"""
Microsoft 365管理ツール データベース接続モジュール
===============================================

非同期PostgreSQL接続・SQLAlchemy統合
- PowerShell CSV/JSONデータ互換性
- 高パフォーマンス非同期処理  
- コネクションプール最適化
- エラーハンドリング・再試行ロジック
"""

import os
import logging
import asyncio
from typing import AsyncGenerator, Optional, Dict, Any
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncSession, AsyncEngine, create_async_engine,
    async_sessionmaker, async_scoped_session
)
from sqlalchemy.pool import QueuePool
from sqlalchemy.exc import SQLAlchemyError, OperationalError
from sqlalchemy import text, event
import asyncpg

logger = logging.getLogger(__name__)


# データベース設定
class DatabaseConfig:
    """データベース設定管理"""
    
    def __init__(self):
        # 環境変数から設定取得
        self.database_url = os.getenv(
            'DATABASE_URL',
            'postgresql+asyncpg://ms365_user:password@localhost:5432/ms365_management'
        )
        
        # 接続プール設定
        self.pool_size = int(os.getenv('DB_POOL_SIZE', '20'))
        self.max_overflow = int(os.getenv('DB_MAX_OVERFLOW', '30'))
        self.pool_timeout = int(os.getenv('DB_POOL_TIMEOUT', '30'))
        self.pool_recycle = int(os.getenv('DB_POOL_RECYCLE', '3600'))
        
        # 接続タイムアウト設定
        self.connect_timeout = int(os.getenv('DB_CONNECT_TIMEOUT', '60'))
        self.command_timeout = int(os.getenv('DB_COMMAND_TIMEOUT', '60'))
        
        # リトライ設定
        self.max_retries = int(os.getenv('DB_MAX_RETRIES', '3'))
        self.retry_delay = float(os.getenv('DB_RETRY_DELAY', '1.0'))
        
        # ログ設定
        self.echo = os.getenv('DB_ECHO', 'false').lower() == 'true'


# グローバル設定インスタンス
db_config = DatabaseConfig()

# エンジン作成
def create_database_engine() -> AsyncEngine:
    """非同期データベースエンジン作成"""
    
    # asyncpg接続パラメータ
    connect_args = {
        "server_settings": {
            "jit": "off",  # JITコンパイルを無効化（安定性向上）
            "application_name": "Microsoft365ManagementAPI",
        },
        "command_timeout": db_config.command_timeout,
        "timeout": db_config.connect_timeout,
    }
    
    engine = create_async_engine(
        db_config.database_url,
        
        # 接続プール設定
        poolclass=QueuePool,
        pool_size=db_config.pool_size,
        max_overflow=db_config.max_overflow,
        pool_timeout=db_config.pool_timeout,
        pool_recycle=db_config.pool_recycle,
        pool_pre_ping=True,  # 接続前の健全性チェック
        
        # 非同期設定
        connect_args=connect_args,
        
        # ログ設定
        echo=db_config.echo,
        echo_pool=False,
        
        # その他設定
        future=True,  # SQLAlchemy 2.0スタイル
    )
    
    # 接続イベントリスナー
    @event.listens_for(engine.sync_engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        """接続時の設定（PostgreSQL用）"""
        pass  # PostgreSQLでは不要だが拡張可能
    
    return engine


# グローバルエンジン
engine: AsyncEngine = create_database_engine()

# セッション作成
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


# 依存性注入用セッション取得
async def get_async_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI依存性注入用の非同期セッション取得"""
    session = AsyncSessionLocal()
    try:
        yield session
    except Exception as e:
        await session.rollback()
        logger.error(f"データベースセッションエラー: {e}")
        raise
    finally:
        await session.close()


# リトライ付きデータベース操作
async def execute_with_retry(
    session: AsyncSession,
    query: str,
    params: Optional[Dict[str, Any]] = None,
    max_retries: Optional[int] = None
) -> Any:
    """
    リトライ付きクエリ実行
    PowerShell Invoke-GraphAPIWithRetry互換
    """
    if max_retries is None:
        max_retries = db_config.max_retries
    
    last_error = None
    
    for attempt in range(max_retries + 1):
        try:
            if params:
                result = await session.execute(text(query), params)
            else:
                result = await session.execute(text(query))
            
            logger.debug(f"クエリ実行成功 (試行 {attempt + 1}): {query[:100]}...")
            return result
            
        except (OperationalError, asyncpg.PostgresConnectionError) as e:
            last_error = e
            logger.warning(f"データベース接続エラー (試行 {attempt + 1}): {e}")
            
            if attempt < max_retries:
                delay = db_config.retry_delay * (2 ** attempt)  # 指数バックオフ
                logger.info(f"{delay}秒後にリトライします...")
                await asyncio.sleep(delay)
                continue
            else:
                logger.error(f"最大リトライ回数に到達: {e}")
                raise
                
        except SQLAlchemyError as e:
            logger.error(f"SQLAlchemyエラー: {e}")
            raise
        except Exception as e:
            logger.error(f"予期しないデータベースエラー: {e}")
            raise
    
    if last_error:
        raise last_error


# 接続状態確認
async def test_database_connection() -> Dict[str, Any]:
    """
    データベース接続テスト
    PowerShell Test-AuthenticationStatus互換
    """
    status = {
        "connected": False,
        "version": None,
        "latency_ms": None,
        "error": None
    }
    
    try:
        import time
        start_time = time.time()
        
        async with AsyncSessionLocal() as session:
            # PostgreSQLバージョン確認
            result = await session.execute(text("SELECT version()"))
            version = result.scalar()
            status["version"] = version
            
            # 接続確認
            await session.execute(text("SELECT 1"))
            
            # レイテンシ計算
            end_time = time.time()
            status["latency_ms"] = int((end_time - start_time) * 1000)
            status["connected"] = True
            
            logger.info(f"データベース接続成功 - レイテンシ: {status['latency_ms']}ms")
            
    except Exception as e:
        status["error"] = str(e)
        logger.error(f"データベース接続テスト失敗: {e}")
    
    return status


# PowerShell CSV/JSON データ移行ヘルパー
@asynccontextmanager
async def get_migration_session():
    """データ移行専用セッション"""
    # 移行用の大容量処理設定
    migration_engine = create_async_engine(
        db_config.database_url,
        pool_size=5,  # 移行中は接続数を制限
        max_overflow=10,
        echo=db_config.echo
    )
    
    Migration_SessionLocal = async_sessionmaker(
        migration_engine,
        class_=AsyncSession,
        expire_on_commit=False
    )
    
    session = Migration_SessionLocal()
    try:
        yield session
    except Exception as e:
        await session.rollback()
        logger.error(f"データ移行セッションエラー: {e}")
        raise
    finally:
        await session.close()
        await migration_engine.dispose()


# バッチ処理用セッション管理
class BatchProcessor:
    """大量データ処理用バッチプロセッサー"""
    
    def __init__(self, batch_size: int = 1000):
        self.batch_size = batch_size
        self.processed_count = 0
        
    async def process_batch(
        self,
        session: AsyncSession,
        data_batch: list,
        table_class,
        on_conflict_action: str = "update"
    ):
        """バッチデータ処理"""
        try:
            # バッチ挿入/更新
            if on_conflict_action == "update":
                # PostgreSQL UPSERT (ON CONFLICT DO UPDATE)
                await session.execute(
                    table_class.__table__.insert().values(data_batch).
                    on_conflict_do_update(
                        constraint=f"{table_class.__tablename__}_pkey",
                        set_=dict(
                            updated_at=text("CURRENT_TIMESTAMP")
                        )
                    )
                )
            else:
                # 通常の挿入
                await session.execute(
                    table_class.__table__.insert().values(data_batch)
                )
            
            await session.commit()
            self.processed_count += len(data_batch)
            
            logger.info(f"バッチ処理完了: {len(data_batch)}件 (累計: {self.processed_count}件)")
            
        except Exception as e:
            await session.rollback()
            logger.error(f"バッチ処理エラー: {e}")
            raise


# データベース統計情報取得
async def get_database_statistics() -> Dict[str, Any]:
    """データベース統計情報取得（監視・最適化用）"""
    stats = {}
    
    try:
        async with AsyncSessionLocal() as session:
            # テーブル統計
            table_stats_query = """
            SELECT 
                schemaname,
                tablename,
                n_live_tup as row_count,
                n_dead_tup as dead_rows,
                pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
            FROM pg_stat_user_tables 
            ORDER BY n_live_tup DESC;
            """
            
            result = await session.execute(text(table_stats_query))
            table_stats = [dict(row) for row in result]
            stats["table_statistics"] = table_stats
            
            # インデックス統計
            index_stats_query = """
            SELECT 
                schemaname,
                tablename,
                indexname,
                idx_scan as scans,
                idx_tup_read as tuples_read,
                idx_tup_fetch as tuples_fetched
            FROM pg_stat_user_indexes 
            ORDER BY idx_scan DESC;
            """
            
            result = await session.execute(text(index_stats_query))
            index_stats = [dict(row) for row in result]
            stats["index_statistics"] = index_stats
            
            # 接続統計
            conn_stats_query = """
            SELECT 
                count(*) as total_connections,
                count(*) FILTER (WHERE state = 'active') as active_connections,
                count(*) FILTER (WHERE state = 'idle') as idle_connections
            FROM pg_stat_activity 
            WHERE datname = current_database();
            """
            
            result = await session.execute(text(conn_stats_query))
            conn_stats = dict(result.fetchone())
            stats["connection_statistics"] = conn_stats
            
            logger.info("データベース統計情報取得完了")
            
    except Exception as e:
        logger.error(f"データベース統計取得エラー: {e}")
        stats["error"] = str(e)
    
    return stats


# ヘルスチェック機能
async def health_check() -> Dict[str, Any]:
    """包括的データベースヘルスチェック"""
    health = {
        "status": "unknown",
        "timestamp": None,
        "connection": {},
        "performance": {},
        "errors": []
    }
    
    try:
        import time
        from datetime import datetime
        
        health["timestamp"] = datetime.utcnow().isoformat()
        
        # 基本接続確認
        connection_test = await test_database_connection()
        health["connection"] = connection_test
        
        if not connection_test["connected"]:
            health["status"] = "unhealthy"
            health["errors"].append("データベース接続失敗")
            return health
        
        # パフォーマンステスト
        start_time = time.time()
        
        async with AsyncSessionLocal() as session:
            # 簡単なクエリテスト
            await session.execute(text("SELECT COUNT(*) FROM pg_stat_user_tables"))
            
            # 複雑なクエリテスト（実際のテーブルが存在する場合）
            try:
                await session.execute(text("SELECT COUNT(*) FROM users LIMIT 1"))
                health["performance"]["users_table"] = "accessible"
            except:
                health["performance"]["users_table"] = "not_created_yet"
        
        query_time = (time.time() - start_time) * 1000
        health["performance"]["query_response_ms"] = int(query_time)
        
        # 全体ステータス判定
        if query_time > 1000:  # 1秒以上
            health["status"] = "degraded"
            health["errors"].append("クエリ応答時間が遅い")
        else:
            health["status"] = "healthy"
            
    except Exception as e:
        health["status"] = "unhealthy"
        health["errors"].append(f"ヘルスチェックエラー: {str(e)}")
        logger.error(f"データベースヘルスチェック失敗: {e}")
    
    return health


# クリーンアップ関数
async def cleanup_database_connections():
    """データベース接続クリーンアップ"""
    try:
        await engine.dispose()
        logger.info("データベース接続プールクリーンアップ完了")
    except Exception as e:
        logger.error(f"データベースクリーンアップエラー: {e}")


if __name__ == "__main__":
    # テスト実行
    async def test_connection():
        logger.info("データベース接続テスト開始")
        
        # 接続テスト
        test_result = await test_database_connection()
        print(f"接続テスト結果: {test_result}")
        
        # ヘルスチェック
        health_result = await health_check()
        print(f"ヘルスチェック結果: {health_result}")
        
        # 統計情報
        stats = await get_database_statistics()
        print(f"統計情報: {stats}")
        
        # クリーンアップ
        await cleanup_database_connections()
    
    asyncio.run(test_connection())