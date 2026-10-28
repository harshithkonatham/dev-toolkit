#!/usr/bin/env python3
"""
crypto_helper.py — CTF Cryptography Toolkit
Usage: python3 crypto_helper.py <mode> [args]
Modes: xor | rsa | vigenere | affine | freq | padding | hash | all
"""

import sys
import math
import string
import hashlib
import itertools
from collections import Counter


# ── XOR ───────────────────────────────────────────────────────────────────────

def xor_single_byte(ciphertext: bytes, key: int) -> bytes:
    return bytes([b ^ key for b in ciphertext])


def xor_brute_force(ciphertext: bytes, printable_only: bool = True) -> list:
    """Brute force single-byte XOR, return likely candidates."""
    results = []
    for key in range(256):
        decrypted = xor_single_byte(ciphertext, key)
        try:
            text = decrypted.decode("utf-8")
            score = sum(c in string.printable for c in text)
            # English text heuristic
            english_score = sum(text.lower().count(c) for c in "etaoinshrdlu ")
            results.append((english_score, key, text))
        except (UnicodeDecodeError, ValueError):
            continue

    results.sort(reverse=True)
    return results[:5]


def xor_repeating_key(ciphertext: bytes, key: bytes) -> bytes:
    """XOR with repeating key."""
    return bytes([b ^ key[i % len(key)] for i, b in enumerate(ciphertext)])


def detect_xor_key_length(ciphertext: bytes, max_keylen: int = 40) -> list:
    """Detect XOR key length using Hamming distance."""
    def hamming(a: bytes, b: bytes) -> int:
        return sum(bin(x ^ y).count("1") for x, y in zip(a, b))

    results = []
    for keylen in range(2, min(max_keylen, len(ciphertext) // 2)):
        chunks = [ciphertext[i:i+keylen] for i in range(0, len(ciphertext) - keylen, keylen)]
        distances = []
        for i in range(min(4, len(chunks) - 1)):
            d = hamming(chunks[i], chunks[i+1]) / keylen
            distances.append(d)
        if distances:
            results.append((sum(distances)/len(distances), keylen))

    results.sort()
    return results[:5]


def crack_repeating_xor(ciphertext: bytes, keylen: int) -> tuple:
    """Crack repeating-key XOR given key length."""
    blocks = [ciphertext[i::keylen] for i in range(keylen)]
    key = []
    for block in blocks:
        candidates = xor_brute_force(block)
        if candidates:
            key.append(candidates[0][1])
    key_bytes = bytes(key)
    plaintext = xor_repeating_key(ciphertext, key_bytes)
    return key_bytes, plaintext


# ── RSA ───────────────────────────────────────────────────────────────────────

def egcd(a: int, b: int) -> tuple:
    if a == 0:
        return b, 0, 1
    g, x, y = egcd(b % a, a)
    return g, y - (b // a) * x, x


def modinv(a: int, m: int) -> int:
    g, x, _ = egcd(a % m, m)
    if g != 1:
        raise ValueError(f"No modular inverse: gcd({a},{m})={g}")
    return x % m


def rsa_decrypt(c: int, d: int, n: int) -> int:
    return pow(c, d, n)


def rsa_encrypt(m: int, e: int, n: int) -> int:
    return pow(m, e, n)


def long_to_bytes(n: int) -> bytes:
    length = (n.bit_length() + 7) // 8
    return n.to_bytes(length, "big")


def bytes_to_long(b: bytes) -> int:
    return int.from_bytes(b, "big")


def factor_small_n(n: int) -> tuple:
    """Factor small RSA modulus by trial division."""
    for p in range(2, int(math.isqrt(n)) + 1):
        if n % p == 0:
            return p, n // p
    return None, None


def rsa_common_modulus(n: int, e1: int, e2: int, c1: int, c2: int) -> int:
    """Common modulus attack: decrypt if gcd(e1,e2)=1."""
    g, a, b = egcd(e1, e2)
    if g != 1:
        raise ValueError(f"gcd(e1,e2) = {g} ≠ 1, attack not applicable")
    if a < 0:
        c1 = modinv(c1, n)
        a = -a
    if b < 0:
        c2 = modinv(c2, n)
        b = -b
    m = pow(c1, a, n) * pow(c2, b, n) % n
    return m


def rsa_hastad(ciphertexts: list, moduli: list, e: int = 3) -> int:
    """Hastad's broadcast attack (small e, same plaintext encrypted under multiple keys)."""
    from functools import reduce

    def crt(remainders, moduli):
        M = 1
        for m in moduli:
            M *= m
        result = 0
        for r, m in zip(remainders, moduli):
            Mi = M // m
            _, inv, _ = egcd(Mi % m, m)
            result = (result + r * Mi * inv) % M
        return result % M

    combined = crt(ciphertexts, moduli)
    # Take e-th root
    root = round(combined ** (1/e))
    # Check nearby values
    for r in range(root - 2, root + 3):
        if r ** e == combined:
            return r
    return combined  # Return CRT result if integer root not found


# ── Vigenere Cipher ───────────────────────────────────────────────────────────

def vigenere_encrypt(plaintext: str, key: str) -> str:
    key = key.upper()
    result = []
    ki = 0
    for c in plaintext:
        if c.isalpha():
            shift = ord(key[ki % len(key)]) - ord("A")
            if c.isupper():
                result.append(chr((ord(c) - ord("A") + shift) % 26 + ord("A")))
            else:
                result.append(chr((ord(c) - ord("a") + shift) % 26 + ord("a")))
            ki += 1
        else:
            result.append(c)
    return "".join(result)


def vigenere_decrypt(ciphertext: str, key: str) -> str:
    key = key.upper()
    result = []
    ki = 0
    for c in ciphertext:
        if c.isalpha():
            shift = ord(key[ki % len(key)]) - ord("A")
            if c.isupper():
                result.append(chr((ord(c) - ord("A") - shift) % 26 + ord("A")))
            else:
                result.append(chr((ord(c) - ord("a") - shift) % 26 + ord("a")))
            ki += 1
        else:
            result.append(c)
    return "".join(result)


def index_of_coincidence(text: str) -> float:
    text = [c for c in text.upper() if c.isalpha()]
    n = len(text)
    if n < 2:
        return 0.0
    freq = Counter(text)
    return sum(f * (f - 1) for f in freq.values()) / (n * (n - 1))


def detect_vigenere_keylen(ciphertext: str, max_keylen: int = 20) -> list:
    text = [c for c in ciphertext.upper() if c.isalpha()]
    results = []
    for keylen in range(1, min(max_keylen + 1, len(text))):
        columns = ["".join(text[i::keylen]) for i in range(keylen)]
        avg_ic = sum(index_of_coincidence(col) for col in columns) / keylen
        results.append((avg_ic, keylen))
    results.sort(reverse=True)
    return results[:5]


ENGLISH_FREQ = {
    "E": 12.70, "T": 9.06, "A": 8.17, "O": 7.51, "I": 6.97,
    "N": 6.75, "S": 6.33, "H": 6.09, "R": 5.99, "D": 4.25,
    "L": 4.03, "C": 2.78, "U": 2.76, "M": 2.41, "W": 2.36,
    "F": 2.23, "G": 2.02, "Y": 1.97, "P": 1.93, "B": 1.29,
    "V": 0.98, "K": 0.77, "J": 0.15, "X": 0.15, "Q": 0.10, "Z": 0.07,
}


def crack_vigenere_column(column: str) -> str:
    """Find most likely key letter for one Vigenere column."""
    column = [c for c in column.upper() if c.isalpha()]
    best_score = float("-inf")
    best_key = "A"
    for key_char in string.ascii_uppercase:
        shift = ord(key_char) - ord("A")
        decrypted = "".join(chr((ord(c) - ord("A") - shift) % 26 + ord("A")) for c in column)
        freq = Counter(decrypted)
        score = sum(ENGLISH_FREQ.get(c, 0) * freq.get(c, 0) for c in string.ascii_uppercase)
        if score > best_score:
            best_score = score
            best_key = key_char
    return best_key


def crack_vigenere(ciphertext: str, keylen: int) -> tuple:
    text = [c for c in ciphertext.upper() if c.isalpha()]
    columns = ["".join(text[i::keylen]) for i in range(keylen)]
    key = "".join(crack_vigenere_column(col) for col in columns)
    plaintext = vigenere_decrypt(ciphertext, key)
    return key, plaintext


# ── Affine Cipher ─────────────────────────────────────────────────────────────

def affine_encrypt(plaintext: str, a: int, b: int) -> str:
    assert math.gcd(a, 26) == 1, f"a={a} must be coprime with 26"
    return "".join(
        chr((a * (ord(c) - ord("A")) + b) % 26 + ord("A")) if c.isalpha() else c
        for c in plaintext.upper()
    )


def affine_decrypt(ciphertext: str, a: int, b: int) -> str:
    a_inv = modinv(a, 26)
    return "".join(
        chr(a_inv * (ord(c) - ord("A") - b) % 26 + ord("A")) if c.isalpha() else c
        for c in ciphertext.upper()
    )


def affine_brute_force(ciphertext: str) -> list:
    valid_a = [a for a in range(1, 26) if math.gcd(a, 26) == 1]
    results = []
    for a in valid_a:
        for b in range(26):
            decrypted = affine_decrypt(ciphertext, a, b)
            score = sum(decrypted.count(c) for c in "ETAOINSHRDLU")
            results.append((score, a, b, decrypted))
    results.sort(reverse=True)
    return results[:5]


# ── Frequency Analysis ────────────────────────────────────────────────────────

def frequency_analysis(text: str) -> dict:
    text = [c for c in text.upper() if c.isalpha()]
    total = len(text)
    freq = Counter(text)
    return {c: (freq.get(c, 0) / total * 100) for c in string.ascii_uppercase}


def print_frequency(text: str):
    freq = frequency_analysis(text)
    sorted_freq = sorted(freq.items(), key=lambda x: x[1], reverse=True)
    print("\nCharacter Frequency Analysis:")
    print(f"{'Char':4} {'Count%':8} {'Bar':30} {'English%':8}")
    print("-" * 55)
    for char, pct in sorted_freq:
        bar = "█" * int(pct * 2)
        eng_pct = ENGLISH_FREQ.get(char, 0)
        print(f"  {char}   {pct:6.2f}%  {bar:30s} ({eng_pct:.2f}%)")


# ── Hash Utils ────────────────────────────────────────────────────────────────

def hash_identify(h: str) -> str:
    h = h.strip()
    length = len(h)
    patterns = {
        32:  ["MD5", "MD4", "NTLM"],
        40:  ["SHA-1", "MySQL5"],
        56:  ["SHA-224"],
        64:  ["SHA-256", "Blake2-256"],
        96:  ["SHA-384"],
        128: ["SHA-512", "Whirlpool"],
    }
    if h.startswith("$2"):   return "bcrypt"
    if h.startswith("$6$"):  return "sha512crypt"
    if h.startswith("$5$"):  return "sha256crypt"
    if h.startswith("$1$"):  return "MD5crypt"
    return ", ".join(patterns.get(length, ["Unknown"]))


def hash_string(s: str) -> dict:
    b = s.encode()
    return {
        "MD5":    hashlib.md5(b).hexdigest(),
        "SHA1":   hashlib.sha1(b).hexdigest(),
        "SHA256": hashlib.sha256(b).hexdigest(),
        "SHA512": hashlib.sha512(b).hexdigest(),
    }


# ── Padding Oracle Helper ─────────────────────────────────────────────────────

def pkcs7_pad(data: bytes, block_size: int = 16) -> bytes:
    pad_len = block_size - (len(data) % block_size)
    return data + bytes([pad_len] * pad_len)


def pkcs7_unpad(data: bytes) -> bytes:
    pad_len = data[-1]
    if pad_len > len(data) or pad_len == 0:
        raise ValueError("Invalid padding")
    if data[-pad_len:] != bytes([pad_len] * pad_len):
        raise ValueError("Invalid padding")
    return data[:-pad_len]


def is_valid_pkcs7(data: bytes) -> bool:
    try:
        pkcs7_unpad(data)
        return True
    except ValueError:
        return False


# ── Main CLI ─────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nExamples:")
        print("  python3 crypto_helper.py xor 4865780a68656c6c6f")
        print("  python3 crypto_helper.py rsa-decrypt 1234 65537 3233 7")
        print("  python3 crypto_helper.py vigenere-crack LXFOPVEFRNHR")
        print("  python3 crypto_helper.py freq 'Hello World'")
        print("  python3 crypto_helper.py hash 'password'")
        print("  python3 crypto_helper.py affine-crack 'ENCRYPTED TEXT'")
        return

    mode = sys.argv[1].lower()

    if mode == "xor":
        data = bytes.fromhex(sys.argv[2]) if len(sys.argv) > 2 else sys.stdin.buffer.read()
        print("XOR brute force (single byte):")
        for score, key, text in xor_brute_force(data):
            print(f"  Key=0x{key:02x} ({key:3d}): {text[:80]}")

    elif mode == "xor-key":
        # Usage: xor-key <hex_data> <hex_key>
        data = bytes.fromhex(sys.argv[2])
        key = bytes.fromhex(sys.argv[3])
        print(xor_repeating_key(data, key))

    elif mode == "xor-detect":
        data = bytes.fromhex(sys.argv[2])
        print("Likely XOR key lengths:")
        for score, keylen in detect_xor_key_length(data):
            print(f"  Key length {keylen}: normalized hamming = {score:.4f}")

    elif mode == "xor-crack":
        data = bytes.fromhex(sys.argv[2])
        keylen = int(sys.argv[3]) if len(sys.argv) > 3 else detect_xor_key_length(data)[0][1]
        key, plaintext = crack_repeating_xor(data, keylen)
        print(f"Key (hex): {key.hex()}")
        print(f"Key (str): {key.decode(errors='replace')}")
        print(f"Plaintext: {plaintext.decode(errors='replace')}")

    elif mode == "rsa-decrypt":
        c, e, n, d = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
        m = rsa_decrypt(c, d, n)
        print(f"m (int):   {m}")
        print(f"m (bytes): {long_to_bytes(m)}")
        print(f"m (str):   {long_to_bytes(m).decode(errors='replace')}")

    elif mode == "rsa-factor":
        n = int(sys.argv[2])
        e = int(sys.argv[3])
        c = int(sys.argv[4]) if len(sys.argv) > 4 else None
        p, q = factor_small_n(n)
        if p:
            print(f"p = {p}")
            print(f"q = {q}")
            phi = (p - 1) * (q - 1)
            d = modinv(e, phi)
            print(f"d = {d}")
            if c:
                m = rsa_decrypt(c, d, n)
                print(f"plaintext: {long_to_bytes(m).decode(errors='replace')}")
        else:
            print("Could not factor n (too large for trial division)")
            print("Try: https://factordb.com/")

    elif mode == "vigenere-crack":
        ciphertext = sys.argv[2]
        print("Detecting key length (by Index of Coincidence):")
        for ic, keylen in detect_vigenere_keylen(ciphertext):
            print(f"  Key length {keylen}: IC = {ic:.4f}")
        print()
        keylen = detect_vigenere_keylen(ciphertext)[0][1]
        key, plaintext = crack_vigenere(ciphertext, keylen)
        print(f"Most likely key: {key}")
        print(f"Plaintext:       {plaintext}")

    elif mode == "vigenere-decrypt":
        ciphertext = sys.argv[2]
        key = sys.argv[3]
        print(vigenere_decrypt(ciphertext, key))

    elif mode == "affine-crack":
        ciphertext = " ".join(sys.argv[2:])
        print("Affine cipher brute force (top 5):")
        for score, a, b, text in affine_brute_force(ciphertext):
            print(f"  a={a}, b={b}: {text[:60]} (score={score})")

    elif mode == "freq":
        text = " ".join(sys.argv[2:])
        print_frequency(text)

    elif mode == "hash":
        s = " ".join(sys.argv[2:])
        hashes = hash_string(s)
        for algo, h in hashes.items():
            print(f"  {algo:8}: {h}")

    elif mode == "hash-id":
        h = sys.argv[2]
        print(f"Hash type: {hash_identify(h)}")

    elif mode == "all":
        data = " ".join(sys.argv[2:])
        print(f"\n=== Crypto Analysis: {data[:50]}... ===\n")

        print("Hash identification:", hash_identify(data))
        print()

        # Try base64
        import base64
        try:
            decoded = base64.b64decode(data + "==").decode("utf-8", errors="replace")
            print(f"Base64 decoded: {decoded}")
        except Exception:
            pass

        # Frequency
        if any(c.isalpha() for c in data):
            print_frequency(data)

        # ROT13
        rot13 = data.translate(str.maketrans(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
            "NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm"
        ))
        print(f"\nROT13: {rot13}")
    else:
        print(f"Unknown mode: {mode}")
        print(__doc__)


if __name__ == "__main__":
    main()
