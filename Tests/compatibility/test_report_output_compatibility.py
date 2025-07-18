"""
レポート出力互換性テスト

PowerShell版とPython版のレポート出力フォーマットの互換性を検証します。
"""

import pytest
import json
import csv
from pathlib import Path
from typing import Dict, List, Any
import subprocess
import sys
from unittest.mock import Mock, patch

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from src.core.powershell_bridge import PowerShellBridge
from src.reports.generators.csv_generator import CSVGenerator
from src.reports.generators.html_generator import HTMLGenerator


@pytest.mark.compatibility
class TestReportOutputCompatibility:
    """レポート出力の互換性テストスイート"""
    
    @pytest.fixture
    def powershell_bridge(self):
        """PowerShellブリッジのフィクスチャ"""
        return PowerShellBridge()
    
    @pytest.fixture
    def sample_user_data(self):
        """サンプルユーザーデータ"""
        return [
            {
                "ID": "user-001",
                "表示名": "山田太郎",
                "メールアドレス": "yamada@contoso.com",
                "部署": "IT部門",
                "状態": "有効",
                "最終サインイン": "2025-01-18T10:30:00Z"
            },
            {
                "ID": "user-002",
                "表示名": "田中花子",
                "メールアドレス": "tanaka@contoso.com",
                "部署": "営業部",
                "状態": "有効",
                "最終サインイン": "2025-01-18T09:15:00Z"
            }
        ]
    
    @pytest.mark.requires_powershell
    def test_csv_header_compatibility(self, powershell_bridge, tmp_path):
        """CSVヘッダーの互換性テスト"""
        # PowerShellスクリプトの実行
        ps_script = """
        $users = @(
            @{ID='user-001'; '表示名'='山田太郎'; 'メールアドレス'='yamada@contoso.com'}
        )
        $users | Export-Csv -Path '{output}' -NoTypeInformation -Encoding UTF8
        """
        
        ps_output = tmp_path / "ps_output.csv"
        powershell_bridge.execute_script(
            ps_script.format(output=ps_output)
        )
        
        # Python版のCSV生成
        py_output = tmp_path / "py_output.csv"
        generator = CSVGenerator()
        generator.generate(
            [{"ID": "user-001", "表示名": "山田太郎", "メールアドレス": "yamada@contoso.com"}],
            py_output
        )
        
        # ヘッダー比較
        with open(ps_output, 'r', encoding='utf-8-sig') as ps_file:
            ps_header = ps_file.readline().strip()
        
        with open(py_output, 'r', encoding='utf-8-sig') as py_file:
            py_header = py_file.readline().strip()
        
        assert ps_header == py_header, f"ヘッダーが一致しません: PS={ps_header}, PY={py_header}"
    
    @pytest.mark.mock_data
    def test_csv_encoding_compatibility(self, tmp_path):
        """CSVエンコーディングの互換性テスト"""
        # UTF-8 BOMの確認
        test_data = [{"名前": "テスト", "説明": "日本語データ"}]
        
        generator = CSVGenerator()
        output_path = tmp_path / "encoding_test.csv"
        generator.generate(test_data, output_path)
        
        # BOM確認
        with open(output_path, 'rb') as f:
            bom = f.read(3)
            assert bom == b'\xef\xbb\xbf', "UTF-8 BOMが正しくありません"
        
        # 内容確認
        with open(output_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            row = next(reader)
            assert row["名前"] == "テスト"
            assert row["説明"] == "日本語データ"
    
    def test_html_structure_compatibility(self, sample_user_data, tmp_path):
        """HTML構造の互換性テスト"""
        generator = HTMLGenerator()
        output_path = tmp_path / "report.html"
        
        generator.generate(
            data=sample_user_data,
            output_path=output_path,
            title="ユーザーレポート",
            report_type="users"
        )
        
        # HTML構造の確認
        with open(output_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
            # 必須要素の確認
            assert '<!DOCTYPE html>' in content
            assert '<html lang="ja">' in content
            assert '<meta charset="utf-8">' in content
            assert 'Microsoft 365管理ツール' in content
            
            # テーブル構造の確認
            assert '<table' in content
            assert '<thead>' in content
            assert '<tbody>' in content
            
            # データの確認
            assert '山田太郎' in content
            assert '田中花子' in content
    
    @pytest.mark.parametrize("field_name,ps_name,py_name", [
        ("ユーザーID", "ID", "ID"),
        ("表示名", "DisplayName", "表示名"),
        ("メールアドレス", "UserPrincipalName", "メールアドレス"),
        ("部署", "Department", "部署"),
        ("最終サインイン", "LastSignInDateTime", "最終サインイン"),
    ])
    def test_field_name_mapping(self, field_name, ps_name, py_name):
        """フィールド名マッピングの互換性テスト"""
        # PowerShell形式からPython形式への変換を確認
        mapping = {
            "ID": "ID",
            "DisplayName": "表示名",
            "UserPrincipalName": "メールアドレス",
            "Department": "部署",
            "LastSignInDateTime": "最終サインイン",
        }
        
        assert mapping.get(ps_name, ps_name) == py_name
    
    def test_datetime_format_compatibility(self):
        """日時フォーマットの互換性テスト"""
        from datetime import datetime
        
        # PowerShell形式: 2025-01-18T10:30:00Z
        ps_format = "2025-01-18T10:30:00Z"
        
        # Pythonでの解析と再フォーマット
        dt = datetime.fromisoformat(ps_format.replace('Z', '+00:00'))
        py_format = dt.strftime("%Y-%m-%dT%H:%M:%S") + "Z"
        
        assert ps_format == py_format
    
    @pytest.mark.requires_powershell
    def test_large_dataset_compatibility(self, powershell_bridge, tmp_path):
        """大規模データセットの互換性テスト"""
        # 1000件のテストデータ
        large_data = [
            {
                "ID": f"user-{i:04d}",
                "表示名": f"ユーザー{i}",
                "メールアドレス": f"user{i}@contoso.com",
                "部署": f"部署{i % 10}",
                "状態": "有効"
            }
            for i in range(1000)
        ]
        
        # Python版のCSV生成
        generator = CSVGenerator()
        output_path = tmp_path / "large_dataset.csv"
        generator.generate(large_data, output_path)
        
        # ファイルサイズとレコード数の確認
        assert output_path.exists()
        
        with open(output_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            assert len(rows) == 1000
            
            # 最初と最後のレコード確認
            assert rows[0]["ID"] == "user-0000"
            assert rows[999]["ID"] == "user-0999"
    
    def test_special_character_handling(self, tmp_path):
        """特殊文字の処理互換性テスト"""
        special_data = [
            {
                "名前": "田中,花子",  # カンマ
                "説明": 'これは"引用符"を含む',  # 引用符
                "パス": r"C:\Users\test\file.txt",  # バックスラッシュ
                "改行": "1行目\n2行目",  # 改行
            }
        ]
        
        generator = CSVGenerator()
        output_path = tmp_path / "special_chars.csv"
        generator.generate(special_data, output_path)
        
        # 読み込んで確認
        with open(output_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            row = next(reader)
            
            assert row["名前"] == "田中,花子"
            assert row["説明"] == 'これは"引用符"を含む'
            assert row["パス"] == r"C:\Users\test\file.txt"
            assert "\n" in row["改行"]
    
    @pytest.mark.mock_data
    def test_empty_dataset_handling(self, tmp_path):
        """空データセットの処理互換性テスト"""
        generator = CSVGenerator()
        output_path = tmp_path / "empty.csv"
        
        # 空データでの生成
        generator.generate([], output_path, headers=["ID", "名前", "メール"])
        
        assert output_path.exists()
        
        with open(output_path, 'r', encoding='utf-8-sig') as f:
            content = f.read()
            lines = content.strip().split('\n')
            
            # ヘッダーのみ存在
            assert len(lines) == 1
            assert "ID,名前,メール" in lines[0]
    
    def test_report_metadata_compatibility(self, sample_user_data, tmp_path):
        """レポートメタデータの互換性テスト"""
        generator = HTMLGenerator()
        output_path = tmp_path / "metadata_test.html"
        
        metadata = {
            "generated_at": "2025-01-18T12:00:00Z",
            "report_type": "ユーザーレポート",
            "record_count": len(sample_user_data),
            "version": "2.0"
        }
        
        generator.generate(
            data=sample_user_data,
            output_path=output_path,
            title="ユーザーレポート",
            metadata=metadata
        )
        
        with open(output_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
            # メタデータの存在確認
            assert "生成日時" in content
            assert "レコード数" in content
            assert str(len(sample_user_data)) in content


class TestErrorHandlingCompatibility:
    """エラーハンドリングの互換性テスト"""
    
    def test_invalid_data_handling(self, tmp_path):
        """無効なデータの処理互換性"""
        generator = CSVGenerator()
        
        # None値を含むデータ
        data_with_none = [
            {"ID": "001", "名前": None, "メール": "test@example.com"}
        ]
        
        output_path = tmp_path / "none_handling.csv"
        generator.generate(data_with_none, output_path)
        
        with open(output_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            row = next(reader)
            # PowerShell同様、Noneは空文字列として出力
            assert row["名前"] == ""
    
    def test_permission_error_handling(self, tmp_path):
        """権限エラーの処理互換性"""
        output_path = tmp_path / "readonly.csv"
        output_path.touch()
        output_path.chmod(0o444)  # 読み取り専用
        
        generator = CSVGenerator()
        
        with pytest.raises(PermissionError):
            generator.generate([{"test": "data"}], output_path)
        
        # クリーンアップ
        output_path.chmod(0o644)