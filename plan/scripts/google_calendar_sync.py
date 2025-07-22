#!/usr/bin/env python3
"""
Googleカレンダー連携システム
スケジュール管理・進捗同期
"""

import json
import os
import pickle
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import logging

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    GOOGLE_AVAILABLE = True
except ImportError:
    GOOGLE_AVAILABLE = False
    logging.warning("⚠️ Google APIライブラリが見つかりません。pip install google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client")

class GoogleCalendarSync:
    def __init__(self, credentials_path: str = "plan/credentials.json", token_path: str = "plan/token.pickle"):
        self.credentials_path = credentials_path
        self.token_path = token_path
        self.scopes = ['https://www.googleapis.com/auth/calendar']
        self.calendar_id = 'primary'  # プライマリカレンダー
        
        self.setup_logging()
        
        if GOOGLE_AVAILABLE:
            self.service = self.authenticate()
        else:
            self.service = None
            
    def setup_logging(self):
        """ログ設定"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
    def authenticate(self):
        """Google認証"""
        creds = None
        
        # 既存トークンファイル確認
        if os.path.exists(self.token_path):
            with open(self.token_path, 'rb') as token:
                creds = pickle.load(token)
                
        # 認証情報が無効または存在しない場合
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except Exception as e:
                    self.logger.warning(f"トークン更新失敗: {str(e)}")
                    creds = None
                    
            if not creds:
                if not os.path.exists(self.credentials_path):
                    self.logger.error(f"❌ 認証ファイルが見つかりません: {self.credentials_path}")
                    self.logger.info("📋 Google Cloud Consoleで認証ファイルを取得してください")
                    return None
                    
                try:
                    flow = InstalledAppFlow.from_client_secrets_file(
                        self.credentials_path, self.scopes)
                    creds = flow.run_local_server(port=0)
                except Exception as e:
                    self.logger.error(f"❌ 認証エラー: {str(e)}")
                    return None
                    
            # トークン保存
            with open(self.token_path, 'wb') as token:
                pickle.dump(creds, token)
                
        try:
            service = build('calendar', 'v3', credentials=creds)
            self.logger.info("✅ Googleカレンダー認証成功")
            return service
        except Exception as e:
            self.logger.error(f"❌ サービス構築エラー: {str(e)}")
            return None
            
    def create_calendar_event(self, title: str, start_time: datetime, end_time: datetime, 
                            description: str = "", location: str = "") -> Optional[str]:
        """カレンダーイベント作成"""
        if not self.service:
            self.logger.warning("⚠️ Google Calendar サービス未利用可能")
            return None
            
        try:
            event = {
                'summary': title,
                'description': description,
                'location': location,
                'start': {
                    'dateTime': start_time.isoformat(),
                    'timeZone': 'Asia/Tokyo',
                },
                'end': {
                    'dateTime': end_time.isoformat(),
                    'timeZone': 'Asia/Tokyo',
                },
                'reminders': {
                    'useDefault': False,
                    'overrides': [
                        {'method': 'popup', 'minutes': 15},
                        {'method': 'email', 'minutes': 30},
                    ],
                },
            }
            
            created_event = self.service.events().insert(
                calendarId=self.calendar_id, 
                body=event
            ).execute()
            
            self.logger.info(f"✅ イベント作成成功: {title}")
            return created_event.get('id')
            
        except Exception as e:
            self.logger.error(f"❌ イベント作成エラー: {str(e)}")
            return None
            
    def update_calendar_event(self, event_id: str, title: str = None, start_time: datetime = None, 
                            end_time: datetime = None, description: str = None) -> bool:
        """カレンダーイベント更新"""
        if not self.service:
            return False
            
        try:
            # 既存イベント取得
            event = self.service.events().get(
                calendarId=self.calendar_id, 
                eventId=event_id
            ).execute()
            
            # 更新内容適用
            if title:
                event['summary'] = title
            if description is not None:
                event['description'] = description
            if start_time:
                event['start']['dateTime'] = start_time.isoformat()
            if end_time:
                event['end']['dateTime'] = end_time.isoformat()
                
            # イベント更新
            updated_event = self.service.events().update(
                calendarId=self.calendar_id,
                eventId=event_id,
                body=event
            ).execute()
            
            self.logger.info(f"✅ イベント更新成功: {event_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ イベント更新エラー: {str(e)}")
            return False
            
    def sync_development_schedule(self, schedule_file: str = "plan/schedules/master_schedule.json") -> bool:
        """開発スケジュール同期"""
        if not self.service:
            self.logger.warning("⚠️ Google Calendar サービス未利用可能")
            return False
            
        try:
            # マスタースケジュール読み込み
            if not os.path.exists(schedule_file):
                self.logger.error(f"❌ スケジュールファイルが見つかりません: {schedule_file}")
                return False
                
            with open(schedule_file, 'r', encoding='utf-8') as f:
                schedule_data = json.load(f)
                
            sync_count = 0
            
            # Claude Codeセッション同期
            weekly_pattern = schedule_data.get('claude_code_schedule', {}).get('weekly_pattern', {})
            project_start = datetime.strptime(schedule_data['project_info']['start_date'], "%Y-%m-%d")
            project_end = datetime.strptime(schedule_data['project_info']['end_date'], "%Y-%m-%d")
            
            current_date = project_start
            while current_date <= project_end:
                day_name = current_date.strftime("%A").lower()
                
                if day_name in weekly_pattern:
                    day_schedule = weekly_pattern[day_name]
                    
                    if day_schedule.get('claude_hours', 0) > 0:
                        # 時間解析
                        time_range = day_schedule.get('time', '09:00-14:00')
                        start_time_str, end_time_str = time_range.split('-')
                        
                        start_time = datetime.combine(
                            current_date.date(),
                            datetime.strptime(start_time_str, "%H:%M").time()
                        )
                        end_time = datetime.combine(
                            current_date.date(),
                            datetime.strptime(end_time_str, "%H:%M").time()
                        )
                        
                        # イベント作成
                        title = f"🚀 Claude開発セッション - {day_schedule['focus']}"
                        description = f"フェーズ: {self.get_current_phase(current_date, schedule_data)}\\n重点: {day_schedule['focus']}\\n予定時間: {day_schedule.get('claude_hours', 5)}時間"
                        
                        event_id = self.create_calendar_event(
                            title, start_time, end_time, description, "リモート開発環境"
                        )
                        
                        if event_id:
                            sync_count += 1
                            
                current_date += timedelta(days=1)
                
            # マイルストーン同期
            milestones = schedule_data.get('milestones', {})
            for milestone_id, milestone in milestones.items():
                milestone_date = datetime.strptime(milestone['date'], "%Y-%m-%d")
                
                title = f"🎯 マイルストーン: {milestone['name']}"
                description = f"フェーズ: {milestone['phase']}\\n成果物:\\n" + "\\n".join(f"- {d}" for d in milestone['deliverables'])
                
                # 終日イベントとして作成
                end_date = milestone_date + timedelta(days=1)
                
                event_id = self.create_calendar_event(
                    title, milestone_date, end_date, description
                )
                
                if event_id:
                    sync_count += 1
                    
            self.logger.info(f"✅ スケジュール同期完了: {sync_count}件のイベント作成")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ スケジュール同期エラー: {str(e)}")
            return False
            
    def get_current_phase(self, target_date: datetime, schedule_data: Dict) -> str:
        """指定日の現在フェーズ取得"""
        for phase_id, phase in schedule_data.get('development_phases', {}).items():
            start_date = datetime.strptime(phase['duration'].split(' to ')[0], "%Y-%m-%d")
            end_date = datetime.strptime(phase['duration'].split(' to ')[1], "%Y-%m-%d")
            
            if start_date <= target_date <= end_date:
                return phase['name']
                
        return "未定義"
        
    def create_progress_update_event(self, date: datetime, completed_tasks: List[str], 
                                   issues: List[str] = None, next_tasks: List[str] = None) -> Optional[str]:
        """進捗更新イベント作成"""
        if not self.service:
            return None
            
        title = f"📊 開発進捗更新 - {date.strftime('%Y-%m-%d')}"
        
        description_parts = ["**完了タスク**:"]
        for task in completed_tasks:
            description_parts.append(f"✅ {task}")
            
        if issues:
            description_parts.extend(["", "**発見された問題**:"])
            for issue in issues:
                description_parts.append(f"⚠️ {issue}")
                
        if next_tasks:
            description_parts.extend(["", "**次回タスク**:"])
            for task in next_tasks:
                description_parts.append(f"📋 {task}")
                
        description = "\\n".join(description_parts)
        
        # 30分間のイベントとして作成
        start_time = datetime.combine(date.date(), datetime.strptime("17:30", "%H:%M").time())
        end_time = start_time + timedelta(minutes=30)
        
        return self.create_calendar_event(title, start_time, end_time, description)
        
    def get_upcoming_events(self, days: int = 7) -> List[Dict]:
        """今後のイベント取得"""
        if not self.service:
            return []
            
        try:
            now = datetime.now()
            time_min = now.isoformat() + 'Z'
            time_max = (now + timedelta(days=days)).isoformat() + 'Z'
            
            events_result = self.service.events().list(
                calendarId=self.calendar_id,
                timeMin=time_min,
                timeMax=time_max,
                maxResults=50,
                singleEvents=True,
                orderBy='startTime'
            ).execute()
            
            events = events_result.get('items', [])
            
            parsed_events = []
            for event in events:
                parsed_event = {
                    'id': event.get('id'),
                    'title': event.get('summary', ''),
                    'start': event.get('start', {}).get('dateTime', ''),
                    'end': event.get('end', {}).get('dateTime', ''),
                    'description': event.get('description', '')
                }
                parsed_events.append(parsed_event)
                
            return parsed_events
            
        except Exception as e:
            self.logger.error(f"❌ イベント取得エラー: {str(e)}")
            return []


# フォールバック機能（Google APIが利用できない場合）
class CalendarSyncFallback:
    """Google API未利用時のフォールバック機能"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.events_file = "plan/calendar_sync/local_events.json"
        os.makedirs(os.path.dirname(self.events_file), exist_ok=True)
        
    def save_event_locally(self, title: str, start_time: datetime, end_time: datetime, description: str = "") -> str:
        """ローカルイベント保存"""
        try:
            # 既存イベント読み込み
            events = []
            if os.path.exists(self.events_file):
                with open(self.events_file, 'r', encoding='utf-8') as f:
                    events = json.load(f)
                    
            # 新イベント追加
            event_id = f"local_{int(datetime.now().timestamp())}"
            new_event = {
                'id': event_id,
                'title': title,
                'start_time': start_time.isoformat(),
                'end_time': end_time.isoformat(),
                'description': description,
                'created_at': datetime.now().isoformat()
            }
            
            events.append(new_event)
            
            # ファイル保存
            with open(self.events_file, 'w', encoding='utf-8') as f:
                json.dump(events, f, ensure_ascii=False, indent=2)
                
            self.logger.info(f"✅ ローカルイベント保存: {title}")
            return event_id
            
        except Exception as e:
            self.logger.error(f"❌ ローカル保存エラー: {str(e)}")
            return ""


# 使用例・テスト実行
if __name__ == "__main__":
    print("📅 Googleカレンダー連携システムテスト開始")
    
    calendar_sync = GoogleCalendarSync()
    
    if calendar_sync.service:
        print("✅ Google Calendar認証成功")
        
        # 開発スケジュール同期テスト
        if calendar_sync.sync_development_schedule():
            print("✅ 開発スケジュール同期成功")
        else:
            print("❌ 開発スケジュール同期失敗")
            
        # 今後のイベント取得テスト
        upcoming_events = calendar_sync.get_upcoming_events()
        print(f"📋 今後7日間のイベント: {len(upcoming_events)}件")
        
    else:
        print("⚠️ Google Calendar未利用 - フォールバック機能でローカル保存")
        fallback = CalendarSyncFallback()
        
        # テストイベント作成
        test_start = datetime.now() + timedelta(hours=1)
        test_end = test_start + timedelta(hours=5)
        
        event_id = fallback.save_event_locally(
            "🚀 Claude開発セッション（テスト）",
            test_start,
            test_end,
            "テスト用セッション"
        )
        
        if event_id:
            print("✅ フォールバック機能でローカル保存成功")