#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# subdomain_enum.sh — Multi-Tool Subdomain Enumeration
# Usage: bash subdomain_enum.sh <domain> [output_dir]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DOMAIN="${1:?Usage: $0 <domain> [output_dir]}"
OUTPUT_DIR="${2:-./subdomains_${DOMAIN}}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

tool_run()  { echo -e "${CYAN}[*]${NC} Running $1..."; }
tool_done() { echo -e "${GREEN}[+]${NC} $1: $2 results"; }
tool_skip() { echo -e "${YELLOW}[-]${NC} $1 not installed — skipping"; }

mkdir -p "$OUTPUT_DIR"

echo -e "\n${BOLD}Subdomain Enumeration: $DOMAIN${NC}"

# ── 1. subfinder ──────────────────────────────────────────────────────────────
if command -v subfinder &>/dev/null; then
  tool_run "subfinder"
  subfinder -d "$DOMAIN" -silent -all \
    -o "$OUTPUT_DIR/subfinder.txt" 2>/dev/null || true
  tool_done "subfinder" "$(wc -l < "$OUTPUT_DIR/subfinder.txt" 2>/dev/null || echo 0)"
else
  tool_skip "subfinder (install: go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest)"
fi

# ── 2. amass ──────────────────────────────────────────────────────────────────
if command -v amass &>/dev/null; then
  tool_run "amass (passive)"
  timeout 120 amass enum -passive -d "$DOMAIN" \
    -o "$OUTPUT_DIR/amass.txt" 2>/dev/null || true
  tool_done "amass" "$(wc -l < "$OUTPUT_DIR/amass.txt" 2>/dev/null || echo 0)"
else
  tool_skip "amass (install: brew install amass)"
fi

# ── 3. theHarvester ───────────────────────────────────────────────────────────
if command -v theHarvester &>/dev/null; then
  tool_run "theHarvester"
  theHarvester -d "$DOMAIN" -l 300 -b bing,yahoo,google \
    -f "$OUTPUT_DIR/harvester" 2>/dev/null || true
  # Extract just subdomains
  grep -oE "[a-zA-Z0-9._-]+\.$DOMAIN" "$OUTPUT_DIR/harvester.json" 2>/dev/null \
    | sort -u > "$OUTPUT_DIR/harvester_subdomains.txt" || true
  tool_done "theHarvester" "$(wc -l < "$OUTPUT_DIR/harvester_subdomains.txt" 2>/dev/null || echo 0)"
else
  tool_skip "theHarvester (install: pip install theHarvester)"
fi

# ── 4. DNS bruteforce ─────────────────────────────────────────────────────────
tool_run "DNS bruteforce (common names)"
COMMON_SUBS=(
  www mail ftp ssh vpn api dev staging prod app admin portal
  beta cdn static assets media img images blog shop store
  test demo uat qa helpdesk support docs git gitlab jenkins
  ci cd build deploy monitor grafana kibana elastic
  api-v1 api-v2 v1 v2 auth oauth sso login account
  db database redis cache queue worker
  backup old legacy archive
)

BRUTEFORCE_FILE="$OUTPUT_DIR/bruteforce_input.txt"
for sub in "${COMMON_SUBS[@]}"; do
  echo "${sub}.${DOMAIN}"
done > "$BRUTEFORCE_FILE"

if command -v dnsx &>/dev/null; then
  dnsx -l "$BRUTEFORCE_FILE" -silent -a -resp \
    2>/dev/null | awk '{print $1}' | sort -u > "$OUTPUT_DIR/bruteforce.txt"
  tool_done "DNS bruteforce" "$(wc -l < "$OUTPUT_DIR/bruteforce.txt" 2>/dev/null || echo 0)"
elif command -v dig &>/dev/null; then
  # Fallback: use dig
  > "$OUTPUT_DIR/bruteforce.txt"
  while IFS= read -r fqdn; do
    result=$(dig +short "$fqdn" A 2>/dev/null | head -1)
    if [[ -n "$result" ]]; then
      echo "$fqdn" >> "$OUTPUT_DIR/bruteforce.txt"
      echo -e "  ${GREEN}✔${NC} $fqdn → $result"
    fi
  done < "$BRUTEFORCE_FILE"
  tool_done "DNS bruteforce (dig)" "$(wc -l < "$OUTPUT_DIR/bruteforce.txt")"
fi

# ── 5. Certificate transparency (crt.sh) ─────────────────────────────────────
tool_run "Certificate Transparency (crt.sh)"
if command -v curl &>/dev/null && command -v jq &>/dev/null; then
  curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null \
    | jq -r '.[].name_value' 2>/dev/null \
    | grep -v "^*" \
    | sort -u > "$OUTPUT_DIR/crtsh.txt" || true
  tool_done "crt.sh" "$(wc -l < "$OUTPUT_DIR/crtsh.txt" 2>/dev/null || echo 0)"
else
  tool_skip "crt.sh (requires curl + jq)"
fi

# ── 6. Merge & deduplicate ────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}[*]${NC} Merging all results..."

ALL_FILE="$OUTPUT_DIR/all_subdomains.txt"
cat "$OUTPUT_DIR"/*.txt 2>/dev/null \
  | grep -E "\.$DOMAIN$" \
  | sort -u > "$ALL_FILE" || true

TOTAL=$(wc -l < "$ALL_FILE")
echo -e "${GREEN}[+]${NC} Total unique subdomains: ${BOLD}$TOTAL${NC}"
echo -e "    Saved to: ${CYAN}$ALL_FILE${NC}"

# ── 7. Probe live web servers ─────────────────────────────────────────────────
if command -v httpx &>/dev/null && [[ -s "$ALL_FILE" ]]; then
  echo ""
  tool_run "httpx (probing live web servers)"
  httpx -l "$ALL_FILE" -silent -status-code -title -tech-detect -follow-redirects \
    -o "$OUTPUT_DIR/live_web.txt" 2>/dev/null || true
  echo -e "${GREEN}[+]${NC} Live web servers: $(wc -l < "$OUTPUT_DIR/live_web.txt" 2>/dev/null || echo 0)"
  echo ""
  echo "=== Live Web Servers ==="
  cat "$OUTPUT_DIR/live_web.txt" 2>/dev/null | head -20
fi

echo ""
echo -e "${BOLD}Done. Results in: ${CYAN}$OUTPUT_DIR/${NC}"
ls -la "$OUTPUT_DIR/"
