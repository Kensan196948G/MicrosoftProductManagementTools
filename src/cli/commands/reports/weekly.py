# Microsoft 365 Management Tools - Weekly Report Command
# 週次活動レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--start-date', type=click.DateTime(['%Y-%m-%d']), 
              help='開始日 (YYYY-MM-DD形式、未指定時は先週)')
@click.option('--end-date', type=click.DateTime(['%Y-%m-%d']),
              help='終了日 (YYYY-MM-DD形式、未指定時は先週末)')
@click.option('--include-weekend', is_flag=True,
              help='週末データを含める')
@click.option('--department', help='特定部署のみ対象')
@click.pass_context
def weekly_command(ctx, start_date, end_date, include_weekend, department):
    """週次活動・MFA状況レポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 weekly
    
    Microsoft 365の週次アクティビティ、MFA設定状況、外部共有を分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    # Default to last week if no dates specified
    if not start_date:
        today = datetime.now()
        start_date = today - timedelta(days=today.weekday() + 7)  # Last Monday
    if not end_date:
        end_date = start_date + timedelta(days=6)  # Following Sunday
    
    asyncio.run(execute_weekly_report(cli_context, start_date, end_date, include_weekend, department))

async def execute_weekly_report(context: CLIContext,
                              start_date: datetime,
                              end_date: datetime,
                              include_weekend: bool = True,
                              department_filter: str = None):
    """Execute weekly activity report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("週次レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_weekly_data(start_date, end_date, department_filter)
        else:
            report_data = await _generate_weekly_report_data(
                context, start_date, end_date, include_weekend, department_filter
            )
        
        if not report_data:
            output.output_warning("対象期間のデータが見つかりませんでした")
            return
        
        output.output_success(f"週次レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="週次活動レポート",
            filename_prefix="weekly_activity_report"
        )
        
        _show_weekly_summary(report_data, output, start_date, end_date)
        
    except Exception as e:
        output.output_error(f"週次レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_weekly_report_data(context: CLIContext,
                                     start_date: datetime,
                                     end_date: datetime,
                                     include_weekend: bool,
                                     department_filter: str) -> List[Dict[str, Any]]:
    """Generate weekly report data from Microsoft 365 APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get weekly data
        output.output_progress("週次アクティビティデータを取得中...")
        
        # Users with MFA status
        users_data = await graph_client.get_users_with_mfa_status()
        
        # Activity data for the week
        activity_data = await graph_client.get_weekly_activity(
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
        
        report_data = []
        
        for user in users_data:
            upn = user.get('userPrincipalName', '')
            display_name = user.get('displayName', '')
            dept = user.get('department', '不明')
            
            # Filter by department if specified
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            # Get activity for this user
            user_activity = activity_data.get(upn, {})
            
            # MFA status
            mfa_status = user.get('mfaEnabled', False)
            mfa_methods = user.get('mfaMethods', [])
            
            # Weekly activity metrics
            total_logins = user_activity.get('loginCount', 0)
            unique_apps = len(user_activity.get('applicationsUsed', []))
            last_activity = user_activity.get('lastActivity')
            
            # Risk assessment
            risk_level = "低"
            if not mfa_status:
                risk_level = "高"
            elif total_logins == 0:
                risk_level = "中"
            
            record = {
                'ユーザー名': display_name,
                'ユーザープリンシパル名': upn,
                '部署': dept,
                '週次ログイン回数': total_logins,
                '使用アプリ数': unique_apps,
                'MFA状態': mfa_status and 'enabled' or 'disabled',
                'MFA方法': ', '.join(mfa_methods) if mfa_methods else 'なし',
                '最終アクティビティ': last_activity or 'なし',
                'リスクレベル': risk_level,
                '期間': f"{start_date.strftime('%Y-%m-%d')} - {end_date.strftime('%Y-%m-%d')}"
            }
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_weekly_data(start_date, end_date, department_filter)

def _generate_sample_weekly_data(start_date: datetime, end_date: datetime, department_filter: str) -> List[Dict[str, Any]]:
    """Generate sample weekly report data"""
    
    sample_data = [
        ("田中 太郎", "tanaka@contoso.com", "IT部", 45, 8, "enabled", "SMS, アプリ", "低"),
        ("佐藤 花子", "sato@contoso.com", "営業部", 52, 6, "enabled", "SMS", "低"),
        ("鈴木 次郎", "suzuki@contoso.com", "人事部", 38, 5, "disabled", "なし", "高"),
        ("高橋 美咲", "takahashi@contoso.com", "経理部", 0, 0, "enabled", "アプリ", "中"),
        ("渡辺 健一", "watanabe@contoso.com", "IT部", 67, 12, "enabled", "SMS, アプリ, 電話", "低"),
        ("山田 綾子", "yamada@contoso.com", "営業部", 41, 7, "disabled", "なし", "高"),
        ("中村 大輔", "nakamura@contoso.com", "開発部", 58, 9, "enabled", "アプリ", "低"),
        ("小林 真由美", "kobayashi@contoso.com", "マーケティング部", 33, 4, "enabled", "SMS", "低")
    ]
    
    report_data = []
    
    for user_data in sample_data:
        name, upn, dept, logins, apps, mfa, methods, risk = user_data
        
        # Filter by department if specified
        if department_filter and dept.lower() != department_filter.lower():
            continue
        
        # Generate last activity time
        import random
        if logins > 0:
            activity_date = start_date + timedelta(days=random.randint(0, 6))
            last_activity = activity_date.strftime('%Y-%m-%d %H:%M:%S')
        else:
            last_activity = 'なし'
        
        record = {
            'ユーザー名': name,
            'ユーザープリンシパル名': upn,
            '部署': dept,
            '週次ログイン回数': logins,
            '使用アプリ数': apps,
            'MFA状態': mfa,
            'MFA方法': methods,
            '最終アクティビティ': last_activity,
            'リスクレベル': risk,
            '期間': f"{start_date.strftime('%Y-%m-%d')} - {end_date.strftime('%Y-%m-%d')}"
        }
        
        report_data.append(record)
    
    return report_data

def _show_weekly_summary(report_data: List[Dict[str, Any]], output: OutputFormatter,
                        start_date: datetime, end_date: datetime):
    """Show weekly report summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_users = len(report_data)
    active_users = len([r for r in report_data if r['週次ログイン回数'] > 0])
    mfa_enabled = len([r for r in report_data if r['MFA状態'] == 'enabled'])
    high_risk = len([r for r in report_data if r['リスクレベル'] == '高'])
    
    total_logins = sum(r['週次ログイン回数'] for r in report_data)
    avg_logins = total_logins / max(active_users, 1)
    
    click.echo("\\n📈 週次レポートサマリー")
    click.echo("=" * 30)
    click.echo(f"📅 期間: {start_date.strftime('%Y-%m-%d')} - {end_date.strftime('%Y-%m-%d')}")
    click.echo(f"👥 総ユーザー数: {total_users}")
    click.echo(f"✅ アクティブユーザー: {active_users}")
    click.echo(f"🔐 MFA有効ユーザー: {mfa_enabled} ({mfa_enabled/total_users*100:.1f}%)")
    click.echo(f"⚠️ 高リスクユーザー: {high_risk}")
    click.echo(f"🔢 総ログイン回数: {total_logins}")
    click.echo(f"📊 平均ログイン回数: {avg_logins:.1f}")
    click.echo()

# Command alias for PowerShell compatibility
weekly_report = weekly_command