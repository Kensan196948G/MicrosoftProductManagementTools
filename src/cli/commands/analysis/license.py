# Microsoft 365 Management Tools - License Analysis Command
# ライセンス分析・コスト最適化レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--include-cost-analysis', is_flag=True, help='コスト分析を含める')
@click.option('--unused-only', is_flag=True, help='未使用ライセンスのみ')
@click.option('--department', help='特定部署のみ対象')
@click.option('--license-type', type=click.Choice(['all', 'office365', 'enterprise', 'basic']), 
              default='all', help='対象ライセンスタイプ')
@click.pass_context
def license_command(ctx, include_cost_analysis, unused_only, department, license_type):
    """ライセンス分析・コスト最適化レポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 license
    
    Microsoft 365ライセンスの使用状況、コスト分析、最適化提案を生成します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_license_analysis(
        cli_context, include_cost_analysis, unused_only, department, license_type
    ))

async def execute_license_analysis(context: CLIContext,
                                 include_cost_analysis: bool = False,
                                 unused_only: bool = False,
                                 department_filter: str = None,
                                 license_type_filter: str = 'all'):
    """Execute license analysis report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("ライセンス分析レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_license_data(
                include_cost_analysis, unused_only, department_filter, license_type_filter
            )
        else:
            report_data = await _generate_license_analysis_data(
                context, include_cost_analysis, unused_only, department_filter, license_type_filter
            )
        
        if not report_data:
            output.output_warning("ライセンスデータが見つかりませんでした")
            return
        
        output.output_success(f"ライセンス分析レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="ライセンス分析レポート",
            filename_prefix="license_analysis_report"
        )
        
        _show_license_summary(report_data, output, include_cost_analysis)
        
    except Exception as e:
        output.output_error(f"ライセンス分析レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_license_analysis_data(context: CLIContext,
                                        include_cost_analysis: bool,
                                        unused_only: bool,
                                        department_filter: str,
                                        license_type_filter: str) -> List[Dict[str, Any]]:
    """Generate license analysis data from Microsoft 365 APIs"""
    
    try:
        from src.api.graph.client import GraphClient
        from src.core.auth.authenticator import Authenticator
        
        authenticator = Authenticator(context.config)
        await authenticator.authenticate_graph()
        graph_client = GraphClient(authenticator)
        
        output = OutputFormatter(context)
        
        # Get license information
        output.output_progress("ライセンス情報を取得中...")
        
        # Get all users with license details
        users_data = await graph_client.get_users_with_licenses()
        
        # Get license usage statistics
        license_stats = await graph_client.get_license_statistics()
        
        # Get service usage data
        service_usage = await graph_client.get_service_usage_data()
        
        report_data = []
        
        for user in users_data:
            upn = user.get('userPrincipalName', '')
            display_name = user.get('displayName', '')
            dept = user.get('department', '不明')
            
            # Filter by department if specified
            if department_filter and dept.lower() != department_filter.lower():
                continue
            
            # Get assigned licenses
            assigned_licenses = user.get('assignedLicenses', [])
            
            for license_info in assigned_licenses:
                sku_part_number = license_info.get('skuPartNumber', '不明')
                
                # Filter by license type if specified
                if license_type_filter != 'all':
                    if license_type_filter == 'office365' and 'OFFICE' not in sku_part_number:
                        continue
                    elif license_type_filter == 'enterprise' and 'ENTERPRISE' not in sku_part_number:
                        continue
                    elif license_type_filter == 'basic' and 'BASIC' not in sku_part_number:
                        continue
                
                # Get usage data for this user
                user_usage = service_usage.get(upn, {})
                last_activity = user_usage.get('lastActivity')
                service_usage_count = len([s for s in user_usage.get('services', []) if s.get('used', False)])
                
                # Determine usage status
                usage_status = "使用中"
                if not last_activity:
                    usage_status = "未使用"
                elif service_usage_count == 0:
                    usage_status = "低使用"
                
                # Skip if only unused requested
                if unused_only and usage_status == "使用中":
                    continue
                
                # Get cost information if requested
                monthly_cost = 0.0
                if include_cost_analysis:
                    cost_info = license_stats.get(sku_part_number, {})
                    monthly_cost = cost_info.get('monthlyCost', 0.0)
                
                record = {
                    'ユーザー名': display_name,
                    'ユーザープリンシパル名': upn,
                    '部署': dept,
                    'ライセンス名': sku_part_number,
                    '使用状況': usage_status,
                    'サービス使用数': service_usage_count,
                    '最終アクティビティ': last_activity or 'なし',
                    'アカウント状態': user.get('accountEnabled', True) and '有効' or '無効'
                }
                
                if include_cost_analysis:
                    record['月額コスト'] = f"${monthly_cost:.2f}"
                    record['年額コスト'] = f"${monthly_cost * 12:.2f}"
                
                report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_license_data(
            include_cost_analysis, unused_only, department_filter, license_type_filter
        )

def _generate_sample_license_data(include_cost_analysis: bool, unused_only: bool,
                                department_filter: str, license_type_filter: str) -> List[Dict[str, Any]]:
    """Generate sample license analysis data"""
    
    sample_data = [
        ("田中 太郎", "tanaka@contoso.com", "IT部", "ENTERPRISEPACK", "使用中", 8, "2024-01-20", "有効", 22.00),
        ("佐藤 花子", "sato@contoso.com", "営業部", "ENTERPRISEPACK", "使用中", 6, "2024-01-19", "有効", 22.00),
        ("鈴木 次郎", "suzuki@contoso.com", "人事部", "ENTERPRISEPACK", "低使用", 2, "2024-01-15", "有効", 22.00),
        ("高橋 美咲", "takahashi@contoso.com", "経理部", "ENTERPRISEPACK", "未使用", 0, "なし", "無効", 22.00),
        ("渡辺 健一", "watanabe@contoso.com", "IT部", "ENTERPRISEPACK", "使用中", 9, "2024-01-20", "有効", 22.00),
        ("山田 綾子", "yamada@contoso.com", "営業部", "OFFICE365_BUSINESS_PREMIUM", "使用中", 5, "2024-01-18", "有効", 12.50),
        ("中村 大輔", "nakamura@contoso.com", "開発部", "ENTERPRISEPACK", "使用中", 7, "2024-01-20", "有効", 22.00),
        ("小林 真由美", "kobayashi@contoso.com", "マーケティング部", "OFFICE365_BUSINESS_PREMIUM", "低使用", 3, "2024-01-17", "有効", 12.50)
    ]
    
    report_data = []
    
    for user_data in sample_data:
        name, upn, dept, license, status, services, last_activity, account_status, cost = user_data
        
        # Filter by department if specified
        if department_filter and dept.lower() != department_filter.lower():
            continue
        
        # Filter by license type if specified
        if license_type_filter != 'all':
            if license_type_filter == 'office365' and 'OFFICE' not in license:
                continue
            elif license_type_filter == 'enterprise' and 'ENTERPRISE' not in license:
                continue
            elif license_type_filter == 'basic' and 'BASIC' not in license:
                continue
        
        # Skip if only unused requested
        if unused_only and status == "使用中":
            continue
        
        record = {
            'ユーザー名': name,
            'ユーザープリンシパル名': upn,
            '部署': dept,
            'ライセンス名': license,
            '使用状況': status,
            'サービス使用数': services,
            '最終アクティビティ': last_activity,
            'アカウント状態': account_status
        }
        
        if include_cost_analysis:
            record['月額コスト'] = f"${cost:.2f}"
            record['年額コスト'] = f"${cost * 12:.2f}"
        
        report_data.append(record)
    
    return report_data

def _show_license_summary(report_data: List[Dict[str, Any]], output: OutputFormatter, include_cost_analysis: bool):
    """Show license analysis summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_licenses = len(report_data)
    active_licenses = len([r for r in report_data if r['使用状況'] == '使用中'])
    unused_licenses = len([r for r in report_data if r['使用状況'] == '未使用'])
    low_usage_licenses = len([r for r in report_data if r['使用状況'] == '低使用'])
    
    # License type breakdown
    enterprise_licenses = len([r for r in report_data if 'ENTERPRISE' in r['ライセンス名']])
    office365_licenses = len([r for r in report_data if 'OFFICE365' in r['ライセンス名']])
    other_licenses = total_licenses - enterprise_licenses - office365_licenses
    
    utilization_rate = (active_licenses / total_licenses) * 100 if total_licenses > 0 else 0
    
    click.echo("\n📊 ライセンス分析サマリー")
    click.echo("=" * 35)
    click.echo(f"📋 総ライセンス数: {total_licenses}")
    click.echo(f"✅ アクティブ: {active_licenses} ({active_licenses/total_licenses*100:.1f}%)")
    click.echo(f"🔶 低使用: {low_usage_licenses} ({low_usage_licenses/total_licenses*100:.1f}%)")
    click.echo(f"❌ 未使用: {unused_licenses} ({unused_licenses/total_licenses*100:.1f}%)")
    click.echo(f"📈 利用率: {utilization_rate:.1f}%")
    click.echo()
    click.echo("📦 ライセンスタイプ別:")
    click.echo(f"  🏢 Enterprise: {enterprise_licenses}")
    click.echo(f"  💼 Office365: {office365_licenses}")
    click.echo(f"  📄 その他: {other_licenses}")
    
    # Cost analysis if included
    if include_cost_analysis:
        total_monthly_cost = 0.0
        for record in report_data:
            if '月額コスト' in record:
                cost_str = record['月額コスト'].replace('$', '')
                total_monthly_cost += float(cost_str)
        
        potential_savings = 0.0
        for record in report_data:
            if record['使用状況'] in ['未使用', '低使用'] and '月額コスト' in record:
                cost_str = record['月額コスト'].replace('$', '')
                potential_savings += float(cost_str)
        
        click.echo()
        click.echo("💰 コスト分析:")
        click.echo(f"  💲 月額総コスト: ${total_monthly_cost:.2f}")
        click.echo(f"  💲 年額総コスト: ${total_monthly_cost * 12:.2f}")
        click.echo(f"  💲 潜在的節約額/月: ${potential_savings:.2f}")
        click.echo(f"  💲 潜在的節約額/年: ${potential_savings * 12:.2f}")
    
    # Recommendations
    click.echo()
    click.echo("💡 最適化提案:")
    if unused_licenses > 0:
        click.echo(f"  • {unused_licenses} 個の未使用ライセンスの見直しを推奨")
    if low_usage_licenses > 0:
        click.echo(f"  • {low_usage_licenses} 個の低使用ライセンスのダウングレードを検討")
    if utilization_rate > 90:
        click.echo("  • 高い利用率です。追加ライセンス購入を検討してください")
    elif utilization_rate < 70:
        click.echo("  • 利用率が低いです。ライセンス最適化の余地があります")
    
    click.echo()

# Command alias for PowerShell compatibility
license_analysis = license_command