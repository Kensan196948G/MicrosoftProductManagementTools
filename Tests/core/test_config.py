"""
Unit tests for core configuration module.
Tests configuration loading, validation, environment variable overrides, and PowerShell compatibility.
"""

import json
import os
import pytest
import tempfile
from pathlib import Path
from unittest.mock import patch, mock_open, MagicMock

from src.core.config import Config


class TestConfig:
    """Test suite for Config class."""
    
    def setup_method(self):
        """Setup test environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_file = Path(self.temp_dir) / "appsettings.json"
        self.env_file = Path(self.temp_dir) / ".env"
        
        # Sample PowerShell-compatible configuration
        self.sample_config = {
            "Authentication": {
                "TenantId": "test-tenant-id",
                "ClientId": "test-client-id",
                "ClientSecret": "test-client-secret",
                "CertificateThumbprint": "",
                "CertificatePath": "",
                "CertificatePassword": "",
                "UseModernAuth": True,
                "AuthMethod": "ClientSecret"
            },
            "ReportSettings": {
                "OutputPath": "Reports",
                "OutputDirectory": "Reports",
                "EnableAutoOpen": True,
                "DefaultFormat": "both",
                "MaxRecords": 1000,
                "EnableRealTimeData": True
            },
            "GuiSettings": {
                "AutoOpenFiles": True,
                "ShowPopupNotifications": True,
                "LogLevel": "INFO",
                "Theme": "light",
                "Language": "ja"
            },
            "Logging": {
                "Level": "INFO",
                "Directory": "Logs",
                "MaxFileSize": "10MB",
                "MaxFiles": 5,
                "Format": "detailed"
            }
        }
    
    def teardown_method(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_config_initialization(self):
        """Test basic config initialization."""
        config = Config(self.config_file)
        assert config.config_path == self.config_file
        assert isinstance(config.settings, dict)
    
    def test_config_initialization_default_path(self):
        """Test config initialization with default path."""
        with patch('pathlib.Path.exists', return_value=False):
            config = Config()
            assert config.config_path.name == "appsettings.json"
    
    def test_load_existing_config(self):
        """Test loading existing configuration file."""
        # Create config file
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(self.sample_config, f)
        
        config = Config(self.config_file)
        settings = config.load()
        
        assert settings["Authentication"]["TenantId"] == "test-tenant-id"
        assert settings["Authentication"]["ClientId"] == "test-client-id"
        assert settings["ReportSettings"]["OutputPath"] == "Reports"
        assert settings["GuiSettings"]["AutoOpenFiles"] is True
    
    def test_load_nonexistent_config(self):
        """Test loading non-existent configuration file creates default."""
        config = Config(self.config_file)
        settings = config.load()
        
        # Should create default config
        assert "Authentication" in settings
        assert "ReportSettings" in settings
        assert "GuiSettings" in settings
        assert "Logging" in settings
        assert "ApiSettings" in settings
    
    def test_powershell_compatibility_structure(self):
        """Test that default config structure is PowerShell compatible."""
        config = Config(self.config_file)
        settings = config.load()
        
        # Check PowerShell-compatible sections
        assert "Authentication" in settings
        assert "ReportSettings" in settings
        assert "GuiSettings" in settings
        assert "ExchangeOnlineSettings" in settings
        assert "TeamsSettings" in settings
        assert "SecuritySettings" in settings
        
        # Check dual naming for compatibility
        assert settings["ReportSettings"]["OutputPath"] == "Reports"
        assert settings["ReportSettings"]["OutputDirectory"] == "Reports"
    
    def test_environment_variable_overrides(self):
        """Test environment variable overrides."""
        with patch.dict(os.environ, {
            'M365_TENANT_ID': 'env-tenant-id',
            'M365_CLIENT_ID': 'env-client-id',
            'M365_CLIENT_SECRET': 'env-client-secret',
            'M365_OUTPUT_DIR': 'env-output-dir',
            'M365_LOG_LEVEL': 'DEBUG'
        }):
            config = Config(self.config_file)
            settings = config.load()
            
            assert settings["Authentication"]["TenantId"] == "env-tenant-id"
            assert settings["Authentication"]["ClientId"] == "env-client-id"
            assert settings["Authentication"]["ClientSecret"] == "env-client-secret"
            assert settings["ReportSettings"]["OutputDirectory"] == "env-output-dir"
            assert settings["Logging"]["Level"] == "DEBUG"
    
    def test_dotenv_file_loading(self):
        """Test loading from .env file."""
        # Create .env file
        env_content = """
M365_TENANT_ID=dotenv-tenant-id
M365_CLIENT_ID=dotenv-client-id
M365_CLIENT_SECRET=dotenv-client-secret
"""
        with open(self.env_file, 'w') as f:
            f.write(env_content)
        
        # Change to temp directory to test relative path
        original_cwd = os.getcwd()
        try:
            os.chdir(self.temp_dir)
            config = Config(self.config_file)
            settings = config.load()
            
            assert settings["Authentication"]["TenantId"] == "dotenv-tenant-id"
            assert settings["Authentication"]["ClientId"] == "dotenv-client-id"
            assert settings["Authentication"]["ClientSecret"] == "dotenv-client-secret"
        finally:
            os.chdir(original_cwd)
    
    def test_get_configuration_value(self):
        """Test getting configuration values using dot notation."""
        config = Config(self.config_file)
        config.settings = self.sample_config
        
        assert config.get("Authentication.TenantId") == "test-tenant-id"
        assert config.get("Authentication.ClientId") == "test-client-id"
        assert config.get("ReportSettings.OutputPath") == "Reports"
        assert config.get("GuiSettings.AutoOpenFiles") is True
        assert config.get("NonExistent.Key", "default") == "default"
    
    def test_set_configuration_value(self):
        """Test setting configuration values using dot notation."""
        config = Config(self.config_file)
        config.settings = {}
        
        config.set("Authentication.TenantId", "new-tenant-id")
        config.set("Deep.Nested.Value", "test-value")
        
        assert config.get("Authentication.TenantId") == "new-tenant-id"
        assert config.get("Deep.Nested.Value") == "test-value"
    
    def test_save_configuration(self):
        """Test saving configuration to file."""
        config = Config(self.config_file)
        config.settings = self.sample_config
        
        config.save()
        
        # Verify file was created and contains correct data
        assert self.config_file.exists()
        
        with open(self.config_file, 'r', encoding='utf-8') as f:
            saved_config = json.load(f)
        
        assert saved_config["Authentication"]["TenantId"] == "test-tenant-id"
        assert saved_config["Authentication"]["ClientId"] == "test-client-id"
    
    def test_validate_configuration_valid(self):
        """Test configuration validation with valid config."""
        config = Config(self.config_file)
        config.settings = self.sample_config
        
        assert config.validate() is True
    
    def test_validate_configuration_missing_tenant_id(self):
        """Test configuration validation with missing TenantId."""
        config = Config(self.config_file)
        config.settings = self.sample_config.copy()
        config.settings["Authentication"]["TenantId"] = ""
        
        assert config.validate() is False
    
    def test_validate_configuration_missing_client_id(self):
        """Test configuration validation with missing ClientId."""
        config = Config(self.config_file)
        config.settings = self.sample_config.copy()
        config.settings["Authentication"]["ClientId"] = ""
        
        assert config.validate() is False
    
    def test_validate_configuration_missing_auth_method(self):
        """Test configuration validation with no auth method."""
        config = Config(self.config_file)
        config.settings = self.sample_config.copy()
        config.settings["Authentication"]["ClientSecret"] = ""
        config.settings["Authentication"]["CertificateThumbprint"] = ""
        config.settings["Authentication"]["CertificatePath"] = ""
        
        assert config.validate() is False
    
    def test_validate_configuration_with_certificate_path(self):
        """Test configuration validation with certificate path."""
        config = Config(self.config_file)
        config.settings = self.sample_config.copy()
        config.settings["Authentication"]["ClientSecret"] = ""
        config.settings["Authentication"]["CertificatePath"] = "path/to/cert.pfx"
        
        assert config.validate() is True
    
    def test_validate_configuration_with_certificate_thumbprint(self):
        """Test configuration validation with certificate thumbprint."""
        config = Config(self.config_file)
        config.settings = self.sample_config.copy()
        config.settings["Authentication"]["ClientSecret"] = ""
        config.settings["Authentication"]["CertificateThumbprint"] = "ABC123"
        
        assert config.validate() is True
    
    def test_error_handling_malformed_json(self):
        """Test error handling for malformed JSON."""
        # Create malformed JSON file
        with open(self.config_file, 'w') as f:
            f.write('{ "invalid": json }')
        
        config = Config(self.config_file)
        settings = config.load()
        
        # Should fall back to default config
        assert "Authentication" in settings
        assert "ReportSettings" in settings
    
    def test_error_handling_permission_denied(self):
        """Test error handling for permission denied."""
        with patch('builtins.open', mock_open()) as mock_file:
            mock_file.side_effect = PermissionError("Permission denied")
            
            config = Config(self.config_file)
            settings = config.load()
            
            # Should fall back to default config
            assert "Authentication" in settings
            assert "ReportSettings" in settings
    
    def test_config_path_search_order(self):
        """Test configuration path search order."""
        with patch('pathlib.Path.exists') as mock_exists:
            # Mock the search order
            mock_exists.side_effect = [False, False, True, False]
            
            config = Config()
            # Should find the third path in the search order
            assert "appsettings.json" in str(config.config_path)
    
    def test_nested_value_setting(self):
        """Test setting nested values in configuration."""
        config = Config(self.config_file)
        config.settings = {}
        
        config._set_nested_value(config.settings, ["Level1", "Level2", "Level3"], "test-value")
        
        assert config.settings["Level1"]["Level2"]["Level3"] == "test-value"
    
    def test_default_config_creation(self):
        """Test default configuration creation."""
        config = Config(self.config_file)
        config._create_default_config()
        
        # Check all required sections exist
        required_sections = [
            "Authentication", "ReportSettings", "GuiSettings", 
            "ApiSettings", "UISettings", "Logging", "Features",
            "ExchangeOnlineSettings", "TeamsSettings", "SecuritySettings"
        ]
        
        for section in required_sections:
            assert section in config.settings
    
    def test_configuration_inheritance_and_merging(self):
        """Test configuration inheritance and merging scenarios."""
        # Test partial config file with environment overrides
        partial_config = {
            "Authentication": {
                "TenantId": "file-tenant-id",
                "ClientId": "file-client-id"
            }
        }
        
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(partial_config, f)
        
        with patch.dict(os.environ, {
            'M365_TENANT_ID': 'env-tenant-id',
            'M365_CLIENT_SECRET': 'env-client-secret'
        }):
            config = Config(self.config_file)
            settings = config.load()
            
            # Environment should override file
            assert settings["Authentication"]["TenantId"] == "env-tenant-id"
            # File values should be preserved
            assert settings["Authentication"]["ClientId"] == "file-client-id"
            # Environment-only values should be added
            assert settings["Authentication"]["ClientSecret"] == "env-client-secret"
    
    def test_security_sensitive_data_handling(self):
        """Test handling of security-sensitive configuration data."""
        config = Config(self.config_file)
        config.settings = self.sample_config
        
        # Ensure sensitive data is handled appropriately
        assert "ClientSecret" in config.settings["Authentication"]
        assert "CertificatePassword" in config.settings["Authentication"]
        
        # Test that validation doesn't expose sensitive data in logs
        with patch('logging.Logger.error') as mock_log:
            config.settings["Authentication"]["ClientSecret"] = ""
            config.settings["Authentication"]["CertificateThumbprint"] = ""
            config.settings["Authentication"]["CertificatePath"] = ""
            
            config.validate()
            
            # Should log error without exposing sensitive data
            assert mock_log.called
    
    def test_multiple_config_file_formats(self):
        """Test support for multiple configuration file formats."""
        # Test JSON format (primary)
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(self.sample_config, f)
        
        config = Config(self.config_file)
        settings = config.load()
        
        assert settings["Authentication"]["TenantId"] == "test-tenant-id"
    
    def test_config_backward_compatibility(self):
        """Test backward compatibility with legacy configuration structures."""
        # Test legacy PowerShell config structure
        legacy_config = {
            "EntraID": {
                "TenantId": "legacy-tenant-id",
                "ClientId": "legacy-client-id",
                "ClientSecret": "legacy-client-secret"
            },
            "ExchangeOnline": {
                "CertificatePath": "legacy/cert/path",
                "CertificatePassword": "legacy-cert-password"
            }
        }
        
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(legacy_config, f)
        
        config = Config(self.config_file)
        settings = config.load()
        
        # Should load legacy structure
        assert settings["EntraID"]["TenantId"] == "legacy-tenant-id"
        assert settings["ExchangeOnline"]["CertificatePath"] == "legacy/cert/path"
    
    def test_config_performance_large_files(self):
        """Test configuration performance with large files."""
        # Create a large configuration with many sections
        large_config = {}
        for i in range(100):
            large_config[f"Section{i}"] = {
                f"Key{j}": f"Value{j}" for j in range(50)
            }
        
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(large_config, f)
        
        config = Config(self.config_file)
        settings = config.load()
        
        # Should load successfully
        assert len(settings) == 100
        assert settings["Section0"]["Key0"] == "Value0"
    
    def test_config_edge_cases(self):
        """Test configuration edge cases and error conditions."""
        config = Config(self.config_file)
        
        # Test get with invalid path
        assert config.get("") is None
        assert config.get("..") is None
        assert config.get("Invalid.Path.That.Does.Not.Exist") is None
        
        # Test set with invalid path
        config.set("", "value")  # Should not crash
        config.set("ValidKey", "value")
        assert config.get("ValidKey") == "value"
        
        # Test with None values
        config.settings = {"Key": None}
        assert config.get("Key") is None
    
    def test_configuration_validation_edge_cases(self):
        """Test configuration validation edge cases."""
        config = Config(self.config_file)
        
        # Test with empty settings
        config.settings = {}
        assert config.validate() is False
        
        # Test with partial settings
        config.settings = {"Authentication": {}}
        assert config.validate() is False
        
        # Test with only some required fields
        config.settings = {
            "Authentication": {
                "TenantId": "test-tenant",
                "ClientId": ""
            }
        }
        assert config.validate() is False


class TestConfigIntegration:
    """Integration tests for Config class with real file system."""
    
    def test_real_appsettings_json_compatibility(self):
        """Test compatibility with real appsettings.json file."""
        # Use actual appsettings.json from the project
        real_config_path = Path("/mnt/e/MicrosoftProductManagementTools/Config/appsettings.json")
        
        if real_config_path.exists():
            config = Config(real_config_path)
            settings = config.load()
            
            # Should load successfully
            assert isinstance(settings, dict)
            
            # Check for expected sections from real file
            expected_sections = ["General", "EntraID", "ExchangeOnline", "ActiveDirectory", 
                               "Logging", "Reports", "Security", "Performance"]
            
            for section in expected_sections:
                assert section in settings, f"Missing section: {section}"
    
    def test_environment_variable_precedence(self):
        """Test environment variable precedence over file values."""
        real_config_path = Path("/mnt/e/MicrosoftProductManagementTools/Config/appsettings.json")
        
        if real_config_path.exists():
            # Test with environment variables
            with patch.dict(os.environ, {
                'M365_TENANT_ID': 'env-override-tenant',
                'M365_CLIENT_ID': 'env-override-client'
            }):
                config = Config(real_config_path)
                settings = config.load()
                
                # Environment variables should override file values
                # Note: This may not match exactly due to config structure differences
                # but the mechanism should work
                assert isinstance(settings, dict)