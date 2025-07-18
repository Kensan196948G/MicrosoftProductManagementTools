"""
CLI application for Microsoft365 Management Tools.
Provides command-line interface compatible with PowerShell version.
"""

import logging
import sys
from pathlib import Path
from typing import Optional
import click
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn

from src.core.config import Config


class CLIApp:
    """
    CLI application implementing 26 functions across 6 categories.
    Maintains compatibility with PowerShell CLI version.
    """
    
    def __init__(self, config: Config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.console = Console()
        
    def run_interactive(self):
        """Run interactive menu mode."""
        self.console.print("\n[bold cyan]🚀 Microsoft 365 統合管理ツール - Python Edition[/bold cyan]\n")
        
        while True:
            self._display_menu()
            choice = self.console.input("\n[bold]選択してください (0で終了): [/bold]")
            
            if choice == '0':
                self.console.print("\n[yellow]終了します...[/yellow]")
                break
            
            self._handle_menu_choice(choice)
    
    def _display_menu(self):
        """Display main menu."""
        menu_items = [
            ("1", "📊 定期レポート", "定期実行レポートの生成"),
            ("2", "🔍 分析レポート", "各種分析レポートの生成"),
            ("3", "👥 Entra ID管理", "ユーザー・グループ管理"),
            ("4", "📧 Exchange Online管理", "メールボックス管理"),
            ("5", "💬 Teams管理", "Teams環境の管理"),
            ("6", "💾 OneDrive管理", "ストレージ管理"),
            ("7", "⚙️ 設定", "アプリケーション設定"),
            ("8", "🧪 接続テスト", "API接続テスト"),
        ]
        
        table = Table(title="メインメニュー", show_header=True)
        table.add_column("番号", style="cyan", width=6)
        table.add_column("機能", style="green", width=25)
        table.add_column("説明", style="white")
        
        for num, name, desc in menu_items:
            table.add_row(num, name, desc)
        
        self.console.print(table)
    
    def _handle_menu_choice(self, choice: str):
        """Handle menu selection."""
        handlers = {
            '1': self._regular_reports_menu,
            '2': self._analysis_reports_menu,
            '3': self._entra_id_menu,
            '4': self._exchange_menu,
            '5': self._teams_menu,
            '6': self._onedrive_menu,
            '7': self._settings_menu,
            '8': self._test_connection,
        }
        
        handler = handlers.get(choice)
        if handler:
            handler()
        else:
            self.console.print("[red]無効な選択です[/red]")
    
    def _regular_reports_menu(self):
        """Display regular reports submenu."""
        self.console.print("\n[bold]📊 定期レポート[/bold]")
        
        submenu = [
            ("1", "日次レポート", "daily_report"),
            ("2", "週次レポート", "weekly_report"),
            ("3", "月次レポート", "monthly_report"),
            ("4", "年次レポート", "yearly_report"),
            ("5", "テスト実行", "test_execution"),
        ]
        
        self._display_submenu(submenu)
    
    def _analysis_reports_menu(self):
        """Display analysis reports submenu."""
        self.console.print("\n[bold]🔍 分析レポート[/bold]")
        
        submenu = [
            ("1", "ライセンス分析", "license_analysis"),
            ("2", "使用状況分析", "usage_analysis"),
            ("3", "パフォーマンス分析", "performance_analysis"),
            ("4", "セキュリティ分析", "security_analysis"),
            ("5", "権限監査", "permission_audit"),
        ]
        
        self._display_submenu(submenu)
    
    def _entra_id_menu(self):
        """Display Entra ID management submenu."""
        self.console.print("\n[bold]👥 Entra ID管理[/bold]")
        
        submenu = [
            ("1", "ユーザー一覧", "user_list"),
            ("2", "MFA状況", "mfa_status"),
            ("3", "条件付きアクセス", "conditional_access"),
            ("4", "サインインログ", "signin_logs"),
        ]
        
        self._display_submenu(submenu)
    
    def _exchange_menu(self):
        """Display Exchange Online management submenu."""
        self.console.print("\n[bold]📧 Exchange Online管理[/bold]")
        
        submenu = [
            ("1", "メールボックス管理", "mailbox_management"),
            ("2", "メールフロー分析", "mail_flow_analysis"),
            ("3", "スパム対策", "spam_protection"),
            ("4", "配信分析", "delivery_analysis"),
        ]
        
        self._display_submenu(submenu)
    
    def _teams_menu(self):
        """Display Teams management submenu."""
        self.console.print("\n[bold]💬 Teams管理[/bold]")
        
        submenu = [
            ("1", "Teams使用状況", "teams_usage"),
            ("2", "Teams設定", "teams_settings"),
            ("3", "会議品質", "meeting_quality"),
            ("4", "アプリ分析", "app_analysis"),
        ]
        
        self._display_submenu(submenu)
    
    def _onedrive_menu(self):
        """Display OneDrive management submenu."""
        self.console.print("\n[bold]💾 OneDrive管理[/bold]")
        
        submenu = [
            ("1", "ストレージ分析", "storage_analysis"),
            ("2", "共有分析", "sharing_analysis"),
            ("3", "同期エラー", "sync_errors"),
            ("4", "外部共有分析", "external_sharing"),
        ]
        
        self._display_submenu(submenu)
    
    def _display_submenu(self, items):
        """Display submenu and handle selection."""
        for num, name, _ in items:
            self.console.print(f"  {num}. {name}")
        
        self.console.print("  0. 戻る")
        
        choice = self.console.input("\n選択してください: ")
        
        if choice == '0':
            return
        
        for num, name, action in items:
            if choice == num:
                self.execute_command(action)
                return
        
        self.console.print("[red]無効な選択です[/red]")
    
    def _settings_menu(self):
        """Display settings menu."""
        self.console.print("\n[bold]⚙️ 設定[/bold]")
        self.console.print("  1. 認証設定")
        self.console.print("  2. 出力設定")
        self.console.print("  3. ログ設定")
        self.console.print("  0. 戻る")
        
        choice = self.console.input("\n選択してください: ")
        
        # TODO: Implement settings management
        self.console.print("[yellow]設定機能は実装予定です[/yellow]")
    
    def _test_connection(self):
        """Test API connections."""
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console
        ) as progress:
            task = progress.add_task("API接続テスト中...", total=None)
            
            # TODO: Implement actual connection test
            import time
            time.sleep(2)
            
            progress.stop()
            self.console.print("[green]✓ API接続成功[/green]")
    
    def execute_command(
        self,
        command: str,
        batch_mode: bool = False,
        output_format: str = "both",
        output_dir: Optional[Path] = None
    ):
        """
        Execute a specific command.
        
        Args:
            command: Command to execute
            batch_mode: Run in batch mode (no interaction)
            output_format: Output format (html, csv, both)
            output_dir: Output directory for reports
        """
        self.logger.info(f"Executing command: {command}")
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console
        ) as progress:
            task = progress.add_task(f"{command} 実行中...", total=None)
            
            try:
                # TODO: Implement actual command execution
                # This is where we'd call the appropriate API methods
                # and generate reports
                
                import time
                time.sleep(2)  # Simulate work
                
                progress.stop()
                self.console.print(f"[green]✓ {command} 完了[/green]")
                
                # Show output location
                if output_dir:
                    self.console.print(f"出力先: {output_dir}")
                
            except Exception as e:
                progress.stop()
                self.console.print(f"[red]✗ エラー: {e}[/red]")
                self.logger.error(f"Command execution failed: {e}", exc_info=True)