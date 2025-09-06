# Capacity Planning & Technical Baseline

This document provides guidance for sizing and baseline technical requirements. Values are indicative and MUST be validated per network release notes.

## Hardware Guidelines
- Production: 8+ vCPU, 32GB+ RAM, 2TB+ NVMe SSD, 1Gbps+, 99.9% SLA
- Staging: 4+ vCPU, 16GB+ RAM, 1TB+ SSD, 100Mbps+

## Software Baseline
- Ubuntu 22.04 LTS
- Docker 24+, Docker Compose 2.20+
- Git 2.40+

## Security Tooling Baseline
- UFW (firewall), Fail2ban, SSH keys only, VPN for administrative access

## Monitoring Baseline
- Prometheus, Grafana, Node Exporter, Alertmanager
- Notifications: Telegram/Discord/Email/Slack

## Network-Specific Notes
Maintain ports, images/tags, and health checks in each network playbook (`playbooks/*.md`) and Compose files (`compose/*.yml`).

---

Last Update: 2025-09-06
Owner: Noa SEED Org


