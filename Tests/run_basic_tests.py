#!/usr/bin/env python3
"""
基本的なテスト実行スクリプト

pytest がインストールされていない環境でも動作する
基本的なテストランナーです。
"""

import os
import sys
import importlib.util
import traceback
from pathlib import Path

# プロジェクトルートを追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

class BasicTestRunner:
    """基本的なテストランナー"""
    
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []
    
    def run_test_module(self, module_path):
        """テストモジュールの実行"""
        try:
            spec = importlib.util.spec_from_file_location("test_module", module_path)
            test_module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(test_module)
            
            # テストクラスの検索と実行
            for name in dir(test_module):
                obj = getattr(test_module, name)
                if isinstance(obj, type) and name.startswith('Test'):
                    self.run_test_class(obj, name)
                    
        except Exception as e:
            self.errors.append(f"モジュール {module_path} の読み込みエラー: {e}")
            print(f"ERROR: {e}")
    
    def run_test_class(self, test_class, class_name):
        """テストクラスの実行"""
        try:
            instance = test_class()
            
            # テストメソッドの検索と実行
            for method_name in dir(instance):
                if method_name.startswith('test_'):
                    self.run_test_method(instance, method_name, class_name)
                    
        except Exception as e:
            self.errors.append(f"テストクラス {class_name} のインスタンス化エラー: {e}")
            print(f"ERROR: {e}")
    
    def run_test_method(self, instance, method_name, class_name):
        """テストメソッドの実行"""
        try:
            method = getattr(instance, method_name)
            method()
            self.passed += 1
            print(f"PASS: {class_name}.{method_name}")
            
        except AssertionError as e:
            self.failed += 1
            error_msg = f"FAIL: {class_name}.{method_name} - {e}"
            self.errors.append(error_msg)
            print(error_msg)
            
        except Exception as e:
            self.failed += 1
            error_msg = f"ERROR: {class_name}.{method_name} - {e}"
            self.errors.append(error_msg)
            print(error_msg)
    
    def run_all_tests(self):
        """全テストの実行"""
        test_dirs = [
            project_root / "tests" / "unit",
            project_root / "tests" / "integration",
            project_root / "tests" / "regression"
        ]
        
        for test_dir in test_dirs:
            if test_dir.exists():
                print(f"\n=== {test_dir.name} テスト実行 ===")
                for test_file in test_dir.glob("test_*.py"):
                    print(f"\n実行中: {test_file.name}")
                    self.run_test_module(test_file)
    
    def print_summary(self):
        """テスト結果サマリーの出力"""
        total = self.passed + self.failed
        pass_rate = (self.passed / total * 100) if total > 0 else 0
        
        print(f"\n{'='*60}")
        print(f"テスト結果サマリー")
        print(f"{'='*60}")
        print(f"実行テスト数: {total}")
        print(f"成功: {self.passed}")
        print(f"失敗: {self.failed}")
        print(f"成功率: {pass_rate:.1f}%")
        
        if self.errors:
            print(f"\n失敗したテスト:")
            for error in self.errors:
                print(f"  - {error}")
        
        return pass_rate


def main():
    """メイン実行関数"""
    print("基本的なテストランナー開始")
    print(f"プロジェクトルート: {project_root}")
    
    runner = BasicTestRunner()
    runner.run_all_tests()
    pass_rate = runner.print_summary()
    
    # カバレッジ情報（簡易版）
    print(f"\n{'='*60}")
    print("カバレッジ情報（簡易版）")
    print(f"{'='*60}")
    
    # srcディレクトリのPythonファイル数をカウント
    src_dir = project_root / "src"
    if src_dir.exists():
        python_files = list(src_dir.glob("**/*.py"))
        print(f"srcディレクトリのPythonファイル数: {len(python_files)}")
        
        # 各ファイルの確認
        for py_file in python_files:
            rel_path = py_file.relative_to(project_root)
            print(f"  - {rel_path}")
    
    # テストディレクトリのファイル数をカウント
    test_dir = project_root / "tests"
    if test_dir.exists():
        test_files = list(test_dir.glob("**/*.py"))
        print(f"testsディレクトリのPythonファイル数: {len(test_files)}")
    
    # 簡易カバレッジ計算
    if src_dir.exists() and test_dir.exists():
        src_files = len(list(src_dir.glob("**/*.py")))
        test_files = len(list(test_dir.glob("**/test_*.py")))
        
        if src_files > 0:
            coverage_estimate = min(100, (test_files / src_files) * 100)
            print(f"推定カバレッジ: {coverage_estimate:.1f}%")
    
    return 0 if pass_rate >= 90 else 1


if __name__ == "__main__":
    exit(main())