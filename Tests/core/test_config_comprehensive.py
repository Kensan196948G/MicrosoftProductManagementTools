#!/usr/bin/env python3
"""
Comprehensive Config Module Tests - Emergency Coverage Boost
Tests all methods, edge cases, and error conditions in src/core/config.py
"""

import pytest
import json
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, mock_open
import logging

from src.core.config import Config


class TestConfigComprehensive:
    """Comprehensive tests for Config class to achieve 85%+ coverage."""
    
    def test_init_default_path(self):
        """Test Config initialization with default path."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            assert config.config_path is not None
            assert config.settings == {}
    
    def test_init_custom_path(self):
        """Test Config initialization with custom path."""
        custom_path = Path("/custom/config.json")
        with patch('src.core.config.load_dotenv'):
            config = Config(config_path=custom_path)
            assert config.config_path == custom_path
    
    def test_get_default_config_path_existing_files(self):
        """Test _get_default_config_path with existing files."""
        with patch('pathlib.Path.exists') as mock_exists:
            # Mock first path exists
            mock_exists.side_effect = [True, False, False, False]
            
            config = Config()
            assert "appsettings.json" in str(config.config_path)
    
    def test_get_default_config_path_no_existing_files(self):
        """Test _get_default_config_path with no existing files."""
        with patch('pathlib.Path.exists') as mock_exists:
            mock_exists.return_value = False
            
            config = Config()
            assert "appsettings.json" in str(config.config_path)
    
    def test_load_env_with_existing_files(self):
        """Test _load_env with existing .env files."""
        with patch('pathlib.Path.exists') as mock_exists:
            mock_exists.side_effect = [True, False, False, False]
            
            with patch('src.core.config.load_dotenv') as mock_load_dotenv:
                config = Config()
                mock_load_dotenv.assert_called()
    
    def test_load_env_no_existing_files(self):
        """Test _load_env with no existing .env files."""
        with patch('pathlib.Path.exists') as mock_exists:
            mock_exists.return_value = False
            
            with patch('src.core.config.load_dotenv') as mock_load_dotenv:
                config = Config()
                # Should not call load_dotenv if no .env files exist
                mock_load_dotenv.assert_not_called()
    
    def test_load_existing_config_file(self):
        """Test load() with existing config file."""
        mock_config_data = {
            "Authentication": {
                "TenantId": "test-tenant",
                "ClientId": "test-client"
            }
        }
        
        with patch('pathlib.Path.exists', return_value=True):
            with patch('builtins.open', mock_open(read_data=json.dumps(mock_config_data))):
                with patch('src.core.config.load_dotenv'):
                    config = Config()
                    result = config.load()
                    
                    assert result == mock_config_data
                    assert config.settings == mock_config_data
    
    def test_load_nonexistent_config_file(self):
        """Test load() with non-existent config file."""
        with patch('pathlib.Path.exists', return_value=False):
            with patch('src.core.config.load_dotenv'):
                config = Config()
                result = config.load()
                
                # Should create default config
                assert "Authentication" in result
                assert "ReportSettings" in result
                assert "GuiSettings" in result
    
    def test_load_invalid_json(self):
        """Test load() with invalid JSON."""
        with patch('pathlib.Path.exists', return_value=True):
            with patch('builtins.open', mock_open(read_data="invalid json")):
                with patch('src.core.config.load_dotenv'):
                    config = Config()
                    result = config.load()
                    
                    # Should create default config on JSON error
                    assert "Authentication" in result
    
    def test_load_file_permission_error(self):
        """Test load() with file permission error."""
        with patch('pathlib.Path.exists', return_value=True):
            with patch('builtins.open', side_effect=PermissionError("Permission denied")):
                with patch('src.core.config.load_dotenv'):
                    config = Config()
                    result = config.load()
                    
                    # Should create default config on permission error
                    assert "Authentication" in result
    
    def test_create_default_config_all_sections(self):
        """Test _create_default_config creates all required sections."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config._create_default_config()
            
            required_sections = [
                "Authentication",
                "ReportSettings", 
                "GuiSettings",
                "ApiSettings",
                "UISettings",
                "Logging",
                "Features",
                "ExchangeOnlineSettings",
                "TeamsSettings",
                "SecuritySettings"
            ]
            
            for section in required_sections:
                assert section in config.settings
    
    def test_create_default_config_with_env_vars(self):
        """Test _create_default_config with environment variables."""
        env_vars = {
            "M365_TENANT_ID": "test-tenant",
            "M365_CLIENT_ID": "test-client",
            "M365_CLIENT_SECRET": "test-secret"
        }
        
        with patch.dict(os.environ, env_vars):
            with patch('src.core.config.load_dotenv'):
                config = Config()
                config._create_default_config()
                
                assert config.settings["Authentication"]["TenantId"] == "test-tenant"
                assert config.settings["Authentication"]["ClientId"] == "test-client"
                assert config.settings["Authentication"]["ClientSecret"] == "test-secret"
    
    def test_apply_env_overrides_all_mappings(self):
        """Test _apply_env_overrides with all possible mappings."""
        env_vars = {
            "M365_TENANT_ID": "override-tenant",
            "M365_CLIENT_ID": "override-client",
            "M365_CLIENT_SECRET": "override-secret",
            "M365_CERT_THUMBPRINT": "override-thumbprint",
            "M365_CERT_PATH": "override-path",
            "M365_CERT_PASSWORD": "override-password",
            "M365_OUTPUT_DIR": "override-output",
            "M365_LOG_LEVEL": "DEBUG"
        }
        
        with patch.dict(os.environ, env_vars):
            with patch('src.core.config.load_dotenv'):
                config = Config()
                config._create_default_config()
                config._apply_env_overrides()
                
                assert config.settings["Authentication"]["TenantId"] == "override-tenant"
                assert config.settings["Authentication"]["ClientId"] == "override-client"
                assert config.settings["Authentication"]["ClientSecret"] == "override-secret"
                assert config.settings["Authentication"]["CertificateThumbprint"] == "override-thumbprint"
                assert config.settings["Authentication"]["CertificatePath"] == "override-path"
                assert config.settings["Authentication"]["CertificatePassword"] == "override-password"
                assert config.settings["ReportSettings"]["OutputDirectory"] == "override-output"
                assert config.settings["Logging"]["Level"] == "DEBUG"
    
    def test_apply_env_overrides_no_env_vars(self):
        """Test _apply_env_overrides with no environment variables."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config._create_default_config()
            original_settings = config.settings.copy()
            
            config._apply_env_overrides()
            
            # Settings should remain unchanged
            assert config.settings == original_settings
    
    def test_set_nested_value_simple(self):
        """Test _set_nested_value with simple path."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            data = {}
            
            config._set_nested_value(data, ["key"], "value")
            
            assert data["key"] == "value"
    
    def test_set_nested_value_nested(self):
        """Test _set_nested_value with nested path."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            data = {}
            
            config._set_nested_value(data, ["level1", "level2", "key"], "value")
            
            assert data["level1"]["level2"]["key"] == "value"
    
    def test_set_nested_value_existing_structure(self):
        """Test _set_nested_value with existing structure."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            data = {"level1": {"existing": "value"}}
            
            config._set_nested_value(data, ["level1", "level2", "key"], "new_value")
            
            assert data["level1"]["level2"]["key"] == "new_value"
            assert data["level1"]["existing"] == "value"
    
    def test_get_simple_key(self):
        """Test get() with simple key."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "value"}
            
            result = config.get("key")
            assert result == "value"
    
    def test_get_nested_key(self):
        """Test get() with nested key using dot notation."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "level1": {
                    "level2": {
                        "key": "nested_value"
                    }
                }
            }
            
            result = config.get("level1.level2.key")
            assert result == "nested_value"
    
    def test_get_nonexistent_key(self):
        """Test get() with non-existent key."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "value"}
            
            result = config.get("nonexistent")
            assert result is None
    
    def test_get_with_default(self):
        """Test get() with default value."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "value"}
            
            result = config.get("nonexistent", "default_value")
            assert result == "default_value"
    
    def test_get_partial_path(self):
        """Test get() with partial path that doesn't exist."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"level1": "not_dict"}
            
            result = config.get("level1.level2.key", "default")
            assert result == "default"
    
    def test_get_empty_path(self):
        """Test get() with empty path."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "value"}
            
            result = config.get("", "default")
            assert result == "default"
    
    def test_set_simple_key(self):
        """Test set() with simple key."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {}
            
            config.set("key", "value")
            assert config.settings["key"] == "value"
    
    def test_set_nested_key(self):
        """Test set() with nested key using dot notation."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {}
            
            config.set("level1.level2.key", "nested_value")
            assert config.settings["level1"]["level2"]["key"] == "nested_value"
    
    def test_set_override_existing(self):
        """Test set() overriding existing value."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "old_value"}
            
            config.set("key", "new_value")
            assert config.settings["key"] == "new_value"
    
    def test_save_success(self):
        """Test save() successful operation."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "value"}
            
            with patch('pathlib.Path.mkdir') as mock_mkdir:
                with patch('builtins.open', mock_open()) as mock_file:
                    config.save()
                    
                    mock_mkdir.assert_called_once()
                    mock_file.assert_called_once()
    
    def test_save_file_error(self):
        """Test save() with file write error."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "value"}
            
            with patch('pathlib.Path.mkdir'):
                with patch('builtins.open', side_effect=PermissionError("Permission denied")):
                    with pytest.raises(PermissionError):
                        config.save()
    
    def test_save_directory_creation_error(self):
        """Test save() with directory creation error."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {"key": "value"}
            
            with patch('pathlib.Path.mkdir', side_effect=OSError("Cannot create directory")):
                with pytest.raises(OSError):
                    config.save()
    
    def test_validate_success_client_secret(self):
        """Test validate() with valid client secret configuration."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "TenantId": "test-tenant",
                    "ClientId": "test-client",
                    "ClientSecret": "test-secret"
                }
            }
            
            result = config.validate()
            assert result is True
    
    def test_validate_success_certificate_thumbprint(self):
        """Test validate() with valid certificate thumbprint configuration."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "TenantId": "test-tenant",
                    "ClientId": "test-client",
                    "CertificateThumbprint": "test-thumbprint"
                }
            }
            
            result = config.validate()
            assert result is True
    
    def test_validate_success_certificate_path(self):
        """Test validate() with valid certificate path configuration."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "TenantId": "test-tenant",
                    "ClientId": "test-client",
                    "CertificatePath": "test-path"
                }
            }
            
            result = config.validate()
            assert result is True
    
    def test_validate_missing_tenant_id(self):
        """Test validate() with missing tenant ID."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "ClientId": "test-client",
                    "ClientSecret": "test-secret"
                }
            }
            
            result = config.validate()
            assert result is False
    
    def test_validate_missing_client_id(self):
        """Test validate() with missing client ID."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "TenantId": "test-tenant",
                    "ClientSecret": "test-secret"
                }
            }
            
            result = config.validate()
            assert result is False
    
    def test_validate_no_auth_method(self):
        """Test validate() with no authentication method."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "TenantId": "test-tenant",
                    "ClientId": "test-client"
                }
            }
            
            result = config.validate()
            assert result is False
    
    def test_validate_empty_values(self):
        """Test validate() with empty values."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "TenantId": "",
                    "ClientId": "test-client",
                    "ClientSecret": "test-secret"
                }
            }
            
            result = config.validate()
            assert result is False
    
    def test_validate_none_values(self):
        """Test validate() with None values."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "Authentication": {
                    "TenantId": None,
                    "ClientId": "test-client",
                    "ClientSecret": "test-secret"
                }
            }
            
            result = config.validate()
            assert result is False
    
    def test_validate_missing_authentication_section(self):
        """Test validate() with missing Authentication section."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {}
            
            result = config.validate()
            assert result is False
    
    def test_integration_load_and_validate(self):
        """Test integration of load() and validate()."""
        mock_config_data = {
            "Authentication": {
                "TenantId": "test-tenant",
                "ClientId": "test-client",
                "ClientSecret": "test-secret"
            }
        }
        
        with patch('pathlib.Path.exists', return_value=True):
            with patch('builtins.open', mock_open(read_data=json.dumps(mock_config_data))):
                with patch('src.core.config.load_dotenv'):
                    config = Config()
                    config.load()
                    
                    result = config.validate()
                    assert result is True
    
    def test_integration_set_and_get(self):
        """Test integration of set() and get()."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            
            config.set("test.nested.key", "test_value")
            result = config.get("test.nested.key")
            
            assert result == "test_value"
    
    def test_integration_env_override_and_get(self):
        """Test integration of environment override and get()."""
        env_vars = {
            "M365_TENANT_ID": "env-tenant",
            "M365_CLIENT_ID": "env-client"
        }
        
        with patch.dict(os.environ, env_vars):
            with patch('src.core.config.load_dotenv'):
                config = Config()
                config.load()
                
                tenant_id = config.get("Authentication.TenantId")
                client_id = config.get("Authentication.ClientId")
                
                assert tenant_id == "env-tenant"
                assert client_id == "env-client"
    
    def test_logging_integration(self):
        """Test logging integration in Config class."""
        with patch('src.core.config.load_dotenv'):
            with patch('logging.getLogger') as mock_get_logger:
                mock_logger = Mock()
                mock_get_logger.return_value = mock_logger
                
                config = Config()
                config.load()
                
                # Verify logger was created
                mock_get_logger.assert_called_with('src.core.config')
    
    def test_config_path_types(self):
        """Test Config with different path types."""
        # Test with string path
        with patch('src.core.config.load_dotenv'):
            config = Config(config_path="test_path.json")
            assert isinstance(config.config_path, Path)
            assert str(config.config_path).endswith("test_path.json")
        
        # Test with Path object
        with patch('src.core.config.load_dotenv'):
            path_obj = Path("test_path.json")
            config = Config(config_path=path_obj)
            assert config.config_path == path_obj
    
    def test_edge_cases_empty_settings(self):
        """Test edge cases with empty settings."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {}
            
            # Test get with empty settings
            result = config.get("any.key", "default")
            assert result == "default"
            
            # Test validate with empty settings
            result = config.validate()
            assert result is False
    
    def test_edge_cases_deeply_nested_get(self):
        """Test get() with deeply nested structure."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "a": {
                    "b": {
                        "c": {
                            "d": {
                                "e": "deep_value"
                            }
                        }
                    }
                }
            }
            
            result = config.get("a.b.c.d.e")
            assert result == "deep_value"
    
    def test_edge_cases_special_characters_in_values(self):
        """Test configuration with special characters."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            
            special_value = "test!@#$%^&*()_+{}|:<>?[]\\;'\",./"
            config.set("special.key", special_value)
            
            result = config.get("special.key")
            assert result == special_value
    
    def test_concurrency_safety(self):
        """Test thread safety of Config operations."""
        import threading
        
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {}
            
            def set_value(key, value):
                config.set(f"thread.{key}", value)
            
            def get_value(key):
                return config.get(f"thread.{key}")
            
            # Create multiple threads
            threads = []
            for i in range(10):
                thread = threading.Thread(target=set_value, args=(f"key{i}", f"value{i}"))
                threads.append(thread)
                thread.start()
            
            # Wait for all threads
            for thread in threads:
                thread.join()
            
            # Verify all values were set
            for i in range(10):
                result = get_value(f"key{i}")
                assert result == f"value{i}"


# Additional edge case tests
class TestConfigEdgeCases:
    """Additional edge case tests for complete coverage."""
    
    def test_home_directory_config_path(self):
        """Test config path resolution to home directory."""
        with patch('pathlib.Path.exists') as mock_exists:
            # Mock home directory path exists
            mock_exists.side_effect = [False, False, False, True]
            
            with patch('src.core.config.load_dotenv'):
                config = Config()
                assert ".m365tools" in str(config.config_path)
    
    def test_resolve_path_absolute(self):
        """Test path resolution with absolute paths."""
        with patch('pathlib.Path.exists', return_value=True):
            with patch('pathlib.Path.resolve') as mock_resolve:
                mock_resolve.return_value = Path("/absolute/path/config.json")
                
                with patch('src.core.config.load_dotenv'):
                    config = Config()
                    mock_resolve.assert_called()
    
    def test_json_encoding_utf8(self):
        """Test JSON encoding with UTF-8 characters."""
        with patch('src.core.config.load_dotenv'):
            config = Config()
            config.settings = {
                "unicode": "こんにちは世界",
                "emoji": "🎉🎊",
                "special": "åäöüß"
            }
            
            with patch('pathlib.Path.mkdir'):
                with patch('builtins.open', mock_open()) as mock_file:
                    config.save()
                    
                    # Verify encoding parameter
                    mock_file.assert_called_once_with(config.config_path, 'w', encoding='utf-8')


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])