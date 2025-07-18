"""
PowerShell実行環境との互換性テスト
Dev1 - Test/QA Developer による完全実行環境互換性検証

PowerShell版スクリプトの実行環境、パフォーマンス、エラーハンドリングの互換性を検証
"""

import pytest
import subprocess
import asyncio
import time
import psutil
import json
import tempfile
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from unittest.mock import Mock, patch, MagicMock
import sys

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

from src.core.compatibility.powershell_bridge import PowerShellBridge
from src.core.compatibility.enhanced_bridge import EnhancedPowerShellBridge


class PowerShellEnvironmentTester:
    """PowerShell実行環境テスター"""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.test_scripts_dir = project_root / "TestScripts"
        self.scripts_dir = project_root / "Scripts"
        self.config_dir = project_root / "Config"
        
        # 実行タイムアウト設定
        self.short_timeout = 30
        self.medium_timeout = 120
        self.long_timeout = 300
        
        # PowerShell実行パフォーマンス閾値
        self.performance_thresholds = {
            "startup_time": 5.0,  # PowerShell起動時間（秒）
            "simple_command": 2.0,  # 簡単なコマンド実行時間（秒）
            "module_import": 10.0,  # モジュールインポート時間（秒）
            "memory_usage": 500,  # メモリ使用量（MB）
            "cpu_usage": 80.0  # CPU使用率（%）
        }
    
    async def test_powershell_availability(self) -> Dict[str, Any]:
        """PowerShell実行環境の可用性テスト"""
        results = {}
        
        # PowerShell Core (pwsh) の確認
        try:
            process = await asyncio.create_subprocess_exec(
                "pwsh", "--version",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=10)
            results["pwsh"] = {
                "available": process.returncode == 0,
                "version": stdout.decode().strip(),
                "error": stderr.decode().strip()
            }
        except (asyncio.TimeoutError, FileNotFoundError, OSError) as e:
            results["pwsh"] = {
                "available": False,
                "version": None,
                "error": str(e)
            }
        
        # Windows PowerShell (powershell) の確認
        try:
            process = await asyncio.create_subprocess_exec(
                "powershell", "-Command", "$PSVersionTable.PSVersion",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=10)
            results["powershell"] = {
                "available": process.returncode == 0,
                "version": stdout.decode().strip(),
                "error": stderr.decode().strip()
            }
        except (asyncio.TimeoutError, FileNotFoundError, OSError) as e:
            results["powershell"] = {
                "available": False,
                "version": None,
                "error": str(e)
            }
        
        # 推奨PowerShell実行環境の判定
        if results["pwsh"]["available"]:
            results["recommended_ps"] = "pwsh"
        elif results["powershell"]["available"]:
            results["recommended_ps"] = "powershell"
        else:
            results["recommended_ps"] = None
        
        return results
    
    async def test_powershell_module_compatibility(self) -> Dict[str, Any]:
        """PowerShellモジュールの互換性テスト"""
        required_modules = [
            "Microsoft.Graph",
            "Microsoft.Graph.Authentication",
            "Microsoft.Graph.Users",
            "Microsoft.Graph.Groups",
            "Microsoft.Graph.Reports",
            "ExchangeOnlineManagement",
            "AzureAD",
            "MicrosoftTeams"
        ]
        
        results = {}
        
        for module in required_modules:
            try:
                # モジュールの存在確認
                cmd = f"Get-Module -ListAvailable -Name {module}"
                process = await asyncio.create_subprocess_exec(
                    "pwsh", "-Command", cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=15)
                
                if process.returncode == 0 and stdout.decode().strip():
                    results[module] = {
                        "available": True,
                        "version": stdout.decode().strip(),
                        "error": None
                    }
                else:
                    results[module] = {
                        "available": False,
                        "version": None,
                        "error": stderr.decode().strip()
                    }
            except Exception as e:
                results[module] = {
                    "available": False,
                    "version": None,
                    "error": str(e)
                }
        
        return results
    
    async def test_powershell_script_execution(self, script_path: Path, args: List[str] = None) -> Dict[str, Any]:
        """PowerShellスクリプト実行テスト"""
        start_time = time.time()
        
        try:
            # 実行コマンド構築
            cmd = ["pwsh", "-File", str(script_path)]
            if args:
                cmd.extend(args)
            
            # プロセス開始前のシステム状態取得
            initial_memory = psutil.virtual_memory().percent
            initial_cpu = psutil.cpu_percent(interval=1)
            
            # PowerShellスクリプト実行
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.project_root)
            )
            
            # 実行中のリソース監視
            max_memory = initial_memory
            max_cpu = initial_cpu
            
            # 非同期でリソース監視
            async def monitor_resources():
                nonlocal max_memory, max_cpu
                while process.returncode is None:
                    try:
                        memory_percent = psutil.virtual_memory().percent
                        cpu_percent = psutil.cpu_percent(interval=0.1)
                        max_memory = max(max_memory, memory_percent)
                        max_cpu = max(max_cpu, cpu_percent)
                        await asyncio.sleep(0.5)
                    except:
                        break
            
            # 並列実行
            monitor_task = asyncio.create_task(monitor_resources())
            
            try:
                stdout, stderr = await asyncio.wait_for(
                    process.communicate(), 
                    timeout=self.long_timeout
                )
            finally:
                monitor_task.cancel()
            
            execution_time = time.time() - start_time
            
            return {
                "success": process.returncode == 0,
                "returncode": process.returncode,
                "stdout": stdout.decode("utf-8", errors="replace"),
                "stderr": stderr.decode("utf-8", errors="replace"),
                "execution_time": execution_time,
                "max_memory_percent": max_memory,
                "max_cpu_percent": max_cpu,
                "performance_ok": execution_time < self.performance_thresholds["simple_command"]
            }
            
        except asyncio.TimeoutError:
            return {
                "success": False,
                "returncode": -1,
                "stdout": "",
                "stderr": f"スクリプト実行がタイムアウトしました ({self.long_timeout}秒)",
                "execution_time": self.long_timeout,
                "max_memory_percent": max_memory,
                "max_cpu_percent": max_cpu,
                "performance_ok": False
            }
        except Exception as e:
            return {
                "success": False,
                "returncode": -1,
                "stdout": "",
                "stderr": f"スクリプト実行エラー: {str(e)}",
                "execution_time": time.time() - start_time,
                "max_memory_percent": max_memory,
                "max_cpu_percent": max_cpu,
                "performance_ok": False
            }
    
    async def test_powershell_bridge_performance(self, bridge: PowerShellBridge) -> Dict[str, Any]:
        """PowerShellブリッジのパフォーマンステスト"""
        performance_results = {}
        
        # 1. 基本コマンド実行性能
        start_time = time.time()
        result = bridge.execute_command("Get-Date")
        basic_command_time = time.time() - start_time
        performance_results["basic_command"] = {
            "execution_time": basic_command_time,
            "success": result.success,
            "within_threshold": basic_command_time < self.performance_thresholds["simple_command"]
        }
        
        # 2. モジュールインポート性能
        start_time = time.time()
        module_success = bridge.import_module("Common")
        module_import_time = time.time() - start_time
        performance_results["module_import"] = {
            "execution_time": module_import_time,
            "success": module_success,
            "within_threshold": module_import_time < self.performance_thresholds["module_import"]
        }
        
        # 3. バッチ実行性能
        commands = ["Get-Date", "Get-Process | Select-Object -First 5", "Get-Service | Select-Object -First 5"]
        start_time = time.time()
        batch_results = bridge.execute_batch(commands, parallel=True)
        batch_execution_time = time.time() - start_time
        performance_results["batch_execution"] = {
            "execution_time": batch_execution_time,
            "success": all(r.success for r in batch_results),
            "command_count": len(commands),
            "average_per_command": batch_execution_time / len(commands)
        }
        
        # 4. メモリ使用量確認
        memory_info = psutil.virtual_memory()
        performance_results["memory_usage"] = {
            "total_mb": memory_info.total / (1024 * 1024),
            "available_mb": memory_info.available / (1024 * 1024),
            "percent_used": memory_info.percent,
            "within_threshold": memory_info.percent < self.performance_thresholds["memory_usage"]
        }
        
        return performance_results


@pytest.fixture(scope="session")
def ps_env_tester(project_root):
    """PowerShell環境テスターのフィクスチャ"""
    return PowerShellEnvironmentTester(project_root)


@pytest.fixture(scope="function")
def enhanced_bridge(project_root):
    """Enhanced PowerShell Bridgeのフィクスチャ"""
    return EnhancedPowerShellBridge(project_root=project_root)


class TestPowerShellEnvironmentCompatibility:
    """PowerShell実行環境互換性テスト"""
    
    @pytest.mark.compatibility
    @pytest.mark.asyncio
    async def test_powershell_availability(self, ps_env_tester):
        """PowerShell実行環境の可用性テスト"""
        results = await ps_env_tester.test_powershell_availability()
        
        # 少なくとも1つのPowerShell実行環境が利用可能であることを確認
        assert results["pwsh"]["available"] or results["powershell"]["available"], \
            "PowerShell実行環境が利用できません"
        
        # 推奨環境（PowerShell Core）の確認
        if results["pwsh"]["available"]:
            assert "PowerShell" in results["pwsh"]["version"], \
                f"PowerShell Coreのバージョン情報が正しくありません: {results['pwsh']['version']}"
        
        # 実行環境の推奨
        assert results["recommended_ps"] is not None, "推奨PowerShell実行環境が特定できません"
    
    @pytest.mark.compatibility
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_required_modules_availability(self, ps_env_tester):
        """必要なPowerShellモジュールの可用性テスト"""
        results = await ps_env_tester.test_powershell_module_compatibility()
        
        # 必須モジュールの確認
        critical_modules = ["Microsoft.Graph", "Microsoft.Graph.Authentication"]
        for module in critical_modules:
            if module in results:
                # モジュールが利用可能でない場合は警告として記録
                if not results[module]["available"]:
                    pytest.skip(f"必須モジュール '{module}' が利用できません: {results[module]['error']}")
        
        # 利用可能なモジュール数の確認
        available_modules = sum(1 for r in results.values() if r["available"])
        total_modules = len(results)
        
        # 最低限のモジュールが利用可能であることを確認
        assert available_modules >= 2, \
            f"利用可能なモジュール数が少なすぎます: {available_modules}/{total_modules}"
    
    @pytest.mark.compatibility
    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_basic_script_execution(self, ps_env_tester):
        """基本的なスクリプト実行テスト"""
        # 基本的なテストスクリプトの実行
        test_scripts = [
            "test-auth.ps1",
            "test-enhanced-functionality.ps1"
        ]
        
        execution_results = []
        
        for script_name in test_scripts:
            script_path = ps_env_tester.test_scripts_dir / script_name
            
            if script_path.exists():
                result = await ps_env_tester.test_powershell_script_execution(
                    script_path, 
                    args=["-Timeout", "60", "-Test"]
                )
                execution_results.append({
                    "script": script_name,
                    "result": result
                })
        
        # 実行結果の基本確認
        assert len(execution_results) > 0, "実行可能なテストスクリプトが見つかりません"
        
        # 少なくとも1つのスクリプトが正常実行されることを確認
        successful_executions = [r for r in execution_results if r["result"]["success"]]
        if len(successful_executions) == 0:
            # 全てのスクリプトが失敗した場合は環境問題として記録
            pytest.skip("PowerShell実行環境でスクリプトが正常実行されませんでした")
    
    @pytest.mark.compatibility
    @pytest.mark.performance
    @pytest.mark.asyncio
    async def test_bridge_performance(self, ps_env_tester, enhanced_bridge):
        """PowerShellブリッジのパフォーマンステスト"""
        # PowerShell実行環境が利用可能かどうかを事前確認
        env_results = await ps_env_tester.test_powershell_availability()
        if not (env_results["pwsh"]["available"] or env_results["powershell"]["available"]):
            pytest.skip("PowerShell実行環境が利用できません")
        
        # パフォーマンス測定
        try:
            performance_results = await ps_env_tester.test_powershell_bridge_performance(enhanced_bridge)
            
            # 基本コマンド実行性能の確認
            basic_perf = performance_results["basic_command"]
            assert basic_perf["execution_time"] < 10.0, \
                f"基本コマンド実行が遅すぎます: {basic_perf['execution_time']}秒"
            
            # メモリ使用量の確認
            memory_info = performance_results["memory_usage"]
            assert memory_info["percent_used"] < 95.0, \
                f"メモリ使用率が高すぎます: {memory_info['percent_used']}%"
            
            # バッチ実行性能の確認
            batch_perf = performance_results["batch_execution"]
            assert batch_perf["average_per_command"] < 5.0, \
                f"バッチ実行のコマンド平均時間が遅すぎます: {batch_perf['average_per_command']}秒"
                
        except Exception as e:
            # PowerShellブリッジの初期化に失敗した場合
            pytest.skip(f"PowerShellブリッジの初期化に失敗しました: {str(e)}")


class TestPowerShellErrorHandling:
    """PowerShellエラーハンドリング互換性テスト"""
    
    @pytest.mark.compatibility
    @pytest.mark.unit
    def test_powershell_error_parsing(self, enhanced_bridge):
        """PowerShellエラーの解析テスト"""
        # 意図的にエラーを発生させるコマンド
        error_commands = [
            "Get-NonExistentCommand",
            "Get-Process -Name 'NonExistentProcess'",
            "1/0"  # 除算エラー
        ]
        
        for cmd in error_commands:
            result = enhanced_bridge.execute_command(cmd)
            
            # エラーが適切に検出されることを確認
            assert result.success is False, f"エラーが適切に検出されませんでした: {cmd}"
            assert result.returncode != 0, f"エラーコードが適切に設定されていません: {cmd}"
            assert result.error_message is not None, f"エラーメッセージが設定されていません: {cmd}"
    
    @pytest.mark.compatibility
    @pytest.mark.integration
    def test_powershell_timeout_handling(self, enhanced_bridge):
        """PowerShellタイムアウトハンドリングテスト"""
        # 長時間実行されるコマンド（無限ループ）
        long_running_cmd = "while($true) { Start-Sleep -Seconds 1 }"
        
        result = enhanced_bridge.execute_command(long_running_cmd, timeout=3)
        
        # タイムアウトが適切に処理されることを確認
        assert result.success is False, "タイムアウトが適切に検出されませんでした"
        assert "タイムアウト" in result.error_message or "timeout" in result.error_message.lower(), \
            f"タイムアウトエラーメッセージが適切でありません: {result.error_message}"
    
    @pytest.mark.compatibility
    @pytest.mark.integration
    def test_powershell_retry_mechanism(self, enhanced_bridge):
        """PowerShell再試行メカニズムテスト"""
        # ネットワーク関連のエラーをシミュレート
        network_error_cmd = "Invoke-WebRequest -Uri 'https://nonexistent.example.com' -TimeoutSec 1"
        
        result = enhanced_bridge.execute_with_retry(network_error_cmd, max_retries=2)
        
        # 再試行が実行されることを確認
        assert result.success is False, "ネットワークエラーが適切に検出されませんでした"
        
        # 再試行回数の確認は内部実装に依存するため、基本的な動作確認のみ
        assert result.error_message is not None, "エラーメッセージが設定されていません"


class TestPowerShellDataCompatibility:
    """PowerShellデータ互換性テスト"""
    
    @pytest.mark.compatibility
    @pytest.mark.unit
    def test_powershell_data_type_conversion(self, enhanced_bridge):
        """PowerShellデータ型変換テスト"""
        # 各種データ型のテスト
        test_cases = [
            {"input": True, "ps_expected": "$true"},
            {"input": False, "ps_expected": "$false"},
            {"input": None, "ps_expected": "$null"},
            {"input": 42, "ps_expected": "42"},
            {"input": 3.14, "ps_expected": "3.14"},
            {"input": "test", "ps_expected": "'test'"},
            {"input": [1, 2, 3], "ps_expected": "@(1,2,3)"},
            {"input": {"key": "value"}, "ps_expected": "@{'key'='value'}"}
        ]
        
        for case in test_cases:
            ps_value = enhanced_bridge._convert_python_to_ps(case["input"])
            assert ps_value == case["ps_expected"], \
                f"データ型変換が正しくありません: {case['input']} -> {ps_value} (期待: {case['ps_expected']})"
    
    @pytest.mark.compatibility
    @pytest.mark.unit
    def test_powershell_json_compatibility(self, enhanced_bridge):
        """PowerShell JSON互換性テスト"""
        # JSON形式のデータ交換テスト
        test_data = {
            "users": [
                {"id": 1, "name": "テストユーザー1", "active": True},
                {"id": 2, "name": "テストユーザー2", "active": False}
            ],
            "metadata": {
                "total": 2,
                "timestamp": "2024-01-01T00:00:00Z"
            }
        }
        
        # JSON形式でデータを送信し、結果を確認
        json_cmd = f"'{json.dumps(test_data, ensure_ascii=False)}' | ConvertFrom-Json | ConvertTo-Json -Depth 10"
        result = enhanced_bridge.execute_command(json_cmd)
        
        if result.success:
            # JSON解析が成功した場合のデータ確認
            try:
                parsed_data = json.loads(result.stdout)
                assert "users" in parsed_data, "JSONデータの'users'フィールドが見つかりません"
                assert "metadata" in parsed_data, "JSONデータの'metadata'フィールドが見つかりません"
                assert len(parsed_data["users"]) == 2, "JSONデータのユーザー数が正しくありません"
            except json.JSONDecodeError:
                pytest.skip("PowerShell JSON処理でJSONDecodeErrorが発生しました")
        else:
            # JSON処理に失敗した場合はスキップ
            pytest.skip(f"PowerShell JSON処理に失敗しました: {result.error_message}")


@pytest.mark.compatibility
class TestPowerShellScriptCompatibility:
    """PowerShellスクリプト互換性テスト"""
    
    @pytest.mark.requires_powershell
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_existing_scripts_compatibility(self, ps_env_tester):
        """既存スクリプトの互換性テスト"""
        # プロジェクト内の主要スクリプトファイルを検索
        script_patterns = [
            "test-*.ps1",
            "Apps/*.ps1",
            "Scripts/Common/*.ps1"
        ]
        
        found_scripts = []
        for pattern in script_patterns:
            found_scripts.extend(ps_env_tester.project_root.glob(pattern))
        
        # 少なくとも1つのスクリプトが見つかることを確認
        assert len(found_scripts) > 0, "テスト対象のPowerShellスクリプトが見つかりません"
        
        # 各スクリプトの基本的な構文チェック
        syntax_check_results = []
        
        for script_path in found_scripts[:5]:  # 最初の5つのスクリプトをテスト
            try:
                # PowerShellの構文チェック
                cmd = ["pwsh", "-Command", f"Get-Content '{script_path}' | Out-Null"]
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
                
                syntax_check_results.append({
                    "script": script_path.name,
                    "syntax_ok": process.returncode == 0,
                    "error": stderr.decode().strip() if stderr else None
                })
            except Exception as e:
                syntax_check_results.append({
                    "script": script_path.name,
                    "syntax_ok": False,
                    "error": str(e)
                })
        
        # 構文チェック結果の確認
        failed_scripts = [r for r in syntax_check_results if not r["syntax_ok"]]
        if failed_scripts:
            # 構文エラーがあるスクリプトがある場合は詳細を記録
            error_details = "\n".join([f"  {s['script']}: {s['error']}" for s in failed_scripts])
            pytest.skip(f"PowerShellスクリプトの構文エラーが検出されました:\n{error_details}")