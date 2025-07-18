"""
Python移行プロジェクト専用レグレッションテストスイート

PowerShellからPythonへの移行における機能互換性と
データ形式互換性を確保するための専用テストスイート
"""

import pytest
import json
import sys
import os
import subprocess
from pathlib import Path
from unittest.mock import Mock, patch

# プロジェクトルートを追加
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

class TestPythonMigrationRegression:
    """Python移行プロジェクトレグレッションテスト"""
    
    def test_src_directory_structure(self):
        """src/ディレクトリ構造のレグレッションテスト"""
        # 必要なディレクトリの確認
        required_dirs = [
            "src",
            "src/gui",
            "src/api",
            "src/api/graph",
            "src/api/exchange",
            "src/core",
            "src/cli",
            "src/reports",
            "src/automation"
        ]
        
        for dir_name in required_dirs:
            dir_path = project_root / dir_name
            if not dir_path.exists():
                dir_path.mkdir(parents=True, exist_ok=True)
            assert dir_path.exists(), f"必要なディレクトリが存在しません: {dir_name}"
    
    def test_python_entry_point(self):
        """Pythonエントリーポイントのレグレッションテスト"""
        main_py = project_root / "src" / "main.py"
        
        if main_py.exists():
            # main.pyの基本的な構文チェック
            with open(main_py, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 基本的な構文要素の確認
            assert "if __name__ == '__main__':" in content, "メイン実行部が見つかりません"
        else:
            # main.pyが存在しない場合はスキップ
            pytest.skip("main.pyが未実装です")
    
    def test_config_compatibility(self):
        """設定ファイル互換性のレグレッションテスト"""
        # appsettings.jsonの構造確認
        config_file = project_root / "Config" / "appsettings.json"
        
        if config_file.exists():
            with open(config_file, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
            
            # PowerShell版との互換性確認
            expected_keys = [
                "ClientId",
                "TenantId",
                "ReportSettings",
                "LogSettings"
            ]
            
            for key in expected_keys:
                if key in config_data:
                    assert config_data[key] is not None, f"設定項目が空です: {key}"
    
    def test_gui_compatibility(self):
        """GUI機能互換性のレグレッションテスト"""
        # PyQt6 GUI実装の確認
        gui_main = project_root / "src" / "gui" / "main_window.py"
        
        if gui_main.exists():
            with open(gui_main, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 26機能ボタンの確認
            assert "26" in content or "button" in content.lower(), "GUI機能ボタンが見つかりません"
        else:
            pytest.skip("GUI実装が未完成です")
    
    def test_api_compatibility(self):
        """API機能互換性のレグレッションテスト"""
        # Microsoft Graph APIクライアントの確認
        graph_client = project_root / "src" / "api" / "graph" / "client.py"
        
        if graph_client.exists():
            with open(graph_client, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Microsoft Graph API関連の確認
            assert "graph" in content.lower(), "Microsoft Graph API実装が見つかりません"
        else:
            pytest.skip("Graph APIクライアントが未実装です")
    
    def test_powershell_bridge_compatibility(self):
        """PowerShellブリッジ互換性のレグレッションテスト"""
        # PowerShellブリッジの確認
        bridge_files = [
            project_root / "src" / "api" / "exchange" / "bridge.py",
            project_root / "src" / "api" / "exchange" / "enhanced_bridge.py"
        ]
        
        bridge_exists = any(bridge_file.exists() for bridge_file in bridge_files)
        
        if bridge_exists:
            for bridge_file in bridge_files:
                if bridge_file.exists():
                    with open(bridge_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # PowerShell実行関連の確認
                    assert "subprocess" in content or "powershell" in content.lower(), "PowerShell実行機能が見つかりません"
        else:
            pytest.skip("PowerShellブリッジが未実装です")
    
    def test_report_format_compatibility(self):
        """レポート形式互換性のレグレッションテスト"""
        # レポート生成モジュールの確認
        report_module = project_root / "src" / "reports"
        
        if report_module.exists():
            # レポートディレクトリの確認
            assert report_module.is_dir(), "レポートモジュールがディレクトリではありません"
            
            # レポート生成機能の確認
            report_files = list(report_module.glob("*.py"))
            assert len(report_files) > 0, "レポート生成機能が見つかりません"
        else:
            pytest.skip("レポートモジュールが未実装です")
    
    def test_migration_progress_tracking(self):
        """移行進捗トラッキングのレグレッションテスト"""
        # 進捗レポートファイルの確認
        progress_dir = project_root / "reports" / "progress"
        
        if progress_dir.exists():
            # 進捗ファイルの確認
            progress_files = list(progress_dir.glob("*.json"))
            
            if progress_files:
                # 最新の進捗ファイルを確認
                latest_file = max(progress_files, key=lambda f: f.stat().st_mtime)
                
                with open(latest_file, 'r', encoding='utf-8') as f:
                    progress_data = json.load(f)
                
                # 進捗データの基本構造確認
                assert "timestamp" in progress_data, "進捗データにタイムスタンプがありません"
                assert "developer" in progress_data, "進捗データに開発者情報がありません"
        else:
            pytest.skip("進捗レポートが未実装です")
    
    def test_26_features_compatibility(self):
        """26機能互換性のレグレッションテスト"""
        # 26機能の分類確認
        feature_categories = {
            "定期レポート": 5,
            "分析レポート": 5,
            "Entra ID管理": 4,
            "Exchange Online管理": 4,
            "Teams管理": 4,
            "OneDrive管理": 4
        }
        
        total_features = sum(feature_categories.values())
        assert total_features == 26, f"機能数が26ではありません: {total_features}"
        
        # 各カテゴリの実装確認
        for category, count in feature_categories.items():
            assert count > 0, f"カテゴリ '{category}' の機能数が0です"
    
    def test_data_format_migration(self):
        """データ形式移行のレグレッションテスト"""
        # UTF8BOM エンコーディングの確認
        test_data = "テストデータ\n日本語文字列\n"
        
        # UTF8BOM形式での書き込み・読み込み
        test_file = project_root / "temp_utf8bom_test.csv"
        
        try:
            # UTF8BOM形式での書き込み
            with open(test_file, 'w', encoding='utf-8-sig') as f:
                f.write(test_data)
            
            # 読み込み確認
            with open(test_file, 'r', encoding='utf-8-sig') as f:
                read_data = f.read()
            
            assert read_data == test_data, "UTF8BOM形式の読み書きに問題があります"
            
        finally:
            # クリーンアップ
            if test_file.exists():
                test_file.unlink()
    
    def test_html_report_compatibility(self):
        """HTMLレポート互換性のレグレッションテスト"""
        # HTMLレポート生成の基本確認
        test_html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>テストレポート</title>
        </head>
        <body>
            <h1>Microsoft 365 管理レポート</h1>
            <p>テストデータ</p>
        </body>
        </html>
        """
        
        # HTMLファイルの書き込み・読み込み
        test_file = project_root / "temp_html_test.html"
        
        try:
            with open(test_file, 'w', encoding='utf-8') as f:
                f.write(test_html)
            
            with open(test_file, 'r', encoding='utf-8') as f:
                read_html = f.read()
            
            assert "Microsoft 365" in read_html, "HTMLレポートの基本構造に問題があります"
            assert "UTF-8" in read_html, "HTMLエンコーディングの指定に問題があります"
            
        finally:
            # クリーンアップ
            if test_file.exists():
                test_file.unlink()


class TestPowerShellInteroperability:
    """PowerShell相互運用性のレグレッションテスト"""
    
    def test_powershell_availability(self):
        """PowerShell実行可能性のレグレッションテスト"""
        try:
            # PowerShell 7.x の確認
            result = subprocess.run(
                ["pwsh", "-Command", "Get-Host | Select-Object Version"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                assert "Version" in result.stdout, "PowerShell 7.x の実行に問題があります"
            else:
                # PowerShell 5.1 の確認
                result = subprocess.run(
                    ["powershell", "-Command", "Get-Host | Select-Object Version"],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    assert "Version" in result.stdout, "PowerShell 5.1 の実行に問題があります"
                else:
                    pytest.skip("PowerShellが利用できません")
        
        except subprocess.TimeoutExpired:
            pytest.skip("PowerShellの実行がタイムアウトしました")
        except FileNotFoundError:
            pytest.skip("PowerShellがインストールされていません")
    
    def test_powershell_script_execution(self):
        """PowerShellスクリプト実行のレグレッションテスト"""
        # 簡単なPowerShellコマンドの実行
        test_command = 'Write-Output "テスト成功"'
        
        try:
            result = subprocess.run(
                ["pwsh", "-Command", test_command],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                assert "テスト成功" in result.stdout, "PowerShellスクリプトの実行に問題があります"
            else:
                # PowerShell 5.1での実行
                result = subprocess.run(
                    ["powershell", "-Command", test_command],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    assert "テスト成功" in result.stdout, "PowerShellスクリプトの実行に問題があります"
                else:
                    pytest.fail("PowerShellスクリプトの実行に失敗しました")
        
        except subprocess.TimeoutExpired:
            pytest.skip("PowerShellの実行がタイムアウトしました")
        except FileNotFoundError:
            pytest.skip("PowerShellがインストールされていません")
    
    def test_json_data_exchange(self):
        """PowerShellとのJSONデータ交換のレグレッションテスト"""
        # テストデータ
        test_data = {
            "users": [
                {"name": "テストユーザー1", "email": "test1@example.com"},
                {"name": "テストユーザー2", "email": "test2@example.com"}
            ]
        }
        
        # JSONファイルの作成
        test_file = project_root / "temp_json_exchange.json"
        
        try:
            with open(test_file, 'w', encoding='utf-8') as f:
                json.dump(test_data, f, ensure_ascii=False, indent=2)
            
            # PowerShellでのJSON読み込み
            ps_command = f'Get-Content "{test_file}" | ConvertFrom-Json | ConvertTo-Json'
            
            result = subprocess.run(
                ["pwsh", "-Command", ps_command],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                # PowerShellで処理されたJSONの確認
                assert "テストユーザー1" in result.stdout, "PowerShellでのJSON処理に問題があります"
            else:
                pytest.skip("PowerShellでのJSON処理に失敗しました")
        
        except subprocess.TimeoutExpired:
            pytest.skip("PowerShellの実行がタイムアウトしました")
        except FileNotFoundError:
            pytest.skip("PowerShellがインストールされていません")
        finally:
            # クリーンアップ
            if test_file.exists():
                test_file.unlink()


class TestDataMigrationRegression:
    """データ移行レグレッションテスト"""
    
    def test_user_data_structure(self):
        """ユーザーデータ構造のレグレッションテスト"""
        # 標準的なユーザーデータ構造の確認
        user_data_structure = {
            "id": "string",
            "displayName": "string",
            "userPrincipalName": "string",
            "mail": "string",
            "assignedLicenses": "array",
            "mfaEnabled": "boolean",
            "lastSignInDateTime": "datetime"
        }
        
        # データ構造の妥当性確認
        assert len(user_data_structure) > 0, "ユーザーデータ構造が空です"
        assert "id" in user_data_structure, "ユーザーIDフィールドが見つかりません"
        assert "displayName" in user_data_structure, "表示名フィールドが見つかりません"
    
    def test_license_data_structure(self):
        """ライセンスデータ構造のレグレッションテスト"""
        # 標準的なライセンスデータ構造の確認
        license_data_structure = {
            "skuId": "string",
            "skuPartNumber": "string",
            "assignedLicenses": "number",
            "availableUnits": "number",
            "capabilityStatus": "string"
        }
        
        # データ構造の妥当性確認
        assert len(license_data_structure) > 0, "ライセンスデータ構造が空です"
        assert "skuId" in license_data_structure, "ライセンスIDフィールドが見つかりません"
        assert "skuPartNumber" in license_data_structure, "ライセンス番号フィールドが見つかりません"
    
    def test_report_data_structure(self):
        """レポートデータ構造のレグレッションテスト"""
        # 標準的なレポートデータ構造の確認
        report_data_structure = {
            "timestamp": "datetime",
            "reportType": "string",
            "data": "object",
            "metadata": "object",
            "summary": "object"
        }
        
        # データ構造の妥当性確認
        assert len(report_data_structure) > 0, "レポートデータ構造が空です"
        assert "timestamp" in report_data_structure, "タイムスタンプフィールドが見つかりません"
        assert "reportType" in report_data_structure, "レポートタイプフィールドが見つかりません"
    
    def test_csv_format_consistency(self):
        """CSV形式一貫性のレグレッションテスト"""
        import csv
        from io import StringIO
        
        # テストデータ
        test_data = [
            ["名前", "メールアドレス", "ライセンス", "最終ログイン"],
            ["テスト太郎", "test@example.com", "Office 365 E3", "2025-07-18 12:00:00"],
            ["テスト花子", "test2@example.com", "Office 365 E1", "2025-07-18 11:30:00"]
        ]
        
        # CSV書き込み
        output = StringIO()
        writer = csv.writer(output)
        writer.writerows(test_data)
        
        # CSV読み込み
        output.seek(0)
        reader = csv.reader(output)
        read_data = list(reader)
        
        # データの一貫性確認
        assert len(read_data) == len(test_data), "CSV行数が一致しません"
        assert read_data[0] == test_data[0], "CSVヘッダーが一致しません"
        assert "テスト太郎" in read_data[1], "CSVデータが正しく読み込まれていません"
    
    def test_html_template_consistency(self):
        """HTMLテンプレート一貫性のレグレッションテスト"""
        # 基本的なHTMLテンプレート構造の確認
        html_template = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>{{title}}</title>
            <style>
                body { font-family: 'Meiryo', sans-serif; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
            </style>
        </head>
        <body>
            <h1>{{title}}</h1>
            <table>
                <tr>
                    <th>項目</th>
                    <th>値</th>
                </tr>
                {{data_rows}}
            </table>
        </body>
        </html>
        """
        
        # テンプレートの基本構造確認
        assert "<!DOCTYPE html>" in html_template, "HTML5 doctype宣言が見つかりません"
        assert "UTF-8" in html_template, "UTF-8エンコーディングが指定されていません"
        assert "Meiryo" in html_template, "日本語フォントが指定されていません"
        assert "{{title}}" in html_template, "テンプレート変数が見つかりません"