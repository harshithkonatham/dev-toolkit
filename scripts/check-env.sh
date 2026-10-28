#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ak-dev-toolkit — Environment Validator
# Checks all major developer tools for installation.
# Usage: bash scripts/check-env.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

section() { echo -e "\n${BLUE}${BOLD}── $1 ──${NC}"; }

ok()   { echo -e "  ${GREEN}✔${NC}  $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✘${NC}  $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; ((WARN++)); }

check() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" &>/dev/null; then
    local version
    version=$("$cmd" --version 2>&1 | head -n1 | sed 's/[^0-9.]//g' | cut -d. -f1-2)
    ok "$name ($version)"
  else
    fail "$name — not found"
  fi
}

check_cmd() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" &>/dev/null; then
    ok "$name"
  else
    fail "$name — not found"
  fi
}

check_env() {
  local name="$1"
  local var="$2"
  if [[ -n "${!var:-}" ]]; then
    local preview="${!var:0:8}..."
    ok "$name ($preview)"
  else
    warn "$name — \$$var not set"
  fi
}

echo ""
echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   ak-dev-toolkit — Environment Check   ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"
echo -e "  Platform: $(uname -s) $(uname -m)"
echo -e "  Date:     $(date '+%Y-%m-%d %H:%M')"

# ── Core ─────────────────────────────────────────────────────────────────────
section "Core CLI Tools"
check "Git" git
check "curl" curl
check "wget" wget
check_cmd "jq" jq
check_cmd "yq" yq
check_cmd "fzf" fzf
check_cmd "ripgrep (rg)" rg
check_cmd "fd" fd
check_cmd "bat" bat
check_cmd "eza" eza
check_cmd "tree" tree
check_cmd "htop" htop
check_cmd "tmux" tmux

# ── Package Managers ─────────────────────────────────────────────────────────
section "Package Managers"
if [[ "$OSTYPE" == "darwin"* ]]; then
  check_cmd "Homebrew" brew
fi
check "npm" npm
check_cmd "pnpm" pnpm
check_cmd "yarn" yarn
check_cmd "uv (Python)" uv
check_cmd "cargo (Rust)" cargo

# ── Languages ────────────────────────────────────────────────────────────────
section "Languages & Runtimes"
check "Node.js" node
check "Python" python3
check "Go" go
check "Rust (rustc)" rustc
check_cmd "Java" java
check_cmd "Ruby" ruby

# ── Node tools ───────────────────────────────────────────────────────────────
section "Node.js Tools"
check_cmd "TypeScript (tsc)" tsc
check_cmd "ts-node" ts-node
check_cmd "tsx" tsx
check_cmd "ESLint" eslint
check_cmd "Prettier" prettier

# ── Python tools ─────────────────────────────────────────────────────────────
section "Python Tools"
check_cmd "pyenv" pyenv
check_cmd "pip" pip3
check_cmd "ruff" ruff
check_cmd "mypy" mypy
check_cmd "black" black
check_cmd "httpie (http)" http

# ── Version Managers ─────────────────────────────────────────────────────────
section "Version Managers"
check_cmd "nvm" nvm || warn "nvm — load with: source ~/.nvm/nvm.sh"
check_cmd "pyenv" pyenv
check_cmd "rbenv" rbenv
check_cmd "tfenv" tfenv

# ── Containers & Orchestration ───────────────────────────────────────────────
section "Containers & Kubernetes"
check "Docker" docker
check "Docker Compose" "docker-compose" || check_cmd "docker compose" docker
check "kubectl" kubectl
check "helm" helm
check_cmd "k9s" k9s
check_cmd "kubectx" kubectx
check_cmd "kubens" kubens
check_cmd "kind" kind
check_cmd "minikube" minikube
check_cmd "skopeo" skopeo
check_cmd "trivy" trivy

# ── Cloud CLIs ───────────────────────────────────────────────────────────────
section "Cloud CLIs"
check "AWS CLI" aws
check_cmd "Google Cloud (gcloud)" gcloud
check_cmd "Azure CLI (az)" az

# ── Infrastructure as Code ───────────────────────────────────────────────────
section "Infrastructure as Code"
check "Terraform" terraform
check_cmd "Terragrunt" terragrunt
check_cmd "Pulumi" pulumi
check_cmd "Ansible" ansible
check_cmd "tfsec" tfsec
check_cmd "infracost" infracost

# ── DevOps Tools ─────────────────────────────────────────────────────────────
section "DevOps & CI"
check_cmd "GitHub CLI (gh)" gh
check_cmd "pre-commit" pre-commit
check_cmd "make" make
check_cmd "cmake" cmake
check_cmd "direnv" direnv

# ── AI Tools ─────────────────────────────────────────────────────────────────
section "AI Tools"
check_cmd "Claude Code (claude)" claude
check_cmd "Ollama" ollama
check_cmd "Aider" aider

# ── API Keys ─────────────────────────────────────────────────────────────────
section "API Keys (env vars)"
check_env "Anthropic API Key" ANTHROPIC_API_KEY
check_env "OpenAI API Key" OPENAI_API_KEY
check_env "GitHub Token" GITHUB_TOKEN
check_env "AWS Access Key" AWS_ACCESS_KEY_ID

# ── Shell ────────────────────────────────────────────────────────────────────
section "Shell"
echo -e "  ${GREEN}✔${NC}  Shell: $SHELL"
echo -e "  ${GREEN}✔${NC}  Zsh: $(zsh --version 2>/dev/null | head -n1 || echo 'not found')"
check_cmd "Starship prompt" starship
check_cmd "zoxide" zoxide
check_cmd "atuin" atuin

# ── Summary ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))

echo ""
echo -e "${BOLD}╔════════════════════════════╗${NC}"
echo -e "${BOLD}║         Summary            ║${NC}"
echo -e "${BOLD}╠════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  ${GREEN}Installed:${NC}  $PASS / $TOTAL             ${BOLD}║${NC}"

if [[ $WARN -gt 0 ]]; then
  echo -e "${BOLD}║${NC}  ${YELLOW}Warnings:${NC}   $WARN                     ${BOLD}║${NC}"
fi

if [[ $FAIL -gt 0 ]]; then
  echo -e "${BOLD}║${NC}  ${RED}Missing:${NC}    $FAIL                     ${BOLD}║${NC}"
fi

echo -e "${BOLD}╚════════════════════════════╝${NC}"
echo ""

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "Tip (macOS): ${YELLOW}brew install <tool>${NC} or ${YELLOW}brew install --cask <app>${NC}"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo -e "Tip (Linux): ${YELLOW}sudo apt install <tool>${NC} or ${YELLOW}curl -fsSL <install-script>${NC}"
fi

echo ""
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
