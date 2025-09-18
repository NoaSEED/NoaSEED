#!/bin/bash

# SEEDNodes - Starknet Validator Terminal Dashboard
# Interactive terminal-based dashboard for Starknet validator setup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
VALIDATOR_DIR="$HOME/starknet-validator"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to install jq if not available
install_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Installing jq..."
        sudo apt update && sudo apt install -y jq
        if command -v jq >/dev/null 2>&1; then
            echo "✅ jq installed successfully"
        else
            echo "❌ Failed to install jq"
        fi
    fi
}

# Phase status
PHASE1_COMPLETE=false
PHASE2_COMPLETE=false

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
fail() { echo -e "${RED}[ERROR] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
phase() { echo -e "${PURPLE}[PHASE] $1${NC}"; }
info() { echo -e "${CYAN}[INFO] $1${NC}"; }

show_banner() {
  clear
  echo -e "${WHITE}"
  cat << "EOF"
    ███████╗███████╗███████╗██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗███████╗
    ██╔════╝██╔════╝██╔════╝██╔══██╗████╗  ██║██╔═══██╗██╔══██╗██╔════╝██╔════╝
    ███████╗█████╗  █████╗  ██║  ██║██╔██╗ ██║██║   ██║██║  ██║█████╗  ███████╗
    ╚════██║██╔══╝  ██╔══╝  ██║  ██║██║╚██╗██║██║   ██║██║  ██║██╔══╝  ╚════██║
    ███████║███████╗███████╗██████╔╝██║ ╚████║╚██████╔╝██████╔╝███████╗███████║
    ╚══════╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝

                    SEEDNodes - Starknet Validator Terminal Dashboard
                              Interactive Setup & Management
EOF
  echo -e "${NC}"
}

check_phase_status() {
  if [[ -f "$VALIDATOR_DIR/phase1_complete.json" ]]; then
    PHASE1_COMPLETE=true
  fi
  if [[ -f "$VALIDATOR_DIR/phase2_complete.json" ]]; then
    PHASE2_COMPLETE=true
  fi
}

show_status() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           SYSTEM STATUS${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  
  # Phase 1 Status
  if [[ "$PHASE1_COMPLETE" == "true" ]]; then
    echo -e "${GREEN}✅ Phase 1: Sepolia Node Setup - COMPLETE${NC}"
  else
    echo -e "${YELLOW}⏳ Phase 1: Sepolia Node Setup - PENDING${NC}"
  fi
  
  # Phase 2 Status
  if [[ "$PHASE2_COMPLETE" == "true" ]]; then
    echo -e "${GREEN}✅ Phase 2: Validator Staking - COMPLETE${NC}"
  else
    echo -e "${YELLOW}⏳ Phase 2: Validator Staking - PENDING${NC}"
  fi
  
  
  echo ""
  
  # System Status
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker: Running${NC}"
  else
    echo -e "${RED}❌ Docker: Not running${NC}"
  fi
  
  if command -v python3 >/dev/null; then
    echo -e "${GREEN}✅ Python3: Available${NC}"
  else
    echo -e "${RED}❌ Python3: Not installed${NC}"
  fi
  
  if command -v curl >/dev/null; then
    echo -e "${GREEN}✅ Curl: Available${NC}"
  else
    echo -e "${RED}❌ Curl: Not installed${NC}"
  fi
  
  echo ""
}

show_menu() {
  echo -e "${WHITE}========================================${NC}"
  echo -e "${WHITE}           MAIN MENU${NC}"
  echo -e "${WHITE}========================================${NC}"
  echo ""
  echo -e "${CYAN}1. 🚀 Phase 1: Sepolia Node Setup${NC}"
  echo -e "${CYAN}2. ⚡ Phase 2: Validator Staking${NC}"
  echo -e "${CYAN}3. 📊 System Status & Monitoring${NC}"
  echo -e "${CYAN}4. 🔧 Management Tools${NC}"
  echo -e "${CYAN}5. 📋 View Logs${NC}"
  echo -e "${CYAN}6. 🆘 Help & Documentation${NC}"
  echo -e "${CYAN}0. 🚪 Exit${NC}"
  echo ""
  echo -e "${YELLOW}Select an option (0-6): ${NC}"
}

run_phase1() {
  phase "Starting Phase 1: Sepolia Node Setup"
  
  if [[ "$PHASE1_COMPLETE" == "true" ]]; then
    warn "Phase 1 is already complete!"
    read -p "Do you want to reinstall? (y/n): " reinstall
    if [[ "$reinstall" != "y" ]]; then
      return 0
    fi
  fi
  
  progress "Installing Sepolia Node with Pathfinder..."
  
  # Check if original script exists
  ORIGINAL_SCRIPT="$SCRIPT_DIR/starknet_bitcoin_oneclick.sh"
  if [[ ! -f "$ORIGINAL_SCRIPT" ]]; then
    fail "Original starknet script not found at $ORIGINAL_SCRIPT"
  fi
  
  # Run Phase 1 script
  if [[ -f "$SCRIPT_DIR/phase1_sepolia_node.sh" ]]; then
    log "Running Phase 1 script..."
    "$SCRIPT_DIR/phase1_sepolia_node.sh"
  else
    log "Running original starknet script..."
    "$ORIGINAL_SCRIPT" \
      --yes \
      --eth-ws "wss://ethereum-sepolia.publicnode.com" \
      --data-dir "$VALIDATOR_DIR/pathfinder-data" \
      --rpc-port 9545 \
      --monitoring Y \
      --grafana-port 3001 \
      --prom-port 9091 \
      --node-exporter-port 9101
  fi
  
  if [[ $? -eq 0 ]]; then
    log "✅ Phase 1 completed successfully!"
    PHASE1_COMPLETE=true
  else
    fail "❌ Phase 1 failed. Check logs for details."
  fi
}

run_phase2() {
  phase "Starting Phase 2: Validator Staking"
  
  if [[ "$PHASE1_COMPLETE" != "true" ]]; then
    fail "Phase 1 must be completed first!"
    return 1
  fi
  
  if [[ "$PHASE2_COMPLETE" == "true" ]]; then
    warn "Phase 2 is already complete!"
    read -p "Do you want to reconfigure? (y/n): " reconfigure
    if [[ "$reconfigure" != "y" ]]; then
      return 0
    fi
  fi
  
  progress "Setting up validator wallets and staking..."
  
  # Run Phase 2 script
  if [[ -f "$SCRIPT_DIR/phase2_validator_staking.sh" ]]; then
    log "Running Phase 2 script..."
    "$SCRIPT_DIR/phase2_validator_staking.sh"
  else
    fail "Phase 2 script not found!"
  fi
  
  if [[ $? -eq 0 ]]; then
    log "✅ Phase 2 completed successfully!"
    PHASE2_COMPLETE=true
  else
    fail "❌ Phase 2 failed. Check logs for details."
  fi
}


show_monitoring() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           MONITORING & STATUS${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  
  # Docker containers
  echo -e "${CYAN}🐳 Docker Containers:${NC}"
  if command -v docker >/dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"
  else
    echo "Docker not available"
  fi
  echo ""
  
  # System resources
  echo -e "${CYAN}💻 System Resources:${NC}"
  echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
  echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
  echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"
  echo ""
  
  # Network status
  echo -e "${CYAN}🌐 Network Status:${NC}"
  echo "External IP: $(curl -s ifconfig.me 2>/dev/null || echo 'Unable to get IP')"
  echo "Local IP: $(hostname -I | awk '{print $1}')"
  echo ""
  
  # Endpoints
  echo -e "${CYAN}🔗 Available Endpoints:${NC}"
  if [[ "$PHASE1_COMPLETE" == "true" ]]; then
    echo "RPC: http://$(hostname -I | awk '{print $1}'):9545"
    echo "Grafana: http://$(hostname -I | awk '{print $1}'):3001"
    echo "Prometheus: http://$(hostname -I | awk '{print $1}'):9091"
  else
    echo "Endpoints not available (Phase 1 not complete)"
  fi
  echo ""
}

show_management() {
  while true; do
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}           MANAGEMENT TOOLS${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${CYAN}1. 🔄 Restart Services${NC}"
    echo -e "${CYAN}2. 🛑 Stop All Services${NC}"
    echo -e "${CYAN}3. 🧹 Clean System${NC}"
    echo -e "${CYAN}4. 📦 Update System${NC}"
    echo -e "${CYAN}5. 🔐 Manage Wallets${NC}"
    echo -e "${CYAN}6. 📊 Validator Status${NC}"
    echo -e "${CYAN}7. 🔍 Check RPC Health${NC}"
    echo -e "${CYAN}8. 💾 Backup Wallets${NC}"
    echo -e "${CYAN}9. 📈 View Metrics${NC}"
    echo -e "${CYAN}0. ⬅️ Back to Main Menu${NC}"
    echo ""
    echo -e "${YELLOW}Select an option (0-9): ${NC}"
    
    read -r choice
    case $choice in
      1)
        progress "Restarting services..."
        if [[ -f "$VALIDATOR_DIR/compose/starknet-sepolia.docker-compose.yml" ]]; then
          cd "$VALIDATOR_DIR"
          docker compose -f compose/starknet-sepolia.docker-compose.yml restart
          log "✅ Services restarted successfully"
          echo "Services status:"
          docker compose -f compose/starknet-sepolia.docker-compose.yml ps
        else
          warn "❌ No services to restart - docker-compose file not found"
        fi
        read -p "Press Enter to continue..."
        ;;
      2)
        progress "Stopping all services..."
        if [[ -f "$VALIDATOR_DIR/compose/starknet-sepolia.docker-compose.yml" ]]; then
          cd "$VALIDATOR_DIR"
          docker compose -f compose/starknet-sepolia.docker-compose.yml down
          log "✅ All services stopped successfully"
          echo "Checking if containers are stopped:"
          docker ps | grep starknet || echo "No starknet containers running"
        else
          warn "❌ No services to stop - docker-compose file not found"
        fi
        read -p "Press Enter to continue..."
        ;;
      3)
        progress "Cleaning system..."
        echo "Cleaning Docker system..."
        docker system prune -f
        echo "Cleaning unused images..."
        docker image prune -f
        echo "Cleaning unused volumes..."
        docker volume prune -f
        log "✅ System cleaned successfully"
        echo "Disk usage after cleanup:"
        df -h / | tail -1
        read -p "Press Enter to continue..."
        ;;
      4)
        progress "Updating system..."
        echo "Updating package lists..."
        sudo apt update
        echo "Upgrading packages..."
        sudo apt upgrade -y
        echo "Cleaning up..."
        sudo apt autoremove -y
        sudo apt autoclean
        log "✅ System updated successfully"
        read -p "Press Enter to continue..."
        ;;
      5)
        progress "Managing wallets..."
        install_jq
        echo "🔍 Checking wallet status..."
        
        # Check if wallets directory exists
        if [[ -d "$VALIDATOR_DIR/wallets" ]]; then
          echo "✅ Wallets directory found: $VALIDATOR_DIR/wallets"
          echo ""
          echo "📁 Wallet files:"
          ls -la "$VALIDATOR_DIR/wallets/" 2>/dev/null || echo "No wallet files found"
          
          # Check for specific wallet files
          if [[ -f "$VALIDATOR_DIR/wallets/staking_wallet.json" ]]; then
            echo "✅ Staking wallet found"
          fi
          if [[ -f "$VALIDATOR_DIR/wallets/operational_wallet.json" ]]; then
            echo "✅ Operational wallet found"
          fi
          if [[ -f "$VALIDATOR_DIR/wallets/rewards_wallet.json" ]]; then
            echo "✅ Rewards wallet found"
          fi
        else
          echo "❌ No wallets directory found"
          echo "Creating wallets directory..."
          mkdir -p "$VALIDATOR_DIR/wallets"
          echo "✅ Wallets directory created"
        fi
        
        # Check validator config
        if [[ -f "$VALIDATOR_DIR/validator_config.json" ]]; then
          echo ""
          echo "📋 Validator configuration:"
          if command -v jq >/dev/null 2>&1; then
            cat "$VALIDATOR_DIR/validator_config.json" | jq .
          else
            echo "jq not installed, showing raw config:"
            cat "$VALIDATOR_DIR/validator_config.json"
          fi
        else
          echo "❌ No validator config found"
        fi
        read -p "Press Enter to continue..."
        ;;
      6)
        progress "Checking validator status..."
        install_jq
        echo "🔍 Checking validator configuration..."
        
        # Check validator config file
        if [[ -f "$VALIDATOR_DIR/validator_config.json" ]]; then
          echo "✅ Validator config found"
          echo ""
          echo "📋 Configuration details:"
          if command -v jq >/dev/null 2>&1; then
            cat "$VALIDATOR_DIR/validator_config.json" | jq .
          else
            echo "jq not installed, showing raw config:"
            cat "$VALIDATOR_DIR/validator_config.json"
          fi
        else
          echo "❌ No validator config found"
        fi
        
        # Check phase completion
        echo ""
        echo "📊 Phase completion status:"
        if [[ -f "$VALIDATOR_DIR/phase1_complete.json" ]]; then
          echo "✅ Phase 1: Sepolia Node - COMPLETED"
        else
          echo "❌ Phase 1: Sepolia Node - NOT COMPLETED"
        fi
        
        if [[ -f "$VALIDATOR_DIR/phase2_complete.json" ]]; then
          echo "✅ Phase 2: Validator Staking - COMPLETED"
        else
          echo "❌ Phase 2: Validator Staking - NOT COMPLETED"
        fi
        
        # Check for staking manager
        if [[ -f "$VALIDATOR_DIR/staking_manager.sh" ]]; then
          echo "✅ Staking manager script found"
        else
          echo "❌ Staking manager script not found"
        fi
        
        # Check for other validator files
        echo ""
        echo "📁 Validator files:"
        ls -la "$VALIDATOR_DIR/" | grep -E "(validator|staking|phase|wallet)" || echo "No validator files found"
        read -p "Press Enter to continue..."
        ;;
      7)
        progress "Checking RPC health..."
        install_jq
        echo "Testing RPC endpoint..."
        RPC_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
          -d '{"jsonrpc":"2.0","method":"starknet_chainId","params":[],"id":1}' \
          http://localhost:9545)
        
        if echo "$RPC_RESPONSE" | grep -q "0x534e5f5345504f4c4941"; then
          log "✅ RPC endpoint is healthy"
          if command -v jq >/dev/null 2>&1; then
            echo "Chain ID: $(echo "$RPC_RESPONSE" | jq -r '.result')"
          else
            echo "Chain ID: $(echo "$RPC_RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)"
          fi
          echo "Response time: $(curl -s -w "%{time_total}" -o /dev/null -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"starknet_chainId","params":[],"id":1}' http://localhost:9545)s"
        else
          warn "⚠️ RPC endpoint not responding"
          echo "Response: $RPC_RESPONSE"
        fi
        
        echo ""
        echo "Testing other endpoints:"
        echo "Metrics endpoint:"
        if curl -s http://localhost:9187/metrics | head -1; then
          echo "✅ Metrics endpoint responding"
        else
          echo "❌ Metrics endpoint not responding"
        fi
        read -p "Press Enter to continue..."
        ;;
      8)
        progress "Creating wallet backup..."
        if [[ -d "$VALIDATOR_DIR/wallets" ]]; then
          BACKUP_DIR="$VALIDATOR_DIR/wallets/backup-$(date +%Y%m%d-%H%M%S)"
          mkdir -p "$BACKUP_DIR"
          
          # Copy wallet files
          cp "$VALIDATOR_DIR/wallets"/*.json "$BACKUP_DIR/" 2>/dev/null || true
          
          # Copy validator config
          if [[ -f "$VALIDATOR_DIR/validator_config.json" ]]; then
            cp "$VALIDATOR_DIR/validator_config.json" "$BACKUP_DIR/"
          fi
          
          # Create backup info
          cat > "$BACKUP_DIR/backup_info.txt" << EOF
# Wallet Backup Information
Created: $(date)
Source: $VALIDATOR_DIR/wallets/
Backup: $BACKUP_DIR/

Files backed up:
$(ls -la "$BACKUP_DIR" | grep -v "backup_info.txt")

Security Note: Keep this backup secure and encrypted!
EOF
          
          log "✅ Wallets backed up successfully"
          echo "Backup location: $BACKUP_DIR"
          echo "Files backed up:"
          ls -la "$BACKUP_DIR"
        else
          warn "❌ No wallets to backup"
          echo "Wallets directory not found at: $VALIDATOR_DIR/wallets"
        fi
        read -p "Press Enter to continue..."
        ;;
      9)
        progress "Viewing metrics information..."
        echo "Available metrics endpoints:"
        echo ""
        echo "📊 Prometheus (Metrics Collection):"
        echo "  URL: http://$(hostname -I | awk '{print $1}'):9091"
        echo "  Local: http://localhost:9091"
        echo ""
        echo "📈 Grafana (Dashboards):"
        echo "  URL: http://$(hostname -I | awk '{print $1}'):3001"
        echo "  Local: http://localhost:3001"
        echo "  Login: admin/admin"
        echo ""
        echo "🔍 Node Metrics (Raw):"
        echo "  URL: http://$(hostname -I | awk '{print $1}'):9187"
        echo "  Local: http://localhost:9187"
        echo ""
        echo "Testing endpoints..."
        for port in 9091 3001 9187; do
          if curl -s "http://localhost:$port" >/dev/null 2>&1; then
            echo "✅ Port $port: Responding"
          else
            echo "❌ Port $port: Not responding"
          fi
        done
        read -p "Press Enter to continue..."
        ;;
      0)
        return 0
        ;;
      *)
        warn "Invalid option. Please select 0-9."
        sleep 2
        ;;
    esac
  done
}

show_logs() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           LOG VIEWER${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo -e "${CYAN}1. 📋 Node Logs${NC}"
  echo -e "${CYAN}2. 🔧 System Logs${NC}"
  echo -e "${CYAN}3. 🐳 Docker Logs${NC}"
  echo -e "${CYAN}4. 📊 Validator Logs${NC}"
  echo -e "${CYAN}0. ⬅️ Back to Main Menu${NC}"
  echo ""
  echo -e "${YELLOW}Select an option (0-4): ${NC}"
  
  read -r choice
  case $choice in
    1)
      if [[ -f "$VALIDATOR_DIR/compose/starknet-sepolia.docker-compose.yml" ]]; then
        docker compose -f "$VALIDATOR_DIR/compose/starknet-sepolia.docker-compose.yml" logs -f --tail=50 pathfinder
      else
        warn "Node not running"
      fi
      ;;
    2)
      journalctl -f --lines=50
      ;;
    3)
      docker logs --tail=50 $(docker ps -q)
      ;;
    4)
      if [[ -f "$VALIDATOR_DIR/staking_manager.sh" ]]; then
        "$VALIDATOR_DIR/staking_manager.sh" status
      else
        warn "Validator not configured"
      fi
      ;;
    0)
      return 0
      ;;
    *)
      warn "Invalid option"
      ;;
  esac
}

show_help() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           HELP & DOCUMENTATION${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo -e "${CYAN}📚 SEEDNodes Starknet Validator Dashboard${NC}"
  echo ""
  echo -e "${YELLOW}Phase 1: Sepolia Node Setup${NC}"
  echo "  • Installs Pathfinder node for Starknet Sepolia"
  echo "  • Sets up monitoring with Prometheus & Grafana"
  echo "  • Configures RPC endpoints and health checks"
  echo ""
  echo -e "${YELLOW}Phase 2: Validator Staking${NC}"
  echo "  • Creates validator wallets (staking, operational, rewards)"
  echo "  • Sets up STRK staking for Sepolia testnet"
  echo "  • Configures commission and delegation pools"
  echo ""
  echo -e "${CYAN}🔗 Useful Commands:${NC}"
  echo "  • Check status: docker ps"
  echo "  • View logs: docker logs <container>"
  echo "  • Restart: docker compose restart"
  echo "  • Stop all: docker compose down"
  echo ""
  echo -e "${CYAN}📞 Support:${NC}"
  echo "  • GitHub: https://github.com/NoaSEED"
  echo "  • Documentation: See VALIDATOR_DASHBOARD_README.md"
  echo ""
  read -p "Press Enter to continue..."
}

main() {
  while true; do
    show_banner
    check_phase_status
    show_status
    show_menu
    
    read -r choice
    case $choice in
      1)
        run_phase1
        read -p "Press Enter to continue..."
        ;;
      2)
        run_phase2
        read -p "Press Enter to continue..."
        ;;
      3)
        show_monitoring
        read -p "Press Enter to continue..."
        ;;
      4)
        show_management
        ;;
      5)
        show_logs
        ;;
      6)
        show_help
        ;;
      0)
        echo -e "${GREEN}Goodbye! 👋${NC}"
        exit 0
        ;;
      *)
        warn "Invalid option. Please select 0-6."
        sleep 2
        ;;
    esac
  done
}

# Run main function
main "$@"
