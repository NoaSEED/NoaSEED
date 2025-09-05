# Playbook Gnosis - 108 Validators
## SEEDNodes - NodeOps Institucionales

---

## Objetivo

Configurar y operar 108 validadores en Gnosis Chain, optimizando para máxima eficiencia y uptime ≥ 99.9% con estándares institucionales.

---

## Prerequisitos

### Hardware Mínimo
- **CPU**: 16+ cores (ARM64/x86_64) - 108 validadores requieren mucho CPU
- **RAM**: 64GB+ DDR4 - cada validador consume ~500MB
- **Storage**: 4TB+ NVMe SSD - estado de 108 validadores
- **Network**: 2Gbps+ simétrico - alta concurrencia de validadores

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
cp env/gnosis.env.example env/gnosis.env
# Editar variables según tu infraestructura
```

---

## Configuración de Gnosis

### 1. Variables de Entorno

```bash
# env/gnosis.env
GNOSIS_NETWORK=mainnet
GNOSIS_RPC_URL=https://rpc.gnosischain.com
GNOSIS_BEACON_URL=https://beacon.gnosischain.com

# Configuración de validadores
VALIDATOR_COUNT=108
VALIDATOR_START_INDEX=0
VALIDATOR_END_INDEX=107

# Configuración de claves
VALIDATOR_KEYS_DIR=/opt/gnosis/validator-keys
WITHDRAWAL_KEYS_DIR=/opt/gnosis/withdrawal-keys

# Configuración de monitoreo
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...

# Configuración de backup
BACKUP_SCHEDULE="0 2 * * *"  # Diario a las 2 AM
BACKUP_RETENTION_DAYS=30
```

### 2. Docker Compose para Gnosis

```yaml
# compose/gnosis.docker-compose.yml
version: '3.8'

services:
  gnosis-beacon:
    image: sigp/lighthouse:latest
    container_name: gnosis-beacon
    restart: unless-stopped
    ports:
      - "9000:9000"  # Beacon API
      - "9001:9001"  # Metrics
    volumes:
      - gnosis_beacon_data:/var/lib/lighthouse
      - ./config/gnosis:/config
      - ${VALIDATOR_KEYS_DIR}:/keys
    environment:
      - GNOSIS_NETWORK=${GNOSIS_NETWORK}
      - GNOSIS_BEACON_URL=${GNOSIS_BEACON_URL}
    command: >
      lighthouse beacon_node
      --network gnosis
      --datadir /var/lib/lighthouse
      --http
      --http-address 0.0.0.0
      --http-port 9000
      --metrics
      --metrics-address 0.0.0.0
      --metrics-port 9001
      --checkpoint-sync-url ${GNOSIS_BEACON_URL}
    networks:
      - gnosis-network

  gnosis-validator:
    image: sigp/lighthouse:latest
    container_name: gnosis-validator
    restart: unless-stopped
    volumes:
      - gnosis_validator_data:/var/lib/lighthouse
      - ${VALIDATOR_KEYS_DIR}:/keys
      - ${WITHDRAWAL_KEYS_DIR}:/withdrawal-keys
    environment:
      - GNOSIS_NETWORK=${GNOSIS_NETWORK}
    command: >
      lighthouse validator
      --network gnosis
      --datadir /var/lib/lighthouse
      --beacon-nodes http://gnosis-beacon:9000
      --validators-dir /keys
      --secrets-dir /keys
      --init-slashing-protection
      --metrics
      --metrics-address 0.0.0.0
      --metrics-port 9002
    depends_on:
      - gnosis-beacon
    networks:
      - gnosis-network

  prometheus:
    image: prom/prometheus:latest
    container_name: gnosis-prometheus
    restart: unless-stopped
    ports:
      - "${PROMETHEUS_PORT}:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
    networks:
      - gnosis-network

  grafana:
    image: grafana/grafana:latest
    container_name: gnosis-grafana
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    networks:
      - gnosis-network

volumes:
  gnosis_beacon_data:
  gnosis_validator_data:
  prometheus_data:
  grafana_data:

networks:
  gnosis-network:
    driver: bridge
```

### 3. Configuración del Nodo

```yaml
# config/gnosis-config.yaml
network: gnosis
beacon:
  http_address: "0.0.0.0"
  http_port: 9000
  metrics_address: "0.0.0.0"
  metrics_port: 9001
  checkpoint_sync_url: "https://beacon.gnosischain.com"

validator:
  beacon_nodes: ["http://gnosis-beacon:9000"]
  validators_dir: "/keys"
  secrets_dir: "/keys"
  metrics_address: "0.0.0.0"
  metrics_port: 9002
  init_slashing_protection: true

logging:
  level: info
  format: json
```

---

## Proceso de Despliegue

### 1. Preparación del Entorno

```bash
#!/bin/bash
# scripts/20_deploy_gnosis.sh

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
    log "Verificando prerequisitos para Gnosis..."
    
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
    if [ ! -f "env/gnosis.env" ]; then
        error "Archivo env/gnosis.env no encontrado"
        exit 1
    fi
    
    # Verificar claves de validadores
    if [ ! -d "${VALIDATOR_KEYS_DIR:-/opt/gnosis/validator-keys}" ]; then
        error "Directorio de claves de validadores no encontrado"
        exit 1
    fi
    
    log "Prerequisitos verificados ✅"
}

# Cargar variables de entorno
load_env() {
    log "Cargando variables de entorno..."
    source env/gnosis.env
    
    # Verificar variables críticas
    if [ -z "${GNOSIS_NETWORK:-}" ]; then
        error "GNOSIS_NETWORK no está definida"
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
    mkdir -p "${VALIDATOR_KEYS_DIR:-/opt/gnosis/validator-keys}"
    mkdir -p "${WITHDRAWAL_KEYS_DIR:-/opt/gnosis/withdrawal-keys}"
    
    log "Directorios creados ✅"
}

# Generar configuración desde template
generate_config() {
    log "Generando configuración desde template..."
    
    # Usar Jinja2 para renderizar template
    python3 -c "
import os
from jinja2 import Template

# Cargar variables de entorno
env_vars = {k: v for k, v in os.environ.items() if k.startswith('GNOSIS_') or k.startswith('VALIDATOR_')}

# Leer template
with open('templates/gnosis-config.yaml.j2', 'r') as f:
    template = Template(f.read())

# Renderizar configuración
config = template.render(**env_vars)

# Escribir configuración
with open('config/gnosis-config.yaml', 'w') as f:
    f.write(config)
"
    
    log "Configuración generada ✅"
}

# Desplegar servicios
deploy_services() {
    log "Desplegando servicios de Gnosis..."
    
    # Parar servicios existentes
    docker-compose -f compose/gnosis.docker-compose.yml down
    
    # Construir y levantar servicios
    docker-compose -f compose/gnosis.docker-compose.yml up -d
    
    # Esperar a que los servicios estén listos
    log "Esperando a que los servicios estén listos..."
    sleep 60  # Gnosis necesita más tiempo para sincronizar
    
    # Verificar estado de los servicios
    if ! docker-compose -f compose/gnosis.docker-compose.yml ps | grep -q "Up"; then
        error "Algunos servicios no están funcionando"
        docker-compose -f compose/gnosis.docker-compose.yml logs
        exit 1
    fi
    
    log "Servicios desplegados ✅"
}

# Verificar conectividad
verify_connectivity() {
    log "Verificando conectividad..."
    
    # Verificar Beacon API
    if ! curl -s http://localhost:9000/eth/v1/node/syncing > /dev/null; then
        error "Beacon API no está respondiendo"
        exit 1
    fi
    
    # Verificar Prometheus
    if ! curl -s http://localhost:${PROMETHEUS_PORT}/api/v1/query?query=up > /dev/null; then
        warning "Prometheus no está respondiendo"
    fi
    
    # Verificar Grafana
    if ! curl -s http://localhost:${GRAFANA_PORT}/api/health > /dev/null; then
        warning "Grafana no está respondiendo"
    fi
    
    log "Conectividad verificada ✅"
}

# Configurar monitoreo
setup_monitoring() {
    log "Configurando monitoreo para Gnosis..."
    
    # Configurar Prometheus
    cat > monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "gnosis_rules.yml"

scrape_configs:
  - job_name: 'gnosis-beacon'
    static_configs:
      - targets: ['gnosis-beacon:9001']
    scrape_interval: 5s
    metrics_path: /metrics

  - job_name: 'gnosis-validator'
    static_configs:
      - targets: ['gnosis-validator:9002']
    scrape_interval: 5s
    metrics_path: /metrics

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

    # Configurar Grafana datasource
    cat > monitoring/grafana/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    log "Monitoreo configurado ✅"
}

# Generar log de auditoría
generate_audit_log() {
    log "Generando log de auditoría..."
    
    AUDIT_LOG="audit-logs/gnosis-deploy-$(date +%Y%m%d-%H%M%S).log"
    
    cat > "$AUDIT_LOG" << EOF
# Gnosis Deploy Audit Log
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
User: $(whoami)
Server: $(hostname)
Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
Network: ${GNOSIS_NETWORK}
Validator Count: ${VALIDATOR_COUNT}
Status: SUCCESS

## Services Deployed:
$(docker-compose -f compose/gnosis.docker-compose.yml ps)

## Configuration:
- Beacon API Port: 9000
- Beacon Metrics Port: 9001
- Validator Metrics Port: 9002
- Prometheus Port: ${PROMETHEUS_PORT}
- Grafana Port: ${GRAFANA_PORT}

## Verification:
- Beacon API Connectivity: OK
- Prometheus: $(curl -s http://localhost:${PROMETHEUS_PORT}/api/v1/query?query=up > /dev/null && echo "OK" || echo "FAIL")
- Grafana: $(curl -s http://localhost:${GRAFANA_PORT}/api/health > /dev/null && echo "OK" || echo "FAIL")

## Next Steps:
1. Verify validator keys are loaded
2. Check validator performance
3. Set up backup schedule
4. Configure alerting rules
5. Test monitoring dashboards
EOF

    log "Log de auditoría generado: $AUDIT_LOG ✅"
}

# Función principal
main() {
    log "Iniciando despliegue de Gnosis con ${VALIDATOR_COUNT} validadores..."
    
    check_prerequisites
    load_env
    create_directories
    generate_config
    deploy_services
    verify_connectivity
    setup_monitoring
    generate_audit_log
    
    log "Despliegue de Gnosis completado exitosamente! 🚀"
    log "Beacon API: http://localhost:9000"
    log "Grafana: http://localhost:${GRAFANA_PORT}"
    log "Prometheus: http://localhost:${PROMETHEUS_PORT}"
}

# Ejecutar función principal
main "$@"
```

### 2. Configuración de Validadores

```bash
#!/bin/bash
# scripts/configure_gnosis_validators.sh

# Configurar 108 validadores
configure_validators() {
    log "Configurando ${VALIDATOR_COUNT} validadores de Gnosis..."
    
    # Verificar que las claves existen
    if [ ! -f "${VALIDATOR_KEYS_DIR}/keystore-m_12381_3600_0_0_0-$(date +%s).json" ]; then
        error "Claves de validadores no encontradas"
        error "Genera las claves primero con: lighthouse account validator import"
        exit 1
    fi
    
    # Verificar que los validadores están activos
    for i in $(seq 0 $((VALIDATOR_COUNT-1))); do
        VALIDATOR_INDEX=$i
        VALIDATOR_STATUS=$(curl -s "http://localhost:9000/eth/v1/beacon/states/head/validators/${VALIDATOR_INDEX}" | jq -r '.data.status')
        
        if [ "$VALIDATOR_STATUS" = "active_ongoing" ]; then
            log "Validador ${VALIDATOR_INDEX}: ✅ Activo"
        else
            warning "Validador ${VALIDATOR_INDEX}: ⚠️ Estado: ${VALIDATOR_STATUS}"
        fi
    done
    
    log "Configuración de validadores completada ✅"
}
```

---

## Monitoreo y Métricas

### 1. Dashboard de Grafana para Gnosis

```json
{
  "dashboard": {
    "title": "Gnosis Chain - SEEDNodes",
    "panels": [
      {
        "title": "Beacon Node Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"gnosis-beacon\"}",
            "legendFormat": "Beacon Node"
          }
        ]
      },
      {
        "title": "Validator Performance",
        "type": "graph",
        "targets": [
          {
            "expr": "lighthouse_validator_attestations_total",
            "legendFormat": "Attestations"
          },
          {
            "expr": "lighthouse_validator_proposals_total",
            "legendFormat": "Proposals"
          }
        ]
      },
      {
        "title": "Sync Status",
        "type": "graph",
        "targets": [
          {
            "expr": "lighthouse_beacon_sync_distance",
            "legendFormat": "Sync Distance"
          }
        ]
      },
      {
        "title": "Validator Count",
        "type": "stat",
        "targets": [
          {
            "expr": "lighthouse_validator_total",
            "legendFormat": "Total Validators"
          }
        ]
      }
    ]
  }
}
```

### 2. Alertas de Prometheus para Gnosis

```yaml
# monitoring/gnosis_rules.yml
groups:
  - name: gnosis
    rules:
      - alert: GnosisBeaconNodeDown
        expr: up{job="gnosis-beacon"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Gnosis beacon node is down"
          description: "Gnosis beacon node has been down for more than 1 minute"

      - alert: GnosisValidatorDown
        expr: up{job="gnosis-validator"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Gnosis validator is down"
          description: "Gnosis validator has been down for more than 1 minute"

      - alert: GnosisSyncDistanceHigh
        expr: lighthouse_beacon_sync_distance > 2
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Gnosis sync distance is high"
          description: "Gnosis sync distance is {{ $value }} blocks"

      - alert: GnosisValidatorSlashingRisk
        expr: lighthouse_validator_slashing_risk > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Gnosis validator slashing risk detected"
          description: "Validator {{ $labels.validator }} has slashing risk"

      - alert: GnosisValidatorPerformanceLow
        expr: rate(lighthouse_validator_attestations_total[1h]) < 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Gnosis validator performance is low"
          description: "Validator {{ $labels.validator }} attestation rate is {{ $value }}"
```

---

## Backup y Recuperación

### 1. Script de Backup para Gnosis

```bash
#!/bin/bash
# scripts/40_backup_gnosis.sh

backup_gnosis() {
    log "Iniciando backup de Gnosis..."
    
    BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="backups/gnosis-backup-${BACKUP_DATE}.tar.gz"
    
    # Crear backup
    tar -czf "$BACKUP_FILE" \
        data/gnosis \
        config/gnosis-config.yaml \
        logs/ \
        "${VALIDATOR_KEYS_DIR}" \
        "${WITHDRAWAL_KEYS_DIR}"
    
    # Generar hash
    SHA256_HASH=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
    
    # Subir a storage remoto (ejemplo con AWS S3)
    aws s3 cp "$BACKUP_FILE" "s3://seedops-backups/gnosis/${BACKUP_FILE}"
    
    # Log de auditoría
    cat >> "audit-logs/backup-${BACKUP_DATE}.log" << EOF
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Type: Gnosis Backup
File: ${BACKUP_FILE}
Size: $(du -h "$BACKUP_FILE" | cut -f1)
SHA256: ${SHA256_HASH}
Validator Count: ${VALIDATOR_COUNT}
Status: SUCCESS
Remote: s3://seedops-backups/gnosis/${BACKUP_FILE}
EOF
    
    log "Backup completado: $BACKUP_FILE ✅"
}
```

---

## Respuesta a Incidentes

### 1. Script de Incident Response para Gnosis

```bash
#!/bin/bash
# scripts/90_incident_gnosis.sh

incident_response() {
    local incident_type="$1"
    local severity="${2:-P2}"
    
    INCIDENT_ID="GNOSIS-$(date +%Y%m%d-%H%M%S)"
    INCIDENT_LOG="audit-logs/incident-${INCIDENT_ID}.log"
    
    log "Iniciando respuesta a incidente: $INCIDENT_ID"
    
    # Crear log de incidente
    cat > "$INCIDENT_LOG" << EOF
# Gnosis Incident Response Log
Incident ID: ${INCIDENT_ID}
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Type: ${incident_type}
Severity: ${severity}
User: $(whoami)
Server: $(hostname)

## Initial Assessment:
$(docker-compose -f compose/gnosis.docker-compose.yml ps)
$(docker-compose -f compose/gnosis.docker-compose.yml logs --tail=50)

## System Status:
- CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
- Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')
- Disk: $(df -h / | awk 'NR==2 {print $5}')
- Network: $(ss -tuln | grep -E ':(9000|9001|9002)' | wc -l) ports open

## Validator Status:
$(curl -s http://localhost:9000/eth/v1/beacon/states/head/validators | jq '.data | length')

EOF

    # Acciones según tipo de incidente
    case $incident_type in
        "beacon_down")
            handle_beacon_down
            ;;
        "validator_down")
            handle_validator_down
            ;;
        "sync_issues")
            handle_sync_issues
            ;;
        "slashing_risk")
            handle_slashing_risk
            ;;
        *)
            log "Tipo de incidente no reconocido: $incident_type"
            ;;
    esac
    
    # Notificar al equipo
    send_telegram_alert "Incident $INCIDENT_ID: $incident_type (${severity})" "$severity"
    
    log "Respuesta a incidente completada: $INCIDENT_ID"
}

handle_beacon_down() {
    log "Manejando beacon node caído..."
    
    # Intentar reiniciar beacon node
    docker-compose -f compose/gnosis.docker-compose.yml restart gnosis-beacon
    
    # Esperar y verificar
    sleep 30
    
    if curl -s http://localhost:9000/eth/v1/node/syncing > /dev/null; then
        log "Beacon node reiniciado exitosamente ✅"
    else
        error "Beacon node no pudo ser reiniciado"
        send_telegram_alert "CRITICAL: Gnosis beacon node failed to restart. Manual intervention required." "critical"
    fi
}

handle_validator_down() {
    log "Manejando validator caído..."
    
    # Intentar reiniciar validator
    docker-compose -f compose/gnosis.docker-compose.yml restart gnosis-validator
    
    # Esperar y verificar
    sleep 30
    
    if docker-compose -f compose/gnosis.docker-compose.yml ps gnosis-validator | grep -q "Up"; then
        log "Validator reiniciado exitosamente ✅"
    else
        error "Validator no pudo ser reiniciado"
        send_telegram_alert "CRITICAL: Gnosis validator failed to restart. Manual intervention required." "critical"
    fi
}

handle_sync_issues() {
    log "Manejando problemas de sincronización..."
    
    # Verificar checkpoint sync
    CHECKPOINT_SYNC=$(curl -s http://localhost:9000/eth/v1/node/syncing | jq -r '.data.is_syncing')
    
    if [ "$CHECKPOINT_SYNC" = "true" ]; then
        log "Nodo está sincronizando, esperando..."
        # Monitorear progreso
    else
        log "Problema de sincronización detectado, reiniciando..."
        docker-compose -f compose/gnosis.docker-compose.yml restart gnosis-beacon
    fi
}

handle_slashing_risk() {
    log "Manejando riesgo de slashing..."
    
    # Detener validadores inmediatamente
    docker-compose -f compose/gnosis.docker-compose.yml stop gnosis-validator
    
    # Notificar inmediatamente
    send_telegram_alert "CRITICAL: Slashing risk detected. Validators stopped immediately." "critical"
    
    # Investigar causa
    log "Investigando causa del slashing risk..."
    docker-compose -f compose/gnosis.docker-compose.yml logs gnosis-validator | tail -100
}
```

---

## Optimización y Performance

### 1. Tuning del Sistema para 108 Validadores

```bash
#!/bin/bash
# scripts/optimize_gnosis.sh

optimize_system() {
    log "Optimizando sistema para 108 validadores de Gnosis..."
    
    # Optimizar parámetros de red
    echo 'net.core.rmem_max = 268435456' >> /etc/sysctl.conf
    echo 'net.core.wmem_max = 268435456' >> /etc/sysctl.conf
    echo 'net.ipv4.tcp_rmem = 4096 131072 268435456' >> /etc/sysctl.conf
    echo 'net.ipv4.tcp_wmem = 4096 131072 268435456' >> /etc/sysctl.conf
    echo 'net.core.netdev_max_backlog = 5000' >> /etc/sysctl.conf
    
    # Aplicar cambios
    sysctl -p
    
    # Optimizar Docker para alta concurrencia
    cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 65536,
            "Soft": 65536
        }
    }
}
EOF
    
    systemctl restart docker
    
    log "Sistema optimizado para 108 validadores ✅"
}
```

---

## Checklist de Verificación

### Pre-Despliegue
- [ ] Hardware cumple requisitos (16+ cores, 64GB+ RAM, 4TB+ SSD)
- [ ] Sistema operativo actualizado
- [ ] Docker y Docker Compose instalados
- [ ] Variables de entorno configuradas
- [ ] Claves de validadores generadas e importadas
- [ ] Red y firewall configurados
- [ ] Backup de configuración existente

### Post-Despliegue
- [ ] Beacon node funcionando correctamente
- [ ] Validator funcionando correctamente
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

---

## Métricas de Éxito

### KPIs Institucionales
- **Uptime**: ≥ 99.9%
- **APR**: Optimizado vs. red
- **Slashing Events**: 0 eventos
- **Tiempo de Respuesta**: < 5 minutos para P0
- **Costos**: Tracking completo
- **Auditorías**: 100% de procesos auditados

### Métricas Técnicas
- **Beacon API Response Time**: < 100ms
- **Sync Distance**: < 2 bloques
- **Validator Performance**: > 95% attestations
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

*"Este playbook garantiza que cada despliegue de Gnosis en SEEDNodes cumple con estándares institucionales de seguridad, transparencia y continuidad, optimizado para 108 validadores."*

