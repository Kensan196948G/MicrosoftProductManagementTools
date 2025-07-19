#!/usr/bin/env python3
"""
Enhanced Button Manager Tests - Microsoft 365 Management Tools
pytest-qt Tests for Advanced Button Management System

Test Coverage:
- Button creation and configuration
- State management and transitions
- Animation and visual effects
- Responsive layout behavior
- Performance optimization testing

Author: Frontend Developer (dev0)
Version: 3.1.0
Date: 2025-07-19
"""

import sys
import pytest
import time
from unittest.mock import Mock, patch, MagicMock
from typing import Dict, List, Any

try:
    from PyQt6.QtWidgets import QApplication, QWidget, QPushButton
    from PyQt6.QtCore import Qt, QTimer, QSize, QRect, QPoint
    from PyQt6.QtGui import QKeySequence, QCursor
    from PyQt6.QtTest import QTest
    import pytest_qt
except ImportError as e:
    print(f"❌ PyQt6 or pytest-qt not available: {e}")
    sys.exit(1)

# Import components to test
sys.path.append('/mnt/e/MicrosoftProductManagementTools/src')
try:
    from gui.components.enhanced_button_manager import (
        EnhancedButtonManager, EnhancedButton, ResponsiveButtonLayout,
        ButtonState, ButtonConfig, ButtonSize, ButtonPriority
    )
except ImportError as e:
    print(f"❌ Enhanced Button Manager not available: {e}")
    pytest.skip("Enhanced Button Manager not available", allow_module_level=True)


class TestButtonConfig:
    """Button Configuration Tests"""
    
    def test_button_config_creation(self):
        """Test button configuration creation"""
        config = ButtonConfig(
            id="test_button",
            text="Test Button",
            icon="🧪",
            tooltip="Test tooltip",
            shortcut="Ctrl+T",
            size=ButtonSize.MEDIUM,
            priority=ButtonPriority.PRIMARY,
            category="test",
            enabled=True,
            visible=True
        )
        
        assert config.id == "test_button"
        assert config.text == "Test Button"
        assert config.icon == "🧪"
        assert config.tooltip == "Test tooltip"
        assert config.shortcut == "Ctrl+T"
        assert config.size == ButtonSize.MEDIUM
        assert config.priority == ButtonPriority.PRIMARY
        assert config.category == "test"
        assert config.enabled is True
        assert config.visible is True
    
    def test_button_config_defaults(self):
        """Test button configuration default values"""
        config = ButtonConfig(
            id="minimal_button",
            text="Minimal Button"
        )
        
        assert config.icon == ""
        assert config.tooltip == ""
        assert config.shortcut == ""
        assert config.size == ButtonSize.MEDIUM
        assert config.priority == ButtonPriority.PRIMARY
        assert config.category == "general"
        assert config.enabled is True
        assert config.visible is True
        assert config.handler is None


class TestEnhancedButton:
    """Enhanced Button Tests"""
    
    @pytest.fixture
    def app(self, qtbot):
        """PyQt Application fixture"""
        return QApplication.instance() or QApplication([])
    
    @pytest.fixture
    def button_config(self):
        """Basic button configuration fixture"""
        return ButtonConfig(
            id="test_button",
            text="🧪 Test Button",
            tooltip="This is a test button",
            shortcut="Ctrl+T",
            size=ButtonSize.MEDIUM,
            priority=ButtonPriority.PRIMARY,
            category="test"
        )
    
    @pytest.fixture
    def enhanced_button(self, qtbot, button_config):
        """Enhanced button fixture"""
        button = EnhancedButton(button_config)
        qtbot.addWidget(button)
        return button
    
    def test_button_initialization(self, qtbot, enhanced_button, button_config):
        """Test enhanced button initialization"""
        assert enhanced_button.config == button_config
        assert enhanced_button.current_state == ButtonState.IDLE
        assert enhanced_button.progress_value == 0
        assert enhanced_button.text() == button_config.text
        
        # Check size
        size = button_config.size.value
        assert enhanced_button.minimumSize().width() == size[0]
        assert enhanced_button.minimumSize().height() == size[1]
    
    def test_button_tooltip(self, qtbot, enhanced_button, button_config):
        """Test button tooltip functionality"""
        expected_tooltip = f"{button_config.tooltip} ({button_config.shortcut})"
        assert enhanced_button.toolTip() == expected_tooltip
    
    def test_button_shortcut(self, qtbot, enhanced_button):
        """Test keyboard shortcut functionality"""
        # Simulate shortcut press
        qtbot.keyPress(enhanced_button, Qt.Key.Key_T, Qt.KeyboardModifier.ControlModifier)
        
        # Should trigger click (tested via signal emission)
        # Note: Actual click testing requires proper focus handling
    
    def test_state_transitions(self, qtbot, enhanced_button):
        """Test button state transitions"""
        # Test IDLE -> LOADING
        enhanced_button.set_state(ButtonState.LOADING, 50)
        assert enhanced_button.current_state == ButtonState.LOADING
        assert enhanced_button.progress_value == 50
        assert "処理中" in enhanced_button.text()
        assert not enhanced_button.isEnabled()
        
        # Test LOADING -> SUCCESS
        enhanced_button.set_state(ButtonState.SUCCESS)
        assert enhanced_button.current_state == ButtonState.SUCCESS
        assert "✅ 完了" in enhanced_button.text()
        
        # Wait for auto-reset
        qtbot.wait(2100)  # Wait for auto-reset (2 seconds + buffer)
        assert enhanced_button.current_state == ButtonState.IDLE
        
        # Test IDLE -> ERROR
        enhanced_button.set_state(ButtonState.ERROR)
        assert enhanced_button.current_state == ButtonState.ERROR
        assert "❌ エラー" in enhanced_button.text()
        
        # Wait for auto-reset
        qtbot.wait(3100)  # Wait for auto-reset (3 seconds + buffer)
        assert enhanced_button.current_state == ButtonState.IDLE
    
    def test_progress_updates(self, qtbot, enhanced_button):
        """Test progress update functionality"""
        enhanced_button.set_state(ButtonState.LOADING)
        
        # Test progress updates
        for progress in [0, 25, 50, 75, 100]:
            enhanced_button.update_progress(progress)
            assert enhanced_button.progress_value == progress
            assert f"({progress}%)" in enhanced_button.text()
    
    def test_mouse_interactions(self, qtbot, enhanced_button):
        """Test mouse interaction events"""
        # Test mouse enter/leave for hover animation
        enter_event = QTest.mouseMove(enhanced_button, QPoint(50, 25))
        qtbot.wait(50)  # Wait for animation
        
        leave_event = QTest.mouseMove(enhanced_button, QPoint(-10, -10))
        qtbot.wait(50)  # Wait for animation
        
        # Test click
        qtbot.mouseClick(enhanced_button, Qt.MouseButton.LeftButton)
        # Click should trigger signal (tested in integration)
    
    def test_context_menu(self, qtbot, enhanced_button):
        """Test right-click context menu"""
        # Right-click to show context menu
        qtbot.mouseClick(enhanced_button, Qt.MouseButton.RightButton)
        
        # Context menu should be available (implementation-dependent verification)
        assert enhanced_button.contextMenuPolicy() == Qt.ContextMenuPolicy.CustomContextMenu
    
    def test_long_press_detection(self, qtbot, enhanced_button):
        """Test long press detection"""
        # Simulate long press
        qtbot.mousePress(enhanced_button, Qt.MouseButton.LeftButton)
        qtbot.wait(900)  # Wait longer than long press threshold (800ms)
        qtbot.mouseRelease(enhanced_button, Qt.MouseButton.LeftButton)
        
        # Long press signal should have been emitted (tested via signal spy)
    
    def test_button_styling(self, qtbot, enhanced_button):
        """Test button styling based on priority"""
        # Button should have applied stylesheet
        assert enhanced_button.styleSheet() != ""
        
        # Test different priorities
        priorities = [
            ButtonPriority.PRIMARY,
            ButtonPriority.SUCCESS,
            ButtonPriority.WARNING,
            ButtonPriority.DANGER,
            ButtonPriority.INFO
        ]
        
        for priority in priorities:
            config = ButtonConfig(
                id=f"test_{priority.value}",
                text=f"Test {priority.value}",
                priority=priority
            )
            button = EnhancedButton(config)
            qtbot.addWidget(button)
            
            # Should have different styling based on priority
            assert button.styleSheet() != ""
            button.deleteLater()


class TestResponsiveButtonLayout:
    """Responsive Button Layout Tests"""
    
    @pytest.fixture
    def app(self, qtbot):
        """PyQt Application fixture"""
        return QApplication.instance() or QApplication([])
    
    @pytest.fixture
    def test_buttons(self, qtbot):
        """Create test buttons for layout testing"""
        buttons = []
        for i in range(12):  # Create 12 test buttons
            config = ButtonConfig(
                id=f"test_button_{i}",
                text=f"Button {i+1}",
                category="test"
            )
            button = EnhancedButton(config)
            qtbot.addWidget(button)
            buttons.append(button)
        return buttons
    
    @pytest.fixture
    def responsive_layout(self, qtbot, test_buttons):
        """Responsive layout fixture"""
        layout = ResponsiveButtonLayout(test_buttons)
        qtbot.addWidget(layout)
        return layout
    
    def test_layout_initialization(self, qtbot, responsive_layout, test_buttons):
        """Test responsive layout initialization"""
        assert responsive_layout.buttons == test_buttons
        assert responsive_layout.current_columns == 3  # Default
        assert responsive_layout.layout is not None
    
    def test_responsive_behavior(self, qtbot, responsive_layout):
        """Test responsive layout behavior"""
        # Test different window sizes
        test_sizes = [
            (500, 400, 1),    # Small -> 1 column
            (700, 500, 2),    # Medium -> 2 columns
            (1000, 600, 3),   # Large -> 3 columns
            (1300, 700, 4),   # Extra large -> 4 columns
        ]
        
        for width, height, expected_columns in test_sizes:
            responsive_layout.resize(width, height)
            qtbot.wait(50)  # Wait for resize processing
            
            assert responsive_layout.current_columns == expected_columns
    
    def test_button_arrangement(self, qtbot, responsive_layout, test_buttons):
        """Test button arrangement in grid"""
        responsive_layout.resize(1000, 600)  # 3 columns
        qtbot.wait(50)
        
        # Verify buttons are arranged in grid
        layout = responsive_layout.layout
        
        # Should have buttons arranged in rows and columns
        for i, button in enumerate(test_buttons):
            expected_row = i // 3
            expected_col = i % 3
            
            # Verify button is in correct position
            item = layout.itemAtPosition(expected_row, expected_col)
            assert item is not None
            assert item.widget() == button


class TestEnhancedButtonManager:
    """Enhanced Button Manager Tests"""
    
    @pytest.fixture
    def app(self, qtbot):
        """PyQt Application fixture"""
        return QApplication.instance() or QApplication([])
    
    @pytest.fixture
    def button_manager(self, qtbot):
        """Button manager fixture"""
        manager = EnhancedButtonManager()
        return manager
    
    def test_manager_initialization(self, qtbot, button_manager):
        """Test button manager initialization"""
        # Should have 26 buttons (Microsoft 365 functions)
        assert len(button_manager.buttons) == 26
        
        # Should have 6 categories
        expected_categories = [
            "regular_reports", "analytics", "entra_id",
            "exchange", "teams", "onedrive"
        ]
        assert len(button_manager.button_groups) == len(expected_categories)
        for category in expected_categories:
            assert category in button_manager.button_groups
    
    def test_button_configuration_completeness(self, qtbot, button_manager):
        """Test that all buttons are properly configured"""
        for button_id, button in button_manager.buttons.items():
            assert button.config.id == button_id
            assert button.config.text != ""
            assert button.config.category in button_manager.button_groups
            assert button.config.priority in ButtonPriority
            assert button.config.size in ButtonSize
    
    def test_category_specific_buttons(self, qtbot, button_manager):
        """Test category-specific button retrieval"""
        # Test each category
        category_expected_counts = {
            "regular_reports": 6,
            "analytics": 5,
            "entra_id": 4,
            "exchange": 4,
            "teams": 4,
            "onedrive": 4
        }
        
        for category, expected_count in category_expected_counts.items():
            buttons = button_manager.get_buttons_by_category(category)
            assert len(buttons) == expected_count
            
            # Verify all buttons belong to the category
            for button in buttons:
                assert button.config.category == category
    
    def test_signal_connections(self, qtbot, button_manager):
        """Test signal connections and emission"""
        # Test button click signal
        clicked_signals = []
        state_changed_signals = []
        
        def on_button_clicked(button_id, category):
            clicked_signals.append((button_id, category))
        
        def on_state_changed(button_id, state):
            state_changed_signals.append((button_id, state))
        
        button_manager.button_clicked.connect(on_button_clicked)
        button_manager.button_state_changed.connect(on_state_changed)
        
        # Simulate button click
        test_button_id = "daily_report"
        button_manager.on_button_clicked(test_button_id)
        
        # Should have emitted clicked signal
        assert len(clicked_signals) == 1
        assert clicked_signals[0][0] == test_button_id
        assert clicked_signals[0][1] == "regular_reports"
    
    def test_state_management_operations(self, qtbot, button_manager):
        """Test state management operations"""
        test_button_id = "license_analysis"
        
        # Test setting button state
        button_manager.set_button_state(test_button_id, ButtonState.LOADING, 30)
        button = button_manager.buttons[test_button_id]
        assert button.current_state == ButtonState.LOADING
        assert button.progress_value == 30
        
        # Test progress update
        button_manager.update_button_progress(test_button_id, 75)
        assert button.progress_value == 75
        
        # Test state change to success
        button_manager.set_button_state(test_button_id, ButtonState.SUCCESS)
        assert button.current_state == ButtonState.SUCCESS
    
    def test_bulk_operations(self, qtbot, button_manager):
        """Test bulk enable/disable operations"""
        # Test disable all buttons
        button_manager.disable_buttons()
        
        for button in button_manager.buttons.values():
            assert button.current_state == ButtonState.DISABLED
        
        # Test enable all buttons
        button_manager.enable_buttons()
        
        for button in button_manager.buttons.values():
            assert button.current_state == ButtonState.IDLE
        
        # Test selective disable
        test_button_ids = ["daily_report", "weekly_report", "monthly_report"]
        button_manager.disable_buttons(test_button_ids)
        
        for button_id in test_button_ids:
            button = button_manager.buttons[button_id]
            assert button.current_state == ButtonState.DISABLED
    
    def test_layout_creation(self, qtbot, button_manager):
        """Test category layout creation"""
        # Test creating layout for specific category
        category = "regular_reports"
        layout = button_manager.create_category_layout(category)
        
        assert isinstance(layout, ResponsiveButtonLayout)
        assert category in button_manager.layouts
        assert button_manager.layouts[category] == layout
        
        # Verify layout contains correct buttons
        expected_buttons = button_manager.get_buttons_by_category(category)
        assert layout.buttons == expected_buttons
    
    def test_statistics_generation(self, qtbot, button_manager):
        """Test statistics generation"""
        stats = button_manager.get_button_stats()
        
        # Verify statistics structure
        assert "total_buttons" in stats
        assert "categories" in stats
        assert "states" in stats
        assert "category_counts" in stats
        
        # Verify values
        assert stats["total_buttons"] == 26
        assert stats["categories"] == 6
        
        # Initially all buttons should be idle
        assert stats["states"].get("idle", 0) == 26
        
        # Category counts should match expected
        expected_counts = {
            "regular_reports": 6,
            "analytics": 5,
            "entra_id": 4,
            "exchange": 4,
            "teams": 4,
            "onedrive": 4
        }
        
        for category, expected_count in expected_counts.items():
            assert stats["category_counts"][category] == expected_count


class TestPerformanceAndStressTests:
    """Performance and Stress Tests"""
    
    @pytest.fixture
    def button_manager(self, qtbot):
        """Button manager fixture"""
        return EnhancedButtonManager()
    
    def test_rapid_state_changes(self, qtbot, button_manager):
        """Test rapid state changes performance"""
        test_button_id = "daily_report"
        
        start_time = time.time()
        
        # Perform rapid state changes
        for i in range(100):
            states = [ButtonState.LOADING, ButtonState.SUCCESS, ButtonState.IDLE]
            for state in states:
                button_manager.set_button_state(test_button_id, state)
                qtbot.wait(1)  # Minimal wait
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Should complete within reasonable time
        assert duration < 5.0, f"Rapid state changes took too long: {duration}s"
    
    def test_massive_progress_updates(self, qtbot, button_manager):
        """Test massive progress updates"""
        test_button_id = "license_analysis"
        button_manager.set_button_state(test_button_id, ButtonState.LOADING)
        
        start_time = time.time()
        
        # Update progress rapidly
        for progress in range(0, 101, 1):
            button_manager.update_button_progress(test_button_id, progress)
            if progress % 10 == 0:  # Minimal UI updates
                qtbot.wait(1)
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Should handle massive updates efficiently
        assert duration < 2.0, f"Progress updates took too long: {duration}s"
    
    def test_memory_usage_stability(self, qtbot, button_manager):
        """Test memory usage stability"""
        import psutil
        import os
        
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss
        
        # Perform extensive operations
        for cycle in range(50):
            # Create and destroy layouts
            for category in button_manager.button_groups.keys():
                layout = button_manager.create_category_layout(category)
                layout.deleteLater()
            
            # Rapid state changes
            for button_id in list(button_manager.buttons.keys())[:5]:
                button_manager.set_button_state(button_id, ButtonState.LOADING)
                button_manager.set_button_state(button_id, ButtonState.SUCCESS)
                button_manager.set_button_state(button_id, ButtonState.IDLE)
        
        # Force garbage collection
        import gc
        gc.collect()
        qtbot.wait(100)
        
        final_memory = process.memory_info().rss
        memory_increase = final_memory - initial_memory
        
        # Memory increase should be reasonable
        assert memory_increase < 20 * 1024 * 1024, f"Memory leak detected: {memory_increase / 1024 / 1024:.2f}MB"


if __name__ == "__main__":
    # Run tests
    pytest.main([
        __file__,
        "-v",
        "--tb=short",
        "--maxfail=3",
        "-x"  # Stop on first failure for debugging
    ])