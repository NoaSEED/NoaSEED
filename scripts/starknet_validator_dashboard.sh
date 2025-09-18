#!/bin/bash

# SEEDNodes - Starknet Validator Dashboard & Multi-Phase Installer
# Phase 1: Sepolia Node Setup
# Phase 2: Validator Staking
# Phase 3: BTC Pool Integration
# Web Dashboard for Management

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
DASHBOARD_PORT=8080
DASHBOARD_DIR="/tmp/starknet-dashboard"
VALIDATOR_DIR="$HOME/starknet-validator"
PHASE1_COMPLETE=false
PHASE2_COMPLETE=false
PHASE3_COMPLETE=false

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

                    SEEDNodes - Starknet Validator Multi-Phase Dashboard
                              Phase 1: Node | Phase 2: Validator | Phase 3: BTC Pool
EOF
  echo -e "${NC}"
}

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
fail() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
phase() { echo -e "${PURPLE}[PHASE] $1${NC}"; }

# Check system requirements
check_requirements() {
  progress "Checking system requirements"
  command -v curl >/dev/null || fail "curl not installed"
  command -v docker >/dev/null || fail "Docker not installed"
  command -v python3 >/dev/null || fail "Python3 not installed"
  
  if ! docker info >/dev/null 2>&1; then
    fail "Docker not running. Start Docker first."
  fi
  
  log "System requirements check passed ✓"
}

# Create dashboard structure
create_dashboard() {
  progress "Creating web dashboard"
  
  mkdir -p "$DASHBOARD_DIR"
  mkdir -p "$VALIDATOR_DIR"
  
  # Create main dashboard HTML
  cat > "$DASHBOARD_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SEEDNodes - Starknet Validator Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { 
            text-align: center; 
            color: white; 
            margin-bottom: 40px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { font-size: 1.2em; opacity: 0.9; }
        .phases { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 30px; }
        .phase-card { 
            background: white; 
            border-radius: 15px; 
            padding: 30px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            transition: transform 0.3s ease;
        }
        .phase-card:hover { transform: translateY(-5px); }
        .phase-card h2 { 
            color: #667eea; 
            margin-bottom: 15px; 
            font-size: 1.5em;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .status { 
            display: inline-block; 
            padding: 5px 15px; 
            border-radius: 20px; 
            font-size: 0.9em; 
            font-weight: bold;
            margin-bottom: 20px;
        }
        .status.pending { background: #ffeaa7; color: #d63031; }
        .status.complete { background: #00b894; color: white; }
        .status.running { background: #74b9ff; color: white; }
        .btn { 
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white; 
            border: none; 
            padding: 12px 25px; 
            border-radius: 25px; 
            cursor: pointer; 
            font-size: 1em;
            transition: all 0.3s ease;
            margin: 5px;
        }
        .btn:hover { transform: scale(1.05); box-shadow: 0 5px 15px rgba(0,0,0,0.3); }
        .btn:disabled { opacity: 0.6; cursor: not-allowed; }
        .info { 
            background: #f8f9fa; 
            padding: 15px; 
            border-radius: 10px; 
            margin: 15px 0;
            border-left: 4px solid #667eea;
        }
        .logs { 
            background: #2d3748; 
            color: #e2e8f0; 
            padding: 15px; 
            border-radius: 10px; 
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            max-height: 200px;
            overflow-y: auto;
            margin-top: 15px;
        }
        .progress-bar { 
            width: 100%; 
            height: 8px; 
            background: #e2e8f0; 
            border-radius: 4px; 
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill { 
            height: 100%; 
            background: linear-gradient(45deg, #667eea, #764ba2);
            transition: width 0.3s ease;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 SEEDNodes Validator Dashboard</h1>
            <p>Starknet Multi-Phase Validator Setup & Management</p>
        </div>
        
        <div class="phases">
            <!-- Phase 1: Node Setup -->
            <div class="phase-card">
                <h2>🚀 Phase 1: Sepolia Node</h2>
                <div class="status pending" id="phase1-status">Pending</div>
                <div class="info">
                    <strong>Setup Starknet Sepolia Node (Pathfinder)</strong><br>
                    • Install Docker & Pathfinder<br>
                    • Configure RPC endpoints<br>
                    • Setup monitoring stack
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="phase1-progress" style="width: 0%"></div>
                </div>
                <button class="btn" onclick="startPhase1()" id="phase1-btn">Start Phase 1</button>
                <button class="btn" onclick="checkPhase1Status()">Check Status</button>
                <div class="logs" id="phase1-logs">Ready to start...</div>
            </div>
            
            <!-- Phase 2: Validator Setup -->
            <div class="phase-card">
                <h2>⚡ Phase 2: Validator Staking</h2>
                <div class="status pending" id="phase2-status">Pending</div>
                <div class="info">
                    <strong>Setup Validator & Stake STRK</strong><br>
                    • Create validator wallets<br>
                    • Stake minimum STRK (1 for Sepolia)<br>
                    • Configure attestation
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="phase2-progress" style="width: 0%"></div>
                </div>
                <button class="btn" onclick="startPhase2()" id="phase2-btn" disabled>Start Phase 2</button>
                <button class="btn" onclick="checkPhase2Status()">Check Status</button>
                <div class="logs" id="phase2-logs">Waiting for Phase 1...</div>
            </div>
            
            <!-- Phase 3: BTC Pool -->
            <div class="phase-card">
                <h2>₿ Phase 3: BTC Pool</h2>
                <div class="status pending" id="phase3-status">Pending</div>
                <div class="info">
                    <strong>Setup BTC Liquidity Pool</strong><br>
                    • Configure BTC bridges<br>
                    • Setup liquidity pools<br>
                    • Enable BTC staking
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="phase3-progress" style="width: 0%"></div>
                </div>
                <button class="btn" onclick="startPhase3()" id="phase3-btn" disabled>Start Phase 3</button>
                <button class="btn" onclick="checkPhase3Status()">Check Status</button>
                <div class="logs" id="phase3-logs">Waiting for Phase 2...</div>
            </div>
        </div>
        
        <!-- System Status -->
        <div class="phase-card" style="margin-top: 30px;">
            <h2>📊 System Status</h2>
            <div id="system-status">
                <div class="info">
                    <strong>Overall Progress:</strong> <span id="overall-progress">0%</span><br>
                    <strong>Active Services:</strong> <span id="active-services">None</span><br>
                    <strong>Last Update:</strong> <span id="last-update">Never</span>
                </div>
            </div>
        </div>
    </div>

    <script>
        let phase1Complete = false;
        let phase2Complete = false;
        let phase3Complete = false;

        // Phase 1 Functions
        async function startPhase1() {
            updateLog('phase1-logs', 'Starting Phase 1: Sepolia Node Setup...');
            updateProgress('phase1-progress', 10);
            updateStatus('phase1-status', 'running', 'Running');
            
            try {
                const response = await fetch('/api/phase1/start', { method: 'POST' });
                const result = await response.json();
                
                if (result.success) {
                    updateLog('phase1-logs', 'Phase 1 completed successfully!');
                    updateProgress('phase1-progress', 100);
                    updateStatus('phase1-status', 'complete', 'Complete');
                    document.getElementById('phase2-btn').disabled = false;
                    phase1Complete = true;
                    updateOverallProgress();
                } else {
                    throw new Error(result.error);
                }
            } catch (error) {
                updateLog('phase1-logs', 'Error: ' + error.message);
                updateStatus('phase1-status', 'pending', 'Failed');
            }
        }

        // Phase 2 Functions
        async function startPhase2() {
            updateLog('phase2-logs', 'Starting Phase 2: Validator Setup...');
            updateProgress('phase2-progress', 10);
            updateStatus('phase2-status', 'running', 'Running');
            
            try {
                const response = await fetch('/api/phase2/start', { method: 'POST' });
                const result = await response.json();
                
                if (result.success) {
                    updateLog('phase2-logs', 'Phase 2 completed successfully!');
                    updateProgress('phase2-progress', 100);
                    updateStatus('phase2-status', 'complete', 'Complete');
                    document.getElementById('phase3-btn').disabled = false;
                    phase2Complete = true;
                    updateOverallProgress();
                } else {
                    throw new Error(result.error);
                }
            } catch (error) {
                updateLog('phase2-logs', 'Error: ' + error.message);
                updateStatus('phase2-status', 'pending', 'Failed');
            }
        }

        // Phase 3 Functions
        async function startPhase3() {
            updateLog('phase3-logs', 'Starting Phase 3: BTC Pool Setup...');
            updateProgress('phase3-progress', 10);
            updateStatus('phase3-status', 'running', 'Running');
            
            try {
                const response = await fetch('/api/phase3/start', { method: 'POST' });
                const result = await response.json();
                
                if (result.success) {
                    updateLog('phase3-logs', 'Phase 3 completed successfully!');
                    updateProgress('phase3-progress', 100);
                    updateStatus('phase3-status', 'complete', 'Complete');
                    phase3Complete = true;
                    updateOverallProgress();
                } else {
                    throw new Error(result.error);
                }
            } catch (error) {
                updateLog('phase3-logs', 'Error: ' + error.message);
                updateStatus('phase3-status', 'pending', 'Failed');
            }
        }

        // Status Check Functions
        async function checkPhase1Status() {
            try {
                const response = await fetch('/api/phase1/status');
                const result = await response.json();
                updateLog('phase1-logs', 'Status: ' + JSON.stringify(result, null, 2));
            } catch (error) {
                updateLog('phase1-logs', 'Error checking status: ' + error.message);
            }
        }

        async function checkPhase2Status() {
            try {
                const response = await fetch('/api/phase2/status');
                const result = await response.json();
                updateLog('phase2-logs', 'Status: ' + JSON.stringify(result, null, 2));
            } catch (error) {
                updateLog('phase2-logs', 'Error checking status: ' + error.message);
            }
        }

        async function checkPhase3Status() {
            try {
                const response = await fetch('/api/phase3/status');
                const result = await response.json();
                updateLog('phase3-logs', 'Status: ' + JSON.stringify(result, null, 2));
            } catch (error) {
                updateLog('phase3-logs', 'Error checking status: ' + error.message);
            }
        }

        // Utility Functions
        function updateLog(elementId, message) {
            const logElement = document.getElementById(elementId);
            const timestamp = new Date().toLocaleTimeString();
            logElement.innerHTML += `[${timestamp}] ${message}\n`;
            logElement.scrollTop = logElement.scrollHeight;
        }

        function updateProgress(elementId, percent) {
            document.getElementById(elementId).style.width = percent + '%';
        }

        function updateStatus(elementId, className, text) {
            const statusElement = document.getElementById(elementId);
            statusElement.className = 'status ' + className;
            statusElement.textContent = text;
        }

        function updateOverallProgress() {
            let total = 0;
            if (phase1Complete) total += 33;
            if (phase2Complete) total += 33;
            if (phase3Complete) total += 34;
            
            document.getElementById('overall-progress').textContent = total + '%';
            document.getElementById('last-update').textContent = new Date().toLocaleString();
        }

        // Auto-refresh status every 30 seconds
        setInterval(async () => {
            try {
                const response = await fetch('/api/status');
                const result = await response.json();
                document.getElementById('active-services').textContent = result.services.join(', ') || 'None';
            } catch (error) {
                console.log('Status check failed:', error);
            }
        }, 30000);
    </script>
</body>
</html>
EOF

  log "Dashboard created at $DASHBOARD_DIR ✓"
}

# Create Python Flask backend
create_backend() {
  progress "Creating backend API"
  
  cat > "$DASHBOARD_DIR/app.py" << 'EOF'
#!/usr/bin/env python3

from flask import Flask, jsonify, request
import subprocess
import json
import os
import time
import threading
from datetime import datetime

app = Flask(__name__)

# Global state
phase1_status = {"complete": False, "running": False}
phase2_status = {"complete": False, "running": False}
phase3_status = {"complete": False, "running": False}

VALIDATOR_DIR = os.path.expanduser("~/starknet-validator")

@app.route('/')
def index():
    return app.send_static_file('index.html')

@app.route('/api/status')
def get_status():
    services = []
    
    # Check Docker services
    try:
        result = subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            services = [name for name in result.stdout.strip().split('\n') if name]
    except:
        pass
    
    return jsonify({
        "services": services,
        "timestamp": datetime.now().isoformat()
    })

@app.route('/api/phase1/status')
def phase1_status_check():
    return jsonify(phase1_status)

@app.route('/api/phase1/start', methods=['POST'])
def start_phase1():
    if phase1_status["running"]:
        return jsonify({"success": False, "error": "Phase 1 already running"})
    
    def run_phase1():
        phase1_status["running"] = True
        try:
            # Create validator directory
            os.makedirs(VALIDATOR_DIR, exist_ok=True)
            
            # Run the original starknet script
            script_path = os.path.expanduser("~/Desktop/Cursor Github/NoaSEED/scripts/starknet_bitcoin_oneclick.sh")
            
            if os.path.exists(script_path):
                result = subprocess.run([
                    script_path, 
                    "--yes",
                    "--eth-ws", "wss://ethereum-sepolia.publicnode.com",
                    "--data-dir", f"{VALIDATOR_DIR}/pathfinder-data",
                    "--rpc-port", "9545",
                    "--monitoring", "Y",
                    "--grafana-port", "3001",
                    "--prom-port", "9091",
                    "--node-exporter-port", "9101"
                ], cwd=VALIDATOR_DIR, capture_output=True, text=True)
                
                if result.returncode == 0:
                    phase1_status["complete"] = True
                    phase1_status["running"] = False
                else:
                    phase1_status["running"] = False
                    print(f"Phase 1 error: {result.stderr}")
            else:
                phase1_status["running"] = False
                print("Starknet script not found")
                
        except Exception as e:
            phase1_status["running"] = False
            print(f"Phase 1 exception: {e}")
    
    thread = threading.Thread(target=run_phase1)
    thread.daemon = True
    thread.start()
    
    return jsonify({"success": True, "message": "Phase 1 started"})

@app.route('/api/phase2/status')
def phase2_status_check():
    return jsonify(phase2_status)

@app.route('/api/phase2/start', methods=['POST'])
def start_phase2():
    if not phase1_status["complete"]:
        return jsonify({"success": False, "error": "Phase 1 must be completed first"})
    
    if phase2_status["running"]:
        return jsonify({"success": False, "error": "Phase 2 already running"})
    
    def run_phase2():
        phase2_status["running"] = True
        try:
            # Install starkli if not present
            subprocess.run(['cargo', 'install', 'starkli', '--locked'], check=True)
            
            # Create validator wallets
            wallets_dir = f"{VALIDATOR_DIR}/wallets"
            os.makedirs(wallets_dir, exist_ok=True)
            
            # Create staking wallet (cold)
            subprocess.run([
                'starkli', 'account', 'oz', 'init', 
                f"{wallets_dir}/staking.json"
            ], check=True)
            
            # Create operational wallet (hot)
            subprocess.run([
                'starkli', 'account', 'oz', 'init', 
                f"{wallets_dir}/operational.json"
            ], check=True)
            
            # Create rewards wallet
            subprocess.run([
                'starkli', 'account', 'oz', 'init', 
                f"{wallets_dir}/rewards.json"
            ], check=True)
            
            # Save wallet addresses
            staking_addr = subprocess.run([
                'starkli', 'account', 'address', f"{wallets_dir}/staking.json"
            ], capture_output=True, text=True, check=True).stdout.strip()
            
            operational_addr = subprocess.run([
                'starkli', 'account', 'address', f"{wallets_dir}/operational.json"
            ], capture_output=True, text=True, check=True).stdout.strip()
            
            rewards_addr = subprocess.run([
                'starkli', 'account', 'address', f"{wallets_dir}/rewards.json"
            ], capture_output=True, text=True, check=True).stdout.strip()
            
            # Save configuration
            config = {
                "staking_address": staking_addr,
                "operational_address": operational_addr,
                "rewards_address": rewards_addr,
                "created_at": datetime.now().isoformat()
            }
            
            with open(f"{VALIDATOR_DIR}/validator_config.json", 'w') as f:
                json.dump(config, f, indent=2)
            
            phase2_status["complete"] = True
            phase2_status["running"] = False
            
        except Exception as e:
            phase2_status["running"] = False
            print(f"Phase 2 exception: {e}")
    
    thread = threading.Thread(target=run_phase2)
    thread.daemon = True
    thread.start()
    
    return jsonify({"success": True, "message": "Phase 2 started"})

@app.route('/api/phase3/status')
def phase3_status_check():
    return jsonify(phase3_status)

@app.route('/api/phase3/start', methods=['POST'])
def start_phase3():
    if not phase2_status["complete"]:
        return jsonify({"success": False, "error": "Phase 2 must be completed first"})
    
    if phase3_status["running"]:
        return jsonify({"success": False, "error": "Phase 3 already running"})
    
    def run_phase3():
        phase3_status["running"] = True
        try:
            # Create BTC pool configuration
            btc_config = {
                "pool_type": "BTC-STRK",
                "dex": "JediSwap",
                "btc_wrapper": "wBTC",
                "created_at": datetime.now().isoformat()
            }
            
            with open(f"{VALIDATOR_DIR}/btc_pool_config.json", 'w') as f:
                json.dump(btc_config, f, indent=2)
            
            # Create BTC pool management script
            pool_script = f"""#!/bin/bash
# BTC Pool Management Script
# Auto-generated by SEEDNodes Validator Dashboard

export STARKNET_RPC_URL="http://localhost:9545"
export STARKNET_ACCOUNT="{VALIDATOR_DIR}/wallets/operational.json"

# JediSwap contracts
JEDI_FACTORY="0x00dad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
JEDI_ROUTER="0x041fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388412c96"

# Tokens
ETH_TOKEN="0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c7b7f8c8c"
WBTC_TOKEN="0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac"

echo "BTC Pool Management Ready"
echo "Use: ./btc_pool_manager.sh [command]"
"""
            
            with open(f"{VALIDATOR_DIR}/btc_pool_manager.sh", 'w') as f:
                f.write(pool_script)
            
            os.chmod(f"{VALIDATOR_DIR}/btc_pool_manager.sh", 0o755)
            
            phase3_status["complete"] = True
            phase3_status["running"] = False
            
        except Exception as e:
            phase3_status["running"] = False
            print(f"Phase 3 exception: {e}")
    
    thread = threading.Thread(target=run_phase3)
    thread.daemon = True
    thread.start()
    
    return jsonify({"success": True, "message": "Phase 3 started"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
EOF

  # Make it executable
  chmod +x "$DASHBOARD_DIR/app.py"
  
  log "Backend API created ✓"
}

# Install Python dependencies
install_dependencies() {
  progress "Installing Python dependencies"
  
  # Create requirements.txt
  cat > "$DASHBOARD_DIR/requirements.txt" << 'EOF'
Flask==2.3.3
requests==2.31.0
EOF

  # Install dependencies
  pip3 install -r "$DASHBOARD_DIR/requirements.txt"
  
  log "Dependencies installed ✓"
}

# Start dashboard
start_dashboard() {
  progress "Starting dashboard server"
  
  # Start Flask app in background
  cd "$DASHBOARD_DIR"
  python3 app.py &
  
  # Wait a moment for server to start
  sleep 3
  
  log "Dashboard started ✓"
  echo ""
  echo -e "${CYAN}🌐 Dashboard URL: http://localhost:$DASHBOARD_PORT${NC}"
  echo -e "${CYAN}📊 Management Interface: http://localhost:$DASHBOARD_PORT${NC}"
  echo ""
  echo -e "${YELLOW}Dashboard Features:${NC}"
  echo "  • Phase 1: Sepolia Node Setup (Pathfinder + Monitoring)"
  echo "  • Phase 2: Validator Staking (Wallets + STRK Staking)"
  echo "  • Phase 3: BTC Pool Integration (Liquidity Pools)"
  echo ""
  echo -e "${GREEN}Press Ctrl+C to stop the dashboard${NC}"
}

# Main execution
main() {
  show_banner
  
  echo -e "${YELLOW}This will create a web dashboard for managing Starknet validator setup${NC}"
  echo -e "${YELLOW}The dashboard will guide you through 3 phases:${NC}"
  echo "  1. 🚀 Sepolia Node Setup"
  echo "  2. ⚡ Validator Staking"
  echo "  3. ₿ BTC Pool Integration"
  echo ""
  
  read -p "Continue? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Setup cancelled."
    exit 0
  fi
  
  check_requirements
  create_dashboard
  create_backend
  install_dependencies
  start_dashboard
  
  # Keep script running
  while true; do
    sleep 1
  done
}

# Run main function
main "$@"
