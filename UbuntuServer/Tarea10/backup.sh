#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/backups/backup_$TIMESTAMP.sql"
pg_dumpall -U "$POSTGRES_USER" -h localhost > "$BACKUP_FILE"