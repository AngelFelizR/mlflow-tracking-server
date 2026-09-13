#!/usr/bin/env bash
set -euo pipefail

# 0. Ir a la raíz del proyecto, sin importar desde dónde se invoque
cd "$(dirname "$0")/.."

# 1. Validar .env
[ -f .env ] || { echo "❌ Falta .env (copia .env.example)"; exit 1; }

# 2. Validar basic_auth.ini
[ -f basic_auth.ini ] || { echo "❌ Falta basic_auth.ini (copia basic_auth.ini.example)"; exit 1; }

# 3. Levantar stack
docker compose up -d

# 4. Esperar a que MLflow esté healthy (con timeout)
echo "⏳ Esperando a que MLflow esté healthy (max 3 min)..."
TIMEOUT=180
ELAPSED=0
until [ "$(docker inspect -f '{{.State.Health.Status}}' mlflow-server 2>/dev/null)" = "healthy" ]; do
  sleep 3
  ELAPSED=$((ELAPSED + 3))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "❌ MLflow no llegó a healthy en ${TIMEOUT}s"
    docker compose logs --tail=50 mlflow
    exit 1
  fi
done
echo "✅ MLflow healthy"

# 5. Copiar config de Nginx y habilitar
sudo cp nginx/mlflow.angelfeliz.com /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/mlflow.angelfeliz.com \
            /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 6. Emitir certificado (solo la primera vez)
if [ ! -d /etc/letsencrypt/live/mlflow.angelfeliz.com ]; then
  read -rp "Email para Let's Encrypt: " LE_EMAIL
  sudo certbot --nginx -d mlflow.angelfeliz.com \
       --non-interactive --agree-tos -m "$LE_EMAIL"
fi

echo "🎉 Despliegue listo: https://mlflow.angelfeliz.com"
