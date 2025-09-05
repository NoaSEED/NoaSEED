# Playbook Ethereum - Obol DVT + CSM
## SEEDNodes - NodeOps Institucionales

---

## 🎯 Objetivo

Configurar y operar validadores Ethereum usando Obol Distributed Validator Technology (DVT) y Consensus Layer Client Management (CSM), optimizando para máxima eficiencia y uptime ≥ 99.9% con estándares institucionales.

---

## 📋 Prerequisitos

### Hardware Mínimo
- **CPU**: 12+ cores (ARM64/x86_64) - DVT requiere más recursos
- **RAM**: 48GB+ DDR4 - múltiples clientes y DVT
- **Storage**: 3TB+ NVMe SSD - estado de Ethereum + DVT
- **Network**: 2Gbps+ simétrico - alta concurrencia DVT

### Software Requerido
- **OS**: Ubuntu 22.04 LTS (probado y estable)
- **Docker**: 24.0+ (contenedores para aislamiento)
- **Docker Compose**: 2.20+ (orquestación de servicios)
- **Git**: 2.40+ (control de versiones)

### Configuración Inicial
```bash
# 1. Bootstrap del sistema (instala todo lo necesario)
make bootstrap

# 2. Hardening de seguridad (firewall, SSH, etc.)
make harden

# 3. Configuración de variables (personaliza según tu setup)
cp env/ethereum.env.example env/ethereum.env
# Editar variables según tu infraestructura
```

---

## ⚙️ Configuración de Ethereum

### 1. Variables de Entorno

```bash
# env/ethereum.env
ETHEREUM_NETWORK=mainnet
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
ETHEREUM_BEACON_URL=https://beacon-mainnet.infura.io/v3/YOUR_KEY

# Configuración DVT
DVT_ENABLED=true
DVT_OPERATOR_COUNT=4
DVT_THRESHOLD=3
DVT_CLUSTER_NAME=seednodes-cluster

# Configuración de clientes
EXECUTION_CLIENT=geth
CONSENSUS_CLIENT=lighthouse
EXECUTION_CLIENT_PORT=8545
CONSENSUS_CLIENT_PORT=9000

# Configuración de validadores
VALIDATOR_COUNT=32
VALIDATOR_KEYS_DIR=/opt/ethereum/validator-keys
WITHDRAWAL_KEYS_DIR=/opt/ethereum/withdrawal-keys

# Configuración de monitoreo
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...

# Configuración de backup
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30
```

### 2. Docker Compose para Ethereum

```yaml
# compose/ethereum.docker-compose.yml
version: '3.8'

services:
  geth:
    image: ethereum/client-go:latest
    container_name: ethereum-geth
    restart: unless-stopped
    ports:
      - "8545:8545"  # RPC
      - "8546:8546"  # WebSocket
      - "30303:30303"  # P2P
    volumes:
      - geth_data:/root/.ethereum
      - ./config/geth:/config
    environment:
      - ETHEREUM_NETWORK=${ETHEREUM_NETWORK}
    command: >
      geth
      --mainnet
      --http
      --http.addr 0.0.0.0
      --http.port 8545
      --http.api eth,net,web3,personal,admin
      --ws
      --ws.addr 0.0.0.0
      --ws.port 8546
      --ws.api eth,net,web3,personal,admin
      --metrics
      --metrics.addr 0.0.0.0
      --metrics.port 6060
      --datadir /root/.ethereum
    networks:
      - ethereum-network

  lighthouse-beacon:
    image: sigp/lighthouse:latest
    container_name: ethereum-lighthouse-beacon
    restart: unless-stopped
    ports:
      - "9000:9000"  # Beacon API
      - "9001:9001"  # Metrics
    volumes:
      - lighthouse_beacon_data:/var/lib/lighthouse
      - ./config/lighthouse:/config
    environment:
      - ETHEREUM_NETWORK=${ETHEREUM_NETWORK}
    command: >
      lighthouse beacon_node
      --network mainnet
      --datadir /var/lib/lighthouse
      --http
      --http-address 0.0.0.0
      --http-port 9000
      --metrics
      --metrics-address 0.0.0.0
      --metrics-port 9001
      --checkpoint-sync-url ${ETHEREUM_BEACON_URL}
      --execution-endpoint http://geth:8551
      --execution-jwt /config/jwt.hex
    depends_on:
      - geth
    networks:
      - ethereum-network

  lighthouse-validator:
    image: sigp/lighthouse:latest
    container_name: ethereum-lighthouse-validator
    restart: unless-stopped
    volumes:
      - lighthouse_validator_data:/var/lib/lighthouse
      - ${VALIDATOR_KEYS_DIR}:/keys
      - ${WITHDRAWAL_KEYS_DIR}:/withdrawal-keys
    environment:
      - ETHEREUM_NETWORK=${ETHEREUM_NETWORK}
    command: >
      lighthouse validator
      --network mainnet
      --datadir /var/lib/lighthouse
      --beacon-nodes http://lighthouse-beacon:9000
      --validators-dir /keys
      --secrets-dir /keys
      --init-slashing-protection
      --metrics
      --metrics-address 0.0.0.0
      --metrics-port 9002
    depends_on:
      - lighthouse-beacon
    networks:
      - ethereum-network

  obol-charon:
    image: obolnetwork/charon:latest
    container_name: ethereum-charon
    restart: unless-stopped
    ports:
      - "3610:3610"  # Charon API
      - "3611:3611"  # Metrics
    volumes:
      - charon_data:/opt/charon
      - ./config/charon:/config
    environment:
      - CHARON_CLUSTER_CONFIG_FILE=/config/cluster-config.json
    command: >
      charon
      --data-dir /opt/charon
      --config-file /config/cluster-config.json
      --p2p-external-hostname ${HOSTNAME}
      --p2p-external-ip ${EXTERNAL_IP}
      --api-address 0.0.0.0:3610
      --metrics-address 0.0.0.0:3611
    networks:
      - ethereum-network

  prometheus:
    image: prom/prometheus:latest
    container_name: ethereum-prometheus
    restart: unless-stopped
    ports:
      - "${PROMETHEUS_PORT}:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/ethereum_rules.yml:/etc/prometheus/ethereum_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    networks:
      - ethereum-network

  grafana:
    image: grafana/grafana:latest
    container_name: ethereum-grafana
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-changeme}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SECURITY_DISABLE_GRAVATAR=true
    networks:
      - ethereum-network

volumes:
  geth_data:
  lighthouse_beacon_data:
  lighthouse_validator_data:
  charon_data:
  prometheus_data:
  grafana_data:

networks:
  ethereum-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/16
```

---

## 🚀 Proceso de Despliegue

### 1. Script de Despliegue Ethereum

```bash
#!/bin/bash
# scripts/20_deploy_ethereum.sh

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Verificar prerequisitos
check_prerequisites() {
    log "Verificando prerequisitos para Ethereum..."
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        error "Docker no está instalado"
        exit 1
    fi
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose no está instalado"
        exit 1
    fi
    
    # Verificar archivo de configuración
    if [ ! -f "env/ethereum.env" ]; then
        error "Archivo env/ethereum.env no encontrado"
        exit 1
    fi
    
    # Verificar claves de validadores
    if [ ! -d "${VALIDATOR_KEYS_DIR:-/opt/ethereum/validator-keys}" ]; then
        error "Directorio de claves de validadores no encontrado"
        exit 1
    fi
    
    log "Prerequisitos verificados ✅"
}

# Cargar variables de entorno
load_env() {
    log "Cargando variables de entorno..."
    source env/ethereum.env
    
    # Verificar variables críticas
    if [ -z "${ETHEREUM_NETWORK:-}" ]; then
        error "ETHEREUM_NETWORK no está definida"
        exit 1
    fi
    
    if [ -z "${VALIDATOR_COUNT:-}" ]; then
        error "VALIDATOR_COUNT no está definida"
        exit 1
    fi
    
    log "Variables de entorno cargadas ✅"
}

# Crear directorios necesarios
create_directories() {
    log "Creando directorios necesarios..."
    
    mkdir -p {data,logs,backups,monitoring/grafana/{dashboards,datasources}}
    
    # Crear directorios de claves si no existen
    mkdir -p "${VALIDATOR_KEYS_DIR:-/opt/ethereum/validator-keys}"
    mkdir -p "${WITHDRAWAL_KEYS_DIR:-/opt/ethereum/withdrawal-keys}"
    
    log "Directorios creados ✅"
}

# Configurar DVT
setup_dvt() {
    log "Configurando Distributed Validator Technology..."
    
    if [ "${DVT_ENABLED:-false}" = "true" ]; then
        # Crear configuración de cluster DVT
        cat > config/charon/cluster-config.json << EOF
{
  "name": "${DVT_CLUSTER_NAME:-seednodes-cluster}",
  "operators": ${DVT_OPERATOR_COUNT:-4},
  "threshold": ${DVT_THRESHOLD:-3},
  "network": "mainnet",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "v1.0.0"
}
EOF
        
        log "Configuración DVT creada ✅"
    else
        log "DVT deshabilitado, usando validación tradicional"
    fi
}

# Desplegar servicios
deploy_services() {
    log "Desplegando servicios de Ethereum..."
    
    # Parar servicios existentes
    docker-compose -f compose/ethereum.docker-compose.yml down
    
    # Construir y levantar servicios
    docker-compose -f compose/ethereum.docker-compose.yml up -d
    
    # Esperar a que los servicios estén listos
    log "Esperando a que los servicios estén listos..."
    sleep 90  # Ethereum necesita más tiempo para sincronizar
    
    # Verificar estado de los servicios
    if ! docker-compose -f compose/ethereum.docker-compose.yml ps | grep -q "Up"; then
        error "Algunos servicios no están funcionando"
        docker-compose -f compose/ethereum.docker-compose.yml logs
        exit 1
    fi
    
    log "Servicios desplegados ✅"
}

# Verificar conectividad
verify_connectivity() {
    log "Verificando conectividad..."
    
    # Verificar Geth RPC
    if ! curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8545 > /dev/null; then
        error "Geth RPC no está respondiendo"
        exit 1
    fi
    
    # Verificar Beacon API
    if ! curl -s http://localhost:9000/eth/v1/node/syncing > /dev/null; then
        error "Beacon API no está respondiendo"
        exit 1
    fi
    
    # Verificar Charon API (si DVT está habilitado)
    if [ "${DVT_ENABLED:-false}" = "true" ]; then
        if ! curl -s http://localhost:3610/health > /dev/null; then
            warning "Charon API no está respondiendo"
        fi
    fi
    
    log "Conectividad verificada ✅"
}

# Función principal
main() {
    log "Iniciando despliegue de Ethereum con DVT..."
    
    check_prerequisites
    load_env
    create_directories
    setup_dvt
    deploy_services
    verify_connectivity
    
    log "Despliegue de Ethereum completado exitosamente! 🚀"
    log "Geth RPC: http://localhost:8545"
    log "Beacon API: http://localhost:9000"
    log "Grafana: http://localhost:${GRAFANA_PORT:-3000}"
}

# Ejecutar función principal
main "$@"
```

---

## 📊 Monitoreo y Métricas

### 1. Dashboard de Grafana para Ethereum

```json
{
  "dashboard": {
    "title": "Ethereum - SEEDNodes",
    "panels": [
      {
        "title": "Execution Client Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"geth\"}",
            "legendFormat": "Geth Status"
          }
        ]
      },
      {
        "title": "Consensus Client Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"lighthouse-beacon\"}",
            "legendFormat": "Lighthouse Beacon"
          }
        ]
      },
      {
        "title": "DVT Cluster Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"charon\"}",
            "legendFormat": "Charon DVT"
          }
        ]
      },
      {
        "title": "Block Height",
        "type": "graph",
        "targets": [
          {
            "expr": "geth_block_height",
            "legendFormat": "Execution Block"
          },
          {
            "expr": "lighthouse_beacon_slot",
            "legendFormat": "Consensus Slot"
          }
        ]
      }
    ]
  }
}
```

### 2. Alertas de Prometheus para Ethereum

```yaml
# monitoring/ethereum_rules.yml
groups:
  - name: ethereum
    rules:
      - alert: EthereumExecutionClientDown
        expr: up{job="geth"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Ethereum execution client is down"
          description: "Geth has been down for more than 1 minute"

      - alert: EthereumConsensusClientDown
        expr: up{job="lighthouse-beacon"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Ethereum consensus client is down"
          description: "Lighthouse beacon has been down for more than 1 minute"

      - alert: EthereumValidatorDown
        expr: up{job="lighthouse-validator"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Ethereum validator is down"
          description: "Lighthouse validator has been down for more than 1 minute"

      - alert: EthereumDVTClusterDown
        expr: up{job="charon"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Ethereum DVT cluster is down"
          description: "Charon DVT cluster has been down for more than 1 minute"

      - alert: EthereumSyncDistanceHigh
        expr: lighthouse_beacon_sync_distance > 2
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Ethereum sync distance is high"
          description: "Ethereum sync distance is {{ $value }} blocks"
```

---

## 💾 Backup y Recuperación

### 1. Script de Backup para Ethereum

```bash
#!/bin/bash
# scripts/40_backup_ethereum.sh

backup_ethereum() {
    log "Iniciando backup de Ethereum..."
    
    BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="backups/ethereum-backup-${BACKUP_DATE}.tar.gz"
    
    # Crear backup
    tar -czf "$BACKUP_FILE" \
        data/geth \
        data/lighthouse \
        data/charon \
        config/ \
        logs/ \
        "${VALIDATOR_KEYS_DIR}" \
        "${WITHDRAWAL_KEYS_DIR}"
    
    # Generar hash
    SHA256_HASH=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
    
    # Subir a storage remoto
    aws s3 cp "$BACKUP_FILE" "s3://seedops-backups/ethereum/${BACKUP_FILE}"
    
    # Log de auditoría
    cat >> "audit-logs/backup-${BACKUP_DATE}.log" << EOF
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Type: Ethereum Backup
File: ${BACKUP_FILE}
Size: $(du -h "$BACKUP_FILE" | cut -f1)
SHA256: ${SHA256_HASH}
Validator Count: ${VALIDATOR_COUNT}
DVT Enabled: ${DVT_ENABLED}
Status: SUCCESS
Remote: s3://seedops-backups/ethereum/${BACKUP_FILE}
EOF
    
    log "Backup completado: $BACKUP_FILE ✅"
}
```

---

## 📋 Checklist de Verificación

### Pre-Despliegue
- [ ] Hardware cumple requisitos (12+ cores, 48GB+ RAM, 3TB+ SSD)
- [ ] Sistema operativo actualizado
- [ ] Docker y Docker Compose instalados
- [ ] Variables de entorno configuradas
- [ ] Claves de validadores generadas e importadas
- [ ] Configuración DVT (si aplica)
- [ ] Red y firewall configurados
- [ ] Backup de configuración existente

### Post-Despliegue
- [ ] Geth funcionando correctamente
- [ ] Lighthouse beacon funcionando
- [ ] Lighthouse validator funcionando
- [ ] Charon DVT funcionando (si habilitado)
- [ ] RPC respondiendo
- [ ] Beacon API respondiendo
- [ ] Prometheus recopilando métricas
- [ ] Grafana accesible
- [ ] Alertas configuradas
- [ ] Backup programado
- [ ] Logs de auditoría generados

### Monitoreo Continuo
- [ ] Uptime ≥ 99.9%
- [ ] CPU < 80%
- [ ] RAM < 85%
- [ ] Disk < 90%
- [ ] Sync distance < 2 bloques
- [ ] Sin errores críticos
- [ ] Backups ejecutándose
- [ ] Alertas funcionando
- [ ] Validadores activos
- [ ] DVT cluster saludable

---

## 🎯 Métricas de Éxito

### KPIs Institucionales
- **Uptime**: ≥ 99.9%
- **APR**: Optimizado vs. red
- **Slashing Events**: 0 eventos
- **Tiempo de Respuesta**: < 5 minutos para P0
- **Costos**: Tracking completo
- **Auditorías**: 100% de procesos auditados

### Métricas Técnicas
- **RPC Response Time**: < 100ms
- **Beacon API Response Time**: < 100ms
- **Sync Distance**: < 2 bloques
- **Validator Performance**: > 95% attestations
- **DVT Cluster Health**: 100% operadores activos
- **Memory Usage**: < 85%
- **CPU Usage**: < 80%
- **Disk I/O**: Optimizado
- **Network Latency**: < 50ms

---

**Documento Version**: 1.0  
**Última Actualización**: 2025-01-XX  
**Próxima Revisión**: 2025-04-XX  
**Responsable**: Tech Lead - SEEDNodes

---

*"Este playbook garantiza que cada despliegue de Ethereum en SEEDNodes cumple con estándares institucionales de seguridad, transparencia y continuidad, con soporte completo para DVT y CSM."*
