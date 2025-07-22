"""
Configuration Converter Module
PowerShell版の設定ファイルをPython版互換形式に変換

このモジュールは：
1. appsettings.json の読み込みと変換
2. PowerShell特有の設定の解釈
3. Python設定形式での出力
4. 互換性維持のための設定マッピング
"""

import json
import logging
from typing import Dict, Any, Optional, Union, List
from pathlib import Path
from dataclasses import dataclass
import re

logger = logging.getLogger(__name__)


@dataclass
class ConfigMapping:
    """設定項目のマッピング定義"""
    powershell_key: str
    python_key: str
    converter: Optional[callable] = None
    default_value: Any = None
    required: bool = False


class ConfigConverter:
    """
    PowerShell版設定ファイルをPython版形式に変換するクラス
    """
    
    def __init__(self):
        self.mappings = self._get_config_mappings()
    
    def _get_config_mappings(self) -> Dict[str, ConfigMapping]:
        """設定項目のマッピングを定義"""
        mappings = {}
        
        # 認証設定
        mappings['tenant_id'] = ConfigMapping(
            powershell_key='Authentication.TenantId',
            python_key='authentication.tenant_id',
            required=True
        )
        
        mappings['client_id'] = ConfigMapping(
            powershell_key='Authentication.ClientId', 
            python_key='authentication.client_id',
            required=True
        )
        
        mappings['client_secret'] = ConfigMapping(
            powershell_key='Authentication.ClientSecret',
            python_key='authentication.client_secret'
        )
        
        mappings['certificate_path'] = ConfigMapping(
            powershell_key='Authentication.CertificatePath',
            python_key='authentication.certificate_path'
        )
        
        mappings['certificate_thumbprint'] = ConfigMapping(
            powershell_key='Authentication.CertificateThumbprint',
            python_key='authentication.certificate_thumbprint'
        )
        
        # レポート設定
        mappings['output_path'] = ConfigMapping(
            powershell_key='ReportSettings.OutputPath',
            python_key='reports.output_path',
            default_value='Reports'
        )
        
        mappings['auto_open_files'] = ConfigMapping(
            powershell_key='GuiSettings.AutoOpenFiles',
            python_key='gui.auto_open_files',
            converter=self._convert_bool,
            default_value=True
        )
        
        mappings['show_popup_notifications'] = ConfigMapping(
            powershell_key='GuiSettings.ShowPopupNotifications',
            python_key='gui.show_popup_notifications',
            converter=self._convert_bool,
            default_value=True
        )
        
        # ログ設定
        mappings['log_level'] = ConfigMapping(
            powershell_key='Logging.Level',
            python_key='logging.level',
            default_value='INFO'
        )
        
        mappings['log_directory'] = ConfigMapping(
            powershell_key='Logging.Directory',
            python_key='logging.directory',
            default_value='Logs'
        )
        
        mappings['max_log_files'] = ConfigMapping(
            powershell_key='Logging.MaxFiles',
            python_key='logging.max_files',
            converter=int,
            default_value=30
        )
        
        # パフォーマンス設定
        mappings['max_retry_attempts'] = ConfigMapping(
            powershell_key='PerformanceSettings.MaxRetryAttempts',
            python_key='performance.max_retry_attempts',
            converter=int,
            default_value=3
        )
        
        mappings['timeout_seconds'] = ConfigMapping(
            powershell_key='PerformanceSettings.TimeoutSeconds',
            python_key='performance.timeout_seconds',
            converter=int,
            default_value=300
        )
        
        mappings['batch_size'] = ConfigMapping(
            powershell_key='PerformanceSettings.BatchSize',
            python_key='performance.batch_size',
            converter=int,
            default_value=100
        )
        
        # Exchange Online設定
        mappings['exchange_connection_uri'] = ConfigMapping(
            powershell_key='ExchangeOnline.ConnectionUri',
            python_key='exchange.connection_uri'
        )
        
        mappings['exchange_organization'] = ConfigMapping(
            powershell_key='ExchangeOnline.Organization',
            python_key='exchange.organization'
        )
        
        # Microsoft Graph設定
        mappings['graph_scopes'] = ConfigMapping(
            powershell_key='MicrosoftGraph.Scopes',
            python_key='graph.scopes',
            converter=self._convert_string_array,
            default_value=[
                'https://graph.microsoft.com/.default'
            ]
        )
        
        mappings['graph_api_version'] = ConfigMapping(
            powershell_key='MicrosoftGraph.ApiVersion',
            python_key='graph.api_version',
            default_value='v1.0'
        )
        
        # レポート閾値設定
        mappings['storage_warning_threshold'] = ConfigMapping(
            powershell_key='ReportThresholds.StorageWarningPercent',
            python_key='thresholds.storage_warning_percent',
            converter=float,
            default_value=80.0
        )
        
        mappings['mailbox_warning_threshold'] = ConfigMapping(
            powershell_key='ReportThresholds.MailboxWarningPercent',
            python_key='thresholds.mailbox_warning_percent',
            converter=float,
            default_value=90.0
        )
        
        mappings['inactive_user_days'] = ConfigMapping(
            powershell_key='ReportThresholds.InactiveUserDays',
            python_key='thresholds.inactive_user_days',
            converter=int,
            default_value=30
        )
        
        return mappings
    
    def convert_config_file(self, 
                          powershell_config_path: Union[str, Path],
                          python_config_path: Union[str, Path] = None) -> Dict[str, Any]:
        """
        PowerShell版設定ファイルをPython版形式に変換
        
        Args:
            powershell_config_path: PowerShell版appsettings.jsonのパス
            python_config_path: 出力先のPython版設定ファイルパス（省略可）
        
        Returns:
            変換された設定辞書
        """
        ps_config_path = Path(powershell_config_path)
        
        if not ps_config_path.exists():
            raise FileNotFoundError(f"PowerShell config file not found: {ps_config_path}")
        
        # PowerShell版設定を読み込み
        with open(ps_config_path, 'r', encoding='utf-8') as f:
            ps_config = json.load(f)
        
        logger.info(f"Loading PowerShell config from: {ps_config_path}")
        
        # Python版設定に変換
        py_config = self._convert_config_structure(ps_config)
        
        # ファイルに保存（指定された場合）
        if python_config_path:
            py_config_path = Path(python_config_path)
            py_config_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(py_config_path, 'w', encoding='utf-8') as f:
                json.dump(py_config, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Python config saved to: {py_config_path}")
        
        return py_config
    
    def _convert_config_structure(self, ps_config: Dict[str, Any]) -> Dict[str, Any]:
        """設定構造をPython版形式に変換"""
        py_config = {}
        
        for mapping_name, mapping in self.mappings.items():
            ps_value = self._get_nested_value(ps_config, mapping.powershell_key)
            
            if ps_value is not None:
                # 値の変換
                if mapping.converter:
                    try:
                        py_value = mapping.converter(ps_value)
                    except Exception as e:
                        logger.warning(f"Failed to convert {mapping.powershell_key}: {e}")
                        py_value = mapping.default_value
                else:
                    py_value = ps_value
            else:
                # デフォルト値を使用
                py_value = mapping.default_value
                
                if mapping.required:
                    logger.warning(f"Required config {mapping.powershell_key} not found")
            
            # Python設定に値を設定
            if py_value is not None:
                self._set_nested_value(py_config, mapping.python_key, py_value)
        
        # 追加の互換性設定
        self._add_compatibility_settings(py_config, ps_config)
        
        return py_config
    
    def _get_nested_value(self, config: Dict[str, Any], key_path: str) -> Any:
        """ネストされた設定値を取得"""
        keys = key_path.split('.')
        value = config
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return None
        
        return value
    
    def _set_nested_value(self, config: Dict[str, Any], key_path: str, value: Any):
        """ネストされた設定値を設定"""
        keys = key_path.split('.')
        current = config
        
        for key in keys[:-1]:
            if key not in current:
                current[key] = {}
            current = current[key]
        
        current[keys[-1]] = value
    
    def _convert_bool(self, value: Any) -> bool:
        """PowerShell真偽値をPython形式に変換"""
        if isinstance(value, bool):
            return value
        elif isinstance(value, str):
            return value.lower() in ['true', '1', 'yes', 'on']
        elif isinstance(value, (int, float)):
            return bool(value)
        else:
            return False
    
    def _convert_string_array(self, value: Any) -> List[str]:
        """文字列配列に変換"""
        if isinstance(value, list):
            return [str(item) for item in value]
        elif isinstance(value, str):
            # カンマ区切り文字列を配列に変換
            return [item.strip() for item in value.split(',') if item.strip()]
        else:
            return []
    
    def _add_compatibility_settings(self, py_config: Dict[str, Any], ps_config: Dict[str, Any]):
        """PowerShell互換性のための追加設定"""
        
        # エンコーディング設定
        if 'output' not in py_config:
            py_config['output'] = {}
        
        py_config['output']['encoding'] = 'utf-8-sig'  # PowerShell互換のUTF8-BOM
        py_config['output']['csv_encoding'] = 'utf-8-sig'
        py_config['output']['html_encoding'] = 'utf-8'
        
        # 日時形式設定
        py_config['output']['datetime_format'] = '%Y/%m/%d %H:%M:%S'  # PowerShell形式
        py_config['output']['date_format'] = '%Y/%m/%d'
        
        # PowerShellブリッジ設定
        if 'powershell_bridge' not in py_config:
            py_config['powershell_bridge'] = {}
        
        py_config['powershell_bridge']['enabled'] = True
        py_config['powershell_bridge']['timeout'] = 300
        py_config['powershell_bridge']['execution_policy'] = 'Bypass'
        
        # キャッシュ設定
        if 'cache' not in py_config:
            py_config['cache'] = {}
        
        py_config['cache']['enabled'] = True
        py_config['cache']['ttl'] = {
            'users': 300,      # 5分
            'licenses': 1800,  # 30分
            'reports': 1800    # 30分
        }
    
    def validate_config(self, config: Dict[str, Any]) -> List[str]:
        """設定の妥当性を検証"""
        errors = []
        
        # 必須項目チェック
        required_keys = [
            'authentication.tenant_id',
            'authentication.client_id'
        ]
        
        for key in required_keys:
            if self._get_nested_value(config, key) is None:
                errors.append(f"Required configuration missing: {key}")
        
        # 認証方式チェック
        has_client_secret = self._get_nested_value(config, 'authentication.client_secret')
        has_certificate = (
            self._get_nested_value(config, 'authentication.certificate_path') or
            self._get_nested_value(config, 'authentication.certificate_thumbprint')
        )
        
        if not has_client_secret and not has_certificate:
            errors.append("Authentication configuration incomplete: need either client_secret or certificate")
        
        # パス存在チェック
        output_path = self._get_nested_value(config, 'reports.output_path')
        if output_path:
            try:
                Path(output_path).mkdir(parents=True, exist_ok=True)
            except Exception as e:
                errors.append(f"Cannot create output directory {output_path}: {e}")
        
        return errors
    
    def merge_configs(self, base_config: Dict[str, Any], override_config: Dict[str, Any]) -> Dict[str, Any]:
        """設定をマージ"""
        def deep_merge(base: Dict, override: Dict) -> Dict:
            result = base.copy()
            
            for key, value in override.items():
                if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                    result[key] = deep_merge(result[key], value)
                else:
                    result[key] = value
            
            return result
        
        return deep_merge(base_config, override_config)


def convert_powershell_config(ps_config_path: Union[str, Path], 
                            py_config_path: Union[str, Path] = None) -> Dict[str, Any]:
    """PowerShell設定ファイルをPython形式に変換（便利関数）"""
    converter = ConfigConverter()
    return converter.convert_config_file(ps_config_path, py_config_path)