"""
Microsoft 365管理ツール Microsoft Graph統合
=========================================

Microsoft Graph API完全統合
- リアルタイムデータ取得
- ユーザー・グループ管理
- Teams・OneDrive・Exchange統合
- 認証・権限管理
"""

import asyncio
import logging
from datetime import datetime, date, timedelta
from typing import List, Dict, Any, Optional, AsyncGenerator
from dataclasses import dataclass

from ..auth.msal_authentication import MSALAuthenticationManager, AuthenticationConfig

logger = logging.getLogger(__name__)


@dataclass
class GraphAPIResponse:
    """Graph APIレスポンス"""
    data: Any
    status_code: int
    success: bool
    error: Optional[str] = None
    next_link: Optional[str] = None


class MicrosoftGraphIntegration:
    """Microsoft Graph API統合クラス"""
    
    # Microsoft Graph API エンドポイント
    BASE_URL = "https://graph.microsoft.com/v1.0"
    BETA_URL = "https://graph.microsoft.com/beta"
    
    # API エンドポイント定義
    ENDPOINTS = {
        # ユーザー管理
        "users": "/users",
        "user_detail": "/users/{user_id}",
        "user_manager": "/users/{user_id}/manager",
        "user_direct_reports": "/users/{user_id}/directReports",
        
        # グループ管理
        "groups": "/groups",
        "group_members": "/groups/{group_id}/members",
        "group_owners": "/groups/{group_id}/owners",
        
        # サインインログ
        "signin_logs": "/auditLogs/signIns",
        "directory_audits": "/auditLogs/directoryAudits",
        
        # ライセンス管理
        "subscribed_skus": "/subscribedSkus",
        "directory_roles": "/directoryRoles",
        "role_assignments": "/roleAssignments",
        
        # Teams統合
        "teams": "/teams",
        "team_channels": "/teams/{team_id}/channels",
        "chat_messages": "/teams/{team_id}/channels/{channel_id}/messages",
        "team_members": "/teams/{team_id}/members",
        
        # OneDrive統合
        "drives": "/drives",
        "drive_items": "/drives/{drive_id}/root/children",
        "shared_items": "/me/drive/sharedWithMe",
        "drive_usage": "/reports/getOneDriveUsageAccountDetail(period='D30')",
        
        # Exchange統合（Graph経由）
        "mailboxes": "/users/{user_id}/mailboxSettings",
        "messages": "/users/{user_id}/messages",
        "mail_folders": "/users/{user_id}/mailFolders",
        "calendar_events": "/users/{user_id}/events",
        
        # セキュリティ・コンプライアンス
        "security_alerts": "/security/alerts",
        "conditional_access": "/identity/conditionalAccess/policies",
        "privileged_access": "/privilegedAccess/azureAD/resources",
        
        # レポート機能
        "usage_reports": "/reports/{report_name}(period='{period}')",
        "activity_reports": "/reports/getEmailActivityUserDetail(period='D30')",
        "teams_activity": "/reports/getTeamsUserActivityUserDetail(period='D30')",
    }
    
    def __init__(self, config: AuthenticationConfig):
        """
        Microsoft Graph統合初期化
        
        Args:
            config: MSAL認証設定
        """
        self.config = config
        self.auth_manager = MSALAuthenticationManager(config)
        self._session = None
        
        # APIリクエスト制限設定
        self.rate_limit_delay = 0.1  # 100ms delay between requests
        self.max_retries = 3
        self.retry_delay = 1.0
        
        # バッチリクエスト設定
        self.batch_size = 20  # Microsoft Graph バッチ制限
        
    async def initialize(self):
        """非同期初期化"""
        try:
            # 認証実行
            auth_result = await asyncio.to_thread(self.auth_manager.authenticate, ['Microsoft Graph'])
            
            if not auth_result.success:
                raise Exception(f"Microsoft Graph認証失敗: {auth_result.error}")
            
            self.access_token = auth_result.tokens.get('Microsoft Graph')
            
            if not self.access_token:
                raise Exception("Microsoft Graph アクセストークン取得失敗")
            
            logger.info("Microsoft Graph統合初期化完了")
            
        except Exception as e:
            logger.error(f"Microsoft Graph初期化エラー: {e}")
            raise
    
    async def _make_request(self, 
                           endpoint: str, 
                           method: str = "GET",
                           params: Optional[Dict[str, Any]] = None,
                           data: Optional[Dict[str, Any]] = None,
                           use_beta: bool = False) -> GraphAPIResponse:
        """Graph APIリクエスト実行"""
        
        import aiohttp
        
        base_url = self.BETA_URL if use_beta else self.BASE_URL
        url = f"{base_url}{endpoint}"
        
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
            "ConsistencyLevel": "eventual"  # 最新データ取得
        }
        
        for attempt in range(self.max_retries):
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.request(
                        method=method,
                        url=url,
                        headers=headers,
                        params=params,
                        json=data
                    ) as response:
                        
                        response_data = await response.json() if response.content_type == 'application/json' else await response.text()
                        
                        # レート制限チェック
                        if response.status == 429:
                            retry_after = int(response.headers.get('Retry-After', self.retry_delay))
                            logger.warning(f"レート制限発生、{retry_after}秒待機")
                            await asyncio.sleep(retry_after)
                            continue
                        
                        # 成功レスポンス
                        if 200 <= response.status < 300:
                            next_link = None
                            if isinstance(response_data, dict) and '@odata.nextLink' in response_data:
                                next_link = response_data['@odata.nextLink']
                            
                            return GraphAPIResponse(
                                data=response_data,
                                status_code=response.status,
                                success=True,
                                next_link=next_link
                            )
                        
                        # エラーレスポンス
                        else:
                            error_msg = f"HTTP {response.status}"
                            if isinstance(response_data, dict) and 'error' in response_data:
                                error_msg = response_data['error'].get('message', error_msg)
                            
                            return GraphAPIResponse(
                                data=response_data,
                                status_code=response.status,
                                success=False,
                                error=error_msg
                            )
            
            except Exception as e:
                logger.warning(f"Graph APIリクエストエラー (試行 {attempt + 1}): {e}")
                if attempt < self.max_retries - 1:
                    await asyncio.sleep(self.retry_delay * (2 ** attempt))
                    continue
                else:
                    return GraphAPIResponse(
                        data=None,
                        status_code=0,
                        success=False,
                        error=str(e)
                    )
        
        # レート制限遵守
        await asyncio.sleep(self.rate_limit_delay)
    
    async def get_all_users(self, 
                           select_fields: Optional[List[str]] = None,
                           filter_query: Optional[str] = None) -> AsyncGenerator[Dict[str, Any], None]:
        """全ユーザー情報取得（ページネーション対応）"""
        
        params = {
            "$top": 999  # 最大取得数
        }
        
        if select_fields:
            params["$select"] = ",".join(select_fields)
        
        if filter_query:
            params["$filter"] = filter_query
        
        endpoint = self.ENDPOINTS["users"]
        
        while True:
            response = await self._make_request(endpoint, params=params)
            
            if not response.success:
                logger.error(f"ユーザー取得エラー: {response.error}")
                break
            
            # データ取得
            if isinstance(response.data, dict) and 'value' in response.data:
                for user in response.data['value']:
                    yield user
            
            # 次ページチェック
            if response.next_link:
                endpoint = response.next_link.replace(self.BASE_URL, "")
                params = {}  # next_linkに含まれているためクリア
            else:
                break
    
    async def get_user_signin_logs(self,
                                  user_id: Optional[str] = None,
                                  hours: int = 24) -> List[Dict[str, Any]]:
        """ユーザーサインインログ取得"""
        
        cutoff_time = (datetime.utcnow() - timedelta(hours=hours)).isoformat() + 'Z'
        
        params = {
            "$top": 1000,
            "$filter": f"createdDateTime ge {cutoff_time}",
            "$orderby": "createdDateTime desc"
        }
        
        if user_id:
            params["$filter"] += f" and userId eq '{user_id}'"
        
        logs = []
        endpoint = self.ENDPOINTS["signin_logs"]
        
        while True:
            response = await self._make_request(endpoint, params=params, use_beta=True)
            
            if not response.success:
                logger.error(f"サインインログ取得エラー: {response.error}")
                break
            
            if isinstance(response.data, dict) and 'value' in response.data:
                logs.extend(response.data['value'])
            
            # 次ページチェック
            if response.next_link and len(logs) < 10000:  # 制限設定
                endpoint = response.next_link.replace(self.BETA_URL, "")
                params = {}
            else:
                break
        
        return logs
    
    async def get_teams_usage_reports(self, period: str = "D30") -> List[Dict[str, Any]]:
        """Teams使用状況レポート取得"""
        
        endpoint = self.ENDPOINTS["teams_activity"].format(period=period)
        response = await self._make_request(endpoint)
        
        if not response.success:
            logger.error(f"Teams使用状況取得エラー: {response.error}")
            return []
        
        # CSVレスポンスの処理（Graph APIレポートはCSV形式）
        if isinstance(response.data, str):
            return self._parse_csv_report(response.data)
        
        return []
    
    async def get_onedrive_usage_reports(self, period: str = "D30") -> List[Dict[str, Any]]:
        """OneDrive使用状況レポート取得"""
        
        endpoint = self.ENDPOINTS["drive_usage"].format(period=period)
        response = await self._make_request(endpoint)
        
        if not response.success:
            logger.error(f"OneDrive使用状況取得エラー: {response.error}")
            return []
        
        if isinstance(response.data, str):
            return self._parse_csv_report(response.data)
        
        return []
    
    async def get_user_mailbox_settings(self, user_id: str) -> Optional[Dict[str, Any]]:
        """ユーザーメールボックス設定取得"""
        
        endpoint = self.ENDPOINTS["mailboxes"].format(user_id=user_id)
        response = await self._make_request(endpoint)
        
        if not response.success:
            logger.error(f"メールボックス設定取得エラー (ユーザー: {user_id}): {response.error}")
            return None
        
        return response.data
    
    async def get_conditional_access_policies(self) -> List[Dict[str, Any]]:
        """条件付きアクセスポリシー取得"""
        
        endpoint = self.ENDPOINTS["conditional_access"]
        response = await self._make_request(endpoint)
        
        if not response.success:
            logger.error(f"条件付きアクセスポリシー取得エラー: {response.error}")
            return []
        
        if isinstance(response.data, dict) and 'value' in response.data:
            return response.data['value']
        
        return []
    
    async def get_organization_licenses(self) -> List[Dict[str, Any]]:
        """組織ライセンス情報取得"""
        
        endpoint = self.ENDPOINTS["subscribed_skus"]
        response = await self._make_request(endpoint)
        
        if not response.success:
            logger.error(f"ライセンス情報取得エラー: {response.error}")
            return []
        
        if isinstance(response.data, dict) and 'value' in response.data:
            return response.data['value']
        
        return []
    
    async def batch_request(self, requests: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """バッチリクエスト実行"""
        
        if len(requests) > self.batch_size:
            # バッチサイズ制限を超える場合は分割実行
            results = []
            for i in range(0, len(requests), self.batch_size):
                batch = requests[i:i + self.batch_size]
                batch_results = await self._execute_batch(batch)
                results.extend(batch_results)
            return results
        else:
            return await self._execute_batch(requests)
    
    async def _execute_batch(self, requests: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """単一バッチリクエスト実行"""
        
        batch_data = {
            "requests": [
                {
                    "id": str(i),
                    "method": req.get("method", "GET"),
                    "url": req["url"],
                    "headers": req.get("headers", {}),
                    "body": req.get("body")
                }
                for i, req in enumerate(requests)
            ]
        }
        
        response = await self._make_request("/$batch", method="POST", data=batch_data)
        
        if not response.success:
            logger.error(f"バッチリクエストエラー: {response.error}")
            return []
        
        if isinstance(response.data, dict) and 'responses' in response.data:
            return response.data['responses']
        
        return []
    
    def _parse_csv_report(self, csv_data: str) -> List[Dict[str, Any]]:
        """CSV形式レポートをPythonオブジェクトに変換"""
        
        import csv
        import io
        
        try:
            reader = csv.DictReader(io.StringIO(csv_data))
            return [row for row in reader]
        except Exception as e:
            logger.error(f"CSVレポート解析エラー: {e}")
            return []
    
    async def sync_users_to_database(self, session, user_model_class):
        """Microsoft Graphからユーザーデータを取得してデータベースに同期"""
        
        synced_count = 0
        error_count = 0
        
        try:
            # 必要なフィールドを指定してユーザー取得
            select_fields = [
                'id', 'displayName', 'userPrincipalName', 'mail',
                'department', 'jobTitle', 'createdDateTime', 'signInActivity',
                'accountEnabled', 'usageLocation', 'assignedLicenses'
            ]
            
            async for user in self.get_all_users(select_fields=select_fields):
                try:
                    # データベースモデルに変換
                    user_data = {
                        'display_name': user.get('displayName', ''),
                        'user_principal_name': user.get('userPrincipalName', ''),
                        'email': user.get('mail'),
                        'department': user.get('department'),
                        'job_title': user.get('jobTitle'),
                        'account_status': '有効' if user.get('accountEnabled', False) else '無効',
                        'usage_location': user.get('usageLocation'),
                        'azure_ad_id': user.get('id'),
                        'creation_date': self._parse_datetime(user.get('createdDateTime')),
                        'last_sign_in': self._parse_signin_activity(user.get('signInActivity'))
                    }
                    
                    # データベース保存（UPSERT）
                    await self._upsert_user(session, user_model_class, user_data)
                    synced_count += 1
                    
                except Exception as e:
                    logger.error(f"ユーザー同期エラー: {user.get('userPrincipalName', 'Unknown')}: {e}")
                    error_count += 1
        
        except Exception as e:
            logger.error(f"ユーザー同期全体エラー: {e}")
            raise
        
        logger.info(f"ユーザー同期完了: 成功 {synced_count}件, エラー {error_count}件")
        return {"synced": synced_count, "errors": error_count}
    
    def _parse_datetime(self, datetime_str: Optional[str]) -> Optional[datetime]:
        """ISO8601日時文字列をdatetimeオブジェクトに変換"""
        
        if not datetime_str:
            return None
        
        try:
            # Microsoft Graph形式: 2023-01-01T12:00:00Z
            return datetime.fromisoformat(datetime_str.replace('Z', '+00:00'))
        except Exception:
            return None
    
    def _parse_signin_activity(self, signin_activity: Optional[Dict[str, Any]]) -> Optional[datetime]:
        """サインインアクティビティから最終サインイン時刻を取得"""
        
        if not signin_activity or not isinstance(signin_activity, dict):
            return None
        
        last_signin = signin_activity.get('lastSignInDateTime')
        return self._parse_datetime(last_signin)
    
    async def _upsert_user(self, session, user_model_class, user_data: Dict[str, Any]):
        """ユーザーデータのUPSERT操作"""
        
        from sqlalchemy import select
        from sqlalchemy.dialects.postgresql import insert
        
        # 既存ユーザーチェック
        stmt = select(user_model_class).where(
            user_model_class.user_principal_name == user_data['user_principal_name']
        )
        result = await session.execute(stmt)
        existing_user = result.scalar_one_or_none()
        
        if existing_user:
            # 更新
            for key, value in user_data.items():
                if value is not None:
                    setattr(existing_user, key, value)
        else:
            # 新規作成
            new_user = user_model_class(**user_data)
            session.add(new_user)
        
        await session.commit()
    
    async def cleanup(self):
        """リソースクリーンアップ"""
        
        if self._session:
            await self._session.close()
        
        logger.info("Microsoft Graph統合クリーンアップ完了")