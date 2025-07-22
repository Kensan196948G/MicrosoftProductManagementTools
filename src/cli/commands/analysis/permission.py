# Microsoft 365 Management Tools - Permission Analysis Command
# 権限監査・アクセス制御分析レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--permission-type', type=click.Choice(['all', 'admin', 'group', 'sharing', 'application']),
              default='all', help='権限タイプ')
@click.option('--risk-level', type=click.Choice(['all', 'critical', 'high', 'medium', 'low']),
              default='all', help='リスクレベル')
@click.option('--include-inactive-users', is_flag=True, help='非アクティブユーザーを含める')
@click.option('--department', help='特定部署のみ対象')
@click.pass_context
def permission_command(ctx, permission_type, risk_level, include_inactive_users, department):
    """権限監査・アクセス制御分析レポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 permission
    
    Microsoft 365の権限設定、管理者権限、グループメンバーシップを監査します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_permission_analysis(
        cli_context, permission_type, risk_level, include_inactive_users, department
    ))

async def execute_permission_analysis(context: CLIContext,
                                    permission_type: str = 'all',
                                    risk_level: str = 'all',
                                    include_inactive_users: bool = False,
                                    department_filter: str = None):
    """Execute permission analysis report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("権限分析レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_permission_data(
                permission_type, risk_level, include_inactive_users, department_filter
            )
        else:
            report_data = await _generate_permission_analysis_data(
                context, permission_type, risk_level, include_inactive_users, department_filter
            )
        
        if not report_data:
            output.output_warning("権限データが見つかりませんでした")
            return
        
        output.output_success(f"権限分析レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="権限分析レポート",
            filename_prefix="permission_analysis_report"
        )
        
        _show_permission_summary(report_data, output, permission_type, risk_level)
        
    except Exception as e:
        output.output_error(f"権限分析レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_permission_analysis_data(context: CLIContext,
                                           permission_type: str,
                                           risk_level: str,
                                           include_inactive_users: bool,
                                           department_filter: str) -> List[Dict[str, Any]]:
    """Generate permission analysis data from Microsoft 365 APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get permission data
        output.output_progress("権限情報を取得中...")
        
        # Get users with role assignments
        users_with_roles = await graph_client.get_users_with_directory_roles()
        
        # Get group memberships
        group_memberships = await graph_client.get_group_memberships()
        
        # Get application permissions
        app_permissions = await graph_client.get_application_permissions()
        
        # Get sharing permissions
        sharing_permissions = await graph_client.get_sharing_permissions()
        
        report_data = []
        
        # Process admin permissions
        if permission_type in ['all', 'admin']:
            for user_role in users_with_roles:
                user = user_role.get('user', {})
                roles = user_role.get('roles', [])
                
                upn = user.get('userPrincipalName', '')
                display_name = user.get('displayName', '')
                dept = user.get('department', '不明')
                is_active = user.get('accountEnabled', True)
                last_signin = user.get('lastSignInDateTime')
                
                # Filter by department
                if department_filter and dept.lower() != department_filter.lower():
                    continue
                
                # Filter inactive users
                if not include_inactive_users and not is_active:
                    continue
                
                for role in roles:
                    role_name = role.get('displayName', '不明')
                    role_type = role.get('roleType', 'DirectoryRole')
                    
                    # Assess risk level
                    assigned_risk = _assess_permission_risk(role_name, role_type, is_active, last_signin)
                    
                    # Filter by risk level
                    if risk_level != 'all' and assigned_risk.lower() != risk_level:
                        continue
                    
                    record = {
                        'ユーザー名': display_name,
                        'ユーザープリンシパル名': upn,
                        '部署': dept,
                        '権限タイプ': '管理者権限',
                        '権限名': role_name,
                        'ロールタイプ': role_type,
                        'リスクレベル': assigned_risk,
                        '最終サインイン': last_signin or 'なし',
                        'アカウント状態': 'アクティブ' if is_active else '非アクティブ',
                        '権限付与日': role.get('assignedDateTime', '不明'),
                        '有効期限': role.get('expirationDateTime', '無期限')
                    }
                    
                    report_data.append(record)
        
        # Process group memberships
        if permission_type in ['all', 'group']:
            for membership in group_memberships:
                user = membership.get('user', {})
                group = membership.get('group', {})
                
                upn = user.get('userPrincipalName', '')
                display_name = user.get('displayName', '')
                dept = user.get('department', '不明')
                is_active = user.get('accountEnabled', True)
                
                group_name = group.get('displayName', '不明')
                group_type = group.get('groupType', 'Security')
                member_count = group.get('memberCount', 0)
                
                # Filter by department
                if department_filter and dept.lower() != department_filter.lower():
                    continue
                
                # Filter inactive users
                if not include_inactive_users and not is_active:
                    continue
                
                # Assess risk level for group membership
                group_risk = _assess_group_risk(group_name, group_type, member_count, is_active)
                
                # Filter by risk level
                if risk_level != 'all' and group_risk.lower() != risk_level:
                    continue
                
                record = {
                    'ユーザー名': display_name,
                    'ユーザープリンシパル名': upn,
                    '部署': dept,
                    '権限タイプ': 'グループメンバーシップ',
                    'グループ名': group_name,
                    'グループタイプ': group_type,
                    'リスクレベル': group_risk,
                    'メンバー数': member_count,
                    'アカウント状態': 'アクティブ' if is_active else '非アクティブ',
                    '参加日': membership.get('joinedDateTime', '不明')
                }
                
                report_data.append(record)
        
        # Process application permissions
        if permission_type in ['all', 'application']:
            for app_perm in app_permissions:
                app = app_perm.get('application', {})
                permissions = app_perm.get('permissions', [])
                
                app_name = app.get('displayName', '不明')
                app_id = app.get('id', '不明')
                
                for perm in permissions:
                    perm_type = perm.get('type', '不明')
                    perm_value = perm.get('value', '不明')
                    
                    # Assess risk level for application permission
                    app_risk = _assess_application_risk(perm_type, perm_value)
                    
                    # Filter by risk level
                    if risk_level != 'all' and app_risk.lower() != risk_level:
                        continue
                    
                    record = {
                        'アプリケーション名': app_name,
                        'アプリケーションID': app_id,
                        '権限タイプ': 'アプリケーション権限',
                        '権限スコープ': perm_type,
                        '権限値': perm_value,
                        'リスクレベル': app_risk,
                        '許可日': perm.get('consentDateTime', '不明'),
                        '許可者': perm.get('consentedBy', '不明')
                    }
                    
                    report_data.append(record)
        
        # Process sharing permissions
        if permission_type in ['all', 'sharing']:
            for sharing in sharing_permissions:
                resource = sharing.get('resource', {})
                shared_with = sharing.get('sharedWith', [])
                
                resource_name = resource.get('name', '不明')
                resource_type = resource.get('type', '不明')
                owner = resource.get('owner', {}).get('displayName', '不明')
                
                for share in shared_with:
                    share_type = share.get('type', 'internal')  # internal/external
                    permission_level = share.get('permission', 'read')
                    
                    # Assess risk level for sharing
                    sharing_risk = _assess_sharing_risk(share_type, permission_level, resource_type)
                    
                    # Filter by risk level
                    if risk_level != 'all' and sharing_risk.lower() != risk_level:
                        continue
                    
                    record = {
                        'リソース名': resource_name,
                        'リソースタイプ': resource_type,
                        'オーナー': owner,
                        '権限タイプ': '外部共有' if share_type == 'external' else '内部共有',
                        '共有先': share.get('email', '不明'),
                        '権限レベル': permission_level,
                        'リスクレベル': sharing_risk,
                        '共有日': sharing.get('sharedDateTime', '不明'),
                        '有効期限': sharing.get('expirationDateTime', '無期限')
                    }
                    
                    report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_permission_data(
            permission_type, risk_level, include_inactive_users, department_filter
        )

def _assess_permission_risk(role_name: str, role_type: str, is_active: bool, last_signin: str) -> str:
    """Assess risk level for a permission assignment"""
    
    high_risk_roles = ['Global Administrator', 'Privileged Role Administrator', 'Exchange Administrator']
    medium_risk_roles = ['User Administrator', 'Security Administrator', 'Compliance Administrator']
    
    if not is_active:
        return 'High'  # Inactive users with roles are high risk
    
    if role_name in high_risk_roles:
        return 'Critical'
    elif role_name in medium_risk_roles:
        return 'High'
    elif not last_signin:  # No recent signin
        return 'Medium'
    else:
        return 'Low'

def _assess_group_risk(group_name: str, group_type: str, member_count: int, is_active: bool) -> str:
    """Assess risk level for group membership"""
    
    if not is_active:
        return 'Medium'
    
    high_risk_groups = ['Domain Admins', 'Enterprise Admins', 'Schema Admins']
    
    if group_name in high_risk_groups:
        return 'Critical'
    elif 'Admin' in group_name:
        return 'High'
    elif member_count > 100:  # Large groups
        return 'Medium'
    else:
        return 'Low'

def _assess_application_risk(perm_type: str, perm_value: str) -> str:
    """Assess risk level for application permissions"""
    
    critical_permissions = ['Directory.ReadWrite.All', 'User.ReadWrite.All', 'Mail.ReadWrite']
    high_risk_permissions = ['Directory.Read.All', 'User.Read.All', 'Files.ReadWrite.All']
    
    if perm_value in critical_permissions:
        return 'Critical'
    elif perm_value in high_risk_permissions:
        return 'High'
    elif 'Write' in perm_value:
        return 'Medium'
    else:
        return 'Low'

def _assess_sharing_risk(share_type: str, permission_level: str, resource_type: str) -> str:
    """Assess risk level for sharing permissions"""
    
    if share_type == 'external':
        if permission_level in ['write', 'owner']:
            return 'Critical'
        else:
            return 'High'
    elif permission_level == 'owner':
        return 'Medium'
    else:
        return 'Low'

def _generate_sample_permission_data(permission_type: str, risk_level: str,
                                   include_inactive_users: bool, department_filter: str) -> List[Dict[str, Any]]:
    """Generate sample permission analysis data"""
    
    import random
    
    sample_users = [
        ("田中 太郎", "tanaka@contoso.com", "IT部", True, "2024-01-20T10:30:00Z"),
        ("佐藤 花子", "sato@contoso.com", "営業部", True, "2024-01-19T14:15:00Z"),
        ("鈴木 次郎", "suzuki@contoso.com", "人事部", False, None),
        ("高橋 美咲", "takahashi@contoso.com", "経理部", True, "2024-01-18T09:45:00Z"),
        ("渡辺 健一", "watanabe@contoso.com", "IT部", True, "2024-01-20T16:20:00Z")
    ]
    
    admin_roles = [
        ("Global Administrator", "Critical"),
        ("Exchange Administrator", "Critical"),
        ("User Administrator", "High"),
        ("Security Administrator", "High"),
        ("Compliance Administrator", "High"),
        ("Help Desk Administrator", "Medium"),
        ("Directory Reader", "Low")
    ]
    
    groups = [
        ("Domain Admins", "Security", 5, "Critical"),
        ("IT Security Team", "Security", 12, "High"),
        ("Sales Team", "Office365", 45, "Low"),
        ("HR Team", "Office365", 8, "Medium"),
        ("All Company", "Distribution", 150, "Low")
    ]
    
    applications = [
        ("Microsoft Graph", "Directory.ReadWrite.All", "Critical"),
        ("PowerBI Service", "User.Read.All", "High"),
        ("SharePoint Online", "Sites.ReadWrite.All", "Medium"),
        ("Teams App", "Chat.ReadWrite", "Low")
    ]
    
    sharing_data = [
        ("Confidential Report.xlsx", "File", "external", "read", "Critical"),
        ("Project Plan.docx", "File", "internal", "write", "Medium"),
        ("Team Photos", "Folder", "internal", "read", "Low")
    ]
    
    report_data = []
    
    # Admin permissions
    if permission_type in ['all', 'admin']:
        for name, upn, dept, is_active, last_signin in sample_users:
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            if not include_inactive_users and not is_active:
                continue
            
            # Randomly assign roles
            if random.random() < 0.4:  # 40% chance to have admin role
                role_name, role_risk = random.choice(admin_roles)
                
                if risk_level != 'all' and role_risk.lower() != risk_level:
                    continue
                
                record = {
                    'ユーザー名': name,
                    'ユーザープリンシパル名': upn,
                    '部署': dept,
                    '権限タイプ': '管理者権限',
                    '権限名': role_name,
                    'ロールタイプ': 'DirectoryRole',
                    'リスクレベル': role_risk,
                    '最終サインイン': last_signin or 'なし',
                    'アカウント状態': 'アクティブ' if is_active else '非アクティブ',
                    '権限付与日': '2023-12-01T00:00:00Z',
                    '有効期限': '無期限'
                }
                
                report_data.append(record)
    
    # Group memberships
    if permission_type in ['all', 'group']:
        for name, upn, dept, is_active, last_signin in sample_users:
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            if not include_inactive_users and not is_active:
                continue
            
            # Assign to 2-3 groups
            selected_groups = random.sample(groups, random.randint(1, 3))
            for group_name, group_type, member_count, group_risk in selected_groups:
                
                if risk_level != 'all' and group_risk.lower() != risk_level:
                    continue
                
                record = {
                    'ユーザー名': name,
                    'ユーザープリンシパル名': upn,
                    '部署': dept,
                    '権限タイプ': 'グループメンバーシップ',
                    'グループ名': group_name,
                    'グループタイプ': group_type,
                    'リスクレベル': group_risk,
                    'メンバー数': member_count,
                    'アカウント状態': 'アクティブ' if is_active else '非アクティブ',
                    '参加日': '2023-11-15T00:00:00Z'
                }
                
                report_data.append(record)
    
    # Application permissions
    if permission_type in ['all', 'application']:
        for app_name, permission, app_risk in applications:
            if risk_level != 'all' and app_risk.lower() != risk_level:
                continue
            
            record = {
                'アプリケーション名': app_name,
                'アプリケーションID': f"app-{hash(app_name) % 10000:04d}",
                '権限タイプ': 'アプリケーション権限',
                '権限スコープ': 'Application',
                '権限値': permission,
                'リスクレベル': app_risk,
                '許可日': '2023-10-01T00:00:00Z',
                '許可者': 'admin@contoso.com'
            }
            
            report_data.append(record)
    
    # Sharing permissions
    if permission_type in ['all', 'sharing']:
        for resource_name, resource_type, share_type, perm_level, share_risk in sharing_data:
            if risk_level != 'all' and share_risk.lower() != risk_level:
                continue
            
            record = {
                'リソース名': resource_name,
                'リソースタイプ': resource_type,
                'オーナー': '田中 太郎',
                '権限タイプ': '外部共有' if share_type == 'external' else '内部共有',
                '共有先': 'external@partner.com' if share_type == 'external' else 'internal@contoso.com',
                '権限レベル': perm_level,
                'リスクレベル': share_risk,
                '共有日': '2024-01-10T00:00:00Z',
                '有効期限': '2024-07-10T00:00:00Z' if share_type == 'external' else '無期限'
            }
            
            report_data.append(record)
    
    return report_data

def _show_permission_summary(report_data: List[Dict[str, Any]], output: OutputFormatter,
                           permission_type: str, risk_level: str):
    """Show permission analysis summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_permissions = len(report_data)
    critical_permissions = len([r for r in report_data if r.get('リスクレベル') == 'Critical'])
    high_risk_permissions = len([r for r in report_data if r.get('リスクレベル') == 'High'])
    medium_risk_permissions = len([r for r in report_data if r.get('リスクレベル') == 'Medium'])
    low_risk_permissions = len([r for r in report_data if r.get('リスクレベル') == 'Low'])
    
    # Permission type breakdown
    perm_type_stats = {}
    for record in report_data:
        perm_type = record.get('権限タイプ', '不明')
        if perm_type not in perm_type_stats:
            perm_type_stats[perm_type] = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}
        
        risk = record.get('リスクレベル', 'Low')
        perm_type_stats[perm_type][risk.lower()] += 1
    
    # Inactive account analysis
    inactive_accounts = len([r for r in report_data if r.get('アカウント状態') == '非アクティブ'])
    
    # Calculate risk score
    risk_score = 100
    if total_permissions > 0:
        risk_score = max(0, 100 - (critical_permissions * 20) - (high_risk_permissions * 10) - (medium_risk_permissions * 5) - (low_risk_permissions * 1))
    
    click.echo("\n🔐 権限分析サマリー")
    click.echo("=" * 35)
    click.echo(f"🎯 権限タイプ: {permission_type.upper()}")
    click.echo(f"📊 リスクフィルター: {risk_level.upper()}")
    click.echo(f"📋 総権限数: {total_permissions}")
    click.echo(f"🚨 重大リスク: {critical_permissions}")
    click.echo(f"🔴 高リスク: {high_risk_permissions}")
    click.echo(f"🟡 中リスク: {medium_risk_permissions}")
    click.echo(f"🟢 低リスク: {low_risk_permissions}")
    click.echo(f"⚠️ 非アクティブアカウント: {inactive_accounts}")
    click.echo(f"🛡️ 権限リスクスコア: {risk_score:.0f}/100")
    
    # Permission type breakdown
    if perm_type_stats:
        click.echo("\n📦 権限タイプ別内訳:")
        for perm_type, stats in perm_type_stats.items():
            total_type = stats['critical'] + stats['high'] + stats['medium'] + stats['low']
            click.echo(f"  🔑 {perm_type}: 重大{stats['critical']}, 高{stats['high']}, 中{stats['medium']}, 低{stats['low']} (計{total_type})")
    
    # Risk assessment
    click.echo("\n🛡️ 権限リスク評価:")
    if risk_score >= 90:
        click.echo("  🎉 優秀: 権限管理は適切に行われています")
    elif risk_score >= 75:
        click.echo("  🔶 良好: 軽微な権限リスクがありますが、管理可能です")
    elif risk_score >= 50:
        click.echo("  ⚠️ 注意: 権限の見直しと最適化が必要です")
    else:
        click.echo("  🚨 危険: 権限管理に重大な問題があります")
    
    # Recommendations
    click.echo("\n💡 権限最適化推奨事項:")
    if critical_permissions > 0:
        click.echo(f"  • {critical_permissions} 件の重大権限の即座の見直し")
    if high_risk_permissions > 0:
        click.echo(f"  • {high_risk_permissions} 件の高リスク権限の定期的な監査")
    if inactive_accounts > 0:
        click.echo(f"  • {inactive_accounts} 個の非アクティブアカウントの権限剥奪")
    
    # Type-specific recommendations
    for perm_type, stats in perm_type_stats.items():
        if stats['critical'] > 0 or stats['high'] > 0:
            if perm_type == '管理者権限':
                click.echo("  • 管理者権限: 最小権限の原則適用と定期的な権限見直し")
            elif perm_type == 'グループメンバーシップ':
                click.echo("  • グループメンバーシップ: 不要なグループからの除名")
            elif perm_type == 'アプリケーション権限':
                click.echo("  • アプリケーション権限: アプリの権限スコープ最小化")
            elif perm_type == '外部共有':
                click.echo("  • 外部共有: 共有ポリシーの厳格化と期限設定")
    
    if total_permissions == 0:
        click.echo("  • 権限設定は適切です。継続的な監査を維持してください")
    
    click.echo()

# Command alias for PowerShell compatibility
permission_analysis = permission_command