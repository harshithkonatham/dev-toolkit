# Cybersecurity Tools & Scripts

Production-ready scripts for penetration testing, CTF challenges, security auditing, and defensive hardening.
Updated: April 2026.

> **Legal:** Use only on systems you own or have explicit written authorization to test.

---

## Directory Structure

```
cybersecurity/
├── scripts/
│   ├── recon/          — reconnaissance & enumeration scripts
│   ├── web/            — web application attack scripts
│   ├── network/        — network scanning & attack scripts
│   ├── password/       — cracking & brute force scripts
│   ├── forensics/      — digital forensics & log analysis
│   ├── post-exploit/   — privilege escalation & enumeration
│   ├── defensive/      — hardening & monitoring setup
│   └── ctf/            — CTF toolkit scripts
├── tools/
│   ├── setup/          — tool installation scripts per OS
│   ├── configs/        — tool configuration files
│   └── metasploit-rc/  — Metasploit resource scripts
└── wordlists/          — wordlist management
```

---

## Quick Start

```bash
# Make all scripts executable
find cybersecurity/scripts -name "*.sh" -exec chmod +x {} \;
find cybersecurity/tools -name "*.sh" -exec chmod +x {} \;

# Install all tools (choose your OS)
bash cybersecurity/tools/setup/install_macos.sh
bash cybersecurity/tools/setup/install_ubuntu.sh

# Run full recon on a target
bash cybersecurity/scripts/recon/full_recon.sh example.com

# Run web scan
bash cybersecurity/scripts/web/web_scan.sh https://example.com

# Audit your own system
bash cybersecurity/scripts/defensive/audit_system.sh
```

---

## Scripts Reference

| Script | Description |
|---|---|
| `scripts/recon/full_recon.sh` | Full passive + active recon pipeline |
| `scripts/recon/subdomain_enum.sh` | Subdomain enumeration (multi-tool) |
| `scripts/recon/port_scan.sh` | Nmap port scanning with profiles |
| `scripts/recon/osint_gather.sh` | OSINT data collection |
| `scripts/web/web_scan.sh` | Full web application scan |
| `scripts/web/dir_fuzz.sh` | Directory & file fuzzing |
| `scripts/web/header_audit.sh` | HTTP security header checker |
| `scripts/web/ssl_audit.sh` | SSL/TLS configuration audit |
| `scripts/network/arp_scan.sh` | LAN host discovery |
| `scripts/network/packet_capture.sh` | Targeted packet capture |
| `scripts/network/service_enum.sh` | Service banner grabbing |
| `scripts/password/hash_crack.sh` | Multi-tool hash cracking |
| `scripts/password/wordlist_gen.sh` | Custom wordlist generator |
| `scripts/password/brute_ssh.sh` | SSH brute force (authorized use) |
| `scripts/forensics/memory_analysis.sh` | Volatility memory forensics |
| `scripts/forensics/log_analyzer.sh` | System log analysis |
| `scripts/forensics/file_recovery.sh` | Deleted file recovery |
| `scripts/post-exploit/linux_enum.sh` | Linux privilege escalation enum |
| `scripts/post-exploit/windows_enum.ps1` | Windows post-exploitation |
| `scripts/defensive/harden_ssh.sh` | SSH hardening |
| `scripts/defensive/audit_system.sh` | Full system security audit |
| `scripts/defensive/setup_ids.sh` | IDS/IPS setup (Suricata + Fail2Ban) |
| `scripts/ctf/decode_all.sh` | Multi-format decoder |
| `scripts/ctf/steg_toolkit.sh` | Steganography extraction toolkit |
| `scripts/ctf/crypto_helper.py` | Common CTF crypto helpers |
