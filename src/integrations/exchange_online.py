"""
Microsoft 365管理ツール Exchange Online統合
=========================================

Exchange Online PowerShell統合
- メールボックス管理
- メールフロー分析
- セキュリティ・コンプライアンス
- PowerShellモジュール連携
"""

import asyncio
import logging
import subprocess
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass 
class ExchangeCommand:
    """Exchange PowerShellコマンド"""
    cmdlet: str
    parameters: Dict[str, Any]
    output_format: str = "json"


@dataclass
class ExchangeResult:
    """Exchange PowerShell実行結果"""
    success: bool
    data: Any
    error: Optional[str] = None
    execution_time: Optional[float] = None


class ExchangeOnlineIntegration:
    """Exchange Online PowerShell統合クラス"""
    
    # Exchange Online PowerShell コマンドレット
    CMDLETS = {
        # メールボックス管理
        "get_mailboxes": "Get-Mailbox",
        "get_mailbox_stats": "Get-MailboxStatistics", 
        "get_mailbox_permissions": "Get-MailboxPermission",
        "set_mailbox": "Set-Mailbox",
        
        # メールフロー管理
        "get_message_trace": "Get-MessageTrace",
        "get_message_trace_detail": "Get-MessageTraceDetail",
        "get_transport_rule": "Get-TransportRule",
        "get_mail_flow_policy": "Get-DlpPolicy",
        
        # セキュリティ・コンプライアンス
        "get_anti_spam_policy": "Get-HostedContentFilterPolicy",
        "get_anti_malware_policy": "Get-MalwareFilterPolicy",
        "get_safe_attachment_policy": "Get-SafeAttachmentPolicy",
        "get_safe_links_policy": "Get-SafeLinksPolicy",
        
        # 配信・監視
        "get_mail_detail_report": "Get-MailDetailReport",
        "get_mail_traffic_report": "Get-MailTrafficSummaryReport",
        "get_spam_detector_report": "Get-SpamDetectorReport",
        
        # 接続・認証
        "connect_exchange": "Connect-ExchangeOnline",
        "disconnect_exchange": "Disconnect-ExchangeOnline",
        "get_connection_info": "Get-ConnectionInformation"
    }
    
    def __init__(self, 
                 tenant_id: str,
                 app_id: str, 
                 certificate_path: Optional[str] = None,
                 certificate_thumbprint: Optional[str] = None):
        """
        Exchange Online統合初期化
        
        Args:
            tenant_id: Azure ADテナントID
            app_id: アプリケーションID
            certificate_path: 証明書ファイルパス
            certificate_thumbprint: 証明書拇印
        """
        self.tenant_id = tenant_id
        self.app_id = app_id
        self.certificate_path = certificate_path
        self.certificate_thumbprint = certificate_thumbprint
        
        # PowerShell実行設定
        self.powershell_executable = "pwsh"  # PowerShell Core
        self.session_timeout = 300  # 5分
        self.command_timeout = 60   # 1分
        
        # 接続状態
        self.is_connected = False
        self.connection_info = None
    
    async def initialize(self):
        """非同期初期化・接続"""
        
        try:
            # Exchange Online接続
            connection_result = await self.connect_exchange_online()
            
            if not connection_result.success:
                raise Exception(f"Exchange Online接続失敗: {connection_result.error}")
            
            self.is_connected = True
            self.connection_info = connection_result.data
            
            logger.info("Exchange Online統合初期化完了")
            
        except Exception as e:
            logger.error(f"Exchange Online初期化エラー: {e}")
            raise
    
    async def connect_exchange_online(self) -> ExchangeResult:
        """Exchange Online接続"""
        
        connection_params = {
            "AppId": self.app_id,
            "Organization": f"{self.tenant_id}.onmicrosoft.com",
            "ShowBanner": "$false"
        }
        
        # 証明書認証
        if self.certificate_thumbprint:
            connection_params["CertificateThumbprint"] = self.certificate_thumbprint
        elif self.certificate_path:
            connection_params["CertificateFilePath"] = self.certificate_path
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["connect_exchange"],
            parameters=connection_params
        )
        
        result = await self._execute_powershell_command(command)
        
        if result.success:
            # 接続情報取得
            info_command = ExchangeCommand(
                cmdlet=self.CMDLETS["get_connection_info"],
                parameters={}
            )
            
            info_result = await self._execute_powershell_command(info_command)
            if info_result.success:
                result.data = info_result.data
        
        return result
    
    async def get_all_mailboxes(self, 
                               result_size: int = 1000,
                               properties: Optional[List[str]] = None) -> ExchangeResult:
        """全メールボックス取得"""
        
        parameters = {
            "ResultSize": result_size
        }
        
        if properties:
            # PowerShell Select-Object用のプロパティ指定
            parameters["Properties"] = ",".join(properties)
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["get_mailboxes"],
            parameters=parameters
        )
        
        return await self._execute_powershell_command(command)
    
    async def get_mailbox_statistics(self, 
                                   identity: Optional[str] = None,
                                   archive: bool = False) -> ExchangeResult:
        """メールボックス統計取得"""
        
        parameters = {}
        
        if identity:
            parameters["Identity"] = identity
        
        if archive:
            parameters["Archive"] = "$true"
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["get_mailbox_stats"],
            parameters=parameters
        )
        
        return await self._execute_powershell_command(command)
    
    async def get_message_trace(self,
                               start_date: datetime,
                               end_date: datetime,
                               sender_address: Optional[str] = None,
                               recipient_address: Optional[str] = None,
                               page_size: int = 1000) -> ExchangeResult:
        """メッセージトレース取得"""
        
        parameters = {
            "StartDate": start_date.isoformat(),
            "EndDate": end_date.isoformat(),
            "PageSize": page_size
        }
        
        if sender_address:
            parameters["SenderAddress"] = sender_address
        
        if recipient_address:
            parameters["RecipientAddress"] = recipient_address
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["get_message_trace"],
            parameters=parameters
        )
        
        return await self._execute_powershell_command(command)
    
    async def get_transport_rules(self) -> ExchangeResult:
        """トランスポートルール取得"""
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["get_transport_rule"],
            parameters={}
        )
        
        return await self._execute_powershell_command(command)
    
    async def get_anti_spam_policies(self) -> ExchangeResult:
        """スパム対策ポリシー取得"""
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["get_anti_spam_policy"],
            parameters={}
        )
        
        return await self._execute_powershell_command(command)
    
    async def get_mail_traffic_summary(self, 
                                     start_date: datetime,
                                     end_date: datetime) -> ExchangeResult:
        """メールトラフィックサマリー取得"""
        
        parameters = {
            "StartDate": start_date.isoformat(),
            "EndDate": end_date.isoformat()
        }
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["get_mail_traffic_report"],
            parameters=parameters
        )
        
        return await self._execute_powershell_command(command)
    
    async def bulk_mailbox_operation(self, 
                                   operations: List[Dict[str, Any]]) -> List[ExchangeResult]:
        """バルクメールボックス操作"""
        
        results = []
        
        for operation in operations:
            try:
                cmdlet = operation.get("cmdlet")
                parameters = operation.get("parameters", {})
                
                if not cmdlet:
                    results.append(ExchangeResult(
                        success=False,
                        data=None,
                        error="コマンドレットが指定されていません"
                    ))
                    continue
                
                command = ExchangeCommand(
                    cmdlet=cmdlet,
                    parameters=parameters
                )
                
                result = await self._execute_powershell_command(command)
                results.append(result)
                
                # レート制限対応
                await asyncio.sleep(0.5)
                
            except Exception as e:
                results.append(ExchangeResult(
                    success=False,
                    data=None,
                    error=str(e)
                ))
        
        return results
    
    async def _execute_powershell_command(self, command: ExchangeCommand) -> ExchangeResult:
        """PowerShellコマンド実行"""
        
        start_time = asyncio.get_event_loop().time()
        
        try:
            # PowerShellスクリプト生成
            script = self._build_powershell_script(command)
            
            # PowerShell実行
            process = await asyncio.create_subprocess_exec(
                self.powershell_executable,
                "-Command", script,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                timeout=self.command_timeout
            )
            
            stdout, stderr = await process.communicate()
            
            execution_time = asyncio.get_event_loop().time() - start_time
            
            # 結果解析
            if process.returncode == 0:
                try:
                    if command.output_format == "json" and stdout:
                        data = json.loads(stdout.decode('utf-8'))
                    else:
                        data = stdout.decode('utf-8') if stdout else None
                    
                    return ExchangeResult(
                        success=True,
                        data=data,
                        execution_time=execution_time
                    )
                    
                except json.JSONDecodeError as e:
                    return ExchangeResult(
                        success=False,
                        data=stdout.decode('utf-8') if stdout else None,
                        error=f"JSON解析エラー: {e}",
                        execution_time=execution_time
                    )
            
            else:
                error_msg = stderr.decode('utf-8') if stderr else f"終了コード: {process.returncode}"
                return ExchangeResult(
                    success=False,
                    data=None,
                    error=error_msg,
                    execution_time=execution_time
                )
        
        except asyncio.TimeoutError:
            return ExchangeResult(
                success=False,
                data=None,
                error=f"タイムアウト（{self.command_timeout}秒）"
            )
        
        except Exception as e:
            execution_time = asyncio.get_event_loop().time() - start_time
            return ExchangeResult(
                success=False,
                data=None,
                error=str(e),
                execution_time=execution_time
            )
    
    def _build_powershell_script(self, command: ExchangeCommand) -> str:
        """PowerShellスクリプト構築"""
        
        # パラメータ文字列構築
        param_strings = []
        for key, value in command.parameters.items():
            if isinstance(value, str):
                param_strings.append(f"-{key} '{value}'")
            elif isinstance(value, bool):
                param_strings.append(f"-{key} ${str(value).lower()}")
            else:
                param_strings.append(f"-{key} {value}")
        
        params = " ".join(param_strings)
        
        # 基本スクリプト
        script_parts = [
            "try {",
            f"    $result = {command.cmdlet} {params}",
        ]
        
        # 出力形式に応じた変換
        if command.output_format == "json":
            script_parts.extend([
                "    if ($result) {",
                "        $result | ConvertTo-Json -Depth 10 -Compress",
                "    } else {",
                "        Write-Output '[]'",
                "    }",
            ])
        else:
            script_parts.append("    $result")
        
        script_parts.extend([
            "} catch {",
            "    Write-Error $_.Exception.Message",
            "    exit 1",
            "}"
        ])
        
        return "\n".join(script_parts)
    
    async def test_connection(self) -> ExchangeResult:
        """接続テスト"""
        
        if not self.is_connected:
            return ExchangeResult(
                success=False,
                data=None,
                error="Exchange Onlineに接続されていません"
            )
        
        # 簡単なコマンドで接続確認
        command = ExchangeCommand(
            cmdlet="Get-OrganizationConfig",
            parameters={}
        )
        
        result = await self._execute_powershell_command(command)
        
        if result.success:
            return ExchangeResult(
                success=True,
                data={
                    "connected": True,
                    "organization": result.data.get("Name") if isinstance(result.data, dict) else "Connected"
                }
            )
        
        return result
    
    async def disconnect(self) -> ExchangeResult:
        """Exchange Online切断"""
        
        if not self.is_connected:
            return ExchangeResult(success=True, data={"message": "既に切断済み"})
        
        command = ExchangeCommand(
            cmdlet=self.CMDLETS["disconnect_exchange"],
            parameters={"Confirm": "$false"}
        )
        
        result = await self._execute_powershell_command(command)
        
        if result.success:
            self.is_connected = False
            self.connection_info = None
            logger.info("Exchange Online切断完了")
        
        return result
    
    async def sync_mailboxes_to_database(self, 
                                       session, 
                                       mailbox_model_class):
        """Exchange Onlineメールボックス情報をデータベースに同期"""
        
        synced_count = 0
        error_count = 0
        
        try:
            # メールボックス一覧取得
            mailboxes_result = await self.get_all_mailboxes(
                result_size=10000,
                properties=[
                    "DisplayName", "PrimarySmtpAddress", "UserPrincipalName",
                    "RecipientTypeDetails", "TotalItemSize", "ProhibitSendQuota",
                    "ForwardingAddress", "DeliverToMailboxAndForward"
                ]
            )
            
            if not mailboxes_result.success:
                raise Exception(f"メールボックス取得失敗: {mailboxes_result.error}")
            
            mailboxes = mailboxes_result.data
            if not isinstance(mailboxes, list):
                mailboxes = [mailboxes] if mailboxes else []
            
            for mailbox in mailboxes:
                try:
                    # 統計情報取得
                    stats_result = await self.get_mailbox_statistics(
                        identity=mailbox.get("PrimarySmtpAddress")
                    )
                    
                    stats = stats_result.data if stats_result.success else {}
                    
                    # データベースモデルに変換
                    mailbox_data = {
                        'email': mailbox.get('PrimarySmtpAddress', ''),
                        'display_name': mailbox.get('DisplayName', ''),
                        'user_principal_name': mailbox.get('UserPrincipalName'),
                        'mailbox_type': mailbox.get('RecipientTypeDetails'),
                        'total_size_mb': self._parse_mailbox_size(stats.get('TotalItemSize')),
                        'quota_mb': self._parse_mailbox_size(mailbox.get('ProhibitSendQuota')),
                        'message_count': stats.get('ItemCount', 0),
                        'last_access': self._parse_datetime(stats.get('LastLogonTime')),
                        'forwarding_enabled': bool(mailbox.get('ForwardingAddress')),
                        'forwarding_address': mailbox.get('ForwardingAddress'),
                        'auto_reply_enabled': bool(mailbox.get('DeliverToMailboxAndForward'))
                    }
                    
                    # 使用率計算
                    if mailbox_data['total_size_mb'] and mailbox_data['quota_mb']:
                        mailbox_data['usage_percent'] = (
                            mailbox_data['total_size_mb'] / mailbox_data['quota_mb'] * 100
                        )
                    
                    # データベース保存
                    await self._upsert_mailbox(session, mailbox_model_class, mailbox_data)
                    synced_count += 1
                    
                except Exception as e:
                    logger.error(f"メールボックス同期エラー: {mailbox.get('PrimarySmtpAddress', 'Unknown')}: {e}")
                    error_count += 1
                
                # レート制限対応
                await asyncio.sleep(0.1)
        
        except Exception as e:
            logger.error(f"メールボックス同期全体エラー: {e}")
            raise
        
        logger.info(f"メールボックス同期完了: 成功 {synced_count}件, エラー {error_count}件")
        return {"synced": synced_count, "errors": error_count}
    
    def _parse_mailbox_size(self, size_string: Optional[str]) -> Optional[float]:
        """メールボックスサイズ文字列を MB に変換"""
        
        if not size_string:
            return None
        
        try:
            # Exchange形式: "1.234 GB (1,234,567,890 bytes)"
            if "bytes" in size_string:
                bytes_part = size_string.split("(")[1].split(" bytes")[0]
                bytes_value = int(bytes_part.replace(",", ""))
                return bytes_value / (1024 * 1024)  # MB変換
            
            # 単純な数値の場合
            return float(size_string)
            
        except Exception:
            return None
    
    def _parse_datetime(self, datetime_str: Optional[str]) -> Optional[datetime]:
        """Exchange日時文字列をdatetimeオブジェクトに変換"""
        
        if not datetime_str:
            return None
        
        try:
            # Exchange形式: "2023/01/01 12:00:00"
            return datetime.strptime(datetime_str, "%Y/%m/%d %H:%M:%S")
        except Exception:
            try:
                # ISO形式も試行
                return datetime.fromisoformat(datetime_str.replace('Z', '+00:00'))
            except Exception:
                return None
    
    async def _upsert_mailbox(self, session, mailbox_model_class, mailbox_data: Dict[str, Any]):
        """メールボックスデータのUPSERT操作"""
        
        from sqlalchemy import select
        
        # 既存メールボックスチェック
        stmt = select(mailbox_model_class).where(
            mailbox_model_class.email == mailbox_data['email']
        )
        result = await session.execute(stmt)
        existing_mailbox = result.scalar_one_or_none()
        
        if existing_mailbox:
            # 更新
            for key, value in mailbox_data.items():
                if value is not None:
                    setattr(existing_mailbox, key, value)
        else:
            # 新規作成
            new_mailbox = mailbox_model_class(**mailbox_data)
            session.add(new_mailbox)
        
        await session.commit()
    
    async def cleanup(self):
        """リソースクリーンアップ"""
        
        if self.is_connected:
            await self.disconnect()
        
        logger.info("Exchange Online統合クリーンアップ完了")