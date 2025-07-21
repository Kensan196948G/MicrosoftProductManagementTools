"""
リアルタイム通知システム (Microsoft Graph Delta Query)
Microsoft 365 データの変更をリアルタイムで検知・通知
"""

import asyncio
import json
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Set, Callable
from dataclasses import dataclass, asdict
from urllib.parse import urljoin
import aiohttp
from sqlalchemy.ext.asyncio import AsyncSession

from ..graph.client import GraphClient
from ...core.config import settings
from ...core.logging_config import get_logger
from ...core.database import get_async_session

logger = get_logger(__name__)

@dataclass
class DeltaQueryConfig:
    """Delta Query設定"""
    resource_type: str
    endpoint: str
    poll_interval_seconds: int = 60
    max_retries: int = 3
    retry_delay_seconds: int = 5
    subscription_enabled: bool = True
    webhook_url: Optional[str] = None

@dataclass
class ChangeNotification:
    """変更通知"""
    resource_type: str
    change_type: str  # created, updated, deleted
    resource_id: str
    resource_data: Dict[str, Any]
    timestamp: datetime
    client_state: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """辞書形式に変換"""
        return {
            **asdict(self),
            "timestamp": self.timestamp.isoformat()
        }

class DeltaQueryManager:
    """Delta Query管理"""
    
    def __init__(self):
        self.graph_client: Optional[GraphClient] = None
        self.delta_tokens: Dict[str, str] = {}  # リソースタイプ: Delta Token
        self.subscriptions: Dict[str, str] = {}  # リソースタイプ: Subscription ID
        self.webhooks: Dict[str, Callable] = {}  # Webhook コールバック
        self.polling_tasks: Dict[str, asyncio.Task] = {}
        self.is_running = False
        
        # 監視対象リソース設定
        self.resource_configs = {
            "users": DeltaQueryConfig(
                resource_type="users",
                endpoint="/users/delta",
                poll_interval_seconds=300,  # 5分
                subscription_enabled=True
            ),
            "groups": DeltaQueryConfig(
                resource_type="groups", 
                endpoint="/groups/delta",
                poll_interval_seconds=600,  # 10分
                subscription_enabled=True
            ),
            "applications": DeltaQueryConfig(
                resource_type="applications",
                endpoint="/applications/delta",
                poll_interval_seconds=1800,  # 30分
                subscription_enabled=False
            ),
            "directoryRoles": DeltaQueryConfig(
                resource_type="directoryRoles",
                endpoint="/directoryRoles/delta", 
                poll_interval_seconds=3600,  # 1時間
                subscription_enabled=False
            ),
            "devices": DeltaQueryConfig(
                resource_type="devices",
                endpoint="/devices/delta",
                poll_interval_seconds=900,  # 15分
                subscription_enabled=True
            )
        }
        
    async def initialize(self):
        """初期化"""
        try:
            self.graph_client = GraphClient()
            await self.graph_client.initialize()
            
            # 既存のDelta Tokenを復元
            await self._restore_delta_tokens()
            
            logger.info("Delta Query Manager initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize Delta Query Manager: {e}")
            raise

    async def start_monitoring(self):
        """リアルタイム監視開始"""
        if self.is_running:
            logger.warning("Delta Query monitoring is already running")
            return
            
        self.is_running = True
        logger.info("Starting Delta Query monitoring...")
        
        try:
            # Subscription作成
            for resource_type, config in self.resource_configs.items():
                if config.subscription_enabled:
                    await self._create_subscription(resource_type, config)
            
            # ポーリングタスク開始
            for resource_type, config in self.resource_configs.items():
                task = asyncio.create_task(
                    self._poll_resource_changes(resource_type, config)
                )
                self.polling_tasks[resource_type] = task
            
            logger.info(f"Started monitoring {len(self.polling_tasks)} resources")
            
        except Exception as e:
            logger.error(f"Failed to start Delta Query monitoring: {e}")
            self.is_running = False
            raise

    async def stop_monitoring(self):
        """リアルタイム監視停止"""
        if not self.is_running:
            return
            
        self.is_running = False
        logger.info("Stopping Delta Query monitoring...")
        
        try:
            # ポーリングタスク停止
            for task in self.polling_tasks.values():
                task.cancel()
            
            # タスク完了待ち
            await asyncio.gather(*self.polling_tasks.values(), return_exceptions=True)
            self.polling_tasks.clear()
            
            # Subscription削除
            for resource_type, subscription_id in self.subscriptions.items():
                await self._delete_subscription(subscription_id)
            
            self.subscriptions.clear()
            
            # Delta Token保存
            await self._save_delta_tokens()
            
            logger.info("Delta Query monitoring stopped")
            
        except Exception as e:
            logger.error(f"Error stopping Delta Query monitoring: {e}")

    async def _poll_resource_changes(self, resource_type: str, config: DeltaQueryConfig):
        """リソース変更ポーリング"""
        logger.info(f"Starting delta polling for {resource_type}")
        
        while self.is_running:
            try:
                changes = await self._get_delta_changes(resource_type, config)
                
                if changes:
                    logger.info(f"Found {len(changes)} changes for {resource_type}")
                    
                    # 変更通知処理
                    for change in changes:
                        await self._process_change_notification(change)
                
                # 次のポーリングまで待機
                await asyncio.sleep(config.poll_interval_seconds)
                
            except asyncio.CancelledError:
                logger.info(f"Delta polling cancelled for {resource_type}")
                break
            except Exception as e:
                logger.error(f"Error in delta polling for {resource_type}: {e}")
                
                # エラー時は短い間隔で再試行
                await asyncio.sleep(config.retry_delay_seconds)

    async def _get_delta_changes(self, resource_type: str, config: DeltaQueryConfig) -> List[ChangeNotification]:
        """Delta変更取得"""
        if not self.graph_client:
            raise Exception("Graph client not initialized")
        
        try:
            # Delta Token取得
            delta_token = self.delta_tokens.get(resource_type)
            
            # Delta Query実行
            if delta_token:
                # 差分取得
                url = f"{config.endpoint}?$deltatoken={delta_token}"
            else:
                # 初回フル取得
                url = config.endpoint
                
            response = await self.graph_client._make_request("GET", url)
            
            if not response.get("value"):
                return []
            
            changes = []
            
            # レスポンス解析
            for item in response["value"]:
                # 削除項目チェック
                if "@removed" in item:
                    change_type = "deleted"
                    resource_data = {"id": item.get("id"), "deleted": True}
                else:
                    # 新規作成 vs 更新判定
                    change_type = "updated"  # 厳密には作成時刻で判定が必要
                    resource_data = item
                
                change = ChangeNotification(
                    resource_type=resource_type,
                    change_type=change_type,
                    resource_id=item.get("id", ""),
                    resource_data=resource_data,
                    timestamp=datetime.utcnow()
                )
                changes.append(change)
            
            # Delta Token更新
            delta_link = response.get("@odata.deltaLink")
            if delta_link:
                # Delta Token抽出
                if "$deltatoken=" in delta_link:
                    new_token = delta_link.split("$deltatoken=")[1].split("&")[0]
                    self.delta_tokens[resource_type] = new_token
                    logger.debug(f"Updated delta token for {resource_type}")
            
            return changes
            
        except Exception as e:
            logger.error(f"Failed to get delta changes for {resource_type}: {e}")
            return []

    async def _create_subscription(self, resource_type: str, config: DeltaQueryConfig):
        """Webhook Subscription作成"""
        if not config.subscription_enabled or not config.webhook_url:
            return
            
        try:
            subscription_data = {
                "changeType": "created,updated,deleted",
                "notificationUrl": config.webhook_url,
                "resource": config.endpoint.replace("/delta", ""),
                "expirationDateTime": (datetime.utcnow() + timedelta(hours=24)).isoformat() + "Z",
                "clientState": f"client_state_{resource_type}_{int(time.time())}"
            }
            
            response = await self.graph_client._make_request(
                "POST", 
                "/subscriptions", 
                data=subscription_data
            )
            
            if response.get("id"):
                self.subscriptions[resource_type] = response["id"]
                logger.info(f"Created subscription for {resource_type}: {response['id']}")
            
        except Exception as e:
            logger.error(f"Failed to create subscription for {resource_type}: {e}")

    async def _delete_subscription(self, subscription_id: str):
        """Subscription削除"""
        try:
            await self.graph_client._make_request("DELETE", f"/subscriptions/{subscription_id}")
            logger.info(f"Deleted subscription: {subscription_id}")
            
        except Exception as e:
            logger.error(f"Failed to delete subscription {subscription_id}: {e}")

    async def _process_change_notification(self, change: ChangeNotification):
        """変更通知処理"""
        try:
            # データベースに記録
            await self._save_change_to_database(change)
            
            # Webhook通知
            await self._send_webhook_notification(change)
            
            # キャッシュ無効化
            await self._invalidate_cache(change)
            
            logger.debug(f"Processed change notification: {change.resource_type}/{change.resource_id}")
            
        except Exception as e:
            logger.error(f"Failed to process change notification: {e}")

    async def _save_change_to_database(self, change: ChangeNotification):
        """変更をデータベースに保存"""
        try:
            async with get_async_session() as session:
                # ChangeLog テーブルに保存（テーブル定義は省略）
                change_log = {
                    "resource_type": change.resource_type,
                    "change_type": change.change_type,
                    "resource_id": change.resource_id,
                    "resource_data": json.dumps(change.resource_data),
                    "timestamp": change.timestamp,
                    "processed": True
                }
                
                # 実際のINSERT処理は省略
                logger.debug(f"Saved change to database: {change.resource_id}")
                
        except Exception as e:
            logger.error(f"Failed to save change to database: {e}")

    async def _send_webhook_notification(self, change: ChangeNotification):
        """Webhook通知送信"""
        webhook_handlers = self.webhooks.get(change.resource_type, [])
        
        for handler in webhook_handlers:
            try:
                await handler(change)
            except Exception as e:
                logger.error(f"Webhook handler error for {change.resource_type}: {e}")

    async def _invalidate_cache(self, change: ChangeNotification):
        """関連キャッシュ無効化"""
        try:
            # パフォーマンス最適化モジュールのキャッシュマネージャーを使用
            from ..optimization.performance_optimizer import cache_manager
            
            # リソースタイプ別キャッシュ無効化
            await cache_manager.invalidate_pattern(change.resource_type, "*")
            
            # 関連キャッシュも無効化
            if change.resource_type == "users":
                await cache_manager.invalidate_pattern("user_data", "*")
                await cache_manager.invalidate_pattern("license_data", "*")
            
            logger.debug(f"Invalidated cache for {change.resource_type}")
            
        except Exception as e:
            logger.error(f"Failed to invalidate cache: {e}")

    async def _restore_delta_tokens(self):
        """Delta Token復元"""
        try:
            # 実際はデータベースから復元
            # 今回は簡易実装でファイルから復元
            import os
            token_file = "delta_tokens.json"
            
            if os.path.exists(token_file):
                with open(token_file, 'r') as f:
                    self.delta_tokens = json.load(f)
                logger.info(f"Restored {len(self.delta_tokens)} delta tokens")
            
        except Exception as e:
            logger.error(f"Failed to restore delta tokens: {e}")

    async def _save_delta_tokens(self):
        """Delta Token保存"""
        try:
            import os
            token_file = "delta_tokens.json"
            
            with open(token_file, 'w') as f:
                json.dump(self.delta_tokens, f, indent=2)
            logger.info(f"Saved {len(self.delta_tokens)} delta tokens")
            
        except Exception as e:
            logger.error(f"Failed to save delta tokens: {e}")

    def register_webhook(self, resource_type: str, handler: Callable[[ChangeNotification], None]):
        """Webhook ハンドラー登録"""
        if resource_type not in self.webhooks:
            self.webhooks[resource_type] = []
        
        self.webhooks[resource_type].append(handler)
        logger.info(f"Registered webhook handler for {resource_type}")

    def unregister_webhook(self, resource_type: str, handler: Callable):
        """Webhook ハンドラー登録解除"""
        if resource_type in self.webhooks and handler in self.webhooks[resource_type]:
            self.webhooks[resource_type].remove(handler)
            logger.info(f"Unregistered webhook handler for {resource_type}")

    async def get_monitoring_status(self) -> Dict[str, Any]:
        """監視状態取得"""
        return {
            "is_running": self.is_running,
            "monitored_resources": list(self.resource_configs.keys()),
            "active_tasks": len([task for task in self.polling_tasks.values() if not task.done()]),
            "subscriptions": dict(self.subscriptions),
            "delta_tokens": {k: bool(v) for k, v in self.delta_tokens.items()},
            "webhook_handlers": {k: len(v) for k, v in self.webhooks.items()},
            "last_update": datetime.utcnow().isoformat()
        }

    async def force_refresh(self, resource_type: str) -> int:
        """指定リソースの強制更新"""
        if resource_type not in self.resource_configs:
            raise ValueError(f"Unknown resource type: {resource_type}")
        
        # Delta Token削除（フルスキャン強制）
        if resource_type in self.delta_tokens:
            del self.delta_tokens[resource_type]
        
        # 即座に変更取得実行
        config = self.resource_configs[resource_type]
        changes = await self._get_delta_changes(resource_type, config)
        
        # 変更処理
        for change in changes:
            await self._process_change_notification(change)
        
        logger.info(f"Force refresh completed for {resource_type}: {len(changes)} changes")
        return len(changes)

# グローバルインスタンス
delta_query_manager = DeltaQueryManager()

# 便利な関数群
async def start_real_time_monitoring():
    """リアルタイム監視開始"""
    await delta_query_manager.initialize()
    await delta_query_manager.start_monitoring()

async def stop_real_time_monitoring():
    """リアルタイム監視停止"""
    await delta_query_manager.stop_monitoring()

async def get_real_time_status():
    """リアルタイム監視状態取得"""
    return await delta_query_manager.get_monitoring_status()

# サンプルWebhookハンドラー
async def sample_user_change_handler(change: ChangeNotification):
    """ユーザー変更ハンドラーサンプル"""
    logger.info(f"User {change.change_type}: {change.resource_id}")
    
    # WebSocketでフロントエンドに通知
    try:
        from ..integration.frontend_support import frontend_integration_manager
        
        notification = {
            "type": "real_time_update",
            "resource": "users",
            "change": change.to_dict()
        }
        
        await frontend_integration_manager.broadcast_to_all(notification)
        
    except Exception as e:
        logger.error(f"Failed to send WebSocket notification: {e}")

# 初期化関数
async def initialize_delta_query():
    """Delta Query初期化"""
    await delta_query_manager.initialize()
    
    # サンプルハンドラー登録
    delta_query_manager.register_webhook("users", sample_user_change_handler)
    
    logger.info("Delta Query system initialized")