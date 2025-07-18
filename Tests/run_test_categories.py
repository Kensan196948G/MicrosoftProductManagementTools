#!/usr/bin/env python3
"""
テストカテゴリ別実行スクリプト

このスクリプトは、特定のカテゴリのテストを簡単に実行するための
ヘルパースクリプトです。
"""

import sys
import subprocess
import argparse
from pathlib import Path
from typing import List, Optional

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent


class TestRunner:
    """テスト実行ヘルパークラス"""
    
    def __init__(self):
        self.test_categories = {
            "unit": "ユニットテスト（単体テスト）",
            "integration": "統合テスト",
            "compatibility": "PowerShell互換性テスト",
            "gui": "GUIテスト",
            "api": "APIテスト",
            "performance": "パフォーマンステスト",
            "security": "セキュリティテスト",
            "all": "全てのテスト"
        }
    
    def run_tests(self, category: str, options: Optional[List[str]] = None) -> int:
        """指定されたカテゴリのテストを実行"""
        if category not in self.test_categories:
            print(f"エラー: 不明なカテゴリ '{category}'")
            self.show_categories()
            return 1
        
        # 基本コマンド
        cmd = [sys.executable, "-m", "pytest"]
        
        # カテゴリ別の設定
        if category == "all":
            cmd.extend(["-v"])
        else:
            cmd.extend(["-m", category, "-v"])
        
        # カバレッジオプション
        if category in ["unit", "all"]:
            cmd.extend(["--cov=src", "--cov-report=term-missing"])
        
        # 追加オプション
        if options:
            cmd.extend(options)
        
        # 実行
        print(f"\n🚀 {self.test_categories[category]}を実行中...")
        print(f"コマンド: {' '.join(cmd)}\n")
        
        return subprocess.run(cmd, cwd=PROJECT_ROOT).returncode
    
    def run_quick_tests(self) -> int:
        """クイックテスト（高速なテストのみ）"""
        print("\n⚡ クイックテストを実行中...")
        cmd = [
            sys.executable, "-m", "pytest",
            "-m", "not slow and not requires_auth and not requires_powershell",
            "-v", "--tb=short"
        ]
        return subprocess.run(cmd, cwd=PROJECT_ROOT).returncode
    
    def run_ci_tests(self) -> int:
        """CI用テスト（認証不要、PowerShell不要）"""
        print("\n🤖 CI用テストを実行中...")
        cmd = [
            sys.executable, "-m", "pytest",
            "-m", "not requires_auth and not requires_powershell",
            "--cov=src", "--cov-report=xml",
            "--junit-xml=test-results.xml",
            "-v"
        ]
        return subprocess.run(cmd, cwd=PROJECT_ROOT).returncode
    
    def run_compatibility_check(self) -> int:
        """PowerShell互換性チェック"""
        print("\n🔄 PowerShell互換性チェックを実行中...")
        
        # PowerShell利用可能性チェック
        try:
            result = subprocess.run(
                ["pwsh", "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode != 0:
                print("❌ PowerShellが利用できません。互換性テストをスキップします。")
                return 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print("❌ PowerShellが利用できません。互換性テストをスキップします。")
            return 0
        
        cmd = [
            sys.executable, "-m", "pytest",
            "-m", "compatibility",
            "-v", "--tb=short"
        ]
        return subprocess.run(cmd, cwd=PROJECT_ROOT).returncode
    
    def show_categories(self):
        """利用可能なカテゴリを表示"""
        print("\n利用可能なテストカテゴリ:")
        for key, description in self.test_categories.items():
            print(f"  {key:<15} - {description}")
    
    def generate_coverage_report(self) -> int:
        """カバレッジレポート生成"""
        print("\n📊 カバレッジレポートを生成中...")
        cmd = [
            sys.executable, "-m", "pytest",
            "--cov=src", "--cov-report=html:htmlcov",
            "--cov-report=term-missing",
            "-v"
        ]
        result = subprocess.run(cmd, cwd=PROJECT_ROOT).returncode
        
        if result == 0:
            print("\n✅ カバレッジレポートが生成されました: htmlcov/index.html")
        
        return result


def main():
    """メインエントリーポイント"""
    parser = argparse.ArgumentParser(
        description="Microsoft 365管理ツール テスト実行ヘルパー"
    )
    
    parser.add_argument(
        "category",
        nargs="?",
        default="unit",
        help="実行するテストカテゴリ"
    )
    
    parser.add_argument(
        "--quick", "-q",
        action="store_true",
        help="クイックテストを実行（高速なテストのみ）"
    )
    
    parser.add_argument(
        "--ci",
        action="store_true",
        help="CI用テストを実行（認証・PowerShell不要）"
    )
    
    parser.add_argument(
        "--compat", "-c",
        action="store_true",
        help="PowerShell互換性チェックを実行"
    )
    
    parser.add_argument(
        "--coverage",
        action="store_true",
        help="カバレッジレポートを生成"
    )
    
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="利用可能なカテゴリを表示"
    )
    
    parser.add_argument(
        "--parallel", "-n",
        type=str,
        metavar="NUM",
        help="並列実行（auto, 数値を指定）"
    )
    
    parser.add_argument(
        "--verbose", "-v",
        action="count",
        default=0,
        help="詳細出力（-vvで最大）"
    )
    
    parser.add_argument(
        "--pdb",
        action="store_true",
        help="失敗時にデバッガを起動"
    )
    
    args = parser.parse_args()
    runner = TestRunner()
    
    # カテゴリ一覧表示
    if args.list:
        runner.show_categories()
        return 0
    
    # 追加オプション構築
    extra_options = []
    if args.parallel:
        extra_options.extend(["-n", args.parallel])
    if args.verbose:
        extra_options.extend(["-" + "v" * args.verbose])
    if args.pdb:
        extra_options.append("--pdb")
    
    # 実行モード選択
    if args.quick:
        return runner.run_quick_tests()
    elif args.ci:
        return runner.run_ci_tests()
    elif args.compat:
        return runner.run_compatibility_check()
    elif args.coverage:
        return runner.generate_coverage_report()
    else:
        return runner.run_tests(args.category, extra_options)


if __name__ == "__main__":
    sys.exit(main())