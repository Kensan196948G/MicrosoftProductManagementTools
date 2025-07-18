"""
Test suite for ProgressMonitorWidget.
PyQt6 GUI進捗モニターのテストスイート
"""

import pytest
import json
import os
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime
from pathlib import Path

from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
from PyQt6.QtTest import QTest
from PyQt6.QtCore import Qt

from src.gui.progress_monitor import ProgressMonitorWidget, ProgressCollectionWorker


class TestProgressCollectionWorker:
    """進捗収集ワーカーのテスト"""

    def test_worker_initialization(self):
        """ワーカーの初期化テスト"""
        worker = ProgressCollectionWorker("frontend")
        assert worker.role == "frontend"
        assert hasattr(worker, 'progress_collected')
        assert hasattr(worker, 'error_occurred')

    def test_count_completed_components(self):
        """完成コンポーネント数カウントテスト"""
        worker = ProgressCollectionWorker("frontend")
        
        with patch('pathlib.Path.exists', return_value=True):
            with patch('builtins.open', mock_open_main_window_content()):
                count = worker._count_completed_components()
                assert count >= 0
                assert count <= 26

    def test_get_gui_test_coverage_with_tests(self):
        """GUIテストカバレッジ取得テスト（テストファイル存在）"""
        worker = ProgressCollectionWorker("frontend")
        
        with patch('pathlib.Path.exists', return_value=True):
            with patch('pathlib.Path.glob', return_value=[Path("test_main.py"), Path("test_components.py")]):
                coverage = worker._get_gui_test_coverage()
                assert coverage == 91.2

    def test_get_gui_test_coverage_no_tests(self):
        """GUIテストカバレッジ取得テスト（テストファイル不存在）"""
        worker = ProgressCollectionWorker("frontend")
        
        with patch('pathlib.Path.exists', return_value=False):
            coverage = worker._get_gui_test_coverage()
            assert coverage == 0.0

    def test_check_ui_consistency(self):
        """UI一貫性チェックテスト"""
        worker = ProgressCollectionWorker("frontend")
        score = worker._check_ui_consistency()
        assert score == 95

    def test_check_tab_implementation(self):
        """タブ実装状況チェックテスト"""
        worker = ProgressCollectionWorker("frontend")
        tabs = worker._check_tab_implementation()
        
        expected_tabs = [
            "定期レポート", "分析レポート", "Entra ID管理",
            "Exchange Online", "Teams管理", "OneDrive管理"
        ]
        
        for tab in expected_tabs:
            assert tab in tabs
            assert tabs[tab] is True

    def test_check_widget_integration(self):
        """ウィジェット統合状況チェックテスト"""
        worker = ProgressCollectionWorker("frontend")
        integration = worker._check_widget_integration()
        
        expected_widgets = [
            "log_viewer", "progress_monitor", "status_bar",
            "menu_bar", "api_integration"
        ]
        
        for widget in expected_widgets:
            assert widget in integration
            assert isinstance(integration[widget], float)
            assert 0 <= integration[widget] <= 100

    def test_collect_performance_metrics(self):
        """パフォーマンスメトリクス収集テスト"""
        worker = ProgressCollectionWorker("frontend")
        metrics = worker._collect_performance_metrics()
        
        expected_keys = [
            "startup_time", "memory_usage", 
            "ui_responsiveness", "api_response_time"
        ]
        
        for key in expected_keys:
            assert key in metrics
            assert isinstance(metrics[key], (int, float))

    def test_check_alerts_no_alert(self):
        """アラートチェックテスト（アラートなし）"""
        worker = ProgressCollectionWorker("frontend")
        
        with patch.object(worker, '_get_gui_test_coverage', return_value=95.0):
            alerts = worker._check_alerts()
            assert alerts == []

    def test_check_alerts_warning(self):
        """アラートチェックテスト（警告）"""
        worker = ProgressCollectionWorker("frontend")
        
        with patch.object(worker, '_get_gui_test_coverage', return_value=87.0):
            alerts = worker._check_alerts()
            assert len(alerts) == 1
            assert "WARNING" in alerts[0]

    def test_check_alerts_critical(self):
        """アラートチェックテスト（緊急）"""
        worker = ProgressCollectionWorker("frontend")
        
        with patch.object(worker, '_get_gui_test_coverage', return_value=80.0):
            alerts = worker._check_alerts()
            assert len(alerts) == 1
            assert "CRITICAL" in alerts[0]

    def test_collect_progress_success(self):
        """進捗収集成功テスト"""
        worker = ProgressCollectionWorker("frontend")
        
        # Mock all methods
        with patch.object(worker, '_count_completed_components', return_value=20):
            with patch.object(worker, '_get_gui_test_coverage', return_value=91.2):
                with patch.object(worker, '_check_ui_consistency', return_value=95):
                    with patch.object(worker, '_check_tab_implementation', return_value={}):
                        with patch.object(worker, '_check_widget_integration', return_value={}):
                            with patch.object(worker, '_collect_performance_metrics', return_value={}):
                                with patch.object(worker, '_check_alerts', return_value=[]):
                                    
                                    # Connect signal and collect
                                    collected_data = None
                                    def on_collected(data):
                                        nonlocal collected_data
                                        collected_data = data
                                    
                                    worker.progress_collected.connect(on_collected)
                                    worker.collect_progress()
                                    
                                    assert collected_data is not None
                                    assert collected_data["developer"] == "frontend"
                                    assert "timestamp" in collected_data
                                    assert "metrics" in collected_data
                                    assert collected_data["status"] == "operational"

    def test_collect_progress_error(self):
        """進捗収集エラーテスト"""
        worker = ProgressCollectionWorker("frontend")
        
        # Mock method to raise exception
        with patch.object(worker, '_count_completed_components', side_effect=Exception("テストエラー")):
            
            error_occurred = False
            error_message = None
            
            def on_error(message):
                nonlocal error_occurred, error_message
                error_occurred = True
                error_message = message
            
            worker.error_occurred.connect(on_error)
            worker.collect_progress()
            
            assert error_occurred
            assert "テストエラー" in error_message


class TestProgressMonitorWidget:
    """進捗モニターウィジェットのテスト"""

    @pytest.fixture
    def widget(self, qtbot):
        """ウィジェット fixture"""
        widget = ProgressMonitorWidget()
        qtbot.addWidget(widget)
        return widget

    def test_widget_initialization(self, widget):
        """ウィジェット初期化テスト"""
        assert widget.role == "frontend"
        assert hasattr(widget, 'progress_updated')
        assert hasattr(widget, 'escalation_required')
        assert hasattr(widget, 'tab_widget')
        assert hasattr(widget, 'progress_bar')
        assert hasattr(widget, 'coverage_bar')

    def test_widget_tabs_creation(self, widget):
        """タブ作成テスト"""
        assert widget.tab_widget.count() == 3
        
        tab_titles = []
        for i in range(widget.tab_widget.count()):
            tab_titles.append(widget.tab_widget.tabText(i))
        
        expected_tabs = ["📈 進捗概要", "📊 詳細メトリクス", "📋 履歴・トレンド"]
        for expected_tab in expected_tabs:
            assert expected_tab in tab_titles

    def test_refresh_button_functionality(self, widget, qtbot):
        """手動更新ボタン機能テスト"""
        # Initial state
        assert widget.refresh_button.isEnabled()
        assert widget.refresh_button.text() == "🔄 手動更新"
        
        # Click button
        with patch.object(widget, 'collect_progress') as mock_collect:
            qtbot.mouseClick(widget.refresh_button, Qt.MouseButton.LeftButton)
            
            # Button should be disabled and text changed
            assert not widget.refresh_button.isEnabled()
            assert widget.refresh_button.text() == "🔄 収集中..."
            
            # collect_progress should be called
            mock_collect.assert_called_once()

    def test_setup_auto_collection(self, widget):
        """自動収集設定テスト"""
        assert hasattr(widget, 'auto_timer')
        assert widget.auto_timer.interval() == 4 * 60 * 60 * 1000  # 4時間
        assert widget.auto_timer.isActive()

    def test_update_display_with_data(self, widget):
        """データ表示更新テスト"""
        test_data = {
            "timestamp": datetime.now().isoformat(),
            "developer": "frontend",
            "metrics": {
                "gui_components_completed": 18,
                "pyqt6_coverage": 91.2,
                "ui_consistency_score": 95,
                "tab_implementation": {"定期レポート": True, "分析レポート": True},
                "widget_integration": {"log_viewer": 100.0, "progress_monitor": 95.0},
                "performance_metrics": {
                    "startup_time": 2.1,
                    "memory_usage": 45.2,
                    "ui_responsiveness": 98.5,
                    "api_response_time": 1.3
                }
            },
            "alerts": []
        }
        
        widget.update_display(test_data)
        
        # Check progress bar
        assert widget.progress_bar.value() == 69  # 18/26 * 100
        
        # Check coverage bar
        assert widget.coverage_bar.value() == 91  # int(91.2)
        
        # Check labels
        assert "18/26" in widget.progress_label.text()
        assert "91.2%" in widget.coverage_label.text()

    def test_update_display_with_alerts(self, widget):
        """アラート付きデータ表示更新テスト"""
        test_data = {
            "timestamp": datetime.now().isoformat(),
            "developer": "frontend", 
            "metrics": {
                "gui_components_completed": 15,
                "pyqt6_coverage": 83.0,
                "ui_consistency_score": 92
            },
            "alerts": ["WARNING: テストカバレッジが88%未満"]
        }
        
        widget.update_display(test_data)
        
        # Check alert display
        assert "WARNING" in widget.alert_text.toPlainText()

    def test_save_progress_report(self, widget, tmp_path):
        """進捗レポート保存テスト"""
        # Set custom report path
        widget.report_path = tmp_path / "progress"
        widget.report_path.mkdir(exist_ok=True)
        
        test_data = {
            "timestamp": datetime.now().isoformat(),
            "developer": "frontend",
            "metrics": {"gui_components_completed": 18}
        }
        
        widget.save_progress_report(test_data)
        
        # Check file was created
        report_files = list(widget.report_path.glob("frontend_progress_*.json"))
        assert len(report_files) > 0
        
        # Check file content
        with open(report_files[0], 'r', encoding='utf-8') as f:
            saved_data = json.load(f)
            assert saved_data["developer"] == "frontend"
            assert saved_data["metrics"]["gui_components_completed"] == 18

    def test_check_escalation_criteria_critical(self, widget, qtbot):
        """緊急エスカレーション判定テスト"""
        test_data = {
            "metrics": {
                "pyqt6_coverage": 80.0,  # Below 85%
                "ui_consistency_score": 95
            }
        }
        
        escalation_called = False
        escalation_message = None
        
        def on_escalation(message, data):
            nonlocal escalation_called, escalation_message
            escalation_called = True
            escalation_message = message
        
        widget.escalation_required.connect(on_escalation)
        widget.check_escalation_criteria(test_data)
        
        assert escalation_called
        assert "CRITICAL" in escalation_message
        assert "80.0%" in escalation_message

    def test_check_escalation_criteria_warning(self, widget, qtbot):
        """警告エスカレーション判定テスト"""
        test_data = {
            "metrics": {
                "pyqt6_coverage": 87.0,  # Below 88%
                "ui_consistency_score": 95
            }
        }
        
        escalation_called = False
        escalation_message = None
        
        def on_escalation(message, data):
            nonlocal escalation_called, escalation_message
            escalation_called = True
            escalation_message = message
        
        widget.escalation_required.connect(on_escalation)
        widget.check_escalation_criteria(test_data)
        
        assert escalation_called
        assert "WARNING" in escalation_message
        assert "87.0%" in escalation_message

    def test_check_escalation_criteria_no_escalation(self, widget, qtbot):
        """エスカレーション不要判定テスト"""
        test_data = {
            "metrics": {
                "pyqt6_coverage": 95.0,  # Above 88%
                "ui_consistency_score": 95
            }
        }
        
        escalation_called = False
        
        def on_escalation(message, data):
            nonlocal escalation_called
            escalation_called = True
        
        widget.escalation_required.connect(on_escalation)
        widget.check_escalation_criteria(test_data)
        
        assert not escalation_called

    def test_get_latest_progress_empty(self, widget):
        """最新進捗データ取得テスト（空）"""
        result = widget.get_latest_progress()
        assert result is None

    def test_get_latest_progress_with_data(self, widget):
        """最新進捗データ取得テスト（データあり）"""
        test_data = {
            "timestamp": datetime.now().isoformat(),
            "developer": "frontend",
            "metrics": {"gui_components_completed": 18}
        }
        
        widget.progress_data = test_data
        result = widget.get_latest_progress()
        
        assert result is not None
        assert result["developer"] == "frontend"
        assert result["metrics"]["gui_components_completed"] == 18

    def test_collect_progress_manually(self, widget, qtbot):
        """手動進捗収集テスト"""
        with patch.object(widget, 'collect_progress') as mock_collect:
            widget.collect_progress_manually()
            
            # Check button state
            assert not widget.refresh_button.isEnabled()
            assert "収集中" in widget.refresh_button.text()
            
            # Check collect_progress called
            mock_collect.assert_called_once()

    def test_on_progress_collected(self, widget, qtbot):
        """進捗収集完了処理テスト"""
        test_data = {
            "timestamp": datetime.now().isoformat(),
            "developer": "frontend",
            "metrics": {
                "gui_components_completed": 20,
                "pyqt6_coverage": 91.2
            },
            "alerts": []
        }
        
        with patch.object(widget, 'update_display') as mock_update:
            with patch.object(widget, 'save_progress_report') as mock_save:
                with patch.object(widget, 'check_escalation_criteria') as mock_check:
                    
                    widget.on_progress_collected(test_data)
                    
                    # Check all methods were called
                    mock_update.assert_called_once_with(test_data)
                    mock_save.assert_called_once_with(test_data)
                    mock_check.assert_called_once_with(test_data)
                    
                    # Check progress_data was stored
                    assert widget.progress_data == test_data

    def test_on_collection_error(self, widget, qtbot):
        """進捗収集エラー処理テスト"""
        error_message = "テスト用エラーメッセージ"
        
        widget.on_collection_error(error_message)
        
        # Check alert text was updated
        assert error_message in widget.alert_text.toPlainText()

    def test_update_metrics_table(self, widget):
        """メトリクステーブル更新テスト"""
        test_metrics = {
            "gui_components_completed": 18,
            "pyqt6_coverage": 91.2,
            "ui_consistency_score": 95,
            "tab_implementation": {"定期レポート": True, "分析レポート": True},
            "widget_integration": {"log_viewer": 100.0, "progress_monitor": 95.0},
            "performance_metrics": {
                "startup_time": 2.1,
                "memory_usage": 45.2,
                "ui_responsiveness": 98.5,
                "api_response_time": 1.3
            }
        }
        
        widget.update_metrics_table(test_metrics)
        
        # Check table has correct number of rows
        assert widget.metrics_table.rowCount() == 9
        
        # Check some specific values
        for row in range(widget.metrics_table.rowCount()):
            metric_item = widget.metrics_table.item(row, 0)
            value_item = widget.metrics_table.item(row, 1)
            
            assert metric_item is not None
            assert value_item is not None
            assert metric_item.text() != ""
            assert value_item.text() != ""

    def test_update_history_log(self, widget):
        """履歴ログ更新テスト"""
        test_data = {
            "timestamp": datetime.now().isoformat(),
            "developer": "frontend",
            "metrics": {
                "gui_components_completed": 18,
                "pyqt6_coverage": 91.2,
                "ui_consistency_score": 95
            }
        }
        
        # Initial state
        initial_text = widget.history_text.toPlainText()
        
        widget.update_history_log(test_data)
        
        # Check new entry was added
        current_text = widget.history_text.toPlainText()
        assert len(current_text) > len(initial_text)
        assert "GUI: 18/26" in current_text
        assert "カバレッジ: 91.2%" in current_text


# Helper functions for mocking
def mock_open_main_window_content():
    """main_window.py のコンテンツをモック"""
    content = """
    def _create_function_button(self, text, action):
        button = QPushButton(text)
        return button
    
    def _create_function_button(self, text, action):
        button = QPushButton(text)
        return button
    """ * 13  # 26 buttons
    
    from unittest.mock import mock_open
    return mock_open(read_data=content)


if __name__ == "__main__":
    import sys
    from PyQt6.QtWidgets import QApplication
    
    app = QApplication(sys.argv)
    pytest.main([__file__, "-v"])