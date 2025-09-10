#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-sso_local}

# Parámetros
NAME="${NAME:-web-client (local)}"
REDIRECT="${REDIRECT:-http://localhost:5173/auth/callback}"
GRANTS_RAW="${GRANTS:-authorization_code,refresh_token}"

docker compose -f compose.yml exec -T \
  -e NAME="$NAME" -e REDIRECT="$REDIRECT" -e GRANTS_RAW="$GRANTS_RAW" \
  backend bash -lc '
set -e
cat >/tmp/upsert_client.php <<'"'"'PHP'"'"'
<?php
chdir("/var/www/html");
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Laravel\Passport\Client;

// Entradas
$name     = getenv("NAME") ?: "web-client (local)";
$redirect = getenv("REDIRECT") ?: "http://localhost:5173/auth/callback";
$grantsRaw= getenv("GRANTS_RAW") ?: "authorization_code,refresh_token";

// Normalizar grants (array único, sin vacíos)
$grants = array_values(array_unique(array_filter(array_map("trim", explode(",", $grantsRaw)))));
// Fallback razonable
if (!$grants) { $grants = ["authorization_code", "refresh_token"]; }

// Buscar por NOMBRE exacto y no revocado
$c = Client::query()->where("name", $name)->where("revoked", false)->first();

if (!$c) {
  $c = new Client();
  $c->name    = $name;
  $c->secret  = null;     // público (PKCE)
  $c->revoked = false;
  $c->redirect_uris = [$redirect];   // << arrays (casts en v13)
  $c->grant_types   = $grants;       // << arrays (casts en v13)
  $c->save();
} else {
  // Merge del redirect en la lista existente (único)
  $uris = is_array($c->redirect_uris) ? $c->redirect_uris : [];
  if (!in_array($redirect, $uris, true)) { $uris[] = $redirect; }
  $c->redirect_uris = $uris;
  $c->grant_types   = is_array($c->grant_types) ? array_values(array_unique(array_merge($c->grant_types, $grants))) : $grants;
  $c->secret        = null;
  $c->revoked       = false;
  $c->save();
}

echo $c->id;
PHP
php /tmp/upsert_client.php
rm -f /tmp/upsert_client.php
'
echo
