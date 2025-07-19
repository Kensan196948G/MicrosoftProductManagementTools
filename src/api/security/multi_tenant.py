#!/usr/bin/env python3
"""
Multi-tenant Manager - Phase 3 Advanced Integration
Enterprise-grade multi-tenant security and isolation
"""

import asyncio
import logging
from typing import Dict, List, Optional, Any, Set
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
import uuid
import hashlib

from fastapi import HTTPException, status
import redis.asyncio as redis
from cryptography.fernet import Fernet
import jwt

from src.core.config import get_settings

logger = logging.getLogger(__name__)


class TenantStatus(str, Enum):
    """Tenant status enumeration"""
    ACTIVE = "active"
    SUSPENDED = "suspended"
    TRIAL = "trial"
    EXPIRED = "expired"
    DELETED = "deleted"


class TenantTier(str, Enum):
    """Tenant service tier"""
    FREE = "free"
    BASIC = "basic" 
    PREMIUM = "premium"
    ENTERPRISE = "enterprise"


@dataclass
class TenantLimits:
    """Tenant resource limits"""
    max_users: int = 100
    max_groups: int = 50
    max_api_requests_per_hour: int = 1000
    max_storage_gb: int = 10
    max_webhooks: int = 5
    max_concurrent_connections: int = 50
    features: Set[str] = field(default_factory=set)


@dataclass
class TenantUsage:
    """Current tenant usage statistics"""
    users_count: int = 0
    groups_count: int = 0
    api_requests_this_hour: int = 0
    storage_used_gb: float = 0.0
    webhooks_count: int = 0
    concurrent_connections: int = 0
    last_updated: datetime = field(default_factory=datetime.utcnow)


@dataclass
class Tenant:
    """Tenant configuration"""
    id: str
    name: str
    domain: str
    status: TenantStatus = TenantStatus.ACTIVE
    tier: TenantTier = TenantTier.FREE
    created_at: datetime = field(default_factory=datetime.utcnow)
    expires_at: Optional[datetime] = None
    limits: TenantLimits = field(default_factory=TenantLimits)
    usage: TenantUsage = field(default_factory=TenantUsage)
    settings: Dict[str, Any] = field(default_factory=dict)
    encryption_key: Optional[str] = None
    webhook_secret: Optional[str] = None
    
    def __post_init__(self):
        if not self.encryption_key:
            self.encryption_key = Fernet.generate_key().decode()
        if not self.webhook_secret:
            self.webhook_secret = self._generate_webhook_secret()
    
    def _generate_webhook_secret(self) -> str:
        """Generate webhook secret for tenant"""
        data = f"{self.id}:{self.name}:{datetime.utcnow().isoformat()}"
        return hashlib.sha256(data.encode()).hexdigest()
    
    def is_active(self) -> bool:
        """Check if tenant is active"""
        if self.status != TenantStatus.ACTIVE:
            return False
        
        if self.expires_at and datetime.utcnow() > self.expires_at:
            return False
        
        return True
    
    def is_within_limits(self, resource: str, additional: int = 1) -> bool:
        """Check if tenant is within resource limits"""
        current_usage = getattr(self.usage, f"{resource}_count", 0)
        limit = getattr(self.limits, f"max_{resource}", 0)
        return (current_usage + additional) <= limit
    
    def has_feature(self, feature: str) -> bool:
        """Check if tenant has access to specific feature"""
        return feature in self.limits.features
    
    def get_fernet_key(self) -> Fernet:
        """Get Fernet encryption instance for tenant"""
        return Fernet(self.encryption_key.encode())


class MultiTenantManager:
    """
    Multi-tenant Manager for enterprise-grade tenant isolation
    
    Features:
    - Tenant registration and management
    - Resource limits and usage tracking
    - Data encryption per tenant
    - API rate limiting
    - Feature toggles
    - Usage analytics
    """
    
    def __init__(self, 
                 redis_url: Optional[str] = None,
                 enable_caching: bool = True,
                 cache_ttl: int = 300):
        """
        Initialize Multi-tenant Manager
        
        Args:
            redis_url: Redis connection URL for caching
            enable_caching: Enable tenant data caching
            cache_ttl: Cache TTL in seconds
        """
        self.redis_url = redis_url
        self.enable_caching = enable_caching
        self.cache_ttl = cache_ttl
        
        # In-memory storage (replace with database in production)
        self.tenants: Dict[str, Tenant] = {}
        self.domain_to_tenant: Dict[str, str] = {}
        
        # Redis client for caching
        self.redis_client: Optional[redis.Redis] = None
        
        # Default tier configurations
        self.tier_limits = {
            TenantTier.FREE: TenantLimits(
                max_users=10,
                max_groups=5,
                max_api_requests_per_hour=100,
                max_storage_gb=1,
                max_webhooks=1,
                max_concurrent_connections=10,
                features={"basic_reporting"}
            ),
            TenantTier.BASIC: TenantLimits(
                max_users=100,
                max_groups=50,
                max_api_requests_per_hour=1000,
                max_storage_gb=10,
                max_webhooks=5,
                max_concurrent_connections=50,
                features={"basic_reporting", "webhooks", "api_access"}
            ),
            TenantTier.PREMIUM: TenantLimits(
                max_users=1000,
                max_groups=500,
                max_api_requests_per_hour=10000,
                max_storage_gb=100,
                max_webhooks=20,
                max_concurrent_connections=200,
                features={"basic_reporting", "webhooks", "api_access", "advanced_analytics", "sso"}
            ),
            TenantTier.ENTERPRISE: TenantLimits(
                max_users=10000,
                max_groups=5000,
                max_api_requests_per_hour=100000,
                max_storage_gb=1000,
                max_webhooks=100,
                max_concurrent_connections=1000,
                features={"basic_reporting", "webhooks", "api_access", "advanced_analytics", "sso", "custom_integration", "priority_support"}
            )
        }
        
        # Usage tracking
        self.usage_cache: Dict[str, Dict[str, int]] = {}
        
        logger.info("MultiTenantManager initialized")
    
    async def initialize(self):
        """Initialize multi-tenant manager"""
        if self.enable_caching and self.redis_url:
            try:
                self.redis_client = redis.from_url(self.redis_url)
                await self.redis_client.ping()
                logger.info("Redis connected for multi-tenant caching")
            except Exception as e:
                logger.warning(f"Failed to connect to Redis: {e}")
                self.enable_caching = False
        
        # Load tenants from storage
        await self._load_tenants()
        
        logger.info("MultiTenantManager initialized successfully")
    
    async def create_tenant(self,
                           name: str,
                           domain: str,
                           tier: TenantTier = TenantTier.FREE,
                           admin_email: Optional[str] = None,
                           settings: Optional[Dict[str, Any]] = None) -> Tenant:
        """
        Create new tenant
        
        Args:
            name: Tenant name
            domain: Tenant domain
            tier: Service tier
            admin_email: Administrator email
            settings: Additional settings
            
        Returns:
            Created tenant
            
        Raises:
            HTTPException: If domain already exists
        """
        try:
            # Validate domain uniqueness
            if domain in self.domain_to_tenant:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Domain {domain} already exists"
                )
            
            # Generate tenant ID
            tenant_id = str(uuid.uuid4())
            
            # Get limits for tier
            limits = self.tier_limits.get(tier, self.tier_limits[TenantTier.FREE])
            
            # Create tenant
            tenant = Tenant(
                id=tenant_id,
                name=name,
                domain=domain,
                tier=tier,
                limits=limits,
                settings=settings or {}
            )
            
            # Set expiration for trial tenants
            if tier == TenantTier.FREE:
                tenant.expires_at = datetime.utcnow() + timedelta(days=30)
            
            # Store tenant
            self.tenants[tenant_id] = tenant
            self.domain_to_tenant[domain] = tenant_id
            
            # Save to persistent storage
            await self._save_tenant(tenant)
            
            # Cache tenant data
            if self.enable_caching:
                await self._cache_tenant(tenant)
            
            logger.info(f"Created tenant {tenant_id} ({name}) with domain {domain}")
            return tenant
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error creating tenant: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create tenant"
            )
    
    async def get_tenant(self, tenant_id: str) -> Optional[Tenant]:
        """
        Get tenant by ID
        
        Args:
            tenant_id: Tenant identifier
            
        Returns:
            Tenant or None if not found
        """
        try:
            # Check cache first
            if self.enable_caching:
                cached_tenant = await self._get_cached_tenant(tenant_id)
                if cached_tenant:
                    return cached_tenant
            
            # Check in-memory storage
            tenant = self.tenants.get(tenant_id)
            if tenant:
                # Cache for future requests
                if self.enable_caching:
                    await self._cache_tenant(tenant)
                return tenant
            
            # Load from persistent storage
            tenant = await self._load_tenant(tenant_id)
            if tenant:
                self.tenants[tenant_id] = tenant
                self.domain_to_tenant[tenant.domain] = tenant_id
                
                if self.enable_caching:
                    await self._cache_tenant(tenant)
            
            return tenant
            
        except Exception as e:
            logger.error(f"Error getting tenant {tenant_id}: {e}")
            return None
    
    async def get_tenant_by_domain(self, domain: str) -> Optional[Tenant]:
        """
        Get tenant by domain
        
        Args:
            domain: Tenant domain
            
        Returns:
            Tenant or None if not found
        """
        tenant_id = self.domain_to_tenant.get(domain)
        if tenant_id:
            return await self.get_tenant(tenant_id)
        return None
    
    async def update_tenant(self, tenant_id: str, updates: Dict[str, Any]) -> Optional[Tenant]:
        """
        Update tenant configuration
        
        Args:
            tenant_id: Tenant identifier
            updates: Fields to update
            
        Returns:
            Updated tenant or None if not found
        """
        try:
            tenant = await self.get_tenant(tenant_id)
            if not tenant:
                return None
            
            # Update fields
            for field, value in updates.items():
                if hasattr(tenant, field):
                    setattr(tenant, field, value)
            
            # Update tier limits if tier changed
            if 'tier' in updates:
                tenant.limits = self.tier_limits.get(
                    tenant.tier, 
                    self.tier_limits[TenantTier.FREE]
                )
            
            # Save changes
            await self._save_tenant(tenant)
            
            # Update cache
            if self.enable_caching:
                await self._cache_tenant(tenant)
            
            logger.info(f"Updated tenant {tenant_id}")
            return tenant
            
        except Exception as e:
            logger.error(f"Error updating tenant {tenant_id}: {e}")
            return None
    
    async def delete_tenant(self, tenant_id: str) -> bool:
        """
        Delete tenant
        
        Args:
            tenant_id: Tenant identifier
            
        Returns:
            True if deleted successfully
        """
        try:
            tenant = await self.get_tenant(tenant_id)
            if not tenant:
                return False
            
            # Mark as deleted
            tenant.status = TenantStatus.DELETED
            
            # Remove from memory
            if tenant_id in self.tenants:
                del self.tenants[tenant_id]
            
            if tenant.domain in self.domain_to_tenant:
                del self.domain_to_tenant[tenant.domain]
            
            # Remove from cache
            if self.enable_caching:
                await self._remove_cached_tenant(tenant_id)
            
            # Save deletion to persistent storage
            await self._save_tenant(tenant)
            
            logger.info(f"Deleted tenant {tenant_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error deleting tenant {tenant_id}: {e}")
            return False
    
    async def check_resource_limit(self, tenant_id: str, resource: str, additional: int = 1) -> bool:
        """
        Check if tenant can use additional resources
        
        Args:
            tenant_id: Tenant identifier
            resource: Resource type (users, groups, etc.)
            additional: Additional resources requested
            
        Returns:
            True if within limits
        """
        try:
            tenant = await self.get_tenant(tenant_id)
            if not tenant or not tenant.is_active():
                return False
            
            return tenant.is_within_limits(resource, additional)
            
        except Exception as e:
            logger.error(f"Error checking resource limit for {tenant_id}: {e}")
            return False
    
    async def update_usage(self, tenant_id: str, resource: str, delta: int = 1):
        """
        Update tenant resource usage
        
        Args:
            tenant_id: Tenant identifier
            resource: Resource type
            delta: Usage change (positive or negative)
        """
        try:
            tenant = await self.get_tenant(tenant_id)
            if not tenant:
                return
            
            # Update usage
            current_usage = getattr(tenant.usage, f"{resource}_count", 0)
            new_usage = max(0, current_usage + delta)
            setattr(tenant.usage, f"{resource}_count", new_usage)
            tenant.usage.last_updated = datetime.utcnow()
            
            # Save changes
            await self._save_tenant(tenant)
            
            # Update cache
            if self.enable_caching:
                await self._cache_tenant(tenant)
            
            logger.debug(f"Updated {resource} usage for tenant {tenant_id}: {new_usage}")
            
        except Exception as e:
            logger.error(f"Error updating usage for {tenant_id}: {e}")
    
    async def check_api_rate_limit(self, tenant_id: str) -> bool:
        """
        Check API rate limit for tenant
        
        Args:
            tenant_id: Tenant identifier
            
        Returns:
            True if within rate limit
        """
        try:
            tenant = await self.get_tenant(tenant_id)
            if not tenant or not tenant.is_active():
                return False
            
            # Get current hour usage
            current_hour = datetime.utcnow().strftime("%Y%m%d%H")
            cache_key = f"api_usage:{tenant_id}:{current_hour}"
            
            current_usage = 0
            if self.redis_client:
                try:
                    usage_data = await self.redis_client.get(cache_key)
                    if usage_data:
                        current_usage = int(usage_data)
                except Exception:
                    pass
            
            # Check against limit
            return current_usage < tenant.limits.max_api_requests_per_hour
            
        except Exception as e:
            logger.error(f"Error checking API rate limit for {tenant_id}: {e}")
            return False
    
    async def increment_api_usage(self, tenant_id: str) -> int:
        """
        Increment API usage counter
        
        Args:
            tenant_id: Tenant identifier
            
        Returns:
            Current usage count
        """
        try:
            current_hour = datetime.utcnow().strftime("%Y%m%d%H")
            cache_key = f"api_usage:{tenant_id}:{current_hour}"
            
            if self.redis_client:
                try:
                    # Increment counter with expiration
                    current_usage = await self.redis_client.incr(cache_key)
                    await self.redis_client.expire(cache_key, 3600)  # 1 hour
                    return current_usage
                except Exception as e:
                    logger.warning(f"Failed to increment API usage in Redis: {e}")
            
            # Fallback to in-memory tracking
            if tenant_id not in self.usage_cache:
                self.usage_cache[tenant_id] = {}
            
            if current_hour not in self.usage_cache[tenant_id]:
                self.usage_cache[tenant_id][current_hour] = 0
            
            self.usage_cache[tenant_id][current_hour] += 1
            return self.usage_cache[tenant_id][current_hour]
            
        except Exception as e:
            logger.error(f"Error incrementing API usage for {tenant_id}: {e}")
            return 0
    
    async def encrypt_tenant_data(self, tenant_id: str, data: str) -> str:
        """
        Encrypt data for specific tenant
        
        Args:
            tenant_id: Tenant identifier
            data: Data to encrypt
            
        Returns:
            Encrypted data
        """
        try:
            tenant = await self.get_tenant(tenant_id)
            if not tenant:
                raise ValueError(f"Tenant {tenant_id} not found")
            
            fernet = tenant.get_fernet_key()
            return fernet.encrypt(data.encode()).decode()
            
        except Exception as e:
            logger.error(f"Error encrypting data for tenant {tenant_id}: {e}")
            raise
    
    async def decrypt_tenant_data(self, tenant_id: str, encrypted_data: str) -> str:
        """
        Decrypt data for specific tenant
        
        Args:
            tenant_id: Tenant identifier
            encrypted_data: Encrypted data
            
        Returns:
            Decrypted data
        """
        try:
            tenant = await self.get_tenant(tenant_id)
            if not tenant:
                raise ValueError(f"Tenant {tenant_id} not found")
            
            fernet = tenant.get_fernet_key()
            return fernet.decrypt(encrypted_data.encode()).decode()
            
        except Exception as e:
            logger.error(f"Error decrypting data for tenant {tenant_id}: {e}")
            raise
    
    def get_tenant_stats(self) -> Dict[str, Any]:
        """Get multi-tenant statistics"""
        stats = {
            "total_tenants": len(self.tenants),
            "active_tenants": len([t for t in self.tenants.values() if t.is_active()]),
            "tenants_by_tier": {},
            "tenants_by_status": {},
            "total_usage": {
                "users": sum(t.usage.users_count for t in self.tenants.values()),
                "groups": sum(t.usage.groups_count for t in self.tenants.values()),
                "storage_gb": sum(t.usage.storage_used_gb for t in self.tenants.values())
            }
        }
        
        # Count by tier and status
        for tenant in self.tenants.values():
            tier = tenant.tier.value
            status = tenant.status.value
            
            stats["tenants_by_tier"][tier] = stats["tenants_by_tier"].get(tier, 0) + 1
            stats["tenants_by_status"][status] = stats["tenants_by_status"].get(status, 0) + 1
        
        return stats
    
    # Cache methods
    async def _cache_tenant(self, tenant: Tenant):
        """Cache tenant data"""
        if not self.redis_client:
            return
        
        try:
            import pickle
            cache_key = f"tenant:{tenant.id}"
            tenant_data = pickle.dumps(tenant)
            await self.redis_client.setex(cache_key, self.cache_ttl, tenant_data)
        except Exception as e:
            logger.warning(f"Failed to cache tenant {tenant.id}: {e}")
    
    async def _get_cached_tenant(self, tenant_id: str) -> Optional[Tenant]:
        """Get tenant from cache"""
        if not self.redis_client:
            return None
        
        try:
            import pickle
            cache_key = f"tenant:{tenant_id}"
            tenant_data = await self.redis_client.get(cache_key)
            if tenant_data:
                return pickle.loads(tenant_data)
        except Exception as e:
            logger.warning(f"Failed to get cached tenant {tenant_id}: {e}")
        
        return None
    
    async def _remove_cached_tenant(self, tenant_id: str):
        """Remove tenant from cache"""
        if not self.redis_client:
            return
        
        try:
            cache_key = f"tenant:{tenant_id}"
            await self.redis_client.delete(cache_key)
        except Exception as e:
            logger.warning(f"Failed to remove cached tenant {tenant_id}: {e}")
    
    # Storage methods (placeholder implementations)
    async def _load_tenants(self):
        """Load all tenants from persistent storage"""
        # TODO: Implement database loading
        pass
    
    async def _load_tenant(self, tenant_id: str) -> Optional[Tenant]:
        """Load tenant from persistent storage"""
        # TODO: Implement database loading
        return None
    
    async def _save_tenant(self, tenant: Tenant):
        """Save tenant to persistent storage"""
        # TODO: Implement database saving
        pass
    
    async def close(self):
        """Close multi-tenant manager"""
        if self.redis_client:
            await self.redis_client.close()
        
        logger.info("MultiTenantManager closed")


# Global multi-tenant manager instance
multi_tenant_manager = MultiTenantManager()


if __name__ == "__main__":
    # Test multi-tenant manager
    import asyncio
    
    async def test_multi_tenant():
        """Test multi-tenant manager functionality"""
        print("Testing MultiTenantManager...")
        
        await multi_tenant_manager.initialize()
        
        # Create test tenant
        tenant = await multi_tenant_manager.create_tenant(
            name="Test Company",
            domain="test.example.com",
            tier=TenantTier.BASIC
        )
        print(f"Created tenant: {tenant.id}")
        
        # Test limits
        within_limits = await multi_tenant_manager.check_resource_limit(
            tenant.id, "users", 5
        )
        print(f"Within user limits: {within_limits}")
        
        # Test API rate limit
        rate_limit_ok = await multi_tenant_manager.check_api_rate_limit(tenant.id)
        print(f"API rate limit OK: {rate_limit_ok}")
        
        # Get stats
        stats = multi_tenant_manager.get_tenant_stats()
        print(f"Tenant stats: {stats}")
        
        await multi_tenant_manager.close()
        print("MultiTenantManager test completed")
    
    asyncio.run(test_multi_tenant())