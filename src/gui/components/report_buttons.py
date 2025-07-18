"""
Report buttons widget for function categories.
Enhanced implementation with PowerShell GUI compatibility.
"""

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QGridLayout,
    QPushButton, QLabel, QGroupBox, QSizePolicy
)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QFont, QIcon
from typing import Dict, List, Tuple, Optional


class ReportButtonsWidget(QWidget):
    """Enhanced report buttons widget with PowerShell GUI compatibility."""
    
    # Signal emitted when a function button is clicked
    function_clicked = pyqtSignal(str)  # action_name
    
    def __init__(self):
        super().__init__()
        self.buttons: Dict[str, QPushButton] = {}
        self._init_ui()
        
    def _init_ui(self):
        """Initialize UI with function categories."""
        main_layout = QVBoxLayout(self)
        main_layout.setSpacing(15)
        main_layout.setContentsMargins(10, 10, 10, 10)
        
        # Create function categories
        self._create_regular_reports_group(main_layout)
        self._create_analysis_reports_group(main_layout)
        self._create_entra_id_group(main_layout)
        self._create_exchange_group(main_layout)
        self._create_teams_group(main_layout)
        self._create_onedrive_group(main_layout)
        
        # Add stretch to bottom
        main_layout.addStretch()
        
    def _create_regular_reports_group(self, parent_layout: QVBoxLayout):
        """Create regular reports group (6 functions)."""
        group = QGroupBox("📊 定期レポート")
        group.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        layout = QGridLayout(group)
        
        buttons = [
            ("📅 日次レポート", "daily_report", 0, 0),
            ("📊 週次レポート", "weekly_report", 0, 1),
            ("📈 月次レポート", "monthly_report", 0, 2),
            ("📆 年次レポート", "yearly_report", 1, 0),
            ("🧪 テスト実行", "test_execution", 1, 1),
            ("📋 最新日次表示", "show_latest_daily", 1, 2),
        ]
        
        self._create_buttons(layout, buttons)
        parent_layout.addWidget(group)
        
    def _create_analysis_reports_group(self, parent_layout: QVBoxLayout):
        """Create analysis reports group (5 functions)."""
        group = QGroupBox("🔍 分析レポート")
        group.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        layout = QGridLayout(group)
        
        buttons = [
            ("📊 ライセンス分析", "license_analysis", 0, 0),
            ("📈 使用状況分析", "usage_analysis", 0, 1),
            ("⚡ パフォーマンス分析", "performance_analysis", 0, 2),
            ("🛡️ セキュリティ分析", "security_analysis", 1, 0),
            ("🔍 権限監査", "permission_audit", 1, 1),
        ]
        
        self._create_buttons(layout, buttons)
        parent_layout.addWidget(group)
        
    def _create_entra_id_group(self, parent_layout: QVBoxLayout):
        """Create Entra ID management group (4 functions)."""
        group = QGroupBox("👥 Entra ID管理")
        group.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        layout = QGridLayout(group)
        
        buttons = [
            ("👥 ユーザー一覧", "user_list", 0, 0),
            ("🔐 MFA状況", "mfa_status", 0, 1),
            ("🛡️ 条件付きアクセス", "conditional_access", 1, 0),
            ("📋 サインインログ", "signin_logs", 1, 1),
        ]
        
        self._create_buttons(layout, buttons)
        parent_layout.addWidget(group)
        
    def _create_exchange_group(self, parent_layout: QVBoxLayout):
        """Create Exchange Online management group (4 functions)."""
        group = QGroupBox("📧 Exchange Online")
        group.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        layout = QGridLayout(group)
        
        buttons = [
            ("📧 メールボックス管理", "mailbox_management", 0, 0),
            ("📨 メールフロー分析", "mail_flow_analysis", 0, 1),
            ("🛡️ スパム対策", "spam_protection", 1, 0),
            ("📊 配信分析", "delivery_analysis", 1, 1),
        ]
        
        self._create_buttons(layout, buttons)
        parent_layout.addWidget(group)
        
    def _create_teams_group(self, parent_layout: QVBoxLayout):
        """Create Teams management group (4 functions)."""
        group = QGroupBox("💬 Teams管理")
        group.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        layout = QGridLayout(group)
        
        buttons = [
            ("💬 Teams使用状況", "teams_usage", 0, 0),
            ("⚙️ Teams設定", "teams_settings", 0, 1),
            ("📞 会議品質", "meeting_quality", 1, 0),
            ("📱 アプリ分析", "app_analysis", 1, 1),
        ]
        
        self._create_buttons(layout, buttons)
        parent_layout.addWidget(group)
        
    def _create_onedrive_group(self, parent_layout: QVBoxLayout):
        """Create OneDrive management group (4 functions)."""
        group = QGroupBox("💾 OneDrive管理")
        group.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        layout = QGridLayout(group)
        
        buttons = [
            ("💾 ストレージ分析", "storage_analysis", 0, 0),
            ("🔗 共有分析", "sharing_analysis", 0, 1),
            ("⚠️ 同期エラー", "sync_errors", 1, 0),
            ("🌐 外部共有分析", "external_sharing", 1, 1),
        ]
        
        self._create_buttons(layout, buttons)
        parent_layout.addWidget(group)
        
    def _create_buttons(self, layout: QGridLayout, buttons: List[Tuple[str, str, int, int]]):
        """Create buttons with consistent styling."""
        for text, action, row, col in buttons:
            button = self._create_function_button(text, action)
            layout.addWidget(button, row, col)
            self.buttons[action] = button
            
    def _create_function_button(self, text: str, action: str) -> QPushButton:
        """Create a function button with PowerShell GUI styling."""
        button = QPushButton(text)
        button.setMinimumSize(180, 45)
        button.setMaximumSize(220, 45)
        button.setFont(QFont("Yu Gothic UI", 9, QFont.Weight.Bold))
        button.setCursor(Qt.CursorShape.PointingHandCursor)
        button.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        
        # Apply PowerShell GUI compatible styling
        button.setStyleSheet("""
            QPushButton {
                background-color: #0078D7;
                color: white;
                border: 1px solid #005A9E;
                border-radius: 4px;
                padding: 8px 12px;
                text-align: center;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #0096F0;
                border-color: #0078D7;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
            }
            QPushButton:pressed {
                background-color: #005A9E;
                border-color: #004578;
                box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.3);
            }
            QPushButton:disabled {
                background-color: #CCCCCC;
                color: #666666;
                border-color: #BBBBBB;
                box-shadow: none;
            }
        """)
        
        # Connect button click
        button.clicked.connect(lambda: self.function_clicked.emit(action))
        
        return button
        
    def set_button_enabled(self, action: str, enabled: bool):
        """Enable or disable a specific button."""
        if action in self.buttons:
            self.buttons[action].setEnabled(enabled)
            
    def set_all_buttons_enabled(self, enabled: bool):
        """Enable or disable all buttons."""
        for button in self.buttons.values():
            button.setEnabled(enabled)
            
    def get_button_count(self) -> int:
        """Get total number of buttons."""
        return len(self.buttons)
        
    def get_button_actions(self) -> List[str]:
        """Get list of all button actions."""
        return list(self.buttons.keys())