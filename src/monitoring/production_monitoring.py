"""
Microsoft 365管理ツール 本番監視システム
===================================

本番環境向け包括的監視システム
- システム稼働監視・ヘルスチェック
- パフォーマンス監視・アラート
- エラー監視・異常検知
- 運用メトリクス・ダッシュボード
"""

import asyncio
import logging
import time
import json
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from enum import Enum
import psutil
import aiofiles

logger = logging.getLogger(__name__)


class AlertSeverity(Enum):
    """アラート重要度"""
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR" 
    CRITICAL = "CRITICAL"


class MonitoringStatus(Enum):
    """監視ステータス"""
    HEALTHY = "HEALTHY"
    WARNING = "WARNING"
    DEGRADED = "DEGRADED"
    DOWN = "DOWN"


@dataclass
class SystemMetrics:
    """システムメトリクス"""
    timestamp: datetime
    cpu_percent: float
    memory_percent: float
    disk_percent: float
    network_connections: int
    active_threads: int
    response_time_ms: float
    request_count: int
    error_count: int
    database_connections: int


@dataclass
class Alert:
    """アラート"""
    alert_id: str
    severity: AlertSeverity
    title: str
    description: str
    component: str
    timestamp: datetime
    resolved: bool = False
    resolved_at: Optional[datetime] = None
    metadata: Dict[str, Any] = None


@dataclass
class HealthCheck:
    """ヘルスチェック結果"""
    component: str
    status: MonitoringStatus
    response_time_ms: float
    message: str
    timestamp: datetime
    details: Dict[str, Any] = None


class ProductionMonitoringSystem:
    """本番監視システム"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.metrics_history: List[SystemMetrics] = []
        self.alerts: List[Alert] = []
        self.health_checks: Dict[str, HealthCheck] = {}
        
        # 監視設定
        self.monitoring_interval = config.get('monitoring_interval', 30)  # 30秒間隔
        self.metrics_retention_hours = config.get('metrics_retention_hours', 24)
        self.alert_thresholds = config.get('alert_thresholds', {
            'cpu_percent': 80,
            'memory_percent': 85,
            'disk_percent': 90,
            'response_time_ms': 2000,
            'error_rate': 0.05
        })
        
        # 通知設定
        self.notification_config = config.get('notifications', {})
        self.email_enabled = self.notification_config.get('email_enabled', False)
        self.webhook_enabled = self.notification_config.get('webhook_enabled', False)
        
        # 監視状態
        self.is_monitoring = False
        self.monitoring_task = None
        
        # コンポーネント監視設定
        self.components_to_monitor = [
            'api_server',
            'database',
            'microsoft_graph',
            'exchange_online',
            'authentication',
            'cache_system'
        ]
    
    async def start_monitoring(self):
        """監視開始"""
        
        if self.is_monitoring:
            logger.warning("監視は既に開始されています")
            return
        
        self.is_monitoring = True
        self.monitoring_task = asyncio.create_task(self._monitoring_loop())
        
        logger.info("本番監視システム開始")
        
        # 開始通知
        await self._send_notification(
            Alert(
                alert_id=f"monitoring_started_{int(time.time())}",
                severity=AlertSeverity.INFO,
                title="監視システム開始",
                description="本番監視システムが開始されました",
                component="monitoring_system",
                timestamp=datetime.utcnow()
            )
        )
    
    async def stop_monitoring(self):
        """監視停止"""
        
        self.is_monitoring = False
        
        if self.monitoring_task:
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass
        
        logger.info("本番監視システム停止")
    
    async def _monitoring_loop(self):
        """監視ループ"""
        
        while self.is_monitoring:
            try:
                # システムメトリクス収集
                metrics = await self._collect_system_metrics()
                self.metrics_history.append(metrics)
                
                # ヘルスチェック実行
                await self._perform_health_checks()
                
                # アラート評価
                await self._evaluate_alerts(metrics)
                
                # メトリクス履歴クリーンアップ
                await self._cleanup_metrics_history()
                
                # 監視間隔待機
                await asyncio.sleep(self.monitoring_interval)
                
            except Exception as e:
                logger.error(f"監視ループエラー: {e}")
                await asyncio.sleep(5)  # エラー時は短い間隔で再試行
    
    async def _collect_system_metrics(self) -> SystemMetrics:
        """システムメトリクス収集"""
        
        try:
            # CPU使用率
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # メモリ使用率
            memory = psutil.virtual_memory()
            memory_percent = memory.percent
            
            # ディスク使用率
            disk = psutil.disk_usage('/')
            disk_percent = (disk.used / disk.total) * 100
            
            # ネットワーク接続数
            network_connections = len(psutil.net_connections())
            
            # プロセス情報
            process = psutil.Process()
            active_threads = process.num_threads()
            
            # API メトリクス（プレースホルダー）
            response_time_ms = await self._measure_api_response_time()
            request_count = await self._get_request_count()
            error_count = await self._get_error_count()
            
            # データベース接続数
            database_connections = await self._get_database_connections()
            
            metrics = SystemMetrics(
                timestamp=datetime.utcnow(),
                cpu_percent=cpu_percent,
                memory_percent=memory_percent,
                disk_percent=disk_percent,
                network_connections=network_connections,
                active_threads=active_threads,
                response_time_ms=response_time_ms,
                request_count=request_count,
                error_count=error_count,
                database_connections=database_connections
            )
            
            logger.debug(f"メトリクス収集完了: CPU={cpu_percent:.1f}%, メモリ={memory_percent:.1f}%")
            return metrics
            
        except Exception as e:
            logger.error(f"メトリクス収集エラー: {e}")
            return SystemMetrics(
                timestamp=datetime.utcnow(),
                cpu_percent=0,
                memory_percent=0,
                disk_percent=0,
                network_connections=0,
                active_threads=0,
                response_time_ms=0,
                request_count=0,
                error_count=0,
                database_connections=0
            )
    
    async def _perform_health_checks(self):
        """ヘルスチェック実行"""
        
        for component in self.components_to_monitor:
            try:
                health_check = await self._check_component_health(component)
                self.health_checks[component] = health_check
                
                # 異常検知時のアラート
                if health_check.status in [MonitoringStatus.DEGRADED, MonitoringStatus.DOWN]:
                    await self._create_alert(
                        AlertSeverity.ERROR if health_check.status == MonitoringStatus.DOWN else AlertSeverity.WARNING,
                        f"{component}異常検知",
                        f"コンポーネント {component} の状態: {health_check.status.value}",
                        component,
                        {"health_check": asdict(health_check)}
                    )
                
            except Exception as e:
                logger.error(f"ヘルスチェックエラー {component}: {e}")
                
                self.health_checks[component] = HealthCheck(
                    component=component,
                    status=MonitoringStatus.DOWN,
                    response_time_ms=0,
                    message=f"ヘルスチェック失敗: {str(e)}",
                    timestamp=datetime.utcnow()
                )
    
    async def _check_component_health(self, component: str) -> HealthCheck:
        """コンポーネント別ヘルスチェック"""
        
        start_time = time.time()
        
        try:
            if component == 'api_server':
                status, message = await self._check_api_server()
            elif component == 'database':
                status, message = await self._check_database()
            elif component == 'microsoft_graph':
                status, message = await self._check_microsoft_graph()
            elif component == 'exchange_online':
                status, message = await self._check_exchange_online()
            elif component == 'authentication':
                status, message = await self._check_authentication()
            elif component == 'cache_system':
                status, message = await self._check_cache_system()
            else:
                status, message = MonitoringStatus.WARNING, f"未知のコンポーネント: {component}"
            
            response_time = (time.time() - start_time) * 1000
            
            return HealthCheck(
                component=component,
                status=status,
                response_time_ms=response_time,
                message=message,
                timestamp=datetime.utcnow()
            )
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            
            return HealthCheck(
                component=component,
                status=MonitoringStatus.DOWN,
                response_time_ms=response_time,
                message=f"ヘルスチェック例外: {str(e)}",
                timestamp=datetime.utcnow()
            )
    
    async def _check_api_server(self) -> tuple[MonitoringStatus, str]:
        """APIサーバーヘルスチェック"""
        
        try:
            # 簡易ヘルスチェックエンドポイント呼び出し
            import aiohttp
            
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=5)) as session:
                async with session.get('http://localhost:8000/health') as response:
                    if response.status == 200:
                        return MonitoringStatus.HEALTHY, "APIサーバー正常"
                    else:
                        return MonitoringStatus.DEGRADED, f"APIサーバー応答異常: {response.status}"
        
        except asyncio.TimeoutError:
            return MonitoringStatus.DEGRADED, "APIサーバータイムアウト"
        except Exception as e:
            return MonitoringStatus.DOWN, f"APIサーバー接続失敗: {str(e)}"
    
    async def _check_database(self) -> tuple[MonitoringStatus, str]:
        """データベースヘルスチェック"""
        
        try:
            # データベース接続テスト（プレースホルダー）
            # 実際の実装では SQLAlchemy セッションを使用
            connection_count = await self._get_database_connections()
            
            if connection_count > 0:
                return MonitoringStatus.HEALTHY, f"データベース接続正常 ({connection_count}接続)"
            else:
                return MonitoringStatus.WARNING, "データベース接続数0"
                
        except Exception as e:
            return MonitoringStatus.DOWN, f"データベース接続失敗: {str(e)}"
    
    async def _check_microsoft_graph(self) -> tuple[MonitoringStatus, str]:
        """Microsoft Graph ヘルスチェック"""
        
        try:
            # Microsoft Graph API 疎通確認（プレースホルダー）
            # 実際の実装では認証トークンを使用してテストAPI呼び出し
            await asyncio.sleep(0.1)  # 模擬API呼び出し
            
            return MonitoringStatus.HEALTHY, "Microsoft Graph API 正常"
            
        except Exception as e:
            return MonitoringStatus.DOWN, f"Microsoft Graph API 異常: {str(e)}"
    
    async def _check_exchange_online(self) -> tuple[MonitoringStatus, str]:
        """Exchange Online ヘルスチェック"""
        
        try:
            # Exchange Online PowerShell 接続確認（プレースホルダー）
            await asyncio.sleep(0.1)  # 模擬接続確認
            
            return MonitoringStatus.HEALTHY, "Exchange Online 接続正常"
            
        except Exception as e:
            return MonitoringStatus.DOWN, f"Exchange Online 接続異常: {str(e)}"
    
    async def _check_authentication(self) -> tuple[MonitoringStatus, str]:
        """認証システムヘルスチェック"""
        
        try:
            # 認証システム動作確認（プレースホルダー）
            await asyncio.sleep(0.1)  # 模擬認証テスト
            
            return MonitoringStatus.HEALTHY, "認証システム正常"
            
        except Exception as e:
            return MonitoringStatus.DOWN, f"認証システム異常: {str(e)}"
    
    async def _check_cache_system(self) -> tuple[MonitoringStatus, str]:
        """キャッシュシステムヘルスチェック"""
        
        try:
            # キャッシュシステム動作確認（プレースホルダー）
            await asyncio.sleep(0.1)  # 模擬キャッシュテスト
            
            return MonitoringStatus.HEALTHY, "キャッシュシステム正常"
            
        except Exception as e:
            return MonitoringStatus.WARNING, f"キャッシュシステム異常: {str(e)}"
    
    async def _evaluate_alerts(self, metrics: SystemMetrics):
        """アラート評価"""
        
        # CPU使用率アラート
        if metrics.cpu_percent > self.alert_thresholds['cpu_percent']:
            await self._create_alert(
                AlertSeverity.WARNING if metrics.cpu_percent < 90 else AlertSeverity.ERROR,
                "CPU使用率高",
                f"CPU使用率が {metrics.cpu_percent:.1f}% に達しています",
                "system",
                {"cpu_percent": metrics.cpu_percent}
            )
        
        # メモリ使用率アラート
        if metrics.memory_percent > self.alert_thresholds['memory_percent']:
            await self._create_alert(
                AlertSeverity.WARNING if metrics.memory_percent < 95 else AlertSeverity.CRITICAL,
                "メモリ使用率高",
                f"メモリ使用率が {metrics.memory_percent:.1f}% に達しています",
                "system",
                {"memory_percent": metrics.memory_percent}
            )
        
        # ディスク使用率アラート
        if metrics.disk_percent > self.alert_thresholds['disk_percent']:
            await self._create_alert(
                AlertSeverity.ERROR,
                "ディスク使用率高",
                f"ディスク使用率が {metrics.disk_percent:.1f}% に達しています",
                "system",
                {"disk_percent": metrics.disk_percent}
            )
        
        # レスポンス時間アラート
        if metrics.response_time_ms > self.alert_thresholds['response_time_ms']:
            await self._create_alert(
                AlertSeverity.WARNING,
                "レスポンス時間遅延",
                f"平均レスポンス時間が {metrics.response_time_ms:.0f}ms に達しています",
                "api",
                {"response_time_ms": metrics.response_time_ms}
            )
        
        # エラー率アラート
        if metrics.request_count > 0:
            error_rate = metrics.error_count / metrics.request_count
            if error_rate > self.alert_thresholds['error_rate']:
                await self._create_alert(
                    AlertSeverity.ERROR,
                    "エラー率高",
                    f"エラー率が {error_rate:.2%} に達しています",
                    "api",
                    {"error_rate": error_rate, "error_count": metrics.error_count}
                )
    
    async def _create_alert(self, severity: AlertSeverity, title: str, description: str, 
                          component: str, metadata: Dict[str, Any] = None):
        """アラート作成"""
        
        alert_id = f"{component}_{int(time.time())}"
        
        # 重複アラートチェック
        recent_alerts = [
            alert for alert in self.alerts
            if alert.component == component
            and alert.title == title
            and not alert.resolved
            and (datetime.utcnow() - alert.timestamp).total_seconds() < 300  # 5分以内
        ]
        
        if recent_alerts:
            logger.debug(f"重複アラートスキップ: {title}")
            return
        
        alert = Alert(
            alert_id=alert_id,
            severity=severity,
            title=title,
            description=description,
            component=component,
            timestamp=datetime.utcnow(),
            metadata=metadata or {}
        )
        
        self.alerts.append(alert)
        
        # アラート通知
        await self._send_notification(alert)
        
        # ログ出力
        log_level = {
            AlertSeverity.INFO: logging.INFO,
            AlertSeverity.WARNING: logging.WARNING,
            AlertSeverity.ERROR: logging.ERROR,
            AlertSeverity.CRITICAL: logging.CRITICAL
        }.get(severity, logging.INFO)
        
        logger.log(log_level, f"アラート発生 [{severity.value}] {title}: {description}")
    
    async def _send_notification(self, alert: Alert):
        """通知送信"""
        
        try:
            # メール通知
            if self.email_enabled:
                await self._send_email_notification(alert)
            
            # Webhook通知
            if self.webhook_enabled:
                await self._send_webhook_notification(alert)
            
        except Exception as e:
            logger.error(f"通知送信エラー: {e}")
    
    async def _send_email_notification(self, alert: Alert):
        """メール通知送信"""
        
        try:
            email_config = self.notification_config.get('email', {})
            
            if not email_config:
                return
            
            # メール作成
            msg = MIMEMultipart()
            msg['From'] = email_config.get('from_address')
            msg['To'] = ', '.join(email_config.get('to_addresses', []))
            msg['Subject'] = f"[監視アラート] {alert.title}"
            
            body = f"""
監視システムからのアラート通知

重要度: {alert.severity.value}
コンポーネント: {alert.component}
タイトル: {alert.title}
説明: {alert.description}
発生時刻: {alert.timestamp.isoformat()}

詳細情報:
{json.dumps(alert.metadata, indent=2, ensure_ascii=False)}

本メールは自動送信です。
            """.strip()
            
            msg.attach(MIMEText(body, 'plain', 'utf-8'))
            
            # SMTP送信
            smtp_config = email_config.get('smtp', {})
            with smtplib.SMTP(smtp_config.get('host'), smtp_config.get('port', 587)) as server:
                if smtp_config.get('tls', True):
                    server.starttls()
                
                if smtp_config.get('username') and smtp_config.get('password'):
                    server.login(smtp_config['username'], smtp_config['password'])
                
                server.send_message(msg)
            
            logger.info(f"メール通知送信完了: {alert.title}")
            
        except Exception as e:
            logger.error(f"メール通知エラー: {e}")
    
    async def _send_webhook_notification(self, alert: Alert):
        """Webhook通知送信"""
        
        try:
            import aiohttp
            
            webhook_config = self.notification_config.get('webhook', {})
            
            if not webhook_config or not webhook_config.get('url'):
                return
            
            payload = {
                "alert_id": alert.alert_id,
                "severity": alert.severity.value,
                "title": alert.title,
                "description": alert.description,
                "component": alert.component,
                "timestamp": alert.timestamp.isoformat(),
                "metadata": alert.metadata
            }
            
            headers = webhook_config.get('headers', {})
            headers['Content-Type'] = 'application/json'
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    webhook_config['url'],
                    json=payload,
                    headers=headers,
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as response:
                    if response.status == 200:
                        logger.info(f"Webhook通知送信完了: {alert.title}")
                    else:
                        logger.warning(f"Webhook通知失敗: {response.status}")
            
        except Exception as e:
            logger.error(f"Webhook通知エラー: {e}")
    
    async def _measure_api_response_time(self) -> float:
        """API レスポンス時間測定"""
        
        try:
            import aiohttp
            
            start_time = time.time()
            
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=5)) as session:
                async with session.get('http://localhost:8000/health') as response:
                    await response.text()
            
            return (time.time() - start_time) * 1000
            
        except Exception:
            return 0.0
    
    async def _get_request_count(self) -> int:
        """リクエスト数取得"""
        # 実際の実装ではメトリクスストアから取得
        return len(self.metrics_history)
    
    async def _get_error_count(self) -> int:
        """エラー数取得"""
        # 実際の実装ではエラーログから取得
        return len([alert for alert in self.alerts if alert.severity in [AlertSeverity.ERROR, AlertSeverity.CRITICAL]])
    
    async def _get_database_connections(self) -> int:
        """データベース接続数取得"""
        # 実際の実装では SQLAlchemy プールから取得
        return 5  # プレースホルダー
    
    async def _cleanup_metrics_history(self):
        """メトリクス履歴クリーンアップ"""
        
        cutoff_time = datetime.utcnow() - timedelta(hours=self.metrics_retention_hours)
        
        original_count = len(self.metrics_history)
        self.metrics_history = [
            metrics for metrics in self.metrics_history
            if metrics.timestamp > cutoff_time
        ]
        
        cleaned_count = original_count - len(self.metrics_history)
        if cleaned_count > 0:
            logger.debug(f"メトリクス履歴クリーンアップ: {cleaned_count}件削除")
    
    async def get_monitoring_dashboard(self) -> Dict[str, Any]:
        """監視ダッシュボードデータ取得"""
        
        # 最新メトリクス
        latest_metrics = self.metrics_history[-1] if self.metrics_history else None
        
        # アクティブアラート
        active_alerts = [alert for alert in self.alerts if not alert.resolved]
        
        # アラート統計
        alert_by_severity = {}
        alert_by_component = {}
        
        for alert in active_alerts:
            alert_by_severity[alert.severity.value] = alert_by_severity.get(alert.severity.value, 0) + 1
            alert_by_component[alert.component] = alert_by_component.get(alert.component, 0) + 1
        
        # システム全体ステータス
        overall_status = MonitoringStatus.HEALTHY
        
        if any(alert.severity == AlertSeverity.CRITICAL for alert in active_alerts):
            overall_status = MonitoringStatus.DOWN
        elif any(alert.severity == AlertSeverity.ERROR for alert in active_alerts):
            overall_status = MonitoringStatus.DEGRADED
        elif any(alert.severity == AlertSeverity.WARNING for alert in active_alerts):
            overall_status = MonitoringStatus.WARNING
        
        # パフォーマンス統計
        performance_stats = {}
        if self.metrics_history:
            recent_metrics = self.metrics_history[-60:]  # 最新30分（30秒間隔の場合）
            
            performance_stats = {
                "avg_cpu_percent": sum(m.cpu_percent for m in recent_metrics) / len(recent_metrics),
                "avg_memory_percent": sum(m.memory_percent for m in recent_metrics) / len(recent_metrics),
                "avg_response_time_ms": sum(m.response_time_ms for m in recent_metrics) / len(recent_metrics),
                "total_requests": sum(m.request_count for m in recent_metrics),
                "total_errors": sum(m.error_count for m in recent_metrics)
            }
        
        return {
            "monitoring_status": {
                "is_active": self.is_monitoring,
                "overall_status": overall_status.value,
                "last_check": datetime.utcnow().isoformat()
            },
            "current_metrics": asdict(latest_metrics) if latest_metrics else None,
            "health_checks": {
                component: asdict(health_check)
                for component, health_check in self.health_checks.items()
            },
            "active_alerts": {
                "total": len(active_alerts),
                "by_severity": alert_by_severity,
                "by_component": alert_by_component,
                "recent_alerts": [
                    asdict(alert) for alert in 
                    sorted(active_alerts, key=lambda a: a.timestamp, reverse=True)[:10]
                ]
            },
            "performance_statistics": performance_stats,
            "system_resources": {
                "cpu_threshold": self.alert_thresholds['cpu_percent'],
                "memory_threshold": self.alert_thresholds['memory_percent'],
                "disk_threshold": self.alert_thresholds['disk_percent'],
                "response_time_threshold": self.alert_thresholds['response_time_ms']
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    async def resolve_alert(self, alert_id: str, resolution_note: str = ""):
        """アラート解決"""
        
        for alert in self.alerts:
            if alert.alert_id == alert_id and not alert.resolved:
                alert.resolved = True
                alert.resolved_at = datetime.utcnow()
                
                if resolution_note:
                    alert.metadata = alert.metadata or {}
                    alert.metadata['resolution_note'] = resolution_note
                
                logger.info(f"アラート解決: {alert.title} ({alert_id})")
                return True
        
        return False
    
    async def export_metrics(self, hours: int = 24) -> str:
        """メトリクスエクスポート"""
        
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        recent_metrics = [
            metrics for metrics in self.metrics_history
            if metrics.timestamp > cutoff_time
        ]
        
        export_data = {
            "export_info": {
                "period_hours": hours,
                "metric_count": len(recent_metrics),
                "export_timestamp": datetime.utcnow().isoformat()
            },
            "metrics": [asdict(metrics) for metrics in recent_metrics],
            "alerts": [asdict(alert) for alert in self.alerts if alert.timestamp > cutoff_time],
            "health_checks": {
                component: asdict(health_check)
                for component, health_check in self.health_checks.items()
            }
        }
        
        # JSONファイルとして保存
        filename = f"monitoring_export_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
        filepath = f"logs/{filename}"
        
        async with aiofiles.open(filepath, 'w', encoding='utf-8') as f:
            await f.write(json.dumps(export_data, ensure_ascii=False, indent=2, default=str))
        
        logger.info(f"監視データエクスポート完了: {filepath}")
        return filepath