# Microsoft 365 Management Tools - Database Engine Configuration
# Enterprise PostgreSQL with connection pooling and security

import os
import logging
from typing import Optional, Generator
from contextlib import contextmanager
from sqlalchemy import create_engine, event, MetaData
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
from sqlalchemy.ext.declarative import declarative_base
import urllib.parse

# Configure logging
logger = logging.getLogger(__name__)

# Database configuration
DATABASE_CONFIG = {
    'host': os.getenv('DATABASE_HOST', 'localhost'),
    'port': int(os.getenv('DATABASE_PORT', '5432')),
    'database': os.getenv('DATABASE_NAME', 'microsoft365_tools'),
    'username': os.getenv('DATABASE_USERNAME', 'postgres'),
    'password': os.getenv('DATABASE_PASSWORD', ''),
    'ssl_mode': os.getenv('DATABASE_SSL_MODE', 'require'),
    'pool_size': int(os.getenv('DATABASE_POOL_SIZE', '20')),
    'max_overflow': int(os.getenv('DATABASE_MAX_OVERFLOW', '30')),
    'pool_timeout': int(os.getenv('DATABASE_POOL_TIMEOUT', '30')),
    'pool_recycle': int(os.getenv('DATABASE_POOL_RECYCLE', '3600')),
    'echo': os.getenv('DATABASE_ECHO', 'false').lower() == 'true'
}

# SQLAlchemy Base
Base = declarative_base()

# Global engine instance
_engine: Optional[Engine] = None
_SessionLocal: Optional[sessionmaker] = None

def create_database_url() -> str:
    """Create PostgreSQL database URL with proper encoding."""
    password = urllib.parse.quote_plus(DATABASE_CONFIG['password'])
    username = urllib.parse.quote_plus(DATABASE_CONFIG['username'])
    
    return (
        f"postgresql://{username}:{password}@"
        f"{DATABASE_CONFIG['host']}:{DATABASE_CONFIG['port']}/"
        f"{DATABASE_CONFIG['database']}?sslmode={DATABASE_CONFIG['ssl_mode']}"
    )

def get_database_engine() -> Engine:
    """Get or create database engine with enterprise configuration."""
    global _engine
    
    if _engine is None:
        database_url = create_database_url()
        
        _engine = create_engine(
            database_url,
            echo=DATABASE_CONFIG['echo'],
            poolclass=QueuePool,
            pool_size=DATABASE_CONFIG['pool_size'],
            max_overflow=DATABASE_CONFIG['max_overflow'],
            pool_timeout=DATABASE_CONFIG['pool_timeout'],
            pool_recycle=DATABASE_CONFIG['pool_recycle'],
            pool_pre_ping=True,  # Verify connections before use
            connect_args={
                "application_name": "Microsoft365Tools",
                "options": "-c timezone=UTC",
                "sslmode": DATABASE_CONFIG['ssl_mode'],
                "connect_timeout": "10",
                "tcp_keepalives_idle": "600",
                "tcp_keepalives_interval": "30",
                "tcp_keepalives_count": "3"
            }
        )
        
        # Add event listeners for connection management
        @event.listens_for(_engine, "connect")
        def set_sqlite_pragma(dbapi_connection, connection_record):
            """Set connection-level configurations."""
            if hasattr(dbapi_connection, 'execute'):
                # Set session timezone to UTC
                cursor = dbapi_connection.cursor()
                cursor.execute("SET timezone = 'UTC'")
                cursor.execute("SET statement_timeout = '60s'")
                cursor.execute("SET lock_timeout = '30s'")
                cursor.close()
        
        @event.listens_for(_engine, "checkout")
        def receive_checkout(dbapi_connection, connection_record, connection_proxy):
            """Log connection checkout for monitoring."""
            logger.debug("Connection checked out from pool")
        
        @event.listens_for(_engine, "checkin")
        def receive_checkin(dbapi_connection, connection_record):
            """Log connection checkin for monitoring.""" 
            logger.debug("Connection checked in to pool")
        
        logger.info(f"Database engine created: {DATABASE_CONFIG['host']}:{DATABASE_CONFIG['port']}")
    
    return _engine

def get_session_maker() -> sessionmaker:
    """Get session maker for database operations."""
    global _SessionLocal
    
    if _SessionLocal is None:
        engine = get_database_engine()
        _SessionLocal = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=engine,
            expire_on_commit=False
        )
        logger.info("Database session maker created")
    
    return _SessionLocal

@contextmanager
def get_session() -> Generator[Session, None, None]:
    """Get database session with automatic cleanup."""
    SessionLocal = get_session_maker()
    session = SessionLocal()
    
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        logger.error(f"Database session error: {e}")
        raise
    finally:
        session.close()

def get_db_session() -> Session:
    """Get database session for dependency injection."""
    SessionLocal = get_session_maker()
    return SessionLocal()

def create_all_tables():
    """Create all database tables."""
    engine = get_database_engine()
    Base.metadata.create_all(bind=engine)
    logger.info("All database tables created")

def drop_all_tables():
    """Drop all database tables (use with caution)."""
    engine = get_database_engine()
    Base.metadata.drop_all(bind=engine)
    logger.warning("All database tables dropped")

def check_database_connection() -> bool:
    """Check database connectivity."""
    try:
        engine = get_database_engine()
        with engine.connect() as conn:
            result = conn.execute("SELECT 1")
            return bool(result.fetchone())
    except Exception as e:
        logger.error(f"Database connection check failed: {e}")
        return False

def get_database_info() -> dict:
    """Get database information for monitoring."""
    try:
        engine = get_database_engine()
        with engine.connect() as conn:
            version_result = conn.execute("SELECT version()")
            version = version_result.fetchone()[0]
            
            size_result = conn.execute(
                "SELECT pg_size_pretty(pg_database_size(current_database()))"
            )
            size = size_result.fetchone()[0]
            
            return {
                "status": "connected",
                "version": version,
                "database_size": size,
                "pool_size": engine.pool.size(),
                "checked_out_connections": engine.pool.checkedout(),
                "overflow_connections": engine.pool.overflow(),
                "invalid_connections": engine.pool.invalid()
            }
    except Exception as e:
        logger.error(f"Failed to get database info: {e}")
        return {"status": "error", "error": str(e)}

# Health check function
async def database_health_check() -> dict:
    """Async health check for database."""
    try:
        is_connected = check_database_connection()
        info = get_database_info() if is_connected else {"status": "disconnected"}
        
        return {
            "database": {
                "status": "healthy" if is_connected else "unhealthy",
                "connected": is_connected,
                "details": info
            }
        }
    except Exception as e:
        return {
            "database": {
                "status": "unhealthy",
                "connected": False,
                "error": str(e)
            }
        }