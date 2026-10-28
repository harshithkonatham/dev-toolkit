#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# arp_scan.sh — LAN Host Discovery & Network Mapping
# Usage: bash arp_scan.sh [subnet] (e.g. 192.168.1.0/24)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Auto-detect subnet if not provided
if [[ -z "${1:-}" ]]; then
  # macOS
  if command -v ifconfig &>/dev/null; then
    SUBNET=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | \
      awk '{print $2}' | sed 's/\.[0-9]*$/.0\/24/')
  # Linux
  elif command -v ip &>/dev/null; then
    SUBNET=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | \
      grep -v "127.0.0.1" | head -1 | sed 's/\.[0-9]*\//\.0\//')
  fi
  SUBNET="${SUBNET:-192.168.1.0/24}"
  echo -e "${YELLOW}Auto-detected subnet: $SUBNET${NC}"
else
  SUBNET="$1"
fi

echo -e "\n${BOLD}LAN Host Discovery${NC}"
echo -e "  Subnet: ${CYAN}$SUBNET${NC}"
echo -e "  Date:   $(date)\n"

OUTPUT_FILE="./arp_scan_$(date +%Y%m%d_%H%M%S).txt"

# ── Method 1: arp-scan ────────────────────────────────────────────────────────
if command -v arp-scan &>/dev/null; then
  echo -e "${CYAN}[*]${NC} Running arp-scan..."
  sudo arp-scan --localnet 2>/dev/null | tee "$OUTPUT_FILE"

# ── Method 2: nmap ARP ping ───────────────────────────────────────────────────
elif command -v nmap &>/dev/null; then
  echo -e "${CYAN}[*]${NC} Running nmap ARP ping sweep..."
  sudo nmap -sn -PR "$SUBNET" 2>/dev/null | tee "$OUTPUT_FILE"

  # Also try nmap with host discovery
  echo ""
  echo -e "${CYAN}[*]${NC} Running nmap ping sweep (no ARP)..."
  nmap -sn "$SUBNET" 2>/dev/null | grep -E "Nmap scan report|MAC Address" | tee -a "$OUTPUT_FILE"

# ── Method 3: ping sweep ──────────────────────────────────────────────────────
else
  echo -e "${CYAN}[*]${NC} Running manual ping sweep..."
  BASE=$(echo "$SUBNET" | cut -d. -f1-3)
  LIVE_HOSTS=()

  for i in $(seq 1 254); do
    (
      if ping -c1 -W1 "${BASE}.${i}" &>/dev/null 2>&1; then
        MAC=$(arp -n "${BASE}.${i}" 2>/dev/null | grep -oE "[0-9a-f:]{17}" | head -1 || echo "unknown")
        HOSTNAME=$(dig +short -x "${BASE}.${i}" 2>/dev/null | sed 's/\.$//' || echo "")
        printf "${GREEN}[+]${NC} %-15s  MAC: %-20s  Host: %s\n" "${BASE}.${i}" "$MAC" "$HOSTNAME"
        echo "${BASE}.${i}  $MAC  $HOSTNAME" >> "$OUTPUT_FILE"
      fi
    ) &
  done
  wait

  echo ""
  echo -e "${BOLD}Scan complete. Results saved: ${CYAN}$OUTPUT_FILE${NC}"
fi

# ── ARP Cache ────────────────────────────────────────────────────────────────
echo ""
echo "=== Current ARP Cache ==="
if command -v arp &>/dev/null; then
  arp -a 2>/dev/null | grep -v "incomplete" | sort -t. -k4 -n | head -30
fi

# ── MAC Vendor Lookup ─────────────────────────────────────────────────────────
echo ""
echo "=== MAC Vendor Lookup (from ARP cache) ==="
arp -a 2>/dev/null | grep -oE "[0-9a-f:]{17}" | while read -r mac; do
  # OUI = first 3 octets
  OUI=$(echo "$mac" | tr ':' '-' | cut -d- -f1-3 | tr '[:lower:]' '[:upper:]')
  # Quick offline lookup of common vendors
  case "${OUI}" in
    00-50-56|00-0C-29|00-05-69) VENDOR="VMware" ;;
    08-00-27)                    VENDOR="VirtualBox" ;;
    AC-BC-32|A4-C3-F0|78-4F-43) VENDOR="Apple" ;;
    00-1A-2B|F8-1A-67|00-26-B9) VENDOR="Dell" ;;
    3C-52-82|9C-B6-D0|F4-CE-46) VENDOR="Raspberry Pi" ;;
    DC-A6-32)                    VENDOR="Raspberry Pi" ;;
    B8-27-EB)                    VENDOR="Raspberry Pi" ;;
    *)                           VENDOR="Unknown" ;;
  esac
  echo "  $mac → $VENDOR"
done | sort -u

echo ""
echo -e "${GREEN}[+]${NC} Results saved: ${CYAN}$OUTPUT_FILE${NC}"
