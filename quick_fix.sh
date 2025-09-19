#!/bin/bash

# Quick Fix for Phase 1 - Simple and Direct
# Soluciona el problema de variables de entorno

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }

echo -e "${BLUE}🔧 Quick Fix for Phase 1${NC}"
echo ""

# Go to validator directory
cd ~/starknet-validator

# Stop services
progress "Stopping services..."
docker compose -f compose/starknet-sepolia.docker-compose.yml down

# Create proper env file
progress "Creating environment file..."
cat > env/starknet-sepolia.env << 'EOF'
PATHFINDER_DATA_DIR=/usr/share/pathfinder/data
ETHEREUM_RPC_URL=wss://ethereum-sepolia.publicnode.com
STARKNET_RPC_URL=http://localhost:9545
STARKNET_CHAIN_ID=0x534e5f5345504f4c4941
EOF

# Export variables
export PATHFINDER_DATA_DIR="/usr/share/pathfinder/data"
export ETHEREUM_RPC_URL="wss://ethereum-sepolia.publicnode.com"
export STARKNET_RPC_URL="http://localhost:9545"
export STARKNET_CHAIN_ID="0x534e5f5345504f4c4941"

log "✅ Environment variables set"

# Start services
progress "Starting services..."
docker compose -f compose/starknet-sepolia.docker-compose.yml up -d

# Wait
progress "Waiting for services to start..."
sleep 20

# Check status
progress "Checking status..."
docker compose -f compose/starknet-sepolia.docker-compose.yml ps

# Test RPC
progress "Testing RPC..."
sleep 10
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"starknet_chainId","params":[],"id":1}' \
  http://localhost:9545

echo ""
log "✅ Quick fix completed!"
echo ""
echo -e "${CYAN}📊 Service Status:${NC}"
docker compose -f compose/starknet-sepolia.docker-compose.yml ps
echo ""
echo -e "${GREEN}🎉 Phase 1 should now be working!${NC}"


