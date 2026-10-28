#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# log_analyzer.sh — System Log Security Analyzer
# Usage: bash log_analyzer.sh [log_dir] [output_dir]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LOG_DIR="${1:-/var/log}"
OUTPUT_DIR="${2:-./log_analysis_$(date +%Y%m%d_%H%M%S)}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p "$OUTPUT_DIR"

alert() { echo -e "${RED}[ALERT]${NC} $1"; echo "[ALERT] $1" >> "$OUTPUT_DIR/alerts.txt"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }

echo -e "\n${BOLD}System Log Security Analyzer${NC}"
echo -e "  Log directory: ${CYAN}$LOG_DIR${NC}"
echo -e "  Output:        ${CYAN}$OUTPUT_DIR${NC}"
echo -e "  Date:          $(date)\n"

> "$OUTPUT_DIR/alerts.txt"

# Determine auth log location
AUTH_LOG=""
for f in "$LOG_DIR/auth.log" "$LOG_DIR/secure" "$LOG_DIR/messages"; do
  [[ -f "$f" ]] && { AUTH_LOG="$f"; break; }
done

# ── SSH Attack Analysis ────────────────────────────────────────────────────────
echo "=== SSH Authentication Failures ==="

if [[ -n "$AUTH_LOG" && -r "$AUTH_LOG" ]]; then
  FAILED_COUNT=$(grep -c "Failed password\|authentication failure\|Invalid user" "$AUTH_LOG" 2>/dev/null || echo 0)
  info "Total failed SSH attempts: $FAILED_COUNT"

  if [[ "$FAILED_COUNT" -gt 50 ]]; then
    alert "High SSH failure count: $FAILED_COUNT (possible brute force)"
  fi

  echo ""
  echo "Top attacking IPs:"
  grep "Failed password\|Invalid user" "$AUTH_LOG" 2>/dev/null | \
    grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
    sort | uniq -c | sort -rn | head -20 | \
    awk '{print "  " $1 " attempts from " $2}' | \
    tee "$OUTPUT_DIR/ssh_attackers.txt"

  echo ""
  echo "Targeted usernames:"
  grep "Invalid user" "$AUTH_LOG" 2>/dev/null | \
    grep -oP "Invalid user \K\S+" | sort | uniq -c | sort -rn | head -10 | \
    tee "$OUTPUT_DIR/ssh_usernames.txt"

  echo ""
  echo "Successful SSH logins (last 20):"
  grep "Accepted\|session opened" "$AUTH_LOG" 2>/dev/null | tail -20 | \
    tee "$OUTPUT_DIR/ssh_success.txt"

  # IPs with > 100 attempts (likely bots)
  BOT_IPS=$(grep "Failed password" "$AUTH_LOG" 2>/dev/null | \
    grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort | uniq -c | sort -rn | \
    awk '$1 > 100 {print $2}')
  if [[ -n "$BOT_IPS" ]]; then
    alert "Bot-level attack (>100 attempts) from: $(echo "$BOT_IPS" | tr '\n' ' ')"
  fi
else
  warn "Auth log not found or not readable: $AUTH_LOG"
fi

# ── Sudo Usage ────────────────────────────────────────────────────────────────
echo ""
echo "=== Sudo Usage ==="
if [[ -n "$AUTH_LOG" && -r "$AUTH_LOG" ]]; then
  grep "sudo:" "$AUTH_LOG" 2>/dev/null | tail -20 | tee "$OUTPUT_DIR/sudo_usage.txt"

  SUDO_FAIL=$(grep -c "sudo:.*FAILED" "$AUTH_LOG" 2>/dev/null || echo 0)
  [[ "$SUDO_FAIL" -gt 0 ]] && alert "Failed sudo attempts: $SUDO_FAIL"
fi

# ── System Changes ────────────────────────────────────────────────────────────
echo ""
echo "=== System Changes (syslog) ==="
SYSLOG=""
for f in "$LOG_DIR/syslog" "$LOG_DIR/messages"; do
  [[ -f "$f" && -r "$f" ]] && { SYSLOG="$f"; break; }
done

if [[ -n "$SYSLOG" ]]; then
  echo "Package installations:"
  grep -iE "install|upgrade|remove" "$SYSLOG" 2>/dev/null | tail -10

  echo ""
  echo "Cron executions (last 20):"
  grep -i "cron\|CMD" "$SYSLOG" 2>/dev/null | tail -20

  echo ""
  echo "Kernel messages:"
  dmesg 2>/dev/null | grep -iE "error|warning|fail|oom|usb|new device" | tail -20 || true
fi

# ── Web Server Log Analysis ────────────────────────────────────────────────────
echo ""
echo "=== Web Server Attack Patterns ==="

for access_log in "$LOG_DIR/nginx/access.log" "$LOG_DIR/apache2/access.log" \
                  "$LOG_DIR/httpd/access_log" /var/log/nginx/access.log; do
  [[ ! -f "$access_log" || ! -r "$access_log" ]] && continue

  info "Analyzing: $access_log"

  echo "Top IPs by request count:"
  awk '{print $1}' "$access_log" | sort | uniq -c | sort -rn | head -10

  echo ""
  echo "4xx/5xx errors:"
  grep -E '" [45][0-9]{2} ' "$access_log" | wc -l

  echo ""
  echo "Potential attack patterns:"

  # SQL injection
  SQL_COUNT=$(grep -ciE "union.*select|insert.*into|drop.*table|1=1|' or|%27|%3D" "$access_log" 2>/dev/null || echo 0)
  [[ "$SQL_COUNT" -gt 0 ]] && alert "Possible SQL injection attempts: $SQL_COUNT"

  # XSS
  XSS_COUNT=$(grep -ciE "<script|javascript:|onerror=|onload=|%3Cscript" "$access_log" 2>/dev/null || echo 0)
  [[ "$XSS_COUNT" -gt 0 ]] && alert "Possible XSS attempts: $XSS_COUNT"

  # Path traversal
  TRAV_COUNT=$(grep -ciE "\.\./|%2e%2e|%252e" "$access_log" 2>/dev/null || echo 0)
  [[ "$TRAV_COUNT" -gt 0 ]] && alert "Possible path traversal: $TRAV_COUNT"

  # Scanner detection
  SCAN_COUNT=$(grep -ciE "sqlmap|nikto|nmap|masscan|zgrab|nuclei|acunetix|nessus" "$access_log" 2>/dev/null || echo 0)
  [[ "$SCAN_COUNT" -gt 0 ]] && alert "Security scanner detected: $SCAN_COUNT requests"

  # Extract scanning IPs
  grep -iE "sqlmap|nikto|nmap|masscan" "$access_log" 2>/dev/null | \
    awk '{print $1}' | sort | uniq -c | sort -rn | head -5 | \
    awk '{print "  " $1 " scans from " $2}'

  echo ""
  echo "High-frequency IPs (>500 requests):"
  awk '{print $1}' "$access_log" | sort | uniq -c | sort -rn | \
    awk '$1 > 500 {print "  " $1 " reqs: " $2}'

  echo ""
  echo "Requested paths returning 200:"
  grep '" 200 ' "$access_log" | awk '{print $7}' | sort | uniq -c | sort -rn | head -10
done

# ── Login Analysis ────────────────────────────────────────────────────────────
echo ""
echo "=== Login Sessions ==="
last 2>/dev/null | head -20 | tee "$OUTPUT_DIR/logins.txt"

echo ""
echo "Currently logged in:"
who 2>/dev/null || w 2>/dev/null || true

# ── Process & Network ─────────────────────────────────────────────────────────
echo ""
echo "=== Suspicious Processes ==="
ps aux 2>/dev/null | grep -iE "nc -l|ncat|socat|msfconsole|netcat|bind_shell" | \
  grep -v grep | tee "$OUTPUT_DIR/suspicious_procs.txt" || true

echo ""
echo "=== Unusual Network Connections ==="
ss -tulnp 2>/dev/null | grep -v "LISTEN\|127.0.0.1" | head -20 || \
  netstat -tulnp 2>/dev/null | grep ESTABLISHED | head -20 || true

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
ALERT_COUNT=$(wc -l < "$OUTPUT_DIR/alerts.txt")
echo -e "\n${BOLD}╔═══════════════════════════════╗${NC}"
echo -e "${BOLD}║  Log Analysis Summary         ║${NC}"
echo -e "${BOLD}╠═══════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  Alerts: ${RED}$ALERT_COUNT${NC}                    ${BOLD}║${NC}"
echo -e "${BOLD}╚═══════════════════════════════╝${NC}"

if [[ "$ALERT_COUNT" -gt 0 ]]; then
  echo ""
  echo -e "${RED}=== ALERTS ===${NC}"
  cat "$OUTPUT_DIR/alerts.txt"
fi

echo ""
echo -e "Full output: ${CYAN}$OUTPUT_DIR/${NC}"
