#!/bin/bash

# 参照整合性テスト自動検証スクリプト
# Reference Integrity Test Automation Script
# Role: QA Engineer - Automated Reference Integrity Testing
# Target: Zero Reference Errors Achievement
# Priority: High - Directory Structure Quality Assurance

set -euo pipefail

# スクリプト設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
REPORT_DIR="$SCRIPT_DIR/reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TEST_LOG="$LOG_DIR/reference-integrity-test_$TIMESTAMP.log"
REPORT_FILE="$REPORT_DIR/reference-integrity-report_$TIMESTAMP.json"

# ディレクトリ作成
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# テスト結果格納用
declare -A TEST_RESULTS
declare -A ERROR_COUNTS
declare -A PERFORMANCE_METRICS

# 設定
TIMEOUT=300
MAX_RETRIES=3
STRICT_MODE=true

# ログ関数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$TEST_LOG"
}

log_info() { log_message "INFO" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }

# エラーハンドリング
handle_error() {
    local line_number="$1"
    local error_code="$2"
    local command="$3"
    
    log_error "Error in line $line_number: Command '$command' failed with exit code $error_code"
    ERROR_COUNTS["script_errors"]=$((${ERROR_COUNTS["script_errors"]:-0} + 1))
}

trap 'handle_error $LINENO $? "$BASH_COMMAND"' ERR

# 1. データベース参照整合性テスト
test_database_references() {
    log_info "Testing database reference integrity..."
    
    local db_paths=(
        "/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/database/itsm.db"
        "/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/data/itsm.db"
        "/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/itsm.db"
        "$SCRIPT_DIR/data/itsm.db"
    )
    
    local found_dbs=0
    local accessible_dbs=0
    
    for db_path in "${db_paths[@]}"; do
        if [[ -f "$db_path" ]]; then
            found_dbs=$((found_dbs + 1))
            log_info "Found database: $db_path"
            
            # 読み取り権限確認
            if [[ -r "$db_path" ]]; then
                accessible_dbs=$((accessible_dbs + 1))
                log_info "Database accessible: $db_path"
                
                # SQLite形式確認
                if file "$db_path" | grep -q "SQLite"; then
                    log_success "Database format verified: $db_path"
                else
                    log_error "Invalid database format: $db_path"
                    ERROR_COUNTS["database_format_errors"]=$((${ERROR_COUNTS["database_format_errors"]:-0} + 1))
                fi
            else
                log_error "Database not accessible: $db_path"
                ERROR_COUNTS["database_access_errors"]=$((${ERROR_COUNTS["database_access_errors"]:-0} + 1))
            fi
        fi
    done
    
    TEST_RESULTS["database_references"]="$found_dbs/$accessible_dbs"
    
    if [[ $found_dbs -eq 0 ]]; then
        log_error "No database files found"
        return 1
    fi
    
    if [[ $accessible_dbs -eq 0 ]]; then
        log_error "No accessible database files"
        return 1
    fi
    
    log_success "Database reference test completed: $found_dbs found, $accessible_dbs accessible"
    return 0
}

# 2. TypeScript/JavaScript import整合性テスト
test_import_references() {
    log_info "Testing TypeScript/JavaScript import references..."
    
    local ts_files=(
        "$SCRIPT_DIR/POST_SWITCH_INTEGRATION_TEST.ts"
        "$SCRIPT_DIR/SERVER_SWITCH_INTEGRATION_TEST.ts"
        "$SCRIPT_DIR/AUTH_LIBRARY_DIAGNOSTIC.ts"
        "$SCRIPT_DIR/ERROR_RESPONSE_PATTERN_ANALYZER.ts"
        "$SCRIPT_DIR/DATABASE_CONNECTION_DIAGNOSTIC.ts"
        "$SCRIPT_DIR/API_COMMUNICATION_PATTERN_ANALYZER.ts"
        "$SCRIPT_DIR/EMERGENCY_COMPONENT_DIAGNOSTIC_SUITE.ts"
    )
    
    local total_imports=0
    local valid_imports=0
    local import_errors=0
    
    for file in "${ts_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "Checking imports in: $file"
            
            # import文の抽出
            local imports=$(grep -n "import.*from\|require(" "$file" || true)
            
            if [[ -n "$imports" ]]; then
                while IFS= read -r import_line; do
                    total_imports=$((total_imports + 1))
                    
                    # 相対パスの抽出
                    local import_path=$(echo "$import_line" | sed -n "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/p")
                    
                    if [[ "$import_path" =~ ^\.\.?/ ]]; then
                        # 相対パス解決
                        local resolved_path=$(cd "$(dirname "$file")" && realpath "$import_path" 2>/dev/null || echo "")
                        
                        if [[ -n "$resolved_path" && -f "$resolved_path" ]]; then
                            valid_imports=$((valid_imports + 1))
                            log_info "Valid import: $import_path -> $resolved_path"
                        else
                            import_errors=$((import_errors + 1))
                            log_error "Invalid import: $import_path in $file"
                        fi
                    else
                        # 絶対パスまたはモジュール名
                        valid_imports=$((valid_imports + 1))
                        log_info "Module import: $import_path"
                    fi
                done <<< "$imports"
            fi
        else
            log_warn "TypeScript file not found: $file"
        fi
    done
    
    TEST_RESULTS["import_references"]="$valid_imports/$total_imports"
    ERROR_COUNTS["import_errors"]=$import_errors
    
    if [[ $import_errors -gt 0 ]]; then
        log_error "Import reference test failed: $import_errors errors found"
        return 1
    fi
    
    log_success "Import reference test completed: $valid_imports/$total_imports valid"
    return 0
}

# 3. シェルスクリプト参照整合性テスト
test_shell_script_references() {
    log_info "Testing shell script references..."
    
    local shell_scripts=(
        "$SCRIPT_DIR/send-message.sh"
        "$SCRIPT_DIR/developer-activity-monitor.sh"
        "$SCRIPT_DIR/auto-start-servers.sh"
        "$SCRIPT_DIR/check-claude-status.sh"
        "$SCRIPT_DIR/start-servers.sh"
        "$SCRIPT_DIR/ui-dev-loop.sh"
    )
    
    local total_refs=0
    local valid_refs=0
    local script_errors=0
    
    for script in "${shell_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log_info "Checking script references in: $script"
            
            # 実行権限確認
            if [[ -x "$script" ]]; then
                log_info "Script is executable: $script"
            else
                log_warn "Script not executable: $script"
                script_errors=$((script_errors + 1))
            fi
            
            # ファイル参照の抽出
            local file_refs=$(grep -n "logs/\|data/\|scripts/\|instructions/" "$script" || true)
            
            if [[ -n "$file_refs" ]]; then
                while IFS= read -r ref_line; do
                    total_refs=$((total_refs + 1))
                    
                    # パスの抽出
                    local ref_path=$(echo "$ref_line" | grep -o '[^[:space:]]*\(logs\|data\|scripts\|instructions\)[^[:space:]]*' | head -1)
                    
                    if [[ -n "$ref_path" ]]; then
                        # 相対パス解決
                        local resolved_path=""
                        if [[ "$ref_path" = /* ]]; then
                            resolved_path="$ref_path"
                        else
                            resolved_path="$SCRIPT_DIR/$ref_path"
                        fi
                        
                        if [[ -e "$resolved_path" ]]; then
                            valid_refs=$((valid_refs + 1))
                            log_info "Valid reference: $ref_path -> $resolved_path"
                        else
                            script_errors=$((script_errors + 1))
                            log_error "Invalid reference: $ref_path in $script"
                        fi
                    fi
                done <<< "$file_refs"
            fi
        else
            log_warn "Shell script not found: $script"
        fi
    done
    
    TEST_RESULTS["shell_script_references"]="$valid_refs/$total_refs"
    ERROR_COUNTS["script_reference_errors"]=$script_errors
    
    if [[ $script_errors -gt 0 ]]; then
        log_error "Shell script reference test failed: $script_errors errors found"
        return 1
    fi
    
    log_success "Shell script reference test completed: $valid_refs/$total_refs valid"
    return 0
}

# 4. ディレクトリ構造整合性テスト
test_directory_structure() {
    log_info "Testing directory structure integrity..."
    
    local required_dirs=(
        "logs"
        "data"
        "scripts"
        "instructions"
        "screenshots"
        "tmux_Docs"
        "ui-baseline"
        "ui-reports"
        "instructions_backup"
    )
    
    local existing_dirs=0
    local missing_dirs=0
    
    for dir in "${required_dirs[@]}"; do
        local full_path="$SCRIPT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            existing_dirs=$((existing_dirs + 1))
            log_info "Directory exists: $dir"
            
            # 権限確認
            if [[ -r "$full_path" && -w "$full_path" ]]; then
                log_info "Directory accessible: $dir"
            else
                log_warn "Directory permission issues: $dir"
                ERROR_COUNTS["directory_permission_errors"]=$((${ERROR_COUNTS["directory_permission_errors"]:-0} + 1))
            fi
        else
            missing_dirs=$((missing_dirs + 1))
            log_error "Directory missing: $dir"
        fi
    done
    
    TEST_RESULTS["directory_structure"]="$existing_dirs/$((existing_dirs + missing_dirs))"
    
    if [[ $missing_dirs -gt 0 ]]; then
        log_error "Directory structure test failed: $missing_dirs missing directories"
        return 1
    fi
    
    log_success "Directory structure test completed: $existing_dirs directories verified"
    return 0
}

# 5. 機能テスト
test_functionality() {
    log_info "Testing core functionality..."
    
    local start_time=$(date +%s)
    local functional_tests=(
        "test_send_message_script"
        "test_log_file_creation"
        "test_database_access"
        "test_script_execution"
    )
    
    local passed_tests=0
    local total_tests=${#functional_tests[@]}
    
    for test in "${functional_tests[@]}"; do
        log_info "Running functional test: $test"
        
        if eval "$test"; then
            passed_tests=$((passed_tests + 1))
            log_success "Functional test passed: $test"
        else
            log_error "Functional test failed: $test"
            ERROR_COUNTS["functional_errors"]=$((${ERROR_COUNTS["functional_errors"]:-0} + 1))
        fi
    done
    
    local end_time=$(date +%s)
    PERFORMANCE_METRICS["functional_test_duration"]=$((end_time - start_time))
    
    TEST_RESULTS["functionality"]="$passed_tests/$total_tests"
    
    if [[ $passed_tests -lt $total_tests ]]; then
        log_error "Functionality test failed: $passed_tests/$total_tests passed"
        return 1
    fi
    
    log_success "Functionality test completed: $passed_tests/$total_tests passed"
    return 0
}

# 機能テスト実装
test_send_message_script() {
    local script="$SCRIPT_DIR/send-message.sh"
    
    if [[ -f "$script" && -x "$script" ]]; then
        # テストモード実行
        if "$script" --help &>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

test_log_file_creation() {
    local test_log="$LOG_DIR/test_$$"
    
    if echo "test" > "$test_log" 2>/dev/null; then
        rm -f "$test_log"
        return 0
    fi
    
    return 1
}

test_database_access() {
    local db_file="$SCRIPT_DIR/data/itsm.db"
    
    if [[ -f "$db_file" && -r "$db_file" ]]; then
        # SQLite形式確認
        if file "$db_file" | grep -q "SQLite"; then
            return 0
        fi
    fi
    
    return 1
}

test_script_execution() {
    local script="$SCRIPT_DIR/check-claude-status.sh"
    
    if [[ -f "$script" && -x "$script" ]]; then
        # 構文チェック
        if bash -n "$script" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# 6. パフォーマンステスト
test_performance() {
    log_info "Testing performance metrics..."
    
    local start_time=$(date +%s)
    local memory_before=$(free -m | awk '/^Mem:/{print $3}')
    
    # 負荷テスト
    for i in {1..10}; do
        test_database_references &>/dev/null
        test_import_references &>/dev/null
    done
    
    local end_time=$(date +%s)
    local memory_after=$(free -m | awk '/^Mem:/{print $3}')
    
    PERFORMANCE_METRICS["test_duration"]=$((end_time - start_time))
    PERFORMANCE_METRICS["memory_usage"]=$((memory_after - memory_before))
    
    log_success "Performance test completed: ${PERFORMANCE_METRICS["test_duration"]}s duration, ${PERFORMANCE_METRICS["memory_usage"]}MB memory"
    return 0
}

# 7. レポート生成
generate_report() {
    log_info "Generating comprehensive test report..."
    
    local total_errors=0
    for count in "${ERROR_COUNTS[@]}"; do
        total_errors=$((total_errors + count))
    done
    
    local overall_status="PASS"
    if [[ $total_errors -gt 0 ]]; then
        overall_status="FAIL"
    fi
    
    # JSON形式でレポート生成
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overall_status": "$overall_status",
  "total_errors": $total_errors,
  "test_results": {
$(for key in "${!TEST_RESULTS[@]}"; do
    echo "    \"$key\": \"${TEST_RESULTS[$key]}\","
done | sed '$ s/,$//')
  },
  "error_counts": {
$(for key in "${!ERROR_COUNTS[@]}"; do
    echo "    \"$key\": ${ERROR_COUNTS[$key]:-0},"
done | sed '$ s/,$//')
  },
  "performance_metrics": {
$(for key in "${!PERFORMANCE_METRICS[@]}"; do
    echo "    \"$key\": ${PERFORMANCE_METRICS[$key]:-0},"
done | sed '$ s/,$//')
  },
  "recommendations": [
$(if [[ $total_errors -gt 0 ]]; then
    echo "    \"Fix $total_errors reference integrity errors\","
fi)
$(if [[ ${ERROR_COUNTS["import_errors"]:-0} -gt 0 ]]; then
    echo "    \"Resolve import reference issues\","
fi)
$(if [[ ${ERROR_COUNTS["database_access_errors"]:-0} -gt 0 ]]; then
    echo "    \"Fix database access permissions\","
fi)
    "Continue monitoring reference integrity"
  ]
}
EOF
    
    log_success "Report generated: $REPORT_FILE"
}

# 8. メイン実行関数
main() {
    log_info "Starting Reference Integrity Test Suite..."
    log_info "Script Directory: $SCRIPT_DIR"
    log_info "Log File: $TEST_LOG"
    log_info "Report File: $REPORT_FILE"
    
    local start_time=$(date +%s)
    local failed_tests=0
    
    # テスト実行
    local tests=(
        "test_database_references"
        "test_import_references"
        "test_shell_script_references"
        "test_directory_structure"
        "test_functionality"
        "test_performance"
    )
    
    for test in "${tests[@]}"; do
        log_info "Executing test: $test"
        
        if ! "$test"; then
            failed_tests=$((failed_tests + 1))
            log_error "Test failed: $test"
        fi
    done
    
    local end_time=$(date +%s)
    PERFORMANCE_METRICS["total_duration"]=$((end_time - start_time))
    
    # レポート生成
    generate_report
    
    # 結果サマリー
    log_info "=== Test Summary ==="
    log_info "Total Tests: ${#tests[@]}"
    log_info "Failed Tests: $failed_tests"
    log_info "Duration: ${PERFORMANCE_METRICS["total_duration"]}s"
    log_info "Report: $REPORT_FILE"
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All reference integrity tests passed! ✅"
        exit 0
    else
        log_error "Reference integrity tests failed: $failed_tests failures ❌"
        exit 1
    fi
}

# コマンドライン引数処理
case "${1:-run}" in
    "run")
        main
        ;;
    "database")
        test_database_references
        ;;
    "imports")
        test_import_references
        ;;
    "scripts")
        test_shell_script_references
        ;;
    "structure")
        test_directory_structure
        ;;
    "functionality")
        test_functionality
        ;;
    "performance")
        test_performance
        ;;
    "report")
        generate_report
        ;;
    *)
        echo "Usage: $0 {run|database|imports|scripts|structure|functionality|performance|report}"
        echo ""
        echo "Commands:"
        echo "  run          - Run all tests (default)"
        echo "  database     - Test database references"
        echo "  imports      - Test import references"
        echo "  scripts      - Test shell script references"
        echo "  structure    - Test directory structure"
        echo "  functionality - Test core functionality"
        echo "  performance  - Test performance metrics"
        echo "  report       - Generate report only"
        exit 1
        ;;
esac