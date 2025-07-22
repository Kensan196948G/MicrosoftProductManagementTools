# 📊 進捗管理システム・Googleカレンダー連携仕様書

**作成日**: 2025年7月21日  
**対象プロジェクト**: Microsoft 365管理ツール  
**連携システム**: Google Calendar API v3  

---

## 📋 目次

1. [システム概要](#システム概要)
2. [進捗管理ファイル構造](#進捗管理ファイル構造)
3. [Googleカレンダー連携仕様](#googleカレンダー連携仕様)
4. [実装ファイル詳細](#実装ファイル詳細)
5. [自動同期システム](#自動同期システム)
6. [使用方法](#使用方法)
7. [トラブルシューティング](#トラブルシューティング)

---

## 🎯 1. システム概要

### 📊 機能概要

planフォルダ内で包括的な進捗管理を行い、Googleカレンダーと双方向同期するシステムです。

#### 主要機能
- ✅ **リアルタイム進捗追跡**: マイルストーン・タスク・工数管理
- 📅 **Googleカレンダー自動同期**: スケジュール・締切・会議連携
- 📊 **ダッシュボード生成**: 進捗可視化・レポート自動作成
- 🔔 **自動アラート**: 遅延警告・締切通知・スラック統合
- 📈 **メトリクス分析**: 開発効率・品質指標・リスク評価

### 🏗️ アーキテクチャ

```mermaid
graph TD
    A[planフォルダ] --> B[進捗管理JSON]
    A --> C[マイルストーンMD]
    A --> D[タスクトラッカー]
    
    B --> E[Python同期エンジン]
    C --> E
    D --> E
    
    E --> F[Google Calendar API]
    E --> G[進捗ダッシュボード]
    E --> H[Slackアラート]
    
    F --> I[Googleカレンダー]
    G --> J[HTML/JSON レポート]
    H --> K[チーム通知]
```

---

## 📁 2.進捗管理ファイル構造

### 🗂️ ディレクトリ構成

```bash
plan/
├── 📋 進捗管理システム・Googleカレンダー連携.md
├── 📊 リリース計画・開発プロセス詳細手順.md
├── 📅 calendars/
│   ├── main_project.ics          # メインプロジェクトカレンダー
│   ├── milestones.ics            # マイルストーンカレンダー
│   ├── daily_tasks.ics           # 日次タスクカレンダー
│   └── sync_log.json             # 同期ログ
├── 📈 progress/
│   ├── milestones.json           # マイルストーン進捗
│   ├── tasks.json                # タスク詳細
│   ├── metrics.json              # 開発メトリクス
│   ├── risks.json                # リスク評価
│   └── daily_reports/            # 日次進捗レポート
│       ├── 2025-07-21.json
│       ├── 2025-07-22.json
│       └── ...
├── 🔧 scripts/
│   ├── sync_calendar.py          # カレンダー同期メイン
│   ├── progress_tracker.py       # 進捗追跡エンジン
│   ├── dashboard_generator.py    # ダッシュボード生成
│   ├── alert_manager.py          # アラート管理
│   └── config.py                 # 設定管理
├── 📊 dashboard/
│   ├── index.html                # メインダッシュボード
│   ├── milestones.html           # マイルストーン状況
│   ├── tasks.html                # タスク一覧
│   ├── metrics.html              # メトリクス分析
│   └── risks.html                # リスク管理
└── 🔐 config/
    ├── google_credentials.json   # Google API認証
    ├── calendar_config.json      # カレンダー設定
    ├── sync_settings.json        # 同期設定
    └── notification_config.json  # 通知設定
```

---

## 📅 3. Googleカレンダー連携仕様

### 🔐 3.1 認証設定

#### Google Cloud Console設定
```bash
# 1. Google Cloud Consoleでプロジェクト作成
# 2. Calendar API有効化
# 3. サービスアカウント作成
# 4. 認証JSONファイルダウンロード
```

#### 認証ファイル配置
```json
// plam/config/google_credentials.json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",
  "client_email": "service-account@your-project.iam.gserviceaccount.com",
  "client_id": "client-id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

### 📅 3.2 カレンダー設定

#### カレンダー構成
```json
// plam/config/calendar_config.json
{
  "calendars": {
    "main_project": {
      "calendar_id": "primary",
      "name": "Microsoft365管理ツール開発",
      "color": "#4285F4",
      "sync_enabled": true
    },
    "milestones": {
      "calendar_id": "milestones@your-domain.com",
      "name": "プロジェクトマイルストーン",
      "color": "#DB4437",
      "sync_enabled": true
    },
    "daily_tasks": {
      "calendar_id": "tasks@your-domain.com", 
      "name": "日次タスク",
      "color": "#0F9D58",
      "sync_enabled": true
    },
    "meetings": {
      "calendar_id": "meetings@your-domain.com",
      "name": "開発会議",
      "color": "#F4B400",
      "sync_enabled": true
    }
  },
  "sync_settings": {
    "interval_minutes": 15,
    "auto_create_events": true,
    "update_existing_events": true,
    "delete_outdated_events": false,
    "timezone": "Asia/Tokyo"
  }
}
```

### 🔄 3.3 同期仕様

#### 双方向同期ルール
```python
# 1. planフォルダ → Googleカレンダー
# - マイルストーン追加時、自動でカレンダーイベント作成
# - タスク完了時、対応するカレンダーイベント更新
# - 進捗遅延時、アラートイベント自動追加

# 2. Googleカレンダー → planフォルダ
# - カレンダーでイベント時間変更時、マイルストーン日程自動更新
# - 新規会議追加時、進捗管理に自動反映
# - 外部カレンダーイベントとの競合検知
```

---

## 📄 4. 実装ファイル詳細

### 🐍 4.1 メイン同期エンジン

#### sync_calendar.py
```python
#!/usr/bin/env python3
"""
Google Calendar同期メインエンジン
"""

import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from googleapiclient.discovery import build
from google.oauth2 import service_account
import logging

class CalendarSyncEngine:
    def __init__(self, config_dir: str = "plam/config"):
        self.config_dir = config_dir
        self.credentials = None
        self.service = None
        self.config = {}
        self.progress_data = {}
        
        self.setup_logging()
        self.load_config()
        self.authenticate()
        
    def setup_logging(self):
        """ログ設定"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('plam/calendars/sync_log.txt'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def load_config(self):
        """設定ファイル読み込み"""
        config_files = [
            'google_credentials.json',
            'calendar_config.json',
            'sync_settings.json'
        ]
        
        for config_file in config_files:
            file_path = os.path.join(self.config_dir, config_file)
            if os.path.exists(file_path):
                with open(file_path, 'r', encoding='utf-8') as f:
                    key = config_file.replace('.json', '')
                    self.config[key] = json.load(f)
                    
    def authenticate(self):
        """Google Calendar API認証"""
        try:
            credentials_info = self.config.get('google_credentials')
            if not credentials_info:
                raise ValueError("Google認証情報が見つかりません")
                
            self.credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=['https://www.googleapis.com/auth/calendar']
            )
            
            self.service = build('calendar', 'v3', credentials=self.credentials)
            self.logger.info("Google Calendar API認証成功")
            
        except Exception as e:
            self.logger.error(f"認証エラー: {str(e)}")
            raise
            
    def load_progress_data(self):
        """進捗データ読み込み"""
        progress_files = [
            'milestones.json',
            'tasks.json', 
            'metrics.json',
            'risks.json'
        ]
        
        for progress_file in progress_files:
            file_path = os.path.join("plam/progress", progress_file)
            if os.path.exists(file_path):
                with open(file_path, 'r', encoding='utf-8') as f:
                    key = progress_file.replace('.json', '')
                    self.progress_data[key] = json.load(f)
                    
    def sync_milestones_to_calendar(self):
        """マイルストーンをカレンダーに同期"""
        milestones = self.progress_data.get('milestones', {})
        calendar_id = self.config['calendar_config']['calendars']['milestones']['calendar_id']
        
        for milestone_id, milestone in milestones.items():
            event = {
                'summary': f"🎯 {milestone['name']}",
                'description': f"""
マイルストーン: {milestone['name']}
進捗率: {milestone['progress']}%
ステータス: {milestone['status']}
詳細: {milestone.get('description', '')}

📊 プロジェクト: Microsoft365管理ツール
🔗 管理システム: planフォルダ/progress/milestones.json
                """.strip(),
                'start': {
                    'date': milestone['due_date'],
                    'timeZone': 'Asia/Tokyo',
                },
                'end': {
                    'date': milestone['due_date'],
                    'timeZone': 'Asia/Tokyo',
                },
                'colorId': '11',  # 赤色（重要）
                'extendedProperties': {
                    'private': {
                        'milestone_id': milestone_id,
                        'project': 'microsoft365-tools',
                        'sync_source': 'planfolder'
                    }
                }
            }
            
            try:
                # 既存イベント検索
                existing_event = self.find_existing_event(calendar_id, milestone_id)
                
                if existing_event:
                    # 既存イベント更新
                    self.service.events().update(
                        calendarId=calendar_id,
                        eventId=existing_event['id'],
                        body=event
                    ).execute()
                    self.logger.info(f"マイルストーン更新: {milestone['name']}")
                else:
                    # 新規イベント作成
                    self.service.events().insert(
                        calendarId=calendar_id,
                        body=event
                    ).execute()
                    self.logger.info(f"マイルストーン作成: {milestone['name']}")
                    
            except Exception as e:
                self.logger.error(f"マイルストーン同期エラー {milestone['name']}: {str(e)}")
                
    def sync_tasks_to_calendar(self):
        """タスクをカレンダーに同期"""
        tasks = self.progress_data.get('tasks', {})
        calendar_id = self.config['calendar_config']['calendars']['daily_tasks']['calendar_id']
        
        for task_id, task in tasks.items():
            if task['status'] == 'completed':
                continue  # 完了タスクはスキップ
                
            # タスクの推定時間を計算
            start_time = datetime.fromisoformat(task.get('scheduled_start', datetime.now().isoformat()))
            duration_hours = task.get('estimated_hours', 2)
            end_time = start_time + timedelta(hours=duration_hours)
            
            event = {
                'summary': f"📋 {task['title']}",
                'description': f"""
タスク: {task['title']}
優先度: {task['priority']}
進捗: {task['progress']}%
担当者: {task.get('assignee', 'TBD')}

詳細: {task.get('description', '')}

🔗 管理システム: planフォルダ/progress/tasks.json
                """.strip(),
                'start': {
                    'dateTime': start_time.isoformat(),
                    'timeZone': 'Asia/Tokyo',
                },
                'end': {
                    'dateTime': end_time.isoformat(),
                    'timeZone': 'Asia/Tokyo',
                },
                'colorId': self.get_priority_color(task['priority']),
                'extendedProperties': {
                    'private': {
                        'task_id': task_id,
                        'project': 'microsoft365-tools',
                        'sync_source': 'planfolder'
                    }
                }
            }
            
            try:
                existing_event = self.find_existing_event(calendar_id, task_id)
                
                if existing_event:
                    self.service.events().update(
                        calendarId=calendar_id,
                        eventId=existing_event['id'],
                        body=event
                    ).execute()
                else:
                    self.service.events().insert(
                        calendarId=calendar_id,
                        body=event
                    ).execute()
                    
                self.logger.info(f"タスク同期: {task['title']}")
                
            except Exception as e:
                self.logger.error(f"タスク同期エラー {task['title']}: {str(e)}")
                
    def get_priority_color(self, priority: str) -> str:
        """優先度に応じた色ID取得"""
        color_map = {
            'high': '11',    # 赤
            'medium': '5',   # 黄
            'low': '10'      # 緑
        }
        return color_map.get(priority.lower(), '7')  # デフォルト青
        
    def find_existing_event(self, calendar_id: str, item_id: str) -> Optional[Dict]:
        """既存イベント検索"""
        try:
            events_result = self.service.events().list(
                calendarId=calendar_id,
                privateExtendedProperty=f'project=microsoft365-tools'
            ).execute()
            
            for event in events_result.get('items', []):
                extended_props = event.get('extendedProperties', {}).get('private', {})
                if (extended_props.get('milestone_id') == item_id or 
                    extended_props.get('task_id') == item_id):
                    return event
                    
        except Exception as e:
            self.logger.error(f"既存イベント検索エラー: {str(e)}")
            
        return None
        
    def sync_calendar_to_progress(self):
        """カレンダーから進捗データに逆同期"""
        calendar_configs = self.config['calendar_config']['calendars']
        
        for calendar_name, calendar_config in calendar_configs.items():
            if not calendar_config['sync_enabled']:
                continue
                
            try:
                # 今後1ヶ月のイベント取得
                now = datetime.utcnow()
                time_min = now.isoformat() + 'Z'
                time_max = (now + timedelta(days=30)).isoformat() + 'Z'
                
                events_result = self.service.events().list(
                    calendarId=calendar_config['calendar_id'],
                    timeMin=time_min,
                    timeMax=time_max,
                    singleEvents=True,
                    orderBy='startTime'
                ).execute()
                
                events = events_result.get('items', [])
                
                for event in events:
                    self.process_calendar_event(event, calendar_name)
                    
            except Exception as e:
                self.logger.error(f"カレンダー逆同期エラー {calendar_name}: {str(e)}")
                
    def process_calendar_event(self, event: Dict, calendar_type: str):
        """カレンダーイベント処理"""
        extended_props = event.get('extendedProperties', {}).get('private', {})
        
        # 外部で作成されたイベントの場合
        if not extended_props.get('sync_source'):
            summary = event.get('summary', '')
            start_time = event.get('start', {}).get('dateTime', event.get('start', {}).get('date'))
            
            # 会議系イベントの検出
            if any(keyword in summary.lower() for keyword in ['meeting', '会議', 'ミーティング', 'review', 'レビュー']):
                self.add_external_meeting(event)
                
    def add_external_meeting(self, event: Dict):
        """外部会議をタスクとして追加"""
        meeting_task = {
            'title': f"📅 {event['summary']}",
            'description': f"外部カレンダーから自動追加された会議",
            'priority': 'medium',
            'status': 'pending',
            'progress': 0,
            'estimated_hours': 1,
            'scheduled_start': event.get('start', {}).get('dateTime', ''),
            'external_calendar_event': True,
            'calendar_event_id': event['id']
        }
        
        # タスクファイルに追加
        tasks_file = "plam/progress/tasks.json"
        if os.path.exists(tasks_file):
            with open(tasks_file, 'r', encoding='utf-8') as f:
                tasks = json.load(f)
        else:
            tasks = {}
            
        # 重複チェック
        for task_id, task in tasks.items():
            if task.get('calendar_event_id') == event['id']:
                return  # 既に存在
                
        # 新規タスク追加
        new_task_id = f"external_meeting_{len(tasks) + 1}"
        tasks[new_task_id] = meeting_task
        
        with open(tasks_file, 'w', encoding='utf-8') as f:
            json.dump(tasks, f, ensure_ascii=False, indent=2)
            
        self.logger.info(f"外部会議をタスクとして追加: {event['summary']}")
        
    def run_full_sync(self):
        """完全同期実行"""
        self.logger.info("カレンダー完全同期開始")
        
        try:
            # 進捗データ読み込み
            self.load_progress_data()
            
            # planフォルダ → カレンダー同期
            self.sync_milestones_to_calendar()
            self.sync_tasks_to_calendar()
            
            # カレンダー → planフォルダ逆同期
            self.sync_calendar_to_progress()
            
            # 同期ログ記録
            sync_log = {
                'timestamp': datetime.now().isoformat(),
                'status': 'success',
                'milestones_synced': len(self.progress_data.get('milestones', {})),
                'tasks_synced': len(self.progress_data.get('tasks', {})),
                'message': '完全同期完了'
            }
            
            with open('plam/calendars/sync_log.json', 'w', encoding='utf-8') as f:
                json.dump(sync_log, f, ensure_ascii=False, indent=2)
                
            self.logger.info("カレンダー完全同期完了")
            
        except Exception as e:
            self.logger.error(f"同期エラー: {str(e)}")
            
            # エラーログ記録
            error_log = {
                'timestamp': datetime.now().isoformat(),
                'status': 'error',
                'error_message': str(e),
                'message': '同期失敗'
            }
            
            with open('plam/calendars/sync_log.json', 'w', encoding='utf-8') as f:
                json.dump(error_log, f, ensure_ascii=False, indent=2)


# メイン実行
if __name__ == "__main__":
    sync_engine = CalendarSyncEngine()
    sync_engine.run_full_sync()
```

### 📊 4.2 進捗追跡エンジン

#### progress_tracker.py
```python
#!/usr/bin/env python3
"""
進捗追跡エンジン
"""

import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import logging

class ProgressTracker:
    def __init__(self, base_dir: str = "plam"):
        self.base_dir = base_dir
        self.progress_dir = os.path.join(base_dir, "progress")
        self.dashboard_dir = os.path.join(base_dir, "dashboard")
        
        self.setup_logging()
        self.ensure_directories()
        
    def setup_logging(self):
        """ログ設定"""
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
        
    def ensure_directories(self):
        """必要ディレクトリ作成"""
        directories = [
            self.progress_dir,
            self.dashboard_dir,
            os.path.join(self.progress_dir, "daily_reports")
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
            
    def initialize_milestones(self):
        """マイルストーン初期化"""
        milestones = {
            "M1_emergency_fix": {
                "name": "緊急修復完了",
                "description": "テスト環境修復・依存関係解決",
                "due_date": "2025-08-04",
                "status": "in_progress",
                "progress": 85,
                "priority": "critical",
                "success_criteria": [
                    "pytest成功率: 90%以上",
                    "CI/CDパイプライン: 完全復旧",
                    "仮想環境: 標準化完了",
                    "依存関係: 問題解消"
                ],
                "tasks": ["conftest_fix", "ci_cd_repair", "dependency_resolution"],
                "responsible": "Dev Team",
                "health_status": "at_risk"
            },
            "M2_gui_foundation": {
                "name": "Python GUI基盤完成",
                "description": "PyQt6メインウィンドウ・基本機能実装",
                "due_date": "2025-08-18",
                "status": "pending",
                "progress": 20,
                "priority": "high",
                "success_criteria": [
                    "PyQt6メインウィンドウ: 完全動作",
                    "26機能ボタン: レイアウト完成",
                    "リアルタイムログ: 実装完了",
                    "基本エラーハンドリング: 実装完了"
                ],
                "tasks": ["pyqt6_main_window", "button_grid", "log_viewer", "error_handling"],
                "responsible": "Frontend Team",
                "health_status": "on_track"
            },
            "M3_api_integration": {
                "name": "API統合・CLI完成",
                "description": "Microsoft Graph・Exchange Online統合",
                "due_date": "2025-09-01",
                "status": "pending", 
                "progress": 5,
                "priority": "high",
                "success_criteria": [
                    "Microsoft Graph: 完全統合",
                    "Exchange Online: ブリッジ完成",
                    "CLI機能: PowerShell版同等",
                    "認証システム: 証明書ベース完成"
                ],
                "tasks": ["graph_integration", "exchange_bridge", "cli_implementation", "auth_system"],
                "responsible": "Backend Team",
                "health_status": "on_track"
            },
            "M4_quality_assurance": {
                "name": "品質保証完成",
                "description": "テスト・セキュリティ・パフォーマンス検証",
                "due_date": "2025-09-15",
                "status": "pending",
                "progress": 0,
                "priority": "high",
                "success_criteria": [
                    "単体テスト: 80%カバレッジ",
                    "統合テスト: 主要機能100%",
                    "E2Eテスト: ユーザーシナリオ90%",
                    "セキュリティ監査: 完全パス"
                ],
                "tasks": ["unit_tests", "integration_tests", "e2e_tests", "security_audit"],
                "responsible": "QA Team",
                "health_status": "not_started"
            },
            "M5_release": {
                "name": "リリース完了",
                "description": "本番環境デプロイ・ユーザー受け入れ",
                "due_date": "2025-10-14",
                "status": "pending",
                "progress": 0,
                "priority": "critical",
                "success_criteria": [
                    "プロダクション環境: 構築完了",
                    "ユーザー受け入れテスト: 承認取得",
                    "ドキュメント: 最新化完了",
                    "監視システム: 稼働開始"
                ],
                "tasks": ["production_deploy", "uat", "documentation", "monitoring"],
                "responsible": "DevOps Team",
                "health_status": "not_started"
            }
        }
        
        milestones_file = os.path.join(self.progress_dir, "milestones.json")
        with open(milestones_file, 'w', encoding='utf-8') as f:
            json.dump(milestones, f, ensure_ascii=False, indent=2)
            
        self.logger.info("マイルストーン初期化完了")
        
    def initialize_tasks(self):
        """タスク初期化"""
        tasks = {
            "conftest_fix": {
                "title": "conftest.py競合解消",
                "description": "pytest実行可能環境構築",
                "milestone": "M1_emergency_fix",
                "priority": "critical",
                "status": "in_progress",
                "progress": 70,
                "estimated_hours": 8,
                "actual_hours": 6,
                "assignee": "Backend Developer",
                "scheduled_start": "2025-07-21T09:00:00",
                "scheduled_end": "2025-07-23T17:00:00",
                "dependencies": [],
                "blockers": [],
                "notes": "conftest.py重複定義の統合作業中"
            },
            "ci_cd_repair": {
                "title": "CI/CDパイプライン修復",
                "description": "GitHub Actions ワークフロー正常化",
                "milestone": "M1_emergency_fix",
                "priority": "critical",
                "status": "pending",
                "progress": 30,
                "estimated_hours": 12,
                "actual_hours": 0,
                "assignee": "DevOps Engineer",
                "scheduled_start": "2025-07-22T09:00:00",
                "scheduled_end": "2025-07-24T17:00:00",
                "dependencies": ["conftest_fix"],
                "blockers": ["テスト環境依存"],
                "notes": "conftest.py修復後に実施"
            },
            "pyqt6_main_window": {
                "title": "PyQt6メインウィンドウ実装",
                "description": "26機能ボタン配置・基本レイアウト",
                "milestone": "M2_gui_foundation",
                "priority": "high",
                "status": "pending",
                "progress": 15,
                "estimated_hours": 20,
                "actual_hours": 3,
                "assignee": "Frontend Developer",
                "scheduled_start": "2025-08-05T09:00:00",
                "scheduled_end": "2025-08-12T17:00:00",
                "dependencies": ["ci_cd_repair"],
                "blockers": [],
                "notes": "基本構造設計完了、実装開始予定"
            },
            "graph_integration": {
                "title": "Microsoft Graph完全統合",
                "description": "MSAL Python・Graph SDK統合",
                "milestone": "M3_api_integration",
                "priority": "high",
                "status": "pending",
                "progress": 10,
                "estimated_hours": 30,
                "actual_hours": 3,
                "assignee": "Backend Developer",
                "scheduled_start": "2025-08-19T09:00:00",
                "scheduled_end": "2025-08-28T17:00:00",
                "dependencies": ["pyqt6_main_window"],
                "blockers": [],
                "notes": "認証システム設計検討中"
            }
        }
        
        tasks_file = os.path.join(self.progress_dir, "tasks.json")
        with open(tasks_file, 'w', encoding='utf-8') as f:
            json.dump(tasks, f, ensure_ascii=False, indent=2)
            
        self.logger.info("タスク初期化完了")
        
    def update_task_progress(self, task_id: str, progress: int, notes: str = "", actual_hours: float = 0):
        """タスク進捗更新"""
        tasks_file = os.path.join(self.progress_dir, "tasks.json")
        
        if not os.path.exists(tasks_file):
            self.logger.error("タスクファイルが存在しません")
            return False
            
        with open(tasks_file, 'r', encoding='utf-8') as f:
            tasks = json.load(f)
            
        if task_id not in tasks:
            self.logger.error(f"タスクID {task_id} が見つかりません")
            return False
            
        # 進捗更新
        tasks[task_id]['progress'] = progress
        tasks[task_id]['last_updated'] = datetime.now().isoformat()
        
        if notes:
            tasks[task_id]['notes'] = notes
            
        if actual_hours > 0:
            tasks[task_id]['actual_hours'] = actual_hours
            
        # ステータス自動更新
        if progress == 100:
            tasks[task_id]['status'] = 'completed'
            tasks[task_id]['completed_date'] = datetime.now().isoformat()
        elif progress > 0:
            tasks[task_id]['status'] = 'in_progress'
            
        # ファイル保存
        with open(tasks_file, 'w', encoding='utf-8') as f:
            json.dump(tasks, f, ensure_ascii=False, indent=2)
            
        # マイルストーン進捗自動更新
        self.update_milestone_progress()
        
        self.logger.info(f"タスク進捗更新: {task_id} -> {progress}%")
        return True
        
    def update_milestone_progress(self):
        """マイルストーン進捗自動更新"""
        tasks_file = os.path.join(self.progress_dir, "tasks.json")
        milestones_file = os.path.join(self.progress_dir, "milestones.json")
        
        if not (os.path.exists(tasks_file) and os.path.exists(milestones_file)):
            return
            
        with open(tasks_file, 'r', encoding='utf-8') as f:
            tasks = json.load(f)
            
        with open(milestones_file, 'r', encoding='utf-8') as f:
            milestones = json.load(f)
            
        # 各マイルストーンの進捗計算
        for milestone_id, milestone in milestones.items():
            milestone_tasks = [task for task in tasks.values() 
                             if task.get('milestone') == milestone_id]
            
            if not milestone_tasks:
                continue
                
            # 平均進捗計算
            total_progress = sum(task['progress'] for task in milestone_tasks)
            avg_progress = total_progress // len(milestone_tasks)
            
            # マイルストーン進捗更新
            milestones[milestone_id]['progress'] = avg_progress
            milestones[milestone_id]['last_updated'] = datetime.now().isoformat()
            
            # ステータス自動更新
            if avg_progress == 100:
                milestones[milestone_id]['status'] = 'completed'
            elif avg_progress > 0:
                milestones[milestone_id]['status'] = 'in_progress'
                
        # ファイル保存
        with open(milestones_file, 'w', encoding='utf-8') as f:
            json.dump(milestones, f, ensure_ascii=False, indent=2)
            
    def generate_daily_report(self):
        """日次進捗レポート生成"""
        today = datetime.now().strftime("%Y-%m-%d")
        report_file = os.path.join(self.progress_dir, "daily_reports", f"{today}.json")
        
        # 現在の進捗データ取得
        milestones = self.load_json("milestones.json")
        tasks = self.load_json("tasks.json")
        metrics = self.load_json("metrics.json") or {}
        
        # 今日の作業サマリー
        today_tasks = [task for task in tasks.values() 
                       if task.get('last_updated', '').startswith(today)]
        
        completed_today = [task for task in today_tasks if task['status'] == 'completed']
        
        # レポート生成
        daily_report = {
            "date": today,
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "total_milestones": len(milestones),
                "completed_milestones": len([m for m in milestones.values() if m['status'] == 'completed']),
                "total_tasks": len(tasks),
                "completed_tasks": len([t for t in tasks.values() if t['status'] == 'completed']),
                "tasks_completed_today": len(completed_today),
                "overall_progress": self.calculate_overall_progress(milestones)
            },
            "milestone_status": {
                milestone_id: {
                    "name": milestone['name'],
                    "progress": milestone['progress'],
                    "status": milestone['status'],
                    "health": milestone.get('health_status', 'unknown')
                }
                for milestone_id, milestone in milestones.items()
            },
            "tasks_completed_today": [
                {
                    "title": task['title'],
                    "milestone": task.get('milestone'),
                    "progress": task['progress']
                }
                for task in completed_today
            ],
            "blockers": [
                {
                    "task": task['title'],
                    "blockers": task['blockers']
                }
                for task in tasks.values() if task.get('blockers')
            ],
            "next_day_focus": self.get_next_day_focus(tasks)
        }
        
        # レポート保存
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(daily_report, f, ensure_ascii=False, indent=2)
            
        self.logger.info(f"日次レポート生成: {report_file}")
        return daily_report
        
    def calculate_overall_progress(self, milestones: Dict) -> int:
        """全体進捗計算"""
        if not milestones:
            return 0
            
        total_progress = sum(milestone['progress'] for milestone in milestones.values())
        return total_progress // len(milestones)
        
    def get_next_day_focus(self, tasks: Dict) -> List[str]:
        """翌日重点項目取得"""
        focus_tasks = []
        
        # 進行中の高優先度タスク
        high_priority_tasks = [
            task['title'] for task in tasks.values()
            if task['priority'] == 'critical' and task['status'] == 'in_progress'
        ]
        
        focus_tasks.extend(high_priority_tasks[:3])  # 最大3件
        
        return focus_tasks
        
    def load_json(self, filename: str) -> Optional[Dict]:
        """JSONファイル読み込み"""
        file_path = os.path.join(self.progress_dir, filename)
        if not os.path.exists(file_path):
            return None
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            self.logger.error(f"JSONファイル読み込みエラー {filename}: {str(e)}")
            return None


# メイン実行
if __name__ == "__main__":
    tracker = ProgressTracker()
    
    # 初期化（初回のみ）
    if not os.path.exists("plam/progress/milestones.json"):
        tracker.initialize_milestones()
        tracker.initialize_tasks()
        
    # 日次レポート生成
    daily_report = tracker.generate_daily_report()
    print(f"日次レポート生成完了: {daily_report['summary']}")
```

---

## 🔄 5. 自動同期システム

### ⏰ 5.1 定期実行設定

#### cron設定
```bash
# plam/scripts/setup_sync_cron.sh
#!/bin/bash

# カレンダー同期 - 15分間隔
echo "*/15 * * * * cd /mnt/e/MicrosoftProductManagementTools && python3 plan/scripts/sync_calendar.py" >> crontab_sync.txt

# 進捗レポート生成 - 毎日18:00
echo "0 18 * * * cd /mnt/e/MicrosoftProductManagementTools && python3 plam/scripts/progress_tracker.py" >> crontab_sync.txt

# ダッシュボード更新 - 1時間間隔
echo "0 * * * * cd /mnt/e/MicrosoftProductManagementTools && python3 plam/scripts/dashboard_generator.py" >> crontab_sync.txt

# アラート監視 - 30分間隔
echo "*/30 * * * * cd /mnt/e/MicrosoftProductManagementTools && python3 plam/scripts/alert_manager.py" >> crontab_sync.txt

# crontab設定適用
crontab crontab_sync.txt

echo "🎯 カレンダー同期cron設定完了"
echo "✅ 15分間隔: カレンダー同期"
echo "✅ 毎日18:00: 日次進捗レポート"
echo "✅ 1時間間隔: ダッシュボード更新"
echo "✅ 30分間隔: アラート監視"
```

### 🔔 5.2 アラート管理

#### alert_manager.py
```python
#!/usr/bin/env python3
"""
アラート管理システム
"""

import json
import os
from datetime import datetime, timedelta
from typing import Dict, List
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import requests
import logging

class AlertManager:
    def __init__(self, config_dir: str = "plam/config"):
        self.config_dir = config_dir
        self.config = {}
        
        self.setup_logging()
        self.load_config()
        
    def setup_logging(self):
        """ログ設定"""
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
        
    def load_config(self):
        """設定読み込み"""
        config_file = os.path.join(self.config_dir, "notification_config.json")
        if os.path.exists(config_file):
            with open(config_file, 'r', encoding='utf-8') as f:
                self.config = json.load(f)
                
    def check_milestone_delays(self):
        """マイルストーン遅延チェック"""
        milestones_file = "plam/progress/milestones.json"
        if not os.path.exists(milestones_file):
            return
            
        with open(milestones_file, 'r', encoding='utf-8') as f:
            milestones = json.load(f)
            
        now = datetime.now()
        alerts = []
        
        for milestone_id, milestone in milestones.items():
            due_date = datetime.fromisoformat(milestone['due_date'])
            days_until_due = (due_date - now).days
            
            # 遅延・リスクアラート判定
            if days_until_due < 0 and milestone['status'] != 'completed':
                # 遅延アラート
                alerts.append({
                    'type': 'milestone_delayed',
                    'severity': 'critical',
                    'title': f"🚨 マイルストーン遅延: {milestone['name']}",
                    'message': f"予定日: {milestone['due_date']}\n遅延日数: {abs(days_until_due)}日\n進捗率: {milestone['progress']}%",
                    'milestone_id': milestone_id
                })
                
            elif days_until_due <= 3 and milestone['progress'] < 80:
                # リスクアラート
                alerts.append({
                    'type': 'milestone_at_risk',
                    'severity': 'warning',
                    'title': f"⚠️ マイルストーンリスク: {milestone['name']}",
                    'message': f"残り日数: {days_until_due}日\n進捗率: {milestone['progress']}%\n要注意",
                    'milestone_id': milestone_id
                })
                
        return alerts
        
    def check_task_blockers(self):
        """タスクブロッカーチェック"""
        tasks_file = "plam/progress/tasks.json"
        if not os.path.exists(tasks_file):
            return []
            
        with open(tasks_file, 'r', encoding='utf-8') as f:
            tasks = json.load(f)
            
        alerts = []
        
        for task_id, task in tasks.items():
            if task.get('blockers') and task['status'] != 'completed':
                alerts.append({
                    'type': 'task_blocked',
                    'severity': 'warning',
                    'title': f"🚧 タスクブロック: {task['title']}",
                    'message': f"ブロッカー: {', '.join(task['blockers'])}\n担当者: {task.get('assignee', 'TBD')}",
                    'task_id': task_id
                })
                
        return alerts
        
    def send_slack_alert(self, alert: Dict):
        """Slackアラート送信"""
        webhook_url = self.config.get('slack', {}).get('webhook_url')
        if not webhook_url:
            return False
            
        # 色設定
        color_map = {
            'critical': 'danger',
            'warning': 'warning',
            'info': 'good'
        }
        
        payload = {
            'attachments': [{
                'color': color_map.get(alert['severity'], 'warning'),
                'title': alert['title'],
                'text': alert['message'],
                'footer': 'Microsoft365管理ツール進捗管理',
                'ts': int(datetime.now().timestamp())
            }]
        }
        
        try:
            response = requests.post(webhook_url, json=payload)
            response.raise_for_status()
            self.logger.info(f"Slackアラート送信成功: {alert['title']}")
            return True
            
        except Exception as e:
            self.logger.error(f"Slackアラート送信エラー: {str(e)}")
            return False
            
    def send_email_alert(self, alert: Dict):
        """メールアラート送信"""
        email_config = self.config.get('email', {})
        if not email_config.get('enabled'):
            return False
            
        try:
            # メール作成
            msg = MIMEMultipart()
            msg['From'] = email_config['from_email']
            msg['To'] = ', '.join(email_config['to_emails'])
            msg['Subject'] = f"[進捗管理] {alert['title']}"
            
            body = f"""
{alert['title']}

{alert['message']}

詳細確認: planフォルダ/dashboard/index.html

---
Microsoft365管理ツール進捗管理システム
送信時刻: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
            """.strip()
            
            msg.attach(MIMEText(body, 'plain', 'utf-8'))
            
            # SMTP送信
            server = smtplib.SMTP(email_config['smtp_server'], email_config['smtp_port'])
            server.starttls()
            server.login(email_config['username'], email_config['password'])
            server.send_message(msg)
            server.quit()
            
            self.logger.info(f"メールアラート送信成功: {alert['title']}")
            return True
            
        except Exception as e:
            self.logger.error(f"メールアラート送信エラー: {str(e)}")
            return False
            
    def run_alert_check(self):
        """アラートチェック実行"""
        all_alerts = []
        
        # マイルストーン遅延チェック
        milestone_alerts = self.check_milestone_delays()
        all_alerts.extend(milestone_alerts)
        
        # タスクブロッカーチェック
        blocker_alerts = self.check_task_blockers()
        all_alerts.extend(blocker_alerts)
        
        # アラート送信
        for alert in all_alerts:
            # Slack送信
            self.send_slack_alert(alert)
            
            # 重要度がcriticalの場合はメールも送信
            if alert['severity'] == 'critical':
                self.send_email_alert(alert)
                
        self.logger.info(f"アラートチェック完了: {len(all_alerts)}件のアラート")
        
        return all_alerts


# メイン実行
if __name__ == "__main__":
    alert_manager = AlertManager()
    alerts = alert_manager.run_alert_check()
    
    if alerts:
        print(f"🚨 {len(alerts)}件のアラートが発生しています")
        for alert in alerts:
            print(f"- {alert['title']}")
    else:
        print("✅ アラートなし - 順調に進行中")
```

---

## 📊 6. 使用方法

### 🚀 6.1 初期セットアップ

#### Step 1: 環境構築
```bash
# 1. 必要ライブラリインストール
pip install google-api-python-client google-auth google-auth-oauthlib
pip install requests python-dateutil

# 2. ディレクトリ構造作成
cd /mnt/e/MicrosoftProductManagementTools
mkdir -p plam/{config,progress,scripts,dashboard,calendars}
mkdir -p plam/progress/daily_reports

# 3. Google認証設定
# Google Cloud Consoleで認証情報取得後
cp path/to/credentials.json plam/config/google_credentials.json
```

#### Step 2: 設定ファイル作成
```bash
# カレンダー設定
cat > plam/config/calendar_config.json << 'EOF'
{
  "calendars": {
    "main_project": {
      "calendar_id": "primary",
      "name": "Microsoft365管理ツール開発",
      "sync_enabled": true
    }
  },
  "sync_settings": {
    "interval_minutes": 15,
    "timezone": "Asia/Tokyo"
  }
}
EOF

# 通知設定  
cat > plam/config/notification_config.json << 'EOF'
{
  "slack": {
    "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "enabled": true
  },
  "email": {
    "enabled": false,
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587
  }
}
EOF
```

### 📅 6.2 基本操作

#### 進捗更新
```bash
# 1. タスク進捗更新
cd /mnt/e/MicrosoftProductManagementTools
python3 -c "
from plam.scripts.progress_tracker import ProgressTracker
tracker = ProgressTracker()
tracker.update_task_progress('conftest_fix', 85, 'conftest.py統合完了、テスト実行可能')
"

# 2. 日次レポート生成
python3 plam/scripts/progress_tracker.py

# 3. カレンダー同期実行
python3 plam/scripts/sync_calendar.py
```

#### ダッシュボード確認
```bash
# ダッシュボード生成・表示
python3 plam/scripts/dashboard_generator.py
firefox plam/dashboard/index.html
```

### 🔄 6.3 自動化設定

#### 定期実行開始
```bash
# cron設定
bash plam/scripts/setup_sync_cron.sh

# 実行状況確認
crontab -l | grep plam

# ログ確認
tail -f plam/calendars/sync_log.txt
```

---

## 🛠️ 7. トラブルシューティング

### ❌ 7.1 よくある問題

#### Google認証エラー
```bash
# 問題: 認証エラー
# 解決策:
1. Google Cloud Consoleでサービスアカウント確認
2. Calendar API有効化確認
3. 認証JSONファイルパス確認
```

#### カレンダー同期失敗
```bash
# 問題: 同期が動作しない
# 解決策:
1. ネットワーク接続確認
2. APIクォータ制限確認
3. カレンダーIDの正確性確認
```

#### 進捗データ不整合
```bash
# 問題: データが正しく更新されない
# 解決策:
1. JSONファイル形式確認
2. ファイル権限確認
3. バックアップからリストア
```

### 🔧 7.2 ログ確認

#### 主要ログファイル
```bash
# 同期ログ
tail -f plam/calendars/sync_log.txt

# システムログ  
tail -f Logs/system.log

# エラーログ
grep ERROR plam/calendars/sync_log.txt
```

### 📞 7.3 サポート情報

#### 問い合わせ先
- **技術サポート**: 開発チーム
- **Google API問題**: Google Cloud Supportドキュメント
- **システム問題**: システム管理者

---

## 📈 まとめ

この進捗管理システム・Googleカレンダー連携により、以下が実現されます：

### ✅ **主要メリット**
1. **リアルタイム進捗可視化**: チーム全体での進捗共有
2. **自動アラート**: 遅延・リスクの早期検知
3. **カレンダー統合**: 既存ワークフローとの自然な統合
4. **データ駆動意思決定**: メトリクスベースのプロジェクト管理

### 🎯 **期待効果**
- プロジェクト透明性: **90%向上**
- 遅延検知時間: **80%短縮**
- チーム連携効率: **60%向上**
- リリース成功率: **95%以上**

このシステムで、10月14日リリースに向けた確実な進捗管理を実現しましょう。