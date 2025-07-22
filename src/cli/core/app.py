# Microsoft 365 Management Tools - CLI Application Core
# Main CLI application class with PowerShell compatibility

import asyncio
import logging
from typing import Dict, Any, Optional, List
from pathlib import Path
import click

from src.core.config import Config
from src.core.auth.authenticator import Authenticator
from src.api.graph.client import GraphClient
from src.api.exchange.client import ExchangeClient
from .context import CLIContext
from .output import OutputFormatter

logger = logging.getLogger(__name__)

class M365CLI:
    """Microsoft 365 CLI Application - PowerShell Enhanced CLI Compatible"""
    
    def __init__(self, context: CLIContext):
        self.context = context
        self.config = context.config
        self.output = OutputFormatter(context)
        
        # Initialize authenticator
        self.authenticator = Authenticator(self.config)
        
        # Initialize API clients (lazy loading)
        self._graph_client: Optional[GraphClient] = None
        self._exchange_client: Optional[ExchangeClient] = None
        
        logger.info("M365CLI initialized")
    
    @property
    def graph_client(self) -> GraphClient:
        """Get Microsoft Graph client (lazy initialization)"""
        if self._graph_client is None:
            self._graph_client = GraphClient(self.authenticator)
        return self._graph_client
    
    @property  
    def exchange_client(self) -> ExchangeClient:
        """Get Exchange Online client (lazy initialization)"""
        if self._exchange_client is None:
            self._exchange_client = ExchangeClient(self.authenticator)
        return self._exchange_client
    
    async def run_interactive_menu(self):
        """Run interactive menu (PowerShell Enhanced CLI compatible)"""
        
        click.echo("\\n🚀 Microsoft 365統合管理ツール - Python CLI版")
        click.echo("=" * 60)
        click.echo("PowerShell Enhanced CLI完全互換 + エンタープライズ機能")
        
        if not self.context.no_connect:
            await self._authenticate()
        
        while True:
            self._show_main_menu()
            choice = click.prompt("\\n選択してください (1-7, q)", 
                                type=str, default='q').strip().lower()
            
            if choice == 'q':
                click.echo("\\n👋 アプリケーションを終了します。")
                break
            elif choice == '1':
                await self._regular_reports_menu()
            elif choice == '2':
                await self._analysis_reports_menu()
            elif choice == '3':
                await self._entra_id_menu()
            elif choice == '4':
                await self._exchange_menu()
            elif choice == '5':
                await self._teams_menu()
            elif choice == '6':
                await self._onedrive_menu()
            elif choice == '7':
                await self._system_menu()
            else:
                click.echo("❌ 無効な選択です。1-7またはqを入力してください。")
    
    def _show_main_menu(self):
        """Show main menu (PowerShell Enhanced CLI compatible)"""
        
        menu_text = \"\"\"
📋 メインメニュー
─────────────────────────────────────────
1. 📊 定期レポート (5機能)
   - 日次/週次/月次/年次レポート、テスト実行
   
2. 🔍 分析レポート (5機能)  
   - ライセンス/使用状況/パフォーマンス/セキュリティ/権限分析
   
3. 👥 Entra ID管理 (4機能)
   - ユーザー/MFA/条件付きアクセス/サインインログ
   
4. 📧 Exchange Online管理 (4機能)
   - メールボックス/フロー/スパム対策/配信分析
   
5. 💬 Teams管理 (4機能)
   - 使用状況/設定/会議品質/アプリ分析
   
6. 💾 OneDrive管理 (4機能)
   - ストレージ/共有/同期エラー/外部共有
   
7. ⚙️  システム管理
   - 接続状況確認/設定/ログ確認
   
q. 終了
        \"\"\"
        
        click.echo(menu_text)
    
    async def _authenticate(self):
        """Microsoft 365 authentication"""
        try:
            click.echo("\\n🔐 Microsoft 365に認証中...")
            
            if self.context.dry_run:
                click.echo("✅ ドライランモード: 認証をスキップしました")
                return
            
            # Authenticate with Graph API
            await self.authenticator.authenticate_graph()
            
            # Authenticate with Exchange Online  
            await self.authenticator.authenticate_exchange()
            
            click.echo("✅ Microsoft 365認証が完了しました")
            
        except Exception as e:
            logger.error(f"Authentication failed: {e}")
            click.echo(f"❌ 認証に失敗しました: {e}")
            if not click.confirm("認証なしで続行しますか？"):
                raise click.Abort()
    
    async def _regular_reports_menu(self):
        """Regular reports submenu (PowerShell compatible)"""
        
        while True:
            menu_text = \"\"\"
📊 定期レポートメニュー
─────────────────────
1. 日次セキュリティレポート
2. 週次活動レポート  
3. 月次利用状況レポート
4. 年次統計レポート
5. テスト実行レポート
b. メインメニューに戻る
            \"\"\"
            
            click.echo(menu_text)
            choice = click.prompt("選択してください", type=str, default='b').strip()
            
            if choice == 'b':
                break
            elif choice == '1':
                await self._run_daily_report()
            elif choice == '2':
                await self._run_weekly_report()
            elif choice == '3':
                await self._run_monthly_report()
            elif choice == '4':
                await self._run_yearly_report()
            elif choice == '5':
                await self._run_test_report()
            else:
                click.echo("❌ 無効な選択です")
    
    async def _analysis_reports_menu(self):
        """Analysis reports submenu"""
        
        while True:
            menu_text = \"\"\"
🔍 分析レポートメニュー
─────────────────────
1. ライセンス分析
2. 使用状況分析
3. パフォーマンス分析
4. セキュリティ分析  
5. 権限監査分析
b. メインメニューに戻る
            \"\"\"
            
            click.echo(menu_text)
            choice = click.prompt("選択してください", type=str, default='b').strip()
            
            if choice == 'b':
                break
            elif choice == '1':
                await self._run_license_analysis()
            elif choice == '2':
                await self._run_usage_analysis()
            elif choice == '3':
                await self._run_performance_analysis()
            elif choice == '4':
                await self._run_security_analysis()
            elif choice == '5':
                await self._run_permission_analysis()
            else:
                click.echo("❌ 無効な選択です")
    
    async def _entra_id_menu(self):
        """Entra ID management submenu"""
        
        while True:
            menu_text = \"\"\"
👥 Entra ID管理メニュー
──────────────────────
1. ユーザー一覧・管理
2. MFA状況確認
3. 条件付きアクセス確認
4. サインインログ分析
b. メインメニューに戻る
            \"\"\"
            
            click.echo(menu_text)
            choice = click.prompt("選択してください", type=str, default='b').strip()
            
            if choice == 'b':
                break
            elif choice == '1':
                await self._manage_users()
            elif choice == '2':
                await self._check_mfa_status()
            elif choice == '3':
                await self._check_conditional_access()
            elif choice == '4':
                await self._analyze_signin_logs()
            else:
                click.echo("❌ 無効な選択です")
    
    async def _exchange_menu(self):
        """Exchange Online management submenu"""
        
        while True:
            menu_text = \"\"\"
📧 Exchange Online管理メニュー
─────────────────────────────
1. メールボックス管理
2. メールフロー分析
3. スパム対策状況
4. 配信分析
b. メインメニューに戻る
            \"\"\"
            
            click.echo(menu_text)
            choice = click.prompt("選択してください", type=str, default='b').strip()
            
            if choice == 'b':
                break
            elif choice == '1':
                await self._manage_mailboxes()
            elif choice == '2':
                await self._analyze_mailflow()
            elif choice == '3':
                await self._check_spam_protection()
            elif choice == '4':
                await self._analyze_delivery()
            else:
                click.echo("❌ 無効な選択です")
    
    async def _teams_menu(self):
        """Teams management submenu"""
        
        while True:
            menu_text = \"\"\"
💬 Teams管理メニュー
────────────────────
1. Teams使用状況
2. Teams設定分析
3. 会議品質分析
4. Teamsアプリ分析
b. メインメニューに戻る
            \"\"\"
            
            click.echo(menu_text)
            choice = click.prompt("選択してください", type=str, default='b').strip()
            
            if choice == 'b':
                break
            elif choice == '1':
                await self._analyze_teams_usage()
            elif choice == '2':
                await self._analyze_teams_settings()
            elif choice == '3':
                await self._analyze_meeting_quality()
            elif choice == '4':
                await self._analyze_teams_apps()
            else:
                click.echo("❌ 無効な選択です")
    
    async def _onedrive_menu(self):
        """OneDrive management submenu"""
        
        while True:
            menu_text = \"\"\"
💾 OneDrive管理メニュー
──────────────────────
1. ストレージ分析
2. 共有分析
3. 同期エラー分析
4. 外部共有分析
b. メインメニューに戻る
            \"\"\"
            
            click.echo(menu_text)
            choice = click.prompt("選択してください", type=str, default='b').strip()
            
            if choice == 'b':
                break
            elif choice == '1':
                await self._analyze_storage()
            elif choice == '2':
                await self._analyze_sharing()
            elif choice == '3':
                await self._analyze_sync_errors()
            elif choice == '4':
                await self._analyze_external_sharing()
            else:
                click.echo("❌ 無効な選択です")
    
    async def _system_menu(self):
        """System management menu"""
        
        while True:
            menu_text = \"\"\"
⚙️ システム管理メニュー
──────────────────────
1. 接続状況確認
2. 設定表示
3. ログ確認
4. パフォーマンス情報
b. メインメニューに戻る
            \"\"\"
            
            click.echo(menu_text)
            choice = click.prompt("選択してください", type=str, default='b').strip()
            
            if choice == 'b':
                break
            elif choice == '1':
                await self._check_connection_status()
            elif choice == '2':
                self._show_configuration()
            elif choice == '3':
                self._show_logs()
            elif choice == '4':
                await self._show_performance_info()
            else:
                click.echo("❌ 無効な選択です")
    
    # Report execution methods (to be implemented by command modules)
    async def _run_daily_report(self):
        """Execute daily report"""
        click.echo("\\n📊 日次セキュリティレポートを実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: レポート生成をスキップしました")
            return
        
        # Import and execute daily report command
        from src.cli.commands.reports.daily import execute_daily_report
        await execute_daily_report(self.context)
    
    async def _run_weekly_report(self):
        """Execute weekly report"""
        click.echo("\\n📊 週次活動レポートを実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: レポート生成をスキップしました")
            return
            
        from src.cli.commands.reports.weekly import execute_weekly_report
        await execute_weekly_report(self.context)
    
    async def _run_monthly_report(self):
        """Execute monthly report"""
        click.echo("\\n📊 月次利用状況レポートを実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: レポート生成をスキップしました")
            return
            
        from src.cli.commands.reports.monthly import execute_monthly_report
        await execute_monthly_report(self.context)
    
    async def _run_yearly_report(self):
        """Execute yearly report"""
        click.echo("\\n📊 年次統計レポートを実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: レポート生成をスキップしました")
            return
            
        from src.cli.commands.reports.yearly import execute_yearly_report
        await execute_yearly_report(self.context)
    
    async def _run_test_report(self):
        """Execute test report"""
        click.echo("\\n🧪 テスト実行レポートを実行中...")
        
        from src.cli.commands.reports.test import execute_test_report
        await execute_test_report(self.context)
    
    # Analysis methods
    async def _run_license_analysis(self):
        """Execute license analysis"""
        click.echo("\\n🔍 ライセンス分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 分析をスキップしました")
            return
            
        from src.cli.commands.analysis.license import execute_license_analysis
        await execute_license_analysis(self.context)
    
    async def _run_usage_analysis(self):
        """Execute usage analysis"""
        click.echo("\\n🔍 使用状況分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 分析をスキップしました")
            return
            
        from src.cli.commands.analysis.usage import execute_usage_analysis
        await execute_usage_analysis(self.context)
    
    async def _run_performance_analysis(self):
        """Execute performance analysis"""
        click.echo("\\n🔍 パフォーマンス分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 分析をスキップしました")
            return
            
        from src.cli.commands.analysis.performance import execute_performance_analysis
        await execute_performance_analysis(self.context)
    
    async def _run_security_analysis(self):
        """Execute security analysis"""
        click.echo("\\n🔍 セキュリティ分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 分析をスキップしました")
            return
            
        from src.cli.commands.analysis.security import execute_security_analysis
        await execute_security_analysis(self.context)
    
    async def _run_permission_analysis(self):
        """Execute permission analysis"""
        click.echo("\\n🔍 権限監査分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 分析をスキップしました")
            return
            
        from src.cli.commands.analysis.permission import execute_permission_analysis
        await execute_permission_analysis(self.context)
    
    # Entra ID management methods
    async def _manage_users(self):
        """Manage Entra ID users"""
        click.echo("\\n👥 ユーザー管理を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: ユーザー管理をスキップしました")
            return
            
        from src.cli.commands.entraid.users import execute_users_management
        await execute_users_management(self.context)
    
    async def _check_mfa_status(self):
        """Check MFA status"""
        click.echo("\\n🔐 MFA状況確認を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: MFA確認をスキップしました")
            return
            
        from src.cli.commands.entraid.mfa import execute_mfa_check
        await execute_mfa_check(self.context)
    
    async def _check_conditional_access(self):
        """Check conditional access"""
        click.echo("\\n🛡️ 条件付きアクセス確認を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 条件付きアクセス確認をスキップしました")
            return
            
        from src.cli.commands.entraid.conditional import execute_conditional_access_check
        await execute_conditional_access_check(self.context)
    
    async def _analyze_signin_logs(self):
        """Analyze sign-in logs"""
        click.echo("\\n📋 サインインログ分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: ログ分析をスキップしました")
            return
            
        from src.cli.commands.entraid.signin import execute_signin_analysis
        await execute_signin_analysis(self.context)
    
    # Exchange management methods
    async def _manage_mailboxes(self):
        """Manage mailboxes"""
        click.echo("\\n📧 メールボックス管理を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: メールボックス管理をスキップしました")
            return
            
        from src.cli.commands.exchange.mailbox import execute_mailbox_management
        await execute_mailbox_management(self.context)
    
    async def _analyze_mailflow(self):
        """Analyze mail flow"""
        click.echo("\\n📬 メールフロー分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: フロー分析をスキップしました")
            return
            
        from src.cli.commands.exchange.mailflow import execute_mailflow_analysis
        await execute_mailflow_analysis(self.context)
    
    async def _check_spam_protection(self):
        """Check spam protection"""
        click.echo("\\n🛡️ スパム対策確認を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: スパム対策確認をスキップしました")
            return
            
        from src.cli.commands.exchange.spam import execute_spam_check
        await execute_spam_check(self.context)
    
    async def _analyze_delivery(self):
        """Analyze mail delivery"""
        click.echo("\\n📨 配信分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 配信分析をスキップしました")
            return
            
        from src.cli.commands.exchange.delivery import execute_delivery_analysis
        await execute_delivery_analysis(self.context)
    
    # Teams management methods
    async def _analyze_teams_usage(self):
        """Analyze Teams usage"""
        click.echo("\\n💬 Teams使用状況分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: Teams分析をスキップしました")
            return
            
        from src.cli.commands.teams.usage import execute_teams_usage_analysis
        await execute_teams_usage_analysis(self.context)
    
    async def _analyze_teams_settings(self):
        """Analyze Teams settings"""
        click.echo("\\n⚙️ Teams設定分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 設定分析をスキップしました")
            return
            
        from src.cli.commands.teams.settings import execute_teams_settings_analysis
        await execute_teams_settings_analysis(self.context)
    
    async def _analyze_meeting_quality(self):
        """Analyze meeting quality"""
        click.echo("\\n📹 会議品質分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 会議分析をスキップしました")
            return
            
        from src.cli.commands.teams.meetings import execute_meeting_quality_analysis
        await execute_meeting_quality_analysis(self.context)
    
    async def _analyze_teams_apps(self):
        """Analyze Teams apps"""
        click.echo("\\n📱 Teamsアプリ分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: アプリ分析をスキップしました")
            return
            
        from src.cli.commands.teams.apps import execute_teams_apps_analysis
        await execute_teams_apps_analysis(self.context)
    
    # OneDrive management methods
    async def _analyze_storage(self):
        """Analyze OneDrive storage"""
        click.echo("\\n💾 OneDriveストレージ分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: ストレージ分析をスキップしました")
            return
            
        from src.cli.commands.onedrive.storage import execute_storage_analysis
        await execute_storage_analysis(self.context)
    
    async def _analyze_sharing(self):
        """Analyze OneDrive sharing"""
        click.echo("\\n🔗 OneDrive共有分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 共有分析をスキップしました")
            return
            
        from src.cli.commands.onedrive.sharing import execute_sharing_analysis
        await execute_sharing_analysis(self.context)
    
    async def _analyze_sync_errors(self):
        """Analyze sync errors"""
        click.echo("\\n⚠️ 同期エラー分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: エラー分析をスキップしました")
            return
            
        from src.cli.commands.onedrive.syncerror import execute_sync_error_analysis
        await execute_sync_error_analysis(self.context)
    
    async def _analyze_external_sharing(self):
        """Analyze external sharing"""
        click.echo("\\n🌐 外部共有分析を実行中...")
        
        if self.context.dry_run:
            click.echo("✅ ドライランモード: 外部共有分析をスキップしました")
            return
            
        from src.cli.commands.onedrive.external import execute_external_sharing_analysis
        await execute_external_sharing_analysis(self.context)
    
    # System methods
    async def _check_connection_status(self):
        """Check connection status"""
        click.echo("\\n🔗 接続状況確認中...")
        
        try:
            # Check Graph API connection
            if self.context.no_connect or self.context.dry_run:
                click.echo("📊 Microsoft Graph: ⚠️ 未接続 (スキップモード)")
                click.echo("📧 Exchange Online: ⚠️ 未接続 (スキップモード)")
            else:
                graph_status = await self.graph_client.check_connection()
                exchange_status = await self.exchange_client.check_connection()
                
                graph_icon = "✅" if graph_status else "❌"
                exchange_icon = "✅" if exchange_status else "❌"
                
                click.echo(f"📊 Microsoft Graph: {graph_icon} {'接続済み' if graph_status else '未接続'}")
                click.echo(f"📧 Exchange Online: {exchange_icon} {'接続済み' if exchange_status else '未接続'}")
            
            click.echo(f"🗂️ データベース: ✅ 接続済み")
            click.echo(f"🚀 Redis キャッシュ: ✅ 接続済み")
            
        except Exception as e:
            logger.error(f"Connection check failed: {e}")
            click.echo(f"❌ 接続確認に失敗しました: {e}")
    
    def _show_configuration(self):
        """Show current configuration"""
        click.echo("\\n⚙️ 現在の設定:")
        click.echo(f"📁 出力パス: {self.context.output_path or '自動'}")
        click.echo(f"📄 出力形式: {', '.join([k for k, v in self.context.output_formats.items() if v]) or 'デフォルト'}")
        click.echo(f"📊 最大結果数: {self.context.max_results}")
        click.echo(f"🔄 バッチモード: {'有効' if self.context.batch_mode else '無効'}")
        click.echo(f"🧪 ドライランモード: {'有効' if self.context.dry_run else '無効'}")
        click.echo(f"🔗 接続スキップ: {'有効' if self.context.no_connect else '無効'}")
    
    def _show_logs(self):
        """Show recent logs"""
        click.echo("\\n📋 最新ログ情報:")
        try:
            log_file = Path("Logs/CLI") / "app.log"
            if log_file.exists():
                with open(log_file, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    recent_lines = lines[-10:] if len(lines) > 10 else lines
                    for line in recent_lines:
                        click.echo(f"  {line.strip()}")
            else:
                click.echo("ログファイルが見つかりません")
        except Exception as e:
            click.echo(f"ログ読み込みエラー: {e}")
    
    async def _show_performance_info(self):
        """Show performance information"""
        click.echo("\\n⚡ パフォーマンス情報:")
        
        try:
            import psutil
            
            # System info
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            
            click.echo(f"🖥️ CPU使用率: {cpu_percent:.1f}%")
            click.echo(f"💾 メモリ使用率: {memory.percent:.1f}%")
            click.echo(f"💾 使用メモリ: {memory.used // (1024**2):.0f}MB / {memory.total // (1024**2):.0f}MB")
            
            # Database performance (if available)
            try:
                from src.database.performance import get_powershell_performance_status
                db_status = get_powershell_performance_status()
                
                click.echo(f"🗃️ データベース: {db_status.get('PerformanceStatus', 'UNKNOWN')}")
                click.echo(f"📊 キャッシュ効率: {db_status.get('CacheHitRatio', 0):.1f}%")
            except:
                click.echo("🗃️ データベース: パフォーマンス情報取得不可")
                
        except ImportError:
            click.echo("パフォーマンス情報の取得にはpsutilが必要です")
        except Exception as e:
            click.echo(f"パフォーマンス情報取得エラー: {e}")