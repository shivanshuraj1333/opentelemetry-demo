#!/bin/bash

# OpenTelemetry Demo Host Setup Script
# This script sets up the OpenTelemetry demo services to run directly on the host

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_USER="oteldemo"
DEMO_HOME="/opt/oteldemo"
SERVICES_DIR="$DEMO_HOME/services"
CONFIG_DIR="$DEMO_HOME/config"
LOG_DIR="/var/log/oteldemo"
OTEL_COLLECTOR_HOST="localhost"
OTEL_COLLECTOR_PORT_GRPC="4317"
OTEL_COLLECTOR_PORT_HTTP="4318"

# Service configurations
declare -A SERVICES=(
    ["frontend"]="3000"
    ["cart"]="8080"
    ["checkout"]="8080"
    ["currency"]="8080"
    ["email"]="8080"
    ["payment"]="8080"
    ["product-catalog"]="8080"
    ["quote"]="8080"
    ["recommendation"]="8080"
    ["shipping"]="8080"
    ["ad"]="8080"
    ["fraud-detection"]="8080"
    ["accounting"]="8080"
    ["load-generator"]="8089"
)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    # Detect OS and install dependencies
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y nodejs npm python3 python3-pip openjdk-11-jdk golang-go rustc cargo php php-cli postgresql redis-server
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y nodejs npm python3 python3-pip java-11-openjdk-devel golang rust cargo php php-cli postgresql-server redis
    else
        log_warning "Package manager not detected. Please install dependencies manually."
    fi
}

create_demo_user() {
    log_info "Creating demo user..."
    
    if ! id "$DEMO_USER" &>/dev/null; then
        useradd --system --create-home --shell /bin/bash "$DEMO_USER"
        usermod -aG docker "$DEMO_USER" 2>/dev/null || true
        log_success "Created user: $DEMO_USER"
    else
        log_info "User $DEMO_USER already exists"
    fi
}

create_directories() {
    log_info "Creating directories..."
    
    mkdir -p "$SERVICES_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    chown -R "$DEMO_USER:$DEMO_USER" "$DEMO_HOME"
    chown -R "$DEMO_USER:$DEMO_USER" "$LOG_DIR"
    
    log_success "Created directories"
}

create_service_scripts() {
    log_info "Creating service scripts..."
    
    # Create a generic service runner script
    cat > "$SERVICES_DIR/run-service.sh" << 'EOF'
#!/bin/bash

SERVICE_NAME=$1
SERVICE_PORT=$2
SERVICE_DIR=$3
SERVICE_CMD=$4

export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
export OTEL_SERVICE_NAME="$SERVICE_NAME"
export OTEL_RESOURCE_ATTRIBUTES="service.name=$SERVICE_NAME,service.version=1.0.0,deployment.environment=host"

cd "$SERVICE_DIR"

# Start the service
exec $SERVICE_CMD
EOF

    chmod +x "$SERVICES_DIR/run-service.sh"
    
    # Create individual service scripts
    for service in "${!SERVICES[@]}"; do
        port=${SERVICES[$service]}
        
        cat > "$SERVICES_DIR/start-$service.sh" << EOF
#!/bin/bash
# Start $service on port $port

SERVICE_DIR="$SERVICES_DIR/$service"
LOG_FILE="$LOG_DIR/$service.log"

# Create service directory if it doesn't exist
mkdir -p "\$SERVICE_DIR"

# Service-specific startup commands
case "$service" in
    "frontend")
        cd "\$SERVICE_DIR"
        npm start > "\$LOG_FILE" 2>&1 &
        ;;
    "cart"|"checkout"|"currency"|"email"|"payment"|"product-catalog"|"quote"|"recommendation"|"shipping"|"ad"|"fraud-detection"|"accounting")
        cd "\$SERVICE_DIR"
        # These would be language-specific startup commands
        # For now, we'll create placeholder scripts
        echo "Starting $service on port $port" > "\$LOG_FILE"
        ;;
    "load-generator")
        cd "\$SERVICE_DIR"
        locust --host=http://localhost:3000 --web-host=0.0.0.0 --web-port=$port > "\$LOG_FILE" 2>&1 &
        ;;
esac

echo "Started $service on port $port"
EOF

        chmod +x "$SERVICES_DIR/start-$service.sh"
    done
    
    log_success "Service scripts created"
}

create_systemd_services() {
    log_info "Creating systemd services for demo applications..."
    
    for service in "${!SERVICES[@]}"; do
        port=${SERVICES[$service]}
        
        cat > "/etc/systemd/system/oteldemo-$service.service" << EOF
[Unit]
Description=OpenTelemetry Demo - $service
After=network.target coralogix-collector.service
Wants=network.target

[Service]
Type=simple
User=$DEMO_USER
Group=$DEMO_USER
WorkingDirectory=$SERVICES_DIR
ExecStart=$SERVICES_DIR/start-$service.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=oteldemo-$service

# Environment
Environment=OTEL_EXPORTER_OTLP_ENDPOINT=http://$OTEL_COLLECTOR_HOST:$OTEL_COLLECTOR_PORT_HTTP
Environment=OTEL_SERVICE_NAME=$service
Environment=OTEL_RESOURCE_ATTRIBUTES=service.name=$service,service.version=1.0.0,deployment.environment=host

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable "oteldemo-$service"
    done
    
    log_success "Systemd services created"
}

create_docker_compose_alternative() {
    log_info "Creating Docker Compose alternative for infrastructure services..."
    
    cat > "$CONFIG_DIR/docker-compose-infra.yml" << EOF
version: '3.8'

services:
  postgresql:
    image: postgres:15
    container_name: oteldemo-postgresql
    environment:
      POSTGRES_USER: root
      POSTGRES_PASSWORD: otel
      POSTGRES_DB: otel
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: oteldemo-redis
    ports:
      - "6379:6379"
    restart: unless-stopped

  kafka:
    image: confluentinc/cp-kafka:latest
    container_name: oteldemo-kafka
    environment:
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    ports:
      - "9092:9092"
    depends_on:
      - zookeeper
    restart: unless-stopped

  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    container_name: oteldemo-zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"
    restart: unless-stopped

volumes:
  postgres_data:
EOF

    chown -R "$DEMO_USER:$DEMO_USER" "$CONFIG_DIR"
    
    log_success "Docker Compose alternative created"
}

create_monitoring_setup() {
    log_info "Creating monitoring setup..."
    
    # Create a simple monitoring script
    cat > "$SERVICES_DIR/monitor.sh" << 'EOF'
#!/bin/bash

# Simple monitoring script for OpenTelemetry demo services

echo "OpenTelemetry Demo Services Status"
echo "=================================="

# Check Coralogix services
echo "Coralogix Services:"
systemctl is-active coralogix-agent --quiet && echo "  ✓ Coralogix Agent: Running" || echo "  ✗ Coralogix Agent: Stopped"
systemctl is-active coralogix-collector --quiet && echo "  ✓ Coralogix Collector: Running" || echo "  ✗ Coralogix Collector: Stopped"

echo
echo "Demo Services:"
for service in frontend cart checkout currency email payment product-catalog quote recommendation shipping ad fraud-detection accounting load-generator; do
    if systemctl is-active "oteldemo-$service" --quiet; then
        echo "  ✓ $service: Running"
    else
        echo "  ✗ $service: Stopped"
    fi
done

echo
echo "Infrastructure Services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep oteldemo || echo "  No infrastructure services running"

echo
echo "Port Status:"
netstat -tlnp | grep -E ":(3000|8080|8089|4317|4318|5432|6379|9092)" | awk '{print "  " $1 " - " $4}'
EOF

    chmod +x "$SERVICES_DIR/monitor.sh"
    
    # Create a log viewer script
    cat > "$SERVICES_DIR/logs.sh" << 'EOF'
#!/bin/bash

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name>"
    echo "Available services:"
    echo "  coralogix-agent, coralogix-collector"
    echo "  frontend, cart, checkout, currency, email, payment, product-catalog"
    echo "  quote, recommendation, shipping, ad, fraud-detection, accounting, load-generator"
    exit 1
fi

if [[ "$SERVICE" == "coralogix-"* ]]; then
    journalctl -u "$SERVICE" -f
else
    journalctl -u "oteldemo-$SERVICE" -f
fi
EOF

    chmod +x "$SERVICES_DIR/logs.sh"
    
    log_success "Monitoring setup created"
}

show_next_steps() {
    log_success "OpenTelemetry Demo setup completed!"
    echo
    echo "Next steps:"
    echo "1. Start infrastructure services:"
    echo "   cd $CONFIG_DIR && docker-compose -f docker-compose-infra.yml up -d"
    echo
    echo "2. Start demo services:"
    echo "   sudo systemctl start oteldemo-frontend"
    echo "   sudo systemctl start oteldemo-cart"
    echo "   # ... start other services as needed"
    echo
    echo "3. Monitor services:"
    echo "   $SERVICES_DIR/monitor.sh"
    echo "   $SERVICES_DIR/logs.sh <service-name>"
    echo
    echo "4. Access the demo:"
    echo "   Frontend: http://localhost:3000"
    echo "   Load Generator: http://localhost:8089"
    echo
    echo "Configuration files:"
    echo "  Services: $SERVICES_DIR/"
    echo "  Config: $CONFIG_DIR/"
    echo "  Logs: $LOG_DIR/"
}

main() {
    log_info "Starting OpenTelemetry Demo Host Setup"
    
    check_root
    install_dependencies
    create_demo_user
    create_directories
    create_service_scripts
    create_systemd_services
    create_docker_compose_alternative
    create_monitoring_setup
    show_next_steps
}

# Run main function
main "$@"
