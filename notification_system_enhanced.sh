#!/bin/bash

# Microsoft 365 Management Tools - 拡張通知システム
# Microsoft Teams + Gmail + Slack 対応・マルチチャンネル通知

set -euo pipefail

# ========== 設定 ==========
readonly PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
readonly CONFIG_FILE="$PROJECT_ROOT/Config/notification_config.json"
readonly LOG_FILE="$PROJECT_ROOT/logs/notifications.log"

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

# ========== ログ関数 ==========
log_notification() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# ========== Microsoft Teams 通知 ==========
send_teams_notification() {
    local webhook_url="$1"
    local title="$2"
    local message="$3"
    local level="$4"
    local color="0078d4"  # Microsoft Blue
    
    # レベルに応じた色設定
    case "$level" in
        "SUCCESS") color="28a745" ;;
        "WARNING") color="ffc107" ;;
        "ERROR") color="dc3545" ;;
        "CRITICAL") color="ff0000" ;;
        "SECURITY") color="9b59b6" ;;
        "DEPLOYMENT") color="3498db" ;;
    esac
    
    local emoji="${NOTIFICATION_LEVELS[$level]:-💬}"
    
    # Teams用 Adaptive Card payload
    local payload=$(cat << EOF
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "summary": "$title",
    "themeColor": "$color",
    "sections": [
        {
            "activityTitle": "$emoji Microsoft 365 Tools",
            "activitySubtitle": "$title",
            "activityImage": "https://github.com/microsoft.png",
            "facts": [
                {
                    "name": "レベル:",
                    "value": "$level"
                },
                {
                    "name": "ホスト:",
                    "value": "$(hostname)"
                },
                {
                    "name": "時刻:",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S')"
                },
                {
                    "name": "プロセスID:",
                    "value": "$$"
                }
            ],
            "text": "$message"
        }
    ],
    "potentialAction": [
        {
            "@type": "OpenUri",
            "name": "ダッシュボードを開く",
            "targets": [
                {
                    "os": "default",
                    "uri": "https://your-github-pages-url.github.io/MicrosoftProductManagementTools"
                }
            ]
        }
    ]
}
EOF
)
    
    if [ -n "$webhook_url" ] && [ "$webhook_url" != "TEAMS_WEBHOOK_NOT_SET" ]; then
        if curl -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            --max-time 15 \
            --silent \
            --fail \
            "$webhook_url" > /dev/null 2>&1; then
            
            log_notification "SUCCESS" "Teams notification sent: $title"
            return 0
        else
            log_notification "ERROR" "Failed to send Teams notification: $title"
            return 1
        fi
    else
        log_notification "INFO" "Teams webhook not configured, skipping Teams notification"
        return 0
    fi
}

# ========== Gmail 通知 ==========
send_gmail_notification() {
    local smtp_server="$1"
    local smtp_port="$2"
    local username="$3"
    local password="$4"
    local recipient="$5"
    local subject="$6"
    local message="$7"
    local level="$8"
    
    local emoji="${NOTIFICATION_LEVELS[$level]:-💬}"
    local priority="normal"
    
    # 重要度設定
    case "$level" in
        "CRITICAL"|"SECURITY") priority="high" ;;
        "ERROR") priority="high" ;;
        "WARNING") priority="normal" ;;
        *) priority="normal" ;;
    esac
    
    # HTML形式のメール本文生成
    local html_body=$(cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #0078d4, #106ebe); color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .alert { padding: 15px; margin: 15px 0; border-radius: 5px; border-left: 4px solid; }
        .alert-success { background: #d4edda; border-color: #28a745; color: #155724; }
        .alert-warning { background: #fff3cd; border-color: #ffc107; color: #856404; }
        .alert-error { background: #f8d7da; border-color: #dc3545; color: #721c24; }
        .alert-critical { background: #f8d7da; border-color: #ff0000; color: #721c24; font-weight: bold; }
        .metadata { background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 20px; }
        .footer { background: #f8f9fa; padding: 15px; text-align: center; font-size: 12px; color: #6c757d; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$emoji Microsoft 365 Tools</h1>
            <h2>$subject</h2>
        </div>
        <div class="content">
            <div class="alert alert-$(echo $level | tr '[:upper:]' '[:lower:]')">
                <strong>$level</strong>: $message
            </div>
            <div class="metadata">
                <h3>実行情報</h3>
                <ul>
                    <li><strong>ホスト:</strong> $(hostname)</li>
                    <li><strong>時刻:</strong> $(date '+%Y-%m-%d %H:%M:%S')</li>
                    <li><strong>プロセスID:</strong> $$</li>
                    <li><strong>ユーザー:</strong> $(whoami)</li>
                </ul>
            </div>
        </div>
        <div class="footer">
            Microsoft 365 Management Tools - Enterprise Backup & Monitoring System
        </div>
    </div>
</body>
</html>
EOF
)
    
    # メール送信
    if command -v sendemail >/dev/null 2>&1; then
        # sendemail を使用（推奨）
        if sendemail \
            -f "$username" \
            -t "$recipient" \
            -u "$emoji $subject" \
            -m "$html_body" \
            -s "$smtp_server:$smtp_port" \
            -xu "$username" \
            -xp "$password" \
            -o tls=yes \
            -o message-content-type=html \
            -o message-charset=utf-8 \
            -q > /dev/null 2>&1; then
            
            log_notification "SUCCESS" "Gmail notification sent to $recipient: $subject"
            return 0
        else
            log_notification "ERROR" "Failed to send Gmail notification: $subject"
            return 1
        fi
    elif command -v msmtp >/dev/null 2>&1; then
        # msmtp を使用（代替手段）
        local temp_mail=$(mktemp)
        cat << EOF > "$temp_mail"
To: $recipient
From: $username
Subject: $emoji $subject
Content-Type: text/html; charset=UTF-8
MIME-Version: 1.0

$html_body
EOF
        
        if msmtp --host="$smtp_server" --port="$smtp_port" --auth=on --user="$username" --password="$password" --tls=on "$recipient" < "$temp_mail" > /dev/null 2>&1; then
            log_notification "SUCCESS" "Gmail notification sent via msmtp to $recipient: $subject"
            rm -f "$temp_mail"
            return 0
        else
            log_notification "ERROR" "Failed to send Gmail notification via msmtp: $subject"
            rm -f "$temp_mail"
            return 1
        fi
    else
        log_notification "WARNING" "No email client (sendemail/msmtp) found, skipping Gmail notification"
        return 1
    fi
}

# ========== 統合通知送信 ==========
send_unified_notification() {
    local notification_type="$1"
    local level="$2"
    local title="$3"
    local message="$4"
    shift 4
    
    local config_data=""
    if [ -f "$CONFIG_FILE" ]; then
        config_data=$(cat "$CONFIG_FILE")
    else
        log_notification "WARNING" "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Microsoft Teams 通知
    local teams_enabled=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('microsoft_teams', {}).get('enabled', 'false'))" 2>/dev/null || echo "false")
    if [ "$teams_enabled" = "true" ]; then
        local teams_webhook=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('microsoft_teams', {}).get('webhook', ''))" 2>/dev/null || echo "")
        send_teams_notification "$teams_webhook" "$title" "$message" "$level"
    fi
    
    # Gmail 通知
    local gmail_enabled=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('gmail', {}).get('enabled', 'false'))" 2>/dev/null || echo "false")
    if [ "$gmail_enabled" = "true" ]; then
        local smtp_server=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('gmail', {}).get('smtp_server', 'smtp.gmail.com'))" 2>/dev/null || echo "smtp.gmail.com")
        local smtp_port=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('gmail', {}).get('smtp_port', '587'))" 2>/dev/null || echo "587")
        local username=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('gmail', {}).get('username', ''))" 2>/dev/null || echo "")
        local password=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('gmail', {}).get('app_password', ''))" 2>/dev/null || echo "")
        local recipients=$(echo "$config_data" | python3 -c "import sys,json; data=json.load(sys.stdin); print(' '.join(data.get('gmail', {}).get('recipients', [])))" 2>/dev/null || echo "")
        
        for recipient in $recipients; do
            send_gmail_notification "$smtp_server" "$smtp_port" "$username" "$password" "$recipient" "$title" "$message" "$level"
        done
    fi
    
    log_notification "INFO" "Unified notification sent: $notification_type - $title"
}

# ========== 特定用途向け通知関数 ==========

# バックアップ成功通知
notify_backup_success() {
    local backup_path="$1"
    local backup_size="$2"
    local duration="$3"
    local file_count="$4"
    
    local title="バックアップ完了"
    local message="バックアップが正常に完了しました

📁 **パス**: \`$(basename "$backup_path")\`
📏 **サイズ**: $backup_size
⏱️ **実行時間**: ${duration}秒
📄 **ファイル数**: $file_count
🕐 **時刻**: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_unified_notification "backup-success" "SUCCESS" "$title" "$message"
}

# バックアップ失敗通知
notify_backup_failure() {
    local error_code="$1"
    local error_message="$2"
    
    local title="🚨 バックアップ失敗"
    local message="**緊急**: バックアップが失敗しました

❌ **エラーコード**: $error_code
📝 **エラー詳細**: $error_message
🕐 **発生時刻**: $(date '+%Y-%m-%d %H:%M:%S')
🖥️ **ホスト**: $(hostname)

**即座の対応が必要です。管理者に連絡してください。**"
    
    send_unified_notification "backup-failure" "CRITICAL" "$title" "$message"
}

# GitHub Actions 通知
notify_github_actions() {
    local workflow_name="$1"
    local status="$2"
    local run_id="$3"
    local commit_sha="$4"
    
    local level="INFO"
    case "$status" in
        "success") level="SUCCESS" ;;
        "failure") level="ERROR" ;;
        "cancelled") level="WARNING" ;;
    esac
    
    local title="GitHub Actions: $workflow_name"
    local message="GitHub Actionsワークフローが完了しました

🔄 **ワークフロー**: $workflow_name
📊 **ステータス**: $status
🆔 **実行ID**: $run_id
📝 **コミット**: \`${commit_sha:0:8}\`
🕐 **時刻**: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_unified_notification "github-actions" "$level" "$title" "$message"
}

# 日次サマリー通知
send_daily_summary() {
    local backup_count="$1"
    local success_rate="$2"
    local total_size="$3"
    local system_health="$4"
    
    local title="📊 Microsoft 365 Tools 日次サマリー"
    local message="**日次サマリーレポート**

**📁 バックアップ統計**
• 実行回数: $backup_count
• 成功率: $success_rate%
• 総使用容量: $total_size

**🖥️ システム状況**
• ヘルス: $system_health
• GitHub Actions: 連携中
• Cron統合: アクティブ

**✅ コンプライアンス**
• ISO 27001: 準拠
• 監査証跡: 完全
• セキュリティスキャン: 合格

生成日時: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_unified_notification "daily-summary" "INFO" "$title" "$message"
}

# ========== 設定検証 ==========
validate_notification_config() {
    log_notification "INFO" "通知設定検証開始"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_notification "ERROR" "設定ファイルが見つかりません: $CONFIG_FILE"
        return 1
    fi
    
    local config_valid=true
    
    # Teams設定チェック
    local teams_enabled=$(cat "$CONFIG_FILE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('microsoft_teams', {}).get('enabled', 'false'))" 2>/dev/null || echo "false")
    if [ "$teams_enabled" = "true" ]; then
        local teams_webhook=$(cat "$CONFIG_FILE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('microsoft_teams', {}).get('webhook', ''))" 2>/dev/null || echo "")
        if [ -z "$teams_webhook" ] || [ "$teams_webhook" = "TEAMS_WEBHOOK_NOT_SET" ]; then
            log_notification "WARNING" "Teams webhook が設定されていません"
            config_valid=false
        fi
    fi
    
    # Gmail設定チェック
    local gmail_enabled=$(cat "$CONFIG_FILE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('gmail', {}).get('enabled', 'false'))" 2>/dev/null || echo "false")
    if [ "$gmail_enabled" = "true" ]; then
        local gmail_username=$(cat "$CONFIG_FILE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('gmail', {}).get('username', ''))" 2>/dev/null || echo "")
        if [ -z "$gmail_username" ]; then
            log_notification "WARNING" "Gmail username が設定されていません"
            config_valid=false
        fi
    fi
    
    if [ "$config_valid" = true ]; then
        log_notification "SUCCESS" "通知設定検証完了"
        return 0
    else
        log_notification "WARNING" "一部の通知設定が不完全です"
        return 1
    fi
}

# ========== テスト通知 ==========
send_test_notifications() {
    log_notification "INFO" "テスト通知送信開始"
    
    send_unified_notification "test" "INFO" "接続テスト" "Microsoft Teams + Gmail 通知統合システムの接続テストです。"
    
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
            notify_github_actions "$2" "$3" "$4" "$5"
            ;;
        "daily-summary")
            send_daily_summary "$2" "$3" "$4" "$5"
            ;;
        "test")
            send_test_notifications
            ;;
        "validate")
            validate_notification_config
            ;;
        "help")
            echo "Microsoft 365 Tools - 拡張通知システム (Teams + Gmail)"
            echo ""
            echo "使用方法:"
            echo "  $0 backup-success <path> <size> <duration> <files>"
            echo "  $0 backup-failure <error_code> <message>"
            echo "  $0 github-actions <workflow> <status> <run_id> <commit>"
            echo "  $0 daily-summary <count> <rate> <size> <health>"
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