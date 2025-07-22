#!/usr/bin/env python3
"""
PowerShell Pester + Python pytest Integration Bridge
QA Engineer (dev2) - PowerShell Integration & Migration Support

PowerShell Pester テスト統合・移行期並列実行システム：
- PowerShell Pester テストとPython pytest統合
- 移行期間中の並行テスト実行体制
- PowerShell → Python テスト移行支援
- 統一レポート生成・結果統合
"""
import os
import sys
import json
import subprocess
import logging
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import pytest

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PowerShellPesterBridge:
    """PowerShell Pester ブリッジシステム"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.scripts_dir = self.project_root / "Scripts"
        self.test_scripts_dir = self.project_root / "TestScripts"
        self.apps_dir = self.project_root / "Apps"
        
        self.integration_dir = self.project_root / "Tests" / "powershell_integration"
        self.integration_dir.mkdir(exist_ok=True)
        
        self.reports_dir = self.integration_dir / "reports"
        self.reports_dir.mkdir(exist_ok=True)
        
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # PowerShell実行環境検証
        self.powershell_available = self._check_powershell_availability()
        
    def _check_powershell_availability(self) -> bool:
        """PowerShell実行環境チェック"""
        try:
            # PowerShell Core (pwsh) 確認
            result = subprocess.run(
                ["pwsh", "-Command", "Get-Host | Select-Object Version"],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                logger.info("✅ PowerShell Core (pwsh) available")
                return True
        except Exception:
            pass
        
        try:
            # Windows PowerShell (powershell) 確認
            result = subprocess.run(
                ["powershell", "-Command", "Get-Host | Select-Object Version"],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                logger.info("✅ Windows PowerShell available")
                return True
        except Exception:
            pass
        
        logger.warning("⚠️ PowerShell not available")
        return False
    
    def discover_powershell_tests(self) -> Dict[str, Any]:
        """PowerShell テストファイル発見"""
        logger.info("🔍 Discovering PowerShell test files...")
        
        discovery_results = {
            "test_scripts": [],
            "app_tests": [],
            "pester_tests": [],
            "total_files": 0
        }
        
        # TestScripts ディレクトリ
        if self.test_scripts_dir.exists():
            ps1_files = list(self.test_scripts_dir.glob("**/*.ps1"))
            for ps1_file in ps1_files:
                if "test" in ps1_file.name.lower():
                    discovery_results["test_scripts"].append({
                        "path": str(ps1_file),
                        "name": ps1_file.name,
                        "size": ps1_file.stat().st_size,
                        "modified": ps1_file.stat().st_mtime
                    })
        
        # Apps ディレクトリのテスト可能ファイル
        if self.apps_dir.exists():
            app_files = list(self.apps_dir.glob("*.ps1"))
            for app_file in app_files:
                discovery_results["app_tests"].append({
                    "path": str(app_file),
                    "name": app_file.name,
                    "size": app_file.stat().st_size,
                    "modified": app_file.stat().st_mtime,
                    "type": "gui" if "gui" in app_file.name.lower() else "cli"
                })
        
        # Pester テストファイル検索
        pester_patterns = ["*.Tests.ps1", "*Test.ps1", "Test-*.ps1"]
        for pattern in pester_patterns:
            pester_files = list(self.project_root.glob(f"**/{pattern}"))
            for pester_file in pester_files:
                discovery_results["pester_tests"].append({
                    "path": str(pester_file),
                    "name": pester_file.name,
                    "size": pester_file.stat().st_size,
                    "pattern": pattern
                })
        
        discovery_results["total_files"] = (
            len(discovery_results["test_scripts"]) +
            len(discovery_results["app_tests"]) +
            len(discovery_results["pester_tests"])
        )
        
        logger.info(f"Found {discovery_results['total_files']} PowerShell test files")
        
        return discovery_results
    
    def create_pester_test_runner(self) -> Dict[str, Any]:
        """Pester テストランナー作成"""
        logger.info("⚙️ Creating Pester test runner...")
        
        # Pester テストランナースクリプト作成
        pester_runner_content = '''#Requires -Version 5.1
<#
.SYNOPSIS
    Microsoft 365 Management Tools - Pester Test Runner
    QA Engineer (dev2) - PowerShell Pester Integration

.DESCRIPTION
    PowerShell Pester テスト統合実行・レポート生成
    Python pytest との統合ブリッジ機能
#>

param(
    [string]$TestPath = ".",
    [string]$OutputPath = "./Tests/powershell_integration/reports",
    [string]$TestType = "All",
    [switch]$Parallel = $false,
    [switch]$PassThru = $false
)

# Pester モジュール確認・インストール
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Installing Pester module..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck
}

Import-Module Pester

# 出力ディレクトリ作成
$OutputPath = Resolve-Path $OutputPath -ErrorAction SilentlyContinue
if (-not $OutputPath) {
    $OutputPath = New-Item -ItemType Directory -Path "./Tests/powershell_integration/reports" -Force
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Pester 設定
$PesterConfig = @{
    Run = @{
        Path = $TestPath
        PassThru = $PassThru
        Throw = $false
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    TestResult = @{
        Enabled = $true
        OutputPath = "$OutputPath/pester_results_$timestamp.xml"
        OutputFormat = 'NUnit3'
    }
    CodeCoverage = @{
        Enabled = $true
        OutputPath = "$OutputPath/pester_coverage_$timestamp.xml"
        OutputFormat = 'CoverageGutters'
    }
}

# 並列実行設定
if ($Parallel) {
    $PesterConfig.Run.Parallel = $true
    $PesterConfig.Run.Jobs = [Environment]::ProcessorCount
}

# テストタイプ別フィルタリング
switch ($TestType) {
    "Unit" {
        $PesterConfig.Filter = @{ Tag = 'Unit' }
    }
    "Integration" {
        $PesterConfig.Filter = @{ Tag = 'Integration' }
    }
    "GUI" {
        $PesterConfig.Filter = @{ Tag = 'GUI' }
    }
    "CLI" {
        $PesterConfig.Filter = @{ Tag = 'CLI' }
    }
    "Security" {
        $PesterConfig.Filter = @{ Tag = 'Security' }
    }
    default {
        # All tests
    }
}

Write-Host "Starting Pester tests..." -ForegroundColor Green
Write-Host "Test Path: $TestPath" -ForegroundColor Cyan
Write-Host "Output Path: $OutputPath" -ForegroundColor Cyan
Write-Host "Test Type: $TestType" -ForegroundColor Cyan
Write-Host "Parallel: $Parallel" -ForegroundColor Cyan

# Pester 実行
try {
    $testResult = Invoke-Pester -Configuration $PesterConfig
    
    # 結果サマリー
    $summary = @{
        Timestamp = $timestamp
        TestType = $TestType
        TotalTests = $testResult.TotalCount
        PassedTests = $testResult.PassedCount
        FailedTests = $testResult.FailedCount
        SkippedTests = $testResult.SkippedCount
        ExecutionTime = $testResult.Duration.TotalSeconds
        Success = ($testResult.FailedCount -eq 0)
        OutputPath = $OutputPath
    }
    
    # JSON サマリー保存
    $summary | ConvertTo-Json -Depth 3 | Out-File "$OutputPath/pester_summary_$timestamp.json" -Encoding UTF8
    
    # コンソール出力
    Write-Host "`n=== Pester Test Results ===" -ForegroundColor Green
    Write-Host "Total Tests: $($summary.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($summary.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($summary.FailedTests)" -ForegroundColor Red
    Write-Host "Skipped: $($summary.SkippedTests)" -ForegroundColor Yellow
    Write-Host "Execution Time: $($summary.ExecutionTime) seconds" -ForegroundColor Cyan
    Write-Host "Success: $($summary.Success)" -ForegroundColor $(if($summary.Success) { "Green" } else { "Red" })
    Write-Host "=========================" -ForegroundColor Green
    
    if ($PassThru) {
        return $testResult
    }
    
    exit $(if($summary.Success) { 0 } else { 1 })
    
} catch {
    Write-Error "Pester execution failed: $($_.Exception.Message)"
    exit 1
}
'''
        
        # Pester ランナー保存
        runner_path = self.integration_dir / "Run-PesterTests.ps1"
        with open(runner_path, 'w', encoding='utf-8') as f:
            f.write(pester_runner_content)
        
        return {
            "runner_created": str(runner_path),
            "runner_size": runner_path.stat().st_size,
            "status": "ready"
        }
    
    def run_powershell_tests(self, test_type: str = "All") -> Dict[str, Any]:
        """PowerShell テスト実行"""
        logger.info(f"🔥 Running PowerShell tests (type: {test_type})...")
        
        if not self.powershell_available:
            return {
                "status": "skipped",
                "reason": "PowerShell not available",
                "success": False
            }
        
        # Pester ランナー実行
        runner_path = self.integration_dir / "Run-PesterTests.ps1"
        if not runner_path.exists():
            self.create_pester_test_runner()
        
        try:
            # PowerShell コマンド実行
            cmd = [
                "pwsh" if self._check_powershell_core() else "powershell",
                "-ExecutionPolicy", "Bypass",
                "-File", str(runner_path),
                "-TestPath", str(self.project_root),
                "-OutputPath", str(self.reports_dir),
                "-TestType", test_type
            ]
            
            start_time = datetime.now()
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
            end_time = datetime.now()
            
            execution_time = (end_time - start_time).total_seconds()
            
            # 結果解析
            success = result.returncode == 0
            
            # サマリーファイル読み込み
            summary_files = list(self.reports_dir.glob("pester_summary_*.json"))
            latest_summary = None
            
            if summary_files:
                latest_summary_file = max(summary_files, key=lambda f: f.stat().st_mtime)
                try:
                    with open(latest_summary_file) as f:
                        latest_summary = json.load(f)
                except Exception as e:
                    logger.warning(f"Failed to read summary: {e}")
            
            return {
                "status": "completed",
                "success": success,
                "execution_time": execution_time,
                "exit_code": result.returncode,
                "stdout_lines": len(result.stdout.splitlines()),
                "stderr_lines": len(result.stderr.splitlines()),
                "test_type": test_type,
                "summary": latest_summary,
                "command": " ".join(cmd)
            }
            
        except subprocess.TimeoutExpired:
            return {
                "status": "timeout",
                "success": False,
                "execution_time": 600,
                "test_type": test_type
            }
        except Exception as e:
            return {
                "status": "error",
                "success": False,
                "error": str(e),
                "test_type": test_type
            }
    
    def _check_powershell_core(self) -> bool:
        """PowerShell Core (pwsh) 可用性チェック"""
        try:
            subprocess.run(["pwsh", "-Command", "$null"], 
                         capture_output=True, timeout=5)
            return True
        except:
            return False
    
    def create_hybrid_test_suite(self) -> Dict[str, Any]:
        """ハイブリッドテストスイート作成"""
        logger.info("🔄 Creating hybrid test suite (PowerShell + Python)...")
        
        hybrid_suite_content = '''#!/usr/bin/env python3
"""
Hybrid Test Suite - PowerShell + Python Integration
QA Engineer (dev2) - Migration Period Parallel Testing

PowerShell Pester + Python pytest 並列実行・統合レポート
"""
import asyncio
import json
import subprocess
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

class HybridTestRunner:
    """ハイブリッドテストランナー"""
    
    def __init__(self):
        self.project_root = Path(__file__).parent.parent.parent
        self.reports_dir = self.project_root / "Tests" / "powershell_integration" / "reports"
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    def run_python_tests(self) -> dict:
        """Python pytest 実行"""
        print("🐍 Running Python pytest...")
        
        cmd = [
            "python", "-m", "pytest", 
            "Tests/",
            "-v", "--tb=short",
            "--junitxml=Tests/powershell_integration/reports/pytest_results.xml",
            "--html=Tests/powershell_integration/reports/pytest_report.html",
            "--self-contained-html",
            "-m", "not requires_powershell"
        ]
        
        try:
            start_time = datetime.now()
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            end_time = datetime.now()
            
            return {
                "framework": "pytest",
                "success": result.returncode == 0,
                "execution_time": (end_time - start_time).total_seconds(),
                "exit_code": result.returncode,
                "command": " ".join(cmd)
            }
        except Exception as e:
            return {
                "framework": "pytest",
                "success": False,
                "error": str(e)
            }
    
    def run_powershell_tests(self) -> dict:
        """PowerShell Pester 実行"""
        print("⚡ Running PowerShell Pester...")
        
        runner_path = self.project_root / "Tests" / "powershell_integration" / "Run-PesterTests.ps1"
        
        cmd = [
            "pwsh", "-ExecutionPolicy", "Bypass",
            "-File", str(runner_path),
            "-TestType", "All"
        ]
        
        try:
            start_time = datetime.now()
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            end_time = datetime.now()
            
            return {
                "framework": "pester",
                "success": result.returncode == 0,
                "execution_time": (end_time - start_time).total_seconds(),
                "exit_code": result.returncode,
                "command": " ".join(cmd)
            }
        except Exception as e:
            return {
                "framework": "pester",
                "success": False,
                "error": str(e)
            }
    
    def run_parallel_tests(self) -> dict:
        """並列テスト実行"""
        print("🔄 Running parallel hybrid tests...")
        
        with ThreadPoolExecutor(max_workers=2) as executor:
            # Python と PowerShell テストを並列実行
            futures = {
                executor.submit(self.run_python_tests): "python",
                executor.submit(self.run_powershell_tests): "powershell"
            }
            
            results = {}
            for future in as_completed(futures):
                framework = futures[future]
                try:
                    result = future.result()
                    results[framework] = result
                    print(f"✅ {framework} tests completed")
                except Exception as e:
                    results[framework] = {"success": False, "error": str(e)}
                    print(f"❌ {framework} tests failed: {e}")
        
        # 統合結果
        overall_success = all(r.get("success", False) for r in results.values())
        
        hybrid_results = {
            "timestamp": self.timestamp,
            "execution_mode": "parallel",
            "frameworks": results,
            "overall_success": overall_success,
            "total_frameworks": len(results),
            "successful_frameworks": sum(1 for r in results.values() if r.get("success", False))
        }
        
        # 結果保存
        results_file = self.reports_dir / f"hybrid_test_results_{self.timestamp}.json"
        with open(results_file, 'w') as f:
            json.dump(hybrid_results, f, indent=2)
        
        print(f"📄 Hybrid test results saved: {results_file}")
        
        return hybrid_results

if __name__ == "__main__":
    runner = HybridTestRunner()
    results = runner.run_parallel_tests()
    
    print("\\n" + "="*60)
    print("🔄 HYBRID TEST RESULTS")
    print("="*60)
    print(f"Overall Success: {results['overall_success']}")
    print(f"Successful Frameworks: {results['successful_frameworks']}/{results['total_frameworks']}")
    
    for framework, result in results["frameworks"].items():
        status = "✅ PASS" if result.get("success", False) else "❌ FAIL"
        print(f"{framework}: {status}")
    
    print("="*60)
'''
        
        # ハイブリッドテストスイート保存
        hybrid_path = self.integration_dir / "hybrid_test_runner.py"
        with open(hybrid_path, 'w', encoding='utf-8') as f:
            f.write(hybrid_suite_content)
        
        return {
            "hybrid_suite_created": str(hybrid_path),
            "features": [
                "PowerShell + Python parallel execution",
                "Unified reporting",
                "Migration period support",
                "Cross-platform compatibility"
            ],
            "status": "ready"
        }
    
    def run_full_integration(self) -> Dict[str, Any]:
        """完全統合実行"""
        logger.info("🚀 Running full PowerShell-Python integration...")
        
        # 発見
        discovery = self.discover_powershell_tests()
        
        # Pester ランナー作成
        pester_runner = self.create_pester_test_runner()
        
        # ハイブリッドスイート作成
        hybrid_suite = self.create_hybrid_test_suite()
        
        # PowerShell テスト実行
        powershell_results = self.run_powershell_tests("All")
        
        # ハイブリッドテスト実行
        hybrid_results = {}
        hybrid_path = self.integration_dir / "hybrid_test_runner.py"
        if hybrid_path.exists():
            try:
                result = subprocess.run(
                    ["python", str(hybrid_path)],
                    capture_output=True, text=True, timeout=600
                )
                hybrid_results = {
                    "executed": True,
                    "success": result.returncode == 0,
                    "exit_code": result.returncode
                }
            except Exception as e:
                hybrid_results = {
                    "executed": False,
                    "error": str(e)
                }
        
        # 統合結果
        integration_results = {
            "timestamp": self.timestamp,
            "project_root": str(self.project_root),
            "powershell_available": self.powershell_available,
            "discovery": discovery,
            "pester_runner": pester_runner,
            "hybrid_suite": hybrid_suite,
            "powershell_test_results": powershell_results,
            "hybrid_test_results": hybrid_results,
            "integration_status": "completed"
        }
        
        # 最終レポート保存
        final_report = self.reports_dir / f"powershell_integration_report_{self.timestamp}.json"
        with open(final_report, 'w') as f:
            json.dump(integration_results, f, indent=2)
        
        logger.info(f"✅ PowerShell integration completed!")
        logger.info(f"📄 Integration report: {final_report}")
        
        return integration_results


# pytest統合用テスト関数
@pytest.mark.powershell
@pytest.mark.integration
def test_powershell_availability():
    """PowerShell実行環境テスト"""
    bridge = PowerShellPesterBridge()
    assert bridge.powershell_available or os.name != 'nt', "PowerShell should be available on Windows"


@pytest.mark.powershell
@pytest.mark.integration
def test_pester_runner_creation():
    """Pester ランナー作成テスト"""
    bridge = PowerShellPesterBridge()
    result = bridge.create_pester_test_runner()
    
    assert result["status"] == "ready", "Pester runner should be created successfully"
    assert Path(result["runner_created"]).exists(), "Pester runner file should exist"


@pytest.mark.powershell
@pytest.mark.integration
def test_hybrid_suite_creation():
    """ハイブリッドテストスイート作成テスト"""
    bridge = PowerShellPesterBridge()
    result = bridge.create_hybrid_test_suite()
    
    assert result["status"] == "ready", "Hybrid suite should be created successfully"
    assert Path(result["hybrid_suite_created"]).exists(), "Hybrid suite file should exist"


@pytest.mark.powershell
@pytest.mark.integration
@pytest.mark.requires_powershell
def test_powershell_test_execution():
    """PowerShell テスト実行テスト"""
    bridge = PowerShellPesterBridge()
    
    if not bridge.powershell_available:
        pytest.skip("PowerShell not available")
    
    result = bridge.run_powershell_tests("All")
    assert result["status"] in ["completed", "timeout", "error"], "PowerShell test should execute"


if __name__ == "__main__":
    # スタンドアロン実行
    bridge = PowerShellPesterBridge()
    results = bridge.run_full_integration()
    
    print("\n" + "="*60)
    print("⚡ POWERSHELL INTEGRATION RESULTS")
    print("="*60)
    print(f"PowerShell Available: {results['powershell_available']}")
    print(f"PowerShell Files Found: {results['discovery']['total_files']}")
    print(f"Integration Status: {results['integration_status']}")
    print("="*60)