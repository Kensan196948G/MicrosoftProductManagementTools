"""
pytest テストスイート実行・レポート生成ツール
Dev1 - Test/QA Developer による基盤構築

テスト実行、カバレッジ分析、レポート生成の統合ツール
"""
import os
import sys
import subprocess
import json
import shutil
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
import asyncio

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))


class PytestTestRunner:
    """pytestテストランナー"""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.tests_dir = project_root / "tests"
        self.reports_dir = project_root / "TestScripts" / "TestReports"
        self.coverage_dir = project_root / "htmlcov"
        
        # レポート出力ディレクトリ準備
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        
        # タイムスタンプ
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 実行結果保存
        self.test_results = {}
        self.execution_summary = {}
    
    def run_unit_tests(self, verbose: bool = True) -> Dict[str, Any]:
        """ユニットテスト実行"""
        print("🧪 ユニットテスト実行中...")
        
        cmd = [
            "python", "-m", "pytest",
            str(self.tests_dir / "unit"),
            "-v" if verbose else "",
            "--tb=short",
            "--junitxml=" + str(self.reports_dir / f"unit-test-results_{self.timestamp}.xml"),
            "--html=" + str(self.reports_dir / f"unit-test-report_{self.timestamp}.html"),
            "--self-contained-html",
            "--cov=src",
            "--cov-report=html:" + str(self.coverage_dir),
            "--cov-report=xml:" + str(self.reports_dir / f"unit-coverage_{self.timestamp}.xml"),
            "--cov-report=json:" + str(self.reports_dir / f"unit-coverage_{self.timestamp}.json"),
            "-m", "unit"
        ]
        
        # 空文字列要素を除去
        cmd = [arg for arg in cmd if arg]
        
        try:
            result = subprocess.run(
                cmd,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=600  # 10分タイムアウト
            )
            
            test_result = {
                "category": "unit",
                "exit_code": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "success": result.returncode == 0,
                "timestamp": datetime.now().isoformat(),
                "duration": self._extract_duration_from_output(result.stdout)
            }
            
            self.test_results["unit"] = test_result
            return test_result
            
        except subprocess.TimeoutExpired:
            test_result = {
                "category": "unit",
                "exit_code": -1,
                "stdout": "",
                "stderr": "ユニットテスト実行がタイムアウトしました (10分)",
                "success": False,
                "timestamp": datetime.now().isoformat(),
                "duration": 600.0
            }
            self.test_results["unit"] = test_result
            return test_result
    
    def run_integration_tests(self, verbose: bool = True) -> Dict[str, Any]:
        """統合テスト実行"""
        print("🔗 統合テスト実行中...")
        
        cmd = [
            "python", "-m", "pytest",
            str(self.tests_dir / "integration"),
            "-v" if verbose else "",
            "--tb=short",
            "--junitxml=" + str(self.reports_dir / f"integration-test-results_{self.timestamp}.xml"),
            "--html=" + str(self.reports_dir / f"integration-test-report_{self.timestamp}.html"),
            "--self-contained-html",
            "-m", "integration"
        ]
        
        cmd = [arg for arg in cmd if arg]
        
        try:
            result = subprocess.run(
                cmd,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=900  # 15分タイムアウト
            )
            
            test_result = {
                "category": "integration",
                "exit_code": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "success": result.returncode == 0,
                "timestamp": datetime.now().isoformat(),
                "duration": self._extract_duration_from_output(result.stdout)
            }
            
            self.test_results["integration"] = test_result
            return test_result
            
        except subprocess.TimeoutExpired:
            test_result = {
                "category": "integration",
                "exit_code": -1,
                "stdout": "",
                "stderr": "統合テスト実行がタイムアウトしました (15分)",
                "success": False,
                "timestamp": datetime.now().isoformat(),
                "duration": 900.0
            }
            self.test_results["integration"] = test_result
            return test_result
    
    def run_compatibility_tests(self, verbose: bool = True, 
                               skip_powershell: bool = False) -> Dict[str, Any]:
        """互換性テスト実行"""
        print("🤝 互換性テスト実行中...")
        
        markers = ["compatibility"]
        if skip_powershell:
            markers.append("not requires_powershell")
        
        cmd = [
            "python", "-m", "pytest",
            str(self.tests_dir / "compatibility"),
            "-v" if verbose else "",
            "--tb=short",
            "--junitxml=" + str(self.reports_dir / f"compatibility-test-results_{self.timestamp}.xml"),
            "--html=" + str(self.reports_dir / f"compatibility-test-report_{self.timestamp}.html"),
            "--self-contained-html",
            "-m", " and ".join(markers)
        ]
        
        cmd = [arg for arg in cmd if arg]
        
        try:
            result = subprocess.run(
                cmd,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=1200  # 20分タイムアウト
            )
            
            test_result = {
                "category": "compatibility",
                "exit_code": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "success": result.returncode == 0,
                "timestamp": datetime.now().isoformat(),
                "duration": self._extract_duration_from_output(result.stdout),
                "skipped_powershell": skip_powershell
            }
            
            self.test_results["compatibility"] = test_result
            return test_result
            
        except subprocess.TimeoutExpired:
            test_result = {
                "category": "compatibility",
                "exit_code": -1,
                "stdout": "",
                "stderr": "互換性テスト実行がタイムアウトしました (20分)",
                "success": False,
                "timestamp": datetime.now().isoformat(),
                "duration": 1200.0,
                "skipped_powershell": skip_powershell
            }
            self.test_results["compatibility"] = test_result
            return test_result
    
    def run_gui_tests(self, verbose: bool = True) -> Dict[str, Any]:
        """GUIテスト実行"""
        print("🖥️ GUIテスト実行中...")
        
        cmd = [
            "python", "-m", "pytest",
            str(self.tests_dir),
            "-v" if verbose else "",
            "--tb=short",
            "--junitxml=" + str(self.reports_dir / f"gui-test-results_{self.timestamp}.xml"),
            "--html=" + str(self.reports_dir / f"gui-test-report_{self.timestamp}.html"),
            "--self-contained-html",
            "-m", "gui"
        ]
        
        cmd = [arg for arg in cmd if arg]
        
        try:
            result = subprocess.run(
                cmd,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=600  # 10分タイムアウト
            )
            
            test_result = {
                "category": "gui",
                "exit_code": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "success": result.returncode == 0,
                "timestamp": datetime.now().isoformat(),
                "duration": self._extract_duration_from_output(result.stdout)
            }
            
            self.test_results["gui"] = test_result
            return test_result
            
        except subprocess.TimeoutExpired:
            test_result = {
                "category": "gui",
                "exit_code": -1,
                "stdout": "",
                "stderr": "GUIテスト実行がタイムアウトしました (10分)",
                "success": False,
                "timestamp": datetime.now().isoformat(),
                "duration": 600.0
            }
            self.test_results["gui"] = test_result
            return test_result
    
    def run_all_tests(self, verbose: bool = True, 
                     skip_powershell: bool = False,
                     skip_gui: bool = False) -> Dict[str, Any]:
        """全テスト実行"""
        print("🚀 全テストスイート実行開始...")
        start_time = datetime.now()
        
        # 各カテゴリのテスト実行
        results = {}
        
        # ユニットテスト
        results["unit"] = self.run_unit_tests(verbose)
        
        # 統合テスト
        results["integration"] = self.run_integration_tests(verbose)
        
        # 互換性テスト
        results["compatibility"] = self.run_compatibility_tests(verbose, skip_powershell)
        
        # GUIテスト（オプション）
        if not skip_gui:
            results["gui"] = self.run_gui_tests(verbose)
        
        end_time = datetime.now()
        total_duration = (end_time - start_time).total_seconds()
        
        # 実行サマリー生成
        self.execution_summary = {
            "start_time": start_time.isoformat(),
            "end_time": end_time.isoformat(),
            "total_duration": total_duration,
            "categories_run": list(results.keys()),
            "overall_success": all(r["success"] for r in results.values()),
            "total_tests": sum(self._extract_test_count(r["stdout"]) for r in results.values()),
            "failed_tests": sum(self._extract_failed_count(r["stdout"]) for r in results.values()),
            "skipped_options": {
                "powershell": skip_powershell,
                "gui": skip_gui
            }
        }
        
        self.test_results = results
        return results
    
    def generate_comprehensive_report(self) -> Path:
        """包括的テストレポート生成"""
        print("📊 包括的テストレポート生成中...")
        
        report_file = self.reports_dir / f"comprehensive-test-report_{self.timestamp}.html"
        
        html_content = self._generate_html_report()
        
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(html_content)
        
        # CSV版も生成
        csv_file = self.reports_dir / f"comprehensive-test-summary_{self.timestamp}.csv"
        csv_content = self._generate_csv_summary()
        
        with open(csv_file, "w", encoding="utf-8-sig") as f:
            f.write(csv_content)
        
        # JSON版も生成
        json_file = self.reports_dir / f"comprehensive-test-data_{self.timestamp}.json"
        json_data = {
            "execution_summary": self.execution_summary,
            "test_results": self.test_results,
            "generated_at": datetime.now().isoformat(),
            "project_root": str(self.project_root)
        }
        
        with open(json_file, "w", encoding="utf-8") as f:
            json.dump(json_data, f, indent=2, ensure_ascii=False)
        
        print(f"✅ レポート生成完了:")
        print(f"  HTML: {report_file}")
        print(f"  CSV:  {csv_file}")
        print(f"  JSON: {json_file}")
        
        return report_file
    
    def _generate_html_report(self) -> str:
        """HTMLレポート生成"""
        summary = self.execution_summary
        results = self.test_results
        
        # 成功率計算
        total_categories = len(results)
        successful_categories = sum(1 for r in results.values() if r["success"])
        success_rate = (successful_categories / total_categories * 100) if total_categories > 0 else 0
        
        html = f"""
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365管理ツール - 包括的テストレポート</title>
    <style>
        body {{
            font-family: 'Meiryo', 'MS Gothic', sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1, h2 {{
            color: #2E8B57;
            border-bottom: 2px solid #2E8B57;
            padding-bottom: 10px;
        }}
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }}
        .summary-card {{
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #2E8B57;
        }}
        .summary-card h3 {{
            margin: 0 0 10px 0;
            color: #333;
        }}
        .summary-card .value {{
            font-size: 24px;
            font-weight: bold;
            color: #2E8B57;
        }}
        .test-category {{
            margin: 30px 0;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 8px;
        }}
        .test-category.success {{
            border-left: 4px solid #28a745;
            background-color: #d4edda;
        }}
        .test-category.failure {{
            border-left: 4px solid #dc3545;
            background-color: #f8d7da;
        }}
        .test-details {{
            background: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            margin-top: 10px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 12px;
            white-space: pre-wrap;
            max-height: 300px;
            overflow-y: auto;
        }}
        .progress-bar {{
            width: 100%;
            height: 20px;
            background-color: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }}
        .progress-fill {{
            height: 100%;
            background-color: {('#28a745' if success_rate >= 80 else '#ffc107' if success_rate >= 60 else '#dc3545')};
            transition: width 0.5s ease;
        }}
        .timestamp {{
            color: #6c757d;
            font-size: 12px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }}
        th {{
            background-color: #2E8B57;
            color: white;
        }}
        .status-success {{
            color: #28a745;
            font-weight: bold;
        }}
        .status-failure {{
            color: #dc3545;
            font-weight: bold;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🧪 Microsoft 365管理ツール - 包括的テストレポート</h1>
        
        <div class="timestamp">
            レポート生成日時: {datetime.now().strftime("%Y年%m月%d日 %H:%M:%S")}<br>
            テスト実行期間: {summary.get('start_time', 'N/A')} ～ {summary.get('end_time', 'N/A')}<br>
            総実行時間: {summary.get('total_duration', 0):.1f}秒
        </div>
        
        <h2>📈 実行サマリー</h2>
        <div class="summary-grid">
            <div class="summary-card">
                <h3>総合成功率</h3>
                <div class="value">{success_rate:.1f}%</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {success_rate}%"></div>
                </div>
            </div>
            <div class="summary-card">
                <h3>実行カテゴリ数</h3>
                <div class="value">{total_categories}</div>
            </div>
            <div class="summary-card">
                <h3>成功カテゴリ数</h3>
                <div class="value">{successful_categories}</div>
            </div>
            <div class="summary-card">
                <h3>総テスト数</h3>
                <div class="value">{summary.get('total_tests', 0)}</div>
            </div>
        </div>
        
        <h2>📋 カテゴリ別テスト結果</h2>
        <table>
            <thead>
                <tr>
                    <th>カテゴリ</th>
                    <th>ステータス</th>
                    <th>実行時間</th>
                    <th>終了コード</th>
                    <th>実行時刻</th>
                </tr>
            </thead>
            <tbody>
"""
        
        # 各カテゴリの結果をテーブルに追加
        for category, result in results.items():
            status_class = "status-success" if result["success"] else "status-failure"
            status_text = "✅ 成功" if result["success"] else "❌ 失敗"
            
            html += f"""
                <tr>
                    <td>{category.upper()}</td>
                    <td class="{status_class}">{status_text}</td>
                    <td>{result.get('duration', 0):.1f}秒</td>
                    <td>{result.get('exit_code', 'N/A')}</td>
                    <td>{result.get('timestamp', 'N/A')}</td>
                </tr>
"""
        
        html += """
            </tbody>
        </table>
        
        <h2>🔍 詳細テスト結果</h2>
"""
        
        # 各カテゴリの詳細結果
        for category, result in results.items():
            category_class = "success" if result["success"] else "failure"
            status_icon = "✅" if result["success"] else "❌"
            
            html += f"""
        <div class="test-category {category_class}">
            <h3>{status_icon} {category.upper()} テスト</h3>
            <p><strong>ステータス:</strong> {'成功' if result["success"] else '失敗'}</p>
            <p><strong>実行時間:</strong> {result.get('duration', 0):.1f}秒</p>
            <p><strong>終了コード:</strong> {result.get('exit_code', 'N/A')}</p>
            
            <details>
                <summary>標準出力</summary>
                <div class="test-details">{result.get('stdout', 'N/A')}</div>
            </details>
            
            <details>
                <summary>エラー出力</summary>
                <div class="test-details">{result.get('stderr', 'N/A')}</div>
            </details>
        </div>
"""
        
        html += f"""
        
        <h2>⚙️ 実行環境情報</h2>
        <table>
            <tr><th>項目</th><th>値</th></tr>
            <tr><td>プロジェクトルート</td><td>{self.project_root}</td></tr>
            <tr><td>Python実行環境</td><td>{sys.executable}</td></tr>
            <tr><td>Python バージョン</td><td>{sys.version}</td></tr>
            <tr><td>プラットフォーム</td><td>{sys.platform}</td></tr>
            <tr><td>PowerShell スキップ</td><td>{'はい' if summary.get('skipped_options', {}).get('powershell', False) else 'いいえ'}</td></tr>
            <tr><td>GUI テスト スキップ</td><td>{'はい' if summary.get('skipped_options', {}).get('gui', False) else 'いいえ'}</td></tr>
        </table>
        
        <footer style="margin-top: 50px; text-align: center; color: #6c757d; font-size: 12px;">
            <p>Microsoft 365管理ツール - pytest テストスイート</p>
            <p>Dev1 - Test/QA Developer による基盤構築</p>
        </footer>
    </div>
</body>
</html>
"""
        
        return html
    
    def _generate_csv_summary(self) -> str:
        """CSVサマリー生成"""
        summary = self.execution_summary
        results = self.test_results
        
        csv_lines = [
            "カテゴリ,ステータス,実行時間(秒),終了コード,実行時刻,テスト数,失敗数"
        ]
        
        for category, result in results.items():
            status = "成功" if result["success"] else "失敗"
            duration = result.get("duration", 0)
            exit_code = result.get("exit_code", "N/A")
            timestamp = result.get("timestamp", "N/A")
            test_count = self._extract_test_count(result.get("stdout", ""))
            failed_count = self._extract_failed_count(result.get("stdout", ""))
            
            csv_lines.append(f"{category},{status},{duration},{exit_code},{timestamp},{test_count},{failed_count}")
        
        # サマリー行追加
        total_duration = summary.get("total_duration", 0)
        total_tests = summary.get("total_tests", 0)
        failed_tests = summary.get("failed_tests", 0)
        overall_status = "成功" if summary.get("overall_success", False) else "失敗"
        
        csv_lines.append("")
        csv_lines.append("総合サマリー")
        csv_lines.append(f"全体,{overall_status},{total_duration},N/A,{summary.get('end_time', 'N/A')},{total_tests},{failed_tests}")
        
        return "\n".join(csv_lines)
    
    def _extract_duration_from_output(self, output: str) -> float:
        """出力からテスト実行時間を抽出"""
        import re
        
        # pytest の実行時間パターンを検索
        patterns = [
            r"=+ (.+) in ([\d.]+)s =+",
            r"=+ .+ in ([\d.]+) seconds =+",
            r"([\d.]+)s",
        ]
        
        for pattern in patterns:
            match = re.search(pattern, output)
            if match:
                try:
                    return float(match.group(-1))  # 最後のグループ（時間）
                except (ValueError, IndexError):
                    continue
        
        return 0.0
    
    def _extract_test_count(self, output: str) -> int:
        """出力からテスト数を抽出"""
        import re
        
        patterns = [
            r"(\d+) passed",
            r"(\d+) failed",
            r"(\d+) error",
            r"collected (\d+) item"
        ]
        
        total_count = 0
        for pattern in patterns:
            matches = re.findall(pattern, output)
            for match in matches:
                try:
                    total_count += int(match)
                except ValueError:
                    continue
        
        return total_count
    
    def _extract_failed_count(self, output: str) -> int:
        """出力から失敗テスト数を抽出"""
        import re
        
        patterns = [
            r"(\d+) failed",
            r"(\d+) error"
        ]
        
        failed_count = 0
        for pattern in patterns:
            matches = re.findall(pattern, output)
            for match in matches:
                try:
                    failed_count += int(match)
                except ValueError:
                    continue
        
        return failed_count


def main():
    """メイン実行関数"""
    parser = argparse.ArgumentParser(description="Microsoft 365管理ツール pytest テストスイート実行")
    
    parser.add_argument("--category", choices=["unit", "integration", "compatibility", "gui", "all"],
                       default="all", help="実行するテストカテゴリ")
    parser.add_argument("--verbose", "-v", action="store_true", help="詳細出力")
    parser.add_argument("--skip-powershell", action="store_true", 
                       help="PowerShell実行が必要なテストをスキップ")
    parser.add_argument("--skip-gui", action="store_true", help="GUIテストをスキップ")
    parser.add_argument("--report-only", action="store_true", 
                       help="既存の結果からレポートのみ生成")
    
    args = parser.parse_args()
    
    # テストランナー初期化
    runner = PytestTestRunner(PROJECT_ROOT)
    
    print("🧪 Microsoft 365管理ツール - pytest テストスイート")
    print("=" * 60)
    
    if not args.report_only:
        # テスト実行
        if args.category == "all":
            runner.run_all_tests(
                verbose=args.verbose,
                skip_powershell=args.skip_powershell,
                skip_gui=args.skip_gui
            )
        elif args.category == "unit":
            runner.run_unit_tests(args.verbose)
        elif args.category == "integration":
            runner.run_integration_tests(args.verbose)
        elif args.category == "compatibility":
            runner.run_compatibility_tests(args.verbose, args.skip_powershell)
        elif args.category == "gui":
            runner.run_gui_tests(args.verbose)
        
        # 結果表示
        print("\n" + "=" * 60)
        print("📊 テスト実行結果サマリー")
        print("=" * 60)
        
        for category, result in runner.test_results.items():
            status = "✅ 成功" if result["success"] else "❌ 失敗"
            duration = result.get("duration", 0)
            print(f"{category.upper():15} : {status} ({duration:.1f}秒)")
        
        if runner.execution_summary:
            overall_status = "✅ 成功" if runner.execution_summary["overall_success"] else "❌ 失敗"
            total_duration = runner.execution_summary["total_duration"]
            print(f"{'総合':15} : {overall_status} ({total_duration:.1f}秒)")
    
    # レポート生成
    report_file = runner.generate_comprehensive_report()
    
    print("\n" + "=" * 60)
    print("✅ テストスイート実行完了")
    print(f"📄 詳細レポート: {report_file}")
    print("=" * 60)
    
    return runner.execution_summary.get("overall_success", False) if runner.execution_summary else True


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)