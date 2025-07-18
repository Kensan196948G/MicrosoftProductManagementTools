"""
PowerShellBridge互換性テスト
PowerShellとPythonの相互運用性を確認するための包括的なテストスイート
"""

import pytest
import json
import asyncio
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, call
from datetime import datetime
import subprocess
from typing import Dict, Any, List

from src.core.powershell_bridge import (
    PowerShellBridge, 
    PowerShellResult, 
    PowerShellCompatibilityLayer
)


@pytest.fixture
def mock_subprocess():
    """subprocess.runをモック化"""
    with patch('subprocess.run') as mock_run:
        yield mock_run


@pytest.fixture
def project_root():
    """プロジェクトルートディレクトリ"""
    return Path(__file__).parent.parent.parent


@pytest.fixture
def bridge(mock_subprocess, project_root):
    """PowerShellBridgeインスタンス（モック付き）"""
    # PowerShell検出のモック
    mock_subprocess.return_value = Mock(
        returncode=0,
        stdout="PowerShell 7.5.1",
        stderr=""
    )
    return PowerShellBridge(project_root=project_root)


@pytest.fixture
def success_result():
    """成功時のPowerShellResult"""
    return PowerShellResult(
        stdout='{"success": true, "data": "test"}',
        stderr="",
        returncode=0,
        success=True,
        data={"success": True, "data": "test"}
    )


@pytest.fixture
def error_result():
    """エラー時のPowerShellResult"""
    return PowerShellResult(
        stdout="",
        stderr="Error occurred",
        returncode=1,
        success=False,
        error_message="Error occurred"
    )


class TestPowerShellBridge:
    """PowerShellBridgeクラスのテスト"""
    
    def test_init(self, bridge, project_root):
        """初期化テスト"""
        assert bridge.project_root == project_root
        assert bridge.pwsh_exe in ['pwsh', 'pwsh.exe', 'powershell', 'powershell.exe']
        assert bridge.max_retries == 3
        assert len(bridge.module_paths) > 0
        assert bridge.default_params == ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass']
    
    def test_find_powershell_not_found(self, project_root):
        """PowerShellが見つからない場合のテスト"""
        with patch('subprocess.run') as mock_run:
            mock_run.side_effect = FileNotFoundError()
            
            with pytest.raises(RuntimeError, match="PowerShellが見つかりません"):
                PowerShellBridge(project_root=project_root)
    
    def test_execute_command_success(self, bridge, mock_subprocess):
        """コマンド実行成功のテスト"""
        expected_data = {"users": [{"name": "Test User"}]}
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(expected_data),
            stderr=""
        )
        
        result = bridge.execute_command("Get-MgUser")
        
        assert result.success is True
        assert result.returncode == 0
        assert result.data == expected_data
        assert result.error_message is None
        
        # コマンドが正しく準備されているか確認
        call_args = mock_subprocess.call_args
        assert '-NoProfile' in call_args[0][0]
        assert '-NonInteractive' in call_args[0][0]
        assert '-ExecutionPolicy' in call_args[0][0]
        assert 'Bypass' in call_args[0][0]
    
    def test_execute_command_error(self, bridge, mock_subprocess):
        """コマンド実行エラーのテスト"""
        error_data = {
            "Message": "Access denied",
            "Type": "System.UnauthorizedAccessException",
            "StackTrace": "at line 1"
        }
        mock_subprocess.return_value = Mock(
            returncode=1,
            stdout="",
            stderr=json.dumps(error_data)
        )
        
        result = bridge.execute_command("Get-MgUser")
        
        assert result.success is False
        assert result.returncode == 1
        assert result.error_message == "Access denied"
        assert result.data == error_data
    
    def test_execute_command_timeout(self, bridge, mock_subprocess):
        """コマンドタイムアウトのテスト"""
        mock_subprocess.side_effect = subprocess.TimeoutExpired('cmd', 30)
        
        result = bridge.execute_command("Get-MgUser", timeout=30)
        
        assert result.success is False
        assert result.returncode == -1
        assert "タイムアウト" in result.error_message
    
    def test_execute_command_json_parse_error(self, bridge, mock_subprocess):
        """JSON解析エラーのテスト"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout="Not a valid JSON",
            stderr=""
        )
        
        result = bridge.execute_command("Get-Date", return_json=True)
        
        assert result.success is True
        assert result.data == "Not a valid JSON"  # 生データが格納される
    
    @pytest.mark.asyncio
    async def test_execute_command_async(self, bridge, mock_subprocess):
        """非同期コマンド実行のテスト"""
        expected_data = {"async": True}
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(expected_data),
            stderr=""
        )
        
        result = await bridge.execute_command_async("Get-MgUser")
        
        assert result.success is True
        assert result.data == expected_data
    
    def test_execute_script(self, bridge, mock_subprocess, tmp_path):
        """スクリプト実行のテスト"""
        script_path = tmp_path / "test_script.ps1"
        script_path.write_text("Write-Output 'Hello'")
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout="Hello",
            stderr=""
        )
        
        result = bridge.execute_script(script_path, parameters={"Name": "Test", "Count": 5, "Force": True})
        
        assert result.success is True
        assert result.stdout == "Hello"
        
        # パラメータが正しく渡されているか確認
        call_args = mock_subprocess.call_args[0][0]
        assert str(script_path) in call_args
        assert '-Name' in call_args
        assert 'Test' in call_args
        assert '-Count' in call_args
        assert '5' in call_args
        assert '-Force' in call_args
    
    def test_execute_script_not_found(self, bridge):
        """存在しないスクリプトのテスト"""
        result = bridge.execute_script("nonexistent_script.ps1")
        
        assert result.success is False
        assert "スクリプトが見つかりません" in result.error_message
    
    def test_import_module(self, bridge, mock_subprocess, project_root):
        """モジュールインポートのテスト"""
        # モジュールファイルを作成
        module_path = project_root / 'Scripts' / 'Common' / 'TestModule.psm1'
        module_path.parent.mkdir(parents=True, exist_ok=True)
        module_path.write_text("# Test module")
        
        mock_subprocess.return_value = Mock(returncode=0, stdout="", stderr="")
        
        success = bridge.import_module("TestModule")
        
        assert success is True
        assert "TestModule" in bridge._module_cache
        
        # キャッシュのテスト
        bridge.import_module("TestModule")  # 2回目の呼び出し
        assert mock_subprocess.call_count == 2  # 初期化時とインポート時の2回のみ
        
        # クリーンアップ
        module_path.unlink()
    
    def test_import_module_not_found(self, bridge):
        """存在しないモジュールのインポートテスト"""
        success = bridge.import_module("NonExistentModule")
        assert success is False
    
    def test_call_function(self, bridge, mock_subprocess):
        """関数呼び出しのテスト"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"result": "success"}',
            stderr=""
        )
        
        result = bridge.call_function(
            "Get-UserData",
            UserPrincipalName="test@example.com",
            Properties=["displayName", "mail"],
            IncludeGuests=True,
            Filter={"Department": "IT", "Country": "Japan"}
        )
        
        assert result.success is True
        assert result.data == {"result": "success"}
        
        # コマンドが正しく構築されているか確認
        call_args = mock_subprocess.call_args[0][0]
        command_str = str(call_args)
        assert "Get-UserData" in command_str
        assert "-UserPrincipalName 'test@example.com'" in command_str
        assert "-Properties @(\"displayName\",\"mail\")" in command_str
        assert "-IncludeGuests" in command_str
        assert "-Filter @{Department=\"IT\";Country=\"Japan\"}" in command_str
    
    def test_microsoft365_methods(self, bridge, mock_subprocess):
        """Microsoft 365固有メソッドのテスト"""
        mock_subprocess.return_value = Mock(returncode=0, stdout='{}', stderr="")
        
        # Connect Graph
        result = bridge.connect_graph(
            tenant_id="test-tenant",
            client_id="test-client",
            certificate_thumbprint="test-thumbprint"
        )
        assert result.success is True
        
        # Get Users
        result = bridge.get_users(
            properties=["displayName", "mail"],
            filter_query="startswith(displayName,'A')"
        )
        assert result.success is True
        
        # Get Licenses
        result = bridge.get_licenses()
        assert result.success is True
        
        # Get Mailboxes
        result = bridge.get_mailboxes(result_size=50)
        assert result.success is True
        
        # Get Teams Usage
        result = bridge.get_teams_usage()
        assert result.success is True
        
        # Get OneDrive Storage
        result = bridge.get_onedrive_storage()
        assert result.success is True
    
    def test_execute_batch(self, bridge, mock_subprocess):
        """バッチ実行のテスト"""
        commands = ["Get-Date", "Get-Process", "Get-Service"]
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"data": "test"}',
            stderr=""
        )
        
        # 順次実行
        results = bridge.execute_batch(commands, parallel=False)
        assert len(results) == 3
        assert all(r.success for r in results)
        
        # 並列実行
        results = bridge.execute_batch(commands, parallel=True)
        assert len(results) == 3
    
    @pytest.mark.asyncio
    async def test_execute_batch_async(self, bridge, mock_subprocess):
        """非同期バッチ実行のテスト"""
        commands = ["Get-Date", "Get-Process"]
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"data": "test"}',
            stderr=""
        )
        
        results = await bridge.execute_batch_async(commands)
        assert len(results) == 2
        assert all(r.success for r in results)
    
    def test_type_conversion_ps_to_python(self, bridge):
        """PowerShell → Python型変換のテスト"""
        # 辞書
        ps_dict = {"Name": "Test", "@odata.type": "#microsoft.graph.user"}
        py_dict = bridge._convert_ps_to_python(ps_dict)
        assert py_dict == ps_dict
        
        # リスト
        ps_list = [1, 2, "three"]
        py_list = bridge._convert_ps_to_python(ps_list)
        assert py_list == ps_list
        
        # DateTime文字列
        ps_date = "/Date(1640995200000)/"
        py_date = bridge._convert_ps_to_python(ps_date)
        assert isinstance(py_date, datetime)
        assert py_date.year == 2022
    
    def test_type_conversion_python_to_ps(self, bridge):
        """Python → PowerShell型変換のテスト"""
        # None
        assert bridge._convert_python_to_ps(None) == '$null'
        
        # Bool
        assert bridge._convert_python_to_ps(True) == '$true'
        assert bridge._convert_python_to_ps(False) == '$false'
        
        # 数値
        assert bridge._convert_python_to_ps(42) == '42'
        assert bridge._convert_python_to_ps(3.14) == '3.14'
        
        # 文字列（エスケープ処理）
        assert bridge._convert_python_to_ps("test") == "'test'"
        assert bridge._convert_python_to_ps("test'quote") == "'test''quote'"
        assert bridge._convert_python_to_ps('test"quote') == "'test`\"quote'"
        
        # リスト
        assert bridge._convert_python_to_ps([1, 2, 3]) == "@(1,2,3)"
        assert bridge._convert_python_to_ps(["a", "b"]) == "@('a','b')"
        
        # 辞書
        assert bridge._convert_python_to_ps({"key": "value"}) == "@{'key'='value'}"
        
        # datetime
        dt = datetime(2022, 1, 1, 12, 0, 0)
        result = bridge._convert_python_to_ps(dt)
        assert dt.isoformat() in result
    
    def test_execute_with_retry(self, bridge, mock_subprocess):
        """再試行機能のテスト"""
        # 2回失敗後に成功
        mock_subprocess.side_effect = [
            Mock(returncode=1, stdout="", stderr="Temporary error"),
            Mock(returncode=1, stdout="", stderr="Temporary error"),
            Mock(returncode=0, stdout='{"success": true}', stderr="")
        ]
        
        result = bridge.execute_with_retry("Get-MgUser")
        
        assert result.success is True
        assert mock_subprocess.call_count == 4  # 初期化時 + 3回の実行
    
    def test_execute_with_retry_permission_error(self, bridge, mock_subprocess):
        """権限エラーは再試行しないテスト"""
        mock_subprocess.return_value = Mock(
            returncode=1,
            stdout="",
            stderr='{"Message": "Permission denied"}'
        )
        
        result = bridge.execute_with_retry("Get-MgUser")
        
        assert result.success is False
        assert mock_subprocess.call_count == 2  # 初期化時 + 1回の実行のみ
    
    def test_execute_pipeline(self, bridge, mock_subprocess):
        """パイプライン実行のテスト"""
        commands = ["Get-MgUser", "Where-Object {$_.Department -eq 'IT'}", "Select-Object DisplayName"]
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='[{"DisplayName": "Test User"}]',
            stderr=""
        )
        
        result = bridge.execute_pipeline(commands)
        
        assert result.success is True
        
        # パイプラインが正しく構築されているか確認
        call_args = mock_subprocess.call_args[0][0]
        command_str = str(call_args)
        assert " | " in command_str
    
    def test_persistent_session(self, bridge, mock_subprocess):
        """永続セッションのテスト"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout="12345",  # セッションID
            stderr=""
        )
        
        success = bridge.create_persistent_session()
        
        assert success is True
        assert bridge._session_id == "12345"
        assert bridge._persistent_session is True
    
    def test_context_manager(self, bridge, mock_subprocess):
        """コンテキストマネージャーのテスト"""
        mock_subprocess.return_value = Mock(returncode=0, stdout="", stderr="")
        
        with bridge as b:
            assert b is bridge
        
        # cleanupが呼ばれたことを確認
        assert bridge.executor._shutdown is True
        assert len(bridge._module_cache) == 0
    
    def test_data_format_compatibility(self, bridge, mock_subprocess):
        """PowerShell出力との互換性テスト"""
        # 実際のPowerShell出力形式をシミュレート
        ps_user_output = {
            "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
            "value": [
                {
                    "id": "12345",
                    "displayName": "Test User",
                    "userPrincipalName": "test@example.com",
                    "mail": "test@example.com",
                    "accountEnabled": True,
                    "createdDateTime": "2022-01-01T00:00:00Z"
                }
            ]
        }
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(ps_user_output),
            stderr=""
        )
        
        result = bridge.get_users()
        
        assert result.success is True
        assert result.data == ps_user_output
        assert "value" in result.data
        assert len(result.data["value"]) == 1
        assert result.data["value"][0]["displayName"] == "Test User"


class TestPowerShellCompatibilityLayer:
    """PowerShellCompatibilityLayerのテスト"""
    
    @pytest.fixture
    def compat_layer(self, bridge):
        """互換性レイヤーのインスタンス"""
        return PowerShellCompatibilityLayer(bridge)
    
    def test_function_mapping(self, compat_layer):
        """関数マッピングのテスト"""
        assert 'connect_services' in compat_layer._function_map
        assert compat_layer._function_map['connect_services'] == 'Connect-M365Services'
        assert 'get_users' in compat_layer._function_map
        assert compat_layer._function_map['get_users'] == 'Get-MgUser'
    
    def test_dynamic_method_resolution(self, compat_layer, mock_subprocess):
        """動的メソッド解決のテスト"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"users": []}',
            stderr=""
        )
        
        # 存在するメソッド
        result = compat_layer.get_users(Property=['displayName'])
        assert hasattr(result, 'success')
        
        # 存在しないメソッド
        with pytest.raises(AttributeError):
            compat_layer.non_existent_method()
    
    def test_import_common_modules(self, compat_layer, mock_subprocess):
        """共通モジュール一括インポートのテスト"""
        mock_subprocess.return_value = Mock(returncode=0, stdout="", stderr="")
        
        # モジュールファイルを作成
        modules = ['Common', 'Authentication', 'Logging', 'ErrorHandling', 'ReportGenerator', 'RealM365DataProvider']
        for module in modules:
            module_path = compat_layer.bridge.project_root / 'Scripts' / 'Common' / f'{module}.psm1'
            module_path.parent.mkdir(parents=True, exist_ok=True)
            module_path.write_text(f"# {module} module")
        
        compat_layer.import_common_modules()
        
        # 全モジュールがキャッシュされているか確認
        for module in modules:
            assert module in compat_layer.bridge._module_cache
        
        # クリーンアップ
        for module in modules:
            module_path = compat_layer.bridge.project_root / 'Scripts' / 'Common' / f'{module}.psm1'
            if module_path.exists():
                module_path.unlink()


class TestRealDataCompatibility:
    """実データとの互換性テスト"""
    
    def test_user_data_format(self, bridge, mock_subprocess):
        """ユーザーデータ形式の互換性"""
        # PowerShellのGet-MgUserの実際の出力形式
        real_user_data = {
            "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
            "value": [
                {
                    "businessPhones": [],
                    "displayName": "田中 太郎",
                    "givenName": "太郎",
                    "id": "87d349ed-44d7-43e1-9a83-5f2406dee5bd",
                    "jobTitle": "営業部長",
                    "mail": "tanaka@contoso.com",
                    "mobilePhone": None,
                    "officeLocation": "18/2111",
                    "preferredLanguage": "ja-JP",
                    "surname": "田中",
                    "userPrincipalName": "tanaka@contoso.onmicrosoft.com"
                }
            ]
        }
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(real_user_data),
            stderr=""
        )
        
        result = bridge.get_users()
        assert result.data["value"][0]["displayName"] == "田中 太郎"
        assert result.data["value"][0]["preferredLanguage"] == "ja-JP"
    
    def test_license_data_format(self, bridge, mock_subprocess):
        """ライセンスデータ形式の互換性"""
        # PowerShellのGet-MgSubscribedSkuの実際の出力形式
        real_license_data = {
            "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#subscribedSkus",
            "value": [
                {
                    "capabilityStatus": "Enabled",
                    "consumedUnits": 23,
                    "id": "b05e124f-c7cc-45a0-a6aa-8cf78c946968",
                    "prepaidUnits": {
                        "enabled": 25,
                        "suspended": 0,
                        "warning": 0
                    },
                    "servicePlans": [
                        {
                            "appliesTo": "User",
                            "provisioningStatus": "Success",
                            "servicePlanId": "efb87545-963c-4e0d-99df-69c6916d9eb0",
                            "servicePlanName": "EXCHANGE_S_ENTERPRISE"
                        }
                    ],
                    "skuId": "b05e124f-c7cc-45a0-a6aa-8cf78c946968",
                    "skuPartNumber": "ENTERPRISEPREMIUM"
                }
            ]
        }
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(real_license_data),
            stderr=""
        )
        
        result = bridge.get_licenses()
        assert result.data["value"][0]["skuPartNumber"] == "ENTERPRISEPREMIUM"
        assert result.data["value"][0]["consumedUnits"] == 23
        assert result.data["value"][0]["prepaidUnits"]["enabled"] == 25
    
    def test_mailbox_data_format(self, bridge, mock_subprocess):
        """メールボックスデータ形式の互換性"""
        # Exchange Online PowerShellの実際の出力形式
        real_mailbox_data = [
            {
                "Name": "田中 太郎",
                "Alias": "tanaka",
                "PrimarySmtpAddress": "tanaka@contoso.com",
                "RecipientTypeDetails": "UserMailbox",
                "ProhibitSendQuota": "50 GB (53,687,091,200 bytes)",
                "ProhibitSendReceiveQuota": "52 GB (55,834,574,848 bytes)",
                "IssueWarningQuota": "49 GB (52,613,349,376 bytes)",
                "UseDatabaseQuotaDefaults": False,
                "Database": "JAPDB01",
                "ArchiveStatus": "Active"
            }
        ]
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(real_mailbox_data),
            stderr=""
        )
        
        result = bridge.get_mailboxes()
        assert result.data[0]["PrimarySmtpAddress"] == "tanaka@contoso.com"
        assert result.data[0]["RecipientTypeDetails"] == "UserMailbox"
        assert "50 GB" in result.data[0]["ProhibitSendQuota"]


class TestErrorHandlingScenarios:
    """エラーハンドリングシナリオのテスト"""
    
    def test_network_error_handling(self, bridge, mock_subprocess):
        """ネットワークエラーハンドリング"""
        mock_subprocess.return_value = Mock(
            returncode=1,
            stdout="",
            stderr=json.dumps({
                "Message": "The remote server returned an error: (503) Server Unavailable.",
                "Type": "System.Net.WebException"
            })
        )
        
        result = bridge.execute_with_retry("Get-MgUser", timeout=5)
        assert result.success is False
        assert "503" in result.error_message
    
    def test_authentication_error_handling(self, bridge, mock_subprocess):
        """認証エラーハンドリング"""
        mock_subprocess.return_value = Mock(
            returncode=1,
            stdout="",
            stderr=json.dumps({
                "Message": "Authentication failed. The provided access token is expired.",
                "Type": "Microsoft.Graph.PowerShell.Authentication.AuthenticationException"
            })
        )
        
        result = bridge.execute_command("Get-MgUser")
        assert result.success is False
        assert "Authentication failed" in result.error_message
        assert "expired" in result.error_message
    
    def test_partial_success_handling(self, bridge, mock_subprocess):
        """部分的成功のハンドリング"""
        # 一部のデータ取得に成功、一部失敗
        partial_data = {
            "value": [
                {"displayName": "User 1", "mail": "user1@example.com"},
                {"displayName": "User 2", "mail": "user2@example.com"}
            ],
            "@odata.nextLink": "https://graph.microsoft.com/v1.0/users?$skiptoken=...",
            "error": {
                "code": "Request_ResourceNotFound",
                "message": "Resource 'User3' does not exist."
            }
        }
        
        mock_subprocess.return_value = Mock(
            returncode=0,  # 部分的成功
            stdout=json.dumps(partial_data),
            stderr=""
        )
        
        result = bridge.get_users()
        assert result.success is True
        assert len(result.data["value"]) == 2
        assert "error" in result.data