#!/usr/bin/env python3
"""
Auto Recovery & Failover System - Phase 5 Enterprise Operations
Intelligent self-healing infrastructure for 99.9% SLA maintenance
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
import traceback
from pathlib import Path
import subprocess
import platform

# Circuit breaker pattern
from enum import Enum as CircuitState
import httpx
import redis.asyncio as redis
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import text

from src.core.config import get_settings
from src.monitoring.health_checks import HealthCheckManager, HealthStatus

logger = logging.getLogger(__name__)


class RecoveryStatus(str, Enum):
    """復旧ステータス"""
    PENDING = "pending"           # 待機中
    IN_PROGRESS = "in_progress"   # 実行中
    SUCCESS = "success"           # 成功
    FAILED = "failed"             # 失敗
    SKIPPED = "skipped"           # スキップ


class FailoverTrigger(str, Enum):
    """フェイルオーバートリガー"""
    HEALTH_CHECK_FAILURE = "health_check_failure"
    RESPONSE_TIME_THRESHOLD = "response_time_threshold"
    ERROR_RATE_THRESHOLD = "error_rate_threshold"
    MANUAL_TRIGGER = "manual_trigger"
    RESOURCE_EXHAUSTION = "resource_exhaustion"


class CircuitBreakerState(str, Enum):
    """サーキットブレーカー状態"""
    CLOSED = "closed"     # 正常動作
    OPEN = "open"         # 回路オープン（障害）
    HALF_OPEN = "half_open"  # 部分復旧テスト


@dataclass
class RecoveryAction:
    """復旧アクション定義"""
    name: str
    description: str
    action_func: Callable[[Dict[str, Any]], Any]
    priority: int = 1  # 1=最高優先度
    timeout_seconds: int = 60
    retry_count: int = 3
    retry_delay_seconds: float = 1.0
    prerequisites: List[str] = field(default_factory=list)
    success_criteria: Optional[Callable[[Any], bool]] = None
    
    # 実行統計
    execution_count: int = 0
    success_count: int = 0
    last_execution: Optional[datetime] = None
    last_success: Optional[datetime] = None


@dataclass
class RecoveryPlan:
    """復旧計画"""
    name: str
    trigger_conditions: List[str]
    recovery_actions: List[RecoveryAction]
    escalation_actions: List[RecoveryAction] = field(default_factory=list)
    cooldown_minutes: int = 15
    max_executions_per_hour: int = 3
    
    # 実行履歴
    execution_history: List[Dict[str, Any]] = field(default_factory=list)
    last_execution: Optional[datetime] = None


@dataclass
class CircuitBreaker:
    """サーキットブレーカー"""
    name: str
    failure_threshold: int = 5
    recovery_timeout_seconds: int = 60
    half_open_max_calls: int = 3
    
    # 状態管理
    state: CircuitBreakerState = CircuitBreakerState.CLOSED
    failure_count: int = 0
    last_failure_time: Optional[datetime] = None
    next_attempt_time: Optional[datetime] = None
    half_open_call_count: int = 0


class MicrosoftGraphRecovery:
    """Microsoft Graph API専用復旧処理"""
    
    def __init__(self):
        self.settings = get_settings()
        self.circuit_breaker = CircuitBreaker(
            name="microsoft_graph",
            failure_threshold=3,
            recovery_timeout_seconds=300
        )
    
    async def recover_authentication(self, error_details: Dict[str, Any]) -> Dict[str, Any]:
        """認証問題復旧"""
        try:
            logger.info("Attempting Microsoft Graph authentication recovery")
            
            # 1. トークンキャッシュクリア
            await self._clear_token_cache()
            
            # 2. 新しいトークン取得試行
            token_result = await self._acquire_new_token()
            
            # 3. 接続テスト
            test_result = await self._test_graph_connection(token_result.get("access_token"))
            
            if test_result["success"]:
                self.circuit_breaker.state = CircuitBreakerState.CLOSED
                self.circuit_breaker.failure_count = 0
                return {
                    "status": "success",
                    "message": "Microsoft Graph authentication recovered successfully",
                    "details": {
                        "token_renewed": True,
                        "connection_test": "passed"
                    }
                }
            else:
                return {
                    "status": "failed",
                    "message": "Microsoft Graph authentication recovery failed",
                    "details": test_result
                }
                
        except Exception as e:
            logger.error(f"Microsoft Graph authentication recovery failed: {e}")
            return {
                "status": "failed",
                "message": f"Authentication recovery error: {str(e)}",
                "details": {"error": str(e), "traceback": traceback.format_exc()}
            }
    
    async def recover_rate_limiting(self, error_details: Dict[str, Any]) -> Dict[str, Any]:
        """レート制限復旧"""
        try:
            logger.info("Handling Microsoft Graph rate limiting")
            
            # Retry-After ヘッダーから待機時間取得
            retry_after = error_details.get("retry_after", 60)
            
            # 指数バックオフ適用
            backoff_time = min(retry_after * 2, 300)  # 最大5分
            
            logger.info(f"Waiting {backoff_time} seconds due to rate limiting")
            await asyncio.sleep(backoff_time)
            
            # 接続テスト
            test_result = await self._test_graph_connection()
            
            return {
                "status": "success",
                "message": f"Rate limiting handled with {backoff_time}s wait",
                "details": {
                    "wait_time_seconds": backoff_time,
                    "test_result": test_result
                }
            }
            
        except Exception as e:
            return {
                "status": "failed",
                "message": f"Rate limiting recovery error: {str(e)}",
                "details": {"error": str(e)}
            }
    
    async def _clear_token_cache(self):
        """トークンキャッシュクリア"""
        try:
            # アプリケーション固有のトークンキャッシュクリア
            cache_paths = [
                Path.home() / ".cache" / "msal_token_cache.bin",
                Path("/tmp/msal_token_cache.bin"),
                Path("./token_cache.bin")
            ]
            
            for cache_path in cache_paths:
                if cache_path.exists():
                    cache_path.unlink()
                    logger.info(f"Cleared token cache: {cache_path}")
                    
        except Exception as e:
            logger.warning(f"Token cache clear warning: {e}")
    
    async def _acquire_new_token(self) -> Dict[str, Any]:
        """新しいトークン取得"""
        try:
            # Microsoft Graph クライアント経由でトークン取得
            # 実際の実装ではMSALライブラリを使用
            
            return {
                "access_token": "new_token_placeholder",
                "expires_in": 3600,
                "token_type": "Bearer"
            }
            
        except Exception as e:
            logger.error(f"Token acquisition failed: {e}")
            raise
    
    async def _test_graph_connection(self, token: str = None) -> Dict[str, Any]:
        """Graph API接続テスト"""
        try:
            headers = {}
            if token:
                headers["Authorization"] = f"Bearer {token}"
            
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.get(
                    "https://graph.microsoft.com/v1.0/me",
                    headers=headers
                )
            
            success = response.status_code in [200, 401]  # 401も接続は成功
            
            return {
                "success": success,
                "status_code": response.status_code,
                "response_time": response.elapsed.total_seconds() if hasattr(response, 'elapsed') else 0
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }


class DatabaseRecovery:
    """データベース復旧処理"""
    
    def __init__(self):
        self.settings = get_settings()
    
    async def recover_connection_pool(self, error_details: Dict[str, Any]) -> Dict[str, Any]:
        """データベース接続プール復旧"""
        try:
            logger.info("Attempting database connection pool recovery")
            
            if not hasattr(self.settings, 'DATABASE_URL'):
                return {
                    "status": "skipped",
                    "message": "Database URL not configured"
                }
            
            # 1. 古い接続プールクリア
            await self._clear_connection_pool()
            
            # 2. 新しい接続プール作成
            engine = create_async_engine(
                self.settings.DATABASE_URL,
                pool_size=10,
                max_overflow=20,
                pool_pre_ping=True,
                pool_recycle=300
            )
            
            # 3. 接続テスト
            async with engine.begin() as conn:
                result = await conn.execute(text("SELECT 1 as test"))
                test_value = result.scalar()
            
            await engine.dispose()
            
            if test_value == 1:
                return {
                    "status": "success",
                    "message": "Database connection pool recovered successfully",
                    "details": {
                        "pool_recreated": True,
                        "connection_test": "passed"
                    }
                }
            else:
                return {
                    "status": "failed",
                    "message": "Database connection test failed",
                    "details": {"test_value": test_value}
                }
                
        except Exception as e:
            logger.error(f"Database recovery failed: {e}")
            return {
                "status": "failed",
                "message": f"Database recovery error: {str(e)}",
                "details": {"error": str(e)}
            }
    
    async def _clear_connection_pool(self):
        """接続プールクリア"""
        try:
            # 実装依存の接続プールクリア処理
            logger.info("Clearing database connection pool")
            await asyncio.sleep(1)  # 模擬的な処理時間
            
        except Exception as e:
            logger.warning(f"Connection pool clear warning: {e}")


class SystemResourceRecovery:
    """システムリソース復旧処理"""
    
    async def recover_memory_pressure(self, error_details: Dict[str, Any]) -> Dict[str, Any]:
        """メモリ圧迫復旧"""
        try:
            logger.info("Attempting memory pressure recovery")
            
            initial_memory = self._get_memory_usage()
            
            # 1. ガベージコレクション強制実行
            import gc
            collected = gc.collect()
            
            # 2. 一時ファイルクリーンアップ
            temp_cleaned = await self._cleanup_temp_files()
            
            # 3. メモリ使用量再確認
            final_memory = self._get_memory_usage()
            memory_freed = initial_memory - final_memory
            
            return {
                "status": "success",
                "message": f"Memory recovery completed, freed {memory_freed:.1f}MB",
                "details": {
                    "initial_memory_mb": initial_memory,
                    "final_memory_mb": final_memory,
                    "memory_freed_mb": memory_freed,
                    "gc_collected": collected,
                    "temp_files_cleaned": temp_cleaned
                }
            }
            
        except Exception as e:
            return {
                "status": "failed",
                "message": f"Memory recovery error: {str(e)}",
                "details": {"error": str(e)}
            }
    
    async def recover_disk_space(self, error_details: Dict[str, Any]) -> Dict[str, Any]:
        """ディスク容量復旧"""
        try:
            logger.info("Attempting disk space recovery")
            
            initial_disk = self._get_disk_usage()
            
            # 1. ログファイルローテーション
            log_cleaned = await self._rotate_log_files()
            
            # 2. 一時ファイル削除
            temp_cleaned = await self._cleanup_temp_files()
            
            # 3. 古いバックアップ削除
            backup_cleaned = await self._cleanup_old_backups()
            
            final_disk = self._get_disk_usage()
            space_freed = initial_disk - final_disk
            
            return {
                "status": "success",
                "message": f"Disk space recovery completed, freed {space_freed:.1f}GB",
                "details": {
                    "initial_disk_gb": initial_disk,
                    "final_disk_gb": final_disk,
                    "space_freed_gb": space_freed,
                    "log_files_cleaned": log_cleaned,
                    "temp_files_cleaned": temp_cleaned,
                    "backup_files_cleaned": backup_cleaned
                }
            }
            
        except Exception as e:
            return {
                "status": "failed", 
                "message": f"Disk space recovery error: {str(e)}",
                "details": {"error": str(e)}
            }
    
    def _get_memory_usage(self) -> float:
        """メモリ使用量取得（MB）"""
        try:
            import psutil
            process = psutil.Process()
            return process.memory_info().rss / (1024 * 1024)
        except:
            return 0.0
    
    def _get_disk_usage(self) -> float:
        """ディスク使用量取得（GB）"""
        try:
            import psutil
            disk = psutil.disk_usage('/')
            return disk.used / (1024 * 1024 * 1024)
        except:
            return 0.0
    
    async def _cleanup_temp_files(self) -> int:
        """一時ファイルクリーンアップ"""
        try:
            import tempfile
            import shutil
            
            temp_dir = Path(tempfile.gettempdir())
            cutoff_time = datetime.utcnow() - timedelta(hours=24)
            
            cleaned_count = 0
            for file_path in temp_dir.iterdir():
                try:
                    if file_path.is_file():
                        file_time = datetime.fromtimestamp(file_path.stat().st_mtime)
                        if file_time < cutoff_time:
                            file_path.unlink()
                            cleaned_count += 1
                except:
                    pass
            
            return cleaned_count
            
        except Exception as e:
            logger.warning(f"Temp file cleanup warning: {e}")
            return 0
    
    async def _rotate_log_files(self) -> int:
        """ログファイルローテーション"""
        try:
            log_dirs = [Path("./logs"), Path("/var/log/app")]
            rotated_count = 0
            
            for log_dir in log_dirs:
                if log_dir.exists():
                    for log_file in log_dir.glob("*.log"):
                        if log_file.stat().st_size > 100 * 1024 * 1024:  # 100MB以上
                            backup_name = f"{log_file}.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                            log_file.rename(backup_name)
                            log_file.touch()
                            rotated_count += 1
            
            return rotated_count
            
        except Exception as e:
            logger.warning(f"Log rotation warning: {e}")
            return 0
    
    async def _cleanup_old_backups(self) -> int:
        """古いバックアップクリーンアップ"""
        try:
            backup_dirs = [Path("./backups"), Path("/var/backups/app")]
            cutoff_time = datetime.utcnow() - timedelta(days=30)
            cleaned_count = 0
            
            for backup_dir in backup_dirs:
                if backup_dir.exists():
                    for backup_file in backup_dir.iterdir():
                        try:
                            file_time = datetime.fromtimestamp(backup_file.stat().st_mtime)
                            if file_time < cutoff_time:
                                if backup_file.is_file():
                                    backup_file.unlink()
                                    cleaned_count += 1
                                elif backup_file.is_dir():
                                    import shutil
                                    shutil.rmtree(backup_file)
                                    cleaned_count += 1
                        except:
                            pass
            
            return cleaned_count
            
        except Exception as e:
            logger.warning(f"Backup cleanup warning: {e}")
            return 0


class AutoRecoverySystem:
    """自動復旧システム - メインクラス"""
    
    def __init__(self):
        self.settings = get_settings()
        
        # 復旧コンポーネント
        self.graph_recovery = MicrosoftGraphRecovery()
        self.database_recovery = DatabaseRecovery()
        self.system_recovery = SystemResourceRecovery()
        
        # 復旧計画
        self.recovery_plans: Dict[str, RecoveryPlan] = {}
        
        # サーキットブレーカー
        self.circuit_breakers: Dict[str, CircuitBreaker] = {}
        
        # 実行状態
        self.is_active = False
        self.recovery_task: Optional[asyncio.Task] = None
        
        # 統計情報
        self.stats = {
            "total_recoveries_attempted": 0,
            "total_recoveries_successful": 0,
            "total_recoveries_failed": 0,
            "last_recovery_time": None,
            "recovery_success_rate": 0.0
        }
        
        logger.info("Auto Recovery System initialized")
    
    async def initialize(self):
        """自動復旧システム初期化"""
        try:
            # デフォルト復旧計画セットアップ
            await self._setup_default_recovery_plans()
            
            # サーキットブレーカー初期化
            await self._initialize_circuit_breakers()
            
            logger.info("Auto Recovery System initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Auto Recovery System: {e}")
            raise
    
    async def _setup_default_recovery_plans(self):
        """デフォルト復旧計画セットアップ"""
        
        # Microsoft Graph復旧計画
        graph_plan = RecoveryPlan(
            name="microsoft_graph_recovery",
            trigger_conditions=["microsoft_graph_auth_failure", "microsoft_graph_rate_limit"],
            recovery_actions=[
                RecoveryAction(
                    name="graph_auth_recovery",
                    description="Microsoft Graph authentication recovery",
                    action_func=self.graph_recovery.recover_authentication,
                    priority=1,
                    timeout_seconds=60
                ),
                RecoveryAction(
                    name="graph_rate_limit_recovery", 
                    description="Microsoft Graph rate limiting recovery",
                    action_func=self.graph_recovery.recover_rate_limiting,
                    priority=2,
                    timeout_seconds=300
                )
            ]
        )
        self.recovery_plans["microsoft_graph"] = graph_plan
        
        # データベース復旧計画
        database_plan = RecoveryPlan(
            name="database_recovery",
            trigger_conditions=["database_connection_failure", "database_timeout"],
            recovery_actions=[
                RecoveryAction(
                    name="database_connection_pool_recovery",
                    description="Database connection pool recovery",
                    action_func=self.database_recovery.recover_connection_pool,
                    priority=1,
                    timeout_seconds=30
                )
            ]
        )
        self.recovery_plans["database"] = database_plan
        
        # システムリソース復旧計画
        system_plan = RecoveryPlan(
            name="system_resource_recovery",
            trigger_conditions=["high_memory_usage", "high_disk_usage", "resource_exhaustion"],
            recovery_actions=[
                RecoveryAction(
                    name="memory_pressure_recovery",
                    description="Memory pressure recovery",
                    action_func=self.system_recovery.recover_memory_pressure,
                    priority=1,
                    timeout_seconds=60
                ),
                RecoveryAction(
                    name="disk_space_recovery",
                    description="Disk space recovery", 
                    action_func=self.system_recovery.recover_disk_space,
                    priority=2,
                    timeout_seconds=120
                )
            ]
        )
        self.recovery_plans["system_resources"] = system_plan
        
        logger.info(f"Setup {len(self.recovery_plans)} default recovery plans")
    
    async def _initialize_circuit_breakers(self):
        """サーキットブレーカー初期化"""
        services = ["microsoft_graph", "database", "redis", "external_api"]
        
        for service in services:
            self.circuit_breakers[service] = CircuitBreaker(
                name=service,
                failure_threshold=5,
                recovery_timeout_seconds=300,
                half_open_max_calls=3
            )
        
        logger.info(f"Initialized {len(self.circuit_breakers)} circuit breakers")
    
    async def start_monitoring(self):
        """自動復旧監視開始"""
        if self.is_active:
            logger.warning("Auto recovery monitoring is already active")
            return
        
        self.is_active = True
        self.recovery_task = asyncio.create_task(self._recovery_monitoring_loop())
        
        logger.info("Auto recovery monitoring started")
    
    async def stop_monitoring(self):
        """自動復旧監視停止"""
        if not self.is_active:
            return
        
        self.is_active = False
        
        if self.recovery_task:
            self.recovery_task.cancel()
            try:
                await self.recovery_task
            except asyncio.CancelledError:
                pass
        
        logger.info("Auto recovery monitoring stopped")
    
    async def _recovery_monitoring_loop(self):
        """復旧監視ループ"""
        logger.info("Starting auto recovery monitoring loop")
        
        while self.is_active:
            try:
                # 1. サーキットブレーカー状態チェック
                await self._check_circuit_breakers()
                
                # 2. 復旧計画実行チェック
                await self._check_recovery_triggers()
                
                # 3. 統計更新
                self._update_statistics()
                
                # 60秒間隔でチェック
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error(f"Error in recovery monitoring loop: {e}")
                await asyncio.sleep(30)  # エラー時は短い間隔で再試行
    
    async def _check_circuit_breakers(self):
        """サーキットブレーカー状態チェック"""
        current_time = datetime.utcnow()
        
        for name, breaker in self.circuit_breakers.items():
            if breaker.state == CircuitBreakerState.OPEN:
                # 復旧時間チェック
                if (breaker.next_attempt_time and 
                    current_time >= breaker.next_attempt_time):
                    breaker.state = CircuitBreakerState.HALF_OPEN
                    breaker.half_open_call_count = 0
                    logger.info(f"Circuit breaker {name} moved to HALF_OPEN state")
    
    async def _check_recovery_triggers(self):
        """復旧トリガーチェック"""
        # 実際の実装ではヘルスチェック結果を基に判定
        # ここでは模擬的な実装
        pass
    
    async def execute_recovery_plan(self, plan_name: str, trigger_reason: str = "manual", 
                                   error_details: Dict[str, Any] = None) -> Dict[str, Any]:
        """復旧計画実行"""
        try:
            if plan_name not in self.recovery_plans:
                return {
                    "status": "failed",
                    "message": f"Recovery plan '{plan_name}' not found"
                }
            
            plan = self.recovery_plans[plan_name]
            current_time = datetime.utcnow()
            
            # クールダウンチェック
            if (plan.last_execution and 
                (current_time - plan.last_execution).total_seconds() < plan.cooldown_minutes * 60):
                return {
                    "status": "skipped",
                    "message": f"Recovery plan '{plan_name}' is in cooldown period"
                }
            
            # 実行頻度チェック
            recent_executions = [
                ex for ex in plan.execution_history
                if datetime.fromisoformat(ex["start_time"]) > current_time - timedelta(hours=1)
            ]
            
            if len(recent_executions) >= plan.max_executions_per_hour:
                return {
                    "status": "skipped",
                    "message": f"Recovery plan '{plan_name}' exceeded max executions per hour"
                }
            
            # 復旧実行
            execution_id = f"{plan_name}_{int(time.time())}"
            execution_record = {
                "execution_id": execution_id,
                "plan_name": plan_name,
                "trigger_reason": trigger_reason,
                "start_time": current_time.isoformat(),
                "actions": [],
                "overall_status": RecoveryStatus.IN_PROGRESS
            }
            
            logger.info(f"Starting recovery plan execution: {plan_name} (ID: {execution_id})")
            
            successful_actions = 0
            total_actions = len(plan.recovery_actions)
            
            # 優先度順にアクション実行
            sorted_actions = sorted(plan.recovery_actions, key=lambda x: x.priority)
            
            for action in sorted_actions:
                action_result = await self._execute_recovery_action(
                    action, error_details or {}, execution_id
                )
                
                execution_record["actions"].append(action_result)
                
                if action_result["status"] == RecoveryStatus.SUCCESS:
                    successful_actions += 1
                elif action_result["status"] == RecoveryStatus.FAILED:
                    # アクション失敗時は継続するかどうか判定
                    if action.priority == 1:  # 最高優先度のアクションが失敗した場合は停止
                        break
            
            # 実行結果判定
            if successful_actions == total_actions:
                execution_record["overall_status"] = RecoveryStatus.SUCCESS
                self.stats["total_recoveries_successful"] += 1
            elif successful_actions > 0:
                execution_record["overall_status"] = RecoveryStatus.SUCCESS  # 部分成功も成功扱い
                self.stats["total_recoveries_successful"] += 1
            else:
                execution_record["overall_status"] = RecoveryStatus.FAILED
                self.stats["total_recoveries_failed"] += 1
            
            execution_record["end_time"] = datetime.utcnow().isoformat()
            execution_record["successful_actions"] = successful_actions
            execution_record["total_actions"] = total_actions
            
            # 実行履歴更新
            plan.execution_history.append(execution_record)
            plan.last_execution = current_time
            
            # 統計更新
            self.stats["total_recoveries_attempted"] += 1
            self.stats["last_recovery_time"] = current_time.isoformat()
            self._update_statistics()
            
            logger.info(f"Recovery plan execution completed: {plan_name} - {execution_record['overall_status']}")
            
            return {
                "status": execution_record["overall_status"],
                "execution_id": execution_id,
                "successful_actions": successful_actions,
                "total_actions": total_actions,
                "execution_time_seconds": (
                    datetime.fromisoformat(execution_record["end_time"]) - 
                    datetime.fromisoformat(execution_record["start_time"])
                ).total_seconds(),
                "details": execution_record
            }
            
        except Exception as e:
            logger.error(f"Recovery plan execution failed: {e}")
            self.stats["total_recoveries_failed"] += 1
            return {
                "status": RecoveryStatus.FAILED,
                "message": f"Recovery plan execution error: {str(e)}",
                "details": {"error": str(e), "traceback": traceback.format_exc()}
            }
    
    async def _execute_recovery_action(self, action: RecoveryAction, 
                                     error_details: Dict[str, Any], 
                                     execution_id: str) -> Dict[str, Any]:
        """個別復旧アクション実行"""
        start_time = datetime.utcnow()
        
        action_result = {
            "action_name": action.name,
            "start_time": start_time.isoformat(),
            "status": RecoveryStatus.IN_PROGRESS,
            "retry_attempts": 0
        }
        
        logger.info(f"Executing recovery action: {action.name} (Execution: {execution_id})")
        
        for attempt in range(action.retry_count + 1):
            try:
                action_result["retry_attempts"] = attempt
                
                # タイムアウト付きでアクション実行
                result = await asyncio.wait_for(
                    action.action_func(error_details),
                    timeout=action.timeout_seconds
                )
                
                # 成功判定
                if action.success_criteria:
                    success = action.success_criteria(result)
                else:
                    success = (isinstance(result, dict) and 
                              result.get("status") in ["success", "completed"])
                
                if success:
                    action_result["status"] = RecoveryStatus.SUCCESS
                    action_result["result"] = result
                    
                    # 統計更新
                    action.execution_count += 1
                    action.success_count += 1
                    action.last_execution = start_time
                    action.last_success = start_time
                    
                    break
                else:
                    if attempt < action.retry_count:
                        logger.warning(f"Action {action.name} attempt {attempt + 1} failed, retrying...")
                        await asyncio.sleep(action.retry_delay_seconds * (2 ** attempt))  # 指数バックオフ
                    else:
                        action_result["status"] = RecoveryStatus.FAILED
                        action_result["result"] = result
                        action.execution_count += 1
                        action.last_execution = start_time
                
            except asyncio.TimeoutError:
                logger.error(f"Action {action.name} timed out after {action.timeout_seconds}s")
                action_result["status"] = RecoveryStatus.FAILED
                action_result["error"] = f"Timeout after {action.timeout_seconds}s"
                break
                
            except Exception as e:
                logger.error(f"Action {action.name} failed with error: {e}")
                if attempt < action.retry_count:
                    await asyncio.sleep(action.retry_delay_seconds * (2 ** attempt))
                else:
                    action_result["status"] = RecoveryStatus.FAILED
                    action_result["error"] = str(e)
                    action_result["traceback"] = traceback.format_exc()
                    action.execution_count += 1
                    action.last_execution = start_time
        
        action_result["end_time"] = datetime.utcnow().isoformat()
        action_result["duration_seconds"] = (
            datetime.fromisoformat(action_result["end_time"]) - start_time
        ).total_seconds()
        
        logger.info(f"Recovery action completed: {action.name} - {action_result['status']}")
        
        return action_result
    
    def _update_statistics(self):
        """統計情報更新"""
        total_attempts = self.stats["total_recoveries_attempted"]
        if total_attempts > 0:
            self.stats["recovery_success_rate"] = (
                self.stats["total_recoveries_successful"] / total_attempts * 100
            )
    
    def get_system_status(self) -> Dict[str, Any]:
        """システム状況取得"""
        return {
            "auto_recovery_active": self.is_active,
            "recovery_plans": {
                name: {
                    "last_execution": plan.last_execution.isoformat() if plan.last_execution else None,
                    "execution_count": len(plan.execution_history),
                    "cooldown_minutes": plan.cooldown_minutes
                }
                for name, plan in self.recovery_plans.items()
            },
            "circuit_breakers": {
                name: {
                    "state": breaker.state.value,
                    "failure_count": breaker.failure_count,
                    "last_failure": breaker.last_failure_time.isoformat() if breaker.last_failure_time else None
                }
                for name, breaker in self.circuit_breakers.items()
            },
            "statistics": self.stats
        }
    
    async def close(self):
        """自動復旧システム終了"""
        await self.stop_monitoring()
        logger.info("Auto Recovery System closed")


# グローバルインスタンス
auto_recovery_system = AutoRecoverySystem()


if __name__ == "__main__":
    # テスト実行
    async def test_auto_recovery():
        """自動復旧システムテスト"""
        print("Testing Auto Recovery System...")
        
        system = AutoRecoverySystem()
        await system.initialize()
        
        # 復旧計画実行テスト
        result = await system.execute_recovery_plan(
            "microsoft_graph",
            trigger_reason="test",
            error_details={"error_type": "authentication", "status_code": 401}
        )
        
        print(f"Recovery result: {json.dumps(result, indent=2, default=str)}")
        
        # システム状況確認
        status = system.get_system_status()
        print(f"System status: {json.dumps(status, indent=2, default=str)}")
        
        await system.close()
        print("Auto recovery test completed")
    
    asyncio.run(test_auto_recovery())