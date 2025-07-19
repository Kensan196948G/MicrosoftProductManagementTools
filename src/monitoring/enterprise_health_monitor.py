#!/usr/bin/env python3
"""
Enterprise Health Monitor - Phase 5 Critical Priority
24/7運用監視体制 - SLA 99.9%可用性維持

Features:
- Real-time system health monitoring
- Automatic incident detection and response
- SLA compliance tracking (99.9% uptime)
- Performance metrics collection
- Alert escalation management
- Disaster recovery automation

Author: Frontend Developer (dev0) - Phase 5 Emergency Response
Version: 5.0.0 CRITICAL
Date: 2025-07-19
"""

import asyncio
import logging
import json
import time
import psutil
import smtplib
import subprocess
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import threading
from pathlib import Path
import sqlite3
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart

try:
    import requests
    from PyQt6.QtCore import QObject, QTimer, pyqtSignal
    import websockets
except ImportError as e:
    print(f"⚠️ Optional dependencies not available: {e}")

# Configure logging for 24/7 operations
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/microsoft365-monitor.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class HealthStatus(Enum):
    """System health status levels"""
    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"
    DOWN = "down"
    MAINTENANCE = "maintenance"


class AlertLevel(Enum):
    """Alert escalation levels"""
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"
    EMERGENCY = "emergency"


@dataclass
class HealthMetric:
    """Health monitoring metric"""
    name: str
    value: float
    unit: str
    threshold_warning: float
    threshold_critical: float
    status: HealthStatus = HealthStatus.HEALTHY
    timestamp: datetime = field(default_factory=datetime.utcnow)
    description: str = ""
    
    def evaluate_status(self) -> HealthStatus:
        """Evaluate metric status based on thresholds"""
        if self.value >= self.threshold_critical:
            self.status = HealthStatus.CRITICAL
        elif self.value >= self.threshold_warning:
            self.status = HealthStatus.WARNING
        else:
            self.status = HealthStatus.HEALTHY
        
        return self.status


@dataclass
class Incident:
    """System incident record"""
    id: str
    title: str
    description: str
    severity: AlertLevel
    status: str = "open"
    created_at: datetime = field(default_factory=datetime.utcnow)
    resolved_at: Optional[datetime] = None
    assigned_to: Optional[str] = None
    resolution_notes: str = ""
    affected_services: List[str] = field(default_factory=list)
    
    @property
    def duration(self) -> Optional[timedelta]:
        """Calculate incident duration"""
        if self.resolved_at:
            return self.resolved_at - self.created_at
        return datetime.utcnow() - self.created_at


class SLATracker:
    """SLA (Service Level Agreement) tracking for 99.9% uptime"""
    
    def __init__(self, target_availability: float = 99.9):
        self.target_availability = target_availability
        self.uptime_records: List[Dict] = []
        self.downtime_incidents: List[Incident] = []
        
    def record_uptime(self, service: str, is_available: bool):
        """Record service uptime status"""
        record = {
            "service": service,
            "timestamp": datetime.utcnow(),
            "is_available": is_available
        }
        self.uptime_records.append(record)
        
        # Keep only last 30 days of records
        cutoff = datetime.utcnow() - timedelta(days=30)
        self.uptime_records = [
            r for r in self.uptime_records 
            if r["timestamp"] > cutoff
        ]
    
    def calculate_availability(self, service: str = None, period_days: int = 30) -> float:
        """Calculate availability percentage"""
        cutoff = datetime.utcnow() - timedelta(days=period_days)
        
        if service:
            records = [r for r in self.uptime_records 
                      if r["service"] == service and r["timestamp"] > cutoff]
        else:
            records = [r for r in self.uptime_records if r["timestamp"] > cutoff]
        
        if not records:
            return 100.0
        
        available_count = sum(1 for r in records if r["is_available"])
        return (available_count / len(records)) * 100.0
    
    def is_sla_compliant(self, service: str = None) -> bool:
        """Check if SLA target is being met"""
        availability = self.calculate_availability(service)
        return availability >= self.target_availability
    
    def get_sla_status(self) -> Dict[str, Any]:
        """Get comprehensive SLA status"""
        overall_availability = self.calculate_availability()
        
        services = set(r["service"] for r in self.uptime_records)
        service_availability = {
            service: self.calculate_availability(service)
            for service in services
        }
        
        return {
            "overall_availability": overall_availability,
            "service_availability": service_availability,
            "sla_compliant": overall_availability >= self.target_availability,
            "target": self.target_availability,
            "active_incidents": len([i for i in self.downtime_incidents if i.status == "open"])
        }


class AutoRecoverySystem:
    """Automatic incident response and recovery"""
    
    def __init__(self):
        self.recovery_procedures: Dict[str, Callable] = {}
        self.recovery_history: List[Dict] = []
        
    def register_recovery_procedure(self, incident_type: str, procedure: Callable):
        """Register automatic recovery procedure"""
        self.recovery_procedures[incident_type] = procedure
        logger.info(f"Registered recovery procedure for: {incident_type}")
    
    async def attempt_recovery(self, incident: Incident) -> bool:
        """Attempt automatic recovery"""
        incident_type = incident.title.lower()
        
        # Find matching recovery procedure
        for registered_type, procedure in self.recovery_procedures.items():
            if registered_type in incident_type:
                logger.info(f"Attempting automatic recovery for: {incident.title}")
                
                try:
                    success = await procedure(incident)
                    
                    self.recovery_history.append({
                        "incident_id": incident.id,
                        "recovery_type": registered_type,
                        "success": success,
                        "timestamp": datetime.utcnow()
                    })
                    
                    if success:
                        logger.info(f"Automatic recovery successful: {incident.title}")
                        incident.status = "auto_resolved"
                        incident.resolved_at = datetime.utcnow()
                        incident.resolution_notes = f"Auto-recovered using {registered_type} procedure"
                    
                    return success
                    
                except Exception as e:
                    logger.error(f"Recovery procedure failed: {e}")
                    return False
        
        logger.warning(f"No recovery procedure found for: {incident.title}")
        return False


class AlertManager:
    """Alert escalation and notification management"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.alert_history: List[Dict] = []
        self.escalation_rules = {
            AlertLevel.INFO: [],
            AlertLevel.WARNING: ["frontend_dev"],
            AlertLevel.ERROR: ["frontend_dev", "backend_dev"],
            AlertLevel.CRITICAL: ["frontend_dev", "backend_dev", "tech_manager"],
            AlertLevel.EMERGENCY: ["frontend_dev", "backend_dev", "tech_manager", "ceo"]
        }
    
    async def send_alert(self, level: AlertLevel, title: str, message: str, 
                        details: Dict[str, Any] = None):
        """Send alert based on escalation rules"""
        recipients = self.escalation_rules.get(level, [])
        
        alert = {
            "level": level.value,
            "title": title,
            "message": message,
            "details": details or {},
            "timestamp": datetime.utcnow(),
            "recipients": recipients
        }
        
        self.alert_history.append(alert)
        
        # Send notifications
        for recipient in recipients:
            await self._send_notification(recipient, alert)
        
        logger.info(f"Alert sent - Level: {level.value}, Title: {title}")
    
    async def _send_notification(self, recipient: str, alert: Dict):
        """Send notification to specific recipient"""
        try:
            # Email notification
            if "email" in self.config.get("notifications", {}):
                await self._send_email(recipient, alert)
            
            # Slack notification (if configured)
            if "slack" in self.config.get("notifications", {}):
                await self._send_slack(recipient, alert)
            
            # SMS for critical alerts (if configured)
            if alert["level"] in ["critical", "emergency"] and "sms" in self.config.get("notifications", {}):
                await self._send_sms(recipient, alert)
                
        except Exception as e:
            logger.error(f"Failed to send notification to {recipient}: {e}")
    
    async def _send_email(self, recipient: str, alert: Dict):
        """Send email notification"""
        email_config = self.config.get("notifications", {}).get("email", {})
        if not email_config:
            return
        
        try:
            msg = MimeMultipart()
            msg['From'] = email_config['from']
            msg['To'] = email_config['recipients'].get(recipient, recipient)
            msg['Subject'] = f"[{alert['level'].upper()}] {alert['title']}"
            
            body = f"""
Microsoft 365 Management Tools - Alert Notification

Level: {alert['level'].upper()}
Title: {alert['title']}
Time: {alert['timestamp']}

Message:
{alert['message']}

Details:
{json.dumps(alert['details'], indent=2)}

---
Automated alert from Enterprise Health Monitor
"""
            
            msg.attach(MimeText(body, 'plain'))
            
            with smtplib.SMTP(email_config['smtp_server'], email_config['smtp_port']) as server:
                if email_config.get('use_tls'):
                    server.starttls()
                if email_config.get('username'):
                    server.login(email_config['username'], email_config['password'])
                
                server.send_message(msg)
            
            logger.info(f"Email sent to {recipient}")
            
        except Exception as e:
            logger.error(f"Email send failed: {e}")
    
    async def _send_slack(self, recipient: str, alert: Dict):
        """Send Slack notification"""
        # Placeholder for Slack integration
        logger.info(f"Slack notification would be sent to {recipient}")
    
    async def _send_sms(self, recipient: str, alert: Dict):
        """Send SMS notification for critical alerts"""
        # Placeholder for SMS integration
        logger.info(f"SMS notification would be sent to {recipient}")


class EnterpriseHealthMonitor:
    """
    Enterprise-grade health monitoring system
    24/7 operations with 99.9% SLA compliance
    """
    
    def __init__(self, config_path: str = "config/monitoring.json"):
        self.config = self._load_config(config_path)
        self.metrics: Dict[str, HealthMetric] = {}
        self.incidents: List[Incident] = []
        self.sla_tracker = SLATracker()
        self.auto_recovery = AutoRecoverySystem()
        self.alert_manager = AlertManager(self.config)
        
        # Database for persistence
        self.db_path = self.config.get("database", {}).get("path", "monitoring.db")
        self._init_database()
        
        # Monitoring state
        self.is_monitoring = False
        self.monitor_interval = self.config.get("monitor_interval", 30)  # seconds
        
        # Performance tracking
        self.performance_baseline = {}
        self.performance_trends = {}
        
        # Setup default recovery procedures
        self._setup_recovery_procedures()
        
        logger.info("Enterprise Health Monitor initialized")
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load monitoring configuration"""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"Config file not found: {config_path}, using defaults")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Default monitoring configuration"""
        return {
            "monitor_interval": 30,
            "thresholds": {
                "cpu_warning": 70.0,
                "cpu_critical": 90.0,
                "memory_warning": 80.0,
                "memory_critical": 95.0,
                "disk_warning": 85.0,
                "disk_critical": 95.0,
                "response_time_warning": 3.0,
                "response_time_critical": 10.0
            },
            "services": [
                "microsoft365_gui",
                "websocket_server",
                "api_gateway",
                "database"
            ],
            "notifications": {
                "email": {
                    "enabled": True,
                    "smtp_server": "localhost",
                    "smtp_port": 587,
                    "recipients": {
                        "frontend_dev": "dev0@company.com",
                        "backend_dev": "dev1@company.com",
                        "tech_manager": "manager@company.com",
                        "ceo": "ceo@company.com"
                    }
                }
            },
            "database": {
                "path": "monitoring.db"
            }
        }
    
    def _init_database(self):
        """Initialize monitoring database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Create tables
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    value REAL NOT NULL,
                    unit TEXT,
                    status TEXT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS incidents (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    severity TEXT,
                    status TEXT,
                    created_at DATETIME,
                    resolved_at DATETIME,
                    resolution_notes TEXT
                )
            ''')
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS sla_records (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    service TEXT NOT NULL,
                    is_available BOOLEAN,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            conn.commit()
            conn.close()
            
            logger.info("Monitoring database initialized")
            
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
    
    def _setup_recovery_procedures(self):
        """Setup automatic recovery procedures"""
        
        async def restart_service_recovery(incident: Incident) -> bool:
            """Recovery procedure for service restart"""
            try:
                # Extract service name from incident
                service_name = "microsoft365_gui"  # Default service
                
                logger.info(f"Attempting service restart: {service_name}")
                
                # Restart service (implementation depends on deployment)
                result = subprocess.run(
                    ["systemctl", "restart", service_name],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                if result.returncode == 0:
                    logger.info(f"Service restart successful: {service_name}")
                    await asyncio.sleep(10)  # Wait for service to stabilize
                    return await self._verify_service_health(service_name)
                else:
                    logger.error(f"Service restart failed: {result.stderr}")
                    return False
                    
            except Exception as e:
                logger.error(f"Service restart recovery failed: {e}")
                return False
        
        async def clear_cache_recovery(incident: Incident) -> bool:
            """Recovery procedure for cache clearing"""
            try:
                logger.info("Attempting cache clear recovery")
                
                # Clear application cache
                cache_dirs = [
                    "/tmp/microsoft365_cache",
                    "/var/cache/microsoft365"
                ]
                
                for cache_dir in cache_dirs:
                    if Path(cache_dir).exists():
                        subprocess.run(["rm", "-rf", cache_dir])
                
                logger.info("Cache clear recovery completed")
                return True
                
            except Exception as e:
                logger.error(f"Cache clear recovery failed: {e}")
                return False
        
        async def memory_cleanup_recovery(incident: Incident) -> bool:
            """Recovery procedure for memory issues"""
            try:
                logger.info("Attempting memory cleanup recovery")
                
                # Force garbage collection
                import gc
                gc.collect()
                
                # Clear system caches
                subprocess.run(["sync"])
                subprocess.run(["echo", "3"], input=b"3\n", 
                             stdout=open("/proc/sys/vm/drop_caches", "w"))
                
                logger.info("Memory cleanup recovery completed")
                return True
                
            except Exception as e:
                logger.error(f"Memory cleanup recovery failed: {e}")
                return False
        
        # Register recovery procedures
        self.auto_recovery.register_recovery_procedure("service down", restart_service_recovery)
        self.auto_recovery.register_recovery_procedure("high memory", memory_cleanup_recovery)
        self.auto_recovery.register_recovery_procedure("cache error", clear_cache_recovery)
        self.auto_recovery.register_recovery_procedure("connection timeout", restart_service_recovery)
    
    async def start_monitoring(self):
        """Start 24/7 monitoring"""
        if self.is_monitoring:
            logger.warning("Monitoring already running")
            return
        
        self.is_monitoring = True
        logger.info("🚨 Starting 24/7 Enterprise Health Monitoring")
        
        # Start monitoring tasks
        tasks = [
            asyncio.create_task(self._system_health_monitor()),
            asyncio.create_task(self._service_health_monitor()),
            asyncio.create_task(self._performance_monitor()),
            asyncio.create_task(self._sla_monitor()),
            asyncio.create_task(self._incident_processor())
        ]
        
        try:
            await asyncio.gather(*tasks)
        except Exception as e:
            logger.error(f"Monitoring task failed: {e}")
            await self.alert_manager.send_alert(
                AlertLevel.CRITICAL,
                "Monitoring System Failure",
                f"Enterprise health monitoring encountered critical error: {e}"
            )
    
    async def stop_monitoring(self):
        """Stop monitoring gracefully"""
        self.is_monitoring = False
        logger.info("Stopping Enterprise Health Monitoring")
    
    async def _system_health_monitor(self):
        """Monitor system resource health"""
        while self.is_monitoring:
            try:
                # CPU monitoring
                cpu_percent = psutil.cpu_percent(interval=1)
                cpu_metric = HealthMetric(
                    name="cpu_usage",
                    value=cpu_percent,
                    unit="%",
                    threshold_warning=self.config["thresholds"]["cpu_warning"],
                    threshold_critical=self.config["thresholds"]["cpu_critical"],
                    description="System CPU usage percentage"
                )
                cpu_metric.evaluate_status()
                self.metrics["cpu_usage"] = cpu_metric
                
                # Memory monitoring
                memory = psutil.virtual_memory()
                memory_metric = HealthMetric(
                    name="memory_usage",
                    value=memory.percent,
                    unit="%",
                    threshold_warning=self.config["thresholds"]["memory_warning"],
                    threshold_critical=self.config["thresholds"]["memory_critical"],
                    description="System memory usage percentage"
                )
                memory_metric.evaluate_status()
                self.metrics["memory_usage"] = memory_metric
                
                # Disk monitoring
                disk = psutil.disk_usage('/')
                disk_percent = (disk.used / disk.total) * 100
                disk_metric = HealthMetric(
                    name="disk_usage",
                    value=disk_percent,
                    unit="%",
                    threshold_warning=self.config["thresholds"]["disk_warning"],
                    threshold_critical=self.config["thresholds"]["disk_critical"],
                    description="System disk usage percentage"
                )
                disk_metric.evaluate_status()
                self.metrics["disk_usage"] = disk_metric
                
                # Check for critical conditions
                critical_metrics = [m for m in self.metrics.values() if m.status == HealthStatus.CRITICAL]
                if critical_metrics:
                    for metric in critical_metrics:
                        await self._handle_critical_metric(metric)
                
                # Store metrics in database
                await self._store_metrics()
                
                await asyncio.sleep(self.monitor_interval)
                
            except Exception as e:
                logger.error(f"System health monitoring error: {e}")
                await asyncio.sleep(60)  # Wait longer on error
    
    async def _service_health_monitor(self):
        """Monitor service health and availability"""
        while self.is_monitoring:
            try:
                services = self.config.get("services", [])
                
                for service in services:
                    is_healthy = await self._check_service_health(service)
                    
                    # Record SLA data
                    self.sla_tracker.record_uptime(service, is_healthy)
                    
                    if not is_healthy:
                        incident = await self._create_incident(
                            f"{service} Service Down",
                            f"Service {service} is not responding or unhealthy",
                            AlertLevel.CRITICAL,
                            affected_services=[service]
                        )
                        
                        # Attempt automatic recovery
                        recovery_success = await self.auto_recovery.attempt_recovery(incident)
                        
                        if not recovery_success:
                            await self.alert_manager.send_alert(
                                AlertLevel.CRITICAL,
                                f"Service Down: {service}",
                                f"Service {service} is down and automatic recovery failed",
                                {"service": service, "incident_id": incident.id}
                            )
                
                await asyncio.sleep(self.monitor_interval)
                
            except Exception as e:
                logger.error(f"Service health monitoring error: {e}")
                await asyncio.sleep(60)
    
    async def _performance_monitor(self):
        """Monitor application performance metrics"""
        while self.is_monitoring:
            try:
                # GUI responsiveness test
                gui_response_time = await self._measure_gui_response_time()
                if gui_response_time:
                    response_metric = HealthMetric(
                        name="gui_response_time",
                        value=gui_response_time,
                        unit="seconds",
                        threshold_warning=self.config["thresholds"]["response_time_warning"],
                        threshold_critical=self.config["thresholds"]["response_time_critical"],
                        description="GUI response time"
                    )
                    response_metric.evaluate_status()
                    self.metrics["gui_response_time"] = response_metric
                
                # Database performance
                db_response_time = await self._measure_database_performance()
                if db_response_time:
                    db_metric = HealthMetric(
                        name="database_response_time",
                        value=db_response_time,
                        unit="seconds",
                        threshold_warning=1.0,
                        threshold_critical=5.0,
                        description="Database query response time"
                    )
                    db_metric.evaluate_status()
                    self.metrics["database_response_time"] = db_metric
                
                await asyncio.sleep(self.monitor_interval * 2)  # Less frequent performance checks
                
            except Exception as e:
                logger.error(f"Performance monitoring error: {e}")
                await asyncio.sleep(120)
    
    async def _sla_monitor(self):
        """Monitor SLA compliance (99.9% uptime target)"""
        while self.is_monitoring:
            try:
                sla_status = self.sla_tracker.get_sla_status()
                
                # Check overall SLA compliance
                if not sla_status["sla_compliant"]:
                    await self.alert_manager.send_alert(
                        AlertLevel.ERROR,
                        "SLA Compliance Breach",
                        f"System availability ({sla_status['overall_availability']:.2f}%) "
                        f"below target ({sla_status['target']}%)",
                        sla_status
                    )
                
                # Check individual service SLA
                for service, availability in sla_status["service_availability"].items():
                    if availability < self.sla_tracker.target_availability:
                        await self.alert_manager.send_alert(
                            AlertLevel.WARNING,
                            f"Service SLA Breach: {service}",
                            f"Service {service} availability ({availability:.2f}%) below target",
                            {"service": service, "availability": availability}
                        )
                
                # Store SLA metrics
                sla_metric = HealthMetric(
                    name="sla_availability",
                    value=sla_status["overall_availability"],
                    unit="%",
                    threshold_warning=99.5,
                    threshold_critical=99.0,
                    description="Overall system availability"
                )
                sla_metric.evaluate_status()
                self.metrics["sla_availability"] = sla_metric
                
                await asyncio.sleep(300)  # Check SLA every 5 minutes
                
            except Exception as e:
                logger.error(f"SLA monitoring error: {e}")
                await asyncio.sleep(300)
    
    async def _incident_processor(self):
        """Process and manage incidents"""
        while self.is_monitoring:
            try:
                # Check for open incidents that need attention
                open_incidents = [i for i in self.incidents if i.status == "open"]
                
                for incident in open_incidents:
                    # Check if incident has been open too long
                    if incident.duration and incident.duration > timedelta(hours=1):
                        if incident.severity in [AlertLevel.CRITICAL, AlertLevel.EMERGENCY]:
                            await self.alert_manager.send_alert(
                                AlertLevel.EMERGENCY,
                                f"Unresolved Critical Incident: {incident.title}",
                                f"Incident {incident.id} has been open for {incident.duration}",
                                {"incident_id": incident.id, "duration": str(incident.duration)}
                            )
                
                await asyncio.sleep(600)  # Check incidents every 10 minutes
                
            except Exception as e:
                logger.error(f"Incident processing error: {e}")
                await asyncio.sleep(600)
    
    async def _handle_critical_metric(self, metric: HealthMetric):
        """Handle critical metric conditions"""
        incident_title = f"Critical {metric.name.replace('_', ' ').title()}"
        incident_description = (
            f"{metric.description} has reached critical level: "
            f"{metric.value}{metric.unit} (threshold: {metric.threshold_critical}{metric.unit})"
        )
        
        incident = await self._create_incident(
            incident_title,
            incident_description,
            AlertLevel.CRITICAL
        )
        
        # Attempt automatic recovery based on metric type
        if metric.name in ["memory_usage", "cpu_usage"]:
            await self.auto_recovery.attempt_recovery(incident)
    
    async def _check_service_health(self, service: str) -> bool:
        """Check if a specific service is healthy"""
        try:
            if service == "microsoft365_gui":
                # Check if GUI process is running
                for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                    if 'python' in proc.info['name'] and 'main_window' in ' '.join(proc.info['cmdline']):
                        return True
                return False
            
            elif service == "websocket_server":
                # Check WebSocket server connectivity
                try:
                    async with websockets.connect("ws://localhost:8000/health", timeout=5) as websocket:
                        await websocket.send("ping")
                        response = await websocket.recv()
                        return response == "pong"
                except:
                    return False
            
            elif service == "api_gateway":
                # Check API gateway health
                try:
                    response = requests.get("http://localhost:8000/health", timeout=5)
                    return response.status_code == 200
                except:
                    return False
            
            elif service == "database":
                # Check database connectivity
                try:
                    conn = sqlite3.connect(self.db_path, timeout=5)
                    cursor = conn.cursor()
                    cursor.execute("SELECT 1")
                    conn.close()
                    return True
                except:
                    return False
            
            else:
                logger.warning(f"Unknown service: {service}")
                return True  # Assume healthy if unknown
                
        except Exception as e:
            logger.error(f"Service health check failed for {service}: {e}")
            return False
    
    async def _verify_service_health(self, service: str) -> bool:
        """Verify service health after recovery attempt"""
        await asyncio.sleep(5)  # Wait for service to stabilize
        return await self._check_service_health(service)
    
    async def _measure_gui_response_time(self) -> Optional[float]:
        """Measure GUI response time"""
        try:
            start_time = time.time()
            
            # Simulate GUI health check (placeholder)
            # In real implementation, this would ping the GUI application
            await asyncio.sleep(0.1)  # Simulate GUI response
            
            end_time = time.time()
            return end_time - start_time
            
        except Exception as e:
            logger.error(f"GUI response time measurement failed: {e}")
            return None
    
    async def _measure_database_performance(self) -> Optional[float]:
        """Measure database performance"""
        try:
            start_time = time.time()
            
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM metrics WHERE timestamp > datetime('now', '-1 hour')")
            cursor.fetchone()
            conn.close()
            
            end_time = time.time()
            return end_time - start_time
            
        except Exception as e:
            logger.error(f"Database performance measurement failed: {e}")
            return None
    
    async def _create_incident(self, title: str, description: str, 
                             severity: AlertLevel, affected_services: List[str] = None) -> Incident:
        """Create new incident"""
        incident = Incident(
            id=f"INC-{int(time.time())}",
            title=title,
            description=description,
            severity=severity,
            affected_services=affected_services or []
        )
        
        self.incidents.append(incident)
        
        # Store in database
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO incidents (id, title, description, severity, status, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (incident.id, incident.title, incident.description, 
                 incident.severity.value, incident.status, incident.created_at)
            )
            conn.commit()
            conn.close()
        except Exception as e:
            logger.error(f"Failed to store incident: {e}")
        
        logger.error(f"Incident created: {incident.id} - {incident.title}")
        return incident
    
    async def _store_metrics(self):
        """Store current metrics in database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            for metric in self.metrics.values():
                cursor.execute(
                    "INSERT INTO metrics (name, value, unit, status) VALUES (?, ?, ?, ?)",
                    (metric.name, metric.value, metric.unit, metric.status.value)
                )
                
                # SLA record
                cursor.execute(
                    "INSERT INTO sla_records (service, is_available) VALUES (?, ?)",
                    ("system", metric.status != HealthStatus.CRITICAL)
                )
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Failed to store metrics: {e}")
    
    def get_health_status(self) -> Dict[str, Any]:
        """Get current system health status"""
        overall_status = HealthStatus.HEALTHY
        
        # Determine overall status from worst metric
        for metric in self.metrics.values():
            if metric.status == HealthStatus.CRITICAL:
                overall_status = HealthStatus.CRITICAL
                break
            elif metric.status == HealthStatus.WARNING and overall_status == HealthStatus.HEALTHY:
                overall_status = HealthStatus.WARNING
        
        return {
            "overall_status": overall_status.value,
            "metrics": {
                name: {
                    "value": metric.value,
                    "unit": metric.unit,
                    "status": metric.status.value,
                    "timestamp": metric.timestamp.isoformat()
                }
                for name, metric in self.metrics.items()
            },
            "sla_status": self.sla_tracker.get_sla_status(),
            "active_incidents": len([i for i in self.incidents if i.status == "open"]),
            "monitoring_active": self.is_monitoring
        }
    
    async def manual_recovery(self, incident_id: str) -> bool:
        """Trigger manual recovery for incident"""
        incident = next((i for i in self.incidents if i.id == incident_id), None)
        if not incident:
            logger.error(f"Incident not found: {incident_id}")
            return False
        
        return await self.auto_recovery.attempt_recovery(incident)


# Global monitor instance
enterprise_monitor = EnterpriseHealthMonitor()


async def main():
    """Main monitoring entry point"""
    print("🚨 Microsoft 365 Enterprise Health Monitor - Phase 5 Critical Priority")
    print("Starting 24/7 monitoring with 99.9% SLA target...")
    
    try:
        await enterprise_monitor.start_monitoring()
    except KeyboardInterrupt:
        print("\n⚠️ Monitoring stopped by user")
        await enterprise_monitor.stop_monitoring()
    except Exception as e:
        print(f"❌ Critical monitoring error: {e}")
        await enterprise_monitor.alert_manager.send_alert(
            AlertLevel.EMERGENCY,
            "Monitoring System Critical Failure",
            f"Enterprise health monitoring system has failed: {e}"
        )


if __name__ == "__main__":
    asyncio.run(main())