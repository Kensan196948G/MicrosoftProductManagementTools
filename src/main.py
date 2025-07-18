#!/usr/bin/env python3
"""
Main entry point for Microsoft365 Management Tools
完全版 Python Edition v2.0 - GUI/CLI 統合ランチャー
"""

import sys
import logging
import argparse
import os
from pathlib import Path

# Add src to Python path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.core.config import Config
from src.core.logging_config import setup_logging


def main_gui():
    """Launch GUI application with PowerShell compatibility."""
    setup_logging()
    logger = logging.getLogger(__name__)
    
    try:
        logger.info("🚀 Microsoft365 Management Tools GUI 起動中...")
        
        # Platform check
        if sys.platform not in ["win32", "darwin", "linux"]:
            logger.error(f"未対応のプラットフォーム: {sys.platform}")
            sys.exit(1)
            
        # Load configuration
        config = Config()
        config.load()
        
        # Check if running in STA mode (Windows requirement)
        if sys.platform == "win32":
            import ctypes
            try:
                ctypes.windll.ole32.CoInitialize()
                logger.info("Windows COM初期化完了")
            except Exception as e:
                logger.warning(f"Windows COM初期化失敗: {e}")
        
        # Launch GUI
        from PyQt6.QtWidgets import QApplication
        from PyQt6.QtCore import QLocale, Qt
        from PyQt6.QtGui import QFont
        from src.gui.main_window import MainWindow
        QApplication.setAttribute(Qt.ApplicationAttribute.AA_EnableHighDpiScaling, True)
        QApplication.setAttribute(Qt.ApplicationAttribute.AA_UseHighDpiPixmaps, True)
        
        app = QApplication(sys.argv)
        app.setApplicationName("Microsoft365 Management Tools")
        app.setOrganizationName("Enterprise IT")
        app.setApplicationVersion("2.0")
        
        # Set application font
        try:
            font = QFont("Yu Gothic UI", 9)
            app.setFont(font)
        except Exception:
            pass
        
        # Set locale to Japanese
        QLocale.setDefault(QLocale(QLocale.Language.Japanese, QLocale.Country.Japan))
        
        logger.info("PyQt6 アプリケーション初期化完了")
        
        window = MainWindow(config)
        window.show()
        
        logger.info("GUI アプリケーション起動完了")
        sys.exit(app.exec())
        
    except ImportError as e:
        logger.error(f"PyQt6インポートエラー: {e}")
        print("エラー: PyQt6がインストールされていません。")
        print("インストール: pip install PyQt6")
        sys.exit(1)
    except Exception as e:
        logger.error(f"GUI起動失敗: {e}", exc_info=True)
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
        from src.cli.cli_app import CLIApp
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
    # Show banner
    print("=" * 80)
    print("🚀 Microsoft 365 統合管理ツール - 完全版 Python Edition v2.0")
    print("   PowerShell GUI完全互換 - 26機能搭載")
    print("=" * 80)
    
    if len(sys.argv) > 1 and sys.argv[1] in ["cli", "--cli", "-c"]:
        # Remove the CLI flag and run CLI
        sys.argv.pop(1)
        print("📋 CLI モードで起動中...")
        main_cli()
    else:
        print("🖥️  GUI モードで起動中...")
        main_gui()


if __name__ == "__main__":
    main()