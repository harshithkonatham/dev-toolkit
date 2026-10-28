#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# audit_system.sh — Full System Security Audit
# Usage: bash audit_system.sh [output_dir]
# ─────────────────────────────────────────────────────────────────────────────

OUTPUT_DIR="${1:-./security_audit_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUTPUT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0

pass() { echo -e "  ${GREEN}✔ PASS${NC}  $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✘ FAIL${NC}  $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠ WARN${NC}  $1"; ((WARN++)); }
section() { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }

exec > >(tee "$OUTPUT_DIR/audit_report.txt") 2>&1

echo -e "\n${BOLD}╔═══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     System Security Audit             ║${NC}"
echo -e "${BOLD}╠═══════════════════════════════════════╣${NC}"
echo -e "${BOLD}║  Host: $(hostname)                    ${NC}"
echo -e "${BOLD}║  Date: $(date '+%Y-%m-%d %H:%M')     ${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════╝${NC}"

# ── OS & Kernel ───────────────────────────────────────────────────────────────
section "OS & Kernel"
echo "OS:     $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -s)"
echo "Kernel: $(uname -r)"
echo "Arch:   $(uname -m)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"

# Check for pending updates
if command -v apt &>/dev/null; then
  UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
  SECURITY=$(apt list --upgradable 2>/dev/null | grep -c security || true)
  [[ "$SECURITY" -gt 0 ]] && fail "Security updates available: $SECURITY" || pass "No security updates pending"
elif command -v yum &>/dev/null; then
  UPDATES=$(yum check-update --security 2>/dev/null | wc -l)
  [[ "$UPDATES" -gt 2 ]] && fail "Security updates available" || pass "No security updates pending"
elif command -v brew &>/dev/null; then
  warn "macOS: check 'softwareupdate -l' for security updates"
fi

# ── User Accounts ─────────────────────────────────────────────────────────────
section "User Account Security"

# Root account
if grep -q "^root:.*:/bin/bash\|^root:.*:/bin/sh\|^root:.*:/bin/zsh" /etc/passwd 2>/dev/null; then
  warn "Root account has login shell"
else
  pass "Root login shell restricted"
fi

# Empty passwords
EMPTY_PASS=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null || echo "")
[[ -z "$EMPTY_PASS" ]] && pass "No accounts with empty passwords" || \
  fail "Accounts with empty/locked passwords: $EMPTY_PASS"

# UID 0 accounts (besides root)
UID0=$(awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd 2>/dev/null || echo "")
[[ -z "$UID0" ]] && pass "No unauthorized UID 0 accounts" || \
  fail "Non-root UID 0 accounts: $UID0"

# Password aging
if [[ -f /etc/login.defs ]]; then
  MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
  MIN_DAYS=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')
  [[ "${MAX_DAYS:-99999}" -le 90 ]] && pass "Password max age: $MAX_DAYS days" || \
    warn "Password max age too long: $MAX_DAYS (recommend ≤90)"
fi

# sudo config
if [[ -f /etc/sudoers ]]; then
  if grep -qE "NOPASSWD" /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
    warn "NOPASSWD entries in sudoers — review carefully"
  else
    pass "No NOPASSWD in sudoers"
  fi
fi

# ── SSH Configuration ─────────────────────────────────────────────────────────
section "SSH Configuration"

check_ssh() {
  local param="$1"
  local desired="$2"
  local label="$3"
  local val
  val=$(sshd -T 2>/dev/null | grep -i "^${param}" | awk '{print $2}' | head -1 || echo "")

  if [[ -z "$val" ]]; then
    warn "$label (could not determine)"
    return
  fi

  if [[ "${val,,}" == "${desired,,}" ]]; then
    pass "$label: $val"
  else
    fail "$label: $val (should be $desired)"
  fi
}

if command -v sshd &>/dev/null; then
  check_ssh "permitrootlogin"        "no"        "Root login disabled"
  check_ssh "passwordauthentication" "no"        "Password auth disabled"
  check_ssh "permitemptypasswords"   "no"        "Empty passwords disabled"
  check_ssh "x11forwarding"          "no"        "X11 forwarding disabled"
  check_ssh "protocol"               "2"         "SSH Protocol 2 only"
  check_ssh "maxauthtries"           "3"         "Max auth tries"
  check_ssh "logingracetime"         "30"        "Login grace time"

  # Check SSH port
  SSH_PORT=$(sshd -T 2>/dev/null | grep "^port" | awk '{print $2}')
  [[ "$SSH_PORT" != "22" ]] && \
    pass "SSH on non-standard port: $SSH_PORT" || \
    warn "SSH on default port 22 (consider changing)"
else
  warn "SSH not running"
fi

# ── Firewall ──────────────────────────────────────────────────────────────────
section "Firewall"

if command -v ufw &>/dev/null; then
  UFW_STATUS=$(ufw status 2>/dev/null | head -1)
  [[ "$UFW_STATUS" == *"active"* ]] && pass "UFW firewall active" || fail "UFW firewall inactive"
  ufw status numbered 2>/dev/null | head -15

elif command -v firewall-cmd &>/dev/null; then
  FWSTATE=$(firewall-cmd --state 2>/dev/null)
  [[ "$FWSTATE" == "running" ]] && pass "firewalld active" || fail "firewalld not running"

elif command -v iptables &>/dev/null; then
  RULES=$(iptables -L 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT")
  [[ "$RULES" -gt 0 ]] && pass "iptables rules present ($RULES rules)" || \
    warn "iptables has no rules (default ACCEPT)"

elif [[ "$(uname)" == "Darwin" ]]; then
  FW_STATUS=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
  [[ "$FW_STATUS" -ge 1 ]] && pass "macOS firewall enabled" || warn "macOS firewall disabled"
fi

# ── Open Ports ────────────────────────────────────────────────────────────────
section "Open Ports & Services"
echo "Listening ports:"
ss -tulnp 2>/dev/null | grep LISTEN | tee "$OUTPUT_DIR/open_ports.txt"

# Check for dangerous open services
DANGER_PORTS="23:Telnet 512:rexec 513:rlogin 514:rsh 111:RPC 2049:NFS 6000:X11"
for entry in $DANGER_PORTS; do
  PORT=$(echo "$entry" | cut -d: -f1)
  NAME=$(echo "$entry" | cut -d: -f2)
  if ss -tulnp 2>/dev/null | grep -q ":$PORT "; then
    fail "$NAME (port $PORT) is open — DANGEROUS"
  fi
done

# ── File Permissions ──────────────────────────────────────────────────────────
section "Critical File Permissions"

check_perm() {
  local file="$1"
  local expected="$2"
  local label="$3"
  [[ ! -e "$file" ]] && return

  local actual
  actual=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null || echo "???")
  [[ "$actual" == "$expected" ]] && pass "$label: $file ($actual)" || \
    fail "$label: $file (got $actual, expected $expected)"
}

check_perm "/etc/passwd"   "644" "/etc/passwd"
check_perm "/etc/shadow"   "640" "/etc/shadow"
check_perm "/etc/gshadow"  "640" "/etc/gshadow"
check_perm "/etc/group"    "644" "/etc/group"
check_perm "/etc/ssh/sshd_config" "600" "sshd_config"
check_perm "/etc/crontab"  "644" "/etc/crontab"
check_perm "/boot/grub/grub.cfg" "400" "grub.cfg"

# World-writable files outside /tmp
echo ""
echo "World-writable files (excluding /tmp, /proc, /sys):"
WWORLD=$(find / -xdev -type f -perm -0002 2>/dev/null | \
  grep -v "^/tmp\|^/proc\|^/sys\|^/dev\|^/run" | head -10)
if [[ -n "$WWORLD" ]]; then
  fail "World-writable files found:"
  echo "$WWORLD"
else
  pass "No unsafe world-writable files"
fi

# SUID files
SUID_COUNT=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
[[ "$SUID_COUNT" -gt 30 ]] && warn "High SUID count: $SUID_COUNT" || \
  pass "SUID count reasonable: $SUID_COUNT"

# ── Package Security ──────────────────────────────────────────────────────────
section "Installed Security Tools"

tools_check() {
  local tool="$1"
  local label="$2"
  command -v "$tool" &>/dev/null && pass "$label installed" || warn "$label not installed"
}

tools_check "fail2ban-client" "Fail2Ban (SSH/brute force protection)"
tools_check "rkhunter"        "rkhunter (rootkit detector)"
tools_check "chkrootkit"      "chkrootkit (rootkit detector)"
tools_check "lynis"           "Lynis (security auditor)"
tools_check "auditd"          "auditd (system audit daemon)"
tools_check "aide"            "AIDE (file integrity monitor)"
tools_check "trivy"           "Trivy (container scanner)"

# ── System Integrity ──────────────────────────────────────────────────────────
section "System Integrity"

# Check /tmp is mounted noexec
if mount | grep -qE "on /tmp.*noexec"; then
  pass "/tmp mounted noexec"
else
  warn "/tmp not mounted with noexec"
fi

# Core dumps disabled
CORE=$(ulimit -c)
[[ "$CORE" == "0" ]] && pass "Core dumps disabled" || warn "Core dumps enabled ($CORE)"

# ASLR
if [[ -f /proc/sys/kernel/randomize_va_space ]]; then
  ASLR=$(cat /proc/sys/kernel/randomize_va_space)
  [[ "$ASLR" == "2" ]] && pass "ASLR enabled (full randomization)" || \
    [[ "$ASLR" == "1" ]] && warn "ASLR partial" || fail "ASLR disabled"
fi

# Kernel hardening
if [[ -f /proc/sys/net/ipv4/tcp_syncookies ]]; then
  [[ "$(cat /proc/sys/net/ipv4/tcp_syncookies)" == "1" ]] && \
    pass "TCP SYN cookies enabled" || fail "TCP SYN cookies disabled (SYN flood risk)"
fi

if [[ -f /proc/sys/net/ipv4/conf/all/accept_redirects ]]; then
  [[ "$(cat /proc/sys/net/ipv4/conf/all/accept_redirects)" == "0" ]] && \
    pass "ICMP redirects disabled" || warn "ICMP redirects accepted"
fi

# ── Log Files ─────────────────────────────────────────────────────────────────
section "Logging"

LOG_FILES=("/var/log/auth.log" "/var/log/secure" "/var/log/syslog" "/var/log/messages")
for log in "${LOG_FILES[@]}"; do
  [[ -f "$log" ]] && pass "Log present: $log" || true
done

# Check for recent failed logins
FAILED=$(grep -c "Failed password\|authentication failure" /var/log/auth.log 2>/dev/null || \
         grep -c "Failed password" /var/log/secure 2>/dev/null || echo "0")
[[ "$FAILED" -gt 100 ]] && warn "High failed login count: $FAILED" || \
  [[ "$FAILED" -gt 0 ]] && pass "Failed logins: $FAILED" || true

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))
SCORE=$(awk "BEGIN { printf \"%.0f\", ($PASS/$TOTAL)*100 }")

echo ""
echo -e "${BOLD}╔════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Audit Summary              ║${NC}"
echo -e "${BOLD}╠════════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  ${GREEN}PASS:${NC} $PASS                      ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ${YELLOW}WARN:${NC} $WARN                      ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ${RED}FAIL:${NC} $FAIL                      ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  Score: ${CYAN}${SCORE}%${NC}                   ${BOLD}║${NC}"
echo -e "${BOLD}╚════════════════════════════════╝${NC}"
echo ""
echo -e "Report: ${CYAN}$OUTPUT_DIR/audit_report.txt${NC}"
echo ""
echo "Next steps:"
echo "  sudo lynis audit system"
echo "  sudo rkhunter --check"
echo "  bash harden_ssh.sh"
echo "  bash setup_ids.sh"
