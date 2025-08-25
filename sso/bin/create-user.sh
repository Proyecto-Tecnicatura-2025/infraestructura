#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local

EMAIL="${EMAIL:-leoalmada.dev@gmail.com}"
NAME="${NAME:-Leo Dev}"
PASS="${PASS:-3213214}"

docker compose -f compose.yml exec -T backend bash -lc "php artisan tinker --execute '
use App\\Models\\User;
\\$u = User::firstOrCreate([\"email\"=>\"$EMAIL\"],[\"name\"=>\"$NAME\",\"password\"=>bcrypt(\"$PASS\")]);
echo \"id=\\$u->id email=\\$u->email\\n\";
'"
