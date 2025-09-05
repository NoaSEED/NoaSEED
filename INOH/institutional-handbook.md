# INOH - Manual de Operaciones de Nodos Institucionales
## SEEDNodes - Estándar Maestro para NodeOps

---

## Tabla de Contenidos

1. [Objetivo Institucional](#objetivo-institucional)
2. [Infraestructura Mínima](#infraestructura-mínima)
3. [Procedimientos Operativos](#procedimientos-operativos)
4. [Seguridad & Compliance](#seguridad--compliance)
5. [Monitoreo & Reporting](#monitoreo--reporting)
6. [Auditorías Integradas](#auditorías-integradas)
7. [Agentic NodeOps](#agentic-nodeops)
8. [Gobernanza](#gobernanza)

---

## Objetivo Institucional

### Misión
Operar infraestructura de nodos blockchain con estándares institucionales en LATAM, desarrollando procesos automatizados, auditables y escalables.

### Visión
Establecer mejores prácticas para la industria con estándares institucionales que garantizan:
- **Seguridad**: Zero trust, auditorías continuas
- **Transparencia**: Trazabilidad completa de operaciones
- **Confiabilidad**: Uptime ≥ 99.9%, respuesta predictiva
- **Escalabilidad**: Orquestación multired (Ethereum, Gnosis, Starknet, Aztec)

### Diferenciadores Institucionales
1. **Automatización Avanzada**: Procesos autónomos con sistemas que se adaptan
2. **Audit Trail**: Cada operación genera evidencia verificable
3. **Monitoreo Predictivo**: Detección temprana de problemas
4. **Hub Multired**: Orquestación centralizada de múltiples redes
5. **Compliance Institucional**: Estándares KYB/KYC que cumplen regulaciones locales

---

## Infraestructura Mínima

### Requisitos de Hardware

#### Nodos de Producción
- **CPU**: 8+ cores (ARM64/x86_64)
- **RAM**: 32GB+ DDR4
- **Storage**: 2TB+ NVMe SSD
- **Network**: 1Gbps+ simétrico
- **Uptime**: 99.9% SLA

#### Nodos de Staging
- **CPU**: 4+ cores
- **RAM**: 16GB+
- **Storage**: 1TB+ SSD
- **Network**: 100Mbps+

### Requisitos de Software

#### Sistema Operativo
- **Ubuntu 22.04 LTS** (probado y estable)
- **Docker Engine** 24.0+ (contenedores para aislamiento)
- **Docker Compose** 2.20+ (orquestación de servicios)
- **Git** 2.40+ (control de versiones)

#### Herramientas de Seguridad
- **UFW** (firewall - primera línea de defensa)
- **Fail2ban** (protección SSH contra ataques de fuerza bruta)
- **SSH Key-based auth** (sin passwords - solo claves)
- **VPN** (acceso remoto seguro)

#### Monitoreo
- **Prometheus** + **Grafana** (métricas y visualización)
- **Node Exporter** (métricas del sistema)
- **AlertManager** (gestión de alertas)
- **Telegram/Discord** (notificaciones en tiempo real)

### Redes Soportadas

| Red | Tipo | Validadores | Sequencers | Estado |
|-----|------|-------------|------------|--------|
| **Ethereum** | Obol DVT | ✅ | ❌ | Producción |
| **Gnosis** | Native | Variable | ❌ | Producción |
| **Starknet** | Delegación | ✅ | ❌ | Desarrollo |
| **Aztec** | Native | ✅ | ✅ | Investigación |

---

## Procedimientos Operativos

### 1. Bootstrap (Configuración Inicial)

```bash
# Ejecutar en orden secuencial
make bootstrap    # Configuración base del sistema
make harden       # Aplicar medidas de seguridad
make deploy       # Desplegar nodo específico
make monitor      # Configurar monitoreo
make backup       # Configurar backups
```

#### Checklist de Bootstrap
- [ ] Sistema operativo actualizado
- [ ] Usuario no-root creado
- [ ] SSH configurado (solo keys)
- [ ] Docker instalado y configurado
- [ ] Repositorio clonado
- [ ] Variables de entorno configuradas
- [ ] Logs de auditoría habilitados

### 2. Hardening (Seguridad Institucional)

#### Medidas Obligatorias
- [ ] **Firewall**: UFW activo, puertos mínimos
- [ ] **SSH**: Sin password auth, solo keys
- [ ] **Fail2ban**: Protección contra ataques
- [ ] **Updates**: Automáticos de seguridad
- [ ] **Logs**: Centralizados y rotados
- [ ] **VPN**: Acceso remoto obligatorio

#### Auditoría Post-Hardening
```bash
# Generar reporte de seguridad
./scripts/audit_security.sh
# Output: security-audit-YYYY-MM-DD.pdf
```

### 3. Deploy (Despliegue por Red)

#### Ethereum (Obol DVT)
```bash
make deploy-ethereum
# - Configura Obol DVT
# - Registra validadores
# - Configura monitoring
# - Genera audit log
```

#### Gnosis (108 Validators)
```bash
make deploy-gnosis
# - Configura validadores nativos
# - Optimiza para 108 validadores
# - Configura monitoring específico
```

#### Starknet (Delegación STRK)
```bash
make deploy-starknet
# - Configura delegación
# - Optimiza para STRK rewards
# - Monitoreo de delegaciones
```

#### Aztec (Validators + Sequencers)
```bash
make deploy-aztec
# - Configura validadores
# - Configura sequencers
# - Monitoreo dual
```

### 4. Monitoring (Monitoreo Predictivo)

#### Métricas Obligatorias
- **Uptime**: ≥ 99.9%
- **CPU**: < 80% promedio
- **RAM**: < 85% promedio
- **Disk**: < 90% uso
- **Network**: Latencia < 100ms
- **Block Production**: 100% en tiempo

#### Alertas Automáticas
- **Critical**: Nodo caído, slashing risk
- **Warning**: Recursos altos, latencia alta
- **Info**: Updates disponibles, backups completados

### 5. Backup (Respaldo Auditado)

#### Frecuencia
- **Diario**: Configuraciones críticas
- **Semanal**: Estado completo del nodo
- **Mensual**: Backup completo + restore test

#### Validación
```bash
# Cada backup incluye:
# - Hash SHA256 del archivo
# - Test de restore en staging
# - Verificación de integridad
# - Log de auditoría
```

### 6. Incident Response (Respuesta a Incidentes)

#### Niveles de Severidad
- **P0**: Nodo caído, slashing inminente
- **P1**: Performance degradada, recursos críticos
- **P2**: Alertas de monitoreo, updates pendientes
- **P3**: Información, mantenimiento programado

#### Proceso Automatizado
1. **Detección**: Monitoring detecta anomalía
2. **Clasificación**: Agent clasifica severidad
3. **Acción**: Auto-ejecuta script de recuperación
4. **Notificación**: Alerta a equipo vía Telegram/Discord
5. **Documentación**: Log automático en audit-logs
6. **Escalación**: Si no se resuelve, escalar a humano

---

## Seguridad & Compliance

### Zero Trust Architecture

#### Principios
1. **Never Trust, Always Verify**: Cada acceso verificado
2. **Least Privilege**: Permisos mínimos necesarios
3. **Defense in Depth**: Múltiples capas de seguridad
4. **Continuous Monitoring**: Vigilancia 24/7

#### Implementación
- **VPN**: Acceso remoto obligatorio
- **MFA**: Autenticación multifactor
- **SSH Keys**: Sin passwords
- **Firewall**: Puertos mínimos abiertos
- **Audit Logs**: Registro de todas las acciones

### Gestión de Claves

#### Validator Keys
- **Generación**: Hardware security module (HSM)
- **Almacenamiento**: Encriptado, múltiples copias
- **Rotación**: Automática cada 90 días
- **Backup**: 3 copias en ubicaciones diferentes

#### API Keys
- **Vault**: Hashicorp Vault para almacenamiento
- **Rotación**: Automática cada 30 días
- **Acceso**: Solo para procesos autorizados
- **Audit**: Log de cada uso

### Compliance Institucional

#### KYB/KYC
- **Verificación**: Identidad de la organización
- **Documentación**: Certificados y licencias
- **Actualización**: Anual o por cambios
- **Almacenamiento**: Encriptado, acceso restringido

#### Auditorías
- **Interna**: Mensual, por Governance Lead
- **Externa**: Trimestral, por auditor independiente
- **Regulatoria**: Según requerimientos locales
- **Técnica**: Continua, automatizada

---

## Monitoreo & Reporting

### KPIs Institucionales

#### Métricas de Red
- **Uptime**: ≥ 99.9% por nodo
- **APR**: Rendimiento vs. red
- **Slashing Events**: 0 eventos (objetivo)
- **Costos**: Tracking completo de gastos

#### Métricas Operacionales
- **Tiempo de Respuesta**: < 5 minutos para P0
- **Disponibilidad**: 24/7/365
- **Escalabilidad**: Auto-scaling según demanda
- **Eficiencia**: Optimización continua

### Dashboard Institucional

#### Métricas en Tiempo Real
- Estado de todos los nodos
- Performance por red
- Alertas activas
- Recursos utilizados

#### Reportes Automáticos
- **Diario**: Resumen de operaciones
- **Semanal**: Performance y alertas
- **Mensual**: Reporte ejecutivo completo
- **Trimestral**: Análisis de tendencias

### Notificaciones

#### Canales
- **Telegram**: Alertas críticas
- **Discord**: Notificaciones generales
- **Email**: Reportes ejecutivos
- **Slack**: Comunicación interna

#### Escalamiento
- **P0**: Notificación inmediata a todo el equipo
- **P1**: Notificación a DevOps + Monitoring Lead
- **P2**: Notificación a Monitoring Lead
- **P3**: Log en dashboard

---

## Auditorías Integradas

### Tipos de Auditoría

#### 1. Auditoría de Infraestructura
```bash
# Cada proceso genera registro:
# 2025-01-XX 21:14 UTC | validator-starknet-01 | deploy.sh | SUCCESS | Commit: a1b2c3d
```

#### 2. Auditoría de Seguridad
```bash
# Post-hardening checklist:
# - Puertos abiertos: [22, 80, 443] ✅
# - SSH password auth: DISABLED ✅
# - UFW status: ACTIVE ✅
# - Fail2ban: RUNNING ✅
```

#### 3. Auditoría de Backups
```bash
# Validación de backup:
# Backup test OK | starknet-config-2025-01-XX.tgz | SHA256 match ✅
```

#### 4. Auditoría de Monitoreo
```bash
# Verificación de métricas:
# - Prometheus: RUNNING ✅
# - Grafana: ACCESSIBLE ✅
# - AlertManager: CONFIGURED ✅
# - Notifications: TESTED ✅
```

### Proceso de Auditoría

#### Automatizada (Continua)
- Cada operación genera log
- Validación automática de resultados
- Alertas por desviaciones
- Reportes automáticos

#### Manual (Periódica)
- **Semanal**: Revisión de logs por Monitoring Lead
- **Mensual**: Auditoría completa por Governance Lead
- **Trimestral**: Auditoría externa independiente

### Evidencia Auditada

#### Requisitos
- **Trazabilidad**: Cada acción documentada
- **Verificabilidad**: Hash y timestamps
- **Inmutabilidad**: Logs en blockchain o repo inmutable
- **Accesibilidad**: Disponible para auditores

#### Almacenamiento
- **Local**: `/var/log/seedops/`
- **Remoto**: Repo privado `audit-logs`
- **Backup**: Múltiples ubicaciones
- **Retención**: 7 años (requerimiento legal)

---

## Agentic NodeOps

### Evolución de Automatización

#### Fase 1: Scripts Manuales
- Scripts ejecutados bajo demanda
- Dependencia de humanos
- Procesos documentados pero manuales

#### Fase 2: Automatización Básica
- Cron jobs para tareas repetitivas
- Monitoreo básico con alertas
- Backups automatizados

#### Fase 3: Agentic AI (Objetivo)
- **Agents autónomos** que detectan y responden
- **Procesos auto-ejecutables** sin intervención humana
- **Respuesta predictiva** a problemas

### Implementación de Agents

#### Security Agent
```python
# Detecta anomalías de seguridad:
# - Puertos abiertos no autorizados
# - Intentos de acceso SSH
# - Cambios en configuración
# → Ejecuta hardening automáticamente
```

#### Backup Agent
```python
# Gestiona backups automáticamente:
# - Ejecuta backup diario
# - Valida integridad
# - Sube a storage remoto
# - Notifica si falla
```

#### Incident Agent
```python
# Responde a incidentes:
# - Detecta nodo caído
# - Ejecuta script de recuperación
# - Reinicia servicios
# - Notifica al equipo
# - Documenta en audit-logs
```

#### Monitoring Agent
```python
# Monitoreo predictivo:
# - Analiza tendencias de recursos
# - Predice fallos de disco/CPU
# - Ejecuta auto-scaling
# - Optimiza configuración
```

### Orquestación Multired

#### Hub Central
- **Un solo punto de control** para todas las redes
- **Procesos estandarizados** entre redes
- **Seguridad centralizada**
- **Monitoreo unificado**

#### Pipeline CI/CD
```yaml
# GitHub Actions workflow:
# 1. Valida sintaxis de playbooks
# 2. Ejecuta en staging
# 3. Pruebas automatizadas
# 4. Deploy a producción
# 5. Monitoreo post-deploy
```

### Capa Predictiva

#### Modelos de ML
- **Predicción de recursos**: CPU, RAM, disco
- **Detección de anomalías**: Patrones inusuales
- **Optimización automática**: Configuración dinámica
- **Prevención de fallos**: Anticipación de problemas

#### Implementación
- **Datos**: Métricas históricas de todos los nodos
- **Modelo**: TensorFlow/PyTorch para predicción
- **Acción**: Auto-scaling y optimización
- **Feedback**: Mejora continua del modelo

---

## Gobernanza

### Estructura Organizacional

#### Roles y Responsabilidades

| Rol | Responsabilidades | Escalamiento |
|-----|------------------|--------------|
| **Research Lead** | Análisis de estándares, métricas | Governance Lead |
| **Tech Lead** | Playbooks técnicos, implementación | DevOps Lead |
| **DevOps Lead** | Scripts, automatización, deploy | Monitoring Lead |
| **Monitoring Lead** | KPIs, reportes, alertas | Governance Lead |
| **Governance Lead** | Compliance, auditorías, procesos | CEO |
| **Comms Lead** | Documentación ejecutiva, comunicación | Governance Lead |

#### RACI Matrix

| Proceso | Research | Tech | DevOps | Monitoring | Governance | Comms |
|---------|----------|------|--------|------------|------------|-------|
| **Bootstrap** | C | R | A | I | I | I |
| **Hardening** | I | C | A | R | I | I |
| **Deploy** | I | R | A | C | I | I |
| **Monitoring** | I | I | C | A | R | I |
| **Backup** | I | I | A | C | R | I |
| **Incident** | I | I | A | R | C | I |
| **Audit** | I | I | I | C | A | R |
| **Reporting** | I | I | I | A | R | C |

*R=Responsible, A=Accountable, C=Consulted, I=Informed*

### Procesos de Decisión

#### Niveles de Autoridad
- **Operacional**: DevOps Lead (cambios menores)
- **Técnico**: Tech Lead (cambios de configuración)
- **Estratégico**: Governance Lead (cambios de proceso)
- **Institucional**: CEO (cambios de política)

#### Comités
- **Technical Committee**: Tech + DevOps + Monitoring
- **Governance Committee**: Governance + Comms + CEO
- **Audit Committee**: Governance + Monitoring + externo

### Ciclo de Mejora Continua

#### Revisión Trimestral
1. **Análisis**: Performance vs. objetivos
2. **Identificación**: Oportunidades de mejora
3. **Planificación**: Acciones correctivas
4. **Implementación**: Cambios en procesos
5. **Validación**: Medición de resultados

#### Lessons Learned
- **Documentación**: Cada incidente documentado
- **Análisis**: Causa raíz identificada
- **Mejora**: Proceso actualizado
- **Comunicación**: Compartido con equipo
- **Training**: Capacitación actualizada

---

## Anexos

### A. Glosario de Términos
- **INOH**: Institutional Node Operations Handbook
- **DVT**: Distributed Validator Technology
- **CSM**: Consensus Layer Client
- **STRK**: Starknet Token
- **KYB**: Know Your Business
- **KYC**: Know Your Customer
- **SLA**: Service Level Agreement
- **HSM**: Hardware Security Module

### B. Referencias Técnicas
- [Ethereum Validator Guide](https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/)
- [Obol DVT Documentation](https://docs.obol.tech/)
- [Starknet Documentation](https://docs.starknet.io/)
- [Gnosis Chain Validators](https://docs.gnosischain.com/)

### C. Contactos de Emergencia
- **Security Issues**: noa@seedlatam.org
- **Technical Support**: node@seedlatam.org

---

**Documento Version**: 1.0  
**Última Actualización**: 2025-01-03  
**Próxima Revisión**: 2025-01-05  
**Responsable**: SEED Org ltd

---

*"El INOH es el estándar maestro de SEEDNodes para operación de nodos. Cada despliegue sigue esta estructura, garantizando que nuestras prácticas cumplen con niveles institucionales de seguridad, transparencia y continuidad."*

