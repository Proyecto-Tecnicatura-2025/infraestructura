#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sso_local}"
[ -f .env.local ] && set -a && . ./.env.local && set +a

AUTH_URL="${AUTH_URL:-http://localhost:8080}"

# Servicios (ajustá si tu compose usa otros nombres)
DB_SERVICE="${DB_SERVICE:-db-oauth}"
BACKEND_SERVICE="${BACKEND_SERVICE:-backend}"

# Redirects por defecto para las dos apps
TIENDA_REDIRECT="${TIENDA_REDIRECT:-http://localhost:5174/auth/callback}"
PUBLICADORES_REDIRECT="${PUBLICADORES_REDIRECT:-http://localhost:5175/auth/callback}"

# Siempre usar compose.yml + compose.override.yml
COMPOSE="docker compose -f compose.yml -f compose.override.yml"

echo "▶️  docker compose up..."
$COMPOSE up -d --build

echo "⏳ esperando DB healthy (${DB_SERVICE})..."
CID="$($COMPOSE ps -q "${DB_SERVICE}" || true)"
if [ -n "${CID:-}" ]; then
  until [ "$({ docker inspect -f '{{.State.Health.Status}}' "$CID" 2>/dev/null || echo starting; })" = "healthy" ]; do
    sleep 2
  done
else
  echo "WARN: no pude detectar el contenedor de ${DB_SERVICE}, continúo..."
fi

echo "🧹 clear caches & ensure runtime dirs..."
$COMPOSE exec -T "${BACKEND_SERVICE}" bash -lc '
set -e
cd /var/www/html
mkdir -p storage/framework/{sessions,views,cache,data} resources/views
chown -R www-data:www-data storage bootstrap/cache || true
chmod -R ug+rw storage bootstrap/cache || true
php artisan view:clear
php artisan optimize:clear
'

echo "🗃️  migrate fresh..."
$COMPOSE exec -T "${BACKEND_SERVICE}" bash -lc 'php artisan migrate:fresh --force'

echo "🔑 passport keys..."
$COMPOSE exec -T "${BACKEND_SERVICE}" bash -lc '
set -e
cd /var/www/html
php artisan passport:keys --force
chown www-data:www-data storage/oauth-*.key || true
chmod 640 storage/oauth-*.key || true
'

echo "🪪 upsert PKCE clients (tienda/publicadores)..."
IDS="$($COMPOSE exec -T "${BACKEND_SERVICE}" bash -lc '
set -e
cat >/tmp/upsert_two.php << "PHP"
<?php
chdir("/var/www/html");
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Laravel\Passport\Client;

function upsert($name, $redirect, $grants=["authorization_code","refresh_token"]) {
  $c = Client::query()->where("name",$name)->where("revoked",false)->first();
  if (!$c) {
    $c = new Client();
    $c->name    = $name;
    $c->secret  = null;     // público (PKCE)
    $c->revoked = false;
    $c->redirect_uris = [];
    $c->grant_types   = $grants;
  }
  $uris = is_array($c->redirect_uris) ? $c->redirect_uris : [];
  if (!in_array($redirect, $uris, true)) $uris[] = $redirect;
  $c->redirect_uris = $uris;
  $c->grant_types   = is_array($c->grant_types) ? array_values(array_unique(array_merge($c->grant_types,$grants))) : $grants;
  $c->save();
  return $c->id;
}

$tienda_id = upsert(getenv("TIENDA_NAME") ?: "tienda-web (local)", getenv("TIENDA_REDIRECT") ?: "http://localhost:5174/auth/callback");
$publ_id   = upsert(getenv("PUBL_NAME") ?: "publicadores-web (local)", getenv("PUBLICADORES_REDIRECT") ?: "http://localhost:5175/auth/callback");

echo "TIENDA_CLIENT_ID={$tienda_id}\nPUBLICADORES_CLIENT_ID={$publ_id}\n";
PHP
TIENDA_NAME="tienda-web (local)" PUBL_NAME="publicadores-web (local)" TIENDA_REDIRECT="${TIENDA_REDIRECT}" PUBLICADORES_REDIRECT="${PUBLICADORES_REDIRECT}" php /tmp/upsert_two.php
rm -f /tmp/upsert_two.php
')"

TIENDA_ID="$(echo "$IDS" | awk -F= '/^TIENDA_CLIENT_ID=/{print $2}')"
PUBLICADORES_ID="$(echo "$IDS" | awk -F= '/^PUBLICADORES_CLIENT_ID=/{print $2}')"

# Resumen y archivo auxiliar
{
  echo "# generado por dev-all.sh ($(date -Iseconds))"
  echo "TIENDA_CLIENT_ID=${TIENDA_ID}"
  echo "PUBLICADORES_CLIENT_ID=${PUBLICADORES_ID}"
  echo "TIENDA_REDIRECT=${TIENDA_REDIRECT}"
  echo "PUBLICADORES_REDIRECT=${PUBLICADORES_REDIRECT}"
} > sso_clients.env

echo "📋 Clientes creados/actualizados:"
echo "  - tienda-web (local):        CLIENT_ID=${TIENDA_ID}"
echo "  - publicadores-web (local):  CLIENT_ID=${PUBLICADORES_ID}"
echo "💾 También guardado en: sso_clients.env"

echo "🔄 (re)lanzando frontends con sso_clients.env..."
$COMPOSE --env-file sso_clients.env up -d web_tienda web_publicadores

echo "✅ Listo."
echo "   Tienda:        http://localhost:5174"
echo "   Publicadores:  http://localhost:5175"
echo "   IdP:           ${AUTH_URL}"
echo "   Authorize:     ${AUTH_URL}/oauth/authorize"
echo "   Token:         ${AUTH_URL}/oauth/token"
