# Docker Setup — Local Development Reference

Docker Desktop, Compose, useful images, and local dev workflows.
Updated: April 2026.

---

## Install

```bash
# macOS
brew install --cask docker

# Linux (Ubuntu)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER    # add user to docker group (re-login required)
newgrp docker

# Verify
docker --version
docker compose version
docker run hello-world
```

---

## Docker Essentials

### Images

```bash
docker pull ubuntu:24.04            # pull image
docker images                       # list local images
docker rmi ubuntu:24.04             # remove image
docker image prune                  # remove dangling images
docker image prune -a               # remove all unused images

# Build image
docker build -t myapp:latest .
docker build -t myapp:1.0 -f Dockerfile.prod .
docker build --no-cache -t myapp .  # force rebuild

# Tag and push
docker tag myapp:latest myrepo/myapp:latest
docker push myrepo/myapp:latest
```

### Containers

```bash
# Run
docker run nginx                    # foreground
docker run -d nginx                 # detached (background)
docker run -d -p 8080:80 nginx      # port mapping (host:container)
docker run -d --name webserver -p 8080:80 nginx

# Interactive
docker run -it ubuntu bash          # interactive with TTY
docker run --rm -it python:3.13 python  # auto-remove on exit

# Volumes
docker run -v /host/path:/container/path nginx    # bind mount
docker run -v myvolume:/data nginx                # named volume

# Environment variables
docker run -e DATABASE_URL=postgres://... myapp
docker run --env-file .env myapp

# Resource limits
docker run --memory="512m" --cpus="1.5" myapp

# Lifecycle
docker ps                           # running containers
docker ps -a                        # all containers
docker stop webserver               # graceful stop
docker kill webserver               # force kill
docker rm webserver                 # remove container
docker restart webserver            # restart

# Exec into running container
docker exec -it webserver bash
docker exec webserver ls /etc/nginx

# Logs
docker logs webserver               # all logs
docker logs -f webserver            # follow
docker logs --tail=50 webserver     # last 50 lines
docker logs --since=1h webserver    # last hour

# Copy files
docker cp webserver:/etc/nginx/nginx.conf ./nginx.conf
docker cp ./config.json webserver:/app/config.json

# Inspect
docker inspect webserver
docker stats                        # live resource usage
docker top webserver                # processes inside
```

### Volumes

```bash
docker volume create mydata
docker volume ls
docker volume inspect mydata
docker volume rm mydata
docker volume prune                 # remove unused volumes
```

### Networks

```bash
docker network create mynet
docker network ls
docker network inspect mynet
docker network rm mynet

# Run container in network
docker run -d --network mynet --name db postgres:17

# Connect existing container
docker network connect mynet webserver
docker network disconnect mynet webserver
```

---

## Dockerfile Reference

### Multi-stage build (Node.js)

```dockerfile
# syntax=docker/dockerfile:1

# ── Stage 1: Dependencies ─────────────────────────────────────────────────────
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# ── Stage 2: Build ────────────────────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm run build

# ── Stage 3: Production ───────────────────────────────────────────────────────
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Non-root user
RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000 HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
```

### Python (FastAPI)

```dockerfile
FROM python:3.13-slim

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-dev

# Copy application
COPY app/ ./app/

# Non-root user
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Go

```dockerfile
FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server ./cmd/server

FROM scratch
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### `.dockerignore`

```
.git
.gitignore
node_modules
.next
dist
__pycache__
*.pyc
.venv
.env
.env.local
*.log
.DS_Store
Dockerfile*
docker-compose*
README.md
```

---

## Docker Compose

### Basic `docker-compose.yml`

```yaml
version: "3.9"

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - .:/app                       # for development hot-reload
      - /app/node_modules            # don't mount host node_modules
    restart: unless-stopped

  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: myapp
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --save 60 1 --loglevel warning
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### Compose commands

```bash
docker compose up                   # start all services (foreground)
docker compose up -d                # start all (detached)
docker compose up -d db redis       # start specific services

docker compose down                 # stop and remove containers
docker compose down -v              # also remove volumes

docker compose ps                   # list service containers
docker compose logs                 # all logs
docker compose logs -f app          # follow app logs

docker compose exec app bash        # exec into service
docker compose run --rm app pytest  # one-off command

docker compose build                # build images
docker compose build --no-cache     # force rebuild
docker compose pull                 # pull latest images

docker compose restart app          # restart a service
docker compose stop                 # stop without removing

# Scale a service
docker compose up -d --scale app=3
```

---

## Local Dev Stacks

### Full-stack web app

```yaml
# docker-compose.dev.yml
services:
  postgres:
    image: postgres:17-alpine
    environment: { POSTGRES_PASSWORD: dev, POSTGRES_DB: mydb }
    ports: ["5432:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  adminer:
    image: adminer
    ports: ["8080:8080"]          # DB admin UI

volumes:
  postgres_data:
```

```bash
docker compose -f docker-compose.dev.yml up -d
```

### AI / ML local stack

```yaml
# docker-compose.ai.yml
services:
  ollama:
    image: ollama/ollama
    ports: ["11434:11434"]
    volumes: [ollama:/root/.ollama]

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    ports: ["3000:8080"]
    environment:
      OLLAMA_BASE_URL: http://ollama:11434
    depends_on: [ollama]
    volumes: [open-webui:/app/backend/data]

  qdrant:
    image: qdrant/qdrant
    ports: ["6333:6333", "6334:6334"]
    volumes: [qdrant:/qdrant/storage]

volumes:
  ollama:
  open-webui:
  qdrant:
```

### Kafka

```yaml
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.7.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.7.0
    depends_on: [zookeeper]
    ports: ["9092:9092"]
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"

  kafka-ui:
    image: provectuslabs/kafka-ui
    ports: ["8080:8080"]
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
```

---

## System Cleanup

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Remove everything (nuclear option)
docker system prune -af --volumes

# Check disk usage
docker system df
```

---

## Docker Tips

```bash
# Check image layers and size
docker history myimage:latest
docker image inspect myimage:latest | jq '.[].Size'

# Run temporary database for testing
docker run --rm -d \
  -e POSTGRES_PASSWORD=test \
  -p 5432:5432 \
  postgres:17-alpine

# One-liner: spin up Redis for dev
docker run --rm -d -p 6379:6379 --name redis redis:7-alpine

# One-liner: Adminer for any database
docker run --rm -d -p 8080:8080 --name adminer adminer

# Port scan a container
docker exec mycontainer netstat -tlnp

# Copy from container to host
docker cp mycontainer:/var/log/nginx/error.log ./nginx-error.log

# Export and import image (offline transfer)
docker save myimage:latest | gzip > myimage.tar.gz
docker load < myimage.tar.gz
```
