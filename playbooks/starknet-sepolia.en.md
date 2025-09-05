# Starknet Sepolia Playbook (Pathfinder) – Bitcoin Pool Purpose
## SEEDNodes – Institutional NodeOps

---

## Objective
Deploy and operate a Starknet node on Sepolia using Pathfinder via Docker, as a foundation for Bitcoin Pool integration.

---

## Requirements
- CPU: 4+ cores; RAM: 8GB+; Disk: 250GB SSD+
- Ubuntu 22.04 LTS; Docker 24+, Compose 2.20+
- Ports: 9545 (HTTP RPC), 9187 (metrics), 9090 (Prometheus), 3000 (Grafana), 9100 (Node Exporter)

---

## Automated Install
```bash
git clone https://github.com/NoaSEED/seedops-institutional.git
cd seedops-institutional
chmod +x scripts/starknet_sepolia_installer.sh
./scripts/starknet_sepolia_installer.sh
```
Prompts: Sepolia RPC, data directory (default `/var/lib/pathfinder`), RPC port (9545), monitoring stack enable (Prometheus + Grafana + Node Exporter).

---

## What the Installer Does
- System updates, Docker install, UFW rules
- Generates `env/starknet-sepolia.env` and `compose/starknet-sepolia.docker-compose.yml`
- Creates Prometheus and Grafana provisioning
- Starts `pathfinder` (+ optional `prometheus`, `grafana`, `node-exporter`)

---

## Operations
```bash
docker compose -f compose/starknet-sepolia.docker-compose.yml logs -fn 200
docker compose -f compose/starknet-sepolia.docker-compose.yml ps
docker compose -f compose/starknet-sepolia.docker-compose.yml down
```
Endpoints:
- HTTP RPC: `http://<ip>:9545`
- App metrics: `http://<ip>:9187`
- Prometheus: `http://<ip>:9090`
- Grafana: `http://<ip>:3000` (admin/admin)

---

## Monitoring
Prometheus jobs: `starknet_pathfinder` (9187) and `node_exporter` (9100). Grafana dashboard “Starknet Pathfinder + Host” includes UP, CPU%, Memory% panels.

---

## Maintenance
Update images and redeploy:
```bash
docker compose -f compose/starknet-sepolia.docker-compose.yml pull
docker compose -f compose/starknet-sepolia.docker-compose.yml up -d
```
Backup: archive the data directory (`/var/lib/pathfinder`) and provisioning files.

---

Owner: Noa SEED Org
