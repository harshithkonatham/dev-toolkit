# ak-dev-toolkit

A consolidated repository containing development tools, setup guides, frameworks, Dockerfiles, and learning resources.
Updated: April 2026.

[![Toolkit CI](https://github.com/harshithkonatham/dev-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/harshithkonatham/dev-toolkit/actions/workflows/ci.yml)
[![payments-api](https://github.com/harshithkonatham/dev-toolkit/actions/workflows/payments-api.yml/badge.svg)](https://github.com/harshithkonatham/dev-toolkit/actions/workflows/payments-api.yml)

## Featured: Payments API (DevSecOps reference project)

[`projects/payments-api`](projects/payments-api) is a small card-transactions
service that puts the practices in [`tools/devsecops`](tools/devsecops) into
working code:

- **Secure by design:** card numbers never stored or logged, pinned-algorithm
  JWT auth, per-user authorization, idempotent payments, transactional outbox
- **Tested at three levels:** unit, integration and end-to-end, with a 90%
  coverage gate
- **Security gates in CI:** Bandit, Semgrep, CodeQL, Gitleaks, pip-audit,
  Hadolint, Checkov and Grype, plus an SBOM for every build
- **Shipped like production:** hardened non-root container, deployed to a
  Kubernetes (kind) cluster in CI and smoke-tested there

## Repository Taxonomy

| Directory | Description |
|---|---|
| **`setup/`** | OS-level configuration (macOS, Linux essentials) |
| **`tools/developer/`** | IDE (VS Code), Version Control (Git), and Terminal utilities |
| **`tools/devops/`** | Infrastructure as Code, CI/CD (ArgoCD, Ansible), and Observability |
| **`tools/ai/`** | AI coding assistants, local LLMs, agent frameworks, MCP servers |
| **`frameworks/`** | Frontend, backend, mobile, AI/ML, CSS/UI, full-stack, testing, databases |
| **`containers/`** | Dockerfiles, Compose files, and Registry configurations |
| **`networking/`** | Networking tools, tunneling, proxies, and cybersecurity |
| **`security/`** | Security, Compliance, and Secret Management standards |
| **`projects/`** | Demo projects, including the [Payments API](projects/payments-api) DevSecOps reference |

## Frameworks Quick Reference

| Category | Top Tools |
|---|---|
| **Frontend** | Next.js 15, React 19, Vue 3.5, Svelte 5, Astro 5 |
| **Backend** | FastAPI, NestJS, Hono, Express, Go Fiber |
| **Mobile** | React Native 0.77, Expo SDK 52, Flutter 3.29 |
| **AI/ML** | LangChain, LlamaIndex, Hugging Face, PyTorch 2.6 |
| **CSS/UI** | Tailwind CSS 4, shadcn/ui, Radix UI, Mantine |
| **Full-Stack** | T3 Stack, Remix, SvelteKit, Nuxt 3 |
| **Testing** | Vitest, Playwright, Cypress, pytest |
| **Databases** | Prisma, Drizzle ORM, SQLAlchemy, Neon, Supabase |

## AI Tools Quick Reference

| Tool | Purpose |
|---|---|
| **Claude Code** | Autonomous coding agent, MCP server integration |
| **Cursor / Windsurf** | AI-first IDEs |
| **GitHub Copilot** | IDE inline suggestions |
| **Aider** | Git-aware terminal AI pair programmer |
| **Ollama** | Local LLM runner (llama3.3, qwen2.5-coder, phi4) |
| **Open WebUI** | Web UI for local models |
| **LangChain/LangGraph** | LLM chains and agent graphs |
| **CrewAI** | Multi-agent teams |
| **Pydantic AI** | Type-safe Python agents |
