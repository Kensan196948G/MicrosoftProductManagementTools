# Microsoft 365 Management Tools - Performance Analysis Command
# パフォーマンス監視・会議品質分析レポート - PowerShell Enhanced CLI Compatible

import click
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

from src.cli.core.context import CLIContext
from src.cli.core.output import OutputFormatter

@click.command()
@click.option('--metric-type', type=click.Choice(['all', 'response-time', 'availability', 'meetings', 'email-flow']),
              default='all', help='監視メトリックタイプ')
@click.option('--time-period', type=click.Choice(['1hour', '24hours', '7days', '30days']),
              default='24hours', help='監視期間')
@click.option('--include-sla-analysis', is_flag=True, help='SLA分析を含める')
@click.option('--threshold-alerts', is_flag=True, help='閾値超過アラートのみ')
@click.pass_context
def performance_command(ctx, metric_type, time_period, include_sla_analysis, threshold_alerts):
    """パフォーマンス監視・会議品質分析レポート生成
    
    PowerShell Enhanced CLI互換: pwsh -File CliApp_Enhanced.ps1 performance
    
    Microsoft 365サービスのパフォーマンス、応答時間、会議品質を分析します。
    """
    
    cli_context: CLIContext = ctx.obj
    
    asyncio.run(execute_performance_analysis(
        cli_context, metric_type, time_period, include_sla_analysis, threshold_alerts
    ))

async def execute_performance_analysis(context: CLIContext,
                                     metric_type: str = 'all',
                                     time_period: str = '24hours',
                                     include_sla_analysis: bool = False,
                                     threshold_alerts: bool = False):
    """Execute performance analysis report"""
    
    output = OutputFormatter(context)
    
    try:
        output.output_progress("パフォーマンス分析レポート生成を開始しています...")
        
        if context.dry_run:
            report_data = _generate_sample_performance_data(
                metric_type, time_period, include_sla_analysis, threshold_alerts
            )
        else:
            report_data = await _generate_performance_analysis_data(
                context, metric_type, time_period, include_sla_analysis, threshold_alerts
            )
        
        if not report_data:
            output.output_warning("パフォーマンスデータが見つかりませんでした")
            return
        
        output.output_success(f"パフォーマンス分析レポートを生成しました ({len(report_data)} 件)")
        
        await output.output_results(
            data=report_data,
            report_type="パフォーマンス分析レポート",
            filename_prefix="performance_analysis_report"
        )
        
        _show_performance_summary(report_data, output, metric_type, time_period)
        
    except Exception as e:
        output.output_error(f"パフォーマンス分析レポート生成に失敗しました: {str(e)}")
        if context.verbose:
            import traceback
            click.echo(traceback.format_exc(), err=True)

async def _generate_performance_analysis_data(context: CLIContext,
                                            metric_type: str,
                                            time_period: str,
                                            include_sla_analysis: bool,
                                            threshold_alerts: bool) -> List[Dict[str, Any]]:
    """Generate performance analysis data from Microsoft 365 APIs"""
    
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
        
        # Get performance data
        output.output_progress("パフォーマンスメトリクスを取得中...")
        
        # Get service health data
        service_health = await graph_client.get_service_health_status()
        
        # Get Teams meeting quality data
        meeting_quality = await graph_client.get_teams_meeting_quality(
            start_time.strftime('%Y-%m-%dT%H:%M:%S'),
            end_time.strftime('%Y-%m-%dT%H:%M:%S')
        )
        
        # Get email flow performance
        email_performance = await graph_client.get_exchange_performance_metrics(
            start_time.strftime('%Y-%m-%dT%H:%M:%S'),
            end_time.strftime('%Y-%m-%dT%H:%M:%S')
        )
        
        report_data = []
        
        # Process service health metrics
        if metric_type in ['all', 'availability']:
            for service, health_data in service_health.items():
                availability = health_data.get('availability', 0.0)
                response_time = health_data.get('responseTime', 0.0)
                incident_count = health_data.get('incidentCount', 0)
                
                # Filter by threshold if requested
                if threshold_alerts:
                    if availability >= 99.0 and response_time <= 2000:  # Normal thresholds
                        continue
                
                status = "正常"
                if availability < 95.0:
                    status = "🚨 重大"
                elif availability < 99.0:
                    status = "⚠️ 注意"
                elif response_time > 2000:
                    status = "⚠️ 遅延"
                
                record = {
                    'メトリックタイプ': 'サービス可用性',
                    'サービス名': service,
                    '監視期間': time_period,
                    '可用性': f"{availability:.2f}%",
                    '平均応答時間': f"{response_time:.0f}ms",
                    'インシデント数': incident_count,
                    'ステータス': status,
                    '測定時刻': end_time.strftime('%Y-%m-%d %H:%M:%S')
                }
                
                if include_sla_analysis:
                    sla_target = 99.9
                    sla_compliance = "達成" if availability >= sla_target else "未達成"
                    record['SLA目標'] = f"{sla_target}%"
                    record['SLA達成'] = sla_compliance
                
                report_data.append(record)
        
        # Process Teams meeting quality
        if metric_type in ['all', 'meetings']:
            for meeting_data in meeting_quality:
                audio_quality = meeting_data.get('audioQuality', 0.0)
                video_quality = meeting_data.get('videoQuality', 0.0)
                network_quality = meeting_data.get('networkQuality', 0.0)
                participant_count = meeting_data.get('participantCount', 0)
                
                # Calculate overall quality score
                overall_quality = (audio_quality + video_quality + network_quality) / 3
                
                # Filter by threshold if requested
                if threshold_alerts and overall_quality >= 3.5:  # Good quality threshold
                    continue
                
                quality_status = "優秀"
                if overall_quality < 2.0:
                    quality_status = "🚨 不良"
                elif overall_quality < 3.0:
                    quality_status = "⚠️ 普通"
                elif overall_quality < 4.0:
                    quality_status = "🔶 良好"
                
                record = {
                    'メトリックタイプ': 'Teams会議品質',
                    'サービス名': 'Microsoft Teams',
                    '監視期間': time_period,
                    '音声品質スコア': f"{audio_quality:.1f}/5.0",
                    '映像品質スコア': f"{video_quality:.1f}/5.0",
                    'ネットワーク品質': f"{network_quality:.1f}/5.0",
                    '総合品質': f"{overall_quality:.1f}/5.0",
                    '参加者数': participant_count,
                    'ステータス': quality_status,
                    '測定時刻': meeting_data.get('timestamp', end_time.strftime('%Y-%m-%d %H:%M:%S'))
                }
                
                report_data.append(record)
        
        # Process email flow performance
        if metric_type in ['all', 'email-flow']:
            avg_delivery_time = email_performance.get('avgDeliveryTime', 0.0)
            queue_length = email_performance.get('queueLength', 0)
            throughput = email_performance.get('throughput', 0.0)
            error_rate = email_performance.get('errorRate', 0.0)
            
            # Filter by threshold if requested
            if threshold_alerts and avg_delivery_time <= 30 and error_rate <= 0.1:  # Normal thresholds
                pass
            else:
                flow_status = "正常"
                if avg_delivery_time > 300:  # 5 minutes
                    flow_status = "🚨 遅延深刻"
                elif avg_delivery_time > 60:  # 1 minute
                    flow_status = "⚠️ 遅延"
                elif error_rate > 0.05:  # 5% error rate
                    flow_status = "⚠️ エラー多発"
                
                record = {
                    'メトリックタイプ': 'Exchange メールフロー',
                    'サービス名': 'Exchange Online',
                    '監視期間': time_period,
                    '平均配信時間': f"{avg_delivery_time:.1f}秒",
                    'キュー長': queue_length,
                    'スループット': f"{throughput:.1f}/分",
                    'エラー率': f"{error_rate:.3f}%",
                    'ステータス': flow_status,
                    '測定時刻': end_time.strftime('%Y-%m-%d %H:%M:%S')
                }
                
                report_data.append(record)
        
        return report_data
        
    except Exception as e:
        output = OutputFormatter(context)
        output.output_warning(f"APIアクセスに失敗しました、サンプルデータを使用します: {e}")
        return _generate_sample_performance_data(
            metric_type, time_period, include_sla_analysis, threshold_alerts
        )

def _generate_sample_performance_data(metric_type: str, time_period: str,
                                    include_sla_analysis: bool, threshold_alerts: bool) -> List[Dict[str, Any]]:
    """Generate sample performance analysis data"""
    
    import random
    
    services = ['Exchange Online', 'Microsoft Teams', 'OneDrive', 'SharePoint Online', 'Office Online']
    report_data = []
    
    # Service availability metrics
    if metric_type in ['all', 'availability']:
        for service in services:
            # Generate realistic availability and response times
            availability = random.uniform(98.5, 99.99)
            response_time = random.uniform(150, 3000)
            incident_count = random.randint(0, 3)
            
            # Filter by threshold if requested
            if threshold_alerts and availability >= 99.0 and response_time <= 2000:
                continue
            
            status = "正常"
            if availability < 95.0:
                status = "🚨 重大"
            elif availability < 99.0:
                status = "⚠️ 注意"
            elif response_time > 2000:
                status = "⚠️ 遅延"
            
            record = {
                'メトリックタイプ': 'サービス可用性',
                'サービス名': service,
                '監視期間': time_period,
                '可用性': f"{availability:.2f}%",
                '平均応答時間': f"{response_time:.0f}ms",
                'インシデント数': incident_count,
                'ステータス': status,
                '測定時刻': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
            if include_sla_analysis:
                sla_target = 99.9
                sla_compliance = "達成" if availability >= sla_target else "未達成"
                record['SLA目標'] = f"{sla_target}%"
                record['SLA達成'] = sla_compliance
            
            report_data.append(record)
    
    # Teams meeting quality metrics
    if metric_type in ['all', 'meetings']:
        for i in range(5):  # Sample meetings
            audio_quality = random.uniform(2.0, 5.0)
            video_quality = random.uniform(2.0, 5.0)
            network_quality = random.uniform(2.5, 5.0)
            participant_count = random.randint(2, 25)
            
            overall_quality = (audio_quality + video_quality + network_quality) / 3
            
            # Filter by threshold if requested
            if threshold_alerts and overall_quality >= 3.5:
                continue
            
            quality_status = "優秀"
            if overall_quality < 2.0:
                quality_status = "🚨 不良"
            elif overall_quality < 3.0:
                quality_status = "⚠️ 普通"
            elif overall_quality < 4.0:
                quality_status = "🔶 良好"
            
            timestamp = datetime.now() - timedelta(minutes=random.randint(1, 1440))
            
            record = {
                'メトリックタイプ': 'Teams会議品質',
                'サービス名': 'Microsoft Teams',
                '監視期間': time_period,
                '音声品質スコア': f"{audio_quality:.1f}/5.0",
                '映像品質スコア': f"{video_quality:.1f}/5.0",
                'ネットワーク品質': f"{network_quality:.1f}/5.0",
                '総合品質': f"{overall_quality:.1f}/5.0",
                '参加者数': participant_count,
                'ステータス': quality_status,
                '測定時刻': timestamp.strftime('%Y-%m-%d %H:%M:%S')
            }
            
            report_data.append(record)
    
    # Email flow performance
    if metric_type in ['all', 'email-flow']:
        avg_delivery_time = random.uniform(5, 180)
        queue_length = random.randint(0, 150)
        throughput = random.uniform(50, 500)
        error_rate = random.uniform(0.001, 0.08)
        
        # Filter by threshold if requested
        if not (threshold_alerts and avg_delivery_time <= 30 and error_rate <= 0.1):
            flow_status = "正常"
            if avg_delivery_time > 300:
                flow_status = "🚨 遅延深刻"
            elif avg_delivery_time > 60:
                flow_status = "⚠️ 遅延"
            elif error_rate > 0.05:
                flow_status = "⚠️ エラー多発"
            
            record = {
                'メトリックタイプ': 'Exchange メールフロー',
                'サービス名': 'Exchange Online',
                '監視期間': time_period,
                '平均配信時間': f"{avg_delivery_time:.1f}秒",
                'キュー長': queue_length,
                'スループット': f"{throughput:.1f}/分",
                'エラー率': f"{error_rate:.3f}%",
                'ステータス': flow_status,
                '測定時刻': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
            report_data.append(record)
    
    return report_data

def _show_performance_summary(report_data: List[Dict[str, Any]], output: OutputFormatter,
                            metric_type: str, time_period: str):
    """Show performance analysis summary"""
    
    if not report_data:
        return
    
    # Summary statistics
    total_metrics = len(report_data)
    critical_issues = len([r for r in report_data if '🚨' in r.get('ステータス', '')])
    warning_issues = len([r for r in report_data if '⚠️' in r.get('ステータス', '')])
    normal_status = total_metrics - critical_issues - warning_issues
    
    # Service breakdown
    service_stats = {}
    for record in report_data:
        service = record.get('サービス名', '不明')
        if service not in service_stats:
            service_stats[service] = {'critical': 0, 'warning': 0, 'normal': 0}
        
        status = record.get('ステータス', '正常')
        if '🚨' in status:
            service_stats[service]['critical'] += 1
        elif '⚠️' in status:
            service_stats[service]['warning'] += 1
        else:
            service_stats[service]['normal'] += 1
    
    # Metric type breakdown
    metric_stats = {}
    for record in report_data:
        metric = record.get('メトリックタイプ', '不明')
        if metric not in metric_stats:
            metric_stats[metric] = 0
        metric_stats[metric] += 1
    
    overall_health = (normal_status / total_metrics) * 100 if total_metrics > 0 else 0
    
    click.echo("\n📊 パフォーマンス分析サマリー")
    click.echo("=" * 40)
    click.echo(f"📅 監視期間: {time_period}")
    click.echo(f"🎯 対象メトリック: {metric_type.upper()}")
    click.echo(f"📋 総メトリック数: {total_metrics}")
    click.echo(f"🚨 重大問題: {critical_issues}")
    click.echo(f"⚠️ 警告: {warning_issues}")
    click.echo(f"✅ 正常: {normal_status}")
    click.echo(f"📈 システム健全性: {overall_health:.1f}%")
    
    # Service-specific statistics
    if service_stats:
        click.echo("\n📦 サービス別ステータス:")
        for service, stats in service_stats.items():
            total_service = stats['critical'] + stats['warning'] + stats['normal']
            service_health = (stats['normal'] / total_service) * 100 if total_service > 0 else 0
            click.echo(f"  📧 {service}: 重大{stats['critical']}, 警告{stats['warning']}, 正常{stats['normal']} ({service_health:.1f}%)")
    
    # Metric type statistics
    if metric_stats:
        click.echo("\n📊 メトリックタイプ別:")
        for metric, count in metric_stats.items():
            click.echo(f"  📈 {metric}: {count}件")
    
    # Performance assessment
    click.echo("\n🎯 パフォーマンス評価:")
    if overall_health >= 95:
        click.echo("  🎉 優秀: システムは正常に動作しています")
    elif overall_health >= 80:
        click.echo("  🔶 良好: 軽微な問題がありますが、使用に支障はありません")
    elif overall_health >= 60:
        click.echo("  ⚠️ 注意: いくつかの問題があります。監視を強化してください")
    else:
        click.echo("  🚨 重大: 深刻な問題があります。即座の対応が必要です")
    
    # Recommendations
    click.echo("\n💡 改善提案:")
    if critical_issues > 0:
        click.echo(f"  • {critical_issues} 件の重大問題への即座の対応が必要")
    if warning_issues > 0:
        click.echo(f"  • {warning_issues} 件の警告の監視強化を推奨")
    if overall_health < 90:
        click.echo("  • システム最適化とキャパシティプランニングの見直しを検討")
    
    click.echo()

# Command alias for PowerShell compatibility
performance_analysis = performance_command