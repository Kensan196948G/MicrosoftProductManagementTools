# Microsoft 365 Management Tools - CLI Configuration Management
# PowerShell Enhanced CLI compatible configuration

import os
import json
from typing import Any, Dict, Optional
from pathlib import Path

class CLIConfig:
    """CLI Configuration Manager - PowerShell Enhanced CLI Compatible"""
    
    def __init__(self, config_file: Optional[str] = None):
        self.config_data = {}
        self.config_file = config_file or self._find_default_config()
        
        if self.config_file and Path(self.config_file).exists():
            self._load_config()
        else:
            self._load_default_config()
    
    def _find_default_config(self) -> Optional[str]:
        """Find default configuration file"""
        possible_paths = [
            "Config/appsettings.json",
            "appsettings.json", 
            "config.json"
        ]
        
        for path in possible_paths:
            if Path(path).exists():
                return path
        
        return None
    
    def _load_config(self):
        """Load configuration from file"""
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                self.config_data = json.load(f)
        except Exception as e:
            print(f"Warning: Failed to load config file {self.config_file}: {e}")
            self._load_default_config()
    
    def _load_default_config(self):
        """Load default configuration"""
        self.config_data = {
            "Output": {
                "DefaultPath": "Reports",
                "AutoOpenFiles": True,
                "ShowPopup": True,
                "CsvEncoding": "UTF-8 BOM"
            },
            "Performance": {
                "MaxResults": 1000,
                "BatchSize": 100,
                "ParallelRequests": 4,
                "CacheEnabled": True
            },
            "Authentication": {
                "TenantId": "",
                "ClientId": "",
                "CertificatePath": "",
                "CertificateThumbprint": "",
                "Scopes": [
                    "https://graph.microsoft.com/.default"
                ]
            },
            "Database": {
                "Host": "localhost",
                "Port": 5432,
                "Name": "microsoft365_tools",
                "Username": "postgres",
                "Password": "",
                "ConnectionTimeout": 30
            },
            "Cache": {
                "Redis": {
                    "Host": "localhost",
                    "Port": 6379,
                    "Database": 0,
                    "Password": ""
                },
                "Enabled": True,
                "DefaultTTL": 300
            },
            "Logging": {
                "Level": "INFO",
                "Directory": "Logs/CLI",
                "MaxFiles": 10,
                "MaxSizeMB": 10
            },
            "Features": {
                "PowerShellCompatibility": True,
                "InteractiveMenu": True,
                "AutoUpdate": False,
                "TelemetryEnabled": False
            }
        }
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value using dot notation"""
        keys = key.split('.')
        value = self.config_data
        
        try:
            for k in keys:
                value = value[k]
            return value
        except (KeyError, TypeError):
            return default
    
    def set(self, key: str, value: Any):
        """Set configuration value using dot notation"""
        keys = key.split('.')
        config = self.config_data
        
        # Navigate to parent
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        
        # Set value
        config[keys[-1]] = value
    
    def save(self, file_path: Optional[str] = None):
        """Save configuration to file"""
        save_path = file_path or self.config_file
        
        if not save_path:
            save_path = "config.json"
        
        try:
            # Ensure directory exists
            Path(save_path).parent.mkdir(parents=True, exist_ok=True)
            
            with open(save_path, 'w', encoding='utf-8') as f:
                json.dump(self.config_data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error: Failed to save config to {save_path}: {e}")
    
    def get_output_config(self) -> Dict[str, Any]:
        """Get output configuration"""
        return {
            'default_path': self.get('Output.DefaultPath', 'Reports'),
            'auto_open_files': self.get('Output.AutoOpenFiles', True),
            'show_popup': self.get('Output.ShowPopup', True),
            'csv_encoding': self.get('Output.CsvEncoding', 'UTF-8 BOM')
        }
    
    def get_auth_config(self) -> Dict[str, Any]:
        """Get authentication configuration"""
        return {
            'tenant_id': self.get('Authentication.TenantId', ''),
            'client_id': self.get('Authentication.ClientId', ''),
            'certificate_path': self.get('Authentication.CertificatePath', ''),
            'certificate_thumbprint': self.get('Authentication.CertificateThumbprint', ''),
            'scopes': self.get('Authentication.Scopes', [])
        }
    
    def get_database_config(self) -> Dict[str, Any]:
        """Get database configuration"""
        return {
            'host': self.get('Database.Host', 'localhost'),
            'port': self.get('Database.Port', 5432),
            'name': self.get('Database.Name', 'microsoft365_tools'),
            'username': self.get('Database.Username', 'postgres'),
            'password': self.get('Database.Password', ''),
            'connection_timeout': self.get('Database.ConnectionTimeout', 30)
        }
    
    def get_cache_config(self) -> Dict[str, Any]:
        """Get cache configuration"""
        return {
            'host': self.get('Cache.Redis.Host', 'localhost'),
            'port': self.get('Cache.Redis.Port', 6379),
            'database': self.get('Cache.Redis.Database', 0),
            'password': self.get('Cache.Redis.Password', ''),
            'enabled': self.get('Cache.Enabled', True),
            'default_ttl': self.get('Cache.DefaultTTL', 300)
        }
    
    def get_performance_config(self) -> Dict[str, Any]:
        """Get performance configuration"""
        return {
            'max_results': self.get('Performance.MaxResults', 1000),
            'batch_size': self.get('Performance.BatchSize', 100),
            'parallel_requests': self.get('Performance.ParallelRequests', 4),
            'cache_enabled': self.get('Performance.CacheEnabled', True)
        }
    
    def is_feature_enabled(self, feature: str) -> bool:
        """Check if feature is enabled"""
        return self.get(f'Features.{feature}', False)
    
    def update_from_env(self):
        """Update configuration from environment variables"""
        env_mappings = {
            'AZURE_TENANT_ID': 'Authentication.TenantId',
            'AZURE_CLIENT_ID': 'Authentication.ClientId',
            'DATABASE_HOST': 'Database.Host',
            'DATABASE_PORT': 'Database.Port',
            'DATABASE_NAME': 'Database.Name',
            'DATABASE_USERNAME': 'Database.Username',
            'DATABASE_PASSWORD': 'Database.Password',
            'REDIS_HOST': 'Cache.Redis.Host',
            'REDIS_PORT': 'Cache.Redis.Port',
            'REDIS_PASSWORD': 'Cache.Redis.Password',
            'CLI_LOG_LEVEL': 'Logging.Level',
            'CLI_OUTPUT_PATH': 'Output.DefaultPath'
        }
        
        for env_var, config_key in env_mappings.items():
            env_value = os.getenv(env_var)
            if env_value:
                # Type conversion for numeric values
                if config_key.endswith('.Port'):
                    try:
                        env_value = int(env_value)
                    except ValueError:
                        continue
                elif config_key.endswith('.Database') and config_key.startswith('Cache'):
                    try:
                        env_value = int(env_value)
                    except ValueError:
                        continue
                
                self.set(config_key, env_value)
    
    def validate(self) -> tuple[bool, list[str]]:
        """Validate configuration"""
        errors = []
        
        # Check required authentication fields
        if not self.get('Authentication.TenantId') and not os.getenv('AZURE_TENANT_ID'):
            errors.append("Authentication.TenantId is required")
        
        if not self.get('Authentication.ClientId') and not os.getenv('AZURE_CLIENT_ID'):
            errors.append("Authentication.ClientId is required")
        
        # Check database configuration
        if not self.get('Database.Password') and not os.getenv('DATABASE_PASSWORD'):
            errors.append("Database.Password is required")
        
        # Check output directory
        output_path = self.get('Output.DefaultPath')
        if output_path:
            try:
                Path(output_path).mkdir(parents=True, exist_ok=True)
            except Exception as e:
                errors.append(f"Cannot create output directory {output_path}: {e}")
        
        return len(errors) == 0, errors
    
    def __str__(self) -> str:
        """String representation"""
        return f"CLIConfig(file={self.config_file})"
    
    def __repr__(self) -> str:
        return self.__str__()