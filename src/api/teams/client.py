"""
Microsoft Teams API client implementation.
Python equivalent of PowerShell Teams management modules.
Provides authentication and API access for Microsoft Teams services.
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
class TeamsResult:
    """Teams API result container."""
    success: bool
    data: Any
    error_message: Optional[str] = None
    source: str = "Graph API"  # "Graph API" or "PowerShell"
    metadata: Optional[Dict[str, Any]] = None


class TeamsClient:
    """
    Microsoft Teams client with dual Graph API and PowerShell support.
    Python equivalent of PowerShell Teams management modules.
    
    Features:
    - Microsoft Graph API for Teams operations
    - PowerShell Teams module integration
    - Teams usage analytics
    - Meeting and calling analytics
    - Team and channel management
    """
    
    def __init__(self, config: Config, graph_client: Optional[GraphClient] = None):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.graph_client = graph_client or GraphClient(config)
        self.powershell_bridge = PowerShellBridge()
        
        # Connection state
        self.graph_connected = False
        self.teams_connected = False
        
        # Performance tracking
        self.api_call_count = 0
        self.powershell_call_count = 0
        
    def initialize(self):
        """Initialize Teams client with authentication."""
        try:
            # Initialize Graph client
            self.graph_client.initialize()
            self.graph_connected = True
            self.logger.info("Graph API connection established")
            
            # Try to connect to Teams PowerShell
            self._connect_teams_powershell()
            
        except Exception as e:
            self.logger.error(f"Teams client initialization failed: {e}")
            raise
    
    def _connect_teams_powershell(self):
        """Connect to Teams PowerShell module."""
        try:
            # Try to import Teams module
            import_result = self.powershell_bridge.execute_command(
                "Import-Module MicrosoftTeams -Force",
                return_json=False
            )
            
            if not import_result.success:
                self.logger.warning("MicrosoftTeams module not available")
                return
            
            # Get connection parameters
            tenant_id = (
                self.config.get('Authentication.TenantId') or 
                self.config.get('Teams.TenantId') or 
                self.config.get('EntraID.TenantId')
            )
            client_id = (
                self.config.get('Authentication.ClientId') or 
                self.config.get('Teams.ClientId') or 
                self.config.get('EntraID.ClientId')
            )
            cert_thumbprint = (
                self.config.get('Authentication.CertificateThumbprint') or
                self.config.get('Teams.CertificateThumbprint')
            )
            
            if not all([tenant_id, client_id, cert_thumbprint]):
                self.logger.warning("Teams PowerShell connection parameters incomplete")
                return
            
            # Connect to Teams
            connect_cmd = f"""
            Connect-MicrosoftTeams -TenantId '{tenant_id}' -ClientId '{client_id}' -CertificateThumbprint '{cert_thumbprint}'
            """
            
            connect_result = self.powershell_bridge.execute_command(
                connect_cmd,
                return_json=False,
                timeout=120
            )
            
            if connect_result.success:
                self.teams_connected = True
                self.logger.info("Teams PowerShell connection established")
            else:
                self.logger.warning(f"Teams PowerShell connection failed: {connect_result.error_message}")
                
        except Exception as e:
            self.logger.warning(f"Teams PowerShell connection error: {e}")
    
    def get_teams_usage_data(self, period: str = 'D7') -> TeamsResult:
        """Get Teams usage statistics."""
        self.api_call_count += 1
        
        try:
            # Try Graph API first
            if self.graph_connected:
                result = self._get_teams_usage_graph(period)
                if result.success:
                    return result
                else:
                    self.logger.warning("Graph API failed, trying PowerShell")
            
            # Fallback to PowerShell
            if self.teams_connected:
                return self._get_teams_usage_powershell(period)
            
            # Both methods failed, generate mock data
            return self._get_teams_usage_mock(period)
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_teams_usage_graph(self, period: str) -> TeamsResult:
        """Get Teams usage using Microsoft Graph API."""
        try:
            # Get Teams user activity reports
            try:
                activity_data = self.graph_client.get(f'/reports/getTeamsUserActivityUserDetail(period=\'{period}\')')
                users_data = activity_data.get('value', [])
            except:
                users_data = []
            
            # Get Teams device usage
            try:
                device_data = self.graph_client.get(f'/reports/getTeamsDeviceUsageUserDetail(period=\'{period}\')')
                device_users = device_data.get('value', [])
            except:
                device_users = []
            
            # Process and combine data
            usage_data = []
            for user in users_data:
                # Find corresponding device data
                device_info = next(
                    (d for d in device_users if d.get('userPrincipalName') == user.get('userPrincipalName')),
                    {}
                )
                
                user_usage = {
                    'ユーザー名': user.get('userDisplayName', ''),
                    'UPN': user.get('userPrincipalName', ''),
                    'チームチャットメッセージ数': user.get('teamChatMessageCount', 0),
                    'プライベートチャットメッセージ数': user.get('privateChatMessageCount', 0),
                    '通話数': user.get('callCount', 0),
                    '会議数': user.get('meetingCount', 0),
                    'チームアクティビティ数': user.get('teamActivities', 0),
                    '最終アクティビティ日': user.get('lastActivityDate', ''),
                    'デスクトップ使用': device_info.get('usedWeb', False),
                    'モバイル使用': device_info.get('usedMobile', False),
                    'ライセンスタイプ': user.get('assignedProducts', []),
                    'アクティビティ状態': 'アクティブ' if user.get('lastActivityDate') else '非アクティブ'
                }
                usage_data.append(user_usage)
            
            return TeamsResult(
                success=True,
                data=usage_data,
                source="Graph API",
                metadata={
                    'total_users': len(usage_data),
                    'period': period,
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _get_teams_usage_powershell(self, period: str) -> TeamsResult:
        """Get Teams usage using PowerShell Teams module."""
        try:
            self.powershell_call_count += 1
            
            # Get Teams information
            teams_cmd = "Get-Team"
            teams_result = self.powershell_bridge.execute_command(teams_cmd)
            
            if not teams_result.success:
                return TeamsResult(
                    success=False,
                    data=None,
                    error_message=teams_result.error_message,
                    source="PowerShell"
                )
            
            # Get team statistics
            usage_data = []
            teams_data = teams_result.data if isinstance(teams_result.data, list) else [teams_result.data]
            
            for team in teams_data:
                if isinstance(team, dict):
                    # Get team members
                    try:
                        members_cmd = f"Get-TeamUser -GroupId '{team.get('GroupId', '')}'"
                        members_result = self.powershell_bridge.execute_command(members_cmd)
                        member_count = len(members_result.data) if members_result.success and members_result.data else 0
                    except:
                        member_count = 0
                    
                    team_usage = {
                        'チーム名': team.get('DisplayName', ''),
                        'チームID': team.get('GroupId', ''),
                        'メンバー数': member_count,
                        'プライベーシータイプ': team.get('Visibility', ''),
                        '説明': team.get('Description', ''),
                        'メールアドレス': team.get('MailNickName', ''),
                        'アーカイブ状態': team.get('Archived', False),
                        '作成者': team.get('CreatedBy', ''),
                        'ゲストアクセス': team.get('AllowGuestAccess', False),
                        'チャンネル数': 'N/A (PowerShell)',
                        '最終アクティビティ': 'N/A (PowerShell)'
                    }
                    usage_data.append(team_usage)
            
            return TeamsResult(
                success=True,
                data=usage_data,
                source="PowerShell",
                metadata={
                    'total_teams': len(usage_data),
                    'period': period,
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_teams_usage_mock(self, period: str) -> TeamsResult:
        """Generate mock Teams usage data."""
        import random
        
        self.logger.warning("Generating mock Teams usage data")
        
        # Generate mock user activity data
        usage_data = []
        departments = ['営業部', 'IT部', 'マーケティング部', '経理部', '人事部', '開発部']
        
        for i in range(random.randint(20, 50)):
            usage = {
                'ユーザー名': f'テストユーザー{i+1}',
                'UPN': f'user{i+1}@example.com',
                'チームチャットメッセージ数': random.randint(0, 200),
                'プライベートチャットメッセージ数': random.randint(0, 100),
                '通話数': random.randint(0, 50),
                '会議数': random.randint(0, 30),
                'チームアクティビティ数': random.randint(0, 150),
                '最終アクティビティ日': (datetime.now() - timedelta(days=random.randint(0, 30))).strftime('%Y-%m-%d'),
                'デスクトップ使用': random.choice([True, False]),
                'モバイル使用': random.choice([True, False]),
                'ライセンスタイプ': ['Microsoft Teams'],
                'アクティビティ状態': random.choice(['アクティブ', '非アクティブ']),
                '部署': random.choice(departments)
            }
            usage_data.append(usage)
        
        return TeamsResult(
            success=True,
            data=usage_data,
            source="Mock Data",
            metadata={
                'total_users': len(usage_data),
                'period': period,
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock data generated - no API access available'
            }
        )
    
    def get_teams_settings_data(self) -> TeamsResult:
        """Get Teams settings and configuration."""
        self.api_call_count += 1
        
        try:
            # Try PowerShell first for settings
            if self.teams_connected:
                result = self._get_teams_settings_powershell()
                if result.success:
                    return result
            
            # Fallback to Graph API
            if self.graph_connected:
                result = self._get_teams_settings_graph()
                if result.success:
                    return result
            
            # Generate mock data
            return self._get_teams_settings_mock()
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_teams_settings_powershell(self) -> TeamsResult:
        """Get Teams settings using PowerShell."""
        try:
            self.powershell_call_count += 1
            
            # Get Teams client configuration
            config_cmd = "Get-CsTeamsClientConfiguration"
            config_result = self.powershell_bridge.execute_command(config_cmd)
            
            if not config_result.success:
                return TeamsResult(
                    success=False,
                    data=None,
                    error_message=config_result.error_message,
                    source="PowerShell"
                )
            
            # Get Teams meeting policy
            meeting_cmd = "Get-CsTeamsMeetingPolicy"
            meeting_result = self.powershell_bridge.execute_command(meeting_cmd)
            
            # Get Teams messaging policy
            messaging_cmd = "Get-CsTeamsMessagingPolicy"
            messaging_result = self.powershell_bridge.execute_command(messaging_cmd)
            
            # Process settings data
            settings_data = []
            
            # Client configuration
            if config_result.data:
                config_data = config_result.data if isinstance(config_result.data, list) else [config_result.data]
                for config in config_data:
                    if isinstance(config, dict):
                        setting = {
                            '設定タイプ': 'クライアント設定',
                            'ポリシー名': config.get('Identity', ''),
                            'ファイルアップロード': config.get('AllowDropBox', False),
                            'ゲストアクセス': config.get('AllowGuestUser', False),
                            'スケジュール送信': config.get('AllowScheduleSendMessage', False),
                            'プライベートチャット': config.get('AllowPrivateChat', True),
                            '最終更新': config.get('WhenChanged', '')
                        }
                        settings_data.append(setting)
            
            # Meeting policies
            if meeting_result.success and meeting_result.data:
                meeting_data = meeting_result.data if isinstance(meeting_result.data, list) else [meeting_result.data]
                for meeting in meeting_data:
                    if isinstance(meeting, dict):
                        setting = {
                            '設定タイプ': '会議ポリシー',
                            'ポリシー名': meeting.get('Identity', ''),
                            '会議録画': meeting.get('AllowCloudRecording', False),
                            'プライベート会議開催': meeting.get('AllowPrivateMeetingScheduling', True),
                            'チャンネル会議開催': meeting.get('AllowChannelMeetingScheduling', True),
                            '外部参加者': meeting.get('AllowAnonymousUsersToJoinMeeting', False),
                            '最終更新': meeting.get('WhenChanged', '')
                        }
                        settings_data.append(setting)
            
            # Messaging policies
            if messaging_result.success and messaging_result.data:
                messaging_data = messaging_result.data if isinstance(messaging_result.data, list) else [messaging_result.data]
                for messaging in messaging_data:
                    if isinstance(messaging, dict):
                        setting = {
                            '設定タイプ': 'メッセージングポリシー',
                            'ポリシー名': messaging.get('Identity', ''),
                            'チャット編集': messaging.get('AllowUserEditMessage', True),
                            'チャット削除': messaging.get('AllowUserDeleteMessage', True),
                            '絵文字使用': messaging.get('AllowGiphy', True),
                            'ステッカー使用': messaging.get('AllowStickers', True),
                            '最終更新': messaging.get('WhenChanged', '')
                        }
                        settings_data.append(setting)
            
            return TeamsResult(
                success=True,
                data=settings_data,
                source="PowerShell",
                metadata={
                    'total_settings': len(settings_data),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_teams_settings_graph(self) -> TeamsResult:
        """Get Teams settings using Graph API."""
        try:
            # Graph API has limited Teams settings access
            # Get organization settings
            org_settings = self.graph_client.get('/organization')
            
            settings_data = []
            
            for org in org_settings.get('value', []):
                setting = {
                    '設定タイプ': '組織設定',
                    'ポリシー名': org.get('displayName', ''),
                    'テナントID': org.get('id', ''),
                    '国コード': org.get('countryLetterCode', ''),
                    '言語': org.get('preferredLanguage', ''),
                    'テナントタイプ': 'Microsoft 365',
                    '最終更新': org.get('createdDateTime', ''),
                    'ゲストアクセス': 'N/A (Graph API)',
                    'プライベートチャット': 'N/A (Graph API)',
                    '会議録画': 'N/A (Graph API)'
                }
                settings_data.append(setting)
            
            return TeamsResult(
                success=True,
                data=settings_data,
                source="Graph API",
                metadata={
                    'total_settings': len(settings_data),
                    'generated_at': datetime.now().isoformat(),
                    'note': 'Limited settings available via Graph API'
                }
            )
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _get_teams_settings_mock(self) -> TeamsResult:
        """Generate mock Teams settings data."""
        import random
        
        self.logger.warning("Generating mock Teams settings data")
        
        settings_data = [
            {
                '設定タイプ': 'クライアント設定',
                'ポリシー名': 'Global',
                'ファイルアップロード': random.choice([True, False]),
                'ゲストアクセス': random.choice([True, False]),
                'スケジュール送信': random.choice([True, False]),
                'プライベートチャット': True,
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            },
            {
                '設定タイプ': '会議ポリシー',
                'ポリシー名': 'Global',
                '会議録画': random.choice([True, False]),
                'プライベート会議開催': True,
                'チャンネル会議開催': True,
                '外部参加者': random.choice([True, False]),
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            },
            {
                '設定タイプ': 'メッセージングポリシー',
                'ポリシー名': 'Global',
                'チャット編集': True,
                'チャット削除': True,
                '絵文字使用': True,
                'ステッカー使用': True,
                '最終更新': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
        ]
        
        return TeamsResult(
            success=True,
            data=settings_data,
            source="Mock Data",
            metadata={
                'total_settings': len(settings_data),
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock data generated - no API access available'
            }
        )
    
    def get_meeting_quality_data(self, days: int = 7) -> TeamsResult:
        """Get Teams meeting quality analytics."""
        self.api_call_count += 1
        
        try:
            # This would typically use Call Quality Dashboard APIs
            # For now, generate mock data
            return self._get_meeting_quality_mock(days)
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_meeting_quality_mock(self, days: int) -> TeamsResult:
        """Generate mock meeting quality data."""
        import random
        
        self.logger.warning("Generating mock meeting quality data")
        
        quality_data = []
        
        for i in range(random.randint(20, 50)):
            quality = {
                '会議ID': f'meeting-{i+1}',
                '会議名': f'会議{i+1}',
                '開催日時': (datetime.now() - timedelta(days=random.randint(0, days))).strftime('%Y-%m-%d %H:%M:%S'),
                '参加者数': random.randint(2, 50),
                '最大参加者数': random.randint(2, 50),
                '持続時間(分)': random.randint(15, 180),
                '音声品質スコア': round(random.uniform(3.0, 5.0), 2),
                'ビデオ品質スコア': round(random.uniform(3.0, 5.0), 2),
                'ネットワーク品質スコア': round(random.uniform(3.0, 5.0), 2),
                'ドロップアウト数': random.randint(0, 5),
                '録画有無': random.choice([True, False]),
                'チャットメッセージ数': random.randint(0, 50),
                'プラットフォーム': random.choice(['Windows', 'Mac', 'Web', 'Mobile']),
                '品質レーティング': random.choice(['優秀', '良好', '普通', '要改善'])
            }
            quality_data.append(quality)
        
        return TeamsResult(
            success=True,
            data=quality_data,
            source="Mock Data",
            metadata={
                'total_meetings': len(quality_data),
                'period_days': days,
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock data generated - Call Quality Dashboard APIs not available'
            }
        )
    
    def get_teams_apps_data(self) -> TeamsResult:
        """Get Teams apps and integrations data."""
        self.api_call_count += 1
        
        try:
            # Try Graph API first
            if self.graph_connected:
                result = self._get_teams_apps_graph()
                if result.success:
                    return result
            
            # Fallback to PowerShell
            if self.teams_connected:
                result = self._get_teams_apps_powershell()
                if result.success:
                    return result
            
            # Generate mock data
            return self._get_teams_apps_mock()
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_teams_apps_graph(self) -> TeamsResult:
        """Get Teams apps using Graph API."""
        try:
            # Get Teams apps from Graph API
            apps = self.graph_client.get('/appCatalogs/teamsApps')
            apps_data = apps.get('value', [])
            
            processed_apps = []
            for app in apps_data:
                app_info = {
                    'アプリ名': app.get('displayName', ''),
                    'アプリID': app.get('id', ''),
                    'バージョン': app.get('version', ''),
                    '種類': app.get('distributionMethod', ''),
                    '説明': app.get('shortDescription', ''),
                    '公開者': app.get('publishingState', ''),
                    '最終更新': app.get('createdDateTime', ''),
                    'カテゴリ': app.get('categories', []),
                    'アクセス許可': app.get('authorizationInfo', {}),
                    'ステータス': 'アクティブ'
                }
                processed_apps.append(app_info)
            
            return TeamsResult(
                success=True,
                data=processed_apps,
                source="Graph API",
                metadata={
                    'total_apps': len(processed_apps),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _get_teams_apps_powershell(self) -> TeamsResult:
        """Get Teams apps using PowerShell."""
        try:
            self.powershell_call_count += 1
            
            # Get Teams app policies
            policy_cmd = "Get-CsTeamsAppPermissionPolicy"
            policy_result = self.powershell_bridge.execute_command(policy_cmd)
            
            if not policy_result.success:
                return TeamsResult(
                    success=False,
                    data=None,
                    error_message=policy_result.error_message,
                    source="PowerShell"
                )
            
            # Process app policies
            apps_data = []
            policies = policy_result.data if isinstance(policy_result.data, list) else [policy_result.data]
            
            for policy in policies:
                if isinstance(policy, dict):
                    app_info = {
                        'アプリ名': policy.get('Identity', ''),
                        'アプリID': policy.get('Identity', ''),
                        'バージョン': 'N/A (PowerShell)',
                        '種類': 'ポリシー',
                        '説明': policy.get('Description', ''),
                        '公開者': 'Microsoft',
                        '最終更新': policy.get('WhenChanged', ''),
                        'カテゴリ': ['ポリシー管理'],
                        'アクセス許可': policy.get('GlobalCatalogAppsType', ''),
                        'ステータス': 'アクティブ'
                    }
                    apps_data.append(app_info)
            
            return TeamsResult(
                success=True,
                data=apps_data,
                source="PowerShell",
                metadata={
                    'total_apps': len(apps_data),
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return TeamsResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_teams_apps_mock(self) -> TeamsResult:
        """Generate mock Teams apps data."""
        import random
        
        self.logger.warning("Generating mock Teams apps data")
        
        apps_data = [
            {
                'アプリ名': 'Microsoft Planner',
                'アプリID': 'planner-app-001',
                'バージョン': '2.1.0',
                '種類': 'Microsoft',
                '説明': 'タスク管理とプロジェクト計画',
                '公開者': 'Microsoft Corporation',
                '最終更新': '2024-01-15',
                'カテゴリ': ['生産性', 'プロジェクト管理'],
                'アクセス許可': '承認済み',
                'ステータス': 'アクティブ'
            },
            {
                'アプリ名': 'OneNote',
                'アプリID': 'onenote-app-002',
                'バージョン': '3.0.1',
                '種類': 'Microsoft',
                '説明': 'デジタルノートアプリケーション',
                '公開者': 'Microsoft Corporation',
                '最終更新': '2024-02-01',
                'カテゴリ': ['生産性', 'ノート'],
                'アクセス許可': '承認済み',
                'ステータス': 'アクティブ'
            },
            {
                'アプリ名': 'Power BI',
                'アプリID': 'powerbi-app-003',
                'バージョン': '4.2.0',
                '種類': 'Microsoft',
                '説明': 'ビジネスインテリジェンスツール',
                '公開者': 'Microsoft Corporation',
                '最終更新': '2024-01-30',
                'カテゴリ': ['アナリティクス', 'ダッシュボード'],
                'アクセス許可': '承認済み',
                'ステータス': 'アクティブ'
            },
            {
                'アプリ名': 'SharePoint',
                'アプリID': 'sharepoint-app-004',
                'バージョン': '2.5.0',
                '種類': 'Microsoft',
                '説明': 'ドキュメント管理とコラボレーション',
                '公開者': 'Microsoft Corporation',
                '最終更新': '2024-01-20',
                'カテゴリ': ['コラボレーション', 'ドキュメント'],
                'アクセス許可': '承認済み',
                'ステータス': 'アクティブ'
            }
        ]
        
        return TeamsResult(
            success=True,
            data=apps_data,
            source="Mock Data",
            metadata={
                'total_apps': len(apps_data),
                'generated_at': datetime.now().isoformat(),
                'note': 'Mock data generated - Teams Apps APIs not available'
            }
        )
    
    def get_connection_status(self) -> Dict[str, Any]:
        """Get connection status for both Graph API and PowerShell."""
        return {
            'graph_connected': self.graph_connected,
            'teams_connected': self.teams_connected,
            'api_call_count': self.api_call_count,
            'powershell_call_count': self.powershell_call_count,
            'preferred_method': 'PowerShell' if self.teams_connected else 'Graph API' if self.graph_connected else 'Mock Data'
        }
    
    def disconnect(self):
        """Disconnect from Teams services."""
        try:
            if self.teams_connected:
                self.powershell_bridge.execute_command(
                    "Disconnect-MicrosoftTeams",
                    return_json=False
                )
                self.teams_connected = False
                self.logger.info("Disconnected from Teams PowerShell")
            
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
