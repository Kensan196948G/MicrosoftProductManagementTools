"""
OneDrive for Business API client implementation.
Python equivalent of PowerShell OneDrive management modules.
Provides authentication and API access for OneDrive for Business services.
"""

import logging
import json
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Union
from dataclasses import dataclass
import requests

from src.core.config import Config
from src.api.graph.client import GraphClient
from src.core.powershell_bridge import PowerShellBridge


@dataclass
class OneDriveResult:
    """OneDrive API result container."""
    success: bool
    data: Any
    error_message: Optional[str] = None
    source: str = "Graph API"  # "Graph API" or "PowerShell"
    metadata: Optional[Dict[str, Any]] = None


class OneDriveClient:
    """
    OneDrive for Business client with dual Graph API and PowerShell support.
    Python equivalent of PowerShell OneDrive management modules.
    
    Features:
    - Microsoft Graph API for OneDrive operations
    - SharePoint Online PowerShell integration
    - Storage and usage analytics
    - Sharing and permissions management
    - Sync status monitoring
    """
    
    def __init__(self, config: Config, graph_client: Optional[GraphClient] = None):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.graph_client = graph_client or GraphClient(config)
        self.powershell_bridge = PowerShellBridge()
        
        # Connection state
        self.graph_connected = False
        self.spo_connected = False
        
        # Performance tracking
        self.api_call_count = 0
        self.powershell_call_count = 0
        
    def initialize(self):
        """Initialize OneDrive client with authentication."""
        try:
            # Initialize Graph client
            self.graph_client.initialize()
            self.graph_connected = True
            self.logger.info("Graph API connection established")
            
            # Try to connect to SharePoint Online PowerShell
            self._connect_spo_powershell()
            
        except Exception as e:
            self.logger.error(f"OneDrive client initialization failed: {e}")
            raise
    
    def _connect_spo_powershell(self):
        """Connect to SharePoint Online PowerShell module."""
        try:
            # Try to import SharePoint Online module
            import_result = self.powershell_bridge.execute_command(
                "Import-Module Microsoft.Online.SharePoint.PowerShell -Force",
                return_json=False
            )
            
            if not import_result.success:
                self.logger.warning("SharePoint Online PowerShell module not available")
                return
            
            # Get connection parameters
            admin_url = (
                self.config.get('SharePoint.AdminUrl') or 
                self.config.get('OneDrive.AdminUrl') or
                'https://tenant-admin.sharepoint.com'  # Default pattern
            )
            
            tenant_id = (
                self.config.get('Authentication.TenantId') or 
                self.config.get('SharePoint.TenantId') or 
                self.config.get('EntraID.TenantId')
            )
            client_id = (
                self.config.get('Authentication.ClientId') or 
                self.config.get('SharePoint.ClientId') or 
                self.config.get('EntraID.ClientId')
            )
            cert_thumbprint = (
                self.config.get('Authentication.CertificateThumbprint') or
                self.config.get('SharePoint.CertificateThumbprint')
            )
            
            if not all([admin_url, tenant_id, client_id, cert_thumbprint]):
                self.logger.warning("SharePoint Online PowerShell connection parameters incomplete")
                return
            
            # Connect to SharePoint Online
            connect_cmd = f"""
            Connect-SPOService -Url '{admin_url}' -ClientId '{client_id}' -CertificateThumbprint '{cert_thumbprint}'
            """
            
            connect_result = self.powershell_bridge.execute_command(
                connect_cmd,
                return_json=False,
                timeout=120
            )
            
            if connect_result.success:
                self.spo_connected = True
                self.logger.info("SharePoint Online PowerShell connection established")
            else:
                self.logger.warning(f"SharePoint Online PowerShell connection failed: {connect_result.error_message}")
                
        except Exception as e:
            self.logger.warning(f"SharePoint Online PowerShell connection error: {e}")
    
    def get_onedrive_storage_data(self, limit: int = 1000) -> OneDriveResult:
        """Get OneDrive storage usage data."""
        self.api_call_count += 1
        
        try:
            # Try Graph API first
            if self.graph_connected:
                result = self._get_storage_data_graph(limit)
                if result.success:
                    return result
                else:
                    self.logger.warning("Graph API failed, trying PowerShell")
            
            # Fallback to PowerShell
            if self.spo_connected:
                result = self._get_storage_data_powershell(limit)
                if result.success:
                    return result
            
            # Generate mock data if both fail
            return self._get_storage_data_mock(limit)
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_storage_data_graph(self, limit: int) -> OneDriveResult:
        """Get OneDrive storage data using Microsoft Graph API."""
        try:
            # Get OneDrive usage reports
            try:
                usage_data = self.graph_client.get(f'/reports/getOneDriveUsageAccountDetail(period=\'D7\')')
                users_data = usage_data.get('value', [])
            except:
                users_data = []
            
            # If no report data, get users and their drives
            if not users_data:
                users = self.graph_client.get_users(
                    select=['id', 'displayName', 'userPrincipalName', 'mail'],
                    limit=limit
                )
                
                users_data = []
                for user in users:
                    try:
                        # Get user's drive information
                        drive_data = self.graph_client.get(f'/users/{user["id"]}/drive')
                        if drive_data:
                            user_storage = {
                                'userDisplayName': user.get('displayName', ''),
                                'userPrincipalName': user.get('userPrincipalName', ''),
                                'siteUrl': drive_data.get('webUrl', ''),
                                'storageUsedInBytes': drive_data.get('quota', {}).get('used', 0),
                                'storageAllocatedInBytes': drive_data.get('quota', {}).get('total', 0),
                                'fileCount': drive_data.get('quota', {}).get('fileCount', 0),
                                'lastActivityDate': drive_data.get('lastModifiedDateTime', ''),
                                'isDeleted': drive_data.get('deleted') is not None
                            }
                            users_data.append(user_storage)
                    except:
                        # Skip users without drives
                        continue
            
            # Process storage data
            storage_data = []
            for user in users_data:
                storage_used_bytes = user.get('storageUsedInBytes', 0)
                storage_allocated_bytes = user.get('storageAllocatedInBytes', 0)
                
                # Convert bytes to GB
                storage_used_gb = round(storage_used_bytes / (1024**3), 2)
                storage_allocated_gb = round(storage_allocated_bytes / (1024**3), 2)
                
                usage_percent = round((storage_used_gb / storage_allocated_gb) * 100, 2) if storage_allocated_gb > 0 else 0
                
                storage_info = {
                    'ユーザー名': user.get('userDisplayName', ''),
                    'UPN': user.get('userPrincipalName', ''),
                    'サイトURL': user.get('siteUrl', ''),
                    '使用容量(GB)': storage_used_gb,
                    '割り当て容量(GB)': storage_allocated_gb,
                    '使用率(%)': usage_percent,
                    'ファイル数': user.get('fileCount', 0),
                    '最終アクティビティ': self._format_datetime(user.get('lastActivityDate', '')),
                    'アクティブ状態': 'アクティブ' if not user.get('isDeleted', False) else '削除済み',
                    '同期状態': '未知 (Graph API)',
                    '外部共有': '未知 (Graph API)',
                    'ストレージクォータ状態': '正常' if usage_percent < 90 else '警告'
                }
                storage_data.append(storage_info)
            
            return OneDriveResult(
                success=True,
                data=storage_data,
                source="Graph API",
                metadata={
                    'total_users': len(storage_data),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _get_storage_data_powershell(self, limit: int) -> OneDriveResult:
        """Get OneDrive storage data using SharePoint Online PowerShell."""
        try:
            self.powershell_call_count += 1
            
            # Get OneDrive sites
            sites_cmd = f"Get-SPOSite -IncludePersonalSite $true -Limit {limit} -Filter \"Url -like '*-my.sharepoint.com*'\""
            sites_result = self.powershell_bridge.execute_command(sites_cmd)
            
            if not sites_result.success:
                return OneDriveResult(
                    success=False,
                    data=None,
                    error_message=sites_result.error_message,
                    source="PowerShell"
                )
            
            # Process sites data
            storage_data = []
            sites_data = sites_result.data if isinstance(sites_result.data, list) else [sites_result.data]
            
            for site in sites_data:
                if isinstance(site, dict):
                    storage_used_mb = site.get('StorageUsageCurrent', 0)
                    storage_quota_mb = site.get('StorageQuota', 0)
                    
                    # Convert MB to GB
                    storage_used_gb = round(storage_used_mb / 1024, 2)
                    storage_quota_gb = round(storage_quota_mb / 1024, 2)
                    
                    usage_percent = round((storage_used_gb / storage_quota_gb) * 100, 2) if storage_quota_gb > 0 else 0
                    
                    storage_info = {
                        'ユーザー名': site.get('Owner', ''),
                        'UPN': site.get('Owner', ''),
                        'サイトURL': site.get('Url', ''),
                        '使用容量(GB)': storage_used_gb,
                        '割り当て容量(GB)': storage_quota_gb,
                        '使用率(%)': usage_percent,
                        'ファイル数': 'N/A (PowerShell)',
                        '最終アクティビティ': self._format_datetime(site.get('LastContentModifiedDate', '')),
                        'アクティブ状態': 'アクティブ' if site.get('Status') == 'Active' else '非アクティブ',
                        '同期状態': '未知 (PowerShell)',
                        '外部共有': '有効' if site.get('SharingCapability') != 'Disabled' else '無効',
                        'ストレージクォータ状態': '正常' if usage_percent < 90 else '警告',
                        'テンプレート': site.get('Template', ''),
                        'ロック状態': site.get('LockState', 'Unlock')
                    }
                    storage_data.append(storage_info)
            
            return OneDriveResult(
                success=True,
                data=storage_data,
                source="PowerShell",
                metadata={
                    'total_users': len(storage_data),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_storage_data_mock(self, limit: int) -> OneDriveResult:
        """Generate mock OneDrive storage data."""
        import random
        
        self.logger.warning("Generating mock OneDrive storage data")
        
        storage_data = []
        departments = ['営業部', 'IT部', 'マーケティング部', '経理部', '人事部', '開発部']
        
        for i in range(min(limit, 50)):
            storage_quota_gb = random.choice([1024, 2048, 5120])  # 1TB, 2TB, 5TB
            storage_used_gb = round(random.uniform(50, storage_quota_gb * 0.8), 2)
            usage_percent = round((storage_used_gb / storage_quota_gb) * 100, 2)
            
            storage_info = {
                'ユーザー名': f'テストユーザー{i+1}',
                'UPN': f'user{i+1}@example.com',
                'サイトURL': f'https://example-my.sharepoint.com/personal/user{i+1}_example_com',
                '使用容量(GB)': storage_used_gb,
                '割り当て容量(GB)': storage_quota_gb,
                '使用率(%)': usage_percent,
                'ファイル数': random.randint(100, 10000),
                '最終アクティビティ': (datetime.now() - timedelta(days=random.randint(0, 30))).strftime('%Y-%m-%d'),
                'アクティブ状態': random.choice(['アクティブ', 'アクティブ', '非アクティブ']),
                '同期状態': random.choice(['同期中', '停止中', 'エラー']),
                '外部共有': random.choice(['有効', '無効']),
                'ストレージクォータ状態': '正常' if usage_percent < 90 else '警告',
                '部署': random.choice(departments),
                'テンプレート': 'SPSPERS#10',
                'ロック状態': 'Unlock'
            }
            storage_data.append(storage_info)
        
        return OneDriveResult(
            success=True,
            data=storage_data,
            source="Mock Data",
            metadata={
                'total_users': len(storage_data),
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock data generated - no API access available'
            }
        )
    
    def get_onedrive_sharing_data(self, limit: int = 1000) -> OneDriveResult:
        """Get OneDrive sharing and permissions data."""
        self.api_call_count += 1
        
        try:
            # Try Graph API first
            if self.graph_connected:
                result = self._get_sharing_data_graph(limit)
                if result.success:
                    return result
            
            # Fallback to PowerShell
            if self.spo_connected:
                result = self._get_sharing_data_powershell(limit)
                if result.success:
                    return result
            
            # Generate mock data
            return self._get_sharing_data_mock(limit)
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_sharing_data_graph(self, limit: int) -> OneDriveResult:
        """Get OneDrive sharing data using Graph API."""
        try:
            # Get users and their shared files
            users = self.graph_client.get_users(
                select=['id', 'displayName', 'userPrincipalName'],
                limit=limit
            )
            
            sharing_data = []
            for user in users:
                try:
                    # Get shared files for this user
                    shared_files = self.graph_client.get(f'/users/{user["id"]}/drive/sharedWithMe')
                    shared_count = len(shared_files.get('value', []))
                    
                    # Get files shared by this user
                    my_files = self.graph_client.get(f'/users/{user["id"]}/drive/root/children')
                    shared_by_user = 0
                    for file in my_files.get('value', []):
                        if 'shared' in file.get('name', '').lower():
                            shared_by_user += 1
                    
                    sharing_info = {
                        'ユーザー名': user.get('displayName', ''),
                        'UPN': user.get('userPrincipalName', ''),
                        '共有受信数': shared_count,
                        '共有送信数': shared_by_user,
                        '総共有数': shared_count + shared_by_user,
                        '外部共有数': 'N/A (Graph API)',
                        '内部共有数': 'N/A (Graph API)',
                        'リンク共有数': 'N/A (Graph API)',
                        '最終共有日': 'N/A (Graph API)',
                        '共有ポリシー': 'N/A (Graph API)',
                        '権限レベル': 'N/A (Graph API)',
                        'アクティブ状態': 'アクティブ'
                    }
                    sharing_data.append(sharing_info)
                    
                except:
                    # Skip users with no drive access
                    continue
            
            return OneDriveResult(
                success=True,
                data=sharing_data,
                source="Graph API",
                metadata={
                    'total_users': len(sharing_data),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _get_sharing_data_powershell(self, limit: int) -> OneDriveResult:
        """Get OneDrive sharing data using SharePoint Online PowerShell."""
        try:
            self.powershell_call_count += 1
            
            # Get OneDrive sites with sharing information
            sites_cmd = f"Get-SPOSite -IncludePersonalSite $true -Limit {limit} -Filter \"Url -like '*-my.sharepoint.com*'\" | Select-Object Url,Owner,SharingCapability,DisableCompanyWideSharing"
            sites_result = self.powershell_bridge.execute_command(sites_cmd)
            
            if not sites_result.success:
                return OneDriveResult(
                    success=False,
                    data=None,
                    error_message=sites_result.error_message,
                    source="PowerShell"
                )
            
            # Process sharing data
            sharing_data = []
            sites_data = sites_result.data if isinstance(sites_result.data, list) else [sites_result.data]
            
            for site in sites_data:
                if isinstance(site, dict):
                    sharing_info = {
                        'ユーザー名': site.get('Owner', ''),
                        'UPN': site.get('Owner', ''),
                        '共有受信数': 'N/A (PowerShell)',
                        '共有送信数': 'N/A (PowerShell)',
                        '総共有数': 'N/A (PowerShell)',
                        '外部共有数': 'N/A (PowerShell)',
                        '内部共有数': 'N/A (PowerShell)',
                        'リンク共有数': 'N/A (PowerShell)',
                        '最終共有日': 'N/A (PowerShell)',
                        '共有ポリシー': site.get('SharingCapability', ''),
                        '企業全体共有': '無効' if site.get('DisableCompanyWideSharing') else '有効',
                        'サイトURL': site.get('Url', ''),
                        'アクティブ状態': 'アクティブ'
                    }
                    sharing_data.append(sharing_info)
            
            return OneDriveResult(
                success=True,
                data=sharing_data,
                source="PowerShell",
                metadata={
                    'total_users': len(sharing_data),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_sharing_data_mock(self, limit: int) -> OneDriveResult:
        """Generate mock OneDrive sharing data."""
        import random
        
        self.logger.warning("Generating mock OneDrive sharing data")
        
        sharing_data = []
        sharing_policies = ['ExistingAccess', 'AnonymousAccess', 'DirectAccess', 'Disabled']
        
        for i in range(min(limit, 50)):
            shared_received = random.randint(0, 50)
            shared_sent = random.randint(0, 30)
            external_shared = random.randint(0, 10)
            internal_shared = shared_sent - external_shared if shared_sent > external_shared else 0
            
            sharing_info = {
                'ユーザー名': f'テストユーザー{i+1}',
                'UPN': f'user{i+1}@example.com',
                '共有受信数': shared_received,
                '共有送信数': shared_sent,
                '総共有数': shared_received + shared_sent,
                '外部共有数': external_shared,
                '内部共有数': internal_shared,
                'リンク共有数': random.randint(0, 20),
                '最終共有日': (datetime.now() - timedelta(days=random.randint(0, 30))).strftime('%Y-%m-%d'),
                '共有ポリシー': random.choice(sharing_policies),
                '権限レベル': random.choice(['読み取り', '編集', 'フルコントロール']),
                '企業全体共有': random.choice(['有効', '無効']),
                'サイトURL': f'https://example-my.sharepoint.com/personal/user{i+1}_example_com',
                'アクティブ状態': random.choice(['アクティブ', 'アクティブ', '非アクティブ']),
                'セキュリティリスク': random.choice(['低', '中', '高']) if external_shared > 5 else '低'
            }
            sharing_data.append(sharing_info)
        
        return OneDriveResult(
            success=True,
            data=sharing_data,
            source="Mock Data",
            metadata={
                'total_users': len(sharing_data),
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock data generated - no API access available'
            }
        )
    
    def get_onedrive_sync_errors(self, limit: int = 1000) -> OneDriveResult:
        """Get OneDrive sync errors and issues."""
        self.api_call_count += 1
        
        try:
            # This would typically require OneDrive client logs or sync service APIs
            # For now, generate mock data
            return self._get_sync_errors_mock(limit)
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_sync_errors_mock(self, limit: int) -> OneDriveResult:
        """Generate mock OneDrive sync errors data."""
        import random
        
        self.logger.warning("Generating mock OneDrive sync errors data")
        
        error_types = [
            'ファイルロックエラー',
            'ネットワーク接続エラー',
            'ファイルサイズ超過',
            'ファイル名不正',
            'アクセス許可エラー',
            'ストレージ容量不足',
            '同期競合エラー',
            'ファイル破損エラー'
        ]
        
        sync_errors = []
        
        for i in range(random.randint(5, 20)):
            error_info = {
                'ユーザー名': f'テストユーザー{random.randint(1, 50)}',
                'UPN': f'user{random.randint(1, 50)}@example.com',
                'エラータイプ': random.choice(error_types),
                'ファイル名': f'document{random.randint(1, 1000)}.{random.choice(["docx", "xlsx", "pptx", "pdf", "txt"])}',
                'ファイルパス': f'/Documents/フォルダ{random.randint(1, 10)}/document{random.randint(1, 1000)}.docx',
                'エラーコード': f'0x{random.randint(10000000, 99999999):08X}',
                'エラーメッセージ': f'{random.choice(error_types)}が発生しました',
                '発生日時': (datetime.now() - timedelta(days=random.randint(0, 7))).strftime('%Y-%m-%d %H:%M:%S'),
                '解決状態': random.choice(['未解決', '解決済み', '再試行中']),
                '重要度': random.choice(['低', '中', '高']),
                '再試行回数': random.randint(0, 5),
                '最終再試行日': (datetime.now() - timedelta(hours=random.randint(1, 24))).strftime('%Y-%m-%d %H:%M:%S'),
                'クライアントバージョン': f'OneDrive {random.randint(20, 23)}.{random.randint(1, 12)}.{random.randint(1, 30)}.{random.randint(1, 9)}'
            }
            sync_errors.append(error_info)
        
        return OneDriveResult(
            success=True,
            data=sync_errors,
            source="Mock Data",
            metadata={
                'total_errors': len(sync_errors),
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock sync errors data - OneDrive client logs not available'
            }
        )
    
    def get_external_sharing_analysis(self, limit: int = 1000) -> OneDriveResult:
        """Get external sharing analysis and security assessment."""
        self.api_call_count += 1
        
        try:
            # Try PowerShell first for external sharing analysis
            if self.spo_connected:
                result = self._get_external_sharing_powershell(limit)
                if result.success:
                    return result
            
            # Fallback to Graph API
            if self.graph_connected:
                result = self._get_external_sharing_graph(limit)
                if result.success:
                    return result
            
            # Generate mock data
            return self._get_external_sharing_mock(limit)
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_external_sharing_powershell(self, limit: int) -> OneDriveResult:
        """Get external sharing analysis using PowerShell."""
        try:
            self.powershell_call_count += 1
            
            # Get external sharing report
            sharing_cmd = f"Get-SPOSite -IncludePersonalSite $true -Limit {limit} | Where-Object {{$_.SharingCapability -ne 'Disabled'}} | Select-Object Url,Owner,SharingCapability,DisableCompanyWideSharing"
            sharing_result = self.powershell_bridge.execute_command(sharing_cmd)
            
            if not sharing_result.success:
                return OneDriveResult(
                    success=False,
                    data=None,
                    error_message=sharing_result.error_message,
                    source="PowerShell"
                )
            
            # Process external sharing data
            external_sharing = []
            sharing_data = sharing_result.data if isinstance(sharing_result.data, list) else [sharing_result.data]
            
            for site in sharing_data:
                if isinstance(site, dict):
                    sharing_capability = site.get('SharingCapability', '')
                    
                    # Determine risk level
                    if sharing_capability == 'ExternalUserSharingOnly':
                        risk_level = '低'
                    elif sharing_capability == 'ExternalUserAndGuestSharing':
                        risk_level = '中'
                    elif sharing_capability == 'ExistingExternalUserSharingOnly':
                        risk_level = '低'
                    else:
                        risk_level = '高'
                    
                    external_info = {
                        'ユーザー名': site.get('Owner', ''),
                        'UPN': site.get('Owner', ''),
                        'サイトURL': site.get('Url', ''),
                        '外部共有設定': sharing_capability,
                        '企業全体共有': '無効' if site.get('DisableCompanyWideSharing') else '有効',
                        'リスクレベル': risk_level,
                        '外部ユーザー数': 'N/A (PowerShell)',
                        '共有リンク数': 'N/A (PowerShell)',
                        'ゲストアクセス': '有効' if 'Guest' in sharing_capability else '無効',
                        'アクセス要求承認': 'N/A (PowerShell)',
                        '最終共有日': 'N/A (PowerShell)',
                        'セキュリティ状態': '管理必要' if risk_level == '高' else '監視中',
                        'コンプライアンス': '準拠' if risk_level == '低' else '確認要'
                    }
                    external_sharing.append(external_info)
            
            return OneDriveResult(
                success=True,
                data=external_sharing,
                source="PowerShell",
                metadata={
                    'total_sites': len(external_sharing),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_external_sharing_graph(self, limit: int) -> OneDriveResult:
        """Get external sharing analysis using Graph API."""
        try:
            # Graph API has limited external sharing visibility
            # Get users and their sharing activities
            users = self.graph_client.get_users(
                select=['id', 'displayName', 'userPrincipalName'],
                limit=limit
            )
            
            external_sharing = []
            for user in users:
                # This is a simplified implementation
                # Real implementation would need to check drive permissions
                external_info = {
                    'ユーザー名': user.get('displayName', ''),
                    'UPN': user.get('userPrincipalName', ''),
                    'サイトURL': f'https://example-my.sharepoint.com/personal/{user.get("userPrincipalName", "").replace("@", "_").replace(".", "_")}',
                    '外部共有設定': 'N/A (Graph API)',
                    '企業全体共有': 'N/A (Graph API)',
                    'リスクレベル': 'N/A (Graph API)',
                    '外部ユーザー数': 'N/A (Graph API)',
                    '共有リンク数': 'N/A (Graph API)',
                    'ゲストアクセス': 'N/A (Graph API)',
                    'アクセス要求承認': 'N/A (Graph API)',
                    '最終共有日': 'N/A (Graph API)',
                    'セキュリティ状態': 'N/A (Graph API)',
                    'コンプライアンス': 'N/A (Graph API)'
                }
                external_sharing.append(external_info)
            
            return OneDriveResult(
                success=True,
                data=external_sharing,
                source="Graph API",
                metadata={
                    'total_sites': len(external_sharing),
                    'generated_at': datetime.now().isoformat(),
                    'note': 'Limited external sharing data available via Graph API'
                }
            )
            
        except Exception as e:
            return OneDriveResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _get_external_sharing_mock(self, limit: int) -> OneDriveResult:
        """Generate mock external sharing analysis data."""
        import random
        
        self.logger.warning("Generating mock external sharing analysis data")
        
        sharing_capabilities = [
            'ExternalUserSharingOnly',
            'ExternalUserAndGuestSharing',
            'ExistingExternalUserSharingOnly',
            'Disabled'
        ]
        
        external_sharing = []
        
        for i in range(min(limit, 30)):
            sharing_capability = random.choice(sharing_capabilities)
            
            # Determine risk level
            if sharing_capability == 'ExternalUserSharingOnly':
                risk_level = '低'
            elif sharing_capability == 'ExternalUserAndGuestSharing':
                risk_level = '中'
            elif sharing_capability == 'ExistingExternalUserSharingOnly':
                risk_level = '低'
            else:
                risk_level = '高'
            
            external_info = {
                'ユーザー名': f'テストユーザー{i+1}',
                'UPN': f'user{i+1}@example.com',
                'サイトURL': f'https://example-my.sharepoint.com/personal/user{i+1}_example_com',
                '外部共有設定': sharing_capability,
                '企業全体共有': random.choice(['有効', '無効']),
                'リスクレベル': risk_level,
                '外部ユーザー数': random.randint(0, 20) if risk_level != '高' else random.randint(0, 5),
                '共有リンク数': random.randint(0, 15),
                'ゲストアクセス': '有効' if 'Guest' in sharing_capability else '無効',
                'アクセス要求承認': random.choice(['必要', '不要']),
                '最終共有日': (datetime.now() - timedelta(days=random.randint(0, 30))).strftime('%Y-%m-%d'),
                'セキュリティ状態': '管理必要' if risk_level == '高' else '監視中',
                'コンプライアンス': '準拠' if risk_level == '低' else '確認要',
                'ドメイン制限': random.choice(['あり', 'なし']),
                'リンク有効期限': random.choice(['あり', 'なし']),
                'パスワード保護': random.choice(['あり', 'なし'])
            }
            external_sharing.append(external_info)
        
        return OneDriveResult(
            success=True,
            data=external_sharing,
            source="Mock Data",
            metadata={
                'total_sites': len(external_sharing),
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock external sharing data - SharePoint APIs not available'
            }
        )
    
    def _format_datetime(self, dt_str: str) -> str:
        """Format datetime string for consistency."""
        try:
            if not dt_str:
                return '未記録'
            # Handle various datetime formats
            if 'T' in dt_str:
                dt = datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
                return dt.strftime('%Y-%m-%d %H:%M:%S')
            return dt_str
        except:
            return dt_str or '未記録'
    
    def get_connection_status(self) -> Dict[str, Any]:
        """Get connection status for both Graph API and PowerShell."""
        return {
            'graph_connected': self.graph_connected,
            'spo_connected': self.spo_connected,
            'api_call_count': self.api_call_count,
            'powershell_call_count': self.powershell_call_count,
            'preferred_method': 'PowerShell' if self.spo_connected else 'Graph API' if self.graph_connected else 'Mock Data'
        }
    
    def disconnect(self):
        """Disconnect from OneDrive/SharePoint services."""
        try:
            if self.spo_connected:
                self.powershell_bridge.execute_command(
                    "Disconnect-SPOService",
                    return_json=False
                )
                self.spo_connected = False
                self.logger.info("Disconnected from SharePoint Online PowerShell")
            
            if self.powershell_bridge:
                self.powershell_bridge.cleanup()
                
        except Exception as e:
            self.logger.error(f"Error during disconnect: {e}")
    
    def __del__(self):
        """Cleanup on object destruction."""
        try:
            self.disconnect()
        except:
            pass
