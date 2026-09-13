#!/usr/bin/env bash
set -euo pipefail

DOMAIN="mlflow.angelfeliz.com"

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

# 5. Obtener certificado SSL si no existe
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
  echo "🔒 Certificado no encontrado. Configurando Nginx temporal (HTTP)..."
  
  # Pedir correo para Let's Encrypt
  read -rp "Email para Let's Encrypt: " LE_EMAIL

  # Crear una configuración HTTP temporal
  cat <<EOF | sudo tee "/etc/nginx/sites-available/${DOMAIN}" > /dev/null
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

  sudo ln -sf "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/"
  sudo nginx -t && sudo systemctl reload nginx

  echo "📜 Solicitando certificado a Let's Encrypt..."
  sudo certbot --nginx -d "${DOMAIN}" \
       --non-interactive --agree-tos -m "$LE_EMAIL"
fi

# 6. Aplicar la configuración SSL final de Nginx
echo "⚙️ Aplicando configuración SSL definitiva en Nginx..."
sudo cp nginx/mlflow.angelfeliz.com /etc/nginx/sites-available/
sudo ln -sf "/etc/nginx/sites-available/${DOMAIN}" /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo "🎉 Despliegue listo: https://${DOMAIN}"
