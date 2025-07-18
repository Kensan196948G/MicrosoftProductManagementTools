"""
Enhanced PowerShell Bridge Module
PowerShell版との互換性を最大限に保つ強化ブリッジシステム

Dev2 - PowerShell Compatibility Developer による改善:
1. リアルタイムデータ変換の精度向上
2. PowerShell特有のエラーハンドリング対応
3. GUI操作の完全互換性
4. パフォーマンス最適化
"""

import subprocess
import json
import logging
import asyncio
from typing import Dict, List, Any, Optional, Union, Callable
from pathlib import Path
import tempfile
import os
import time
from dataclasses import dataclass, field
from datetime import datetime
import threading
import queue
import re

from .powershell_bridge import PowerShellBridge, PowerShellResult, DataFormatConverter

logger = logging.getLogger(__name__)


@dataclass
class EnhancedPowerShellResult:
    """拡張PowerShell実行結果"""
    success: bool
    data: Any
    source: str = "powershell"
    execution_time: float = 0.0
    error: Optional[str] = None
    warnings: List[str] = field(default_factory=list)
    ps_version: Optional[str] = None
    module_versions: Dict[str, str] = field(default_factory=dict)
    cached: bool = False
    retry_count: int = 0


class EnhancedDataConverter:
    """
    PowerShell特有のデータ形式を完全互換で変換
    """
    
    @staticmethod
    def convert_powershell_object(ps_obj: Any) -> Any:
        """PowerShellオブジェクトを詳細変換"""
        if ps_obj is None:
            return None
        
        if isinstance(ps_obj, dict):
            # PowerShellハッシュテーブルの特殊処理
            converted = {}
            for key, value in ps_obj.items():
                # PowerShell特有のキー名の正規化
                normalized_key = EnhancedDataConverter._normalize_property_name(key)
                converted[normalized_key] = EnhancedDataConverter.convert_powershell_object(value)
            return converted
            
        elif isinstance(ps_obj, list):
            return [EnhancedDataConverter.convert_powershell_object(item) for item in ps_obj]
            
        elif isinstance(ps_obj, str):
            # PowerShell特有の文字列処理
            return EnhancedDataConverter._process_powershell_string(ps_obj)
            
        else:
            return ps_obj
    
    @staticmethod
    def _normalize_property_name(name: str) -> str:
        """PowerShellプロパティ名を正規化"""
        # よくあるPowerShell→Python変換
        name_mappings = {
            'DisplayName': 'display_name',
            'UserPrincipalName': 'user_principal_name',
            'ObjectId': 'object_id',
            'AssignedLicenses': 'assigned_licenses',
            'SignInActivity': 'signin_activity',
            'CreatedDateTime': 'created_datetime',
            'LastSignInDateTime': 'last_signin_datetime'
        }
        
        return name_mappings.get(name, name)
    
    @staticmethod
    def _process_powershell_string(value: str) -> Union[str, datetime, bool, float, int]:
        """PowerShell文字列の型推定と変換"""
        value = value.strip()
        
        # 日時文字列の検出と変換
        datetime_patterns = [
            r'\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}',
            r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
            r'\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}'
        ]
        
        for pattern in datetime_patterns:
            if re.match(pattern, value):
                try:
                    if '/' in value:
                        dt = datetime.strptime(value, '%Y/%m/%d %H:%M:%S')
                    else:
                        dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
                    return dt.strftime('%Y/%m/%d %H:%M:%S')  # PowerShell形式に統一
                except ValueError:
                    continue
        
        # 真偽値の検出
        if value.lower() in ['true', '$true', 'enabled', 'yes']:
            return True
        elif value.lower() in ['false', '$false', 'disabled', 'no']:
            return False
        
        # 数値の検出
        try:
            if '.' in value:
                return float(value)
            else:
                return int(value)
        except ValueError:
            pass
        
        return value
    
    @staticmethod
    def ensure_utf8_bom_compatibility(content: str) -> bytes:
        """PowerShell互換のUTF-8 BOMエンコーディング"""
        return content.encode('utf-8-sig')
    
    @staticmethod
    def format_for_powershell_csv(data: List[Dict[str, Any]]) -> str:
        """PowerShell形式のCSV出力互換"""
        if not data:
            return ""
        
        # ヘッダー生成
        headers = list(data[0].keys())
        csv_lines = [','.join(f'"{header}"' for header in headers)]
        
        # データ行生成
        for row in data:
            values = []
            for header in headers:
                value = row.get(header, '')
                if isinstance(value, (list, dict)):
                    value = json.dumps(value, ensure_ascii=False)
                elif value is None:
                    value = ''
                else:
                    value = str(value)
                
                # CSVエスケープ
                if '"' in value:
                    value = value.replace('"', '""')
                values.append(f'"{value}"')
            
            csv_lines.append(','.join(values))
        
        return '\\n'.join(csv_lines)


class PowerShellSessionManager:
    """
    PowerShellセッションの永続化管理
    """
    
    def __init__(self, powershell_root: Path):
        self.powershell_root = powershell_root
        self.session_process = None
        self.session_lock = threading.Lock()
        self.command_queue = queue.Queue()
        self.result_queue = queue.Queue()
        self.session_active = False
        
    async def start_persistent_session(self) -> bool:
        """永続的なPowerShellセッションを開始"""
        with self.session_lock:
            if self.session_active:
                return True
            
            try:
                # PowerShellプロセスを開始
                self.session_process = await asyncio.create_subprocess_exec(
                    "pwsh",
                    "-NoExit",
                    "-NoProfile",
                    "-ExecutionPolicy", "Bypass",
                    "-Command", "& {Import-Module Microsoft.Graph -Force; Import-Module ExchangeOnlineManagement -Force}",
                    stdin=asyncio.subprocess.PIPE,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=str(self.powershell_root)
                )
                
                self.session_active = True
                logger.info("Persistent PowerShell session started")
                return True
                
            except Exception as e:
                logger.error(f"Failed to start PowerShell session: {e}")
                return False
    
    async def execute_in_session(self, command: str) -> PowerShellResult:
        """永続セッションでコマンドを実行"""
        if not self.session_active:
            if not await self.start_persistent_session():
                raise RuntimeError("PowerShell session not available")
        
        try:
            # コマンドを送信
            self.session_process.stdin.write(f"{command}\\n".encode())
            await self.session_process.stdin.drain()
            
            # 結果を読み取り（タイムアウト付き）
            stdout, stderr = await asyncio.wait_for(
                self.session_process.communicate(),
                timeout=300
            )
            
            if stderr:
                logger.warning(f"PowerShell stderr: {stderr.decode()}")
            
            return PowerShellResult(
                success=True,
                data=stdout.decode() if stdout else None
            )
            
        except asyncio.TimeoutError:
            logger.error("PowerShell command timed out")
            return PowerShellResult(
                success=False,
                data=None,
                error="Command execution timed out"
            )
        except Exception as e:
            logger.error(f"PowerShell execution error: {e}")
            return PowerShellResult(
                success=False,
                data=None,
                error=str(e)
            )
    
    def close_session(self):
        """PowerShellセッションを終了"""
        with self.session_lock:
            if self.session_process:
                self.session_process.terminate()
                self.session_process = None
                self.session_active = False
                logger.info("PowerShell session closed")


class EnhancedPowerShellBridge(PowerShellBridge):
    """
    機能強化されたPowerShellブリッジ
    
    Dev2 - PowerShell Compatibility Developer による拡張:
    - セッション永続化
    - エラー回復機能
    - データ変換精度向上
    - パフォーマンス最適化
    """
    
    def __init__(self, powershell_root: Path):
        super().__init__(powershell_root)
        
        # 拡張機能
        self.session_manager = PowerShellSessionManager(powershell_root)
        self.data_converter = EnhancedDataConverter()
        self.function_cache = {}
        self.cache_ttl = 300  # 5分
        
        # エラー回復設定
        self.max_retries = 3
        self.retry_delay = 2
        
        # PowerShell特有の設定
        self.powershell_culture = "ja-JP"  # 日本語ロケール
        self.output_encoding = "utf8"
        
        logger.info("Enhanced PowerShell Bridge initialized")
    
    async def execute_enhanced_script(self, 
                                   script_path: Union[str, Path],
                                   parameters: Dict[str, Any] = None,
                                   use_cache: bool = True,
                                   retry_on_failure: bool = True) -> EnhancedPowerShellResult:
        """
        拡張PowerShellスクリプト実行
        
        機能:
        - 自動リトライ
        - インテリジェントキャッシング
        - エラー詳細分析
        - パフォーマンス追跡
        """
        start_time = time.time()
        cache_key = self._generate_cache_key(script_path, parameters)
        
        # キャッシュチェック
        if use_cache and cache_key in self.function_cache:
            cached_result = self.function_cache[cache_key]
            if time.time() - cached_result['timestamp'] < self.cache_ttl:
                logger.info(f"Using cached result for {script_path}")
                cached_result['result'].cached = True
                return cached_result['result']
        
        # スクリプト実行（リトライ機能付き）
        last_error = None
        for attempt in range(self.max_retries if retry_on_failure else 1):
            try:
                result = await self._execute_with_enhanced_handling(
                    script_path, parameters, attempt
                )
                
                if result.success:
                    # 成功時はキャッシュに保存
                    if use_cache:
                        self.function_cache[cache_key] = {
                            'result': result,
                            'timestamp': time.time()
                        }
                    
                    return result
                else:
                    last_error = result.error
                    if attempt < self.max_retries - 1:
                        logger.warning(f"Attempt {attempt + 1} failed, retrying in {self.retry_delay}s")
                        await asyncio.sleep(self.retry_delay)
                    
            except Exception as e:
                last_error = str(e)
                if attempt < self.max_retries - 1:
                    logger.warning(f"Attempt {attempt + 1} failed with exception, retrying: {e}")
                    await asyncio.sleep(self.retry_delay)
        
        # 全試行失敗
        execution_time = time.time() - start_time
        return EnhancedPowerShellResult(
            success=False,
            data=None,
            execution_time=execution_time,
            error=f"All {self.max_retries} attempts failed. Last error: {last_error}",
            retry_count=self.max_retries
        )
    
    async def _execute_with_enhanced_handling(self, 
                                           script_path: Union[str, Path],
                                           parameters: Dict[str, Any],
                                           attempt: int) -> EnhancedPowerShellResult:
        """拡張エラーハンドリング付きスクリプト実行"""
        start_time = time.time()
        
        try:
            # PowerShellコマンド構築
            ps_command = self._build_enhanced_command(script_path, parameters)
            
            # 実行
            process = await asyncio.create_subprocess_exec(
                self.ps_executable,
                "-ExecutionPolicy", "Bypass",
                "-NoProfile",
                "-OutputFormat", "Text",
                "-InputFormat", "Text",
                "-Command", ps_command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.powershell_root)
            )
            
            stdout, stderr = await asyncio.wait_for(
                process.communicate(), timeout=self.timeout
            )
            
            execution_time = time.time() - start_time
            
            # 結果解析
            if process.returncode == 0:
                # 成功時の詳細解析
                result_data = self._parse_powershell_output(stdout.decode('utf-8'))
                warnings = self._extract_warnings(stderr.decode('utf-8')) if stderr else []
                
                return EnhancedPowerShellResult(
                    success=True,
                    data=result_data,
                    execution_time=execution_time,
                    warnings=warnings,
                    retry_count=attempt
                )
            else:
                # エラー時の詳細分析
                error_analysis = self._analyze_powershell_error(
                    stderr.decode('utf-8') if stderr else "",
                    process.returncode
                )
                
                return EnhancedPowerShellResult(
                    success=False,
                    data=None,
                    execution_time=execution_time,
                    error=error_analysis,
                    retry_count=attempt
                )
                
        except asyncio.TimeoutError:
            execution_time = time.time() - start_time
            return EnhancedPowerShellResult(
                success=False,
                data=None,
                execution_time=execution_time,
                error=f"Script execution timed out after {self.timeout}s",
                retry_count=attempt
            )
    
    def _build_enhanced_command(self, 
                              script_path: Union[str, Path],
                              parameters: Dict[str, Any] = None) -> str:
        """拡張PowerShellコマンド構築"""
        commands = []
        
        # 文化設定
        commands.append(f"[System.Threading.Thread]::CurrentThread.CurrentCulture = '{self.powershell_culture}'")
        commands.append(f"[System.Threading.Thread]::CurrentThread.CurrentUICulture = '{self.powershell_culture}'")
        
        # エラーアクション設定
        commands.append("$ErrorActionPreference = 'Continue'")
        commands.append("$WarningPreference = 'Continue'")
        commands.append("$VerbosePreference = 'SilentlyContinue'")
        
        # 必須モジュールのインポート
        essential_modules = [
            "Common",
            "RealM365DataProvider",
            "Authentication",
            "Logging",
            "ReportGenerator"
        ]
        
        for module in essential_modules:
            module_path = self.common_dir / f"{module}.psm1"
            if module_path.exists():
                commands.append(f"try {{ Import-Module '{module_path}' -Force -ErrorAction SilentlyContinue }} catch {{}}")
        
        # Microsoft 365モジュール
        ms_modules = [
            "Microsoft.Graph",
            "ExchangeOnlineManagement"
        ]
        
        for module in ms_modules:
            commands.append(f"try {{ Import-Module {module} -Force -ErrorAction SilentlyContinue }} catch {{}}")
        
        # メインスクリプト実行
        script_cmd = f"& '{script_path}'"
        
        if parameters:
            for key, value in parameters.items():
                if isinstance(value, bool):
                    if value:
                        script_cmd += f" -{key}"
                elif isinstance(value, str):
                    # 特殊文字のエスケープ
                    escaped_value = value.replace("'", "''")
                    script_cmd += f" -{key} '{escaped_value}'"
                else:
                    script_cmd += f" -{key} {value}"
        
        commands.append(script_cmd)
        
        # 結果をJSON形式で出力
        commands.append("if ($?) { $result | ConvertTo-Json -Depth 10 -Compress } else { Write-Error 'Script execution failed' }")
        
        return "; ".join(commands)
    
    def _parse_powershell_output(self, output: str) -> Any:
        """PowerShell出力の詳細解析"""
        if not output or output.strip() == "":
            return None
        
        try:
            # JSON形式の場合
            parsed = json.loads(output)
            return self.data_converter.convert_powershell_object(parsed)
        except json.JSONDecodeError:
            # JSON以外の場合は行ベースで解析
            lines = output.strip().split('\\n')
            
            # CSV形式の検出
            if len(lines) > 1 and ',' in lines[0]:
                return self._parse_csv_output(lines)
            
            # テーブル形式の検出
            if len(lines) > 2 and '---' in lines[1]:
                return self._parse_table_output(lines)
            
            # その他はそのまま返す
            return output.strip()
    
    def _parse_csv_output(self, lines: List[str]) -> List[Dict[str, Any]]:
        """CSV形式の出力を解析"""
        if len(lines) < 2:
            return []
        
        headers = [h.strip('"') for h in lines[0].split(',')]
        data = []
        
        for line in lines[1:]:
            values = [v.strip('"') for v in line.split(',')]
            if len(values) == len(headers):
                row = {}
                for i, header in enumerate(headers):
                    row[header] = self.data_converter._process_powershell_string(values[i])
                data.append(row)
        
        return data
    
    def _parse_table_output(self, lines: List[str]) -> List[Dict[str, Any]]:
        """テーブル形式の出力を解析"""
        if len(lines) < 3:
            return []
        
        # ヘッダー解析
        header_line = lines[0]
        separator_line = lines[1]
        
        # カラム位置の特定
        column_positions = []
        current_pos = 0
        
        for part in header_line.split():
            pos = header_line.find(part, current_pos)
            column_positions.append((part.strip(), pos))
            current_pos = pos + len(part)
        
        # データ行解析
        data = []
        for line in lines[2:]:
            if line.strip():
                row = {}
                for i, (header, pos) in enumerate(column_positions):
                    if i < len(column_positions) - 1:
                        next_pos = column_positions[i + 1][1]
                        value = line[pos:next_pos].strip()
                    else:
                        value = line[pos:].strip()
                    
                    row[header] = self.data_converter._process_powershell_string(value)
                data.append(row)
        
        return data
    
    def _extract_warnings(self, stderr: str) -> List[str]:
        """警告メッセージの抽出"""
        warnings = []
        if stderr:
            for line in stderr.split('\\n'):
                if 'WARNING:' in line.upper() or 'WARN:' in line.upper():
                    warnings.append(line.strip())
        return warnings
    
    def _analyze_powershell_error(self, stderr: str, return_code: int) -> str:
        """PowerShellエラーの詳細分析"""
        error_analysis = f"PowerShell execution failed (Exit code: {return_code})"
        
        if stderr:
            # 認証エラーの検出
            if any(keyword in stderr.lower() for keyword in ['authentication', 'unauthorized', 'access denied']):
                error_analysis += " - Authentication failure detected. Please check credentials."
            
            # モジュールエラーの検出
            elif 'module' in stderr.lower() and 'not found' in stderr.lower():
                error_analysis += " - Required PowerShell module not found. Please install missing modules."
            
            # 実行ポリシーエラーの検出
            elif 'execution policy' in stderr.lower():
                error_analysis += " - PowerShell execution policy restriction. Try running as administrator."
            
            # その他のエラー
            else:
                error_analysis += f" - {stderr.strip()}"
        
        return error_analysis
    
    def _generate_cache_key(self, script_path: Union[str, Path], parameters: Dict[str, Any] = None) -> str:
        """キャッシュキーの生成"""
        key_parts = [str(script_path)]
        
        if parameters:
            # パラメータをソートして一意のキーを生成
            sorted_params = sorted(parameters.items())
            key_parts.extend([f"{k}={v}" for k, v in sorted_params])
        
        return "|".join(key_parts)
    
    async def get_powershell_environment_info(self) -> EnhancedPowerShellResult:
        """PowerShell環境情報の取得"""
        info_script = """
        $info = @{
            PSVersion = $PSVersionTable.PSVersion.ToString()
            OS = $PSVersionTable.OS
            Platform = $PSVersionTable.Platform
            Culture = [System.Threading.Thread]::CurrentThread.CurrentCulture.Name
            Modules = @{}
        }
        
        # Microsoft 365関連モジュールの確認
        $modules = @('Microsoft.Graph', 'ExchangeOnlineManagement', 'MSOnline', 'AzureAD')
        foreach ($module in $modules) {
            $moduleInfo = Get-Module -Name $module -ListAvailable | Select-Object -First 1
            if ($moduleInfo) {
                $info.Modules[$module] = $moduleInfo.Version.ToString()
            } else {
                $info.Modules[$module] = "Not installed"
            }
        }
        
        $info | ConvertTo-Json -Depth 3
        """
        
        return await self._execute_inline_script(info_script)
    
    def get_cache_statistics(self) -> Dict[str, Any]:
        """キャッシュ統計の取得"""
        current_time = time.time()
        active_cache_count = 0
        
        for cache_entry in self.function_cache.values():
            if current_time - cache_entry['timestamp'] < self.cache_ttl:
                active_cache_count += 1
        
        return {
            'total_cache_entries': len(self.function_cache),
            'active_cache_entries': active_cache_count,
            'cache_ttl_seconds': self.cache_ttl,
            'cache_hit_ratio': getattr(self, '_cache_hits', 0) / max(getattr(self, '_cache_requests', 1), 1)
        }
    
    def clear_cache(self):
        """キャッシュのクリア"""
        self.function_cache.clear()
        logger.info("PowerShell function cache cleared")


# シングルトンインスタンス
_enhanced_bridge_instance = None

def get_enhanced_powershell_bridge(powershell_root: Path = None) -> EnhancedPowerShellBridge:
    """拡張PowerShellブリッジのシングルトンインスタンスを取得"""
    global _enhanced_bridge_instance
    
    if _enhanced_bridge_instance is None:
        if powershell_root is None:
            current_dir = Path(__file__).parent
            powershell_root = current_dir.parent.parent.parent
        
        _enhanced_bridge_instance = EnhancedPowerShellBridge(powershell_root)
    
    return _enhanced_bridge_instance