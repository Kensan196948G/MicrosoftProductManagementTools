#!/usr/bin/env python3
"""
Test Runner for Microsoft 365 Management Tools
Advanced pytest execution with GUI testing support

Features:
- Automated test discovery and execution
- GUI testing with virtual display support
- Performance and coverage reporting
- Parallel execution support
- Custom test filtering and selection

Author: Frontend Developer (dev0)
Version: 3.1.0
Date: 2025-07-19
"""

import sys
import os
import argparse
import subprocess
from pathlib import Path
from typing import List, Optional
import time

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestRunner:
    """Advanced test runner for PyQt6 GUI tests"""
    
    def __init__(self):
        self.test_dir = Path(__file__).parent
        self.src_dir = self.test_dir.parent
        self.project_root = self.src_dir.parent
        
    def check_dependencies(self) -> bool:
        """Check if all testing dependencies are available"""
        required_packages = [
            'pytest',
            'pytest_qt', 
            'PyQt6',
            'psutil'
        ]
        
        missing_packages = []
        for package in required_packages:
            try:
                __import__(package)
            except ImportError:
                missing_packages.append(package)
        
        if missing_packages:
            print(f"❌ Missing required packages: {', '.join(missing_packages)}")
            print("Install with: pip install -r tests/requirements.txt")
            return False
        
        return True
    
    def setup_display(self) -> bool:
        """Setup virtual display for headless GUI testing"""
        if os.getenv('DISPLAY') or sys.platform == 'win32':
            return True  # Display available or Windows
        
        try:
            # Try to setup Xvfb for headless testing
            subprocess.run(['which', 'xvfb-run'], check=True, capture_output=True)
            print("📺 Virtual display (Xvfb) available for headless testing")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("⚠️  No display available and Xvfb not found")
            print("Install Xvfb: sudo apt-get install xvfb")
            return False
    
    def run_tests(self,
                  test_types: List[str] = None,
                  markers: List[str] = None,
                  coverage: bool = True,
                  parallel: bool = False,
                  verbose: bool = True,
                  headless: bool = False,
                  html_report: bool = True,
                  timeout: int = 300) -> int:
        """
        Run tests with specified options
        
        Args:
            test_types: Types of tests to run (unit, integration, gui, etc.)
            markers: pytest markers to filter tests
            coverage: Enable coverage reporting
            parallel: Enable parallel test execution
            verbose: Verbose output
            headless: Run in headless mode
            html_report: Generate HTML report
            timeout: Test timeout in seconds
            
        Returns:
            Exit code (0 for success)
        """
        
        if not self.check_dependencies():
            return 1
        
        # Build pytest command
        cmd = ['python', '-m', 'pytest']
        
        # Test discovery paths
        if test_types:
            for test_type in test_types:
                if test_type == 'gui':
                    cmd.extend([str(self.test_dir / 'gui')])
                elif test_type == 'integration':
                    cmd.extend([str(self.test_dir / 'integration')])
                elif test_type == 'unit':
                    cmd.extend([str(self.test_dir / 'unit')])
                else:
                    cmd.extend([str(self.test_dir)])
        else:
            cmd.append(str(self.test_dir))
        
        # Markers
        if markers:
            for marker in markers:
                cmd.extend(['-m', marker])
        
        # Coverage
        if coverage:
            cmd.extend([
                '--cov=src/gui',
                '--cov-report=html:htmlcov',
                '--cov-report=term-missing',
                '--cov-fail-under=70'
            ])
        
        # Parallel execution
        if parallel:
            try:
                import pytest_xdist
                cmd.extend(['-n', 'auto'])
            except ImportError:
                print("⚠️  pytest-xdist not available, running sequentially")
        
        # Verbosity
        if verbose:
            cmd.append('-v')
        else:
            cmd.append('-q')
        
        # HTML report
        if html_report:
            reports_dir = self.project_root / 'reports'
            reports_dir.mkdir(exist_ok=True)
            cmd.extend([
                '--html', str(reports_dir / 'pytest_report.html'),
                '--self-contained-html'
            ])
        
        # Timeout
        cmd.extend(['--timeout', str(timeout)])
        
        # Additional options
        cmd.extend([
            '--tb=short',
            '--durations=10',
            '--strict-markers'
        ])
        
        # Setup environment
        env = os.environ.copy()
        env['PYTHONPATH'] = str(self.src_dir)
        
        # Handle headless mode
        if headless and not self.setup_display():
            return 1
        
        if headless and sys.platform != 'win32':
            # Use xvfb-run for headless execution
            cmd = ['xvfb-run', '-a', '--server-args=-screen 0 1024x768x24'] + cmd
        
        print(f"🚀 Running tests with command: {' '.join(cmd)}")
        print(f"📁 Working directory: {os.getcwd()}")
        print(f"🐍 Python path: {env.get('PYTHONPATH')}")
        
        start_time = time.time()
        
        try:
            result = subprocess.run(cmd, env=env, cwd=self.project_root)
            duration = time.time() - start_time
            
            print(f"\n⏱️  Tests completed in {duration:.2f} seconds")
            
            if result.returncode == 0:
                print("✅ All tests passed!")
            else:
                print(f"❌ Tests failed with exit code {result.returncode}")
            
            return result.returncode
            
        except KeyboardInterrupt:
            print("\n⚠️  Tests interrupted by user")
            return 130
        except Exception as e:
            print(f"❌ Error running tests: {e}")
            return 1
    
    def run_specific_test(self, test_file: str, test_function: str = None) -> int:
        """Run a specific test file or function"""
        cmd = ['python', '-m', 'pytest', '-v']
        
        if test_function:
            cmd.append(f"{test_file}::{test_function}")
        else:
            cmd.append(test_file)
        
        env = os.environ.copy()
        env['PYTHONPATH'] = str(self.src_dir)
        
        return subprocess.run(cmd, env=env, cwd=self.project_root).returncode
    
    def generate_coverage_report(self) -> int:
        """Generate detailed coverage report"""
        if not self.check_dependencies():
            return 1
        
        cmd = [
            'python', '-m', 'pytest',
            '--cov=src/gui',
            '--cov-report=html:htmlcov',
            '--cov-report=term-missing',
            '--cov-report=xml:coverage.xml',
            '--cov-only',
            str(self.test_dir)
        ]
        
        env = os.environ.copy()
        env['PYTHONPATH'] = str(self.src_dir)
        
        result = subprocess.run(cmd, env=env, cwd=self.project_root)
        
        if result.returncode == 0:
            print("📊 Coverage report generated in htmlcov/index.html")
        
        return result.returncode
    
    def run_performance_tests(self) -> int:
        """Run performance and stress tests"""
        return self.run_tests(
            markers=['performance'],
            timeout=600,  # Longer timeout for performance tests
            parallel=False  # Run sequentially for consistent measurements
        )
    
    def run_smoke_tests(self) -> int:
        """Run smoke tests (quick verification)"""
        return self.run_tests(
            markers=['smoke', 'not slow'],
            coverage=False,
            verbose=False,
            timeout=60
        )


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Test runner for Microsoft 365 Management Tools GUI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --gui                    # Run GUI tests only
  %(prog)s --integration           # Run integration tests
  %(prog)s --performance           # Run performance tests
  %(prog)s --smoke                 # Run smoke tests (quick)
  %(prog)s --headless              # Run in headless mode
  %(prog)s --parallel              # Run tests in parallel
  %(prog)s --coverage-only         # Generate coverage report only
  %(prog)s gui/test_main_window.py # Run specific test file
        """
    )
    
    # Test type selection
    parser.add_argument('--gui', action='store_true',
                       help='Run GUI tests only')
    parser.add_argument('--integration', action='store_true',
                       help='Run integration tests only')
    parser.add_argument('--unit', action='store_true',
                       help='Run unit tests only')
    parser.add_argument('--performance', action='store_true',
                       help='Run performance tests only')
    parser.add_argument('--smoke', action='store_true',
                       help='Run smoke tests (quick verification)')
    
    # Execution options
    parser.add_argument('--parallel', action='store_true',
                       help='Enable parallel test execution')
    parser.add_argument('--headless', action='store_true',
                       help='Run in headless mode (requires Xvfb)')
    parser.add_argument('--no-coverage', action='store_true',
                       help='Disable coverage reporting')
    parser.add_argument('--no-html', action='store_true',
                       help='Disable HTML report generation')
    parser.add_argument('--quiet', action='store_true',
                       help='Quiet output (less verbose)')
    
    # Special modes
    parser.add_argument('--coverage-only', action='store_true',
                       help='Generate coverage report only')
    parser.add_argument('--timeout', type=int, default=300,
                       help='Test timeout in seconds (default: 300)')
    
    # Marker selection
    parser.add_argument('-m', '--markers', action='append',
                       help='pytest markers to filter tests')
    
    # Specific test selection
    parser.add_argument('tests', nargs='*',
                       help='Specific test files or functions to run')
    
    args = parser.parse_args()
    
    runner = TestRunner()
    
    # Handle special modes
    if args.coverage_only:
        return runner.generate_coverage_report()
    
    if args.smoke:
        return runner.run_smoke_tests()
    
    if args.performance:
        return runner.run_performance_tests()
    
    # Handle specific test files
    if args.tests:
        exit_code = 0
        for test in args.tests:
            if '::' in test:
                file_path, function = test.split('::', 1)
                result = runner.run_specific_test(file_path, function)
            else:
                result = runner.run_specific_test(test)
            
            if result != 0:
                exit_code = result
        
        return exit_code
    
    # Determine test types
    test_types = []
    if args.gui:
        test_types.append('gui')
    if args.integration:
        test_types.append('integration')
    if args.unit:
        test_types.append('unit')
    
    # Run tests
    return runner.run_tests(
        test_types=test_types or None,
        markers=args.markers,
        coverage=not args.no_coverage,
        parallel=args.parallel,
        verbose=not args.quiet,
        headless=args.headless,
        html_report=not args.no_html,
        timeout=args.timeout
    )


if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)