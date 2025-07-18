"""
Unit tests for configuration management module.
Tests Config class functionality including loading, validation, and environment overrides.
"""

import pytest
import json
import os
from pathlib import Path
from unittest.mock import patch, mock_open, MagicMock
import tempfile
import shutil

# Import the module to test
import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))
from core.config import Config


class TestConfig:
    """Test suite for Config class."""
    
    @pytest.fixture
    def temp_config_dir(self):
        """Create temporary directory for test configs."""
        temp_dir = tempfile.mkdtemp()
        yield Path(temp_dir)
        shutil.rmtree(temp_dir)
    
    @pytest.fixture
    def sample_config(self):
        """Sample configuration data."""
        return {
            "Authentication": {
                "TenantId": "test-tenant-id",
                "ClientId": "test-client-id",
                "ClientSecret": "test-secret",
                "CertificateThumbprint": "",
                "CertificatePath": "",
                "UseModernAuth": True,
                "AuthMethod": "ClientSecret"
            },
            "ReportSettings": {
                "OutputPath": "Reports",
                "EnableAutoOpen": True,
                "DefaultFormat": "both",
                "MaxRecords": 1000
            },
            "Logging": {
                "Level": "INFO",
                "Directory": "Logs"
            }
        }
    
    @pytest.fixture
    def config_file(self, temp_config_dir, sample_config):
        """Create a temporary config file."""
        config_path = temp_config_dir / "appsettings.json"
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(sample_config, f, indent=2)
        return config_path
    
    def test_init_default_path(self):
        """Test Config initialization with default path."""
        config = Config()
        assert config.config_path.name == "appsettings.json"
        assert config.settings == {}
    
    def test_init_custom_path(self, temp_config_dir):
        """Test Config initialization with custom path."""
        custom_path = temp_config_dir / "custom_config.json"
        config = Config(custom_path)
        assert config.config_path == custom_path
    
    def test_load_existing_config(self, config_file, sample_config):
        """Test loading existing configuration file."""
        config = Config(config_file)
        loaded = config.load()
        
        assert loaded == sample_config
        assert config.settings == sample_config
        assert config.get("Authentication.TenantId") == "test-tenant-id"
    
    def test_load_missing_config(self, temp_config_dir):
        """Test loading when config file doesn't exist."""
        missing_path = temp_config_dir / "missing.json"
        config = Config(missing_path)
        
        loaded = config.load()
        assert "Authentication" in loaded
        assert "ReportSettings" in loaded
        assert loaded["Authentication"]["TenantId"] == ""  # Default empty
    
    def test_load_corrupted_config(self, temp_config_dir):
        """Test loading corrupted JSON file."""
        corrupted_path = temp_config_dir / "corrupted.json"
        with open(corrupted_path, 'w') as f:
            f.write("{ invalid json }")
        
        config = Config(corrupted_path)
        loaded = config.load()
        
        # Should create default config on error
        assert "Authentication" in loaded
        assert isinstance(loaded, dict)
    
    @patch.dict(os.environ, {
        "M365_TENANT_ID": "env-tenant-id",
        "M365_CLIENT_ID": "env-client-id",
        "M365_LOG_LEVEL": "DEBUG"
    })
    def test_env_overrides(self, config_file):
        """Test environment variable overrides."""
        config = Config(config_file)
        config.load()
        
        # Environment variables should override file values
        assert config.get("Authentication.TenantId") == "env-tenant-id"
        assert config.get("Authentication.ClientId") == "env-client-id"
        assert config.get("Logging.Level") == "DEBUG"
        # Non-overridden value should remain
        assert config.get("Authentication.ClientSecret") == "test-secret"
    
    def test_get_nested_value(self, config_file):
        """Test getting nested configuration values."""
        config = Config(config_file)
        config.load()
        
        # Test various nested paths
        assert config.get("Authentication.TenantId") == "test-tenant-id"
        assert config.get("ReportSettings.MaxRecords") == 1000
        assert config.get("Logging.Level") == "INFO"
        
        # Test with default
        assert config.get("NonExistent.Path", "default") == "default"
        assert config.get("Authentication.NonExistent", None) is None
    
    def test_set_nested_value(self):
        """Test setting nested configuration values."""
        config = Config()
        config.settings = {}
        
        # Set various nested values
        config.set("Authentication.TenantId", "new-tenant")
        config.set("ReportSettings.OutputPath", "NewReports")
        config.set("Deep.Nested.Path.Value", "test")
        
        assert config.get("Authentication.TenantId") == "new-tenant"
        assert config.get("ReportSettings.OutputPath") == "NewReports"
        assert config.get("Deep.Nested.Path.Value") == "test"
    
    def test_save_config(self, temp_config_dir):
        """Test saving configuration to file."""
        config_path = temp_config_dir / "save_test.json"
        config = Config(config_path)
        
        # Set some values
        config.settings = {
            "Test": {"Value": "saved"}
        }
        
        # Save
        config.save()
        
        # Verify file exists and contains correct data
        assert config_path.exists()
        with open(config_path, 'r', encoding='utf-8') as f:
            saved_data = json.load(f)
        assert saved_data == {"Test": {"Value": "saved"}}
    
    def test_save_creates_directory(self, temp_config_dir):
        """Test save creates directory if not exists."""
        nested_path = temp_config_dir / "nested" / "dir" / "config.json"
        config = Config(nested_path)
        config.settings = {"Test": "Value"}
        
        config.save()
        
        assert nested_path.exists()
        assert nested_path.parent.exists()
    
    def test_validate_valid_config(self):
        """Test validation of valid configuration."""
        config = Config()
        config.settings = {
            "Authentication": {
                "TenantId": "tenant-123",
                "ClientId": "client-456",
                "ClientSecret": "secret-789"
            }
        }
        
        assert config.validate() is True
    
    def test_validate_missing_required(self):
        """Test validation with missing required fields."""
        config = Config()
        
        # Missing TenantId
        config.settings = {
            "Authentication": {
                "ClientId": "client-456",
                "ClientSecret": "secret-789"
            }
        }
        assert config.validate() is False
        
        # Missing ClientId
        config.settings = {
            "Authentication": {
                "TenantId": "tenant-123",
                "ClientSecret": "secret-789"
            }
        }
        assert config.validate() is False
    
    def test_validate_missing_auth_method(self):
        """Test validation with missing authentication method."""
        config = Config()
        config.settings = {
            "Authentication": {
                "TenantId": "tenant-123",
                "ClientId": "client-456"
                # No auth method (ClientSecret, Certificate, etc.)
            }
        }
        
        assert config.validate() is False
    
    def test_validate_certificate_auth(self):
        """Test validation with certificate authentication."""
        config = Config()
        config.settings = {
            "Authentication": {
                "TenantId": "tenant-123",
                "ClientId": "client-456",
                "CertificatePath": "/path/to/cert.pfx"
            }
        }
        
        assert config.validate() is True
    
    def test_default_config_structure(self):
        """Test default configuration has all required sections."""
        config = Config()
        config._create_default_config()
        
        # Check main sections exist
        assert "Authentication" in config.settings
        assert "ReportSettings" in config.settings
        assert "GuiSettings" in config.settings
        assert "ApiSettings" in config.settings
        assert "UISettings" in config.settings
        assert "Logging" in config.settings
        assert "Features" in config.settings
        assert "ExchangeOnlineSettings" in config.settings
        assert "TeamsSettings" in config.settings
        assert "SecuritySettings" in config.settings
        
        # Check PowerShell compatibility fields
        assert config.settings["ReportSettings"]["OutputPath"] == "Reports"
        assert config.settings["GuiSettings"]["AutoOpenFiles"] is True
        assert config.settings["Features"]["EnablePowerShellBridge"] is True
    
    @patch("pathlib.Path.exists")
    def test_get_default_config_path(self, mock_exists):
        """Test default config path resolution."""
        config = Config()
        
        # Test each possible path in order
        test_paths = [
            ("Config/appsettings.json", True),
            ("../Config/appsettings.json", True),
            ("../../Config/appsettings.json", True),
            (str(Path.home() / ".m365tools" / "config.json"), True)
        ]
        
        for test_path, should_exist in test_paths:
            mock_exists.reset_mock()
            mock_exists.return_value = should_exist
            
            # Only the first existing path should be returned
            def side_effect(path):
                return str(path).endswith(test_path) and should_exist
            
            mock_exists.side_effect = side_effect
            result = config._get_default_config_path()
            
            if should_exist:
                assert test_path in str(result)
                break
    
    @patch("dotenv.load_dotenv")
    @patch("pathlib.Path.exists")
    def test_load_env(self, mock_exists, mock_load_dotenv):
        """Test environment file loading."""
        config = Config()
        
        # Test .env exists
        mock_exists.side_effect = lambda x: str(x) == ".env"
        config._load_env()
        mock_load_dotenv.assert_called_once_with(".env")
        
        # Test .env.local exists
        mock_load_dotenv.reset_mock()
        mock_exists.side_effect = lambda x: str(x) == ".env.local"
        config._load_env()
        mock_load_dotenv.assert_called_once_with(".env.local")
    
    def test_powershell_compatibility(self):
        """Test PowerShell configuration compatibility."""
        config = Config()
        config._create_default_config()
        
        # Check PowerShell-specific settings
        assert config.get("ExchangeOnlineSettings.ConnectionUri") == "https://outlook.office365.com/powershell-liveid/"
        assert config.get("ExchangeOnlineSettings.Prefix") == "EXO"
        assert config.get("GuiSettings.ShowPopupNotifications") is True
        assert config.get("ReportSettings.EnableRealTimeData") is True
        
        # Check both OutputPath and OutputDirectory exist (aliases)
        assert config.get("ReportSettings.OutputPath") == "Reports"
        assert config.get("ReportSettings.OutputDirectory") == "Reports"


class TestConfigIntegration:
    """Integration tests for Config class."""
    
    @pytest.fixture
    def real_config_file(self, tmp_path):
        """Create a real configuration file for integration testing."""
        config_dir = tmp_path / "Config"
        config_dir.mkdir()
        config_file = config_dir / "appsettings.json"
        
        config_data = {
            "Authentication": {
                "TenantId": "integration-tenant",
                "ClientId": "integration-client",
                "ClientSecret": "integration-secret",
                "UseModernAuth": True
            },
            "ReportSettings": {
                "OutputPath": "TestReports",
                "MaxRecords": 500
            }
        }
        
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config_data, f)
        
        return config_file
    
    def test_full_config_lifecycle(self, real_config_file):
        """Test complete configuration lifecycle: load, modify, save, reload."""
        # Initial load
        config = Config(real_config_file)
        config.load()
        
        assert config.get("Authentication.TenantId") == "integration-tenant"
        assert config.get("ReportSettings.MaxRecords") == 500
        
        # Modify
        config.set("Authentication.TenantId", "modified-tenant")
        config.set("NewSection.NewValue", "test-value")
        
        # Save
        config.save()
        
        # Create new instance and reload
        config2 = Config(real_config_file)
        config2.load()
        
        assert config2.get("Authentication.TenantId") == "modified-tenant"
        assert config2.get("NewSection.NewValue") == "test-value"
        assert config2.get("ReportSettings.MaxRecords") == 500  # Unchanged
    
    @patch.dict(os.environ, {
        "M365_TENANT_ID": "env-override-tenant",
        "M365_OUTPUT_DIR": "EnvReports"
    })
    def test_env_override_integration(self, real_config_file):
        """Test environment override in real scenario."""
        config = Config(real_config_file)
        config.load()
        
        # Environment should override file
        assert config.get("Authentication.TenantId") == "env-override-tenant"
        assert config.get("ReportSettings.OutputDirectory") == "EnvReports"
        
        # Non-overridden values should remain from file
        assert config.get("Authentication.ClientId") == "integration-client"
        assert config.get("ReportSettings.MaxRecords") == 500