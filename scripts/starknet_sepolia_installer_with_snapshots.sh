#!/bin/bash

# SEEDNODES - One-Click Installer: Starknet Sepolia (Pathfinder) with Juno Snapshots
# Accelerates sync using official Juno snapshots from Nethermind

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

show_banner() {
  clear || true
  echo -e "${WHITE}"
  cat << "EOF"
    ███████╗███████╗███████╗██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗███████╗
    ██╔════╝██╔════╝██╔════╝██╔══██╗████╗  ██║██╔════╝██╔═══██╗██╔════╝██╔════╝
    ███████╗█████╗  █████╗  ██║  ██║██╔██╗ ██║██║     ██║   ██║███████╗█████╗  
    ╚════██║██╔══╝  ██╔══╝  ██║  ██║██║╚██╗██║██║     ██║   ██║╚════██║██╔══╝  
    ███████║███████╗███████╗██████╔╝██║ ╚████║╚██████╗╚██████╔╝███████║███████╗
    ╚══════╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝
    
    🚀 Starknet Sepolia Node Installer with Juno Snapshots
    ⚡ Ultra-fast sync using official Nethermind snapshots
    📊 Includes monitoring with Prometheus & Grafana
EOF
  echo -e "${NC}"
}

log() {
  echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

fail() {
  echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
  exit 1
}

progress() {
  echo -e "${CYAN}[$(date +'%H:%M:%S')] 🔄 $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  fail "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Parse command line arguments
NON_INTERACTIVE=false
if [[ "$1" == "--yes" || "$1" == "-y" ]]; then
  NON_INTERACTIVE=true
fi

show_banner

# Check system requirements
log "Checking system requirements..."

# Check OS
if [[ ! -f /etc/os-release ]]; then
  fail "Cannot determine OS version"
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  fail "This script only supports Ubuntu and Debian"
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
  fail "Unsupported architecture: $ARCH"
fi

log "✅ OS: $PRETTY_NAME ($ARCH)"

# Check disk space
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
REQUIRED_SPACE=50000000  # 50GB in KB

if [[ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]]; then
  warn "Available disk space: $(($AVAILABLE_SPACE / 1024 / 1024))GB"
  warn "Recommended: 50GB+"
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      fail "Installation cancelled"
    fi
  fi
else
  log "✅ Disk space: $(($AVAILABLE_SPACE / 1024 / 1024))GB available"
fi

# Check memory
TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
if [[ $TOTAL_MEM -lt 4000 ]]; then
  warn "Total memory: ${TOTAL_MEM}MB"
  warn "Recommended: 4GB+"
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      fail "Installation cancelled"
    fi
  fi
else
  log "✅ Memory: ${TOTAL_MEM}MB"
fi

# Update system packages
log "Updating system packages..."
sudo apt update -y

# Install required packages
log "Installing required packages..."
sudo apt install -y \
  curl \
  wget \
  jq \
  ca-certificates \
  gnupg \
  lsb-release \
  zstd \
  unzip \
  htop \
  net-tools

# Install Docker
if ! command -v docker &> /dev/null; then
  log "Installing Docker..."
  
  # Add Docker's official GPG key
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  
  # Set up the repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Install Docker Engine
  sudo apt update -y
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  # Add user to docker group
  sudo usermod -aG docker $USER
  
  log "✅ Docker installed successfully"
else
  log "✅ Docker already installed"
fi

# Install Docker Compose
if ! command -v docker compose &> /dev/null; then
  log "Installing Docker Compose..."
  sudo apt install -y docker-compose-plugin
  log "✅ Docker Compose installed successfully"
else
  log "✅ Docker Compose already installed"
fi

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Create project directory
PROJECT_DIR="$HOME/starknet-sepolia"
log "Creating project directory: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create environment file
log "Creating environment configuration..."
cat > .env << 'EOF'
# Starknet Sepolia Configuration
PATHFINDER_DATA_DIR=/usr/share/pathfinder/data
ETHEREUM_RPC_URL=wss://ethereum-sepolia.publicnode.com
STARKNET_RPC_URL=http://localhost:9545
STARKNET_CHAIN_ID=0x534e5f5345504f4c4941
EOF

# Create data directory
sudo mkdir -p /usr/share/pathfinder/data
sudo chown -R $USER:$USER /usr/share/pathfinder

# Function to download Juno snapshot
download_juno_snapshot() {
  log "📥 Downloading Juno snapshot for ultra-fast sync..."
  progress "This may take several minutes depending on your internet connection..."

  # Create snapshot directory
  mkdir -p snapshots
  cd snapshots

  # Try multiple snapshot URLs
  SNAPSHOT_URLS=(
    "https://juno-snapshots.nethermind.dev/files/sepolia/latest"
    "https://juno.nethermind.io/snapshots/starknet-sepolia-latest.tar.zst"
    "https://snapshots.juno.nethermind.io/starknet-sepolia-latest.tar.zst"
  )

  SNAPSHOT_DOWNLOADED=false

  for SNAPSHOT_URL in "${SNAPSHOT_URLS[@]}"; do
    log "Trying snapshot URL: $SNAPSHOT_URL"
    
    # Determine file extension based on URL
    if [[ "$SNAPSHOT_URL" == *".tar.zst" ]]; then
      SNAPSHOT_FILE="starknet-sepolia-latest.tar.zst"
      EXTRACT_CMD="tar --zstd -xf"
    else
      SNAPSHOT_FILE="starknet-sepolia-latest.tar"
      EXTRACT_CMD="tar -xf"
    fi

    if wget -O "$SNAPSHOT_FILE" "$SNAPSHOT_URL" 2>/dev/null; then
      log "✅ Snapshot downloaded successfully from: $SNAPSHOT_URL"
      
      # Extract snapshot
      progress "Extracting snapshot (this may take 10-15 minutes)..."
      if $EXTRACT_CMD "$SNAPSHOT_FILE" -C /usr/share/pathfinder/data; then
        log "✅ Snapshot extracted successfully"
        
        # Set proper permissions
        sudo chown -R $USER:$USER /usr/share/pathfinder/data
        
        # Clean up
        rm -f "$SNAPSHOT_FILE"
        log "✅ Snapshot cleanup completed"
        SNAPSHOT_DOWNLOADED=true
        break
      else
        warn "Failed to extract snapshot from: $SNAPSHOT_URL"
        rm -f "$SNAPSHOT_FILE"
      fi
    else
      warn "Failed to download snapshot from: $SNAPSHOT_URL"
    fi
  done

  if [[ "$SNAPSHOT_DOWNLOADED" == "false" ]]; then
    warn "All snapshot download attempts failed, continuing with normal sync..."
    warn "This will take significantly longer to synchronize"
  fi

  cd "$PROJECT_DIR"
}

# Download and apply Juno snapshot
download_juno_snapshot

cd "$PROJECT_DIR"

# Create Docker Compose file
log "Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  pathfinder:
    image: eqlabs/pathfinder:latest
    container_name: starknet-pathfinder
    restart: unless-stopped
    ports:
      - "9545:9545"
      - "9187:9187"
    volumes:
      - /usr/share/pathfinder/data:/usr/share/pathfinder/data
    environment:
      - PATHFINDER_DATA_DIR=/usr/share/pathfinder/data
      - ETHEREUM_RPC_URL=wss://ethereum-sepolia.publicnode.com
      - STARKNET_RPC_URL=http://localhost:9545
      - STARKNET_CHAIN_ID=0x534e5f5345504f4c4941
    command: >
      --ethereum.url ${ETHEREUM_RPC_URL}
      --http-rpc-address 0.0.0.0
      --http-rpc-port 9545
      --chain-id ${STARKNET_CHAIN_ID}
      --metrics-address 0.0.0.0
      --metrics-port 9187
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9545"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  prometheus:
    image: prom/prometheus:latest
    container_name: starknet-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    container_name: starknet-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana

  node-exporter:
    image: prom/node-exporter:latest
    container_name: starknet-node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  grafana-storage:
EOF

# Create Prometheus configuration
log "Creating Prometheus configuration..."
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'pathfinder'
    static_configs:
      - targets: ['pathfinder:9187']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Configure firewall
log "Configuring firewall..."
if command -v ufw &> /dev/null; then
  sudo ufw --force enable
  sudo ufw allow 22/tcp
  sudo ufw allow 9545/tcp
  sudo ufw allow 9090/tcp
  sudo ufw allow 3000/tcp
  sudo ufw allow 9100/tcp
  sudo ufw allow 9187/tcp
  log "✅ Firewall configured"
else
  warn "UFW not found, please configure firewall manually"
fi

# Start services
log "Starting Starknet Sepolia node with monitoring..."
docker compose up -d

# Wait for services to start
log "Waiting for services to start..."
sleep 30

# Verify installation
log "Verifying installation..."

# Check if containers are running
if docker compose ps | grep -q "Up"; then
  log "✅ Containers are running"
else
  fail "❌ Some containers failed to start"
fi

# Check RPC endpoint
log "Testing RPC endpoint..."
sleep 10

if curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"starknet_blockNumber","params":[],"id":1}' \
  http://localhost:9545 | jq -r '.result' > /dev/null 2>&1; then
  log "✅ RPC endpoint is working"
else
  warn "⚠️  RPC endpoint not ready yet, may need more time to sync"
fi

# Show status
echo ""
log "🎉 Installation completed successfully!"
echo ""
echo -e "${WHITE}========================================${NC}"
echo -e "${WHITE}           SERVICE STATUS${NC}"
echo -e "${WHITE}========================================${NC}"
docker compose ps
echo ""
echo -e "${WHITE}========================================${NC}"
echo -e "${WHITE}           USEFUL COMMANDS${NC}"
echo -e "${WHITE}========================================${NC}"
echo -e "${CYAN}• View logs:${NC} docker compose logs -f pathfinder"
echo -e "${CYAN}• RPC endpoint:${NC} http://localhost:9545"
echo -e "${CYAN}• Metrics:${NC} http://localhost:9187"
echo -e "${CYAN}• Prometheus:${NC} http://localhost:9090"
echo -e "${CYAN}• Grafana:${NC} http://localhost:3000 (admin/admin)"
echo -e "${CYAN}• Stop services:${NC} docker compose down"
echo -e "${CYAN}• Restart services:${NC} docker compose restart"
echo ""
echo -e "${GREEN}🚀 Your Starknet Sepolia node is now running with ultra-fast sync!${NC}"
echo -e "${YELLOW}📊 Monitor sync progress in Grafana or check logs${NC}"
echo ""
