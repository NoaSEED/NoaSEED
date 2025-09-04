#!/usr/bin/env bash
# SEED Ops - Starknet Incident Response Script
# Script de respuesta a incidentes para validador Starknet
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
readonly LOG_FILE="/var/log/starknet-incident.log"

# Directorios de incidentes
readonly INCIDENT_DIR="$STARKNET_HOME/incidents"
readonly DIAGNOSTICS_DIR="$INCIDENT_DIR/diagnostics"
readonly EMERGENCY_SCRIPTS_DIR="$INCIDENT_DIR/emergency"

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
            echo -e "${RED}[ERROR]${NC} $timestamp - $message" | tee -a "$message"
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

load_environment() {
    log_info "Cargando variables de entorno..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warn "Archivo de entorno no encontrado: $ENV_FILE"
        log_warn "Usando valores por defecto"
        return 0
    fi
    
    source "$ENV_FILE"
    log_info "Variables de entorno cargadas"
}

# =============================================================================
# FUNCIONES DE PREPARACIÓN
# =============================================================================

prepare_incident_directories() {
    log_info "Preparando directorios de incidentes..."
    
    local directories=(
        "$INCIDENT_DIR" "$DIAGNOSTICS_DIR" "$EMERGENCY_SCRIPTS_DIR"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Directorio creado: $dir"
        fi
        
        chown "$STARKNET_USER:$STARKNET_GROUP" "$dir"
        chmod 755 "$dir"
    done
    
    log_info "Directorios de incidentes preparados"
}

# =============================================================================
# FUNCIONES DE CLASIFICACIÓN
# =============================================================================

classify_incident() {
    local incident_type="$1"
    local severity="$2"
    
    case "$severity" in
        "critical"|"P1")
            log_error "🚨 INCIDENTE CRÍTICO (P1) - $incident_type"
            log_error "Tiempo de respuesta: < 15 minutos"
            log_error "Escalación: Automática a on-call"
            ;;
        "high"|"P2")
            log_warn "⚠️  INCIDENTE ALTO (P2) - $incident_type"
            log_warn "Tiempo de respuesta: < 1 hora"
            log_warn "Escalación: Manual si persiste > 2 horas"
            ;;
        "medium"|"P3")
            log_info "ℹ️  INCIDENTE MEDIO (P3) - $incident_type"
            log_info "Tiempo de respuesta: < 4 horas"
            log_info "Escalación: Solo si es recurrente"
            ;;
        *)
            log_info "ℹ️  INCIDENTE BAJO (P4) - $incident_type"
            log_info "Tiempo de respuesta: < 24 horas"
            ;;
    esac
    
    # Crear archivo de incidente
    local incident_file="$INCIDENT_DIR/incident-$(date +%Y%m%d_%H%M%S).log"
    cat > "$incident_file" << EOF
# Incidente Starknet - $(date '+%Y-%m-%d %H:%M:%S')
# Tipo: $incident_type
# Severidad: $severity
# Script: $SCRIPT_NAME

## Clasificación
- Tipo: $incident_type
- Severidad: $severity
- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Hostname: $(hostname)

## Acciones Tomadas
- Script de incidente ejecutado
- Diagnósticos recolectados
- Procedimientos de emergencia activados

## Próximos Pasos
- Revisar diagnósticos en: $DIAGNOSTICS_DIR
- Aplicar mitigaciones según severidad
- Documentar resolución
- Actualizar runbook si es necesario
EOF
    
    chown "$STARKNET_USER:$STARKNET_GROUP" "$incident_file"
    chmod 644 "$incident_file"
    
    log_info "Archivo de incidente creado: $incident_file"
}

# =============================================================================
# FUNCIONES DE DIAGNÓSTICO
# =============================================================================

collect_diagnostics() {
    local incident_id="$(date +%Y%m%d_%H%M%S)"
    local diagnostic_dir="$DIAGNOSTICS_DIR/incident-$incident_id"
    
    log_info "Recolectando diagnósticos del sistema..."
    
    mkdir -p "$diagnostic_dir"
    
    # Información del sistema
    collect_system_info "$diagnostic_dir"
    
    # Información de Docker
    collect_docker_info "$diagnostic_dir"
    
    # Información de red
    collect_network_info "$diagnostic_dir"
    
    # Logs del sistema
    collect_system_logs "$diagnostic_dir"
    
    # Logs de Starknet
    collect_starknet_logs "$diagnostic_dir"
    
    # Estado de servicios
    collect_service_status "$diagnostic_dir"
    
    # Métricas del sistema
    collect_system_metrics "$diagnostic_dir"
    
    # Crear resumen de diagnósticos
    create_diagnostic_summary "$diagnostic_dir"
    
    log_info "Diagnósticos recolectados en: $diagnostic_dir"
}

collect_system_info() {
    local dir="$1"
    
    log_info "Recolectando información del sistema..."
    
    # Información básica del sistema
    uname -a > "$dir/system-uname.txt" 2>/dev/null || true
    cat /etc/os-release > "$dir/system-os-release.txt" 2>/dev/null || true
    uptime > "$dir/system-uptime.txt" 2>/dev/null || true
    
    # Uso de recursos
    df -h > "$dir/system-disk-usage.txt" 2>/dev/null || true
    free -h > "$dir/system-memory-usage.txt" 2>/dev/null || true
    top -bn1 > "$dir/system-top.txt" 2>/dev/null || true
    
    # Procesos del sistema
    ps aux > "$dir/system-processes.txt" 2>/dev/null || true
    ps aux | grep -E "(starknet|docker)" > "$dir/system-starknet-processes.txt" 2>/dev/null || true
}

collect_docker_info() {
    local dir="$1"
    
    log_info "Recolectando información de Docker..."
    
    # Estado de contenedores
    docker ps -a > "$dir/docker-containers.txt" 2>/dev/null || true
    docker images > "$dir/docker-images.txt" 2>/dev/null || true
    
    # Logs de contenedores
    if docker ps -q | grep -q .; then
        docker logs --tail=500 $(docker ps -q | head -1) > "$dir/docker-logs.txt" 2>/dev/null || true
    fi
    
    # Estadísticas de contenedores
    docker stats --no-stream > "$dir/docker-stats.txt" 2>/dev/null || true
    
    # Información del sistema Docker
    docker system df > "$dir/docker-system-df.txt" 2>/dev/null || true
    docker info > "$dir/docker-info.txt" 2>/dev/null || true
}

collect_network_info() {
    local dir="$1"
    
    log_info "Recolectando información de red..."
    
    # Interfaces de red
    ip addr > "$dir/network-interfaces.txt" 2>/dev/null || true
    ip route > "$dir/network-routes.txt" 2>/dev/null || true
    
    # Puertos en uso
    ss -lntup > "$dir/network-ports.txt" 2>/dev/null || true
    netstat -tlnp > "$dir/network-netstat.txt" 2>/dev/null || true
    
    # Conectividad
    ping -c 3 8.8.8.8 > "$dir/network-ping.txt" 2>/dev/null || true
    nslookup google.com > "$dir/network-dns.txt" 2>/dev/null || true
    
    # Firewall
    ufw status > "$dir/network-ufw.txt" 2>/dev/null || true
    iptables -L > "$dir/network-iptables.txt" 2>/dev/null || true
}

collect_system_logs() {
    local dir="$1"
    
    log_info "Recolectando logs del sistema..."
    
    # Logs del sistema
    journalctl --since="1 hour ago" > "$dir/system-journal.txt" 2>/dev/null || true
    tail -1000 /var/log/syslog > "$dir/system-syslog.txt" 2>/dev/null || true
    tail -1000 /var/log/auth.log > "$dir/system-auth.txt" 2>/dev/null || true
    
    # Logs de Docker
    journalctl -u docker --since="1 hour ago" > "$dir/docker-service.txt" 2>/dev/null || true
    
    # Logs de servicios críticos
    for service in ssh ufw fail2ban; do
        if systemctl is-active --quiet "$service"; then
            journalctl -u "$service" --since="1 hour ago" > "$dir/service-$service.txt" 2>/dev/null || true
        fi
    done
}

collect_starknet_logs() {
    local dir="$1"
    
    log_info "Recolectando logs de Starknet..."
    
    # Logs de Starknet
    if [[ -d "$STARKNET_HOME/logs" ]]; then
        find "$STARKNET_HOME/logs" -name "*.log" -exec tail -1000 {} \; > "$dir/starknet-logs.txt" 2>/dev/null || true
    fi
    
    # Logs del script
    if [[ -f "$LOG_FILE" ]]; then
        tail -1000 "$LOG_FILE" > "$dir/starknet-script-logs.txt" 2>/dev/null || true
    fi
    
    # Estado del validador
    if [[ -f "$PROJECT_ROOT/compose/starknet.docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        docker compose ps > "$dir/starknet-compose-status.txt" 2>/dev/null || true
        docker compose logs --tail=200 > "$dir/starknet-compose-logs.txt" 2>/dev/null || true
    fi
}

collect_service_status() {
    local dir="$1"
    
    log_info "Recolectando estado de servicios..."
    
    # Estado de servicios críticos
    local critical_services=("docker" "ssh" "ufw" "fail2ban" "rsyslog")
    
    for service in "${critical_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            systemctl status "$service" > "$dir/service-$service-status.txt" 2>/dev/null || true
            systemctl is-active "$service" > "$dir/service-$service-active.txt" 2>/dev/null || true
        fi
    done
    
    # Estado de cron
    crontab -l > "$dir/system-crontab.txt" 2>/dev/null || true
    
    # Estado de monitoreo
    if [[ -d "$STARKNET_HOME/monitoring" ]]; then
        cd "$STARKNET_HOME/monitoring"
        docker compose ps > "$dir/monitoring-status.txt" 2>/dev/null || true
    fi
}

collect_system_metrics() {
    local dir="$1"
    
    log_info "Recolectando métricas del sistema..."
    
    # Métricas básicas
    vmstat 1 5 > "$dir/system-vmstat.txt" 2>/dev/null || true
    iostat 1 5 > "$dir/system-iostat.txt" 2>/dev/null || true
    
    # Información de memoria
    cat /proc/meminfo > "$dir/system-meminfo.txt" 2>/dev/null || true
    cat /proc/loadavg > "$dir/system-loadavg.txt" 2>/dev/null || true
    
    # Información de CPU
    cat /proc/cpuinfo > "$dir/system-cpuinfo.txt" 2>/dev/null || true
    cat /proc/stat > "$dir/system-stat.txt" 2>/dev/null || true
    
    # Información de disco
    cat /proc/diskstats > "$dir/system-diskstats.txt" 2>/dev/null || true
    iostat -x 1 5 > "$dir/system-iostat-detailed.txt" 2>/dev/null || true
}

create_diagnostic_summary() {
    local dir="$1"
    
    log_info "Creando resumen de diagnósticos..."
    
    local summary_file="$dir/diagnostic-summary.txt"
    
    cat > "$summary_file" << EOF
# Resumen de Diagnósticos - Incidente Starknet
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')
# Directorio: $dir

## Archivos Recolectados
$(find "$dir" -type f -name "*.txt" | sort | sed 's|.*/||' | sed 's/^/- /')

## Estado del Sistema
- Uptime: $(uptime | awk -F'up' '{print $2}' | awk '{print $1}' 2>/dev/null || echo "N/A")
- Carga del sistema: $(cat /proc/loadavg 2>/dev/null || echo "N/A")
- Memoria disponible: $(free -h | awk 'NR==2{print $7}' 2>/dev/null || echo "N/A")
- Espacio en disco: $(df -h / | awk 'NR==2{print $4}' 2>/dev/null || echo "N/A")

## Estado de Docker
- Contenedores corriendo: $(docker ps -q | wc -l 2>/dev/null || echo "0")
- Imágenes disponibles: $(docker images -q | wc -l 2>/dev/null || echo "0")

## Estado de Servicios
$(for service in docker ssh ufw fail2ban; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo "- $service: $(systemctl is-active "$service" 2>/dev/null || echo "unknown")"
    fi
done)

## Próximos Pasos
1. Revisar archivos de diagnóstico
2. Identificar causa raíz del incidente
3. Aplicar mitigaciones apropiadas
4. Documentar resolución
5. Actualizar procedimientos si es necesario

## Notas
- Todos los archivos están en formato texto para fácil revisión
- Usar 'grep' para buscar patrones específicos
- Comparar con estado normal del sistema
EOF
    
    log_info "Resumen de diagnósticos creado: $summary_file"
}

# =============================================================================
# FUNCIONES DE MITIGACIÓN
# =============================================================================

apply_emergency_mitigation() {
    local incident_type="$1"
    local severity="$2"
    
    log_info "Aplicando mitigaciones de emergencia..."
    
    case "$incident_type" in
        "service_down"|"container_down")
            mitigate_service_down
            ;;
        "high_resource_usage")
            mitigate_high_resource_usage
            ;;
        "network_issue")
            mitigate_network_issue
            ;;
        "security_breach")
            mitigate_security_breach
            ;;
        *)
            log_warn "Tipo de incidente no reconocido: $incident_type"
            log_warn "Aplicando mitigaciones genéricas"
            apply_generic_mitigation
            ;;
    esac
}

mitigate_service_down() {
    log_info "Mitigando servicio caído..."
    
    # Reiniciar Docker si es necesario
    if ! systemctl is-active --quiet docker; then
        log_warn "Docker no está activo, reiniciando..."
        systemctl restart docker
        sleep 10
    fi
    
    # Reiniciar contenedores de Starknet
    if [[ -f "$PROJECT_ROOT/compose/starknet.docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        log_info "Reiniciando contenedores de Starknet..."
        docker compose restart
    fi
    
    # Verificar estado después de mitigación
    sleep 30
    if [[ -f "$PROJECT_ROOT/compose/starknet.docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        docker compose ps
    fi
}

mitigate_high_resource_usage() {
    log_info "Mitigando alto uso de recursos..."
    
    # Limpiar logs antiguos
    log_info "Limpiando logs antiguos..."
    find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
    find "$STARKNET_HOME/logs" -name "*.log.*" -mtime +3 -delete 2>/dev/null || true
    
    # Limpiar contenedores Docker no utilizados
    log_info "Limpiando contenedores Docker no utilizados..."
    docker container prune -f >/dev/null 2>&1 || true
    docker image prune -f >/dev/null 2>&1 || true
    
    # Reiniciar servicios críticos si es necesario
    if [[ $(cat /proc/loadavg | awk '{print $1}') -gt 10 ]]; then
        log_warn "Carga del sistema muy alta, reiniciando servicios críticos..."
        systemctl restart rsyslog
        systemctl restart fail2ban
    fi
}

mitigate_network_issue() {
    log_info "Mitigando problemas de red..."
    
    # Verificar y reiniciar interfaces de red
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_warn "Sin conectividad a internet, verificando interfaces..."
        ip link show
        systemctl restart networking
    fi
    
    # Verificar firewall
    if ! ufw status | grep -q "Status: active"; then
        log_warn "UFW no está activo, habilitando..."
        ufw --force enable
    fi
    
    # Verificar puertos críticos
    local critical_ports=("22" "9545" "9546" "9100")
    for port in "${critical_ports[@]}"; do
        if ! ss -lnt | grep -q ":$port "; then
            log_warn "Puerto crítico $port no está escuchando"
        fi
    done
}

mitigate_security_breach() {
    log_info "Mitigando brecha de seguridad..."
    
    # Bloquear acceso SSH temporalmente
    log_warn "Bloqueando acceso SSH temporalmente..."
    ufw deny 22/tcp
    
    # Verificar procesos sospechosos
    log_info "Verificando procesos sospechosos..."
    ps aux | grep -E "(ssh|sshd)" > /tmp/suspicious-processes.txt
    
    # Verificar conexiones de red activas
    log_info "Verificando conexiones de red activas..."
    ss -tuln > /tmp/active-connections.txt
    
    # Verificar logs de autenticación
    log_info "Verificando logs de autenticación..."
    tail -1000 /var/log/auth.log | grep -E "(Failed|Invalid|Failed password)" > /tmp/auth-failures.txt
    
    log_warn "Acceso SSH bloqueado. Revisar archivos de diagnóstico antes de desbloquear"
}

apply_generic_mitigation() {
    log_info "Aplicando mitigaciones genéricas..."
    
    # Reiniciar servicios críticos
    for service in docker rsyslog fail2ban; do
        if systemctl is-active --quiet "$service"; then
            log_info "Reiniciando $service..."
            systemctl restart "$service"
        fi
    done
    
    # Limpiar recursos del sistema
    log_info "Limpiando recursos del sistema..."
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    # Verificar estado general
    log_info "Verificando estado general del sistema..."
    systemctl status docker ssh ufw fail2ban
}

# =============================================================================
# FUNCIONES DE NOTIFICACIÓN
# =============================================================================

notify_incident_team() {
    local incident_type="$1"
    local severity="$2"
    local diagnostic_dir="$3"
    
    log_info "Notificando al equipo de incidentes..."
    
    # Crear mensaje de notificación
    local notification_file="$INCIDENT_DIR/notification-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$notification_file" << EOF
🚨 INCIDENTE STARKNET DETECTADO

📋 Detalles:
- Tipo: $incident_type
- Severidad: $severity
- Timestamp: $(date '+%Y-%m-%d %H:%M:%S UTC')
- Hostname: $(hostname)
- IP: $(hostname -I | awk '{print $1}')

🔍 Diagnósticos:
- Directorio: $diagnostic_dir
- Archivos: $(find "$diagnostic_dir" -type f | wc -l)

📊 Estado del Sistema:
- Uptime: $(uptime | awk -F'up' '{print $2}' | awk '{print $1}' 2>/dev/null || echo "N/A")
- Carga: $(cat /proc/loadavg 2>/dev/null || echo "N/A")
- Memoria: $(free -h | awk 'NR==2{print $7}' 2>/dev/null || echo "N/A")

⚠️  Acciones Requeridas:
1. Revisar diagnósticos en: $diagnostic_dir
2. Evaluar severidad y escalar si es necesario
3. Aplicar mitigaciones apropiadas
4. Documentar acciones tomadas
5. Actualizar estado del incidente

🔗 Acceso:
- SSH: ssh -p ${SSH_PORT:-22} $STARKNET_USER@$(hostname -I | awk '{print $1}')
- Logs: $LOG_FILE
- Diagnósticos: $diagnostic_dir

📞 Escalación:
- P1 (Crítico): On-call inmediato
- P2 (Alto): On-call en 1 hora
- P3 (Medio): Equipo en 4 horas
- P4 (Bajo): Revisión diaria

---
Generado automáticamente por $SCRIPT_NAME
EOF
    
    chown "$STARKNET_USER:$STARKNET_GROUP" "$notification_file"
    chmod 644 "$notification_file"
    
    log_info "Notificación creada: $notification_file"
    
    # Mostrar checklist para el canal de incidentes
    show_incident_checklist "$incident_type" "$severity" "$diagnostic_dir"
}

show_incident_checklist() {
    local incident_type="$1"
    local severity="$2"
    local diagnostic_dir="$3"
    
    log_info "📋 CHECKLIST PARA CANAL #incidentes:"
    echo ""
    echo "🚨 INCIDENTE STARKNET - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "📋 Tipo: $incident_type | Severidad: $severidad"
    echo ""
    echo "📎 ADJUNTAR:"
    echo "  ✅ Archivo de incidente: $INCIDENT_DIR/incident-*.log"
    echo "  ✅ Resumen de diagnósticos: $diagnostic_dir/diagnostic-summary.txt"
    echo "  ✅ Logs del sistema: $diagnostic_dir/system-*.txt"
    echo "  ✅ Estado de Docker: $diagnostic_dir/docker-*.txt"
    echo "  ✅ Estado de red: $diagnostic_dir/network-*.txt"
    echo ""
    echo "🔍 VERIFICAR:"
    echo "  ✅ Estado de servicios críticos"
    echo "  ✅ Uso de recursos del sistema"
    echo "  ✅ Conectividad de red"
    echo "  ✅ Logs de errores recientes"
    echo "  ✅ Estado de contenedores"
    echo ""
    echo "📊 MÉTRICAS CLAVE:"
    echo "  ✅ Uptime del sistema"
    echo "  ✅ Carga del sistema (load average)"
    echo "  ✅ Uso de memoria y disco"
    echo "  ✅ Estado de puertos críticos"
    echo "  ✅ Estado de firewall"
    echo ""
    echo "⚠️  ACCIONES INMEDIATAS:"
    echo "  ✅ Notificar al equipo on-call"
    echo "  ✅ Evaluar impacto en usuarios"
    echo "  ✅ Aplicar mitigaciones básicas"
    echo "  ✅ Documentar acciones tomadas"
    echo "  ✅ Establecer timeline de resolución"
    echo ""
    echo "📞 ESCALACIÓN:"
    case "$severity" in
        "critical"|"P1")
            echo "  🚨 ESCALAR INMEDIATAMENTE a on-call"
            echo "  🚨 Notificar a stakeholders críticos"
            ;;
        "high"|"P2")
            echo "  ⚠️  Escalar en 1 hora si no se resuelve"
            ;;
        "medium"|"P3")
            echo "  ℹ️  Revisar en 4 horas"
            ;;
        *)
            echo "  ℹ️  Revisar en 24 horas"
            ;;
    esac
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log_info "=== Iniciando script de respuesta a incidentes de Starknet ==="
    log_info "Script: $SCRIPT_NAME"
    log_info "Directorio: $SCRIPT_DIR"
    log_info "Archivo de entorno: $ENV_FILE"
    
    # Verificaciones previas
    check_root
    check_user_exists
    load_environment
    
    # Preparación
    prepare_incident_directories
    
    # Procesar argumentos
    local incident_type="${1:-unknown}"
    local severity="${2:-medium}"
    local action="${3:-collect}"
    
    # Clasificar incidente
    classify_incident "$incident_type" "$severity"
    
    # Recolectar diagnósticos
    collect_diagnostics
    local diagnostic_dir="$DIAGNOSTICS_DIR/incident-$(date +%Y%m%d_%H%M%S)"
    
    # Aplicar mitigaciones si se solicita
    case "$action" in
        "mitigate")
            apply_emergency_mitigation "$incident_type" "$severity"
            ;;
        "restart")
            log_info "Reiniciando servicios de Starknet..."
            if [[ -f "$PROJECT_ROOT/compose/starknet.docker-compose.yml" ]]; then
                cd "$PROJECT_ROOT"
                docker compose restart
            fi
            ;;
        *)
            log_info "Solo recolectando diagnósticos (no mitigación)"
            ;;
    esac
    
    # Notificar al equipo
    notify_incident_team "$incident_type" "$severity" "$diagnostic_dir"
    
    log_info "=== Script de respuesta a incidentes completado ===""
    log_info "Próximos pasos:"
    log_info "1. Revisar diagnósticos en: $diagnostic_dir"
    log_info "2. Evaluar severidad y escalar si es necesario"
    log_info "3. Aplicar mitigaciones apropiadas"
    log_info "4. Documentar resolución del incidente"
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
