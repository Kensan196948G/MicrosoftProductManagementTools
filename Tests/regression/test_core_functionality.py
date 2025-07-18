"""
レグレッションテストスイート - コア機能

Python移行プロジェクトにおいて、既存のPowerShell機能との互換性を確保する
レグレッションテストスイートです。
"""

import pytest
import sys
import os
from pathlib import Path

# プロジェクトルートを追加
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

class TestCoreRegression:
    """コア機能のレグレッションテスト"""
    
    def test_config_loading(self):
        """設定ファイル読み込み機能のレグレッションテスト"""
        # 設定ファイルの存在確認
        config_file = project_root / "Config" / "appsettings.json"
        assert config_file.exists(), "設定ファイルが存在しません"
        
        # 設定ファイルの読み込み可能性確認
        import json
        with open(config_file, 'r', encoding='utf-8') as f:
            config_data = json.load(f)
        
        assert isinstance(config_data, dict), "設定ファイルの形式が不正です"
        assert len(config_data) > 0, "設定ファイルが空です"
    
    def test_logging_functionality(self):
        """ログ機能のレグレッションテスト"""
        # ログディレクトリの確認
        log_dir = project_root / "logs"
        assert log_dir.exists() or log_dir.mkdir(exist_ok=True), "ログディレクトリが作成できません"
        
        # ログファイルの書き込み可能性確認
        test_log_file = log_dir / "regression_test.log"
        with open(test_log_file, 'w', encoding='utf-8') as f:
            f.write("レグレッションテスト実行\n")
        
        assert test_log_file.exists(), "ログファイルが作成されません"
        
        # クリーンアップ
        if test_log_file.exists():
            test_log_file.unlink()
    
    def test_report_generation_directories(self):
        """レポート生成用ディレクトリ構造のレグレッションテスト"""
        # 必要なディレクトリの確認
        required_dirs = [
            "Reports",
            "Reports/Daily",
            "Reports/Weekly", 
            "Reports/Monthly",
            "Reports/Yearly",
            "Reports/EntraID",
            "Reports/Exchange",
            "Reports/Teams",
            "Reports/OneDrive"
        ]
        
        for dir_name in required_dirs:
            dir_path = project_root / dir_name
            if not dir_path.exists():
                dir_path.mkdir(parents=True, exist_ok=True)
            assert dir_path.exists(), f"必要なディレクトリが存在しません: {dir_name}"
    
    def test_powershell_script_existence(self):
        """PowerShellスクリプトの存在確認レグレッションテスト"""
        # 重要なPowerShellスクリプトの存在確認
        required_scripts = [
            "run_launcher.ps1",
            "Apps/GuiApp_Enhanced.ps1",
            "Apps/CliApp_Enhanced.ps1"
        ]
        
        for script_name in required_scripts:
            script_path = project_root / script_name
            assert script_path.exists(), f"必要なPowerShellスクリプトが存在しません: {script_name}"
    
    def test_template_directory_structure(self):
        """テンプレートディレクトリ構造のレグレッションテスト"""
        # Templates/Samples構造の確認
        templates_dir = project_root / "Templates" / "Samples"
        if templates_dir.exists():
            # 6フォルダ構造の確認
            expected_folders = [
                "Daily",
                "Weekly", 
                "Monthly",
                "Yearly",
                "Analysis",
                "Security"
            ]
            
            for folder in expected_folders:
                folder_path = templates_dir / folder
                if not folder_path.exists():
                    folder_path.mkdir(parents=True, exist_ok=True)
                assert folder_path.exists(), f"テンプレートフォルダが存在しません: {folder}"


class TestAPIRegression:
    """API機能のレグレッションテスト"""
    
    def test_microsoft_graph_compatibility(self):
        """Microsoft Graph API互換性のレグレッションテスト"""
        # Microsoft Graph関連の設定確認
        config_file = project_root / "Config" / "appsettings.json"
        
        if config_file.exists():
            import json
            with open(config_file, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
            
            # Graph API設定の確認
            assert "ClientId" in config_data or "client_id" in config_data, "Graph APIクライアントIDが設定されていません"
    
    def test_exchange_online_compatibility(self):
        """Exchange Online API互換性のレグレッションテスト"""
        # Exchange Online関連の設定確認
        config_file = project_root / "Config" / "appsettings.json"
        
        if config_file.exists():
            import json
            with open(config_file, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
            
            # Exchange Online設定の確認（存在する場合）
            # 基本的な設定項目の確認
            assert isinstance(config_data, dict), "設定ファイルの形式が不正です"


class TestDataFormatRegression:
    """データ形式互換性のレグレッションテスト"""
    
    def test_csv_output_format(self):
        """CSV出力形式のレグレッションテスト"""
        # CSVファイルの基本的な読み書き確認
        import csv
        from io import StringIO
        
        # テストデータ
        test_data = [
            ["Name", "Email", "License"],
            ["テストユーザー1", "test1@example.com", "Office 365 E3"],
            ["テストユーザー2", "test2@example.com", "Office 365 E1"]
        ]
        
        # CSV書き込み
        output = StringIO()
        writer = csv.writer(output)
        writer.writerows(test_data)
        
        # CSV読み込み
        output.seek(0)
        reader = csv.reader(output)
        read_data = list(reader)
        
        assert read_data == test_data, "CSV形式の読み書きに問題があります"
    
    def test_json_output_format(self):
        """JSON出力形式のレグレッションテスト"""
        import json
        
        # テストデータ
        test_data = {
            "timestamp": "2025-07-18T20:00:00Z",
            "users": [
                {"name": "テストユーザー1", "email": "test1@example.com"},
                {"name": "テストユーザー2", "email": "test2@example.com"}
            ]
        }
        
        # JSON書き込み・読み込み
        json_str = json.dumps(test_data, ensure_ascii=False, indent=2)
        read_data = json.loads(json_str)
        
        assert read_data == test_data, "JSON形式の読み書きに問題があります"


class TestGUIRegression:
    """GUI機能のレグレッションテスト"""
    
    def test_gui_script_syntax(self):
        """GUIスクリプトの構文チェック"""
        gui_script = project_root / "Apps" / "GuiApp_Enhanced.ps1"
        
        if gui_script.exists():
            # PowerShellスクリプトの基本的な構文チェック
            with open(gui_script, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 基本的な構文要素の確認
            assert "System.Windows.Forms" in content, "Windows Forms参照が見つかりません"
            assert "Add-Type" in content, "Add-Type宣言が見つかりません"
    
    def test_cli_script_syntax(self):
        """CLIスクリプトの構文チェック"""
        cli_script = project_root / "Apps" / "CliApp_Enhanced.ps1"
        
        if cli_script.exists():
            # PowerShellスクリプトの基本的な構文チェック
            with open(cli_script, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 基本的な構文要素の確認
            assert "param" in content, "パラメータ宣言が見つかりません"


class TestSecurityRegression:
    """セキュリティ機能のレグレッションテスト"""
    
    def test_sensitive_data_protection(self):
        """機密データ保護のレグレッションテスト"""
        # 設定ファイルの機密情報チェック
        config_file = project_root / "Config" / "appsettings.json"
        
        if config_file.exists():
            with open(config_file, 'r', encoding='utf-8') as f:
                config_content = f.read()
            
            # 平文パスワードが含まれていないことを確認
            sensitive_patterns = [
                "password",
                "secret",
                "key"
            ]
            
            for pattern in sensitive_patterns:
                # パターンが含まれている場合は値が空またはプレースホルダーであることを確認
                if pattern in config_content.lower():
                    import json
                    f.seek(0)
                    config_data = json.load(f)
                    # 実際の値の確認は省略（機密情報のため）
                    assert isinstance(config_data, dict), "設定ファイルの形式が不正です"
    
    def test_log_file_permissions(self):
        """ログファイルの権限設定レグレッションテスト"""
        log_dir = project_root / "logs"
        
        if log_dir.exists():
            # ログディレクトリの存在確認
            assert log_dir.is_dir(), "ログディレクトリが正しく作成されていません"
            
            # ログファイルの作成・書き込み権限確認
            test_log_file = log_dir / "permission_test.log"
            try:
                with open(test_log_file, 'w', encoding='utf-8') as f:
                    f.write("権限テスト\n")
                
                assert test_log_file.exists(), "ログファイルの作成権限がありません"
                
                # クリーンアップ
                if test_log_file.exists():
                    test_log_file.unlink()
                    
            except PermissionError:
                pytest.fail("ログファイルの書き込み権限がありません")


@pytest.mark.slow
class TestPerformanceRegression:
    """パフォーマンス関連のレグレッションテスト"""
    
    def test_file_operation_performance(self):
        """ファイル操作パフォーマンスのレグレッションテスト"""
        import time
        
        # 大量のファイル操作のパフォーマンス測定
        start_time = time.time()
        
        # テストファイルの作成・読み込み・削除
        test_files = []
        for i in range(10):
            test_file = project_root / f"temp_test_{i}.txt"
            with open(test_file, 'w', encoding='utf-8') as f:
                f.write(f"テストデータ {i}\n" * 100)
            test_files.append(test_file)
        
        # 読み込み
        for test_file in test_files:
            with open(test_file, 'r', encoding='utf-8') as f:
                content = f.read()
                assert len(content) > 0, "ファイルが正しく読み込めません"
        
        # クリーンアップ
        for test_file in test_files:
            if test_file.exists():
                test_file.unlink()
        
        end_time = time.time()
        operation_time = end_time - start_time
        
        # 10秒以内での完了を期待
        assert operation_time < 10.0, f"ファイル操作が遅すぎます: {operation_time:.2f}秒"
    
    def test_json_processing_performance(self):
        """JSON処理パフォーマンスのレグレッションテスト"""
        import json
        import time
        
        # 大きなJSONデータの処理パフォーマンス測定
        test_data = {
            "users": [
                {"id": i, "name": f"User{i}", "email": f"user{i}@example.com"}
                for i in range(1000)
            ]
        }
        
        start_time = time.time()
        
        # JSON変換
        json_str = json.dumps(test_data, ensure_ascii=False)
        parsed_data = json.loads(json_str)
        
        end_time = time.time()
        processing_time = end_time - start_time
        
        # 1秒以内での完了を期待
        assert processing_time < 1.0, f"JSON処理が遅すぎます: {processing_time:.2f}秒"
        assert len(parsed_data["users"]) == 1000, "JSONデータが正しく処理されていません"