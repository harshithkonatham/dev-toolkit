#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# wordlist_gen.sh — Custom Wordlist Generator
# Usage: bash wordlist_gen.sh [mode] [args...]
# Modes: cewl | crunch | profile | mutate | combine
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

MODE="${1:-help}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

case "$MODE" in

# ── CeWL — Generate from website ─────────────────────────────────────────────
  cewl)
    URL="${2:?Usage: $0 cewl <url> [min_length] [output_file]}"
    MIN_LEN="${3:-6}"
    OUTPUT="${4:-cewl_wordlist.txt}"

    if command -v cewl &>/dev/null; then
      echo -e "${CYAN}[*]${NC} Crawling $URL for words..."
      cewl "$URL" \
        -m "$MIN_LEN" \
        -d 3 \
        --with-numbers \
        -w "$OUTPUT" 2>/dev/null
      echo -e "${GREEN}[+]${NC} Words extracted: $(wc -l < "$OUTPUT")"
      echo -e "    Output: ${CYAN}$OUTPUT${NC}"
    else
      echo "cewl not installed: sudo apt install cewl"
    fi
    ;;

# ── Crunch — Generate by pattern ─────────────────────────────────────────────
  crunch)
    MIN="${2:-6}"
    MAX="${3:-8}"
    CHARSET="${4:-abcdefghijklmnopqrstuvwxyz0123456789}"
    OUTPUT="${5:-crunch_wordlist.txt}"

    if command -v crunch &>/dev/null; then
      echo -e "${CYAN}[*]${NC} Generating ${MIN}-${MAX} char wordlist..."
      crunch "$MIN" "$MAX" "$CHARSET" -o "$OUTPUT"
      echo -e "${GREEN}[+]${NC} Generated: $(wc -l < "$OUTPUT") words"
    else
      echo "crunch not installed: sudo apt install crunch"
      echo ""
      echo "Alternative — use Python:"
      python3 << PYEOF
import itertools, string
chars = "${CHARSET}"
min_len = ${MIN}
max_len = ${MAX}
count = 0
with open("${OUTPUT}", "w") as f:
    for length in range(min_len, max_len + 1):
        for combo in itertools.product(chars, repeat=length):
            f.write("".join(combo) + "\n")
            count += 1
            if count > 100000:  # safety limit
                print(f"Safety limit hit: {count} words")
                break
        else:
            continue
        break
print(f"Generated {count} words → ${OUTPUT}")
PYEOF
    fi
    ;;

# ── Profile — Generate from personal info ─────────────────────────────────────
  profile)
    OUTPUT="${2:-profile_wordlist.txt}"

    echo -e "${BOLD}Personal Info Password Generator${NC}"
    echo "(Enter details to generate target-specific wordlist)"
    echo ""

    read -rp "First name: " FNAME
    read -rp "Last name: " LNAME
    read -rp "Nickname: " NICK
    read -rp "Birth year (e.g. 1990): " BYEAR
    read -rp "Birth date DDMM (e.g. 1503): " BDATE
    read -rp "Company/Organization: " COMPANY
    read -rp "Pet name: " PET
    read -rp "City: " CITY
    read -rp "Favorite number: " FNUM
    read -rp "Favorite word/phrase: " FWORD

    {
      # Base words
      for word in "$FNAME" "$LNAME" "$NICK" "$COMPANY" "$PET" "$CITY" "$FWORD"; do
        [[ -z "$word" ]] && continue
        echo "$word"
        echo "${word,,}"               # lowercase
        echo "${word^^}"               # UPPERCASE
        echo "${word^}"                # Capitalized
        echo "${word}${BYEAR}"
        echo "${word}${BDATE}"
        echo "${word}${FNUM}"
        echo "${word}123"
        echo "${word}123!"
        echo "${word}1234"
        echo "${word}@${BYEAR}"
        echo "${word}!"
        echo "${word}#1"
        echo "${word,,}${BYEAR}"
        echo "${word^}${BYEAR}!"
        echo "${word^}${BDATE}"
      done

      # Combinations
      echo "${FNAME,,}${LNAME,,}"
      echo "${FNAME^}${LNAME^}"
      echo "${FNAME,,}.${LNAME,,}"
      echo "${FNAME,,}_${LNAME,,}"
      echo "${FNAME,,}${BYEAR}"
      echo "${LNAME,,}${FNAME,,}"
      echo "${FNAME,,}${LNAME^^}"
      echo "${FNAME:0:1}${LNAME,,}${BYEAR}"
      echo "${FNAME,,}${LNAME:0:1}${BYEAR}"

      # Leet speak variations for first name
      LEET=$(echo "${FNAME,,}" | \
        sed 's/a/@/g;s/e/3/g;s/i/1/g;s/o/0/g;s/s/$/g;s/t/+/g')
      echo "$LEET"
      echo "${LEET}${BYEAR}"

    } | sort -u > "$OUTPUT"

    COUNT=$(wc -l < "$OUTPUT")
    echo -e "\n${GREEN}[+]${NC} Generated $COUNT passwords → ${CYAN}$OUTPUT${NC}"
    echo "Preview:"
    head -20 "$OUTPUT"
    ;;

# ── Mutate — Apply common mutations to a wordlist ─────────────────────────────
  mutate)
    INPUT="${2:?Usage: $0 mutate <input_wordlist> [output_file]}"
    OUTPUT="${3:-${INPUT%.*}_mutated.txt}"

    echo -e "${CYAN}[*]${NC} Mutating $INPUT..."
    {
      while IFS= read -r word; do
        [[ -z "$word" ]] && continue
        echo "$word"
        echo "${word,,}"
        echo "${word^^}"
        echo "${word^}"
        echo "${word}1"
        echo "${word}12"
        echo "${word}123"
        echo "${word}1234"
        echo "${word}12345"
        echo "${word}!"
        echo "${word}@"
        echo "${word}#"
        echo "${word}2024"
        echo "${word}2025"
        echo "${word}2026"
        echo "${word}123!"
        echo "${word}@123"
        echo "1${word}"
        echo "${word}$"
        echo "${word^}1"
        echo "${word^}!"
        echo "${word^}123"
        echo "${word^}@2024"
        # Leet speak
        echo "${word}" | sed 's/a/@/g;s/e/3/g;s/i/1/g;s/o/0/g;s/s/$/g'
        # Reverse
        echo "$word" | rev
        # Double
        echo "${word}${word}"
      done < "$INPUT"
    } | sort -u > "$OUTPUT"

    echo -e "${GREEN}[+]${NC} Mutated words: $(wc -l < "$OUTPUT") → ${CYAN}$OUTPUT${NC}"
    ;;

# ── Combine — Merge and deduplicate wordlists ─────────────────────────────────
  combine)
    OUTPUT="${2:?Usage: $0 combine <output_file> <wordlist1> [wordlist2...]}"
    shift 2
    echo -e "${CYAN}[*]${NC} Combining wordlists..."
    cat "$@" | sort -u > "$OUTPUT"
    echo -e "${GREEN}[+]${NC} Combined: $(wc -l < "$OUTPUT") unique words → ${CYAN}$OUTPUT${NC}"
    ;;

# ── Help ───────────────────────────────────────────────────────────────────────
  help|*)
    echo -e "${BOLD}wordlist_gen.sh — Modes:${NC}"
    echo ""
    echo "  cewl    <url> [min_len] [output]   — scrape website for words"
    echo "  crunch  [min] [max] [charset]       — generate by pattern"
    echo "  profile [output]                    — generate from personal info"
    echo "  mutate  <wordlist> [output]          — apply common mutations"
    echo "  combine <output> <list1> [list2...]  — merge + deduplicate"
    echo ""
    echo "Examples:"
    echo "  bash wordlist_gen.sh cewl https://example.com 6 words.txt"
    echo "  bash wordlist_gen.sh crunch 6 8 abc123 output.txt"
    echo "  bash wordlist_gen.sh profile targets.txt"
    echo "  bash wordlist_gen.sh mutate rockyou.txt rockyou_mutated.txt"
    echo "  bash wordlist_gen.sh combine merged.txt list1.txt list2.txt"
    ;;
esac
