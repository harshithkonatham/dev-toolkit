#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# steg_toolkit.sh — Steganography Extraction Toolkit for CTF
# Usage: bash steg_toolkit.sh <file> [password]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

FILE="${1:?Usage: $0 <file> [password]}"
PASSWORD="${2:-}"
OUTPUT_DIR="./steg_out_$(basename "$FILE" | tr '.' '_')_$(date +%Y%m%d_%H%M%S)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p "$OUTPUT_DIR"

[[ ! -f "$FILE" ]] && { echo "File not found: $FILE"; exit 1; }

FILETYPE=$(file "$FILE" | cut -d: -f2- | xargs)
echo -e "\n${BOLD}Steganography Analysis: $FILE${NC}"
echo -e "  Type: ${CYAN}$FILETYPE${NC}"
echo -e "  Size: $(du -h "$FILE" | cut -f1)"
echo -e "  Output: ${CYAN}$OUTPUT_DIR${NC}\n"

found() { echo -e "${GREEN}[FOUND]${NC} $1"; }
try()   { echo -e "${CYAN}[*]${NC} Trying: $1"; }
skip()  { echo -e "${YELLOW}[-]${NC} $1 not installed"; }

# ── strings — Find hidden text ────────────────────────────────────────────────
echo "=== strings ==="
try "Extracting printable strings"
strings "$FILE" | tee "$OUTPUT_DIR/strings.txt" | \
  grep -iE "flag|ctf|htb|thm|picoCTF|\{.*\}" | head -20 || true

strings -e l "$FILE" >> "$OUTPUT_DIR/strings.txt" 2>/dev/null || true  # 16-bit LE
strings -e b "$FILE" >> "$OUTPUT_DIR/strings.txt" 2>/dev/null || true  # 16-bit BE

echo "Found $(wc -l < "$OUTPUT_DIR/strings.txt") strings"

# ── xxd — hex dump ────────────────────────────────────────────────────────────
echo ""
echo "=== Hex Analysis ==="
xxd "$FILE" | head -20
echo ""
echo "Last 20 bytes:"
xxd "$FILE" | tail -20
xxd "$FILE" > "$OUTPUT_DIR/hexdump.txt"

# ── File signature check ──────────────────────────────────────────────────────
echo ""
echo "=== File Signature / Magic Bytes ==="
MAGIC=$(xxd "$FILE" | head -2)
echo "$MAGIC"

# Detect embedded file signatures
try "Scanning for embedded file signatures"
python3 << 'PYEOF'
import sys

SIGS = {
    b'\xff\xd8\xff': 'JPEG',
    b'\x89PNG\r\n': 'PNG',
    b'GIF8': 'GIF',
    b'PK\x03\x04': 'ZIP',
    b'PK\x05\x06': 'ZIP (empty)',
    b'%PDF': 'PDF',
    b'\x1f\x8b': 'GZIP',
    b'BZh': 'BZIP2',
    b'\xfd7zXZ': 'XZ',
    b'Rar!': 'RAR',
    b'7z\xbc\xaf': '7ZIP',
    b'IHDR': 'PNG chunk',
    b'IDAT': 'PNG chunk',
    b'iCCP': 'PNG color profile',
    b'tEXt': 'PNG text chunk',
    b'zTXt': 'PNG compressed text',
    b'\x00\x00\x00\x0cftyp': 'MP4/MOV',
    b'OggS': 'OGG',
    b'ID3': 'MP3',
    b'fLaC': 'FLAC',
    b'RIFF': 'WAV/AVI',
    b'ELF': 'ELF binary',
    b'MZ': 'Windows PE',
}

import sys
try:
    data = open(sys.argv[1], 'rb').read()
except:
    sys.exit()

found = []
for offset in range(len(data) - 8):
    chunk = data[offset:offset+8]
    for sig, name in SIGS.items():
        if chunk.startswith(sig) and offset > 0:
            found.append((offset, name, sig.hex()))

if found:
    print("Embedded file signatures found:")
    for offset, name, sig in found:
        print(f"  Offset 0x{offset:08x} ({offset}): {name} ({sig})")
else:
    print("  No embedded signatures found")
PYEOF "$FILE" 2>/dev/null || true

# ── exiftool — metadata ────────────────────────────────────────────────────────
echo ""
echo "=== EXIF Metadata ==="
if command -v exiftool &>/dev/null; then
  exiftool "$FILE" | tee "$OUTPUT_DIR/exiftool.txt"
else
  skip "exiftool (install: brew install exiftool)"
fi

# ── binwalk — embedded files ──────────────────────────────────────────────────
echo ""
echo "=== Binwalk — Embedded Files ==="
if command -v binwalk &>/dev/null; then
  try "Scanning with binwalk"
  binwalk "$FILE" | tee "$OUTPUT_DIR/binwalk_scan.txt"

  if grep -q "%" "$OUTPUT_DIR/binwalk_scan.txt" 2>/dev/null; then
    try "Extracting with binwalk"
    binwalk -e --directory="$OUTPUT_DIR/binwalk_extracted" "$FILE" 2>/dev/null || true
    found "Binwalk extracted files to: $OUTPUT_DIR/binwalk_extracted/"
    ls "$OUTPUT_DIR/binwalk_extracted/" 2>/dev/null || true
  fi
else
  skip "binwalk (install: pip install binwalk)"
fi

# ── steghide — audio/image steg ───────────────────────────────────────────────
echo ""
echo "=== Steghide ==="
if command -v steghide &>/dev/null; then
  # Try with provided password
  if [[ -n "$PASSWORD" ]]; then
    try "Steghide extract (password: $PASSWORD)"
    steghide extract -sf "$FILE" -p "$PASSWORD" -xf "$OUTPUT_DIR/steghide_extracted" 2>/dev/null && \
      found "Steghide extracted: $OUTPUT_DIR/steghide_extracted" || \
      echo "  Wrong password or no hidden data"
  fi

  # Try common passwords
  COMMON_PASSWORDS=("" "password" "secret" "steghide" "ctf" "flag" "hidden" "steg" "admin" "12345")
  echo "  Trying common passwords..."
  for pass in "${COMMON_PASSWORDS[@]}"; do
    if steghide extract -sf "$FILE" -p "$pass" -xf "$OUTPUT_DIR/steghide_${pass:-nopass}.txt" 2>/dev/null; then
      found "Steghide extract succeeded! Password: '${pass:-empty}'"
      break
    fi
  done
else
  skip "steghide (install: brew install steghide)"
fi

# ── zsteg — PNG LSB analysis ──────────────────────────────────────────────────
echo ""
echo "=== zsteg (PNG/BMP) ==="
if [[ "$FILE" =~ \.(png|bmp)$ ]] || echo "$FILETYPE" | grep -qi "png\|bitmap"; then
  if command -v zsteg &>/dev/null; then
    try "Running zsteg"
    zsteg "$FILE" | tee "$OUTPUT_DIR/zsteg.txt"
    zsteg -a "$FILE" | tee -a "$OUTPUT_DIR/zsteg.txt" 2>/dev/null || true
  else
    skip "zsteg (install: gem install zsteg)"
  fi
fi

# ── stegseek — fast steghide cracking ────────────────────────────────────────
echo ""
echo "=== StegSeek (fast steghide brute force) ==="
if command -v stegseek &>/dev/null; then
  ROCKYOU=""
  for wl in /usr/share/wordlists/rockyou.txt /opt/homebrew/share/wordlists/rockyou.txt; do
    [[ -f "$wl" ]] && { ROCKYOU="$wl"; break; }
  done

  if [[ -n "$ROCKYOU" ]]; then
    try "StegSeek with rockyou.txt"
    stegseek "$FILE" "$ROCKYOU" "$OUTPUT_DIR/stegseek_out.txt" 2>/dev/null && \
      found "StegSeek cracked it!" || echo "  StegSeek: not found"
  fi
else
  skip "stegseek (install: https://github.com/RickdeJager/stegseek)"
fi

# ── Audio steg (WAV/MP3) ──────────────────────────────────────────────────────
if echo "$FILETYPE" | grep -qi "wav\|audio\|mpeg"; then
  echo ""
  echo "=== Audio Steganography ==="

  # Least significant bit
  try "Checking audio LSB (Python)"
  python3 << PYEOF 2>/dev/null || true
import wave, struct

try:
    with wave.open("$FILE", "rb") as f:
        frames = f.readframes(f.getnframes())
        samples = struct.unpack(f"<{len(frames)//2}h", frames)
        bits = [s & 1 for s in samples]
        chars = []
        for i in range(0, len(bits) - 8, 8):
            byte = int("".join(str(b) for b in bits[i:i+8]), 2)
            if byte == 0:
                break
            chars.append(chr(byte))
        result = "".join(chars)
        if any(c.isprintable() for c in result[:10]):
            print(f"  Possible LSB hidden text: {result[:100]}")
except Exception as e:
    pass
PYEOF

  # Check for spectogram text (hint)
  echo -e "  ${YELLOW}[Tip]${NC} For spectogram analysis, open in Sonic Visualizer or Audacity"
  echo -e "  ${YELLOW}[Tip]${NC} Spectogram may reveal text/images at certain frequencies"
fi

# ── LSB extraction (images) ───────────────────────────────────────────────────
if echo "$FILETYPE" | grep -qi "image\|png\|jpeg\|bitmap"; then
  echo ""
  echo "=== LSB Image Analysis ==="
  python3 << PYEOF 2>/dev/null || true
try:
    from PIL import Image
    img = Image.open("$FILE")
    pixels = list(img.getdata())

    # Extract LSB from each channel
    bits = []
    for pixel in pixels[:10000]:  # check first 10k pixels
        if isinstance(pixel, int):
            bits.append(pixel & 1)
        else:
            for channel in pixel[:3]:  # RGB
                bits.append(channel & 1)

    # Decode bits to characters
    chars = []
    for i in range(0, len(bits) - 8, 8):
        byte = int("".join(str(b) for b in bits[i:i+8]), 2)
        if byte == 0:
            break
        if 32 <= byte <= 126:
            chars.append(chr(byte))

    result = "".join(chars)
    if len(result) > 4 and result.isprintable():
        print(f"  Possible LSB hidden text: {result[:200]}")
    else:
        print("  No obvious LSB message found")
except ImportError:
    print("  pip install Pillow for LSB analysis")
except Exception as e:
    print(f"  Error: {e}")
PYEOF
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== Analysis Complete ===${NC}"
echo -e "  Output: ${CYAN}$OUTPUT_DIR/${NC}"
ls -la "$OUTPUT_DIR/"
echo ""
echo "Manual checks:"
echo "  pngcheck -v $FILE              — validate PNG chunks"
echo "  identify -verbose $FILE        — ImageMagick metadata"
echo "  audacity $FILE                 — inspect spectogram"
echo "  https://gchq.github.io/CyberChef — online analysis"
