# OpenTelemetry Demo - Vanilla Host Makefile
# This Makefile provides convenient commands for managing the demo

.PHONY: help install build start stop restart status logs clean

# Default target
help:
	@echo "OpenTelemetry Demo - Vanilla Host Management"
	@echo ""
	@echo "Available commands:"
	@echo "  install     - Install dependencies and services"
	@echo "  build       - Build all demo services"
	@echo "  start       - Start all services"
	@echo "  stop        - Stop all services"
	@echo "  restart     - Restart all services"
	@echo "  status      - Show service status"
	@echo "  logs        - Show logs for all services"
	@echo "  clean       - Clean up and remove services"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Infrastructure commands:"
	@echo "  start-infra - Start infrastructure services only"
	@echo "  stop-infra  - Stop infrastructure services only"
	@echo "  start-demo  - Start demo services only"
	@echo "  stop-demo   - Stop demo services only"
	@echo ""
	@echo "Individual service commands:"
	@echo "  start-frontend    - Start frontend service"
	@echo "  start-cart        - Start cart service"
	@echo "  start-checkout    - Start checkout service"
	@echo "  start-currency    - Start currency service"
	@echo "  start-payment     - Start payment service"
	@echo "  start-product     - Start product catalog service"
	@echo "  start-loadgen     - Start load generator"
	@echo ""

# Installation
install:
	@echo "Installing OpenTelemetry Demo..."
	sudo ./install.sh

# Building
build:
	@echo "Building demo services..."
	sudo ./build-services.sh

# Service management
start:
	@echo "Starting all services..."
	sudo ./quick-start.sh start

stop:
	@echo "Stopping all services..."
	sudo ./quick-start.sh stop

restart:
	@echo "Restarting all services..."
	sudo ./quick-start.sh restart

status:
	@echo "Checking service status..."
	sudo ./quick-start.sh status

logs:
	@echo "Showing logs for all services..."
	sudo ./quick-start.sh logs

# Infrastructure services
start-infra:
	@echo "Starting infrastructure services..."
	sudo systemctl start postgresql redis-server kafka zookeeper otel-collector jaeger

stop-infra:
	@echo "Stopping infrastructure services..."
	sudo systemctl stop otel-collector jaeger kafka zookeeper redis-server postgresql

# Demo services
start-demo:
	@echo "Starting demo services..."
	sudo systemctl start oteldemo-frontend oteldemo-cart oteldemo-checkout \
		oteldemo-currency oteldemo-payment oteldemo-product-catalog \
		oteldemo-load-generator

stop-demo:
	@echo "Stopping demo services..."
	sudo systemctl stop oteldemo-*

# Individual services
start-frontend:
	@echo "Starting frontend service..."
	sudo systemctl start oteldemo-frontend

start-cart:
	@echo "Starting cart service..."
	sudo systemctl start oteldemo-cart

start-checkout:
	@echo "Starting checkout service..."
	sudo systemctl start oteldemo-checkout

start-currency:
	@echo "Starting currency service..."
	sudo systemctl start oteldemo-currency

start-payment:
	@echo "Starting payment service..."
	sudo systemctl start oteldemo-payment

start-product:
	@echo "Starting product catalog service..."
	sudo systemctl start oteldemo-product-catalog

start-loadgen:
	@echo "Starting load generator..."
	sudo systemctl start oteldemo-load-generator

# Docker infrastructure (alternative)
start-docker-infra:
	@echo "Starting infrastructure services with Docker..."
	docker-compose -f docker-compose-infrastructure.yml up -d

stop-docker-infra:
	@echo "Stopping Docker infrastructure services..."
	docker-compose -f docker-compose-infrastructure.yml down

# Cleanup
clean:
	@echo "Cleaning up services..."
	sudo systemctl stop oteldemo-* otel-collector jaeger kafka zookeeper redis-server postgresql || true
	sudo systemctl disable oteldemo-* otel-collector jaeger || true
	sudo rm -f /etc/systemd/system/oteldemo-*.service /etc/systemd/system/otel-collector.service /etc/systemd/system/jaeger.service
	sudo systemctl daemon-reload
	sudo rm -rf /opt/oteldemo
	sudo rm -rf /var/lib/otelcol
	sudo rm -rf /etc/otelcol
	@echo "Cleanup completed"

# Development helpers
dev-setup: install build
	@echo "Development setup completed"

dev-start: start-infra start-demo
	@echo "Development environment started"

dev-stop: stop-demo stop-infra
	@echo "Development environment stopped"

# Testing commands
test-scripts:
	@echo "Testing script syntax..."
	@for script in *.sh; do echo -n "  $$script: "; bash -n "$$script" && echo "OK" || echo "FAILED"; done

test-configs:
	@echo "Testing configuration files..."
	@echo -n "  otel-collector.yaml: "; grep -q "receivers:" otel-collector.yaml && grep -q "exporters:" otel-collector.yaml && echo "OK" || echo "ISSUES"
	@echo -n "  env.vanilla: "; grep -q "OTEL_COLLECTOR_HOST" env.vanilla && grep -q "FRONTEND_PORT" env.vanilla && echo "OK" || echo "ISSUES"
	@echo -n "  init.sql: "; grep -q "CREATE TABLE" init.sql && grep -q "INSERT INTO" init.sql && echo "OK" || echo "ISSUES"

test-services:
	@echo "Testing systemd service files..."
	@for service in services/*.service; do echo -n "  $$(basename $$service): "; grep -q "\[Unit\]" "$$service" && grep -q "\[Service\]" "$$service" && echo "OK" || echo "ISSUES"; done

test-all: test-scripts test-configs test-services
	@echo "All tests completed"

test-vm:
	@echo "Running comprehensive VM test..."
	@echo "Note: This should be run on the actual Ubuntu VM"
	@echo "Usage: sudo ./test-vm.sh"

# Health checks
health:
	@echo "Checking service health..."
	@echo "Collector Health:"
	@curl -s http://localhost:13133 || echo "Collector not responding"
	@echo ""
	@echo "Jaeger Health:"
	@curl -s http://localhost:16686 || echo "Jaeger not responding"
	@echo ""
	@echo "Frontend Health:"
	@curl -s http://localhost:3000 || echo "Frontend not responding"
	@echo ""

# Service logs
logs-frontend:
	@echo "Showing frontend logs..."
	sudo journalctl -u oteldemo-frontend -f

logs-cart:
	@echo "Showing cart logs..."
	sudo journalctl -u oteldemo-cart -f

logs-checkout:
	@echo "Showing checkout logs..."
	sudo journalctl -u oteldemo-checkout -f

logs-collector:
	@echo "Showing collector logs..."
	sudo journalctl -u otel-collector -f

logs-all:
	@echo "Showing all service logs..."
	sudo journalctl -u "oteldemo-*" -u "otel-collector" -u "jaeger" -f
