#!/bin/bash
# SEEDNodes - Bootstrap Script
# Configuración inicial del sistema para NodeOps Institucionales

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
AUDIT_DIR="$PROJECT_ROOT/audit-logs"

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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Verificar si se ejecuta como root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        error "No ejecutes esto como root - es peligroso y no necesario"
        exit 1
    fi
}

# Verificar sistema operativo
check_os() {
    log "Verificando sistema operativo..."
    
    if [ ! -f /etc/os-release ]; then
        error "No se puede determinar el sistema operativo"
        exit 1
    fi
    
    . /etc/os-release
    
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "22.04" ]; then
        warning "Detecté: $PRETTY_NAME"
        warning "Probamos todo en Ubuntu 22.04 LTS - otros sistemas pueden tener problemas"
        read -p "¿Seguir adelante? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Sistema operativo verificado: $PRETTY_NAME ✅"
}

# Actualizar sistema
update_system() {
    log "Actualizando sistema operativo..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean
    
    log "Sistema actualizado ✅"
}

# Instalar dependencias básicas
install_dependencies() {
    log "Instalando dependencias básicas..."
    
    sudo apt install -y \
        curl \
        wget \
        git \
        vim \
        htop \
        tree \
        jq \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
        ufw \
        fail2ban \
        logrotate \
        rsync \
        openssh-server
    
    log "Dependencias básicas instaladas ✅"
}

# Configurar usuario y grupos
setup_user() {
    log "Configurando usuario y grupos..."
    
    # Agregar usuario al grupo docker (se creará después)
    sudo usermod -aG sudo "$USER"
    
    # Crear directorio home si no existe
    mkdir -p "$HOME/.local/bin"
    
    # Configurar bashrc
    if ! grep -q "SEED Org" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# SEEDNodes - NodeOps Configuration
export SEEDOPS_ROOT="$HOME/seedops-institutional"
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=vim

# Aliases útiles
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'
EOF
    fi
    
    log "Usuario configurado ✅"
}

# Instalar Docker
install_docker() {
    log "Instalando Docker..."
    
    # Verificar si Docker ya está instalado
    if command -v docker &> /dev/null; then
        info "Docker ya está instalado: $(docker --version)"
        return 0
    fi
    
    # Agregar clave GPG de Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Agregar repositorio de Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Actualizar e instalar Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Agregar usuario al grupo docker
    sudo usermod -aG docker "$USER"
    
    # Habilitar Docker al inicio
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "Docker instalado ✅"
    warning "Reinicia la sesión para que los cambios de grupo surtan efecto"
}

# Instalar Docker Compose
install_docker_compose() {
    log "Instalando Docker Compose..."
    
    # Verificar si Docker Compose ya está instalado
    if command -v docker-compose &> /dev/null; then
        info "Docker Compose ya está instalado: $(docker-compose --version)"
        return 0
    fi
    
    # Instalar Docker Compose
    sudo apt install -y docker-compose
    
    log "Docker Compose instalado ✅"
}

# Instalar herramientas adicionales
install_additional_tools() {
    log "Instalando herramientas adicionales..."
    
    # Instalar Node.js (para herramientas de desarrollo)
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Instalar herramientas de monitoreo
    sudo apt install -y \
        prometheus-node-exporter \
        htop \
        iotop \
        nethogs \
        ncdu
    
    # Instalar herramientas de red
    sudo apt install -y \
        netcat \
        nmap \
        tcpdump \
        wireshark-common
    
    log "Herramientas adicionales instaladas ✅"
}

# Configurar directorios del proyecto
setup_directories() {
    log "Configurando directorios del proyecto..."
    
    # Crear directorios necesarios
    mkdir -p "$PROJECT_ROOT"/{data,logs,backups,monitoring/{grafana/{dashboards,datasources},prometheus},templates,compose,env}
    
    # Crear directorio de auditoría
    mkdir -p "$AUDIT_DIR"
    
    # Configurar permisos
    chmod 755 "$PROJECT_ROOT"
    chmod 755 "$LOG_DIR"
    chmod 755 "$AUDIT_DIR"
    
    log "Directorios configurados ✅"
}

# Configurar SSH
setup_ssh() {
    log "Configurando SSH..."
    
    # Verificar si SSH está instalado
    if ! systemctl is-active --quiet ssh; then
        sudo systemctl enable ssh
        sudo systemctl start ssh
    fi
    
    # Configurar SSH para mayor seguridad
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configuración de seguridad SSH
    sudo tee /etc/ssh/sshd_config.d/99-seedops.conf > /dev/null << 'EOF'
# SEED Org - SSH Security Configuration
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowUsers seedops
EOF
    
    # Reiniciar SSH
    sudo systemctl restart ssh
    
    log "SSH configurado ✅"
    warning "Asegúrate de tener configurada tu clave SSH antes de cerrar la sesión"
}

# Configurar firewall básico
setup_firewall() {
    log "Configurando firewall básico..."
    
    # Habilitar UFW
    sudo ufw --force enable
    
    # Configurar reglas básicas
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Permitir SSH
    sudo ufw allow ssh
    
    # Permitir puertos comunes para nodos
    sudo ufw allow 80/tcp   # HTTP
    sudo ufw allow 443/tcp  # HTTPS
    sudo ufw allow 9545/tcp # RPC (ejemplo)
    sudo ufw allow 9546/tcp # WebSocket (ejemplo)
    sudo ufw allow 9090/tcp # Prometheus
    sudo ufw allow 3000/tcp # Grafana
    
    # Mostrar estado
    sudo ufw status
    
    log "Firewall configurado ✅"
}

# Configurar fail2ban
setup_fail2ban() {
    log "Configurando fail2ban..."
    
    # Crear configuración personalizada
    sudo tee /etc/fail2ban/jail.d/seedops.conf > /dev/null << 'EOF'
# SEED Org - Fail2ban Configuration
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = false

[nginx-limit-req]
enabled = false
EOF
    
    # Reiniciar fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    
    log "Fail2ban configurado ✅"
}

# Configurar logrotate
setup_logrotate() {
    log "Configurando logrotate..."
    
    # Crear configuración para logs de SEED Org
    sudo tee /etc/logrotate.d/seedops > /dev/null << EOF
# SEED Org - Log Rotation
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        # Reiniciar servicios si es necesario
    endscript
}

$AUDIT_DIR/*.log {
    weekly
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
}
EOF
    
    log "Logrotate configurado ✅"
}

# Configurar Python y herramientas
setup_python() {
    log "Configurando Python y herramientas..."
    
    # Crear entorno virtual
    python3 -m venv "$HOME/.venv/seedops"
    source "$HOME/.venv/seedops/bin/activate"
    
    # Instalar herramientas Python
    pip install --upgrade pip
    pip install \
        jinja2 \
        pyyaml \
        requests \
        docker \
        prometheus-client \
        python-telegram-bot
    
    # Crear script de activación
    cat > "$HOME/.local/bin/activate-seedops" << 'EOF'
#!/bin/bash
source "$HOME/.venv/seedops/bin/activate"
echo "Entorno SEED Org activado"
EOF
    
    chmod +x "$HOME/.local/bin/activate-seedops"
    
    log "Python configurado ✅"
}

# Configurar Git
setup_git() {
    log "Configurando Git..."
    
    # Configurar Git globalmente si no está configurado
    if [ -z "$(git config --global user.name)" ]; then
        git config --global user.name "SEEDNodes"
        git config --global user.email "ops@seedlatam.org"
    fi
    
    # Configurar rama por defecto
    git config --global init.defaultBranch main
    
    # Configurar colores
    git config --global color.ui auto
    
    # Configurar editor
    git config --global core.editor vim
    
    log "Git configurado ✅"
}

# Crear archivos de configuración base
create_base_configs() {
    log "Creando archivos de configuración base..."
    
    # Crear Makefile
    cat > "$PROJECT_ROOT/Makefile" << 'EOF'
# SEEDNodes - NodeOps Makefile

.PHONY: help bootstrap harden deploy monitor backup incident clean

help: ## Mostrar ayuda
	@echo "SEEDNodes - NodeOps Institucionales"
	@echo "Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Configuración inicial del sistema
	@echo "Ejecutando bootstrap..."
	./scripts/00_bootstrap.sh

harden: ## Aplicar medidas de seguridad
	@echo "Ejecutando hardening..."
	./scripts/10_hardening.sh

deploy: ## Desplegar nodos
	@echo "Desplegando nodos..."
	./scripts/20_deploy.sh

monitor: ## Configurar monitoreo
	@echo "Configurando monitoreo..."
	./scripts/30_monitoring.sh

backup: ## Ejecutar backup
	@echo "Ejecutando backup..."
	./scripts/40_backup.sh

incident: ## Respuesta a incidentes
	@echo "Ejecutando respuesta a incidentes..."
	./scripts/90_incident.sh

clean: ## Limpiar logs y archivos temporales
	@echo "Limpiando archivos temporales..."
	find . -name "*.log" -mtime +30 -delete
	find . -name "*.tmp" -delete
	docker system prune -f
EOF

    # Crear archivo de variables de entorno ejemplo
    cat > "$PROJECT_ROOT/env/.env.example" << 'EOF'
# SEEDNodes - Variables de Entorno
# Copiar a .env y configurar según necesidades

# Configuración general
SEEDOPS_ENV=production
SEEDOPS_NETWORK=mainnet
SEEDOPS_LOG_LEVEL=info

# Configuración de monitoreo
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
GRAFANA_PASSWORD=changeme

# Configuración de notificaciones
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
DISCORD_WEBHOOK_URL=your_webhook_url

# Configuración de backup
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30
BACKUP_REMOTE_URL=s3://your-backup-bucket

# Configuración de seguridad
SSH_PORT=22
UFW_ENABLED=true
FAIL2BAN_ENABLED=true
EOF

    # Crear archivo de configuración de monitoreo
    cat > "$PROJECT_ROOT/monitoring/prometheus.yml" << 'EOF'
# SEEDNodes - Prometheus Configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

    log "Archivos de configuración base creados ✅"
}

# Generar log de auditoría
generate_audit_log() {
    log "Generando log de auditoría..."
    
    AUDIT_LOG="$AUDIT_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
    
    cat > "$AUDIT_LOG" << EOF
# SEEDNodes - Bootstrap Audit Log
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
User: $(whoami)
Server: $(hostname)
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
Status: SUCCESS

## Installed Software:
- Docker: $(docker --version 2>/dev/null || echo "Not installed")
- Docker Compose: $(docker-compose --version 2>/dev/null || echo "Not installed")
- Node.js: $(node --version 2>/dev/null || echo "Not installed")
- Python: $(python3 --version 2>/dev/null || echo "Not installed")
- Git: $(git --version 2>/dev/null || echo "Not installed")

## System Configuration:
- SSH: $(systemctl is-active ssh)
- UFW: $(sudo ufw status | head -1)
- Fail2ban: $(systemctl is-active fail2ban)
- Logrotate: $(systemctl is-active logrotate)

## Directories Created:
$(find "$PROJECT_ROOT" -type d | sort)

## Next Steps:
1. Configure SSH keys
2. Set up environment variables
3. Run hardening script
4. Deploy nodes
5. Configure monitoring
EOF

    log "Log de auditoría generado: $AUDIT_LOG ✅"
}

# Función principal
main() {
    log "🚀 Iniciando bootstrap de SEEDNodes NodeOps..."
    
    check_root
    check_os
    update_system
    install_dependencies
    setup_user
    install_docker
    install_docker_compose
    install_additional_tools
    setup_directories
    setup_ssh
    setup_firewall
    setup_fail2ban
    setup_logrotate
    setup_python
    setup_git
    create_base_configs
    generate_audit_log
    
    log "✅ Bootstrap completado exitosamente!"
    log ""
    log "📋 Próximos pasos:"
    log "1. Reinicia la sesión para aplicar cambios de grupo"
    log "2. Configura tu clave SSH"
    log "3. Copia env/.env.example a env/.env y configura"
    log "4. Ejecuta: make harden"
    log "5. Ejecuta: make deploy"
    log ""
    log "📚 Documentación: INOH/institutional-handbook.md"
    log "🔧 Comandos disponibles: make help"
    log ""
    warning "IMPORTANTE: Reinicia la sesión antes de continuar"
}

# Ejecutar función principal
main "$@"

