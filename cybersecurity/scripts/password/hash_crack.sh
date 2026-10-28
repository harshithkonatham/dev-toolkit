#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# hash_crack.sh — Multi-Tool Hash Cracking
# Usage: bash hash_crack.sh <hash_or_file> [hash_type] [wordlist]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

INPUT="${1:?Usage: $0 <hash_or_file> [hash_type] [wordlist]}"
HASH_TYPE="${2:-auto}"
WORDLIST="${3:-}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Auto-detect wordlist
if [[ -z "$WORDLIST" ]]; then
  for wl in \
    /usr/share/wordlists/rockyou.txt \
    /opt/homebrew/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz \
    /usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt \
    ~/wordlists/rockyou.txt; do
    if [[ -f "$wl" ]]; then
      WORDLIST="$wl"
      break
    fi
  done
fi

if [[ -z "$WORDLIST" ]]; then
  echo -e "${YELLOW}[!] rockyou.txt not found. Download:${NC}"
  echo "  wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"
  echo "  mkdir -p ~/wordlists && mv rockyou.txt ~/wordlists/"

  # Create tiny fallback
  WORDLIST="/tmp/common_passwords.txt"
  cat > "$WORDLIST" << 'EOF'
password
123456
password1
admin
letmein
welcome
monkey
dragon
master
123456789
qwerty
abc123
pass
root
toor
EOF
  echo -e "${YELLOW}Using minimal fallback wordlist${NC}"
fi

# Handle single hash vs file
if [[ -f "$INPUT" ]]; then
  HASH_FILE="$INPUT"
else
  HASH_FILE="/tmp/hash_$(date +%s).txt"
  echo "$INPUT" > "$HASH_FILE"
fi

echo -e "\n${BOLD}Hash Cracking${NC}"
echo -e "  Input:    ${CYAN}$INPUT${NC}"
echo -e "  Wordlist: ${CYAN}$WORDLIST${NC}"
echo -e "  Type:     ${CYAN}$HASH_TYPE${NC}\n"

# ── Auto-detect hash type ─────────────────────────────────────────────────────
detect_hash() {
  local hash="$1"
  local len=${#hash}
  case "$len" in
    32)  echo "0"    ;;   # MD5
    40)  echo "100"  ;;   # SHA1
    56)  echo "700"  ;;   # SHA-224
    64)  echo "1400" ;;   # SHA-256
    96)  echo "10800";;   # SHA-384
    128) echo "1700" ;;   # SHA-512
    *)
      if [[ "$hash" =~ ^\$2[aby]\$ ]]; then echo "3200"  # bcrypt
      elif [[ "$hash" =~ ^\$6\$    ]]; then echo "1800"  # sha512crypt
      elif [[ "$hash" =~ ^\$5\$    ]]; then echo "7400"  # sha256crypt
      elif [[ "$hash" =~ ^\$1\$    ]]; then echo "500"   # md5crypt
      elif [[ "$hash" =~ ^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}$ ]]; then echo "3200" # MD5:salt
      else echo "0"
      fi
      ;;
  esac
}

SAMPLE_HASH=$(head -1 "$HASH_FILE")
if [[ "$HASH_TYPE" == "auto" ]]; then
  HASH_MODE=$(detect_hash "$SAMPLE_HASH")
  echo -e "${CYAN}[*]${NC} Auto-detected hash mode: $HASH_MODE"
else
  HASH_MODE="$HASH_TYPE"
fi

RESULT_FILE="/tmp/cracked_$(date +%s).txt"

# ── hashcat ───────────────────────────────────────────────────────────────────
if command -v hashcat &>/dev/null; then
  echo -e "${CYAN}[*]${NC} Running hashcat (dictionary attack)..."
  hashcat -m "$HASH_MODE" -a 0 \
    "$HASH_FILE" "$WORDLIST" \
    --outfile "$RESULT_FILE" \
    --outfile-format 2 \
    --quiet \
    --optimized-kernel-enable \
    2>/dev/null || true

  if [[ -s "$RESULT_FILE" ]]; then
    echo -e "\n${GREEN}[+] Cracked passwords:${NC}"
    cat "$RESULT_FILE"
    echo ""
    COUNT=$(wc -l < "$RESULT_FILE")
    echo -e "${GREEN}Total cracked: $COUNT${NC}"
  else
    echo -e "${YELLOW}[-] Dictionary attack failed — trying rules...${NC}"

    # Try with rules
    hashcat -m "$HASH_MODE" -a 0 \
      "$HASH_FILE" "$WORDLIST" \
      --outfile "$RESULT_FILE" \
      --outfile-format 2 \
      --rules-file /usr/share/hashcat/rules/best64.rule \
      --quiet \
      2>/dev/null || true

    if [[ -s "$RESULT_FILE" ]]; then
      echo -e "${GREEN}[+] Cracked with rules:${NC}"
      cat "$RESULT_FILE"
    else
      echo -e "${YELLOW}[-] Not cracked with wordlist + best64 rules${NC}"
      echo -e "  Try: hashcat -m $HASH_MODE -a 3 $HASH_FILE ?a?a?a?a?a?a?a?a"
    fi
  fi

# ── john ─────────────────────────────────────────────────────────────────────
elif command -v john &>/dev/null; then
  echo -e "${CYAN}[*]${NC} Running John the Ripper..."

  # Map hashcat mode to john format
  case "$HASH_MODE" in
    0)    JOHN_FORMAT="--format=raw-md5" ;;
    100)  JOHN_FORMAT="--format=raw-sha1" ;;
    1400) JOHN_FORMAT="--format=raw-sha256" ;;
    1700) JOHN_FORMAT="--format=raw-sha512" ;;
    3200) JOHN_FORMAT="--format=bcrypt" ;;
    1800) JOHN_FORMAT="--format=sha512crypt" ;;
    *)    JOHN_FORMAT="" ;;
  esac

  john "$JOHN_FORMAT" --wordlist="$WORDLIST" "$HASH_FILE" 2>/dev/null || true
  john --show "$JOHN_FORMAT" "$HASH_FILE"

else
  echo -e "${YELLOW}[!] Neither hashcat nor john found${NC}"
  echo "  Install: brew install hashcat john"
fi

# ── Hash identification helper ─────────────────────────────────────────────────
echo ""
echo "=== Hash Type Reference ==="
cat << 'EOF'
  hashcat -m 0     → MD5
  hashcat -m 100   → SHA-1
  hashcat -m 1400  → SHA-256
  hashcat -m 1700  → SHA-512
  hashcat -m 3200  → bcrypt
  hashcat -m 1800  → sha512crypt (Linux /etc/shadow)
  hashcat -m 500   → md5crypt (Linux/Cisco)
  hashcat -m 1000  → NTLM (Windows)
  hashcat -m 5600  → Net-NTLMv2 (Windows)
  hashcat -m 22000 → WPA-PBKDF2-PMKID+EAPOL (WiFi)
  hashcat -m 13100 → Kerberos TGS-REP (Kerberoasting)

  Online: https://hashes.com/en/decrypt/hash
  Online: https://crackstation.net/
EOF
