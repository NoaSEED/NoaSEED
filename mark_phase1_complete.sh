#!/bin/bash

# Mark Phase 1 as Complete
# Crea el marcador de que Phase 1 está completa

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }

echo -e "${BLUE}🔧 Mark Phase 1 as Complete${NC}"
echo ""

# Go to validator directory
cd ~/starknet-validator

# Create phase1 completion marker
progress "Creating Phase 1 completion marker..."
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

log "✅ Phase 1 marked as complete!"

# Verify the marker was created
if [[ -f "phase1_complete.json" ]]; then
    log "✅ Marker file created successfully"
    echo ""
    echo -e "${CYAN}📄 Phase 1 completion marker:${NC}"
    cat phase1_complete.json
    echo ""
    echo -e "${GREEN}🎉 Phase 1 is now marked as complete!${NC}"
    echo -e "${GREEN}You can now proceed with Phase 2!${NC}"
else
    echo -e "${RED}❌ Failed to create marker file${NC}"
    exit 1
fi
