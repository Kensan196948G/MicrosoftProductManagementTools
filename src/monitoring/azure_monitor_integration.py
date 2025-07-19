#!/usr/bin/env python3
"""
Azure Monitor & Application Insights Integration - Phase 2 Enterprise Production
24/7監視・自動復旧機能・可用性監視・パフォーマンス最適化
"""

import os
import logging
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, field
from enum import Enum
import asyncio
from pathlib import Path

# Azure Monitor & Application Insights
from azure.monitor.opentelemetry import configure_azure_monitor
from azure.monitor.opentelemetry.exporter import AzureMonitorLogExporter, AzureMonitorMetricExporter, AzureMonitorTraceExporter
from azure.monitor.opentelemetry.exporter.export._base import ExportResult
from azure.identity import DefaultAzureCredential
from azure.monitor.query import LogsQueryClient, MetricsQueryClient
from azure.monitor.query.models import MetricAggregationType, LogsQueryResult

# OpenTelemetry
from opentelemetry import trace, metrics, logs
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.logs import LoggerProvider
from opentelemetry.sdk.logs.export import BatchLogRecordProcessor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.urllib3 import URLLib3Instrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor

# Health monitoring
import psutil
import requests
from concurrent.futures import ThreadPoolExecutor
import threading

from src.auth.azure_key_vault_auth import AzureKeyVaultAuth

logger = logging.getLogger(__name__)


class MonitoringLevel(Enum):
    """監視レベル"""
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INFO = "info"


class HealthStatus(Enum):
    """ヘルスステータス"""
    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"
    UNKNOWN = "unknown"


@dataclass
class MonitoringConfig:
    """監視設定"""
    connection_string: str
    workspace_id: str
    enable_trace: bool = True
    enable_metrics: bool = True
    enable_logs: bool = True
    enable_health_checks: bool = True
    health_check_interval: int = 30
    metrics_export_interval: int = 60
    trace_sample_rate: float = 1.0
    max_retry_attempts: int = 3
    retry_delay: float = 1.0
    alert_thresholds: Dict[str, float] = field(default_factory=dict)


@dataclass
class HealthCheckResult:
    """ヘルスチェック結果"""
    name: str
    status: HealthStatus
    message: str
    timestamp: datetime
    response_time: float
    details: Dict[str, Any] = field(default_factory=dict)


@dataclass
class MetricData:
    """メトリクスデータ"""
    name: str
    value: float
    unit: str
    timestamp: datetime
    dimensions: Dict[str, str] = field(default_factory=dict)
    tags: Dict[str, str] = field(default_factory=dict)


class AzureMonitorIntegration:
    """
    Azure Monitor & Application Insights統合クライアント
    24/7監視・自動復旧機能・可用性監視・パフォーマンス最適化
    """
    
    def __init__(self, 
                 config: MonitoringConfig,
                 credential: Any = None,
                 use_key_vault: bool = True,
                 key_vault_url: str = None):
        """
        Initialize Azure Monitor Integration
        
        Args:
            config: 監視設定
            credential: Azure credential
            use_key_vault: Azure Key Vault使用フラグ
            key_vault_url: Azure Key Vault URL
        """
        self.config = config
        self.credential = credential or DefaultAzureCredential()
        self.use_key_vault = use_key_vault
        self.key_vault_url = key_vault_url
        
        # Azure Key Vault統合
        if self.use_key_vault:
            self.key_vault_auth = AzureKeyVaultAuth(vault_url=key_vault_url)
            self._load_monitoring_config_from_key_vault()
        else:
            self.key_vault_auth = None
        
        # OpenTelemetry初期化
        self._setup_opentelemetry()
        
        # Azure Monitor clients
        self.logs_client = LogsQueryClient(credential=self.credential)
        self.metrics_client = MetricsQueryClient(credential=self.credential)
        
        # Health monitoring
        self.health_checks: Dict[str, callable] = {}
        self.health_check_results: List[HealthCheckResult] = []
        self.health_check_thread: Optional[threading.Thread] = None
        self.health_check_running = False
        
        # Performance monitoring
        self.performance_metrics: Dict[str, List[MetricData]] = {}
        self.custom_metrics: Dict[str, Any] = {}
        
        # Auto-recovery
        self.recovery_actions: Dict[str, callable] = {}
        self.recovery_history: List[Dict[str, Any]] = []
        
        # Alerting
        self.alert_rules: Dict[str, Dict[str, Any]] = {}
        self.active_alerts: List[Dict[str, Any]] = []
        
        logger.info("Azure Monitor Integration initialized successfully")
    
    def _load_monitoring_config_from_key_vault(self):
        """Key Vaultから監視設定を読み込み"""
        try:
            # Application Insights接続文字列
            connection_string = self.key_vault_auth.get_secret("APP-INSIGHTS-CONNECTION-STRING")
            if connection_string:
                self.config.connection_string = connection_string
            
            # Log Analytics ワークスペースID
            workspace_id = self.key_vault_auth.get_secret("LOG-ANALYTICS-WORKSPACE-ID")
            if workspace_id:
                self.config.workspace_id = workspace_id
            
            logger.info("Monitoring configuration loaded from Key Vault")
            
        except Exception as e:
            logger.warning(f"Failed to load monitoring config from Key Vault: {str(e)}")
    
    def _setup_opentelemetry(self):
        """OpenTelemetryの設定"""
        try:
            # Configure Azure Monitor
            configure_azure_monitor(
                connection_string=self.config.connection_string,
                disable_offline_storage=False,
                sampling_ratio=self.config.trace_sample_rate
            )
            
            # Trace provider
            if self.config.enable_trace:
                trace_exporter = AzureMonitorTraceExporter(
                    connection_string=self.config.connection_string
                )
                span_processor = BatchSpanProcessor(trace_exporter)
                trace_provider = TracerProvider()
                trace_provider.add_span_processor(span_processor)
                trace.set_tracer_provider(trace_provider)
                
                # Instrument libraries
                RequestsInstrumentor().instrument()
                URLLib3Instrumentor().instrument()
                LoggingInstrumentor().instrument()
            
            # Metrics provider
            if self.config.enable_metrics:
                metric_exporter = AzureMonitorMetricExporter(
                    connection_string=self.config.connection_string
                )
                metric_reader = PeriodicExportingMetricReader(
                    exporter=metric_exporter,
                    export_interval_millis=self.config.metrics_export_interval * 1000
                )
                metrics_provider = MeterProvider(metric_readers=[metric_reader])
                metrics.set_meter_provider(metrics_provider)
            
            # Logs provider
            if self.config.enable_logs:
                log_exporter = AzureMonitorLogExporter(
                    connection_string=self.config.connection_string
                )
                log_processor = BatchLogRecordProcessor(log_exporter)
                log_provider = LoggerProvider()
                log_provider.add_log_record_processor(log_processor)
                logs.set_logger_provider(log_provider)
            
            # Get instrumentors
            self.tracer = trace.get_tracer(__name__)
            self.meter = metrics.get_meter(__name__)
            self.logger = logs.get_logger(__name__)
            
            # Custom metrics
            self.response_time_histogram = self.meter.create_histogram(
                name="http_request_duration_seconds",
                description="HTTP request duration in seconds",
                unit="s"
            )
            
            self.request_counter = self.meter.create_counter(
                name="http_requests_total",
                description="Total HTTP requests",
                unit="1"
            )
            
            self.active_connections_gauge = self.meter.create_up_down_counter(
                name="active_connections",
                description="Number of active connections",
                unit="1"
            )
            
            self.memory_usage_gauge = self.meter.create_up_down_counter(
                name="memory_usage_bytes",
                description="Memory usage in bytes",
                unit="bytes"
            )
            
            self.cpu_usage_gauge = self.meter.create_up_down_counter(
                name="cpu_usage_percent",
                description="CPU usage percentage",
                unit="percent"
            )
            
            logger.info("OpenTelemetry configured successfully")
            
        except Exception as e:
            logger.error(f"Failed to setup OpenTelemetry: {str(e)}")
            raise
    
    def add_health_check(self, name: str, check_function: callable):
        """ヘルスチェック追加"""
        self.health_checks[name] = check_function
        logger.info(f"Added health check: {name}")
    
    def remove_health_check(self, name: str):
        """ヘルスチェック削除"""
        if name in self.health_checks:
            del self.health_checks[name]
            logger.info(f"Removed health check: {name}")
    
    def _perform_health_check(self, name: str, check_function: callable) -> HealthCheckResult:
        """個別ヘルスチェック実行"""
        start_time = time.time()
        
        try:
            result = check_function()
            response_time = time.time() - start_time
            
            if isinstance(result, dict):
                status = HealthStatus(result.get('status', HealthStatus.UNKNOWN.value))
                message = result.get('message', 'No message')
                details = result.get('details', {})
            else:
                status = HealthStatus.HEALTHY if result else HealthStatus.CRITICAL
                message = "Check passed" if result else "Check failed"
                details = {}
            
            return HealthCheckResult(
                name=name,
                status=status,
                message=message,
                timestamp=datetime.utcnow(),
                response_time=response_time,
                details=details
            )
            
        except Exception as e:
            response_time = time.time() - start_time
            return HealthCheckResult(
                name=name,
                status=HealthStatus.CRITICAL,
                message=f"Health check failed: {str(e)}",
                timestamp=datetime.utcnow(),
                response_time=response_time,
                details={'error': str(e)}
            )
    
    def _health_check_loop(self):
        """ヘルスチェック実行ループ"""
        while self.health_check_running:
            try:
                current_results = []
                
                # 並列でヘルスチェック実行
                with ThreadPoolExecutor(max_workers=10) as executor:
                    futures = {
                        executor.submit(self._perform_health_check, name, check_func): name
                        for name, check_func in self.health_checks.items()
                    }
                    
                    for future in futures:
                        try:
                            result = future.result(timeout=30)
                            current_results.append(result)
                        except Exception as e:
                            name = futures[future]
                            logger.error(f"Health check '{name}' failed: {str(e)}")
                            current_results.append(HealthCheckResult(
                                name=name,
                                status=HealthStatus.CRITICAL,
                                message=f"Health check timeout: {str(e)}",
                                timestamp=datetime.utcnow(),
                                response_time=30.0
                            ))
                
                # 結果を保存
                self.health_check_results = current_results
                
                # メトリクス送信
                self._send_health_metrics(current_results)
                
                # アラート確認
                self._check_alerts(current_results)
                
                # 自動復旧チェック
                self._check_auto_recovery(current_results)
                
            except Exception as e:
                logger.error(f"Health check loop error: {str(e)}")
            
            # 次回実行まで待機
            time.sleep(self.config.health_check_interval)
    
    def start_health_monitoring(self):
        """ヘルスモニタリング開始"""
        if self.health_check_running:
            return
        
        self.health_check_running = True
        self.health_check_thread = threading.Thread(
            target=self._health_check_loop,
            daemon=True
        )
        self.health_check_thread.start()
        
        logger.info("Health monitoring started")
    
    def stop_health_monitoring(self):
        """ヘルスモニタリング停止"""
        self.health_check_running = False
        
        if self.health_check_thread:
            self.health_check_thread.join(timeout=5)
            self.health_check_thread = None
        
        logger.info("Health monitoring stopped")
    
    def _send_health_metrics(self, results: List[HealthCheckResult]):
        """ヘルスメトリクス送信"""
        try:
            with self.tracer.start_as_current_span("health_metrics_export"):
                for result in results:
                    # ヘルスステータス
                    status_value = 1 if result.status == HealthStatus.HEALTHY else 0
                    
                    # カスタムメトリクス記録
                    self.meter.create_up_down_counter(
                        name=f"health_check_{result.name}",
                        description=f"Health check status for {result.name}",
                        unit="1"
                    ).add(status_value, {
                        "check_name": result.name,
                        "status": result.status.value,
                        "message": result.message
                    })
                    
                    # レスポンス時間
                    self.response_time_histogram.record(
                        result.response_time,
                        {"check_name": result.name, "type": "health_check"}
                    )
                    
                    # Azure Monitor Custom Events
                    self._send_custom_event("HealthCheck", {
                        "name": result.name,
                        "status": result.status.value,
                        "message": result.message,
                        "response_time": result.response_time,
                        "timestamp": result.timestamp.isoformat(),
                        "details": json.dumps(result.details)
                    })
                    
        except Exception as e:
            logger.error(f"Failed to send health metrics: {str(e)}")
    
    def _send_custom_event(self, event_name: str, properties: Dict[str, Any]):
        """カスタムイベント送信"""
        try:
            with self.tracer.start_as_current_span(f"custom_event_{event_name}") as span:
                span.set_attributes(properties)
                
                # Application Insights Custom Event
                self.logger.info(f"CustomEvent: {event_name}", extra={
                    "custom_dimensions": properties
                })
                
        except Exception as e:
            logger.error(f"Failed to send custom event: {str(e)}")
    
    def record_metric(self, name: str, value: float, unit: str = "1", 
                     dimensions: Dict[str, str] = None, tags: Dict[str, str] = None):
        """カスタムメトリクス記録"""
        try:
            metric_data = MetricData(
                name=name,
                value=value,
                unit=unit,
                timestamp=datetime.utcnow(),
                dimensions=dimensions or {},
                tags=tags or {}
            )
            
            if name not in self.performance_metrics:
                self.performance_metrics[name] = []
            
            self.performance_metrics[name].append(metric_data)
            
            # OpenTelemetry経由でメトリクス送信
            counter = self.meter.create_counter(
                name=name,
                description=f"Custom metric: {name}",
                unit=unit
            )
            counter.add(value, dimensions or {})
            
            logger.debug(f"Recorded metric: {name} = {value} {unit}")
            
        except Exception as e:
            logger.error(f"Failed to record metric '{name}': {str(e)}")
    
    def record_performance_metrics(self):
        """システムパフォーマンスメトリクス記録"""
        try:
            with self.tracer.start_as_current_span("performance_metrics"):
                # CPU使用率
                cpu_percent = psutil.cpu_percent(interval=1)
                self.cpu_usage_gauge.add(cpu_percent, {"host": os.getenv("HOSTNAME", "unknown")})
                
                # メモリ使用量
                memory = psutil.virtual_memory()
                self.memory_usage_gauge.add(memory.used, {"host": os.getenv("HOSTNAME", "unknown")})
                
                # ディスク使用量
                disk = psutil.disk_usage('/')
                self.record_metric("disk_usage_bytes", disk.used, "bytes", {"host": os.getenv("HOSTNAME", "unknown")})
                
                # ネットワーク統計
                network = psutil.net_io_counters()
                self.record_metric("network_bytes_sent", network.bytes_sent, "bytes", {"host": os.getenv("HOSTNAME", "unknown")})
                self.record_metric("network_bytes_recv", network.bytes_recv, "bytes", {"host": os.getenv("HOSTNAME", "unknown")})
                
                # プロセス統計
                process = psutil.Process()
                self.record_metric("process_memory_bytes", process.memory_info().rss, "bytes", {"pid": str(process.pid)})
                self.record_metric("process_cpu_percent", process.cpu_percent(), "percent", {"pid": str(process.pid)})
                
                # カスタムメトリクス
                self.record_metric("application_uptime_seconds", time.time() - self.start_time, "seconds")
                
        except Exception as e:
            logger.error(f"Failed to record performance metrics: {str(e)}")
    
    def add_alert_rule(self, name: str, condition: callable, threshold: float, 
                      recovery_action: callable = None, severity: MonitoringLevel = MonitoringLevel.MEDIUM):
        """アラートルール追加"""
        self.alert_rules[name] = {
            'condition': condition,
            'threshold': threshold,
            'recovery_action': recovery_action,
            'severity': severity,
            'triggered_at': None,
            'last_triggered': None
        }
        logger.info(f"Added alert rule: {name}")
    
    def _check_alerts(self, health_results: List[HealthCheckResult]):
        """アラート確認"""
        try:
            for rule_name, rule in self.alert_rules.items():
                try:
                    # アラート条件チェック
                    triggered = rule['condition'](health_results, self.performance_metrics)
                    
                    if triggered and rule['triggered_at'] is None:
                        # 新しいアラート
                        rule['triggered_at'] = datetime.utcnow()
                        rule['last_triggered'] = datetime.utcnow()
                        
                        alert = {
                            'name': rule_name,
                            'severity': rule['severity'].value,
                            'triggered_at': rule['triggered_at'],
                            'message': f"Alert triggered: {rule_name}",
                            'threshold': rule['threshold']
                        }
                        self.active_alerts.append(alert)
                        
                        # カスタムイベント送信
                        self._send_custom_event("AlertTriggered", alert)
                        
                        logger.warning(f"Alert triggered: {rule_name}")
                        
                    elif not triggered and rule['triggered_at'] is not None:
                        # アラート解除
                        rule['triggered_at'] = None
                        
                        # アクティブアラートから削除
                        self.active_alerts = [
                            alert for alert in self.active_alerts 
                            if alert['name'] != rule_name
                        ]
                        
                        # カスタムイベント送信
                        self._send_custom_event("AlertResolved", {
                            'name': rule_name,
                            'resolved_at': datetime.utcnow().isoformat()
                        })
                        
                        logger.info(f"Alert resolved: {rule_name}")
                        
                except Exception as e:
                    logger.error(f"Error checking alert rule '{rule_name}': {str(e)}")
                    
        except Exception as e:
            logger.error(f"Failed to check alerts: {str(e)}")
    
    def _check_auto_recovery(self, health_results: List[HealthCheckResult]):
        """自動復旧チェック"""
        try:
            for result in health_results:
                if result.status == HealthStatus.CRITICAL:
                    # 復旧アクション実行
                    if result.name in self.recovery_actions:
                        try:
                            recovery_action = self.recovery_actions[result.name]
                            recovery_result = recovery_action(result)
                            
                            recovery_record = {
                                'service': result.name,
                                'triggered_at': datetime.utcnow().isoformat(),
                                'action': recovery_action.__name__,
                                'result': recovery_result,
                                'original_error': result.message
                            }
                            self.recovery_history.append(recovery_record)
                            
                            # カスタムイベント送信
                            self._send_custom_event("AutoRecoveryTriggered", recovery_record)
                            
                            logger.info(f"Auto recovery triggered for {result.name}: {recovery_result}")
                            
                        except Exception as e:
                            logger.error(f"Auto recovery failed for {result.name}: {str(e)}")
                            
        except Exception as e:
            logger.error(f"Failed to check auto recovery: {str(e)}")
    
    def add_recovery_action(self, service_name: str, action: callable):
        """復旧アクション追加"""
        self.recovery_actions[service_name] = action
        logger.info(f"Added recovery action for: {service_name}")
    
    async def query_logs(self, query: str, timespan: timedelta = None) -> Optional[LogsQueryResult]:
        """ログクエリ実行"""
        try:
            timespan = timespan or timedelta(hours=1)
            
            with self.tracer.start_as_current_span("logs_query"):
                result = await self.logs_client.query_workspace(
                    workspace_id=self.config.workspace_id,
                    query=query,
                    timespan=timespan
                )
                
                logger.info(f"Logs query executed successfully. Rows: {len(result.tables[0].rows) if result.tables else 0}")
                return result
                
        except Exception as e:
            logger.error(f"Failed to query logs: {str(e)}")
            return None
    
    def get_health_status(self) -> Dict[str, Any]:
        """全体ヘルスステータス取得"""
        if not self.health_check_results:
            return {
                'overall_status': HealthStatus.UNKNOWN.value,
                'message': 'No health checks available',
                'checks': []
            }
        
        # 全体ステータス判定
        critical_count = sum(1 for r in self.health_check_results if r.status == HealthStatus.CRITICAL)
        warning_count = sum(1 for r in self.health_check_results if r.status == HealthStatus.WARNING)
        
        if critical_count > 0:
            overall_status = HealthStatus.CRITICAL
        elif warning_count > 0:
            overall_status = HealthStatus.WARNING
        else:
            overall_status = HealthStatus.HEALTHY
        
        return {
            'overall_status': overall_status.value,
            'message': f'{critical_count} critical, {warning_count} warning',
            'checks': [
                {
                    'name': r.name,
                    'status': r.status.value,
                    'message': r.message,
                    'response_time': r.response_time,
                    'timestamp': r.timestamp.isoformat()
                }
                for r in self.health_check_results
            ],
            'active_alerts': self.active_alerts,
            'recovery_history': self.recovery_history[-10:]  # 最新10件
        }
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """パフォーマンス統計取得"""
        return {
            'metrics_count': sum(len(metrics) for metrics in self.performance_metrics.values()),
            'metrics_by_name': {
                name: len(metrics) for name, metrics in self.performance_metrics.items()
            },
            'health_checks_count': len(self.health_checks),
            'active_alerts_count': len(self.active_alerts),
            'recovery_actions_count': len(self.recovery_actions),
            'last_health_check': self.health_check_results[-1].timestamp.isoformat() if self.health_check_results else None
        }
    
    def close(self):
        """Azure Monitor統合終了"""
        try:
            # ヘルスモニタリング停止
            self.stop_health_monitoring()
            
            # Azure clients
            if hasattr(self.logs_client, 'close'):
                self.logs_client.close()
            if hasattr(self.metrics_client, 'close'):
                self.metrics_client.close()
            
            # Key Vault認証
            if self.key_vault_auth:
                self.key_vault_auth.close()
            
            logger.info("Azure Monitor integration closed")
            
        except Exception as e:
            logger.error(f"Error closing Azure Monitor integration: {str(e)}")
    
    def __enter__(self):
        """Context manager entry"""
        self.start_time = time.time()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


# デフォルトヘルスチェック関数
def check_system_health() -> Dict[str, Any]:
    """システムヘルスチェック"""
    try:
        # CPU使用率チェック
        cpu_percent = psutil.cpu_percent(interval=1)
        if cpu_percent > 90:
            return {
                'status': HealthStatus.CRITICAL.value,
                'message': f'High CPU usage: {cpu_percent}%',
                'details': {'cpu_percent': cpu_percent}
            }
        elif cpu_percent > 70:
            return {
                'status': HealthStatus.WARNING.value,
                'message': f'Moderate CPU usage: {cpu_percent}%',
                'details': {'cpu_percent': cpu_percent}
            }
        
        # メモリ使用率チェック
        memory = psutil.virtual_memory()
        if memory.percent > 90:
            return {
                'status': HealthStatus.CRITICAL.value,
                'message': f'High memory usage: {memory.percent}%',
                'details': {'memory_percent': memory.percent}
            }
        elif memory.percent > 80:
            return {
                'status': HealthStatus.WARNING.value,
                'message': f'Moderate memory usage: {memory.percent}%',
                'details': {'memory_percent': memory.percent}
            }
        
        return {
            'status': HealthStatus.HEALTHY.value,
            'message': 'System health normal',
            'details': {
                'cpu_percent': cpu_percent,
                'memory_percent': memory.percent
            }
        }
        
    except Exception as e:
        return {
            'status': HealthStatus.CRITICAL.value,
            'message': f'System health check failed: {str(e)}',
            'details': {'error': str(e)}
        }


def check_endpoint_health(url: str, timeout: int = 10) -> Dict[str, Any]:
    """エンドポイントヘルスチェック"""
    try:
        response = requests.get(url, timeout=timeout)
        
        if response.status_code == 200:
            return {
                'status': HealthStatus.HEALTHY.value,
                'message': f'Endpoint healthy: {response.status_code}',
                'details': {
                    'status_code': response.status_code,
                    'response_time': response.elapsed.total_seconds()
                }
            }
        else:
            return {
                'status': HealthStatus.WARNING.value,
                'message': f'Endpoint returned {response.status_code}',
                'details': {
                    'status_code': response.status_code,
                    'response_time': response.elapsed.total_seconds()
                }
            }
            
    except requests.exceptions.Timeout:
        return {
            'status': HealthStatus.CRITICAL.value,
            'message': f'Endpoint timeout: {url}',
            'details': {'timeout': timeout}
        }
    except Exception as e:
        return {
            'status': HealthStatus.CRITICAL.value,
            'message': f'Endpoint check failed: {str(e)}',
            'details': {'error': str(e)}
        }


if __name__ == "__main__":
    # テスト実行
    import asyncio
    
    async def test_azure_monitor():
        """Azure Monitor統合テスト"""
        print("Testing Azure Monitor Integration...")
        
        # 設定
        config = MonitoringConfig(
            connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING", "test-connection"),
            workspace_id=os.getenv("LOG_ANALYTICS_WORKSPACE_ID", "test-workspace"),
            health_check_interval=10
        )
        
        # Azure Monitor統合
        with AzureMonitorIntegration(config) as monitor:
            # ヘルスチェック追加
            monitor.add_health_check("system", check_system_health)
            monitor.add_health_check("api", lambda: check_endpoint_health("http://localhost:8000/health"))
            
            # 監視開始
            monitor.start_health_monitoring()
            
            # テストメトリクス送信
            monitor.record_metric("test_metric", 42.0, "count")
            monitor.record_performance_metrics()
            
            # 10秒待機
            await asyncio.sleep(10)
            
            # ステータス確認
            health_status = monitor.get_health_status()
            performance_stats = monitor.get_performance_stats()
            
            print(f"Health Status: {health_status}")
            print(f"Performance Stats: {performance_stats}")
    
    if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
        asyncio.run(test_azure_monitor())
    else:
        print("APPLICATIONINSIGHTS_CONNECTION_STRING not set, skipping test")