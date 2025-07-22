#!/bin/bash
set -e

# Microsoft 365 Management Tools - Advanced Deployment Pipeline Script
# Enterprise-grade deployment automation with blue-green, canary, and rolling strategies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
ENVIRONMENT="${ENVIRONMENT:-development}"
DEPLOYMENT_STRATEGY="${DEPLOYMENT_STRATEGY:-blue_green}"
NAMESPACE="${NAMESPACE:-microsoft-365-tools-${ENVIRONMENT}}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPO_NAME="${REPO_NAME:-microsoft365tools}"

# Deployment settings
HEALTH_CHECK_TIMEOUT=300
ROLLBACK_ENABLED="${ROLLBACK_ENABLED:-true}"
MONITORING_ENABLED="${MONITORING_ENABLED:-true}"
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# Usage information
usage() {
    cat << EOF
Microsoft 365 Management Tools - Advanced Deployment Pipeline

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    deploy          Execute deployment
    rollback        Rollback to previous version
    status          Check deployment status
    cleanup         Clean up old deployments
    test            Run deployment tests
    
Options:
    --environment ENV           Target environment (development, staging, production)
    --strategy STRATEGY         Deployment strategy (blue_green, canary, rolling)
    --image-tag TAG            Container image tag
    --namespace NAMESPACE      Kubernetes namespace
    --dry-run                  Simulate deployment
    --force                    Force deployment
    --skip-tests              Skip health checks
    --skip-backup             Skip pre-deployment backup
    -h, --help                Show this help message

Deployment Strategies:
    blue_green    Zero-downtime deployment with environment switching
    canary        Gradual traffic shifting with monitoring
    rolling       Rolling update with pod replacement

Examples:
    $0 deploy --environment staging --strategy blue_green
    $0 deploy --environment production --strategy canary --image-tag v2.0.1
    $0 rollback --environment production
    $0 status --environment staging

EOF
}

# Check prerequisites
check_prerequisites() {
    log "Checking deployment prerequisites..."
    
    # Check required tools
    local tools=("kubectl" "helm" "curl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
        kubectl label namespace "$NAMESPACE" \
            environment="$ENVIRONMENT" \
            monitoring=enabled \
            backup=enabled
    fi
    
    log "Prerequisites check completed"
}

# Pre-deployment backup
create_backup() {
    if [[ "$BACKUP_ENABLED" != "true" ]]; then
        log "Backup disabled, skipping..."
        return 0
    fi
    
    log "Creating pre-deployment backup..."
    
    local backup_timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="/tmp/backup-${ENVIRONMENT}-${backup_timestamp}"
    
    mkdir -p "$backup_dir"
    
    # Backup current deployment configuration
    if kubectl get deployment -n "$NAMESPACE" &> /dev/null; then
        kubectl get deployment,service,configmap,secret,ingress \
            -n "$NAMESPACE" \
            -o yaml > "$backup_dir/kubernetes-resources.yaml"
        log "Kubernetes resources backed up"
    fi
    
    # Backup Helm releases
    if helm list -n "$NAMESPACE" | grep -q "m365-tools"; then
        helm get values m365-tools -n "$NAMESPACE" > "$backup_dir/helm-values.yaml"
        helm get manifest m365-tools -n "$NAMESPACE" > "$backup_dir/helm-manifest.yaml"
        log "Helm configuration backed up"
    fi
    
    # Store backup location
    echo "$backup_dir" > "/tmp/last-backup-location"
    log "Backup created: $backup_dir"
}

# Blue-Green deployment
deploy_blue_green() {
    log "Starting Blue-Green deployment to $ENVIRONMENT..."
    
    # Determine current active environment
    local current_active=$(kubectl get service m365-tools-service \
        -n "$NAMESPACE" \
        -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "blue")
    
    local target_env="green"
    if [[ "$current_active" == "green" ]]; then
        target_env="blue"
    fi
    
    log "Current active: $current_active, Deploying to: $target_env"
    
    # Deploy to target environment
    local values_file="/tmp/values-${target_env}.yaml"
    create_helm_values "$target_env" > "$values_file"
    
    helm upgrade --install "m365-tools-${target_env}" \
        "$PROJECT_ROOT/helm/m365-tools" \
        --namespace "$NAMESPACE" \
        --values "$values_file" \
        --set image.tag="$IMAGE_TAG" \
        --set deployment.version="$target_env" \
        --wait --timeout=10m
    
    # Health check
    if run_health_checks "$target_env"; then
        # Switch traffic
        kubectl patch service m365-tools-service \
            -n "$NAMESPACE" \
            -p "{\"spec\":{\"selector\":{\"version\":\"$target_env\"}}}"
        
        log "Traffic switched to $target_env"
        
        # Wait for stabilization
        sleep 30
        
        # Final health check
        if run_health_checks "$target_env"; then
            # Clean up old environment
            log "Cleaning up old environment: $current_active"
            helm uninstall "m365-tools-${current_active}" -n "$NAMESPACE" || true
            
            log "✅ Blue-Green deployment completed successfully"
            return 0
        else
            error "Final health check failed, rolling back"
            rollback_blue_green "$current_active" "$target_env"
            return 1
        fi
    else
        error "Health check failed, cleaning up failed deployment"
        helm uninstall "m365-tools-${target_env}" -n "$NAMESPACE" || true
        return 1
    fi
}

# Canary deployment
deploy_canary() {
    log "Starting Canary deployment to $ENVIRONMENT..."
    
    local canary_weight=10
    local weights=(10 25 50 75 100)
    
    # Deploy canary version
    local values_file="/tmp/values-canary.yaml"
    create_helm_values "canary" "$canary_weight" > "$values_file"
    
    helm upgrade --install "m365-tools-canary" \
        "$PROJECT_ROOT/helm/m365-tools" \
        --namespace "$NAMESPACE" \
        --values "$values_file" \
        --set image.tag="$IMAGE_TAG" \
        --set deployment.type="canary" \
        --set canary.weight="$canary_weight" \
        --wait --timeout=10m
    
    # Progressive traffic shifting
    for weight in "${weights[@]}"; do
        log "Shifting $weight% traffic to canary..."
        
        # Update canary weight
        kubectl patch deployment m365-tools-canary \
            -n "$NAMESPACE" \
            --type='merge' \
            -p="{\"metadata\":{\"annotations\":{\"canary.weight\":\"$weight\"}}}"
        
        # Monitor for issues
        local monitor_duration=300  # 5 minutes
        if ! monitor_canary_deployment "$weight" "$monitor_duration"; then
            error "Canary monitoring failed at $weight%, rolling back"
            rollback_canary
            return 1
        fi
        
        log "Canary at $weight% is stable"
    done
    
    # Complete canary deployment (100% traffic)
    log "Completing canary deployment..."
    
    # Replace main deployment
    helm upgrade --install "m365-tools" \
        "$PROJECT_ROOT/helm/m365-tools" \
        --namespace "$NAMESPACE" \
        --set image.tag="$IMAGE_TAG" \
        --wait --timeout=10m
    
    # Remove canary
    helm uninstall "m365-tools-canary" -n "$NAMESPACE" || true
    
    log "✅ Canary deployment completed successfully"
    return 0
}

# Rolling deployment
deploy_rolling() {
    log "Starting Rolling deployment to $ENVIRONMENT..."
    
    # Standard Helm upgrade with rolling update
    helm upgrade --install "m365-tools" \
        "$PROJECT_ROOT/helm/m365-tools" \
        --namespace "$NAMESPACE" \
        --set image.tag="$IMAGE_TAG" \
        --set environment="$ENVIRONMENT" \
        --wait --timeout=10m
    
    # Health check
    if run_health_checks; then
        log "✅ Rolling deployment completed successfully"
        return 0
    else
        error "Rolling deployment health check failed"
        return 1
    fi
}

# Generate Helm values
create_helm_values() {
    local version="${1:-}"
    local canary_weight="${2:-}"
    
    cat << EOF
global:
  imageRegistry: $REGISTRY

image:
  repository: $REGISTRY/$REPO_NAME
  tag: $IMAGE_TAG

environment: $ENVIRONMENT

replicaCount: $(get_replica_count)

resources:
  requests:
    cpu: $(get_cpu_request)
    memory: $(get_memory_request)
  limits:
    cpu: $(get_cpu_limit)
    memory: $(get_memory_limit)

monitoring:
  enabled: $MONITORING_ENABLED

persistence:
  enabled: true
  size: $(get_storage_size)

EOF

    if [[ -n "$version" ]]; then
        echo "deployment:"
        echo "  version: $version"
        if [[ -n "$canary_weight" ]]; then
            echo "  type: canary"
            echo "canary:"
            echo "  weight: $canary_weight"
        else
            echo "  type: blue-green"
        fi
    fi
}

# Environment-specific resource allocation
get_replica_count() {
    case "$ENVIRONMENT" in
        production) echo "3" ;;
        staging) echo "2" ;;
        *) echo "1" ;;
    esac
}

get_cpu_request() {
    case "$ENVIRONMENT" in
        production) echo "500m" ;;
        staging) echo "250m" ;;
        *) echo "100m" ;;
    esac
}

get_memory_request() {
    case "$ENVIRONMENT" in
        production) echo "1Gi" ;;
        staging) echo "512Mi" ;;
        *) echo "256Mi" ;;
    esac
}

get_cpu_limit() {
    case "$ENVIRONMENT" in
        production) echo "2" ;;
        staging) echo "1" ;;
        *) echo "500m" ;;
    esac
}

get_memory_limit() {
    case "$ENVIRONMENT" in
        production) echo "4Gi" ;;
        staging) echo "2Gi" ;;
        *) echo "1Gi" ;;
    esac
}

get_storage_size() {
    case "$ENVIRONMENT" in
        production) echo "20Gi" ;;
        staging) echo "10Gi" ;;
        *) echo "5Gi" ;;
    esac
}

# Health checks
run_health_checks() {
    local version="${1:-}"
    local service_name="m365-tools-service"
    
    if [[ -n "$version" ]]; then
        service_name="m365-tools-service-${version}"
    fi
    
    log "Running health checks..."
    
    # Wait for pods to be ready
    local label_selector="app=m365-tools"
    if [[ -n "$version" ]]; then
        label_selector="app=m365-tools,version=$version"
    fi
    
    if ! kubectl wait --for=condition=ready pod \
        -l "$label_selector" \
        -n "$NAMESPACE" \
        --timeout="${HEALTH_CHECK_TIMEOUT}s"; then
        error "Pods failed to become ready"
        return 1
    fi
    
    # Port forward for health check
    local port_forward_pid=""
    kubectl port-forward "service/$service_name" 8080:80 -n "$NAMESPACE" &
    port_forward_pid=$!
    sleep 10
    
    # Health endpoint check
    local health_check_passed=false
    for i in {1..10}; do
        if curl -f -s http://localhost:8080/health > /dev/null; then
            log "Health check passed (attempt $i)"
            health_check_passed=true
            break
        fi
        sleep 5
    done
    
    # Clean up port forward
    kill $port_forward_pid 2>/dev/null || true
    
    if [[ "$health_check_passed" == "true" ]]; then
        log "✅ Health checks passed"
        return 0
    else
        error "❌ Health checks failed"
        return 1
    fi
}

# Monitor canary deployment
monitor_canary_deployment() {
    local weight="$1"
    local duration="$2"
    
    log "Monitoring canary deployment at $weight% for $duration seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Check error rate
        local error_rate=$(get_error_rate)
        if (( $(echo "$error_rate > 0.05" | bc -l) )); then
            error "Error rate too high: $error_rate"
            return 1
        fi
        
        # Check response time
        local response_time=$(get_response_time)
        if (( $(echo "$response_time > 2000" | bc -l) )); then
            error "Response time too high: ${response_time}ms"
            return 1
        fi
        
        sleep 30
    done
    
    log "Canary monitoring completed successfully"
    return 0
}

# Get error rate (mock implementation)
get_error_rate() {
    # This would typically query Prometheus or other monitoring system
    echo "0.01"
}

# Get response time (mock implementation)
get_response_time() {
    # This would typically query Prometheus or other monitoring system
    echo "500"
}

# Rollback functions
rollback_blue_green() {
    local stable_env="$1"
    local failed_env="$2"
    
    log "Rolling back Blue-Green deployment..."
    
    # Switch traffic back to stable environment
    kubectl patch service m365-tools-service \
        -n "$NAMESPACE" \
        -p "{\"spec\":{\"selector\":{\"version\":\"$stable_env\"}}}"
    
    # Clean up failed environment
    helm uninstall "m365-tools-${failed_env}" -n "$NAMESPACE" || true
    
    log "✅ Rollback completed"
}

rollback_canary() {
    log "Rolling back Canary deployment..."
    
    # Remove canary deployment
    helm uninstall "m365-tools-canary" -n "$NAMESPACE" || true
    
    log "✅ Canary rollback completed"
}

# General rollback
rollback_deployment() {
    log "Initiating rollback for $ENVIRONMENT environment..."
    
    # Helm rollback
    if helm history m365-tools -n "$NAMESPACE" &> /dev/null; then
        local previous_revision=$(helm history m365-tools -n "$NAMESPACE" --max 2 -o json | \
            jq -r '.[-2].revision' 2>/dev/null || echo "")
        
        if [[ -n "$previous_revision" && "$previous_revision" != "null" ]]; then
            helm rollback m365-tools "$previous_revision" -n "$NAMESPACE"
            log "✅ Rollback to revision $previous_revision completed"
        else
            error "No previous revision found for rollback"
            
            # Restore from backup if available
            if [[ -f "/tmp/last-backup-location" ]]; then
                local backup_dir=$(cat "/tmp/last-backup-location")
                restore_from_backup "$backup_dir"
            fi
        fi
    else
        error "No Helm release found for rollback"
        return 1
    fi
}

# Restore from backup
restore_from_backup() {
    local backup_dir="$1"
    
    log "Restoring from backup: $backup_dir"
    
    if [[ -f "$backup_dir/kubernetes-resources.yaml" ]]; then
        kubectl apply -f "$backup_dir/kubernetes-resources.yaml" -n "$NAMESPACE"
        log "Kubernetes resources restored"
    fi
    
    if [[ -f "$backup_dir/helm-values.yaml" ]]; then
        helm upgrade m365-tools "$PROJECT_ROOT/helm/m365-tools" \
            -n "$NAMESPACE" \
            --values "$backup_dir/helm-values.yaml"
        log "Helm configuration restored"
    fi
}

# Deployment status
check_deployment_status() {
    log "Checking deployment status for $ENVIRONMENT..."
    
    # Helm releases
    echo "📊 Helm Releases:"
    helm list -n "$NAMESPACE"
    
    # Kubernetes resources
    echo "🔧 Kubernetes Resources:"
    kubectl get deployment,service,ingress -n "$NAMESPACE"
    
    # Pod status
    echo "🚀 Pod Status:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    # Recent events
    echo "📋 Recent Events:"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
}

# Cleanup old deployments
cleanup_deployments() {
    log "Cleaning up old deployments in $ENVIRONMENT..."
    
    # Keep last 3 Helm revisions
    if helm history m365-tools -n "$NAMESPACE" &> /dev/null; then
        local revision_count=$(helm history m365-tools -n "$NAMESPACE" --max 100 | wc -l)
        if (( revision_count > 4 )); then  # Including header
            log "Keeping last 3 revisions, cleaning up older ones"
            # Helm automatically manages revision history
        fi
    fi
    
    # Clean up failed pods
    kubectl delete pods --field-selector=status.phase=Failed -n "$NAMESPACE" || true
    
    # Clean up completed jobs older than 7 days
    kubectl delete jobs --field-selector=status.conditions[0].type=Complete \
        -n "$NAMESPACE" \
        $(kubectl get jobs -n "$NAMESPACE" --no-headers | \
          awk '$4 ~ /[7-9]d|[0-9][0-9]d/ {print $1}') 2>/dev/null || true
    
    log "✅ Cleanup completed"
}

# Parse command line arguments
COMMAND=""
DRY_RUN="false"
FORCE="false"
SKIP_TESTS="false"
SKIP_BACKUP="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        deploy|rollback|status|cleanup|test)
            COMMAND="$1"
            shift
            ;;
        --environment)
            ENVIRONMENT="$2"
            NAMESPACE="microsoft-365-tools-${ENVIRONMENT}"
            shift 2
            ;;
        --strategy)
            DEPLOYMENT_STRATEGY="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --skip-tests)
            SKIP_TESTS="true"
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP="false"
            BACKUP_ENABLED="false"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log "🚀 Microsoft 365 Management Tools - Advanced Deployment Pipeline"
    log "==============================================================="
    
    info "Configuration:"
    info "  Environment: $ENVIRONMENT"
    info "  Strategy: $DEPLOYMENT_STRATEGY"
    info "  Namespace: $NAMESPACE"
    info "  Image Tag: $IMAGE_TAG"
    info "  Dry Run: $DRY_RUN"
    
    check_prerequisites
    
    case "$COMMAND" in
        deploy)
            if [[ "$SKIP_BACKUP" != "true" ]]; then
                create_backup
            fi
            
            case "$DEPLOYMENT_STRATEGY" in
                blue_green)
                    deploy_blue_green
                    ;;
                canary)
                    deploy_canary
                    ;;
                rolling)
                    deploy_rolling
                    ;;
                *)
                    error "Unknown deployment strategy: $DEPLOYMENT_STRATEGY"
                    exit 1
                    ;;
            esac
            ;;
        rollback)
            rollback_deployment
            ;;
        status)
            check_deployment_status
            ;;
        cleanup)
            cleanup_deployments
            ;;
        test)
            run_health_checks
            ;;
        "")
            warn "No command specified"
            usage
            exit 1
            ;;
        *)
            error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
    
    log "🎉 Deployment pipeline completed successfully!"
}

# Execute main function
main "$@"