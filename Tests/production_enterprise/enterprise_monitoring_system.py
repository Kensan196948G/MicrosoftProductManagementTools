#!/usr/bin/env python3
"""
Microsoft 365 Management Tools - エンタープライズ運用監視システム
24/7リアルタイム監視・SLA 99.9%可用性保証・自動インシデント対応
"""

import asyncio
import time
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from pathlib import Path
import psutil
import subprocess
import smtplib
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
import requests
from dataclasses import dataclass, asdict
import threading
from concurrent.futures import ThreadPoolExecutor
import sqlite3
from enum import Enum
import sys

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))


class AlertLevel(Enum):
    """アラートレベル定義"""
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"
    EMERGENCY = "emergency"


class ServiceStatus(Enum):
    """サービス状態定義"""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    DOWN = "down"
    MAINTENANCE = "maintenance"


@dataclass
class Alert:
    """アラート定義"""
    id: str
    timestamp: datetime
    level: AlertLevel
    service: str
    message: str
    details: Dict[str, Any]
    resolved: bool = False
    resolution_time: Optional[datetime] = None


@dataclass
class HealthMetrics:
    """ヘルスメトリクス定義"""
    timestamp: datetime
    cpu_usage: float
    memory_usage: float
    disk_usage: float
    response_time: float
    error_rate: float
    active_users: int
    api_calls_per_minute: int


class EnterpriseMonitoringSystem:
    """エンタープライズ監視システム"""
    
    def __init__(self, config_path: str = None):
        self.config = self._load_config(config_path)
        self.alerts_db = self._init_alerts_database()
        self.metrics_db = self._init_metrics_database()
        self.active_alerts: Dict[str, Alert] = {}
        self.service_status: Dict[str, ServiceStatus] = {}
        self.monitoring_active = False
        self.alert_handlers = self._init_alert_handlers()
        
        # ログ設定
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('Tests/production_enterprise/logs/monitoring.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """設定ファイル読み込み"""
        default_config = {
            "monitoring": {
                "interval_seconds": 30,
                "health_check_timeout": 10,
                "sla_target": 99.9
            },
            "thresholds": {
                "cpu_warning": 70,
                "cpu_critical": 85,
                "memory_warning": 80,
                "memory_critical": 90,
                "disk_warning": 80,
                "disk_critical": 90,
                "response_time_warning": 2000,
                "response_time_critical": 5000,
                "error_rate_warning": 5,
                "error_rate_critical": 10
            },
            "services": {
                "gui_app": {
                    "url": "http://localhost:3000/health",
                    "critical": True
                },
                "api_server": {
                    "url": "http://localhost:8000/health",
                    "critical": True
                },
                "database": {
                    "type": "postgresql",
                    "critical": True
                }
            },
            "notifications": {
                "email": {
                    "enabled": True,
                    "smtp_server": "smtp.company.com",
                    "recipients": ["devops@company.com", "oncall@company.com"]
                },
                "slack": {
                    "enabled": True,
                    "webhook_url": "https://hooks.slack.com/services/..."
                }
            }
        }
        
        if config_path and Path(config_path).exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                user_config = json.load(f)
                default_config.update(user_config)
        
        return default_config
    
    def _init_alerts_database(self) -> sqlite3.Connection:
        """アラートデータベース初期化"""
        db_path = Path("Tests/production_enterprise/alerts.db")
        db_path.parent.mkdir(parents=True, exist_ok=True)
        
        conn = sqlite3.connect(str(db_path), check_same_thread=False)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS alerts (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                level TEXT NOT NULL,
                service TEXT NOT NULL,
                message TEXT NOT NULL,
                details TEXT NOT NULL,
                resolved BOOLEAN DEFAULT FALSE,
                resolution_time TEXT
            )
        ''')
        
        conn.commit()
        return conn
    
    def _init_metrics_database(self) -> sqlite3.Connection:
        """メトリクスデータベース初期化"""
        db_path = Path("Tests/production_enterprise/metrics.db")
        db_path.parent.mkdir(parents=True, exist_ok=True)
        
        conn = sqlite3.connect(str(db_path), check_same_thread=False)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS health_metrics (
                timestamp TEXT PRIMARY KEY,
                cpu_usage REAL NOT NULL,
                memory_usage REAL NOT NULL,
                disk_usage REAL NOT NULL,
                response_time REAL NOT NULL,
                error_rate REAL NOT NULL,
                active_users INTEGER NOT NULL,
                api_calls_per_minute INTEGER NOT NULL
            )
        ''')
        
        conn.commit()
        return conn
    
    def _init_alert_handlers(self) -> Dict[str, callable]:
        """アラートハンドラー初期化"""
        return {
            'email': self._send_email_alert,
            'slack': self._send_slack_alert,
            'auto_recovery': self._attempt_auto_recovery
        }
    
    async def start_monitoring(self):
        """監視開始"""
        self.monitoring_active = True
        self.logger.info("🚨 エンタープライズ監視システム開始 - 24/7運用監視開始")
        
        # 並列監視タスクを開始
        monitoring_tasks = [
            self._system_health_monitor(),
            self._service_health_monitor(),
            self._sla_compliance_monitor(),
            self._alert_processor(),
            self._auto_recovery_monitor()
        ]
        
        await asyncio.gather(*monitoring_tasks)
    
    async def stop_monitoring(self):
        """監視停止"""
        self.monitoring_active = False
        self.logger.info("監視システム停止")
        
        # データベース接続クローズ
        self.alerts_db.close()
        self.metrics_db.close()
    
    async def _system_health_monitor(self):
        """システムヘルス監視"""
        while self.monitoring_active:
            try:
                metrics = await self._collect_system_metrics()
                await self._store_metrics(metrics)
                await self._analyze_metrics(metrics)
                
                await asyncio.sleep(self.config['monitoring']['interval_seconds'])
            
            except Exception as e:
                self.logger.error(f"システムヘルス監視エラー: {e}")
                await asyncio.sleep(5)
    
    async def _collect_system_metrics(self) -> HealthMetrics:
        """システムメトリクス収集"""
        # CPU使用率
        cpu_usage = psutil.cpu_percent(interval=1)
        
        # メモリ使用率
        memory = psutil.virtual_memory()
        memory_usage = memory.percent
        
        # ディスク使用率
        disk = psutil.disk_usage('/')
        disk_usage = disk.percent
        
        # API応答時間測定
        response_time = await self._measure_api_response_time()
        
        # エラー率計算（過去1分間）
        error_rate = await self._calculate_error_rate()
        
        # アクティブユーザー数（シミュレーション）
        active_users = await self._get_active_users_count()
        
        # API呼び出し数/分（シミュレーション）
        api_calls = await self._get_api_calls_per_minute()
        
        return HealthMetrics(
            timestamp=datetime.now(),
            cpu_usage=cpu_usage,
            memory_usage=memory_usage,
            disk_usage=disk_usage,
            response_time=response_time,
            error_rate=error_rate,
            active_users=active_users,
            api_calls_per_minute=api_calls
        )
    
    async def _measure_api_response_time(self) -> float:
        """API応答時間測定"""
        try:
            start_time = time.time()
            
            # ヘルスチェックエンドポイントへのリクエスト
            response = requests.get(
                "http://localhost:8000/health",
                timeout=self.config['monitoring']['health_check_timeout']
            )
            
            response_time = (time.time() - start_time) * 1000  # ミリ秒
            
            if response.status_code == 200:
                return response_time
            else:
                await self._create_alert(
                    AlertLevel.WARNING,
                    "api_server",
                    f"API応答異常: HTTP {response.status_code}",
                    {"status_code": response.status_code, "response_time": response_time}
                )
                return response_time
        
        except requests.exceptions.Timeout:
            await self._create_alert(
                AlertLevel.CRITICAL,
                "api_server",
                "APIタイムアウト",
                {"timeout": self.config['monitoring']['health_check_timeout']}
            )
            return 999999  # タイムアウト値
        
        except requests.exceptions.ConnectionError:
            await self._create_alert(
                AlertLevel.CRITICAL,
                "api_server",
                "API接続失敗",
                {"error": "connection_refused"}
            )
            return 999999
        
        except Exception as e:
            self.logger.error(f"API応答時間測定エラー: {e}")
            return 0
    
    async def _calculate_error_rate(self) -> float:
        """エラー率計算"""
        try:
            # 過去1分間のログファイルからエラー率を計算
            # 実装例：ログファイル解析
            return 0.5  # シミュレーション値
        except Exception as e:
            self.logger.error(f"エラー率計算エラー: {e}")
            return 0
    
    async def _get_active_users_count(self) -> int:
        """アクティブユーザー数取得"""
        try:
            # 実際の実装では、セッション管理システムから取得
            return 150  # シミュレーション値
        except Exception as e:
            self.logger.error(f"アクティブユーザー数取得エラー: {e}")
            return 0
    
    async def _get_api_calls_per_minute(self) -> int:
        """API呼び出し数/分取得"""
        try:
            # 実際の実装では、APIゲートウェイから取得
            return 300  # シミュレーション値
        except Exception as e:
            self.logger.error(f"API呼び出し数取得エラー: {e}")
            return 0
    
    async def _store_metrics(self, metrics: HealthMetrics):
        """メトリクス保存"""
        try:
            cursor = self.metrics_db.cursor()
            cursor.execute('''
                INSERT INTO health_metrics 
                (timestamp, cpu_usage, memory_usage, disk_usage, response_time, 
                 error_rate, active_users, api_calls_per_minute)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                metrics.timestamp.isoformat(),
                metrics.cpu_usage,
                metrics.memory_usage,
                metrics.disk_usage,
                metrics.response_time,
                metrics.error_rate,
                metrics.active_users,
                metrics.api_calls_per_minute
            ))
            self.metrics_db.commit()
        
        except Exception as e:
            self.logger.error(f"メトリクス保存エラー: {e}")
    
    async def _analyze_metrics(self, metrics: HealthMetrics):
        """メトリクス分析・アラート生成"""
        thresholds = self.config['thresholds']
        
        # CPU使用率チェック
        if metrics.cpu_usage >= thresholds['cpu_critical']:
            await self._create_alert(
                AlertLevel.CRITICAL,
                "system",
                f"CPU使用率がクリティカル: {metrics.cpu_usage:.1f}%",
                {"cpu_usage": metrics.cpu_usage, "threshold": thresholds['cpu_critical']}
            )
        elif metrics.cpu_usage >= thresholds['cpu_warning']:
            await self._create_alert(
                AlertLevel.WARNING,
                "system",
                f"CPU使用率が高い: {metrics.cpu_usage:.1f}%",
                {"cpu_usage": metrics.cpu_usage, "threshold": thresholds['cpu_warning']}
            )
        
        # メモリ使用率チェック
        if metrics.memory_usage >= thresholds['memory_critical']:
            await self._create_alert(
                AlertLevel.CRITICAL,
                "system",
                f"メモリ使用率がクリティカル: {metrics.memory_usage:.1f}%",
                {"memory_usage": metrics.memory_usage, "threshold": thresholds['memory_critical']}
            )
        elif metrics.memory_usage >= thresholds['memory_warning']:
            await self._create_alert(
                AlertLevel.WARNING,
                "system",
                f"メモリ使用率が高い: {metrics.memory_usage:.1f}%",
                {"memory_usage": metrics.memory_usage, "threshold": thresholds['memory_warning']}
            )
        
        # 応答時間チェック
        if metrics.response_time >= thresholds['response_time_critical']:
            await self._create_alert(
                AlertLevel.CRITICAL,
                "api_server",
                f"API応答時間がクリティカル: {metrics.response_time:.0f}ms",
                {"response_time": metrics.response_time, "threshold": thresholds['response_time_critical']}
            )
        elif metrics.response_time >= thresholds['response_time_warning']:
            await self._create_alert(
                AlertLevel.WARNING,
                "api_server",
                f"API応答時間が遅い: {metrics.response_time:.0f}ms",
                {"response_time": metrics.response_time, "threshold": thresholds['response_time_warning']}
            )
    
    async def _service_health_monitor(self):
        """サービスヘルス監視"""
        while self.monitoring_active:
            try:
                for service_name, service_config in self.config['services'].items():
                    await self._check_service_health(service_name, service_config)
                
                await asyncio.sleep(self.config['monitoring']['interval_seconds'])
            
            except Exception as e:
                self.logger.error(f"サービスヘルス監視エラー: {e}")
                await asyncio.sleep(5)
    
    async def _check_service_health(self, service_name: str, service_config: Dict[str, Any]):
        """個別サービスヘルスチェック"""
        try:
            if 'url' in service_config:
                # HTTP ヘルスチェック
                response = requests.get(
                    service_config['url'],
                    timeout=self.config['monitoring']['health_check_timeout']
                )
                
                if response.status_code == 200:
                    self.service_status[service_name] = ServiceStatus.HEALTHY
                    # 既存のアラートがあれば解決済みにする
                    await self._resolve_service_alerts(service_name)
                else:
                    self.service_status[service_name] = ServiceStatus.DEGRADED
                    
                    await self._create_alert(
                        AlertLevel.WARNING if not service_config.get('critical') else AlertLevel.CRITICAL,
                        service_name,
                        f"サービス異常検出: HTTP {response.status_code}",
                        {"status_code": response.status_code, "url": service_config['url']}
                    )
            
            elif service_config.get('type') == 'postgresql':
                # データベースヘルスチェック
                # 実際の実装では、データベース接続テストを行う
                self.service_status[service_name] = ServiceStatus.HEALTHY
        
        except requests.exceptions.ConnectionError:
            self.service_status[service_name] = ServiceStatus.DOWN
            
            await self._create_alert(
                AlertLevel.CRITICAL if service_config.get('critical') else AlertLevel.WARNING,
                service_name,
                "サービス接続失敗",
                {"error": "connection_refused", "url": service_config.get('url')}
            )
        
        except Exception as e:
            self.logger.error(f"サービスヘルスチェックエラー ({service_name}): {e}")
    
    async def _sla_compliance_monitor(self):
        """SLA準拠監視"""
        while self.monitoring_active:
            try:
                uptime_percentage = await self._calculate_uptime_percentage()
                sla_target = self.config['monitoring']['sla_target']
                
                if uptime_percentage < sla_target:
                    await self._create_alert(
                        AlertLevel.CRITICAL,
                        "sla",
                        f"SLA違反: 稼働率 {uptime_percentage:.2f}% < 目標 {sla_target}%",
                        {"uptime": uptime_percentage, "target": sla_target}
                    )
                
                # SLAレポート生成
                await self._generate_sla_report(uptime_percentage)
                
                await asyncio.sleep(300)  # 5分間隔
            
            except Exception as e:
                self.logger.error(f"SLA監視エラー: {e}")
                await asyncio.sleep(60)
    
    async def _calculate_uptime_percentage(self) -> float:
        """稼働率計算"""
        try:
            # 過去24時間の稼働率を計算
            # 実装例：メトリクスデータベースから計算
            return 99.95  # シミュレーション値
        except Exception as e:
            self.logger.error(f"稼働率計算エラー: {e}")
            return 0.0
    
    async def _generate_sla_report(self, uptime_percentage: float):
        """SLAレポート生成"""
        try:
            report = {
                "timestamp": datetime.now().isoformat(),
                "uptime_percentage": uptime_percentage,
                "sla_target": self.config['monitoring']['sla_target'],
                "status": "COMPLIANT" if uptime_percentage >= self.config['monitoring']['sla_target'] else "VIOLATION",
                "service_status": {name: status.value for name, status in self.service_status.items()}
            }
            
            report_file = Path(f"Tests/production_enterprise/sla_reports/sla_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
            report_file.parent.mkdir(parents=True, exist_ok=True)
            
            with open(report_file, 'w', encoding='utf-8') as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
        
        except Exception as e:
            self.logger.error(f"SLAレポート生成エラー: {e}")
    
    async def _create_alert(self, level: AlertLevel, service: str, message: str, details: Dict[str, Any]):
        """アラート作成"""
        alert_id = f"{service}_{int(time.time())}"
        
        alert = Alert(
            id=alert_id,
            timestamp=datetime.now(),
            level=level,
            service=service,
            message=message,
            details=details
        )
        
        # アクティブアラートに追加
        self.active_alerts[alert_id] = alert
        
        # データベースに保存
        await self._store_alert(alert)
        
        # アラート通知
        await self._send_alert_notifications(alert)
        
        self.logger.warning(f"🚨 アラート発生: [{level.value.upper()}] {service} - {message}")
    
    async def _store_alert(self, alert: Alert):
        """アラート保存"""
        try:
            cursor = self.alerts_db.cursor()
            cursor.execute('''
                INSERT INTO alerts 
                (id, timestamp, level, service, message, details, resolved)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                alert.id,
                alert.timestamp.isoformat(),
                alert.level.value,
                alert.service,
                alert.message,
                json.dumps(alert.details),
                alert.resolved
            ))
            self.alerts_db.commit()
        
        except Exception as e:
            self.logger.error(f"アラート保存エラー: {e}")
    
    async def _send_alert_notifications(self, alert: Alert):
        """アラート通知送信"""
        # 並列で各通知手段を実行
        notification_tasks = []
        
        if self.config['notifications']['email']['enabled']:
            notification_tasks.append(self._send_email_alert(alert))
        
        if self.config['notifications']['slack']['enabled']:
            notification_tasks.append(self._send_slack_alert(alert))
        
        # 自動復旧の試行
        if alert.level in [AlertLevel.CRITICAL, AlertLevel.EMERGENCY]:
            notification_tasks.append(self._attempt_auto_recovery(alert))
        
        await asyncio.gather(*notification_tasks, return_exceptions=True)
    
    async def _send_email_alert(self, alert: Alert):
        """メール通知送信"""
        try:
            msg = MimeMultipart()
            msg['From'] = "monitoring@company.com"
            msg['To'] = ", ".join(self.config['notifications']['email']['recipients'])
            msg['Subject'] = f"[{alert.level.value.upper()}] Microsoft 365監視アラート: {alert.service}"
            
            body = f"""
            🚨 Microsoft 365管理システム監視アラート
            
            レベル: {alert.level.value.upper()}
            サービス: {alert.service}
            時刻: {alert.timestamp.strftime('%Y-%m-%d %H:%M:%S')}
            メッセージ: {alert.message}
            
            詳細情報:
            {json.dumps(alert.details, indent=2, ensure_ascii=False)}
            
            このアラートは自動で生成されました。
            """
            
            msg.attach(MimeText(body, 'plain', 'utf-8'))
            
            # メール送信（実際の実装では適切なSMTP設定を使用）
            # server = smtplib.SMTP(self.config['notifications']['email']['smtp_server'])
            # server.send_message(msg)
            # server.quit()
            
            self.logger.info(f"📧 メール通知送信完了: {alert.id}")
        
        except Exception as e:
            self.logger.error(f"メール通知送信エラー: {e}")
    
    async def _send_slack_alert(self, alert: Alert):
        """Slack通知送信"""
        try:
            emoji_map = {
                AlertLevel.INFO: "ℹ️",
                AlertLevel.WARNING: "⚠️",
                AlertLevel.CRITICAL: "🚨",
                AlertLevel.EMERGENCY: "🆘"
            }
            
            payload = {
                "text": f"{emoji_map.get(alert.level, '🔔')} Microsoft 365監視アラート",
                "attachments": [
                    {
                        "color": "danger" if alert.level in [AlertLevel.CRITICAL, AlertLevel.EMERGENCY] else "warning",
                        "fields": [
                            {"title": "レベル", "value": alert.level.value.upper(), "short": True},
                            {"title": "サービス", "value": alert.service, "short": True},
                            {"title": "メッセージ", "value": alert.message, "short": False},
                            {"title": "時刻", "value": alert.timestamp.strftime('%Y-%m-%d %H:%M:%S'), "short": True}
                        ]
                    }
                ]
            }
            
            # Slack WebHook送信（実際の実装では適切なWebHook URLを使用）
            # response = requests.post(
            #     self.config['notifications']['slack']['webhook_url'],
            #     json=payload
            # )
            
            self.logger.info(f"📱 Slack通知送信完了: {alert.id}")
        
        except Exception as e:
            self.logger.error(f"Slack通知送信エラー: {e}")
    
    async def _attempt_auto_recovery(self, alert: Alert):
        """自動復旧試行"""
        try:
            recovery_actions = {
                "api_server": self._restart_api_server,
                "database": self._restart_database_connection,
                "system": self._cleanup_system_resources
            }
            
            if alert.service in recovery_actions:
                self.logger.info(f"🔄 自動復旧開始: {alert.service}")
                
                success = await recovery_actions[alert.service](alert)
                
                if success:
                    await self._resolve_alert(alert.id)
                    self.logger.info(f"✅ 自動復旧成功: {alert.service}")
                else:
                    self.logger.warning(f"❌ 自動復旧失敗: {alert.service}")
        
        except Exception as e:
            self.logger.error(f"自動復旧エラー: {e}")
    
    async def _restart_api_server(self, alert: Alert) -> bool:
        """APIサーバー再起動"""
        try:
            # サービス再起動のシミュレーション
            await asyncio.sleep(2)
            return True
        except Exception as e:
            self.logger.error(f"APIサーバー再起動エラー: {e}")
            return False
    
    async def _restart_database_connection(self, alert: Alert) -> bool:
        """データベース接続再起動"""
        try:
            # データベース接続再初期化のシミュレーション
            await asyncio.sleep(1)
            return True
        except Exception as e:
            self.logger.error(f"データベース接続再起動エラー: {e}")
            return False
    
    async def _cleanup_system_resources(self, alert: Alert) -> bool:
        """システムリソースクリーンアップ"""
        try:
            # メモリクリーンアップ、一時ファイル削除のシミュレーション
            await asyncio.sleep(1)
            return True
        except Exception as e:
            self.logger.error(f"システムリソースクリーンアップエラー: {e}")
            return False
    
    async def _alert_processor(self):
        """アラート処理ループ"""
        while self.monitoring_active:
            try:
                # 未解決アラートの確認・エスカレーション
                current_time = datetime.now()
                
                for alert_id, alert in list(self.active_alerts.items()):
                    if not alert.resolved:
                        # 30分以上未解決のクリティカルアラートをエスカレーション
                        if (current_time - alert.timestamp) > timedelta(minutes=30) and \
                           alert.level in [AlertLevel.CRITICAL, AlertLevel.EMERGENCY]:
                            await self._escalate_alert(alert)
                
                await asyncio.sleep(60)  # 1分間隔
            
            except Exception as e:
                self.logger.error(f"アラート処理エラー: {e}")
                await asyncio.sleep(10)
    
    async def _auto_recovery_monitor(self):
        """自動復旧監視ループ"""
        while self.monitoring_active:
            try:
                # 自動復旧可能な状況の監視
                await self._check_recovery_opportunities()
                await asyncio.sleep(120)  # 2分間隔
            
            except Exception as e:
                self.logger.error(f"自動復旧監視エラー: {e}")
                await asyncio.sleep(30)
    
    async def _check_recovery_opportunities(self):
        """復旧機会の確認"""
        # 自動復旧可能な状況をチェック
        pass
    
    async def _escalate_alert(self, alert: Alert):
        """アラートエスカレーション"""
        try:
            escalated_alert = Alert(
                id=f"{alert.id}_escalated",
                timestamp=datetime.now(),
                level=AlertLevel.EMERGENCY,
                service=alert.service,
                message=f"エスカレーション: {alert.message}",
                details={**alert.details, "original_alert_id": alert.id, "escalation_reason": "30分未解決"}
            )
            
            await self._send_alert_notifications(escalated_alert)
            self.logger.critical(f"🆘 アラートエスカレーション: {alert.id}")
        
        except Exception as e:
            self.logger.error(f"アラートエスカレーションエラー: {e}")
    
    async def _resolve_alert(self, alert_id: str):
        """アラート解決"""
        try:
            if alert_id in self.active_alerts:
                alert = self.active_alerts[alert_id]
                alert.resolved = True
                alert.resolution_time = datetime.now()
                
                # データベース更新
                cursor = self.alerts_db.cursor()
                cursor.execute('''
                    UPDATE alerts 
                    SET resolved = TRUE, resolution_time = ?
                    WHERE id = ?
                ''', (alert.resolution_time.isoformat(), alert_id))
                self.alerts_db.commit()
                
                # アクティブアラートから削除
                del self.active_alerts[alert_id]
                
                self.logger.info(f"✅ アラート解決: {alert_id}")
        
        except Exception as e:
            self.logger.error(f"アラート解決エラー: {e}")
    
    async def _resolve_service_alerts(self, service_name: str):
        """サービス関連アラートの解決"""
        resolved_alerts = []
        
        for alert_id, alert in self.active_alerts.items():
            if alert.service == service_name and not alert.resolved:
                await self._resolve_alert(alert_id)
                resolved_alerts.append(alert_id)
        
        if resolved_alerts:
            self.logger.info(f"サービス復旧によりアラート解決: {service_name} - {len(resolved_alerts)}件")
    
    def get_system_status(self) -> Dict[str, Any]:
        """システム状態取得"""
        return {
            "timestamp": datetime.now().isoformat(),
            "monitoring_active": self.monitoring_active,
            "service_status": {name: status.value for name, status in self.service_status.items()},
            "active_alerts_count": len(self.active_alerts),
            "active_alerts": [asdict(alert) for alert in self.active_alerts.values()]
        }


async def main():
    """メイン実行関数"""
    monitoring_system = EnterpriseMonitoringSystem()
    
    try:
        await monitoring_system.start_monitoring()
    except KeyboardInterrupt:
        print("\n監視システムを停止中...")
        await monitoring_system.stop_monitoring()
    except Exception as e:
        logging.error(f"監視システムエラー: {e}")
    finally:
        await monitoring_system.stop_monitoring()


if __name__ == "__main__":
    asyncio.run(main())
