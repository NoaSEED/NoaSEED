<div align="center">
  <img src="assets/seednodes-hero.svg" alt="SEEDNodes - Institutional NodeOps" width="600"/>
</div>

We are a team of blockchain infrastructure engineers and operators with a single goal: to run nodes and validators to institutional standards. Blockchain infrastructure must be more reliable—and we are here to make it better.

Our mission is to design, deploy, and maintain blockchain node infrastructure with automated, auditable, and scalable processes. We operate to the highest standards of security, transparency, and continuity.

We run validators on leading web3 networks, including Ethereum, Gnosis, Starknet, Aztec, and more.

---

<div align="center">

[![Twitter](https://img.shields.io/badge/Twitter-@SeedsPuntoEth-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/SeedsPuntoEth)
[![NodeOps](https://img.shields.io/badge/NodeOps-Institutional-00ff88?style=for-the-badge&logo=server&logoColor=black)](https://github.com/NoaSEED/seedops-institutional)

</div>

## Project Structure

```
seedops-institutional/
├── INOH/                          # Institutional Node Operations Handbook
│   ├── institutional-handbook.en.md
│   └── institutional-handbook.md
├── playbooks/                     # Technical playbooks per network
│   ├── ethereum.en.md
│   ├── gnosis.en.md
│   ├── starknet.en.md
│   ├── starknet-sepolia.en.md
│   └── aztec.en.md
├── scripts/                       # Automation scripts
│   ├── 00_bootstrap.sh            # System bootstrap
│   ├── aztec_installer.sh         # Aztec Sequencer installer
│   └── starknet_sepolia_installer.sh
├── templates/                     # Config templates (Jinja2)
├── compose/                       # Docker Compose per network
├── env/                           # Environment examples per network
├── monitoring/                    # Prometheus/Grafana provisioning
├── audit-logs/                    # Operation evidence
└── docs/
```

## Implementation Phases

- Phase 1: Research and baseline standards
- Phase 2: INOH (handbook), security standards, audit procedures
- Phase 3: Network playbooks (Ethereum, Gnosis, Starknet, Aztec)
- Phase 4: Monitoring & reporting (KPIs, dashboards)
- Phase 5: Continuous improvement (quarterly reviews)

## NodeOps Automation

- Current: automated scripts (bootstrap, hardening, deploy, monitor, backup, incident)
- Advanced: automated vulnerability detection and hardening; encrypted daily backups; automated incident response with notifications
- Multi‑network orchestration: unified CI/CD, centralized security and monitoring
- Predictive monitoring: resource trends, early threat detection, preventive scaling

## Institutional Security

- Zero‑trust: VPN + MFA, no hardcoded secrets
- Auditability: every action recorded in `audit-logs`
- Security testing: attack simulations via playbooks

## Integrated Audits

Each process produces verifiable evidence:
- Infrastructure: timestamp, actor, host, commit hash, result
- Security: post‑hardening checklist
- Backups: SHA256 + restore test
- Monitoring: metrics and SLA validation

## Deliverable

Every operational action at SEEDNodes generates complete audit evidence. Deployments, updates, and backups require verifiable proof to be considered valid—ensuring transparency, traceability, and trust for delegators, foundations, and stakeholders.

---

For Spanish documentation, see the corresponding `.md` files. This English edition mirrors the same structure and standards with concise technical language.

