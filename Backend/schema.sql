PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS schema_version(version INTEGER NOT NULL);
INSERT INTO schema_version SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM schema_version);
CREATE TABLE IF NOT EXISTS stops (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS routes (
  id TEXT PRIMARY KEY, name TEXT NOT NULL,
  origin_stop_id TEXT NOT NULL REFERENCES stops(id),
  destination_stop_id TEXT NOT NULL REFERENCES stops(id),
  version INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS schedules (
  id TEXT PRIMARY KEY, route_id TEXT NOT NULL REFERENCES routes(id), kind TEXT NOT NULL,
  service_date TEXT, valid_from TEXT, valid_until TEXT,
  is_suspended INTEGER NOT NULL, priority INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS timetables (
  id TEXT PRIMARY KEY, route_id TEXT NOT NULL REFERENCES routes(id),
  schedule_id TEXT NOT NULL REFERENCES schedules(id), stops_json TEXT NOT NULL, note TEXT
);
CREATE INDEX IF NOT EXISTS timetable_route ON timetables(route_id);
CREATE TABLE IF NOT EXISTS changes (
  route_id TEXT NOT NULL REFERENCES routes(id), version INTEGER NOT NULL,
  entity_id TEXT NOT NULL, operation TEXT NOT NULL, updated_at TEXT NOT NULL,
  PRIMARY KEY (route_id, version, entity_id)
);
CREATE TABLE IF NOT EXISTS publications (
  id TEXT PRIMARY KEY, publish_at TEXT NOT NULL, changes_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', error TEXT
);
CREATE INDEX IF NOT EXISTS pending_publications ON publications(status, publish_at);
