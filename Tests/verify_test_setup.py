#!/usr/bin/env python3
"""
テストセットアップ検証スクリプト
PowerShellBridge互換性テストの設定が正しいかチェック
"""

import sys
import os
from pathlib import Path

# プロジェクトルートをパスに追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

def check_test_files():
    """テストファイルの存在確認"""
    print("📋 テストファイル確認:")
    
    test_dir = project_root / "Tests" / "compatibility"
    test_files = [
        "test_powershell_bridge.py",
        "test_data_format_compatibility.py",
        "test_advanced_scenarios.py",
        "conftest.py"
    ]
    
    all_exist = True
    for test_file in test_files:
        file_path = test_dir / test_file
        if file_path.exists():
            size = file_path.stat().st_size
            print(f"  ✅ {test_file} ({size:,} bytes)")
        else:
            print(f"  ❌ {test_file} (見つかりません)")
            all_exist = False
    
    return all_exist

def check_powershell_bridge():
    """PowerShellBridgeモジュールの確認"""
    print("\n🔌 PowerShellBridgeモジュール確認:")
    
    try:
        from src.core.powershell_bridge import PowerShellBridge, PowerShellResult
        print("  ✅ PowerShellBridge インポート成功")
        
        # 基本的な初期化テスト
        try:
            bridge = PowerShellBridge(project_root=project_root)
            print("  ✅ PowerShellBridge 初期化成功")
            
            # 基本的なメソッドの存在確認
            methods = ['execute_command', 'import_module', 'call_function', 'get_users']
            for method in methods:
                if hasattr(bridge, method):
                    print(f"  ✅ {method} メソッド存在")
                else:
                    print(f"  ❌ {method} メソッド不存在")
                    
        except Exception as e:
            print(f"  ❌ PowerShellBridge 初期化エラー: {e}")
            return False
            
    except ImportError as e:
        print(f"  ❌ PowerShellBridge インポートエラー: {e}")
        return False
    
    return True

def check_test_structure():
    """テスト構造の確認"""
    print("\n📁 テスト構造確認:")
    
    test_dir = project_root / "Tests"
    if test_dir.exists():
        print(f"  ✅ Testsディレクトリ: {test_dir}")
    else:
        print(f"  ❌ Testsディレクトリが見つかりません: {test_dir}")
        return False
    
    compatibility_dir = test_dir / "compatibility"
    if compatibility_dir.exists():
        print(f"  ✅ compatibilityディレクトリ: {compatibility_dir}")
    else:
        print(f"  ❌ compatibilityディレクトリが見つかりません: {compatibility_dir}")
        return False
    
    # テストランナーの確認
    runners = [
        "run_powershell_bridge_tests.py",
        "run_compatibility_tests.py"
    ]
    
    for runner in runners:
        runner_path = test_dir / runner
        if runner_path.exists():
            print(f"  ✅ {runner}")
        else:
            print(f"  ❌ {runner} (見つかりません)")
    
    return True

def parse_test_file(file_path):
    """テストファイルを解析"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # テストクラスとメソッドをカウント
        test_classes = content.count('class Test')
        test_methods = content.count('def test_')
        fixtures = content.count('@pytest.fixture')
        
        return {
            'test_classes': test_classes,
            'test_methods': test_methods,
            'fixtures': fixtures,
            'lines': len(content.splitlines())
        }
    except Exception as e:
        return {'error': str(e)}

def generate_test_summary():
    """テストサマリーを生成"""
    print("\n📊 テストサマリー:")
    
    test_dir = project_root / "Tests" / "compatibility"
    test_files = [
        "test_powershell_bridge.py",
        "test_data_format_compatibility.py",
        "test_advanced_scenarios.py"
    ]
    
    total_classes = 0
    total_methods = 0
    total_fixtures = 0
    
    for test_file in test_files:
        file_path = test_dir / test_file
        if file_path.exists():
            stats = parse_test_file(file_path)
            if 'error' not in stats:
                total_classes += stats['test_classes']
                total_methods += stats['test_methods']
                total_fixtures += stats['fixtures']
                
                print(f"  📄 {test_file}:")
                print(f"    - テストクラス: {stats['test_classes']}")
                print(f"    - テストメソッド: {stats['test_methods']}")
                print(f"    - フィクスチャー: {stats['fixtures']}")
                print(f"    - 行数: {stats['lines']}")
            else:
                print(f"  ❌ {test_file}: {stats['error']}")
    
    print(f"\n  📈 合計:")
    print(f"    - テストクラス: {total_classes}")
    print(f"    - テストメソッド: {total_methods}")
    print(f"    - フィクスチャー: {total_fixtures}")

def main():
    """メイン関数"""
    print("🔍 PowerShellBridge互換性テストセットアップ検証")
    print("=" * 60)
    
    checks = [
        check_test_files,
        check_powershell_bridge,
        check_test_structure
    ]
    
    all_passed = True
    for check in checks:
        if not check():
            all_passed = False
    
    generate_test_summary()
    
    print("\n" + "=" * 60)
    if all_passed:
        print("✅ 全てのチェックが成功しました！")
        print("🚀 テストの実行準備が整いました。")
        print("\n実行コマンド:")
        print("  python3 Tests/run_powershell_bridge_tests.py")
        return 0
    else:
        print("❌ 一部のチェックが失敗しました。")
        print("🔧 問題を解決してから再度実行してください。")
        return 1

if __name__ == "__main__":
    sys.exit(main())