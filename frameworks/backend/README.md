# Backend Frameworks — Setup & Reference

Updated: April 2026

---

## FastAPI (Python) — Recommended

**Best for**: High-performance async Python APIs, ML service backends, type-safe APIs.

```bash
pip install fastapi uvicorn[standard] pydantic sqlalchemy alembic

# Create project
mkdir my-api && cd my-api
```

**Full project structure**:
```
my-api/
├── app/
│   ├── main.py
│   ├── routers/
│   │   ├── users.py
│   │   └── items.py
│   ├── models/
│   │   └── user.py
│   ├── schemas/
│   │   └── user.py
│   ├── services/
│   │   └── user_service.py
│   ├── db/
│   │   └── database.py
│   └── dependencies.py
├── tests/
├── alembic/
├── .env
└── requirements.txt
```

**`app/main.py`**:
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import users, items

app = FastAPI(
    title="My API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(items.router, prefix="/items", tags=["items"])

@app.get("/health")
def health():
    return {"status": "ok"}
```

**Router with dependencies**:
```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.schemas.user import UserCreate, UserResponse

router = APIRouter()

@router.get("/", response_model=list[UserResponse])
async def get_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    return db.query(User).offset(skip).limit(limit).all()

@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = User(**user.model_dump())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user
```

**Run**:
```bash
uvicorn app.main:app --reload --port 8000
# Docs: http://localhost:8000/docs
```

---

## Django + DRF (Python)

**Best for**: Full-featured web apps, admin UI, auth baked in.

```bash
pip install django djangorestframework django-cors-headers python-decouple

django-admin startproject myproject .
python manage.py startapp api
python manage.py migrate
python manage.py runserver
```

**settings.py key additions**:
```python
INSTALLED_APPS = [
    ...
    'rest_framework',
    'corsheaders',
    'api',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    ...
]

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

CORS_ALLOWED_ORIGINS = ['http://localhost:3000']
```

**ViewSet**:
```python
from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        user = self.get_object()
        user.is_active = True
        user.save()
        return Response({'status': 'activated'})
```

---

## Express.js (Node.js)

**Best for**: Flexible, minimal Node.js APIs, middleware ecosystem.

```bash
npm init -y
npm install express cors helmet morgan dotenv
npm install -D typescript @types/express @types/node ts-node nodemon
```

**`src/index.ts`**:
```typescript
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import morgan from 'morgan'
import { userRouter } from './routes/users'

const app = express()

app.use(helmet())
app.use(cors({ origin: process.env.FRONTEND_URL }))
app.use(morgan('dev'))
app.use(express.json())

app.use('/api/users', userRouter)

app.get('/health', (req, res) => {
  res.json({ status: 'ok' })
})

app.listen(process.env.PORT || 8000, () => {
  console.log('Server running on port 8000')
})
```

---

## NestJS (TypeScript)

**Best for**: Enterprise Node.js, Angular-like architecture, decorators, DI.

```bash
npm i -g @nestjs/cli
nest new my-api
cd my-api && npm run start:dev
```

**Module structure**:
```typescript
// users/users.controller.ts
import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common'
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger'
import { UsersService } from './users.service'
import { CreateUserDto } from './dto/create-user.dto'
import { JwtAuthGuard } from '../auth/jwt-auth.guard'

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll() {
    return this.usersService.findAll()
  }

  @Post()
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto)
  }
}
```

```bash
# Generate a full resource (CRUD)
nest g resource users
```

---

## Hono (TypeScript/Edge)

**Best for**: Ultra-fast APIs, edge runtimes (Cloudflare Workers, Bun, Deno), lightweight.

```bash
npm create hono@latest my-app
# or
bun create hono my-app
```

**`src/index.ts`**:
```typescript
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { jwt } from 'hono/jwt'
import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

const app = new Hono()

app.use('*', cors())
app.use('*', logger())

const userSchema = z.object({
  name: z.string().min(1),
  email: z.string().email()
})

app.get('/users', async (c) => {
  return c.json({ users: [] })
})

app.post('/users', zValidator('json', userSchema), async (c) => {
  const body = c.req.valid('json')
  return c.json({ created: body }, 201)
})

export default app
```

**Deploy to Cloudflare Workers**:
```bash
wrangler deploy
```

---

## Go Fiber

**Best for**: High-performance Go APIs, Express-like syntax.

```bash
mkdir my-api && cd my-api
go mod init my-api
go get github.com/gofiber/fiber/v2
```

**`main.go`**:
```go
package main

import (
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
)

func main() {
	app := fiber.New()

	app.Use(logger.New())
	app.Use(cors.New())

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	app.Get("/users", getUsers)
	app.Post("/users", createUser)

	app.Listen(":8000")
}

func getUsers(c *fiber.Ctx) error {
	return c.JSON([]map[string]string{{"name": "Alice"}})
}

func createUser(c *fiber.Ctx) error {
	var body map[string]string
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(body)
}
```

```bash
go run main.go
```

---

## Fastify (Node.js)

**Best for**: Fastest Node.js HTTP server, plugin architecture, schema validation.

```bash
npm install fastify @fastify/cors @fastify/jwt zod
```

```typescript
import Fastify from 'fastify'
import cors from '@fastify/cors'

const app = Fastify({ logger: true })

await app.register(cors, { origin: true })

app.get('/health', async () => ({ status: 'ok' }))

app.post<{ Body: { name: string } }>('/users', {
  schema: {
    body: {
      type: 'object',
      required: ['name'],
      properties: { name: { type: 'string' } }
    }
  }
}, async (request, reply) => {
  return reply.status(201).send({ name: request.body.name })
})

await app.listen({ port: 8000, host: '0.0.0.0' })
```

---

## Axum (Rust)

**Best for**: Memory-safe, high-performance APIs.

```bash
cargo new my-api && cd my-api
# Cargo.toml dependencies:
# axum = "0.8"
# tokio = { version = "1", features = ["full"] }
# serde = { version = "1", features = ["derive"] }
```

```rust
use axum::{routing::get, Router, Json};
use serde::{Deserialize, Serialize};

#[derive(Serialize)]
struct User { name: String }

async fn get_users() -> Json<Vec<User>> {
    Json(vec![User { name: "Alice".into() }])
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/users", get(get_users));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

---

## API Design Best Practices

### REST vs GraphQL vs tRPC vs gRPC

| Protocol | Best For | Libraries |
|---|---|---|
| REST | Public APIs, mobile | Express, FastAPI, Hono |
| GraphQL | Flexible queries, BFF | Apollo, Pothos, Strawberry |
| tRPC | TypeScript full-stack | tRPC, Next.js |
| gRPC | Microservices, low-latency | grpc-node, grpcio |

### Authentication patterns

```bash
# JWT with refresh tokens (most common)
npm install jsonwebtoken bcrypt
pip install python-jose[cryptography] passlib

# OAuth2 / Social login
npm install next-auth    # Next.js
pip install authlib      # Python

# API keys
# Store hashed in DB, validate on each request
```

### Docker for any backend
```dockerfile
# FastAPI
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# Node.js (NestJS/Express/Hono)
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/main.js"]
```
