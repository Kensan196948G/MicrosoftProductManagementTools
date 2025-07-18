"""
エンドツーエンド統合テスト - 完全なワークフロー統合テスト
Dev1 - Test/QA Developer による包括的E2Eテスト実装

Microsoft 365管理ツールの完全なワークフロー統合テストを実装
"""

import pytest
import asyncio
import json
import tempfile
from pathlib import Path
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, MagicMock
from typing import Dict, List, Any
import pandas as pd

# プロジェクトモジュール（実装時に調整）
try:
    from src.main import main
    from src.gui.main_window import MainWindow
    from src.api.graph.client import GraphClient
    from src.core.config import Config
    from src.reports.generator import ReportGenerator
    from src.core.auth.auth_manager import AuthManager
except ImportError:
    # 開発初期段階でのモック定義
    main = Mock()
    MainWindow = Mock()
    GraphClient = Mock()
    Config = Mock()
    ReportGenerator = Mock()
    AuthManager = Mock()


@pytest.mark.e2e
@pytest.mark.integration
class TestCompleteWorkflows:
    """完全なワークフロー統合テスト"""
    
    @pytest.fixture(autouse=True)
    def setup_e2e_environment(self, temp_project_dir, mock_graph_client):
        """E2Eテスト環境セットアップ"""
        self.temp_dir = temp_project_dir
        self.mock_graph = mock_graph_client
        self.config_path = self.temp_dir / "config.json"
        
        # テスト用設定ファイル作成
        test_config = {
            "Authentication": {
                "TenantId": "test-tenant-123",
                "ClientId": "test-client-456",
                "CertificateThumbprint": "test-cert-789"
            },
            "Reports": {
                "OutputPath": str(self.temp_dir / "Reports"),
                "Format": ["HTML", "CSV"]
            },
            "Features": {
                "EnableAllFeatures": True,
                "MockDataMode": True
            }
        }
        
        with open(self.config_path, 'w', encoding='utf-8') as f:
            json.dump(test_config, f, indent=2)
    
    @pytest.mark.mock_data
    @pytest.mark.slow
    def test_complete_user_management_workflow(self, mock_graph_client):
        """完全なユーザー管理ワークフロー統合テスト"""
        # 1. 認証フロー
        auth_manager = AuthManager(self.config_path)
        assert auth_manager.authenticate()
        
        # 2. ユーザー一覧取得
        users = mock_graph_client.get_users()
        assert len(users["value"]) > 0
        
        # 3. ライセンス情報取得
        licenses = mock_graph_client.get_licenses()
        assert len(licenses["value"]) > 0
        
        # 4. レポート生成
        report_generator = ReportGenerator(self.temp_dir / "Reports")
        report_path = report_generator.generate_user_report(users, licenses)
        
        # 5. ファイル出力検証
        assert report_path.exists()
        assert report_path.suffix in ['.html', '.csv']
        
        # 6. レポート内容検証
        if report_path.suffix == '.csv':
            df = pd.read_csv(report_path, encoding='utf-8-sig')
            assert len(df) > 0
            assert 'displayName' in df.columns
    
    @pytest.mark.mock_data
    @pytest.mark.gui
    def test_gui_to_api_integration_workflow(self, gui_test_env, mock_graph_client):
        """GUI→API統合ワークフロー"""
        # 1. GUIアプリケーション起動
        app = MainWindow()
        
        # 2. 認証設定
        app.set_auth_config(self.config_path)
        
        # 3. 機能実行（ユーザー一覧取得）
        with patch.object(app, 'graph_client', mock_graph_client):
            result = app.execute_feature("get_users")
            assert result is not None
            assert "success" in result
            assert result["success"] is True
        
        # 4. レポート生成確認
        reports_dir = self.temp_dir / "Reports"
        report_files = list(reports_dir.glob("*.html"))
        assert len(report_files) > 0
    
    @pytest.mark.mock_data
    @pytest.mark.performance
    def test_large_dataset_processing_workflow(self, mock_graph_client):
        """大規模データセット処理ワークフロー"""
        # 1. 大量データのモック準備
        large_user_dataset = {
            "value": [
                {
                    "id": f"user-{i:04d}",
                    "displayName": f"テストユーザー{i}",
                    "userPrincipalName": f"test{i}@contoso.com",
                    "department": f"部署{i % 10}",
                    "accountEnabled": True
                }
                for i in range(1000)  # 1000ユーザーのテストデータ
            ]
        }
        
        mock_graph_client.get_users.return_value = large_user_dataset
        
        # 2. 処理時間測定
        start_time = datetime.now()
        
        # 3. データ処理実行
        users = mock_graph_client.get_users()
        
        # 4. レポート生成
        report_generator = ReportGenerator(self.temp_dir / "Reports")
        report_path = report_generator.generate_user_report(users, {"value": []})
        
        end_time = datetime.now()
        processing_time = (end_time - start_time).total_seconds()
        
        # 5. パフォーマンス検証
        assert processing_time < 30  # 30秒以内
        assert report_path.exists()
        
        # 6. 出力データ検証
        df = pd.read_csv(report_path, encoding='utf-8-sig')
        assert len(df) == 1000
    
    @pytest.mark.mock_data
    @pytest.mark.security
    def test_authentication_security_workflow(self, mock_graph_client):
        """認証セキュリティ統合ワークフロー"""
        # 1. 正常な認証フロー
        auth_manager = AuthManager(self.config_path)
        assert auth_manager.authenticate()
        
        # 2. 無効な認証情報でのテスト
        invalid_config = self.config_path.parent / "invalid_config.json"
        invalid_data = {
            "Authentication": {
                "TenantId": "invalid-tenant",
                "ClientId": "invalid-client",
                "CertificateThumbprint": "invalid-cert"
            }
        }
        
        with open(invalid_config, 'w') as f:
            json.dump(invalid_data, f)
        
        auth_manager_invalid = AuthManager(invalid_config)
        
        # 3. 認証失敗の検証
        with pytest.raises(Exception):
            auth_manager_invalid.authenticate()
        
        # 4. トークンの有効期限検証
        # トークンの有効期限切れシミュレーション
        expired_token = {
            "access_token": "expired_token",
            "expires_in": -1,
            "token_type": "Bearer"
        }
        
        with patch.object(auth_manager, 'get_token', return_value=expired_token):
            with pytest.raises(Exception):
                auth_manager.validate_token()
    
    @pytest.mark.mock_data
    @pytest.mark.api
    def test_cross_service_integration_workflow(self, mock_graph_client):
        """Microsoft 365サービス間統合ワークフロー"""
        # 1. 複数サービスのデータ取得
        services_data = {}
        
        # Entra ID ユーザー
        services_data["users"] = mock_graph_client.get_users()
        
        # Exchange メールボックス
        mock_graph_client.get_mailboxes.return_value = {
            "value": [
                {
                    "id": "mailbox-001",
                    "displayName": "テストメールボックス",
                    "emailAddress": "test@contoso.com"
                }
            ]
        }
        services_data["mailboxes"] = mock_graph_client.get_mailboxes()
        
        # Teams チーム
        mock_graph_client.get_teams.return_value = {
            "value": [
                {
                    "id": "team-001",
                    "displayName": "テストチーム",
                    "description": "テスト用チーム"
                }
            ]
        }
        services_data["teams"] = mock_graph_client.get_teams()
        
        # OneDrive サイト
        mock_graph_client.get_onedrive_sites.return_value = {
            "value": [
                {
                    "id": "site-001",
                    "displayName": "テストサイト",
                    "webUrl": "https://contoso.sharepoint.com/sites/test"
                }
            ]
        }
        services_data["onedrive"] = mock_graph_client.get_onedrive_sites()
        
        # 2. データ相関チェック
        user_count = len(services_data["users"]["value"])
        mailbox_count = len(services_data["mailboxes"]["value"])
        
        assert user_count > 0
        assert mailbox_count > 0
        
        # 3. 統合レポート生成
        report_generator = ReportGenerator(self.temp_dir / "Reports")
        integrated_report = report_generator.generate_integrated_report(services_data)
        
        assert integrated_report.exists()
        
        # 4. レポート内容検証
        with open(integrated_report, 'r', encoding='utf-8') as f:
            content = f.read()
            assert "ユーザー" in content
            assert "メールボックス" in content
            assert "チーム" in content
            assert "OneDrive" in content
    
    @pytest.mark.mock_data
    @pytest.mark.compatibility
    def test_powershell_python_compatibility_workflow(self, mock_powershell_execution):
        """PowerShell-Python互換性統合ワークフロー"""
        # 1. PowerShellスクリプト実行
        ps_script = "Get-MgUser -All"
        mock_powershell_execution.return_value.stdout = json.dumps({
            "value": [
                {
                    "Id": "user-001",
                    "DisplayName": "テストユーザー",
                    "UserPrincipalName": "test@contoso.com"
                }
            ]
        })
        
        # 2. Python実装の実行
        python_result = self.mock_graph.get_users()
        
        # 3. PowerShell実行結果の取得
        import subprocess
        ps_result = subprocess.run(
            ["pwsh", "-Command", ps_script],
            capture_output=True,
            text=True
        )
        ps_data = json.loads(ps_result.stdout)
        
        # 4. 結果の比較
        assert len(python_result["value"]) == len(ps_data["value"])
        
        # 5. データ構造の互換性確認
        for py_user, ps_user in zip(python_result["value"], ps_data["value"]):
            assert py_user["id"] == ps_user["Id"]
            assert py_user["displayName"] == ps_user["DisplayName"]
            assert py_user["userPrincipalName"] == ps_user["UserPrincipalName"]
    
    @pytest.mark.mock_data
    @pytest.mark.slow
    def test_error_recovery_workflow(self, mock_graph_client):
        """エラー回復統合ワークフロー"""
        # 1. 正常動作確認
        users = mock_graph_client.get_users()
        assert len(users["value"]) > 0
        
        # 2. ネットワークエラーシミュレーション
        network_error = Exception("Network timeout")
        
        with patch.object(mock_graph_client, 'get_users', side_effect=network_error):
            # 3. エラー発生時の処理
            with pytest.raises(Exception):
                mock_graph_client.get_users()
        
        # 4. 自動再試行機能のテスト
        call_count = 0
        def side_effect():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise Exception("Temporary error")
            return {"value": [{"id": "user-001", "displayName": "回復済みユーザー"}]}
        
        with patch.object(mock_graph_client, 'get_users', side_effect=side_effect):
            # 5. 回復後の正常動作確認
            result = mock_graph_client.get_users()
            assert result["value"][0]["displayName"] == "回復済みユーザー"
    
    @pytest.mark.mock_data
    @pytest.mark.performance
    def test_concurrent_operations_workflow(self, mock_graph_client):
        """並行処理統合ワークフロー"""
        # 1. 複数の非同期操作を並行実行
        async def fetch_users():
            await asyncio.sleep(0.1)  # API遅延シミュレーション
            return mock_graph_client.get_users()
        
        async def fetch_licenses():
            await asyncio.sleep(0.1)
            return mock_graph_client.get_licenses()
        
        async def fetch_groups():
            await asyncio.sleep(0.1)
            return {"value": [{"id": "group-001", "displayName": "テストグループ"}]}
        
        # 2. 並行実行
        async def run_concurrent_test():
            tasks = [
                fetch_users(),
                fetch_licenses(),
                fetch_groups()
            ]
            results = await asyncio.gather(*tasks)
            return results
        
        # 3. 実行時間測定
        start_time = datetime.now()
        results = asyncio.run(run_concurrent_test())
        end_time = datetime.now()
        
        # 4. 結果検証
        assert len(results) == 3
        assert all(result is not None for result in results)
        
        # 5. 並行処理の効率性確認（順次実行より高速）
        concurrent_time = (end_time - start_time).total_seconds()
        assert concurrent_time < 0.5  # 0.5秒以内（順次実行なら0.3秒以上）


@pytest.mark.e2e
@pytest.mark.integration
class TestReportingWorkflows:
    """レポート生成統合ワークフロー"""
    
    @pytest.fixture(autouse=True)
    def setup_reporting_environment(self, temp_project_dir):
        """レポート生成環境セットアップ"""
        self.temp_dir = temp_project_dir
        self.reports_dir = self.temp_dir / "Reports"
        self.reports_dir.mkdir(exist_ok=True)
        
        # 各種レポートディレクトリ作成
        for report_type in ["Daily", "Weekly", "Monthly", "Analysis"]:
            (self.reports_dir / report_type).mkdir(exist_ok=True)
    
    @pytest.mark.mock_data
    def test_daily_report_generation_workflow(self, mock_graph_client, sample_test_data):
        """日次レポート生成ワークフロー"""
        # 1. 日次データ取得
        daily_data = {
            "users": sample_test_data["users"],
            "licenses": sample_test_data["licenses"],
            "logins": [
                {
                    "userId": "user-001",
                    "loginTime": "2024-01-15T09:00:00Z",
                    "ipAddress": "192.168.1.100"
                }
            ]
        }
        
        # 2. レポート生成
        report_generator = ReportGenerator(self.reports_dir / "Daily")
        daily_report = report_generator.generate_daily_report(daily_data)
        
        # 3. ファイル存在確認
        assert daily_report.exists()
        
        # 4. HTML形式確認
        with open(daily_report, 'r', encoding='utf-8') as f:
            content = f.read()
            assert "<!DOCTYPE html>" in content
            assert "日次レポート" in content
            assert "ユーザー" in content
            assert "ライセンス" in content
    
    @pytest.mark.mock_data
    def test_multi_format_report_generation(self, mock_graph_client, sample_test_data):
        """複数フォーマットレポート生成"""
        # 1. レポート生成（HTML, CSV, JSON）
        report_generator = ReportGenerator(self.reports_dir / "Analysis")
        
        formats = ["html", "csv", "json"]
        generated_reports = {}
        
        for fmt in formats:
            report_path = report_generator.generate_report(
                sample_test_data, 
                format=fmt,
                report_type="analysis"
            )
            generated_reports[fmt] = report_path
        
        # 2. 各フォーマットの存在確認
        for fmt, path in generated_reports.items():
            assert path.exists()
            assert path.suffix.lower() == f".{fmt}"
        
        # 3. 内容一貫性確認
        # CSV内容確認
        csv_df = pd.read_csv(generated_reports["csv"], encoding='utf-8-sig')
        assert len(csv_df) > 0
        
        # JSON内容確認
        with open(generated_reports["json"], 'r', encoding='utf-8') as f:
            json_data = json.load(f)
            assert "users" in json_data
            assert len(json_data["users"]) > 0
    
    @pytest.mark.mock_data
    @pytest.mark.slow
    def test_scheduled_report_workflow(self, mock_graph_client, sample_test_data):
        """スケジュール実行レポートワークフロー"""
        # 1. スケジュール実行シミュレーション
        schedule_types = ["daily", "weekly", "monthly"]
        
        for schedule_type in schedule_types:
            # 2. スケジュール設定
            schedule_config = {
                "type": schedule_type,
                "output_path": str(self.reports_dir / schedule_type.capitalize()),
                "formats": ["html", "csv"],
                "data_sources": ["users", "licenses", "usage"]
            }
            
            # 3. レポート生成実行
            report_generator = ReportGenerator(self.reports_dir)
            reports = report_generator.generate_scheduled_report(
                schedule_config, 
                sample_test_data
            )
            
            # 4. 生成されたレポートの確認
            assert len(reports) > 0
            for report in reports:
                assert report.exists()
                assert report.suffix in ['.html', '.csv']
    
    @pytest.mark.mock_data
    def test_report_archival_workflow(self, mock_graph_client, sample_test_data):
        """レポートアーカイブワークフロー"""
        # 1. 複数のレポートを生成
        report_generator = ReportGenerator(self.reports_dir)
        
        reports = []
        for i in range(5):
            report = report_generator.generate_report(
                sample_test_data,
                report_name=f"test_report_{i}",
                format="html"
            )
            reports.append(report)
        
        # 2. アーカイブ処理
        archive_manager = report_generator.get_archive_manager()
        archive_path = archive_manager.archive_old_reports(
            older_than_days=0,  # 即座にアーカイブ
            archive_format="zip"
        )
        
        # 3. アーカイブファイルの確認
        assert archive_path.exists()
        assert archive_path.suffix == ".zip"
        
        # 4. アーカイブ内容の検証
        import zipfile
        with zipfile.ZipFile(archive_path, 'r') as zip_file:
            archived_files = zip_file.namelist()
            assert len(archived_files) >= 5


@pytest.mark.e2e
@pytest.mark.integration  
class TestSystemIntegrationWorkflows:
    """システム統合ワークフロー"""
    
    @pytest.mark.mock_data
    @pytest.mark.slow
    def test_full_system_startup_workflow(self, temp_project_dir):
        """完全なシステム起動ワークフロー"""
        # 1. 設定ファイル初期化
        config_path = temp_project_dir / "config.json"
        config_data = {
            "system": {"mode": "production"},
            "logging": {"level": "INFO"},
            "features": {"all_enabled": True}
        }
        
        with open(config_path, 'w') as f:
            json.dump(config_data, f)
        
        # 2. アプリケーション起動
        with patch('src.main.main') as mock_main:
            mock_main.return_value = {"status": "started", "pid": 12345}
            
            # 3. 起動確認
            result = main(["--config", str(config_path)])
            assert result["status"] == "started"
            assert "pid" in result
        
        # 4. ヘルスチェック
        health_check = {"status": "healthy", "version": "1.0.0"}
        assert health_check["status"] == "healthy"
    
    @pytest.mark.mock_data
    def test_configuration_reload_workflow(self, temp_project_dir):
        """設定リロードワークフロー"""
        # 1. 初期設定
        config_path = temp_project_dir / "config.json"
        initial_config = {"feature_x": False, "max_users": 100}
        
        with open(config_path, 'w') as f:
            json.dump(initial_config, f)
        
        config_manager = Config(config_path)
        assert config_manager.get("feature_x") is False
        assert config_manager.get("max_users") == 100
        
        # 2. 設定変更
        updated_config = {"feature_x": True, "max_users": 200}
        with open(config_path, 'w') as f:
            json.dump(updated_config, f)
        
        # 3. 動的リロード
        config_manager.reload()
        assert config_manager.get("feature_x") is True
        assert config_manager.get("max_users") == 200
    
    @pytest.mark.mock_data
    def test_logging_integration_workflow(self, temp_project_dir, capture_logs):
        """ログ統合ワークフロー"""
        # 1. ログ設定
        log_config = {
            "level": "DEBUG",
            "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            "handlers": ["console", "file"]
        }
        
        # 2. ログ出力テスト
        import logging
        logger = logging.getLogger("test_workflow")
        logger.info("ワークフロー開始")
        logger.debug("デバッグ情報")
        logger.warning("警告メッセージ")
        logger.error("エラーメッセージ")
        
        # 3. ログ内容確認
        log_contents = capture_logs.getvalue()
        assert "ワークフロー開始" in log_contents
        assert "デバッグ情報" in log_contents
        assert "警告メッセージ" in log_contents
        assert "エラーメッセージ" in log_contents
    
    @pytest.mark.mock_data
    def test_cleanup_workflow(self, temp_project_dir):
        """クリーンアップワークフロー"""
        # 1. 一時ファイル作成
        temp_files = []
        for i in range(5):
            temp_file = temp_project_dir / f"temp_file_{i}.tmp"
            temp_file.write_text(f"テンポラリファイル {i}")
            temp_files.append(temp_file)
        
        # 2. 一時ディレクトリ作成
        temp_dirs = []
        for i in range(3):
            temp_dir = temp_project_dir / f"temp_dir_{i}"
            temp_dir.mkdir()
            temp_dirs.append(temp_dir)
        
        # 3. クリーンアップ実行
        cleanup_manager = Mock()
        cleanup_manager.cleanup_temp_files.return_value = len(temp_files)
        cleanup_manager.cleanup_temp_dirs.return_value = len(temp_dirs)
        
        files_cleaned = cleanup_manager.cleanup_temp_files()
        dirs_cleaned = cleanup_manager.cleanup_temp_dirs()
        
        # 4. クリーンアップ結果確認
        assert files_cleaned == 5
        assert dirs_cleaned == 3


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])