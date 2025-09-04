#!/usr/bin/env bash
# SEED Ops - Starknet Monitoring Script
# Script de configuración del stack de monitoreo para validador Starknet
# Parte del Institutional Node Operations Handbook (INOH) - SEED Org

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "[ERROR] Linea $LINENO"; exit 1' ERR

# =============================================================================
# CONFIGURACIÓN Y CONSTANTES
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/env/starknet.env}"
readonly STARKNET_USER="starknet"
readonly STARKNET_GROUP="starknet"
readonly STARKNET_HOME="/opt/starknet"
readonly LOG_FILE="/var/log/starknet-monitoring.log"

# Directorios de monitoreo
readonly MONITORING_DIR="$STARKNET_HOME/monitoring"
readonly PROMETHEUS_DIR="$MONITORING_DIR/prometheus"
readonly GRAFANA_DIR="$MONITORING_DIR/grafana"
readonly ALERTMANAGER_DIR="$MONITORING_DIR/alertmanager"

# Puertos por defecto
readonly PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
readonly GRAFANA_PORT="${GRAFANA_PORT:-3000}"
readonly NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
readonly ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}"

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# FUNCIONES DE LOGGING
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $timestamp - $message" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $timestamp - $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message" | tee -a "$LOG_FILE"
            ;;
        *)
            echo -e "${BLUE}[$level]${NC} $timestamp - $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# =============================================================================
# FUNCIONES DE VALIDACIÓN
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root o con sudo"
        exit 1
    fi
}

check_user_exists() {
    if ! getent passwd "$STARKNET_USER" >/dev/null 2>&1; then
        log_error "Usuario $STARKNET_USER no existe. Ejecutar bootstrap primero: make bootstrap"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker no está instalado. Ejecutar bootstrap primero: make bootstrap"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker no está funcionando. Verificar servicio: systemctl status docker"
        exit 1
    fi
}

load_environment() {
    log_info "Cargando variables de entorno..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warn "Archivo de entorno no encontrado: $ENV_FILE"
        log_warn "Usando valores por defecto"
        return 0
    fi
    
    # Cargar variables
    source "$ENV_FILE"
    
    # Validar variables críticas
    local critical_vars=("METRICS_PORT" "PROMETHEUS_PORT" "GRAFANA_PORT")
    local missing_vars=()
    
    for var in "${critical_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_warn "Variables críticas faltantes: ${missing_vars[*]}"
        log_warn "Usando valores por defecto"
    else
        log_info "Variables de entorno cargadas correctamente"
    fi
}

validate_ports() {
    log_info "Validando puertos de monitoreo..."
    
    local ports=("$PROMETHEUS_PORT" "$GRAFANA_PORT" "$NODE_EXPORTER_PORT" "$ALERTMANAGER_PORT")
    
    for port in "${ports[@]}"; do
        if ss -lnt | grep -q ":$port "; then
            log_warn "Puerto $port ya está en uso"
        else
            log_info "Puerto $port disponible"
        fi
    done
}

# =============================================================================
# FUNCIONES DE PREPARACIÓN
# =============================================================================

prepare_directories() {
    log_info "Preparando directorios de monitoreo..."
    
    local directories=(
        "$MONITORING_DIR" "$PROMETHEUS_DIR" "$GRAFANA_DIR" "$ALERTMANAGER_DIR"
        "$PROMETHEUS_DIR/rules" "$PROMETHEUS_DIR/data" "$GRAFANA_DIR/provisioning"
        "$GRAFANA_DIR/provisioning/datasources" "$GRAFANA_DIR/provisioning/dashboards"
        "$ALERTMANAGER_DIR/data"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Directorio creado: $dir"
        else
            log_info "Directorio ya existe: $dir"
        fi
        
        # Establecer permisos correctos
        chown "$STARKNET_USER:$STARKNET_GROUP" "$dir"
        chmod 755 "$dir"
    done
    
    log_info "Directorios de monitoreo preparados"
}

# =============================================================================
# FUNCIONES DE PROMETHEUS
# =============================================================================

setup_prometheus() {
    log_info "Configurando Prometheus..."
    
    # Configuración principal de Prometheus
    local prometheus_config="$PROMETHEUS_DIR/prometheus.yml"
    
    if [[ ! -f "$prometheus_config" ]]; then
        cat > "$prometheus_config" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'starknet-validator'
    environment: '${NETWORK:-mainnet}'

rule_files:
  - "starknet-alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:${PROMETHEUS_PORT}']
    metrics_path: /metrics
    scrape_interval: 15s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:${NODE_EXPORTER_PORT}']
    metrics_path: /metrics
    scrape_interval: 15s

  - job_name: 'starknet-validator'
    static_configs:
      - targets: ['localhost:${METRICS_PORT:-9100}']
    metrics_path: /metrics
    scrape_interval: 30s
    scrape_timeout: 10s

  - job_name: 'starknet-rpc'
    static_configs:
      - targets: ['localhost:${RPC_PORT:-9545}']
    metrics_path: /metrics
    scrape_interval: 30s
    scrape_timeout: 10s
    honor_labels: true

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:${ALERTMANAGER_PORT}']
      scheme: http
      timeout: 10s
EOF
        log_info "Configuración de Prometheus creada"
    else
        log_info "Configuración de Prometheus ya existe"
    fi
    
    # Reglas de alertas
    local alerts_config="$PROMETHEUS_DIR/starknet-alerts.yml"
    
    if [[ ! -f "$alerts_config" ]]; then
        cat > "$alerts_config" << EOF
groups:
  - name: starknet-validator
    rules:
      - alert: StarknetValidatorDown
        expr: up{job="starknet-validator"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Starknet validator is down"
          description: "Starknet validator has been down for more than 1 minute"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% for more than 5 minutes"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space"
          description: "Disk space is below 15%"

      - alert: StarknetRPCDown
        expr: up{job="starknet-rpc"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Starknet RPC endpoint is down"
          description: "Starknet RPC endpoint has been down for more than 1 minute"

      - alert: StarknetSyncBehind
        expr: starknet_sync_status{job="starknet-validator"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Starknet validator is out of sync"
          description: "Starknet validator is not synced with the network"
EOF
        log_info "Reglas de alertas de Prometheus creadas"
    else
        log_info "Reglas de alertas de Prometheus ya existen"
    fi
    
    # Establecer permisos correctos
    chown "$STARKNET_USER:$STARKNET_GROUP" "$PROMETHEUS_DIR"/*
    chmod 644 "$PROMETHEUS_DIR"/*
    
    log_info "Prometheus configurado"
}

# =============================================================================
# FUNCIONES DE GRAFANA
# =============================================================================

setup_grafana() {
    log_info "Configurando Grafana..."
    
    # Configuración principal de Grafana
    local grafana_config="$GRAFANA_DIR/grafana.ini"
    
    if [[ ! -f "$grafana_config" ]]; then
        cat > "$grafana_config" << EOF
[server]
http_port = ${GRAFANA_PORT}
domain = localhost
root_url = http://localhost:${GRAFANA_PORT}/

[database]
type = sqlite3
path = /var/lib/grafana/grafana.db

[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD:-admin123}
secret_key = ${GRAFANA_SECRET_KEY:-$(openssl rand -hex 32)}

[users]
allow_sign_up = false
allow_org_create = false

[auth.anonymous]
enabled = false

[log]
mode = console
level = info

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning
EOF
        log_info "Configuración de Grafana creada"
    else
        log_info "Configuración de Grafana ya existe"
    fi
    
    # Configuración de datasource de Prometheus
    local datasource_config="$GRAFANA_DIR/provisioning/datasources/prometheus.yml"
    
    if [[ ! -f "$datasource_config" ]]; then
        cat > "$datasource_config" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:${PROMETHEUS_PORT}
    isDefault: true
    editable: true
EOF
        log_info "Configuración de datasource de Grafana creada"
    else
        log_info "Configuración de datasource de Grafana ya existe"
    fi
    
    # Dashboard de Starknet
    local dashboard_config="$GRAFANA_DIR/provisioning/dashboards/starknet.yml"
    
    if [[ ! -f "$dashboard_config" ]]; then
        cat > "$dashboard_config" << EOF
apiVersion: 1

providers:
  - name: 'Starknet'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
        log_info "Configuración de dashboards de Grafana creada"
    else
        log_info "Configuración de dashboards de Grafana ya existe"
    fi
    
    # Dashboard JSON de Starknet
    local dashboard_json="$GRAFANA_DIR/provisioning/dashboards/starknet-overview.json"
    
    if [[ ! -f "$dashboard_json" ]]; then
        cat > "$dashboard_json" << EOF
{
  "dashboard": {
    "id": null,
    "title": "Starknet Validator Overview",
    "tags": ["starknet", "validator", "blockchain"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "System Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
            "legendFormat": "Memory Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Disk Space Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_filesystem_size_bytes{mountpoint=\"/\"} - node_filesystem_avail_bytes{mountpoint=\"/\"}) / node_filesystem_size_bytes{mountpoint=\"/\"} * 100",
            "legendFormat": "Disk Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Network Traffic",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total[5m])",
            "legendFormat": "Receive {{device}}"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total[5m])",
            "legendFormat": "Transmit {{device}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF
        log_info "Dashboard de Starknet creado"
    else
        log_info "Dashboard de Starknet ya existe"
    fi
    
    # Establecer permisos correctos
    chown "$STARKNET_USER:$STARKNET_GROUP" "$GRAFANA_DIR"/*
    chmod 644 "$GRAFANA_DIR"/*
    
    log_info "Grafana configurado"
}

# =============================================================================
# FUNCIONES DE ALERTMANAGER
# =============================================================================

setup_alertmanager() {
    log_info "Configurando Alertmanager..."
    
    # Configuración de Alertmanager
    local alertmanager_config="$ALERTMANAGER_DIR/alertmanager.yml"
    
    if [[ ! -f "$alertmanager_config" ]]; then
        cat > "$alertmanager_config" << EOF
global:
  resolve_timeout: 5m
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@${HOSTNAME:-localhost}'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
    - match:
        severity: critical
      receiver: 'web.hook'
      repeat_interval: 30m

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF
        log_info "Configuración de Alertmanager creada"
    else
        log_info "Configuración de Alertmanager ya existe"
    fi
    
    # Establecer permisos correctos
    chown "$STARKNET_USER:$STARKNET_GROUP" "$ALERTMANAGER_DIR"/*
    chmod 644 "$ALERTMANAGER_DIR"/*
    
    log_info "Alertmanager configurado"
}

# =============================================================================
# FUNCIONES DE DOCKER COMPOSE
# =============================================================================

create_monitoring_compose() {
    log_info "Creando Docker Compose para monitoreo..."
    
    local compose_file="$MONITORING_DIR/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        cat > "$compose_file" << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: starknet-prometheus
    user: "1000:1000"
    restart: unless-stopped
    ports:
      - "${PROMETHEUS_PORT}:9090"
    volumes:
      - ${PROMETHEUS_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${PROMETHEUS_DIR}/starknet-alerts.yml:/etc/prometheus/starknet-alerts.yml:ro
      - ${PROMETHEUS_DIR}/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  grafana:
    image: grafana/grafana:latest
    container_name: starknet-grafana
    user: "1000:1000"
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    volumes:
      - ${GRAFANA_DIR}/grafana.ini:/etc/grafana/grafana.ini:ro
      - ${GRAFANA_DIR}/provisioning:/etc/grafana/provisioning:ro
      - ${GRAFANA_DIR}/data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
    networks:
      - monitoring
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  alertmanager:
    image: prom/alertmanager:latest
    container_name: starknet-alertmanager
    user: "1000:1000"
    restart: unless-stopped
    ports:
      - "${ALERTMANAGER_PORT}:9093"
    volumes:
      - ${ALERTMANAGER_DIR}/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ${ALERTMANAGER_DIR}/data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.listen-address=:9093'
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9093/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  node-exporter:
    image: prom/node-exporter:latest
    container_name: starknet-node-exporter
    user: "1000:1000"
    restart: unless-stopped
    ports:
      - "${NODE_EXPORTER_PORT}:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9100/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  monitoring:
    driver: bridge
    internal: false
    ipam:
      config:
        - subnet: 172.21.0.0/16

volumes:
  prometheus_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${PROMETHEUS_DIR}/data
  grafana_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${GRAFANA_DIR}/data
  alertmanager_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${ALERTMANAGER_DIR}/data
EOF
        log_info "Docker Compose de monitoreo creado"
    else
        log_info "Docker Compose de monitoreo ya existe"
    fi
    
    # Establecer permisos correctos
    chown "$STARKNET_USER:$STARKNET_GROUP" "$compose_file"
    chmod 644 "$compose_file"
    
    log_info "Docker Compose de monitoreo configurado"
}

# =============================================================================
# FUNCIONES DE DESPLIEGUE
# =============================================================================

deploy_monitoring() {
    log_info "Desplegando stack de monitoreo..."
    
    local compose_file="$MONITORING_DIR/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "Archivo Docker Compose de monitoreo no encontrado"
        exit 1
    fi
    
    # Cambiar al directorio de monitoreo
    cd "$MONITORING_DIR"
    
    # Pull de las imágenes
    log_info "Descargando imágenes de monitoreo..."
    if docker compose version >/dev/null 2>&1; then
        docker compose pull
    else
        docker-compose pull
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Error al descargar imágenes de monitoreo"
        exit 1
    fi
    
    # Desplegar servicios
    log_info "Iniciando servicios de monitoreo..."
    if docker compose version >/dev/null 2>&1; then
        docker compose up -d
    else
        docker-compose up -d
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Error al desplegar servicios de monitoreo"
        exit 1
    fi
    
    log_info "Stack de monitoreo desplegado exitosamente"
}

# =============================================================================
# FUNCIONES DE VERIFICACIÓN
# =============================================================================

verify_monitoring() {
    log_info "Verificando despliegue de monitoreo..."
    
    local errors=0
    local compose_file="$MONITORING_DIR/docker-compose.yml"
    
    # Verificar que los contenedores estén corriendo
    if docker compose version >/dev/null 2>&1; then
        local services_status=$(docker compose -f "$compose_file" ps --format json)
    else
        local services_status=$(docker-compose -f "$compose_file" ps --format json)
    fi
    
    local services=("prometheus" "grafana" "alertmanager" "node-exporter")
    
    for service in "${services[@]}"; do
        local service_status=$(echo "$services_status" | jq -r ".[] | select(.Service == \"$service\") | .State")
        
        if [[ "$service_status" == "running" ]]; then
            log_info "✅ $service corriendo correctamente"
        else
            log_error "❌ $service no está corriendo. Estado: $service_status"
            ((errors++))
        fi
    done
    
    # Verificar puertos
    if ss -lnt | grep -q ":$PROMETHEUS_PORT "; then
        log_info "✅ Puerto Prometheus $PROMETHEUS_PORT escuchando"
    else
        log_error "❌ Puerto Prometheus $PROMETHEUS_PORT no está escuchando"
        ((errors++))
    fi
    
    if ss -lnt | grep -q ":$GRAFANA_PORT "; then
        log_info "✅ Puerto Grafana $GRAFANA_PORT escuchando"
    else
        log_error "❌ Puerto Grafana $GRAFANA_PORT no está escuchando"
        ((errors++))
    fi
    
    if ss -lnt | grep -q ":$NODE_EXPORTER_PORT "; then
        log_info "✅ Puerto Node Exporter $NODE_EXPORTER_PORT escuchando"
    else
        log_error "❌ Puerto Node Exporter $NODE_EXPORTER_PORT no está escuchando"
        ((errors++))
    fi
    
    if ss -lnt | grep -q ":$ALERTMANAGER_PORT "; then
        log_info "✅ Puerto Alertmanager $ALERTMANAGER_PORT escuchando"
    else
        log_error "❌ Puerto Alertmanager $ALERTMANAGER_PORT no está escuchando"
        ((errors++))
    fi
    
    # Verificar endpoints de métricas
    verify_metrics_endpoints
    
    if [[ $errors -eq 0 ]]; then
        log_info "✅ Monitoreo verificado exitosamente"
        return 0
    else
        log_error "❌ Se encontraron $errors errores en el monitoreo"
        return 1
    fi
}

verify_metrics_endpoints() {
    log_info "Verificando endpoints de métricas..."
    
    # Verificar Node Exporter
    if curl -s -f "http://localhost:$NODE_EXPORTER_PORT/metrics" >/dev/null; then
        log_info "✅ Node Exporter /metrics responde correctamente"
    else
        log_warn "⚠️  Node Exporter /metrics no responde"
    fi
    
    # Verificar Prometheus
    if curl -s -f "http://localhost:$PROMETHEUS_PORT/-/healthy" >/dev/null; then
        log_info "✅ Prometheus health check exitoso"
    else
        log_warn "⚠️  Prometheus health check falló"
    fi
    
    # Verificar Grafana
    if curl -s -f "http://localhost:$GRAFANA_PORT/api/health" >/dev/null; then
        log_info "✅ Grafana health check exitoso"
    else
        log_warn "⚠️  Grafana health check falló"
    fi
    
    # Verificar Alertmanager
    if curl -s -f "http://localhost:$ALERTMANAGER_PORT/-/healthy" >/dev/null; then
        log_info "✅ Alertmanager health check exitoso"
    else
        log_warn "⚠️  Alertmanager health check falló"
    fi
}

# =============================================================================
# FUNCIONES DE HEALTH CHECK
# =============================================================================

health_check() {
    log_info "Ejecutando health check del sistema..."
    
    # Verificar uso de CPU y RAM
    if command -v docker >/dev/null 2>&1; then
        log_info "Estado de contenedores:"
        if docker compose version >/dev/null 2>&1; then
            docker compose -f "$MONITORING_DIR/docker-compose.yml" ps
        else
            docker-compose -f "$MONITORING_DIR/docker-compose.yml" ps
        fi
        
        log_info "Estadísticas de recursos:"
        if docker compose version >/dev/null 2>&1; then
            docker compose -f "$MONITORING_DIR/docker-compose.yml" stats --no-stream
        else
            docker-compose -f "$MONITORING_DIR/docker-compose.yml" stats --no-stream
        fi
    fi
    
    # Verificar métricas del sistema
    if curl -s -f "http://localhost:$NODE_EXPORTER_PORT/metrics" >/dev/null; then
        log_info "Métricas del sistema disponibles en: http://localhost:$NODE_EXPORTER_PORT/metrics"
    fi
    
    log_info "Health check completado"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log_info "=== Iniciando configuración de monitoreo de Starknet ==="
    log_info "Script: $SCRIPT_NAME"
    log_info "Directorio: $SCRIPT_DIR"
    log_info "Archivo de entorno: $ENV_FILE"
    
    # Verificaciones previas
    check_root
    check_user_exists
    check_docker
    load_environment
    validate_ports
    
    # Preparación
    prepare_directories
    setup_prometheus
    setup_grafana
    setup_alertmanager
    create_monitoring_compose
    
    # Despliegue
    deploy_monitoring
    
    # Verificación
    if verify_monitoring; then
        log_info "=== Configuración de monitoreo completada exitosamente ==="
        log_info "Próximos pasos:"
        log_info "1. Acceder a Grafana: http://localhost:$GRAFANA_PORT (admin/admin123)"
        log_info "2. Acceder a Prometheus: http://localhost:$PROMETHEUS_PORT"
        log_info "3. Acceder a Alertmanager: http://localhost:$ALERTMANAGER_PORT"
        log_info "4. Verificar métricas: http://localhost:$NODE_EXPORTER_PORT/metrics"
        log_info "5. Configurar backup: make backup"
        
        # Mostrar endpoints
        log_info "Endpoints de monitoreo:"
        log_info "  - Prometheus: http://$(hostname -I | awk '{print $1}'):$PROMETHEUS_PORT"
        log_info "  - Grafana: http://$(hostname -I | awk '{print $1}'):$GRAFANA_PORT"
        log_info "  - Node Exporter: http://$(hostname -I | awk '{print $1}'):$NODE_EXPORTER_PORT"
        log_info "  - Alertmanager: http://$(hostname -I | awk '{print $1}'):$ALERTMANAGER_PORT"
    else
        log_error "=== Configuración de monitoreo falló ==="
        exit 1
    fi
}

# =============================================================================
# MANEJO DE ARGUMENTOS
# =============================================================================

case "${1:-}" in
    "--health-check")
        health_check
        ;;
    *)
        main "$@"
        ;;
esac
