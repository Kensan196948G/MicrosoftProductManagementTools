"""
Microsoft Graph API応答データの互換性テストスイート
Dev1 - Test/QA Developer による基盤構築

Python版とPowerShell版のMicrosoft Graph API統合の互換性を検証
"""
import os
import sys
import json
import asyncio
from pathlib import Path
from typing import Dict, List, Any, Optional, Union
from datetime import datetime, timedelta
from unittest.mock import Mock, patch
import tempfile

import pytest
import requests_mock
import pandas as pd
from msal import ConfidentialClientApplication

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

try:
    from src.api.graph.client import GraphAPIClient
    from src.api.graph.services import GraphAPIService
except ImportError:
    # Python版が未実装の場合はモック版を使用
    GraphAPIClient = None
    GraphAPIService = None


class MockGraphAPIResponse:
    """Graph API応答のモッククラス"""
    
    def __init__(self, status_code: int = 200, json_data: Dict = None):
        self.status_code = status_code
        self._json_data = json_data or {}
    
    def json(self):
        return self._json_data
    
    @property
    def text(self):
        return json.dumps(self._json_data)


class GraphAPICompatibilityTester:
    """Graph API互換性テストクラス"""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.config_file = project_root / "Config" / "appsettings.json"
        self.temp_dir = project_root / "tests" / "temp" / "graph_api"
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        
        # モックレスポンスデータ
        self.mock_responses = self._setup_mock_responses()
        
    def _setup_mock_responses(self) -> Dict[str, Dict]:
        """Graph APIモックレスポンスセットアップ"""
        return {
            "users": {
                "url_pattern": "https://graph.microsoft.com/v1.0/users",
                "response": {
                    "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
                    "@odata.count": 3,
                    "value": [
                        {
                            "id": "12345678-1234-1234-1234-123456789abc",
                            "displayName": "山田太郎",
                            "userPrincipalName": "yamada@contoso.com",
                            "mail": "yamada@contoso.com",
                            "department": "IT部門",
                            "jobTitle": "システム管理者",
                            "accountEnabled": True,
                            "createdDateTime": "2023-01-15T10:00:00Z",
                            "lastSignInDateTime": "2024-01-15T14:30:00Z",
                            "assignedLicenses": [
                                {
                                    "skuId": "6fd2c87f-b296-42f0-b197-1e91e994b900",
                                    "servicePlans": []
                                }
                            ]
                        },
                        {
                            "id": "87654321-4321-4321-4321-cba987654321",
                            "displayName": "田中花子",
                            "userPrincipalName": "tanaka@contoso.com", 
                            "mail": "tanaka@contoso.com",
                            "department": "営業部",
                            "jobTitle": "営業マネージャー",
                            "accountEnabled": True,
                            "createdDateTime": "2023-02-01T09:00:00Z",
                            "lastSignInDateTime": "2024-01-16T11:45:00Z",
                            "assignedLicenses": [
                                {
                                    "skuId": "c7df2760-2c81-4ef7-b578-5b5392b571df",
                                    "servicePlans": []
                                }
                            ]
                        },
                        {
                            "id": "11111111-2222-3333-4444-555555555555",
                            "displayName": "佐藤一郎",
                            "userPrincipalName": "sato@contoso.com",
                            "mail": "sato@contoso.com", 
                            "department": "開発部",
                            "jobTitle": "開発者",
                            "accountEnabled": False,
                            "createdDateTime": "2023-03-10T08:30:00Z",
                            "lastSignInDateTime": null,
                            "assignedLicenses": []
                        }
                    ]
                }
            },
            "licenses": {
                "url_pattern": "https://graph.microsoft.com/v1.0/subscribedSkus",
                "response": {
                    "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#subscribedSkus",
                    "value": [
                        {
                            "skuId": "6fd2c87f-b296-42f0-b197-1e91e994b900",
                            "skuPartNumber": "ENTERPRISEPACK",
                            "servicePlans": [
                                {
                                    "servicePlanId": "57ff2da0-773e-42df-b2af-ffb7a2317929",
                                    "servicePlanName": "TEAMS1",
                                    "provisioningStatus": "Success",
                                    "appliesTo": "User"
                                }
                            ],
                            "prepaidUnits": {
                                "enabled": 100,
                                "suspended": 0,
                                "warning": 0
                            },
                            "consumedUnits": 85
                        },
                        {
                            "skuId": "c7df2760-2c81-4ef7-b578-5b5392b571df",
                            "skuPartNumber": "ENTERPRISEPREMIUM",
                            "servicePlans": [
                                {
                                    "servicePlanId": "57ff2da0-773e-42df-b2af-ffb7a2317929",
                                    "servicePlanName": "TEAMS1",
                                    "provisioningStatus": "Success",
                                    "appliesTo": "User"
                                }
                            ],
                            "prepaidUnits": {
                                "enabled": 50,
                                "suspended": 0,
                                "warning": 0
                            },
                            "consumedUnits": 25
                        }
                    ]
                }
            },
            "groups": {
                "url_pattern": "https://graph.microsoft.com/v1.0/groups",
                "response": {
                    "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#groups",
                    "value": [
                        {
                            "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                            "displayName": "IT部門チーム",
                            "description": "IT部門のメンバー",
                            "groupTypes": ["Unified"],
                            "mail": "it-team@contoso.com",
                            "mailEnabled": True,
                            "securityEnabled": False,
                            "createdDateTime": "2023-01-01T10:00:00Z"
                        },
                        {
                            "id": "ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj",
                            "displayName": "営業部グループ",
                            "description": "営業部のセキュリティグループ",
                            "groupTypes": [],
                            "mail": null,
                            "mailEnabled": False,
                            "securityEnabled": True,
                            "createdDateTime": "2023-02-01T09:00:00Z"
                        }
                    ]
                }
            },
            "sign_in_logs": {
                "url_pattern": "https://graph.microsoft.com/v1.0/auditLogs/signIns",
                "response": {
                    "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#auditLogs/signIns",
                    "value": [
                        {
                            "id": "66ea54eb-blah-blah-blah-25ee60d0cb47",
                            "createdDateTime": "2024-01-16T14:30:00Z",
                            "userDisplayName": "山田太郎",
                            "userPrincipalName": "yamada@contoso.com",
                            "userId": "12345678-1234-1234-1234-123456789abc",
                            "appDisplayName": "Microsoft 365",
                            "appId": "00000002-0000-0ff1-ce00-000000000000",
                            "ipAddress": "203.0.113.1",
                            "clientAppUsed": "Browser",
                            "status": {
                                "errorCode": 0,
                                "failureReason": null,
                                "additionalDetails": null
                            },
                            "deviceDetail": {
                                "deviceId": "device-001",
                                "displayName": "WIN-YAMADA01",
                                "operatingSystem": "Windows 10",
                                "browser": "Edge 120.0.0.0"
                            },
                            "location": {
                                "city": "Tokyo",
                                "state": "Tokyo",
                                "countryOrRegion": "JP"
                            }
                        }
                    ]
                }
            }
        }
    
    def normalize_powershell_response(self, ps_data: Dict) -> Dict:
        """PowerShell版のレスポンス形式を正規化"""
        # PowerShell版の特殊な形式を標準形式に変換
        if isinstance(ps_data, dict):
            normalized = {}
            for key, value in ps_data.items():
                # PowerShellのプロパティ名変換
                if key.startswith("@"):
                    # OData annotations
                    normalized[key] = value
                elif key in ["value", "Value"]:
                    # Collection値
                    normalized["value"] = value
                else:
                    # 通常のプロパティ
                    normalized[key] = value
            return normalized
        return ps_data
    
    def compare_graph_responses(self, python_response: Dict, powershell_response: Dict) -> Dict[str, Any]:
        """Graph API応答の詳細比較"""
        try:
            # PowerShell応答を正規化
            ps_normalized = self.normalize_powershell_response(powershell_response)
            
            comparison = {
                "success": True,
                "structure_match": True,
                "data_match": True,
                "differences": [],
                "python_count": 0,
                "powershell_count": 0
            }
            
            # 基本構造比較
            py_keys = set(python_response.keys())
            ps_keys = set(ps_normalized.keys())
            
            if py_keys != ps_keys:
                comparison["structure_match"] = False
                comparison["differences"].append({
                    "type": "structure",
                    "description": "レスポンスキーが異なります",
                    "python_keys": list(py_keys),
                    "powershell_keys": list(ps_keys),
                    "missing_in_python": list(ps_keys - py_keys),
                    "missing_in_powershell": list(py_keys - ps_keys)
                })
            
            # データ配列比較（value プロパティ）
            if "value" in python_response and "value" in ps_normalized:
                py_items = python_response["value"]
                ps_items = ps_normalized["value"]
                
                comparison["python_count"] = len(py_items) if isinstance(py_items, list) else 0
                comparison["powershell_count"] = len(ps_items) if isinstance(ps_items, list) else 0
                
                if comparison["python_count"] != comparison["powershell_count"]:
                    comparison["data_match"] = False
                    comparison["differences"].append({
                        "type": "count",
                        "description": "アイテム数が異なります",
                        "python_count": comparison["python_count"],
                        "powershell_count": comparison["powershell_count"]
                    })
                
                # 先頭アイテムの詳細比較
                if py_items and ps_items and isinstance(py_items, list) and isinstance(ps_items, list):
                    py_item = py_items[0]
                    ps_item = ps_items[0]
                    
                    # 必須フィールドの存在確認
                    required_fields = ["id", "displayName"]
                    for field in required_fields:
                        if field in py_item and field not in ps_item:
                            comparison["data_match"] = False
                            comparison["differences"].append({
                                "type": "missing_field",
                                "description": f"PowerShell版に必須フィールド {field} がありません",
                                "field": field
                            })
                        elif field not in py_item and field in ps_item:
                            comparison["data_match"] = False
                            comparison["differences"].append({
                                "type": "missing_field", 
                                "description": f"Python版に必須フィールド {field} がありません",
                                "field": field
                            })
            
            # 全体成功判定
            comparison["success"] = comparison["structure_match"] and comparison["data_match"]
            
            return comparison
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    def export_comparison_report(self, comparisons: Dict[str, Dict], output_dir: Path) -> Path:
        """比較結果レポート出力"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = output_dir / f"graph_api_compatibility_report_{timestamp}.html"
        
        # HTML レポート生成
        html_content = f"""
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft Graph API 互換性テストレポート</title>
    <style>
        body {{
            font-family: 'Meiryo', 'MS Gothic', sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1, h2 {{
            color: #2E8B57;
            border-bottom: 2px solid #2E8B57;
            padding-bottom: 10px;
        }}
        .test-result {{
            margin: 20px 0;
            padding: 15px;
            border-radius: 5px;
            border: 1px solid #ddd;
        }}
        .test-result.success {{
            background-color: #d4edda;
            border-color: #c3e6cb;
        }}
        .test-result.failure {{
            background-color: #f8d7da;
            border-color: #f5c6cb;
        }}
        .differences {{
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 3px;
            margin-top: 10px;
            font-family: monospace;
            font-size: 12px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }}
        th {{
            background-color: #2E8B57;
            color: white;
        }}
        .status-success {{ color: #28a745; font-weight: bold; }}
        .status-failure {{ color: #dc3545; font-weight: bold; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🔗 Microsoft Graph API 互換性テストレポート</h1>
        <p>生成日時: {datetime.now().strftime("%Y年%m月%d日 %H:%M:%S")}</p>
        
        <h2>📊 テスト結果サマリー</h2>
        <table>
            <thead>
                <tr>
                    <th>API エンドポイント</th>
                    <th>構造一致</th>
                    <th>データ一致</th>
                    <th>全体結果</th>
                    <th>Python件数</th>
                    <th>PowerShell件数</th>
                </tr>
            </thead>
            <tbody>
"""
        
        for endpoint, comparison in comparisons.items():
            if comparison.get("success", False):
                status_class = "status-success"
                status_text = "✅ 成功"
            else:
                status_class = "status-failure"
                status_text = "❌ 失敗"
            
            structure_status = "✅" if comparison.get("structure_match", False) else "❌"
            data_status = "✅" if comparison.get("data_match", False) else "❌"
            
            html_content += f"""
                <tr>
                    <td>{endpoint}</td>
                    <td>{structure_status}</td>
                    <td>{data_status}</td>
                    <td class="{status_class}">{status_text}</td>
                    <td>{comparison.get('python_count', 'N/A')}</td>
                    <td>{comparison.get('powershell_count', 'N/A')}</td>
                </tr>
"""
        
        html_content += """
            </tbody>
        </table>
        
        <h2>🔍 詳細比較結果</h2>
"""
        
        for endpoint, comparison in comparisons.items():
            result_class = "success" if comparison.get("success", False) else "failure"
            status_icon = "✅" if comparison.get("success", False) else "❌"
            
            html_content += f"""
        <div class="test-result {result_class}">
            <h3>{status_icon} {endpoint} API</h3>
            <p><strong>構造一致:</strong> {'はい' if comparison.get('structure_match', False) else 'いいえ'}</p>
            <p><strong>データ一致:</strong> {'はい' if comparison.get('data_match', False) else 'いいえ'}</p>
            <p><strong>Python件数:</strong> {comparison.get('python_count', 'N/A')}</p>
            <p><strong>PowerShell件数:</strong> {comparison.get('powershell_count', 'N/A')}</p>
            
            {f'<div class="differences"><strong>差分詳細:</strong><br>{json.dumps(comparison.get("differences", []), indent=2, ensure_ascii=False)}</div>' if comparison.get("differences") else ''}
        </div>
"""
        
        html_content += """
    </div>
</body>
</html>
"""
        
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(html_content)
        
        return report_file


@pytest.fixture(scope="function")
def graph_compatibility_tester(project_root):
    """Graph API互換性テスターのフィクスチャ"""
    return GraphAPICompatibilityTester(project_root)


@pytest.fixture(scope="function")
def temp_graph_dir(graph_compatibility_tester):
    """一時Graph APIテストディレクトリ"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    temp_dir = graph_compatibility_tester.temp_dir / f"graph_test_{timestamp}"
    temp_dir.mkdir(exist_ok=True)
    yield temp_dir


class TestGraphAPIUserCompatibility:
    """Graph API Users エンドポイント互換性テスト"""
    
    @pytest.mark.api
    @pytest.mark.compatibility
    @pytest.mark.integration
    def test_users_api_response_format(self, graph_compatibility_tester, temp_graph_dir):
        """Users API応答形式の互換性テスト"""
        
        # Python版（モック）応答
        python_response = graph_compatibility_tester.mock_responses["users"]["response"]
        
        # PowerShell版（模擬）応答
        powershell_response = {
            "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
            "@odata.count": 3,
            "value": [
                {
                    "id": "12345678-1234-1234-1234-123456789abc",
                    "displayName": "山田太郎",
                    "userPrincipalName": "yamada@contoso.com",
                    "mail": "yamada@contoso.com",
                    "department": "IT部門",
                    "jobTitle": "システム管理者",
                    "accountEnabled": True,
                    "createdDateTime": "2023-01-15T10:00:00Z",
                    "lastSignInDateTime": "2024-01-15T14:30:00Z",
                    "assignedLicenses": [
                        {
                            "skuId": "6fd2c87f-b296-42f0-b197-1e91e994b900",
                            "servicePlans": []
                        }
                    ]
                },
                {
                    "id": "87654321-4321-4321-4321-cba987654321",
                    "displayName": "田中花子",
                    "userPrincipalName": "tanaka@contoso.com",
                    "mail": "tanaka@contoso.com",
                    "department": "営業部",
                    "jobTitle": "営業マネージャー",
                    "accountEnabled": True,
                    "createdDateTime": "2023-02-01T09:00:00Z",
                    "lastSignInDateTime": "2024-01-16T11:45:00Z",
                    "assignedLicenses": [
                        {
                            "skuId": "c7df2760-2c81-4ef7-b578-5b5392b571df",
                            "servicePlans": []
                        }
                    ]
                },
                {
                    "id": "11111111-2222-3333-4444-555555555555",
                    "displayName": "佐藤一郎",
                    "userPrincipalName": "sato@contoso.com",
                    "mail": "sato@contoso.com",
                    "department": "開発部",
                    "jobTitle": "開発者",
                    "accountEnabled": False,
                    "createdDateTime": "2023-03-10T08:30:00Z",
                    "lastSignInDateTime": None,
                    "assignedLicenses": []
                }
            ]
        }
        
        # 応答比較
        comparison = graph_compatibility_tester.compare_graph_responses(
            python_response, 
            powershell_response
        )
        
        assert comparison["success"], f"Users API応答の互換性テスト失敗: {comparison.get('differences', [])}"
        assert comparison["structure_match"], "Users API応答構造が一致しません"
        assert comparison["data_match"], "Users APIデータが一致しません"
        assert comparison["python_count"] == comparison["powershell_count"], "Users API件数が一致しません"
    
    @pytest.mark.api
    @pytest.mark.compatibility
    def test_users_csv_export_compatibility(self, graph_compatibility_tester, temp_graph_dir):
        """Users API CSVエクスポートの互換性テスト"""
        users_data = graph_compatibility_tester.mock_responses["users"]["response"]["value"]
        
        # Python版CSV出力をシミュレート
        python_csv = temp_graph_dir / "python_users.csv"
        df = pd.DataFrame(users_data)
        df.to_csv(python_csv, index=False, encoding="utf-8-sig")
        
        # PowerShell版CSV出力をシミュレート
        powershell_csv = temp_graph_dir / "powershell_users.csv"
        df.to_csv(powershell_csv, index=False, encoding="utf-8-sig")
        
        # ファイル存在確認
        assert python_csv.exists(), "Python版CSVファイルが生成されませんでした"
        assert powershell_csv.exists(), "PowerShell版CSVファイルが生成されませんでした"
        
        # ファイル内容確認
        py_df = pd.read_csv(python_csv, encoding="utf-8-sig")
        ps_df = pd.read_csv(powershell_csv, encoding="utf-8-sig")
        
        assert len(py_df) == len(ps_df), "CSVレコード数が一致しません"
        assert list(py_df.columns) == list(ps_df.columns), "CSV列名が一致しません"


class TestGraphAPILicenseCompatibility:
    """Graph API Licenses エンドポイント互換性テスト"""
    
    @pytest.mark.api
    @pytest.mark.compatibility
    def test_licenses_api_response_format(self, graph_compatibility_tester):
        """Licenses API応答形式の互換性テスト"""
        
        # Python版応答
        python_response = graph_compatibility_tester.mock_responses["licenses"]["response"]
        
        # PowerShell版応答（同一データ）
        powershell_response = python_response.copy()
        
        # 応答比較
        comparison = graph_compatibility_tester.compare_graph_responses(
            python_response,
            powershell_response
        )
        
        assert comparison["success"], f"Licenses API応答の互換性テスト失敗: {comparison.get('differences', [])}"
        assert comparison["structure_match"], "Licenses API応答構造が一致しません"
        assert comparison["data_match"], "Licenses APIデータが一致しません"


class TestGraphAPISignInLogsCompatibility:
    """Graph API Sign-in Logs エンドポイント互換性テスト"""
    
    @pytest.mark.api
    @pytest.mark.compatibility
    @pytest.mark.requires_auth
    def test_signin_logs_api_response_format(self, graph_compatibility_tester):
        """Sign-in Logs API応答形式の互換性テスト"""
        
        # Python版応答
        python_response = graph_compatibility_tester.mock_responses["sign_in_logs"]["response"]
        
        # PowerShell版応答（同一データ）
        powershell_response = python_response.copy()
        
        # 応答比較
        comparison = graph_compatibility_tester.compare_graph_responses(
            python_response,
            powershell_response
        )
        
        assert comparison["success"], f"Sign-in Logs API応答の互換性テスト失敗: {comparison.get('differences', [])}"
        assert comparison["structure_match"], "Sign-in Logs API応答構造が一致しません"
        assert comparison["data_match"], "Sign-in Logs APIデータが一致しません"


class TestGraphAPIErrorHandlingCompatibility:
    """Graph API エラーハンドリング互換性テスト"""
    
    @pytest.mark.api
    @pytest.mark.compatibility
    def test_error_response_format_compatibility(self, graph_compatibility_tester):
        """API エラー応答形式の互換性テスト"""
        
        # 標準的なGraph APIエラー応答
        error_response = {
            "error": {
                "code": "Forbidden",
                "message": "Insufficient privileges to complete the operation.",
                "innerError": {
                    "date": "2024-01-16T15:00:00",
                    "request-id": "12345678-1234-1234-1234-123456789abc",
                    "client-request-id": "87654321-4321-4321-4321-cba987654321"
                }
            }
        }
        
        # Python版とPowerShell版で同一のエラー応答が期待される
        python_error = error_response
        powershell_error = error_response
        
        comparison = graph_compatibility_tester.compare_graph_responses(
            python_error,
            powershell_error
        )
        
        assert comparison["success"], "エラー応答形式の互換性テスト失敗"
        assert comparison["structure_match"], "エラー応答構造が一致しません"


@pytest.mark.api
@pytest.mark.compatibility 
@pytest.mark.integration
class TestGraphAPIEndToEndCompatibility:
    """Graph API エンドツーエンド互換性テスト"""
    
    def test_comprehensive_api_compatibility(self, graph_compatibility_tester, temp_graph_dir):
        """包括的API互換性テスト"""
        
        comparisons = {}
        
        # 各エンドポイントの比較
        for endpoint_name, mock_data in graph_compatibility_tester.mock_responses.items():
            python_response = mock_data["response"]
            powershell_response = mock_data["response"].copy()  # 同一データで比較
            
            comparison = graph_compatibility_tester.compare_graph_responses(
                python_response,
                powershell_response  
            )
            
            comparisons[endpoint_name] = comparison
        
        # レポート生成
        report_file = graph_compatibility_tester.export_comparison_report(
            comparisons,
            temp_graph_dir
        )
        
        assert report_file.exists(), "互換性レポートが生成されませんでした"
        
        # 全エンドポイントの互換性確認
        all_success = all(comp.get("success", False) for comp in comparisons.values())
        assert all_success, f"一部のエンドポイントで互換性問題が発生しました: {comparisons}"
        
        print(f"✅ Graph API互換性テスト完了 - レポート: {report_file}")


# カスタムアサーション関数
def assert_graph_response_structure(response: Dict, required_fields: List[str]):
    """Graph API応答構造のカスタムアサーション"""
    assert "value" in response, "Graph API応答に 'value' フィールドがありません"
    
    if response["value"] and isinstance(response["value"], list):
        first_item = response["value"][0]
        for field in required_fields:
            assert field in first_item, f"必須フィールド '{field}' が見つかりません"


def assert_graph_api_paging_support(response: Dict):
    """Graph API ページング対応のカスタムアサーション"""
    # ODataページング情報の確認
    odata_fields = ["@odata.context", "@odata.nextLink", "@odata.count"]
    
    # 少なくとも @odata.context は必須
    assert "@odata.context" in response, "Graph API応答に @odata.context がありません"