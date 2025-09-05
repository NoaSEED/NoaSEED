# Aztec Playbook – Sequencer Node
## SEEDNodes – Institutional NodeOps

---

## Objective
Deploy and operate an Aztec sequencer node to institutional standards, targeting ≥ 99.9% uptime with auditable operations.

---

## Prerequisites
- CPU: 4+ cores (ARM64/x86_64)
- RAM: 8GB+
- Storage: 250GB+ NVMe SSD
- Network: 25Mbps+ symmetric
- OS: Ubuntu 22.04 LTS; Docker 24+, Docker Compose 2.20+

Required information:
- Sepolia Execution RPC URL (Alchemy/Infura/etc.)
- Beacon RPC URL (Infura/QuickNode/etc.)
- Wallet private key (use a new wallet)
- Wallet address (fund with Sepolia ETH)
- Server IP

---

## Automated Install
```bash
./scripts/aztec_installer.sh
```

Manual path (if needed): update packages, install dependencies, install Docker, configure UFW (40400 tcp/udp, 8080, 9999), create `.env` and `docker-compose.yml`, then `docker compose up -d`.

---

## Configuration
Environment example (`env/aztec.env`):
```bash
AZTEC_NETWORK=alpha-testnet
ETHEREUM_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
CONSENSUS_BEACON_URL=https://sepolia-beacon.infura.io/v3/YOUR_KEY
VALIDATOR_PRIVATE_KEYS=0xYourPrivateKey
COINBASE=0xYourAddress
P2P_IP=Your-IP-Address
LOG_LEVEL=info
```

---

## Operations
```bash
docker compose ps
docker compose logs -fn 1000
bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/sync-check.sh)
```
Dozzle logs UI: `http://<IP>:9999`.

---

## Monitoring
- KPIs: uptime ≥ 99.9%, 100% sync, stable P2P, memory < 85%, CPU < 80%
- Tools: Prometheus + Grafana (optional), Dozzle for logs

---

## Backup & Restore
Daily config backups; weekly/full state; monthly full with restore test. Include SHA256, integrity validation, and audit log.

---

## Incident Response
P0–P3 runbooks: check status, inspect logs, restart, re‑sync if needed, notify, document.

---

## Verification Checklist
Pre‑deploy (HW/OS, Docker, env, funded wallet, network). Post‑deploy (running, syncing, ports open, monitoring set, backups scheduled). Continuous (SLA, resources, clean logs, alerts active).

