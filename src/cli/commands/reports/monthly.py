# Microsoft 365 Management Tools - Monthly Report Command
# 月次利用状況レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--year', type=int, help='対象年 (未指定時は前月の年)')
@click.option('--month', type=int, help='対象月 (未指定時は前月)')
@click.option('--include-trends', is_flag=True, help='トレンド分析を含める')
@click.option('--service', type=click.Choice(['all', 'exchange', 'teams', 'onedrive', 'sharepoint']), 
              default='all', help='対象サービス')
@click.pass_context
def monthly_command(ctx, year, month, include_trends, service):
    """月次利用状況・権限レビューレポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 monthly
    
    Microsoft 365の月次利用統計、権限変更、グループメンバーシップを分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    # Default to last month if not specified
    if not year or not month:
        today = datetime.now()
        if today.month == 1:
            year = today.year - 1
            month = 12
        else:
            year = today.year
            month = today.month - 1
    
    target_date = datetime(year, month, 1)
    
    asyncio.run(execute_monthly_report(cli_context, target_date, include_trends, service))

async def execute_monthly_report(context: CLIContext,
                                target_month: datetime,
                                include_trends: bool = False,
                                service_filter: str = 'all'):
    """Execute monthly utilization report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("月次レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_monthly_data(target_month, service_filter)
        else:
            report_data = await _generate_monthly_report_data(
                context, target_month, include_trends, service_filter
            )
        
        if not report_data:
            output.output_warning("対象月のデータが見つかりませんでした")
            return
        
        output.output_success(f"月次レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="月次利用状況レポート",
            filename_prefix="monthly_utilization_report"
        )
        
        _show_monthly_summary(report_data, output, target_month)
        
    except Exception as e:
        output.output_error(f"月次レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_monthly_report_data(context: CLIContext,
                                      target_month: datetime,
                                      include_trends: bool,
                                      service_filter: str) -> List[Dict[str, Any]]:
    """Generate monthly report data from Microsoft 365 APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get monthly usage data
        output.output_progress("月次利用状況データを取得中...")
        
        # Calculate month range
        start_date = target_month
        if target_month.month == 12:
            end_date = datetime(target_month.year + 1, 1, 1) - timedelta(days=1)
        else:
            end_date = datetime(target_month.year, target_month.month + 1, 1) - timedelta(days=1)
        
        # Get service usage data
        usage_data = await graph_client.get_monthly_service_usage(
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
        
        # Get user details
        users_data = await graph_client.get_users()
        
        report_data = []
        
        for user in users_data:
            upn = user.get('userPrincipalName', '')
            display_name = user.get('displayName', '')
            dept = user.get('department', '不明')
            
            # Get usage for this user
            user_usage = usage_data.get(upn, {})
            
            # Service-specific data
            exchange_usage = user_usage.get('exchange', {})
            teams_usage = user_usage.get('teams', {})
            onedrive_usage = user_usage.get('onedrive', {})
            
            # Filter by service if specified
            if service_filter != 'all':
                if service_filter == 'exchange' and not exchange_usage:
                    continue
                elif service_filter == 'teams' and not teams_usage:
                    continue
                elif service_filter == 'onedrive' and not onedrive_usage:
                    continue
            
            # Calculate activity score
            activity_score = 0
            if exchange_usage.get('emailsReceived', 0) > 0:
                activity_score += 30
            if teams_usage.get('meetingsAttended', 0) > 0:
                activity_score += 35
            if onedrive_usage.get('filesAccessed', 0) > 0:
                activity_score += 35
            
            utilization_level = "低"
            if activity_score >= 70:
                utilization_level = "高"
            elif activity_score >= 40:
                utilization_level = "中"
            
            record = {
                'ユーザー名': display_name,
                'ユーザープリンシパル名': upn,
                '部署': dept,
                '対象月': target_month.strftime('%Y-%m'),
                'Exchange使用': exchange_usage.get('emailsReceived', 0),
                'Teams使用': teams_usage.get('meetingsAttended', 0),
                'OneDrive使用': onedrive_usage.get('filesAccessed', 0),
                '活動スコア': activity_score,
                '利用レベル': utilization_level,
                '最終アクセス': user_usage.get('lastActivity', 'なし'),
                'ライセンス': user.get('assignedLicenses', [{}])[0].get('skuPartNumber', '未割り当て') if user.get('assignedLicenses') else '未割り当て'
            }
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_monthly_data(target_month, service_filter)

def _generate_sample_monthly_data(target_month: datetime, service_filter: str) -> List[Dict[str, Any]]:
    """Generate sample monthly report data"""
    
    sample_data = [
        ("田中 太郎", "tanaka@contoso.com", "IT部", 245, 18, 127, "高", "ENTERPRISEPACK"),
        ("佐藤 花子", "sato@contoso.com", "営業部", 189, 22, 89, "高", "ENTERPRISEPACK"),
        ("鈴木 次郎", "suzuki@contoso.com", "人事部", 156, 12, 45, "中", "ENTERPRISEPACK"),
        ("高橋 美咲", "takahashi@contoso.com", "経理部", 78, 5, 23, "低", "ENTERPRISEPACK"),
        ("渡辺 健一", "watanabe@contoso.com", "IT部", 312, 28, 156, "高", "ENTERPRISEPACK"),
        ("山田 綾子", "yamada@contoso.com", "営業部", 201, 15, 67, "中", "ENTERPRISEPACK"),
        ("中村 大輔", "nakamura@contoso.com", "開発部", 267, 31, 198, "高", "ENTERPRISEPACK"),
        ("小林 真由美", "kobayashi@contoso.com", "マーケティング部", 134, 9, 34, "中", "ENTERPRISEPACK")
    ]
    
    report_data = []
    
    for user_data in sample_data:
        name, upn, dept, exchange, teams, onedrive, level, license = user_data
        
        # Calculate activity score
        activity_score = 0
        if exchange > 0:
            activity_score += min(30, (exchange / 200) * 30)
        if teams > 0:
            activity_score += min(35, (teams / 20) * 35)
        if onedrive > 0:
            activity_score += min(35, (onedrive / 100) * 35)
        
        activity_score = int(activity_score)
        
        # Generate last activity
        import random
        last_activity_days = random.randint(1, 30)
        last_activity = (target_month + timedelta(days=last_activity_days)).strftime('%Y-%m-%d')
        
        record = {
            'ユーザー名': name,
            'ユーザープリンシパル名': upn,
            '部署': dept,
            '対象月': target_month.strftime('%Y-%m'),
            'Exchange使用': exchange,
            'Teams使用': teams,
            'OneDrive使用': onedrive,
            '活動スコア': activity_score,
            '利用レベル': level,
            '最終アクセス': last_activity,
            'ライセンス': license
        }
        
        report_data.append(record)
    
    return report_data

def _show_monthly_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, target_month: datetime):
    """Show monthly report summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_users = len(report_data)
    high_utilization = len([r for r in report_data if r['利用レベル'] == '高'])
    medium_utilization = len([r for r in report_data if r['利用レベル'] == '中'])
    low_utilization = len([r for r in report_data if r['利用レベル'] == '低'])
    
    total_exchange = sum(r['Exchange使用'] for r in report_data)
    total_teams = sum(r['Teams使用'] for r in report_data)
    total_onedrive = sum(r['OneDrive使用'] for r in report_data)
    
    avg_activity_score = sum(r['活動スコア'] for r in report_data) / total_users
    
    click.echo("\\n📈 月次レポートサマリー")
    click.echo("=" * 30)
    click.echo(f"📅 対象月: {target_month.strftime('%Y年%m月')}")
    click.echo(f"👥 総ユーザー数: {total_users}")
    click.echo(f"🔥 高利用ユーザー: {high_utilization} ({high_utilization/total_users*100:.1f}%)")
    click.echo(f"🔶 中利用ユーザー: {medium_utilization} ({medium_utilization/total_users*100:.1f}%)")
    click.echo(f"🔵 低利用ユーザー: {low_utilization} ({low_utilization/total_users*100:.1f}%)")
    click.echo(f"📧 Exchange総利用: {total_exchange}")
    click.echo(f"💬 Teams総利用: {total_teams}")
    click.echo(f"💾 OneDrive総利用: {total_onedrive}")
    click.echo(f"📊 平均活動スコア: {avg_activity_score:.1f}")
    click.echo()

# Command alias for PowerShell compatibility
monthly_report = monthly_command