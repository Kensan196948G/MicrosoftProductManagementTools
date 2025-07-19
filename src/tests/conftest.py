#!/usr/bin/env python3
"""
pytest configuration for Microsoft 365 Management Tools GUI Testing
Centralized test configuration and fixtures

Features:
- PyQt6 application lifecycle management
- Mock API and WebSocket services
- Test data generators
- Performance monitoring fixtures
- Common test utilities

Author: Frontend Developer (dev0)
Version: 3.1.0
Date: 2025-07-19
"""

import sys
import pytest
import asyncio
import json
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch, AsyncMock
from typing import Dict, List, Any, Generator
import time

try:
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtCore import QTimer
    from PyQt6.QtTest import QTest
    import pytest_qt
except ImportError:
    print("❌ PyQt6 or pytest-qt not available")
    sys.exit(1)

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


@pytest.fixture(scope="session")
def app():
    """Session-scoped PyQt6 application fixture"""
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    yield app
    # Cleanup handled by pytest-qt


@pytest.fixture
def temp_dir():
    """Temporary directory fixture for test files"""
    temp_dir = tempfile.mkdtemp()
    yield Path(temp_dir)
    shutil.rmtree(temp_dir, ignore_errors=True)


@pytest.fixture
def mock_config():
    """Mock configuration for testing"""
    return {
        "websocket_url": "ws://localhost:8000/ws",
        "api_base_url": "https://graph.microsoft.com",
        "tenant_id": "test-tenant-id",
        "client_id": "test-client-id",
        "client_secret": "test-client-secret",
        "log_level": "INFO",
        "max_log_entries": 100,
        "reconnect_interval": 5
    }


@pytest.fixture
def mock_microsoft365_api():
    """Mock Microsoft 365 API client"""
    with patch('gui.main_window_integrated.Microsoft365ApiClient') as mock_api:
        api_instance = mock_api.return_value
        
        # Mock user data
        api_instance.get_user_list.return_value = {
            "status": "success",
            "data": [
                {
                    "id": "user1",
                    "displayName": "Test User 1",
                    "userPrincipalName": "test1@company.com",
                    "assignedLicenses": ["E5"]
                },
                {
                    "id": "user2", 
                    "displayName": "Test User 2",
                    "userPrincipalName": "test2@company.com",
                    "assignedLicenses": ["E3"]
                }
            ]
        }
        
        # Mock license data
        api_instance.get_license_usage.return_value = {
            "status": "success",
            "data": {
                "total_licenses": 1000,
                "assigned_licenses": 850,
                "available_licenses": 150,
                "license_types": {
                    "Microsoft 365 E5": 500,
                    "Microsoft 365 E3": 350
                }
            }
        }
        
        # Mock usage statistics
        api_instance.get_usage_statistics.return_value = {
            "status": "success",
            "data": {
                "active_users_30_days": 780,
                "teams_usage": {
                    "total_meetings": 1250,
                    "total_participants": 5600
                },
                "onedrive_usage": {
                    "total_storage_gb": 15000,
                    "used_storage_gb": 12500
                }
            }
        }
        
        yield api_instance


@pytest.fixture
def mock_websocket_client():
    """Mock WebSocket client for dashboard testing"""
    with patch('gui.components.realtime_dashboard.QWebSocketClient') as mock_ws:
        ws_instance = Mock()
        ws_instance.connected = Mock()
        ws_instance.disconnected = Mock()
        ws_instance.error = Mock()
        ws_instance.textMessageReceived = Mock()
        ws_instance.open = Mock()
        ws_instance.close = Mock()
        ws_instance.sendTextMessage = Mock()
        
        mock_ws.return_value = ws_instance
        yield ws_instance


@pytest.fixture
def sample_metrics():
    """Sample dashboard metrics for testing"""
    return {
        "total_users": {
            "name": "Total Users",
            "value": 1500,
            "unit": "users",
            "change": "+5%",
            "status": "excellent"
        },
        "active_licenses": {
            "name": "Active Licenses",
            "value": 1200,
            "unit": "licenses",
            "change": "+2%",
            "status": "good"
        },
        "storage_usage": {
            "name": "Storage Usage",
            "value": 75,
            "unit": "%",
            "change": "+3%",
            "status": "warning"
        },
        "security_alerts": {
            "name": "Security Alerts",
            "value": 5,
            "unit": "alerts",
            "change": "-2",
            "status": "critical"
        }
    }


@pytest.fixture
def sample_log_entries():
    """Sample log entries for testing"""
    return [
        {
            "timestamp": "2025-07-19 10:30:00",
            "level": "INFO",
            "source": "EntraID",
            "message": "User authentication successful",
            "details": {"user": "test1@company.com"}
        },
        {
            "timestamp": "2025-07-19 10:31:00",
            "level": "WARNING",
            "source": "Exchange",
            "message": "Mailbox quota exceeded",
            "details": {"mailbox": "test2@company.com", "usage": "95%"}
        },
        {
            "timestamp": "2025-07-19 10:32:00",
            "level": "ERROR",
            "source": "Teams",
            "message": "Meeting creation failed",
            "details": {"error": "Insufficient permissions"}
        },
        {
            "timestamp": "2025-07-19 10:33:00",
            "level": "SUCCESS",
            "source": "OneDrive",
            "message": "Sync completed successfully",
            "details": {"files_synced": 150}
        }
    ]


@pytest.fixture
def sample_function_progress():
    """Sample function progress data for testing"""
    return {
        "daily_report": {
            "function_name": "Daily Report Generation",
            "progress": 45,
            "status": "Collecting user data...",
            "started_at": "2025-07-19 10:30:00"
        },
        "license_analysis": {
            "function_name": "License Analysis",
            "progress": 75,
            "status": "Analyzing usage patterns...",
            "started_at": "2025-07-19 10:28:00"
        },
        "security_scan": {
            "function_name": "Security Scan",
            "progress": 100,
            "status": "Scan completed",
            "started_at": "2025-07-19 10:25:00"
        }
    }


@pytest.fixture
def performance_monitor():
    """Performance monitoring fixture"""
    class PerformanceMonitor:
        def __init__(self):
            self.start_time = None
            self.measurements = {}
        
        def start(self, operation_name: str = "default"):
            self.start_time = time.time()
            self.operation_name = operation_name
        
        def stop(self, max_duration: float = None):
            if self.start_time is None:
                raise ValueError("Performance monitoring not started")
            
            duration = time.time() - self.start_time
            self.measurements[self.operation_name] = duration
            
            if max_duration and duration > max_duration:
                pytest.fail(f"Operation '{self.operation_name}' took too long: {duration:.2f}s (max: {max_duration}s)")
            
            self.start_time = None
            return duration
        
        def get_measurement(self, operation_name: str = "default"):
            return self.measurements.get(operation_name)
    
    return PerformanceMonitor()


@pytest.fixture
def memory_monitor():
    """Memory monitoring fixture"""
    class MemoryMonitor:
        def __init__(self):
            try:
                import psutil
                import os
                self.process = psutil.Process(os.getpid())
                self.initial_memory = None
                self.psutil_available = True
            except ImportError:
                self.psutil_available = False
        
        def start(self):
            if not self.psutil_available:
                pytest.skip("psutil not available for memory monitoring")
            self.initial_memory = self.process.memory_info().rss
        
        def check(self, max_increase_mb: float = 50):
            if not self.psutil_available or self.initial_memory is None:
                return 0
            
            current_memory = self.process.memory_info().rss
            increase_bytes = current_memory - self.initial_memory
            increase_mb = increase_bytes / (1024 * 1024)
            
            if increase_mb > max_increase_mb:
                pytest.fail(f"Memory usage increased too much: {increase_mb:.2f}MB (max: {max_increase_mb}MB)")
            
            return increase_mb
    
    return MemoryMonitor()


@pytest.fixture
def gui_test_helper():
    """GUI testing helper utilities"""
    class GuiTestHelper:
        @staticmethod
        def wait_for_signal(signal, timeout_ms=5000):
            """Wait for a PyQt signal to be emitted"""
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            signal_received = False
            
            def on_signal(*args):
                nonlocal signal_received
                signal_received = True
            
            signal.connect(on_signal)
            
            # Wait for signal or timeout
            start_time = time.time()
            while not signal_received and (time.time() - start_time) * 1000 < timeout_ms:
                QApplication.processEvents()
                time.sleep(0.01)
            
            signal.disconnect(on_signal)
            return signal_received
        
        @staticmethod
        def find_widget_by_text(parent, text, widget_type=None):
            """Find child widget by text content"""
            for child in parent.findChildren(widget_type or type(parent)):
                if hasattr(child, 'text') and text in child.text():
                    return child
                elif hasattr(child, 'toPlainText') and text in child.toPlainText():
                    return child
            return None
        
        @staticmethod
        def simulate_user_delay(ms=100):
            """Simulate realistic user interaction delay"""
            QTest.qWait(ms)
        
        @staticmethod
        def capture_widget_image(widget, filename=None):
            """Capture widget as image for visual debugging"""
            if filename:
                pixmap = widget.grab()
                pixmap.save(filename)
                return filename
            return widget.grab()
    
    return GuiTestHelper()


@pytest.fixture
def websocket_message_generator():
    """Generate WebSocket messages for testing"""
    class WebSocketMessageGenerator:
        @staticmethod
        def metric_update(metric_id: str, name: str, value: Any, **kwargs):
            return json.dumps({
                "type": "metric_update",
                "data": {
                    "metric_id": metric_id,
                    "name": name,
                    "value": value,
                    **kwargs
                }
            })
        
        @staticmethod
        def progress_update(function_id: str, progress: int, status: str, **kwargs):
            return json.dumps({
                "type": "progress_update",
                "data": {
                    "function_id": function_id,
                    "progress": progress,
                    "status": status,
                    **kwargs
                }
            })
        
        @staticmethod
        def log_entry(level: str, source: str, message: str, **kwargs):
            return json.dumps({
                "type": "log_entry",
                "data": {
                    "timestamp": "2025-07-19 10:30:00",
                    "level": level,
                    "source": source,
                    "message": message,
                    **kwargs
                }
            })
        
        @staticmethod
        def system_status(status: str, **kwargs):
            return json.dumps({
                "type": "system_status",
                "data": {
                    "status": status,
                    **kwargs
                }
            })
    
    return WebSocketMessageGenerator()


# Test markers
def pytest_configure(config):
    """Configure custom pytest markers"""
    config.addinivalue_line(
        "markers",
        "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )
    config.addinivalue_line(
        "markers",
        "integration: marks tests as integration tests"
    )
    config.addinivalue_line(
        "markers",
        "performance: marks tests as performance tests"
    )
    config.addinivalue_line(
        "markers",
        "gui: marks tests as GUI tests"
    )


# Pytest plugins
pytest_plugins = ["pytest_qt"]


# Custom test collection
def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers automatically"""
    for item in items:
        # Mark GUI tests
        if "gui" in str(item.fspath) or "test_gui" in item.name:
            item.add_marker(pytest.mark.gui)
        
        # Mark slow tests
        if "stress" in item.name or "performance" in item.name or "massive" in item.name:
            item.add_marker(pytest.mark.slow)
        
        # Mark integration tests
        if "integration" in item.name or "workflow" in item.name:
            item.add_marker(pytest.mark.integration)


# Session cleanup
@pytest.fixture(scope="session", autouse=True)
def cleanup_session():
    """Session-level cleanup"""
    yield
    # Cleanup any global resources if needed
    print("\n🧹 Cleaning up test session...")