# 🌐 SEEDNodes - Starknet Validator Dashboard

## 📋 Overview

This is a comprehensive web-based dashboard for setting up and managing a Starknet validator with BTC pool integration. The system is divided into 3 phases that can be executed sequentially through an intuitive web interface.

## 🎯 Features

### Phase 1: Sepolia Node Setup
- **Pathfinder Node**: Full Starknet Sepolia node with Pathfinder
- **Monitoring Stack**: Prometheus + Grafana + Node Exporter
- **RPC Endpoints**: HTTP RPC on port 9545
- **Health Checks**: Automated health monitoring

### Phase 2: Validator Staking
- **Multi-Wallet Setup**: Staking, Operational, and Rewards wallets
- **STRK Staking**: Minimum stake configuration for Sepolia (1 STRK)
- **Commission Management**: Configurable validator commission rates
- **Delegation Pools**: Open delegation for STRK and BTC

### Phase 3: BTC Pool Integration
- **Liquidity Pools**: BTC-STRK pools on JediSwap
- **Bridge Integration**: Support for multiple BTC bridges
- **Staking Power**: BTC contributes 25% to validator staking power
- **Reward Optimization**: Multiple income streams

## 🚀 Quick Start

### Prerequisites
- macOS/Linux with Docker installed
- Python 3.7+ with pip
- Rust toolchain (auto-installed)
- 8GB+ RAM, 100GB+ storage

### Launch Dashboard
```bash
# Simple launcher
./launch_validator_dashboard.sh

# Or direct execution
./scripts/starknet_validator_dashboard.sh
```

### Access Dashboard
- **URL**: http://localhost:8080
- **Features**: Web-based phase management
- **Real-time**: Live status updates and logs

## 📊 Dashboard Interface

### Phase 1: Node Setup
- **Status**: Pending → Running → Complete
- **Progress Bar**: Real-time installation progress
- **Logs**: Live installation logs
- **Endpoints**: RPC, Metrics, Prometheus, Grafana

### Phase 2: Validator Setup
- **Wallets**: Automatic wallet creation
- **Configuration**: Validator parameters
- **Staking**: STRK staking management
- **Delegation**: Pool opening and management

### Phase 3: BTC Pool
- **Pools**: Liquidity pool creation
- **Bridges**: BTC bridge integration
- **Monitoring**: Pool performance tracking
- **Integration**: BTC staking power

## 🔧 Manual Commands

### Phase 1: Node Management
```bash
# Start node
./scripts/phase1_sepolia_node.sh

# Check status
docker compose -f ~/starknet-validator/compose/starknet-sepolia.docker-compose.yml ps

# View logs
docker compose -f ~/starknet-validator/compose/starknet-sepolia.docker-compose.yml logs -f pathfinder
```

### Phase 2: Validator Management
```bash
# Setup validator
./scripts/phase2_validator_staking.sh

# Get testnet tokens
~/starknet-validator/get_testnet_tokens.sh

# Manage staking
~/starknet-validator/staking_manager.sh status
~/starknet-validator/staking_manager.sh stake 1000000000000000000
~/starknet-validator/staking_manager.sh commission 500
```

### Phase 3: BTC Pool Management
```bash
# Setup BTC pools
./scripts/phase3_btc_pool.sh

# Manage pools
~/starknet-validator/btc-pools/btc_pool_manager.sh check
~/starknet-validator/btc-pools/btc_pool_manager.sh bridge
~/starknet-validator/btc-pools/btc_pool_manager.sh add [tokens]

# Monitor pools
~/starknet-validator/btc-pools/monitor_btc_pools.sh --continuous
```

## 📁 Directory Structure

```
~/starknet-validator/
├── compose/
│   └── starknet-sepolia.docker-compose.yml
├── env/
│   └── starknet-sepolia.env
├── monitoring/
│   ├── prometheus-starknet.yml
│   └── grafana/
├── wallets/
│   ├── staking.json
│   ├── operational.json
│   └── rewards.json
├── btc-pools/
│   ├── btc_pool_config.json
│   ├── btc_pool_manager.sh
│   ├── btc_staking_integration.sh
│   └── monitor_btc_pools.sh
├── validator_config.json
├── staking_manager.sh
└── get_testnet_tokens.sh
```

## 🌐 Endpoints

### Node Endpoints
- **RPC**: http://localhost:9545
- **Metrics**: http://localhost:9187
- **Prometheus**: http://localhost:9091
- **Grafana**: http://localhost:3001 (admin/admin)

### Dashboard Endpoints
- **Main Dashboard**: http://localhost:8080
- **API Status**: http://localhost:8080/api/status
- **Phase APIs**: http://localhost:8080/api/phase[1-3]/[start|status]

## 🔐 Security Notes

### Wallet Security
- **Staking Wallet**: Cold storage for large amounts
- **Operational Wallet**: Hot wallet for frequent operations
- **Rewards Wallet**: Separate wallet for reward collection

### Network Security
- **Firewall**: UFW configured with necessary ports
- **Docker**: Isolated containers with minimal privileges
- **Monitoring**: Comprehensive logging and alerting

## 📈 Monitoring & Alerts

### Grafana Dashboards
- **Node Health**: Pathfinder status and performance
- **System Metrics**: CPU, Memory, Disk usage
- **Network Stats**: RPC calls, sync status
- **Validator Metrics**: Staking power, attestations

### Prometheus Metrics
- **Application**: Pathfinder-specific metrics
- **System**: Node exporter metrics
- **Custom**: Validator and pool metrics

## 🛠️ Troubleshooting

### Common Issues

#### Phase 1: Node Issues
```bash
# Check Docker status
docker ps
docker logs starknet-pathfinder

# Restart services
docker compose -f ~/starknet-validator/compose/starknet-sepolia.docker-compose.yml restart
```

#### Phase 2: Wallet Issues
```bash
# Check wallet addresses
starkli account address ~/starknet-validator/wallets/staking.json

# Verify balances
~/starknet-validator/staking_manager.sh status
```

#### Phase 3: Pool Issues
```bash
# Check pool status
~/starknet-validator/btc-pools/btc_pool_manager.sh check

# Verify bridge status
~/starknet-validator/btc-pools/btc_pool_manager.sh bridge
```

### Log Locations
- **Dashboard**: `/tmp/starknet-dashboard/`
- **Node Logs**: Docker container logs
- **Validator**: `~/starknet-validator/`
- **Pools**: `~/starknet-validator/btc-pools/`

## 🔄 Updates & Maintenance

### Updating Images
```bash
# Update Docker images
docker compose -f ~/starknet-validator/compose/starknet-sepolia.docker-compose.yml pull
docker compose -f ~/starknet-validator/compose/starknet-sepolia.docker-compose.yml up -d
```

### Backup Strategy
```bash
# Backup validator data
tar -czf starknet-validator-backup-$(date +%Y%m%d).tar.gz ~/starknet-validator/

# Backup wallet files (encrypt first!)
gpg --symmetric ~/starknet-validator/wallets/*.json
```

## 📚 Additional Resources

### Documentation
- [Starknet Staking Docs](https://docs.starknet.io/learn/protocol/staking)
- [Pathfinder Documentation](https://github.com/eqlabs/pathfinder)
- [JediSwap Documentation](https://docs.jediswap.xyz/)

### Community
- [Starknet Discord](https://discord.gg/starknet)
- [SEEDNodes Community](https://github.com/NoaSEED)

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs in the dashboard
3. Check system requirements
4. Contact SEEDNodes support

---

**Built with ❤️ by SEEDNodes - Institutional NodeOps**
