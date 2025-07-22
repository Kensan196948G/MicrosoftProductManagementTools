"""
Microsoft 365管理ツール データベース最適化
=========================================

本番システム向けデータベース最適化
- インデックス最適化・クエリチューニング
- 接続プール管理・トランザクション最適化
- パーティショニング・キャッシング戦略
- パフォーマンス監視・自動最適化
"""

import asyncio
import logging
from typing import List, Dict, Any, Optional
from sqlalchemy import text, Index, inspect
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.pool import QueuePool
from datetime import datetime, timedelta
import json

logger = logging.getLogger(__name__)


class DatabaseOptimizer:
    """本番データベース最適化クラス"""
    
    # 推奨インデックス設定
    RECOMMENDED_INDEXES = [
        {
            "table": "users",
            "columns": ["user_principal_name", "account_status"],
            "unique": True,
            "priority": "high"
        },
        {
            "table": "users", 
            "columns": ["department", "creation_date"],
            "unique": False,
            "priority": "medium"
        },
        {
            "table": "mailboxes",
            "columns": ["email", "usage_percent"],
            "unique": True,
            "priority": "high"
        },
        {
            "table": "mailboxes",
            "columns": ["mailbox_type", "total_size_mb"],
            "unique": False,
            "priority": "medium"
        },
        {
            "table": "signin_logs",
            "columns": ["user_id", "signin_time"],
            "unique": False,
            "priority": "high"
        },
        {
            "table": "signin_logs",
            "columns": ["signin_time", "status"],
            "unique": False,
            "priority": "medium"
        },
        {
            "table": "teams_usage",
            "columns": ["user_id", "usage_date"],
            "unique": False,
            "priority": "high"
        },
        {
            "table": "onedrive_usage",
            "columns": ["user_id", "storage_used_gb"],
            "unique": False,
            "priority": "medium"
        },
        {
            "table": "performance_metrics",
            "columns": ["endpoint", "timestamp"],
            "unique": False,
            "priority": "high"
        }
    ]
    
    # パーティション戦略
    PARTITION_STRATEGIES = [
        {
            "table": "signin_logs",
            "strategy": "time_based",
            "column": "signin_time",
            "interval": "monthly",
            "retention": "12_months"
        },
        {
            "table": "performance_metrics",
            "strategy": "time_based", 
            "column": "timestamp",
            "interval": "daily",
            "retention": "3_months"
        },
        {
            "table": "audit_logs",
            "strategy": "time_based",
            "column": "created_at",
            "interval": "monthly",
            "retention": "24_months"
        }
    ]
    
    def __init__(self, database_url: str):
        """データベース最適化初期化"""
        # 本番向け接続プール設定
        self.engine = create_async_engine(
            database_url,
            # 接続プール最適化
            poolclass=QueuePool,
            pool_size=20,          # 基本接続数
            max_overflow=50,       # 最大追加接続数
            pool_pre_ping=True,    # 接続ヘルスチェック
            pool_recycle=3600,     # 接続リサイクル時間（1時間）
            
            # パフォーマンス設定
            echo=False,            # 本番ではSQLログ無効
            future=True,           # SQLAlchemy 2.0スタイル
            
            # 接続オプション
            connect_args={
                "server_settings": {
                    "application_name": "MS365_Management_API",
                    "jit": "off",                    # JITコンパイル無効（安定性優先）
                },
                "command_timeout": 60,
                "statement_timeout": 300000,         # 5分タイムアウト
            }
        )
        
        # 最適化統計
        self.optimization_stats = {
            "indexes_created": 0,
            "queries_optimized": 0,
            "partitions_created": 0,
            "performance_improvement": 0.0
        }
    
    async def execute_full_optimization(self, session: AsyncSession) -> Dict[str, Any]:
        """完全最適化実行"""
        logger.info("本番データベース最適化開始")
        
        start_time = datetime.utcnow()
        results = {}
        
        try:
            # 1. インデックス最適化
            index_results = await self._optimize_indexes(session)
            results["index_optimization"] = index_results
            
            # 2. クエリ最適化
            query_results = await self._optimize_queries(session)
            results["query_optimization"] = query_results
            
            # 3. パーティション最適化
            partition_results = await self._optimize_partitions(session)
            results["partition_optimization"] = partition_results
            
            # 4. 統計更新
            stats_results = await self._update_statistics(session)
            results["statistics_update"] = stats_results
            
            # 5. 設定最適化
            config_results = await self._optimize_configuration(session)
            results["configuration_optimization"] = config_results
            
            # 6. パフォーマンス測定
            performance_results = await self._measure_performance(session)
            results["performance_metrics"] = performance_results
            
            execution_time = (datetime.utcnow() - start_time).total_seconds()
            results["total_execution_time"] = execution_time
            results["optimization_completed"] = True
            
            logger.info(f"データベース最適化完了: {execution_time:.2f}秒")
            
        except Exception as e:
            logger.error(f"データベース最適化エラー: {e}")
            results["error"] = str(e)
            results["optimization_completed"] = False
        
        return results
    
    async def _optimize_indexes(self, session: AsyncSession) -> Dict[str, Any]:
        """インデックス最適化"""
        results = {"created": [], "analyzed": [], "dropped": []}
        
        try:
            # 既存インデックス分析
            existing_indexes = await self._analyze_existing_indexes(session)
            results["analyzed"] = existing_indexes
            
            # 推奨インデックス作成
            for index_config in self.RECOMMENDED_INDEXES:
                try:
                    created = await self._create_index_if_not_exists(session, index_config)
                    if created:
                        results["created"].append(index_config)
                        self.optimization_stats["indexes_created"] += 1
                
                except Exception as e:
                    logger.warning(f"インデックス作成エラー {index_config}: {e}")
            
            # 未使用インデックスの削除
            dropped_indexes = await self._drop_unused_indexes(session)
            results["dropped"] = dropped_indexes
            
        except Exception as e:
            logger.error(f"インデックス最適化エラー: {e}")
            results["error"] = str(e)
        
        return results
    
    async def _analyze_existing_indexes(self, session: AsyncSession) -> List[Dict[str, Any]]:
        """既存インデックス分析"""
        query = text("""
        SELECT 
            schemaname,
            tablename,
            indexname,
            indexdef,
            pg_size_pretty(pg_relation_size(indexrelid)) as size,
            idx_scan as usage_count,
            idx_tup_read,
            idx_tup_fetch
        FROM pg_indexes 
        JOIN pg_stat_user_indexes USING (indexrelname)
        WHERE schemaname = 'public'
        ORDER BY usage_count DESC
        """)
        
        result = await session.execute(query)
        indexes = []
        
        for row in result:
            indexes.append({
                "schema": row.schemaname,
                "table": row.tablename,
                "name": row.indexname,
                "definition": row.indexdef,
                "size": row.size,
                "usage_count": row.usage_count,
                "tuples_read": row.idx_tup_read,
                "tuples_fetch": row.idx_tup_fetch
            })
        
        return indexes
    
    async def _create_index_if_not_exists(self, session: AsyncSession, index_config: Dict) -> bool:
        """インデックス作成（存在しない場合）"""
        table_name = index_config["table"]
        columns = index_config["columns"]
        unique = index_config.get("unique", False)
        
        index_name = f"idx_{table_name}_{'_'.join(columns)}"
        
        # 存在確認
        check_query = text("""
        SELECT 1 FROM pg_indexes 
        WHERE tablename = :table_name AND indexname = :index_name
        """)
        
        result = await session.execute(
            check_query, 
            {"table_name": table_name, "index_name": index_name}
        )
        
        if result.fetchone():
            logger.info(f"インデックス既存: {index_name}")
            return False
        
        # インデックス作成
        unique_keyword = "UNIQUE" if unique else ""
        columns_str = ", ".join(columns)
        
        create_query = text(f"""
        CREATE {unique_keyword} INDEX CONCURRENTLY {index_name} 
        ON {table_name} ({columns_str})
        """)
        
        await session.execute(create_query)
        await session.commit()
        
        logger.info(f"インデックス作成完了: {index_name}")
        return True
    
    async def _drop_unused_indexes(self, session: AsyncSession) -> List[str]:
        """未使用インデックス削除"""
        # 使用頻度が極めて低いインデックスを特定
        query = text("""
        SELECT indexname, idx_scan
        FROM pg_stat_user_indexes
        WHERE schemaname = 'public'
        AND idx_scan < 10  -- 10回未満の使用
        AND indexname NOT LIKE '%_pkey'  -- 主キーは除外
        AND indexname NOT LIKE '%_unique'  -- ユニーク制約は除外
        """)
        
        result = await session.execute(query)
        dropped = []
        
        for row in result:
            index_name = row.indexname
            try:
                drop_query = text(f"DROP INDEX CONCURRENTLY {index_name}")
                await session.execute(drop_query)
                await session.commit()
                
                dropped.append(index_name)
                logger.info(f"未使用インデックス削除: {index_name}")
                
            except Exception as e:
                logger.warning(f"インデックス削除失敗 {index_name}: {e}")
        
        return dropped
    
    async def _optimize_queries(self, session: AsyncSession) -> Dict[str, Any]:
        """クエリ最適化"""
        results = {"optimized_queries": [], "slow_queries": []}
        
        try:
            # スロークエリ分析
            slow_queries = await self._analyze_slow_queries(session)
            results["slow_queries"] = slow_queries
            
            # クエリプラン最適化
            for query_info in slow_queries[:5]:  # 上位5件を最適化
                optimized = await self._optimize_query_plan(session, query_info)
                if optimized:
                    results["optimized_queries"].append(query_info)
                    self.optimization_stats["queries_optimized"] += 1
            
            # バキューム・解析実行
            vacuum_results = await self._execute_maintenance(session)
            results["maintenance"] = vacuum_results
            
        except Exception as e:
            logger.error(f"クエリ最適化エラー: {e}")
            results["error"] = str(e)
        
        return results
    
    async def _analyze_slow_queries(self, session: AsyncSession) -> List[Dict[str, Any]]:
        """スロークエリ分析"""
        query = text("""
        SELECT 
            query,
            calls,
            total_time,
            mean_time,
            max_time,
            stddev_time,
            rows,
            100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
        FROM pg_stat_statements
        WHERE mean_time > 100  -- 100ms以上
        ORDER BY mean_time DESC
        LIMIT 20
        """)
        
        try:
            result = await session.execute(query)
            slow_queries = []
            
            for row in result:
                slow_queries.append({
                    "query": row.query[:200] + "..." if len(row.query) > 200 else row.query,
                    "calls": row.calls,
                    "total_time": row.total_time,
                    "mean_time": row.mean_time,
                    "max_time": row.max_time,
                    "hit_percent": row.hit_percent or 0
                })
            
            return slow_queries
            
        except Exception as e:
            logger.warning(f"スロークエリ分析スキップ（pg_stat_statements未有効）: {e}")
            return []
    
    async def _optimize_query_plan(self, session: AsyncSession, query_info: Dict) -> bool:
        """クエリプラン最適化"""
        try:
            # クエリプラン分析
            explain_query = f"EXPLAIN (ANALYZE, BUFFERS) {query_info['query']}"
            result = await session.execute(text(explain_query))
            
            plan_lines = [row[0] for row in result]
            
            # シーケンシャルスキャン検出
            sequential_scans = [line for line in plan_lines if "Seq Scan" in line]
            
            if sequential_scans:
                logger.warning(f"シーケンシャルスキャン検出: {len(sequential_scans)}件")
                # インデックス提案をログ出力
                for scan in sequential_scans:
                    logger.info(f"インデックス推奨: {scan}")
            
            return len(sequential_scans) == 0
            
        except Exception as e:
            logger.error(f"クエリプラン最適化エラー: {e}")
            return False
    
    async def _execute_maintenance(self, session: AsyncSession) -> Dict[str, Any]:
        """データベースメンテナンス実行"""
        results = {"vacuum": [], "analyze": []}
        
        # 主要テーブルのバキューム・解析
        main_tables = ["users", "mailboxes", "signin_logs", "teams_usage", "onedrive_usage"]
        
        for table in main_tables:
            try:
                # VACUUM ANALYZE実行
                vacuum_query = text(f"VACUUM ANALYZE {table}")
                await session.execute(vacuum_query)
                await session.commit()
                
                results["vacuum"].append(table)
                logger.info(f"VACUUM ANALYZE完了: {table}")
                
            except Exception as e:
                logger.error(f"VACUUM ANALYZE失敗 {table}: {e}")
        
        return results
    
    async def _optimize_partitions(self, session: AsyncSession) -> Dict[str, Any]:
        """パーティション最適化"""
        results = {"created": [], "analyzed": []}
        
        for partition_config in self.PARTITION_STRATEGIES:
            try:
                created = await self._create_partition_if_needed(session, partition_config)
                if created:
                    results["created"].append(partition_config["table"])
                    self.optimization_stats["partitions_created"] += 1
                
            except Exception as e:
                logger.error(f"パーティション作成エラー {partition_config['table']}: {e}")
        
        return results
    
    async def _create_partition_if_needed(self, session: AsyncSession, config: Dict) -> bool:
        """必要に応じてパーティション作成"""
        table_name = config["table"]
        
        # テーブル存在確認
        check_query = text("""
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = :table_name
        """)
        
        result = await session.execute(check_query, {"table_name": table_name})
        if not result.fetchone():
            logger.info(f"テーブル未存在: {table_name}")
            return False
        
        # パーティション戦略に応じた処理
        if config["strategy"] == "time_based":
            return await self._create_time_based_partition(session, config)
        
        return False
    
    async def _create_time_based_partition(self, session: AsyncSession, config: Dict) -> bool:
        """時間ベースパーティション作成"""
        table_name = config["table"]
        column = config["column"]
        interval = config["interval"]
        
        # 既存パーティション確認
        partition_query = text("""
        SELECT schemaname, tablename, partitionbounds
        FROM pg_partitions
        WHERE schemaname = 'public' AND tablename LIKE :pattern
        """)
        
        result = await session.execute(
            partition_query, 
            {"pattern": f"{table_name}_%"}
        )
        
        existing_partitions = result.fetchall()
        
        if existing_partitions:
            logger.info(f"パーティション既存: {table_name}")
            return False
        
        # パーティションテーブル作成例（月次パーティション）
        if interval == "monthly":
            current_date = datetime.utcnow().replace(day=1)
            
            for i in range(12):  # 今後12ヶ月分作成
                partition_date = current_date + timedelta(days=32*i)
                partition_name = f"{table_name}_{partition_date.strftime('%Y_%m')}"
                
                try:
                    # パーティション作成（例：PostgreSQL 10+）
                    create_partition_query = text(f"""
                    CREATE TABLE {partition_name} PARTITION OF {table_name}
                    FOR VALUES FROM ('{partition_date.strftime('%Y-%m-01')}') 
                    TO ('{(partition_date + timedelta(days=32)).replace(day=1).strftime('%Y-%m-01')}')
                    """)
                    
                    await session.execute(create_partition_query)
                    logger.info(f"パーティション作成: {partition_name}")
                    
                except Exception as e:
                    logger.warning(f"パーティション作成スキップ {partition_name}: {e}")
            
            await session.commit()
            return True
        
        return False
    
    async def _update_statistics(self, session: AsyncSession) -> Dict[str, Any]:
        """統計情報更新"""
        results = {"updated_tables": []}
        
        # 全テーブルの統計更新
        stats_query = text("ANALYZE")
        await session.execute(stats_query)
        await session.commit()
        
        results["global_analyze"] = True
        logger.info("グローバル統計更新完了")
        
        return results
    
    async def _optimize_configuration(self, session: AsyncSession) -> Dict[str, Any]:
        """PostgreSQL設定最適化"""
        results = {"recommendations": []}
        
        # 推奨設定確認
        config_checks = [
            ("shared_buffers", "256MB", "メモリキャッシュサイズ"),
            ("effective_cache_size", "1GB", "利用可能キャッシュサイズ"),
            ("work_mem", "4MB", "ソート・ハッシュ作業メモリ"),
            ("maintenance_work_mem", "64MB", "メンテナンス作業メモリ"),
            ("max_connections", "100", "最大接続数"),
            ("random_page_cost", "1.1", "ランダムアクセスコスト"),
        ]
        
        for param, recommended, description in config_checks:
            try:
                current_query = text(f"SHOW {param}")
                result = await session.execute(current_query)
                current_value = result.scalar()
                
                results["recommendations"].append({
                    "parameter": param,
                    "current_value": current_value,
                    "recommended_value": recommended,
                    "description": description
                })
                
            except Exception as e:
                logger.warning(f"設定確認エラー {param}: {e}")
        
        return results
    
    async def _measure_performance(self, session: AsyncSession) -> Dict[str, Any]:
        """パフォーマンス測定"""
        results = {}
        
        # 基本クエリパフォーマンステスト
        test_queries = [
            ("SELECT COUNT(*) FROM users", "users_count"),
            ("SELECT COUNT(*) FROM mailboxes WHERE usage_percent > 80", "high_usage_mailboxes"),
            ("SELECT user_id, COUNT(*) FROM signin_logs GROUP BY user_id LIMIT 10", "signin_activity")
        ]
        
        for query, test_name in test_queries:
            start_time = asyncio.get_event_loop().time()
            
            try:
                result = await session.execute(text(query))
                result.fetchall()  # 結果を完全に取得
                
                execution_time = (asyncio.get_event_loop().time() - start_time) * 1000
                results[test_name] = {
                    "execution_time_ms": execution_time,
                    "status": "success"
                }
                
            except Exception as e:
                results[test_name] = {
                    "execution_time_ms": 0,
                    "status": "error",
                    "error": str(e)
                }
        
        return results
    
    async def get_optimization_report(self) -> Dict[str, Any]:
        """最適化レポート取得"""
        return {
            "optimization_stats": self.optimization_stats,
            "database_engine_info": {
                "pool_size": self.engine.pool.size(),
                "checked_out": self.engine.pool.checkedout(),
                "overflow": self.engine.pool.overflow(),
                "checked_in": self.engine.pool.checkedin()
            },
            "timestamp": datetime.utcnow().isoformat()
        }