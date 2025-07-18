#!/usr/bin/env python3
"""
Main entry point for Microsoft365 Management Tools
"""

import sys
import logging
import argparse
from pathlib import Path

# Add src to Python path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.core.config import Config
from src.core.logging_config import setup_logging
from src.gui.main_window import MainWindow
from src.cli.cli_app import CLIApp


def main_gui():
    """Launch GUI application."""
    setup_logging()
    logger = logging.getLogger(__name__)
    
    try:
        logger.info("Starting Microsoft365 Management Tools GUI...")
        
        # Load configuration
        config = Config()
        config.load()
        
        # Check if running in STA mode (Windows requirement)
        if sys.platform == "win32":
            import ctypes
            try:
                ctypes.windll.ole32.CoInitialize()
            except:
                pass
        
        # Launch GUI
        from PyQt6.QtWidgets import QApplication
        app = QApplication(sys.argv)
        app.setApplicationName("Microsoft365 Management Tools")
        app.setOrganizationName("Enterprise IT")
        
        window = MainWindow(config)
        window.show()
        
        sys.exit(app.exec())
        
    except Exception as e:
        logger.error(f"Failed to start GUI: {e}", exc_info=True)
        sys.exit(1)


def main_cli():
    """Launch CLI application."""
    setup_logging()
    logger = logging.getLogger(__name__)
    
    parser = argparse.ArgumentParser(
        description="Microsoft365 Management Tools - CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        "command",
        nargs="?",
        help="Command to execute (use 'menu' for interactive mode)"
    )
    
    parser.add_argument(
        "--batch",
        action="store_true",
        help="Run in batch mode (non-interactive)"
    )
    
    parser.add_argument(
        "--output",
        choices=["html", "csv", "both"],
        default="both",
        help="Output format (default: both)"
    )
    
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="Output directory for reports"
    )
    
    args = parser.parse_args()
    
    try:
        logger.info("Starting Microsoft365 Management Tools CLI...")
        
        # Load configuration
        config = Config()
        config.load()
        
        # Launch CLI
        cli = CLIApp(config)
        
        if args.command:
            cli.execute_command(
                args.command,
                batch_mode=args.batch,
                output_format=args.output,
                output_dir=args.output_dir
            )
        else:
            cli.run_interactive()
            
    except Exception as e:
        logger.error(f"Failed to start CLI: {e}", exc_info=True)
        sys.exit(1)


def main():
    """Main entry point - determine GUI or CLI mode."""
    if len(sys.argv) > 1 and sys.argv[1] in ["cli", "--cli", "-c"]:
        # Remove the CLI flag and run CLI
        sys.argv.pop(1)
        main_cli()
    else:
        main_gui()


if __name__ == "__main__":
    main()