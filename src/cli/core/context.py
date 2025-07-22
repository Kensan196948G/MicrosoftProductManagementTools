# Microsoft 365 Management Tools - CLI Context Management
# Global CLI execution context and configuration

import os
from typing import Dict, Any, Optional, List
from pathlib import Path
from dataclasses import dataclass, field

from src.core.config import Config

@dataclass
class CLIContext:
    """CLI execution context - PowerShell Enhanced CLI compatible"""
    
    # Configuration
    config: Optional[Config] = None
    config_file: Optional[str] = None
    
    # Execution mode
    verbose: bool = False
    dry_run: bool = False
    batch_mode: bool = False
    no_connect: bool = False
    
    # Output configuration
    output_formats: Dict[str, bool] = field(default_factory=lambda: {
        'csv': False,
        'html': False, 
        'json': False,
        'table': True  # Default format
    })
    output_path: Optional[str] = None
    
    # Data processing
    max_results: int = 1000
    
    # Authentication
    tenant_id: Optional[str] = None
    client_id: Optional[str] = None
    
    # Runtime state
    authenticated: bool = False
    graph_connected: bool = False
    exchange_connected: bool = False
    
    def configure(self, **kwargs):
        """Configure CLI context from arguments"""
        
        # Update from kwargs
        for key, value in kwargs.items():
            if hasattr(self, key) and value is not None:
                setattr(self, key, value)
        
        # Load configuration file
        if self.config_file:
            self.config = Config(self.config_file)
        elif self.config is None:
            # Try to find default config
            default_config = Path("Config/appsettings.json")
            if default_config.exists():
                self.config = Config(str(default_config))
            else:
                # Create minimal config
                self.config = Config()
        
        # Set up output path
        if not self.output_path:
            self.output_path = self.config.get('Output.DefaultPath', 'Reports')
        
        # Ensure output directory exists
        Path(self.output_path).mkdir(parents=True, exist_ok=True)
        
        # Override from environment variables
        self._load_from_environment()
    
    def _load_from_environment(self):
        """Load configuration from environment variables"""
        
        # Authentication
        if not self.tenant_id:
            self.tenant_id = os.getenv('AZURE_TENANT_ID')
        if not self.client_id:
            self.client_id = os.getenv('AZURE_CLIENT_ID')
        
        # Output configuration
        if os.getenv('CLI_OUTPUT_CSV', '').lower() == 'true':
            self.output_formats['csv'] = True
        if os.getenv('CLI_OUTPUT_HTML', '').lower() == 'true':
            self.output_formats['html'] = True
        if os.getenv('CLI_OUTPUT_JSON', '').lower() == 'true':
            self.output_formats['json'] = True
        
        # Execution mode
        if os.getenv('CLI_BATCH_MODE', '').lower() == 'true':
            self.batch_mode = True
        if os.getenv('CLI_DRY_RUN', '').lower() == 'true':
            self.dry_run = True
        if os.getenv('CLI_NO_CONNECT', '').lower() == 'true':
            self.no_connect = True
        
        # Data processing
        max_results_env = os.getenv('CLI_MAX_RESULTS')
        if max_results_env:
            try:
                self.max_results = int(max_results_env)
            except ValueError:
                pass  # Use default
    
    def get_output_path(self, filename: str) -> str:
        """Get full output path for a file"""
        return str(Path(self.output_path) / filename)
    
    def should_output_format(self, format_type: str) -> bool:
        """Check if specific output format is enabled"""
        return self.output_formats.get(format_type, False)
    
    def get_active_output_formats(self) -> List[str]:
        """Get list of active output formats"""
        return [fmt for fmt, enabled in self.output_formats.items() if enabled]
    
    def is_powershell_compatible_mode(self) -> bool:
        """Check if running in PowerShell compatibility mode"""
        # PowerShell compatibility when using CSV or HTML output
        return (self.output_formats.get('csv', False) or 
                self.output_formats.get('html', False))
    
    def get_config_value(self, key: str, default=None):
        """Get configuration value with fallback"""
        if self.config:
            return self.config.get(key, default)
        return default
    
    def get_authentication_config(self) -> Dict[str, Any]:
        """Get authentication configuration"""
        auth_config = {
            'tenant_id': self.tenant_id,
            'client_id': self.client_id,
        }
        
        # Add from config file if available
        if self.config:
            auth_config.update({
                'certificate_path': self.config.get('Authentication.CertificatePath'),
                'certificate_thumbprint': self.config.get('Authentication.CertificateThumbprint'),
                'client_secret': self.config.get('Authentication.ClientSecret'),
                'scopes': self.config.get('Authentication.Scopes', [])
            })
        
        return {k: v for k, v in auth_config.items() if v is not None}
    
    def get_database_config(self) -> Dict[str, Any]:
        """Get database configuration"""
        if not self.config:
            return {}
        
        return {
            'host': self.config.get('Database.Host', 'localhost'),
            'port': self.config.get('Database.Port', 5432),
            'database': self.config.get('Database.Name', 'microsoft365_tools'),
            'username': self.config.get('Database.Username', 'postgres'),
            'password': self.config.get('Database.Password', ''),
        }
    
    def get_cache_config(self) -> Dict[str, Any]:
        """Get cache configuration"""
        if not self.config:
            return {}
        
        return {
            'host': self.config.get('Cache.Redis.Host', 'localhost'),
            'port': self.config.get('Cache.Redis.Port', 6379),
            'db': self.config.get('Cache.Redis.Database', 0),
            'password': self.config.get('Cache.Redis.Password'),
            'enabled': self.config.get('Cache.Enabled', True)
        }
    
    def __str__(self) -> str:
        """String representation for debugging"""
        return (f"CLIContext(batch={self.batch_mode}, dry_run={self.dry_run}, "
                f"formats={self.get_active_output_formats()}, "
                f"output_path={self.output_path})")
    
    def __repr__(self) -> str:
        return self.__str__()