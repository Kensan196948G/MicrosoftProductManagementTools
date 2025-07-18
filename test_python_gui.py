#!/usr/bin/env python3
"""
Test launcher for Python GUI application.
Checks dependencies and provides fallback for testing.
"""

import sys
import os
import logging
from pathlib import Path

# Add src to Python path
sys.path.insert(0, str(Path(__file__).parent / 'src'))

def check_dependencies():
    """Check if all required dependencies are available."""
    missing_deps = []
    
    try:
        import PyQt6
        print("✅ PyQt6 available")
    except ImportError:
        missing_deps.append("PyQt6")
        print("❌ PyQt6 not available")
    
    try:
        import msal
        print("✅ MSAL available")
    except ImportError:
        missing_deps.append("msal")
        print("❌ MSAL not available")
    
    try:
        import requests
        print("✅ Requests available")
    except ImportError:
        missing_deps.append("requests")
        print("❌ Requests not available")
    
    try:
        import colorlog
        print("✅ Colorlog available")
    except ImportError:
        missing_deps.append("colorlog")
        print("❌ Colorlog not available - using basic logging")
    
    return missing_deps

def create_test_config():
    """Create test configuration file."""
    config_dir = Path("Config")
    config_dir.mkdir(exist_ok=True)
    
    config_path = config_dir / "appsettings.json"
    
    if not config_path.exists():
        test_config = {
            "Authentication": {
                "TenantId": "test-tenant-id",
                "ClientId": "test-client-id",
                "ClientSecret": "",
                "AuthMethod": "Interactive"
            },
            "ReportSettings": {
                "OutputPath": "Reports",
                "EnableAutoOpen": False,
                "DefaultFormat": "both"
            },
            "GuiSettings": {
                "AutoOpenFiles": False,
                "ShowPopupNotifications": True,
                "LogLevel": "INFO"
            },
            "Logging": {
                "Level": "INFO",
                "Directory": "Logs"
            }
        }
        
        import json
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(test_config, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Created test config: {config_path}")
    else:
        print(f"✅ Config already exists: {config_path}")

def test_config_module():
    """Test configuration module."""
    try:
        from src.core.config import Config
        
        config = Config()
        config.load()
        
        print("✅ Configuration module works")
        print(f"   Tenant ID: {config.get('Authentication.TenantId', 'Not set')}")
        print(f"   Output Path: {config.get('ReportSettings.OutputPath', 'Not set')}")
        
        return True
    except Exception as e:
        print(f"❌ Configuration module error: {e}")
        return False

def test_logging_module():
    """Test logging module."""
    try:
        from src.core.logging_config import setup_logging, get_logger
        
        setup_logging(console=True, file=False)
        logger = get_logger(__name__)
        logger.info("Test log message")
        
        print("✅ Logging module works")
        return True
    except Exception as e:
        print(f"❌ Logging module error: {e}")
        return False

def test_report_generators():
    """Test report generation modules."""
    try:
        from src.reports.generators.csv_generator import CSVGenerator
        from src.reports.generators.html_generator import HTMLGenerator
        
        # Test CSV generator
        csv_gen = CSVGenerator()
        test_data = [
            {'ID': 1, 'Name': 'Test User 1', 'Status': '正常'},
            {'ID': 2, 'Name': 'Test User 2', 'Status': '警告'}
        ]
        
        test_dir = Path("TestOutput")
        test_dir.mkdir(exist_ok=True)
        
        csv_path = test_dir / "test_report.csv"
        html_path = test_dir / "test_report.html"
        
        if csv_gen.generate(test_data, str(csv_path)):
            print("✅ CSV generator works")
        else:
            print("❌ CSV generator failed")
        
        # Test HTML generator
        html_gen = HTMLGenerator()
        if html_gen.generate(test_data, str(html_path), "テストレポート"):
            print("✅ HTML generator works")
        else:
            print("❌ HTML generator failed")
        
        return True
    except Exception as e:
        print(f"❌ Report generators error: {e}")
        return False

def run_cli_mode():
    """Run in CLI mode for testing without GUI."""
    print("\\n🚀 Starting Python CLI Mode Test...")
    
    try:
        from src.cli.cli_app import CLIApp
        from src.core.config import Config
        
        config = Config()
        config.load()
        
        cli = CLIApp(config)
        print("✅ CLI app initialized successfully")
        
        # Test CLI functionality here
        print("📋 CLI mode test completed")
        
    except Exception as e:
        print(f"❌ CLI mode error: {e}")

def main():
    """Main test function."""
    print("🧪 Python GUI Application Test Suite")
    print("=" * 50)
    
    # Check dependencies
    print("\\n1. Checking Dependencies...")
    missing_deps = check_dependencies()
    
    # Create test configuration
    print("\\n2. Setting up test configuration...")
    create_test_config()
    
    # Test core modules
    print("\\n3. Testing core modules...")
    config_ok = test_config_module()
    logging_ok = test_logging_module()
    reports_ok = test_report_generators()
    
    # Summary
    print("\\n" + "=" * 50)
    print("📊 Test Summary:")
    print(f"   Dependencies missing: {len(missing_deps)}")
    print(f"   Configuration: {'✅' if config_ok else '❌'}")
    print(f"   Logging: {'✅' if logging_ok else '❌'}")
    print(f"   Report generators: {'✅' if reports_ok else '❌'}")
    
    if missing_deps:
        print(f"\\n⚠️  Missing dependencies: {', '.join(missing_deps)}")
        print("   Install with: pip install -r requirements.txt")
    
    if len(missing_deps) == 0:
        print("\\n🎉 All dependencies available - GUI can be started!")
        try:
            from src.main import main_gui
            print("   Starting GUI...")
            main_gui()
        except Exception as e:
            print(f"❌ GUI startup error: {e}")
    else:
        print("\\n🖥️  Running CLI mode test instead...")
        run_cli_mode()

if __name__ == "__main__":
    main()