"""
Hybrid Service Module
PowerShellとPythonの実装を統合的に管理するサービス

このモジュールは：
1. PowerShell版とPython版の機能を統合
2. 最適な実装の自動選択
3. フォールバック機能の提供
4. 統一されたインターフェース
"""

import asyncio
import logging
from typing import Dict, List, Any, Optional, Union
from dataclasses import dataclass
from datetime import datetime
import json

from .powershell_bridge import PowerShellBridge, get_powershell_bridge, DataFormatConverter
from .migration_helper import MigrationHelper, get_migration_helper, MigrationStatus
from ..config import Config

logger = logging.getLogger(__name__)


@dataclass
class ServiceResult:
    """サービス実行結果"""
    success: bool
    data: Any
    source: str  # 'powershell' or 'python'
    execution_time: float
    error: Optional[str] = None
    fallback_used: bool = False


class HybridService:
    """
    PowerShell版とPython版を統合管理するハイブリッドサービス
    
    機能ごとに最適な実装を自動選択し、フォールバック機能を提供します。
    """
    
    def __init__(self, config: Config):
        self.config = config
        self.migration_helper = get_migration_helper()
        self.powershell_bridge = get_powershell_bridge()
        
        # Python版サービスの遅延読み込み
        self._python_services = None
        
        # 統計情報
        self.execution_stats = {
            'powershell_calls': 0,
            'python_calls': 0,
            'fallback_calls': 0,
            'total_calls': 0,
            'last_reset': datetime.now()
        }
        
        logger.info("Hybrid Service initialized")
    
    @property
    def python_services(self):
        """Python版サービスの遅延読み込み"""
        if self._python_services is None:
            try:
                from src.api.graph.services import (
                    UserService, LicenseService, TeamsService,
                    OneDriveService, ExchangeService, ReportService
                )
                from src.api.graph.client import GraphClient
                
                # Graph clientの初期化は必要に応じて
                graph_client = None  # 実際の初期化は認証後
                
                self._python_services = {
                    'user': UserService(graph_client) if graph_client else None,
                    'license': LicenseService(graph_client) if graph_client else None,
                    'teams': TeamsService(graph_client) if graph_client else None,
                    'onedrive': OneDriveService(graph_client) if graph_client else None,
                    'exchange': ExchangeService(graph_client) if graph_client else None,
                    'report': ReportService(graph_client) if graph_client else None
                }
            except ImportError as e:
                logger.warning(f"Python services not available: {e}")
                self._python_services = {}
        
        return self._python_services
    
    async def execute_function(self, function_name: str, **kwargs) -> ServiceResult:
        """
        指定された機能を実行
        
        移行状況に応じて最適な実装を選択し、必要に応じてフォールバック
        """
        start_time = datetime.now()
        self.execution_stats['total_calls'] += 1
        
        # 実装方式の決定
        preferred_impl = self.migration_helper.get_preferred_implementation(function_name)
        
        logger.info(f"Executing {function_name} with preferred implementation: {preferred_impl}")
        
        # 優先実装での実行
        if preferred_impl == 'python':
            result = await self._execute_python_function(function_name, **kwargs)
            if result.success:
                self.execution_stats['python_calls'] += 1
                return result
            else:
                # Pythonで失敗した場合はPowerShellにフォールバック
                logger.warning(f"Python implementation failed for {function_name}, falling back to PowerShell")
                fallback_result = await self._execute_powershell_function(function_name, **kwargs)
                if fallback_result.success:
                    fallback_result.fallback_used = True
                    self.execution_stats['fallback_calls'] += 1
                return fallback_result
        else:
            result = await self._execute_powershell_function(function_name, **kwargs)
            if result.success:
                self.execution_stats['powershell_calls'] += 1
                return result
            else:
                # PowerShellで失敗した場合はPythonにフォールバック
                if self.migration_helper.should_use_python(function_name):
                    logger.warning(f"PowerShell implementation failed for {function_name}, falling back to Python")
                    fallback_result = await self._execute_python_function(function_name, **kwargs)
                    if fallback_result.success:
                        fallback_result.fallback_used = True
                        self.execution_stats['fallback_calls'] += 1
                    return fallback_result
                else:
                    return result
    
    async def _execute_python_function(self, function_name: str, **kwargs) -> ServiceResult:
        """Python版機能を実行"""
        start_time = datetime.now()
        
        try:
            # 機能マッピングを取得
            mapping = self.migration_helper.get_function_mapping(function_name)
            if not mapping or not mapping.python_function:
                return ServiceResult(
                    success=False,
                    data=None,
                    source='python',
                    execution_time=0,
                    error=f"Python implementation not available for {function_name}"
                )
            
            # パラメータ変換
            python_kwargs = self._convert_parameters_to_python(mapping, kwargs)
            
            # Python関数の実行
            result_data = await self._call_python_function(function_name, python_kwargs)
            
            execution_time = (datetime.now() - start_time).total_seconds()
            
            return ServiceResult(
                success=True,
                data=result_data,
                source='python',
                execution_time=execution_time
            )
            
        except Exception as e:
            execution_time = (datetime.now() - start_time).total_seconds()
            logger.error(f"Python function execution failed: {e}")
            
            return ServiceResult(
                success=False,
                data=None,
                source='python',
                execution_time=execution_time,
                error=str(e)
            )
    
    async def _execute_powershell_function(self, function_name: str, **kwargs) -> ServiceResult:
        """PowerShell版機能を実行"""
        start_time = datetime.now()
        
        try:
            # PowerShellブリッジを使用して実行
            ps_result = await self._call_powershell_function(function_name, kwargs)
            
            execution_time = (datetime.now() - start_time).total_seconds()
            
            if ps_result.success:
                # データ形式をPython互換に変換
                converted_data = DataFormatConverter.powershell_to_python(ps_result.data)
                
                return ServiceResult(
                    success=True,
                    data=converted_data,
                    source='powershell',
                    execution_time=execution_time
                )
            else:
                return ServiceResult(
                    success=False,
                    data=None,
                    source='powershell',
                    execution_time=execution_time,
                    error=ps_result.error
                )
                
        except Exception as e:
            execution_time = (datetime.now() - start_time).total_seconds()
            logger.error(f"PowerShell function execution failed: {e}")
            
            return ServiceResult(
                success=False,
                data=None,
                source='powershell',
                execution_time=execution_time,
                error=str(e)
            )
    
    async def _call_python_function(self, function_name: str, kwargs: Dict[str, Any]) -> Any:
        """Python関数を呼び出し"""
        
        # 機能名に基づいてPythonサービスを選択・実行
        if function_name == 'user_list':
            service = self.python_services.get('user')
            if service:
                return service.get_all_users(**kwargs)
            else:
                return self._generate_mock_python_data(function_name)
                
        elif function_name == 'mfa_status':
            service = self.python_services.get('user')
            if service:
                return service.get_user_mfa_status()
            else:
                return self._generate_mock_python_data(function_name)
                
        elif function_name == 'license_analysis':
            service = self.python_services.get('license')
            if service:
                return service.get_license_analysis()
            else:
                return self._generate_mock_python_data(function_name)
                
        elif function_name == 'teams_usage':
            service = self.python_services.get('teams')
            if service:
                return service.get_teams_usage()
            else:
                return self._generate_mock_python_data(function_name)
                
        elif function_name == 'storage_analysis':
            service = self.python_services.get('onedrive')
            if service:
                return service.get_storage_analysis()
            else:
                return self._generate_mock_python_data(function_name)
                
        elif function_name == 'mailbox_management':
            service = self.python_services.get('exchange')
            if service:
                return service.get_mailbox_analysis()
            else:
                return self._generate_mock_python_data(function_name)
                
        elif function_name == 'daily_report':
            service = self.python_services.get('report')
            if service:
                return service.generate_daily_report()
            else:
                return self._generate_mock_python_data(function_name)
                
        else:
            # その他の機能はモックデータで対応
            return self._generate_mock_python_data(function_name)
    
    async def _call_powershell_function(self, function_name: str, kwargs: Dict[str, Any]):
        """PowerShell関数を呼び出し"""
        
        # 機能名に基づいてPowerShell関数を選択・実行
        if function_name == 'user_list':
            return await self.powershell_bridge.get_m365_users(
                limit=kwargs.get('limit', 1000)
            )
        elif function_name == 'license_analysis':
            return await self.powershell_bridge.get_m365_license_analysis()
        elif function_name == 'teams_usage':
            return await self.powershell_bridge.get_m365_teams_usage()
        elif function_name == 'storage_analysis':
            return await self.powershell_bridge.get_m365_onedrive_analysis()
        elif function_name == 'mailbox_management':
            return await self.powershell_bridge.get_m365_mailbox_analysis()
        else:
            # その他の機能はCLI経由で実行
            return await self.powershell_bridge.generate_report_via_powershell(
                function_name, **kwargs
            )
    
    def _convert_parameters_to_python(self, mapping, ps_kwargs: Dict[str, Any]) -> Dict[str, Any]:
        """PowerShellパラメータをPython形式に変換"""
        python_kwargs = {}
        
        for ps_key, py_key in mapping.parameters_mapping.items():
            if ps_key in ps_kwargs:
                python_kwargs[py_key] = ps_kwargs[ps_key]
        
        # マッピングにないパラメータもそのまま渡す
        for key, value in ps_kwargs.items():
            if key not in mapping.parameters_mapping:
                python_kwargs[key] = value
        
        return python_kwargs
    
    def _generate_mock_python_data(self, function_name: str) -> List[Dict[str, Any]]:
        """Python用モックデータ生成"""
        import random
        
        mock_data = []
        for i in range(random.randint(5, 15)):
            mock_data.append({
                'ID': i + 1,
                'Function': function_name,
                'Timestamp': datetime.now().strftime('%Y/%m/%d %H:%M:%S'),
                'Status': random.choice(['正常', '警告', '異常']),
                'Source': 'Python (Mock)',
                'Details': f'{function_name} のモックデータ {i + 1}'
            })
        
        return mock_data
    
    async def test_authentication(self) -> ServiceResult:
        """認証状態をテスト"""
        # PowerShell版認証テスト
        ps_result = await self.powershell_bridge.test_m365_authentication()
        
        # TODO: Python版認証テストも実装
        
        return ServiceResult(
            success=ps_result.success,
            data=ps_result.data,
            source='powershell',
            execution_time=ps_result.execution_time,
            error=ps_result.error
        )
    
    def get_execution_statistics(self) -> Dict[str, Any]:
        """実行統計を取得"""
        total = self.execution_stats['total_calls']
        
        return {
            'total_calls': total,
            'powershell_calls': self.execution_stats['powershell_calls'],
            'python_calls': self.execution_stats['python_calls'],
            'fallback_calls': self.execution_stats['fallback_calls'],
            'powershell_percentage': (self.execution_stats['powershell_calls'] / total * 100) if total > 0 else 0,
            'python_percentage': (self.execution_stats['python_calls'] / total * 100) if total > 0 else 0,
            'fallback_percentage': (self.execution_stats['fallback_calls'] / total * 100) if total > 0 else 0,
            'last_reset': self.execution_stats['last_reset'].isoformat()
        }
    
    def reset_statistics(self):
        """実行統計をリセット"""
        self.execution_stats = {
            'powershell_calls': 0,
            'python_calls': 0,
            'fallback_calls': 0,
            'total_calls': 0,
            'last_reset': datetime.now()
        }


class UnifiedAPIService:
    """
    統一されたAPI インターフェース
    
    GUI/CLIからの呼び出しを統一的に処理し、
    適切な実装に振り分けます。
    """
    
    def __init__(self, config: Config):
        self.config = config
        self.hybrid_service = HybridService(config)
        
    async def get_users(self, limit: int = 1000, filter: str = None) -> ServiceResult:
        """ユーザー一覧取得"""
        return await self.hybrid_service.execute_function(
            'user_list', 
            limit=limit, 
            filter=filter
        )
    
    async def get_mfa_status(self) -> ServiceResult:
        """MFA状況取得"""
        return await self.hybrid_service.execute_function('mfa_status')
    
    async def get_license_analysis(self) -> ServiceResult:
        """ライセンス分析"""
        return await self.hybrid_service.execute_function('license_analysis')
    
    async def get_teams_usage(self) -> ServiceResult:
        """Teams使用状況"""
        return await self.hybrid_service.execute_function('teams_usage')
    
    async def get_storage_analysis(self) -> ServiceResult:
        """ストレージ分析"""
        return await self.hybrid_service.execute_function('storage_analysis')
    
    async def get_mailbox_analysis(self) -> ServiceResult:
        """メールボックス分析"""
        return await self.hybrid_service.execute_function('mailbox_management')
    
    async def generate_daily_report(self) -> ServiceResult:
        """日次レポート生成"""
        return await self.hybrid_service.execute_function('daily_report')
    
    async def generate_weekly_report(self) -> ServiceResult:
        """週次レポート生成"""
        return await self.hybrid_service.execute_function('weekly_report')
    
    async def generate_monthly_report(self) -> ServiceResult:
        """月次レポート生成"""
        return await self.hybrid_service.execute_function('monthly_report')
    
    async def generate_yearly_report(self) -> ServiceResult:
        """年次レポート生成"""
        return await self.hybrid_service.execute_function('yearly_report')
    
    def get_migration_status(self) -> Dict[str, Any]:
        """移行状況を取得"""
        progress = self.hybrid_service.migration_helper.get_migration_progress()
        stats = self.hybrid_service.get_execution_statistics()
        
        return {
            'migration_progress': progress,
            'execution_statistics': stats,
            'timestamp': datetime.now().isoformat()
        }


# グローバルサービスインスタンス
_unified_service = None

def get_unified_service(config: Config = None) -> UnifiedAPIService:
    """統一APIサービスのシングルトンインスタンスを取得"""
    global _unified_service
    
    if _unified_service is None:
        if config is None:
            from ..config import Config
            config = Config()
            config.load()
        
        _unified_service = UnifiedAPIService(config)
    
    return _unified_service