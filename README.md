<div align="center">

# SEEDNodes

**NodeOps Institucionales**

```
███████╗███████╗███████╗██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗███████╗
██╔════╝██╔════╝██╔════╝██╔══██╗████╗  ██║██╔═══██╗██╔══██╗██╔════╝██╔════╝
███████╗█████╗  █████╗  ██║  ██║██╔██╗ ██║██║   ██║██║  ██║█████╗  ███████╗
╚════██║██╔══╝  ██╔══╝  ██║  ██║██║╚██╗██║██║   ██║██║  ██║██╔══╝  ╚════██║
███████║███████╗███████╗██████╔╝██║ ╚████║╚██████╔╝██████╔╝███████╗███████║
╚══════╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝
```

[English version](README.en.md)

</div>

Somos un equipo de desarrolladores y operadores de infraestructura blockchain con un objetivo común: operar nodos y validadores con estándares institucionales. La infraestructura blockchain necesita ser más confiable, y estamos aquí para hacerla mejor.

Nuestra misión es desarrollar, implementar y mantener infraestructura de nodos blockchain con procesos automatizados, auditables y escalables. Nos comprometemos a operar con los más altos estándares de seguridad, transparencia y continuidad.

Operamos validadores en las redes más relevantes de web3, incluyendo Ethereum, Gnosis, Starknet, Aztec, y más.

---

<div align="center">

[![Twitter](https://img.shields.io/badge/Twitter-@SeedsPuntoEth-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/SeedsPuntoEth)
[![NodeOps](https://img.shields.io/badge/NodeOps-Institucionales-00ff88?style=for-the-badge&logo=server&logoColor=black)](https://github.com/NoaSEED/seedops-institutional)

</div>

## Estructura del Proyecto

```
seedops-institutional/
├── INOH/                          # Manual de Operaciones de Nodos
│   ├── institutional-handbook.md  # Manual maestro institucional
│   ├── security-compliance.md     # Estándares de seguridad
│   └── audit-procedures.md        # Procedimientos de auditoría
├── playbooks/                     # Playbooks técnicos por red
│   ├── ethereum.md               # Obol DVT, CSM
│   ├── gnosis.md                 # Validators
│   ├── starknet.md               # Delegación STRK
│   └── aztec.md                  # Sequencer node
├── scripts/                      # Scripts de automatización
│   ├── 00_bootstrap.sh           # Configuración inicial
│   ├── 10_hardening.sh           # Seguridad institucional
│   ├── 20_deploy.sh              # Despliegue automatizado
│   ├── 30_monitoring.sh          # Monitoreo predictivo
│   ├── 40_backup.sh              # Backups auditables
│   ├── 90_incident.sh            # Respuesta a incidentes
│   └── aztec_installer.sh        # Instalador automatizado Aztec
├── templates/                    # Templates de configuración
├── compose/                      # Docker Compose por red
├── env/                         # Variables de entorno
├── monitoring/                  # Dashboards y métricas
├── audit-logs/                 # Registros de auditoría
└── docs/                       # Documentación ejecutiva
```

## Fases de Implementación

### Fase 1: Research Inicial
- [x] Análisis de estándares institucionales
- [x] Identificación de métricas clave
- [x] Definición de diferenciadores SEEDNodes

### Fase 2: Marco Institucional (INOH)
- [ ] Manual de Operaciones de Nodos
- [ ] Estándares de seguridad y compliance
- [ ] Procedimientos de auditoría

### Fase 3: Playbooks por Red
- [x] Ethereum (Obol DVT, CSM)
- [x] Gnosis (validators)
- [x] Starknet (delegación STRK)
- [x] Aztec (sequencer node)

### Fase 4: Monitoreo & Reporting
- [ ] KPIs por red (uptime, APR, slashing, costos)
- [ ] Pipeline de reportes automáticos
- [ ] Dashboard institucional

### Fase 5: Mejora Continua
- [ ] Revisión trimestral
- [ ] Actualización de guías
- [ ] Lessons learned

## Automatización de NodeOps

### Implementación Actual
- Scripts automatizados para bootstrap, hardening, deploy, monitor, backup, incident
- Playbooks documentados y versionados para replicabilidad
- Procesos manuales controlados con `make deploy`, `make monitor`, etc.

### Automatización Avanzada
- **Seguridad**: Detección automática de vulnerabilidades y aplicación de hardening
- **Backups**: Procesos automatizados con encriptación y verificación diaria
- **Incidentes**: Respuesta automática, reinicio de servicios y notificaciones

### Orquestación Multired
- Gestión centralizada para Ethereum, Gnosis, Starknet, Aztec
- Pipeline CI/CD para despliegues institucionales
- Seguridad y monitoreo unificados

### Monitoreo Predictivo
- Análisis de tendencias de recursos (disco, CPU, memoria)
- Detección temprana de amenazas de seguridad
- Escalado automático preventivo

## Seguridad de Nivel Institucional

- **Zero trust**: VPN + MFA, sin claves hardcodeadas en procesos
- **Auditoría**: cada acción logueada en repositorio "audit-logs"
- **Testing de seguridad**: playbooks de simulación de ataques

## Auditorías Integradas

Cada proceso genera **registro verificable**:
- Infraestructura: fecha, usuario, servidor, hash de commit, resultado
- Seguridad: checklist automático post-hardening
- Backups: hash SHA256 + restore test
- Monitoreo: validación de métricas y SLA

## Estándares Operativos

Cada proceso operativo en SEEDNodes genera registros de auditoría completos. Los despliegues, actualizaciones y backups requieren evidencia verificable para ser considerados válidos. Esto garantiza transparencia, trazabilidad y confianza para delegadores, fundaciones y stakeholders.

---

**El INOH es el estándar maestro de SEEDNodes para operación de nodos. Cada despliegue sigue esta estructura, garantizando que nuestras prácticas cumplen con niveles institucionales de seguridad, transparencia y continuidad.**

