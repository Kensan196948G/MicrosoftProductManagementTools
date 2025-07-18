"""
Log viewer widget for real-time log display.
Maintains compatibility with PowerShell Write-GuiLog functionality.
"""

from PyQt6.QtWidgets import QWidget, QVBoxLayout, QTextEdit, QTabWidget
from PyQt6.QtCore import Qt, pyqtSlot
from PyQt6.QtGui import QFont, QTextCursor, QTextCharFormat, QColor


class LogViewerWidget(QWidget):
    """
    Log viewer widget with color-coded log levels.
    Similar to PowerShell GUI's RichTextBox implementation.
    """
    
    def __init__(self):
        super().__init__()
        self._init_ui()
        
    def _init_ui(self):
        """Initialize UI components."""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # Create tab widget for logs
        self.tab_widget = QTabWidget()
        
        # Execution log tab
        self.execution_log = self._create_log_text_edit()
        self.tab_widget.addTab(self.execution_log, "📋 実行ログ")
        
        # Error log tab
        self.error_log = self._create_log_text_edit()
        self.tab_widget.addTab(self.error_log, "❌ エラーログ")
        
        # PowerShell prompt tab (for compatibility)
        self.prompt_log = self._create_log_text_edit()
        self.tab_widget.addTab(self.prompt_log, "💻 PowerShellプロンプト")
        
        layout.addWidget(self.tab_widget)
        
    def _create_log_text_edit(self) -> QTextEdit:
        """Create a styled text edit for logs."""
        text_edit = QTextEdit()
        text_edit.setReadOnly(True)
        text_edit.setFont(QFont("Consolas", 9))
        
        # Dark theme similar to PowerShell
        text_edit.setStyleSheet("""
            QTextEdit {
                background-color: #1E1E1E;
                color: #D4D4D4;
                border: none;
            }
        """)
        
        return text_edit
    
    @pyqtSlot(str, str)
    def add_log(self, message: str, level: str):
        """
        Add a log message with color coding.
        
        Args:
            message: Log message
            level: Log level (INFO, SUCCESS, WARNING, ERROR, DEBUG)
        """
        # Color mapping similar to PowerShell implementation
        color_map = {
            'INFO': QColor(0, 255, 255),      # Cyan
            'SUCCESS': QColor(0, 255, 0),     # Lime Green
            'WARNING': QColor(255, 165, 0),   # Orange
            'ERROR': QColor(255, 0, 0),       # Red
            'CRITICAL': QColor(255, 0, 0),    # Red
            'DEBUG': QColor(255, 0, 255),     # Magenta
        }
        
        # Get color for level
        color = color_map.get(level, QColor(212, 212, 212))
        
        # Determine target log
        if level in ['ERROR', 'CRITICAL']:
            target_log = self.error_log
        else:
            target_log = self.execution_log
            
        # Also add to prompt log
        self._append_colored_text(self.prompt_log, message, color)
        
        # Append to appropriate log
        self._append_colored_text(target_log, message, color)
    
    def _append_colored_text(self, text_edit: QTextEdit, text: str, color: QColor):
        """Append colored text to a QTextEdit."""
        cursor = text_edit.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        
        # Create format with color
        format = QTextCharFormat()
        format.setForeground(color)
        
        # Insert text with format
        cursor.insertText(text + '\n', format)
        
        # Scroll to bottom
        text_edit.setTextCursor(cursor)
        text_edit.ensureCursorVisible()
    
    def clear_logs(self):
        """Clear all logs."""
        self.execution_log.clear()
        self.error_log.clear()
        self.prompt_log.clear()
    
    def save_logs(self, file_path: str):
        """Save logs to file."""
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write("=== 実行ログ ===\n")
                f.write(self.execution_log.toPlainText())
                f.write("\n\n=== エラーログ ===\n")
                f.write(self.error_log.toPlainText())
                f.write("\n\n=== プロンプトログ ===\n")
                f.write(self.prompt_log.toPlainText())
        except Exception as e:
            self.add_log(f"ログ保存エラー: {e}", "ERROR")