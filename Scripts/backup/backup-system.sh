#!/bin/bash
set -e

# Microsoft 365 Management Tools - Enterprise Backup & Disaster Recovery System
# Automated backup with Azure Storage, S3, and local storage support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
NAMESPACE="${NAMESPACE:-microsoft-365-tools}"
ENVIRONMENT="${ENVIRONMENT:-production}"
BACKUP_TYPE="${BACKUP_TYPE:-full}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Storage backends
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT}"
AZURE_STORAGE_KEY="${AZURE_STORAGE_KEY}"
AZURE_CONTAINER="${AZURE_CONTAINER:-m365-backups}"
AWS_S3_BUCKET="${AWS_S3_BUCKET}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
LOCAL_BACKUP_PATH="${LOCAL_BACKUP_PATH:-/app/backups}"

# Database configuration
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-microsoft365_tools}"
DB_USER="${DB_USER:-m365user}"
DB_PASSWORD="${DB_PASSWORD}"

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

# Usage information
usage() {
    cat << EOF
Microsoft 365 Management Tools - Backup & Disaster Recovery

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    backup          Create full backup
    backup-db       Backup database only
    backup-config   Backup configuration files
    backup-reports  Backup reports and data
    restore         Restore from backup
    list            List available backups
    cleanup         Clean up old backups
    verify          Verify backup integrity
    schedule        Setup automated backup schedule

Options:
    --type TYPE           Backup type: full, incremental, differential (default: full)
    --retention DAYS      Retention period in days (default: 30)
    --storage BACKEND     Storage backend: azure, s3, local (default: local)
    --exclude PATTERN     Exclude files matching pattern
    --encrypt             Enable encryption (requires GPG)
    --compress            Enable compression
    --verify              Verify backup after creation
    -h, --help           Show this help message

Examples:
    $0 backup --type full --storage azure --encrypt
    $0 restore --file backup-20240120-120000.tar.gz
    $0 list --storage s3
    $0 cleanup --retention 7

EOF
}

# Check prerequisites
check_prerequisites() {
    log "Checking backup prerequisites..."
    
    # Check required tools
    local tools=("tar" "gzip")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed"
            exit 1
        fi
    done
    
    # Check database tools
    if ! command -v pg_dump &> /dev/null; then
        warn "pg_dump not found, database backups will be disabled"
    fi
    
    # Check cloud storage tools
    if [[ "$STORAGE_BACKEND" == "azure" ]]; then
        if ! command -v az &> /dev/null; then
            error "Azure CLI not found for Azure storage backend"
            exit 1
        fi
    elif [[ "$STORAGE_BACKEND" == "s3" ]]; then
        if ! command -v aws &> /dev/null; then
            error "AWS CLI not found for S3 storage backend"
            exit 1
        fi
    fi
    
    # Check encryption tools
    if [[ "$ENCRYPT" == "true" ]]; then
        if ! command -v gpg &> /dev/null; then
            error "GPG not found for encryption"
            exit 1
        fi
    fi
    
    log "Prerequisites check completed"
}

# Create backup manifest
create_backup_manifest() {
    local backup_dir="$1"
    local manifest_file="$backup_dir/MANIFEST.json"
    
    cat > "$manifest_file" << EOF
{
  "backup_info": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "type": "$BACKUP_TYPE",
    "environment": "$ENVIRONMENT",
    "namespace": "$NAMESPACE",
    "version": "$(git describe --tags --always 2>/dev/null || echo 'unknown')",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
  },
  "components": {
    "database": $([ "$BACKUP_DATABASE" == "true" ] && echo "true" || echo "false"),
    "config": $([ "$BACKUP_CONFIG" == "true" ] && echo "true" || echo "false"),
    "reports": $([ "$BACKUP_REPORTS" == "true" ] && echo "true" || echo "false"),
    "logs": $([ "$BACKUP_LOGS" == "true" ] && echo "true" || echo "false")
  },
  "storage": {
    "backend": "$STORAGE_BACKEND",
    "encrypted": $([ "$ENCRYPT" == "true" ] && echo "true" || echo "false"),
    "compressed": $([ "$COMPRESS" == "true" ] && echo "true" || echo "false")
  },
  "checksums": {}
}
EOF
    
    echo "$manifest_file"
}

# Backup database
backup_database() {
    if [[ -z "$DB_PASSWORD" ]]; then
        warn "Database password not set, skipping database backup"
        return 0
    fi
    
    local backup_dir="$1"
    local db_backup_file="$backup_dir/database.sql"
    
    log "Backing up database: $DB_NAME"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    # Create database backup
    pg_dump \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --no-password \
        --verbose \
        --clean \
        --if-exists \
        --create \
        --format=plain \
        > "$db_backup_file"
    
    unset PGPASSWORD
    
    # Calculate checksum
    local checksum=$(sha256sum "$db_backup_file" | awk '{print $1}')
    info "Database backup checksum: $checksum"
    
    # Compress if requested
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$db_backup_file"
        db_backup_file="${db_backup_file}.gz"
    fi
    
    log "✅ Database backup completed: $db_backup_file"
    echo "$checksum"
}

# Backup configuration files
backup_config() {
    local backup_dir="$1"
    local config_backup_dir="$backup_dir/config"
    
    log "Backing up configuration files..."
    
    mkdir -p "$config_backup_dir"
    
    # Copy configuration files
    if [[ -d "$PROJECT_ROOT/Config" ]]; then
        cp -r "$PROJECT_ROOT/Config" "$config_backup_dir/"
    fi
    
    # Backup Kubernetes secrets and configmaps
    if command -v kubectl &> /dev/null; then
        kubectl get secrets -n "$NAMESPACE" -o yaml > "$config_backup_dir/secrets.yaml" 2>/dev/null || true
        kubectl get configmaps -n "$NAMESPACE" -o yaml > "$config_backup_dir/configmaps.yaml" 2>/dev/null || true
        kubectl get deployment m365-tools-deployment -n "$NAMESPACE" -o yaml > "$config_backup_dir/deployment.yaml" 2>/dev/null || true
    fi
    
    # Calculate checksum
    local checksum=$(find "$config_backup_dir" -type f -exec sha256sum {} \; | sha256sum | awk '{print $1}')
    
    log "✅ Configuration backup completed"
    echo "$checksum"
}

# Backup reports and data
backup_reports() {
    local backup_dir="$1"
    local reports_backup_dir="$backup_dir/reports"
    
    log "Backing up reports and data..."
    
    mkdir -p "$reports_backup_dir"
    
    # Copy reports directory
    if [[ -d "$PROJECT_ROOT/Reports" ]]; then
        # Only backup recent reports (last 30 days) to save space
        find "$PROJECT_ROOT/Reports" -type f -mtime -30 -exec cp --parents {} "$reports_backup_dir/" \;
    fi
    
    # Backup application data
    if [[ -d "/app/data" ]]; then
        cp -r "/app/data" "$reports_backup_dir/" 2>/dev/null || true
    fi
    
    # Calculate checksum
    local checksum=$(find "$reports_backup_dir" -type f -exec sha256sum {} \; | sha256sum | awk '{print $1}')
    
    log "✅ Reports backup completed"
    echo "$checksum"
}

# Backup logs
backup_logs() {
    local backup_dir="$1"
    local logs_backup_dir="$backup_dir/logs"
    
    log "Backing up application logs..."
    
    mkdir -p "$logs_backup_dir"
    
    # Copy recent logs (last 7 days)
    if [[ -d "/app/logs" ]]; then
        find "/app/logs" -type f -mtime -7 -exec cp --parents {} "$logs_backup_dir/" \;
    fi
    
    # Backup system logs if accessible
    if [[ -d "/var/log" ]]; then
        find "/var/log" -name "*m365*" -o -name "*microsoft365*" -mtime -7 -exec cp --parents {} "$logs_backup_dir/" \; 2>/dev/null || true
    fi
    
    # Calculate checksum
    local checksum=$(find "$logs_backup_dir" -type f -exec sha256sum {} \; | sha256sum | awk '{print $1}')
    
    log "✅ Logs backup completed"
    echo "$checksum"
}

# Encrypt backup
encrypt_backup() {
    local backup_file="$1"
    local encrypted_file="${backup_file}.gpg"
    
    log "Encrypting backup file..."
    
    # Use symmetric encryption with passphrase from environment
    local passphrase="${BACKUP_ENCRYPTION_KEY:-m365-backup-key-change-me}"
    
    gpg --batch --yes --passphrase "$passphrase" --symmetric --cipher-algo AES256 --output "$encrypted_file" "$backup_file"
    
    # Remove unencrypted file
    rm "$backup_file"
    
    log "✅ Backup encrypted: $encrypted_file"
    echo "$encrypted_file"
}

# Upload to Azure Storage
upload_to_azure() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    log "Uploading backup to Azure Storage..."
    
    # Authenticate with Azure
    if [[ -n "$AZURE_STORAGE_KEY" ]]; then
        export AZURE_STORAGE_ACCOUNT="$AZURE_STORAGE_ACCOUNT"
        export AZURE_STORAGE_KEY="$AZURE_STORAGE_KEY"
    fi
    
    # Upload file
    az storage blob upload \
        --container-name "$AZURE_CONTAINER" \
        --name "$filename" \
        --file "$backup_file" \
        --overwrite
    
    log "✅ Backup uploaded to Azure Storage: $filename"
}

# Upload to AWS S3
upload_to_s3() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    log "Uploading backup to AWS S3..."
    
    # Set AWS credentials
    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
    
    # Upload file
    aws s3 cp "$backup_file" "s3://$AWS_S3_BUCKET/$filename"
    
    log "✅ Backup uploaded to S3: $filename"
}

# Create full backup
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="m365-backup-${ENVIRONMENT}-${BACKUP_TYPE}-${timestamp}"
    local temp_backup_dir="/tmp/$backup_name"
    local final_backup_file="${LOCAL_BACKUP_PATH}/${backup_name}.tar.gz"
    
    log "🎯 Starting $BACKUP_TYPE backup: $backup_name"
    
    # Create temporary backup directory
    mkdir -p "$temp_backup_dir"
    mkdir -p "$LOCAL_BACKUP_PATH"
    
    # Create manifest
    local manifest_file=$(create_backup_manifest "$temp_backup_dir")
    
    # Backup components
    local checksums=()
    
    if [[ "$BACKUP_DATABASE" == "true" ]]; then
        local db_checksum=$(backup_database "$temp_backup_dir")
        checksums+=("database:$db_checksum")
    fi
    
    if [[ "$BACKUP_CONFIG" == "true" ]]; then
        local config_checksum=$(backup_config "$temp_backup_dir")
        checksums+=("config:$config_checksum")
    fi
    
    if [[ "$BACKUP_REPORTS" == "true" ]]; then
        local reports_checksum=$(backup_reports "$temp_backup_dir")
        checksums+=("reports:$reports_checksum")
    fi
    
    if [[ "$BACKUP_LOGS" == "true" ]]; then
        local logs_checksum=$(backup_logs "$temp_backup_dir")
        checksums+=("logs:$logs_checksum")
    fi
    
    # Update manifest with checksums
    for checksum_entry in "${checksums[@]}"; do
        local component="${checksum_entry%%:*}"
        local checksum="${checksum_entry##*:}"
        # Update manifest JSON (simplified approach)
        sed -i "s/\"checksums\": {}/\"checksums\": {\"$component\": \"$checksum\"}/" "$manifest_file"
    done
    
    # Create compressed archive
    log "Creating compressed archive..."
    tar -czf "$final_backup_file" -C "/tmp" "$backup_name"
    
    # Clean up temporary directory
    rm -rf "$temp_backup_dir"
    
    # Encrypt if requested
    if [[ "$ENCRYPT" == "true" ]]; then
        final_backup_file=$(encrypt_backup "$final_backup_file")
    fi
    
    # Calculate final checksum
    local final_checksum=$(sha256sum "$final_backup_file" | awk '{print $1}')
    info "Final backup checksum: $final_checksum"
    
    # Upload to cloud storage
    case "$STORAGE_BACKEND" in
        azure)
            upload_to_azure "$final_backup_file"
            ;;
        s3)
            upload_to_s3 "$final_backup_file"
            ;;
        local)
            log "✅ Backup stored locally: $final_backup_file"
            ;;
    esac
    
    # Verify backup if requested
    if [[ "$VERIFY_BACKUP" == "true" ]]; then
        verify_backup "$final_backup_file"
    fi
    
    log "🎉 Backup completed successfully: $final_backup_file"
    echo "$final_backup_file"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    log "Verifying backup integrity..."
    
    # Test archive
    if [[ "$backup_file" == *.tar.gz ]]; then
        tar -tzf "$backup_file" > /dev/null
        log "✅ Archive integrity verified"
    fi
    
    # Test encryption if applicable
    if [[ "$backup_file" == *.gpg ]]; then
        local passphrase="${BACKUP_ENCRYPTION_KEY:-m365-backup-key-change-me}"
        gpg --batch --yes --passphrase "$passphrase" --decrypt "$backup_file" > /dev/null 2>&1
        log "✅ Encryption integrity verified"
    fi
}

# List available backups
list_backups() {
    log "Listing available backups..."
    
    case "$STORAGE_BACKEND" in
        azure)
            az storage blob list --container-name "$AZURE_CONTAINER" --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" --output table
            ;;
        s3)
            aws s3 ls "s3://$AWS_S3_BUCKET/" --human-readable --summarize
            ;;
        local)
            if [[ -d "$LOCAL_BACKUP_PATH" ]]; then
                ls -lah "$LOCAL_BACKUP_PATH"/m365-backup-*
            else
                warn "No local backup directory found"
            fi
            ;;
    esac
}

# Cleanup old backups
cleanup_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    case "$STORAGE_BACKEND" in
        azure)
            # Azure cleanup would require more complex script
            warn "Azure cleanup not implemented yet"
            ;;
        s3)
            # S3 lifecycle policies are recommended for cleanup
            warn "S3 cleanup should be configured via lifecycle policies"
            ;;
        local)
            if [[ -d "$LOCAL_BACKUP_PATH" ]]; then
                find "$LOCAL_BACKUP_PATH" -name "m365-backup-*" -mtime +$RETENTION_DAYS -delete
                log "✅ Local backup cleanup completed"
            fi
            ;;
    esac
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        error "Backup file not specified"
        exit 1
    fi
    
    log "🔄 Starting restore from: $backup_file"
    
    # Download backup if from cloud storage
    local local_backup_file="$backup_file"
    if [[ "$backup_file" != /* ]]; then
        # Assume it's a cloud backup
        local_backup_file="/tmp/$(basename "$backup_file")"
        
        case "$STORAGE_BACKEND" in
            azure)
                az storage blob download --container-name "$AZURE_CONTAINER" --name "$backup_file" --file "$local_backup_file"
                ;;
            s3)
                aws s3 cp "s3://$AWS_S3_BUCKET/$backup_file" "$local_backup_file"
                ;;
        esac
    fi
    
    # Decrypt if necessary
    if [[ "$local_backup_file" == *.gpg ]]; then
        log "Decrypting backup..."
        local passphrase="${BACKUP_ENCRYPTION_KEY:-m365-backup-key-change-me}"
        local decrypted_file="${local_backup_file%.gpg}"
        gpg --batch --yes --passphrase "$passphrase" --decrypt "$local_backup_file" > "$decrypted_file"
        local_backup_file="$decrypted_file"
    fi
    
    # Extract backup
    local restore_dir="/tmp/restore-$(date +%s)"
    mkdir -p "$restore_dir"
    tar -xzf "$local_backup_file" -C "$restore_dir"
    
    # Find the extracted backup directory
    local backup_dir=$(find "$restore_dir" -maxdepth 1 -type d -name "m365-backup-*" | head -1)
    
    if [[ -z "$backup_dir" ]]; then
        error "Backup directory not found in archive"
        exit 1
    fi
    
    # Read manifest
    if [[ -f "$backup_dir/MANIFEST.json" ]]; then
        info "Backup manifest found:"
        cat "$backup_dir/MANIFEST.json"
    fi
    
    # Restore database
    if [[ -f "$backup_dir/database.sql" || -f "$backup_dir/database.sql.gz" ]]; then
        warn "Database restore requires manual intervention"
        info "Database backup location: $backup_dir/database.sql*"
    fi
    
    # Restore configuration
    if [[ -d "$backup_dir/config" ]]; then
        log "Configuration files available for restore in: $backup_dir/config"
    fi
    
    # Restore reports
    if [[ -d "$backup_dir/reports" ]]; then
        log "Reports available for restore in: $backup_dir/reports"
    fi
    
    log "🎉 Restore preparation completed. Files extracted to: $backup_dir"
    info "Manual intervention may be required for database and configuration restore"
}

# Setup backup schedule
setup_schedule() {
    log "Setting up automated backup schedule..."
    
    # Create cron job for daily backups
    local cron_job="0 2 * * * $0 backup --type full --storage $STORAGE_BACKEND --compress --verify"
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    log "✅ Backup schedule configured: Daily at 2 AM"
}

# Parse command line arguments
COMMAND=""
STORAGE_BACKEND="local"
ENCRYPT="false"
COMPRESS="false"
VERIFY_BACKUP="false"
BACKUP_DATABASE="true"
BACKUP_CONFIG="true"
BACKUP_REPORTS="true"
BACKUP_LOGS="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        backup|backup-db|backup-config|backup-reports|restore|list|cleanup|verify|schedule)
            COMMAND="$1"
            shift
            ;;
        --type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --storage)
            STORAGE_BACKEND="$2"
            shift 2
            ;;
        --file)
            BACKUP_FILE="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_PATTERN="$2"
            shift 2
            ;;
        --encrypt)
            ENCRYPT="true"
            shift
            ;;
        --compress)
            COMPRESS="true"
            shift
            ;;
        --verify)
            VERIFY_BACKUP="true"
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
    log "💾 Microsoft 365 Management Tools - Backup & DR System"
    log "=================================================="
    
    info "Configuration:"
    info "  Environment: $ENVIRONMENT"
    info "  Namespace: $NAMESPACE"
    info "  Storage Backend: $STORAGE_BACKEND"
    info "  Backup Type: $BACKUP_TYPE"
    info "  Retention: $RETENTION_DAYS days"
    
    check_prerequisites
    
    case "$COMMAND" in
        backup)
            create_backup
            ;;
        backup-db)
            BACKUP_DATABASE="true"
            BACKUP_CONFIG="false"
            BACKUP_REPORTS="false"
            BACKUP_LOGS="false"
            create_backup
            ;;
        backup-config)
            BACKUP_DATABASE="false"
            BACKUP_CONFIG="true"
            BACKUP_REPORTS="false"
            BACKUP_LOGS="false"
            create_backup
            ;;
        backup-reports)
            BACKUP_DATABASE="false"
            BACKUP_CONFIG="false"
            BACKUP_REPORTS="true"
            BACKUP_LOGS="false"
            create_backup
            ;;
        restore)
            restore_backup "$BACKUP_FILE"
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_backups
            ;;
        verify)
            if [[ -n "$BACKUP_FILE" ]]; then
                verify_backup "$BACKUP_FILE"
            else
                error "Backup file not specified for verification"
                exit 1
            fi
            ;;
        schedule)
            setup_schedule
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
    
    log "🎉 Backup operation completed successfully!"
}

# Execute main function
main "$@"