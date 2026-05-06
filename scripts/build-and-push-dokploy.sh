#!/usr/bin/env bash
set -euo pipefail

# Build and push Dokploy image to registry.
#
# Usage:
#   IMAGE_REPO=yourdockeruser/dokploy ./scripts/build-and-push-dokploy.sh
# Optional:
#   IMAGE_TAG=v0.29.2
#   PLATFORMS=linux/amd64,linux/arm64
#   PUSH_LATEST=true

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_REPO="${IMAGE_REPO:-dokploy/dokploy}"
IMAGE_TAG="${IMAGE_TAG:-$(node -p "require('${ROOT_DIR}/apps/dokploy/package.json').version")}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH_LATEST="${PUSH_LATEST:-true}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: docker daemon is not running"
  exit 1
fi

echo "==> Building and pushing ${IMAGE_REPO}:${IMAGE_TAG}"

if [ "${PUSH_LATEST}" = "true" ]; then
  docker buildx build \
    --platform "${PLATFORMS}" \
    --pull --rm \
    -t "${IMAGE_REPO}:${IMAGE_TAG}" \
    -t "${IMAGE_REPO}:latest" \
    -f "${ROOT_DIR}/Dockerfile" \
    --push \
    "${ROOT_DIR}"
else
  docker buildx build \
    --platform "${PLATFORMS}" \
    --pull --rm \
    -t "${IMAGE_REPO}:${IMAGE_TAG}" \
    -f "${ROOT_DIR}/Dockerfile" \
    --push \
    "${ROOT_DIR}"
fi

echo "==> Done"
echo "Pushed: ${IMAGE_REPO}:${IMAGE_TAG}"
