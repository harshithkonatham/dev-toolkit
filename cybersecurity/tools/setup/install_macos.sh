#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install_macos.sh — Cybersecurity Tools for macOS
# Usage: bash install_macos.sh [category]
# Categories: all | recon | web | password | network | forensics | defense | ctf
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CATEGORY="${1:-all}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo -e "\n${BOLD}Cybersecurity Tools Installer — macOS${NC}"
echo -e "  Category: $CATEGORY\n"

# ── Homebrew check ────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew_install() {
  local pkg="$1"
  if brew list "$pkg" &>/dev/null; then
    warn "$pkg already installed"
  else
    info "Installing $pkg..."
    brew install "$pkg" && ok "$pkg installed"
  fi
}

brew_cask() {
  local pkg="$1"
  if brew list --cask "$pkg" &>/dev/null; then
    warn "$pkg (cask) already installed"
  else
    info "Installing $pkg (cask)..."
    brew install --cask "$pkg" && ok "$pkg installed"
  fi
}

pip_install() {
  python3 -m pip install --quiet "$1" 2>/dev/null && ok "pip: $1 installed" || warn "pip: $1 failed"
}

go_install() {
  go install "$1" 2>/dev/null && ok "go: $1 installed" || warn "go: $1 failed"
}

# ── Core (always install) ─────────────────────────────────────────────────────
install_core() {
  info "Installing core tools..."
  brew_install nmap
  brew_install netcat
  brew_install curl
  brew_install wget
  brew_install jq
  brew_install git
  brew_install python3
  brew_install go
  ok "Core tools complete"
}

# ── Recon ─────────────────────────────────────────────────────────────────────
install_recon() {
  info "Installing recon tools..."
  brew_install nmap
  brew_install amass
  brew_install subfinder    2>/dev/null || go_install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  brew_install dnsx         2>/dev/null || go_install "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
  brew_install httpx        2>/dev/null || go_install "github.com/projectdiscovery/httpx/cmd/httpx@latest"
  brew_install whatweb      2>/dev/null || warn "whatweb: install via gem install whatweb"
  brew_install theharvester 2>/dev/null || pip_install theHarvester
  brew_install shodan       2>/dev/null || pip_install shodan
  brew_install whois
  brew_install dig          2>/dev/null || brew_install bind

  # SecLists wordlists
  if ! brew list seclists &>/dev/null; then
    info "Installing SecLists..."
    brew install seclists
    ok "SecLists installed"
  fi

  ok "Recon tools complete"
}

# ── Web ───────────────────────────────────────────────────────────────────────
install_web() {
  info "Installing web attack tools..."
  brew_install sqlmap
  brew_install nikto
  brew_install ffuf         2>/dev/null || go_install "github.com/ffuf/ffuf/v2@latest"
  brew_install gobuster     2>/dev/null || go_install "github.com/OJ/gobuster/v3@latest"
  brew_install nuclei       2>/dev/null || go_install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
  brew_install mitmproxy
  brew_install openssl

  pip_install xsstrike
  pip_install requests
  pip_install beautifulsoup4

  # Burp Suite Community
  if ! brew list --cask burp-suite &>/dev/null; then
    info "Installing Burp Suite Community..."
    brew_cask burp-suite
  fi

  ok "Web tools complete"
}

# ── Password ──────────────────────────────────────────────────────────────────
install_password() {
  info "Installing password attack tools..."
  brew_install hashcat
  brew_install john
  brew_install hydra
  brew_install wordlist    2>/dev/null || true
  brew_install cewl        2>/dev/null || warn "cewl: gem install cewl"

  # rockyou.txt
  ROCKYOU_DIR="$HOME/wordlists"
  mkdir -p "$ROCKYOU_DIR"
  if [[ ! -f "$ROCKYOU_DIR/rockyou.txt" ]]; then
    info "Downloading rockyou.txt..."
    if [[ -f /opt/homebrew/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz ]]; then
      tar -xzf /opt/homebrew/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz \
        -C "$ROCKYOU_DIR/" 2>/dev/null || true
    fi
    ok "rockyou.txt → $ROCKYOU_DIR/rockyou.txt"
  fi

  ok "Password tools complete"
}

# ── Network ───────────────────────────────────────────────────────────────────
install_network() {
  info "Installing network tools..."
  brew_install nmap
  brew_install wireshark
  brew_install tcpdump
  brew_install netcat
  brew_install mtr
  brew_install iperf3
  brew_install socat
  brew_install masscan     2>/dev/null || warn "masscan: requires manual install"
  brew_install bettercap   2>/dev/null || warn "bettercap: install manually"
  brew_install scapy       2>/dev/null || pip_install scapy

  pip_install impacket
  pip_install scapy

  ok "Network tools complete"
}

# ── Forensics ─────────────────────────────────────────────────────────────────
install_forensics() {
  info "Installing forensics tools..."
  brew_install volatility  2>/dev/null || pip_install volatility3
  brew_install binwalk     2>/dev/null || pip_install binwalk
  brew_install foremost    2>/dev/null || warn "foremost: may not be in brew"
  brew_install exiftool
  brew_install sleuthkit   2>/dev/null || true
  brew_install autopsy     2>/dev/null || brew_cask autopsy 2>/dev/null || true
  brew_install xxd         2>/dev/null || true

  pip_install volatility3
  pip_install pillow
  pip_install pycryptodome

  ok "Forensics tools complete"
}

# ── Defensive ─────────────────────────────────────────────────────────────────
install_defense() {
  info "Installing defensive tools..."
  brew_install fail2ban    2>/dev/null || warn "fail2ban: Linux-focused tool"
  brew_install lynis
  brew_install trivy
  brew_install gitleaks
  brew_install bandit      2>/dev/null || pip_install bandit
  brew_install semgrep     2>/dev/null || pip_install semgrep

  pip_install safety
  pip_install detect-secrets

  ok "Defensive tools complete"
}

# ── CTF ───────────────────────────────────────────────────────────────────────
install_ctf() {
  info "Installing CTF tools..."
  brew_install pwntools     2>/dev/null || pip_install pwntools
  brew_install steghide
  brew_install zsteg        2>/dev/null || warn "zsteg: gem install zsteg"
  brew_install stegseek     2>/dev/null || warn "stegseek: https://github.com/RickdeJager/stegseek"
  brew_install imagemagick
  brew_install pngcheck
  brew_install radare2
  brew_install ghidra       2>/dev/null || brew_cask ghidra

  pip_install pwntools
  pip_install pycryptodome
  pip_install sympy
  pip_install gmpy2
  pip_install pillow
  pip_install angr          2>/dev/null || warn "angr: may fail on ARM — use x86"

  # CyberChef (Docker)
  if command -v docker &>/dev/null; then
    docker pull mpepping/cyberchef 2>/dev/null || true
    ok "CyberChef Docker image pulled"
    echo "  Run: docker run -d -p 8080:80 mpepping/cyberchef"
  fi

  ok "CTF tools complete"
}

# ── Update nuclei templates ───────────────────────────────────────────────────
update_templates() {
  if command -v nuclei &>/dev/null; then
    info "Updating Nuclei templates..."
    nuclei -update-templates 2>/dev/null && ok "Nuclei templates updated"
  fi
}

# ── Run selected category ─────────────────────────────────────────────────────
install_core

case "$CATEGORY" in
  all)
    install_recon
    install_web
    install_password
    install_network
    install_forensics
    install_defense
    install_ctf
    update_templates
    ;;
  recon)     install_recon ;;
  web)       install_web ;;
  password)  install_password ;;
  network)   install_network ;;
  forensics) install_forensics ;;
  defense)   install_defense ;;
  ctf)       install_ctf ;;
  *)
    echo "Unknown category: $CATEGORY"
    echo "Available: all | recon | web | password | network | forensics | defense | ctf"
    exit 1
    ;;
esac

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Installation Complete               ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""
echo "Verify with: bash ../../scripts/check-env.sh"
