# Docker - Containerization Platform

## Overview

Docker is an open-source platform that automates the deployment, scaling, and management of applications using **containerization**. Containers package an application and all its dependencies into a standardized unit, ensuring consistency across development, testing, and production environments.

Unlike virtual machines, containers share the host OS kernel, making them lightweight, fast to start, and efficient with system resources.

## Why Use Docker?

| Benefit | Description |
|---|---|
| **Consistency** | "Works on my machine" is eliminated -- containers behave identically everywhere |
| **Isolation** | Each container runs in its own namespace with its own filesystem, network, and process tree |
| **Portability** | Build once, run anywhere -- local, cloud, CI/CD, or on-prem |
| **Efficiency** | Containers share the host kernel, using far less overhead than VMs |
| **Speed** | Containers start in milliseconds compared to minutes for VMs |
| **Microservices** | Ideal for decomposing monoliths into independently deployable services |
| **DevOps Integration** | First-class support in every major CI/CD system |

## Installation

### macOS

```bash
# Option 1: Docker Desktop (recommended for local development)
brew install --cask docker

# Option 2: Colima (lightweight alternative, no Docker Desktop license needed)
brew install docker docker-compose colima
colima start
```

### Linux (Ubuntu/Debian)

```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install via official repository
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Run Docker without sudo
sudo usermod -aG docker $USER
newgrp docker
```

### Windows

```powershell
# Option 1: Docker Desktop (requires WSL 2)
winget install Docker.DockerDesktop

# Option 2: Install via WSL 2
wsl --install
# Then install Docker Engine inside your WSL distribution
```

### Verify Installation

```bash
docker --version
docker run hello-world
```

## Basic Configuration

### Docker Daemon Configuration (`/etc/docker/daemon.json`)

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    { "base": "172.20.0.0/16", "size": 24 }
  ],
  "features": {
    "buildkit": true
  },
  "storage-driver": "overlay2"
}
```

### BuildKit (Default in Modern Docker)

BuildKit is the next-generation build engine. It provides:
- Parallel build stages
- Better caching
- Build secrets support
- SSH forwarding during builds

```bash
# Ensure BuildKit is enabled (default since Docker 23.0)
export DOCKER_BUILDKIT=1
```

## Dockerfile Best Practices

### Basic Dockerfile

```dockerfile
# Use specific tags, never 'latest' in production
FROM python:3.12-slim AS base

# Set metadata
LABEL maintainer="you@example.com"
LABEL version="1.0"

# Set working directory
WORKDIR /app

# Copy dependency files first (cache optimization)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Use non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

# Document the port (does not publish it)
EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Prefer exec form for CMD
CMD ["python", "app.py"]
```

### Multi-Stage Build

Multi-stage builds drastically reduce final image size by separating the build environment from the runtime environment.

```dockerfile
# ---- Build Stage ----
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# ---- Runtime Stage ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### Key Dockerfile Best Practices

1. **Pin base image versions** -- use `python:3.12.3-slim`, not `python:latest`
2. **Minimize layers** -- combine related `RUN` commands with `&&`
3. **Order instructions by change frequency** -- put rarely changing instructions first
4. **Use `.dockerignore`** -- exclude `.git`, `node_modules`, `__pycache__`, etc.
5. **Never store secrets in images** -- use build secrets or runtime injection
6. **Use multi-stage builds** -- separate build tools from runtime
7. **Prefer `COPY` over `ADD`** -- `ADD` auto-extracts tarballs and fetches URLs, which can be unexpected
8. **Run as non-root** -- always create and switch to an unprivileged user

### Example `.dockerignore`

```
.git
.gitignore
node_modules
*.md
docker-compose*.yml
.env
.env.*
__pycache__
*.pyc
```

## Docker Compose

Docker Compose defines and runs multi-container applications using a YAML file.

```yaml
# docker-compose.yml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/mydb
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./src:/app/src   # bind mount for development
    networks:
      - backend

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - backend

  redis:
    image: redis:7-alpine
    networks:
      - backend

volumes:
  pgdata:

networks:
  backend:
    driver: bridge
```

## Common Commands Cheat Sheet

### Images

```bash
docker build -t myapp:1.0 .                # Build image
docker build --no-cache -t myapp:1.0 .      # Build without cache
docker images                                # List images
docker rmi myapp:1.0                         # Remove image
docker image prune -a                        # Remove all unused images
docker tag myapp:1.0 registry/myapp:1.0      # Tag image
docker push registry/myapp:1.0               # Push to registry
```

### Containers

```bash
docker run -d --name web -p 8080:80 nginx    # Run detached
docker run -it --rm ubuntu bash              # Run interactive, remove on exit
docker ps                                     # List running containers
docker ps -a                                  # List all containers
docker stop web                               # Stop container
docker rm web                                 # Remove container
docker logs -f web                            # Follow logs
docker exec -it web /bin/sh                   # Exec into container
docker inspect web                            # Inspect container details
docker stats                                  # Live resource usage
```

### Volumes

```bash
docker volume create mydata                   # Create named volume
docker volume ls                              # List volumes
docker volume inspect mydata                  # Inspect volume
docker volume rm mydata                       # Remove volume
docker volume prune                           # Remove unused volumes
```

### Networking

```bash
docker network create mynet                   # Create network
docker network ls                             # List networks
docker network inspect mynet                  # Inspect network
docker network connect mynet web              # Attach container to network
docker network disconnect mynet web           # Detach container from network
```

### Compose

```bash
docker compose up -d                          # Start services (detached)
docker compose down                           # Stop and remove containers
docker compose down -v                        # Also remove volumes
docker compose logs -f web                    # Follow logs for a service
docker compose ps                             # List services
docker compose exec web sh                    # Exec into a service container
docker compose build                          # Rebuild images
docker compose pull                           # Pull latest images
```

### Cleanup

```bash
docker system prune                           # Remove unused data
docker system prune -a --volumes              # Aggressive cleanup (everything unused)
docker system df                              # Show disk usage
```

## Networking

Docker provides several network drivers:

| Driver | Use Case |
|---|---|
| `bridge` | Default. Isolated network for containers on a single host |
| `host` | Container shares the host network stack (no isolation) |
| `overlay` | Multi-host networking for Swarm or distributed setups |
| `macvlan` | Assign a MAC address to a container, making it appear as a physical device |
| `none` | No networking |

### Best Practices for Networking

- Use **user-defined bridge networks** instead of the default bridge -- they provide DNS resolution by container name
- Avoid `--network host` in production unless you have a specific performance reason
- Use `expose` in Dockerfiles for documentation; use `ports` in Compose to actually publish

## Volumes and Storage

| Type | Syntax | Use Case |
|---|---|---|
| Named volume | `mydata:/app/data` | Persistent data managed by Docker |
| Bind mount | `./local:/app/data` | Development -- reflects host filesystem changes |
| tmpfs | `--tmpfs /tmp` | Temporary data that should not persist |

## Security Best Practices

1. **Run as non-root** -- always use `USER` in Dockerfiles
2. **Use read-only filesystems** -- `docker run --read-only`
3. **Drop capabilities** -- `docker run --cap-drop ALL --cap-add NET_BIND_SERVICE`
4. **Scan images for vulnerabilities** -- use Docker Scout, Trivy, or Snyk
5. **Sign images** -- use Docker Content Trust (`export DOCKER_CONTENT_TRUST=1`)
6. **Use distroless or scratch base images** when possible
7. **Never hardcode secrets** -- use Docker Secrets, environment variables, or a vault
8. **Set resource limits** -- `--memory`, `--cpus` flags or Compose `deploy.resources`
9. **Keep images updated** -- rebuild regularly to pick up security patches

## Modern Docker Features

### Docker Scout

Docker Scout analyzes container images for vulnerabilities and provides remediation advice.

```bash
# Analyze an image
docker scout cves myapp:latest

# Compare two image versions
docker scout compare myapp:1.0 myapp:2.0

# Get quickview of image health
docker scout quickview myapp:latest
```

### Docker Init

Generates Dockerfiles, Compose files, and `.dockerignore` for your project automatically.

```bash
# Run in your project root
docker init

# It detects your language/framework and generates:
#   - Dockerfile
#   - docker-compose.yml
#   - .dockerignore
```

### Docker Build Cloud

Offload builds to the cloud for faster CI and cross-platform compilation.

```bash
docker buildx create --driver cloud myorg/mybuilder
docker buildx build --builder cloud-myorg-mybuilder --tag myapp:1.0 .
```

## Resources

- [Official Docker Documentation](https://docs.docker.com/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Docker Compose Specification](https://docs.docker.com/compose/compose-file/)
- [Docker Hub](https://hub.docker.com/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [BuildKit Documentation](https://docs.docker.com/build/buildkit/)
- [Docker Scout](https://docs.docker.com/scout/)
- [Awesome Docker (GitHub)](https://github.com/veggiemonk/awesome-docker)
