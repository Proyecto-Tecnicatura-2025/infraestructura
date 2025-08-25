#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local
[ -f .env.local ] && set -a && . ./.env.local && set +a
docker compose -f compose.yml up -d --build
docker compose -f compose.yml ps
