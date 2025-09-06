#!/bin/bash

# SEEDNodes - One-Click Installer: Starknet Sepolia (Pathfinder) for Bitcoin Pool
# Applies fixes discovered during ops: sepolia-testnet, --monitor-address, WS URL requirement

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

show_banner() {
  clear || true
  echo -e "${WHITE}"
  cat << 'EOF'
   _____ __            __           __           _            
  / ___// /___  ______/ /____  ____/ /___  _____(_)___  ____ _
  \__ \/ __/ / / / __  / ___ \/ __  / __ \/ ___/ / __ \/ __ `/
 ___/ / /_/ /_/ / /_/ / / / / /_/ / /_/ / /  / / / / / /_/ / 
/____/\__/\__,_/\__,_/_/ /_/\__,_/\____/_/  /_/_/ /_/\__, /  
                                                   /____/   
         SEEDNodes - Starknet Sepolia (Pathfinder) One-Click
                 Purpose: Bitcoin Pool Integration
EOF
  echo -e "${NC}"
}

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
fail() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
progress() { echo -e "${BLUE}==> $1${NC}"; }

usage() {
  cat << USAGE
Uso: $0 [--yes] [--eth-ws WS_URL] [--data-dir DIR] [--rpc-port PORT] [--monitoring Y|N]
  --yes             Modo no interactivo (no pregunta)
  --eth-ws          URL de Ethereum WebSocket (ws:// o wss://)
  --data-dir        Directorio de datos de Pathfinder (default /var/lib/pathfinder)
  --rpc-port        Puerto HTTP RPC de Pathfinder (default 9545)
  --monitoring      Habilitar monitoreo (Y|N) (default Y)
USAGE
}

NON_INTERACTIVE="false"
ARG_ETH_WS=""
ARG_DATA_DIR=""
ARG_RPC_PORT=""
ARG_MON=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)
        NON_INTERACTIVE="true"; shift ;;
      --eth-ws)
        ARG_ETH_WS="$2"; shift 2 ;;
      --data-dir)
        ARG_DATA_DIR="$2"; shift 2 ;;
      --rpc-port)
        ARG_RPC_PORT="$2"; shift 2 ;;
      --monitoring)
        ARG_MON="$2"; shift 2 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        echo "Opción desconocida: $1"; usage; exit 1 ;;
    esac
  done
}

ensure_prereqs() {
  progress "Comprobando prerequisitos (curl, docker, compose)"
  command -v curl >/dev/null || fail "curl no instalado"
  if ! docker info >/dev/null 2>&1; then
    fail "Docker no disponible. Instálalo primero (Engine + Compose v2)"
  fi
}

collect_inputs() {
  progress "Parámetros"
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    ETH_WS=${ARG_ETH_WS:-"wss://ethereum-sepolia.publicnode.com"}
    DATA_DIR=${ARG_DATA_DIR:-"/var/lib/pathfinder"}
    RPC_PORT=${ARG_RPC_PORT:-"9545"}
    MON=${ARG_MON:-"Y"}
    log "Modo no interactivo: ETH_WS=$ETH_WS, DATA_DIR=$DATA_DIR, RPC_PORT=$RPC_PORT, MON=$MON"
  else
    read -p "Ethereum WS URL (recomendado ws(s)://...): " ETH_WS
    if [[ -z "$ETH_WS" ]]; then
      warn "No ingresaste WS. Usaré temporalmente wss://ethereum-sepolia.publicnode.com"
      ETH_WS="wss://ethereum-sepolia.publicnode.com"
    fi
    read -p "Directorio de datos (default: /var/lib/pathfinder): " DATA_DIR
    DATA_DIR=${DATA_DIR:-/var/lib/pathfinder}
    read -p "Puerto RPC HTTP de Pathfinder (default: 9545): " RPC_PORT
    RPC_PORT=${RPC_PORT:-9545}
    read -p "¿Habilitar monitoreo (Prometheus+Grafana+NodeExporter)? [Y/n]: " MON
    MON=${MON:-Y}
  fi
}

prepare_layout() {
  progress "Creando carpetas"
  mkdir -p env compose monitoring/grafana/{dashboards,datasources}
  mkdir -p "$DATA_DIR"
}

write_env() {
  progress "Escribiendo env/starknet-sepolia.env"
  cat > env/starknet-sepolia.env <<EOF
# Starknet Sepolia (Pathfinder)
ETHEREUM_RPC_URL=${ETH_WS}
PATHFINDER_DATA_DIR=${DATA_DIR}
RPC_PORT=${RPC_PORT}
METRICS_PORT=9187
NODE_EXPORTER_PORT=9100
EOF
}

write_compose() {
  progress "Escribiendo compose/starknet-sepolia.docker-compose.yml (fixes aplicados)"
  cat > compose/starknet-sepolia.docker-compose.yml << 'YAML'
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
      - "${RPC_PORT:-9545}:9545"
      - "${METRICS_PORT:-9187}:9187"
    command:
      - --network
      - sepolia-testnet
      - --ethereum.url
      - ${ETHEREUM_RPC_URL}
      - --http-rpc
      - 0.0.0.0:9545
      - --monitor-address
      - 0.0.0.0:9187
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "-", "http://localhost:9545/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  node-exporter:
    image: prom/node-exporter:latest
    container_name: starknet-node-exporter
    restart: unless-stopped
    pid: "host"
    network_mode: host
    command:
      - --path.rootfs=/host
    volumes:
      - /:/host:ro,rslave
    profiles:
      - monitoring

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
YAML
}

write_monitoring() {
  progress "Escribiendo configuración de Prometheus/Grafana"
  cat > monitoring/prometheus-starknet.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'starknet_pathfinder'
    static_configs:
      - targets: ['pathfinder:9187']
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

  cat > monitoring/grafana/datasources/datasource.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

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

  cat > monitoring/grafana/dashboards/starknet-up.json << 'EOF'
{
  "annotations": {"list": []},
  "panels": [
    {"type": "stat","title": "Pathfinder UP","targets": [{"expr": "up{job=\"starknet_pathfinder\"}","refId": "A"}],"gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}},
    {"type": "graph","title": "CPU %","targets": [{"expr": "100 - (avg by(instance)(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)","refId": "B"}],"gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}},
    {"type": "graph","title": "Memory Used %","targets": [{"expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100","refId": "C"}],"gridPos": {"h": 8, "w": 12, "x": 0, "y": 12}}
  ],
  "schemaVersion": 38,
  "title": "Starknet Pathfinder + Host",
  "version": 1
}
EOF
}

bring_up() {
  progress "Levantando servicios"
  set -a; source env/starknet-sepolia.env; set +a
  if [[ "${MON^^}" == "Y" ]]; then
    docker compose -f compose/starknet-sepolia.docker-compose.yml --profile monitoring up -d
  else
    docker compose -f compose/starknet-sepolia.docker-compose.yml up -d pathfinder
  fi
  sleep 3
  docker compose -f compose/starknet-sepolia.docker-compose.yml ps
}

final_msg() {
  echo ""
  echo -e "${CYAN}Listo. Comandos útiles:${NC}"
  echo "  • Logs:  docker compose -f compose/starknet-sepolia.docker-compose.yml logs -fn 200 pathfinder"
  echo "  • RPC:   http://<ip>:${RPC_PORT}"
  echo "  • Metrics: http://<ip>:9187"
  echo "  • Prometheus: http://<ip>:9090  • Grafana: http://<ip>:3000 (admin/admin)"
}

main() {
  show_banner
  parse_args "$@"
  ensure_prereqs
  collect_inputs
  prepare_layout
  write_env
  write_compose
  write_monitoring
  bring_up
  final_msg
}

main "$@"


