"""
Logging configuration for Microsoft365 Management Tools.
Provides colored console output and file logging with rotation.
"""

import logging
import logging.handlers
import os
from pathlib import Path
from datetime import datetime
import colorlog


def setup_logging(
    log_level: str = "INFO",
    log_dir: str = "Logs",
    log_file: str = None,
    console: bool = True,
    file: bool = True
):
    """
    Setup logging configuration.
    
    Args:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_dir: Directory for log files
        log_file: Log file name (default: m365_tools_YYYYMMDD.log)
        console: Enable console logging
        file: Enable file logging
    """
    # Create log directory if needed
    if file:
        log_path = Path(log_dir)
        log_path.mkdir(parents=True, exist_ok=True)
        
        if not log_file:
            log_file = f"m365_tools_{datetime.now().strftime('%Y%m%d')}.log"
        
        log_file_path = log_path / log_file
    
    # Root logger configuration
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper()))
    
    # Remove existing handlers
    root_logger.handlers = []
    
    # Console handler with color
    if console:
        console_handler = colorlog.StreamHandler()
        console_handler.setLevel(getattr(logging, log_level.upper()))
        
        # Color formatter for console
        console_formatter = colorlog.ColoredFormatter(
            '%(log_color)s%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S',
            log_colors={
                'DEBUG': 'cyan',
                'INFO': 'green',
                'WARNING': 'yellow',
                'ERROR': 'red',
                'CRITICAL': 'red,bg_white',
            }
        )
        console_handler.setFormatter(console_formatter)
        root_logger.addHandler(console_handler)
    
    # File handler with rotation
    if file:
        file_handler = logging.handlers.RotatingFileHandler(
            log_file_path,
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5,
            encoding='utf-8'
        )
        file_handler.setLevel(getattr(logging, log_level.upper()))
        
        # Detailed formatter for file
        file_formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(funcName)s() - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(file_formatter)
        root_logger.addHandler(file_handler)
    
    # Log initial message
    logger = logging.getLogger(__name__)
    logger.info(f"Logging initialized - Level: {log_level}, Console: {console}, File: {file}")
    if file:
        logger.info(f"Log file: {log_file_path}")


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance.
    
    Args:
        name: Logger name (usually __name__)
        
    Returns:
        Logger instance
    """
    return logging.getLogger(name)


class GuiLogHandler(logging.Handler):
    """
    Custom log handler for GUI log display.
    Emits log records to GUI components.
    """
    
    def __init__(self, callback):
        super().__init__()
        self.callback = callback
        
    def emit(self, record):
        """Emit a log record to GUI."""
        try:
            msg = self.format(record)
            self.callback(msg, record.levelname)
        except Exception:
            self.handleError(record)