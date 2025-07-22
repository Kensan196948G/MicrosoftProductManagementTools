# Microsoft 365 Management Tools - Conditional Access Command
# 条件付きアクセス・アクセス制御分析 - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--policy-state', type=click.Choice(['all', 'enabled', 'disabled', 'report-only']),
              default='all', help='ポリシー状態フィルター')
@click.option('--include-details', is_flag=True, help='ポリシー詳細条件を含める')
@click.option('--policy-name', help='特定ポリシー名でフィルター')
@click.option('--show-impact', is_flag=True, help='ユーザー影響分析を含める')
@click.pass_context
def conditional_command(ctx, policy_state, include_details, policy_name, show_impact):
    """条件付きアクセス・アクセス制御ポリシー分析
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 conditional
    
    Entra IDの条件付きアクセスポリシー設定、適用状況を分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_conditional_report(
        cli_context, policy_state, include_details, policy_name, show_impact
    ))

async def execute_conditional_report(context: CLIContext,
                                   policy_state: str = 'all',
                                   include_details: bool = False,
                                   policy_name_filter: str = None,
                                   show_impact: bool = False):
    """Execute conditional access report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("条件付きアクセスポリシーを取得中...")
        
        if context.dry_run:
            report_data = _generate_sample_conditional_data(
                policy_state, include_details, policy_name_filter, show_impact
            )
        else:
            report_data = await _generate_conditional_report_data(
                context, policy_state, include_details, policy_name_filter, show_impact
            )
        
        if not report_data:
            output.output_warning("条件付きアクセスデータが見つかりませんでした")
            return
        
        output.output_success(f"条件付きアクセスレポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="条件付きアクセスレポート",
            filename_prefix="conditional_access_report"
        )
        
        _show_conditional_summary(report_data, output, policy_state)
        
    except Exception as e:
        output.output_error(f"条件付きアクセスレポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_conditional_report_data(context: CLIContext,
                                          policy_state: str,
                                          include_details: bool,
                                          policy_name_filter: str,
                                          show_impact: bool) -> List[Dict[str, Any]]:
    """Generate conditional access report data from Microsoft Graph APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get conditional access policies
        output.output_progress("条件付きアクセスポリシー一覧を取得中...")
        
        ca_policies = await graph_client.get_conditional_access_policies()
        
        # Get policy usage/impact data if requested
        policy_usage = {}
        if show_impact:
            output.output_progress("ポリシー適用状況を取得中...")
            policy_usage = await graph_client.get_conditional_access_usage()
        
        report_data = []
        
        for policy in ca_policies:
            policy_id = policy.get('id', '')
            display_name = policy.get('displayName', '')
            state = policy.get('state', 'disabled')  # enabled, disabled, enabledForReportingButNotEnforced
            created_date = policy.get('createdDateTime', '')
            modified_date = policy.get('modifiedDateTime', '')
            
            # Filter by policy name if specified
            if policy_name_filter and policy_name_filter.lower() not in display_name.lower():
                continue
            
            # Filter by policy state
            if policy_state != 'all':
                if policy_state == 'enabled' and state != 'enabled':
                    continue
                elif policy_state == 'disabled' and state != 'disabled':
                    continue
                elif policy_state == 'report-only' and state != 'enabledForReportingButNotEnforced':
                    continue
            
            # Get policy conditions
            conditions = policy.get('conditions', {})
            users = conditions.get('users', {})
            applications = conditions.get('applications', {})
            locations = conditions.get('locations', {})
            
            # Get grant controls
            grant_controls = policy.get('grantControls', {})
            operator = grant_controls.get('operator', 'OR')
            built_in_controls = grant_controls.get('builtInControls', [])
            
            # Determine policy type and risk level
            policy_type = _determine_policy_type(conditions, built_in_controls)
            risk_level = _assess_policy_risk(state, conditions, built_in_controls)
            
            # Get usage statistics if available
            usage_stats = policy_usage.get(policy_id, {})
            affected_users = usage_stats.get('affectedUsers', 0)
            success_rate = usage_stats.get('successRate', 0.0)
            
            record = {
                'ポリシー名': display_name,
                'ポリシーID': policy_id,
                '状態': state,
                'ポリシータイプ': policy_type,
                'リスクレベル': risk_level,
                '対象ユーザー': _format_user_conditions(users),
                '対象アプリケーション': _format_app_conditions(applications),
                '場所条件': _format_location_conditions(locations),
                '制御アクション': _format_grant_controls(built_in_controls, operator),
                '作成日': created_date,
                '更新日': modified_date
            }
            
            if show_impact:
                record['影響ユーザー数'] = affected_users
                record['成功率'] = f"{success_rate:.1f}%" if success_rate > 0 else '不明'
            
            if include_details:
                record['詳細条件'] = _format_detailed_conditions(conditions)
                record['セッション制御'] = _format_session_controls(policy.get('sessionControls', {}))
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_conditional_data(
            policy_state, include_details, policy_name_filter, show_impact
        )

def _determine_policy_type(conditions: Dict, controls: List[str]) -> str:
    """Determine the type of conditional access policy"""
    
    if 'mfa' in controls:
        return 'MFA必須'
    elif 'domainJoinedDevice' in controls or 'compliantDevice' in controls:
        return 'デバイス制御'
    elif conditions.get('locations', {}).get('excludeLocations'):
        return '場所ベース'
    elif conditions.get('applications', {}).get('includeApplications'):
        return 'アプリ制御'
    elif conditions.get('userRiskLevels') or conditions.get('signInRiskLevels'):
        return 'リスクベース'
    else:
        return '汎用'

def _assess_policy_risk(state: str, conditions: Dict, controls: List[str]) -> str:
    """Assess the risk level of a policy configuration"""
    
    if state == 'disabled':
        return '🔴高'  # Disabled security policies are high risk
    
    # Check for comprehensive coverage
    has_mfa = 'mfa' in controls
    has_device = any(ctrl in controls for ctrl in ['domainJoinedDevice', 'compliantDevice'])
    has_block = 'block' in controls
    
    if has_block:
        return '⚠️中'  # Blocking policies need careful monitoring
    elif has_mfa and has_device:
        return '✅低'  # Comprehensive security
    elif has_mfa or has_device:
        return '🟡中'  # Partial security
    else:
        return '🔴高'  # Insufficient security

def _format_user_conditions(users: Dict) -> str:
    """Format user conditions for display"""
    
    include_users = users.get('includeUsers', [])
    exclude_users = users.get('excludeUsers', [])
    include_groups = users.get('includeGroups', [])
    
    if 'All' in include_users:
        return '全ユーザー'
    elif include_groups:
        return f"グループ: {len(include_groups)}個"
    elif include_users:
        return f"ユーザー: {len(include_users)}人"
    else:
        return '未指定'

def _format_app_conditions(applications: Dict) -> str:
    """Format application conditions for display"""
    
    include_apps = applications.get('includeApplications', [])
    exclude_apps = applications.get('excludeApplications', [])
    
    if 'All' in include_apps:
        return '全アプリケーション'
    elif include_apps:
        return f"アプリ: {len(include_apps)}個"
    else:
        return '未指定'

def _format_location_conditions(locations: Dict) -> str:
    """Format location conditions for display"""
    
    include_locations = locations.get('includeLocations', [])
    exclude_locations = locations.get('excludeLocations', [])
    
    if 'All' in include_locations:
        return '全ての場所'
    elif exclude_locations:
        return f"除外場所: {len(exclude_locations)}個"
    elif include_locations:
        return f"許可場所: {len(include_locations)}個"
    else:
        return '制限なし'

def _format_grant_controls(controls: List[str], operator: str) -> str:
    """Format grant controls for display"""
    
    control_names = {
        'mfa': '多要素認証',
        'domainJoinedDevice': 'ドメイン参加デバイス',
        'compliantDevice': '準拠デバイス',
        'approvedApplication': '承認済みアプリ',
        'block': 'ブロック'
    }
    
    formatted_controls = [control_names.get(ctrl, ctrl) for ctrl in controls]
    
    if not formatted_controls:
        return '制御なし'
    
    connector = ' および ' if operator == 'AND' else ' または '
    return connector.join(formatted_controls)

def _format_detailed_conditions(conditions: Dict) -> str:
    """Format detailed conditions for display"""
    
    details = []
    
    if conditions.get('userRiskLevels'):
        details.append(f"ユーザーリスク: {', '.join(conditions['userRiskLevels'])}")
    
    if conditions.get('signInRiskLevels'):
        details.append(f"サインインリスク: {', '.join(conditions['signInRiskLevels'])}")
    
    if conditions.get('platforms'):
        platforms = conditions['platforms'].get('includePlatforms', [])
        if platforms:
            details.append(f"プラットフォーム: {', '.join(platforms)}")
    
    return '; '.join(details) if details else 'なし'

def _format_session_controls(session_controls: Dict) -> str:
    """Format session controls for display"""
    
    controls = []
    
    if session_controls.get('applicationEnforcedRestrictions'):
        controls.append('アプリ制限')
    
    if session_controls.get('cloudAppSecurity'):
        controls.append('Cloud App Security')
    
    if session_controls.get('signInFrequency'):
        frequency = session_controls['signInFrequency']
        controls.append(f"サインイン頻度: {frequency.get('value')} {frequency.get('type')}")
    
    return ', '.join(controls) if controls else 'なし'

def _generate_sample_conditional_data(policy_state: str, include_details: bool,
                                    policy_name_filter: str, show_impact: bool) -> List[Dict[str, Any]]:
    """Generate sample conditional access data"""
    
    sample_policies = [
        {
            'name': 'MFA for All Users',
            'id': 'policy-001',
            'state': 'enabled',
            'type': 'MFA必須',
            'risk': '✅低',
            'users': '全ユーザー',
            'apps': '全アプリケーション',
            'locations': '制限なし',
            'controls': '多要素認証',
            'affected_users': 150,
            'success_rate': 98.5
        },
        {
            'name': 'Block Legacy Authentication',
            'id': 'policy-002', 
            'state': 'enabled',
            'type': 'アプリ制御',
            'risk': '✅低',
            'users': '全ユーザー',
            'apps': 'レガシーアプリ',
            'locations': '制限なし',
            'controls': 'ブロック',
            'affected_users': 25,
            'success_rate': 100.0
        },
        {
            'name': 'High Risk Sign-in Policy',
            'id': 'policy-003',
            'state': 'enabled',
            'type': 'リスクベース',
            'risk': '🟡中',
            'users': '全ユーザー',
            'apps': '全アプリケーション', 
            'locations': '制限なし',
            'controls': '多要素認証',
            'affected_users': 12,
            'success_rate': 85.2
        },
        {
            'name': 'Admin MFA Enforcement',
            'id': 'policy-004',
            'state': 'enabled',
            'type': 'MFA必須',
            'risk': '✅低',
            'users': 'グループ: 1個',
            'apps': '管理ポータル',
            'locations': '制限なし',
            'controls': '多要素認証 および 準拠デバイス',
            'affected_users': 8,
            'success_rate': 96.8
        },
        {
            'name': 'Guest User Access',
            'id': 'policy-005',
            'state': 'enabledForReportingButNotEnforced',
            'type': '汎用',
            'risk': '⚠️中',
            'users': 'ゲストユーザー',
            'apps': '特定アプリ: 5個',
            'locations': '許可場所: 2個',
            'controls': '多要素認証',
            'affected_users': 15,
            'success_rate': 0.0
        },
        {
            'name': 'Device Compliance Policy',
            'id': 'policy-006',
            'state': 'disabled',
            'type': 'デバイス制御',
            'risk': '🔴高',
            'users': '全ユーザー',
            'apps': '全アプリケーション',
            'locations': '制限なし',
            'controls': '準拠デバイス',
            'affected_users': 0,
            'success_rate': 0.0
        }
    ]
    
    report_data = []
    
    for policy_info in sample_policies:
        # Apply filters
        if policy_name_filter and policy_name_filter.lower() not in policy_info['name'].lower():
            continue
        
        state = policy_info['state']
        if policy_state != 'all':
            if policy_state == 'enabled' and state != 'enabled':
                continue
            elif policy_state == 'disabled' and state != 'disabled':
                continue
            elif policy_state == 'report-only' and state != 'enabledForReportingButNotEnforced':
                continue
        
        # Generate dates
        import random
        created_date = (datetime.now() - timedelta(days=random.randint(30, 365))).strftime('%Y-%m-%dT%H:%M:%SZ')
        modified_date = (datetime.now() - timedelta(days=random.randint(1, 30))).strftime('%Y-%m-%dT%H:%M:%SZ')
        
        record = {
            'ポリシー名': policy_info['name'],
            'ポリシーID': policy_info['id'],
            '状態': state,
            'ポリシータイプ': policy_info['type'],
            'リスクレベル': policy_info['risk'],
            '対象ユーザー': policy_info['users'],
            '対象アプリケーション': policy_info['apps'],
            '場所条件': policy_info['locations'],
            '制御アクション': policy_info['controls'],
            '作成日': created_date,
            '更新日': modified_date
        }
        
        if show_impact:
            record['影響ユーザー数'] = policy_info['affected_users']
            record['成功率'] = f"{policy_info['success_rate']:.1f}%" if policy_info['success_rate'] > 0 else '不明'
        
        if include_details:
            import random
            details = []
            if random.choice([True, False]):
                details.append("ユーザーリスク: medium, high")
            if random.choice([True, False]):
                details.append("プラットフォーム: Windows, iOS")
            
            record['詳細条件'] = '; '.join(details) if details else 'なし'
            record['セッション制御'] = random.choice(['なし', 'アプリ制限', 'Cloud App Security'])
        
        report_data.append(record)
    
    return report_data

def _show_conditional_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, policy_state: str):
    """Show conditional access report summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_policies = len(report_data)
    enabled_policies = len([r for r in report_data if r['状態'] == 'enabled'])
    disabled_policies = len([r for r in report_data if r['状態'] == 'disabled'])
    report_only_policies = len([r for r in report_data if r['状態'] == 'enabledForReportingButNotEnforced'])
    
    # Policy type breakdown
    policy_types = {}
    for record in report_data:
        policy_type = record.get('ポリシータイプ', '不明')
        policy_types[policy_type] = policy_types.get(policy_type, 0) + 1
    
    # Risk level analysis
    risk_levels = {}
    for record in report_data:
        risk_level = record.get('リスクレベル', '不明')
        risk_levels[risk_level] = risk_levels.get(risk_level, 0) + 1
    
    # Calculate coverage rates
    enable_rate = (enabled_policies / total_policies) * 100 if total_policies > 0 else 0
    
    click.echo("\n🔒 条件付きアクセスサマリー")
    click.echo("=" * 40)
    click.echo(f"🎯 フィルター: {policy_state.upper()}")
    click.echo(f"📋 総ポリシー数: {total_policies}")
    click.echo(f"✅ 有効: {enabled_policies} ({enable_rate:.1f}%)")
    click.echo(f"❌ 無効: {disabled_policies}")
    click.echo(f"📊 レポートのみ: {report_only_policies}")
    
    # Policy type breakdown
    if policy_types:
        click.echo("\n📦 ポリシータイプ別:")
        sorted_types = sorted(policy_types.items(), key=lambda x: x[1], reverse=True)
        for policy_type, count in sorted_types:
            percentage = (count / total_policies) * 100
            click.echo(f"  🔧 {policy_type}: {count} ({percentage:.1f}%)")
    
    # Risk level analysis
    if risk_levels:
        click.echo("\n🚨 リスクレベル分析:")
        risk_order = ['🔴高', '⚠️中', '🟡中', '✅低', '低']
        for risk_level in risk_order:
            if risk_level in risk_levels:
                count = risk_levels[risk_level]
                percentage = (count / total_policies) * 100
                click.echo(f"  {risk_level}: {count} ({percentage:.1f}%)")
    
    # Impact analysis (if available)
    total_affected = 0
    successful_policies = 0
    for record in report_data:
        if '影響ユーザー数' in record:
            total_affected += record['影響ユーザー数']
        if '成功率' in record and record['成功率'] != '不明':
            success_rate_str = record['成功率'].replace('%', '')
            if float(success_rate_str) > 90:
                successful_policies += 1
    
    if total_affected > 0:
        click.echo(f"\n👥 総影響ユーザー数: {total_affected}")
        click.echo(f"📈 高成功率ポリシー: {successful_policies}")
    
    # Security posture assessment
    click.echo("\n🛡️ セキュリティ体制評価:")
    high_risk_count = risk_levels.get('🔴高', 0)
    low_risk_count = risk_levels.get('✅低', 0) + risk_levels.get('低', 0)
    
    if high_risk_count == 0 and enable_rate >= 80:
        click.echo("  🎉 優秀: 条件付きアクセス体制は良好です")
    elif high_risk_count <= 1 and enable_rate >= 60:
        click.echo("  🔶 良好: 軽微な改善の余地があります")
    elif high_risk_count <= 2 and enable_rate >= 40:
        click.echo("  ⚠️ 注意: ポリシーの見直しと強化が必要です")
    else:
        click.echo("  🚨 警告: 条件付きアクセス体制の大幅な改善が必要です")
    
    # Recommendations
    click.echo("\n💡 セキュリティ強化推奨事項:")
    if disabled_policies > 0:
        click.echo(f"  • {disabled_policies} 個の無効ポリシーの有効化を検討")
    if high_risk_count > 0:
        click.echo(f"  • {high_risk_count} 個の高リスクポリシーの見直し")
    if report_only_policies > 0:
        click.echo(f"  • {report_only_policies} 個のレポートモードポリシーの本格運用移行")
    
    # Policy type recommendations
    mfa_policies = policy_types.get('MFA必須', 0)
    device_policies = policy_types.get('デバイス制御', 0)
    
    if mfa_policies == 0:
        click.echo("  • MFA必須ポリシーの実装を強く推奨")
    if device_policies == 0:
        click.echo("  • デバイス制御ポリシーの導入を検討")
    if total_policies < 3:
        click.echo("  • 包括的なセキュリティポリシーセットの構築")
    
    click.echo()

# Command alias for PowerShell compatibility
conditional_access = conditional_command