#!/bin/bash
# SEEDNodes - Bootstrap Script
# Initial system configuration for Institutional NodeOps

set -euo pipefail

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
AUDIT_DIR="$PROJECT_ROOT/audit-logs"

# Logging functions
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

# Ensure not running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        error "Do not run as root — it is unsafe and unnecessary"
        exit 1
    fi
}

# Check operating system
check_os() {
    log "Checking operating system..."
    
    if [ ! -f /etc/os-release ]; then
        error "Unable to determine operating system"
        exit 1
    fi
    
    . /etc/os-release
    
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "22.04" ]; then
        warning "Detected: $PRETTY_NAME"
        warning "We test on Ubuntu 22.04 LTS — other systems may have issues"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Operating system verified: $PRETTY_NAME ✅"
}

# Update system
update_system() {
    log "Updating operating system..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean
    
    log "System updated ✅"
}

# Install base dependencies
install_dependencies() {
    log "Installing base dependencies..."
    
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
    
    log "Base dependencies installed ✅"
}

# User and groups setup
setup_user() {
    log "Configuring user and groups..."
    
    # Add user to sudo group (docker group added later)
    sudo usermod -aG sudo "$USER"
    
    # Ensure home bin directory
    mkdir -p "$HOME/.local/bin"
    
    # Configure bashrc
    if ! grep -q "SEED Org" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# SEEDNodes - NodeOps Configuration
export SEEDOPS_ROOT="$HOME/seedops-institutional"
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=vim

# Useful aliases
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
    
    log "User configured ✅"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    # Skip if Docker exists
    if command -v docker &> /dev/null; then
        info "Docker already installed: $(docker --version)"
        return 0
    fi
    
    # Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Docker repo
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Group
    sudo usermod -aG docker "$USER"
    
    # Enable & start
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "Docker installed ✅"
    warning "Re-login required for group changes to take effect"
}

# Install Docker Compose
install_docker_compose() {
    log "Installing Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        info "Docker Compose already installed: $(docker-compose --version)"
        return 0
    fi
    
    sudo apt install -y docker-compose
    
    log "Docker Compose installed ✅"
}

# Additional tools
install_additional_tools() {
    log "Installing additional tools..."
    
    # Node.js
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Monitoring tools
    sudo apt install -y \
        prometheus-node-exporter \
        htop \
        iotop \
        nethogs \
        ncdu
    
    # Networking tools
    sudo apt install -y \
        netcat \
        nmap \
        tcpdump \
        wireshark-common
    
    log "Additional tools installed ✅"
}

# Project directories
setup_directories() {
    log "Configuring project directories..."
    
    mkdir -p "$PROJECT_ROOT"/{data,logs,backups,monitoring/{grafana/{dashboards,datasources},prometheus},templates,compose,env}
    
    mkdir -p "$AUDIT_DIR"
    
    chmod 755 "$PROJECT_ROOT"
    chmod 755 "$LOG_DIR"
    chmod 755 "$AUDIT_DIR"
    
    log "Directories configured ✅"
}

# SSH
setup_ssh() {
    log "Configuring SSH..."
    
    if ! systemctl is-active --quiet ssh; then
        sudo systemctl enable ssh
        sudo systemctl start ssh
    fi
    
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # SSH hardening
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
    
    sudo systemctl restart ssh
    
    log "SSH configured ✅"
    warning "Ensure your SSH key is configured before logging out"
}

# Firewall
setup_firewall() {
    log "Configuring basic firewall..."
    
    sudo ufw --force enable
    
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    sudo ufw allow ssh
    
    # Common node ports
    sudo ufw allow 80/tcp   # HTTP
    sudo ufw allow 443/tcp  # HTTPS
    sudo ufw allow 9545/tcp # RPC (example)
    sudo ufw allow 9546/tcp # WebSocket (example)
    sudo ufw allow 9090/tcp # Prometheus
    sudo ufw allow 3000/tcp # Grafana
    
    sudo ufw status
    
    log "Firewall configured ✅"
}

# fail2ban
setup_fail2ban() {
    log "Configuring fail2ban..."
    
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
    
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    
    log "fail2ban configured ✅"
}

# logrotate
setup_logrotate() {
    log "Configuring logrotate..."
    
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
        # Restart services if needed
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
    
    log "logrotate configured ✅"
}

# Python tooling
setup_python() {
    log "Configuring Python and tools..."
    
    python3 -m venv "$HOME/.venv/seedops"
    source "$HOME/.venv/seedops/bin/activate"
    
    pip install --upgrade pip
    pip install \
        jinja2 \
        pyyaml \
        requests \
        docker \
        prometheus-client \
        python-telegram-bot
    
    cat > "$HOME/.local/bin/activate-seedops" << 'EOF'
#!/bin/bash
source "$HOME/.venv/seedops/bin/activate"
echo "SEED Org environment activated"
EOF
    
    chmod +x "$HOME/.local/bin/activate-seedops"
    
    log "Python configured ✅"
}

# Git
setup_git() {
    log "Configuring Git..."
    
    if [ -z "$(git config --global user.name)" ]; then
        git config --global user.name "SEEDNodes"
        git config --global user.email "ops@seedlatam.org"
    fi
    
    git config --global init.defaultBranch main
    git config --global color.ui auto
    git config --global core.editor vim
    
    log "Git configured ✅"
}

# Base configs
create_base_configs() {
    log "Creating base configuration files..."
    
    cat > "$PROJECT_ROOT/Makefile" << 'EOF'
# SEEDNodes - NodeOps Makefile

.PHONY: help bootstrap harden deploy monitor backup incident clean

help: ## Show help
	@echo "SEEDNodes - Institutional NodeOps"
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap: ## System bootstrap
	@echo "Running bootstrap..."
	./scripts/00_bootstrap.sh

harden: ## Apply security hardening
	@echo "Running hardening..."
	./scripts/10_hardening.sh

deploy: ## Deploy nodes
	@echo "Deploying nodes..."
	./scripts/20_deploy.sh

monitor: ## Configure monitoring
	@echo "Configuring monitoring..."
	./scripts/30_monitoring.sh

backup: ## Run backup
	@echo "Running backup..."
	./scripts/40_backup.sh

incident: ## Incident response
	@echo "Running incident response..."
	./scripts/90_incident.sh

clean: ## Clean logs and temp files
	@echo "Cleaning temp files..."
	find . -name "*.log" -mtime +30 -delete
	find . -name "*.tmp" -delete
	docker system prune -f
EOF

    cat > "$PROJECT_ROOT/env/.env.example" << 'EOF'
# SEEDNodes - Environment Variables
# Copy to .env and configure as needed

# General configuration
SEEDOPS_ENV=production
SEEDOPS_NETWORK=mainnet
SEEDOPS_LOG_LEVEL=info

# Monitoring configuration
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
GRAFANA_PASSWORD=changeme

# Notifications configuration
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
DISCORD_WEBHOOK_URL=your_webhook_url

# Backup configuration
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30
BACKUP_REMOTE_URL=s3://your-backup-bucket

# Security configuration
SSH_PORT=22
UFW_ENABLED=true
FAIL2BAN_ENABLED=true
EOF

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

    log "Base configuration files created ✅"
}

# Audit log
generate_audit_log() {
    log "Generating audit log..."
    
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
    
    log "Audit log generated: $AUDIT_LOG ✅"
}

# Main
main() {
    log "🚀 Starting SEEDNodes NodeOps bootstrap..."
    
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
    
    log "✅ Bootstrap completed successfully!"
    log ""
    log "📋 Next steps:"
    log "1. Re-login to apply group changes"
    log "2. Configure your SSH key"
    log "3. Copy env/.env.example to env/.env and configure"
    log "4. Run: make harden"
    log "5. Run: make deploy"
    log ""
    log "📚 Documentation: INOH/institutional-handbook.en.md"
    log "🔧 Available commands: make help"
    log ""
    warning "IMPORTANT: Re-login before continuing"
}

# Execute
main "$@"

