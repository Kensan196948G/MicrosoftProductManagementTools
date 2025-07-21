#!/bin/bash
set -e

# Microsoft 365 Management Tools - Security Hardening Script
# Enterprise-grade security configuration and vulnerability mitigation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
NAMESPACE="${NAMESPACE:-microsoft-365-tools}"
ENVIRONMENT="${ENVIRONMENT:-production}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# Security hardening functions
apply_network_policies() {
    log "Applying Kubernetes Network Policies..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: m365-tools-network-policy
  namespace: $NAMESPACE
spec:
  podSelector:
    matchLabels:
      app: m365-tools
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS
    - protocol: TCP
      port: 80   # HTTP
    - protocol: TCP
      port: 5432 # PostgreSQL
    - protocol: TCP
      port: 6379 # Redis
    - protocol: UDP
      port: 53   # DNS
EOF

    log "✅ Network policies applied"
}

apply_pod_security_standards() {
    log "Applying Pod Security Standards..."
    
    # Update namespace with pod security labels
    kubectl label namespace "$NAMESPACE" \
        pod-security.kubernetes.io/enforce=restricted \
        pod-security.kubernetes.io/audit=restricted \
        pod-security.kubernetes.io/warn=restricted \
        --overwrite
    
    log "✅ Pod Security Standards applied"
}

create_security_context_constraints() {
    log "Creating Security Context Constraints..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: SecurityContextConstraints
metadata:
  name: m365-tools-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowedCapabilities: []
defaultAddCapabilities: []
requiredDropCapabilities:
- ALL
allowedFlexVolumes: []
fsGroup:
  type: MustRunAs
  ranges:
  - min: 1000
    max: 2000
runAsUser:
  type: MustRunAs
  uid: 1001
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: MustRunAs
  ranges:
  - min: 1000
    max: 2000
volumes:
- configMap
- emptyDir
- persistentVolumeClaim
- secret
EOF

    log "✅ Security Context Constraints created"
}

setup_rbac() {
    log "Setting up RBAC policies..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: m365-tools-security-sa
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: m365-tools-security-role
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: m365-tools-security-binding
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: m365-tools-security-sa
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: m365-tools-security-role
  apiGroup: rbac.authorization.k8s.io
EOF

    log "✅ RBAC policies configured"
}

create_secrets_securely() {
    log "Creating secure secrets configuration..."
    
    # Create example secret template (values should be provided via external secret management)
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: m365-tools-security-config
  namespace: $NAMESPACE
  labels:
    app: m365-tools
    component: security
  annotations:
    kubernetes.io/managed-by: "security-hardening-script"
type: Opaque
data:
  # These should be populated by external secret management system
  security-key: $(echo -n "change-me-in-production" | base64)
  encryption-key: $(echo -n "change-me-in-production" | base64)
EOF

    log "✅ Security secrets template created"
}

setup_admission_controllers() {
    log "Configuring admission controllers..."
    
    # Pod Security Policy (deprecated but still used in some clusters)
    cat <<EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: m365-tools-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
EOF

    log "✅ Admission controllers configured"
}

configure_resource_quotas() {
    log "Configuring resource quotas and limits..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: m365-tools-quota
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
    services: "5"
    secrets: "10"
    configmaps: "10"
    persistentvolumeclaims: "3"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: m365-tools-limits
  namespace: $NAMESPACE
spec:
  limits:
  - default:
      cpu: 500m
      memory: 1Gi
    defaultRequest:
      cpu: 250m
      memory: 512Mi
    type: Container
  - max:
      cpu: 2
      memory: 4Gi
    min:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF

    log "✅ Resource quotas and limits configured"
}

setup_monitoring_and_auditing() {
    log "Setting up security monitoring and auditing..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-audit-config
  namespace: $NAMESPACE
data:
  audit-policy.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
    - level: Namespace
      omitStages:
      - RequestReceived
      resources:
      - group: ""
        resources: ["pods", "services", "secrets"]
      namespaces: ["$NAMESPACE"]
    - level: RequestResponse
      omitStages:
      - RequestReceived
      resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "rolebindings"]
      namespaces: ["$NAMESPACE"]
EOF

    log "✅ Security monitoring and auditing configured"
}

run_security_scan() {
    log "Running security vulnerability scan..."
    
    # Check if trivy is available
    if command -v trivy &> /dev/null; then
        # Scan the deployment for vulnerabilities
        log "Scanning deployment for vulnerabilities..."
        trivy k8s --report=summary deployment/m365-tools-deployment -n "$NAMESPACE" || warn "Trivy scan failed"
        
        # Scan container images
        log "Scanning container images..."
        local image=$(kubectl get deployment m365-tools-deployment -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
        if [[ -n "$image" ]]; then
            trivy image --severity HIGH,CRITICAL "$image" || warn "Image scan failed"
        fi
    else
        warn "Trivy not found, skipping vulnerability scan"
    fi
    
    log "✅ Security scan completed"
}

validate_security_configuration() {
    log "Validating security configuration..."
    
    # Check if pods are running as non-root
    local non_root_count=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -c true || echo "0")
    local total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    
    if [[ "$non_root_count" -eq "$total_pods" && "$total_pods" -gt 0 ]]; then
        log "✅ All pods running as non-root"
    else
        warn "⚠️ Some pods may be running as root"
    fi
    
    # Check if Network Policies are applied
    if kubectl get networkpolicy m365-tools-network-policy -n "$NAMESPACE" &> /dev/null; then
        log "✅ Network Policy is active"
    else
        warn "⚠️ Network Policy not found"
    fi
    
    # Check resource limits
    local pods_with_limits=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].resources.limits}' | grep -c memory || echo "0")
    if [[ "$pods_with_limits" -gt 0 ]]; then
        log "✅ Resource limits configured"
    else
        warn "⚠️ Resource limits not configured"
    fi
    
    log "✅ Security validation completed"
}

backup_security_configuration() {
    log "Backing up security configuration..."
    
    local backup_dir="/tmp/security-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Export security-related resources
    kubectl get networkpolicy,psp,resourcequota,limitrange,secret,serviceaccount,role,rolebinding \
        -n "$NAMESPACE" -o yaml > "$backup_dir/security-resources.yaml"
    
    # Export namespace configuration
    kubectl get namespace "$NAMESPACE" -o yaml > "$backup_dir/namespace.yaml"
    
    log "✅ Security configuration backed up to: $backup_dir"
    echo "$backup_dir"
}

# Main security hardening function
apply_security_hardening() {
    log "🔒 Starting security hardening process..."
    
    # Create backup first
    local backup_dir=$(backup_security_configuration)
    
    # Apply security measures
    apply_network_policies
    apply_pod_security_standards
    setup_rbac
    create_secrets_securely
    configure_resource_quotas
    setup_monitoring_and_auditing
    
    # OpenShift specific (if available)
    if kubectl get crd securitycontextconstraints.security.openshift.io &> /dev/null; then
        create_security_context_constraints
    fi
    
    # Validate configuration
    sleep 10
    validate_security_configuration
    
    # Run security scan
    run_security_scan
    
    log "🎉 Security hardening completed successfully!"
    info "Backup location: $backup_dir"
}

# Parse command line arguments
case "${1:-apply}" in
    apply)
        apply_security_hardening
        ;;
    validate)
        validate_security_configuration
        ;;
    scan)
        run_security_scan
        ;;
    backup)
        backup_security_configuration
        ;;
    *)
        echo "Usage: $0 [apply|validate|scan|backup]"
        exit 1
        ;;
esac