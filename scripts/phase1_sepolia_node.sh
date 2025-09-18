#!/bin/bash

# Phase 1: Sepolia Node Setup
# Part of SEEDNodes Validator Dashboard

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
fail() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

VALIDATOR_DIR="$HOME/starknet-validator"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're being called from dashboard
if [[ "$1" == "--dashboard" ]]; then
    DASHBOARD_MODE=true
else
    DASHBOARD_MODE=false
fi

progress "Starting Phase 1: Sepolia Node Setup"

# Create validator directory
mkdir -p "$VALIDATOR_DIR"
cd "$VALIDATOR_DIR"

# Check if original script exists
ORIGINAL_SCRIPT="$SCRIPT_DIR/starknet_bitcoin_oneclick.sh"
if [[ ! -f "$ORIGINAL_SCRIPT" ]]; then
    fail "Original starknet script not found at $ORIGINAL_SCRIPT"
fi

# Make script executable
chmod +x "$ORIGINAL_SCRIPT"

# Run the original script with our parameters
log "Running Starknet Sepolia setup..."
"$ORIGINAL_SCRIPT" \
    --yes \
    --eth-ws "wss://ethereum-sepolia.publicnode.com" \
    --data-dir "$VALIDATOR_DIR/pathfinder-data" \
    --rpc-port 9545 \
    --monitoring Y \
    --grafana-port 3001 \
    --prom-port 9091 \
    --node-exporter-port 9101

# Verify installation
progress "Verifying installation..."

# Check if containers are running
if docker compose -f compose/starknet-sepolia.docker-compose.yml ps | grep -q "Up"; then
    log "✅ Pathfinder node is running"
else
    fail "❌ Pathfinder node failed to start"
fi

# Test RPC endpoint
if curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"starknet_chainId","params":[],"id":1}' \
    http://localhost:9545 | grep -q "0x534e5f5345504f4c4941"; then
    log "✅ RPC endpoint responding correctly"
else
    fail "❌ RPC endpoint not responding"
fi

# Test monitoring endpoints
if curl -s http://localhost:9187/metrics | grep -q "starknet"; then
    log "✅ Metrics endpoint working"
else
    warn "⚠️ Metrics endpoint not responding"
fi

# Create phase1 completion marker
cat > "$VALIDATOR_DIR/phase1_complete.json" << EOF
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

log "🎉 Phase 1 completed successfully!"
log "📊 Node Status:"
echo "  • RPC: http://localhost:9545"
echo "  • Metrics: http://localhost:9187"
echo "  • Prometheus: http://localhost:9091"
echo "  • Grafana: http://localhost:3001 (admin/admin)"

if [[ "$DASHBOARD_MODE" == "true" ]]; then
    echo "PHASE1_COMPLETE"
fi
