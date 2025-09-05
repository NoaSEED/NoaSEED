# Ethereum Playbook – Obol DVT + CSM
## SEEDNodes – Institutional NodeOps

---

## Objective
Deploy validators on Ethereum using Obol DVT and Consensus Client Management with institutional‑grade automation and monitoring.

---

## Requirements
- Hardware: 8+ cores, 32GB+ RAM, 2TB+ NVMe
- OS: Ubuntu 22.04 LTS; Docker 24+, Compose 2.20+

## Operations
- Provision Obol DVT cluster, import validator keys, enable slashing protection
- Configure execution client (Geth) + consensus client (Lighthouse) + Charon
- Monitoring: Prometheus + Grafana; KPIs (attestation rate, inclusion distance, duties)

## Incident Response
- P0: validator down/slashing risk → immediate restart, verify slashing DB, review logs
- P1: performance degradation → check peers, disk I/O, CPU/memory, optimize

## Verification Checklist
- Keys protected, slashing DB initialized, peers stable, duties executing, dashboards green
