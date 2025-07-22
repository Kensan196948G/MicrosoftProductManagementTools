# 🌐 Microsoft 365 API仕様書

## 📋 概要

### 🎯 API利用目的
Microsoft 365統合管理ツールは、Microsoft Graph APIおよび各種PowerShell管理モジュールを活用して、Microsoft 365サービスの包括的な管理・監視を実現します。本仕様書では、使用するAPI、認証方法、データ取得パターン、エラーハンドリングについて詳述します。

### 🔐 セキュリティ原則
- 🎫 **最小権限の原則**: 必要最小限の権限のみ要求
- 🔒 **証明書ベース認証**: セキュアな認証方式を優先使用
- 📝 **監査証跡**: 全API呼び出しの記録・追跡
- 🔄 **トークン管理**: 適切なトークンライフサイクル管理

---

## 🔑 認証・認可システム

### 🎫 Microsoft Graph API認証

#### 📱 アプリケーション認証（推奨）
```powershell
# 証明書ベース認証（本番環境推奨）
$certThumbprint = "ABC123...789"
$tenantId = "your-tenant-id"
$clientId = "your-app-id"

Connect-MgGraph -CertificateThumbprint $certThumbprint `
                -AppId $clientId `
                -TenantId $tenantId

# 接続確認
Get-MgContext
```

#### 🔐 クライアントシークレット認証（開発環境）
```powershell
# シークレット方式（開発環境のみ）
$clientSecret = ConvertTo-SecureString "your-secret" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($clientId, $clientSecret)

Connect-MgGraph -ClientSecretCredential $credential -TenantId $tenantId
```

#### 🏢 必要なAPIアクセス許可
```json
{
  "requiredResourceAccess": [
    {
      "resourceAppId": "00000003-0000-0000-c000-000000000000",
      "resourceAccess": [
        {
          "id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
          "type": "Role"
        },
        {
          "id": "df021288-bdef-4463-88db-98f22de89214",
          "type": "Role"
        }
      ]
    }
  ]
}
```

**🎯 必要な権限詳細:**
- 📊 `User.Read.All` - ユーザー情報読み取り
- 🏢 `Group.Read.All` - グループ情報読み取り
- 📧 `Mail.Read` - メール統計読み取り
- 🎫 `Directory.Read.All` - ディレクトリ情報読み取り
- 📊 `Reports.Read.All` - 使用状況レポート読み取り
- ☁️ `Files.Read.All` - OneDrive情報読み取り

### 📧 Exchange Online認証

#### 🔐 モダン認証（Certificate-based）
```powershell
# Exchange Online接続（証明書認証）
$connectionParams = @{
    CertificateThumbprint = $certThumbprint
    AppId = $clientId
    Organization = "your-tenant.onmicrosoft.com"
    ShowProgress = $false
}

Connect-ExchangeOnline @connectionParams
```

#### 📋 必要な役割・権限
```
🏢 Exchange Online役割
├── 📊 View-Only Recipients
├── 📧 Mail Recipients  
├── 📋 View-Only Configuration
├── 📊 Hygiene Management
└── 📈 View-Only Audit Logs
```

---

## 📊 Microsoft Graph API仕様

### 👥 ユーザー管理API

#### 🔍 ユーザー一覧取得
```http
GET https://graph.microsoft.com/v1.0/users
```

**PowerShellコマンド:**
```powershell
# 全ユーザー取得
$users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,LastSignInDateTime

# フィルタリング取得
$activeUsers = Get-MgUser -Filter "accountEnabled eq true" -All
```

**📄 レスポンス例:**
```json
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
  "value": [
    {
      "id": "87d349ed-44d7-43e1-9a83-5f2406dee5bd",
      "displayName": "田中太郎",
      "userPrincipalName": "tanaka@contoso.com",
      "accountEnabled": true,
      "createdDateTime": "2023-01-15T09:30:00Z",
      "lastSignInDateTime": "2024-06-13T08:45:00Z"
    }
  ]
}
```

#### 📊 ユーザーライセンス情報
```powershell
# ライセンス割り当て状況
$userLicenses = Get-MgUser -UserId $userId -Property AssignedLicenses,LicenseProcessingState

# ライセンス詳細情報
$licenseDetails = Get-MgSubscribedSku | Select-Object SkuId,SkuPartNumber,ConsumedUnits,PrepaidUnits
```

### 🏢 グループ管理API

#### 📋 グループ一覧・詳細取得
```powershell
# セキュリティグループ取得
$securityGroups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified') eq false" -All

# Microsoft 365グループ取得
$m365Groups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All

# グループメンバー取得
$groupMembers = Get-MgGroupMember -GroupId $groupId -All
```

### 📊 レポート・統計API

#### 📈 使用状況レポート
```powershell
# Microsoft 365使用状況レポート（過去30日）
$usageReports = @{
    # OneDrive使用状況
    OneDriveUsage = Get-MgReportOneDriveUsageAccountDetail -Period D30
    
    # Teams使用状況
    TeamsUsage = Get-MgReportTeamsUserActivityUserDetail -Period D30
    
    # Exchange使用状況
    ExchangeUsage = Get-MgReportEmailActivityUserDetail -Period D30
    
    # SharePoint使用状況
    SharePointUsage = Get-MgReportSharePointSiteUsageDetail -Period D30
}
```

#### 📊 詳細統計データ
```powershell
# OneDrive容量詳細
$oneDriveStats = Get-MgReportOneDriveUsageStorage -Period D7

# Teams会議統計
$teamsStats = Get-MgReportTeamsDeviceUsageUserDetail -Period D30

# メール活動統計
$emailStats = Get-MgReportEmailActivityCount -Period D90
```

---

## 📧 Exchange Online API仕様

### 📦 メールボックス管理

#### 💾 メールボックス容量監視
```powershell
# メールボックス統計取得
$mailboxStats = Get-MailboxStatistics -ResultSize Unlimited | 
    Select-Object DisplayName,
                  @{Name="TotalItemSizeGB";Expression={[math]::Round($_.TotalItemSize.Value.ToGB(),2)}},
                  ItemCount,
                  LastLogonTime,
                  LastLoggedOnUserAccount

# メールボックス容量制限
$mailboxQuotas = Get-Mailbox -ResultSize Unlimited | 
    Select-Object DisplayName,
                  ProhibitSendQuota,
                  ProhibitSendReceiveQuota,
                  IssueWarningQuota,
                  UseDatabaseQuotaDefaults
```

#### 📎 添付ファイル分析
```powershell
# 大容量添付ファイル検索
$largeAttachments = Get-MessageTrace -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) |
    Where-Object {$_.Size -gt 10MB} |
    Select-Object Received,SenderAddress,RecipientAddress,Subject,Size

# 添付ファイル統計
$attachmentStats = Search-MailboxAuditLog -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) |
    Where-Object {$_.Operation -eq "Create" -and $_.ObjectId -like "*.pdf" -or $_.ObjectId -like "*.zip"}
```

### 🛡️ セキュリティ・コンプライアンス

#### 🔒 スパム・マルウェア統計
```powershell
# スパムフィルター効果
$spamStats = Get-MailFilterListReport -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date)

# マルウェア検出統計
$malwareStats = Get-MailDetailMalwareReport -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date)

# 配信不能レポート
$bounceStats = Get-MailDetailReport -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) |
    Where-Object {$_.EventType -eq "Bounce"}
```

#### 📋 監査ログ
```powershell
# メールボックス監査ログ
$auditLogs = Search-MailboxAuditLog -Identity $userPrincipalName -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date)

# 管理者操作ログ
$adminLogs = Search-AdminAuditLog -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date)
```

---

## ☁️ OneDrive・Teams API仕様

### 💾 OneDrive容量管理

#### 📊 サイト別使用状況
```powershell
# OneDriveサイト容量情報
$oneDriveSites = Get-MgReportOneDriveUsageAccountDetail -Period D30 |
    Select-Object UserPrincipalName,
                  LastActivityDate,
                  FileCount,
                  ActiveFileCount,
                  StorageUsedInBytes,
                  StorageAllocatedInBytes

# 容量上位ユーザー
$topUsers = $oneDriveSites | 
    Sort-Object StorageUsedInBytes -Descending |
    Select-Object -First 20
```

#### 🔍 ファイル活動監視
```powershell
# ファイル活動統計
$fileActivity = Get-MgReportOneDriveActivityUserDetail -Period D30 |
    Select-Object UserPrincipalName,
                  LastActivityDate,
                  ViewedOrEditedFileCount,
                  SyncedFileCount,
                  SharedInternallyFileCount,
                  SharedExternallyFileCount
```

### 👥 Teams利用状況

#### 📞 会議・通話統計
```powershell
# Teams会議統計
$meetingStats = Get-MgReportTeamsUserActivityUserDetail -Period D30 |
    Select-Object UserPrincipalName,
                  LastActivityDate,
                  TeamChatMessageCount,
                  PrivateChatMessageCount,
                  CallCount,
                  MeetingCount

# デバイス別利用状況
$deviceUsage = Get-MgReportTeamsDeviceUsageUserDetail -Period D30 |
    Select-Object UserPrincipalName,
                  LastActivityDate,
                  UsedWeb,
                  UsedWindowsPhone,
                  UsedMobile,
                  UsedWindows,
                  UsedMac
```

#### 💬 チーム・チャネル分析
```powershell
# チーム一覧
$teams = Get-Team | Select-Object GroupId,DisplayName,Visibility,MailNickName,Description

# チャネル活動
foreach($team in $teams) {
    $channels = Get-TeamChannel -GroupId $team.GroupId
    $teamActivity = Get-MgReportTeamsTeamActivityDetail -Period D30 |
        Where-Object {$_.TeamId -eq $team.GroupId}
}
```

---

## 🔄 API呼び出しパターン

### ⚡ 効率的なデータ取得

#### 📊 バッチ処理
```powershell
# 複数ユーザー情報の並列取得
$userIds = @("user1@contoso.com", "user2@contoso.com", "user3@contoso.com")

$jobs = foreach($userId in $userIds) {
    Start-Job -ScriptBlock {
        param($UserId)
        Import-Module Microsoft.Graph.Users
        Connect-MgGraph
        Get-MgUser -UserId $UserId -Property Id,DisplayName,LastSignInDateTime
    } -ArgumentList $userId
}

$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job
```

#### 📋 フィルタリング・ページング
```powershell
# 効率的なフィルタリング
$recentUsers = Get-MgUser -Filter "lastSignInDateTime ge 2024-01-01T00:00:00Z" `
                         -Property Id,DisplayName,LastSignInDateTime `
                         -PageSize 100 `
                         -All

# 特定プロパティのみ取得
$userBasics = Get-MgUser -Property Id,DisplayName,UserPrincipalName,AccountEnabled -All
```

### 🔄 エラーハンドリング・リトライ

#### ⚠️ API制限対応
```powershell
function Invoke-GraphAPIWithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 5,
        [int]$BaseDelaySeconds = 2
    )
    
    $attempt = 0
    do {
        try {
            $attempt++
            return & $ScriptBlock
        }
        catch {
            if ($_.Exception.Message -match "429|throttle|rate limit") {
                if ($attempt -lt $MaxRetries) {
                    $delay = $BaseDelaySeconds * [Math]::Pow(2, $attempt)
                    Write-Warning "API制限検出。${delay}秒後にリトライします..."
                    Start-Sleep -Seconds $delay
                }
                else {
                    throw "最大リトライ回数に到達しました: $($_.Exception.Message)"
                }
            }
            else {
                throw
            }
        }
    } while ($attempt -lt $MaxRetries)
}

# 使用例
$users = Invoke-GraphAPIWithRetry -ScriptBlock {
    Get-MgUser -All -Property Id,DisplayName,UserPrincipalName
}
```

#### 🛡️ 接続状態管理
```powershell
function Test-GraphConnection {
    try {
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Microsoft Graph未接続"
        }
        
        # 接続テスト
        $null = Get-MgUser -Top 1 -Property Id
        return $true
    }
    catch {
        Write-Warning "Microsoft Graph接続エラー: $($_.Exception.Message)"
        return $false
    }
}

function Ensure-GraphConnection {
    if (-not (Test-GraphConnection)) {
        Write-Host "Microsoft Graphに再接続中..."
        Connect-MgGraph -CertificateThumbprint $certThumbprint -AppId $clientId -TenantId $tenantId
    }
}
```

---

## 📊 APIレスポンス処理

### 🔄 データ変換・標準化

#### 📋 統一データ形式
```powershell
function ConvertTo-StandardUserObject {
    param([Parameter(ValueFromPipeline)]$GraphUser)
    
    process {
        [PSCustomObject]@{
            Id = $GraphUser.Id
            DisplayName = $GraphUser.DisplayName
            UserPrincipalName = $GraphUser.UserPrincipalName
            Enabled = $GraphUser.AccountEnabled
            CreatedDate = if($GraphUser.CreatedDateTime) { 
                [DateTime]::Parse($GraphUser.CreatedDateTime) 
            } else { $null }
            LastSignIn = if($GraphUser.LastSignInDateTime) { 
                [DateTime]::Parse($GraphUser.LastSignInDateTime) 
            } else { $null }
            LicenseCount = if($GraphUser.AssignedLicenses) { 
                $GraphUser.AssignedLicenses.Count 
            } else { 0 }
            Department = $GraphUser.Department
            JobTitle = $GraphUser.JobTitle
            Manager = $GraphUser.Manager.DisplayName
        }
    }
}

# 使用例
$standardUsers = Get-MgUser -All | ConvertTo-StandardUserObject
```

#### 📊 集計・統計処理
```powershell
function Get-UserStatistics {
    param($Users)
    
    $stats = [PSCustomObject]@{
        TotalUsers = $Users.Count
        ActiveUsers = ($Users | Where-Object {$_.Enabled}).Count
        InactiveUsers = ($Users | Where-Object {-not $_.Enabled}).Count
        RecentSignIns = ($Users | Where-Object {$_.LastSignIn -gt (Get-Date).AddDays(-30)}).Count
        LicensedUsers = ($Users | Where-Object {$_.LicenseCount -gt 0}).Count
        UnlicensedUsers = ($Users | Where-Object {$_.LicenseCount -eq 0}).Count
        
        # 部門別統計
        DepartmentStats = $Users | Group-Object Department | Sort-Object Count -Descending |
            Select-Object @{N="Department";E={$_.Name}}, @{N="UserCount";E={$_.Count}}
        
        # ライセンス統計
        LicenseDistribution = $Users | Group-Object LicenseCount | Sort-Object Name |
            Select-Object @{N="LicenseCount";E={[int]$_.Name}}, @{N="UserCount";E={$_.Count}}
    }
    
    return $stats
}
```

---

## 🔐 セキュリティ考慮事項

### 🛡️ 認証情報保護

#### 🔒 証明書管理
```powershell
# 証明書の健全性チェック
function Test-CertificateHealth {
    param([string]$Thumbprint)
    
    $cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$Thumbprint" -ErrorAction SilentlyContinue
    
    if (-not $cert) {
        throw "証明書が見つかりません: $Thumbprint"
    }
    
    $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
    
    if ($daysUntilExpiry -lt 30) {
        Write-Warning "証明書の有効期限が近づいています: $daysUntilExpiry 日"
    }
    
    return @{
        IsValid = $true
        ExpiryDate = $cert.NotAfter
        DaysUntilExpiry = $daysUntilExpiry
        Subject = $cert.Subject
    }
}
```

#### 🔑 アクセストークン管理
```powershell
# トークンの残り有効期間確認
function Get-TokenExpiryInfo {
    $context = Get-MgContext
    if ($context -and $context.AccessToken) {
        # JWTトークンのデコード（簡易版）
        $tokenParts = $context.AccessToken.Split('.')
        $payload = [System.Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($tokenParts[1].PadRight(($tokenParts[1].Length + 3) -band -4, '='))
        ) | ConvertFrom-Json
        
        $expiry = [DateTimeOffset]::FromUnixTimeSeconds($payload.exp).DateTime
        $remaining = $expiry - (Get-Date)
        
        return @{
            ExpiryTime = $expiry
            RemainingMinutes = [Math]::Round($remaining.TotalMinutes, 2)
            IsExpiringSoon = $remaining.TotalMinutes -lt 10
        }
    }
    return $null
}
```

### 📝 監査ログ記録

#### 📊 API呼び出しログ
```powershell
function Write-APIAuditLog {
    param(
        [string]$Operation,
        [string]$Resource,
        [string]$User,
        [hashtable]$Parameters = @{},
        [string]$Result = "Success",
        [string]$ErrorMessage = $null
    )
    
    $logEntry = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        Operation = $Operation
        Resource = $Resource
        User = $User
        Parameters = ($Parameters | ConvertTo-Json -Compress)
        Result = $Result
        ErrorMessage = $ErrorMessage
        SessionId = $env:SESSIONNAME
        ComputerName = $env:COMPUTERNAME
    }
    
    $logPath = Join-Path $LogDir "API_Audit_$(Get-Date -Format 'yyyyMMdd').csv"
    $logEntry | Export-Csv -Path $logPath -Append -NoTypeInformation -Encoding UTF8
}

# 使用例
Write-APIAuditLog -Operation "Get-MgUser" -Resource "Users" -User $currentUser -Parameters @{Filter="accountEnabled eq true"}
```

---

## 📈 パフォーマンス最適化

### ⚡ キャッシュ戦略

#### 💾 インメモリキャッシュ
```powershell
# グローバルキャッシュ
$Global:APICache = @{}

function Get-CachedData {
    param(
        [string]$Key,
        [scriptblock]$DataSource,
        [int]$CacheMinutes = 15
    )
    
    $cacheItem = $Global:APICache[$Key]
    
    if ($cacheItem -and ((Get-Date) - $cacheItem.Timestamp).TotalMinutes -lt $CacheMinutes) {
        Write-Verbose "キャッシュからデータを取得: $Key"
        return $cacheItem.Data
    }
    
    Write-Verbose "新しいデータを取得: $Key"
    $data = & $DataSource
    
    $Global:APICache[$Key] = @{
        Data = $data
        Timestamp = Get-Date
    }
    
    return $data
}

# 使用例
$users = Get-CachedData -Key "AllUsers" -DataSource {
    Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled
} -CacheMinutes 30
```

### 📊 監視・メトリクス

#### ⏱️ API呼び出し統計
```powershell
# API呼び出し統計
$Global:APIMetrics = @{
    CallCount = 0
    TotalTime = [TimeSpan]::Zero
    Errors = 0
    ThrottleEvents = 0
}

function Measure-APICall {
    param([scriptblock]$ScriptBlock, [string]$OperationName)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $Global:APIMetrics.CallCount++
        $result = & $ScriptBlock
        return $result
    }
    catch {
        $Global:APIMetrics.Errors++
        if ($_.Exception.Message -match "429|throttle") {
            $Global:APIMetrics.ThrottleEvents++
        }
        throw
    }
    finally {
        $stopwatch.Stop()
        $Global:APIMetrics.TotalTime = $Global:APIMetrics.TotalTime.Add($stopwatch.Elapsed)
        
        Write-Verbose "API呼び出し完了: $OperationName (${stopwatch.ElapsedMilliseconds}ms)"
    }
}
```

---

**🎯 堅牢で効率的なAPI統合により、信頼性の高いMicrosoft 365管理を実現します！**

---

*📅 最終更新: 2025年6月 | 🌐 Microsoft 365 API仕様 v2.0*