# Microsoft 365 Management Tools - Sign-in Logs Command
# サインインログ・認証分析 - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--time-period', type=click.Choice(['1hour', '24hours', '7days', '30days']),
              default='24hours', help='分析期間')
@click.option('--result-status', type=click.Choice(['all', 'success', 'failure', 'interrupted']),
              default='all', help='サインイン結果フィルター')
@click.option('--risk-level', type=click.Choice(['all', 'none', 'low', 'medium', 'high']),
              default='all', help='リスクレベルフィルター')
@click.option('--user-name', help='特定ユーザーのサインインログ')
@click.option('--application', help='特定アプリケーションのサインインログ')
@click.pass_context
def signin_command(ctx, time_period, result_status, risk_level, user_name, application):
    """サインインログ・認証アクティビティ分析
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 signin
    
    Entra IDのサインインログ、認証失敗、リスク検出を分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_signin_report(
        cli_context, time_period, result_status, risk_level, user_name, application
    ))

async def execute_signin_report(context: CLIContext,
                              time_period: str = '24hours',
                              result_status: str = 'all',
                              risk_level: str = 'all',
                              user_filter: str = None,
                              app_filter: str = None):
    """Execute sign-in logs report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("サインインログを取得中...")
        
        if context.dry_run:
            report_data = _generate_sample_signin_data(
                time_period, result_status, risk_level, user_filter, app_filter
            )
        else:
            report_data = await _generate_signin_report_data(
                context, time_period, result_status, risk_level, user_filter, app_filter
            )
        
        if not report_data:
            output.output_warning("サインインログが見つかりませんでした")
            return
        
        output.output_success(f"サインインログレポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="サインインログレポート",
            filename_prefix="signin_logs_report"
        )
        
        _show_signin_summary(report_data, output, time_period)
        
    except Exception as e:
        output.output_error(f"サインインログレポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_signin_report_data(context: CLIContext,
                                     time_period: str,
                                     result_status: str,
                                     risk_level: str,
                                     user_filter: str,
                                     app_filter: str) -> List[Dict[str, Any]]:
    """Generate sign-in logs report data from Microsoft Graph APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Calculate time period
        end_time = datetime.now()
        time_deltas = {
            '1hour': timedelta(hours=1),
            '24hours': timedelta(hours=24),
            '7days': timedelta(days=7),
            '30days': timedelta(days=30)
        }
        start_time = end_time - time_deltas[time_period]
        
        # Get sign-in logs
        output.output_progress("サインインアクティビティを取得中...")
        
        signin_logs = await graph_client.get_signin_logs(
            start_date=start_time.strftime('%Y-%m-%dT%H:%M:%S'),
            end_date=end_time.strftime('%Y-%m-%dT%H:%M:%S')
        )
        
        # Get risk detection data
        risk_detections = {}
        if risk_level != 'all' and risk_level != 'none':
            risk_detections = await graph_client.get_risk_detections(
                start_date=start_time.strftime('%Y-%m-%dT%H:%M:%S')
            )
        
        report_data = []
        
        for signin in signin_logs:
            user_upn = signin.get('userPrincipalName', '')
            user_display_name = signin.get('userDisplayName', '')
            app_name = signin.get('appDisplayName', '')
            app_id = signin.get('appId', '')
            signin_datetime = signin.get('createdDateTime', '')
            
            # Filter by user if specified
            if user_filter and user_filter.lower() not in user_upn.lower() and user_filter.lower() not in user_display_name.lower():
                continue
            
            # Filter by application if specified
            if app_filter and app_filter.lower() not in app_name.lower():
                continue
            
            # Get sign-in status
            status = signin.get('status', {})
            error_code = status.get('errorCode', 0)
            failure_reason = status.get('failureReason', '')
            
            signin_result = "成功"
            if error_code != 0:
                if error_code == 50126:  # Invalid credentials
                    signin_result = "失敗 (認証情報無効)"
                elif error_code == 50076:  # MFA required
                    signin_result = "失敗 (MFA必須)"
                elif error_code == 50053:  # Account locked
                    signin_result = "失敗 (アカウントロック)"
                elif error_code == 50058:  # Interrupted
                    signin_result = "中断"
                else:
                    signin_result = f"失敗 (エラー{error_code})"
            
            # Filter by result status
            if result_status != 'all':
                if result_status == 'success' and error_code != 0:
                    continue
                elif result_status == 'failure' and error_code == 0:
                    continue
                elif result_status == 'interrupted' and error_code not in [50058, 50055]:
                    continue
            
            # Get risk information
            signin_risk_level = signin.get('riskLevelDuringSignIn', 'none')
            signin_risk_state = signin.get('riskState', 'none')
            
            # Filter by risk level
            if risk_level != 'all' and signin_risk_level != risk_level:
                continue
            
            # Get location and device information
            location = signin.get('location', {})
            city = location.get('city', '不明')
            country = location.get('countryOrRegion', '不明')
            
            device_detail = signin.get('deviceDetail', {})
            device_name = device_detail.get('displayName', '不明')
            os_name = device_detail.get('operatingSystem', '不明')
            browser = device_detail.get('browser', '不明')
            
            # Check for suspicious patterns
            is_suspicious = _detect_suspicious_patterns(signin, risk_detections)
            
            # Get conditional access status
            ca_applied = signin.get('conditionalAccessStatus', 'notApplied')
            
            record = {
                'ユーザー名': user_display_name,
                'ユーザープリンシパル名': user_upn,
                'アプリケーション': app_name,
                'サインイン時刻': signin_datetime,
                'サインイン結果': signin_result,
                'リスクレベル': signin_risk_level,
                'リスク状態': signin_risk_state,
                '場所': f"{city}, {country}",
                'デバイス名': device_name,
                'OS': os_name,
                'ブラウザ': browser,
                'IPアドレス': signin.get('ipAddress', '不明'),
                '条件付きアクセス': ca_applied,
                '疑わしい活動': 'あり' if is_suspicious else 'なし',
                'エラーコード': error_code if error_code != 0 else '',
                '失敗理由': failure_reason if failure_reason else ''
            }
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_signin_data(
            time_period, result_status, risk_level, user_filter, app_filter
        )

def _detect_suspicious_patterns(signin: Dict, risk_detections: Dict) -> bool:
    """Detect suspicious sign-in patterns"""
    
    # Check for risk detection
    if signin.get('riskLevelDuringSignIn') in ['medium', 'high']:
        return True
    
    # Check for impossible travel
    if signin.get('riskEventTypes', []):
        risk_types = signin['riskEventTypes']
        if 'impossibleTravel' in risk_types or 'anonymizedIPAddress' in risk_types:
            return True
    
    # Check for multiple failures
    if signin.get('status', {}).get('errorCode') in [50126, 50053]:  # Invalid creds or locked
        return True
    
    return False

def _generate_sample_signin_data(time_period: str, result_status: str, risk_level: str,
                               user_filter: str, app_filter: str) -> List[Dict[str, Any]]:
    """Generate sample sign-in data"""
    
    import random
    
    sample_users = [
        ('田中 太郎', 'tanaka@contoso.com'),
        ('佐藤 花子', 'sato@contoso.com'),
        ('鈴木 次郎', 'suzuki@contoso.com'),
        ('高橋 美咲', 'takahashi@contoso.com'),
        ('渡辺 健一', 'watanabe@contoso.com')
    ]
    
    sample_apps = [
        'Microsoft Teams',
        'Outlook',
        'SharePoint Online',
        'OneDrive for Business',
        'Azure portal',
        'Office 365',
        'Power BI',
        'Microsoft 365 Admin Center'
    ]
    
    locations = [
        ('東京', '日本'),
        ('大阪', '日本'),
        ('New York', 'United States'),
        ('London', 'United Kingdom'),
        ('不明', '不明')
    ]
    
    devices = [
        ('DESKTOP-ABC123', 'Windows 10', 'Chrome'),
        ('iPhone-DEF456', 'iOS', 'Safari'),
        ('LAPTOP-GHI789', 'Windows 11', 'Edge'),
        ('Android-JKL012', 'Android', 'Chrome'),
        ('MacBook-MNO345', 'macOS', 'Safari')
    ]
    
    # Calculate time range
    time_deltas = {
        '1hour': timedelta(hours=1),
        '24hours': timedelta(hours=24),
        '7days': timedelta(days=7),
        '30days': timedelta(days=30)
    }
    
    start_time = datetime.now() - time_deltas[time_period]
    
    report_data = []
    
    # Generate sample sign-in events
    num_events = min(100, int(time_deltas[time_period].total_seconds() / 3600))  # 1 event per hour max
    
    for i in range(num_events):
        # Random user and app
        user_name, user_upn = random.choice(sample_users)
        app_name = random.choice(sample_apps)
        
        # Filter by user if specified
        if user_filter and user_filter.lower() not in user_upn.lower() and user_filter.lower() not in user_name.lower():
            continue
        
        # Filter by application if specified
        if app_filter and app_filter.lower() not in app_name.lower():
            continue
        
        # Random time within period
        signin_time = start_time + timedelta(seconds=random.randint(0, int(time_deltas[time_period].total_seconds())))
        
        # Generate sign-in result
        success_rate = 0.85  # 85% success rate
        error_code = 0
        signin_result = "成功"
        failure_reason = ""
        
        if random.random() > success_rate:
            error_codes = {
                50126: "失敗 (認証情報無効)",
                50076: "失敗 (MFA必須)",
                50053: "失敗 (アカウントロック)",
                50058: "中断"
            }
            error_code = random.choice(list(error_codes.keys()))
            signin_result = error_codes[error_code]
            failure_reason = signin_result.split(' ')[1] if ' ' in signin_result else ""
        
        # Filter by result status
        if result_status != 'all':
            if result_status == 'success' and error_code != 0:
                continue
            elif result_status == 'failure' and error_code == 0:
                continue
            elif result_status == 'interrupted' and error_code != 50058:
                continue
        
        # Generate risk information
        risk_levels = ['none', 'low', 'medium', 'high']
        weights = [0.7, 0.2, 0.08, 0.02]  # Most are none/low risk
        signin_risk_level = random.choices(risk_levels, weights=weights)[0]
        
        # Filter by risk level
        if risk_level != 'all' and signin_risk_level != risk_level:
            continue
        
        signin_risk_state = 'confirmed' if signin_risk_level in ['medium', 'high'] else 'none'
        
        # Random location and device
        city, country = random.choice(locations)
        device_name, os_name, browser = random.choice(devices)
        
        # Generate IP address
        ip_address = f"{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}"
        
        # Conditional access status
        ca_statuses = ['success', 'failure', 'notApplied']
        ca_status = random.choice(ca_statuses)
        
        # Suspicious activity detection
        is_suspicious = signin_risk_level in ['medium', 'high'] or error_code in [50126, 50053]
        
        record = {
            'ユーザー名': user_name,
            'ユーザープリンシパル名': user_upn,
            'アプリケーション': app_name,
            'サインイン時刻': signin_time.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'サインイン結果': signin_result,
            'リスクレベル': signin_risk_level,
            'リスク状態': signin_risk_state,
            '場所': f"{city}, {country}",
            'デバイス名': device_name,
            'OS': os_name,
            'ブラウザ': browser,
            'IPアドレス': ip_address,
            '条件付きアクセス': ca_status,
            '疑わしい活動': 'あり' if is_suspicious else 'なし',
            'エラーコード': error_code if error_code != 0 else '',
            '失敗理由': failure_reason if failure_reason else ''
        }
        
        report_data.append(record)
    
    return report_data

def _show_signin_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, time_period: str):
    """Show sign-in logs summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_signins = len(report_data)
    successful_signins = len([r for r in report_data if r['サインイン結果'] == '成功'])
    failed_signins = total_signins - successful_signins
    
    # Risk analysis
    high_risk = len([r for r in report_data if r['リスクレベル'] == 'high'])
    medium_risk = len([r for r in report_data if r['リスクレベル'] == 'medium'])
    low_risk = len([r for r in report_data if r['リスクレベル'] == 'low'])
    no_risk = len([r for r in report_data if r['リスクレベル'] == 'none'])
    
    # Suspicious activity analysis
    suspicious_signins = len([r for r in report_data if r['疑わしい活動'] == 'あり'])
    
    # Application breakdown
    app_stats = {}
    for record in report_data:
        app = record.get('アプリケーション', '不明')
        app_stats[app] = app_stats.get(app, 0) + 1
    
    # Location analysis
    location_stats = {}
    for record in report_data:
        location = record.get('場所', '不明')
        location_stats[location] = location_stats.get(location, 0) + 1
    
    # Error code analysis
    error_stats = {}
    for record in report_data:
        error_code = record.get('エラーコード', '')
        if error_code:
            error_stats[error_code] = error_stats.get(error_code, 0) + 1
    
    success_rate = (successful_signins / total_signins) * 100 if total_signins > 0 else 0
    risk_rate = ((high_risk + medium_risk) / total_signins) * 100 if total_signins > 0 else 0
    
    click.echo("\n🔐 サインインログサマリー")
    click.echo("=" * 35)
    click.echo(f"📅 分析期間: {time_period}")
    click.echo(f"📋 総サインイン回数: {total_signins}")
    click.echo(f"✅ 成功: {successful_signins} ({success_rate:.1f}%)")
    click.echo(f"❌ 失敗: {failed_signins}")
    click.echo(f"⚠️ 疑わしい活動: {suspicious_signins}")
    
    # Risk level breakdown
    click.echo("\n🚨 リスクレベル分析:")
    click.echo(f"  🔴 高リスク: {high_risk}")
    click.echo(f"  🟡 中リスク: {medium_risk}")
    click.echo(f"  🔵 低リスク: {low_risk}")
    click.echo(f"  ✅ リスクなし: {no_risk}")
    click.echo(f"  📊 リスク率: {risk_rate:.1f}%")
    
    # Top applications
    if app_stats:
        click.echo("\n📱 利用頻度上位アプリケーション:")
        sorted_apps = sorted(app_stats.items(), key=lambda x: x[1], reverse=True)
        for app, count in sorted_apps[:5]:  # Top 5
            percentage = (count / total_signins) * 100
            click.echo(f"  📊 {app}: {count} ({percentage:.1f}%)")
    
    # Top locations
    if location_stats:
        click.echo("\n🌍 サインイン場所:")
        sorted_locations = sorted(location_stats.items(), key=lambda x: x[1], reverse=True)
        for location, count in sorted_locations[:5]:  # Top 5
            percentage = (count / total_signins) * 100
            click.echo(f"  🗺️ {location}: {count} ({percentage:.1f}%)")
    
    # Error analysis
    if error_stats:
        click.echo("\n❌ エラー分析:")
        error_names = {
            50126: '認証情報無効',
            50076: 'MFA必須',
            50053: 'アカウントロック',
            50058: '中断'
        }
        for error_code, count in error_stats.items():
            error_name = error_names.get(error_code, f'エラー{error_code}')
            percentage = (count / failed_signins) * 100 if failed_signins > 0 else 0
            click.echo(f"  🔴 {error_name}: {count} ({percentage:.1f}%)")
    
    # Security assessment
    click.echo("\n🛡️ セキュリティ評価:")
    if success_rate >= 95 and risk_rate < 5:
        click.echo("  🎉 優秀: サインインセキュリティは良好です")
    elif success_rate >= 85 and risk_rate < 10:
        click.echo("  🔶 良好: 軽微なセキュリティ問題があります")
    elif success_rate >= 70 and risk_rate < 20:
        click.echo("  ⚠️ 注意: セキュリティ強化が必要です")
    else:
        click.echo("  🚨 警告: 深刻なセキュリティ問題があります")
    
    # Recommendations
    click.echo("\n💡 セキュリティ強化推奨事項:")
    if failed_signins > total_signins * 0.15:  # More than 15% failure rate
        click.echo("  • サインイン失敗率が高いです。ユーザー教育を強化してください")
    if high_risk > 0:
        click.echo(f"  • {high_risk} 件の高リスクサインインの調査が必要")
    if suspicious_signins > 0:
        click.echo(f"  • {suspicious_signins} 件の疑わしい活動の詳細調査を推奨")
    
    # Error-specific recommendations
    if 50126 in error_stats:  # Invalid credentials
        click.echo("  • パスワード管理とセキュリティ教育の強化")
    if 50053 in error_stats:  # Account locked
        click.echo("  • アカウントロックポリシーの見直し")
    if 50076 in error_stats:  # MFA required
        click.echo("  • MFA設定支援の提供")
    
    if successful_signins == total_signins and suspicious_signins == 0:
        click.echo("  • サインインセキュリティは良好です。継続的な監視を維持してください")
    
    click.echo()

# Command alias for PowerShell compatibility
signin_logs = signin_command