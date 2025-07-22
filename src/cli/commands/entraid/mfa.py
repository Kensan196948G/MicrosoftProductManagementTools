# Microsoft 365 Management Tools - MFA Status Command
# MFA状況・多要素認証分析 - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--mfa-status', type=click.Choice(['all', 'enabled', 'disabled', 'enforced']),
              default='all', help='MFAステータスフィルター')
@click.option('--include-methods', is_flag=True, help='認証方法詳細を含める')
@click.option('--department', help='特定部署のみ対象')
@click.option('--risk-users-only', is_flag=True, help='高リスクユーザーのみ')
@click.pass_context
def mfa_command(ctx, mfa_status, include_methods, department, risk_users_only):
    """MFA状況・多要素認証設定分析
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 mfa
    
    Entra IDのMFA設定状況、認証方法、リスク評価を分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_mfa_report(
        cli_context, mfa_status, include_methods, department, risk_users_only
    ))

async def execute_mfa_report(context: CLIContext,
                           mfa_status: str = 'all',
                           include_methods: bool = False,
                           department_filter: str = None,
                           risk_users_only: bool = False):
    """Execute MFA status report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("MFA設定状況を取得中...")
        
        if context.dry_run:
            report_data = _generate_sample_mfa_data(
                mfa_status, include_methods, department_filter, risk_users_only
            )
        else:
            report_data = await _generate_mfa_report_data(
                context, mfa_status, include_methods, department_filter, risk_users_only
            )
        
        if not report_data:
            output.output_warning("MFAデータが見つかりませんでした")
            return
        
        output.output_success(f"MFA状況レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="MFA状況レポート",
            filename_prefix="mfa_status_report"
        )
        
        _show_mfa_summary(report_data, output, mfa_status)
        
    except Exception as e:
        output.output_error(f"MFAレポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_mfa_report_data(context: CLIContext,
                                  mfa_status: str,
                                  include_methods: bool,
                                  department_filter: str,
                                  risk_users_only: bool) -> List[Dict[str, Any]]:
    """Generate MFA report data from Microsoft Graph APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get users with MFA status
        output.output_progress("ユーザーMFA設定を取得中...")
        
        # Get users with MFA information
        users_mfa_data = await graph_client.get_users_with_mfa_status()
        
        # Get authentication methods if requested
        auth_methods_data = {}
        if include_methods:
            output.output_progress("認証方法詳細を取得中...")
            auth_methods_data = await graph_client.get_authentication_methods()
        
        # Get risky users for risk assessment
        risky_users = set()
        if risk_users_only:
            risky_users_data = await graph_client.get_risky_users()
            risky_users = {user.get('userPrincipalName') for user in risky_users_data}
        
        report_data = []
        
        for user in users_mfa_data:
            upn = user.get('userPrincipalName', '')
            display_name = user.get('displayName', '')
            dept = user.get('department', '未設定')
            is_enabled = user.get('accountEnabled', True)
            
            # Filter by department if specified
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            # Filter by risk users if specified
            if risk_users_only and upn not in risky_users:
                continue
            
            # Get MFA status
            mfa_state = user.get('mfaState', 'Disabled')
            mfa_enabled = mfa_state in ['Enabled', 'Enforced']
            
            # Filter by MFA status
            if mfa_status != 'all':
                if mfa_status == 'enabled' and not mfa_enabled:
                    continue
                elif mfa_status == 'disabled' and mfa_enabled:
                    continue
                elif mfa_status == 'enforced' and mfa_state != 'Enforced':
                    continue
            
            # Get authentication methods
            methods = []
            if include_methods and upn in auth_methods_data:
                user_methods = auth_methods_data[upn]
                methods = [method.get('displayName', '') for method in user_methods]
            
            # Assess risk level
            risk_level = _assess_mfa_risk(mfa_state, methods, upn in risky_users, is_enabled)
            
            # Get MFA registration date
            mfa_registered = user.get('mfaRegisteredDateTime')
            
            record = {
                'ユーザー名': display_name,
                'ユーザープリンシパル名': upn,
                '部署': dept,
                'MFA状態': mfa_state,
                'MFA有効': 'はい' if mfa_enabled else 'いいえ',
                'リスクレベル': risk_level,
                '認証方法数': len(methods) if methods else 0,
                'アカウント状態': 'アクティブ' if is_enabled else '無効',
                'MFA登録日': mfa_registered or '未登録'
            }
            
            if include_methods:
                record['認証方法'] = ', '.join(methods) if methods else 'なし'
                record['SMS認証'] = 'あり' if any('SMS' in method for method in methods) else 'なし'
                record['アプリ認証'] = 'あり' if any('Authenticator' in method for method in methods) else 'なし'
                record['電話認証'] = 'あり' if any('Phone' in method for method in methods) else 'なし'
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_mfa_data(
            mfa_status, include_methods, department_filter, risk_users_only
        )

def _assess_mfa_risk(mfa_state: str, methods: List[str], is_risky_user: bool, is_enabled: bool) -> str:
    """Assess risk level based on MFA configuration"""
    
    if not is_enabled:
        return "低"  # Disabled accounts are low risk
    
    if is_risky_user and mfa_state != 'Enforced':
        return "🚨重大"
    
    if mfa_state == 'Disabled':
        return "🔴高"
    elif mfa_state == 'Enabled' and len(methods) < 2:
        return "🟡中"
    elif mfa_state == 'Enforced':
        return "✅低"
    else:
        return "中"

def _generate_sample_mfa_data(mfa_status: str, include_methods: bool,
                            department_filter: str, risk_users_only: bool) -> List[Dict[str, Any]]:
    """Generate sample MFA data"""
    
    sample_users = [
        {
            'name': '田中 太郎', 'upn': 'tanaka@contoso.com', 'dept': 'IT部',
            'mfa_state': 'Enforced', 'methods': ['SMS', 'Microsoft Authenticator'], 'risky': False
        },
        {
            'name': '佐藤 花子', 'upn': 'sato@contoso.com', 'dept': '営業部',
            'mfa_state': 'Enabled', 'methods': ['SMS'], 'risky': False
        },
        {
            'name': '鈴木 次郎', 'upn': 'suzuki@contoso.com', 'dept': '人事部',
            'mfa_state': 'Disabled', 'methods': [], 'risky': True
        },
        {
            'name': '高橋 美咲', 'upn': 'takahashi@contoso.com', 'dept': '経理部',
            'mfa_state': 'Enabled', 'methods': ['Microsoft Authenticator', 'Phone'], 'risky': False
        },
        {
            'name': '渡辺 健一', 'upn': 'watanabe@contoso.com', 'dept': 'IT部',
            'mfa_state': 'Enforced', 'methods': ['SMS', 'Microsoft Authenticator', 'FIDO2'], 'risky': False
        },
        {
            'name': '山田 綾子', 'upn': 'yamada@contoso.com', 'dept': '営業部',
            'mfa_state': 'Disabled', 'methods': [], 'risky': True
        },
        {
            'name': '中村 大輔', 'upn': 'nakamura@contoso.com', 'dept': '開発部',
            'mfa_state': 'Enabled', 'methods': ['Microsoft Authenticator'], 'risky': False
        },
        {
            'name': '小林 真由美', 'upn': 'kobayashi@contoso.com', 'dept': 'マーケティング部',
            'mfa_state': 'Enabled', 'methods': ['SMS', 'Microsoft Authenticator'], 'risky': False
        }
    ]
    
    report_data = []
    
    for user_info in sample_users:
        # Apply filters
        if department_filter and user_info['dept'].lower() != department_filter.lower():
            continue
        
        if risk_users_only and not user_info['risky']:
            continue
        
        user_mfa_state = user_info['mfa_state']
        mfa_enabled = user_mfa_state in ['Enabled', 'Enforced']
        
        # Filter by MFA status
        if mfa_status != 'all':
            if mfa_status == 'enabled' and not mfa_enabled:
                continue
            elif mfa_status == 'disabled' and mfa_enabled:
                continue
            elif mfa_status == 'enforced' and user_mfa_state != 'Enforced':
                continue
        
        methods = user_info['methods']
        risk_level = _assess_mfa_risk(user_mfa_state, methods, user_info['risky'], True)
        
        # Generate MFA registration date
        if mfa_enabled:
            import random
            days_ago = random.randint(30, 365)
            mfa_registered = (datetime.now() - timedelta(days=days_ago)).strftime('%Y-%m-%dT%H:%M:%SZ')
        else:
            mfa_registered = '未登録'
        
        record = {
            'ユーザー名': user_info['name'],
            'ユーザープリンシパル名': user_info['upn'],
            '部署': user_info['dept'],
            'MFA状態': user_mfa_state,
            'MFA有効': 'はい' if mfa_enabled else 'いいえ',
            'リスクレベル': risk_level,
            '認証方法数': len(methods),
            'アカウント状態': 'アクティブ',
            'MFA登録日': mfa_registered
        }
        
        if include_methods:
            record['認証方法'] = ', '.join(methods) if methods else 'なし'
            record['SMS認証'] = 'あり' if 'SMS' in methods else 'なし'
            record['アプリ認証'] = 'あり' if any('Authenticator' in method for method in methods) else 'なし'
            record['電話認証'] = 'あり' if 'Phone' in methods else 'なし'
        
        report_data.append(record)
    
    return report_data

def _show_mfa_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, mfa_status: str):
    """Show MFA report summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_users = len(report_data)
    mfa_enabled_users = len([r for r in report_data if r['MFA有効'] == 'はい'])
    mfa_disabled_users = len([r for r in report_data if r['MFA有効'] == 'いいえ'])
    enforced_users = len([r for r in report_data if r['MFA状態'] == 'Enforced'])
    
    # Risk level analysis
    critical_risk = len([r for r in report_data if '🚨' in r.get('リスクレベル', '')])
    high_risk = len([r for r in report_data if '🔴' in r.get('リスクレベル', '')])
    medium_risk = len([r for r in report_data if '🟡' in r.get('リスクレベル', '')])
    low_risk = len([r for r in report_data if '✅' in r.get('リスクレベル', '') or r.get('リスクレベル') == '低'])
    
    # Department breakdown
    dept_stats = {}
    for record in report_data:
        dept = record.get('部署', '未設定')
        if dept not in dept_stats:
            dept_stats[dept] = {'enabled': 0, 'disabled': 0}
        
        if record['MFA有効'] == 'はい':
            dept_stats[dept]['enabled'] += 1
        else:
            dept_stats[dept]['disabled'] += 1
    
    # Authentication method analysis (if available)
    method_stats = {}
    sms_users = 0
    app_users = 0
    phone_users = 0
    
    for record in report_data:
        if 'SMS認証' in record:
            if record['SMS認証'] == 'あり':
                sms_users += 1
        if 'アプリ認証' in record:
            if record['アプリ認証'] == 'あり':
                app_users += 1
        if '電話認証' in record:
            if record['電話認証'] == 'あり':
                phone_users += 1
    
    mfa_adoption_rate = (mfa_enabled_users / total_users) * 100 if total_users > 0 else 0
    enforcement_rate = (enforced_users / total_users) * 100 if total_users > 0 else 0
    
    click.echo("\n🔐 MFA状況サマリー")
    click.echo("=" * 30)
    click.echo(f"🎯 フィルター: {mfa_status.upper()}")
    click.echo(f"📋 総ユーザー数: {total_users}")
    click.echo(f"✅ MFA有効: {mfa_enabled_users} ({mfa_adoption_rate:.1f}%)")
    click.echo(f"❌ MFA無効: {mfa_disabled_users}")
    click.echo(f"🔒 MFA強制: {enforced_users} ({enforcement_rate:.1f}%)")
    
    # Risk level breakdown
    click.echo("\n🚨 リスクレベル分析:")
    click.echo(f"  🚨 重大リスク: {critical_risk}")
    click.echo(f"  🔴 高リスク: {high_risk}")
    click.echo(f"  🟡 中リスク: {medium_risk}")
    click.echo(f"  ✅ 低リスク: {low_risk}")
    
    # Department breakdown
    if dept_stats:
        click.echo("\n🏢 部署別MFA状況:")
        sorted_depts = sorted(dept_stats.items(), key=lambda x: x[1]['enabled'] + x[1]['disabled'], reverse=True)
        for dept, stats in sorted_depts[:5]:  # Top 5 departments
            total_dept = stats['enabled'] + stats['disabled']
            enabled_rate = (stats['enabled'] / total_dept) * 100 if total_dept > 0 else 0
            click.echo(f"  📊 {dept}: {stats['enabled']}有効/{stats['disabled']}無効 ({enabled_rate:.1f}%)")
    
    # Authentication method analysis
    if sms_users > 0 or app_users > 0 or phone_users > 0:
        click.echo("\n📱 認証方法利用状況:")
        if sms_users > 0:
            click.echo(f"  📱 SMS認証: {sms_users}人 ({sms_users/total_users*100:.1f}%)")
        if app_users > 0:
            click.echo(f"  📲 アプリ認証: {app_users}人 ({app_users/total_users*100:.1f}%)")
        if phone_users > 0:
            click.echo(f"  📞 電話認証: {phone_users}人 ({phone_users/total_users*100:.1f}%)")
    
    # Security assessment
    click.echo("\n🛡️ セキュリティ評価:")
    if mfa_adoption_rate >= 95:
        click.echo("  🎉 優秀: MFA導入率が非常に高いです")
    elif mfa_adoption_rate >= 80:
        click.echo("  🔶 良好: MFA導入率は良好です")
    elif mfa_adoption_rate >= 50:
        click.echo("  ⚠️ 注意: MFA導入の促進が必要です")
    else:
        click.echo("  🚨 警告: MFA導入率が低く、セキュリティリスクがあります")
    
    # Recommendations
    click.echo("\n💡 セキュリティ強化推奨事項:")
    if critical_risk > 0:
        click.echo(f"  • {critical_risk} 人の重大リスクユーザーへの即座のMFA強制")
    if high_risk > 0:
        click.echo(f"  • {high_risk} 人の高リスクユーザーへのMFA有効化")
    if mfa_disabled_users > 0:
        click.echo(f"  • {mfa_disabled_users} 人のMFA未設定ユーザーへの導入支援")
    if enforcement_rate < 50:
        click.echo("  • 重要な部署・役職へのMFA強制適用を検討")
    
    # Method-specific recommendations
    if sms_users > app_users and sms_users > 0:
        click.echo("  • SMS依存の軽減とアプリベース認証の推進")
    if app_users + phone_users < mfa_enabled_users:
        click.echo("  • より安全な認証方法（アプリ・電話）の採用促進")
    
    click.echo()

# Command alias for PowerShell compatibility
mfa_status = mfa_command