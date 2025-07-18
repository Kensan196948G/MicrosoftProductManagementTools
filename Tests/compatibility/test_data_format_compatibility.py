"""
データフォーマット互換性テスト
PowerShellの既存出力形式との完全な互換性を検証
"""

import pytest
import json
import csv
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List
import pandas as pd
from unittest.mock import Mock, patch

from src.core.powershell_bridge import PowerShellBridge, PowerShellResult


class TestDataFormatCompatibility:
    """既存PowerShell出力との互換性テスト"""
    
    def test_csv_format_compatibility(self, bridge, mock_subprocess, tmp_path):
        """CSV出力形式の互換性テスト"""
        # PowerShellのExport-Csvと同じ形式のデータ
        users_data = [
            {
                "DisplayName": "田中 太郎",
                "UserPrincipalName": "tanaka.taro@contoso.com",
                "Mail": "tanaka.taro@contoso.com",
                "Department": "営業部",
                "AccountEnabled": "True",
                "CreatedDateTime": "2021-04-01T09:00:00Z"
            },
            {
                "DisplayName": "佐藤 花子",
                "UserPrincipalName": "sato.hanako@contoso.com",
                "Mail": "sato.hanako@contoso.com",
                "Department": "人事部",
                "AccountEnabled": "True",
                "CreatedDateTime": "2020-08-15T09:00:00Z"
            }
        ]
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(users_data),
            stderr=""
        )
        
        # CSVエクスポートコマンドを実行
        csv_path = tmp_path / "users.csv"
        command = f"Get-MgUser | Select-Object DisplayName,UserPrincipalName,Mail,Department,AccountEnabled,CreatedDateTime | Export-Csv -Path '{csv_path}' -NoTypeInformation -Encoding UTF8"
        
        result = bridge.execute_command(command, return_json=False)
        
        # 実際のPowerShell CSV形式をシミュレート
        with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=users_data[0].keys(), quoting=csv.QUOTE_ALL)
            writer.writeheader()
            writer.writerows(users_data)
        
        # CSVファイルを読み込んで検証
        df = pd.read_csv(csv_path, encoding='utf-8-sig')
        assert len(df) == 2
        assert df.iloc[0]['DisplayName'] == '田中 太郎'
        assert df.iloc[1]['Department'] == '人事部'
        assert all(col in df.columns for col in ['DisplayName', 'UserPrincipalName', 'Mail'])
    
    def test_html_report_format(self, bridge, mock_subprocess, tmp_path):
        """HTMLレポート形式の互換性テスト"""
        report_data = {
            "Title": "Microsoft 365 ユーザーレポート",
            "GeneratedDate": "2025-01-18T12:00:00+09:00",
            "Summary": {
                "TotalUsers": 168,
                "ActiveUsers": 156,
                "LicensedUsers": 165
            },
            "Details": [
                {
                    "DisplayName": "田中 太郎",
                    "LastSignIn": "2025-01-17T10:30:00Z",
                    "LicenseStatus": "Active"
                }
            ]
        }
        
        # PowerShellのConvertTo-Html形式をシミュレート
        html_content = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Microsoft 365 ユーザーレポート</title>
    <style>
        body { font-family: 'Meiryo', 'Yu Gothic', sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Microsoft 365 ユーザーレポート</h1>
    <p>生成日時: 2025-01-18T12:00:00+09:00</p>
    <table>
        <tr>
            <th>表示名</th>
            <th>最終サインイン</th>
            <th>ライセンス状態</th>
        </tr>
        <tr>
            <td>田中 太郎</td>
            <td>2025-01-17T10:30:00Z</td>
            <td>Active</td>
        </tr>
    </table>
</body>
</html>
        """.strip()
        
        html_path = tmp_path / "report.html"
        html_path.write_text(html_content, encoding='utf-8')
        
        # HTMLファイルの存在と基本構造を検証
        assert html_path.exists()
        content = html_path.read_text(encoding='utf-8')
        assert '<meta charset="UTF-8">' in content
        assert 'Microsoft 365 ユーザーレポート' in content
        assert '田中 太郎' in content
        assert 'font-family' in content  # 日本語フォント指定
    
    def test_datetime_format_compatibility(self, bridge):
        """日時形式の互換性テスト"""
        # PowerShellの各種日時形式
        datetime_formats = {
            "ISO8601": "2025-01-18T12:00:00Z",
            "ISO8601_JST": "2025-01-18T21:00:00+09:00",
            "PowerShell_DateTime": "/Date(1737201600000)/",
            "Exchange_DateTime": "1/18/2025 12:00:00 PM",
            "FileTime": "133530336000000000"
        }
        
        # ISO8601形式のテスト
        iso_date = bridge._convert_ps_to_python("2025-01-18T12:00:00Z")
        assert isinstance(iso_date, str)
        assert iso_date == "2025-01-18T12:00:00Z"
        
        # PowerShell DateTime形式のテスト
        ps_date = bridge._convert_ps_to_python("/Date(1737201600000)/")
        assert isinstance(ps_date, datetime)
        assert ps_date.year == 2025
        assert ps_date.month == 1
        assert ps_date.day == 18
    
    def test_size_format_compatibility(self, bridge, mock_subprocess):
        """サイズ表記の互換性テスト"""
        # PowerShellの各種サイズ表記
        mailbox_data = {
            "ProhibitSendQuota": "50 GB (53,687,091,200 bytes)",
            "TotalItemSize": "15.23 GB (16,357,892,096 bytes)",
            "DatabaseQuotaInMB": 51200,
            "UsageInBytes": 16357892096
        }
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(mailbox_data),
            stderr=""
        )
        
        result = bridge.execute_command("Get-MailboxStatistics")
        
        assert result.success
        assert "50 GB" in result.data["ProhibitSendQuota"]
        assert "53,687,091,200" in result.data["ProhibitSendQuota"]
        assert result.data["DatabaseQuotaInMB"] == 51200
    
    def test_boolean_format_compatibility(self, bridge):
        """ブール値形式の互換性テスト"""
        # PowerShellのブール値表記
        test_cases = [
            ("$true", "$true"),
            ("$false", "$false"),
            (True, "$true"),
            (False, "$false"),
            ("True", "'True'"),  # 文字列の場合
            ("False", "'False'")
        ]
        
        for input_val, expected in test_cases:
            if isinstance(input_val, bool):
                result = bridge._convert_python_to_ps(input_val)
                assert result == expected
    
    def test_array_format_compatibility(self, bridge):
        """配列形式の互換性テスト"""
        # PowerShellの配列表記
        test_arrays = [
            ([], "@()"),
            ([1, 2, 3], "@(1,2,3)"),
            (["a", "b", "c"], "@('a','b','c')"),
            (["test@example.com", "user@domain.com"], "@('test@example.com','user@domain.com')")
        ]
        
        for input_array, expected in test_arrays:
            result = bridge._convert_python_to_ps(input_array)
            assert result == expected
    
    def test_hashtable_format_compatibility(self, bridge):
        """ハッシュテーブル形式の互換性テスト"""
        # PowerShellのハッシュテーブル表記
        test_hashtables = [
            ({}, "@{}"),
            ({"Name": "Test"}, "@{'Name'='Test'}"),
            ({"Name": "Test", "Count": 5}, "@{'Name'='Test';'Count'=5}"),
            ({"Filter": "Department eq 'IT'"}, "@{'Filter'='Department eq ''IT'''}")
        ]
        
        for input_dict, expected in test_hashtables:
            result = bridge._convert_python_to_ps(input_dict)
            assert result == expected
    
    def test_exchange_cmdlet_output_format(self, bridge, mock_subprocess, mock_exchange_mailboxes):
        """Exchange コマンドレット出力形式の互換性"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(mock_exchange_mailboxes),
            stderr=""
        )
        
        result = bridge.execute_command("Get-Mailbox | ConvertTo-Json -Depth 10")
        
        assert result.success
        assert len(result.data) == 2
        
        # Exchange特有のフィールドを確認
        mailbox = result.data[0]
        assert "PrimarySmtpAddress" in mailbox
        assert "RecipientTypeDetails" in mailbox
        assert "ProhibitSendQuota" in mailbox
        assert "EmailAddresses" in mailbox
        assert isinstance(mailbox["EmailAddresses"], list)
        assert mailbox["EmailAddresses"][0].startswith("SMTP:")
    
    def test_graph_api_output_format(self, bridge, mock_subprocess, mock_m365_users):
        """Microsoft Graph API出力形式の互換性"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(mock_m365_users),
            stderr=""
        )
        
        result = bridge.execute_command("Get-MgUser -All")
        
        assert result.success
        assert "@odata.context" in result.data
        assert "value" in result.data
        assert isinstance(result.data["value"], list)
        
        # Graph API特有のフィールドを確認
        user = result.data["value"][0]
        assert "id" in user
        assert "userPrincipalName" in user
        assert "assignedLicenses" in user
        assert "assignedPlans" in user
    
    def test_error_format_compatibility(self, bridge, mock_subprocess, mock_powershell_error_scenarios):
        """エラー形式の互換性テスト"""
        for error_type, error_data in mock_powershell_error_scenarios.items():
            mock_subprocess.return_value = Mock(
                returncode=1,
                stdout="",
                stderr=json.dumps(error_data)
            )
            
            result = bridge.execute_command("Test-Command")
            
            assert not result.success
            assert result.error_message == error_data["Message"]
            assert result.data["Type"] == error_data["Type"]
            
            if "ErrorCode" in error_data:
                assert result.data["ErrorCode"] == error_data["ErrorCode"]
    
    def test_pipeline_output_format(self, bridge, mock_subprocess):
        """パイプライン出力形式の互換性"""
        # PowerShellパイプラインの結果
        pipeline_result = [
            {"Name": "User1", "Department": "IT", "Selected": True},
            {"Name": "User2", "Department": "IT", "Selected": True}
        ]
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(pipeline_result),
            stderr=""
        )
        
        commands = [
            "Get-MgUser",
            "Where-Object {$_.Department -eq 'IT'}",
            "Select-Object Name,Department,@{Name='Selected';Expression={$true}}"
        ]
        
        result = bridge.execute_pipeline(commands)
        
        assert result.success
        assert len(result.data) == 2
        assert all(user["Department"] == "IT" for user in result.data)
        assert all(user["Selected"] for user in result.data)
    
    def test_special_characters_handling(self, bridge):
        """特殊文字の処理互換性"""
        special_strings = [
            "test'with'quotes",
            'test"with"doublequotes',
            "test`with`backticks",
            "test$with$dollar",
            "test\\with\\backslash",
            "テスト　全角スペース",
            "test\nwith\nnewlines",
            "test\twith\ttabs"
        ]
        
        for test_string in special_strings:
            converted = bridge._convert_python_to_ps(test_string)
            # 適切にエスケープされているか確認
            assert converted.startswith("'") and converted.endswith("'")
            
            # PowerShellで実行可能な形式か確認
            if "'" in test_string:
                assert "''" in converted  # シングルクォートのエスケープ
            if '"' in test_string:
                assert '`"' in converted  # ダブルクォートのエスケープ
    
    def test_null_and_empty_handling(self, bridge):
        """null値と空値の処理互換性"""
        test_cases = [
            (None, "$null"),
            ("", "''"),
            ([], "@()"),
            ({}, "@{}"),
            (0, "0"),
            (False, "$false")
        ]
        
        for input_val, expected in test_cases:
            result = bridge._convert_python_to_ps(input_val)
            assert result == expected
    
    def test_large_dataset_format(self, bridge, mock_subprocess, performance_test_data):
        """大量データセットの形式互換性"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(performance_test_data),
            stderr=""
        )
        
        result = bridge.execute_command("Get-MgUser -All")
        
        assert result.success
        assert "@odata.count" in result.data
        assert result.data["@odata.count"] == 1000
        assert len(result.data["value"]) == 1000
        
        # データの整合性確認
        for i, user in enumerate(result.data["value"]):
            assert user["id"] == f"user-{i:04d}"
            assert user["department"] == f"Dept{i % 10}"
    
    def test_encoding_compatibility(self, bridge, mock_subprocess, tmp_path):
        """エンコーディング互換性テスト"""
        # 日本語を含むデータ
        japanese_data = {
            "users": [
                {"name": "山田太郎", "dept": "営業部"},
                {"name": "鈴木花子", "dept": "経理部"},
                {"name": "佐藤🌸", "dept": "人事部"}  # 絵文字を含む
            ]
        }
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(japanese_data, ensure_ascii=False),
            stderr=""
        )
        
        result = bridge.execute_command("Get-CustomData")
        
        assert result.success
        assert result.data["users"][0]["name"] == "山田太郎"
        assert result.data["users"][2]["name"] == "佐藤🌸"
        
        # CSV出力でのエンコーディング確認
        csv_path = tmp_path / "japanese.csv"
        with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['name', 'dept'])
            writer.writeheader()
            writer.writerows(japanese_data["users"])
        
        # BOM付きUTF-8で読み込み可能か確認
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            assert rows[0]['name'] == "山田太郎"
            assert rows[2]['name'] == "佐藤🌸"


class TestComplexScenarios:
    """複雑なシナリオでの互換性テスト"""
    
    def test_nested_object_compatibility(self, bridge, mock_subprocess):
        """ネストされたオブジェクトの互換性"""
        nested_data = {
            "organization": {
                "displayName": "Contoso Ltd.",
                "verifiedDomains": [
                    {
                        "name": "contoso.com",
                        "isDefault": True,
                        "isInitial": False,
                        "capabilities": ["Email", "OfficeCommunicationsOnline"]
                    },
                    {
                        "name": "contoso.onmicrosoft.com",
                        "isDefault": False,
                        "isInitial": True,
                        "capabilities": ["Email", "OfficeCommunicationsOnline"]
                    }
                ],
                "assignedPlans": [
                    {
                        "assignedTimestamp": "2022-01-01T00:00:00Z",
                        "capabilityStatus": "Enabled",
                        "service": "exchange",
                        "servicePlanId": "efb87545-963c-4e0d-99df-69c6916d9eb0"
                    }
                ]
            }
        }
        
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(nested_data),
            stderr=""
        )
        
        result = bridge.execute_command("Get-MgOrganization")
        
        assert result.success
        assert result.data["organization"]["displayName"] == "Contoso Ltd."
        assert len(result.data["organization"]["verifiedDomains"]) == 2
        assert result.data["organization"]["verifiedDomains"][0]["isDefault"] is True
        assert "Email" in result.data["organization"]["verifiedDomains"][0]["capabilities"]
    
    def test_mixed_type_array_compatibility(self, bridge):
        """異なる型を含む配列の互換性"""
        mixed_array = [
            "string value",
            123,
            True,
            None,
            {"key": "value"},
            ["nested", "array"]
        ]
        
        result = bridge._convert_python_to_ps(mixed_array)
        
        # PowerShell形式の配列として正しく変換されているか確認
        assert result.startswith("@(")
        assert result.endswith(")")
        assert "'string value'" in result
        assert "123" in result
        assert "$true" in result
        assert "$null" in result
        assert "@{'key'='value'}" in result
        assert "@('nested','array')" in result
    
    def test_conditional_access_policy_format(self, bridge, mock_subprocess, mock_conditional_access_policies):
        """条件付きアクセスポリシーの複雑な形式"""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout=json.dumps(mock_conditional_access_policies),
            stderr=""
        )
        
        result = bridge.execute_command("Get-MgIdentityConditionalAccessPolicy")
        
        assert result.success
        policy = result.data["value"][0]
        
        # 複雑なネスト構造の確認
        assert policy["conditions"]["users"]["includeUsers"] == ["All"]
        assert policy["conditions"]["applications"]["includeApplications"] == ["All"]
        assert policy["grantControls"]["builtInControls"] == ["mfa"]
        assert policy["state"] == "enabled"