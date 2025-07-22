#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
レポート生成エンジン - CSV/HTML出力とファイル管理
PowerShell版ReportGenerator.psm1の完全PyQt6実装

企業レベルのレポート生成機能:
- CSV/HTML両形式対応・UTF8BOM エンコーディング
- レスポンシブHTMLテンプレート・日本語フォント対応
- 機能別ディレクトリ自動作成・タイムスタンプ付きファイル名
- 自動ファイル表示・ポップアップ通知機能
- Microsoft 365データの視覚化・グラフ生成

Frontend Developer (dev0) - PyQt6 GUI専門実装
Version: 2.0.0
Date: 2025-01-22
"""

import os
import csv
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Any, Union, Tuple
import webbrowser
import subprocess
import sys

try:
    import pandas as pd
    import jinja2
    from jinja2 import Environment, FileSystemLoader, Template
    import matplotlib
    matplotlib.use('Qt5Agg')  # PyQt6バックエンド設定
    import matplotlib.pyplot as plt
    import seaborn as sns
    plt.style.use('seaborn-v0_8')
    import base64
    from io import BytesIO
except ImportError:
    # フォールバック実装
    pd = None
    jinja2 = None
    Environment = None
    FileSystemLoader = None
    Template = None
    matplotlib = None
    plt = None
    sns = None
    base64 = None
    BytesIO = None

from PyQt6.QtCore import QObject, pyqtSignal, QTimer, QThread, QUrl
from PyQt6.QtWidgets import QMessageBox, QApplication, QFileDialog
from PyQt6.QtGui import QDesktopServices

class ReportGenerator(QObject):
    """
    企業レベルレポート生成エンジン
    PowerShell版の完全互換実装
    """
    
    # シグナル定義
    report_generated = pyqtSignal(str, str, str)  # report_type, file_path, format
    export_completed = pyqtSignal(str, list)      # report_type, file_paths
    error_occurred = pyqtSignal(str, str)         # operation, error_message
    progress_updated = pyqtSignal(int)            # progress_percentage
    
    def __init__(self, base_reports_dir: str = "Reports"):
        super().__init__()
        self.base_reports_dir = Path(base_reports_dir)
        self.logger = logging.getLogger(__name__)
        
        # レポートディレクトリ構造（PowerShell版互換）
        self.report_categories = {
            # 定期レポート
            "DailyReport": "Daily",
            "WeeklyReport": "Weekly", 
            "MonthlyReport": "Monthly",
            "YearlyReport": "Yearly",
            "TestExecution": "Tests",
            
            # 分析レポート
            "LicenseAnalysis": "Analysis/License",
            "UsageAnalysis": "Analysis/Usage",
            "PerformanceAnalysis": "Analysis/Performance",
            "SecurityAnalysis": "Analysis/Security",
            "PermissionAudit": "Analysis/Permissions",
            
            # Entra ID管理
            "UserList": "EntraID/Users",
            "MFAStatus": "EntraID/MFA", 
            "ConditionalAccess": "EntraID/ConditionalAccess",
            "SignInLogs": "EntraID/SignInLogs",
            
            # Exchange Online管理
            "MailboxManagement": "Exchange/Mailboxes",
            "MailFlowAnalysis": "Exchange/MailFlow",
            "SpamProtectionAnalysis": "Exchange/SpamProtection",
            "MailDeliveryAnalysis": "Exchange/Delivery",
            
            # Teams管理
            "TeamsUsage": "Teams/Usage",
            "TeamsSettingsAnalysis": "Teams/Settings",
            "MeetingQualityAnalysis": "Teams/MeetingQuality",
            "TeamsAppAnalysis": "Teams/Apps",
            
            # OneDrive管理
            "StorageAnalysis": "OneDrive/Storage",
            "SharingAnalysis": "OneDrive/Sharing",
            "SyncErrorAnalysis": "OneDrive/SyncErrors",
            "ExternalSharingAnalysis": "OneDrive/ExternalSharing"
        }
        
        # HTMLテンプレート初期化
        self.template_env = self._initialize_templates()
        
        # レポートディレクトリ作成
        self._ensure_directories()
        
        self.logger.info("レポート生成エンジン初期化完了")
    
    def _initialize_templates(self):
        """HTMLテンプレート初期化"""
        if not jinja2:
            self.logger.warning("Jinja2が利用できません - 基本HTMLテンプレートを使用")
            return None
            
        try:
            # テンプレートディレクトリ作成
            template_dir = Path(__file__).parent.parent / "templates" 
            template_dir.mkdir(exist_ok=True, parents=True)
            
            # 基本テンプレートファイルを作成（存在しない場合）
            self._create_base_template(template_dir)
            
            # Jinja2環境設定
            env = Environment(
                loader=FileSystemLoader(str(template_dir)),
                autoescape=True,
                trim_blocks=True,
                lstrip_blocks=True
            )
            
            return env
            
        except Exception as e:
            self.logger.error(f"テンプレート初期化エラー: {str(e)}")
            return None
    
    def _create_base_template(self, template_dir: Path):
        """基本HTMLテンプレート作成"""
        template_content = """<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ report_title }}</title>
    <style>
        /* Microsoft 365風デザイン */
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: 'Segoe UI', 'Yu Gothic', 'Hiragino Sans', sans-serif;
            line-height: 1.6;
            color: #323130;
            background-color: #faf9f8;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #0078d4, #106ebe);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            font-weight: 300;
            margin-bottom: 10px;
        }
        
        .header .subtitle {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .metadata {
            background: #f3f2f1;
            padding: 20px 30px;
            border-bottom: 1px solid #edebe9;
        }
        
        .metadata-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .metadata-item {
            display: flex;
            align-items: center;
        }
        
        .metadata-label {
            font-weight: 600;
            color: #605e5c;
            margin-right: 10px;
        }
        
        .content {
            padding: 30px;
        }
        
        .section {
            margin-bottom: 40px;
        }
        
        .section-title {
            color: #0078d4;
            font-size: 1.5em;
            font-weight: 600;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #0078d4;
        }
        
        /* テーブルスタイル */
        .data-table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            font-size: 0.95em;
        }
        
        .data-table th {
            background: #0078d4;
            color: white;
            padding: 12px 15px;
            text-align: left;
            font-weight: 600;
        }
        
        .data-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #edebe9;
        }
        
        .data-table tr:hover {
            background-color: #f8f9fa;
        }
        
        .data-table tr:nth-child(even) {
            background-color: #faf9f8;
        }
        
        /* 統計カード */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        
        .stat-card {
            background: white;
            border: 1px solid #edebe9;
            border-radius: 6px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        
        .stat-card .number {
            font-size: 2.5em;
            font-weight: 300;
            color: #0078d4;
            margin-bottom: 5px;
        }
        
        .stat-card .label {
            color: #605e5c;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        /* グラフコンテナ */
        .chart-container {
            text-align: center;
            margin: 30px 0;
            padding: 20px;
            background: #faf9f8;
            border-radius: 6px;
        }
        
        .chart-container img {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        /* レスポンシブ対応 */
        @media (max-width: 768px) {
            body { padding: 10px; }
            .header { padding: 20px; }
            .header h1 { font-size: 2em; }
            .content { padding: 20px; }
            .metadata-grid { grid-template-columns: 1fr; }
            .stats-grid { grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); }
        }
        
        /* 印刷対応 */
        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; }
            .header { background: #0078d4 !important; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{{ report_title }}</h1>
            <div class="subtitle">{{ report_subtitle }}</div>
        </div>
        
        <div class="metadata">
            <div class="metadata-grid">
                <div class="metadata-item">
                    <span class="metadata-label">📅 生成日時:</span>
                    <span>{{ generation_time }}</span>
                </div>
                <div class="metadata-item">
                    <span class="metadata-label">📊 レポート種別:</span>
                    <span>{{ report_type }}</span>
                </div>
                <div class="metadata-item">
                    <span class="metadata-label">📈 データ件数:</span>
                    <span>{{ data_count }} 件</span>
                </div>
                <div class="metadata-item">
                    <span class="metadata-label">🏢 テナント:</span>
                    <span>{{ tenant_name }}</span>
                </div>
            </div>
        </div>
        
        <div class="content">
            {{ content | safe }}
        </div>
    </div>
</body>
</html>"""
        
        template_file = template_dir / "base_report.html"
        if not template_file.exists():
            with open(template_file, 'w', encoding='utf-8') as f:
                f.write(template_content)
    
    def _ensure_directories(self):
        """レポートディレクトリ作成"""
        # ベースディレクトリ作成
        self.base_reports_dir.mkdir(exist_ok=True, parents=True)
        
        # 各カテゴリディレクトリ作成
        for action, subdir in self.report_categories.items():
            dir_path = self.base_reports_dir / subdir
            dir_path.mkdir(exist_ok=True, parents=True)
    
    def generate_report(self, report_type: str, data: Dict[str, Any], 
                       formats: List[str] = None) -> List[str]:
        """
        レポート生成（メイン関数）
        
        Args:
            report_type: レポート種別（DailyReport, UserList等）
            data: レポートデータ
            formats: 出力形式リスト（["csv", "html"]）
            
        Returns:
            生成されたファイルパスのリスト
        """
        if formats is None:
            formats = ["csv", "html"]  # デフォルトは両形式
        
        try:
            self.progress_updated.emit(10)
            
            # ファイルパス生成
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            subdir = self.report_categories.get(report_type, "Other")
            report_dir = self.base_reports_dir / subdir
            report_dir.mkdir(exist_ok=True, parents=True)
            
            generated_files = []
            
            self.progress_updated.emit(30)
            
            # CSV生成
            if "csv" in formats:
                csv_path = report_dir / f"{report_type}_{timestamp}.csv"
                self._generate_csv(csv_path, data)
                generated_files.append(str(csv_path))
                self.report_generated.emit(report_type, str(csv_path), "csv")
            
            self.progress_updated.emit(60)
            
            # HTML生成
            if "html" in formats:
                html_path = report_dir / f"{report_type}_{timestamp}.html"
                self._generate_html(html_path, report_type, data)
                generated_files.append(str(html_path))
                self.report_generated.emit(report_type, str(html_path), "html")
            
            self.progress_updated.emit(90)
            
            # 完了通知
            self.export_completed.emit(report_type, generated_files)
            self.progress_updated.emit(100)
            
            self.logger.info(f"レポート生成完了: {report_type} - {len(generated_files)}ファイル")
            
            # 自動ファイル表示（最初のファイル）
            if generated_files:
                self._open_report_file(generated_files[0])
            
            return generated_files
            
        except Exception as e:
            error_msg = f"レポート生成エラー: {str(e)}"
            self.logger.error(error_msg)
            self.error_occurred.emit("レポート生成", error_msg)
            return []
    
    def _generate_csv(self, file_path: Path, data: Dict[str, Any]):
        """CSV形式レポート生成"""
        try:
            # データをDataFrameに変換（pandas利用可能な場合）
            if pd and isinstance(data.get('data'), list) and data['data']:
                df = pd.DataFrame(data['data'])
                df.to_csv(file_path, index=False, encoding='utf-8-sig')  # UTF8BOM
            else:
                # 手動CSV生成
                self._generate_csv_manual(file_path, data)
                
        except Exception as e:
            self.logger.error(f"CSV生成エラー: {str(e)}")
            raise
    
    def _generate_csv_manual(self, file_path: Path, data: Dict[str, Any]):
        """手動CSV生成（pandasなしの場合）"""
        with open(file_path, 'w', newline='', encoding='utf-8-sig') as csvfile:
            if isinstance(data.get('data'), list) and data['data']:
                # リスト形式のデータ
                fieldnames = data['data'][0].keys() if data['data'] else []
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(data['data'])
            else:
                # その他の形式のデータ
                writer = csv.writer(csvfile)
                writer.writerow(['項目', '値'])
                for key, value in data.items():
                    if not isinstance(value, (list, dict)):
                        writer.writerow([key, str(value)])
    
    def _generate_html(self, file_path: Path, report_type: str, data: Dict[str, Any]):
        """HTML形式レポート生成"""
        try:
            # レポート固有のコンテンツ生成
            content = self._generate_report_content(report_type, data)
            
            # テンプレート変数
            template_vars = {
                'report_title': self._get_report_title(report_type),
                'report_subtitle': self._get_report_subtitle(report_type),
                'report_type': report_type,
                'generation_time': datetime.now().strftime("%Y年%m月%d日 %H:%M:%S"),
                'data_count': self._get_data_count(data),
                'tenant_name': data.get('tenant_name', 'Contoso Corporation'),
                'content': content
            }
            
            # テンプレート適用
            if self.template_env:
                template = self.template_env.get_template('base_report.html')
                html_content = template.render(**template_vars)
            else:
                # フォールバック HTML生成
                html_content = self._generate_fallback_html(template_vars)
            
            # ファイル書き込み
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(html_content)
                
        except Exception as e:
            self.logger.error(f"HTML生成エラー: {str(e)}")
            raise
    
    def _generate_report_content(self, report_type: str, data: Dict[str, Any]) -> str:
        """レポート種別に応じたコンテンツ生成"""
        content_generators = {
            'UserList': self._generate_user_list_content,
            'MFAStatus': self._generate_mfa_status_content,
            'LicenseAnalysis': self._generate_license_analysis_content,
            'TeamsUsage': self._generate_teams_usage_content,
            'SignInLogs': self._generate_signin_logs_content,
        }
        
        generator = content_generators.get(report_type, self._generate_generic_content)
        return generator(data)
    
    def _generate_user_list_content(self, data: Dict[str, Any]) -> str:
        """ユーザー一覧レポートコンテンツ"""
        users = data.get('users', data.get('data', []))
        
        # 統計情報
        total_users = len(users)
        active_users = len([u for u in users if u.get('accountEnabled', True)])
        
        # 統計カード
        stats_html = f"""
        <div class="section">
            <h2 class="section-title">👥 ユーザー統計</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="number">{total_users}</div>
                    <div class="label">総ユーザー数</div>
                </div>
                <div class="stat-card">
                    <div class="number">{active_users}</div>
                    <div class="label">有効ユーザー</div>
                </div>
                <div class="stat-card">
                    <div class="number">{total_users - active_users}</div>
                    <div class="label">無効ユーザー</div>
                </div>
            </div>
        </div>
        """
        
        # ユーザー一覧テーブル
        if users:
            table_html = """
            <div class="section">
                <h2 class="section-title">📋 ユーザー一覧</h2>
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>メールアドレス</th>
                            <th>部署</th>
                            <th>役職</th>
                            <th>場所</th>
                            <th>状態</th>
                        </tr>
                    </thead>
                    <tbody>
            """
            
            for user in users[:100]:  # 最大100件表示
                status = "有効" if user.get('accountEnabled', True) else "無効"
                status_class = "enabled" if user.get('accountEnabled', True) else "disabled"
                
                table_html += f"""
                        <tr>
                            <td>{user.get('displayName', 'N/A')}</td>
                            <td>{user.get('mail', user.get('userPrincipalName', 'N/A'))}</td>
                            <td>{user.get('department', 'N/A')}</td>
                            <td>{user.get('jobTitle', 'N/A')}</td>
                            <td>{user.get('officeLocation', 'N/A')}</td>
                            <td><span class="{status_class}">{status}</span></td>
                        </tr>
                """
            
            table_html += """
                    </tbody>
                </table>
            </div>
            """
        else:
            table_html = "<div class='section'><p>ユーザーデータがありません。</p></div>"
        
        return stats_html + table_html
    
    def _generate_mfa_status_content(self, data: Dict[str, Any]) -> str:
        """MFA状況レポートコンテンツ"""
        total_users = data.get('total_users', 0)
        mfa_enabled = data.get('mfa_enabled', 0)
        compliance_rate = data.get('compliance_rate', 0)
        
        # 統計カード
        stats_html = f"""
        <div class="section">
            <h2 class="section-title">🔐 MFA統計</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="number">{total_users}</div>
                    <div class="label">総ユーザー数</div>
                </div>
                <div class="stat-card">
                    <div class="number">{mfa_enabled}</div>
                    <div class="label">MFA有効ユーザー</div>
                </div>
                <div class="stat-card">
                    <div class="number">{compliance_rate:.1f}%</div>
                    <div class="label">コンプライアンス率</div>
                </div>
            </div>
        </div>
        """
        
        # MFA詳細テーブル
        mfa_details = data.get('details', [])
        if mfa_details:
            table_html = """
            <div class="section">
                <h2 class="section-title">📋 MFA詳細状況</h2>
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ユーザー名</th>
                            <th>メールアドレス</th>
                            <th>MFA状態</th>
                            <th>登録済み方法</th>
                            <th>既定方法</th>
                        </tr>
                    </thead>
                    <tbody>
            """
            
            for user in mfa_details:
                mfa_status = "有効" if user.get('isMfaRegistered', False) else "無効"
                methods = ", ".join(user.get('methodsRegistered', []))
                default_method = user.get('defaultMethod', 'N/A')
                
                table_html += f"""
                        <tr>
                            <td>{user.get('userDisplayName', 'N/A')}</td>
                            <td>{user.get('userPrincipalName', 'N/A')}</td>
                            <td>{mfa_status}</td>
                            <td>{methods or 'N/A'}</td>
                            <td>{default_method}</td>
                        </tr>
                """
            
            table_html += """
                    </tbody>
                </table>
            </div>
            """
        else:
            table_html = "<div class='section'><p>MFA詳細データがありません。</p></div>"
        
        return stats_html + table_html
    
    def _generate_license_analysis_content(self, data: Dict[str, Any]) -> str:
        """ライセンス分析レポートコンテンツ"""
        licenses = data.get('licenses', [])
        summary = data.get('summary', [])
        
        if summary:
            # 統計カード
            total_consumed = sum(s.get('consumed_units', 0) for s in summary)
            total_enabled = sum(s.get('enabled_units', 0) for s in summary)
            overall_usage = (total_consumed / total_enabled * 100) if total_enabled > 0 else 0
            
            stats_html = f"""
            <div class="section">
                <h2 class="section-title">📊 ライセンス統計</h2>
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="number">{total_enabled}</div>
                        <div class="label">総ライセンス数</div>
                    </div>
                    <div class="stat-card">
                        <div class="number">{total_consumed}</div>
                        <div class="label">使用中ライセンス</div>
                    </div>
                    <div class="stat-card">
                        <div class="number">{overall_usage:.1f}%</div>
                        <div class="label">使用率</div>
                    </div>
                </div>
            </div>
            """
            
            # ライセンス詳細テーブル
            table_html = """
            <div class="section">
                <h2 class="section-title">📋 ライセンス詳細</h2>
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ライセンス名</th>
                            <th>使用中</th>
                            <th>利用可能</th>
                            <th>空き</th>
                            <th>使用率</th>
                        </tr>
                    </thead>
                    <tbody>
            """
            
            for lic in summary:
                sku_name = lic.get('sku_name', 'Unknown')
                consumed = lic.get('consumed_units', 0)
                enabled = lic.get('enabled_units', 0)
                available = lic.get('available_units', 0)
                usage_pct = lic.get('usage_percentage', 0)
                
                table_html += f"""
                        <tr>
                            <td>{sku_name}</td>
                            <td>{consumed}</td>
                            <td>{enabled}</td>
                            <td>{available}</td>
                            <td>{usage_pct:.1f}%</td>
                        </tr>
                """
            
            table_html += """
                    </tbody>
                </table>
            </div>
            """
        else:
            stats_html = "<div class='section'><p>ライセンス統計データがありません。</p></div>"
            table_html = ""
        
        return stats_html + table_html
    
    def _generate_teams_usage_content(self, data: Dict[str, Any]) -> str:
        """Teams使用状況レポートコンテンツ"""
        total_users = data.get('total_users', 0)
        active_users = data.get('active_users', 0)
        meetings_organized = data.get('meetings_organized', 0)
        chat_messages = data.get('chat_messages', 0)
        
        # 統計カード
        stats_html = f"""
        <div class="section">
            <h2 class="section-title">💬 Teams統計</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="number">{active_users}/{total_users}</div>
                    <div class="label">アクティブユーザー</div>
                </div>
                <div class="stat-card">
                    <div class="number">{meetings_organized}</div>
                    <div class="label">会議開催数</div>
                </div>
                <div class="stat-card">
                    <div class="number">{chat_messages:,}</div>
                    <div class="label">チャットメッセージ</div>
                </div>
                <div class="stat-card">
                    <div class="number">{data.get('calls_organized', 0)}</div>
                    <div class="label">通話開催数</div>
                </div>
            </div>
        </div>
        """
        
        # アクティビティ詳細
        activity_html = f"""
        <div class="section">
            <h2 class="section-title">📈 アクティビティ詳細</h2>
            <table class="data-table">
                <thead>
                    <tr><th>項目</th><th>件数</th><th>説明</th></tr>
                </thead>
                <tbody>
                    <tr><td>チャネルメッセージ</td><td>{data.get('channel_messages', 0):,}</td><td>チャネル内でのメッセージ数</td></tr>
                    <tr><td>会議参加数</td><td>{data.get('meetings_attended', 0):,}</td><td>ユーザーが参加した会議数</td></tr>
                    <tr><td>通話参加数</td><td>{data.get('calls_participated', 0):,}</td><td>ユーザーが参加した通話数</td></tr>
                </tbody>
            </table>
        </div>
        """
        
        return stats_html + activity_html
    
    def _generate_signin_logs_content(self, data: Dict[str, Any]) -> str:
        """サインインログレポートコンテンツ"""
        total_signins = data.get('total_signins', 0)
        successful_signins = data.get('successful_signins', 0)
        failed_signins = data.get('failed_signins', 0)
        success_rate = data.get('success_rate', 0)
        
        # 統計カード
        stats_html = f"""
        <div class="section">
            <h2 class="section-title">📝 サインイン統計</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="number">{total_signins:,}</div>
                    <div class="label">総サインイン数</div>
                </div>
                <div class="stat-card">
                    <div class="number">{successful_signins:,}</div>
                    <div class="label">成功</div>
                </div>
                <div class="stat-card">
                    <div class="number">{failed_signins:,}</div>
                    <div class="label">失敗</div>
                </div>
                <div class="stat-card">
                    <div class="number">{success_rate:.1f}%</div>
                    <div class="label">成功率</div>
                </div>
            </div>
        </div>
        """
        
        # サインインログテーブル
        logs = data.get('logs', [])
        if logs:
            table_html = """
            <div class="section">
                <h2 class="section-title">📋 最新サインインログ</h2>
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>日時</th>
                            <th>ユーザー</th>
                            <th>アプリケーション</th>
                            <th>IPアドレス</th>
                            <th>場所</th>
                            <th>結果</th>
                        </tr>
                    </thead>
                    <tbody>
            """
            
            for log in logs[:50]:  # 最大50件表示
                datetime_str = log.get('createdDateTime', '').replace('T', ' ').replace('Z', '')
                location_info = log.get('location', {})
                location_str = f"{location_info.get('city', '')}, {location_info.get('countryOrRegion', '')}"
                
                status = log.get('status', {})
                result = "成功" if status.get('errorCode') == 0 else f"失敗 ({status.get('failureReason', 'Unknown')})"
                result_class = "success" if status.get('errorCode') == 0 else "failure"
                
                table_html += f"""
                        <tr>
                            <td>{datetime_str}</td>
                            <td>{log.get('userDisplayName', log.get('userPrincipalName', 'N/A'))}</td>
                            <td>{log.get('appDisplayName', 'N/A')}</td>
                            <td>{log.get('ipAddress', 'N/A')}</td>
                            <td>{location_str}</td>
                            <td><span class="{result_class}">{result}</span></td>
                        </tr>
                """
            
            table_html += """
                    </tbody>
                </table>
            </div>
            """
        else:
            table_html = "<div class='section'><p>サインインログがありません。</p></div>"
        
        return stats_html + table_html
    
    def _generate_generic_content(self, data: Dict[str, Any]) -> str:
        """汎用コンテンツ生成"""
        content = "<div class='section'><h2 class='section-title'>📊 データ概要</h2>"
        
        # データ統計
        data_items = []
        for key, value in data.items():
            if isinstance(value, (int, float)):
                data_items.append(f"<li><strong>{key}:</strong> {value:,}</li>")
            elif isinstance(value, str):
                data_items.append(f"<li><strong>{key}:</strong> {value}</li>")
            elif isinstance(value, list):
                data_items.append(f"<li><strong>{key}:</strong> {len(value)} 件</li>")
        
        if data_items:
            content += f"<ul>{''.join(data_items)}</ul>"
        else:
            content += "<p>表示可能なデータがありません。</p>"
        
        content += "</div>"
        return content
    
    def _generate_fallback_html(self, template_vars: Dict[str, Any]) -> str:
        """フォールバックHTML生成（テンプレートエンジンなしの場合）"""
        return f"""<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{template_vars['report_title']}</title>
    <style>
        body {{ font-family: 'Segoe UI', sans-serif; margin: 20px; background: #faf9f8; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; }}
        .header {{ background: linear-gradient(135deg, #0078d4, #106ebe); color: white; padding: 30px; text-align: center; }}
        .content {{ padding: 30px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{template_vars['report_title']}</h1>
            <p>{template_vars['report_subtitle']}</p>
            <p>生成日時: {template_vars['generation_time']}</p>
        </div>
        <div class="content">
            {template_vars['content']}
        </div>
    </div>
</body>
</html>"""
    
    def _get_report_title(self, report_type: str) -> str:
        """レポートタイトル取得"""
        titles = {
            "DailyReport": "日次レポート",
            "WeeklyReport": "週次レポート",
            "MonthlyReport": "月次レポート",
            "YearlyReport": "年次レポート",
            "UserList": "ユーザー一覧",
            "MFAStatus": "MFA状況レポート",
            "LicenseAnalysis": "ライセンス分析レポート",
            "TeamsUsage": "Teams使用状況レポート",
            "SignInLogs": "サインインログレポート",
        }
        return titles.get(report_type, f"{report_type} レポート")
    
    def _get_report_subtitle(self, report_type: str) -> str:
        """レポートサブタイトル取得"""
        subtitles = {
            "DailyReport": "Microsoft 365日次アクティビティレポート",
            "WeeklyReport": "Microsoft 365週次利用状況レポート",
            "UserList": "Entra IDユーザー管理レポート",
            "MFAStatus": "多要素認証コンプライアンスレポート",
            "LicenseAnalysis": "ライセンス使用状況分析レポート",
            "TeamsUsage": "Microsoft Teams活用状況レポート",
            "SignInLogs": "セキュリティ・サインイン監査レポート",
        }
        return subtitles.get(report_type, "Microsoft 365管理レポート")
    
    def _get_data_count(self, data: Dict[str, Any]) -> int:
        """データ件数取得"""
        if 'data' in data and isinstance(data['data'], list):
            return len(data['data'])
        elif 'users' in data and isinstance(data['users'], list):
            return len(data['users'])
        elif 'logs' in data and isinstance(data['logs'], list):
            return len(data['logs'])
        else:
            return sum(1 for v in data.values() if not isinstance(v, (dict, list)))
    
    def _open_report_file(self, file_path: str):
        """レポートファイル自動表示"""
        try:
            if sys.platform.startswith('win'):
                # Windows
                os.startfile(file_path)
            elif sys.platform.startswith('darwin'):
                # macOS
                subprocess.run(['open', file_path])
            else:
                # Linux
                subprocess.run(['xdg-open', file_path])
                
            self.logger.info(f"レポートファイルを開きました: {file_path}")
            
        except Exception as e:
            self.logger.error(f"ファイル表示エラー: {str(e)}")
            # PyQt6でWebブラウザを開く
            QDesktopServices.openUrl(QUrl.fromLocalFile(file_path))

# 使用例とテスト
def test_report_generator():
    """レポート生成エンジンのテスト"""
    generator = ReportGenerator()
    
    # テストデータ
    test_data = {
        'users': [
            {'displayName': '田中 太郎', 'mail': 'tanaka@contoso.com', 'department': 'IT', 'accountEnabled': True},
            {'displayName': '佐藤 花子', 'mail': 'sato@contoso.com', 'department': '営業', 'accountEnabled': True}
        ],
        'total_users': 2,
        'tenant_name': 'Test Corporation'
    }
    
    # レポート生成
    files = generator.generate_report('UserList', test_data)
    print(f"Generated files: {files}")

if __name__ == "__main__":
    test_report_generator()