#!/bin/bash
set -euo pipefail

# Microsoft 365 Management Tools - Kubernetes Deployment Script
# Support for Standard, Blue-Green, and Canary deployment strategies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELM_CHART_PATH="${PROJECT_ROOT}/helm/m365-tools"

# Default values
DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-standard}"
NAMESPACE="${NAMESPACE:-m365-tools}"
RELEASE_NAME="${RELEASE_NAME:-m365-tools}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DRY_RUN="${DRY_RUN:-false}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-600s}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Microsoft 365 Management Tools - Kubernetes Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -t, --type TYPE           Deployment type: standard, blue-green, canary (default: standard)
    -n, --namespace NS        Kubernetes namespace (default: m365-tools)
    -r, --release RELEASE     Helm release name (default: m365-tools)
    -i, --image-tag TAG       Docker image tag (default: latest)
    -d, --dry-run            Perform dry-run without actual deployment
    -w, --wait-timeout TIME   Wait timeout for deployment (default: 600s)
    -h, --help               Show this help message

DEPLOYMENT TYPES:
    standard      Standard rolling update deployment
    blue-green    Blue-Green deployment with zero-downtime switching
    canary        Canary deployment with traffic splitting

EXAMPLES:
    # Standard deployment
    $0 --type standard --image-tag v2.0.0

    # Blue-Green deployment
    $0 --type blue-green --image-tag v2.1.0

    # Canary deployment with 20% traffic
    CANARY_WEIGHT=20 $0 --type canary --image-tag v2.1.0-rc1

    # Dry-run deployment
    $0 --type canary --dry-run

ENVIRONMENT VARIABLES:
    DEPLOYMENT_TYPE           Same as --type
    NAMESPACE                 Same as --namespace
    RELEASE_NAME             Same as --release
    IMAGE_TAG                Same as --image-tag
    DRY_RUN                  Same as --dry-run (true/false)
    WAIT_TIMEOUT             Same as --wait-timeout
    CANARY_WEIGHT            Canary traffic weight percentage (1-100)
    BLUE_GREEN_VERSION       Blue-Green active version (blue/green)
    ROLLOUTS_ENABLED         Enable Argo Rollouts (true/false)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            DEPLOYMENT_TYPE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -i|--image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -w|--wait-timeout)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown parameter: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate deployment type
case $DEPLOYMENT_TYPE in
    standard|blue-green|canary)
        ;;
    *)
        error "Invalid deployment type: $DEPLOYMENT_TYPE"
        error "Valid types: standard, blue-green, canary"
        exit 1
        ;;
esac

# Pre-deployment checks
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        error "Helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if connected to cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "Not connected to Kubernetes cluster"
        exit 1
    fi
    
    # Check if Argo Rollouts is required and available
    if [[ "$DEPLOYMENT_TYPE" == "blue-green" || "$DEPLOYMENT_TYPE" == "canary" ]] && [[ "${ROLLOUTS_ENABLED:-true}" == "true" ]]; then
        if ! kubectl get crd rollouts.argoproj.io &> /dev/null; then
            warning "Argo Rollouts CRD not found. Installing standard deployment strategy."
            DEPLOYMENT_TYPE="standard"
        fi
    fi
    
    # Check if helm chart exists
    if [[ ! -d "$HELM_CHART_PATH" ]]; then
        error "Helm chart not found at: $HELM_CHART_PATH"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Create namespace if it doesn't exist
create_namespace() {
    log "📁 Checking namespace: $NAMESPACE"
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "Creating namespace: $NAMESPACE"
        if [[ "$DRY_RUN" != "true" ]]; then
            kubectl create namespace "$NAMESPACE"
            kubectl label namespace "$NAMESPACE" name="$NAMESPACE" --overwrite
        else
            echo "DRY RUN: kubectl create namespace $NAMESPACE"
        fi
    else
        success "Namespace $NAMESPACE already exists"
    fi
}

# Generate Helm values based on deployment type
generate_values() {
    local values_file="/tmp/helm-values-${DEPLOYMENT_TYPE}-$(date +%s).yaml"
    
    log "📝 Generating Helm values for $DEPLOYMENT_TYPE deployment..."
    
    cat > "$values_file" << EOF
# Generated values for $DEPLOYMENT_TYPE deployment
deployment:
  type: "$DEPLOYMENT_TYPE"
  version: "${BLUE_GREEN_VERSION:-blue}"
  canaryWeight: ${CANARY_WEIGHT:-10}

image:
  tag: "$IMAGE_TAG"

environment: "production"

# Enable rollouts for advanced deployment strategies
rollouts:
  enabled: $([ "$DEPLOYMENT_TYPE" != "standard" ] && [ "${ROLLOUTS_ENABLED:-true}" == "true" ] && echo "true" || echo "false")

# Blue-Green specific configuration
blueGreen:
  enabled: $([ "$DEPLOYMENT_TYPE" == "blue-green" ] && echo "true" || echo "false")
  activeVersion: "${BLUE_GREEN_VERSION:-blue}"
  autoPromotionEnabled: ${BLUE_GREEN_AUTO_PROMOTION:-false}

# Canary specific configuration
canary:
  enabled: $([ "$DEPLOYMENT_TYPE" == "canary" ] && echo "true" || echo "false")

# Enhanced monitoring for production deployments
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true

# Security configuration
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  fsGroup: 1001

podSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true

# High availability configuration
replicaCount: $([ "$DEPLOYMENT_TYPE" == "standard" ] && echo "3" || echo "2")
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10

# Network policies for production
networkPolicy:
  enabled: true

# Pod disruption budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1
EOF

    echo "$values_file"
}

# Deploy using Helm
deploy_helm() {
    local values_file="$1"
    
    log "🚀 Starting $DEPLOYMENT_TYPE deployment..."
    log "   Release: $RELEASE_NAME"
    log "   Namespace: $NAMESPACE"
    log "   Image Tag: $IMAGE_TAG"
    
    local helm_args=(
        upgrade
        --install
        --namespace "$NAMESPACE"
        --create-namespace
        --values "$values_file"
        --set "image.tag=$IMAGE_TAG"
        --timeout "$WAIT_TIMEOUT"
        --atomic
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        helm_args+=(--dry-run)
        log "🔍 Performing dry-run deployment..."
    else
        helm_args+=(--wait)
        log "⏳ Deploying to cluster..."
    fi
    
    # Add deployment type specific arguments
    case $DEPLOYMENT_TYPE in
        blue-green)
            helm_args+=(--set "blueGreen.enabled=true")
            helm_args+=(--set "blueGreen.activeVersion=${BLUE_GREEN_VERSION:-blue}")
            ;;
        canary)
            helm_args+=(--set "canary.enabled=true")
            helm_args+=(--set "deployment.canaryWeight=${CANARY_WEIGHT:-10}")
            ;;
    esac
    
    if helm "${helm_args[@]}" "$RELEASE_NAME" "$HELM_CHART_PATH"; then
        if [[ "$DRY_RUN" != "true" ]]; then
            success "✅ Deployment completed successfully!"
        else
            success "✅ Dry-run completed successfully!"
        fi
    else
        error "❌ Deployment failed!"
        return 1
    fi
}

# Post-deployment validation
validate_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log "🔍 Validating deployment..."
    
    # Wait for rollout to complete
    log "⏳ Waiting for rollout to complete..."
    if kubectl rollout status deployment/"$RELEASE_NAME" --namespace="$NAMESPACE" --timeout="$WAIT_TIMEOUT"; then
        success "✅ Rollout completed successfully"
    else
        error "❌ Rollout failed or timed out"
        return 1
    fi
    
    # Check pod status
    log "🔍 Checking pod status..."
    if kubectl get pods --namespace="$NAMESPACE" -l "app.kubernetes.io/name=m365-tools,app.kubernetes.io/instance=$RELEASE_NAME"; then
        success "✅ Pods are running"
    else
        warning "⚠️ Some pods may not be ready"
    fi
    
    # Check service endpoints
    log "🌐 Checking service endpoints..."
    if kubectl get endpoints --namespace="$NAMESPACE" "$RELEASE_NAME"; then
        success "✅ Service endpoints are available"
    else
        warning "⚠️ Service endpoints may not be ready"
    fi
    
    # Deployment-specific validation
    case $DEPLOYMENT_TYPE in
        blue-green)
            log "🔵🟢 Validating Blue-Green deployment..."
            kubectl get services --namespace="$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"
            ;;
        canary)
            log "🐤 Validating Canary deployment..."
            kubectl get ingress --namespace="$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"
            ;;
    esac
}

# Cleanup function
cleanup() {
    if [[ -n "${values_file:-}" ]] && [[ -f "$values_file" ]]; then
        rm -f "$values_file"
    fi
}

# Main execution
main() {
    log "🚀 Microsoft 365 Management Tools - Kubernetes Deployment"
    log "   Deployment Type: $DEPLOYMENT_TYPE"
    log "   Target Namespace: $NAMESPACE"
    log "   Release Name: $RELEASE_NAME"
    log "   Image Tag: $IMAGE_TAG"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Execute deployment steps
    check_prerequisites
    create_namespace
    
    values_file=$(generate_values)
    deploy_helm "$values_file"
    validate_deployment
    
    success "🎉 Deployment process completed!"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log ""
        log "📋 Deployment Summary:"
        log "   Release: $RELEASE_NAME"
        log "   Namespace: $NAMESPACE"
        log "   Type: $DEPLOYMENT_TYPE"
        log "   Image: $(kubectl get deployment "$RELEASE_NAME" --namespace="$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "$IMAGE_TAG")"
        log ""
        log "🔧 Useful commands:"
        log "   Status: kubectl get all --namespace=$NAMESPACE"
        log "   Logs: kubectl logs -f deployment/$RELEASE_NAME --namespace=$NAMESPACE"
        log "   Port-forward: kubectl port-forward service/$RELEASE_NAME 8080:80 --namespace=$NAMESPACE"
        
        case $DEPLOYMENT_TYPE in
            blue-green)
                log "   Switch traffic: helm upgrade $RELEASE_NAME $HELM_CHART_PATH --namespace=$NAMESPACE --set blueGreen.activeVersion=green"
                ;;
            canary)
                log "   Adjust canary: helm upgrade $RELEASE_NAME $HELM_CHART_PATH --namespace=$NAMESPACE --set deployment.canaryWeight=50"
                ;;
        esac
    fi
}

# Execute main function
main "$@"