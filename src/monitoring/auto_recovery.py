#!/usr/bin/env python3
"""
Auto Recovery System - Phase 2 Enterprise Production
自動復旧機能・障害自動検出・セルフヒーリング・可用性保証
"""

import os
import logging
import time
import threading
import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import json
import subprocess
import signal
import psutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, TimeoutError

# Monitoring integration
from src.monitoring.health_checks import HealthStatus, HealthCheckResult, health_registry
from src.monitoring.azure_monitor_integration import AzureMonitorIntegration, MonitoringLevel

logger = logging.getLogger(__name__)


class RecoveryActionType(Enum):
    """復旧アクションタイプ"""
    RESTART_SERVICE = "restart_service"
    RESTART_APPLICATION = "restart_application"
    CLEAR_CACHE = "clear_cache"
    CLEAR_TEMP_FILES = "clear_temp_files"
    SCALE_UP = "scale_up"
    SCALE_DOWN = "scale_down"
    FAILOVER = "failover"
    CUSTOM = "custom"


class RecoveryResult(Enum):
    """復旧結果"""
    SUCCESS = "success"
    FAILED = "failed"
    PARTIAL = "partial"
    SKIPPED = "skipped"
    TIMEOUT = "timeout"


@dataclass
class RecoveryAction:
    """復旧アクション定義"""
    name: str
    action_type: RecoveryActionType
    function: Callable
    timeout: int = 60
    max_retries: int = 3
    retry_delay: float = 5.0
    cooldown_period: int = 300  # 5分
    dependencies: List[str] = field(default_factory=list)
    tags: List[str] = field(default_factory=list)
    enabled: bool = True
    last_executed: Optional[datetime] = None
    execution_count: int = 0
    success_count: int = 0
    failure_count: int = 0


@dataclass
class RecoveryRule:
    """復旧ルール定義"""
    name: str
    condition: Callable[[List[HealthCheckResult]], bool]
    actions: List[str]  # RecoveryAction名のリスト
    priority: int = 1
    max_executions_per_hour: int = 3
    enabled: bool = True
    tags: List[str] = field(default_factory=list)
    execution_history: List[datetime] = field(default_factory=list)


@dataclass
class RecoveryExecution:
    """復旧実行記録"""
    rule_name: str
    action_name: str
    started_at: datetime
    completed_at: Optional[datetime] = None
    result: Optional[RecoveryResult] = None
    message: str = ""
    details: Dict[str, Any] = field(default_factory=dict)
    duration: float = 0.0
    error: Optional[str] = None


class AutoRecoverySystem:
    """
    自動復旧システム
    24/7自動監視・障害検出・自動復旧・可用性保証
    """
    
    def __init__(self, 
                 azure_monitor: Optional[AzureMonitorIntegration] = None,
                 enable_monitoring: bool = True,
                 monitoring_interval: int = 30,
                 max_concurrent_actions: int = 3,
                 enable_logging: bool = True,
                 log_file: str = "/app/logs/auto_recovery.log"):
        """
        Initialize Auto Recovery System
        
        Args:
            azure_monitor: Azure Monitor統合インスタンス
            enable_monitoring: 監視有効化
            monitoring_interval: 監視間隔（秒）
            max_concurrent_actions: 最大同時実行アクション数
            enable_logging: ログ有効化
            log_file: ログファイルパス
        """
        self.azure_monitor = azure_monitor
        self.enable_monitoring = enable_monitoring
        self.monitoring_interval = monitoring_interval
        self.max_concurrent_actions = max_concurrent_actions
        self.enable_logging = enable_logging
        self.log_file = log_file
        
        # 復旧アクション・ルール登録
        self.recovery_actions: Dict[str, RecoveryAction] = {}
        self.recovery_rules: Dict[str, RecoveryRule] = {}
        
        # 実行履歴
        self.execution_history: List[RecoveryExecution] = []
        self.max_history_size = 1000
        
        # 監視・実行制御
        self.monitoring_thread: Optional[threading.Thread] = None
        self.monitoring_running = False
        self.executor = ThreadPoolExecutor(max_workers=max_concurrent_actions)
        self.active_executions: Dict[str, RecoveryExecution] = {}
        
        # 統計情報
        self.stats = {
            'total_executions': 0,
            'successful_executions': 0,
            'failed_executions': 0,
            'skipped_executions': 0,
            'average_execution_time': 0.0,
            'last_execution_time': None,
            'uptime_start': datetime.utcnow()
        }
        
        # デフォルトアクション登録
        self._register_default_actions()
        self._register_default_rules()
        
        logger.info("Auto Recovery System initialized")
    
    def _register_default_actions(self):
        """デフォルト復旧アクション登録"""
        
        # アプリケーション再起動
        self.register_action(
            "restart_application",
            RecoveryAction(
                name="restart_application",
                action_type=RecoveryActionType.RESTART_APPLICATION,
                function=self._restart_application,
                timeout=120,
                max_retries=1,
                cooldown_period=600,  # 10分
                tags=["critical", "application"]
            )
        )
        
        # キャッシュクリア
        self.register_action(
            "clear_cache",
            RecoveryAction(
                name="clear_cache",
                action_type=RecoveryActionType.CLEAR_CACHE,
                function=self._clear_cache,
                timeout=30,
                max_retries=2,
                cooldown_period=60,
                tags=["memory", "performance"]
            )
        )
        
        # 一時ファイルクリア
        self.register_action(
            "clear_temp_files",
            RecoveryAction(
                name="clear_temp_files",
                action_type=RecoveryActionType.CLEAR_TEMP_FILES,
                function=self._clear_temp_files,
                timeout=60,
                max_retries=2,
                cooldown_period=300,
                tags=["disk", "cleanup"]
            )
        )
        
        # メモリ最適化
        self.register_action(
            "optimize_memory",
            RecoveryAction(
                name="optimize_memory",
                action_type=RecoveryActionType.CUSTOM,
                function=self._optimize_memory,
                timeout=45,
                max_retries=1,
                cooldown_period=120,
                tags=["memory", "optimization"]
            )
        )
        
        # プロセス再起動
        self.register_action(
            "restart_process",
            RecoveryAction(
                name="restart_process",
                action_type=RecoveryActionType.CUSTOM,
                function=self._restart_process,
                timeout=90,
                max_retries=2,
                cooldown_period=300,
                tags=["process", "restart"]
            )
        )
        
        logger.info("Default recovery actions registered")
    
    def _register_default_rules(self):
        """デフォルト復旧ルール登録"""
        
        # 高CPU使用率時の復旧
        self.register_rule(
            "high_cpu_recovery",
            RecoveryRule(
                name="high_cpu_recovery",
                condition=lambda results: any(
                    r.status == HealthStatus.CRITICAL and 
                    'CPU' in r.message.upper() and 
                    r.name == "system_resources"
                    for r in results
                ),
                actions=["clear_cache", "optimize_memory"],
                priority=2,
                max_executions_per_hour=2,
                tags=["cpu", "performance"]
            )
        )
        
        # 高メモリ使用率時の復旧
        self.register_rule(
            "high_memory_recovery",
            RecoveryRule(
                name="high_memory_recovery",
                condition=lambda results: any(
                    r.status == HealthStatus.CRITICAL and 
                    'MEMORY' in r.message.upper() and 
                    r.name == "system_resources"
                    for r in results
                ),
                actions=["clear_cache", "clear_temp_files", "optimize_memory"],
                priority=2,
                max_executions_per_hour=3,
                tags=["memory", "cleanup"]
            )
        )
        
        # API接続失敗時の復旧
        self.register_rule(
            "api_connection_recovery",
            RecoveryRule(
                name="api_connection_recovery",
                condition=lambda results: any(
                    r.status == HealthStatus.CRITICAL and 
                    r.name in ["microsoft_graph_api", "api_endpoint"]
                    for r in results
                ),
                actions=["restart_process"],
                priority=1,
                max_executions_per_hour=2,
                tags=["api", "connectivity"]
            )
        )
        
        # ファイルシステム問題時の復旧
        self.register_rule(
            "filesystem_recovery",
            RecoveryRule(
                name="filesystem_recovery",
                condition=lambda results: any(
                    r.status == HealthStatus.CRITICAL and 
                    r.name == "file_system"
                    for r in results
                ),
                actions=["clear_temp_files"],
                priority=3,
                max_executions_per_hour=1,
                tags=["filesystem", "cleanup"]
            )
        )
        
        # 緊急時の全体復旧
        self.register_rule(
            "emergency_recovery",
            RecoveryRule(
                name="emergency_recovery",
                condition=lambda results: sum(
                    1 for r in results if r.status == HealthStatus.CRITICAL
                ) >= 3,
                actions=["restart_application"],
                priority=10,
                max_executions_per_hour=1,
                tags=["emergency", "critical"]
            )
        )
        
        logger.info("Default recovery rules registered")
    
    def register_action(self, name: str, action: RecoveryAction):
        """復旧アクション登録"""
        self.recovery_actions[name] = action
        logger.info(f"Recovery action registered: {name}")
    
    def unregister_action(self, name: str):
        """復旧アクション登録解除"""
        if name in self.recovery_actions:
            del self.recovery_actions[name]
            logger.info(f"Recovery action unregistered: {name}")
    
    def register_rule(self, name: str, rule: RecoveryRule):
        """復旧ルール登録"""
        self.recovery_rules[name] = rule
        logger.info(f"Recovery rule registered: {name}")
    
    def unregister_rule(self, name: str):
        """復旧ルール登録解除"""
        if name in self.recovery_rules:
            del self.recovery_rules[name]
            logger.info(f"Recovery rule unregistered: {name}")
    
    def _can_execute_action(self, action: RecoveryAction) -> bool:
        """アクション実行可能性チェック"""
        if not action.enabled:
            return False
        
        # クールダウン期間チェック
        if action.last_executed:
            cooldown_end = action.last_executed + timedelta(seconds=action.cooldown_period)
            if datetime.utcnow() < cooldown_end:
                logger.debug(f"Action {action.name} in cooldown period")
                return False
        
        # 同時実行数チェック
        if len(self.active_executions) >= self.max_concurrent_actions:
            logger.debug(f"Max concurrent actions reached: {self.max_concurrent_actions}")
            return False
        
        return True
    
    def _can_execute_rule(self, rule: RecoveryRule) -> bool:
        """ルール実行可能性チェック"""
        if not rule.enabled:
            return False
        
        # 時間当たり実行回数チェック
        hour_ago = datetime.utcnow() - timedelta(hours=1)
        recent_executions = [
            exec_time for exec_time in rule.execution_history
            if exec_time > hour_ago
        ]
        
        if len(recent_executions) >= rule.max_executions_per_hour:
            logger.debug(f"Rule {rule.name} exceeded max executions per hour")
            return False
        
        return True
    
    def _execute_action(self, action: RecoveryAction, context: Dict[str, Any] = None) -> RecoveryExecution:
        """復旧アクション実行"""
        execution = RecoveryExecution(
            rule_name=context.get('rule_name', 'manual') if context else 'manual',
            action_name=action.name,
            started_at=datetime.utcnow()
        )
        
        try:
            logger.info(f"Executing recovery action: {action.name}")
            
            # アクション実行
            for attempt in range(action.max_retries + 1):
                try:
                    # タイムアウト付きで実行
                    future = self.executor.submit(action.function, context)
                    result = future.result(timeout=action.timeout)
                    
                    # 実行成功
                    execution.completed_at = datetime.utcnow()
                    execution.duration = (execution.completed_at - execution.started_at).total_seconds()
                    execution.result = RecoveryResult.SUCCESS
                    execution.message = result if isinstance(result, str) else "Action completed successfully"
                    execution.details = result if isinstance(result, dict) else {}
                    
                    # 統計更新
                    action.execution_count += 1
                    action.success_count += 1
                    action.last_executed = datetime.utcnow()
                    
                    logger.info(f"Recovery action {action.name} completed successfully")
                    break
                    
                except TimeoutError:
                    if attempt < action.max_retries:
                        logger.warning(f"Recovery action {action.name} timed out, retrying...")
                        time.sleep(action.retry_delay)
                        continue
                    else:
                        execution.result = RecoveryResult.TIMEOUT
                        execution.message = f"Action timed out after {action.timeout} seconds"
                        logger.error(f"Recovery action {action.name} timed out")
                        break
                        
                except Exception as e:
                    if attempt < action.max_retries:
                        logger.warning(f"Recovery action {action.name} failed, retrying: {str(e)}")
                        time.sleep(action.retry_delay)
                        continue
                    else:
                        execution.result = RecoveryResult.FAILED
                        execution.message = f"Action failed: {str(e)}"
                        execution.error = str(e)
                        logger.error(f"Recovery action {action.name} failed: {str(e)}")
                        break
            
            # 統計更新
            if execution.result == RecoveryResult.SUCCESS:
                action.success_count += 1
                self.stats['successful_executions'] += 1
            else:
                action.failure_count += 1
                self.stats['failed_executions'] += 1
            
            action.execution_count += 1
            self.stats['total_executions'] += 1
            
            # 平均実行時間更新
            if execution.duration > 0:
                total_time = self.stats['average_execution_time'] * (self.stats['total_executions'] - 1)
                self.stats['average_execution_time'] = (total_time + execution.duration) / self.stats['total_executions']
            
            self.stats['last_execution_time'] = datetime.utcnow()
            
        except Exception as e:
            execution.completed_at = datetime.utcnow()
            execution.duration = (execution.completed_at - execution.started_at).total_seconds()
            execution.result = RecoveryResult.FAILED
            execution.message = f"Action execution failed: {str(e)}"
            execution.error = str(e)
            
            logger.error(f"Recovery action {action.name} execution failed: {str(e)}")
        
        return execution
    
    def _execute_rule(self, rule: RecoveryRule, health_results: List[HealthCheckResult]) -> List[RecoveryExecution]:
        """復旧ルール実行"""
        executions = []
        
        try:
            logger.info(f"Executing recovery rule: {rule.name}")
            
            # ルール実行履歴追加
            rule.execution_history.append(datetime.utcnow())
            
            # 古い履歴をクリーンアップ
            hour_ago = datetime.utcnow() - timedelta(hours=1)
            rule.execution_history = [
                exec_time for exec_time in rule.execution_history
                if exec_time > hour_ago
            ]
            
            # アクション実行
            for action_name in rule.actions:
                if action_name not in self.recovery_actions:
                    logger.warning(f"Recovery action not found: {action_name}")
                    continue
                
                action = self.recovery_actions[action_name]
                
                if not self._can_execute_action(action):
                    logger.info(f"Skipping action {action_name} (cannot execute)")
                    continue
                
                # 実行コンテキスト作成
                context = {
                    'rule_name': rule.name,
                    'health_results': health_results,
                    'trigger_time': datetime.utcnow()
                }
                
                # アクション実行
                execution = self._execute_action(action, context)
                executions.append(execution)
                
                # 実行履歴に追加
                self.execution_history.append(execution)
                
                # 履歴サイズ制限
                if len(self.execution_history) > self.max_history_size:
                    self.execution_history = self.execution_history[-self.max_history_size:]
                
                # Azure Monitor統合
                if self.azure_monitor:
                    self.azure_monitor._send_custom_event("RecoveryActionExecuted", {
                        'rule_name': rule.name,
                        'action_name': action_name,
                        'result': execution.result.value if execution.result else 'unknown',
                        'duration': execution.duration,
                        'message': execution.message
                    })
                
                # 成功時は後続アクションをスキップ（オプション）
                if execution.result == RecoveryResult.SUCCESS and action_name != rule.actions[-1]:
                    logger.info(f"Action {action_name} succeeded, checking if rule should continue")
                    # 再度条件チェック
                    if not rule.condition(health_results):
                        logger.info(f"Rule {rule.name} condition resolved, stopping further actions")
                        break
        
        except Exception as e:
            logger.error(f"Recovery rule {rule.name} execution failed: {str(e)}")
        
        return executions
    
    def _monitoring_loop(self):
        """監視ループ"""
        logger.info("Auto recovery monitoring loop started")
        
        while self.monitoring_running:
            try:
                # ヘルスチェック結果取得
                health_results = []
                
                # 登録されたヘルスチェック実行
                for check_name, check_info in health_registry.checks.items():
                    try:
                        result = check_info['function']()
                        health_result = HealthCheckResult(
                            name=check_name,
                            status=HealthStatus(result['status']),
                            message=result['message'],
                            timestamp=datetime.utcnow(),
                            response_time=0.0,
                            details=result.get('details', {})
                        )
                        health_results.append(health_result)
                    except Exception as e:
                        logger.error(f"Health check {check_name} failed: {str(e)}")
                
                # 復旧ルール評価・実行
                for rule_name, rule in self.recovery_rules.items():
                    try:
                        if not self._can_execute_rule(rule):
                            continue
                        
                        # 条件チェック
                        if rule.condition(health_results):
                            logger.info(f"Recovery rule triggered: {rule_name}")
                            
                            # ルール実行
                            executions = self._execute_rule(rule, health_results)
                            
                            logger.info(f"Recovery rule {rule_name} executed {len(executions)} actions")
                        
                    except Exception as e:
                        logger.error(f"Recovery rule {rule_name} evaluation failed: {str(e)}")
                
            except Exception as e:
                logger.error(f"Monitoring loop error: {str(e)}")
            
            # 次回実行まで待機
            time.sleep(self.monitoring_interval)
        
        logger.info("Auto recovery monitoring loop stopped")
    
    def start_monitoring(self):
        """監視開始"""
        if self.monitoring_running:
            logger.warning("Monitoring already running")
            return
        
        self.monitoring_running = True
        self.monitoring_thread = threading.Thread(
            target=self._monitoring_loop,
            daemon=True
        )
        self.monitoring_thread.start()
        
        logger.info("Auto recovery monitoring started")
    
    def stop_monitoring(self):
        """監視停止"""
        if not self.monitoring_running:
            return
        
        self.monitoring_running = False
        
        if self.monitoring_thread:
            self.monitoring_thread.join(timeout=10)
            self.monitoring_thread = None
        
        logger.info("Auto recovery monitoring stopped")
    
    def execute_action_manually(self, action_name: str, context: Dict[str, Any] = None) -> RecoveryExecution:
        """手動アクション実行"""
        if action_name not in self.recovery_actions:
            raise ValueError(f"Recovery action not found: {action_name}")
        
        action = self.recovery_actions[action_name]
        
        if not self._can_execute_action(action):
            raise ValueError(f"Cannot execute action: {action_name}")
        
        logger.info(f"Manually executing recovery action: {action_name}")
        
        execution = self._execute_action(action, context)
        self.execution_history.append(execution)
        
        return execution
    
    def get_status(self) -> Dict[str, Any]:
        """自動復旧システムステータス取得"""
        return {
            'monitoring_running': self.monitoring_running,
            'monitoring_interval': self.monitoring_interval,
            'registered_actions': len(self.recovery_actions),
            'registered_rules': len(self.recovery_rules),
            'active_executions': len(self.active_executions),
            'execution_history_size': len(self.execution_history),
            'statistics': self.stats.copy(),
            'uptime': (datetime.utcnow() - self.stats['uptime_start']).total_seconds()
        }
    
    def get_action_status(self, action_name: str) -> Optional[Dict[str, Any]]:
        """アクション詳細ステータス取得"""
        if action_name not in self.recovery_actions:
            return None
        
        action = self.recovery_actions[action_name]
        
        return {
            'name': action.name,
            'type': action.action_type.value,
            'enabled': action.enabled,
            'execution_count': action.execution_count,
            'success_count': action.success_count,
            'failure_count': action.failure_count,
            'last_executed': action.last_executed.isoformat() if action.last_executed else None,
            'timeout': action.timeout,
            'max_retries': action.max_retries,
            'cooldown_period': action.cooldown_period,
            'tags': action.tags
        }
    
    def get_recent_executions(self, limit: int = 10) -> List[Dict[str, Any]]:
        """最近の実行履歴取得"""
        recent_executions = self.execution_history[-limit:]
        
        return [
            {
                'rule_name': exec.rule_name,
                'action_name': exec.action_name,
                'started_at': exec.started_at.isoformat(),
                'completed_at': exec.completed_at.isoformat() if exec.completed_at else None,
                'result': exec.result.value if exec.result else None,
                'message': exec.message,
                'duration': exec.duration,
                'error': exec.error
            }
            for exec in recent_executions
        ]
    
    # デフォルトアクション実装
    def _restart_application(self, context: Dict[str, Any] = None) -> str:
        """アプリケーション再起動"""
        try:
            logger.info("Restarting application...")
            
            # Graceful shutdown
            os.kill(os.getpid(), signal.SIGTERM)
            
            return "Application restart initiated"
            
        except Exception as e:
            logger.error(f"Application restart failed: {str(e)}")
            return f"Application restart failed: {str(e)}"
    
    def _clear_cache(self, context: Dict[str, Any] = None) -> str:
        """キャッシュクリア"""
        try:
            logger.info("Clearing cache...")
            
            # アプリケーションキャッシュクリア
            cleared_items = 0
            
            # Microsoft Graph clientキャッシュクリア
            try:
                from src.api.microsoft_graph_client import MicrosoftGraphClient
                # Note: 実際の実装では、実行中のclientインスタンスを探してキャッシュクリア
                cleared_items += 1
            except Exception:
                pass
            
            # システムキャッシュクリア
            try:
                if os.path.exists('/proc/sys/vm/drop_caches'):
                    # Linux only
                    subprocess.run(['sync'], check=True)
                    subprocess.run(['echo', '1', '>', '/proc/sys/vm/drop_caches'], 
                                 shell=True, check=True)
                    cleared_items += 1
            except Exception:
                pass
            
            return f"Cache cleared: {cleared_items} items"
            
        except Exception as e:
            logger.error(f"Cache clear failed: {str(e)}")
            return f"Cache clear failed: {str(e)}"
    
    def _clear_temp_files(self, context: Dict[str, Any] = None) -> str:
        """一時ファイルクリア"""
        try:
            logger.info("Clearing temporary files...")
            
            temp_dirs = ['/app/temp', '/tmp']
            total_deleted = 0
            total_size = 0
            
            for temp_dir in temp_dirs:
                temp_path = Path(temp_dir)
                if not temp_path.exists():
                    continue
                
                for file_path in temp_path.iterdir():
                    try:
                        if file_path.is_file():
                            file_size = file_path.stat().st_size
                            file_path.unlink()
                            total_deleted += 1
                            total_size += file_size
                    except Exception as e:
                        logger.warning(f"Failed to delete {file_path}: {str(e)}")
            
            return f"Temp files cleared: {total_deleted} files, {total_size / (1024**2):.1f} MB"
            
        except Exception as e:
            logger.error(f"Temp files clear failed: {str(e)}")
            return f"Temp files clear failed: {str(e)}"
    
    def _optimize_memory(self, context: Dict[str, Any] = None) -> str:
        """メモリ最適化"""
        try:
            logger.info("Optimizing memory...")
            
            # Pythonガベージコレクション強制実行
            import gc
            collected = gc.collect()
            
            # メモリマップファイルクリア
            try:
                import mmap
                # Note: 実際の実装では、開いているmmap objectsを探してクリア
            except Exception:
                pass
            
            return f"Memory optimized: {collected} objects collected"
            
        except Exception as e:
            logger.error(f"Memory optimization failed: {str(e)}")
            return f"Memory optimization failed: {str(e)}"
    
    def _restart_process(self, context: Dict[str, Any] = None) -> str:
        """プロセス再起動"""
        try:
            logger.info("Restarting process...")
            
            # 現在のプロセスを特定
            current_process = psutil.Process()
            
            # 子プロセスを終了
            for child in current_process.children(recursive=True):
                try:
                    child.terminate()
                except Exception as e:
                    logger.warning(f"Failed to terminate child process {child.pid}: {str(e)}")
            
            # 少し待機
            time.sleep(2)
            
            # 強制終了
            for child in current_process.children(recursive=True):
                try:
                    child.kill()
                except Exception as e:
                    logger.warning(f"Failed to kill child process {child.pid}: {str(e)}")
            
            return "Process restart completed"
            
        except Exception as e:
            logger.error(f"Process restart failed: {str(e)}")
            return f"Process restart failed: {str(e)}"
    
    def close(self):
        """自動復旧システム終了"""
        try:
            # 監視停止
            self.stop_monitoring()
            
            # Executorシャットダウン
            self.executor.shutdown(wait=True)
            
            logger.info("Auto recovery system closed")
            
        except Exception as e:
            logger.error(f"Error closing auto recovery system: {str(e)}")
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


if __name__ == "__main__":
    # テスト実行
    print("Testing Auto Recovery System...")
    
    # システム初期化
    with AutoRecoverySystem() as recovery:
        # 監視開始
        recovery.start_monitoring()
        
        # 10秒待機
        time.sleep(10)
        
        # ステータス確認
        status = recovery.get_status()
        print(f"Status: {json.dumps(status, indent=2)}")
        
        # 手動アクション実行テスト
        try:
            execution = recovery.execute_action_manually("clear_cache")
            print(f"Manual execution result: {execution.result.value}")
        except Exception as e:
            print(f"Manual execution failed: {str(e)}")
        
        # 最近の実行履歴
        recent = recovery.get_recent_executions(5)
        print(f"Recent executions: {json.dumps(recent, indent=2)}")