#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Service definitions with ports and languages
declare -A SERVICES=(
    ["accounting"]="8080 .NET"
    ["ad"]="8081 Java"
    ["cart"]="8082 .NET"
    ["checkout"]="8083 Go"
    ["currency"]="8084 C++"
    ["email"]="8085 Ruby"
    ["fraud-detection"]="8086 Kotlin"
    ["frontend"]="3000 Node.js"
    ["frontend-proxy"]="8087 Envoy"
    ["image-provider"]="8088 Nginx"
    ["load-generator"]="8089 Python"
    ["payment"]="8090 Node.js"
    ["product-catalog"]="8091 Go"
    ["quote"]="8092 PHP"
    ["recommendation"]="8093 Python"
    ["shipping"]="8094 Rust"
)

# Create systemd services
log_info "Creating systemd services..."

for service in "${!SERVICES[@]}"; do
    IFS=' ' read -r port language <<< "${SERVICES[$service]}"
    
    case $language in
        "Node.js")
            exec_start="/usr/bin/node server.js"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Python")
            exec_start="/usr/bin/python3 server.py"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Go")
            exec_start="/opt/oteldemo/$service/server"
            working_dir="/opt/oteldemo/$service"
            ;;
        "C++")
            exec_start="/opt/oteldemo/$service/server"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Ruby")
            exec_start="/usr/bin/ruby server.rb"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Rust")
            exec_start="/opt/oteldemo/$service/target/release/$service"
            working_dir="/opt/oteldemo/$service"
            ;;
        "PHP")
            exec_start="/usr/bin/php server.php"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Envoy")
            exec_start="/usr/bin/envoy -c envoy.yaml"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Nginx")
            exec_start="/usr/sbin/nginx -c nginx.conf -p /opt/oteldemo/$service"
            working_dir="/opt/oteldemo/$service"
            ;;
        ".NET")
            exec_start="/opt/oteldemo/$service/bin/Release/net8.0/$service"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Java")
            exec_start="/usr/bin/java -cp /opt/oteldemo/$service:/opt/oteldemo/$service/gson-2.10.1.jar Main"
            working_dir="/opt/oteldemo/$service"
            ;;
        "Kotlin")
            exec_start="/usr/bin/kotlin -cp /opt/oteldemo/$service:/opt/oteldemo/$service/gson-2.10.1.jar MainKt"
            working_dir="/opt/oteldemo/$service"
            ;;
    esac
    
    cat > /etc/systemd/system/oteldemo-$service.service << EOF
[Unit]
Description=OpenTelemetry Demo - $service
After=network.target

[Service]
Type=simple
User=oteldemo
Group=oteldemo
WorkingDirectory=$working_dir
ExecStart=$exec_start
Restart=on-failure
RestartSec=5
Environment=OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
Environment=OTEL_SERVICE_NAME=$service
Environment=OTEL_RESOURCE_ATTRIBUTES=service.name=$service,service.version=1.0.0

[Install]
WantedBy=multi-user.target
EOF
done

# Download Gson for Java/Kotlin services
wget -O /opt/oteldemo/ad/gson-2.10.1.jar https://repo1.maven.org/maven2/com/google/code/gson/gson/2.10.1/gson-2.10.1.jar
wget -O /opt/oteldemo/fraud-detection/gson-2.10.1.jar https://repo1.maven.org/maven2/com/google/code/gson/gson/2.10.1/gson-2.10.1.jar

# Enable and start services
systemctl daemon-reload
for service in "${!SERVICES[@]}"; do
    systemctl enable oteldemo-$service
    systemctl start oteldemo-$service
done

log_success "All systemd services created and started!"
