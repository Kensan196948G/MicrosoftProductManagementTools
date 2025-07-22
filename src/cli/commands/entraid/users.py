# Microsoft 365 Management Tools - Entra ID Users Command
# Entra IDユーザー一覧・詳細管理 - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--include-disabled', is_flag=True, help='無効化されたユーザーを含める')
@click.option('--include-guest', is_flag=True, help='ゲストユーザーを含める')
@click.option('--department', help='特定部署のみ対象')
@click.option('--filter-by-license', help='特定ライセンス所有者のみ')
@click.option('--last-signin-days', type=int, help='指定日数以内にサインインしたユーザーのみ')
@click.pass_context
def users_command(ctx, include_disabled, include_guest, department, filter_by_license, last_signin_days):
    """Entra IDユーザー一覧・詳細情報取得
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 users
    
    Entra IDのユーザー情報、ライセンス、部署、最終ログイン情報を取得します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_users_report(
        cli_context, include_disabled, include_guest, department, filter_by_license, last_signin_days
    ))

async def execute_users_report(context: CLIContext,
                             include_disabled: bool = False,
                             include_guest: bool = False,
                             department_filter: str = None,
                             license_filter: str = None,
                             signin_days: int = None):
    """Execute Entra ID users report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("Entra IDユーザー情報を取得中...")
        
        if context.dry_run:
            report_data = _generate_sample_users_data(
                include_disabled, include_guest, department_filter, license_filter, signin_days
            )
        else:
            report_data = await _generate_users_report_data(
                context, include_disabled, include_guest, department_filter, license_filter, signin_days
            )
        
        if not report_data:
            output.output_warning("ユーザーデータが見つかりませんでした")
            return
        
        output.output_success(f"Entra IDユーザーレポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="Entra IDユーザーレポート",
            filename_prefix="entraid_users_report"
        )
        
        _show_users_summary(report_data, output, include_disabled, include_guest)
        
    except Exception as e:
        output.output_error(f"ユーザーレポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_users_report_data(context: CLIContext,
                                    include_disabled: bool,
                                    include_guest: bool,
                                    department_filter: str,
                                    license_filter: str,
                                    signin_days: int) -> List[Dict[str, Any]]:
    """Generate users report data from Microsoft Graph APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get users data
        output.output_progress("ユーザー基本情報を取得中...")
        
        # Get users with detailed information
        users_data = await graph_client.get_users(
            include_disabled=include_disabled,
            include_guest=include_guest
        )
        
        # Get signin activity data
        if signin_days:
            signin_cutoff = datetime.now() - timedelta(days=signin_days)
            signin_activity = await graph_client.get_signin_activity(
                start_date=signin_cutoff.strftime('%Y-%m-%d')
            )
        else:
            signin_activity = {}
        
        # Get license information
        output.output_progress("ライセンス情報を取得中...")
        license_data = await graph_client.get_user_licenses()
        
        report_data = []
        
        for user in users_data:
            upn = user.get('userPrincipalName', '')
            display_name = user.get('displayName', '')
            dept = user.get('department', '未設定')
            job_title = user.get('jobTitle', '未設定')
            is_enabled = user.get('accountEnabled', True)
            user_type = user.get('userType', 'Member')
            created_date = user.get('createdDateTime', '')
            last_signin = user.get('lastSignInDateTime')
            
            # Filter by department if specified
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            # Filter by signin days if specified
            if signin_days and last_signin:
                try:
                    signin_date = datetime.fromisoformat(last_signin.replace('Z', '+00:00'))
                    if signin_date < signin_cutoff:
                        continue
                except:
                    continue
            
            # Get user licenses
            user_licenses = license_data.get(upn, [])
            license_names = [lic.get('skuPartNumber', '') for lic in user_licenses]
            primary_license = license_names[0] if license_names else '未割り当て'
            
            # Filter by license if specified
            if license_filter and license_filter not in ' '.join(license_names):
                continue
            
            # Determine user status
            user_status = "アクティブ"
            if not is_enabled:
                user_status = "無効"
            elif user_type == 'Guest':
                user_status = "ゲスト"
            elif not last_signin:
                user_status = "未ログイン"
            
            # Calculate days since last signin
            days_since_signin = "なし"
            if last_signin:
                try:
                    signin_date = datetime.fromisoformat(last_signin.replace('Z', '+00:00'))
                    days_diff = (datetime.now() - signin_date.replace(tzinfo=None)).days
                    days_since_signin = f"{days_diff}日前"
                except:
                    days_since_signin = "不明"
            
            record = {
                'ユーザー名': display_name,
                'ユーザープリンシパル名': upn,
                '部署': dept,
                '役職': job_title,
                'ユーザータイプ': user_type,
                'アカウント状態': user_status,
                '主ライセンス': primary_license,
                '全ライセンス': ', '.join(license_names) if license_names else '未割り当て',
                '最終サインイン': last_signin or 'なし',
                '最終サインイン経過日数': days_since_signin,
                'アカウント作成日': created_date,
                'マネージャー': user.get('manager', {}).get('displayName', '未設定') if user.get('manager') else '未設定'
            }
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_users_data(
            include_disabled, include_guest, department_filter, license_filter, signin_days
        )

def _generate_sample_users_data(include_disabled: bool, include_guest: bool,
                              department_filter: str, license_filter: str, signin_days: int) -> List[Dict[str, Any]]:
    """Generate sample users data"""
    
    import random
    
    sample_users = [
        {
            'name': '田中 太郎', 'upn': 'tanaka@contoso.com', 'dept': 'IT部', 'job': 'システム管理者',
            'type': 'Member', 'enabled': True, 'license': 'ENTERPRISEPACK', 'signin_days_ago': 1
        },
        {
            'name': '佐藤 花子', 'upn': 'sato@contoso.com', 'dept': '営業部', 'job': '営業部長',
            'type': 'Member', 'enabled': True, 'license': 'ENTERPRISEPACK', 'signin_days_ago': 2
        },
        {
            'name': '鈴木 次郎', 'upn': 'suzuki@contoso.com', 'dept': '人事部', 'job': '人事担当',
            'type': 'Member', 'enabled': False, 'license': 'ENTERPRISEPACK', 'signin_days_ago': 45
        },
        {
            'name': 'John Smith', 'upn': 'john@partner.com', 'dept': '外部', 'job': 'コンサルタント',
            'type': 'Guest', 'enabled': True, 'license': '', 'signin_days_ago': 7
        },
        {
            'name': '高橋 美咲', 'upn': 'takahashi@contoso.com', 'dept': '経理部', 'job': '経理担当',
            'type': 'Member', 'enabled': True, 'license': 'OFFICE365_BUSINESS', 'signin_days_ago': 3
        },
        {
            'name': '渡辺 健一', 'upn': 'watanabe@contoso.com', 'dept': 'IT部', 'job': '開発者',
            'type': 'Member', 'enabled': True, 'license': 'ENTERPRISEPACK', 'signin_days_ago': 1
        },
        {
            'name': '山田 綾子', 'upn': 'yamada@contoso.com', 'dept': '営業部', 'job': '営業担当',
            'type': 'Member', 'enabled': True, 'license': 'ENTERPRISEPACK', 'signin_days_ago': 2
        },
        {
            'name': '中村 大輔', 'upn': 'nakamura@contoso.com', 'dept': '開発部', 'job': 'エンジニア',
            'type': 'Member', 'enabled': True, 'license': 'ENTERPRISEPACK', 'signin_days_ago': 1
        }
    ]
    
    managers = ['田中 太郎', '佐藤 花子', '渡辺 健一']
    
    report_data = []
    
    for user_info in sample_users:
        # Apply filters
        if not include_disabled and not user_info['enabled']:
            continue
        
        if not include_guest and user_info['type'] == 'Guest':
            continue
            
        if department_filter and user_info['dept'].lower() != department_filter.lower():
            continue
            
        if license_filter and license_filter not in user_info['license']:
            continue
            
        if signin_days and user_info['signin_days_ago'] > signin_days:
            continue
        
        # Generate signin time
        signin_time = None
        days_since_signin = "なし"
        if user_info['signin_days_ago'] and user_info['signin_days_ago'] < 365:
            signin_date = datetime.now() - timedelta(days=user_info['signin_days_ago'])
            signin_time = signin_date.strftime('%Y-%m-%dT%H:%M:%SZ')
            days_since_signin = f"{user_info['signin_days_ago']}日前"
        
        # Determine user status
        user_status = "アクティブ"
        if not user_info['enabled']:
            user_status = "無効"
        elif user_info['type'] == 'Guest':
            user_status = "ゲスト"
        elif not signin_time:
            user_status = "未ログイン"
        
        # Generate creation date
        created_date = (datetime.now() - timedelta(days=random.randint(30, 365))).strftime('%Y-%m-%dT%H:%M:%SZ')
        
        # Select manager
        manager = random.choice(managers) if user_info['name'] not in managers else '未設定'
        
        record = {
            'ユーザー名': user_info['name'],
            'ユーザープリンシパル名': user_info['upn'],
            '部署': user_info['dept'],
            '役職': user_info['job'],
            'ユーザータイプ': user_info['type'],
            'アカウント状態': user_status,
            '主ライセンス': user_info['license'] or '未割り当て',
            '全ライセンス': user_info['license'] or '未割り当て',
            '最終サインイン': signin_time or 'なし',
            '最終サインイン経過日数': days_since_signin,
            'アカウント作成日': created_date,
            'マネージャー': manager
        }
        
        report_data.append(record)
    
    return report_data

def _show_users_summary(report_data: List[Dict[str, Any]], output: OutputFormatter,
                       include_disabled: bool, include_guest: bool):
    """Show users report summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_users = len(report_data)
    active_users = len([r for r in report_data if r['アカウント状態'] == 'アクティブ'])
    disabled_users = len([r for r in report_data if r['アカウント状態'] == '無効'])
    guest_users = len([r for r in report_data if r['アカウント状態'] == 'ゲスト'])
    no_signin_users = len([r for r in report_data if r['アカウント状態'] == '未ログイン'])
    
    # Department breakdown
    dept_stats = {}
    for record in report_data:
        dept = record.get('部署', '未設定')
        dept_stats[dept] = dept_stats.get(dept, 0) + 1
    
    # License breakdown
    license_stats = {}
    for record in report_data:
        license = record.get('主ライセンス', '未割り当て')
        license_stats[license] = license_stats.get(license, 0) + 1
    
    # Recent signin analysis
    recent_signin = len([r for r in report_data 
                        if r.get('最終サインイン経過日数', 'なし') != 'なし' 
                        and '日前' in r.get('最終サインイン経過日数', '')])
    
    activation_rate = (active_users / total_users) * 100 if total_users > 0 else 0
    
    click.echo("\n👥 Entra IDユーザーサマリー")
    click.echo("=" * 35)
    click.echo(f"📋 総ユーザー数: {total_users}")
    click.echo(f"✅ アクティブユーザー: {active_users} ({activation_rate:.1f}%)")
    click.echo(f"❌ 無効化ユーザー: {disabled_users}")
    click.echo(f"👤 ゲストユーザー: {guest_users}")
    click.echo(f"⏭️ 未ログインユーザー: {no_signin_users}")
    click.echo(f"🔄 最近のサインイン: {recent_signin}")
    
    # Department statistics
    if dept_stats:
        click.echo("\n🏢 部署別ユーザー数:")
        sorted_depts = sorted(dept_stats.items(), key=lambda x: x[1], reverse=True)
        for dept, count in sorted_depts[:5]:  # Top 5 departments
            percentage = (count / total_users) * 100
            click.echo(f"  📊 {dept}: {count} ({percentage:.1f}%)")
    
    # License statistics
    if license_stats:
        click.echo("\n📄 ライセンス別分布:")
        sorted_licenses = sorted(license_stats.items(), key=lambda x: x[1], reverse=True)
        for license, count in sorted_licenses[:5]:  # Top 5 licenses
            percentage = (count / total_users) * 100
            click.echo(f"  📦 {license}: {count} ({percentage:.1f}%)")
    
    # User health assessment
    click.echo("\n📊 ユーザーアカウント健全性:")
    if activation_rate >= 90:
        click.echo("  🎉 優秀: ユーザーアカウント管理は良好です")
    elif activation_rate >= 75:
        click.echo("  🔶 良好: 軽微な非アクティブアカウントがあります")
    elif activation_rate >= 50:
        click.echo("  ⚠️ 注意: 非アクティブアカウントの整理が必要です")
    else:
        click.echo("  🚨 警告: 多くの非アクティブアカウントがあります")
    
    # Recommendations
    click.echo("\n💡 管理推奨事項:")
    if disabled_users > 0:
        click.echo(f"  • {disabled_users} 個の無効アカウントの削除を検討")
    if no_signin_users > 0:
        click.echo(f"  • {no_signin_users} 人の未ログインユーザーの状況確認")
    if guest_users > total_users * 0.1:
        click.echo("  • ゲストアカウントの定期的な見直しを推奨")
    
    unassigned_licenses = license_stats.get('未割り当て', 0)
    if unassigned_licenses > 0:
        click.echo(f"  • {unassigned_licenses} 人にライセンスが未割り当て")
    
    click.echo()

# Command alias for PowerShell compatibility
entraid_users = users_command