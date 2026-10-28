#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup_ids.sh — IDS/IPS Setup: Fail2Ban + Suricata + CrowdSec
# Usage: sudo bash setup_ids.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

[[ "$EUID" -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

DISTRO=$(. /etc/os-release && echo "$ID")

echo -e "\n${BOLD}IDS/IPS Setup${NC}"
echo -e "  Distro: $DISTRO\n"

# ── 1. Fail2Ban ───────────────────────────────────────────────────────────────
info "Installing Fail2Ban..."
case "$DISTRO" in
  ubuntu|debian)
    apt-get install -y fail2ban ;;
  centos|rhel|fedora|rocky)
    yum install -y fail2ban || dnf install -y fail2ban ;;
  *)
    warn "Unknown distro — install fail2ban manually"
    ;;
esac

# Configure Fail2Ban
cat > /etc/fail2ban/jail.d/custom.conf << 'EOF'
[DEFAULT]
bantime   = 1h
findtime  = 10m
maxretry  = 5
banaction = iptables-multiport
backend   = auto
ignoreip  = 127.0.0.1/8 ::1

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 24h

[http-auth]
enabled  = true
port     = http,https
filter   = apache-auth
logpath  = /var/log/apache2/error.log
           /var/log/nginx/error.log
maxretry = 5

[nginx-http-auth]
enabled  = true
port     = http,https
filter   = nginx-http-auth
logpath  = /var/log/nginx/error.log
maxretry = 5

[nginx-limit-req]
enabled  = true
port     = http,https
filter   = nginx-limit-req
logpath  = /var/log/nginx/error.log
maxretry = 10

[nginx-botsearch]
enabled  = true
port     = http,https
filter   = nginx-botsearch
logpath  = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400

[wordpress-xml-rpc]
enabled  = true
port     = http,https
filter   = wordpress
logpath  = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400
EOF

# Create wordpress filter
cat > /etc/fail2ban/filter.d/wordpress.conf << 'EOF'
[Definition]
failregex = ^<HOST>.*"POST /xmlrpc.php
            ^<HOST>.*"GET /wp-login.php.*HTTP.*" (401|403|429)
ignoreregex =
EOF

systemctl enable fail2ban
systemctl restart fail2ban
ok "Fail2Ban configured and started"

# Show status
fail2ban-client status 2>/dev/null | head -5

# ── 2. Suricata IDS ───────────────────────────────────────────────────────────
info "Installing Suricata..."
case "$DISTRO" in
  ubuntu|debian)
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:oisf/suricata-stable 2>/dev/null || true
    apt-get update -q
    apt-get install -y suricata ;;
  centos|rhel|rocky)
    yum install -y epel-release
    yum install -y suricata ;;
  *)
    warn "Install Suricata manually: https://suricata.io/download/"
    ;;
esac

if command -v suricata &>/dev/null; then
  # Get active network interface
  IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' || echo "eth0")

  # Configure Suricata
  sed -i "s/interface: eth0/interface: $IFACE/" /etc/suricata/suricata.yaml 2>/dev/null || true

  # Update rules
  info "Updating Suricata rules..."
  suricata-update 2>/dev/null && ok "Suricata rules updated"

  # Create custom local rules
  cat > /etc/suricata/rules/local.rules << 'EOF'
# Custom local rules

# Detect SSH brute force
alert tcp any any -> $HOME_NET 22 (msg:"SSH brute force"; flow:to_server; threshold:type both,track by_src,count 10,seconds 60; classtype:attempted-dos; sid:9000001; rev:1;)

# Detect port scan
alert tcp any any -> $HOME_NET any (msg:"Port scan detected"; flags:S; threshold:type both,track by_src,count 20,seconds 5; classtype:recon-portscan; sid:9000002; rev:1;)

# Detect SQL injection attempts
alert http any any -> $HTTP_SERVERS $HTTP_PORTS (msg:"SQL Injection attempt"; flow:to_server,established; content:"UNION"; nocase; content:"SELECT"; nocase; distance:0; classtype:web-application-attack; sid:9000003; rev:1;)

# Detect XSS attempts
alert http any any -> $HTTP_SERVERS $HTTP_PORTS (msg:"XSS attempt"; flow:to_server,established; content:"<script>"; nocase; classtype:web-application-attack; sid:9000004; rev:1;)

# Detect directory traversal
alert http any any -> $HTTP_SERVERS $HTTP_PORTS (msg:"Directory traversal"; flow:to_server,established; content:"../"; classtype:web-application-attack; sid:9000005; rev:1;)

# Detect Nmap scan
alert tcp any any -> $HOME_NET any (msg:"Nmap SYN scan detected"; flags:S,12; threshold:type both,track by_src,count 30,seconds 5; classtype:recon-portscan; sid:9000006; rev:1;)

# Alert on DNS queries for known malware C2
alert dns any any -> any 53 (msg:"Suspicious DNS query"; dns.query; content:"evil-domain.com"; nocase; classtype:policy-violation; sid:9000007; rev:1;)
EOF

  # Add local rules to config
  grep -q "local.rules" /etc/suricata/suricata.yaml 2>/dev/null || \
    echo "  - /etc/suricata/rules/local.rules" >> /etc/suricata/suricata.yaml

  # Test config
  suricata -T -c /etc/suricata/suricata.yaml 2>/dev/null && ok "Suricata config valid"

  systemctl enable suricata
  systemctl restart suricata 2>/dev/null || true
  ok "Suricata IDS started on $IFACE"
fi

# ── 3. CrowdSec (modern IPS) ──────────────────────────────────────────────────
info "Installing CrowdSec..."
if ! command -v crowdsec &>/dev/null; then
  curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash 2>/dev/null || \
  curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | bash 2>/dev/null || true

  apt-get install -y crowdsec 2>/dev/null || \
  yum install -y crowdsec 2>/dev/null || \
  warn "CrowdSec install failed — see https://docs.crowdsec.net/"
fi

if command -v crowdsec &>/dev/null; then
  # Install bouncer (iptables)
  apt-get install -y crowdsec-firewall-bouncer-iptables 2>/dev/null || \
  yum install -y crowdsec-firewall-bouncer-iptables 2>/dev/null || true

  systemctl enable crowdsec 2>/dev/null
  systemctl start crowdsec 2>/dev/null || true
  ok "CrowdSec started"

  # Install common collections
  cscli collections install crowdsecurity/linux 2>/dev/null || true
  cscli collections install crowdsecurity/sshd 2>/dev/null || true
  cscli collections install crowdsecurity/nginx 2>/dev/null || true
  cscli collections install crowdsecurity/http-cve 2>/dev/null || true
  ok "CrowdSec collections installed"
fi

# ── 4. auditd — System Call Auditing ─────────────────────────────────────────
info "Setting up auditd..."
apt-get install -y auditd 2>/dev/null || yum install -y audit 2>/dev/null || true

if command -v auditd &>/dev/null; then
  cat > /etc/audit/rules.d/security.rules << 'EOF'
# Delete all existing rules
-D

# Buffer size
-b 8192

# Failure mode: 1=log, 2=panic
-f 1

# Monitor privileged commands
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_commands
-a always,exit -F arch=b32 -S execve -F euid=0 -k root_commands

# Monitor sudo usage
-w /usr/bin/sudo -p x -k sudo_usage
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes

# Monitor authentication
-w /var/log/auth.log -p wa -k auth_log
-w /etc/pam.d -p wa -k pam_changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes

# Monitor SSH
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /root/.ssh -p wa -k root_ssh

# Monitor cron
-w /etc/crontab -p wa -k cron_changes
-w /etc/cron.d -p wa -k cron_changes
-w /var/spool/cron -p wa -k cron_changes

# Monitor network config changes
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network_changes
-w /etc/hosts -p wa -k hosts_changes
-w /etc/network -p wa -k network_changes

# Monitor kernel module loading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Monitor file deletion
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k file_deletion

# Immutable rules (requires reboot to change)
-e 2
EOF

  systemctl enable auditd
  systemctl restart auditd 2>/dev/null || service auditd restart 2>/dev/null || true
  ok "auditd configured with security rules"
fi

# ── Status Summary ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== IDS/IPS Status ===${NC}"
for svc in fail2ban suricata crowdsec auditd; do
  STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "not-installed")
  case "$STATUS" in
    active)   echo -e "  ${GREEN}✔${NC}  $svc: running" ;;
    inactive) echo -e "  ${YELLOW}⚠${NC}  $svc: stopped" ;;
    *)        echo -e "  ${YELLOW}-${NC}  $svc: $STATUS" ;;
  esac
done

echo ""
echo "Management commands:"
echo "  fail2ban-client status          — view bans"
echo "  fail2ban-client set sshd unbanip X.X.X.X — unban IP"
echo "  suricata-update                 — update rules"
echo "  tail -f /var/log/suricata/fast.log — view alerts"
echo "  cscli decisions list            — CrowdSec bans"
echo "  ausearch -k ssh_config          — audit log search"
