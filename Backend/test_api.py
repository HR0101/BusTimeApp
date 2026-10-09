from datetime import datetime, timedelta, timezone
import json
from fastapi.testclient import TestClient
import pytest
from .main import create_app

KEY = 'test-only-administrator-key-32-characters'
AUTH = {'X-Admin-Key': KEY}
ROUTE = 'mansion-station'


@pytest.fixture
def api(tmp_path):
    clock = [datetime(2026, 8, 12, 1, tzinfo=timezone.utc)]
    app = create_app(tmp_path / 'timetable.sqlite3', admin_key=KEY, now=lambda: clock[0])
    with TestClient(app) as client:
        yield client, app.state.store, clock


def trip(identifier='extra-trip', departure='12:15', arrival='12:23'):
    return dict(id=identifier, route_id=ROUTE, schedule_id=ROUTE + '-weekday',
                stops=[dict(stop_id='mansion', time=departure), dict(stop_id='station', time=arrival)], note='臨時便')


def snapshot(client):
    return client.get('/api/v1/timetables/' + ROUTE)


def test_seed_covers_all_routes_and_stops(api):
    client, store, _ = api
    assert client.get('/health').json()['schema_version'] == 1
    routes = client.get('/api/v1/routes').json()['routes']
    assert len(routes) == 5
    assert len(client.get('/api/v1/stops').json()['stops']) == 3
    assert sum(len(client.get('/api/v1/timetables/' + r['id']).json()['buses']) for r in routes) == 115
    values = snapshot(client).json()
    assert len(values['schedules']) == 3
    assert values['version'] == 1
    assert any(b['departure'] == '0:04' for b in values['buses'])


@pytest.mark.parametrize('method,path,body', [
    ('post', '/api/v1/timetables', trip()),
    ('put', '/api/v1/timetables/id', trip()),
    ('delete', '/api/v1/timetables/id', None),
    ('put', '/api/v1/schedules/id', dict(id='id', route_id=ROUTE, kind='weekday')),
    ('post', '/api/v1/admin/preview', {'changes': [{'operation': 'upsert', 'trip': trip()}]}),
    ('post', '/api/v1/admin/batch', {'changes': [{'operation': 'upsert', 'trip': trip()}]}),
    ('post', '/api/v1/admin/publications', {'changes': [{'operation': 'upsert', 'trip': trip()}], 'publish_at': '2026-08-13T00:00:00Z'}),
])
def test_every_mutation_requires_correct_admin_key(api, method, path, body):
    client, _, _ = api
    for headers in [{}, {'X-Admin-Key': 'wrong'}]:
        response = getattr(client, method)(path, headers=headers, **({'json': body} if body else {}))
        assert response.status_code == 401
    assert snapshot(client).json()['version'] == 1


def test_crud_delta_deletion_and_etag(api):
    client, _, _ = api
    original = snapshot(client)
    assert client.get('/api/v1/timetables/' + ROUTE, headers={'If-None-Match': original.headers['etag']}).status_code == 304
    assert client.post('/api/v1/timetables', json=trip(), headers=AUTH).status_code == 201
    assert client.post('/api/v1/timetables', json=trip(), headers=AUTH).status_code == 422
    changed = snapshot(client)
    assert changed.headers['etag'] != original.headers['etag']
    delta = client.get('/api/v1/timetables/' + ROUTE + '/changes?since_version=1').json()
    assert [b['id'] for b in delta['upserts']] == ['extra-trip']
    assert delta['version'] == 2 and delta['deleted_ids'] == []
    assert client.put('/api/v1/timetables/extra-trip', json=trip(departure='12:25', arrival='12:33'), headers=AUTH).status_code == 200
    assert client.delete('/api/v1/timetables/extra-trip', headers=AUTH).status_code == 200
    delta = client.get('/api/v1/timetables/' + ROUTE + '/changes?since_version=2').json()
    assert delta['upserts'] == [] and delta['deleted_ids'] == ['extra-trip']
    assert client.delete('/api/v1/timetables/extra-trip', headers=AUTH).status_code == 404
    assert client.get('/api/v1/timetables/' + ROUTE + '/changes?since_version=999').status_code == 422
    assert len(client.get('/api/v1/timetables/' + ROUTE + '/changes?since_version=0').json()['upserts']) == len(original.json()['buses'])


def test_invalid_stop_times_and_endpoints_leave_data_untouched(api):
    client, _, _ = api
    for value in [trip(departure='25:00'), trip(arrival='12:00'),
                  dict(trip(), route_id='missing'), dict(trip(), schedule_id='yokado-mansion-weekday')]:
        assert client.post('/api/v1/timetables', json=value, headers=AUTH).status_code == 422
    value = trip()
    value['stops'][0]['stop_id'] = 'yokado'
    assert client.post('/api/v1/timetables', json=value, headers=AUTH).status_code == 422
    assert snapshot(client).json()['version'] == 1


def test_batch_preview_and_invalid_batch_are_atomic(api):
    client, _, _ = api
    changes = [{'operation': 'upsert', 'trip': trip()}]
    preview = client.post('/api/v1/admin/preview', json={'changes': changes}, headers=AUTH)
    assert preview.status_code == 200 and preview.json()['changes'][0]['before'] is None
    assert snapshot(client).json()['version'] == 1
    bad = changes + [{'operation': 'delete', 'id': 'missing'}]
    assert client.post('/api/v1/admin/batch', json={'changes': bad}, headers=AUTH).status_code == 404
    assert snapshot(client).json()['version'] == 1
    assert client.post('/api/v1/admin/batch', json={'changes': changes}, headers=AUTH).status_code == 200


def test_scheduled_publication_activates_and_appears_in_delta(api):
    client, _, clock = api
    publish_at = clock[0] + timedelta(hours=1)
    body = dict(changes=[{'operation': 'upsert', 'trip': trip()}], publish_at=publish_at.isoformat())
    assert client.post('/api/v1/admin/publications', json=body, headers=AUTH).status_code == 201
    assert snapshot(client).json()['version'] == 1
    clock[0] = publish_at
    delta = client.get('/api/v1/timetables/' + ROUTE + '/changes?since_version=1').json()
    assert delta['version'] == 2 and delta['upserts'][0]['id'] == 'extra-trip'
    assert client.get('/api/v1/admin/publications', headers=AUTH).json()['publications'][0]['status'] == 'published'
    assert snapshot(client).json()['version'] == 2


def test_special_service_and_suspension_are_versioned(api):
    client, _, _ = api
    value = dict(id='special-date', route_id=ROUTE, kind='special', service_date='2026-08-12', is_suspended=True, priority=10)
    assert client.put('/api/v1/schedules/special-date', json=value, headers=AUTH).status_code == 200
    delta = client.get('/api/v1/timetables/' + ROUTE + '/changes?since_version=1').json()
    assert delta['version'] == 2 and delta['upserts'] == []
    assert any(s['id'] == 'special-date' and s['is_suspended'] for s in delta['schedules'])


def test_csv_preview_round_trip_and_authentication(api):
    client, _, _ = api
    assert client.get('/api/v1/admin/export.csv').status_code == 401
    assert client.post('/api/v1/admin/import.csv', content=b'csv').status_code == 401
    exported = client.get('/api/v1/admin/export.csv', headers=AUTH).text
    response = client.post('/api/v1/admin/import.csv', content=exported, headers=dict(AUTH, **{'Content-Type': 'text/csv'}))
    assert response.status_code == 200 and len(response.json()['changes']) == 115
    assert snapshot(client).json()['version'] == 1
    assert client.post('/api/v1/admin/import.csv?preview=false', content=exported, headers=dict(AUTH, **{'Content-Type': 'text/csv'})).status_code == 200
    assert len(snapshot(client).json()['buses']) > 0
    assert client.post('/api/v1/admin/import.csv', content='invalid headers', headers=AUTH).status_code == 422


def test_restart_keeps_admin_edits(tmp_path):
    path = tmp_path / 'persist.sqlite3'
    with TestClient(create_app(path, admin_key=KEY)) as first:
        first.post('/api/v1/timetables', json=trip(), headers=AUTH)
    with TestClient(create_app(path, admin_key=KEY)) as second:
        assert any(b['id'] == 'extra-trip' for b in snapshot(second).json()['buses'])
        assert snapshot(second).json()['version'] == 2


def test_unconfigured_administration_is_fail_closed(tmp_path):
    with TestClient(create_app(tmp_path / 'disabled.sqlite3', admin_key='')) as client:
        assert client.get('/api/v1/routes').status_code == 200
        assert client.post('/api/v1/timetables', json=trip(), headers=AUTH).status_code == 503


def test_admin_page_and_assets_use_external_scripts_and_restrict_framing(api):
    client, _, _ = api
    page = client.get('/admin')
    assert page.status_code == 200
    assert "frame-ancestors 'none'" in page.headers['content-security-policy']
    assert 'unsafe-inline' not in page.headers['content-security-policy']
    assert 'no-store' == page.headers['cache-control']
    assert client.get('/admin-assets/admin.js').status_code == 200
    assert client.get('/admin-assets/admin.css').status_code == 200
