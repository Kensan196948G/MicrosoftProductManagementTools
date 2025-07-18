# 5ペイン体制 相互連携実装ガイド

## 概要
このドキュメントは、Microsoft365管理ツールPython版開発における5ペイン体制での効率的な相互連携を実現するための実装ガイドです。

## tmuxセッション初期化スクリプト

### 5ペイン自動セットアップ（setup_5pane_dev.sh）
```bash
#!/bin/bash
# 5ペイン開発環境自動セットアップスクリプト

SESSION_NAME="MicrosoftProductTools-Python"
PROJECT_DIR="/mnt/e/MicrosoftProductManagementTools"

# セッション作成
tmux new-session -d -s $SESSION_NAME -c $PROJECT_DIR

# 5ペイン分割
tmux split-window -h -p 50          # 右半分作成
tmux split-window -v -p 50          # 右下作成  
tmux select-pane -t 0               # 左ペイン選択
tmux split-window -v -p 67          # 左中作成
tmux split-window -v -p 50          # 左下作成

# ペイン設定と初期化
tmux send-keys -t 0 'cd '$PROJECT_DIR' && source ./tmux/scripts/roles/role_startup.sh CTO' C-m
tmux send-keys -t 1 'cd '$PROJECT_DIR' && source ./tmux/scripts/roles/role_startup.sh Manager' C-m
tmux send-keys -t 2 'cd '$PROJECT_DIR' && source ./tmux/scripts/roles/role_startup.sh Developer GUI' C-m
tmux send-keys -t 3 'cd '$PROJECT_DIR' && source ./tmux/scripts/roles/role_startup.sh Developer Test' C-m
tmux send-keys -t 4 'cd '$PROJECT_DIR' && source ./tmux/scripts/roles/role_startup.sh Developer Infra' C-m

# ペイン名設定
tmux select-pane -t 0 -T "👑 CTO"
tmux select-pane -t 1 -T "👔 Manager"
tmux select-pane -t 2 -T "🐍 dev0-GUI"
tmux select-pane -t 3 -T "🧪 dev1-Test"
tmux select-pane -t 4 -T "🔄 dev2-Infra"

# メッセージングシステム自動読み込み
for pane in 0 1 2 3 4; do
    tmux send-keys -t $pane 'source ./tmux/collaboration/messaging_system.sh' C-m
done

# 初期ステータス送信
sleep 2
tmux send-keys -t 0 'team status CTO "開発環境準備完了、技術方針確認中"' C-m
tmux send-keys -t 1 'team status Manager "本日のスプリント計画を開始します"' C-m
tmux send-keys -t 2 'team status dev0 "GUI開発環境セットアップ完了"' C-m
tmux send-keys -t 3 'team status dev1 "テスト環境準備完了"' C-m
tmux send-keys -t 4 'team status dev2 "インフラ・互換性検証環境準備完了"' C-m

# セッション接続
tmux attach-session -t $SESSION_NAME
```

## リアルタイム連携実装

### 連携ステータスダッシュボード（status_dashboard.sh）
```bash
#!/bin/bash
# リアルタイムステータスダッシュボード

DASHBOARD_FILE="/tmp/team_status_dashboard.txt"

update_dashboard() {
    clear
    echo "=== 5ペイン開発チーム ステータスダッシュボード ===" > $DASHBOARD_FILE
    echo "更新時刻: $(date '+%Y-%m-%d %H:%M:%S')" >> $DASHBOARD_FILE
    echo "" >> $DASHBOARD_FILE
    
    # 各ペインの最新ステータス取得
    for role in CTO Manager dev0 dev1 dev2; do
        latest_status=$(grep "$role" ./logs/messages/all_messages.log | grep "status" | tail -1)
        echo "[$role] $latest_status" >> $DASHBOARD_FILE
    done
    
    echo "" >> $DASHBOARD_FILE
    echo "=== 進行中タスク ===" >> $DASHBOARD_FILE
    grep "request" ./logs/messages/all_messages.log | tail -5 >> $DASHBOARD_FILE
    
    echo "" >> $DASHBOARD_FILE
    echo "=== 技術相談 ===" >> $DASHBOARD_FILE
    grep "technical" ./logs/messages/all_messages.log | tail -3 >> $DASHBOARD_FILE
    
    cat $DASHBOARD_FILE
}

# 30秒毎に更新
while true; do
    update_dashboard
    sleep 30
done
```

### フェーズ進捗トラッカー（phase_tracker.sh）
```bash
#!/bin/bash
# フェーズ別進捗管理スクリプト

PHASE_FILE="./logs/phase_progress.json"

# 進捗更新関数
update_phase_progress() {
    local phase=$1
    local pane=$2
    local progress=$3
    local details=$4
    
    # JSON形式で進捗を記録
    jq --arg phase "$phase" \
       --arg pane "$pane" \
       --arg progress "$progress" \
       --arg details "$details" \
       --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.phases[$phase].panes[$pane] = {
           "progress": $progress,
           "details": $details,
           "updated": $timestamp
       }' $PHASE_FILE > ${PHASE_FILE}.tmp && mv ${PHASE_FILE}.tmp $PHASE_FILE
}

# 全体進捗計算
calculate_overall_progress() {
    local phase=$1
    jq -r --arg phase "$phase" '
        .phases[$phase].panes | 
        to_entries | 
        map(.value.progress | tonumber) | 
        add / length
    ' $PHASE_FILE
}

# 使用例
# ./phase_tracker.sh update 1 dev0 60 "GUI基盤実装中"
# ./phase_tracker.sh overall 1

case $1 in
    update)
        update_phase_progress $2 $3 $4 "$5"
        ;;
    overall)
        calculate_overall_progress $2
        ;;
    *)
        echo "Usage: $0 {update|overall} [args]"
        ;;
esac
```

## クロスペイン連携の実装

### 自動タスク依存関係管理（task_dependency.sh）
```bash
#!/bin/bash
# タスク依存関係自動管理

TASK_DB="./logs/task_dependencies.json"

# タスク登録
register_task() {
    local task_id=$1
    local owner=$2
    local depends_on=$3
    local description=$4
    
    jq --arg id "$task_id" \
       --arg owner "$owner" \
       --arg deps "$depends_on" \
       --arg desc "$description" \
       '.tasks[$id] = {
           "owner": $owner,
           "depends_on": ($deps | split(",")),
           "description": $desc,
           "status": "pending",
           "created": now
       }' $TASK_DB > ${TASK_DB}.tmp && mv ${TASK_DB}.tmp $TASK_DB
}

# 依存関係チェック
check_dependencies() {
    local task_id=$1
    
    # 依存タスクがすべて完了しているか確認
    jq -r --arg id "$task_id" '
        .tasks[$id].depends_on as $deps |
        if ($deps | length) == 0 then
            "ready"
        else
            [$deps[] as $dep | .tasks[$dep].status] |
            if all(. == "completed") then "ready" else "blocked" end
        end
    ' $TASK_DB
}

# タスク完了通知と依存解決
complete_task() {
    local task_id=$1
    
    # タスクを完了に更新
    jq --arg id "$task_id" \
       '.tasks[$id].status = "completed" | 
        .tasks[$id].completed = now' \
       $TASK_DB > ${TASK_DB}.tmp && mv ${TASK_DB}.tmp $TASK_DB
    
    # 依存していたタスクに通知
    dependent_tasks=$(jq -r --arg id "$task_id" '
        .tasks | to_entries[] | 
        select(.value.depends_on | contains([$id])) | 
        .key
    ' $TASK_DB)
    
    for dep_task in $dependent_tasks; do
        if [ "$(check_dependencies $dep_task)" = "ready" ]; then
            owner=$(jq -r --arg id "$dep_task" '.tasks[$id].owner' $TASK_DB)
            desc=$(jq -r --arg id "$dep_task" '.tasks[$id].description' $TASK_DB)
            
            # 自動通知送信
            ./collaboration/team_commands.sh request System $owner "タスク[$dep_task]の依存が解決しました: $desc"
        fi
    done
}
```

### 並行作業コーディネーター（parallel_coordinator.sh）
```bash
#!/bin/bash
# 並行作業の最適化と調整

WORK_QUEUE="./logs/parallel_work_queue.json"

# 作業キューに追加
enqueue_work() {
    local work_id=$1
    local assignee=$2
    local priority=$3
    local estimated_time=$4
    local description=$5
    
    jq --arg id "$work_id" \
       --arg assignee "$assignee" \
       --arg priority "$priority" \
       --arg time "$estimated_time" \
       --arg desc "$description" \
       '.queue += [{
           "id": $id,
           "assignee": $assignee,
           "priority": ($priority | tonumber),
           "estimated_time": ($time | tonumber),
           "description": $desc,
           "status": "queued",
           "created": now
       }]' $WORK_QUEUE > ${WORK_QUEUE}.tmp && mv ${WORK_QUEUE}.tmp $WORK_QUEUE
}

# 最適な作業割り当て
optimize_assignment() {
    # 各開発者の現在の負荷を計算
    jq -r '
        .queue | 
        group_by(.assignee) | 
        map({
            assignee: .[0].assignee,
            total_time: map(select(.status == "in_progress") | .estimated_time) | add,
            task_count: length
        }) |
        sort_by(.total_time)
    ' $WORK_QUEUE
}

# 作業開始通知
start_work() {
    local work_id=$1
    
    # ステータス更新
    jq --arg id "$work_id" \
       '(.queue[] | select(.id == $id) | .status) = "in_progress" |
        (.queue[] | select(.id == $id) | .started) = now' \
       $WORK_QUEUE > ${WORK_QUEUE}.tmp && mv ${WORK_QUEUE}.tmp $WORK_QUEUE
    
    # 関連チームメンバーに通知
    work_info=$(jq -r --arg id "$work_id" '.queue[] | select(.id == $id)' $WORK_QUEUE)
    assignee=$(echo $work_info | jq -r '.assignee')
    desc=$(echo $work_info | jq -r '.description')
    
    ./collaboration/team_commands.sh status $assignee "作業開始: $desc"
}
```

## メッセージングシステム拡張

### 優先度付きメッセージキュー（priority_queue.sh）
```bash
#!/bin/bash
# 優先度付きメッセージ処理

PRIORITY_QUEUE="./logs/priority_message_queue.json"

# メッセージ優先度計算
calculate_priority() {
    local msg_type=$1
    local sender=$2
    
    case $msg_type in
        emergency) echo 100 ;;
        technical) echo 75 ;;
        coordination) echo 50 ;;
        general) echo 25 ;;
        *) echo 10 ;;
    esac
}

# 優先度付きメッセージ送信
send_priority_message() {
    local from=$1
    local to=$2
    local type=$3
    local message=$4
    
    priority=$(calculate_priority $type $from)
    
    # キューに追加
    jq --arg from "$from" \
       --arg to "$to" \
       --arg type "$type" \
       --arg msg "$message" \
       --arg pri "$priority" \
       '.messages += [{
           "from": $from,
           "to": $to,
           "type": $type,
           "message": $msg,
           "priority": ($pri | tonumber),
           "timestamp": now,
           "processed": false
       }] | .messages |= sort_by(.priority) | reverse' \
       $PRIORITY_QUEUE > ${PRIORITY_QUEUE}.tmp && mv ${PRIORITY_QUEUE}.tmp $PRIORITY_QUEUE
}

# 次のメッセージ取得と処理
process_next_message() {
    # 最高優先度の未処理メッセージを取得
    next_msg=$(jq -r '.messages[] | select(.processed == false) | . + {index: .timestamp}' $PRIORITY_QUEUE | head -1)
    
    if [ ! -z "$next_msg" ]; then
        # メッセージ処理
        from=$(echo $next_msg | jq -r '.from')
        to=$(echo $next_msg | jq -r '.to')
        type=$(echo $next_msg | jq -r '.type')
        message=$(echo $next_msg | jq -r '.message')
        timestamp=$(echo $next_msg | jq -r '.timestamp')
        
        # 実際の送信処理
        ./collaboration/messaging_system.sh send_message "$from" "$to" "$type" "$message"
        
        # 処理済みマーク
        jq --arg ts "$timestamp" \
           '(.messages[] | select(.timestamp == ($ts | tonumber)) | .processed) = true' \
           $PRIORITY_QUEUE > ${PRIORITY_QUEUE}.tmp && mv ${PRIORITY_QUEUE}.tmp $PRIORITY_QUEUE
    fi
}
```

## 連携効果測定ツール

### メトリクス収集スクリプト（collect_metrics.sh）
```bash
#!/bin/bash
# 連携効果の定量的測定

METRICS_FILE="./logs/collaboration_metrics.json"

# 応答時間測定
measure_response_time() {
    local from=$1
    local to=$2
    local start_time=$3
    local end_time=$4
    
    # 応答時間計算（秒単位）
    response_time=$((end_time - start_time))
    
    jq --arg from "$from" \
       --arg to "$to" \
       --arg time "$response_time" \
       '.response_times += [{
           "from": $from,
           "to": $to,
           "seconds": ($time | tonumber),
           "timestamp": now
       }]' $METRICS_FILE > ${METRICS_FILE}.tmp && mv ${METRICS_FILE}.tmp $METRICS_FILE
}

# 並行作業率計算
calculate_parallel_work_rate() {
    # 同時進行中のタスク数を取得
    active_tasks=$(jq '[.tasks[] | select(.status == "in_progress")] | length' ./logs/task_dependencies.json)
    total_tasks=$(jq '.tasks | length' ./logs/task_dependencies.json)
    
    if [ $total_tasks -gt 0 ]; then
        parallel_rate=$((active_tasks * 100 / total_tasks))
        echo "並行作業率: ${parallel_rate}%"
        
        jq --arg rate "$parallel_rate" \
           '.parallel_work_rate += [{
               "rate": ($rate | tonumber),
               "timestamp": now
           }]' $METRICS_FILE > ${METRICS_FILE}.tmp && mv ${METRICS_FILE}.tmp $METRICS_FILE
    fi
}

# 日次レポート生成
generate_daily_report() {
    echo "=== 連携効果日次レポート ===" 
    echo "日付: $(date '+%Y-%m-%d')"
    echo ""
    
    # 平均応答時間
    avg_response=$(jq '
        .response_times | 
        map(.seconds) | 
        add / length
    ' $METRICS_FILE)
    echo "平均応答時間: ${avg_response}秒"
    
    # メッセージ数統計
    total_messages=$(grep -c "send_message" ./logs/messages/all_messages.log)
    echo "総メッセージ数: $total_messages"
    
    # チャネル別統計
    for channel in emergency technical coordination general; do
        count=$(grep -c "$channel" ./logs/messages/all_messages.log)
        echo "${channel}チャネル: $count"
    done
}
```

## 初期化と実行

### マスター初期化スクリプト（init_5pane_collaboration.sh）
```bash
#!/bin/bash
# 5ペイン連携システム完全初期化

echo "5ペイン連携システムを初期化しています..."

# 必要なディレクトリ作成
mkdir -p ./logs/messages
mkdir -p ./tmux/collaboration

# 初期JSONファイル作成
echo '{"tasks": {}}' > ./logs/task_dependencies.json
echo '{"queue": []}' > ./logs/parallel_work_queue.json
echo '{"messages": []}' > ./logs/priority_message_queue.json
echo '{"response_times": [], "parallel_work_rate": []}' > ./logs/collaboration_metrics.json
echo '{"phases": {"1": {"panes": {}}, "2": {"panes": {}}, "3": {"panes": {}}}}' > ./logs/phase_progress.json

# 実行権限付与
chmod +x ./tmux/collaboration/*.sh
chmod +x ./tmux/scripts/roles/*.sh

echo "初期化完了！"
echo ""
echo "5ペイン開発環境を起動するには:"
echo "./tmux/collaboration/setup_5pane_dev.sh"
```

## 使用方法

1. **初期セットアップ**
   ```bash
   ./tmux/collaboration/init_5pane_collaboration.sh
   ```

2. **5ペイン環境起動**
   ```bash
   ./tmux/collaboration/setup_5pane_dev.sh
   ```

3. **ステータスダッシュボード起動**（別ターミナル）
   ```bash
   ./tmux/collaboration/status_dashboard.sh
   ```

4. **連携コマンド例**
   ```bash
   # タスク登録と依存関係
   ./task_dependency.sh register T001 dev0 "" "GUI基本実装"
   ./task_dependency.sh register T002 dev1 "T001" "GUIテスト作成"
   
   # 並行作業登録
   ./parallel_coordinator.sh enqueue W001 dev0 1 120 "PyQt6セットアップ"
   ./parallel_coordinator.sh enqueue W002 dev2 1 90 "WSL環境構築"
   
   # 優先メッセージ送信
   ./priority_queue.sh send CTO All emergency "セキュリティパッチ適用必須"
   ```

5. **メトリクス確認**
   ```bash
   ./collect_metrics.sh generate_daily_report
   ```

これにより、5ペイン体制での効率的な相互連携が実現できます。