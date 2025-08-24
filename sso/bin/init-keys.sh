#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local
docker compose -f compose.yml exec -T oauth bash -lc $'set -e
cd /var/www/html
php artisan optimize:clear
chown -R www-data:www-data storage bootstrap/cache || true
chmod -R ug+rw storage bootstrap/cache || true
php artisan passport:keys --force
chmod 640 storage/oauth-private.key storage/oauth-public.key || true
php artisan route:list | egrep "oauth/authorize|oauth/token|api/user" || true
'
