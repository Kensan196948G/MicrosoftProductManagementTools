"""
Microsoft 365管理ツール データ移行CLI
==================================

PowerShellデータ移行コマンドライン インターフェース
- 対話型・バッチ処理両対応
- 進捗表示・詳細ログ
- PowerShell互換出力
"""

import asyncio
import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, List

from .data_migrator import PowerShellDataMigrator, migrate_specific_function, migrate_all_data
from .csv_template_generator import PowerShellCSVTemplateGenerator


class MigrationCLI:
    """データ移行コマンドライン インターフェース"""
    
    def __init__(self):
        self.migrator = None
        self.template_generator = None
    
    def create_parser(self) -> argparse.ArgumentParser:
        """コマンドライン引数解析器作成"""
        
        parser = argparse.ArgumentParser(
            description="Microsoft 365管理ツール データ移行システム",
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog="""
使用例:
  # 全データ移行
  python -m src.migration.migration_cli migrate --all
  
  # 特定機能の移行
  python -m src.migration.migration_cli migrate --function users
  
  # CSVテンプレート生成
  python -m src.migration.migration_cli template --all
  
  # 対話モード
  python -m src.migration.migration_cli interactive
            """
        )
        
        subparsers = parser.add_subparsers(dest='command', help='使用可能なコマンド')
        
        # migrate サブコマンド
        migrate_parser = subparsers.add_parser('migrate', help='データ移行実行')
        migrate_group = migrate_parser.add_mutually_exclusive_group(required=True)
        migrate_group.add_argument('--all', action='store_true', help='全機能データ移行')
        migrate_group.add_argument('--function', type=str, help='特定機能のみ移行')
        migrate_parser.add_argument('--reports-path', type=str, 
                                  default="/mnt/e/MicrosoftProductManagementTools/Reports",
                                  help='PowerShellレポートパス')
        migrate_parser.add_argument('--batch-size', type=int, default=1000,
                                  help='バッチ処理サイズ')
        migrate_parser.add_argument('--output', type=str, help='結果出力ファイル')
        
        # template サブコマンド  
        template_parser = subparsers.add_parser('template', help='CSVテンプレート生成')
        template_group = template_parser.add_mutually_exclusive_group(required=True)
        template_group.add_argument('--all', action='store_true', help='全機能テンプレート生成')
        template_group.add_argument('--function', type=str, help='特定機能のみ')
        template_parser.add_argument('--output-path', type=str,
                                   default="/mnt/e/MicrosoftProductManagementTools/Templates/Generated",
                                   help='テンプレート出力パス')
        template_parser.add_argument('--sample-data', action='store_true',
                                   help='サンプルデータも生成')
        
        # status サブコマンド
        status_parser = subparsers.add_parser('status', help='移行ステータス確認')
        status_parser.add_argument('--database', action='store_true', help='データベース接続確認')
        status_parser.add_argument('--files', action='store_true', help='移行対象ファイル一覧')
        
        # interactive サブコマンド
        subparsers.add_parser('interactive', help='対話モード起動')
        
        # validate サブコマンド
        validate_parser = subparsers.add_parser('validate', help='データ検証実行')
        validate_parser.add_argument('--function', type=str, help='検証対象機能')
        
        return parser
    
    async def run_migration_command(self, args) -> int:
        """migrate コマンド実行"""
        
        print("🚀 Microsoft 365データ移行開始")
        print(f"📂 レポートパス: {args.reports_path}")
        print(f"📦 バッチサイズ: {args.batch_size}")
        
        try:
            if args.all:
                print("📊 全機能データ移行実行...")
                result = await migrate_all_data(args.reports_path)
            else:
                print(f"📋 機能 '{args.function}' データ移行実行...")
                result = await migrate_specific_function(args.function, args.reports_path)
            
            # 結果表示
            self._display_migration_result(result)
            
            # 結果ファイル出力
            if args.output:
                await self._save_result_to_file(result, args.output)
            
            return 0 if result.get("status") in ["completed", "success"] else 1
            
        except Exception as e:
            print(f"❌ 移行エラー: {e}")
            return 1
    
    async def run_template_command(self, args) -> int:
        """template コマンド実行"""
        
        print("📝 CSVテンプレート生成開始")
        print(f"📂 出力パス: {args.output_path}")
        
        try:
            generator = PowerShellCSVTemplateGenerator(args.output_path)
            
            if args.all:
                print("📊 全機能テンプレート生成...")
                generated_files = generator.generate_all_templates(args.sample_data)
            else:
                print(f"📋 機能 '{args.function}' テンプレート生成...")
                model_class = generator.MODEL_MAPPING.get(args.function)
                if not model_class:
                    print(f"❌ 不明な機能名: {args.function}")
                    return 1
                
                template_path = generator.generate_csv_template(args.function, model_class)
                generated_files = {f"{args.function}_template": str(template_path)}
                
                if args.sample_data:
                    sample_path = generator.generate_sample_data(args.function, model_class)
                    generated_files[f"{args.function}_sample"] = str(sample_path)
            
            # 結果表示
            print("✅ テンプレート生成完了:")
            for name, path in generated_files.items():
                print(f"  📄 {name}: {path}")
            
            return 0
            
        except Exception as e:
            print(f"❌ テンプレート生成エラー: {e}")
            return 1
    
    async def run_status_command(self, args) -> int:
        """status コマンド実行"""
        
        print("📊 システムステータス確認")
        
        if args.database:
            await self._check_database_status()
        
        if args.files:
            await self._check_migration_files()
        
        return 0
    
    async def run_interactive_mode(self) -> int:
        """対話モード実行"""
        
        print("🎯 Microsoft 365データ移行 - 対話モード")
        print("=" * 50)
        
        while True:
            try:
                print("\n利用可能な操作:")
                print("1. 全データ移行")
                print("2. 特定機能データ移行")
                print("3. CSVテンプレート生成")
                print("4. システムステータス確認")
                print("5. 終了")
                
                choice = input("\n選択してください (1-5): ").strip()
                
                if choice == '1':
                    await self._interactive_full_migration()
                elif choice == '2':
                    await self._interactive_function_migration()
                elif choice == '3':
                    await self._interactive_template_generation()
                elif choice == '4':
                    await self._interactive_status_check()
                elif choice == '5':
                    print("👋 対話モード終了")
                    break
                else:
                    print("❌ 無効な選択です")
                
            except KeyboardInterrupt:
                print("\n👋 対話モード終了")
                break
            except Exception as e:
                print(f"❌ エラー: {e}")
        
        return 0
    
    async def _interactive_full_migration(self):
        """対話型全データ移行"""
        
        reports_path = input("レポートパス [/mnt/e/MicrosoftProductManagementTools/Reports]: ").strip()
        if not reports_path:
            reports_path = "/mnt/e/MicrosoftProductManagementTools/Reports"
        
        print("🚀 全データ移行開始...")
        result = await migrate_all_data(reports_path)
        self._display_migration_result(result)
    
    async def _interactive_function_migration(self):
        """対話型機能別移行"""
        
        # 利用可能な機能一覧表示
        print("\n利用可能な機能:")
        functions = list(PowerShellDataMigrator.FUNCTION_MODEL_MAPPING.keys())
        for i, func in enumerate(functions, 1):
            print(f"  {i:2d}. {func}")
        
        try:
            choice = int(input("\n機能番号を選択: ")) - 1
            if 0 <= choice < len(functions):
                function_name = functions[choice]
                
                reports_path = input("レポートパス [/mnt/e/MicrosoftProductManagementTools/Reports]: ").strip()
                if not reports_path:
                    reports_path = "/mnt/e/MicrosoftProductManagementTools/Reports"
                
                print(f"🚀 機能 '{function_name}' 移行開始...")
                result = await migrate_specific_function(function_name, reports_path)
                self._display_migration_result(result)
            else:
                print("❌ 無効な選択です")
        except ValueError:
            print("❌ 数値を入力してください")
    
    async def _interactive_template_generation(self):
        """対話型テンプレート生成"""
        
        output_path = input("出力パス [/mnt/e/MicrosoftProductManagementTools/Templates/Generated]: ").strip()
        if not output_path:
            output_path = "/mnt/e/MicrosoftProductManagementTools/Templates/Generated"
        
        sample_data = input("サンプルデータも生成しますか? (y/N): ").strip().lower() == 'y'
        
        print("📝 全テンプレート生成開始...")
        generator = PowerShellCSVTemplateGenerator(output_path)
        generated_files = generator.generate_all_templates(sample_data)
        
        print("✅ テンプレート生成完了:")
        for name, path in generated_files.items():
            print(f"  📄 {name}: {path}")
    
    async def _interactive_status_check(self):
        """対話型ステータス確認"""
        
        print("📊 システムステータス確認中...")
        await self._check_database_status()
        await self._check_migration_files()
    
    async def _check_database_status(self):
        """データベース接続状態確認"""
        
        try:
            from ..database.connection import test_database_connection
            
            print("🔍 データベース接続確認中...")
            status = await test_database_connection()
            
            if status["connected"]:
                print(f"✅ データベース接続正常")
                print(f"   📊 レイテンシ: {status['latency_ms']}ms")
                print(f"   📋 バージョン: {status['version'][:50]}...")
            else:
                print(f"❌ データベース接続エラー: {status['error']}")
                
        except ImportError:
            print("❌ データベースモジュール読み込みエラー")
        except Exception as e:
            print(f"❌ データベース確認エラー: {e}")
    
    async def _check_migration_files(self):
        """移行対象ファイル確認"""
        
        try:
            reports_path = Path("/mnt/e/MicrosoftProductManagementTools/Reports")
            
            if not reports_path.exists():
                print(f"❌ レポートパスが存在しません: {reports_path}")
                return
            
            # CSVファイル検索
            csv_files = list(reports_path.glob("**/*.csv"))
            json_files = list(reports_path.glob("**/*.json"))
            
            print(f"📁 移行対象ファイル確認:")
            print(f"   📄 CSVファイル: {len(csv_files)}個")
            print(f"   📄 JSONファイル: {len(json_files)}個")
            
            if csv_files or json_files:
                print(f"   📂 最新ファイル例:")
                all_files = csv_files + json_files
                all_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                for file_path in all_files[:5]:
                    print(f"     - {file_path.name}")
            
        except Exception as e:
            print(f"❌ ファイル確認エラー: {e}")
    
    def _display_migration_result(self, result: dict):
        """移行結果表示"""
        
        status = result.get("status", "unknown")
        
        if status == "completed":
            print("\n✅ 移行完了!")
            
            # 統計情報表示
            if "statistics" in result:
                stats = result["statistics"]
                print(f"📊 処理統計:")
                print(f"   📄 処理ファイル数: {stats.get('processed_files', 0)}")
                print(f"   📋 処理レコード数: {stats.get('processed_records', 0)}")
                print(f"   ✅ 成功: {stats.get('successful_records', 0)}")
                print(f"   ❌ 失敗: {stats.get('failed_records', 0)}")
                
                if stats.get('processed_records', 0) > 0:
                    success_rate = stats.get('successful_records', 0) / stats.get('processed_records', 1) * 100
                    print(f"   📈 成功率: {success_rate:.1f}%")
            
            # 処理時間表示
            if "duration_seconds" in result:
                duration = result["duration_seconds"]
                print(f"⏱️  処理時間: {duration:.1f}秒")
            
        elif status == "failed":
            print(f"\n❌ 移行失敗: {result.get('error', '不明なエラー')}")
            
        elif status == "no_data":
            print(f"\n⚠️  データなし: {result.get('message', 'データファイルが見つかりません')}")
    
    async def _save_result_to_file(self, result: dict, output_path: str):
        """結果をファイルに保存"""
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(result, f, ensure_ascii=False, indent=2, default=str)
            
            print(f"📄 結果保存: {output_path}")
            
        except Exception as e:
            print(f"❌ 結果保存エラー: {e}")


async def main():
    """メイン関数"""
    
    cli = MigrationCLI()
    parser = cli.create_parser()
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        if args.command == 'migrate':
            return await cli.run_migration_command(args)
        elif args.command == 'template':
            return await cli.run_template_command(args)
        elif args.command == 'status':
            return await cli.run_status_command(args)
        elif args.command == 'interactive':
            return await cli.run_interactive_mode()
        elif args.command == 'validate':
            print("🔍 データ検証機能は実装予定です")
            return 0
        else:
            print(f"❌ 不明なコマンド: {args.command}")
            return 1
            
    except KeyboardInterrupt:
        print("\n👋 処理を中断しました")
        return 1
    except Exception as e:
        print(f"❌ 予期しないエラー: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))