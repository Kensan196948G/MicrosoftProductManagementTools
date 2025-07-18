"""
PowerShellとPythonの統合テスト
既存のPowerShellスクリプトとPython実装の互換性を確認するテストスイート
"""

import pytest
import json
import asyncio
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from typing import Dict, Any, List
import sys
import os

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from src.core.powershell_bridge import PowerShellBridge, PowerShellResult


@pytest.mark.compatibility
@pytest.mark.integration
class TestPowerShellIntegration:
    """PowerShellとPythonの統合テスト"""
    
    @pytest.fixture
    def project_root(self):
        """プロジェクトルートパス"""
        return Path(__file__).parent.parent.parent
    
    @pytest.fixture
    def mock_bridge(self, project_root):
        """テスト用PowerShellブリッジ"""
        with patch('src.core.powershell_bridge.subprocess.run') as mock_run:
            # PowerShell検出をモック
            mock_run.return_value = MagicMock(returncode=0, stdout="PowerShell 7.5.1")
            bridge = PowerShellBridge(project_root=project_root)
            return bridge, mock_run
    
    def test_entra_id_user_list_compatibility(self, mock_bridge):
        """Entra IDユーザー一覧の互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # PowerShellスクリプトの想定出力
        expected_powershell_output = {
            "Users": [
                {
                    "Id": "12345678-1234-1234-1234-123456789abc",
                    "DisplayName": "田中太郎",
                    "UserPrincipalName": "tanaka@example.com",
                    "Mail": "tanaka@example.com",
                    "JobTitle": "マネージャー",
                    "Department": "営業部",
                    "AccountEnabled": True,
                    "CreatedDateTime": "2023-01-15T09:30:00Z",
                    "SignInActivity": {
                        "LastSignInDateTime": "2024-07-18T08:45:00Z",
                        "LastNonInteractiveSignInDateTime": "2024-07-18T08:45:00Z"
                    }
                }
            ],
            "TotalCount": 1,
            "ReportGeneratedAt": "2024-07-18T12:00:00Z"
        }
        
        # PowerShell実行結果をモック
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_powershell_output),
            stderr=""
        )
        
        # PowerShellスクリプト実行
        result = bridge.execute_script("Scripts/EntraID/Get-EntraIDUsers.ps1")
        
        # 結果の検証
        assert result.success
        assert result.data["TotalCount"] == 1
        assert len(result.data["Users"]) == 1
        
        user = result.data["Users"][0]
        assert user["DisplayName"] == "田中太郎"
        assert user["UserPrincipalName"] == "tanaka@example.com"
        assert user["AccountEnabled"] is True
        
        # コマンドライン引数の検証
        call_args = mock_run.call_args
        assert "Get-EntraIDUsers.ps1" in str(call_args)
    
    def test_exchange_mailbox_compatibility(self, mock_bridge):
        """Exchange Onlineメールボックスの互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # PowerShellスクリプトの想定出力
        expected_output = {
            "Mailboxes": [
                {
                    "Identity": "tanaka@example.com",
                    "DisplayName": "田中太郎",
                    "PrimarySmtpAddress": "tanaka@example.com",
                    "RecipientTypeDetails": "UserMailbox",
                    "TotalItemSize": "2.5 GB (2,684,354,560 bytes)",
                    "ItemCount": 15432,
                    "ProhibitSendQuota": "50 GB (53,687,091,200 bytes)",
                    "UsagePercentage": 5.0,
                    "LastLogonTime": "2024-07-18T08:45:00Z"
                }
            ],
            "TotalCount": 1,
            "ReportGeneratedAt": "2024-07-18T12:00:00Z"
        }
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_output),
            stderr=""
        )
        
        # PowerShellスクリプト実行
        result = bridge.execute_script("Scripts/EXO/Get-ExchangeMailboxes.ps1")
        
        # 結果の検証
        assert result.success
        assert result.data["TotalCount"] == 1
        
        mailbox = result.data["Mailboxes"][0]
        assert mailbox["DisplayName"] == "田中太郎"
        assert mailbox["PrimarySmtpAddress"] == "tanaka@example.com"
        assert mailbox["UsagePercentage"] == 5.0
    
    def test_teams_usage_compatibility(self, mock_bridge):
        """Teams使用状況の互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # PowerShellスクリプトの想定出力
        expected_output = {
            "TeamsUsage": [
                {
                    "UserPrincipalName": "tanaka@example.com",
                    "DisplayName": "田中太郎",
                    "TeamsEnabled": True,
                    "LastActivityDate": "2024-07-18",
                    "TeamChatMessageCount": 45,
                    "CallCount": 12,
                    "MeetingCount": 8,
                    "HasOtherAction": True,
                    "ReportPeriod": "7 days"
                }
            ],
            "TotalCount": 1,
            "ReportGeneratedAt": "2024-07-18T12:00:00Z"
        }
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_output),
            stderr=""
        )
        
        # PowerShellスクリプト実行
        result = bridge.execute_script("Scripts/Teams/Get-TeamsUsage.ps1")
        
        # 結果の検証
        assert result.success
        assert result.data["TotalCount"] == 1
        
        usage = result.data["TeamsUsage"][0]
        assert usage["DisplayName"] == "田中太郎"
        assert usage["TeamsEnabled"] is True
        assert usage["TeamChatMessageCount"] == 45
    
    def test_onedrive_storage_compatibility(self, mock_bridge):
        """OneDriveストレージの互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # PowerShellスクリプトの想定出力
        expected_output = {
            "OneDriveUsage": [
                {
                    "UserPrincipalName": "tanaka@example.com",
                    "DisplayName": "田中太郎",
                    "StorageUsedInBytes": 5368709120,
                    "StorageAllocatedInBytes": 1099511627776,
                    "UsagePercentage": 0.49,
                    "FileCount": 2456,
                    "LastActivityDate": "2024-07-18",
                    "IsDeleted": False
                }
            ],
            "TotalCount": 1,
            "ReportGeneratedAt": "2024-07-18T12:00:00Z"
        }
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_output),
            stderr=""
        )
        
        # PowerShellスクリプト実行
        result = bridge.execute_script("Scripts/OneDrive/Get-OneDriveUsage.ps1")
        
        # 結果の検証
        assert result.success
        assert result.data["TotalCount"] == 1
        
        usage = result.data["OneDriveUsage"][0]
        assert usage["DisplayName"] == "田中太郎"
        assert usage["StorageUsedInBytes"] == 5368709120
        assert usage["UsagePercentage"] == 0.49
    
    def test_license_analysis_compatibility(self, mock_bridge):
        """ライセンス分析の互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # PowerShellスクリプトの想定出力
        expected_output = {
            "LicenseAnalysis": [
                {
                    "SkuPartNumber": "SPE_E5",
                    "SkuName": "Microsoft 365 E5",
                    "TotalLicenses": 100,
                    "AssignedLicenses": 85,
                    "AvailableLicenses": 15,
                    "UsagePercentage": 85.0,
                    "CostPerLicense": 5700.0,
                    "TotalCost": 570000.0,
                    "UnusedCost": 85500.0
                }
            ],
            "TotalCost": 570000.0,
            "TotalUnusedCost": 85500.0,
            "ReportGeneratedAt": "2024-07-18T12:00:00Z"
        }
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_output),
            stderr=""
        )
        
        # PowerShellスクリプト実行
        result = bridge.execute_script("Scripts/Common/Get-LicenseAnalysis.ps1")
        
        # 結果の検証
        assert result.success
        assert result.data["TotalCost"] == 570000.0
        assert result.data["TotalUnusedCost"] == 85500.0
        
        license_info = result.data["LicenseAnalysis"][0]
        assert license_info["SkuPartNumber"] == "SPE_E5"
        assert license_info["AssignedLicenses"] == 85
        assert license_info["UsagePercentage"] == 85.0
    
    def test_error_handling_compatibility(self, mock_bridge):
        """エラーハンドリングの互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # PowerShellエラーをモック
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="Connect-MgGraph: Authentication failed"
        )
        
        # PowerShellスクリプト実行
        result = bridge.execute_script("Scripts/EntraID/Get-EntraIDUsers.ps1")
        
        # エラーの検証
        assert not result.success
        assert "Authentication failed" in result.stderr
        assert result.returncode == 1
    
    @pytest.mark.requires_powershell
    def test_real_powershell_availability(self):
        """実際のPowerShell環境の可用性テスト"""
        try:
            bridge = PowerShellBridge()
            result = bridge.execute_command("Get-Host")
            assert result.success
        except RuntimeError as e:
            pytest.skip(f"PowerShell not available: {e}")
    
    def test_data_format_consistency(self, mock_bridge):
        """データフォーマットの一貫性テスト"""
        bridge, mock_run = mock_bridge
        
        # 日付フォーマットの一貫性
        expected_output = {
            "TestData": {
                "DateTime": "2024-07-18T12:00:00Z",
                "Date": "2024-07-18",
                "Time": "12:00:00"
            }
        }
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_output),
            stderr=""
        )
        
        result = bridge.execute_command("Get-TestData")
        
        # フォーマットの検証
        assert result.success
        test_data = result.data["TestData"]
        assert test_data["DateTime"].endswith("Z")  # ISO 8601 UTC
        assert len(test_data["Date"]) == 10  # YYYY-MM-DD
        assert len(test_data["Time"]) == 8   # HH:MM:SS
    
    def test_unicode_handling_compatibility(self, mock_bridge):
        """Unicode文字列の互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # Unicode文字を含むデータ
        expected_output = {
            "Users": [
                {
                    "DisplayName": "田中太郎",
                    "Department": "営業部",
                    "JobTitle": "マネージャー",
                    "Notes": "特殊文字: éñ中文🚀"
                }
            ]
        }
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_output, ensure_ascii=False),
            stderr=""
        )
        
        result = bridge.execute_command("Get-UsersWithUnicode")
        
        # Unicode文字の検証
        assert result.success
        user = result.data["Users"][0]
        assert user["DisplayName"] == "田中太郎"
        assert user["Department"] == "営業部"
        assert "🚀" in user["Notes"]
    
    @pytest.mark.parametrize("script_path,expected_fields", [
        ("Scripts/EntraID/Get-EntraIDUsers.ps1", ["Users", "TotalCount", "ReportGeneratedAt"]),
        ("Scripts/EXO/Get-ExchangeMailboxes.ps1", ["Mailboxes", "TotalCount", "ReportGeneratedAt"]),
        ("Scripts/Teams/Get-TeamsUsage.ps1", ["TeamsUsage", "TotalCount", "ReportGeneratedAt"]),
        ("Scripts/OneDrive/Get-OneDriveUsage.ps1", ["OneDriveUsage", "TotalCount", "ReportGeneratedAt"])
    ])
    def test_consistent_output_structure(self, mock_bridge, script_path, expected_fields):
        """一貫した出力構造のテスト"""
        bridge, mock_run = mock_bridge
        
        # 標準的な出力構造
        mock_output = {field: [] if field.endswith("s") else 0 if field == "TotalCount" else "2024-07-18T12:00:00Z" for field in expected_fields}
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(mock_output),
            stderr=""
        )
        
        result = bridge.execute_script(script_path)
        
        # 構造の検証
        assert result.success
        for field in expected_fields:
            assert field in result.data
    
    def test_performance_metrics_compatibility(self, mock_bridge):
        """パフォーマンスメトリクスの互換性テスト"""
        bridge, mock_run = mock_bridge
        
        # パフォーマンスメトリクスを含む出力
        expected_output = {
            "PerformanceMetrics": {
                "ExecutionTime": "00:00:02.1234567",
                "MemoryUsage": "125.4 MB",
                "ProcessedItems": 1000,
                "ItemsPerSecond": 471.7
            },
            "Data": {"Status": "Success"}
        }
        
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(expected_output),
            stderr=""
        )
        
        result = bridge.execute_command("Get-PerformanceData")
        
        # パフォーマンスメトリクスの検証
        assert result.success
        metrics = result.data["PerformanceMetrics"]
        assert "ExecutionTime" in metrics
        assert "MemoryUsage" in metrics
        assert metrics["ProcessedItems"] == 1000
        assert metrics["ItemsPerSecond"] == 471.7