#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# dir_fuzz.sh — Directory & File Fuzzing with ffuf/gobuster
# Usage: bash dir_fuzz.sh <url> [wordlist] [extensions]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

URL="${1:?Usage: $0 <url> [wordlist] [extensions]}"
WORDLIST="${2:-}"
EXTENSIONS="${3:-.php,.html,.txt,.bak,.json,.xml,.env,.log,.sql,.zip}"
OUTPUT_DIR="./dirfuzz_$(echo "$URL" | sed 's|https\?://||;s|/.*||')_$(date +%Y%m%d_%H%M%S)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p "$OUTPUT_DIR"

# Auto-detect wordlist
if [[ -z "$WORDLIST" ]]; then
  for wl in \
    /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt \
    /usr/share/seclists/Discovery/Web-Content/common.txt \
    /opt/homebrew/share/seclists/Discovery/Web-Content/common.txt \
    /usr/share/wordlists/dirb/big.txt \
    /usr/share/wordlists/dirb/common.txt; do
    if [[ -f "$wl" ]]; then
      WORDLIST="$wl"
      break
    fi
  done
fi

if [[ -z "$WORDLIST" || ! -f "$WORDLIST" ]]; then
  echo -e "${YELLOW}No wordlist found. Install SecLists:${NC}"
  echo "  macOS: brew install seclists"
  echo "  Linux: sudo apt install seclists"
  echo "  Manual: git clone https://github.com/danielmiessler/SecLists.git"

  # Create minimal fallback wordlist
  WORDLIST="$OUTPUT_DIR/mini_wordlist.txt"
  cat > "$WORDLIST" << 'EOF'
admin
login
dashboard
api
v1
v2
swagger
graphql
uploads
backup
config
.env
.git
robots.txt
sitemap.xml
phpinfo.php
info.php
test
dev
staging
EOF
  echo -e "${YELLOW}Using minimal built-in wordlist${NC}"
fi

echo -e "\n${BOLD}Directory Fuzzing${NC}"
echo -e "  Target: ${CYAN}$URL${NC}"
echo -e "  Wordlist: ${CYAN}$WORDLIST${NC} ($(wc -l < "$WORDLIST") entries)"
echo -e "  Extensions: ${CYAN}$EXTENSIONS${NC}"

# ── ffuf (preferred) ──────────────────────────────────────────────────────────
if command -v ffuf &>/dev/null; then
  echo -e "\n${CYAN}[*]${NC} Running ffuf..."

  # Directory scan
  ffuf \
    -u "${URL}/FUZZ" \
    -w "$WORDLIST" \
    -e "$EXTENSIONS" \
    -fc 404 \
    -mc 200,201,204,301,302,307,401,403 \
    -t 50 \
    -timeout 10 \
    -of json \
    -o "$OUTPUT_DIR/ffuf_dirs.json" \
    -recursion \
    -recursion-depth 2 \
    2>/dev/null || true

  # Extract and display results
  if command -v jq &>/dev/null && [[ -f "$OUTPUT_DIR/ffuf_dirs.json" ]]; then
    echo -e "\n${GREEN}[+]${NC} Results:"
    jq -r '.results[] | "  [\(.status)] \(.url) (\(.length) bytes)"' \
      "$OUTPUT_DIR/ffuf_dirs.json" 2>/dev/null | sort -t'[' -k2 -n || true

    COUNT=$(jq '.results | length' "$OUTPUT_DIR/ffuf_dirs.json" 2>/dev/null || echo 0)
    echo -e "\n${GREEN}Total: $COUNT findings${NC}"
  fi

  # Parameter fuzzing (if target has query params)
  if echo "$URL" | grep -q "?"; then
    PARAM=$(echo "$URL" | grep -oP '\?\K[^=]+')
    echo -e "\n${CYAN}[*]${NC} Parameter fuzzing on: $PARAM"
    ffuf \
      -u "${URL//=$PARAM*/=FUZZ}" \
      -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt \
      -fc 404 \
      -t 30 \
      2>/dev/null | head -20 || true
  fi

# ── gobuster fallback ─────────────────────────────────────────────────────────
elif command -v gobuster &>/dev/null; then
  echo -e "\n${CYAN}[*]${NC} Running gobuster..."

  gobuster dir \
    -u "$URL" \
    -w "$WORDLIST" \
    -x "${EXTENSIONS//./}" \
    -t 50 \
    --timeout 10s \
    --no-error \
    -o "$OUTPUT_DIR/gobuster.txt" \
    2>/dev/null || true

  echo -e "\n${GREEN}[+]${NC} Results:"
  grep -v "^Error" "$OUTPUT_DIR/gobuster.txt" 2>/dev/null | head -50 || true

else
  echo -e "${YELLOW}Neither ffuf nor gobuster found. Install:${NC}"
  echo "  ffuf:     go install github.com/ffuf/ffuf/v2@latest"
  echo "  gobuster: go install github.com/OJ/gobuster/v3@latest"
  echo "  or brew:  brew install ffuf gobuster"
fi

echo -e "\n${BOLD}Output: ${CYAN}$OUTPUT_DIR/${NC}"
ls -la "$OUTPUT_DIR/"
