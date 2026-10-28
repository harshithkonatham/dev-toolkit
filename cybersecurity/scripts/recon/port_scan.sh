#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# port_scan.sh — Nmap Port Scanning with Profiles
# Usage: bash port_scan.sh <target> [profile] [output_dir]
# Profiles: quick | full | udp | vuln | stealth | web
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

TARGET="${1:?Usage: $0 <target> [profile] [output_dir]}"
PROFILE="${2:-quick}"
OUTPUT_DIR="${3:-.}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

command -v nmap &>/dev/null || { echo "nmap not installed. Run: brew install nmap"; exit 1; }

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_PREFIX="$OUTPUT_DIR/scan_${TARGET//\//_}_${PROFILE}_${TIMESTAMP}"

echo -e "\n${CYAN}${BOLD}[*] Scanning: $TARGET | Profile: $PROFILE${NC}"
echo -e "${YELLOW}[!] Authorized use only${NC}\n"

case "$PROFILE" in
  quick)
    echo "Profile: Top 1000 ports, service detection, default scripts"
    nmap -sV -sC -T4 --open \
         -oA "$OUT_PREFIX" \
         "$TARGET"
    ;;

  full)
    echo "Profile: All 65535 ports, then service detection on open ports"
    # Phase 1: discover open ports fast
    nmap -p- -T4 --open --min-rate=1000 \
         -oG "$OUT_PREFIX_phase1.gnmap" \
         "$TARGET" 2>/dev/null

    # Extract open ports
    OPEN_PORTS=$(grep "Ports:" "${OUT_PREFIX_phase1.gnmap}" 2>/dev/null | \
      grep -oP '\d+/open' | cut -d/ -f1 | tr '\n' ',' | sed 's/,$//' || echo "1-65535")

    echo "Open ports found: $OPEN_PORTS"

    # Phase 2: detailed scan on open ports
    nmap -p "$OPEN_PORTS" -sV -sC -O -T4 \
         -oA "$OUT_PREFIX" \
         "$TARGET"
    ;;

  udp)
    echo "Profile: Top 200 UDP ports"
    sudo nmap -sU --top-ports 200 -T4 \
         --open -oA "$OUT_PREFIX" \
         "$TARGET"
    ;;

  vuln)
    echo "Profile: Vulnerability scan with NSE scripts"
    nmap -sV -sC -T4 --open \
         --script=vuln,safe,discovery \
         -oA "$OUT_PREFIX" \
         "$TARGET"
    ;;

  stealth)
    echo "Profile: SYN stealth scan (requires root)"
    sudo nmap -sS -p- -T2 --open \
         --randomize-hosts \
         -D RND:5 \
         -oA "$OUT_PREFIX" \
         "$TARGET"
    ;;

  web)
    echo "Profile: Web ports with HTTP scripts"
    nmap -p 80,443,8080,8443,8000,8888,3000,4443,9443 \
         -sV --open \
         --script=http-title,http-headers,http-methods,http-auth-finder,\
http-robots.txt,http-sitemap-generator,ssl-cert,ssl-enum-ciphers \
         -oA "$OUT_PREFIX" \
         "$TARGET"
    ;;

  smb)
    echo "Profile: SMB/Windows enumeration"
    nmap -p 139,445 -sV --open \
         --script=smb-vuln-ms17-010,smb-security-mode,\
smb-enum-shares,smb-enum-users,smb-os-discovery \
         -oA "$OUT_PREFIX" \
         "$TARGET"
    ;;

  *)
    echo "Unknown profile: $PROFILE"
    echo "Available: quick | full | udp | vuln | stealth | web | smb"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}[+] Scan complete${NC}"
echo -e "    Output: ${CYAN}${OUT_PREFIX}.nmap${NC}"
echo ""
echo "=== Open Ports Summary ==="
grep "open" "${OUT_PREFIX}.nmap" 2>/dev/null | grep -v "^#" || echo "No output file found"
