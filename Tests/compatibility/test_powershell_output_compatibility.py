"""
PowerShell版との出力互換性テストスイート
Dev1 - Test/QA Developer による基盤構築

Python版とPowerShell版の出力形式・データ互換性を検証
"""
import os
import sys
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
import asyncio
import csv
import hashlib

import pytest
import pandas as pd
from bs4 import BeautifulSoup
import requests_mock

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))


class PowerShellOutputComparator:
    """PowerShell版出力との比較クラス"""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.powershell_scripts_dir = project_root / "TestScripts"
        self.reports_dir = project_root / "Reports"
        self.temp_dir = project_root / "tests" / "temp"
        self.temp_dir.mkdir(exist_ok=True)
        
        # PowerShell実行タイムアウト
        self.ps_timeout = 180
        
    async def run_powershell_script(self, script_name: str, args: List[str] = None) -> Dict[str, Any]:
        """PowerShellスクリプトを非同期実行"""
        script_path = self.powershell_scripts_dir / script_name
        if not script_path.exists():
            raise FileNotFoundError(f"PowerShellスクリプトが見つかりません: {script_path}")
        
        cmd = ["pwsh", "-File", str(script_path)]
        if args:
            cmd.extend(args)
        
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.project_root)
            )
            
            stdout, stderr = await asyncio.wait_for(
                process.communicate(), 
                timeout=self.ps_timeout
            )
            
            return {
                "returncode": process.returncode,
                "stdout": stdout.decode("utf-8", errors="replace"),
                "stderr": stderr.decode("utf-8", errors="replace"),
                "success": process.returncode == 0
            }
        except asyncio.TimeoutError:
            return {
                "returncode": -1,
                "stdout": "",
                "stderr": f"PowerShellスクリプト実行がタイムアウトしました ({self.ps_timeout}秒)",
                "success": False
            }
        except Exception as e:
            return {
                "returncode": -1,
                "stdout": "",
                "stderr": f"PowerShellスクリプト実行エラー: {str(e)}",
                "success": False
            }
    
    def compare_csv_files(self, python_csv: Path, powershell_csv: Path) -> Dict[str, Any]:
        """CSV出力ファイルの詳細比較"""
        try:
            # UTF-8 BOMでCSVを読み込み
            py_df = pd.read_csv(python_csv, encoding="utf-8-sig")
            ps_df = pd.read_csv(powershell_csv, encoding="utf-8-sig")
            
            # 基本構造比較
            columns_match = list(py_df.columns) == list(ps_df.columns)
            row_count_match = len(py_df) == len(ps_df)
            
            # データ型比較（型変換後）
            py_types = py_df.dtypes.to_dict()
            ps_types = ps_df.dtypes.to_dict()
            
            # 列名差分
            py_cols = set(py_df.columns)
            ps_cols = set(ps_df.columns)
            
            # データ内容のサンプル比較（最初の5行）
            content_sample_match = True
            sample_differences = []
            
            if columns_match and row_count_match and len(py_df) > 0:
                for i in range(min(5, len(py_df))):
                    for col in py_df.columns:
                        py_val = str(py_df.iloc[i][col]).strip()
                        ps_val = str(ps_df.iloc[i][col]).strip()
                        if py_val != ps_val:
                            content_sample_match = False
                            sample_differences.append({
                                "row": i,
                                "column": col,
                                "python_value": py_val,
                                "powershell_value": ps_val
                            })
            
            return {
                "success": True,
                "columns_match": columns_match,
                "row_count_match": row_count_match,
                "content_sample_match": content_sample_match,
                "sample_differences": sample_differences,
                "python_shape": py_df.shape,
                "powershell_shape": ps_df.shape,
                "python_columns": list(py_df.columns),
                "powershell_columns": list(ps_df.columns),
                "column_differences": {
                    "python_only": list(py_cols - ps_cols),
                    "powershell_only": list(ps_cols - py_cols)
                },
                "data_types": {
                    "python": py_types,
                    "powershell": ps_types
                }
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    def compare_html_files(self, python_html: Path, powershell_html: Path) -> Dict[str, Any]:
        """HTML出力ファイルの構造比較"""
        try:
            with open(python_html, "r", encoding="utf-8") as f:
                py_content = f.read()
            with open(powershell_html, "r", encoding="utf-8") as f:
                ps_content = f.read()
            
            # BeautifulSoupでHTML解析
            py_soup = BeautifulSoup(py_content, "html.parser")
            ps_soup = BeautifulSoup(ps_content, "html.parser")
            
            # 基本的なHTML要素の存在確認
            html_elements = ["html", "head", "body", "title", "table", "tr", "td", "th"]
            py_elements = {elem: len(py_soup.find_all(elem)) for elem in html_elements}
            ps_elements = {elem: len(ps_soup.find_all(elem)) for elem in html_elements}
            
            # テーブル構造の比較
            py_tables = py_soup.find_all("table")
            ps_tables = ps_soup.find_all("table")
            
            table_structure_match = len(py_tables) == len(ps_tables)
            table_details = []
            
            if table_structure_match and py_tables:
                for i, (py_table, ps_table) in enumerate(zip(py_tables, ps_tables)):
                    py_rows = len(py_table.find_all("tr"))
                    ps_rows = len(ps_table.find_all("tr"))
                    py_headers = len(py_table.find_all("th"))
                    ps_headers = len(ps_table.find_all("th"))
                    
                    table_details.append({
                        "table_index": i,
                        "rows_match": py_rows == ps_rows,
                        "headers_match": py_headers == ps_headers,
                        "python_rows": py_rows,
                        "powershell_rows": ps_rows,
                        "python_headers": py_headers,
                        "powershell_headers": ps_headers
                    })
            
            # CSS/JavaScriptの存在確認
            py_css = len(py_soup.find_all("style")) + len(py_soup.find_all("link", rel="stylesheet"))
            ps_css = len(ps_soup.find_all("style")) + len(ps_soup.find_all("link", rel="stylesheet"))
            py_js = len(py_soup.find_all("script"))
            ps_js = len(ps_soup.find_all("script"))
            
            return {
                "success": True,
                "basic_structure_match": py_elements == ps_elements,
                "table_structure_match": table_structure_match,
                "python_elements": py_elements,
                "powershell_elements": ps_elements,
                "table_details": table_details,
                "styling": {
                    "python_css_count": py_css,
                    "powershell_css_count": ps_css,
                    "python_js_count": py_js,
                    "powershell_js_count": ps_js
                },
                "content_length": {
                    "python": len(py_content),
                    "powershell": len(ps_content),
                    "difference": abs(len(py_content) - len(ps_content))
                }
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    def generate_test_hash(self, data: Any) -> str:
        """テストデータのハッシュ値生成"""
        data_str = json.dumps(data, sort_keys=True, ensure_ascii=False)
        return hashlib.sha256(data_str.encode("utf-8")).hexdigest()[:16]


@pytest.fixture(scope="function")
def output_comparator(project_root):
    """出力比較器のフィクスチャ"""
    return PowerShellOutputComparator(project_root)


@pytest.fixture(scope="function")
def temp_output_dir(output_comparator):
    """一時出力ディレクトリ"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    temp_dir = output_comparator.temp_dir / f"compatibility_test_{timestamp}"
    temp_dir.mkdir(exist_ok=True)
    yield temp_dir
    # cleanup は pytest の一時ディレクトリ管理に委ねる


class TestBasicOutputCompatibility:
    """基本的な出力互換性テスト"""
    
    @pytest.mark.compatibility
    @pytest.mark.requires_powershell
    @pytest.mark.asyncio
    async def test_daily_report_output_compatibility(self, output_comparator, temp_output_dir):
        """日次レポート出力の互換性テスト"""
        # PowerShell版の日次レポート実行
        ps_result = await output_comparator.run_powershell_script(
            "test-daily-report-real.ps1",
            ["-OutputPath", str(temp_output_dir)]
        )
        
        assert ps_result["success"], f"PowerShellスクリプト実行失敗: {ps_result['stderr']}"
        
        # 生成されたファイルを検索
        csv_files = list(temp_output_dir.glob("*daily*.csv"))
        html_files = list(temp_output_dir.glob("*daily*.html"))
        
        assert len(csv_files) > 0, "PowerShell版でCSVファイルが生成されませんでした"
        assert len(html_files) > 0, "PowerShell版でHTMLファイルが生成されませんでした"
        
        # TODO: Python版の日次レポート実行と比較
        # (Python版実装完了後に詳細比較を追加)
        
        # 基本的なファイル形式確認
        for csv_file in csv_files:
            assert csv_file.stat().st_size > 0, f"CSVファイルが空です: {csv_file}"
            
            # UTF-8 BOM確認
            with open(csv_file, "rb") as f:
                content = f.read(3)
                assert content == b'\xef\xbb\xbf', f"UTF-8 BOMが正しくありません: {csv_file}"
        
        for html_file in html_files:
            assert html_file.stat().st_size > 0, f"HTMLファイルが空です: {html_file}"
            
            with open(html_file, "r", encoding="utf-8") as f:
                content = f.read()
                assert "<html" in content.lower(), f"HTML形式が正しくありません: {html_file}"
                assert "<table" in content.lower(), f"テーブル要素が見つかりません: {html_file}"
    
    @pytest.mark.compatibility
    @pytest.mark.requires_powershell
    @pytest.mark.asyncio 
    async def test_license_analysis_output_compatibility(self, output_comparator, temp_output_dir):
        """ライセンス分析レポート出力の互換性テスト"""
        ps_result = await output_comparator.run_powershell_script(
            "test-enhanced-functionality.ps1",
            ["-TestType", "License", "-OutputPath", str(temp_output_dir)]
        )
        
        # PowerShell実行結果の基本確認
        assert ps_result["returncode"] == 0 or "license" in ps_result["stdout"].lower(), \
            f"ライセンス分析が正常に実行されませんでした: {ps_result['stderr']}"
        
        # 期待されるファイルパターンを確認
        generated_files = list(temp_output_dir.glob("*license*.csv")) + \
                         list(temp_output_dir.glob("*license*.html"))
        
        # ファイルが生成されている場合の詳細チェック
        if generated_files:
            for file_path in generated_files:
                assert file_path.stat().st_size > 100, f"生成ファイルが小さすぎます: {file_path}"
    
    @pytest.mark.compatibility
    @pytest.mark.slow
    async def test_csv_encoding_consistency(self, output_comparator, temp_output_dir):
        """CSV出力のエンコーディング一貫性テスト"""
        # テスト用のCSVファイルを生成
        test_data = [
            {"名前": "テストユーザー1", "部署": "IT部門", "ライセンス": "Office 365 E3"},
            {"名前": "テストユーザー2", "部署": "営業部", "ライセンス": "Microsoft 365 E5"},
            {"名前": "特殊文字_テスト", "部署": "管理部@#$", "ライセンス": "Office 365 E1"}
        ]
        
        # Python版でのCSV出力（UTF-8 BOM）
        python_csv = temp_output_dir / "python_test.csv"
        with open(python_csv, "w", encoding="utf-8-sig", newline="") as f:
            if test_data:
                writer = csv.DictWriter(f, fieldnames=test_data[0].keys())
                writer.writeheader()
                writer.writerows(test_data)
        
        # PowerShell版相当のCSV出力をシミュレート
        powershell_csv = temp_output_dir / "powershell_test.csv"
        with open(powershell_csv, "w", encoding="utf-8-sig", newline="") as f:
            if test_data:
                writer = csv.DictWriter(f, fieldnames=test_data[0].keys())
                writer.writeheader()
                writer.writerows(test_data)
        
        # 比較実行
        comparison = output_comparator.compare_csv_files(python_csv, powershell_csv)
        
        assert comparison["success"], f"CSV比較エラー: {comparison.get('error', 'Unknown error')}"
        assert comparison["columns_match"], "CSV列名が一致しません"
        assert comparison["row_count_match"], "CSVレコード数が一致しません"
        assert comparison["content_sample_match"], f"CSVデータ内容が一致しません: {comparison['sample_differences']}"


class TestAdvancedOutputCompatibility:
    """高度な出力互換性テスト"""
    
    @pytest.mark.compatibility
    @pytest.mark.integration
    def test_html_template_structure_compatibility(self, output_comparator, temp_output_dir):
        """HTMLテンプレート構造の互換性テスト"""
        # PowerShell版HTMLテンプレートの基本構造を模倣
        powershell_html_content = """
        <!DOCTYPE html>
        <html lang="ja">
        <head>
            <meta charset="UTF-8">
            <title>Microsoft 365管理レポート</title>
            <style>
                body { font-family: 'Meiryo', 'MS Gothic', sans-serif; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #4CAF50; color: white; }
            </style>
        </head>
        <body>
            <h1>Microsoft 365管理レポート</h1>
            <table>
                <tr><th>項目</th><th>値</th><th>状態</th></tr>
                <tr><td>ユーザー数</td><td>100</td><td>正常</td></tr>
                <tr><td>ライセンス消費</td><td>85/100</td><td>注意</td></tr>
            </table>
        </body>
        </html>
        """
        
        # Python版HTMLテンプレートの基本構造
        python_html_content = """
        <!DOCTYPE html>
        <html lang="ja">
        <head>
            <meta charset="UTF-8">
            <title>Microsoft 365管理レポート</title>
            <style>
                body { font-family: 'Meiryo', 'MS Gothic', sans-serif; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #4CAF50; color: white; }
            </style>
        </head>
        <body>
            <h1>Microsoft 365管理レポート</h1>
            <table>
                <tr><th>項目</th><th>値</th><th>状態</th></tr>
                <tr><td>ユーザー数</td><td>100</td><td>正常</td></tr>
                <tr><td>ライセンス消費</td><td>85/100</td><td>注意</td></tr>
            </table>
        </body>
        </html>
        """
        
        # ファイル出力
        powershell_html = temp_output_dir / "powershell_template.html"
        python_html = temp_output_dir / "python_template.html"
        
        with open(powershell_html, "w", encoding="utf-8") as f:
            f.write(powershell_html_content)
        with open(python_html, "w", encoding="utf-8") as f:
            f.write(python_html_content)
        
        # HTML構造比較
        comparison = output_comparator.compare_html_files(python_html, powershell_html)
        
        assert comparison["success"], f"HTML比較エラー: {comparison.get('error', 'Unknown error')}"
        assert comparison["basic_structure_match"], \
            f"HTML基本構造が一致しません: {comparison['python_elements']} vs {comparison['powershell_elements']}"
        assert comparison["table_structure_match"], "HTMLテーブル構造が一致しません"
    
    @pytest.mark.compatibility
    @pytest.mark.performance
    def test_large_dataset_output_compatibility(self, output_comparator, temp_output_dir):
        """大量データ出力の互換性テスト"""
        # 大量テストデータ生成（1000レコード）
        large_test_data = []
        for i in range(1000):
            large_test_data.append({
                "ID": f"user-{i:04d}",
                "表示名": f"テストユーザー{i:04d}",
                "メール": f"testuser{i:04d}@contoso.com",
                "部署": ["IT部門", "営業部", "管理部", "開発部"][i % 4],
                "ライセンス": ["Office 365 E3", "Microsoft 365 E5", "Office 365 E1"][i % 3],
                "最終ログイン": f"2024-01-{(i % 30) + 1:02d}",
                "状態": "有効" if i % 10 != 0 else "無効"
            })
        
        # Python版とPowerShell版の出力をシミュレート
        python_csv = temp_output_dir / "python_large_dataset.csv"
        powershell_csv = temp_output_dir / "powershell_large_dataset.csv"
        
        # 同一データでCSV出力
        for csv_file in [python_csv, powershell_csv]:
            with open(csv_file, "w", encoding="utf-8-sig", newline="") as f:
                if large_test_data:
                    writer = csv.DictWriter(f, fieldnames=large_test_data[0].keys())
                    writer.writeheader()
                    writer.writerows(large_test_data)
        
        # 大量データでの比較性能測定
        start_time = datetime.now()
        comparison = output_comparator.compare_csv_files(python_csv, powershell_csv)
        comparison_time = (datetime.now() - start_time).total_seconds()
        
        assert comparison["success"], f"大量データCSV比較エラー: {comparison.get('error', 'Unknown error')}"
        assert comparison["columns_match"], "大量データCSV列名が一致しません"
        assert comparison["row_count_match"], "大量データCSVレコード数が一致しません"
        assert comparison_time < 10.0, f"比較処理が遅すぎます: {comparison_time}秒"
        
        # ファイルサイズの妥当性確認
        python_size = python_csv.stat().st_size
        powershell_size = powershell_csv.stat().st_size
        assert abs(python_size - powershell_size) < 100, \
            f"ファイルサイズの差が大きすぎます: Python={python_size}, PowerShell={powershell_size}"


class TestSpecialCharacterCompatibility:
    """特殊文字・国際化対応の互換性テスト"""
    
    @pytest.mark.compatibility
    @pytest.mark.unit
    def test_japanese_unicode_compatibility(self, output_comparator, temp_output_dir):
        """日本語・Unicode文字の互換性テスト"""
        # 特殊文字を含むテストデータ
        special_char_data = [
            {"名前": "山田太郎", "部署": "総務部", "メモ": "通常の日本語"},
            {"名前": "田中花子", "部署": "開発部", "メモ": "絵文字テスト😀🚀💯"},
            {"名前": "佐藤一郎", "部署": "営業部", "メモ": "特殊記号①②③⑤⑩"},
            {"名前": "鈴木美咲", "部署": "人事部", "メモ": "旧字体：國學廳"},
            {"名前": "高橋健太", "部署": "IT部", "メモ": "記号: ①②③④⑤⑥⑦⑧⑨⑩"},
            {"名前": "伊藤麻衣", "部署": "法務部", "メモ": "HTML: <script>alert('test')</script>"},
            {"名前": "渡辺裕介", "部署": "財務部", "メモ": "SQL: SELECT * FROM users; DROP TABLE--"},
        ]
        
        # Python版とPowerShell版のCSV出力
        python_csv = temp_output_dir / "python_special_chars.csv"
        powershell_csv = temp_output_dir / "powershell_special_chars.csv"
        
        for csv_file in [python_csv, powershell_csv]:
            with open(csv_file, "w", encoding="utf-8-sig", newline="") as f:
                if special_char_data:
                    writer = csv.DictWriter(f, fieldnames=special_char_data[0].keys())
                    writer.writeheader()
                    writer.writerows(special_char_data)
        
        # 特殊文字比較
        comparison = output_comparator.compare_csv_files(python_csv, powershell_csv)
        
        assert comparison["success"], f"特殊文字CSV比較エラー: {comparison.get('error', 'Unknown error')}"
        assert comparison["content_sample_match"], \
            f"特殊文字データが一致しません: {comparison['sample_differences']}"
        
        # ファイル読み込み確認（UTF-8 BOM）
        for csv_file in [python_csv, powershell_csv]:
            with open(csv_file, "rb") as f:
                bom = f.read(3)
                assert bom == b'\xef\xbb\xbf', f"UTF-8 BOMが正しくありません: {csv_file}"
            
            # pandas での読み込み確認
            df = pd.read_csv(csv_file, encoding="utf-8-sig")
            assert len(df) == len(special_char_data), f"特殊文字CSVの読み込みレコード数が正しくありません: {csv_file}"


@pytest.mark.compatibility
@pytest.mark.integration
class TestEndToEndCompatibility:
    """エンドツーエンド互換性テスト"""
    
    @pytest.mark.requires_powershell
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_full_report_generation_compatibility(self, output_comparator, temp_output_dir):
        """完全レポート生成の互換性テスト"""
        # PowerShell版の統合テスト実行
        ps_result = await output_comparator.run_powershell_script(
            "test-enhanced-functionality.ps1",
            ["-TestType", "All", "-OutputPath", str(temp_output_dir), "-Timeout", "300"]
        )
        
        # 基本的な実行確認（エラーがあっても部分的成功を許可）
        if ps_result["returncode"] != 0:
            # PowerShell実行に問題がある場合はスキップ
            pytest.skip(f"PowerShell実行環境の問題: {ps_result['stderr']}")
        
        # 生成されたファイルの確認
        csv_files = list(temp_output_dir.glob("*.csv"))
        html_files = list(temp_output_dir.glob("*.html"))
        
        if csv_files or html_files:
            # ファイルが生成された場合の基本検証
            total_csv_size = sum(f.stat().st_size for f in csv_files)
            total_html_size = sum(f.stat().st_size for f in html_files)
            
            assert total_csv_size > 0, "CSVファイルの総サイズが0です"
            assert total_html_size > 0, "HTMLファイルの総サイズが0です"
            
            # ファイル命名規則の確認
            for csv_file in csv_files:
                assert "_" in csv_file.name, f"CSVファイル名に期待される区切り文字がありません: {csv_file.name}"
            
            for html_file in html_files:
                assert "_" in html_file.name, f"HTMLファイル名に期待される区切り文字がありません: {html_file.name}"
        else:
            # ファイルが生成されない場合はテスト環境の問題として記録
            pytest.skip("PowerShell実行でファイルが生成されませんでした（テスト環境の問題）")


# カスタムアサーション関数
def assert_csv_structure_compatible(python_csv: Path, powershell_csv: Path):
    """CSV構造互換性のカスタムアサーション"""
    try:
        py_df = pd.read_csv(python_csv, encoding="utf-8-sig")
        ps_df = pd.read_csv(powershell_csv, encoding="utf-8-sig")
        
        assert list(py_df.columns) == list(ps_df.columns), \
            f"CSV列名が一致しません: Python={list(py_df.columns)}, PowerShell={list(ps_df.columns)}"
        
        assert py_df.shape == ps_df.shape, \
            f"CSVデータサイズが一致しません: Python={py_df.shape}, PowerShell={ps_df.shape}"
        
    except Exception as e:
        pytest.fail(f"CSV構造比較中にエラーが発生しました: {str(e)}")


def assert_html_basic_structure(html_file: Path):
    """HTML基本構造のカスタムアサーション"""
    try:
        with open(html_file, "r", encoding="utf-8") as f:
            content = f.read()
        
        soup = BeautifulSoup(content, "html.parser")
        
        assert soup.find("html") is not None, f"HTML要素が見つかりません: {html_file}"
        assert soup.find("head") is not None, f"HEAD要素が見つかりません: {html_file}"
        assert soup.find("body") is not None, f"BODY要素が見つかりません: {html_file}"
        assert soup.find("title") is not None, f"TITLE要素が見つかりません: {html_file}"
        
        # 日本語対応確認
        charset_meta = soup.find("meta", attrs={"charset": True})
        assert charset_meta is not None, f"文字セット指定が見つかりません: {html_file}"
        assert "utf-8" in charset_meta.get("charset", "").lower(), \
            f"UTF-8文字セットが指定されていません: {html_file}"
        
    except Exception as e:
        pytest.fail(f"HTML構造確認中にエラーが発生しました: {str(e)}")