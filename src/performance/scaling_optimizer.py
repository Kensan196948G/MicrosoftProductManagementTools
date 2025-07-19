#!/usr/bin/env python3
"""
High-Performance Scaling Optimizer - 4-Hour Emergency Implementation
Enterprise-grade autoscaling and performance optimization
"""

import asyncio
import logging
import time
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import threading
import psutil
import math

# FastAPI performance
from fastapi import FastAPI, BackgroundTasks
from fastapi.concurrency import run_in_threadpool
import uvicorn

# Async processing
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
from multiprocessing import cpu_count

# Memory optimization
import gc
import weakref
from functools import lru_cache, wraps
import pickle
import gzip

from src.core.config import get_settings

logger = logging.getLogger(__name__)


class ScalingTrigger(str, Enum):
    """スケーリングトリガー"""
    CPU_THRESHOLD = "cpu_threshold"
    MEMORY_THRESHOLD = "memory_threshold"
    REQUEST_RATE = "request_rate"
    RESPONSE_TIME = "response_time"
    QUEUE_LENGTH = "queue_length"
    MANUAL = "manual"


class ScalingDirection(str, Enum):
    """スケーリング方向"""
    SCALE_UP = "scale_up"
    SCALE_DOWN = "scale_down"
    MAINTAIN = "maintain"


@dataclass
class PerformanceMetrics:
    """パフォーマンス指標"""
    timestamp: datetime
    cpu_percent: float
    memory_percent: float
    request_rate_per_second: float
    avg_response_time_ms: float
    active_connections: int
    queue_length: int
    throughput_rps: float
    error_rate_percent: float
    
    def is_under_pressure(self) -> bool:
        """負荷状況判定"""
        return (
            self.cpu_percent > 80 or 
            self.memory_percent > 85 or 
            self.avg_response_time_ms > 1000 or
            self.error_rate_percent > 5
        )


@dataclass
class ScalingRule:
    """スケーリングルール"""
    name: str
    trigger: ScalingTrigger
    threshold_up: float
    threshold_down: float
    scale_factor: float = 1.5
    cooldown_seconds: int = 300
    min_instances: int = 1
    max_instances: int = 10
    
    last_scaling: Optional[datetime] = None
    enabled: bool = True


class ConnectionPoolOptimizer:
    """接続プール最適化"""
    
    def __init__(self):
        self.pools: Dict[str, Any] = {}
        self.pool_stats: Dict[str, Dict[str, Any]] = {}
        
    async def optimize_pool_size(self, pool_name: str, current_load: float) -> int:
        """負荷に応じてプールサイズ最適化"""
        try:
            base_size = 10
            max_size = 100
            
            # 負荷に応じたプールサイズ計算
            if current_load < 30:
                optimal_size = max(base_size, int(base_size * 0.7))
            elif current_load < 60:
                optimal_size = base_size
            elif current_load < 80:
                optimal_size = int(base_size * 1.5)
            else:
                optimal_size = min(max_size, int(base_size * 2))
            
            logger.info(f"Optimized pool size for {pool_name}: {optimal_size} (load: {current_load}%)")
            return optimal_size
            
        except Exception as e:
            logger.error(f"Pool optimization error: {e}")
            return base_size


class MemoryOptimizer:
    """メモリ最適化"""
    
    def __init__(self):
        self.cache_stats = {"hits": 0, "misses": 0, "size": 0}
        self.weak_refs: weakref.WeakSet = weakref.WeakSet()
        
    async def optimize_memory_usage(self) -> Dict[str, Any]:
        """メモリ使用量最適化"""
        try:
            initial_memory = psutil.virtual_memory().percent
            
            # 1. ガベージコレクション
            collected = gc.collect()
            
            # 2. キャッシュクリーンアップ
            cache_cleared = self._cleanup_caches()
            
            # 3. 弱参照クリーンアップ
            weak_refs_cleared = len(self.weak_refs)
            self.weak_refs.clear()
            
            # 4. システムキャッシュ最適化
            system_optimized = await self._optimize_system_cache()
            
            final_memory = psutil.virtual_memory().percent
            memory_freed = initial_memory - final_memory
            
            result = {
                "initial_memory_percent": initial_memory,
                "final_memory_percent": final_memory,
                "memory_freed_percent": memory_freed,
                "gc_collected": collected,
                "cache_cleared": cache_cleared,
                "weak_refs_cleared": weak_refs_cleared,
                "system_optimized": system_optimized
            }
            
            logger.info(f"Memory optimization completed: {memory_freed:.2f}% freed")
            return result
            
        except Exception as e:
            logger.error(f"Memory optimization error: {e}")
            return {"error": str(e)}
    
    def _cleanup_caches(self) -> int:
        """キャッシュクリーンアップ"""
        try:
            # LRUキャッシュクリア
            cleared_count = 0
            
            # グローバルキャッシュクリア（実装依存）
            if hasattr(self, '_global_cache'):
                cleared_count = len(self._global_cache)
                self._global_cache.clear()
            
            return cleared_count
            
        except Exception as e:
            logger.warning(f"Cache cleanup warning: {e}")
            return 0
    
    async def _optimize_system_cache(self) -> bool:
        """システムキャッシュ最適化"""
        try:
            # OS レベルのキャッシュ最適化（プラットフォーム依存）
            import platform
            
            if platform.system() == "Linux":
                # Linux の場合
                try:
                    await asyncio.create_subprocess_exec(
                        "sync", stdout=asyncio.subprocess.PIPE
                    )
                    return True
                except:
                    pass
            
            return True
            
        except Exception:
            return False


class RequestLoadBalancer:
    """リクエスト負荷分散"""
    
    def __init__(self, max_workers: int = None):
        self.max_workers = max_workers or min(32, (cpu_count() or 1) + 4)
        self.thread_pool = ThreadPoolExecutor(max_workers=self.max_workers)
        self.process_pool = ProcessPoolExecutor(max_workers=cpu_count() or 1)
        
        self.request_queue = asyncio.Queue(maxsize=1000)
        self.workers_busy = 0
        self.total_requests = 0
        self.completed_requests = 0
        
    async def distribute_request(self, request_func: Callable, *args, **kwargs) -> Any:
        """リクエスト分散処理"""
        try:
            self.total_requests += 1
            
            # キューが満杯の場合は即座に処理
            if self.request_queue.full():
                logger.warning("Request queue full, processing immediately")
                return await self._execute_request(request_func, *args, **kwargs)
            
            # キューに追加
            await self.request_queue.put((request_func, args, kwargs))
            
            # 処理実行
            result = await self._process_queue()
            return result
            
        except Exception as e:
            logger.error(f"Request distribution error: {e}")
            raise
    
    async def _execute_request(self, request_func: Callable, *args, **kwargs) -> Any:
        """リクエスト実行"""
        try:
            self.workers_busy += 1
            
            if asyncio.iscoroutinefunction(request_func):
                result = await request_func(*args, **kwargs)
            else:
                # CPU集約的なタスクはプロセスプールで実行
                if getattr(request_func, '_cpu_intensive', False):
                    result = await asyncio.get_event_loop().run_in_executor(
                        self.process_pool, request_func, *args
                    )
                else:
                    # I/O集約的なタスクはスレッドプールで実行
                    result = await asyncio.get_event_loop().run_in_executor(
                        self.thread_pool, request_func, *args
                    )
            
            self.completed_requests += 1
            return result
            
        finally:
            self.workers_busy -= 1
    
    async def _process_queue(self) -> Any:
        """キュー処理"""
        try:
            request_func, args, kwargs = await asyncio.wait_for(
                self.request_queue.get(), timeout=1.0
            )
            result = await self._execute_request(request_func, *args, **kwargs)
            self.request_queue.task_done()
            return result
            
        except asyncio.TimeoutError:
            raise Exception("Request queue timeout")
    
    def get_load_stats(self) -> Dict[str, Any]:
        """負荷統計取得"""
        return {
            "max_workers": self.max_workers,
            "workers_busy": self.workers_busy,
            "queue_size": self.request_queue.qsize(),
            "total_requests": self.total_requests,
            "completed_requests": self.completed_requests,
            "completion_rate": (
                self.completed_requests / self.total_requests * 100 
                if self.total_requests > 0 else 0
            )
        }
    
    async def close(self):
        """リソースクリーンアップ"""
        self.thread_pool.shutdown(wait=True)
        self.process_pool.shutdown(wait=True)


class AdaptiveScaler:
    """適応型スケーラー"""
    
    def __init__(self):
        self.scaling_rules: List[ScalingRule] = []
        self.metrics_history: List[PerformanceMetrics] = []
        self.current_instances = 1
        self.target_instances = 1
        
        # コンポーネント
        self.connection_optimizer = ConnectionPoolOptimizer()
        self.memory_optimizer = MemoryOptimizer()
        self.load_balancer = RequestLoadBalancer()
        
        # スケーリング状態
        self.is_scaling = False
        self.last_scale_time = datetime.utcnow()
        
    async def initialize_default_rules(self):
        """デフォルトスケーリングルール初期化"""
        self.scaling_rules = [
            ScalingRule(
                name="cpu_scaling",
                trigger=ScalingTrigger.CPU_THRESHOLD,
                threshold_up=75.0,
                threshold_down=40.0,
                scale_factor=1.5,
                cooldown_seconds=180
            ),
            ScalingRule(
                name="memory_scaling", 
                trigger=ScalingTrigger.MEMORY_THRESHOLD,
                threshold_up=80.0,
                threshold_down=50.0,
                scale_factor=1.3,
                cooldown_seconds=240
            ),
            ScalingRule(
                name="response_time_scaling",
                trigger=ScalingTrigger.RESPONSE_TIME,
                threshold_up=800.0,  # 800ms
                threshold_down=300.0, # 300ms
                scale_factor=2.0,
                cooldown_seconds=120
            ),
            ScalingRule(
                name="request_rate_scaling",
                trigger=ScalingTrigger.REQUEST_RATE,
                threshold_up=100.0,  # 100 RPS
                threshold_down=20.0,  # 20 RPS
                scale_factor=1.8,
                cooldown_seconds=150
            )
        ]
        
        logger.info(f"Initialized {len(self.scaling_rules)} scaling rules")
    
    async def collect_metrics(self) -> PerformanceMetrics:
        """パフォーマンス指標収集"""
        try:
            current_time = datetime.utcnow()
            
            # システムメトリクス
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            
            # アプリケーションメトリクス
            load_stats = self.load_balancer.get_load_stats()
            
            # 応答時間計算（模擬）
            avg_response_time = self._calculate_avg_response_time()
            
            # エラー率計算（模擬）
            error_rate = self._calculate_error_rate()
            
            metrics = PerformanceMetrics(
                timestamp=current_time,
                cpu_percent=cpu_percent,
                memory_percent=memory.percent,
                request_rate_per_second=load_stats["completion_rate"] / 60,  # 模擬値
                avg_response_time_ms=avg_response_time,
                active_connections=load_stats["workers_busy"],
                queue_length=load_stats["queue_size"],
                throughput_rps=load_stats["completion_rate"] / 60,
                error_rate_percent=error_rate
            )
            
            # 履歴に追加（最新100件保持）
            self.metrics_history.append(metrics)
            if len(self.metrics_history) > 100:
                self.metrics_history = self.metrics_history[-100:]
            
            return metrics
            
        except Exception as e:
            logger.error(f"Metrics collection error: {e}")
            # デフォルト値返却
            return PerformanceMetrics(
                timestamp=datetime.utcnow(),
                cpu_percent=0,
                memory_percent=0,
                request_rate_per_second=0,
                avg_response_time_ms=0,
                active_connections=0,
                queue_length=0,
                throughput_rps=0,
                error_rate_percent=0
            )
    
    def _calculate_avg_response_time(self) -> float:
        """平均応答時間計算"""
        if len(self.metrics_history) < 5:
            return 200.0  # デフォルト値
        
        recent_metrics = self.metrics_history[-5:]
        return sum(m.avg_response_time_ms for m in recent_metrics) / len(recent_metrics)
    
    def _calculate_error_rate(self) -> float:
        """エラー率計算"""
        if len(self.metrics_history) < 5:
            return 0.0
        
        recent_metrics = self.metrics_history[-5:]
        return sum(m.error_rate_percent for m in recent_metrics) / len(recent_metrics)
    
    async def evaluate_scaling_decision(self, metrics: PerformanceMetrics) -> ScalingDirection:
        """スケーリング判定"""
        try:
            current_time = datetime.utcnow()
            
            # クールダウン期間チェック
            if (current_time - self.last_scale_time).total_seconds() < 60:
                return ScalingDirection.MAINTAIN
            
            scale_up_votes = 0
            scale_down_votes = 0
            
            for rule in self.scaling_rules:
                if not rule.enabled:
                    continue
                
                # クールダウンチェック
                if (rule.last_scaling and 
                    (current_time - rule.last_scaling).total_seconds() < rule.cooldown_seconds):
                    continue
                
                # メトリクス値取得
                metric_value = self._get_metric_value(metrics, rule.trigger)
                
                if metric_value >= rule.threshold_up:
                    scale_up_votes += 1
                elif metric_value <= rule.threshold_down:
                    scale_down_votes += 1
            
            # スケーリング決定
            if scale_up_votes > scale_down_votes and scale_up_votes >= 2:
                return ScalingDirection.SCALE_UP
            elif scale_down_votes > scale_up_votes and scale_down_votes >= 2:
                # 最小インスタンス数チェック
                if self.current_instances > 1:
                    return ScalingDirection.SCALE_DOWN
            
            return ScalingDirection.MAINTAIN
            
        except Exception as e:
            logger.error(f"Scaling decision error: {e}")
            return ScalingDirection.MAINTAIN
    
    def _get_metric_value(self, metrics: PerformanceMetrics, trigger: ScalingTrigger) -> float:
        """トリガーに応じたメトリクス値取得"""
        mapping = {
            ScalingTrigger.CPU_THRESHOLD: metrics.cpu_percent,
            ScalingTrigger.MEMORY_THRESHOLD: metrics.memory_percent,
            ScalingTrigger.REQUEST_RATE: metrics.request_rate_per_second,
            ScalingTrigger.RESPONSE_TIME: metrics.avg_response_time_ms,
            ScalingTrigger.QUEUE_LENGTH: float(metrics.queue_length)
        }
        return mapping.get(trigger, 0.0)
    
    async def execute_scaling(self, direction: ScalingDirection, metrics: PerformanceMetrics) -> Dict[str, Any]:
        """スケーリング実行"""
        try:
            if self.is_scaling:
                return {"status": "already_scaling"}
            
            self.is_scaling = True
            start_time = datetime.utcnow()
            
            scaling_result = {
                "direction": direction.value,
                "start_time": start_time.isoformat(),
                "previous_instances": self.current_instances,
                "actions": []
            }
            
            if direction == ScalingDirection.SCALE_UP:
                result = await self._scale_up(metrics)
                scaling_result["actions"].append(result)
                
            elif direction == ScalingDirection.SCALE_DOWN:
                result = await self._scale_down(metrics)
                scaling_result["actions"].append(result)
            
            # 接続プール最適化
            pool_result = await self.connection_optimizer.optimize_pool_size(
                "main_pool", metrics.cpu_percent
            )
            scaling_result["actions"].append({
                "type": "connection_pool_optimization",
                "optimal_size": pool_result
            })
            
            # メモリ最適化
            if metrics.memory_percent > 70:
                memory_result = await self.memory_optimizer.optimize_memory_usage()
                scaling_result["actions"].append({
                    "type": "memory_optimization",
                    "result": memory_result
                })
            
            scaling_result["current_instances"] = self.current_instances
            scaling_result["end_time"] = datetime.utcnow().isoformat()
            scaling_result["duration_seconds"] = (
                datetime.fromisoformat(scaling_result["end_time"]) - start_time
            ).total_seconds()
            
            self.last_scale_time = datetime.utcnow()
            
            logger.info(f"Scaling completed: {direction.value} - {self.current_instances} instances")
            return scaling_result
            
        except Exception as e:
            logger.error(f"Scaling execution error: {e}")
            return {"status": "error", "message": str(e)}
        finally:
            self.is_scaling = False
    
    async def _scale_up(self, metrics: PerformanceMetrics) -> Dict[str, Any]:
        """スケールアップ実行"""
        try:
            # 最大インスタンス数チェック
            max_instances = min(rule.max_instances for rule in self.scaling_rules)
            if self.current_instances >= max_instances:
                return {
                    "type": "scale_up",
                    "status": "max_instances_reached",
                    "max_instances": max_instances
                }
            
            # スケール係数計算
            scale_factor = 1.5  # デフォルト
            if metrics.cpu_percent > 90:
                scale_factor = 2.0
            elif metrics.avg_response_time_ms > 1000:
                scale_factor = 1.8
            
            new_instances = min(
                max_instances,
                max(self.current_instances + 1, int(self.current_instances * scale_factor))
            )
            
            # ワーカー数増加（模擬）
            additional_workers = new_instances - self.current_instances
            await self._adjust_worker_pool(additional_workers)
            
            self.current_instances = new_instances
            
            return {
                "type": "scale_up",
                "status": "success",
                "scale_factor": scale_factor,
                "additional_workers": additional_workers,
                "new_instances": new_instances
            }
            
        except Exception as e:
            return {
                "type": "scale_up",
                "status": "error",
                "error": str(e)
            }
    
    async def _scale_down(self, metrics: PerformanceMetrics) -> Dict[str, Any]:
        """スケールダウン実行"""
        try:
            # 最小インスタンス数チェック
            min_instances = max(rule.min_instances for rule in self.scaling_rules)
            if self.current_instances <= min_instances:
                return {
                    "type": "scale_down",
                    "status": "min_instances_reached",
                    "min_instances": min_instances
                }
            
            # 安全なスケールダウン係数
            scale_factor = 0.7
            new_instances = max(
                min_instances,
                int(self.current_instances * scale_factor)
            )
            
            # ワーカー数減少
            workers_to_remove = self.current_instances - new_instances
            await self._adjust_worker_pool(-workers_to_remove)
            
            self.current_instances = new_instances
            
            return {
                "type": "scale_down",
                "status": "success",
                "scale_factor": scale_factor,
                "workers_removed": workers_to_remove,
                "new_instances": new_instances
            }
            
        except Exception as e:
            return {
                "type": "scale_down", 
                "status": "error",
                "error": str(e)
            }
    
    async def _adjust_worker_pool(self, worker_delta: int):
        """ワーカープール調整"""
        try:
            if worker_delta > 0:
                # ワーカー追加
                new_max_workers = self.load_balancer.max_workers + worker_delta * 4
                self.load_balancer.max_workers = min(128, new_max_workers)
                
            elif worker_delta < 0:
                # ワーカー削除
                new_max_workers = self.load_balancer.max_workers + worker_delta * 4
                self.load_balancer.max_workers = max(4, new_max_workers)
            
            logger.info(f"Adjusted worker pool to {self.load_balancer.max_workers} workers")
            
        except Exception as e:
            logger.error(f"Worker pool adjustment error: {e}")
    
    def get_scaling_status(self) -> Dict[str, Any]:
        """スケーリング状況取得"""
        try:
            latest_metrics = self.metrics_history[-1] if self.metrics_history else None
            
            return {
                "current_instances": self.current_instances,
                "target_instances": self.target_instances,
                "is_scaling": self.is_scaling,
                "last_scale_time": self.last_scale_time.isoformat(),
                "scaling_rules": [
                    {
                        "name": rule.name,
                        "enabled": rule.enabled,
                        "threshold_up": rule.threshold_up,
                        "threshold_down": rule.threshold_down,
                        "last_scaling": rule.last_scaling.isoformat() if rule.last_scaling else None
                    }
                    for rule in self.scaling_rules
                ],
                "latest_metrics": {
                    "timestamp": latest_metrics.timestamp.isoformat(),
                    "cpu_percent": latest_metrics.cpu_percent,
                    "memory_percent": latest_metrics.memory_percent,
                    "avg_response_time_ms": latest_metrics.avg_response_time_ms,
                    "under_pressure": latest_metrics.is_under_pressure()
                } if latest_metrics else None,
                "load_balancer_stats": self.load_balancer.get_load_stats()
            }
            
        except Exception as e:
            logger.error(f"Scaling status error: {e}")
            return {"error": str(e)}
    
    async def close(self):
        """リソースクリーンアップ"""
        await self.load_balancer.close()
        logger.info("Adaptive Scaler closed")


class PerformanceScalingSystem:
    """パフォーマンススケーリングシステム - メインクラス"""
    
    def __init__(self):
        self.settings = get_settings()
        self.scaler = AdaptiveScaler()
        
        self.is_active = False
        self.monitoring_task: Optional[asyncio.Task] = None
        self.monitoring_interval = 30  # 30秒間隔
        
        # 統計情報
        self.stats = {
            "monitoring_start_time": None,
            "total_scaling_events": 0,
            "scale_up_events": 0,
            "scale_down_events": 0,
            "optimization_events": 0,
            "avg_response_time_improvement": 0.0
        }
        
        logger.info("Performance Scaling System initialized")
    
    async def initialize(self):
        """システム初期化"""
        try:
            await self.scaler.initialize_default_rules()
            logger.info("Performance Scaling System initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Performance Scaling System: {e}")
            raise
    
    async def start_monitoring(self):
        """パフォーマンス監視開始"""
        if self.is_active:
            logger.warning("Performance monitoring is already active")
            return
        
        self.is_active = True
        self.stats["monitoring_start_time"] = datetime.utcnow()
        self.monitoring_task = asyncio.create_task(self._monitoring_loop())
        
        logger.info("Performance scaling monitoring started")
    
    async def stop_monitoring(self):
        """監視停止"""
        if not self.is_active:
            return
        
        self.is_active = False
        
        if self.monitoring_task:
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass
        
        logger.info("Performance scaling monitoring stopped")
    
    async def _monitoring_loop(self):
        """メイン監視ループ"""
        logger.info("Starting performance scaling monitoring loop")
        
        while self.is_active:
            try:
                # 1. メトリクス収集
                metrics = await self.scaler.collect_metrics()
                
                # 2. スケーリング判定
                scaling_decision = await self.scaler.evaluate_scaling_decision(metrics)
                
                # 3. スケーリング実行
                if scaling_decision != ScalingDirection.MAINTAIN:
                    scaling_result = await self.scaler.execute_scaling(scaling_decision, metrics)
                    
                    # 統計更新
                    self.stats["total_scaling_events"] += 1
                    if scaling_decision == ScalingDirection.SCALE_UP:
                        self.stats["scale_up_events"] += 1
                    elif scaling_decision == ScalingDirection.SCALE_DOWN:
                        self.stats["scale_down_events"] += 1
                    
                    logger.info(f"Scaling executed: {scaling_decision.value}")
                
                # 4. 最適化実行（高負荷時）
                if metrics.is_under_pressure():
                    await self._execute_optimizations(metrics)
                
                # 監視間隔待機
                await asyncio.sleep(self.monitoring_interval)
                
            except Exception as e:
                logger.error(f"Error in performance monitoring loop: {e}")
                await asyncio.sleep(60)  # エラー時は長めに待機
    
    async def _execute_optimizations(self, metrics: PerformanceMetrics):
        """パフォーマンス最適化実行"""
        try:
            logger.info("Executing performance optimizations due to high load")
            
            # メモリ最適化
            if metrics.memory_percent > 80:
                memory_result = await self.scaler.memory_optimizer.optimize_memory_usage()
                logger.info(f"Memory optimization: {memory_result.get('memory_freed_percent', 0):.2f}% freed")
            
            # 接続プール最適化
            pool_size = await self.scaler.connection_optimizer.optimize_pool_size(
                "main_pool", metrics.cpu_percent
            )
            
            self.stats["optimization_events"] += 1
            
        except Exception as e:
            logger.error(f"Optimization execution error: {e}")
    
    async def manual_scale(self, direction: ScalingDirection, factor: float = 1.5) -> Dict[str, Any]:
        """手動スケーリング"""
        try:
            logger.info(f"Manual scaling requested: {direction.value}")
            
            # 現在のメトリクス取得
            metrics = await self.scaler.collect_metrics()
            
            # 手動スケーリング実行
            result = await self.scaler.execute_scaling(direction, metrics)
            
            # 統計更新
            self.stats["total_scaling_events"] += 1
            if direction == ScalingDirection.SCALE_UP:
                self.stats["scale_up_events"] += 1
            elif direction == ScalingDirection.SCALE_DOWN:
                self.stats["scale_down_events"] += 1
            
            return result
            
        except Exception as e:
            logger.error(f"Manual scaling error: {e}")
            return {"status": "error", "message": str(e)}
    
    async def force_optimization(self) -> Dict[str, Any]:
        """強制最適化実行"""
        try:
            logger.info("Force optimization requested")
            
            metrics = await self.scaler.collect_metrics()
            
            # 全最適化実行
            results = []
            
            # メモリ最適化
            memory_result = await self.scaler.memory_optimizer.optimize_memory_usage()
            results.append({"type": "memory", "result": memory_result})
            
            # 接続プール最適化
            pool_size = await self.scaler.connection_optimizer.optimize_pool_size(
                "main_pool", metrics.cpu_percent
            )
            results.append({"type": "connection_pool", "optimal_size": pool_size})
            
            self.stats["optimization_events"] += 1
            
            return {
                "status": "completed",
                "optimizations": results,
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Force optimization error: {e}")
            return {"status": "error", "message": str(e)}
    
    def get_performance_status(self) -> Dict[str, Any]:
        """パフォーマンス状況取得"""
        try:
            scaling_status = self.scaler.get_scaling_status()
            
            return {
                "monitoring_active": self.is_active,
                "monitoring_interval_seconds": self.monitoring_interval,
                "scaling_status": scaling_status,
                "statistics": self.stats,
                "system_resources": {
                    "cpu_count": cpu_count(),
                    "current_cpu_percent": psutil.cpu_percent(),
                    "current_memory_percent": psutil.virtual_memory().percent,
                    "available_memory_gb": psutil.virtual_memory().available / (1024**3)
                }
            }
            
        except Exception as e:
            logger.error(f"Performance status error: {e}")
            return {"error": str(e)}
    
    async def close(self):
        """システム終了"""
        await self.stop_monitoring()
        await self.scaler.close()
        logger.info("Performance Scaling System closed")


# グローバルインスタンス
performance_scaling_system = PerformanceScalingSystem()


if __name__ == "__main__":
    # 高速テスト実行
    async def rapid_test():
        """高速パフォーマンステスト"""
        print("🚀 Rapid Performance Scaling Test")
        
        system = PerformanceScalingSystem()
        await system.initialize()
        await system.start_monitoring()
        
        # 10秒間監視
        await asyncio.sleep(10)
        
        # 手動スケールアップテスト
        scale_result = await system.manual_scale(ScalingDirection.SCALE_UP)
        print(f"Scale up result: {json.dumps(scale_result, indent=2, default=str)}")
        
        # 強制最適化テスト
        opt_result = await system.force_optimization()
        print(f"Optimization result: {json.dumps(opt_result, indent=2, default=str)}")
        
        # ステータス確認
        status = system.get_performance_status()
        print(f"Performance status: {json.dumps(status, indent=2, default=str)}")
        
        await system.close()
        print("✅ Rapid test completed")
    
    asyncio.run(rapid_test())