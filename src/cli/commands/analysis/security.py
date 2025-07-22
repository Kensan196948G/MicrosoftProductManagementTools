# Microsoft 365 Management Tools - Security Analysis Command
# セキュリティ分析・脅威検出レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--threat-type', type=click.Choice(['all', 'malware', 'phishing', 'suspicious-login', 'data-leak']),
              default='all', help='脅威タイプ')
@click.option('--severity', type=click.Choice(['all', 'critical', 'high', 'medium', 'low']),
              default='all', help='重要度レベル')
@click.option('--time-period', type=click.Choice(['24hours', '7days', '30days', '90days']),
              default='7days', help='分析期間')
@click.option('--include-compliance', is_flag=True, help='コンプライアンス分析を含める')
@click.pass_context
def security_command(ctx, threat_type, severity, time_period, include_compliance):
    """セキュリティ分析・脅威検出レポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 security
    
    Microsoft 365のセキュリティ脅威、異常検知、コンプライアンス状況を分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_security_analysis(
        cli_context, threat_type, severity, time_period, include_compliance
    ))

async def execute_security_analysis(context: CLIContext,
                                  threat_type: str = 'all',
                                  severity: str = 'all',
                                  time_period: str = '7days',
                                  include_compliance: bool = False):
    """Execute security analysis report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("セキュリティ分析レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_security_data(
                threat_type, severity, time_period, include_compliance
            )
        else:
            report_data = await _generate_security_analysis_data(
                context, threat_type, severity, time_period, include_compliance
            )
        
        if not report_data:
            output.output_warning("セキュリティデータが見つかりませんでした")
            return
        
        output.output_success(f"セキュリティ分析レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="セキュリティ分析レポート",
            filename_prefix="security_analysis_report"
        )
        
        _show_security_summary(report_data, output, threat_type, severity, time_period)
        
    except Exception as e:
        output.output_error(f"セキュリティ分析レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_security_analysis_data(context: CLIContext,
                                         threat_type: str,
                                         severity: str,
                                         time_period: str,
                                         include_compliance: bool) -> List[Dict[str, Any]]:
    """Generate security analysis data from Microsoft 365 APIs"""
    
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
            '24hours': timedelta(hours=24),
            '7days': timedelta(days=7),
            '30days': timedelta(days=30),
            '90days': timedelta(days=90)
        }
        start_time = end_time - time_deltas[time_period]
        
        # Get security data
        output.output_progress("セキュリティインシデントを取得中...")
        
        # Get security incidents
        security_incidents = await graph_client.get_security_incidents(
            start_time.strftime('%Y-%m-%dT%H:%M:%S'),
            end_time.strftime('%Y-%m-%dT%H:%M:%S')
        )
        
        # Get risky users
        risky_users = await graph_client.get_risky_users()
        
        # Get threat intelligence
        threat_indicators = await graph_client.get_threat_indicators()
        
        # Get compliance data if requested
        compliance_data = {}
        if include_compliance:
            compliance_data = await graph_client.get_compliance_status()
        
        report_data = []
        
        # Process security incidents
        for incident in security_incidents:
            incident_type = incident.get('category', '不明')
            incident_severity = incident.get('severity', 'low').lower()
            
            # Filter by threat type
            if threat_type != 'all':
                type_mapping = {
                    'malware': 'malware',
                    'phishing': 'phishing',
                    'suspicious-login': 'suspiciousLogin',
                    'data-leak': 'dataLeak'
                }
                if incident_type != type_mapping.get(threat_type):
                    continue
            
            # Filter by severity
            if severity != 'all' and incident_severity != severity:
                continue
            
            affected_users = incident.get('affectedUsers', [])
            affected_count = len(affected_users)
            
            # Determine risk level
            risk_level = "低"
            if incident_severity == 'critical':
                risk_level = "🚨 重大"
            elif incident_severity == 'high':
                risk_level = "🔴 高"
            elif incident_severity == 'medium':
                risk_level = "🟡 中"
            
            record = {
                'インシデントID': incident.get('id', '不明'),
                '脅威タイプ': incident_type,
                '重要度': incident_severity.upper(),
                'リスクレベル': risk_level,
                '影響ユーザー数': affected_count,
                '検出時刻': incident.get('createdDateTime', '不明'),
                '状態': incident.get('status', '不明'),
                '説明': incident.get('description', '説明なし')[:100] + '...' if len(incident.get('description', '')) > 100 else incident.get('description', '説明なし'),
                '対応状況': incident.get('assignedTo', '未対応') or '未対応',
                '分析期間': time_period
            }
            
            if include_compliance:
                compliance_impact = incident.get('complianceImpact', '不明')
                record['コンプライアンス影響'] = compliance_impact
            
            report_data.append(record)
        
        # Process risky users
        for user in risky_users:
            user_risk = user.get('riskLevel', 'low').lower()
            
            # Filter by severity (map risk level to severity)
            severity_mapping = {
                'critical': 'high',  # Map critical to high for risky users
                'high': 'high',
                'medium': 'medium',
                'low': 'low'
            }
            if severity != 'all' and severity_mapping.get(severity, severity) != user_risk:
                continue
            
            # Filter by threat type (risky users are considered suspicious-login)
            if threat_type not in ['all', 'suspicious-login']:
                continue
            
            risk_level = "低"
            if user_risk == 'high':
                risk_level = "🔴 高"
            elif user_risk == 'medium':
                risk_level = "🟡 中"
            
            record = {
                'インシデントID': f"RISK-{user.get('id', 'unknown')[:8]}",
                '脅威タイプ': 'suspiciousLogin',
                '重要度': user_risk.upper(),
                'リスクレベル': risk_level,
                'ユーザー名': user.get('userDisplayName', '不明'),
                'ユーザーUPN': user.get('userPrincipalName', '不明'),
                'リスク理由': ', '.join(user.get('riskReasons', [])) or '不明',
                '最終検出': user.get('riskLastUpdatedDateTime', '不明'),
                '状態': user.get('riskState', '不明'),
                '対応状況': '調査中',
                '分析期間': time_period
            }
            
            report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_security_data(
            threat_type, severity, time_period, include_compliance
        )

def _generate_sample_security_data(threat_type: str, severity: str,
                                 time_period: str, include_compliance: bool) -> List[Dict[str, Any]]:
    """Generate sample security analysis data"""
    
    import random
    
    threat_types = ['malware', 'phishing', 'suspiciousLogin', 'dataLeak', 'anomalyDetection']
    severities = ['critical', 'high', 'medium', 'low']
    
    sample_incidents = [
        {
            'id': 'INC-001',
            'type': 'phishing',
            'severity': 'high',
            'affected_users': 3,
            'description': '疑わしいメールアクセスパターンが検出されました',
            'status': '調査中'
        },
        {
            'id': 'INC-002',
            'type': 'suspiciousLogin',
            'severity': 'medium',
            'affected_users': 1,
            'description': '通常と異なる地理的位置からのサインイン',
            'status': '対応済み'
        },
        {
            'id': 'INC-003',
            'type': 'malware',
            'severity': 'critical',
            'affected_users': 1,
            'description': '悪意のあるファイルがOneDriveで検出されました',
            'status': '隔離済み'
        },
        {
            'id': 'INC-004',
            'type': 'dataLeak',
            'severity': 'high',
            'affected_users': 2,
            'description': '機密文書の外部共有が検出されました',
            'status': '調査中'
        },
        {
            'id': 'INC-005',
            'type': 'anomalyDetection',
            'severity': 'low',
            'affected_users': 1,
            'description': '通常と異なるファイルアクセスパターン',
            'status': '監視中'
        }
    ]
    
    risky_users = [
        {
            'id': 'USER-001',
            'name': '田中 太郎',
            'upn': 'tanaka@contoso.com',
            'risk_level': 'medium',
            'reasons': ['異常なサインインパターン', '複数デバイスからの同時アクセス']
        },
        {
            'id': 'USER-002',
            'name': '佐藤 花子',
            'upn': 'sato@contoso.com',
            'risk_level': 'high',
            'reasons': ['不可能な移動', 'TORネットワークの使用']
        }
    ]
    
    report_data = []
    
    # Process incidents
    for incident in sample_incidents:
        inc_type = incident['type']
        inc_severity = incident['severity']
        
        # Filter by threat type
        if threat_type != 'all':
            type_mapping = {
                'malware': 'malware',
                'phishing': 'phishing',
                'suspicious-login': 'suspiciousLogin',
                'data-leak': 'dataLeak'
            }
            if inc_type != type_mapping.get(threat_type):
                continue
        
        # Filter by severity
        if severity != 'all' and inc_severity != severity:
            continue
        
        # Determine risk level
        risk_level = "低"
        if inc_severity == 'critical':
            risk_level = "🚨 重大"
        elif inc_severity == 'high':
            risk_level = "🔴 高"
        elif inc_severity == 'medium':
            risk_level = "🟡 中"
        
        # Generate timestamp within the time period
        hours_ago = random.randint(1, {'24hours': 24, '7days': 168, '30days': 720, '90days': 2160}[time_period])
        incident_time = datetime.now() - timedelta(hours=hours_ago)
        
        record = {
            'インシデントID': incident['id'],
            '脅威タイプ': inc_type,
            '重要度': inc_severity.upper(),
            'リスクレベル': risk_level,
            '影響ユーザー数': incident['affected_users'],
            '検出時刻': incident_time.strftime('%Y-%m-%d %H:%M:%S'),
            '状態': incident['status'],
            '説明': incident['description'],
            '対応状況': incident['status'],
            '分析期間': time_period
        }
        
        if include_compliance:
            compliance_levels = ['影響なし', '軽微', '中程度', '重大']
            record['コンプライアンス影響'] = random.choice(compliance_levels)
        
        report_data.append(record)
    
    # Process risky users
    for user in risky_users:
        user_risk = user['risk_level']
        
        # Filter by severity
        severity_mapping = {
            'critical': 'high',
            'high': 'high',
            'medium': 'medium',
            'low': 'low'
        }
        if severity != 'all' and severity_mapping.get(severity, severity) != user_risk:
            continue
        
        # Filter by threat type
        if threat_type not in ['all', 'suspicious-login']:
            continue
        
        risk_level = "低"
        if user_risk == 'high':
            risk_level = "🔴 高"
        elif user_risk == 'medium':
            risk_level = "🟡 中"
        
        # Generate timestamp
        hours_ago = random.randint(1, {'24hours': 24, '7days': 168, '30days': 720, '90days': 2160}[time_period])
        detection_time = datetime.now() - timedelta(hours=hours_ago)
        
        record = {
            'インシデントID': f"RISK-{user['id']}",
            '脅威タイプ': 'suspiciousLogin',
            '重要度': user_risk.upper(),
            'リスクレベル': risk_level,
            'ユーザー名': user['name'],
            'ユーザーUPN': user['upn'],
            'リスク理由': ', '.join(user['reasons']),
            '最終検出': detection_time.strftime('%Y-%m-%d %H:%M:%S'),
            '状態': 'アクティブ',
            '対応状況': '調査中',
            '分析期間': time_period
        }
        
        report_data.append(record)
    
    return report_data

def _show_security_summary(report_data: List[Dict[str, Any]], output: OutputFormatter,
                         threat_type: str, severity: str, time_period: str):
    """Show security analysis summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_incidents = len(report_data)
    critical_incidents = len([r for r in report_data if '🚨' in r.get('リスクレベル', '')])
    high_risk_incidents = len([r for r in report_data if '🔴' in r.get('リスクレベル', '')])
    medium_risk_incidents = len([r for r in report_data if '🟡' in r.get('リスクレベル', '')])
    low_risk_incidents = total_incidents - critical_incidents - high_risk_incidents - medium_risk_incidents
    
    # Threat type breakdown
    threat_stats = {}
    for record in report_data:
        threat = record.get('脅威タイプ', '不明')
        if threat not in threat_stats:
            threat_stats[threat] = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}
        
        risk_level = record.get('リスクレベル', '低')
        if '🚨' in risk_level:
            threat_stats[threat]['critical'] += 1
        elif '🔴' in risk_level:
            threat_stats[threat]['high'] += 1
        elif '🟡' in risk_level:
            threat_stats[threat]['medium'] += 1
        else:
            threat_stats[threat]['low'] += 1
    
    # Status breakdown
    status_stats = {}
    for record in report_data:
        status = record.get('状態', '不明')
        status_stats[status] = status_stats.get(status, 0) + 1
    
    # Calculate security score
    security_score = 100
    if total_incidents > 0:
        security_score = max(0, 100 - (critical_incidents * 15) - (high_risk_incidents * 8) - (medium_risk_incidents * 3) - (low_risk_incidents * 1))
    
    click.echo("\n🔒 セキュリティ分析サマリー")
    click.echo("=" * 40)
    click.echo(f"📅 分析期間: {time_period}")
    click.echo(f"🎯 脅威フィルター: {threat_type.upper()}")
    click.echo(f"📊 重要度フィルター: {severity.upper()}")
    click.echo(f"📋 総インシデント数: {total_incidents}")
    click.echo(f"🚨 重大: {critical_incidents}")
    click.echo(f"🔴 高リスク: {high_risk_incidents}")
    click.echo(f"🟡 中リスク: {medium_risk_incidents}")
    click.echo(f"🟢 低リスク: {low_risk_incidents}")
    click.echo(f"🛡️ セキュリティスコア: {security_score:.0f}/100")
    
    # Threat type breakdown
    if threat_stats:
        click.echo("\n🎯 脅威タイプ別内訳:")
        for threat, stats in threat_stats.items():
            total_threat = stats['critical'] + stats['high'] + stats['medium'] + stats['low']
            click.echo(f"  🔍 {threat}: 重大{stats['critical']}, 高{stats['high']}, 中{stats['medium']}, 低{stats['low']} (計{total_threat})")
    
    # Status breakdown
    if status_stats:
        click.echo("\n📊 対応状況別:")
        for status, count in status_stats.items():
            percentage = (count / total_incidents) * 100 if total_incidents > 0 else 0
            click.echo(f"  📌 {status}: {count} ({percentage:.1f}%)")
    
    # Security assessment
    click.echo("\n🛡️ セキュリティ評価:")
    if security_score >= 90:
        click.echo("  🎉 優秀: セキュリティ体制は良好です")
    elif security_score >= 75:
        click.echo("  🔶 良好: 軽微なセキュリティ問題がありますが、管理可能です")
    elif security_score >= 50:
        click.echo("  ⚠️ 注意: セキュリティ強化が必要です")
    else:
        click.echo("  🚨 危険: 即座のセキュリティ対応が必要です")
    
    # Risk trends and recommendations
    click.echo("\n💡 セキュリティ推奨事項:")
    if critical_incidents > 0:
        click.echo(f"  • {critical_incidents} 件の重大インシデントへの即座の対応")
    if high_risk_incidents > 0:
        click.echo(f"  • {high_risk_incidents} 件の高リスクインシデントの優先的対応")
    
    # Threat-specific recommendations
    for threat, stats in threat_stats.items():
        if stats['critical'] > 0 or stats['high'] > 0:
            if threat == 'phishing':
                click.echo("  • フィッシング対策: ユーザー教育とメールフィルタリング強化")
            elif threat == 'malware':
                click.echo("  • マルウェア対策: エンドポイント保護とファイルスキャンの強化")
            elif threat == 'suspiciousLogin':
                click.echo("  • ログイン監視: 多要素認証と条件付きアクセスの強化")
            elif threat == 'dataLeak':
                click.echo("  • データ保護: DLP設定と外部共有ポリシーの見直し")
    
    if total_incidents == 0:
        click.echo("  • セキュリティ状況は良好です。継続的な監視を維持してください")
    
    click.echo()

# Command alias for PowerShell compatibility
security_analysis = security_command