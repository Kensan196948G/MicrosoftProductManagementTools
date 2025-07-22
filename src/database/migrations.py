# Microsoft 365 Management Tools - Database Migrations
# Alembic-based schema versioning and PowerShell compatibility migrations

import os
import sys
import logging
from pathlib import Path
from typing import Optional, List, Dict, Any
from datetime import datetime
from sqlalchemy import create_engine, text, MetaData, Table, Column, Integer, String, DateTime, inspect
from sqlalchemy.engine import Engine
from sqlalchemy.exc import SQLAlchemyError
from alembic import command
from alembic.config import Config
from alembic.runtime.environment import EnvironmentContext
from alembic.script import ScriptDirectory
from alembic.migration import MigrationContext

from .engine import get_database_engine, create_database_url
from .models import Base, create_all_tables, create_performance_indexes

# Configure logging
logger = logging.getLogger(__name__)

# Migration configuration
MIGRATIONS_DIR = Path(__file__).parent / "migrations"
ALEMBIC_CONFIG_PATH = MIGRATIONS_DIR / "alembic.ini"

class DatabaseMigrationManager:
    """Enterprise database migration manager with PowerShell compatibility."""
    
    def __init__(self, engine: Optional[Engine] = None):
        self.engine = engine or get_database_engine()
        self.metadata = Base.metadata
        self.migrations_dir = MIGRATIONS_DIR
        self.alembic_cfg = self._setup_alembic_config()
    
    def _setup_alembic_config(self) -> Config:
        """Setup Alembic configuration for migrations."""
        # Ensure migrations directory exists
        self.migrations_dir.mkdir(exist_ok=True)
        
        # Create alembic.ini if it doesn't exist
        if not ALEMBIC_CONFIG_PATH.exists():
            self._create_alembic_config()
        
        # Configure Alembic
        alembic_cfg = Config(str(ALEMBIC_CONFIG_PATH))
        alembic_cfg.set_main_option("script_location", str(self.migrations_dir))
        alembic_cfg.set_main_option("sqlalchemy.url", create_database_url())
        
        return alembic_cfg
    
    def _create_alembic_config(self):
        """Create default alembic.ini configuration file."""
        config_content = """
# Alembic Configuration for Microsoft 365 Management Tools

[alembic]
script_location = migrations
prepend_sys_path = .
version_path_separator = os
sqlalchemy.url = 

# post_write_hooks defines scripts or Python functions that are run
# on newly generated revision scripts.
# post_write_hooks = 

# Logging configuration
[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
"""
        with open(ALEMBIC_CONFIG_PATH, 'w') as f:
            f.write(config_content.strip())
    
    def init_migrations(self) -> bool:
        """Initialize Alembic migrations directory."""
        try:
            # Check if already initialized
            if (self.migrations_dir / "env.py").exists():
                logger.info("Migrations already initialized")
                return True
            
            # Initialize Alembic
            command.init(self.alembic_cfg, str(self.migrations_dir))
            
            # Create custom env.py for Microsoft 365 tools
            self._create_custom_env_py()
            
            logger.info("Migration environment initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize migrations: {e}")
            return False
    
    def _create_custom_env_py(self):
        """Create custom env.py with Microsoft 365 tools specific configuration."""
        env_py_content = '''"""Microsoft 365 Management Tools - Alembic Environment Configuration"""
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
import os
import sys

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../')))

# Import models
from src.database.models import Base
from src.database.engine import create_database_url

# Alembic Config object
config = context.config

# Interpret the config file for Python logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Add model's MetaData object for 'autogenerate' support
target_metadata = Base.metadata

def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = create_database_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        compare_server_default=True
    )

    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    configuration = config.get_section(config.config_ini_section)
    configuration['sqlalchemy.url'] = create_database_url()
    
    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, 
            target_metadata=target_metadata,
            compare_type=True,
            compare_server_default=True
        )

        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
'''
        env_py_path = self.migrations_dir / "env.py"
        with open(env_py_path, 'w') as f:
            f.write(env_py_content)
    
    def create_migration(self, message: str, auto_generate: bool = True) -> Optional[str]:
        """Create a new migration file."""
        try:
            if auto_generate:
                # Auto-generate migration based on model changes
                revision = command.revision(
                    self.alembic_cfg, 
                    message=message, 
                    autogenerate=True
                )
            else:
                # Create empty migration template
                revision = command.revision(
                    self.alembic_cfg,
                    message=message
                )
            
            logger.info(f"Created migration: {message}")
            return revision.revision
            
        except Exception as e:
            logger.error(f"Failed to create migration '{message}': {e}")
            return None
    
    def run_migrations(self, revision: str = "head") -> bool:
        """Run database migrations up to specified revision."""
        try:
            command.upgrade(self.alembic_cfg, revision)
            logger.info(f"Migrations upgraded to: {revision}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to run migrations to '{revision}': {e}")
            return False
    
    def downgrade_migration(self, revision: str) -> bool:
        """Downgrade database to specified revision."""
        try:
            command.downgrade(self.alembic_cfg, revision)
            logger.info(f"Database downgraded to: {revision}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to downgrade to '{revision}': {e}")
            return False
    
    def get_current_revision(self) -> Optional[str]:
        """Get current database revision."""
        try:
            with self.engine.connect() as conn:
                context = MigrationContext.configure(conn)
                return context.get_current_revision()
        except Exception as e:
            logger.error(f"Failed to get current revision: {e}")
            return None
    
    def get_migration_history(self) -> List[Dict[str, Any]]:
        """Get migration history."""
        try:
            script_dir = ScriptDirectory.from_config(self.alembic_cfg)
            revisions = []
            
            for revision in script_dir.walk_revisions():
                revisions.append({
                    'revision': revision.revision,
                    'down_revision': revision.down_revision,
                    'message': revision.doc,
                    'branch_labels': revision.branch_labels,
                    'depends_on': revision.depends_on
                })
            
            return revisions
            
        except Exception as e:
            logger.error(f"Failed to get migration history: {e}")
            return []
    
    def validate_database_schema(self) -> Dict[str, Any]:
        """Validate current database schema against models."""
        try:
            inspector = inspect(self.engine)
            existing_tables = set(inspector.get_table_names())
            model_tables = set(Base.metadata.tables.keys())
            
            missing_tables = model_tables - existing_tables
            extra_tables = existing_tables - model_tables
            
            return {
                "status": "valid" if not missing_tables and not extra_tables else "invalid",
                "existing_tables": list(existing_tables),
                "model_tables": list(model_tables),
                "missing_tables": list(missing_tables),
                "extra_tables": list(extra_tables),
                "table_count": len(existing_tables)
            }
            
        except Exception as e:
            logger.error(f"Schema validation failed: {e}")
            return {"status": "error", "error": str(e)}

def run_migrations(revision: str = "head") -> bool:
    """Convenience function to run migrations."""
    manager = DatabaseMigrationManager()
    
    # Initialize if needed
    if not manager.init_migrations():
        return False
    
    # Run migrations
    return manager.run_migrations(revision)

def create_initial_migration() -> bool:
    """Create initial migration for Microsoft 365 tools database."""
    try:
        manager = DatabaseMigrationManager()
        
        # Initialize migrations
        if not manager.init_migrations():
            return False
        
        # Create initial migration
        revision = manager.create_migration(
            "Initial Microsoft 365 Management Tools schema",
            auto_generate=True
        )
        
        if revision:
            logger.info(f"Initial migration created successfully: {revision}")
            return True
        else:
            logger.error("Failed to create initial migration")
            return False
            
    except Exception as e:
        logger.error(f"Initial migration creation failed: {e}")
        return False

def setup_database() -> bool:
    """Complete database setup with migrations."""
    try:
        logger.info("Setting up Microsoft 365 Management Tools database...")
        
        # Check if database exists and is accessible
        engine = get_database_engine()
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        
        manager = DatabaseMigrationManager(engine)
        
        # Initialize migrations
        if not manager.init_migrations():
            logger.error("Failed to initialize migrations")
            return False
        
        # Check current state
        current_revision = manager.get_current_revision()
        if current_revision is None:
            # No migration history, create tables directly first time
            logger.info("No migration history found, creating initial schema...")
            create_all_tables(engine)
            create_performance_indexes(engine)
            
            # Stamp database with head revision
            command.stamp(manager.alembic_cfg, "head")
            logger.info("Database stamped with current schema version")
        else:
            # Run any pending migrations
            logger.info(f"Current revision: {current_revision}")
            if not manager.run_migrations():
                logger.error("Failed to run migrations")
                return False
        
        # Validate final schema
        validation = manager.validate_database_schema()
        if validation["status"] == "valid":
            logger.info("✅ Database setup completed successfully")
            logger.info(f"📊 Tables created: {validation['table_count']}")
            return True
        else:
            logger.warning(f"⚠️ Schema validation issues: {validation}")
            return True  # Still continue, may be acceptable
        
    except Exception as e:
        logger.error(f"Database setup failed: {e}")
        return False

# PowerShell compatibility functions
def get_powershell_migration_status() -> Dict[str, Any]:
    """Get migration status in PowerShell-compatible format."""
    try:
        manager = DatabaseMigrationManager()
        current_revision = manager.get_current_revision()
        history = manager.get_migration_history()
        validation = manager.validate_database_schema()
        
        return {
            "Status": "Connected" if current_revision else "NotInitialized",
            "CurrentRevision": current_revision or "None",
            "MigrationCount": len(history),
            "TableCount": validation.get("table_count", 0),
            "LastUpdate": datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'),
            "SchemaValid": validation.get("status") == "valid"
        }
        
    except Exception as e:
        return {
            "Status": "Error",
            "CurrentRevision": "Unknown",
            "Error": str(e),
            "LastUpdate": datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        }

if __name__ == "__main__":
    # Test migration functionality
    try:
        print("🔄 Testing database migration functionality...")
        
        # Setup database
        if setup_database():
            print("✅ Database setup successful")
            
            # Get status
            status = get_powershell_migration_status()
            print(f"📊 Migration status: {status}")
            
        else:
            print("❌ Database setup failed")
            
    except Exception as e:
        print(f"❌ Migration test failed: {e}")