"""
継続的品質改善システム
コード品質・セキュリティ・パフォーマンス・可用性の継続的監視・改善
"""

import asyncio
import json
import subprocess
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
from pathlib import Path
from dataclasses import dataclass, asdict
from enum import Enum
import tempfile
import statistics
import ast

from ..core.config import settings
from ..core.logging_config import get_logger

logger = get_logger(__name__)

class QualityMetricType(str, Enum):
    """品質メトリクスタイプ"""
    CODE_QUALITY = "code_quality"
    SECURITY = "security"
    PERFORMANCE = "performance"
    MAINTAINABILITY = "maintainability"
    RELIABILITY = "reliability"
    COVERAGE = "coverage"

class SeverityLevel(str, Enum):
    """重要度レベル"""
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INFO = "info"

@dataclass
class QualityIssue:
    """品質問題"""
    issue_type: QualityMetricType
    severity: SeverityLevel
    file_path: str
    line_number: Optional[int]
    message: str
    rule_id: Optional[str]
    suggestion: Optional[str]
    detected_at: datetime
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            **asdict(self),
            "detected_at": self.detected_at.isoformat()
        }

@dataclass
class QualityReport:
    """品質レポート"""
    generated_at: datetime
    overall_score: float
    metrics: Dict[QualityMetricType, Dict[str, Any]]
    issues: List[QualityIssue]
    recommendations: List[str]
    trend_data: Dict[str, List[float]]
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "generated_at": self.generated_at.isoformat(),
            "overall_score": self.overall_score,
            "metrics": {k.value: v for k, v in self.metrics.items()},
            "issues": [issue.to_dict() for issue in self.issues],
            "recommendations": self.recommendations,
            "trend_data": self.trend_data
        }

class CodeQualityAnalyzer:
    """コード品質分析器"""
    
    def __init__(self):
        self.base_dir = Path(settings.base_dir)
        self.src_dir = self.base_dir / "src"
        
    async def analyze_code_quality(self) -> Dict[str, Any]:
        """コード品質分析"""
        try:
            results = {}
            
            # Black (コードフォーマット)
            black_results = await self._run_black_check()
            results["formatting"] = black_results
            
            # isort (import順序)
            isort_results = await self._run_isort_check()
            results["import_order"] = isort_results
            
            # Flake8 (スタイル・品質)
            flake8_results = await self._run_flake8()
            results["style_quality"] = flake8_results
            
            # MyPy (型チェック)
            mypy_results = await self._run_mypy()
            results["type_checking"] = mypy_results
            
            # Pylint (品質メトリクス)
            pylint_results = await self._run_pylint()
            results["code_metrics"] = pylint_results
            
            # 複雑度分析
            complexity_results = await self._analyze_complexity()
            results["complexity"] = complexity_results
            
            # コードクローン検出
            clone_results = await self._detect_code_clones()
            results["code_clones"] = clone_results
            
            return results
            
        except Exception as e:
            logger.error(f"Code quality analysis failed: {e}")
            return {"error": str(e)}
    
    async def _run_black_check(self) -> Dict[str, Any]:
        """Black フォーマットチェック"""
        try:
            result = await self._run_command([
                "black", "--check", "--diff", str(self.src_dir)
            ])
            
            return {
                "passed": result.returncode == 0,
                "issues_count": len(result.stdout.split("\n")) if result.stdout else 0,
                "details": result.stdout if result.returncode != 0 else "All files formatted correctly"
            }
            
        except Exception as e:
            return {"error": str(e), "passed": False}
    
    async def _run_isort_check(self) -> Dict[str, Any]:
        """isort インポート順序チェック"""
        try:
            result = await self._run_command([
                "isort", "--check-only", "--diff", str(self.src_dir)
            ])
            
            return {
                "passed": result.returncode == 0,
                "issues_count": len([line for line in result.stdout.split("\n") if "would reformat" in line]),
                "details": result.stdout if result.returncode != 0 else "All imports correctly ordered"
            }
            
        except Exception as e:
            return {"error": str(e), "passed": False}
    
    async def _run_flake8(self) -> Dict[str, Any]:
        """Flake8 スタイルチェック"""
        try:
            result = await self._run_command([
                "flake8", str(self.src_dir), "--format=json"
            ])
            
            if result.stdout:
                issues = []
                for line in result.stdout.split("\n"):
                    if line.strip():
                        try:
                            issue = json.loads(line)
                            issues.append(issue)
                        except json.JSONDecodeError:
                            continue
                
                return {
                    "passed": len(issues) == 0,
                    "issues_count": len(issues),
                    "issues": issues[:50],  # 最初の50件のみ
                    "summary": self._summarize_flake8_issues(issues)
                }
            else:
                return {"passed": True, "issues_count": 0, "issues": []}
                
        except Exception as e:
            return {"error": str(e), "passed": False}
    
    async def _run_mypy(self) -> Dict[str, Any]:
        """MyPy 型チェック"""
        try:
            result = await self._run_command([
                "mypy", str(self.src_dir), "--json-report", "/tmp/mypy_report"
            ])
            
            # JSON レポート読み込み
            report_file = Path("/tmp/mypy_report/index.txt")
            if report_file.exists():
                with open(report_file, 'r') as f:
                    mypy_output = f.read()
                
                # エラー数カウント
                error_count = mypy_output.count("error:")
                
                return {
                    "passed": error_count == 0,
                    "error_count": error_count,
                    "details": mypy_output[:2000] if error_count > 0 else "No type errors found"
                }
            else:
                return {
                    "passed": result.returncode == 0,
                    "error_count": 0 if result.returncode == 0 else -1,
                    "details": result.stdout or result.stderr
                }
                
        except Exception as e:
            return {"error": str(e), "passed": False}
    
    async def _run_pylint(self) -> Dict[str, Any]:
        """Pylint 品質メトリクス"""
        try:
            result = await self._run_command([
                "pylint", str(self.src_dir), "--output-format=json"
            ])
            
            if result.stdout:
                try:
                    issues = json.loads(result.stdout)
                    
                    # スコア計算
                    score = 10.0 - (len(issues) * 0.1)  # 簡易スコア計算
                    score = max(0.0, min(10.0, score))
                    
                    return {
                        "score": round(score, 2),
                        "issues_count": len(issues),
                        "issues_by_type": self._categorize_pylint_issues(issues),
                        "top_issues": issues[:20]  # 上位20件
                    }
                except json.JSONDecodeError:
                    return {"error": "Failed to parse pylint output", "score": 0.0}
            else:
                return {"score": 10.0, "issues_count": 0, "issues_by_type": {}}
                
        except Exception as e:
            return {"error": str(e), "score": 0.0}
    
    async def _analyze_complexity(self) -> Dict[str, Any]:
        """コード複雑度分析"""
        try:
            complexity_data = []
            
            for py_file in self.src_dir.rglob("*.py"):
                if py_file.name.startswith("test_"):
                    continue
                    
                complexity = await self._calculate_file_complexity(py_file)
                complexity_data.append({
                    "file": str(py_file.relative_to(self.base_dir)),
                    "complexity": complexity
                })
            
            if complexity_data:
                complexities = [data["complexity"] for data in complexity_data]
                return {
                    "average_complexity": round(statistics.mean(complexities), 2),
                    "max_complexity": max(complexities),
                    "files_over_threshold": len([c for c in complexities if c > 10]),
                    "files": complexity_data[:20]  # 上位20ファイル
                }
            else:
                return {"average_complexity": 0, "max_complexity": 0, "files_over_threshold": 0}
                
        except Exception as e:
            return {"error": str(e)}
    
    async def _calculate_file_complexity(self, file_path: Path) -> int:
        """ファイル複雑度計算（サイクロマティック複雑度）"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            tree = ast.parse(content)
            complexity = 1  # 基本複雑度
            
            for node in ast.walk(tree):
                if isinstance(node, (ast.If, ast.While, ast.For, ast.With, ast.Try)):
                    complexity += 1
                elif isinstance(node, ast.BoolOp):
                    complexity += len(node.values) - 1
                elif isinstance(node, (ast.And, ast.Or)):
                    complexity += 1
            
            return complexity
            
        except Exception:
            return 0
    
    async def _detect_code_clones(self) -> Dict[str, Any]:
        """コードクローン検出"""
        try:
            # 簡易クローン検出（関数レベル）
            function_hashes = {}
            clones = []
            
            for py_file in self.src_dir.rglob("*.py"):
                if py_file.name.startswith("test_"):
                    continue
                
                with open(py_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                try:
                    tree = ast.parse(content)
                    for node in ast.walk(tree):
                        if isinstance(node, ast.FunctionDef):
                            func_hash = hash(ast.dump(node))
                            if func_hash in function_hashes:
                                clones.append({
                                    "function": node.name,
                                    "files": [function_hashes[func_hash], str(py_file.relative_to(self.base_dir))],
                                    "lines": node.lineno
                                })
                            else:
                                function_hashes[func_hash] = str(py_file.relative_to(self.base_dir))
                except:
                    continue
            
            return {
                "clones_count": len(clones),
                "clones": clones[:10]  # 上位10件
            }
            
        except Exception as e:
            return {"error": str(e), "clones_count": 0}
    
    def _summarize_flake8_issues(self, issues: List[Dict[str, Any]]) -> Dict[str, int]:
        """Flake8問題サマリー"""
        summary = {}
        for issue in issues:
            code = issue.get("code", "Unknown")
            summary[code] = summary.get(code, 0) + 1
        return summary
    
    def _categorize_pylint_issues(self, issues: List[Dict[str, Any]]) -> Dict[str, int]:
        """Pylint問題カテゴリ分け"""
        categories = {"error": 0, "warning": 0, "refactor": 0, "convention": 0}
        for issue in issues:
            msg_type = issue.get("type", "").lower()
            if msg_type in categories:
                categories[msg_type] += 1
        return categories
    
    async def _run_command(self, command: List[str]) -> subprocess.CompletedProcess:
        """コマンド実行"""
        try:
            process = await asyncio.create_subprocess_exec(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.base_dir)
            )
            
            stdout, stderr = await process.communicate()
            
            return subprocess.CompletedProcess(
                args=command,
                returncode=process.returncode,
                stdout=stdout.decode('utf-8', errors='replace'),
                stderr=stderr.decode('utf-8', errors='replace')
            )
        except Exception as e:
            logger.error(f"Command execution failed: {command}, error: {e}")
            return subprocess.CompletedProcess(
                args=command,
                returncode=-1,
                stdout="",
                stderr=str(e)
            )

class SecurityAnalyzer:
    """セキュリティ分析器"""
    
    def __init__(self):
        self.base_dir = Path(settings.base_dir)
        self.src_dir = self.base_dir / "src"
    
    async def analyze_security(self) -> Dict[str, Any]:
        """セキュリティ分析"""
        try:
            results = {}
            
            # Bandit (セキュリティ脆弱性)
            bandit_results = await self._run_bandit()
            results["vulnerabilities"] = bandit_results
            
            # Safety (依存関係脆弱性)
            safety_results = await self._run_safety()
            results["dependencies"] = safety_results
            
            # 秘密情報検出
            secrets_results = await self._detect_secrets()
            results["secrets"] = secrets_results
            
            # 許可・認証チェック
            auth_results = await self._analyze_authentication()
            results["authentication"] = auth_results
            
            return results
            
        except Exception as e:
            logger.error(f"Security analysis failed: {e}")
            return {"error": str(e)}
    
    async def _run_bandit(self) -> Dict[str, Any]:
        """Bandit セキュリティスキャン"""
        try:
            result = await self._run_command([
                "bandit", "-r", str(self.src_dir), "-f", "json"
            ])
            
            if result.stdout:
                try:
                    bandit_data = json.loads(result.stdout)
                    
                    issues = bandit_data.get("results", [])
                    
                    # 重要度別集計
                    severity_counts = {"HIGH": 0, "MEDIUM": 0, "LOW": 0}
                    for issue in issues:
                        severity = issue.get("issue_severity", "LOW")
                        severity_counts[severity] = severity_counts.get(severity, 0) + 1
                    
                    return {
                        "total_issues": len(issues),
                        "severity_breakdown": severity_counts,
                        "high_risk_issues": [
                            issue for issue in issues 
                            if issue.get("issue_severity") == "HIGH"
                        ][:10],  # 上位10件のHIGHリスク
                        "confidence_levels": self._analyze_confidence_levels(issues)
                    }
                except json.JSONDecodeError:
                    return {"error": "Failed to parse bandit output", "total_issues": 0}
            else:
                return {"total_issues": 0, "severity_breakdown": {}}
                
        except Exception as e:
            return {"error": str(e), "total_issues": 0}
    
    async def _run_safety(self) -> Dict[str, Any]:
        """Safety 依存関係脆弱性チェック"""
        try:
            result = await self._run_command([
                "safety", "check", "--json"
            ])
            
            if result.stdout:
                try:
                    safety_data = json.loads(result.stdout)
                    
                    vulnerabilities = safety_data if isinstance(safety_data, list) else []
                    
                    return {
                        "vulnerable_packages": len(vulnerabilities),
                        "vulnerabilities": vulnerabilities[:20],  # 上位20件
                        "critical_count": len([v for v in vulnerabilities if "critical" in str(v).lower()])
                    }
                except json.JSONDecodeError:
                    return {"error": "Failed to parse safety output", "vulnerable_packages": 0}
            else:
                return {"vulnerable_packages": 0, "vulnerabilities": []}
                
        except Exception as e:
            return {"error": str(e), "vulnerable_packages": 0}
    
    async def _detect_secrets(self) -> Dict[str, Any]:
        """秘密情報検出"""
        try:
            secrets_found = []
            
            # パスワード・キーパターン
            secret_patterns = [
                r"password\s*=\s*['\"][^'\"]{6,}['\"]",
                r"api_key\s*=\s*['\"][^'\"]{10,}['\"]",
                r"secret\s*=\s*['\"][^'\"]{10,}['\"]",
                r"token\s*=\s*['\"][^'\"]{10,}['\"]"
            ]
            
            import re
            
            for py_file in self.src_dir.rglob("*.py"):
                if py_file.name.startswith("test_"):
                    continue
                
                try:
                    with open(py_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    for line_num, line in enumerate(content.split('\n'), 1):
                        for pattern in secret_patterns:
                            if re.search(pattern, line, re.IGNORECASE):
                                secrets_found.append({
                                    "file": str(py_file.relative_to(self.base_dir)),
                                    "line": line_num,
                                    "type": "potential_secret",
                                    "pattern": pattern
                                })
                except:
                    continue
            
            return {
                "secrets_found": len(secrets_found),
                "locations": secrets_found[:10]  # 上位10件
            }
            
        except Exception as e:
            return {"error": str(e), "secrets_found": 0}
    
    async def _analyze_authentication(self) -> Dict[str, Any]:
        """認証・認可分析"""
        try:
            auth_issues = []
            
            # 認証関連ファイル検索
            auth_files = list(self.src_dir.rglob("*auth*")) + list(self.src_dir.rglob("*security*"))
            
            # 基本的な認証チェック
            for auth_file in auth_files:
                if auth_file.is_file() and auth_file.suffix == ".py":
                    try:
                        with open(auth_file, 'r', encoding='utf-8') as f:
                            content = f.read()
                        
                        # SQLインジェクション脆弱性チェック
                        if "execute(" in content and "%" in content:
                            auth_issues.append({
                                "file": str(auth_file.relative_to(self.base_dir)),
                                "issue": "Potential SQL injection vulnerability",
                                "severity": "HIGH"
                            })
                        
                        # ハードコードされた認証情報チェック
                        if "password" in content.lower() and "=" in content:
                            auth_issues.append({
                                "file": str(auth_file.relative_to(self.base_dir)),
                                "issue": "Potential hardcoded credentials",
                                "severity": "MEDIUM"
                            })
                    except:
                        continue
            
            return {
                "auth_files_count": len(auth_files),
                "issues_found": len(auth_issues),
                "issues": auth_issues
            }
            
        except Exception as e:
            return {"error": str(e), "auth_files_count": 0, "issues_found": 0}
    
    def _analyze_confidence_levels(self, issues: List[Dict[str, Any]]) -> Dict[str, int]:
        """信頼度レベル分析"""
        confidence_counts = {"HIGH": 0, "MEDIUM": 0, "LOW": 0}
        for issue in issues:
            confidence = issue.get("issue_confidence", "LOW")
            confidence_counts[confidence] = confidence_counts.get(confidence, 0) + 1
        return confidence_counts
    
    async def _run_command(self, command: List[str]) -> subprocess.CompletedProcess:
        """コマンド実行"""
        try:
            process = await asyncio.create_subprocess_exec(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.base_dir)
            )
            
            stdout, stderr = await process.communicate()
            
            return subprocess.CompletedProcess(
                args=command,
                returncode=process.returncode,
                stdout=stdout.decode('utf-8', errors='replace'),
                stderr=stderr.decode('utf-8', errors='replace')
            )
        except Exception as e:
            return subprocess.CompletedProcess(
                args=command,
                returncode=-1,
                stdout="",
                stderr=str(e)
            )

class PerformanceAnalyzer:
    """パフォーマンス分析器"""
    
    def __init__(self):
        self.base_dir = Path(settings.base_dir)
    
    async def analyze_performance(self) -> Dict[str, Any]:
        """パフォーマンス分析"""
        try:
            results = {}
            
            # プロファイリング結果分析
            profiling_results = await self._analyze_profiling_data()
            results["profiling"] = profiling_results
            
            # メモリ使用量分析
            memory_results = await self._analyze_memory_usage()
            results["memory"] = memory_results
            
            # 応答時間分析
            response_time_results = await self._analyze_response_times()
            results["response_times"] = response_time_results
            
            # データベースパフォーマンス
            db_results = await self._analyze_database_performance()
            results["database"] = db_results
            
            return results
            
        except Exception as e:
            logger.error(f"Performance analysis failed: {e}")
            return {"error": str(e)}
    
    async def _analyze_profiling_data(self) -> Dict[str, Any]:
        """プロファイリングデータ分析"""
        # 実装省略：実際のプロファイリングデータ分析
        return {
            "hot_spots": [],
            "slow_functions": [],
            "optimization_suggestions": [
                "Consider caching frequently accessed data",
                "Optimize database queries",
                "Use async operations for I/O bound tasks"
            ]
        }
    
    async def _analyze_memory_usage(self) -> Dict[str, Any]:
        """メモリ使用量分析"""
        try:
            import psutil
            
            # 現在のプロセス情報
            process = psutil.Process()
            memory_info = process.memory_info()
            
            return {
                "current_usage_mb": round(memory_info.rss / (1024 * 1024), 2),
                "peak_usage_mb": round(memory_info.vms / (1024 * 1024), 2),
                "memory_percent": round(process.memory_percent(), 2),
                "recommendations": self._get_memory_recommendations(memory_info)
            }
            
        except ImportError:
            return {"error": "psutil not available", "current_usage_mb": 0}
        except Exception as e:
            return {"error": str(e), "current_usage_mb": 0}
    
    async def _analyze_response_times(self) -> Dict[str, Any]:
        """応答時間分析"""
        # パフォーマンス最適化モジュールからメトリクス取得
        try:
            from ..api.optimization.performance_optimizer import performance_metrics
            
            stats = performance_metrics.get_stats()
            
            return {
                "average_response_time_ms": stats.get("avg_response_time_ms", 0),
                "p95_response_time_ms": stats.get("p95_response_time_ms", 0),
                "total_requests": stats.get("total_requests", 0),
                "performance_rating": self._calculate_performance_rating(stats)
            }
            
        except ImportError:
            return {"error": "Performance metrics not available"}
        except Exception as e:
            return {"error": str(e)}
    
    async def _analyze_database_performance(self) -> Dict[str, Any]:
        """データベースパフォーマンス分析"""
        # データベース接続プールマネージャーから統計取得
        try:
            from ..api.optimization.performance_optimizer import connection_pool_manager
            
            pool_stats = connection_pool_manager.get_pool_stats()
            
            return {
                "active_connections": pool_stats.get("active_connections", 0),
                "pool_size": pool_stats.get("pool_size", 0),
                "avg_query_time_ms": round(pool_stats.get("avg_query_time", 0) * 1000, 2),
                "total_queries": pool_stats.get("total_queries", 0),
                "optimization_suggestions": self._get_db_optimization_suggestions(pool_stats)
            }
            
        except ImportError:
            return {"error": "Database metrics not available"}
        except Exception as e:
            return {"error": str(e)}
    
    def _get_memory_recommendations(self, memory_info) -> List[str]:
        """メモリ最適化推奨事項"""
        recommendations = []
        
        memory_mb = memory_info.rss / (1024 * 1024)
        
        if memory_mb > 1000:  # 1GB以上
            recommendations.append("Consider implementing memory caching strategies")
            recommendations.append("Review large object allocations")
        
        if memory_mb > 500:  # 500MB以上
            recommendations.append("Monitor for memory leaks")
            recommendations.append("Optimize data structures")
        
        return recommendations
    
    def _calculate_performance_rating(self, stats: Dict[str, Any]) -> str:
        """パフォーマンス評価"""
        avg_time = stats.get("avg_response_time_ms", 0)
        
        if avg_time < 100:
            return "Excellent"
        elif avg_time < 500:
            return "Good"
        elif avg_time < 1000:
            return "Fair"
        else:
            return "Poor"
    
    def _get_db_optimization_suggestions(self, pool_stats: Dict[str, Any]) -> List[str]:
        """データベース最適化推奨事項"""
        suggestions = []
        
        avg_query_time = pool_stats.get("avg_query_time", 0) * 1000
        
        if avg_query_time > 1000:  # 1秒以上
            suggestions.append("Review slow queries and add appropriate indexes")
            suggestions.append("Consider query optimization and caching")
        
        active_connections = pool_stats.get("active_connections", 0)
        pool_size = pool_stats.get("pool_size", 0)
        
        if active_connections > pool_size * 0.8:
            suggestions.append("Consider increasing connection pool size")
        
        return suggestions

class ContinuousQualityManager:
    """継続的品質改善マネージャー"""
    
    def __init__(self):
        self.code_analyzer = CodeQualityAnalyzer()
        self.security_analyzer = SecurityAnalyzer()
        self.performance_analyzer = PerformanceAnalyzer()
        self.reports_dir = Path(settings.base_dir) / "Reports" / "quality"
        self.reports_dir.mkdir(parents=True, exist_ok=True)
    
    async def generate_comprehensive_quality_report(self) -> QualityReport:
        """包括的品質レポート生成"""
        try:
            logger.info("Starting comprehensive quality analysis...")
            
            # 各分析実行
            code_quality = await self.code_analyzer.analyze_code_quality()
            security_analysis = await self.security_analyzer.analyze_security()
            performance_analysis = await self.performance_analyzer.analyze_performance()
            
            # メトリクス統合
            metrics = {
                QualityMetricType.CODE_QUALITY: code_quality,
                QualityMetricType.SECURITY: security_analysis,
                QualityMetricType.PERFORMANCE: performance_analysis
            }
            
            # 問題抽出
            issues = self._extract_issues(metrics)
            
            # 総合スコア計算
            overall_score = self._calculate_overall_score(metrics)
            
            # 推奨事項生成
            recommendations = self._generate_recommendations(metrics, issues)
            
            # トレンドデータ（履歴データがある場合）
            trend_data = await self._get_trend_data()
            
            report = QualityReport(
                generated_at=datetime.utcnow(),
                overall_score=overall_score,
                metrics=metrics,
                issues=issues,
                recommendations=recommendations,
                trend_data=trend_data
            )
            
            # レポート保存
            await self._save_report(report)
            
            logger.info(f"Quality report generated with overall score: {overall_score}")
            return report
            
        except Exception as e:
            logger.error(f"Failed to generate quality report: {e}")
            raise
    
    def _extract_issues(self, metrics: Dict[QualityMetricType, Dict[str, Any]]) -> List[QualityIssue]:
        """問題抽出"""
        issues = []
        
        # コード品質問題
        code_quality = metrics.get(QualityMetricType.CODE_QUALITY, {})
        if "style_quality" in code_quality and "issues" in code_quality["style_quality"]:
            for issue in code_quality["style_quality"]["issues"][:20]:  # 上位20件
                issues.append(QualityIssue(
                    issue_type=QualityMetricType.CODE_QUALITY,
                    severity=SeverityLevel.MEDIUM,
                    file_path=issue.get("filename", "unknown"),
                    line_number=issue.get("line_number"),
                    message=issue.get("text", ""),
                    rule_id=issue.get("code"),
                    suggestion="Follow PEP 8 guidelines",
                    detected_at=datetime.utcnow()
                ))
        
        # セキュリティ問題
        security = metrics.get(QualityMetricType.SECURITY, {})
        if "vulnerabilities" in security and "high_risk_issues" in security["vulnerabilities"]:
            for issue in security["vulnerabilities"]["high_risk_issues"]:
                issues.append(QualityIssue(
                    issue_type=QualityMetricType.SECURITY,
                    severity=SeverityLevel.HIGH,
                    file_path=issue.get("filename", "unknown"),
                    line_number=issue.get("line_number"),
                    message=issue.get("issue_text", ""),
                    rule_id=issue.get("test_id"),
                    suggestion="Review security implications and apply fixes",
                    detected_at=datetime.utcnow()
                ))
        
        return issues
    
    def _calculate_overall_score(self, metrics: Dict[QualityMetricType, Dict[str, Any]]) -> float:
        """総合スコア計算"""
        scores = []
        
        # コード品質スコア
        code_quality = metrics.get(QualityMetricType.CODE_QUALITY, {})
        if "code_metrics" in code_quality and "score" in code_quality["code_metrics"]:
            scores.append(code_quality["code_metrics"]["score"])
        
        # セキュリティスコア（脆弱性数から計算）
        security = metrics.get(QualityMetricType.SECURITY, {})
        if "vulnerabilities" in security:
            vuln_count = security["vulnerabilities"].get("total_issues", 0)
            security_score = max(0, 10 - (vuln_count * 0.5))
            scores.append(security_score)
        
        # パフォーマンススコア
        performance = metrics.get(QualityMetricType.PERFORMANCE, {})
        if "response_times" in performance:
            perf_rating = performance["response_times"].get("performance_rating", "Poor")
            perf_score = {"Excellent": 10, "Good": 8, "Fair": 6, "Poor": 4}.get(perf_rating, 5)
            scores.append(perf_score)
        
        if scores:
            return round(sum(scores) / len(scores), 2)
        else:
            return 7.0  # デフォルトスコア
    
    def _generate_recommendations(self, metrics: Dict[QualityMetricType, Dict[str, Any]], issues: List[QualityIssue]) -> List[str]:
        """推奨事項生成"""
        recommendations = []
        
        # コード品質推奨事項
        code_quality = metrics.get(QualityMetricType.CODE_QUALITY, {})
        if "complexity" in code_quality:
            complexity = code_quality["complexity"]
            if complexity.get("files_over_threshold", 0) > 0:
                recommendations.append("Reduce complexity in functions with high cyclomatic complexity")
        
        # セキュリティ推奨事項
        security = metrics.get(QualityMetricType.SECURITY, {})
        if "vulnerabilities" in security:
            vuln_count = security["vulnerabilities"].get("total_issues", 0)
            if vuln_count > 0:
                recommendations.append("Address high-priority security vulnerabilities")
        
        # パフォーマンス推奨事項
        performance = metrics.get(QualityMetricType.PERFORMANCE, {})
        if "memory" in performance:
            memory_mb = performance["memory"].get("current_usage_mb", 0)
            if memory_mb > 500:
                recommendations.append("Optimize memory usage and implement caching strategies")
        
        # 高頻度問題に対する推奨事項
        issue_counts = {}
        for issue in issues:
            if issue.rule_id:
                issue_counts[issue.rule_id] = issue_counts.get(issue.rule_id, 0) + 1
        
        top_issues = sorted(issue_counts.items(), key=lambda x: x[1], reverse=True)[:3]
        for rule_id, count in top_issues:
            if count > 5:
                recommendations.append(f"Focus on resolving {rule_id} issues (found {count} times)")
        
        return recommendations
    
    async def _get_trend_data(self) -> Dict[str, List[float]]:
        """トレンドデータ取得"""
        trend_data = {
            "overall_score": [],
            "code_quality": [],
            "security_score": [],
            "performance_score": []
        }
        
        # 過去のレポートファイルから履歴データ読み込み
        try:
            for report_file in sorted(self.reports_dir.glob("quality_report_*.json"))[-10:]:
                with open(report_file, 'r', encoding='utf-8') as f:
                    past_report = json.load(f)
                
                trend_data["overall_score"].append(past_report.get("overall_score", 0))
                
                # 他のメトリクスも追加（実装省略）
        except Exception as e:
            logger.warning(f"Could not load trend data: {e}")
        
        return trend_data
    
    async def _save_report(self, report: QualityReport):
        """レポート保存"""
        timestamp = report.generated_at.strftime("%Y%m%d_%H%M%S")
        report_file = self.reports_dir / f"quality_report_{timestamp}.json"
        
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report.to_dict(), f, indent=2, ensure_ascii=False)
        
        # 最新レポートリンク更新
        latest_file = self.reports_dir / "latest_quality_report.json"
        with open(latest_file, 'w', encoding='utf-8') as f:
            json.dump(report.to_dict(), f, indent=2, ensure_ascii=False)
        
        logger.info(f"Quality report saved: {report_file}")
    
    async def schedule_continuous_monitoring(self, interval_hours: int = 24):
        """継続的監視スケジュール"""
        while True:
            try:
                logger.info("Starting scheduled quality analysis...")
                await self.generate_comprehensive_quality_report()
                
                # 次の実行まで待機
                await asyncio.sleep(interval_hours * 3600)
                
            except Exception as e:
                logger.error(f"Scheduled quality analysis failed: {e}")
                # エラー時は短い間隔で再試行
                await asyncio.sleep(3600)  # 1時間後に再試行

# グローバルインスタンス
continuous_quality_manager = ContinuousQualityManager()

# 便利な関数群
async def run_quality_analysis():
    """品質分析実行"""
    return await continuous_quality_manager.generate_comprehensive_quality_report()

async def get_latest_quality_report() -> Optional[Dict[str, Any]]:
    """最新品質レポート取得"""
    try:
        latest_file = continuous_quality_manager.reports_dir / "latest_quality_report.json"
        if latest_file.exists():
            with open(latest_file, 'r', encoding='utf-8') as f:
                return json.load(f)
    except Exception as e:
        logger.error(f"Failed to load latest quality report: {e}")
    return None

async def start_continuous_monitoring(interval_hours: int = 24):
    """継続的監視開始"""
    await continuous_quality_manager.schedule_continuous_monitoring(interval_hours)