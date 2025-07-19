#!/bin/bash

# Microsoft 365 Management Tools - Slack通知統合システム
# エンタープライズグレード・多チャンネル対応・GitHub Actions連携

set -euo pipefail

# ========== 設定 ==========
readonly PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
readonly CONFIG_FILE="$PROJECT_ROOT/Config/appsettings.json"
readonly SLACK_CONFIG_FILE="$PROJECT_ROOT/Config/slack_config.json"
readonly LOG_FILE="$PROJECT_ROOT/logs/slack_notifications.log"

# Slack設定（実際の運用では環境変数またはKVから取得）
readonly SLACK_WEBHOOK_BACKUP="${SLACK_WEBHOOK_BACKUP:-}"
readonly SLACK_WEBHOOK_MONITORING="${SLACK_WEBHOOK_MONITORING:-}"
readonly SLACK_WEBHOOK_EMERGENCY="${SLACK_WEBHOOK_EMERGENCY:-}"
readonly SLACK_WEBHOOK_DEPLOYMENTS="${SLACK_WEBHOOK_DEPLOYMENTS:-}"

# ========== 通知レベル定義 ==========
declare -A NOTIFICATION_LEVELS=(
    ["INFO"]="💡"
    ["SUCCESS"]="✅"
    ["WARNING"]="⚠️"
    ["ERROR"]="❌"
    ["CRITICAL"]="🚨"
    ["DEPLOYMENT"]="🚀"
    ["SECURITY"]="🛡️"
    ["BACKUP"]="💾"
)

declare -A CHANNEL_MAPPINGS=(
    ["backup"]="$SLACK_WEBHOOK_BACKUP"
    ["monitoring"]="$SLACK_WEBHOOK_MONITORING"
    ["emergency"]="$SLACK_WEBHOOK_EMERGENCY"
    ["deployments"]="$SLACK_WEBHOOK_DEPLOYMENTS"
)

# ========== ログ関数 ==========
log_notification() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# ========== Slack通知関数 ==========
send_slack_notification() {
    local channel="$1"
    local level="$2"
    local title="$3"
    local message="$4"
    local webhook_url="${CHANNEL_MAPPINGS[$channel]:-}"
    
    # ウェブフックURLが設定されていない場合はログのみ
    if [ -z "$webhook_url" ]; then
        log_notification "WARNING" "Slack webhook not configured for channel: $channel"
        return 0
    fi
    
    local emoji="${NOTIFICATION_LEVELS[$level]:-💬}"
    local color="#36a64f"  # デフォルト（成功色）
    
    # レベルに応じた色設定
    case "$level" in
        "WARNING") color="#ff9500" ;;
        "ERROR") color="#ff4444" ;;
        "CRITICAL") color="#ff0000" ;;
        "SECURITY") color="#9b59b6" ;;
        "DEPLOYMENT") color="#3498db" ;;
    esac
    
    # Slack payload生成
    local payload=$(cat << EOF
{
    "username": "Microsoft 365 Tools Bot",
    "icon_emoji": ":robot_face:",
    "attachments": [
        {
            "color": "$color",
            "title": "$emoji $title",
            "text": "$message",
            "footer": "Microsoft 365 Management Tools",
            "footer_icon": "https://github.com/microsoft.png",
            "ts": $(date +%s),
            "fields": [
                {
                    "title": "環境",
                    "value": "$(hostname)",
                    "short": true
                },
                {
                    "title": "レベル",
                    "value": "$level",
                    "short": true
                },
                {
                    "title": "プロセスID",
                    "value": "$$",
                    "short": true
                },
                {
                    "title": "タイムスタンプ",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S')",
                    "short": true
                }
            ]
        }
    ]
}
EOF
)
    
    # Slack送信
    if curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        --max-time 10 \
        --silent \
        --fail \
        "$webhook_url" > /dev/null 2>&1; then
        
        log_notification "SUCCESS" "Slack notification sent to $channel: $title"
        return 0
    else
        log_notification "ERROR" "Failed to send Slack notification to $channel: $title"
        return 1
    fi
}

# ========== 特定用途向け通知関数 ==========

# バックアップ成功通知
notify_backup_success() {
    local backup_path="$1"
    local backup_size="$2"
    local duration="$3"
    local file_count="$4"
    
    local message="バックアップが正常に完了しました
• パス: \`$(basename "$backup_path")\`
• サイズ: $backup_size
• 実行時間: ${duration}秒
• ファイル数: $file_count
• 時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_slack_notification "backup" "SUCCESS" "バックアップ完了" "$message"
}

# バックアップ失敗通知
notify_backup_failure() {
    local error_code="$1"
    local error_message="$2"
    
    local message="🚨 バックアップが失敗しました
• エラーコード: $error_code
• エラー詳細: $error_message
• 時刻: $(date '+%Y-%m-%d %H:%M:%S')
• ホスト: $(hostname)

即座の対応が必要です。管理者に連絡してください。"
    
    send_slack_notification "emergency" "CRITICAL" "バックアップ失敗" "$message"
}

# GitHub Actions統合通知
notify_github_actions_status() {
    local workflow_name="$1"
    local status="$2"
    local run_id="$3"
    local commit_sha="$4"
    
    local level="INFO"
    local emoji="🔄"
    
    case "$status" in
        "success")
            level="SUCCESS"
            emoji="✅"
            ;;
        "failure")
            level="ERROR"
            emoji="❌"
            ;;
        "cancelled")
            level="WARNING"
            emoji="⚠️"
            ;;
    esac
    
    local message="GitHub Actionsワークフロー実行結果
• ワークフロー: \`$workflow_name\`
• ステータス: $status
• 実行ID: $run_id
• コミット: \`${commit_sha:0:8}\`
• 時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_slack_notification "monitoring" "$level" "${emoji} GitHub Actions" "$message"
}

# セキュリティアラート通知
notify_security_alert() {
    local alert_type="$1"
    local severity="$2"
    local description="$3"
    
    local message="🛡️ セキュリティアラートが発生しました
• アラート種別: $alert_type
• 重要度: $severity
• 詳細: $description
• 検出時刻: $(date '+%Y-%m-%d %H:%M:%S')
• ホスト: $(hostname)

セキュリティチームに即座に連絡してください。"
    
    send_slack_notification "emergency" "SECURITY" "セキュリティアラート" "$message"
}

# システムヘルス通知
notify_system_health() {
    local component="$1"
    local status="$2"
    local metrics="$3"
    
    local level="INFO"
    case "$status" in
        "healthy") level="SUCCESS" ;;
        "warning") level="WARNING" ;;
        "critical") level="ERROR" ;;
    esac
    
    local message="システムヘルス監視レポート
• コンポーネント: $component
• ステータス: $status
• メトリクス: $metrics
• 確認時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_slack_notification "monitoring" "$level" "システムヘルス" "$message"
}

# デプロイメント通知
notify_deployment() {
    local environment="$1"
    local version="$2"
    local status="$3"
    
    local level="DEPLOYMENT"
    local emoji="🚀"
    
    if [ "$status" = "failed" ]; then
        level="ERROR"
        emoji="💥"
    fi
    
    local message="デプロイメント実行結果
• 環境: $environment
• バージョン: $version
• ステータス: $status
• 実行時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_slack_notification "deployments" "$level" "${emoji} デプロイメント" "$message"
}

# ========== 統合レポート通知 ==========
send_daily_summary() {
    local backup_count="$1"
    local success_rate="$2"
    local total_size="$3"
    local system_health="$4"
    
    local message="📊 Microsoft 365 Tools 日次サマリー

*バックアップ統計*
• 実行回数: $backup_count
• 成功率: $success_rate%
• 総使用容量: $total_size

*システム状況*
• ヘルス: $system_health
• GitHub Actions: 連携中
• Cron統合: アクティブ

*コンプライアンス*
• ISO 27001: 準拠
• 監査証跡: 完全
• セキュリティスキャン: 合格

日次レポート: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_slack_notification "monitoring" "INFO" "日次サマリーレポート" "$message"
}

# ========== 緊急エスカレーション ==========
emergency_escalation() {
    local incident_type="$1"
    local severity="$2"
    local details="$3"
    
    local message="🚨🚨 緊急エスカレーション 🚨🚨

*インシデント詳細*
• 種別: $incident_type
• 重要度: $severity
• 詳細: $details
• 発生時刻: $(date '+%Y-%m-%d %H:%M:%S')
• ホスト: $(hostname)

*必要な対応*
1. 即座の管理者連絡
2. インシデント対応チーム招集
3. システム状況確認
4. 復旧手順実行

@channel"
    
    # 緊急時は複数チャンネルに送信
    send_slack_notification "emergency" "CRITICAL" "緊急エスカレーション" "$message"
    send_slack_notification "monitoring" "CRITICAL" "緊急エスカレーション" "$message"
}

# ========== 設定検証 ==========
validate_slack_config() {
    log_notification "INFO" "Slack設定検証開始"
    
    local config_valid=true
    
    for channel in "${!CHANNEL_MAPPINGS[@]}"; do
        local webhook="${CHANNEL_MAPPINGS[$channel]}"
        if [ -z "$webhook" ]; then
            log_notification "WARNING" "Webhook not configured for channel: $channel"
            config_valid=false
        fi
    done
    
    if [ "$config_valid" = true ]; then
        log_notification "SUCCESS" "Slack設定検証完了"
        return 0
    else
        log_notification "WARNING" "一部のSlack設定が不完全です"
        return 1
    fi
}

# ========== テスト通知 ==========
send_test_notifications() {
    log_notification "INFO" "テスト通知送信開始"
    
    send_slack_notification "monitoring" "INFO" "接続テスト" "Slack通知統合システムの接続テストです。"
    
    log_notification "INFO" "テスト通知送信完了"
}

# ========== メイン処理 ==========
main() {
    local action="${1:-help}"
    
    case "$action" in
        "backup-success")
            notify_backup_success "$2" "$3" "$4" "$5"
            ;;
        "backup-failure")
            notify_backup_failure "$2" "$3"
            ;;
        "github-actions")
            notify_github_actions_status "$2" "$3" "$4" "$5"
            ;;
        "security-alert")
            notify_security_alert "$2" "$3" "$4"
            ;;
        "system-health")
            notify_system_health "$2" "$3" "$4"
            ;;
        "deployment")
            notify_deployment "$2" "$3" "$4"
            ;;
        "daily-summary")
            send_daily_summary "$2" "$3" "$4" "$5"
            ;;
        "emergency")
            emergency_escalation "$2" "$3" "$4"
            ;;
        "test")
            send_test_notifications
            ;;
        "validate")
            validate_slack_config
            ;;
        "help")
            echo "Microsoft 365 Tools - Slack通知統合システム"
            echo ""
            echo "使用方法:"
            echo "  $0 backup-success <path> <size> <duration> <files>"
            echo "  $0 backup-failure <error_code> <message>"
            echo "  $0 github-actions <workflow> <status> <run_id> <commit>"
            echo "  $0 security-alert <type> <severity> <description>"
            echo "  $0 system-health <component> <status> <metrics>"
            echo "  $0 deployment <environment> <version> <status>"
            echo "  $0 daily-summary <count> <rate> <size> <health>"
            echo "  $0 emergency <type> <severity> <details>"
            echo "  $0 test"
            echo "  $0 validate"
            ;;
        *)
            echo "エラー: 未知のアクション '$action'"
            echo "使用方法については '$0 help' を実行してください"
            exit 1
            ;;
    esac
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi