"""
pytest configuration and fixtures for GUI tests.
"""

import pytest
import sys
import os
from unittest.mock import Mock, patch
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))


@pytest.fixture(scope="session")
def qapp():
    """Create QApplication instance for testing session."""
    if not QApplication.instance():
        app = QApplication([])
        app.setAttribute(Qt.ApplicationAttribute.AA_DisableWindowContextHelpButton)
        yield app
        app.quit()
    else:
        yield QApplication.instance()


@pytest.fixture
def mock_config():
    """Create mock configuration object."""
    config = Mock()
    config.get.return_value = "test_value"
    config.get_section.return_value = {"test_key": "test_value"}
    return config


@pytest.fixture
def mock_logger():
    """Create mock logger."""
    logger = Mock()
    logger.info.return_value = None
    logger.error.return_value = None
    logger.warning.return_value = None
    logger.debug.return_value = None
    return logger


@pytest.fixture
def mock_graph_client():
    """Create mock Microsoft Graph client."""
    client = Mock()
    client.get_users.return_value = [
        {
            "id": "user1",
            "displayName": "Test User 1",
            "userPrincipalName": "test1@example.com",
            "mail": "test1@example.com",
            "accountEnabled": True
        },
        {
            "id": "user2", 
            "displayName": "Test User 2",
            "userPrincipalName": "test2@example.com",
            "mail": "test2@example.com",
            "accountEnabled": True
        }
    ]
    client.get_licenses.return_value = [
        {
            "skuId": "sku1",
            "skuPartNumber": "ENTERPRISEPACK",
            "consumedUnits": 50,
            "prepaidUnits": {"enabled": 100}
        }
    ]
    return client


@pytest.fixture
def sample_report_data():
    """Create sample report data for testing."""
    return [
        {
            "ID": 1,
            "Name": "Test Item 1",
            "Status": "Active",
            "Date": "2025-01-18",
            "Category": "Test"
        },
        {
            "ID": 2,
            "Name": "Test Item 2", 
            "Status": "Inactive",
            "Date": "2025-01-17",
            "Category": "Test"
        }
    ]


@pytest.fixture
def temp_directory(tmp_path):
    """Create temporary directory for test outputs."""
    test_dir = tmp_path / "test_outputs"
    test_dir.mkdir()
    return test_dir


@pytest.fixture(autouse=True)
def mock_external_dependencies():
    """Mock external dependencies to prevent actual API calls."""
    with patch('psutil.Process') as mock_process:
        mock_process.return_value.memory_info.return_value.rss = 100 * 1024 * 1024  # 100MB
        mock_process.return_value.cpu_percent.return_value = 25.0
        
        with patch('psutil.virtual_memory') as mock_memory:
            mock_memory.return_value.total = 8 * 1024 * 1024 * 1024  # 8GB
            mock_memory.return_value.used = 4 * 1024 * 1024 * 1024   # 4GB
            mock_memory.return_value.percent = 50.0
            
            yield


# Test markers
def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests"
    )
    config.addinivalue_line(
        "markers", "unit: marks tests as unit tests"
    )
    config.addinivalue_line(
        "markers", "gui: marks tests as GUI tests"
    )


# Custom test collection
def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers based on test names."""
    for item in items:
        # Add gui marker to all tests in this directory
        if "gui" in str(item.fspath):
            item.add_marker(pytest.mark.gui)
            
        # Add slow marker to integration tests
        if "integration" in item.name or "TestIntegration" in str(item.cls):
            item.add_marker(pytest.mark.slow)
            item.add_marker(pytest.mark.integration)
        else:
            item.add_marker(pytest.mark.unit)


# Test environment setup
@pytest.fixture(autouse=True)
def setup_test_environment():
    """Setup test environment."""
    # Set test environment variables
    os.environ['PYTEST_RUNNING'] = 'true'
    os.environ['QT_QPA_PLATFORM'] = 'offscreen'  # For headless testing
    
    yield
    
    # Cleanup
    if 'PYTEST_RUNNING' in os.environ:
        del os.environ['PYTEST_RUNNING']


# Exception handling for Qt tests
@pytest.fixture(autouse=True)
def handle_qt_exceptions():
    """Handle Qt exceptions during testing."""
    original_excepthook = sys.excepthook
    
    def test_excepthook(exc_type, exc_value, exc_traceback):
        """Custom exception hook for tests."""
        if exc_type == SystemExit:
            # Allow SystemExit to propagate
            sys.exit(exc_value.code if hasattr(exc_value, 'code') else 0)
        else:
            # Log other exceptions
            original_excepthook(exc_type, exc_value, exc_traceback)
    
    sys.excepthook = test_excepthook
    yield
    sys.excepthook = original_excepthook