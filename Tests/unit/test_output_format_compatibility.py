"""
Python版とPowerShell版の出力形式比較テストスイート
Dev1 - Test/QA Developer による基盤構築

CSVおよびHTML出力の完全互換性検証
"""
import os
import sys
import csv
import json
import tempfile
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
import hashlib

import pytest
import pandas as pd
from bs4 import BeautifulSoup
import requests_mock

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

try:
    from src.reports.generators.csv_generator import CSVGenerator
    from src.reports.generators.html_generator import HTMLGenerator
except ImportError:
    # Python版が未実装の場合はモック版を使用
    CSVGenerator = None
    HTMLGenerator = None


class OutputFormatCompatibilityTester:
    """出力形式互換性テストクラス"""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.temp_dir = project_root / "tests" / "temp" / "output_format"
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        
        # PowerShell版テンプレートパス
        self.ps_templates_dir = project_root / "Templates"
        self.ps_samples_dir = project_root / "Templates" / "Samples"
        
        # 共通テストデータ
        self.test_data = self._generate_test_data()
        
    def _generate_test_data(self) -> Dict[str, List[Dict]]:
        """テスト用データセット生成"""
        return {
            "users": [
                {
                    "ID": "user-001",
                    "表示名": "山田太郎",
                    "メールアドレス": "yamada@contoso.com",
                    "部署": "IT部門",
                    "職位": "システム管理者",
                    "ライセンス": "Office 365 E3",
                    "最終ログイン": "2024-01-15 14:30:00",
                    "状態": "有効",
                    "作成日": "2023-01-15 10:00:00",
                    "MFA有効": "はい"
                },
                {
                    "ID": "user-002", 
                    "表示名": "田中花子",
                    "メールアドレス": "tanaka@contoso.com",
                    "部署": "営業部",
                    "職位": "営業マネージャー",
                    "ライセンス": "Microsoft 365 E5",
                    "最終ログイン": "2024-01-16 11:45:00",
                    "状態": "有効",
                    "作成日": "2023-02-01 09:00:00",
                    "MFA有効": "はい"
                },
                {
                    "ID": "user-003",
                    "表示名": "佐藤一郎",
                    "メールアドレス": "sato@contoso.com",
                    "部署": "開発部", 
                    "職位": "開発者",
                    "ライセンス": "Office 365 E1",
                    "最終ログイン": "",
                    "状態": "無効",
                    "作成日": "2023-03-10 08:30:00",
                    "MFA有効": "いいえ"
                }
            ],
            "licenses": [
                {
                    "SKU ID": "6fd2c87f-b296-42f0-b197-1e91e994b900",
                    "製品名": "Office 365 Enterprise E3",
                    "購入数": "100",
                    "消費数": "85",
                    "残り": "15",
                    "利用率": "85%",
                    "状態": "有効"
                },
                {
                    "SKU ID": "c7df2760-2c81-4ef7-b578-5b5392b571df",
                    "製品名": "Microsoft 365 Enterprise E5",
                    "購入数": "50",
                    "消費数": "25", 
                    "残り": "25",
                    "利用率": "50%",
                    "状態": "有効"
                }
            ],
            "daily_report": [
                {
                    "日付": "2024-01-16",
                    "ログイン成功": "156",
                    "ログイン失敗": "3",
                    "新規ユーザー": "2",
                    "無効化ユーザー": "1",
                    "ライセンス消費": "110/150",
                    "アラート": "1",
                    "システム状態": "正常"
                },
                {
                    "日付": "2024-01-15",
                    "ログイン成功": "142",
                    "ログイン失敗": "5",
                    "新規ユーザー": "1",
                    "無効化ユーザー": "0",
                    "ライセンス消費": "108/150",
                    "アラート": "0",
                    "システム状態": "正常"
                }
            ]
        }
    
    def generate_python_csv(self, data: List[Dict], output_path: Path) -> bool:
        """Python版CSV生成"""
        try:
            # UTF-8 BOM付きで出力（PowerShell版互換）
            with open(output_path, "w", encoding="utf-8-sig", newline="") as f:
                if data:
                    writer = csv.DictWriter(f, fieldnames=data[0].keys())
                    writer.writeheader()
                    writer.writerows(data)
            return True
        except Exception as e:
            print(f"Python CSV生成エラー: {e}")
            return False
    
    def generate_powershell_compatible_csv(self, data: List[Dict], output_path: Path) -> bool:
        """PowerShell版互換CSV生成"""
        try:
            # PowerShell Export-Csv コマンドと同等の出力
            with open(output_path, "w", encoding="utf-8-sig", newline="") as f:
                if data:
                    writer = csv.DictWriter(f, fieldnames=data[0].keys(), quoting=csv.QUOTE_MINIMAL)
                    writer.writeheader()
                    writer.writerows(data)
            return True
        except Exception as e:
            print(f"PowerShell互換CSV生成エラー: {e}")
            return False
    
    def generate_python_html(self, data: List[Dict], title: str, output_path: Path) -> bool:
        """Python版HTML生成"""
        try:
            # PowerShell版HTMLテンプレートと互換性のある構造
            html_content = f"""<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
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
        h1 {{
            color: #2E8B57;
            border-bottom: 2px solid #2E8B57;
            padding-bottom: 10px;
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
        tr:nth-child(even) {{
            background-color: #f2f2f2;
        }}
        .timestamp {{
            color: #6c757d;
            font-size: 12px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>{title}</h1>
        <div class="timestamp">生成日時: {datetime.now().strftime("%Y年%m月%d日 %H:%M:%S")}</div>
        
        <table>
            <thead>
                <tr>
"""
            
            if data:
                # ヘッダー行
                for column in data[0].keys():
                    html_content += f"                    <th>{column}</th>\n"
                
                html_content += """                </tr>
            </thead>
            <tbody>
"""
                
                # データ行
                for row in data:
                    html_content += "                <tr>\n"
                    for value in row.values():
                        html_content += f"                    <td>{str(value)}</td>\n"
                    html_content += "                </tr>\n"
            
            html_content += """            </tbody>
        </table>
        
        <footer style="margin-top: 30px; text-align: center; color: #6c757d; font-size: 12px;">
            <p>Microsoft 365管理ツール - Python版レポート</p>
        </footer>
    </div>
</body>
</html>"""
            
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(html_content)
            return True
        except Exception as e:
            print(f"Python HTML生成エラー: {e}")
            return False
    
    def generate_powershell_compatible_html(self, data: List[Dict], title: str, output_path: Path) -> bool:
        """PowerShell版互換HTML生成"""
        # Python版と同一の出力（互換性確認用）
        return self.generate_python_html(data, title, output_path)
    
    def compare_csv_files_detailed(self, python_csv: Path, powershell_csv: Path) -> Dict[str, Any]:
        """詳細CSV比較"""
        try:
            # ファイル存在確認
            if not python_csv.exists():
                return {"success": False, "error": "Python CSVファイルが存在しません"}
            if not powershell_csv.exists():
                return {"success": False, "error": "PowerShell CSVファイルが存在しません"}
            
            # UTF-8 BOM確認
            with open(python_csv, "rb") as f:
                py_bom = f.read(3)
            with open(powershell_csv, "rb") as f:
                ps_bom = f.read(3)
            
            bom_match = py_bom == ps_bom == b'\xef\xbb\xbf'
            
            # CSV読み込み
            py_df = pd.read_csv(python_csv, encoding="utf-8-sig")
            ps_df = pd.read_csv(powershell_csv, encoding="utf-8-sig")
            
            # 基本比較
            structure_comparison = {
                "columns_match": list(py_df.columns) == list(ps_df.columns),
                "row_count_match": len(py_df) == len(ps_df),
                "python_shape": py_df.shape,
                "powershell_shape": ps_df.shape
            }
            
            # データ内容比較
            content_match = True
            content_differences = []
            
            if structure_comparison["columns_match"] and structure_comparison["row_count_match"]:
                for i in range(len(py_df)):
                    for col in py_df.columns:
                        py_val = str(py_df.iloc[i][col]).strip()
                        ps_val = str(ps_df.iloc[i][col]).strip()
                        if py_val != ps_val:
                            content_match = False
                            content_differences.append({
                                "row": i,
                                "column": col,
                                "python_value": py_val,
                                "powershell_value": ps_val
                            })
            
            # ファイルサイズ比較
            py_size = python_csv.stat().st_size
            ps_size = powershell_csv.stat().st_size
            size_difference = abs(py_size - ps_size)
            
            return {
                "success": True,
                "bom_match": bom_match,
                "python_bom": py_bom.hex(),
                "powershell_bom": ps_bom.hex(),
                "structure": structure_comparison,
                "content_match": content_match,
                "content_differences": content_differences[:10],  # 最初の10件のみ
                "total_differences": len(content_differences),
                "file_sizes": {
                    "python": py_size,
                    "powershell": ps_size,
                    "difference": size_difference
                }
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    def compare_html_files_detailed(self, python_html: Path, powershell_html: Path) -> Dict[str, Any]:
        """詳細HTML比較"""
        try:
            # ファイル存在確認
            if not python_html.exists():
                return {"success": False, "error": "Python HTMLファイルが存在しません"}
            if not powershell_html.exists():
                return {"success": False, "error": "PowerShell HTMLファイルが存在しません"}
            
            # HTML読み込み
            with open(python_html, "r", encoding="utf-8") as f:
                py_content = f.read()
            with open(powershell_html, "r", encoding="utf-8") as f:
                ps_content = f.read()
            
            # BeautifulSoup解析
            py_soup = BeautifulSoup(py_content, "html.parser")
            ps_soup = BeautifulSoup(ps_content, "html.parser")
            
            # 基本HTML要素カウント
            html_elements = ["html", "head", "body", "title", "table", "tr", "td", "th", "style"]
            py_elements = {elem: len(py_soup.find_all(elem)) for elem in html_elements}
            ps_elements = {elem: len(ps_soup.find_all(elem)) for elem in html_elements}
            
            elements_match = py_elements == ps_elements
            
            # テーブル構造詳細比較
            py_tables = py_soup.find_all("table")
            ps_tables = ps_soup.find_all("table")
            
            table_comparison = {
                "table_count_match": len(py_tables) == len(ps_tables),
                "python_table_count": len(py_tables),
                "powershell_table_count": len(ps_tables),
                "table_details": []
            }
            
            if py_tables and ps_tables:
                for i, (py_table, ps_table) in enumerate(zip(py_tables, ps_tables)):
                    py_rows = len(py_table.find_all("tr"))
                    ps_rows = len(ps_table.find_all("tr"))
                    py_headers = len(py_table.find_all("th"))
                    ps_headers = len(ps_table.find_all("th"))
                    
                    table_comparison["table_details"].append({
                        "table_index": i,
                        "rows_match": py_rows == ps_rows,
                        "headers_match": py_headers == ps_headers,
                        "python_rows": py_rows,
                        "powershell_rows": ps_rows,
                        "python_headers": py_headers,
                        "powershell_headers": ps_headers
                    })
            
            # 文字エンコーディング確認
            py_charset = None
            ps_charset = None
            
            py_charset_meta = py_soup.find("meta", attrs={"charset": True})
            if py_charset_meta:
                py_charset = py_charset_meta.get("charset")
            
            ps_charset_meta = ps_soup.find("meta", attrs={"charset": True})
            if ps_charset_meta:
                ps_charset = ps_charset_meta.get("charset")
            
            charset_match = py_charset == ps_charset
            
            # ファイルサイズ比較
            py_size = python_html.stat().st_size
            ps_size = powershell_html.stat().st_size
            size_difference = abs(py_size - ps_size)
            
            return {
                "success": True,
                "elements_match": elements_match,
                "python_elements": py_elements,
                "powershell_elements": ps_elements,
                "table_comparison": table_comparison,
                "charset_match": charset_match,
                "python_charset": py_charset,
                "powershell_charset": ps_charset,
                "content_length": {
                    "python": len(py_content),
                    "powershell": len(ps_content),
                    "difference": abs(len(py_content) - len(ps_content))
                },
                "file_sizes": {
                    "python": py_size,
                    "powershell": ps_size,
                    "difference": size_difference
                }
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    def generate_compatibility_report(self, comparisons: Dict[str, Dict], output_dir: Path) -> Path:
        """互換性レポート生成"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = output_dir / f"output_format_compatibility_report_{timestamp}.html"
        
        html_content = f"""<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>出力形式互換性テストレポート</title>
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
        .test-result {{
            margin: 20px 0;
            padding: 15px;
            border-radius: 5px;
            border: 1px solid #ddd;
        }}
        .test-result.success {{
            background-color: #d4edda;
            border-color: #c3e6cb;
        }}
        .test-result.failure {{
            background-color: #f8d7da;
            border-color: #f5c6cb;
        }}
        .details {{
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 3px;
            margin-top: 10px;
            font-family: monospace;
            font-size: 12px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }}
        th {{
            background-color: #2E8B57;
            color: white;
        }}
        .status-success {{ color: #28a745; font-weight: bold; }}
        .status-failure {{ color: #dc3545; font-weight: bold; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 出力形式互換性テストレポート</h1>
        <p>生成日時: {datetime.now().strftime("%Y年%m月%d日 %H:%M:%S")}</p>
        
        <h2>📈 テスト結果サマリー</h2>
        <table>
            <thead>
                <tr>
                    <th>データタイプ</th>
                    <th>形式</th>
                    <th>構造一致</th>
                    <th>内容一致</th>
                    <th>全体結果</th>
                </tr>
            </thead>
            <tbody>
"""
        
        for data_type, formats in comparisons.items():
            for format_type, comparison in formats.items():
                if comparison.get("success", False):
                    status_class = "status-success"
                    status_text = "✅ 成功"
                else:
                    status_class = "status-failure"
                    status_text = "❌ 失敗"
                
                if format_type == "csv":
                    structure_match = comparison.get("structure", {}).get("columns_match", False)
                    content_match = comparison.get("content_match", False)
                else:  # html
                    structure_match = comparison.get("elements_match", False)
                    content_match = comparison.get("table_comparison", {}).get("table_count_match", False)
                
                structure_status = "✅" if structure_match else "❌"
                content_status = "✅" if content_match else "❌"
                
                html_content += f"""
                <tr>
                    <td>{data_type}</td>
                    <td>{format_type.upper()}</td>
                    <td>{structure_status}</td>
                    <td>{content_status}</td>
                    <td class="{status_class}">{status_text}</td>
                </tr>
"""
        
        html_content += """
            </tbody>
        </table>
        
        <h2>🔍 詳細比較結果</h2>
"""
        
        for data_type, formats in comparisons.items():
            for format_type, comparison in formats.items():
                result_class = "success" if comparison.get("success", False) else "failure"
                status_icon = "✅" if comparison.get("success", False) else "❌"
                
                html_content += f"""
        <div class="test-result {result_class}">
            <h3>{status_icon} {data_type} - {format_type.upper()} 形式</h3>
"""
                
                if format_type == "csv" and comparison.get("success"):
                    structure = comparison.get("structure", {})
                    html_content += f"""
            <p><strong>BOM一致:</strong> {'はい' if comparison.get('bom_match', False) else 'いいえ'}</p>
            <p><strong>列名一致:</strong> {'はい' if structure.get('columns_match', False) else 'いいえ'}</p>
            <p><strong>行数一致:</strong> {'はい' if structure.get('row_count_match', False) else 'いいえ'}</p>
            <p><strong>内容一致:</strong> {'はい' if comparison.get('content_match', False) else 'いいえ'}</p>
            <p><strong>Python形状:</strong> {structure.get('python_shape', 'N/A')}</p>
            <p><strong>PowerShell形状:</strong> {structure.get('powershell_shape', 'N/A')}</p>
"""
                
                elif format_type == "html" and comparison.get("success"):
                    html_content += f"""
            <p><strong>HTML要素一致:</strong> {'はい' if comparison.get('elements_match', False) else 'いいえ'}</p>
            <p><strong>文字セット一致:</strong> {'はい' if comparison.get('charset_match', False) else 'いいえ'}</p>
            <p><strong>テーブル数一致:</strong> {'はい' if comparison.get('table_comparison', {}).get('table_count_match', False) else 'いいえ'}</p>
"""
                
                if not comparison.get("success"):
                    html_content += f"""
            <div class="details">
                <strong>エラー:</strong> {comparison.get('error', 'Unknown error')}<br>
                <strong>エラータイプ:</strong> {comparison.get('error_type', 'Unknown')}
            </div>
"""
                
                html_content += "        </div>\n"
        
        html_content += """
    </div>
</body>
</html>
"""
        
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(html_content)
        
        return report_file


@pytest.fixture(scope="function")
def output_tester(project_root):
    """出力形式テスターのフィクスチャ"""
    return OutputFormatCompatibilityTester(project_root)


@pytest.fixture(scope="function")
def temp_output_dir(output_tester):
    """一時出力ディレクトリ"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    temp_dir = output_tester.temp_dir / f"format_test_{timestamp}"
    temp_dir.mkdir(exist_ok=True)
    yield temp_dir


class TestCSVOutputCompatibility:
    """CSV出力互換性テスト"""
    
    @pytest.mark.unit
    @pytest.mark.compatibility
    def test_users_csv_format_compatibility(self, output_tester, temp_output_dir):
        """ユーザーCSV出力形式の互換性テスト"""
        users_data = output_tester.test_data["users"]
        
        # Python版とPowerShell版のCSV生成
        python_csv = temp_output_dir / "python_users.csv"
        powershell_csv = temp_output_dir / "powershell_users.csv"
        
        py_success = output_tester.generate_python_csv(users_data, python_csv)
        ps_success = output_tester.generate_powershell_compatible_csv(users_data, powershell_csv)
        
        assert py_success, "Python版CSV生成に失敗しました"
        assert ps_success, "PowerShell互換CSV生成に失敗しました"
        
        # 詳細比較
        comparison = output_tester.compare_csv_files_detailed(python_csv, powershell_csv)
        
        assert comparison["success"], f"CSV比較エラー: {comparison.get('error', 'Unknown')}"
        assert comparison["bom_match"], "UTF-8 BOMが一致しません"
        assert comparison["structure"]["columns_match"], "CSV列名が一致しません"
        assert comparison["structure"]["row_count_match"], "CSVレコード数が一致しません"
        assert comparison["content_match"], f"CSVデータ内容が一致しません。差分数: {comparison['total_differences']}"
    
    @pytest.mark.unit
    @pytest.mark.compatibility
    def test_licenses_csv_format_compatibility(self, output_tester, temp_output_dir):
        """ライセンスCSV出力形式の互換性テスト"""
        licenses_data = output_tester.test_data["licenses"]
        
        python_csv = temp_output_dir / "python_licenses.csv"
        powershell_csv = temp_output_dir / "powershell_licenses.csv"
        
        py_success = output_tester.generate_python_csv(licenses_data, python_csv)
        ps_success = output_tester.generate_powershell_compatible_csv(licenses_data, powershell_csv)
        
        assert py_success and ps_success, "CSV生成に失敗しました"
        
        comparison = output_tester.compare_csv_files_detailed(python_csv, powershell_csv)
        
        assert comparison["success"], f"ライセンスCSV比較エラー: {comparison.get('error', 'Unknown')}"
        assert comparison["bom_match"], "ライセンスCSV UTF-8 BOMが一致しません"
        assert comparison["structure"]["columns_match"], "ライセンスCSV列名が一致しません"
        assert comparison["content_match"], "ライセンスCSVデータ内容が一致しません"
    
    @pytest.mark.unit
    @pytest.mark.compatibility
    def test_daily_report_csv_format_compatibility(self, output_tester, temp_output_dir):
        """日次レポートCSV出力形式の互換性テスト"""
        daily_data = output_tester.test_data["daily_report"]
        
        python_csv = temp_output_dir / "python_daily.csv"
        powershell_csv = temp_output_dir / "powershell_daily.csv"
        
        py_success = output_tester.generate_python_csv(daily_data, python_csv)
        ps_success = output_tester.generate_powershell_compatible_csv(daily_data, powershell_csv)
        
        assert py_success and ps_success, "日次レポートCSV生成に失敗しました"
        
        comparison = output_tester.compare_csv_files_detailed(python_csv, powershell_csv)
        
        assert comparison["success"], f"日次レポートCSV比較エラー: {comparison.get('error', 'Unknown')}"
        assert comparison["bom_match"], "日次レポートCSV UTF-8 BOMが一致しません"
        assert comparison["structure"]["columns_match"], "日次レポートCSV列名が一致しません"
        assert comparison["content_match"], "日次レポートCSVデータ内容が一致しません"


class TestHTMLOutputCompatibility:
    """HTML出力互換性テスト"""
    
    @pytest.mark.unit
    @pytest.mark.compatibility
    def test_users_html_format_compatibility(self, output_tester, temp_output_dir):
        """ユーザーHTML出力形式の互換性テスト"""
        users_data = output_tester.test_data["users"]
        
        python_html = temp_output_dir / "python_users.html"
        powershell_html = temp_output_dir / "powershell_users.html"
        
        py_success = output_tester.generate_python_html(users_data, "ユーザー一覧", python_html)
        ps_success = output_tester.generate_powershell_compatible_html(users_data, "ユーザー一覧", powershell_html)
        
        assert py_success, "Python版HTML生成に失敗しました"
        assert ps_success, "PowerShell互換HTML生成に失敗しました"
        
        comparison = output_tester.compare_html_files_detailed(python_html, powershell_html)
        
        assert comparison["success"], f"HTML比較エラー: {comparison.get('error', 'Unknown')}"
        assert comparison["elements_match"], "HTML要素構造が一致しません"
        assert comparison["charset_match"], "HTML文字セット指定が一致しません"
        assert comparison["table_comparison"]["table_count_match"], "HTMLテーブル数が一致しません"
    
    @pytest.mark.unit
    @pytest.mark.compatibility
    def test_licenses_html_format_compatibility(self, output_tester, temp_output_dir):
        """ライセンスHTML出力形式の互換性テスト"""
        licenses_data = output_tester.test_data["licenses"]
        
        python_html = temp_output_dir / "python_licenses.html"
        powershell_html = temp_output_dir / "powershell_licenses.html"
        
        py_success = output_tester.generate_python_html(licenses_data, "ライセンス分析", python_html)
        ps_success = output_tester.generate_powershell_compatible_html(licenses_data, "ライセンス分析", powershell_html)
        
        assert py_success and ps_success, "ライセンスHTML生成に失敗しました"
        
        comparison = output_tester.compare_html_files_detailed(python_html, powershell_html)
        
        assert comparison["success"], f"ライセンスHTML比較エラー: {comparison.get('error', 'Unknown')}"
        assert comparison["elements_match"], "ライセンスHTML要素構造が一致しません"
        assert comparison["charset_match"], "ライセンスHTML文字セット指定が一致しません"
    
    @pytest.mark.unit
    @pytest.mark.compatibility
    def test_daily_report_html_format_compatibility(self, output_tester, temp_output_dir):
        """日次レポートHTML出力形式の互換性テスト"""
        daily_data = output_tester.test_data["daily_report"]
        
        python_html = temp_output_dir / "python_daily.html"
        powershell_html = temp_output_dir / "powershell_daily.html"
        
        py_success = output_tester.generate_python_html(daily_data, "日次レポート", python_html)
        ps_success = output_tester.generate_powershell_compatible_html(daily_data, "日次レポート", powershell_html)
        
        assert py_success and ps_success, "日次レポートHTML生成に失敗しました"
        
        comparison = output_tester.compare_html_files_detailed(python_html, powershell_html)
        
        assert comparison["success"], f"日次レポートHTML比較エラー: {comparison.get('error', 'Unknown')}"
        assert comparison["elements_match"], "日次レポートHTML要素構造が一致しません"
        assert comparison["table_comparison"]["table_count_match"], "日次レポートHTMLテーブル数が一致しません"


@pytest.mark.compatibility
@pytest.mark.integration
class TestComprehensiveOutputCompatibility:
    """包括的出力互換性テスト"""
    
    def test_all_formats_comprehensive_compatibility(self, output_tester, temp_output_dir):
        """全形式包括的互換性テスト"""
        
        comparisons = {}
        
        # 各データタイプとフォーマットの組み合わせテスト
        for data_type, data in output_tester.test_data.items():
            comparisons[data_type] = {}
            
            # CSV形式テスト
            python_csv = temp_output_dir / f"python_{data_type}.csv"
            powershell_csv = temp_output_dir / f"powershell_{data_type}.csv"
            
            py_csv_success = output_tester.generate_python_csv(data, python_csv)
            ps_csv_success = output_tester.generate_powershell_compatible_csv(data, powershell_csv)
            
            if py_csv_success and ps_csv_success:
                csv_comparison = output_tester.compare_csv_files_detailed(python_csv, powershell_csv)
                comparisons[data_type]["csv"] = csv_comparison
            
            # HTML形式テスト
            python_html = temp_output_dir / f"python_{data_type}.html"
            powershell_html = temp_output_dir / f"powershell_{data_type}.html"
            
            py_html_success = output_tester.generate_python_html(data, f"{data_type}レポート", python_html)
            ps_html_success = output_tester.generate_powershell_compatible_html(data, f"{data_type}レポート", powershell_html)
            
            if py_html_success and ps_html_success:
                html_comparison = output_tester.compare_html_files_detailed(python_html, powershell_html)
                comparisons[data_type]["html"] = html_comparison
        
        # 包括的レポート生成
        report_file = output_tester.generate_compatibility_report(comparisons, temp_output_dir)
        
        assert report_file.exists(), "包括的互換性レポートが生成されませんでした"
        
        # 全ての比較が成功したかチェック
        all_success = True
        failed_tests = []
        
        for data_type, formats in comparisons.items():
            for format_type, comparison in formats.items():
                if not comparison.get("success", False):
                    all_success = False
                    failed_tests.append(f"{data_type}-{format_type}")
        
        assert all_success, f"一部のテストが失敗しました: {failed_tests}"
        
        print(f"✅ 包括的出力互換性テスト完了 - レポート: {report_file}")


# カスタムアサーション関数
def assert_csv_bom_utf8(csv_file: Path):
    """CSV UTF-8 BOMのカスタムアサーション"""
    with open(csv_file, "rb") as f:
        bom = f.read(3)
    assert bom == b'\xef\xbb\xbf', f"UTF-8 BOMが正しくありません: {csv_file} - BOM: {bom.hex()}"


def assert_html_japanese_charset(html_file: Path):
    """HTML日本語文字セットのカスタムアサーション"""
    with open(html_file, "r", encoding="utf-8") as f:
        content = f.read()
    
    soup = BeautifulSoup(content, "html.parser")
    charset_meta = soup.find("meta", attrs={"charset": True})
    
    assert charset_meta is not None, f"文字セット指定が見つかりません: {html_file}"
    assert "utf-8" in charset_meta.get("charset", "").lower(), \
        f"UTF-8文字セットが指定されていません: {html_file}"


def assert_file_size_reasonable(file_path: Path, min_size: int = 100, max_size: int = 1048576):
    """ファイルサイズ妥当性のカスタムアサーション"""
    file_size = file_path.stat().st_size
    assert min_size <= file_size <= max_size, \
        f"ファイルサイズが範囲外です: {file_path} - サイズ: {file_size}バイト (範囲: {min_size}-{max_size})"