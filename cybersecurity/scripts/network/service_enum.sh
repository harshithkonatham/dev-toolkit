#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# service_enum.sh — Service Enumeration & Banner Grabbing
# Usage: bash service_enum.sh <host> [ports]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HOST="${1:?Usage: $0 <host> [ports]}"
PORTS="${2:-21,22,23,25,53,80,110,143,443,445,3306,3389,5432,6379,8080,8443,27017}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
RED='\033[0;31m'; NC='\033[0m'

OUTPUT_DIR="./enum_${HOST}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo -e "\n${BOLD}Service Enumeration: $HOST${NC}"
echo -e "  Ports: $PORTS\n"

# ── Banner grabbing with nmap ─────────────────────────────────────────────────
if command -v nmap &>/dev/null; then
  echo -e "${CYAN}[*]${NC} Nmap service + version detection..."
  nmap -p "$PORTS" -sV -sC --open "$HOST" \
    -oA "$OUTPUT_DIR/nmap_services" 2>/dev/null
  cat "$OUTPUT_DIR/nmap_services.nmap"
fi

# ── Service-specific enumeration ──────────────────────────────────────────────
IFS=',' read -ra PORT_LIST <<< "$PORTS"

for PORT in "${PORT_LIST[@]}"; do
  PORT="${PORT// /}"
  OPEN=$(nc -z -w3 "$HOST" "$PORT" 2>/dev/null && echo "open" || echo "closed")
  [[ "$OPEN" != "open" ]] && continue

  echo ""
  echo -e "${GREEN}[+] Port $PORT is open${NC}"

  case "$PORT" in
    21) # FTP
      echo "=== FTP Enumeration ==="
      echo -e "${CYAN}[*]${NC} Testing anonymous FTP..."
      {
        echo "user anonymous"
        echo "pass test@test.com"
        echo "ls"
        echo "quit"
      } | timeout 10 nc "$HOST" 21 2>/dev/null | head -30 > "$OUTPUT_DIR/ftp_enum.txt"
      cat "$OUTPUT_DIR/ftp_enum.txt"

      if grep -q "230" "$OUTPUT_DIR/ftp_enum.txt" 2>/dev/null; then
        echo -e "${RED}[!] Anonymous FTP LOGIN SUCCESSFUL${NC}"
      fi
      ;;

    22) # SSH
      echo "=== SSH Enumeration ==="
      SSH_BANNER=$(echo | timeout 5 nc "$HOST" 22 2>/dev/null | head -3)
      echo "  Banner: $SSH_BANNER"
      echo "$SSH_BANNER" > "$OUTPUT_DIR/ssh_banner.txt"

      if command -v nmap &>/dev/null; then
        nmap -p 22 --script=ssh-auth-methods,ssh-hostkey,ssh2-enum-algos \
          "$HOST" 2>/dev/null | tee -a "$OUTPUT_DIR/ssh_enum.txt"
      fi
      ;;

    25|587|465) # SMTP
      echo "=== SMTP Enumeration ==="
      {
        echo "EHLO test.com"
        echo "VRFY root"
        echo "VRFY admin"
        echo "EXPN users"
        echo "QUIT"
      } | timeout 10 nc "$HOST" "$PORT" 2>/dev/null > "$OUTPUT_DIR/smtp_enum.txt"
      cat "$OUTPUT_DIR/smtp_enum.txt"
      ;;

    53) # DNS
      echo "=== DNS Enumeration ==="
      DOMAIN=$(dig -x "$HOST" +short 2>/dev/null | sed 's/\.$//' || echo "$HOST")
      echo "  PTR: $DOMAIN"
      dig "@$HOST" version.bind chaos txt 2>/dev/null | head -5
      dig "@$HOST" "$DOMAIN" ANY 2>/dev/null | head -20 > "$OUTPUT_DIR/dns_enum.txt"
      cat "$OUTPUT_DIR/dns_enum.txt"
      ;;

    80|8080|8000) # HTTP
      echo "=== HTTP Enumeration ==="
      curl -sI --max-time 10 "http://${HOST}:${PORT}/" 2>/dev/null \
        > "$OUTPUT_DIR/http_${PORT}_headers.txt"
      cat "$OUTPUT_DIR/http_${PORT}_headers.txt"
      TITLE=$(curl -s --max-time 10 "http://${HOST}:${PORT}/" 2>/dev/null \
        | grep -i "<title" | head -1 | sed 's/<[^>]*>//g' | xargs)
      [[ -n "$TITLE" ]] && echo "  Page Title: $TITLE"
      ;;

    443|8443) # HTTPS
      echo "=== HTTPS Enumeration ==="
      curl -skI --max-time 10 "https://${HOST}:${PORT}/" 2>/dev/null \
        > "$OUTPUT_DIR/https_${PORT}_headers.txt"
      cat "$OUTPUT_DIR/https_${PORT}_headers.txt"
      echo | timeout 10 openssl s_client -connect "${HOST}:${PORT}" \
        -servername "$HOST" 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null \
        | tee -a "$OUTPUT_DIR/ssl_info.txt" || true
      ;;

    445) # SMB
      echo "=== SMB Enumeration ==="
      if command -v nmap &>/dev/null; then
        nmap -p 445 --script=smb-os-discovery,smb-security-mode,\
smb-enum-shares,smb2-security-mode,smb-vuln-ms17-010 \
          "$HOST" 2>/dev/null | tee "$OUTPUT_DIR/smb_enum.txt"
        if grep -q "VULNERABLE" "$OUTPUT_DIR/smb_enum.txt" 2>/dev/null; then
          echo -e "${RED}[!] SMB VULNERABILITY DETECTED — Check $OUTPUT_DIR/smb_enum.txt${NC}"
        fi
      fi
      ;;

    3306) # MySQL
      echo "=== MySQL Enumeration ==="
      echo | timeout 5 nc "$HOST" 3306 2>/dev/null | strings | head -5 \
        > "$OUTPUT_DIR/mysql_banner.txt" || true
      cat "$OUTPUT_DIR/mysql_banner.txt"
      if command -v nmap &>/dev/null; then
        nmap -p 3306 --script=mysql-info,mysql-empty-password,mysql-databases \
          "$HOST" 2>/dev/null | tee -a "$OUTPUT_DIR/mysql_enum.txt"
      fi
      ;;

    6379) # Redis
      echo "=== Redis Enumeration ==="
      {
        echo "INFO server"
        echo "QUIT"
      } | timeout 5 nc "$HOST" 6379 2>/dev/null | head -20 > "$OUTPUT_DIR/redis_enum.txt"
      cat "$OUTPUT_DIR/redis_enum.txt"
      if grep -q "redis_version" "$OUTPUT_DIR/redis_enum.txt" 2>/dev/null; then
        echo -e "${RED}[!] Redis is UNAUTHENTICATED — accessible without password${NC}"
      fi
      ;;

    27017) # MongoDB
      echo "=== MongoDB Enumeration ==="
      if command -v nmap &>/dev/null; then
        nmap -p 27017 --script=mongodb-info,mongodb-databases \
          "$HOST" 2>/dev/null | tee "$OUTPUT_DIR/mongodb_enum.txt"
      fi
      ;;

    5432) # PostgreSQL
      echo "=== PostgreSQL Enumeration ==="
      if command -v nmap &>/dev/null; then
        nmap -p 5432 --script=pgsql-brute \
          --script-args="userdb=/dev/stdin,passdb=/dev/stdin" \
          "$HOST" 2>/dev/null | head -10 || true
      fi
      ;;

    3389) # RDP
      echo "=== RDP Enumeration ==="
      if command -v nmap &>/dev/null; then
        nmap -p 3389 --script=rdp-enum-encryption,rdp-vuln-ms12-020 \
          "$HOST" 2>/dev/null | tee "$OUTPUT_DIR/rdp_enum.txt"
      fi
      ;;
  esac
done

echo ""
echo -e "${GREEN}[+]${NC} Enumeration complete"
echo -e "    Output: ${CYAN}$OUTPUT_DIR/${NC}"
ls -la "$OUTPUT_DIR/"
