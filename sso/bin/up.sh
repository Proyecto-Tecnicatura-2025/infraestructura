#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME=sso_local
# usa .env.local si existe
[ -f .env.local ] && export $(grep -v '^#' .env.local | xargs)

docker compose -f compose.yml up -d --build
