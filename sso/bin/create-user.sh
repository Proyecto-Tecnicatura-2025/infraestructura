#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local

EMAIL="${EMAIL:-leoalmada.dev@gmail.com}"
NAME="${NAME:-Leo Dev}"
PASS="${PASS:-3213214}"
UPDATE_PASS="${UPDATE_PASS:-0}"  # 1 = si existe, actualiza password

docker compose -f compose.yml exec -T \
  -e EMAIL="$EMAIL" -e NAME="$NAME" -e PASS="$PASS" -e UPDATE_PASS="$UPDATE_PASS" \
  backend bash -lc '
set -e
cat >/tmp/create_user.php <<'"'"'PHP'"'"'
<?php
chdir("/var/www/html");
require "vendor/autoload.php";
$app = require "bootstrap/app.php";

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap(); // 👈 importa: inicializa el contenedor, config, DB, etc.

use Illuminate\Support\Facades\DB;
use App\Models\User;

// esperar DB hasta 30s
$ok = false;
for ($i=0; $i<30; $i++) {
  try { DB::connection()->getPdo(); $ok = true; break; }
  catch (\Throwable $e) { sleep(1); }
}
if (!$ok) { fwrite(STDERR, "DB no disponible\n"); exit(1); }

$email = getenv("EMAIL") ?: "leoalmada.dev@gmail.com";
$name  = getenv("NAME")  ?: "Leo Dev";
$pass  = getenv("PASS")  ?: "3213214";
$updatePass = (getenv("UPDATE_PASS") === "1");

$u = User::where("email", $email)->first();
if (!$u) {
  $u = new User();
  $u->email = $email;
  $u->name  = $name;
  // evitar depender de bindings de Laravel (hash): usamos bcrypt nativo de PHP
  $u->password = password_hash($pass, PASSWORD_BCRYPT);
  $u->save();
  echo "CREATED id={$u->id} email={$u->email}\n";
} else {
  if ($updatePass) {
    $u->password = password_hash($pass, PASSWORD_BCRYPT);
    $u->save();
    echo "UPDATED id={$u->id} email={$u->email}\n";
  } else {
    echo "EXISTS  id={$u->id} email={$u->email}\n";
  }
}
PHP
php /tmp/create_user.php
rm -f /tmp/create_user.php
'
