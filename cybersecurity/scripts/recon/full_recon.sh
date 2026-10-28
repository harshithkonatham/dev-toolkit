#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# full_recon.sh — Complete Reconnaissance Pipeline
# Usage: bash full_recon.sh <domain> [output_dir]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

TARGET="${1:?Usage: $0 <domain> [output_dir]}"
OUTPUT_DIR="${2:-./recon_${TARGET}_$(date +%Y%m%d_%H%M%S)}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

banner() { echo -e "\n${CYAN}${BOLD}[*] $1${NC}"; }
ok()     { echo -e "${GREEN}[+]${NC} $1"; }
info()   { echo -e "${BLUE}[i]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }

check_tool() {
  command -v "$1" &>/dev/null || { warn "$1 not found — skipping related checks"; return 1; }
}

mkdir -p "$OUTPUT_DIR"/{dns,subdomains,ports,web,whois,screenshots}

echo -e "\n${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        Full Recon — $TARGET ${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
info "Output directory: $OUTPUT_DIR"
info "Start time: $(date)"

# ── WHOIS ────────────────────────────────────────────────────────────────────
banner "WHOIS Lookup"
if check_tool whois; then
  whois "$TARGET" > "$OUTPUT_DIR/whois/whois.txt" 2>&1
  ok "WHOIS saved"
  grep -E "Registrar:|Registrant|Name Server|Creation Date|Expiry Date" "$OUTPUT_DIR/whois/whois.txt" | head -20 || true
fi

# ── DNS Enumeration ───────────────────────────────────────────────────────────
banner "DNS Enumeration"
if check_tool dig; then
  for record in A AAAA MX NS TXT SOA CNAME; do
    echo "=== $record ===" >> "$OUTPUT_DIR/dns/dns_records.txt"
    dig "$TARGET" "$record" +short >> "$OUTPUT_DIR/dns/dns_records.txt" 2>&1
    echo "" >> "$OUTPUT_DIR/dns/dns_records.txt"
  done
  ok "DNS records saved"

  # Zone transfer attempt
  echo "=== AXFR Attempt ===" >> "$OUTPUT_DIR/dns/zone_transfer.txt"
  NS_SERVERS=$(dig "$TARGET" NS +short)
  while IFS= read -r ns; do
    echo "Trying NS: $ns" >> "$OUTPUT_DIR/dns/zone_transfer.txt"
    dig axfr "@$ns" "$TARGET" >> "$OUTPUT_DIR/dns/zone_transfer.txt" 2>&1
  done <<< "$NS_SERVERS"
  ok "Zone transfer attempt saved"

  # Reverse DNS for common IPs
  TARGET_IP=$(dig "$TARGET" A +short | head -1)
  if [[ -n "$TARGET_IP" ]]; then
    dig -x "$TARGET_IP" +short > "$OUTPUT_DIR/dns/reverse_dns.txt" 2>&1
    ok "Reverse DNS: $TARGET_IP → $(cat "$OUTPUT_DIR/dns/reverse_dns.txt")"
  fi
fi

# ── Subdomain Enumeration ─────────────────────────────────────────────────────
banner "Subdomain Enumeration"

# subfinder
if check_tool subfinder; then
  info "Running subfinder..."
  subfinder -d "$TARGET" -silent -o "$OUTPUT_DIR/subdomains/subfinder.txt" 2>/dev/null
  ok "subfinder: $(wc -l < "$OUTPUT_DIR/subdomains/subfinder.txt") subdomains"
fi

# amass (passive)
if check_tool amass; then
  info "Running amass (passive)..."
  amass enum -passive -d "$TARGET" -o "$OUTPUT_DIR/subdomains/amass.txt" 2>/dev/null || true
  ok "amass: $(wc -l < "$OUTPUT_DIR/subdomains/amass.txt" 2>/dev/null || echo 0) subdomains"
fi

# theHarvester
if check_tool theHarvester; then
  info "Running theHarvester..."
  theHarvester -d "$TARGET" -l 200 -b bing,google,yahoo \
    -f "$OUTPUT_DIR/subdomains/harvester" 2>/dev/null || true
  ok "theHarvester complete"
fi

# DNS brute force with common subdomains
if check_tool dnsx; then
  info "DNS bruteforcing common subdomains..."
  COMMON_SUBS="www mail ftp ssh vpn api dev staging prod app admin portal beta cdn static assets"
  for sub in $COMMON_SUBS; do
    echo "${sub}.${TARGET}"
  done | dnsx -silent -a -resp 2>/dev/null >> "$OUTPUT_DIR/subdomains/brute.txt" || true
  ok "DNS bruteforce complete"
fi

# Merge and deduplicate all subdomains
cat "$OUTPUT_DIR/subdomains/"*.txt 2>/dev/null | sort -u > "$OUTPUT_DIR/subdomains/all_subdomains.txt" || true
SUBDOMAIN_COUNT=$(wc -l < "$OUTPUT_DIR/subdomains/all_subdomains.txt" 2>/dev/null || echo 0)
ok "Total unique subdomains: $SUBDOMAIN_COUNT"

# ── Port Scanning ─────────────────────────────────────────────────────────────
banner "Port Scanning"
TARGET_IP=$(dig "$TARGET" A +short | head -1)

if check_tool nmap && [[ -n "$TARGET_IP" ]]; then
  info "Quick scan (top 1000 ports)..."
  nmap -sV -sC -T4 --open -oA "$OUTPUT_DIR/ports/quick_scan" "$TARGET_IP" 2>/dev/null
  ok "Quick scan complete"

  info "Full port scan (all 65535)..."
  nmap -p- -T4 --open -oA "$OUTPUT_DIR/ports/full_scan" "$TARGET_IP" 2>/dev/null
  ok "Full scan complete"

  # Extract open ports
  grep "open" "$OUTPUT_DIR/ports/quick_scan.nmap" 2>/dev/null | grep -v "#" > "$OUTPUT_DIR/ports/open_ports.txt" || true
  ok "Open ports:"
  cat "$OUTPUT_DIR/ports/open_ports.txt"
fi

# ── Web Discovery ─────────────────────────────────────────────────────────────
banner "Web Discovery"

for proto in http https; do
  URL="${proto}://${TARGET}"
  info "Checking $URL..."

  # HTTP headers
  if check_tool curl; then
    curl -sI --max-time 10 "$URL" > "$OUTPUT_DIR/web/${proto}_headers.txt" 2>&1 || true
    ok "Headers saved: ${proto}_headers.txt"
  fi

  # Technology detection
  if check_tool whatweb; then
    whatweb -a 3 "$URL" > "$OUTPUT_DIR/web/${proto}_whatweb.txt" 2>/dev/null || true
    ok "Technology: $(cat "$OUTPUT_DIR/web/${proto}_whatweb.txt" | head -1)"
  fi
done

# Check subdomains for live web
if check_tool httpx && [[ -f "$OUTPUT_DIR/subdomains/all_subdomains.txt" ]]; then
  info "Probing subdomains for live web servers..."
  httpx -l "$OUTPUT_DIR/subdomains/all_subdomains.txt" \
    -silent -status-code -title -tech-detect \
    -o "$OUTPUT_DIR/web/live_subdomains.txt" 2>/dev/null || true
  ok "Live web servers: $(wc -l < "$OUTPUT_DIR/web/live_subdomains.txt" 2>/dev/null || echo 0)"
fi

# ── Google Dorks ──────────────────────────────────────────────────────────────
banner "Google Dorks (Manual)"
cat > "$OUTPUT_DIR/web/google_dorks.txt" << EOF
# Google Dorks for: $TARGET
# Search these manually at https://google.com

site:$TARGET filetype:pdf
site:$TARGET filetype:xlsx OR filetype:csv OR filetype:sql
site:$TARGET inurl:login OR inurl:admin OR inurl:dashboard
site:$TARGET inurl:api OR inurl:v1 OR inurl:v2
site:$TARGET ext:env OR ext:log OR ext:conf OR ext:bak
site:$TARGET "Index of /"
site:$TARGET "phpMyAdmin" OR "wp-login"
site:$TARGET "SQL syntax" OR "mysql_fetch" OR "Warning:"
inurl:s3.amazonaws.com "$TARGET"
site:github.com "$TARGET" password
site:github.com "$TARGET" secret OR api_key
site:pastebin.com "$TARGET"
"$TARGET" filetype:pdf "confidential"
EOF
ok "Google dorks saved"

# ── Summary Report ────────────────────────────────────────────────────────────
banner "Generating Summary Report"
REPORT="$OUTPUT_DIR/REPORT.md"
cat > "$REPORT" << EOF
# Recon Report: $TARGET
Generated: $(date)

## Target Information
- Domain: $TARGET
- IP: $(dig "$TARGET" A +short | head -1)
- WHOIS Registrar: $(grep -i "Registrar:" "$OUTPUT_DIR/whois/whois.txt" 2>/dev/null | head -1 || echo "N/A")

## DNS Records
\`\`\`
$(cat "$OUTPUT_DIR/dns/dns_records.txt" 2>/dev/null | head -30)
\`\`\`

## Subdomains ($SUBDOMAIN_COUNT found)
\`\`\`
$(head -20 "$OUTPUT_DIR/subdomains/all_subdomains.txt" 2>/dev/null || echo "None")
\`\`\`

## Open Ports
\`\`\`
$(cat "$OUTPUT_DIR/ports/open_ports.txt" 2>/dev/null || echo "Scan not completed")
\`\`\`

## Web Technologies
\`\`\`
$(cat "$OUTPUT_DIR/web/http_whatweb.txt" 2>/dev/null | head -5 || echo "N/A")
\`\`\`

## Files
- WHOIS: whois/whois.txt
- DNS: dns/dns_records.txt
- Subdomains: subdomains/all_subdomains.txt
- Port scans: ports/
- Web info: web/
EOF

ok "Report generated: $REPORT"
echo ""
echo -e "${BOLD}╔════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Recon Complete — $TARGET  ${NC}"
echo -e "${BOLD}╚════════════════════════════════╝${NC}"
echo -e "  Output: ${CYAN}$OUTPUT_DIR${NC}"
echo -e "  Report: ${CYAN}$REPORT${NC}"
echo -e "  Subdomains: ${GREEN}$SUBDOMAIN_COUNT${NC}"
echo ""
