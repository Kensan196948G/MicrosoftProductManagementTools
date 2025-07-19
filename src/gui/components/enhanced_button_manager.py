#!/usr/bin/env python3
"""
Enhanced Button Manager - Phase 3 GUI統合加速
Advanced Button Management for 26 Functions

Features:
- Adaptive Button Layouts
- Real-time Status Updates
- Accessibility Enhancements
- Performance Optimization
- Multi-language Support

Author: Frontend Developer (dev0)
Version: 3.1.0
Date: 2025-07-19
"""

import sys
from datetime import datetime
from typing import Dict, List, Optional, Callable, Any
from dataclasses import dataclass
from enum import Enum

try:
    from PyQt6.QtWidgets import (
        QWidget, QVBoxLayout, QHBoxLayout, QGridLayout,
        QPushButton, QLabel, QProgressBar, QFrame,
        QToolTip, QGraphicsDropShadowEffect, QButtonGroup,
        QMenu, QAction, QWidgetAction, QSizePolicy
    )
    from PyQt6.QtCore import (
        Qt, QTimer, QObject, pyqtSignal, pyqtSlot,
        QPropertyAnimation, QEasingCurve, QRect,
        QParallelAnimationGroup, QSequentialAnimationGroup,
        QAbstractAnimation, QSize, QPoint
    )
    from PyQt6.QtGui import (
        QFont, QIcon, QPalette, QColor, QLinearGradient,
        QBrush, QPainter, QPen, QPixmap, QKeySequence,
        QShortcut, QCursor, QAction as QGuiAction
    )
except ImportError as e:
    print(f"❌ PyQt6インポートエラー: {e}")
    sys.exit(1)


class ButtonState(Enum):
    """ボタン状態"""
    IDLE = "idle"
    LOADING = "loading"
    SUCCESS = "success"
    ERROR = "error"
    DISABLED = "disabled"


class ButtonSize(Enum):
    """ボタンサイズ"""
    SMALL = (140, 35)
    MEDIUM = (190, 50)
    LARGE = (240, 60)


class ButtonPriority(Enum):
    """ボタン優先度"""
    PRIMARY = "primary"
    SECONDARY = "secondary"
    SUCCESS = "success"
    WARNING = "warning"
    DANGER = "danger"
    INFO = "info"


@dataclass
class ButtonConfig:
    """ボタン設定"""
    id: str
    text: str
    icon: str = ""
    tooltip: str = ""
    shortcut: str = ""
    size: ButtonSize = ButtonSize.MEDIUM
    priority: ButtonPriority = ButtonPriority.PRIMARY
    category: str = "general"
    enabled: bool = True
    visible: bool = True
    handler: Optional[Callable] = None


class EnhancedButton(QPushButton):
    """
    機能強化ボタン
    - アニメーション効果
    - 状態管理
    - アクセシビリティ対応
    - 多言語対応
    """
    
    # シグナル定義
    state_changed = pyqtSignal(str, str)  # button_id, state
    long_pressed = pyqtSignal(str)  # button_id
    
    def __init__(self, config: ButtonConfig):
        super().__init__()
        self.config = config
        self.current_state = ButtonState.IDLE
        self.progress_value = 0
        
        # 長押し検出用タイマー
        self.long_press_timer = QTimer()
        self.long_press_timer.setSingleShot(True)
        self.long_press_timer.timeout.connect(self.on_long_press)
        
        # アニメーション
        self.hover_animation = None
        self.click_animation = None
        self.state_animation = None
        
        self.init_ui()
        self.setup_animations()
        
    def init_ui(self):
        """UI初期化"""
        # 基本設定
        self.setText(self.config.text)
        size = self.config.size.value
        self.setMinimumSize(size[0], size[1])
        self.setMaximumSize(size[0] + 50, size[1] + 10)  # 若干の余裕
        
        # フォント設定
        font = QFont("Yu Gothic UI", 10, QFont.Weight.Bold)
        self.setFont(font)
        
        # ツールチップ
        if self.config.tooltip:
            self.setToolTip(self.config.tooltip)
        
        # ショートカット
        if self.config.shortcut:
            shortcut = QShortcut(QKeySequence(self.config.shortcut), self)
            shortcut.activated.connect(self.click)
            # ツールチップにショートカット情報追加
            tooltip_text = self.config.tooltip or self.config.text
            self.setToolTip(f"{tooltip_text} ({self.config.shortcut})")
        
        # 右クリックメニュー
        self.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.customContextMenuRequested.connect(self.show_context_menu)
        
        # ドロップシャドウ効果
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(8)
        shadow.setColor(QColor(0, 0, 0, 30))
        shadow.setOffset(0, 2)
        self.setGraphicsEffect(shadow)
        
        # スタイル適用
        self.apply_style()
        
    def apply_style(self):
        """スタイル適用"""
        # 優先度に応じた色設定
        color_schemes = {
            ButtonPriority.PRIMARY: ("#0078d4", "#106ebe", "#005a9e"),
            ButtonPriority.SECONDARY: ("#6c757d", "#5a6268", "#495057"),
            ButtonPriority.SUCCESS: ("#28a745", "#218838", "#1e7e34"),
            ButtonPriority.WARNING: ("#ffc107", "#e0a800", "#d39e00"),
            ButtonPriority.DANGER: ("#dc3545", "#c82333", "#bd2130"),
            ButtonPriority.INFO: ("#17a2b8", "#138496", "#117a8b"),
        }
        
        base_color, hover_color, active_color = color_schemes.get(
            self.config.priority, color_schemes[ButtonPriority.PRIMARY]
        )
        
        style = f"""
        EnhancedButton {{
            background-color: {base_color};
            border: 2px solid {active_color};
            border-radius: 6px;
            color: white;
            font-weight: bold;
            padding: 8px 16px;
            text-align: center;
        }}
        
        EnhancedButton:hover {{
            background-color: {hover_color};
        }}
        
        EnhancedButton:pressed {{
            background-color: {active_color};
        }}
        
        EnhancedButton:disabled {{
            background-color: #6c757d;
            border-color: #6c757d;
            color: #adb5bd;
        }}
        """
        
        self.setStyleSheet(style)
        
    def setup_animations(self):
        """アニメーション設定"""
        # ホバーアニメーション
        self.hover_animation = QPropertyAnimation(self, b"geometry")
        self.hover_animation.setDuration(200)
        self.hover_animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        
        # クリックアニメーション
        self.click_animation = QPropertyAnimation(self, b"geometry")
        self.click_animation.setDuration(150)
        self.click_animation.setEasingCurve(QEasingCurve.Type.OutBounce)
        
    def enterEvent(self, event):
        """マウス進入時"""
        super().enterEvent(event)
        self.animate_hover(True)
        
    def leaveEvent(self, event):
        """マウス離脱時"""
        super().leaveEvent(event)
        self.animate_hover(False)
        
    def mousePressEvent(self, event):
        """マウス押下時"""
        super().mousePressEvent(event)
        if event.button() == Qt.MouseButton.LeftButton:
            self.long_press_timer.start(800)  # 800ms後に長押し検出
            self.animate_click()
            
    def mouseReleaseEvent(self, event):
        """マウス離上時"""
        super().mouseReleaseEvent(event)
        self.long_press_timer.stop()
        
    def animate_hover(self, enter: bool):
        """ホバーアニメーション"""
        if self.hover_animation.state() == QAbstractAnimation.State.Running:
            self.hover_animation.stop()
            
        current_rect = self.geometry()
        if enter:
            # 少し大きくする
            new_rect = QRect(
                current_rect.x() - 2,
                current_rect.y() - 1,
                current_rect.width() + 4,
                current_rect.height() + 2
            )
        else:
            # 元のサイズに戻す
            size = self.config.size.value
            new_rect = QRect(
                current_rect.x() + 2,
                current_rect.y() + 1,
                size[0],
                size[1]
            )
            
        self.hover_animation.setStartValue(current_rect)
        self.hover_animation.setEndValue(new_rect)
        self.hover_animation.start()
        
    def animate_click(self):
        """クリックアニメーション"""
        if self.click_animation.state() == QAbstractAnimation.State.Running:
            return
            
        current_rect = self.geometry()
        # 一瞬小さくしてから戻す
        small_rect = QRect(
            current_rect.x() + 3,
            current_rect.y() + 2,
            current_rect.width() - 6,
            current_rect.height() - 4
        )
        
        self.click_animation.setStartValue(current_rect)
        self.click_animation.setEndValue(small_rect)
        self.click_animation.finished.connect(lambda: self.animate_hover(True))
        self.click_animation.start()
        
    def on_long_press(self):
        """長押し時の処理"""
        self.long_pressed.emit(self.config.id)
        
    def show_context_menu(self, position):
        """右クリックメニュー表示"""
        menu = QMenu(self)
        
        # 基本アクション
        execute_action = QAction(f"🚀 {self.config.text}を実行", self)
        execute_action.triggered.connect(self.click)
        menu.addAction(execute_action)
        
        menu.addSeparator()
        
        # 詳細情報
        info_action = QAction("ℹ️ 詳細情報", self)
        info_action.triggered.connect(self.show_detailed_info)
        menu.addAction(info_action)
        
        # ヘルプ
        help_action = QAction("❓ ヘルプ", self)
        help_action.triggered.connect(self.show_help)
        menu.addAction(help_action)
        
        menu.exec(self.mapToGlobal(position))
        
    def show_detailed_info(self):
        """詳細情報表示"""
        info = f"""
        機能ID: {self.config.id}
        カテゴリ: {self.config.category}
        ショートカット: {self.config.shortcut or 'なし'}
        現在の状態: {self.current_state.value}
        """
        QToolTip.showText(QCursor.pos(), info)
        
    def show_help(self):
        """ヘルプ表示"""
        help_text = f"{self.config.text}の詳細なヘルプ情報がここに表示されます。"
        QToolTip.showText(QCursor.pos(), help_text)
        
    def set_state(self, state: ButtonState, progress: int = 0):
        """状態設定"""
        if self.current_state == state:
            return
            
        old_state = self.current_state
        self.current_state = state
        self.progress_value = progress
        
        # UI更新
        self.update_appearance()
        
        # シグナル発行
        self.state_changed.emit(self.config.id, state.value)
        
    def update_appearance(self):
        """外観更新"""
        if self.current_state == ButtonState.LOADING:
            self.setText(f"🔄 処理中... ({self.progress_value}%)")
            self.setEnabled(False)
        elif self.current_state == ButtonState.SUCCESS:
            self.setText(f"✅ 完了")
            QTimer.singleShot(2000, self.reset_to_idle)  # 2秒後に元に戻す
        elif self.current_state == ButtonState.ERROR:
            self.setText(f"❌ エラー")
            QTimer.singleShot(3000, self.reset_to_idle)  # 3秒後に元に戻す
        elif self.current_state == ButtonState.DISABLED:
            self.setEnabled(False)
        else:  # IDLE
            self.setText(self.config.text)
            self.setEnabled(True)
            
    def reset_to_idle(self):
        """アイドル状態にリセット"""
        self.set_state(ButtonState.IDLE)
        
    def update_progress(self, progress: int):
        """進捗更新"""
        if self.current_state == ButtonState.LOADING:
            self.progress_value = max(0, min(100, progress))
            self.setText(f"🔄 処理中... ({self.progress_value}%)")


class ResponsiveButtonLayout(QWidget):
    """
    レスポンシブボタンレイアウト
    画面サイズに応じて動的にレイアウトを調整
    """
    
    def __init__(self, buttons: List[EnhancedButton]):
        super().__init__()
        self.buttons = buttons
        self.current_columns = 3
        self.init_ui()
        
    def init_ui(self):
        """UI初期化"""
        self.layout = QGridLayout(self)
        self.layout.setSpacing(15)
        self.layout.setContentsMargins(20, 20, 20, 20)
        
        # 初期レイアウト
        self.arrange_buttons()
        
    def arrange_buttons(self):
        """ボタン配置"""
        # 既存のウィジェットをクリア
        for i in reversed(range(self.layout.count())):
            self.layout.itemAt(i).widget().setParent(None)
            
        # ボタン配置
        for i, button in enumerate(self.buttons):
            row = i // self.current_columns
            col = i % self.current_columns
            self.layout.addWidget(button, row, col)
            
        # 列の幅を均等に
        for col in range(self.current_columns):
            self.layout.setColumnStretch(col, 1)
            
    def resizeEvent(self, event):
        """リサイズイベント"""
        super().resizeEvent(event)
        
        # 画面幅に応じて列数を調整
        width = event.size().width()
        new_columns = 3  # デフォルト
        
        if width < 600:
            new_columns = 1
        elif width < 900:
            new_columns = 2
        elif width < 1200:
            new_columns = 3
        else:
            new_columns = 4
            
        if new_columns != self.current_columns:
            self.current_columns = new_columns
            self.arrange_buttons()


class EnhancedButtonManager(QObject):
    """
    Enhanced Button Manager
    26機能ボタンの高度な管理システム
    """
    
    # シグナル定義
    button_clicked = pyqtSignal(str, str)  # button_id, category
    button_state_changed = pyqtSignal(str, str)  # button_id, state
    category_changed = pyqtSignal(str)  # category
    
    def __init__(self):
        super().__init__()
        self.buttons: Dict[str, EnhancedButton] = {}
        self.button_groups: Dict[str, List[str]] = {}
        self.layouts: Dict[str, ResponsiveButtonLayout] = {}
        self.current_category = "all"
        
        # 26機能ボタン設定
        self.button_configs = self.create_button_configs()
        
        # ボタン作成
        self.create_buttons()
        
    def create_button_configs(self) -> List[ButtonConfig]:
        """26機能ボタン設定作成"""
        configs = [
            # 定期レポート (6機能)
            ButtonConfig("daily_report", "📅 日次レポート", tooltip="日次アクティビティレポートを生成", 
                        shortcut="Ctrl+1", category="regular_reports", priority=ButtonPriority.PRIMARY),
            ButtonConfig("weekly_report", "📊 週次レポート", tooltip="週次サマリーレポートを生成",
                        shortcut="Ctrl+2", category="regular_reports", priority=ButtonPriority.PRIMARY),
            ButtonConfig("monthly_report", "📈 月次レポート", tooltip="月次統計レポートを生成",
                        shortcut="Ctrl+3", category="regular_reports", priority=ButtonPriority.PRIMARY),
            ButtonConfig("yearly_report", "📆 年次レポート", tooltip="年次総合レポートを生成",
                        shortcut="Ctrl+4", category="regular_reports", priority=ButtonPriority.PRIMARY),
            ButtonConfig("test_execution", "🧪 テスト実行", tooltip="システムテストを実行",
                        shortcut="Ctrl+5", category="regular_reports", priority=ButtonPriority.INFO),
            ButtonConfig("latest_daily", "📋 最新日次レポート表示", tooltip="最新の日次レポートを表示",
                        category="regular_reports", priority=ButtonPriority.SECONDARY),
            
            # 分析レポート (5機能)
            ButtonConfig("license_analysis", "📊 ライセンス分析", tooltip="ライセンス使用状況を分析",
                        shortcut="Alt+1", category="analytics", priority=ButtonPriority.SUCCESS),
            ButtonConfig("usage_analysis", "📈 使用状況分析", tooltip="サービス使用状況を分析",
                        shortcut="Alt+2", category="analytics", priority=ButtonPriority.SUCCESS),
            ButtonConfig("performance_analysis", "⚡ パフォーマンス分析", tooltip="システムパフォーマンスを分析",
                        shortcut="Alt+3", category="analytics", priority=ButtonPriority.SUCCESS),
            ButtonConfig("security_analysis", "🛡️ セキュリティ分析", tooltip="セキュリティ状況を分析",
                        shortcut="Alt+4", category="analytics", priority=ButtonPriority.WARNING),
            ButtonConfig("permission_audit", "🔍 権限監査", tooltip="ユーザー権限を監査",
                        shortcut="Alt+5", category="analytics", priority=ButtonPriority.WARNING),
            
            # Entra ID管理 (4機能)
            ButtonConfig("user_list", "👥 ユーザー一覧", tooltip="Entra IDユーザー一覧を取得",
                        shortcut="Ctrl+U", category="entra_id", priority=ButtonPriority.INFO),
            ButtonConfig("mfa_status", "🔐 MFA状況", tooltip="多要素認証の状況を確認",
                        shortcut="Ctrl+M", category="entra_id", priority=ButtonPriority.WARNING),
            ButtonConfig("conditional_access", "🛡️ 条件付きアクセス", tooltip="条件付きアクセスポリシーを確認",
                        category="entra_id", priority=ButtonPriority.WARNING),
            ButtonConfig("signin_logs", "📝 サインインログ", tooltip="サインインログを取得",
                        category="entra_id", priority=ButtonPriority.INFO),
            
            # Exchange Online (4機能)  
            ButtonConfig("mailbox_management", "📧 メールボックス管理", tooltip="メールボックス情報を管理",
                        shortcut="Ctrl+E", category="exchange", priority=ButtonPriority.INFO),
            ButtonConfig("mail_flow_analysis", "🔄 メールフロー分析", tooltip="メールフローを分析",
                        category="exchange", priority=ButtonPriority.SUCCESS),
            ButtonConfig("spam_protection", "🛡️ スパム対策分析", tooltip="スパム対策状況を分析",
                        category="exchange", priority=ButtonPriority.WARNING),
            ButtonConfig("mail_delivery", "📬 配信分析", tooltip="メール配信状況を分析",
                        category="exchange", priority=ButtonPriority.SUCCESS),
            
            # Teams管理 (4機能)
            ButtonConfig("teams_usage", "💬 Teams使用状況", tooltip="Teams使用状況を確認",
                        shortcut="Ctrl+T", category="teams", priority=ButtonPriority.INFO),
            ButtonConfig("teams_settings", "⚙️ Teams設定分析", tooltip="Teams設定を分析",
                        category="teams", priority=ButtonPriority.SUCCESS),
            ButtonConfig("meeting_quality", "📹 会議品質分析", tooltip="Teams会議品質を分析",
                        category="teams", priority=ButtonPriority.SUCCESS),
            ButtonConfig("teams_apps", "📱 アプリ分析", tooltip="Teamsアプリ使用状況を分析",
                        category="teams", priority=ButtonPriority.INFO),
            
            # OneDrive管理 (4機能)
            ButtonConfig("storage_analysis", "💾 ストレージ分析", tooltip="OneDriveストレージを分析",
                        shortcut="Ctrl+O", category="onedrive", priority=ButtonPriority.INFO),
            ButtonConfig("sharing_analysis", "🤝 共有分析", tooltip="ファイル共有状況を分析",
                        category="onedrive", priority=ButtonPriority.SUCCESS),
            ButtonConfig("sync_error", "🔄 同期エラー分析", tooltip="同期エラーを分析",
                        category="onedrive", priority=ButtonPriority.WARNING),
            ButtonConfig("external_sharing", "🌐 外部共有分析", tooltip="外部共有状況を分析",
                        category="onedrive", priority=ButtonPriority.DANGER),
        ]
        
        return configs
        
    def create_buttons(self):
        """ボタン作成"""
        for config in self.button_configs:
            button = EnhancedButton(config)
            
            # シグナル接続
            button.clicked.connect(lambda checked=False, btn_id=config.id: self.on_button_clicked(btn_id))
            button.state_changed.connect(self.button_state_changed.emit)
            
            # ハンドラー設定
            if config.handler:
                button.clicked.connect(config.handler)
                
            self.buttons[config.id] = button
            
            # カテゴリ分類
            if config.category not in self.button_groups:
                self.button_groups[config.category] = []
            self.button_groups[config.category].append(config.id)
            
    def on_button_clicked(self, button_id: str):
        """ボタンクリック時の処理"""
        button = self.buttons.get(button_id)
        if button:
            category = button.config.category
            self.button_clicked.emit(button_id, category)
            
    def get_buttons_by_category(self, category: str) -> List[EnhancedButton]:
        """カテゴリ別ボタン取得"""
        if category == "all":
            return list(self.buttons.values())
        
        button_ids = self.button_groups.get(category, [])
        return [self.buttons[btn_id] for btn_id in button_ids]
        
    def create_category_layout(self, category: str) -> ResponsiveButtonLayout:
        """カテゴリ別レイアウト作成"""
        buttons = self.get_buttons_by_category(category)
        layout = ResponsiveButtonLayout(buttons)
        self.layouts[category] = layout
        return layout
        
    def set_button_state(self, button_id: str, state: ButtonState, progress: int = 0):
        """ボタン状態設定"""
        button = self.buttons.get(button_id)
        if button:
            button.set_state(state, progress)
            
    def update_button_progress(self, button_id: str, progress: int):
        """ボタン進捗更新"""
        button = self.buttons.get(button_id)
        if button:
            button.update_progress(progress)
            
    def enable_buttons(self, button_ids: List[str] = None):
        """ボタン有効化"""
        target_buttons = button_ids or list(self.buttons.keys())
        for button_id in target_buttons:
            button = self.buttons.get(button_id)
            if button:
                button.set_state(ButtonState.IDLE)
                
    def disable_buttons(self, button_ids: List[str] = None):
        """ボタン無効化"""
        target_buttons = button_ids or list(self.buttons.keys())
        for button_id in target_buttons:
            button = self.buttons.get(button_id)
            if button:
                button.set_state(ButtonState.DISABLED)
                
    def get_button_stats(self) -> Dict[str, Any]:
        """ボタン統計情報取得"""
        stats = {
            "total_buttons": len(self.buttons),
            "categories": len(self.button_groups),
            "states": {},
            "category_counts": {}
        }
        
        # 状態別集計
        for button in self.buttons.values():
            state = button.current_state.value
            stats["states"][state] = stats["states"].get(state, 0) + 1
            
        # カテゴリ別集計
        for category, button_ids in self.button_groups.items():
            stats["category_counts"][category] = len(button_ids)
            
        return stats


if __name__ == "__main__":
    from PyQt6.QtWidgets import QApplication, QMainWindow, QTabWidget
    
    app = QApplication(sys.argv)
    
    # テスト用メインウィンドウ
    main_window = QMainWindow()
    main_window.setWindowTitle("Enhanced Button Manager Test")
    main_window.resize(1000, 700)
    
    # ボタンマネージャー作成
    button_manager = EnhancedButtonManager()
    
    # タブウィジェット作成
    tab_widget = QTabWidget()
    
    # カテゴリ別タブ追加
    categories = [
        ("regular_reports", "📊 定期レポート"),
        ("analytics", "🔍 分析レポート"),
        ("entra_id", "👥 Entra ID"),
        ("exchange", "📧 Exchange"),
        ("teams", "💬 Teams"),
        ("onedrive", "💾 OneDrive"),
        ("all", "🌟 全機能")
    ]
    
    for category, tab_name in categories:
        layout = button_manager.create_category_layout(category)
        tab_widget.addTab(layout, tab_name)
    
    main_window.setCentralWidget(tab_widget)
    
    # シグナル接続テスト
    def on_button_clicked(button_id: str, category: str):
        print(f"Button clicked: {button_id} (category: {category})")
        button_manager.set_button_state(button_id, ButtonState.LOADING)
        
        # 3秒後に成功状態に変更
        QTimer.singleShot(3000, lambda: button_manager.set_button_state(button_id, ButtonState.SUCCESS))
    
    button_manager.button_clicked.connect(on_button_clicked)
    
    main_window.show()
    
    # 統計情報表示
    stats = button_manager.get_button_stats()
    print(f"Button Manager Stats: {stats}")
    
    sys.exit(app.exec())