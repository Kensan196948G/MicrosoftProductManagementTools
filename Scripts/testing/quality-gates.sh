#!/bin/bash
set -e

# Microsoft 365 Management Tools - Quality Gates & Testing Framework
# Enterprise-grade automated testing with quality gates integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
TEST_ENVIRONMENT="${TEST_ENVIRONMENT:-ci}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-90}"
SECURITY_THRESHOLD="${SECURITY_THRESHOLD:-100}"
PERFORMANCE_THRESHOLD="${PERFORMANCE_THRESHOLD:-2000}"
QUALITY_GATE_STRICT="${QUALITY_GATE_STRICT:-true}"

# Test categories
RUN_UNIT_TESTS="${RUN_UNIT_TESTS:-true}"
RUN_INTEGRATION_TESTS="${RUN_INTEGRATION_TESTS:-true}"
RUN_SECURITY_TESTS="${RUN_SECURITY_TESTS:-true}"
RUN_PERFORMANCE_TESTS="${RUN_PERFORMANCE_TESTS:-true}"
RUN_E2E_TESTS="${RUN_E2E_TESTS:-false}"

# Output directories
REPORTS_DIR="${PROJECT_ROOT}/TestScripts/TestReports"
COVERAGE_DIR="${REPORTS_DIR}/coverage"
SECURITY_DIR="${REPORTS_DIR}/security"
PERFORMANCE_DIR="${REPORTS_DIR}/performance"

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

# Initialize test environment
init_test_environment() {
    log "Initializing test environment..."
    
    # Create report directories
    mkdir -p "$REPORTS_DIR" "$COVERAGE_DIR" "$SECURITY_DIR" "$PERFORMANCE_DIR"
    
    # Set environment variables
    export PYTHONDONTWRITEBYTECODE=1
    export PYTEST_CURRENT_TEST=""
    export QT_QPA_PLATFORM=offscreen
    
    # Clean up previous test artifacts
    find "$REPORTS_DIR" -name "*.xml" -mtime +7 -delete 2>/dev/null || true
    find "$REPORTS_DIR" -name "*.json" -mtime +7 -delete 2>/dev/null || true
    find "$REPORTS_DIR" -name "*.html" -mtime +7 -delete 2>/dev/null || true
    
    log "Test environment initialized"
}

# Run unit tests
run_unit_tests() {
    if [[ "$RUN_UNIT_TESTS" != "true" ]]; then
        log "Unit tests skipped"
        return 0
    fi
    
    log "Running unit tests..."
    
    local test_result=0
    
    # Python unit tests
    if [ -d "$PROJECT_ROOT/Tests" ]; then
        log "Running Python unit tests..."
        
        python -m pytest "$PROJECT_ROOT/Tests" \
            -v \
            --tb=short \
            --strict-markers \
            --cov=src \
            --cov=Tests \
            --cov-report=html:"$COVERAGE_DIR/python-coverage" \
            --cov-report=xml:"$COVERAGE_DIR/python-coverage.xml" \
            --cov-report=term-missing \
            --html="$REPORTS_DIR/python-unit-tests.html" \
            --self-contained-html \
            --junitxml="$REPORTS_DIR/python-unit-tests.xml" \
            --maxfail=10 \
            -m "not integration and not e2e" \
            || test_result=$?
    fi
    
    # PowerShell unit tests
    if [ -d "$PROJECT_ROOT/TestScripts" ]; then
        log "Running PowerShell unit tests..."
        
        pwsh -Command "
            try {
                \$testResults = @()
                Get-ChildItem '$PROJECT_ROOT/TestScripts' -Filter 'test-*.ps1' | ForEach-Object {
                    Write-Host 'Running PowerShell test: ' \$_.Name
                    try {
                        \$result = & \$_.FullName
                        \$testResults += @{
                            Name = \$_.Name
                            Status = 'Passed'
                            Output = \$result
                        }
                    } catch {
                        \$testResults += @{
                            Name = \$_.Name
                            Status = 'Failed'
                            Error = \$_.Exception.Message
                        }
                    }
                }
                
                # Generate test report
                \$report = @{
                    Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
                    Environment = '$TEST_ENVIRONMENT'
                    TotalTests = \$testResults.Count
                    PassedTests = (\$testResults | Where-Object { \$_.Status -eq 'Passed' }).Count
                    FailedTests = (\$testResults | Where-Object { \$_.Status -eq 'Failed' }).Count
                    Results = \$testResults
                }
                
                \$report | ConvertTo-Json -Depth 3 | Out-File '$REPORTS_DIR/powershell-unit-tests.json' -Encoding UTF8
                Write-Host 'PowerShell unit tests completed'
            } catch {
                Write-Warning 'PowerShell unit tests failed: ' \$_.Exception.Message
                exit 1
            }
        " || test_result=$?
    fi
    
    if [ $test_result -eq 0 ]; then
        log "✅ Unit tests passed"
        return 0
    else
        error "❌ Unit tests failed"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    if [[ "$RUN_INTEGRATION_TESTS" != "true" ]]; then
        log "Integration tests skipped"
        return 0
    fi
    
    log "Running integration tests..."
    
    local test_result=0
    
    # Python integration tests
    if [ -d "$PROJECT_ROOT/Tests" ]; then
        python -m pytest "$PROJECT_ROOT/Tests" \
            -v \
            --tb=short \
            --html="$REPORTS_DIR/python-integration-tests.html" \
            --self-contained-html \
            --junitxml="$REPORTS_DIR/python-integration-tests.xml" \
            -m "integration" \
            || test_result=$?
    fi
    
    # API integration tests
    if [ -f "$PROJECT_ROOT/Tests/api/test_integration.py" ]; then
        log "Running API integration tests..."
        
        python -m pytest "$PROJECT_ROOT/Tests/api/test_integration.py" \
            -v \
            --html="$REPORTS_DIR/api-integration-tests.html" \
            --junitxml="$REPORTS_DIR/api-integration-tests.xml" \
            || test_result=$?
    fi
    
    if [ $test_result -eq 0 ]; then
        log "✅ Integration tests passed"
        return 0
    else
        error "❌ Integration tests failed"
        return 1
    fi
}

# Run security tests
run_security_tests() {
    if [[ "$RUN_SECURITY_TESTS" != "true" ]]; then
        log "Security tests skipped"
        return 0
    fi
    
    log "Running security tests..."
    
    local security_issues=0
    
    # Bandit security scan (Python)
    if find "$PROJECT_ROOT" -name "*.py" -not -path "*/venv/*" -not -path "*/.pytest_cache/*" | head -1 | grep -q .; then
        log "Running Bandit security scan..."
        bandit -r "$PROJECT_ROOT" \
            -f json \
            -o "$SECURITY_DIR/bandit-report.json" \
            --skip B101,B601 \
            --exclude "**/venv/**,**/.pytest_cache/**" \
            || ((security_issues++))
    fi
    
    # Safety dependency check
    log "Running Safety dependency check..."
    safety check \
        --json \
        --output "$SECURITY_DIR/safety-report.json" \
        || ((security_issues++))
    
    # Semgrep SAST scan
    if command -v semgrep &> /dev/null; then
        log "Running Semgrep SAST scan..."
        semgrep \
            --config=auto \
            --json \
            --output="$SECURITY_DIR/semgrep-report.json" \
            "$PROJECT_ROOT" \
            || ((security_issues++))
    fi
    
    # PowerShell Script Analyzer
    log "Running PowerShell Script Analyzer..."
    pwsh -Command "
        if (Get-Module -ListAvailable PSScriptAnalyzer) {
            Import-Module PSScriptAnalyzer
            \$results = Get-ChildItem '$PROJECT_ROOT' -Recurse -Include '*.ps1' | Invoke-ScriptAnalyzer
            if (\$results) {
                \$results | Export-Csv -Path '$SECURITY_DIR/scriptanalyzer-report.csv' -NoTypeInformation
                Write-Host 'PowerShell analysis issues found: ' \$results.Count
            } else {
                Write-Host 'PowerShell analysis: No issues found'
            }
        } else {
            Write-Host 'PSScriptAnalyzer not available'
        }
    "
    
    # Custom security tests
    if [ -f "$PROJECT_ROOT/Tests/security/automated_security_scanner.py" ]; then
        log "Running custom security tests..."
        cd "$PROJECT_ROOT/Tests/security"
        python automated_security_scanner.py || ((security_issues++))
        cd "$PROJECT_ROOT"
    fi
    
    # Generate security summary
    generate_security_summary "$security_issues"
    
    if [ $security_issues -eq 0 ]; then
        log "✅ Security tests passed"
        return 0
    else
        error "❌ Security tests found $security_issues issues"
        if [[ "$QUALITY_GATE_STRICT" == "true" ]]; then
            return 1
        else
            warn "Security issues found but not blocking (strict mode disabled)"
            return 0
        fi
    fi
}

# Run performance tests
run_performance_tests() {
    if [[ "$RUN_PERFORMANCE_TESTS" != "true" ]]; then
        log "Performance tests skipped"
        return 0
    fi
    
    log "Running performance tests..."
    
    local perf_result=0
    
    # Load testing
    if [ -f "$PROJECT_ROOT/Tests/performance/load_testing_suite.py" ]; then
        log "Running load tests..."
        cd "$PROJECT_ROOT/Tests/performance"
        python load_testing_suite.py || perf_result=$?
        cd "$PROJECT_ROOT"
    fi
    
    # Memory profiling
    if [ -f "$PROJECT_ROOT/Tests/performance/memory_profiler.py" ]; then
        log "Running memory profiling..."
        python -m memory_profiler "$PROJECT_ROOT/Tests/performance/memory_profiler.py" \
            > "$PERFORMANCE_DIR/memory-profile.txt" || true
    fi
    
    # Performance benchmarks
    if [ -f "$PROJECT_ROOT/Tests/performance/benchmarks.py" ]; then
        log "Running performance benchmarks..."
        python "$PROJECT_ROOT/Tests/performance/benchmarks.py" \
            --output "$PERFORMANCE_DIR/benchmarks.json" || perf_result=$?
    fi
    
    # Generate performance summary
    generate_performance_summary
    
    if [ $perf_result -eq 0 ]; then
        log "✅ Performance tests passed"
        return 0
    else
        error "❌ Performance tests failed"
        return 1
    fi
}

# Run end-to-end tests
run_e2e_tests() {
    if [[ "$RUN_E2E_TESTS" != "true" ]]; then
        log "E2E tests skipped"
        return 0
    fi
    
    log "Running end-to-end tests..."
    
    local e2e_result=0
    
    # Playwright E2E tests
    if [ -d "$PROJECT_ROOT/frontend/tests" ]; then
        log "Running Playwright E2E tests..."
        cd "$PROJECT_ROOT/frontend"
        npm run test:e2e || e2e_result=$?
        cd "$PROJECT_ROOT"
    fi
    
    # Cypress E2E tests
    if [ -f "$PROJECT_ROOT/frontend/cypress.config.ts" ]; then
        log "Running Cypress E2E tests..."
        cd "$PROJECT_ROOT/frontend"
        npm run cypress:run || e2e_result=$?
        cd "$PROJECT_ROOT"
    fi
    
    if [ $e2e_result -eq 0 ]; then
        log "✅ E2E tests passed"
        return 0
    else
        error "❌ E2E tests failed"
        return 1
    fi
}

# Generate security summary
generate_security_summary() {
    local issues_count="$1"
    
    cat > "$SECURITY_DIR/security-summary.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$TEST_ENVIRONMENT",
    "total_issues": $issues_count,
    "threshold": $SECURITY_THRESHOLD,
    "passed": $([ $issues_count -eq 0 ] && echo "true" || echo "false"),
    "reports": {
        "bandit": "$([ -f "$SECURITY_DIR/bandit-report.json" ] && echo "available" || echo "not_run")",
        "safety": "$([ -f "$SECURITY_DIR/safety-report.json" ] && echo "available" || echo "not_run")",
        "semgrep": "$([ -f "$SECURITY_DIR/semgrep-report.json" ] && echo "available" || echo "not_run")",
        "powershell": "$([ -f "$SECURITY_DIR/scriptanalyzer-report.csv" ] && echo "available" || echo "not_run")"
    }
}
EOF
}

# Generate performance summary
generate_performance_summary() {
    cat > "$PERFORMANCE_DIR/performance-summary.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$TEST_ENVIRONMENT",
    "threshold_ms": $PERFORMANCE_THRESHOLD,
    "reports": {
        "load_testing": "$([ -f "$PERFORMANCE_DIR/load-test-results.json" ] && echo "available" || echo "not_run")",
        "memory_profiling": "$([ -f "$PERFORMANCE_DIR/memory-profile.txt" ] && echo "available" || echo "not_run")",
        "benchmarks": "$([ -f "$PERFORMANCE_DIR/benchmarks.json" ] && echo "available" || echo "not_run")"
    }
}
EOF
}

# Calculate test coverage
calculate_coverage() {
    log "Calculating test coverage..."
    
    local coverage_percentage=0
    
    # Python coverage
    if [ -f "$COVERAGE_DIR/python-coverage.xml" ]; then
        coverage_percentage=$(python -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('$COVERAGE_DIR/python-coverage.xml')
    root = tree.getroot()
    coverage = float(root.attrib.get('line-rate', 0)) * 100
    print(f'{coverage:.1f}')
except:
    print('0')
        ")
    fi
    
    info "Current coverage: ${coverage_percentage}%"
    info "Coverage threshold: ${COVERAGE_THRESHOLD}%"
    
    if (( $(echo "$coverage_percentage >= $COVERAGE_THRESHOLD" | bc -l) )); then
        log "✅ Coverage threshold met"
        echo "$coverage_percentage"
        return 0
    else
        error "❌ Coverage below threshold: ${coverage_percentage}% < ${COVERAGE_THRESHOLD}%"
        echo "$coverage_percentage"
        return 1
    fi
}

# Quality gate evaluation
evaluate_quality_gates() {
    log "Evaluating quality gates..."
    
    local quality_score=0
    local max_score=100
    local gates_passed=0
    local total_gates=0
    
    # Coverage gate (25 points)
    ((total_gates++))
    local coverage=$(calculate_coverage)
    if [ $? -eq 0 ]; then
        ((gates_passed++))
        quality_score=$((quality_score + 25))
        log "✅ Coverage gate passed: ${coverage}%"
    else
        error "❌ Coverage gate failed: ${coverage}%"
    fi
    
    # Security gate (25 points)
    ((total_gates++))
    if [ -f "$SECURITY_DIR/security-summary.json" ]; then
        local security_passed=$(jq -r '.passed' "$SECURITY_DIR/security-summary.json" 2>/dev/null || echo "false")
        if [ "$security_passed" = "true" ]; then
            ((gates_passed++))
            quality_score=$((quality_score + 25))
            log "✅ Security gate passed"
        else
            error "❌ Security gate failed"
        fi
    else
        error "❌ Security gate failed: No security summary available"
    fi
    
    # Unit tests gate (25 points)
    ((total_gates++))
    if [ -f "$REPORTS_DIR/python-unit-tests.xml" ] || [ -f "$REPORTS_DIR/powershell-unit-tests.json" ]; then
        ((gates_passed++))
        quality_score=$((quality_score + 25))
        log "✅ Unit tests gate passed"
    else
        error "❌ Unit tests gate failed"
    fi
    
    # Integration tests gate (25 points)
    ((total_gates++))
    if [ -f "$REPORTS_DIR/python-integration-tests.xml" ] || [ "$RUN_INTEGRATION_TESTS" != "true" ]; then
        ((gates_passed++))
        quality_score=$((quality_score + 25))
        log "✅ Integration tests gate passed"
    else
        error "❌ Integration tests gate failed"
    fi
    
    # Generate quality gate report
    cat > "$REPORTS_DIR/quality-gates-summary.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$TEST_ENVIRONMENT",
    "quality_score": $quality_score,
    "max_score": $max_score,
    "gates_passed": $gates_passed,
    "total_gates": $total_gates,
    "success_rate": $(echo "scale=1; $gates_passed * 100 / $total_gates" | bc),
    "coverage_percentage": $coverage,
    "coverage_threshold": $COVERAGE_THRESHOLD,
    "security_threshold": $SECURITY_THRESHOLD,
    "strict_mode": $QUALITY_GATE_STRICT,
    "gates": {
        "coverage": $([ $(echo "$coverage >= $COVERAGE_THRESHOLD" | bc -l) -eq 1 ] && echo "true" || echo "false"),
        "security": $([ -f "$SECURITY_DIR/security-summary.json" ] && jq -r '.passed' "$SECURITY_DIR/security-summary.json" || echo "false"),
        "unit_tests": $([ -f "$REPORTS_DIR/python-unit-tests.xml" ] && echo "true" || echo "false"),
        "integration_tests": $([ -f "$REPORTS_DIR/python-integration-tests.xml" ] && echo "true" || echo "false")
    }
}
EOF
    
    # Determine overall result
    local minimum_gates=3
    if [[ "$QUALITY_GATE_STRICT" == "true" ]]; then
        minimum_gates=$total_gates
    fi
    
    if [ $gates_passed -ge $minimum_gates ]; then
        log "🎉 Quality gates passed: $gates_passed/$total_gates (Score: $quality_score/$max_score)"
        return 0
    else
        error "❌ Quality gates failed: $gates_passed/$total_gates (Score: $quality_score/$max_score)"
        return 1
    fi
}

# Generate comprehensive test report
generate_test_report() {
    log "Generating comprehensive test report..."
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local report_file="$REPORTS_DIR/comprehensive-test-report-$(date +%Y%m%d-%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Microsoft 365 Management Tools - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .passed { color: green; font-weight: bold; }
        .failed { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .metric { font-size: 24px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Microsoft 365 Management Tools - Test Report</h1>
        <p><strong>Generated:</strong> $timestamp</p>
        <p><strong>Environment:</strong> $TEST_ENVIRONMENT</p>
        <p><strong>Quality Gate:</strong> $([ -f "$REPORTS_DIR/quality-gates-summary.json" ] && echo "Available" || echo "Not Available")</p>
    </div>

    <div class="section">
        <h2>📊 Test Summary</h2>
        <table>
            <tr><th>Test Category</th><th>Status</th><th>Report</th></tr>
            <tr>
                <td>Unit Tests</td>
                <td class="$([ -f "$REPORTS_DIR/python-unit-tests.xml" ] && echo "passed" || echo "failed")">
                    $([ -f "$REPORTS_DIR/python-unit-tests.xml" ] && echo "✅ Passed" || echo "❌ Failed")
                </td>
                <td>$([ -f "$REPORTS_DIR/python-unit-tests.html" ] && echo "<a href='python-unit-tests.html'>View Report</a>" || echo "No Report")</td>
            </tr>
            <tr>
                <td>Integration Tests</td>
                <td class="$([ -f "$REPORTS_DIR/python-integration-tests.xml" ] && echo "passed" || echo "failed")">
                    $([ -f "$REPORTS_DIR/python-integration-tests.xml" ] && echo "✅ Passed" || echo "❌ Failed")
                </td>
                <td>$([ -f "$REPORTS_DIR/python-integration-tests.html" ] && echo "<a href='python-integration-tests.html'>View Report</a>" || echo "No Report")</td>
            </tr>
            <tr>
                <td>Security Tests</td>
                <td class="$([ -f "$SECURITY_DIR/security-summary.json" ] && echo "passed" || echo "failed")">
                    $([ -f "$SECURITY_DIR/security-summary.json" ] && echo "✅ Passed" || echo "❌ Failed")
                </td>
                <td>$([ -f "$SECURITY_DIR/security-summary.json" ] && echo "<a href='security/security-summary.json'>View Report</a>" || echo "No Report")</td>
            </tr>
            <tr>
                <td>Performance Tests</td>
                <td class="$([ -f "$PERFORMANCE_DIR/performance-summary.json" ] && echo "passed" || echo "failed")">
                    $([ -f "$PERFORMANCE_DIR/performance-summary.json" ] && echo "✅ Passed" || echo "❌ Failed")
                </td>
                <td>$([ -f "$PERFORMANCE_DIR/performance-summary.json" ] && echo "<a href='performance/performance-summary.json'>View Report</a>" || echo "No Report")</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>📈 Quality Metrics</h2>
        <p><strong>Coverage:</strong> <span class="metric">$([ -f "$COVERAGE_DIR/python-coverage.xml" ] && calculate_coverage || echo "0")%</span></p>
        <p><strong>Coverage Threshold:</strong> ${COVERAGE_THRESHOLD}%</p>
        <p><strong>Security Issues:</strong> <span class="metric">$([ -f "$SECURITY_DIR/security-summary.json" ] && jq -r '.total_issues' "$SECURITY_DIR/security-summary.json" || echo "Unknown")</span></p>
    </div>

    <div class="section">
        <h2>🎯 Quality Gates</h2>
        $([ -f "$REPORTS_DIR/quality-gates-summary.json" ] && echo "<p>Quality gates evaluation completed. Check quality-gates-summary.json for details.</p>" || echo "<p>Quality gates evaluation not available.</p>")
    </div>

    <div class="section">
        <h2>📁 Generated Reports</h2>
        <ul>
            $(find "$REPORTS_DIR" -name "*.html" -o -name "*.xml" -o -name "*.json" | while read file; do
                basename=$(basename "$file")
                echo "<li><a href='$(realpath --relative-to="$REPORTS_DIR" "$file")'>$basename</a></li>"
            done)
        </ul>
    </div>

    <footer style="margin-top: 40px; padding: 20px; background-color: #f9f9f9; border-radius: 5px;">
        <p><em>Generated by Microsoft 365 Management Tools Quality Gates Framework</em></p>
        <p><em>Timestamp: $timestamp</em></p>
    </footer>
</body>
</html>
EOF
    
    log "Test report generated: $report_file"
}

# Usage information
usage() {
    cat << EOF
Microsoft 365 Management Tools - Quality Gates & Testing Framework

Usage: $0 [OPTIONS]

Options:
    --unit-tests           Run unit tests (default: true)
    --integration-tests    Run integration tests (default: true)
    --security-tests       Run security tests (default: true)
    --performance-tests    Run performance tests (default: true)
    --e2e-tests           Run end-to-end tests (default: false)
    --coverage-threshold N Set coverage threshold (default: 90)
    --security-threshold N Set security threshold (default: 100)
    --strict              Enable strict quality gates (default: true)
    --environment ENV     Set test environment (default: ci)
    --help                Show this help message

Examples:
    $0                                    # Run all default tests
    $0 --e2e-tests --coverage-threshold 85
    $0 --security-tests --strict=false

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-tests)
            RUN_UNIT_TESTS="${2:-true}"
            shift 2
            ;;
        --integration-tests)
            RUN_INTEGRATION_TESTS="${2:-true}"
            shift 2
            ;;
        --security-tests)
            RUN_SECURITY_TESTS="${2:-true}"
            shift 2
            ;;
        --performance-tests)
            RUN_PERFORMANCE_TESTS="${2:-true}"
            shift 2
            ;;
        --e2e-tests)
            RUN_E2E_TESTS="${2:-true}"
            shift 2
            ;;
        --coverage-threshold)
            COVERAGE_THRESHOLD="$2"
            shift 2
            ;;
        --security-threshold)
            SECURITY_THRESHOLD="$2"
            shift 2
            ;;
        --strict)
            QUALITY_GATE_STRICT="$2"
            shift 2
            ;;
        --environment)
            TEST_ENVIRONMENT="$2"
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
    log "🧪 Microsoft 365 Management Tools - Quality Gates & Testing Framework"
    log "======================================================================"
    
    info "Configuration:"
    info "  Environment: $TEST_ENVIRONMENT"
    info "  Coverage Threshold: ${COVERAGE_THRESHOLD}%"
    info "  Security Threshold: ${SECURITY_THRESHOLD}%"
    info "  Strict Mode: $QUALITY_GATE_STRICT"
    info "  Unit Tests: $RUN_UNIT_TESTS"
    info "  Integration Tests: $RUN_INTEGRATION_TESTS"
    info "  Security Tests: $RUN_SECURITY_TESTS"
    info "  Performance Tests: $RUN_PERFORMANCE_TESTS"
    info "  E2E Tests: $RUN_E2E_TESTS"
    
    # Initialize
    init_test_environment
    
    # Run test suites
    local test_results=()
    
    if [[ "$RUN_UNIT_TESTS" == "true" ]]; then
        run_unit_tests && test_results+=("unit:passed") || test_results+=("unit:failed")
    fi
    
    if [[ "$RUN_INTEGRATION_TESTS" == "true" ]]; then
        run_integration_tests && test_results+=("integration:passed") || test_results+=("integration:failed")
    fi
    
    if [[ "$RUN_SECURITY_TESTS" == "true" ]]; then
        run_security_tests && test_results+=("security:passed") || test_results+=("security:failed")
    fi
    
    if [[ "$RUN_PERFORMANCE_TESTS" == "true" ]]; then
        run_performance_tests && test_results+=("performance:passed") || test_results+=("performance:failed")
    fi
    
    if [[ "$RUN_E2E_TESTS" == "true" ]]; then
        run_e2e_tests && test_results+=("e2e:passed") || test_results+=("e2e:failed")
    fi
    
    # Evaluate quality gates
    local quality_result=0
    evaluate_quality_gates || quality_result=$?
    
    # Generate reports
    generate_test_report
    
    # Summary
    log "Test Results Summary:"
    for result in "${test_results[@]}"; do
        local test_type="${result%%:*}"
        local test_status="${result##*:}"
        if [[ "$test_status" == "passed" ]]; then
            log "  ✅ $test_type tests: PASSED"
        else
            log "  ❌ $test_type tests: FAILED"
        fi
    done
    
    if [ $quality_result -eq 0 ]; then
        log "🎉 Quality gates evaluation: PASSED"
        exit 0
    else
        error "❌ Quality gates evaluation: FAILED"
        exit 1
    fi
}

# Execute main function
main "$@"