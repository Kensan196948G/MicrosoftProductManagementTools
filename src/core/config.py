"""
Configuration management for Microsoft365 Management Tools.
Maintains compatibility with existing PowerShell configuration.
"""

import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
import yaml
from dotenv import load_dotenv
import logging


class Config:
    """
    Configuration manager that maintains compatibility with existing 
    PowerShell appsettings.json structure.
    """
    
    def __init__(self, config_path: Optional[Path] = None):
        self.logger = logging.getLogger(__name__)
        self.config_path = config_path or self._get_default_config_path()
        self.settings: Dict[str, Any] = {}
        self._load_env()
        
    def _get_default_config_path(self) -> Path:
        """Get default configuration path."""
        # Check multiple locations for config
        possible_paths = [
            Path("Config/appsettings.json"),
            Path("../Config/appsettings.json"),
            Path("../../Config/appsettings.json"),
            Path.home() / ".m365tools" / "config.json"
        ]
        
        for path in possible_paths:
            if path.exists():
                return path.resolve()
                
        # Default to Config/appsettings.json
        return Path("Config/appsettings.json").resolve()
    
    def _load_env(self):
        """Load environment variables."""
        # Load .env file if exists
        env_paths = [".env", ".env.local", "../.env", "../../.env"]
        for env_path in env_paths:
            if Path(env_path).exists():
                load_dotenv(env_path)
                self.logger.debug(f"Loaded environment from {env_path}")
                break
    
    def load(self) -> Dict[str, Any]:
        """Load configuration from file."""
        try:
            if self.config_path.exists():
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    self.settings = json.load(f)
                self.logger.info(f"Configuration loaded from {self.config_path}")
            else:
                self.logger.warning(f"Configuration file not found: {self.config_path}")
                self._create_default_config()
                
            # Override with environment variables
            self._apply_env_overrides()
            
            return self.settings
            
        except Exception as e:
            self.logger.error(f"Failed to load configuration: {e}")
            self._create_default_config()
            return self.settings
    
    def _create_default_config(self):
        """Create default configuration structure compatible with PowerShell version."""
        self.settings = {
            "Authentication": {
                "TenantId": os.getenv("M365_TENANT_ID", ""),
                "ClientId": os.getenv("M365_CLIENT_ID", ""),
                "ClientSecret": os.getenv("M365_CLIENT_SECRET", ""),
                "CertificateThumbprint": os.getenv("M365_CERT_THUMBPRINT", ""),
                "CertificatePath": os.getenv("M365_CERT_PATH", ""),
                "CertificatePassword": os.getenv("M365_CERT_PASSWORD", ""),
                "UseModernAuth": True,
                "AuthMethod": "Certificate"  # Certificate | ClientSecret | Interactive
            },
            "ReportSettings": {
                "OutputPath": "Reports",  # PowerShell互換
                "OutputDirectory": "Reports",  # Python用エイリアス
                "EnableAutoOpen": True,
                "DefaultFormat": "both",  # html | csv | both
                "MaxRecords": 1000,
                "EnableRealTimeData": True
            },
            "GuiSettings": {  # PowerShell互換
                "AutoOpenFiles": True,
                "ShowPopupNotifications": True,
                "LogLevel": "INFO",
                "Theme": "light",
                "Language": "ja"
            },
            "ApiSettings": {
                "GraphApiVersion": "v1.0",
                "BatchSize": 100,
                "RetryCount": 3,
                "RetryDelay": 5,
                "Timeout": 300
            },
            "UISettings": {  # 追加UI設定
                "Theme": "light",
                "Language": "ja",
                "ShowNotifications": True,
                "AutoRefresh": False,
                "RefreshInterval": 300
            },
            "Logging": {
                "Level": "INFO",
                "Directory": "Logs",
                "MaxFileSize": "10MB",
                "MaxFiles": 5,
                "Format": "detailed"
            },
            "Features": {
                "EnablePowerShellBridge": True,
                "EnableAsyncOperations": True,
                "EnableCaching": True,
                "CacheExpiration": 3600
            },
            # PowerShell互換の追加セクション
            "ExchangeOnlineSettings": {
                "ConnectionUri": "https://outlook.office365.com/powershell-liveid/",
                "AzureADAuthorizationEndpointUri": "https://login.microsoftonline.com/common/oauth2/authorize",
                "Prefix": "EXO",
                "UseBasicParsing": True
            },
            "TeamsSettings": {
                "EnableDirectRouting": False,
                "MaxConcurrentConnections": 10
            },
            "SecuritySettings": {
                "EncryptCredentials": True,
                "AuditLogging": True,
                "RequireMFA": False
            }
        }
    
    def _apply_env_overrides(self):
        """Apply environment variable overrides to configuration."""
        # Map environment variables to config paths
        env_mappings = {
            "M365_TENANT_ID": ["Authentication", "TenantId"],
            "M365_CLIENT_ID": ["Authentication", "ClientId"],
            "M365_CLIENT_SECRET": ["Authentication", "ClientSecret"],
            "M365_CERT_THUMBPRINT": ["Authentication", "CertificateThumbprint"],
            "M365_CERT_PATH": ["Authentication", "CertificatePath"],
            "M365_CERT_PASSWORD": ["Authentication", "CertificatePassword"],
            "M365_OUTPUT_DIR": ["ReportSettings", "OutputDirectory"],
            "M365_LOG_LEVEL": ["Logging", "Level"]
        }
        
        for env_var, config_path in env_mappings.items():
            value = os.getenv(env_var)
            if value:
                self._set_nested_value(self.settings, config_path, value)
                self.logger.debug(f"Applied override from {env_var}")
    
    def _set_nested_value(self, data: Dict, path: list, value: Any):
        """Set a value in nested dictionary using path list."""
        for key in path[:-1]:
            data = data.setdefault(key, {})
        data[path[-1]] = value
    
    def get(self, key_path: str, default: Any = None) -> Any:
        """
        Get configuration value using dot notation.
        Example: config.get('Authentication.TenantId')
        """
        keys = key_path.split('.')
        value = self.settings
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
                
        return value
    
    def set(self, key_path: str, value: Any):
        """
        Set configuration value using dot notation.
        Example: config.set('Authentication.TenantId', 'xxx')
        """
        keys = key_path.split('.')
        self._set_nested_value(self.settings, keys, value)
    
    def save(self):
        """Save configuration to file."""
        try:
            # Ensure directory exists
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Save as JSON (PowerShell compatible)
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.settings, f, indent=2, ensure_ascii=False)
                
            self.logger.info(f"Configuration saved to {self.config_path}")
            
        except Exception as e:
            self.logger.error(f"Failed to save configuration: {e}")
            raise
    
    def validate(self) -> bool:
        """Validate configuration has required values."""
        required_fields = [
            "Authentication.TenantId",
            "Authentication.ClientId"
        ]
        
        # At least one auth method required
        auth_methods = [
            "Authentication.ClientSecret",
            "Authentication.CertificateThumbprint",
            "Authentication.CertificatePath"
        ]
        
        # Check required fields
        for field in required_fields:
            if not self.get(field):
                self.logger.error(f"Required configuration missing: {field}")
                return False
        
        # Check at least one auth method
        if not any(self.get(method) for method in auth_methods):
            self.logger.error("No authentication method configured")
            return False
            
        return True