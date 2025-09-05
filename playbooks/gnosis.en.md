# Gnosis Playbook – Validators
## SEEDNodes – Institutional NodeOps

---

## Objective
Deploy and operate Gnosis Chain validators with institutional standards: secure setup, auditable operations, and reliable monitoring.

## Requirements
- Hardware: 8+ cores, 32GB RAM, 2TB NVMe
- OS: Ubuntu 22.04 LTS; Docker 24+, Compose 2.20+

## Operations
- Lighthouse beacon + validator; import keys; slashing protection
- Monitoring: Prometheus + Grafana; KPIs (uptime, missed attestations, peers)

## Verification Checklist
- Validator keys imported, slashing DB active, peers healthy, dashboards green
