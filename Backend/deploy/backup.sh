#!/bin/sh
set -eu
cd /opt/bustime
umask 077
mkdir -p backups
backup_file="backups/timetable-$(date -u +%Y%m%dT%H%M%SZ).sqlite3"
docker compose --env-file Backend/deploy/.env -f Backend/deploy/compose.yaml exec -T api python -c "import sqlite3; src=sqlite3.connect('/data/timetable.sqlite3'); dst=sqlite3.connect('/data/backup.sqlite3'); src.backup(dst); dst.close(); src.close()"
docker compose --env-file Backend/deploy/.env -f Backend/deploy/compose.yaml cp api:/data/backup.sqlite3 "$backup_file"
find backups -name 'timetable-*.sqlite3' -mtime +7 -delete
