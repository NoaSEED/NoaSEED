# Playbook Aztec - Sequencer Node
## SEEDNodes - NodeOps Institucionales

---

## Objetivo

Configurar y operar un nodo secuenciador de Aztec Network, optimizando para máxima eficiencia y uptime ≥ 99.9% con estándares institucionales.

---

## Prerequisitos

### Hardware Mínimo
- **CPU**: 4+ cores (ARM64/x86_64)
- **RAM**: 8GB+ DDR4
- **Storage**: 250GB+ NVMe SSD
- **Network**: 25Mbps+ simétrico

### Software Requerido
- **OS**: Ubuntu 22.04 LTS (probado y estable)
- **Docker**: 24.0+ (contenedores para aislamiento)
- **Docker Compose**: 2.20+ (orquestación de servicios)

### Información Requerida
- **Sepolia RPC**: URL del proveedor RPC
- **Beacon RPC**: URL del proveedor Beacon
- **Wallet Private Key**: Clave privada (usar wallet nueva)
- **Wallet Address**: Dirección del wallet (fundir con Sepolia ETH)
- **IP Address**: IP del VPS

---

## Instalación Automatizada

### Script de Instalación
```bash
# Ejecutar script automatizado
./scripts/aztec_installer.sh
```

### Proceso Manual (si es necesario)

#### 1. Actualizar Sistema
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

#### 2. Instalar Paquetes
```bash
sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
    libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev ufw \
    screen gawk -y
```

#### 3. Instalar Docker
```bash
# Script de instalación Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### 4. Configurar Firewall
```bash
sudo ufw allow 22
sudo ufw allow ssh
sudo ufw allow 40400/tcp
sudo ufw allow 40400/udp
sudo ufw allow 8080
sudo ufw allow 9999
sudo ufw --force enable
```

---

## Configuración

### Variables de Entorno
```bash
# env/aztec.env
AZTEC_NETWORK=alpha-testnet
ETHEREUM_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
CONSENSUS_BEACON_URL=https://sepolia-beacon.infura.io/v3/YOUR_KEY
VALIDATOR_PRIVATE_KEYS=0xYourPrivateKey
COINBASE=0xYourAddress
P2P_IP=Your-IP-Address
LOG_LEVEL=info
```

### Docker Compose
```yaml
# compose/aztec.docker-compose.yml
services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:1.2.1
    restart: unless-stopped
    network_mode: host
    environment:
      ETHEREUM_HOSTS: ${ETHEREUM_RPC_URL}
      L1_CONSENSUS_HOST_URLS: ${CONSENSUS_BEACON_URL}
      DATA_DIRECTORY: /data
      VALIDATOR_PRIVATE_KEYS: ${VALIDATOR_PRIVATE_KEYS}
      COINBASE: ${COINBASE}
      P2P_IP: ${P2P_IP}
      LOG_LEVEL: info
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - /root/.aztec/alpha-testnet/data/:/data
```

---

## Despliegue

### Iniciar Nodo
```bash
# Usar script automatizado
./scripts/aztec_installer.sh

# O manualmente
docker compose up -d
```

### Verificar Estado
```bash
# Ver logs
docker compose logs -fn 1000

# Verificar sincronización
bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/sync-check.sh)

# Estado del contenedor
docker compose ps
```

---

## Monitoreo

### Métricas Clave
- **Uptime**: ≥ 99.9%
- **Sync Status**: 100%
- **Block Production**: Continuo
- **P2P Connections**: Estables
- **Memory Usage**: < 85%
- **CPU Usage**: < 80%

### Herramientas de Monitoreo

#### Dozzle (Logs)
```bash
# Instalar Dozzle
docker run -d --name dozzle -v /var/run/docker.sock:/var/run/docker.sock -p 9999:8080 amir20/dozzle:latest

# Acceder: http://YOUR_IP:9999
```

#### Prometheus + Grafana
```bash
# Usar configuración de monitoreo
make monitor-aztec
```

### Alertas Automáticas
- **Critical**: Nodo caído, sync perdido
- **Warning**: Recursos altos, conexiones bajas
- **Info**: Updates disponibles, backups completados

---

## Backup y Recuperación

### Backup Automático
```bash
#!/bin/bash
# scripts/backup_aztec.sh

BACKUP_DIR="/backups/aztec/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup de datos
docker exec aztec-sequencer tar -czf /tmp/aztec-data.tar.gz /data
docker cp aztec-sequencer:/tmp/aztec-data.tar.gz $BACKUP_DIR/

# Backup de configuración
cp .env $BACKUP_DIR/
cp docker-compose.yml $BACKUP_DIR/

# Verificar integridad
sha256sum $BACKUP_DIR/* > $BACKUP_DIR/checksums.txt

log "Backup completado: $BACKUP_DIR"
```

### Restauración
```bash
#!/bin/bash
# scripts/restore_aztec.sh

BACKUP_DIR=$1
if [ -z "$BACKUP_DIR" ]; then
    error "Especificar directorio de backup"
fi

# Restaurar datos
docker cp $BACKUP_DIR/aztec-data.tar.gz aztec-sequencer:/tmp/
docker exec aztec-sequencer tar -xzf /tmp/aztec-data.tar.gz -C /

# Restaurar configuración
cp $BACKUP_DIR/.env .
cp $BACKUP_DIR/docker-compose.yml .

# Reiniciar nodo
docker compose restart

log "Restauración completada"
```

---

## Respuesta a Incidentes

### Niveles de Severidad
- **P0**: Nodo caído, sync perdido
- **P1**: Performance degradada, recursos críticos
- **P2**: Alertas de monitoreo, updates pendientes
- **P3**: Información, mantenimiento programado

### Procedimientos de Recuperación

#### Nodo Caído
```bash
# 1. Verificar estado
docker compose ps

# 2. Ver logs de error
docker compose logs --tail=100

# 3. Reiniciar si es necesario
docker compose restart

# 4. Verificar sincronización
bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/sync-check.sh)
```

#### Sync Perdido
```bash
# 1. Detener nodo
docker compose down

# 2. Limpiar datos corruptos (cuidado!)
sudo rm -rf /root/.aztec/alpha-testnet/data/

# 3. Reiniciar
docker compose up -d

# 4. Monitorear resync
docker compose logs -fn 1000
```

---

## Optimización y Performance

### Tuning del Sistema
```bash
#!/bin/bash
# scripts/optimize_aztec.sh

# Optimizar parámetros de red
echo 'net.core.rmem_max = 268435456' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 268435456' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 131072 268435456' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 131072 268435456' >> /etc/sysctl.conf

# Optimizar Docker
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl restart docker
log "Sistema optimizado para Aztec ✓"
```

### Monitoreo de Recursos
```bash
# CPU y memoria
htop

# Disco
df -h
du -sh /root/.aztec/alpha-testnet/data/

# Red
netstat -tulpn | grep -E "(40400|8080)"
```

---

## Checklist de Verificación

### Pre-Despliegue
- [ ] Hardware cumple requisitos (4+ cores, 8GB+ RAM, 250GB+ SSD)
- [ ] Sistema operativo actualizado
- [ ] Docker y Docker Compose instalados
- [ ] Variables de entorno configuradas
- [ ] Wallet fundido con Sepolia ETH (0.2-0.5 ETH)
- [ ] Red y firewall configurados

### Post-Despliegue
- [ ] Nodo iniciado correctamente
- [ ] Logs muestran sincronización
- [ ] P2P puerto 40400 accesible
- [ ] RPC puerto 8080 funcionando
- [ ] Monitoreo configurado
- [ ] Backups programados

### Operación Continua
- [ ] Uptime ≥ 99.9%
- [ ] Sync status 100%
- [ ] Recursos dentro de límites
- [ ] Logs sin errores críticos
- [ ] Backups ejecutándose
- [ ] Alertas funcionando

---

**Documento Version**: 1.0  
**Última Actualización**: 2025-01-05  
**Próxima Revisión**: 2025-04-05  
**Responsable**: Noa SEED Org

---

*"Este playbook garantiza que cada despliegue de Aztec en SEEDNodes cumple con estándares institucionales de seguridad, transparencia y continuidad."*
