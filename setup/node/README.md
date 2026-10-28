# Node.js Setup — nvm, pnpm, Version Management

Complete Node.js environment setup for developers.
Updated: April 2026.

---

## Install Node.js via nvm (Recommended)

nvm lets you install and switch between multiple Node.js versions.

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Reload shell
source ~/.zshrc   # or source ~/.bashrc

# Install versions
nvm install --lts              # Latest LTS (v22.x)
nvm install node               # Latest current release
nvm install 20                 # Specific major version
nvm install 18.20.4            # Specific version

# Switch versions
nvm use --lts
nvm use 20
nvm use node

# Set default
nvm alias default lts/*        # Always use latest LTS
nvm alias default 22           # Or pin to major version

# List versions
nvm ls                         # Installed
nvm ls-remote                  # All available
nvm ls-remote --lts            # LTS releases only

# Use version from .nvmrc
nvm use                        # auto-detects .nvmrc in current dir

# Per-project .nvmrc
echo "22" > .nvmrc
nvm use
```

### Auto-switch Node version with direnv

```bash
# .envrc in project root
use node 22
```

---

## Package Managers

### pnpm (Recommended — fast, disk efficient)

```bash
# Install
npm install -g pnpm

# Enable via corepack (built into Node 16+)
corepack enable pnpm
corepack prepare pnpm@latest --activate

# Commands
pnpm install                   # Install dependencies
pnpm add express               # Add dependency
pnpm add -D typescript         # Add dev dependency
pnpm add -g vercel             # Global install
pnpm remove express            # Remove
pnpm update                    # Update packages
pnpm audit                     # Security audit
pnpm why lodash                # Why is lodash installed?

pnpm run dev                   # Run script
pnpm exec tsc                  # Run local bin
pnpm dlx create-next-app       # Run without install (like npx)

# Workspaces (monorepo)
pnpm -r run build              # Run build in all workspaces
pnpm --filter @myapp/web build # Run in specific workspace
```

### npm

```bash
npm install                    # Install from package.json
npm install express            # Add to dependencies
npm install -D typescript      # Add to devDependencies
npm install -g pnpm            # Global install
npm uninstall express          # Remove
npm update                     # Update packages
npm audit                      # Security check
npm audit fix                  # Auto-fix vulnerabilities
npm run <script>               # Run a script
npm list --depth=0             # Top-level installed packages
npm outdated                   # Check for updates
npm pack                       # Create tarball
npm publish                    # Publish to registry
```

### yarn (v4 berry)

```bash
corepack enable yarn
yarn install
yarn add express
yarn add -D typescript
yarn run dev
yarn dlx create-next-app
```

### Comparison

| Feature | npm | pnpm | yarn |
|---|---|---|---|
| Speed | Baseline | Fastest | Fast |
| Disk usage | High | Lowest | Medium |
| Workspaces | ✅ | ✅ (best) | ✅ |
| Plug'n'Play | ❌ | ❌ | ✅ |
| Recommendation | Fallback | **Use this** | Alternative |

---

## Global Packages

```bash
# TypeScript
npm install -g typescript ts-node tsx

# AI / Dev tools
npm install -g @anthropic-ai/claude-code
npm install -g vercel

# Linting & formatting
npm install -g eslint prettier

# Testing
npm install -g vitest jest

# Build tools
npm install -g turbo nx

# API
npm install -g httpie          # Better HTTP client

# Debugging
npm install -g clinic          # Node.js performance profiling

# Generators
npm install -g create-next-app create-vite degit
```

---

## TypeScript Setup

```bash
npm install -D typescript @types/node
npx tsc --init
```

**`tsconfig.json`** (modern Node.js):

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**`tsconfig.json`** (Next.js):

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

---

## `package.json` Scripts Reference

```json
{
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "eslint . --ext .ts,.tsx --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "type-check": "tsc --noEmit",
    "test": "vitest",
    "test:ci": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "clean": "rm -rf .next dist node_modules/.cache",
    "prepare": "husky"
  }
}
```

---

## Linting & Formatting

### ESLint v9 (flat config)

```bash
npm install -D eslint @eslint/js typescript-eslint
```

**`eslint.config.mjs`**:

```javascript
import eslint from '@eslint/js'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  }
)
```

### Prettier

```bash
npm install -D prettier
```

**`.prettierrc`**:

```json
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100,
  "bracketSpacing": true,
  "arrowParens": "always"
}
```

### Husky + lint-staged (pre-commit hooks)

```bash
npm install -D husky lint-staged
npx husky init
```

**`package.json`**:

```json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{js,json,md,css}": "prettier --write"
  }
}
```

**`.husky/pre-commit`**:

```bash
#!/bin/sh
npx lint-staged
```

---

## Node.js Version per Project

### `.nvmrc` file

```bash
# In project root
echo "22" > .nvmrc

# Switch automatically
nvm use       # reads .nvmrc

# Auto-switch on cd (add to ~/.zshrc)
autoload -U add-zsh-hook
load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
    if [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc
```

### `.node-version` file (Volta / fnm)

```bash
echo "22.11.0" > .node-version
```

### fnm (Fast Node Manager — alternative to nvm)

```bash
brew install fnm

# Add to ~/.zshrc
eval "$(fnm env --use-on-cd)"

fnm install --lts
fnm install 22
fnm use 22
fnm default 22
```

---

## Debugging Node.js

```bash
# Built-in debugger
node --inspect server.js             # Open Chrome DevTools at chrome://inspect
node --inspect-brk server.js        # Break on first line

# Clinic.js profiling
npm install -g clinic
clinic doctor -- node server.js
clinic flame -- node server.js       # Flamegraph
clinic bubbleprof -- node server.js  # Async analysis

# Memory leak detection
node --expose-gc --inspect server.js
```

---

## Useful Node.js CLI Tools

```bash
# Project scaffolding
npx create-next-app@latest
npx create-vite@latest
npx create-turbo@latest

# Static analysis
npx knip                   # Find unused code and dependencies
npx depcheck               # Check unused dependencies
npx bundlephobia           # Check bundle size of packages

# Security
npx npm-check-updates -u   # Update all package versions
npx audit-ci               # CI-friendly npm audit

# Documentation
npx typedoc --out docs src  # Generate TypeScript docs

# Release management
npx release-it              # Automated releases
npx changesets              # Changelog management (monorepos)
```
