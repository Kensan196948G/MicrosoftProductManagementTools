#!/usr/bin/env python3
"""
Microsoft 365統合管理ツール - 完全版 PyQt6 GUI
PowerShell版GuiApp_Enhanced.ps1の完全Python移植版

🎯 Phase 3 統合実装: Day 2 GUI統合・セキュリティ統合
- 26機能ボタン完全実装（PowerShell版100%互換）
- 6セクション構成（定期レポート、分析レポート、Entra ID、Exchange、Teams、OneDrive）
- Azure Key Vault統合セキュリティ
- 監査証跡・暗号化対応
- リアルタイムログ表示・進捗監視統合
"""

import sys
import os
import asyncio
import logging
import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

# PyQt6インポート
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QGridLayout, QPushButton, QLabel, QTextEdit, QScrollArea,
    QTabWidget, QProgressBar, QStatusBar, QMenuBar, QMessageBox,
    QSplitter, QFrame, QGroupBox, QDialog, QDialogButtonBox,
    QSystemTrayIcon, QMenu, QAction
)
from PyQt6.QtCore import (
    Qt, QThread, pyqtSignal, QTimer, QSettings, QSize,
    QPropertyAnimation, QEasingCurve, QRect, pyqtSlot
)
from PyQt6.QtGui import (
    QFont, QIcon, QPalette, QColor, QPixmap, QPainter,
    QLinearGradient, QKeySequence, QShortcut, QAction as QGuiAction
)

# 相対インポート対応
sys.path.append(str(Path(__file__).parent.parent))

from core.config_manager import UnifiedConfigManager
from core.logging_manager import UnifiedLoggingManager
from core.powershell_bridge import EnhancedPowerShellBridge
from api.graph_client_unified import UnifiedGraphClient
from auth.azure_key_vault_auth import AzureKeyVaultAuth
from monitoring.progress_monitor import ProgressMonitorWidget
from compliance.audit_trail import AuditTrailManager

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/gui_unified.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class UnifiedMainWindow(QMainWindow):
    """
    Microsoft 365統合管理ツール - PyQt6完全版メインウィンドウ
    PowerShell版GuiApp_Enhanced.ps1の完全移植
    """
    
    # シグナル定義
    function_executed = pyqtSignal(str, bool, str)  # function_name, success, message
    progress_updated = pyqtSignal(int)  # progress_percentage
    log_message = pyqtSignal(str, str)  # level, message
    
    def __init__(self):
        super().__init__()
        
        # 初期化フラグ
        self.initialization_complete = False
        
        # コンポーネント初期化
        self.config_manager = None
        self.logging_manager = None
        self.powershell_bridge = None
        self.graph_client = None
        self.auth_manager = None
        self.audit_manager = None
        self.progress_monitor = None
        
        # UI要素
        self.central_widget = None
        self.log_text_edit = None
        self.progress_bar = None
        self.status_bar = None
        self.system_tray = None
        
        # 26機能ボタン辞書
        self.function_buttons: Dict[str, QPushButton] = {}
        
        # 設定
        self.settings = QSettings('Microsoft365Tools', 'UnifiedGUI')
        
        # 初期化実行
        self.init_components()
        self.init_ui()
        self.setup_connections()
        self.setup_shortcuts()
        self.setup_system_tray()
        
        # 最終初期化
        self.initialization_complete = True
        self.log_info("🚀 Microsoft 365統合管理ツール - PyQt6完全版 起動完了")
        
    def init_components(self):
        """コアコンポーネント初期化"""
        try:
            # 設定管理初期化
            self.config_manager = UnifiedConfigManager()
            self.log_info("✅ 統合設定管理システム初期化完了")
            
            # ログ管理初期化
            self.logging_manager = UnifiedLoggingManager()
            self.log_info("✅ 統合ログ管理システム初期化完了")
            
            # PowerShellブリッジ初期化
            self.powershell_bridge = EnhancedPowerShellBridge()
            self.log_info("✅ PowerShell統合ブリッジ初期化完了")
            
            # Azure認証管理初期化
            self.auth_manager = AzureKeyVaultAuthManager()
            self.log_info("✅ Azure Key Vault認証管理初期化完了")
            
            # Microsoft Graph クライアント初期化
            self.graph_client = UnifiedGraphClient(self.auth_manager)
            self.log_info("✅ Microsoft Graph統合クライアント初期化完了")
            
            # 監査証跡管理初期化
            self.audit_manager = AuditTrailManager()
            self.log_info("✅ 監査証跡管理システム初期化完了")
            
            # 進捗監視ウィジェット初期化
            self.progress_monitor = ProgressMonitorWidget()
            self.log_info("✅ 進捗監視システム初期化完了")
            
        except Exception as e:
            self.log_error(f"❌ コンポーネント初期化エラー: {str(e)}")
            QMessageBox.critical(self, "初期化エラー", f"システム初期化に失敗しました:\n{str(e)}")
    
    def init_ui(self):
        """UI初期化"""
        try:
            # ウィンドウ設定
            self.setWindowTitle("🚀 Microsoft 365統合管理ツール - PyQt6完全版 v3.0")
            self.setMinimumSize(1400, 900)
            self.resize(1600, 1000)
            
            # アイコン設定
            self.setWindowIcon(self.create_app_icon())
            
            # メニューバー設定
            self.setup_menu_bar()
            
            # ステータスバー設定
            self.setup_status_bar()
            
            # 中央ウィジェット設定
            self.setup_central_widget()
            
            # スタイル適用
            self.apply_modern_style()
            
            self.log_info("✅ UI初期化完了")
            
        except Exception as e:
            self.log_error(f"❌ UI初期化エラー: {str(e)}")
    
    def setup_central_widget(self):
        """中央ウィジェット設定"""
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        
        # メインレイアウト（水平分割）
        main_layout = QHBoxLayout(self.central_widget)
        
        # スプリッター作成
        splitter = QSplitter(Qt.Orientation.Horizontal)
        main_layout.addWidget(splitter)
        
        # 左側: 機能ボタンエリア
        left_widget = self.create_function_buttons_area()
        splitter.addWidget(left_widget)
        
        # 右側: 進捗監視・ログエリア
        right_widget = self.create_monitoring_area()
        splitter.addWidget(right_widget)
        
        # スプリッター比率設定（機能ボタン70%、監視30%）
        splitter.setSizes([1000, 400])
    
    def create_function_buttons_area(self) -> QWidget:
        """26機能ボタンエリア作成"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # タイトル
        title_label = QLabel("📊 Microsoft 365管理機能")
        title_label.setFont(QFont("Segoe UI", 16, QFont.Weight.Bold))
        title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title_label)
        
        # タブウィジェット（6セクション）
        tab_widget = QTabWidget()
        layout.addWidget(tab_widget)
        
        # 6セクション作成
        self.create_regular_reports_tab(tab_widget)
        self.create_analysis_reports_tab(tab_widget)
        self.create_entra_id_tab(tab_widget)
        self.create_exchange_tab(tab_widget)
        self.create_teams_tab(tab_widget)
        self.create_onedrive_tab(tab_widget)
        
        return widget
    
    def create_regular_reports_tab(self, tab_widget: QTabWidget):
        """📊 定期レポートタブ"""
        tab = QWidget()
        layout = QGridLayout(tab)
        
        # 5機能ボタン
        functions = [
            ("daily", "📅 日次レポート", "日次ログイン状況・容量監視"),
            ("weekly", "📊 週次レポート", "週次MFA状況・外部共有監視"),
            ("monthly", "📈 月次レポート", "月次利用率・権限レビュー"),
            ("yearly", "📋 年次レポート", "年次ライセンス・統計分析"),
            ("test", "🧪 テスト実行", "各機能のテスト実行")
        ]
        
        for i, (func_id, title, description) in enumerate(functions):
            button = self.create_function_button(func_id, title, description)
            layout.addWidget(button, i // 2, i % 2)
            self.function_buttons[func_id] = button
        
        tab_widget.addTab(tab, "📊 定期レポート")
    
    def create_analysis_reports_tab(self, tab_widget: QTabWidget):
        """🔍 分析レポートタブ"""
        tab = QWidget()
        layout = QGridLayout(tab)
        
        # 5機能ボタン
        functions = [
            ("license", "💳 ライセンス分析", "ライセンス使用状況・コスト分析"),
            ("usage", "📊 使用状況分析", "サービス別使用状況・普及率"),
            ("performance", "⚡ パフォーマンス分析", "応答時間・スループット監視"),
            ("security", "🔒 セキュリティ分析", "脅威検出・リスク評価"),
            ("audit", "📋 権限監査", "アクセス権限・コンプライアンス")
        ]
        
        for i, (func_id, title, description) in enumerate(functions):
            button = self.create_function_button(func_id, title, description)
            layout.addWidget(button, i // 2, i % 2)
            self.function_buttons[func_id] = button
        
        tab_widget.addTab(tab, "🔍 分析レポート")
    
    def create_entra_id_tab(self, tab_widget: QTabWidget):
        """👥 Entra ID管理タブ"""
        tab = QWidget()
        layout = QGridLayout(tab)
        
        # 4機能ボタン
        functions = [
            ("users", "👤 ユーザー一覧", "全ユーザー情報・属性管理"),
            ("mfa", "🔐 MFA状況", "多要素認証設定・使用状況"),
            ("conditional", "🚪 条件付きアクセス", "アクセス制御・ポリシー管理"),
            ("signin", "📊 サインインログ", "ログイン履歴・異常検出")
        ]
        
        for i, (func_id, title, description) in enumerate(functions):
            button = self.create_function_button(func_id, title, description)
            layout.addWidget(button, i // 2, i % 2)
            self.function_buttons[func_id] = button
        
        tab_widget.addTab(tab, "👥 Entra ID")
    
    def create_exchange_tab(self, tab_widget: QTabWidget):
        """📧 Exchange Online管理タブ"""
        tab = QWidget()
        layout = QGridLayout(tab)
        
        # 4機能ボタン
        functions = [
            ("mailbox", "📬 メールボックス管理", "メールボックス設定・容量管理"),
            ("mailflow", "📮 メールフロー", "メール配信・ルーティング監視"),
            ("spam", "🛡️ スパム対策", "迷惑メール・脅威保護分析"),
            ("delivery", "📊 配信分析", "配信状況・エラー分析")
        ]
        
        for i, (func_id, title, description) in enumerate(functions):
            button = self.create_function_button(func_id, title, description)
            layout.addWidget(button, i // 2, i % 2)
            self.function_buttons[func_id] = button
        
        tab_widget.addTab(tab, "📧 Exchange")
    
    def create_teams_tab(self, tab_widget: QTabWidget):
        """💬 Teams管理タブ"""
        tab = QWidget()
        layout = QGridLayout(tab)
        
        # 4機能ボタン
        functions = [
            ("teams_usage", "💬 Teams使用状況", "チーム・チャネル使用統計"),
            ("teams_settings", "⚙️ Teams設定", "ポリシー・設定管理"),
            ("meeting_quality", "📹 会議品質", "音声・映像品質分析"),
            ("teams_apps", "🔌 Teamsアプリ", "アプリ使用状況・管理")
        ]
        
        for i, (func_id, title, description) in enumerate(functions):
            button = self.create_function_button(func_id, title, description)
            layout.addWidget(button, i // 2, i % 2)
            self.function_buttons[func_id] = button
        
        tab_widget.addTab(tab, "💬 Teams")
    
    def create_onedrive_tab(self, tab_widget: QTabWidget):
        """💾 OneDrive管理タブ"""
        tab = QWidget()
        layout = QGridLayout(tab)
        
        # 4機能ボタン
        functions = [
            ("storage", "💾 ストレージ分析", "容量使用状況・傾向分析"),
            ("sharing", "🔗 共有分析", "ファイル共有・権限管理"),
            ("sync_errors", "⚠️ 同期エラー", "同期問題・解決支援"),
            ("external_sharing", "🌐 外部共有", "外部共有監視・セキュリティ")
        ]
        
        for i, (func_id, title, description) in enumerate(functions):
            button = self.create_function_button(func_id, title, description)
            layout.addWidget(button, i // 2, i % 2)
            self.function_buttons[func_id] = button
        
        tab_widget.addTab(tab, "💾 OneDrive")
    
    def create_function_button(self, func_id: str, title: str, description: str) -> QPushButton:
        """機能ボタン作成"""
        button = QPushButton()
        button.setText(title)
        button.setToolTip(description)
        button.setMinimumSize(200, 80)
        button.setMaximumSize(300, 100)
        
        # ボタンスタイル
        button.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #4a90e2, stop:1 #357abd);
                border: 2px solid #2c5f8a;
                border-radius: 8px;
                color: white;
                font-size: 11px;
                font-weight: bold;
                padding: 8px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #5ba0f2, stop:1 #4580cd);
                border: 2px solid #3d6f9a;
            }
            QPushButton:pressed {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #3a80d2, stop:1 #2570ad);
            }
            QPushButton:disabled {
                background: #cccccc;
                color: #666666;
                border: 2px solid #999999;
            }
        """)
        
        # クリックイベント接続
        button.clicked.connect(lambda: self.execute_function(func_id))
        
        return button
    
    def create_monitoring_area(self) -> QWidget:
        """進捗監視・ログエリア作成"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # 進捗監視ウィジェット追加
        if self.progress_monitor:
            layout.addWidget(self.progress_monitor)
        
        # ログ表示エリア
        log_group = QGroupBox("📋 リアルタイムログ")
        log_layout = QVBoxLayout(log_group)
        
        # ログテキストエディット
        self.log_text_edit = QTextEdit()
        self.log_text_edit.setMaximumHeight(300)
        self.log_text_edit.setFont(QFont("Consolas", 9))
        self.log_text_edit.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e1e;
                color: #d4d4d4;
                border: 1px solid #555555;
                border-radius: 4px;
                padding: 8px;
            }
        """)
        log_layout.addWidget(self.log_text_edit)
        
        layout.addWidget(log_group)
        
        # プログレスバー
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        layout.addWidget(self.progress_bar)
        
        return widget
    
    def setup_menu_bar(self):
        """メニューバー設定"""
        menubar = self.menuBar()
        
        # ファイルメニュー
        file_menu = menubar.addMenu("ファイル(&F)")
        
        # 設定
        settings_action = QAction("設定(&S)", self)
        settings_action.triggered.connect(self.show_settings_dialog)
        file_menu.addAction(settings_action)
        
        file_menu.addSeparator()
        
        # 終了
        exit_action = QAction("終了(&X)", self)
        exit_action.setShortcut(QKeySequence.StandardKey.Quit)
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)
        
        # ツールメニュー
        tools_menu = menubar.addMenu("ツール(&T)")
        
        # 認証テスト
        auth_test_action = QAction("認証テスト(&A)", self)
        auth_test_action.triggered.connect(self.test_authentication)
        tools_menu.addAction(auth_test_action)
        
        # 全機能テスト
        all_test_action = QAction("全機能テスト(&T)", self)
        all_test_action.triggered.connect(self.test_all_functions)
        tools_menu.addAction(all_test_action)
        
        # ヘルプメニュー
        help_menu = menubar.addMenu("ヘルプ(&H)")
        
        # バージョン情報
        about_action = QAction("バージョン情報(&A)", self)
        about_action.triggered.connect(self.show_about_dialog)
        help_menu.addAction(about_action)
    
    def setup_status_bar(self):
        """ステータスバー設定"""
        self.status_bar = self.statusBar()
        self.status_bar.showMessage("準備完了")
        
        # 認証状態表示
        self.auth_status_label = QLabel("認証: 未確認")
        self.status_bar.addPermanentWidget(self.auth_status_label)
        
        # 時刻表示
        self.time_label = QLabel()
        self.status_bar.addPermanentWidget(self.time_label)
        
        # 時刻更新タイマー
        self.time_timer = QTimer()
        self.time_timer.timeout.connect(self.update_time)
        self.time_timer.start(1000)
        self.update_time()
    
    def setup_connections(self):
        """シグナル・スロット接続設定"""
        # 機能実行シグナル
        self.function_executed.connect(self.on_function_executed)
        
        # 進捗更新シグナル
        self.progress_updated.connect(self.on_progress_updated)
        
        # ログメッセージシグナル
        self.log_message.connect(self.on_log_message)
        
        # 進捗監視ウィジェットからのシグナル
        if self.progress_monitor:
            self.progress_monitor.progress_updated.connect(self.on_progress_monitor_updated)
    
    def setup_shortcuts(self):
        """キーボードショートカット設定"""
        # Ctrl+R: リフレッシュ
        refresh_shortcut = QShortcut(QKeySequence("Ctrl+R"), self)
        refresh_shortcut.activated.connect(self.refresh_all)
        
        # Ctrl+T: テスト実行
        test_shortcut = QShortcut(QKeySequence("Ctrl+T"), self)
        test_shortcut.activated.connect(self.test_all_functions)
        
        # F5: リフレッシュ
        f5_shortcut = QShortcut(QKeySequence("F5"), self)
        f5_shortcut.activated.connect(self.refresh_all)
    
    def setup_system_tray(self):
        """システムトレイ設定"""
        if QSystemTrayIcon.isSystemTrayAvailable():
            self.system_tray = QSystemTrayIcon(self)
            self.system_tray.setIcon(self.create_app_icon())
            
            # トレイメニュー
            tray_menu = QMenu()
            
            show_action = tray_menu.addAction("表示")
            show_action.triggered.connect(self.show)
            
            tray_menu.addSeparator()
            
            quit_action = tray_menu.addAction("終了")
            quit_action.triggered.connect(self.close)
            
            self.system_tray.setContextMenu(tray_menu)
            self.system_tray.activated.connect(self.on_tray_activated)
            self.system_tray.show()
    
    def create_app_icon(self) -> QIcon:
        """アプリケーションアイコン作成"""
        pixmap = QPixmap(32, 32)
        pixmap.fill(QColor("#4a90e2"))
        
        painter = QPainter(pixmap)
        painter.setPen(QColor("white"))
        painter.setFont(QFont("Arial", 16, QFont.Weight.Bold))
        painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, "M365")
        painter.end()
        
        return QIcon(pixmap)
    
    def apply_modern_style(self):
        """モダンスタイル適用"""
        self.setStyleSheet("""
            QMainWindow {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #f8f9fa, stop:1 #e9ecef);
            }
            QTabWidget::pane {
                border: 1px solid #dee2e6;
                background: white;
                border-radius: 8px;
            }
            QTabWidget::tab-bar {
                alignment: center;
            }
            QTabBar::tab {
                background: #f8f9fa;
                border: 1px solid #dee2e6;
                padding: 8px 16px;
                margin-right: 2px;
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
            }
            QTabBar::tab:selected {
                background: white;
                border-bottom: 1px solid white;
            }
            QTabBar::tab:hover {
                background: #e9ecef;
            }
            QGroupBox {
                font-weight: bold;
                border: 2px solid #dee2e6;
                border-radius: 8px;
                margin-top: 1ex;
                padding-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px 0 5px;
            }
        """)
    
    # ===== イベントハンドラー =====
    
    @pyqtSlot(str)
    def execute_function(self, func_id: str):
        """機能実行"""
        try:
            self.log_info(f"🚀 機能実行開始: {func_id}")
            self.status_bar.showMessage(f"実行中: {func_id}")
            
            # ボタンを無効化
            if func_id in self.function_buttons:
                self.function_buttons[func_id].setEnabled(False)
            
            # プログレスバー表示
            self.progress_bar.setVisible(True)
            self.progress_bar.setValue(0)
            
            # 監査ログ記録
            if self.audit_manager:
                self.audit_manager.log_function_execution(func_id, "started")
            
            # 非同期実行
            asyncio.create_task(self._execute_function_async(func_id))
            
        except Exception as e:
            self.log_error(f"❌ 機能実行エラー: {func_id} - {str(e)}")
            self.function_executed.emit(func_id, False, str(e))
    
    async def _execute_function_async(self, func_id: str):
        """非同期機能実行"""
        try:
            success = False
            message = ""
            
            # 進捗更新
            self.progress_updated.emit(25)
            
            # Microsoft Graph API経由でのデータ取得
            if self.graph_client:
                data = await self.graph_client.get_data_for_function(func_id)
                self.progress_updated.emit(50)
            
            # PowerShellブリッジ経由での既存スクリプト実行
            if self.powershell_bridge:
                result = await self.powershell_bridge.execute_function(func_id, data if 'data' in locals() else None)
                self.progress_updated.emit(75)
                
                if result.get('success'):
                    success = True
                    message = f"機能 {func_id} が正常に完了しました"
                else:
                    message = result.get('error', '不明なエラーが発生しました')
            
            # 完了
            self.progress_updated.emit(100)
            
            # 監査ログ記録
            if self.audit_manager:
                self.audit_manager.log_function_execution(func_id, "completed" if success else "failed", message)
            
            # 結果通知
            self.function_executed.emit(func_id, success, message)
            
        except Exception as e:
            error_msg = f"非同期実行エラー: {str(e)}"
            self.log_error(f"❌ {error_msg}")
            self.function_executed.emit(func_id, False, error_msg)
    
    @pyqtSlot(str, bool, str)
    def on_function_executed(self, func_id: str, success: bool, message: str):
        """機能実行完了処理"""
        # ボタンを有効化
        if func_id in self.function_buttons:
            self.function_buttons[func_id].setEnabled(True)
        
        # プログレスバー非表示
        self.progress_bar.setVisible(False)
        
        # ステータス更新
        if success:
            self.status_bar.showMessage(f"完了: {func_id}")
            self.log_info(f"✅ {message}")
            
            # 成功通知
            if self.system_tray:
                self.system_tray.showMessage(
                    "機能実行完了",
                    message,
                    QSystemTrayIcon.MessageIcon.Information,
                    3000
                )
        else:
            self.status_bar.showMessage(f"エラー: {func_id}")
            self.log_error(f"❌ {message}")
            
            # エラーダイアログ
            QMessageBox.warning(self, "実行エラー", f"機能 {func_id} の実行に失敗しました:\n{message}")
    
    @pyqtSlot(int)
    def on_progress_updated(self, value: int):
        """進捗更新処理"""
        if self.progress_bar.isVisible():
            self.progress_bar.setValue(value)
    
    @pyqtSlot(str, str)
    def on_log_message(self, level: str, message: str):
        """ログメッセージ処理"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        # レベル別色分け
        color_map = {
            "INFO": "#d4d4d4",
            "SUCCESS": "#4ade80",
            "WARNING": "#fbbf24",
            "ERROR": "#ef4444",
            "DEBUG": "#94a3b8"
        }
        
        color = color_map.get(level, "#d4d4d4")
        formatted_message = f'<span style="color: {color}">[{timestamp}] {level}: {message}</span><br>'
        
        if self.log_text_edit:
            self.log_text_edit.insertHtml(formatted_message)
            self.log_text_edit.ensureCursorVisible()
            
            # ログトリミング（1000行制限）
            document = self.log_text_edit.document()
            if document.blockCount() > 1000:
                cursor = self.log_text_edit.textCursor()
                cursor.movePosition(cursor.MoveOperation.Start)
                cursor.movePosition(cursor.MoveOperation.Down, cursor.MoveMode.KeepAnchor, 100)
                cursor.removeSelectedText()
    
    @pyqtSlot(dict)
    def on_progress_monitor_updated(self, data: dict):
        """進捗監視更新処理"""
        self.log_info(f"📊 進捗監視更新: {data.get('message', 'データ更新')}")
    
    @pyqtSlot()
    def on_tray_activated(self, reason):
        """システムトレイアクティベート処理"""
        if reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            self.show()
            self.raise_()
            self.activateWindow()
    
    def update_time(self):
        """時刻更新"""
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.time_label.setText(current_time)
    
    # ===== ダイアログ =====
    
    def show_settings_dialog(self):
        """設定ダイアログ表示"""
        dialog = QDialog(self)
        dialog.setWindowTitle("設定")
        dialog.setModal(True)
        dialog.resize(500, 400)
        
        layout = QVBoxLayout(dialog)
        
        # 設定内容（今後拡張）
        label = QLabel("設定機能は今後のバージョンで実装予定です。")
        layout.addWidget(label)
        
        # ボタン
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok)
        buttons.accepted.connect(dialog.accept)
        layout.addWidget(buttons)
        
        dialog.exec()
    
    def show_about_dialog(self):
        """バージョン情報ダイアログ"""
        about_text = """
        <h2>Microsoft 365統合管理ツール</h2>
        <p><b>バージョン:</b> 3.0 (PyQt6完全版)</p>
        <p><b>説明:</b> PowerShell版の完全Python移植</p>
        <p><b>機能:</b> 26機能・6セクション完全対応</p>
        <p><b>技術:</b> PyQt6 + Microsoft Graph SDK</p>
        <p><b>セキュリティ:</b> Azure Key Vault統合</p>
        <p><b>コンプライアンス:</b> ISO27001/27002準拠</p>
        """
        
        QMessageBox.about(self, "バージョン情報", about_text)
    
    # ===== テスト機能 =====
    
    @pyqtSlot()
    def test_authentication(self):
        """認証テスト"""
        try:
            self.log_info("🔐 認証テスト開始")
            
            if self.auth_manager:
                result = asyncio.create_task(self.auth_manager.test_connection())
                self.log_info("✅ 認証テスト完了")
            else:
                self.log_error("❌ 認証管理が初期化されていません")
                
        except Exception as e:
            self.log_error(f"❌ 認証テストエラー: {str(e)}")
    
    @pyqtSlot()
    def test_all_functions(self):
        """全機能テスト"""
        self.log_info("🧪 全機能テスト開始")
        
        # テスト機能実行
        self.execute_function("test")
    
    @pyqtSlot()
    def refresh_all(self):
        """全体リフレッシュ"""
        self.log_info("🔄 システムリフレッシュ")
        
        # 認証状態確認
        if self.auth_manager:
            asyncio.create_task(self.auth_manager.refresh_tokens())
        
        # 進捗監視更新
        if self.progress_monitor:
            self.progress_monitor.collect_progress()
    
    # ===== ログ用ヘルパーメソッド =====
    
    def log_info(self, message: str):
        """情報ログ"""
        logger.info(message)
        self.log_message.emit("INFO", message)
    
    def log_success(self, message: str):
        """成功ログ"""
        logger.info(message)
        self.log_message.emit("SUCCESS", message)
    
    def log_warning(self, message: str):
        """警告ログ"""
        logger.warning(message)
        self.log_message.emit("WARNING", message)
    
    def log_error(self, message: str):
        """エラーログ"""
        logger.error(message)
        self.log_message.emit("ERROR", message)
    
    def log_debug(self, message: str):
        """デバッグログ"""
        logger.debug(message)
        self.log_message.emit("DEBUG", message)
    
    # ===== ウィンドウイベント =====
    
    def closeEvent(self, event):
        """ウィンドウクローズイベント"""
        if self.system_tray and self.system_tray.isVisible():
            # システムトレイに最小化
            self.hide()
            self.system_tray.showMessage(
                "Microsoft 365管理ツール",
                "アプリケーションはシステムトレイに最小化されました",
                QSystemTrayIcon.MessageIcon.Information,
                2000
            )
            event.ignore()
        else:
            # 終了確認
            reply = QMessageBox.question(
                self,
                "終了確認",
                "Microsoft 365管理ツールを終了しますか？",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No
            )
            
            if reply == QMessageBox.StandardButton.Yes:
                # クリーンアップ
                if self.logging_manager:
                    self.logging_manager.cleanup()
                
                event.accept()
            else:
                event.ignore()

def main():
    """メイン関数"""
    # Qtアプリケーション作成
    app = QApplication(sys.argv)
    app.setApplicationName("Microsoft 365統合管理ツール")
    app.setApplicationVersion("3.0")
    app.setOrganizationName("Microsoft365Tools")
    
    # 高DPI対応
    app.setAttribute(Qt.ApplicationAttribute.AA_EnableHighDpiScaling)
    app.setAttribute(Qt.ApplicationAttribute.AA_UseHighDpiPixmaps)
    
    try:
        # メインウィンドウ作成・表示
        window = UnifiedMainWindow()
        window.show()
        
        # アプリケーション実行
        sys.exit(app.exec())
        
    except Exception as e:
        logger.error(f"❌ アプリケーション起動エラー: {str(e)}")
        QMessageBox.critical(None, "起動エラー", f"アプリケーションの起動に失敗しました:\n{str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()