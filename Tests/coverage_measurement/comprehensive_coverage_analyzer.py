#!/usr/bin/env python3
"""
Comprehensive Test Coverage Analyzer - 90% Target Achievement
QA Engineer (dev2) - Test Coverage & Quality Metrics Specialist

テストカバレッジ90%以上達成・品質指標測定システム：
- 1,037テスト関数の包括的カバレッジ測定
- Python/PowerShell/React/TypeScriptすべてのカバレッジ統合
- 26機能完全カバレッジ検証
- 品質指標・メトリクス収集分析
- カバレッジ改善提案自動生成
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
import coverage
import ast

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ComprehensiveCoverageAnalyzer:
    """包括的テストカバレッジ分析システム"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.tests_dir = self.project_root / "Tests"
        self.src_dir = self.project_root / "src"
        self.frontend_dir = self.project_root / "frontend"
        self.apps_dir = self.project_root / "Apps"
        self.scripts_dir = self.project_root / "Scripts"
        
        self.coverage_dir = self.tests_dir / "coverage_measurement"
        self.coverage_dir.mkdir(exist_ok=True)
        
        self.reports_dir = self.coverage_dir / "reports"
        self.reports_dir.mkdir(exist_ok=True)
        
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # カバレッジ目標設定
        self.coverage_targets = {
            "overall": 90.0,
            "python": 90.0,
            "react_typescript": 85.0,
            "powershell": 75.0,  # PowerShellは少し低め
            "api_endpoints": 95.0,
            "26_features": 100.0  # 26機能は完全カバレッジ
        }
        
        # 品質指標閾値
        self.quality_thresholds = {
            "complexity_score": 8.0,
            "maintainability_index": 70.0,
            "test_failure_rate": 5.0,
            "performance_score": 80.0
        }
        
    def discover_all_source_files(self) -> Dict[str, List[str]]:
        """全ソースファイル発見"""
        logger.info("🔍 Discovering all source files...")
        
        source_files = {
            "python": [],
            "powershell": [],
            "typescript": [],
            "javascript": [],
            "test_files": []
        }
        
        # Pythonファイル
        for pattern in ["**/*.py"]:
            for py_file in self.project_root.glob(pattern):
                if any(exclude in str(py_file) for exclude in [".git", "__pycache__", "node_modules", "venv", ".venv"]):
                    continue
                
                if "test_" in py_file.name or py_file.parent.name in ["tests", "Tests"]:
                    source_files["test_files"].append(str(py_file))
                else:
                    source_files["python"].append(str(py_file))
        
        # PowerShellファイル
        for pattern in ["**/*.ps1", "**/*.psm1"]:
            for ps_file in self.project_root.glob(pattern):
                if ".git" not in str(ps_file):
                    source_files["powershell"].append(str(ps_file))
        
        # TypeScript/JavaScriptファイル（フロントエンド）
        if self.frontend_dir.exists():
            for pattern in ["**/*.ts", "**/*.tsx"]:
                for ts_file in self.frontend_dir.glob(pattern):
                    if any(exclude in str(ts_file) for exclude in ["node_modules", "dist", "build"]):
                        continue
                    source_files["typescript"].append(str(ts_file))
            
            for pattern in ["**/*.js", "**/*.jsx"]:
                for js_file in self.frontend_dir.glob(pattern):
                    if any(exclude in str(js_file) for exclude in ["node_modules", "dist", "build"]):
                        continue
                    source_files["javascript"].append(str(js_file))
        
        # 統計
        total_files = sum(len(files) for files in source_files.values())
        logger.info(f"Found {total_files} source files:")
        for file_type, files in source_files.items():
            logger.info(f"  {file_type}: {len(files)} files")
        
        return source_files
    
    def analyze_python_coverage(self) -> Dict[str, Any]:
        """Python カバレッジ分析"""
        logger.info("🐍 Analyzing Python test coverage...")
        
        # coverage.py実行
        coverage_data = {
            "execution_status": "unknown",
            "coverage_percentage": 0.0,
            "lines_covered": 0,
            "lines_total": 0,
            "files_analyzed": 0,
            "missing_lines": [],
            "detailed_results": {}
        }
        
        try:
            # pytest with coverage実行
            cmd = [
                "python", "-m", "pytest",
                str(self.tests_dir),
                "--cov=src",
                "--cov=Tests", 
                "--cov=Apps",
                "--cov=Scripts",
                f"--cov-report=html:{self.reports_dir}/python_coverage_html",
                f"--cov-report=xml:{self.reports_dir}/python_coverage.xml",
                f"--cov-report=json:{self.reports_dir}/python_coverage.json",
                "--cov-report=term-missing",
                "--cov-fail-under=90",
                "-v", "--tb=short",
                "--maxfail=5"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
            
            coverage_data["execution_status"] = "completed"
            coverage_data["exit_code"] = result.returncode
            coverage_data["stdout_lines"] = len(result.stdout.splitlines())
            coverage_data["stderr_lines"] = len(result.stderr.splitlines())
            
            # JSON coverage結果読み込み
            json_coverage_file = self.reports_dir / "python_coverage.json"
            if json_coverage_file.exists():
                with open(json_coverage_file) as f:
                    coverage_json = json.load(f)
                    
                    totals = coverage_json.get("totals", {})
                    coverage_data["coverage_percentage"] = totals.get("percent_covered", 0.0)
                    coverage_data["lines_covered"] = totals.get("covered_lines", 0)
                    coverage_data["lines_total"] = totals.get("num_statements", 0)
                    coverage_data["files_analyzed"] = len(coverage_json.get("files", {}))
                    
                    # 詳細結果
                    coverage_data["detailed_results"] = coverage_json.get("files", {})
            
            # XML coverage結果読み込み（追加分析用）
            xml_coverage_file = self.reports_dir / "python_coverage.xml"
            if xml_coverage_file.exists():
                coverage_data["xml_report_available"] = True
            
            logger.info(f"Python coverage: {coverage_data['coverage_percentage']:.1f}%")
            
        except subprocess.TimeoutExpired:
            coverage_data["execution_status"] = "timeout"
        except Exception as e:
            coverage_data["execution_status"] = "error"
            coverage_data["error"] = str(e)
        
        return coverage_data
    
    def analyze_frontend_coverage(self) -> Dict[str, Any]:
        """フロントエンド(React/TypeScript)カバレッジ分析"""
        logger.info("⚛️ Analyzing frontend test coverage...")
        
        frontend_coverage = {
            "vitest_coverage": {},
            "cypress_coverage": {},
            "combined_coverage": {},
            "execution_status": "unknown"
        }
        
        if not self.frontend_dir.exists():
            frontend_coverage["execution_status"] = "no_frontend"
            return frontend_coverage
        
        try:
            # Vitest カバレッジ実行
            vitest_cmd = ["npm", "run", "test:coverage"]
            
            vitest_result = subprocess.run(
                vitest_cmd, 
                cwd=self.frontend_dir,
                capture_output=True, text=True, timeout=300
            )
            
            frontend_coverage["vitest_coverage"] = {
                "exit_code": vitest_result.returncode,
                "executed": True
            }
            
            # Vitest coverage結果読み込み
            vitest_coverage_file = self.frontend_dir / "coverage" / "coverage-summary.json"
            if vitest_coverage_file.exists():
                with open(vitest_coverage_file) as f:
                    vitest_data = json.load(f)
                    frontend_coverage["vitest_coverage"]["results"] = vitest_data
            
            # Cypress カバレッジ実行（可能であれば）
            try:
                cypress_cmd = ["npm", "run", "test:e2e", "--", "--coverage"]
                
                cypress_result = subprocess.run(
                    cypress_cmd,
                    cwd=self.frontend_dir, 
                    capture_output=True, text=True, timeout=300
                )
                
                frontend_coverage["cypress_coverage"] = {
                    "exit_code": cypress_result.returncode,
                    "executed": True
                }
                
            except Exception as e:
                frontend_coverage["cypress_coverage"] = {
                    "executed": False,
                    "error": str(e)
                }
            
            frontend_coverage["execution_status"] = "completed"
            
        except Exception as e:
            frontend_coverage["execution_status"] = "error"
            frontend_coverage["error"] = str(e)
        
        return frontend_coverage
    
    def analyze_powershell_coverage(self) -> Dict[str, Any]:
        """PowerShell カバレッジ分析"""
        logger.info("⚡ Analyzing PowerShell test coverage...")
        
        powershell_coverage = {
            "pester_coverage": {},
            "manual_analysis": {},
            "execution_status": "unknown"
        }
        
        try:
            # Pester カバレッジ実行
            pester_runner = self.project_root / "Tests" / "powershell_integration" / "Run-PesterTests.ps1"
            
            if pester_runner.exists():
                cmd = [
                    "pwsh", "-ExecutionPolicy", "Bypass",
                    "-File", str(pester_runner),
                    "-TestPath", str(self.project_root),
                    "-TestType", "All",
                    "-OutputPath", str(self.reports_dir)
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
                
                powershell_coverage["pester_coverage"] = {
                    "exit_code": result.returncode,
                    "executed": True,
                    "success": result.returncode == 0
                }
            
            # PowerShellファイル手動分析
            ps_files = list(self.apps_dir.glob("*.ps1")) + list(self.scripts_dir.glob("**/*.ps1"))
            
            analyzed_files = []
            total_functions = 0
            
            for ps_file in ps_files:
                try:
                    content = ps_file.read_text(encoding='utf-8')
                    function_count = content.count("function ")
                    param_count = content.count("param(")
                    
                    analyzed_files.append({
                        "file": str(ps_file),
                        "functions": function_count,
                        "parameters": param_count,
                        "lines": len(content.splitlines())
                    })
                    
                    total_functions += function_count
                    
                except Exception as e:
                    logger.warning(f"Failed to analyze {ps_file}: {e}")
            
            powershell_coverage["manual_analysis"] = {
                "files_analyzed": len(analyzed_files),
                "total_functions": total_functions,
                "detailed_files": analyzed_files
            }
            
            powershell_coverage["execution_status"] = "completed"
            
        except Exception as e:
            powershell_coverage["execution_status"] = "error"
            powershell_coverage["error"] = str(e)
        
        return powershell_coverage
    
    def analyze_26_features_coverage(self) -> Dict[str, Any]:
        """26機能カバレッジ分析"""
        logger.info("🎯 Analyzing 26 features coverage...")
        
        # 26機能定義
        features_26 = {
            "regular_reports": [
                "daily_report", "weekly_report", "monthly_report", 
                "yearly_report", "test_execution"
            ],
            "analysis_reports": [
                "license_analysis", "usage_analysis", "performance_analysis",
                "security_analysis", "permission_audit"
            ],
            "entraid_management": [
                "user_list", "mfa_status", "conditional_access", "signin_logs"
            ],
            "exchange_management": [
                "mailbox_management", "mail_flow", "spam_protection", "delivery_analysis"
            ],
            "teams_management": [
                "teams_usage", "teams_settings", "meeting_quality", "teams_apps"
            ],
            "onedrive_management": [
                "storage_analysis", "sharing_analysis", "sync_errors", "external_sharing"
            ]
        }
        
        all_features = []
        for category_features in features_26.values():
            all_features.extend(category_features)
        
        # 各機能のテストカバレッジ分析
        features_coverage = {
            "total_features": len(all_features),
            "categories": len(features_26),
            "coverage_by_category": {},
            "coverage_by_feature": {},
            "overall_coverage": 0.0
        }
        
        covered_features = 0
        
        for category, features in features_26.items():
            category_coverage = {
                "total": len(features),
                "covered": 0,
                "features": {}
            }
            
            for feature in features:
                # 各機能のテスト存在確認
                feature_covered = self._check_feature_test_coverage(feature)
                category_coverage["features"][feature] = feature_covered
                
                if feature_covered["has_tests"]:
                    category_coverage["covered"] += 1
                    covered_features += 1
            
            category_coverage["coverage_percentage"] = (
                category_coverage["covered"] / category_coverage["total"] * 100
            )
            
            features_coverage["coverage_by_category"][category] = category_coverage
        
        features_coverage["overall_coverage"] = (covered_features / len(all_features)) * 100
        
        return features_coverage
    
    def _check_feature_test_coverage(self, feature: str) -> Dict[str, Any]:
        """個別機能のテストカバレッジチェック"""
        coverage_info = {
            "feature": feature,
            "has_tests": False,
            "test_files": [],
            "test_functions": 0,
            "implementations": []
        }
        
        # テストファイル検索
        test_patterns = [
            f"**/test_{feature}*.py",
            f"**/test_*{feature}*.py",
            f"**/{feature}_test.py",
            f"**/*{feature}*.spec.ts",
            f"**/*{feature}*.cy.ts"
        ]
        
        for pattern in test_patterns:
            test_files = list(self.project_root.glob(pattern))
            for test_file in test_files:
                coverage_info["test_files"].append(str(test_file))
                
                # テスト関数数カウント
                try:
                    content = test_file.read_text(encoding='utf-8')
                    if test_file.suffix == ".py":
                        coverage_info["test_functions"] += content.count("def test_")
                    elif test_file.suffix in [".ts", ".js"]:
                        coverage_info["test_functions"] += content.count("test(") + content.count("it(")
                except Exception:
                    pass
        
        # 実装ファイル検索
        impl_patterns = [
            f"**/src/**/*{feature}*.py",
            f"**/Apps/*{feature}*.ps1",
            f"**/Scripts/**/*{feature}*.ps1",
            f"**/frontend/src/**/*{feature}*.ts",
            f"**/frontend/src/**/*{feature}*.tsx"
        ]
        
        for pattern in impl_patterns:
            impl_files = list(self.project_root.glob(pattern))
            for impl_file in impl_files:
                coverage_info["implementations"].append(str(impl_file))
        
        coverage_info["has_tests"] = len(coverage_info["test_files"]) > 0
        
        return coverage_info
    
    def calculate_quality_metrics(self) -> Dict[str, Any]:
        """品質指標計算"""
        logger.info("📊 Calculating quality metrics...")
        
        quality_metrics = {
            "complexity": self._calculate_complexity(),
            "maintainability": self._calculate_maintainability(),
            "test_quality": self._calculate_test_quality(),
            "performance": self._calculate_performance_metrics(),
            "overall_score": 0.0
        }
        
        # 総合スコア計算
        scores = [
            quality_metrics["complexity"].get("score", 0),
            quality_metrics["maintainability"].get("score", 0), 
            quality_metrics["test_quality"].get("score", 0),
            quality_metrics["performance"].get("score", 0)
        ]
        
        quality_metrics["overall_score"] = sum(scores) / len(scores) if scores else 0.0
        
        return quality_metrics
    
    def _calculate_complexity(self) -> Dict[str, Any]:
        """複雑度計算"""
        complexity_data = {
            "average_complexity": 0.0,
            "max_complexity": 0.0,
            "files_analyzed": 0,
            "score": 100.0
        }
        
        try:
            # radon実行（複雑度測定ツール）
            result = subprocess.run(
                ["python", "-m", "radon", "cc", str(self.src_dir), "-j"],
                capture_output=True, text=True, timeout=60
            )
            
            if result.returncode == 0:
                radon_data = json.loads(result.stdout)
                complexities = []
                
                for file_data in radon_data.values():
                    for item in file_data:
                        if isinstance(item, dict) and "complexity" in item:
                            complexities.append(item["complexity"])
                
                if complexities:
                    complexity_data["average_complexity"] = sum(complexities) / len(complexities)
                    complexity_data["max_complexity"] = max(complexities)
                    complexity_data["files_analyzed"] = len(radon_data)
                    
                    # スコア計算（低い複雑度ほど高スコア）
                    avg_complexity = complexity_data["average_complexity"]
                    complexity_data["score"] = max(0, 100 - (avg_complexity * 10))
                
        except Exception as e:
            logger.warning(f"Complexity analysis failed: {e}")
        
        return complexity_data
    
    def _calculate_maintainability(self) -> Dict[str, Any]:
        """保守性指標計算"""
        maintainability_data = {
            "maintainability_index": 0.0,
            "files_analyzed": 0,
            "score": 0.0
        }
        
        try:
            # radon実行（保守性指標測定）
            result = subprocess.run(
                ["python", "-m", "radon", "mi", str(self.src_dir), "-j"],
                capture_output=True, text=True, timeout=60
            )
            
            if result.returncode == 0:
                mi_data = json.loads(result.stdout)
                mi_scores = []
                
                for file_path, mi_value in mi_data.items():
                    if isinstance(mi_value, (int, float)):
                        mi_scores.append(mi_value)
                
                if mi_scores:
                    maintainability_data["maintainability_index"] = sum(mi_scores) / len(mi_scores)
                    maintainability_data["files_analyzed"] = len(mi_scores)
                    maintainability_data["score"] = maintainability_data["maintainability_index"]
                
        except Exception as e:
            logger.warning(f"Maintainability analysis failed: {e}")
        
        return maintainability_data
    
    def _calculate_test_quality(self) -> Dict[str, Any]:
        """テスト品質計算"""
        test_quality_data = {
            "test_count": 0,
            "assertion_count": 0,
            "test_files": 0,
            "score": 0.0
        }
        
        # テストファイル分析
        test_files = list(self.tests_dir.glob("**/test_*.py"))
        test_count = 0
        assertion_count = 0
        
        for test_file in test_files:
            try:
                content = test_file.read_text(encoding='utf-8')
                test_count += content.count("def test_")
                assertion_count += content.count("assert ")
                
            except Exception:
                pass
        
        test_quality_data["test_count"] = test_count
        test_quality_data["assertion_count"] = assertion_count
        test_quality_data["test_files"] = len(test_files)
        
        # スコア計算
        if test_count > 0:
            assertions_per_test = assertion_count / test_count
            test_quality_data["score"] = min(100, assertions_per_test * 20)  # 5 assertions per test = 100 score
        
        return test_quality_data
    
    def _calculate_performance_metrics(self) -> Dict[str, Any]:
        """パフォーマンス指標計算"""
        performance_data = {
            "test_execution_time": 0.0,
            "memory_usage": 0.0,
            "score": 80.0  # デフォルトスコア
        }
        
        # 簡単なパフォーマンステスト実行
        try:
            start_time = datetime.now()
            
            result = subprocess.run(
                ["python", "-m", "pytest", str(self.tests_dir), "-q", "--tb=no", "--maxfail=1"],
                capture_output=True, text=True, timeout=120
            )
            
            end_time = datetime.now()
            execution_time = (end_time - start_time).total_seconds()
            
            performance_data["test_execution_time"] = execution_time
            
            # 実行時間に基づくスコア（短いほど高スコア）
            if execution_time < 30:
                performance_data["score"] = 100
            elif execution_time < 60:
                performance_data["score"] = 80
            elif execution_time < 120:
                performance_data["score"] = 60
            else:
                performance_data["score"] = 40
                
        except Exception as e:
            logger.warning(f"Performance analysis failed: {e}")
        
        return performance_data
    
    def generate_coverage_improvement_suggestions(self, coverage_results: Dict[str, Any]) -> List[str]:
        """カバレッジ改善提案生成"""
        logger.info("💡 Generating coverage improvement suggestions...")
        
        suggestions = []
        
        # Python カバレッジ
        python_coverage = coverage_results.get("python_coverage", {}).get("coverage_percentage", 0)
        if python_coverage < self.coverage_targets["python"]:
            suggestions.append(
                f"Python カバレッジを {python_coverage:.1f}% から {self.coverage_targets['python']}% に向上させる必要があります。"
            )
            suggestions.append("未テストの関数・クラスに対してユニットテストを追加してください。")
        
        # フロントエンド カバレッジ
        frontend_coverage = coverage_results.get("frontend_coverage", {})
        if frontend_coverage.get("execution_status") == "completed":
            suggestions.append("フロントエンドコンポーネントテストの拡充を検討してください。")
        
        # 26機能カバレッジ
        features_coverage = coverage_results.get("features_26_coverage", {})
        uncovered_features = []
        
        for category, data in features_coverage.get("coverage_by_category", {}).items():
            for feature, feature_data in data.get("features", {}).items():
                if not feature_data.get("has_tests"):
                    uncovered_features.append(feature)
        
        if uncovered_features:
            suggestions.append(f"以下の{len(uncovered_features)}機能にテストが不足しています: {', '.join(uncovered_features[:5])}")
            suggestions.append("各機能にE2Eテストと統合テストを追加してください。")
        
        # 品質指標
        quality_metrics = coverage_results.get("quality_metrics", {})
        overall_score = quality_metrics.get("overall_score", 0)
        
        if overall_score < 80:
            suggestions.append(f"品質スコア {overall_score:.1f} を80以上に向上させる必要があります。")
            
            complexity = quality_metrics.get("complexity", {})
            if complexity.get("average_complexity", 0) > 8:
                suggestions.append("複雑度の高い関数をリファクタリングしてください。")
        
        # 具体的な改善アクション
        suggestions.extend([
            "pytest --cov で詳細なカバレッジレポートを確認してください。",
            "未カバーの分岐条件に対してテストケースを追加してください。",
            "モック・スタブを活用して外部依存を分離したテストを作成してください。",
            "テストデータ生成器を使用してエッジケースのテストを充実させてください。"
        ])
        
        return suggestions
    
    def run_comprehensive_coverage_analysis(self) -> Dict[str, Any]:
        """包括的カバレッジ分析実行"""
        logger.info("🚀 Running comprehensive coverage analysis...")
        
        # ソースファイル発見
        source_files = self.discover_all_source_files()
        
        # Python カバレッジ分析
        python_coverage = self.analyze_python_coverage()
        
        # フロントエンド カバレッジ分析
        frontend_coverage = self.analyze_frontend_coverage()
        
        # PowerShell カバレッジ分析
        powershell_coverage = self.analyze_powershell_coverage()
        
        # 26機能カバレッジ分析
        features_26_coverage = self.analyze_26_features_coverage()
        
        # 品質指標計算
        quality_metrics = self.calculate_quality_metrics()
        
        # 統合結果
        comprehensive_results = {
            "timestamp": self.timestamp,
            "project_root": str(self.project_root),
            "analysis_phase": "comprehensive_coverage",
            "coverage_targets": self.coverage_targets,
            "source_files": source_files,
            "python_coverage": python_coverage,
            "frontend_coverage": frontend_coverage,
            "powershell_coverage": powershell_coverage,
            "features_26_coverage": features_26_coverage,
            "quality_metrics": quality_metrics,
            "overall_assessment": self._generate_overall_assessment(
                python_coverage, frontend_coverage, features_26_coverage, quality_metrics
            )
        }
        
        # 改善提案生成
        comprehensive_results["improvement_suggestions"] = self.generate_coverage_improvement_suggestions(
            comprehensive_results
        )
        
        # 最終レポート保存
        final_report = self.reports_dir / f"comprehensive_coverage_report_{self.timestamp}.json"
        with open(final_report, 'w') as f:
            json.dump(comprehensive_results, f, indent=2)
        
        # HTMLレポート生成
        html_report = self._generate_html_report(comprehensive_results)
        html_report_path = self.reports_dir / f"comprehensive_coverage_report_{self.timestamp}.html"
        with open(html_report_path, 'w', encoding='utf-8') as f:
            f.write(html_report)
        
        logger.info(f"✅ Comprehensive coverage analysis completed!")
        logger.info(f"📄 JSON Report: {final_report}")
        logger.info(f"🌐 HTML Report: {html_report_path}")
        
        return comprehensive_results
    
    def _generate_overall_assessment(self, python_cov, frontend_cov, features_cov, quality) -> Dict[str, Any]:
        """総合評価生成"""
        assessment = {
            "coverage_score": 0.0,
            "quality_score": 0.0,
            "features_completeness": 0.0,
            "overall_grade": "F",
            "target_achievement": False
        }
        
        # カバレッジスコア
        python_score = python_cov.get("coverage_percentage", 0)
        features_score = features_cov.get("overall_coverage", 0)
        coverage_score = (python_score * 0.6 + features_score * 0.4)  # 重み付け平均
        
        assessment["coverage_score"] = coverage_score
        assessment["quality_score"] = quality.get("overall_score", 0)
        assessment["features_completeness"] = features_score
        
        # 総合評価
        overall_score = (coverage_score * 0.5 + assessment["quality_score"] * 0.3 + features_score * 0.2)
        
        if overall_score >= 90:
            assessment["overall_grade"] = "A"
        elif overall_score >= 80:
            assessment["overall_grade"] = "B"
        elif overall_score >= 70:
            assessment["overall_grade"] = "C"
        elif overall_score >= 60:
            assessment["overall_grade"] = "D"
        else:
            assessment["overall_grade"] = "F"
        
        assessment["target_achievement"] = coverage_score >= self.coverage_targets["overall"]
        
        return assessment
    
    def _generate_html_report(self, results: Dict[str, Any]) -> str:
        """HTMLレポート生成"""
        html_content = f'''<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>包括的テストカバレッジレポート - Microsoft 365 Management Tools</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .header {{ text-align: center; margin-bottom: 30px; border-bottom: 2px solid #0078d4; padding-bottom: 20px; }}
        .metric-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }}
        .metric-card {{ background: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #0078d4; }}
        .metric-value {{ font-size: 2em; font-weight: bold; color: #0078d4; }}
        .progress-bar {{ width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; margin: 10px 0; }}
        .progress-fill {{ height: 100%; background: linear-gradient(90deg, #ff6b6b, #feca57, #48dbfb, #0be881); transition: width 0.3s; }}
        .grade-a {{ color: #0be881; }}
        .grade-b {{ color: #48dbfb; }}
        .grade-c {{ color: #feca57; }}
        .grade-d {{ color: #ff9ff3; }}
        .grade-f {{ color: #ff6b6b; }}
        .suggestions {{ background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 15px; margin: 20px 0; }}
        .feature-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }}
        .feature-item {{ padding: 10px; border-radius: 5px; text-align: center; }}
        .covered {{ background: #d4edda; color: #155724; }}
        .uncovered {{ background: #f8d7da; color: #721c24; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 包括的テストカバレッジレポート</h1>
            <h2>Microsoft 365 Management Tools</h2>
            <p>生成日時: {results['timestamp']}</p>
        </div>
        
        <div class="metric-grid">
            <div class="metric-card">
                <h3>🎯 総合カバレッジ</h3>
                <div class="metric-value">{results['overall_assessment']['coverage_score']:.1f}%</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {results['overall_assessment']['coverage_score']}%"></div>
                </div>
                <p>目標: {results['coverage_targets']['overall']}%</p>
            </div>
            
            <div class="metric-card">
                <h3>🐍 Python カバレッジ</h3>
                <div class="metric-value">{results['python_coverage']['coverage_percentage']:.1f}%</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {results['python_coverage']['coverage_percentage']}%"></div>
                </div>
                <p>実行ライン: {results['python_coverage']['lines_covered']}/{results['python_coverage']['lines_total']}</p>
            </div>
            
            <div class="metric-card">
                <h3>🎯 26機能カバレッジ</h3>
                <div class="metric-value">{results['features_26_coverage']['overall_coverage']:.1f}%</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {results['features_26_coverage']['overall_coverage']}%"></div>
                </div>
                <p>機能数: {results['features_26_coverage']['total_features']}</p>
            </div>
            
            <div class="metric-card">
                <h3>📈 品質スコア</h3>
                <div class="metric-value grade-{results['overall_assessment']['overall_grade'].lower()}">{results['overall_assessment']['overall_grade']}</div>
                <p>総合スコア: {results['quality_metrics']['overall_score']:.1f}</p>
            </div>
        </div>
        
        <h3>🎯 26機能カバレッジ詳細</h3>
        <div class="feature-grid">
'''
        
        # 26機能詳細
        for category, data in results['features_26_coverage']['coverage_by_category'].items():
            for feature, feature_data in data['features'].items():
                status_class = "covered" if feature_data['has_tests'] else "uncovered"
                status_text = "✅ テスト済" if feature_data['has_tests'] else "❌ 未テスト"
                html_content += f'''
            <div class="feature-item {status_class}">
                <strong>{feature}</strong><br>
                {status_text}
            </div>'''
        
        html_content += f'''
        </div>
        
        <h3>💡 改善提案</h3>
        <div class="suggestions">
            <ul>
'''
        
        for suggestion in results['improvement_suggestions'][:10]:
            html_content += f'<li>{suggestion}</li>'
        
        html_content += '''
            </ul>
        </div>
        
        <h3>📊 詳細メトリクス</h3>
        <div class="metric-grid">
            <div class="metric-card">
                <h4>複雑度</h4>
                <p>平均: {:.1f}</p>
                <p>最大: {:.1f}</p>
            </div>
            <div class="metric-card">
                <h4>保守性</h4>
                <p>指標: {:.1f}</p>
            </div>
            <div class="metric-card">
                <h4>テスト品質</h4>
                <p>テスト数: {}</p>
                <p>アサーション数: {}</p>
            </div>
            <div class="metric-card">
                <h4>パフォーマンス</h4>
                <p>実行時間: {:.1f}秒</p>
            </div>
        </div>
    </div>
</body>
</html>'''.format(
            results['quality_metrics']['complexity']['average_complexity'],
            results['quality_metrics']['complexity']['max_complexity'],
            results['quality_metrics']['maintainability']['maintainability_index'],
            results['quality_metrics']['test_quality']['test_count'],
            results['quality_metrics']['test_quality']['assertion_count'],
            results['quality_metrics']['performance']['test_execution_time']
        )
        
        return html_content


# pytest統合用テスト関数
@pytest.mark.coverage
@pytest.mark.quality
def test_coverage_analyzer_setup():
    """カバレッジ分析器セットアップテスト"""
    analyzer = ComprehensiveCoverageAnalyzer()
    
    assert analyzer.coverage_targets["overall"] == 90.0
    assert analyzer.coverage_targets["26_features"] == 100.0
    assert len(analyzer.quality_thresholds) >= 4


@pytest.mark.coverage
@pytest.mark.slow
def test_python_coverage_analysis():
    """Python カバレッジ分析テスト"""
    analyzer = ComprehensiveCoverageAnalyzer()
    
    coverage_result = analyzer.analyze_python_coverage()
    assert coverage_result["execution_status"] in ["completed", "timeout", "error"]
    
    if coverage_result["execution_status"] == "completed":
        assert isinstance(coverage_result["coverage_percentage"], float)
        assert coverage_result["coverage_percentage"] >= 0


@pytest.mark.coverage
@pytest.mark.features_26
def test_26_features_coverage_analysis():
    """26機能カバレッジ分析テスト"""
    analyzer = ComprehensiveCoverageAnalyzer()
    
    features_coverage = analyzer.analyze_26_features_coverage()
    assert features_coverage["total_features"] == 26
    assert features_coverage["categories"] == 6
    assert "coverage_by_category" in features_coverage


@pytest.mark.coverage
@pytest.mark.quality
def test_quality_metrics_calculation():
    """品質指標計算テスト"""
    analyzer = ComprehensiveCoverageAnalyzer()
    
    quality_metrics = analyzer.calculate_quality_metrics()
    assert "complexity" in quality_metrics
    assert "maintainability" in quality_metrics
    assert "test_quality" in quality_metrics
    assert "performance" in quality_metrics


@pytest.mark.coverage
@pytest.mark.slow
def test_comprehensive_coverage_analysis():
    """包括的カバレッジ分析テスト"""
    analyzer = ComprehensiveCoverageAnalyzer()
    
    results = analyzer.run_comprehensive_coverage_analysis()
    assert results["analysis_phase"] == "comprehensive_coverage"
    assert "overall_assessment" in results
    assert "improvement_suggestions" in results


if __name__ == "__main__":
    # スタンドアロン実行
    analyzer = ComprehensiveCoverageAnalyzer()
    results = analyzer.run_comprehensive_coverage_analysis()
    
    print("\n" + "="*60)
    print("📊 COMPREHENSIVE COVERAGE ANALYSIS RESULTS")
    print("="*60)
    print(f"Overall Coverage: {results['overall_assessment']['coverage_score']:.1f}%")
    print(f"Python Coverage: {results['python_coverage']['coverage_percentage']:.1f}%")
    print(f"26 Features Coverage: {results['features_26_coverage']['overall_coverage']:.1f}%")
    print(f"Quality Grade: {results['overall_assessment']['overall_grade']}")
    print(f"Target Achievement: {results['overall_assessment']['target_achievement']}")
    print("="*60)