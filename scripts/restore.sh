#!/bin/bash
# PostgreSQL restore script with data verification
# Usage: ./restore.sh backups/appdb_20241015_120000.sql.gz

set -euo pipefail

BACKUP_FILE="${1:-}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-appuser}"
PGPASSWORD="${PGPASSWORD:-secret}"
PGDATABASE="${PGDATABASE:-appdb}"
RESTORE_DB="${RESTORE_DB:-${PGDATABASE}_restored}"  # Restore to separate DB by default

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ── Validation ───────────────────────────────────────────────────────
if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    echo ""
    echo "Available backups:"
    ls -lh /backups/*.sql.gz 2>/dev/null || echo "  No backups found in /backups/"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    log "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

log "=== PostgreSQL Restore Started ==="
log "Backup file : $BACKUP_FILE"
log "Target DB   : $RESTORE_DB on $PGHOST:$PGPORT"

# ── Verify backup integrity before restore ───────────────────────────
log "Verifying backup integrity..."
gzip -t "$BACKUP_FILE" || { log "ERROR: Backup file is corrupted!"; exit 1; }
log "Integrity check passed"

# ── Create restore target database ───────────────────────────────────
log "Creating restore database: $RESTORE_DB"
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c \
    "DROP DATABASE IF EXISTS $RESTORE_DB;" 2>/dev/null || true
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c \
    "CREATE DATABASE $RESTORE_DB OWNER $PGUSER;"

# ── Restore ──────────────────────────────────────────────────────────
log "Restoring data..."
zcat "$BACKUP_FILE" | PGPASSWORD="$PGPASSWORD" psql \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -U "$PGUSER" \
    -d "$RESTORE_DB" \
    --quiet

log "Restore complete"

# ── Verify data ──────────────────────────────────────────────────────
log "=== DATA VERIFICATION ==="
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$RESTORE_DB" <<-EOF
\echo 'Tables in restored database:'
\dt

\echo ''
\echo 'Row counts:'
SELECT
    schemaname,
    tablename,
    n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

\echo ''
\echo 'Sample data from orders (if exists):'
SELECT * FROM orders LIMIT 5;
EOF

log "=== Restore Verification Complete ==="
log "Restored database: $RESTORE_DB"
log "Connect: psql -h $PGHOST -U $PGUSER -d $RESTORE_DB"
