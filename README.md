# traefik-stack

One-command setup for [Traefik](https://github.com/traefik/traefik) + [Traefik Manager](https://github.com/chr0nzz/traefik-manager).

Runs an interactive setup that asks you a few questions and gets both services running in Docker - no manual config editing required.

---

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/chr0nzz/traefik-stack/main/setup.sh | bash
```

Or if you prefer to review the script before running:

```bash
curl -fsSL https://raw.githubusercontent.com/chr0nzz/traefik-stack/main/setup.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

---

## What it does

The script walks you through the following and generates a ready-to-run `docker-compose.yml` and `traefik.yml` based on your answers.

**Deployment type** - external (internet-facing) or internal (LAN / VPN / Tailscale). If external, it shows you exactly which ports to open and pauses until you confirm.

**Domain + subdomains** - set the hostname for the Traefik dashboard and Traefik Manager separately.

**TLS / certificates** - choose one:
- Let's Encrypt - HTTP challenge
- Let's Encrypt - DNS challenge: Cloudflare, Route 53, DigitalOcean, Namecheap, or DuckDNS
- No TLS (HTTP only)

**Dynamic config layout** - a single `dynamic.yml` file, or a directory where each service gets its own `.yml` file. Both are watched by Traefik and apply live without a restart.

**Traefik Manager mounts** - optionally expose access logs, SSL certs (`acme.json`), and a plugins directory to Traefik Manager for richer visibility.

**Docker** - if Docker is not installed, the script offers to install it for you (supports Debian/Ubuntu, RHEL/Fedora, and Arch).

---

## Notes

**Docker install:** if the script installs Docker for you, it will exit after installation with a prompt to re-run. This is expected - the new `docker` group requires a fresh shell session to take effect. Just run the curl command again and the setup will continue normally.

---

## Requirements

- A Linux server (Debian, Ubuntu, Fedora, RHEL, Arch, or compatible)
- `curl`
- Docker + Docker Compose (or let the script install Docker for you)
- A domain with DNS you control

---

## What gets created

```
~/traefik-stack/
- docker-compose.yml
- traefik/
  - traefik.yml          # Traefik static config
  - acme.json            # Let's Encrypt cert storage (chmod 600)
  - logs/
    - access.log
  - config/
    - dynamic.yml        # (single file mode)
    - *.yml              # (directory mode - one file per service)
```

---

## Updating

```bash
cd ~/traefik-stack
docker compose pull
docker compose up -d
```

Running containers are replaced in place - no manual stop needed.

---

## Related

- [Traefik](https://github.com/traefik/traefik) - the reverse proxy
- [Traefik Manager](https://github.com/chr0nzz/traefik-manager) - web UI for managing Traefik without editing YAML
- [Traefik Manager Mobile](https://github.com/chr0nzz/traefik-manager-mobile) - Android companion app

---

## License

GPL-3.0
