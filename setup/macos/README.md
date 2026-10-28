# macOS Developer Setup — Complete Guide

Full setup for a macOS developer workstation from scratch.
Updated: April 2026 (macOS Sequoia 15+).

---

## Table of Contents

1. [System Preferences](#1-system-preferences)
2. [Homebrew](#2-homebrew)
3. [Terminal & Shell](#3-terminal--shell)
4. [Core Dev Tools](#4-core-dev-tools)
5. [Languages & Runtimes](#5-languages--runtimes)
6. [Databases](#6-databases)
7. [Containers & Orchestration](#7-containers--orchestration)
8. [Cloud CLI Tools](#8-cloud-cli-tools)
9. [AI & LLM Tools](#9-ai--llm-tools)
10. [IDEs & Editors](#10-ides--editors)
11. [Productivity Apps](#11-productivity-apps)
12. [macOS Defaults Script](#12-macos-defaults-script)
13. [Full Install Script](#13-full-install-script)

---

## 1. System Preferences

```bash
# Show all filename extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar and status bar in Finder
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Disable .DS_Store on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct, auto-capitalize, and smart quotes
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Show full URL in Safari address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Dock — auto-hide, no recent apps
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 48

# Screenshot — save to Desktop
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# Apply all changes
killall Finder Dock
```

---

## 2. Homebrew

The package manager for macOS.

```bash
# Install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Add to PATH (Intel)
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile

# Verify
brew --version
brew doctor

# Essential commands
brew install <package>           # Install CLI tool
brew install --cask <app>        # Install GUI app
brew upgrade                     # Upgrade everything
brew cleanup                     # Remove old versions
brew list                        # List installed packages
brew search <keyword>            # Search packages
brew info <package>              # Package details
brew services start <service>    # Start a background service
brew services list               # List services
```

---

## 3. Terminal & Shell

### iTerm2

```bash
brew install --cask iterm2
```

**Recommended iTerm2 settings:**
- Preferences → Profiles → Text → Font: **JetBrains Mono Nerd Font** 14pt
- Preferences → General → Closing: Confirm "Quit iTerm2"
- Preferences → Keys → Hotkey: Enable system-wide hotkey (e.g. `⌥Space`)

### Zsh & Oh My Zsh

```bash
# Zsh is default on macOS — confirm
zsh --version

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z

# Enable in ~/.zshrc
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-z docker kubectl)
```

### Starship Prompt (Alternative to Powerlevel10k)

```bash
brew install starship

# Add to ~/.zshrc
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# Config: ~/.config/starship.toml
```

### Nerd Fonts

```bash
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-fira-code-nerd-font
brew install --cask font-hack-nerd-font
```

### Terminal Multiplexer — tmux

```bash
brew install tmux

# Config ~/.tmux.conf
cat >> ~/.tmux.conf << 'EOF'
set -g prefix C-a
unbind C-b
bind C-a send-prefix
set -g mouse on
set -g base-index 1
set -g history-limit 50000
set -g default-terminal "screen-256color"
EOF

# Key commands
# C-a c        new window
# C-a ,        rename window
# C-a "        split horizontally
# C-a %        split vertically
# C-a z        zoom pane
# C-a d        detach session
tmux new -s dev       # new session
tmux attach -t dev    # reattach
```

---

## 4. Core Dev Tools

```bash
# Version control
brew install git gh git-lfs git-delta

# CLI utilities (must-haves)
brew install curl wget jq yq httpie
brew install fzf fd ripgrep bat eza tree
brew install tldr direnv watchman
brew install htop btop ncdu

# Build tools
brew install make cmake pkg-config

# Network tools
brew install nmap netcat mtr

# Install fzf key bindings
$(brew --prefix)/opt/fzf/install

# Configure git delta (beautiful diffs)
git config --global core.pager delta
git config --global delta.navigate true
git config --global delta.side-by-side true
```

**Tool reference:**

| Tool | Purpose | Replaces |
|---|---|---|
| `eza` | Modern file listing | `ls` |
| `bat` | Syntax-highlighted file view | `cat` |
| `fd` | Fast file finder | `find` |
| `ripgrep` (`rg`) | Fast content search | `grep` |
| `fzf` | Fuzzy finder for shell | — |
| `htop` / `btop` | Interactive process viewer | `top` |
| `ncdu` | Interactive disk usage | `du` |
| `tldr` | Simplified man pages | `man` |
| `jq` | JSON processor | — |
| `yq` | YAML/JSON processor | — |
| `httpie` (`http`) | Human-friendly HTTP client | `curl` |
| `git-delta` | Beautiful git diffs | — |
| `direnv` | Auto-load .env per directory | — |
| `watchman` | File watcher (used by React Native) | — |

---

## 5. Languages & Runtimes

### Node.js (via nvm)

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Reload shell
source ~/.zshrc

# Install Node versions
nvm install --lts            # Latest LTS (v22.x)
nvm install node             # Latest current
nvm use --lts
nvm alias default lts/*      # Set default

# Install pnpm (faster npm)
npm install -g pnpm
corepack enable pnpm

# Global packages
npm install -g typescript ts-node tsx
npm install -g @anthropic-ai/claude-code
npm install -g vercel
npm install -g eslint prettier

# Check
node --version && npm --version && pnpm --version
```

### Python (via pyenv + uv)

```bash
# Install pyenv
brew install pyenv

# Add to ~/.zshrc
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
source ~/.zshrc

# Install Python versions
pyenv install 3.13.0
pyenv install 3.12.8
pyenv global 3.13.0

# uv — ultra-fast Python package manager (replaces pip, venv)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Use uv
uv venv                      # create .venv
uv pip install fastapi       # install package
uv run python script.py      # run with venv

# pipx — install CLI tools in isolated envs
brew install pipx
pipx ensurepath
pipx install black ruff mypy httpie
```

### Go

```bash
brew install go

# Add to ~/.zshrc
echo 'export GOPATH=$HOME/go' >> ~/.zshrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc

go version                   # verify
go install golang.org/x/tools/gopls@latest   # LSP
```

### Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Reload shell
source ~/.cargo/env

rustc --version
cargo --version

# Useful Rust CLI tools (compiled from source)
cargo install eza bat ripgrep fd-find
```

### Java (via SDKMAN)

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

sdk install java 21.0.5-tem    # Temurin JDK 21 (LTS)
sdk install java 17.0.13-tem   # JDK 17
sdk install gradle
sdk install maven

java --version
```

### Ruby (via rbenv)

```bash
brew install rbenv ruby-build

echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc

rbenv install 3.3.6
rbenv global 3.3.6

gem install bundler rails
```

---

## 6. Databases

### PostgreSQL

```bash
brew install postgresql@16
brew services start postgresql@16

echo 'export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"' >> ~/.zshrc

# Create a database
createdb mydb
psql mydb

# GUI — TablePlus (recommended)
brew install --cask tableplus
```

### MySQL

```bash
brew install mysql@8.4
brew services start mysql@8.4

mysql_secure_installation
mysql -u root -p
```

### Redis

```bash
brew install redis
brew services start redis

redis-cli ping    # → PONG
```

### MongoDB

```bash
brew tap mongodb/brew
brew install mongodb-community@7.0
brew services start mongodb-community@7.0

mongosh
```

### SQLite

```bash
brew install sqlite
sqlite3 --version

# GUI
brew install --cask db-browser-for-sqlite
```

### Database GUI Tools

```bash
brew install --cask tableplus          # Recommended (all DBs)
brew install --cask dbeaver-community  # Free, all DBs
brew install --cask pgadmin4           # PostgreSQL only
brew install --cask mongodb-compass    # MongoDB
```

---

## 7. Containers & Orchestration

### Docker Desktop

```bash
brew install --cask docker

# Verify after launch
docker --version
docker compose version
docker run hello-world
```

### Kubernetes tools

```bash
brew install kubectl helm k9s kubectx kubens kustomize
brew install kind                  # Kubernetes in Docker (local cluster)
brew install minikube              # Local Kubernetes cluster

# Create local cluster with kind
kind create cluster --name local

# Switch contexts
kubectx                            # list contexts
kubectx local                     # switch to local
kubens default                    # switch namespace

# k9s — terminal UI for Kubernetes
k9s
```

### Container utilities

```bash
brew install crane                 # OCI image tool
brew install skopeo                # Container image inspection
brew install trivy                 # Container vulnerability scanner

# Scan an image
trivy image python:3.13-slim
```

---

## 8. Cloud CLI Tools

### AWS CLI

```bash
brew install awscli

aws --version
aws configure                      # Set key, secret, region, output format

# Named profiles
aws configure --profile prod
export AWS_PROFILE=prod

# Useful commands
aws s3 ls
aws ec2 describe-instances
aws sts get-caller-identity        # Who am I?
```

### Google Cloud SDK

```bash
brew install --cask google-cloud-sdk

gcloud init
gcloud auth login
gcloud config set project my-project

gcloud components install kubectl
gcloud components update
```

### Azure CLI

```bash
brew install azure-cli

az login
az account list --output table
az group list
```

### Terraform

```bash
brew install terraform
brew install terragrunt            # DRY Terraform wrapper
brew install tfsec                 # Terraform security scanner
brew install infracost             # Cost estimation

terraform --version
terraform init
terraform plan
terraform apply
```

### Pulumi (IaC alternative)

```bash
brew install pulumi/tap/pulumi
pulumi login
pulumi new typescript
```

---

## 9. AI & LLM Tools

### Claude Code

```bash
npm install -g @anthropic-ai/claude-code

# Set API key
export ANTHROPIC_API_KEY=sk-ant-...

# Run
claude
claude "explain this codebase"
claude --model claude-opus-4-6
```

### Ollama (local LLMs)

```bash
brew install ollama

# Ollama starts automatically on macOS
ollama serve                        # start manually if needed

# Pull and run models
ollama pull llama3.3:70b
ollama pull qwen2.5-coder:7b
ollama pull phi4:14b
ollama pull nomic-embed-text        # embeddings

ollama run llama3.3:70b
ollama list
ollama ps                           # running models
```

### Aider (terminal AI pair programmer)

```bash
pip install aider-install && aider-install
# OR
uv tool install aider-chat

aider --model claude-sonnet-4-6
aider --model ollama/qwen2.5-coder:7b   # local model
```

### Open WebUI (Ollama web interface)

```bash
docker run -d \
  -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

# Access at http://localhost:3000
```

---

## 10. IDEs & Editors

```bash
# VS Code (recommended)
brew install --cask visual-studio-code

# Cursor (AI-first IDE)
brew install --cask cursor

# Windsurf (Codeium AI IDE)
brew install --cask windsurf

# JetBrains (via Toolbox)
brew install --cask jetbrains-toolbox

# Zed (fast Rust-based editor)
brew install --cask zed

# Neovim
brew install neovim
```

### VS Code extensions (install via CLI)

```bash
# AI
code --install-extension GitHub.copilot
code --install-extension GitHub.copilot-chat
code --install-extension Continue.continue

# Languages
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension golang.go
code --install-extension rust-lang.rust-analyzer

# DevOps
code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension hashicorp.terraform
code --install-extension redhat.ansible

# Utilities
code --install-extension eamodio.gitlens
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension usernamehw.errorlens
code --install-extension mechatroner.rainbow-csv
code --install-extension mikestead.dotenv
code --install-extension PKief.material-icon-theme
```

---

## 11. Productivity Apps

```bash
# Window management
brew install --cask rectangle           # Free window snapping
brew install --cask raycast             # Spotlight replacement + AI

# Menu bar utilities
brew install --cask bartender           # Menu bar organizer (paid)
brew install --cask hidden-bar          # Free menu bar manager

# Clipboard manager
brew install --cask maccy               # Free clipboard history

# Communication
brew install --cask slack
brew install --cask discord
brew install --cask zoom

# Notes & docs
brew install --cask notion
brew install --cask obsidian            # Local markdown notes

# Password manager
brew install --cask 1password
brew install --cask bitwarden           # Free alternative

# Screenshots & screen recording
brew install --cask shottr              # Better screenshots
brew install --cask obs

# API testing
brew install --cask postman
brew install --cask insomnia

# Database GUI
brew install --cask tableplus

# Design
brew install --cask figma

# VPN
brew install --cask tailscale           # Mesh VPN (free tier)
```

---

## 12. macOS Defaults Script

Save as `~/scripts/macos-defaults.sh` and run once after fresh install.

```bash
#!/bin/bash
set -e
echo "Applying macOS defaults..."

# Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Prevent .DS_Store on network/USB
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock minimize-to-application -bool true

# Screenshots
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# Trackpad
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Safari
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

# TextEdit — plain text by default
defaults write com.apple.TextEdit RichText -int 0
defaults write com.apple.TextEdit PlainTextEncoding -int 4

# Activity Monitor — show all processes
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Disable Gatekeeper (optional — allows unsigned apps)
# sudo spctl --master-disable

# Apply
killall Finder Dock SystemUIServer 2>/dev/null || true
echo "Done. Some changes require a logout to take full effect."
```

---

## 13. Full Install Script

Run after a fresh macOS install. Installs everything above in one shot.

```bash
#!/bin/bash
set -euo pipefail
echo "=== macOS Dev Setup ==="

# 1. Homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 2. CLI tools
brew install git gh git-lfs git-delta \
  curl wget jq yq httpie \
  fzf fd ripgrep bat eza tree htop btop ncdu \
  tldr direnv watchman \
  make cmake pkg-config \
  tmux starship \
  nmap netcat mtr

# 3. Languages
brew install pyenv go

# Node via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh"
nvm install --lts && nvm alias default lts/*
npm install -g pnpm typescript ts-node @anthropic-ai/claude-code

# Python via uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 4. Casks — apps
brew install --cask \
  iterm2 visual-studio-code cursor \
  docker tableplus \
  rectangle raycast maccy \
  slack discord zoom \
  notion obsidian \
  1password \
  postman figma \
  tailscale

# 5. Fonts
brew install --cask \
  font-jetbrains-mono-nerd-font \
  font-fira-code-nerd-font

# 6. DevOps
brew install kubectl helm k9s kubectx kind \
  terraform awscli

# 7. AI tools
brew install ollama
ollama pull llama3.3:70b &     # pull in background

# 8. Zsh setup
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

echo "=== Setup complete! Restart your terminal. ==="
```
