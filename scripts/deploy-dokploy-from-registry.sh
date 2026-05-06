#!/usr/bin/env bash
set -euo pipefail

# Pull and run Dokploy image from registry on target server.
#
# Usage:
#   DOKPLOY_IMAGE=yourdockeruser/dokploy:v0.29.2 ./scripts/deploy-dokploy-from-registry.sh
# Optional:
#   DOKPLOY_CONTAINER=dokploy
#   POSTGRES_CONTAINER=dokploy-postgres
#   POSTGRES_DB=dokploy
#   POSTGRES_USER=dokploy
#   POSTGRES_PASSWORD=change-me
#   APP_PORT=3000
#   NETWORK_NAME=dokploy-net

DOKPLOY_IMAGE="${DOKPLOY_IMAGE:-dokploy/dokploy:latest}"
DOKPLOY_CONTAINER="${DOKPLOY_CONTAINER:-dokploy}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-dokploy-postgres}"
POSTGRES_DB="${POSTGRES_DB:-dokploy}"
POSTGRES_USER="${POSTGRES_USER:-dokploy}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-amukds4wi9001583845717ad2}"
APP_PORT="${APP_PORT:-3000}"
NETWORK_NAME="${NETWORK_NAME:-dokploy-net}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: docker daemon is not running"
  exit 1
fi

echo "==> Pulling ${DOKPLOY_IMAGE}"
docker pull "${DOKPLOY_IMAGE}"

echo "==> Ensuring network ${NETWORK_NAME}"
docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1 || docker network create "${NETWORK_NAME}"

echo "==> Ensuring postgres ${POSTGRES_CONTAINER}"
if docker ps -a --format '{{.Names}}' | grep -qx "${POSTGRES_CONTAINER}"; then
  docker start "${POSTGRES_CONTAINER}" >/dev/null
else
  docker run -d \
    --name "${POSTGRES_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -v dokploy_postgres_data:/var/lib/postgresql/data \
    postgres:16-alpine >/dev/null
fi

echo "==> Replacing ${DOKPLOY_CONTAINER}"
if docker ps -a --format '{{.Names}}' | grep -qx "${DOKPLOY_CONTAINER}"; then
  docker rm -f "${DOKPLOY_CONTAINER}" >/dev/null
fi

docker run -d \
  --name "${DOKPLOY_CONTAINER}" \
  --network "${NETWORK_NAME}" \
  --restart unless-stopped \
  -p "${APP_PORT}:3000" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_CONTAINER}:5432/${POSTGRES_DB}" \
  "${DOKPLOY_IMAGE}" >/dev/null

echo "==> Done"
echo "Dokploy URL: http://localhost:${APP_PORT}"
echo "Logs: docker logs -f ${DOKPLOY_CONTAINER}"
