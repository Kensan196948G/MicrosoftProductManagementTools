#!/usr/bin/env python3
"""
Google Calendar同期メインエンジン
Microsoft 365管理ツール開発プロジェクト用
"""

import json
import os
import sys
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
        # ログディレクトリ作成
        log_dir = "plam/calendars"
        os.makedirs(log_dir, exist_ok=True)
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(os.path.join(log_dir, 'sync_log.txt')),
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
            else:
                self.logger.warning(f"設定ファイルが見つかりません: {file_path}")
                
    def authenticate(self):
        """Google Calendar API認証"""
        try:
            credentials_info = self.config.get('google_credentials')
            if not credentials_info:
                self.logger.error("Google認証情報が見つかりません")
                return False
                
            self.credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=['https://www.googleapis.com/auth/calendar']
            )
            
            self.service = build('calendar', 'v3', credentials=self.credentials)
            self.logger.info("Google Calendar API認証成功")
            return True
            
        except Exception as e:
            self.logger.error(f"認証エラー: {str(e)}")
            return False
            
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
            else:
                self.logger.warning(f"進捗ファイルが見つかりません: {file_path}")
                self.progress_data[progress_file.replace('.json', '')] = {}
                
    def sync_milestones_to_calendar(self):
        """マイルストーンをカレンダーに同期"""
        if not self.service:
            self.logger.error("カレンダーサービスが初期化されていません")
            return
            
        milestones = self.progress_data.get('milestones', {})
        if not milestones:
            self.logger.warning("マイルストーンデータが空です")
            return
            
        calendar_config = self.config.get('calendar_config', {})
        milestones_calendar = calendar_config.get('calendars', {}).get('milestones', {})
        calendar_id = milestones_calendar.get('calendar_id', 'primary')
        
        for milestone_id, milestone in milestones.items():
            event = {
                'summary': f"🎯 {milestone['name']}",
                'description': f"""
マイルストーン: {milestone['name']}
進捗率: {milestone['progress']}%
ステータス: {milestone['status']}
優先度: {milestone['priority']}
詳細: {milestone.get('description', '')}

成功基準:
{chr(10).join(f"- {criteria}" for criteria in milestone.get('success_criteria', []))}

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
                'colorId': self.get_milestone_color(milestone),
                'extendedProperties': {
                    'private': {
                        'milestone_id': milestone_id,
                        'project': 'microsoft365-tools',
                        'sync_source': 'planfolder',
                        'item_type': 'milestone'
                    }
                }
            }
            
            try:
                # 既存イベント検索
                existing_event = self.find_existing_event(calendar_id, milestone_id, 'milestone')
                
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
                
    def get_milestone_color(self, milestone: Dict) -> str:
        """マイルストーンの色ID取得"""
        priority_color_map = {
            'critical': '11',  # 赤
            'high': '9',       # 青
            'medium': '5',     # 黄
            'low': '10'        # 緑
        }
        
        status_color_map = {
            'completed': '10',   # 緑
            'in_progress': '9',  # 青
            'at_risk': '11',     # 赤
            'pending': '8'       # グレー
        }
        
        # 優先度とステータスで色を決定
        priority = milestone.get('priority', 'medium').lower()
        status = milestone.get('status', 'pending').lower()
        health = milestone.get('health_status', '').lower()
        
        if health == 'at_risk':
            return '11'  # 赤
        elif status == 'completed':
            return '10'  # 緑
        else:
            return priority_color_map.get(priority, '8')  # デフォルトグレー
                
    def sync_tasks_to_calendar(self):
        """タスクをカレンダーに同期"""
        if not self.service:
            return
            
        tasks = self.progress_data.get('tasks', {})
        if not tasks:
            self.logger.warning("タスクデータが空です")
            return
            
        calendar_config = self.config.get('calendar_config', {})
        tasks_calendar = calendar_config.get('calendars', {}).get('daily_tasks', {})
        calendar_id = tasks_calendar.get('calendar_id', 'primary')
        
        for task_id, task in tasks.items():
            if task['status'] == 'completed':
                continue  # 完了タスクはスキップ
                
            # タスクの時間計算
            scheduled_start = task.get('scheduled_start')
            if scheduled_start:
                try:
                    start_time = datetime.fromisoformat(scheduled_start.replace('Z', '+00:00'))
                except:
                    start_time = datetime.now()
            else:
                start_time = datetime.now()
                
            duration_hours = task.get('estimated_hours', 2)
            end_time = start_time + timedelta(hours=duration_hours)
            
            event = {
                'summary': f"📋 {task['title']}",
                'description': f"""
タスク: {task['title']}
マイルストーン: {task.get('milestone', 'TBD')}
優先度: {task['priority']}
進捗: {task['progress']}%
担当者: {task.get('assignee', 'TBD')}
推定工数: {task.get('estimated_hours', 'TBD')}時間

詳細: {task.get('description', '')}

依存関係: {', '.join(task.get('dependencies', []))}
ブロッカー: {', '.join(task.get('blockers', []))}

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
                        'sync_source': 'planfolder',
                        'item_type': 'task'
                    }
                }
            }
            
            try:
                existing_event = self.find_existing_event(calendar_id, task_id, 'task')
                
                if existing_event:
                    self.service.events().update(
                        calendarId=calendar_id,
                        eventId=existing_event['id'],
                        body=event
                    ).execute()
                    self.logger.info(f"タスク更新: {task['title']}")
                else:
                    self.service.events().insert(
                        calendarId=calendar_id,
                        body=event
                    ).execute()
                    self.logger.info(f"タスク作成: {task['title']}")
                    
            except Exception as e:
                self.logger.error(f"タスク同期エラー {task['title']}: {str(e)}")
                
    def get_priority_color(self, priority: str) -> str:
        """優先度に応じた色ID取得"""
        color_map = {
            'critical': '11',  # 赤
            'high': '9',       # 青
            'medium': '5',     # 黄
            'low': '10'        # 緑
        }
        return color_map.get(priority.lower(), '8')  # デフォルトグレー
        
    def find_existing_event(self, calendar_id: str, item_id: str, item_type: str) -> Optional[Dict]:
        """既存イベント検索"""
        try:
            events_result = self.service.events().list(
                calendarId=calendar_id,
                privateExtendedProperty='project=microsoft365-tools'
            ).execute()
            
            for event in events_result.get('items', []):
                extended_props = event.get('extendedProperties', {}).get('private', {})
                
                if item_type == 'milestone' and extended_props.get('milestone_id') == item_id:
                    return event
                elif item_type == 'task' and extended_props.get('task_id') == item_id:
                    return event
                    
        except Exception as e:
            self.logger.error(f"既存イベント検索エラー: {str(e)}")
            
        return None
        
    def sync_calendar_to_progress(self):
        """カレンダーから進捗データに逆同期"""
        calendar_configs = self.config.get('calendar_config', {}).get('calendars', {})
        
        for calendar_name, calendar_config in calendar_configs.items():
            if not calendar_config.get('sync_enabled', True):
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
        
        # 外部で作成されたイベント（プロジェクト管理外）の場合
        if not extended_props.get('sync_source'):
            summary = event.get('summary', '')
            start_time = event.get('start', {}).get('dateTime', event.get('start', {}).get('date'))
            
            # 会議系イベントの検出
            meeting_keywords = ['meeting', '会議', 'ミーティング', 'review', 'レビュー', 'standup', '定例']
            if any(keyword in summary.lower() for keyword in meeting_keywords):
                self.add_external_meeting(event)
                
    def add_external_meeting(self, event: Dict):
        """外部会議をタスクとして追加"""
        meeting_task = {
            'title': f"📅 {event['summary']}",
            'description': f"外部カレンダーから自動追加された会議\n元のイベント: {event.get('htmlLink', '')}",
            'milestone': 'external_meetings',
            'priority': 'medium',
            'status': 'pending',
            'progress': 0,
            'estimated_hours': 1,
            'scheduled_start': event.get('start', {}).get('dateTime', ''),
            'external_calendar_event': True,
            'calendar_event_id': event['id'],
            'assignee': 'チーム全体'
        }
        
        # タスクファイル読み込み
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
        new_task_id = f"external_meeting_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        tasks[new_task_id] = meeting_task
        
        # ファイル保存
        os.makedirs(os.path.dirname(tasks_file), exist_ok=True)
        with open(tasks_file, 'w', encoding='utf-8') as f:
            json.dump(tasks, f, ensure_ascii=False, indent=2)
            
        self.logger.info(f"外部会議をタスクとして追加: {event['summary']}")
        
    def run_full_sync(self):
        """完全同期実行"""
        self.logger.info("📅 カレンダー完全同期開始")
        
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
                'tasks_synced': len([t for t in self.progress_data.get('tasks', {}).values() if t['status'] != 'completed']),
                'message': '完全同期完了'
            }
            
            # ログディレクトリ作成
            log_dir = os.path.dirname('plam/calendars/sync_log.json')
            os.makedirs(log_dir, exist_ok=True)
            
            with open('plam/calendars/sync_log.json', 'w', encoding='utf-8') as f:
                json.dump(sync_log, f, ensure_ascii=False, indent=2)
                
            self.logger.info("✅ カレンダー完全同期完了")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ 同期エラー: {str(e)}")
            
            # エラーログ記録
            error_log = {
                'timestamp': datetime.now().isoformat(),
                'status': 'error',
                'error_message': str(e),
                'message': '同期失敗'
            }
            
            log_dir = os.path.dirname('plam/calendars/sync_log.json')
            os.makedirs(log_dir, exist_ok=True)
            
            with open('plam/calendars/sync_log.json', 'w', encoding='utf-8') as f:
                json.dump(error_log, f, ensure_ascii=False, indent=2)
                
            return False


# メイン実行
if __name__ == "__main__":
    # 実行ディレクトリを確認
    if not os.path.exists("plam"):
        print("❌ エラー: planフォルダが見つかりません")
        print("プロジェクトルートディレクトリから実行してください")
        sys.exit(1)
        
    sync_engine = CalendarSyncEngine()
    
    if sync_engine.run_full_sync():
        print("✅ カレンダー同期が完了しました")
    else:
        print("❌ カレンダー同期でエラーが発生しました")
        sys.exit(1)