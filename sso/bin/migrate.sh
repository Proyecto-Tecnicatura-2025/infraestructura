#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local
docker compose -f compose.yml exec -T backend bash -lc 'php artisan migrate --force'
