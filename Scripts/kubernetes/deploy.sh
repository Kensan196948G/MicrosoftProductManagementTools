#!/bin/bash
set -e

# Microsoft 365 Management Tools - Kubernetes Deployment Script
# Enterprise-grade deployment automation with zero-downtime rolling updates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default configuration
NAMESPACE="microsoft-365-tools"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-ghcr.io/microsoft365-tools}"
DEPLOYMENT_NAME="m365-tools-deployment"
TIMEOUT="${TIMEOUT:-600}"
ENVIRONMENT="${ENVIRONMENT:-production}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Usage information
usage() {
    cat << EOF
Microsoft 365 Management Tools - Kubernetes Deployment

Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE     Target Kubernetes namespace (default: microsoft-365-tools)
    -t, --tag TAG                Docker image tag (default: latest)
    -r, --registry REGISTRY      Container registry (default: ghcr.io/microsoft365-tools)
    -e, --environment ENV        Deployment environment (default: production)
    -d, --dry-run                Perform a dry run without applying changes
    -f, --force                  Force deployment without confirmations
    -h, --help                   Show this help message
    --timeout SECONDS           Deployment timeout in seconds (default: 600)
    --skip-checks               Skip pre-deployment checks
    --rollback                  Rollback to previous deployment

Examples:
    $0 --tag v2.0.1 --environment production
    $0 --dry-run --namespace staging
    $0 --rollback --force

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -t|--tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --skip-checks)
                SKIP_CHECKS=true
                shift
                ;;
            --rollback)
                ROLLBACK=true
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
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check kubectl context
    CURRENT_CONTEXT=$(kubectl config current-context)
    info "Current kubectl context: ${CURRENT_CONTEXT}"
    
    # Verify cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        warn "Namespace '${NAMESPACE}' does not exist. Creating..."
        kubectl create namespace "${NAMESPACE}"
        kubectl label namespace "${NAMESPACE}" name="${NAMESPACE}" environment="${ENVIRONMENT}"
    fi
    
    log "Prerequisites check completed"
}

# Validate deployment configuration
validate_configuration() {
    if [[ "$SKIP_CHECKS" == "true" ]]; then
        warn "Skipping configuration validation"
        return 0
    fi
    
    log "Validating deployment configuration..."
    
    # Check if deployment manifests exist
    MANIFEST_FILE="${PROJECT_ROOT}/k8s-deployment.yaml"
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        error "Kubernetes manifest file not found: $MANIFEST_FILE"
        exit 1
    fi
    
    # Validate manifest syntax
    if ! kubectl apply --dry-run=client -f "$MANIFEST_FILE" &> /dev/null; then
        error "Invalid Kubernetes manifest syntax"
        exit 1
    fi
    
    # Check required secrets
    required_secrets=(
        "m365-secrets"
        "azure-keyvault-cert"
    )
    
    for secret in "${required_secrets[@]}"; do
        if ! kubectl get secret "$secret" -n "$NAMESPACE" &> /dev/null; then
            warn "Required secret '${secret}' not found in namespace '${NAMESPACE}'"
        fi
    done
    
    log "Configuration validation completed"
}

# Get current deployment status
get_deployment_status() {
    if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
        CURRENT_IMAGE=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
        READY_REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
        DESIRED_REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
        
        info "Current deployment status:"
        info "  Image: ${CURRENT_IMAGE}"
        info "  Ready replicas: ${READY_REPLICAS:-0}/${DESIRED_REPLICAS:-0}"
        
        return 0
    else
        info "Deployment '${DEPLOYMENT_NAME}' does not exist in namespace '${NAMESPACE}'"
        return 1
    fi
}

# Create deployment configuration
create_deployment_config() {
    log "Creating deployment configuration..."
    
    FULL_IMAGE_NAME="${REGISTRY}/microsoft365-tools:${IMAGE_TAG}"
    TEMP_MANIFEST="/tmp/k8s-deployment-${ENVIRONMENT}.yaml"
    
    # Update manifest with current configuration
    sed "s|microsoft365tools:2.0|${FULL_IMAGE_NAME}|g" "${PROJECT_ROOT}/k8s-deployment.yaml" > "$TEMP_MANIFEST"
    
    # Update namespace if different
    if [[ "$NAMESPACE" != "microsoft-365-tools" ]]; then
        sed -i "s|namespace: microsoft-365-tools|namespace: ${NAMESPACE}|g" "$TEMP_MANIFEST"
    fi
    
    # Add environment-specific labels
    kubectl patch -f "$TEMP_MANIFEST" --local \
        -p "{\"metadata\":{\"labels\":{\"environment\":\"${ENVIRONMENT}\",\"version\":\"${IMAGE_TAG}\"}}}" \
        -o yaml > "${TEMP_MANIFEST}.patched"
    mv "${TEMP_MANIFEST}.patched" "$TEMP_MANIFEST"
    
    echo "$TEMP_MANIFEST"
}

# Perform deployment
deploy() {
    log "Starting deployment to ${ENVIRONMENT} environment..."
    
    MANIFEST_FILE=$(create_deployment_config)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run mode - showing what would be applied:"
        kubectl apply --dry-run=server -f "$MANIFEST_FILE"
        rm -f "$MANIFEST_FILE"
        return 0
    fi
    
    # Confirmation for production deployments
    if [[ "$ENVIRONMENT" == "production" && "$FORCE" != "true" ]]; then
        echo
        warn "You are about to deploy to PRODUCTION environment!"
        info "Namespace: ${NAMESPACE}"
        info "Image: ${REGISTRY}/microsoft365-tools:${IMAGE_TAG}"
        echo -n "Are you sure you want to continue? (yes/no): "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Apply the manifest
    log "Applying Kubernetes manifests..."
    kubectl apply -f "$MANIFEST_FILE"
    
    # Update deployment image
    log "Updating deployment image..."
    kubectl set image deployment/"$DEPLOYMENT_NAME" \
        m365-tools="${REGISTRY}/microsoft365-tools:${IMAGE_TAG}" \
        -n "$NAMESPACE"
    
    # Record deployment
    kubectl annotate deployment/"$DEPLOYMENT_NAME" \
        deployment.kubernetes.io/revision="$(date +%s)" \
        deployment.kubernetes.io/change-cause="Deployed version ${IMAGE_TAG} via automation script" \
        github.com/sha="${GITHUB_SHA:-unknown}" \
        github.com/actor="${GITHUB_ACTOR:-$(whoami)}" \
        -n "$NAMESPACE" \
        --overwrite
    
    # Wait for rollout
    log "Waiting for deployment rollout..."
    if kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout="${TIMEOUT}s"; then
        log "Deployment rollout completed successfully"
    else
        error "Deployment rollout timed out or failed"
        show_deployment_logs
        exit 1
    fi
    
    rm -f "$MANIFEST_FILE"
}

# Rollback deployment
rollback_deployment() {
    log "Rolling back deployment..."
    
    if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
        error "Deployment '${DEPLOYMENT_NAME}' not found"
        exit 1
    fi
    
    # Get rollout history
    log "Current rollout history:"
    kubectl rollout history deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE"
    
    if [[ "$FORCE" != "true" ]]; then
        echo -n "Confirm rollback to previous version? (yes/no): "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            log "Rollback cancelled by user"
            exit 0
        fi
    fi
    
    # Perform rollback
    kubectl rollout undo deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE"
    
    # Wait for rollback
    log "Waiting for rollback to complete..."
    kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout="${TIMEOUT}s"
    
    log "Rollback completed"
}

# Health check
perform_health_check() {
    log "Performing post-deployment health check..."
    
    # Wait for pods to be ready
    sleep 30
    
    # Check pod status
    READY_PODS=$(kubectl get pods -l app=m365-tools -n "$NAMESPACE" --field-selector=status.phase=Running -o name | wc -l)
    TOTAL_PODS=$(kubectl get pods -l app=m365-tools -n "$NAMESPACE" -o name | wc -l)
    
    info "Ready pods: ${READY_PODS}/${TOTAL_PODS}"
    
    if [[ "$READY_PODS" -eq 0 ]]; then
        error "No pods are ready"
        show_deployment_logs
        exit 1
    fi
    
    # Check service endpoint
    SERVICE_IP=$(kubectl get service m365-tools-service -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    if [[ -n "$SERVICE_IP" ]]; then
        info "Service endpoint: ${SERVICE_IP}"
        
        # Test health endpoint if possible
        if kubectl run health-check --rm -i --tty --restart=Never --image=curlimages/curl -- \
           curl -f "http://${SERVICE_IP}/health" 2>/dev/null; then
            log "Health check endpoint is responding"
        else
            warn "Health check endpoint test failed or not accessible"
        fi
    fi
    
    log "Health check completed"
}

# Show deployment logs
show_deployment_logs() {
    warn "Showing recent deployment logs..."
    
    # Show deployment events
    kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" | tail -20
    
    # Show pod logs
    kubectl logs -l app=m365-tools -n "$NAMESPACE" --tail=50 --since=5m
}

# Main execution
main() {
    log "🚀 Microsoft 365 Management Tools - Kubernetes Deployment"
    log "=================================================="
    
    parse_args "$@"
    
    info "Configuration:"
    info "  Namespace: ${NAMESPACE}"
    info "  Image Tag: ${IMAGE_TAG}"
    info "  Registry: ${REGISTRY}"
    info "  Environment: ${ENVIRONMENT}"
    info "  Timeout: ${TIMEOUT}s"
    
    if [[ "$ROLLBACK" == "true" ]]; then
        check_prerequisites
        rollback_deployment
    else
        check_prerequisites
        validate_configuration
        get_deployment_status || true
        deploy
        perform_health_check
    fi
    
    log "🎉 Deployment process completed successfully!"
    
    # Show final status
    get_deployment_status
}

# Execute main function with all arguments
main "$@"