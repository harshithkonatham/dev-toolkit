# Shell Setup — Zsh, Bash, Aliases, Dotfiles

Complete shell configuration reference for productive terminal workflows.
Updated: April 2026.

---

## Table of Contents

1. [Zsh Configuration](#1-zsh-configuration)
2. [Oh My Zsh](#2-oh-my-zsh)
3. [Starship Prompt](#3-starship-prompt)
4. [Aliases & Functions](#4-aliases--functions)
5. [Dotfiles Management](#5-dotfiles-management)
6. [Environment Variables](#6-environment-variables)
7. [Shell Productivity Tools](#7-shell-productivity-tools)
8. [Bash Reference](#8-bash-reference)

---

## 1. Zsh Configuration

**`~/.zshrc`** — full recommended config:

```zsh
# ── PATH ─────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"

# Homebrew (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── OH MY ZSH ────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   # leave empty when using Starship

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-z
  docker
  kubectl
  aws
  npm
  python
  brew
  macos
)

source $ZSH/oh-my-zsh.sh

# ── HISTORY ──────────────────────────────────────────────────────────────────
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

# ── PROMPT ───────────────────────────────────────────────────────────────────
eval "$(starship init zsh)"

# ── NVM ──────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── PYENV ────────────────────────────────────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# ── GOLANG ───────────────────────────────────────────────────────────────────
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# ── RUST ─────────────────────────────────────────────────────────────────────
source "$HOME/.cargo/env"

# ── SDKMAN (Java) ────────────────────────────────────────────────────────────
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# ── DIRENV ───────────────────────────────────────────────────────────────────
eval "$(direnv hook zsh)"

# ── FZF ──────────────────────────────────────────────────────────────────────
source <(fzf --zsh)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# ── ALIASES & FUNCTIONS ──────────────────────────────────────────────────────
source ~/.zsh_aliases

# ── COMPLETIONS ──────────────────────────────────────────────────────────────
autoload -Uz compinit && compinit
```

---

## 2. Oh My Zsh

```bash
# Install
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

git clone https://github.com/agkozak/zsh-z \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z

# Update
omz update

# Reload
source ~/.zshrc
```

**Useful Oh My Zsh plugins:**

| Plugin | What it adds |
|---|---|
| `git` | Git aliases (`gst`, `gco`, `gcmsg`, `gp`, etc.) |
| `zsh-autosuggestions` | Fish-like command suggestions |
| `zsh-syntax-highlighting` | Command syntax coloring |
| `zsh-z` | Jump to frecent directories |
| `docker` | Docker autocompletion |
| `kubectl` | kubectl autocompletion + aliases |
| `aws` | AWS CLI autocompletion |
| `brew` | Homebrew aliases |
| `macos` | macOS-specific commands |
| `python` | Python aliases |
| `npm` | npm command aliases |

---

## 3. Starship Prompt

Cross-shell prompt — shows git branch, language versions, cloud context, exit codes.

```bash
# Install
brew install starship   # macOS
curl -sS https://starship.rs/install.sh | sh   # Linux

# Add to ~/.zshrc
eval "$(starship init zsh)"

# Add to ~/.bashrc
eval "$(starship init bash)"
```

**`~/.config/starship.toml`**:

```toml
# Prompt format
format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$nodejs\
$python\
$golang\
$rust\
$docker_context\
$kubernetes\
$aws\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[directory]
truncation_length = 3
truncate_to_repo = true
style = "bold cyan"

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
modified = "!${count}"
untracked = "?${count}"
staged = "+${count}"

[nodejs]
symbol = " "
detect_files = ["package.json", ".nvmrc"]

[python]
symbol = " "
detect_files = ["requirements.txt", "pyproject.toml", ".python-version"]
pyenv_version_name = true

[golang]
symbol = " "

[rust]
symbol = " "

[kubernetes]
disabled = false
symbol = "⎈ "
detect_files = ["Dockerfile", "docker-compose.yml"]

[aws]
disabled = false
symbol = " "
format = '[$symbol($profile)(\($region\))]($style) '
style = "bold yellow"

[cmd_duration]
min_time = 2000
format = "[$duration]($style) "
style = "yellow"
```

---

## 4. Aliases & Functions

**`~/.zsh_aliases`**:

```zsh
# ── Navigation ────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias dl='cd ~/Downloads'
alias dt='cd ~/Desktop'
alias dev='cd ~/Workspace'

# ── File listing ─────────────────────────────────────────────────────────────
alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias la='eza -la --icons'
alias lt='eza -lah --tree --level=2 --icons'
alias llt='eza -lah --tree --icons --git'

# ── File operations ──────────────────────────────────────────────────────────
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'
alias mkdir='mkdir -pv'

# ── Cat / bat ────────────────────────────────────────────────────────────────
alias cat='bat --style=plain'
alias catp='bat --style=plain --paging=never'
alias cath='bat --style=header,grid'

# ── Search ───────────────────────────────────────────────────────────────────
alias grep='grep --color=auto'
alias rg='rg --smart-case'
alias fd='fd --hidden'

# ── Network ──────────────────────────────────────────────────────────────────
alias myip='curl -s https://ipinfo.io/ip'
alias localip="ipconfig getifaddr en0"
alias ports='ss -tlnp'
alias ping='ping -c 5'

# ── Git shortcuts ────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -m'
alias gca='git commit --amend --no-edit'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull --rebase'
alias gst='git stash'
alias gstp='git stash pop'
alias gb='git branch -vv'
alias gbd='git branch -d'
alias gt='git tag'

# ── Docker ───────────────────────────────────────────────────────────────────
alias d='docker'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dimg='docker images'
alias drm='docker rm $(docker ps -aq)'
alias drmi='docker rmi $(docker images -q)'
alias dprune='docker system prune -af --volumes'
alias dexec='docker exec -it'

# ── Kubernetes ───────────────────────────────────────────────────────────────
alias k='kubectl'
alias kx='kubectx'
alias kns='kubens'
alias kg='kubectl get'
alias kgp='kubectl get pods -o wide'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kl='kubectl logs -f'
alias ka='kubectl apply -f'
alias kdel='kubectl delete'
alias keti='kubectl exec -ti'
alias kctx='kubectl config current-context'
alias kctxs='kubectl config get-contexts'

# ── Python ───────────────────────────────────────────────────────────────────
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv .venv'
alias activate='source .venv/bin/activate'
alias uvr='uv run'

# ── Node ─────────────────────────────────────────────────────────────────────
alias ni='npm install'
alias nid='npm install --save-dev'
alias nr='npm run'
alias nrb='npm run build'
alias nrd='npm run dev'
alias nrt='npm run test'
alias pi='pnpm install'
alias pr='pnpm run'
alias prd='pnpm run dev'

# ── System ───────────────────────────────────────────────────────────────────
alias top='btop'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias path='echo -e ${PATH//:/\\n}'
alias reload='source ~/.zshrc'
alias zshrc='$EDITOR ~/.zshrc'
alias aliases='$EDITOR ~/.zsh_aliases'

# ── macOS specific ───────────────────────────────────────────────────────────
alias o='open .'
alias finder='open -a Finder .'
alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES && killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO && killall Finder'
alias cleanup='find . -type f -name "*.DS_Store" -ls -delete'
alias flush='dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias lock='pmset displaysleepnow'
alias sleep='pmset sleepnow'
alias update='brew update && brew upgrade && brew cleanup'

# ── Claude Code ──────────────────────────────────────────────────────────────
alias ai='claude'
alias aip='claude --print'

# ── Terraform ────────────────────────────────────────────────────────────────
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'

# ── AWS ──────────────────────────────────────────────────────────────────────
alias awsid='aws sts get-caller-identity'
alias awsregion='aws configure get region'

# ── Misc ─────────────────────────────────────────────────────────────────────
alias weather='curl wttr.in'
alias cheat='curl cheat.sh/'       # cheat <command>
alias urlencode='python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))"'
alias urldecode='python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))"'
alias json='python3 -m json.tool'  # pretty print JSON: echo '{}' | json
alias uuid='python3 -c "import uuid; print(uuid.uuid4())"'
alias timestamp='date +%s'
alias dateutc='date -u +"%Y-%m-%dT%H:%M:%SZ"'

# ── FUNCTIONS ────────────────────────────────────────────────────────────────

# Create directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1" }

# Extract any archive
extract() {
  case "$1" in
    *.tar.bz2)  tar xjf "$1" ;;
    *.tar.gz)   tar xzf "$1" ;;
    *.tar.xz)   tar xJf "$1" ;;
    *.bz2)      bunzip2 "$1" ;;
    *.gz)       gunzip "$1" ;;
    *.tar)      tar xf "$1" ;;
    *.zip)      unzip "$1" ;;
    *.rar)      unrar x "$1" ;;
    *.7z)       7z x "$1" ;;
    *)          echo "'$1' cannot be extracted" ;;
  esac
}

# Find process using a port
port() { lsof -i ":$1" }

# Kill process on a port
killport() { lsof -ti ":$1" | xargs kill -9 }

# Serve current directory over HTTP
serve() { python3 -m http.server "${1:-8000}" }

# Search command history
his() { history | grep "$1" }

# Create a new GitHub repo from current dir
newrepo() {
  git init
  git add -A
  git commit -m "Initial commit"
  gh repo create --private --source=. --push
}

# Quick git commit and push
gcp() { git add -A && git commit -m "$1" && git push }

# Docker: exec into running container by partial name
dsh() {
  local container
  container=$(docker ps --format '{{.Names}}' | fzf --query="$1")
  docker exec -it "$container" /bin/bash 2>/dev/null || docker exec -it "$container" /bin/sh
}

# Kubectl: get pod logs with fuzzy finder
klog() {
  local pod
  pod=$(kubectl get pods --no-headers -o custom-columns=':metadata.name' | fzf)
  kubectl logs -f "$pod"
}

# Switch AWS profile with fzf
awsp() {
  local profile
  profile=$(aws configure list-profiles | fzf)
  export AWS_PROFILE="$profile"
  echo "Switched to AWS profile: $profile"
}

# Switch kubectl context with fzf
kctxf() {
  local ctx
  ctx=$(kubectl config get-contexts -o name | fzf)
  kubectl config use-context "$ctx"
}

# Generate a strong password
genpass() { openssl rand -base64 "${1:-32}" }

# Diff two files side by side
sidediff() { diff --side-by-side "$1" "$2" | less }

# Show top 10 largest files in current dir
biggest() { du -sh ./* | sort -rh | head -10 }

# Git: show uncommitted changes as patch
gitpatch() { git diff HEAD > "$(date +%Y%m%d_%H%M%S).patch" }

# Base64 encode/decode
b64enc() { echo -n "$1" | base64 }
b64dec() { echo -n "$1" | base64 -d }
```

---

## 5. Dotfiles Management

### Approach 1: Bare git repo (simplest)

```bash
# Initialize bare repo
git init --bare $HOME/.dotfiles

# Alias (add to .zshrc)
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Don't show untracked files
dotfiles config --local status.showUntrackedFiles no

# Add files
dotfiles add ~/.zshrc ~/.zsh_aliases ~/.gitconfig ~/.config/starship.toml
dotfiles commit -m "Initial dotfiles"
dotfiles remote add origin https://github.com/youruser/dotfiles.git
dotfiles push -u origin main
```

### Approach 2: chezmoi (recommended for multiple machines)

```bash
# Install
brew install chezmoi

# Init
chezmoi init

# Add files
chezmoi add ~/.zshrc
chezmoi add ~/.zsh_aliases
chezmoi add ~/.gitconfig
chezmoi add ~/.config/starship.toml

# Edit
chezmoi edit ~/.zshrc

# Apply changes
chezmoi apply

# Push to GitHub
chezmoi git -- remote add origin https://github.com/youruser/dotfiles.git
chezmoi git -- push -u origin main

# Bootstrap on a new machine
chezmoi init --apply https://github.com/youruser/dotfiles.git
```

---

## 6. Environment Variables

### direnv — per-directory .env loading

```bash
brew install direnv

# Add to ~/.zshrc
eval "$(direnv hook zsh)"

# In any project directory
cat > .envrc << 'EOF'
export API_KEY=xxx
export DATABASE_URL=postgresql://localhost/mydb
export NODE_ENV=development
EOF

direnv allow    # whitelist the directory
```

### Global environment setup

**`~/.zshenv`** (loaded for all shells, including non-interactive):

```zsh
# API keys (never commit these)
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GITHUB_TOKEN="ghp_..."

# Tool config
export EDITOR="code --wait"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS="-R"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# History
export HISTCONTROL=ignoreboth:erasedups
```

---

## 7. Shell Productivity Tools

### fzf — fuzzy finder

```bash
brew install fzf
$(brew --prefix)/opt/fzf/install   # install key bindings

# Key bindings after install:
# Ctrl+R  — fuzzy history search
# Ctrl+T  — fuzzy file picker
# Alt+C   — fuzzy cd
```

### zoxide — smarter cd

```bash
brew install zoxide

# Add to ~/.zshrc
eval "$(zoxide init zsh)"

# Usage
z project       # jump to most-used dir matching "project"
z -             # go to previous dir
zi              # interactive fuzzy selection
```

### atuin — shell history with sync

```bash
brew install atuin

# Add to ~/.zshrc
eval "$(atuin init zsh)"

# Key bindings
# Ctrl+R  — fuzzy history search with stats
atuin stats     # usage statistics
atuin sync      # sync across machines (optional)
```

### zsh-z (simpler alternative)

```bash
git clone https://github.com/agkozak/zsh-z \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z

# Add to plugins in .zshrc
plugins=(... zsh-z)

z project       # jump to matching directory
```

---

## 8. Bash Reference

For Linux servers and CI environments.

**`~/.bashrc`** minimal setup:

```bash
# ── History ──────────────────────────────────────────────────────────────────
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# ── Prompt (Starship) ────────────────────────────────────────────────────────
eval "$(starship init bash)"

# ── Source aliases ───────────────────────────────────────────────────────────
[ -f ~/.bash_aliases ] && source ~/.bash_aliases

# ── Completions ──────────────────────────────────────────────────────────────
if [ -f /usr/share/bash-completion/bash_completion ]; then
  source /usr/share/bash-completion/bash_completion
fi

# ── Tools ────────────────────────────────────────────────────────────────────
eval "$(direnv hook bash)"
eval "$(zoxide init bash)"
source <(fzf --bash)

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```
