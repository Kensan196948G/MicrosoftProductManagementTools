# Microsoft 365 Management Tools - Exchange Mailbox Command
# メールボックス管理・容量監視 - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--include-shared', is_flag=True, help='共有メールボックスを含める')
@click.option('--include-archive', is_flag=True, help='アーカイブ情報を含める')
@click.option('--size-threshold', type=int, default=50, help='容量アラート閾値(GB)')
@click.option('--department', help='特定部署のみ対象')
@click.option('--usage-stats', is_flag=True, help='使用統計を含める')
@click.pass_context
def mailbox_command(ctx, include_shared, include_archive, size_threshold, department, usage_stats):
    """Exchange Onlineメールボックス管理・容量監視
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 mailbox
    
    Exchange Onlineのメールボックス情報、容量使用率、制限設定を分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_mailbox_report(
        cli_context, include_shared, include_archive, size_threshold, department, usage_stats
    ))

async def execute_mailbox_report(context: CLIContext,
                                include_shared: bool = False,
                                include_archive: bool = False,
                                size_threshold: int = 50,
                                department_filter: str = None,
                                usage_stats: bool = False):
    """Execute Exchange mailbox report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("Exchange Onlineメールボックス情報を取得中...")
        
        if context.dry_run:
            report_data = _generate_sample_mailbox_data(
                include_shared, include_archive, size_threshold, department_filter, usage_stats
            )
        else:
            report_data = await _generate_mailbox_report_data(
                context, include_shared, include_archive, size_threshold, department_filter, usage_stats
            )
        
        if not report_data:
            output.output_warning("メールボックスデータが見つかりませんでした")
            return
        
        output.output_success(f"メールボックスレポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="Exchange Onlineメールボックスレポート",
            filename_prefix="exchange_mailbox_report"
        )
        
        _show_mailbox_summary(report_data, output, size_threshold)
        
    except Exception as e:
        output.output_error(f"メールボックスレポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_mailbox_report_data(context: CLIContext,
                                      include_shared: bool,
                                      include_archive: bool,
                                      size_threshold: int,
                                      department_filter: str,
                                      usage_stats: bool) -> List[Dict[str, Any]]:
    """Generate mailbox report data from Exchange Online APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get mailbox information
        output.output_progress("メールボックス基本情報を取得中...")
        
        mailboxes = await graph_client.get_mailboxes(
            include_shared=include_shared
        )
        
        # Get mailbox statistics
        mailbox_stats = {}
        if usage_stats:
            output.output_progress("使用統計を取得中...")
            mailbox_stats = await graph_client.get_mailbox_usage_statistics()
        
        report_data = []
        
        for mailbox in mailboxes:
            display_name = mailbox.get('displayName', '')
            upn = mailbox.get('userPrincipalName', '')
            mailbox_type = mailbox.get('recipientTypeDetails', 'UserMailbox')
            dept = mailbox.get('department', '未設定')
            
            # Filter by department if specified
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            # Get mailbox size information
            total_size_bytes = mailbox.get('totalItemSize', 0)
            total_size_gb = total_size_bytes / (1024**3) if total_size_bytes else 0
            
            # Get quota information
            quota_gb = mailbox.get('prohibitSendReceiveQuota', 100)
            usage_percent = (total_size_gb / quota_gb * 100) if quota_gb > 0 else 0
            
            # Determine status
            status = "正常"
            if usage_percent >= 95:
                status = "🚨 容量満杯"
            elif usage_percent >= size_threshold:
                status = "⚠️ 容量注意" 
            
            # Get last access time
            last_access = mailbox.get('lastUserAccessTime', '')
            
            record = {
                'ユーザー名': display_name,
                'メールアドレス': upn,
                '部署': dept,
                'メールボックスタイプ': mailbox_type,
                '総容量(GB)': f"{total_size_gb:.2f}",
                'クォータ(GB)': quota_gb,
                '使用率': f"{usage_percent:.1f}%",
                'ステータス': status,
                '最終アクセス': last_access or '不明',
                'アイテム数': mailbox.get('totalItemCount', 0),
                '削除アイテム数': mailbox.get('totalDeletedItemCount', 0)
            }
            
            if include_archive:
                archive_size_bytes = mailbox.get('archiveSize', 0)
                archive_size_gb = archive_size_bytes / (1024**3) if archive_size_bytes else 0
                record['アーカイブ容量(GB)'] = f"{archive_size_gb:.2f}"
                record['アーカイブ有効'] = 'はい' if mailbox.get('archiveEnabled') else 'いいえ'
            
            if usage_stats and upn in mailbox_stats:
                stats = mailbox_stats[upn]
                record['送信メール数'] = stats.get('emailsSent', 0)
                record['受信メール数'] = stats.get('emailsReceived', 0)
                record['読取率'] = f"{stats.get('readPercentage', 0):.1f}%"
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_mailbox_data(
            include_shared, include_archive, size_threshold, department_filter, usage_stats
        )

def _generate_sample_mailbox_data(include_shared: bool, include_archive: bool,
                                size_threshold: int, department_filter: str, usage_stats: bool) -> List[Dict[str, Any]]:
    """Generate sample mailbox data"""
    
    import random
    
    sample_mailboxes = [
        {'name': '田中 太郎', 'email': 'tanaka@contoso.com', 'dept': 'IT部', 'type': 'UserMailbox', 'size_gb': 45.2, 'quota': 50},
        {'name': '佐藤 花子', 'email': 'sato@contoso.com', 'dept': '営業部', 'type': 'UserMailbox', 'size_gb': 38.7, 'quota': 100},
        {'name': '営業部共有', 'email': 'sales@contoso.com', 'dept': '営業部', 'type': 'SharedMailbox', 'size_gb': 78.3, 'quota': 100},
        {'name': '鈴木 次郎', 'email': 'suzuki@contoso.com', 'dept': '人事部', 'type': 'UserMailbox', 'size_gb': 15.6, 'quota': 50},
        {'name': '高橋 美咲', 'email': 'takahashi@contoso.com', 'dept': '経理部', 'type': 'UserMailbox', 'size_gb': 62.1, 'quota': 100},
        {'name': 'サポート', 'email': 'support@contoso.com', 'dept': 'IT部', 'type': 'SharedMailbox', 'size_gb': 25.4, 'quota': 50}
    ]
    
    report_data = []
    
    for mb in sample_mailboxes:
        # Apply filters
        if not include_shared and mb['type'] == 'SharedMailbox':
            continue
            
        if department_filter and mb['dept'].lower() != department_filter.lower():
            continue
        
        usage_percent = (mb['size_gb'] / mb['quota']) * 100
        
        # Determine status
        status = "正常"
        if usage_percent >= 95:
            status = "🚨 容量満杯"
        elif usage_percent >= size_threshold:
            status = "⚠️ 容量注意"
        
        # Generate last access time
        last_access = (datetime.now() - timedelta(days=random.randint(1, 30))).strftime('%Y-%m-%dT%H:%M:%SZ')
        
        record = {
            'ユーザー名': mb['name'],
            'メールアドレス': mb['email'],
            '部署': mb['dept'],
            'メールボックスタイプ': mb['type'],
            '総容量(GB)': f"{mb['size_gb']:.2f}",
            'クォータ(GB)': mb['quota'],
            '使用率': f"{usage_percent:.1f}%",
            'ステータス': status,
            '最終アクセス': last_access,
            'アイテム数': random.randint(5000, 50000),
            '削除アイテム数': random.randint(100, 5000)
        }
        
        if include_archive:
            archive_size = random.uniform(0, 20)
            record['アーカイブ容量(GB)'] = f"{archive_size:.2f}"
            record['アーカイブ有効'] = random.choice(['はい', 'いいえ'])
        
        if usage_stats:
            record['送信メール数'] = random.randint(50, 500)
            record['受信メール数'] = random.randint(200, 2000)
            record['読取率'] = f"{random.uniform(70, 95):.1f}%"
        
        report_data.append(record)
    
    return report_data

def _show_mailbox_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, size_threshold: int):
    """Show mailbox report summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_mailboxes = len(report_data)
    warning_mailboxes = len([r for r in report_data if '⚠️' in r.get('ステータス', '')])
    critical_mailboxes = len([r for r in report_data if '🚨' in r.get('ステータス', '')])
    normal_mailboxes = total_mailboxes - warning_mailboxes - critical_mailboxes
    
    # Calculate total storage
    total_storage = sum(float(r['総容量(GB)']) for r in report_data if r['総容量(GB)'])
    total_quota = sum(r['クォータ(GB)'] for r in report_data if isinstance(r['クォータ(GB)'], (int, float)))
    
    # Mailbox type breakdown
    type_stats = {}
    for record in report_data:
        mb_type = record.get('メールボックスタイプ', '不明')
        type_stats[mb_type] = type_stats.get(mb_type, 0) + 1
    
    overall_usage = (total_storage / total_quota * 100) if total_quota > 0 else 0
    
    click.echo("\n📧 Exchange Onlineメールボックスサマリー")
    click.echo("=" * 45)
    click.echo(f"📋 総メールボックス数: {total_mailboxes}")
    click.echo(f"✅ 正常: {normal_mailboxes}")
    click.echo(f"⚠️ 容量注意: {warning_mailboxes}")
    click.echo(f"🚨 容量満杯: {critical_mailboxes}")
    click.echo(f"💾 総使用容量: {total_storage:.2f}GB")
    click.echo(f"📊 総クォータ: {total_quota:.2f}GB")
    click.echo(f"📈 全体使用率: {overall_usage:.1f}%")
    
    # Mailbox type breakdown
    if type_stats:
        click.echo("\n📦 メールボックスタイプ別:")
        for mb_type, count in type_stats.items():
            percentage = (count / total_mailboxes) * 100
            click.echo(f"  📨 {mb_type}: {count} ({percentage:.1f}%)")
    
    # Storage health assessment
    click.echo("\n💾 ストレージ健全性:")
    if critical_mailboxes == 0 and warning_mailboxes <= total_mailboxes * 0.1:
        click.echo("  🎉 優秀: メールボックス容量管理は良好です")
    elif critical_mailboxes == 0 and warning_mailboxes <= total_mailboxes * 0.2:
        click.echo("  🔶 良好: 軽微な容量警告があります")
    elif critical_mailboxes <= 2:
        click.echo("  ⚠️ 注意: 容量管理の改善が必要です")
    else:
        click.echo("  🚨 警告: 深刻な容量問題があります")
    
    # Recommendations
    click.echo("\n💡 管理推奨事項:")
    if critical_mailboxes > 0:
        click.echo(f"  • {critical_mailboxes} 個の満杯メールボックスの即座の対応")
    if warning_mailboxes > 0:
        click.echo(f"  • {warning_mailboxes} 個の容量注意メールボックスの監視強化")
    if overall_usage > 80:
        click.echo("  • 全体的な容量使用率が高いです。クォータ拡張を検討")
    
    # Archive recommendations
    archive_count = len([r for r in report_data if r.get('アーカイブ有効') == 'いいえ'])
    if archive_count > 0:
        click.echo(f"  • {archive_count} 個のアーカイブ未有効メールボックスでのアーカイブ有効化")
    
    click.echo()

# Command alias for PowerShell compatibility
exchange_mailbox = mailbox_command