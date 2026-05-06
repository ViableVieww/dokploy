#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/deploy-dokploy.sh
# Optional env overrides:
#   DOKPLOY_IMAGE=dokploy/dokploy:local
#   DOKPLOY_CONTAINER=dokploy
#   POSTGRES_CONTAINER=dokploy-postgres
#   POSTGRES_DB=dokploy
#   POSTGRES_USER=dokploy
#   POSTGRES_PASSWORD=change-me
#   APP_PORT=3000

DOKPLOY_IMAGE="${DOKPLOY_IMAGE:-dokploy/dokploy:local}"
DOKPLOY_CONTAINER="${DOKPLOY_CONTAINER:-dokploy}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-dokploy-postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-dokploy-redis}"
POSTGRES_DB="${POSTGRES_DB:-dokploy}"
POSTGRES_USER="${POSTGRES_USER:-dokploy}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-amukds4wi9001583845717ad2}"
APP_PORT="${APP_PORT:-3000}"
NETWORK_NAME="${NETWORK_NAME:-dokploy-net}"
ENABLE_SWARM_INIT="${ENABLE_SWARM_INIT:-true}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.production"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command '$1'"
    exit 1
  fi
}

require_cmd docker

if ! docker info >/dev/null 2>&1; then
  echo "Error: docker daemon is not running"
  exit 1
fi

if [ "${ENABLE_SWARM_INIT}" = "true" ]; then
  if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -qx "active"; then
    echo "==> Initializing Docker Swarm"
    docker swarm init >/dev/null || true
  fi
fi

echo "==> Preparing ${ENV_FILE}"
cat > "${ENV_FILE}" <<EOF
PORT=${APP_PORT}
NODE_ENV=production
DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_CONTAINER}:5432/${POSTGRES_DB}
EOF

echo "==> Ensuring network ${NETWORK_NAME}"
docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1 || docker network create "${NETWORK_NAME}"
docker network inspect "dokploy-network" >/dev/null 2>&1 || docker network create "dokploy-network"

echo "==> Starting postgres ${POSTGRES_CONTAINER}"
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

echo "==> Starting redis ${REDIS_CONTAINER}"
if docker ps -a --format '{{.Names}}' | grep -qx "${REDIS_CONTAINER}"; then
  docker start "${REDIS_CONTAINER}" >/dev/null
else
  docker run -d \
    --name "${REDIS_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    --restart unless-stopped \
    redis:7-alpine >/dev/null
fi

echo "==> Building ${DOKPLOY_IMAGE}"
docker build -t "${DOKPLOY_IMAGE}" -f "${ROOT_DIR}/Dockerfile" "${ROOT_DIR}"

echo "==> Replacing app container ${DOKPLOY_CONTAINER}"
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

docker network connect dokploy-network "${DOKPLOY_CONTAINER}" >/dev/null 2>&1 || true

echo "==> Ensuring Traefik exists"
echo "==> Preparing /etc/dokploy/traefik"
sudo mkdir -p /etc/dokploy/traefik/dynamic
if [ ! -f /etc/dokploy/traefik/traefik.yml ]; then
  sudo tee /etc/dokploy/traefik/traefik.yml >/dev/null <<'EOF'
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: dokploy-network
  file:
    directory: /etc/dokploy/traefik/dynamic
    watch: true
EOF
fi

if ! docker ps --format '{{.Names}}' | grep -qx "dokploy-traefik" \
  && ! docker service ls --format '{{.Name}}' 2>/dev/null | grep -qx "dokploy-traefik"; then
  echo "==> Traefik not found, starting standalone Traefik container"
  docker run -d \
    --name dokploy-traefik \
    --restart unless-stopped \
    --network dokploy-network \
    -p 80:80 \
    -p 443:443 \
    -v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml \
    -v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic \
    -v /var/run/docker.sock:/var/run/docker.sock \
    traefik:v3.6.7 >/dev/null || true
fi

echo "==> Done"
echo "Dokploy URL: http://localhost:${APP_PORT}"
echo "Logs: docker logs -f ${DOKPLOY_CONTAINER}"
