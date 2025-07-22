# Microsoft 365 Management Tools - Daily Report Command
# 日次セキュリティレポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--date', type=click.DateTime(['%Y-%m-%d']), 
              help='レポート対象日 (YYYY-MM-DD形式、未指定時は昨日)')
@click.option('--include-inactive', is_flag=True, 
              help='非アクティブユーザーを含める')
@click.option('--security-only', is_flag=True,
              help='セキュリティ関連データのみ')
@click.option('--format', type=click.Choice(['table', 'summary']), default='table',
              help='出力形式')
@click.pass_context
def daily_command(ctx, date, include_inactive, security_only, format):
    """日次セキュリティ・活動レポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 daily
    
    Microsoft 365の日次アクティビティとセキュリティ状況を分析します。
    ユーザーのサインイン状況、セキュリティアラート、システムの健全性を確認。
    """
    
    cli_context: CLIContext = ctx.obj
    
    # Default to yesterday if no date specified
    if not date:
        date = datetime.now() - timedelta(days=1)
    
    # Run async execution
    asyncio.run(execute_daily_report(cli_context, date, include_inactive, security_only, format))

async def execute_daily_report(context: CLIContext, 
                             target_date: datetime,
                             include_inactive: bool = False,
                             security_only: bool = False,
                             output_format: str = 'table'):
    """Execute daily security report"""
    
    output = OutputFormatter(context)
    
    try:
        # Show progress
        output.output_progress("日次レポート生成を開始しています...")
        
        if context.dry_run:
            output.output_info("ドライランモード: サンプルデータを生成します")
            report_data = _generate_sample_daily_data(target_date, include_inactive)
        else:
            # Generate real report data
            report_data = await _generate_daily_report_data(context, target_date, include_inactive, security_only)
        
        if not report_data:
            output.output_warning("対象日のデータが見つかりませんでした")
            return
        
        # Output results
        output.output_success(f"日次レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="日次セキュリティレポート",
            filename_prefix="daily_security_report"
        )
        
        # Show summary if requested
        if output_format == 'summary':
            _show_daily_summary(report_data, output)
        
    except Exception as e:
        output.output_error(f"日次レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_daily_report_data(context: CLIContext, 
                                    target_date: datetime,
                                    include_inactive: bool,
                                    security_only: bool) -> List[Dict[str, Any]]:
    """Generate daily report data from Microsoft 365 APIs"""
    
    try:
        # Import Microsoft Graph client
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        # Initialize authentication
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        
        # Create Graph client
        graph_client = GraphClient(authenticator)
        
        report_data = []
        
        # Get user signin activities
        output = OutputFormatter(context)
        output.output_progress("ユーザーサインイン情報を取得中...")
        
        # Get signin logs for the target date
        signin_data = await graph_client.get_signin_logs(
            start_date=target_date.strftime('%Y-%m-%d'),
            end_date=(target_date + timedelta(days=1)).strftime('%Y-%m-%d')
        )
        
        # Get user information
        output.output_progress("ユーザー情報を取得中...")
        users_data = await graph_client.get_users(include_inactive=include_inactive)
        
        # Process and combine data
        output.output_progress("データを処理中...")
        
        user_activities = {}
        
        # Process signin logs
        for signin in signin_data:
            user_upn = signin.get('userPrincipalName', '')
            if user_upn not in user_activities:
                user_activities[user_upn] = {
                    'signin_count': 0,
                    'successful_signin': 0,
                    'failed_signin': 0,
                    'risk_events': 0,
                    'last_signin': None
                }
            
            user_activities[user_upn]['signin_count'] += 1
            
            if signin.get('status', {}).get('errorCode') == 0:
                user_activities[user_upn]['successful_signin'] += 1
            else:
                user_activities[user_upn]['failed_signin'] += 1
            
            # Check for risk
            if signin.get('riskLevelDuringSignIn') in ['medium', 'high']:
                user_activities[user_upn]['risk_events'] += 1
            
            # Track last signin time
            signin_time = signin.get('createdDateTime')
            if signin_time:
                if not user_activities[user_upn]['last_signin'] or signin_time > user_activities[user_upn]['last_signin']:
                    user_activities[user_upn]['last_signin'] = signin_time
        
        # Generate report records
        for user in users_data:
            user_upn = user.get('userPrincipalName', '')
            display_name = user.get('displayName', '')
            department = user.get('department', '不明')
            
            activity = user_activities.get(user_upn, {
                'signin_count': 0,
                'successful_signin': 0,
                'failed_signin': 0,
                'risk_events': 0,
                'last_signin': None
            })
            
            # Determine security status
            security_risk = "正常"
            if activity['risk_events'] > 0:
                security_risk = "⚠️ 高リスク"
            elif activity['failed_signin'] > 5:
                security_risk = "⚠️ 注意"
            elif activity['signin_count'] == 0:
                security_risk = "✗ 非アクティブ"
            
            # Skip inactive users if not requested
            if not include_inactive and activity['signin_count'] == 0:
                continue
            
            # Skip non-security data if security only
            if security_only and security_risk == "正常":
                continue
            
            report_record = {
                'ユーザー名': display_name,
                'ユーザープリンシパル名': user_upn,
                '部署': department,
                'サインイン回数': activity['signin_count'],
                '成功回数': activity['successful_signin'],
                '失敗回数': activity['failed_signin'],
                'リスクイベント': activity['risk_events'],
                '最終サインイン': activity['last_signin'] or 'なし',
                'セキュリティリスク': security_risk,
                'アカウント状態': user.get('accountEnabled', True) and '有効' or '無効',
                'レポート日': target_date.strftime('%Y-%m-%d')
            }
            
            report_data.append(report_record)
        
        return report_data
        
    except Exception as e:
        # Fallback to sample data if API fails
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_daily_data(target_date, include_inactive)

def _generate_sample_daily_data(target_date: datetime, include_inactive: bool) -> List[Dict[str, Any]]:
    """Generate sample daily report data for testing"""
    
    sample_users = [
        ("田中 太郎", "tanaka@contoso.com", "IT部", 25, 25, 0, 0, "正常", "有効"),
        ("佐藤 花子", "sato@contoso.com", "営業部", 18, 17, 1, 0, "正常", "有効"),
        ("鈴木 次郎", "suzuki@contoso.com", "人事部", 12, 10, 2, 1, "⚠️ 注意", "有効"),
        ("高橋 美咲", "takahashi@contoso.com", "経理部", 0, 0, 0, 0, "✗ 非アクティブ", "無効"),
        ("渡辺 健一", "watanabe@contoso.com", "IT部", 32, 28, 4, 2, "⚠️ 高リスク", "有効"),
        ("山田 綾子", "yamada@contoso.com", "営業部", 21, 21, 0, 0, "正常", "有効"),
        ("中村 大輔", "nakamura@contoso.com", "開発部", 19, 19, 0, 0, "正常", "有効"),
        ("小林 真由美", "kobayashi@contoso.com", "マーケティング部", 15, 13, 2, 0, "正常", "有効")
    ]
    
    report_data = []
    
    for user_data in sample_users:
        display_name, upn, dept, signin_count, success, failed, risk, security_risk, status = user_data
        
        # Skip inactive users if not requested
        if not include_inactive and signin_count == 0:
            continue
        
        last_signin = None
        if signin_count > 0:
            # Generate last signin time (within target date)
            import random
            hours = random.randint(8, 18)
            minutes = random.randint(0, 59)
            last_signin = target_date.replace(hour=hours, minute=minutes).strftime('%Y-%m-%d %H:%M:%S')
        
        record = {
            'ユーザー名': display_name,
            'ユーザープリンシパル名': upn,
            '部署': dept,
            'サインイン回数': signin_count,
            '成功回数': success,
            '失敗回数': failed,
            'リスクイベント': risk,
            '最終サインイン': last_signin or 'なし',
            'セキュリティリスク': security_risk,
            'アカウント状態': status,
            'レポート日': target_date.strftime('%Y-%m-%d')
        }
        
        report_data.append(record)
    
    return report_data

def _show_daily_summary(report_data: List[Dict[str, Any]], output: OutputFormatter):
    """Show daily report summary"""
    
    if not report_data:
        return
    
    # Calculate summary statistics
    total_users = len(report_data)
    active_users = len([r for r in report_data if r['サインイン回数'] > 0])
    high_risk_users = len([r for r in report_data if '高リスク' in r['セキュリティリスク']])
    failed_signin_users = len([r for r in report_data if r['失敗回数'] > 0])
    
    total_signins = sum(r['サインイン回数'] for r in report_data)
    total_failures = sum(r['失敗回数'] for r in report_data)
    
    click.echo("\\n📈 日次レポートサマリー")
    click.echo("=" * 30)
    click.echo(f"📊 総ユーザー数: {total_users}")
    click.echo(f"✅ アクティブユーザー: {active_users}")
    click.echo(f"⚠️ 高リスクユーザー: {high_risk_users}")
    click.echo(f"🔴 サインイン失敗ユーザー: {failed_signin_users}")
    click.echo(f"🔢 総サインイン回数: {total_signins}")
    click.echo(f"❌ 総失敗回数: {total_failures}")
    
    if total_signins > 0:
        success_rate = ((total_signins - total_failures) / total_signins) * 100
        click.echo(f"📈 成功率: {success_rate:.1f}%")
    
    click.echo()

# Command alias for PowerShell compatibility
daily_report = daily_command