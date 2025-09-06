# OpenTelemetry Demo - Complete Setup

## What This Does
- **Infrastructure in Docker**: PostgreSQL, Kafka, Zookeeper, Jaeger, OpenTelemetry Collector, Prometheus, OpenSearch, Grafana, Flagd
- **Demo Services as Systemd**: All 16 services from the original OpenTelemetry demo

## Services Included
**Infrastructure (Docker):**
- PostgreSQL (5432), Kafka (9092), Zookeeper (2181)
- Jaeger (16686), OpenTelemetry Collector (4317/4318)
- Prometheus (9090), OpenSearch (9200), Grafana (3001)
- Flagd (8013), Flagd UI (8080)

**Demo Services (Systemd):**
- accounting (8080), ad (8081), cart (8082), checkout (8083)
- currency (8084), email (8085), fraud-detection (8086)
- frontend (3000), frontend-proxy (8087), image-provider (8088)
- load-generator (8089), payment (8090), product-catalog (8091)
- quote (8092), recommendation (8093), shipping (8094)

## Quick Start
```bash
# Copy to VM
scp -r . user@your-vm:/opt/otel-demo/

# SSH and install
ssh user@your-vm
cd /opt/otel-demo

# If you get package dependency errors, run this first:
sudo ./fix-dependencies.sh

# Then install
sudo ./install.sh
```

## Access
- **Frontend**: http://localhost:3000
- **Jaeger UI**: http://localhost:16686
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Flagd UI**: http://localhost:8080

## Management
```bash
# Infrastructure
docker compose up|down|ps

# Demo services
systemctl start|stop|status oteldemo-*

# Check all services
systemctl status oteldemo-*
```

## Files
- `docker-compose.yml` - Infrastructure services
- `otel-collector.yaml` - OpenTelemetry configuration
- `install.sh` - Main installation script
- `create-services.sh` - Creates demo service code
- `create-systemd.sh` - Creates systemd service files
- `init.sql` - Database initialization
- `prometheus-config.yaml` - Prometheus configuration
- `flagd/demo.flagd.json` - Feature flags
- `grafana/datasources.yaml` - Grafana data sources

Complete OpenTelemetry demo with all services running as systemd processes.
