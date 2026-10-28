# Linux Essentials for Developers

## Overview

Linux powers the vast majority of servers, containers, and cloud infrastructure. Proficiency with Linux commands, system administration, and shell tools is essential for any developer working with DevOps, backend systems, or cloud-native technologies.

## Why Learn Linux?

- **Server dominance** - 90%+ of cloud instances run Linux
- **Container foundation** - Docker, Kubernetes, and OCI containers are Linux-native
- **Automation** - Shell scripting is the backbone of CI/CD and infrastructure automation
- **Open source ecosystem** - Most developer tools are built for Linux first
- **Career requirement** - Expected knowledge for DevOps, SRE, backend, and platform roles

## Essential File and Directory Commands

```bash
# Navigation
pwd                          # Print working directory
ls -la                       # List all files with details
ls -lhS                      # List sorted by size, human-readable
cd /var/log                  # Change directory
cd -                         # Return to previous directory
tree -L 2                    # Directory tree (2 levels deep)

# File operations
cp -r source/ dest/          # Copy recursively
mv old.txt new.txt           # Move or rename
rm -rf directory/            # Remove recursively (use with caution)
mkdir -p a/b/c               # Create nested directories
touch file.txt               # Create empty file or update timestamp
ln -s /path/to/target link   # Create symbolic link

# File content
cat file.txt                 # Display entire file
less file.txt                # Page through file (q to quit)
head -n 20 file.txt          # First 20 lines
tail -n 50 file.txt          # Last 50 lines
tail -f /var/log/syslog      # Follow log file in real time
wc -l file.txt               # Count lines

# Search
find / -name "*.conf" -type f 2>/dev/null       # Find files by name
find . -mtime -7 -type f                         # Files modified in last 7 days
find . -size +100M                                # Files larger than 100MB
locate filename                                   # Fast search via index (updatedb)
which python3                                     # Find command location
```

## File Permissions and Ownership

### Permission Structure

```
-rwxr-xr-- 1 user group 4096 Jan 15 10:30 script.sh
│└┬┘└┬┘└┬┘
│ │   │   └── Others: read only
│ │   └────── Group: read + execute
│ └────────── Owner: read + write + execute
└──────────── File type (- = file, d = directory, l = link)
```

### Numeric (Octal) Permissions

| Number | Permission       | Symbol |
|--------|------------------|--------|
| 0      | None             | ---    |
| 1      | Execute          | --x    |
| 2      | Write            | -w-    |
| 4      | Read             | r--    |
| 5      | Read + Execute   | r-x    |
| 6      | Read + Write     | rw-    |
| 7      | All              | rwx    |

```bash
# Change permissions
chmod 755 script.sh          # rwxr-xr-x
chmod 644 config.txt         # rw-r--r--
chmod +x script.sh           # Add execute for all
chmod u+w,g-w file.txt       # Owner +write, group -write
chmod -R 755 directory/      # Recursive

# Change ownership
chown user:group file.txt
chown -R www-data:www-data /var/www/
chgrp developers project/

# Special permissions
chmod u+s binary             # SUID - runs as file owner
chmod g+s directory/         # SGID - new files inherit group
chmod +t /tmp                # Sticky bit - only owner can delete
```

## Package Managers

### APT (Debian/Ubuntu)

```bash
sudo apt update                      # Refresh package index
sudo apt upgrade                     # Upgrade all packages
sudo apt install nginx               # Install package
sudo apt remove nginx                # Remove package (keep config)
sudo apt purge nginx                 # Remove package + config
sudo apt autoremove                  # Remove unused dependencies
apt search keyword                   # Search packages
apt show nginx                       # Package details
dpkg -l | grep nginx                 # List installed matching pattern
```

### DNF / YUM (RHEL/CentOS/Fedora)

```bash
sudo dnf update                      # Update all packages
sudo dnf install httpd               # Install package
sudo dnf remove httpd                # Remove package
sudo dnf search keyword              # Search packages
sudo dnf info httpd                  # Package details
sudo dnf list installed              # List installed packages
sudo dnf group install "Development Tools"  # Install group
```

### Pacman (Arch Linux)

```bash
sudo pacman -Syu                     # Full system upgrade
sudo pacman -S nginx                 # Install package
sudo pacman -R nginx                 # Remove package
sudo pacman -Ss keyword              # Search packages
sudo pacman -Qi nginx                # Package info
sudo pacman -Qs keyword              # Search installed packages
```

## Systemd and Service Management

```bash
# Service control
sudo systemctl start nginx           # Start service
sudo systemctl stop nginx            # Stop service
sudo systemctl restart nginx         # Restart service
sudo systemctl reload nginx          # Reload config without restart
sudo systemctl enable nginx          # Start on boot
sudo systemctl disable nginx         # Do not start on boot
sudo systemctl status nginx          # Check status

# View logs
journalctl -u nginx                  # Logs for a service
journalctl -u nginx --since "1 hour ago"
journalctl -u nginx -f               # Follow logs
journalctl -p err                    # Only error-level messages
journalctl --disk-usage              # Check log storage size

# System state
systemctl list-units --type=service  # List all services
systemctl list-units --failed        # List failed services
systemctl is-active nginx            # Check if running
systemctl is-enabled nginx           # Check if enabled on boot

# Create a custom service
# /etc/systemd/system/myapp.service
```

### Custom Systemd Service

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server --port 8080
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

```bash
# After creating the service file
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
```

## Cron Jobs

```bash
# Edit crontab for current user
crontab -e

# List cron jobs
crontab -l

# Crontab format
# ┌───────── minute (0-59)
# │ ┌─────── hour (0-23)
# │ │ ┌───── day of month (1-31)
# │ │ │ ┌─── month (1-12)
# │ │ │ │ ┌─ day of week (0-7, 0 and 7 = Sunday)
# │ │ │ │ │
# * * * * * command
```

### Common Cron Patterns

```bash
# Every minute
* * * * * /path/to/script.sh

# Every 5 minutes
*/5 * * * * /path/to/script.sh

# Every hour at minute 0
0 * * * * /path/to/script.sh

# Daily at 2:30 AM
30 2 * * * /path/to/backup.sh

# Weekly on Sunday at midnight
0 0 * * 0 /path/to/weekly.sh

# Monthly on the 1st at 6 AM
0 6 1 * * /path/to/monthly.sh

# Weekdays at 9 AM
0 9 * * 1-5 /path/to/report.sh

# Redirect output to log
0 * * * * /path/to/script.sh >> /var/log/myjob.log 2>&1

# Use environment variables
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=admin@example.com
```

### Systemd Timers (Modern Alternative)

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily backup timer

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl enable --now backup.timer
systemctl list-timers --all
```

## SSH Configuration and Tunneling

### SSH Config

```bash
# ~/.ssh/config
Host dev
  HostName 10.0.1.50
  User developer
  IdentityFile ~/.ssh/id_ed25519
  ForwardAgent yes

Host bastion
  HostName bastion.example.com
  User admin
  IdentityFile ~/.ssh/id_ed25519

Host internal
  HostName 10.0.2.100
  User deploy
  ProxyJump bastion

Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
  AddKeysToAgent yes
```

### Key Management

```bash
# Generate ED25519 key (recommended)
ssh-keygen -t ed25519 -C "you@example.com"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host

# SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh-add -l                   # List loaded keys
```

### Tunneling

```bash
# Local port forwarding (access remote service locally)
# Access remote DB on localhost:5433
ssh -L 5433:localhost:5432 user@db-server

# Remote port forwarding (expose local service to remote)
# Make local port 3000 available on remote as port 8080
ssh -R 8080:localhost:3000 user@remote-server

# Dynamic port forwarding (SOCKS proxy)
ssh -D 1080 user@proxy-server

# SSH tunnel in background
ssh -fN -L 5433:localhost:5432 user@db-server
```

## Process Management

```bash
# View processes
ps aux                       # All processes
ps aux | grep nginx          # Filter processes
pgrep -a nginx               # Search by name
pstree -p                    # Process tree

# Process control
kill <PID>                   # Graceful stop (SIGTERM)
kill -9 <PID>                # Force kill (SIGKILL)
pkill -f "python app.py"    # Kill by command pattern
killall nginx                # Kill all by name

# Background jobs
command &                    # Run in background
jobs                         # List background jobs
fg %1                        # Bring job 1 to foreground
bg %1                        # Continue job 1 in background
nohup command &              # Persist after logout
disown %1                    # Detach job from shell

# Resource limits
ulimit -a                    # Show all limits
ulimit -n 65536              # Set max open files
```

## Performance Monitoring

### CPU and Memory

```bash
# top - real-time process monitor
top
# Press: 1 (per-CPU), M (sort by memory), P (sort by CPU), q (quit)

# htop - enhanced process monitor (install: apt install htop)
htop

# System overview
uptime                       # Load averages
free -h                      # Memory usage
vmstat 1 5                   # Virtual memory stats (1-sec interval, 5 samples)

# CPU info
lscpu                        # CPU architecture details
nproc                        # Number of processors
cat /proc/loadavg            # Load averages
```

### Disk

```bash
# Disk usage
df -h                        # Filesystem usage
du -sh /var/log              # Directory size
du -h --max-depth=1 /        # Top-level directory sizes
ncdu /                       # Interactive disk usage (install: apt install ncdu)

# I/O monitoring
iostat -x 1                  # Extended I/O stats (1-sec interval)
iotop                        # Per-process I/O (requires root)

# Disk info
lsblk                        # Block devices
fdisk -l                     # Partition info
```

### Memory Deep Dive

```bash
# Detailed memory
cat /proc/meminfo
slabtop                      # Kernel slab cache
smem                         # Per-process memory (PSS)

# Swap
swapon --show                # Show swap devices
free -h                      # Includes swap info
```

## Networking Tools

### Connection and Transfer

```bash
# curl - HTTP client
curl https://api.example.com                    # GET request
curl -X POST -H "Content-Type: application/json" \
  -d '{"key":"value"}' https://api.example.com  # POST with JSON
curl -o file.zip https://example.com/file.zip   # Download to file
curl -I https://example.com                     # Headers only
curl -s https://example.com | jq '.'            # Silent + JSON parsing
curl -w "%{http_code}" -o /dev/null -s URL      # Just status code

# wget - file downloader
wget https://example.com/file.tar.gz            # Download file
wget -r -np https://example.com/docs/           # Recursive download
wget -c https://example.com/large.iso           # Resume download
```

### Network Diagnostics

```bash
# Connection status
ss -tlnp                     # Listening TCP ports with process info
ss -tunap                    # All TCP/UDP connections
netstat -tlnp                # Legacy alternative to ss

# DNS
dig example.com              # DNS lookup (detailed)
dig +short example.com       # Just the IP
dig @8.8.8.8 example.com    # Query specific DNS server
nslookup example.com         # Simple DNS lookup
host example.com             # Simple DNS lookup

# Connectivity
ping -c 4 example.com        # ICMP ping (4 packets)
traceroute example.com       # Trace packet route
mtr example.com              # Combined ping + traceroute
nc -zv host 80               # Test if port is open (netcat)

# Network interfaces
ip addr show                 # Interface addresses
ip route show                # Routing table
ifconfig                     # Legacy interface info
```

### Firewall (iptables / nftables / ufw)

```bash
# UFW (Ubuntu Firewall - simplified iptables)
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow 80,443/tcp
sudo ufw deny from 10.0.0.5
sudo ufw status verbose

# iptables (direct)
sudo iptables -L -n -v                     # List rules
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -j DROP             # Default deny
```

## Shell Scripting Basics

```bash
#!/bin/bash
set -euo pipefail    # Exit on error, undefined vars, pipe failures

# Variables
NAME="world"
echo "Hello, ${NAME}!"

# Conditionals
if [ -f "/etc/hosts" ]; then
  echo "File exists"
elif [ -d "/tmp" ]; then
  echo "Directory exists"
else
  echo "Neither"
fi

# Loops
for server in web1 web2 web3; do
  echo "Checking ${server}..."
  ssh "${server}" uptime
done

# Functions
check_disk() {
  local threshold=${1:-80}
  local usage
  usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  if [ "${usage}" -gt "${threshold}" ]; then
    echo "WARNING: Disk usage at ${usage}%"
    return 1
  fi
  echo "OK: Disk usage at ${usage}%"
  return 0
}
check_disk 90
```

## Common Text Processing

```bash
# grep - search text
grep -r "ERROR" /var/log/           # Recursive search
grep -c "pattern" file.txt          # Count matches
grep -n "pattern" file.txt          # Show line numbers
grep -v "comment" file.txt          # Invert match (exclude)
grep -E "error|warn" file.txt       # Extended regex (OR)

# sed - stream editor
sed 's/old/new/g' file.txt          # Replace all occurrences
sed -i 's/old/new/g' file.txt       # In-place replacement
sed -n '10,20p' file.txt            # Print lines 10-20
sed '/^#/d' file.txt                # Delete comment lines

# awk - text processing
awk '{print $1, $3}' file.txt       # Print columns 1 and 3
awk -F: '{print $1}' /etc/passwd    # Custom delimiter
awk '$3 > 100 {print $0}' data.txt  # Conditional printing
awk '{sum += $1} END {print sum}'    # Sum a column

# Other useful tools
sort file.txt                        # Sort lines
sort -u file.txt                     # Sort and deduplicate
uniq -c                              # Count duplicates (requires sorted input)
cut -d: -f1 /etc/passwd              # Cut columns by delimiter
tr 'a-z' 'A-Z' < file.txt           # Translate characters
xargs                                # Build commands from stdin
```

## Best Practices

1. **Use `set -euo pipefail`** in every bash script for safer execution
2. **Prefer `ss` over `netstat`** - it is faster and more informative
3. **Use `systemctl`** for service management, not legacy init scripts
4. **Keep systems updated** - `apt upgrade` or `dnf update` regularly
5. **Minimize root usage** - Use `sudo` for specific commands, not `sudo su`
6. **Monitor logs** - `journalctl` and `/var/log/` are your debugging friends
7. **Use SSH keys** - Disable password authentication on servers
8. **Document cron jobs** - Add comments above each crontab entry
9. **Test destructive commands** - Use `echo` or `--dry-run` before `rm -rf` or mass operations
10. **Learn one tool well** - Master `awk` or `jq` before collecting more tools

## Resources

- [Linux Command Line (William Shotts)](https://linuxcommand.org/tlcl.php) - Free book
- [TLDR Pages](https://tldr.sh/) - Simplified man pages
- [ExplainShell](https://explainshell.com/) - Break down complex commands
- [Linux Journey](https://linuxjourney.com/) - Interactive lessons
- [DigitalOcean Tutorials](https://www.digitalocean.com/community/tutorials) - Practical guides
- [Arch Wiki](https://wiki.archlinux.org/) - Comprehensive Linux documentation
- [SystemD Documentation](https://www.freedesktop.org/software/systemd/man/)
