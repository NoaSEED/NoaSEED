#!/bin/bash

# SEEDNodes - Aztec Sequencer Node Installer
# Based on: https://web3creed.gitbook.io/aztec-guide/sequencer-node/aztec-setup-guide
# Institutional NodeOps - Automated Setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Helper: print centered ASCII art from stdin
print_centered_art() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    while IFS= read -r line; do
        local pad=$(( (cols - ${#line}) / 2 ))
        (( pad < 0 )) && pad=0
        printf "%*s%s\n" "$pad" "" "$line"
    done
}

# If running as root, make sudo a no-op for seamless execution
if [[ $EUID -eq 0 ]]; then
    sudo() { "$@"; }
fi

# Default RPC endpoints (hidden in output)
SEPOLIA_RPC_DEFAULT="http://geth.sepolia-geth.dappnode:8545"
BEACON_RPC_DEFAULT="http://prysm-sepolia.dappnode:3500"

# ASCII Art Banner
show_banner() {
    clear
    echo -e "${GREEN}"
    print_centered_art << 'EOF'
           _____________
         /               \
        /   ___________   \
       /   /  _____   /\   \
       \   \_/     \_/  \  /
        \               _/
         \_____________/
EOF
    echo -e "${NC}"
    echo -e "${CYAN}                    Institutional NodeOps - Aztec Sequencer Setup${NC}"
    echo -e "${YELLOW}================================================================${NC}"
    echo ""
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${BLUE}] ${percent}%% - ${desc}${NC}"
    echo ""
}

# Log function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    show_progress 1 10 "System Check"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        error "This script requires Ubuntu/Debian"
    fi
    
    # Allow running as root by default; can be disabled with ALLOW_ROOT=no
    if [[ $EUID -eq 0 ]]; then
        case "${ALLOW_ROOT,,}" in
            no|false|0|n)
                error "Running as root is disabled by ALLOW_ROOT. Set ALLOW_ROOT=yes or run as non-root user."
                ;;
            *)
                log "Running as root. Proceeding (sudo is a no-op)."
                ;;
        esac
    fi
    
    # Check available disk space (default minimum 250GB; override with MIN_DISK_GB and ALLOW_LOW_DISK)
    available_kb=$(df / | awk 'NR==2 {print $4}')
    available_gb=$((available_kb / 1024 / 1024))
    min_disk_gb=${MIN_DISK_GB:-100}
    required_kb=$((min_disk_gb * 1024 * 1024))

    if [[ $available_kb -lt $required_kb ]]; then
        case "${ENFORCE_DISK_CHECK,,}" in
            yes|true|1|y)
                error "Insufficient disk space. Required ${min_disk_gb}GB; detected ${available_gb}GB. You can set MIN_DISK_GB=<value> or disable with ENFORCE_DISK_CHECK=no."
                ;;
            *)
                log "Disk space below ${min_disk_gb}GB (detected: ${available_gb}GB). Continuing anyway."
                ;;
        esac
    fi
    
    log "System requirements check passed ✓"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    show_progress 2 10 "System Update"
    
    sudo apt-get update && sudo apt-get upgrade -y
    log "System updated ✓"
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    show_progress 3 10 "Package Installation"
    
    sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano \
        automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
        libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev ufw \
        screen gawk -y
    
    log "Packages installed ✓"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    show_progress 4 10 "Docker Installation"
    
    # Remove old Docker installations
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin; do
        sudo apt-get remove --purge -y $pkg 2>/dev/null || true
    done
    sudo apt-get autoremove -y
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    
    . /etc/os-release
    repo_url="https://download.docker.com/linux/$ID"
    curl -fsSL "$repo_url/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $repo_url $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Test Docker installation
    if sudo docker run hello-world; then
        sudo docker rm $(sudo docker ps -a --filter "ancestor=hello-world" --format "{{.ID}}") --force 2>/dev/null || true
        sudo docker image rm hello-world 2>/dev/null || true
        sudo systemctl enable docker
        sudo systemctl restart docker
        log "Docker installed and configured ✓"
    else
        error "Docker installation failed"
    fi
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    show_progress 5 10 "Firewall Configuration"
    
    sudo apt install -y ufw > /dev/null 2>&1
    sudo ufw allow 22
    sudo ufw allow ssh
    sudo ufw allow 40400/tcp
    sudo ufw allow 40400/udp
    sudo ufw allow 8080
    sudo ufw allow 9999  # For Dozzle monitoring
    sudo ufw --force enable
    sudo ufw reload
    
    log "Firewall configured ✓"
}

# Get user configuration
get_configuration() {
    log "Collecting configuration information..."
    show_progress 6 10 "Configuration Setup"
    
    echo -e "${YELLOW}Please provide the following information:${NC}"
    echo ""
    
    # Get IP address
    IP_ADDRESS=$(curl -s ipv4.icanhazip.com)
    echo -e "${CYAN}Detected IP Address: ${IP_ADDRESS}${NC}"
    read -p "Is this correct? (y/n): " ip_confirm
    if [[ $ip_confirm != "y" ]]; then
        read -p "Enter your VPS IP address: " IP_ADDRESS
    fi
    
    # Set RPC URLs (use defaults; allow override via env vars)
    echo ""
    SEPOLIA_RPC="${SEPOLIA_RPC:-$SEPOLIA_RPC_DEFAULT}"
    BEACON_RPC="${BEACON_RPC:-$BEACON_RPC_DEFAULT}"
    log "RPC endpoints configured."
    
    # Get wallet information
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Use a new wallet, not your main wallet!${NC}"
    read -p "Enter wallet private key (0x...): " PRIVATE_KEY
    read -p "Enter wallet address (0x...): " WALLET_ADDRESS
    
    echo ""
    echo -e "${YELLOW}⚠️  Make sure your wallet has at least 0.2-0.5 Sepolia ETH!${NC}"
    read -p "Press Enter to continue..."
    
    log "Configuration collected ✓"
}

# Prepare directory and cleanup
prepare_directory() {
    log "Preparing directory and cleaning up..."
    show_progress 7 10 "Directory Setup"
    
    # Cleanup old installations
    bash <(curl -Ls https://raw.githubusercontent.com/DeepPatel2412/Aztec-Tools/refs/heads/main/Aztec%20CLI%20Cleanup) 2>/dev/null || true
    
    # Create new directory
    rm -rf aztec
    mkdir aztec && cd aztec
    
    log "Directory prepared ✓"
}

# Create configuration files
create_config_files() {
    log "Creating configuration files..."
    show_progress 8 10 "Config Files"
    
    # Create .env file
    cat > .env << EOF
ETHEREUM_RPC_URL=${SEPOLIA_RPC}
CONSENSUS_BEACON_URL=${BEACON_RPC}
VALIDATOR_PRIVATE_KEYS=${PRIVATE_KEY}
COINBASE=${WALLET_ADDRESS}
P2P_IP=${IP_ADDRESS}
EOF
    
    # Create docker-compose.yml
    cat > docker-compose.yml << 'EOF'
services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:1.2.1
    restart: unless-stopped
    network_mode: host
    environment:
      ETHEREUM_HOSTS: ${ETHEREUM_RPC_URL}
      L1_CONSENSUS_HOST_URLS: ${CONSENSUS_BEACON_URL}
      DATA_DIRECTORY: /data
      VALIDATOR_PRIVATE_KEYS: ${VALIDATOR_PRIVATE_KEYS}
      COINBASE: ${COINBASE}
      P2P_IP: ${P2P_IP}
      LOG_LEVEL: info
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - /root/.aztec/alpha-testnet/data/:/data
EOF
    
    log "Configuration files created ✓"
}

# Start Aztec node
start_aztec_node() {
    log "Starting Aztec Sequencer Node..."
    show_progress 9 10 "Node Startup"
    
    # Start the node
    docker compose up -d
    
    # Wait a moment for startup
    sleep 10
    
    log "Aztec node started ✓"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    show_progress 10 10 "Monitoring Setup"
    
    # Install Dozzle for log monitoring
    docker run -d --name dozzle -v /var/run/docker.sock:/var/run/docker.sock -p 9999:8080 amir20/dozzle:latest 2>/dev/null || true
    
    log "Monitoring setup complete ✓"
}

# Show final information
show_final_info() {
    clear
    echo -e "${GREEN}"
    print_centered_art << 'EOF'
           _____________
         /               \
        /   ___________   \
       /   /  _____   /\   \
       \   \_/     \_/  \  /
        \               _/
         \_____________/
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}🎉 Aztec Sequencer Node Installation Complete!${NC}"
    echo ""
    echo -e "${YELLOW}📊 Node Information:${NC}"
    echo -e "   • Container: aztec-sequencer"
    echo -e "   • Network: alpha-testnet"
    echo -e "   • P2P Port: 40400"
    echo -e "   • RPC Port: 8080"
    echo ""
    echo -e "${YELLOW}🔍 Monitoring:${NC}"
    echo -e "   • Logs: docker compose logs -fn 1000"
    echo -e "   • Dozzle: http://${IP_ADDRESS}:9999"
    echo -e "   • Sync Check: bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/sync-check.sh)"
    echo ""
    echo -e "${YELLOW}📝 Useful Commands:${NC}"
    echo -e "   • View logs: docker compose logs -fn 1000"
    echo -e "   • Stop node: docker compose down"
    echo -e "   • Restart: docker compose restart"
    echo -e "   • Status: docker compose ps"
    echo ""
    echo -e "${GREEN}✅ Your Aztec Sequencer Node is now running!${NC}"
    echo -e "${BLUE}🔗 Monitor at: http://${IP_ADDRESS}:9999${NC}"
}

# Main execution
main() {
    show_banner
    
    echo -e "${YELLOW}This script will install and configure an Aztec Sequencer Node${NC}"
    echo -e "${YELLOW}Based on: https://web3creed.gitbook.io/aztec-guide/sequencer-node/aztec-setup-guide${NC}"
    echo ""
    read -p "Continue with installation? (y/n): " confirm
    
    if [[ $confirm != "y" ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    check_requirements
    update_system
    install_packages
    install_docker
    configure_firewall
    get_configuration
    prepare_directory
    create_config_files
    start_aztec_node
    setup_monitoring
    show_final_info
}

# Run main function
main "$@"
