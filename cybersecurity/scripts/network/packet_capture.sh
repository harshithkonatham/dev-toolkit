#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# packet_capture.sh — Targeted Packet Capture & Analysis
# Usage: bash packet_capture.sh [interface] [filter] [duration_seconds]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

IFACE="${1:-}"
FILTER="${2:-}"
DURATION="${3:-60}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

OUTPUT_DIR="./captures_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

command -v tcpdump &>/dev/null || { echo "tcpdump required: brew install tcpdump"; exit 1; }

# Auto-detect interface
if [[ -z "$IFACE" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    IFACE=$(route get default 2>/dev/null | grep interface | awk '{print $2}' || echo "en0")
  else
    IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' || echo "eth0")
  fi
  echo -e "${YELLOW}Auto-detected interface: $IFACE${NC}"
fi

echo -e "\n${BOLD}Packet Capture${NC}"
echo -e "  Interface: ${CYAN}$IFACE${NC}"
echo -e "  Filter:    ${CYAN}${FILTER:-none (capture all)}${NC}"
echo -e "  Duration:  ${CYAN}${DURATION}s${NC}"
echo -e "  Output:    ${CYAN}$OUTPUT_DIR/${NC}\n"

PCAP="$OUTPUT_DIR/capture_${IFACE}_$(date +%H%M%S).pcap"

# ── Capture ───────────────────────────────────────────────────────────────────
echo -e "${CYAN}[*]${NC} Capturing for ${DURATION}s... (Ctrl+C to stop early)"
if [[ -n "$FILTER" ]]; then
  sudo timeout "$DURATION" tcpdump -i "$IFACE" -w "$PCAP" "$FILTER" 2>/dev/null || true
else
  sudo timeout "$DURATION" tcpdump -i "$IFACE" -w "$PCAP" 2>/dev/null || true
fi

[[ ! -f "$PCAP" ]] && { echo "Capture failed or empty"; exit 1; }
PACKET_COUNT=$(tcpdump -r "$PCAP" 2>/dev/null | wc -l || echo 0)
echo -e "${GREEN}[+]${NC} Captured $PACKET_COUNT packets → $PCAP"

# ── Analysis ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Traffic Summary ==="

# Protocol breakdown
tcpdump -r "$PCAP" -q 2>/dev/null | awk '{print $2}' | sort | uniq -c | sort -rn | head -10

echo ""
echo "=== Top Source IPs ==="
tcpdump -r "$PCAP" -n 2>/dev/null | awk '{print $3}' | \
  grep -oE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort | uniq -c | sort -rn | head -10

echo ""
echo "=== Top Destination IPs ==="
tcpdump -r "$PCAP" -n 2>/dev/null | awk '{print $5}' | \
  grep -oE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort | uniq -c | sort -rn | head -10

echo ""
echo "=== HTTP Requests ==="
tcpdump -r "$PCAP" -A 2>/dev/null | grep -E "GET |POST |PUT |DELETE |Host:" | head -20

echo ""
echo "=== DNS Queries ==="
tcpdump -r "$PCAP" -n port 53 2>/dev/null | grep -oP "A\? \K[^\s]+" | sort -u | head -20

echo ""
echo "=== Potential Credentials (plaintext) ==="
tcpdump -r "$PCAP" -A 2>/dev/null | \
  grep -iE "password|passwd|login|user|email|Authorization:" | \
  grep -v "Binary" | head -20

echo ""
echo "=== TCP SYN packets (connection attempts) ==="
tcpdump -r "$PCAP" -n "tcp[tcpflags] & tcp-syn != 0" 2>/dev/null | head -20

# ── Predefined capture profiles ───────────────────────────────────────────────
echo ""
echo "=== Useful Capture Profiles ==="
echo "  # Capture HTTP traffic:"
echo "  sudo tcpdump -i $IFACE -w http.pcap 'port 80'"
echo ""
echo "  # Capture DNS queries:"
echo "  sudo tcpdump -i $IFACE -w dns.pcap 'port 53'"
echo ""
echo "  # Capture traffic to/from specific IP:"
echo "  sudo tcpdump -i $IFACE -w target.pcap 'host 192.168.1.1'"
echo ""
echo "  # Capture and display HTTP passwords:"
echo "  sudo tcpdump -i $IFACE -A -s0 'port 80' | grep -iE 'pass|login|user'"
echo ""
echo "  # Open in Wireshark:"
echo "  wireshark $PCAP"
echo ""
echo -e "${GREEN}[+]${NC} PCAP saved: ${CYAN}$PCAP${NC}"
