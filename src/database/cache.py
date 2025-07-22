# Microsoft 365 Management Tools - Redis Cache Integration
# High-performance caching for Microsoft Graph API and PowerShell data compatibility

import os
import json
import logging
from typing import Any, Optional, Dict, List, Union
from datetime import datetime, timedelta
import redis
from redis.exceptions import RedisError, ConnectionError
import pickle
import hashlib

# Configure logging
logger = logging.getLogger(__name__)

# Redis configuration
REDIS_CONFIG = {
    'host': os.getenv('REDIS_HOST', 'localhost'),
    'port': int(os.getenv('REDIS_PORT', '6379')),
    'db': int(os.getenv('REDIS_DB', '0')),
    'password': os.getenv('REDIS_PASSWORD', None),
    'socket_timeout': int(os.getenv('REDIS_SOCKET_TIMEOUT', '5')),
    'socket_connect_timeout': int(os.getenv('REDIS_CONNECT_TIMEOUT', '5')),
    'socket_keepalive': True,
    'socket_keepalive_options': {},
    'health_check_interval': int(os.getenv('REDIS_HEALTH_CHECK_INTERVAL', '30')),
    'decode_responses': False  # Keep binary for better performance
}

# Cache TTL settings (seconds)
CACHE_TTL_CONFIG = {
    'user_data': 300,           # 5 minutes - User information
    'license_data': 1800,       # 30 minutes - License information
    'usage_statistics': 600,    # 10 minutes - Usage statistics
    'security_data': 180,       # 3 minutes - MFA, signin logs
    'teams_data': 900,          # 15 minutes - Teams usage data
    'onedrive_data': 1200,      # 20 minutes - OneDrive storage data
    'exchange_data': 300,       # 5 minutes - Exchange mailbox data
    'report_metadata': 3600,    # 1 hour - Report generation metadata
    'powershell_compat': 120,   # 2 minutes - PowerShell compatibility data
    'default': 600              # 10 minutes - Default TTL
}

# Global Redis client
_redis_client: Optional[redis.Redis] = None

def get_redis_client() -> redis.Redis:
    """Get or create Redis client with connection pooling."""
    global _redis_client
    
    if _redis_client is None:
        try:
            _redis_client = redis.Redis(
                connection_pool=redis.ConnectionPool(
                    host=REDIS_CONFIG['host'],
                    port=REDIS_CONFIG['port'],
                    db=REDIS_CONFIG['db'],
                    password=REDIS_CONFIG['password'],
                    socket_timeout=REDIS_CONFIG['socket_timeout'],
                    socket_connect_timeout=REDIS_CONFIG['socket_connect_timeout'],
                    socket_keepalive=REDIS_CONFIG['socket_keepalive'],
                    socket_keepalive_options=REDIS_CONFIG['socket_keepalive_options'],
                    health_check_interval=REDIS_CONFIG['health_check_interval'],
                    decode_responses=REDIS_CONFIG['decode_responses'],
                    max_connections=50,
                    retry_on_timeout=True
                )
            )
            
            # Test connection
            _redis_client.ping()
            logger.info(f"Redis client connected: {REDIS_CONFIG['host']}:{REDIS_CONFIG['port']}")
            
        except (RedisError, ConnectionError) as e:
            logger.error(f"Redis connection failed: {e}")
            _redis_client = None
            raise
    
    return _redis_client

def create_cache_key(prefix: str, *args: str) -> str:
    """Create standardized cache key with namespace."""
    key_parts = [prefix] + list(args)
    key = ':'.join(str(part) for part in key_parts)
    
    # Hash long keys to avoid Redis key length limits
    if len(key) > 250:
        key_hash = hashlib.sha256(key.encode()).hexdigest()
        key = f"{prefix}:hashed:{key_hash}"
    
    return f"ms365_tools:{key}"

class CacheManager:
    """Enterprise cache manager for Microsoft 365 data."""
    
    def __init__(self):
        self.redis_client = None
        self._connect()
    
    def _connect(self):
        """Initialize Redis connection."""
        try:
            self.redis_client = get_redis_client()
        except (RedisError, ConnectionError) as e:
            logger.warning(f"Cache disabled due to Redis connection error: {e}")
            self.redis_client = None
    
    def _serialize_data(self, data: Any) -> bytes:
        """Serialize data for Redis storage with PowerShell compatibility."""
        if isinstance(data, (dict, list)):
            # JSON serialization for PowerShell compatibility
            return json.dumps(data, default=str, ensure_ascii=False).encode('utf-8')
        else:
            # Pickle for complex Python objects
            return pickle.dumps(data)
    
    def _deserialize_data(self, data: bytes) -> Any:
        """Deserialize data from Redis with fallback handling."""
        try:
            # Try JSON first (PowerShell compatible)
            return json.loads(data.decode('utf-8'))
        except (json.JSONDecodeError, UnicodeDecodeError):
            try:
                # Fallback to pickle
                return pickle.loads(data)
            except Exception as e:
                logger.error(f"Data deserialization failed: {e}")
                return None
    
    def get(self, key: str) -> Optional[Any]:
        """Get data from cache with error handling."""
        if not self.redis_client:
            return None
        
        try:
            cache_key = create_cache_key('data', key)
            data = self.redis_client.get(cache_key)
            
            if data is None:
                return None
            
            result = self._deserialize_data(data)
            logger.debug(f"Cache HIT: {key}")
            return result
            
        except (RedisError, Exception) as e:
            logger.error(f"Cache get error for key '{key}': {e}")
            return None
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None, 
            data_type: str = 'default') -> bool:
        """Set data in cache with TTL and type-based expiration."""
        if not self.redis_client:
            return False
        
        try:
            cache_key = create_cache_key('data', key)
            serialized_data = self._serialize_data(value)
            
            # Determine TTL
            if ttl is None:
                ttl = CACHE_TTL_CONFIG.get(data_type, CACHE_TTL_CONFIG['default'])
            
            result = self.redis_client.setex(cache_key, ttl, serialized_data)
            logger.debug(f"Cache SET: {key} (TTL: {ttl}s)")
            return bool(result)
            
        except (RedisError, Exception) as e:
            logger.error(f"Cache set error for key '{key}': {e}")
            return False
    
    def delete(self, key: str) -> bool:
        """Delete data from cache."""
        if not self.redis_client:
            return False
        
        try:
            cache_key = create_cache_key('data', key)
            result = self.redis_client.delete(cache_key)
            logger.debug(f"Cache DELETE: {key}")
            return bool(result)
            
        except (RedisError, Exception) as e:
            logger.error(f"Cache delete error for key '{key}': {e}")
            return False
    
    def exists(self, key: str) -> bool:
        """Check if key exists in cache."""
        if not self.redis_client:
            return False
        
        try:
            cache_key = create_cache_key('data', key)
            return bool(self.redis_client.exists(cache_key))
        except (RedisError, Exception) as e:
            logger.error(f"Cache exists check error for key '{key}': {e}")
            return False
    
    def get_ttl(self, key: str) -> int:
        """Get remaining TTL for a key."""
        if not self.redis_client:
            return -1
        
        try:
            cache_key = create_cache_key('data', key)
            return self.redis_client.ttl(cache_key)
        except (RedisError, Exception) as e:
            logger.error(f"Cache TTL check error for key '{key}': {e}")
            return -1
    
    def flush_pattern(self, pattern: str) -> int:
        """Delete all keys matching pattern."""
        if not self.redis_client:
            return 0
        
        try:
            search_pattern = create_cache_key('data', pattern)
            keys = self.redis_client.keys(search_pattern)
            if keys:
                result = self.redis_client.delete(*keys)
                logger.info(f"Cache FLUSH: {len(keys)} keys deleted for pattern '{pattern}'")
                return result
            return 0
        except (RedisError, Exception) as e:
            logger.error(f"Cache flush pattern error for '{pattern}': {e}")
            return 0
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics and health information."""
        if not self.redis_client:
            return {"status": "disconnected", "error": "Redis client not available"}
        
        try:
            info = self.redis_client.info()
            return {
                "status": "connected",
                "redis_version": info.get('redis_version'),
                "used_memory_human": info.get('used_memory_human'),
                "connected_clients": info.get('connected_clients'),
                "total_commands_processed": info.get('total_commands_processed'),
                "keyspace_hits": info.get('keyspace_hits', 0),
                "keyspace_misses": info.get('keyspace_misses', 0),
                "hit_rate": self._calculate_hit_rate(
                    info.get('keyspace_hits', 0), 
                    info.get('keyspace_misses', 0)
                )
            }
        except (RedisError, Exception) as e:
            return {"status": "error", "error": str(e)}
    
    def _calculate_hit_rate(self, hits: int, misses: int) -> float:
        """Calculate cache hit rate percentage."""
        total = hits + misses
        return (hits / total * 100) if total > 0 else 0.0

    def clear_all(self) -> bool:
        """Clear all Microsoft 365 tools cache data."""
        if not self.redis_client:
            return False
        
        try:
            pattern = "ms365_tools:*"
            keys = self.redis_client.keys(pattern)
            if keys:
                result = self.redis_client.delete(*keys)
                logger.info(f"Cache CLEAR ALL: {len(keys)} keys deleted")
                return bool(result)
            return True
        except (RedisError, Exception) as e:
            logger.error(f"Cache clear all error: {e}")
            return False

# Specialized cache functions for Microsoft 365 data types
def cache_user_data(user_id: str, data: Dict[str, Any], ttl: Optional[int] = None) -> bool:
    """Cache user data with optimized TTL."""
    cache_manager = CacheManager()
    key = f"user:{user_id}"
    return cache_manager.set(key, data, ttl, 'user_data')

def get_cached_user_data(user_id: str) -> Optional[Dict[str, Any]]:
    """Get cached user data."""
    cache_manager = CacheManager()
    key = f"user:{user_id}"
    return cache_manager.get(key)

def cache_license_data(tenant_id: str, data: List[Dict[str, Any]], ttl: Optional[int] = None) -> bool:
    """Cache license information."""
    cache_manager = CacheManager()
    key = f"licenses:{tenant_id}"
    return cache_manager.set(key, data, ttl, 'license_data')

def get_cached_license_data(tenant_id: str) -> Optional[List[Dict[str, Any]]]:
    """Get cached license data."""
    cache_manager = CacheManager()
    key = f"licenses:{tenant_id}"
    return cache_manager.get(key)

def cache_usage_statistics(service: str, date: str, data: Dict[str, Any], ttl: Optional[int] = None) -> bool:
    """Cache usage statistics data."""
    cache_manager = CacheManager()
    key = f"usage:{service}:{date}"
    return cache_manager.set(key, data, ttl, 'usage_statistics')

def get_cached_usage_statistics(service: str, date: str) -> Optional[Dict[str, Any]]:
    """Get cached usage statistics."""
    cache_manager = CacheManager()
    key = f"usage:{service}:{date}"
    return cache_manager.get(key)

def cache_powershell_compatible_data(report_type: str, data: List[Dict[str, Any]], 
                                   ttl: Optional[int] = None) -> bool:
    """Cache PowerShell-compatible data format."""
    cache_manager = CacheManager()
    key = f"powershell:{report_type}"
    return cache_manager.set(key, data, ttl, 'powershell_compat')

def get_cached_powershell_data(report_type: str) -> Optional[List[Dict[str, Any]]]:
    """Get cached PowerShell-compatible data."""
    cache_manager = CacheManager()
    key = f"powershell:{report_type}"
    return cache_manager.get(key)

# Health check function
async def cache_health_check() -> Dict[str, Any]:
    """Async health check for Redis cache."""
    try:
        cache_manager = CacheManager()
        stats = cache_manager.get_stats()
        
        return {
            "cache": {
                "status": "healthy" if stats.get("status") == "connected" else "unhealthy",
                "connected": stats.get("status") == "connected",
                "details": stats
            }
        }
    except Exception as e:
        return {
            "cache": {
                "status": "unhealthy", 
                "connected": False,
                "error": str(e)
            }
        }

# Initialize global cache manager
cache_manager = CacheManager()

if __name__ == "__main__":
    # Test Redis connection and functionality
    try:
        test_cache = CacheManager()
        
        # Test basic operations
        test_data = {"test": "data", "timestamp": datetime.utcnow().isoformat()}
        
        # Set test data
        if test_cache.set("test_key", test_data, 60):
            print("✅ Cache SET operation successful")
        else:
            print("❌ Cache SET operation failed")
        
        # Get test data
        retrieved_data = test_cache.get("test_key")
        if retrieved_data:
            print("✅ Cache GET operation successful")
            print(f"Retrieved data: {retrieved_data}")
        else:
            print("❌ Cache GET operation failed")
        
        # Get cache stats
        stats = test_cache.get_stats()
        print(f"📊 Cache stats: {stats}")
        
        print("✅ Redis cache integration test completed successfully")
        
    except Exception as e:
        print(f"❌ Redis cache test failed: {e}")