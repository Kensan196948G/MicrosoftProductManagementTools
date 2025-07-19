#!/usr/bin/env python3
"""
Audit Trail System - Phase 2 Enterprise Production
完全監査証跡・コンプライアンス対応・ISO27001/27002・SOX・GDPR対応
"""

import os
import logging
import json
import hashlib
import time
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, field, asdict
from enum import Enum
from pathlib import Path
import uuid
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

# Database
import sqlite3
import json
from contextlib import contextmanager

# Azure integration
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential

# Monitoring integration
from src.monitoring.azure_monitor_integration import AzureMonitorIntegration
from src.auth.azure_key_vault_auth import AzureKeyVaultAuth

logger = logging.getLogger(__name__)


class AuditEventType(Enum):
    """監査イベントタイプ"""
    LOGIN = "login"
    LOGOUT = "logout"
    ACCESS = "access"
    MODIFICATION = "modification"
    DELETION = "deletion"
    CREATION = "creation"
    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    CONFIGURATION_CHANGE = "configuration_change"
    DATA_EXPORT = "data_export"
    DATA_IMPORT = "data_import"
    SYSTEM_EVENT = "system_event"
    ERROR = "error"
    SECURITY_EVENT = "security_event"
    COMPLIANCE_EVENT = "compliance_event"


class AuditSeverity(Enum):
    """監査重要度"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ComplianceStandard(Enum):
    """コンプライアンス標準"""
    ISO27001 = "iso27001"
    ISO27002 = "iso27002"
    SOX = "sox"
    GDPR = "gdpr"
    HIPAA = "hipaa"
    PCI_DSS = "pci_dss"
    CUSTOM = "custom"


@dataclass
class AuditEvent:
    """監査イベント"""
    event_id: str
    event_type: AuditEventType
    timestamp: datetime
    user_id: str
    user_name: str
    resource: str
    action: str
    result: str
    severity: AuditSeverity
    source_ip: str
    user_agent: str
    session_id: str
    details: Dict[str, Any] = field(default_factory=dict)
    compliance_standards: List[ComplianceStandard] = field(default_factory=list)
    data_classification: str = "internal"
    retention_period: int = 2555  # 7年（デフォルト）
    encrypted: bool = False
    hash_value: str = ""
    
    def __post_init__(self):
        """初期化後処理"""
        if not self.event_id:
            self.event_id = str(uuid.uuid4())
        if not self.hash_value:
            self.hash_value = self._calculate_hash()
    
    def _calculate_hash(self) -> str:
        """イベントハッシュ計算"""
        # ハッシュ対象データ
        hash_data = f"{self.event_id}{self.event_type.value}{self.timestamp.isoformat()}{self.user_id}{self.resource}{self.action}{self.result}"
        
        # SHA-256ハッシュ
        return hashlib.sha256(hash_data.encode()).hexdigest()
    
    def to_dict(self) -> Dict[str, Any]:
        """辞書形式変換"""
        data = asdict(self)
        data['event_type'] = self.event_type.value
        data['severity'] = self.severity.value
        data['compliance_standards'] = [cs.value for cs in self.compliance_standards]
        data['timestamp'] = self.timestamp.isoformat()
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'AuditEvent':
        """辞書から作成"""
        data['event_type'] = AuditEventType(data['event_type'])
        data['severity'] = AuditSeverity(data['severity'])
        data['compliance_standards'] = [ComplianceStandard(cs) for cs in data['compliance_standards']]
        data['timestamp'] = datetime.fromisoformat(data['timestamp'])
        return cls(**data)


@dataclass
class ComplianceRule:
    """コンプライアンスルール"""
    rule_id: str
    name: str
    standard: ComplianceStandard
    description: str
    condition: str
    action: str
    enabled: bool = True
    severity: AuditSeverity = AuditSeverity.MEDIUM
    retention_period: int = 2555  # 7年
    notification_recipients: List[str] = field(default_factory=list)


@dataclass
class RetentionPolicy:
    """保持ポリシー"""
    policy_id: str
    name: str
    event_types: List[AuditEventType]
    retention_days: int
    archive_location: str
    encryption_required: bool = True
    compliance_standards: List[ComplianceStandard] = field(default_factory=list)


class AuditTrailSystem:
    """
    監査証跡システム
    完全監査証跡・コンプライアンス対応・改ざん防止・長期保存
    """
    
    def __init__(self,
                 db_path: str = "/app/data/audit_trail.db",
                 archive_path: str = "/app/data/audit_archive",
                 encryption_key: str = None,
                 azure_storage_connection: str = None,
                 azure_monitor: Optional[AzureMonitorIntegration] = None,
                 key_vault_auth: Optional[AzureKeyVaultAuth] = None,
                 enable_real_time_monitoring: bool = True,
                 batch_size: int = 100,
                 flush_interval: int = 60):
        """
        Initialize Audit Trail System
        
        Args:
            db_path: データベースパス
            archive_path: アーカイブパス
            encryption_key: 暗号化キー
            azure_storage_connection: Azure Storage接続文字列
            azure_monitor: Azure Monitor統合
            key_vault_auth: Azure Key Vault認証
            enable_real_time_monitoring: リアルタイム監視
            batch_size: バッチサイズ
            flush_interval: フラッシュ間隔（秒）
        """
        self.db_path = Path(db_path)
        self.archive_path = Path(archive_path)
        self.encryption_key = encryption_key
        self.azure_storage_connection = azure_storage_connection
        self.azure_monitor = azure_monitor
        self.key_vault_auth = key_vault_auth
        self.enable_real_time_monitoring = enable_real_time_monitoring
        self.batch_size = batch_size
        self.flush_interval = flush_interval
        
        # 暗号化設定
        self.cipher = self._initialize_encryption()
        
        # Azure Storage設定
        self.blob_client = self._initialize_azure_storage()
        
        # データベース初期化
        self._initialize_database()
        
        # コンプライアンスルール
        self.compliance_rules: Dict[str, ComplianceRule] = {}
        self.retention_policies: Dict[str, RetentionPolicy] = {}
        
        # バッファリング
        self.event_buffer: List[AuditEvent] = []
        self.buffer_lock = threading.Lock()
        
        # バックグラウンド処理
        self.flush_thread: Optional[threading.Thread] = None
        self.archive_thread: Optional[threading.Thread] = None
        self.running = False
        
        # 統計情報
        self.stats = {
            'total_events': 0,
            'events_by_type': {},
            'events_by_severity': {},
            'compliance_violations': 0,
            'last_flush': None,
            'last_archive': None
        }
        
        # デフォルト設定
        self._setup_default_compliance_rules()
        self._setup_default_retention_policies()
        
        logger.info("Audit Trail System initialized")
    
    def _initialize_encryption(self) -> Optional[Fernet]:
        """暗号化初期化"""
        try:
            if self.encryption_key:
                key = base64.urlsafe_b64encode(self.encryption_key.encode()[:32].ljust(32, b'\0'))
                return Fernet(key)
            elif self.key_vault_auth:
                # Key Vaultから暗号化キー取得
                vault_key = self.key_vault_auth.get_secret("audit-encryption-key")
                if vault_key:
                    key = base64.urlsafe_b64encode(vault_key.encode()[:32].ljust(32, b'\0'))
                    return Fernet(key)
            
            # デフォルト暗号化キー生成
            key = Fernet.generate_key()
            cipher = Fernet(key)
            
            # Key Vaultに保存
            if self.key_vault_auth:
                self.key_vault_auth.set_secret("audit-encryption-key", key.decode())
            
            logger.info("Audit encryption initialized")
            return cipher
            
        except Exception as e:
            logger.error(f"Failed to initialize encryption: {str(e)}")
            return None
    
    def _initialize_azure_storage(self) -> Optional[BlobServiceClient]:
        """Azure Storage初期化"""
        try:
            if self.azure_storage_connection:
                return BlobServiceClient.from_connection_string(self.azure_storage_connection)
            elif self.key_vault_auth:
                # Key Vaultから接続文字列取得
                connection_string = self.key_vault_auth.get_secret("audit-storage-connection-string")
                if connection_string:
                    return BlobServiceClient.from_connection_string(connection_string)
            
            # デフォルト認証
            return BlobServiceClient(
                account_url="https://audittrailstorage.blob.core.windows.net",
                credential=DefaultAzureCredential()
            )
            
        except Exception as e:
            logger.warning(f"Failed to initialize Azure Storage: {str(e)}")
            return None
    
    def _initialize_database(self):
        """データベース初期化"""
        try:
            # ディレクトリ作成
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
            
            with sqlite3.connect(str(self.db_path)) as conn:
                cursor = conn.cursor()
                
                # 監査イベントテーブル
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS audit_events (
                        event_id TEXT PRIMARY KEY,
                        event_type TEXT NOT NULL,
                        timestamp TEXT NOT NULL,
                        user_id TEXT NOT NULL,
                        user_name TEXT NOT NULL,
                        resource TEXT NOT NULL,
                        action TEXT NOT NULL,
                        result TEXT NOT NULL,
                        severity TEXT NOT NULL,
                        source_ip TEXT,
                        user_agent TEXT,
                        session_id TEXT,
                        details TEXT,
                        compliance_standards TEXT,
                        data_classification TEXT,
                        retention_period INTEGER,
                        encrypted INTEGER,
                        hash_value TEXT,
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # コンプライアンスルールテーブル
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS compliance_rules (
                        rule_id TEXT PRIMARY KEY,
                        name TEXT NOT NULL,
                        standard TEXT NOT NULL,
                        description TEXT,
                        condition TEXT,
                        action TEXT,
                        enabled INTEGER,
                        severity TEXT,
                        retention_period INTEGER,
                        notification_recipients TEXT,
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # 保持ポリシーテーブル
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS retention_policies (
                        policy_id TEXT PRIMARY KEY,
                        name TEXT NOT NULL,
                        event_types TEXT,
                        retention_days INTEGER,
                        archive_location TEXT,
                        encryption_required INTEGER,
                        compliance_standards TEXT,
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # インデックス作成
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_timestamp ON audit_events(timestamp)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_event_type ON audit_events(event_type)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_user_id ON audit_events(user_id)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_severity ON audit_events(severity)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_compliance ON audit_events(compliance_standards)')
                
                conn.commit()
                
            logger.info("Audit database initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize database: {str(e)}")
            raise
    
    def _setup_default_compliance_rules(self):
        """デフォルトコンプライアンスルール設定"""
        
        # ISO27001 - 情報セキュリティ管理
        self.add_compliance_rule(ComplianceRule(
            rule_id="iso27001_access_control",
            name="ISO27001 Access Control",
            standard=ComplianceStandard.ISO27001,
            description="Monitor all access control events",
            condition="event_type IN ('login', 'logout', 'access', 'authorization')",
            action="log_and_alert",
            severity=AuditSeverity.HIGH,
            retention_period=2555  # 7年
        ))
        
        # ISO27002 - 情報セキュリティ管理実践規範
        self.add_compliance_rule(ComplianceRule(
            rule_id="iso27002_data_protection",
            name="ISO27002 Data Protection",
            standard=ComplianceStandard.ISO27002,
            description="Monitor data modification and export events",
            condition="event_type IN ('modification', 'deletion', 'data_export')",
            action="log_and_encrypt",
            severity=AuditSeverity.HIGH,
            retention_period=2555
        ))
        
        # SOX - サーベンス・オクスリー法
        self.add_compliance_rule(ComplianceRule(
            rule_id="sox_financial_data",
            name="SOX Financial Data Access",
            standard=ComplianceStandard.SOX,
            description="Monitor financial data access and changes",
            condition="resource LIKE '%financial%' OR resource LIKE '%accounting%'",
            action="log_and_alert_immediate",
            severity=AuditSeverity.CRITICAL,
            retention_period=2555
        ))
        
        # GDPR - 一般データ保護規則
        self.add_compliance_rule(ComplianceRule(
            rule_id="gdpr_personal_data",
            name="GDPR Personal Data Processing",
            standard=ComplianceStandard.GDPR,
            description="Monitor personal data processing activities",
            condition="data_classification = 'personal' OR resource LIKE '%personal%'",
            action="log_and_notify_dpo",
            severity=AuditSeverity.HIGH,
            retention_period=2555
        ))
        
        logger.info("Default compliance rules configured")
    
    def _setup_default_retention_policies(self):
        """デフォルト保持ポリシー設定"""
        
        # 高セキュリティイベント - 7年保持
        self.add_retention_policy(RetentionPolicy(
            policy_id="high_security_events",
            name="High Security Events",
            event_types=[AuditEventType.SECURITY_EVENT, AuditEventType.AUTHENTICATION, AuditEventType.AUTHORIZATION],
            retention_days=2555,  # 7年
            archive_location="azure_storage",
            encryption_required=True,
            compliance_standards=[ComplianceStandard.ISO27001, ComplianceStandard.ISO27002]
        ))
        
        # 財務関連イベント - 7年保持
        self.add_retention_policy(RetentionPolicy(
            policy_id="financial_events",
            name="Financial Events",
            event_types=[AuditEventType.MODIFICATION, AuditEventType.ACCESS, AuditEventType.DATA_EXPORT],
            retention_days=2555,
            archive_location="azure_storage",
            encryption_required=True,
            compliance_standards=[ComplianceStandard.SOX]
        ))
        
        # 個人データ処理イベント - 7年保持
        self.add_retention_policy(RetentionPolicy(
            policy_id="personal_data_events",
            name="Personal Data Events",
            event_types=[AuditEventType.ACCESS, AuditEventType.MODIFICATION, AuditEventType.DATA_EXPORT],
            retention_days=2555,
            archive_location="azure_storage",
            encryption_required=True,
            compliance_standards=[ComplianceStandard.GDPR]
        ))
        
        # 一般システムイベント - 3年保持
        self.add_retention_policy(RetentionPolicy(
            policy_id="general_system_events",
            name="General System Events",
            event_types=[AuditEventType.SYSTEM_EVENT, AuditEventType.CONFIGURATION_CHANGE],
            retention_days=1095,  # 3年
            archive_location="local_storage",
            encryption_required=False
        ))
        
        logger.info("Default retention policies configured")
    
    def add_compliance_rule(self, rule: ComplianceRule):
        """コンプライアンスルール追加"""
        self.compliance_rules[rule.rule_id] = rule
        
        # データベースに保存
        try:
            with sqlite3.connect(str(self.db_path)) as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT OR REPLACE INTO compliance_rules
                    (rule_id, name, standard, description, condition, action, enabled, severity, retention_period, notification_recipients)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    rule.rule_id,
                    rule.name,
                    rule.standard.value,
                    rule.description,
                    rule.condition,
                    rule.action,
                    int(rule.enabled),
                    rule.severity.value,
                    rule.retention_period,
                    json.dumps(rule.notification_recipients)
                ))
                conn.commit()
        except Exception as e:
            logger.error(f"Failed to save compliance rule: {str(e)}")
        
        logger.info(f"Compliance rule added: {rule.rule_id}")
    
    def add_retention_policy(self, policy: RetentionPolicy):
        """保持ポリシー追加"""
        self.retention_policies[policy.policy_id] = policy
        
        # データベースに保存
        try:
            with sqlite3.connect(str(self.db_path)) as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT OR REPLACE INTO retention_policies
                    (policy_id, name, event_types, retention_days, archive_location, encryption_required, compliance_standards)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    policy.policy_id,
                    policy.name,
                    json.dumps([et.value for et in policy.event_types]),
                    policy.retention_days,
                    policy.archive_location,
                    int(policy.encryption_required),
                    json.dumps([cs.value for cs in policy.compliance_standards])
                ))
                conn.commit()
        except Exception as e:
            logger.error(f"Failed to save retention policy: {str(e)}")
        
        logger.info(f"Retention policy added: {policy.policy_id}")
    
    def log_event(self, event: AuditEvent):
        """監査イベントログ"""
        try:
            # 改ざん防止ハッシュ計算
            if not event.hash_value:
                event.hash_value = event._calculate_hash()
            
            # 暗号化
            if event.encrypted and self.cipher:
                # 機密データ暗号化
                if event.details:
                    event.details = json.loads(self.cipher.encrypt(json.dumps(event.details).encode()).decode())
                event.encrypted = True
            
            # コンプライアンスチェック
            self._check_compliance(event)
            
            # バッファに追加
            with self.buffer_lock:
                self.event_buffer.append(event)
                
                # バッファサイズチェック
                if len(self.event_buffer) >= self.batch_size:
                    self._flush_buffer()
            
            # 統計更新
            self.stats['total_events'] += 1
            self.stats['events_by_type'][event.event_type.value] = self.stats['events_by_type'].get(event.event_type.value, 0) + 1
            self.stats['events_by_severity'][event.severity.value] = self.stats['events_by_severity'].get(event.severity.value, 0) + 1
            
            # リアルタイム監視
            if self.enable_real_time_monitoring:
                self._real_time_monitoring(event)
            
            logger.debug(f"Audit event logged: {event.event_id}")
            
        except Exception as e:
            logger.error(f"Failed to log audit event: {str(e)}")
    
    def _check_compliance(self, event: AuditEvent):
        """コンプライアンスチェック"""
        try:
            for rule_id, rule in self.compliance_rules.items():
                if not rule.enabled:
                    continue
                
                # 条件チェック（簡易実装）
                if self._evaluate_condition(rule.condition, event):
                    # コンプライアンス標準追加
                    if rule.standard not in event.compliance_standards:
                        event.compliance_standards.append(rule.standard)
                    
                    # 重要度調整
                    if rule.severity.value == AuditSeverity.CRITICAL.value:
                        event.severity = AuditSeverity.CRITICAL
                    elif rule.severity.value == AuditSeverity.HIGH.value and event.severity.value != AuditSeverity.CRITICAL.value:
                        event.severity = AuditSeverity.HIGH
                    
                    # 保持期間調整
                    if rule.retention_period > event.retention_period:
                        event.retention_period = rule.retention_period
                    
                    # アクション実行
                    self._execute_compliance_action(rule, event)
                    
        except Exception as e:
            logger.error(f"Compliance check failed: {str(e)}")
    
    def _evaluate_condition(self, condition: str, event: AuditEvent) -> bool:
        """条件評価（簡易実装）"""
        try:
            # 基本的な条件評価
            if "event_type IN" in condition:
                # event_type IN ('login', 'logout', 'access')
                import re
                match = re.search(r"event_type IN \('([^']+)'(?:, '([^']+)')*\)", condition)
                if match:
                    types = [match.group(1)]
                    if match.group(2):
                        types.append(match.group(2))
                    return event.event_type.value in types
            
            elif "resource LIKE" in condition:
                # resource LIKE '%financial%'
                import re
                match = re.search(r"resource LIKE '([^']+)'", condition)
                if match:
                    pattern = match.group(1).replace('%', '.*')
                    return re.search(pattern, event.resource, re.IGNORECASE) is not None
            
            elif "data_classification" in condition:
                # data_classification = 'personal'
                return event.data_classification in condition
            
            return False
            
        except Exception as e:
            logger.error(f"Condition evaluation failed: {str(e)}")
            return False
    
    def _execute_compliance_action(self, rule: ComplianceRule, event: AuditEvent):
        """コンプライアンスアクション実行"""
        try:
            if rule.action == "log_and_alert":
                # アラート送信
                self._send_compliance_alert(rule, event)
            elif rule.action == "log_and_encrypt":
                # 暗号化強制
                event.encrypted = True
            elif rule.action == "log_and_alert_immediate":
                # 即座にアラート
                self._send_immediate_alert(rule, event)
            elif rule.action == "log_and_notify_dpo":
                # データ保護責任者通知
                self._notify_dpo(rule, event)
            
        except Exception as e:
            logger.error(f"Compliance action execution failed: {str(e)}")
    
    def _send_compliance_alert(self, rule: ComplianceRule, event: AuditEvent):
        """コンプライアンスアラート送信"""
        try:
            alert_data = {
                'rule_id': rule.rule_id,
                'rule_name': rule.name,
                'standard': rule.standard.value,
                'event_id': event.event_id,
                'event_type': event.event_type.value,
                'severity': event.severity.value,
                'user_id': event.user_id,
                'resource': event.resource,
                'action': event.action,
                'timestamp': event.timestamp.isoformat()
            }
            
            # Azure Monitor統合
            if self.azure_monitor:
                self.azure_monitor._send_custom_event("ComplianceAlert", alert_data)
            
            # メール通知（実装時に追加）
            for recipient in rule.notification_recipients:
                logger.info(f"Compliance alert sent to {recipient}: {rule.name}")
            
        except Exception as e:
            logger.error(f"Failed to send compliance alert: {str(e)}")
    
    def _send_immediate_alert(self, rule: ComplianceRule, event: AuditEvent):
        """即座アラート送信"""
        self._send_compliance_alert(rule, event)
        logger.warning(f"IMMEDIATE ALERT: {rule.name} - {event.event_id}")
    
    def _notify_dpo(self, rule: ComplianceRule, event: AuditEvent):
        """データ保護責任者通知"""
        logger.info(f"DPO Notification: {rule.name} - {event.event_id}")
        # 実際の実装では専用通知システムを使用
    
    def _real_time_monitoring(self, event: AuditEvent):
        """リアルタイム監視"""
        try:
            # 高重要度イベントの即座処理
            if event.severity in [AuditSeverity.HIGH, AuditSeverity.CRITICAL]:
                self._flush_buffer()
            
            # Azure Monitor統合
            if self.azure_monitor:
                self.azure_monitor._send_custom_event("AuditEvent", {
                    'event_id': event.event_id,
                    'event_type': event.event_type.value,
                    'severity': event.severity.value,
                    'user_id': event.user_id,
                    'resource': event.resource,
                    'compliance_standards': [cs.value for cs in event.compliance_standards]
                })
            
        except Exception as e:
            logger.error(f"Real-time monitoring failed: {str(e)}")
    
    def _flush_buffer(self):
        """バッファフラッシュ"""
        try:
            if not self.event_buffer:
                return
            
            with sqlite3.connect(str(self.db_path)) as conn:
                cursor = conn.cursor()
                
                for event in self.event_buffer:
                    cursor.execute('''
                        INSERT INTO audit_events
                        (event_id, event_type, timestamp, user_id, user_name, resource, action, result,
                         severity, source_ip, user_agent, session_id, details, compliance_standards,
                         data_classification, retention_period, encrypted, hash_value)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        event.event_id,
                        event.event_type.value,
                        event.timestamp.isoformat(),
                        event.user_id,
                        event.user_name,
                        event.resource,
                        event.action,
                        event.result,
                        event.severity.value,
                        event.source_ip,
                        event.user_agent,
                        event.session_id,
                        json.dumps(event.details),
                        json.dumps([cs.value for cs in event.compliance_standards]),
                        event.data_classification,
                        event.retention_period,
                        int(event.encrypted),
                        event.hash_value
                    ))
                
                conn.commit()
            
            logger.info(f"Flushed {len(self.event_buffer)} audit events to database")
            self.event_buffer.clear()
            self.stats['last_flush'] = datetime.utcnow()
            
        except Exception as e:
            logger.error(f"Failed to flush buffer: {str(e)}")
    
    def _flush_loop(self):
        """フラッシュループ"""
        while self.running:
            try:
                time.sleep(self.flush_interval)
                with self.buffer_lock:
                    if self.event_buffer:
                        self._flush_buffer()
            except Exception as e:
                logger.error(f"Flush loop error: {str(e)}")
    
    def _archive_old_events(self):
        """古いイベントのアーカイブ"""
        try:
            with sqlite3.connect(str(self.db_path)) as conn:
                cursor = conn.cursor()
                
                # 保持期間を過ぎたイベントを取得
                cutoff_date = datetime.utcnow() - timedelta(days=365)  # 1年前
                cursor.execute('''
                    SELECT * FROM audit_events
                    WHERE timestamp < ?
                    ORDER BY timestamp
                ''', (cutoff_date.isoformat(),))
                
                events_to_archive = cursor.fetchall()
                
                if events_to_archive:
                    # アーカイブファイル作成
                    archive_file = self.archive_path / f"audit_archive_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
                    self.archive_path.mkdir(parents=True, exist_ok=True)
                    
                    # アーカイブデータ準備
                    archive_data = []
                    for event_row in events_to_archive:
                        event_dict = {
                            'event_id': event_row[0],
                            'event_type': event_row[1],
                            'timestamp': event_row[2],
                            'user_id': event_row[3],
                            'user_name': event_row[4],
                            'resource': event_row[5],
                            'action': event_row[6],
                            'result': event_row[7],
                            'severity': event_row[8],
                            'source_ip': event_row[9],
                            'user_agent': event_row[10],
                            'session_id': event_row[11],
                            'details': event_row[12],
                            'compliance_standards': event_row[13],
                            'data_classification': event_row[14],
                            'retention_period': event_row[15],
                            'encrypted': event_row[16],
                            'hash_value': event_row[17]
                        }
                        archive_data.append(event_dict)
                    
                    # アーカイブファイル書き込み
                    with open(archive_file, 'w') as f:
                        json.dump(archive_data, f, indent=2)
                    
                    # 暗号化
                    if self.cipher:
                        encrypted_data = self.cipher.encrypt(archive_file.read_bytes())
                        encrypted_file = archive_file.with_suffix('.encrypted')
                        encrypted_file.write_bytes(encrypted_data)
                        archive_file.unlink()  # 元ファイル削除
                        archive_file = encrypted_file
                    
                    # Azure Storageにアップロード
                    if self.blob_client:
                        try:
                            blob_name = f"audit_archive/{archive_file.name}"
                            with open(archive_file, 'rb') as data:
                                self.blob_client.upload_blob(
                                    name=blob_name,
                                    data=data,
                                    overwrite=True
                                )
                            logger.info(f"Archived {len(events_to_archive)} events to Azure Storage")
                        except Exception as e:
                            logger.error(f"Failed to upload to Azure Storage: {str(e)}")
                    
                    # データベースから削除
                    cursor.execute('DELETE FROM audit_events WHERE timestamp < ?', (cutoff_date.isoformat(),))
                    conn.commit()
                    
                    logger.info(f"Archived {len(events_to_archive)} audit events")
                    self.stats['last_archive'] = datetime.utcnow()
                    
        except Exception as e:
            logger.error(f"Failed to archive events: {str(e)}")
    
    def _archive_loop(self):
        """アーカイブループ"""
        while self.running:
            try:
                time.sleep(86400)  # 24時間
                self._archive_old_events()
            except Exception as e:
                logger.error(f"Archive loop error: {str(e)}")
    
    def start(self):
        """監査システム開始"""
        if self.running:
            return
        
        self.running = True
        
        # フラッシュスレッド開始
        self.flush_thread = threading.Thread(target=self._flush_loop, daemon=True)
        self.flush_thread.start()
        
        # アーカイブスレッド開始
        self.archive_thread = threading.Thread(target=self._archive_loop, daemon=True)
        self.archive_thread.start()
        
        logger.info("Audit Trail System started")
    
    def stop(self):
        """監査システム停止"""
        if not self.running:
            return
        
        self.running = False
        
        # 残バッファをフラッシュ
        with self.buffer_lock:
            if self.event_buffer:
                self._flush_buffer()
        
        # スレッド停止
        if self.flush_thread:
            self.flush_thread.join(timeout=10)
        if self.archive_thread:
            self.archive_thread.join(timeout=10)
        
        logger.info("Audit Trail System stopped")
    
    def query_events(self, 
                    start_time: Optional[datetime] = None,
                    end_time: Optional[datetime] = None,
                    event_types: Optional[List[AuditEventType]] = None,
                    user_id: Optional[str] = None,
                    resource: Optional[str] = None,
                    severity: Optional[AuditSeverity] = None,
                    compliance_standards: Optional[List[ComplianceStandard]] = None,
                    limit: int = 100) -> List[AuditEvent]:
        """監査イベント検索"""
        try:
            query = "SELECT * FROM audit_events WHERE 1=1"
            params = []
            
            if start_time:
                query += " AND timestamp >= ?"
                params.append(start_time.isoformat())
            
            if end_time:
                query += " AND timestamp <= ?"
                params.append(end_time.isoformat())
            
            if event_types:
                placeholders = ','.join(['?' for _ in event_types])
                query += f" AND event_type IN ({placeholders})"
                params.extend([et.value for et in event_types])
            
            if user_id:
                query += " AND user_id = ?"
                params.append(user_id)
            
            if resource:
                query += " AND resource LIKE ?"
                params.append(f"%{resource}%")
            
            if severity:
                query += " AND severity = ?"
                params.append(severity.value)
            
            if compliance_standards:
                # JSON配列内の検索（簡易実装）
                for cs in compliance_standards:
                    query += " AND compliance_standards LIKE ?"
                    params.append(f"%{cs.value}%")
            
            query += " ORDER BY timestamp DESC LIMIT ?"
            params.append(limit)
            
            with sqlite3.connect(str(self.db_path)) as conn:
                cursor = conn.cursor()
                cursor.execute(query, params)
                rows = cursor.fetchall()
                
                events = []
                for row in rows:
                    event = AuditEvent(
                        event_id=row[0],
                        event_type=AuditEventType(row[1]),
                        timestamp=datetime.fromisoformat(row[2]),
                        user_id=row[3],
                        user_name=row[4],
                        resource=row[5],
                        action=row[6],
                        result=row[7],
                        severity=AuditSeverity(row[8]),
                        source_ip=row[9] or "",
                        user_agent=row[10] or "",
                        session_id=row[11] or "",
                        details=json.loads(row[12]) if row[12] else {},
                        compliance_standards=[ComplianceStandard(cs) for cs in json.loads(row[13])] if row[13] else [],
                        data_classification=row[14] or "internal",
                        retention_period=row[15] or 2555,
                        encrypted=bool(row[16]),
                        hash_value=row[17] or ""
                    )
                    events.append(event)
                
                return events
                
        except Exception as e:
            logger.error(f"Failed to query events: {str(e)}")
            return []
    
    def get_compliance_report(self, 
                            standard: ComplianceStandard,
                            start_time: Optional[datetime] = None,
                            end_time: Optional[datetime] = None) -> Dict[str, Any]:
        """コンプライアンスレポート生成"""
        try:
            # 期間設定
            if not start_time:
                start_time = datetime.utcnow() - timedelta(days=30)
            if not end_time:
                end_time = datetime.utcnow()
            
            # 関連イベント取得
            events = self.query_events(
                start_time=start_time,
                end_time=end_time,
                compliance_standards=[standard],
                limit=10000
            )
            
            # 統計分析
            total_events = len(events)
            events_by_type = {}
            events_by_severity = {}
            events_by_day = {}
            
            for event in events:
                # イベントタイプ別
                event_type = event.event_type.value
                events_by_type[event_type] = events_by_type.get(event_type, 0) + 1
                
                # 重要度別
                severity = event.severity.value
                events_by_severity[severity] = events_by_severity.get(severity, 0) + 1
                
                # 日別
                day = event.timestamp.strftime('%Y-%m-%d')
                events_by_day[day] = events_by_day.get(day, 0) + 1
            
            # 違反検出
            violations = []
            for event in events:
                if event.severity in [AuditSeverity.HIGH, AuditSeverity.CRITICAL]:
                    violations.append({
                        'event_id': event.event_id,
                        'timestamp': event.timestamp.isoformat(),
                        'user_id': event.user_id,
                        'resource': event.resource,
                        'action': event.action,
                        'severity': event.severity.value
                    })
            
            report = {
                'standard': standard.value,
                'period': {
                    'start_time': start_time.isoformat(),
                    'end_time': end_time.isoformat()
                },
                'summary': {
                    'total_events': total_events,
                    'total_violations': len(violations),
                    'compliance_rate': (total_events - len(violations)) / total_events if total_events > 0 else 1.0
                },
                'statistics': {
                    'events_by_type': events_by_type,
                    'events_by_severity': events_by_severity,
                    'events_by_day': events_by_day
                },
                'violations': violations[:100],  # 最新100件
                'generated_at': datetime.utcnow().isoformat()
            }
            
            return report
            
        except Exception as e:
            logger.error(f"Failed to generate compliance report: {str(e)}")
            return {}
    
    def get_audit_statistics(self) -> Dict[str, Any]:
        """監査統計情報取得"""
        return {
            'system_status': {
                'running': self.running,
                'buffer_size': len(self.event_buffer),
                'database_path': str(self.db_path),
                'archive_path': str(self.archive_path),
                'encryption_enabled': self.cipher is not None,
                'azure_storage_enabled': self.blob_client is not None
            },
            'statistics': self.stats,
            'compliance_rules': len(self.compliance_rules),
            'retention_policies': len(self.retention_policies)
        }
    
    def close(self):
        """監査システム終了"""
        try:
            self.stop()
            
            # Azure Storage接続終了
            if self.blob_client:
                self.blob_client.close()
            
            logger.info("Audit Trail System closed")
            
        except Exception as e:
            logger.error(f"Error closing Audit Trail System: {str(e)}")
    
    def __enter__(self):
        """Context manager entry"""
        self.start()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


# 便利関数
def create_audit_event(event_type: AuditEventType,
                      user_id: str,
                      user_name: str,
                      resource: str,
                      action: str,
                      result: str,
                      severity: AuditSeverity = AuditSeverity.MEDIUM,
                      source_ip: str = "",
                      user_agent: str = "",
                      session_id: str = "",
                      details: Dict[str, Any] = None,
                      data_classification: str = "internal") -> AuditEvent:
    """監査イベント作成ヘルパー"""
    return AuditEvent(
        event_id=str(uuid.uuid4()),
        event_type=event_type,
        timestamp=datetime.utcnow(),
        user_id=user_id,
        user_name=user_name,
        resource=resource,
        action=action,
        result=result,
        severity=severity,
        source_ip=source_ip,
        user_agent=user_agent,
        session_id=session_id,
        details=details or {},
        data_classification=data_classification
    )


if __name__ == "__main__":
    # テスト実行
    print("Testing Audit Trail System...")
    
    # 監査システム初期化
    with AuditTrailSystem() as audit_system:
        # テストイベント作成
        test_event = create_audit_event(
            event_type=AuditEventType.LOGIN,
            user_id="test_user",
            user_name="Test User",
            resource="Microsoft 365 Management System",
            action="login",
            result="success",
            severity=AuditSeverity.MEDIUM,
            source_ip="192.168.1.100",
            details={"browser": "Chrome", "os": "Windows 10"}
        )
        
        # イベントログ
        audit_system.log_event(test_event)
        
        # 少し待機
        time.sleep(2)
        
        # 検索テスト
        events = audit_system.query_events(
            event_types=[AuditEventType.LOGIN],
            user_id="test_user",
            limit=10
        )
        
        print(f"Found {len(events)} events")
        for event in events:
            print(f"  Event: {event.event_id} - {event.action} - {event.result}")
        
        # 統計情報
        stats = audit_system.get_audit_statistics()
        print(f"Audit Statistics: {json.dumps(stats, indent=2, default=str)}")
        
        # コンプライアンスレポート
        report = audit_system.get_compliance_report(ComplianceStandard.ISO27001)
        print(f"Compliance Report: {json.dumps(report, indent=2, default=str)}")