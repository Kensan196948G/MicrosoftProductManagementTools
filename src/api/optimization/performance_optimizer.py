"""
API最適化・パフォーマンス調整モジュール
FastAPI パフォーマンス最適化とキャッシュ機能強化
"""

import asyncio
import json
import time
import hashlib
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Callable, Union
from functools import wraps
import aioredis
import asyncpg
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
import psutil
import statistics

from ...core.config import settings
from ...core.logging_config import get_logger

logger = get_logger(__name__)

class PerformanceMetrics:
    """パフォーマンスメトリクス"""
    def __init__(self):
        self.request_times: List[float] = []
        self.cache_hits = 0
        self.cache_misses = 0
        self.api_calls = 0
        self.error_count = 0
        self.start_time = time.time()
        
    def add_request_time(self, duration: float):
        """リクエスト時間記録"""
        self.request_times.append(duration)
        # 直近1000件のみ保持
        if len(self.request_times) > 1000:
            self.request_times = self.request_times[-1000:]
    
    def cache_hit(self):
        """キャッシュヒット記録"""
        self.cache_hits += 1
    
    def cache_miss(self):
        """キャッシュミス記録"""
        self.cache_misses += 1
    
    def api_call(self):
        """API呼び出し記録"""
        self.api_calls += 1
    
    def error(self):
        """エラー記録"""
        self.error_count += 1
    
    def get_stats(self) -> Dict[str, Any]:
        """統計情報取得"""
        cache_total = self.cache_hits + self.cache_misses
        cache_hit_rate = (self.cache_hits / cache_total * 100) if cache_total > 0 else 0
        
        avg_response_time = statistics.mean(self.request_times) if self.request_times else 0
        p95_response_time = statistics.quantiles(self.request_times, n=20)[18] if len(self.request_times) >= 20 else 0
        
        return {
            "uptime_seconds": time.time() - self.start_time,
            "total_requests": len(self.request_times),
            "avg_response_time_ms": round(avg_response_time * 1000, 2),
            "p95_response_time_ms": round(p95_response_time * 1000, 2),
            "cache_hit_rate_percent": round(cache_hit_rate, 2),
            "cache_hits": self.cache_hits,
            "cache_misses": self.cache_misses,
            "api_calls": self.api_calls,
            "error_count": self.error_count,
            "error_rate_percent": round((self.error_count / len(self.request_times) * 100) if self.request_times else 0, 2)
        }

class CacheManager:
    """高度なキャッシュマネージャー"""
    
    def __init__(self):
        self.redis_client: Optional[aioredis.Redis] = None
        self.local_cache: Dict[str, Dict[str, Any]] = {}
        self.cache_config = {
            "user_data": {"ttl": 300, "max_size": 1000},  # 5分
            "license_data": {"ttl": 900, "max_size": 500},  # 15分
            "system_status": {"ttl": 60, "max_size": 100},  # 1分
            "reports": {"ttl": 3600, "max_size": 200}  # 1時間
        }
        
    async def initialize(self):
        """初期化"""
        try:
            if settings.redis_url:
                self.redis_client = await aioredis.from_url(
                    settings.redis_url,
                    encoding="utf-8",
                    decode_responses=True
                )
                logger.info("Redis cache initialized")
            else:
                logger.info("Using local cache only (Redis not configured)")
        except Exception as e:
            logger.error(f"Failed to initialize cache: {e}")
    
    def _get_cache_key(self, category: str, key: str) -> str:
        """キャッシュキー生成"""
        return f"cache:{category}:{key}"
    
    def _hash_key(self, data: Any) -> str:
        """データハッシュ化"""
        if isinstance(data, dict):
            data = json.dumps(data, sort_keys=True)
        return hashlib.md5(str(data).encode()).hexdigest()
    
    async def get(self, category: str, key: str) -> Optional[Any]:
        """キャッシュ取得"""
        cache_key = self._get_cache_key(category, key)
        
        try:
            # Redis から取得
            if self.redis_client:
                cached_data = await self.redis_client.get(cache_key)
                if cached_data:
                    performance_metrics.cache_hit()
                    return json.loads(cached_data)
            
            # ローカルキャッシュから取得
            if cache_key in self.local_cache:
                cache_entry = self.local_cache[cache_key]
                if cache_entry["expires_at"] > time.time():
                    performance_metrics.cache_hit()
                    return cache_entry["data"]
                else:
                    # 期限切れエントリを削除
                    del self.local_cache[cache_key]
            
            performance_metrics.cache_miss()
            return None
            
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            performance_metrics.cache_miss()
            return None
    
    async def set(self, category: str, key: str, data: Any, ttl: Optional[int] = None) -> bool:
        """キャッシュ設定"""
        cache_key = self._get_cache_key(category, key)
        config = self.cache_config.get(category, {"ttl": 300, "max_size": 100})
        effective_ttl = ttl or config["ttl"]
        
        try:
            serialized_data = json.dumps(data)
            
            # Redis に保存
            if self.redis_client:
                await self.redis_client.setex(cache_key, effective_ttl, serialized_data)
            
            # ローカルキャッシュに保存
            self.local_cache[cache_key] = {
                "data": data,
                "expires_at": time.time() + effective_ttl,
                "created_at": time.time()
            }
            
            # ローカルキャッシュサイズ制限
            await self._cleanup_local_cache(category, config["max_size"])
            
            return True
            
        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False
    
    async def delete(self, category: str, key: str) -> bool:
        """キャッシュ削除"""
        cache_key = self._get_cache_key(category, key)
        
        try:
            # Redis から削除
            if self.redis_client:
                await self.redis_client.delete(cache_key)
            
            # ローカルキャッシュから削除
            if cache_key in self.local_cache:
                del self.local_cache[cache_key]
            
            return True
            
        except Exception as e:
            logger.error(f"Cache delete error: {e}")
            return False
    
    async def invalidate_pattern(self, category: str, pattern: str = "*") -> int:
        """パターンマッチでキャッシュ無効化"""
        count = 0
        cache_pattern = self._get_cache_key(category, pattern)
        
        try:
            # Redis パターン削除
            if self.redis_client:
                keys = await self.redis_client.keys(cache_pattern)
                if keys:
                    count += await self.redis_client.delete(*keys)
            
            # ローカルキャッシュパターン削除
            keys_to_delete = [
                key for key in self.local_cache.keys()
                if key.startswith(f"cache:{category}:")
            ]
            for key in keys_to_delete:
                del self.local_cache[key]
                count += 1
            
            logger.info(f"Invalidated {count} cache entries for pattern: {cache_pattern}")
            return count
            
        except Exception as e:
            logger.error(f"Cache pattern invalidation error: {e}")
            return 0
    
    async def _cleanup_local_cache(self, category: str, max_size: int):
        """ローカルキャッシュクリーンアップ"""
        category_keys = [
            key for key in self.local_cache.keys()
            if key.startswith(f"cache:{category}:")
        ]
        
        if len(category_keys) > max_size:
            # 古いエントリから削除
            category_keys.sort(key=lambda k: self.local_cache[k]["created_at"])
            keys_to_delete = category_keys[:-max_size]
            
            for key in keys_to_delete:
                del self.local_cache[key]
    
    async def get_cache_stats(self) -> Dict[str, Any]:
        """キャッシュ統計"""
        stats = {
            "local_cache_size": len(self.local_cache),
            "categories": {}
        }
        
        for category in self.cache_config.keys():
            category_keys = [
                key for key in self.local_cache.keys()
                if key.startswith(f"cache:{category}:")
            ]
            stats["categories"][category] = {
                "local_entries": len(category_keys),
                "config": self.cache_config[category]
            }
        
        if self.redis_client:
            try:
                redis_info = await self.redis_client.info("memory")
                stats["redis"] = {
                    "used_memory": redis_info.get("used_memory"),
                    "used_memory_human": redis_info.get("used_memory_human")
                }
            except:
                stats["redis"] = {"status": "error"}
        
        return stats

def cache_result(category: str, key_func: Callable[[Any], str], ttl: Optional[int] = None):
    """キャッシュデコレータ"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # キャッシュキー生成
            cache_key = key_func(*args, **kwargs) if callable(key_func) else str(key_func)
            
            # キャッシュ確認
            cached_result = await cache_manager.get(category, cache_key)
            if cached_result is not None:
                return cached_result
            
            # 関数実行
            result = await func(*args, **kwargs)
            
            # 結果をキャッシュ
            await cache_manager.set(category, cache_key, result, ttl)
            
            return result
        return wrapper
    return decorator

class ConnectionPoolManager:
    """データベース接続プール最適化"""
    
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None
        self.pool_stats = {
            "created_connections": 0,
            "active_connections": 0,
            "idle_connections": 0,
            "total_queries": 0,
            "avg_query_time": 0.0
        }
        
    async def initialize(self):
        """接続プール初期化"""
        try:
            self.pool = await asyncpg.create_pool(
                settings.database_url,
                min_size=5,
                max_size=20,
                max_queries=50000,
                max_inactive_connection_lifetime=300,
                command_timeout=30
            )
            logger.info("Database connection pool initialized")
        except Exception as e:
            logger.error(f"Failed to initialize connection pool: {e}")
    
    async def execute_optimized_query(self, query: str, *args) -> List[Dict[str, Any]]:
        """最適化クエリ実行"""
        start_time = time.time()
        
        try:
            async with self.pool.acquire() as connection:
                result = await connection.fetch(query, *args)
                
                # 統計更新
                execution_time = time.time() - start_time
                self.pool_stats["total_queries"] += 1
                self.pool_stats["avg_query_time"] = (
                    (self.pool_stats["avg_query_time"] * (self.pool_stats["total_queries"] - 1) + execution_time) 
                    / self.pool_stats["total_queries"]
                )
                
                return [dict(row) for row in result]
                
        except Exception as e:
            logger.error(f"Database query error: {e}")
            raise
    
    def get_pool_stats(self) -> Dict[str, Any]:
        """プール統計取得"""
        if self.pool:
            self.pool_stats.update({
                "active_connections": len([c for c in self.pool._holders if not c._in_use]),
                "idle_connections": len([c for c in self.pool._holders if c._in_use]),
                "pool_size": self.pool.get_size(),
                "pool_min_size": self.pool.get_min_size(),
                "pool_max_size": self.pool.get_max_size()
            })
        
        return self.pool_stats

class RateLimiter:
    """レート制限機能"""
    
    def __init__(self):
        self.requests: Dict[str, List[float]] = {}
        self.limits = {
            "default": {"requests": 100, "window": 60},  # 100req/min
            "heavy": {"requests": 10, "window": 60},     # 10req/min
            "auth": {"requests": 5, "window": 300}       # 5req/5min
        }
    
    async def check_rate_limit(self, client_id: str, endpoint_type: str = "default") -> bool:
        """レート制限チェック"""
        current_time = time.time()
        limit_config = self.limits.get(endpoint_type, self.limits["default"])
        
        # クライアントのリクエスト履歴取得
        if client_id not in self.requests:
            self.requests[client_id] = []
        
        client_requests = self.requests[client_id]
        
        # 期限切れリクエスト削除
        window_start = current_time - limit_config["window"]
        client_requests[:] = [req_time for req_time in client_requests if req_time > window_start]
        
        # リクエスト数チェック
        if len(client_requests) >= limit_config["requests"]:
            return False
        
        # 現在のリクエスト記録
        client_requests.append(current_time)
        return True
    
    def get_rate_limit_info(self, client_id: str, endpoint_type: str = "default") -> Dict[str, Any]:
        """レート制限情報取得"""
        current_time = time.time()
        limit_config = self.limits.get(endpoint_type, self.limits["default"])
        
        if client_id not in self.requests:
            return {
                "remaining": limit_config["requests"],
                "reset_time": current_time + limit_config["window"],
                "limit": limit_config["requests"]
            }
        
        client_requests = self.requests[client_id]
        window_start = current_time - limit_config["window"]
        recent_requests = [req_time for req_time in client_requests if req_time > window_start]
        
        return {
            "remaining": max(0, limit_config["requests"] - len(recent_requests)),
            "reset_time": max(recent_requests) + limit_config["window"] if recent_requests else current_time,
            "limit": limit_config["requests"]
        }

# パフォーマンス監視ミドルウェア
async def performance_middleware(request: Request, call_next):
    """パフォーマンス監視ミドルウェア"""
    start_time = time.time()
    
    try:
        # リクエスト処理
        response = await call_next(request)
        
        # 実行時間記録
        execution_time = time.time() - start_time
        performance_metrics.add_request_time(execution_time)
        performance_metrics.api_call()
        
        # レスポンスヘッダーに統計追加
        response.headers["X-Response-Time"] = f"{execution_time:.3f}"
        response.headers["X-Cache-Status"] = "miss"  # デフォルト
        
        return response
        
    except Exception as e:
        performance_metrics.error()
        execution_time = time.time() - start_time
        performance_metrics.add_request_time(execution_time)
        raise

# システム監視関数
async def get_system_performance() -> Dict[str, Any]:
    """システムパフォーマンス取得"""
    try:
        # CPU・メモリ使用率
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        # ネットワーク統計
        network = psutil.net_io_counters()
        
        return {
            "cpu": {
                "usage_percent": cpu_percent,
                "count": psutil.cpu_count()
            },
            "memory": {
                "total_gb": round(memory.total / (1024**3), 2),
                "used_gb": round(memory.used / (1024**3), 2),
                "usage_percent": memory.percent,
                "available_gb": round(memory.available / (1024**3), 2)
            },
            "disk": {
                "total_gb": round(disk.total / (1024**3), 2),
                "used_gb": round(disk.used / (1024**3), 2),
                "usage_percent": round(disk.used / disk.total * 100, 2),
                "free_gb": round(disk.free / (1024**3), 2)
            },
            "network": {
                "bytes_sent": network.bytes_sent,
                "bytes_recv": network.bytes_recv,
                "packets_sent": network.packets_sent,
                "packets_recv": network.packets_recv
            }
        }
    except Exception as e:
        logger.error(f"Failed to get system performance: {e}")
        return {"error": str(e)}

# グローバルインスタンス
performance_metrics = PerformanceMetrics()
cache_manager = CacheManager()
connection_pool_manager = ConnectionPoolManager()
rate_limiter = RateLimiter()

# 初期化関数
async def initialize_performance_optimization():
    """パフォーマンス最適化初期化"""
    await cache_manager.initialize()
    await connection_pool_manager.initialize()
    logger.info("Performance optimization initialized")

# 統計取得関数
async def get_performance_stats() -> Dict[str, Any]:
    """パフォーマンス統計取得"""
    return {
        "metrics": performance_metrics.get_stats(),
        "cache": await cache_manager.get_cache_stats(),
        "database": connection_pool_manager.get_pool_stats(),
        "system": await get_system_performance(),
        "timestamp": datetime.utcnow().isoformat()
    }