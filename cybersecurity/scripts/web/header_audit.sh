#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# header_audit.sh — HTTP Security Header Checker
# Usage: bash header_audit.sh <url>
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

URL="${1:?Usage: $0 <url>}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "\n${BOLD}HTTP Security Header Audit${NC}"
echo -e "Target: ${CYAN}$URL${NC}\n"

HEADERS=$(curl -sI --max-time 15 -L "$URL" 2>/dev/null)

pass() { echo -e "  ${GREEN}✔ PASS${NC}  $1"; }
fail() { echo -e "  ${RED}✘ FAIL${NC}  $1"; }
info() { echo -e "  ${YELLOW}ℹ INFO${NC}  $1"; }

SCORE=0
TOTAL=0

check() {
  local name="$1"
  local header_pattern="$2"
  local recommendation="$3"
  TOTAL=$((TOTAL + 1))

  if echo "$HEADERS" | grep -qi "$header_pattern"; then
    SCORE=$((SCORE + 1))
    VALUE=$(echo "$HEADERS" | grep -i "$header_pattern" | head -1 | sed 's/\r//')
    pass "$name → $VALUE"
  else
    fail "$name — $recommendation"
  fi
}

echo "=== Security Headers ==="
check "HSTS" \
  "Strict-Transport-Security:" \
  "Add: Strict-Transport-Security: max-age=31536000; includeSubDomains; preload"

check "Content-Security-Policy" \
  "Content-Security-Policy:" \
  "Add: Content-Security-Policy: default-src 'self'"

check "X-Frame-Options" \
  "X-Frame-Options:" \
  "Add: X-Frame-Options: DENY"

check "X-Content-Type-Options" \
  "X-Content-Type-Options:" \
  "Add: X-Content-Type-Options: nosniff"

check "Referrer-Policy" \
  "Referrer-Policy:" \
  "Add: Referrer-Policy: strict-origin-when-cross-origin"

check "Permissions-Policy" \
  "Permissions-Policy:" \
  "Add: Permissions-Policy: geolocation=(), microphone=(), camera=()"

check "Cache-Control" \
  "Cache-Control:" \
  "Add: Cache-Control: no-store for sensitive pages"

echo ""
echo "=== Information Disclosure ==="

if echo "$HEADERS" | grep -qi "^Server:"; then
  SERVER=$(echo "$HEADERS" | grep -i "^Server:" | head -1 | sed 's/\r//')
  fail "Server header exposed → $SERVER (remove or obfuscate)"
else
  pass "Server header hidden"
fi

if echo "$HEADERS" | grep -qi "X-Powered-By:"; then
  POWERED=$(echo "$HEADERS" | grep -i "X-Powered-By:" | head -1 | sed 's/\r//')
  fail "X-Powered-By exposed → $POWERED (remove this header)"
else
  pass "X-Powered-By header hidden"
fi

if echo "$HEADERS" | grep -qi "X-Generator:"; then
  GEN=$(echo "$HEADERS" | grep -i "X-Generator:" | head -1 | sed 's/\r//')
  fail "X-Generator exposed → $GEN"
else
  pass "X-Generator header hidden"
fi

if echo "$HEADERS" | grep -qi "X-AspNet-Version:\|X-AspNetMvc-Version:"; then
  fail "ASP.NET version exposed"
else
  pass "ASP.NET version hidden"
fi

echo ""
echo "=== Cookie Security ==="
if echo "$HEADERS" | grep -qi "Set-Cookie:"; then
  COOKIES=$(echo "$HEADERS" | grep -i "Set-Cookie:")
  echo "$COOKIES" | while read -r cookie; do
    cookie=$(echo "$cookie" | sed 's/\r//')
    NAME=$(echo "$cookie" | grep -oP 'Set-Cookie: \K[^=]+' | head -1)
    echo -e "  Cookie: ${CYAN}$NAME${NC}"
    echo "$cookie" | grep -qi "Secure"   && echo -e "    ${GREEN}✔${NC} Secure flag" || echo -e "    ${RED}✘${NC} Missing Secure flag"
    echo "$cookie" | grep -qi "HttpOnly" && echo -e "    ${GREEN}✔${NC} HttpOnly flag" || echo -e "    ${RED}✘${NC} Missing HttpOnly flag"
    echo "$cookie" | grep -qi "SameSite" && echo -e "    ${GREEN}✔${NC} SameSite set" || echo -e "    ${RED}✘${NC} Missing SameSite"
  done
else
  info "No Set-Cookie headers found"
fi

echo ""
echo "=== CORS ==="
CORS_RESP=$(curl -sI --max-time 10 \
  -H "Origin: https://evil-test.com" \
  "$URL" 2>/dev/null || echo "")

if echo "$CORS_RESP" | grep -qi "Access-Control-Allow-Origin: \*"; then
  fail "CORS Wildcard: allows any origin"
elif echo "$CORS_RESP" | grep -qi "Access-Control-Allow-Origin: https://evil-test.com"; then
  fail "CORS reflects arbitrary origin (insecure)"
elif echo "$CORS_RESP" | grep -qi "Access-Control-Allow-Origin:"; then
  CORS_VAL=$(echo "$CORS_RESP" | grep -i "Access-Control-Allow-Origin:" | head -1 | sed 's/\r//')
  pass "CORS restricted → $CORS_VAL"
else
  pass "No CORS headers (not exposed)"
fi

echo ""
echo "=== All Raw Headers ==="
echo "$HEADERS" | sed 's/\r//' | head -40

echo ""
echo -e "${BOLD}Score: ${SCORE}/${TOTAL} security headers present${NC}"
GRADE=$(awk "BEGIN { pct=$SCORE/$TOTAL*100; if(pct>=90) print \"A\"; else if(pct>=70) print \"B\"; else if(pct>=50) print \"C\"; else print \"F\" }")
echo -e "Grade: ${BOLD}${CYAN}$GRADE${NC}"
echo ""
echo -e "Check also: ${CYAN}https://securityheaders.com/?q=$URL${NC}"
