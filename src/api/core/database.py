"""
Database management for Microsoft 365 Management Tools API
SQLAlchemy-based database layer with ORM models and connection management.
"""

import asyncio
import logging
from typing import Optional, Dict, Any, List, AsyncGenerator
from contextlib import asynccontextmanager
from sqlalchemy import create_engine, text, MetaData, Table, Column, Integer, String, DateTime, Boolean, Text, Float, ForeignKey
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session
from sqlalchemy.pool import StaticPool
from sqlalchemy.exc import SQLAlchemyError
from datetime import datetime, timedelta
import json
import uuid

# Simplified config for API
class Settings:
    DATABASE_URL = "sqlite:///./m365_tools.db"
    DATABASE_POOL_SIZE = 10

def get_database_config(settings):
    return {
        "url": settings.DATABASE_URL,
        "pool_size": 10,
        "max_overflow": 20,
        "pool_timeout": 30,
        "echo": False,
        "pool_pre_ping": True,
        "pool_recycle": 3600
    }

logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    """Base class for all ORM models."""
    pass


class User(Base):
    """
    User model for Microsoft 365 users.
    Maps to PowerShell Get-M365AllUsers functionality.
    """
    __tablename__ = "users"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    user_principal_name: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    display_name: Mapped[Optional[str]] = mapped_column(String(255))
    mail: Mapped[Optional[str]] = mapped_column(String(255))
    job_title: Mapped[Optional[str]] = mapped_column(String(255))
    department: Mapped[Optional[str]] = mapped_column(String(255))
    office_location: Mapped[Optional[str]] = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(100))
    usage_location: Mapped[Optional[str]] = mapped_column(String(10))
    is_licensed: Mapped[bool] = mapped_column(Boolean, default=False)
    account_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_datetime: Mapped[Optional[datetime]] = mapped_column(DateTime)
    last_signin_datetime: Mapped[Optional[datetime]] = mapped_column(DateTime)
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Relationships
    licenses: Mapped[List["UserLicense"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    signin_logs: Mapped[List["SignInLog"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self) -> str:
        return f"User(id={self.id!r}, upn={self.user_principal_name!r}, display_name={self.display_name!r})"


class UserLicense(Base):
    """
    User license model for Microsoft 365 license assignments.
    Maps to PowerShell Get-M365LicenseAnalysis functionality.
    """
    __tablename__ = "user_licenses"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    sku_id: Mapped[str] = mapped_column(String(100))
    sku_part_number: Mapped[str] = mapped_column(String(100))
    display_name: Mapped[str] = mapped_column(String(255))
    consumed_units: Mapped[int] = mapped_column(Integer, default=0)
    enabled_units: Mapped[int] = mapped_column(Integer, default=0)
    suspended_units: Mapped[int] = mapped_column(Integer, default=0)
    warning_units: Mapped[int] = mapped_column(Integer, default=0)
    assigned_datetime: Mapped[Optional[datetime]] = mapped_column(DateTime)
    
    # Relationships
    user: Mapped["User"] = relationship(back_populates="licenses")
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self) -> str:
        return f"UserLicense(id={self.id!r}, sku={self.sku_part_number!r}, user_id={self.user_id!r})"


class SignInLog(Base):
    """
    Sign-in log model for Microsoft 365 sign-in events.
    Maps to PowerShell Get-M365SignInLogs functionality.
    """
    __tablename__ = "signin_logs"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    signin_datetime: Mapped[datetime] = mapped_column(DateTime, index=True)
    user_principal_name: Mapped[str] = mapped_column(String(255), index=True)
    app_display_name: Mapped[Optional[str]] = mapped_column(String(255))
    client_app_used: Mapped[Optional[str]] = mapped_column(String(255))
    ip_address: Mapped[Optional[str]] = mapped_column(String(45))
    location: Mapped[Optional[str]] = mapped_column(String(255))
    device_detail: Mapped[Optional[str]] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(50))
    error_code: Mapped[Optional[int]] = mapped_column(Integer)
    failure_reason: Mapped[Optional[str]] = mapped_column(Text)
    risk_level: Mapped[Optional[str]] = mapped_column(String(50))
    
    # Relationships
    user: Mapped["User"] = relationship(back_populates="signin_logs")
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"SignInLog(id={self.id!r}, user_id={self.user_id!r}, status={self.status!r})"


class Report(Base):
    """
    Report model for tracking generated reports.
    Maps to PowerShell report generation functionality.
    """
    __tablename__ = "reports"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    report_type: Mapped[str] = mapped_column(String(100), index=True)
    report_name: Mapped[str] = mapped_column(String(255))
    description: Mapped[Optional[str]] = mapped_column(Text)
    parameters: Mapped[Optional[str]] = mapped_column(Text)  # JSON string
    file_path: Mapped[Optional[str]] = mapped_column(String(500))
    file_format: Mapped[str] = mapped_column(String(10))  # csv, html, pdf, etc.
    file_size: Mapped[Optional[int]] = mapped_column(Integer)
    record_count: Mapped[Optional[int]] = mapped_column(Integer)
    generation_time: Mapped[Optional[float]] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String(50), default="pending")
    error_message: Mapped[Optional[str]] = mapped_column(Text)
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self) -> str:
        return f"Report(id={self.id!r}, type={self.report_type!r}, status={self.status!r})"


class ApiCache(Base):
    """
    API cache model for caching Microsoft Graph API responses.
    Improves performance by reducing API calls.
    """
    __tablename__ = "api_cache"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    cache_key: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    endpoint: Mapped[str] = mapped_column(String(255))
    parameters: Mapped[Optional[str]] = mapped_column(Text)  # JSON string
    response_data: Mapped[str] = mapped_column(Text)  # JSON string
    expires_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self) -> str:
        return f"ApiCache(id={self.id!r}, key={self.cache_key!r}, expires_at={self.expires_at!r})"


class AuditLog(Base):
    """
    Audit log model for tracking API operations and changes.
    Provides audit trail for compliance requirements.
    """
    __tablename__ = "audit_logs"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    operation: Mapped[str] = mapped_column(String(100), index=True)
    resource_type: Mapped[str] = mapped_column(String(100))
    resource_id: Mapped[Optional[str]] = mapped_column(String(255))
    user_principal_name: Mapped[Optional[str]] = mapped_column(String(255))
    details: Mapped[Optional[str]] = mapped_column(Text)  # JSON string
    ip_address: Mapped[Optional[str]] = mapped_column(String(45))
    user_agent: Mapped[Optional[str]] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(String(50))
    error_message: Mapped[Optional[str]] = mapped_column(Text)
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    def __repr__(self) -> str:
        return f"AuditLog(id={self.id!r}, operation={self.operation!r}, status={self.status!r})"


class DatabaseManager:
    """
    Database manager for handling connections, sessions, and operations.
    Provides async support and connection pooling.
    """
    
    def __init__(self, settings: Settings):
        self.settings = settings
        self.engine: Optional[AsyncEngine] = None
        self.session_factory: Optional[async_sessionmaker] = None
        self.logger = logging.getLogger(__name__)
        
    async def initialize(self) -> None:
        """Initialize database engine and create tables."""
        try:
            database_config = get_database_config(self.settings)
            
            # Convert sync URL to async URL
            database_url = database_config["url"]
            if database_url.startswith("postgresql://"):
                database_url = database_url.replace("postgresql://", "postgresql+asyncpg://", 1)
            elif database_url.startswith("mysql://"):
                database_url = database_url.replace("mysql://", "mysql+aiomysql://", 1)
            elif database_url.startswith("sqlite:///"):
                database_url = database_url.replace("sqlite:///", "sqlite+aiosqlite:///", 1)
            
            # Create async engine
            self.engine = create_async_engine(
                database_url,
                pool_size=database_config.get("pool_size", 10),
                max_overflow=database_config.get("max_overflow", 20),
                pool_timeout=database_config.get("pool_timeout", 30),
                echo=database_config.get("echo", False),
                pool_pre_ping=database_config.get("pool_pre_ping", True),
                pool_recycle=database_config.get("pool_recycle", 3600)
            )
            
            # Create session factory
            self.session_factory = async_sessionmaker(
                self.engine,
                class_=AsyncSession,
                expire_on_commit=False
            )
            
            # Create tables
            await self.create_tables()
            
            self.logger.info("Database initialized successfully")
            
        except Exception as e:
            self.logger.error(f"Failed to initialize database: {str(e)}")
            raise
    
    async def create_tables(self) -> None:
        """Create all database tables."""
        try:
            async with self.engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            self.logger.info("Database tables created successfully")
        except Exception as e:
            self.logger.error(f"Failed to create tables: {str(e)}")
            raise
    
    async def drop_tables(self) -> None:
        """Drop all database tables."""
        try:
            async with self.engine.begin() as conn:
                await conn.run_sync(Base.metadata.drop_all)
            self.logger.info("Database tables dropped successfully")
        except Exception as e:
            self.logger.error(f"Failed to drop tables: {str(e)}")
            raise
    
    @asynccontextmanager
    async def get_session(self) -> AsyncGenerator[AsyncSession, None]:
        """Get database session with automatic cleanup."""
        if not self.session_factory:
            raise RuntimeError("Database not initialized")
        
        async with self.session_factory() as session:
            try:
                yield session
            except Exception as e:
                await session.rollback()
                self.logger.error(f"Database session error: {str(e)}")
                raise
            finally:
                await session.close()
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform database health check."""
        try:
            async with self.get_session() as session:
                result = await session.execute(text("SELECT 1"))
                result.scalar_one()
                
                # Get connection info
                connection_info = {
                    "status": "healthy",
                    "database_url": self.settings.DATABASE_URL.split("@")[1] if "@" in self.settings.DATABASE_URL else "sqlite",
                    "pool_size": self.settings.DATABASE_POOL_SIZE,
                    "timestamp": datetime.utcnow().isoformat()
                }
                
                return connection_info
                
        except Exception as e:
            self.logger.error(f"Database health check failed: {str(e)}")
            return {
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    async def get_table_info(self) -> Dict[str, Any]:
        """Get information about database tables."""
        try:
            async with self.get_session() as session:
                tables_info = {}
                
                for table_name, table in Base.metadata.tables.items():
                    # Get row count
                    result = await session.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
                    row_count = result.scalar_one()
                    
                    tables_info[table_name] = {
                        "row_count": row_count,
                        "columns": len(table.columns),
                        "column_names": [col.name for col in table.columns]
                    }
                
                return tables_info
                
        except Exception as e:
            self.logger.error(f"Failed to get table info: {str(e)}")
            return {}
    
    async def cleanup_expired_cache(self) -> int:
        """Clean up expired cache entries."""
        try:
            async with self.get_session() as session:
                result = await session.execute(
                    text("DELETE FROM api_cache WHERE expires_at < :now"),
                    {"now": datetime.utcnow()}
                )
                deleted_count = result.rowcount
                await session.commit()
                
                self.logger.info(f"Cleaned up {deleted_count} expired cache entries")
                return deleted_count
                
        except Exception as e:
            self.logger.error(f"Failed to cleanup expired cache: {str(e)}")
            return 0
    
    async def cleanup_old_audit_logs(self, days: int = 90) -> int:
        """Clean up old audit logs."""
        try:
            cutoff_date = datetime.utcnow() - timedelta(days=days)
            
            async with self.get_session() as session:
                result = await session.execute(
                    text("DELETE FROM audit_logs WHERE created_at < :cutoff"),
                    {"cutoff": cutoff_date}
                )
                deleted_count = result.rowcount
                await session.commit()
                
                self.logger.info(f"Cleaned up {deleted_count} old audit log entries")
                return deleted_count
                
        except Exception as e:
            self.logger.error(f"Failed to cleanup old audit logs: {str(e)}")
            return 0
    
    async def backup_database(self, backup_path: str) -> bool:
        """Create database backup (SQLite only)."""
        try:
            if not self.settings.DATABASE_URL.startswith("sqlite"):
                self.logger.warning("Backup only supported for SQLite databases")
                return False
            
            # For SQLite, we can use the backup API
            # This is a simplified implementation
            import shutil
            import os
            
            db_path = self.settings.DATABASE_URL.replace("sqlite:///", "")
            if os.path.exists(db_path):
                shutil.copy2(db_path, backup_path)
                self.logger.info(f"Database backed up to {backup_path}")
                return True
            else:
                self.logger.error("Database file not found")
                return False
                
        except Exception as e:
            self.logger.error(f"Failed to backup database: {str(e)}")
            return False
    
    async def close(self) -> None:
        """Close database connections."""
        if self.engine:
            await self.engine.dispose()
            self.logger.info("Database connections closed")


# Repository pattern implementations
class UserRepository:
    """Repository for User operations."""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self.logger = logging.getLogger(__name__)
    
    async def get_all_users(self, skip: int = 0, limit: int = 100) -> List[User]:
        """Get all users with pagination."""
        async with self.db_manager.get_session() as session:
            from sqlalchemy import select
            
            stmt = select(User).offset(skip).limit(limit)
            result = await session.execute(stmt)
            return result.scalars().all()
    
    async def get_user_by_upn(self, user_principal_name: str) -> Optional[User]:
        """Get user by UPN."""
        async with self.db_manager.get_session() as session:
            from sqlalchemy import select
            
            stmt = select(User).where(User.user_principal_name == user_principal_name)
            result = await session.execute(stmt)
            return result.scalar_one_or_none()
    
    async def create_user(self, user_data: Dict[str, Any]) -> User:
        """Create a new user."""
        async with self.db_manager.get_session() as session:
            user = User(**user_data)
            session.add(user)
            await session.commit()
            await session.refresh(user)
            return user
    
    async def update_user(self, user_id: int, user_data: Dict[str, Any]) -> Optional[User]:
        """Update user data."""
        async with self.db_manager.get_session() as session:
            from sqlalchemy import select
            
            stmt = select(User).where(User.id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            
            if user:
                for key, value in user_data.items():
                    setattr(user, key, value)
                user.updated_at = datetime.utcnow()
                await session.commit()
                await session.refresh(user)
            
            return user
    
    async def delete_user(self, user_id: int) -> bool:
        """Delete user."""
        async with self.db_manager.get_session() as session:
            from sqlalchemy import select
            
            stmt = select(User).where(User.id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            
            if user:
                await session.delete(user)
                await session.commit()
                return True
            
            return False


class CacheRepository:
    """Repository for API cache operations."""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self.logger = logging.getLogger(__name__)
    
    async def get_cache(self, cache_key: str) -> Optional[ApiCache]:
        """Get cached data by key."""
        async with self.db_manager.get_session() as session:
            from sqlalchemy import select
            
            stmt = select(ApiCache).where(
                ApiCache.cache_key == cache_key,
                ApiCache.expires_at > datetime.utcnow()
            )
            result = await session.execute(stmt)
            return result.scalar_one_or_none()
    
    async def set_cache(self, cache_key: str, endpoint: str, parameters: Optional[Dict], 
                       response_data: Dict, ttl: int = 300) -> ApiCache:
        """Set cached data."""
        async with self.db_manager.get_session() as session:
            from sqlalchemy import select
            
            expires_at = datetime.utcnow() + timedelta(seconds=ttl)
            
            # Check if cache entry already exists
            stmt = select(ApiCache).where(ApiCache.cache_key == cache_key)
            result = await session.execute(stmt)
            cache_entry = result.scalar_one_or_none()
            
            if cache_entry:
                # Update existing entry
                cache_entry.endpoint = endpoint
                cache_entry.parameters = json.dumps(parameters) if parameters else None
                cache_entry.response_data = json.dumps(response_data)
                cache_entry.expires_at = expires_at
                cache_entry.updated_at = datetime.utcnow()
            else:
                # Create new entry
                cache_entry = ApiCache(
                    cache_key=cache_key,
                    endpoint=endpoint,
                    parameters=json.dumps(parameters) if parameters else None,
                    response_data=json.dumps(response_data),
                    expires_at=expires_at
                )
                session.add(cache_entry)
            
            await session.commit()
            await session.refresh(cache_entry)
            return cache_entry


class AuditRepository:
    """Repository for audit log operations."""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self.logger = logging.getLogger(__name__)
    
    async def log_operation(self, operation: str, resource_type: str, 
                           resource_id: Optional[str] = None, 
                           user_principal_name: Optional[str] = None,
                           details: Optional[Dict] = None,
                           ip_address: Optional[str] = None,
                           user_agent: Optional[str] = None,
                           status: str = "success",
                           error_message: Optional[str] = None) -> AuditLog:
        """Log an operation to the audit trail."""
        async with self.db_manager.get_session() as session:
            audit_log = AuditLog(
                operation=operation,
                resource_type=resource_type,
                resource_id=resource_id,
                user_principal_name=user_principal_name,
                details=json.dumps(details) if details else None,
                ip_address=ip_address,
                user_agent=user_agent,
                status=status,
                error_message=error_message
            )
            session.add(audit_log)
            await session.commit()
            await session.refresh(audit_log)
            return audit_log
    
    async def get_audit_logs(self, skip: int = 0, limit: int = 100, 
                            operation: Optional[str] = None,
                            resource_type: Optional[str] = None,
                            start_date: Optional[datetime] = None,
                            end_date: Optional[datetime] = None) -> List[AuditLog]:
        """Get audit logs with filtering."""
        async with self.db_manager.get_session() as session:
            from sqlalchemy import select
            
            stmt = select(AuditLog)
            
            if operation:
                stmt = stmt.where(AuditLog.operation == operation)
            if resource_type:
                stmt = stmt.where(AuditLog.resource_type == resource_type)
            if start_date:
                stmt = stmt.where(AuditLog.created_at >= start_date)
            if end_date:
                stmt = stmt.where(AuditLog.created_at <= end_date)
            
            stmt = stmt.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit)
            
            result = await session.execute(stmt)
            return result.scalars().all()


# Global database manager instance
_db_manager: Optional[DatabaseManager] = None


def get_db_manager() -> DatabaseManager:
    """Get the global database manager."""
    global _db_manager
    if _db_manager is None:
        settings = Settings()
        _db_manager = DatabaseManager(settings)
    return _db_manager