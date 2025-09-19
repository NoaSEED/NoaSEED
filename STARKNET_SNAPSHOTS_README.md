# 🚀 SEEDNodes - Starknet Sepolia Installer with Juno Snapshots

## 📋 Overview

Instalador one-click para nodo Starknet Sepolia con **sincronización ultra rápida** usando snapshots oficiales de Juno. Reduce el tiempo de sincronización de semanas a horas.

## ⚡ Características Principales

### 🚀 **Sincronización Acelerada**
- **Snapshots oficiales de Juno**: Descarga automática desde [juno.nethermind.io](https://juno.nethermind.io/snapshots/)
- **Sincronización ultra rápida**: De semanas a horas
- **Datos verificados**: Snapshots oficiales y confiables

### 📊 **Monitoreo Completo**
- **Prometheus**: Métricas del nodo
- **Grafana**: Dashboards visuales
- **Node Exporter**: Métricas del sistema
- **Health checks**: Verificación automática

### 🔧 **Configuración Automática**
- **Docker Compose**: Orquestación de servicios
- **Firewall**: Configuración automática de puertos
- **Variables de entorno**: Configuración optimizada
- **Permisos**: Configuración automática de usuarios

## 🛠️ Instalación

### **Requisitos del Sistema**
- **OS**: Ubuntu 20.04+ o Debian 11+
- **RAM**: 4GB+ (recomendado 8GB+)
- **Disco**: 50GB+ espacio libre
- **CPU**: 2+ cores
- **Red**: Conexión estable a internet

### **Instalación Rápida**
```bash
# Clonar repositorio
git clone https://github.com/NoaSEED/NoaSEED.git starknet-validator
cd starknet-validator

# Ejecutar instalador
chmod +x scripts/starknet_sepolia_installer_with_snapshots.sh
./scripts/starknet_sepolia_installer_with_snapshots.sh --yes
```

### **Instalación Interactiva**
```bash
# Clonar repositorio
git clone https://github.com/NoaSEED/NoaSEED.git starknet-validator
cd starknet-validator

# Ejecutar instalador (modo interactivo)
chmod +x scripts/starknet_sepolia_installer_with_snapshots.sh
./scripts/starknet_sepolia_installer_with_snapshots.sh
```

## 📊 Servicios Incluidos

### **1. Pathfinder Node**
- **Puerto**: 9545 (RPC)
- **Métricas**: 9187
- **Estado**: Verificación automática

### **2. Prometheus**
- **Puerto**: 9090
- **Función**: Recolección de métricas
- **Configuración**: Automática

### **3. Grafana**
- **Puerto**: 3000
- **Usuario**: admin
- **Contraseña**: admin
- **Dashboards**: Pre-configurados

### **4. Node Exporter**
- **Puerto**: 9100
- **Función**: Métricas del sistema
- **Configuración**: Automática

## 🔧 Comandos Útiles

### **Gestión de Servicios**
```bash
# Ver estado
docker compose ps

# Ver logs
docker compose logs -f pathfinder

# Reiniciar servicios
docker compose restart

# Detener servicios
docker compose down

# Iniciar servicios
docker compose up -d
```

### **Verificación de Sincronización**
```bash
# Verificar bloque actual
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"starknet_blockNumber","params":[],"id":1}' \
  http://localhost:9545

# Comparar con red pública
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"starknet_blockNumber","params":[],"id":1}' \
  https://starknet-sepolia.public.blastapi.io/rpc/v0_7
```

### **Monitoreo**
```bash
# Ver métricas
curl http://localhost:9187/metrics

# Ver estado de Prometheus
curl http://localhost:9090/api/v1/status/config

# Ver dashboards de Grafana
# Navegar a: http://localhost:3000
```

## 🛠️ Solución de Problemas

### **Problema: RPC no responde**
```bash
# Verificar logs
docker compose logs pathfinder

# Verificar estado del contenedor
docker compose ps

# Reiniciar servicio
docker compose restart pathfinder
```

### **Problema: Sincronización lenta**
```bash
# Verificar conexión a internet
ping -c 4 8.8.8.8

# Verificar logs de sincronización
docker compose logs -f pathfinder | grep -i sync

# Verificar métricas
curl http://localhost:9187/metrics | grep -i sync
```

### **Problema: Snapshots fallan**
```bash
# Verificar espacio en disco
df -h

# Verificar permisos
ls -la /usr/share/pathfinder/data

# Limpiar y reintentar
sudo rm -rf /usr/share/pathfinder/data/*
docker compose restart pathfinder
```

## 📈 Optimización

### **Para Mejor Rendimiento**
1. **SSD**: Usar SSD para datos del nodo
2. **RAM**: 8GB+ para mejor rendimiento
3. **CPU**: 4+ cores para sincronización más rápida
4. **Red**: Conexión estable y rápida

### **Para Menor Uso de Recursos**
1. **RAM**: 4GB mínimo
2. **CPU**: 2 cores mínimo
3. **Disco**: 50GB mínimo
4. **Red**: Conexión básica

## 🔒 Seguridad

### **Firewall Configurado**
- **Puerto 22**: SSH
- **Puerto 9545**: RPC (solo local)
- **Puerto 9090**: Prometheus (solo local)
- **Puerto 3000**: Grafana (solo local)
- **Puerto 9100**: Node Exporter (solo local)
- **Puerto 9187**: Métricas (solo local)

### **Recomendaciones**
- Cambiar contraseña de Grafana
- Configurar VPN para acceso remoto
- Monitorear logs regularmente
- Mantener sistema actualizado

## 📚 Recursos Adicionales

- **Documentación oficial**: [docs.starknet.io](https://docs.starknet.io)
- **Snapshots Juno**: [juno.nethermind.io/snapshots](https://juno.nethermind.io/snapshots/)
- **Pathfinder**: [github.com/eqlabs/pathfinder](https://github.com/eqlabs/pathfinder)
- **Prometheus**: [prometheus.io](https://prometheus.io)
- **Grafana**: [grafana.com](https://grafana.com)

## 🆘 Soporte

- **Issues**: [GitHub Issues](https://github.com/NoaSEED/NoaSEED/issues)
- **Discord**: [SEEDNodes Discord](https://discord.gg/seednodes)
- **Twitter**: [@SEEDNodes](https://twitter.com/seednodes)

## 📄 Licencia

MIT License - Ver [LICENSE](LICENSE) para más detalles.

---

**¡Disfruta de tu nodo Starknet Sepolia con sincronización ultra rápida! 🚀**
