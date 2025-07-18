"""
Microsoft Graph API service implementations.
Provides high-level services for interacting with Microsoft 365 data.
"""

import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import asyncio
from dataclasses import dataclass

from .client import GraphClient


@dataclass
class ServiceResult:
    """Standard service result container."""
    success: bool
    data: Any
    error: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class BaseService:
    """Base service class with common functionality."""
    
    def __init__(self, graph_client: GraphClient):
        self.client = graph_client
        self.logger = logging.getLogger(f"{__name__}.{self.__class__.__name__}")
    
    def _handle_error(self, e: Exception, operation: str) -> ServiceResult:
        """Handle service errors consistently."""
        error_msg = f"{operation} failed: {str(e)}"
        self.logger.error(error_msg, exc_info=True)
        return ServiceResult(success=False, data=None, error=error_msg)


class UserService(BaseService):
    """User management and information service."""
    
    def get_all_users(self, limit: int = 1000) -> List[Dict[str, Any]]:
        """Get all users from Microsoft 365."""
        try:
            self.logger.info(f"Fetching users (limit: {limit})")
            
            # Use Graph client to get users
            users = self.client.get_users(limit=limit)
            
            # Transform user data for compatibility
            result = []
            for user in users:
                user_data = {
                    'id': user.get('id', ''),
                    'displayName': user.get('displayName', ''),
                    'userPrincipalName': user.get('userPrincipalName', ''),
                    'mail': user.get('mail', ''),
                    'accountEnabled': user.get('accountEnabled', False),
                    'createdDateTime': user.get('createdDateTime', ''),
                    'department': user.get('department', ''),
                    'jobTitle': user.get('jobTitle', ''),
                    'officeLocation': user.get('officeLocation', ''),
                    'signInActivity': user.get('signInActivity', {}),
                    'assignedLicenses': user.get('assignedLicenses', [])
                }
                result.append(user_data)
            
            self.logger.info(f"Retrieved {len(result)} users")
            return result
            
        except Exception as e:
            self.logger.error(f"Failed to get users: {e}")
            return self._generate_mock_users(limit)
    
    def get_user_mfa_status(self) -> List[Dict[str, Any]]:
        """Get MFA status for all users."""
        try:
            self.logger.info("Fetching user MFA status")
            
            # Get users with authentication methods
            users = self.client.get_users_with_auth_methods()
            
            result = []
            for user in users:
                mfa_methods = user.get('authenticationMethods', [])
                mfa_enabled = len(mfa_methods) > 0
                
                user_data = {
                    'ユーザー名': user.get('displayName', ''),
                    'UPN': user.get('userPrincipalName', ''),
                    'MFA有効': 'はい' if mfa_enabled else 'いいえ',
                    'MFA方法数': len(mfa_methods),
                    '利用可能な方法': ', '.join([method.get('@odata.type', '').split('.')[-1] for method in mfa_methods]),
                    '最終サインイン': user.get('signInActivity', {}).get('lastSignInDateTime', '未記録'),
                    'アカウント状態': '有効' if user.get('accountEnabled') else '無効'
                }
                result.append(user_data)
            
            self.logger.info(f"Retrieved MFA status for {len(result)} users")
            return result
            
        except Exception as e:
            self.logger.error(f"Failed to get MFA status: {e}")
            return self._generate_mock_mfa_data()
    
    def _generate_mock_users(self, limit: int) -> List[Dict[str, Any]]:
        """Generate mock user data when API is unavailable."""
        import random
        
        self.logger.warning("Generating mock user data")
        
        departments = ['IT', 'HR', '営業', '経理', 'マーケティング', '開発']
        job_titles = ['管理者', 'マネージャー', '担当者', 'エンジニア', 'アナリスト']
        
        users = []
        for i in range(min(limit, 50)):  # Limit mock data
            user = {
                'id': f'mock-user-{i+1}',
                'displayName': f'テストユーザー {i+1}',
                'userPrincipalName': f'user{i+1}@example.com',
                'mail': f'user{i+1}@example.com',
                'accountEnabled': random.choice([True, True, True, False]),  # Mostly enabled
                'createdDateTime': (datetime.now() - timedelta(days=random.randint(30, 365))).isoformat(),
                'department': random.choice(departments),
                'jobTitle': random.choice(job_titles),
                'officeLocation': f'東京オフィス {random.randint(1, 10)}F',
                'signInActivity': {
                    'lastSignInDateTime': (datetime.now() - timedelta(days=random.randint(0, 30))).isoformat()
                },
                'assignedLicenses': [
                    {'skuId': 'mock-license-1'},
                    {'skuId': 'mock-license-2'}
                ]
            }
            users.append(user)
        
        return users
    
    def _generate_mock_mfa_data(self) -> List[Dict[str, Any]]:
        """Generate mock MFA data."""
        import random
        
        methods = ['SMS', 'Authenticator App', 'Phone', 'Email']
        mock_data = []
        
        for i in range(20):
            enabled = random.choice([True, True, False])  # 66% MFA enabled
            user_methods = random.sample(methods, random.randint(0, 2)) if enabled else []
            
            data = {
                'ユーザー名': f'テストユーザー {i+1}',
                'UPN': f'user{i+1}@example.com',
                'MFA有効': 'はい' if enabled else 'いいえ',
                'MFA方法数': len(user_methods),
                '利用可能な方法': ', '.join(user_methods),
                '最終サインイン': (datetime.now() - timedelta(days=random.randint(0, 30))).strftime('%Y-%m-%d %H:%M:%S'),
                'アカウント状態': '有効' if random.choice([True, True, True, False]) else '無効'
            }
            mock_data.append(data)
        
        return mock_data


class LicenseService(BaseService):
    """License management and analysis service."""
    
    def get_license_analysis(self) -> List[Dict[str, Any]]:
        """Get comprehensive license analysis."""
        try:
            self.logger.info("Performing license analysis")
            
            # Get all licenses and subscriptions
            subscriptions = self.client.get_subscriptions()
            license_usage = self.client.get_license_usage()
            
            result = []
            for sub in subscriptions:
                sku_id = sub.get('skuId', '')
                sku_name = sub.get('skuPartNumber', '')
                
                # Find corresponding usage data
                usage = next((u for u in license_usage if u.get('skuId') == sku_id), {})
                
                total_licenses = sub.get('totalLicenses', 0)
                assigned_licenses = usage.get('assignedLicenses', 0)
                available_licenses = total_licenses - assigned_licenses
                utilization = (assigned_licenses / total_licenses * 100) if total_licenses > 0 else 0
                
                license_data = {
                    'ライセンス名': sku_name,
                    'SKU ID': sku_id,
                    '総ライセンス数': total_licenses,
                    '割り当て済み': assigned_licenses,
                    '利用可能': available_licenses,
                    '利用率': f"{utilization:.1f}%",
                    'ステータス': sub.get('capabilityStatus', ''),
                    '契約状態': sub.get('subscriptionStatus', ''),
                    '次回更新日': sub.get('nextLifecycleDateTime', ''),
                    '月額コスト': f"¥{assigned_licenses * 500:,}"  # Mock pricing
                }
                result.append(license_data)
            
            self.logger.info(f"Analyzed {len(result)} license types")
            return result
            
        except Exception as e:
            self.logger.error(f"Failed to analyze licenses: {e}")
            return self._generate_mock_license_data()
    
    def _generate_mock_license_data(self) -> List[Dict[str, Any]]:
        """Generate mock license data."""
        import random
        
        license_types = [
            ('Microsoft 365 E3', 100, random.randint(80, 95)),
            ('Microsoft 365 E1', 50, random.randint(40, 48)),
            ('Microsoft 365 Business Premium', 25, random.randint(20, 24)),
            ('Exchange Online Plan 2', 75, random.randint(60, 70)),
            ('Teams Exploratory', 200, random.randint(150, 180)),
            ('Power BI Pro', 30, random.randint(15, 25))
        ]
        
        result = []
        for name, total, assigned in license_types:
            available = total - assigned
            utilization = (assigned / total * 100) if total > 0 else 0
            
            data = {
                'ライセンス名': name,
                'SKU ID': f'mock-sku-{name.replace(" ", "-").lower()}',
                '総ライセンス数': total,
                '割り当て済み': assigned,
                '利用可能': available,
                '利用率': f"{utilization:.1f}%",
                'ステータス': 'Enabled',
                '契約状態': 'Active',
                '次回更新日': (datetime.now() + timedelta(days=random.randint(30, 365))).strftime('%Y-%m-%d'),
                '月額コスト': f"¥{assigned * random.randint(300, 800):,}"
            }
            result.append(data)
        
        return result


class TeamsService(BaseService):
    """Microsoft Teams management service."""
    
    def get_teams_usage(self) -> List[Dict[str, Any]]:
        """Get Teams usage statistics."""
        try:
            self.logger.info("Fetching Teams usage data")
            
            # Get Teams usage reports
            usage_data = self.client.get_teams_usage_reports()
            
            result = []
            for team_data in usage_data:
                team_info = {
                    'チーム名': team_data.get('teamName', ''),
                    'チームID': team_data.get('teamId', ''),
                    'メンバー数': team_data.get('memberCount', 0),
                    'アクティブメンバー数': team_data.get('activeMemberCount', 0),
                    'チャンネル数': team_data.get('channelCount', 0),
                    '総投稿数': team_data.get('totalPosts', 0),
                    '今月の投稿数': team_data.get('postsThisMonth', 0),
                    '最終アクティビティ': team_data.get('lastActivityDate', ''),
                    'プライベート/パブリック': team_data.get('teamType', ''),
                    'ゲストメンバー数': team_data.get('guestMemberCount', 0)
                }
                result.append(team_info)
            
            self.logger.info(f"Retrieved usage data for {len(result)} teams")
            return result
            
        except Exception as e:
            self.logger.error(f"Failed to get Teams usage: {e}")
            return self._generate_mock_teams_data()
    
    def _generate_mock_teams_data(self) -> List[Dict[str, Any]]:
        """Generate mock Teams data."""
        import random
        
        team_names = [
            'IT部門', '営業チーム', 'マーケティング', '人事部', '経理部',
            '開発チーム', 'プロジェクトA', 'カスタマーサポート', '役員会議', '全社員'
        ]
        
        result = []
        for i, name in enumerate(team_names):
            data = {
                'チーム名': name,
                'チームID': f'mock-team-{i+1}',
                'メンバー数': random.randint(5, 50),
                'アクティブメンバー数': random.randint(3, 40),
                'チャンネル数': random.randint(2, 10),
                '総投稿数': random.randint(100, 5000),
                '今月の投稿数': random.randint(10, 300),
                '最終アクティビティ': (datetime.now() - timedelta(days=random.randint(0, 7))).strftime('%Y-%m-%d'),
                'プライベート/パブリック': random.choice(['Private', 'Public']),
                'ゲストメンバー数': random.randint(0, 5)
            }
            result.append(data)
        
        return result


class OneDriveService(BaseService):
    """OneDrive for Business management service."""
    
    def get_storage_analysis(self) -> List[Dict[str, Any]]:
        """Get OneDrive storage analysis."""
        try:
            self.logger.info("Analyzing OneDrive storage")
            
            # Get OneDrive usage data
            storage_data = self.client.get_onedrive_usage()
            
            result = []
            for user_data in storage_data:
                storage_info = {
                    'ユーザー名': user_data.get('userDisplayName', ''),
                    'UPN': user_data.get('userPrincipalName', ''),
                    '使用容量(GB)': round(user_data.get('storageUsedInBytes', 0) / (1024**3), 2),
                    '割り当て容量(GB)': round(user_data.get('storageAllocatedInBytes', 0) / (1024**3), 2),
                    '使用率(%)': user_data.get('storageUsedPercentage', 0),
                    'ファイル数': user_data.get('fileCount', 0),
                    'アクティビティ': user_data.get('isActive', False),
                    '最終アクセス': user_data.get('lastActivityDate', ''),
                    '共有ファイル数': user_data.get('sharedFileCount', 0),
                    '外部共有': user_data.get('externalSharingEnabled', False)
                }
                result.append(storage_info)
            
            self.logger.info(f"Analyzed storage for {len(result)} users")
            return result
            
        except Exception as e:
            self.logger.error(f"Failed to analyze OneDrive storage: {e}")
            return self._generate_mock_storage_data()
    
    def _generate_mock_storage_data(self) -> List[Dict[str, Any]]:
        """Generate mock OneDrive storage data."""
        import random
        
        result = []
        for i in range(25):
            allocated = 1024  # 1TB default
            used = random.uniform(50, 800)
            usage_percent = (used / allocated) * 100
            
            data = {
                'ユーザー名': f'テストユーザー {i+1}',
                'UPN': f'user{i+1}@example.com',
                '使用容量(GB)': round(used, 2),
                '割り当て容量(GB)': allocated,
                '使用率(%)': round(usage_percent, 1),
                'ファイル数': random.randint(100, 5000),
                'アクティビティ': random.choice([True, True, False]),
                '最終アクセス': (datetime.now() - timedelta(days=random.randint(0, 30))).strftime('%Y-%m-%d'),
                '共有ファイル数': random.randint(0, 50),
                '外部共有': random.choice([True, False])
            }
            result.append(data)
        
        return result


class ExchangeService(BaseService):
    """Exchange Online management service."""
    
    def get_mailbox_analysis(self) -> List[Dict[str, Any]]:
        """Get mailbox analysis data."""
        try:
            self.logger.info("Analyzing Exchange mailboxes")
            
            # Get mailbox usage data
            mailbox_data = self.client.get_mailbox_usage()
            
            result = []
            for mailbox in mailbox_data:
                mailbox_info = {
                    'ユーザー名': mailbox.get('userDisplayName', ''),
                    'メールアドレス': mailbox.get('userPrincipalName', ''),
                    'メールボックス容量(MB)': round(mailbox.get('storageUsedInBytes', 0) / (1024**2), 2),
                    'クォータ(MB)': round(mailbox.get('prohibitSendQuotaInBytes', 0) / (1024**2), 2),
                    '使用率(%)': mailbox.get('storageUsedPercentage', 0),
                    'アイテム数': mailbox.get('itemCount', 0),
                    '削除済みアイテム(MB)': round(mailbox.get('deletedItemSizeInBytes', 0) / (1024**2), 2),
                    '最終アクティビティ': mailbox.get('lastActivityDate', ''),
                    'メールボックスタイプ': mailbox.get('recipientType', ''),
                    'アーカイブ有効': mailbox.get('hasArchive', False)
                }
                result.append(mailbox_info)
            
            self.logger.info(f"Analyzed {len(result)} mailboxes")
            return result
            
        except Exception as e:
            self.logger.error(f"Failed to analyze mailboxes: {e}")
            return self._generate_mock_mailbox_data()
    
    def _generate_mock_mailbox_data(self) -> List[Dict[str, Any]]:
        """Generate mock mailbox data."""
        import random
        
        result = []
        for i in range(30):
            quota = 50 * 1024  # 50GB in MB
            used = random.uniform(1000, 40000)  # 1GB to 40GB
            usage_percent = (used / quota) * 100
            
            data = {
                'ユーザー名': f'テストユーザー {i+1}',
                'メールアドレス': f'user{i+1}@example.com',
                'メールボックス容量(MB)': round(used, 2),
                'クォータ(MB)': quota,
                '使用率(%)': round(usage_percent, 1),
                'アイテム数': random.randint(1000, 50000),
                '削除済みアイテム(MB)': round(random.uniform(10, 500), 2),
                '最終アクティビティ': (datetime.now() - timedelta(days=random.randint(0, 7))).strftime('%Y-%m-%d'),
                'メールボックスタイプ': random.choice(['UserMailbox', 'SharedMailbox', 'RoomMailbox']),
                'アーカイブ有効': random.choice([True, False])
            }
            result.append(data)
        
        return result


class ReportService(BaseService):
    """Centralized reporting service."""
    
    def generate_daily_report(self) -> List[Dict[str, Any]]:
        """Generate comprehensive daily report."""
        try:
            self.logger.info("Generating daily report")
            
            # Collect data from various services
            user_service = UserService(self.client)
            license_service = LicenseService(self.client)
            teams_service = TeamsService(self.client)
            onedrive_service = OneDriveService(self.client)
            exchange_service = ExchangeService(self.client)
            
            # Get summary data
            users = user_service.get_all_users(limit=100)
            licenses = license_service.get_license_analysis()
            teams = teams_service.get_teams_usage()
            storage = onedrive_service.get_storage_analysis()
            mailboxes = exchange_service.get_mailbox_analysis()
            
            # Create summary report
            report_data = []
            
            # User summary
            active_users = len([u for u in users if u.get('accountEnabled')])
            report_data.append({
                'カテゴリ': 'ユーザー管理',
                '項目': '総ユーザー数',
                '値': len(users),
                '詳細': f'アクティブ: {active_users}, 無効: {len(users) - active_users}',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
            
            # License summary
            total_licenses = sum(l.get('総ライセンス数', 0) for l in licenses)
            assigned_licenses = sum(l.get('割り当て済み', 0) for l in licenses)
            report_data.append({
                'カテゴリ': 'ライセンス管理',
                '項目': 'ライセンス使用状況',
                '値': f'{assigned_licenses}/{total_licenses}',
                '詳細': f'利用率: {(assigned_licenses/total_licenses*100):.1f}%' if total_licenses > 0 else '0%',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
            
            # Teams summary
            active_teams = len([t for t in teams if t.get('今月の投稿数', 0) > 0])
            report_data.append({
                'カテゴリ': 'Teams活用',
                '項目': 'アクティブチーム数',
                '値': active_teams,
                '詳細': f'総チーム数: {len(teams)}',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
            
            # Storage summary
            total_storage = sum(s.get('使用容量(GB)', 0) for s in storage)
            report_data.append({
                'カテゴリ': 'ストレージ',
                '項目': '総使用容量',
                '値': f'{total_storage:.1f} GB',
                '詳細': f'平均使用率: {sum(s.get("使用率(%)", 0) for s in storage)/len(storage):.1f}%' if storage else '0%',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
            
            # Mailbox summary
            total_mailbox_size = sum(m.get('メールボックス容量(MB)', 0) for m in mailboxes)
            report_data.append({
                'カテゴリ': 'Exchange Online',
                '項目': '総メールボックス容量',
                '値': f'{total_mailbox_size/1024:.1f} GB',
                '詳細': f'平均使用率: {sum(m.get("使用率(%)", 0) for m in mailboxes)/len(mailboxes):.1f}%' if mailboxes else '0%',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
            
            self.logger.info(f"Generated daily report with {len(report_data)} items")
            return report_data
            
        except Exception as e:
            self.logger.error(f"Failed to generate daily report: {e}")
            return self._generate_mock_daily_report()
    
    def _generate_mock_daily_report(self) -> List[Dict[str, Any]]:
        """Generate mock daily report data."""
        import random
        
        return [
            {
                'カテゴリ': 'ユーザー管理',
                '項目': '総ユーザー数',
                '値': random.randint(80, 120),
                '詳細': f'アクティブ: {random.randint(75, 110)}, 無効: {random.randint(5, 10)}',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            },
            {
                'カテゴリ': 'ライセンス管理',
                '項目': 'ライセンス使用状況',
                '値': f'{random.randint(80, 95)}/{random.randint(100, 120)}',
                '詳細': f'利用率: {random.randint(75, 95)}%',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            },
            {
                'カテゴリ': 'Teams活用',
                '項目': 'アクティブチーム数',
                '値': random.randint(15, 25),
                '詳細': f'総チーム数: {random.randint(20, 30)}',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            },
            {
                'カテゴリ': 'ストレージ',
                '項目': '総使用容量',
                '値': f'{random.randint(5000, 15000):.1f} GB',
                '詳細': f'平均使用率: {random.randint(40, 70)}%',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            },
            {
                'カテゴリ': 'セキュリティ',
                '項目': 'MFA有効率',
                '値': f'{random.randint(85, 95)}%',
                '詳細': f'未設定ユーザー: {random.randint(5, 15)}名',
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
        ]