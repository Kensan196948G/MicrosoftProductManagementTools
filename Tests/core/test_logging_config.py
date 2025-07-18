"""
Unit tests for logging configuration module.
Tests logging setup, handlers, formatters, and GUI log handler.
"""

import logging
import logging.handlers
import os
import pytest
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock, call
from io import StringIO

from src.core.logging_config import setup_logging, get_logger, GuiLogHandler


class TestLoggingSetup:
    """Test suite for logging setup functionality."""
    
    def setup_method(self):
        """Setup test environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.log_dir = Path(self.temp_dir) / "logs"
        
        # Clear any existing handlers
        root_logger = logging.getLogger()
        root_logger.handlers.clear()
        root_logger.setLevel(logging.WARNING)
    
    def teardown_method(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
        
        # Clear handlers again
        root_logger = logging.getLogger()
        root_logger.handlers.clear()
    
    def test_setup_logging_default_params(self):
        """Test logging setup with default parameters."""
        setup_logging()
        
        root_logger = logging.getLogger()
        assert root_logger.level == logging.INFO
        assert len(root_logger.handlers) >= 1
    
    def test_setup_logging_custom_level(self):
        """Test logging setup with custom log level."""
        setup_logging(log_level="DEBUG")
        
        root_logger = logging.getLogger()
        assert root_logger.level == logging.DEBUG
    
    def test_setup_logging_invalid_level(self):
        """Test logging setup with invalid log level."""
        with pytest.raises(AttributeError):
            setup_logging(log_level="INVALID_LEVEL")
    
    def test_setup_logging_console_only(self):
        """Test logging setup with console handler only."""
        setup_logging(console=True, file=False)
        
        root_logger = logging.getLogger()
        assert len(root_logger.handlers) == 1
        assert isinstance(root_logger.handlers[0], logging.StreamHandler)
    
    def test_setup_logging_file_only(self):
        """Test logging setup with file handler only."""
        setup_logging(
            console=False, 
            file=True, 
            log_dir=str(self.log_dir),
            log_file="test.log"
        )
        
        root_logger = logging.getLogger()
        assert len(root_logger.handlers) == 1
        assert isinstance(root_logger.handlers[0], logging.handlers.RotatingFileHandler)
        
        # Check if log file was created
        log_file = self.log_dir / "test.log"
        assert log_file.exists()
    
    def test_setup_logging_both_handlers(self):
        """Test logging setup with both console and file handlers."""
        setup_logging(
            console=True, 
            file=True, 
            log_dir=str(self.log_dir),
            log_file="test.log"
        )
        
        root_logger = logging.getLogger()
        assert len(root_logger.handlers) == 2
        
        handler_types = [type(h) for h in root_logger.handlers]
        assert any(issubclass(t, logging.StreamHandler) for t in handler_types)
        assert any(issubclass(t, logging.handlers.RotatingFileHandler) for t in handler_types)
    
    def test_setup_logging_no_handlers(self):
        """Test logging setup with no handlers."""
        setup_logging(console=False, file=False)
        
        root_logger = logging.getLogger()
        assert len(root_logger.handlers) == 0
    
    def test_setup_logging_creates_log_directory(self):
        """Test that logging setup creates log directory if it doesn't exist."""
        log_dir = self.log_dir / "nested" / "directory"
        
        setup_logging(
            console=False, 
            file=True, 
            log_dir=str(log_dir),
            log_file="test.log"
        )
        
        assert log_dir.exists()
        assert (log_dir / "test.log").exists()
    
    def test_setup_logging_default_filename(self):
        """Test logging setup with default filename generation."""
        setup_logging(
            console=False, 
            file=True, 
            log_dir=str(self.log_dir)
        )
        
        # Should create file with date pattern
        log_files = list(self.log_dir.glob("m365_tools_*.log"))
        assert len(log_files) == 1
        assert "m365_tools_" in log_files[0].name
    
    def test_setup_logging_file_rotation(self):
        """Test file handler rotation configuration."""
        setup_logging(
            console=False, 
            file=True, 
            log_dir=str(self.log_dir),
            log_file="test.log"
        )
        
        root_logger = logging.getLogger()
        file_handler = root_logger.handlers[0]
        
        assert isinstance(file_handler, logging.handlers.RotatingFileHandler)
        assert file_handler.maxBytes == 10 * 1024 * 1024  # 10MB
        assert file_handler.backupCount == 5
    
    def test_setup_logging_formatter_console(self):
        """Test console formatter configuration."""
        setup_logging(console=True, file=False)
        
        root_logger = logging.getLogger()
        console_handler = root_logger.handlers[0]
        
        # Check formatter is set
        assert console_handler.formatter is not None
        
        # Test formatter output
        record = logging.LogRecord(
            name="test", level=logging.INFO, pathname="", lineno=0,
            msg="Test message", args=(), exc_info=None
        )
        
        formatted = console_handler.formatter.format(record)
        assert "Test message" in formatted
    
    def test_setup_logging_formatter_file(self):
        """Test file formatter configuration."""
        setup_logging(
            console=False, 
            file=True, 
            log_dir=str(self.log_dir),
            log_file="test.log"
        )
        
        root_logger = logging.getLogger()
        file_handler = root_logger.handlers[0]
        
        # Check formatter is set
        assert file_handler.formatter is not None
        
        # Test formatter output includes detailed information
        record = logging.LogRecord(
            name="test", level=logging.INFO, pathname="/path/to/file.py", lineno=42,
            msg="Test message", args=(), exc_info=None, func="test_function"
        )
        
        formatted = file_handler.formatter.format(record)
        assert "Test message" in formatted
        assert "test_function" in formatted
        assert "42" in formatted
    
    def test_setup_logging_multiple_calls(self):
        """Test that multiple calls to setup_logging replace handlers."""
        # First call
        setup_logging(console=True, file=False)
        root_logger = logging.getLogger()
        assert len(root_logger.handlers) == 1
        
        # Second call
        setup_logging(console=True, file=True, log_dir=str(self.log_dir))
        assert len(root_logger.handlers) == 2
        
        # Third call
        setup_logging(console=False, file=True, log_dir=str(self.log_dir))
        assert len(root_logger.handlers) == 1
    
    def test_setup_logging_encoding(self):
        """Test file handler uses UTF-8 encoding."""
        setup_logging(
            console=False, 
            file=True, 
            log_dir=str(self.log_dir),
            log_file="test.log"
        )
        
        root_logger = logging.getLogger()
        file_handler = root_logger.handlers[0]
        
        # Check encoding is set correctly
        assert file_handler.encoding == 'utf-8'
    
    def test_setup_logging_error_handling(self):
        """Test error handling in logging setup."""
        # Test with read-only directory
        readonly_dir = Path(self.temp_dir) / "readonly"
        readonly_dir.mkdir()
        readonly_dir.chmod(0o444)
        
        try:
            # Should not raise exception
            setup_logging(
                console=False, 
                file=True, 
                log_dir=str(readonly_dir),
                log_file="test.log"
            )
        except Exception as e:
            # If it does raise, should be handled gracefully
            assert "permission" in str(e).lower() or "access" in str(e).lower()
        finally:
            readonly_dir.chmod(0o755)


class TestGetLogger:
    """Test suite for get_logger function."""
    
    def test_get_logger_returns_logger(self):
        """Test that get_logger returns a Logger instance."""
        logger = get_logger("test_module")
        assert isinstance(logger, logging.Logger)
        assert logger.name == "test_module"
    
    def test_get_logger_same_name_same_instance(self):
        """Test that get_logger returns the same instance for the same name."""
        logger1 = get_logger("test_module")
        logger2 = get_logger("test_module")
        assert logger1 is logger2
    
    def test_get_logger_different_names(self):
        """Test that get_logger returns different instances for different names."""
        logger1 = get_logger("module1")
        logger2 = get_logger("module2")
        assert logger1 is not logger2
        assert logger1.name == "module1"
        assert logger2.name == "module2"
    
    def test_get_logger_with_dunder_name(self):
        """Test get_logger with __name__ pattern."""
        logger = get_logger(__name__)
        assert logger.name == __name__


class TestGuiLogHandler:
    """Test suite for GuiLogHandler class."""
    
    def test_gui_log_handler_initialization(self):
        """Test GuiLogHandler initialization."""
        callback = MagicMock()
        handler = GuiLogHandler(callback)
        
        assert handler.callback is callback
        assert isinstance(handler, logging.Handler)
    
    def test_gui_log_handler_emit_success(self):
        """Test GuiLogHandler emit method with successful callback."""
        callback = MagicMock()
        handler = GuiLogHandler(callback)
        
        # Create a log record
        record = logging.LogRecord(
            name="test", level=logging.INFO, pathname="", lineno=0,
            msg="Test message", args=(), exc_info=None
        )
        
        # Set a formatter
        formatter = logging.Formatter('%(message)s')
        handler.setFormatter(formatter)
        
        # Emit the record
        handler.emit(record)
        
        # Verify callback was called
        callback.assert_called_once_with("Test message", "INFO")
    
    def test_gui_log_handler_emit_with_args(self):
        """Test GuiLogHandler emit method with message arguments."""
        callback = MagicMock()
        handler = GuiLogHandler(callback)
        
        # Create a log record with arguments
        record = logging.LogRecord(
            name="test", level=logging.WARNING, pathname="", lineno=0,
            msg="Test message: %s", args=("formatted",), exc_info=None
        )
        
        # Set a formatter
        formatter = logging.Formatter('%(message)s')
        handler.setFormatter(formatter)
        
        # Emit the record
        handler.emit(record)
        
        # Verify callback was called with formatted message
        callback.assert_called_once_with("Test message: formatted", "WARNING")
    
    def test_gui_log_handler_emit_error_handling(self):
        """Test GuiLogHandler emit method with callback error."""
        callback = MagicMock()
        callback.side_effect = Exception("Callback error")
        handler = GuiLogHandler(callback)
        
        # Mock handleError method
        handler.handleError = MagicMock()
        
        # Create a log record
        record = logging.LogRecord(
            name="test", level=logging.ERROR, pathname="", lineno=0,
            msg="Test message", args=(), exc_info=None
        )
        
        # Set a formatter
        formatter = logging.Formatter('%(message)s')
        handler.setFormatter(formatter)
        
        # Emit the record
        handler.emit(record)
        
        # Verify handleError was called
        handler.handleError.assert_called_once_with(record)
    
    def test_gui_log_handler_different_log_levels(self):
        """Test GuiLogHandler with different log levels."""
        callback = MagicMock()
        handler = GuiLogHandler(callback)
        formatter = logging.Formatter('%(message)s')
        handler.setFormatter(formatter)
        
        # Test different log levels
        levels = [
            (logging.DEBUG, "DEBUG"),
            (logging.INFO, "INFO"),
            (logging.WARNING, "WARNING"),
            (logging.ERROR, "ERROR"),
            (logging.CRITICAL, "CRITICAL")
        ]
        
        for level_num, level_name in levels:
            record = logging.LogRecord(
                name="test", level=level_num, pathname="", lineno=0,
                msg=f"Test {level_name} message", args=(), exc_info=None
            )
            
            handler.emit(record)
        
        # Verify all levels were handled
        assert callback.call_count == len(levels)
        
        # Check specific calls
        calls = callback.call_args_list
        for i, (level_num, level_name) in enumerate(levels):
            assert calls[i] == call(f"Test {level_name} message", level_name)
    
    def test_gui_log_handler_with_complex_formatter(self):
        """Test GuiLogHandler with complex formatter."""
        callback = MagicMock()
        handler = GuiLogHandler(callback)
        
        # Set a complex formatter
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        handler.setFormatter(formatter)
        
        # Create a log record
        record = logging.LogRecord(
            name="test.module", level=logging.INFO, pathname="", lineno=0,
            msg="Test message", args=(), exc_info=None
        )
        
        # Emit the record
        handler.emit(record)
        
        # Verify callback was called with formatted message
        callback.assert_called_once()
        args, kwargs = callback.call_args
        formatted_message, level = args
        
        assert "test.module" in formatted_message
        assert "INFO" in formatted_message
        assert "Test message" in formatted_message
        assert level == "INFO"


class TestLoggingIntegration:
    """Integration tests for logging functionality."""
    
    def setup_method(self):
        """Setup test environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.log_dir = Path(self.temp_dir) / "logs"
        
        # Clear any existing handlers
        root_logger = logging.getLogger()
        root_logger.handlers.clear()
    
    def teardown_method(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
        
        # Clear handlers again
        root_logger = logging.getLogger()
        root_logger.handlers.clear()
    
    def test_end_to_end_logging_flow(self):
        """Test complete logging flow from setup to message output."""
        # Setup logging
        setup_logging(
            log_level="INFO",
            console=True,
            file=True,
            log_dir=str(self.log_dir),
            log_file="test.log"
        )
        
        # Get logger and log messages
        logger = get_logger("test_module")
        
        logger.debug("Debug message")  # Should not appear (level is INFO)
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")
        
        # Check that log file was created and contains messages
        log_file = self.log_dir / "test.log"
        assert log_file.exists()
        
        log_content = log_file.read_text(encoding='utf-8')
        assert "Info message" in log_content
        assert "Warning message" in log_content
        assert "Error message" in log_content
        assert "Critical message" in log_content
        assert "Debug message" not in log_content  # Should be filtered out
    
    def test_gui_integration_with_logging(self):
        """Test GUI handler integration with logging system."""
        # Setup logging with GUI handler
        setup_logging(console=False, file=False)
        
        # Add GUI handler
        gui_callback = MagicMock()
        gui_handler = GuiLogHandler(gui_callback)
        gui_handler.setLevel(logging.INFO)
        
        root_logger = logging.getLogger()
        root_logger.addHandler(gui_handler)
        
        # Get logger and log messages
        logger = get_logger("gui_test")
        
        logger.info("GUI message")
        logger.error("GUI error")
        
        # Verify GUI callback was called
        assert gui_callback.call_count == 2
        
        # Check specific calls
        calls = gui_callback.call_args_list
        assert any("GUI message" in str(call) for call in calls)
        assert any("GUI error" in str(call) for call in calls)
    
    def test_logging_with_japanese_characters(self):
        """Test logging with Japanese characters."""
        setup_logging(
            console=False,
            file=True,
            log_dir=str(self.log_dir),
            log_file="japanese.log"
        )
        
        logger = get_logger("japanese_test")
        
        # Log messages with Japanese characters
        logger.info("テストメッセージ")
        logger.warning("警告：日本語のメッセージ")
        logger.error("エラー：ファイルが見つかりません")
        
        # Check that log file contains Japanese characters
        log_file = self.log_dir / "japanese.log"
        assert log_file.exists()
        
        log_content = log_file.read_text(encoding='utf-8')
        assert "テストメッセージ" in log_content
        assert "警告：日本語のメッセージ" in log_content
        assert "エラー：ファイルが見つかりません" in log_content
    
    def test_logging_performance_large_volume(self):
        """Test logging performance with large volume of messages."""
        setup_logging(
            console=False,
            file=True,
            log_dir=str(self.log_dir),
            log_file="performance.log"
        )
        
        logger = get_logger("performance_test")
        
        # Log many messages
        import time
        start_time = time.time()
        
        for i in range(1000):
            logger.info(f"Performance test message {i}")
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Should complete reasonably quickly (less than 5 seconds)
        assert duration < 5.0
        
        # Check that all messages were logged
        log_file = self.log_dir / "performance.log"
        log_content = log_file.read_text(encoding='utf-8')
        assert "Performance test message 999" in log_content
    
    def test_logging_thread_safety(self):
        """Test logging thread safety."""
        import threading
        import time
        
        setup_logging(
            console=False,
            file=True,
            log_dir=str(self.log_dir),
            log_file="thread_test.log"
        )
        
        logger = get_logger("thread_test")
        results = []
        
        def log_messages(thread_id):
            for i in range(100):
                logger.info(f"Thread {thread_id} message {i}")
                results.append(f"Thread {thread_id} message {i}")
        
        # Create and start multiple threads
        threads = []
        for i in range(5):
            thread = threading.Thread(target=log_messages, args=(i,))
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # Check that all messages were logged
        log_file = self.log_dir / "thread_test.log"
        log_content = log_file.read_text(encoding='utf-8')
        
        # Should have all 500 messages (5 threads × 100 messages)
        assert len(results) == 500
        
        # Check that messages from all threads are present
        for i in range(5):
            assert f"Thread {i} message 99" in log_content