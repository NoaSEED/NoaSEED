#!/usr/bin/env bash
# SEED Ops - Starknet Security Hardening Script
# Script de hardening de seguridad para validador Starknet
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
readonly LOG_FILE="/var/log/starknet-hardening.log"

# Puertos por defecto (se pueden sobrescribir con variables de entorno)
readonly SSH_PORT="${SSH_PORT:-2222}"
readonly RPC_PORT="${RPC_PORT:-9545}"
readonly P2P_PORT="${P2P_PORT:-9546}"
readonly METRICS_PORT="${METRICS_PORT:-9100}"

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

load_environment() {
    log_info "Cargando variables de entorno..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warn "Archivo de entorno no encontrado: $ENV_FILE"
        log_warn "Usando valores por defecto"
        return 0
    fi
    
    # Cargar variables críticas
    source "$ENV_FILE"
    
    # Validar variables críticas
    local critical_vars=("SSH_PORT" "RPC_PORT" "P2P_PORT" "METRICS_PORT")
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

check_prerequisites() {
    log_info "Verificando prerrequisitos..."
    
    # Verificar comandos requeridos
    local required_commands=("ufw" "sshd" "systemctl")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Comando requerido no encontrado: $cmd"
            exit 1
        fi
    done
    
    # Verificar que UFW esté disponible
    if ! ufw version >/dev/null 2>&1; then
        log_error "UFW no está disponible. Instalar con: apt install ufw"
        exit 1
    fi
    
    log_info "Prerrequisitos verificados"
}

# =============================================================================
# FUNCIONES DE FIREWALL
# =============================================================================

configure_firewall() {
    log_info "Configurando firewall UFW..."
    
    # Verificar si UFW ya está configurado
    if ufw status | grep -q "Status: active"; then
        log_info "UFW ya está activo, verificando configuración..."
    else
        log_info "Activando UFW..."
        ufw --force enable
    fi
    
    # Configurar política por defecto
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH en puerto configurado
    if ufw status | grep -q "$SSH_PORT/tcp"; then
        log_info "Regla SSH para puerto $SSH_PORT ya existe"
    else
        ufw allow "$SSH_PORT/tcp" comment "SSH access"
        log_info "Regla SSH agregada para puerto $SSH_PORT"
    fi
    
    # Permitir puerto P2P de Starknet
    if ufw status | grep -q "$P2P_PORT/tcp"; then
        log_info "Regla P2P para puerto $P2P_PORT ya existe"
    else
        ufw allow "$P2P_PORT/tcp" comment "Starknet P2P"
        log_info "Regla P2P agregada para puerto $P2P_PORT"
    fi
    
    # Permitir puerto RPC de Starknet (si está habilitado)
    if [[ "${ENABLE_RPC:-true}" == "true" ]]; then
        if ufw status | grep -q "$RPC_PORT/tcp"; then
            log_info "Regla RPC para puerto $RPC_PORT ya existe"
        else
            ufw allow "$RPC_PORT/tcp" comment "Starknet RPC"
            log_info "Regla RPC agregada para puerto $RPC_PORT"
        fi
    else
        log_info "RPC deshabilitado, no se agrega regla de firewall"
    fi
    
    # Permitir puerto de métricas (si está habilitado)
    if [[ "${ENABLE_METRICS:-true}" == "true" ]]; then
        if ufw status | grep -q "$METRICS_PORT/tcp"; then
            log_info "Regla de métricas para puerto $METRICS_PORT ya existe"
        else
            ufw allow "$METRICS_PORT/tcp" comment "Node Exporter metrics"
            log_info "Regla de métricas agregada para puerto $METRICS_PORT"
        fi
    else
        log_info "Métricas deshabilitadas, no se agrega regla de firewall"
    fi
    
    # Permitir loopback
    ufw allow in on lo
    ufw allow out on lo
    
    log_info "Firewall UFW configurado correctamente"
}

# =============================================================================
# FUNCIONES DE SSH
# =============================================================================

harden_ssh() {
    log_info "Configurando hardening de SSH..."
    
    local sshd_config="/etc/ssh/sshd_config"
    local sshd_config_backup="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Crear backup de la configuración actual
    if [[ ! -f "$sshd_config_backup" ]]; then
        cp "$sshd_config" "$sshd_config_backup"
        log_info "Backup de configuración SSH creado: $sshd_config_backup"
    fi
    
    # Cambiar puerto SSH
    if grep -q "^Port " "$sshd_config"; then
        sed -i "s/^Port .*/Port $SSH_PORT/" "$sshd_config"
        log_info "Puerto SSH cambiado a $SSH_PORT"
    else
        echo "Port $SSH_PORT" >> "$sshd_config"
        log_info "Puerto SSH configurado a $SSH_PORT"
    fi
    
    # Deshabilitar autenticación por contraseña
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$sshd_config"
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$sshd_config"
    
    # Configuraciones adicionales de seguridad
    echo "Protocol 2" >> "$sshd_config"
    echo "MaxAuthTries 3" >> "$sshd_config"
    echo "MaxSessions 2" >> "$sshd_config"
    echo "ClientAliveInterval 300" >> "$sshd_config"
    echo "ClientAliveCountMax 2" >> "$sshd_config"
    echo "AllowUsers $STARKNET_USER" >> "$sshd_config"
    
    log_info "Configuración SSH hardened"
    
    # Reiniciar SSH de forma segura
    restart_ssh_safely
}

restart_ssh_safely() {
    log_info "Reiniciando SSH de forma segura..."
    
    # Verificar configuración antes de reiniciar
    if sshd -t; then
        log_info "Configuración SSH válida, reiniciando servicio..."
        
        # Detectar sistema de init
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart ssh
            log_info "SSH reiniciado con systemctl"
        else
            service ssh restart
            log_info "SSH reiniciado con service"
        fi
        
        # Verificar que SSH esté funcionando
        sleep 5
        if ss -lnt | grep -q ":$SSH_PORT "; then
            log_info "SSH reiniciado exitosamente en puerto $SSH_PORT"
        else
            log_error "SSH no está funcionando después del reinicio"
            exit 1
        fi
    else
        log_error "Configuración SSH inválida, no se reinicia el servicio"
        exit 1
    fi
}

# =============================================================================
# FUNCIONES DE FAIL2BAN
# =============================================================================

configure_fail2ban() {
    if [[ "${ENABLE_FAIL2BAN:-true}" != "true" ]]; then
        log_info "Fail2ban deshabilitado por configuración"
        return 0
    fi
    
    log_info "Configurando Fail2ban..."
    
    # Instalar Fail2ban si no está disponible
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log_info "Instalando Fail2ban..."
        apt update && apt install -y fail2ban
    fi
    
    # Crear configuración personalizada
    local fail2ban_config="/etc/fail2ban/jail.local"
    
    if [[ ! -f "$fail2ban_config" ]]; then
        cat > "$fail2ban_config" << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = auto

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

[starknet-rpc]
enabled = true
port = $RPC_PORT
filter = starknet
logpath = /var/log/starknet.log
maxretry = 5
bantime = 1800
findtime = 300
EOF
        log_info "Configuración de Fail2ban creada"
    else
        log_info "Configuración de Fail2ban ya existe"
    fi
    
    # Crear filtro personalizado para Starknet
    local filter_file="/etc/fail2ban/filter.d/starknet.conf"
    
    if [[ ! -f "$filter_file" ]]; then
        cat > "$filter_file" << EOF
[Definition]
failregex = ^.*Failed RPC request from <HOST>.*$
            ^.*Invalid request from <HOST>.*$
ignoreregex =
EOF
        log_info "Filtro de Fail2ban para Starknet creado"
    fi
    
    # Habilitar y reiniciar Fail2ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_info "Fail2ban configurado y habilitado"
}

# =============================================================================
# FUNCIONES DE AUDITORÍA
# =============================================================================

configure_auditd() {
    log_info "Configurando auditoría del sistema..."
    
    # Instalar auditd si no está disponible
    if ! command -v auditctl >/dev/null 2>&1; then
        log_info "Instalando auditd..."
        apt update && apt install -y auditd audispd-plugins
    fi
    
    # Configurar reglas de auditoría
    local audit_rules="/etc/audit/rules.d/starknet.rules"
    
    if [[ ! -f "$audit_rules" ]]; then
        cat > "$audit_rules" << EOF
# Reglas de auditoría para Starknet
-w /opt/starknet/keys -p wa -k starknet_keys
-w /opt/starknet/config -p wa -k starknet_config
-w /opt/starknet/data -p wa -k starknet_data
-w /var/log/starknet.log -p wa -k starknet_logs
-a always,exit -F arch=b64 -S connect -k network_connect
-a always,exit -F arch=b64 -S bind -k network_bind
EOF
        log_info "Reglas de auditoría creadas"
    else
        log_info "Reglas de auditoría ya existen"
    fi
    
    # Habilitar y reiniciar auditd
    systemctl enable auditd
    systemctl restart auditd
    
    log_info "Auditoría del sistema configurada"
}

# =============================================================================
# FUNCIONES DE LÍMITES DEL SISTEMA
# =============================================================================

configure_system_limits() {
    log_info "Configurando límites del sistema..."
    
    local limits_conf="/etc/security/limits.d/starknet.conf"
    
    if [[ ! -f "$limits_conf" ]]; then
        cat > "$limits_conf" << EOF
# Límites para usuario Starknet
starknet soft nofile 65536
starknet hard nofile 65536
starknet soft nproc 32768
starknet hard nproc 32768
starknet soft memlock unlimited
starknet hard memlock unlimited
EOF
        log_info "Límites del sistema configurados"
    else
        log_info "Límites del sistema ya configurados"
    fi
    
    # Configurar parámetros del kernel
    local sysctl_conf="/etc/sysctl.d/99-starknet.conf"
    
    if [[ ! -f "$sysctl_conf" ]]; then
        cat > "$sysctl_conf" << EOF
# Parámetros del kernel para Starknet
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
EOF
        log_info "Parámetros del kernel configurados"
    else
        log_info "Parámetros del kernel ya configurados"
    fi
    
    # Aplicar cambios
    sysctl -p "$sysctl_conf"
    
    log_info "Límites del sistema aplicados"
}

# =============================================================================
# FUNCIONES DE VERIFICACIÓN
# =============================================================================

verify_hardening() {
    log_info "Verificando configuración de hardening..."
    
    local errors=0
    
    # Verificar UFW
    if ufw status | grep -q "Status: active"; then
        log_info "✅ UFW está activo"
    else
        log_error "❌ UFW no está activo"
        ((errors++))
    fi
    
    # Verificar puerto SSH
    if ss -lnt | grep -q ":$SSH_PORT "; then
        log_info "✅ SSH escuchando en puerto $SSH_PORT"
    else
        log_error "❌ SSH no está escuchando en puerto $SSH_PORT"
        ((errors++))
    fi
    
    # Verificar reglas de firewall
    if ufw status | grep -q "$SSH_PORT/tcp"; then
        log_info "✅ Regla SSH en UFW"
    else
        log_error "❌ Regla SSH no encontrada en UFW"
        ((errors++))
    fi
    
    # Verificar Fail2ban
    if [[ "${ENABLE_FAIL2BAN:-true}" == "true" ]]; then
        if systemctl is-active --quiet fail2ban; then
            log_info "✅ Fail2ban está activo"
        else
            log_error "❌ Fail2ban no está activo"
            ((errors++))
        fi
    fi
    
    # Verificar auditoría
    if systemctl is-active --quiet auditd; then
        log_info "✅ Auditoría del sistema activa"
    else
        log_error "❌ Auditoría del sistema no está activa"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_info "✅ Hardening verificado exitosamente"
        return 0
    else
        log_error "❌ Se encontraron $errors errores en el hardening"
        return 1
    fi
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log_info "=== Iniciando hardening de seguridad de Starknet ==="
    log_info "Script: $SCRIPT_NAME"
    log_info "Directorio: $SCRIPT_DIR"
    log_info "Archivo de entorno: $ENV_FILE"
    
    # Verificaciones previas
    check_root
    load_environment
    check_prerequisites
    
    # Configuración de seguridad
    configure_firewall
    harden_ssh
    configure_fail2ban
    configure_auditd
    configure_system_limits
    
    # Verificación final
    if verify_hardening; then
        log_info "=== Hardening de seguridad completado exitosamente ==="
        log_info "Próximos pasos:"
        log_info "1. Verificar acceso SSH en puerto $SSH_PORT"
        log_info "2. Ejecutar: make deploy"
        log_info "3. Ejecutar: make monitor"
    else
        log_error "=== Hardening de seguridad falló ==="
        exit 1
    fi
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
