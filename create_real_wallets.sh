#!/bin/bash

# Create Real Wallets with Private Keys
# Crea wallets reales con claves privadas para control total

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }

VALIDATOR_DIR="$HOME/starknet-validator"
WALLETS_DIR="$VALIDATOR_DIR/wallets"

echo -e "${BLUE}🔐 Create Real Wallets with Private Keys${NC}"
echo ""

# Create wallets directory
mkdir -p "$WALLETS_DIR"
cd "$VALIDATOR_DIR"

# Check if starkli is available
if ! command -v starkli &> /dev/null; then
    warn "Starkli not found. Installing..."
    if [[ -f "$(dirname "$0")/install_starkli.sh" ]]; then
        "$(dirname "$0")/install_starkli.sh"
    else
        fail "Please install starkli first: ./install_starkli.sh"
    fi
fi

# Set environment variables
export STARKNET_RPC_URL="http://localhost:9545"
export STARKNET_CHAIN_ID="0x534e5f5345504f4c4941"

progress "Creating real validator wallets..."

# Create staking wallet (cold wallet)
log "Creating staking wallet (cold wallet)..."
starkli account oz init "$WALLETS_DIR/staking.json" --force
STAKING_ADDRESS=$(starkli account address "$WALLETS_DIR/staking.json")
log "✅ Staking wallet created: $STAKING_ADDRESS"

# Create operational wallet (hot wallet)
log "Creating operational wallet (hot wallet)..."
starkli account oz init "$WALLETS_DIR/operational.json" --force
OPERATIONAL_ADDRESS=$(starkli account address "$WALLETS_DIR/operational.json")
log "✅ Operational wallet created: $OPERATIONAL_ADDRESS"

# Create rewards wallet
log "Creating rewards wallet..."
starkli account oz init "$WALLETS_DIR/rewards.json" --force
REWARDS_ADDRESS=$(starkli account address "$WALLETS_DIR/rewards.json")
log "✅ Rewards wallet created: $REWARDS_ADDRESS"

# Create backup directory
mkdir -p "$WALLETS_DIR/backup"

# Backup wallet files
log "Creating backups..."
cp "$WALLETS_DIR/staking.json" "$WALLETS_DIR/backup/staking.json.backup"
cp "$WALLETS_DIR/operational.json" "$WALLETS_DIR/backup/operational.json.backup"
cp "$WALLETS_DIR/rewards.json" "$WALLETS_DIR/backup/rewards.json.backup"

# Create wallet info file
cat > "$WALLETS_DIR/wallet_info.txt" << EOF
# SEEDNodes Validator Wallets
# Generated: $(date)

## Staking Wallet (Cold Wallet)
Address: $STAKING_ADDRESS
File: $WALLETS_DIR/staking.json
Purpose: Large amounts, infrequent transactions
Backup: $WALLETS_DIR/backup/staking.json.backup

## Operational Wallet (Hot Wallet)
Address: $OPERATIONAL_ADDRESS
File: $WALLETS_DIR/operational.json
Purpose: Frequent transactions, daily operations
Backup: $WALLETS_DIR/backup/operational.json.backup

## Rewards Wallet
Address: $REWARDS_ADDRESS
File: $WALLETS_DIR/rewards.json
Purpose: Collecting validator rewards
Backup: $WALLETS_DIR/backup/rewards.json.backup

## Security Notes:
- Keep private keys secure and encrypted
- Store backups in multiple secure locations
- Never share private keys
- Use cold wallet for large amounts
- Use hot wallet for daily operations
EOF

# Update validator configuration
progress "Updating validator configuration..."
cat > "$VALIDATOR_DIR/validator_config.json" << EOF
{
    "validator_info": {
        "staking_address": "$STAKING_ADDRESS",
        "operational_address": "$OPERATIONAL_ADDRESS",
        "rewards_address": "$REWARDS_ADDRESS",
        "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    "staking_parameters": {
        "minimum_stake_sepolia": "1000000000000000000",
        "minimum_stake_mainnet": "20000000000000000000000",
        "commission_rate": "500",
        "commission_max": "1000"
    },
    "contracts": {
        "staking_contract_sepolia": "0x04718e5e9c03c0b4c80c2b407dd1c7687b6d4b5d0c9a7c3e8f1d2a5b8c9e0f1a",
        "delegation_contract_sepolia": "0x04718e5e9c03c0b4c80c2b407dd1c7687b6d4b5d0c9a7c3e8f1d2a5b8c9e0f1b"
    },
    "wallets": {
        "staking_file": "$WALLETS_DIR/staking.json",
        "operational_file": "$WALLETS_DIR/operational.json",
        "rewards_file": "$WALLETS_DIR/rewards.json"
    }
}
EOF

# Create enhanced staking manager
progress "Creating enhanced staking manager..."
cat > "$VALIDATOR_DIR/staking_manager.sh" << 'EOF'
#!/bin/bash

# Enhanced Starknet Validator Staking Manager
# With real wallet support

set -e

VALIDATOR_DIR="$HOME/starknet-validator"
WALLETS_DIR="$VALIDATOR_DIR/wallets"

# Load configuration
if [[ -f "$VALIDATOR_DIR/validator_config.json" ]]; then
    STAKING_ADDRESS=$(jq -r '.validator_info.staking_address' "$VALIDATOR_DIR/validator_config.json")
    OPERATIONAL_ADDRESS=$(jq -r '.validator_info.operational_address' "$VALIDATOR_DIR/validator_config.json")
    REWARDS_ADDRESS=$(jq -r '.validator_info.rewards_address' "$VALIDATOR_DIR/validator_config.json")
    STAKING_CONTRACT=$(jq -r '.contracts.staking_contract_sepolia' "$VALIDATOR_DIR/validator_config.json")
    DELEGATION_CONTRACT=$(jq -r '.contracts.delegation_contract_sepolia' "$VALIDATOR_DIR/validator_config.json")
    STAKING_FILE=$(jq -r '.wallets.staking_file' "$VALIDATOR_DIR/validator_config.json")
    OPERATIONAL_FILE=$(jq -r '.wallets.operational_file' "$VALIDATOR_DIR/validator_config.json")
else
    echo "Error: validator_config.json not found"
    exit 1
fi

# Set environment
export STARKNET_RPC_URL="http://localhost:9545"
export STARKNET_ACCOUNT="$STAKING_FILE"

# Functions
stake() {
    local amount=$1
    if [[ -z "$amount" ]]; then
        echo "Usage: stake <amount_in_wei>"
        echo "Example: stake 1000000000000000000  # 1 STRK"
        exit 1
    fi
    
    echo "Staking $amount wei to contract $STAKING_CONTRACT..."
    starkli invoke "$STAKING_CONTRACT" "stake" "u256:$amount"
}

set_commission() {
    local commission=$1
    if [[ -z "$commission" ]]; then
        echo "Usage: set_commission <commission_in_basis_points>"
        echo "Example: set_commission 500  # 5%"
        exit 1
    fi
    
    echo "Setting commission to $commission basis points..."
    starkli invoke "$STAKING_CONTRACT" "set_commission" "u256:$commission"
}

declare_operational() {
    echo "Declaring operational address: $OPERATIONAL_ADDRESS..."
    starkli invoke "$STAKING_CONTRACT" "declare_operational_address" "$OPERATIONAL_ADDRESS"
}

open_delegation() {
    echo "Opening delegation pool..."
    starkli invoke "$STAKING_CONTRACT" "open_delegation"
}

check_status() {
    echo "Validator Status:"
    echo "  Staking Address: $STAKING_ADDRESS"
    echo "  Operational Address: $OPERATIONAL_ADDRESS"
    echo "  Rewards Address: $REWARDS_ADDRESS"
    echo "  Staking Contract: $STAKING_CONTRACT"
    echo ""
    
    # Check balances
    echo "Checking balances..."
    starkli call 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c7b7f8c8c "balanceOf" "$STAKING_ADDRESS"
}

show_wallets() {
    echo "Wallet Files:"
    echo "  Staking: $STAKING_FILE"
    echo "  Operational: $OPERATIONAL_FILE"
    echo "  Rewards: $REWARDS_FILE"
    echo ""
    echo "Backup Files:"
    echo "  Staking: $WALLETS_DIR/backup/staking.json.backup"
    echo "  Operational: $WALLETS_DIR/backup/operational.json.backup"
    echo "  Rewards: $WALLETS_DIR/backup/rewards.json.backup"
}

# Main command handling
case "$1" in
    "stake")
        stake "$2"
        ;;
    "commission")
        set_commission "$2"
        ;;
    "operational")
        declare_operational
        ;;
    "delegation")
        open_delegation
        ;;
    "status")
        check_status
        ;;
    "wallets")
        show_wallets
        ;;
    *)
        echo "Enhanced Starknet Validator Staking Manager"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  stake <amount>     - Stake STRK tokens"
        echo "  commission <rate>  - Set commission rate (basis points)"
        echo "  operational       - Declare operational address"
        echo "  delegation        - Open delegation pool"
        echo "  status            - Check validator status"
        echo "  wallets           - Show wallet file locations"
        echo ""
        echo "Examples:"
        echo "  $0 stake 1000000000000000000    # Stake 1 STRK"
        echo "  $0 commission 500               # Set 5% commission"
        echo "  $0 operational                  # Set operational address"
        echo "  $0 delegation                   # Open delegation"
        echo "  $0 status                       # Check status"
        echo "  $0 wallets                      # Show wallet files"
        ;;
esac
EOF

chmod +x "$VALIDATOR_DIR/staking_manager.sh"

# Create faucet helper with real addresses
progress "Creating faucet helper with real addresses..."
cat > "$VALIDATOR_DIR/get_testnet_tokens.sh" << EOF
#!/bin/bash

# Get testnet tokens for validator setup
# With real wallet addresses

VALIDATOR_DIR="$HOME/starknet-validator"

if [[ -f "$VALIDATOR_DIR/validator_config.json" ]]; then
    STAKING_ADDRESS=\$(jq -r '.validator_info.staking_address' "$VALIDATOR_DIR/validator_config.json")
    OPERATIONAL_ADDRESS=\$(jq -r '.validator_info.operational_address' "$VALIDATOR_DIR/validator_config.json")
    REWARDS_ADDRESS=\$(jq -r '.validator_info.rewards_address' "$VALIDATOR_DIR/validator_config.json")
    
    echo "🔗 Get testnet tokens for your REAL validator addresses:"
    echo ""
    echo "Staking Address (Cold Wallet):"
    echo "  \$STAKING_ADDRESS"
    echo "  Faucet: https://starknet-faucet.vercel.app/"
    echo ""
    echo "Operational Address (Hot Wallet):"
    echo "  \$OPERATIONAL_ADDRESS"
    echo "  Faucet: https://faucet.quicknode.com/starknet/sepolia"
    echo ""
    echo "Rewards Address:"
    echo "  \$REWARDS_ADDRESS"
    echo "  Faucet: https://starknet-faucet.pk910.de/"
    echo ""
    echo "📝 Instructions:"
    echo "1. Visit each faucet URL"
    echo "2. Paste the corresponding address"
    echo "3. Request tokens (usually 0.1-1 STRK)"
    echo "4. Wait for confirmation"
    echo "5. Run: ./staking_manager.sh status"
    echo ""
    echo "🔐 Security:"
    echo "  • Your private keys are in: $VALIDATOR_DIR/wallets/"
    echo "  • Backups are in: $VALIDATOR_DIR/wallets/backup/"
    echo "  • Keep these files secure and encrypted!"
else
    echo "Error: validator_config.json not found"
    exit 1
fi
EOF

chmod +x "$VALIDATOR_DIR/get_testnet_tokens.sh"

log "🎉 Real wallets created successfully!"
echo ""
echo -e "${CYAN}📊 Validator Wallets:${NC}"
echo "  • Staking Address: $STAKING_ADDRESS"
echo "  • Operational Address: $OPERATIONAL_ADDRESS"
echo "  • Rewards Address: $REWARDS_ADDRESS"
echo ""
echo -e "${CYAN}🔐 Wallet Files:${NC}"
echo "  • Staking: $WALLETS_DIR/staking.json"
echo "  • Operational: $WALLETS_DIR/operational.json"
echo "  • Rewards: $WALLETS_DIR/rewards.json"
echo ""
echo -e "${CYAN}💾 Backups:${NC}"
echo "  • $WALLETS_DIR/backup/"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT SECURITY NOTES:${NC}"
echo "  • Your private keys are in the wallet files"
echo "  • Keep these files secure and encrypted"
echo "  • Store backups in multiple secure locations"
echo "  • Never share private keys"
echo ""
echo -e "${GREEN}📝 Next Steps:${NC}"
echo "  1. Get testnet tokens: ./get_testnet_tokens.sh"
echo "  2. Check wallet status: ./staking_manager.sh status"
echo "  3. Show wallet files: ./staking_manager.sh wallets"
echo "  4. Stake tokens: ./staking_manager.sh stake 1000000000000000000"
