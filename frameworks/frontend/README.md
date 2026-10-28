# Frontend Frameworks — Setup & Reference

Updated: April 2026

---

## Next.js 15

**Best for**: Full-stack React apps, SSR, ISR, API routes, App Router.

```bash
# Create new project
npx create-next-app@latest my-app --typescript --tailwind --app --eslint

cd my-app
npm run dev    # http://localhost:3000
```

**Project structure (App Router)**:
```
app/
├── layout.tsx          # Root layout
├── page.tsx            # Home route
├── (auth)/             # Route group
│   ├── login/page.tsx
│   └── signup/page.tsx
├── dashboard/
│   ├── layout.tsx
│   └── page.tsx
├── api/
│   └── route.ts        # API route
components/
lib/
public/
next.config.ts
```

**Key features in Next.js 15**:
- React 19 support
- Turbopack stable (10x faster builds)
- Partial Prerendering (PPR)
- Server Components by default
- Server Actions
- `use cache` directive

**next.config.ts**:
```typescript
import type { NextConfig } from 'next'

const config: NextConfig = {
  experimental: {
    ppr: true,          // Partial Prerendering
    reactCompiler: true
  },
  images: {
    remotePatterns: [{ hostname: 'example.com' }]
  }
}

export default config
```

**Common patterns**:
```typescript
// Server Component (default)
export default async function Page() {
  const data = await fetch('https://api.example.com/data', {
    next: { revalidate: 3600 }  // ISR: revalidate every hour
  })
  const json = await data.json()
  return <div>{json.title}</div>
}

// Server Action
async function createUser(formData: FormData) {
  'use server'
  const name = formData.get('name')
  await db.user.create({ data: { name } })
}

// Dynamic route
// app/blog/[slug]/page.tsx
export default function BlogPost({ params }: { params: { slug: string } }) {
  return <h1>{params.slug}</h1>
}
```

---

## React 19

**Best for**: Component-based UIs, SPAs, library of choice for Next.js/Remix.

```bash
npm create vite@latest my-app -- --template react-ts
cd my-app && npm install && npm run dev
```

**React 19 new features**:
```typescript
// use() hook — read promises and context
import { use, Suspense } from 'react'

function UserName({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise)   // unwraps promise in render
  return <span>{user.name}</span>
}

// useActionState — form actions
import { useActionState } from 'react'

function Form() {
  const [state, formAction, isPending] = useActionState(
    async (prevState, formData) => {
      const result = await submitForm(formData)
      return result
    },
    null
  )
  return (
    <form action={formAction}>
      <input name="email" />
      <button disabled={isPending}>Submit</button>
    </form>
  )
}

// useOptimistic — optimistic UI updates
import { useOptimistic } from 'react'

function TodoList({ todos, addTodo }) {
  const [optimisticTodos, addOptimistic] = useOptimistic(
    todos,
    (state, newTodo) => [...state, newTodo]
  )
}
```

---

## Vue 3.5

**Best for**: Progressive enhancement, gradual adoption, Composition API.

```bash
npm create vue@latest my-app
cd my-app && npm install && npm run dev
```

**Composition API**:
```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'

const count = ref(0)
const doubled = computed(() => count.value * 2)

function increment() {
  count.value++
}

onMounted(() => {
  console.log('mounted')
})
</script>

<template>
  <button @click="increment">{{ count }} ({{ doubled }})</button>
</template>
```

**Vue 3.5 features**:
- `useTemplateRef()` — reactive template refs
- `useId()` — unique IDs for SSR
- Deferred Teleport
- `onWatcherCleanup()`

---

## Svelte 5 + SvelteKit

**Best for**: Compiled, minimal JS output, excellent performance.

```bash
# SvelteKit
npx sv create my-app
cd my-app && npm install && npm run dev
```

**Svelte 5 Runes** (new reactivity system):
```svelte
<script>
  // $state — reactive variable
  let count = $state(0)

  // $derived — computed value
  let doubled = $derived(count * 2)

  // $effect — side effects
  $effect(() => {
    console.log('count changed:', count)
  })

  // $props — component props
  let { name, age = 25 } = $props()
</script>

<button onclick={() => count++}>
  {count} (doubled: {doubled})
</button>
```

---

## Astro 5

**Best for**: Content-heavy sites, blogs, marketing, islands architecture.

```bash
npm create astro@latest my-site
cd my-site && npm run dev
```

**Islands architecture**:
```astro
---
// .astro file — server by default, zero JS shipped
import ReactCounter from '../components/Counter.tsx'
import VueWidget from '../components/Widget.vue'
---

<html>
  <body>
    <h1>Static Content</h1>
    <!-- Only this component ships JS -->
    <ReactCounter client:load />
    <!-- Loads JS when visible in viewport -->
    <VueWidget client:visible />
  </body>
</html>
```

**Content Collections** (type-safe):
```typescript
// src/content/config.ts
import { defineCollection, z } from 'astro:content'

const blog = defineCollection({
  schema: z.object({
    title: z.string(),
    date: z.date(),
    tags: z.array(z.string())
  })
})

export const collections = { blog }
```

---

## Angular 19

**Best for**: Enterprise SPAs, large teams, strict TypeScript.

```bash
npm install -g @angular/cli
ng new my-app --routing --style scss
cd my-app && ng serve
```

**Angular 19 features**:
- Standalone components (no NgModule)
- Signal-based reactivity
- Zoneless change detection

```typescript
import { Component, signal, computed } from '@angular/core'

@Component({
  selector: 'app-root',
  standalone: true,
  template: `
    <button (click)="increment()">{{ count() }}</button>
    <p>Doubled: {{ doubled() }}</p>
  `
})
export class AppComponent {
  count = signal(0)
  doubled = computed(() => this.count() * 2)

  increment() {
    this.count.update(n => n + 1)
  }
}
```

---

## Solid.js

**Best for**: Fine-grained reactivity, no virtual DOM, fastest renders.

```bash
npx degit solidjs/templates/ts my-app
cd my-app && npm install && npm run dev
```

```typescript
import { createSignal, createEffect, createMemo } from 'solid-js'

function Counter() {
  const [count, setCount] = createSignal(0)
  const doubled = createMemo(() => count() * 2)

  createEffect(() => console.log(count()))

  return <button onClick={() => setCount(c => c + 1)}>{count()} / {doubled()}</button>
}
```

---

## Vite (Build Tool)

Used by: React, Vue, Svelte, Solid, Astro

```bash
npm create vite@latest my-app -- --template react-ts

# Templates: vanilla, vanilla-ts, vue, vue-ts, react, react-ts,
#             react-swc-ts, svelte, svelte-ts, solid-ts, qwik-ts
```

**vite.config.ts**:
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') }
  },
  server: {
    port: 3000,
    proxy: {
      '/api': 'http://localhost:8000'
    }
  }
})
```

---

## State Management

| Library | Framework | Pattern |
|---|---|---|
| Zustand | React | Minimal, hooks-based |
| Jotai | React | Atomic state |
| TanStack Query | React/Vue | Server state, caching |
| Pinia | Vue | Official Vue store |
| Redux Toolkit | React | Predictable, large apps |
| XState | Any | State machines |
| Nanostores | Any | Framework-agnostic |

**Zustand** (recommended for React):
```typescript
import { create } from 'zustand'

interface Store {
  count: number
  increment: () => void
}

const useStore = create<Store>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 }))
}))

function Counter() {
  const { count, increment } = useStore()
  return <button onClick={increment}>{count}</button>
}
```

**TanStack Query** (server state):
```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

function Users() {
  const { data, isLoading } = useQuery({
    queryKey: ['users'],
    queryFn: () => fetch('/api/users').then(r => r.json()),
    staleTime: 5 * 60 * 1000   // 5 minutes
  })

  if (isLoading) return <div>Loading...</div>
  return <ul>{data?.map(u => <li key={u.id}>{u.name}</li>)}</ul>
}
```
