#!/bin/bash
set -e

# Microsoft 365 Management Tools - Production Deployment Script
# Automated deployment with comprehensive checks and rollback capability

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="/opt/microsoft365-tools/backups/deployments"
DATA_DIR="/opt/microsoft365-tools/data"
LOG_FILE="/var/log/microsoft365-tools/deployment.log"

# Deployment metadata
DEPLOYMENT_ID="deploy_$(date +%Y%m%d_%H%M%S)"
VERSION=${VERSION:-"3.0.0"}
ENVIRONMENT=${ENVIRONMENT:-"production"}

# Functions
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${GREEN}[INFO]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
        DEBUG) echo -e "${BLUE}[DEBUG]${NC} $message" ;;
    esac
    
    # Also log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

check_prerequisites() {
    log INFO "Checking deployment prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        log ERROR "This script should not be run as root for security reasons"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("docker" "docker-compose" "curl" "jq" "envsubst")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log ERROR "Required command '$cmd' is not installed"
            exit 1
        fi
    done
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log ERROR "Docker daemon is not running or accessible"
        exit 1
    fi
    
    # Check environment file
    if [[ ! -f "$PROJECT_ROOT/.env.production" ]]; then
        log ERROR "Production environment file not found: $PROJECT_ROOT/.env.production"
        log INFO "Please copy .env.production.template to .env.production and configure it"
        exit 1
    fi
    
    # Check data directory permissions
    if [[ ! -d "$DATA_DIR" ]]; then
        log WARN "Data directory doesn't exist, creating: $DATA_DIR"
        sudo mkdir -p "$DATA_DIR"
        sudo chown -R $(whoami):$(whoami) "$DATA_DIR"
    fi
    
    log INFO "Prerequisites check completed successfully"
}

validate_environment() {
    log INFO "Validating environment configuration..."
    
    # Source environment file
    set -a
    source "$PROJECT_ROOT/.env.production"
    set +a
    
    # Required environment variables
    local required_vars=(
        "MICROSOFT_TENANT_ID"
        "MICROSOFT_CLIENT_ID"
        "MICROSOFT_CLIENT_SECRET"
        "SECRET_KEY"
        "JWT_SECRET_KEY"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "GRAFANA_PASSWORD"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" || "${!var}" == "your-"* ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log ERROR "Missing or unconfigured environment variables:"
        for var in "${missing_vars[@]}"; do
            log ERROR "  - $var"
        done
        exit 1
    fi
    
    # Validate domain configuration
    if [[ -z "$DOMAIN" || "$DOMAIN" == "your-domain.com" ]]; then
        log ERROR "DOMAIN must be configured in .env.production"
        exit 1
    fi
    
    log INFO "Environment validation completed successfully"
}

create_backup() {
    log INFO "Creating pre-deployment backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    local backup_file="$BACKUP_DIR/pre-deployment-$DEPLOYMENT_ID.tar.gz"
    
    # Backup current deployment
    cd "$PROJECT_ROOT"
    
    # Stop services for consistent backup
    if docker-compose -f docker-compose.production.yml ps | grep -q "Up"; then
        log INFO "Stopping services for backup..."
        docker-compose -f docker-compose.production.yml stop
    fi
    
    # Create backup archive
    tar -czf "$backup_file" \
        --exclude='*.log' \
        --exclude='__pycache__' \
        --exclude='.git' \
        --exclude='node_modules' \
        -C "$PROJECT_ROOT" \
        .
    
    # Backup database
    if docker ps | grep -q "m365-postgres"; then
        log INFO "Backing up database..."
        docker exec m365-postgres pg_dump -U m365user microsoft365_tools > "$BACKUP_DIR/database-$DEPLOYMENT_ID.sql"
    fi
    
    # Backup data volumes
    if [[ -d "$DATA_DIR" ]]; then
        log INFO "Backing up data volumes..."
        tar -czf "$BACKUP_DIR/data-$DEPLOYMENT_ID.tar.gz" -C "$DATA_DIR" .
    fi
    
    log INFO "Backup created successfully: $backup_file"
}

pull_latest_images() {
    log INFO "Pulling latest Docker images..."
    
    cd "$PROJECT_ROOT"
    docker-compose -f docker-compose.production.yml pull
    
    log INFO "Docker images updated successfully"
}

build_application() {
    log INFO "Building application Docker image..."
    
    cd "$PROJECT_ROOT"
    
    # Build with build arguments
    docker build \
        --file Dockerfile.production \
        --tag "microsoft365-tools:$VERSION" \
        --tag "microsoft365-tools:latest" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VERSION="$VERSION" \
        --build-arg VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
        .
    
    # Build backup service
    docker build \
        --file Dockerfile.backup \
        --tag "microsoft365-backup:$VERSION" \
        --tag "microsoft365-backup:latest" \
        .
    
    log INFO "Application images built successfully"
}

setup_data_directories() {
    log INFO "Setting up data directories..."
    
    # Create all required data directories
    local data_dirs=(
        "$DATA_DIR/postgres"
        "$DATA_DIR/redis"
        "$DATA_DIR/prometheus"
        "$DATA_DIR/grafana"
        "$DATA_DIR/loki"
        "$DATA_DIR/alertmanager"
    )
    
    for dir in "${data_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log INFO "Created directory: $dir"
        fi
    done
    
    # Set proper permissions
    chown -R $(whoami):$(whoami) "$DATA_DIR"
    chmod -R 755 "$DATA_DIR"
    
    log INFO "Data directories setup completed"
}

deploy_services() {
    log INFO "Deploying services..."
    
    cd "$PROJECT_ROOT"
    
    # Start services with production configuration
    docker-compose -f docker-compose.production.yml up -d
    
    log INFO "Services deployment initiated"
}

wait_for_services() {
    log INFO "Waiting for services to become healthy..."
    
    local max_attempts=60
    local attempt=0
    local services=("m365-postgres" "m365-redis" "m365-api")
    
    while [[ $attempt -lt $max_attempts ]]; do
        local healthy_services=0
        
        for service in "${services[@]}"; do
            if docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$service" | grep -q "healthy\|Up"; then
                ((healthy_services++))
            fi
        done
        
        if [[ $healthy_services -eq ${#services[@]} ]]; then
            log INFO "All services are healthy"
            break
        fi
        
        ((attempt++))
        log INFO "Attempt $attempt/$max_attempts - $healthy_services/${#services[@]} services healthy"
        sleep 5
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log ERROR "Services failed to become healthy within timeout"
        return 1
    fi
    
    return 0
}

run_health_checks() {
    log INFO "Running post-deployment health checks..."
    
    # API health check
    local api_url="http://localhost:8000/health"
    local max_attempts=12
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "$api_url" > /dev/null; then
            log INFO "API health check passed"
            break
        fi
        
        ((attempt++))
        log INFO "API health check attempt $attempt/$max_attempts"
        sleep 5
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log ERROR "API health check failed"
        return 1
    fi
    
    # Database connectivity check
    if ! docker exec m365-postgres pg_isready -U m365user -d microsoft365_tools > /dev/null; then
        log ERROR "Database connectivity check failed"
        return 1
    fi
    log INFO "Database connectivity check passed"
    
    # Redis connectivity check
    if ! docker exec m365-redis redis-cli ping > /dev/null; then
        log ERROR "Redis connectivity check failed"
        return 1
    fi
    log INFO "Redis connectivity check passed"
    
    # Prometheus metrics check
    if curl -f -s "http://localhost:9090/-/healthy" > /dev/null; then
        log INFO "Prometheus health check passed"
    else
        log WARN "Prometheus health check failed (non-critical)"
    fi
    
    # Grafana check
    if curl -f -s "http://localhost:3000/api/health" > /dev/null; then
        log INFO "Grafana health check passed"
    else
        log WARN "Grafana health check failed (non-critical)"
    fi
    
    log INFO "Health checks completed successfully"
    return 0
}

run_smoke_tests() {
    log INFO "Running smoke tests..."
    
    # Test API endpoints
    local endpoints=(
        "http://localhost:8000/"
        "http://localhost:8000/health"
        "http://localhost:8000/operations/status"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -f -s "$endpoint" > /dev/null; then
            log INFO "Smoke test passed: $endpoint"
        else
            log ERROR "Smoke test failed: $endpoint"
            return 1
        fi
    done
    
    log INFO "Smoke tests completed successfully"
    return 0
}

rollback_deployment() {
    log ERROR "Rolling back deployment..."
    
    # Stop current services
    docker-compose -f docker-compose.production.yml down
    
    # Restore from backup
    local backup_file="$BACKUP_DIR/pre-deployment-$DEPLOYMENT_ID.tar.gz"
    if [[ -f "$backup_file" ]]; then
        log INFO "Restoring from backup: $backup_file"
        tar -xzf "$backup_file" -C "$PROJECT_ROOT"
    fi
    
    # Restore database
    local db_backup="$BACKUP_DIR/database-$DEPLOYMENT_ID.sql"
    if [[ -f "$db_backup" ]]; then
        log INFO "Restoring database from backup"
        docker exec -i m365-postgres psql -U m365user microsoft365_tools < "$db_backup"
    fi
    
    # Restart services
    docker-compose -f docker-compose.production.yml up -d
    
    log ERROR "Rollback completed"
}

cleanup_old_images() {
    log INFO "Cleaning up old Docker images..."
    
    # Remove dangling images
    docker image prune -f
    
    # Remove old tagged images (keep last 3 versions)
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}" | \
        grep "microsoft365-tools" | \
        grep -v "latest" | \
        tail -n +4 | \
        awk '{print $3}' | \
        xargs -r docker rmi -f
    
    log INFO "Docker cleanup completed"
}

post_deployment_tasks() {
    log INFO "Running post-deployment tasks..."
    
    # Update deployment metadata
    echo "{
        \"deployment_id\": \"$DEPLOYMENT_ID\",
        \"version\": \"$VERSION\",
        \"environment\": \"$ENVIRONMENT\",
        \"deployed_at\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",
        \"deployed_by\": \"$(whoami)\",
        \"git_commit\": \"$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')\"
    }" > "$PROJECT_ROOT/deployment-info.json"
    
    # Set up log rotation
    if command -v logrotate &> /dev/null; then
        sudo logrotate -f /etc/logrotate.d/microsoft365-tools 2>/dev/null || true
    fi
    
    # Schedule automated backups
    if command -v crontab &> /dev/null; then
        log INFO "Setting up automated backup schedule"
        (crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_ROOT/scripts/backup.sh") | crontab -
    fi
    
    log INFO "Post-deployment tasks completed"
}

show_deployment_summary() {
    log INFO "Deployment Summary"
    echo "===================="
    echo "Deployment ID: $DEPLOYMENT_ID"
    echo "Version: $VERSION"
    echo "Environment: $ENVIRONMENT"
    echo "Deployed at: $(date)"
    echo "===================="
    echo ""
    echo "Service URLs:"
    echo "  API: https://${API_DOMAIN:-localhost:8000}"
    echo "  Dashboard: https://${API_DOMAIN:-localhost:8000}/dashboard"
    echo "  Grafana: https://${GRAFANA_DOMAIN:-localhost:3000}"
    echo "  Prometheus: https://${PROMETHEUS_DOMAIN:-localhost:9090}"
    echo ""
    echo "Next steps:"
    echo "  1. Verify all services are running: docker-compose -f docker-compose.production.yml ps"
    echo "  2. Check logs: docker-compose -f docker-compose.production.yml logs -f"
    echo "  3. Monitor metrics in Grafana"
    echo "  4. Set up DNS records for your domain"
    echo "  5. Configure SSL certificates"
    echo ""
}

# Main deployment flow
main() {
    log INFO "Starting Microsoft 365 Management Tools deployment"
    log INFO "Deployment ID: $DEPLOYMENT_ID"
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Trap for cleanup on error
    trap 'log ERROR "Deployment failed! Check logs for details."; exit 1' ERR
    
    # Deployment steps
    check_prerequisites
    validate_environment
    create_backup
    setup_data_directories
    pull_latest_images
    build_application
    deploy_services
    
    # Wait and verify
    if wait_for_services; then
        if run_health_checks && run_smoke_tests; then
            cleanup_old_images
            post_deployment_tasks
            show_deployment_summary
            log INFO "Deployment completed successfully!"
        else
            log ERROR "Health checks or smoke tests failed"
            rollback_deployment
            exit 1
        fi
    else
        log ERROR "Services failed to start properly"
        rollback_deployment
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi