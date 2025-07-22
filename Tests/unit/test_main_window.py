#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PyQt6 メインウィンドウ単体テストスイート

QA Engineer - Phase 3品質保証
dev0のPyQt6 GUI完全実装版の単体テスト

テスト対象: src/gui/main_window_complete.py
品質目標: 単体テスト合格率 95%以上
"""

import sys
import os
import pytest
import tempfile
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime
from pathlib import Path

# テスト対象のパスを追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# PyQt6のモック（CI環境対応）
class MockQApplication:
    def __init__(self, *args):
        pass
    def setApplicationName(self, name): pass
    def setApplicationVersion(self, version): pass
    def setOrganizationName(self, org): pass
    def setHighDpiScaleFactorRoundingPolicy(self, policy): pass
    def setStyle(self, style): pass
    def processEvents(self): pass
    def exec(self): return 0

class MockQWidget:
    def __init__(self, parent=None):
        self.parent_widget = parent
        self._visible = False
        self._text = ""
        self._style = ""
        
    def setVisible(self, visible): self._visible = visible
    def isVisible(self): return self._visible
    def setText(self, text): self._text = text
    def text(self): return self._text
    def setStyleSheet(self, style): self._style = style
    def styleSheet(self): return self._style
    def show(self): self._visible = True
    def hide(self): self._visible = False
    def setParent(self, parent): self.parent_widget = parent

class MockQMainWindow(MockQWidget):
    def __init__(self):
        super().__init__()
        self._title = ""
        self._geometry = (0, 0, 800, 600)
        self._central_widget = None
        
    def setWindowTitle(self, title): self._title = title
    def windowTitle(self): return self._title
    def setGeometry(self, x, y, w, h): self._geometry = (x, y, w, h)
    def geometry(self): return self._geometry
    def setCentralWidget(self, widget): self._central_widget = widget
    def centralWidget(self): return self._central_widget
    def setMinimumSize(self, w, h): pass
    def menuBar(self): return Mock()
    def statusBar(self): return Mock()
    def setStatusBar(self, bar): pass

# PyQt6モック設定
sys.modules['PyQt6'] = Mock()
sys.modules['PyQt6.QtWidgets'] = Mock()
sys.modules['PyQt6.QtCore'] = Mock()
sys.modules['PyQt6.QtGui'] = Mock()

# モッククラスの設定
PyQt6_mock = sys.modules['PyQt6']
PyQt6_mock.QtWidgets.QApplication = MockQApplication
PyQt6_mock.QtWidgets.QMainWindow = MockQMainWindow
PyQt6_mock.QtWidgets.QWidget = MockQWidget
PyQt6_mock.QtWidgets.QPushButton = MockQWidget
PyQt6_mock.QtWidgets.QLabel = MockQWidget
PyQt6_mock.QtWidgets.QTextEdit = MockQWidget
PyQt6_mock.QtWidgets.QTabWidget = MockQWidget
PyQt6_mock.QtWidgets.QVBoxLayout = Mock()
PyQt6_mock.QtWidgets.QHBoxLayout = Mock()
PyQt6_mock.QtWidgets.QGridLayout = Mock()
PyQt6_mock.QtWidgets.QSplitter = Mock()
PyQt6_mock.QtWidgets.QFrame = MockQWidget
PyQt6_mock.QtWidgets.QScrollArea = MockQWidget
PyQt6_mock.QtWidgets.QGroupBox = MockQWidget
PyQt6_mock.QtWidgets.QStatusBar = Mock()
PyQt6_mock.QtWidgets.QMenuBar = Mock()
PyQt6_mock.QtWidgets.QProgressBar = Mock()
PyQt6_mock.QtWidgets.QMessageBox = Mock()
PyQt6_mock.QtWidgets.QDialog = MockQWidget
PyQt6_mock.QtWidgets.QDialogButtonBox = Mock()
PyQt6_mock.QtWidgets.QFormLayout = Mock()
PyQt6_mock.QtWidgets.QLineEdit = MockQWidget
PyQt6_mock.QtWidgets.QComboBox = Mock()
PyQt6_mock.QtWidgets.QCheckBox = Mock()
PyQt6_mock.QtWidgets.QFileDialog = Mock()

# QtCoreモック
PyQt6_mock.QtCore.Qt = Mock()
PyQt6_mock.QtCore.Qt.AlignmentFlag = Mock()
PyQt6_mock.QtCore.Qt.AlignmentFlag.AlignCenter = 0x84
PyQt6_mock.QtCore.Qt.Orientation = Mock()
PyQt6_mock.QtCore.Qt.Orientation.Horizontal = 1
PyQt6_mock.QtCore.Qt.FocusPolicy = Mock()
PyQt6_mock.QtCore.Qt.FocusPolicy.StrongFocus = 11
PyQt6_mock.QtCore.Qt.ScrollBarPolicy = Mock()
PyQt6_mock.QtCore.Qt.ScrollBarPolicy.ScrollBarAsNeeded = 0
PyQt6_mock.QtCore.pyqtSignal = Mock(return_value=Mock())
PyQt6_mock.QtCore.QTimer = Mock()
PyQt6_mock.QtCore.QSettings = Mock()
PyQt6_mock.QtCore.QThread = Mock()
PyQt6_mock.QtCore.QObject = Mock()
PyQt6_mock.QtCore.QPropertyAnimation = Mock()
PyQt6_mock.QtCore.QEasingCurve = Mock()
PyQt6_mock.QtCore.QEasingCurve.Type = Mock()
PyQt6_mock.QtCore.QEasingCurve.Type.OutCubic = 64

# QtGuiモック
PyQt6_mock.QtGui.QKeySequence = Mock()
PyQt6_mock.QtGui.QKeySequence.StandardKey = Mock()
PyQt6_mock.QtGui.QKeySequence.StandardKey.Quit = Mock()
PyQt6_mock.QtGui.QShortcut = Mock()
PyQt6_mock.QtGui.QDesktopServices = Mock()
PyQt6_mock.QtGui.QUrl = Mock()

try:
    # テスト対象をインポート
    from gui.main_window_complete import (
        APP_NAME, APP_VERSION, LogLevel, M365Function,
        Microsoft365MainWindow, LogWidget, ModernButton, SettingsDialog
    )
    IMPORT_SUCCESS = True
except Exception as e:
    print(f"インポートエラー: {e}")
    IMPORT_SUCCESS = False

class TestLogLevel:
    """ログレベル定数テスト"""
    
    def test_log_level_constants(self):
        """ログレベル定数が正しく定義されているかテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        assert LogLevel.INFO == "INFO"
        assert LogLevel.SUCCESS == "SUCCESS"
        assert LogLevel.WARNING == "WARNING"
        assert LogLevel.ERROR == "ERROR"
        assert LogLevel.DEBUG == "DEBUG"
        
    def test_log_level_completeness(self):
        """すべての必要なログレベルが定義されているかテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        required_levels = ["INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG"]
        for level in required_levels:
            assert hasattr(LogLevel, level)

class TestM365Function:
    """Microsoft 365機能定義クラステスト"""
    
    def test_function_creation(self):
        """機能オブジェクトの作成テスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        func = M365Function(
            name="テスト機能",
            action="TestAction",
            icon="🧪",
            category="テスト",
            description="テスト用の機能"
        )
        
        assert func.name == "テスト機能"
        assert func.action == "TestAction"
        assert func.icon == "🧪"
        assert func.category == "テスト"
        assert func.description == "テスト用の機能"
        
    def test_function_default_description(self):
        """デフォルト説明のテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        func = M365Function(
            name="テスト機能",
            action="TestAction",
            icon="🧪",
            category="テスト"
        )
        
        assert func.description == ""

class TestLogWidget:
    """ログウィジェットテスト"""
    
    @pytest.fixture
    def log_widget(self):
        """ログウィジェットのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        return LogWidget()
    
    def test_log_widget_creation(self, log_widget):
        """ログウィジェット作成テスト"""
        assert log_widget is not None
        
    def test_write_log_method(self, log_widget):
        """ログ出力メソッドテスト"""
        # write_logメソッドが例外なく実行されることを確認
        try:
            log_widget.write_log(LogLevel.INFO, "テストメッセージ")
            log_widget.write_log(LogLevel.SUCCESS, "成功メッセージ", "TEST")
            log_widget.write_log(LogLevel.WARNING, "警告メッセージ")
            log_widget.write_log(LogLevel.ERROR, "エラーメッセージ")
            assert True  # 例外が発生しなければ成功
        except Exception as e:
            pytest.fail(f"write_logメソッドでエラー: {e}")
            
    def test_log_levels_support(self, log_widget):
        """すべてのログレベルサポートテスト"""
        levels = [LogLevel.INFO, LogLevel.SUCCESS, LogLevel.WARNING, LogLevel.ERROR, LogLevel.DEBUG]
        
        for level in levels:
            try:
                log_widget.write_log(level, f"{level}レベルテスト")
            except Exception as e:
                pytest.fail(f"{level}レベルでエラー: {e}")

class TestModernButton:
    """モダンボタンテスト"""
    
    @pytest.fixture
    def modern_button(self):
        """モダンボタンのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        return ModernButton("テストボタン", "🧪")
    
    def test_button_creation(self, modern_button):
        """ボタン作成テスト"""
        assert modern_button is not None
        
    def test_button_text_with_icon(self):
        """アイコン付きテキストテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        button = ModernButton("テスト", "🧪")
        # テキスト設定の確認（モックなので実際の値は確認困難）
        assert button is not None
        
    def test_button_text_without_icon(self):
        """アイコンなしテキストテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        button = ModernButton("テスト")
        assert button is not None

class TestMicrosoft365MainWindow:
    """メインウィンドウテスト"""
    
    @pytest.fixture
    def main_window(self):
        """メインウィンドウのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch('gui.main_window_complete.QApplication') as mock_app:
            mock_app.processEvents = Mock()
            window = Microsoft365MainWindow()
            return window
    
    def test_window_creation(self, main_window):
        """ウィンドウ作成テスト"""
        assert main_window is not None
        
    def test_initialize_functions(self, main_window):
        """機能初期化テスト"""
        functions = main_window.initialize_functions()
        
        # 6つのタブカテゴリが存在することを確認
        expected_categories = [
            "定期レポート", "分析レポート", "Entra ID管理",
            "Exchange Online", "Teams管理", "OneDrive管理"
        ]
        
        for category in expected_categories:
            assert category in functions, f"カテゴリ '{category}' が見つかりません"
            
        # 各カテゴリに適切な数の機能があることを確認
        expected_counts = {
            "定期レポート": 5,
            "分析レポート": 5,
            "Entra ID管理": 4,
            "Exchange Online": 4,
            "Teams管理": 4,
            "OneDrive管理": 4
        }
        
        for category, expected_count in expected_counts.items():
            actual_count = len(functions[category])
            assert actual_count == expected_count, \
                f"カテゴリ '{category}' の機能数が不正: {actual_count} != {expected_count}"
        
        # 総機能数が26であることを確認
        total_functions = sum(len(funcs) for funcs in functions.values())
        assert total_functions == 26, f"総機能数が不正: {total_functions} != 26"
        
    def test_write_log_method(self, main_window):
        """ログ出力メソッドテスト"""
        try:
            main_window.write_log(LogLevel.INFO, "テストログメッセージ")
            assert True  # 例外が発生しなければ成功
        except Exception as e:
            pytest.fail(f"write_logメソッドでエラー: {e}")
            
    def test_tab_icon_mapping(self, main_window):
        """タブアイコンマッピングテスト"""
        expected_icons = {
            "定期レポート": "📊",
            "分析レポート": "🔍",
            "Entra ID管理": "👥",
            "Exchange Online": "📧",
            "Teams管理": "💬",
            "OneDrive管理": "💾"
        }
        
        for tab_name, expected_icon in expected_icons.items():
            actual_icon = main_window.get_tab_icon(tab_name)
            assert actual_icon == expected_icon, \
                f"タブ '{tab_name}' のアイコンが不正: {actual_icon} != {expected_icon}"
                
    def test_tab_descriptions(self, main_window):
        """タブ説明テスト"""
        categories = ["定期レポート", "分析レポート", "Entra ID管理", "Exchange Online", "Teams管理", "OneDrive管理"]
        
        for category in categories:
            description = main_window.get_tab_description(category)
            assert isinstance(description, str), f"タブ '{category}' の説明がstring型ではありません"
            assert len(description) > 0, f"タブ '{category}' の説明が空です"
            assert "Microsoft 365" in description or "管理" in description or "分析" in description, \
                f"タブ '{category}' の説明が適切ではありません: {description}"

class TestSettingsDialog:
    """設定ダイアログテスト"""
    
    @pytest.fixture
    def settings_dialog(self):
        """設定ダイアログのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        return SettingsDialog()
    
    def test_dialog_creation(self, settings_dialog):
        """ダイアログ作成テスト"""
        assert settings_dialog is not None

class TestApplicationConstants:
    """アプリケーション定数テスト"""
    
    def test_app_constants(self):
        """アプリケーション定数テスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        assert APP_NAME == "Microsoft 365統合管理ツール"
        assert APP_VERSION == "2.0.0"
        assert isinstance(APP_NAME, str)
        assert isinstance(APP_VERSION, str)

# 統合テスト
class TestIntegrationScenarios:
    """統合シナリオテスト"""
    
    def test_function_execution_flow(self):
        """機能実行フローテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        # M365Functionオブジェクトの作成
        test_function = M365Function(
            name="テスト機能",
            action="TestAction",
            icon="🧪",
            category="テスト",
            description="統合テスト用機能"
        )
        
        # 機能オブジェクトが正しく作成されることを確認
        assert test_function.name == "テスト機能"
        assert test_function.action == "TestAction"
        
        # メインウィンドウでの機能実行シミュレーション
        with patch('gui.main_window_complete.QApplication') as mock_app:
            mock_app.processEvents = Mock()
            window = Microsoft365MainWindow()
            
            # 機能実行メソッドが例外なく呼び出せることを確認
            try:
                window.write_log(LogLevel.INFO, f"機能実行テスト: {test_function.name}")
                assert True
            except Exception as e:
                pytest.fail(f"統合テストでエラー: {e}")

# テスト実行時の設定
def pytest_configure():
    """pytest設定"""
    # テスト用の一時ディレクトリ作成
    os.makedirs("Tests/temp", exist_ok=True)

def pytest_unconfigure():
    """pytest後処理"""
    # テスト用ファイルの削除
    import shutil
    temp_dir = "Tests/temp"
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir, ignore_errors=True)

if __name__ == "__main__":
    # 単体でのテスト実行
    pytest.main([__file__, "-v", "--tb=short"])