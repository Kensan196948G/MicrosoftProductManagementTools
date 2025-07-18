"""
Enhanced status bar widget with PowerShell GUI compatibility.
Includes progress tracking, connection status, and system info.
"""

from PyQt6.QtWidgets import (
    QWidget, QHBoxLayout, QLabel, QProgressBar, 
    QFrame, QSizePolicy, QStatusBar
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QFont, QPixmap, QIcon
from typing import Optional
import datetime


class EnhancedStatusBar(QStatusBar):
    """Enhanced status bar with PowerShell GUI compatibility."""
    
    # Signals for status updates
    connection_changed = pyqtSignal(bool)  # True if connected
    progress_changed = pyqtSignal(int, str)  # progress, message
    
    def __init__(self):
        super().__init__()
        self.is_connected = False
        self.current_operation = ""
        self._init_ui()
        self._setup_timer()
        
    def _init_ui(self):
        """Initialize status bar components."""
        self.setFont(QFont("Yu Gothic UI", 9))
        self.setStyleSheet("""
            QStatusBar {
                background-color: #F0F0F0;
                border-top: 1px solid #CCCCCC;
                padding: 2px;
            }
            QStatusBar::item {
                border: none;
            }
        """)
        
        # Main status label
        self.status_label = QLabel("準備完了")
        self.status_label.setFont(QFont("Yu Gothic UI", 9))
        self.status_label.setMinimumWidth(200)
        self.addWidget(self.status_label)
        
        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setMaximumWidth(200)
        self.progress_bar.setMinimumWidth(150)
        self.progress_bar.setMaximumHeight(16)
        self.progress_bar.setVisible(False)
        self.progress_bar.setStyleSheet("""
            QProgressBar {
                border: 1px solid #CCCCCC;
                border-radius: 3px;
                text-align: center;
                background-color: #F8F8F8;
                font-size: 8px;
            }
            QProgressBar::chunk {
                background-color: #0078D4;
                border-radius: 2px;
            }
        """)
        self.addPermanentWidget(self.progress_bar)
        
        # Separator
        separator1 = QFrame()
        separator1.setFrameShape(QFrame.Shape.VLine)
        separator1.setFrameShadow(QFrame.Shadow.Sunken)
        separator1.setStyleSheet("color: #CCCCCC;")
        self.addPermanentWidget(separator1)
        
        # Connection status
        self.connection_label = QLabel("❌ 未接続")
        self.connection_label.setFont(QFont("Yu Gothic UI", 9, QFont.Weight.Bold))
        self.connection_label.setStyleSheet("color: #D32F2F; padding: 0 5px;")
        self.connection_label.setMinimumWidth(80)
        self.addPermanentWidget(self.connection_label)
        
        # Separator
        separator2 = QFrame()
        separator2.setFrameShape(QFrame.Shape.VLine)
        separator2.setFrameShadow(QFrame.Shadow.Sunken)
        separator2.setStyleSheet("color: #CCCCCC;")
        self.addPermanentWidget(separator2)
        
        # Clock
        self.clock_label = QLabel()
        self.clock_label.setFont(QFont("Yu Gothic UI", 9))
        self.clock_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.clock_label.setMinimumWidth(120)
        self.addPermanentWidget(self.clock_label)
        
        # Separator
        separator3 = QFrame()
        separator3.setFrameShape(QFrame.Shape.VLine)
        separator3.setFrameShadow(QFrame.Shadow.Sunken)
        separator3.setStyleSheet("color: #CCCCCC;")
        self.addPermanentWidget(separator3)
        
        # System info
        self.system_label = QLabel("Python GUI v2.0")
        self.system_label.setFont(QFont("Yu Gothic UI", 8))
        self.system_label.setStyleSheet("color: #666666; padding: 0 5px;")
        self.addPermanentWidget(self.system_label)
        
    def _setup_timer(self):
        """Setup timer for clock updates."""
        self.timer = QTimer()
        self.timer.timeout.connect(self._update_clock)
        self.timer.start(1000)  # Update every second
        self._update_clock()  # Initial update
        
    def _update_clock(self):
        """Update clock display."""
        now = datetime.datetime.now()
        time_str = now.strftime("%Y/%m/%d %H:%M:%S")
        self.clock_label.setText(time_str)
        
    def set_status(self, message: str, timeout: int = 0):
        """Set status message with optional timeout."""
        self.status_label.setText(message)
        if timeout > 0:
            QTimer.singleShot(timeout * 1000, self._reset_status)
            
    def _reset_status(self):
        """Reset status to ready."""
        self.status_label.setText("準備完了")
        
    def set_connection_status(self, connected: bool, service: str = ""):
        """Set connection status."""
        self.is_connected = connected
        if connected:
            text = f"✅ 接続済み"
            if service:
                text += f" ({service})"
            self.connection_label.setText(text)
            self.connection_label.setStyleSheet("color: #388E3C; font-weight: bold; padding: 0 5px;")
        else:
            self.connection_label.setText("❌ 未接続")
            self.connection_label.setStyleSheet("color: #D32F2F; font-weight: bold; padding: 0 5px;")
        
        self.connection_changed.emit(connected)
        
    def show_progress(self, value: int, message: str = ""):
        """Show progress bar with value and optional message."""
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(value)
        
        if message:
            self.set_status(message)
            
        self.progress_changed.emit(value, message)
        
    def hide_progress(self):
        """Hide progress bar."""
        self.progress_bar.setVisible(False)
        self.progress_bar.setValue(0)
        
    def set_operation_status(self, operation: str, status: str = "実行中"):
        """Set operation status."""
        self.current_operation = operation
        self.set_status(f"{operation} - {status}")
        
    def complete_operation(self, operation: str, success: bool = True):
        """Complete operation with success/failure status."""
        if success:
            self.set_status(f"{operation} - 完了", 3)
        else:
            self.set_status(f"{operation} - エラー", 5)
        
        self.current_operation = ""
        self.hide_progress()
        
    def set_function_count(self, total: int, available: int):
        """Set function count information."""
        self.system_label.setText(f"機能: {available}/{total} 利用可能")
        
    def show_api_status(self, api_name: str, status: str):
        """Show API status information."""
        color = "#388E3C" if status == "正常" else "#D32F2F"
        self.system_label.setText(f"{api_name}: {status}")
        self.system_label.setStyleSheet(f"color: {color}; font-weight: bold; padding: 0 5px;")
        
    def reset_api_status(self):
        """Reset API status to default."""
        self.system_label.setText("Python GUI v2.0")
        self.system_label.setStyleSheet("color: #666666; padding: 0 5px;")
        
    def get_connection_status(self) -> bool:
        """Get current connection status."""
        return self.is_connected
        
    def get_current_operation(self) -> str:
        """Get current operation name."""
        return self.current_operation
        
    def animate_progress(self, duration_ms: int = 2000):
        """Animate progress bar for indefinite operations."""
        self.progress_bar.setVisible(True)
        self.progress_bar.setMinimum(0)
        self.progress_bar.setMaximum(0)  # Indeterminate progress
        
        # Reset after duration
        def reset_progress():
            self.progress_bar.setMaximum(100)
            self.progress_bar.setMinimum(0)
            self.hide_progress()
            
        QTimer.singleShot(duration_ms, reset_progress)
        
    def show_memory_usage(self, used_mb: float, total_mb: float):
        """Show memory usage information."""
        usage_percent = (used_mb / total_mb) * 100
        self.system_label.setText(f"メモリ: {used_mb:.1f}MB ({usage_percent:.1f}%)")
        
        # Color code based on usage
        if usage_percent > 80:
            color = "#D32F2F"
        elif usage_percent > 60:
            color = "#F57C00"
        else:
            color = "#388E3C"
            
        self.system_label.setStyleSheet(f"color: {color}; padding: 0 5px;")