#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install_ubuntu.sh — Cybersecurity Tools for Ubuntu/Debian
# Usage: sudo bash install_ubuntu.sh [category]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

[[ "$EUID" -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

CATEGORY="${1:-all}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

apt_install() {
  apt-get install -y --no-install-recommends "$@" 2>/dev/null && ok "apt: $*" || warn "apt: $* failed"
}

pip_install() {
  python3 -m pip install --quiet "$1" 2>/dev/null && ok "pip: $1" || warn "pip: $1 failed"
}

go_install() {
  GOPATH=/usr/local go install "$1" 2>/dev/null && ok "go: $1" || warn "go: $1 failed"
}

echo -e "\n${BOLD}Cybersecurity Tools Installer — Ubuntu/Debian${NC}"

# ── Update ────────────────────────────────────────────────────────────────────
info "Updating package lists..."
apt-get update -q

# ── Core ─────────────────────────────────────────────────────────────────────
install_core() {
  apt_install nmap netcat-openbsd curl wget jq git python3 python3-pip \
              golang-go build-essential libssl-dev libffi-dev
  pip_install requests
  ok "Core installed"
}

# ── Recon ─────────────────────────────────────────────────────────────────────
install_recon() {
  apt_install nmap whois dnsutils amass

  # subfinder, httpx, dnsx, nuclei (via Go)
  if command -v go &>/dev/null; then
    go_install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    go_install "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    go_install "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    go_install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
  fi

  pip_install theHarvester
  pip_install shodan

  # SecLists
  apt_install seclists 2>/dev/null || {
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists 2>/dev/null || true
  }
  ok "Recon installed"
}

# ── Web ───────────────────────────────────────────────────────────────────────
install_web() {
  apt_install sqlmap nikto

  # ffuf, gobuster via Go
  go_install "github.com/ffuf/ffuf/v2@latest"
  go_install "github.com/OJ/gobuster/v3@latest"

  apt_install python3-mitmproxy 2>/dev/null || pip_install mitmproxy

  pip_install xsstrike
  pip_install requests

  ok "Web tools installed"
}

# ── Password ──────────────────────────────────────────────────────────────────
install_password() {
  apt_install hashcat john hydra

  # wordlists
  apt_install wordlists
  [[ -f /usr/share/wordlists/rockyou.txt.gz ]] && \
    gunzip -f /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true

  ok "Password tools installed"
}

# ── Network ───────────────────────────────────────────────────────────────────
install_network() {
  apt_install nmap wireshark tcpdump tshark netcat-openbsd mtr iperf3 \
              socat masscan arp-scan net-tools

  pip_install scapy
  pip_install impacket

  # bettercap
  go_install "github.com/bettercap/bettercap@latest" 2>/dev/null || true

  ok "Network tools installed"
}

# ── Forensics ─────────────────────────────────────────────────────────────────
install_forensics() {
  apt_install binwalk foremost scalpel exiftool xxd sleuthkit \
              autopsy 2>/dev/null || true

  pip_install volatility3
  pip_install pillow
  pip_install pycryptodome

  ok "Forensics tools installed"
}

# ── Defensive ─────────────────────────────────────────────────────────────────
install_defense() {
  apt_install fail2ban suricata auditd aide rkhunter chkrootkit lynis

  # Update suricata rules
  suricata-update 2>/dev/null || true
  systemctl enable fail2ban 2>/dev/null || true
  systemctl enable auditd 2>/dev/null || true

  # Trivy
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
    sh -s -- -b /usr/local/bin 2>/dev/null || true

  # Gitleaks
  go_install "github.com/gitleaks/gitleaks/v8@latest" 2>/dev/null || true

  pip_install bandit
  pip_install semgrep

  ok "Defensive tools installed"
}

# ── CTF ───────────────────────────────────────────────────────────────────────
install_ctf() {
  apt_install steghide imagemagick pngcheck radare2 gdb
  apt_install ruby-dev && gem install zsteg 2>/dev/null || true

  pip_install pwntools
  pip_install pycryptodome
  pip_install sympy
  pip_install pillow
  pip_install angr 2>/dev/null || warn "angr install failed"

  # GDB with pwndbg
  git clone https://github.com/pwndbg/pwndbg /opt/pwndbg 2>/dev/null || \
    { cd /opt/pwndbg && git pull; }
  bash /opt/pwndbg/setup.sh 2>/dev/null || true

  # Ghidra
  if [[ ! -d /opt/ghidra ]]; then
    GHIDRA_VER="11.1.2"
    curl -L "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VER}_build/ghidra_${GHIDRA_VER}_PUBLIC_20240709.zip" \
      -o /tmp/ghidra.zip 2>/dev/null
    unzip -q /tmp/ghidra.zip -d /opt/ 2>/dev/null
    mv /opt/ghidra_* /opt/ghidra 2>/dev/null || true
    ln -sf /opt/ghidra/ghidraRun /usr/local/bin/ghidra 2>/dev/null || true
    ok "Ghidra installed"
  fi

  ok "CTF tools installed"
}

# ── Metasploit ────────────────────────────────────────────────────────────────
install_metasploit() {
  if ! command -v msfconsole &>/dev/null; then
    info "Installing Metasploit Framework..."
    curl -sSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod 755 /tmp/msfinstall
    /tmp/msfinstall
    msfdb init 2>/dev/null || true
    ok "Metasploit installed"
  else
    ok "Metasploit already installed"
  fi
}

# ── Run ───────────────────────────────────────────────────────────────────────
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
    install_metasploit
    ;;
  recon)       install_recon ;;
  web)         install_web ;;
  password)    install_password ;;
  network)     install_network ;;
  forensics)   install_forensics ;;
  defense)     install_defense ;;
  ctf)         install_ctf ;;
  metasploit)  install_metasploit ;;
  *)
    echo "Unknown: $CATEGORY"
    echo "Available: all | recon | web | password | network | forensics | defense | ctf | metasploit"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
