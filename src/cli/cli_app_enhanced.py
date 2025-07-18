"""
CLI application for Microsoft 365 Management Tools.
Provides command-line interface for all functions.
"""

import logging
import argparse
from typing import Dict, Any, List, Optional
from pathlib import Path

from src.core.config import Config
from src.core.logging_config import setup_logging


class CLIApp:
    """Command-line interface application."""
    
    def __init__(self, config: Config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        
        # Initialize logging for CLI
        setup_logging(
            log_level=config.get('Logging.Level', 'INFO'),
            log_dir=config.get('Logging.Directory', 'Logs'),
            console=True,
            file=True
        )
        
    def run_interactive(self):
        """Run interactive mode with menu."""
        print("\\n🚀 Microsoft 365 統合管理ツール - Python CLI版")
        print("=" * 60)
        
        while True:
            self._show_main_menu()
            choice = input("\\n選択してください (1-7, q): ").strip().lower()
            
            if choice == 'q':
                print("\\n👋 アプリケーションを終了します。")
                break
            elif choice == '1':
                self._regular_reports_menu()
            elif choice == '2':
                self._analysis_reports_menu()
            elif choice == '3':
                self._entra_id_menu()
            elif choice == '4':
                self._exchange_menu()
            elif choice == '5':
                self._teams_menu()
            elif choice == '6':
                self._onedrive_menu()
            elif choice == '7':
                self._test_functions()
            else:
                print("❌ 無効な選択です。もう一度選択してください。")
    
    def _show_main_menu(self):
        """Show main menu options."""
        print("\\n📋 メインメニュー:")
        print("1. 📊 定期レポート")
        print("2. 🔍 分析レポート") 
        print("3. 👥 Entra ID管理")
        print("4. 📧 Exchange Online管理")
        print("5. 💬 Teams管理")
        print("6. 💾 OneDrive管理")
        print("7. 🧪 テスト機能")
        print("q. 終了")
    
    def _regular_reports_menu(self):
        """Regular reports submenu."""
        print("\\n📊 定期レポート:")
        print("1. 日次レポート")
        print("2. 週次レポート")
        print("3. 月次レポート")
        print("4. 年次レポート")
        print("5. テスト実行")
        
        choice = input("選択 (1-5): ").strip()
        actions = {
            '1': 'daily_report',
            '2': 'weekly_report', 
            '3': 'monthly_report',
            '4': 'yearly_report',
            '5': 'test_execution'
        }
        
        if choice in actions:
            self._execute_function(actions[choice])
    
    def _analysis_reports_menu(self):
        """Analysis reports submenu."""
        print("\\n🔍 分析レポート:")
        print("1. ライセンス分析")
        print("2. 使用状況分析")
        print("3. パフォーマンス分析")
        print("4. セキュリティ分析")
        print("5. 権限監査")
        
        choice = input("選択 (1-5): ").strip()
        actions = {
            '1': 'license_analysis',
            '2': 'usage_analysis',
            '3': 'performance_analysis',
            '4': 'security_analysis',
            '5': 'permission_audit'
        }
        
        if choice in actions:
            self._execute_function(actions[choice])
    
    def _entra_id_menu(self):
        """Entra ID management submenu."""
        print("\\n👥 Entra ID管理:")
        print("1. ユーザー一覧")
        print("2. MFA状況")
        print("3. 条件付きアクセス")
        print("4. サインインログ")
        
        choice = input("選択 (1-4): ").strip()
        actions = {
            '1': 'user_list',
            '2': 'mfa_status',
            '3': 'conditional_access',
            '4': 'signin_logs'
        }
        
        if choice in actions:
            self._execute_function(actions[choice])
    
    def _exchange_menu(self):
        """Exchange Online management submenu."""
        print("\\n📧 Exchange Online管理:")
        print("1. メールボックス管理")
        print("2. メールフロー分析")
        print("3. スパム対策分析")
        print("4. 配信分析")
        
        choice = input("選択 (1-4): ").strip()
        actions = {
            '1': 'mailbox_management',
            '2': 'mail_flow_analysis',
            '3': 'spam_protection',
            '4': 'delivery_analysis'
        }
        
        if choice in actions:
            self._execute_function(actions[choice])
    
    def _teams_menu(self):
        """Teams management submenu."""
        print("\\n💬 Teams管理:")
        print("1. Teams使用状況")
        print("2. Teams設定分析")
        print("3. 会議品質分析")
        print("4. アプリ分析")
        
        choice = input("選択 (1-4): ").strip()
        actions = {
            '1': 'teams_usage',
            '2': 'teams_settings',
            '3': 'meeting_quality',
            '4': 'app_analysis'
        }
        
        if choice in actions:
            self._execute_function(actions[choice])
    
    def _onedrive_menu(self):
        """OneDrive management submenu."""
        print("\\n💾 OneDrive管理:")
        print("1. ストレージ分析")
        print("2. 共有分析")
        print("3. 同期エラー分析")
        print("4. 外部共有分析")
        
        choice = input("選択 (1-4): ").strip()
        actions = {
            '1': 'storage_analysis',
            '2': 'sharing_analysis',
            '3': 'sync_errors',
            '4': 'external_sharing'
        }
        
        if choice in actions:
            self._execute_function(actions[choice])
    
    def _test_functions(self):
        """Test functions for development."""
        print("\\n🧪 テスト機能:")
        print("1. 設定テスト")
        print("2. ログテスト")
        print("3. レポート生成テスト")
        print("4. モックデータテスト")
        
        choice = input("選択 (1-4): ").strip()
        
        if choice == '1':
            self._test_config()
        elif choice == '2':
            self._test_logging()
        elif choice == '3':
            self._test_report_generation()
        elif choice == '4':
            self._test_mock_data()
    
    def _execute_function(self, action: str):
        """Execute a specific function."""
        print(f"\\n⚡ 実行中: {action}")
        print("-" * 40)
        
        try:
            # Generate mock data for testing
            data = self._generate_test_data(action)
            
            if data:
                print(f"✅ データ取得完了: {len(data)} 件")
                
                # Generate reports
                self._generate_reports(data, action)
                
                print(f"📋 レポート生成完了: {action}")
            else:
                print("❌ データ取得に失敗しました")
                
        except Exception as e:
            self.logger.error(f"Function execution error: {e}")
            print(f"❌ エラーが発生しました: {e}")
    
    def _generate_test_data(self, action: str) -> List[Dict[str, Any]]:
        """Generate test data for the specified action."""
        import datetime
        import random
        
        # Function name mapping
        function_names = {
            'daily_report': '日次レポート',
            'weekly_report': '週次レポート',
            'monthly_report': '月次レポート',
            'yearly_report': '年次レポート',
            'test_execution': 'テスト実行',
            'license_analysis': 'ライセンス分析',
            'usage_analysis': '使用状況分析',
            'performance_analysis': 'パフォーマンス分析',
            'security_analysis': 'セキュリティ分析',
            'permission_audit': '権限監査',
            'user_list': 'ユーザー一覧',
            'mfa_status': 'MFA状況',
            'conditional_access': '条件付きアクセス',
            'signin_logs': 'サインインログ',
            'mailbox_management': 'メールボックス管理',
            'mail_flow_analysis': 'メールフロー分析',
            'spam_protection': 'スパム対策',
            'delivery_analysis': '配信分析',
            'teams_usage': 'Teams使用状況',
            'teams_settings': 'Teams設定',
            'meeting_quality': '会議品質',
            'app_analysis': 'アプリ分析',
            'storage_analysis': 'ストレージ分析',
            'sharing_analysis': '共有分析',
            'sync_errors': '同期エラー',
            'external_sharing': '外部共有分析'
        }
        
        report_name = function_names.get(action, action)
        
        # Generate sample data
        data = []
        record_count = random.randint(5, 20)
        
        for i in range(record_count):
            data.append({
                'ID': i + 1,
                'レポートタイプ': report_name,
                '実行日時': datetime.datetime.now().strftime('%Y/%m/%d %H:%M:%S'),
                'ステータス': random.choice(['正常', '警告', '異常']),
                '詳細': f'{report_name} - サンプルレコード {i + 1}',
                'カテゴリ': action,
                '実行モード': 'CLI'
            })
        
        return data
    
    def _generate_reports(self, data: List[Dict[str, Any]], action: str):
        """Generate CSV and HTML reports."""
        try:
            from src.reports.generators.csv_generator import CSVGenerator
            from src.reports.generators.html_generator import HTMLGenerator
            from datetime import datetime
            
            # Create output directory
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            output_dir = Path(self.config.get('ReportSettings.OutputPath', 'Reports')) / 'CLI'
            output_dir.mkdir(parents=True, exist_ok=True)
            
            base_filename = f'{action}_{timestamp}'
            
            # Generate CSV
            csv_gen = CSVGenerator()
            csv_path = output_dir / f'{base_filename}.csv'
            if csv_gen.generate(data, str(csv_path)):
                print(f"   📄 CSV: {csv_path}")
            
            # Generate HTML
            html_gen = HTMLGenerator()
            html_path = output_dir / f'{base_filename}.html'
            if html_gen.generate(data, str(html_path), f'{action} レポート'):
                print(f"   🌐 HTML: {html_path}")
            
        except Exception as e:
            self.logger.error(f"Report generation error: {e}")
            print(f"❌ レポート生成エラー: {e}")
    
    def _test_config(self):
        """Test configuration functionality."""
        print("\\n🔧 設定テスト:")
        print(f"   設定ファイル: {self.config.config_path}")
        print(f"   テナントID: {self.config.get('Authentication.TenantId', '未設定')}")
        print(f"   出力パス: {self.config.get('ReportSettings.OutputPath', '未設定')}")
        print(f"   ログレベル: {self.config.get('Logging.Level', '未設定')}")
        print("✅ 設定テスト完了")
    
    def _test_logging(self):
        """Test logging functionality."""
        print("\\n📝 ログテスト:")
        self.logger.debug("DEBUG レベルのテストメッセージ")
        self.logger.info("INFO レベルのテストメッセージ")
        self.logger.warning("WARNING レベルのテストメッセージ")
        self.logger.error("ERROR レベルのテストメッセージ")
        print("✅ ログテスト完了")
    
    def _test_report_generation(self):
        """Test report generation."""
        print("\\n📊 レポート生成テスト:")
        test_data = [
            {'ID': 1, 'テスト項目': 'サンプル1', 'ステータス': '正常'},
            {'ID': 2, 'テスト項目': 'サンプル2', 'ステータス': '警告'},
            {'ID': 3, 'テスト項目': 'サンプル3', 'ステータス': '異常'}
        ]
        
        self._generate_reports(test_data, 'test_report')
        print("✅ レポート生成テスト完了")
    
    def _test_mock_data(self):
        """Test mock data generation."""
        print("\\n🎭 モックデータテスト:")
        actions = ['user_list', 'license_analysis', 'teams_usage']
        
        for action in actions:
            data = self._generate_test_data(action)
            print(f"   {action}: {len(data)} 件のデータ生成")
        
        print("✅ モックデータテスト完了")
    
    def execute_command(self, command: str, batch_mode: bool = False,
                       output_format: str = 'both', output_dir: Optional[Path] = None):
        """Execute a specific command (for non-interactive use)."""
        if batch_mode:
            print(f"🤖 バッチモードで実行: {command}")
        
        # Override output directory if specified
        if output_dir:
            self.config.set('ReportSettings.OutputPath', str(output_dir))
        
        # Execute the function
        self._execute_function(command)
        
        if batch_mode:
            print(f"✅ バッチ実行完了: {command}")


def main():
    """Main entry point for CLI."""
    from src.core.config import Config
    
    config = Config()
    config.load()
    
    cli = CLIApp(config)
    cli.run_interactive()


if __name__ == "__main__":
    main()