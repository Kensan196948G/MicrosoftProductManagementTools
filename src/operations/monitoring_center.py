#!/usr/bin/env python3
"""
24/7 Operations Monitoring Center - Phase 5 Enterprise Stability
SLA 99.9% Availability & Incident Response Automation
"""

import asyncio
import logging
import time
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable, Union
from dataclasses import dataclass, field
from enum import Enum
import threading
from pathlib import Path
import uuid
import smtplib
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart

# Monitoring & Alerting
import psutil
import httpx
import redis.asyncio as redis
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import text

# Microsoft Teams Notifications
try:
    import pymsteams
except ImportError:
    pymsteams = None

from src.core.config import get_settings
from src.monitoring.health_checks import HealthCheckManager, HealthStatus
from src.monitoring.azure_monitor_integration import AzureMonitorIntegration

logger = logging.getLogger(__name__)


class SeverityLevel(str, Enum):
    """アラート重要度レベル"""
    CRITICAL = "critical"    # システム停止・重大障害
    HIGH = "high"           # サービス影響あり
    MEDIUM = "medium"       # 警告レベル
    LOW = "low"             # 情報レベル
    INFO = "info"           # 通知のみ


class IncidentStatus(str, Enum):
    """インシデント状態"""
    OPEN = "open"           # 対応中
    INVESTIGATING = "investigating"  # 調査中
    RESOLVING = "resolving"  # 解決中
    RESOLVED = "resolved"    # 解決済み
    CLOSED = "closed"       # 完了


@dataclass
class SLAMetrics:
    """SLA指標"""
    availability_target: float = 99.9  # 99.9% SLA
    response_time_target_ms: float = 500.0  # 500ms応答目標
    error_rate_target: float = 0.1  # 0.1%エラー率
    
    # 現在の指標
    current_availability: float = 0.0
    current_response_time_ms: float = 0.0
    current_error_rate: float = 0.0
    
    # 月間累計
    monthly_uptime_seconds: int = 0
    monthly_downtime_seconds: int = 0
    monthly_total_requests: int = 0
    monthly_failed_requests: int = 0


@dataclass
class AlertRule:
    """アラートルール"""
    name: str
    description: str
    condition: Callable[[Dict[str, Any]], bool]
    severity: SeverityLevel
    cooldown_minutes: int = 15  # アラート抑制時間
    escalation_minutes: int = 30  # エスカレーション時間
    auto_resolve: bool = True
    
    # 状態管理
    last_triggered: Optional[datetime] = None
    last_resolved: Optional[datetime] = None
    trigger_count: int = 0
    is_suppressed: bool = False


@dataclass
class Incident:
    """インシデント"""
    id: str
    title: str
    description: str
    severity: SeverityLevel
    status: IncidentStatus
    created_at: datetime
    updated_at: datetime
    assigned_to: Optional[str] = None
    resolution_notes: Optional[str] = None
    
    # タイムライン
    events: List[Dict[str, Any]] = field(default_factory=list)
    
    # SLA計算
    response_time_minutes: Optional[float] = None
    resolution_time_minutes: Optional[float] = None


class OperationsMonitoringCenter:
    """24/7運用監視センター"""
    
    def __init__(self):
        self.settings = get_settings()
        
        # 監視コンポーネント
        self.health_manager = HealthCheckManager()
        self.azure_monitor = None
        
        # SLA管理
        self.sla_metrics = SLAMetrics()
        self.sla_start_time = datetime.utcnow()
        
        # アラート管理
        self.alert_rules: Dict[str, AlertRule] = {}
        self.active_alerts: Dict[str, Dict[str, Any]] = {}
        self.alert_history: List[Dict[str, Any]] = []
        
        # インシデント管理
        self.incidents: Dict[str, Incident] = {}
        self.incident_history: List[Incident] = []
        
        # 自動復旧
        self.recovery_actions: Dict[str, Callable] = {}
        self.recovery_history: List[Dict[str, Any]] = []
        
        # 通知システム
        self.notification_channels: Dict[str, Any] = {}
        
        # 運用状態
        self.is_monitoring = False
        self.monitoring_task: Optional[asyncio.Task] = None
        
        # 統計情報
        self.stats = {
            "monitoring_start_time": None,
            "total_checks_performed": 0,
            "total_alerts_triggered": 0,
            "total_incidents_created": 0,
            "total_auto_recoveries": 0,
            "last_check_timestamp": None
        }
        
        logger.info("Operations Monitoring Center initialized")
    
    async def initialize(self):
        """監視センター初期化"""
        try:
            # ヘルスチェックマネージャー初期化
            await self.health_manager.initialize()
            
            # Azure Monitor初期化（利用可能な場合）
            if hasattr(self.settings, 'AZURE_MONITOR_CONNECTION_STRING'):
                try:
                    from src.monitoring.azure_monitor_integration import MonitoringConfig
                    config = MonitoringConfig(
                        connection_string=self.settings.AZURE_MONITOR_CONNECTION_STRING,
                        workspace_id=getattr(self.settings, 'LOG_ANALYTICS_WORKSPACE_ID', ''),
                        health_check_interval=30
                    )
                    self.azure_monitor = AzureMonitorIntegration(config)
                    logger.info("Azure Monitor integration enabled")
                except Exception as e:
                    logger.warning(f"Azure Monitor initialization failed: {e}")
            
            # デフォルトアラートルール設定
            await self._setup_default_alert_rules()
            
            # デフォルト復旧アクション設定
            await self._setup_default_recovery_actions()
            
            # 通知チャネル設定
            await self._setup_notification_channels()
            
            # SLA監視開始
            self.sla_start_time = datetime.utcnow()
            self.stats["monitoring_start_time"] = self.sla_start_time
            
            logger.info("Operations Monitoring Center initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Operations Monitoring Center: {e}")
            raise
    
    async def start_monitoring(self):
        """24/7監視開始"""
        if self.is_monitoring:
            logger.warning("Monitoring is already running")
            return
        
        self.is_monitoring = True
        self.monitoring_task = asyncio.create_task(self._monitoring_loop())
        
        # 開始通知
        await self._send_notification(
            severity=SeverityLevel.INFO,
            title="24/7 Monitoring Started",
            message="Operations Monitoring Center has started 24/7 monitoring",
            details={"start_time": datetime.utcnow().isoformat()}
        )
        
        logger.info("24/7 Operations monitoring started")
    
    async def stop_monitoring(self):
        """監視停止"""
        if not self.is_monitoring:
            return
        
        self.is_monitoring = False
        
        if self.monitoring_task:
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass
        
        # 停止通知
        await self._send_notification(
            severity=SeverityLevel.INFO,
            title="Monitoring Stopped",
            message="Operations Monitoring Center monitoring has been stopped",
            details={"stop_time": datetime.utcnow().isoformat()}
        )
        
        logger.info("Operations monitoring stopped")
    
    async def _monitoring_loop(self):
        """メイン監視ループ"""
        logger.info("Starting 24/7 monitoring loop")
        
        while self.is_monitoring:
            try:
                start_time = time.time()
                
                # 1. ヘルスチェック実行
                health_results = await self.health_manager.check_all()
                
                # 2. SLA指標更新
                await self._update_sla_metrics(health_results)
                
                # 3. アラート評価
                await self._evaluate_alerts(health_results)
                
                # 4. インシデント管理
                await self._manage_incidents()
                
                # 5. 自動復旧チェック
                await self._check_auto_recovery(health_results)
                
                # 6. 統計更新
                self.stats["total_checks_performed"] += 1
                self.stats["last_check_timestamp"] = datetime.utcnow()
                
                # 7. パフォーマンス測定
                check_duration = time.time() - start_time
                if check_duration > 5.0:  # 5秒以上かかった場合は警告
                    logger.warning(f"Monitoring check took {check_duration:.2f} seconds")
                
                # 8. 次回チェックまで待機（30秒間隔）
                await asyncio.sleep(30)
                
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                await asyncio.sleep(60)  # エラー時は1分待機
    
    async def _update_sla_metrics(self, health_results: Dict[str, Any]):
        """SLA指標更新"""
        try:
            current_time = datetime.utcnow()
            
            # 可用性計算
            if health_results.get("status") == "healthy":
                # システム正常
                availability = 100.0
            elif health_results.get("status") == "warning":
                # 部分的な問題
                availability = 95.0
            else:
                # 重大な問題
                availability = 0.0
            
            self.sla_metrics.current_availability = availability
            
            # 応答時間（ヘルスチェック実行時間から推定）
            response_times = []
            for service, details in health_results.get("details", {}).items():
                if isinstance(details, dict) and "duration_ms" in details:
                    response_times.append(details["duration_ms"])
            
            if response_times:
                self.sla_metrics.current_response_time_ms = sum(response_times) / len(response_times)
            
            # エラー率計算
            total_services = len(health_results.get("details", {}))
            failed_services = health_results.get("summary", {}).get("critical", 0)
            
            if total_services > 0:
                self.sla_metrics.current_error_rate = (failed_services / total_services) * 100
            
            # 月間累計更新
            elapsed_seconds = (current_time - self.sla_start_time).total_seconds()
            if availability >= 99:
                # 99%以上なら稼働時間としてカウント
                self.sla_metrics.monthly_uptime_seconds = int(elapsed_seconds)
            else:
                # 99%未満なら停止時間としてカウント
                self.sla_metrics.monthly_downtime_seconds += 30  # チェック間隔
            
        except Exception as e:
            logger.error(f"Error updating SLA metrics: {e}")
    
    async def _evaluate_alerts(self, health_results: Dict[str, Any]):
        """アラート評価"""
        try:
            current_time = datetime.utcnow()
            
            for rule_name, rule in self.alert_rules.items():
                try:
                    # クールダウン期間チェック
                    if (rule.last_triggered and 
                        (current_time - rule.last_triggered).total_seconds() < rule.cooldown_minutes * 60):
                        continue
                    
                    # 条件評価
                    triggered = rule.condition(health_results)
                    
                    if triggered and rule_name not in self.active_alerts:
                        # 新規アラート
                        await self._trigger_alert(rule_name, rule, health_results)
                        
                    elif not triggered and rule_name in self.active_alerts:
                        # アラート解決
                        if rule.auto_resolve:
                            await self._resolve_alert(rule_name, rule)
                            
                except Exception as e:
                    logger.error(f"Error evaluating alert rule '{rule_name}': {e}")
                    
        except Exception as e:
            logger.error(f"Error in alert evaluation: {e}")
    
    async def _trigger_alert(self, rule_name: str, rule: AlertRule, context: Dict[str, Any]):
        """アラート発火"""
        try:
            alert_id = str(uuid.uuid4())
            alert_time = datetime.utcnow()
            
            alert = {
                "id": alert_id,
                "rule_name": rule_name,
                "severity": rule.severity.value,
                "title": f"Alert: {rule.name}",
                "description": rule.description,
                "triggered_at": alert_time,
                "context": context,
                "escalated": False
            }
            
            self.active_alerts[rule_name] = alert
            self.alert_history.append(alert.copy())
            
            # ルール更新
            rule.last_triggered = alert_time
            rule.trigger_count += 1
            
            # 統計更新
            self.stats["total_alerts_triggered"] += 1
            
            # インシデント作成（CRITICALまたはHIGHの場合）
            if rule.severity in [SeverityLevel.CRITICAL, SeverityLevel.HIGH]:
                incident_id = await self._create_incident(
                    title=f"Incident: {rule.name}",
                    description=rule.description,
                    severity=rule.severity,
                    alert_id=alert_id
                )
                alert["incident_id"] = incident_id
            
            # 通知送信
            await self._send_notification(
                severity=rule.severity,
                title=alert["title"],
                message=rule.description,
                details={"alert_id": alert_id, "context": context}
            )
            
            logger.warning(f"Alert triggered: {rule_name} ({rule.severity.value})")
            
        except Exception as e:
            logger.error(f"Error triggering alert '{rule_name}': {e}")
    
    async def _resolve_alert(self, rule_name: str, rule: AlertRule):
        """アラート解決"""
        try:
            if rule_name in self.active_alerts:
                alert = self.active_alerts[rule_name]
                resolve_time = datetime.utcnow()
                
                alert["resolved_at"] = resolve_time
                alert["duration_minutes"] = (resolve_time - alert["triggered_at"]).total_seconds() / 60
                
                # アクティブアラートから削除
                del self.active_alerts[rule_name]
                
                # ルール更新
                rule.last_resolved = resolve_time
                
                # インシデント自動解決
                if "incident_id" in alert:
                    await self._resolve_incident(
                        alert["incident_id"],
                        "Auto-resolved when alert condition cleared"
                    )
                
                # 通知送信
                await self._send_notification(
                    severity=SeverityLevel.INFO,
                    title=f"Alert Resolved: {rule.name}",
                    message=f"Alert {rule_name} has been automatically resolved",
                    details={"alert_id": alert["id"], "duration_minutes": alert["duration_minutes"]}
                )
                
                logger.info(f"Alert resolved: {rule_name}")
                
        except Exception as e:
            logger.error(f"Error resolving alert '{rule_name}': {e}")
    
    async def _create_incident(self, title: str, description: str, 
                             severity: SeverityLevel, alert_id: str = None) -> str:
        """インシデント作成"""
        try:
            incident_id = str(uuid.uuid4())
            current_time = datetime.utcnow()
            
            incident = Incident(
                id=incident_id,
                title=title,
                description=description,
                severity=severity,
                status=IncidentStatus.OPEN,
                created_at=current_time,
                updated_at=current_time,
                events=[{
                    "timestamp": current_time.isoformat(),
                    "action": "incident_created",
                    "details": {"alert_id": alert_id} if alert_id else {}
                }]
            )
            
            self.incidents[incident_id] = incident
            self.incident_history.append(incident)
            
            # 統計更新
            self.stats["total_incidents_created"] += 1
            
            # 高重要度インシデントの場合、即座にエスカレーション
            if severity == SeverityLevel.CRITICAL:
                await self._escalate_incident(incident_id)
            
            logger.error(f"Incident created: {incident_id} - {title} ({severity.value})")
            return incident_id
            
        except Exception as e:
            logger.error(f"Error creating incident: {e}")
            return ""
    
    async def _resolve_incident(self, incident_id: str, resolution_notes: str):
        """インシデント解決"""
        try:
            if incident_id in self.incidents:
                incident = self.incidents[incident_id]
                resolve_time = datetime.utcnow()
                
                incident.status = IncidentStatus.RESOLVED
                incident.updated_at = resolve_time
                incident.resolution_notes = resolution_notes
                incident.resolution_time_minutes = (resolve_time - incident.created_at).total_seconds() / 60
                
                incident.events.append({
                    "timestamp": resolve_time.isoformat(),
                    "action": "incident_resolved",
                    "details": {"resolution_notes": resolution_notes}
                })
                
                logger.info(f"Incident resolved: {incident_id}")
                
        except Exception as e:
            logger.error(f"Error resolving incident '{incident_id}': {e}")
    
    async def _escalate_incident(self, incident_id: str):
        """インシデントエスカレーション"""
        try:
            if incident_id in self.incidents:
                incident = self.incidents[incident_id]
                
                # エスカレーション通知
                await self._send_notification(
                    severity=SeverityLevel.CRITICAL,
                    title=f"ESCALATED: {incident.title}",
                    message=f"Critical incident {incident_id} has been escalated for immediate attention",
                    details={
                        "incident_id": incident_id,
                        "severity": incident.severity.value,
                        "created_at": incident.created_at.isoformat()
                    }
                )
                
                incident.events.append({
                    "timestamp": datetime.utcnow().isoformat(),
                    "action": "incident_escalated",
                    "details": {}
                })
                
                logger.critical(f"Incident escalated: {incident_id}")
                
        except Exception as e:
            logger.error(f"Error escalating incident '{incident_id}': {e}")
    
    async def _check_auto_recovery(self, health_results: Dict[str, Any]):
        """自動復旧チェック"""
        try:
            # クリティカルなサービスの自動復旧
            for service_name, details in health_results.get("details", {}).items():
                if isinstance(details, dict) and details.get("status") == "critical":
                    if service_name in self.recovery_actions:
                        await self._execute_recovery_action(service_name, details)
                        
        except Exception as e:
            logger.error(f"Error in auto recovery check: {e}")
    
    async def _execute_recovery_action(self, service_name: str, error_details: Dict[str, Any]):
        """復旧アクション実行"""
        try:
            if service_name not in self.recovery_actions:
                return
            
            recovery_action = self.recovery_actions[service_name]
            recovery_id = str(uuid.uuid4())
            start_time = datetime.utcnow()
            
            logger.info(f"Executing auto recovery for {service_name}")
            
            try:
                # 復旧アクション実行
                if asyncio.iscoroutinefunction(recovery_action):
                    result = await recovery_action(error_details)
                else:
                    result = recovery_action(error_details)
                
                success = True
                
            except Exception as e:
                result = f"Recovery action failed: {str(e)}"
                success = False
            
            end_time = datetime.utcnow()
            duration = (end_time - start_time).total_seconds()
            
            # 復旧履歴記録
            recovery_record = {
                "id": recovery_id,
                "service": service_name,
                "started_at": start_time.isoformat(),
                "completed_at": end_time.isoformat(),
                "duration_seconds": duration,
                "success": success,
                "result": result,
                "error_details": error_details
            }
            
            self.recovery_history.append(recovery_record)
            self.stats["total_auto_recoveries"] += 1
            
            # 通知送信
            severity = SeverityLevel.INFO if success else SeverityLevel.HIGH
            await self._send_notification(
                severity=severity,
                title=f"Auto Recovery {'Successful' if success else 'Failed'}: {service_name}",
                message=f"Auto recovery action for {service_name} {'completed successfully' if success else 'failed'}",
                details=recovery_record
            )
            
            logger.info(f"Auto recovery {'successful' if success else 'failed'} for {service_name}: {result}")
            
        except Exception as e:
            logger.error(f"Error executing recovery action for '{service_name}': {e}")
    
    async def _setup_default_alert_rules(self):
        """デフォルトアラートルール設定"""
        try:
            # システム可用性
            self.alert_rules["system_availability"] = AlertRule(
                name="System Availability",
                description="System availability below 99%",
                condition=lambda hr: hr.get("status") != "healthy",
                severity=SeverityLevel.CRITICAL,
                cooldown_minutes=5
            )
            
            # 応答時間
            self.alert_rules["response_time"] = AlertRule(
                name="High Response Time",
                description="Average response time above 1000ms",
                condition=lambda hr: self._check_response_time(hr, 1000),
                severity=SeverityLevel.HIGH,
                cooldown_minutes=10
            )
            
            # エラー率
            self.alert_rules["error_rate"] = AlertRule(
                name="High Error Rate",
                description="Error rate above 5%",
                condition=lambda hr: self._check_error_rate(hr, 5.0),
                severity=SeverityLevel.HIGH,
                cooldown_minutes=15
            )
            
            # リソース使用率
            self.alert_rules["resource_usage"] = AlertRule(
                name="High Resource Usage",
                description="CPU or Memory usage above 90%",
                condition=lambda hr: self._check_resource_usage(hr, 90),
                severity=SeverityLevel.MEDIUM,
                cooldown_minutes=20
            )
            
            logger.info("Default alert rules configured")
            
        except Exception as e:
            logger.error(f"Error setting up default alert rules: {e}")
    
    def _check_response_time(self, health_results: Dict[str, Any], threshold_ms: float) -> bool:
        """応答時間チェック"""
        try:
            total_time = 0
            count = 0
            
            for service, details in health_results.get("details", {}).items():
                if isinstance(details, dict) and "duration_ms" in details:
                    total_time += details["duration_ms"]
                    count += 1
            
            if count > 0:
                avg_time = total_time / count
                return avg_time > threshold_ms
            
            return False
            
        except Exception:
            return False
    
    def _check_error_rate(self, health_results: Dict[str, Any], threshold_percent: float) -> bool:
        """エラー率チェック"""
        try:
            summary = health_results.get("summary", {})
            total = summary.get("total", 0)
            critical = summary.get("critical", 0)
            
            if total > 0:
                error_rate = (critical / total) * 100
                return error_rate > threshold_percent
            
            return False
            
        except Exception:
            return False
    
    def _check_resource_usage(self, health_results: Dict[str, Any], threshold_percent: float) -> bool:
        """リソース使用率チェック"""
        try:
            for service, details in health_results.get("details", {}).items():
                if isinstance(details, dict) and "details" in details:
                    service_details = details["details"]
                    
                    # CPU使用率チェック
                    if "cpu_percent" in service_details:
                        if service_details["cpu_percent"] > threshold_percent:
                            return True
                    
                    # メモリ使用率チェック
                    if "memory_percent" in service_details:
                        if service_details["memory_percent"] > threshold_percent:
                            return True
            
            return False
            
        except Exception:
            return False
    
    async def _setup_default_recovery_actions(self):
        """デフォルト復旧アクション設定"""
        try:
            # システムリソース復旧
            self.recovery_actions["system_resources"] = self._recover_system_resources
            
            # ネットワーク接続復旧
            self.recovery_actions["network_connectivity"] = self._recover_network_connectivity
            
            # データベース復旧
            self.recovery_actions["database"] = self._recover_database
            
            # Redis復旧
            self.recovery_actions["redis"] = self._recover_redis
            
            logger.info("Default recovery actions configured")
            
        except Exception as e:
            logger.error(f"Error setting up default recovery actions: {e}")
    
    async def _recover_system_resources(self, error_details: Dict[str, Any]) -> str:
        """システムリソース復旧"""
        try:
            actions_taken = []
            
            # メモリクリーンアップ
            import gc
            gc.collect()
            actions_taken.append("Memory garbage collection")
            
            # 一時ファイルクリーンアップ
            try:
                import tempfile
                import shutil
                temp_dir = Path(tempfile.gettempdir())
                
                # 古い一時ファイル削除（24時間以上）
                cutoff_time = datetime.utcnow() - timedelta(hours=24)
                deleted_files = 0
                
                for file_path in temp_dir.iterdir():
                    if file_path.is_file():
                        file_time = datetime.fromtimestamp(file_path.stat().st_mtime)
                        if file_time < cutoff_time:
                            try:
                                file_path.unlink()
                                deleted_files += 1
                            except:
                                pass
                
                if deleted_files > 0:
                    actions_taken.append(f"Cleaned {deleted_files} temporary files")
                    
            except Exception as e:
                logger.warning(f"Temp file cleanup failed: {e}")
            
            return f"System recovery completed: {', '.join(actions_taken)}"
            
        except Exception as e:
            return f"System recovery failed: {str(e)}"
    
    async def _recover_network_connectivity(self, error_details: Dict[str, Any]) -> str:
        """ネットワーク接続復旧"""
        try:
            # DNS リフレッシュ（プラットフォーム依存）
            actions_taken = []
            
            # HTTP接続プールリセット
            try:
                import httpx
                # 新しいクライアントで接続テスト
                async with httpx.AsyncClient(timeout=10) as client:
                    response = await client.get("https://www.google.com")
                    if response.status_code == 200:
                        actions_taken.append("HTTP connectivity verified")
            except Exception as e:
                actions_taken.append(f"HTTP test failed: {str(e)}")
            
            return f"Network recovery attempted: {', '.join(actions_taken)}"
            
        except Exception as e:
            return f"Network recovery failed: {str(e)}"
    
    async def _recover_database(self, error_details: Dict[str, Any]) -> str:
        """データベース復旧"""
        try:
            if not hasattr(self.settings, 'DATABASE_URL'):
                return "Database URL not configured"
            
            # データベース接続再試行
            try:
                engine = create_async_engine(self.settings.DATABASE_URL)
                async with engine.begin() as conn:
                    result = await conn.execute(text("SELECT 1"))
                    test_result = result.scalar()
                await engine.dispose()
                
                if test_result == 1:
                    return "Database recovery successful - connection restored"
                else:
                    return "Database recovery failed - unexpected result"
                    
            except Exception as e:
                return f"Database recovery failed: {str(e)}"
                
        except Exception as e:
            return f"Database recovery error: {str(e)}"
    
    async def _recover_redis(self, error_details: Dict[str, Any]) -> str:
        """Redis復旧"""
        try:
            if not hasattr(self.settings, 'REDIS_URL'):
                return "Redis URL not configured"
            
            # Redis接続再試行
            try:
                client = redis.from_url(self.settings.REDIS_URL)
                await client.ping()
                await client.close()
                
                return "Redis recovery successful - connection restored"
                
            except Exception as e:
                return f"Redis recovery failed: {str(e)}"
                
        except Exception as e:
            return f"Redis recovery error: {str(e)}"
    
    async def _setup_notification_channels(self):
        """通知チャネル設定"""
        try:
            # メール通知設定
            if hasattr(self.settings, 'SMTP_HOST'):
                self.notification_channels["email"] = {
                    "enabled": True,
                    "smtp_host": self.settings.SMTP_HOST,
                    "smtp_port": getattr(self.settings, 'SMTP_PORT', 587),
                    "username": getattr(self.settings, 'SMTP_USERNAME', ''),
                    "password": getattr(self.settings, 'SMTP_PASSWORD', ''),
                    "from_email": getattr(self.settings, 'ALERT_FROM_EMAIL', 'alerts@company.com'),
                    "to_emails": getattr(self.settings, 'ALERT_TO_EMAILS', ['ops@company.com'])
                }
            
            # Microsoft Teams通知設定
            if hasattr(self.settings, 'TEAMS_WEBHOOK_URL') and pymsteams:
                self.notification_channels["teams"] = {
                    "enabled": True,
                    "webhook_url": self.settings.TEAMS_WEBHOOK_URL
                }
            
            # Slack通知設定（将来拡張用）
            if hasattr(self.settings, 'SLACK_WEBHOOK_URL'):
                self.notification_channels["slack"] = {
                    "enabled": True,
                    "webhook_url": self.settings.SLACK_WEBHOOK_URL
                }
            
            logger.info(f"Notification channels configured: {list(self.notification_channels.keys())}")
            
        except Exception as e:
            logger.error(f"Error setting up notification channels: {e}")
    
    async def _send_notification(self, severity: SeverityLevel, title: str, 
                               message: str, details: Dict[str, Any] = None):
        """通知送信"""
        try:
            notification_data = {
                "severity": severity.value,
                "title": title,
                "message": message,
                "timestamp": datetime.utcnow().isoformat(),
                "details": details or {},
                "source": "Operations Monitoring Center"
            }
            
            # メール通知
            if "email" in self.notification_channels and self.notification_channels["email"]["enabled"]:
                await self._send_email_notification(notification_data)
            
            # Teams通知
            if "teams" in self.notification_channels and self.notification_channels["teams"]["enabled"]:
                await self._send_teams_notification(notification_data)
            
            # ログ出力
            log_level = {
                SeverityLevel.CRITICAL: logger.critical,
                SeverityLevel.HIGH: logger.error,
                SeverityLevel.MEDIUM: logger.warning,
                SeverityLevel.LOW: logger.info,
                SeverityLevel.INFO: logger.info
            }[severity]
            
            log_level(f"NOTIFICATION [{severity.value.upper()}]: {title} - {message}")
            
        except Exception as e:
            logger.error(f"Error sending notification: {e}")
    
    async def _send_email_notification(self, notification_data: Dict[str, Any]):
        """メール通知送信"""
        try:
            email_config = self.notification_channels["email"]
            
            # メール作成
            msg = MimeMultipart()
            msg['From'] = email_config["from_email"]
            msg['To'] = ", ".join(email_config["to_emails"])
            msg['Subject'] = f"[{notification_data['severity'].upper()}] {notification_data['title']}"
            
            # メール本文
            body = f"""
Operations Alert Notification

Severity: {notification_data['severity'].upper()}
Title: {notification_data['title']}
Time: {notification_data['timestamp']}

Message:
{notification_data['message']}

Details:
{json.dumps(notification_data['details'], indent=2)}

---
Microsoft 365 Management Tools - Operations Monitoring Center
            """.strip()
            
            msg.attach(MimeText(body, 'plain'))
            
            # SMTP送信
            if email_config.get("username") and email_config.get("password"):
                server = smtplib.SMTP(email_config["smtp_host"], email_config["smtp_port"])
                server.starttls()
                server.login(email_config["username"], email_config["password"])
                server.send_message(msg)
                server.quit()
                
                logger.debug("Email notification sent successfully")
            else:
                logger.warning("Email credentials not configured")
                
        except Exception as e:
            logger.error(f"Error sending email notification: {e}")
    
    async def _send_teams_notification(self, notification_data: Dict[str, Any]):
        """Teams通知送信"""
        try:
            if not pymsteams:
                logger.warning("pymsteams not available for Teams notifications")
                return
            
            teams_config = self.notification_channels["teams"]
            
            # Teams messageカード作成
            teams_message = pymsteams.connectorcard(teams_config["webhook_url"])
            
            # 重要度に応じた色設定
            color_map = {
                SeverityLevel.CRITICAL: "FF0000",  # 赤
                SeverityLevel.HIGH: "FFA500",      # オレンジ
                SeverityLevel.MEDIUM: "FFFF00",    # 黄
                SeverityLevel.LOW: "00FF00",       # 緑
                SeverityLevel.INFO: "0000FF"       # 青
            }
            
            teams_message.color(color_map.get(SeverityLevel(notification_data['severity']), "808080"))
            teams_message.title(notification_data['title'])
            teams_message.text(notification_data['message'])
            
            # 詳細情報セクション
            details_section = pymsteams.cardsection()
            details_section.activityTitle("Alert Details")
            details_section.activitySubtitle(f"Severity: {notification_data['severity'].upper()}")
            details_section.activityText(f"Time: {notification_data['timestamp']}")
            
            teams_message.addSection(details_section)
            
            # 送信
            teams_message.send()
            
            logger.debug("Teams notification sent successfully")
            
        except Exception as e:
            logger.error(f"Error sending Teams notification: {e}")
    
    async def get_operations_status(self) -> Dict[str, Any]:
        """運用状況取得"""
        try:
            current_time = datetime.utcnow()
            uptime_seconds = (current_time - self.stats["monitoring_start_time"]).total_seconds() if self.stats["monitoring_start_time"] else 0
            
            # SLA計算
            total_seconds = max(uptime_seconds, 1)  # ゼロ除算回避
            availability_percentage = ((total_seconds - self.sla_metrics.monthly_downtime_seconds) / total_seconds) * 100
            
            return {
                "monitoring_status": "active" if self.is_monitoring else "stopped",
                "uptime_hours": uptime_seconds / 3600,
                "sla_metrics": {
                    "availability_percentage": round(availability_percentage, 3),
                    "target_availability": self.sla_metrics.availability_target,
                    "current_response_time_ms": self.sla_metrics.current_response_time_ms,
                    "target_response_time_ms": self.sla_metrics.response_time_target_ms,
                    "current_error_rate": self.sla_metrics.current_error_rate,
                    "target_error_rate": self.sla_metrics.error_rate_target,
                    "monthly_downtime_minutes": self.sla_metrics.monthly_downtime_seconds / 60
                },
                "alerts": {
                    "active_count": len(self.active_alerts),
                    "total_triggered": self.stats["total_alerts_triggered"],
                    "active_alerts": list(self.active_alerts.keys())
                },
                "incidents": {
                    "open_count": len([i for i in self.incidents.values() if i.status in [IncidentStatus.OPEN, IncidentStatus.INVESTIGATING]]),
                    "total_created": self.stats["total_incidents_created"],
                    "open_incidents": [i.id for i in self.incidents.values() if i.status in [IncidentStatus.OPEN, IncidentStatus.INVESTIGATING]]
                },
                "auto_recovery": {
                    "total_executions": self.stats["total_auto_recoveries"],
                    "recent_recoveries": self.recovery_history[-5:]  # 最新5件
                },
                "statistics": {
                    "total_health_checks": self.stats["total_checks_performed"],
                    "last_check": self.stats["last_check_timestamp"].isoformat() if self.stats["last_check_timestamp"] else None,
                    "notification_channels": list(self.notification_channels.keys())
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting operations status: {e}")
            return {"error": str(e)}
    
    async def close(self):
        """監視センター終了"""
        try:
            await self.stop_monitoring()
            
            if self.health_manager:
                await self.health_manager.close()
            
            if self.azure_monitor:
                self.azure_monitor.close()
            
            logger.info("Operations Monitoring Center closed")
            
        except Exception as e:
            logger.error(f"Error closing Operations Monitoring Center: {e}")


# グローバルインスタンス
operations_center = OperationsMonitoringCenter()


if __name__ == "__main__":
    # テスト実行
    async def test_operations_center():
        """運用監視センターテスト"""
        print("Testing Operations Monitoring Center...")
        
        center = OperationsMonitoringCenter()
        
        try:
            await center.initialize()
            await center.start_monitoring()
            
            # 10秒間監視実行
            await asyncio.sleep(10)
            
            # 状況確認
            status = await center.get_operations_status()
            print(f"Operations Status: {json.dumps(status, indent=2, default=str)}")
            
        finally:
            await center.close()
        
        print("Operations test completed")
    
    asyncio.run(test_operations_center())