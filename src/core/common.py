"""
Common module for Microsoft 365 Management Tools.
Python equivalent of Common.psm1 with enhanced initialization and configuration management.
"""

import json
import os
import sys
import logging
import platform
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional, List, Union
from dataclasses import dataclass
from enum import Enum

from .config import Config
from .logging_config import setup_logging
from .auth.authenticator import Authenticator
from .auth.graph_auth import GraphAuthenticator
from .auth.exchange_auth import ExchangeAuthenticator


class InitializationError(Exception):
    """Exception raised when initialization fails."""
    pass


class ServiceType(Enum):
    """Microsoft 365 service types."""
    MICROSOFT_GRAPH = "MicrosoftGraph"
    EXCHANGE_ONLINE = "ExchangeOnline"
    TEAMS = "Teams"
    SHAREPOINT = "SharePoint"
    ONEDRIVE = "OneDrive"
    AZURE_AD = "AzureAD"


@dataclass
class SystemInfo:
    """System information data class."""
    python_version: str
    os_version: str
    machine_name: str
    user_name: str
    timestamp: str
    timezone: str
    platform: str
    architecture: str


@dataclass
class AuthenticationResult:
    """Authentication result data class."""
    success: bool
    connected_services: List[str]
    failed_services: List[str]
    error_messages: List[str]
    timestamp: datetime


class ManagementToolsInitializer:
    """
    Main initializer for Microsoft 365 Management Tools.
    Python equivalent of PowerShell Common.psm1 functionality.
    """
    
    def __init__(self, config_path: Optional[Path] = None):
        self.config_path = config_path
        self.config: Optional[Config] = None
        self.logger: Optional[logging.Logger] = None
        self.authenticators: Dict[ServiceType, Authenticator] = {}
        self._initialized = False
    
    def initialize(self, skip_authentication: bool = False) -> Config:
        """
        Initialize Microsoft 365 Management Tools.
        
        Args:
            skip_authentication: Whether to skip automatic authentication
            
        Returns:
            Loaded configuration
            
        Raises:
            InitializationError: If initialization fails
        """
        try:
            # Setup logging first
            setup_logging()
            self.logger = logging.getLogger(__name__)
            
            self.logger.info("Initializing Microsoft 365 Management Tools")
            
            # Load configuration
            self.config = self._load_configuration()
            
            # Configure logging with settings from config
            self._configure_logging()
            
            # Initialize authenticators
            self._initialize_authenticators()
            
            # Auto-authenticate if not skipped
            if not skip_authentication:
                auth_result = self._auto_authenticate()
                if auth_result.success:
                    self.logger.info(f"Authentication successful: {', '.join(auth_result.connected_services)}")
                    if auth_result.failed_services:
                        self.logger.warning(f"Authentication failed for: {', '.join(auth_result.failed_services)}")
                else:
                    self.logger.warning("Authentication partially failed. Some features may be limited.")
            
            self._initialized = True
            self.logger.info("Microsoft 365 Management Tools initialized successfully")
            
            return self.config
            
        except Exception as e:
            error_msg = f"Initialization error: {str(e)}"
            if self.logger:
                self.logger.error(error_msg)
            raise InitializationError(error_msg) from e
    
    def _load_configuration(self) -> Config:
        """
        Load configuration with support for local overrides.
        Equivalent to PowerShell configuration merging logic.
        """
        # Determine config paths
        if self.config_path:
            base_config_path = self.config_path
        else:
            base_config_path = Path("Config/appsettings.json")
        
        # Check for local configuration file
        local_config_path = base_config_path.parent / "appsettings.local.json"
        
        config = Config(base_config_path)
        
        # Load base configuration
        if base_config_path.exists():
            base_settings = config.load()
            self.logger.info(f"Configuration loaded from: {base_config_path}")
        else:
            self.logger.warning(f"Configuration file not found: {base_config_path}")
            base_settings = {}
        
        # Merge with local configuration if exists
        if local_config_path.exists():
            self.logger.info(f"Local configuration detected: {local_config_path}")
            local_config = Config(local_config_path)
            local_settings = local_config.load()
            
            # Merge configurations (local overrides base)
            merged_settings = self._merge_configurations(base_settings, local_settings)
            config.settings = merged_settings
            self.logger.info(f"Configuration merged: {base_config_path} + {local_config_path}")
        
        return config
    
    def _merge_configurations(self, base: Dict[str, Any], local: Dict[str, Any]) -> Dict[str, Any]:
        """
        Deep merge two configuration dictionaries.
        Local configuration takes precedence over base.
        """
        def merge_dict(base_dict: Dict[str, Any], local_dict: Dict[str, Any]) -> Dict[str, Any]:
            merged = base_dict.copy()
            
            for key, value in local_dict.items():
                if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
                    merged[key] = merge_dict(merged[key], value)
                else:
                    merged[key] = value
            
            return merged
        
        try:
            return merge_dict(base, local)
        except Exception as e:
            self.logger.warning(f"Configuration merge failed: {e}")
            return local  # Fallback to local configuration
    
    def _configure_logging(self):
        """
        Configure logging based on configuration settings.
        """
        log_level = self.config.get('Logging.Level', 'INFO')
        log_dir = self.config.get('Logging.Directory', 'Logs')
        
        # Ensure log directory exists
        Path(log_dir).mkdir(parents=True, exist_ok=True)
        
        # Update logging configuration
        logging.getLogger().setLevel(getattr(logging, log_level.upper(), logging.INFO))
        
        self.logger.info(f"Logging configured: Level={log_level}, Directory={log_dir}")
    
    def _initialize_authenticators(self):
        """
        Initialize authenticators for different services.
        """
        try:
            # Initialize Graph authenticator
            self.authenticators[ServiceType.MICROSOFT_GRAPH] = GraphAuthenticator(self.config)
            self.logger.debug("Graph authenticator initialized")
            
            # Initialize Exchange authenticator
            self.authenticators[ServiceType.EXCHANGE_ONLINE] = ExchangeAuthenticator(self.config)
            self.logger.debug("Exchange authenticator initialized")
            
            # Add more authenticators as needed
            
        except Exception as e:
            self.logger.error(f"Failed to initialize authenticators: {e}")
            raise
    
    def _auto_authenticate(self) -> AuthenticationResult:
        """
        Perform automatic authentication to Microsoft 365 services.
        """
        self.logger.info("Starting automatic authentication to Microsoft 365 services")
        
        connected_services = []
        failed_services = []
        error_messages = []
        
        # Default services to authenticate
        services_to_connect = [
            ServiceType.MICROSOFT_GRAPH,
            ServiceType.EXCHANGE_ONLINE
        ]
        
        for service in services_to_connect:
            try:
                if service in self.authenticators:
                    authenticator = self.authenticators[service]
                    
                    # Determine authentication method from config
                    auth_method = self.config.get('Authentication.AuthMethod', 'Certificate')
                    
                    # Authenticate
                    if hasattr(authenticator, 'connect'):
                        result = authenticator.connect()
                        if result:
                            connected_services.append(service.value)
                            self.logger.info(f"Successfully connected to {service.value}")
                        else:
                            failed_services.append(service.value)
                            self.logger.warning(f"Failed to connect to {service.value}")
                    else:
                        # Fallback to basic authentication
                        auth_result = authenticator.authenticate()
                        if auth_result and auth_result.success:
                            connected_services.append(service.value)
                            self.logger.info(f"Successfully authenticated to {service.value}")
                        else:
                            failed_services.append(service.value)
                            error_msg = auth_result.error if auth_result else "Unknown error"
                            error_messages.append(f"{service.value}: {error_msg}")
                            self.logger.warning(f"Authentication failed for {service.value}: {error_msg}")
                
            except Exception as e:
                failed_services.append(service.value)
                error_msg = str(e)
                error_messages.append(f"{service.value}: {error_msg}")
                self.logger.error(f"Authentication error for {service.value}: {error_msg}")
        
        success = len(connected_services) > 0
        
        return AuthenticationResult(
            success=success,
            connected_services=connected_services,
            failed_services=failed_services,
            error_messages=error_messages,
            timestamp=datetime.now()
        )
    
    def get_system_info(self) -> SystemInfo:
        """
        Get system information.
        Python equivalent of PowerShell Get-SystemInfo function.
        """
        import getpass
        
        return SystemInfo(
            python_version=sys.version,
            os_version=platform.platform(),
            machine_name=platform.node(),
            user_name=getpass.getuser(),
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            timezone=str(datetime.now().astimezone().tzinfo),
            platform=platform.system(),
            architecture=platform.architecture()[0]
        )
    
    def test_system_requirements(self) -> Dict[str, Any]:
        """
        Test system requirements.
        Python equivalent of PowerShell Test-SystemRequirements function.
        """
        requirements = {
            "python_version": "3.9",
            "required_packages": ["msal", "requests", "PyQt6", "pandas", "jinja2"]
        }
        
        results = {
            "system_info": self.get_system_info(),
            "requirements_met": True,
            "issues": []
        }
        
        # Check Python version
        current_version = sys.version_info
        required_version = tuple(map(int, requirements["python_version"].split(".")))
        
        if current_version < required_version:
            results["requirements_met"] = False
            results["issues"].append(f"Python version {sys.version} is below required {requirements['python_version']}")
        
        # Check required packages
        missing_packages = []
        for package in requirements["required_packages"]:
            try:
                __import__(package)
            except ImportError:
                missing_packages.append(package)
        
        if missing_packages:
            results["requirements_met"] = False
            results["issues"].append(f"Missing required packages: {', '.join(missing_packages)}")
        
        return results
    
    def get_authenticator(self, service: ServiceType) -> Optional[Authenticator]:
        """
        Get authenticator for a specific service.
        
        Args:
            service: Service type
            
        Returns:
            Authenticator instance or None if not found
        """
        return self.authenticators.get(service)
    
    def is_initialized(self) -> bool:
        """
        Check if the tools are initialized.
        
        Returns:
            True if initialized, False otherwise
        """
        return self._initialized
    
    def get_config(self) -> Optional[Config]:
        """
        Get the current configuration.
        
        Returns:
            Configuration instance or None if not initialized
        """
        return self.config


# Global initializer instance
_initializer: Optional[ManagementToolsInitializer] = None


def initialize_management_tools(config_path: Optional[Path] = None, 
                              skip_authentication: bool = False) -> Config:
    """
    Initialize Microsoft 365 Management Tools.
    
    Args:
        config_path: Optional path to configuration file
        skip_authentication: Whether to skip automatic authentication
        
    Returns:
        Loaded configuration
    """
    global _initializer
    
    if _initializer is None:
        _initializer = ManagementToolsInitializer(config_path)
    
    return _initializer.initialize(skip_authentication)


def get_initializer() -> Optional[ManagementToolsInitializer]:
    """
    Get the global initializer instance.
    
    Returns:
        Initializer instance or None if not initialized
    """
    return _initializer


def get_system_info() -> SystemInfo:
    """
    Get system information.
    
    Returns:
        System information
    """
    if _initializer:
        return _initializer.get_system_info()
    else:
        # Create temporary instance for system info
        temp_init = ManagementToolsInitializer()
        return temp_init.get_system_info()


def test_system_requirements() -> Dict[str, Any]:
    """
    Test system requirements.
    
    Returns:
        Requirements test results
    """
    if _initializer:
        return _initializer.test_system_requirements()
    else:
        # Create temporary instance for testing
        temp_init = ManagementToolsInitializer()
        return temp_init.test_system_requirements()
