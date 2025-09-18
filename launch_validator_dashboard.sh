#!/bin/bash

# SEEDNodes - Starknet Validator Dashboard Launcher
# Simple launcher for the multi-phase validator dashboard

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}"
cat << "EOF"
    ███████╗███████╗███████╗██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗███████╗
    ██╔════╝██╔════╝██╔════╝██╔══██╗████╗  ██║██╔═══██╗██╔══██╗██╔════╝██╔════╝
    ███████╗█████╗  █████╗  ██║  ██║██╔██╗ ██║██║   ██║██║  ██║█████╗  ███████╗
    ╚════██║██╔══╝  ██╔══╝  ██║  ██║██║╚██╗██║██║   ██║██║  ██║██╔══╝  ╚════██║
    ███████║███████╗███████╗██████╔╝██║ ╚████║╚██████╔╝██████╔╝███████╗███████║
    ╚══════╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝

                    SEEDNodes - Starknet Validator Dashboard
EOF
echo -e "${NC}"

echo -e "${BLUE}🚀 Launching Starknet Validator Dashboard...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_SCRIPT="$SCRIPT_DIR/scripts/starknet_validator_dashboard.sh"

# Check if dashboard script exists
if [[ ! -f "$DASHBOARD_SCRIPT" ]]; then
    echo -e "${RED}Error: Dashboard script not found at $DASHBOARD_SCRIPT${NC}"
    exit 1
fi

# Make sure it's executable
chmod +x "$DASHBOARD_SCRIPT"

echo -e "${CYAN}📊 Dashboard Features:${NC}"
echo "  • Phase 1: Sepolia Node Setup (Pathfinder + Monitoring)"
echo "  • Phase 2: Validator Staking (Wallets + STRK Staking)"
echo "  • Phase 3: BTC Pool Integration (Liquidity Pools)"
echo ""
echo -e "${CYAN}🌐 Dashboard will be available at: http://localhost:8080${NC}"
echo ""
echo -e "${GREEN}Starting dashboard...${NC}"

# Launch the dashboard
exec "$DASHBOARD_SCRIPT"
