#!/bin/bash

# SEEDNodes - Starknet Sepolia Node Installer (Pathfinder)
# Institutional NodeOps - Automated Setup (English banner as requested)
# Ref: Starknet Sepolia public docs and common Pathfinder usage

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

show_banner() {
  clear
  echo -e "${WHITE}"
  cat << 'EOF'
   _____ __            __           __           _            
  / ___// /___  ______/ /____  ____/ /___  _____(_)___  ____ _
  \__ \/ __/ / / / __  / ___ \/ __  / __ \/ ___/ / __ \/ __ `/
 ___/ / /_/ /_/ / /_/ / / / / /_/ / /_/ / /  / / / / / /_/ / 
/____/\__/\__,_/\__,_/_/ /_/\__,_/\____/_/  /_/_/ /_/\__, /  
                                                   /____/   
   Institutional NodeOps - Starknet Sepolia (Pathfinder)
                Purpose: Bitcoin Pool Integration
EOF
  echo -e "${NC}"
}

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
fail() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

progress() {
  local msg=$1
  echo -e "${BLUE}==> ${msg}${NC}"
}

requirements() {
  progress "Checking system requirements"
  [[ -f /etc/os-release ]] || fail "Only Ubuntu/Debian-like systems supported"
  if [[ $EUID -eq 0 ]]; then fail "Run as non-root user with sudo privileges"; fi
  sudo -v || fail "User needs sudo privileges"
}

update_system() {
  progress "Updating system"
  sudo apt-get update -y && sudo apt-get upgrade -y
}

install_packages() {
  progress "Installing base packages"
  sudo apt-get install -y curl jq git ufw ca-certificates gnupg lsb-release wget
}

install_docker() {
  progress "Installing Docker Engine"
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin; do
    sudo apt-get remove --purge -y $pkg 2>/dev/null || true
  done
  sudo apt-get autoremove -y || true
  sudo rm -rf /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
  
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(. /etc/os-release; echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable docker && sudo systemctl restart docker
  sudo docker run --rm hello-world >/dev/null 2>&1 && log "Docker OK" || fail "Docker test failed"
}

configure_firewall() {
  progress "Configuring firewall (UFW)"
  sudo ufw allow 22 || true
  sudo ufw allow ssh || true
  # Pathfinder default HTTP RPC
  sudo ufw allow 9545 || true
  # Metrics (Prometheus scrape)
  sudo ufw allow 9187 || true
  sudo ufw --force enable || true
  sudo ufw reload || true
}

collect_inputs() {
  progress "Collecting configuration"
  read -p "Ethereum Sepolia RPC URL (e.g. https://sepolia.infura.io/v3/KEY): " ETH_RPC
  [[ -n "$ETH_RPC" ]] || fail "Ethereum RPC is required"
  read -p "Data directory (default: /var/lib/pathfinder): " DATA_DIR
  DATA_DIR=${DATA_DIR:-/var/lib/pathfinder}
  read -p "Expose HTTP RPC port (default: 9545): " RPC_PORT
  RPC_PORT=${RPC_PORT:-9545}
  read -p "Enable monitoring stack (Prometheus+Grafana)? [Y/n]: " MON
  MON=${MON:-Y}
}

prepare_dirs() {
  progress "Preparing directories"
  sudo mkdir -p "$DATA_DIR"
  sudo chown -R "$USER":"$USER" "$DATA_DIR"
  mkdir -p "$PWD/compose"
  mkdir -p "$PWD/env"
  mkdir -p "$PWD/monitoring/grafana/dashboards" "$PWD/monitoring/grafana/datasources"
}

write_env() {
  progress "Writing env file"
  cat > env/starknet-sepolia.env <<EOF
# Starknet Sepolia (Pathfinder) - Purpose: Bitcoin Pool Integration
ETHEREUM_RPC_URL=${ETH_RPC}
PATHFINDER_DATA_DIR=${DATA_DIR}
RPC_PORT=${RPC_PORT}
METRICS_PORT=9187
EOF
}

write_monitoring_configs() {
  progress "Writing Prometheus/Grafana configs"
  # Prometheus config
  cat > monitoring/prometheus-starknet.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'starknet_pathfinder'
    static_configs:
      - targets: ['pathfinder:9187']
EOF

  # Grafana datasource
  mkdir -p monitoring/grafana/datasources
  cat > monitoring/grafana/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

  # Grafana dashboard (minimal up panel)
  mkdir -p monitoring/grafana/dashboards
  cat > monitoring/grafana/dashboards/starknet-up.json << 'EOF'
{
  "annotations": {"list": []},
  "panels": [
    {
      "type": "stat",
      "title": "Pathfinder UP",
      "targets": [{"expr": "up{job=\"starknet_pathfinder\"}", "refId": "A"}],
      "fieldConfig": {"defaults": {"unit": "none"}},
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
    }
  ],
  "schemaVersion": 38,
  "title": "Starknet Pathfinder",
  "version": 1
}
EOF

  # Grafana dashboards provisioning
  cat > monitoring/grafana/dashboards/dashboards.yml << 'EOF'
apiVersion: 1
providers:
  - name: 'starknet'
    orgId: 1
    type: file
    disableDeletion: true
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
}

write_compose() {
  progress "Writing docker-compose"
  cat > compose/starknet-sepolia.docker-compose.yml << 'EOF'
services:
  pathfinder:
    container_name: starknet-pathfinder
    image: eqlabs/pathfinder:latest
    restart: unless-stopped
    user: "0:0"
    environment:
      - RUST_LOG=info
    volumes:
      - ${PATHFINDER_DATA_DIR}:/usr/share/pathfinder/data
    ports:
      - "${RPC_PORT}:9545"
      - "9187:9187"
    command: >
      pathfinder \
      --network sepolia \
      --ethereum.url ${ETHEREUM_RPC_URL} \
      --http-rpc 0.0.0.0:9545 \
      --monitoring 0.0.0.0:9187
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "-", "http://localhost:9545/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  prometheus:
    image: prom/prometheus:latest
    container_name: starknet-prometheus
    restart: unless-stopped
    volumes:
      - ../monitoring/prometheus-starknet.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - "9090:9090"
    profiles:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: starknet-grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ../monitoring/grafana/datasources:/etc/grafana/provisioning/datasources:ro
      - ../monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
    ports:
      - "3000:3000"
    profiles:
      - monitoring
EOF
}

start_node() {
  progress "Starting Starknet Sepolia (Pathfinder)"
  set -a; source env/starknet-sepolia.env; set +a
  if [[ "${MON^^}" == "Y" ]]; then
    docker compose -f compose/starknet-sepolia.docker-compose.yml --profile monitoring up -d
  else
    docker compose -f compose/starknet-sepolia.docker-compose.yml up -d pathfinder
  fi
  sleep 5
  docker compose -f compose/starknet-sepolia.docker-compose.yml ps
}

final_info() {
  echo ""
  echo -e "${CYAN}Starknet Sepolia node is starting. Useful commands:${NC}"
  echo "  • View logs:   docker compose -f compose/starknet-sepolia.docker-compose.yml logs -fn 200"
  echo "  • Status:      docker compose -f compose/starknet-sepolia.docker-compose.yml ps"
  echo "  • Stop:        docker compose -f compose/starknet-sepolia.docker-compose.yml down"
  echo "  • HTTP RPC:    http://<server-ip>:${RPC_PORT}"
  echo "  • Metrics:     http://<server-ip>:9187 (Prometheus scrape)"
  echo "  • Prometheus:  http://<server-ip>:9090"
  echo "  • Grafana:     http://<server-ip>:3000 (admin/admin by default)"
  echo ""
  echo -e "${YELLOW}Purpose: Bitcoin Pool Integration (per guide).${NC}"
  log "Done"
}

main() {
  show_banner
  echo -e "${YELLOW}This installer will deploy Starknet Sepolia (Pathfinder) with Docker.${NC}"
  read -p "Continue? (y/n): " ok
  [[ "$ok" == "y" ]] || exit 0
  requirements
  update_system
  install_packages
  install_docker
  configure_firewall
  collect_inputs
  prepare_dirs
  write_env
  write_monitoring_configs
  write_compose
  start_node
  final_info
}

main "$@"
