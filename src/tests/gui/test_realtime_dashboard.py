#!/usr/bin/env python3
"""
Real-time Dashboard Tests - Microsoft 365 Management Tools
pytest-qt Tests for Real-time Dashboard and WebSocket Integration

Test Coverage:
- Dashboard widget initialization and layout
- WebSocket connection and message handling
- Metrics updates and visualization
- Progress tracking and function monitoring
- Log viewer functionality
- Performance and concurrent operation testing

Author: Frontend Developer (dev0)
Version: 3.1.0
Date: 2025-07-19
"""

import sys
import pytest
import asyncio
import json
import time
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from typing import Dict, List, Any

try:
    from PyQt6.QtWidgets import QApplication, QWidget, QVBoxLayout, QLabel
    from PyQt6.QtCore import Qt, QTimer, pyqtSignal
    from PyQt6.QtTest import QTest
    from PyQt6.QtChart import QChart, QChartView
    import pytest_qt
except ImportError as e:
    print(f"❌ PyQt6 or pytest-qt not available: {e}")
    sys.exit(1)

# Import components to test
sys.path.append('/mnt/e/MicrosoftProductManagementTools/src')
try:
    from gui.components.realtime_dashboard import (
        RealTimeDashboard, DashboardMetric, MetricCard,
        LogEntry, ProgressWidget, MetricStatus
    )
except ImportError as e:
    print(f"❌ Real-time Dashboard not available: {e}")
    pytest.skip("Real-time Dashboard not available", allow_module_level=True)


class TestDashboardMetric:
    """Dashboard Metric Data Class Tests"""
    
    def test_metric_creation(self):
        """Test dashboard metric creation"""
        metric = DashboardMetric(
            name="Active Users",
            value=1250,
            unit="users",
            change="+5.2%",
            status=MetricStatus.GOOD,
            description="Currently active users in the system"
        )
        
        assert metric.name == "Active Users"
        assert metric.value == 1250
        assert metric.unit == "users"
        assert metric.change == "+5.2%"
        assert metric.status == MetricStatus.GOOD
        assert metric.description == "Currently active users in the system"
    
    def test_metric_defaults(self):
        """Test metric default values"""
        metric = DashboardMetric(
            name="Test Metric",
            value=100
        )
        
        assert metric.unit == ""
        assert metric.change == ""
        assert metric.status == MetricStatus.NEUTRAL
        assert metric.description == ""
        assert metric.timestamp is not None
    
    def test_metric_status_interpretation(self):
        """Test metric status values"""
        statuses = [
            MetricStatus.EXCELLENT,
            MetricStatus.GOOD,
            MetricStatus.WARNING,
            MetricStatus.CRITICAL,
            MetricStatus.NEUTRAL
        ]
        
        for status in statuses:
            metric = DashboardMetric(
                name="Test",
                value=100,
                status=status
            )
            assert metric.status == status


class TestLogEntry:
    """Log Entry Data Class Tests"""
    
    def test_log_entry_creation(self):
        """Test log entry creation"""
        log_entry = LogEntry(
            timestamp="2025-07-19 10:30:00",
            level="INFO",
            source="EntraID",
            message="User authentication successful",
            details={"user_id": "test@company.com", "ip": "192.168.1.100"}
        )
        
        assert log_entry.timestamp == "2025-07-19 10:30:00"
        assert log_entry.level == "INFO"
        assert log_entry.source == "EntraID"
        assert log_entry.message == "User authentication successful"
        assert log_entry.details["user_id"] == "test@company.com"
    
    def test_log_entry_defaults(self):
        """Test log entry default values"""
        log_entry = LogEntry(
            timestamp="2025-07-19 10:30:00",
            level="INFO",
            source="Test",
            message="Test message"
        )
        
        assert log_entry.details == {}


class TestMetricCard:
    """Metric Card Widget Tests"""
    
    @pytest.fixture
    def app(self, qtbot):
        """PyQt Application fixture"""
        return QApplication.instance() or QApplication([])
    
    @pytest.fixture
    def test_metric(self):
        """Test metric fixture"""
        return DashboardMetric(
            name="Total Users",
            value=1500,
            unit="users",
            change="+10%",
            status=MetricStatus.EXCELLENT,
            description="Total registered users"
        )
    
    @pytest.fixture
    def metric_card(self, qtbot, test_metric):
        """Metric card fixture"""
        card = MetricCard(test_metric)
        qtbot.addWidget(card)
        return card
    
    def test_metric_card_initialization(self, qtbot, metric_card, test_metric):
        """Test metric card initialization"""
        assert metric_card.metric == test_metric
        assert metric_card.name_label.text() == test_metric.name
        assert metric_card.value_label.text() == f"{test_metric.value} {test_metric.unit}"
        assert metric_card.change_label.text() == test_metric.change
    
    def test_metric_card_update(self, qtbot, metric_card):
        """Test metric card update"""
        new_metric = DashboardMetric(
            name="Updated Users",
            value=2000,
            unit="users",
            change="+25%",
            status=MetricStatus.GOOD
        )
        
        metric_card.update_metric(new_metric)
        
        assert metric_card.metric == new_metric
        assert metric_card.name_label.text() == "Updated Users"
        assert metric_card.value_label.text() == "2000 users"
        assert metric_card.change_label.text() == "+25%"
    
    def test_metric_card_styling(self, qtbot, metric_card):
        """Test metric card styling based on status"""
        # Test different statuses
        statuses = [
            MetricStatus.EXCELLENT,
            MetricStatus.GOOD,
            MetricStatus.WARNING,
            MetricStatus.CRITICAL
        ]
        
        for status in statuses:
            metric = DashboardMetric(
                name="Test",
                value=100,
                status=status
            )
            metric_card.update_metric(metric)
            
            # Should have appropriate styling
            assert metric_card.styleSheet() != ""


class TestProgressWidget:
    """Progress Widget Tests"""
    
    @pytest.fixture
    def app(self, qtbot):
        """PyQt Application fixture"""
        return QApplication.instance() or QApplication([])
    
    @pytest.fixture
    def progress_widget(self, qtbot):
        """Progress widget fixture"""
        widget = ProgressWidget("test_function", "Test Function")
        qtbot.addWidget(widget)
        return widget
    
    def test_progress_widget_initialization(self, qtbot, progress_widget):
        """Test progress widget initialization"""
        assert progress_widget.function_id == "test_function"
        assert progress_widget.function_name == "Test Function"
        assert progress_widget.progress_bar.value() == 0
        assert progress_widget.status_label.text() == "待機中"
    
    def test_progress_updates(self, qtbot, progress_widget):
        """Test progress updates"""
        # Test progress update
        progress_widget.update_progress(45, "データ処理中...")
        
        assert progress_widget.progress_bar.value() == 45
        assert progress_widget.status_label.text() == "データ処理中..."
    
    def test_progress_completion(self, qtbot, progress_widget):
        """Test progress completion"""
        # Set to completion
        progress_widget.update_progress(100, "完了")
        
        assert progress_widget.progress_bar.value() == 100
        assert progress_widget.status_label.text() == "完了"
    
    def test_progress_reset(self, qtbot, progress_widget):
        """Test progress reset"""
        # Set some progress
        progress_widget.update_progress(75, "進行中")
        
        # Reset
        progress_widget.reset_progress()
        
        assert progress_widget.progress_bar.value() == 0
        assert progress_widget.status_label.text() == "待機中"


class TestRealTimeDashboard:
    """Real-time Dashboard Tests"""
    
    @pytest.fixture
    def app(self, qtbot):
        """PyQt Application fixture"""
        return QApplication.instance() or QApplication([])
    
    @pytest.fixture
    def mock_websocket(self):
        """Mock WebSocket client"""
        with patch('gui.components.realtime_dashboard.QWebSocketClient') as mock_ws:
            mock_ws_instance = Mock()
            mock_ws_instance.connected = Mock()
            mock_ws_instance.disconnected = Mock()
            mock_ws_instance.error = Mock()
            mock_ws_instance.textMessageReceived = Mock()
            mock_ws.return_value = mock_ws_instance
            yield mock_ws_instance
    
    @pytest.fixture
    def dashboard(self, qtbot, mock_websocket):
        """Dashboard fixture"""
        dashboard = RealTimeDashboard("ws://test:8000/ws")
        qtbot.addWidget(dashboard)
        return dashboard
    
    def test_dashboard_initialization(self, qtbot, dashboard):
        """Test dashboard initialization"""
        assert dashboard.websocket_url == "ws://test:8000/ws"
        assert hasattr(dashboard, 'metrics_cards')
        assert hasattr(dashboard, 'charts')
        assert hasattr(dashboard, 'progress_widgets')
        assert hasattr(dashboard, 'log_viewer')
        
        # Check initial state
        assert len(dashboard.current_metrics) == 0
        assert len(dashboard.function_progress) == 0
        assert len(dashboard.recent_logs) == 0
    
    def test_metric_updates(self, qtbot, dashboard):
        """Test metric update functionality"""
        test_metric = DashboardMetric(
            name="Active Sessions",
            value=850,
            unit="sessions",
            change="+3.5%",
            status=MetricStatus.GOOD
        )
        
        # Update metric
        dashboard.update_metric("active_sessions", test_metric)
        
        # Verify metric was stored
        assert "active_sessions" in dashboard.current_metrics
        assert dashboard.current_metrics["active_sessions"] == test_metric
        
        # Verify UI was updated (metric card should exist)
        assert "active_sessions" in dashboard.metrics_cards
        assert isinstance(dashboard.metrics_cards["active_sessions"], MetricCard)
    
    def test_multiple_metric_updates(self, qtbot, dashboard):
        """Test multiple metric updates"""
        metrics = {
            "total_users": DashboardMetric("Total Users", 1200, "users", "+5%", MetricStatus.EXCELLENT),
            "active_licenses": DashboardMetric("Active Licenses", 950, "licenses", "+2%", MetricStatus.GOOD),
            "storage_used": DashboardMetric("Storage Used", 75, "%", "+1%", MetricStatus.WARNING),
            "security_alerts": DashboardMetric("Security Alerts", 3, "alerts", "-2", MetricStatus.CRITICAL),
        }
        
        # Update all metrics
        for metric_id, metric in metrics.items():
            dashboard.update_metric(metric_id, metric)
        
        # Verify all metrics were stored and cards created
        assert len(dashboard.current_metrics) == 4
        assert len(dashboard.metrics_cards) == 4
        
        for metric_id in metrics.keys():
            assert metric_id in dashboard.current_metrics
            assert metric_id in dashboard.metrics_cards
    
    def test_function_progress_tracking(self, qtbot, dashboard):
        """Test function progress tracking"""
        function_id = "daily_report"
        function_name = "Daily Report Generation"
        
        # Update progress
        dashboard.update_function_progress(function_id, 25, "データ収集中...", function_name)
        
        # Verify progress was stored
        assert function_id in dashboard.function_progress
        progress_data = dashboard.function_progress[function_id]
        assert progress_data["progress"] == 25
        assert progress_data["status"] == "データ収集中..."
        assert progress_data["function_name"] == function_name
        
        # Verify progress widget was created
        assert function_id in dashboard.progress_widgets
        widget = dashboard.progress_widgets[function_id]
        assert isinstance(widget, ProgressWidget)
        assert widget.progress_bar.value() == 25
    
    def test_multiple_function_progress(self, qtbot, dashboard):
        """Test tracking multiple function progress"""
        functions = [
            ("daily_report", "Daily Report", 25, "データ収集中"),
            ("user_analysis", "User Analysis", 50, "分析実行中"),
            ("license_check", "License Check", 75, "ライセンス確認中"),
            ("security_scan", "Security Scan", 100, "完了")
        ]
        
        # Update all function progress
        for func_id, func_name, progress, status in functions:
            dashboard.update_function_progress(func_id, progress, status, func_name)
        
        # Verify all functions are tracked
        assert len(dashboard.function_progress) == 4
        assert len(dashboard.progress_widgets) == 4
        
        # Verify specific progress values
        for func_id, _, progress, status in functions:
            assert dashboard.function_progress[func_id]["progress"] == progress
            assert dashboard.function_progress[func_id]["status"] == status
            assert dashboard.progress_widgets[func_id].progress_bar.value() == progress
    
    def test_log_entry_handling(self, qtbot, dashboard):
        """Test log entry handling"""
        log_entries = [
            LogEntry("2025-07-19 10:30:00", "INFO", "EntraID", "User login successful"),
            LogEntry("2025-07-19 10:31:00", "WARNING", "Exchange", "Mailbox quota exceeded"),
            LogEntry("2025-07-19 10:32:00", "ERROR", "Teams", "Meeting creation failed"),
            LogEntry("2025-07-19 10:33:00", "SUCCESS", "OneDrive", "Sync completed")
        ]
        
        # Add log entries
        for log_entry in log_entries:
            dashboard.add_log_entry(
                log_entry.timestamp,
                log_entry.level,
                log_entry.source,
                log_entry.message,
                log_entry.details
            )
        
        # Verify logs were stored
        assert len(dashboard.recent_logs) == 4
        
        # Verify log order (should be newest first)
        assert dashboard.recent_logs[0].message == "Sync completed"
        assert dashboard.recent_logs[-1].message == "User login successful"
    
    def test_log_entry_limit(self, qtbot, dashboard):
        """Test log entry limit (should keep only recent entries)"""
        # Add many log entries
        for i in range(150):  # More than typical limit
            dashboard.add_log_entry(
                f"2025-07-19 10:{i:02d}:00",
                "INFO",
                "Test",
                f"Test message {i}"
            )
        
        # Should not exceed reasonable limit
        assert len(dashboard.recent_logs) <= 100  # Assuming 100 is the limit
        
        # Should keep most recent entries
        assert dashboard.recent_logs[0].message == "Test message 149"
    
    @pytest.mark.asyncio
    async def test_websocket_connection(self, qtbot, dashboard, mock_websocket):
        """Test WebSocket connection functionality"""
        # Test connection attempt
        await dashboard.connect_websocket()
        
        # Should have attempted to connect
        assert dashboard.websocket_client is not None
        
        # Test connection handling
        dashboard.on_websocket_connected()
        assert dashboard.connection_status == "connected"
        
        # Test disconnection
        dashboard.on_websocket_disconnected()
        assert dashboard.connection_status == "disconnected"
    
    @pytest.mark.asyncio
    async def test_websocket_message_handling(self, qtbot, dashboard, mock_websocket):
        """Test WebSocket message handling"""
        # Test metric update message
        metric_message = json.dumps({
            "type": "metric_update",
            "data": {
                "metric_id": "cpu_usage",
                "name": "CPU Usage",
                "value": 65.5,
                "unit": "%",
                "change": "+2%",
                "status": "warning"
            }
        })
        
        dashboard.handle_websocket_message(metric_message)
        
        # Should have updated metric
        assert "cpu_usage" in dashboard.current_metrics
        
        # Test progress update message
        progress_message = json.dumps({
            "type": "progress_update",
            "data": {
                "function_id": "weekly_report",
                "function_name": "Weekly Report",
                "progress": 40,
                "status": "Generating charts..."
            }
        })
        
        dashboard.handle_websocket_message(progress_message)
        
        # Should have updated progress
        assert "weekly_report" in dashboard.function_progress
        assert dashboard.function_progress["weekly_report"]["progress"] == 40
    
    def test_chart_integration(self, qtbot, dashboard):
        """Test chart integration functionality"""
        # Charts should be initialized
        assert hasattr(dashboard, 'charts')
        
        # Test adding chart data
        chart_data = {
            "labels": ["Jan", "Feb", "Mar", "Apr", "May"],
            "values": [100, 120, 130, 110, 140]
        }
        
        dashboard.update_chart("user_growth", chart_data)
        
        # Should have stored chart data
        assert "user_growth" in dashboard.chart_data
        assert dashboard.chart_data["user_growth"] == chart_data


class TestWebSocketIntegration:
    """WebSocket Integration Tests"""
    
    @pytest.fixture
    def app(self, qtbot):
        """PyQt Application fixture"""
        return QApplication.instance() or QApplication([])
    
    @pytest.fixture
    def dashboard(self, qtbot):
        """Dashboard fixture with real WebSocket mock"""
        with patch('gui.components.realtime_dashboard.QWebSocketClient') as mock_ws_class:
            dashboard = RealTimeDashboard("ws://test:8000/ws")
            qtbot.addWidget(dashboard)
            yield dashboard
    
    def test_message_parsing(self, qtbot, dashboard):
        """Test WebSocket message parsing"""
        # Test valid messages
        valid_messages = [
            '{"type": "metric_update", "data": {"metric_id": "test", "name": "Test", "value": 100}}',
            '{"type": "progress_update", "data": {"function_id": "test", "progress": 50}}',
            '{"type": "log_entry", "data": {"timestamp": "2025-07-19", "level": "INFO", "message": "Test"}}',
            '{"type": "system_status", "data": {"status": "healthy"}}'
        ]
        
        for message in valid_messages:
            # Should not raise exception
            dashboard.handle_websocket_message(message)
    
    def test_invalid_message_handling(self, qtbot, dashboard):
        """Test handling of invalid WebSocket messages"""
        invalid_messages = [
            "invalid json",
            '{"type": "unknown_type"}',
            '{"missing": "type"}',
            "",
            None
        ]
        
        for message in invalid_messages:
            # Should handle gracefully without crashing
            try:
                dashboard.handle_websocket_message(message)
            except Exception as e:
                pytest.fail(f"Dashboard crashed on invalid message: {e}")
    
    @pytest.mark.asyncio
    async def test_connection_error_handling(self, qtbot, dashboard):
        """Test WebSocket connection error handling"""
        # Simulate connection error
        dashboard.on_websocket_error("Connection refused")
        
        # Should handle error gracefully
        assert dashboard.connection_status == "error"
        assert dashboard.last_error == "Connection refused"
    
    @pytest.mark.asyncio
    async def test_reconnection_logic(self, qtbot, dashboard):
        """Test automatic reconnection logic"""
        # Simulate disconnection
        dashboard.on_websocket_disconnected()
        assert dashboard.connection_status == "disconnected"
        
        # Should attempt reconnection
        # (Implementation-dependent - would need to check reconnection timer)
        assert hasattr(dashboard, 'reconnect_timer')


class TestPerformanceAndStress:
    """Performance and Stress Tests"""
    
    @pytest.fixture
    def dashboard(self, qtbot):
        """Dashboard fixture"""
        with patch('gui.components.realtime_dashboard.QWebSocketClient'):
            dashboard = RealTimeDashboard("ws://test:8000/ws")
            qtbot.addWidget(dashboard)
            return dashboard
    
    def test_rapid_metric_updates(self, qtbot, dashboard):
        """Test rapid metric updates performance"""
        start_time = time.time()
        
        # Perform rapid updates
        for i in range(100):
            metric = DashboardMetric(
                name=f"Metric {i}",
                value=i * 10,
                status=MetricStatus.GOOD
            )
            dashboard.update_metric(f"metric_{i}", metric)
            
            if i % 10 == 0:  # Minimal UI processing
                qtbot.wait(1)
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Should handle rapid updates efficiently
        assert duration < 3.0, f"Rapid metric updates took too long: {duration}s"
    
    def test_massive_log_entries(self, qtbot, dashboard):
        """Test handling of massive log entries"""
        start_time = time.time()
        
        # Add many log entries
        for i in range(500):
            dashboard.add_log_entry(
                f"2025-07-19 10:{i%60:02d}:{i%60:02d}",
                "INFO",
                f"Source{i%5}",
                f"Log message {i}"
            )
            
            if i % 50 == 0:  # Minimal UI processing
                qtbot.wait(1)
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Should handle massive logs efficiently
        assert duration < 5.0, f"Massive log handling took too long: {duration}s"
        
        # Should maintain reasonable memory usage
        assert len(dashboard.recent_logs) <= 100  # Should limit stored logs
    
    def test_concurrent_updates(self, qtbot, dashboard):
        """Test concurrent metric and progress updates"""
        start_time = time.time()
        
        # Simulate concurrent updates
        for cycle in range(50):
            # Update metrics
            for i in range(5):
                metric = DashboardMetric(f"Metric {i}", cycle * i, status=MetricStatus.GOOD)
                dashboard.update_metric(f"metric_{i}", metric)
            
            # Update progress
            for i in range(5):
                dashboard.update_function_progress(
                    f"function_{i}",
                    (cycle * 2) % 100,
                    f"Progress {cycle}",
                    f"Function {i}"
                )
            
            # Add log entries
            dashboard.add_log_entry(
                f"2025-07-19 10:30:{cycle:02d}",
                "INFO",
                "Test",
                f"Cycle {cycle}"
            )
            
            if cycle % 10 == 0:
                qtbot.wait(1)
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Should handle concurrent updates efficiently
        assert duration < 10.0, f"Concurrent updates took too long: {duration}s"


if __name__ == "__main__":
    # Run tests
    pytest.main([
        __file__,
        "-v",
        "--tb=short",
        "--maxfail=5",
        "-x"  # Stop on first failure for debugging
    ])