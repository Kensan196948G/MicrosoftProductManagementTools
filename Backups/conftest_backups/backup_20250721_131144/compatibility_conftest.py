"""
pytest設定とフィクスチャー
PowerShellBridge互換性テスト用の共通フィクスチャー
"""

import pytest
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List
from unittest.mock import Mock, MagicMock


@pytest.fixture
def mock_m365_users():
    """Microsoft 365ユーザーデータのモック"""
    return {
        "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
        "@odata.count": 3,
        "value": [
            {
                "id": "87d349ed-44d7-43e1-9a83-5f2406dee5bd",
                "businessPhones": ["+81 3 1234 5678"],
                "displayName": "田中 太郎",
                "givenName": "太郎",
                "jobTitle": "営業部長",
                "mail": "tanaka.taro@contoso.com",
                "mobilePhone": "+81 90 1234 5678",
                "officeLocation": "東京本社 18F",
                "preferredLanguage": "ja-JP",
                "surname": "田中",
                "userPrincipalName": "tanaka.taro@contoso.onmicrosoft.com",
                "accountEnabled": True,
                "assignedLicenses": [
                    {
                        "disabledPlans": [],
                        "skuId": "b05e124f-c7cc-45a0-a6aa-8cf78c946968"
                    }
                ],
                "assignedPlans": [
                    {
                        "assignedDateTime": "2022-01-15T00:00:00Z",
                        "capabilityStatus": "Enabled",
                        "service": "exchange",
                        "servicePlanId": "efb87545-963c-4e0d-99df-69c6916d9eb0"
                    }
                ],
                "createdDateTime": "2021-04-01T09:00:00Z",
                "department": "営業部",
                "lastPasswordChangeDateTime": "2024-10-15T10:30:00Z",
                "usageLocation": "JP"
            },
            {
                "id": "45b7d2e7-b882-4989-a5f7-3573b8fbf9e4",
                "businessPhones": [],
                "displayName": "佐藤 花子",
                "givenName": "花子",
                "jobTitle": "人事マネージャー",
                "mail": "sato.hanako@contoso.com",
                "mobilePhone": "+81 90 9876 5432",
                "officeLocation": "大阪支社 5F",
                "preferredLanguage": "ja-JP",
                "surname": "佐藤",
                "userPrincipalName": "sato.hanako@contoso.onmicrosoft.com",
                "accountEnabled": True,
                "assignedLicenses": [
                    {
                        "disabledPlans": [],
                        "skuId": "b05e124f-c7cc-45a0-a6aa-8cf78c946968"
                    }
                ],
                "createdDateTime": "2020-08-15T09:00:00Z",
                "department": "人事部",
                "lastPasswordChangeDateTime": "2024-11-20T14:15:00Z",
                "usageLocation": "JP"
            },
            {
                "id": "8e4f5g6h-7i8j-9k0l-1m2n-3o4p5q6r7s8t",
                "businessPhones": [],
                "displayName": "山田 次郎",
                "givenName": "次郎",
                "jobTitle": "システム管理者",
                "mail": "yamada.jiro@contoso.com",
                "mobilePhone": None,
                "officeLocation": "リモート",
                "preferredLanguage": "ja-JP",
                "surname": "山田",
                "userPrincipalName": "yamada.jiro@contoso.onmicrosoft.com",
                "accountEnabled": True,
                "assignedLicenses": [
                    {
                        "disabledPlans": [],
                        "skuId": "b05e124f-c7cc-45a0-a6aa-8cf78c946968"
                    }
                ],
                "createdDateTime": "2022-12-01T09:00:00Z",
                "department": "IT部",
                "lastPasswordChangeDateTime": "2024-12-01T09:00:00Z",
                "usageLocation": "JP"
            }
        ]
    }


@pytest.fixture
def mock_m365_licenses():
    """Microsoft 365ライセンスデータのモック"""
    return {
        "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#subscribedSkus",
        "value": [
            {
                "capabilityStatus": "Enabled",
                "consumedUnits": 23,
                "id": "b05e124f-c7cc-45a0-a6aa-8cf78c946968",
                "prepaidUnits": {
                    "enabled": 25,
                    "suspended": 0,
                    "warning": 0
                },
                "servicePlans": [
                    {
                        "appliesTo": "User",
                        "provisioningStatus": "Success",
                        "servicePlanId": "efb87545-963c-4e0d-99df-69c6916d9eb0",
                        "servicePlanName": "EXCHANGE_S_ENTERPRISE"
                    },
                    {
                        "appliesTo": "User",
                        "provisioningStatus": "Success",
                        "servicePlanId": "0feaeb32-d00e-4d66-bd5a-43b5b83db82c",
                        "servicePlanName": "MCOSTANDARD"
                    },
                    {
                        "appliesTo": "User",
                        "provisioningStatus": "Success",
                        "servicePlanId": "e95bec33-7c88-4a70-8e19-b10bd9d0c014",
                        "servicePlanName": "SHAREPOINTWAC"
                    }
                ],
                "skuId": "b05e124f-c7cc-45a0-a6aa-8cf78c946968",
                "skuPartNumber": "ENTERPRISEPREMIUM"
            },
            {
                "capabilityStatus": "Enabled",
                "consumedUnits": 5,
                "id": "78e66a63-337a-4a9a-8959-41c6654dfb56",
                "prepaidUnits": {
                    "enabled": 10,
                    "suspended": 0,
                    "warning": 0
                },
                "servicePlans": [
                    {
                        "appliesTo": "User",
                        "provisioningStatus": "Success",
                        "servicePlanId": "9aaf7827-d63c-4b61-89c3-182f06f82e5c",
                        "servicePlanName": "EXCHANGE_S_STANDARD"
                    }
                ],
                "skuId": "78e66a63-337a-4a9a-8959-41c6654dfb56",
                "skuPartNumber": "STANDARDPACK"
            }
        ]
    }


@pytest.fixture
def mock_exchange_mailboxes():
    """Exchange Onlineメールボックスデータのモック"""
    return [
        {
            "Name": "田中 太郎",
            "Alias": "tanaka.taro",
            "DisplayName": "田中 太郎",
            "PrimarySmtpAddress": "tanaka.taro@contoso.com",
            "RecipientTypeDetails": "UserMailbox",
            "EmailAddresses": [
                "SMTP:tanaka.taro@contoso.com",
                "smtp:t.tanaka@contoso.com",
                "smtp:tanaka@contoso.onmicrosoft.com"
            ],
            "Database": "JPNDB01",
            "ServerName": "JPNEX01",
            "ProhibitSendQuota": "50 GB (53,687,091,200 bytes)",
            "ProhibitSendReceiveQuota": "52 GB (55,834,574,848 bytes)",
            "IssueWarningQuota": "49 GB (52,613,349,376 bytes)",
            "UseDatabaseQuotaDefaults": False,
            "ArchiveStatus": "Active",
            "ArchiveDatabase": "JPNARCH01",
            "ArchiveQuota": "100 GB (107,374,182,400 bytes)",
            "WhenMailboxCreated": "2021-04-01T09:00:00+09:00",
            "LitigationHoldEnabled": False,
            "RetentionPolicy": "Default MRM Policy"
        },
        {
            "Name": "佐藤 花子",
            "Alias": "sato.hanako",
            "DisplayName": "佐藤 花子",
            "PrimarySmtpAddress": "sato.hanako@contoso.com",
            "RecipientTypeDetails": "UserMailbox",
            "EmailAddresses": [
                "SMTP:sato.hanako@contoso.com",
                "smtp:h.sato@contoso.com"
            ],
            "Database": "JPNDB02",
            "ServerName": "JPNEX02",
            "ProhibitSendQuota": "50 GB (53,687,091,200 bytes)",
            "ProhibitSendReceiveQuota": "52 GB (55,834,574,848 bytes)",
            "IssueWarningQuota": "49 GB (52,613,349,376 bytes)",
            "UseDatabaseQuotaDefaults": False,
            "ArchiveStatus": "None",
            "WhenMailboxCreated": "2020-08-15T09:00:00+09:00",
            "LitigationHoldEnabled": True,
            "LitigationHoldDate": "2023-06-01T00:00:00+09:00",
            "RetentionPolicy": "Default MRM Policy"
        }
    ]


@pytest.fixture
def mock_teams_usage():
    """Teams使用状況データのモック"""
    return {
        "reportRefreshDate": "2025-01-17",
        "value": [
            {
                "reportPeriod": 7,
                "userCounts": {
                    "activeUsers": 156,
                    "inactiveUsers": 12,
                    "totalUsers": 168
                },
                "activityCounts": {
                    "teamChatMessages": 3420,
                    "privateMessages": 1856,
                    "calls": 234,
                    "meetings": 89,
                    "meetingMinutes": 4567
                },
                "deviceUsage": {
                    "windows": 98,
                    "mac": 34,
                    "web": 45,
                    "ios": 67,
                    "android": 89
                }
            }
        ]
    }


@pytest.fixture
def mock_onedrive_storage():
    """OneDriveストレージデータのモック"""
    return {
        "reportRefreshDate": "2025-01-17",
        "value": [
            {
                "ownerPrincipalName": "tanaka.taro@contoso.com",
                "ownerDisplayName": "田中 太郎",
                "siteUrl": "https://contoso-my.sharepoint.com/personal/tanaka_taro_contoso_com",
                "storageUsedInBytes": 10737418240,  # 10 GB
                "storageAllocatedInBytes": 1099511627776,  # 1 TB
                "fileCount": 1234,
                "activeFileCount": 567,
                "lastActivityDate": "2025-01-16T15:30:00Z",
                "isDeleted": False
            },
            {
                "ownerPrincipalName": "sato.hanako@contoso.com",
                "ownerDisplayName": "佐藤 花子",
                "siteUrl": "https://contoso-my.sharepoint.com/personal/sato_hanako_contoso_com",
                "storageUsedInBytes": 53687091200,  # 50 GB
                "storageAllocatedInBytes": 1099511627776,  # 1 TB
                "fileCount": 5678,
                "activeFileCount": 2345,
                "lastActivityDate": "2025-01-17T09:15:00Z",
                "isDeleted": False
            }
        ]
    }


@pytest.fixture
def mock_mfa_status():
    """MFA状況データのモック"""
    return [
        {
            "userPrincipalName": "tanaka.taro@contoso.com",
            "displayName": "田中 太郎",
            "isMfaRegistered": True,
            "isCapable": True,
            "methodsRegistered": [
                "microsoftAuthenticatorPush",
                "microsoftAuthenticatorPasswordless",
                "phoneAuthentication"
            ],
            "defaultMethod": "microsoftAuthenticatorPush",
            "lastSignInDateTime": "2025-01-17T10:30:00Z"
        },
        {
            "userPrincipalName": "sato.hanako@contoso.com",
            "displayName": "佐藤 花子",
            "isMfaRegistered": True,
            "isCapable": True,
            "methodsRegistered": [
                "phoneAuthentication",
                "email"
            ],
            "defaultMethod": "phoneAuthentication",
            "lastSignInDateTime": "2025-01-17T14:45:00Z"
        },
        {
            "userPrincipalName": "yamada.jiro@contoso.com",
            "displayName": "山田 次郎",
            "isMfaRegistered": False,
            "isCapable": True,
            "methodsRegistered": [],
            "defaultMethod": None,
            "lastSignInDateTime": "2025-01-15T09:00:00Z"
        }
    ]


@pytest.fixture
def mock_conditional_access_policies():
    """条件付きアクセスポリシーデータのモック"""
    return {
        "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies",
        "value": [
            {
                "id": "ca-policy-001",
                "displayName": "Require MFA for all users",
                "createdDateTime": "2023-01-15T00:00:00Z",
                "modifiedDateTime": "2024-06-01T00:00:00Z",
                "state": "enabled",
                "conditions": {
                    "users": {
                        "includeUsers": ["All"]
                    },
                    "applications": {
                        "includeApplications": ["All"]
                    },
                    "locations": {
                        "includeLocations": ["All"],
                        "excludeLocations": ["AllTrusted"]
                    }
                },
                "grantControls": {
                    "operator": "OR",
                    "builtInControls": ["mfa"]
                }
            },
            {
                "id": "ca-policy-002",
                "displayName": "Block legacy authentication",
                "createdDateTime": "2023-02-01T00:00:00Z",
                "modifiedDateTime": "2023-02-01T00:00:00Z",
                "state": "enabled",
                "conditions": {
                    "users": {
                        "includeUsers": ["All"]
                    },
                    "clientAppTypes": ["exchangeActiveSync", "other"]
                },
                "grantControls": {
                    "operator": "OR",
                    "builtInControls": ["block"]
                }
            }
        ]
    }


@pytest.fixture
def mock_signin_logs():
    """サインインログデータのモック"""
    return {
        "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#auditLogs/signIns",
        "value": [
            {
                "id": "sign-in-001",
                "createdDateTime": "2025-01-17T10:30:00Z",
                "userPrincipalName": "tanaka.taro@contoso.com",
                "userDisplayName": "田中 太郎",
                "ipAddress": "203.0.113.1",
                "clientAppUsed": "Browser",
                "appDisplayName": "Office 365",
                "status": {
                    "errorCode": 0,
                    "failureReason": None,
                    "additionalDetails": "MFA requirement satisfied"
                },
                "conditionalAccessStatus": "success",
                "riskDetail": "none",
                "riskLevelDuringSignIn": "none",
                "riskState": "none",
                "deviceDetail": {
                    "browser": "Chrome 120.0.0",
                    "operatingSystem": "Windows 10",
                    "deviceId": None,
                    "displayName": None,
                    "isCompliant": None,
                    "isManaged": None
                },
                "location": {
                    "city": "Tokyo",
                    "state": "Tokyo",
                    "countryOrRegion": "JP",
                    "geoCoordinates": {
                        "latitude": 35.6762,
                        "longitude": 139.6503
                    }
                }
            },
            {
                "id": "sign-in-002",
                "createdDateTime": "2025-01-17T08:15:00Z",
                "userPrincipalName": "unknown@external.com",
                "userDisplayName": "Unknown User",
                "ipAddress": "198.51.100.42",
                "clientAppUsed": "Other clients; POP",
                "appDisplayName": "Exchange Online",
                "status": {
                    "errorCode": 53003,
                    "failureReason": "Blocked by Conditional Access",
                    "additionalDetails": "Legacy authentication blocked"
                },
                "conditionalAccessStatus": "failure",
                "riskDetail": "unknownFutureValue",
                "riskLevelDuringSignIn": "high",
                "riskState": "atRisk",
                "deviceDetail": {
                    "browser": "Unknown",
                    "operatingSystem": "Unknown",
                    "deviceId": None,
                    "displayName": None,
                    "isCompliant": None,
                    "isManaged": None
                },
                "location": {
                    "city": "Unknown",
                    "state": "Unknown",
                    "countryOrRegion": "CN",
                    "geoCoordinates": None
                }
            }
        ]
    }


@pytest.fixture
def mock_powershell_error_scenarios():
    """PowerShellエラーシナリオのモック"""
    return {
        "permission_denied": {
            "Message": "Insufficient privileges to complete the operation.",
            "Type": "Microsoft.Graph.PowerShell.Models.ODataErrors.ODataError",
            "ErrorCode": "Authorization_RequestDenied",
            "StackTrace": "at Microsoft.Graph.PowerShell.Cmdlets.GetMgUser_List"
        },
        "token_expired": {
            "Message": "Access token has expired or is not yet valid.",
            "Type": "Microsoft.Identity.Client.MsalUiRequiredException",
            "ErrorCode": "invalid_grant",
            "StackTrace": "at Microsoft.Identity.Client.TokenCache.GetAccessToken"
        },
        "resource_not_found": {
            "Message": "Resource 'user@example.com' does not exist or one of its queried reference-property objects are not present.",
            "Type": "Microsoft.Graph.PowerShell.Models.ODataErrors.ODataError",
            "ErrorCode": "Request_ResourceNotFound",
            "StackTrace": "at Microsoft.Graph.PowerShell.Cmdlets.GetMgUser_Get"
        },
        "throttling": {
            "Message": "Too many requests. Please retry after 60 seconds.",
            "Type": "Microsoft.Graph.PowerShell.Models.ODataErrors.ODataError",
            "ErrorCode": "Request_ThrottledTemporarily",
            "RetryAfter": 60,
            "StackTrace": "at Microsoft.Graph.PowerShell.Cmdlets.GetMgUser_List"
        },
        "network_error": {
            "Message": "The remote name could not be resolved: 'graph.microsoft.com'",
            "Type": "System.Net.WebException",
            "ErrorCode": "NameResolutionFailure",
            "StackTrace": "at System.Net.HttpWebRequest.GetResponse()"
        }
    }


@pytest.fixture
def mock_batch_commands():
    """バッチコマンドのモック"""
    return [
        "Get-MgUser -Top 10 | Select-Object DisplayName,Mail",
        "Get-MgGroup -Top 5 | Select-Object DisplayName,MailEnabled",
        "Get-MgSubscribedSku | Select-Object SkuPartNumber,ConsumedUnits",
        "Get-MgOrganization | Select-Object DisplayName,VerifiedDomains"
    ]


@pytest.fixture
def temp_module_structure(tmp_path):
    """一時的なモジュール構造を作成"""
    # Scripts/Common ディレクトリ構造を作成
    common_dir = tmp_path / "Scripts" / "Common"
    common_dir.mkdir(parents=True, exist_ok=True)
    
    # 各モジュールファイルを作成
    modules = {
        "Common.psm1": """
            function Initialize-Environment {
                [CmdletBinding()]
                param()
                Write-Output "Environment initialized"
            }
            Export-ModuleMember -Function Initialize-Environment
        """,
        "Authentication.psm1": """
            function Connect-M365Services {
                [CmdletBinding()]
                param(
                    [string]$TenantId,
                    [string]$ClientId,
                    [string]$CertificateThumbprint
                )
                Write-Output "Connected to M365"
            }
            Export-ModuleMember -Function Connect-M365Services
        """,
        "RealM365DataProvider.psm1": """
            function Get-RealM365Users {
                [CmdletBinding()]
                param()
                # Return mock data
                @{
                    value = @(
                        @{
                            displayName = "Test User"
                            mail = "test@example.com"
                        }
                    )
                } | ConvertTo-Json
            }
            Export-ModuleMember -Function Get-RealM365Users
        """
    }
    
    for filename, content in modules.items():
        module_path = common_dir / filename
        module_path.write_text(content)
    
    return tmp_path


@pytest.fixture
def performance_test_data():
    """パフォーマンステスト用の大量データ"""
    users = []
    for i in range(1000):
        users.append({
            "id": f"user-{i:04d}",
            "displayName": f"User {i:04d}",
            "userPrincipalName": f"user{i:04d}@contoso.com",
            "mail": f"user{i:04d}@contoso.com",
            "department": f"Dept{i % 10}",
            "accountEnabled": i % 10 != 0  # 10%は無効
        })
    
    return {
        "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
        "@odata.count": 1000,
        "value": users
    }