#!/bin/bash
set -e

# Microsoft 365 Management Tools - Certificate Management Script
# Enterprise-grade SSL/TLS certificate automation with Let's Encrypt and Azure Key Vault integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
DOMAIN="${DOMAIN:-microsoft365tools.company.com}"
EMAIL="${CERT_EMAIL:-admin@company.com}"
ENVIRONMENT="${ENVIRONMENT:-production}"
CERT_PATH="${CERT_PATH:-/etc/ssl/certs}"
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-/etc/ssl/private}"
NAMESPACE="${NAMESPACE:-microsoft-365-tools}"

# Azure Key Vault configuration
KEYVAULT_NAME="${KEYVAULT_NAME:-m365-tools-kv}"
AZURE_TENANT_ID="${AZURE_TENANT_ID}"
AZURE_CLIENT_ID="${AZURE_CLIENT_ID}"
AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET}"

# Let's Encrypt configuration
ACME_SERVER="${ACME_SERVER:-https://acme-v02.api.letsencrypt.org/directory}"
if [[ "$ENVIRONMENT" == "staging" ]]; then
    ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
fi

# Colors for output
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
Microsoft 365 Management Tools - Certificate Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    generate        Generate new SSL certificate
    renew          Renew existing certificate
    install        Install certificate to Kubernetes
    check          Check certificate status
    backup         Backup certificates to Azure Key Vault
    restore        Restore certificates from Azure Key Vault
    rotate         Rotate all certificates

Options:
    -d, --domain DOMAIN        Domain name (default: microsoft365tools.company.com)
    -e, --email EMAIL          Email for Let's Encrypt (default: admin@company.com)
    -n, --namespace NAMESPACE  Kubernetes namespace (default: microsoft-365-tools)
    -s, --staging              Use Let's Encrypt staging environment
    -f, --force                Force certificate generation/renewal
    -h, --help                 Show this help message

Examples:
    $0 generate --domain microsoft365tools.company.com
    $0 renew --force
    $0 install --namespace production
    $0 check

EOF
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    local tools=("openssl" "kubectl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed"
            exit 1
        fi
    done
    
    # Check certbot for Let's Encrypt
    if ! command -v certbot &> /dev/null; then
        warn "certbot not found, installing..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y certbot
        elif command -v yum &> /dev/null; then
            sudo yum install -y certbot
        else
            error "Cannot install certbot automatically. Please install manually."
            exit 1
        fi
    fi
    
    # Check Azure CLI if Key Vault is configured
    if [[ -n "$KEYVAULT_NAME" ]]; then
        if ! command -v az &> /dev/null; then
            warn "Azure CLI not found, Key Vault features will be disabled"
        else
            log "Azure CLI found, Key Vault integration available"
        fi
    fi
    
    log "Prerequisites check completed"
}

# Azure authentication
azure_login() {
    if [[ -z "$AZURE_TENANT_ID" || -z "$AZURE_CLIENT_ID" || -z "$AZURE_CLIENT_SECRET" ]]; then
        warn "Azure credentials not configured, skipping Azure integration"
        return 1
    fi
    
    log "Authenticating with Azure..."
    az login --service-principal \
        --username "$AZURE_CLIENT_ID" \
        --password "$AZURE_CLIENT_SECRET" \
        --tenant "$AZURE_TENANT_ID" &> /dev/null
    
    log "Azure authentication successful"
    return 0
}

# Generate self-signed certificate (development)
generate_self_signed() {
    log "Generating self-signed certificate for development..."
    
    local cert_dir="/tmp/certs"
    mkdir -p "$cert_dir"
    
    # Generate private key
    openssl genrsa -out "$cert_dir/tls.key" 2048
    
    # Generate certificate
    openssl req -new -x509 -key "$cert_dir/tls.key" -out "$cert_dir/tls.crt" -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
    
    echo "$cert_dir"
}

# Generate Let's Encrypt certificate
generate_letsencrypt() {
    log "Generating Let's Encrypt certificate for $DOMAIN..."
    
    local staging_flag=""
    if [[ "$ENVIRONMENT" == "staging" ]]; then
        staging_flag="--staging"
    fi
    
    # Use DNS challenge for wildcard certificates
    if [[ "$DOMAIN" == *"*"* ]]; then
        log "Wildcard domain detected, using DNS challenge..."
        certbot certonly \
            --manual \
            --preferred-challenges=dns \
            --email "$EMAIL" \
            --server "$ACME_SERVER" \
            --agree-tos \
            --no-eff-email \
            -d "$DOMAIN" \
            $staging_flag
    else
        # Use HTTP challenge for regular domains
        log "Using HTTP challenge for domain verification..."
        certbot certonly \
            --standalone \
            --email "$EMAIL" \
            --server "$ACME_SERVER" \
            --agree-tos \
            --no-eff-email \
            -d "$DOMAIN" \
            $staging_flag
    fi
    
    # Copy certificates to standard location
    local cert_dir="/tmp/certs"
    mkdir -p "$cert_dir"
    
    local domain_clean="${DOMAIN//\*/wildcard}"
    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$cert_dir/tls.crt"
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$cert_dir/tls.key"
    
    log "Let's Encrypt certificate generated successfully"
    echo "$cert_dir"
}

# Install certificate to Kubernetes
install_to_kubernetes() {
    local cert_dir="$1"
    
    log "Installing certificate to Kubernetes namespace: $NAMESPACE..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Delete existing secret if it exists
    kubectl delete secret m365-tools-tls -n "$NAMESPACE" 2>/dev/null || true
    
    # Create TLS secret
    kubectl create secret tls m365-tools-tls \
        --cert="$cert_dir/tls.crt" \
        --key="$cert_dir/tls.key" \
        -n "$NAMESPACE"
    
    # Add labels and annotations
    kubectl label secret m365-tools-tls \
        app=m365-tools \
        component=tls \
        environment="$ENVIRONMENT" \
        -n "$NAMESPACE"
    
    kubectl annotate secret m365-tools-tls \
        "cert-manager.io/issuer"="letsencrypt-${ENVIRONMENT}" \
        "kubernetes.io/managed-by"="certificate-manager" \
        "last-updated"="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        -n "$NAMESPACE"
    
    log "Certificate installed to Kubernetes successfully"
}

# Backup certificates to Azure Key Vault
backup_to_keyvault() {
    if ! azure_login; then
        warn "Skipping Key Vault backup - Azure not configured"
        return 0
    fi
    
    local cert_dir="$1"
    
    log "Backing up certificates to Azure Key Vault: $KEYVAULT_NAME..."
    
    # Upload certificate
    az keyvault certificate import \
        --vault-name "$KEYVAULT_NAME" \
        --name "m365-tools-${ENVIRONMENT}" \
        --file "$cert_dir/tls.crt" \
        --policy '{
            "keyProperties": {
                "exportable": true,
                "keyType": "RSA",
                "keySize": 2048,
                "reuseKey": false
            },
            "secretProperties": {
                "contentType": "application/x-pkcs12"
            }
        }' || warn "Certificate backup failed"
    
    # Upload private key as secret
    az keyvault secret set \
        --vault-name "$KEYVAULT_NAME" \
        --name "m365-tools-${ENVIRONMENT}-key" \
        --file "$cert_dir/tls.key" || warn "Private key backup failed"
    
    log "Certificate backup completed"
}

# Restore certificates from Azure Key Vault
restore_from_keyvault() {
    if ! azure_login; then
        error "Azure not configured for Key Vault restore"
        exit 1
    fi
    
    log "Restoring certificates from Azure Key Vault: $KEYVAULT_NAME..."
    
    local cert_dir="/tmp/certs"
    mkdir -p "$cert_dir"
    
    # Download certificate
    az keyvault certificate download \
        --vault-name "$KEYVAULT_NAME" \
        --name "m365-tools-${ENVIRONMENT}" \
        --file "$cert_dir/tls.crt" \
        --encoding PEM
    
    # Download private key
    az keyvault secret download \
        --vault-name "$KEYVAULT_NAME" \
        --name "m365-tools-${ENVIRONMENT}-key" \
        --file "$cert_dir/tls.key"
    
    log "Certificate restored from Key Vault"
    echo "$cert_dir"
}

# Check certificate status
check_certificate() {
    log "Checking certificate status..."
    
    # Check Kubernetes secret
    if kubectl get secret m365-tools-tls -n "$NAMESPACE" &> /dev/null; then
        log "✅ Certificate secret exists in Kubernetes"
        
        # Get certificate details
        kubectl get secret m365-tools-tls -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | \
            base64 -d | openssl x509 -noout -dates -subject -issuer
    else
        warn "❌ Certificate secret not found in Kubernetes"
    fi
    
    # Check Let's Encrypt certificates
    if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
        log "✅ Let's Encrypt certificate found"
        openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" -noout -dates -subject -issuer
    else
        warn "❌ Let's Encrypt certificate not found"
    fi
    
    # Check Azure Key Vault
    if azure_login; then
        if az keyvault certificate show --vault-name "$KEYVAULT_NAME" --name "m365-tools-${ENVIRONMENT}" &> /dev/null; then
            log "✅ Certificate backup found in Azure Key Vault"
        else
            warn "❌ Certificate backup not found in Azure Key Vault"
        fi
    fi
}

# Renew certificate
renew_certificate() {
    log "Renewing certificate for $DOMAIN..."
    
    # Check if renewal is needed
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        local expiry_date=$(openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" -noout -enddate | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        info "Certificate expires in $days_until_expiry days"
        
        if [[ $days_until_expiry -gt 30 && "$FORCE" != "true" ]]; then
            log "Certificate does not need renewal yet (>30 days remaining)"
            return 0
        fi
    fi
    
    # Renew with certbot
    certbot renew --force-renewal
    
    # Reinstall to Kubernetes
    local cert_dir="/tmp/certs"
    mkdir -p "$cert_dir"
    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$cert_dir/tls.crt"
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$cert_dir/tls.key"
    
    install_to_kubernetes "$cert_dir"
    backup_to_keyvault "$cert_dir"
    
    # Restart deployment to pick up new certificate
    kubectl rollout restart deployment/m365-tools-deployment -n "$NAMESPACE" || true
    
    log "Certificate renewal completed"
}

# Generate new certificate
generate_certificate() {
    log "Starting certificate generation process..."
    
    local cert_dir=""
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        cert_dir=$(generate_self_signed)
    else
        cert_dir=$(generate_letsencrypt)
    fi
    
    install_to_kubernetes "$cert_dir"
    backup_to_keyvault "$cert_dir"
    
    # Clean up temporary files
    rm -rf "$cert_dir"
    
    log "Certificate generation completed successfully"
}

# Rotate all certificates
rotate_certificates() {
    log "Starting certificate rotation process..."
    
    # Backup current certificates
    if kubectl get secret m365-tools-tls -n "$NAMESPACE" &> /dev/null; then
        kubectl get secret m365-tools-tls -n "$NAMESPACE" -o yaml > "/tmp/m365-tls-backup-$(date +%Y%m%d-%H%M%S).yaml"
        log "Current certificate backed up"
    fi
    
    # Generate new certificate
    generate_certificate
    
    # Verify new certificate
    sleep 10
    check_certificate
    
    log "Certificate rotation completed"
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        generate|renew|install|check|backup|restore|rotate)
            COMMAND="$1"
            shift
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -s|--staging)
            ENVIRONMENT="staging"
            shift
            ;;
        -f|--force)
            FORCE="true"
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
    log "🔐 Microsoft 365 Management Tools - Certificate Manager"
    log "=================================================="
    
    info "Configuration:"
    info "  Domain: $DOMAIN"
    info "  Email: $EMAIL"
    info "  Environment: $ENVIRONMENT"
    info "  Namespace: $NAMESPACE"
    info "  Key Vault: ${KEYVAULT_NAME:-not configured}"
    
    check_prerequisites
    
    case "$COMMAND" in
        generate)
            generate_certificate
            ;;
        renew)
            renew_certificate
            ;;
        install)
            local cert_dir="${1:-/tmp/certs}"
            if [[ ! -d "$cert_dir" ]]; then
                error "Certificate directory not found: $cert_dir"
                exit 1
            fi
            install_to_kubernetes "$cert_dir"
            ;;
        check)
            check_certificate
            ;;
        backup)
            local cert_dir="${1:-/tmp/certs}"
            backup_to_keyvault "$cert_dir"
            ;;
        restore)
            local cert_dir=$(restore_from_keyvault)
            install_to_kubernetes "$cert_dir"
            ;;
        rotate)
            rotate_certificates
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
    
    log "🎉 Certificate management completed successfully!"
}

# Execute main function
main "$@"