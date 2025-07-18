"""
Exchange Online API client implementation.
Python equivalent of PowerShell ExchangeManagement modules.
Provides authentication and API access for Exchange Online services.
"""

import logging
import json
import base64
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Union
from dataclasses import dataclass
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from src.core.config import Config
from src.core.powershell_bridge import PowerShellBridge
from src.api.graph.client import GraphClient


@dataclass
class ExchangeResult:
    """Exchange API result container."""
    success: bool
    data: Any
    error_message: Optional[str] = None
    source: str = "Graph API"  # "Graph API" or "PowerShell"
    metadata: Optional[Dict[str, Any]] = None


class ExchangeClient:
    """
    Exchange Online client with dual Graph API and PowerShell support.
    Python equivalent of PowerShell ExchangeManagement.psm1.
    
    Features:
    - Microsoft Graph API for modern Exchange operations
    - PowerShell bridge for legacy/advanced Exchange commands
    - Automatic fallback between methods
    - Comprehensive error handling
    """
    
    def __init__(self, config: Config, graph_client: Optional[GraphClient] = None):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.graph_client = graph_client or GraphClient(config)
        self.powershell_bridge = PowerShellBridge()
        
        # Connection state
        self.exchange_connected = False
        self.graph_connected = False
        
        # Performance tracking
        self.api_call_count = 0
        self.powershell_call_count = 0
        
    def initialize(self):
        """Initialize Exchange client with authentication."""
        try:
            # Initialize Graph client first
            self.graph_client.initialize()
            self.graph_connected = True
            self.logger.info("Graph API connection established")
            
            # Try to connect to Exchange Online PowerShell
            self._connect_exchange_powershell()
            
        except Exception as e:
            self.logger.error(f"Exchange client initialization failed: {e}")
            raise
    
    def _connect_exchange_powershell(self):
        """Connect to Exchange Online PowerShell."""
        try:
            # Import Exchange Online module
            import_result = self.powershell_bridge.execute_command(
                "Import-Module ExchangeOnlineManagement -Force",
                return_json=False
            )
            
            if not import_result.success:
                self.logger.warning("ExchangeOnlineManagement module not available")
                return
            
            # Get connection parameters
            tenant_id = (
                self.config.get('Authentication.TenantId') or 
                self.config.get('ExchangeOnline.TenantId') or 
                self.config.get('EntraID.TenantId')
            )
            client_id = (
                self.config.get('Authentication.ClientId') or 
                self.config.get('ExchangeOnline.ClientId') or 
                self.config.get('EntraID.ClientId')
            )
            cert_thumbprint = (
                self.config.get('Authentication.CertificateThumbprint') or
                self.config.get('ExchangeOnline.CertificateThumbprint')
            )
            
            if not all([tenant_id, client_id, cert_thumbprint]):
                self.logger.warning("Exchange PowerShell connection parameters incomplete")
                return
            
            # Connect to Exchange Online
            connect_cmd = f"""
            Connect-ExchangeOnline -TenantId '{tenant_id}' -ClientId '{client_id}' -CertificateThumbprint '{cert_thumbprint}' -ShowProgress $false
            """
            
            connect_result = self.powershell_bridge.execute_command(
                connect_cmd,
                return_json=False,
                timeout=120
            )
            
            if connect_result.success:
                self.exchange_connected = True
                self.logger.info("Exchange Online PowerShell connection established")
            else:
                self.logger.warning(f"Exchange PowerShell connection failed: {connect_result.error_message}")
                
        except Exception as e:
            self.logger.warning(f"Exchange PowerShell connection error: {e}")
    
    def get_mailboxes(self, limit: int = 1000, include_statistics: bool = False) -> ExchangeResult:
        """Get mailboxes using Graph API or PowerShell fallback."""
        self.api_call_count += 1
        
        try:
            # Try Graph API first
            if self.graph_connected:
                result = self._get_mailboxes_graph(limit, include_statistics)
                if result.success:
                    return result
                else:
                    self.logger.warning("Graph API failed, trying PowerShell")
            
            # Fallback to PowerShell
            if self.exchange_connected:
                return self._get_mailboxes_powershell(limit, include_statistics)
            
            # Both methods failed
            return ExchangeResult(
                success=False,
                data=None,
                error_message="No available connection methods"
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_mailboxes_graph(self, limit: int, include_statistics: bool) -> ExchangeResult:
        """Get mailboxes using Microsoft Graph API."""
        try:
            # Use Graph API to get users with mailboxes
            users = self.graph_client.get_users(
                select=['id', 'displayName', 'userPrincipalName', 'mail', 'accountEnabled'],
                limit=limit
            )
            
            mailboxes = []
            for user in users:
                if user.get('mail'):  # User has a mailbox
                    mailbox = {
                        'ユーザー名': user.get('displayName', ''),
                        'メールアドレス': user.get('mail', ''),
                        'UPN': user.get('userPrincipalName', ''),
                        'アカウント状態': '有効' if user.get('accountEnabled') else '無効',
                        'メールボックスタイプ': 'UserMailbox',
                        'GUID': user.get('id', ''),
                        'プライマリSMTPアドレス': user.get('mail', ''),
                        'エイリアス': user.get('mailNickname', ''),
                        'データベース': 'N/A (Graph API)',
                        'サーバー': 'N/A (Graph API)'
                    }
                    
                    # Add statistics if requested
                    if include_statistics:
                        try:
                            stats = self.graph_client.get(f'/users/{user["id"]}/mailboxSettings')
                            mailbox.update({
                                '自動返信': stats.get('automaticRepliesSetting', {}).get('status', 'Disabled'),
                                '言語': stats.get('language', {}).get('displayName', 'Default'),
                                'タイムゾーン': stats.get('timeZone', 'UTC')
                            })
                        except:
                            mailbox.update({
                                '自動返信': 'Unknown',
                                '言語': 'Unknown',
                                'タイムゾーン': 'Unknown'
                            })
                    
                    mailboxes.append(mailbox)
            
            return ExchangeResult(
                success=True,
                data=mailboxes,
                source="Graph API",
                metadata={
                    'total_count': len(mailboxes),
                    'include_statistics': include_statistics,
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _get_mailboxes_powershell(self, limit: int, include_statistics: bool) -> ExchangeResult:
        """Get mailboxes using PowerShell Exchange Online commands."""
        try:
            self.powershell_call_count += 1
            
            # Build PowerShell command
            ps_command = f"Get-Mailbox -ResultSize {limit}"
            
            if include_statistics:
                ps_command += " | ForEach-Object { $_ | Add-Member -NotePropertyName 'Statistics' -NotePropertyValue (Get-MailboxStatistics -Identity $_.Identity) -PassThru }"
            
            # Execute command
            result = self.powershell_bridge.execute_command(ps_command)
            
            if not result.success:
                return ExchangeResult(
                    success=False,
                    data=None,
                    error_message=result.error_message,
                    source="PowerShell"
                )
            
            # Process PowerShell results
            mailboxes = []
            ps_data = result.data if isinstance(result.data, list) else [result.data]
            
            for mailbox in ps_data:
                if isinstance(mailbox, dict):
                    processed_mailbox = {
                        'ユーザー名': mailbox.get('DisplayName', ''),
                        'メールアドレス': mailbox.get('PrimarySmtpAddress', ''),
                        'UPN': mailbox.get('UserPrincipalName', ''),
                        'アカウント状態': '有効' if not mailbox.get('AccountDisabled', False) else '無効',
                        'メールボックスタイプ': mailbox.get('RecipientType', ''),
                        'GUID': mailbox.get('Guid', ''),
                        'プライマリSMTPアドレス': mailbox.get('PrimarySmtpAddress', ''),
                        'エイリアス': mailbox.get('Alias', ''),
                        'データベース': mailbox.get('Database', ''),
                        'サーバー': mailbox.get('ServerName', '')
                    }
                    
                    # Add statistics if available
                    if include_statistics and 'Statistics' in mailbox:
                        stats = mailbox['Statistics']
                        processed_mailbox.update({
                            '使用容量(MB)': stats.get('TotalItemSize', 0),
                            'アイテム数': stats.get('ItemCount', 0),
                            '削除済みアイテム数': stats.get('DeletedItemCount', 0),
                            '最終ログオン時刻': stats.get('LastLogonTime', ''),
                            '最終ログオフ時刻': stats.get('LastLogoffTime', '')
                        })
                    
                    mailboxes.append(processed_mailbox)
            
            return ExchangeResult(
                success=True,
                data=mailboxes,
                source="PowerShell",
                metadata={
                    'total_count': len(mailboxes),
                    'include_statistics': include_statistics,
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def get_mailbox_statistics(self, identity: Optional[str] = None, limit: int = 1000) -> ExchangeResult:
        """Get mailbox statistics."""
        self.api_call_count += 1
        
        try:
            # PowerShell is preferred for detailed statistics
            if self.exchange_connected:
                return self._get_mailbox_statistics_powershell(identity, limit)
            
            # Graph API fallback (limited statistics)
            if self.graph_connected:
                return self._get_mailbox_statistics_graph(identity, limit)
            
            return ExchangeResult(
                success=False,
                data=None,
                error_message="No available connection methods"
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_mailbox_statistics_powershell(self, identity: Optional[str], limit: int) -> ExchangeResult:
        """Get mailbox statistics using PowerShell."""
        try:
            self.powershell_call_count += 1
            
            if identity:
                ps_command = f"Get-MailboxStatistics -Identity '{identity}'"
            else:
                ps_command = f"Get-Mailbox -ResultSize {limit} | Get-MailboxStatistics"
            
            result = self.powershell_bridge.execute_command(ps_command)
            
            if not result.success:
                return ExchangeResult(
                    success=False,
                    data=None,
                    error_message=result.error_message,
                    source="PowerShell"
                )
            
            # Process results
            statistics = []
            ps_data = result.data if isinstance(result.data, list) else [result.data]
            
            for stat in ps_data:
                if isinstance(stat, dict):
                    processed_stat = {
                        'ユーザー名': stat.get('DisplayName', ''),
                        'メールアドレス': stat.get('PrimarySmtpAddress', ''),
                        'メールボックスGUID': stat.get('MailboxGuid', ''),
                        '使用容量(MB)': self._parse_size(stat.get('TotalItemSize', '0')),
                        'アイテム数': stat.get('ItemCount', 0),
                        '削除済みアイテム数': stat.get('DeletedItemCount', 0),
                        '削除済みアイテム容量(MB)': self._parse_size(stat.get('TotalDeletedItemSize', '0')),
                        '最終ログオン時刻': stat.get('LastLogonTime', ''),
                        '最終ログオフ時刻': stat.get('LastLogoffTime', ''),
                        'データベース': stat.get('Database', ''),
                        'サーバー': stat.get('ServerName', ''),
                        'ストレージクォータ': self._parse_size(stat.get('StorageQuotaStatus', '0')),
                        'アーカイブ状態': stat.get('ArchiveState', 'None')
                    }
                    statistics.append(processed_stat)
            
            return ExchangeResult(
                success=True,
                data=statistics,
                source="PowerShell",
                metadata={
                    'total_count': len(statistics),
                    'identity': identity,
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_mailbox_statistics_graph(self, identity: Optional[str], limit: int) -> ExchangeResult:
        """Get limited mailbox statistics using Graph API."""
        try:
            # Graph API has limited mailbox statistics
            if identity:
                # Get specific user
                user = self.graph_client.get_user(identity)
                users = [user] if user else []
            else:
                # Get all users with mailboxes
                users = self.graph_client.get_users(
                    select=['id', 'displayName', 'userPrincipalName', 'mail'],
                    limit=limit
                )
            
            statistics = []
            for user in users:
                if user.get('mail'):  # Has mailbox
                    # Try to get mailbox usage from reports API
                    try:
                        usage = self.graph_client.get(f'/reports/getMailboxUsageDetail(period=\'D7\')')
                        user_usage = next(
                            (u for u in usage.get('value', []) if u.get('userPrincipalName') == user.get('userPrincipalName')),
                            {}
                        )
                    except:
                        user_usage = {}
                    
                    stat = {
                        'ユーザー名': user.get('displayName', ''),
                        'メールアドレス': user.get('mail', ''),
                        'メールボックスGUID': user.get('id', ''),
                        '使用容量(MB)': round(user_usage.get('storageUsedInBytes', 0) / (1024**2), 2),
                        'アイテム数': user_usage.get('itemCount', 0),
                        '削除済みアイテム数': 'N/A (Graph API)',
                        '削除済みアイテム容量(MB)': 'N/A (Graph API)',
                        '最終ログオン時刻': user_usage.get('lastActivityDate', ''),
                        '最終ログオフ時刻': 'N/A (Graph API)',
                        'データベース': 'N/A (Graph API)',
                        'サーバー': 'N/A (Graph API)',
                        'ストレージクォータ': 'N/A (Graph API)',
                        'アーカイブ状態': 'N/A (Graph API)'
                    }
                    statistics.append(stat)
            
            return ExchangeResult(
                success=True,
                data=statistics,
                source="Graph API",
                metadata={
                    'total_count': len(statistics),
                    'identity': identity,
                    'generated_at': datetime.now().isoformat(),
                    'note': 'Limited statistics available via Graph API'
                }
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def get_mail_flow_statistics(self, days: int = 7) -> ExchangeResult:
        """Get mail flow statistics."""
        self.api_call_count += 1
        
        try:
            # PowerShell is preferred for mail flow data
            if self.exchange_connected:
                return self._get_mail_flow_powershell(days)
            
            # Graph API fallback with limited data
            if self.graph_connected:
                return self._get_mail_flow_graph(days)
            
            return ExchangeResult(
                success=False,
                data=None,
                error_message="No available connection methods"
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=str(e)
            )
    
    def _get_mail_flow_powershell(self, days: int) -> ExchangeResult:
        """Get mail flow statistics using PowerShell."""
        try:
            self.powershell_call_count += 1
            
            # Get message trace for the specified period
            start_date = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')
            end_date = datetime.now().strftime('%Y-%m-%d')
            
            ps_command = f"""
            Get-MessageTrace -StartDate '{start_date}' -EndDate '{end_date}' -PageSize 5000 | 
            Group-Object Status | 
            Select-Object Name, Count, @{{n='Percentage'; e={{[math]::Round(($_.Count / (Get-MessageTrace -StartDate '{start_date}' -EndDate '{end_date}' -PageSize 5000 | Measure-Object).Count * 100), 2)}}}}
            """
            
            result = self.powershell_bridge.execute_command(ps_command)
            
            if not result.success:
                return ExchangeResult(
                    success=False,
                    data=None,
                    error_message=result.error_message,
                    source="PowerShell"
                )
            
            # Process results
            flow_data = []
            ps_data = result.data if isinstance(result.data, list) else [result.data]
            
            for flow in ps_data:
                if isinstance(flow, dict):
                    processed_flow = {
                        'ステータス': flow.get('Name', ''),
                        'メッセージ数': flow.get('Count', 0),
                        '割合(%)': flow.get('Percentage', 0),
                        '期間': f'{days}日間',
                        '開始日': start_date,
                        '終了日': end_date
                    }
                    flow_data.append(processed_flow)
            
            return ExchangeResult(
                success=True,
                data=flow_data,
                source="PowerShell",
                metadata={
                    'total_count': len(flow_data),
                    'period_days': days,
                    'generated_at': datetime.now().isoformat()
                }
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=f"PowerShell error: {str(e)}",
                source="PowerShell"
            )
    
    def _get_mail_flow_graph(self, days: int) -> ExchangeResult:
        """Get limited mail flow statistics using Graph API."""
        try:
            # Graph API has limited mail flow reporting
            # Use email activity reports as a substitute
            period = f'D{days}'
            
            try:
                activity = self.graph_client.get(f'/reports/getEmailActivityUserDetail(period=\'{period}\')')
                activity_data = activity.get('value', [])
            except:
                activity_data = []
            
            # Process activity data
            flow_data = []
            
            if activity_data:
                total_sent = sum(user.get('sendCount', 0) for user in activity_data)
                total_received = sum(user.get('receiveCount', 0) for user in activity_data)
                total_read = sum(user.get('readCount', 0) for user in activity_data)
                
                flow_data = [
                    {
                        'ステータス': '送信済み',
                        'メッセージ数': total_sent,
                        '割合(%)': round(total_sent / (total_sent + total_received) * 100, 2) if (total_sent + total_received) > 0 else 0,
                        '期間': f'{days}日間',
                        '開始日': (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d'),
                        '終了日': datetime.now().strftime('%Y-%m-%d')
                    },
                    {
                        'ステータス': '受信済み',
                        'メッセージ数': total_received,
                        '割合(%)': round(total_received / (total_sent + total_received) * 100, 2) if (total_sent + total_received) > 0 else 0,
                        '期間': f'{days}日間',
                        '開始日': (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d'),
                        '終了日': datetime.now().strftime('%Y-%m-%d')
                    },
                    {
                        'ステータス': '既読',
                        'メッセージ数': total_read,
                        '割合(%)': round(total_read / total_received * 100, 2) if total_received > 0 else 0,
                        '期間': f'{days}日間',
                        '開始日': (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d'),
                        '終了日': datetime.now().strftime('%Y-%m-%d')
                    }
                ]
            
            return ExchangeResult(
                success=True,
                data=flow_data,
                source="Graph API",
                metadata={
                    'total_count': len(flow_data),
                    'period_days': days,
                    'generated_at': datetime.now().isoformat(),
                    'note': 'Limited mail flow data available via Graph API'
                }
            )
            
        except Exception as e:
            return ExchangeResult(
                success=False,
                data=None,
                error_message=f"Graph API error: {str(e)}",
                source="Graph API"
            )
    
    def _parse_size(self, size_str: str) -> float:
        """Parse Exchange size string to MB."""
        try:
            if not size_str or size_str == '0':
                return 0.0
            
            # Remove parentheses and extract size
            size_str = str(size_str).strip()
            if '(' in size_str and ')' in size_str:
                size_str = size_str.split('(')[1].split(')')[0]
            
            # Convert to MB
            if 'bytes' in size_str.lower():
                bytes_value = float(size_str.lower().replace('bytes', '').replace(',', '').strip())
                return round(bytes_value / (1024**2), 2)
            elif 'kb' in size_str.lower():
                kb_value = float(size_str.lower().replace('kb', '').replace(',', '').strip())
                return round(kb_value / 1024, 2)
            elif 'mb' in size_str.lower():
                return float(size_str.lower().replace('mb', '').replace(',', '').strip())
            elif 'gb' in size_str.lower():
                gb_value = float(size_str.lower().replace('gb', '').replace(',', '').strip())
                return round(gb_value * 1024, 2)
            else:
                # Assume bytes
                return round(float(size_str.replace(',', '')) / (1024**2), 2)
        except:
            return 0.0
    
    def get_connection_status(self) -> Dict[str, Any]:
        """Get connection status for both Graph API and PowerShell."""
        return {
            'graph_connected': self.graph_connected,
            'exchange_connected': self.exchange_connected,
            'api_call_count': self.api_call_count,
            'powershell_call_count': self.powershell_call_count,
            'preferred_method': 'PowerShell' if self.exchange_connected else 'Graph API' if self.graph_connected else 'None'
        }
    
    def disconnect(self):
        """Disconnect from Exchange services."""
        try:
            if self.exchange_connected:
                self.powershell_bridge.execute_command(
                    "Disconnect-ExchangeOnline -Confirm:$false",
                    return_json=False
                )
                self.exchange_connected = False
                self.logger.info("Disconnected from Exchange Online PowerShell")
            
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
