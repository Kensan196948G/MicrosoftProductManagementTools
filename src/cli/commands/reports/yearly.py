# Microsoft 365 Management Tools - Yearly Report Command
# 年次統計レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--year', type=int, help='対象年 (未指定時は前年)')
@click.option('--include-monthly-trends', is_flag=True, help='月別トレンドを含める')
@click.option('--license-analysis', is_flag=True, help='ライセンス分析を含める')
@click.option('--cost-analysis', is_flag=True, help='コスト分析を含める')
@click.pass_context
def yearly_command(ctx, year, include_monthly_trends, license_analysis, cost_analysis):
    """年次統計・インシデント統計・コンプライアンスレポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 yearly
    
    Microsoft 365の年間利用統計、インシデント分析、コンプライアンス状況を総合的に分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    # Default to last year if not specified
    if not year:
        year = datetime.now().year - 1
    
    target_year = datetime(year, 1, 1)
    
    asyncio.run(execute_yearly_report(
        cli_context, target_year, include_monthly_trends, license_analysis, cost_analysis
    ))

async def execute_yearly_report(context: CLIContext,
                               target_year: datetime,
                               include_trends: bool = False,
                               license_analysis: bool = False,
                               cost_analysis: bool = False):
    """Execute yearly statistics report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("年次レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_yearly_data(target_year)
        else:
            report_data = await _generate_yearly_report_data(
                context, target_year, include_trends, license_analysis, cost_analysis
            )
        
        if not report_data:
            output.output_warning("対象年のデータが見つかりませんでした")
            return
        
        output.output_success(f"年次レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="年次統計レポート",
            filename_prefix="yearly_statistics_report"
        )
        
        _show_yearly_summary(report_data, output, target_year)
        
    except Exception as e:
        output.output_error(f"年次レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_yearly_report_data(context: CLIContext,
                                     target_year: datetime,
                                     include_trends: bool,
                                     license_analysis: bool,
                                     cost_analysis: bool) -> List[Dict[str, Any]]:
    """Generate yearly report data from Microsoft 365 APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get yearly statistics
        output.output_progress("年次統計データを取得中...")
        
        start_date = target_year
        end_date = datetime(target_year.year + 1, 1, 1) - timedelta(days=1)
        
        # Get comprehensive yearly data
        yearly_stats = await graph_client.get_yearly_statistics(
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
        
        # Get incident data
        incidents = await graph_client.get_security_incidents(
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
        
        # Get license information
        license_data = await graph_client.get_license_statistics()
        
        report_data = []
        
        # Monthly breakdown
        for month in range(1, 13):
            month_date = datetime(target_year.year, month, 1)
            month_stats = yearly_stats.get(f"{target_year.year}-{month:02d}", {})
            
            # Calculate monthly metrics
            active_users = month_stats.get('activeUsers', 0)
            total_logins = month_stats.get('totalLogins', 0)
            security_incidents = len([i for i in incidents if i.get('month') == month])
            
            # Service adoption
            exchange_adoption = month_stats.get('exchangeAdoption', 0.0)
            teams_adoption = month_stats.get('teamsAdoption', 0.0)
            onedrive_adoption = month_stats.get('onedriveAdoption', 0.0)
            
            # Compliance score
            compliance_score = month_stats.get('complianceScore', 85.0)
            
            record = {
                '年': target_year.year,
                '月': month,
                '月名': month_date.strftime('%B'),
                'アクティブユーザー数': active_users,
                '総ログイン回数': total_logins,
                'セキュリティインシデント': security_incidents,
                'Exchange導入率': f"{exchange_adoption:.1f}%",
                'Teams導入率': f"{teams_adoption:.1f}%",
                'OneDrive導入率': f"{onedrive_adoption:.1f}%",
                'コンプライアンススコア': f"{compliance_score:.1f}%",
                'ライセンス使用率': f"{month_stats.get('licenseUtilization', 75.0):.1f}%"
            }
            
            if cost_analysis:
                monthly_cost = month_stats.get('monthlyCost', 5000.0)
                cost_per_user = monthly_cost / max(active_users, 1)
                record['月次コスト'] = f"${monthly_cost:,.2f}"
                record['ユーザーあたりコスト'] = f"${cost_per_user:.2f}"
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_yearly_data(target_year)

def _generate_sample_yearly_data(target_year: datetime) -> List[Dict[str, Any]]:
    """Generate sample yearly report data"""
    
    import random
    
    base_users = 150
    report_data = []
    
    months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    for month_num in range(1, 13):
        # Simulate seasonal variations
        seasonal_factor = 1.0
        if month_num in [7, 8, 12]:  # Summer vacation and December
            seasonal_factor = 0.8
        elif month_num in [1, 9]:  # New Year and September
            seasonal_factor = 1.2
        
        active_users = int(base_users * seasonal_factor * random.uniform(0.9, 1.1))
        total_logins = active_users * random.randint(18, 25)
        incidents = random.randint(0, 3)
        
        # Service adoption (gradually improving over year)
        exchange_adoption = min(95.0, 75.0 + (month_num * 1.5) + random.uniform(-2, 2))
        teams_adoption = min(90.0, 60.0 + (month_num * 2.0) + random.uniform(-3, 3))
        onedrive_adoption = min(88.0, 65.0 + (month_num * 1.8) + random.uniform(-2, 2))
        
        # Compliance score
        compliance_score = min(98.0, 85.0 + random.uniform(-3, 5))
        
        # License utilization
        license_util = min(95.0, 70.0 + random.uniform(5, 15))
        
        record = {
            '年': target_year.year,
            '月': month_num,
            '月名': months[month_num - 1],
            'アクティブユーザー数': active_users,
            '総ログイン回数': total_logins,
            'セキュリティインシデント': incidents,
            'Exchange導入率': f"{exchange_adoption:.1f}%",
            'Teams導入率': f"{teams_adoption:.1f}%",
            'OneDrive導入率': f"{onedrive_adoption:.1f}%",
            'コンプライアンススコア': f"{compliance_score:.1f}%",
            'ライセンス使用率': f"{license_util:.1f}%",
            '月次コスト': f"${random.uniform(4500, 6500):,.2f}",
            'ユーザーあたりコスト': f"${random.uniform(30, 45):.2f}"
        }
        
        report_data.append(record)
    
    return report_data

def _show_yearly_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, target_year: datetime):
    """Show yearly report summary"""
    
    if not report_data:
        return
    
    # Calculate yearly totals
    total_users = sum(r['アクティブユーザー数'] for r in report_data) // 12  # Average
    total_logins = sum(r['総ログイン回数'] for r in report_data)
    total_incidents = sum(r['セキュリティインシデント'] for r in report_data)
    
    # Parse adoption rates
    avg_exchange = sum(float(r['Exchange導入率'].rstrip('%')) for r in report_data) / 12
    avg_teams = sum(float(r['Teams導入率'].rstrip('%')) for r in report_data) / 12
    avg_onedrive = sum(float(r['OneDrive導入率'].rstrip('%')) for r in report_data) / 12
    avg_compliance = sum(float(r['コンプライアンススコア'].rstrip('%')) for r in report_data) / 12
    
    # Calculate growth (compare first vs last month)
    first_month = report_data[0]
    last_month = report_data[-1]
    user_growth = last_month['アクティブユーザー数'] - first_month['アクティブユーザー数']
    growth_rate = (user_growth / first_month['アクティブユーザー数']) * 100 if first_month['アクティブユーザー数'] > 0 else 0
    
    click.echo("\\n📈 年次レポートサマリー")
    click.echo("=" * 40)
    click.echo(f"📅 対象年: {target_year.year}年")
    click.echo(f"👥 平均アクティブユーザー数: {total_users}")
    click.echo(f"🔢 年間総ログイン回数: {total_logins:,}")
    click.echo(f"⚠️ 年間セキュリティインシデント: {total_incidents}")
    click.echo(f"📈 ユーザー成長率: {growth_rate:+.1f}%")
    click.echo()
    click.echo("📊 平均サービス導入率:")
    click.echo(f"  📧 Exchange Online: {avg_exchange:.1f}%")
    click.echo(f"  💬 Microsoft Teams: {avg_teams:.1f}%")
    click.echo(f"  💾 OneDrive: {avg_onedrive:.1f}%")
    click.echo(f"📋 平均コンプライアンススコア: {avg_compliance:.1f}%")
    
    # Show trends
    if len(report_data) >= 12:
        q1_users = sum(r['アクティブユーザー数'] for r in report_data[0:3]) / 3
        q4_users = sum(r['アクティブユーザー数'] for r in report_data[9:12]) / 3
        quarterly_growth = ((q4_users - q1_users) / q1_users) * 100 if q1_users > 0 else 0
        
        click.echo(f"📈 四半期成長率 (Q1→Q4): {quarterly_growth:+.1f}%")
    
    # Security assessment
    if total_incidents == 0:
        security_status = "優秀"
    elif total_incidents <= 6:
        security_status = "良好"
    elif total_incidents <= 12:
        security_status = "注意が必要"
    else:
        security_status = "改善が必要"
    
    click.echo(f"🔒 年間セキュリティ評価: {security_status}")
    click.echo()

# Command alias for PowerShell compatibility
yearly_report = yearly_command