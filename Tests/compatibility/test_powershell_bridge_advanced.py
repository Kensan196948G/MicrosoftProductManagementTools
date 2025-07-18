"""
PowerShellブリッジ高度機能テスト

PowerShellブリッジの高度な機能（再試行、非同期、バッチ処理、永続セッション）をテストします。
"""

import pytest
import asyncio
import time
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from concurrent.futures import ThreadPoolExecutor
import sys

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from src.core.powershell_bridge import PowerShellBridge, PowerShellResult, PowerShellCompatibilityLayer


@pytest.mark.compatibility
@pytest.mark.unit
class TestPowerShellBridgeAdvanced:
    """PowerShellブリッジ高度機能テスト"""
    
    @pytest.fixture
    def mock_bridge(self):
        """モックPowerShellブリッジ"""
        with patch('src.core.powershell_bridge.PowerShellBridge._find_powershell') as mock_find:
            mock_find.return_value = 'pwsh'
            bridge = PowerShellBridge()
            return bridge
    
    @pytest.fixture
    def mock_subprocess(self):
        """subprocess.runのモック"""
        with patch('src.core.powershell_bridge.subprocess.run') as mock_run:
            yield mock_run
    
    def test_retry_mechanism_success_after_failure(self, mock_bridge, mock_subprocess):
        """再試行メカニズムのテスト - 失敗後の成功"""
        # 1回目失敗、2回目成功
        mock_subprocess.side_effect = [
            MagicMock(returncode=1, stdout="", stderr="Temporary failure"),
            MagicMock(returncode=0, stdout='{"result": "success"}', stderr="")
        ]
        
        result = mock_bridge.execute_with_retry("Get-TestData")
        
        assert result.success
        assert mock_subprocess.call_count == 2
        assert result.data == {"result": "success"}
    
    def test_retry_mechanism_max_retries(self, mock_bridge, mock_subprocess):
        """再試行メカニズムのテスト - 最大再試行回数"""
        # 常に失敗
        mock_subprocess.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="Persistent failure"
        )
        
        result = mock_bridge.execute_with_retry("Get-TestData")
        
        assert not result.success
        assert mock_subprocess.call_count == 3  # デフォルト3回
        assert "Persistent failure" in result.error_message
    
    def test_retry_mechanism_no_retry_on_auth_error(self, mock_bridge, mock_subprocess):
        """認証エラーでは再試行しない"""
        mock_subprocess.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="Unauthorized access"
        )
        
        result = mock_bridge.execute_with_retry("Get-TestData")
        
        assert not result.success
        assert mock_subprocess.call_count == 1  # 再試行なし
        assert "Unauthorized access" in result.stderr
    
    @pytest.mark.asyncio
    async def test_async_command_execution(self, mock_bridge, mock_subprocess):
        """非同期コマンド実行テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout='{"data": "async_result"}',
            stderr=""
        )
        
        result = await mock_bridge.execute_command_async("Get-AsyncData")
        
        assert result.success
        assert result.data == {"data": "async_result"}
    
    @pytest.mark.asyncio
    async def test_async_batch_execution(self, mock_bridge, mock_subprocess):
        """非同期バッチ実行テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout='{"result": "batch_success"}',
            stderr=""
        )
        
        commands = ["Get-Data1", "Get-Data2", "Get-Data3"]
        results = await mock_bridge.execute_batch_async(commands)
        
        assert len(results) == 3
        assert all(result.success for result in results)
        assert mock_subprocess.call_count == 3
    
    def test_parallel_batch_execution(self, mock_bridge, mock_subprocess):
        """並列バッチ実行テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout='{"result": "parallel_success"}',
            stderr=""
        )
        
        commands = ["Get-Data1", "Get-Data2", "Get-Data3"]
        results = mock_bridge.execute_batch(commands, parallel=True)
        
        assert len(results) == 3
        assert all(result.success for result in results)
        assert mock_subprocess.call_count == 3
    
    def test_sequential_batch_execution(self, mock_bridge, mock_subprocess):
        """順次バッチ実行テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout='{"result": "sequential_success"}',
            stderr=""
        )
        
        commands = ["Get-Data1", "Get-Data2", "Get-Data3"]
        results = mock_bridge.execute_batch(commands, parallel=False)
        
        assert len(results) == 3
        assert all(result.success for result in results)
        assert mock_subprocess.call_count == 3
    
    def test_pipeline_execution(self, mock_bridge, mock_subprocess):
        """パイプライン実行テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout='{"pipeline": "result"}',
            stderr=""
        )
        
        commands = ["Get-Users", "Select-Object Name", "Sort-Object Name"]
        result = mock_bridge.execute_pipeline(commands)
        
        assert result.success
        assert result.data == {"pipeline": "result"}
        
        # パイプラインコマンドが正しく構築されているか確認
        called_args = mock_subprocess.call_args[0][0]
        assert "Get-Users | Select-Object Name | Sort-Object Name" in called_args[-1]
    
    def test_persistent_session_creation(self, mock_bridge, mock_subprocess):
        """永続セッション作成テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout="12345",
            stderr=""
        )
        
        result = mock_bridge.create_persistent_session()
        
        assert result
        assert mock_bridge._session_id == "12345"
        assert mock_bridge._persistent_session
    
    def test_persistent_session_cleanup(self, mock_bridge, mock_subprocess):
        """永続セッションクリーンアップテスト"""
        mock_bridge._persistent_session = True
        mock_bridge._session_id = "12345"
        
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout="",
            stderr=""
        )
        
        mock_bridge.cleanup()
        
        assert mock_bridge._persistent_session is None
        assert mock_bridge._session_id is None
    
    def test_module_import_caching(self, mock_bridge, mock_subprocess):
        """モジュールインポートキャッシュテスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout="",
            stderr=""
        )
        
        # テスト用の一時モジュールファイルを作成
        module_path = mock_bridge.project_root / 'Scripts' / 'Common' / 'TestModule.psm1'
        module_path.parent.mkdir(parents=True, exist_ok=True)
        module_path.touch()
        
        try:
            # 1回目のインポート
            result1 = mock_bridge.import_module("TestModule")
            assert result1
            
            # 2回目のインポート（キャッシュされる）
            result2 = mock_bridge.import_module("TestModule")
            assert result2
            
            # キャッシュされているか確認
            assert "TestModule" in mock_bridge._module_cache
            assert mock_subprocess.call_count == 2  # 初回だけ実行
        finally:
            module_path.unlink(missing_ok=True)
    
    def test_type_conversion_powershell_to_python(self, mock_bridge):
        """PowerShellからPythonへの型変換テスト"""
        # 基本型
        assert mock_bridge._convert_ps_to_python("string") == "string"
        assert mock_bridge._convert_ps_to_python(123) == 123
        assert mock_bridge._convert_ps_to_python(True) == True
        
        # 配列
        ps_array = ["item1", "item2", {"key": "value"}]
        py_array = mock_bridge._convert_ps_to_python(ps_array)
        assert py_array == ["item1", "item2", {"key": "value"}]
        
        # PSCustomObject
        ps_object = {
            "Name": "Test",
            "Value": 42,
            "NestedObject": {"NestedKey": "NestedValue"}
        }
        py_object = mock_bridge._convert_ps_to_python(ps_object)
        assert py_object == ps_object
        
        # DateTime変換
        ps_datetime = "/Date(1642492800000)/"
        py_datetime = mock_bridge._convert_ps_to_python(ps_datetime)
        assert hasattr(py_datetime, 'year')
    
    def test_type_conversion_python_to_powershell(self, mock_bridge):
        """PythonからPowerShellへの型変換テスト"""
        # 基本型
        assert mock_bridge._convert_python_to_ps(None) == '$null'
        assert mock_bridge._convert_python_to_ps(True) == '$true'
        assert mock_bridge._convert_python_to_ps(False) == '$false'
        assert mock_bridge._convert_python_to_ps(123) == '123'
        assert mock_bridge._convert_python_to_ps("test") == "'test'"
        
        # 配列
        py_array = ["item1", "item2", 123]
        ps_array = mock_bridge._convert_python_to_ps(py_array)
        assert ps_array == "@('item1','item2',123)"
        
        # 辞書
        py_dict = {"key1": "value1", "key2": 42}
        ps_dict = mock_bridge._convert_python_to_ps(py_dict)
        assert "'key1'='value1'" in ps_dict
        assert "'key2'=42" in ps_dict
        
        # エスケープ処理
        special_string = 'String with "quotes" and \'apostrophes\''
        ps_string = mock_bridge._convert_python_to_ps(special_string)
        assert "`\"" in ps_string  # エスケープされた引用符
        assert "''" in ps_string  # エスケープされたアポストロフィ
    
    def test_context_manager_usage(self, mock_bridge, mock_subprocess):
        """コンテキストマネージャーの使用テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout='{"result": "context_test"}',
            stderr=""
        )
        
        with mock_bridge as bridge:
            result = bridge.execute_command("Get-TestData")
            assert result.success
        
        # コンテキスト終了時にクリーンアップが呼ばれるか確認
        # （実際のテストでは Executorがshutdownされているかチェック）
        assert bridge.executor._shutdown
    
    def test_timeout_handling(self, mock_bridge, mock_subprocess):
        """タイムアウト処理テスト"""
        import subprocess
        mock_subprocess.side_effect = subprocess.TimeoutExpired(
            cmd="pwsh", timeout=5
        )
        
        result = mock_bridge.execute_command("Start-Sleep -Seconds 10", timeout=1)
        
        assert not result.success
        assert "タイムアウト" in result.error_message
        assert result.returncode == -1
    
    def test_error_handling_with_json_error(self, mock_bridge, mock_subprocess):
        """JSON形式のエラーハンドリングテスト"""
        error_json = '{"Message": "Test error", "Type": "TestException"}'
        mock_subprocess.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr=error_json
        )
        
        result = mock_bridge.execute_command("Get-ErrorData")
        
        assert not result.success
        assert result.error_message == "Test error"
        assert result.data["Type"] == "TestException"
    
    def test_command_parameter_handling(self, mock_bridge, mock_subprocess):
        """コマンドパラメータ処理テスト"""
        mock_subprocess.return_value = MagicMock(
            returncode=0,
            stdout='{"result": "param_test"}',
            stderr=""
        )
        
        # 関数呼び出しでパラメータを渡す
        result = mock_bridge.call_function(
            "Get-TestData",
            Name="TestUser",
            Count=10,
            Enabled=True,
            Properties=["Name", "Email"],
            Metadata={"source": "test", "version": "1.0"}
        )
        
        assert result.success
        
        # パラメータが正しく構築されているか確認
        called_command = mock_subprocess.call_args[0][0][-1]
        assert "-Name 'TestUser'" in called_command
        assert "-Count 10" in called_command
        assert "-Enabled" in called_command
        assert "-Properties @(\"Name\",\"Email\")" in called_command
        assert "-Metadata @{source=\"test\";version=\"1.0\"}" in called_command


@pytest.mark.compatibility
@pytest.mark.unit
class TestPowerShellCompatibilityLayer:
    """PowerShell互換性レイヤーテスト"""
    
    @pytest.fixture
    def mock_bridge(self):
        """モックブリッジ"""
        bridge = Mock(spec=PowerShellBridge)
        bridge.call_function = Mock(return_value=PowerShellResult(
            stdout='{"result": "success"}',
            stderr="",
            returncode=0,
            data={"result": "success"},
            success=True
        ))
        bridge.import_module = Mock(return_value=True)
        return bridge
    
    @pytest.fixture
    def compat_layer(self, mock_bridge):
        """互換性レイヤー"""
        return PowerShellCompatibilityLayer(mock_bridge)
    
    def test_function_mapping_dynamic_resolution(self, compat_layer):
        """動的関数解決テスト"""
        # 定義されている関数
        result = compat_layer.get_users(Property=['displayName'])
        
        # モックブリッジの call_function が呼ばれるか確認
        compat_layer.bridge.call_function.assert_called_once_with(
            'Get-MgUser',
            Property=['displayName']
        )
        
        assert result.success
        assert result.data == {"result": "success"}
    
    def test_function_mapping_invalid_function(self, compat_layer):
        """無効な関数名のテスト"""
        with pytest.raises(AttributeError):
            compat_layer.nonexistent_function()
    
    def test_common_modules_import(self, compat_layer):
        """共通モジュール一括インポートテスト"""
        compat_layer.import_common_modules()
        
        expected_modules = [
            'Common',
            'Authentication',
            'Logging',
            'ErrorHandling', 
            'ReportGenerator',
            'RealM365DataProvider'
        ]
        
        # 各モジュールがインポートされているか確認
        for module in expected_modules:
            compat_layer.bridge.import_module.assert_any_call(module)
    
    def test_microsoft365_api_calls(self, compat_layer):
        """Microsoft 365 API呼び出しテスト"""
        # ユーザー取得
        compat_layer.get_users(Filter="department eq 'IT'")
        compat_layer.bridge.call_function.assert_called_with(
            'Get-MgUser',
            Filter="department eq 'IT'"
        )
        
        # ライセンス取得
        compat_layer.get_licenses()
        compat_layer.bridge.call_function.assert_called_with('Get-MgSubscribedSku')
        
        # グループ取得
        compat_layer.get_groups(Top=50)
        compat_layer.bridge.call_function.assert_called_with(
            'Get-MgGroup',
            Top=50
        )
    
    def test_exchange_management_calls(self, compat_layer):
        """Exchange管理呼び出しテスト"""
        # メールボックス取得
        compat_layer.get_mailboxes(ResultSize=100)
        compat_layer.bridge.call_function.assert_called_with(
            'Get-Mailbox',
            ResultSize=100
        )
        
        # メールボックス統計
        compat_layer.get_mailbox_statistics(Identity='user@contoso.com')
        compat_layer.bridge.call_function.assert_called_with(
            'Get-MailboxStatistics',
            Identity='user@contoso.com'
        )
    
    def test_teams_management_calls(self, compat_layer):
        """Teams管理呼び出しテスト"""
        # Teams取得
        compat_layer.get_teams()
        compat_layer.bridge.call_function.assert_called_with('Get-Team')
        
        # Teams使用状況
        compat_layer.get_teams_usage()
        compat_layer.bridge.call_function.assert_called_with('Get-TeamsUsageReport')
    
    def test_report_generation_calls(self, compat_layer):
        """レポート生成呼び出しテスト"""
        # HTMLレポート生成
        compat_layer.new_html_report(
            Data=[{"Name": "Test", "Value": 42}],
            Title="Test Report"
        )
        compat_layer.bridge.call_function.assert_called_with(
            'New-HTMLReport',
            Data=[{"Name": "Test", "Value": 42}],
            Title="Test Report"
        )
        
        # CSVレポート出力
        compat_layer.export_csv_report(
            Data=[{"Name": "Test", "Value": 42}],
            Path="test.csv"
        )
        compat_layer.bridge.call_function.assert_called_with(
            'Export-CSVReport',
            Data=[{"Name": "Test", "Value": 42}],
            Path="test.csv"
        )


@pytest.mark.compatibility
@pytest.mark.integration
@pytest.mark.performance
class TestPowerShellBridgePerformance:
    """PowerShellブリッジパフォーマンステスト"""
    
    @pytest.fixture
    def bridge(self):
        """実際のブリッジ（PowerShell実行可能な環境用）"""
        try:
            return PowerShellBridge()
        except RuntimeError:
            pytest.skip("PowerShellが利用できません")
    
    @pytest.mark.slow
    def test_large_dataset_processing(self, bridge):
        """大規模データセット処理テスト"""
        # 1000件のデータを生成して処理
        command = """
        $data = @()
        1..1000 | ForEach-Object {
            $data += @{
                ID = $_
                Name = "User$_"
                Email = "user$_@contoso.com"
                Department = "Dept$(($_ % 10) + 1)"
            }
        }
        $data
        """
        
        start_time = time.time()
        result = bridge.execute_command(command)
        end_time = time.time()
        
        assert result.success
        assert isinstance(result.data, list)
        assert len(result.data) == 1000
        
        # パフォーマンス目標: 10秒以内
        execution_time = end_time - start_time
        assert execution_time < 10, f"実行時間が遅すぎます: {execution_time:.2f}秒"
    
    @pytest.mark.slow
    def test_concurrent_command_execution(self, bridge):
        """並行コマンド実行テスト"""
        commands = [
            "Get-Date",
            "Get-Process | Select-Object -First 5",
            "Get-Service | Select-Object -First 5",
            "Get-ChildItem C:\\ | Select-Object -First 5"
        ]
        
        start_time = time.time()
        results = bridge.execute_batch(commands, parallel=True)
        end_time = time.time()
        
        assert len(results) == 4
        assert all(result.success for result in results)
        
        # 並列実行により時間短縮されているか確認
        execution_time = end_time - start_time
        assert execution_time < 5, f"並列実行時間が遅すぎます: {execution_time:.2f}秒"
    
    @pytest.mark.slow
    def test_memory_usage_monitoring(self, bridge):
        """メモリ使用量監視テスト"""
        import psutil
        
        process = psutil.Process()
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # 複数のコマンドを実行
        for i in range(10):
            command = f"1..100 | ForEach-Object {{ @{{ID=$_; Name='User$_'}} }}"
            result = bridge.execute_command(command)
            assert result.success
        
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_increase = final_memory - initial_memory
        
        # メモリ増加量が閾値以下であることを確認
        assert memory_increase < 50, f"メモリ使用量が増加しすぎです: {memory_increase:.2f}MB"
    
    def test_module_import_performance(self, bridge):
        """モジュールインポートパフォーマンステスト"""
        # キャッシュクリア
        bridge.import_module.cache_clear()
        
        # 初回インポート時間測定
        start_time = time.time()
        result1 = bridge.import_module("Common")
        first_import_time = time.time() - start_time
        
        # 2回目インポート時間測定（キャッシュ使用）
        start_time = time.time()
        result2 = bridge.import_module("Common")
        second_import_time = time.time() - start_time
        
        # キャッシュ使用により高速化されているか確認
        assert second_import_time < first_import_time / 2, \
            f"キャッシュが効果的に動作していません: {second_import_time:.4f}s vs {first_import_time:.4f}s"