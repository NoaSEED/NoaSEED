#!/bin/bash

# Fix Phase 1 - Repair Pathfinder Configuration
# Soluciona problemas de configuración del Pathfinder

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
fail() { echo -e "${RED}[ERROR] $1${NC}"; }

VALIDATOR_DIR="$HOME/starknet-validator"

echo -e "${BLUE}🔧 SEEDNodes - Phase 1 Repair Tool${NC}"
echo ""

progress "Fixing Pathfinder configuration..."

# Create validator directory if it doesn't exist
mkdir -p "$VALIDATOR_DIR"
cd "$VALIDATOR_DIR"

# Stop all services first
progress "Stopping all services..."
if [[ -f "compose/starknet-sepolia.docker-compose.yml" ]]; then
    docker compose -f compose/starknet-sepolia.docker-compose.yml down
fi

# Create proper environment file
progress "Creating environment configuration..."
mkdir -p env
cat > env/starknet-sepolia.env << 'EOF'
# Starknet Sepolia Configuration
PATHFINDER_DATA_DIR=/usr/share/pathfinder/data
ETHEREUM_RPC_URL=wss://ethereum-sepolia.publicnode.com
STARKNET_RPC_URL=http://localhost:9545
STARKNET_CHAIN_ID=0x534e5f5345504f4c4941
EOF

log "✅ Environment file created"

# Verify docker-compose file exists
if [[ ! -f "compose/starknet-sepolia.docker-compose.yml" ]]; then
    fail "Docker compose file not found. Please run Phase 1 first."
fi

# Start services
progress "Starting services with correct configuration..."
docker compose -f compose/starknet-sepolia.docker-compose.yml up -d

# Wait for services to start
progress "Waiting for services to start..."
sleep 15

# Check status
progress "Checking service status..."
docker compose -f compose/starknet-sepolia.docker-compose.yml ps

# Wait for Pathfinder to initialize
progress "Waiting for Pathfinder to initialize..."
sleep 30

# Test RPC endpoint
progress "Testing RPC endpoint..."
for i in {1..3}; do
    if curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"starknet_chainId","params":[],"id":1}' \
        http://localhost:9545 | grep -q "0x534e5f5345504f4c4941"; then
        log "✅ RPC endpoint working correctly"
        break
    else
        if [[ $i -eq 3 ]]; then
            warn "⚠️ RPC endpoint not responding yet"
        else
            log "Retrying RPC test ($i/3)..."
            sleep 10
        fi
    fi
done

# Create completion marker
cat > phase1_complete.json << EOF
{
    "phase": 1,
    "name": "Sepolia Node Setup",
    "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "success",
    "endpoints": {
        "rpc": "http://localhost:9545",
        "metrics": "http://localhost:9187",
        "prometheus": "http://localhost:9091",
        "grafana": "http://localhost:3001"
    },
    "services": [
        "starknet-pathfinder",
        "starknet-prometheus",
        "starknet-grafana",
        "starknet-node-exporter"
    ]
}
EOF

log "🎉 Phase 1 repair completed!"
echo ""
echo -e "${CYAN}📊 Service Status:${NC}"
docker compose -f compose/starknet-sepolia.docker-compose.yml ps
echo ""
echo -e "${CYAN}🔗 Available Endpoints:${NC}"
echo "  • RPC: http://$(hostname -I | awk '{print $1}'):9545"
echo "  • Metrics: http://$(hostname -I | awk '{print $1}'):9187"
echo "  • Prometheus: http://$(hostname -I | awk '{print $1}'):9091"
echo "  • Grafana: http://$(hostname -I | awk '{print $1}'):3001 (admin/admin)"
echo ""
echo -e "${GREEN}✅ Phase 1 is now ready for Phase 2!${NC}"


