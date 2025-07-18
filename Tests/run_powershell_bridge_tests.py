#!/usr/bin/env python3
"""
PowerShellBridge専用テストランナー
新しく作成したPowerShellBridge互換性テストを実行します
"""

import sys
import os
from pathlib import Path
import pytest
import json
from datetime import datetime
import subprocess
import logging

# プロジェクトルートをPythonパスに追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


def setup_logging():
    """ログ設定"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(project_root / "TestOutput" / "powershell_bridge_tests.log", encoding='utf-8')
        ]
    )
    return logging.getLogger(__name__)


def run_powershell_bridge_tests():
    """PowerShellBridgeテストを実行"""
    logger = setup_logging()
    
    print("=" * 80)
    print("🔄 PowerShellBridge 互換性テストスイート")
    print("=" * 80)
    print(f"📅 実行日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📁 プロジェクトルート: {project_root}")
    print()
    
    # 出力ディレクトリを作成
    output_dir = project_root / "TestOutput"
    output_dir.mkdir(exist_ok=True)
    
    # テストディレクトリ
    test_dir = project_root / "Tests" / "compatibility"
    
    # 実行するテストファイル
    test_files = [
        "test_powershell_bridge.py",
        "test_data_format_compatibility.py", 
        "test_advanced_scenarios.py"
    ]
    
    print("🧪 実行対象テスト:")
    for test_file in test_files:
        test_path = test_dir / test_file
        if test_path.exists():
            print(f"  ✅ {test_file}")
        else:
            print(f"  ❌ {test_file} (見つかりません)")
    print()
    
    # pytest設定
    pytest_args = [
        "-v",  # 詳細出力
        "--tb=short",  # 短いトレースバック
        "--color=yes",  # カラー出力
        "-p", "no:warnings",  # 警告を非表示
        "--durations=10",  # 実行時間が長いテストTOP10を表示
        str(test_dir),
    ]
    
    # オプション処理
    if "--coverage" in sys.argv:
        pytest_args.extend([
            "--cov=src.core.powershell_bridge",
            "--cov-report=html:TestOutput/coverage_powershell_bridge",
            "--cov-report=term-missing",
            "--cov-report=json:TestOutput/coverage_powershell_bridge.json"
        ])
        print("📊 コードカバレッジ測定が有効です")
    
    if "--quick" in sys.argv:
        pytest_args.extend(["-m", "not slow"])
        print("⚡ クイックテストモードが有効です")
    
    if "--html-report" in sys.argv:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        html_report = output_dir / f"powershell_bridge_report_{timestamp}.html"
        pytest_args.extend([
            "--html=" + str(html_report),
            "--self-contained-html"
        ])
        print(f"📄 HTMLレポートが生成されます: {html_report}")
    
    if "--xml-report" in sys.argv:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        xml_report = output_dir / f"powershell_bridge_junit_{timestamp}.xml"
        pytest_args.extend([
            "--junit-xml=" + str(xml_report)
        ])
        print(f"📄 XML JUnitレポートが生成されます: {xml_report}")
    
    # 特定のテストパターンのみ実行
    if "-k" in sys.argv:
        idx = sys.argv.index("-k")
        if idx + 1 < len(sys.argv):
            test_pattern = sys.argv[idx + 1]
            pytest_args.extend(["-k", test_pattern])
            print(f"🔍 テストパターン: {test_pattern}")
    
    print()
    print("🚀 テスト実行中...")
    print("-" * 80)
    
    start_time = datetime.now()
    
    try:
        # pytestを実行
        exit_code = pytest.main(pytest_args)
        
        end_time = datetime.now()
        execution_time = (end_time - start_time).total_seconds()
        
        print("-" * 80)
        print(f"⏱️  実行時間: {execution_time:.2f}秒")
        
        # 結果サマリー
        if exit_code == 0:
            print("🎉 全てのテストが成功しました！")
            logger.info("PowerShellBridge互換性テスト完了: 全テスト成功")
        else:
            print(f"⚠️  一部のテストが失敗しました (終了コード: {exit_code})")
            logger.warning(f"PowerShellBridge互換性テスト完了: 一部テスト失敗 (終了コード: {exit_code})")
        
        # カバレッジ結果を表示
        if "--coverage" in sys.argv:
            coverage_json = output_dir / "coverage_powershell_bridge.json"
            if coverage_json.exists():
                try:
                    with open(coverage_json, 'r') as f:
                        coverage_data = json.load(f)
                        total_coverage = coverage_data.get("totals", {}).get("percent_covered", 0)
                        print(f"📊 コードカバレッジ: {total_coverage:.1f}%")
                except Exception as e:
                    logger.error(f"カバレッジデータの読み込みエラー: {e}")
        
        return exit_code
        
    except Exception as e:
        logger.error(f"テスト実行中にエラーが発生: {e}")
        print(f"❌ テスト実行エラー: {e}")
        return 1


def list_available_tests():
    """利用可能なテストをリスト表示"""
    print("📋 利用可能なテスト:")
    print()
    
    test_dir = project_root / "Tests" / "compatibility"
    test_files = [
        ("test_powershell_bridge.py", "PowerShellBridge基本機能テスト"),
        ("test_data_format_compatibility.py", "データフォーマット互換性テスト"),
        ("test_advanced_scenarios.py", "高度なシナリオテスト（非同期・パフォーマンス）"),
    ]
    
    for file_name, description in test_files:
        file_path = test_dir / file_name
        if file_path.exists():
            # テスト関数の数をカウント
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    test_count = content.count("def test_")
                    class_count = content.count("class Test")
                    print(f"📄 {file_name}")
                    print(f"   📋 {description}")
                    print(f"   📊 {test_count} テスト関数, {class_count} テストクラス")
            except Exception as e:
                print(f"📄 {file_name} (読み込みエラー: {e})")
        else:
            print(f"❌ {file_name} (見つかりません)")
        print()
    
    print("🔧 実行オプション:")
    print("  python run_powershell_bridge_tests.py                    # 全テスト実行")
    print("  python run_powershell_bridge_tests.py --quick            # クイックテスト")
    print("  python run_powershell_bridge_tests.py --coverage         # カバレッジ測定")
    print("  python run_powershell_bridge_tests.py --html-report      # HTMLレポート生成")
    print("  python run_powershell_bridge_tests.py --xml-report       # XML JUnitレポート生成")
    print("  python run_powershell_bridge_tests.py -k <pattern>      # 特定パターンのテスト実行")
    print()
    print("📝 例:")
    print("  python run_powershell_bridge_tests.py -k \"test_execute_command\"")
    print("  python run_powershell_bridge_tests.py -k \"compatibility\"")
    print("  python run_powershell_bridge_tests.py -k \"async\"")


def check_prerequisites():
    """前提条件をチェック"""
    print("🔍 前提条件チェック...")
    
    # Pythonバージョン
    python_version = sys.version_info
    print(f"   Python: {python_version.major}.{python_version.minor}.{python_version.micro}")
    if python_version < (3, 8):
        print("   ⚠️  Python 3.8以上が推奨されます")
    
    # 必要なモジュール
    required_modules = ['pytest', 'pathlib', 'json', 'datetime', 'subprocess']
    missing_modules = []
    
    for module in required_modules:
        try:
            __import__(module)
            print(f"   ✅ {module}")
        except ImportError:
            missing_modules.append(module)
            print(f"   ❌ {module} (見つかりません)")
    
    # PowerShellBridgeモジュール
    try:
        from src.core.powershell_bridge import PowerShellBridge
        print("   ✅ PowerShellBridge")
    except ImportError as e:
        print(f"   ❌ PowerShellBridge (インポートエラー: {e})")
        missing_modules.append("PowerShellBridge")
    
    # テストファイルの存在確認
    test_dir = project_root / "Tests" / "compatibility"
    if test_dir.exists():
        print(f"   ✅ テストディレクトリ: {test_dir}")
    else:
        print(f"   ❌ テストディレクトリが見つかりません: {test_dir}")
        missing_modules.append("test_directory")
    
    if missing_modules:
        print(f"\n❌ 不足している要素: {', '.join(missing_modules)}")
        return False
    
    print("   ✅ 全ての前提条件が満たされています")
    return True


def main():
    """メインエントリーポイント"""
    if len(sys.argv) > 1:
        if "--help" in sys.argv or "-h" in sys.argv:
            list_available_tests()
            return 0
        elif "--list" in sys.argv:
            list_available_tests()
            return 0
        elif "--check" in sys.argv:
            if check_prerequisites():
                print("\n🎉 前提条件チェック完了: テスト実行可能です")
                return 0
            else:
                print("\n❌ 前提条件チェック失敗: 問題を解決してください")
                return 1
    
    # 前提条件チェック
    if not check_prerequisites():
        print("\n❌ 前提条件が満たされていません")
        return 1
    
    print()
    
    # テスト実行
    return run_powershell_bridge_tests()


if __name__ == "__main__":
    sys.exit(main())