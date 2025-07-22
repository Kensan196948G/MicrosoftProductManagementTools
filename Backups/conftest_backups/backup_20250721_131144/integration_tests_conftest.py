"""
pytest configuration for integration tests.
"""

import pytest
import asyncio
import sys
import os
from unittest.mock import Mock, patch
from PyQt6.QtWidgets import QApplication, QWidget
from PyQt6.QtCore import Qt

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
def qapp():
    """Create QApplication for testing."""
    if not QApplication.instance():
        app = QApplication([])
        app.setAttribute(Qt.ApplicationAttribute.AA_DisableWindowContextHelpButton)
        yield app
        app.quit()
    else:
        yield QApplication.instance()


@pytest.fixture
def mock_main_window(qapp):
    """Create mock main window for testing."""
    window = Mock(spec=QWidget)
    
    # Mock function tabs
    window.function_tabs = Mock()
    window.function_tabs.count.return_value = 6
    
    # Mock widgets for each tab
    mock_widgets = []
    for i in range(6):
        widget = Mock()
        widget.findChildren.return_value = [Mock() for _ in range(5)]  # Mock buttons
        mock_widgets.append(widget)
    
    window.function_tabs.widget.side_effect = lambda i: mock_widgets[i] if i < len(mock_widgets) else Mock()
    
    # Mock other components
    window.log_viewer = Mock()
    window.status_bar = Mock()
    window.graph_client = Mock()
    window.performance_monitor = Mock()
    window.accessibility_helper = Mock()
    
    return window


@pytest.fixture
def mock_integration_task():
    """Create mock integration task."""
    from src.gui.integration.integration_interface import IntegrationTask, IntegrationStatus, ComponentType
    
    return IntegrationTask(
        id="test_task_001",
        name="test_task",
        component_type=ComponentType.FRONTEND,
        priority="high",
        status=IntegrationStatus.PENDING,
        dependencies=[]
    )


@pytest.fixture
def mock_test_case():
    """Create mock test case."""
    from src.gui.integration.qa_integration import TestCase, TestType, TestSeverity
    
    return TestCase(
        id="test_case_001",
        name="Test Case 1",
        type=TestType.UNIT_TEST,
        severity=TestSeverity.HIGH,
        description="Test case description",
        expected_result="Expected result"
    )


@pytest.fixture
def mock_test_suite():
    """Create mock test suite."""
    from src.gui.integration.qa_integration import TestSuite, TestCase, TestType, TestSeverity
    
    test_cases = [
        TestCase(
            id="test_001",
            name="Test 1",
            type=TestType.UNIT_TEST,
            severity=TestSeverity.HIGH,
            description="Test description 1",
            expected_result="Expected result 1"
        ),
        TestCase(
            id="test_002",
            name="Test 2",
            type=TestType.INTEGRATION_TEST,
            severity=TestSeverity.MEDIUM,
            description="Test description 2",
            expected_result="Expected result 2"
        )
    ]
    
    return TestSuite(
        id="test_suite_001",
        name="Test Suite 1",
        test_cases=test_cases,
        parallel_execution=True
    )


@pytest.fixture
def mock_backend_response():
    """Create mock backend response."""
    from src.gui.integration.backend_integration import BackendResponse
    
    return BackendResponse(
        status_code=200,
        data={"test": "data"},
        headers={"Content-Type": "application/json"},
        execution_time=0.1
    )


@pytest.fixture
def mock_integration_plan():
    """Create mock integration plan."""
    from src.gui.integration.system_integration import IntegrationPlan, IntegrationPhase, IntegrationPriority
    from src.gui.integration.integration_interface import ComponentType, IntegrationStatus
    
    return IntegrationPlan(
        id="test_plan_001",
        name="Test Plan 1",
        phase=IntegrationPhase.PREPARATION,
        priority=IntegrationPriority.HIGH,
        components=[ComponentType.FRONTEND],
        dependencies=[],
        estimated_time=30.0,
        status=IntegrationStatus.PENDING
    )


@pytest.fixture
def mock_system_metrics():
    """Create mock system metrics."""
    from src.gui.integration.system_integration import SystemMetrics
    
    return SystemMetrics(
        total_components=6,
        integrated_components=4,
        pending_integrations=2,
        failed_integrations=0,
        overall_health=75.0,
        performance_score=85.0,
        quality_score=90.0,
        security_score=88.0,
        accessibility_score=92.0,
        integration_completion=75.0
    )


@pytest.fixture(autouse=True)
def mock_external_dependencies():
    """Mock external dependencies for testing."""
    with patch('asyncio.sleep') as mock_sleep:
        mock_sleep.return_value = None
        
        with patch('time.time') as mock_time:
            mock_time.return_value = 1234567890.0
            
            with patch('logging.getLogger') as mock_logger:
                mock_logger.return_value.info.return_value = None
                mock_logger.return_value.error.return_value = None
                mock_logger.return_value.warning.return_value = None
                
                yield


@pytest.fixture
def integration_test_data():
    """Create test data for integration tests."""
    return {
        "users": [
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
        ],
        "licenses": [
            {
                "skuId": "sku1",
                "skuPartNumber": "ENTERPRISEPACK",
                "consumedUnits": 50,
                "prepaidUnits": {"enabled": 100}
            }
        ],
        "reports": [
            {
                "id": "report1",
                "name": "Daily Report",
                "data": [
                    {"date": "2025-01-18", "users": 150, "active": 120},
                    {"date": "2025-01-17", "users": 148, "active": 118}
                ]
            }
        ]
    }


# Test markers
def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests"
    )
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )
    config.addinivalue_line(
        "markers", "async_test: marks tests as async tests"
    )
    config.addinivalue_line(
        "markers", "frontend: marks tests as frontend integration tests"
    )
    config.addinivalue_line(
        "markers", "backend: marks tests as backend integration tests"
    )
    config.addinivalue_line(
        "markers", "qa: marks tests as QA integration tests"
    )
    config.addinivalue_line(
        "markers", "system: marks tests as system integration tests"
    )


# Custom test collection
def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers."""
    for item in items:
        # Add integration marker to all tests
        item.add_marker(pytest.mark.integration)
        
        # Add async marker to async tests
        if 'async' in item.name or 'asyncio' in str(item.function):
            item.add_marker(pytest.mark.async_test)
        
        # Add component markers based on class name
        if 'Frontend' in str(item.cls):
            item.add_marker(pytest.mark.frontend)
        elif 'Backend' in str(item.cls):
            item.add_marker(pytest.mark.backend)
        elif 'QA' in str(item.cls):
            item.add_marker(pytest.mark.qa)
        elif 'System' in str(item.cls):
            item.add_marker(pytest.mark.system)


# Test environment setup
@pytest.fixture(autouse=True)
def setup_integration_test_environment():
    """Setup integration test environment."""
    # Set test environment variables
    os.environ['INTEGRATION_TEST_MODE'] = 'true'
    os.environ['QT_QPA_PLATFORM'] = 'offscreen'
    
    yield
    
    # Cleanup
    if 'INTEGRATION_TEST_MODE' in os.environ:
        del os.environ['INTEGRATION_TEST_MODE']