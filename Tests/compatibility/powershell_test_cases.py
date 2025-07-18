"""
PowerShell版機能テストケース定義
Dev1 - Test/QA Developer による26機能の包括的テストケース
"""
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from enum import Enum
import pytest


class TestCategory(Enum):
    """テストカテゴリー"""
    REGULAR_REPORTS = "定期レポート"
    ANALYSIS_REPORTS = "分析レポート"
    ENTRAID_MANAGEMENT = "Entra ID管理"
    EXCHANGE_MANAGEMENT = "Exchange Online管理"
    TEAMS_MANAGEMENT = "Teams管理"
    ONEDRIVE_MANAGEMENT = "OneDrive管理"


@dataclass
class PowerShellTestCase:
    """PowerShell機能テストケース"""
    test_id: str
    function_name: str
    category: TestCategory
    description: str
    powershell_script: str
    expected_outputs: List[str]  # 期待される出力ファイル（CSV/HTML）
    test_data_requirements: Dict[str, Any]
    execution_timeout: int = 120
    requires_auth: bool = True
    mock_data_available: bool = True
    validation_rules: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.validation_rules is None:
            self.validation_rules = {}


class PowerShellTestCaseDefinitions:
    """PowerShell版の全26機能テストケース定義"""
    
    @staticmethod
    def get_all_test_cases() -> List[PowerShellTestCase]:
        """全テストケースを取得"""
        return [
            # 📊 定期レポート (5機能)
            PowerShellTestCase(
                test_id="REG001",
                function_name="daily_report",
                category=TestCategory.REGULAR_REPORTS,
                description="日次レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["日次レポート_*.csv", "日次レポート_*.html"],
                test_data_requirements={
                    "users": 50,
                    "active_users": 40,
                    "login_events": 100,
                    "date_range": "1_day"
                },
                validation_rules={
                    "csv_columns": ["ユーザー名", "最終ログイン", "アクティビティ"],
                    "min_records": 1,
                    "html_contains": ["日次レポート", "ログイン状況"]
                }
            ),
            
            PowerShellTestCase(
                test_id="REG002", 
                function_name="weekly_report",
                category=TestCategory.REGULAR_REPORTS,
                description="週次レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["週次レポート_*.csv", "週次レポート_*.html"],
                test_data_requirements={
                    "users": 50,
                    "mfa_enabled": 30,
                    "date_range": "7_days"
                },
                validation_rules={
                    "csv_columns": ["ユーザー名", "MFA状況", "週間アクティビティ"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="REG003",
                function_name="monthly_report", 
                category=TestCategory.REGULAR_REPORTS,
                description="月次レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["月次レポート_*.csv", "月次レポート_*.html"],
                test_data_requirements={
                    "users": 50,
                    "licenses": 30,
                    "date_range": "30_days"
                },
                validation_rules={
                    "csv_columns": ["ユーザー名", "ライセンス", "月間利用率"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="REG004",
                function_name="yearly_report",
                category=TestCategory.REGULAR_REPORTS, 
                description="年次レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["年次レポート_*.csv", "年次レポート_*.html"],
                test_data_requirements={
                    "users": 50,
                    "licenses": 30,
                    "date_range": "365_days"
                },
                validation_rules={
                    "csv_columns": ["ユーザー名", "年間ライセンス消費", "コスト"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="REG005",
                function_name="test_execution",
                category=TestCategory.REGULAR_REPORTS,
                description="テスト実行レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1", 
                expected_outputs=["テスト実行_*.csv", "テスト実行_*.html"],
                test_data_requirements={
                    "test_cases": 20,
                    "success_rate": 0.85
                },
                validation_rules={
                    "csv_columns": ["テスト項目", "結果", "実行時間"],
                    "min_records": 1
                }
            ),
            
            # 🔍 分析レポート (5機能)
            PowerShellTestCase(
                test_id="ANA001",
                function_name="license_analysis",
                category=TestCategory.ANALYSIS_REPORTS,
                description="ライセンス分析レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["ライセンス分析_*.csv", "ライセンス分析_*.html"],
                test_data_requirements={
                    "license_types": ["Office 365 E3", "Office 365 E5"],
                    "total_licenses": 100,
                    "consumed_licenses": 75
                },
                validation_rules={
                    "csv_columns": ["ライセンス種別", "総数", "使用数", "使用率"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="ANA002",
                function_name="usage_analysis", 
                category=TestCategory.ANALYSIS_REPORTS,
                description="使用状況分析レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["使用状況分析_*.csv", "使用状況分析_*.html"],
                test_data_requirements={
                    "services": ["Teams", "OneDrive", "Exchange"],
                    "usage_data": 30
                },
                validation_rules={
                    "csv_columns": ["サービス名", "使用率", "アクティブユーザー"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="ANA003",
                function_name="performance_analysis",
                category=TestCategory.ANALYSIS_REPORTS,
                description="パフォーマンス分析レポート生成テスト", 
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["パフォーマンス分析_*.csv", "パフォーマンス分析_*.html"],
                test_data_requirements={
                    "performance_metrics": 50,
                    "response_times": 100
                },
                validation_rules={
                    "csv_columns": ["サービス", "応答時間", "可用性"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="ANA004",
                function_name="security_analysis",
                category=TestCategory.ANALYSIS_REPORTS,
                description="セキュリティ分析レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["セキュリティ分析_*.csv", "セキュリティ分析_*.html"],
                test_data_requirements={
                    "security_events": 100,
                    "threat_data": 20
                },
                validation_rules={
                    "csv_columns": ["イベント種別", "重要度", "対処状況"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="ANA005",
                function_name="permission_audit",
                category=TestCategory.ANALYSIS_REPORTS,
                description="権限監査レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["権限監査_*.csv", "権限監査_*.html"],
                test_data_requirements={
                    "users": 50,
                    "permissions": 200
                },
                validation_rules={
                    "csv_columns": ["ユーザー", "権限", "付与日"],
                    "min_records": 1
                }
            ),
            
            # 👥 Entra ID管理 (4機能)
            PowerShellTestCase(
                test_id="ENT001",
                function_name="user_list",
                category=TestCategory.ENTRAID_MANAGEMENT,
                description="Entra IDユーザー一覧テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["AllUsers_*.csv", "AllUsers_*.html"],
                test_data_requirements={
                    "total_users": 100,
                    "active_users": 85
                },
                validation_rules={
                    "csv_columns": ["DisplayName", "UserPrincipalName", "Department"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="ENT002",
                function_name="mfa_status",
                category=TestCategory.ENTRAID_MANAGEMENT,
                description="MFA状況レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["MFA状況_*.csv", "MFA状況_*.html"],
                test_data_requirements={
                    "users": 50,
                    "mfa_enabled": 30
                },
                validation_rules={
                    "csv_columns": ["ユーザー", "MFA状況", "最終設定日"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="ENT003",
                function_name="conditional_access",
                category=TestCategory.ENTRAID_MANAGEMENT,
                description="条件付きアクセス分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["条件付きアクセス_*.csv", "条件付きアクセス_*.html"],
                test_data_requirements={
                    "policies": 10,
                    "users_affected": 50
                },
                validation_rules={
                    "csv_columns": ["ポリシー名", "状態", "対象ユーザー"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="ENT004",
                function_name="signin_logs",
                category=TestCategory.ENTRAID_MANAGEMENT,
                description="サインインログ分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["サインインログ_*.csv", "サインインログ_*.html"],
                test_data_requirements={
                    "signin_events": 500,
                    "date_range": "7_days"
                },
                validation_rules={
                    "csv_columns": ["ユーザー", "サインイン時刻", "結果"],
                    "min_records": 1
                }
            ),
            
            # 📧 Exchange Online管理 (4機能)
            PowerShellTestCase(
                test_id="EXO001",
                function_name="mailbox_management",
                category=TestCategory.EXCHANGE_MANAGEMENT,
                description="メールボックス管理レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["mailbox_*.csv", "mailbox_*.html"],
                test_data_requirements={
                    "mailboxes": 50,
                    "storage_data": 100
                },
                validation_rules={
                    "csv_columns": ["メールボックス", "サイズ", "使用率"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="EXO002",
                function_name="mail_flow_analysis",
                category=TestCategory.EXCHANGE_MANAGEMENT,
                description="メールフロー分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["メールフロー_*.csv", "メールフロー_*.html"],
                test_data_requirements={
                    "mail_flow_data": 1000,
                    "date_range": "7_days"
                },
                validation_rules={
                    "csv_columns": ["送信者", "受信者", "ステータス"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="EXO003",
                function_name="spam_protection",
                category=TestCategory.EXCHANGE_MANAGEMENT,
                description="スパム対策分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["スパム対策_*.csv", "スパム対策_*.html"],
                test_data_requirements={
                    "spam_events": 200,
                    "blocked_emails": 150
                },
                validation_rules={
                    "csv_columns": ["送信者", "件名", "判定結果"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="EXO004",
                function_name="mail_delivery_analysis",
                category=TestCategory.EXCHANGE_MANAGEMENT,
                description="メール配信分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["メール配信分析_*.csv", "メール配信分析_*.html"],
                test_data_requirements={
                    "delivery_data": 500,
                    "success_rate": 0.95
                },
                validation_rules={
                    "csv_columns": ["宛先", "配信時刻", "ステータス"],
                    "min_records": 1
                }
            ),
            
            # 💬 Teams管理 (4機能)
            PowerShellTestCase(
                test_id="TEA001",
                function_name="teams_usage",
                category=TestCategory.TEAMS_MANAGEMENT,
                description="Teams使用状況レポート生成テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1", 
                expected_outputs=["teams_*.csv", "teams_*.html"],
                test_data_requirements={
                    "teams": 20,
                    "active_users": 100
                },
                validation_rules={
                    "csv_columns": ["チーム名", "メンバー数", "アクティビティ"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="TEA002",
                function_name="teams_settings",
                category=TestCategory.TEAMS_MANAGEMENT,
                description="Teams設定分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["Teams設定_*.csv", "Teams設定_*.html"],
                test_data_requirements={
                    "teams": 20,
                    "settings_data": 50
                },
                validation_rules={
                    "csv_columns": ["チーム名", "設定項目", "値"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="TEA003",
                function_name="meeting_quality",
                category=TestCategory.TEAMS_MANAGEMENT,
                description="Teams会議品質分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["meetings_*.csv", "meetings_*.html"],
                test_data_requirements={
                    "meetings": 100,
                    "quality_metrics": 500
                },
                validation_rules={
                    "csv_columns": ["会議ID", "品質スコア", "参加者数"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="TEA004",
                function_name="teams_app_analysis",
                category=TestCategory.TEAMS_MANAGEMENT,
                description="Teamsアプリ分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["teamsapps_*.csv", "teamsapps_*.html"],
                test_data_requirements={
                    "apps": 30,
                    "usage_data": 200
                },
                validation_rules={
                    "csv_columns": ["アプリ名", "使用回数", "ユーザー数"],
                    "min_records": 1
                }
            ),
            
            # 💾 OneDrive管理 (4機能)
            PowerShellTestCase(
                test_id="OND001",
                function_name="onedrive_storage",
                category=TestCategory.ONEDRIVE_MANAGEMENT,
                description="OneDriveストレージ分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["OneDriveストレージ_*.csv", "OneDriveストレージ_*.html"],
                test_data_requirements={
                    "users": 50,
                    "storage_data": 100
                },
                validation_rules={
                    "csv_columns": ["ユーザー", "使用容量", "使用率"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="OND002",
                function_name="onedrive_sharing",
                category=TestCategory.ONEDRIVE_MANAGEMENT,
                description="OneDrive共有分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["OneDrive共有_*.csv", "OneDrive共有_*.html"],
                test_data_requirements={
                    "shared_files": 200,
                    "sharing_events": 100
                },
                validation_rules={
                    "csv_columns": ["ファイル", "共有先", "権限"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="OND003",
                function_name="sync_error_analysis",
                category=TestCategory.ONEDRIVE_MANAGEMENT,
                description="OneDrive同期エラー分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["同期エラー_*.csv", "同期エラー_*.html"],
                test_data_requirements={
                    "sync_errors": 50,
                    "users_affected": 20
                },
                validation_rules={
                    "csv_columns": ["ユーザー", "エラー種別", "発生日時"],
                    "min_records": 1
                }
            ),
            
            PowerShellTestCase(
                test_id="OND004",
                function_name="external_sharing_analysis",
                category=TestCategory.ONEDRIVE_MANAGEMENT,
                description="OneDrive外部共有分析テスト",
                powershell_script="Apps/GuiApp_Enhanced.ps1",
                expected_outputs=["external_*.csv", "external_*.html"],
                test_data_requirements={
                    "external_shares": 100,
                    "risk_level": "medium"
                },
                validation_rules={
                    "csv_columns": ["ファイル", "外部ユーザー", "リスクレベル"],
                    "min_records": 1
                }
            )
        ]
    
    @staticmethod
    def get_test_cases_by_category(category: TestCategory) -> List[PowerShellTestCase]:
        """カテゴリー別のテストケースを取得"""
        all_cases = PowerShellTestCaseDefinitions.get_all_test_cases()
        return [case for case in all_cases if case.category == category]
    
    @staticmethod
    def get_test_case_by_id(test_id: str) -> Optional[PowerShellTestCase]:
        """IDでテストケースを取得"""
        all_cases = PowerShellTestCaseDefinitions.get_all_test_cases()
        for case in all_cases:
            if case.test_id == test_id:
                return case
        return None
    
    @staticmethod
    def get_auth_required_tests() -> List[PowerShellTestCase]:
        """認証が必要なテストケースを取得"""
        all_cases = PowerShellTestCaseDefinitions.get_all_test_cases()
        return [case for case in all_cases if case.requires_auth]
    
    @staticmethod
    def get_mock_data_tests() -> List[PowerShellTestCase]:
        """モックデータ対応のテストケースを取得"""
        all_cases = PowerShellTestCaseDefinitions.get_all_test_cases()
        return [case for case in all_cases if case.mock_data_available]
    
    @staticmethod
    def generate_test_summary() -> Dict[str, Any]:
        """テストケースサマリーを生成"""
        all_cases = PowerShellTestCaseDefinitions.get_all_test_cases()
        
        category_counts = {}
        for category in TestCategory:
            category_counts[category.value] = len(
                PowerShellTestCaseDefinitions.get_test_cases_by_category(category)
            )
        
        return {
            "total_test_cases": len(all_cases),
            "category_breakdown": category_counts,
            "auth_required_count": len(PowerShellTestCaseDefinitions.get_auth_required_tests()),
            "mock_data_available_count": len(PowerShellTestCaseDefinitions.get_mock_data_tests()),
            "categories": [cat.value for cat in TestCategory]
        }


# テストケース検証用の共通フィクスチャとヘルパー
@pytest.fixture(scope="session")
def powershell_test_definitions():
    """PowerShellテストケース定義を提供"""
    return PowerShellTestCaseDefinitions()


@pytest.fixture(scope="function")
def sample_test_case():
    """サンプルテストケースを提供"""
    return PowerShellTestCase(
        test_id="TEST001",
        function_name="sample_function",
        category=TestCategory.REGULAR_REPORTS,
        description="サンプルテスト",
        powershell_script="test_script.ps1",
        expected_outputs=["output.csv"],
        test_data_requirements={"users": 10}
    )