# CSS & UI Frameworks — Setup & Reference

Updated: April 2026

---

## Tailwind CSS 4 — Recommended

**Best for**: Utility-first CSS, rapid development, consistent design.

```bash
npm install tailwindcss @tailwindcss/vite

# For Next.js
npm install tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

**Tailwind CSS v4 changes** (CSS-first config):
```css
/* app/globals.css — no more tailwind.config.js needed */
@import "tailwindcss";

@theme {
  --color-brand: oklch(60% 0.2 250);
  --font-display: "Inter", sans-serif;
  --radius-lg: 0.75rem;
}
```

**Usage**:
```tsx
<div className="flex min-h-screen items-center justify-center bg-gray-50 dark:bg-gray-900">
  <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-xl dark:bg-gray-800">
    <h1 className="mb-6 text-3xl font-bold text-gray-900 dark:text-white">
      Hello World
    </h1>
    <button className="w-full rounded-lg bg-blue-600 px-4 py-3 font-semibold text-white
                       hover:bg-blue-700 active:scale-95 transition-all duration-150">
      Click me
    </button>
  </div>
</div>
```

**Tailwind plugins**:
```bash
npm install @tailwindcss/forms @tailwindcss/typography @tailwindcss/aspect-ratio
```

---

## shadcn/ui — Most Popular React UI

**Best for**: Copy-paste components built on Radix UI + Tailwind. You own the code.

```bash
# Initialize in Next.js project
npx shadcn@latest init

# Add components
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add dialog
npx shadcn@latest add form
npx shadcn@latest add input
npx shadcn@latest add table
npx shadcn@latest add toast
npx shadcn@latest add dropdown-menu
npx shadcn@latest add sheet
npx shadcn@latest add select
```

**components.json**:
```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "app/globals.css",
    "baseColor": "slate",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils"
  }
}
```

**Usage**:
```tsx
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

export function LoginForm() {
  return (
    <Card className="w-[380px]">
      <CardHeader>
        <CardTitle>Login</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input id="email" type="email" placeholder="m@example.com" />
        </div>
        <Button className="w-full">Sign In</Button>
      </CardContent>
    </Card>
  )
}
```

---

## Radix UI (Headless Primitives)

**Best for**: Fully accessible, unstyled components — bring your own styles.

```bash
npm install @radix-ui/react-dialog @radix-ui/react-dropdown-menu
npm install @radix-ui/react-select @radix-ui/react-switch
```

```tsx
import * as Dialog from '@radix-ui/react-dialog'

function ConfirmDialog() {
  return (
    <Dialog.Root>
      <Dialog.Trigger asChild>
        <button>Open Dialog</button>
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-black/50" />
        <Dialog.Content className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2
                                    w-[450px] rounded-xl bg-white p-6 shadow-2xl">
          <Dialog.Title>Confirm Action</Dialog.Title>
          <Dialog.Description>Are you sure?</Dialog.Description>
          <div className="mt-4 flex gap-3 justify-end">
            <Dialog.Close asChild>
              <button>Cancel</button>
            </Dialog.Close>
            <button>Confirm</button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
```

---

## Framer Motion

**Best for**: Production-ready animations in React.

```bash
npm install framer-motion
```

```tsx
import { motion, AnimatePresence } from 'framer-motion'

// Basic animation
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  exit={{ opacity: 0, y: -20 }}
  transition={{ duration: 0.3, ease: 'easeOut' }}
>
  Content
</motion.div>

// Gesture animations
<motion.button
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
  className="..."
>
  Button
</motion.button>

// List animations
<AnimatePresence>
  {items.map(item => (
    <motion.li
      key={item.id}
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: 20 }}
    >
      {item.name}
    </motion.li>
  ))}
</AnimatePresence>
```

---

## DaisyUI

**Best for**: Tailwind component library with semantic class names.

```bash
npm install daisyui
```

```js
// tailwind.config.js
plugins: [require("daisyui")],
daisyui: {
  themes: ["light", "dark", "cupcake", "cyberpunk"]
}
```

```html
<button class="btn btn-primary">Button</button>
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Content</p>
  </div>
</div>
<label class="input input-bordered flex items-center gap-2">
  <input type="text" class="grow" placeholder="Search" />
</label>
```

---

## Mantine

**Best for**: Full-featured React UI with 100+ components, hooks library.

```bash
npm install @mantine/core @mantine/hooks @mantine/form @mantine/dates
npm install @mantine/notifications @mantine/modals
```

```tsx
import { MantineProvider, Button, TextInput, Select, Group } from '@mantine/core'
import { useForm } from '@mantine/form'

function App() {
  return (
    <MantineProvider>
      <MyForm />
    </MantineProvider>
  )
}

function MyForm() {
  const form = useForm({
    initialValues: { email: '', role: '' },
    validate: {
      email: (value) => (/^\S+@\S+$/.test(value) ? null : 'Invalid email'),
    },
  })

  return (
    <form onSubmit={form.onSubmit((values) => console.log(values))}>
      <TextInput label="Email" {...form.getInputProps('email')} />
      <Select label="Role" data={['Admin', 'User']} {...form.getInputProps('role')} />
      <Group justify="flex-end" mt="md">
        <Button type="submit">Submit</Button>
      </Group>
    </form>
  )
}
```

---

## Chakra UI v3

**Best for**: Accessible React components with sensible defaults.

```bash
npm install @chakra-ui/react @emotion/react @emotion/styled framer-motion
```

---

## Ant Design 5

**Best for**: Enterprise React apps, complete component library, data tables.

```bash
npm install antd @ant-design/icons
```

---

## Material UI (MUI) v6

**Best for**: Google Material Design in React.

```bash
npm install @mui/material @emotion/react @emotion/styled @mui/icons-material
```

---

## CSS Architecture

### CSS Modules (built into Next.js/Vite)
```css
/* Button.module.css */
.button {
  padding: 0.5rem 1rem;
  background: var(--color-primary);
  border-radius: 0.5rem;
}

.button:hover {
  opacity: 0.9;
}
```

```tsx
import styles from './Button.module.css'
<button className={styles.button}>Click</button>
```

### CSS Variables for theming
```css
:root {
  --color-primary: #3b82f6;
  --color-background: #ffffff;
  --color-text: #1f2937;
  --radius: 0.5rem;
  --shadow: 0 1px 3px rgba(0,0,0,0.1);
}

[data-theme="dark"] {
  --color-background: #0f172a;
  --color-text: #f8fafc;
}
```

---

## Design Systems Comparison

| Library | Size | Customizable | Accessible | Best For |
|---|---|---|---|---|
| Tailwind CSS | Tiny | Full | Manual | Any project |
| shadcn/ui | 0 (copy) | Full | Yes | React, own code |
| DaisyUI | Small | Themes | Yes | Rapid prototyping |
| Mantine | Medium | High | Yes | React apps |
| Chakra UI | Medium | High | Excellent | Accessible apps |
| Ant Design | Large | Medium | Yes | Enterprise apps |
| MUI | Large | Medium | Yes | Material Design |
