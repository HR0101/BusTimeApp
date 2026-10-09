from fastapi.testclient import TestClient
import pytest

from .main import create_app
from .security import RequestProtection, SlidingWindow

KEY = 'test-only-administrator-key-32-characters'
AUTH = {'X-Admin-Key': KEY}
ADMIN = '/api/v1/admin/publications'


def test_authentication_precedes_body_parsing(tmp_path):
    with TestClient(create_app(tmp_path / 'auth.sqlite3', admin_key=KEY)) as client:
        for path in ['/api/v1/timetables', '/api/v1/admin/import.csv']:
            response = client.post(path, content=b'{malformed', headers={'Content-Length': '2000001'})
            assert response.status_code == 401
            assert response.headers['cache-control'] == 'no-store'
        assert client.get('/api/v1/timetables/mansion-station').json()['version'] == 1


@pytest.mark.parametrize('length,status', [('2000001', 413), ('-1', 400), ('invalid', 400)])
def test_invalid_or_large_content_length_is_rejected(tmp_path, length, status):
    with TestClient(create_app(tmp_path / 'length.sqlite3', admin_key=KEY)) as client:
        response = client.post('/api/v1/admin/import.csv', content=b'x', headers=dict(AUTH, **{'Content-Length': length}))
        assert response.status_code == status
        assert response.headers['x-content-type-options'] == 'nosniff'
        assert response.headers['cache-control'] == 'no-store'


def test_streamed_body_without_content_length_is_bounded(tmp_path):
    with TestClient(create_app(tmp_path / 'stream.sqlite3', admin_key=KEY)) as client:
        request = client.build_request('POST', '/api/v1/admin/import.csv',
                                       content=iter([b'x' * 1_000_000, b'x' * 1_000_001]), headers=AUTH)
        assert 'content-length' not in request.headers
        assert client.send(request).status_code == 413
        assert client.get('/api/v1/timetables/mansion-station').json()['version'] == 1


def test_auth_failure_limit_recovers_without_locking_out_valid_key(tmp_path):
    clock = [0.0]
    protection = RequestProtection(clock=lambda: clock[0], failure_limit=2)
    with TestClient(create_app(tmp_path / 'failures.sqlite3', admin_key=KEY, protection=protection)) as client:
        for address in ['1.1.1.1', '2.2.2.2']:
            assert client.get(ADMIN, headers={'X-Forwarded-For': address, 'CF-Connecting-IP': address}).status_code == 401
        limited = client.get(ADMIN)
        assert limited.status_code == 429 and limited.headers['retry-after'] == '60'
        assert limited.headers['cache-control'] == 'no-store'
        assert client.get(ADMIN, headers=AUTH).status_code == 200
        assert client.get('/api/v1/routes').status_code == 200
        clock[0] = 60
        assert client.get(ADMIN).status_code == 401


def test_admin_and_public_limits_are_separate_and_keep_etags(tmp_path):
    clock = [0.0]
    protection = RequestProtection(clock=lambda: clock[0], public_limit=2, admin_limit=1)
    with TestClient(create_app(tmp_path / 'limits.sqlite3', admin_key=KEY, protection=protection)) as client:
        first = client.get('/api/v1/routes')
        assert first.status_code == 200
        assert client.get('/api/v1/routes', headers={'If-None-Match': first.headers['etag']}).status_code == 304
        assert client.get('/api/v1/routes').status_code == 429
        assert client.get(ADMIN, headers=AUTH).status_code == 200
        assert client.get(ADMIN, headers=AUTH).status_code == 429
        clock[0] = 60
        assert client.get('/api/v1/routes').status_code == 200
        assert client.get(ADMIN, headers=AUTH).status_code == 200


def test_headers_and_api_documentation_exposure(tmp_path):
    with TestClient(create_app(tmp_path / 'headers.sqlite3', admin_key=KEY)) as client:
        for path in ['/api/v1/routes', ADMIN, '/admin', '/admin-assets/admin.js', '/missing']:
            response = client.get(path)
            assert response.headers['x-content-type-options'] == 'nosniff'
            assert response.headers['x-frame-options'] == 'DENY'
            assert response.headers['referrer-policy'] == 'no-referrer'
            if path.startswith('/admin'):
                assert "frame-ancestors 'none'" in response.headers['content-security-policy']
                assert 'unsafe-inline' not in response.headers['content-security-policy']
                assert response.headers['cache-control'] == 'no-store'
        for path in ['/docs', '/redoc', '/openapi.json']:
            assert client.get(path).status_code == 404


def test_rate_limiter_bounds_memory_and_expires_requests():
    clock = [0.0]
    limiter = SlidingWindow(2, max_clients=3, clock=lambda: clock[0])
    for index in range(100):
        assert limiter.retry_after(str(index)) == 0
    assert len(limiter.visitors) == 3
    assert limiter.retry_after('99') == 0
    assert limiter.retry_after('99') == 60
    clock[0] = 59.2
    assert limiter.retry_after('99') == 1
    clock[0] = 60
    assert limiter.retry_after('99') == 0
