#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local
[ -f .env.local ] && set -a && . ./.env.local && set +a
WEB_PORT="${WEB_PORT:-5173}"
REDIRECT="http://localhost:${WEB_PORT}/auth/callback"

PHP_CODE='$redirect = getenv("REDIRECT") ?: "http://localhost:5173/auth/callback";
$c = Laravel\Passport\Client::firstOrNew(["name" => "web-client (local)"]);
$c->name    = "web-client (local)";
$c->secret  = null;                  // público (PKCE)
$c->revoked = 0;
$c->redirect_uris = [$redirect];     // 👈 arrays, no json_encode
$c->grant_types   = ["authorization_code","refresh_token"];
$c->save();
echo $c->id;'

CID=$(docker compose -f compose.yml exec -T \
  -e REDIRECT="$REDIRECT" \
  backend php artisan tinker --execute "$PHP_CODE" \
  | tail -n1 | tr -d '\r\n')

echo "client_id=${CID}"

# persistir en .env.local
if [ ! -f .env.local ]; then cp .env.example .env.local || true; fi
if grep -q '^VITE_OAUTH_CLIENT_ID=' .env.local; then
  sed -i -E "s|^VITE_OAUTH_CLIENT_ID=.*|VITE_OAUTH_CLIENT_ID=${CID}|" .env.local
else
  printf "\nVITE_OAUTH_CLIENT_ID=%s\n" "${CID}" >> .env.local
fi

# recrear front para inyectar env
set -a; . ./.env.local; set +a
docker compose -f compose.yml up -d web_client
