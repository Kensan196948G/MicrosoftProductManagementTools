"""
Migration Helper Module
PowerShell版からPython版への機能移行を支援

このモジュールは：
1. 機能マッピングの定義
2. 段階的移行のサポート
3. 互換性チェック
4. 移行進捗の追跡
"""

import logging
from typing import Dict, List, Any, Optional, Callable, Union
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import json
from datetime import datetime

logger = logging.getLogger(__name__)


class MigrationStatus(Enum):
    """移行ステータス"""
    NOT_STARTED = "not_started"
    POWERSHELL_ONLY = "powershell_only"
    HYBRID = "hybrid"
    PYTHON_ONLY = "python_only"
    COMPLETED = "completed"


@dataclass
class FunctionMapping:
    """機能マッピング定義"""
    powershell_function: str
    python_function: Optional[str] = None
    powershell_module: Optional[str] = None
    python_module: Optional[str] = None
    parameters_mapping: Dict[str, str] = field(default_factory=dict)
    status: MigrationStatus = MigrationStatus.NOT_STARTED
    priority: int = 1  # 1: 高優先度, 2: 中優先度, 3: 低優先度
    dependencies: List[str] = field(default_factory=list)
    notes: str = ""


class MigrationHelper:
    """
    PowerShell→Python移行支援クラス
    
    機能ごとの移行状況を管理し、適切な実装を選択します。
    """
    
    def __init__(self, config_path: Optional[Path] = None):
        self.config_path = config_path or Path(__file__).parent / "migration_config.json"
        self.function_mappings: Dict[str, FunctionMapping] = {}
        self.load_mappings()
    
    def load_mappings(self):
        """機能マッピング設定を読み込み"""
        # デフォルトのマッピング定義
        default_mappings = self._get_default_mappings()
        
        # 設定ファイルから読み込み（存在する場合）
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    config_data = json.load(f)
                    
                for func_name, mapping_data in config_data.get('function_mappings', {}).items():
                    self.function_mappings[func_name] = FunctionMapping(
                        powershell_function=mapping_data.get('powershell_function'),
                        python_function=mapping_data.get('python_function'),
                        powershell_module=mapping_data.get('powershell_module'),
                        python_module=mapping_data.get('python_module'),
                        parameters_mapping=mapping_data.get('parameters_mapping', {}),
                        status=MigrationStatus(mapping_data.get('status', 'not_started')),
                        priority=mapping_data.get('priority', 1),
                        dependencies=mapping_data.get('dependencies', []),
                        notes=mapping_data.get('notes', '')
                    )
            except Exception as e:
                logger.warning(f"Failed to load migration config: {e}")
        
        # デフォルトマッピングをマージ
        for func_name, mapping in default_mappings.items():
            if func_name not in self.function_mappings:
                self.function_mappings[func_name] = mapping
    
    def _get_default_mappings(self) -> Dict[str, FunctionMapping]:
        """デフォルトの機能マッピングを定義"""
        mappings = {}
        
        # 定期レポート機能
        mappings['daily_report'] = FunctionMapping(
            powershell_function='Get-M365DailyReport',
            python_function='src.api.graph.services.ReportService.generate_daily_report',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.HYBRID,
            priority=1,
            notes='日次レポート生成機能'
        )
        
        mappings['weekly_report'] = FunctionMapping(
            powershell_function='Get-M365WeeklyReport',
            python_function='src.api.graph.services.ReportService.generate_weekly_report',
            powershell_module='WeeklyReportData',
            python_module='src.api.graph.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        mappings['monthly_report'] = FunctionMapping(
            powershell_function='Get-M365MonthlyReport',
            python_function='src.api.graph.services.ReportService.generate_monthly_report',
            powershell_module='MonthlyReportData',
            python_module='src.api.graph.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        mappings['yearly_report'] = FunctionMapping(
            powershell_function='Get-M365YearlyReport',
            python_function='src.api.graph.services.ReportService.generate_yearly_report',
            powershell_module='YearlyReportData',
            python_module='src.api.graph.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=3
        )
        
        # 分析レポート機能
        mappings['license_analysis'] = FunctionMapping(
            powershell_function='Get-M365LicenseAnalysis',
            python_function='src.api.graph.services.LicenseService.get_license_analysis',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.HYBRID,
            priority=1
        )
        
        mappings['usage_analysis'] = FunctionMapping(
            powershell_function='Get-M365UsageAnalysis',
            python_function='src.api.graph.services.ReportService.get_usage_analysis',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        # Entra ID管理機能
        mappings['user_list'] = FunctionMapping(
            powershell_function='Get-M365AllUsers',
            python_function='src.api.graph.services.UserService.get_all_users',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            parameters_mapping={
                'MaxResults': 'limit',
                'Filter': 'filter'
            },
            status=MigrationStatus.HYBRID,
            priority=1
        )
        
        mappings['mfa_status'] = FunctionMapping(
            powershell_function='Get-M365MFAStatus',
            python_function='src.api.graph.services.UserService.get_user_mfa_status',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.HYBRID,
            priority=1
        )
        
        mappings['conditional_access'] = FunctionMapping(
            powershell_function='Get-M365ConditionalAccess',
            python_function='src.api.graph.services.SecurityService.get_conditional_access',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        mappings['signin_logs'] = FunctionMapping(
            powershell_function='Get-M365SignInLogs',
            python_function='src.api.graph.services.SecurityService.get_signin_logs',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        # Exchange Online管理機能
        mappings['mailbox_management'] = FunctionMapping(
            powershell_function='Get-M365MailboxAnalysis',
            python_function='src.api.graph.services.ExchangeService.get_mailbox_analysis',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.HYBRID,
            priority=1
        )
        
        mappings['mail_flow_analysis'] = FunctionMapping(
            powershell_function='Get-M365MailFlowAnalysis',
            python_function='src.api.exchange.services.MailFlowService.get_analysis',
            powershell_module='RealM365DataProvider',
            python_module='src.api.exchange.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        # Teams管理機能
        mappings['teams_usage'] = FunctionMapping(
            powershell_function='Get-M365TeamsUsage',
            python_function='src.api.graph.services.TeamsService.get_teams_usage',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.HYBRID,
            priority=1
        )
        
        mappings['teams_settings'] = FunctionMapping(
            powershell_function='Get-M365TeamsSettings',
            python_function='src.api.teams.services.TeamsConfigService.get_settings',
            powershell_module='RealM365DataProvider',
            python_module='src.api.teams.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        # OneDrive管理機能
        mappings['storage_analysis'] = FunctionMapping(
            powershell_function='Get-M365OneDriveAnalysis',
            python_function='src.api.graph.services.OneDriveService.get_storage_analysis',
            powershell_module='RealM365DataProvider',
            python_module='src.api.graph.services',
            status=MigrationStatus.HYBRID,
            priority=1
        )
        
        mappings['sharing_analysis'] = FunctionMapping(
            powershell_function='Get-M365OneDriveSharing',
            python_function='src.api.onedrive.services.SharingService.get_analysis',
            powershell_module='RealM365DataProvider',
            python_module='src.api.onedrive.services',
            status=MigrationStatus.POWERSHELL_ONLY,
            priority=2
        )
        
        return mappings
    
    def get_function_mapping(self, function_name: str) -> Optional[FunctionMapping]:
        """指定された機能のマッピング情報を取得"""
        return self.function_mappings.get(function_name)
    
    def should_use_powershell(self, function_name: str) -> bool:
        """指定された機能でPowerShellを使用すべきかを判定"""
        mapping = self.get_function_mapping(function_name)
        if not mapping:
            return True  # マッピングが不明な場合はPowerShellを使用
        
        return mapping.status in [
            MigrationStatus.NOT_STARTED,
            MigrationStatus.POWERSHELL_ONLY,
            MigrationStatus.HYBRID
        ]
    
    def should_use_python(self, function_name: str) -> bool:
        """指定された機能でPythonを使用すべきかを判定"""
        mapping = self.get_function_mapping(function_name)
        if not mapping:
            return False  # マッピングが不明な場合はPythonは使用しない
        
        return mapping.status in [
            MigrationStatus.HYBRID,
            MigrationStatus.PYTHON_ONLY,
            MigrationStatus.COMPLETED
        ]
    
    def get_preferred_implementation(self, function_name: str) -> str:
        """推奨実装を取得（'powershell' または 'python'）"""
        mapping = self.get_function_mapping(function_name)
        if not mapping:
            return 'powershell'
        
        if mapping.status == MigrationStatus.PYTHON_ONLY:
            return 'python'
        elif mapping.status == MigrationStatus.COMPLETED:
            return 'python'
        elif mapping.status == MigrationStatus.HYBRID:
            # ハイブリッドの場合は優先度に基づいて決定
            return 'python' if mapping.priority == 1 else 'powershell'
        else:
            return 'powershell'
    
    def get_migration_progress(self) -> Dict[str, Any]:
        """移行進捗を取得"""
        status_counts = {}
        for status in MigrationStatus:
            status_counts[status.value] = 0
        
        for mapping in self.function_mappings.values():
            status_counts[mapping.status.value] += 1
        
        total_functions = len(self.function_mappings)
        completed = status_counts[MigrationStatus.COMPLETED.value]
        python_ready = status_counts[MigrationStatus.PYTHON_ONLY.value] + completed
        
        return {
            'total_functions': total_functions,
            'completed': completed,
            'python_ready': python_ready,
            'completion_percentage': (completed / total_functions * 100) if total_functions > 0 else 0,
            'python_ready_percentage': (python_ready / total_functions * 100) if total_functions > 0 else 0,
            'status_breakdown': status_counts,
            'last_updated': datetime.now().isoformat()
        }
    
    def update_function_status(self, function_name: str, status: MigrationStatus, notes: str = ""):
        """機能のステータスを更新"""
        if function_name in self.function_mappings:
            self.function_mappings[function_name].status = status
            if notes:
                self.function_mappings[function_name].notes = notes
            self.save_mappings()
            logger.info(f"Updated {function_name} status to {status.value}")
        else:
            logger.warning(f"Function {function_name} not found in mappings")
    
    def get_high_priority_functions(self) -> List[str]:
        """高優先度の機能リストを取得"""
        return [
            name for name, mapping in self.function_mappings.items()
            if mapping.priority == 1
        ]
    
    def get_functions_by_status(self, status: MigrationStatus) -> List[str]:
        """指定されたステータスの機能リストを取得"""
        return [
            name for name, mapping in self.function_mappings.items()
            if mapping.status == status
        ]
    
    def save_mappings(self):
        """マッピング設定をファイルに保存"""
        try:
            config_data = {
                'function_mappings': {},
                'last_updated': datetime.now().isoformat(),
                'version': '1.0.0'
            }
            
            for func_name, mapping in self.function_mappings.items():
                config_data['function_mappings'][func_name] = {
                    'powershell_function': mapping.powershell_function,
                    'python_function': mapping.python_function,
                    'powershell_module': mapping.powershell_module,
                    'python_module': mapping.python_module,
                    'parameters_mapping': mapping.parameters_mapping,
                    'status': mapping.status.value,
                    'priority': mapping.priority,
                    'dependencies': mapping.dependencies,
                    'notes': mapping.notes
                }
            
            # ディレクトリが存在しない場合は作成
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(config_data, f, indent=2, ensure_ascii=False)
                
            logger.info(f"Migration mappings saved to {self.config_path}")
            
        except Exception as e:
            logger.error(f"Failed to save migration mappings: {e}")
    
    def generate_migration_report(self) -> str:
        """移行レポートを生成"""
        progress = self.get_migration_progress()
        
        report = []
        report.append("=" * 60)
        report.append("Microsoft 365 Management Tools - Migration Report")
        report.append("=" * 60)
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # 全体進捗
        report.append("📊 Overall Progress:")
        report.append(f"  Total Functions: {progress['total_functions']}")
        report.append(f"  Completed: {progress['completed']} ({progress['completion_percentage']:.1f}%)")
        report.append(f"  Python Ready: {progress['python_ready']} ({progress['python_ready_percentage']:.1f}%)")
        report.append("")
        
        # ステータス別分類
        report.append("📋 Status Breakdown:")
        for status, count in progress['status_breakdown'].items():
            report.append(f"  {status}: {count}")
        report.append("")
        
        # 高優先度機能
        high_priority = self.get_high_priority_functions()
        report.append("🔥 High Priority Functions:")
        for func in high_priority:
            mapping = self.function_mappings[func]
            status_icon = "✅" if mapping.status == MigrationStatus.COMPLETED else "⏳"
            report.append(f"  {status_icon} {func} ({mapping.status.value})")
        report.append("")
        
        # 完了済み機能
        completed = self.get_functions_by_status(MigrationStatus.COMPLETED)
        if completed:
            report.append("✅ Completed Functions:")
            for func in completed:
                report.append(f"  - {func}")
            report.append("")
        
        # PowerShellのみの機能
        ps_only = self.get_functions_by_status(MigrationStatus.POWERSHELL_ONLY)
        if ps_only:
            report.append("⚠️ PowerShell Only Functions:")
            for func in ps_only:
                report.append(f"  - {func}")
            report.append("")
        
        return "\\n".join(report)


# グローバルなMigrationHelperインスタンス
_migration_helper = None

def get_migration_helper() -> MigrationHelper:
    """MigrationHelperのシングルトンインスタンスを取得"""
    global _migration_helper
    if _migration_helper is None:
        _migration_helper = MigrationHelper()
    return _migration_helper