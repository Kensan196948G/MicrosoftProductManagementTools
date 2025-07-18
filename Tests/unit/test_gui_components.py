"""
GUI機能のpytest-qt基盤テスト
Dev1 - Test/QA Developer による基盤構築

PyQt6基盤のGUIコンポーネントの単体テスト
"""
import sys
import os
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock
from typing import List, Dict, Any
import asyncio

import pytest
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QPushButton, QVBoxLayout, 
    QHBoxLayout, QTextEdit, QLabel, QProgressBar, QMessageBox,
    QScrollArea, QFrame
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QThread, QObject
from PyQt6.QtGui import QFont, QPalette, QColor
from PyQt6.QtTest import QTest

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))


class MockMainWindow(QMainWindow):
    """テスト用のメインウィンドウモック"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Microsoft 365管理ツール - テスト版")
        self.setGeometry(100, 100, 1200, 800)
        
        # 中央ウィジェット
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # メインレイアウト
        main_layout = QVBoxLayout(central_widget)
        
        # ヘッダー
        self.header_label = QLabel("Microsoft 365管理ツール - Python版")
        self.header_label.setStyleSheet("font-size: 18px; font-weight: bold; color: #2E8B57;")
        main_layout.addWidget(self.header_label)
        
        # スクロール可能エリア
        scroll_area = QScrollArea()
        scroll_widget = QWidget()
        self.scroll_layout = QVBoxLayout(scroll_widget)
        
        # 26機能ボタンをセクション別に配置
        self.create_button_sections()
        
        scroll_area.setWidget(scroll_widget)
        scroll_area.setWidgetResizable(True)
        main_layout.addWidget(scroll_area)
        
        # ログパネル
        self.log_panel = QTextEdit()
        self.log_panel.setMaximumHeight(200)
        self.log_panel.setStyleSheet("background-color: #f0f0f0; font-family: 'Consolas', 'Monaco', monospace;")
        main_layout.addWidget(QLabel("実行ログ:"))
        main_layout.addWidget(self.log_panel)
        
        # プログレスバー
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        main_layout.addWidget(self.progress_bar)
        
        # ボタン実行カウンター
        self.button_click_count = 0
        self.last_clicked_button = None
    
    def create_button_sections(self):
        """26機能ボタンをセクション別に作成"""
        sections = [
            ("📊 定期レポート", [
                "日次レポート", "週次レポート", "月次レポート", "年次レポート", "テスト実行"
            ]),
            ("🔍 分析レポート", [
                "ライセンス分析", "使用状況分析", "パフォーマンス監視", "セキュリティ分析", "権限監査"
            ]),
            ("👥 Entra ID管理", [
                "ユーザー一覧", "MFA状況", "条件付きアクセス", "サインインログ"
            ]),
            ("📧 Exchange Online管理", [
                "メールボックス管理", "メールフロー分析", "スパム対策分析", "配信分析"
            ]),
            ("💬 Teams管理", [
                "Teams使用状況", "Teams設定分析", "会議品質分析", "Teamsアプリ分析"
            ]),
            ("💾 OneDrive管理", [
                "ストレージ分析", "共有分析", "同期エラー分析", "外部共有分析"
            ])
        ]
        
        self.buttons = {}
        
        for section_title, button_names in sections:
            # セクションフレーム
            section_frame = QFrame()
            section_frame.setFrameStyle(QFrame.Shape.Box)
            section_frame.setStyleSheet("QFrame { border: 1px solid #cccccc; margin: 5px; }")
            section_layout = QVBoxLayout(section_frame)
            
            # セクションタイトル
            section_label = QLabel(section_title)
            section_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #333333; margin: 5px;")
            section_layout.addWidget(section_label)
            
            # ボタングリッド
            button_layout = QHBoxLayout()
            for button_name in button_names:
                button = QPushButton(button_name)
                button.setMinimumHeight(40)
                button.setStyleSheet("""
                    QPushButton {
                        background-color: #4CAF50;
                        color: white;
                        border: none;
                        padding: 8px;
                        font-size: 12px;
                        border-radius: 4px;
                    }
                    QPushButton:hover {
                        background-color: #45a049;
                    }
                    QPushButton:pressed {
                        background-color: #3d8b40;
                    }
                """)
                
                # ボタンクリックイベント
                button.clicked.connect(lambda checked, name=button_name: self.on_button_clicked(name))
                
                button_layout.addWidget(button)
                self.buttons[button_name] = button
            
            section_layout.addLayout(button_layout)
            self.scroll_layout.addWidget(section_frame)
    
    def on_button_clicked(self, button_name: str):
        """ボタンクリック処理"""
        self.button_click_count += 1
        self.last_clicked_button = button_name
        
        # ログ出力
        self.write_log(f"INFO", f"機能実行開始: {button_name}")
        
        # プログレスバー表示
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(0)
        
        # 模擬処理実行
        QTimer.singleShot(100, lambda: self.simulate_processing(button_name))
    
    def simulate_processing(self, button_name: str):
        """処理シミュレーション"""
        self.progress_bar.setValue(50)
        self.write_log("SUCCESS", f"機能実行完了: {button_name}")
        
        QTimer.singleShot(100, lambda: self.complete_processing(button_name))
    
    def complete_processing(self, button_name: str):
        """処理完了"""
        self.progress_bar.setValue(100)
        self.progress_bar.setVisible(False)
        self.write_log("INFO", f"レポート生成完了: {button_name}")
    
    def write_log(self, level: str, message: str):
        """ログ出力"""
        import datetime
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {level}: {message}"
        self.log_panel.append(log_entry)
    
    def get_button_count(self) -> int:
        """ボタン数を取得"""
        return len(self.buttons)
    
    def get_button_names(self) -> List[str]:
        """ボタン名リストを取得"""
        return list(self.buttons.keys())


class MockLogViewer(QWidget):
    """ログビューアーのモック"""
    
    def __init__(self):
        super().__init__()
        layout = QVBoxLayout()
        
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setStyleSheet("""
            QTextEdit {
                background-color: #2b2b2b;
                color: #ffffff;
                font-family: 'Consolas', 'Monaco', monospace;
                font-size: 10px;
            }
        """)
        
        layout.addWidget(QLabel("リアルタイムログ"))
        layout.addWidget(self.log_text)
        self.setLayout(layout)
        
        self.log_entries = []
    
    def add_log_entry(self, level: str, message: str, timestamp: str = None):
        """ログエントリ追加"""
        if timestamp is None:
            import datetime
            timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        entry = f"[{timestamp}] {level}: {message}"
        self.log_entries.append(entry)
        self.log_text.append(entry)
    
    def clear_logs(self):
        """ログクリア"""
        self.log_entries.clear()
        self.log_text.clear()
    
    def get_log_count(self) -> int:
        """ログエントリ数取得"""
        return len(self.log_entries)


@pytest.fixture(scope="function")
def mock_main_window(qtbot):
    """メインウィンドウモックのフィクスチャ"""
    window = MockMainWindow()
    qtbot.addWidget(window)
    return window


@pytest.fixture(scope="function")
def mock_log_viewer(qtbot):
    """ログビューアーモックのフィクスチャ"""
    viewer = MockLogViewer()
    qtbot.addWidget(viewer)
    return viewer


class TestMainWindowGUI:
    """メインウィンドウGUIテスト"""
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_main_window_initialization(self, mock_main_window):
        """メインウィンドウ初期化テスト"""
        assert mock_main_window.windowTitle() == "Microsoft 365管理ツール - テスト版"
        assert mock_main_window.isVisible() == False  # 初期状態では非表示
        assert mock_main_window.get_button_count() == 26  # 26機能ボタン
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_button_layout_structure(self, mock_main_window):
        """ボタンレイアウト構造テスト"""
        expected_buttons = [
            # 定期レポート
            "日次レポート", "週次レポート", "月次レポート", "年次レポート", "テスト実行",
            # 分析レポート
            "ライセンス分析", "使用状況分析", "パフォーマンス監視", "セキュリティ分析", "権限監査",
            # Entra ID管理
            "ユーザー一覧", "MFA状況", "条件付きアクセス", "サインインログ",
            # Exchange Online管理
            "メールボックス管理", "メールフロー分析", "スパム対策分析", "配信分析",
            # Teams管理
            "Teams使用状況", "Teams設定分析", "会議品質分析", "Teamsアプリ分析",
            # OneDrive管理
            "ストレージ分析", "共有分析", "同期エラー分析", "外部共有分析"
        ]
        
        actual_buttons = mock_main_window.get_button_names()
        
        assert len(actual_buttons) == 26, f"期待されるボタン数: 26, 実際: {len(actual_buttons)}"
        
        for expected_button in expected_buttons:
            assert expected_button in actual_buttons, f"ボタンが見つかりません: {expected_button}"
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_button_click_functionality(self, mock_main_window, qtbot):
        """ボタンクリック機能テスト"""
        # 初期状態確認
        assert mock_main_window.button_click_count == 0
        assert mock_main_window.last_clicked_button is None
        
        # 日次レポートボタンクリック
        daily_button = mock_main_window.buttons["日次レポート"]
        qtbot.mouseClick(daily_button, Qt.MouseButton.LeftButton)
        
        # クリック結果確認
        assert mock_main_window.button_click_count == 1
        assert mock_main_window.last_clicked_button == "日次レポート"
        
        # ライセンス分析ボタンクリック
        license_button = mock_main_window.buttons["ライセンス分析"]
        qtbot.mouseClick(license_button, Qt.MouseButton.LeftButton)
        
        assert mock_main_window.button_click_count == 2
        assert mock_main_window.last_clicked_button == "ライセンス分析"
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_progress_bar_functionality(self, mock_main_window, qtbot):
        """プログレスバー機能テスト"""
        # 初期状態ではプログレスバーは非表示
        assert mock_main_window.progress_bar.isVisible() == False
        
        # ボタンクリックでプログレスバー表示
        button = mock_main_window.buttons["使用状況分析"]
        qtbot.mouseClick(button, Qt.MouseButton.LeftButton)
        
        # 少し待機してプログレスバーの状態確認
        qtbot.wait(150)  # 処理完了まで待機
        
        # プログレスバーの状態確認（処理完了後は非表示になる）
        assert mock_main_window.progress_bar.value() >= 0
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_log_panel_functionality(self, mock_main_window, qtbot):
        """ログパネル機能テスト"""
        initial_log_content = mock_main_window.log_panel.toPlainText()
        
        # ボタンクリックでログ出力
        button = mock_main_window.buttons["MFA状況"]
        qtbot.mouseClick(button, Qt.MouseButton.LeftButton)
        
        # ログ内容変化の確認
        qtbot.wait(100)
        updated_log_content = mock_main_window.log_panel.toPlainText()
        
        assert len(updated_log_content) > len(initial_log_content)
        assert "MFA状況" in updated_log_content
        assert "INFO:" in updated_log_content or "SUCCESS:" in updated_log_content
    
    @pytest.mark.gui
    @pytest.mark.integration
    def test_window_resizing(self, mock_main_window, qtbot):
        """ウィンドウリサイズテスト"""
        # 初期サイズ確認
        initial_size = mock_main_window.size()
        assert initial_size.width() == 1200
        assert initial_size.height() == 800
        
        # ウィンドウリサイズ
        mock_main_window.resize(800, 600)
        qtbot.wait(50)
        
        new_size = mock_main_window.size()
        assert new_size.width() == 800
        assert new_size.height() == 600
        
        # ボタンがリサイズ後も機能するか確認
        button = mock_main_window.buttons["Teams使用状況"]
        qtbot.mouseClick(button, Qt.MouseButton.LeftButton)
        
        assert mock_main_window.last_clicked_button == "Teams使用状況"


class TestLogViewerGUI:
    """ログビューアーGUIテスト"""
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_log_viewer_initialization(self, mock_log_viewer):
        """ログビューアー初期化テスト"""
        assert mock_log_viewer.get_log_count() == 0
        assert mock_log_viewer.log_text.isReadOnly() == True
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_log_entry_addition(self, mock_log_viewer):
        """ログエントリ追加テスト"""
        # 単一ログエントリ追加
        mock_log_viewer.add_log_entry("INFO", "テストメッセージ1")
        assert mock_log_viewer.get_log_count() == 1
        
        # 複数ログエントリ追加
        mock_log_viewer.add_log_entry("WARNING", "テスト警告メッセージ")
        mock_log_viewer.add_log_entry("ERROR", "テストエラーメッセージ")
        assert mock_log_viewer.get_log_count() == 3
        
        # ログ内容確認
        log_content = mock_log_viewer.log_text.toPlainText()
        assert "INFO: テストメッセージ1" in log_content
        assert "WARNING: テスト警告メッセージ" in log_content
        assert "ERROR: テストエラーメッセージ" in log_content
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_log_clearing(self, mock_log_viewer):
        """ログクリア機能テスト"""
        # ログエントリ追加
        mock_log_viewer.add_log_entry("INFO", "削除されるメッセージ1")
        mock_log_viewer.add_log_entry("DEBUG", "削除されるメッセージ2")
        assert mock_log_viewer.get_log_count() == 2
        
        # ログクリア
        mock_log_viewer.clear_logs()
        assert mock_log_viewer.get_log_count() == 0
        assert mock_log_viewer.log_text.toPlainText() == ""
    
    @pytest.mark.gui
    @pytest.mark.performance
    def test_large_log_performance(self, mock_log_viewer):
        """大量ログのパフォーマンステスト"""
        import time
        
        # 大量ログエントリ追加（1000件）
        start_time = time.time()
        
        for i in range(1000):
            mock_log_viewer.add_log_entry("INFO", f"大量ログテスト {i:04d}")
        
        end_time = time.time()
        processing_time = end_time - start_time
        
        assert mock_log_viewer.get_log_count() == 1000
        assert processing_time < 5.0, f"大量ログ処理が遅すぎます: {processing_time}秒"
        
        # ログクリアのパフォーマンス
        clear_start = time.time()
        mock_log_viewer.clear_logs()
        clear_end = time.time()
        clear_time = clear_end - clear_start
        
        assert clear_time < 1.0, f"ログクリアが遅すぎます: {clear_time}秒"


class TestGUIInteraction:
    """GUI相互作用テスト"""
    
    @pytest.mark.gui
    @pytest.mark.integration
    def test_main_window_log_viewer_integration(self, mock_main_window, mock_log_viewer, qtbot):
        """メインウィンドウとログビューアーの統合テスト"""
        # 初期状態確認
        assert mock_main_window.get_button_count() == 26
        assert mock_log_viewer.get_log_count() == 0
        
        # メインウィンドウでボタンクリック
        button = mock_main_window.buttons["パフォーマンス監視"]
        qtbot.mouseClick(button, Qt.MouseButton.LeftButton)
        
        # メインウィンドウのログをログビューアーに転送（統合処理の模擬）
        main_log_content = mock_main_window.log_panel.toPlainText()
        if main_log_content:
            log_lines = main_log_content.strip().split('\n')
            for line in log_lines:
                if line.strip():
                    # ログレベルとメッセージを抽出
                    if "INFO:" in line:
                        parts = line.split("INFO:", 1)
                        if len(parts) == 2:
                            mock_log_viewer.add_log_entry("INFO", parts[1].strip())
                    elif "SUCCESS:" in line:
                        parts = line.split("SUCCESS:", 1)
                        if len(parts) == 2:
                            mock_log_viewer.add_log_entry("SUCCESS", parts[1].strip())
        
        # 統合結果確認
        assert mock_log_viewer.get_log_count() > 0
        assert "パフォーマンス監視" in mock_log_viewer.log_text.toPlainText()


class TestGUIErrorHandling:
    """GUIエラーハンドリングテスト"""
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_button_rapid_clicking(self, mock_main_window, qtbot):
        """ボタン連打処理テスト"""
        button = mock_main_window.buttons["セキュリティ分析"]
        
        # 高速連続クリック
        for _ in range(10):
            qtbot.mouseClick(button, Qt.MouseButton.LeftButton)
            qtbot.wait(10)  # 短い間隔
        
        # 連続クリックが適切に処理されるか確認
        assert mock_main_window.button_click_count >= 10
        assert mock_main_window.last_clicked_button == "セキュリティ分析"
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_widget_destruction_safety(self, qtbot):
        """ウィジェット破棄時の安全性テスト"""
        # 一時的なウィンドウ作成
        temp_window = MockMainWindow()
        qtbot.addWidget(temp_window)
        
        # ボタンクリック
        button = temp_window.buttons["権限監査"]
        qtbot.mouseClick(button, Qt.MouseButton.LeftButton)
        
        # ウィンドウ破棄
        temp_window.close()
        temp_window = None
        
        # エラーが発生しないことを確認（暗黙的テスト）
        qtbot.wait(100)


class TestGUIStyleAndLayout:
    """GUIスタイル・レイアウトテスト"""
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_button_styling(self, mock_main_window):
        """ボタンスタイリングテスト"""
        for button_name, button in mock_main_window.buttons.items():
            # ボタンサイズ確認
            assert button.minimumHeight() == 40, f"ボタン高さが正しくありません: {button_name}"
            
            # スタイルシート設定確認
            style_sheet = button.styleSheet()
            assert "background-color" in style_sheet, f"背景色が設定されていません: {button_name}"
            assert "color" in style_sheet, f"文字色が設定されていません: {button_name}"
    
    @pytest.mark.gui
    @pytest.mark.unit
    def test_window_minimum_size(self, mock_main_window):
        """ウィンドウ最小サイズテスト"""
        # 極小サイズに変更してみる
        mock_main_window.resize(300, 200)
        
        # ウィジェットが適切に表示されるか確認
        assert mock_main_window.size().width() >= 300
        assert mock_main_window.size().height() >= 200
        
        # 重要なウィジェットが見えるか確認
        assert mock_main_window.header_label.isVisible()
        assert mock_main_window.log_panel.isVisible()


@pytest.mark.gui
@pytest.mark.slow
class TestGUIPerformance:
    """GUIパフォーマンステスト"""
    
    def test_window_startup_time(self, qtbot):
        """ウィンドウ起動時間テスト"""
        import time
        
        start_time = time.time()
        window = MockMainWindow()
        qtbot.addWidget(window)
        window.show()
        qtbot.wait(100)  # UI更新待機
        end_time = time.time()
        
        startup_time = end_time - start_time
        assert startup_time < 2.0, f"ウィンドウ起動時間が遅すぎます: {startup_time}秒"
    
    def test_button_response_time(self, mock_main_window, qtbot):
        """ボタン応答時間テスト"""
        import time
        
        button = mock_main_window.buttons["年次レポート"]
        
        start_time = time.time()
        qtbot.mouseClick(button, Qt.MouseButton.LeftButton)
        # クリック処理完了まで待機
        qtbot.wait(50)
        end_time = time.time()
        
        response_time = end_time - start_time
        assert response_time < 1.0, f"ボタン応答時間が遅すぎます: {response_time}秒"