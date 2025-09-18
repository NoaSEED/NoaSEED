#!/bin/bash

# SEEDNodes - Terminal Dashboard Launcher
# Simple launcher for the terminal-based validator dashboard

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

                    SEEDNodes - Terminal Dashboard
EOF
echo -e "${NC}"

echo -e "${BLUE}🚀 Launching Terminal Dashboard...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_SCRIPT="$SCRIPT_DIR/scripts/starknet_terminal_dashboard.sh"

# Check if dashboard script exists
if [[ ! -f "$DASHBOARD_SCRIPT" ]]; then
    echo -e "${RED}Error: Terminal dashboard script not found at $DASHBOARD_SCRIPT${NC}"
    exit 1
fi

# Make sure it's executable
chmod +x "$DASHBOARD_SCRIPT"

echo -e "${CYAN}📊 Terminal Dashboard Features:${NC}"
echo "  • Phase 1: Sepolia Node Setup (Pathfinder + Monitoring)"
echo "  • Phase 2: Validator Staking (Wallets + STRK Staking)"
echo "  • System Monitoring & Management"
echo "  • Log Viewer & Troubleshooting"
echo ""
echo -e "${GREEN}Starting terminal dashboard...${NC}"

# Launch the terminal dashboard
exec "$DASHBOARD_SCRIPT"
