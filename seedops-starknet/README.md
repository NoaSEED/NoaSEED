# SEED Ops - Starknet

Repositorio institucional para la operación estandarizada de validadores Starknet, parte del **Institutional Node Operations Handbook (INOH)** de SEED Org.

## 🎯 Objetivo

Este repositorio proporciona:
- **Playbooks institucionales** para la operación de validadores Starknet
- **Scripts automatizados** para despliegue y mantenimiento
- **Infraestructura como código** versionada y replicable
- **Estándares de seguridad** y cumplimiento institucional

## 🏗️ Estructura

```
seedops-starknet/
├─ INOH/                    # Documentación institucional
├─ playbooks/              # Procedimientos operativos
├─ scripts/                # Scripts de automatización
├─ compose/                # Configuraciones Docker
├─ templates/              # Plantillas de configuración
├─ env/                    # Variables de entorno
└─ .github/workflows/      # CI/CD
```

## 🚀 Uso Rápido

### Prerrequisitos
- Ubuntu 22.04 LTS o superior
- Acceso root/sudo
- Conexión a internet estable

### Despliegue Completo
```bash
# Clonar repositorio
git clone https://github.com/seed-org/seedops-starknet.git
cd seedops-starknet

# Configurar variables de entorno
cp env/starknet.env.example env/starknet.env
# Editar env/starknet.env con tus valores

# Ejecutar despliegue completo
make all
```

### Objetivos del Makefile

| Objetivo | Descripción |
|----------|-------------|
| `make bootstrap` | Instalar dependencias y crear usuario |
| `make harden` | Configurar seguridad del sistema |
| `make deploy` | Desplegar validador Starknet |
| `make monitor` | Configurar monitoreo |
| `make backup` | Crear backup de configuraciones |
| `make incident` | Procedimientos de respuesta a incidentes |
| `make all` | Ejecutar todo el pipeline |

## 📚 Documentación

- **[INOH/starknet-infra.md](INOH/starknet-infra.md)** - Estándares institucionales
- **[playbooks/starknet.md](playbooks/starknet.md)** - Procedimientos operativos

## 🔒 Seguridad

- Todos los scripts incluyen validaciones de seguridad
- Configuraciones sensibles se manejan via variables de entorno
- Archivo `env/starknet.env` está en `.gitignore`

## 🤝 Contribución

Este repositorio sigue los estándares del INOH. Para contribuir:

1. Crear issue describiendo el cambio
2. Crear branch desde `main`
3. Implementar cambios siguiendo estándares de seguridad
4. Crear Pull Request con descripción detallada

## 📄 Licencia

Copyright © 2024 SEED Org. Todos los derechos reservados.

---

**Parte del Institutional Node Operations Handbook (INOH) - SEED Org**
