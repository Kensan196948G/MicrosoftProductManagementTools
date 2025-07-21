#!/bin/bash

# 🚀 ITSM AI Team Role-Based Integration System
# CEOx(CTO)、Manager、Developer間の連携を統合管理

# 設定値
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
INSTRUCTIONS_DIR="$SCRIPT_DIR/instructions"

# ログ設定
mkdir -p "$LOG_DIR"
INTEGRATION_LOG="$LOG_DIR/integration.log"
COMMUNICATION_LOG="$LOG_DIR/communication.log"

# ログローテーション機能
rotate_log() {
    local log_file="$1"
    local max_size=10485760  # 10MB
    
    if [[ -f "$log_file" ]]; then
        # ファイルサイズ取得（Linux/macOS対応）
        local file_size
        if command -v stat >/dev/null 2>&1; then
            if stat -f%z "$log_file" >/dev/null 2>&1; then
                file_size=$(stat -f%z "$log_file")  # macOS
            else
                file_size=$(stat -c%s "$log_file")  # Linux
            fi
        else
            file_size=$(wc -c < "$log_file")
        fi
        
        if [[ $file_size -gt $max_size ]]; then
            echo "🔄 ログローテーション実行: $log_file (${file_size} bytes > ${max_size} bytes)"
            mv "$log_file" "${log_file}.old"
            echo "# Log rotated at $(date)" > "$log_file"
            echo "# Previous log archived as ${log_file}.old" >> "$log_file"
            return 0
        fi
    fi
    return 1
}

# ログ関数（ローテーション機能付き）
log_integration() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ログローテーション確認
    rotate_log "$INTEGRATION_LOG"
    
    echo "[$timestamp] [$level] $message" >> "$INTEGRATION_LOG"
    echo "[$level] $message"
}

# 通信ログのローテーション
rotate_communication_log() {
    if [[ -f "$COMMUNICATION_LOG" ]]; then
        rotate_log "$COMMUNICATION_LOG"
    fi
}

# 使用方法表示
show_usage() {
    cat << EOF
🏢 ITSM AI Team Role-Based Integration System

使用方法:
  $0 [コマンド] [オプション]

コマンド:
  init-roles      - 役割別エージェントの初期化
  start-project   - プロジェクト開始（CEO→Manager→Developer）
  monitor-flow    - 役割間の連携フロー監視
  validate-roles  - 各役割の動作検証
  show-hierarchy  - 役割階層の表示
  help           - このヘルプの表示

役割別プロジェクト開始例:
  $0 start-project "ECサイト開発" "Webアプリケーション"
  $0 start-project "API開発" "RESTful API"
  $0 start-project "DB設計" "データベース"

EOF
}

# 役割階層の表示
show_hierarchy() {
    log_integration "INFO" "Role hierarchy display requested"
    
    cat << EOF
🏢 ITSM AI Team Role Hierarchy

┌─────────────────────────────────────────────────────────────┐
│                    CTO (CEO)                                │
│                最高技術責任者                                │
│   ・技術戦略決定                                            │
│   ・アーキテクチャ承認                                       │
│   ・品質基準設定                                            │
│   ・プロジェクト最終承認                                     │
└─────────────────┬───────────────────────────────────────────┘
                  │ 技術指示
                  ▼
┌─────────────────────────────────────────────────────────────┐
│              Technical Manager                              │
│             テクニカルプロジェクトマネージャー               │
│   ・CTO指示の技術実装管理                                   │
│   ・開発タスクの分割・配布                                  │
│   ・技術チーム統括                                          │
│   ・進捗管理・品質管理                                      │
└─────────────────┬───────────────────────────────────────────┘
                  │ 開発指示
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                  Developers                                 │
│                ソフトウェアエンジニア                        │
│                                                             │
│  dev1: フロントエンド/UI開発スペシャリスト                   │
│  dev2: バックエンド/インフラスペシャリスト                   │
│  dev3: QA/セキュリティスペシャリスト                        │
│  dev4: フルスタック/アーキテクチャスペシャリスト             │
│                                                             │
│   ・技術実装                                                │
│   ・コード開発                                              │
│   ・テスト実行                                              │
│   ・技術報告                                                │
└─────────────────────────────────────────────────────────────┘

Communication Flow:
CEO --[技術指示]--> Manager --[開発指示]--> Developer
CEO <--[技術報告]-- Manager <--[完了報告]-- Developer

EOF
}

# 役割検証
validate_roles() {
    log_integration "INFO" "Role validation started"
    
    local validation_passed=true
    
    echo "🔍 役割別指示書検証中..."
    
    # 各役割の指示書存在確認
    local roles=("ceo" "manager" "developer")
    for role in "${roles[@]}"; do
        local instruction_file="$INSTRUCTIONS_DIR/${role}.md"
        if [[ -f "$instruction_file" ]]; then
            echo "✅ $role: 指示書確認"
            
            # 指示書内容の基本検証
            if grep -q "send-message.sh" "$instruction_file"; then
                echo "  ✅ 通信システム統合済み"
            else
                echo "  ⚠️  通信システムへの参照不足"
                validation_passed=false
            fi
            
            if grep -q "技術" "$instruction_file"; then
                echo "  ✅ IT技術特化内容確認"
            else
                echo "  ⚠️  IT技術特化内容不足"
                validation_passed=false
            fi
            
        else
            echo "❌ $role: 指示書が見つかりません"
            validation_passed=false
        fi
    done
    
    echo ""
    
    # 通信システム検証
    if [[ -f "$SCRIPT_DIR/send-message.sh" ]]; then
        echo "✅ 通信システム: send-message.sh 存在確認"
        
        if "$SCRIPT_DIR/send-message.sh" --detect > /dev/null 2>&1; then
            echo "  ✅ 通信システム動作確認"
        else
            echo "  ⚠️  通信システム動作に問題あり"
            validation_passed=false
        fi
    else
        echo "❌ 通信システム: send-message.sh が見つかりません"
        validation_passed=false
    fi
    
    echo ""
    
    if $validation_passed; then
        echo "🎉 役割統合システム: 全体検証完了"
        log_integration "SUCCESS" "Role validation completed successfully"
        return 0
    else
        echo "⚠️  役割統合システム: 一部問題があります"
        log_integration "WARNING" "Role validation completed with issues"
        return 1
    fi
}

# プロジェクト開始（統合ワークフロー）
start_project() {
    local project_name="$1"
    local project_type="$2"
    
    if [[ -z "$project_name" || -z "$project_type" ]]; then
        echo "❌ プロジェクト名とタイプを指定してください"
        echo "例: $0 start-project \"ECサイト開発\" \"Webアプリケーション\""
        return 1
    fi
    
    log_integration "INFO" "Project start requested: $project_name ($project_type)"
    
    echo "🚀 ITプロジェクト開始: $project_name"
    echo "プロジェクトタイプ: $project_type"
    echo ""
    
    # 1. CEO(CTO)への技術プロジェクト開始指示
    echo "📋 Phase 1: CEO(CTO)への技術プロジェクト開始指示"
    
    local ceo_instruction=""
    case "$project_type" in
        "Webアプリケーション"|"Webアプリ")
            ceo_instruction="【ITプロジェクト開始要請】
プロジェクト名：$project_name
システム種別：Webアプリケーション
技術要件分析・アーキテクチャ設計・技術方針決定を行い、
managerに適切な技術指示を出してください。
推奨技術構成：React+Node.js+PostgreSQL
品質基準：セキュリティ・パフォーマンス・スケーラビリティ重視"
            ;;
        "API開発"|"RESTful API")
            ceo_instruction="【ITプロジェクト開始要請】
プロジェクト名：$project_name
システム種別：RESTful API
技術要件分析・API設計・技術方針決定を行い、
managerに適切な技術指示を出してください。
推奨技術構成：Python FastAPI + PostgreSQL + Redis
品質基準：パフォーマンス・セキュリティ・ドキュメント重視"
            ;;
        "データベース"|"DB設計")
            ceo_instruction="【ITプロジェクト開始要請】
プロジェクト名：$project_name
システム種別：データベース設計
技術要件分析・DB設計・技術方針決定を行い、
managerに適切な技術指示を出してください。
推奨技術構成：PostgreSQL + インデックス最適化
品質基準：データ整合性・パフォーマンス・スケーラビリティ重視"
            ;;
        *)
            ceo_instruction="【ITプロジェクト開始要請】
プロジェクト名：$project_name
システム種別：$project_type
技術要件分析・システム設計・技術方針決定を行い、
managerに適切な技術指示を出してください。
品質基準：セキュリティ・パフォーマンス・保守性重視"
            ;;
    esac
    
    # CEO(CTO)にメッセージ送信
    if "$SCRIPT_DIR/send-message.sh" ceo "$ceo_instruction"; then
        echo "✅ CEO(CTO)への指示送信完了"
        log_integration "SUCCESS" "CEO instruction sent successfully"
    else
        echo "❌ CEO(CTO)への指示送信失敗"
        log_integration "ERROR" "CEO instruction failed"
        return 1
    fi
    
    echo ""
    echo "🔄 統合ワークフロー開始："
    echo "  1. CEO(CTO) → 技術戦略決定・アーキテクチャ設計"
    echo "  2. CEO(CTO) → Manager へ技術指示"
    echo "  3. Manager → 開発タスク分割・技術チーム統括"
    echo "  4. Manager → Developer へ開発指示"
    echo "  5. Developer → 技術実装・コード開発"
    echo "  6. Developer → Manager へ完了報告"
    echo "  7. Manager → CEO(CTO) へ技術報告"
    echo "  8. CEO(CTO) → 技術承認・品質評価"
    echo ""
    echo "📊 進捗監視: $0 monitor-flow で連携状況を確認してください"
    
    return 0
}

# 連携フロー監視
monitor_flow() {
    log_integration "INFO" "Flow monitoring started"
    
    echo "📊 役割間連携フロー監視"
    echo "========================"
    
    local log_file="$LOG_DIR/communication.log"
    
    if [[ -f "$log_file" ]]; then
        echo "📋 最新の通信ログ（最後の10件）:"
        tail -10 "$log_file"
        echo ""
        
        echo "📈 役割別通信統計:"
        echo "CEO    : $(grep -c "→ ceo:" "$log_file" || echo "0") 件"
        echo "Manager: $(grep -c "→ manager:" "$log_file" || echo "0") 件"
        echo "Dev1   : $(grep -c "→ dev1:" "$log_file" || echo "0") 件"
        echo "Dev2   : $(grep -c "→ dev2:" "$log_file" || echo "0") 件"
        echo "Dev3   : $(grep -c "→ dev3:" "$log_file" || echo "0") 件"
        echo "Dev4   : $(grep -c "→ dev4:" "$log_file" || echo "0") 件"
        echo ""
        
        echo "🔄 連携パターン分析:"
        if grep -q "技術指示" "$log_file"; then
            echo "  ✅ CEO→Manager 技術指示確認"
        else
            echo "  ⚠️  CEO→Manager 技術指示未確認"
        fi
        
        if grep -q "開発指示" "$log_file"; then
            echo "  ✅ Manager→Developer 開発指示確認"
        else
            echo "  ⚠️  Manager→Developer 開発指示未確認"
        fi
        
        if grep -q "完了報告" "$log_file"; then
            echo "  ✅ Developer→Manager 完了報告確認"
        else
            echo "  ⚠️  Developer→Manager 完了報告未確認"
        fi
        
        if grep -q "技術承認" "$log_file"; then
            echo "  ✅ Manager→CEO 技術報告確認"
        else
            echo "  ⚠️  Manager→CEO 技術報告未確認"
        fi
        
    else
        echo "📋 通信ログが見つかりません"
        echo "まずプロジェクトを開始してください: $0 start-project"
    fi
    
    echo ""
    echo "🔍 リアルタイム監視:"
    echo "  tail -f $log_file"
    echo ""
    echo "📊 統合ログ確認:"
    echo "  tail -f $INTEGRATION_LOG"
}

# 役割初期化
init_roles() {
    log_integration "INFO" "Role initialization started"
    
    echo "🔧 役割別エージェント初期化"
    echo "=========================="
    
    # 各役割に初期化メッセージ送信
    local roles=("ceo" "manager" "dev1" "dev2" "dev3")
    local success_count=0
    
    for role in "${roles[@]}"; do
        local init_message=""
        
        case "$role" in
            "ceo")
                init_message="【役割初期化】あなたはCTO（最高技術責任者）として、IT技術戦略の決定とアーキテクチャ承認を行います。managerに技術指示を出して、高品質なITシステム開発を統括してください。"
                ;;
            "manager")
                init_message="【役割初期化】あなたはTechnical Project Managerとして、CTOからの技術指示を受けて開発チームを統括します。開発タスクを分割して各developerに配布し、完了報告を管理してください。"
                ;;
            "dev1")
                init_message="【役割初期化】あなたはフロントエンド/UI開発スペシャリストとして、React/TypeScript/UI/UXの技術実装を担当します。managerからの開発指示を受けて高品質なコードを開発してください。"
                ;;
            "dev2")
                init_message="【役割初期化】あなたはバックエンド/インフラスペシャリストとして、API/DB/クラウドの技術実装を担当します。managerからの開発指示を受けて高品質なシステムを構築してください。"
                ;;
            "dev3")
                init_message="【役割初期化】あなたはQA/セキュリティスペシャリストとして、テスト自動化/品質保証/セキュリティの技術実装を担当します。managerからの開発指示を受けて高品質な検証システムを構築してください。"
                ;;
        esac
        
        echo "📤 $role 初期化中..."
        if "$SCRIPT_DIR/send-message.sh" "$role" "$init_message"; then
            echo "  ✅ $role 初期化完了"
            ((success_count++))
        else
            echo "  ❌ $role 初期化失敗"
        fi
        
        sleep 1
    done
    
    echo ""
    echo "🎯 初期化結果: $success_count/${#roles[@]} 役割初期化完了"
    
    if [[ $success_count -eq ${#roles[@]} ]]; then
        echo "🎉 全役割初期化完了 - プロジェクト開始準備完了"
        log_integration "SUCCESS" "All roles initialized successfully"
        return 0
    else
        echo "⚠️  一部役割の初期化に失敗 - 個別に確認してください"
        log_integration "WARNING" "Some roles failed to initialize"
        return 1
    fi
}

# メイン処理
main() {
    case "${1:-help}" in
        "init-roles")
            init_roles
            ;;
        "start-project")
            start_project "$2" "$3"
            ;;
        "monitor-flow")
            monitor_flow
            ;;
        "validate-roles")
            validate_roles
            ;;
        "show-hierarchy")
            show_hierarchy
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# スクリプト実行
main "$@"