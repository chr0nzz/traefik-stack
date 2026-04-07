#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  Traefik + Traefik Manager - Setup Script
#  Usage: curl -fsSL https://raw.githubusercontent.com/chr0nzz/traefik-stack/main/setup.sh | bash
# ─────────────────────────────────────────────────────────────────────────────

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

INSTALL_DIR="${HOME}/traefik-stack"
COMPOSE_CMD=""

# ─── Helpers ──────────────────────────────────────────────────────────────────

print_banner() {
  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "  ████████╗██████╗  █████╗ ███████╗███████╗██╗██╗  ██╗"
  echo "     ██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██║██║ ██╔╝"
  echo "     ██║   ██████╔╝███████║█████╗  █████╗  ██║█████╔╝ "
  echo "     ██║   ██╔══██╗██╔══██║██╔══╝  ██╔══╝  ██║██╔═██╗ "
  echo "     ██║   ██║  ██║██║  ██║███████╗██║     ██║██║  ██╗"
  echo "     ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝"
  echo -e "${RESET}"
  echo -e "  ${DIM}+ Traefik Manager - Interactive Setup${RESET}"
  echo ""
}

step()  { echo -e "\n${CYAN}${BOLD}▸ $1${RESET}"; }
ok()    { echo -e "  ${GREEN}✔${RESET}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
info()  { echo -e "  ${DIM}ℹ  $1${RESET}"; }
die()   { echo -e "\n  ${RED}✖  Error: $1${RESET}\n"; exit 1; }
sep()   { echo -e "\n  ${DIM}────────────────────────────────────────${RESET}"; }

ask() {
  local prompt="$1" default="${2:-}" var_name="$3"
  if [[ -n "$default" ]]; then
    echo -ne "  ${BOLD}${prompt}${RESET} ${DIM}[${default}]${RESET}: "
  else
    echo -ne "  ${BOLD}${prompt}${RESET}: "
  fi
  read -r input </dev/tty
  if [[ -z "$input" && -n "$default" ]]; then
    printf -v "$var_name" '%s' "$default"
  else
    printf -v "$var_name" '%s' "$input"
  fi
}

ask_yn() {
  local prompt="$1" default="${2:-y}" var_name="$3"
  echo -ne "  ${BOLD}${prompt}${RESET} ${DIM}(y/n) [${default}]${RESET}: "
  read -r input </dev/tty
  input="${input:-$default}"
  if [[ "$input" =~ ^[Yy] ]]; then printf -v "$var_name" 'true'
  else printf -v "$var_name" 'false'; fi
}

ask_choice() {
  local prompt="$1" var_name="$2"; shift 2
  local options=("$@")
  echo -e "  ${BOLD}${prompt}${RESET}"
  for i in "${!options[@]}"; do
    echo -e "    ${DIM}$((i+1)))${RESET} ${options[$i]}"
  done
  echo -ne "  Choice [1]: "
  read -r input </dev/tty
  input="${input:-1}"
  local idx=$(( input - 1 ))
  if [[ $idx -lt 0 || $idx -ge ${#options[@]} ]]; then idx=0; fi
  printf -v "$var_name" '%s' "${options[$idx]}"
}

# ─── Docker installation ──────────────────────────────────────────────────────

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
  else
    OS_ID="unknown"
    OS_LIKE=""
  fi
}

install_docker() {
  step "Installing Docker"
  detect_os

  if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* || "$OS_LIKE" == *"ubuntu"* ]]; then
    info "Detected Debian/Ubuntu - using Docker apt repo"
    sudo apt-get update -qq
    sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/${OS_ID} $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "${USER}" || true
    ok "Docker installed via apt"

  elif [[ "$OS_ID" == "fedora" || "$OS_ID" == "rhel" || "$OS_ID" == "centos" || \
          "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" || \
          "$OS_LIKE" == *"rhel"* || "$OS_LIKE" == *"fedora"* ]]; then
    info "Detected RHEL/Fedora - using Docker dnf repo"
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
      || sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "${USER}" || true
    ok "Docker installed via dnf"

  elif [[ "$OS_ID" == "arch" || "$OS_LIKE" == *"arch"* ]]; then
    info "Detected Arch - using pacman"
    sudo pacman -Sy --noconfirm docker docker-compose
    sudo systemctl enable --now docker
    sudo usermod -aG docker "${USER}" || true
    ok "Docker installed via pacman"

  else
    warn "Could not detect package manager. Using Docker convenience script."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "${USER}" || true
    ok "Docker installed via convenience script"
  fi

  if ! docker info &>/dev/null 2>&1; then
    warn "Group changes may require logout. Re-running remaining steps with sg docker..."
    exec sg docker "$0"
  fi
}

check_deps() {
  step "Checking dependencies"

  command -v curl &>/dev/null && ok "curl found" || die "curl is required. Install it and re-run."

  if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    ok "Docker found and running"
  else
    warn "Docker is not installed or the daemon is not running."
    ask_yn "Install Docker now?" "y" INSTALL_DOCKER_NOW
    if [[ "$INSTALL_DOCKER_NOW" == "true" ]]; then
      install_docker
    else
      die "Docker is required. Aborting."
    fi
  fi

  if docker compose version &>/dev/null 2>&1; then
    ok "docker compose (v2) found"
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose &>/dev/null; then
    ok "docker-compose (v1) found"
    COMPOSE_CMD="docker-compose"
  else
    die "Docker Compose is required. Install the Docker Compose plugin and re-run."
  fi
}

# ─── Configuration ────────────────────────────────────────────────────────────

gather_config() {
  step "General"
  echo -e "  ${DIM}Press Enter to accept defaults shown in brackets.${RESET}\n"

  ask "Install directory" "$INSTALL_DIR" INSTALL_DIR

  # ── Deployment type ───────────────────────────────────────────────────────
  sep
  echo ""
  echo -e "  ${BOLD}Deployment type${RESET}"
  info "Internal = LAN / VPN / Tailscale only.  External = reachable from the internet."
  ask_choice "Where will this be accessed from?" DEPLOYMENT_TYPE \
    "External (internet-facing)" \
    "Internal only (LAN / VPN / Tailscale)"

  if [[ "$DEPLOYMENT_TYPE" == "External"* ]]; then EXTERNAL=true
  else EXTERNAL=false; fi

  # ── Domain ────────────────────────────────────────────────────────────────
  sep
  echo ""
  echo -e "  ${BOLD}-- Domain --${RESET}"
  ask "Your domain (e.g. example.com)" "" DOMAIN
  [[ -z "$DOMAIN" ]] && die "A domain is required."

  ask "Traefik dashboard subdomain" "traefik.$DOMAIN" TRAEFIK_DASHBOARD_HOST
  ask "Traefik Manager subdomain"   "manager.$DOMAIN" TM_HOST
  ask_yn "Enable Traefik API dashboard UI?" "y" ENABLE_DASHBOARD

  # ── TLS ──────────────────────────────────────────────────────────────────
  sep
  echo ""
  echo -e "  ${BOLD}-- TLS / Certificates --${RESET}"
  ask_choice "Certificate method" CERT_METHOD \
    "Let's Encrypt - HTTP challenge (port 80 must be open)" \
    "Let's Encrypt - DNS challenge: Cloudflare" \
    "Let's Encrypt - DNS challenge: Route 53 (AWS)" \
    "Let's Encrypt - DNS challenge: DigitalOcean" \
    "Let's Encrypt - DNS challenge: Namecheap" \
    "Let's Encrypt - DNS challenge: DuckDNS" \
    "No TLS (HTTP only)"

  if [[ "$CERT_METHOD" != "No TLS"* ]]; then
    ask "Email for Let's Encrypt" "" ACME_EMAIL
    [[ -z "$ACME_EMAIL" ]] && die "An email is required for Let's Encrypt."
  fi

  DNS_ENV_BLOCK=""
  DNS_PROVIDER=""

  case "$CERT_METHOD" in
    "Let's Encrypt - HTTP challenge"*)
      TLS_TYPE="http"
      CERT_RESOLVER="letsencrypt"
      TRAEFIK_ENTRYPOINT="websecure"
      ;;
    *"Cloudflare"*)
      TLS_TYPE="dns"; CERT_RESOLVER="letsencrypt"; TRAEFIK_ENTRYPOINT="websecure"
      DNS_PROVIDER="cloudflare"
      ask "Cloudflare API Token" "" CF_API_TOKEN
      DNS_ENV_BLOCK="      - CF_API_TOKEN=${CF_API_TOKEN}"
      ;;
    *"Route 53"*)
      TLS_TYPE="dns"; CERT_RESOLVER="letsencrypt"; TRAEFIK_ENTRYPOINT="websecure"
      DNS_PROVIDER="route53"
      ask "AWS Access Key ID"     "" AWS_ACCESS_KEY_ID
      ask "AWS Secret Access Key" "" AWS_SECRET_ACCESS_KEY
      ask "AWS Region"            "us-east-1" AWS_REGION
      DNS_ENV_BLOCK="      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_REGION=${AWS_REGION}"
      ;;
    *"DigitalOcean"*)
      TLS_TYPE="dns"; CERT_RESOLVER="letsencrypt"; TRAEFIK_ENTRYPOINT="websecure"
      DNS_PROVIDER="digitalocean"
      ask "DigitalOcean API Token" "" DO_AUTH_TOKEN
      DNS_ENV_BLOCK="      - DO_AUTH_TOKEN=${DO_AUTH_TOKEN}"
      ;;
    *"Namecheap"*)
      TLS_TYPE="dns"; CERT_RESOLVER="letsencrypt"; TRAEFIK_ENTRYPOINT="websecure"
      DNS_PROVIDER="namecheap"
      ask "Namecheap API User" "" NAMECHEAP_API_USER
      ask "Namecheap API Key"  "" NAMECHEAP_API_KEY
      DNS_ENV_BLOCK="      - NAMECHEAP_API_USER=${NAMECHEAP_API_USER}
      - NAMECHEAP_API_KEY=${NAMECHEAP_API_KEY}"
      ;;
    *"DuckDNS"*)
      TLS_TYPE="dns"; CERT_RESOLVER="letsencrypt"; TRAEFIK_ENTRYPOINT="websecure"
      DNS_PROVIDER="duckdns"
      ask "DuckDNS Token" "" DUCKDNS_TOKEN
      DNS_ENV_BLOCK="      - DUCKDNS_TOKEN=${DUCKDNS_TOKEN}"
      ;;
    "No TLS"*)
      TLS_TYPE="none"; CERT_RESOLVER=""; TRAEFIK_ENTRYPOINT="web"
      warn "Running without TLS. HTTP only."
      ;;
  esac

  # ── Dynamic config layout ─────────────────────────────────────────────────
  sep
  echo ""
  echo -e "  ${BOLD}-- Traefik Dynamic Config --${RESET}"
  info "Single file is simpler. Directory (one .yml per service) is easier at scale."
  ask_choice "Dynamic config layout" CONFIG_LAYOUT \
    "Single file (dynamic.yml)" \
    "Directory - one .yml file per service"

  # ── Traefik Manager mounts ────────────────────────────────────────────────
  sep
  echo ""
  echo -e "  ${BOLD}-- Traefik Manager - Optional Mounts --${RESET}"
  info "Expose extra Traefik data to Traefik Manager for richer visibility."
  ask_yn "Mount access logs?"            "y" MOUNT_ACCESS_LOGS
  ask_yn "Mount SSL certs (acme.json)?"  "y" MOUNT_CERTS
  ask_yn "Mount plugins directory?"      "n" MOUNT_PLUGINS

  # ── Docker network ────────────────────────────────────────────────────────
  sep
  echo ""
  echo -e "  ${BOLD}-- Docker Network --${RESET}"
  ask "Docker network name"       "traefik-net" DOCKER_NETWORK
  ask "Traefik internal API port" "8080"        TRAEFIK_API_PORT

  # ── Port reminder for external setups ─────────────────────────────────────
  if [[ "$EXTERNAL" == "true" ]]; then
    sep
    echo ""
    echo -e "  ${YELLOW}${BOLD}Firewall / Port Requirements${RESET}"
    echo -e "  ${DIM}The following ports must be open on this server's firewall${RESET}"
    echo -e "  ${DIM}and forwarded on your router if behind NAT:${RESET}\n"
    if [[ "$TLS_TYPE" != "none" ]]; then
      echo -e "    ${CYAN}80/tcp${RESET}   HTTP (redirects to HTTPS + ACME HTTP-01 challenge)"
      echo -e "    ${CYAN}443/tcp${RESET}  HTTPS"
    else
      echo -e "    ${CYAN}80/tcp${RESET}   HTTP"
    fi
    echo ""
    echo -e "  ${DIM}Example UFW commands:${RESET}"
    echo -e "  ${DIM}  sudo ufw allow 80/tcp${RESET}"
    if [[ "$TLS_TYPE" != "none" ]]; then
      echo -e "  ${DIM}  sudo ufw allow 443/tcp${RESET}"
    fi
    echo -e "  ${DIM}  sudo ufw reload${RESET}"
    echo ""
    echo -ne "  ${BOLD}Press Enter when ports are open to continue...${RESET}"
    read -r </dev/tty
  fi
}

# ─── Write traefik.yml ────────────────────────────────────────────────────────

build_traefik_static() {
  local resolver_block=""
  if [[ "$TLS_TYPE" == "http" ]]; then
    resolver_block="
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme.json
      httpChallenge:
        entryPoint: web"
  elif [[ "$TLS_TYPE" == "dns" ]]; then
    resolver_block="
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme.json
      dnsChallenge:
        provider: ${DNS_PROVIDER}
        resolvers:
          - \"1.1.1.1:53\"
          - \"8.8.8.8:53\""
  fi

  local file_provider=""
  if [[ "$CONFIG_LAYOUT" == "Single file"* ]]; then
    file_provider="  file:
    filename: /etc/traefik/config/dynamic.yml
    watch: true"
  else
    file_provider="  file:
    directory: /etc/traefik/config
    watch: true"
  fi

  local entrypoints_block=""
  if [[ "$TLS_TYPE" != "none" ]]; then
    entrypoints_block="  web:
    address: \":80\"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: \":443\""
  else
    entrypoints_block="  web:
    address: \":80\""
  fi

  cat > "${INSTALL_DIR}/traefik/traefik.yml" <<EOF
api:
  dashboard: ${ENABLE_DASHBOARD}
  insecure: true

entryPoints:
${entrypoints_block}

providers:
  docker:
    exposedByDefault: false
    network: ${DOCKER_NETWORK}
${file_provider}
${resolver_block}

log:
  level: INFO

accessLog:
  filePath: /logs/access.log
  bufferingSize: 100
EOF
  ok "traefik/traefik.yml written"
}

# ─── Write dynamic config placeholder ────────────────────────────────────────

build_dynamic_config() {
  if [[ "$CONFIG_LAYOUT" == "Single file"* ]]; then
    cat > "${INSTALL_DIR}/traefik/config/dynamic.yml" <<'EOF'
# Traefik dynamic configuration
# Add routers, services, and middlewares here.
# This file is watched - changes apply without restarting Traefik.

http:
  routers: {}
  services: {}
  middlewares: {}
EOF
    ok "traefik/config/dynamic.yml created"
  else
    mkdir -p "${INSTALL_DIR}/traefik/config"
    cat > "${INSTALL_DIR}/traefik/config/README.md" <<'EOF'
# Dynamic Config Directory

Each .yml file in this directory is loaded by Traefik automatically.
Add one file per service. Changes apply live without a restart.

Example files:
  whoami.yml
  grafana.yml
  nextcloud.yml
EOF
    cat > "${INSTALL_DIR}/traefik/config/example-app.yml.disabled" <<'EOF'
http:
  routers:
    my-app:
      rule: "Host(`app.example.com`)"
      entryPoints:
        - websecure
      service: my-app
      tls:
        certResolver: letsencrypt

  services:
    my-app:
      loadBalancer:
        servers:
          - url: "http://my-app-container:3000"
EOF
    ok "traefik/config/ directory created with README and example"
  fi
}

# ─── Write docker-compose.yml ─────────────────────────────────────────────────

build_compose() {
  local tls_label_traefik="" tls_label_tm=""
  if [[ "$TLS_TYPE" != "none" ]]; then
    tls_label_traefik='      - "traefik.http.routers.dashboard.tls.certresolver='"${CERT_RESOLVER}"'"'
    tls_label_tm='      - "traefik.http.routers.traefik-manager.tls.certresolver='"${CERT_RESOLVER}"'"'
  fi

  # Traefik environment block (DNS credentials only)
  local traefik_env=""
  if [[ -n "$DNS_ENV_BLOCK" ]]; then
    traefik_env="    environment:
${DNS_ENV_BLOCK}"
  fi

  # Traefik volumes
  local traefik_vols="      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/traefik.yml:ro
      - ./traefik/acme.json:/acme.json
      - ./traefik/logs:/logs"
  if [[ "$CONFIG_LAYOUT" == "Single file"* ]]; then
    traefik_vols+="
      - ./traefik/config/dynamic.yml:/etc/traefik/config/dynamic.yml:ro"
  else
    traefik_vols+="
      - ./traefik/config:/etc/traefik/config:ro"
  fi
  if [[ "$MOUNT_PLUGINS" == "true" ]]; then
    traefik_vols+="
      - ./traefik/plugins:/plugins"
  fi

  # Traefik Manager volumes
  local tm_vols="      - /var/run/docker.sock:/var/run/docker.sock:ro"
  if [[ "$MOUNT_ACCESS_LOGS" == "true" ]]; then
    tm_vols+="
      - ./traefik/logs:/logs:ro"
  fi
  if [[ "$MOUNT_CERTS" == "true" ]]; then
    tm_vols+="
      - ./traefik/acme.json:/acme.json:ro"
  fi
  if [[ "$MOUNT_PLUGINS" == "true" ]]; then
    tm_vols+="
      - ./traefik/plugins:/plugins:ro"
  fi
  if [[ "$CONFIG_LAYOUT" == "Single file"* ]]; then
    tm_vols+="
      - ./traefik/config/dynamic.yml:/etc/traefik/config/dynamic.yml"
  else
    tm_vols+="
      - ./traefik/config:/etc/traefik/config"
  fi



  # 443 port line
  local port_443=""
  if [[ "$TLS_TYPE" != "none" ]]; then
    port_443='      - "443:443"'
  fi

  cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
networks:
  ${DOCKER_NETWORK}:
    external: false
    name: ${DOCKER_NETWORK}

services:

  # ── Traefik ────────────────────────────────────────────────────────────────
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    networks:
      - ${DOCKER_NETWORK}
    ports:
      - "80:80"
$(if [[ -n "$port_443" ]]; then echo "$port_443"; fi)
      - "${TRAEFIK_API_PORT}:8080"
    volumes:
${traefik_vols}
$(if [[ -n "$traefik_env" ]]; then echo "$traefik_env"; fi)
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`${TRAEFIK_DASHBOARD_HOST}\`)"
      - "traefik.http.routers.dashboard.entrypoints=${TRAEFIK_ENTRYPOINT}"
      - "traefik.http.routers.dashboard.service=api@internal"
$(if [[ -n "$tls_label_traefik" ]]; then echo "$tls_label_traefik"; fi)

  # ── Traefik Manager ────────────────────────────────────────────────────────
  traefik-manager:
    image: ghcr.io/chr0nzz/traefik-manager:latest
    container_name: traefik-manager
    restart: unless-stopped
    networks:
      - ${DOCKER_NETWORK}
    volumes:
${tm_vols}
    environment:
      - COOKIE_SECURE=true
$(if [[ "$CONFIG_LAYOUT" == "Directory"* ]]; then echo "      - CONFIG_DIR=/etc/traefik/config"; fi)
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik-manager.rule=Host(\`${TM_HOST}\`)"
      - "traefik.http.routers.traefik-manager.entrypoints=${TRAEFIK_ENTRYPOINT}"
      - "traefik.http.services.traefik-manager.loadbalancer.server.port=3000"
$(if [[ -n "$tls_label_tm" ]]; then echo "$tls_label_tm"; fi)
    depends_on:
      - traefik
EOF
  ok "docker-compose.yml written"
}

# ─── Scaffold directories and seed files ─────────────────────────────────────

scaffold() {
  step "Creating directory structure at ${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}/traefik/"{config,logs}
  [[ "$MOUNT_PLUGINS" == "true" ]] && mkdir -p "${INSTALL_DIR}/traefik/plugins" && ok "plugins/ directory created"
  touch "${INSTALL_DIR}/traefik/acme.json"
  chmod 600 "${INSTALL_DIR}/traefik/acme.json"
  ok "acme.json created (chmod 600)"
  touch "${INSTALL_DIR}/traefik/logs/access.log"
  ok "logs/access.log created"
}

# ─── Pull and start ───────────────────────────────────────────────────────────

start_services() {
  step "Pulling images"
  cd "${INSTALL_DIR}"
  $COMPOSE_CMD pull

  step "Starting services"
  $COMPOSE_CMD up -d
  ok "Services started"
}

# ─── Summary ──────────────────────────────────────────────────────────────────

print_summary() {
  local scheme="http"
  [[ "$TLS_TYPE" != "none" ]] && scheme="https"

  echo ""
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${GREEN}${BOLD}  Setup complete!${RESET}"
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
  echo -e "  Traefik dashboard   ${CYAN}${scheme}://${TRAEFIK_DASHBOARD_HOST}${RESET}"
  echo -e "  Traefik Manager     ${CYAN}${scheme}://${TM_HOST}${RESET}"
  echo -e "  Install dir         ${DIM}${INSTALL_DIR}${RESET}"
  echo ""
  if [[ "$CONFIG_LAYOUT" == "Single file"* ]]; then
    echo -e "  ${DIM}Dynamic config  ${INSTALL_DIR}/traefik/config/dynamic.yml${RESET}"
  else
    echo -e "  ${DIM}Dynamic config  ${INSTALL_DIR}/traefik/config/*.yml${RESET}"
  fi
  echo ""
  echo -e "  ${DIM}Useful commands:${RESET}"
  echo -e "  ${DIM}  cd ${INSTALL_DIR}${RESET}"
  echo -e "  ${DIM}  ${COMPOSE_CMD} logs -f traefik${RESET}"
  echo -e "  ${DIM}  ${COMPOSE_CMD} logs -f traefik-manager${RESET}"
  echo ""
  echo -e "  ${CYAN}${BOLD}Updating${RESET}"
  echo -e "  ${DIM}To update both services to the latest images:${RESET}"
  echo -e "  ${DIM}  cd ${INSTALL_DIR}${RESET}"
  echo -e "  ${DIM}  ${COMPOSE_CMD} pull${RESET}"
  echo -e "  ${DIM}  ${COMPOSE_CMD} up -d${RESET}"
  echo -e "  ${DIM}Running containers are replaced one at a time - no manual stop needed.${RESET}"
  echo ""
  echo -e "  ${DIM}Stop:    ${COMPOSE_CMD} down${RESET}"
  echo -e "  ${DIM}Restart: ${COMPOSE_CMD} restart${RESET}"
  echo ""
  if [[ "$EXTERNAL" == "true" ]]; then
    warn "DNS A records for ${TRAEFIK_DASHBOARD_HOST} and ${TM_HOST} must point to this server's IP."
  fi
  if [[ "$TLS_TYPE" == "none" ]]; then
    warn "TLS is disabled. Consider enabling it before exposing this publicly."
  fi
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  print_banner
  check_deps
  gather_config
  scaffold
  build_traefik_static
  build_dynamic_config
  build_compose
  start_services
  print_summary
}

main "$@"
