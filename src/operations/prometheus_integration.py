#!/usr/bin/env python3
"""
Prometheus FastAPI Integration - Phase 5 Enterprise Operations
24/7 SLA 99.9% Monitoring with Custom Metrics & Azure Monitor
"""

import asyncio
import logging
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field
import json
import os

# Prometheus FastAPI Instrumentator (Context7 latest)
from prometheus_fastapi_instrumentator import Instrumentator, metrics
from prometheus_fastapi_instrumentator.metrics import Info
from prometheus_client import Counter, Histogram, Gauge, Summary, CollectorRegistry, CONTENT_TYPE_LATEST, generate_latest

# FastAPI
from fastapi import FastAPI, Request, Response, Depends
from fastapi.responses import Response as FastAPIResponse
from starlette.middleware.base import BaseHTTPMiddleware

# Azure Monitor OpenTelemetry (Context7 latest)
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics as otel_metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

from src.core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class PrometheusConfig:
    """Prometheus設定"""
    metric_namespace: str = "microsoft365_tools"
    metric_subsystem: str = "api"
    enable_default_metrics: bool = True
    enable_custom_metrics: bool = True
    should_group_status_codes: bool = False
    should_ignore_untemplated: bool = True
    should_instrument_requests_inprogress: bool = True
    excluded_handlers: List[str] = field(default_factory=lambda: [".*admin.*", "/metrics", "/health"])
    custom_labels: Dict[str, str] = field(default_factory=lambda: {"service": "microsoft365-api"})


@dataclass
class SLATarget:
    """SLA目標値"""
    availability_percent: float = 99.9  # 99.9% SLA
    response_time_ms: float = 500.0     # 500ms目標応答時間
    error_rate_percent: float = 0.1     # 0.1%エラー率目標
    
    # Microsoft 365 API特有の目標
    graph_api_response_ms: float = 1000.0    # Graph API応答時間
    exchange_response_ms: float = 2000.0     # Exchange応答時間
    teams_response_ms: float = 1500.0        # Teams応答時間


class MicrosoftGraphMetrics:
    """Microsoft Graph API専用メトリクス"""
    
    def __init__(self, namespace: str = "microsoft365_tools", subsystem: str = "graph_api"):
        self.namespace = namespace
        self.subsystem = subsystem
        
        # Graph API呼び出し回数
        self.graph_requests_total = Counter(
            name=f"{namespace}_{subsystem}_requests_total",
            documentation="Total Microsoft Graph API requests",
            labelnames=["method", "endpoint", "status_code", "tenant_id"]
        )
        
        # Graph API応答時間
        self.graph_response_time = Histogram(
            name=f"{namespace}_{subsystem}_response_time_seconds",
            documentation="Microsoft Graph API response time",
            labelnames=["method", "endpoint", "tenant_id"],
            buckets=(0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, float("inf"))
        )
        
        # Graph APIエラー率
        self.graph_errors_total = Counter(
            name=f"{namespace}_{subsystem}_errors_total",
            documentation="Total Microsoft Graph API errors",
            labelnames=["method", "endpoint", "error_type", "tenant_id"]
        )
        
        # Graph APIレート制限
        self.graph_rate_limit_remaining = Gauge(
            name=f"{namespace}_{subsystem}_rate_limit_remaining",
            documentation="Remaining Microsoft Graph API rate limit",
            labelnames=["tenant_id"]
        )
        
        # Graph APIアクティブ接続数
        self.graph_active_connections = Gauge(
            name=f"{namespace}_{subsystem}_active_connections",
            documentation="Active Microsoft Graph API connections",
            labelnames=["tenant_id"]
        )


class Microsoft365ServiceMetrics:
    """Microsoft 365サービス別メトリクス"""
    
    def __init__(self, namespace: str = "microsoft365_tools"):
        self.namespace = namespace
        
        # Exchange Online メトリクス
        self.exchange_mailbox_count = Gauge(
            name=f"{namespace}_exchange_mailbox_count",
            documentation="Total Exchange Online mailboxes",
            labelnames=["tenant_id", "mailbox_type"]
        )
        
        self.exchange_mail_flow_total = Counter(
            name=f"{namespace}_exchange_mail_flow_total",
            documentation="Total Exchange mail flow events",
            labelnames=["tenant_id", "direction", "status"]
        )
        
        # Teams メトリクス
        self.teams_active_users = Gauge(
            name=f"{namespace}_teams_active_users",
            documentation="Active Teams users",
            labelnames=["tenant_id", "time_period"]
        )
        
        self.teams_meetings_total = Counter(
            name=f"{namespace}_teams_meetings_total",
            documentation="Total Teams meetings",
            labelnames=["tenant_id", "meeting_type"]
        )
        
        # OneDrive メトリクス
        self.onedrive_storage_used_bytes = Gauge(
            name=f"{namespace}_onedrive_storage_used_bytes",
            documentation="OneDrive storage used in bytes",
            labelnames=["tenant_id", "user_id"]
        )
        
        self.onedrive_files_shared_total = Counter(
            name=f"{namespace}_onedrive_files_shared_total",
            documentation="Total OneDrive files shared",
            labelnames=["tenant_id", "sharing_type"]
        )


class SLAMonitoringMetrics:
    """SLA監視専用メトリクス"""
    
    def __init__(self, namespace: str = "microsoft365_tools", subsystem: str = "sla"):
        self.namespace = namespace
        self.subsystem = subsystem
        
        # SLA可用性
        self.sla_availability_percent = Gauge(
            name=f"{namespace}_{subsystem}_availability_percent",
            documentation="Current SLA availability percentage",
            labelnames=["service", "tenant_id"]
        )
        
        # SLA違反カウンター
        self.sla_violations_total = Counter(
            name=f"{namespace}_{subsystem}_violations_total",
            documentation="Total SLA violations",
            labelnames=["violation_type", "service", "tenant_id"]
        )
        
        # 平均応答時間
        self.sla_response_time_avg = Gauge(
            name=f"{namespace}_{subsystem}_response_time_avg_ms",
            documentation="Average response time for SLA monitoring",
            labelnames=["service", "tenant_id"]
        )
        
        # エラー率
        self.sla_error_rate_percent = Gauge(
            name=f"{namespace}_{subsystem}_error_rate_percent",
            documentation="Current error rate percentage",
            labelnames=["service", "tenant_id"]
        )
        
        # 稼働時間
        self.sla_uptime_seconds = Gauge(
            name=f"{namespace}_{subsystem}_uptime_seconds",
            documentation="Service uptime in seconds",
            labelnames=["service", "tenant_id"]
        )


class PrometheusIntegration:
    """Prometheus FastAPI統合 - Enterprise Edition"""
    
    def __init__(self, config: PrometheusConfig = None):
        self.config = config or PrometheusConfig()
        self.settings = get_settings()
        
        # メトリクスクラス初期化
        self.graph_metrics = MicrosoftGraphMetrics(
            namespace=self.config.metric_namespace,
            subsystem="graph_api"
        )
        self.service_metrics = Microsoft365ServiceMetrics(
            namespace=self.config.metric_namespace
        )
        self.sla_metrics = SLAMonitoringMetrics(
            namespace=self.config.metric_namespace,
            subsystem="sla"
        )
        
        # SLA目標
        self.sla_targets = SLATarget()
        
        # カスタムInstrumentator
        self.instrumentator = self._create_instrumentator()
        
        # Azure Monitor統合
        self.azure_tracer = None
        self.azure_meter = None
        
        # SLA監視状態
        self.sla_monitoring_start = datetime.utcnow()
        self.sla_downtime_seconds = 0
        self.last_availability_check = datetime.utcnow()
        
        logger.info("Prometheus Integration initialized with enterprise features")
    
    def _create_instrumentator(self) -> Instrumentator:
        """カスタムInstrumentator作成（Context7最新機能）"""
        instrumentator = Instrumentator(
            should_group_status_codes=self.config.should_group_status_codes,
            should_ignore_untemplated=self.config.should_ignore_untemplated,
            should_respect_env_var=True,
            should_instrument_requests_inprogress=self.config.should_instrument_requests_inprogress,
            excluded_handlers=self.config.excluded_handlers,
            env_var_name="ENABLE_METRICS",
            inprogress_name="requests_inprogress",
            inprogress_labels=True,
            custom_labels=self.config.custom_labels
        )
        
        if self.config.enable_default_metrics:
            # デフォルトメトリクス追加
            instrumentator.add(
                metrics.latency(
                    buckets=(0.1, 0.25, 0.5, 1, 2.5, 5, 10, float("inf")),
                    metric_namespace=self.config.metric_namespace,
                    metric_subsystem=self.config.metric_subsystem
                )
            )
            
            instrumentator.add(
                metrics.request_size(
                    should_include_handler=True,
                    should_include_method=True,
                    should_include_status=True,
                    metric_namespace=self.config.metric_namespace,
                    metric_subsystem=self.config.metric_subsystem,
                    custom_labels=self.config.custom_labels
                )
            )
            
            instrumentator.add(
                metrics.response_size(
                    should_include_handler=True,
                    should_include_method=True,
                    should_include_status=True,
                    metric_namespace=self.config.metric_namespace,
                    metric_subsystem=self.config.metric_subsystem,
                    custom_labels=self.config.custom_labels
                )
            )
        
        if self.config.enable_custom_metrics:
            # カスタムメトリクス追加
            instrumentator.add(self._microsoft_graph_instrumentation())
            instrumentator.add(self._sla_monitoring_instrumentation())
            instrumentator.add(self._microsoft365_services_instrumentation())
        
        return instrumentator
    
    def _microsoft_graph_instrumentation(self) -> Callable[[Info], None]:
        """Microsoft Graph API専用インスツルメンテーション"""
        def instrumentation(info: Info) -> None:
            try:
                # Graph APIエンドポイント検出
                if "/graph/" in info.request.url.path or "graph.microsoft.com" in str(info.request.url):
                    method = info.request.method
                    endpoint = self._extract_graph_endpoint(info.request.url.path)
                    tenant_id = self._extract_tenant_id(info.request)
                    status_code = str(info.response.status_code)
                    
                    # メトリクス更新
                    self.graph_metrics.graph_requests_total.labels(
                        method=method,
                        endpoint=endpoint,
                        status_code=status_code,
                        tenant_id=tenant_id
                    ).inc()
                    
                    # 応答時間記録
                    if hasattr(info, 'response_time'):
                        self.graph_metrics.graph_response_time.labels(
                            method=method,
                            endpoint=endpoint,
                            tenant_id=tenant_id
                        ).observe(info.response_time)
                    
                    # エラー処理
                    if info.response.status_code >= 400:
                        error_type = self._categorize_error(info.response.status_code)
                        self.graph_metrics.graph_errors_total.labels(
                            method=method,
                            endpoint=endpoint,
                            error_type=error_type,
                            tenant_id=tenant_id
                        ).inc()
                    
                    # レート制限情報
                    if "x-ms-throttle-limit-percentage" in info.response.headers:
                        remaining = float(info.response.headers["x-ms-throttle-limit-percentage"])
                        self.graph_metrics.graph_rate_limit_remaining.labels(
                            tenant_id=tenant_id
                        ).set(remaining)
                        
            except Exception as e:
                logger.error(f"Error in Graph API instrumentation: {e}")
        
        return instrumentation
    
    def _sla_monitoring_instrumentation(self) -> Callable[[Info], None]:
        """SLA監視専用インスツルメンテーション"""
        def instrumentation(info: Info) -> None:
            try:
                service_name = self._identify_service(info.request.url.path)
                tenant_id = self._extract_tenant_id(info.request)
                
                # 応答時間チェック
                if hasattr(info, 'response_time'):
                    response_time_ms = info.response_time * 1000
                    
                    # SLA応答時間更新
                    self.sla_metrics.sla_response_time_avg.labels(
                        service=service_name,
                        tenant_id=tenant_id
                    ).set(response_time_ms)
                    
                    # SLA違反チェック
                    target_time = self._get_response_time_target(service_name)
                    if response_time_ms > target_time:
                        self.sla_metrics.sla_violations_total.labels(
                            violation_type="response_time",
                            service=service_name,
                            tenant_id=tenant_id
                        ).inc()
                
                # エラー率チェック
                if info.response.status_code >= 500:
                    self.sla_metrics.sla_violations_total.labels(
                        violation_type="server_error",
                        service=service_name,
                        tenant_id=tenant_id
                    ).inc()
                
                # 可用性計算
                self._update_sla_availability(service_name, tenant_id, info.response.status_code)
                
            except Exception as e:
                logger.error(f"Error in SLA monitoring instrumentation: {e}")
        
        return instrumentation
    
    def _microsoft365_services_instrumentation(self) -> Callable[[Info], None]:
        """Microsoft 365サービス別インスツルメンテーション"""
        def instrumentation(info: Info) -> None:
            try:
                service_type = self._detect_service_type(info.request.url.path)
                tenant_id = self._extract_tenant_id(info.request)
                
                # Exchange Online
                if service_type == "exchange":
                    self._record_exchange_metrics(info, tenant_id)
                
                # Teams
                elif service_type == "teams":
                    self._record_teams_metrics(info, tenant_id)
                
                # OneDrive
                elif service_type == "onedrive":
                    self._record_onedrive_metrics(info, tenant_id)
                    
            except Exception as e:
                logger.error(f"Error in Microsoft 365 services instrumentation: {e}")
        
        return instrumentation
    
    def _extract_graph_endpoint(self, path: str) -> str:
        """Graph APIエンドポイント抽出"""
        try:
            if "/v1.0/" in path:
                endpoint = path.split("/v1.0/")[1].split("?")[0]
                return endpoint.split("/")[0]  # 最初のリソースタイプ
            elif "/beta/" in path:
                endpoint = path.split("/beta/")[1].split("?")[0]
                return endpoint.split("/")[0]
            else:
                return "unknown"
        except:
            return "unknown"
    
    def _extract_tenant_id(self, request) -> str:
        """テナントID抽出"""
        try:
            # ヘッダーから取得
            if hasattr(request, 'headers'):
                if "x-tenant-id" in request.headers:
                    return request.headers["x-tenant-id"]
                if "authorization" in request.headers:
                    # JWT tokenからテナントID抽出（簡易版）
                    # 実際の実装ではJWTデコードが必要
                    return "decoded-tenant-id"
            
            # クエリパラメータから取得
            if hasattr(request, 'query_params'):
                if "tenant_id" in request.query_params:
                    return request.query_params["tenant_id"]
            
            return "default"
        except:
            return "unknown"
    
    def _categorize_error(self, status_code: int) -> str:
        """エラー分類"""
        if status_code == 401:
            return "authentication"
        elif status_code == 403:
            return "authorization"
        elif status_code == 404:
            return "not_found"
        elif status_code == 429:
            return "rate_limit"
        elif status_code >= 500:
            return "server_error"
        else:
            return "client_error"
    
    def _identify_service(self, path: str) -> str:
        """サービス識別"""
        if "/graph/" in path or "graph.microsoft.com" in path:
            return "microsoft_graph"
        elif "/exchange/" in path:
            return "exchange_online"
        elif "/teams/" in path:
            return "microsoft_teams"
        elif "/onedrive/" in path:
            return "onedrive"
        else:
            return "api"
    
    def _get_response_time_target(self, service_name: str) -> float:
        """サービス別応答時間目標取得"""
        targets = {
            "microsoft_graph": self.sla_targets.graph_api_response_ms,
            "exchange_online": self.sla_targets.exchange_response_ms,
            "microsoft_teams": self.sla_targets.teams_response_ms,
            "onedrive": self.sla_targets.response_time_ms,
            "api": self.sla_targets.response_time_ms
        }
        return targets.get(service_name, self.sla_targets.response_time_ms)
    
    def _update_sla_availability(self, service_name: str, tenant_id: str, status_code: int):
        """SLA可用性更新"""
        try:
            current_time = datetime.utcnow()
            
            # サービス正常性判定
            is_healthy = status_code < 500
            
            # 可用性計算
            total_time = (current_time - self.sla_monitoring_start).total_seconds()
            if total_time > 0:
                if is_healthy:
                    availability = ((total_time - self.sla_downtime_seconds) / total_time) * 100
                else:
                    # ダウンタイム追加
                    check_interval = (current_time - self.last_availability_check).total_seconds()
                    self.sla_downtime_seconds += check_interval
                    availability = ((total_time - self.sla_downtime_seconds) / total_time) * 100
                
                # メトリクス更新
                self.sla_metrics.sla_availability_percent.labels(
                    service=service_name,
                    tenant_id=tenant_id
                ).set(availability)
                
                # 稼働時間更新
                uptime = total_time - self.sla_downtime_seconds
                self.sla_metrics.sla_uptime_seconds.labels(
                    service=service_name,
                    tenant_id=tenant_id
                ).set(uptime)
                
                # SLA違反チェック
                if availability < self.sla_targets.availability_percent:
                    self.sla_metrics.sla_violations_total.labels(
                        violation_type="availability",
                        service=service_name,
                        tenant_id=tenant_id
                    ).inc()
            
            self.last_availability_check = current_time
            
        except Exception as e:
            logger.error(f"Error updating SLA availability: {e}")
    
    def _detect_service_type(self, path: str) -> str:
        """サービスタイプ検出"""
        if "/exchange/" in path or "/mailbox" in path:
            return "exchange"
        elif "/teams/" in path or "/team" in path:
            return "teams"
        elif "/onedrive/" in path or "/drive" in path:
            return "onedrive"
        else:
            return "general"
    
    def _record_exchange_metrics(self, info: Info, tenant_id: str):
        """Exchange メトリクス記録"""
        try:
            if "mailbox" in info.request.url.path:
                # メールボックス数の模擬データ（実際は API レスポンスから取得）
                self.service_metrics.exchange_mailbox_count.labels(
                    tenant_id=tenant_id,
                    mailbox_type="user"
                ).set(100)  # 模擬値
                
        except Exception as e:
            logger.error(f"Error recording Exchange metrics: {e}")
    
    def _record_teams_metrics(self, info: Info, tenant_id: str):
        """Teams メトリクス記録"""
        try:
            if "teams" in info.request.url.path.lower():
                # アクティブユーザー数の模擬データ
                self.service_metrics.teams_active_users.labels(
                    tenant_id=tenant_id,
                    time_period="daily"
                ).set(50)  # 模擬値
                
        except Exception as e:
            logger.error(f"Error recording Teams metrics: {e}")
    
    def _record_onedrive_metrics(self, info: Info, tenant_id: str):
        """OneDrive メトリクス記録"""
        try:
            if "onedrive" in info.request.url.path.lower():
                # ストレージ使用量の模擬データ
                self.service_metrics.onedrive_storage_used_bytes.labels(
                    tenant_id=tenant_id,
                    user_id="user123"
                ).set(1073741824)  # 1GB模擬値
                
        except Exception as e:
            logger.error(f"Error recording OneDrive metrics: {e}")
    
    async def setup_azure_monitor(self):
        """Azure Monitor OpenTelemetry統合（Context7最新）"""
        try:
            if hasattr(self.settings, 'AZURE_MONITOR_CONNECTION_STRING'):
                # Azure Monitor設定
                configure_azure_monitor(
                    connection_string=self.settings.AZURE_MONITOR_CONNECTION_STRING,
                    disable_offline_storage=False
                )
                
                # OpenTelemetry tracer & meter
                self.azure_tracer = trace.get_tracer(__name__)
                self.azure_meter = otel_metrics.get_meter(__name__)
                
                logger.info("Azure Monitor OpenTelemetry configured successfully")
            else:
                logger.warning("Azure Monitor connection string not configured")
                
        except Exception as e:
            logger.error(f"Error setting up Azure Monitor: {e}")
    
    def instrument_app(self, app: FastAPI) -> Instrumentator:
        """FastAPIアプリケーションにメトリクス計測を追加"""
        try:
            # Instrumentator設定
            self.instrumentator.instrument(
                app,
                metric_namespace=self.config.metric_namespace,
                metric_subsystem=self.config.metric_subsystem
            )
            
            # Azure Monitor FastAPI Instrumentation
            if self.azure_tracer:
                FastAPIInstrumentor.instrument_app(app)
                RequestsInstrumentor().instrument()
            
            logger.info(f"FastAPI instrumented with Prometheus metrics (namespace: {self.config.metric_namespace})")
            return self.instrumentator
            
        except Exception as e:
            logger.error(f"Error instrumenting FastAPI app: {e}")
            raise
    
    def expose_metrics(self, app: FastAPI, endpoint: str = "/metrics", 
                      include_in_schema: bool = False, should_gzip: bool = True):
        """メトリクスエンドポイント公開（Context7最新機能）"""
        try:
            self.instrumentator.expose(
                app,
                endpoint=endpoint,
                include_in_schema=include_in_schema,
                should_gzip=should_gzip
            )
            
            logger.info(f"Prometheus metrics exposed at {endpoint}")
            
        except Exception as e:
            logger.error(f"Error exposing metrics endpoint: {e}")
            raise
    
    async def record_custom_metric(self, metric_name: str, value: float, 
                                  labels: Dict[str, str] = None):
        """カスタムメトリクス記録"""
        try:
            # Prometheus記録
            metric_full_name = f"{self.config.metric_namespace}_{metric_name}"
            
            # 動的にメトリクス作成（簡易版）
            from prometheus_client import Gauge
            gauge = Gauge(metric_full_name, f"Custom metric: {metric_name}", labelnames=list(labels.keys()) if labels else [])
            
            if labels:
                gauge.labels(**labels).set(value)
            else:
                gauge.set(value)
            
            # Azure Monitor記録
            if self.azure_meter:
                azure_gauge = self.azure_meter.create_gauge(metric_name)
                azure_gauge.set(value, labels or {})
            
            logger.debug(f"Custom metric recorded: {metric_name}={value}")
            
        except Exception as e:
            logger.error(f"Error recording custom metric: {e}")
    
    def get_sla_status(self) -> Dict[str, Any]:
        """SLA状況取得"""
        try:
            current_time = datetime.utcnow()
            total_time = (current_time - self.sla_monitoring_start).total_seconds()
            
            if total_time > 0:
                availability = ((total_time - self.sla_downtime_seconds) / total_time) * 100
            else:
                availability = 100.0
            
            return {
                "current_availability_percent": round(availability, 3),
                "target_availability_percent": self.sla_targets.availability_percent,
                "sla_compliant": availability >= self.sla_targets.availability_percent,
                "total_monitoring_time_hours": total_time / 3600,
                "total_downtime_minutes": self.sla_downtime_seconds / 60,
                "monitoring_start": self.sla_monitoring_start.isoformat(),
                "last_check": self.last_availability_check.isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting SLA status: {e}")
            return {"error": str(e)}
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """メトリクス概要取得"""
        try:
            return {
                "prometheus_config": {
                    "namespace": self.config.metric_namespace,
                    "subsystem": self.config.metric_subsystem,
                    "custom_labels": self.config.custom_labels
                },
                "sla_targets": {
                    "availability_percent": self.sla_targets.availability_percent,
                    "response_time_ms": self.sla_targets.response_time_ms,
                    "error_rate_percent": self.sla_targets.error_rate_percent
                },
                "azure_monitor_enabled": self.azure_tracer is not None,
                "metrics_exposed": True,
                "instrumentation_active": True
            }
            
        except Exception as e:
            logger.error(f"Error getting metrics summary: {e}")
            return {"error": str(e)}


# グローバルインスタンス
prometheus_integration = PrometheusIntegration()


# FastAPI startup/shutdown handlers
async def startup_prometheus():
    """Prometheus統合スタートアップ"""
    await prometheus_integration.setup_azure_monitor()
    logger.info("Prometheus integration started")


async def shutdown_prometheus():
    """Prometheus統合シャットダウン"""
    logger.info("Prometheus integration stopped")


if __name__ == "__main__":
    # テスト実行
    from fastapi import FastAPI
    
    app = FastAPI(title="Test Prometheus Integration")
    
    # Prometheus統合
    config = PrometheusConfig(
        metric_namespace="test_app",
        metric_subsystem="api"
    )
    
    prometheus = PrometheusIntegration(config)
    prometheus.instrument_app(app)
    prometheus.expose_metrics(app)
    
    @app.get("/test")
    async def test_endpoint():
        await prometheus.record_custom_metric("test_metric", 42.0, {"endpoint": "test"})
        return {"message": "Test endpoint"}
    
    @app.get("/health")
    async def health_check():
        return {"status": "healthy"}
    
    print("Test FastAPI app with Prometheus integration created")
    print("Metrics available at: /metrics")
    print("SLA status:", prometheus.get_sla_status())
    print("Metrics summary:", prometheus.get_metrics_summary())