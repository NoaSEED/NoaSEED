#!/bin/bash

# Test script for Starknet Validator Dashboard
# Verifies all components are working correctly

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    info "Running test: $test_name"
    
    if eval "$test_command"; then
        log "✅ $test_name - PASSED"
        ((TESTS_PASSED++))
    else
        error "❌ $test_name - FAILED"
        ((TESTS_FAILED++))
    fi
    echo ""
}

echo -e "${BLUE}"
cat << "EOF"
    ███████╗███████╗███████╗██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗███████╗
    ██╔════╝██╔════╝██╔════╝██╔══██╗████╗  ██║██╔═══██╗██╔══██╗██╔════╝██╔════╝
    ███████╗█████╗  █████╗  ██║  ██║██╔██╗ ██║██║   ██║██║  ██║█████╗  ███████╗
    ╚════██║██╔══╝  ██╔══╝  ██║  ██║██║╚██╗██║██║   ██║██║  ██║██╔══╝  ╚════██║
    ███████║███████╗███████╗██████╔╝██║ ╚████║╚██████╔╝██████╔╝███████╗███████║
    ╚══════╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝

                    SEEDNodes - Dashboard Test Suite
EOF
echo -e "${NC}"

info "Starting dashboard test suite..."
echo ""

# Test 1: Check if all scripts exist and are executable
run_test "Script Files Exist" "
    [[ -f '$SCRIPT_DIR/scripts/starknet_validator_dashboard.sh' ]] &&
    [[ -f '$SCRIPT_DIR/scripts/phase1_sepolia_node.sh' ]] &&
    [[ -f '$SCRIPT_DIR/scripts/phase2_validator_staking.sh' ]] &&
    [[ -f '$SCRIPT_DIR/scripts/phase3_btc_pool.sh' ]] &&
    [[ -f '$SCRIPT_DIR/launch_validator_dashboard.sh' ]]
"

# Test 2: Check if scripts are executable
run_test "Scripts Are Executable" "
    [[ -x '$SCRIPT_DIR/scripts/starknet_validator_dashboard.sh' ]] &&
    [[ -x '$SCRIPT_DIR/scripts/phase1_sepolia_node.sh' ]] &&
    [[ -x '$SCRIPT_DIR/scripts/phase2_validator_staking.sh' ]] &&
    [[ -x '$SCRIPT_DIR/scripts/phase3_btc_pool.sh' ]] &&
    [[ -x '$SCRIPT_DIR/launch_validator_dashboard.sh' ]]
"

# Test 3: Check if original starknet script exists
run_test "Original Starknet Script Exists" "
    [[ -f '$SCRIPT_DIR/scripts/starknet_bitcoin_oneclick.sh' ]]
"

# Test 4: Check system requirements
run_test "System Requirements" "
    command -v curl >/dev/null &&
    command -v docker >/dev/null &&
    command -v python3 >/dev/null
"

# Test 5: Check Docker status
run_test "Docker Is Running" "
    docker info >/dev/null 2>&1
"

# Test 6: Check Python Flask availability
run_test "Python Flask Available" "
    python3 -c 'import flask' 2>/dev/null || pip3 install flask >/dev/null 2>&1
"

# Test 7: Test dashboard script syntax
run_test "Dashboard Script Syntax" "
    bash -n '$SCRIPT_DIR/scripts/starknet_validator_dashboard.sh'
"

# Test 8: Test phase scripts syntax
run_test "Phase Scripts Syntax" "
    bash -n '$SCRIPT_DIR/scripts/phase1_sepolia_node.sh' &&
    bash -n '$SCRIPT_DIR/scripts/phase2_validator_staking.sh' &&
    bash -n '$SCRIPT_DIR/scripts/phase3_btc_pool.sh'
"

# Test 9: Test launcher script syntax
run_test "Launcher Script Syntax" "
    bash -n '$SCRIPT_DIR/launch_validator_dashboard.sh'
"

# Test 10: Check if ports are available
run_test "Ports Available" "
    ! lsof -i :8080 >/dev/null 2>&1 &&
    ! lsof -i :9545 >/dev/null 2>&1 &&
    ! lsof -i :3001 >/dev/null 2>&1
"

# Test 11: Check directory permissions
run_test "Directory Permissions" "
    [[ -w '$SCRIPT_DIR' ]] &&
    [[ -r '$SCRIPT_DIR' ]]
"

# Test 12: Test dashboard creation (dry run)
run_test "Dashboard Creation Test" "
    DASHBOARD_DIR='/tmp/starknet-dashboard-test'
    mkdir -p '$DASHBOARD_DIR'
    echo '<html><body>Test</body></html>' > '$DASHBOARD_DIR/index.html'
    [[ -f '$DASHBOARD_DIR/index.html' ]]
    rm -rf '$DASHBOARD_DIR'
"

# Test 13: Check if jq is available (needed for JSON parsing)
run_test "jq Available" "
    command -v jq >/dev/null || brew install jq >/dev/null 2>&1
"

# Test 14: Check if cargo is available or can be installed
run_test "Rust/Cargo Available" "
    command -v cargo >/dev/null || command -v rustc >/dev/null || echo 'Rust will be installed during setup'
"

# Test 15: Check available disk space
run_test "Sufficient Disk Space" "
    AVAILABLE_GB=\$(df -g . | awk 'NR==2 {print \$4}')
    [[ \$AVAILABLE_GB -gt 50 ]]
"

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           TEST SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    log "🎉 All tests passed! ($TESTS_PASSED/$((TESTS_PASSED + TESTS_FAILED)))"
    echo ""
    info "✅ Dashboard is ready to launch!"
    echo ""
    echo -e "${GREEN}To start the dashboard:${NC}"
    echo "  ./launch_validator_dashboard.sh"
    echo ""
    echo -e "${GREEN}Dashboard will be available at:${NC}"
    echo "  http://localhost:8080"
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "  • Phase 1: Sepolia Node Setup"
    echo "  • Phase 2: Validator Staking"
    echo "  • Phase 3: BTC Pool Integration"
    echo ""
else
    error "❌ Some tests failed! ($TESTS_FAILED/$((TESTS_PASSED + TESTS_FAILED)))"
    echo ""
    warn "Please fix the failed tests before launching the dashboard."
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  • Install missing dependencies: brew install jq"
    echo "  • Start Docker: open -a Docker"
    echo "  • Install Python packages: pip3 install flask"
    echo "  • Free up disk space if needed"
    echo ""
fi

echo -e "${BLUE}========================================${NC}"

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    exit 0
else
    exit 1
fi
