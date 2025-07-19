#!/usr/bin/env python3
"""
Incident Response System - Phase 5 Critical Priority
24/7自動インシデント対応・復旧システム

Features:
- Automated incident detection and classification
- Intelligent escalation and routing
- Self-healing recovery procedures
- Real-time communication and updates
- Post-incident analysis and learning

Author: Frontend Developer (dev0) - Phase 5 Emergency Response
Version: 5.0.0 CRITICAL
Date: 2025-07-19
"""

import asyncio
import logging
import json
import time
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable, Set
from dataclasses import dataclass, field
from enum import Enum
import threading
import subprocess
import psutil
from pathlib import Path
import sqlite3

# Configure logging for incident response
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] INCIDENT-RESPONSE: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/incident-response.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class IncidentSeverity(Enum):
    """Incident severity levels with SLA response times"""
    P1_CRITICAL = "P1"      # 15 minutes - System down, major service disruption
    P2_HIGH = "P2"          # 1 hour - Significant functionality impacted
    P3_MEDIUM = "P3"        # 4 hours - Minor functionality impacted
    P4_LOW = "P4"           # 24 hours - Enhancement requests, minor issues


class IncidentStatus(Enum):
    """Incident lifecycle status"""
    NEW = "new"
    ASSIGNED = "assigned" 
    IN_PROGRESS = "in_progress"
    ESCALATED = "escalated"
    RESOLVED = "resolved"
    CLOSED = "closed"
    REOPENED = "reopened"


class RecoveryAction(Enum):
    """Types of automated recovery actions"""
    RESTART_SERVICE = "restart_service"
    CLEAR_CACHE = "clear_cache"
    SCALE_RESOURCES = "scale_resources"
    FAILOVER = "failover"
    ROLLBACK = "rollback"
    PATCH_APPLY = "patch_apply"
    MANUAL_INTERVENTION = "manual_intervention"


@dataclass
class IncidentDetail:
    """Comprehensive incident information"""
    id: str
    title: str
    description: str
    severity: IncidentSeverity
    status: IncidentStatus = IncidentStatus.NEW
    
    # Timing
    created_at: datetime = field(default_factory=datetime.utcnow)
    first_response_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    closed_at: Optional[datetime] = None
    
    # Assignment and escalation
    assigned_to: Optional[str] = None
    escalated_to: Optional[str] = None
    escalation_level: int = 0
    
    # Technical details
    affected_services: List[str] = field(default_factory=list)
    error_messages: List[str] = field(default_factory=list)
    stack_traces: List[str] = field(default_factory=list)
    system_metrics: Dict[str, Any] = field(default_factory=dict)
    
    # Response and resolution
    recovery_actions_attempted: List[str] = field(default_factory=list)
    resolution_notes: str = ""
    root_cause: str = ""
    preventive_measures: List[str] = field(default_factory=list)
    
    # Communication
    updates: List[Dict[str, Any]] = field(default_factory=list)
    customer_impact: str = ""
    business_impact: str = ""
    
    # Metadata
    tags: Set[str] = field(default_factory=set)
    related_incidents: List[str] = field(default_factory=list)
    
    @property
    def response_time(self) -> Optional[timedelta]:
        """Time to first response"""
        if self.first_response_at:
            return self.first_response_at - self.created_at
        return None
    
    @property
    def resolution_time(self) -> Optional[timedelta]:
        """Time to resolution"""
        if self.resolved_at:
            return self.resolved_at - self.created_at
        return None
    
    @property
    def sla_breach(self) -> bool:
        """Check if incident breached SLA"""
        sla_times = {
            IncidentSeverity.P1_CRITICAL: timedelta(minutes=15),
            IncidentSeverity.P2_HIGH: timedelta(hours=1),
            IncidentSeverity.P3_MEDIUM: timedelta(hours=4),
            IncidentSeverity.P4_LOW: timedelta(hours=24)
        }
        
        target_time = sla_times.get(self.severity)
        if not target_time:
            return False
        
        if self.resolved_at:
            return self.resolution_time > target_time
        else:
            # Still open - check if already breached
            current_time = datetime.utcnow() - self.created_at
            return current_time > target_time
    
    def add_update(self, message: str, author: str = "system"):
        """Add status update to incident"""
        update = {
            "timestamp": datetime.utcnow(),
            "author": author,
            "message": message
        }
        self.updates.append(update)


@dataclass
class RecoveryProcedure:
    """Automated recovery procedure definition"""
    name: str
    action_type: RecoveryAction
    conditions: Dict[str, Any]
    steps: List[str]
    success_criteria: Dict[str, Any]
    rollback_steps: List[str]
    max_attempts: int = 3
    timeout_seconds: int = 300
    requires_approval: bool = False


class IncidentClassifier:
    """AI-powered incident classification and routing"""
    
    def __init__(self):
        self.classification_rules = self._load_classification_rules()
        self.severity_keywords = {
            IncidentSeverity.P1_CRITICAL: [
                "down", "outage", "critical", "emergency", "offline", 
                "crashed", "deadlock", "security breach", "data loss"
            ],
            IncidentSeverity.P2_HIGH: [
                "slow", "timeout", "error", "failed", "unavailable",
                "performance", "memory leak", "high cpu"
            ],
            IncidentSeverity.P3_MEDIUM: [
                "warning", "minor", "intermittent", "occasional",
                "ui issue", "display", "formatting"
            ],
            IncidentSeverity.P4_LOW: [
                "enhancement", "feature request", "cosmetic",
                "documentation", "typo"
            ]
        }
    
    def _load_classification_rules(self) -> Dict[str, Any]:
        """Load incident classification rules"""
        return {
            "service_patterns": {
                "microsoft365_gui": {
                    "keywords": ["gui", "interface", "window", "button", "display"],
                    "default_severity": IncidentSeverity.P2_HIGH
                },
                "websocket_server": {
                    "keywords": ["websocket", "connection", "realtime", "socket"],
                    "default_severity": IncidentSeverity.P1_CRITICAL
                },
                "api_gateway": {
                    "keywords": ["api", "endpoint", "request", "response"],
                    "default_severity": IncidentSeverity.P1_CRITICAL
                },
                "database": {
                    "keywords": ["database", "sql", "query", "table", "db"],
                    "default_severity": IncidentSeverity.P1_CRITICAL
                }
            }
        }
    
    def classify_incident(self, title: str, description: str, 
                         error_messages: List[str] = None) -> Dict[str, Any]:
        """Classify incident and determine severity, affected services, etc."""
        text_content = f"{title} {description} {' '.join(error_messages or [])}".lower()
        
        # Determine severity
        severity = self._determine_severity(text_content)
        
        # Identify affected services
        affected_services = self._identify_affected_services(text_content)
        
        # Extract tags
        tags = self._extract_tags(text_content)
        
        # Suggest assignment
        suggested_assignee = self._suggest_assignee(severity, affected_services)
        
        return {
            "severity": severity,
            "affected_services": affected_services,
            "tags": tags,
            "suggested_assignee": suggested_assignee,
            "auto_recovery_eligible": self._is_auto_recovery_eligible(text_content)
        }
    
    def _determine_severity(self, text_content: str) -> IncidentSeverity:
        """Determine incident severity based on content analysis"""
        # Score each severity level
        scores = {}
        
        for severity, keywords in self.severity_keywords.items():
            score = sum(1 for keyword in keywords if keyword in text_content)
            scores[severity] = score
        
        # Return highest scoring severity
        if scores:
            return max(scores, key=scores.get)
        
        return IncidentSeverity.P3_MEDIUM  # Default
    
    def _identify_affected_services(self, text_content: str) -> List[str]:
        """Identify affected services from incident content"""
        affected_services = []
        
        for service, config in self.classification_rules["service_patterns"].items():
            for keyword in config["keywords"]:
                if keyword in text_content:
                    affected_services.append(service)
                    break
        
        return affected_services
    
    def _extract_tags(self, text_content: str) -> Set[str]:
        """Extract relevant tags from incident content"""
        tags = set()
        
        # Technical tags
        tech_keywords = {
            "performance": ["slow", "timeout", "latency", "response time"],
            "security": ["breach", "unauthorized", "vulnerability", "attack"],
            "network": ["connection", "timeout", "unreachable", "dns"],
            "storage": ["disk", "space", "storage", "volume"],
            "memory": ["memory", "ram", "oom", "out of memory"],
            "cpu": ["cpu", "processor", "high load", "throttling"]
        }
        
        for tag, keywords in tech_keywords.items():
            if any(keyword in text_content for keyword in keywords):
                tags.add(tag)
        
        return tags
    
    def _suggest_assignee(self, severity: IncidentSeverity, 
                         affected_services: List[str]) -> str:
        """Suggest incident assignee based on severity and affected services"""
        # Assignment rules based on service and severity
        if severity == IncidentSeverity.P1_CRITICAL:
            if "database" in affected_services:
                return "backend_dev"
            elif "websocket_server" in affected_services:
                return "backend_dev"
            else:
                return "frontend_dev"
        
        elif any(service in ["microsoft365_gui", "frontend"] for service in affected_services):
            return "frontend_dev"
        else:
            return "backend_dev"
    
    def _is_auto_recovery_eligible(self, text_content: str) -> bool:
        """Determine if incident is eligible for automatic recovery"""
        auto_recovery_patterns = [
            "service down", "connection timeout", "memory leak",
            "cache error", "temporary failure", "restart required"
        ]
        
        return any(pattern in text_content for pattern in auto_recovery_patterns)


class AutoRecoveryEngine:
    """Intelligent automated recovery system"""
    
    def __init__(self):
        self.procedures: Dict[str, RecoveryProcedure] = {}
        self.recovery_history: List[Dict[str, Any]] = []
        self.success_rates: Dict[str, float] = {}
        self._initialize_procedures()
    
    def _initialize_procedures(self):
        """Initialize standard recovery procedures"""
        
        # Service restart procedure
        restart_service = RecoveryProcedure(
            name="restart_service",
            action_type=RecoveryAction.RESTART_SERVICE,
            conditions={"service_down": True, "process_crashed": True},
            steps=[
                "Stop the service gracefully",
                "Wait 10 seconds for cleanup",
                "Start the service",
                "Wait 30 seconds for initialization",
                "Verify service health"
            ],
            success_criteria={"service_responding": True, "health_check_passed": True},
            rollback_steps=["Log failure", "Escalate to manual intervention"],
            timeout_seconds=180
        )
        
        # Cache clearing procedure
        clear_cache = RecoveryProcedure(
            name="clear_cache",
            action_type=RecoveryAction.CLEAR_CACHE,
            conditions={"cache_corruption": True, "memory_pressure": True},
            steps=[
                "Identify cache directories",
                "Create backup of critical cache data",
                "Clear application cache",
                "Clear system cache",
                "Restart related services"
            ],
            success_criteria={"memory_usage_decreased": True, "cache_rebuilt": True},
            rollback_steps=["Restore cache backup if available"],
            timeout_seconds=120
        )
        
        # Memory cleanup procedure
        memory_cleanup = RecoveryProcedure(
            name="memory_cleanup",
            action_type=RecoveryAction.SCALE_RESOURCES,
            conditions={"high_memory_usage": True, "memory_leak": True},
            steps=[
                "Force garbage collection",
                "Clear unused memory buffers",
                "Restart memory-intensive processes",
                "Monitor memory usage"
            ],
            success_criteria={"memory_usage_normal": True},
            rollback_steps=["Restart entire application if cleanup fails"],
            timeout_seconds=60
        )
        
        # Database connection recovery
        db_recovery = RecoveryProcedure(
            name="database_recovery",
            action_type=RecoveryAction.RESTART_SERVICE,
            conditions={"db_connection_failed": True, "db_timeout": True},
            steps=[
                "Close all database connections",
                "Restart database connection pool",
                "Test basic database connectivity",
                "Verify critical data integrity"
            ],
            success_criteria={"db_responding": True, "connection_pool_healthy": True},
            rollback_steps=["Switch to backup database if available"],
            timeout_seconds=300
        )
        
        # Register procedures
        for procedure in [restart_service, clear_cache, memory_cleanup, db_recovery]:
            self.procedures[procedure.name] = procedure
    
    async def execute_recovery(self, incident: IncidentDetail) -> Dict[str, Any]:
        """Execute appropriate recovery procedure for incident"""
        # Select best recovery procedure
        procedure = self._select_recovery_procedure(incident)
        
        if not procedure:
            logger.warning(f"No suitable recovery procedure for incident {incident.id}")
            return {"success": False, "reason": "No suitable procedure found"}
        
        logger.info(f"Executing recovery procedure '{procedure.name}' for incident {incident.id}")
        
        # Execute procedure
        result = await self._execute_procedure(procedure, incident)
        
        # Record recovery attempt
        recovery_record = {
            "incident_id": incident.id,
            "procedure_name": procedure.name,
            "timestamp": datetime.utcnow(),
            "success": result["success"],
            "execution_time": result.get("execution_time", 0),
            "details": result.get("details", {})
        }
        
        self.recovery_history.append(recovery_record)
        incident.recovery_actions_attempted.append(procedure.name)
        
        # Update success rate
        self._update_success_rate(procedure.name, result["success"])
        
        return result
    
    def _select_recovery_procedure(self, incident: IncidentDetail) -> Optional[RecoveryProcedure]:
        """Select most appropriate recovery procedure"""
        # Match conditions to available procedures
        applicable_procedures = []
        
        for procedure in self.procedures.values():
            if self._matches_conditions(incident, procedure.conditions):
                success_rate = self.success_rates.get(procedure.name, 0.5)
                applicable_procedures.append((procedure, success_rate))
        
        if not applicable_procedures:
            return None
        
        # Sort by success rate and return best option
        applicable_procedures.sort(key=lambda x: x[1], reverse=True)
        return applicable_procedures[0][0]
    
    def _matches_conditions(self, incident: IncidentDetail, 
                           conditions: Dict[str, Any]) -> bool:
        """Check if incident matches procedure conditions"""
        incident_text = f"{incident.title} {incident.description}".lower()
        
        for condition_key, condition_value in conditions.items():
            if condition_key == "service_down":
                if condition_value and "down" not in incident_text:
                    return False
            elif condition_key == "process_crashed":
                if condition_value and "crash" not in incident_text:
                    return False
            elif condition_key == "cache_corruption":
                if condition_value and "cache" not in incident_text:
                    return False
            elif condition_key == "memory_pressure":
                if condition_value and "memory" not in incident_text:
                    return False
            elif condition_key == "high_memory_usage":
                if condition_value and not any(word in incident_text for word in ["memory", "oom"]):
                    return False
            elif condition_key == "db_connection_failed":
                if condition_value and not any(word in incident_text for word in ["database", "db", "connection"]):
                    return False
        
        return True
    
    async def _execute_procedure(self, procedure: RecoveryProcedure, 
                                incident: IncidentDetail) -> Dict[str, Any]:
        """Execute recovery procedure steps"""
        start_time = time.time()
        
        try:
            incident.add_update(f"Starting automated recovery: {procedure.name}")
            
            # Execute each step
            for i, step in enumerate(procedure.steps):
                logger.info(f"Executing step {i+1}/{len(procedure.steps)}: {step}")
                incident.add_update(f"Recovery step {i+1}: {step}")
                
                # Execute step based on procedure type
                step_success = await self._execute_step(step, procedure.action_type, incident)
                
                if not step_success:
                    logger.error(f"Recovery step failed: {step}")
                    incident.add_update(f"Recovery step failed: {step}")
                    
                    # Execute rollback
                    await self._execute_rollback(procedure, incident)
                    
                    return {
                        "success": False,
                        "execution_time": time.time() - start_time,
                        "failed_step": step,
                        "details": {"step_index": i, "total_steps": len(procedure.steps)}
                    }
            
            # Verify success criteria
            success = await self._verify_success_criteria(procedure.success_criteria, incident)
            
            if success:
                incident.add_update(f"Automated recovery successful: {procedure.name}")
                logger.info(f"Recovery procedure '{procedure.name}' completed successfully")
            else:
                incident.add_update(f"Recovery completed but success criteria not met")
                logger.warning(f"Recovery procedure '{procedure.name}' completed but success criteria failed")
            
            return {
                "success": success,
                "execution_time": time.time() - start_time,
                "details": {"all_steps_completed": True}
            }
            
        except asyncio.TimeoutError:
            logger.error(f"Recovery procedure '{procedure.name}' timed out")
            incident.add_update(f"Recovery procedure timed out after {procedure.timeout_seconds} seconds")
            await self._execute_rollback(procedure, incident)
            
            return {
                "success": False,
                "execution_time": time.time() - start_time,
                "reason": "timeout",
                "details": {"timeout_seconds": procedure.timeout_seconds}
            }
            
        except Exception as e:
            logger.error(f"Recovery procedure '{procedure.name}' failed: {e}")
            incident.add_update(f"Recovery procedure failed with error: {str(e)}")
            await self._execute_rollback(procedure, incident)
            
            return {
                "success": False,
                "execution_time": time.time() - start_time,
                "reason": "exception",
                "details": {"error": str(e)}
            }
    
    async def _execute_step(self, step: str, action_type: RecoveryAction, 
                           incident: IncidentDetail) -> bool:
        """Execute individual recovery step"""
        try:
            if action_type == RecoveryAction.RESTART_SERVICE:
                return await self._restart_service_step(step, incident)
            elif action_type == RecoveryAction.CLEAR_CACHE:
                return await self._clear_cache_step(step, incident)
            elif action_type == RecoveryAction.SCALE_RESOURCES:
                return await self._scale_resources_step(step, incident)
            else:
                logger.warning(f"Unknown action type: {action_type}")
                return False
                
        except Exception as e:
            logger.error(f"Step execution failed: {e}")
            return False
    
    async def _restart_service_step(self, step: str, incident: IncidentDetail) -> bool:
        """Execute service restart step"""
        if "stop the service" in step.lower():
            # Stop service gracefully
            service_name = self._extract_service_name(incident)
            try:
                result = subprocess.run(
                    ["systemctl", "stop", service_name],
                    capture_output=True, text=True, timeout=30
                )
                return result.returncode == 0
            except:
                # Fallback: kill process
                return await self._kill_service_process(service_name)
        
        elif "start the service" in step.lower():
            # Start service
            service_name = self._extract_service_name(incident)
            try:
                result = subprocess.run(
                    ["systemctl", "start", service_name],
                    capture_output=True, text=True, timeout=60
                )
                return result.returncode == 0
            except:
                return False
        
        elif "verify service health" in step.lower():
            # Verify service is healthy
            return await self._verify_service_health(incident)
        
        elif "wait" in step.lower():
            # Extract wait time and sleep
            import re
            match = re.search(r'(\d+)', step)
            if match:
                wait_time = int(match.group(1))
                await asyncio.sleep(wait_time)
            return True
        
        return True  # Default success for unknown steps
    
    async def _clear_cache_step(self, step: str, incident: IncidentDetail) -> bool:
        """Execute cache clearing step"""
        if "clear application cache" in step.lower():
            cache_dirs = [
                "/tmp/microsoft365_cache",
                "/var/cache/microsoft365",
                "~/.cache/microsoft365"
            ]
            
            for cache_dir in cache_dirs:
                try:
                    if Path(cache_dir).exists():
                        subprocess.run(["rm", "-rf", cache_dir], timeout=30)
                except:
                    continue
            return True
        
        elif "clear system cache" in step.lower():
            try:
                # Clear system page cache
                subprocess.run(["sync"], timeout=10)
                with open("/proc/sys/vm/drop_caches", "w") as f:
                    f.write("3\n")
                return True
            except:
                return False
        
        return True
    
    async def _scale_resources_step(self, step: str, incident: IncidentDetail) -> bool:
        """Execute resource scaling step"""
        if "garbage collection" in step.lower():
            try:
                import gc
                gc.collect()
                return True
            except:
                return False
        
        elif "clear unused memory" in step.lower():
            try:
                # Force memory cleanup
                subprocess.run(["sync"], timeout=10)
                return True
            except:
                return False
        
        return True
    
    def _extract_service_name(self, incident: IncidentDetail) -> str:
        """Extract service name from incident"""
        if incident.affected_services:
            return incident.affected_services[0].replace("_", "-")
        return "microsoft365-gui"
    
    async def _kill_service_process(self, service_name: str) -> bool:
        """Kill service process as fallback"""
        try:
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                if service_name in proc.info['name'] or any(service_name in cmd for cmd in proc.info['cmdline']):
                    proc.kill()
            return True
        except:
            return False
    
    async def _verify_service_health(self, incident: IncidentDetail) -> bool:
        """Verify service health after recovery"""
        # This would integrate with the health monitoring system
        await asyncio.sleep(5)  # Wait for service to stabilize
        return True  # Placeholder
    
    async def _verify_success_criteria(self, criteria: Dict[str, Any], 
                                     incident: IncidentDetail) -> bool:
        """Verify recovery success criteria"""
        for criterion, expected_value in criteria.items():
            if criterion == "service_responding":
                if not await self._verify_service_health(incident):
                    return False
            elif criterion == "memory_usage_normal":
                memory_usage = psutil.virtual_memory().percent
                if memory_usage > 85:  # Still high memory usage
                    return False
            # Add more criteria checks as needed
        
        return True
    
    async def _execute_rollback(self, procedure: RecoveryProcedure, 
                               incident: IncidentDetail):
        """Execute rollback steps if recovery fails"""
        logger.info(f"Executing rollback for procedure: {procedure.name}")
        incident.add_update(f"Executing rollback for failed recovery: {procedure.name}")
        
        for step in procedure.rollback_steps:
            try:
                logger.info(f"Rollback step: {step}")
                incident.add_update(f"Rollback: {step}")
                # Execute rollback step (implementation depends on step)
                await asyncio.sleep(1)  # Placeholder
            except Exception as e:
                logger.error(f"Rollback step failed: {e}")
    
    def _update_success_rate(self, procedure_name: str, success: bool):
        """Update procedure success rate based on outcome"""
        if procedure_name not in self.success_rates:
            self.success_rates[procedure_name] = 0.5  # Start with 50%
        
        # Simple exponential moving average
        current_rate = self.success_rates[procedure_name]
        new_rate = current_rate * 0.8 + (1.0 if success else 0.0) * 0.2
        self.success_rates[procedure_name] = new_rate


class IncidentResponseSystem:
    """Central incident response coordination system"""
    
    def __init__(self):
        self.incidents: Dict[str, IncidentDetail] = {}
        self.classifier = IncidentClassifier()
        self.recovery_engine = AutoRecoveryEngine()
        
        # Response team assignments
        self.response_team = {
            "frontend_dev": {
                "name": "Frontend Developer (dev0)",
                "skills": ["gui", "ui", "frontend", "pyqt6"],
                "max_concurrent": 3
            },
            "backend_dev": {
                "name": "Backend Developer (dev1)",
                "skills": ["api", "database", "server", "websocket"],
                "max_concurrent": 3
            },
            "tech_manager": {
                "name": "Technical Project Manager",
                "skills": ["escalation", "coordination", "planning"],
                "max_concurrent": 10
            }
        }
        
        # SLA response times
        self.sla_response_times = {
            IncidentSeverity.P1_CRITICAL: timedelta(minutes=15),
            IncidentSeverity.P2_HIGH: timedelta(hours=1),
            IncidentSeverity.P3_MEDIUM: timedelta(hours=4),
            IncidentSeverity.P4_LOW: timedelta(hours=24)
        }
        
        # Initialize database
        self._init_database()
        
        # Start background tasks
        self.monitoring_active = True
        asyncio.create_task(self._sla_monitoring_task())
        asyncio.create_task(self._escalation_task())
    
    def _init_database(self):
        """Initialize incident database"""
        try:
            conn = sqlite3.connect("incidents.db")
            cursor = conn.cursor()
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS incidents (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    severity TEXT,
                    status TEXT,
                    created_at DATETIME,
                    resolved_at DATETIME,
                    assigned_to TEXT,
                    affected_services TEXT,
                    resolution_notes TEXT
                )
            ''')
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS incident_updates (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    incident_id TEXT,
                    timestamp DATETIME,
                    author TEXT,
                    message TEXT,
                    FOREIGN KEY (incident_id) REFERENCES incidents (id)
                )
            ''')
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
    
    async def create_incident(self, title: str, description: str,
                            error_messages: List[str] = None,
                            system_metrics: Dict[str, Any] = None) -> IncidentDetail:
        """Create new incident with automatic classification"""
        
        # Generate unique incident ID
        incident_id = f"INC-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{str(uuid.uuid4())[:8]}"
        
        # Classify incident
        classification = self.classifier.classify_incident(title, description, error_messages)
        
        # Create incident object
        incident = IncidentDetail(
            id=incident_id,
            title=title,
            description=description,
            severity=classification["severity"],
            affected_services=classification["affected_services"],
            error_messages=error_messages or [],
            system_metrics=system_metrics or {},
            tags=classification["tags"]
        )
        
        # Store incident
        self.incidents[incident_id] = incident
        
        # Add initial update
        incident.add_update(f"Incident created with severity {incident.severity.value}")
        
        # Auto-assign if possible
        if classification["suggested_assignee"]:
            await self.assign_incident(incident_id, classification["suggested_assignee"])
        
        # Attempt automatic recovery if eligible
        if classification["auto_recovery_eligible"]:
            asyncio.create_task(self._attempt_auto_recovery(incident))
        
        # Store in database
        await self._store_incident(incident)
        
        # Send immediate alerts for critical incidents
        if incident.severity == IncidentSeverity.P1_CRITICAL:
            await self._send_critical_alert(incident)
        
        logger.error(f"Incident created: {incident_id} - {title} [{incident.severity.value}]")
        return incident
    
    async def assign_incident(self, incident_id: str, assignee: str) -> bool:
        """Assign incident to team member"""
        incident = self.incidents.get(incident_id)
        if not incident:
            return False
        
        # Check assignee availability
        if not self._is_assignee_available(assignee):
            logger.warning(f"Assignee {assignee} not available for incident {incident_id}")
            return False
        
        incident.assigned_to = assignee
        incident.status = IncidentStatus.ASSIGNED
        incident.first_response_at = datetime.utcnow()
        
        incident.add_update(f"Incident assigned to {assignee}")
        
        # Update database
        await self._update_incident(incident)
        
        logger.info(f"Incident {incident_id} assigned to {assignee}")
        return True
    
    async def update_incident_status(self, incident_id: str, status: IncidentStatus,
                                   update_message: str = "", author: str = "system") -> bool:
        """Update incident status"""
        incident = self.incidents.get(incident_id)
        if not incident:
            return False
        
        old_status = incident.status
        incident.status = status
        
        if status == IncidentStatus.RESOLVED:
            incident.resolved_at = datetime.utcnow()
        elif status == IncidentStatus.CLOSED:
            incident.closed_at = datetime.utcnow()
        
        # Add update
        status_message = f"Status changed from {old_status.value} to {status.value}"
        if update_message:
            status_message += f": {update_message}"
        
        incident.add_update(status_message, author)
        
        # Update database
        await self._update_incident(incident)
        
        logger.info(f"Incident {incident_id} status updated to {status.value}")
        return True
    
    async def resolve_incident(self, incident_id: str, resolution_notes: str,
                             root_cause: str = "", preventive_measures: List[str] = None,
                             author: str = "system") -> bool:
        """Resolve incident with details"""
        incident = self.incidents.get(incident_id)
        if not incident:
            return False
        
        incident.status = IncidentStatus.RESOLVED
        incident.resolved_at = datetime.utcnow()
        incident.resolution_notes = resolution_notes
        incident.root_cause = root_cause
        incident.preventive_measures = preventive_measures or []
        
        incident.add_update(f"Incident resolved: {resolution_notes}", author)
        
        # Update database
        await self._update_incident(incident)
        
        logger.info(f"Incident {incident_id} resolved: {resolution_notes}")
        return True
    
    async def escalate_incident(self, incident_id: str, reason: str) -> bool:
        """Escalate incident to next level"""
        incident = self.incidents.get(incident_id)
        if not incident:
            return False
        
        incident.escalation_level += 1
        incident.status = IncidentStatus.ESCALATED
        
        # Determine escalation target
        if incident.escalation_level == 1:
            incident.escalated_to = "tech_manager"
        elif incident.escalation_level == 2:
            incident.escalated_to = "ceo"
        
        incident.add_update(f"Incident escalated (level {incident.escalation_level}): {reason}")
        
        # Update database
        await self._update_incident(incident)
        
        logger.warning(f"Incident {incident_id} escalated to level {incident.escalation_level}: {reason}")
        return True
    
    async def _attempt_auto_recovery(self, incident: IncidentDetail):
        """Attempt automatic recovery for incident"""
        try:
            incident.add_update("Attempting automated recovery")
            incident.status = IncidentStatus.IN_PROGRESS
            
            result = await self.recovery_engine.execute_recovery(incident)
            
            if result["success"]:
                await self.resolve_incident(
                    incident.id,
                    f"Automatically resolved using recovery procedure",
                    root_cause="Automated recovery successful",
                    author="auto_recovery"
                )
            else:
                incident.add_update(f"Automated recovery failed: {result.get('reason', 'Unknown')}")
                # Escalate or assign for manual intervention
                await self.assign_incident(incident.id, "frontend_dev")
                
        except Exception as e:
            logger.error(f"Auto-recovery failed for incident {incident.id}: {e}")
            incident.add_update(f"Auto-recovery exception: {str(e)}")
    
    def _is_assignee_available(self, assignee: str) -> bool:
        """Check if assignee is available for new incidents"""
        if assignee not in self.response_team:
            return False
        
        # Count current assignments
        current_assignments = sum(
            1 for incident in self.incidents.values()
            if incident.assigned_to == assignee and incident.status not in [
                IncidentStatus.RESOLVED, IncidentStatus.CLOSED
            ]
        )
        
        max_concurrent = self.response_team[assignee]["max_concurrent"]
        return current_assignments < max_concurrent
    
    async def _sla_monitoring_task(self):
        """Background task to monitor SLA compliance"""
        while self.monitoring_active:
            try:
                current_time = datetime.utcnow()
                
                for incident in self.incidents.values():
                    if incident.status in [IncidentStatus.RESOLVED, IncidentStatus.CLOSED]:
                        continue
                    
                    # Check SLA breach
                    sla_time = self.sla_response_times.get(incident.severity)
                    if sla_time:
                        time_elapsed = current_time - incident.created_at
                        
                        if time_elapsed > sla_time and not incident.sla_breach:
                            # SLA breach detected
                            logger.error(f"SLA breach detected for incident {incident.id}")
                            incident.add_update(f"SLA breach: {time_elapsed} > {sla_time}")
                            
                            # Auto-escalate SLA breaches
                            await self.escalate_incident(incident.id, f"SLA breach: {time_elapsed} elapsed")
                
                await asyncio.sleep(300)  # Check every 5 minutes
                
            except Exception as e:
                logger.error(f"SLA monitoring error: {e}")
                await asyncio.sleep(300)
    
    async def _escalation_task(self):
        """Background task to handle escalations"""
        while self.monitoring_active:
            try:
                # Check for incidents that need escalation
                for incident in self.incidents.values():
                    if incident.status == IncidentStatus.ESCALATED:
                        # Handle escalated incidents
                        await self._handle_escalated_incident(incident)
                
                await asyncio.sleep(600)  # Check every 10 minutes
                
            except Exception as e:
                logger.error(f"Escalation task error: {e}")
                await asyncio.sleep(600)
    
    async def _handle_escalated_incident(self, incident: IncidentDetail):
        """Handle escalated incident"""
        # Placeholder for escalation handling logic
        logger.info(f"Handling escalated incident: {incident.id}")
    
    async def _send_critical_alert(self, incident: IncidentDetail):
        """Send immediate alert for critical incidents"""
        # Placeholder for alert sending logic
        logger.critical(f"CRITICAL INCIDENT ALERT: {incident.id} - {incident.title}")
    
    async def _store_incident(self, incident: IncidentDetail):
        """Store incident in database"""
        try:
            conn = sqlite3.connect("incidents.db")
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO incidents 
                (id, title, description, severity, status, created_at, assigned_to, affected_services)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                incident.id, incident.title, incident.description,
                incident.severity.value, incident.status.value,
                incident.created_at, incident.assigned_to,
                json.dumps(incident.affected_services)
            ))
            
            # Store updates
            for update in incident.updates:
                cursor.execute('''
                    INSERT INTO incident_updates (incident_id, timestamp, author, message)
                    VALUES (?, ?, ?, ?)
                ''', (incident.id, update["timestamp"], update["author"], update["message"]))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Failed to store incident: {e}")
    
    async def _update_incident(self, incident: IncidentDetail):
        """Update incident in database"""
        try:
            conn = sqlite3.connect("incidents.db")
            cursor = conn.cursor()
            
            cursor.execute('''
                UPDATE incidents SET
                    status = ?, resolved_at = ?, assigned_to = ?, resolution_notes = ?
                WHERE id = ?
            ''', (
                incident.status.value, incident.resolved_at,
                incident.assigned_to, incident.resolution_notes, incident.id
            ))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Failed to update incident: {e}")
    
    def get_incident_statistics(self) -> Dict[str, Any]:
        """Get incident response statistics"""
        total_incidents = len(self.incidents)
        if total_incidents == 0:
            return {"total_incidents": 0}
        
        # Status breakdown
        status_counts = {}
        for status in IncidentStatus:
            status_counts[status.value] = sum(
                1 for incident in self.incidents.values()
                if incident.status == status
            )
        
        # Severity breakdown
        severity_counts = {}
        for severity in IncidentSeverity:
            severity_counts[severity.value] = sum(
                1 for incident in self.incidents.values()
                if incident.severity == severity
            )
        
        # SLA compliance
        resolved_incidents = [
            incident for incident in self.incidents.values()
            if incident.status == IncidentStatus.RESOLVED
        ]
        
        sla_compliant = sum(1 for incident in resolved_incidents if not incident.sla_breach)
        sla_compliance_rate = (sla_compliant / len(resolved_incidents) * 100) if resolved_incidents else 100
        
        # Average resolution time
        resolution_times = [
            incident.resolution_time.total_seconds() / 3600  # Convert to hours
            for incident in resolved_incidents
            if incident.resolution_time
        ]
        avg_resolution_time = sum(resolution_times) / len(resolution_times) if resolution_times else 0
        
        return {
            "total_incidents": total_incidents,
            "status_breakdown": status_counts,
            "severity_breakdown": severity_counts,
            "sla_compliance_rate": sla_compliance_rate,
            "average_resolution_time_hours": avg_resolution_time,
            "active_incidents": status_counts.get("new", 0) + status_counts.get("assigned", 0) + status_counts.get("in_progress", 0)
        }


# Global incident response system
incident_response = IncidentResponseSystem()


async def main():
    """Main incident response system entry point"""
    print("🚨 Incident Response System - Phase 5 Critical Priority")
    print("24/7 Automated Incident Detection and Recovery Active")
    
    try:
        # Keep system running
        while True:
            await asyncio.sleep(3600)  # Sleep for 1 hour
            
            # Print periodic statistics
            stats = incident_response.get_incident_statistics()
            logger.info(f"Incident Response Statistics: {stats}")
            
    except KeyboardInterrupt:
        print("\n⚠️ Incident Response System stopped by user")
        incident_response.monitoring_active = False


if __name__ == "__main__":
    asyncio.run(main())