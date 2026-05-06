# Dokploy Shell Scripts

This folder contains helper scripts for building and deploying Dokploy.

## Prerequisites

- Docker installed and running
- Bash shell (Linux/macOS/WSL/Git Bash)
- Run commands from repo root (`dokploy/`)

---

## 1) Local build + local run

Script: `scripts/deploy-dokploy.sh`

What it does:
- Creates/updates `.env.production`
- Ensures Docker network exists
- Starts/creates Postgres (`dokploy-postgres`)
- Starts/creates Redis (`dokploy-redis`)
- Builds image `dokploy/dokploy:local`
- Replaces app container `dokploy`

Run:

```bash
chmod +x scripts/deploy-dokploy.sh
./scripts/deploy-dokploy.sh
```

Open:

`http://localhost:3000`

Logs:

```bash
docker logs -f dokploy
```

Useful overrides:

```bash
APP_PORT=3001 ./scripts/deploy-dokploy.sh
POSTGRES_PASSWORD='strong-password' ./scripts/deploy-dokploy.sh
```

---

## 2) Build and push image to registry

Script: `scripts/build-and-push-dokploy.sh`

What it does:
- Multi-platform build via `docker buildx`
- Pushes version tag (from `apps/dokploy/package.json`)
- Optionally pushes `latest`

Run:

```bash
chmod +x scripts/build-and-push-dokploy.sh
docker login
IMAGE_REPO=yourdockeruser/dokploy ./scripts/build-and-push-dokploy.sh
```

Useful overrides:

```bash
IMAGE_TAG=v0.29.2 IMAGE_REPO=yourdockeruser/dokploy ./scripts/build-and-push-dokploy.sh
PUSH_LATEST=false IMAGE_REPO=yourdockeruser/dokploy ./scripts/build-and-push-dokploy.sh
PLATFORMS=linux/amd64 IMAGE_REPO=yourdockeruser/dokploy ./scripts/build-and-push-dokploy.sh
```

---

## 3) Deploy from registry image (server/VPS)

Script: `scripts/deploy-dokploy-from-registry.sh`

What it does:
- Pulls image from registry
- Ensures network, Postgres container
- Replaces app container with pulled image

Run on target server:

```bash
chmod +x scripts/deploy-dokploy-from-registry.sh
DOKPLOY_IMAGE=yourdockeruser/dokploy:latest ./scripts/deploy-dokploy-from-registry.sh
```

Useful overrides:

```bash
APP_PORT=3001 DOKPLOY_IMAGE=yourdockeruser/dokploy:v0.29.2 ./scripts/deploy-dokploy-from-registry.sh
POSTGRES_PASSWORD='strong-password' DOKPLOY_IMAGE=yourdockeruser/dokploy:latest ./scripts/deploy-dokploy-from-registry.sh
```

---

## Recommended flows

### Local development changes
1. Edit code
2. Run `./scripts/deploy-dokploy.sh`
3. Test in browser

### Production-style deploy
1. Build and push:
   `IMAGE_REPO=yourdockeruser/dokploy ./scripts/build-and-push-dokploy.sh`
2. On server, pull and restart:
   `DOKPLOY_IMAGE=yourdockeruser/dokploy:latest ./scripts/deploy-dokploy-from-registry.sh`
