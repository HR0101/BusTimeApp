"""Public timetable API and authenticated administration; run with Uvicorn."""
import csv
import hashlib
import io
import json
import os
import secrets
from pathlib import Path
from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.security import APIKeyHeader
from fastapi.staticfiles import StaticFiles
from .database import Database
from .models import Batch, Operation, Publication, Schedule, Trip


CSV_FIELDS = ['id', 'route_id', 'schedule_id', 'stops_json', 'note']


def create_app(database_path=None, admin_key=None, now=None):
    key = admin_key if admin_key is not None else os.environ.get('ADMIN_API_KEY', '')
    if key and len(key) < 32:
        raise RuntimeError('ADMIN_API_KEY must contain at least 32 characters')
    store = Database(database_path or os.environ.get('TIMETABLE_DB_PATH', 'data/timetable.sqlite3'), now=now)
    app = FastAPI(title='BusTimeApp Timetable API', version='1.0.0')
    app.mount('/admin-assets', StaticFiles(directory=Path(__file__).parent / 'static'), name='admin-assets')
    app.state.store = store
    scheme = APIKeyHeader(name='X-Admin-Key', auto_error=False)

    def require_admin(provided: str | None = Depends(scheme)):
        if not key:
            raise HTTPException(503, 'Administration is disabled until ADMIN_API_KEY is configured')
        if not provided or not secrets.compare_digest(provided.encode(), key.encode()):
            raise HTTPException(401, 'Invalid administrator key')

    @app.middleware('http')
    async def limit_requests(request, call_next):
        # Keep JSON and CSV batches bounded, including requests without Content-Length.
        if request.method in ('POST', 'PUT'):
            try:
                if int(request.headers.get('content-length', '0')) > 2_000_000:
                    return JSONResponse({'detail': 'Request too large'}, status_code=413)
            except ValueError:
                return JSONResponse({'detail': 'Invalid Content-Length'}, status_code=400)
            body = bytearray()
            async for chunk in request.stream():
                body.extend(chunk)
                if len(body) > 2_000_000:
                    return JSONResponse({'detail': 'Request too large'}, status_code=413)
            request._body = bytes(body)
        response = await call_next(request)
        response.headers['X-Content-Type-Options'] = 'nosniff'
        if request.url.path.startswith('/api/v1/admin') or request.method != 'GET':
            response.headers['Cache-Control'] = 'no-store'
        return response

    @app.exception_handler(KeyError)
    async def missing(request, error):
        return JSONResponse({'detail': 'Resource not found'}, status_code=404)

    @app.exception_handler(ValueError)
    async def invalid(request, error):
        return JSONResponse({'detail': str(error)}, status_code=422)

    def conditional(request, payload):
        content = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
        etag = '"' + hashlib.sha256(content).hexdigest() + '"'
        headers = {'ETag': etag, 'Cache-Control': 'public, max-age=0, must-revalidate'}
        candidates = [value.strip().removeprefix('W/') for value in request.headers.get('if-none-match', '').split(',')]
        if etag in candidates or '*' in candidates:
            return Response(status_code=304, headers=headers)
        return Response(content, media_type='application/json', headers=headers)

    @app.get('/health')
    def health():
        return {'status': 'ok', 'schema_version': 1}

    @app.get('/api/v1/routes')
    def routes(request: Request):
        return conditional(request, {'schema_version': 1, 'routes': store.routes()})

    @app.get('/api/v1/stops')
    def stops(request: Request):
        return conditional(request, {'stops': store.stops()})

    @app.get('/api/v1/timetables/{route_id}/changes')
    def changes(route_id: str, request: Request, since_version: int = Query(ge=0)):
        return conditional(request, store.snapshot(route_id, since=since_version))

    @app.get('/api/v1/timetables/{route_id}')
    def timetable(route_id: str, request: Request):
        return conditional(request, store.snapshot(route_id))

    @app.post('/api/v1/timetables', dependencies=[Depends(require_admin)], status_code=201)
    def add_trip(trip: Trip):
        return store.write_trip(trip, creating=True)

    @app.put('/api/v1/timetables/{trip_id}', dependencies=[Depends(require_admin)])
    def edit_trip(trip_id: str, trip: Trip):
        if trip.id != trip_id:
            raise HTTPException(422, 'Body ID must match URL')
        return store.write_trip(trip, creating=False)

    @app.delete('/api/v1/timetables/{trip_id}', dependencies=[Depends(require_admin)])
    def delete_trip(trip_id: str):
        return store.apply(Batch(changes=[Operation(operation='delete', id=trip_id)]))

    @app.put('/api/v1/schedules/{schedule_id}', dependencies=[Depends(require_admin)])
    def schedule(schedule_id: str, schedule: Schedule):
        if schedule.id != schedule_id:
            raise HTTPException(422, 'Body ID must match URL')
        return store.write_schedule(schedule)

    @app.post('/api/v1/admin/preview', dependencies=[Depends(require_admin)])
    def preview(batch: Batch):
        return store.apply(batch, preview=True)

    @app.post('/api/v1/admin/batch', dependencies=[Depends(require_admin)])
    def apply_batch(batch: Batch):
        return store.apply(batch)

    @app.post('/api/v1/admin/publications', dependencies=[Depends(require_admin)], status_code=201)
    def publish(publication: Publication):
        return store.schedule_publication(publication)

    @app.get('/api/v1/admin/publications', dependencies=[Depends(require_admin)])
    def publications():
        return {'publications': store.publications()}

    @app.get('/api/v1/admin/export.csv', dependencies=[Depends(require_admin)])
    def export_csv():
        target = io.StringIO(newline='')
        writer = csv.DictWriter(target, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(store.csv_rows())
        return Response(target.getvalue(), media_type='text/csv',
                        headers={'Content-Disposition': 'attachment; filename="timetables.csv"'})

    @app.post('/api/v1/admin/import.csv', dependencies=[Depends(require_admin)])
    async def import_csv(request: Request, preview: bool = True):
        try:
            reader = csv.DictReader(io.StringIO((await request.body()).decode('utf-8-sig')))
            if reader.fieldnames != CSV_FIELDS:
                raise ValueError('CSV headers must be: ' + ','.join(CSV_FIELDS))
            rows = list(reader)
            batch = Batch(changes=[Operation(operation='upsert', trip=Trip.model_validate(
                dict(id=row['id'], route_id=row['route_id'], schedule_id=row['schedule_id'],
                     stops=json.loads(row['stops_json']), note=row['note'] or None))) for row in rows])
        except (UnicodeError, csv.Error, TypeError, json.JSONDecodeError, KeyError) as error:
            raise HTTPException(422, 'Malformed CSV') from error
        return store.apply(batch, preview=preview)

    @app.get('/admin', include_in_schema=False)
    def admin():
        return FileResponse(Path(__file__).parent / 'static/index.html',
                            headers={'Cache-Control': 'no-store', 'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'; frame-ancestors 'none'"})

    return app


app = create_app()
