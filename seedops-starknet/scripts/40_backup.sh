#!/usr/bin/env bash
# SEED Ops - Starknet Backup Script
# Script de backup y recuperación para validador Starknet
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
readonly LOG_FILE="/var/log/starknet-backup.log"

# Directorios y archivos de backup
readonly BACKUP_DIR="$STARKNET_HOME/backups"
readonly BACKUP_KEYS_DIR="$STARKNET_HOME/keys"
readonly BACKUP_CONFIG_DIR="$STARKNET_HOME/config"
readonly BACKUP_COMPOSE_DIR="$PROJECT_ROOT/compose"
readonly BACKUP_TEMPLATES_DIR="$PROJECT_ROOT/templates"

# Configuración de backup
readonly BACKUP_RETENTION_LOCAL="${BACKUP_RETENTION_LOCAL:-30}"
readonly BACKUP_RETENTION_DAILY="${BACKUP_RETENTION_DAILY:-7}"
readonly BACKUP_RETENTION_WEEKLY="${BACKUP_RETENTION_WEEKLY:-4}"
readonly BACKUP_RETENTION_MONTHLY="${BACKUP_RETENTION_MONTHLY:-12}"

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
    local critical_vars=("BACKUP_RETENTION_LOCAL" "ENABLE_ENCRYPTED_BACKUP")
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

check_disk_space() {
    log_info "Verificando espacio en disco para backup..."
    
    local backup_dir="${BACKUP_DIR:-/var/backups/starknet}"
    local available_space=$(df "$backup_dir" | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB en KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Espacio insuficiente en $backup_dir. Disponible: ${available_space}KB, Requerido: ${required_space}KB"
        exit 1
    fi
    
    log_info "Espacio en disco suficiente: ${available_space}KB disponibles"
}

# =============================================================================
# FUNCIONES DE PREPARACIÓN
# =============================================================================

prepare_backup_directories() {
    log_info "Preparando directorios de backup..."
    
    local directories=(
        "$BACKUP_DIR" "$BACKUP_KEYS_DIR" "$BACKUP_CONFIG_DIR"
        "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"
        "$BACKUP_DIR/temp"
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
    
    # Permisos especiales para keys
    chmod 700 "$BACKUP_KEYS_DIR"
    
    log_info "Directorios de backup preparados"
}

# =============================================================================
# FUNCIONES DE BACKUP
# =============================================================================

create_backup_archive() {
    local backup_type="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="starknet-${backup_type}-${timestamp}"
    local temp_dir="$BACKUP_DIR/temp/$backup_name"
    local archive_file="$BACKUP_DIR/${backup_type}/${backup_name}.tar.gz"
    
    log_info "Creando backup $backup_type: $backup_name"
    
    # Crear directorio temporal
    mkdir -p "$temp_dir"
    
    # Copiar archivos de configuración
    if [[ -d "$BACKUP_CONFIG_DIR" ]]; then
        cp -r "$BACKUP_CONFIG_DIR" "$temp_dir/"
        log_info "Configuraciones copiadas"
    fi
    
    # Copiar archivos de Docker Compose
    if [[ -d "$BACKUP_COMPOSE_DIR" ]]; then
        cp -r "$BACKUP_COMPOSE_DIR" "$temp_dir/"
        log_info "Docker Compose copiado"
    fi
    
    # Copiar templates
    if [[ -d "$BACKUP_TEMPLATES_DIR" ]]; then
        cp -r "$BACKUP_TEMPLATES_DIR" "$temp_dir/"
        log_info "Templates copiados"
    fi
    
    # Copiar archivo de entorno (si existe y no es el ejemplo)
    if [[ -f "$ENV_FILE" ]] && [[ "$ENV_FILE" != "$PROJECT_ROOT/env/starknet.env.example" ]]; then
        cp "$ENV_FILE" "$temp_dir/"
        log_info "Variables de entorno copiadas"
    fi
    
    # Crear archivo de metadatos
    create_backup_metadata "$temp_dir" "$backup_type" "$timestamp"
    
    # Crear archivo de verificación
    create_backup_verification "$temp_dir"
    
    # Crear archivo tar.gz
    log_info "Comprimiendo backup..."
    cd "$BACKUP_DIR/temp"
    tar -czf "$archive_file" "$backup_name"
    
    if [[ $? -eq 0 ]]; then
        log_info "Backup comprimido: $archive_file"
        
        # Calcular checksum
        local checksum_file="${archive_file}.sha256"
        sha256sum "$archive_file" > "$checksum_file"
        log_info "Checksum calculado: $checksum_file"
        
        # Establecer permisos correctos
        chown "$STARKNET_USER:$STARKNET_GROUP" "$archive_file" "$checksum_file"
        chmod 644 "$archive_file" "$checksum_file"
        
        # Limpiar directorio temporal
        rm -rf "$temp_dir"
        
        # Encriptar si está habilitado
        if [[ "${ENABLE_ENCRYPTED_BACKUP:-false}" == "true" ]]; then
            encrypt_backup "$archive_file"
        fi
        
        # Subir a almacenamiento remoto si está configurado
        if [[ -n "${RCLONE_REMOTE:-}" ]]; then
            upload_to_remote "$archive_file"
        fi
        
        return 0
    else
        log_error "Error al comprimir backup"
        rm -rf "$temp_dir"
        return 1
    fi
}

create_backup_metadata() {
    local temp_dir="$1"
    local backup_type="$2"
    local timestamp="$3"
    
    local metadata_file="$temp_dir/backup-metadata.txt"
    
    cat > "$metadata_file" << EOF
# Metadatos del Backup - Starknet Validator
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')
# Tipo: $backup_type
# Timestamp: $timestamp
# Script: $SCRIPT_NAME

## Sistema
- Hostname: $(hostname)
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- Kernel: $(uname -r)
- Usuario: $STARKNET_USER

## Configuración
- Directorio Starknet: $STARKNET_HOME
- Archivo de entorno: $ENV_FILE
- Proyecto: $PROJECT_ROOT

## Contenido del Backup
- Configuraciones: $BACKUP_CONFIG_DIR
- Docker Compose: $BACKUP_COMPOSE_DIR
- Templates: $BACKUP_TEMPLATES_DIR
- Variables de entorno: $(if [[ -f "$ENV_FILE" ]]; then echo "Sí"; else echo "No"; fi)

## Verificación
- Checksum: $(sha256sum "$temp_dir"/* | head -1 | awk '{print $1}')
- Tamaño: $(du -sh "$temp_dir" | awk '{print $1}')
- Archivos: $(find "$temp_dir" -type f | wc -l)

## Notas
- Este backup contiene configuraciones críticas del validador
- Restaurar solo en sistemas compatibles
- Verificar integridad antes de restaurar
EOF
    
    log_info "Metadatos del backup creados"
}

create_backup_verification() {
    local temp_dir="$1"
    
    local verification_file="$temp_dir/backup-verification.sh"
    
    cat > "$verification_file" << 'EOF'
#!/bin/bash
# Script de verificación del backup

echo "Verificando integridad del backup..."

# Verificar que los archivos críticos existan
critical_files=(
    "config/config.yaml"
    "compose/starknet.docker-compose.yml"
    "templates/config.yaml.j2"
)

for file in "${critical_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file encontrado"
    else
        echo "❌ $file no encontrado"
        exit 1
    fi
done

# Verificar permisos
if [[ -d "keys" ]] && [[ "$(stat -c %a keys)" == "700" ]]; then
    echo "✅ Permisos de keys correctos"
else
    echo "⚠️  Permisos de keys incorrectos"
fi

echo "Verificación completada exitosamente"
EOF
    
    chmod +x "$verification_file"
    log_info "Script de verificación creado"
}

# =============================================================================
# FUNCIONES DE ENCRIPTACIÓN
# =============================================================================

encrypt_backup() {
    local archive_file="$1"
    
    if [[ "${ENABLE_ENCRYPTED_BACKUP:-false}" != "true" ]]; then
        log_info "Encriptación de backup deshabilitada"
        return 0
    fi
    
    local gpg_recipient="${BACKUP_GPG_RECIPIENT:-}"
    
    if [[ -z "$gpg_recipient" ]]; then
        log_error "BACKUP_GPG_RECIPIENT no configurado para backup encriptado"
        return 1
    fi
    
    log_info "Encriptando backup con GPG..."
    
    # Verificar que GPG esté disponible
    if ! command -v gpg >/dev/null 2>&1; then
        log_info "Instalando GPG..."
        apt update && apt install -y gnupg
    fi
    
    # Verificar que la clave del destinatario esté disponible
    if ! gpg --list-keys "$gpg_recipient" >/dev/null 2>&1; then
        log_error "Clave GPG del destinatario no encontrada: $gpg_recipient"
        return 1
    fi
    
    # Encriptar archivo
    local encrypted_file="${archive_file}.gpg"
    if gpg --encrypt --recipient "$gpg_recipient" --output "$encrypted_file" "$archive_file"; then
        log_info "Backup encriptado: $encrypted_file"
        
        # Establecer permisos correctos
        chown "$STARKNET_USER:$STARKNET_GROUP" "$encrypted_file"
        chmod 644 "$encrypted_file"
        
        # Remover archivo original no encriptado
        rm "$archive_file"
        log_info "Archivo original no encriptado removido"
        
        return 0
    else
        log_error "Error al encriptar backup"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE ALMACENAMIENTO REMOTO
# =============================================================================

upload_to_remote() {
    local archive_file="$1"
    
    if [[ -z "${RCLONE_REMOTE:-}" ]]; then
        log_info "Almacenamiento remoto no configurado"
        return 0
    fi
    
    log_info "Subiendo backup a almacenamiento remoto: $RCLONE_REMOTE"
    
    # Verificar que rclone esté disponible
    if ! command -v rclone >/dev/null 2>&1; then
        log_info "Instalando rclone..."
        curl -s https://rclone.org/install.sh | bash
    fi
    
    # Crear directorio remoto si no existe
    local remote_path="${RCLONE_REMOTE}/starknet-backups"
    
    # Subir archivo
    if rclone copy "$archive_file" "$remote_path"; then
        log_info "Backup subido exitosamente a $remote_path"
        
        # Verificar integridad remota
        verify_remote_backup "$archive_file" "$remote_path"
        
        return 0
    else
        log_error "Error al subir backup a almacenamiento remoto"
        return 1
    fi
}

verify_remote_backup() {
    local local_file="$1"
    local remote_path="$2"
    
    log_info "Verificando integridad del backup remoto..."
    
    # Obtener checksum local
    local local_checksum=$(sha256sum "$local_file" | awk '{print $1}')
    
    # Obtener checksum remoto
    local remote_checksum=$(rclone cat "$remote_path/$(basename "$local_file").sha256" 2>/dev/null | awk '{print $1}')
    
    if [[ "$local_checksum" == "$remote_checksum" ]]; then
        log_info "✅ Integridad del backup remoto verificada"
        return 0
    else
        log_error "❌ Checksum del backup remoto no coincide"
        log_error "Local: $local_checksum"
        log_error "Remoto: $remote_checksum"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE LIMPIEZA
# =============================================================================

cleanup_old_backups() {
    log_info "Limpiando backups antiguos..."
    
    local backup_types=("daily" "weekly" "monthly")
    local retention_map=(
        ["daily"]="$BACKUP_RETENTION_DAILY"
        ["weekly"]="$BACKUP_RETENTION_WEEKLY"
        ["monthly"]="$BACKUP_RETENTION_MONTHLY"
    )
    
    for backup_type in "${backup_types[@]}"; do
        local retention="${retention_map[$backup_type]}"
        local backup_path="$BACKUP_DIR/$backup_type"
        
        if [[ -d "$backup_path" ]]; then
            local files_to_remove=$(find "$backup_path" -name "*.tar.gz*" -type f -printf '%T@ %p\n' | sort -n | head -n -"$retention" | awk '{print $2}')
            
            if [[ -n "$files_to_remove" ]]; then
                log_info "Removiendo $backup_type backups antiguos (reteniendo $retention):"
                echo "$files_to_remove" | while read -r file; do
                    if [[ -f "$file" ]]; then
                        rm "$file"
                        log_info "Removido: $(basename "$file")"
                    fi
                done
            else
                log_info "No hay $backup_type backups antiguos para remover"
            fi
        fi
    done
    
    log_info "Limpieza de backups completada"
}

# =============================================================================
# FUNCIONES DE RECUPERACIÓN
# =============================================================================

restore_backup() {
    local backup_file="$1"
    local restore_dir="${2:-$STARKNET_HOME/restore}"
    
    log_info "Restaurando backup: $backup_file"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Archivo de backup no encontrado: $backup_file"
        return 1
    fi
    
    # Crear directorio de restauración
    mkdir -p "$restore_dir"
    
    # Verificar integridad del backup
    if ! verify_backup_integrity "$backup_file"; then
        log_error "Backup corrupto o inválido"
        return 1
    fi
    
    # Extraer backup
    log_info "Extrayendo backup..."
    if tar -xzf "$backup_file" -C "$restore_dir"; then
        log_info "Backup extraído exitosamente"
        
        # Verificar contenido
        if verify_restored_content "$restore_dir"; then
            log_info "✅ Restauración completada exitosamente"
            log_info "Contenido restaurado en: $restore_dir"
            log_info "Revisar archivos antes de aplicar cambios"
            return 0
        else
            log_error "❌ Contenido restaurado inválido"
            return 1
        fi
    else
        log_error "Error al extraer backup"
        return 1
    fi
}

verify_backup_integrity() {
    local backup_file="$1"
    
    log_info "Verificando integridad del backup..."
    
    # Verificar checksum si existe
    local checksum_file="${backup_file}.sha256"
    if [[ -f "$checksum_file" ]]; then
        if sha256sum -c "$checksum_file" >/dev/null 2>&1; then
            log_info "✅ Checksum del backup verificado"
        else
            log_error "❌ Checksum del backup no coincide"
            return 1
        fi
    else
        log_warn "Archivo de checksum no encontrado, saltando verificación"
    fi
    
    # Verificar que sea un archivo tar válido
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_info "✅ Formato del backup válido"
        return 0
    else
        log_error "❌ Formato del backup inválido"
        return 1
    fi
}

verify_restored_content() {
    local restore_dir="$1"
    
    log_info "Verificando contenido restaurado..."
    
    # Verificar archivos críticos
    local critical_files=(
        "config/config.yaml"
        "compose/starknet.docker-compose.yml"
        "templates/config.yaml.j2"
    )
    
    local missing_files=()
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$restore_dir/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Archivos críticos faltantes: ${missing_files[*]}"
        return 1
    fi
    
    log_info "✅ Contenido restaurado verificado"
    return 0
}

# =============================================================================
# FUNCIONES DE BACKUP AUTOMÁTICO
# =============================================================================

daily_backup() {
    log_info "Ejecutando backup diario..."
    create_backup_archive "daily"
    cleanup_old_backups
}

weekly_backup() {
    log_info "Ejecutando backup semanal..."
    create_backup_archive "weekly"
    cleanup_old_backups
}

monthly_backup() {
    log_info "Ejecutando backup mensual..."
    create_backup_archive "monthly"
    cleanup_old_backups
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log_info "=== Iniciando script de backup de Starknet ==="
    log_info "Script: $SCRIPT_NAME"
    log_info "Directorio: $SCRIPT_DIR"
    log_info "Archivo de entorno: $ENV_FILE"
    
    # Verificaciones previas
    check_root
    check_user_exists
    load_environment
    check_disk_space
    
    # Preparación
    prepare_backup_directories
    
    # Determinar tipo de backup basado en argumentos
    case "${1:-daily}" in
        "daily")
            daily_backup
            ;;
        "weekly")
            weekly_backup
            ;;
        "monthly")
            monthly_backup
            ;;
        "restore")
            if [[ -z "${2:-}" ]]; then
                log_error "Archivo de backup requerido para restauración"
                log_error "Uso: $0 restore <archivo_backup> [directorio_destino]"
                exit 1
            fi
            restore_backup "$2" "${3:-}"
            ;;
        "verify")
            if [[ -z "${2:-}" ]]; then
                log_error "Archivo de backup requerido para verificación"
                log_error "Uso: $0 verify <archivo_backup>"
                exit 1
            fi
            verify_backup_integrity "$2"
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        *)
            log_error "Tipo de backup no válido: $1"
            log_error "Tipos válidos: daily, weekly, monthly, restore, verify, cleanup"
            exit 1
            ;;
    esac
    
    log_info "=== Script de backup completado ==="
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
