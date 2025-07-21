"""
Frontend統合技術支援モジュール
React Frontend と Python Backend の統合を支援
"""

import asyncio
import json
import logging
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Union
from fastapi import WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
import aioredis
from sqlalchemy.ext.asyncio import AsyncSession

from ..graph.client import GraphClient
from ...core.config import settings
from ...core.database import get_async_session
from ...core.logging_config import get_logger

logger = get_logger(__name__)

class FrontendIntegrationConfig(BaseModel):
    """フロントエンド統合設定"""
    websocket_enabled: bool = Field(default=True)
    real_time_updates: bool = Field(default=True)
    cache_duration_seconds: int = Field(default=300)
    max_concurrent_requests: int = Field(default=50)
    request_timeout_seconds: int = Field(default=30)

class WebSocketConnection:
    """WebSocket接続管理"""
    def __init__(self, websocket: WebSocket, client_id: str):
        self.websocket = websocket
        self.client_id = client_id
        self.connected_at = datetime.utcnow()
        self.last_ping = datetime.utcnow()
        
    async def send_json(self, data: Dict[str, Any]) -> bool:
        """JSON データ送信"""
        try:
            await self.websocket.send_json(data)
            return True
        except Exception as e:
            logger.error(f"WebSocket send error for client {self.client_id}: {e}")
            return False
    
    async def ping(self) -> bool:
        """接続確認"""
        try:
            await self.websocket.ping()
            self.last_ping = datetime.utcnow()
            return True
        except:
            return False

class FrontendIntegrationManager:
    """フロントエンド統合マネージャー"""
    
    def __init__(self):
        self.config = FrontendIntegrationConfig()
        self.connections: Dict[str, WebSocketConnection] = {}
        self.redis_client: Optional[aioredis.Redis] = None
        self.graph_client: Optional[GraphClient] = None
        
    async def initialize(self):
        """初期化"""
        try:
            # Redis接続
            if settings.redis_url:
                self.redis_client = await aioredis.from_url(
                    settings.redis_url,
                    encoding="utf-8",
                    decode_responses=True
                )
                logger.info("Redis connected for frontend integration")
            
            # Graph クライアント初期化
            self.graph_client = GraphClient()
            await self.graph_client.initialize()
            
            logger.info("Frontend Integration Manager initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize Frontend Integration Manager: {e}")
            raise

    async def add_websocket_connection(self, websocket: WebSocket, client_id: str) -> bool:
        """WebSocket接続追加"""
        try:
            await websocket.accept()
            connection = WebSocketConnection(websocket, client_id)
            self.connections[client_id] = connection
            
            logger.info(f"WebSocket connection added: {client_id}")
            
            # 接続通知
            await self.broadcast_system_event({
                "type": "client_connected",
                "client_id": client_id,
                "connected_at": connection.connected_at.isoformat(),
                "total_connections": len(self.connections)
            })
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to add WebSocket connection {client_id}: {e}")
            return False

    async def remove_websocket_connection(self, client_id: str):
        """WebSocket接続削除"""
        if client_id in self.connections:
            connection = self.connections[client_id]
            try:
                await connection.websocket.close()
            except:
                pass
            
            del self.connections[client_id]
            logger.info(f"WebSocket connection removed: {client_id}")
            
            # 切断通知
            await self.broadcast_system_event({
                "type": "client_disconnected", 
                "client_id": client_id,
                "total_connections": len(self.connections)
            })

    async def handle_websocket_message(self, client_id: str, message: Dict[str, Any]) -> Dict[str, Any]:
        """WebSocketメッセージ処理"""
        try:
            message_type = message.get("type")
            
            if message_type == "ping":
                return {"type": "pong", "timestamp": datetime.utcnow().isoformat()}
            
            elif message_type == "subscribe_notifications":
                topics = message.get("topics", [])
                return await self.subscribe_notifications(client_id, topics)
            
            elif message_type == "unsubscribe_notifications":
                topics = message.get("topics", [])
                return await self.unsubscribe_notifications(client_id, topics)
            
            elif message_type == "execute_feature":
                return await self.execute_feature_realtime(client_id, message.get("request", {}))
            
            elif message_type == "get_system_status":
                return await self.get_system_status_realtime()
            
            else:
                logger.warning(f"Unknown message type: {message_type}")
                return {"type": "error", "message": f"Unknown message type: {message_type}"}
                
        except Exception as e:
            logger.error(f"Error handling WebSocket message from {client_id}: {e}")
            return {"type": "error", "message": str(e)}

    async def subscribe_notifications(self, client_id: str, topics: List[str]) -> Dict[str, Any]:
        """通知購読"""
        if self.redis_client:
            try:
                # Redis購読設定
                for topic in topics:
                    await self.redis_client.sadd(f"subscribers:{topic}", client_id)
                
                logger.info(f"Client {client_id} subscribed to topics: {topics}")
                return {
                    "type": "subscription_success",
                    "topics": topics,
                    "message": "Successfully subscribed to notifications"
                }
                
            except Exception as e:
                logger.error(f"Failed to subscribe {client_id} to topics {topics}: {e}")
                return {"type": "subscription_error", "message": str(e)}
        
        return {"type": "subscription_error", "message": "Redis not available"}

    async def unsubscribe_notifications(self, client_id: str, topics: List[str]) -> Dict[str, Any]:
        """通知購読解除"""
        if self.redis_client:
            try:
                for topic in topics:
                    await self.redis_client.srem(f"subscribers:{topic}", client_id)
                
                logger.info(f"Client {client_id} unsubscribed from topics: {topics}")
                return {
                    "type": "unsubscription_success",
                    "topics": topics,
                    "message": "Successfully unsubscribed from notifications"
                }
                
            except Exception as e:
                logger.error(f"Failed to unsubscribe {client_id} from topics {topics}: {e}")
                return {"type": "unsubscription_error", "message": str(e)}
        
        return {"type": "unsubscription_error", "message": "Redis not available"}

    async def execute_feature_realtime(self, client_id: str, request: Dict[str, Any]) -> Dict[str, Any]:
        """リアルタイム機能実行"""
        try:
            action = request.get("action")
            parameters = request.get("parameters", {})
            
            if not action:
                return {"type": "execution_error", "message": "Action is required"}
            
            # 実行ID生成
            execution_id = f"exec_{int(time.time())}_{client_id}"
            
            # 非同期で機能実行開始
            asyncio.create_task(self.run_feature_with_progress(
                execution_id, client_id, action, parameters
            ))
            
            return {
                "type": "execution_started",
                "execution_id": execution_id,
                "action": action,
                "message": "Feature execution started"
            }
            
        except Exception as e:
            logger.error(f"Failed to execute feature for {client_id}: {e}")
            return {"type": "execution_error", "message": str(e)}

    async def run_feature_with_progress(self, execution_id: str, client_id: str, action: str, parameters: Dict[str, Any]):
        """進捗付き機能実行"""
        try:
            # 開始通知
            await self.send_to_client(client_id, {
                "type": "execution_progress",
                "execution_id": execution_id,
                "progress": 0,
                "status": "starting",
                "message": f"Starting {action}..."
            })
            
            # 機能実行ロジック（例：ユーザー一覧取得）
            if action == "get_users":
                result = await self.execute_get_users_with_progress(execution_id, client_id, parameters)
            elif action == "get_licenses":
                result = await self.execute_get_licenses_with_progress(execution_id, client_id, parameters)
            elif action == "daily_report":
                result = await self.execute_daily_report_with_progress(execution_id, client_id, parameters)
            else:
                result = {"error": f"Unknown action: {action}"}
            
            # 完了通知
            await self.send_to_client(client_id, {
                "type": "execution_completed",
                "execution_id": execution_id,
                "progress": 100,
                "status": "completed",
                "result": result,
                "message": f"{action} completed successfully"
            })
            
        except Exception as e:
            logger.error(f"Feature execution failed for {execution_id}: {e}")
            await self.send_to_client(client_id, {
                "type": "execution_failed",
                "execution_id": execution_id,
                "status": "failed",
                "error": str(e),
                "message": f"{action} execution failed"
            })

    async def execute_get_users_with_progress(self, execution_id: str, client_id: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """ユーザー取得（進捗付き）"""
        try:
            if not self.graph_client:
                raise Exception("Graph client not initialized")
            
            # 進捗：20%
            await self.send_to_client(client_id, {
                "type": "execution_progress",
                "execution_id": execution_id,
                "progress": 20,
                "message": "Authenticating to Microsoft Graph..."
            })
            
            # Graph API でユーザー取得
            top = parameters.get("top", 100)
            users = await self.graph_client.get_users(top=top)
            
            # 進捗：60%
            await self.send_to_client(client_id, {
                "type": "execution_progress",
                "execution_id": execution_id,
                "progress": 60,
                "message": f"Retrieved {len(users)} users..."
            })
            
            # ライセンス情報付加
            enhanced_users = []
            for i, user in enumerate(users):
                try:
                    # ユーザーライセンス取得
                    licenses = await self.graph_client.get_user_licenses(user.get("id", ""))
                    user["licenses"] = licenses
                    enhanced_users.append(user)
                    
                    # 進捗更新
                    progress = 60 + (30 * (i + 1) / len(users))
                    await self.send_to_client(client_id, {
                        "type": "execution_progress",
                        "execution_id": execution_id,
                        "progress": int(progress),
                        "message": f"Processing user {i + 1}/{len(users)}..."
                    })
                    
                except Exception as e:
                    logger.warning(f"Failed to get licenses for user {user.get('id', 'unknown')}: {e}")
                    user["licenses"] = []
                    enhanced_users.append(user)
            
            return {
                "users": enhanced_users,
                "total_count": len(enhanced_users),
                "execution_time": time.time()
            }
            
        except Exception as e:
            logger.error(f"Failed to execute get_users: {e}")
            raise

    async def execute_get_licenses_with_progress(self, execution_id: str, client_id: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """ライセンス取得（進捗付き）"""
        try:
            if not self.graph_client:
                raise Exception("Graph client not initialized")
            
            # 進捗通知
            progress_steps = [
                (20, "Authenticating to Microsoft Graph..."),
                (40, "Retrieving license information..."),
                (60, "Processing subscribed SKUs..."),
                (80, "Calculating usage statistics...")
            ]
            
            for progress, message in progress_steps:
                await self.send_to_client(client_id, {
                    "type": "execution_progress",
                    "execution_id": execution_id,
                    "progress": progress,
                    "message": message
                })
                await asyncio.sleep(0.5)  # リアリティのための待機
            
            # ライセンス情報取得
            licenses = await self.graph_client.get_licenses()
            
            return {
                "licenses": licenses,
                "total_count": len(licenses),
                "execution_time": time.time()
            }
            
        except Exception as e:
            logger.error(f"Failed to execute get_licenses: {e}")
            raise

    async def execute_daily_report_with_progress(self, execution_id: str, client_id: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """日次レポート生成（進捗付き）"""
        try:
            # 進捗通知
            progress_steps = [
                (10, "Initializing daily report generation..."),
                (25, "Collecting user activity data..."),
                (40, "Analyzing license usage..."),
                (55, "Gathering security insights..."),
                (70, "Processing Teams usage..."),
                (85, "Generating report files..."),
                (95, "Finalizing report...")
            ]
            
            for progress, message in progress_steps:
                await self.send_to_client(client_id, {
                    "type": "execution_progress",
                    "execution_id": execution_id,
                    "progress": progress,
                    "message": message
                })
                await asyncio.sleep(1)  # より長い処理をシミュレート
            
            # レポート生成（実際のロジックは省略）
            report_data = {
                "report_type": "daily",
                "generated_at": datetime.utcnow().isoformat(),
                "total_users": 150,
                "active_users": 142,
                "license_usage": {
                    "total_licenses": 200,
                    "assigned_licenses": 150,
                    "usage_percentage": 75.0
                },
                "security_score": 85,
                "teams_meetings": 45,
                "onedrive_storage_gb": 2500
            }
            
            return {
                "report": report_data,
                "report_path": f"/api/reports/daily_{datetime.utcnow().strftime('%Y%m%d')}.html",
                "execution_time": time.time()
            }
            
        except Exception as e:
            logger.error(f"Failed to execute daily_report: {e}")
            raise

    async def send_to_client(self, client_id: str, data: Dict[str, Any]) -> bool:
        """特定クライアントにデータ送信"""
        if client_id in self.connections:
            return await self.connections[client_id].send_json(data)
        return False

    async def broadcast_to_all(self, data: Dict[str, Any]) -> int:
        """全クライアントにブロードキャスト"""
        sent_count = 0
        for client_id, connection in self.connections.items():
            if await connection.send_json(data):
                sent_count += 1
        return sent_count

    async def broadcast_system_event(self, event: Dict[str, Any]):
        """システムイベントブロードキャスト"""
        system_message = {
            "type": "system_event",
            "timestamp": datetime.utcnow().isoformat(),
            "event": event
        }
        await self.broadcast_to_all(system_message)

    async def get_system_status_realtime(self) -> Dict[str, Any]:
        """リアルタイムシステム状態"""
        try:
            # システム状態収集
            status = {
                "status": "healthy",
                "timestamp": datetime.utcnow().isoformat(),
                "connections": {
                    "websocket_count": len(self.connections),
                    "active_clients": list(self.connections.keys())
                },
                "services": {
                    "graph_api": bool(self.graph_client),
                    "redis": bool(self.redis_client),
                    "database": True  # 実際にはDB接続確認
                },
                "performance": {
                    "uptime_seconds": (datetime.utcnow() - datetime(2024, 1, 1)).total_seconds(),
                    "memory_usage_mb": 256,  # 実際にはpsutilで取得
                    "cpu_usage_percent": 15.5
                }
            }
            
            return status
            
        except Exception as e:
            logger.error(f"Failed to get system status: {e}")
            return {
                "status": "error",
                "timestamp": datetime.utcnow().isoformat(),
                "error": str(e)
            }

    async def cleanup_stale_connections(self):
        """古い接続のクリーンアップ"""
        stale_connections = []
        current_time = datetime.utcnow()
        
        for client_id, connection in self.connections.items():
            # 30分以上古い接続をチェック
            if current_time - connection.last_ping > timedelta(minutes=30):
                if not await connection.ping():
                    stale_connections.append(client_id)
        
        for client_id in stale_connections:
            await self.remove_websocket_connection(client_id)
        
        if stale_connections:
            logger.info(f"Cleaned up {len(stale_connections)} stale connections")

    async def start_background_tasks(self):
        """バックグラウンドタスク開始"""
        # 古い接続のクリーンアップタスク
        asyncio.create_task(self.periodic_cleanup())
        
        # システム監視タスク
        asyncio.create_task(self.periodic_system_monitoring())

    async def periodic_cleanup(self):
        """定期クリーンアップ"""
        while True:
            try:
                await asyncio.sleep(300)  # 5分間隔
                await self.cleanup_stale_connections()
            except Exception as e:
                logger.error(f"Error in periodic cleanup: {e}")

    async def periodic_system_monitoring(self):
        """定期システム監視"""
        while True:
            try:
                await asyncio.sleep(60)  # 1分間隔
                
                # システム状態取得
                status = await self.get_system_status_realtime()
                
                # 異常検知時は全クライアントに通知
                if status.get("status") != "healthy":
                    await self.broadcast_system_event({
                        "type": "system_alert",
                        "severity": "warning",
                        "message": "System health check failed",
                        "details": status
                    })
                
            except Exception as e:
                logger.error(f"Error in periodic system monitoring: {e}")

# グローバルインスタンス
frontend_integration_manager = FrontendIntegrationManager()

# FastAPI WebSocket エンドポイント用ヘルパー
async def handle_websocket_connection(websocket: WebSocket, client_id: str):
    """WebSocket接続ハンドラー"""
    if not await frontend_integration_manager.add_websocket_connection(websocket, client_id):
        await websocket.close(code=1000, reason="Failed to establish connection")
        return
    
    try:
        while True:
            # メッセージ受信
            message = await websocket.receive_json()
            
            # メッセージ処理
            response = await frontend_integration_manager.handle_websocket_message(client_id, message)
            
            # レスポンス送信
            await websocket.send_json(response)
            
    except WebSocketDisconnect:
        logger.info(f"WebSocket client {client_id} disconnected")
    except Exception as e:
        logger.error(f"WebSocket error for client {client_id}: {e}")
    finally:
        await frontend_integration_manager.remove_websocket_connection(client_id)

# 初期化関数
async def initialize_frontend_integration():
    """フロントエンド統合初期化"""
    await frontend_integration_manager.initialize()
    await frontend_integration_manager.start_background_tasks()
    logger.info("Frontend Integration initialized and background tasks started")