"""Transactional SQLite storage; route versions include deletions and schedule edits."""
import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4
from .models import Batch, Schedule, Trip


def timestamp(value):
    return value.astimezone(timezone.utc).isoformat(timespec='microseconds')


class Database:
    def __init__(self, path, seed_path=None, now=None):
        self.path = str(path)
        self.now = now or (lambda: datetime.now(timezone.utc))
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        with self.connection() as db:
            db.executescript(Path(__file__).with_name('schema.sql').read_text())
            db.execute('BEGIN IMMEDIATE')
            if db.execute('SELECT version FROM schema_version').fetchone()[0] != 1:
                raise RuntimeError('Unsupported database schema')
            if not db.execute('SELECT 1 FROM routes').fetchone():
                seed = json.loads(Path(seed_path or Path(__file__).with_name('seed.json')).read_text())
                for stop in seed['stops']:
                    db.execute('INSERT INTO stops VALUES (:id,:name,:latitude,:longitude)', stop)
                for route in seed['routes']:
                    db.execute('INSERT INTO routes VALUES (:id,:name,:origin_stop_id,:destination_stop_id,1,:updated_at)',
                               dict(route, updated_at=timestamp(self.now())))
                for schedule in seed['schedules']:
                    self._write_schedule(db, Schedule.model_validate(schedule))
                for trip in seed['buses']:
                    self._write_trip(db, Trip.model_validate(trip), bump=False)
            db.commit()

    @contextmanager
    def connection(self, write=False):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        db.execute('PRAGMA journal_mode=WAL')
        db.execute('BEGIN IMMEDIATE' if write else 'BEGIN')
        try:
            yield db
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def _bump(self, db, route_id, entity_id, operation):
        updated = timestamp(self.now())
        db.execute('UPDATE routes SET version=version+1, updated_at=? WHERE id=?', (updated, route_id))
        version = db.execute('SELECT version FROM routes WHERE id=?', (route_id,)).fetchone()['version']
        db.execute('INSERT INTO changes VALUES (?,?,?,?,?)', (route_id, version, entity_id, operation, updated))

    def _validate_trip(self, db, trip):
        route = db.execute('SELECT * FROM routes WHERE id=?', (trip.route_id,)).fetchone()
        schedule = db.execute('SELECT route_id FROM schedules WHERE id=?', (trip.schedule_id,)).fetchone()
        if not route or not schedule or schedule['route_id'] != trip.route_id:
            raise ValueError('Route or schedule not found, or schedule belongs to another route')
        for stop in trip.stops:
            if not db.execute('SELECT 1 FROM stops WHERE id=?', (stop.stop_id,)).fetchone():
                raise ValueError('Unknown stop')
        if trip.stops[0].stop_id != route['origin_stop_id'] or trip.stops[-1].stop_id != route['destination_stop_id']:
            raise ValueError('Trip endpoints do not match route')
        existing = db.execute('SELECT route_id FROM timetables WHERE id=?', (trip.id,)).fetchone()
        if existing and existing['route_id'] != trip.route_id:
            raise ValueError('A trip cannot move between routes; create another ID instead')

    def _write_trip(self, db, trip, bump=True):
        self._validate_trip(db, trip)
        db.execute('INSERT INTO timetables VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET '
                   'schedule_id=excluded.schedule_id,stops_json=excluded.stops_json,note=excluded.note',
                   (trip.id, trip.route_id, trip.schedule_id,
                    json.dumps([s.model_dump() for s in trip.stops], ensure_ascii=False), trip.note))
        if bump:
            self._bump(db, trip.route_id, trip.id, 'upsert')

    def write_trip(self, trip, creating):
        with self.connection(write=True) as db:
            exists = db.execute('SELECT 1 FROM timetables WHERE id=?', (trip.id,)).fetchone()
            if creating and exists:
                raise ValueError('Trip ID already exists')
            if not creating and not exists:
                raise KeyError(trip.id)
            self._write_trip(db, trip)
            return self._trip_json(db, db.execute('SELECT * FROM timetables WHERE id=?', (trip.id,)).fetchone())

    def _write_schedule(self, db, schedule):
        if not db.execute('SELECT 1 FROM routes WHERE id=?', (schedule.route_id,)).fetchone():
            raise ValueError('Unknown route')
        previous = db.execute('SELECT route_id FROM schedules WHERE id=?', (schedule.id,)).fetchone()
        if previous and previous['route_id'] != schedule.route_id:
            raise ValueError('Schedule route cannot change')
        values = schedule.model_dump(mode='json')
        db.execute('INSERT INTO schedules VALUES (:id,:route_id,:kind,:service_date,:valid_from,:valid_until,:is_suspended,:priority) '
                   'ON CONFLICT(id) DO UPDATE SET kind=excluded.kind,service_date=excluded.service_date,'
                   'valid_from=excluded.valid_from,valid_until=excluded.valid_until,is_suspended=excluded.is_suspended,priority=excluded.priority', values)

    def write_schedule(self, schedule):
        with self.connection(write=True) as db:
            self._write_schedule(db, schedule)
            self._bump(db, schedule.route_id, 'schedule:' + schedule.id, 'schedule')
        return schedule.model_dump(mode='json')

    def _trip_json(self, db, row):
        if row is None:
            return None
        trip = dict(row)
        trip['stops'] = json.loads(trip.pop('stops_json'))
        for stop in trip['stops']:
            stop['name'] = db.execute('SELECT name FROM stops WHERE id=?', (stop['stop_id'],)).fetchone()['name']
        trip['departure'] = trip['stops'][0]['time']
        trip['arrival'] = trip['stops'][-1]['time']
        return trip

    def _apply(self, db, batch):
        seen = set()
        preview = []
        for change in batch.changes:
            trip_id = change.trip.id if change.trip else change.id
            if trip_id in seen:
                raise ValueError('A batch may change each trip ID only once')
            seen.add(trip_id)
            before = self._trip_json(db, db.execute('SELECT * FROM timetables WHERE id=?', (trip_id,)).fetchone())
            if change.operation == 'upsert':
                self._write_trip(db, change.trip)
                after = self._trip_json(db, db.execute('SELECT * FROM timetables WHERE id=?', (trip_id,)).fetchone())
            else:
                if not before:
                    raise KeyError(trip_id)
                db.execute('DELETE FROM timetables WHERE id=?', (trip_id,))
                self._bump(db, before['route_id'], trip_id, 'delete')
                after = None
            preview.append({'id': trip_id, 'before': before, 'after': after})
        return preview

    def apply(self, batch, preview=False):
        with self.connection(write=True) as db:
            result = self._apply(db, batch)
            if preview:
                db.rollback()
            return {'changes': result}

    def schedule_publication(self, publication):
        if publication.publish_at <= self.now():
            raise ValueError('Publication time must be in the future')
        self.apply(Batch(changes=publication.changes), preview=True)
        identifier = uuid4().hex
        with self.connection(write=True) as db:
            db.execute('INSERT INTO publications(id,publish_at,changes_json) VALUES (?,?,?)',
                       (identifier, timestamp(publication.publish_at), publication.model_dump_json(exclude={'publish_at'})))
        return {'id': identifier, 'publish_at': timestamp(publication.publish_at), 'status': 'pending'}

    def publish_due(self):
        with self.connection(write=True) as db:
            for row in db.execute("SELECT * FROM publications WHERE status='pending' AND publish_at<=? ORDER BY publish_at,id", (timestamp(self.now()),)).fetchall():
                db.execute('SAVEPOINT publication')
                try:
                    self._apply(db, Batch.model_validate_json(row['changes_json']))
                    db.execute("UPDATE publications SET status='published' WHERE id=?", (row['id'],))
                    db.execute('RELEASE publication')
                except (ValueError, KeyError, sqlite3.IntegrityError):
                    db.execute('ROLLBACK TO publication')
                    db.execute('RELEASE publication')
                    db.execute("UPDATE publications SET status='failed',error='Data changed after scheduling; review and resubmit' WHERE id=?", (row['id'],))

    def routes(self):
        self.publish_due()
        with self.connection() as db:
            return [dict(row) for row in db.execute('SELECT * FROM routes ORDER BY id')]

    def stops(self):
        with self.connection() as db:
            return [dict(row) for row in db.execute('SELECT * FROM stops ORDER BY id')]

    def publications(self):
        self.publish_due()
        with self.connection() as db:
            return [dict(row) for row in db.execute('SELECT id,publish_at,status,error FROM publications ORDER BY publish_at DESC')]

    def snapshot(self, route_id, since=None):
        self.publish_due()
        with self.connection() as db:
            route = db.execute('SELECT * FROM routes WHERE id=?', (route_id,)).fetchone()
            if not route:
                raise KeyError(route_id)
            if since is not None and since > route['version']:
                raise ValueError('Requested version is ahead of server; fetch a full snapshot')
            schedules = []
            for row in db.execute('SELECT * FROM schedules WHERE route_id=? ORDER BY priority DESC,id', (route_id,)):
                value = dict(row)
                value['is_suspended'] = bool(value['is_suspended'])
                schedules.append(value)
            result = {'schema_version': 1, 'route_id': route_id, 'route_name': route['name'],
                      'version': route['version'], 'updated_at': route['updated_at'], 'schedules': schedules}
            if since is None:
                result['buses'] = [self._trip_json(db, row) for row in db.execute('SELECT * FROM timetables WHERE route_id=? ORDER BY id', (route_id,))]
            else:
                latest = {}
                if since == 0:
                    latest = {row['id']: 'upsert' for row in db.execute('SELECT id FROM timetables WHERE route_id=?', (route_id,))}
                for row in db.execute('SELECT * FROM changes WHERE route_id=? AND version>? ORDER BY version', (route_id, since)):
                    if row['operation'] != 'schedule':
                        latest[row['entity_id']] = row['operation']
                result['upserts'], result['deleted_ids'] = [], []
                for identifier, operation in latest.items():
                    trip = db.execute('SELECT * FROM timetables WHERE id=?', (identifier,)).fetchone()
                    if trip:
                        result['upserts'].append(self._trip_json(db, trip))
                    else:
                        result['deleted_ids'].append(identifier)
            return result

    def csv_rows(self):
        self.publish_due()
        with self.connection() as db:
            return [dict(row) for row in db.execute('SELECT * FROM timetables ORDER BY route_id,id')]
