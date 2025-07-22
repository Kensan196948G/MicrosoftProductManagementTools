# Microsoft 365 Management Tools - Database Performance Optimization
# Advanced indexing, query optimization, and monitoring for enterprise workloads

import os
import logging
import time
from typing import Optional, Dict, Any, List, Union, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from contextlib import contextmanager
from sqlalchemy import text, inspect, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session
from sqlalchemy.sql import func
import psutil

from .engine import get_database_engine, get_session
from .models import Base

# Configure logging
logger = logging.getLogger(__name__)

# Performance configuration
PERFORMANCE_CONFIG = {
    'slow_query_threshold': float(os.getenv('SLOW_QUERY_THRESHOLD', '1.0')),  # seconds
    'connection_pool_size': int(os.getenv('CONNECTION_POOL_SIZE', '20')),
    'max_overflow': int(os.getenv('CONNECTION_MAX_OVERFLOW', '30')),
    'query_timeout': int(os.getenv('QUERY_TIMEOUT', '60')),
    'enable_query_logging': os.getenv('ENABLE_QUERY_LOGGING', 'false').lower() == 'true',
    'enable_performance_monitoring': os.getenv('ENABLE_PERFORMANCE_MONITORING', 'true').lower() == 'true',
    'maintenance_hour': int(os.getenv('DB_MAINTENANCE_HOUR', '3')),  # 3 AM
    'vacuum_threshold_percent': int(os.getenv('VACUUM_THRESHOLD_PERCENT', '20')),
    'analyze_threshold_percent': int(os.getenv('ANALYZE_THRESHOLD_PERCENT', '10'))
}

@dataclass
class QueryPerformanceMetrics:
    """Query performance metrics data class."""
    query: str
    execution_time: float
    rows_examined: int
    rows_returned: int
    timestamp: datetime
    table_name: Optional[str] = None
    index_used: Optional[str] = None

@dataclass
class TableStatistics:
    """Table statistics data class."""
    table_name: str
    row_count: int
    table_size_bytes: int
    index_size_bytes: int
    last_vacuum: Optional[datetime]
    last_analyze: Optional[datetime]
    seq_scan: int
    seq_tup_read: int
    idx_scan: int
    idx_tup_fetch: int

class DatabasePerformanceOptimizer:
    """Enterprise database performance optimization manager."""
    
    def __init__(self, engine: Optional[Engine] = None):
        self.engine = engine or get_database_engine()
        self.slow_queries = []
        self.query_stats = {}
        self._setup_performance_monitoring()
    
    def _setup_performance_monitoring(self):
        """Setup performance monitoring event listeners."""
        if not PERFORMANCE_CONFIG['enable_performance_monitoring']:
            return
        
        @event.listens_for(self.engine, "before_cursor_execute")
        def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            """Record query start time."""
            context._query_start_time = time.time()
            context._query_statement = statement
        
        @event.listens_for(self.engine, "after_cursor_execute")
        def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            """Record query performance metrics."""
            if hasattr(context, '_query_start_time'):
                execution_time = time.time() - context._query_start_time
                
                # Log slow queries
                if execution_time > PERFORMANCE_CONFIG['slow_query_threshold']:
                    self._log_slow_query(statement, execution_time, cursor.rowcount)
                
                # Update query statistics
                self._update_query_stats(statement, execution_time, cursor.rowcount)
    
    def _log_slow_query(self, query: str, execution_time: float, row_count: int):
        """Log slow query for analysis."""
        slow_query = QueryPerformanceMetrics(
            query=query[:500],  # Truncate long queries
            execution_time=execution_time,
            rows_examined=row_count,
            rows_returned=row_count,
            timestamp=datetime.utcnow()
        )
        
        self.slow_queries.append(slow_query)
        
        # Keep only last 100 slow queries
        if len(self.slow_queries) > 100:
            self.slow_queries = self.slow_queries[-100:]
        
        logger.warning(f"Slow query detected: {execution_time:.3f}s - {query[:100]}...")
    
    def _update_query_stats(self, query: str, execution_time: float, row_count: int):
        """Update query statistics."""
        # Extract query type
        query_type = query.strip().split()[0].upper() if query.strip() else 'UNKNOWN'
        
        if query_type not in self.query_stats:
            self.query_stats[query_type] = {
                'count': 0,
                'total_time': 0.0,
                'avg_time': 0.0,
                'max_time': 0.0,
                'total_rows': 0
            }
        
        stats = self.query_stats[query_type]
        stats['count'] += 1
        stats['total_time'] += execution_time
        stats['avg_time'] = stats['total_time'] / stats['count']
        stats['max_time'] = max(stats['max_time'], execution_time)
        stats['total_rows'] += row_count
    
    def create_advanced_indexes(self) -> Dict[str, Any]:
        """Create advanced indexes for Microsoft 365 data optimization."""
        try:
            with self.engine.connect() as conn:
                # Performance-optimized indexes for Microsoft 365 workloads
                indexes = [
                    # User management indexes
                    {
                        'name': 'idx_users_upn_status_dept',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_upn_status_dept 
                        ON users(user_principal_name, account_status, department) 
                        WHERE account_status = '有効'
                        """,
                        'description': 'Optimized user lookup with status filter'
                    },
                    
                    # Sign-in log performance indexes
                    {
                        'name': 'idx_signin_logs_composite',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signin_logs_composite 
                        ON signin_logs(signin_datetime DESC, user_principal_name, status) 
                        INCLUDE (application, ip_address)
                        """,
                        'description': 'Composite index for signin analysis'
                    },
                    
                    # Mailbox usage optimization
                    {
                        'name': 'idx_mailboxes_usage_optimization',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mailboxes_usage_optimization 
                        ON mailboxes(mailbox_type, usage_percent) 
                        WHERE usage_percent > 80
                        """,
                        'description': 'High usage mailbox identification'
                    },
                    
                    # Teams usage analytics
                    {
                        'name': 'idx_teams_usage_analytics',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_teams_usage_analytics 
                        ON teams_usage(report_date DESC, user_principal_name) 
                        INCLUDE (chat_messages_count, meetings_organized, activity_score)
                        """,
                        'description': 'Teams usage analytics optimization'
                    },
                    
                    # OneDrive storage analysis
                    {
                        'name': 'idx_onedrive_storage_analysis',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_onedrive_storage_analysis 
                        ON onedrive_storage_analysis(report_date DESC, usage_percent) 
                        WHERE usage_percent > 70
                        """,
                        'description': 'OneDrive high usage detection'
                    },
                    
                    # License analysis optimization
                    {
                        'name': 'idx_license_analysis_optimization',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_license_analysis_optimization 
                        ON license_analysis(license_type, department, report_date DESC) 
                        INCLUDE (utilization_rate, monthly_cost)
                        """,
                        'description': 'License utilization and cost analysis'
                    },
                    
                    # Performance monitoring indexes
                    {
                        'name': 'idx_performance_monitoring_time_series',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_performance_monitoring_time_series 
                        ON performance_monitoring(service_name, timestamp DESC, status) 
                        INCLUDE (response_time_ms, availability_percent)
                        """,
                        'description': 'Time series performance data optimization'
                    },
                    
                    # Security analysis indexes
                    {
                        'name': 'idx_security_analysis_risk',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_analysis_risk 
                        ON security_analysis(risk_level, security_item, report_date DESC) 
                        WHERE risk_level IN ('中', '高')
                        """,
                        'description': 'High risk security item identification'
                    },
                    
                    # MFA status optimization
                    {
                        'name': 'idx_mfa_status_optimization',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mfa_status_optimization 
                        ON mfa_status(mfa_status, department, user_principal_name) 
                        WHERE mfa_status IN ('無効', '要設定')
                        """,
                        'description': 'MFA compliance monitoring'
                    },
                    
                    # Report metadata optimization
                    {
                        'name': 'idx_report_metadata_generation',
                        'sql': """
                        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_report_metadata_generation 
                        ON report_metadata(report_type, generation_time DESC, status) 
                        INCLUDE (record_count, data_source)
                        """,
                        'description': 'Report generation tracking'
                    }
                ]
                
                results = []
                for index in indexes:
                    try:
                        conn.execute(text(index['sql']))
                        results.append({
                            'name': index['name'],
                            'status': 'created',
                            'description': index['description']
                        })
                        logger.info(f"Created index: {index['name']}")
                    except Exception as e:
                        results.append({
                            'name': index['name'],
                            'status': 'error',
                            'error': str(e),
                            'description': index['description']
                        })
                        logger.error(f"Failed to create index {index['name']}: {e}")
                
                conn.commit()
                
                return {
                    'status': 'completed',
                    'indexes_processed': len(indexes),
                    'indexes_created': len([r for r in results if r['status'] == 'created']),
                    'results': results
                }
                
        except Exception as e:
            logger.error(f"Advanced index creation failed: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def optimize_query_performance(self) -> Dict[str, Any]:
        """Perform comprehensive query performance optimization."""
        try:
            optimizations = []
            
            with self.engine.connect() as conn:
                # Update table statistics
                optimizations.append(self._update_table_statistics(conn))
                
                # Analyze query plans
                optimizations.append(self._analyze_query_plans(conn))
                
                # Configure PostgreSQL performance settings
                optimizations.append(self._configure_postgres_settings(conn))
                
                # Clean up unused indexes
                optimizations.append(self._cleanup_unused_indexes(conn))
                
                conn.commit()
            
            return {
                'status': 'completed',
                'optimizations': optimizations,
                'timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Query optimization failed: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def _update_table_statistics(self, conn) -> Dict[str, Any]:
        """Update table statistics for better query planning."""
        try:
            # Get all Microsoft 365 tables
            tables = [
                'users', 'mfa_status', 'signin_logs', 'mailboxes', 'mail_flow_analysis',
                'teams_usage', 'onedrive_storage_analysis', 'license_analysis',
                'performance_monitoring', 'security_analysis', 'report_metadata'
            ]
            
            updated_tables = 0
            for table in tables:
                try:
                    conn.execute(text(f"ANALYZE {table}"))
                    updated_tables += 1
                    logger.debug(f"Updated statistics for table: {table}")
                except Exception as e:
                    logger.warning(f"Failed to analyze table {table}: {e}")
            
            return {
                'operation': 'update_statistics',
                'status': 'success',
                'tables_processed': len(tables),
                'tables_updated': updated_tables
            }
            
        except Exception as e:
            return {'operation': 'update_statistics', 'status': 'error', 'error': str(e)}
    
    def _analyze_query_plans(self, conn) -> Dict[str, Any]:
        """Analyze query execution plans for optimization opportunities."""
        try:
            # Common query patterns for Microsoft 365 tools
            query_patterns = [
                {
                    'name': 'user_signin_analysis',
                    'query': """
                    SELECT u.user_principal_name, u.department, COUNT(s.id) as signin_count
                    FROM users u 
                    LEFT JOIN signin_logs s ON u.user_principal_name = s.user_principal_name 
                    WHERE s.signin_datetime >= CURRENT_DATE - INTERVAL '30 days'
                    GROUP BY u.user_principal_name, u.department
                    """
                },
                {
                    'name': 'mailbox_usage_report',
                    'query': """
                    SELECT m.email, m.usage_percent, m.total_size_mb
                    FROM mailboxes m
                    WHERE m.usage_percent > 80
                    ORDER BY m.usage_percent DESC
                    """
                },
                {
                    'name': 'teams_activity_summary',
                    'query': """
                    SELECT t.user_principal_name, t.activity_score, t.report_date
                    FROM teams_usage t
                    WHERE t.report_date >= CURRENT_DATE - INTERVAL '7 days'
                    AND t.activity_score > 0
                    ORDER BY t.activity_score DESC
                    """
                }
            ]
            
            plan_analysis = []
            for pattern in query_patterns:
                try:
                    # Get query execution plan
                    result = conn.execute(text(f"EXPLAIN (ANALYZE, BUFFERS) {pattern['query']}"))
                    plan = '\n'.join([row[0] for row in result])
                    
                    plan_analysis.append({
                        'query_name': pattern['name'],
                        'has_seq_scan': 'Seq Scan' in plan,
                        'has_index_scan': 'Index Scan' in plan,
                        'plan_snippet': plan[:200] + '...' if len(plan) > 200 else plan
                    })
                    
                except Exception as e:
                    plan_analysis.append({
                        'query_name': pattern['name'],
                        'error': str(e)
                    })
            
            return {
                'operation': 'query_plan_analysis',
                'status': 'success',
                'plans_analyzed': len(query_patterns),
                'analysis_results': plan_analysis
            }
            
        except Exception as e:
            return {'operation': 'query_plan_analysis', 'status': 'error', 'error': str(e)}
    
    def _configure_postgres_settings(self, conn) -> Dict[str, Any]:
        """Configure PostgreSQL settings for optimal performance."""
        try:
            # Get current memory and CPU info
            memory_mb = psutil.virtual_memory().total // (1024 * 1024)
            cpu_count = psutil.cpu_count()
            
            # Calculate optimal settings
            shared_buffers_mb = min(memory_mb // 4, 8192)  # 25% of RAM, max 8GB
            effective_cache_size_mb = memory_mb * 3 // 4   # 75% of RAM
            work_mem_mb = max(4, memory_mb // (cpu_count * 4))  # Dynamic work_mem
            
            # Performance settings
            settings = {
                'shared_buffers': f'{shared_buffers_mb}MB',
                'effective_cache_size': f'{effective_cache_size_mb}MB',
                'work_mem': f'{work_mem_mb}MB',
                'maintenance_work_mem': f'{min(2048, memory_mb // 16)}MB',
                'checkpoint_completion_target': '0.9',
                'wal_buffers': '16MB',
                'default_statistics_target': '100',
                'random_page_cost': '1.1',
                'effective_io_concurrency': str(min(200, cpu_count * 2))
            }
            
            applied_settings = []
            for setting, value in settings.items():
                try:
                    # Note: These settings typically require PostgreSQL restart
                    # In production, use postgresql.conf or ALTER SYSTEM
                    logger.info(f"Recommended setting: {setting} = {value}")
                    applied_settings.append(f"{setting} = {value}")
                except Exception as e:
                    logger.warning(f"Could not apply setting {setting}: {e}")
            
            return {
                'operation': 'configure_postgres',
                'status': 'success',
                'memory_mb': memory_mb,
                'cpu_count': cpu_count,
                'recommended_settings': applied_settings
            }
            
        except Exception as e:
            return {'operation': 'configure_postgres', 'status': 'error', 'error': str(e)}
    
    def _cleanup_unused_indexes(self, conn) -> Dict[str, Any]:
        """Identify and optionally remove unused indexes."""
        try:
            # Query to find unused indexes
            unused_indexes_query = """
            SELECT 
                schemaname,
                tablename,
                indexname,
                idx_tup_read,
                idx_tup_fetch
            FROM pg_stat_user_indexes 
            WHERE idx_tup_read = 0 AND idx_tup_fetch = 0
            AND indexname NOT LIKE '%_pkey'  -- Exclude primary keys
            ORDER BY schemaname, tablename, indexname
            """
            
            result = conn.execute(text(unused_indexes_query))
            unused_indexes = []
            
            for row in result:
                unused_indexes.append({
                    'schema': row[0],
                    'table': row[1],
                    'index': row[2],
                    'reads': row[3],
                    'fetches': row[4]
                })
            
            return {
                'operation': 'unused_index_analysis',
                'status': 'success',
                'unused_indexes': unused_indexes,
                'count': len(unused_indexes)
            }
            
        except Exception as e:
            return {'operation': 'unused_index_analysis', 'status': 'error', 'error': str(e)}
    
    def get_table_statistics(self) -> List[TableStatistics]:
        """Get comprehensive table statistics."""
        try:
            with self.engine.connect() as conn:
                # Query for table statistics
                stats_query = """
                SELECT 
                    schemaname,
                    tablename,
                    n_tup_ins + n_tup_upd + n_tup_del as total_changes,
                    n_live_tup as row_count,
                    pg_total_relation_size(schemaname||'.'||tablename) as table_size,
                    pg_indexes_size(schemaname||'.'||tablename) as index_size,
                    last_vacuum,
                    last_autovacuum,
                    last_analyze,
                    last_autoanalyze,
                    seq_scan,
                    seq_tup_read,
                    idx_scan,
                    idx_tup_fetch
                FROM pg_stat_user_tables 
                ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
                """
                
                result = conn.execute(text(stats_query))
                statistics = []
                
                for row in result:
                    stats = TableStatistics(
                        table_name=row[1],
                        row_count=row[3] or 0,
                        table_size_bytes=row[4] or 0,
                        index_size_bytes=row[5] or 0,
                        last_vacuum=row[6] or row[7],  # last_vacuum or last_autovacuum
                        last_analyze=row[8] or row[9], # last_analyze or last_autoanalyze
                        seq_scan=row[10] or 0,
                        seq_tup_read=row[11] or 0,
                        idx_scan=row[12] or 0,
                        idx_tup_fetch=row[13] or 0
                    )
                    statistics.append(stats)
                
                return statistics
                
        except Exception as e:
            logger.error(f"Failed to get table statistics: {e}")
            return []
    
    def run_maintenance_tasks(self) -> Dict[str, Any]:
        """Run database maintenance tasks."""
        try:
            maintenance_results = []
            
            with self.engine.connect() as conn:
                # Get table statistics to determine maintenance needs
                table_stats = self.get_table_statistics()
                
                for stats in table_stats:
                    table_name = stats.table_name
                    
                    # Check if vacuum is needed
                    if (stats.seq_scan > 100 or 
                        stats.last_vacuum is None or 
                        stats.last_vacuum < datetime.utcnow() - timedelta(days=7)):
                        
                        try:
                            conn.execute(text(f"VACUUM ANALYZE {table_name}"))
                            maintenance_results.append({
                                'table': table_name,
                                'operation': 'vacuum_analyze',
                                'status': 'success'
                            })
                            logger.info(f"Vacuum analyze completed for {table_name}")
                        except Exception as e:
                            maintenance_results.append({
                                'table': table_name,
                                'operation': 'vacuum_analyze',
                                'status': 'error',
                                'error': str(e)
                            })
                
                # Reindex if needed
                large_tables = [s for s in table_stats if s.table_size_bytes > 100 * 1024 * 1024]  # > 100MB
                for stats in large_tables:
                    if stats.idx_scan < stats.seq_scan:  # More sequential scans than index scans
                        try:
                            conn.execute(text(f"REINDEX TABLE {stats.table_name}"))
                            maintenance_results.append({
                                'table': stats.table_name,
                                'operation': 'reindex',
                                'status': 'success'
                            })
                            logger.info(f"Reindex completed for {stats.table_name}")
                        except Exception as e:
                            maintenance_results.append({
                                'table': stats.table_name,
                                'operation': 'reindex',
                                'status': 'error',
                                'error': str(e)
                            })
                
                conn.commit()
            
            return {
                'status': 'completed',
                'tasks_performed': len(maintenance_results),
                'results': maintenance_results,
                'timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Database maintenance failed: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def get_performance_metrics(self) -> Dict[str, Any]:
        """Get comprehensive performance metrics."""
        try:
            with self.engine.connect() as conn:
                # Database connection stats
                conn_stats = conn.execute(text("""
                    SELECT count(*) as total_connections,
                           sum(case when state = 'active' then 1 else 0 end) as active_connections,
                           sum(case when state = 'idle' then 1 else 0 end) as idle_connections
                    FROM pg_stat_activity
                """)).fetchone()
                
                # Database size and statistics
                db_stats = conn.execute(text("""
                    SELECT pg_size_pretty(pg_database_size(current_database())) as db_size,
                           pg_database_size(current_database()) as db_size_bytes
                """)).fetchone()
                
                # Cache hit ratio
                cache_hit = conn.execute(text("""
                    SELECT round(sum(blks_hit) * 100.0 / sum(blks_hit + blks_read), 2) as cache_hit_ratio
                    FROM pg_stat_database
                    WHERE datname = current_database()
                """)).fetchone()
                
                # Table sizes
                table_sizes = conn.execute(text("""
                    SELECT tablename,
                           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
                           pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
                    FROM pg_stat_user_tables
                    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
                    LIMIT 10
                """)).fetchall()
                
                return {
                    'connection_stats': {
                        'total_connections': conn_stats[0] if conn_stats else 0,
                        'active_connections': conn_stats[1] if conn_stats else 0,
                        'idle_connections': conn_stats[2] if conn_stats else 0
                    },
                    'database_stats': {
                        'size_pretty': db_stats[0] if db_stats else '0 bytes',
                        'size_bytes': db_stats[1] if db_stats else 0
                    },
                    'cache_performance': {
                        'cache_hit_ratio': cache_hit[0] if cache_hit else 0
                    },
                    'query_performance': {
                        'slow_query_count': len(self.slow_queries),
                        'query_stats': self.query_stats
                    },
                    'largest_tables': [
                        {
                            'table': row[0],
                            'size_pretty': row[1],
                            'size_bytes': row[2]
                        }
                        for row in table_sizes
                    ],
                    'timestamp': datetime.utcnow().isoformat()
                }
                
        except Exception as e:
            logger.error(f"Failed to get performance metrics: {e}")
            return {'error': str(e)}

# PowerShell compatibility functions
def get_powershell_performance_status() -> Dict[str, Any]:
    """Get performance status in PowerShell-compatible format."""
    try:
        optimizer = DatabasePerformanceOptimizer()
        metrics = optimizer.get_performance_metrics()
        
        return {
            "PerformanceStatus": "OPTIMAL" if metrics.get('cache_performance', {}).get('cache_hit_ratio', 0) > 95 else "NEEDS_ATTENTION",
            "CacheHitRatio": metrics.get('cache_performance', {}).get('cache_hit_ratio', 0),
            "TotalConnections": metrics.get('connection_stats', {}).get('total_connections', 0),
            "ActiveConnections": metrics.get('connection_stats', {}).get('active_connections', 0),
            "DatabaseSizeGB": round(metrics.get('database_stats', {}).get('size_bytes', 0) / (1024**3), 2),
            "SlowQueryCount": metrics.get('query_performance', {}).get('slow_query_count', 0),
            "LargestTable": metrics.get('largest_tables', [{}])[0].get('table', 'None') if metrics.get('largest_tables') else 'None',
            "LastCheck": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
    except Exception as e:
        return {
            "PerformanceStatus": "ERROR",
            "Error": str(e),
            "LastCheck": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }

if __name__ == "__main__":
    # Test performance optimization functionality
    try:
        print("⚡ Testing database performance optimization...")
        
        # Initialize optimizer
        optimizer = DatabasePerformanceOptimizer()
        
        # Create advanced indexes
        print("Creating advanced indexes...")
        index_result = optimizer.create_advanced_indexes()
        print(f"Index creation result: {index_result['status']}")
        print(f"Indexes created: {index_result.get('indexes_created', 0)}")
        
        # Get performance metrics
        print("Getting performance metrics...")
        metrics = optimizer.get_performance_metrics()
        if 'error' not in metrics:
            print(f"Cache hit ratio: {metrics['cache_performance']['cache_hit_ratio']}%")
            print(f"Database size: {metrics['database_stats']['size_pretty']}")
        
        # Get PowerShell status
        ps_status = get_powershell_performance_status()
        print(f"🔗 PowerShell status: {ps_status}")
        
        print("✅ Database performance optimization test completed successfully")
        
    except Exception as e:
        print(f"❌ Database performance test failed: {e}")