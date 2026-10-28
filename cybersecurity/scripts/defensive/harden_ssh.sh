#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# harden_ssh.sh — SSH Hardening Script
# Usage: sudo bash harden_ssh.sh [--dry-run]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

[[ "$EUID" -ne 0 && "$DRY_RUN" == false ]] && { echo "Run as root: sudo bash $0"; exit 1; }

apply() {
  local desc="$1"
  local cmd="$2"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[DRY]${NC} $desc"
    echo "        $cmd"
  else
    eval "$cmd"
    echo -e "  ${GREEN}[OK]${NC} $desc"
  fi
}

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

echo -e "\n${BOLD}SSH Hardening Script${NC}"
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}DRY RUN MODE — no changes will be made${NC}"

if [[ "$DRY_RUN" == false ]]; then
  # Backup current config
  cp "$SSHD_CONFIG" "$BACKUP"
  echo -e "${CYAN}[*]${NC} Backed up: $BACKUP"
fi

set_param() {
  local param="$1"
  local value="$2"
  local desc="$3"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[DRY]${NC} Set $param = $value  ($desc)"
    return
  fi

  if grep -qE "^#?${param}" "$SSHD_CONFIG"; then
    sed -i.bak "s|^#\?${param}.*|${param} ${value}|" "$SSHD_CONFIG"
  else
    echo "${param} ${value}" >> "$SSHD_CONFIG"
  fi
  echo -e "  ${GREEN}[OK]${NC} $param = $value  ($desc)"
}

echo ""
echo "=== Authentication ==="
set_param "PermitRootLogin"           "no"              "Disable root login"
set_param "PasswordAuthentication"    "no"              "Keys only, no passwords"
set_param "PubkeyAuthentication"      "yes"             "Enable key-based auth"
set_param "AuthenticationMethods"     "publickey"       "Only public key allowed"
set_param "MaxAuthTries"              "3"               "Max 3 login attempts"
set_param "LoginGraceTime"            "30"              "30 second login window"
set_param "MaxSessions"               "5"               "Max 5 concurrent sessions"
set_param "PermitEmptyPasswords"      "no"              "No empty passwords"
set_param "ChallengeResponseAuth"     "no"              "Disable challenge-response"
set_param "KerberosAuthentication"    "no"              "Disable Kerberos"
set_param "GSSAPIAuthentication"      "no"              "Disable GSSAPI"

echo ""
echo "=== Networking ==="
set_param "Port"                      "22"              "Change to non-standard if needed"
set_param "AddressFamily"             "inet"            "IPv4 only (use inet6 for IPv6)"
set_param "ListenAddress"             "0.0.0.0"         "Listen on all interfaces"
set_param "TCPKeepAlive"              "no"              "Use ClientAlive instead"
set_param "ClientAliveInterval"       "300"             "Send keepalive every 5 min"
set_param "ClientAliveCountMax"       "2"               "Disconnect after 2 missed"
set_param "UseDNS"                    "no"              "Faster logins (skip DNS)"

echo ""
echo "=== Security ==="
set_param "Protocol"                  "2"               "SSHv2 only"
set_param "X11Forwarding"             "no"              "Disable X11"
set_param "AllowAgentForwarding"      "no"              "Disable agent forwarding"
set_param "AllowTcpForwarding"        "no"              "Disable TCP forwarding"
set_param "PrintMotd"                 "no"              "No MOTD"
set_param "PrintLastLog"              "yes"             "Show last login"
set_param "Banner"                    "/etc/ssh/banner" "Legal warning banner"
set_param "StrictModes"               "yes"             "Check file permissions"
set_param "IgnoreRhosts"              "yes"             "Ignore .rhosts files"
set_param "HostbasedAuthentication"   "no"              "No host-based auth"

echo ""
echo "=== Cryptography ==="
set_param "KexAlgorithms" \
  "curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256" \
  "Strong key exchange"
set_param "Ciphers" \
  "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" \
  "Strong ciphers only"
set_param "MACs" \
  "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com" \
  "Strong MACs only"

echo ""
echo "=== Logging ==="
set_param "SyslogFacility"            "AUTH"            "Log to auth facility"
set_param "LogLevel"                  "VERBOSE"         "Verbose logging"

# ── SSH Banner ────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == false ]]; then
  cat > /etc/ssh/banner << 'EOF'
*******************************************************************************
AUTHORIZED ACCESS ONLY
This system is for authorized users only. All activity is monitored and logged.
Unauthorized access will be prosecuted.
*******************************************************************************
EOF
  echo -e "  ${GREEN}[OK]${NC} SSH banner created"
fi

# ── Key-Only: Generate user key if needed ─────────────────────────────────────
echo ""
echo "=== SSH Key Setup ==="
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  apply "Generate Ed25519 SSH key" \
    "ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519 -C '$(whoami)@$(hostname)'"
  echo -e "  ${YELLOW}Add public key to authorized_keys:${NC}"
  echo "  cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys"
  echo "  chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
else
  echo -e "  ${GREEN}[OK]${NC} Ed25519 key exists: ~/.ssh/id_ed25519"
fi

# ── Fail2Ban Integration ──────────────────────────────────────────────────────
echo ""
echo "=== Fail2Ban SSH Protection ==="
if command -v fail2ban-client &>/dev/null; then
  if [[ "$DRY_RUN" == false ]]; then
    cat > /etc/fail2ban/jail.d/sshd.conf << 'EOF'
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
findtime = 600
EOF
    systemctl restart fail2ban 2>/dev/null || true
    echo -e "  ${GREEN}[OK]${NC} Fail2Ban SSH jail configured (3 retries, 1hr ban)"
  else
    echo -e "  ${YELLOW}[DRY]${NC} Would configure Fail2Ban SSH jail"
  fi
else
  echo -e "  ${YELLOW}[!]${NC} Fail2Ban not installed — install: apt install fail2ban"
fi

# ── Validate & Restart ────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == false ]]; then
  echo ""
  echo -e "${CYAN}[*]${NC} Testing SSH config..."
  if sshd -t 2>/dev/null; then
    echo -e "${GREEN}[+]${NC} Config valid — restarting SSH..."
    systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null || true
    echo -e "${GREEN}[+]${NC} SSH restarted successfully"
  else
    echo -e "${RED}[!]${NC} Config has errors — restoring backup..."
    cp "$BACKUP" "$SSHD_CONFIG"
    echo -e "${GREEN}[+]${NC} Restored from backup: $BACKUP"
  fi
fi

echo ""
echo -e "${BOLD}=== Hardening Complete ===${NC}"
echo -e "  Test connection in a NEW terminal before closing this one!"
echo -e "  ssh -i ~/.ssh/id_ed25519 $(whoami)@$(hostname -I | awk '{print $1}')"
echo ""
echo -e "  Verify with: ${CYAN}ssh-audit$(hostname -I | awk '{print $1}')${NC}"
echo -e "  Online:      ${CYAN}https://sshcheck.com/${NC}"
