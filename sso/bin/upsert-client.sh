#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local
# Carga puertos / vars
[ -f .env.local ] && export $(grep -v '^#' .env.local | xargs)
REDIRECT="http://localhost:${WEB_PORT:-5173}/auth/callback"

CID=$(docker compose -f compose.yml exec -T oauth bash -lc "php artisan tinker --execute '
\\$c=\\Laravel\\Passport\\Client::firstOrNew([\"name\"=>\"web-client (local)\"]);
\\$c->secret=null; \\$c->revoked=0;
\\$c->forceFill([
  \"redirect_uris\"=>json_encode([\"$REDIRECT\"]),
  \"grant_types\"=>json_encode([\"authorization_code\",\"refresh_token\"])
])->save();
echo \\$c->id;
'")

echo "client_id=$CID"
# Si querés, persistilo en .env.local:
if grep -q '^VITE_OAUTH_CLIENT_ID=' .env.local 2>/dev/null; then
  sed -i "s|^VITE_OAUTH_CLIENT_ID=.*|VITE_OAUTH_CLIENT_ID=$CID|" .env.local
else
  echo "VITE_OAUTH_CLIENT_ID=$CID" >> .env.local
fi
echo "Actualizado VITE_OAUTH_CLIENT_ID en .env.local"
