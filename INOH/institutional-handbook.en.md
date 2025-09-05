# INOH – Institutional Node Operations Handbook
## SEEDNodes – Master Standard for NodeOps

---

## Table of Contents
1. Institutional Objective
2. Minimum Infrastructure
3. Operating Procedures
4. Security
5. Monitoring & Reporting
6. Integrated Audits
7. Agentic NodeOps
8. Continuous Improvement

---

## Institutional Objective

### Mission
Operate blockchain nodes to institutional standards in LATAM, building automated, auditable, and scalable processes.

### Vision
Establish industry best practices ensuring:
- Security: zero‑trust, continuous audits
- Transparency: end‑to‑end traceability
- Reliability: ≥ 99.9% uptime, predictive response
- Scalability: multi‑network orchestration (Ethereum, Gnosis, Starknet, Aztec)

### Institutional Differentiators
1. Advanced Automation – adaptive processes
2. Audit Trail – verifiable evidence for every action
3. Predictive Monitoring – early detection
4. Multi‑Network Hub – centralized orchestration
5. Technical Operations – focus on validators and nodes

---

## Minimum Infrastructure

### Hardware
- Production: 8+ cores, 32GB+ RAM, 2TB+ NVMe, 1Gbps+, 99.9% SLA
- Staging: 4+ cores, 16GB+ RAM, 1TB+ SSD, 100Mbps+

### Software
- Ubuntu 22.04 LTS, Docker 24+, Docker Compose 2.20+, Git 2.40+

### Security Tooling
- UFW, Fail2ban, SSH keys only, VPN

### Monitoring
- Prometheus + Grafana, Node Exporter, AlertManager, Telegram/Discord

### Supported Networks
| Network | Type | Validators | Sequencers | Status |
|--------|------|------------|------------|--------|
| Ethereum | Obol DVT | ✅ | ❌ | Production |
| Gnosis | Native | Variable | ❌ | Production |
| Starknet | Delegation | ✅ | ❌ | Development |
| Aztec | Native | ✅ | ✅ | Research |

---

## Operating Procedures

### 1. Bootstrap
```bash
make bootstrap   # base setup
make harden      # security
make deploy      # network deploy
make monitor     # monitoring
make backup      # backups
```
Checklist: updated OS, non‑root user, SSH keys, Docker installed, repo cloned, env set, audit logs enabled.

### 2. Hardening
Mandatory: UFW, SSH keys only, Fail2ban, security updates, centralized/rotated logs, VPN.
Post‑hardening audit: `./scripts/audit_security.sh` (PDF report).

### 3. Deploy (per network)
- Ethereum (Obol DVT): register validators, monitoring, audit log
- Gnosis (Validators): native validators, tuned config
- Starknet (Delegation STRK): delegation and rewards monitoring
- Aztec (Validators + Sequencers): dual monitoring

### 4. Monitoring
KPIs: uptime ≥ 99.9%, CPU < 80%, RAM < 85%, Disk < 90%, latency < 100ms, on‑time block production. Alerts: Critical/Warning/Info.

### 5. Backups
Daily critical configs; weekly full state; monthly full + restore test. Each backup: SHA256, restore test, integrity check, audit log.

### 6. Incident Response
Severity P0–P3 with automated detection, classification, recovery, notification, documentation, and escalation.

---

## Security
Zero‑trust architecture: VPN, MFA, SSH keys, minimal ports, comprehensive audit logs.

### Key Management
- Validator keys: HSM, encrypted storage, rotation every 90 days, 3‑copy backups
- API keys: Vault, rotation 30 days, least privilege, audited usage

### Validator Operations
Automated registration, real‑time monitoring, performance tuning, maintenance updates.

### Technical Audits
- Internal: monthly (Noa SEED Org)
- External: quarterly (independent)
- Regulatory: per‑network requirements
- Continuous: automated

---

## Monitoring & Reporting
Institutional KPIs (network and operations), real‑time dashboards, scheduled reports (daily/weekly/monthly/quarterly), notifications via Telegram/Discord/Email/Slack. Escalation: P0 → Noa SEED Org, etc.

---

## Integrated Audits
Types: infrastructure, security, backups, monitoring. Evidence: traceability, verifiability (hash/timestamps), immutability, accessibility. Storage: local `/var/log/seedops/`, private repo `audit-logs`, multi‑site backups, 7‑year retention.

---

## Agentic NodeOps
Automation evolution (manual → basic → agentic). Agents for security, backups, incidents, and monitoring with predictive models. CI/CD hub and centralized security. Predictive layer: resources, anomalies, optimization, failure prevention.

---

## Continuous Improvement
Quarterly cycle: analyze, identify, plan, implement, validate. Lessons learned: documented, root cause, process update, communication, training.

---

## Annex
Glossary (INOH, DVT, CSM, STRK, KYB, KYC, SLA, HSM). Technical references (Ethereum, Obol, Starknet, Gnosis). Emergency contacts: security `noa@seedlatam.org`, support `node@seedlatam.org`.

---

Document Version: 1.0  
Last Update: 2025‑01‑03  
Next Review: 2025‑01‑05  
Owner: Noa SEED Org
