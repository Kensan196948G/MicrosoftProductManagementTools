#!/usr/bin/env python3
"""
Microsoft 365統合管理ツール - PyQt6 メインウィンドウ

PowerShell版の26機能を完全再現するPyQt6ベースのGUIアプリケーション
- 6セクション×26機能ボタン完全対応
- リアルタイムログ表示（Write-GuiLog互換）  
- Microsoft 365 API統合
- エンタープライズグレードUI/UX

Author: Frontend Developer (dev0)
Version: 3.0.0
Date: 2025-07-19
"""

import sys
import json
import asyncio
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from enum import Enum

try:
    from PyQt6.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
        QGridLayout, QPushButton, QTabWidget, QTextEdit, QLineEdit,
        QLabel, QStatusBar, QMenuBar, QToolBar, QSplitter, QFrame,
        QProgressBar, QMessageBox, QFileDialog, QCheckBox, QComboBox,
        QGroupBox, QScrollArea
    )
    from PyQt6.QtCore import (
        Qt, QThread, QTimer, QObject, pyqtSignal, pyqtSlot,
        QSize, QRect, QPropertyAnimation, QEasingCurve
    )
    from PyQt6.QtGui import (
        QFont, QIcon, QPixmap, QAction, QTextCursor, 
        QPalette, QColor, QBrush, QLinearGradient
    )
except ImportError:
    print("❌ PyQt6がインストールされていません")
    print("インストール: pip install PyQt6")
    sys.exit(1)

# ローカルインポート（実装後に有効化）
# from .components.log_viewer import GuiLogger, LogViewer, GuiLogLevel
# from .components.report_buttons import ReportButtonManager
# from ..api.microsoft_graph_client import Microsoft365AuthManager, Microsoft365DataService
# from ..core.config import ConfigManager


class GuiLogLevel(Enum):
    """ログレベル定義（PowerShell版互換）"""
    INFO = ("ℹ️", "#0078d4")      # 青色情報
    SUCCESS = ("✅", "#107c10")   # 緑色成功
    WARNING = ("⚠️", "#ff8c00")   # オレンジ警告  
    ERROR = ("❌", "#d13438")     # 赤色エラー
    DEBUG = ("🔍", "#5c2d91")     # 紫色デバッグ


class Microsoft365ManagementMainWindow(QMainWindow):
    """
    Microsoft 365統合管理ツール メインウィンドウ
    
    PowerShell版GuiApp_Enhanced.ps1の全機能をPyQt6で完全再現:
    - 26機能ボタン（6セクション構成）
    - リアルタイムログ表示
    - Microsoft 365 API統合
    - レスポンシブデザイン・アクセシビリティ対応
    """
    
    # カスタムシグナル
    report_generated = pyqtSignal(str, str)  # csv_path, html_path
    auth_status_changed = pyqtSignal(bool, str)  # connected, message
    log_message = pyqtSignal(str, str, str)  # message, level, timestamp
    
    def __init__(self):
        super().__init__()
        
        # インスタンス変数初期化
        self.current_operations = []
        self.auth_manager = None
        self.data_service = None
        self.config_manager = None
        self.logger = None
        
        # GUI初期化
        self.init_ui()
        self.setup_styling()
        self.setup_connections()
        self.setup_keyboard_shortcuts()
        
        # 初期ログメッセージ
        self.write_gui_log("Microsoft 365統合管理ツール Python版を起動しました", GuiLogLevel.SUCCESS)
        
    def init_ui(self):
        """UI初期化・レイアウト構築"""
        
        # ウィンドウ基本設定
        self.setWindowTitle("Microsoft 365統合管理ツール Python版 v3.0")
        self.setGeometry(100, 100, 1450, 950)
        self.setMinimumSize(1200, 800)
        
        # アイコン設定（リソースファイルが利用可能な場合）
        try:
            self.setWindowIcon(QIcon("resources/icons/ms365_icon.png"))
        except:
            pass  # アイコンファイルが無い場合はスキップ
        
        # 中央ウィジェット設定
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # メインレイアウト
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)
        main_layout.setSpacing(10)
        
        # タイトルパネル
        title_panel = self.create_title_panel()
        main_layout.addWidget(title_panel)
        
        # 接続ステータスパネル  
        connection_panel = self.create_connection_panel()
        main_layout.addWidget(connection_panel)
        
        # メインスプリッター（上下分割）
        main_splitter = QSplitter(Qt.Orientation.Vertical)
        
        # 機能タブ（上部）
        function_tabs = self.create_function_tabs()
        main_splitter.addWidget(function_tabs)
        
        # ログタブ（下部）
        log_tabs = self.create_log_tabs() 
        main_splitter.addWidget(log_tabs)
        
        # スプリッター比率設定（機能:ログ = 6:4）
        main_splitter.setSizes([600, 400])
        main_layout.addWidget(main_splitter)
        
        # メニューバー・ツールバー・ステータスバー
        self.create_menu_bar()
        self.create_tool_bar()
        self.create_status_bar()
        
    def create_title_panel(self) -> QWidget:
        """タイトルパネル作成"""
        panel = QFrame()
        panel.setFrameStyle(QFrame.Shape.StyledPanel)
        panel.setMaximumHeight(80)
        
        layout = QHBoxLayout(panel)
        
        # メインタイトル
        title_label = QLabel("Microsoft 365統合管理ツール Python版 v3.0")
        title_label.setFont(QFont("Yu Gothic UI", 16, QFont.Weight.Bold))
        title_label.setStyleSheet("color: #0078d4; padding: 10px;")
        
        # バージョン情報
        version_label = QLabel("Build 20250719 - PyQt6 Edition")
        version_label.setFont(QFont("Yu Gothic UI", 9))
        version_label.setStyleSheet("color: #6c757d;")
        version_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        
        layout.addWidget(title_label)
        layout.addStretch()
        layout.addWidget(version_label)
        
        return panel
        
    def create_connection_panel(self) -> QWidget:
        """接続ステータスパネル作成"""
        panel = QFrame()
        panel.setFrameStyle(QFrame.Shape.StyledPanel)
        panel.setMaximumHeight(60)
        
        layout = QHBoxLayout(panel)
        
        # 接続ステータスラベル
        self.connection_label = QLabel("状態: 未接続")
        self.connection_label.setFont(QFont("Yu Gothic UI", 10))
        
        # 接続ボタン
        self.connect_button = QPushButton("Microsoft 365 に接続")
        self.connect_button.setMinimumSize(200, 35)
        self.connect_button.clicked.connect(self.connect_to_microsoft365)
        
        # プログレスバー（必要時に表示）
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.progress_bar.setMaximumWidth(300)
        
        layout.addWidget(self.connection_label)
        layout.addStretch()
        layout.addWidget(self.progress_bar)
        layout.addWidget(self.connect_button)
        
        return panel
        
    def create_function_tabs(self) -> QTabWidget:
        """機能タブウィジェット作成（6セクション×26機能）"""
        tab_widget = QTabWidget()
        tab_widget.setTabPosition(QTabWidget.TabPosition.North)
        
        # 6つの機能セクション
        tab_widget.addTab(self.create_regular_reports_tab(), "📊 定期レポート")
        tab_widget.addTab(self.create_analytics_tab(), "🔍 分析レポート") 
        tab_widget.addTab(self.create_entra_id_tab(), "👥 Entra ID管理")
        tab_widget.addTab(self.create_exchange_tab(), "📧 Exchange Online")
        tab_widget.addTab(self.create_teams_tab(), "💬 Teams管理")
        tab_widget.addTab(self.create_onedrive_tab(), "💾 OneDrive管理")
        
        return tab_widget
        
    def create_regular_reports_tab(self) -> QWidget:
        """定期レポートタブ（6機能・3列2行）"""
        widget = QWidget()
        layout = QGridLayout(widget)
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # ボタン定義（text, handler, row, col）
        buttons = [
            ("📅 日次レポート", self.daily_report, 0, 0),
            ("📊 週次レポート", self.weekly_report, 0, 1),
            ("📈 月次レポート", self.monthly_report, 0, 2),
            ("📆 年次レポート", self.yearly_report, 1, 0),
            ("🧪 テスト実行", self.test_execution, 1, 1),
            ("📋 最新日次レポート表示", self.latest_daily_report, 1, 2)
        ]
        
        for text, handler, row, col in buttons:
            btn = self.create_function_button(text, handler)
            layout.addWidget(btn, row, col)
            
        # 列の幅を均等に
        for col in range(3):
            layout.setColumnStretch(col, 1)
            
        return widget
        
    def create_analytics_tab(self) -> QWidget:
        """分析レポートタブ（5機能・3列2行）"""
        widget = QWidget()
        layout = QGridLayout(widget)
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        buttons = [
            ("📊 ライセンス分析", self.license_analysis, 0, 0),
            ("📈 使用状況分析", self.usage_analysis, 0, 1),
            ("⚡ パフォーマンス分析", self.performance_analysis, 0, 2),
            ("🛡️ セキュリティ分析", self.security_analysis, 1, 0),
            ("🔍 権限監査", self.permission_audit, 1, 1)
        ]
        
        for text, handler, row, col in buttons:
            btn = self.create_function_button(text, handler)
            layout.addWidget(btn, row, col)
            
        # 最後のセルは空白
        layout.setColumnStretch(2, 1)
        
        return widget
        
    def create_entra_id_tab(self) -> QWidget:
        """Entra ID管理タブ（4機能・2列2行中央寄せ）"""
        widget = QWidget()
        main_layout = QVBoxLayout(widget)
        
        # 中央寄せのためのコンテナ
        container = QWidget()
        layout = QGridLayout(container)
        layout.setSpacing(15)
        
        buttons = [
            ("👥 ユーザー一覧", self.user_list, 0, 0),
            ("🔐 MFA状況", self.mfa_status, 0, 1),
            ("🛡️ 条件付きアクセス", self.conditional_access, 1, 0),
            ("📝 サインインログ", self.signin_logs, 1, 1)
        ]
        
        for text, handler, row, col in buttons:
            btn = self.create_function_button(text, handler)
            layout.addWidget(btn, row, col)
            
        main_layout.addStretch()
        main_layout.addWidget(container)
        main_layout.addStretch()
        
        return widget
        
    def create_exchange_tab(self) -> QWidget:
        """Exchange Onlineタブ（4機能・2列2行中央寄せ）"""
        widget = QWidget()
        main_layout = QVBoxLayout(widget)
        
        container = QWidget()
        layout = QGridLayout(container)
        layout.setSpacing(15)
        
        buttons = [
            ("📧 メールボックス管理", self.mailbox_management, 0, 0),
            ("🔄 メールフロー分析", self.mail_flow_analysis, 0, 1),
            ("🛡️ スパム対策分析", self.spam_protection_analysis, 1, 0),
            ("📬 配信分析", self.mail_delivery_analysis, 1, 1)
        ]
        
        for text, handler, row, col in buttons:
            btn = self.create_function_button(text, handler)
            layout.addWidget(btn, row, col)
            
        main_layout.addStretch()
        main_layout.addWidget(container)
        main_layout.addStretch()
        
        return widget
        
    def create_teams_tab(self) -> QWidget:
        """Teams管理タブ（4機能・2列2行中央寄せ）"""
        widget = QWidget()
        main_layout = QVBoxLayout(widget)
        
        container = QWidget()
        layout = QGridLayout(container)
        layout.setSpacing(15)
        
        buttons = [
            ("💬 Teams使用状況", self.teams_usage, 0, 0),
            ("⚙️ Teams設定分析", self.teams_settings_analysis, 0, 1),
            ("📹 会議品質分析", self.meeting_quality_analysis, 1, 0),
            ("📱 アプリ分析", self.teams_app_analysis, 1, 1)
        ]
        
        for text, handler, row, col in buttons:
            btn = self.create_function_button(text, handler)
            layout.addWidget(btn, row, col)
            
        main_layout.addStretch()
        main_layout.addWidget(container)
        main_layout.addStretch()
        
        return widget
        
    def create_onedrive_tab(self) -> QWidget:
        """OneDrive管理タブ（4機能・2列2行中央寄せ）"""
        widget = QWidget()
        main_layout = QVBoxLayout(widget)
        
        container = QWidget()
        layout = QGridLayout(container)
        layout.setSpacing(15)
        
        buttons = [
            ("💾 ストレージ分析", self.storage_analysis, 0, 0),
            ("🤝 共有分析", self.sharing_analysis, 0, 1),
            ("🔄 同期エラー分析", self.sync_error_analysis, 1, 0),
            ("🌐 外部共有分析", self.external_sharing_analysis, 1, 1)
        ]
        
        for text, handler, row, col in buttons:
            btn = self.create_function_button(text, handler)
            layout.addWidget(btn, row, col)
            
        main_layout.addStretch()
        main_layout.addWidget(container)
        main_layout.addStretch()
        
        return widget
        
    def create_function_button(self, text: str, handler) -> QPushButton:
        """機能ボタン作成（共通スタイル）"""
        button = QPushButton(text)
        button.setMinimumSize(190, 50)
        button.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        button.setCursor(Qt.CursorShape.PointingHandCursor)
        button.clicked.connect(handler)
        
        # アクセシビリティ対応
        button.setToolTip(f"{text}を実行します")
        
        return button
        
    def create_log_tabs(self) -> QTabWidget:
        """ログタブウィジェット作成（3種類のログ表示）"""
        tab_widget = QTabWidget()
        tab_widget.setTabPosition(QTabWidget.TabPosition.North)
        
        # 3つのログビュー
        tab_widget.addTab(self.create_execution_log_tab(), "🔍 実行ログ")
        tab_widget.addTab(self.create_error_log_tab(), "❌ エラーログ")
        tab_widget.addTab(self.create_prompt_tab(), "💻 プロンプト")
        
        return tab_widget
        
    def create_execution_log_tab(self) -> QWidget:
        """実行ログタブ"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # ログテキストエリア
        self.execution_log_text = QTextEdit()
        self.execution_log_text.setFont(QFont("Consolas", 9))
        self.execution_log_text.setReadOnly(True)
        self.execution_log_text.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e1e;
                color: #ffffff;
                border: 1px solid #3c3c3c;
                border-radius: 4px;
                padding: 8px;
            }
        """)
        
        # プロンプト入力エリア
        prompt_layout = QHBoxLayout()
        
        self.prompt_input = QLineEdit()
        self.prompt_input.setPlaceholderText("PowerShellコマンドを入力...")
        self.prompt_input.returnPressed.connect(self.execute_prompt_command)
        
        self.execute_btn = QPushButton("実行")
        self.execute_btn.setMinimumSize(80, 30)
        self.execute_btn.clicked.connect(self.execute_prompt_command)
        
        self.clear_log_btn = QPushButton("クリア")
        self.clear_log_btn.setMinimumSize(80, 30)
        self.clear_log_btn.clicked.connect(self.clear_execution_log)
        
        prompt_layout.addWidget(self.prompt_input, 8)
        prompt_layout.addWidget(self.execute_btn, 1)
        prompt_layout.addWidget(self.clear_log_btn, 1)
        
        layout.addWidget(self.execution_log_text, 9)
        layout.addLayout(prompt_layout, 1)
        
        return widget
        
    def create_error_log_tab(self) -> QWidget:
        """エラーログタブ"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        self.error_log_text = QTextEdit()
        self.error_log_text.setFont(QFont("Consolas", 9))
        self.error_log_text.setReadOnly(True)
        self.error_log_text.setStyleSheet("""
            QTextEdit {
                background-color: #2d1b1b;
                color: #ff9999;
                border: 1px solid #5c3333;
                border-radius: 4px;
                padding: 8px;
            }
        """)
        
        # エラーログクリアボタン
        clear_error_btn = QPushButton("エラーログクリア")
        clear_error_btn.clicked.connect(self.clear_error_log)
        
        layout.addWidget(self.error_log_text)
        layout.addWidget(clear_error_btn)
        
        return widget
        
    def create_prompt_tab(self) -> QWidget:
        """プロンプトタブ"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # プロンプト出力エリア
        self.prompt_output_text = QTextEdit()
        self.prompt_output_text.setFont(QFont("Consolas", 9))
        self.prompt_output_text.setReadOnly(True)
        self.prompt_output_text.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e2e;
                color: #cdd6f4;
                border: 1px solid #45475a;
                border-radius: 4px;
                padding: 8px;
            }
        """)
        
        # プロンプト入力エリア
        prompt_layout = QHBoxLayout()
        
        self.prompt_input2 = QLineEdit()
        self.prompt_input2.setPlaceholderText("PowerShellコマンドを入力...")
        self.prompt_input2.returnPressed.connect(self.execute_prompt_command2)
        
        self.execute_btn2 = QPushButton("実行")
        self.execute_btn2.setMinimumSize(80, 30)
        self.execute_btn2.clicked.connect(self.execute_prompt_command2)
        
        self.clear_prompt_btn = QPushButton("プロンプトクリア")
        self.clear_prompt_btn.setMinimumSize(120, 30)
        self.clear_prompt_btn.clicked.connect(self.clear_prompt_output)
        
        prompt_layout.addWidget(self.prompt_input2, 7)
        prompt_layout.addWidget(self.execute_btn2, 1)
        prompt_layout.addWidget(self.clear_prompt_btn, 2)
        
        layout.addWidget(self.prompt_output_text, 9)
        layout.addLayout(prompt_layout, 1)
        
        return widget
        
    def create_menu_bar(self):
        """メニューバー作成"""
        menubar = self.menuBar()
        
        # ファイルメニュー
        file_menu = menubar.addMenu("ファイル(&F)")
        
        export_action = QAction("レポートエクスポート(&E)", self)
        export_action.setShortcut("Ctrl+E")
        export_action.triggered.connect(self.export_reports)
        file_menu.addAction(export_action)
        
        file_menu.addSeparator()
        
        exit_action = QAction("終了(&X)", self)
        exit_action.setShortcut("Ctrl+Q")
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)
        
        # 表示メニュー
        view_menu = menubar.addMenu("表示(&V)")
        
        refresh_action = QAction("画面更新(&R)", self)
        refresh_action.setShortcut("F5")
        refresh_action.triggered.connect(self.refresh_ui)
        view_menu.addAction(refresh_action)
        
        # ツールメニュー
        tools_menu = menubar.addMenu("ツール(&T)")
        
        auth_action = QAction("認証設定(&A)", self)
        auth_action.triggered.connect(self.open_auth_settings)
        tools_menu.addAction(auth_action)
        
        config_action = QAction("環境設定(&C)", self)
        config_action.triggered.connect(self.open_config_settings)
        tools_menu.addAction(config_action)
        
        # ヘルプメニュー
        help_menu = menubar.addMenu("ヘルプ(&H)")
        
        about_action = QAction("バージョン情報(&A)", self)
        about_action.triggered.connect(self.show_about)
        help_menu.addAction(about_action)
        
    def create_tool_bar(self):
        """ツールバー作成"""
        toolbar = self.addToolBar("メインツールバー")
        
        # 接続ボタン
        connect_action = QAction("接続", self)
        connect_action.setToolTip("Microsoft 365に接続")
        connect_action.triggered.connect(self.connect_to_microsoft365)
        toolbar.addAction(connect_action)
        
        toolbar.addSeparator()
        
        # ログクリアボタン  
        clear_action = QAction("ログクリア", self)
        clear_action.setToolTip("全ログをクリア")
        clear_action.triggered.connect(self.clear_all_logs)
        toolbar.addAction(clear_action)
        
        # 更新ボタン
        refresh_action = QAction("更新", self)
        refresh_action.setToolTip("画面を更新")
        refresh_action.triggered.connect(self.refresh_ui)
        toolbar.addAction(refresh_action)
        
    def create_status_bar(self):
        """ステータスバー作成"""
        status_bar = self.statusBar()
        
        # 左側: 接続状態
        self.status_connection = QLabel("未接続")
        status_bar.addWidget(self.status_connection)
        
        # 中央: 操作状態
        self.status_operation = QLabel("待機中")
        status_bar.addPermanentWidget(self.status_operation)
        
        # 右側: 時刻表示
        self.status_time = QLabel()
        self.update_status_time()
        status_bar.addPermanentWidget(self.status_time)
        
        # 時刻更新タイマー
        self.time_timer = QTimer()
        self.time_timer.timeout.connect(self.update_status_time)
        self.time_timer.start(1000)  # 1秒間隔
        
    def setup_styling(self):
        """スタイルシート適用"""
        # Microsoft スタイルガイド準拠のスタイルシート
        style = """
        QMainWindow {
            background: qlineargradient(x1: 0, y1: 0, x2: 0, y2: 1,
                                       stop: 0 #f8f9fa, stop: 1 #e9ecef);
            color: #212529;
            font-family: 'Yu Gothic UI', 'Segoe UI', sans-serif;
        }
        
        QPushButton {
            background-color: #0078d4;
            border: 2px solid #005a9e;
            border-radius: 4px;
            color: white;
            font-weight: bold;
            font-size: 10pt;
            padding: 8px 16px;
            min-width: 180px;
            min-height: 40px;
        }
        
        QPushButton:hover {
            background-color: #106ebe;
            border-color: #005a9e;
        }
        
        QPushButton:pressed {
            background-color: #005a9e;
        }
        
        QPushButton:disabled {
            background-color: #6c757d;
            border-color: #6c757d;
            color: #adb5bd;
        }
        
        QTabWidget::pane {
            border: 1px solid #dee2e6;
            background-color: white;
            border-radius: 4px;
        }
        
        QTabBar::tab {
            background-color: #f8f9fa;
            border: 1px solid #dee2e6;
            padding: 8px 16px;
            margin-right: 2px;
            border-top-left-radius: 4px;
            border-top-right-radius: 4px;
        }
        
        QTabBar::tab:selected {
            background-color: white;
            border-bottom-color: white;
        }
        
        QTabBar::tab:hover {
            background-color: #e9ecef;
        }
        
        QFrame {
            background-color: white;
            border: 1px solid #dee2e6;
            border-radius: 4px;
        }
        
        QLineEdit {
            border: 1px solid #ced4da;
            border-radius: 4px;
            padding: 8px;
            font-size: 10pt;
            background-color: white;
        }
        
        QLineEdit:focus {
            border-color: #0078d4;
            outline: none;
        }
        
        QStatusBar {
            border-top: 1px solid #dee2e6;
            background-color: #f8f9fa;
        }
        """
        
        self.setStyleSheet(style)
        
    def setup_connections(self):
        """シグナル・スロット接続設定"""
        # ログメッセージシグナル接続
        self.log_message.connect(self.append_log_to_execution)
        
    def setup_keyboard_shortcuts(self):
        """キーボードショートカット設定"""
        from PyQt6.QtGui import QShortcut, QKeySequence
        
        # Ctrl+R: ログクリア
        clear_shortcut = QShortcut(QKeySequence("Ctrl+R"), self)
        clear_shortcut.activated.connect(self.clear_all_logs)
        
        # F5: 画面更新
        refresh_shortcut = QShortcut(QKeySequence("F5"), self)
        refresh_shortcut.activated.connect(self.refresh_ui)
        
        # Ctrl+Q: アプリケーション終了
        quit_shortcut = QShortcut(QKeySequence("Ctrl+Q"), self)
        quit_shortcut.activated.connect(self.close)
        
    # =================================================================
    # ログ機能（Write-GuiLog互換実装）
    # =================================================================
    
    def write_gui_log(self, message: str, level: GuiLogLevel = GuiLogLevel.INFO, 
                     show_notification: bool = False):
        """
        GUIログ出力（PowerShell版Write-GuiLog互換）
        
        Args:
            message: ログメッセージ
            level: ログレベル（INFO/SUCCESS/WARNING/ERROR/DEBUG）
            show_notification: ポップアップ通知表示フラグ
        """
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        icon, color = level.value
        
        formatted_message = f"[{timestamp}] {icon} {message}"
        
        # シグナル発行（スレッドセーフ）
        self.log_message.emit(formatted_message, color, timestamp)
        
        # エラーログの場合は専用ログにも出力
        if level == GuiLogLevel.ERROR:
            self.append_log_to_error(formatted_message, color)
            
        # 通知表示
        if show_notification:
            self.show_notification(message, level)
            
        # ステータスバー更新
        self.status_operation.setText(message[:50] + "..." if len(message) > 50 else message)
        
    @pyqtSlot(str, str, str)
    def append_log_to_execution(self, message: str, color: str, timestamp: str):
        """実行ログにメッセージ追加（スレッドセーフ）"""
        cursor = self.execution_log_text.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        
        # HTMLフォーマットでカラーログ
        html_message = f'<span style="color: {color};">{message}</span><br>'
        cursor.insertHtml(html_message)
        
        # 自動スクロール
        self.execution_log_text.setTextCursor(cursor)
        self.execution_log_text.ensureCursorVisible()
        
        # ログトリミング（パフォーマンス対策）
        self.trim_log_if_needed(self.execution_log_text)
        
    def append_log_to_error(self, message: str, color: str):
        """エラーログにメッセージ追加"""
        cursor = self.error_log_text.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        
        html_message = f'<span style="color: {color};">{message}</span><br>'
        cursor.insertHtml(html_message)
        
        self.error_log_text.setTextCursor(cursor)
        self.error_log_text.ensureCursorVisible()
        
    def trim_log_if_needed(self, text_edit: QTextEdit, max_lines: int = 1000):
        """ログトリミング（パフォーマンス対策）"""
        document = text_edit.document()
        if document.blockCount() > max_lines:
            # 古いログを削除（先頭200行を削除）
            cursor = QTextCursor(document)
            cursor.movePosition(QTextCursor.MoveOperation.Start)
            for _ in range(200):
                cursor.select(QTextCursor.SelectionType.BlockUnderCursor)
                cursor.removeSelectedText()
                cursor.deleteChar()  # 改行文字削除
                
    def show_notification(self, message: str, level: GuiLogLevel):
        """ポップアップ通知表示"""
        icon, _ = level.value
        
        if level == GuiLogLevel.ERROR:
            QMessageBox.critical(self, f"{icon} エラー", message)
        elif level == GuiLogLevel.WARNING:
            QMessageBox.warning(self, f"{icon} 警告", message)
        elif level == GuiLogLevel.SUCCESS:
            QMessageBox.information(self, f"{icon} 成功", message)
        else:
            QMessageBox.information(self, f"{icon} 情報", message)
            
    # =================================================================
    # Microsoft 365 機能ハンドラー（26機能）
    # =================================================================
    
    # 定期レポート（6機能）
    def daily_report(self):
        """日次レポート生成"""
        self.execute_report_function("日次レポート", "daily")
        
    def weekly_report(self):
        """週次レポート生成"""
        self.execute_report_function("週次レポート", "weekly")
        
    def monthly_report(self):
        """月次レポート生成"""
        self.execute_report_function("月次レポート", "monthly")
        
    def yearly_report(self):
        """年次レポート生成"""
        self.execute_report_function("年次レポート", "yearly")
        
    def test_execution(self):
        """テスト実行"""
        self.execute_report_function("テスト実行", "test")
        
    def latest_daily_report(self):
        """最新日次レポート表示"""
        self.execute_report_function("最新日次レポート表示", "latest_daily")
        
    # 分析レポート（5機能）
    def license_analysis(self):
        """ライセンス分析"""
        self.execute_report_function("ライセンス分析", "license")
        
    def usage_analysis(self):
        """使用状況分析"""
        self.execute_report_function("使用状況分析", "usage")
        
    def performance_analysis(self):
        """パフォーマンス分析"""
        self.execute_report_function("パフォーマンス分析", "performance")
        
    def security_analysis(self):
        """セキュリティ分析"""
        self.execute_report_function("セキュリティ分析", "security")
        
    def permission_audit(self):
        """権限監査"""
        self.execute_report_function("権限監査", "permission")
        
    # Entra ID管理（4機能）
    def user_list(self):
        """ユーザー一覧"""
        self.execute_report_function("ユーザー一覧", "entra_users")
        
    def mfa_status(self):
        """MFA状況"""
        self.execute_report_function("MFA状況", "entra_mfa")
        
    def conditional_access(self):
        """条件付きアクセス"""
        self.execute_report_function("条件付きアクセス", "entra_conditional")
        
    def signin_logs(self):
        """サインインログ"""
        self.execute_report_function("サインインログ", "entra_signin")
        
    # Exchange Online（4機能）
    def mailbox_management(self):
        """メールボックス管理"""
        self.execute_report_function("メールボックス管理", "exchange_mailbox")
        
    def mail_flow_analysis(self):
        """メールフロー分析"""
        self.execute_report_function("メールフロー分析", "exchange_flow")
        
    def spam_protection_analysis(self):
        """スパム対策分析"""
        self.execute_report_function("スパム対策分析", "exchange_spam")
        
    def mail_delivery_analysis(self):
        """配信分析"""
        self.execute_report_function("配信分析", "exchange_delivery")
        
    # Teams管理（4機能）
    def teams_usage(self):
        """Teams使用状況"""
        self.execute_report_function("Teams使用状況", "teams_usage")
        
    def teams_settings_analysis(self):
        """Teams設定分析"""
        self.execute_report_function("Teams設定分析", "teams_settings")
        
    def meeting_quality_analysis(self):
        """会議品質分析"""
        self.execute_report_function("会議品質分析", "teams_meeting")
        
    def teams_app_analysis(self):
        """アプリ分析"""
        self.execute_report_function("アプリ分析", "teams_apps")
        
    # OneDrive管理（4機能）
    def storage_analysis(self):
        """ストレージ分析"""
        self.execute_report_function("ストレージ分析", "onedrive_storage")
        
    def sharing_analysis(self):
        """共有分析"""
        self.execute_report_function("共有分析", "onedrive_sharing")
        
    def sync_error_analysis(self):
        """同期エラー分析"""
        self.execute_report_function("同期エラー分析", "onedrive_sync")
        
    def external_sharing_analysis(self):
        """外部共有分析"""
        self.execute_report_function("外部共有分析", "onedrive_external")
        
    # =================================================================
    # 共通レポート実行処理
    # =================================================================
    
    def execute_report_function(self, display_name: str, function_type: str):
        """
        レポート機能実行（共通処理）
        
        Args:
            display_name: 表示用機能名
            function_type: 機能タイプ（API呼び出し用）
        """
        # UI状態変更
        sender = self.sender()
        if isinstance(sender, QPushButton):
            original_text = sender.text()
            sender.setText("🔄 処理中...")
            sender.setEnabled(False)
            
        # プログレス表示
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(0)
        
        # ログ出力
        self.write_gui_log(f"開始: {display_name}", GuiLogLevel.INFO)
        
        try:
            # 現在は簡易実装（実際のAPI呼び出しは後続Phase）
            self.simulate_report_generation(display_name, function_type)
            
        except Exception as e:
            self.write_gui_log(f"エラー: {display_name} - {str(e)}", GuiLogLevel.ERROR, True)
            
        finally:
            # UI復元
            if isinstance(sender, QPushButton):
                sender.setText(original_text)
                sender.setEnabled(True)
            self.progress_bar.setVisible(False)
            
    def simulate_report_generation(self, display_name: str, function_type: str):
        """レポート生成シミュレーション（開発中の仮実装）"""
        
        # プログレス更新
        for progress in [20, 40, 60, 80, 100]:
            QApplication.processEvents()  # UI応答性確保
            self.progress_bar.setValue(progress)
            QTimer.singleShot(100, lambda: None)  # 短い待機
            
        # サンプルデータ生成
        sample_data = {
            "type": function_type,
            "data": [
                {"項目": "サンプル1", "値": "テストデータ1", "ステータス": "正常"},
                {"項目": "サンプル2", "値": "テストデータ2", "ステータス": "正常"},
                {"項目": "サンプル3", "値": "テストデータ3", "ステータス": "要注意"},
            ]
        }
        
        # レポート生成（現在は簡易実装）
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = Path("Reports") / display_name
        output_dir.mkdir(parents=True, exist_ok=True)
        
        csv_path = output_dir / f"{display_name}_{timestamp}.csv"
        html_path = output_dir / f"{display_name}_{timestamp}.html"
        
        # 簡易CSV出力
        with open(csv_path, "w", encoding="utf-8-sig") as f:
            f.write("項目,値,ステータス\n")
            for item in sample_data["data"]:
                f.write(f"{item['項目']},{item['値']},{item['ステータス']}\n")
                
        # 簡易HTML出力
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>{display_name}</title>
            <meta charset="utf-8">
            <style>
                body {{ font-family: 'Yu Gothic UI', sans-serif; margin: 20px; }}
                table {{ border-collapse: collapse; width: 100%; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #0078d4; color: white; }}
            </style>
        </head>
        <body>
            <h1>{display_name}</h1>
            <p>生成日時: {timestamp}</p>
            <table>
                <tr><th>項目</th><th>値</th><th>ステータス</th></tr>
                {''.join([f"<tr><td>{item['項目']}</td><td>{item['値']}</td><td>{item['ステータス']}</td></tr>" for item in sample_data["data"]])}
            </table>
        </body>
        </html>
        """
        
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(html_content)
            
        # 成功ログ
        self.write_gui_log(f"完了: {display_name}", GuiLogLevel.SUCCESS)
        self.write_gui_log(f"出力: {csv_path}", GuiLogLevel.INFO)
        self.write_gui_log(f"出力: {html_path}", GuiLogLevel.INFO)
        
        # ファイル自動表示（設定に応じて）
        self.auto_open_files(str(html_path), str(csv_path))
        
    def auto_open_files(self, html_path: str, csv_path: str):
        """ファイル自動表示（PowerShell版互換）"""
        try:
            import webbrowser
            import subprocess
            import platform
            
            # HTMLファイルをデフォルトブラウザで表示
            webbrowser.open(f"file://{html_path}")
            
            # CSVファイルも設定に応じて表示
            # config = self.get_config()
            # if config.get("GUI", {}).get("AlsoOpenCSV", False):
            #     if platform.system() == "Windows":
            #         subprocess.run(["start", csv_path], shell=True)
            #     elif platform.system() == "Darwin":  # macOS
            #         subprocess.run(["open", csv_path])
            #     else:  # Linux
            #         subprocess.run(["xdg-open", csv_path])
                
        except Exception as e:
            self.write_gui_log(f"ファイル表示エラー: {str(e)}", GuiLogLevel.WARNING)
            
    # =================================================================
    # UI操作・イベントハンドラー
    # =================================================================
    
    def connect_to_microsoft365(self):
        """Microsoft 365 接続"""
        self.write_gui_log("Microsoft 365への接続を開始します", GuiLogLevel.INFO)
        
        try:
            # 現在は簡易実装（実際の認証は後続Phase）
            self.connection_label.setText("状態: 接続中...")
            self.connect_button.setEnabled(False)
            
            # 接続シミュレーション
            QTimer.singleShot(2000, self.on_connection_success)
            
        except Exception as e:
            self.write_gui_log(f"接続エラー: {str(e)}", GuiLogLevel.ERROR, True)
            self.connection_label.setText("状態: 接続失敗")
            self.connect_button.setEnabled(True)
            
    def on_connection_success(self):
        """接続成功処理"""
        self.connection_label.setText("状態: 接続済み (Microsoft 365)")
        self.status_connection.setText("Microsoft 365 接続中")
        self.connect_button.setText("切断")
        self.connect_button.setEnabled(True)
        
        self.write_gui_log("Microsoft 365への接続が完了しました", GuiLogLevel.SUCCESS, True)
        
    def execute_prompt_command(self):
        """プロンプトコマンド実行（実行ログタブ）"""
        command = self.prompt_input.text().strip()
        if not command:
            return
            
        self.write_gui_log(f"コマンド実行: {command}", GuiLogLevel.INFO)
        
        # 簡易コマンド処理（開発中）
        if command.lower() == "help":
            result = "利用可能なコマンド: help, clear, version, status"
        elif command.lower() == "clear":
            self.clear_execution_log()
            result = "ログをクリアしました"
        elif command.lower() == "version":
            result = "Microsoft 365統合管理ツール Python版 v3.0"
        elif command.lower() == "status":
            result = f"接続状態: {self.connection_label.text()}"
        else:
            result = f"不明なコマンド: {command}"
            
        self.write_gui_log(f"結果: {result}", GuiLogLevel.SUCCESS)
        self.prompt_input.clear()
        
    def execute_prompt_command2(self):
        """プロンプトコマンド実行（プロンプトタブ）"""
        command = self.prompt_input2.text().strip()
        if not command:
            return
            
        # プロンプト出力に追加
        cursor = self.prompt_output_text.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        command_html = f'<span style="color: #89b4fa;">[{timestamp}] PS&gt;</span> <span style="color: #cdd6f4;">{command}</span><br>'
        cursor.insertHtml(command_html)
        
        # 結果表示（簡易実装）
        result = f"コマンド '{command}' を実行しました（開発中のため詳細結果は表示されません）"
        result_html = f'<span style="color: #a6e3a1;">{result}</span><br><br>'
        cursor.insertHtml(result_html)
        
        self.prompt_output_text.setTextCursor(cursor)
        self.prompt_output_text.ensureCursorVisible()
        self.prompt_input2.clear()
        
    def clear_execution_log(self):
        """実行ログクリア"""
        self.execution_log_text.clear()
        self.write_gui_log("実行ログをクリアしました", GuiLogLevel.INFO)
        
    def clear_error_log(self):
        """エラーログクリア"""
        self.error_log_text.clear()
        
    def clear_prompt_output(self):
        """プロンプト出力クリア"""
        self.prompt_output_text.clear()
        
    def clear_all_logs(self):
        """全ログクリア"""
        self.execution_log_text.clear()
        self.error_log_text.clear()
        self.prompt_output_text.clear()
        self.write_gui_log("全ログをクリアしました", GuiLogLevel.INFO)
        
    def refresh_ui(self):
        """UI更新"""
        self.write_gui_log("画面を更新しました", GuiLogLevel.INFO)
        
    def update_status_time(self):
        """ステータスバー時刻更新"""
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.status_time.setText(current_time)
        
    # =================================================================
    # メニュー・設定関連
    # =================================================================
    
    def export_reports(self):
        """レポートエクスポート"""
        file_path, _ = QFileDialog.getSaveFileName(
            self, "レポートエクスポート", 
            f"Microsoft365_Reports_{datetime.now().strftime('%Y%m%d')}.zip",
            "ZIPファイル (*.zip)"
        )
        
        if file_path:
            self.write_gui_log(f"レポートエクスポート: {file_path}", GuiLogLevel.INFO)
            
    def open_auth_settings(self):
        """認証設定ダイアログ"""
        QMessageBox.information(self, "認証設定", "認証設定ダイアログ（実装予定）")
        
    def open_config_settings(self):
        """環境設定ダイアログ"""
        QMessageBox.information(self, "環境設定", "環境設定ダイアログ（実装予定）")
        
    def show_about(self):
        """バージョン情報表示"""
        about_text = f"""
        <h2>Microsoft 365統合管理ツール</h2>
        <p><b>バージョン:</b> Python版 v3.0.0</p>
        <p><b>ビルド:</b> 20250719</p>
        <p><b>フレームワーク:</b> PyQt6</p>
        <p><b>説明:</b> エンタープライズ向けMicrosoft 365統合管理システム</p>
        <p><b>機能数:</b> 26機能（6セクション構成）</p>
        <p><b>対応:</b> ITSM/ISO27001/ISO27002準拠</p>
        """
        
        QMessageBox.about(self, "バージョン情報", about_text)
        
    # =================================================================
    # 終了処理
    # =================================================================
    
    def closeEvent(self, event):
        """アプリケーション終了時の処理"""
        self.write_gui_log("アプリケーションを終了します", GuiLogLevel.INFO)
        
        # 設定保存・リソース解放等
        try:
            # タイマー停止
            if hasattr(self, 'time_timer'):
                self.time_timer.stop()
                
            # 接続切断処理
            # if self.auth_manager:
            #     self.auth_manager.disconnect()
                
        except Exception as e:
            print(f"終了処理エラー: {e}")
            
        event.accept()


def main():
    """メイン関数 - アプリケーション起動"""
    
    # PyQt6アプリケーション初期化
    app = QApplication(sys.argv)
    
    # アプリケーション情報設定
    app.setApplicationName("Microsoft 365統合管理ツール")
    app.setApplicationVersion("3.0.0")
    app.setOrganizationName("Enterprise IT Solutions")
    
    # 日本語フォント設定
    font = QFont("Yu Gothic UI", 9)
    app.setFont(font)
    
    try:
        # メインウィンドウ作成・表示
        main_window = Microsoft365ManagementMainWindow()
        main_window.show()
        
        # イベントループ開始
        sys.exit(app.exec())
        
    except Exception as e:
        print(f"アプリケーション起動エラー: {e}")
        QMessageBox.critical(None, "起動エラー", 
                           f"アプリケーションの起動に失敗しました:\n{str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()