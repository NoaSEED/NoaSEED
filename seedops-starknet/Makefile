# SEED Ops - Starknet Makefile
# Institutional Node Operations Handbook (INOH)
#
# Uso: make [target]
# Autor: SEED Ops Team
# Fecha: 2024
# Versión: 1.0

.PHONY: help bootstrap harden deploy monitor backup incident all clean status logs

# Variables de configuración
STARKNET_USER := starknet
STARKNET_HOME := /opt/starknet
SCRIPTS_DIR := scripts
COMPOSE_FILE := $(STARKNET_HOME)/starknet.docker-compose.yml

# Colores para output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Target por defecto
.DEFAULT_GOAL := help

# Ayuda
help: ## Mostrar esta ayuda
	@echo "$(GREEN)SEED Ops - Starknet Operations$(NC)"
	@echo "======================================"
	@echo ""
	@echo "Targets disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Ejemplos de uso:"
	@echo "  make bootstrap    # Instalar dependencias y crear usuario"
	@echo "  make harden       # Configurar seguridad del sistema"
	@echo "  make deploy       # Desplegar validador Starknet"
	@echo "  make all          # Ejecutar todo el pipeline"
	@echo ""

# Verificaciones de prerrequisitos
check-root: ## Verificar que se ejecute como root
	@if [ $$(id -u) -ne 0 ]; then \
		echo "$(RED)Error: Este comando debe ejecutarse como root (sudo)$(NC)"; \
		exit 1; \
	fi

check-user: ## Verificar que el usuario starknet existe
	@if ! id "$(STARKNET_USER)" &> /dev/null; then \
		echo "$(RED)Error: Usuario $(STARKNET_USER) no existe. Ejecutar 'make bootstrap' primero.$(NC)"; \
		exit 1; \
	fi

check-docker: ## Verificar que Docker esté funcionando
	@if ! systemctl is-active --quiet docker; then \
		echo "$(RED)Error: Docker no está ejecutándose$(NC)"; \
		exit 1; \
	fi

# Target principal de bootstrap
bootstrap: check-root ## Instalar dependencias y crear usuario
	@echo "$(GREEN)🚀 Iniciando bootstrap de Starknet...$(NC)"
	@$(SCRIPTS_DIR)/00_bootstrap.sh
	@echo "$(GREEN)✅ Bootstrap completado exitosamente$(NC)"

# Target de hardening
harden: check-root check-user ## Configurar seguridad del sistema
	@echo "$(GREEN)🔒 Iniciando hardening de seguridad...$(NC)"
	@$(SCRIPTS_DIR)/10_hardening.sh
	@echo "$(GREEN)✅ Hardening completado exitosamente$(NC)"

# Target de despliegue
deploy: check-root check-user check-docker ## Desplegar validador Starknet
	@echo "$(GREEN)🏗️  Iniciando despliegue de Starknet...$(NC)"
	@$(SCRIPTS_DIR)/20_deploy_starknet.sh
	@echo "$(GREEN)✅ Despliegue completado exitosamente$(NC)"

# Target de monitoreo
monitor: check-root check-user check-docker ## Configurar monitoreo avanzado
	@echo "$(GREEN)📊 Iniciando configuración de monitoreo...$(NC)"
	@$(SCRIPTS_DIR)/30_monitoring.sh
	@echo "$(GREEN)✅ Monitoreo configurado exitosamente$(NC)"

# Target de backup
backup: check-root check-user ## Crear backup de configuraciones
	@echo "$(GREEN)💾 Iniciando backup...$(NC)"
	@$(SCRIPTS_DIR)/40_backup.sh daily
	@echo "$(GREEN)✅ Backup completado exitosamente$(NC)"

backup-weekly: check-root check-user ## Crear backup semanal
	@echo "$(GREEN)💾 Iniciando backup semanal...$(NC)"
	@$(SCRIPTS_DIR)/40_backup.sh weekly
	@echo "$(GREEN)✅ Backup semanal completado exitosamente$(NC)"

backup-monthly: check-root check-user ## Crear backup mensual
	@echo "$(GREEN)💾 Iniciando backup mensual...$(NC)"
	@$(SCRIPTS_DIR)/40_backup.sh monthly
	@echo "$(GREEN)✅ Backup mensual completado exitosamente$(NC)"

# Target de incidentes
incident: check-root check-user ## Procedimientos de respuesta a incidentes
	@echo "$(YELLOW)🚨 Iniciando procedimiento de incidente...$(NC)"
	@$(SCRIPTS_DIR)/90_incident.sh medium
	@echo "$(GREEN)✅ Procedimiento de incidente completado$(NC)"

incident-critical: check-root check-user ## Procedimiento de incidente crítico
	@echo "$(RED)🚨 Iniciando procedimiento de incidente CRÍTICO...$(NC)"
	@$(SCRIPTS_DIR)/90_incident.sh critical
	@echo "$(GREEN)✅ Procedimiento de incidente crítico completado$(NC)"

incident-high: check-root check-user ## Procedimiento de incidente alto
	@echo "$(YELLOW)⚠️  Iniciando procedimiento de incidente ALTO...$(NC)"
	@$(SCRIPTS_DIR)/90_incident.sh high
	@echo "$(GREEN)✅ Procedimiento de incidente alto completado$(NC)"

# Target principal - ejecutar todo el pipeline
all: bootstrap harden deploy monitor ## Ejecutar todo el pipeline
	@echo "$(GREEN)🎉 Pipeline completo ejecutado exitosamente$(NC)"
	@echo "$(GREEN)📊 Validador Starknet listo para operación$(NC)"

# Target de verificación de estado
status: check-user ## Verificar estado del validador
	@echo "$(GREEN)📊 Verificando estado del validador Starknet...$(NC)"
	@if [ -f "$(COMPOSE_FILE)" ]; then \
		cd $(STARKNET_HOME) && docker-compose -f starknet.docker-compose.yml ps; \
	else \
		echo "$(YELLOW)⚠️  Validador no desplegado. Ejecutar 'make deploy' primero.$(NC)"; \
	fi

# Target de logs
logs: check-user ## Mostrar logs del validador
	@echo "$(GREEN)📋 Mostrando logs del validador...$(NC)"
	@if [ -f "$(COMPOSE_FILE)" ]; then \
		cd $(STARKNET_HOME) && docker-compose -f starknet.docker-compose.yml logs --tail=50; \
	else \
		echo "$(YELLOW)⚠️  Validador no desplegado. Ejecutar 'make deploy' primero.$(NC)"; \
	fi

# Target de logs de seguimiento
logs-follow: check-user ## Seguir logs del validador en tiempo real
	@echo "$(GREEN)📋 Siguiendo logs del validador...$(NC)"
	@if [ -f "$(COMPOSE_FILE)" ]; then \
		cd $(STARKNET_HOME) && docker-compose -f starknet.docker-compose.yml logs -f; \
	else \
		echo "$(YELLOW)⚠️  Validador no desplegado. Ejecutar 'make deploy' primero.$(NC)"; \
	fi

# Target de reinicio
restart: check-user check-docker ## Reiniciar validador
	@echo "$(GREEN)🔄 Reiniciando validador...$(NC)"
	@if [ -f "$(COMPOSE_FILE)" ]; then \
		cd $(STARKNET_HOME) && docker-compose -f starknet.docker-compose.yml restart; \
		echo "$(GREEN)✅ Validador reiniciado exitosamente$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Validador no desplegado. Ejecutar 'make deploy' primero.$(NC)"; \
	fi

# Target de parada
stop: check-user check-docker ## Parar validador
	@echo "$(YELLOW)⏹️  Parando validador...$(NC)"
	@if [ -f "$(COMPOSE_FILE)" ]; then \
		cd $(STARKNET_HOME) && docker-compose -f starknet.docker-compose.yml stop; \
		echo "$(GREEN)✅ Validador parado exitosamente$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Validador no desplegado.$(NC)"; \
	fi

# Target de inicio
start: check-user check-docker ## Iniciar validador
	@echo "$(GREEN)▶️  Iniciando validador...$(NC)"
	@if [ -f "$(COMPOSE_FILE)" ]; then \
		cd $(STARKNET_HOME) && docker-compose -f starknet.docker-compose.yml start; \
		echo "$(GREEN)✅ Validador iniciado exitosamente$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Validador no desplegado. Ejecutar 'make deploy' primero.$(NC)"; \
	fi

# Target de limpieza
clean: check-root ## Limpiar instalación (CUIDADO: elimina datos)
	@echo "$(RED)⚠️  ADVERTENCIA: Esto eliminará todos los datos del validador$(NC)"
	@echo "$(RED)¿Estás seguro? [y/N]$(NC)"
	@read -p " " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(YELLOW)🧹 Limpiando instalación...$(NC)"; \
		if [ -f "$(COMPOSE_FILE)" ]; then \
			cd $(STARKNET_HOME) && docker-compose -f starknet.docker-compose.yml down -v; \
		fi; \
		rm -rf $(STARKNET_HOME)/{data,keys,logs,config,backups,monitoring}; \
		userdel -r $(STARKNET_USER) 2>/dev/null || true; \
		groupdel $(STARKNET_USER) 2>/dev/null || true; \
		echo "$(GREEN)✅ Instalación limpiada exitosamente$(NC)"; \
	else \
		echo "$(YELLOW)Operación cancelada$(NC)"; \
	fi

# Target de verificación del sistema
check-system: ## Verificar especificaciones del sistema
	@echo "$(GREEN)🔍 Verificando especificaciones del sistema...$(NC)"
	@echo "OS: $$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
	@echo "Kernel: $$(uname -r)"
	@echo "CPU: $$(nproc) cores"
	@echo "RAM: $$(free -h | grep Mem | awk '{print $$2}')"
	@echo "Disk: $$(df -h / | awk 'NR==2 {print $$4}') disponible"
	@echo "Docker: $$(docker --version 2>/dev/null || echo 'No instalado')"

# Target de verificación de red
check-network: ## Verificar conectividad de red
	@echo "$(GREEN)🌐 Verificando conectividad de red...$(NC)"
	@if ping -c 1 8.8.8.8 &> /dev/null; then \
		echo "✅ Conectividad a internet: OK"; \
	else \
		echo "$(RED)❌ Conectividad a internet: FALLO$(NC)"; \
	fi
	@if ping -c 1 alpha-mainnet.starknet.io &> /dev/null; then \
		echo "✅ Conectividad a Starknet: OK"; \
	else \
		echo "$(YELLOW)⚠️  Conectividad a Starknet: FALLO$(NC)"; \
	fi

# Target de verificación de repositorios
check-repos: ## Verificar acceso a repositorios
	@echo "$(GREEN)📦 Verificando acceso a repositorios...$(NC)"
	@if curl -s https://download.docker.com/linux/ubuntu/gpg > /dev/null; then \
		echo "✅ Docker repository: OK"; \
	else \
		echo "$(RED)❌ Docker repository: FALLO$(NC)"; \
	fi

# Target de verificación de bootstrap
verify-bootstrap: check-user ## Verificar instalación de bootstrap
	@echo "$(GREEN)✅ Verificando bootstrap...$(NC)"
	@if id "$(STARKNET_USER)" &> /dev/null; then \
		echo "✅ Usuario $(STARKNET_USER): OK"; \
	else \
		echo "$(RED)❌ Usuario $(STARKNET_USER): FALLO$(NC)"; \
	fi
	@if command -v docker &> /dev/null; then \
		echo "✅ Docker: OK"; \
	else \
		echo "$(RED)❌ Docker: FALLO$(NC)"; \
	fi
	@if [ -d "$(STARKNET_HOME)" ]; then \
		echo "✅ Directorio $(STARKNET_HOME): OK"; \
	else \
		echo "$(RED)❌ Directorio $(STARKNET_HOME): FALLO$(NC)"; \
	fi

# Target de verificación de seguridad
verify-security: check-user ## Verificar configuraciones de seguridad
	@echo "$(GREEN)🔒 Verificando configuraciones de seguridad...$(NC)"
	@if ufw status | grep -q "Status: active"; then \
		echo "✅ Firewall UFW: OK"; \
	else \
		echo "$(RED)❌ Firewall UFW: FALLO$(NC)"; \
	fi
	@if systemctl is-active --quiet fail2ban; then \
		echo "✅ Fail2ban: OK"; \
	else \
		echo "$(RED)❌ Fail2ban: FALLO$(NC)"; \
	fi
	@if systemctl is-active --quiet auditd; then \
		echo "✅ Auditoría: OK"; \
	else \
		echo "$(RED)❌ Auditoría: FALLO$(NC)"; \
	fi

# Target de verificación de configuración
verify-config: check-user ## Verificar configuración del validador
	@echo "$(GREEN)⚙️  Verificando configuración...$(NC)"
	@if [ -f "$(STARKNET_HOME)/config/config.yaml" ]; then \
		echo "✅ Archivo de configuración: OK"; \
	else \
		echo "$(RED)❌ Archivo de configuración: FALLO$(NC)"; \
	fi
	@if [ -f "$(COMPOSE_FILE)" ]; then \
		echo "✅ Docker Compose: OK"; \
	else \
		echo "$(RED)❌ Docker Compose: FALLO$(NC)"; \
	fi

# Target de verificación de monitoreo
verify-monitoring: check-user ## Verificar configuración de monitoreo
	@echo "$(GREEN)📊 Verificando monitoreo...$(NC)"
	@if [ -d "$(STARKNET_HOME)/monitoring" ]; then \
		echo "✅ Directorio de monitoreo: OK"; \
	else \
		echo "$(RED)❌ Directorio de monitoreo: FALLO$(NC)"; \
	fi
	@if netstat -tlnp | grep -q ":9090.*LISTEN"; then \
		echo "✅ Prometheus: OK"; \
	else \
		echo "$(YELLOW)⚠️  Prometheus: NO ACTIVO$(NC)"; \
	fi
	@if netstat -tlnp | grep -q ":3000.*LISTEN"; then \
		echo "✅ Grafana: OK"; \
	else \
		echo "$(YELLOW)⚠️  Grafana: NO ACTIVO$(NC)"; \
	fi

# Target de verificación de backups
verify-backups: check-user ## Verificar configuración de backups
	@echo "$(GREEN)💾 Verificando backups...$(NC)"
	@if [ -d "$(STARKNET_HOME)/backups" ]; then \
		echo "✅ Directorio de backups: OK"; \
		@if ls "$(STARKNET_HOME)/backups"/*.gpg 2>/dev/null | head -1 > /dev/null; then \
			echo "✅ Archivos de backup: OK"; \
		else \
			echo "$(YELLOW)⚠️  No hay archivos de backup$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ Directorio de backups: FALLO$(NC)"; \
	fi

# Target de información del sistema
info: ## Mostrar información completa del sistema
	@echo "$(GREEN)📋 Información del sistema SEED Ops Starknet$(NC)"
	@echo "=================================================="
	@echo ""
	@make check-system
	@echo ""
	@make check-network
	@echo ""
	@make verify-bootstrap
	@echo ""
	@make verify-security
	@echo ""
	@make verify-config
	@echo ""
	@make verify-monitoring
	@echo ""
	@make verify-backups
	@echo ""
	@echo "$(GREEN)📊 Estado del validador:$(NC)"
	@make status

# Target de mantenimiento diario
daily-check: check-user ## Verificación diaria del sistema
	@echo "$(GREEN)📅 Ejecutando verificación diaria...$(NC)"
	@make status
	@make check-system
	@echo "$(GREEN)✅ Verificación diaria completada$(NC)"

# Target de mantenimiento semanal
weekly-maintenance: check-user ## Mantenimiento semanal
	@echo "$(GREEN)📅 Ejecutando mantenimiento semanal...$(NC)"
	@make backup-weekly
	@echo "$(GREEN)✅ Mantenimiento semanal completado$(NC)"

# Target de mantenimiento mensual
monthly-maintenance: check-user ## Mantenimiento mensual
	@echo "$(GREEN)📅 Ejecutando mantenimiento mensual...$(NC)"
	@make backup-monthly
	@echo "$(GREEN)✅ Mantenimiento mensual completado$(NC)"

# Target de actualización del sistema
system-update: check-root ## Actualizar sistema operativo
	@echo "$(GREEN)🔄 Actualizando sistema operativo...$(NC)"
	@apt-get update && apt-get upgrade -y
	@echo "$(GREEN)✅ Sistema actualizado exitosamente$(NC)"

# Target de rotación de logs
rotate-logs: check-user ## Rotar logs del sistema
	@echo "$(GREEN)📋 Rotando logs...$(NC)"
	@logrotate -f /etc/logrotate.d/starknet
	@echo "$(GREEN)✅ Logs rotados exitosamente$(NC)"

# Target de verificación de espacio en disco
check-disk: check-user ## Verificar espacio en disco
	@echo "$(GREEN)💾 Verificando espacio en disco...$(NC)"
	@df -h
	@echo ""
	@echo "Uso de directorios principales:"
	@du -sh $(STARKNET_HOME)/* 2>/dev/null || echo "Directorio no encontrado"

# Target de análisis de performance
performance-review: check-user ## Análisis de performance del sistema
	@echo "$(GREEN)📈 Análisis de performance...$(NC)"
	@echo "CPU: $$(top -bn1 | grep "Cpu(s)" | awk '{print $$2}' | cut -d'%' -f1)%"
	@echo "RAM: $$(free | grep Mem | awk '{printf("%.1f", $$3/$$2 * 100.0)}')%"
	@echo "Disco: $$(df / | awk 'NR==2 {print $$5}')"
	@echo "Procesos: $$(ps aux | wc -l)"
	@echo "Docker: $$(docker ps | wc -l) contenedores activos"

# Target de limpieza de logs
cleanup-logs: check-user ## Limpiar logs antiguos
	@echo "$(GREEN)🧹 Limpiando logs antiguos...$(NC)"
	@find /var/log/starknet -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
	@find $(STARKNET_HOME)/logs -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
	@echo "$(GREEN)✅ Logs antiguos limpiados$(NC)"

# Target de test de restauración
test-restore: check-user ## Test de restauración de backup
	@echo "$(GREEN)🧪 Probando restauración de backup...$(NC)"
	@if [ -f "$(STARKNET_HOME)/scripts/40_backup.sh" ]; then \
		$(STARKNET_HOME)/scripts/40_backup.sh test; \
	else \
		echo "$(YELLOW)⚠️  Script de backup no encontrado$(NC)"; \
	fi

# Target de verificación de integridad
verify-integrity: check-user ## Verificar integridad de archivos críticos
	@echo "$(GREEN)🔍 Verificando integridad...$(NC)"
	@if [ -f "$(STARKNET_HOME)/keys/backup.key" ]; then \
		echo "✅ Clave de backup: OK"; \
	else \
		echo "$(YELLOW)⚠️  Clave de backup: NO ENCONTRADA$(NC)"; \
	fi
	@if [ -f "$(STARKNET_HOME)/config/config.yaml" ]; then \
		echo "✅ Configuración: OK"; \
	else \
		echo "$(RED)❌ Configuración: FALLO$(NC)"; \
	fi

# Target de reporte de estado
status-report: check-user ## Generar reporte de estado completo
	@echo "$(GREEN)📊 Generando reporte de estado...$(NC)"
	@echo "Reporte generado: $(STARKNET_HOME)/logs/status-report-$$(date +%Y%m%d_%H%M%S).txt"
	@make info > "$(STARKNET_HOME)/logs/status-report-$$(date +%Y%m%d_%H%M%S).txt" 2>&1

# Target de ayuda rápida
quick-help: ## Ayuda rápida para operaciones comunes
	@echo "$(GREEN)🚀 Operaciones rápidas para SEED Ops Starknet$(NC)"
	@echo "=================================================="
	@echo ""
	@echo "$(GREEN)Despliegue inicial:$(NC)"
	@echo "  make all                    # Pipeline completo"
	@echo ""
	@echo "$(GREEN)Operaciones diarias:$(NC)"
	@echo "  make status                 # Verificar estado"
	@echo "  make logs                   # Ver logs"
	@echo "  make daily-check            # Verificación diaria"
	@echo ""
	@echo "$(GREEN)Mantenimiento:$(NC)"
	@echo "  make backup                 # Backup diario"
	@echo "  make restart                # Reiniciar validador"
	@echo "  make weekly-maintenance     # Mantenimiento semanal"
	@echo ""
	@echo "$(GREEN)Emergencias:$(NC)"
	@echo "  make incident               # Incidente medio"
	@echo "  make incident-high          # Incidente alto"
	@echo "  make incident-critical      # Incidente crítico"
	@echo ""
	@echo "$(GREEN)Información:$(NC)"
	@echo "  make info                   # Información completa"
	@echo "  make help                   # Ayuda detallada"
