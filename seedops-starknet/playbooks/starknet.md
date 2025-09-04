# Playbook Operativo - Validador Starknet
## Procedimientos Estándar de Operación

**Documento Operativo - SEED Org**  
**Versión:** 1.0  
**Fecha:** 2024  
**Clasificación:** Operativo  

---

## 📋 Índice

1. [Prerrequisitos](#prerrequisitos)
2. [Despliegue Inicial](#despliegue-inicial)
3. [Configuración del Sistema](#configuración-del-sistema)
4. [Despliegue del Validador](#despliegue-del-validador)
5. [Monitoreo y Alertas](#monitoreo-y-alertas)
6. [Mantenimiento Rutinario](#mantenimiento-rutinario)
7. [Respuesta a Incidentes](#respuesta-a-incidentes)
8. [Backup y Recuperación](#backup-y-recuperación)

---

## 🔧 Prerrequisitos

### Verificación de Sistema
```bash
# Verificar especificaciones mínimas
make check-system

# Verificar conectividad de red
make check-network

# Verificar acceso a repositorios
make check-repos
```

### Requisitos Previos
- [ ] Ubuntu 22.04 LTS instalado y actualizado
- [ ] Acceso root/sudo configurado
- [ ] Conexión a internet estable (1Gbps+)
- [ ] 64GB+ RAM disponible
- [ ] 4TB+ espacio en disco
- [ ] Claves SSH configuradas

---

## 🚀 Despliegue Inicial

### 1. Bootstrap del Sistema
```bash
# Ejecutar bootstrap completo
make bootstrap

# Verificar instalación
make verify-bootstrap
```

**Verificaciones:**
- [ ] Usuario `starknet` creado
- [ ] Docker instalado y funcionando
- [ ] Dependencias del sistema instaladas
- [ ] Directorios de trabajo creados

### 2. Hardening de Seguridad
```bash
# Aplicar configuraciones de seguridad
make harden

# Verificar configuraciones
make verify-security
```

**Verificaciones:**
- [ ] Firewall configurado (UFW)
- [ ] SSH hardening aplicado
- [ ] Usuarios no esenciales removidos
- [ ] Logs centralizados configurados

---

## ⚙️ Configuración del Sistema

### Variables de Entorno
```bash
# Copiar archivo de ejemplo
cp env/starknet.env.example env/starknet.env

# Editar configuración
nano env/starknet.env
```

**Variables Críticas:**
```bash
NETWORK=mainnet                    # mainnet, testnet, devnet
DATA_DIR=/opt/starknet/data        # Directorio de datos
KEYSTORE_PATH=/opt/starknet/keys   # Directorio de claves
LOG_LEVEL=info                     # Nivel de logging
RPC_PORT=9545                      # Puerto RPC
P2P_PORT=9546                      # Puerto P2P
```

### Configuración de Red
```bash
# Verificar puertos abiertos
netstat -tlnp | grep -E ':(9545|9546)'

# Configurar firewall
ufw allow 9545/tcp  # RPC
ufw allow 9546/tcp  # P2P
ufw reload
```

---

## 🏗️ Despliegue del Validador

### 1. Preparación de Directorios
```bash
# Crear estructura de directorios
sudo mkdir -p /opt/starknet/{data,keys,logs,config}
sudo chown -R starknet:starknet /opt/starknet
```

### 2. Configuración de Docker
```bash
# Renderizar configuración desde template
make render-config

# Verificar configuración
make verify-config
```

### 3. Despliegue del Servicio
```bash
# Levantar servicios
make deploy

# Verificar estado
make status
```

**Verificaciones:**
- [ ] Contenedores ejecutándose
- [ ] Logs sin errores críticos
- [ ] Puertos escuchando correctamente
- [ ] Sincronización iniciada

---

## 📊 Monitoreo y Alertas

### 1. Despliegue de Monitoreo
```bash
# Instalar y configurar monitoreo
make monitor

# Verificar métricas
make check-metrics
```

### 2. Configuración de Alertas
```bash
# Verificar alertas configuradas
make check-alerts

# Test de notificaciones
make test-alerts
```

**Métricas Críticas:**
- **CPU:** > 90% por 5 minutos
- **RAM:** > 95% por 5 minutos
- **Disk:** > 90% por 5 minutos
- **Sync:** > 24 horas sin progreso
- **Uptime:** < 99.9% mensual

---

## 🔄 Mantenimiento Rutinario

### Mantenimiento Diario
```bash
# Verificar estado general
make daily-check

# Revisar logs de errores
make check-logs
```

### Mantenimiento Semanal
```bash
# Backup de configuraciones
make backup

# Verificar espacio en disco
make check-disk

# Análisis de performance
make performance-review
```

### Mantenimiento Mensual
```bash
# Actualización de sistema
make system-update

# Rotación de logs
make rotate-logs

# Verificación de backups
make verify-backups
```

---

## 🚨 Respuesta a Incidentes

### 1. Clasificación de Incidentes

#### Crítico (P1)
- **Criterios:** Servicio completamente caído
- **Tiempo de Respuesta:** < 15 minutos
- **Escalación:** Automática a on-call

#### Alto (P2)
- **Criterios:** Degradación severa de servicio
- **Tiempo de Respuesta:** < 1 hora
- **Escalación:** Manual a on-call

#### Medio (P3)
- **Criterios:** Problemas menores de performance
- **Tiempo de Respuesta:** < 4 horas
- **Escalación:** Ticket en sistema

### 2. Procedimientos de Respuesta

#### Incidente Crítico
```bash
# 1. Activar procedimiento de emergencia
make incident critical

# 2. Recolectar información de diagnóstico
make collect-diagnostics

# 3. Aplicar mitigación inmediata
make emergency-mitigation

# 4. Escalar a equipo de respuesta
make escalate-incident
```

#### Procedimiento de Diagnóstico
```bash
# Recolectar logs del sistema
make collect-logs

# Verificar estado de servicios
make check-services

# Analizar métricas de performance
make analyze-metrics

# Generar reporte de incidente
make incident-report
```

---

## 💾 Backup y Recuperación

### 1. Estrategia de Backup

#### Backup Diario
```bash
# Backup incremental automático
make backup-daily

# Verificación de integridad
make verify-backup-daily
```

#### Backup Semanal
```bash
# Backup completo semanal
make backup-weekly

# Test de restauración
make test-restore
```

### 2. Procedimientos de Recuperación

#### Recuperación Completa
```bash
# 1. Detener servicios
make stop-services

# 2. Restaurar desde backup
make restore-backup

# 3. Verificar integridad
make verify-restore

# 4. Reiniciar servicios
make start-services
```

#### Recuperación Parcial
```bash
# Restaurar solo configuración
make restore-config

# Restaurar solo datos
make restore-data

# Verificar estado
make verify-partial-restore
```

---

## 📋 Checklist de Verificación

### Pre-Despliegue
- [ ] Sistema cumple especificaciones mínimas
- [ ] Usuario starknet creado y configurado
- [ ] Dependencias instaladas
- [ ] Variables de entorno configuradas
- [ ] Puertos de red disponibles

### Post-Despliegue
- [ ] Contenedores ejecutándose correctamente
- [ ] Logs sin errores críticos
- [ ] Sincronización progresando
- [ ] Monitoreo funcionando
- [ ] Alertas configuradas

### Operación Diaria
- [ ] Estado de servicios verificado
- [ ] Logs revisados
- [ ] Métricas dentro de rangos normales
- [ ] Backups ejecutados exitosamente

---

## 🔗 Referencias

- [Documentación Oficial Starknet](https://docs.starknet.io/)
- [INOH - Estándares de Infraestructura](INOH/starknet-infra.md)
- [Procedimientos de Emergencia](../scripts/90_incident.sh)
- [Configuración de Monitoreo](../scripts/30_monitoring.sh)

---

**Documento Operativo - SEED Org**  
**Última Actualización:** 2024  
**Próxima Revisión:** 2025
