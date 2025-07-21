"""
Tests/conftest.py - Emergency pytest configuration with GUI package handling
"""
import pytest
import sys
import os
from pathlib import Path

# Project root directory
project_root = Path(__file__).parent.parent

# Add src and system paths to Python path
src_path = project_root / "src"
if src_path.exists():
    sys.path.insert(0, str(src_path))
sys.path.insert(0, str(project_root))

# Add system dist-packages for pytest-qt access
sys.path.insert(0, "/usr/local/lib/python3.12/dist-packages")

# Check for required packages with fallback
def check_gui_packages():
    """Check if GUI testing packages are available"""
    try:
        import PyQt6
        # Try both import names for pytest-qt
        try:
            import pytest_qt
        except ImportError:
            import pytestqt as pytest_qt
        return True
    except ImportError as e:
        print(f"⚠️ GUI testing packages unavailable: {e}")
        return False

# Set GUI availability flag
GUI_AVAILABLE = check_gui_packages()

@pytest.fixture(scope="session")
def setup_and_teardown():
    """Basic setup and teardown fixture"""
    print("\n=== Emergency Test Session Setup ===")
    if GUI_AVAILABLE:
        print("✅ GUI testing packages available")
    else:
        print("⚠️ GUI testing limited - packages unavailable")
    
    yield
    
    print("\n=== Emergency Test Session Teardown ===")

@pytest.fixture(scope="session")
def project_root():
    """Project root path fixture"""
    return project_root

@pytest.fixture(scope="function") 
def temp_config():
    """Mock configuration for testing"""
    return {
        "tenant_id": "test-tenant-12345",
        "client_id": "test-client-67890",
        "test_mode": True
    }

@pytest.fixture(scope="function")
def gui_available():
    """GUI availability fixture"""
    return GUI_AVAILABLE

def pytest_configure(config):
    """Configure pytest with comprehensive markers"""
    config.addinivalue_line("markers", "unit: unit tests")
    config.addinivalue_line("markers", "integration: integration tests")
    config.addinivalue_line("markers", "security: security tests")
    config.addinivalue_line("markers", "e2e: end-to-end tests")
    config.addinivalue_line("markers", "e2e_suite: e2e test suite")
    config.addinivalue_line("markers", "frontend_backend: frontend backend integration")
    config.addinivalue_line("markers", "dev0_collaboration: dev0 collaboration tests")
    config.addinivalue_line("markers", "dev1_collaboration: dev1 collaboration tests")
    config.addinivalue_line("markers", "performance: performance tests")
    config.addinivalue_line("markers", "gui: GUI tests")
    config.addinivalue_line("markers", "api: API tests")
    config.addinivalue_line("markers", "compatibility: compatibility tests")
    config.addinivalue_line("markers", "slow: slow running tests")

def pytest_collection_modifyitems(config, items):
    """Skip GUI tests if packages unavailable"""
    if not GUI_AVAILABLE:
        skip_gui = pytest.mark.skip(reason="GUI packages (PyQt6/pytest-qt) not available")
        for item in items:
            if "gui" in item.keywords or "qt" in item.name.lower():
                item.add_marker(skip_gui)