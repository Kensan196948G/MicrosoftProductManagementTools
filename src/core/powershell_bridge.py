"""
PowerShellブリッジ実装
既存のPowerShellモジュールをPythonから呼び出すための互換性レイヤー
"""

import subprocess
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Union
from dataclasses import dataclass
import logging
from functools import lru_cache
import asyncio
from concurrent.futures import ThreadPoolExecutor


# ロガー設定
logger = logging.getLogger(__name__)


@dataclass
class PowerShellResult:
    """PowerShell実行結果"""
    stdout: str
    stderr: str
    returncode: int
    data: Optional[Any] = None
    success: bool = True
    error_message: Optional[str] = None


class PowerShellBridge:
    """
    PowerShellとPythonの相互運用ブリッジ
    既存のPowerShellモジュールを移行期間中も利用可能にする
    
    主な機能:
    - PowerShellコマンド/スクリプトの実行
    - 型変換とデータマッピング
    - エラーハンドリングと再試行
    - 非同期実行サポート
    - Microsoft 365 API統合
    """
    
    def __init__(self, project_root: Optional[Path] = None, max_retries: int = 3):
        self.project_root = project_root or Path(__file__).parent.parent.parent
        self.pwsh_exe = self._find_powershell()
        self._module_cache = {}
        self._session_id = None
        self.executor = ThreadPoolExecutor(max_workers=4)
        self.max_retries = max_retries
        self._persistent_session = None
        
        # PowerShell実行時の基本設定
        self.default_params = [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy', 'Bypass'
        ]
        
        # プロジェクトのモジュールパスを設定
        self.module_paths = [
            self.project_root / 'Scripts' / 'Common',
            self.project_root / 'Scripts' / 'AD',
            self.project_root / 'Scripts' / 'EntraID',
            self.project_root / 'Scripts' / 'EXO',
            self.project_root / 'Scripts' / 'Teams',
            self.project_root / 'Scripts' / 'OneDrive'
        ]
        
    def _find_powershell(self) -> str:
        """利用可能なPowerShellを検索"""
        # PowerShell 7を優先
        candidates = ['pwsh', 'pwsh.exe', 'powershell', 'powershell.exe']
        
        for candidate in candidates:
            try:
                result = subprocess.run(
                    [candidate, '-Version'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    logger.info(f"PowerShell found: {candidate}")
                    return candidate
            except (FileNotFoundError, subprocess.TimeoutExpired):
                continue
                
        raise RuntimeError("PowerShellが見つかりません。PowerShell 7のインストールを推奨します。")
    
    def _prepare_command(self, command: str, use_json: bool = True) -> str:
        """コマンドを準備（JSON出力オプション付き）"""
        # モジュールパスを追加
        module_path_cmd = ";".join([
            f"$env:PSModulePath += ';{path}'"
            for path in self.module_paths if path.exists()
        ])
        
        # PowerShell互換性設定
        compatibility_settings = """
        $PSDefaultParameterValues['*:Encoding'] = 'utf8'
        $OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        """
        
        # エラーハンドリングを追加
        wrapped_command = f"""
        {compatibility_settings}
        {module_path_cmd}
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'SilentlyContinue'
        try {{
            {command}
            {' | ConvertTo-Json -Depth 10 -Compress' if use_json else ''}
        }} catch {{
            $errorDetails = @{{
                Message = $_.Exception.Message
                Type = $_.Exception.GetType().FullName
                StackTrace = $_.ScriptStackTrace
                ErrorRecord = $_.ToString()
            }}
            $errorDetails | ConvertTo-Json -Compress
            exit 1
        }}
        """
        
        return wrapped_command
    
    def execute_command(self, command: str, return_json: bool = True,
                       timeout: int = 60) -> PowerShellResult:
        """PowerShellコマンドを実行"""
        prepared_command = self._prepare_command(command, return_json)
        
        try:
            result = subprocess.run(
                [self.pwsh_exe] + self.default_params + ['-Command', prepared_command],
                capture_output=True,
                text=True,
                encoding='utf-8',
                timeout=timeout
            )
            
            # 結果を処理
            ps_result = PowerShellResult(
                stdout=result.stdout,
                stderr=result.stderr,
                returncode=result.returncode,
                success=result.returncode == 0
            )
            
            if ps_result.success and return_json and result.stdout.strip():
                try:
                    ps_result.data = json.loads(result.stdout)
                except json.JSONDecodeError as e:
                    logger.warning(f"JSON parse error: {e}")
                    ps_result.data = result.stdout
            
            if not ps_result.success:
                # エラー詳細を解析
                if result.stderr:
                    try:
                        error_data = json.loads(result.stderr)
                        ps_result.error_message = error_data.get('Message', 'Unknown error')
                        ps_result.data = error_data
                    except json.JSONDecodeError:
                        ps_result.error_message = result.stderr or "Unknown error"
                else:
                    ps_result.error_message = "Unknown error"
                logger.error(f"PowerShell command failed: {ps_result.error_message}")
            
            return ps_result
            
        except subprocess.TimeoutExpired:
            return PowerShellResult(
                stdout="",
                stderr="Command timed out",
                returncode=-1,
                success=False,
                error_message="コマンドがタイムアウトしました"
            )
        except Exception as e:
            return PowerShellResult(
                stdout="",
                stderr=str(e),
                returncode=-1,
                success=False,
                error_message=f"実行エラー: {str(e)}"
            )
    
    async def execute_command_async(self, command: str, return_json: bool = True,
                                  timeout: int = 60) -> PowerShellResult:
        """PowerShellコマンドを非同期実行"""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            self.executor,
            self.execute_command,
            command,
            return_json,
            timeout
        )
    
    def execute_script(self, script_path: Union[str, Path], 
                      parameters: Optional[Dict[str, Any]] = None,
                      timeout: int = 300) -> PowerShellResult:
        """PowerShellスクリプトを実行"""
        script_path = Path(script_path)
        
        if not script_path.exists():
            return PowerShellResult(
                stdout="",
                stderr=f"Script not found: {script_path}",
                returncode=-1,
                success=False,
                error_message=f"スクリプトが見つかりません: {script_path}"
            )
        
        cmd = [self.pwsh_exe] + self.default_params + ['-File', str(script_path)]
        
        # パラメータを追加
        if parameters:
            for key, value in parameters.items():
                if isinstance(value, bool):
                    if value:
                        cmd.append(f'-{key}')
                else:
                    cmd.extend([f'-{key}', str(value)])
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                timeout=timeout
            )
            
            return PowerShellResult(
                stdout=result.stdout,
                stderr=result.stderr,
                returncode=result.returncode,
                success=result.returncode == 0,
                error_message=result.stderr if result.returncode != 0 else None
            )
            
        except subprocess.TimeoutExpired:
            return PowerShellResult(
                stdout="",
                stderr="Script execution timed out",
                returncode=-1,
                success=False,
                error_message="スクリプト実行がタイムアウトしました"
            )
    
    @lru_cache(maxsize=32)
    def import_module(self, module_name: str) -> bool:
        """PowerShellモジュールをインポート（キャッシュ付き）"""
        # モジュールパスを検索
        module_path = None
        for path in self.module_paths:
            potential_path = path / f"{module_name}.psm1"
            if potential_path.exists():
                module_path = potential_path
                break
        
        if not module_path:
            logger.error(f"Module not found: {module_name}")
            return False
        
        command = f"Import-Module '{module_path}' -Force"
        result = self.execute_command(command, return_json=False)
        
        if result.success:
            self._module_cache[module_name] = str(module_path)
            logger.info(f"Module imported: {module_name}")
        
        return result.success
    
    def call_function(self, function_name: str, **kwargs) -> PowerShellResult:
        """PowerShell関数を呼び出す"""
        # パラメータを構築
        params = []
        for key, value in kwargs.items():
            if isinstance(value, bool):
                if value:
                    params.append(f"-{key}")
            elif isinstance(value, list):
                # 配列パラメータ
                array_values = ','.join([f'"{v}"' for v in value])
                params.append(f"-{key} @({array_values})")
            elif isinstance(value, dict):
                # ハッシュテーブルパラメータ
                hash_items = [f'{k}="{v}"' for k, v in value.items()]
                hash_string = ';'.join(hash_items)
                params.append(f"-{key} @{{{hash_string}}}")
            else:
                params.append(f"-{key} '{value}'")
        
        command = f"{function_name} {' '.join(params)}"
        return self.execute_command(command)
    
    # Microsoft 365 固有のヘルパーメソッド
    
    def connect_graph(self, tenant_id: str, client_id: str, 
                     certificate_thumbprint: Optional[str] = None,
                     client_secret: Optional[str] = None) -> PowerShellResult:
        """Microsoft Graphに接続"""
        self.import_module("Authentication")
        
        params = {
            'TenantId': tenant_id,
            'ClientId': client_id
        }
        
        if certificate_thumbprint:
            params['CertificateThumbprint'] = certificate_thumbprint
        elif client_secret:
            params['ClientSecret'] = client_secret
        
        return self.call_function('Connect-M365Services', **params)
    
    def get_users(self, properties: Optional[List[str]] = None,
                  filter_query: Optional[str] = None) -> PowerShellResult:
        """ユーザー一覧を取得"""
        command = "Get-MgUser -All"
        
        if properties:
            command += f" -Property {','.join(properties)}"
        
        if filter_query:
            command += f" -Filter '{filter_query}'"
        
        return self.execute_command(command)
    
    def get_licenses(self) -> PowerShellResult:
        """ライセンス情報を取得"""
        command = "Get-MgSubscribedSku"
        return self.execute_command(command)
    
    def get_mailboxes(self, result_size: int = 100) -> PowerShellResult:
        """メールボックス一覧を取得"""
        command = f"Get-Mailbox -ResultSize {result_size}"
        return self.execute_command(command)
    
    def get_teams_usage(self) -> PowerShellResult:
        """Teams使用状況を取得"""
        self.import_module("TeamsDataProvider")
        return self.call_function("Get-TeamsUsageData")
    
    def get_onedrive_storage(self) -> PowerShellResult:
        """OneDriveストレージ情報を取得"""
        self.import_module("OneDriveDataProvider")
        return self.call_function("Get-OneDriveStorageData")
    
    # バッチ処理サポート
    
    def execute_batch(self, commands: List[str], 
                     parallel: bool = False) -> List[PowerShellResult]:
        """複数のコマンドをバッチ実行"""
        if parallel:
            # 並列実行
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
                futures = [
                    executor.submit(self.execute_command, cmd)
                    for cmd in commands
                ]
                return [f.result() for f in concurrent.futures.as_completed(futures)]
        else:
            # 順次実行
            return [self.execute_command(cmd) for cmd in commands]
    
    async def execute_batch_async(self, commands: List[str]) -> List[PowerShellResult]:
        """複数のコマンドを非同期バッチ実行"""
        tasks = [self.execute_command_async(cmd) for cmd in commands]
        return await asyncio.gather(*tasks)
    
    # リソース管理
    
    def __enter__(self):
        """コンテキストマネージャー開始"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """コンテキストマネージャー終了"""
        self.cleanup()
    
    def cleanup(self):
        """リソースのクリーンアップ"""
        self.executor.shutdown(wait=True)
        self._module_cache.clear()
        self.import_module.cache_clear()
        if self._persistent_session:
            self.execute_command("Exit-PSSession", return_json=False)
            self._persistent_session = None
    
    # 型変換ヘルパー
    
    def _convert_ps_to_python(self, ps_object: Any) -> Any:
        """PowerShellオブジェクトをPythonオブジェクトに変換"""
        if isinstance(ps_object, dict):
            # PSCustomObjectの処理
            if ps_object.get('@odata.type'):
                # Microsoft Graph APIレスポンス
                return {k: self._convert_ps_to_python(v) for k, v in ps_object.items()}
            return {k: self._convert_ps_to_python(v) for k, v in ps_object.items()}
        elif isinstance(ps_object, list):
            return [self._convert_ps_to_python(item) for item in ps_object]
        elif isinstance(ps_object, str):
            # DateTime文字列の変換
            if ps_object.startswith('/Date(') and ps_object.endswith(')/'):
                import re
                match = re.match(r'/Date\((\d+)\)/', ps_object)
                if match:
                    from datetime import datetime
                    timestamp = int(match.group(1)) / 1000
                    return datetime.fromtimestamp(timestamp)
            return ps_object
        return ps_object
    
    def _convert_python_to_ps(self, py_object: Any) -> str:
        """PythonオブジェクトをPowerShellパラメータに変換"""
        if py_object is None:
            return '$null'
        elif isinstance(py_object, bool):
            return '$true' if py_object else '$false'
        elif isinstance(py_object, (int, float)):
            return str(py_object)
        elif isinstance(py_object, str):
            # エスケープ処理
            escaped = py_object.replace('"', '`"').replace("'", "''")
            return f"'{escaped}'"
        elif isinstance(py_object, list):
            items = [self._convert_python_to_ps(item) for item in py_object]
            return f"@({','.join(items)})"
        elif isinstance(py_object, dict):
            items = [f"'{k}'={self._convert_python_to_ps(v)}" for k, v in py_object.items()]
            return f"@{{{';'.join(items)}}}"
        elif hasattr(py_object, 'isoformat'):
            # datetime オブジェクト
            return f"'{py_object.isoformat()}'"
        else:
            return f"'{str(py_object)}'"
    
    # 再試行機能
    
    def execute_with_retry(self, command: str, return_json: bool = True,
                          timeout: int = 60) -> PowerShellResult:
        """再試行機能付きコマンド実行"""
        last_error = None
        
        for attempt in range(self.max_retries):
            try:
                result = self.execute_command(command, return_json, timeout)
                if result.success:
                    return result
                
                # 特定のエラーは再試行しない
                if result.error_message and any(keyword in result.error_message.lower() 
                                              for keyword in ['permission', 'unauthorized', 'forbidden']):
                    return result
                
                last_error = result
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt  # 指数バックオフ
                    logger.warning(f"Retry {attempt + 1}/{self.max_retries} after {wait_time}s")
                    import time
                    time.sleep(wait_time)
                    
            except Exception as e:
                last_error = PowerShellResult(
                    stdout="",
                    stderr=str(e),
                    returncode=-1,
                    success=False,
                    error_message=str(e)
                )
                
        return last_error
    
    # パイプライン実行
    
    def execute_pipeline(self, commands: List[str], timeout: int = 300) -> PowerShellResult:
        """PowerShellパイプラインを実行"""
        pipeline = " | ".join(commands)
        return self.execute_command(pipeline, timeout=timeout)
    
    # 永続セッション
    
    def create_persistent_session(self) -> bool:
        """永続的なPowerShellセッションを作成"""
        session_cmd = """
        $global:PersistentSession = New-PSSession -ComputerName localhost
        $global:PersistentSession.SessionId
        """
        result = self.execute_command(session_cmd, return_json=False)
        if result.success:
            self._session_id = result.stdout.strip()
            self._persistent_session = True
            logger.info(f"Created persistent session: {self._session_id}")
            return True
        return False


class PowerShellCompatibilityLayer:
    """
    PowerShell関数をPythonメソッドとして提供する互換性レイヤー
    """
    
    def __init__(self, bridge: Optional[PowerShellBridge] = None):
        self.bridge = bridge or PowerShellBridge()
        self._function_map = self._build_function_map()
    
    def _build_function_map(self) -> Dict[str, str]:
        """Python名とPowerShell関数名のマッピング"""
        return {
            # 認証関連
            'connect_services': 'Connect-M365Services',
            'disconnect_services': 'Disconnect-M365Services',
            
            # ユーザー管理
            'get_users': 'Get-MgUser',
            'get_user': 'Get-MgUser',
            'new_user': 'New-MgUser',
            'update_user': 'Update-MgUser',
            'remove_user': 'Remove-MgUser',
            
            # グループ管理
            'get_groups': 'Get-MgGroup',
            'new_group': 'New-MgGroup',
            'add_group_member': 'Add-MgGroupMember',
            
            # ライセンス管理
            'get_licenses': 'Get-MgSubscribedSku',
            'assign_license': 'Set-MgUserLicense',
            
            # レポート生成
            'new_html_report': 'New-HTMLReport',
            'export_csv_report': 'Export-CSVReport',
            
            # Exchange管理
            'get_mailboxes': 'Get-Mailbox',
            'get_mailbox_statistics': 'Get-MailboxStatistics',
            'get_mail_flow': 'Get-MessageTrace',
            
            # Teams管理
            'get_teams': 'Get-Team',
            'get_teams_usage': 'Get-TeamsUsageReport',
            
            # OneDrive管理
            'get_onedrive_sites': 'Get-SPOSite',
            'get_onedrive_usage': 'Get-OneDriveUsageReport'
        }
    
    def __getattr__(self, name: str):
        """動的メソッド解決"""
        if name in self._function_map:
            ps_function = self._function_map[name]
            
            def wrapper(**kwargs):
                return self.bridge.call_function(ps_function, **kwargs)
            
            return wrapper
        
        raise AttributeError(f"'{self.__class__.__name__}' has no attribute '{name}'")
    
    def import_common_modules(self):
        """共通モジュールを一括インポート"""
        modules = [
            'Common',
            'Authentication', 
            'Logging',
            'ErrorHandling',
            'ReportGenerator',
            'RealM365DataProvider'
        ]
        
        for module in modules:
            self.bridge.import_module(module)


# 使用例
if __name__ == '__main__':
    # 基本的な使用例
    with PowerShellBridge() as bridge:
        # PowerShellコマンドの実行
        result = bridge.execute_command("Get-Date")
        if result.success:
            print(f"Current date: {result.stdout}")
        
        # モジュールのインポートと関数呼び出し
        if bridge.import_module("Common"):
            result = bridge.call_function("Initialize-Environment")
            print(f"Environment initialized: {result.success}")
        
        # Microsoft 365 API呼び出し
        # result = bridge.get_users(properties=['displayName', 'mail'])
        # if result.success and result.data:
        #     for user in result.data:
        #         print(f"User: {user.get('displayName')}")
    
    # 互換性レイヤーの使用例
    compat = PowerShellCompatibilityLayer()
    compat.import_common_modules()
    
    # Pythonスタイルでの呼び出し
    # users_result = compat.get_users(Property=['displayName', 'mail'])
    # licenses_result = compat.get_licenses()