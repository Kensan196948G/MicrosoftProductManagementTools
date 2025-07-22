"""
Microsoft 365管理ツール パフォーマンス最適化
=========================================

FastAPI パフォーマンス最適化モジュール
- レスポンス最適化・キャッシング戦略
- 非同期処理・バッチ処理最適化  
- データベースクエリ最適化
- API レート制限・パフォーマンス監視
"""

import asyncio
import logging
import time
import functools
from typing import Dict, Any, Optional, List, Callable
from dataclasses import dataclass
from datetime import datetime, timedelta
import json
import hashlib

logger = logging.getLogger(__name__)


@dataclass
class PerformanceMetrics:
    """パフォーマンスメトリクス"""
    endpoint: str
    execution_time: float
    memory_usage: float
    request_count: int
    error_count: int
    timestamp: datetime


@dataclass
class CacheItem:
    """キャッシュアイテム"""
    data: Any
    timestamp: datetime
    expiry: datetime
    access_count: int = 0


class PerformanceOptimizer:
    """パフォーマンス最適化クラス"""
    
    def __init__(self):
        self.metrics: Dict[str, List[PerformanceMetrics]] = {}
        self.cache: Dict[str, CacheItem] = {}
        self.rate_limits: Dict[str, List[datetime]] = {}
        
        # 設定
        self.cache_ttl = 300  # 5分
        self.max_cache_size = 1000
        self.rate_limit_window = 60  # 1分
        self.rate_limit_max = 100  # 1分間に100リクエスト
    
    def performance_monitor(self, endpoint: str):
        """パフォーマンス監視デコレータ"""
        def decorator(func: Callable):
            @functools.wraps(func)
            async def wrapper(*args, **kwargs):
                start_time = time.time()
                start_memory = self._get_memory_usage()
                
                try:
                    result = await func(*args, **kwargs)
                    error_count = 0
                except Exception as e:
                    error_count = 1
                    raise e
                finally:
                    execution_time = time.time() - start_time
                    end_memory = self._get_memory_usage()
                    memory_usage = end_memory - start_memory
                    
                    # メトリクス記録
                    await self._record_metrics(
                        endpoint=endpoint,
                        execution_time=execution_time,
                        memory_usage=memory_usage,
                        error_count=error_count
                    )
                
                return result
            return wrapper
        return decorator
    
    def cache_response(self, ttl: Optional[int] = None, key_generator: Optional[Callable] = None):
        """レスポンスキャッシュデコレータ"""
        def decorator(func: Callable):
            @functools.wraps(func)
            async def wrapper(*args, **kwargs):
                # キャッシュキー生成
                cache_key = key_generator(*args, **kwargs) if key_generator else self._generate_cache_key(func.__name__, args, kwargs)
                
                # キャッシュ確認
                cached_item = self._get_cached_item(cache_key)
                if cached_item and not self._is_cache_expired(cached_item):
                    cached_item.access_count += 1
                    return cached_item.data
                
                # 関数実行
                result = await func(*args, **kwargs)
                
                # キャッシュ保存
                expiry_time = datetime.utcnow() + timedelta(seconds=ttl or self.cache_ttl)
                await self._set_cache(cache_key, result, expiry_time)
                
                return result
            return wrapper
        return decorator
    
    def rate_limit(self, max_requests: Optional[int] = None, window: Optional[int] = None):
        """レート制限デコレータ"""
        def decorator(func: Callable):
            @functools.wraps(func)
            async def wrapper(*args, **kwargs):
                client_id = self._get_client_id(args, kwargs)
                max_req = max_requests or self.rate_limit_max
                time_window = window or self.rate_limit_window
                
                # レート制限チェック
                if not await self._check_rate_limit(client_id, max_req, time_window):
                    raise Exception(f"レート制限超過: {max_req}リクエスト/{time_window}秒")
                
                return await func(*args, **kwargs)
            return wrapper
        return decorator
    
    async def _record_metrics(self, endpoint: str, execution_time: float, memory_usage: float, error_count: int):
        """メトリクス記録"""
        if endpoint not in self.metrics:
            self.metrics[endpoint] = []
        
        metric = PerformanceMetrics(
            endpoint=endpoint,
            execution_time=execution_time,
            memory_usage=memory_usage,
            request_count=1,
            error_count=error_count,
            timestamp=datetime.utcnow()
        )
        
        self.metrics[endpoint].append(metric)
        
        # 古いメトリクスのクリーンアップ（24時間以上古い）
        cutoff_time = datetime.utcnow() - timedelta(days=1)
        self.metrics[endpoint] = [m for m in self.metrics[endpoint] if m.timestamp > cutoff_time]
    
    def _generate_cache_key(self, func_name: str, args: tuple, kwargs: dict) -> str:
        """キャッシュキー生成"""
        # 関数名と引数からハッシュ生成
        key_data = {
            'function': func_name,
            'args': str(args),
            'kwargs': sorted(kwargs.items()) if kwargs else []
        }
        key_string = json.dumps(key_data, sort_keys=True, default=str)
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def _get_cached_item(self, key: str) -> Optional[CacheItem]:
        """キャッシュアイテム取得"""
        return self.cache.get(key)
    
    def _is_cache_expired(self, cached_item: CacheItem) -> bool:
        """キャッシュ期限確認"""
        return datetime.utcnow() > cached_item.expiry
    
    async def _set_cache(self, key: str, data: Any, expiry: datetime):
        """キャッシュ設定"""
        # キャッシュサイズ制限
        if len(self.cache) >= self.max_cache_size:
            await self._cleanup_cache()
        
        self.cache[key] = CacheItem(
            data=data,
            timestamp=datetime.utcnow(),
            expiry=expiry
        )
    
    async def _cleanup_cache(self):
        """キャッシュクリーンアップ"""
        current_time = datetime.utcnow()
        
        # 期限切れアイテム削除
        expired_keys = [
            key for key, item in self.cache.items() 
            if current_time > item.expiry
        ]
        
        for key in expired_keys:
            del self.cache[key]
        
        # まだサイズ超過の場合、最も古いアイテムを削除
        if len(self.cache) >= self.max_cache_size:
            oldest_items = sorted(
                self.cache.items(), 
                key=lambda x: x[1].timestamp
            )
            
            # 半分のアイテムを削除
            items_to_remove = len(oldest_items) // 2
            for key, _ in oldest_items[:items_to_remove]:
                del self.cache[key]
    
    def _get_client_id(self, args: tuple, kwargs: dict) -> str:
        """クライアントID取得（レート制限用）"""
        # リクエストからクライアントIDを取得（通常はIPアドレスやユーザーID）
        if 'request' in kwargs:
            request = kwargs['request']
            if hasattr(request, 'client') and hasattr(request.client, 'host'):
                return request.client.host
        
        return "default_client"
    
    async def _check_rate_limit(self, client_id: str, max_requests: int, time_window: int) -> bool:
        """レート制限チェック"""
        current_time = datetime.utcnow()
        window_start = current_time - timedelta(seconds=time_window)
        
        if client_id not in self.rate_limits:
            self.rate_limits[client_id] = []
        
        # 時間窓内のリクエスト数をカウント
        recent_requests = [
            req_time for req_time in self.rate_limits[client_id]
            if req_time > window_start
        ]
        
        if len(recent_requests) >= max_requests:
            return False
        
        # リクエスト記録
        self.rate_limits[client_id] = recent_requests + [current_time]
        return True
    
    def _get_memory_usage(self) -> float:
        """メモリ使用量取得（MB）"""
        try:
            import psutil
            import os
            process = psutil.Process(os.getpid())
            return process.memory_info().rss / 1024 / 1024  # MB
        except ImportError:
            return 0.0
    
    async def get_performance_report(self, hours: int = 24) -> Dict[str, Any]:
        """パフォーマンスレポート取得"""
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        report = {}
        
        for endpoint, metrics in self.metrics.items():
            recent_metrics = [m for m in metrics if m.timestamp > cutoff_time]
            
            if not recent_metrics:
                continue
            
            total_requests = len(recent_metrics)
            total_errors = sum(m.error_count for m in recent_metrics)
            avg_response_time = sum(m.execution_time for m in recent_metrics) / total_requests
            max_response_time = max(m.execution_time for m in recent_metrics)
            avg_memory = sum(m.memory_usage for m in recent_metrics) / total_requests
            
            report[endpoint] = {
                'total_requests': total_requests,
                'error_rate': total_errors / total_requests if total_requests > 0 else 0,
                'avg_response_time_ms': avg_response_time * 1000,
                'max_response_time_ms': max_response_time * 1000,
                'avg_memory_usage_mb': avg_memory,
                'requests_per_hour': total_requests / (hours if hours <= 24 else 24)
            }
        
        return report
    
    async def get_cache_statistics(self) -> Dict[str, Any]:
        """キャッシュ統計情報"""
        current_time = datetime.utcnow()
        
        total_items = len(self.cache)
        expired_items = sum(
            1 for item in self.cache.values() 
            if current_time > item.expiry
        )
        
        if total_items > 0:
            avg_access_count = sum(item.access_count for item in self.cache.values()) / total_items
            hit_rate = sum(1 for item in self.cache.values() if item.access_count > 0) / total_items
        else:
            avg_access_count = 0
            hit_rate = 0
        
        return {
            'total_cached_items': total_items,
            'expired_items': expired_items,
            'cache_hit_rate': hit_rate,
            'avg_access_count': avg_access_count,
            'cache_size_mb': self._estimate_cache_size()
        }
    
    def _estimate_cache_size(self) -> float:
        """キャッシュサイズ推定（MB）"""
        try:
            import sys
            total_size = 0
            for item in self.cache.values():
                total_size += sys.getsizeof(item.data)
            return total_size / 1024 / 1024  # MB
        except:
            return 0.0
    
    async def optimize_database_queries(self, session, query_optimizer_config: Optional[Dict] = None):
        """データベースクエリ最適化"""
        try:
            # 実行プラン分析
            if query_optimizer_config:
                # インデックス最適化
                await self._optimize_indexes(session, query_optimizer_config.get('indexes', []))
                
                # クエリ最適化
                await self._analyze_slow_queries(session, query_optimizer_config.get('slow_query_threshold', 1000))
        
        except Exception as e:
            logger.error(f"データベース最適化エラー: {e}")
    
    async def _optimize_indexes(self, session, index_config: List[Dict]):
        """インデックス最適化"""
        for index in index_config:
            try:
                table_name = index.get('table')
                columns = index.get('columns', [])
                index_name = f"idx_{table_name}_{'_'.join(columns)}"
                
                # インデックス存在確認
                check_query = f"""
                SELECT indexname FROM pg_indexes 
                WHERE tablename = '{table_name}' AND indexname = '{index_name}'
                """
                result = await session.execute(check_query)
                
                if not result.fetchone():
                    # インデックス作成
                    create_query = f"""
                    CREATE INDEX CONCURRENTLY {index_name} 
                    ON {table_name} ({', '.join(columns)})
                    """
                    await session.execute(create_query)
                    logger.info(f"インデックス作成完了: {index_name}")
            
            except Exception as e:
                logger.error(f"インデックス最適化エラー: {index}: {e}")
    
    async def _analyze_slow_queries(self, session, threshold_ms: int):
        """スロークエリ分析"""
        try:
            # PostgreSQL統計情報取得
            slow_query_sql = f"""
            SELECT query, mean_time, calls, total_time
            FROM pg_stat_statements 
            WHERE mean_time > {threshold_ms}
            ORDER BY mean_time DESC
            LIMIT 10
            """
            
            result = await session.execute(slow_query_sql)
            slow_queries = result.fetchall()
            
            for query_info in slow_queries:
                logger.warning(f"スロークエリ検出: 平均実行時間 {query_info[1]:.2f}ms - {query_info[0][:100]}...")
        
        except Exception as e:
            logger.error(f"スロークエリ分析エラー: {e}")


# グローバルパフォーマンス最適化インスタンス
performance_optimizer = PerformanceOptimizer()


class BatchProcessor:
    """バッチ処理最適化"""
    
    @staticmethod
    async def process_in_batches(items: List[Any], batch_size: int, processor_func: Callable, max_concurrent: int = 5):
        """バッチ処理実行"""
        results = []
        semaphore = asyncio.Semaphore(max_concurrent)
        
        async def process_batch(batch):
            async with semaphore:
                return await processor_func(batch)
        
        # バッチ作成
        batches = [items[i:i + batch_size] for i in range(0, len(items), batch_size)]
        
        # 並列バッチ処理
        batch_results = await asyncio.gather(*[process_batch(batch) for batch in batches])
        
        # 結果統合
        for batch_result in batch_results:
            if isinstance(batch_result, list):
                results.extend(batch_result)
            else:
                results.append(batch_result)
        
        return results


# パフォーマンス最適化ヘルパー関数
async def optimize_api_response(data: Any, compression: bool = True) -> Any:
    """APIレスポンス最適化"""
    if compression and isinstance(data, (dict, list)):
        # 大きなデータセットの場合、ページネーション推奨
        if isinstance(data, list) and len(data) > 100:
            logger.warning(f"大きなデータセット検出: {len(data)}件。ページネーション実装を推奨")
    
    return data


def get_performance_middleware():
    """FastAPIパフォーマンス監視ミドルウェア"""
    async def performance_middleware(request, call_next):
        start_time = time.time()
        
        response = await call_next(request)
        
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        
        # パフォーマンスログ
        if process_time > 1.0:  # 1秒以上
            logger.warning(f"スローレスポンス: {request.url.path} - {process_time:.3f}秒")
        
        return response
    
    return performance_middleware