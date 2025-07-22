"""
監視・品質メトリクス統合システム
Prometheus・Grafana・Azure Monitor統合による包括的監視
"""

import asyncio
import json
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Callable
from dataclasses import dataclass
from pathlib import Path
import aiofiles

from ..core.config import settings
from ..core.logging_config import get_logger

logger = get_logger(__name__)

@dataclass
class MetricDefinition:
    """メトリクス定義"""
    name: str
    description: str
    metric_type: str  # counter, gauge, histogram, summary
    labels: List[str]
    help_text: str

@dataclass
class QualityThreshold:
    """品質閾値定義"""
    metric_name: str
    warning_threshold: float
    critical_threshold: float
    comparison_operator: str  # "gt", "lt", "eq", "gte", "lte"

class PrometheusMetricsExporter:
    """Prometheus メトリクス エクスポーター"""
    
    def __init__(self):
        self.metrics = {}
        self.custom_metrics = []
        
        # 基本メトリクス定義
        self.metric_definitions = [
            MetricDefinition(
                name="m365_api_requests_total",
                description="Total number of API requests",
                metric_type="counter",
                labels=["method", "endpoint", "status_code"],
                help_text="Total number of API requests processed"
            ),
            MetricDefinition(
                name="m365_api_request_duration_seconds",
                description="API request duration in seconds",
                metric_type="histogram",
                labels=["method", "endpoint"],
                help_text="Duration of API requests in seconds"
            ),
            MetricDefinition(
                name="m365_graph_api_calls_total",
                description="Total Microsoft Graph API calls",
                metric_type="counter",
                labels=["operation", "success"],
                help_text="Total number of Microsoft Graph API calls"
            ),
            MetricDefinition(
                name="m365_cache_hits_total",
                description="Total cache hits",
                metric_type="counter",
                labels=["cache_type"],
                help_text="Total number of cache hits"
            ),
            MetricDefinition(
                name="m365_cache_misses_total",
                description="Total cache misses",
                metric_type="counter",
                labels=["cache_type"],
                help_text="Total number of cache misses"
            ),
            MetricDefinition(
                name="m365_code_quality_score",
                description="Code quality score",
                metric_type="gauge",
                labels=["component"],
                help_text="Current code quality score (0-10)"
            ),
            MetricDefinition(
                name="m365_security_vulnerabilities_total",
                description="Total security vulnerabilities",
                metric_type="gauge",
                labels=["severity"],
                help_text="Total number of security vulnerabilities"
            ),
            MetricDefinition(
                name="m365_error_rate",
                description="Error rate percentage",
                metric_type="gauge",
                labels=["service"],
                help_text="Current error rate percentage"
            ),
            MetricDefinition(
                name="m365_powershell_execution_duration_seconds",
                description="PowerShell script execution duration",
                metric_type="histogram",
                labels=["script_name", "success"],
                help_text="Duration of PowerShell script executions"
            ),
            MetricDefinition(
                name="m365_websocket_connections_active",
                description="Active WebSocket connections",
                metric_type="gauge",
                labels=[],
                help_text="Number of active WebSocket connections"
            )
        ]
    
    def generate_prometheus_config(self) -> str:
        """Prometheus設定ファイル生成"""
        config = {
            "global": {
                "scrape_interval": "15s",
                "evaluation_interval": "15s",
                "external_labels": {
                    "monitor": "microsoft365-tools",
                    "environment": getattr(settings, 'ENVIRONMENT', 'development')
                }
            },
            "rule_files": [
                "m365_tools_alert_rules.yml"
            ],
            "scrape_configs": [
                {
                    "job_name": "microsoft365-tools",
                    "static_configs": [
                        {
                            "targets": ["localhost:8000"]
                        }
                    ],
                    "metrics_path": "/api/metrics",
                    "scrape_interval": "10s",
                    "scrape_timeout": "5s"
                },
                {
                    "job_name": "microsoft365-tools-quality",
                    "static_configs": [
                        {
                            "targets": ["localhost:8000"]
                        }
                    ],
                    "metrics_path": "/api/quality/metrics",
                    "scrape_interval": "60s"
                }
            ],
            "alerting": {
                "alertmanagers": [
                    {
                        "static_configs": [
                            {
                                "targets": ["localhost:9093"]
                            }
                        ]
                    }
                ]
            }
        }
        
        import yaml
        return yaml.dump(config, default_flow_style=False, indent=2)
    
    def generate_alert_rules(self) -> str:
        """アラートルール生成"""
        rules = {
            "groups": [
                {
                    "name": "microsoft365_tools_alerts",
                    "rules": [
                        {
                            "alert": "HighErrorRate",
                            "expr": "m365_error_rate > 5",
                            "for": "5m",
                            "labels": {
                                "severity": "warning"
                            },
                            "annotations": {
                                "summary": "High error rate detected",
                                "description": "Error rate is {{ $value }}% for {{ $labels.service }}"
                            }
                        },
                        {
                            "alert": "LowCodeQuality",
                            "expr": "m365_code_quality_score < 7",
                            "for": "1h",
                            "labels": {
                                "severity": "warning"
                            },
                            "annotations": {
                                "summary": "Code quality score is low",
                                "description": "Code quality score is {{ $value }} for {{ $labels.component }}"
                            }
                        },
                        {
                            "alert": "HighSecurityVulnerabilities",
                            "expr": "m365_security_vulnerabilities_total{severity=\"HIGH\"} > 0",
                            "for": "0m",
                            "labels": {
                                "severity": "critical"
                            },
                            "annotations": {
                                "summary": "High severity security vulnerabilities found",
                                "description": "{{ $value }} high severity vulnerabilities detected"
                            }
                        },
                        {
                            "alert": "SlowAPIResponse",
                            "expr": "histogram_quantile(0.95, m365_api_request_duration_seconds_bucket) > 5",
                            "for": "10m",
                            "labels": {
                                "severity": "warning"
                            },
                            "annotations": {
                                "summary": "API response time is slow",
                                "description": "95th percentile response time is {{ $value }}s"
                            }
                        },
                        {
                            "alert": "GraphAPIFailures",
                            "expr": "rate(m365_graph_api_calls_total{success=\"false\"}[5m]) > 0.1",
                            "for": "5m",
                            "labels": {
                                "severity": "warning"
                            },
                            "annotations": {
                                "summary": "Microsoft Graph API failures detected",
                                "description": "Graph API failure rate is {{ $value }} per second"
                            }
                        }
                    ]
                }
            ]
        }
        
        import yaml
        return yaml.dump(rules, default_flow_style=False, indent=2)
    
    async def export_metrics_endpoint(self) -> str:
        """Prometheusメトリクスエンドポイント用データ生成"""
        metrics_output = []
        
        # メトリクス定義をPrometheus形式で出力
        for metric_def in self.metric_definitions:
            # HELP行
            metrics_output.append(f"# HELP {metric_def.name} {metric_def.help_text}")
            # TYPE行
            metrics_output.append(f"# TYPE {metric_def.name} {metric_def.metric_type}")
        
        # 実際のメトリクス値取得・出力
        current_metrics = await self._collect_current_metrics()
        
        for metric_name, metric_data in current_metrics.items():
            if isinstance(metric_data, dict) and "labels" in metric_data:
                # ラベル付きメトリクス
                label_str = ",".join([f'{k}="{v}"' for k, v in metric_data["labels"].items()])
                metrics_output.append(f"{metric_name}{{{label_str}}} {metric_data['value']}")
            else:
                # 単純メトリクス
                metrics_output.append(f"{metric_name} {metric_data}")
        
        return "\n".join(metrics_output)
    
    async def _collect_current_metrics(self) -> Dict[str, Any]:
        """現在のメトリクス値収集"""
        metrics = {}
        
        try:
            # パフォーマンスメトリクス
            from ..api.optimization.performance_optimizer import get_performance_stats
            perf_stats = await get_performance_stats()
            
            if "metrics" in perf_stats:
                perf_metrics = perf_stats["metrics"]
                metrics["m365_api_request_duration_seconds"] = {
                    "labels": {"method": "GET", "endpoint": "average"},
                    "value": perf_metrics.get("avg_response_time_ms", 0) / 1000
                }
                metrics["m365_error_rate"] = {
                    "labels": {"service": "api"},
                    "value": perf_metrics.get("error_rate_percent", 0)
                }
                metrics["m365_cache_hits_total"] = {
                    "labels": {"cache_type": "general"},
                    "value": perf_metrics.get("cache_hits", 0)
                }
                metrics["m365_cache_misses_total"] = {
                    "labels": {"cache_type": "general"},
                    "value": perf_metrics.get("cache_misses", 0)
                }
            
            # 品質メトリクス
            from ..quality.continuous_improvement import get_latest_quality_report
            quality_report = await get_latest_quality_report()
            
            if quality_report:
                metrics["m365_code_quality_score"] = {
                    "labels": {"component": "overall"},
                    "value": quality_report.get("overall_score", 0)
                }
                
                # セキュリティ脆弱性
                security_metrics = quality_report.get("metrics", {}).get("security", {})
                if "vulnerabilities" in security_metrics:
                    vuln_data = security_metrics["vulnerabilities"]
                    if "severity_breakdown" in vuln_data:
                        for severity, count in vuln_data["severity_breakdown"].items():
                            metrics["m365_security_vulnerabilities_total"] = {
                                "labels": {"severity": severity},
                                "value": count
                            }
            
            # WebSocket接続数
            try:
                from ..api.integration.frontend_support import frontend_integration_manager
                ws_status = await frontend_integration_manager.get_monitoring_status()
                metrics["m365_websocket_connections_active"] = ws_status.get("connections", {}).get("websocket_count", 0)
            except:
                metrics["m365_websocket_connections_active"] = 0
            
            # システムメトリクス
            if "system" in perf_stats:
                system_metrics = perf_stats["system"]
                metrics["m365_system_cpu_usage"] = system_metrics.get("cpu", {}).get("usage_percent", 0)
                metrics["m365_system_memory_usage"] = system_metrics.get("memory", {}).get("usage_percent", 0)
            
        except Exception as e:
            logger.error(f"Failed to collect metrics: {e}")
        
        return metrics

class GrafanaDashboardGenerator:
    """Grafana ダッシュボード生成器"""
    
    def __init__(self):
        self.dashboard_templates_dir = Path(__file__).parent / "grafana_templates"
        self.dashboard_templates_dir.mkdir(exist_ok=True)
    
    def generate_main_dashboard(self) -> Dict[str, Any]:
        """メインダッシュボード生成"""
        dashboard = {
            "dashboard": {
                "id": None,
                "title": "Microsoft 365 Management Tools - Overview",
                "tags": ["microsoft365", "overview"],
                "timezone": "browser",
                "panels": [
                    self._create_api_performance_panel(),
                    self._create_error_rate_panel(),
                    self._create_code_quality_panel(),
                    self._create_security_panel(),
                    self._create_system_resources_panel(),
                    self._create_websocket_connections_panel()
                ],
                "time": {
                    "from": "now-1h",
                    "to": "now"
                },
                "refresh": "10s"
            }
        }
        
        return dashboard
    
    def _create_api_performance_panel(self) -> Dict[str, Any]:
        """API パフォーマンスパネル"""
        return {
            "id": 1,
            "title": "API Performance",
            "type": "graph",
            "targets": [
                {
                    "expr": "histogram_quantile(0.95, m365_api_request_duration_seconds_bucket)",
                    "legendFormat": "95th percentile",
                    "refId": "A"
                },
                {
                    "expr": "histogram_quantile(0.50, m365_api_request_duration_seconds_bucket)",
                    "legendFormat": "50th percentile",
                    "refId": "B"
                }
            ],
            "yAxes": [
                {
                    "label": "Response Time (seconds)",
                    "min": 0
                }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
        }
    
    def _create_error_rate_panel(self) -> Dict[str, Any]:
        """エラー率パネル"""
        return {
            "id": 2,
            "title": "Error Rate",
            "type": "singlestat",
            "targets": [
                {
                    "expr": "m365_error_rate",
                    "legendFormat": "Error Rate %",
                    "refId": "A"
                }
            ],
            "thresholds": "3,5",
            "colorBackground": True,
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
        }
    
    def _create_code_quality_panel(self) -> Dict[str, Any]:
        """コード品質パネル"""
        return {
            "id": 3,
            "title": "Code Quality Score",
            "type": "gauge",
            "targets": [
                {
                    "expr": "m365_code_quality_score",
                    "legendFormat": "Quality Score",
                    "refId": "A"
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "min": 0,
                    "max": 10,
                    "thresholds": {
                        "steps": [
                            {"color": "red", "value": 0},
                            {"color": "yellow", "value": 6},
                            {"color": "green", "value": 8}
                        ]
                    }
                }
            },
            "gridPos": {"h": 8, "w": 6, "x": 0, "y": 8}
        }
    
    def _create_security_panel(self) -> Dict[str, Any]:
        """セキュリティパネル"""
        return {
            "id": 4,
            "title": "Security Vulnerabilities",
            "type": "table",
            "targets": [
                {
                    "expr": "m365_security_vulnerabilities_total",
                    "legendFormat": "{{severity}}",
                    "refId": "A"
                }
            ],
            "gridPos": {"h": 8, "w": 6, "x": 6, "y": 8}
        }
    
    def _create_system_resources_panel(self) -> Dict[str, Any]:
        """システムリソースパネル"""
        return {
            "id": 5,
            "title": "System Resources",
            "type": "graph",
            "targets": [
                {
                    "expr": "m365_system_cpu_usage",
                    "legendFormat": "CPU Usage %",
                    "refId": "A"
                },
                {
                    "expr": "m365_system_memory_usage",
                    "legendFormat": "Memory Usage %",
                    "refId": "B"
                }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
        }
    
    def _create_websocket_connections_panel(self) -> Dict[str, Any]:
        """WebSocket接続パネル"""
        return {
            "id": 6,
            "title": "Active WebSocket Connections",
            "type": "stat",
            "targets": [
                {
                    "expr": "m365_websocket_connections_active",
                    "legendFormat": "Connections",
                    "refId": "A"
                }
            ],
            "gridPos": {"h": 4, "w": 6, "x": 0, "y": 16}
        }
    
    async def save_dashboard(self, dashboard: Dict[str, Any], filename: str):
        """ダッシュボードファイル保存"""
        dashboard_file = self.dashboard_templates_dir / f"{filename}.json"
        
        async with aiofiles.open(dashboard_file, 'w', encoding='utf-8') as f:
            await f.write(json.dumps(dashboard, indent=2, ensure_ascii=False))
        
        logger.info(f"Grafana dashboard saved: {dashboard_file}")

class QualityMetricsCollector:
    """品質メトリクス収集器"""
    
    def __init__(self):
        self.metrics_history = []
        self.collection_interval = 300  # 5分間隔
        self.max_history_size = 1000
        
        # 品質閾値設定
        self.quality_thresholds = [
            QualityThreshold("code_quality_score", 7.0, 5.0, "lt"),
            QualityThreshold("error_rate", 3.0, 5.0, "gt"),
            QualityThreshold("api_response_time_p95", 2.0, 5.0, "gt"),
            QualityThreshold("security_vulnerabilities_high", 0, 1, "gte"),
            QualityThreshold("cache_hit_rate", 80.0, 60.0, "lt")
        ]
    
    async def start_collection(self):
        """メトリクス収集開始"""
        logger.info("Starting quality metrics collection...")
        
        while True:
            try:
                await self._collect_metrics()
                await asyncio.sleep(self.collection_interval)
            except Exception as e:
                logger.error(f"Error in metrics collection: {e}")
                await asyncio.sleep(60)  # エラー時は1分後に再試行
    
    async def _collect_metrics(self):
        """メトリクス収集実行"""
        timestamp = datetime.utcnow()
        
        try:
            # パフォーマンスメトリクス
            from ..api.optimization.performance_optimizer import get_performance_stats
            perf_stats = await get_performance_stats()
            
            # 品質メトリクス
            from ..quality.continuous_improvement import get_latest_quality_report
            quality_report = await get_latest_quality_report()
            
            # エラー統計
            from ..core.error_handling import get_error_statistics
            error_stats = get_error_statistics()
            
            # 統合メトリクス
            metrics = {
                "timestamp": timestamp.isoformat(),
                "performance": perf_stats,
                "quality": quality_report,
                "errors": error_stats
            }
            
            # 履歴に追加
            self.metrics_history.append(metrics)
            
            # 履歴サイズ制限
            if len(self.metrics_history) > self.max_history_size:
                self.metrics_history = self.metrics_history[-self.max_history_size:]
            
            # 閾値チェック
            await self._check_thresholds(metrics)
            
            logger.debug(f"Metrics collected at {timestamp}")
            
        except Exception as e:
            logger.error(f"Failed to collect metrics: {e}")
    
    async def _check_thresholds(self, metrics: Dict[str, Any]):
        """品質閾値チェック"""
        violations = []
        
        for threshold in self.quality_thresholds:
            try:
                current_value = self._extract_metric_value(metrics, threshold.metric_name)
                
                if current_value is not None:
                    if self._threshold_violated(current_value, threshold):
                        violations.append({
                            "metric": threshold.metric_name,
                            "current_value": current_value,
                            "threshold": threshold.critical_threshold,
                            "severity": "critical" if self._critical_threshold_violated(current_value, threshold) else "warning"
                        })
            except Exception as e:
                logger.warning(f"Failed to check threshold for {threshold.metric_name}: {e}")
        
        if violations:
            await self._handle_threshold_violations(violations)
    
    def _extract_metric_value(self, metrics: Dict[str, Any], metric_name: str) -> Optional[float]:
        """メトリクス値抽出"""
        if metric_name == "code_quality_score":
            return metrics.get("quality", {}).get("overall_score")
        elif metric_name == "error_rate":
            return metrics.get("performance", {}).get("metrics", {}).get("error_rate_percent")
        elif metric_name == "api_response_time_p95":
            return metrics.get("performance", {}).get("metrics", {}).get("p95_response_time_ms", 0) / 1000
        elif metric_name == "security_vulnerabilities_high":
            security_data = metrics.get("quality", {}).get("metrics", {}).get("security", {})
            vuln_data = security_data.get("vulnerabilities", {}).get("severity_breakdown", {})
            return vuln_data.get("HIGH", 0)
        elif metric_name == "cache_hit_rate":
            perf_metrics = metrics.get("performance", {}).get("metrics", {})
            total_hits = perf_metrics.get("cache_hits", 0)
            total_misses = perf_metrics.get("cache_misses", 0)
            total_requests = total_hits + total_misses
            return (total_hits / total_requests * 100) if total_requests > 0 else 100
        
        return None
    
    def _threshold_violated(self, value: float, threshold: QualityThreshold) -> bool:
        """閾値違反チェック"""
        if threshold.comparison_operator == "gt":
            return value > threshold.warning_threshold
        elif threshold.comparison_operator == "lt":
            return value < threshold.warning_threshold
        elif threshold.comparison_operator == "gte":
            return value >= threshold.warning_threshold
        elif threshold.comparison_operator == "lte":
            return value <= threshold.warning_threshold
        elif threshold.comparison_operator == "eq":
            return value == threshold.warning_threshold
        
        return False
    
    def _critical_threshold_violated(self, value: float, threshold: QualityThreshold) -> bool:
        """重要閾値違反チェック"""
        if threshold.comparison_operator == "gt":
            return value > threshold.critical_threshold
        elif threshold.comparison_operator == "lt":
            return value < threshold.critical_threshold
        elif threshold.comparison_operator == "gte":
            return value >= threshold.critical_threshold
        elif threshold.comparison_operator == "lte":
            return value <= threshold.critical_threshold
        elif threshold.comparison_operator == "eq":
            return value == threshold.critical_threshold
        
        return False
    
    async def _handle_threshold_violations(self, violations: List[Dict[str, Any]]):
        """閾値違反処理"""
        logger.warning(f"Quality threshold violations detected: {len(violations)} issues")
        
        for violation in violations:
            logger.warning(
                f"Threshold violation - {violation['metric']}: "
                f"current={violation['current_value']}, "
                f"threshold={violation['threshold']}, "
                f"severity={violation['severity']}"
            )
        
        # アラート送信（実装省略）
        # await self._send_alerts(violations)
    
    def get_metrics_history(self, hours: int = 24) -> List[Dict[str, Any]]:
        """メトリクス履歴取得"""
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        return [
            m for m in self.metrics_history 
            if datetime.fromisoformat(m["timestamp"]) > cutoff_time
        ]

class MonitoringIntegrationManager:
    """監視統合マネージャー"""
    
    def __init__(self):
        self.prometheus_exporter = PrometheusMetricsExporter()
        self.grafana_generator = GrafanaDashboardGenerator()
        self.metrics_collector = QualityMetricsCollector()
        self.monitoring_dir = Path(settings.base_dir) / "monitoring"
        self.monitoring_dir.mkdir(exist_ok=True)
    
    async def initialize_monitoring(self):
        """監視システム初期化"""
        try:
            # Prometheus設定生成
            prometheus_config = self.prometheus_exporter.generate_prometheus_config()
            prometheus_config_file = self.monitoring_dir / "prometheus.yml"
            
            async with aiofiles.open(prometheus_config_file, 'w', encoding='utf-8') as f:
                await f.write(prometheus_config)
            
            # アラートルール生成
            alert_rules = self.prometheus_exporter.generate_alert_rules()
            alert_rules_file = self.monitoring_dir / "m365_tools_alert_rules.yml"
            
            async with aiofiles.open(alert_rules_file, 'w', encoding='utf-8') as f:
                await f.write(alert_rules)
            
            # Grafanaダッシュボード生成
            main_dashboard = self.grafana_generator.generate_main_dashboard()
            await self.grafana_generator.save_dashboard(main_dashboard, "microsoft365_overview")
            
            # メトリクス収集開始
            asyncio.create_task(self.metrics_collector.start_collection())
            
            logger.info("Monitoring integration initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize monitoring: {e}")
            raise
    
    async def get_prometheus_metrics(self) -> str:
        """Prometheusメトリクス取得"""
        return await self.prometheus_exporter.export_metrics_endpoint()
    
    async def get_quality_metrics_summary(self) -> Dict[str, Any]:
        """品質メトリクスサマリー取得"""
        recent_metrics = self.metrics_collector.get_metrics_history(hours=1)
        
        if not recent_metrics:
            return {"status": "no_data", "message": "No recent metrics available"}
        
        latest_metrics = recent_metrics[-1]
        
        return {
            "status": "success",
            "timestamp": latest_metrics["timestamp"],
            "summary": {
                "code_quality_score": latest_metrics.get("quality", {}).get("overall_score", 0),
                "error_rate": latest_metrics.get("performance", {}).get("metrics", {}).get("error_rate_percent", 0),
                "api_response_time": latest_metrics.get("performance", {}).get("metrics", {}).get("avg_response_time_ms", 0),
                "security_issues": len(latest_metrics.get("quality", {}).get("issues", [])),
                "total_metrics_collected": len(recent_metrics)
            }
        }
    
    def get_monitoring_status(self) -> Dict[str, Any]:
        """監視システム状態取得"""
        return {
            "prometheus_config_generated": (self.monitoring_dir / "prometheus.yml").exists(),
            "alert_rules_generated": (self.monitoring_dir / "m365_tools_alert_rules.yml").exists(),
            "grafana_dashboard_generated": (self.grafana_generator.dashboard_templates_dir / "microsoft365_overview.json").exists(),
            "metrics_collector_running": len(self.metrics_collector.metrics_history) > 0,
            "total_metrics_collected": len(self.metrics_collector.metrics_history)
        }

# グローバルインスタンス
monitoring_integration_manager = MonitoringIntegrationManager()

# 便利な関数群
async def initialize_monitoring_integration():
    """監視統合初期化"""
    await monitoring_integration_manager.initialize_monitoring()

async def get_prometheus_metrics():
    """Prometheusメトリクス取得"""
    return await monitoring_integration_manager.get_prometheus_metrics()

async def get_quality_summary():
    """品質サマリー取得"""
    return await monitoring_integration_manager.get_quality_metrics_summary()

def get_monitoring_status():
    """監視状態取得"""
    return monitoring_integration_manager.get_monitoring_status()