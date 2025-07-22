#!/bin/bash
set -e

# Microsoft 365 Management Tools - Advanced Security Scanner
# Enterprise-grade security vulnerability scanning with SAST/DAST/SCA integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
SCAN_TYPE="${SCAN_TYPE:-full}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-medium}"
COMPLIANCE_STANDARDS="${COMPLIANCE_STANDARDS:-iso27001,owasp}"

# Scan categories
ENABLE_SAST="${ENABLE_SAST:-true}"        # Static Application Security Testing
ENABLE_DAST="${ENABLE_DAST:-false}"       # Dynamic Application Security Testing
ENABLE_SCA="${ENABLE_SCA:-true}"          # Software Composition Analysis
ENABLE_SECRET_SCAN="${ENABLE_SECRET_SCAN:-true}"
ENABLE_CONTAINER_SCAN="${ENABLE_CONTAINER_SCAN:-true}"
ENABLE_INFRASTRUCTURE_SCAN="${ENABLE_INFRASTRUCTURE_SCAN:-true}"

# Output directories
SECURITY_DIR="${PROJECT_ROOT}/TestScripts/TestReports/security-advanced"
SAST_DIR="${SECURITY_DIR}/sast"
DAST_DIR="${SECURITY_DIR}/dast"
SCA_DIR="${SECURITY_DIR}/sca"
SECRETS_DIR="${SECURITY_DIR}/secrets"
CONTAINER_DIR="${SECURITY_DIR}/containers"
INFRASTRUCTURE_DIR="${SECURITY_DIR}/infrastructure"

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

# Initialize security environment
init_security_environment() {
    log "Initializing advanced security scanning environment..."
    
    # Create output directories
    mkdir -p "$SECURITY_DIR" "$SAST_DIR" "$DAST_DIR" "$SCA_DIR" "$SECRETS_DIR" "$CONTAINER_DIR" "$INFRASTRUCTURE_DIR"
    
    # Clean up old reports (keep last 30 days)
    find "$SECURITY_DIR" -name "*.json" -mtime +30 -delete 2>/dev/null || true
    find "$SECURITY_DIR" -name "*.xml" -mtime +30 -delete 2>/dev/null || true
    find "$SECURITY_DIR" -name "*.html" -mtime +30 -delete 2>/dev/null || true
    
    # Install required tools if missing
    install_security_tools
    
    log "Security environment initialized"
}

# Install security tools
install_security_tools() {
    log "Checking and installing security tools..."
    
    # Bandit (Python SAST)
    if ! command -v bandit &> /dev/null; then
        pip install bandit[toml] || warn "Failed to install bandit"
    fi
    
    # Safety (Python SCA)
    if ! command -v safety &> /dev/null; then
        pip install safety || warn "Failed to install safety"
    fi
    
    # Semgrep (Multi-language SAST)
    if ! command -v semgrep &> /dev/null; then
        pip install semgrep || warn "Failed to install semgrep"
    fi
    
    # GitLeaks (Secret scanning)
    if ! command -v gitleaks &> /dev/null; then
        if command -v curl &> /dev/null; then
            curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sh -s -- -b /usr/local/bin || warn "Failed to install gitleaks"
        fi
    fi
    
    # Trivy (Container/Infrastructure scanning)
    if ! command -v trivy &> /dev/null; then
        if command -v curl &> /dev/null; then
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin || warn "Failed to install trivy"
        fi
    fi
    
    # Checkov (Infrastructure as Code scanning)
    if ! command -v checkov &> /dev/null; then
        pip install checkov || warn "Failed to install checkov"
    fi
    
    log "Security tools check completed"
}

# SAST (Static Application Security Testing)
run_sast_scan() {
    if [[ "$ENABLE_SAST" != "true" ]]; then
        log "SAST scanning disabled"
        return 0
    fi
    
    log "Running SAST (Static Application Security Testing)..."
    
    local sast_issues=0
    
    # Bandit - Python security analysis
    if find "$PROJECT_ROOT" -name "*.py" -not -path "*/venv/*" -not -path "*/.pytest_cache/*" | head -1 | grep -q .; then
        log "Running Bandit Python security analysis..."
        
        bandit -r "$PROJECT_ROOT" \
            -f json \
            -o "$SAST_DIR/bandit-detailed.json" \
            --severity-level low \
            --confidence-level low \
            --exclude "**/venv/**,**/.pytest_cache/**,**/node_modules/**" \
            || ((sast_issues++))
        
        # Generate summary
        if [ -f "$SAST_DIR/bandit-detailed.json" ]; then
            python3 << EOF > "$SAST_DIR/bandit-summary.json"
import json
with open('$SAST_DIR/bandit-detailed.json', 'r') as f:
    data = json.load(f)
    
summary = {
    'tool': 'bandit',
    'total_issues': len(data.get('results', [])),
    'high_severity': len([r for r in data.get('results', []) if r.get('issue_severity') == 'HIGH']),
    'medium_severity': len([r for r in data.get('results', []) if r.get('issue_severity') == 'MEDIUM']),
    'low_severity': len([r for r in data.get('results', []) if r.get('issue_severity') == 'LOW']),
    'files_scanned': len(data.get('metrics', {}).get('_totals', {}).get('SLOC', 0))
}

print(json.dumps(summary, indent=2))
EOF
        fi
    fi
    
    # Semgrep - Multi-language SAST
    log "Running Semgrep multi-language security analysis..."
    
    semgrep \
        --config=auto \
        --config=security-audit \
        --config=owasp-top-ten \
        --json \
        --output="$SAST_DIR/semgrep-detailed.json" \
        --severity=ERROR \
        --severity=WARNING \
        --timeout=300 \
        "$PROJECT_ROOT" \
        || ((sast_issues++))
    
    # Generate Semgrep summary
    if [ -f "$SAST_DIR/semgrep-detailed.json" ]; then
        jq '{
            tool: "semgrep",
            total_issues: (.results | length),
            critical_issues: (.results | map(select(.extra.severity == "ERROR")) | length),
            warning_issues: (.results | map(select(.extra.severity == "WARNING")) | length),
            rules_applied: (.rules | length)
        }' "$SAST_DIR/semgrep-detailed.json" > "$SAST_DIR/semgrep-summary.json"
    fi
    
    # PowerShell Script Analyzer
    log "Running PowerShell Script Analyzer..."
    
    pwsh -Command "
        if (Get-Module -ListAvailable PSScriptAnalyzer) {
            Import-Module PSScriptAnalyzer
            \$results = Get-ChildItem '$PROJECT_ROOT' -Recurse -Include '*.ps1' | Invoke-ScriptAnalyzer -Severity @('Error', 'Warning', 'Information')
            
            \$summary = @{
                tool = 'PSScriptAnalyzer'
                total_issues = \$results.Count
                error_issues = (\$results | Where-Object Severity -eq 'Error').Count
                warning_issues = (\$results | Where-Object Severity -eq 'Warning').Count
                info_issues = (\$results | Where-Object Severity -eq 'Information').Count
                files_scanned = (Get-ChildItem '$PROJECT_ROOT' -Recurse -Include '*.ps1').Count
            }
            
            \$results | Export-Csv -Path '$SAST_DIR/powershell-detailed.csv' -NoTypeInformation
            \$summary | ConvertTo-Json | Out-File '$SAST_DIR/powershell-summary.json' -Encoding UTF8
        } else {
            Write-Warning 'PSScriptAnalyzer not available'
        }
    "
    
    # CodeQL (if available)
    if command -v codeql &> /dev/null; then
        log "Running CodeQL security analysis..."
        
        codeql database create "$SAST_DIR/codeql-db" \
            --language=python,javascript \
            --source-root="$PROJECT_ROOT" \
            --overwrite \
            || warn "CodeQL database creation failed"
        
        if [ -d "$SAST_DIR/codeql-db" ]; then
            codeql database analyze "$SAST_DIR/codeql-db" \
                --format=sarif-latest \
                --output="$SAST_DIR/codeql-results.sarif" \
                security-and-quality \
                || warn "CodeQL analysis failed"
        fi
    fi
    
    log "SAST scanning completed with $sast_issues issues"
    return $sast_issues
}

# SCA (Software Composition Analysis)
run_sca_scan() {
    if [[ "$ENABLE_SCA" != "true" ]]; then
        log "SCA scanning disabled"
        return 0
    fi
    
    log "Running SCA (Software Composition Analysis)..."
    
    local sca_issues=0
    
    # Safety - Python dependency vulnerability scanning
    log "Running Safety Python dependency scan..."
    
    safety check \
        --json \
        --output "$SCA_DIR/safety-detailed.json" \
        --full-report \
        || ((sca_issues++))
    
    # Generate Safety summary
    if [ -f "$SCA_DIR/safety-detailed.json" ]; then
        jq '{
            tool: "safety",
            total_vulnerabilities: (if type == "array" then length else 0 end),
            scan_timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }' "$SCA_DIR/safety-detailed.json" > "$SCA_DIR/safety-summary.json"
    fi
    
    # npm audit (if Node.js project exists)
    if [ -f "$PROJECT_ROOT/frontend/package.json" ]; then
        log "Running npm audit for JavaScript dependencies..."
        
        cd "$PROJECT_ROOT/frontend"
        npm audit --audit-level=low --json > "$SCA_DIR/npm-audit-detailed.json" || ((sca_issues++))
        
        # Generate npm audit summary
        if [ -f "$SCA_DIR/npm-audit-detailed.json" ]; then
            jq '{
                tool: "npm-audit",
                total_vulnerabilities: (.metadata.vulnerabilities.total // 0),
                critical: (.metadata.vulnerabilities.critical // 0),
                high: (.metadata.vulnerabilities.high // 0),
                moderate: (.metadata.vulnerabilities.moderate // 0),
                low: (.metadata.vulnerabilities.low // 0),
                info: (.metadata.vulnerabilities.info // 0)
            }' "$SCA_DIR/npm-audit-detailed.json" > "$SCA_DIR/npm-audit-summary.json"
        fi
        cd "$PROJECT_ROOT"
    fi
    
    # Snyk (if available)
    if command -v snyk &> /dev/null; then
        log "Running Snyk vulnerability scan..."
        
        snyk test \
            --json \
            --file="$PROJECT_ROOT/requirements.txt" \
            > "$SCA_DIR/snyk-detailed.json" || ((sca_issues++))
        
        # Generate Snyk summary
        if [ -f "$SCA_DIR/snyk-detailed.json" ]; then
            jq '{
                tool: "snyk",
                total_issues: (.vulnerabilities | length),
                high_severity: (.vulnerabilities | map(select(.severity == "high")) | length),
                medium_severity: (.vulnerabilities | map(select(.severity == "medium")) | length),
                low_severity: (.vulnerabilities | map(select(.severity == "low")) | length)
            }' "$SCA_DIR/snyk-detailed.json" > "$SCA_DIR/snyk-summary.json"
        fi
    fi
    
    log "SCA scanning completed with $sca_issues issues"
    return $sca_issues
}

# Secret scanning
run_secret_scan() {
    if [[ "$ENABLE_SECRET_SCAN" != "true" ]]; then
        log "Secret scanning disabled"
        return 0
    fi
    
    log "Running secret scanning..."
    
    local secret_issues=0
    
    # GitLeaks secret scanning
    if command -v gitleaks &> /dev/null; then
        log "Running GitLeaks secret detection..."
        
        gitleaks detect \
            --source="$PROJECT_ROOT" \
            --report-path="$SECRETS_DIR/gitleaks-detailed.json" \
            --report-format=json \
            --verbose \
            || ((secret_issues++))
        
        # Generate GitLeaks summary
        if [ -f "$SECRETS_DIR/gitleaks-detailed.json" ]; then
            jq '{
                tool: "gitleaks",
                total_secrets: length,
                files_with_secrets: [.[].File] | unique | length,
                secret_types: [.[].RuleID] | unique
            }' "$SECRETS_DIR/gitleaks-detailed.json" > "$SECRETS_DIR/gitleaks-summary.json"
        fi
    fi
    
    # TruffleHog (if available)
    if command -v trufflehog &> /dev/null; then
        log "Running TruffleHog secret detection..."
        
        trufflehog filesystem "$PROJECT_ROOT" \
            --json \
            --only-verified \
            > "$SECRETS_DIR/trufflehog-detailed.json" || ((secret_issues++))
    fi
    
    # Custom secret patterns
    log "Running custom secret pattern detection..."
    
    cat > "$SECRETS_DIR/custom-patterns.txt" << 'EOF'
# API Keys and Tokens
AKIAI[0-9A-Z]{16}
AKIA[0-9A-Z]{16}
sk-[a-zA-Z0-9]{48}
xoxb-[0-9]{11}-[0-9]{11}-[a-zA-Z0-9]{24}
glpat-[a-zA-Z0-9\-_]{20}

# Microsoft specific
[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}

# Database connections
mongodb://[^/\s]+
postgresql://[^/\s]+
mysql://[^/\s]+

# Private keys
-----BEGIN PRIVATE KEY-----
-----BEGIN RSA PRIVATE KEY-----
-----BEGIN OPENSSH PRIVATE KEY-----
EOF
    
    # Scan using grep
    grep -r -f "$SECRETS_DIR/custom-patterns.txt" "$PROJECT_ROOT" \
        --exclude-dir=".git" \
        --exclude-dir="node_modules" \
        --exclude-dir="venv" \
        --exclude-dir=".pytest_cache" \
        --include="*.py" \
        --include="*.js" \
        --include="*.ts" \
        --include="*.ps1" \
        --include="*.json" \
        --include="*.yaml" \
        --include="*.yml" \
        > "$SECRETS_DIR/custom-secrets.txt" || true
    
    # Convert to JSON format
    if [ -s "$SECRETS_DIR/custom-secrets.txt" ]; then
        python3 << EOF > "$SECRETS_DIR/custom-secrets.json"
import json
secrets = []
with open('$SECRETS_DIR/custom-secrets.txt', 'r') as f:
    for line in f:
        if ':' in line:
            file_path, content = line.strip().split(':', 1)
            secrets.append({
                'file': file_path,
                'content': content,
                'type': 'custom_pattern'
            })

print(json.dumps({
    'tool': 'custom_patterns',
    'total_matches': len(secrets),
    'matches': secrets
}, indent=2))
EOF
        ((secret_issues++))
    else
        echo '{"tool": "custom_patterns", "total_matches": 0, "matches": []}' > "$SECRETS_DIR/custom-secrets.json"
    fi
    
    log "Secret scanning completed with $secret_issues issues"
    return $secret_issues
}

# Container security scanning
run_container_scan() {
    if [[ "$ENABLE_CONTAINER_SCAN" != "true" ]]; then
        log "Container scanning disabled"
        return 0
    fi
    
    log "Running container security scanning..."
    
    local container_issues=0
    
    # Trivy container scanning
    if command -v trivy &> /dev/null; then
        # Scan Dockerfile
        if [ -f "$PROJECT_ROOT/Dockerfile" ]; then
            log "Scanning Dockerfile with Trivy..."
            
            trivy config "$PROJECT_ROOT/Dockerfile" \
                --format json \
                --output "$CONTAINER_DIR/dockerfile-scan.json" \
                || ((container_issues++))
        fi
        
        # Scan container image (if built)
        local image_name="${CONTAINER_IMAGE:-microsoft365tools:latest}"
        if docker images | grep -q "${image_name%:*}"; then
            log "Scanning container image: $image_name"
            
            trivy image "$image_name" \
                --format json \
                --output "$CONTAINER_DIR/image-scan.json" \
                --severity HIGH,CRITICAL \
                || ((container_issues++))
            
            # Generate image scan summary
            if [ -f "$CONTAINER_DIR/image-scan.json" ]; then
                jq '{
                    tool: "trivy",
                    scan_type: "image",
                    image: .ArtifactName,
                    total_vulnerabilities: ([.Results[]?.Vulnerabilities[]?] | length),
                    critical: ([.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length),
                    high: ([.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length),
                    medium: ([.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length),
                    low: ([.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length)
                }' "$CONTAINER_DIR/image-scan.json" > "$CONTAINER_DIR/image-scan-summary.json"
            fi
        fi
    fi
    
    # Docker bench security (if available)
    if command -v docker-bench-security &> /dev/null; then
        log "Running Docker Bench Security..."
        
        docker run --rm \
            --net host \
            --pid host \
            --userns host \
            --cap-add audit_control \
            -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
            -v /var/lib:/var/lib:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            -v /usr/lib/systemd:/usr/lib/systemd:ro \
            -v /etc:/etc:ro \
            docker/docker-bench-security \
            > "$CONTAINER_DIR/docker-bench-security.txt" || ((container_issues++))
    fi
    
    log "Container scanning completed with $container_issues issues"
    return $container_issues
}

# Infrastructure security scanning
run_infrastructure_scan() {
    if [[ "$ENABLE_INFRASTRUCTURE_SCAN" != "true" ]]; then
        log "Infrastructure scanning disabled"
        return 0
    fi
    
    log "Running infrastructure security scanning..."
    
    local infra_issues=0
    
    # Checkov - Infrastructure as Code scanning
    if command -v checkov &> /dev/null; then
        log "Running Checkov IaC security scan..."
        
        checkov \
            --directory "$PROJECT_ROOT" \
            --output json \
            --output-file "$INFRASTRUCTURE_DIR/checkov-detailed.json" \
            --framework kubernetes,dockerfile,github_actions \
            --quiet \
            || ((infra_issues++))
        
        # Generate Checkov summary
        if [ -f "$INFRASTRUCTURE_DIR/checkov-detailed.json" ]; then
            jq '{
                tool: "checkov",
                total_checks: (.summary.parsing_errors + .summary.passed + .summary.failed + .summary.skipped),
                passed: .summary.passed,
                failed: .summary.failed,
                skipped: .summary.skipped,
                parsing_errors: .summary.parsing_errors
            }' "$INFRASTRUCTURE_DIR/checkov-detailed.json" > "$INFRASTRUCTURE_DIR/checkov-summary.json"
        fi
    fi
    
    # Trivy config scanning
    if command -v trivy &> /dev/null; then
        log "Running Trivy configuration scan..."
        
        trivy config "$PROJECT_ROOT" \
            --format json \
            --output "$INFRASTRUCTURE_DIR/trivy-config-scan.json" \
            --severity HIGH,CRITICAL \
            || ((infra_issues++))
        
        # Generate Trivy config summary
        if [ -f "$INFRASTRUCTURE_DIR/trivy-config-scan.json" ]; then
            jq '{
                tool: "trivy-config",
                total_misconfigurations: ([.Results[]?.Misconfigurations[]?] | length),
                critical: ([.Results[]?.Misconfigurations[]? | select(.Severity == "CRITICAL")] | length),
                high: ([.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH")] | length),
                medium: ([.Results[]?.Misconfigurations[]? | select(.Severity == "MEDIUM")] | length),
                low: ([.Results[]?.Misconfigurations[]? | select(.Severity == "LOW")] | length)
            }' "$INFRASTRUCTURE_DIR/trivy-config-scan.json" > "$INFRASTRUCTURE_DIR/trivy-config-summary.json"
        fi
    fi
    
    # Kubernetes security scanning
    if [ -d "$PROJECT_ROOT/helm" ] || [ -d "$PROJECT_ROOT/.github/workflows" ]; then
        log "Running Kubernetes security configuration scan..."
        
        # Custom Kubernetes security checks
        python3 << 'EOF' > "$INFRASTRUCTURE_DIR/k8s-security-check.py"
import json
import yaml
import os
import glob

def check_kubernetes_security(directory):
    issues = []
    
    # Find all YAML files
    yaml_files = glob.glob(f"{directory}/**/*.yaml", recursive=True) + \
                 glob.glob(f"{directory}/**/*.yml", recursive=True)
    
    for file_path in yaml_files:
        try:
            with open(file_path, 'r') as f:
                docs = yaml.safe_load_all(f)
                for doc in docs:
                    if not doc or not isinstance(doc, dict):
                        continue
                    
                    # Check for security issues
                    if doc.get('kind') == 'Deployment':
                        containers = doc.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
                        for container in containers:
                            # Check for privileged containers
                            security_context = container.get('securityContext', {})
                            if security_context.get('privileged'):
                                issues.append({
                                    'file': file_path,
                                    'issue': 'privileged_container',
                                    'severity': 'HIGH',
                                    'description': 'Container running with privileged access'
                                })
                            
                            # Check for root user
                            if security_context.get('runAsUser') == 0:
                                issues.append({
                                    'file': file_path,
                                    'issue': 'root_user',
                                    'severity': 'MEDIUM',
                                    'description': 'Container running as root user'
                                })
                            
                            # Check for missing resource limits
                            if not container.get('resources', {}).get('limits'):
                                issues.append({
                                    'file': file_path,
                                    'issue': 'missing_resource_limits',
                                    'severity': 'MEDIUM',
                                    'description': 'Container missing resource limits'
                                })
                    
        except Exception as e:
            issues.append({
                'file': file_path,
                'issue': 'parsing_error',
                'severity': 'LOW',
                'description': f'Error parsing YAML: {str(e)}'
            })
    
    return issues

# Run the check
issues = check_kubernetes_security(os.environ.get('PROJECT_ROOT', '.'))

# Generate report
report = {
    'tool': 'kubernetes_security_check',
    'total_issues': len(issues),
    'high_severity': len([i for i in issues if i['severity'] == 'HIGH']),
    'medium_severity': len([i for i in issues if i['severity'] == 'MEDIUM']),
    'low_severity': len([i for i in issues if i['severity'] == 'LOW']),
    'issues': issues
}

with open('infrastructure/k8s-security-report.json', 'w') as f:
    json.dump(report, f, indent=2)

print(f"Kubernetes security check completed. Found {len(issues)} issues.")
EOF
        
        cd "$SECURITY_DIR"
        PROJECT_ROOT="$PROJECT_ROOT" python3 k8s-security-check.py || ((infra_issues++))
        cd "$PROJECT_ROOT"
    fi
    
    log "Infrastructure scanning completed with $infra_issues issues"
    return $infra_issues
}

# DAST (Dynamic Application Security Testing)
run_dast_scan() {
    if [[ "$ENABLE_DAST" != "true" ]]; then
        log "DAST scanning disabled"
        return 0
    fi
    
    log "Running DAST (Dynamic Application Security Testing)..."
    
    local dast_issues=0
    local target_url="${DAST_TARGET_URL:-http://localhost:8000}"
    
    # OWASP ZAP scanning (if available)
    if command -v zap-baseline.py &> /dev/null; then
        log "Running OWASP ZAP baseline scan..."
        
        zap-baseline.py \
            -t "$target_url" \
            -J "$DAST_DIR/zap-baseline.json" \
            -r "$DAST_DIR/zap-baseline.html" \
            || ((dast_issues++))
    fi
    
    # Nuclei scanning (if available)
    if command -v nuclei &> /dev/null; then
        log "Running Nuclei vulnerability scan..."
        
        nuclei \
            -target "$target_url" \
            -json \
            -output "$DAST_DIR/nuclei-scan.json" \
            -severity medium,high,critical \
            || ((dast_issues++))
    fi
    
    log "DAST scanning completed with $dast_issues issues"
    return $dast_issues
}

# Generate compliance report
generate_compliance_report() {
    log "Generating compliance report..."
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Collect all scan results
    local total_issues=0
    local critical_issues=0
    local high_issues=0
    local medium_issues=0
    local low_issues=0
    
    # Aggregate results from all scans
    for summary_file in $(find "$SECURITY_DIR" -name "*-summary.json"); do
        if [ -f "$summary_file" ]; then
            local tool_issues=$(jq -r '.total_issues // .total_vulnerabilities // .total_secrets // .total_misconfigurations // 0' "$summary_file")
            total_issues=$((total_issues + tool_issues))
            
            # Count by severity if available
            local tool_critical=$(jq -r '.critical // .critical_issues // 0' "$summary_file")
            local tool_high=$(jq -r '.high // .high_issues // .high_severity // 0' "$summary_file")
            local tool_medium=$(jq -r '.medium // .medium_issues // .medium_severity // 0' "$summary_file")
            local tool_low=$(jq -r '.low // .low_issues // .low_severity // 0' "$summary_file")
            
            critical_issues=$((critical_issues + tool_critical))
            high_issues=$((high_issues + tool_high))
            medium_issues=$((medium_issues + tool_medium))
            low_issues=$((low_issues + tool_low))
        fi
    done
    
    # Generate comprehensive security report
    cat > "$SECURITY_DIR/comprehensive-security-report.json" << EOF
{
    "metadata": {
        "scan_timestamp": "$timestamp",
        "scan_type": "$SCAN_TYPE",
        "project_root": "$PROJECT_ROOT",
        "compliance_standards": ["$COMPLIANCE_STANDARDS"],
        "severity_threshold": "$SEVERITY_THRESHOLD"
    },
    "summary": {
        "total_issues": $total_issues,
        "critical_issues": $critical_issues,
        "high_issues": $high_issues,
        "medium_issues": $medium_issues,
        "low_issues": $low_issues,
        "scan_categories": {
            "sast": $ENABLE_SAST,
            "dast": $ENABLE_DAST,
            "sca": $ENABLE_SCA,
            "secrets": $ENABLE_SECRET_SCAN,
            "containers": $ENABLE_CONTAINER_SCAN,
            "infrastructure": $ENABLE_INFRASTRUCTURE_SCAN
        }
    },
    "compliance": {
        "iso27001": {
            "status": "$([ $critical_issues -eq 0 ] && echo "compliant" || echo "non_compliant")",
            "critical_controls": "$([ $critical_issues -eq 0 ] && echo "passed" || echo "failed")",
            "recommendations": [
                "Implement continuous security monitoring",
                "Regular vulnerability assessments",
                "Security awareness training",
                "Incident response procedures"
            ]
        },
        "owasp": {
            "status": "$([ $((critical_issues + high_issues)) -eq 0 ] && echo "compliant" || echo "non_compliant")",
            "top10_coverage": "comprehensive",
            "recommendations": [
                "Input validation",
                "Authentication and session management",
                "Access control",
                "Security misconfiguration prevention"
            ]
        }
    },
    "recommendations": {
        "immediate": [
            $([ $critical_issues -gt 0 ] && echo "\"Address $critical_issues critical security issues\"," || echo "")
            $([ $high_issues -gt 0 ] && echo "\"Review $high_issues high-severity findings\"," || echo "")
            "Implement automated security testing in CI/CD pipeline"
        ],
        "short_term": [
            "Enable dependency vulnerability scanning",
            "Implement secret management solutions",
            "Configure security monitoring and alerting"
        ],
        "long_term": [
            "Establish security architecture review process",
            "Implement security-by-design principles",
            "Regular security training and awareness programs"
        ]
    }
}
EOF
    
    # Generate HTML report
    generate_html_security_report
    
    log "Compliance report generated: $SECURITY_DIR/comprehensive-security-report.json"
}

# Generate HTML security report
generate_html_security_report() {
    local html_report="$SECURITY_DIR/comprehensive-security-report.html"
    
    cat > "$html_report" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Microsoft 365 Management Tools - Security Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .critical { color: #d32f2f; font-weight: bold; }
        .high { color: #f57c00; font-weight: bold; }
        .medium { color: #1976d2; font-weight: bold; }
        .low { color: #388e3c; }
        .compliant { color: #4caf50; font-weight: bold; }
        .non-compliant { color: #f44336; font-weight: bold; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .metric { font-size: 24px; font-weight: bold; }
        .progress-bar { width: 100%; background-color: #f0f0f0; border-radius: 5px; }
        .progress-fill { height: 20px; background-color: #4caf50; border-radius: 5px; text-align: center; line-height: 20px; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 Microsoft 365 Management Tools - Security Assessment Report</h1>
        <p><strong>Generated:</strong> <span id="timestamp"></span></p>
        <p><strong>Scan Type:</strong> Comprehensive Security Analysis</p>
        <p><strong>Compliance Standards:</strong> ISO 27001, OWASP Top 10</p>
    </div>

    <div class="section">
        <h2>📊 Security Summary</h2>
        <table>
            <tr><th>Severity</th><th>Count</th><th>Status</th></tr>
            <tr><td class="critical">Critical</td><td id="critical-count">-</td><td id="critical-status">-</td></tr>
            <tr><td class="high">High</td><td id="high-count">-</td><td id="high-status">-</td></tr>
            <tr><td class="medium">Medium</td><td id="medium-count">-</td><td id="medium-status">-</td></tr>
            <tr><td class="low">Low</td><td id="low-count">-</td><td id="low-status">-</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>🛡️ Security Scan Coverage</h2>
        <table>
            <tr><th>Scan Type</th><th>Status</th><th>Description</th></tr>
            <tr><td>SAST</td><td id="sast-status">-</td><td>Static Application Security Testing</td></tr>
            <tr><td>DAST</td><td id="dast-status">-</td><td>Dynamic Application Security Testing</td></tr>
            <tr><td>SCA</td><td id="sca-status">-</td><td>Software Composition Analysis</td></tr>
            <tr><td>Secrets</td><td id="secrets-status">-</td><td>Secret Detection Scanning</td></tr>
            <tr><td>Containers</td><td id="containers-status">-</td><td>Container Security Scanning</td></tr>
            <tr><td>Infrastructure</td><td id="infrastructure-status">-</td><td>Infrastructure as Code Scanning</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>📋 Compliance Status</h2>
        <h3>ISO 27001</h3>
        <p>Status: <span id="iso-status" class="compliant">-</span></p>
        <p>Critical Controls: <span id="iso-controls">-</span></p>
        
        <h3>OWASP Top 10</h3>
        <p>Status: <span id="owasp-status" class="compliant">-</span></p>
        <p>Coverage: <span id="owasp-coverage">-</span></p>
    </div>

    <div class="section">
        <h2>🎯 Recommendations</h2>
        <h3>Immediate Actions</h3>
        <ul id="immediate-recommendations"></ul>
        
        <h3>Short-term Improvements</h3>
        <ul id="shortterm-recommendations"></ul>
        
        <h3>Long-term Strategy</h3>
        <ul id="longterm-recommendations"></ul>
    </div>

    <div class="section">
        <h2>📁 Detailed Reports</h2>
        <p>The following detailed reports are available:</p>
        <ul>
            <li><a href="sast/">SAST Results</a></li>
            <li><a href="sca/">SCA Results</a></li>
            <li><a href="secrets/">Secret Scan Results</a></li>
            <li><a href="containers/">Container Scan Results</a></li>
            <li><a href="infrastructure/">Infrastructure Scan Results</a></li>
        </ul>
    </div>

    <script>
        // Load and display security report data
        fetch('comprehensive-security-report.json')
            .then(response => response.json())
            .then(data => {
                // Update timestamp
                document.getElementById('timestamp').textContent = data.metadata.scan_timestamp;
                
                // Update summary
                document.getElementById('critical-count').textContent = data.summary.critical_issues;
                document.getElementById('high-count').textContent = data.summary.high_issues;
                document.getElementById('medium-count').textContent = data.summary.medium_issues;
                document.getElementById('low-count').textContent = data.summary.low_issues;
                
                // Update scan coverage
                document.getElementById('sast-status').textContent = data.summary.scan_categories.sast ? '✅ Enabled' : '❌ Disabled';
                document.getElementById('dast-status').textContent = data.summary.scan_categories.dast ? '✅ Enabled' : '❌ Disabled';
                document.getElementById('sca-status').textContent = data.summary.scan_categories.sca ? '✅ Enabled' : '❌ Disabled';
                document.getElementById('secrets-status').textContent = data.summary.scan_categories.secrets ? '✅ Enabled' : '❌ Disabled';
                document.getElementById('containers-status').textContent = data.summary.scan_categories.containers ? '✅ Enabled' : '❌ Disabled';
                document.getElementById('infrastructure-status').textContent = data.summary.scan_categories.infrastructure ? '✅ Enabled' : '❌ Disabled';
                
                // Update compliance
                document.getElementById('iso-status').textContent = data.compliance.iso27001.status;
                document.getElementById('iso-status').className = data.compliance.iso27001.status === 'compliant' ? 'compliant' : 'non-compliant';
                document.getElementById('iso-controls').textContent = data.compliance.iso27001.critical_controls;
                
                document.getElementById('owasp-status').textContent = data.compliance.owasp.status;
                document.getElementById('owasp-status').className = data.compliance.owasp.status === 'compliant' ? 'compliant' : 'non-compliant';
                document.getElementById('owasp-coverage').textContent = data.compliance.owasp.top10_coverage;
                
                // Update recommendations
                const immediateUl = document.getElementById('immediate-recommendations');
                data.recommendations.immediate.forEach(rec => {
                    const li = document.createElement('li');
                    li.textContent = rec;
                    immediateUl.appendChild(li);
                });
                
                const shorttermUl = document.getElementById('shortterm-recommendations');
                data.recommendations.short_term.forEach(rec => {
                    const li = document.createElement('li');
                    li.textContent = rec;
                    shorttermUl.appendChild(li);
                });
                
                const longtermUl = document.getElementById('longterm-recommendations');
                data.recommendations.long_term.forEach(rec => {
                    const li = document.createElement('li');
                    li.textContent = rec;
                    longtermUl.appendChild(li);
                });
            })
            .catch(error => {
                console.error('Error loading security report:', error);
            });
    </script>
</body>
</html>
EOF
    
    log "HTML security report generated: $html_report"
}

# Usage information
usage() {
    cat << EOF
Microsoft 365 Management Tools - Advanced Security Scanner

Usage: $0 [OPTIONS]

Options:
    --scan-type TYPE          Scan type: full, quick, targeted (default: full)
    --output-format FORMAT    Output format: json, xml, html (default: json)
    --severity-threshold LEVEL Minimum severity: low, medium, high, critical (default: medium)
    --compliance STANDARDS    Compliance standards: iso27001,owasp (default: iso27001,owasp)
    
    --enable-sast            Enable SAST scanning (default: true)
    --enable-dast            Enable DAST scanning (default: false)
    --enable-sca             Enable SCA scanning (default: true)
    --enable-secrets         Enable secret scanning (default: true)
    --enable-containers      Enable container scanning (default: true)
    --enable-infrastructure  Enable infrastructure scanning (default: true)
    
    --dast-target URL        Target URL for DAST scanning
    --container-image IMAGE  Container image to scan
    
    --help                   Show this help message

Examples:
    $0                                           # Full security scan
    $0 --scan-type quick --enable-sast          # Quick SAST scan only
    $0 --enable-dast --dast-target http://localhost:8000
    $0 --compliance iso27001 --severity-threshold high

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --scan-type)
            SCAN_TYPE="$2"
            shift 2
            ;;
        --output-format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --severity-threshold)
            SEVERITY_THRESHOLD="$2"
            shift 2
            ;;
        --compliance)
            COMPLIANCE_STANDARDS="$2"
            shift 2
            ;;
        --enable-sast)
            ENABLE_SAST="true"
            shift
            ;;
        --enable-dast)
            ENABLE_DAST="true"
            shift
            ;;
        --enable-sca)
            ENABLE_SCA="true"
            shift
            ;;
        --enable-secrets)
            ENABLE_SECRET_SCAN="true"
            shift
            ;;
        --enable-containers)
            ENABLE_CONTAINER_SCAN="true"
            shift
            ;;
        --enable-infrastructure)
            ENABLE_INFRASTRUCTURE_SCAN="true"
            shift
            ;;
        --dast-target)
            DAST_TARGET_URL="$2"
            shift 2
            ;;
        --container-image)
            CONTAINER_IMAGE="$2"
            shift 2
            ;;
        --help)
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
    log "🔒 Microsoft 365 Management Tools - Advanced Security Scanner"
    log "==========================================================="
    
    info "Configuration:"
    info "  Scan Type: $SCAN_TYPE"
    info "  Output Format: $OUTPUT_FORMAT"
    info "  Severity Threshold: $SEVERITY_THRESHOLD"
    info "  Compliance Standards: $COMPLIANCE_STANDARDS"
    info "  SAST: $ENABLE_SAST"
    info "  DAST: $ENABLE_DAST"
    info "  SCA: $ENABLE_SCA"
    info "  Secrets: $ENABLE_SECRET_SCAN"
    info "  Containers: $ENABLE_CONTAINER_SCAN"
    info "  Infrastructure: $ENABLE_INFRASTRUCTURE_SCAN"
    
    # Initialize
    init_security_environment
    
    # Run security scans
    local scan_results=()
    local total_issues=0
    
    if [[ "$ENABLE_SAST" == "true" ]]; then
        run_sast_scan && scan_results+=("sast:passed") || { scan_results+=("sast:failed"); total_issues=$((total_issues + $?)); }
    fi
    
    if [[ "$ENABLE_SCA" == "true" ]]; then
        run_sca_scan && scan_results+=("sca:passed") || { scan_results+=("sca:failed"); total_issues=$((total_issues + $?)); }
    fi
    
    if [[ "$ENABLE_SECRET_SCAN" == "true" ]]; then
        run_secret_scan && scan_results+=("secrets:passed") || { scan_results+=("secrets:failed"); total_issues=$((total_issues + $?)); }
    fi
    
    if [[ "$ENABLE_CONTAINER_SCAN" == "true" ]]; then
        run_container_scan && scan_results+=("containers:passed") || { scan_results+=("containers:failed"); total_issues=$((total_issues + $?)); }
    fi
    
    if [[ "$ENABLE_INFRASTRUCTURE_SCAN" == "true" ]]; then
        run_infrastructure_scan && scan_results+=("infrastructure:passed") || { scan_results+=("infrastructure:failed"); total_issues=$((total_issues + $?)); }
    fi
    
    if [[ "$ENABLE_DAST" == "true" ]]; then
        run_dast_scan && scan_results+=("dast:passed") || { scan_results+=("dast:failed"); total_issues=$((total_issues + $?)); }
    fi
    
    # Generate reports
    generate_compliance_report
    
    # Summary
    log "Security Scan Results Summary:"
    for result in "${scan_results[@]}"; do
        local scan_type="${result%%:*}"
        local scan_status="${result##*:}"
        if [[ "$scan_status" == "passed" ]]; then
            log "  ✅ $scan_type scan: PASSED"
        else
            log "  ❌ $scan_type scan: FAILED"
        fi
    done
    
    log "Reports generated in: $SECURITY_DIR"
    
    if [ $total_issues -eq 0 ]; then
        log "🎉 Advanced security scanning completed successfully"
        exit 0
    else
        warn "⚠️ Security scanning completed with issues ($total_issues total)"
        exit 1
    fi
}

# Execute main function
main "$@"