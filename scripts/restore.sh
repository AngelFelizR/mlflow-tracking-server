#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BACKUP_DIR="${1:?Uso: ./scripts/restore.sh backups/YYYYMMDD_HHMMSS}"
[ -d "$BACKUP_DIR" ] || { echo "❌ No existe $BACKUP_DIR"; exit 1; }

PROJECT_NAME="mlflow-tracking-server"
ABS_BACKUP_DIR="$(realpath "$BACKUP_DIR")"

# Restaurar PostgreSQL
cat "$BACKUP_DIR/mlflow.sql" | \
  docker compose exec -T postgres psql -U mlflow mlflow

# Restaurar artefactos
docker run --rm \
  -v "${PROJECT_NAME}_mlflow-artifacts:/data" \
  -v "${ABS_BACKUP_DIR}":/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/artifacts.tar.gz -C /data"

# Restaurar basic auth DB si existe
if [ -f "$BACKUP_DIR/basic_auth.db" ]; then
  docker run --rm \
    -v "${PROJECT_NAME}_basic-auth-db:/data" \
    -v "${ABS_BACKUP_DIR}":/backup \
    alpine sh -c "cp /backup/basic_auth.db /data/basic_auth.db"
fi

echo "✅ Restaurado desde $BACKUP_DIR"
