"""
Test cases for GUI components.
Tests log viewer, report buttons, and other GUI components.
"""

import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock
from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QTextEdit, QTabWidget
from PyQt6.QtCore import Qt
from PyQt6.QtTest import QTest

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from src.gui.components.log_viewer import LogViewerWidget
from src.gui.components.report_buttons import ReportButtonsWidget
from src.gui.components.enhanced_status_bar import EnhancedStatusBar
from src.gui.components.accessibility_helper import AccessibilityHelper
from src.gui.components.performance_monitor import PerformanceMonitor


class TestLogViewerWidget:
    """Test cases for LogViewerWidget class."""
    
    @pytest.fixture
    def app(self):
        """Create QApplication instance for testing."""
        if not QApplication.instance():
            app = QApplication([])
        else:
            app = QApplication.instance()
        return app
    
    @pytest.fixture
    def log_viewer(self, app):
        """Create LogViewerWidget instance for testing."""
        return LogViewerWidget()
    
    def test_log_viewer_initialization(self, log_viewer):
        """Test log viewer initialization."""
        assert isinstance(log_viewer, LogViewerWidget)
        assert hasattr(log_viewer, 'tab_widget')
        assert isinstance(log_viewer.tab_widget, QTabWidget)
        
        # Check tab count (should be 3)
        assert log_viewer.tab_widget.count() == 3
        
        # Check tab names
        expected_tabs = ["📋 実行ログ", "❌ エラーログ", "💻 PowerShellプロンプト"]
        for i, expected_name in enumerate(expected_tabs):
            assert log_viewer.tab_widget.tabText(i) == expected_name
    
    def test_log_text_edit_creation(self, log_viewer):
        """Test log text edit creation."""
        # Check if text edits are created
        assert hasattr(log_viewer, 'execution_log')
        assert hasattr(log_viewer, 'error_log')
        assert hasattr(log_viewer, 'prompt_log')
        
        # Check if they are QTextEdit instances
        assert isinstance(log_viewer.execution_log, QTextEdit)
        assert isinstance(log_viewer.error_log, QTextEdit)
        assert isinstance(log_viewer.prompt_log, QTextEdit)
        
        # Check if they are read-only
        assert log_viewer.execution_log.isReadOnly()
        assert log_viewer.error_log.isReadOnly()
        assert log_viewer.prompt_log.isReadOnly()
    
    def test_add_log_message(self, log_viewer):
        """Test adding log messages."""
        # Test INFO message
        log_viewer.add_log("Test info message", "INFO")
        assert "Test info message" in log_viewer.execution_log.toPlainText()
        assert "Test info message" in log_viewer.prompt_log.toPlainText()
        
        # Test ERROR message
        log_viewer.add_log("Test error message", "ERROR")
        assert "Test error message" in log_viewer.error_log.toPlainText()
        assert "Test error message" in log_viewer.prompt_log.toPlainText()
    
    def test_clear_logs(self, log_viewer):
        """Test clearing logs."""
        # Add some messages
        log_viewer.add_log("Test message 1", "INFO")
        log_viewer.add_log("Test message 2", "ERROR")
        
        # Clear logs
        log_viewer.clear_logs()
        
        # Check if logs are cleared
        assert log_viewer.execution_log.toPlainText() == ""
        assert log_viewer.error_log.toPlainText() == ""
        assert log_viewer.prompt_log.toPlainText() == ""
    
    def test_save_logs(self, log_viewer, tmp_path):
        """Test saving logs to file."""
        # Add some messages
        log_viewer.add_log("Test message 1", "INFO")
        log_viewer.add_log("Test message 2", "ERROR")
        
        # Save logs
        log_file = tmp_path / "test_logs.txt"
        log_viewer.save_logs(str(log_file))
        
        # Check if file exists and contains expected content
        assert log_file.exists()
        content = log_file.read_text(encoding='utf-8')
        assert "=== 実行ログ ===" in content
        assert "=== エラーログ ===" in content
        assert "=== プロンプトログ ===" in content
        assert "Test message 1" in content
        assert "Test message 2" in content


class TestReportButtonsWidget:
    """Test cases for ReportButtonsWidget class."""
    
    @pytest.fixture
    def app(self):
        """Create QApplication instance for testing."""
        if not QApplication.instance():
            app = QApplication([])
        else:
            app = QApplication.instance()
        return app
    
    @pytest.fixture
    def report_buttons(self, app):
        """Create ReportButtonsWidget instance for testing."""
        return ReportButtonsWidget()
    
    def test_report_buttons_initialization(self, report_buttons):
        """Test report buttons initialization."""
        assert isinstance(report_buttons, ReportButtonsWidget)
        assert hasattr(report_buttons, 'buttons')
        assert isinstance(report_buttons.buttons, dict)
    
    def test_button_count(self, report_buttons):
        """Test total button count."""
        # Should have 26 buttons total
        assert report_buttons.get_button_count() == 26
    
    def test_button_actions(self, report_buttons):
        """Test button actions."""
        actions = report_buttons.get_button_actions()
        assert len(actions) == 26
        
        # Check some expected actions
        expected_actions = [
            "daily_report", "weekly_report", "monthly_report", "yearly_report",
            "license_analysis", "usage_analysis", "user_list", "mfa_status",
            "mailbox_management", "teams_usage", "storage_analysis"
        ]
        
        for action in expected_actions:
            assert action in actions
    
    def test_button_styling(self, report_buttons):
        """Test button styling."""
        # Get a button to test
        actions = report_buttons.get_button_actions()
        if actions:
            button = report_buttons.buttons[actions[0]]
            
            # Check minimum size
            assert button.minimumSize().width() == 180
            assert button.minimumSize().height() == 45
            
            # Check cursor
            assert button.cursor().shape() == Qt.CursorShape.PointingHandCursor
            
            # Check if button has style sheet
            assert button.styleSheet() != ""
    
    def test_enable_disable_buttons(self, report_buttons):
        """Test enabling/disabling buttons."""
        # Test disabling all buttons
        report_buttons.set_all_buttons_enabled(False)
        for button in report_buttons.buttons.values():
            assert not button.isEnabled()
        
        # Test enabling all buttons
        report_buttons.set_all_buttons_enabled(True)
        for button in report_buttons.buttons.values():
            assert button.isEnabled()
        
        # Test disabling specific button
        actions = report_buttons.get_button_actions()
        if actions:
            action = actions[0]
            report_buttons.set_button_enabled(action, False)
            assert not report_buttons.buttons[action].isEnabled()
    
    def test_button_click_signal(self, report_buttons):
        """Test button click signal emission."""
        # Mock signal reception
        received_actions = []
        
        def on_function_clicked(action):
            received_actions.append(action)
        
        report_buttons.function_clicked.connect(on_function_clicked)
        
        # Click a button
        actions = report_buttons.get_button_actions()
        if actions:
            button = report_buttons.buttons[actions[0]]
            button.click()
            
            # Check if signal was emitted
            assert len(received_actions) == 1
            assert received_actions[0] == actions[0]


class TestEnhancedStatusBar:
    """Test cases for EnhancedStatusBar class."""
    
    @pytest.fixture
    def app(self):
        """Create QApplication instance for testing."""
        if not QApplication.instance():
            app = QApplication([])
        else:
            app = QApplication.instance()
        return app
    
    @pytest.fixture
    def status_bar(self, app):
        """Create EnhancedStatusBar instance for testing."""
        return EnhancedStatusBar()
    
    def test_status_bar_initialization(self, status_bar):
        """Test status bar initialization."""
        assert isinstance(status_bar, EnhancedStatusBar)
        assert hasattr(status_bar, 'status_label')
        assert hasattr(status_bar, 'progress_bar')
        assert hasattr(status_bar, 'connection_label')
        assert hasattr(status_bar, 'clock_label')
        assert hasattr(status_bar, 'system_label')
        
        # Check initial values
        assert status_bar.status_label.text() == "準備完了"
        assert not status_bar.progress_bar.isVisible()
        assert "未接続" in status_bar.connection_label.text()
    
    def test_set_status(self, status_bar):
        """Test setting status message."""
        status_bar.set_status("Test status message")
        assert status_bar.status_label.text() == "Test status message"
    
    def test_connection_status(self, status_bar):
        """Test connection status updates."""
        # Test connected status
        status_bar.set_connection_status(True, "Graph API")
        assert status_bar.is_connected == True
        assert "接続済み" in status_bar.connection_label.text()
        assert "Graph API" in status_bar.connection_label.text()
        
        # Test disconnected status
        status_bar.set_connection_status(False)
        assert status_bar.is_connected == False
        assert "未接続" in status_bar.connection_label.text()
    
    def test_progress_bar(self, status_bar):
        """Test progress bar functionality."""
        # Test showing progress
        status_bar.show_progress(50, "Processing...")
        assert status_bar.progress_bar.isVisible()
        assert status_bar.progress_bar.value() == 50
        assert status_bar.status_label.text() == "Processing..."
        
        # Test hiding progress
        status_bar.hide_progress()
        assert not status_bar.progress_bar.isVisible()
        assert status_bar.progress_bar.value() == 0
    
    def test_operation_status(self, status_bar):
        """Test operation status updates."""
        status_bar.set_operation_status("Data Export", "準備中")
        assert status_bar.current_operation == "Data Export"
        assert "Data Export - 準備中" in status_bar.status_label.text()
        
        # Test operation completion
        status_bar.complete_operation("Data Export", True)
        assert status_bar.current_operation == ""
        assert "完了" in status_bar.status_label.text()
    
    def test_function_count(self, status_bar):
        """Test function count display."""
        status_bar.set_function_count(26, 20)
        assert "20/26" in status_bar.system_label.text()
        assert "利用可能" in status_bar.system_label.text()
    
    def test_api_status(self, status_bar):
        """Test API status display."""
        status_bar.show_api_status("Graph API", "正常")
        assert "Graph API: 正常" in status_bar.system_label.text()
        
        # Test reset
        status_bar.reset_api_status()
        assert "Python GUI v2.0" in status_bar.system_label.text()


class TestAccessibilityHelper:
    """Test cases for AccessibilityHelper class."""
    
    @pytest.fixture
    def app(self):
        """Create QApplication instance for testing."""
        if not QApplication.instance():
            app = QApplication([])
        else:
            app = QApplication.instance()
        return app
    
    @pytest.fixture
    def parent_widget(self, app):
        """Create parent widget for testing."""
        return QWidget()
    
    @pytest.fixture
    def accessibility_helper(self, parent_widget):
        """Create AccessibilityHelper instance for testing."""
        return AccessibilityHelper(parent_widget)
    
    def test_accessibility_helper_initialization(self, accessibility_helper):
        """Test accessibility helper initialization."""
        assert isinstance(accessibility_helper, AccessibilityHelper)
        assert hasattr(accessibility_helper, 'parent_widget')
        assert hasattr(accessibility_helper, 'focus_chain')
        assert hasattr(accessibility_helper, 'high_contrast_mode')
        assert hasattr(accessibility_helper, 'large_text_mode')
    
    def test_high_contrast_mode(self, accessibility_helper):
        """Test high contrast mode."""
        # Test enabling high contrast
        accessibility_helper.enable_high_contrast_mode(True)
        assert accessibility_helper.high_contrast_mode == True
        
        # Test disabling high contrast
        accessibility_helper.enable_high_contrast_mode(False)
        assert accessibility_helper.high_contrast_mode == False
    
    def test_large_text_mode(self, accessibility_helper):
        """Test large text mode."""
        # Test enabling large text
        accessibility_helper.enable_large_text_mode(True)
        assert accessibility_helper.large_text_mode == True
        
        # Test disabling large text
        accessibility_helper.enable_large_text_mode(False)
        assert accessibility_helper.large_text_mode == False
    
    def test_widget_aria_labels(self, accessibility_helper, parent_widget):
        """Test adding ARIA labels to widgets."""
        widget = QWidget(parent_widget)
        
        # Test adding ARIA label
        accessibility_helper.add_widget_aria_label(widget, "Test Label")
        assert widget.accessibleName() == "Test Label"
        assert widget.toolTip() == "Test Label"
        
        # Test adding ARIA description
        accessibility_helper.add_widget_aria_description(widget, "Test Description")
        assert widget.accessibleDescription() == "Test Description"
    
    def test_accessibility_validation(self, accessibility_helper):
        """Test accessibility validation."""
        validation_results = accessibility_helper.validate_accessibility()
        
        # Check that validation returns expected keys
        expected_keys = [
            "keyboard_navigation", "focus_indicators", "color_contrast",
            "text_alternatives", "aria_labels"
        ]
        
        for key in expected_keys:
            assert key in validation_results
            assert isinstance(validation_results[key], bool)
    
    def test_accessibility_report(self, accessibility_helper):
        """Test accessibility report generation."""
        report = accessibility_helper.get_accessibility_report()
        
        assert isinstance(report, str)
        assert "Accessibility Compliance Report" in report
        assert "Overall Score" in report


class TestPerformanceMonitor:
    """Test cases for PerformanceMonitor class."""
    
    @pytest.fixture
    def app(self):
        """Create QApplication instance for testing."""
        if not QApplication.instance():
            app = QApplication([])
        else:
            app = QApplication.instance()
        return app
    
    @pytest.fixture
    def parent_widget(self, app):
        """Create parent widget for testing."""
        return QWidget()
    
    @pytest.fixture
    def performance_monitor(self, parent_widget):
        """Create PerformanceMonitor instance for testing."""
        return PerformanceMonitor(parent_widget)
    
    def test_performance_monitor_initialization(self, performance_monitor):
        """Test performance monitor initialization."""
        assert isinstance(performance_monitor, PerformanceMonitor)
        assert hasattr(performance_monitor, 'memory_usage_history')
        assert hasattr(performance_monitor, 'cpu_usage_history')
        assert hasattr(performance_monitor, 'fps_history')
        assert hasattr(performance_monitor, 'is_monitoring')
        
        # Check initial state
        assert performance_monitor.is_monitoring == False
        assert len(performance_monitor.memory_usage_history) == 0
        assert len(performance_monitor.cpu_usage_history) == 0
        assert len(performance_monitor.fps_history) == 0
    
    def test_start_stop_monitoring(self, performance_monitor):
        """Test starting and stopping monitoring."""
        # Test starting monitoring
        performance_monitor.start_monitoring()
        assert performance_monitor.is_monitoring == True
        
        # Test stopping monitoring
        performance_monitor.stop_monitoring()
        assert performance_monitor.is_monitoring == False
    
    def test_performance_stats(self, performance_monitor):
        """Test performance statistics."""
        # Get initial stats
        stats = performance_monitor.get_performance_stats()
        
        # Check that stats dictionary has expected keys
        expected_keys = [
            "memory_usage", "cpu_usage", "fps", "avg_frame_time",
            "peak_memory", "peak_cpu", "min_fps"
        ]
        
        for key in expected_keys:
            assert key in stats
            assert isinstance(stats[key], float)
    
    def test_performance_report(self, performance_monitor):
        """Test performance report generation."""
        report = performance_monitor.get_performance_report()
        
        assert isinstance(report, str)
        assert "Performance Report" in report
        assert "Memory Usage" in report
        assert "CPU Usage" in report
        assert "Performance Rating" in report
    
    def test_frame_recording(self, performance_monitor):
        """Test frame recording functionality."""
        # Record some frames
        performance_monitor.record_frame()
        performance_monitor.record_frame()
        performance_monitor.record_frame()
        
        assert performance_monitor.frame_count == 3
        
        # Record frame time
        import time
        start_time = time.time()
        time.sleep(0.001)  # Small delay
        performance_monitor.record_frame_time(start_time)
        
        assert len(performance_monitor.frame_times) == 1
        assert performance_monitor.frame_times[0] > 0
    
    def test_performance_thresholds(self, performance_monitor):
        """Test performance threshold settings."""
        # Test setting thresholds
        performance_monitor.set_memory_warning_threshold(75.0)
        assert performance_monitor.memory_warning_threshold == 75.0
        
        performance_monitor.set_cpu_warning_threshold(70.0)
        assert performance_monitor.cpu_warning_threshold == 70.0
        
        performance_monitor.set_fps_warning_threshold(25.0)
        assert performance_monitor.fps_warning_threshold == 25.0
    
    def test_clear_history(self, performance_monitor):
        """Test clearing performance history."""
        # Add some data to history
        performance_monitor.memory_usage_history.append(100.0)
        performance_monitor.cpu_usage_history.append(50.0)
        performance_monitor.fps_history.append(60.0)
        
        # Clear history
        performance_monitor.clear_history()
        
        # Check that history is cleared
        assert len(performance_monitor.memory_usage_history) == 0
        assert len(performance_monitor.cpu_usage_history) == 0
        assert len(performance_monitor.fps_history) == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])