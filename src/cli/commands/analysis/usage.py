# Microsoft 365 Management Tools - Usage Analysis Command
# サービス別使用状況・普及率分析レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--service', type=click.Choice(['all', 'exchange', 'teams', 'onedrive', 'sharepoint', 'office']),
              default='all', help='対象サービス')
@click.option('--time-period', type=click.Choice(['7days', '30days', '90days']),
              default='30days', help='分析期間')
@click.option('--include-adoption-trends', is_flag=True, help='導入トレンドを含める')
@click.option('--department', help='特定部署のみ対象')
@click.pass_context
def usage_command(ctx, service, time_period, include_adoption_trends, department):
    """サービス別使用状況・普及率分析レポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 usage
    
    Microsoft 365各サービスの使用状況、普及率、採用トレンドを分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_usage_analysis(
        cli_context, service, time_period, include_adoption_trends, department
    ))

async def execute_usage_analysis(context: CLIContext,
                               service_filter: str = 'all',
                               time_period: str = '30days',
                               include_adoption_trends: bool = False,
                               department_filter: str = None):
    """Execute usage analysis report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("使用状況分析レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_usage_data(
                service_filter, time_period, include_adoption_trends, department_filter
            )
        else:
            report_data = await _generate_usage_analysis_data(
                context, service_filter, time_period, include_adoption_trends, department_filter
            )
        
        if not report_data:
            output.output_warning("使用状況データが見つかりませんでした")
            return
        
        output.output_success(f"使用状況分析レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="使用状況分析レポート",
            filename_prefix="usage_analysis_report"
        )
        
        _show_usage_summary(report_data, output, service_filter, time_period)
        
    except Exception as e:
        output.output_error(f"使用状況分析レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_usage_analysis_data(context: CLIContext,
                                      service_filter: str,
                                      time_period: str,
                                      include_adoption_trends: bool,
                                      department_filter: str) -> List[Dict[str, Any]]:
    """Generate usage analysis data from Microsoft 365 APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Calculate time period
        end_date = datetime.now()
        days_map = {'7days': 7, '30days': 30, '90days': 90}
        start_date = end_date - timedelta(days=days_map[time_period])
        
        # Get usage data
        output.output_progress("サービス使用状況データを取得中...")
        
        # Get users and their service usage
        users_data = await graph_client.get_users()
        usage_stats = await graph_client.get_service_usage_statistics(
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
        
        report_data = []
        
        # Process by service type
        services_to_analyze = ['exchange', 'teams', 'onedrive', 'sharepoint', 'office'] if service_filter == 'all' else [service_filter]
        
        for user in users_data:
            upn = user.get('userPrincipalName', '')
            display_name = user.get('displayName', '')
            dept = user.get('department', '不明')
            
            # Filter by department if specified
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            # Get user usage stats
            user_usage = usage_stats.get(upn, {})
            
            for service in services_to_analyze:
                service_data = user_usage.get(service, {})
                
                # Calculate usage metrics
                activity_count = service_data.get('activityCount', 0)
                last_activity = service_data.get('lastActivity')
                usage_hours = service_data.get('usageHours', 0.0)
                
                # Determine adoption status
                adoption_status = "未採用"
                if activity_count > 0:
                    if activity_count >= 10:  # Active user threshold
                        adoption_status = "アクティブ"
                    else:
                        adoption_status = "初期使用"
                
                # Calculate usage intensity
                usage_intensity = "低"
                if usage_hours > 20:  # High usage threshold
                    usage_intensity = "高"
                elif usage_hours > 5:
                    usage_intensity = "中"
                
                record = {
                    'ユーザー名': display_name,
                    'ユーザープリンシパル名': upn,
                    '部署': dept,
                    'サービス': service.title(),
                    '分析期間': f"{time_period}",
                    'アクティビティ数': activity_count,
                    '使用時間': f"{usage_hours:.1f}h",
                    '採用状況': adoption_status,
                    '使用強度': usage_intensity,
                    '最終アクティビティ': last_activity or 'なし',
                    'アカウント状態': user.get('accountEnabled', True) and '有効' or '無効'
                }
                
                # Add trend data if requested
                if include_adoption_trends:
                    trend_data = service_data.get('trendData', {})
                    record['週次成長率'] = f"{trend_data.get('weeklyGrowth', 0.0):+.1f}%"
                    record['月次成長率'] = f"{trend_data.get('monthlyGrowth', 0.0):+.1f}%"
                
                report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_usage_data(
            service_filter, time_period, include_adoption_trends, department_filter
        )

def _generate_sample_usage_data(service_filter: str, time_period: str,
                              include_adoption_trends: bool, department_filter: str) -> List[Dict[str, Any]]:
    """Generate sample usage analysis data"""
    
    import random
    
    sample_users = [
        ("田中 太郎", "tanaka@contoso.com", "IT部"),
        ("佐藤 花子", "sato@contoso.com", "営業部"),
        ("鈴木 次郎", "suzuki@contoso.com", "人事部"),
        ("高橋 美咲", "takahashi@contoso.com", "経理部"),
        ("渡辺 健一", "watanabe@contoso.com", "IT部"),
        ("山田 綾子", "yamada@contoso.com", "営業部"),
        ("中村 大輔", "nakamura@contoso.com", "開発部"),
        ("小林 真由美", "kobayashi@contoso.com", "マーケティング部")
    ]
    
    services_data = {
        'exchange': {'base_activity': 50, 'base_hours': 15.0},
        'teams': {'base_activity': 30, 'base_hours': 12.0},
        'onedrive': {'base_activity': 25, 'base_hours': 8.0},
        'sharepoint': {'base_activity': 20, 'base_hours': 6.0},
        'office': {'base_activity': 40, 'base_hours': 20.0}
    }
    
    services_to_analyze = [service_filter] if service_filter != 'all' else list(services_data.keys())
    
    report_data = []
    
    for name, upn, dept in sample_users:
        # Filter by department if specified
        if department_filter and dept.lower() != department_filter.lower():
            continue
        
        for service in services_to_analyze:
            service_info = services_data[service]
            
            # Generate random usage data with realistic variations
            activity_count = max(0, int(service_info['base_activity'] * random.uniform(0.3, 1.8)))
            usage_hours = max(0.0, service_info['base_hours'] * random.uniform(0.2, 2.0))
            
            # Determine adoption status
            adoption_status = "未採用"
            if activity_count > 0:
                if activity_count >= 10:
                    adoption_status = "アクティブ"
                else:
                    adoption_status = "初期使用"
            
            # Calculate usage intensity
            usage_intensity = "低"
            if usage_hours > 20:
                usage_intensity = "高"
            elif usage_hours > 5:
                usage_intensity = "中"
            
            # Generate last activity
            last_activity = "なし"
            if activity_count > 0:
                days_ago = random.randint(1, 7)
                last_activity = (datetime.now() - timedelta(days=days_ago)).strftime('%Y-%m-%d')
            
            record = {
                'ユーザー名': name,
                'ユーザープリンシパル名': upn,
                '部署': dept,
                'サービス': service.title(),
                '分析期間': time_period,
                'アクティビティ数': activity_count,
                '使用時間': f"{usage_hours:.1f}h",
                '採用状況': adoption_status,
                '使用強度': usage_intensity,
                '最終アクティビティ': last_activity,
                'アカウント状態': '有効'
            }
            
            # Add trend data if requested
            if include_adoption_trends:
                weekly_growth = random.uniform(-5.0, 15.0)
                monthly_growth = random.uniform(-10.0, 25.0)
                record['週次成長率'] = f"{weekly_growth:+.1f}%"
                record['月次成長率'] = f"{monthly_growth:+.1f}%"
            
            report_data.append(record)
    
    return report_data

def _show_usage_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, 
                       service_filter: str, time_period: str):
    """Show usage analysis summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_records = len(report_data)
    active_users = len([r for r in report_data if r['採用状況'] == 'アクティブ'])
    initial_users = len([r for r in report_data if r['採用状況'] == '初期使用'])
    non_users = len([r for r in report_data if r['採用状況'] == '未採用'])
    
    # Service breakdown if analyzing all services
    service_stats = {}
    if service_filter == 'all':
        for record in report_data:
            service = record['サービス']
            if service not in service_stats:
                service_stats[service] = {'active': 0, 'initial': 0, 'none': 0}
            
            status = record['採用状況']
            if status == 'アクティブ':
                service_stats[service]['active'] += 1
            elif status == '初期使用':
                service_stats[service]['initial'] += 1
            else:
                service_stats[service]['none'] += 1
    
    # Calculate adoption rate
    adoption_rate = ((active_users + initial_users) / total_records) * 100 if total_records > 0 else 0
    active_rate = (active_users / total_records) * 100 if total_records > 0 else 0
    
    click.echo("\n📊 使用状況分析サマリー")
    click.echo("=" * 35)
    click.echo(f"📅 分析期間: {time_period}")
    click.echo(f"🎯 対象サービス: {service_filter.upper()}")
    click.echo(f"📋 総レコード数: {total_records}")
    click.echo(f"🔥 アクティブユーザー: {active_users} ({active_rate:.1f}%)")
    click.echo(f"🔶 初期使用ユーザー: {initial_users}")
    click.echo(f"❌ 未採用ユーザー: {non_users}")
    click.echo(f"📈 総採用率: {adoption_rate:.1f}%")
    
    # Service-specific statistics
    if service_stats:
        click.echo("\n📦 サービス別採用状況:")
        for service, stats in service_stats.items():
            total_service = stats['active'] + stats['initial'] + stats['none']
            service_adoption = ((stats['active'] + stats['initial']) / total_service) * 100 if total_service > 0 else 0
            click.echo(f"  📧 {service}: {stats['active']}活発, {stats['initial']}初期, {stats['none']}未採用 ({service_adoption:.1f}%)")
    
    # Usage intensity analysis
    high_intensity = len([r for r in report_data if r['使用強度'] == '高'])
    medium_intensity = len([r for r in report_data if r['使用強度'] == '中'])
    low_intensity = len([r for r in report_data if r['使用強度'] == '低'])
    
    click.echo("\n⚡ 使用強度分析:")
    click.echo(f"  🔥 高強度: {high_intensity} ({high_intensity/total_records*100:.1f}%)")
    click.echo(f"  🔶 中強度: {medium_intensity} ({medium_intensity/total_records*100:.1f}%)")
    click.echo(f"  🔵 低強度: {low_intensity} ({low_intensity/total_records*100:.1f}%)")
    
    # Recommendations
    click.echo("\n💡 改善提案:")
    if adoption_rate < 50:
        click.echo("  • 採用率が低いです。トレーニングプログラムの実施を推奨")
    if non_users > total_records * 0.3:
        click.echo("  • 未採用ユーザーが多いです。導入支援の強化を検討")
    if high_intensity < total_records * 0.2:
        click.echo("  • 高強度ユーザーが少ないです。機能活用の促進を推奨")
    if active_rate > 80:
        click.echo("  • 優秀な採用率です。ベストプラクティスの他部署展開を検討")
    
    click.echo()

# Command alias for PowerShell compatibility
usage_analysis = usage_command