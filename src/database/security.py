# Microsoft 365 Management Tools - Database Security Implementation
# Enterprise-grade encryption, access control, and audit logging

import os
import logging
from typing import Optional, Dict, Any, List, Union
from datetime import datetime, timedelta
import hashlib
import secrets
import base64
import json
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from sqlalchemy import event, text, inspect
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session
from contextlib import contextmanager

from .engine import get_database_engine

# Configure logging
logger = logging.getLogger(__name__)

# Security configuration
SECURITY_CONFIG = {
    'encryption_key_path': os.getenv('DATABASE_ENCRYPTION_KEY_PATH', '/etc/ms365-tools/encryption.key'),
    'master_key_length': 32,  # 256-bit key
    'salt_length': 16,        # 128-bit salt
    'iteration_count': 100000, # PBKDF2 iterations
    'audit_log_retention_days': int(os.getenv('AUDIT_LOG_RETENTION_DAYS', '365')),
    'failed_login_threshold': int(os.getenv('FAILED_LOGIN_THRESHOLD', '5')),
    'session_timeout_minutes': int(os.getenv('SESSION_TIMEOUT_MINUTES', '30')),
    'require_ssl': os.getenv('DATABASE_REQUIRE_SSL', 'true').lower() == 'true',
    'audit_enabled': os.getenv('DATABASE_AUDIT_ENABLED', 'true').lower() == 'true'
}

class DatabaseSecurityManager:
    """Enterprise database security manager with encryption and access control."""
    
    def __init__(self, engine: Optional[Engine] = None):
        self.engine = engine or get_database_engine()
        self.master_key = self._load_or_create_master_key()
        self.cipher = self._create_cipher()
        self.audit_enabled = SECURITY_CONFIG['audit_enabled']
        self._setup_audit_logging()
    
    def _load_or_create_master_key(self) -> bytes:
        """Load or create master encryption key."""
        key_path = SECURITY_CONFIG['encryption_key_path']
        
        try:
            # Ensure directory exists
            os.makedirs(os.path.dirname(key_path), exist_ok=True)
            
            if os.path.exists(key_path):
                # Load existing key
                with open(key_path, 'rb') as f:
                    key = base64.b64decode(f.read())
                logger.info("Loaded existing master encryption key")
                return key
            else:
                # Create new key
                key = secrets.token_bytes(SECURITY_CONFIG['master_key_length'])
                
                # Save key with restricted permissions
                with open(key_path, 'wb') as f:
                    f.write(base64.b64encode(key))
                
                # Set file permissions (owner read/write only)
                os.chmod(key_path, 0o600)
                
                logger.info("Created new master encryption key")
                return key
                
        except Exception as e:
            logger.error(f"Failed to load/create master key: {e}")
            # Fallback to environment variable or generate temporary key
            env_key = os.getenv('DATABASE_MASTER_KEY')
            if env_key:
                return base64.b64decode(env_key)
            else:
                logger.warning("Using temporary encryption key - data will not persist!")
                return secrets.token_bytes(SECURITY_CONFIG['master_key_length'])
    
    def _create_cipher(self) -> Fernet:
        """Create Fernet cipher for symmetric encryption."""
        # Derive key using PBKDF2
        salt = b'ms365_tools_salt'  # In production, use random salt per installation
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=SECURITY_CONFIG['iteration_count']
        )
        
        derived_key = base64.urlsafe_b64encode(kdf.derive(self.master_key))
        return Fernet(derived_key)
    
    def _setup_audit_logging(self):
        """Setup database audit logging."""
        if not self.audit_enabled:
            return
        
        try:
            # Create audit log table if it doesn't exist
            with self.engine.connect() as conn:
                audit_table_sql = """
                CREATE TABLE IF NOT EXISTS database_audit_log (
                    id SERIAL PRIMARY KEY,
                    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    user_name VARCHAR(255),
                    session_id VARCHAR(255),
                    operation VARCHAR(50),
                    table_name VARCHAR(255),
                    record_id VARCHAR(255),
                    old_values JSONB,
                    new_values JSONB,
                    ip_address INET,
                    user_agent TEXT,
                    success BOOLEAN DEFAULT TRUE,
                    error_message TEXT
                );
                """
                conn.execute(text(audit_table_sql))
                
                # Create index for performance
                index_sql = """
                CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_timestamp 
                ON database_audit_log(timestamp);
                """
                conn.execute(text(index_sql))
                conn.commit()
            
            logger.info("Database audit logging initialized")
            
        except Exception as e:
            logger.error(f"Failed to setup audit logging: {e}")
    
    def encrypt_sensitive_data(self, data: Union[str, Dict, List]) -> str:
        """Encrypt sensitive data for database storage."""
        try:
            if isinstance(data, (dict, list)):
                data_str = json.dumps(data, default=str)
            else:
                data_str = str(data)
            
            encrypted_data = self.cipher.encrypt(data_str.encode())
            return base64.b64encode(encrypted_data).decode()
            
        except Exception as e:
            logger.error(f"Data encryption failed: {e}")
            raise
    
    def decrypt_sensitive_data(self, encrypted_data: str) -> Union[str, Dict, List]:
        """Decrypt sensitive data from database."""
        try:
            decoded_data = base64.b64decode(encrypted_data.encode())
            decrypted_data = self.cipher.decrypt(decoded_data).decode()
            
            # Try to parse as JSON first
            try:
                return json.loads(decrypted_data)
            except json.JSONDecodeError:
                return decrypted_data
                
        except Exception as e:
            logger.error(f"Data decryption failed: {e}")
            raise
    
    def hash_sensitive_field(self, data: str, salt: Optional[bytes] = None) -> tuple:
        """Hash sensitive field with salt for database storage."""
        try:
            if salt is None:
                salt = secrets.token_bytes(SECURITY_CONFIG['salt_length'])
            
            # Create hash using PBKDF2
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=SECURITY_CONFIG['iteration_count']
            )
            
            hash_value = kdf.derive(data.encode())
            return base64.b64encode(hash_value).decode(), base64.b64encode(salt).decode()
            
        except Exception as e:
            logger.error(f"Field hashing failed: {e}")
            raise
    
    def verify_hashed_field(self, data: str, hash_value: str, salt: str) -> bool:
        """Verify hashed field against stored hash."""
        try:
            decoded_salt = base64.b64decode(salt.encode())
            computed_hash, _ = self.hash_sensitive_field(data, decoded_salt)
            return computed_hash == hash_value
            
        except Exception as e:
            logger.error(f"Hash verification failed: {e}")
            return False
    
    def log_audit_event(self, session: Session, operation: str, table_name: str,
                       record_id: Optional[str] = None, old_values: Optional[Dict] = None,
                       new_values: Optional[Dict] = None, user_name: Optional[str] = None,
                       session_id: Optional[str] = None, ip_address: Optional[str] = None,
                       user_agent: Optional[str] = None, success: bool = True,
                       error_message: Optional[str] = None):
        """Log audit event to database."""
        if not self.audit_enabled:
            return
        
        try:
            audit_sql = text("""
                INSERT INTO database_audit_log 
                (user_name, session_id, operation, table_name, record_id, 
                 old_values, new_values, ip_address, user_agent, success, error_message)
                VALUES 
                (:user_name, :session_id, :operation, :table_name, :record_id,
                 :old_values, :new_values, :ip_address, :user_agent, :success, :error_message)
            """)
            
            session.execute(audit_sql, {
                'user_name': user_name or 'system',
                'session_id': session_id or 'unknown',
                'operation': operation,
                'table_name': table_name,
                'record_id': record_id,
                'old_values': json.dumps(old_values) if old_values else None,
                'new_values': json.dumps(new_values) if new_values else None,
                'ip_address': ip_address,
                'user_agent': user_agent,
                'success': success,
                'error_message': error_message
            })
            
        except Exception as e:
            logger.error(f"Audit logging failed: {e}")
    
    def setup_row_level_security(self):
        """Setup PostgreSQL Row Level Security (RLS)."""
        try:
            with self.engine.connect() as conn:
                # Enable RLS on sensitive tables
                sensitive_tables = [
                    'users', 'mfa_status', 'signin_logs',
                    'mailboxes', 'mail_flow_analysis', 
                    'onedrive_storage_analysis', 'teams_usage'
                ]
                
                for table in sensitive_tables:
                    try:
                        # Enable RLS
                        conn.execute(text(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY"))
                        
                        # Create policy for application users
                        policy_sql = f"""
                        CREATE POLICY IF NOT EXISTS {table}_access_policy ON {table}
                        FOR ALL TO ms365_app_user
                        USING (true)
                        """
                        conn.execute(text(policy_sql))
                        
                    except Exception as e:
                        logger.warning(f"RLS setup failed for table {table}: {e}")
                
                conn.commit()
                logger.info("Row Level Security configured")
                
        except Exception as e:
            logger.error(f"RLS setup failed: {e}")
    
    def create_database_users(self):
        """Create database users with appropriate privileges."""
        try:
            with self.engine.connect() as conn:
                # Create application user with limited privileges
                user_sql = """
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ms365_app_user') THEN
                        CREATE ROLE ms365_app_user LOGIN PASSWORD 'secure_password';
                    END IF;
                    
                    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ms365_readonly_user') THEN
                        CREATE ROLE ms365_readonly_user LOGIN PASSWORD 'readonly_password';
                    END IF;
                END
                $$;
                """
                conn.execute(text(user_sql))
                
                # Grant appropriate privileges
                privileges_sql = """
                -- Application user privileges
                GRANT CONNECT ON DATABASE microsoft365_tools TO ms365_app_user;
                GRANT USAGE ON SCHEMA public TO ms365_app_user;
                GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ms365_app_user;
                GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO ms365_app_user;
                
                -- Read-only user privileges
                GRANT CONNECT ON DATABASE microsoft365_tools TO ms365_readonly_user;
                GRANT USAGE ON SCHEMA public TO ms365_readonly_user;
                GRANT SELECT ON ALL TABLES IN SCHEMA public TO ms365_readonly_user;
                """
                conn.execute(text(privileges_sql))
                conn.commit()
                
                logger.info("Database users created with appropriate privileges")
                
        except Exception as e:
            logger.error(f"Database user creation failed: {e}")
    
    def cleanup_audit_logs(self, retention_days: Optional[int] = None):
        """Cleanup old audit logs based on retention policy."""
        if not self.audit_enabled:
            return
        
        retention_days = retention_days or SECURITY_CONFIG['audit_log_retention_days']
        
        try:
            with self.engine.connect() as conn:
                cleanup_sql = text("""
                    DELETE FROM database_audit_log 
                    WHERE timestamp < :cutoff_date
                """)
                
                cutoff_date = datetime.utcnow() - timedelta(days=retention_days)
                result = conn.execute(cleanup_sql, {'cutoff_date': cutoff_date})
                
                logger.info(f"Cleaned up {result.rowcount} old audit log entries")
                conn.commit()
                
        except Exception as e:
            logger.error(f"Audit log cleanup failed: {e}")
    
    def get_security_metrics(self) -> Dict[str, Any]:
        """Get security metrics and health information."""
        try:
            with self.engine.connect() as conn:
                # Check SSL connection
                ssl_result = conn.execute(text("SHOW ssl"))
                ssl_enabled = ssl_result.fetchone()[0] == 'on'
                
                # Get audit log statistics
                audit_stats = {}
                if self.audit_enabled:
                    audit_result = conn.execute(text("""
                        SELECT 
                            COUNT(*) as total_events,
                            COUNT(*) FILTER (WHERE timestamp >= CURRENT_DATE) as today_events,
                            COUNT(*) FILTER (WHERE success = false) as failed_events
                        FROM database_audit_log
                    """))
                    stats = audit_result.fetchone()
                    audit_stats = {
                        'total_events': stats[0] if stats else 0,
                        'today_events': stats[1] if stats else 0,
                        'failed_events': stats[2] if stats else 0
                    }
                
                return {
                    'ssl_enabled': ssl_enabled,
                    'audit_enabled': self.audit_enabled,
                    'encryption_active': bool(self.cipher),
                    'audit_statistics': audit_stats,
                    'last_check': datetime.utcnow().isoformat()
                }
                
        except Exception as e:
            logger.error(f"Security metrics collection failed: {e}")
            return {'error': str(e)}

# Event listeners for audit logging
security_manager = None

def setup_security_events(engine: Engine):
    """Setup SQLAlchemy event listeners for security audit."""
    global security_manager
    security_manager = DatabaseSecurityManager(engine)
    
    @event.listens_for(engine, "before_cursor_execute")
    def log_sql_execution(conn, cursor, statement, parameters, context, executemany):
        """Log SQL execution for audit."""
        # Only log data modification statements
        if any(keyword in statement.upper() for keyword in ['INSERT', 'UPDATE', 'DELETE']):
            context._audit_statement = statement
            context._audit_params = parameters
    
    @event.listens_for(engine, "after_cursor_execute") 
    def log_sql_completion(conn, cursor, statement, parameters, context, executemany):
        """Log SQL completion for audit."""
        if hasattr(context, '_audit_statement'):
            # Extract table name from statement
            statement_upper = context._audit_statement.upper()
            table_name = "unknown"
            
            for keyword in ['INSERT INTO', 'UPDATE', 'DELETE FROM']:
                if keyword in statement_upper:
                    parts = statement_upper.split(keyword)[1].strip().split()
                    if parts:
                        table_name = parts[0].strip('()"')
                    break
            
            logger.debug(f"SQL executed on table {table_name}: {cursor.rowcount} rows affected")

@contextmanager
def secure_session(engine: Optional[Engine] = None):
    """Context manager for secure database sessions with audit logging."""
    engine = engine or get_database_engine()
    
    # Setup security if not already done
    global security_manager
    if security_manager is None:
        setup_security_events(engine)
    
    from sqlalchemy.orm import sessionmaker
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = SessionLocal()
    
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        logger.error(f"Secure session error: {e}")
        raise
    finally:
        session.close()

# PowerShell compatibility functions
def get_powershell_security_status() -> Dict[str, Any]:
    """Get security status in PowerShell-compatible format."""
    try:
        manager = DatabaseSecurityManager()
        metrics = manager.get_security_metrics()
        
        return {
            "SecurityStatus": "Enabled" if metrics.get('encryption_active') else "Disabled",
            "SSLEnabled": metrics.get('ssl_enabled', False),
            "AuditEnabled": metrics.get('audit_enabled', False),
            "EncryptionActive": metrics.get('encryption_active', False),
            "AuditEvents": metrics.get('audit_statistics', {}).get('total_events', 0),
            "LastCheck": metrics.get('last_check', ''),
            "SecurityGrade": "A" if all([
                metrics.get('ssl_enabled'),
                metrics.get('audit_enabled'), 
                metrics.get('encryption_active')
            ]) else "B"
        }
        
    except Exception as e:
        return {
            "SecurityStatus": "Error",
            "Error": str(e),
            "LastCheck": datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        }

if __name__ == "__main__":
    # Test security functionality
    try:
        print("🔒 Testing database security functionality...")
        
        # Initialize security manager
        manager = DatabaseSecurityManager()
        
        # Test encryption
        test_data = {"sensitive": "information", "user_id": "test123"}
        encrypted = manager.encrypt_sensitive_data(test_data)
        print(f"✅ Data encrypted: {len(encrypted)} characters")
        
        # Test decryption
        decrypted = manager.decrypt_sensitive_data(encrypted)
        print(f"✅ Data decrypted: {decrypted}")
        
        # Test hashing
        test_password = "test_password_123"
        hash_value, salt = manager.hash_sensitive_field(test_password)
        print(f"✅ Password hashed: {len(hash_value)} characters")
        
        # Test hash verification
        is_valid = manager.verify_hashed_field(test_password, hash_value, salt)
        print(f"✅ Hash verification: {'Valid' if is_valid else 'Invalid'}")
        
        # Get security status
        status = get_powershell_security_status()
        print(f"📊 Security status: {status}")
        
        print("✅ Database security test completed successfully")
        
    except Exception as e:
        print(f"❌ Database security test failed: {e}")