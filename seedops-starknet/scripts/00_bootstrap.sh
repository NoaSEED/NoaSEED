#!/usr/bin/env bash
# SEED Ops - Starknet Bootstrap Script
# Script de preparación del servidor para validador Starknet
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
readonly LOG_FILE="/var/log/starknet-bootstrap.log"

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

check_supported_os() {
    log_info "Verificando sistema operativo..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "No se puede determinar la distribución del sistema"
        exit 1
    fi
    
    source /etc/os-release
    
    case "$ID" in
        "ubuntu"|"debian")
            log_info "Sistema soportado: $PRETTY_NAME"
            readonly PACKAGE_MANAGER="apt"
            readonly UPDATE_CMD="apt update"
            readonly INSTALL_CMD="apt install -y"
            ;;
        *)
            log_error "Sistema operativo no soportado: $PRETTY_NAME"
            log_error "Solo se soportan Ubuntu y Debian"
            exit 1
            ;;
    esac
}

check_connectivity() {
    log_info "Verificando conectividad de red..."
    
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_error "No hay conectividad a internet"
        exit 1
    fi
    
    log_info "Conectividad verificada"
}

check_disk_space() {
    log_info "Verificando espacio en disco..."
    
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB en KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Espacio insuficiente en disco. Disponible: ${available_space}KB, Requerido: ${required_space}KB"
        exit 1
    fi
    
    log_info "Espacio en disco suficiente: ${available_space}KB disponibles"
}

check_ports() {
    log_info "Verificando puertos críticos..."
    
    local ports=("22" "80" "443" "9545" "9546" "9100")
    
    for port in "${ports[@]}"; do
        if ss -lnt | grep -q ":$port "; then
            log_warn "Puerto $port ya está en uso"
        else
            log_info "Puerto $port disponible"
        fi
    done
}

# =============================================================================
# FUNCIONES DE INSTALACIÓN
# =============================================================================

update_system() {
    log_info "Actualizando sistema..."
    
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        $UPDATE_CMD
        $INSTALL_CMD apt-transport-https ca-certificates gnupg lsb-release
    fi
    
    log_info "Sistema actualizado"
}

install_dependencies() {
    log_info "Instalando dependencias del sistema..."
    
    local packages=(
        "curl" "wget" "git" "ufw" "htop" "jq" "build-essential"
        "software-properties-common" "apt-transport-https"
    )
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            log_info "Paquete $package ya instalado"
        else
            log_info "Instalando $package..."
            $INSTALL_CMD "$package"
        fi
    done
    
    log_info "Dependencias del sistema instaladas"
}

install_docker() {
    log_info "Instalando Docker..."
    
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker ya está instalado"
        return 0
    fi
    
    # Agregar repositorio oficial de Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    $UPDATE_CMD
    $INSTALL_CMD docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Habilitar y arrancar Docker
    systemctl enable docker
    systemctl start docker
    
    log_info "Docker instalado y habilitado"
}

install_docker_compose() {
    log_info "Verificando Docker Compose..."
    
    if docker compose version >/dev/null 2>&1; then
        log_info "Docker Compose plugin ya está disponible"
        return 0
    fi
    
    # Instalar Docker Compose standalone si no está disponible el plugin
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_info "Instalando Docker Compose standalone..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    
    log_info "Docker Compose disponible"
}

# =============================================================================
# FUNCIONES DE USUARIO Y DIRECTORIOS
# =============================================================================

create_starknet_user() {
    log_info "Creando usuario y grupo para Starknet..."
    
    # Crear grupo si no existe
    if ! getent group "$STARKNET_GROUP" >/dev/null 2>&1; then
        groupadd "$STARKNET_GROUP"
        log_info "Grupo $STARKNET_GROUP creado"
    else
        log_info "Grupo $STARKNET_GROUP ya existe"
    fi
    
    # Crear usuario si no existe
    if ! getent passwd "$STARKNET_USER" >/dev/null 2>&1; then
        useradd -r -s /bin/bash -g "$STARKNET_GROUP" -d "$STARKNET_HOME" "$STARKNET_USER"
        log_info "Usuario $STARKNET_USER creado"
    else
        log_info "Usuario $STARKNET_USER ya existe"
    fi
    
    # Agregar usuario al grupo docker
    usermod -aG docker "$STARKNET_USER"
    log_info "Usuario $STARKNET_USER agregado al grupo docker"
}

create_directories() {
    log_info "Creando directorios de trabajo..."
    
    local directories=(
        "$STARKNET_HOME"
        "$STARKNET_HOME/config"
        "$STARKNET_HOME/data"
        "$STARKNET_HOME/keys"
        "$STARKNET_HOME/logs"
        "$STARKNET_HOME/backups"
        "$STARKNET_HOME/monitoring"
        "$STARKNET_HOME/incidents"
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
    
    log_info "Directorios de trabajo configurados"
}

# =============================================================================
# FUNCIONES DE CONFIGURACIÓN
# =============================================================================

configure_rsyslog() {
    log_info "Configurando rsyslog para Starknet..."
    
    local rsyslog_config="/etc/rsyslog.d/99-starknet.conf"
    
    if [[ ! -f "$rsyslog_config" ]]; then
        cat > "$rsyslog_config" << EOF
# Configuración de logging para Starknet
if \$programname == 'starknet' then /var/log/starknet.log
if \$programname == 'starknet' then stop
EOF
        log_info "Configuración de rsyslog creada"
    else
        log_info "Configuración de rsyslog ya existe"
    fi
    
    # Reiniciar rsyslog
    systemctl restart rsyslog
    log_info "rsyslog reiniciado"
}

setup_cron_jobs() {
    log_info "Configurando tareas cron..."
    
    local cron_file="/etc/cron.d/starknet"
    
    if [[ ! -f "$cron_file" ]]; then
        cat > "$cron_file" << EOF
# Tareas cron para Starknet
# Backup diario a las 2:00 AM
0 2 * * * starknet $PROJECT_ROOT/scripts/40_backup.sh daily

# Verificación de estado semanal
0 3 * * 0 starknet $PROJECT_ROOT/scripts/30_monitoring.sh --health-check

# Limpieza de logs mensual
0 4 1 * * starknet find $STARKNET_HOME/logs -name "*.log.*" -mtime +30 -delete
EOF
        log_info "Tareas cron configuradas"
    else
        log_info "Tareas cron ya configuradas"
    fi
    
    # Establecer permisos correctos
    chmod 644 "$cron_file"
    chown root:root "$cron_file"
}

# =============================================================================
# FUNCIONES DE VERIFICACIÓN
# =============================================================================

test_docker() {
    log_info "Probando instalación de Docker..."
    
    # Verificar que Docker esté funcionando
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker no está funcionando correctamente"
        exit 1
    fi
    
    # Probar Docker con hello-world (solo si no hay contenedores corriendo)
    if [[ $(docker ps -q | wc -l) -eq 0 ]]; then
        log_info "Ejecutando prueba Docker hello-world..."
        if docker run --rm hello-world >/dev/null 2>&1; then
            log_info "Prueba Docker exitosa"
        else
            log_warn "Prueba Docker falló, pero Docker está funcionando"
        fi
    else
        log_info "Saltando prueba Docker hello-world (hay contenedores corriendo)"
    fi
}

verify_installation() {
    log_info "Verificando instalación..."
    
    # Verificar versiones
    local docker_version=$(docker --version)
    local compose_version=$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null)
    
    log_info "Docker: $docker_version"
    log_info "Docker Compose: $compose_version"
    
    # Verificar espacio en disco
    check_disk_space
    
    # Verificar puertos
    check_ports
    
    # Verificar usuario y grupo
    if getent passwd "$STARKNET_USER" >/dev/null 2>&1; then
        log_info "Usuario $STARKNET_USER verificado"
    else
        log_error "Usuario $STARKNET_USER no existe"
        exit 1
    fi
    
    if getent group "$STARKNET_GROUP" >/dev/null 2>&1; then
        log_info "Grupo $STARKNET_GROUP verificado"
    else
        log_error "Grupo $STARKNET_GROUP no existe"
        exit 1
    fi
    
    # Verificar directorios
    if [[ -d "$STARKNET_HOME" ]]; then
        log_info "Directorio $STARKNET_HOME verificado"
    else
        log_error "Directorio $STARKNET_HOME no existe"
        exit 1
    fi
    
    log_info "Verificación de instalación completada"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log_info "=== Iniciando bootstrap de Starknet ==="
    log_info "Script: $SCRIPT_NAME"
    log_info "Directorio: $SCRIPT_DIR"
    log_info "Archivo de entorno: $ENV_FILE"
    
    # Verificaciones previas
    check_root
    check_supported_os
    check_connectivity
    
    # Instalación y configuración
    update_system
    install_dependencies
    install_docker
    install_docker_compose
    create_starknet_user
    create_directories
    configure_rsyslog
    setup_cron_jobs
    
    # Verificaciones finales
    test_docker
    verify_installation
    
    log_info "=== Bootstrap de Starknet completado exitosamente ==="
    log_info "Próximos pasos:"
    log_info "1. Configurar variables de entorno en $ENV_FILE"
    log_info "2. Ejecutar: make harden"
    log_info "3. Ejecutar: make deploy"
    log_info "4. Ejecutar: make monitor"
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
