# 📋 Google認証設定手順書

**作成日**: 2025年7月21日  
**最終更新**: 2025年7月21日 12:45 JST  
**対象システム**: Microsoft 365管理ツール進捗管理システム  
**目的**: Googleカレンダー連携のための認証設定  
**Context7統合**: 対応完了  
**tmux連携**: 6ペイン並列開発環境対応  

---

## 📋 目次

1. [認証設定概要](#認証設定概要)
2. [Google Cloud Console設定](#google-cloud-console設定)
3. [認証ファイル配置](#認証ファイル配置)
4. [環境設定](#環境設定)
5. [動作確認](#動作確認)
6. [トラブルシューティング](#トラブルシューティング)

---

## 🎯 1. 認証設定概要

### 必要な認証情報
- **Google Service Account**: カレンダーAPI操作用
- **JSON認証ファイル**: サービスアカウントキー
- **Calendar API有効化**: Googleカレンダーアクセス権限

### 認証なしでの利用
```bash
# 進捗管理のみ使用（カレンダー同期なし）
python3 plan/scripts/progress_tracker.py

# Context7統合での利用
claud --dangerously-skip-permissions
# tmux 6ペイン環境で進捗管理
```

---

## 🔧 2. Google Cloud Console設定

### Step 1: プロジェクト作成
```bash
1. Google Cloud Console (https://console.cloud.google.com) にアクセス
2. 右上の「プロジェクトを選択」→「新しいプロジェクト」
3. プロジェクト名: 「Microsoft365-Tools-Calendar」
4. 「作成」をクリック
```

### Step 2: Calendar API有効化
```bash
1. 左側メニュー「APIs & Services」→「Library」
2. 検索バーで「Google Calendar API」を検索
3. 「Google Calendar API」を選択
4. 「有効にする」をクリック
```

### Step 3: サービスアカウント作成
```bash
1. 左側メニュー「APIs & Services」→「認証情報」
2. 「認証情報を作成」→「サービスアカウント」
3. サービスアカウント詳細:
   - 名前: microsoft365-calendar-sync
   - ID: microsoft365-calendar-sync
   - 説明: Microsoft365管理ツール用カレンダー同期
4. 「作成して続行」をクリック
5. ロール設定: 「Editor」または「Calendar API」権限
6. 「完了」をクリック
```

### Step 4: 認証キー生成
```bash
1. 作成したサービスアカウントをクリック
2. 「キー」タブを選択
3. 「キーを追加」→「新しいキーを作成」
4. キーのタイプ: 「JSON」を選択
5. 「作成」をクリック
6. JSONファイルが自動ダウンロードされる
```

---

## 📁 3. 認証ファイル配置

### ダウンロードファイル移動
```bash
# 方法1: コマンドライン
cd /mnt/e/MicrosoftProductManagementTools
cp ~/Downloads/microsoft365-calendar-sync-*.json plan/config/google_credentials.json

# 方法2: 手動移動
# ダウンロードしたJSONファイルを以下の場所にコピー:
# plam/config/google_credentials.json
```

### ファイル構造確認（Context7統合対応）
```bash
plan/
├── config/
│   ├── google_credentials.json     # ← ここに配置
│   ├── calendar_config.json
│   └── notification_config.json
├── scripts/
│   ├── sync_calendar.py
│   ├── progress_tracker.py
│   ├── context7_sync.py             # Context7統合
│   └── teams_notification.py       # Teams通知
├── progress/
│   ├── milestones.json
│   ├── tasks.json
│   └── daily_reports/               # 日次レポート
└── schedules/
    ├── master_schedule.json         # マスタースケジュール
    └── daily_sessions/              # 日次セッション
```

### 認証ファイル形式確認
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",
  "client_email": "microsoft365-calendar-sync@your-project.iam.gserviceaccount.com",
  "client_id": "client-id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

---

## ⚙️ 4. 環境設定

### 必要ライブラリインストール
```bash
# Google APIライブラリ
pip install google-api-python-client
pip install google-auth
pip install google-auth-oauthlib

# 追加ライブラリ
pip install requests
pip install python-dateutil
```

### カレンダー設定ファイル作成（Context7統合対応）
```bash
# plan/config/calendar_config.json
cat > plan/config/calendar_config.json << 'EOF'
{
  "calendars": {
    "main_project": {
      "calendar_id": "primary",
      "name": "Microsoft365管理ツール開発",
      "color": "#4285F4",
      "sync_enabled": true
    },
    "milestones": {
      "calendar_id": "primary",
      "name": "プロジェクトマイルストーン",
      "color": "#DB4437",
      "sync_enabled": true
    },
    "daily_tasks": {
      "calendar_id": "primary",
      "name": "日次タスク",
      "color": "#0F9D58",
      "sync_enabled": true
    }
  },
  "sync_settings": {
    "interval_minutes": 15,
    "auto_create_events": true,
    "update_existing_events": true,
    "delete_outdated_events": false,
    "timezone": "Asia/Tokyo",
    "context7_integration": true,
    "tmux_sync_enabled": true,
    "teams_notification": true,
    "email_notification": true,
    "sync_interval_seconds": 12
  }
}
EOF
```

### 通知設定ファイル作成（Teams + メール統合対応）
```bash
# plan/config/notification_config.json
cat > plan/config/notification_config.json << 'EOF'
{
  "teams": {
    "webhook_url": "",
    "enabled": true,
    "channel": "microsoft365-tools-dev"
  },
  "email": {
    "enabled": true,
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587,
    "username": "",
    "password": "",
    "from_email": "",
    "to_emails": []
  },
  "slack": {
    "webhook_url": "",
    "enabled": false
  },
  "context7": {
    "enabled": true,
    "sync_interval": 12,
    "auto_documentation": true
  }
}
EOF
```

---

## 🧪 5. 動作確認

### Step 1: 基本認証テスト
```bash
cd /mnt/e/MicrosoftProductManagementTools

# 認証ファイル存在確認
ls -la plan/config/google_credentials.json

# 基本認証テスト
python3 -c "
import json
import os
from google.oauth2 import service_account

credentials_file = 'plan/config/google_credentials.json'
if os.path.exists(credentials_file):
    with open(credentials_file, 'r') as f:
        creds_info = json.load(f)
    
    credentials = service_account.Credentials.from_service_account_info(
        creds_info,
        scopes=['https://www.googleapis.com/auth/calendar']
    )
    print('✅ Google認証: 成功')
else:
    print('❌ 認証ファイルが見つかりません')
"
```

### Step 2: カレンダーAPI接続テスト（Context7統合）
```bash
# カレンダー同期テスト実行
python3 plan/scripts/sync_calendar.py

# Context7統合テスト
python3 plan/scripts/context7_sync.py --test

# Teams通知テスト
python3 plan/scripts/teams_notification.py --test
```

### Step 3: 完全システムテスト（6ペイン並列環境）
```bash
# 進捗データ初期化
python3 plan/scripts/progress_tracker.py

# カレンダー同期実行
python3 plan/scripts/sync_calendar.py

# Context7統合テスト
python3 plan/scripts/context7_sync.py

# tmux共有コンテキスト初期化
echo "# Context7統合テスト $(date)" >> tmux_shared_context.md

# 結果確認
cat plan/calendars/sync_log.json
cat tmux_shared_context.md
```

---

## 🔧 6. トラブルシューティング

### ❌ よくあるエラー

#### 1. 認証エラー
```bash
エラー: 「認証エラー: 認証情報が見つかりません」

解決策:
1. google_credentials.jsonファイルの存在確認
2. ファイル内容の形式確認（正しいJSON形式か）
3. ファイルパスの確認（plam/config/google_credentials.json）
```

#### 2. API権限エラー
```bash
エラー: 「Calendar API has not been used」

解決策:
1. Google Cloud ConsoleでCalendar API有効化確認
2. プロジェクトが正しく選択されているか確認
3. サービスアカウントに適切な権限が付与されているか確認
```

#### 3. ライブラリ不足エラー
```bash
エラー: 「ModuleNotFoundError: No module named 'googleapiclient'」

解決策:
pip install google-api-python-client google-auth google-auth-oauthlib
```

### 🔍 ログ確認

#### 同期ログ確認（Context7統合対応）
```bash
# 最新の同期ログ
tail -f plan/calendars/sync_log.txt

# Context7統合ログ
tail -f plan/logs/context7_sync.log

# tmux共有コンテキストログ
tail -f tmux_shared_context.md

# エラーログ抽出
grep ERROR plan/calendars/sync_log.txt

# 同期結果JSON
cat plan/calendars/sync_log.json
```

#### システムログ確認（6ペイン並列環境）
```bash
# システム全体ログ
tail -f Logs/system.log

# 進捗管理ログ
ls -la plan/progress/daily_reports/

# 日次セッションログ
ls -la plan/schedules/daily_sessions/

# Context7統合ログ
ls -la plan/logs/
```

### 🚫 認証なしでの利用

Google認証が困難な場合、進捗管理のみ利用可能：

```bash
# 進捗管理システムのみ使用
python3 plan/scripts/progress_tracker.py

# Context7統合なしでのタスク更新
python3 -c "
from plan.scripts.progress_tracker import ProgressTracker
tracker = ProgressTracker()
tracker.update_task_progress('conftest_fix', 90, '修復作業ほぼ完了')
"

# 日次レポート確認
cat plan/progress/daily_reports/$(date +%Y-%m-%d).json

# tmux環境での進捗確認
echo "進捗確認: $(date)" >> tmux_shared_context.md
```

---

## 📞 7. サポート情報

### 追加支援が必要な場合

#### Google Cloud Console関連
- **公式ドキュメント**: https://cloud.google.com/docs/authentication
- **Calendar API仕様**: https://developers.google.com/calendar/api

#### システム関連（Context7統合対応）
- **進捗管理**: `plan/scripts/progress_tracker.py`実行
- **カレンダー同期**: `plan/scripts/sync_calendar.py`実行
- **Context7統合**: `plan/scripts/context7_sync.py`実行
- **Teams通知**: `plan/scripts/teams_notification.py`実行
- **設定ファイル**: `plan/config/`ディレクトリ
- **tmux共有コンテキスト**: `tmux_shared_context.md`

#### 緊急時（Context7統合環境）
```bash
# 認証なしモードで進捗管理継続
python3 plan/scripts/progress_tracker.py

# tmux環境での緊急対応
echo "緊急対応: $(date)" >> tmux_shared_context.md

# バックアップからの復旧
cp plan/progress/daily_reports/latest.json plan/progress/milestones.json

# Context7統合リセット
python3 plan/scripts/context7_sync.py --reset
```

---

## ✅ まとめ

### 認証設定完了チェックリスト
- [ ] Google Cloud Consoleプロジェクト作成
- [ ] Calendar API有効化
- [ ] サービスアカウント作成
- [ ] 認証JSONファイルダウンロード
- [ ] `plam/config/google_credentials.json`に配置
- [ ] 必要ライブラリインストール
- [ ] 設定ファイル作成
- [ ] 動作確認テスト実行

### 運用開始（Context7統合対応）
```bash
# 1. 進捗管理開始
python3 plan/scripts/progress_tracker.py

# 2. カレンダー同期開始（認証完了後）
python3 plan/scripts/sync_calendar.py

# 3. Context7統合開始
python3 plan/scripts/context7_sync.py --start

# 4. tmux 6ペイン並列環境起動
claud --dangerously-skip-permissions

# 5. Teams + メール通知開始
python3 plan/scripts/teams_notification.py --start

# 6. 定期実行設定（12秒間隔自動同期）
bash plan/scripts/setup_sync_cron.sh
```

この手順書に従って設定することで、進捗管理システムとGoogleカレンダーの連携が完了し、プロジェクト進捗の可視化と自動同期が実現されます。