"""
OneDrive for Business services implementation.
Python equivalent of PowerShell OneDrive/SharePoint management modules.
Provides high-level OneDrive for Business management services.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Union
from dataclasses import dataclass
import asyncio
from concurrent.futures import ThreadPoolExecutor

from .client import OneDriveClient, OneDriveResult
from src.core.config import Config
from src.api.graph.client import GraphClient


@dataclass
class OneDriveServiceResponse:
    """Standard response format for OneDrive services."""
    success: bool
    data: Any
    error_message: Optional[str] = None
    source: str = "OneDrive Service"
    metadata: Optional[Dict[str, Any]] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            'success': self.success,
            'data': self.data,
            'error_message': self.error_message,
            'source': self.source,
            'metadata': self.metadata or {}
        }


class OneDriveService:
    """
    OneDrive for Business management service.
    Python equivalent of PowerShell OneDrive/SharePoint management modules.
    
    Provides high-level OneDrive for Business operations:
    - Storage usage analysis and monitoring
    - Sharing and permissions management
    - Sync error tracking and resolution
    - External sharing security analysis
    - Compliance and governance reporting
    """
    
    def __init__(self, config: Config, graph_client: Optional[GraphClient] = None):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.onedrive_client = OneDriveClient(config, graph_client)
        self.executor = ThreadPoolExecutor(max_workers=4)
        
        # Initialize client
        try:
            self.onedrive_client.initialize()
        except Exception as e:
            self.logger.warning(f"OneDrive client initialization failed: {e}")
    
    def get_storage_usage_analysis(self, 
                                 include_details: bool = True,
                                 limit: int = 1000) -> OneDriveServiceResponse:
        """
        Get comprehensive OneDrive storage usage analysis.
        Python equivalent of PowerShell Get-SPOSite + storage analytics.
        """
        try:
            self.logger.info(f"Getting OneDrive storage analysis (limit: {limit}, details: {include_details})")
            
            # Get storage usage data
            storage_result = self.onedrive_client.get_onedrive_storage_data(limit=limit)
            
            if not storage_result.success:
                return OneDriveServiceResponse(
                    success=False,
                    data=None,
                    error_message=storage_result.error_message,
                    source=storage_result.source
                )
            
            storage_data = storage_result.data
            
            # Calculate comprehensive analytics
            total_users = len(storage_data)
            total_used_gb = sum(user.get('使用容量(GB)', 0) for user in storage_data)
            total_quota_gb = sum(user.get('割り当て容量(GB)', 0) for user in storage_data)
            
            # Usage distribution analysis
            usage_categories = self._categorize_usage(storage_data)
            
            # Identify top users by storage
            top_users = sorted(storage_data, key=lambda x: x.get('使用容量(GB)', 0), reverse=True)[:10]
            
            # Calculate efficiency metrics
            avg_usage_percentage = (total_used_gb / total_quota_gb * 100) if total_quota_gb > 0 else 0
            users_over_80_percent = sum(1 for user in storage_data 
                                      if user.get('使用率(%)', 0) > 80)
            
            # Generate insights
            insights = self._generate_storage_insights(storage_data, usage_categories)
            
            metadata = {
                'analysis_type': 'storage_usage',
                'total_users': total_users,
                'total_used_gb': round(total_used_gb, 2),
                'total_quota_gb': round(total_quota_gb, 2),
                'average_usage_percentage': round(avg_usage_percentage, 2),
                'users_over_80_percent': users_over_80_percent,
                'usage_categories': usage_categories,
                'top_users_count': len(top_users),
                'include_details': include_details,
                'data_source': storage_result.source,
                'insights': insights,
                'generated_at': datetime.now().isoformat()
            }
            
            # Add detailed analysis if requested
            if include_details:
                # Add trend analysis
                for user in storage_data:
                    user['使用率カテゴリ'] = self._get_usage_category(user.get('使用率(%)', 0))
                    user['リスクレベル'] = self._assess_storage_risk(user)
                    user['推奨アクション'] = self._recommend_storage_action(user)
            
            self.logger.info(f"Storage analysis complete: {total_users} users, {total_used_gb:.2f}GB used")
            
            return OneDriveServiceResponse(
                success=True,
                data=storage_data,
                source=storage_result.source,
                metadata=metadata
            )
            
        except Exception as e:
            return self._handle_error(e, "storage usage analysis")
    
    def get_sharing_permissions_analysis(self, 
                                       include_external: bool = True,
                                       limit: int = 1000) -> OneDriveServiceResponse:
        """
        Get comprehensive sharing and permissions analysis.
        Python equivalent of PowerShell sharing policy analysis.
        """
        try:
            self.logger.info(f"Getting OneDrive sharing analysis (limit: {limit}, external: {include_external})")
            
            # Get sharing data
            sharing_result = self.onedrive_client.get_onedrive_sharing_data(limit=limit)
            
            if not sharing_result.success:
                return OneDriveServiceResponse(
                    success=False,
                    data=None,
                    error_message=sharing_result.error_message,
                    source=sharing_result.source
                )
            
            sharing_data = sharing_result.data
            
            # Analyze sharing patterns
            total_shares = len(sharing_data)
            external_shares = sum(1 for share in sharing_data 
                                if share.get('外部共有', False))
            internal_shares = total_shares - external_shares
            
            # Permission level analysis
            permission_stats = self._analyze_permission_levels(sharing_data)
            
            # Security risk assessment
            high_risk_shares = sum(1 for share in sharing_data 
                                 if share.get('リスクレベル', '') == 'High')
            
            # Generate security recommendations
            security_recommendations = self._generate_security_recommendations(sharing_data)
            
            metadata = {
                'analysis_type': 'sharing_permissions',
                'total_shares': total_shares,
                'external_shares': external_shares,
                'internal_shares': internal_shares,
                'external_share_percentage': round((external_shares / total_shares * 100), 2) if total_shares > 0 else 0,
                'permission_statistics': permission_stats,
                'high_risk_shares': high_risk_shares,
                'include_external': include_external,
                'data_source': sharing_result.source,
                'security_recommendations': security_recommendations,
                'generated_at': datetime.now().isoformat()
            }
            
            # Add detailed analysis for each share
            for share in sharing_data:
                share['セキュリティスコア'] = self._calculate_security_score(share)
                share['推奨アクション'] = self._recommend_sharing_action(share)
                share['コンプライアンス状態'] = self._assess_compliance_status(share)
            
            self.logger.info(f"Sharing analysis complete: {total_shares} shares, {external_shares} external")
            
            return OneDriveServiceResponse(
                success=True,
                data=sharing_data,
                source=sharing_result.source,
                metadata=metadata
            )
            
        except Exception as e:
            return self._handle_error(e, "sharing permissions analysis")
    
    def get_sync_error_analysis(self, 
                              days: int = 30,
                              include_resolved: bool = False) -> OneDriveServiceResponse:
        """
        Get OneDrive sync error analysis and troubleshooting data.
        Python equivalent of PowerShell sync error diagnostics.
        """
        try:
            self.logger.info(f"Getting OneDrive sync error analysis (days: {days}, resolved: {include_resolved})")
            
            # Get sync error data
            sync_result = self.onedrive_client.get_onedrive_sync_errors(days=days)
            
            if not sync_result.success:
                return OneDriveServiceResponse(
                    success=False,
                    data=None,
                    error_message=sync_result.error_message,
                    source=sync_result.source
                )
            
            sync_data = sync_result.data
            
            # Filter data based on parameters
            if not include_resolved:
                sync_data = [error for error in sync_data 
                           if error.get('解決状態', '') != '解決済み']
            
            # Analyze error patterns
            total_errors = len(sync_data)
            error_categories = self._categorize_sync_errors(sync_data)
            
            # User impact analysis
            affected_users = len(set(error.get('ユーザー', '') for error in sync_data))
            
            # Resolution tracking
            resolved_errors = sum(1 for error in sync_data 
                                if error.get('解決状態', '') == '解決済み')
            resolution_rate = (resolved_errors / total_errors * 100) if total_errors > 0 else 0
            
            # Generate troubleshooting recommendations
            troubleshooting_guide = self._generate_troubleshooting_guide(error_categories)
            
            metadata = {
                'analysis_type': 'sync_errors',
                'analysis_period_days': days,
                'total_errors': total_errors,
                'affected_users': affected_users,
                'resolved_errors': resolved_errors,
                'resolution_rate_percent': round(resolution_rate, 2),
                'error_categories': error_categories,
                'include_resolved': include_resolved,
                'data_source': sync_result.source,
                'troubleshooting_guide': troubleshooting_guide,
                'generated_at': datetime.now().isoformat()
            }
            
            # Add resolution recommendations for each error
            for error in sync_data:
                error['推奨解決策'] = self._recommend_error_resolution(error)
                error['優先度'] = self._assess_error_priority(error)
                error['推定解決時間'] = self._estimate_resolution_time(error)
            
            self.logger.info(f"Sync error analysis complete: {total_errors} errors, {affected_users} affected users")
            
            return OneDriveServiceResponse(
                success=True,
                data=sync_data,
                source=sync_result.source,
                metadata=metadata
            )
            
        except Exception as e:
            return self._handle_error(e, "sync error analysis")
    
    def get_external_sharing_security_analysis(self) -> OneDriveServiceResponse:
        """
        Get comprehensive external sharing security analysis.
        Python equivalent of PowerShell external sharing security audit.
        """
        try:
            self.logger.info("Getting OneDrive external sharing security analysis")
            
            # Get external sharing data
            external_result = self.onedrive_client.get_external_sharing_analysis()
            
            if not external_result.success:
                return OneDriveServiceResponse(
                    success=False,
                    data=None,
                    error_message=external_result.error_message,
                    source=external_result.source
                )
            
            external_data = external_result.data
            
            # Security analysis
            total_external_shares = len(external_data)
            high_risk_shares = sum(1 for share in external_data 
                                 if share.get('リスクレベル', '') == 'High')
            
            # Domain analysis
            external_domains = set()
            for share in external_data:
                domain = share.get('外部ドメイン', '')
                if domain:
                    external_domains.add(domain)
            
            # Permission analysis
            anonymous_shares = sum(1 for share in external_data 
                                 if share.get('匿名アクセス', False))
            
            # Generate security recommendations
            security_recommendations = self._generate_external_security_recommendations(external_data)
            
            # Compliance assessment
            compliance_issues = self._assess_compliance_issues(external_data)
            
            metadata = {
                'analysis_type': 'external_sharing_security',
                'total_external_shares': total_external_shares,
                'high_risk_shares': high_risk_shares,
                'risk_percentage': round((high_risk_shares / total_external_shares * 100), 2) if total_external_shares > 0 else 0,
                'external_domains_count': len(external_domains),
                'external_domains': list(external_domains),
                'anonymous_shares': anonymous_shares,
                'data_source': external_result.source,
                'security_recommendations': security_recommendations,
                'compliance_issues': compliance_issues,
                'generated_at': datetime.now().isoformat()
            }
            
            # Add detailed security assessment for each share
            for share in external_data:
                share['セキュリティスコア'] = self._calculate_external_security_score(share)
                share['コンプライアンス状態'] = self._assess_external_compliance(share)
                share['推奨アクション'] = self._recommend_external_security_action(share)
            
            self.logger.info(f"External sharing security analysis complete: {total_external_shares} shares, {high_risk_shares} high-risk")
            
            return OneDriveServiceResponse(
                success=True,
                data=external_data,
                source=external_result.source,
                metadata=metadata
            )
            
        except Exception as e:
            return self._handle_error(e, "external sharing security analysis")
    
    def _categorize_usage(self, storage_data: List[Dict[str, Any]]) -> Dict[str, int]:
        """Categorize users by storage usage patterns."""
        categories = {
            'low_usage': 0,      # < 25%
            'medium_usage': 0,   # 25-75%
            'high_usage': 0,     # 75-90%
            'critical_usage': 0  # > 90%
        }
        
        for user in storage_data:
            usage_percent = user.get('使用率(%)', 0)
            if usage_percent < 25:
                categories['low_usage'] += 1
            elif usage_percent < 75:
                categories['medium_usage'] += 1
            elif usage_percent < 90:
                categories['high_usage'] += 1
            else:
                categories['critical_usage'] += 1
        
        return categories
    
    def _generate_storage_insights(self, storage_data: List[Dict[str, Any]], 
                                 categories: Dict[str, int]) -> List[str]:
        """Generate storage usage insights."""
        insights = []
        
        try:
            total_users = len(storage_data)
            
            # Usage distribution insights
            if categories['critical_usage'] > 0:
                insights.append(f"緊急: {categories['critical_usage']}名のユーザーが90%以上のストレージを使用しています")
            
            if categories['high_usage'] > total_users * 0.2:
                insights.append(f"注意: {categories['high_usage']}名のユーザーが75%以上のストレージを使用しています")
            
            if categories['low_usage'] > total_users * 0.5:
                insights.append(f"最適化機会: {categories['low_usage']}名のユーザーの使用率が25%未満です")
            
            # Capacity planning insights
            avg_usage = sum(user.get('使用率(%)', 0) for user in storage_data) / total_users
            if avg_usage < 30:
                insights.append(f"容量効率: 平均使用率{avg_usage:.1f}%で効率的な利用状況です")
            elif avg_usage > 70:
                insights.append(f"容量圧迫: 平均使用率{avg_usage:.1f}%で容量追加を検討してください")
            
            insights.append(f"分析完了: {total_users}名のユーザーのストレージ使用状況を分析しました")
            
        except Exception as e:
            insights.append(f"インサイト生成エラー: {str(e)}")
        
        return insights
    
    def _get_usage_category(self, usage_percent: float) -> str:
        """Get usage category based on percentage."""
        if usage_percent < 25:
            return "低使用"
        elif usage_percent < 75:
            return "標準使用"
        elif usage_percent < 90:
            return "高使用"
        else:
            return "危険使用"
    
    def _assess_storage_risk(self, user: Dict[str, Any]) -> str:
        """Assess storage risk level for a user."""
        usage_percent = user.get('使用率(%)', 0)
        
        if usage_percent > 95:
            return "Critical"
        elif usage_percent > 85:
            return "High"
        elif usage_percent > 75:
            return "Medium"
        else:
            return "Low"
    
    def _recommend_storage_action(self, user: Dict[str, Any]) -> str:
        """Recommend storage action for a user."""
        risk_level = self._assess_storage_risk(user)
        
        if risk_level == "Critical":
            return "即座に容量追加またはファイル整理が必要"
        elif risk_level == "High":
            return "容量追加またはアーカイブを検討"
        elif risk_level == "Medium":
            return "使用状況を監視し、必要に応じて対策を検討"
        else:
            return "現在のところ対策不要"
    
    def _analyze_permission_levels(self, sharing_data: List[Dict[str, Any]]) -> Dict[str, int]:
        """Analyze permission levels in sharing data."""
        permissions = {}
        
        for share in sharing_data:
            permission = share.get('権限レベル', 'Unknown')
            permissions[permission] = permissions.get(permission, 0) + 1
        
        return permissions
    
    def _generate_security_recommendations(self, sharing_data: List[Dict[str, Any]]) -> List[str]:
        """Generate security recommendations based on sharing data."""
        recommendations = []
        
        try:
            total_shares = len(sharing_data)
            external_shares = sum(1 for share in sharing_data if share.get('外部共有', False))
            
            if external_shares > total_shares * 0.3:
                recommendations.append("外部共有の比率が高いため、共有ポリシーの見直しを推奨します")
            
            edit_permissions = sum(1 for share in sharing_data 
                                 if share.get('権限レベル', '') == '編集')
            if edit_permissions > total_shares * 0.5:
                recommendations.append("編集権限の付与が多いため、権限レベルの見直しを推奨します")
            
            anonymous_shares = sum(1 for share in sharing_data 
                                 if share.get('匿名アクセス', False))
            if anonymous_shares > 0:
                recommendations.append(f"{anonymous_shares}件の匿名アクセスが設定されています。セキュリティリスクを確認してください")
            
            recommendations.append("定期的な共有権限の監査を実施してください")
            
        except Exception as e:
            recommendations.append(f"推奨事項生成エラー: {str(e)}")
        
        return recommendations
    
    def _calculate_security_score(self, share: Dict[str, Any]) -> int:
        """Calculate security score for a share (0-100)."""
        score = 100
        
        # Deduct points for risk factors
        if share.get('外部共有', False):
            score -= 30
        if share.get('匿名アクセス', False):
            score -= 40
        if share.get('権限レベル', '') == '編集':
            score -= 20
        if share.get('有効期限', '') == '無期限':
            score -= 10
        
        return max(0, score)
    
    def _recommend_sharing_action(self, share: Dict[str, Any]) -> str:
        """Recommend action for a share based on security assessment."""
        security_score = self._calculate_security_score(share)
        
        if security_score < 30:
            return "即座に共有設定の見直しが必要"
        elif security_score < 60:
            return "共有設定の最適化を推奨"
        elif security_score < 80:
            return "定期的な監視を継続"
        else:
            return "現在の設定は適切"
    
    def _assess_compliance_status(self, share: Dict[str, Any]) -> str:
        """Assess compliance status of a share."""
        issues = []
        
        if share.get('外部共有', False) and not share.get('DLP適用', False):
            issues.append("DLP未適用")
        
        if share.get('匿名アクセス', False):
            issues.append("匿名アクセス")
        
        if share.get('有効期限', '') == '無期限':
            issues.append("期限未設定")
        
        if issues:
            return f"要確認: {', '.join(issues)}"
        else:
            return "準拠"
    
    def _categorize_sync_errors(self, sync_data: List[Dict[str, Any]]) -> Dict[str, int]:
        """Categorize sync errors by type."""
        categories = {}
        
        for error in sync_data:
            error_type = error.get('エラータイプ', 'Unknown')
            categories[error_type] = categories.get(error_type, 0) + 1
        
        return categories
    
    def _generate_troubleshooting_guide(self, error_categories: Dict[str, int]) -> List[Dict[str, Any]]:
        """Generate troubleshooting guide based on error categories."""
        guide = []
        
        for error_type, count in error_categories.items():
            if error_type == 'ファイル名エラー':
                guide.append({
                    'エラータイプ': error_type,
                    '発生件数': count,
                    '解決策': 'ファイル名の文字数制限（260文字）を確認し、無効な文字を削除してください',
                    '推定解決時間': '5-10分'
                })
            elif error_type == 'アクセス権限エラー':
                guide.append({
                    'エラータイプ': error_type,
                    '発生件数': count,
                    '解決策': 'ファイル・フォルダーの権限設定を確認し、必要に応じて権限を付与してください',
                    '推定解決時間': '10-15分'
                })
            elif error_type == 'ストレージ容量エラー':
                guide.append({
                    'エラータイプ': error_type,
                    '発生件数': count,
                    '解決策': '不要なファイルを削除するか、追加ストレージを割り当ててください',
                    '推定解決時間': '15-30分'
                })
            else:
                guide.append({
                    'エラータイプ': error_type,
                    '発生件数': count,
                    '解決策': 'OneDriveサポートへの問い合わせを推奨します',
                    '推定解決時間': '30-60分'
                })
        
        return guide
    
    def _recommend_error_resolution(self, error: Dict[str, Any]) -> str:
        """Recommend resolution for a specific error."""
        error_type = error.get('エラータイプ', '')
        
        if error_type == 'ファイル名エラー':
            return 'ファイル名を260文字以内に短縮し、無効な文字（<>:"/\\|?*）を削除してください'
        elif error_type == 'アクセス権限エラー':
            return 'ファイル・フォルダーの権限設定を確認し、書き込み権限を付与してください'
        elif error_type == 'ストレージ容量エラー':
            return '不要なファイルを削除するか、管理者に追加容量を要求してください'
        elif error_type == 'ネットワークエラー':
            return 'ネットワーク接続を確認し、OneDriveクライアントを再起動してください'
        else:
            return 'OneDriveクライアントを再起動し、問題が続く場合はサポートへお問い合わせください'
    
    def _assess_error_priority(self, error: Dict[str, Any]) -> str:
        """Assess priority level of an error."""
        error_type = error.get('エラータイプ', '')
        duration = error.get('継続日数', 0)
        
        if error_type == 'ストレージ容量エラー' or duration > 7:
            return "High"
        elif error_type == 'アクセス権限エラー' or duration > 3:
            return "Medium"
        else:
            return "Low"
    
    def _estimate_resolution_time(self, error: Dict[str, Any]) -> str:
        """Estimate time required to resolve an error."""
        error_type = error.get('エラータイプ', '')
        
        time_estimates = {
            'ファイル名エラー': '5-10分',
            'アクセス権限エラー': '10-15分',
            'ストレージ容量エラー': '15-30分',
            'ネットワークエラー': '5-15分'
        }
        
        return time_estimates.get(error_type, '30-60分')
    
    def _generate_external_security_recommendations(self, external_data: List[Dict[str, Any]]) -> List[str]:
        """Generate security recommendations for external sharing."""
        recommendations = []
        
        try:
            total_external = len(external_data)
            
            anonymous_shares = sum(1 for share in external_data 
                                 if share.get('匿名アクセス', False))
            if anonymous_shares > 0:
                recommendations.append(f"{anonymous_shares}件の匿名共有を確認し、必要に応じて制限してください")
            
            high_risk_shares = sum(1 for share in external_data 
                                 if share.get('リスクレベル', '') == 'High')
            if high_risk_shares > total_external * 0.1:
                recommendations.append("高リスクの外部共有が多数検出されました。共有ポリシーの見直しを推奨します")
            
            edit_permissions = sum(1 for share in external_data 
                                 if share.get('権限レベル', '') == '編集')
            if edit_permissions > total_external * 0.3:
                recommendations.append("外部ユーザーへの編集権限付与が多いため、権限レベルの見直しを推奨します")
            
            recommendations.append("外部共有の定期的な監査とアクセス権限の見直しを実施してください")
            
        except Exception as e:
            recommendations.append(f"推奨事項生成エラー: {str(e)}")
        
        return recommendations
    
    def _assess_compliance_issues(self, external_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Assess compliance issues in external sharing."""
        issues = []
        
        for share in external_data:
            share_issues = []
            
            if share.get('匿名アクセス', False):
                share_issues.append("匿名アクセス有効")
            
            if not share.get('DLP適用', False):
                share_issues.append("DLP未適用")
            
            if share.get('有効期限', '') == '無期限':
                share_issues.append("有効期限未設定")
            
            if share_issues:
                issues.append({
                    'ファイル名': share.get('ファイル名', ''),
                    'ユーザー': share.get('ユーザー', ''),
                    'コンプライアンス問題': share_issues
                })
        
        return issues
    
    def _calculate_external_security_score(self, share: Dict[str, Any]) -> int:
        """Calculate security score for external sharing (0-100)."""
        score = 100
        
        # Deduct points for risk factors
        if share.get('匿名アクセス', False):
            score -= 50
        if share.get('権限レベル', '') == '編集':
            score -= 30
        if share.get('有効期限', '') == '無期限':
            score -= 20
        if not share.get('DLP適用', False):
            score -= 25
        
        return max(0, score)
    
    def _assess_external_compliance(self, share: Dict[str, Any]) -> str:
        """Assess external sharing compliance."""
        issues = []
        
        if share.get('匿名アクセス', False):
            issues.append("匿名アクセス")
        
        if not share.get('DLP適用', False):
            issues.append("DLP未適用")
        
        if share.get('有効期限', '') == '無期限':
            issues.append("期限未設定")
        
        if issues:
            return f"非準拠: {', '.join(issues)}"
        else:
            return "準拠"
    
    def _recommend_external_security_action(self, share: Dict[str, Any]) -> str:
        """Recommend security action for external sharing."""
        security_score = self._calculate_external_security_score(share)
        
        if security_score < 30:
            return "即座に外部共有の制限または削除が必要"
        elif security_score < 60:
            return "外部共有設定の見直しと制限を推奨"
        elif security_score < 80:
            return "定期的な監視と権限確認を実施"
        else:
            return "現在の設定は適切"
    
    def _handle_error(self, error: Exception, operation: str) -> OneDriveServiceResponse:
        """Handle service errors consistently."""
        error_msg = f"OneDrive {operation} failed: {str(error)}"
        self.logger.error(error_msg, exc_info=True)
        return OneDriveServiceResponse(
            success=False,
            data=None,
            error_message=error_msg
        )
    
    def get_connection_status(self) -> Dict[str, Any]:
        """Get connection status for OneDrive services."""
        return self.onedrive_client.get_connection_status()
    
    def cleanup(self):
        """Clean up resources."""
        try:
            self.onedrive_client.disconnect()
            self.executor.shutdown(wait=True)
        except Exception as e:
            self.logger.error(f"Error during cleanup: {e}")
    
    def __del__(self):
        """Cleanup on object destruction."""
        try:
            self.cleanup()
        except:
            pass


# Export main class
__all__ = ['OneDriveService', 'OneDriveServiceResponse']