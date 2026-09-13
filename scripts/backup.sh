#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

PROJECT_NAME="mlflow-tracking-server"
ABS_BACKUP_DIR="$(realpath "$BACKUP_DIR")"

# PostgreSQL
docker compose exec -T postgres pg_dump -U mlflow mlflow \
  > "$BACKUP_DIR/mlflow.sql"

# Artefactos
docker run --rm \
  -v "${PROJECT_NAME}_mlflow-artifacts:/data" \
  -v "${ABS_BACKUP_DIR}":/backup \
  alpine tar czf /backup/artifacts.tar.gz -C /data .

# Basic auth DB (SQLite)
docker run --rm \
  -v "${PROJECT_NAME}_basic-auth-db:/data" \
  -v "${ABS_BACKUP_DIR}":/backup \
  alpine sh -c "cp /data/basic_auth.db /backup/basic_auth.db 2>/dev/null || true"

echo "✅ Backup en $BACKUP_DIR"
