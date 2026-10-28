#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# web_scan.sh — Full Web Application Security Scan
# Usage: bash web_scan.sh <url> [output_dir]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

URL="${1:?Usage: $0 <url> [output_dir]}"
OUTPUT_DIR="${2:-./webscan_$(echo "$URL" | sed 's|https\?://||;s|/.*||')_$(date +%Y%m%d_%H%M%S)}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()      { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }
ok()        { echo -e "${GREEN}[+]${NC} $1"; }
warn()      { echo -e "${YELLOW}[!]${NC} $1"; }
has_tool()  { command -v "$1" &>/dev/null; }

mkdir -p "$OUTPUT_DIR"/{headers,tech,dirs,vulns,ssl}

echo -e "\n${BOLD}╔═══════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Web Application Scan             ║${NC}"
echo -e "${BOLD}║  Target: $URL ${NC}"
echo -e "${BOLD}╚═══════════════════════════════════╝${NC}"

# ── HTTP Headers Analysis ─────────────────────────────────────────────────────
step "HTTP Headers & Response"
if has_tool curl; then
  curl -sI --max-time 15 -L "$URL" > "$OUTPUT_DIR/headers/response_headers.txt" 2>&1
  ok "Response headers saved"

  # Check security headers
  HEADERS=$(cat "$OUTPUT_DIR/headers/response_headers.txt")
  echo "=== Security Header Analysis ===" > "$OUTPUT_DIR/headers/security_audit.txt"

  check_header() {
    local header="$1"
    local label="$2"
    if echo "$HEADERS" | grep -qi "$header"; then
      echo "  [PASS] $label" >> "$OUTPUT_DIR/headers/security_audit.txt"
      echo -e "  ${GREEN}✔${NC}  $label present"
    else
      echo "  [MISS] $label" >> "$OUTPUT_DIR/headers/security_audit.txt"
      echo -e "  ${RED}✘${NC}  $label MISSING"
    fi
  }

  check_header "Strict-Transport-Security"     "HSTS"
  check_header "Content-Security-Policy"       "CSP"
  check_header "X-Frame-Options"               "X-Frame-Options"
  check_header "X-Content-Type-Options"        "X-Content-Type-Options"
  check_header "Referrer-Policy"               "Referrer-Policy"
  check_header "Permissions-Policy"            "Permissions-Policy"
  check_header "X-XSS-Protection"             "X-XSS-Protection"

  # Check for info disclosure
  if echo "$HEADERS" | grep -qi "Server:"; then
    SERVER=$(echo "$HEADERS" | grep -i "Server:" | head -1)
    warn "Server header exposed: $SERVER"
  fi
  if echo "$HEADERS" | grep -qi "X-Powered-By:"; then
    POWERED=$(echo "$HEADERS" | grep -i "X-Powered-By:" | head -1)
    warn "X-Powered-By exposed: $POWERED"
  fi
fi

# ── Technology Detection ───────────────────────────────────────────────────────
step "Technology Fingerprinting"
if has_tool whatweb; then
  whatweb -a 3 --log-verbose="$OUTPUT_DIR/tech/whatweb.txt" "$URL" 2>/dev/null
  ok "WhatWeb fingerprint complete"
  cat "$OUTPUT_DIR/tech/whatweb.txt" | head -20
fi

# ── SSL/TLS Audit ─────────────────────────────────────────────────────────────
step "SSL/TLS Configuration"
HOST=$(echo "$URL" | sed 's|https\?://||' | cut -d/ -f1 | cut -d: -f1)
PORT=$(echo "$URL" | grep -oP ':\K\d+' | head -1 || echo "443")

if has_tool nmap; then
  nmap -p "$PORT" --script=ssl-cert,ssl-enum-ciphers,ssl-heartbleed,ssl-poodle \
    "$HOST" > "$OUTPUT_DIR/ssl/nmap_ssl.txt" 2>&1
  ok "SSL scan complete"

  # Check for vulnerabilities
  if grep -qi "VULNERABLE" "$OUTPUT_DIR/ssl/nmap_ssl.txt" 2>/dev/null; then
    warn "SSL VULNERABILITIES FOUND — see $OUTPUT_DIR/ssl/nmap_ssl.txt"
  fi
fi

# Check cert details
if has_tool openssl; then
  echo | timeout 10 openssl s_client -connect "${HOST}:${PORT}" 2>/dev/null \
    | openssl x509 -noout -text 2>/dev/null > "$OUTPUT_DIR/ssl/cert_details.txt" || true
  EXPIRY=$(grep "Not After" "$OUTPUT_DIR/ssl/cert_details.txt" 2>/dev/null | head -1 || echo "N/A")
  ok "Certificate expiry: $EXPIRY"
fi

# ── Directory & File Fuzzing ──────────────────────────────────────────────────
step "Directory & File Discovery"

# ffuf (preferred)
if has_tool ffuf; then
  WORDLIST=""
  for wl in /usr/share/seclists/Discovery/Web-Content/common.txt \
             /usr/share/wordlists/dirb/common.txt \
             /opt/homebrew/share/seclists/Discovery/Web-Content/common.txt; do
    [[ -f "$wl" ]] && { WORDLIST="$wl"; break; }
  done

  if [[ -n "$WORDLIST" ]]; then
    ffuf -u "${URL}/FUZZ" \
         -w "$WORDLIST" \
         -e ".php,.html,.txt,.asp,.aspx,.jsp,.bak,.old,.json,.xml,.yaml,.env,.git" \
         -fc 404,429 \
         -t 50 \
         -mc 200,201,204,301,302,307,401,403 \
         -o "$OUTPUT_DIR/dirs/ffuf.json" \
         -of json \
         2>/dev/null || true
    ok "ffuf directory scan complete"
  else
    warn "No wordlist found — install seclists: brew install seclists"
  fi

# gobuster fallback
elif has_tool gobuster; then
  WORDLIST=""
  for wl in /usr/share/seclists/Discovery/Web-Content/common.txt \
             /usr/share/wordlists/dirb/common.txt; do
    [[ -f "$wl" ]] && { WORDLIST="$wl"; break; }
  done

  if [[ -n "$WORDLIST" ]]; then
    gobuster dir \
      -u "$URL" \
      -w "$WORDLIST" \
      -x php,html,txt,bak,json \
      -t 50 \
      --no-error \
      -o "$OUTPUT_DIR/dirs/gobuster.txt" \
      2>/dev/null || true
    ok "gobuster scan complete"
  fi
fi

# Check for common sensitive files
step "Sensitive File Detection"
SENSITIVE_PATHS=(
  "/.env" "/.env.local" "/.env.production"
  "/.git/HEAD" "/.git/config"
  "/robots.txt" "/sitemap.xml"
  "/phpinfo.php" "/info.php"
  "/admin" "/admin/" "/administrator"
  "/wp-login.php" "/wp-admin/"
  "/.htaccess" "/.htpasswd"
  "/web.config" "/app.config"
  "/backup.zip" "/backup.tar.gz" "/dump.sql"
  "/api" "/api/v1" "/api/swagger" "/swagger" "/swagger-ui"
  "/graphql" "/graphiql"
  "/.well-known/security.txt"
  "/crossdomain.xml" "/clientaccesspolicy.xml"
  "/server-status" "/server-info"
)

SENSITIVE_REPORT="$OUTPUT_DIR/dirs/sensitive_files.txt"
echo "# Sensitive File Scan: $URL" > "$SENSITIVE_REPORT"

for path in "${SENSITIVE_PATHS[@]}"; do
  STATUS=$(curl -so /dev/null -w "%{http_code}" --max-time 5 "${URL}${path}" 2>/dev/null || echo "000")
  case "$STATUS" in
    200)
      echo "  [200] $path" >> "$SENSITIVE_REPORT"
      echo -e "  ${RED}[200]${NC} ${RED}FOUND${NC}: $path"
      ;;
    301|302|307)
      echo "  [$STATUS] $path (redirect)" >> "$SENSITIVE_REPORT"
      echo -e "  ${YELLOW}[$STATUS]${NC} Redirect: $path"
      ;;
    401|403)
      echo "  [$STATUS] $path (protected)" >> "$SENSITIVE_REPORT"
      echo -e "  ${YELLOW}[$STATUS]${NC} Protected: $path"
      ;;
  esac
done

# ── Nikto Scan ────────────────────────────────────────────────────────────────
step "Nikto Web Vulnerability Scan"
if has_tool nikto; then
  nikto -h "$URL" -maxtime 120 -output "$OUTPUT_DIR/vulns/nikto.txt" 2>/dev/null || true
  ok "Nikto scan complete"
  NIKTO_ISSUES=$(grep -c "^\+" "$OUTPUT_DIR/vulns/nikto.txt" 2>/dev/null || echo 0)
  echo -e "  Issues found: ${YELLOW}$NIKTO_ISSUES${NC}"
else
  warn "nikto not installed (brew install nikto)"
fi

# ── Nuclei Scan ───────────────────────────────────────────────────────────────
step "Nuclei Vulnerability Templates"
if has_tool nuclei; then
  nuclei -u "$URL" \
         -severity medium,high,critical \
         -silent \
         -o "$OUTPUT_DIR/vulns/nuclei.txt" \
         2>/dev/null || true
  NUCLEI_FINDINGS=$(wc -l < "$OUTPUT_DIR/vulns/nuclei.txt" 2>/dev/null || echo 0)
  if [[ "$NUCLEI_FINDINGS" -gt 0 ]]; then
    echo -e "  ${RED}Nuclei findings: $NUCLEI_FINDINGS${NC}"
    cat "$OUTPUT_DIR/vulns/nuclei.txt"
  else
    ok "No Nuclei findings"
  fi
else
  warn "nuclei not installed (go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest)"
fi

# ── CORS Check ────────────────────────────────────────────────────────────────
step "CORS Misconfiguration Check"
CORS_RESPONSE=$(curl -sI --max-time 10 \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  "$URL" 2>/dev/null || echo "")

if echo "$CORS_RESPONSE" | grep -qi "Access-Control-Allow-Origin: \*"; then
  warn "CORS wildcard (*) detected — potential vulnerability"
elif echo "$CORS_RESPONSE" | grep -qi "Access-Control-Allow-Origin: https://evil.com"; then
  warn "CORS reflects arbitrary origin — potential vulnerability"
else
  ok "No obvious CORS misconfiguration"
fi

# ── Generate Report ───────────────────────────────────────────────────────────
step "Generating Report"
REPORT="$OUTPUT_DIR/REPORT.md"
cat > "$REPORT" << EOF
# Web Scan Report
- **Target:** $URL
- **Host:** $HOST
- **Date:** $(date)

## Security Headers
$(cat "$OUTPUT_DIR/headers/security_audit.txt" 2>/dev/null || echo "N/A")

## SSL/TLS
$(grep -E "TLSv|SSLv|cipher|VULNERABLE|expires" "$OUTPUT_DIR/ssl/nmap_ssl.txt" 2>/dev/null | head -10 || echo "N/A")

## Sensitive Files Found
$(grep "\[200\]" "$OUTPUT_DIR/dirs/sensitive_files.txt" 2>/dev/null || echo "None found")

## Vulnerability Findings
### Nikto
$(head -30 "$OUTPUT_DIR/vulns/nikto.txt" 2>/dev/null || echo "N/A")

### Nuclei
$(cat "$OUTPUT_DIR/vulns/nuclei.txt" 2>/dev/null || echo "N/A")

## Files
- Headers: headers/
- SSL: ssl/
- Directories: dirs/
- Vulnerabilities: vulns/
EOF

echo ""
echo -e "${GREEN}${BOLD}[+] Scan Complete${NC}"
echo -e "    Report: ${CYAN}$REPORT${NC}"
echo -e "    Output: ${CYAN}$OUTPUT_DIR${NC}"
