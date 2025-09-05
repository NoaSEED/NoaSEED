# Playbook Starknet Sepolia (Pathfinder) – Bitcoin Pool Purpose
## SEEDNodes - NodeOps Institucionales

---

## Objetivo
Desplegar y operar un nodo de Starknet en red Sepolia usando Pathfinder vía Docker, como base de integración para un **Bitcoin Pool** (según la guía de referencia), con una instalación automatizada y reproducible.

Fuente de referencia: [Starknet Sepolia - Notion](https://www.notion.so/Starknet-Sepolia-2641ac70713480e2b282f834703bac7c)

---

## Requisitos
- CPU: 4+ cores
- RAM: 8 GB+
- Disco: 250 GB SSD+
- OS: Ubuntu 22.04 LTS
- Red: 25 Mbps+
- Puertos: 9545 (HTTP RPC), 9187 (métricas PathFinder), 9090 (Prometheus), 3000 (Grafana), 9100 (Node Exporter), 22 (SSH)

---

## Instalación Automatizada
```bash
git clone https://github.com/NoaSEED/seedops-institutional.git
cd seedops-institutional
chmod +x scripts/starknet_sepolia_installer.sh
./scripts/starknet_sepolia_installer.sh
```
El instalador solicita:
- Ethereum Sepolia RPC (por ejemplo, Infura/Alchemy)
- Directorio de datos (default: /var/lib/pathfinder)
- Puerto HTTP RPC (default: 9545)
- Activar o no el stack de monitoreo (Prometheus + Grafana + Node Exporter)

---

## Qué hace el instalador
- Actualiza paquetes y dependencias
- Instala Docker + Docker Compose
- Configura UFW con los puertos necesarios (9545/9187/9090/3000/9100)
- Genera `env/starknet-sepolia.env`
- Genera `compose/starknet-sepolia.docker-compose.yml`
- Genera `monitoring/prometheus-starknet.yml` y provisioning de Grafana
- Levanta `pathfinder` (y opcionalmente `prometheus` + `grafana` + `node-exporter`)

---

## Operación
```bash
# Ver logs
docker compose -f compose/starknet-sepolia.docker-compose.yml logs -fn 200

# Estado del servicio
docker compose -f compose/starknet-sepolia.docker-compose.yml ps

# Detener
docker compose -f compose/starknet-sepolia.docker-compose.yml down
```

- HTTP RPC: http://<server-ip>:9545  
- Métricas (scrape): http://<server-ip>:9187  
- Prometheus: http://<server-ip>:9090  
- Grafana: http://<server-ip>:3000 (admin/admin por defecto)

---

## Monitoreo
- Prometheus `starknet_pathfinder` scraping a `pathfinder:9187`.
- Prometheus `node_exporter` scraping a `node-exporter:9100`.
- Dashboards Grafana:
  - “Starknet Pathfinder + Host”: estado `up`, CPU %, Memory %.
  - Puedes añadir paneles para disco, red y latencias RPC.

---

## Mantenimiento
- Actualizar imagen:
```bash
docker compose -f compose/starknet-sepolia.docker-compose.yml pull
docker compose -f compose/starknet-sepolia.docker-compose.yml up -d
```
- Backup de datos: respaldar el directorio de datos (default `/var/lib/pathfinder`).

---

**Responsable**: Noa SEED Org
