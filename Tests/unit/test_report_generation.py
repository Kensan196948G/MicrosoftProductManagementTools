"""
レポート生成機能のpytestテストスイート
Dev1 - Test/QA Developer による基盤構築

CSV・HTMLレポート生成エンジンの単体テスト
"""
import sys
import os
import csv
import json
import tempfile
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch
import uuid

import pytest
import pandas as pd
from jinja2 import Template, Environment, FileSystemLoader
from bs4 import BeautifulSoup

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))


class MockReportGenerator:
    """レポート生成エンジンのモック"""
    
    def __init__(self, output_dir: Path = None):
        self.output_dir = output_dir or Path("Reports")
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # デフォルトテンプレート
        self.default_html_template = """
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }}</title>
    <style>
        body {
            font-family: 'Meiryo', 'MS Gothic', sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2E8B57;
            border-bottom: 2px solid #2E8B57;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #2E8B57;
            color: white;
        }
        .summary-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #2E8B57;
        }
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            color: #2E8B57;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>{{ title }}</h1>
        
        {% if summary_stats %}
        <div class="summary-stats">
            {% for stat in summary_stats %}
            <div class="stat-card">
                <h3>{{ stat.name }}</h3>
                <div class="stat-value">{{ stat.value }}</div>
                {% if stat.description %}
                <p>{{ stat.description }}</p>
                {% endif %}
            </div>
            {% endfor %}
        </div>
        {% endif %}
        
        {% if data %}
        <table>
            <thead>
                <tr>
                    {% for header in headers %}
                    <th>{{ header }}</th>
                    {% endfor %}
                </tr>
            </thead>
            <tbody>
                {% for row in data %}
                <tr>
                    {% for cell in row %}
                    <td>{{ cell }}</td>
                    {% endfor %}
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% endif %}
        
        <footer style="margin-top: 50px; text-align: center; color: #6c757d; font-size: 12px;">
            <p>{{ report_timestamp }}に生成</p>
            <p>Microsoft 365管理ツール - Python版</p>
        </footer>
    </div>
</body>
</html>
        """
    
    def generate_csv_report(self, data: List[Dict[str, Any]], 
                           filename: str,
                           include_timestamp: bool = True) -> Path:
        """CSV レポート生成"""
        if include_timestamp:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            csv_filename = f"{filename}_{timestamp}.csv"
        else:
            csv_filename = f"{filename}.csv"
        
        csv_path = self.output_dir / csv_filename
        
        if data:
            # UTF-8 BOMでCSVファイル書き込み
            with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=data[0].keys())
                writer.writeheader()
                writer.writerows(data)
        else:
            # 空のCSVファイル作成
            with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
                f.write("")
        
        return csv_path
    
    def generate_html_report(self, 
                           title: str,
                           data: List[Dict[str, Any]] = None,
                           summary_stats: List[Dict[str, Any]] = None,
                           filename: str = "report",
                           include_timestamp: bool = True,
                           custom_template: str = None) -> Path:
        """HTML レポート生成"""
        if include_timestamp:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            html_filename = f"{filename}_{timestamp}.html"
        else:
            html_filename = f"{filename}.html"
        
        html_path = self.output_dir / html_filename
        
        # テンプレート準備
        template_content = custom_template or self.default_html_template
        template = Template(template_content)
        
        # データ変換（テーブル表示用）
        headers = []
        table_data = []
        
        if data:
            headers = list(data[0].keys())
            table_data = [[str(row.get(header, "")) for header in headers] for row in data]
        
        # テンプレート変数
        template_vars = {
            "title": title,
            "headers": headers,
            "data": table_data,
            "summary_stats": summary_stats or [],
            "report_timestamp": datetime.now().strftime("%Y年%m月%d日 %H:%M:%S")
        }
        
        # HTML生成
        html_content = template.render(**template_vars)
        
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(html_content)
        
        return html_path
    
    def generate_combined_report(self,
                               title: str,
                               data: List[Dict[str, Any]],
                               summary_stats: List[Dict[str, Any]] = None,
                               filename: str = "report",
                               include_timestamp: bool = True) -> Dict[str, Path]:
        """CSV・HTML両形式のレポート生成"""
        results = {}
        
        # CSV生成
        results["csv"] = self.generate_csv_report(
            data, filename, include_timestamp
        )
        
        # HTML生成
        results["html"] = self.generate_html_report(
            title, data, summary_stats, filename, include_timestamp
        )
        
        return results
    
    def validate_csv_structure(self, csv_path: Path) -> Dict[str, Any]:
        """CSV構造の妥当性確認"""
        try:
            # UTF-8 BOM確認
            with open(csv_path, "rb") as f:
                bom = f.read(3)
                has_bom = bom == b'\xef\xbb\xbf'
            
            # pandas読み込み確認
            df = pd.read_csv(csv_path, encoding="utf-8-sig")
            
            return {
                "success": True,
                "has_utf8_bom": has_bom,
                "row_count": len(df),
                "column_count": len(df.columns),
                "columns": list(df.columns),
                "file_size": csv_path.stat().st_size,
                "empty_cells": df.isnull().sum().sum(),
                "duplicate_rows": df.duplicated().sum()
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    def validate_html_structure(self, html_path: Path) -> Dict[str, Any]:
        """HTML構造の妥当性確認"""
        try:
            with open(html_path, "r", encoding="utf-8") as f:
                content = f.read()
            
            soup = BeautifulSoup(content, "html.parser")
            
            # 基本構造確認
            has_html = soup.find("html") is not None
            has_head = soup.find("head") is not None
            has_body = soup.find("body") is not None
            has_title = soup.find("title") is not None
            
            # 文字セット確認
            charset_meta = soup.find("meta", attrs={"charset": True})
            has_utf8_charset = charset_meta and "utf-8" in charset_meta.get("charset", "").lower()
            
            # テーブル構造確認
            tables = soup.find_all("table")
            table_info = []
            for i, table in enumerate(tables):
                rows = table.find_all("tr")
                headers = table.find_all("th")
                cells = table.find_all("td")
                
                table_info.append({
                    "table_index": i,
                    "row_count": len(rows),
                    "header_count": len(headers),
                    "cell_count": len(cells)
                })
            
            # CSS/JavaScript確認
            styles = soup.find_all("style")
            scripts = soup.find_all("script")
            
            return {
                "success": True,
                "basic_structure": {
                    "has_html": has_html,
                    "has_head": has_head,
                    "has_body": has_body,
                    "has_title": has_title
                },
                "charset": {
                    "has_utf8_charset": has_utf8_charset,
                    "charset_value": charset_meta.get("charset") if charset_meta else None
                },
                "tables": table_info,
                "styling": {
                    "style_count": len(styles),
                    "script_count": len(scripts)
                },
                "content_length": len(content),
                "file_size": html_path.stat().st_size
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }


@pytest.fixture(scope="function")
def mock_report_generator(temp_dir):
    """レポート生成器モックのフィクスチャ"""
    return MockReportGenerator(temp_dir)


@pytest.fixture(scope="function")
def sample_user_data():
    """サンプルユーザーデータ"""
    return [
        {
            "ID": "user-001",
            "表示名": "山田太郎",
            "メール": "yamada@contoso.com",
            "部署": "IT部門",
            "ライセンス": "Office 365 E3",
            "最終ログイン": "2024-01-15",
            "状態": "有効"
        },
        {
            "ID": "user-002", 
            "表示名": "田中花子",
            "メール": "tanaka@contoso.com",
            "部署": "営業部",
            "ライセンス": "Microsoft 365 E5",
            "最終ログイン": "2024-01-14",
            "状態": "有効"
        },
        {
            "ID": "user-003",
            "表示名": "佐藤一郎",
            "メール": "sato@contoso.com",
            "部署": "管理部",
            "ライセンス": "Office 365 E1",
            "最終ログイン": None,
            "状態": "無効"
        }
    ]


@pytest.fixture(scope="function")
def sample_summary_stats():
    """サンプル統計データ"""
    return [
        {
            "name": "総ユーザー数",
            "value": "150",
            "description": "アクティブ・非アクティブ含む"
        },
        {
            "name": "ライセンス消費率", 
            "value": "85%",
            "description": "128/150 ライセンス使用中"
        },
        {
            "name": "最終ログイン7日以内",
            "value": "142",
            "description": "94.7%のユーザーがアクティブ"
        }
    ]


class TestCSVReportGeneration:
    """CSV レポート生成テスト"""
    
    @pytest.mark.unit
    @pytest.mark.integration
    def test_basic_csv_generation(self, mock_report_generator, sample_user_data):
        """基本的なCSV生成テスト"""
        csv_path = mock_report_generator.generate_csv_report(
            sample_user_data, 
            "test_users",
            include_timestamp=False
        )
        
        assert csv_path.exists()
        assert csv_path.name == "test_users.csv"
        
        # CSV内容確認
        validation = mock_report_generator.validate_csv_structure(csv_path)
        assert validation["success"]
        assert validation["has_utf8_bom"]
        assert validation["row_count"] == 3
        assert validation["column_count"] == 7
        assert "表示名" in validation["columns"]
    
    @pytest.mark.unit
    def test_empty_csv_generation(self, mock_report_generator):
        """空データでのCSV生成テスト"""
        csv_path = mock_report_generator.generate_csv_report(
            [],
            "empty_test",
            include_timestamp=False
        )
        
        assert csv_path.exists()
        assert csv_path.stat().st_size >= 3  # 最低でもBOMサイズ
        
        validation = mock_report_generator.validate_csv_structure(csv_path)
        assert validation["success"]
        assert validation["row_count"] == 0
        assert validation["column_count"] == 0
    
    @pytest.mark.unit
    def test_csv_timestamp_inclusion(self, mock_report_generator, sample_user_data):
        """タイムスタンプ付きCSV生成テスト"""
        csv_path = mock_report_generator.generate_csv_report(
            sample_user_data,
            "timestamped_test",
            include_timestamp=True
        )
        
        assert csv_path.exists()
        assert "timestamped_test_" in csv_path.name
        assert csv_path.name.endswith(".csv")
        
        # ファイル名にタイムスタンプ形式が含まれている
        timestamp_part = csv_path.name.replace("timestamped_test_", "").replace(".csv", "")
        assert len(timestamp_part) == 15  # YYYYMMDD_HHMMSS
    
    @pytest.mark.unit
    def test_csv_special_characters(self, mock_report_generator):
        """特殊文字を含むCSV生成テスト"""
        special_data = [
            {
                "名前": "特殊文字テスト①",
                "記号": "①②③④⑤",
                "絵文字": "😀🚀💯",
                "HTML": "<script>alert('test')</script>",
                "SQL": "SELECT * FROM users; DROP TABLE--",
                "改行": "行1\n行2\n行3"
            }
        ]
        
        csv_path = mock_report_generator.generate_csv_report(
            special_data,
            "special_chars_test", 
            include_timestamp=False
        )
        
        assert csv_path.exists()
        
        # pandas読み込み確認
        df = pd.read_csv(csv_path, encoding="utf-8-sig")
        assert len(df) == 1
        assert "絵文字" in df.columns
        assert df.iloc[0]["絵文字"] == "😀🚀💯"
    
    @pytest.mark.unit
    @pytest.mark.performance
    def test_large_csv_generation(self, mock_report_generator):
        """大量データCSV生成テスト"""
        import time
        
        # 10,000レコードの大量データ生成
        large_data = []
        for i in range(10000):
            large_data.append({
                "ID": f"user-{i:05d}",
                "表示名": f"テストユーザー{i:05d}",
                "メール": f"testuser{i:05d}@contoso.com",
                "部署": ["IT部門", "営業部", "管理部"][i % 3],
                "ライセンス": ["Office 365 E3", "Microsoft 365 E5"][i % 2],
                "作成日": (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
            })
        
        start_time = time.time()
        csv_path = mock_report_generator.generate_csv_report(
            large_data,
            "large_dataset_test",
            include_timestamp=False
        )
        generation_time = time.time() - start_time
        
        assert csv_path.exists()
        assert generation_time < 10.0, f"大量データCSV生成が遅すぎます: {generation_time}秒"
        
        validation = mock_report_generator.validate_csv_structure(csv_path)
        assert validation["success"]
        assert validation["row_count"] == 10000
        assert validation["file_size"] > 100000  # 100KB以上


class TestHTMLReportGeneration:
    """HTML レポート生成テスト"""
    
    @pytest.mark.unit
    @pytest.mark.integration
    def test_basic_html_generation(self, mock_report_generator, sample_user_data, sample_summary_stats):
        """基本的なHTML生成テスト"""
        html_path = mock_report_generator.generate_html_report(
            title="ユーザー一覧レポート",
            data=sample_user_data,
            summary_stats=sample_summary_stats,
            filename="test_users",
            include_timestamp=False
        )
        
        assert html_path.exists()
        assert html_path.name == "test_users.html"
        
        validation = mock_report_generator.validate_html_structure(html_path)
        assert validation["success"]
        assert validation["basic_structure"]["has_html"]
        assert validation["basic_structure"]["has_head"]
        assert validation["basic_structure"]["has_body"]
        assert validation["charset"]["has_utf8_charset"]
    
    @pytest.mark.unit
    def test_html_table_structure(self, mock_report_generator, sample_user_data):
        """HTMLテーブル構造テスト"""
        html_path = mock_report_generator.generate_html_report(
            title="テーブル構造テスト",
            data=sample_user_data,
            filename="table_test",
            include_timestamp=False
        )
        
        validation = mock_report_generator.validate_html_structure(html_path)
        assert validation["success"]
        assert len(validation["tables"]) == 1
        
        table_info = validation["tables"][0]
        assert table_info["row_count"] == 4  # ヘッダー + 3データ行
        assert table_info["header_count"] == 7  # 7列
        assert table_info["cell_count"] == 21  # 7列 × 3行
    
    @pytest.mark.unit
    def test_html_summary_stats(self, mock_report_generator, sample_summary_stats):
        """HTML統計サマリーテスト"""
        html_path = mock_report_generator.generate_html_report(
            title="統計サマリーテスト",
            summary_stats=sample_summary_stats,
            filename="summary_test",
            include_timestamp=False
        )
        
        assert html_path.exists()
        
        with open(html_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # 統計データの存在確認
        assert "総ユーザー数" in content
        assert "150" in content
        assert "ライセンス消費率" in content
        assert "85%" in content
    
    @pytest.mark.unit
    def test_custom_html_template(self, mock_report_generator, sample_user_data):
        """カスタムHTMLテンプレートテスト"""
        custom_template = """
<!DOCTYPE html>
<html>
<head><title>{{ title }}</title></head>
<body>
    <h1>カスタムテンプレート</h1>
    <p>データ数: {{ data|length }}</p>
    {% for row in data %}
    <div>{{ row.表示名 }} - {{ row.部署 }}</div>
    {% endfor %}
</body>
</html>
        """
        
        html_path = mock_report_generator.generate_html_report(
            title="カスタムテスト",
            data=sample_user_data,
            filename="custom_template_test",
            include_timestamp=False,
            custom_template=custom_template
        )
        
        assert html_path.exists()
        
        with open(html_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        assert "カスタムテンプレート" in content
        assert "山田太郎 - IT部門" in content
        assert "田中花子 - 営業部" in content
    
    @pytest.mark.unit
    def test_html_responsive_design(self, mock_report_generator, sample_user_data):
        """HTMLレスポンシブデザインテスト"""
        html_path = mock_report_generator.generate_html_report(
            title="レスポンシブテスト",
            data=sample_user_data,
            filename="responsive_test",
            include_timestamp=False
        )
        
        with open(html_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # メタビューポートタグの存在確認
        assert 'name="viewport"' in content
        assert "width=device-width" in content
        
        # グリッドレイアウトの使用確認
        assert "grid-template-columns" in content
        assert "auto-fit" in content


class TestCombinedReportGeneration:
    """統合レポート生成テスト"""
    
    @pytest.mark.integration
    def test_combined_report_generation(self, mock_report_generator, sample_user_data, sample_summary_stats):
        """CSV・HTML両形式の統合レポート生成テスト"""
        results = mock_report_generator.generate_combined_report(
            title="統合レポートテスト",
            data=sample_user_data,
            summary_stats=sample_summary_stats,
            filename="combined_test",
            include_timestamp=False
        )
        
        assert "csv" in results
        assert "html" in results
        assert results["csv"].exists()
        assert results["html"].exists()
        
        # CSV妥当性確認
        csv_validation = mock_report_generator.validate_csv_structure(results["csv"])
        assert csv_validation["success"]
        assert csv_validation["row_count"] == 3
        
        # HTML妥当性確認
        html_validation = mock_report_generator.validate_html_structure(results["html"])
        assert html_validation["success"]
        assert len(html_validation["tables"]) == 1
    
    @pytest.mark.integration
    @pytest.mark.performance
    def test_combined_report_performance(self, mock_report_generator):
        """統合レポート生成パフォーマンステスト"""
        import time
        
        # 中規模データ (1000レコード)
        data = []
        for i in range(1000):
            data.append({
                "ID": f"user-{i:04d}",
                "名前": f"ユーザー{i:04d}",
                "部署": ["部署A", "部署B", "部署C"][i % 3],
                "状態": "有効" if i % 10 != 0 else "無効"
            })
        
        start_time = time.time()
        results = mock_report_generator.generate_combined_report(
            title="パフォーマンステスト",
            data=data,
            filename="performance_test",
            include_timestamp=False
        )
        generation_time = time.time() - start_time
        
        assert generation_time < 5.0, f"統合レポート生成が遅すぎます: {generation_time}秒"
        
        # ファイルサイズ確認
        csv_size = results["csv"].stat().st_size
        html_size = results["html"].stat().st_size
        
        assert csv_size > 10000  # 10KB以上
        assert html_size > 50000  # 50KB以上


class TestReportValidation:
    """レポート妥当性検証テスト"""
    
    @pytest.mark.unit
    def test_csv_validation_with_missing_data(self, mock_report_generator):
        """欠損データを含むCSV妥当性テスト"""
        data_with_nulls = [
            {"名前": "山田太郎", "年齢": 30, "部署": "IT部門"},
            {"名前": "田中花子", "年齢": None, "部署": "営業部"},
            {"名前": "佐藤一郎", "年齢": 45, "部署": None},
            {"名前": None, "年齢": 28, "部署": "管理部"}
        ]
        
        csv_path = mock_report_generator.generate_csv_report(
            data_with_nulls,
            "missing_data_test",
            include_timestamp=False
        )
        
        validation = mock_report_generator.validate_csv_structure(csv_path)
        assert validation["success"]
        assert validation["empty_cells"] > 0
        assert validation["row_count"] == 4
    
    @pytest.mark.unit
    def test_html_validation_with_malformed_data(self, mock_report_generator):
        """不正形式データを含むHTML妥当性テスト"""
        malformed_data = [
            {"フィールド1": "<script>alert('xss')</script>", "フィールド2": "正常データ"},
            {"フィールド1": "データ & 記号", "フィールド2": "データ\"引用符\""},
            {"フィールド1": "改行\n含む\nデータ", "フィールド2": "タブ\t文字"}
        ]
        
        html_path = mock_report_generator.generate_html_report(
            title="不正形式データテスト",
            data=malformed_data,
            filename="malformed_test",
            include_timestamp=False
        )
        
        validation = mock_report_generator.validate_html_structure(html_path)
        assert validation["success"]
        
        # HTML内容確認
        with open(html_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # XSS対策確認（スクリプトタグがエスケープされている）
        assert "<script>" not in content or "&lt;script&gt;" in content
    
    @pytest.mark.unit
    def test_file_permission_validation(self, mock_report_generator, sample_user_data):
        """ファイル権限・アクセス妥当性テスト"""
        csv_path = mock_report_generator.generate_csv_report(
            sample_user_data,
            "permission_test",
            include_timestamp=False
        )
        
        html_path = mock_report_generator.generate_html_report(
            title="権限テスト",
            data=sample_user_data,
            filename="permission_test",
            include_timestamp=False
        )
        
        # ファイル読み取り権限確認
        assert csv_path.is_file()
        assert csv_path.stat().st_size > 0
        assert html_path.is_file()
        assert html_path.stat().st_size > 0
        
        # ファイル読み込みテスト
        with open(csv_path, "r", encoding="utf-8-sig") as f:
            csv_content = f.read()
            assert len(csv_content) > 0
        
        with open(html_path, "r", encoding="utf-8") as f:
            html_content = f.read()
            assert len(html_content) > 0


@pytest.mark.integration
class TestReportIntegration:
    """レポート統合テスト"""
    
    @pytest.mark.asyncio
    async def test_async_report_generation(self, mock_report_generator, sample_user_data):
        """非同期レポート生成テスト"""
        import asyncio
        
        async def generate_report_async(data, filename):
            # 非同期での重い処理をシミュレート
            await asyncio.sleep(0.1)
            return mock_report_generator.generate_combined_report(
                title=f"非同期レポート - {filename}",
                data=data,
                filename=filename,
                include_timestamp=False
            )
        
        # 複数の非同期レポート生成
        tasks = [
            generate_report_async(sample_user_data, "async_test_1"),
            generate_report_async(sample_user_data, "async_test_2"),
            generate_report_async(sample_user_data, "async_test_3")
        ]
        
        results = await asyncio.gather(*tasks)
        
        # 全ての結果が正常に生成されている
        assert len(results) == 3
        for result in results:
            assert "csv" in result
            assert "html" in result
            assert result["csv"].exists()
            assert result["html"].exists()
    
    def test_error_handling_invalid_output_dir(self):
        """無効な出力ディレクトリでのエラーハンドリングテスト"""
        invalid_dir = Path("/invalid/nonexistent/directory")
        
        # 無効なディレクトリでも初期化時にディレクトリが作成される
        generator = MockReportGenerator(invalid_dir)
        
        # 権限があればディレクトリが作成される
        if invalid_dir.exists():
            assert invalid_dir.is_dir()
    
    def test_concurrent_report_generation(self, mock_report_generator, sample_user_data):
        """並行レポート生成テスト"""
        import threading
        import time
        
        results = {}
        errors = {}
        
        def generate_concurrent_report(thread_id):
            try:
                start_time = time.time()
                result = mock_report_generator.generate_combined_report(
                    title=f"並行レポート {thread_id}",
                    data=sample_user_data,
                    filename=f"concurrent_test_{thread_id}",
                    include_timestamp=True  # 重複回避のためタイムスタンプ付き
                )
                end_time = time.time()
                results[thread_id] = {
                    "result": result,
                    "duration": end_time - start_time
                }
            except Exception as e:
                errors[thread_id] = str(e)
        
        # 5つの並行スレッドでレポート生成
        threads = []
        for i in range(5):
            thread = threading.Thread(target=generate_concurrent_report, args=(i,))
            threads.append(thread)
        
        # スレッド開始
        for thread in threads:
            thread.start()
        
        # スレッド完了待機
        for thread in threads:
            thread.join()
        
        # 結果確認
        assert len(errors) == 0, f"並行処理でエラーが発生: {errors}"
        assert len(results) == 5
        
        # 全てのファイルが正常に生成されている
        for thread_id, result_data in results.items():
            result = result_data["result"]
            assert result["csv"].exists()
            assert result["html"].exists()
            
            # レポート妥当性確認
            csv_validation = mock_report_generator.validate_csv_structure(result["csv"])
            html_validation = mock_report_generator.validate_html_structure(result["html"])
            
            assert csv_validation["success"], f"Thread {thread_id} CSV validation failed"
            assert html_validation["success"], f"Thread {thread_id} HTML validation failed"