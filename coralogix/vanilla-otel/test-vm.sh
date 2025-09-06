#!/bin/bash

# OpenTelemetry Demo - VM Test Script
# This script tests the complete setup on an actual Ubuntu VM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_TIMEOUT=300  # 5 minutes timeout for each test phase
LOG_FILE="/tmp/otel-demo-test.log"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Test functions
test_prerequisites() {
    log_info "Testing prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS version"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "This script is designed for Ubuntu. Detected: $ID"
    fi
    
    # Check available memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $MEMORY_GB -lt 4 ]]; then
        log_warning "Low memory detected: ${MEMORY_GB}GB. Recommended: 4GB+"
    fi
    
    # Check disk space
    DISK_GB=$(df / | awk 'NR==2{print int($4/1024/1024)}')
    if [[ $DISK_GB -lt 10 ]]; then
        log_warning "Low disk space: ${DISK_GB}GB. Recommended: 10GB+"
    fi
    
    log_success "Prerequisites check completed"
}

test_installation() {
    log_info "Testing installation process..."
    
    # Run installation script
    if [[ -f "./install.sh" ]]; then
        timeout $TEST_TIMEOUT ./install.sh
        if [[ $? -eq 0 ]]; then
            log_success "Installation script completed successfully"
        else
            log_error "Installation script failed"
            return 1
        fi
    else
        log_error "Installation script not found"
        return 1
    fi
}

test_service_building() {
    log_info "Testing service building..."
    
    # Run build script
    if [[ -f "./build-services.sh" ]]; then
        timeout $TEST_TIMEOUT ./build-services.sh
        if [[ $? -eq 0 ]]; then
            log_success "Service building completed successfully"
        else
            log_error "Service building failed"
            return 1
        fi
    else
        log_error "Build script not found"
        return 1
    fi
}

test_infrastructure_services() {
    log_info "Testing infrastructure services..."
    
    # Start infrastructure services
    systemctl start postgresql redis-server kafka zookeeper otel-collector jaeger
    
    # Wait for services to start
    sleep 10
    
    # Check service status
    local services=("postgresql" "redis-server" "kafka" "zookeeper" "otel-collector" "jaeger")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_error "Failed services: ${failed_services[*]}"
        return 1
    fi
    
    log_success "All infrastructure services are running"
}

test_demo_services() {
    log_info "Testing demo services..."
    
    # Start demo services
    systemctl start oteldemo-frontend oteldemo-cart oteldemo-checkout \
        oteldemo-currency oteldemo-payment oteldemo-product-catalog \
        oteldemo-load-generator
    
    # Wait for services to start
    sleep 15
    
    # Check service status
    local services=("oteldemo-frontend" "oteldemo-cart" "oteldemo-checkout" \
        "oteldemo-currency" "oteldemo-payment" "oteldemo-product-catalog" \
        "oteldemo-load-generator")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_error "Failed services: ${failed_services[*]}"
        return 1
    fi
    
    log_success "All demo services are running"
}

test_connectivity() {
    log_info "Testing service connectivity..."
    
    # Test collector health
    if curl -s http://localhost:13133 > /dev/null; then
        log_success "OpenTelemetry Collector is responding"
    else
        log_error "OpenTelemetry Collector is not responding"
        return 1
    fi
    
    # Test Jaeger UI
    if curl -s http://localhost:16686 > /dev/null; then
        log_success "Jaeger UI is responding"
    else
        log_error "Jaeger UI is not responding"
        return 1
    fi
    
    # Test frontend
    if curl -s http://localhost:3000 > /dev/null; then
        log_success "Frontend is responding"
    else
        log_error "Frontend is not responding"
        return 1
    fi
    
    # Test load generator
    if curl -s http://localhost:8089 > /dev/null; then
        log_success "Load Generator is responding"
    else
        log_error "Load Generator is not responding"
        return 1
    fi
    
    log_success "All services are responding to HTTP requests"
}

test_observability() {
    log_info "Testing observability features..."
    
    # Test OTLP endpoint
    if curl -s -X POST http://localhost:4318/v1/traces \
        -H "Content-Type: application/json" \
        -d '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-service"}}]},"scopeSpans":[{"spans":[{"traceId":"12345678901234567890123456789012","spanId":"1234567890123456","name":"test-span","kind":1,"startTimeUnixNano":"1640995200000000000","endTimeUnixNano":"1640995201000000000"}]}]}]}' > /dev/null; then
        log_success "OTLP traces endpoint is working"
    else
        log_warning "OTLP traces endpoint test failed"
    fi
    
    # Test metrics endpoint
    if curl -s http://localhost:13133/metrics > /dev/null; then
        log_success "Metrics endpoint is working"
    else
        log_warning "Metrics endpoint test failed"
    fi
    
    log_success "Observability features tested"
}

test_cleanup() {
    log_info "Cleaning up test environment..."
    
    # Stop all services
    systemctl stop oteldemo-* || true
    systemctl stop otel-collector jaeger kafka zookeeper redis-server postgresql || true
    
    log_success "Cleanup completed"
}

generate_test_report() {
    log_info "Generating test report..."
    
    local report_file="/tmp/otel-demo-test-report.txt"
    
    cat > "$report_file" << EOF
OpenTelemetry Demo - VM Test Report
Generated: $(date)
Host: $(hostname)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
Memory: $(free -h | awk '/^Mem:/{print $2}')
Disk: $(df -h / | awk 'NR==2{print $4}')

Test Results:
- Prerequisites: $([ $? -eq 0 ] && echo "PASS" || echo "FAIL")
- Installation: $([ $? -eq 0 ] && echo "PASS" || echo "FAIL")
- Service Building: $([ $? -eq 0 ] && echo "PASS" || echo "FAIL")
- Infrastructure Services: $([ $? -eq 0 ] && echo "PASS" || echo "FAIL")
- Demo Services: $([ $? -eq 0 ] && echo "PASS" || echo "FAIL")
- Connectivity: $([ $? -eq 0 ] && echo "PASS" || echo "FAIL")
- Observability: $([ $? -eq 0 ] && echo "PASS" || echo "FAIL")

Service Status:
$(systemctl status otel-collector jaeger postgresql redis-server kafka zookeeper --no-pager -l)

Demo Service Status:
$(systemctl status oteldemo-* --no-pager -l)

Log File: $LOG_FILE
EOF
    
    log_success "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting OpenTelemetry Demo VM Test"
    log_info "Test log: $LOG_FILE"
    
    # Initialize log file
    echo "OpenTelemetry Demo VM Test - $(date)" > "$LOG_FILE"
    
    local test_phases=(
        "test_prerequisites"
        "test_installation"
        "test_service_building"
        "test_infrastructure_services"
        "test_demo_services"
        "test_connectivity"
        "test_observability"
    )
    
    local failed_phases=()
    
    for phase in "${test_phases[@]}"; do
        log_info "Running test phase: $phase"
        if $phase; then
            log_success "Test phase $phase completed successfully"
        else
            log_error "Test phase $phase failed"
            failed_phases+=("$phase")
        fi
        echo "---" >> "$LOG_FILE"
    done
    
    # Generate report
    generate_test_report
    
    # Cleanup
    test_cleanup
    
    # Final results
    if [[ ${#failed_phases[@]} -eq 0 ]]; then
        log_success "All tests passed! OpenTelemetry Demo is working correctly."
        exit 0
    else
        log_error "Some tests failed: ${failed_phases[*]}"
        log_info "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"
