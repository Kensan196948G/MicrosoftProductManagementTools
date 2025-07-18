"""
Test cases for main window GUI components.
Tests PyQt6 GUI functionality and PowerShell compatibility.
"""

import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock
from PyQt6.QtWidgets import QApplication, QWidget, QPushButton, QTabWidget
from PyQt6.QtCore import Qt
from PyQt6.QtTest import QTest

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from src.gui.main_window import MainWindow
from src.core.config import Config


class TestMainWindow:
    """Test cases for MainWindow class."""
    
    @pytest.fixture
    def app(self):
        """Create QApplication instance for testing."""
        if not QApplication.instance():
            app = QApplication([])
        else:
            app = QApplication.instance()
        return app
    
    @pytest.fixture
    def config(self):
        """Create mock config for testing."""
        config = Mock(spec=Config)
        config.get.return_value = "test_value"
        return config
    
    @pytest.fixture
    def main_window(self, app, config):
        """Create MainWindow instance for testing."""
        with patch('src.gui.main_window.logging.getLogger'):
            window = MainWindow(config)
            return window
    
    def test_window_initialization(self, main_window):
        """Test window initialization."""
        assert main_window.windowTitle() == "🚀 Microsoft 365 統合管理ツール - 完全版 Python Edition v2.0"
        assert main_window.width() == 1400
        assert main_window.height() == 900
        
    def test_function_tabs_creation(self, main_window):
        """Test function tabs are created correctly."""
        # Check if tabs are created
        assert hasattr(main_window, 'function_tabs')
        assert isinstance(main_window.function_tabs, QTabWidget)
        
        # Check tab count (should be 6 categories)
        assert main_window.function_tabs.count() == 6
        
        # Check tab names
        expected_tabs = [
            "📊 定期レポート",
            "🔍 分析レポート", 
            "👥 Entra ID管理",
            "📧 Exchange Online",
            "💬 Teams管理",
            "💾 OneDrive管理"
        ]
        
        for i, expected_name in enumerate(expected_tabs):
            assert main_window.function_tabs.tabText(i) == expected_name
    
    def test_regular_reports_tab(self, main_window):
        """Test regular reports tab buttons."""
        # Get first tab (regular reports)
        regular_tab = main_window.function_tabs.widget(0)
        buttons = regular_tab.findChildren(QPushButton)
        
        # Should have 6 buttons
        assert len(buttons) == 6
        
        # Check button texts
        expected_buttons = [
            "📅 日次レポート",
            "📊 週次レポート",
            "📈 月次レポート", 
            "📆 年次レポート",
            "🧪 テスト実行",
            "📋 最新日次レポート表示"
        ]
        
        button_texts = [btn.text() for btn in buttons]
        for expected in expected_buttons:
            assert expected in button_texts
    
    def test_analysis_reports_tab(self, main_window):
        """Test analysis reports tab buttons."""
        # Get second tab (analysis reports)
        analysis_tab = main_window.function_tabs.widget(1)
        buttons = analysis_tab.findChildren(QPushButton)
        
        # Should have 5 buttons
        assert len(buttons) == 5
        
        # Check button texts
        expected_buttons = [
            "📊 ライセンス分析",
            "📈 使用状況分析",
            "⚡ パフォーマンス分析",
            "🛡️ セキュリティ分析",
            "🔍 権限監査"
        ]
        
        button_texts = [btn.text() for btn in buttons]
        for expected in expected_buttons:
            assert expected in button_texts
    
    def test_entra_id_tab(self, main_window):
        """Test Entra ID management tab buttons."""
        # Get third tab (Entra ID)
        entra_tab = main_window.function_tabs.widget(2)
        buttons = entra_tab.findChildren(QPushButton)
        
        # Should have 4 buttons
        assert len(buttons) == 4
        
        # Check button texts
        expected_buttons = [
            "👥 ユーザー一覧",
            "🔐 MFA状況",
            "🛡️ 条件付きアクセス",
            "📋 サインインログ"
        ]
        
        button_texts = [btn.text() for btn in buttons]
        for expected in expected_buttons:
            assert expected in button_texts
    
    def test_exchange_tab(self, main_window):
        """Test Exchange Online management tab buttons."""
        # Get fourth tab (Exchange)
        exchange_tab = main_window.function_tabs.widget(3)
        buttons = exchange_tab.findChildren(QPushButton)
        
        # Should have 4 buttons
        assert len(buttons) == 4
        
        # Check button texts
        expected_buttons = [
            "📧 メールボックス管理",
            "📨 メールフロー分析",
            "🛡️ スパム対策",
            "📊 配信分析"
        ]
        
        button_texts = [btn.text() for btn in buttons]
        for expected in expected_buttons:
            assert expected in button_texts
    
    def test_teams_tab(self, main_window):
        """Test Teams management tab buttons."""
        # Get fifth tab (Teams)
        teams_tab = main_window.function_tabs.widget(4)
        buttons = teams_tab.findChildren(QPushButton)
        
        # Should have 4 buttons
        assert len(buttons) == 4
        
        # Check button texts
        expected_buttons = [
            "💬 Teams使用状況",
            "⚙️ Teams設定",
            "📞 会議品質",
            "📱 アプリ分析"
        ]
        
        button_texts = [btn.text() for btn in buttons]
        for expected in expected_buttons:
            assert expected in button_texts
    
    def test_onedrive_tab(self, main_window):
        """Test OneDrive management tab buttons."""
        # Get sixth tab (OneDrive)
        onedrive_tab = main_window.function_tabs.widget(5)
        buttons = onedrive_tab.findChildren(QPushButton)
        
        # Should have 4 buttons
        assert len(buttons) == 4
        
        # Check button texts
        expected_buttons = [
            "💾 ストレージ分析",
            "🔗 共有分析",
            "⚠️ 同期エラー",
            "🌐 外部共有分析"
        ]
        
        button_texts = [btn.text() for btn in buttons]
        for expected in expected_buttons:
            assert expected in button_texts
    
    def test_total_button_count(self, main_window):
        """Test total button count (should be 26)."""
        total_buttons = 0
        for i in range(main_window.function_tabs.count()):
            tab = main_window.function_tabs.widget(i)
            buttons = tab.findChildren(QPushButton)
            total_buttons += len(buttons)
        
        # Should have exactly 26 buttons total
        assert total_buttons == 26
    
    def test_button_styling(self, main_window):
        """Test button styling matches PowerShell GUI."""
        # Get a button to test styling
        first_tab = main_window.function_tabs.widget(0)
        buttons = first_tab.findChildren(QPushButton)
        
        if buttons:
            button = buttons[0]
            
            # Check minimum size
            assert button.minimumSize().width() == 190
            assert button.minimumSize().height() == 50
            
            # Check cursor
            assert button.cursor().shape() == Qt.CursorShape.PointingHandCursor
            
            # Check if button has style sheet
            assert button.styleSheet() != ""
    
    def test_keyboard_shortcuts(self, main_window):
        """Test keyboard shortcuts are properly set."""
        # Test if shortcuts are created
        assert hasattr(main_window, 'refresh_shortcut')
        assert hasattr(main_window, 'test_shortcut')
        assert hasattr(main_window, 'quit_shortcut')
        assert hasattr(main_window, 'f5_shortcut')
        
        # Test shortcut key sequences
        assert main_window.refresh_shortcut.key().toString() == "Ctrl+R"
        assert main_window.test_shortcut.key().toString() == "Ctrl+T"
        assert main_window.quit_shortcut.key().toString() == "Ctrl+Q"
        assert main_window.f5_shortcut.key().toString() == "F5"
    
    def test_log_viewer_integration(self, main_window):
        """Test log viewer integration."""
        # Check if log viewer is created
        assert hasattr(main_window, 'log_viewer')
        assert main_window.log_viewer is not None
        
        # Test log message signal connection
        assert main_window.log_message.receivers() > 0
    
    def test_status_bar_components(self, main_window):
        """Test status bar components."""
        status_bar = main_window.statusBar()
        assert status_bar is not None
        
        # Check if status components exist
        assert hasattr(main_window, 'status_label')
        assert hasattr(main_window, 'progress_bar')
        assert hasattr(main_window, 'connection_status')
        
        # Check initial status
        assert main_window.status_label.text() == "準備完了"
        assert main_window.progress_bar.isVisible() == False
    
    def test_menu_bar_creation(self, main_window):
        """Test menu bar creation."""
        menu_bar = main_window.menuBar()
        assert menu_bar is not None
        
        # Check if menus exist
        actions = menu_bar.actions()
        menu_titles = [action.text() for action in actions]
        
        expected_menus = ["ファイル(&F)", "ツール(&T)", "ヘルプ(&H)"]
        for expected in expected_menus:
            assert expected in menu_titles
    
    @patch('src.gui.main_window.QMessageBox')
    def test_button_click_handling(self, mock_message_box, main_window):
        """Test button click handling."""
        # Get a button to test
        first_tab = main_window.function_tabs.widget(0)
        buttons = first_tab.findChildren(QPushButton)
        
        if buttons:
            button = buttons[0]
            
            # Mock the execute function to avoid actual execution
            with patch.object(main_window, '_execute_function') as mock_execute:
                mock_execute.return_value = [{"test": "data"}]
                
                # Simulate button click
                button.click()
                
                # Check if status was updated
                assert main_window.status_label.text() != "準備完了"
    
    def test_function_button_creation(self, main_window):
        """Test function button creation method."""
        # Test button creation
        button = main_window._create_function_button("Test Button", "test_action")
        
        assert button.text() == "Test Button"
        assert button.minimumSize().width() == 190
        assert button.minimumSize().height() == 50
        assert button.cursor().shape() == Qt.CursorShape.PointingHandCursor
    
    def test_theme_application(self, main_window):
        """Test theme application."""
        # Check if main window has style sheet applied
        assert main_window.styleSheet() != ""
        
        # Check if theme includes expected elements
        style = main_window.styleSheet()
        assert "QMainWindow" in style
        assert "QTabWidget" in style
        assert "QStatusBar" in style
    
    def test_window_icon(self, main_window):
        """Test window icon setting."""
        # Icon may or may not be set depending on file availability
        # Just check that the code doesn't crash
        icon = main_window.windowIcon()
        assert icon is not None
    
    def test_close_event_handling(self, main_window):
        """Test close event handling."""
        # Mock QMessageBox for close confirmation
        with patch('src.gui.main_window.QMessageBox') as mock_message_box:
            mock_message_box.question.return_value = mock_message_box.StandardButton.Yes
            
            # Create a mock close event
            from PyQt6.QtGui import QCloseEvent
            close_event = QCloseEvent()
            
            # Test close event
            main_window.closeEvent(close_event)
            
            # Check if message box was called
            mock_message_box.question.assert_called_once()
    
    def test_api_client_initialization(self, main_window):
        """Test API client initialization."""
        # Check if graph_client attribute exists
        assert hasattr(main_window, 'graph_client')
        
        # Initially should be None
        assert main_window.graph_client is None
    
    def test_mock_data_generation(self, main_window):
        """Test mock data generation."""
        # Test mock data generation
        mock_data = main_window._generate_mock_data("test_action", "Test Report")
        
        assert isinstance(mock_data, list)
        assert len(mock_data) > 0
        
        # Check data structure
        if mock_data:
            first_item = mock_data[0]
            assert isinstance(first_item, dict)
            assert 'ID' in first_item
            assert 'レポートタイプ' in first_item
            assert 'カテゴリ' in first_item
    
    def test_buttons_enable_disable(self, main_window):
        """Test button enable/disable functionality."""
        # Test setting buttons enabled/disabled
        main_window._set_buttons_enabled(False)
        
        # Check if buttons are disabled
        for i in range(main_window.function_tabs.count()):
            tab = main_window.function_tabs.widget(i)
            buttons = tab.findChildren(QPushButton)
            for button in buttons:
                assert not button.isEnabled()
        
        # Re-enable buttons
        main_window._set_buttons_enabled(True)
        
        # Check if buttons are enabled
        for i in range(main_window.function_tabs.count()):
            tab = main_window.function_tabs.widget(i)
            buttons = tab.findChildren(QPushButton)
            for button in buttons:
                assert button.isEnabled()
    
    def test_custom_log_addition(self, main_window):
        """Test custom log addition."""
        # Test adding custom log message
        main_window.add_custom_log("Test message", "INFO")
        
        # Should not raise an exception
        assert True
    
    def test_about_dialog(self, main_window):
        """Test about dialog."""
        # Mock QMessageBox for about dialog
        with patch('src.gui.main_window.QMessageBox') as mock_message_box:
            main_window.show_about_dialog()
            
            # Check if about dialog was called
            mock_message_box.about.assert_called_once()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])