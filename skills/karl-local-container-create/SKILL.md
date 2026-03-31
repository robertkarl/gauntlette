---
name: karl-local-container-create
description: "Provision a new Proxmox LXC container: create CT, configure networking, set up DNS in Pi-hole, install Tailscale, create systemd service, and document everything in ~/homelab/README.md."
---

# /karl-local-container-create — Provision a Proxmox LXC Container

You are a homelab sysadmin. The user wants to create a new Proxmox LXC container for a project. Your job is to walk through every step — from CT creation to DNS to Tailscale to documentation — so that no future human or agent has to play detective.

## Behavior

- Interactive. Ask questions one at a time. Don't batch.
- State your recommendation and WHY before asking for input.
- If something fails, stop and report it. Don't retry in a loop.
- Every step that changes infrastructure must be confirmed before execution.
- Leave breadcrumbs everywhere. If it's not documented, it didn't happen.

## Environment

- **Proxmox host:** 192.168.50.57 (SSH as `rk`, passwordless sudo)
- **Pi-hole:** CT 102, IP 192.168.50.64, config at `/etc/dnsmasq.d/10-custom.conf`
- **Reverse proxy:** CT 103, IP 192.168.50.92, nginx with Let's Encrypt wildcard cert for `*.robertkarl.net`
- **Homelab README:** `~/homelab/README.md`
- **Network:** 192.168.50.0/24, DHCP (no static range carved out)
- **Container template:** Check what's available: `ssh rk@192.168.50.57 "ls /var/lib/vz/template/cache/"`

## Process

### Step 0: Gather information

Ask the user for these details, one at a time, with sensible defaults:

1. **CT ID** — Must not conflict with existing CTs. Check with:
   ```bash
   ssh rk@192.168.50.57 "sudo pct list"
   ```
   Recommend: next available ID after the highest existing one.

2. **Hostname** — Short name for the container (e.g., `chef`, `karlol`, `paperclip`). Will be used for `{hostname}.robertkarl.net`.

3. **Project name** — What project is this for? One-line description of its purpose.

4. **IP address** — DHCP or static. Recommend DHCP (consistent with existing setup — containers use DHCP reservations, not static IPs inside the container). Note: DHCP reservation must be set on the router (192.168.50.1) after the container gets its first IP, or in Pi-hole if using DHCP there.

5. **OS template** — Default to latest Debian. Show available templates from Proxmox.

6. **Resources** — Defaults: 1 core, 512MB RAM, 4GB disk. Ask if they need more (e.g., for Python ML workloads, databases, etc.).

7. **Services to run** — What will run on this container? (e.g., "Python FastAPI server on port 8099", "Node.js app on port 3000", "static file server"). This determines the systemd service setup.

8. **Reverse proxy** — Should this get a `*.robertkarl.net` subdomain? If yes, what subdomain and what backend port?

9. **Network restrictions** — Should this container have internet access or be LAN-only? (Reference: CT 113/Paperclip is LAN-only via Proxmox firewall rules.)

10. **Tailscale** — Install Tailscale? Default yes. Uses userspace networking mode for unprivileged containers.

### Step 1: Create the container

Run on Proxmox host:

```bash
ssh rk@192.168.50.57 "sudo pct create <CT_ID> <TEMPLATE> \
  --hostname <HOSTNAME> \
  --memory <RAM_MB> \
  --cores <CORES> \
  --rootfs local-lvm:<DISK_GB> \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1 \
  --start 1"
```

Verify it started:
```bash
ssh rk@192.168.50.57 "sudo pct status <CT_ID>"
```

Get the DHCP-assigned IP:
```bash
ssh rk@192.168.50.57 "sudo pct exec <CT_ID> -- ip -4 addr show eth0 | grep inet"
```

### Step 2: Base setup

Run inside the container (via `pct exec`):

```bash
# Update packages
ssh rk@192.168.50.57 "sudo pct exec <CT_ID> -- bash -c 'apt update && apt upgrade -y'"

# Install essentials
ssh rk@192.168.50.57 "sudo pct exec <CT_ID> -- bash -c 'apt install -y curl wget git sudo'"

# Create rk user with SSH key
ssh rk@192.168.50.57 "sudo pct exec <CT_ID> -- bash -c '
  useradd -m -s /bin/bash rk
  echo \"rk ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/rk
  mkdir -p /home/rk/.ssh
  echo \"$(cat ~/.ssh/authorized_keys)\" > /home/rk/.ssh/authorized_keys
  chown -R rk:rk /home/rk/.ssh
  chmod 700 /home/rk/.ssh
  chmod 600 /home/rk/.ssh/authorized_keys
'"
```

Verify SSH access:
```bash
ssh rk@<CT_IP> "hostname"
```

### Step 3: Set up DNS in Pi-hole

Add a local DNS record so `<hostname>.robertkarl.net` resolves to the container's IP on the LAN.

**If the service should be behind the reverse proxy (recommended):**

Point DNS to the reverse proxy IP (192.168.50.92), not directly to the container:

```bash
ssh rk@192.168.50.57 "sudo pct exec 102 -- bash -c 'echo \"address=/<HOSTNAME>.robertkarl.net/192.168.50.92\" >> /etc/dnsmasq.d/10-custom.conf'"
```

**If the service should be accessed directly (e.g., non-HTTP like SMTP):**

Point DNS directly to the container:

```bash
ssh rk@192.168.50.57 "sudo pct exec 102 -- bash -c 'echo \"address=/<HOSTNAME>.robertkarl.net/<CT_IP>\" >> /etc/dnsmasq.d/10-custom.conf'"
```

Reload Pi-hole DNS:
```bash
ssh rk@192.168.50.57 "sudo pct exec 102 -- /usr/local/bin/pihole reloaddns"
```

Verify resolution:
```bash
dig <HOSTNAME>.robertkarl.net @192.168.50.64
```

### Step 4: Configure reverse proxy (if applicable)

Add an nginx server block on CT 103 for the new subdomain:

```bash
ssh rk@192.168.50.57 "sudo pct exec 103 -- bash -c 'cat > /etc/nginx/sites-available/<HOSTNAME>.robertkarl.net << \"NGINX_EOF\"
server {
    listen 443 ssl;
    server_name <HOSTNAME>.robertkarl.net;

    ssl_certificate /etc/letsencrypt/live/robertkarl.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/robertkarl.net/privkey.pem;

    location / {
        proxy_pass http://<CT_IP>:<PORT>;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support (include if the service uses WebSockets)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }
}
NGINX_EOF
'"
```

Enable the site and reload nginx:
```bash
ssh rk@192.168.50.57 "sudo pct exec 103 -- bash -c 'ln -sf /etc/nginx/sites-available/<HOSTNAME>.robertkarl.net /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx'"
```

Verify:
```bash
curl -sI https://<HOSTNAME>.robertkarl.net | head -5
```

### Step 5: Install Tailscale

Tailscale on unprivileged LXC containers requires **userspace networking mode** because they don't have access to `/dev/net/tun`.

```bash
ssh rk@<CT_IP> "curl -fsSL https://tailscale.com/install.sh | sh"
```

Start Tailscale with userspace networking:
```bash
ssh rk@<CT_IP> "sudo tailscale up --accept-routes --userspace-networking"
```

This will print an auth URL. The user must visit it to authenticate the node.

Verify:
```bash
ssh rk@<CT_IP> "tailscale status"
```

### Step 6: Create systemd service (if applicable)

If the project runs a daemon/server, create a systemd unit:

```bash
ssh rk@<CT_IP> "sudo tee /etc/systemd/system/<SERVICE_NAME>.service << 'EOF'
[Unit]
Description=<PROJECT_NAME>
After=network.target

[Service]
Type=simple
User=rk
WorkingDirectory=/opt/<SERVICE_NAME>
ExecStart=<START_COMMAND>
Restart=on-failure
RestartSec=5
Environment=<ENV_VARS>

[Install]
WantedBy=multi-user.target
EOF"
```

Enable and start:
```bash
ssh rk@<CT_IP> "sudo systemctl daemon-reload && sudo systemctl enable <SERVICE_NAME> && sudo systemctl start <SERVICE_NAME>"
```

Verify:
```bash
ssh rk@<CT_IP> "systemctl status <SERVICE_NAME>"
```

### Step 7: Network restrictions (if applicable)

If the container should be LAN-only (like CT 113/Paperclip), create a Proxmox firewall rule:

```bash
ssh rk@192.168.50.57 "sudo tee /etc/pve/firewall/<CT_ID>.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: ACCEPT
policy_out: DROP

[RULES]
OUT ACCEPT -dest 192.168.50.0/24
OUT ACCEPT -dest 192.168.50.64 -p udp -dport 53
EOF"
```

### Step 8: Document in homelab README

This is **non-negotiable**. Every container gets a full entry in `~/homelab/README.md`.

Add a new section under `## Services on proxmox` with this format:

```markdown
### <Project Name> (CT <ID>)

<One-line description of what this does.>

| Setting | Value |
|---|---|
| Web UI | https://<hostname>.robertkarl.net |
| IP | <CT_IP> (DHCP) |
| SSH | `ssh rk@<CT_IP>` |
| Container | CT <ID> (Debian 13, unprivileged) |
| Port | <PORT> |
| Stack | <tech stack summary> |

**Service:** `<service-name>.service` (systemd)

**Tailscale:** Configured and authenticated.
```

Include any project-specific notes: how to deploy, how to check logs, dependencies on other containers (e.g., Ollama on VM 200).

### Step 9: Update reverse proxy table

If a reverse proxy entry was created, also update the **Proxied services** table in the Reverse Proxy (CT 103) section of the README:

```markdown
| <Service Name> | https://<hostname>.robertkarl.net | <CT_IP>:<PORT> |
```

### Step 10: Verification checklist

Run through this checklist and report status:

- [ ] Container running (`pct status`)
- [ ] SSH access works (`ssh rk@<CT_IP> hostname`)
- [ ] DNS resolves (`dig <hostname>.robertkarl.net @192.168.50.64`)
- [ ] Reverse proxy serves HTTPS (if applicable)
- [ ] Tailscale connected (`tailscale status`)
- [ ] Systemd service running (if applicable)
- [ ] Homelab README updated
- [ ] Reverse proxy table updated (if applicable)

Print the checklist with pass/fail for each item.

## Important Rules

- **ALWAYS document.** The homelab README is the source of truth. If it's not there, it doesn't exist.
- **DHCP, not static.** Consistent with existing containers. Use DHCP reservations on the router if a stable IP is needed.
- **Unprivileged containers.** Always. Use `--unprivileged 1 --features nesting=1`.
- **Userspace networking for Tailscale.** Unprivileged LXCs don't have `/dev/net/tun`. Always pass `--userspace-networking` to `tailscale up`.
- **DNS goes through Pi-hole.** All `*.robertkarl.net` local resolution is via `/etc/dnsmasq.d/10-custom.conf` in CT 102.
- **HTTPS via reverse proxy.** The wildcard cert lives on CT 103. New services go through the reverse proxy, not direct HTTPS.
- **Confirm before executing.** Every command that changes infrastructure gets user confirmation first.
- **One question per message.** Never batch questions.
