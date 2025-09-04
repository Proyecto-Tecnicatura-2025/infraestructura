#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local
[ -f .env.local ] && set -a && . ./.env.local && set +a

echo "▶️  docker compose up..."
docker compose -f compose.yml up -d --build

echo "⏳ esperando DB healthy..."
docker compose -f compose.yml ps

echo "🧹 clear caches & ensure runtime dirs..."
docker compose -f compose.yml exec -T backend bash -lc '
set -e
cd /var/www/html
mkdir -p storage/framework/{sessions,views,cache,data} resources/views
chown -R www-data:www-data storage bootstrap/cache || true
chmod -R ug+rw storage bootstrap/cache || true
php artisan view:clear
php artisan optimize:clear
'

echo "🗃️  migrate fresh (dev)..."
docker compose -f compose.yml exec -T backend bash -lc 'php artisan migrate:fresh --force'

echo "🔑 passport keys..."
bin/init-keys.sh

echo "🪪 upsert PKCE client..."
bin/upsert-client.sh

echo "✅ listo. Abrí: http://localhost:${WEB_PORT:-5173}"
