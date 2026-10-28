# Databases & ORMs — Setup & Reference

Updated: April 2026

---

## Prisma (TypeScript ORM) — Recommended

**Best for**: Type-safe database access in TypeScript/Next.js.

```bash
npm install prisma @prisma/client
npx prisma init --datasource-provider postgresql
```

**`prisma/schema.prisma`**:
```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  role      Role     @default(USER)
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
}

enum Role {
  USER
  ADMIN
}
```

**Commands**:
```bash
npx prisma migrate dev --name init       # create migration + apply
npx prisma migrate deploy                # apply in production
npx prisma db push                       # push schema without migration
npx prisma generate                      # regenerate client
npx prisma studio                        # GUI at http://localhost:5555
npx prisma db seed                       # run seed script
```

**Usage**:
```typescript
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

// Find many with filters
const users = await prisma.user.findMany({
  where: {
    role: 'ADMIN',
    createdAt: { gte: new Date('2026-01-01') }
  },
  include: { posts: { where: { published: true } } },
  orderBy: { createdAt: 'desc' },
  take: 10,
  skip: 0
})

// Create
const user = await prisma.user.create({
  data: {
    email: 'alice@example.com',
    name: 'Alice',
    posts: {
      create: { title: 'First Post', published: true }
    }
  }
})

// Upsert
const upserted = await prisma.user.upsert({
  where: { email: 'alice@example.com' },
  update: { name: 'Alice Smith' },
  create: { email: 'alice@example.com', name: 'Alice Smith' }
})

// Transaction
const [post, user] = await prisma.$transaction([
  prisma.post.update({ where: { id: '1' }, data: { published: true } }),
  prisma.user.update({ where: { id: '1' }, data: { name: 'Bob' } })
])

// Raw SQL
const result = await prisma.$queryRaw`
  SELECT * FROM users WHERE email ILIKE ${`%${search}%`}
`
```

---

## Drizzle ORM

**Best for**: Lightweight TypeScript ORM, SQL-like API, excellent for edge runtimes.

```bash
npm install drizzle-orm pg
npm install -D drizzle-kit @types/pg
```

**`src/db/schema.ts`**:
```typescript
import { pgTable, serial, text, boolean, timestamp, varchar } from 'drizzle-orm/pg-core'
import { relations } from 'drizzle-orm'

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: text('name'),
  createdAt: timestamp('created_at').defaultNow()
})

export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: text('title').notNull(),
  published: boolean('published').default(false),
  authorId: serial('author_id').references(() => users.id)
})

export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts)
}))
```

**`drizzle.config.ts`**:
```typescript
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! }
})
```

**Usage**:
```typescript
import { drizzle } from 'drizzle-orm/node-postgres'
import { Pool } from 'pg'
import { eq, and, like, desc } from 'drizzle-orm'
import { users, posts } from './schema'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const db = drizzle(pool, { schema: { users, posts } })

// Select
const allUsers = await db.select().from(users).orderBy(desc(users.createdAt))

// With filter
const admins = await db.select().from(users).where(eq(users.role, 'admin'))

// Join
const usersWithPosts = await db
  .select()
  .from(users)
  .leftJoin(posts, eq(posts.authorId, users.id))
  .where(eq(posts.published, true))

// Insert
const [newUser] = await db.insert(users).values({ email: 'a@b.com', name: 'Alice' }).returning()

// Update
await db.update(users).set({ name: 'Bob' }).where(eq(users.id, 1))

// Delete
await db.delete(users).where(eq(users.id, 1))
```

```bash
npx drizzle-kit generate    # generate migration
npx drizzle-kit migrate     # run migrations
npx drizzle-kit studio      # GUI
```

---

## SQLAlchemy (Python)

```bash
pip install sqlalchemy asyncpg alembic
# OR with sync
pip install sqlalchemy psycopg2-binary
```

**Models**:
```python
from sqlalchemy import Column, String, Boolean, ForeignKey, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, nullable=False, index=True)
    name = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    posts = relationship("Post", back_populates="author")

class Post(Base):
    __tablename__ = "posts"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    published = Column(Boolean, default=False)
    author_id = Column(String, ForeignKey("users.id"))

    author = relationship("User", back_populates="posts")
```

**Async with FastAPI**:
```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy import select

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session

# Usage in FastAPI route
async def get_users(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    return result.scalars().all()
```

**Alembic migrations**:
```bash
alembic init alembic
alembic revision --autogenerate -m "create users table"
alembic upgrade head
alembic downgrade -1
```

---

## Database Options by Use Case

| Database | Type | Best For | Hosted Options |
|---|---|---|---|
| PostgreSQL | Relational | General purpose, JSON, vectors | Neon, Supabase, RDS |
| MySQL | Relational | Web apps, WordPress | PlanetScale, RDS |
| SQLite | Embedded | Local dev, edge, small apps | Turso, Cloudflare D1 |
| MongoDB | Document | Flexible schema, JSON docs | Atlas |
| Redis | Key-Value/Cache | Sessions, caching, queues | Upstash, Redis Cloud |
| Qdrant | Vector | AI embeddings, RAG | Qdrant Cloud |
| Chroma | Vector | Local RAG | Self-hosted |
| ClickHouse | Columnar | Analytics, time-series | ClickHouse Cloud |
| DynamoDB | NoSQL | AWS-native, serverless | AWS |
| Cassandra | Wide-column | High write throughput | Astra DB |

---

## Serverless Database Setup

### Neon (PostgreSQL serverless)
```bash
# .env
DATABASE_URL=postgresql://user:pass@ep-xxx.us-east-1.aws.neon.tech/mydb?sslmode=require

# With connection pooling
DATABASE_URL=postgresql://user:pass@ep-xxx-pooler.us-east-1.aws.neon.tech/mydb

npm install @neondatabase/serverless
```

```typescript
import { neon } from '@neondatabase/serverless'

const sql = neon(process.env.DATABASE_URL!)
const result = await sql`SELECT * FROM users WHERE id = ${userId}`
```

### Supabase (PostgreSQL + Auth + Storage)
```bash
npm install @supabase/supabase-js
```

```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

// Query
const { data, error } = await supabase
  .from('users')
  .select('*, posts(*)')
  .eq('role', 'admin')
  .order('created_at', { ascending: false })

// Realtime subscription
const subscription = supabase
  .channel('users')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, payload => {
    console.log('Change received:', payload)
  })
  .subscribe()

// Auth
const { data: { user } } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password'
})
```

### Turso (SQLite at the edge)
```bash
npm install @libsql/client
```

```typescript
import { createClient } from '@libsql/client'

const db = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!
})

const result = await db.execute('SELECT * FROM users WHERE id = ?', [userId])
```

---

## Redis / Upstash

```bash
npm install ioredis
# OR serverless:
npm install @upstash/redis
```

```typescript
// Upstash (serverless, edge-compatible)
import { Redis } from '@upstash/redis'

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!
})

// Cache
await redis.set('user:1', JSON.stringify(user), { ex: 3600 })
const cached = await redis.get<User>('user:1')

// Rate limiting
const requests = await redis.incr(`ratelimit:${ip}`)
await redis.expire(`ratelimit:${ip}`, 60)
if (requests > 100) throw new Error('Rate limit exceeded')

// Session store
await redis.hset(`session:${sessionId}`, { userId, expiresAt })
```
