#!/usr/bin/env python3
"""
統合進捗ダッシュボード
Python移行プロジェクト用
アーキテクト設計 - 2025/01/18
"""

import json
import os
import yaml
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
import subprocess

class IntegratedProgressDashboard:
    """統合進捗ダッシュボード"""
    
    def __init__(self, base_path: str = "/mnt/e/MicrosoftProductManagementTools"):
        self.base_path = Path(base_path)
        self.reports_path = self.base_path / "Reports" / "progress"
        self.config_path = self.base_path / "Config"
        self.logs_path = self.base_path / "Logs"
        
        # 設定ファイル読み込み
        self.escalation_rules = self.load_escalation_rules()
        
        # レポートディレクトリ作成
        self.reports_path.mkdir(parents=True, exist_ok=True)
        self.logs_path.mkdir(parents=True, exist_ok=True)
    
    def load_escalation_rules(self) -> Dict[str, Any]:
        """エスカレーション基準設定を読み込み"""
        rules_file = self.config_path / "escalation_rules.yml"
        if rules_file.exists():
            with open(rules_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        return {}
    
    def collect_all_metrics(self) -> Dict[str, Any]:
        """全ペインからメトリクスを収集"""
        metrics = {
            "timestamp": datetime.now().isoformat(),
            "collection_type": "integrated_dashboard",
            "panes": {}
        }
        
        # 各ペインのメトリクスを収集
        for pane_name in ["architect", "backend", "frontend", "tester", "devops"]:
            pane_metrics = self.collect_pane_metrics(pane_name)
            metrics["panes"][pane_name] = pane_metrics
        
        # 全体統計を計算
        metrics["overall"] = self.calculate_overall_metrics(metrics["panes"])
        
        return metrics
    
    def collect_pane_metrics(self, pane_name: str) -> Dict[str, Any]:
        """個別ペインのメトリクスを収集"""
        pane_status_file = self.reports_path / f"{pane_name}_status.json"
        
        if pane_status_file.exists():
            with open(pane_status_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        
        # デフォルト値
        return {
            "status": "unknown",
            "progress": 0,
            "coverage": 0,
            "quality_score": "N/A",
            "last_update": "never"
        }
    
    def calculate_overall_metrics(self, pane_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """全体統計を計算"""
        total_progress = 0
        total_coverage = 0
        active_panes = 0
        
        for pane_name, metrics in pane_metrics.items():
            if metrics.get("status") != "unknown":
                total_progress += metrics.get("progress", 0)
                total_coverage += metrics.get("coverage", 0)
                active_panes += 1
        
        avg_progress = total_progress / active_panes if active_panes > 0 else 0
        avg_coverage = total_coverage / active_panes if active_panes > 0 else 0
        
        return {
            "overall_progress": round(avg_progress, 2),
            "overall_coverage": round(avg_coverage, 2),
            "active_panes": active_panes,
            "total_panes": 5,
            "health_status": self.calculate_health_status(avg_progress, avg_coverage)
        }
    
    def calculate_health_status(self, progress: float, coverage: float) -> str:
        """プロジェクト健全性ステータスを計算"""
        if progress >= 90 and coverage >= 95:
            return "🟢 Excellent"
        elif progress >= 80 and coverage >= 90:
            return "🟢 Good"
        elif progress >= 70 and coverage >= 85:
            return "🟡 Warning"
        elif progress >= 60 and coverage >= 80:
            return "🟡 Caution"
        else:
            return "🔴 Critical"
    
    def generate_realtime_view(self) -> str:
        """リアルタイム進捗ビューを生成"""
        metrics = self.collect_all_metrics()
        
        # ヘッダー
        header = f"""
╔══════════════════════════════════════════════════════════════════╗
║     Python移行プロジェクト進捗ダッシュボード - {datetime.now().strftime('%Y-%m-%d %H:%M')}     ║
╠══════════════════════════════════════════════════════════════════╣
║ ペイン │ 役割        │ 進捗率 │ カバレッジ │ 品質スコア │ ステータス ║
╠════════┼═════════════┼════════┼═══════════┼═══════════┼══════════╣"""
        
        # 各ペインの行を生成
        pane_rows = []
        pane_names = {
            "architect": "アーキテクト",
            "backend": "バックエンド",
            "frontend": "フロント",
            "tester": "テスター",
            "devops": "DevOps"
        }
        
        for i, (pane_id, pane_name) in enumerate(pane_names.items()):
            pane_metrics = metrics["panes"].get(pane_id, {})
            progress = pane_metrics.get("progress", 0)
            coverage = pane_metrics.get("coverage", 0)
            quality = pane_metrics.get("quality_score", "N/A")
            status = self.get_pane_status_emoji(pane_metrics.get("status", "unknown"))
            
            row = f"║ Pane {i} │ {pane_name:<11} │ {progress:>5}% │ {coverage:>8}% │ {quality:>9} │ {status:>8} ║"
            pane_rows.append(row)
        
        # フッター
        footer = f"""╚════════┴═════════════┴════════┴═══════════┴═══════════┴══════════╝

📊 全体統計:
- 総合進捗率: {metrics['overall']['overall_progress']}%
- 総合カバレッジ: {metrics['overall']['overall_coverage']}%
- 稼働ペイン: {metrics['overall']['active_panes']}/{metrics['overall']['total_panes']}
- 健全性: {metrics['overall']['health_status']}

{self.generate_alerts(metrics)}

📈 本日の進捗:
{self.generate_daily_progress()}"""
        
        return header + "\n" + "\n".join(pane_rows) + "\n" + footer
    
    def get_pane_status_emoji(self, status: str) -> str:
        """ペインステータスの絵文字を取得"""
        status_map = {
            "operational": "🟢",
            "warning": "🟡",
            "critical": "🔴",
            "unknown": "⚪",
            "offline": "⚫"
        }
        return status_map.get(status, "⚪")
    
    def generate_alerts(self, metrics: Dict[str, Any]) -> str:
        """アラートセクションを生成"""
        alerts = []
        
        # エスカレーション基準チェック
        overall_coverage = metrics['overall']['overall_coverage']
        
        if overall_coverage < 85:
            alerts.append(f"🚨 緊急: 総合カバレッジ {overall_coverage}% < 85%")
        elif overall_coverage < 90:
            alerts.append(f"⚠️ 警告: 総合カバレッジ {overall_coverage}% < 90%")
        
        # 各ペインの個別アラート
        for pane_name, pane_metrics in metrics["panes"].items():
            pane_coverage = pane_metrics.get("coverage", 0)
            pane_progress = pane_metrics.get("progress", 0)
            
            if pane_coverage < 85:
                alerts.append(f"🚨 {pane_name}: カバレッジ {pane_coverage}% < 85%")
            elif pane_progress < 70:
                alerts.append(f"⚠️ {pane_name}: 進捗 {pane_progress}% < 70%")
        
        if alerts:
            return "🚨 アラート:\n" + "\n".join([f"- {alert}" for alert in alerts])
        else:
            return "✅ アラート: なし"
    
    def generate_daily_progress(self) -> str:
        """日次進捗サマリーを生成"""
        try:
            # 各ペインの進捗データを取得
            progress_items = [
                "- API実装: 進行中",
                "- GUI実装: 進行中", 
                "- テスト作成: 進行中",
                "- CI/CDパイプライン: 設定中",
                "- ドキュメント: 更新中"
            ]
            return "\n".join(progress_items)
        except Exception as e:
            return f"- 進捗データ取得エラー: {str(e)}"
    
    def generate_html_dashboard(self) -> str:
        """HTML形式のダッシュボードを生成"""
        metrics = self.collect_all_metrics()
        
        html_template = """
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Python移行プロジェクト進捗ダッシュボード</title>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }}
        .header {{ text-align: center; margin-bottom: 30px; }}
        .metrics-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }}
        .metric-card {{ background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .metric-value {{ font-size: 2em; font-weight: bold; color: #2c3e50; }}
        .metric-label {{ color: #7f8c8d; margin-top: 5px; }}
        .status-excellent {{ color: #27ae60; }}
        .status-good {{ color: #f39c12; }}
        .status-warning {{ color: #e74c3c; }}
        .alerts {{ background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        .progress-bar {{ width: 100%; height: 20px; background-color: #ecf0f1; border-radius: 10px; overflow: hidden; }}
        .progress-fill {{ height: 100%; background-color: #3498db; transition: width 0.3s; }}
        .timestamp {{ text-align: center; color: #7f8c8d; margin-top: 20px; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🐍 Python移行プロジェクト進捗ダッシュボード</h1>
        <p>リアルタイム監視システム</p>
    </div>
    
    <div class="metrics-grid">
        <div class="metric-card">
            <div class="metric-value">{overall_progress}%</div>
            <div class="metric-label">総合進捗率</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: {overall_progress}%"></div>
            </div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value">{overall_coverage}%</div>
            <div class="metric-label">総合カバレッジ</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: {overall_coverage}%"></div>
            </div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value">{active_panes}/{total_panes}</div>
            <div class="metric-label">稼働ペイン数</div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value status-{health_class}">{health_status}</div>
            <div class="metric-label">システム健全性</div>
        </div>
    </div>
    
    <div class="alerts">
        {alerts_html}
    </div>
    
    <div class="timestamp">
        最終更新: {timestamp}
    </div>
</body>
</html>
"""
        
        # テンプレート変数を置換
        health_class = "excellent" if "🟢" in metrics["overall"]["health_status"] else "warning"
        alerts_html = self.generate_alerts(metrics).replace("\n", "<br>")
        
        return html_template.format(
            overall_progress=metrics["overall"]["overall_progress"],
            overall_coverage=metrics["overall"]["overall_coverage"],
            active_panes=metrics["overall"]["active_panes"],
            total_panes=metrics["overall"]["total_panes"],
            health_status=metrics["overall"]["health_status"],
            health_class=health_class,
            alerts_html=alerts_html,
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )
    
    def save_dashboard_report(self, format_type: str = "all") -> List[str]:
        """ダッシュボードレポートを保存"""
        saved_files = []
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        if format_type in ["all", "text"]:
            # テキスト形式
            text_content = self.generate_realtime_view()
            text_file = self.reports_path / f"dashboard_{timestamp}.txt"
            with open(text_file, 'w', encoding='utf-8') as f:
                f.write(text_content)
            saved_files.append(str(text_file))
        
        if format_type in ["all", "html"]:
            # HTML形式
            html_content = self.generate_html_dashboard()
            html_file = self.reports_path / f"dashboard_{timestamp}.html"
            with open(html_file, 'w', encoding='utf-8') as f:
                f.write(html_content)
            saved_files.append(str(html_file))
        
        if format_type in ["all", "json"]:
            # JSON形式
            json_content = self.collect_all_metrics()
            json_file = self.reports_path / f"dashboard_{timestamp}.json"
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(json_content, f, indent=2, ensure_ascii=False)
            saved_files.append(str(json_file))
        
        return saved_files
    
    def check_escalation_needed(self) -> List[Dict[str, Any]]:
        """エスカレーションが必要かチェック"""
        metrics = self.collect_all_metrics()
        escalations = []
        
        overall_coverage = metrics["overall"]["overall_coverage"]
        
        # 緊急エスカレーション
        if overall_coverage < 85:
            escalations.append({
                "level": "critical",
                "reason": f"総合カバレッジ {overall_coverage}% < 85%",
                "action": "immediate_escalation",
                "notification_channels": self.escalation_rules.get("notification_channels", {}).get("critical", [])
            })
        
        # 警告エスカレーション
        elif overall_coverage < 90:
            escalations.append({
                "level": "warning",
                "reason": f"総合カバレッジ {overall_coverage}% < 90%",
                "action": "escalation_in_30_min",
                "notification_channels": self.escalation_rules.get("notification_channels", {}).get("warning", [])
            })
        
        return escalations
    
    def send_tmux_message(self, target_pane: str, message: str) -> bool:
        """tmuxメッセージを送信"""
        try:
            # tmuxセッションとペインが存在するかチェック
            check_cmd = ["tmux", "list-panes", "-t", "MicrosoftProductTools-Python"]
            result = subprocess.run(check_cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                return False
            
            # メッセージを送信
            message_cmd = ["tmux", "send-keys", "-t", f"MicrosoftProductTools-Python:{target_pane}", message, "Enter"]
            result = subprocess.run(message_cmd, capture_output=True, text=True)
            
            return result.returncode == 0
        except Exception as e:
            print(f"tmuxメッセージ送信エラー: {e}")
            return False
    
    def update_shared_context(self, message: str) -> bool:
        """共有コンテキストファイルを更新"""
        try:
            context_file = self.base_path / "tmux_shared_context.md"
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            append_content = f"\n\n### 🚨 ダッシュボードアラート ({timestamp})\n{message}\n"
            
            with open(context_file, 'a', encoding='utf-8') as f:
                f.write(append_content)
            
            return True
        except Exception as e:
            print(f"共有コンテキスト更新エラー: {e}")
            return False

def main():
    """メイン実行関数"""
    dashboard = IntegratedProgressDashboard()
    
    # ダッシュボードを生成・保存
    saved_files = dashboard.save_dashboard_report("all")
    print(f"ダッシュボードレポートを保存しました: {saved_files}")
    
    # エスカレーションチェック
    escalations = dashboard.check_escalation_needed()
    if escalations:
        for escalation in escalations:
            print(f"エスカレーション検出: {escalation['reason']}")
            dashboard.update_shared_context(f"エスカレーション: {escalation['reason']}")
    
    # リアルタイムビューを表示
    print(dashboard.generate_realtime_view())

if __name__ == "__main__":
    main()