#!/usr/bin/env python3
"""
Microsoft 365 Management Tools - インシデント対応システム
自動エスカレーション・復旧ワークフロー・24/7運用対応
"""

import asyncio
import time
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Callable
from pathlib import Path
import smtplib
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
import sqlite3
import threading
from dataclasses import dataclass, asdict
from enum import Enum
import subprocess
import requests
import sys

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))


class IncidentSeverity(Enum):
    """インシデント重要度"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"
    EMERGENCY = "emergency"


class IncidentStatus(Enum):
    """インシデント状態"""
    OPEN = "open"
    ACKNOWLEDGED = "acknowledged"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"


class EscalationLevel(Enum):
    """エスカレーションレベル"""
    L1_SUPPORT = "l1_support"
    L2_TECHNICAL = "l2_technical"
    L3_SENIOR = "l3_senior"
    MANAGEMENT = "management"
    EXECUTIVE = "executive"


@dataclass
class Incident:
    """インシデント定義"""
    id: str
    title: str
    description: str
    severity: IncidentSeverity
    status: IncidentStatus
    affected_services: List[str]
    created_at: datetime
    updated_at: datetime
    assigned_to: Optional[str] = None
    escalation_level: EscalationLevel = EscalationLevel.L1_SUPPORT
    resolution_time: Optional[datetime] = None
    root_cause: Optional[str] = None
    actions_taken: List[str] = None
    metrics: Dict[str, Any] = None

    def __post_init__(self):
        if self.actions_taken is None:
            self.actions_taken = []
        if self.metrics is None:
            self.metrics = {}


@dataclass
class EscalationRule:
    """エスカレーションルール"""
    severity: IncidentSeverity
    initial_response_time_minutes: int
    escalation_time_minutes: int
    notification_channels: List[str]
    auto_actions: List[str]


class IncidentResponseSystem:
    """インシデント対応システム"""
    
    def __init__(self, config_path: str = None):
        self.config = self._load_config(config_path)
        self.incidents_db = self._init_incidents_database()
        self.active_incidents: Dict[str, Incident] = {}
        self.escalation_rules = self._load_escalation_rules()
        self.notification_handlers = self._init_notification_handlers()
        self.auto_recovery_handlers = self._init_auto_recovery_handlers()
        self.response_active = False
        
        # ログ設定
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('Tests/production_enterprise/logs/incident_response.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """設定ファイル読み込み"""
        default_config = {
            "escalation": {
                "response_time_minutes": {
                    "low": 60,
                    "medium": 30,
                    "high": 15,
                    "critical": 5,
                    "emergency": 2
                },
                "escalation_time_minutes": {
                    "low": 240,
                    "medium": 120,
                    "high": 60,
                    "critical": 30,
                    "emergency": 15
                }
            },
            "notifications": {
                "email": {
                    "enabled": True,
                    "smtp_server": "smtp.company.com",
                    "l1_support": ["support@company.com"],
                    "l2_technical": ["tech-lead@company.com"],
                    "l3_senior": ["senior-eng@company.com"],
                    "management": ["manager@company.com"],
                    "executive": ["cto@company.com", "ceo@company.com"]
                },
                "slack": {
                    "enabled": True,
                    "channels": {
                        "alerts": "#alerts",
                        "incidents": "#incidents",
                        "critical": "#critical-incidents"
                    }
                },
                "sms": {
                    "enabled": True,
                    "critical_contacts": ["+1234567890", "+0987654321"]
                }
            },
            "auto_recovery": {
                "enabled": True,
                "max_retry_attempts": 3,
                "retry_interval_seconds": 60,
                "safe_mode_threshold": 5
            },
            "sla": {
                "response_times": {
                    "emergency": 5,  # 5分以内
                    "critical": 15,  # 15分以内
                    "high": 60,      # 1時間以内
                    "medium": 240,   # 4時間以内
                    "low": 480       # 8時間以内
                },
                "resolution_times": {
                    "emergency": 60,   # 1時間以内
                    "critical": 240,   # 4時間以内
                    "high": 480,       # 8時間以内
                    "medium": 1440,    # 24時間以内
                    "low": 2880        # 48時間以内
                }
            }
        }
        
        if config_path and Path(config_path).exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                user_config = json.load(f)
                default_config.update(user_config)
        
        return default_config
    
    def _init_incidents_database(self) -> sqlite3.Connection:
        """インシデントデータベース初期化"""
        db_path = Path("Tests/production_enterprise/incidents.db")
        db_path.parent.mkdir(parents=True, exist_ok=True)
        
        conn = sqlite3.connect(str(db_path), check_same_thread=False)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS incidents (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                severity TEXT NOT NULL,
                status TEXT NOT NULL,
                affected_services TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                assigned_to TEXT,
                escalation_level TEXT NOT NULL,
                resolution_time TEXT,
                root_cause TEXT,
                actions_taken TEXT,
                metrics TEXT
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS incident_timeline (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                incident_id TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                event_type TEXT NOT NULL,
                description TEXT NOT NULL,
                user_id TEXT,
                FOREIGN KEY (incident_id) REFERENCES incidents (id)
            )
        ''')
        
        conn.commit()
        return conn
    
    def _load_escalation_rules(self) -> Dict[IncidentSeverity, EscalationRule]:
        """エスカレーションルール読み込み"""
        rules = {}
        
        for severity in IncidentSeverity:
            rules[severity] = EscalationRule(
                severity=severity,
                initial_response_time_minutes=self.config["escalation"]["response_time_minutes"][severity.value],
                escalation_time_minutes=self.config["escalation"]["escalation_time_minutes"][severity.value],
                notification_channels=["email", "slack"] if severity in [IncidentSeverity.HIGH, IncidentSeverity.CRITICAL, IncidentSeverity.EMERGENCY] else ["email"],
                auto_actions=["auto_recovery"] if severity in [IncidentSeverity.CRITICAL, IncidentSeverity.EMERGENCY] else []
            )
        
        return rules
    
    def _init_notification_handlers(self) -> Dict[str, Callable]:
        """通知ハンドラー初期化"""
        return {
            'email': self._send_email_notification,
            'slack': self._send_slack_notification,
            'sms': self._send_sms_notification
        }
    
    def _init_auto_recovery_handlers(self) -> Dict[str, Callable]:
        """自動復旧ハンドラー初期化"""
        return {
            'restart_service': self._restart_service,
            'scale_resources': self._scale_resources,
            'clear_cache': self._clear_cache,
            'reset_connections': self._reset_connections,
            'failover_database': self._failover_database
        }
    
    async def start_incident_response(self):
        """インシデント対応システム開始"""
        self.response_active = True
        self.logger.info("🚨 インシデント対応システム開始 - 24/7エスカレーション体制開始")
        
        # 並列処理タスクを開始
        response_tasks = [
            self._incident_monitor(),
            self._escalation_processor(),
            self._auto_recovery_monitor(),
            self._sla_compliance_monitor()
        ]
        
        await asyncio.gather(*response_tasks)
    
    async def stop_incident_response(self):
        """インシデント対応システム停止"""
        self.response_active = False
        self.logger.info("インシデント対応システム停止")
        
        # データベース接続クローズ
        self.incidents_db.close()
    
    async def create_incident(self, title: str, description: str, severity: IncidentSeverity, 
                            affected_services: List[str], metrics: Dict[str, Any] = None) -> str:
        """インシデント作成"""
        incident_id = f"INC_{int(time.time())}"
        
        incident = Incident(
            id=incident_id,
            title=title,
            description=description,
            severity=severity,
            status=IncidentStatus.OPEN,
            affected_services=affected_services,
            created_at=datetime.now(),
            updated_at=datetime.now(),
            metrics=metrics or {}
        )
        
        # アクティブインシデントに追加
        self.active_incidents[incident_id] = incident
        
        # データベースに保存
        await self._store_incident(incident)
        
        # タイムライン記録
        await self._add_timeline_event(incident_id, "created", f"インシデント作成: {title}")
        
        # 初期通知
        await self._send_incident_notifications(incident, "created")
        
        # 自動アクションの実行
        if severity in [IncidentSeverity.CRITICAL, IncidentSeverity.EMERGENCY]:
            await self._execute_auto_actions(incident)
        
        self.logger.critical(f"🚨 インシデント作成: [{severity.value.upper()}] {title} - ID: {incident_id}")
        
        return incident_id
    
    async def update_incident_status(self, incident_id: str, status: IncidentStatus, 
                                   assigned_to: str = None, notes: str = None):
        """インシデントステータス更新"""
        if incident_id not in self.active_incidents:
            raise ValueError(f"インシデントが見つかりません: {incident_id}")
        
        incident = self.active_incidents[incident_id]
        old_status = incident.status
        
        incident.status = status
        incident.updated_at = datetime.now()
        
        if assigned_to:
            incident.assigned_to = assigned_to
        
        if status == IncidentStatus.RESOLVED:
            incident.resolution_time = datetime.now()
        
        # データベース更新
        await self._update_incident_in_db(incident)
        
        # タイムライン記録
        status_message = f"ステータス変更: {old_status.value} → {status.value}"
        if notes:
            status_message += f" - {notes}"
        await self._add_timeline_event(incident_id, "status_updated", status_message, assigned_to)
        
        # ステータス変更通知
        await self._send_incident_notifications(incident, "status_updated")
        
        if status == IncidentStatus.CLOSED:
            # クローズしたインシデントをアクティブリストから削除
            del self.active_incidents[incident_id]
        
        self.logger.info(f"インシデントステータス更新: {incident_id} - {status.value}")
    
    async def escalate_incident(self, incident_id: str, reason: str = "自動エスカレーション"):
        """インシデントエスカレーション"""
        if incident_id not in self.active_incidents:
            return
        
        incident = self.active_incidents[incident_id]
        
        # エスカレーションレベルを上げる
        current_level = incident.escalation_level
        new_level = self._get_next_escalation_level(current_level)
        
        if new_level == current_level:
            return  # これ以上エスカレーションできない
        
        incident.escalation_level = new_level
        incident.updated_at = datetime.now()
        
        # データベース更新
        await self._update_incident_in_db(incident)
        
        # タイムライン記録
        await self._add_timeline_event(incident_id, "escalated", f"エスカレーション: {current_level.value} → {new_level.value} - {reason}")
        
        # エスカレーション通知
        await self._send_escalation_notifications(incident, reason)
        
        self.logger.warning(f"🆘 インシデントエスカレーション: {incident_id} - {new_level.value}")
    
    def _get_next_escalation_level(self, current_level: EscalationLevel) -> EscalationLevel:
        """次のエスカレーションレベル取得"""
        escalation_order = [
            EscalationLevel.L1_SUPPORT,
            EscalationLevel.L2_TECHNICAL,
            EscalationLevel.L3_SENIOR,
            EscalationLevel.MANAGEMENT,
            EscalationLevel.EXECUTIVE
        ]
        
        try:
            current_index = escalation_order.index(current_level)
            if current_index < len(escalation_order) - 1:
                return escalation_order[current_index + 1]
        except ValueError:
            pass
        
        return current_level
    
    async def _incident_monitor(self):
        """インシデント監視ループ"""
        while self.response_active:
            try:
                current_time = datetime.now()
                
                for incident_id, incident in list(self.active_incidents.items()):
                    # 応答時間SLA チェック
                    await self._check_response_sla(incident, current_time)
                    
                    # 解決時間SLA チェック
                    await self._check_resolution_sla(incident, current_time)
                    
                    # 自動エスカレーションチェック
                    await self._check_auto_escalation(incident, current_time)
                
                await asyncio.sleep(60)  # 1分間隔
            
            except Exception as e:
                self.logger.error(f"インシデント監視エラー: {e}")
                await asyncio.sleep(10)
    
    async def _escalation_processor(self):
        """エスカレーション処理ループ"""
        while self.response_active:
            try:
                current_time = datetime.now()
                
                for incident_id, incident in list(self.active_incidents.items()):
                    if incident.status not in [IncidentStatus.RESOLVED, IncidentStatus.CLOSED]:
                        time_since_created = (current_time - incident.created_at).total_seconds() / 60
                        escalation_rule = self.escalation_rules[incident.severity]
                        
                        # エスカレーション時間を過ぎている場合
                        if time_since_created > escalation_rule.escalation_time_minutes:
                            await self.escalate_incident(incident_id, f"タイムアウト({escalation_rule.escalation_time_minutes}分経過)")
                
                await asyncio.sleep(300)  # 5分間隔
            
            except Exception as e:
                self.logger.error(f"エスカレーション処理エラー: {e}")
                await asyncio.sleep(30)
    
    async def _auto_recovery_monitor(self):
        """自動復旧監視ループ"""
        while self.response_active:
            try:
                for incident_id, incident in list(self.active_incidents.items()):
                    if incident.severity in [IncidentSeverity.CRITICAL, IncidentSeverity.EMERGENCY]:
                        if incident.status == IncidentStatus.OPEN:
                            await self._attempt_auto_recovery(incident)
                
                await asyncio.sleep(120)  # 2分間隔
            
            except Exception as e:
                self.logger.error(f"自動復旧監視エラー: {e}")
                await asyncio.sleep(30)
    
    async def _sla_compliance_monitor(self):
        """SLA準拠監視ループ"""
        while self.response_active:
            try:
                sla_violations = await self._check_sla_violations()
                
                if sla_violations:
                    await self._handle_sla_violations(sla_violations)
                
                await asyncio.sleep(600)  # 10分間隔
            
            except Exception as e:
                self.logger.error(f"SLA準拠監視エラー: {e}")
                await asyncio.sleep(60)
    
    async def _check_response_sla(self, incident: Incident, current_time: datetime):
        """応答時間SLA チェック"""
        response_limit = self.config["sla"]["response_times"][incident.severity.value]
        time_since_created = (current_time - incident.created_at).total_seconds() / 60
        
        if incident.status == IncidentStatus.OPEN and time_since_created > response_limit:
            await self._add_timeline_event(
                incident.id, 
                "sla_violation", 
                f"応答時間SLA違反: {time_since_created:.1f}分 > {response_limit}分"
            )
            await self.escalate_incident(incident.id, f"応答時間SLA違反({response_limit}分)")
    
    async def _check_resolution_sla(self, incident: Incident, current_time: datetime):
        """解決時間SLA チェック"""
        resolution_limit = self.config["sla"]["resolution_times"][incident.severity.value]
        time_since_created = (current_time - incident.created_at).total_seconds() / 60
        
        if incident.status not in [IncidentStatus.RESOLVED, IncidentStatus.CLOSED] and time_since_created > resolution_limit:
            await self._add_timeline_event(
                incident.id,
                "sla_violation",
                f"解決時間SLA違反: {time_since_created:.1f}分 > {resolution_limit}分"
            )
            await self.escalate_incident(incident.id, f"解決時間SLA違反({resolution_limit}分)")
    
    async def _check_auto_escalation(self, incident: Incident, current_time: datetime):
        """自動エスカレーションチェック"""
        escalation_rule = self.escalation_rules[incident.severity]
        time_since_updated = (current_time - incident.updated_at).total_seconds() / 60
        
        if time_since_updated > escalation_rule.escalation_time_minutes:
            await self.escalate_incident(incident.id, "更新がないため自動エスカレーション")
    
    async def _execute_auto_actions(self, incident: Incident):
        """自動アクション実行"""
        escalation_rule = self.escalation_rules[incident.severity]
        
        for action in escalation_rule.auto_actions:
            if action == "auto_recovery":
                await self._attempt_auto_recovery(incident)
    
    async def _attempt_auto_recovery(self, incident: Incident):
        """自動復旧試行"""
        try:
            recovery_actions = []
            
            # サービス別の復旧アクション
            for service in incident.affected_services:
                if "api" in service.lower():
                    recovery_actions.append("restart_service")
                elif "database" in service.lower():
                    recovery_actions.append("reset_connections")
                elif "memory" in incident.description.lower():
                    recovery_actions.append("clear_cache")
                elif "cpu" in incident.description.lower():
                    recovery_actions.append("scale_resources")
            
            # 復旧アクション実行
            for action in recovery_actions:
                if action in self.auto_recovery_handlers:
                    success = await self.auto_recovery_handlers[action](incident)
                    
                    action_message = f"自動復旧試行: {action} - {'成功' if success else '失敗'}"
                    incident.actions_taken.append(action_message)
                    
                    await self._add_timeline_event(incident.id, "auto_recovery", action_message)
                    
                    if success:
                        # 復旧検証
                        if await self._verify_recovery(incident):
                            await self.update_incident_status(
                                incident.id, 
                                IncidentStatus.RESOLVED, 
                                notes="自動復旧により解決"
                            )
                            return True
        
        except Exception as e:
            self.logger.error(f"自動復旧エラー: {e}")
        
        return False
    
    async def _verify_recovery(self, incident: Incident) -> bool:
        """復旧検証"""
        # サービスヘルスチェック
        for service in incident.affected_services:
            if not await self._check_service_health(service):
                return False
        
        return True
    
    async def _check_service_health(self, service: str) -> bool:
        """サービスヘルスチェック"""
        try:
            if "api" in service.lower():
                response = requests.get("http://localhost:8000/health", timeout=5)
                return response.status_code == 200
            elif "database" in service.lower():
                # データベースヘルスチェック
                return True  # シミュレーション
            else:
                return True  # その他のサービス
        except:
            return False
    
    async def _restart_service(self, incident: Incident) -> bool:
        """サービス再起動"""
        try:
            # サービス再起動のシミュレーション
            await asyncio.sleep(2)
            return True
        except Exception as e:
            self.logger.error(f"サービス再起動エラー: {e}")
            return False
    
    async def _scale_resources(self, incident: Incident) -> bool:
        """リソーススケーリング"""
        try:
            # リソーススケーリングのシミュレーション
            await asyncio.sleep(3)
            return True
        except Exception as e:
            self.logger.error(f"リソーススケーリングエラー: {e}")
            return False
    
    async def _clear_cache(self, incident: Incident) -> bool:
        """キャッシュクリア"""
        try:
            # キャッシュクリアのシミュレーション
            await asyncio.sleep(1)
            return True
        except Exception as e:
            self.logger.error(f"キャッシュクリアエラー: {e}")
            return False
    
    async def _reset_connections(self, incident: Incident) -> bool:
        """接続リセット"""
        try:
            # 接続リセットのシミュレーション
            await asyncio.sleep(2)
            return True
        except Exception as e:
            self.logger.error(f"接続リセットエラー: {e}")
            return False
    
    async def _failover_database(self, incident: Incident) -> bool:
        """データベースフェイルオーバー"""
        try:
            # データベースフェイルオーバーのシミュレーション
            await asyncio.sleep(5)
            return True
        except Exception as e:
            self.logger.error(f"データベースフェイルオーバーエラー: {e}")
            return False
    
    async def _store_incident(self, incident: Incident):
        """インシデント保存"""
        try:
            cursor = self.incidents_db.cursor()
            cursor.execute('''
                INSERT INTO incidents 
                (id, title, description, severity, status, affected_services, created_at, 
                 updated_at, assigned_to, escalation_level, resolution_time, root_cause, 
                 actions_taken, metrics)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                incident.id,
                incident.title,
                incident.description,
                incident.severity.value,
                incident.status.value,
                json.dumps(incident.affected_services),
                incident.created_at.isoformat(),
                incident.updated_at.isoformat(),
                incident.assigned_to,
                incident.escalation_level.value,
                incident.resolution_time.isoformat() if incident.resolution_time else None,
                incident.root_cause,
                json.dumps(incident.actions_taken),
                json.dumps(incident.metrics)
            ))
            self.incidents_db.commit()
        
        except Exception as e:
            self.logger.error(f"インシデント保存エラー: {e}")
    
    async def _update_incident_in_db(self, incident: Incident):
        """インシデントDB更新"""
        try:
            cursor = self.incidents_db.cursor()
            cursor.execute('''
                UPDATE incidents 
                SET status = ?, updated_at = ?, assigned_to = ?, escalation_level = ?, 
                    resolution_time = ?, root_cause = ?, actions_taken = ?, metrics = ?
                WHERE id = ?
            ''', (
                incident.status.value,
                incident.updated_at.isoformat(),
                incident.assigned_to,
                incident.escalation_level.value,
                incident.resolution_time.isoformat() if incident.resolution_time else None,
                incident.root_cause,
                json.dumps(incident.actions_taken),
                json.dumps(incident.metrics),
                incident.id
            ))
            self.incidents_db.commit()
        
        except Exception as e:
            self.logger.error(f"インシデント更新エラー: {e}")
    
    async def _add_timeline_event(self, incident_id: str, event_type: str, description: str, user_id: str = None):
        """タイムラインイベント追加"""
        try:
            cursor = self.incidents_db.cursor()
            cursor.execute('''
                INSERT INTO incident_timeline 
                (incident_id, timestamp, event_type, description, user_id)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                incident_id,
                datetime.now().isoformat(),
                event_type,
                description,
                user_id
            ))
            self.incidents_db.commit()
        
        except Exception as e:
            self.logger.error(f"タイムラインイベント追加エラー: {e}")
    
    async def _send_incident_notifications(self, incident: Incident, event_type: str):
        """インシデント通知送信"""
        escalation_rule = self.escalation_rules[incident.severity]
        
        # 通知チャンネルごとに送信
        for channel in escalation_rule.notification_channels:
            if channel in self.notification_handlers:
                await self.notification_handlers[channel](incident, event_type)
    
    async def _send_escalation_notifications(self, incident: Incident, reason: str):
        """エスカレーション通知送信"""
        # より高いレベルの担当者に通知
        await self._send_email_notification(incident, "escalated", reason)
        await self._send_slack_notification(incident, "escalated", reason)
        
        # Critical/Emergencyの場合はSMS通知
        if incident.severity in [IncidentSeverity.CRITICAL, IncidentSeverity.EMERGENCY]:
            await self._send_sms_notification(incident, "escalated", reason)
    
    async def _send_email_notification(self, incident: Incident, event_type: str, additional_info: str = None):
        """メール通知送信"""
        try:
            recipients = self._get_notification_recipients(incident.escalation_level)
            
            subject = f"[{incident.severity.value.upper()}] Microsoft 365インシデント: {incident.title}"
            
            body = f"""
            🚨 Microsoft 365管理システム インシデント通知
            
            インシデントID: {incident.id}
            タイトル: {incident.title}
            重要度: {incident.severity.value.upper()}
            ステータス: {incident.status.value}
            影響サービス: {', '.join(incident.affected_services)}
            発生時刻: {incident.created_at.strftime('%Y-%m-%d %H:%M:%S')}
            更新時刻: {incident.updated_at.strftime('%Y-%m-%d %H:%M:%S')}
            担当者: {incident.assigned_to or '未割り当て'}
            エスカレーションレベル: {incident.escalation_level.value}
            
            説明: {incident.description}
            """
            
            if additional_info:
                body += f"\n追加情報: {additional_info}"
            
            if incident.actions_taken:
                body += f"\n\n実行済みアクション:\n" + "\n".join(f"- {action}" for action in incident.actions_taken)
            
            self.logger.info(f"📧 メール通知送信: {incident.id} - {event_type}")
        
        except Exception as e:
            self.logger.error(f"メール通知送信エラー: {e}")
    
    async def _send_slack_notification(self, incident: Incident, event_type: str, additional_info: str = None):
        """Slack通知送信"""
        try:
            emoji_map = {
                IncidentSeverity.LOW: "🔵",
                IncidentSeverity.MEDIUM: "🟡",
                IncidentSeverity.HIGH: "🟠",
                IncidentSeverity.CRITICAL: "🔴",
                IncidentSeverity.EMERGENCY: "🆘"
            }
            
            channel = "#critical-incidents" if incident.severity in [IncidentSeverity.CRITICAL, IncidentSeverity.EMERGENCY] else "#incidents"
            
            self.logger.info(f"📱 Slack通知送信: {incident.id} - {event_type} - {channel}")
        
        except Exception as e:
            self.logger.error(f"Slack通知送信エラー: {e}")
    
    async def _send_sms_notification(self, incident: Incident, event_type: str, additional_info: str = None):
        """SMS通知送信"""
        try:
            message = f"🚨 Microsoft 365 Critical Incident: {incident.title} - ID: {incident.id}"
            
            self.logger.info(f"📱 SMS通知送信: {incident.id} - {event_type}")
        
        except Exception as e:
            self.logger.error(f"SMS通知送信エラー: {e}")
    
    def _get_notification_recipients(self, escalation_level: EscalationLevel) -> List[str]:
        """通知宛先取得"""
        email_config = self.config["notifications"]["email"]
        
        return {
            EscalationLevel.L1_SUPPORT: email_config["l1_support"],
            EscalationLevel.L2_TECHNICAL: email_config["l2_technical"],
            EscalationLevel.L3_SENIOR: email_config["l3_senior"],
            EscalationLevel.MANAGEMENT: email_config["management"],
            EscalationLevel.EXECUTIVE: email_config["executive"]
        }.get(escalation_level, email_config["l1_support"])
    
    async def _check_sla_violations(self) -> List[Dict[str, Any]]:
        """SLA違反チェック"""
        violations = []
        current_time = datetime.now()
        
        for incident_id, incident in self.active_incidents.items():
            # 応答時間SLA
            response_limit = self.config["sla"]["response_times"][incident.severity.value]
            time_since_created = (current_time - incident.created_at).total_seconds() / 60
            
            if incident.status == IncidentStatus.OPEN and time_since_created > response_limit:
                violations.append({
                    "incident_id": incident_id,
                    "type": "response_time",
                    "limit": response_limit,
                    "actual": time_since_created
                })
            
            # 解決時間SLA
            resolution_limit = self.config["sla"]["resolution_times"][incident.severity.value]
            
            if incident.status not in [IncidentStatus.RESOLVED, IncidentStatus.CLOSED] and time_since_created > resolution_limit:
                violations.append({
                    "incident_id": incident_id,
                    "type": "resolution_time",
                    "limit": resolution_limit,
                    "actual": time_since_created
                })
        
        return violations
    
    async def _handle_sla_violations(self, violations: List[Dict[str, Any]]):
        """SLA違反処理"""
        for violation in violations:
            incident_id = violation["incident_id"]
            await self.escalate_incident(incident_id, f"SLA違反: {violation['type']}")
    
    def get_incident_statistics(self) -> Dict[str, Any]:
        """インシデント統計取得"""
        stats = {
            "active_incidents": len(self.active_incidents),
            "by_severity": {},
            "by_status": {},
            "by_escalation_level": {}
        }
        
        for incident in self.active_incidents.values():
            # 重要度別統計
            severity = incident.severity.value
            stats["by_severity"][severity] = stats["by_severity"].get(severity, 0) + 1
            
            # ステータス別統計
            status = incident.status.value
            stats["by_status"][status] = stats["by_status"].get(status, 0) + 1
            
            # エスカレーションレベル別統計
            escalation = incident.escalation_level.value
            stats["by_escalation_level"][escalation] = stats["by_escalation_level"].get(escalation, 0) + 1
        
        return stats


async def main():
    """メイン実行関数"""
    incident_system = IncidentResponseSystem()
    
    try:
        # インシデント対応システム開始
        await incident_system.start_incident_response()
    except KeyboardInterrupt:
        print("\nインシデント対応システムを停止中...")
        await incident_system.stop_incident_response()
    except Exception as e:
        logging.error(f"インシデント対応システムエラー: {e}")
    finally:
        await incident_system.stop_incident_response()


if __name__ == "__main__":
    asyncio.run(main())