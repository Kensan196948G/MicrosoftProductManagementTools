#!/bin/bash

# generate-exchange-forwarding-report.sh
# Exchange Online 自動転送・返信設定確認レポート生成
# ITSM/ISO27001/27002準拠

set -e

# プロジェクト設定
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_DIR="${PROJECT_ROOT}/Logs"
REPORT_DIR="${PROJECT_ROOT}/Reports/Daily"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ロギング関数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_DIR}/exchange_forwarding_${TIMESTAMP}.log"
}

# エラーハンドリング
error_exit() {
    log_message "ERROR" "$1"
    echo -e "${RED}❌ エラー: $1${NC}"
    exit 1
}

# 前提条件チェック
check_prerequisites() {
    log_message "INFO" "前提条件をチェック中..."
    
    # PowerShellの存在確認
    if ! command -v pwsh &> /dev/null; then
        error_exit "PowerShellが見つかりません。PowerShell 7をインストールしてください。"
    fi
    
    # ディレクトリ存在確認
    if [[ ! -d "$REPORT_DIR" ]]; then
        log_message "INFO" "レポートディレクトリを作成中: $REPORT_DIR"
        mkdir -p "$REPORT_DIR"
    fi
    
    if [[ ! -d "$LOG_DIR" ]]; then
        log_message "INFO" "ログディレクトリを作成中: $LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi
    
    # Exchange Onlineモジュールファイルの存在確認
    if [[ ! -f "${PROJECT_ROOT}/Scripts/EXO/ExchangeManagement-NEW.psm1" ]]; then
        error_exit "Exchange Online管理モジュールが見つかりません: Scripts/EXO/ExchangeManagement-NEW.psm1"
    fi
    
    log_message "INFO" "前提条件チェック完了"
}

# メイン処理
main() {
    echo -e "${ORANGE}=================================================================================${NC}"
    echo -e "${WHITE}    Exchange Online 自動転送・返信設定確認レポート生成${NC}"
    echo -e "${WHITE}    ITSM/ISO27001/27002準拠セキュリティ監査${NC}"
    echo -e "${ORANGE}=================================================================================${NC}"
    echo ""
    
    log_message "INFO" "Exchange Online自動転送・返信設定確認レポート生成を開始"
    
    # 前提条件チェック
    check_prerequisites
    
    # Exchange Online機能実行
    echo -e "${BLUE}🔄 Exchange Online自動転送・返信設定を分析中...${NC}"
    log_message "INFO" "PowerShellスクリプト実行開始"
    
    # PowerShellスクリプト実行
    local ps_script="
        try {
            # 作業ディレクトリ設定
            Set-Location '${PROJECT_ROOT}'
            
            # モジュール読み込み
            Import-Module './Scripts/Common/Common.psm1' -Force -ErrorAction Stop
            Import-Module './Scripts/EXO/ExchangeManagement-NEW.psm1' -Force -ErrorAction Stop
            
            Write-Host '✅ モジュール読み込み完了' -ForegroundColor Green
            
            # 自動転送・返信設定確認実行
            Write-Host '🔍 自動転送・返信設定確認を実行中...' -ForegroundColor Cyan
            \$result = Get-ForwardingAndAutoReplySettings -ExportCSV -ExportHTML -ShowDetails
            
            if (\$result.Success) {
                Write-Host '✅ 分析完了' -ForegroundColor Green
                Write-Host \"📊 総メールボックス数: \$(\$result.TotalMailboxes)\" -ForegroundColor White
                Write-Host \"📨 転送設定あり: \$(\$result.ForwardingCount)\" -ForegroundColor Yellow
                Write-Host \"🤖 自動応答設定あり: \$(\$result.AutoReplyCount)\" -ForegroundColor Yellow
                Write-Host \"⚠️  外部転送あり: \$(\$result.ExternalForwardingCount)\" -ForegroundColor Red
                Write-Host \"🔥 リスク検出: \$(\$result.RiskCount)\" -ForegroundColor Red
                
                if (\$result.OutputPath) {
                    Write-Host \"📄 CSVレポート: \$(\$result.OutputPath)\" -ForegroundColor Cyan
                }
                if (\$result.HTMLOutputPath) {
                    Write-Host \"🌐 HTMLレポート: \$(\$result.HTMLOutputPath)\" -ForegroundColor Cyan
                }
                
                # 成功終了コード
                exit 0
            } else {
                Write-Host \"❌ エラーが発生しました: \$(\$result.Error)\" -ForegroundColor Red
                exit 1
            }
        }
        catch {
            Write-Host \"❌ PowerShell実行エラー: \$(\$_.Exception.Message)\" -ForegroundColor Red
            Write-Host \"スタックトレース: \$(\$_.ScriptStackTrace)\" -ForegroundColor Red
            exit 1
        }
    "
    
    # PowerShell実行
    if pwsh -NoProfile -Command "$ps_script"; then
        echo ""
        echo -e "${GREEN}✅ Exchange Online自動転送・返信設定確認が正常に完了しました${NC}"
        log_message "INFO" "Exchange Online自動転送・返信設定確認完了"
        
        # 生成されたレポートファイルを確認
        echo ""
        echo -e "${CYAN}📋 生成されたレポートファイル:${NC}"
        find "$REPORT_DIR" -name "*Forwarding_AutoReply_Settings*" -newermt "1 minute ago" 2>/dev/null | while read -r file; do
            echo -e "  ${WHITE}📄 $(basename "$file")${NC} ($(stat -c%s "$file" 2>/dev/null || echo "0") bytes)"
        done
        
        # セキュリティアラート
        echo ""
        echo -e "${YELLOW}🔒 セキュリティ監査のポイント:${NC}"
        echo -e "  • 外部転送設定は情報漏洩リスクがあります"
        echo -e "  • 長期間設定された自動応答は要確認です"
        echo -e "  • インボックスルールによる自動転送も監視対象です"
        echo -e "  • 定期的な設定見直しを推奨します"
        
    else
        error_exit "PowerShellスクリプトの実行に失敗しました"
    fi
    
    echo ""
    echo -e "${ORANGE}=================================================================================${NC}"
    echo -e "${WHITE}Exchange Online自動転送・返信設定確認レポート生成が完了しました${NC}"
    echo -e "${WHITE}生成時刻: $(date '+%Y年%m月%d日 %H:%M:%S')${NC}"
    echo -e "${ORANGE}=================================================================================${NC}"
    
    log_message "INFO" "Exchange Online自動転送・返信設定確認レポート生成処理完了"
}

# オプション処理
case "${1:-}" in
    --help|-h)
        echo "Exchange Online 自動転送・返信設定確認レポート生成"
        echo ""
        echo "使用法: $0 [オプション]"
        echo ""
        echo "オプション:"
        echo "  --help, -h     このヘルプを表示"
        echo "  --verbose, -v  詳細ログを表示"
        echo "  --quiet, -q    静寂モード（エラーのみ表示）"
        echo ""
        echo "説明:"
        echo "  Exchange Onlineの全メールボックスの自動転送・返信設定を確認し、"
        echo "  セキュリティリスクを評価してCSV/HTMLレポートを生成します。"
        echo ""
        echo "出力ファイル:"
        echo "  - Reports/Daily/Forwarding_AutoReply_Settings_YYYYMMDD_HHMMSS.csv"
        echo "  - Reports/Daily/Forwarding_AutoReply_Settings_YYYYMMDD_HHMMSS.html"
        echo "  - Logs/exchange_forwarding_YYYYMMDD_HHMMSS.log"
        exit 0
        ;;
    --verbose|-v)
        set -x
        ;;
    --quiet|-q)
        exec 1>/dev/null
        ;;
esac

# メイン処理実行
main "$@"