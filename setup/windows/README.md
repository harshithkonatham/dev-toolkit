# Windows / WSL2 Developer Setup

Complete Windows developer environment using WSL2 (Windows Subsystem for Linux).
Updated: April 2026 (Windows 11).

---

## 1. Enable WSL2

```powershell
# Run in PowerShell as Administrator
wsl --install                          # installs WSL2 + Ubuntu (default)
wsl --install -d Ubuntu-24.04          # specific distro

# Set WSL2 as default
wsl --set-default-version 2

# List available distros
wsl --list --online

# List installed
wsl --list --verbose

# Open WSL
wsl
ubuntu                                 # or the distro name
```

---

## 2. Windows Terminal

Install from Microsoft Store or:

```powershell
winget install Microsoft.WindowsTerminal
```

**Recommended settings** (`settings.json`):
- Default profile: Ubuntu
- Font: JetBrains Mono Nerd Font
- Startup: maximized

---

## 3. Winget — Windows Package Manager

```powershell
# Update winget
winget upgrade winget

# Search
winget search vscode

# Install
winget install Microsoft.VisualStudioCode
winget install Microsoft.PowerShell
winget install Git.Git
winget install GitHub.GitHubDesktop
winget install Google.Chrome
winget install Notion.Notion
winget install Discord.Discord
winget install Slack.Slack
winget install Zoom.Zoom
winget install Docker.DockerDesktop
winget install JetBrains.Toolbox
winget install Figma.Figma
winget install 1password.1password
winget install Obsidian.Obsidian

# Upgrade all
winget upgrade --all

# List installed
winget list

# Export app list
winget export -o apps.json

# Import app list
winget import -i apps.json
```

---

## 4. WSL2 Ubuntu Setup

After entering WSL (`wsl`):

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential build tools
sudo apt install -y \
  build-essential curl wget git vim \
  software-properties-common apt-transport-https ca-certificates \
  gnupg lsb-release unzip zip \
  jq yq htop tmux tree \
  net-tools dnsutils netcat

# Install zsh
sudo apt install -y zsh
chsh -s $(which zsh)

# Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Starship prompt
curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc
```

### Node.js in WSL2

```bash
# nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.zshrc
nvm install --lts
nvm alias default lts/*
npm install -g pnpm typescript ts-node
```

### Python in WSL2

```bash
# pyenv dependencies
sudo apt install -y \
  libssl-dev libffi-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libncurses5-dev \
  libncursesw5-dev xz-utils tk-dev liblzma-dev

# pyenv
curl https://pyenv.run | bash

# Add to ~/.zshrc
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
source ~/.zshrc

pyenv install 3.13.2
pyenv global 3.13.2

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Docker in WSL2

Use **Docker Desktop for Windows** — it integrates with WSL2 automatically.

```powershell
# Install Docker Desktop
winget install Docker.DockerDesktop
```

Enable in Docker Desktop: Settings → Resources → WSL Integration → Enable for your distro.

```bash
# Verify in WSL2
docker --version
docker compose version
docker run hello-world
```

### Kubernetes in WSL2

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# k9s
brew install k9s    # if using Linuxbrew
# or
curl -sS https://webinstall.dev/k9s | bash
```

### AWS CLI in WSL2

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
aws configure
```

---

## 5. Git Config for WSL2

```bash
# Global config in WSL2
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global core.autocrlf input    # important for Windows line endings
git config --global core.editor "code --wait"

# Use Windows credential manager from WSL2
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
```

---

## 6. VS Code with WSL2

```powershell
# Install VS Code
winget install Microsoft.VisualStudioCode

# Install Remote Development extension pack
code --install-extension ms-vscode-remote.vscode-remote-extensionpack
```

**Open WSL2 project in VS Code:**

```bash
# From inside WSL2
code .                     # opens VS Code connected to WSL2
```

VS Code automatically runs extensions inside WSL2 — full Linux environment with Windows UI.

---

## 7. Windows Performance Tips for Devs

### WSL2 `.wslconfig` (in `%USERPROFILE%`)

```ini
# C:\Users\YourName\.wslconfig
[wsl2]
memory=8GB           # limit RAM (default: 50% of system RAM)
processors=4         # limit CPU cores
swap=2GB
localhostForwarding=true
networkingMode=mirrored   # Windows 11 — share network with host
```

```powershell
# Restart WSL2 after changing .wslconfig
wsl --shutdown
wsl
```

### Fix WSL2 file system performance

Always work on Linux file system (`~`), not Windows files (`/mnt/c/`):

```bash
# Slow (Windows FS from WSL2)
cd /mnt/c/Users/you/projects/myapp

# Fast (Linux FS)
cd ~/projects/myapp
```

### Port forwarding WSL2 → Windows

WSL2 ports are automatically accessible from Windows at `localhost` (with `networkingMode=mirrored`).

---

## 8. PowerShell Setup

```powershell
# Install PowerShell 7
winget install Microsoft.PowerShell

# Install Oh My Posh
winget install JanDeDobbeleer.OhMyPosh

# Install modules
Install-Module -Name PSReadLine -Force
Install-Module -Name Terminal-Icons -Force
Install-Module -Name z -Force

# Microsoft.PowerShell_profile.ps1
oh-my-posh init pwsh | Invoke-Expression
Import-Module -Name Terminal-Icons
Import-Module -Name PSReadLine
Import-Module -Name z

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
```

---

## 9. Scoop — Alternative Windows Package Manager

```powershell
# Install Scoop
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Install packages
scoop install git nodejs python go
scoop install kubectl helm
scoop install fzf ripgrep fd bat eza jq

# Add buckets for more packages
scoop bucket add extras
scoop bucket add versions

# Update
scoop update *
```

---

## 10. Chocolatey — Another Windows Package Manager

```powershell
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install packages
choco install googlechrome -y
choco install vscode -y
choco install git -y
choco install nodejs-lts -y
choco install docker-desktop -y

# Upgrade all
choco upgrade all -y
```

---

## Windows vs WSL2 — When to Use What

| Task | Use |
|---|---|
| Node.js / Python development | WSL2 |
| Docker containers | Docker Desktop (WSL2 backend) |
| Kubernetes | WSL2 or Docker Desktop |
| VS Code | Windows app + WSL2 remote extension |
| Git | WSL2 (better performance) |
| Windows-only tools (Office, Teams) | Windows |
| Gaming | Windows |
| System administration scripts | PowerShell (Windows) |
| Shell scripting / automation | WSL2 bash/zsh |
