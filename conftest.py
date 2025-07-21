"""
Minimal conftest.py for emergency pytest setup - Microsoft 365 Management Tools
"""
import pytest
import sys
import os
from pathlib import Path

# Add src to path for imports
PROJECT_ROOT = Path(__file__).parent.absolute()
src_path = PROJECT_ROOT / "src"
if src_path.exists():
    sys.path.insert(0, str(src_path))

@pytest.fixture(scope="session")
def setup_and_teardown():
    """Basic setup and teardown fixture"""
    print("\n=== Emergency Test Session Setup ===")
    yield
    print("\n=== Emergency Test Session Teardown ===")

@pytest.fixture(scope="session")
def project_root():
    """Project root path fixture"""
    return PROJECT_ROOT

@pytest.fixture(scope="function") 
def temp_config():
    """Mock configuration for testing"""
    return {
        "tenant_id": "test-tenant-12345",
        "client_id": "test-client-67890",
        "test_mode": True
    }

def pytest_configure(config):
    """Configure pytest with minimal settings"""
    config.addinivalue_line("markers", "unit: unit tests")
    config.addinivalue_line("markers", "integration: integration tests")
    config.addinivalue_line("markers", "security: security tests")
    config.addinivalue_line("markers", "e2e: end-to-end tests")
    config.addinivalue_line("markers", "e2e_suite: e2e test suite")
    config.addinivalue_line("markers", "frontend_backend: frontend backend integration")
    config.addinivalue_line("markers", "dev0_collaboration: dev0 collaboration tests")
    config.addinivalue_line("markers", "performance: performance tests")
    config.addinivalue_line("markers", "gui: GUI tests")
    config.addinivalue_line("markers", "api: API tests")
    config.addinivalue_line("markers", "compatibility: compatibility tests")
    config.addinivalue_line("markers", "slow: slow running tests")