# Full-Stack Frameworks & Stacks — Setup & Reference

Updated: April 2026

---

## T3 Stack — Most Popular TypeScript Full-Stack

**Stack**: Next.js + tRPC + Prisma + Tailwind CSS + NextAuth

```bash
npm create t3-app@latest my-app

# Choose:
# ✅ TypeScript
# ✅ Tailwind CSS
# ✅ tRPC
# ✅ Prisma
# ✅ NextAuth.js (Auth.js)

cd my-app && npm run dev
```

**Project structure**:
```
my-app/
├── src/
│   ├── app/                   # Next.js App Router
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── api/trpc/[trpc]/route.ts
│   ├── server/
│   │   ├── api/
│   │   │   ├── routers/
│   │   │   │   └── user.ts    # tRPC router
│   │   │   ├── root.ts        # Root router
│   │   │   └── trpc.ts        # tRPC config
│   │   ├── auth.ts            # Auth.js config
│   │   └── db.ts              # Prisma client
│   ├── trpc/
│   │   ├── react.tsx          # Client-side hooks
│   │   └── server.ts          # Server-side caller
│   └── styles/
│       └── globals.css
├── prisma/
│   └── schema.prisma
└── .env
```

**tRPC router**:
```typescript
// src/server/api/routers/user.ts
import { z } from "zod"
import { createTRPCRouter, protectedProcedure, publicProcedure } from "@/server/api/trpc"

export const userRouter = createTRPCRouter({
  // Public query
  getAll: publicProcedure.query(async ({ ctx }) => {
    return ctx.db.user.findMany()
  }),

  // Protected mutation
  create: protectedProcedure
    .input(z.object({ name: z.string().min(1), email: z.string().email() }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.user.create({ data: input })
    }),

  // By ID
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.db.user.findUnique({ where: { id: input.id } })
    }),
})
```

**Client usage**:
```typescript
// In a React component
import { api } from "@/trpc/react"

function UserList() {
  const { data: users, isLoading } = api.user.getAll.useQuery()
  const createUser = api.user.create.useMutation({
    onSuccess: () => utils.user.getAll.invalidate()
  })

  return (
    <div>
      {users?.map(u => <div key={u.id}>{u.name}</div>)}
      <button onClick={() => createUser.mutate({ name: "Alice", email: "a@b.com" })}>
        Add User
      </button>
    </div>
  )
}
```

---

## Remix

**Best for**: Full-stack React with web platform primitives, progressive enhancement.

```bash
npx create-remix@latest my-app
cd my-app && npm run dev
```

**Route with loader + action**:
```typescript
// app/routes/users.$id.tsx
import { json, redirect } from "@remix-run/node"
import { useLoaderData, Form, useNavigation } from "@remix-run/react"
import type { LoaderFunctionArgs, ActionFunctionArgs } from "@remix-run/node"

export async function loader({ params }: LoaderFunctionArgs) {
  const user = await db.user.findUnique({ where: { id: params.id } })
  if (!user) throw new Response("Not Found", { status: 404 })
  return json({ user })
}

export async function action({ request, params }: ActionFunctionArgs) {
  const formData = await request.formData()
  const name = formData.get("name") as string

  await db.user.update({
    where: { id: params.id },
    data: { name }
  })

  return redirect(`/users/${params.id}`)
}

export default function UserDetail() {
  const { user } = useLoaderData<typeof loader>()
  const navigation = useNavigation()
  const isSubmitting = navigation.state === "submitting"

  return (
    <Form method="post">
      <input name="name" defaultValue={user.name} />
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Saving..." : "Save"}
      </button>
    </Form>
  )
}
```

---

## SvelteKit

**Best for**: Svelte full-stack, excellent DX, minimal JS shipped.

```bash
npx sv create my-app
# Choose: SvelteKit minimal, TypeScript, Tailwind

cd my-app && npm run dev
```

**Route with server load + form actions**:
```typescript
// src/routes/users/+page.server.ts
import type { PageServerLoad, Actions } from './$types'
import { fail, redirect } from '@sveltejs/kit'

export const load: PageServerLoad = async ({ locals }) => {
  const users = await db.user.findMany()
  return { users }
}

export const actions: Actions = {
  create: async ({ request }) => {
    const data = await request.formData()
    const name = data.get('name') as string

    if (!name) return fail(400, { error: 'Name required' })

    await db.user.create({ data: { name } })
    throw redirect(303, '/users')
  }
}
```

```svelte
<!-- src/routes/users/+page.svelte -->
<script lang="ts">
  import { enhance } from '$app/forms'
  export let data
  export let form
</script>

<ul>
  {#each data.users as user}
    <li>{user.name}</li>
  {/each}
</ul>

<form method="POST" action="?/create" use:enhance>
  <input name="name" required />
  {#if form?.error}
    <p class="text-red-500">{form.error}</p>
  {/if}
  <button type="submit">Add User</button>
</form>
```

---

## Nuxt 3

**Best for**: Vue full-stack, SSR/SSG, auto-imports, zero-config.

```bash
npx nuxi@latest init my-app
cd my-app && npm run dev
```

**Server API routes**:
```typescript
// server/api/users/index.get.ts
export default defineEventHandler(async (event) => {
  return await db.user.findMany()
})

// server/api/users/index.post.ts
export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  return await db.user.create({ data: body })
})
```

**Composables (auto-imported)**:
```vue
<!-- pages/users.vue -->
<script setup lang="ts">
const { data: users, refresh } = await useFetch('/api/users')
const newName = ref('')

async function createUser() {
  await $fetch('/api/users', {
    method: 'POST',
    body: { name: newName.value }
  })
  await refresh()
  newName.value = ''
}
</script>

<template>
  <ul>
    <li v-for="user in users" :key="user.id">{{ user.name }}</li>
  </ul>
  <input v-model="newName" />
  <button @click="createUser">Add</button>
</template>
```

---

## RedwoodJS

**Best for**: React + GraphQL + Prisma, batteries-included.

```bash
yarn create redwood-app my-app --typescript
cd my-app && yarn redwood dev
```

---

## Backend for Frontend (BFF) with tRPC

**No Remix/Next.js — standalone tRPC server + React client**:

```bash
# Server
npm install @trpc/server zod express cors

# Client
npm install @trpc/client @trpc/react-query @tanstack/react-query
```

---

## Monorepo Setup (Turborepo)

```bash
npx create-turbo@latest my-monorepo

# Structure:
# apps/web/       — Next.js frontend
# apps/api/       — FastAPI or Express backend
# apps/mobile/    — React Native / Expo
# packages/ui/    — Shared UI components
# packages/types/ — Shared TypeScript types
# packages/db/    — Prisma schema + client
```

**turbo.json**:
```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {},
    "test": {
      "dependsOn": ["build"]
    }
  }
}
```

---

## Deployment Platforms

| Platform | Best For | Framework Support |
|---|---|---|
| Vercel | Next.js, SvelteKit, Astro | Excellent |
| Netlify | Any static + serverless | Great |
| Cloudflare Pages | Edge, Hono, Remix | Growing |
| Railway | Any backend container | Great |
| Render | Full-stack apps | Great |
| Fly.io | Docker, global deploy | Good |
| AWS Amplify | Full-stack, AWS ecosystem | Good |
| Supabase | BaaS, Postgres, auth | Great |
| PlanetScale | MySQL serverless | Good (deprecated branches) |
| Neon | Postgres serverless | Excellent |
