# 💾 Backup + Restore — PostgreSQL Automated Backups

Automated backups with hourly cron, integrity check, retention policy, and restore with data verification.

## Architecture
```
PostgreSQL → backup.sh (cron hourly) → /backups/*.sql.gz
                                     → backup_manifest.json
             restore.sh ─────────────→ appdb_restored (verified)
```

## Quick Start
```bash
docker compose up -d

# Run first manual backup
docker exec backup-runner sh /scripts/backup.sh

# List backups
docker exec backup-runner ls -lh /backups/
```

## Backup
```bash
# Manual backup
docker exec backup-runner sh /scripts/backup.sh

# Check backup manifest
docker exec backup-runner cat /backups/backup_manifest.json

# View backup logs
docker exec backup-runner cat /var/log/backup.log
```

## Restore (THE IMPORTANT PART)
```bash
# See available backups
docker exec backup-runner ls /backups/*.sql.gz

# Restore a backup (restores to appdb_restored by default)
docker exec backup-runner sh /scripts/restore.sh /backups/appdb_20241015_120000.sql.gz

# The script will:
# 1. Verify backup integrity (gzip -t)
# 2. Create fresh target database
# 3. Restore all data
# 4. Show table list + row counts
# 5. Show sample data

# Compare original vs restored
docker exec postgres-backup-demo psql -U appuser -d appdb \
  -c "SELECT COUNT(*) FROM orders;"

docker exec postgres-backup-demo psql -U appuser -d appdb_restored \
  -c "SELECT COUNT(*) FROM orders;"
```

## Test disaster recovery
```bash
# 1. Take backup
docker exec backup-runner sh /scripts/backup.sh

# 2. Delete all data from original (simulate disaster)
docker exec postgres-backup-demo psql -U appuser -d appdb \
  -c "DELETE FROM orders; DELETE FROM users;"

# 3. Verify data is gone
docker exec postgres-backup-demo psql -U appuser -d appdb \
  -c "SELECT COUNT(*) FROM orders;"  # Should be 0

# 4. Restore from backup
LATEST=$(docker exec backup-runner ls -t /backups/*.sql.gz | head -1)
docker exec backup-runner sh /scripts/restore.sh "$LATEST"

# 5. Verify data is back
docker exec postgres-backup-demo psql -U appuser -d appdb_restored \
  -c "SELECT * FROM orders;"  # All 5 rows restored
```

## Key learning
- Don't stop at "backup completed" — always verify the restore works
- Backup includes integrity check (gzip -t) before restore
- Restore to separate database first — don't overwrite production
- Row count verification confirms data made it through
