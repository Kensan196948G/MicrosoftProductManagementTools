#!/usr/bin/env python3
"""
スケジュール管理システム
plan/フォルダ内でのスケジュール表作成・管理
"""

import json
import os
import sys
from datetime import datetime, timedelta, date
from typing import Dict, List, Optional
import calendar
import logging

class ScheduleManager:
    def __init__(self, base_dir: str = "plan"):
        self.base_dir = base_dir
        self.schedules_dir = os.path.join(base_dir, "schedules")
        self.calendar_sync_dir = os.path.join(base_dir, "calendar_sync")
        self.dashboard_dir = os.path.join(base_dir, "dashboard")
        
        self.setup_logging()
        self.ensure_directories()
        
    def setup_logging(self):
        """ログ設定"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
    def ensure_directories(self):
        """必要ディレクトリ作成"""
        directories = [
            self.schedules_dir,
            os.path.join(self.schedules_dir, "weekly_plans"),
            os.path.join(self.schedules_dir, "daily_sessions"),
            self.calendar_sync_dir,
            self.dashboard_dir
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
            
    def load_master_schedule(self) -> Dict:
        """マスタースケジュール読み込み"""
        master_file = os.path.join(self.schedules_dir, "master_schedule.json")
        if os.path.exists(master_file):
            with open(master_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {}
        
    def generate_weekly_schedule(self, week_start_date: str) -> Dict:
        """週次スケジュール生成"""
        master = self.load_master_schedule()
        week_start = datetime.strptime(week_start_date, "%Y-%m-%d")
        
        # 週番号計算
        project_start = datetime.strptime(master['project_info']['start_date'], "%Y-%m-%d")
        week_number = ((week_start - project_start).days // 7) + 1
        
        # 現在フェーズ特定
        current_phase = self.get_current_phase(week_start_date, master)
        
        weekly_schedule = {
            "week_info": {
                "week_number": week_number,
                "start_date": week_start_date,
                "end_date": (week_start + timedelta(days=6)).strftime("%Y-%m-%d"),
                "current_phase": current_phase['name'] if current_phase else "未定義",
                "claude_sessions_planned": 5
            },
            "daily_schedule": {},
            "weekly_objectives": current_phase['objectives'] if current_phase else [],
            "milestones_this_week": self.get_milestones_for_week(week_start_date, master),
            "risk_factors": self.get_week_risks(week_start_date, master)
        }
        
        # 日次スケジュール生成
        claude_pattern = master['claude_code_schedule']['weekly_pattern']
        
        for i in range(7):
            current_date = week_start + timedelta(days=i)
            day_name = current_date.strftime("%A").lower()
            
            if day_name in claude_pattern:
                day_schedule = claude_pattern[day_name].copy()
                day_schedule['date'] = current_date.strftime("%Y-%m-%d")
                day_schedule['day_of_week'] = day_name
                
                # フェーズ固有のタスク追加
                if current_phase:
                    day_schedule['phase_tasks'] = self.get_phase_tasks_for_day(
                        day_name, current_phase, week_number
                    )
                
                weekly_schedule['daily_schedule'][day_name] = day_schedule
                
        return weekly_schedule
        
    def get_current_phase(self, date_str: str, master: Dict) -> Optional[Dict]:
        """指定日時の現在フェーズ取得"""
        target_date = datetime.strptime(date_str, "%Y-%m-%d")
        
        for phase_id, phase in master['development_phases'].items():
            start_date = datetime.strptime(phase['duration'].split(' to ')[0], "%Y-%m-%d")
            end_date = datetime.strptime(phase['duration'].split(' to ')[1], "%Y-%m-%d")
            
            if start_date <= target_date <= end_date:
                return phase
                
        return None
        
    def get_milestones_for_week(self, week_start_date: str, master: Dict) -> List[Dict]:
        """週内のマイルストーン取得"""
        week_start = datetime.strptime(week_start_date, "%Y-%m-%d")
        week_end = week_start + timedelta(days=6)
        
        milestones_this_week = []
        
        for milestone_id, milestone in master['milestones'].items():
            milestone_date = datetime.strptime(milestone['date'], "%Y-%m-%d")
            
            if week_start <= milestone_date <= week_end:
                milestone_copy = milestone.copy()
                milestone_copy['id'] = milestone_id
                milestone_copy['days_until'] = (milestone_date - datetime.now()).days
                milestones_this_week.append(milestone_copy)
                
        return milestones_this_week
        
    def get_week_risks(self, week_start_date: str, master: Dict) -> List[Dict]:
        """週のリスク要因取得"""
        week_start = datetime.strptime(week_start_date, "%Y-%m-%d")
        week_end = week_start + timedelta(days=6)
        
        risks = []
        
        for risk in master['risk_management']['high_risk_periods']:
            risk_start = datetime.strptime(risk['period'].split(' to ')[0], "%Y-%m-%d")
            risk_end = datetime.strptime(risk['period'].split(' to ')[1], "%Y-%m-%d")
            
            # 週とリスク期間の重複確認
            if not (week_end < risk_start or week_start > risk_end):
                risks.append(risk)
                
        return risks
        
    def get_phase_tasks_for_day(self, day_name: str, phase: Dict, week_number: int) -> List[str]:
        """フェーズ・曜日固有のタスク生成"""
        phase_name = phase['name']
        
        # フェーズ別日次タスクマッピング
        phase_tasks = {
            "緊急修復フェーズ": {
                "monday": ["conftest.py競合解消", "pytest環境確認", "CI/CD状況確認"],
                "wednesday": ["依存関係問題解決", "仮想環境標準化", "パッケージ更新"],
                "friday": ["GitHub Actions修正", "自動テスト復旧", "品質チェック"],
                "saturday": ["統合テスト実行", "全体動作確認", "週末バグ修正"],
                "sunday": ["コード品質向上", "ドキュメント更新", "次週準備"]
            },
            "Python GUI基盤完成": {
                "monday": ["PyQt6環境構築", "メインウィンドウ設計", "基本レイアウト"],
                "wednesday": ["26機能ボタン実装", "イベント処理", "ログビューア"],
                "friday": ["PowerShellブリッジ", "エラーハンドリング", "統合テスト"],
                "saturday": ["GUI全機能テスト", "パフォーマンス最適化", "メモリ使用量確認"],
                "sunday": ["コード整理", "ドキュメント作成", "次週計画"]
            },
            "API統合・CLI完成": {
                "monday": ["Microsoft Graph SDK", "認証システム実装", "基本API呼び出し"],
                "wednesday": ["Exchange Onlineブリッジ", "PowerShell統合", "データ取得"],
                "friday": ["CLI機能実装", "コマンドライン処理", "出力フォーマット"],
                "saturday": ["API統合テスト", "パフォーマンステスト", "エラー処理"],
                "sunday": ["全機能テスト", "品質確認", "ドキュメント更新"]
            },
            "品質保証完成": {
                "monday": ["単体テスト実装", "テストカバレッジ向上", "モック作成"],
                "wednesday": ["統合テスト実装", "E2Eテスト", "自動化テスト"],
                "friday": ["セキュリティ監査", "パフォーマンステスト", "負荷テスト"],
                "saturday": ["品質メトリクス確認", "バグ修正", "最終調整"],
                "sunday": ["品質レポート", "次フェーズ準備", "リリース準備"]
            },
            "リリース完了": {
                "monday": ["本番環境構築", "デプロイメント準備", "監視設定"],
                "wednesday": ["ユーザー受け入れテスト", "ドキュメント最終化", "サポート準備"],
                "friday": ["最終テスト", "リリース前確認", "ロールバック準備"],
                "saturday": ["リリース作業", "監視開始", "問題対応"],
                "sunday": ["リリース後監視", "フィードバック収集", "改善計画"]
            }
        }
        
        return phase_tasks.get(phase_name, {}).get(day_name, ["一般開発作業"])
        
    def create_daily_session_plan(self, date_str: str) -> Dict:
        """日次セッション計画作成"""
        target_date = datetime.strptime(date_str, "%Y-%m-%d")
        day_name = target_date.strftime("%A").lower()
        
        master = self.load_master_schedule()
        current_phase = self.get_current_phase(date_str, master)
        
        # 週次スケジュールから日次情報取得
        week_start = target_date - timedelta(days=target_date.weekday())
        weekly_schedule = self.generate_weekly_schedule(week_start.strftime("%Y-%m-%d"))
        
        daily_plan = {
            "session_info": {
                "date": date_str,
                "day_of_week": day_name,
                "phase": current_phase['name'] if current_phase else "未定義",
                "session_type": "claude_code_development"
            },
            "schedule": weekly_schedule['daily_schedule'].get(day_name, {}),
            "specific_tasks": [],
            "success_criteria": [],
            "risk_mitigation": [],
            "preparation_checklist": [
                "前回セッション結果確認",
                "今日の作業優先度確認",
                "開発環境状況確認",
                "tmux環境準備",
                "必要なファイル・ドキュメント準備"
            ],
            "session_structure": master['claude_code_schedule']['session_structure'],
            "handover_checklist": [
                "作業内容Git コミット",
                "進捗状況更新",
                "発見した問題の記録",
                "次回作業項目明確化",
                "品質メトリクス更新"
            ]
        }
        
        # フェーズ固有のタスク追加
        if current_phase:
            phase_tasks = self.get_phase_tasks_for_day(day_name, current_phase, 1)
            daily_plan['specific_tasks'] = phase_tasks
            daily_plan['success_criteria'] = current_phase.get('success_criteria', {})
            
        return daily_plan
        
    def update_session_progress(self, date_str: str, progress_data: Dict):
        """セッション進捗更新"""
        session_file = os.path.join(
            self.schedules_dir, "daily_sessions", f"{date_str}.json"
        )
        
        # 既存セッションデータ読み込み
        if os.path.exists(session_file):
            with open(session_file, 'r', encoding='utf-8') as f:
                session_data = json.load(f)
        else:
            session_data = self.create_daily_session_plan(date_str)
            
        # 進捗データ更新
        session_data['progress'] = progress_data
        session_data['last_updated'] = datetime.now().isoformat()
        
        # ファイル保存
        with open(session_file, 'w', encoding='utf-8') as f:
            json.dump(session_data, f, ensure_ascii=False, indent=2)
            
        self.logger.info(f"セッション進捗更新: {date_str}")
        
    def generate_weekly_report(self, week_start_date: str) -> Dict:
        """週次レポート生成"""
        week_start = datetime.strptime(week_start_date, "%Y-%m-%d")
        
        weekly_report = {
            "report_info": {
                "week_start": week_start_date,
                "week_end": (week_start + timedelta(days=6)).strftime("%Y-%m-%d"),
                "generated_at": datetime.now().isoformat()
            },
            "sessions_completed": [],
            "objectives_achieved": [],
            "milestones_reached": [],
            "issues_encountered": [],
            "next_week_focus": [],
            "metrics": {
                "claude_hours_used": 0,
                "tasks_completed": 0,
                "bugs_fixed": 0,
                "test_coverage_change": 0
            }
        }
        
        # 週内のセッションデータ収集
        for i in range(7):
            session_date = (week_start + timedelta(days=i)).strftime("%Y-%m-%d")
            session_file = os.path.join(
                self.schedules_dir, "daily_sessions", f"{session_date}.json"
            )
            
            if os.path.exists(session_file):
                with open(session_file, 'r', encoding='utf-8') as f:
                    session_data = json.load(f)
                    weekly_report['sessions_completed'].append(session_data)
                    
                    # メトリクス集計
                    if 'progress' in session_data:
                        progress = session_data['progress']
                        weekly_report['metrics']['claude_hours_used'] += progress.get('hours_used', 0)
                        weekly_report['metrics']['tasks_completed'] += len(progress.get('completed_tasks', []))
                        weekly_report['metrics']['bugs_fixed'] += progress.get('bugs_fixed', 0)
                        
        return weekly_report
        
    def export_to_ics(self, start_date: str, weeks: int = 12) -> str:
        """ICSカレンダーファイル生成"""
        ics_content = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Microsoft365Tools//Schedule Manager//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH"
        ]
        
        master = self.load_master_schedule()
        current_date = datetime.strptime(start_date, "%Y-%m-%d")
        
        # ClaudeCodeセッション予定追加
        for week in range(weeks):
            week_start = current_date + timedelta(weeks=week)
            weekly_schedule = self.generate_weekly_schedule(week_start.strftime("%Y-%m-%d"))
            
            for day_name, day_schedule in weekly_schedule['daily_schedule'].items():
                if day_schedule.get('claude_hours', 0) > 0:
                    session_date = datetime.strptime(day_schedule['date'], "%Y-%m-%d")
                    
                    # 時間解析
                    time_range = day_schedule.get('time', '09:00-14:00')
                    start_time, end_time = time_range.split('-')
                    
                    start_datetime = datetime.combine(
                        session_date.date(),
                        datetime.strptime(start_time, "%H:%M").time()
                    )
                    end_datetime = datetime.combine(
                        session_date.date(), 
                        datetime.strptime(end_time, "%H:%M").time()
                    )
                    
                    # ICSイベント生成
                    event_lines = [
                        "BEGIN:VEVENT",
                        f"UID:{session_date.strftime('%Y%m%d')}-claude-session@microsoft365tools",
                        f"DTSTART:{start_datetime.strftime('%Y%m%dT%H%M%S')}",
                        f"DTEND:{end_datetime.strftime('%Y%m%dT%H%M%S')}",
                        f"SUMMARY:🚀 Claude開発セッション - {day_schedule['focus']}",
                        f"DESCRIPTION:フェーズ: {weekly_schedule['week_info']['current_phase']}\\n"
                        f"重点: {day_schedule['focus']}\\n"
                        f"予定時間: {day_schedule.get('claude_hours', 5)}時間",
                        "CATEGORIES:Development,ClaudeCode",
                        "END:VEVENT"
                    ]
                    ics_content.extend(event_lines)
                    
        # マイルストーン追加
        for milestone_id, milestone in master['milestones'].items():
            milestone_date = datetime.strptime(milestone['date'], "%Y-%m-%d")
            
            event_lines = [
                "BEGIN:VEVENT",
                f"UID:{milestone_id}-milestone@microsoft365tools",
                f"DTSTART;VALUE=DATE:{milestone_date.strftime('%Y%m%d')}",
                f"DTEND;VALUE=DATE:{milestone_date.strftime('%Y%m%d')}",
                f"SUMMARY:🎯 マイルストーン: {milestone['name']}",
                f"DESCRIPTION:フェーズ: {milestone['phase']}\\n"
                "成果物:\\n" + "\\n".join(f"- {d}" for d in milestone['deliverables']),
                "CATEGORIES:Milestone,Project",
                "END:VEVENT"
            ]
            ics_content.extend(event_lines)
            
        ics_content.append("END:VCALENDAR")
        
        # ICSファイル保存
        ics_file = os.path.join(self.calendar_sync_dir, "project_schedule.ics")
        with open(ics_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(ics_content))
            
        self.logger.info(f"ICSファイル生成: {ics_file}")
        return ics_file
        
    def run_schedule_management(self):
        """スケジュール管理実行"""
        self.logger.info("📅 スケジュール管理システム開始")
        
        try:
            # 今週のスケジュール生成
            today = datetime.now()
            week_start = today - timedelta(days=today.weekday())
            
            weekly_schedule = self.generate_weekly_schedule(week_start.strftime("%Y-%m-%d"))
            
            # 週次スケジュールファイル保存
            week_file = os.path.join(
                self.schedules_dir, "weekly_plans", 
                f"{week_start.strftime('%Y-W%U')}.json"
            )
            with open(week_file, 'w', encoding='utf-8') as f:
                json.dump(weekly_schedule, f, ensure_ascii=False, indent=2)
                
            # 今日のセッション計画生成
            today_plan = self.create_daily_session_plan(today.strftime("%Y-%m-%d"))
            
            session_file = os.path.join(
                self.schedules_dir, "daily_sessions",
                f"{today.strftime('%Y-%m-%d')}.json"
            )
            with open(session_file, 'w', encoding='utf-8') as f:
                json.dump(today_plan, f, ensure_ascii=False, indent=2)
                
            # ICSエクスポート
            self.export_to_ics(today.strftime("%Y-%m-%d"))
            
            self.logger.info("✅ スケジュール管理完了")
            
            return {
                "weekly_schedule_file": week_file,
                "daily_plan_file": session_file,
                "ics_file": os.path.join(self.calendar_sync_dir, "project_schedule.ics")
            }
            
        except Exception as e:
            self.logger.error(f"❌ スケジュール管理エラー: {str(e)}")
            return None


# メイン実行
if __name__ == "__main__":
    # 実行ディレクトリ確認
    if not os.path.exists("plan"):
        print("❌ エラー: planフォルダが見つかりません")
        print("プロジェクトルートディレクトリから実行してください")
        sys.exit(1)
        
    schedule_manager = ScheduleManager()
    result = schedule_manager.run_schedule_management()
    
    if result:
        print("✅ スケジュール管理システム実行完了")
        print(f"📅 週次スケジュール: {result['weekly_schedule_file']}")
        print(f"📋 今日の計画: {result['daily_plan_file']}")
        print(f"📆 ICSファイル: {result['ics_file']}")
    else:
        print("❌ スケジュール管理でエラーが発生しました")
        sys.exit(1)