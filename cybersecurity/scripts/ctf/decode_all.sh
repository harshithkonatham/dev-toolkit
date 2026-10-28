#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# decode_all.sh — Multi-Format CTF Decoder
# Usage: bash decode_all.sh <input_string_or_file>
# ─────────────────────────────────────────────────────────────────────────────

INPUT="${1:?Usage: $0 <string_or_file>}"

# If it's a file, read it
if [[ -f "$INPUT" ]]; then
  DATA=$(cat "$INPUT")
else
  DATA="$INPUT"
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

try() {
  local label="$1"
  local result="$2"
  if [[ -n "$result" && "$result" != "$DATA" && ${#result} -gt 0 ]]; then
    echo -e "${GREEN}[+] $label:${NC}"
    echo "    $result"
  fi
}

echo -e "\n${BOLD}Multi-Format Decoder${NC}"
echo -e "  Input: ${CYAN}$DATA${NC}\n"

# ── Base Encodings ────────────────────────────────────────────────────────────
echo "=== Base Encodings ==="

try "Base64" "$(echo "$DATA" | base64 -d 2>/dev/null | strings)"
try "Base64 URL-safe" "$(echo "$DATA" | tr '_-' '/+' | base64 -d 2>/dev/null | strings)"
try "Base32" "$(echo "$DATA" | base32 -d 2>/dev/null | strings)"
try "Base16/Hex" "$(echo "$DATA" | xxd -r -p 2>/dev/null | strings)"
try "Base85" "$(python3 -c "import base64, sys; print(base64.b85decode('$DATA').decode())" 2>/dev/null || true)"
try "Base58" "$(python3 -c "
import sys
alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
s = '$DATA'
n = 0
for c in s:
    if c in alphabet:
        n = n * 58 + alphabet.index(c)
result = n.to_bytes((n.bit_length() + 7) // 8, 'big').decode('utf-8', errors='replace')
print(result)
" 2>/dev/null || true)"

# ── Classic Ciphers ───────────────────────────────────────────────────────────
echo ""
echo "=== Classical Ciphers ==="

# ROT13
try "ROT13" "$(echo "$DATA" | tr 'A-Za-z' 'N-ZA-Mn-za-m')"

# All ROT values
echo -e "${YELLOW}ROT brute force:${NC}"
for i in $(seq 1 25); do
  result=$(echo "$DATA" | tr 'A-Za-z' "$(python3 -c "
import string
shift=$i
u = string.ascii_uppercase
l = string.ascii_lowercase
print(u[shift:] + u[:shift] + l[shift:] + l[:shift])
")")
  echo "  ROT$i: $result"
done

# Caesar brute force
echo ""

# Atbash
try "Atbash" "$(echo "$DATA" | tr 'A-Za-z' 'ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkjihgfedcba')"

# ── URL / HTML Encoding ───────────────────────────────────────────────────────
echo ""
echo "=== URL & HTML Encoding ==="

try "URL decode" "$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$DATA'))" 2>/dev/null)"
try "URL decode (plus)" "$(python3 -c "import urllib.parse; print(urllib.parse.unquote_plus('$DATA'))" 2>/dev/null)"
try "HTML entities" "$(python3 -c "import html; print(html.unescape('$DATA'))" 2>/dev/null)"
try "Double URL decode" "$(python3 -c "import urllib.parse; print(urllib.parse.unquote(urllib.parse.unquote('$DATA')))" 2>/dev/null)"

# ── Binary / Octal ────────────────────────────────────────────────────────────
echo ""
echo "=== Binary & Octal ==="

try "Binary" "$(python3 -c "
data = '$DATA'.replace(' ', '')
try:
    result = ''.join(chr(int(data[i:i+8], 2)) for i in range(0, len(data), 8))
    print(result)
except: pass
" 2>/dev/null)"

try "Octal" "$(python3 -c "
import re
nums = re.findall(r'[0-7]+', '$DATA')
try:
    result = ''.join(chr(int(n, 8)) for n in nums if int(n,8) < 256)
    print(result)
except: pass
" 2>/dev/null)"

# ── Hashes (identification) ───────────────────────────────────────────────────
echo ""
echo "=== Hash Identification ==="
LENGTH=${#DATA}
case $LENGTH in
  32)  echo -e "  ${CYAN}Possible: MD5, MD4, NTLM${NC}" ;;
  40)  echo -e "  ${CYAN}Possible: SHA-1, MySQL5${NC}" ;;
  56)  echo -e "  ${CYAN}Possible: SHA-224${NC}" ;;
  64)  echo -e "  ${CYAN}Possible: SHA-256, Blake2${NC}" ;;
  96)  echo -e "  ${CYAN}Possible: SHA-384${NC}" ;;
  128) echo -e "  ${CYAN}Possible: SHA-512, Whirlpool${NC}" ;;
  60)  echo -e "  ${CYAN}Possible: bcrypt (\$2a\$...)${NC}" ;;
  *)
    if [[ "$DATA" =~ ^\$6\$ ]]; then echo "  Possible: sha512crypt"
    elif [[ "$DATA" =~ ^\$5\$ ]]; then echo "  Possible: sha256crypt"
    elif [[ "$DATA" =~ ^\$2[aby]\$ ]]; then echo "  Possible: bcrypt"
    elif [[ "$DATA" =~ ^\$1\$ ]]; then echo "  Possible: MD5crypt"
    else echo "  Hash length $LENGTH — unknown type"
    fi
    ;;
esac

# ── JWT ───────────────────────────────────────────────────────────────────────
echo ""
echo "=== JWT Decode ==="
if echo "$DATA" | grep -qE "^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$"; then
  HEADER=$(echo "$DATA" | cut -d. -f1 | tr '_-' '/+' | \
    awk '{ pad = (4 - length($0) % 4) % 4; for(i=0;i<pad;i++) $0 = $0 "="; print }' | \
    base64 -d 2>/dev/null | python3 -m json.tool 2>/dev/null)
  PAYLOAD=$(echo "$DATA" | cut -d. -f2 | tr '_-' '/+' | \
    awk '{ pad = (4 - length($0) % 4) % 4; for(i=0;i<pad;i++) $0 = $0 "="; print }' | \
    base64 -d 2>/dev/null | python3 -m json.tool 2>/dev/null)
  echo -e "${GREEN}JWT Detected!${NC}"
  echo "  Header:  $HEADER"
  echo "  Payload: $PAYLOAD"
  echo -e "  ${YELLOW}Note: signature not verified${NC}"
fi

# ── Frequency Analysis ────────────────────────────────────────────────────────
echo ""
echo "=== Character Frequency (top 10) ==="
python3 -c "
from collections import Counter
text = '$DATA'
alpha = [c.lower() for c in text if c.isalpha()]
if alpha:
    for char, count in Counter(alpha).most_common(10):
        bar = '#' * count
        print(f'  {char}: {bar} ({count})')
" 2>/dev/null || true

# ── CyberChef reminder ────────────────────────────────────────────────────────
echo ""
echo -e "=== Online Tools ==="
echo -e "  ${CYAN}https://gchq.github.io/CyberChef/${NC}"
echo -e "  ${CYAN}https://www.dcode.fr/cipher-identifier${NC}"
echo -e "  ${CYAN}https://www.rapidtables.com/convert/number/${NC}"
