#!/usr/bin/env python3
"""
Performance Dependencies - Phase 3 FastAPI 0.115.12
StreamingResponse, Caching, and Connection Pooling optimizations
"""

import asyncio
import json
import gzip
import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, AsyncIterator, Union, Callable
from io import BytesIO
import hashlib
import pickle
from contextlib import asynccontextmanager

from fastapi import Depends, Request, Response, BackgroundTasks
from fastapi.responses import StreamingResponse, JSONResponse
from starlette.types import Send
import redis.asyncio as redis
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.pool import QueuePool
import aiofiles
import orjson

from src.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class StreamingResponseDependency:
    """
    Advanced streaming response with compression and buffering
    """
    
    def __init__(self, 
                 buffer_size: int = 8192,
                 enable_compression: bool = True,
                 compression_level: int = 6):
        self.buffer_size = buffer_size
        self.enable_compression = enable_compression
        self.compression_level = compression_level
    
    async def create_streaming_response(self,
                                       data_generator: AsyncIterator[Any],
                                       media_type: str = "application/json",
                                       filename: Optional[str] = None) -> StreamingResponse:
        """
        Create optimized streaming response
        
        Args:
            data_generator: Async generator yielding data chunks
            media_type: Response media type
            filename: Optional filename for downloads
            
        Returns:
            StreamingResponse with optimizations
        """
        try:
            headers = {}
            
            # Set filename if provided
            if filename:
                headers["Content-Disposition"] = f'attachment; filename="{filename}"'
            
            # Create streaming content generator
            if self.enable_compression and "json" in media_type:
                content_generator = self._compressed_json_generator(data_generator)
                headers["Content-Encoding"] = "gzip"
                headers["Content-Type"] = media_type
            else:
                content_generator = self._buffered_generator(data_generator, media_type)
            
            return StreamingResponse(
                content=content_generator,
                media_type=media_type,
                headers=headers
            )
            
        except Exception as e:
            logger.error(f"Error creating streaming response: {e}")
            raise
    
    async def _compressed_json_generator(self, data_generator: AsyncIterator[Any]) -> AsyncIterator[bytes]:
        """Generate compressed JSON chunks"""
        compressor = gzip.GzipFile(fileobj=BytesIO(), mode='wb', compresslevel=self.compression_level)
        
        try:
            # Start JSON array
            chunk = b'['
            compressor.write(chunk)
            
            first_item = True
            buffer = BytesIO()
            
            async for item in data_generator:
                # Add comma separator (except for first item)
                if not first_item:
                    chunk = b','
                else:
                    first_item = False
                    chunk = b''
                
                # Serialize item to JSON
                if isinstance(item, (dict, list)):
                    json_data = orjson.dumps(item)
                else:
                    json_data = orjson.dumps({"data": item})
                
                chunk += json_data
                compressor.write(chunk)
                
                # Yield compressed data when buffer is full
                if compressor.fileobj.tell() >= self.buffer_size:
                    compressed_data = compressor.fileobj.getvalue()
                    compressor.fileobj.seek(0)
                    compressor.fileobj.truncate()
                    
                    if compressed_data:
                        yield compressed_data
            
            # Close JSON array
            compressor.write(b']')
            compressor.close()
            
            # Yield remaining compressed data
            compressed_data = compressor.fileobj.getvalue()
            if compressed_data:
                yield compressed_data
                
        except Exception as e:
            logger.error(f"Error in compressed JSON generator: {e}")
            raise
        finally:
            compressor.close()
    
    async def _buffered_generator(self, 
                                 data_generator: AsyncIterator[Any], 
                                 media_type: str) -> AsyncIterator[bytes]:
        """Generate buffered chunks"""
        buffer = BytesIO()
        
        try:
            async for item in data_generator:
                # Serialize based on media type
                if "json" in media_type:
                    if isinstance(item, (dict, list)):
                        data = orjson.dumps(item)
                    else:
                        data = orjson.dumps({"data": item})
                elif isinstance(item, str):
                    data = item.encode('utf-8')
                elif isinstance(item, bytes):
                    data = item
                else:
                    data = str(item).encode('utf-8')
                
                buffer.write(data)
                buffer.write(b'\n')  # Add newline separator
                
                # Yield when buffer is full
                if buffer.tell() >= self.buffer_size:
                    buffer_data = buffer.getvalue()
                    buffer.seek(0)
                    buffer.truncate()
                    yield buffer_data
            
            # Yield remaining data
            remaining_data = buffer.getvalue()
            if remaining_data:
                yield remaining_data
                
        except Exception as e:
            logger.error(f"Error in buffered generator: {e}")
            raise
        finally:
            buffer.close()


class CachingDependency:
    """
    Advanced multi-layer caching system
    """
    
    def __init__(self, 
                 redis_client: Optional[redis.Redis] = None,
                 default_ttl: int = 300,
                 max_memory_cache_size: int = 1000):
        self.redis_client = redis_client
        self.default_ttl = default_ttl
        self.max_memory_cache_size = max_memory_cache_size
        
        # In-memory cache (L1)
        self._memory_cache: Dict[str, Any] = {}
        self._memory_timestamps: Dict[str, float] = {}
        self._memory_access_times: Dict[str, float] = {}
    
    async def get(self, key: str, default: Any = None) -> Any:
        """
        Get cached value with multi-layer fallback
        
        Args:
            key: Cache key
            default: Default value if not found
            
        Returns:
            Cached value or default
        """
        try:
            # Check L1 cache (memory)
            memory_value = self._get_from_memory(key)
            if memory_value is not None:
                return memory_value
            
            # Check L2 cache (Redis)
            if self.redis_client:
                redis_value = await self._get_from_redis(key)
                if redis_value is not None:
                    # Store in L1 cache
                    self._set_to_memory(key, redis_value)
                    return redis_value
            
            return default
            
        except Exception as e:
            logger.error(f"Cache get error for key {key}: {e}")
            return default
    
    async def set(self, 
                 key: str, 
                 value: Any, 
                 ttl: Optional[int] = None,
                 compress: bool = True) -> bool:
        """
        Set cached value in multiple layers
        
        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds
            compress: Whether to compress large values
            
        Returns:
            True if successful
        """
        try:
            ttl = ttl or self.default_ttl
            
            # Store in L1 cache (memory)
            self._set_to_memory(key, value, ttl)
            
            # Store in L2 cache (Redis)
            if self.redis_client:
                await self._set_to_redis(key, value, ttl, compress)
            
            return True
            
        except Exception as e:
            logger.error(f"Cache set error for key {key}: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        """Delete cached value from all layers"""
        try:
            # Remove from L1 cache
            self._memory_cache.pop(key, None)
            self._memory_timestamps.pop(key, None)
            self._memory_access_times.pop(key, None)
            
            # Remove from L2 cache
            if self.redis_client:
                await self.redis_client.delete(key)
            
            return True
            
        except Exception as e:
            logger.error(f"Cache delete error for key {key}: {e}")
            return False
    
    async def exists(self, key: str) -> bool:
        """Check if key exists in cache"""
        try:
            # Check L1 cache
            if self._get_from_memory(key) is not None:
                return True
            
            # Check L2 cache
            if self.redis_client:
                return await self.redis_client.exists(key) > 0
            
            return False
            
        except Exception as e:
            logger.error(f"Cache exists error for key {key}: {e}")
            return False
    
    def _get_from_memory(self, key: str) -> Any:
        """Get value from memory cache"""
        if key not in self._memory_cache:
            return None
        
        # Check TTL
        import time
        if time.time() - self._memory_timestamps[key] > self.default_ttl:
            self._memory_cache.pop(key, None)
            self._memory_timestamps.pop(key, None)
            self._memory_access_times.pop(key, None)
            return None
        
        # Update access time
        self._memory_access_times[key] = time.time()
        return self._memory_cache[key]
    
    def _set_to_memory(self, key: str, value: Any, ttl: int = None):
        """Set value in memory cache"""
        import time
        
        # Evict if cache is full
        if len(self._memory_cache) >= self.max_memory_cache_size:
            self._evict_lru_memory()
        
        self._memory_cache[key] = value
        self._memory_timestamps[key] = time.time()
        self._memory_access_times[key] = time.time()
    
    def _evict_lru_memory(self):
        """Evict least recently used item from memory cache"""
        if not self._memory_access_times:
            return
        
        lru_key = min(self._memory_access_times.keys(), 
                     key=lambda k: self._memory_access_times[k])
        
        self._memory_cache.pop(lru_key, None)
        self._memory_timestamps.pop(lru_key, None)
        self._memory_access_times.pop(lru_key, None)
    
    async def _get_from_redis(self, key: str) -> Any:
        """Get value from Redis cache"""
        try:
            data = await self.redis_client.get(key)
            if data is None:
                return None
            
            # Try to deserialize
            try:
                return pickle.loads(data)
            except:
                # Fallback to JSON
                return orjson.loads(data)
                
        except Exception as e:
            logger.warning(f"Redis get error for key {key}: {e}")
            return None
    
    async def _set_to_redis(self, 
                           key: str, 
                           value: Any, 
                           ttl: int,
                           compress: bool = True):
        """Set value in Redis cache"""
        try:
            # Serialize value
            try:
                data = pickle.dumps(value)
            except:
                # Fallback to JSON
                data = orjson.dumps(value)
            
            # Compress large values
            if compress and len(data) > 1024:
                data = gzip.compress(data)
                key = f"gz:{key}"
            
            await self.redis_client.setex(key, ttl, data)
            
        except Exception as e:
            logger.warning(f"Redis set error for key {key}: {e}")


class ConnectionPoolDependency:
    """
    Advanced database connection pool management
    """
    
    def __init__(self):
        self.engines: Dict[str, Any] = {}
        self.session_factories: Dict[str, Any] = {}
        self.connection_stats: Dict[str, Dict[str, int]] = {}
    
    async def get_engine(self, 
                        database_url: str,
                        pool_size: int = 20,
                        max_overflow: int = 10,
                        pool_timeout: int = 30,
                        pool_recycle: int = 3600) -> Any:
        """
        Get or create database engine with connection pooling
        
        Args:
            database_url: Database connection URL
            pool_size: Number of connections to maintain
            max_overflow: Max connections beyond pool_size
            pool_timeout: Timeout for getting connection
            pool_recycle: Recycle connections after seconds
            
        Returns:
            SQLAlchemy async engine
        """
        engine_key = hashlib.md5(database_url.encode()).hexdigest()
        
        if engine_key not in self.engines:
            self.engines[engine_key] = create_async_engine(
                database_url,
                poolclass=QueuePool,
                pool_size=pool_size,
                max_overflow=max_overflow,
                pool_timeout=pool_timeout,
                pool_recycle=pool_recycle,
                pool_pre_ping=True,
                echo=False
            )
            
            self.connection_stats[engine_key] = {
                "created_connections": 0,
                "active_connections": 0,
                "pool_hits": 0,
                "pool_misses": 0
            }
            
            logger.info(f"Created database engine with pool_size={pool_size}")
        
        return self.engines[engine_key]
    
    async def get_session_factory(self, database_url: str):
        """Get session factory for database"""
        engine_key = hashlib.md5(database_url.encode()).hexdigest()
        
        if engine_key not in self.session_factories:
            engine = await self.get_engine(database_url)
            from sqlalchemy.ext.asyncio import async_sessionmaker
            
            self.session_factories[engine_key] = async_sessionmaker(
                engine,
                class_=AsyncSession,
                expire_on_commit=False,
                autoflush=True,
                autocommit=False
            )
        
        return self.session_factories[engine_key]
    
    async def get_connection_stats(self) -> Dict[str, Any]:
        """Get connection pool statistics"""
        stats = {}
        
        for engine_key, engine in self.engines.items():
            pool = engine.pool
            stats[engine_key] = {
                "pool_size": pool.size(),
                "checked_out": pool.checkedout(),
                "overflow": pool.overflow(),
                "checked_in": pool.checkedin(),
                "total_connections": pool.size() + pool.overflow(),
                **self.connection_stats.get(engine_key, {})
            }
        
        return stats
    
    async def close_all(self):
        """Close all database engines"""
        for engine in self.engines.values():
            await engine.dispose()
        
        self.engines.clear()
        self.session_factories.clear()
        self.connection_stats.clear()
        logger.info("All database connections closed")


# Global instances
streaming_response_dep = StreamingResponseDependency()
caching_dep = CachingDependency()
connection_pool_dep = ConnectionPoolDependency()


# FastAPI dependencies

async def get_streaming_response() -> StreamingResponseDependency:
    """Get streaming response dependency"""
    return streaming_response_dep


async def get_caching() -> CachingDependency:
    """Get caching dependency"""
    return caching_dep


async def get_connection_pool() -> ConnectionPoolDependency:
    """Get connection pool dependency"""
    return connection_pool_dep


def cached_response(ttl: int = 300, key_prefix: str = "api"):
    """
    Decorator for caching API responses
    
    Args:
        ttl: Cache TTL in seconds
        key_prefix: Cache key prefix
    """
    def decorator(func: Callable):
        async def wrapper(*args, **kwargs):
            # Generate cache key
            request = kwargs.get('request') or (args[0] if args and hasattr(args[0], 'url') else None)
            
            if request:
                cache_key = f"{key_prefix}:{request.url.path}:{hashlib.md5(str(kwargs).encode()).hexdigest()}"
                
                # Check cache
                cached_result = await caching_dep.get(cache_key)
                if cached_result is not None:
                    logger.debug(f"Cache hit for {cache_key}")
                    return cached_result
                
                # Execute function
                result = await func(*args, **kwargs)
                
                # Cache result
                await caching_dep.set(cache_key, result, ttl)
                logger.debug(f"Cached result for {cache_key}")
                
                return result
            else:
                return await func(*args, **kwargs)
        
        return wrapper
    return decorator


async def optimized_json_response(data: Any, 
                                 request: Request,
                                 enable_compression: bool = True) -> Response:
    """
    Create optimized JSON response
    
    Args:
        data: Data to serialize
        request: FastAPI request
        enable_compression: Enable gzip compression
        
    Returns:
        Optimized JSON response
    """
    try:
        # Serialize with orjson for better performance
        content = orjson.dumps(data)
        
        headers = {}
        
        # Apply compression for large responses
        if enable_compression and len(content) > 1024:
            accepts_gzip = "gzip" in request.headers.get("accept-encoding", "")
            if accepts_gzip:
                content = gzip.compress(content)
                headers["Content-Encoding"] = "gzip"
        
        # Add performance headers
        headers.update({
            "Content-Type": "application/json",
            "Cache-Control": "no-cache",
            "X-Response-Time": str(datetime.utcnow().timestamp())
        })
        
        return Response(
            content=content,
            media_type="application/json",
            headers=headers
        )
        
    except Exception as e:
        logger.error(f"Error creating optimized JSON response: {e}")
        return JSONResponse(content={"error": "Response serialization failed"})


# Background processing utilities

class BackgroundProcessor:
    """Advanced background task processor"""
    
    def __init__(self):
        self.task_queue: asyncio.Queue = asyncio.Queue()
        self.workers: List[asyncio.Task] = []
        self.running = False
    
    async def start(self, num_workers: int = 4):
        """Start background workers"""
        self.running = True
        
        for i in range(num_workers):
            worker = asyncio.create_task(self._worker(f"worker-{i}"))
            self.workers.append(worker)
        
        logger.info(f"Started {num_workers} background workers")
    
    async def stop(self):
        """Stop background workers"""
        self.running = False
        
        # Cancel all workers
        for worker in self.workers:
            worker.cancel()
        
        # Wait for workers to finish
        await asyncio.gather(*self.workers, return_exceptions=True)
        self.workers.clear()
        
        logger.info("Background workers stopped")
    
    async def add_task(self, task_func: Callable, *args, **kwargs):
        """Add task to background queue"""
        await self.task_queue.put((task_func, args, kwargs))
    
    async def _worker(self, worker_name: str):
        """Background worker process"""
        logger.info(f"Background worker {worker_name} started")
        
        try:
            while self.running:
                try:
                    # Get task from queue with timeout
                    task_func, args, kwargs = await asyncio.wait_for(
                        self.task_queue.get(), 
                        timeout=1.0
                    )
                    
                    # Execute task
                    if asyncio.iscoroutinefunction(task_func):
                        await task_func(*args, **kwargs)
                    else:
                        task_func(*args, **kwargs)
                    
                    self.task_queue.task_done()
                    
                except asyncio.TimeoutError:
                    continue
                except Exception as e:
                    logger.error(f"Background task error in {worker_name}: {e}")
                    
        except asyncio.CancelledError:
            logger.info(f"Background worker {worker_name} cancelled")
        finally:
            logger.info(f"Background worker {worker_name} stopped")


# Global background processor
background_processor = BackgroundProcessor()


async def get_background_processor() -> BackgroundProcessor:
    """Get background processor dependency"""
    return background_processor


# Performance monitoring utilities

class PerformanceMonitor:
    """Real-time performance monitoring"""
    
    def __init__(self):
        self.metrics: Dict[str, List[float]] = {}
        self.start_times: Dict[str, float] = {}
    
    def start_timer(self, name: str):
        """Start performance timer"""
        import time
        self.start_times[name] = time.time()
    
    def end_timer(self, name: str) -> float:
        """End performance timer and record metric"""
        import time
        
        if name not in self.start_times:
            return 0.0
        
        duration = time.time() - self.start_times[name]
        
        if name not in self.metrics:
            self.metrics[name] = []
        
        self.metrics[name].append(duration)
        
        # Keep only last 100 measurements
        if len(self.metrics[name]) > 100:
            self.metrics[name] = self.metrics[name][-100:]
        
        del self.start_times[name]
        return duration
    
    def get_stats(self, name: str) -> Dict[str, float]:
        """Get performance statistics"""
        if name not in self.metrics or not self.metrics[name]:
            return {}
        
        measurements = self.metrics[name]
        return {
            "count": len(measurements),
            "avg": sum(measurements) / len(measurements),
            "min": min(measurements),
            "max": max(measurements),
            "recent": measurements[-1] if measurements else 0.0
        }
    
    def get_all_stats(self) -> Dict[str, Dict[str, float]]:
        """Get all performance statistics"""
        return {name: self.get_stats(name) for name in self.metrics}


# Global performance monitor
performance_monitor = PerformanceMonitor()


async def get_performance_monitor() -> PerformanceMonitor:
    """Get performance monitor dependency"""
    return performance_monitor


# Initialization functions

async def init_performance_dependencies():
    """Initialize performance dependencies"""
    try:
        # Initialize Redis for caching
        if hasattr(settings, 'REDIS_URL') and settings.REDIS_URL:
            redis_client = redis.from_url(settings.REDIS_URL)
            await redis_client.ping()
            caching_dep.redis_client = redis_client
            logger.info("Redis connected for caching")
        
        # Start background processor
        await background_processor.start()
        
        logger.info("Performance dependencies initialized")
        
    except Exception as e:
        logger.error(f"Failed to initialize performance dependencies: {e}")
        raise


async def cleanup_performance_dependencies():
    """Cleanup performance dependencies"""
    try:
        # Stop background processor
        await background_processor.stop()
        
        # Close connection pools
        await connection_pool_dep.close_all()
        
        # Close Redis
        if caching_dep.redis_client:
            await caching_dep.redis_client.close()
        
        logger.info("Performance dependencies cleaned up")
        
    except Exception as e:
        logger.error(f"Error cleaning up performance dependencies: {e}")


if __name__ == "__main__":
    # Test performance dependencies
    import asyncio
    
    async def test_performance():
        """Test performance optimization features"""
        print("Testing performance dependencies...")
        
        # Test caching
        cache = CachingDependency()
        await cache.set("test_key", {"data": "test_value"})
        cached_value = await cache.get("test_key")
        print(f"Cache test: {cached_value}")
        
        # Test performance monitoring
        monitor = PerformanceMonitor()
        monitor.start_timer("test_operation")
        await asyncio.sleep(0.1)  # Simulate work
        duration = monitor.end_timer("test_operation")
        stats = monitor.get_stats("test_operation")
        print(f"Performance test: {duration:.3f}s, stats: {stats}")
        
        print("Performance test completed")
    
    asyncio.run(test_performance())