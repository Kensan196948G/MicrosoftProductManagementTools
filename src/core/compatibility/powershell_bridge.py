"""
PowerShell Bridge Module
PowerShell版との完全互換性を維持するためのブリッジレイヤー

このモジュールは：
1. PowerShellスクリプトをPythonから直接実行
2. 既存のPowerShellモジュールの機能を活用
3. 段階的移行期間中の互換性確保
4. 同一データ形式での出力保証
"""

import subprocess
import json
import logging
import asyncio
from typing import Dict, List, Any, Optional, Union
from pathlib import Path
import tempfile
import os
from dataclasses import dataclass
from datetime import datetime

logger = logging.getLogger(__name__)


@dataclass
class PowerShellResult:
    """PowerShell実行結果を格納するデータクラス"""
    success: bool
    data: Any
    error: Optional[str] = None
    execution_time: float = 0.0
    ps_version: Optional[str] = None
    module_versions: Dict[str, str] = None


class PowerShellBridge:
    """
    PowerShellとPythonの橋渡しを行うクラス
    
    既存のPowerShellモジュールを活用しながら、
    Pythonから同等の機能を提供します。
    """
    
    def __init__(self, powershell_root: Path):
        self.powershell_root = Path(powershell_root)
        self.scripts_dir = self.powershell_root / "Scripts"
        self.common_dir = self.scripts_dir / "Common"
        self.apps_dir = self.powershell_root / "Apps"
        
        # PowerShell実行環境の設定
        self.ps_executable = self._detect_powershell()
        self.execution_policy = "Bypass"
        self.timeout = 300  # 5分タイムアウト
        
        # 接続状態管理
        self._auth_status = {
            'graph_connected': False,
            'exchange_connected': False,
            'last_check': None
        }
        
        logger.info(f"PowerShell Bridge initialized with root: {powershell_root}")
        logger.info(f"PowerShell executable: {self.ps_executable}")
    
    def _detect_powershell(self) -> str:
        """利用可能なPowerShell実行可能ファイルを検出"""
        candidates = [
            "pwsh",  # PowerShell 7.x
            "powershell"  # Windows PowerShell 5.1
        ]
        
        for ps_exe in candidates:
            try:
                result = subprocess.run([ps_exe, "-Version"], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    logger.info(f"PowerShell detected: {ps_exe}")
                    return ps_exe
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
        
        raise RuntimeError("PowerShell executable not found")
    
    async def execute_powershell_script(self, 
                                      script_path: Union[str, Path],
                                      parameters: Dict[str, Any] = None,
                                      import_modules: List[str] = None) -> PowerShellResult:
        """
        PowerShellスクリプトを非同期で実行
        
        Args:
            script_path: 実行するスクリプトのパス
            parameters: スクリプトに渡すパラメータ
            import_modules: 事前に読み込むモジュール
        
        Returns:
            PowerShellResult: 実行結果
        """
        start_time = datetime.now()
        
        try:
            # PowerShellコマンドを構築
            ps_command = self._build_powershell_command(
                script_path, parameters, import_modules
            )
            
            logger.debug(f"Executing PowerShell: {ps_command}")
            
            # 非同期でPowerShellを実行
            process = await asyncio.create_subprocess_exec(
                self.ps_executable,
                "-ExecutionPolicy", self.execution_policy,
                "-NoProfile",
                "-Command", ps_command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.powershell_root)
            )
            
            stdout, stderr = await asyncio.wait_for(
                process.communicate(), timeout=self.timeout
            )
            
            execution_time = (datetime.now() - start_time).total_seconds()
            
            # 結果の解析
            if process.returncode == 0:
                try:
                    # JSON形式での出力を期待
                    if stdout:
                        data = json.loads(stdout.decode('utf-8'))
                    else:
                        data = None
                    
                    return PowerShellResult(
                        success=True,
                        data=data,
                        execution_time=execution_time
                    )
                except json.JSONDecodeError:
                    # JSON以外の出力の場合はそのまま返す
                    return PowerShellResult(
                        success=True,
                        data=stdout.decode('utf-8') if stdout else None,
                        execution_time=execution_time
                    )
            else:
                error_msg = stderr.decode('utf-8') if stderr else f"Process failed with code {process.returncode}"
                logger.error(f"PowerShell execution failed: {error_msg}")
                
                return PowerShellResult(
                    success=False,
                    data=None,
                    error=error_msg,
                    execution_time=execution_time
                )
                
        except asyncio.TimeoutError:
            logger.error(f"PowerShell execution timed out after {self.timeout}s")
            return PowerShellResult(
                success=False,
                data=None,
                error=f"Execution timed out after {self.timeout} seconds"
            )
        except Exception as e:
            logger.error(f"PowerShell execution error: {e}")
            return PowerShellResult(
                success=False,
                data=None,
                error=str(e)
            )
    
    def _build_powershell_command(self, 
                                script_path: Union[str, Path],
                                parameters: Dict[str, Any] = None,
                                import_modules: List[str] = None) -> str:
        """PowerShell実行コマンドを構築"""
        commands = []
        
        # モジュールのインポート
        if import_modules:
            for module in import_modules:
                module_path = self.common_dir / f"{module}.psm1"
                if module_path.exists():
                    commands.append(f"Import-Module '{module_path}' -Force")
        
        # 既定の共通モジュールをインポート
        default_modules = [
            "Common",
            "RealM365DataProvider", 
            "Authentication",
            "Logging"
        ]
        
        for module in default_modules:
            module_path = self.common_dir / f"{module}.psm1"
            if module_path.exists():
                commands.append(f"Import-Module '{module_path}' -Force -ErrorAction SilentlyContinue")
        
        # スクリプト実行コマンド
        script_cmd = f"& '{script_path}'"
        
        # パラメータの追加
        if parameters:
            for key, value in parameters.items():
                if isinstance(value, bool):
                    if value:
                        script_cmd += f" -{key}"
                elif isinstance(value, str):
                    script_cmd += f" -{key} '{value}'"
                else:
                    script_cmd += f" -{key} {value}"
        
        commands.append(script_cmd)
        
        # 全体のコマンドを結合
        return "; ".join(commands)
    
    async def get_m365_users(self, limit: int = 1000) -> PowerShellResult:
        """Microsoft 365ユーザー一覧をPowerShell経由で取得"""
        script_content = f"""
# RealM365DataProvider モジュールの利用
$users = Get-M365AllUsers -MaxResults {limit}
$users | ConvertTo-Json -Depth 10
"""
        
        return await self._execute_inline_script(script_content)
    
    async def get_m365_license_analysis(self) -> PowerShellResult:
        """ライセンス分析をPowerShell経由で実行"""
        script_content = """
$analysis = Get-M365LicenseAnalysis
$analysis | ConvertTo-Json -Depth 10
"""
        
        return await self._execute_inline_script(script_content)
    
    async def get_m365_teams_usage(self) -> PowerShellResult:
        """Teams使用状況をPowerShell経由で取得"""
        script_content = """
$teams = Get-M365TeamsUsage
$teams | ConvertTo-Json -Depth 10
"""
        
        return await self._execute_inline_script(script_content)
    
    async def get_m365_onedrive_analysis(self) -> PowerShellResult:
        """OneDrive分析をPowerShell経由で実行"""
        script_content = """
$analysis = Get-M365OneDriveAnalysis
$analysis | ConvertTo-Json -Depth 10
"""
        
        return await self._execute_inline_script(script_content)
    
    async def get_m365_mailbox_analysis(self) -> PowerShellResult:
        """メールボックス分析をPowerShell経由で実行"""
        script_content = """
$analysis = Get-M365MailboxAnalysis
$analysis | ConvertTo-Json -Depth 10
"""
        
        return await self._execute_inline_script(script_content)
    
    async def test_m365_authentication(self) -> PowerShellResult:
        """Microsoft 365認証状態をテスト"""
        script_content = """
$authStatus = Test-M365Authentication
$result = @{
    GraphConnected = $authStatus.GraphConnected
    ExchangeConnected = $authStatus.ExchangeConnected
    TenantId = $authStatus.TenantId
    ConnectedUser = $authStatus.ConnectedUser
    LastCheck = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}
$result | ConvertTo-Json
"""
        
        result = await self._execute_inline_script(script_content)
        
        # 認証状態を更新
        if result.success and result.data:
            self._auth_status.update({
                'graph_connected': result.data.get('GraphConnected', False),
                'exchange_connected': result.data.get('ExchangeConnected', False),
                'last_check': datetime.now()
            })
        
        return result
    
    async def _execute_inline_script(self, script_content: str) -> PowerShellResult:
        """インラインスクリプトを実行"""
        # 一時ファイルにスクリプトを保存
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ps1', delete=False, encoding='utf-8') as f:
            f.write(script_content)
            temp_script = f.name
        
        try:
            result = await self.execute_powershell_script(temp_script)
            return result
        finally:
            # 一時ファイルを削除
            try:
                os.unlink(temp_script)
            except OSError:
                pass
    
    async def generate_report_via_powershell(self, 
                                           report_type: str,
                                           output_path: str = None,
                                           output_format: str = "both") -> PowerShellResult:
        """PowerShell版のレポート生成機能を利用"""
        
        # CLIアプリケーション経由でレポート生成
        cli_script = self.apps_dir / "CliApp_Enhanced.ps1"
        
        parameters = {
            "Action": report_type,
            "Batch": True
        }
        
        if output_path:
            parameters["OutputPath"] = output_path
        
        if output_format == "csv":
            parameters["OutputCSV"] = True
        elif output_format == "html":
            parameters["OutputHTML"] = True
        elif output_format == "both":
            parameters["OutputCSV"] = True
            parameters["OutputHTML"] = True
        
        return await self.execute_powershell_script(cli_script, parameters)
    
    def get_authentication_status(self) -> Dict[str, Any]:
        """現在の認証状態を取得"""
        return self._auth_status.copy()
    
    async def initialize_m365_connection(self) -> PowerShellResult:
        """Microsoft 365接続の初期化"""
        script_content = """
# 認証状態の確認と初期化
try {
    $authResult = Initialize-M365Connection
    $result = @{
        Success = $true
        GraphConnected = $authResult.GraphConnected
        ExchangeConnected = $authResult.ExchangeConnected
        TenantId = $authResult.TenantId
        Message = "Authentication initialized successfully"
    }
} catch {
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        Message = "Authentication initialization failed"
    }
}
$result | ConvertTo-Json
"""
        
        return await self._execute_inline_script(script_content)


class DataFormatConverter:
    """
    PowerShellとPythonのデータ形式変換を行うクラス
    既存のPowerShell出力形式を維持
    """
    
    @staticmethod
    def powershell_to_python(ps_data: Any) -> Any:
        """PowerShell形式のデータをPython形式に変換"""
        if isinstance(ps_data, dict):
            # PowerShellのハッシュテーブルをPython辞書に変換
            return {k: DataFormatConverter.powershell_to_python(v) for k, v in ps_data.items()}
        elif isinstance(ps_data, list):
            return [DataFormatConverter.powershell_to_python(item) for item in ps_data]
        elif isinstance(ps_data, str):
            # PowerShell特有の文字列処理
            return ps_data.strip()
        else:
            return ps_data
    
    @staticmethod
    def python_to_powershell(py_data: Any) -> Any:
        """Python形式のデータをPowerShell互換形式に変換"""
        if isinstance(py_data, dict):
            return {k: DataFormatConverter.python_to_powershell(v) for k, v in py_data.items()}
        elif isinstance(py_data, list):
            return [DataFormatConverter.python_to_powershell(item) for item in py_data]
        else:
            return py_data
    
    @staticmethod
    def ensure_utf8_bom_encoding(content: str) -> bytes:
        """PowerShell互換のUTF8-BOMエンコーディング"""
        return content.encode('utf-8-sig')
    
    @staticmethod
    def normalize_datetime_format(dt_str: str) -> str:
        """PowerShell互換の日時形式に正規化"""
        try:
            # ISO形式からPowerShell形式へ変換
            dt = datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
            return dt.strftime('%Y/%m/%d %H:%M:%S')
        except:
            return dt_str


# PowerShellブリッジのシングルトンインスタンス
_bridge_instance = None

def get_powershell_bridge(powershell_root: Path = None) -> PowerShellBridge:
    """PowerShellブリッジのシングルトンインスタンスを取得"""
    global _bridge_instance
    
    if _bridge_instance is None:
        if powershell_root is None:
            # デフォルトのルートディレクトリを設定
            current_dir = Path(__file__).parent
            powershell_root = current_dir.parent.parent.parent  # src/../../../
        
        _bridge_instance = PowerShellBridge(powershell_root)
    
    return _bridge_instance