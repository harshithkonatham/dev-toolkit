# Setup Guides — Index

Environment setup for all platforms and toolchains.
Updated: April 2026.

---

## Sections

| Guide | Description |
|---|---|
| [macOS](macos/README.md) | Full macOS developer workstation setup |
| [Linux](linux/README.md) | Linux commands, services, networking, scripting |
| [Windows / WSL2](windows/README.md) | Windows Subsystem for Linux dev environment |
| [Shell](shell/README.md) | Zsh, aliases, Starship prompt, dotfiles |
| [Node.js](node/README.md) | nvm, pnpm, global packages, version management |
| [Python](python/README.md) | pyenv, uv, virtualenv, pip toolchain |
| [Docker](docker/README.md) | Docker Desktop, Compose, common images |
| [Cloud CLI](cloud/README.md) | AWS CLI, GCP CLI, Azure CLI, Terraform |

---

## Quick One-Line Installs

```bash
# macOS — Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Node (nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Python (uv — fast Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Go
brew install go        # macOS
sudo apt install golang-go   # Ubuntu

# Claude Code (AI coding agent)
npm install -g @anthropic-ai/claude-code

# Ollama (local LLMs)
brew install ollama    # macOS
curl -fsSL https://ollama.com/install.sh | sh   # Linux
```
