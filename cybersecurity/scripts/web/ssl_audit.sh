#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ssl_audit.sh — SSL/TLS Configuration Auditor
# Usage: bash ssl_audit.sh <host> [port]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HOST="${1:?Usage: $0 <host> [port]}"
PORT="${2:-443}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

pass()  { echo -e "  ${GREEN}✔ PASS${NC}  $1"; }
fail()  { echo -e "  ${RED}✘ FAIL${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠ WARN${NC}  $1"; }
info()  { echo -e "  ${CYAN}ℹ INFO${NC}  $1"; }

echo -e "\n${BOLD}SSL/TLS Audit: ${CYAN}${HOST}:${PORT}${NC}\n"

# ── Certificate Info ──────────────────────────────────────────────────────────
echo "=== Certificate Information ==="
if command -v openssl &>/dev/null; then
  CERT=$(echo | timeout 10 openssl s_client -connect "${HOST}:${PORT}" \
    -servername "$HOST" 2>/dev/null | openssl x509 -noout -text 2>/dev/null || echo "")

  if [[ -n "$CERT" ]]; then
    SUBJECT=$(echo "$CERT" | grep "Subject:" | head -1 | sed 's/.*Subject: //')
    ISSUER=$(echo "$CERT" | grep "Issuer:" | head -1 | sed 's/.*Issuer: //')
    NOT_BEFORE=$(echo "$CERT" | grep "Not Before" | sed 's/.*Not Before: //')
    NOT_AFTER=$(echo "$CERT" | grep "Not After" | sed 's/.*Not After : //')
    SAN=$(echo "$CERT" | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/.*DNS://;s/, DNS:/\n         /g')

    info "Subject:    $SUBJECT"
    info "Issuer:     $ISSUER"
    info "Valid from: $NOT_BEFORE"
    info "Valid until:$NOT_AFTER"
    info "SANs:       $SAN"

    # Check expiry
    EXPIRY_DATE=$(echo | timeout 10 openssl s_client -connect "${HOST}:${PORT}" \
      -servername "$HOST" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null \
      | cut -d= -f2 || echo "")

    if [[ -n "$EXPIRY_DATE" ]]; then
      EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$EXPIRY_DATE" +%s 2>/dev/null || echo 0)
      NOW_EPOCH=$(date +%s)
      DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

      if [[ "$DAYS_LEFT" -lt 0 ]]; then
        fail "Certificate EXPIRED ${DAYS_LEFT#-} days ago"
      elif [[ "$DAYS_LEFT" -lt 30 ]]; then
        fail "Certificate expires in $DAYS_LEFT days — URGENT"
      elif [[ "$DAYS_LEFT" -lt 90 ]]; then
        warn "Certificate expires in $DAYS_LEFT days"
      else
        pass "Certificate valid for $DAYS_LEFT days"
      fi
    fi
  else
    fail "Could not retrieve certificate"
  fi
fi

# ── Protocol Support ──────────────────────────────────────────────────────────
echo ""
echo "=== Protocol Support ==="

test_protocol() {
  local proto="$1"
  local flag="$2"
  local result
  result=$(echo | timeout 5 openssl s_client -connect "${HOST}:${PORT}" \
    "$flag" -servername "$HOST" 2>&1 | grep -E "Protocol|CONNECTED|Handshake" | head -1 || echo "failed")

  if echo "$result" | grep -q "CONNECTED"; then
    case "$proto" in
      SSLv2|SSLv3|TLSv1.0|TLSv1.1)
        fail "$proto supported — DEPRECATED/INSECURE"
        ;;
      TLSv1.2|TLSv1.3)
        pass "$proto supported"
        ;;
    esac
  else
    case "$proto" in
      SSLv2|SSLv3|TLSv1.0|TLSv1.1)
        pass "$proto disabled"
        ;;
      TLSv1.2|TLSv1.3)
        warn "$proto not supported"
        ;;
    esac
  fi
}

test_protocol "SSLv2"   "-ssl2"    2>/dev/null || true
test_protocol "SSLv3"   "-ssl3"    2>/dev/null || true
test_protocol "TLSv1.0" "-tls1"    2>/dev/null || true
test_protocol "TLSv1.1" "-tls1_1"  2>/dev/null || true
test_protocol "TLSv1.2" "-tls1_2"  2>/dev/null || true
test_protocol "TLSv1.3" "-tls1_3"  2>/dev/null || true

# ── Nmap SSL Scripts ──────────────────────────────────────────────────────────
echo ""
echo "=== Vulnerability Tests ==="
if command -v nmap &>/dev/null; then
  NMAP_OUT=$(nmap -p "$PORT" \
    --script=ssl-heartbleed,ssl-poodle,ssl-dh-params,ssl-ccs-injection,ssl-enum-ciphers \
    "$HOST" 2>/dev/null || echo "")

  if echo "$NMAP_OUT" | grep -qi "VULNERABLE"; then
    VULNS=$(echo "$NMAP_OUT" | grep -i "VULNERABLE")
    fail "Vulnerabilities detected:"
    echo "$VULNS"
  else
    pass "No common SSL vulnerabilities detected (Heartbleed, POODLE, etc.)"
  fi

  # Weak ciphers
  WEAK_CIPHERS=$(echo "$NMAP_OUT" | grep -E "RC4|DES|NULL|EXPORT|anon" || echo "")
  if [[ -n "$WEAK_CIPHERS" ]]; then
    fail "Weak ciphers detected:"
    echo "$WEAK_CIPHERS"
  else
    pass "No weak ciphers detected"
  fi
fi

# ── HSTS Check ────────────────────────────────────────────────────────────────
echo ""
echo "=== HSTS Check ==="
HSTS=$(curl -sI --max-time 10 "https://${HOST}:${PORT}/" 2>/dev/null \
  | grep -i "Strict-Transport-Security" || echo "")

if [[ -n "$HSTS" ]]; then
  pass "HSTS: $HSTS"
  echo "$HSTS" | grep -qi "preload" && pass "HSTS preload directive present" || warn "HSTS preload not set"
  echo "$HSTS" | grep -qi "includeSubDomains" && pass "HSTS includeSubDomains present" || warn "HSTS includeSubDomains not set"
  MAX_AGE=$(echo "$HSTS" | grep -oP 'max-age=\K\d+' || echo 0)
  [[ "$MAX_AGE" -ge 31536000 ]] && pass "HSTS max-age: $MAX_AGE seconds (≥1 year)" || warn "HSTS max-age low: $MAX_AGE"
else
  fail "HSTS not set — add: Strict-Transport-Security: max-age=31536000; includeSubDomains; preload"
fi

# ── Online Resources ──────────────────────────────────────────────────────────
echo ""
echo -e "=== Online Scanners ==="
echo -e "  ${CYAN}https://www.ssllabs.com/ssltest/analyze.html?d=${HOST}${NC}"
echo -e "  ${CYAN}https://testssl.sh/ (run locally: bash testssl.sh ${HOST}:${PORT})${NC}"
echo -e "  ${CYAN}https://hstspreload.org/?domain=${HOST}${NC}"
