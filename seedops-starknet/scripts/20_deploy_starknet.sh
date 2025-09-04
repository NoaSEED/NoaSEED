#!/usr/bin/env bash
# SEED Ops - Starknet Deployment Script
# Script de despliegue del validador Starknet con Docker Compose
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
readonly LOG_FILE="/var/log/starknet-deploy.log"

# Directorios y archivos
readonly CONFIG_TEMPLATE="$PROJECT_ROOT/templates/config.yaml.j2"
readonly CONFIG_FILE="$STARKNET_HOME/config/config.yaml"
readonly COMPOSE_FILE="$PROJECT_ROOT/compose/starknet.docker-compose.yml"
readonly VALIDATOR_REPO_DIR="$STARKNET_HOME/validator"

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
            echo -e "${BLUE}[$level]${NC} $timestamp - $message" | tee -a "$LOG_file"
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
    
    # Verificar Docker Compose
    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose no está disponible. Ejecutar bootstrap primero: make bootstrap"
        exit 1
    fi
}

load_environment() {
    log_info "Cargando variables de entorno..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Archivo de entorno no encontrado: $ENV_FILE"
        log_error "Copiar desde ejemplo: cp env/starknet.env.example env/starknet.env"
        log_error "Editar con tus valores y ejecutar nuevamente"
        exit 1
    fi
    
    # Cargar variables
    source "$ENV_FILE"
    
    # Validar variables críticas
    local critical_vars=(
        "NETWORK" "DATA_DIR" "KEYSTORE_PATH" "KEY_PASSPHRASE_FILE"
        "RPC_PORT" "P2P_PORT" "METRICS_PORT" "VALIDATOR_IMAGE"
        "VALIDATOR_TAG" "ETHEREUM_API_URL"
    )
    
    local missing_vars=()
    
    for var in "${critical_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Variables críticas faltantes en $ENV_FILE:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        log_error "Configurar estas variables y ejecutar nuevamente"
        exit 1
    fi
    
    log_info "Variables de entorno cargadas correctamente"
}

validate_ports() {
    log_info "Validando puertos..."
    
    local ports=("$RPC_PORT" "$P2P_PORT" "$METRICS_PORT")
    
    for port in "${ports[@]}"; do
        if ss -lnt | grep -q ":$port "; then
            log_warn "Puerto $port ya está en uso"
            if [[ "$port" == "$SSH_PORT" ]]; then
                log_error "Puerto SSH $port está en uso. Cambiar en configuración"
                exit 1
            fi
        else
            log_info "Puerto $port disponible"
        fi
    done
}

check_disk_space() {
    log_info "Verificando espacio en disco..."
    
    local data_dir="${DATA_DIR:-/opt/starknet/data}"
    local available_space=$(df "$data_dir" | awk 'NR==2 {print $4}')
    local required_space=52428800  # 50GB en KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Espacio insuficiente en $data_dir. Disponible: ${available_space}KB, Requerido: ${required_space}KB"
        exit 1
    fi
    
    log_info "Espacio en disco suficiente: ${available_space}KB disponibles"
}

# =============================================================================
# FUNCIONES DE PREPARACIÓN
# =============================================================================

prepare_directories() {
    log_info "Preparando directorios..."
    
    local directories=(
        "$DATA_DIR" "$KEYSTORE_PATH" "$STARKNET_HOME/config"
        "$STARKNET_HOME/logs" "$STARKNET_HOME/backups"
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
    
    # Permisos especiales para keystore
    chmod 700 "$KEYSTORE_PATH"
    
    log_info "Directorios preparados"
}

render_configuration() {
    log_info "Renderizando configuración desde template..."
    
    if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
        log_error "Template de configuración no encontrado: $CONFIG_TEMPLATE"
        exit 1
    fi
    
    # Verificar que envsubst esté disponible
    if ! command -v envsubst >/dev/null 2>&1; then
        log_info "Instalando gettext-base para envsubst..."
        apt update && apt install -y gettext-base
    fi
    
    # Renderizar configuración
    envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_FILE"
    
    # Verificar que se renderizó correctamente
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Error al crear archivo de configuración"
        exit 1
    fi
    
    # Verificar que no queden placeholders
    if grep -q '\${' "$CONFIG_FILE"; then
        log_error "Placeholders sin reemplazar en configuración:"
        grep -n '\${' "$CONFIG_FILE"
        exit 1
    fi
    
    # Establecer permisos correctos
    chown "$STARKNET_USER:$STARKNET_GROUP" "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    
    log_info "Configuración renderizada: $CONFIG_FILE"
}

setup_docker_compose() {
    log_info "Configurando Docker Compose..."
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Archivo Docker Compose no encontrado: $COMPOSE_FILE"
        exit 1
    fi
    
    # Verificar sintaxis del compose
    if docker compose version >/dev/null 2>&1; then
        docker compose -f "$COMPOSE_FILE" config >/dev/null
    else
        docker-compose -f "$COMPOSE_FILE" config >/dev/null
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Error en la sintaxis del Docker Compose"
        exit 1
    fi
    
    log_info "Docker Compose validado"
}

# =============================================================================
# FUNCIONES DE REPOSITORIO
# =============================================================================

setup_validator_repository() {
    log_info "Configurando repositorio del validador..."
    
    local repo_url="${VALIDATOR_REPO_URL:-}"
    local repo_branch="${VALIDATOR_REPO_BRANCH:-main}"
    
    if [[ -z "$repo_url" ]]; then
        log_warn "VALIDATOR_REPO_URL no configurado, saltando clonación"
        log_warn "Configurar URL del repositorio oficial del validador en $ENV_FILE"
        return 0
    fi
    
    if [[ -d "$VALIDATOR_REPO_DIR" ]]; then
        log_info "Repositorio ya existe, actualizando..."
        cd "$VALIDATOR_REPO_DIR"
        
        # Fetch y reset a la rama especificada
        git fetch origin
        git reset --hard "origin/$repo_branch"
        
        log_info "Repositorio actualizado a rama $repo_branch"
    else
        log_info "Clonando repositorio del validador..."
        git clone -b "$repo_branch" "$repo_url" "$VALIDATOR_REPO_DIR"
        
        if [[ $? -ne 0 ]]; then
            log_error "Error al clonar repositorio: $repo_url"
            exit 1
        fi
        
        log_info "Repositorio clonado exitosamente"
    fi
    
    # Establecer permisos correctos
    chown -R "$STARKNET_USER:$STARKNET_GROUP" "$VALIDATOR_REPO_DIR"
    
    # Obtener información del commit
    cd "$VALIDATOR_REPO_DIR"
    local commit_hash=$(git rev-parse --short HEAD)
    local commit_date=$(git log -1 --format=%cd --date=short)
    
    log_info "Commit actual: $commit_hash ($commit_date)"
}

# =============================================================================
# FUNCIONES DE DESPLIEGUE
# =============================================================================

deploy_service() {
    log_info "Desplegando servicio Starknet..."
    
    # Pull de la imagen
    log_info "Descargando imagen del validador..."
    if docker compose version >/dev/null 2>&1; then
        docker compose -f "$COMPOSE_FILE" pull
    else
        docker-compose -f "$COMPOSE_FILE" pull
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Error al descargar imagen del validador"
        exit 1
    fi
    
    # Desplegar servicio
    log_info "Iniciando servicio..."
    if docker compose version >/dev/null 2>&1; then
        docker compose -f "$COMPOSE_FILE" up -d
    else
        docker-compose -f "$COMPOSE_FILE" up -d
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Error al desplegar servicio"
        exit 1
    fi
    
    log_info "Servicio desplegado exitosamente"
}

# =============================================================================
# FUNCIONES DE VERIFICACIÓN
# =============================================================================

verify_deployment() {
    log_info "Verificando despliegue..."
    
    local errors=0
    
    # Verificar que el contenedor esté corriendo
    if docker compose version >/dev/null 2>&1; then
        local container_status=$(docker compose -f "$COMPOSE_FILE" ps --format json | jq -r '.[0].State')
    else
        local container_status=$(docker-compose -f "$COMPOSE_FILE" ps --format json | jq -r '.[0].State')
    fi
    
    if [[ "$container_status" == "running" ]]; then
        log_info "✅ Contenedor corriendo correctamente"
    else
        log_error "❌ Contenedor no está corriendo. Estado: $container_status"
        ((errors++))
    fi
    
    # Verificar puertos
    if ss -lnt | grep -q ":$RPC_PORT "; then
        log_info "✅ Puerto RPC $RPC_PORT escuchando"
    else
        log_error "❌ Puerto RPC $RPC_PORT no está escuchando"
        ((errors++))
    fi
    
    if ss -lnt | grep -q ":$P2P_PORT "; then
        log_info "✅ Puerto P2P $P2P_PORT escuchando"
    else
        log_error "❌ Puerto P2P $P2P_PORT no está escuchando"
        ((errors++))
    fi
    
    # Verificar logs del contenedor
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log_info "Mostrando logs del contenedor..."
        if docker compose version >/dev/null 2>&1; then
            docker compose -f "$COMPOSE_FILE" logs --tail=50
        else
            docker-compose -f "$COMPOSE_FILE" logs --tail=50
        fi
    fi
    
    # Verificar health check
    local health_status
    if docker compose version >/dev/null 2>&1; then
        health_status=$(docker compose -f "$COMPOSE_FILE" ps --format json | jq -r '.[0].Health')
    else
        health_status=$(docker-compose -f "$COMPOSE_FILE" ps --format json | jq -r '.[0].Health')
    fi
    
    if [[ "$health_status" == "healthy" ]]; then
        log_info "✅ Health check del contenedor exitoso"
    else
        log_warn "⚠️  Health check del contenedor: $health_status"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_info "✅ Despliegue verificado exitosamente"
        return 0
    else
        log_error "❌ Se encontraron $errors errores en el despliegue"
        return 1
    fi
}

collect_deployment_info() {
    log_info "Recopilando información del despliegue..."
    
    # Información del contenedor
    local container_info
    if docker compose version >/dev/null 2>&1; then
        container_info=$(docker compose -f "$COMPOSE_FILE" ps --format json)
    else
        container_info=$(docker-compose -f "$COMPOSE_FILE" ps --format json)
    fi
    
    local container_id=$(echo "$container_info" | jq -r '.[0].ID')
    local container_name=$(echo "$container_info" | jq -r '.[0].Name')
    local container_image=$(echo "$container_info" | jq -r '.[0].Image')
    
    # Información del commit (si hay repositorio)
    local commit_info=""
    if [[ -d "$VALIDATOR_REPO_DIR" ]]; then
        cd "$VALIDATOR_REPO_DIR"
        local commit_hash=$(git rev-parse --short HEAD)
        local commit_date=$(git log -1 --format=%cd --date=short)
        commit_info=" (Commit: $commit_hash, Fecha: $commit_date)"
    fi
    
    # Crear archivo de información del despliegue
    local deploy_info_file="$STARKNET_HOME/deployment-info.txt"
    
    cat > "$deploy_info_file" << EOF
# Información del Despliegue - Starknet Validator
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')
# Script: $SCRIPT_NAME

## Contenedor
- ID: $container_id
- Nombre: $container_name
- Imagen: $container_image
- Estado: $(docker inspect "$container_id" --format='{{.State.Status}}')

## Configuración
- Red: ${NETWORK}
- Puerto RPC: $RPC_PORT
- Puerto P2P: $P2P_PORT
- Puerto Métricas: $METRICS_PORT
- Directorio de Datos: $DATA_DIR
- Keystore: $KEYSTORE_PATH

## Repositorio$commit_info

## Variables de Entorno
- Archivo: $ENV_FILE
- Template: $CONFIG_TEMPLATE
- Configuración: $CONFIG_FILE

## Docker Compose
- Archivo: $COMPOSE_FILE
- Usuario: $STARKNET_USER
- Grupo: $STARKNET_GROUP

## Verificación
- Puerto RPC: $(ss -lnt | grep -q ":$RPC_PORT " && echo "✅ Escuchando" || echo "❌ No escucha")
- Puerto P2P: $(ss -lnt | grep -q ":$P2P_PORT " && echo "✅ Escuchando" || echo "❌ No escucha")
- Puerto Métricas: $(ss -lnt | grep -q ":$METRICS_PORT " && echo "✅ Escuchando" || echo "❌ No escucha")
EOF
    
    chown "$STARKNET_USER:$STARKNET_GROUP" "$deploy_info_file"
    chmod 644 "$deploy_info_file"
    
    log_info "Información del despliegue guardada en: $deploy_info_file"
}

# =============================================================================
# FUNCIONES DE ROLLBACK
# =============================================================================

rollback_deployment() {
    log_error "Iniciando rollback del despliegue..."
    
    # Detener y remover contenedores
    if docker compose version >/dev/null 2>&1; then
        docker compose -f "$COMPOSE_FILE" down
    else
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # Remover volúmenes si es necesario
    if [[ "${ROLLBACK_REMOVE_VOLUMES:-false}" == "true" ]]; then
        log_warn "Removiendo volúmenes de datos..."
        if docker compose version >/dev/null 2>&1; then
            docker compose -f "$COMPOSE_FILE" down -v
        else
            docker-compose -f "$COMPOSE_FILE" down -v
        fi
    fi
    
    log_info "Rollback completado"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log_info "=== Iniciando despliegue de Starknet Validator ==="
    log_info "Script: $SCRIPT_NAME"
    log_info "Directorio: $SCRIPT_DIR"
    log_info "Archivo de entorno: $ENV_FILE"
    
    # Verificaciones previas
    check_root
    check_user_exists
    check_docker
    load_environment
    validate_ports
    check_disk_space
    
    # Preparación
    prepare_directories
    render_configuration
    setup_docker_compose
    setup_validator_repository
    
    # Despliegue
    deploy_service
    
    # Verificación
    if verify_deployment; then
        collect_deployment_info
        
        log_info "=== Despliegue de Starknet Validator completado exitosamente ==="
        log_info "Próximos pasos:"
        log_info "1. Verificar logs: docker compose -f $COMPOSE_FILE logs -f"
        log_info "2. Verificar estado: docker compose -f $COMPOSE_FILE ps"
        log_info "3. Configurar monitoreo: make monitor"
        log_info "4. Configurar backup: make backup"
        
        # Mostrar endpoints
        log_info "Endpoints disponibles:"
        log_info "  - RPC: http://$(hostname -I | awk '{print $1}'):$RPC_PORT"
        log_info "  - P2P: $(hostname -I | awk '{print $1}'):$P2P_PORT"
        if [[ "${ENABLE_METRICS:-true}" == "true" ]]; then
            log_info "  - Métricas: http://$(hostname -I | awk '{print $1}'):$METRICS_PORT"
        fi
    else
        log_error "=== Despliegue falló ==="
        rollback_deployment
        exit 1
    fi
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
