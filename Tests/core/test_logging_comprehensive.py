#!/usr/bin/env python3
"""
Comprehensive Logging Module Tests - Emergency Coverage Boost
Tests all functions and classes in src/core/logging_config.py
"""

import pytest
import logging
import logging.handlers
import tempfile
import os
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime

from src.core.logging_config import setup_logging, get_logger, GuiLogHandler


class TestLoggingComprehensive:
    """Comprehensive tests for logging configuration to achieve 85%+ coverage."""
    
    def test_setup_logging_default_parameters(self):
        """Test setup_logging with default parameters."""
        with patch('pathlib.Path.mkdir') as mock_mkdir:
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                with patch('colorlog.StreamHandler') as mock_console:
                    setup_logging()
                    
                    mock_mkdir.assert_called_once()
                    mock_handler.assert_called_once()
                    mock_console.assert_called_once()
    
    def test_setup_logging_custom_parameters(self):
        """Test setup_logging with custom parameters."""
        with patch('pathlib.Path.mkdir') as mock_mkdir:
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                with patch('colorlog.StreamHandler') as mock_console:
                    setup_logging(
                        log_level="DEBUG",
                        log_dir="CustomLogs",
                        log_file="custom.log",
                        console=True,
                        file=True
                    )
                    
                    mock_mkdir.assert_called_once()
                    mock_handler.assert_called_once()
                    mock_console.assert_called_once()
    
    def test_setup_logging_console_only(self):
        """Test setup_logging with console logging only."""
        with patch('colorlog.StreamHandler') as mock_console:
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                setup_logging(console=True, file=False)
                
                mock_console.assert_called_once()
                mock_handler.assert_not_called()
    
    def test_setup_logging_file_only(self):
        """Test setup_logging with file logging only."""
        with patch('pathlib.Path.mkdir') as mock_mkdir:
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                with patch('colorlog.StreamHandler') as mock_console:
                    setup_logging(console=False, file=True)
                    
                    mock_mkdir.assert_called_once()
                    mock_handler.assert_called_once()
                    mock_console.assert_not_called()
    
    def test_setup_logging_no_logging(self):
        """Test setup_logging with no logging enabled."""
        with patch('pathlib.Path.mkdir') as mock_mkdir:
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                with patch('colorlog.StreamHandler') as mock_console:
                    setup_logging(console=False, file=False)
                    
                    mock_mkdir.assert_not_called()
                    mock_handler.assert_not_called()
                    mock_console.assert_not_called()
    
    def test_setup_logging_all_log_levels(self):
        """Test setup_logging with all log levels."""
        levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        
        for level in levels:
            with patch('pathlib.Path.mkdir'):
                with patch('logging.handlers.RotatingFileHandler'):
                    with patch('colorlog.StreamHandler'):
                        with patch('logging.getLogger') as mock_get_logger:
                            mock_logger = Mock()
                            mock_get_logger.return_value = mock_logger
                            
                            setup_logging(log_level=level)
                            
                            # Verify logger was called
                            mock_get_logger.assert_called()
    
    def test_setup_logging_invalid_log_level(self):
        """Test setup_logging with invalid log level."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    with pytest.raises(AttributeError):
                        setup_logging(log_level="INVALID")
    
    def test_setup_logging_case_insensitive_level(self):
        """Test setup_logging with case insensitive log level."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    with patch('logging.getLogger') as mock_get_logger:
                        mock_logger = Mock()
                        mock_get_logger.return_value = mock_logger
                        
                        setup_logging(log_level="debug")  # lowercase
                        
                        # Should work (converted to uppercase)
                        mock_get_logger.assert_called()
    
    def test_setup_logging_directory_creation(self):
        """Test setup_logging creates log directory."""
        with patch('pathlib.Path.mkdir') as mock_mkdir:
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    setup_logging(log_dir="test_logs")
                    
                    mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)
    
    def test_setup_logging_file_path_generation(self):
        """Test setup_logging generates correct file path."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                with patch('colorlog.StreamHandler'):
                    with patch('datetime.now') as mock_now:
                        mock_now.return_value = datetime(2024, 1, 18, 10, 30, 0)
                        
                        setup_logging(log_dir="test_logs", log_file=None)
                        
                        # Check file path contains date
                        call_args = mock_handler.call_args[0]
                        assert "20240118" in str(call_args[0])
    
    def test_setup_logging_custom_log_file(self):
        """Test setup_logging with custom log file name."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                with patch('colorlog.StreamHandler'):
                    setup_logging(log_dir="test_logs", log_file="custom.log")
                    
                    # Check custom file name is used
                    call_args = mock_handler.call_args[0]
                    assert "custom.log" in str(call_args[0])
    
    def test_setup_logging_handler_configuration(self):
        """Test setup_logging configures handlers correctly."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler') as mock_file_handler:
                with patch('colorlog.StreamHandler') as mock_console_handler:
                    mock_file_instance = Mock()
                    mock_console_instance = Mock()
                    mock_file_handler.return_value = mock_file_instance
                    mock_console_handler.return_value = mock_console_instance
                    
                    setup_logging(log_level="INFO")
                    
                    # Verify handlers were configured
                    mock_file_instance.setLevel.assert_called_once()
                    mock_console_instance.setLevel.assert_called_once()
                    mock_file_instance.setFormatter.assert_called_once()
                    mock_console_instance.setFormatter.assert_called_once()
    
    def test_setup_logging_rotating_file_handler_parameters(self):
        """Test setup_logging configures RotatingFileHandler with correct parameters."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler') as mock_handler:
                with patch('colorlog.StreamHandler'):
                    setup_logging()
                    
                    # Check handler parameters
                    call_args = mock_handler.call_args
                    assert call_args[1]['maxBytes'] == 10*1024*1024  # 10MB
                    assert call_args[1]['backupCount'] == 5
                    assert call_args[1]['encoding'] == 'utf-8'
    
    def test_setup_logging_formatter_configuration(self):
        """Test setup_logging configures formatters correctly."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler') as mock_file_handler:
                with patch('colorlog.StreamHandler') as mock_console_handler:
                    with patch('colorlog.ColoredFormatter') as mock_color_formatter:
                        with patch('logging.Formatter') as mock_formatter:
                            mock_file_instance = Mock()
                            mock_console_instance = Mock()
                            mock_file_handler.return_value = mock_file_instance
                            mock_console_handler.return_value = mock_console_instance
                            
                            setup_logging()
                            
                            # Verify formatters were created
                            mock_color_formatter.assert_called_once()
                            mock_formatter.assert_called_once()
    
    def test_setup_logging_root_logger_configuration(self):
        """Test setup_logging configures root logger correctly."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    with patch('logging.getLogger') as mock_get_logger:
                        mock_root_logger = Mock()
                        mock_get_logger.return_value = mock_root_logger
                        
                        setup_logging(log_level="WARNING")
                        
                        # Verify root logger configuration
                        mock_root_logger.setLevel.assert_called_with(logging.WARNING)
                        # Handlers should be cleared first
                        assert mock_root_logger.handlers == []
    
    def test_setup_logging_color_configuration(self):
        """Test setup_logging configures colors correctly."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    with patch('colorlog.ColoredFormatter') as mock_formatter:
                        setup_logging()
                        
                        # Check color configuration
                        call_args = mock_formatter.call_args
                        assert 'log_colors' in call_args[1]
                        colors = call_args[1]['log_colors']
                        assert colors['DEBUG'] == 'cyan'
                        assert colors['INFO'] == 'green'
                        assert colors['WARNING'] == 'yellow'
                        assert colors['ERROR'] == 'red'
                        assert colors['CRITICAL'] == 'red,bg_white'
    
    def test_setup_logging_initialization_message(self):
        """Test setup_logging logs initialization message."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    with patch('logging.getLogger') as mock_get_logger:
                        mock_logger = Mock()
                        mock_get_logger.return_value = mock_logger
                        
                        setup_logging(log_level="INFO", console=True, file=True)
                        
                        # Verify initialization messages
                        assert mock_logger.info.call_count >= 1
                        call_args = mock_logger.info.call_args_list
                        assert any("Logging initialized" in str(call) for call in call_args)
    
    def test_get_logger_basic(self):
        """Test get_logger returns logger instance."""
        with patch('logging.getLogger') as mock_get_logger:
            mock_logger = Mock()
            mock_get_logger.return_value = mock_logger
            
            result = get_logger("test_module")
            
            assert result == mock_logger
            mock_get_logger.assert_called_once_with("test_module")
    
    def test_get_logger_with_module_name(self):
        """Test get_logger with __name__ parameter."""
        with patch('logging.getLogger') as mock_get_logger:
            mock_logger = Mock()
            mock_get_logger.return_value = mock_logger
            
            result = get_logger(__name__)
            
            assert result == mock_logger
            mock_get_logger.assert_called_once_with(__name__)
    
    def test_get_logger_multiple_calls(self):
        """Test get_logger with multiple calls."""
        with patch('logging.getLogger') as mock_get_logger:
            mock_logger1 = Mock()
            mock_logger2 = Mock()
            mock_get_logger.side_effect = [mock_logger1, mock_logger2]
            
            result1 = get_logger("module1")
            result2 = get_logger("module2")
            
            assert result1 == mock_logger1
            assert result2 == mock_logger2
            assert mock_get_logger.call_count == 2
    
    def test_gui_log_handler_init(self):
        """Test GuiLogHandler initialization."""
        callback = Mock()
        handler = GuiLogHandler(callback)
        
        assert handler.callback == callback
        assert isinstance(handler, logging.Handler)
    
    def test_gui_log_handler_emit_success(self):
        """Test GuiLogHandler emit method success."""
        callback = Mock()
        handler = GuiLogHandler(callback)
        
        # Mock log record
        record = Mock()
        record.levelname = "INFO"
        
        with patch.object(handler, 'format', return_value="Test message"):
            handler.emit(record)
            
            callback.assert_called_once_with("Test message", "INFO")
    
    def test_gui_log_handler_emit_exception(self):
        """Test GuiLogHandler emit method with exception."""
        callback = Mock(side_effect=Exception("Callback error"))
        handler = GuiLogHandler(callback)
        
        record = Mock()
        record.levelname = "ERROR"
        
        with patch.object(handler, 'format', return_value="Test message"):
            with patch.object(handler, 'handleError') as mock_handle_error:
                handler.emit(record)
                
                mock_handle_error.assert_called_once_with(record)
    
    def test_gui_log_handler_emit_format_exception(self):
        """Test GuiLogHandler emit method with format exception."""
        callback = Mock()
        handler = GuiLogHandler(callback)
        
        record = Mock()
        record.levelname = "ERROR"
        
        with patch.object(handler, 'format', side_effect=Exception("Format error")):
            with patch.object(handler, 'handleError') as mock_handle_error:
                handler.emit(record)
                
                mock_handle_error.assert_called_once_with(record)
    
    def test_gui_log_handler_emit_different_levels(self):
        """Test GuiLogHandler emit method with different log levels."""
        callback = Mock()
        handler = GuiLogHandler(callback)
        
        levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        
        for level in levels:
            record = Mock()
            record.levelname = level
            
            with patch.object(handler, 'format', return_value=f"Test {level} message"):
                handler.emit(record)
                
                callback.assert_called_with(f"Test {level} message", level)
    
    def test_gui_log_handler_emit_callback_types(self):
        """Test GuiLogHandler emit method with different callback types."""
        # Test with lambda
        results = []
        callback = lambda msg, level: results.append((msg, level))
        handler = GuiLogHandler(callback)
        
        record = Mock()
        record.levelname = "INFO"
        
        with patch.object(handler, 'format', return_value="Lambda test"):
            handler.emit(record)
            
            assert len(results) == 1
            assert results[0] == ("Lambda test", "INFO")
    
    def test_integration_setup_and_get_logger(self):
        """Test integration of setup_logging and get_logger."""
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    setup_logging(log_level="INFO")
                    
                    logger = get_logger("test_integration")
                    
                    assert logger is not None
                    assert hasattr(logger, 'info')
                    assert hasattr(logger, 'error')
                    assert hasattr(logger, 'warning')
                    assert hasattr(logger, 'debug')
    
    def test_integration_gui_handler_with_setup(self):
        """Test integration of GuiLogHandler with setup_logging."""
        callback = Mock()
        
        with patch('pathlib.Path.mkdir'):
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    setup_logging(log_level="INFO")
                    
                    logger = get_logger("test_gui")
                    gui_handler = GuiLogHandler(callback)
                    logger.addHandler(gui_handler)
                    
                    # Test logging with GUI handler
                    with patch.object(gui_handler, 'format', return_value="GUI test message"):
                        record = Mock()
                        record.levelname = "INFO"
                        gui_handler.emit(record)
                        
                        callback.assert_called_once_with("GUI test message", "INFO")
    
    def test_edge_cases_empty_log_dir(self):
        """Test setup_logging with empty log directory."""
        with patch('pathlib.Path.mkdir') as mock_mkdir:
            with patch('logging.handlers.RotatingFileHandler'):
                with patch('colorlog.StreamHandler'):
                    setup_logging(log_dir="")
                    
                    mock_mkdir.assert_called_once()
    
    def test_edge_cases_special_characters_in_paths(self):
        """Test setup_logging with special characters in paths."""
        special_dirs = [
            "logs with spaces",
            "logs-with-dashes",
            "logs_with_underscores",
            "logs.with.dots",
            "logs/with/slashes"
        ]
        
        for log_dir in special_dirs:
            with patch('pathlib.Path.mkdir'):
                with patch('logging.handlers.RotatingFileHandler'):
                    with patch('colorlog.StreamHandler'):
                        setup_logging(log_dir=log_dir)
                        # Should not raise exceptions
    
    def test_edge_cases_unicode_in_log_messages(self):
        """Test GuiLogHandler with Unicode characters."""
        callback = Mock()
        handler = GuiLogHandler(callback)
        
        record = Mock()
        record.levelname = "INFO"
        
        unicode_messages = [
            "Hello, 世界!",
            "Café ☕",
            "🎉 Celebration 🎊",
            "åäöüß",
            "Здравствуй мир"
        ]
        
        for message in unicode_messages:
            with patch.object(handler, 'format', return_value=message):
                handler.emit(record)
                
                callback.assert_called_with(message, "INFO")
    
    def test_edge_cases_none_callback(self):
        """Test GuiLogHandler with None callback."""
        handler = GuiLogHandler(None)
        
        record = Mock()
        record.levelname = "INFO"
        
        with patch.object(handler, 'format', return_value="Test message"):
            with patch.object(handler, 'handleError') as mock_handle_error:
                handler.emit(record)
                
                mock_handle_error.assert_called_once_with(record)
    
    def test_edge_cases_invalid_callback(self):
        """Test GuiLogHandler with invalid callback."""
        handler = GuiLogHandler("not_a_function")
        
        record = Mock()
        record.levelname = "INFO"
        
        with patch.object(handler, 'format', return_value="Test message"):
            with patch.object(handler, 'handleError') as mock_handle_error:
                handler.emit(record)
                
                mock_handle_error.assert_called_once_with(record)
    
    def test_concurrency_safety(self):
        """Test thread safety of logging operations."""
        import threading
        
        results = []
        lock = threading.Lock()
        
        def thread_safe_callback(msg, level):
            with lock:
                results.append((msg, level))
        
        handler = GuiLogHandler(thread_safe_callback)
        
        def emit_log(thread_id):
            record = Mock()
            record.levelname = "INFO"
            
            with patch.object(handler, 'format', return_value=f"Thread {thread_id} message"):
                handler.emit(record)
        
        # Create multiple threads
        threads = []
        for i in range(10):
            thread = threading.Thread(target=emit_log, args=(i,))
            threads.append(thread)
            thread.start()
        
        # Wait for all threads
        for thread in threads:
            thread.join()
        
        # Verify all messages were logged
        assert len(results) == 10
        for i, (msg, level) in enumerate(results):
            assert "Thread" in msg
            assert level == "INFO"
    
    def test_memory_usage_large_messages(self):
        """Test GuiLogHandler with large messages."""
        callback = Mock()
        handler = GuiLogHandler(callback)
        
        record = Mock()
        record.levelname = "INFO"
        
        # Test with large message
        large_message = "A" * 1000000  # 1MB message
        
        with patch.object(handler, 'format', return_value=large_message):
            handler.emit(record)
            
            callback.assert_called_once_with(large_message, "INFO")
    
    def test_performance_multiple_handlers(self):
        """Test performance with multiple handlers."""
        callbacks = [Mock() for _ in range(100)]
        handlers = [GuiLogHandler(callback) for callback in callbacks]
        
        record = Mock()
        record.levelname = "INFO"
        
        # Test emitting to all handlers
        for handler in handlers:
            with patch.object(handler, 'format', return_value="Performance test"):
                handler.emit(record)
        
        # Verify all callbacks were called
        for callback in callbacks:
            callback.assert_called_once_with("Performance test", "INFO")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])