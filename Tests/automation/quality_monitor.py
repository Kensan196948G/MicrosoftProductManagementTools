"""
品質メトリクス自動監視システム

Python移行プロジェクト用の品質メトリクス自動収集・監視システム
4時間ごとの自動品質チェック、エスカレーション機能付き
"""

import subprocess
import json
import yaml
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List
import os
import sys

class QualityMetricsMonitor:
    """品質メトリクス自動監視システム"""
    
    def __init__(self, project_root: str = None):
        """
        初期化
        
        Args:
            project_root: プロジェクトルートパス
        """
        self.project_root = Path(project_root) if project_root else Path(__file__).parent.parent.parent
        self.metrics_path = self.project_root / "reports" / "progress" / "quality"
        self.metrics_path.mkdir(parents=True, exist_ok=True)
        
        # エスカレーション基準ファイルの読み込み
        self.escalation_rules = self._load_escalation_rules()
        
        # ログファイルの設定
        self.log_file = self.project_root / "logs" / "quality_monitor.log"
        self.log_file.parent.mkdir(exist_ok=True)
    
    def _load_escalation_rules(self) -> Dict[str, Any]:
        """エスカレーション基準の読み込み"""
        rules_file = self.project_root / "Config" / "escalation_rules.yml"
        
        if not rules_file.exists():
            # デフォルトエスカレーション基準
            return {
                "escalation_criteria": {
                    "immediate": {
                        "test_coverage_below": 85,
                        "build_failures_consecutive": 3,
                        "repair_loops_exceed": 7,
                        "api_response_time_over": 3.0
                    },
                    "warning": {
                        "test_coverage_below": 88,
                        "repair_loops_exceed": 5,
                        "progress_completion_below": 80
                    }
                }
            }
        
        try:
            with open(rules_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except Exception as e:
            self._log_error(f"エスカレーション基準読み込み失敗: {e}")
            return {}
    
    def run_automated_checks(self) -> Dict[str, Any]:
        """4時間ごとの自動品質チェック"""
        self._log_info("自動品質チェック開始")
        
        metrics = {
            "timestamp": datetime.now().isoformat(),
            "developer": "tester",
            "project_root": str(self.project_root),
            "quality_metrics": {
                "test_results": self.run_all_test_suites(),
                "coverage_report": self.generate_coverage_report(),
                "regression_status": self.check_regression_tests(),
                "compatibility_matrix": self.test_compatibility(),
                "code_quality": self.analyze_code_quality()
            }
        }
        
        # メトリクスの保存
        self._save_metrics(metrics)
        
        # エスカレーション判定
        self.check_escalation_criteria(metrics)
        
        self._log_info("自動品質チェック完了")
        return metrics
    
    def run_all_test_suites(self) -> Dict[str, Any]:
        """全テストスイート実行"""
        self._log_info("テストスイート実行開始")
        
        test_results = {}
        
        # Python単体テスト
        test_results["unit_tests"] = self._run_python_unit_tests()
        
        # 統合テスト
        test_results["integration_tests"] = self._run_integration_tests()
        
        # API テスト
        test_results["api_tests"] = self._run_api_tests()
        
        # GUI テスト
        test_results["gui_tests"] = self._run_gui_tests()
        
        # PowerShell互換性テスト
        test_results["compatibility"] = self._run_powershell_compatibility_tests()
        
        # 全体サマリー
        test_results["summary"] = self._calculate_test_summary(test_results)
        
        return test_results
    
    def _run_python_unit_tests(self) -> Dict[str, Any]:
        """Python単体テスト実行"""
        try:
            result = subprocess.run(
                [sys.executable, "-m", "pytest", "tests/unit/", "-v", "--tb=short", "--json-report", "--json-report-file=reports/progress/unit_test_results.json"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            return {
                "passed": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {"passed": False, "error": "テストタイムアウト", "returncode": -1}
        except Exception as e:
            return {"passed": False, "error": str(e), "returncode": -1}
    
    def _run_integration_tests(self) -> Dict[str, Any]:
        """統合テスト実行"""
        try:
            result = subprocess.run(
                [sys.executable, "-m", "pytest", "tests/integration/", "-v", "--tb=short"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=600
            )
            
            return {
                "passed": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
        except Exception as e:
            return {"passed": False, "error": str(e), "returncode": -1}
    
    def _run_api_tests(self) -> Dict[str, Any]:
        """API テスト実行"""
        try:
            result = subprocess.run(
                [sys.executable, "-m", "pytest", "tests/api/", "-v", "--tb=short"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            return {
                "passed": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
        except Exception as e:
            return {"passed": False, "error": str(e), "returncode": -1}
    
    def _run_gui_tests(self) -> Dict[str, Any]:
        """GUI テスト実行"""
        try:
            result = subprocess.run(
                [sys.executable, "-m", "pytest", "tests/unit/test_gui_components.py", "-v", "--tb=short"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            return {
                "passed": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
        except Exception as e:
            return {"passed": False, "error": str(e), "returncode": -1}
    
    def _run_powershell_compatibility_tests(self) -> Dict[str, Any]:
        """PowerShell互換性テスト実行"""
        try:
            # PowerShell互換性テスト
            result = subprocess.run(
                [sys.executable, "-m", "pytest", "tests/compatibility/", "-v", "--tb=short"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=600
            )
            
            return {
                "passed": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
        except Exception as e:
            return {"passed": False, "error": str(e), "returncode": -1}
    
    def _calculate_test_summary(self, test_results: Dict[str, Any]) -> Dict[str, Any]:
        """テスト結果サマリー計算"""
        total_suites = len([k for k in test_results.keys() if k != "summary"])
        passed_suites = len([k for k, v in test_results.items() if k != "summary" and v.get("passed", False)])
        
        return {
            "total_suites": total_suites,
            "passed_suites": passed_suites,
            "success_rate": (passed_suites / total_suites * 100) if total_suites > 0 else 0
        }
    
    def generate_coverage_report(self) -> Dict[str, Any]:
        """カバレッジレポート生成"""
        try:
            # pytestカバレッジ実行
            result = subprocess.run(
                [sys.executable, "-m", "pytest", "--cov=src", "--cov-report=json", "--cov-report=term"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=600
            )
            
            # JSONカバレッジレポートの読み込み
            coverage_file = self.project_root / "coverage.json"
            if coverage_file.exists():
                with open(coverage_file, 'r') as f:
                    coverage_data = json.load(f)
                    
                total_coverage = coverage_data.get("totals", {}).get("percent_covered", 0)
                
                return {
                    "total": total_coverage,
                    "detailed": coverage_data,
                    "status": "success"
                }
            else:
                return {
                    "total": 0,
                    "error": "カバレッジファイルが見つかりません",
                    "status": "failed"
                }
                
        except Exception as e:
            return {
                "total": 0,
                "error": str(e),
                "status": "failed"
            }
    
    def check_regression_tests(self) -> Dict[str, Any]:
        """レグレッションテストチェック"""
        try:
            # レグレッションテストディレクトリの確認
            regression_dir = self.project_root / "tests" / "regression"
            
            if not regression_dir.exists():
                return {
                    "status": "not_configured",
                    "message": "レグレッションテストディレクトリが存在しません"
                }
            
            # レグレッションテスト実行
            result = subprocess.run(
                [sys.executable, "-m", "pytest", str(regression_dir), "-v"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            return {
                "status": "completed" if result.returncode == 0 else "failed",
                "passed": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e)
            }
    
    def test_compatibility(self) -> Dict[str, Any]:
        """互換性テストマトリクス"""
        compatibility_results = {}
        
        # PowerShell バージョン互換性
        compatibility_results["powershell_versions"] = self._test_powershell_versions()
        
        # Python バージョン互換性
        compatibility_results["python_versions"] = self._test_python_versions()
        
        # プラットフォーム互換性
        compatibility_results["platforms"] = self._test_platform_compatibility()
        
        return compatibility_results
    
    def _test_powershell_versions(self) -> Dict[str, Any]:
        """PowerShell バージョン互換性テスト"""
        try:
            # PowerShell 5.1 テスト
            ps51_result = subprocess.run(
                ["powershell", "-Command", "Get-Host | Select-Object Version"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            # PowerShell 7.x テスト
            ps7_result = subprocess.run(
                ["pwsh", "-Command", "Get-Host | Select-Object Version"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            return {
                "powershell_5_1": ps51_result.returncode == 0,
                "powershell_7_x": ps7_result.returncode == 0,
                "overall_status": "compatible" if ps51_result.returncode == 0 and ps7_result.returncode == 0 else "issues"
            }
        except Exception as e:
            return {"error": str(e), "overall_status": "error"}
    
    def _test_python_versions(self) -> Dict[str, Any]:
        """Python バージョン互換性テスト"""
        try:
            python_version = sys.version_info
            
            # Python 3.9+ チェック
            min_version_ok = python_version >= (3, 9)
            
            # Python 3.11 推奨チェック
            recommended_version = python_version >= (3, 11)
            
            return {
                "current_version": f"{python_version.major}.{python_version.minor}.{python_version.micro}",
                "min_version_ok": min_version_ok,
                "recommended_version": recommended_version,
                "overall_status": "compatible" if min_version_ok else "incompatible"
            }
        except Exception as e:
            return {"error": str(e), "overall_status": "error"}
    
    def _test_platform_compatibility(self) -> Dict[str, Any]:
        """プラットフォーム互換性テスト"""
        import platform
        
        try:
            return {
                "platform": platform.system(),
                "architecture": platform.machine(),
                "python_implementation": platform.python_implementation(),
                "overall_status": "compatible"
            }
        except Exception as e:
            return {"error": str(e), "overall_status": "error"}
    
    def analyze_code_quality(self) -> Dict[str, Any]:
        """コード品質分析"""
        quality_metrics = {}
        
        # flake8 による静的解析
        quality_metrics["flake8"] = self._run_flake8_analysis()
        
        # pylint による詳細解析
        quality_metrics["pylint"] = self._run_pylint_analysis()
        
        # 複雑度分析
        quality_metrics["complexity"] = self._analyze_complexity()
        
        return quality_metrics
    
    def _run_flake8_analysis(self) -> Dict[str, Any]:
        """flake8 静的解析"""
        try:
            result = subprocess.run(
                ["flake8", "src/", "--statistics", "--count"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=120
            )
            
            return {
                "passed": result.returncode == 0,
                "issues_count": result.stdout.count('\n') if result.stdout else 0,
                "output": result.stdout
            }
        except Exception as e:
            return {"error": str(e), "passed": False}
    
    def _run_pylint_analysis(self) -> Dict[str, Any]:
        """pylint 詳細解析"""
        try:
            result = subprocess.run(
                ["pylint", "src/", "--output-format=json"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            return {
                "passed": result.returncode == 0,
                "output": result.stdout
            }
        except Exception as e:
            return {"error": str(e), "passed": False}
    
    def _analyze_complexity(self) -> Dict[str, Any]:
        """複雑度分析"""
        try:
            # radon による複雑度分析
            result = subprocess.run(
                ["radon", "cc", "src/", "-j"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode == 0:
                try:
                    complexity_data = json.loads(result.stdout)
                    return {
                        "status": "success",
                        "data": complexity_data
                    }
                except json.JSONDecodeError:
                    return {"status": "parse_error", "raw_output": result.stdout}
            else:
                return {"status": "failed", "stderr": result.stderr}
                
        except Exception as e:
            return {"error": str(e), "status": "error"}
    
    def check_escalation_criteria(self, metrics: Dict[str, Any]) -> None:
        """エスカレーション基準チェック"""
        try:
            criteria = self.escalation_rules.get("escalation_criteria", {})
            quality_metrics = metrics.get("quality_metrics", {})
            
            # カバレッジチェック
            coverage_report = quality_metrics.get("coverage_report", {})
            coverage = coverage_report.get("total", 0)
            
            # 即時エスカレーション基準
            immediate_criteria = criteria.get("immediate", {})
            if coverage < immediate_criteria.get("test_coverage_below", 85):
                self.escalate_to_architect(
                    f"CRITICAL: テストカバレッジが{coverage}%で基準値{immediate_criteria.get('test_coverage_below', 85)}%を下回っています",
                    metrics
                )
            
            # 警告エスカレーション基準
            warning_criteria = criteria.get("warning", {})
            if coverage < warning_criteria.get("test_coverage_below", 88):
                self.escalate_to_architect(
                    f"WARNING: テストカバレッジが{coverage}%で警告基準{warning_criteria.get('test_coverage_below', 88)}%を下回っています",
                    metrics
                )
            
            # テスト失敗連続チェック
            test_results = quality_metrics.get("test_results", {})
            test_summary = test_results.get("summary", {})
            
            if test_summary.get("success_rate", 100) < 50:
                self.escalate_to_architect(
                    f"CRITICAL: テスト成功率が{test_summary.get('success_rate', 0)}%で異常に低下しています",
                    metrics
                )
            
        except Exception as e:
            self._log_error(f"エスカレーション基準チェックエラー: {e}")
    
    def escalate_to_architect(self, message: str, metrics: Dict[str, Any]) -> None:
        """アーキテクトへのエスカレーション"""
        try:
            escalation_report = {
                "timestamp": datetime.now().isoformat(),
                "escalation_type": "quality_alert",
                "message": message,
                "metrics": metrics,
                "reporter": "tester"
            }
            
            # エスカレーションレポートの保存
            escalation_file = self.metrics_path / f"escalation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(escalation_file, 'w', encoding='utf-8') as f:
                json.dump(escalation_report, f, indent=2, ensure_ascii=False)
            
            # tmux_shared_context.mdへの追記
            self._update_shared_context(message)
            
            self._log_error(f"エスカレーション実行: {message}")
            
        except Exception as e:
            self._log_error(f"エスカレーション実行エラー: {e}")
    
    def _update_shared_context(self, alert_message: str) -> None:
        """共有コンテキストファイルの更新"""
        try:
            shared_context_file = self.project_root / "tmux_shared_context.md"
            
            alert_entry = f"\n### 🚨 エスカレーションアラート ({datetime.now().strftime('%a %b %d %H:%M:%S %Z %Y')})\n- {alert_message}\n"
            
            with open(shared_context_file, 'a', encoding='utf-8') as f:
                f.write(alert_entry)
                
        except Exception as e:
            self._log_error(f"共有コンテキスト更新エラー: {e}")
    
    def _save_metrics(self, metrics: Dict[str, Any]) -> None:
        """メトリクスの保存"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            metrics_file = self.metrics_path / f"quality_metrics_{timestamp}.json"
            
            with open(metrics_file, 'w', encoding='utf-8') as f:
                json.dump(metrics, f, indent=2, ensure_ascii=False)
                
            # 最新メトリクスファイルも更新
            latest_file = self.metrics_path / "latest_quality_metrics.json"
            with open(latest_file, 'w', encoding='utf-8') as f:
                json.dump(metrics, f, indent=2, ensure_ascii=False)
                
        except Exception as e:
            self._log_error(f"メトリクス保存エラー: {e}")
    
    def _log_info(self, message: str) -> None:
        """情報ログ"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] INFO: {message}\n"
        
        try:
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(log_entry)
        except Exception:
            pass  # ログ書き込みエラーは無視
        
        print(log_entry.strip())
    
    def _log_error(self, message: str) -> None:
        """エラーログ"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] ERROR: {message}\n"
        
        try:
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(log_entry)
        except Exception:
            pass  # ログ書き込みエラーは無視
        
        print(log_entry.strip())


def main():
    """メイン実行関数"""
    try:
        # 品質メトリクスモニター初期化
        monitor = QualityMetricsMonitor()
        
        # 自動品質チェック実行
        metrics = monitor.run_automated_checks()
        
        # 結果の表示
        print(f"品質チェック完了: {metrics['timestamp']}")
        print(f"テストカバレッジ: {metrics['quality_metrics']['coverage_report'].get('total', 0)}%")
        print(f"テスト成功率: {metrics['quality_metrics']['test_results']['summary'].get('success_rate', 0)}%")
        
        return 0
        
    except Exception as e:
        print(f"品質チェック実行エラー: {e}")
        return 1


if __name__ == "__main__":
    exit(main())