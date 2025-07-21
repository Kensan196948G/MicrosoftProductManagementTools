"""
PowerShellブリッジ統合システム
既存PowerShellスクリプトとPython環境の完全統合
"""

import asyncio
import json
import os
import subprocess
import tempfile
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Union
import aiofiles
from pydantic import BaseModel, Field

from ...core.config import settings
from ...core.logging_config import get_logger

logger = get_logger(__name__)

class PowerShellExecutionRequest(BaseModel):
    """PowerShell実行リクエスト"""
    script_path: Optional[str] = None
    script_content: Optional[str] = None
    function_name: Optional[str] = None
    parameters: Dict[str, Any] = Field(default_factory=dict)
    working_directory: Optional[str] = None
    timeout_seconds: int = Field(default=300)
    output_format: str = Field(default="json")  # json, csv, html, text
    use_legacy_mode: bool = Field(default=False)  # PowerShell 5.1 vs 7.x

class PowerShellExecutionResult(BaseModel):
    """PowerShell実行結果"""
    success: bool
    exit_code: int
    stdout: str
    stderr: str
    execution_time_seconds: float
    output_data: Optional[Any] = None
    error_details: Optional[Dict[str, Any]] = None
    execution_id: str
    timestamp: datetime

class PowerShellBridge:
    """PowerShellブリッジメインクラス"""
    
    def __init__(self):
        self.powershell_exe = self._detect_powershell_executable()
        self.script_base_path = Path(settings.base_dir) / "Scripts"
        self.temp_dir = Path(tempfile.gettempdir()) / "ms365_powershell_bridge"
        self.temp_dir.mkdir(exist_ok=True)
        
        # 機能マッピング（PowerShell関数 → Pythonエンドポイント）
        self.function_mappings = {
            "Get-M365Users": {
                "script": "EntraID/Get-EntraIDUsers.ps1",
                "function": "Get-EntraIDUsers",
                "output_format": "json"
            },
            "Get-M365Licenses": {
                "script": "EntraID/Get-LicenseAnalysis.ps1",
                "function": "Get-LicenseAnalysis", 
                "output_format": "json"
            },
            "Get-ExchangeMailboxes": {
                "script": "EXO/Get-MailboxAnalysis.ps1",
                "function": "Get-MailboxAnalysis",
                "output_format": "csv"
            },
            "Generate-DailyReport": {
                "script": "Common/ScheduledReports.ps1",
                "function": "Generate-DailyReport",
                "output_format": "html"
            },
            "Test-M365Authentication": {
                "script": "TestScripts/test-auth.ps1",
                "function": "Test-AllAuthentication",
                "output_format": "json"
            }
        }
        
    def _detect_powershell_executable(self) -> str:
        """PowerShell実行ファイル検出"""
        # PowerShell 7.x 優先
        candidates = [
            "pwsh",  # PowerShell 7.x
            "powershell"  # PowerShell 5.1
        ]
        
        for candidate in candidates:
            try:
                result = subprocess.run(
                    [candidate, "-Command", "$PSVersionTable.PSVersion.Major"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                if result.returncode == 0:
                    version = result.stdout.strip()
                    logger.info(f"Detected PowerShell {version}: {candidate}")
                    return candidate
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
        
        raise RuntimeError("PowerShell not found on system")
    
    async def execute_script(self, request: PowerShellExecutionRequest) -> PowerShellExecutionResult:
        """PowerShellスクリプト実行"""
        execution_id = str(uuid.uuid4())
        start_time = datetime.utcnow()
        
        try:
            # スクリプトパス解決
            script_path = await self._resolve_script_path(request)
            
            # 実行環境準備
            execution_env = await self._prepare_execution_environment(request, execution_id)
            
            # PowerShellコマンド構築
            ps_command = await self._build_powershell_command(request, script_path, execution_env)
            
            # 実行
            logger.info(f"Executing PowerShell script: {script_path}")
            result = await self._execute_powershell_command(ps_command, request.timeout_seconds)
            
            # 結果解析
            execution_time = (datetime.utcnow() - start_time).total_seconds()
            output_data = await self._parse_output(result.stdout, request.output_format)
            
            return PowerShellExecutionResult(
                success=result.returncode == 0,
                exit_code=result.returncode,
                stdout=result.stdout,
                stderr=result.stderr,
                execution_time_seconds=execution_time,
                output_data=output_data,
                execution_id=execution_id,
                timestamp=start_time
            )
            
        except Exception as e:
            execution_time = (datetime.utcnow() - start_time).total_seconds()
            logger.error(f"PowerShell execution failed: {e}")
            
            return PowerShellExecutionResult(
                success=False,
                exit_code=-1,
                stdout="",
                stderr=str(e),
                execution_time_seconds=execution_time,
                error_details={"exception": str(e), "type": type(e).__name__},
                execution_id=execution_id,
                timestamp=start_time
            )
        finally:
            # クリーンアップ
            await self._cleanup_execution_environment(execution_id)
    
    async def _resolve_script_path(self, request: PowerShellExecutionRequest) -> Path:
        """スクリプトパス解決"""
        if request.script_content:
            # インラインスクリプトの場合は一時ファイル作成
            temp_script = self.temp_dir / f"inline_{uuid.uuid4().hex}.ps1"
            async with aiofiles.open(temp_script, 'w', encoding='utf-8') as f:
                await f.write(request.script_content)
            return temp_script
        
        elif request.script_path:
            script_path = Path(request.script_path)
            
            # 相対パスの場合はScriptsディレクトリからの相対
            if not script_path.is_absolute():
                script_path = self.script_base_path / script_path
            
            if not script_path.exists():
                raise FileNotFoundError(f"Script not found: {script_path}")
            
            return script_path
        
        else:
            raise ValueError("Either script_path or script_content must be provided")
    
    async def _prepare_execution_environment(self, request: PowerShellExecutionRequest, execution_id: str) -> Dict[str, Any]:
        """実行環境準備"""
        env_dir = self.temp_dir / execution_id
        env_dir.mkdir(exist_ok=True)
        
        # パラメータファイル作成
        params_file = env_dir / "parameters.json"
        async with aiofiles.open(params_file, 'w', encoding='utf-8') as f:
            await f.write(json.dumps(request.parameters, indent=2, ensure_ascii=False))
        
        # 設定ファイルコピー
        config_source = Path(settings.base_dir) / "Config" / "appsettings.json"
        config_target = env_dir / "appsettings.json"
        
        if config_source.exists():
            async with aiofiles.open(config_source, 'r', encoding='utf-8') as src:
                content = await src.read()
            async with aiofiles.open(config_target, 'w', encoding='utf-8') as dst:
                await dst.write(content)
        
        return {
            "env_dir": env_dir,
            "params_file": params_file,
            "config_file": config_target,
            "working_directory": request.working_directory or str(self.script_base_path)
        }
    
    async def _build_powershell_command(self, request: PowerShellExecutionRequest, script_path: Path, env: Dict[str, Any]) -> List[str]:
        """PowerShellコマンド構築"""
        powershell_exe = "powershell" if request.use_legacy_mode else self.powershell_exe
        
        # 基本コマンド
        command = [
            powershell_exe,
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-OutputFormat", "Text"
        ]
        
        # スクリプト実行コマンド構築
        script_commands = []
        
        # 共通モジュールのインポート
        common_module = self.script_base_path / "Common" / "Common.psm1"
        if common_module.exists():
            script_commands.append(f"Import-Module '{common_module}' -Force")
        
        # 作業ディレクトリ設定
        script_commands.append(f"Set-Location '{env['working_directory']}'")
        
        # パラメータ読み込み
        script_commands.append(f"$Parameters = Get-Content '{env['params_file']}' | ConvertFrom-Json")
        
        # スクリプト実行
        if request.function_name:
            # 特定関数実行
            script_commands.append(f". '{script_path}'")
            
            # パラメータ展開
            if request.parameters:
                param_args = []
                for key, value in request.parameters.items():
                    if isinstance(value, str):
                        param_args.append(f"-{key} '{value}'")
                    elif isinstance(value, bool):
                        param_args.append(f"-{key}:${str(value).lower()}")
                    else:
                        param_args.append(f"-{key} {value}")
                
                function_call = f"{request.function_name} {' '.join(param_args)}"
            else:
                function_call = request.function_name
            
            script_commands.append(function_call)
        else:
            # スクリプト全体実行
            script_commands.append(f"& '{script_path}'")
        
        # 出力形式指定
        if request.output_format == "json":
            script_commands.append("| ConvertTo-Json -Depth 10")
        elif request.output_format == "csv":
            script_commands.append("| ConvertTo-Csv -NoTypeInformation")
        
        # 統合コマンド
        full_script = "; ".join(script_commands)
        command.extend(["-Command", full_script])
        
        return command
    
    async def _execute_powershell_command(self, command: List[str], timeout: int) -> subprocess.CompletedProcess:
        """PowerShellコマンド実行"""
        logger.debug(f"Executing command: {' '.join(command[:5])}...")  # 最初の5要素のみログ
        
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(self.script_base_path)
        )
        
        try:
            stdout, stderr = await asyncio.wait_for(
                process.communicate(), 
                timeout=timeout
            )
            
            return subprocess.CompletedProcess(
                args=command,
                returncode=process.returncode,
                stdout=stdout.decode('utf-8', errors='replace'),
                stderr=stderr.decode('utf-8', errors='replace')
            )
            
        except asyncio.TimeoutError:
            process.kill()
            await process.wait()
            raise TimeoutError(f"PowerShell execution timed out after {timeout} seconds")
    
    async def _parse_output(self, stdout: str, output_format: str) -> Optional[Any]:
        """出力解析"""
        if not stdout.strip():
            return None
        
        try:
            if output_format == "json":
                return json.loads(stdout)
            elif output_format == "csv":
                # CSV解析（簡易版）
                lines = stdout.strip().split('\n')
                if len(lines) < 2:
                    return lines
                
                headers = [h.strip('"') for h in lines[0].split(',')]
                data = []
                
                for line in lines[1:]:
                    values = [v.strip('"') for v in line.split(',')]
                    if len(values) == len(headers):
                        data.append(dict(zip(headers, values)))
                
                return data
            else:
                return stdout
                
        except Exception as e:
            logger.warning(f"Failed to parse output as {output_format}: {e}")
            return stdout
    
    async def _cleanup_execution_environment(self, execution_id: str):
        """実行環境クリーンアップ"""
        try:
            env_dir = self.temp_dir / execution_id
            if env_dir.exists():
                import shutil
                shutil.rmtree(env_dir)
        except Exception as e:
            logger.warning(f"Failed to cleanup execution environment {execution_id}: {e}")
    
    async def execute_mapped_function(self, function_name: str, parameters: Dict[str, Any] = None) -> PowerShellExecutionResult:
        """マップされた機能実行"""
        if function_name not in self.function_mappings:
            raise ValueError(f"Unknown function: {function_name}")
        
        mapping = self.function_mappings[function_name]
        
        request = PowerShellExecutionRequest(
            script_path=mapping["script"],
            function_name=mapping["function"],
            parameters=parameters or {},
            output_format=mapping["output_format"]
        )
        
        return await self.execute_script(request)
    
    async def test_powershell_connectivity(self) -> Dict[str, Any]:
        """PowerShell接続テスト"""
        try:
            request = PowerShellExecutionRequest(
                script_content="""
                $PSVersionTable | ConvertTo-Json
                """,
                output_format="json",
                timeout_seconds=30
            )
            
            result = await self.execute_script(request)
            
            return {
                "success": result.success,
                "powershell_version": result.output_data,
                "execution_time": result.execution_time_seconds,
                "executable": self.powershell_exe
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "executable": self.powershell_exe
            }
    
    async def get_available_scripts(self) -> List[Dict[str, Any]]:
        """利用可能スクリプト一覧"""
        scripts = []
        
        try:
            for script_path in self.script_base_path.rglob("*.ps1"):
                if script_path.is_file():
                    relative_path = script_path.relative_to(self.script_base_path)
                    
                    # スクリプト情報読み取り
                    try:
                        async with aiofiles.open(script_path, 'r', encoding='utf-8') as f:
                            content = await f.read()
                        
                        # 関数一覧抽出（簡易版）
                        functions = []
                        for line in content.split('\n'):
                            if line.strip().startswith('function '):
                                func_name = line.split('function ')[1].split('(')[0].split(' ')[0]
                                functions.append(func_name)
                        
                        scripts.append({
                            "path": str(relative_path),
                            "absolute_path": str(script_path),
                            "size_bytes": script_path.stat().st_size,
                            "modified": datetime.fromtimestamp(script_path.stat().st_mtime).isoformat(),
                            "functions": functions
                        })
                        
                    except Exception as e:
                        logger.warning(f"Failed to read script {script_path}: {e}")
                        
        except Exception as e:
            logger.error(f"Failed to scan scripts directory: {e}")
        
        return scripts
    
    def get_function_mappings(self) -> Dict[str, Any]:
        """機能マッピング取得"""
        return self.function_mappings

# グローバルインスタンス
powershell_bridge = PowerShellBridge()

# 便利な関数群
async def execute_powershell_function(function_name: str, parameters: Dict[str, Any] = None) -> PowerShellExecutionResult:
    """PowerShell機能実行"""
    return await powershell_bridge.execute_mapped_function(function_name, parameters)

async def test_powershell_bridge() -> Dict[str, Any]:
    """PowerShellブリッジテスト"""
    return await powershell_bridge.test_powershell_connectivity()

async def get_powershell_scripts() -> List[Dict[str, Any]]:
    """PowerShellスクリプト一覧取得"""
    return await powershell_bridge.get_available_scripts()

# Microsoft 365 特化機能ラッパー
class M365PowerShellWrapper:
    """Microsoft 365 PowerShell ラッパー"""
    
    def __init__(self):
        self.bridge = powershell_bridge
    
    async def get_users(self, max_results: int = 100, include_licenses: bool = True) -> PowerShellExecutionResult:
        """ユーザー一覧取得"""
        parameters = {
            "MaxResults": max_results,
            "IncludeLicenses": include_licenses,
            "OutputFormat": "JSON"
        }
        return await self.bridge.execute_mapped_function("Get-M365Users", parameters)
    
    async def get_licenses(self, detailed: bool = True) -> PowerShellExecutionResult:
        """ライセンス分析"""
        parameters = {
            "Detailed": detailed,
            "OutputFormat": "JSON"
        }
        return await self.bridge.execute_mapped_function("Get-M365Licenses", parameters)
    
    async def get_mailboxes(self, result_size: int = 1000) -> PowerShellExecutionResult:
        """メールボックス分析"""
        parameters = {
            "ResultSize": result_size,
            "OutputFormat": "CSV"
        }
        return await self.bridge.execute_mapped_function("Get-ExchangeMailboxes", parameters)
    
    async def generate_daily_report(self, output_path: Optional[str] = None) -> PowerShellExecutionResult:
        """日次レポート生成"""
        parameters = {
            "OutputFormat": "HTML",
            "AutoOpen": False
        }
        if output_path:
            parameters["OutputPath"] = output_path
            
        return await self.bridge.execute_mapped_function("Generate-DailyReport", parameters)
    
    async def test_authentication(self) -> PowerShellExecutionResult:
        """認証テスト"""
        return await self.bridge.execute_mapped_function("Test-M365Authentication", {})

# グローバルラッパーインスタンス
m365_powershell = M365PowerShellWrapper()

# 初期化関数
async def initialize_powershell_bridge():
    """PowerShellブリッジ初期化"""
    try:
        # 接続テスト
        test_result = await powershell_bridge.test_powershell_connectivity()
        
        if test_result["success"]:
            logger.info(f"PowerShell bridge initialized successfully: {test_result['powershell_version']}")
        else:
            logger.error(f"PowerShell bridge initialization failed: {test_result.get('error')}")
            raise RuntimeError("PowerShell bridge initialization failed")
            
    except Exception as e:
        logger.error(f"Failed to initialize PowerShell bridge: {e}")
        raise