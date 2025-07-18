"""
Microsoft Graph API service implementations.
Provides high-level service interfaces for Microsoft 365 data access.
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from .client import GraphClient


class UserService:
    """User management service using Microsoft Graph API."""
    
    def __init__(self, graph_client: GraphClient):
        self.client = graph_client
        self.logger = logging.getLogger(__name__)
    
    def get_all_users(self, select_fields: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Get all users with optional field selection."""
        try:
            fields = select_fields or [
                'id', 'displayName', 'userPrincipalName', 'mail',
                'accountEnabled', 'createdDateTime', 'lastSignInDateTime',
                'signInActivity', 'assignedLicenses'
            ]
            return self.client.get_users(select=fields)
        except Exception as e:
            self.logger.error(f"Failed to get users: {e}")
            return []
    
    def get_user_mfa_status(self) -> List[Dict[str, Any]]:
        """Get MFA status for all users."""
        try:
            # Get users with authentication methods
            users = self.client.get('/users')['value']
            mfa_data = []
            
            for user in users:
                user_id = user['id']
                # Get authentication methods for each user
                auth_methods = self.client.get(f'/users/{user_id}/authentication/methods')
                
                mfa_enabled = len(auth_methods.get('value', [])) > 1
                
                mfa_data.append({
                    'ユーザー名': user.get('displayName', ''),
                    'UPN': user.get('userPrincipalName', ''),
                    'MFA有効': 'はい' if mfa_enabled else 'いいえ',
                    '認証方法数': len(auth_methods.get('value', [])),
                    '最終サインイン': user.get('signInActivity', {}).get('lastSignInDateTime', '未記録'),
                    'アカウント状態': '有効' if user.get('accountEnabled') else '無効'
                })
            
            return mfa_data
            
        except Exception as e:
            self.logger.error(f"Failed to get MFA status: {e}")
            return []


class LicenseService:
    """License analysis service using Microsoft Graph API."""
    
    def __init__(self, graph_client: GraphClient):
        self.client = graph_client
        self.logger = logging.getLogger(__name__)
    
    def get_license_analysis(self) -> List[Dict[str, Any]]:
        """Get detailed license analysis."""
        try:
            # Get subscribed SKUs
            skus = self.client.get('/subscribedSkus')['value']
            
            license_data = []
            for sku in skus:
                consumed = sku.get('consumedUnits', 0)
                enabled = sku.get('prepaidUnits', {}).get('enabled', 0)
                suspended = sku.get('prepaidUnits', {}).get('suspended', 0)
                warning = sku.get('prepaidUnits', {}).get('warning', 0)
                
                usage_percentage = (consumed / enabled * 100) if enabled > 0 else 0
                
                license_data.append({
                    'ライセンス名': sku.get('skuPartNumber', '不明'),
                    'サービス名': sku.get('skuId', ''),
                    '総ライセンス数': enabled,
                    '使用済み': consumed,
                    '利用可能': enabled - consumed,
                    '使用率(%)': round(usage_percentage, 1),
                    '一時停止': suspended,
                    '警告': warning,
                    'ステータス': self._get_license_status(usage_percentage),
                    '分析日時': datetime.now().strftime('%Y/%m/%d %H:%M:%S')
                })
            
            return license_data
            
        except Exception as e:
            self.logger.error(f"Failed to get license analysis: {e}")
            return []
    
    def _get_license_status(self, usage_percentage: float) -> str:
        """Determine license status based on usage."""
        if usage_percentage >= 90:
            return '危険'
        elif usage_percentage >= 75:
            return '警告'
        elif usage_percentage >= 50:
            return '注意'
        else:
            return '正常'


class TeamsService:
    """Teams management service using Microsoft Graph API."""
    
    def __init__(self, graph_client: GraphClient):
        self.client = graph_client
        self.logger = logging.getLogger(__name__)
    
    def get_teams_usage(self) -> List[Dict[str, Any]]:
        """Get Teams usage statistics."""
        try:
            # Get reports for last 30 days
            end_date = datetime.now()
            start_date = end_date - timedelta(days=30)
            
            # Get Teams user activity report
            # Note: This requires specific permissions and may need different endpoints
            teams_data = []
            
            # Mock data for now - replace with actual API calls
            teams_data.append({
                'ユーザー名': 'サンプルユーザー',
                'チーム参加数': 5,
                'チャット投稿数': 150,
                '会議参加数': 12,
                '通話時間(分)': 180,
                '最終アクティビティ': datetime.now().strftime('%Y/%m/%d'),
                'ステータス': '活発'
            })
            
            return teams_data
            
        except Exception as e:
            self.logger.error(f"Failed to get Teams usage: {e}")
            return []


class OneDriveService:
    """OneDrive management service using Microsoft Graph API."""
    
    def __init__(self, graph_client: GraphClient):
        self.client = graph_client
        self.logger = logging.getLogger(__name__)
    
    def get_storage_analysis(self) -> List[Dict[str, Any]]:
        """Get OneDrive storage analysis."""
        try:
            # Get all users' OneDrive information
            users = self.client.get_users(select=['id', 'displayName', 'userPrincipalName'])
            
            storage_data = []
            for user in users:
                try:
                    # Get user's drive
                    drive = self.client.get(f"/users/{user['id']}/drive")
                    quota = drive.get('quota', {})
                    
                    total = quota.get('total', 0)
                    used = quota.get('used', 0)
                    remaining = quota.get('remaining', 0)
                    
                    usage_percentage = (used / total * 100) if total > 0 else 0
                    
                    storage_data.append({
                        'ユーザー名': user.get('displayName', ''),
                        'UPN': user.get('userPrincipalName', ''),
                        '総容量(GB)': round(total / (1024**3), 2) if total else 0,
                        '使用量(GB)': round(used / (1024**3), 2) if used else 0,
                        '残容量(GB)': round(remaining / (1024**3), 2) if remaining else 0,
                        '使用率(%)': round(usage_percentage, 1),
                        'ステータス': self._get_storage_status(usage_percentage),
                        '分析日時': datetime.now().strftime('%Y/%m/%d %H:%M:%S')
                    })
                    
                except Exception as user_error:
                    self.logger.warning(f"Failed to get storage for user {user.get('displayName')}: {user_error}")
                    continue
            
            return storage_data
            
        except Exception as e:
            self.logger.error(f"Failed to get storage analysis: {e}")
            return []
    
    def _get_storage_status(self, usage_percentage: float) -> str:
        """Determine storage status based on usage."""
        if usage_percentage >= 95:
            return '満杯'
        elif usage_percentage >= 85:
            return '危険'
        elif usage_percentage >= 70:
            return '警告'
        else:
            return '正常'


class ExchangeService:
    """Exchange Online management service."""
    
    def __init__(self, graph_client: GraphClient):
        self.client = graph_client
        self.logger = logging.getLogger(__name__)
    
    def get_mailbox_analysis(self) -> List[Dict[str, Any]]:
        """Get mailbox analysis data."""
        try:
            # Get all users with mailbox information
            users = self.client.get_users(select=['id', 'displayName', 'mail', 'userPrincipalName'])
            
            mailbox_data = []
            for user in users:
                if not user.get('mail'):  # Skip users without mailboxes
                    continue
                
                try:
                    # Get mailbox statistics
                    mailbox_stats = self.client.get(f"/users/{user['id']}/mailboxSettings")
                    
                    mailbox_data.append({
                        'ユーザー名': user.get('displayName', ''),
                        'メールアドレス': user.get('mail', ''),
                        'UPN': user.get('userPrincipalName', ''),
                        '言語設定': mailbox_stats.get('language', {}).get('displayName', '不明'),
                        'タイムゾーン': mailbox_stats.get('timeZone', '不明'),
                        '自動返信': '有効' if mailbox_stats.get('automaticRepliesSetting', {}).get('status') == 'enabled' else '無効',
                        '分析日時': datetime.now().strftime('%Y/%m/%d %H:%M:%S'),
                        'ステータス': '正常'
                    })
                    
                except Exception as user_error:
                    self.logger.warning(f"Failed to get mailbox for user {user.get('displayName')}: {user_error}")
                    continue
            
            return mailbox_data
            
        except Exception as e:
            self.logger.error(f"Failed to get mailbox analysis: {e}")
            return []


class ReportService:
    """Report generation service combining all data sources."""
    
    def __init__(self, graph_client: GraphClient):
        self.client = graph_client
        self.user_service = UserService(graph_client)
        self.license_service = LicenseService(graph_client)
        self.teams_service = TeamsService(graph_client)
        self.onedrive_service = OneDriveService(graph_client)
        self.exchange_service = ExchangeService(graph_client)
        self.logger = logging.getLogger(__name__)
    
    def generate_daily_report(self) -> List[Dict[str, Any]]:
        """Generate daily activity report."""
        try:
            # Combine data from multiple sources
            daily_data = []
            
            # Add user activity summary
            users = self.user_service.get_all_users(select=['displayName', 'signInActivity', 'accountEnabled'])
            
            active_users = sum(1 for user in users if user.get('accountEnabled', False))
            recent_signins = sum(1 for user in users 
                               if user.get('signInActivity', {}).get('lastSignInDateTime') 
                               and self._is_recent_signin(user.get('signInActivity', {}).get('lastSignInDateTime')))
            
            daily_data.append({
                '項目': '総ユーザー数',
                '値': len(users),
                '詳細': f'有効ユーザー: {active_users}名',
                'カテゴリ': 'ユーザー管理',
                '日付': datetime.now().strftime('%Y/%m/%d'),
                'ステータス': '正常'
            })
            
            daily_data.append({
                '項目': '本日のアクティブユーザー',
                '値': recent_signins,
                '詳細': f'24時間以内にサインインしたユーザー数',
                'カテゴリ': 'アクティビティ',
                '日付': datetime.now().strftime('%Y/%m/%d'),
                'ステータス': '正常' if recent_signins > 0 else '注意'
            })
            
            return daily_data
            
        except Exception as e:
            self.logger.error(f"Failed to generate daily report: {e}")
            return []
    
    def _is_recent_signin(self, signin_time: str) -> bool:
        """Check if signin time is within last 24 hours."""
        try:
            if not signin_time:
                return False
            
            signin_dt = datetime.fromisoformat(signin_time.replace('Z', '+00:00'))
            now = datetime.now(signin_dt.tzinfo)
            return (now - signin_dt).total_seconds() < 86400  # 24 hours
            
        except Exception:
            return False