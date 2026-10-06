#!/bin/bash
# Automated PostgreSQL backup script
# Supports: full dump, compression, retention policy, S3 upload (optional)

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-appuser}"
PGPASSWORD="${PGPASSWORD:-secret}"
PGDATABASE="${PGDATABASE:-appdb}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
S3_BUCKET="${S3_BUCKET:-}"  # Optional: set to upload to S3

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${PGDATABASE}_${TIMESTAMP}.sql.gz"
MANIFEST_FILE="${BACKUP_DIR}/backup_manifest.json"

# ── Functions ────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

check_postgres() {
    log "Checking PostgreSQL connection..."
    PGPASSWORD="$PGPASSWORD" pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" || {
        log "ERROR: Cannot connect to PostgreSQL"
        exit 1
    }
}

take_backup() {
    log "Starting backup of $PGDATABASE → $BACKUP_FILE"
    mkdir -p "$BACKUP_DIR"

    PGPASSWORD="$PGPASSWORD" pg_dump \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U "$PGUSER" \
        -d "$PGDATABASE" \
        --format=plain \
        --no-password \
        --verbose \
        | gzip -9 > "$BACKUP_FILE"

    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    log "Backup complete: $BACKUP_FILE ($SIZE)"
}

verify_backup() {
    log "Verifying backup integrity..."
    if gzip -t "$BACKUP_FILE"; then
        log "Backup integrity OK"
    else
        log "ERROR: Backup file is corrupted!"
        exit 1
    fi

    # Check it has actual SQL content
    ROW_COUNT=$(zcat "$BACKUP_FILE" | grep -c "^COPY\|^INSERT" || true)
    log "Backup contains ~$ROW_COUNT data statements"
}

update_manifest() {
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    CHECKSUM=$(md5sum "$BACKUP_FILE" | cut -d' ' -f1)
    ENTRY=$(cat <<EOF
{
  "file": "$(basename $BACKUP_FILE)",
  "database": "$PGDATABASE",
  "timestamp": "$TIMESTAMP",
  "size": "$SIZE",
  "checksum_md5": "$CHECKSUM",
  "host": "$PGHOST"
}
EOF
)
    echo "$ENTRY" >> "$MANIFEST_FILE"
    log "Manifest updated"
}

upload_to_s3() {
    if [ -n "$S3_BUCKET" ]; then
        log "Uploading to s3://$S3_BUCKET/backups/..."
        aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/backups/$(basename $BACKUP_FILE)" \
            --storage-class STANDARD_IA
        log "S3 upload complete"
    fi
}

apply_retention() {
    log "Applying retention: removing backups older than $RETENTION_DAYS days..."
    DELETED=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -print -delete | wc -l)
    log "Removed $DELETED old backup(s)"
}

# ── Main ─────────────────────────────────────────────────────────────
log "=== PostgreSQL Backup Started ==="
check_postgres
take_backup
verify_backup
update_manifest
upload_to_s3
apply_retention
log "=== Backup Complete: $BACKUP_FILE ==="
