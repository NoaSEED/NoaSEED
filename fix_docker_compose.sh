#!/bin/bash

# Fix Docker Compose - Direct Solution
# Soluciona el problema del docker-compose directamente

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }

echo -e "${BLUE}🔧 Fix Docker Compose Configuration${NC}"
echo ""

# Go to validator directory
cd ~/starknet-validator

# Stop all services
progress "Stopping all services..."
docker compose -f compose/starknet-sepolia.docker-compose.yml down 2>/dev/null || true

# Remove problematic containers
progress "Cleaning up containers..."
docker rm -f starknet-pathfinder starknet-prometheus starknet-grafana starknet-node-exporter 2>/dev/null || true

# Create proper env file
progress "Creating environment file..."
mkdir -p env
cat > env/starknet-sepolia.env << 'EOF'
PATHFINDER_DATA_DIR=/usr/share/pathfinder/data
ETHEREUM_RPC_URL=wss://ethereum-sepolia.publicnode.com
STARKNET_RPC_URL=http://localhost:9545
STARKNET_CHAIN_ID=0x534e5f5345504f4c4941
EOF

# Check if docker-compose file exists
if [[ ! -f "compose/starknet-sepolia.docker-compose.yml" ]]; then
    fail "Docker compose file not found!"
fi

# Start services with explicit env file
progress "Starting services with explicit environment..."
docker compose --env-file env/starknet-sepolia.env -f compose/starknet-sepolia.docker-compose.yml up -d

# Wait for services
progress "Waiting for services to start..."
sleep 30

# Check status
progress "Checking service status..."
docker compose -f compose/starknet-sepolia.docker-compose.yml ps

# Test RPC
progress "Testing RPC endpoint..."
sleep 10
if curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"starknet_chainId","params":[],"id":1}' \
  http://localhost:9545 | grep -q "0x534e5f5345504f4c4941"; then
    log "✅ RPC endpoint working!"
else
    warn "⚠️ RPC endpoint not responding yet"
fi

echo ""
log "✅ Docker Compose fix completed!"
echo ""
echo -e "${CYAN}📊 Service Status:${NC}"
docker compose -f compose/starknet-sepolia.docker-compose.yml ps
echo ""
echo -e "${GREEN}🎉 Services should now be running correctly!${NC}"
