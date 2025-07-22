#!/usr/bin/env python3
"""
進捗追跡エンジン
Microsoft 365管理ツール開発プロジェクト用
"""

import json
import os
import sys
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
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
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
                "description": "テスト環境修復・依存関係解決・CI/CD復旧",
                "due_date": "2025-08-04",
                "status": "in_progress",
                "progress": 85,
                "priority": "critical",
                "success_criteria": [
                    "pytest成功率: 90%以上",
                    "CI/CDパイプライン: 完全復旧",
                    "仮想環境: 標準化完了",
                    "依存関係: 問題解消",
                    "GitHub Actions: 正常動作"
                ],
                "tasks": ["conftest_fix", "ci_cd_repair", "dependency_resolution", "venv_standardization"],
                "responsible": "Dev Team Lead",
                "health_status": "at_risk",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "M2_gui_foundation": {
                "name": "Python GUI基盤完成",
                "description": "PyQt6メインウィンドウ・26機能ボタン・基本機能実装",
                "due_date": "2025-08-18",
                "status": "pending",
                "progress": 20,
                "priority": "high",
                "success_criteria": [
                    "PyQt6メインウィンドウ: 完全動作",
                    "26機能ボタン: レイアウト完成",
                    "リアルタイムログ: 実装完了",
                    "基本エラーハンドリング: 実装完了",
                    "PowerShell版呼び出し: 動作確認"
                ],
                "tasks": ["pyqt6_main_window", "button_grid", "log_viewer", "error_handling", "powershell_bridge"],
                "responsible": "Frontend Team",
                "health_status": "on_track",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "M3_api_integration": {
                "name": "API統合・CLI完成",
                "description": "Microsoft Graph・Exchange Online統合・CLI機能実装",
                "due_date": "2025-09-01",
                "status": "pending", 
                "progress": 5,
                "priority": "high",
                "success_criteria": [
                    "Microsoft Graph: 完全統合",
                    "Exchange Online: ブリッジ完成",
                    "CLI機能: PowerShell版同等",
                    "認証システム: 証明書ベース完成",
                    "レポート生成: 全機能動作"
                ],
                "tasks": ["graph_integration", "exchange_bridge", "cli_implementation", "auth_system", "report_generation"],
                "responsible": "Backend Team",
                "health_status": "on_track",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
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
                    "セキュリティ監査: 完全パス",
                    "パフォーマンステスト: 要件達成"
                ],
                "tasks": ["unit_tests", "integration_tests", "e2e_tests", "security_audit", "performance_tests"],
                "responsible": "QA Team",
                "health_status": "not_started",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "M5_release": {
                "name": "リリース完了",
                "description": "本番環境デプロイ・ユーザー受け入れ・監視開始",
                "due_date": "2025-10-14",
                "status": "pending",
                "progress": 0,
                "priority": "critical",
                "success_criteria": [
                    "プロダクション環境: 構築完了",
                    "ユーザー受け入れテスト: 承認取得",
                    "ドキュメント: 最新化完了",
                    "監視システム: 稼働開始",
                    "サポート体制: 準備完了"
                ],
                "tasks": ["production_deploy", "uat", "documentation", "monitoring", "support_setup"],
                "responsible": "DevOps Team",
                "health_status": "not_started",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            }
        }
        
        milestones_file = os.path.join(self.progress_dir, "milestones.json")
        with open(milestones_file, 'w', encoding='utf-8') as f:
            json.dump(milestones, f, ensure_ascii=False, indent=2)
            
        self.logger.info("📊 マイルストーン初期化完了")
        
    def initialize_tasks(self):
        """タスク初期化"""
        tasks = {
            "conftest_fix": {
                "title": "conftest.py競合解消",
                "description": "pytest実行不可能状態の解消・テスト環境完全修復",
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
                "notes": "conftest.py重複定義の統合作業中。src/とtests/の統合実施中。",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "ci_cd_repair": {
                "title": "CI/CDパイプライン修復",
                "description": "GitHub Actions ワークフロー正常化・自動テスト復旧",
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
                "notes": "conftest.py修復後に実施予定。ワークフロー簡素化を検討。",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "dependency_resolution": {
                "title": "依存関係問題解決",
                "description": "requirements.txt vs pyproject.toml統一・仮想環境標準化",
                "milestone": "M1_emergency_fix",
                "priority": "critical",
                "status": "pending",
                "progress": 40,
                "estimated_hours": 6,
                "actual_hours": 2,
                "assignee": "Backend Developer",
                "scheduled_start": "2025-07-21T14:00:00",
                "scheduled_end": "2025-07-22T20:00:00",
                "dependencies": [],
                "blockers": [],
                "notes": "pyproject.toml統一方針で進行中。バージョン競合調査完了。",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "pyqt6_main_window": {
                "title": "PyQt6メインウィンドウ実装",
                "description": "26機能ボタン配置・基本レイアウト・リアルタイムログ実装",
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
                "notes": "基本構造設計完了。PyQt6基本実装開始予定。",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "button_grid": {
                "title": "26機能ボタングリッド実装",
                "description": "セクション別ボタン配置・クリックイベント・プログレス表示",
                "milestone": "M2_gui_foundation",
                "priority": "high",
                "status": "pending",
                "progress": 10,
                "estimated_hours": 15,
                "actual_hours": 1,
                "assignee": "Frontend Developer",
                "scheduled_start": "2025-08-06T09:00:00",
                "scheduled_end": "2025-08-10T17:00:00",
                "dependencies": ["pyqt6_main_window"],
                "blockers": [],
                "notes": "26機能のグループ分けとレイアウト設計完了。",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "graph_integration": {
                "title": "Microsoft Graph完全統合",
                "description": "MSAL Python・Graph SDK統合・ユーザー/ライセンス取得",
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
                "notes": "認証システム設計検討中。証明書ベース認証方針で進行。",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            },
            "exchange_bridge": {
                "title": "Exchange Online PowerShellブリッジ",
                "description": "PowerShell-Python統合・メールボックス/フロー分析",
                "milestone": "M3_api_integration",
                "priority": "high",
                "status": "pending",
                "progress": 5,
                "estimated_hours": 25,
                "actual_hours": 1,
                "assignee": "Backend Developer",
                "scheduled_start": "2025-08-20T09:00:00",
                "scheduled_end": "2025-08-29T17:00:00",
                "dependencies": ["graph_integration"],
                "blockers": [],
                "notes": "PowerShellコマンド実行アーキテクチャ設計中。",
                "created_date": "2025-07-21",
                "last_updated": datetime.now().isoformat()
            }
        }
        
        tasks_file = os.path.join(self.progress_dir, "tasks.json")
        with open(tasks_file, 'w', encoding='utf-8') as f:
            json.dump(tasks, f, ensure_ascii=False, indent=2)
            
        self.logger.info("📋 タスク初期化完了")
        
    def initialize_metrics(self):
        """メトリクス初期化"""
        metrics = {
            "development_metrics": {
                "code_coverage": 35,
                "build_success_rate": 0,
                "test_success_rate": 0,
                "deployment_success_rate": 0,
                "bug_density": 0.2,
                "technical_debt_hours": 40
            },
            "project_metrics": {
                "overall_progress": 75,
                "milestone_completion_rate": 0,
                "task_completion_rate": 5,
                "schedule_adherence": 60,
                "resource_utilization": 70,
                "risk_score": 75
            },
            "quality_metrics": {
                "security_score": 85,
                "performance_score": 70,
                "maintainability_score": 65,
                "reliability_score": 60,
                "usability_score": 80
            },
            "team_metrics": {
                "velocity": 15,
                "burn_rate": 60,
                "satisfaction_score": 75,
                "collaboration_score": 80
            },
            "last_updated": datetime.now().isoformat()
        }
        
        metrics_file = os.path.join(self.progress_dir, "metrics.json")
        with open(metrics_file, 'w', encoding='utf-8') as f:
            json.dump(metrics, f, ensure_ascii=False, indent=2)
            
        self.logger.info("📈 メトリクス初期化完了")
        
    def update_task_progress(self, task_id: str, progress: int, notes: str = "", actual_hours: float = 0):
        """タスク進捗更新"""
        tasks_file = os.path.join(self.progress_dir, "tasks.json")
        
        if not os.path.exists(tasks_file):
            self.logger.error("❌ タスクファイルが存在しません")
            return False
            
        with open(tasks_file, 'r', encoding='utf-8') as f:
            tasks = json.load(f)
            
        if task_id not in tasks:
            self.logger.error(f"❌ タスクID {task_id} が見つかりません")
            return False
            
        # 進捗更新
        old_progress = tasks[task_id]['progress']
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
        
        self.logger.info(f"✅ タスク進捗更新: {task_id} ({old_progress}% → {progress}%)")
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
                
            # 重み付き平均進捗計算（工数ベース）
            total_weighted_progress = 0
            total_weight = 0
            
            for task in milestone_tasks:
                weight = task.get('estimated_hours', 1)
                total_weighted_progress += task['progress'] * weight
                total_weight += weight
                
            if total_weight > 0:
                avg_progress = int(total_weighted_progress / total_weight)
            else:
                avg_progress = 0
            
            # マイルストーン進捗更新
            old_progress = milestones[milestone_id]['progress']
            milestones[milestone_id]['progress'] = avg_progress
            milestones[milestone_id]['last_updated'] = datetime.now().isoformat()
            
            # ステータス自動更新
            if avg_progress == 100:
                milestones[milestone_id]['status'] = 'completed'
            elif avg_progress > 0:
                milestones[milestone_id]['status'] = 'in_progress'
                
            # ヘルス状況自動更新
            due_date = datetime.fromisoformat(milestone['due_date'])
            days_until_due = (due_date - datetime.now()).days
            
            if avg_progress >= 80:
                milestones[milestone_id]['health_status'] = 'on_track'
            elif days_until_due <= 3 and avg_progress < 70:
                milestones[milestone_id]['health_status'] = 'at_risk'
            elif days_until_due <= 7 and avg_progress < 50:
                milestones[milestone_id]['health_status'] = 'at_risk'
            else:
                milestones[milestone_id]['health_status'] = 'on_track'
                
            if old_progress != avg_progress:
                self.logger.info(f"📊 マイルストーン進捗更新: {milestone_id} ({old_progress}% → {avg_progress}%)")
                
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
        
        if not milestones or not tasks:
            self.logger.warning("⚠️ 進捗データが不完全です")
            return None
        
        # 今日の作業サマリー
        today_tasks = [task for task in tasks.values() 
                       if task.get('last_updated', '').startswith(today)]
        
        completed_today = [task for task in today_tasks if task['status'] == 'completed']
        updated_today = [task for task in today_tasks if task['status'] == 'in_progress']
        
        # 重要な指標計算
        overall_progress = self.calculate_overall_progress(milestones)
        critical_blockers = [task for task in tasks.values() if task.get('blockers') and task['priority'] == 'critical']
        at_risk_milestones = [m for m in milestones.values() if m.get('health_status') == 'at_risk']
        
        # レポート生成
        daily_report = {
            "date": today,
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "overall_progress": overall_progress,
                "total_milestones": len(milestones),
                "completed_milestones": len([m for m in milestones.values() if m['status'] == 'completed']),
                "at_risk_milestones": len(at_risk_milestones),
                "total_tasks": len(tasks),
                "completed_tasks": len([t for t in tasks.values() if t['status'] == 'completed']),
                "in_progress_tasks": len([t for t in tasks.values() if t['status'] == 'in_progress']),
                "tasks_completed_today": len(completed_today),
                "tasks_updated_today": len(updated_today),
                "critical_blockers": len(critical_blockers)
            },
            "milestone_status": {
                milestone_id: {
                    "name": milestone['name'],
                    "progress": milestone['progress'],
                    "status": milestone['status'],
                    "health": milestone.get('health_status', 'unknown'),
                    "due_date": milestone['due_date'],
                    "days_until_due": (datetime.fromisoformat(milestone['due_date']) - datetime.now()).days
                }
                for milestone_id, milestone in milestones.items()
            },
            "today_activities": {
                "completed_tasks": [
                    {
                        "title": task['title'],
                        "milestone": task.get('milestone'),
                        "progress": task['progress'],
                        "assignee": task.get('assignee')
                    }
                    for task in completed_today
                ],
                "updated_tasks": [
                    {
                        "title": task['title'],
                        "milestone": task.get('milestone'),
                        "progress": task['progress'],
                        "notes": task.get('notes', ''),
                        "assignee": task.get('assignee')
                    }
                    for task in updated_today
                ]
            },
            "alerts": {
                "at_risk_milestones": [
                    {
                        "name": milestone['name'],
                        "progress": milestone['progress'],
                        "due_date": milestone['due_date'],
                        "days_until_due": (datetime.fromisoformat(milestone['due_date']) - datetime.now()).days
                    }
                    for milestone in at_risk_milestones
                ],
                "critical_blockers": [
                    {
                        "task": task['title'],
                        "blockers": task['blockers'],
                        "assignee": task.get('assignee'),
                        "milestone": task.get('milestone')
                    }
                    for task in critical_blockers
                ]
            },
            "next_day_focus": self.get_next_day_focus(tasks),
            "metrics": metrics.get('development_metrics', {}),
            "recommendations": self.get_recommendations(milestones, tasks)
        }
        
        # レポート保存
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(daily_report, f, ensure_ascii=False, indent=2)
            
        self.logger.info(f"📊 日次レポート生成: {report_file}")
        return daily_report
        
    def calculate_overall_progress(self, milestones: Dict) -> int:
        """全体進捗計算（重み付き）"""
        if not milestones:
            return 0
            
        # 重要度による重み付け
        weight_map = {
            'critical': 3,
            'high': 2,
            'medium': 1,
            'low': 0.5
        }
        
        total_weighted_progress = 0
        total_weight = 0
        
        for milestone in milestones.values():
            weight = weight_map.get(milestone.get('priority', 'medium'), 1)
            total_weighted_progress += milestone['progress'] * weight
            total_weight += weight
            
        return int(total_weighted_progress / total_weight) if total_weight > 0 else 0
        
    def get_next_day_focus(self, tasks: Dict) -> List[str]:
        """翌日重点項目取得"""
        focus_items = []
        
        # 1. 進行中の緊急・重要タスク
        critical_tasks = [
            task['title'] for task in tasks.values()
            if task['priority'] == 'critical' and task['status'] == 'in_progress'
        ]
        focus_items.extend(critical_tasks[:2])
        
        # 2. ブロッカー解消が必要なタスク
        blocked_tasks = [
            f"ブロッカー解消: {task['title']}" for task in tasks.values()
            if task.get('blockers') and task['status'] != 'completed'
        ]
        focus_items.extend(blocked_tasks[:1])
        
        # 3. 遅延リスクのあるタスク
        if len(focus_items) < 3:
            high_priority_tasks = [
                task['title'] for task in tasks.values()
                if task['priority'] == 'high' and task['status'] == 'in_progress' and task['progress'] < 50
            ]
            focus_items.extend(high_priority_tasks[:3-len(focus_items)])
        
        return focus_items[:3]  # 最大3件
        
    def get_recommendations(self, milestones: Dict, tasks: Dict) -> List[str]:
        """改善提案生成"""
        recommendations = []
        
        # 遅延リスクマイルストーン
        at_risk_milestones = [m for m in milestones.values() if m.get('health_status') == 'at_risk']
        if at_risk_milestones:
            recommendations.append(f"🚨 {len(at_risk_milestones)}件のマイルストーンが遅延リスクです。リソース追加またはスコープ調整を検討してください。")
        
        # ブロッカータスク
        blocked_tasks = [t for t in tasks.values() if t.get('blockers')]
        if blocked_tasks:
            recommendations.append(f"🚧 {len(blocked_tasks)}件のタスクがブロックされています。ブロッカー解消を最優先してください。")
        
        # 低進捗率タスク
        low_progress_tasks = [t for t in tasks.values() if t['status'] == 'in_progress' and t['progress'] < 20]
        if len(low_progress_tasks) > 3:
            recommendations.append(f"⚠️ 進捗の遅いタスクが{len(low_progress_tasks)}件あります。タスク分割や支援が必要か確認してください。")
        
        # 全体進捗が低い場合
        overall_progress = self.calculate_overall_progress(milestones)
        if overall_progress < 60:
            recommendations.append("📈 全体進捗が60%未満です。クリティカルパスの見直しとリソース配分の最適化を検討してください。")
        
        return recommendations
        
    def load_json(self, filename: str) -> Optional[Dict]:
        """JSONファイル読み込み"""
        file_path = os.path.join(self.progress_dir, filename)
        if not os.path.exists(file_path):
            return None
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            self.logger.error(f"❌ JSONファイル読み込みエラー {filename}: {str(e)}")
            return None


# メイン実行
if __name__ == "__main__":
    # 実行ディレクトリを確認
    if not os.path.exists("plam"):
        print("❌ エラー: planフォルダが見つかりません")
        print("プロジェクトルートディレクトリから実行してください")
        sys.exit(1)
        
    tracker = ProgressTracker()
    
    # 初期化（初回のみ）
    if not os.path.exists("plam/progress/milestones.json"):
        print("🔧 初期セットアップを実行中...")
        tracker.initialize_milestones()
        tracker.initialize_tasks()
        tracker.initialize_metrics()
        print("✅ 初期セットアップ完了")
        
    # 日次レポート生成
    print("📊 日次レポート生成中...")
    daily_report = tracker.generate_daily_report()
    
    if daily_report:
        summary = daily_report['summary']
        print(f"""
📈 進捗サマリー ({daily_report['date']})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 全体進捗: {summary['overall_progress']}%
📋 マイルストーン: {summary['completed_milestones']}/{summary['total_milestones']} 完了
📝 タスク: {summary['completed_tasks']}/{summary['total_tasks']} 完了
🎯 本日完了: {summary['tasks_completed_today']} タスク
⚠️ リスク: {summary['at_risk_milestones']} マイルストーン
🚧 ブロッカー: {summary['critical_blockers']} 重要タスク
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """.strip())
        
        # アラート表示
        if daily_report['alerts']['at_risk_milestones']:
            print("\n🚨 注意が必要なマイルストーン:")
            for milestone in daily_report['alerts']['at_risk_milestones']:
                print(f"  - {milestone['name']} (進捗: {milestone['progress']}%, 残り{milestone['days_until_due']}日)")
        
        # 翌日重点項目
        if daily_report['next_day_focus']:
            print("\n🎯 明日の重点項目:")
            for item in daily_report['next_day_focus']:
                print(f"  - {item}")
        
        # 推奨アクション
        if daily_report['recommendations']:
            print("\n💡 推奨アクション:")
            for rec in daily_report['recommendations']:
                print(f"  {rec}")
                
        print("\n✅ 日次レポート生成完了")
    else:
        print("❌ 日次レポート生成でエラーが発生しました")
        sys.exit(1)