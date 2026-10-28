# Wordlists Reference

Guide to obtaining, managing, and using wordlists for security testing.

---

## Essential Wordlists

### SecLists (Most Comprehensive)

```bash
# Install
brew install seclists                     # macOS
sudo apt install seclists                 # Ubuntu
git clone --depth 1 https://github.com/danielmiessler/SecLists /usr/share/seclists

# Location
/usr/share/seclists/                      # Linux
/opt/homebrew/share/seclists/             # macOS Homebrew
```

**Key SecLists paths:**

| Path | Description |
|---|---|
| `Passwords/Leaked-Databases/rockyou.txt` | 14M leaked passwords |
| `Discovery/Web-Content/common.txt` | 4,600 common web paths |
| `Discovery/Web-Content/directory-list-2.3-medium.txt` | 220k web paths |
| `Discovery/Web-Content/big.txt` | 20k web paths |
| `Discovery/DNS/subdomains-top1million-20000.txt` | Top 20k subdomains |
| `Discovery/DNS/bitquark-subdomains-top100000.txt` | 100k subdomains |
| `Usernames/top-usernames-shortlist.txt` | Common usernames |
| `Passwords/Common-Credentials/10-million-password-list-top-10000.txt` | Top 10k passwords |
| `Fuzzing/LFI/LFI-Jhaddix.txt` | LFI payloads |
| `Fuzzing/SQLi/Generic-SQLi.txt` | SQL injection payloads |
| `Fuzzing/XSS/XSS-Jhaddix.txt` | XSS payloads |

---

### rockyou.txt

```bash
# Kali Linux (already included)
gunzip /usr/share/wordlists/rockyou.txt.gz
ls -lh /usr/share/wordlists/rockyou.txt   # 134MB, 14M passwords

# Direct download
wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
```

---

### Other Popular Wordlists

```bash
# Kaonashi (rules-based)
git clone https://github.com/kaonashi-passwords/Kaonashi

# OneRuleToRuleThemAll (best hashcat rules)
git clone https://github.com/NotSoSecure/password_cracking_rules

# weakpass.com — large collections
# https://weakpass.com/wordlist

# Probable-Wordlists
git clone https://github.com/berzerk0/Probable-Wordlists

# hashesorg wordlists
# https://hashes.org/
```

---

## Wordlist Management

### Deduplicate & Sort

```bash
# Sort + deduplicate
sort -u wordlist.txt -o wordlist_clean.txt

# Remove duplicates keeping order
awk '!seen[$0]++' wordlist.txt > wordlist_unique.txt

# Count entries
wc -l wordlist.txt
```

### Filter by Length

```bash
# Words 6-12 characters
awk 'length >= 6 && length <= 12' rockyou.txt > rockyou_6-12.txt

# Minimum 8 characters
awk 'length >= 8' rockyou.txt > rockyou_8plus.txt
```

### Combine Wordlists

```bash
cat wordlist1.txt wordlist2.txt | sort -u > combined.txt
```

### Apply Hashcat Rules

```bash
# Generate mutated wordlist
hashcat -a 0 --stdout rockyou.txt -r /usr/share/hashcat/rules/best64.rule > mutated.txt
hashcat -a 0 --stdout rockyou.txt -r rules/OneRuleToRuleThemAll.rule > huge_mutated.txt
```

---

## Generate Custom Wordlists

### CeWL — from website

```bash
cewl https://target.com -m 6 -d 3 -w custom.txt
cewl https://target.com -m 5 --with-numbers -e -w cewl_emails.txt
```

### Crunch — pattern-based

```bash
# 8-char alphanumeric
crunch 8 8 ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -o 8char.txt

# Pattern: 4 lowercase + 4 digits
crunch 8 8 -t @@@@####  -o pattern.txt

# From charset
crunch 6 10 abc123!@ -o custom.txt
```

### Mentalist — GUI (Python)

```bash
pip install mentalist
mentalist
```

---

## Wordlists by Attack Type

| Attack Type | Recommended Wordlist |
|---|---|
| Web directory bruteforce | `seclists/Discovery/Web-Content/common.txt` |
| Large directory scan | `seclists/Discovery/Web-Content/directory-list-2.3-medium.txt` |
| Subdomain enum | `seclists/Discovery/DNS/subdomains-top1million-20000.txt` |
| Password cracking | `rockyou.txt` |
| SSH brute force | `seclists/Passwords/Common-Credentials/best110.txt` |
| Username enum | `seclists/Usernames/top-usernames-shortlist.txt` |
| SQLi payloads | `seclists/Fuzzing/SQLi/Generic-SQLi.txt` |
| XSS payloads | `seclists/Fuzzing/XSS/XSS-Jhaddix.txt` |
| LFI payloads | `seclists/Fuzzing/LFI/LFI-Jhaddix.txt` |
| API endpoints | `seclists/Discovery/Web-Content/api/api-endpoints.txt` |

---

## Storage & Organization

```bash
# Recommended structure
~/wordlists/
├── passwords/
│   ├── rockyou.txt          (14M, general)
│   ├── top10k.txt           (top 10k)
│   └── custom.txt           (target-specific)
├── web/
│   ├── common.txt           (4.6k paths)
│   ├── medium.txt           (220k paths)
│   └── big.txt              (20k paths)
├── dns/
│   └── subdomains.txt       (top 20k)
├── usernames/
│   └── usernames.txt
└── payloads/
    ├── sqli.txt
    ├── xss.txt
    └── lfi.txt
```
