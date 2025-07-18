# 🛠️ Microsoft 365統合管理ツール システム管理者向け運用マニュアル

## 📋 運用管理概要

### 🎯 管理者の役割・責任
Microsoft 365統合管理ツールのシステム管理者として、以下の運用業務を担当いただきます：

#### 🔐 セキュリティ・認証管理
- 🎫 **証明書ベース認証**: セキュアなAPI接続の維持
- 🔑 **アクセス権限管理**: 最小権限原則の徹底
- 📝 **監査証跡**: セキュリティログの定期確認
- 🛡️ **脆弱性対応**: セキュリティパッチの迅速適用

#### 📊 システム監視・保守
- ⚡ **パフォーマンス監視**: システムリソース使用状況の確認
- 🔄 **定期メンテナンス**: ログローテーション・データクリーンアップ
- 📈 **容量管理**: ディスク使用量・レポート保存領域の管理
- 🚨 **アラート対応**: システム異常の迅速な対処

---

## 🔐 セキュリティ管理

### 🎫 認証設定・管理

#### 📱 Azure ADアプリケーション登録
```powershell
# Azure AD管理センターでの設定項目
https://aad.portal.azure.com/

【必要設定】
✅ アプリケーション名: Microsoft365-IntegratedManagement
✅ サポートされるアカウントの種類: この組織ディレクトリのみ
✅ リダイレクトURI: 不要（非対話型認証）
✅ 証明書とシークレット: クライアント証明書をアップロード
```

#### 🔒 必要なAPIアクセス許可
```json
{
  "requiredResourceAccess": [
    {
      "resourceAppId": "00000003-0000-0000-c000-000000000000",
      "resourceAccess": [
        {"id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d", "type": "Role"},
        {"id": "df021288-bdef-4463-88db-98f22de89214", "type": "Role"},
        {"id": "230c1aed-a721-4c5d-9cb4-a90514e508ef", "type": "Role"},
        {"id": "7ab1d382-f21e-4acd-a863-ba3e13f7da61", "type": "Role"}
      ]
    }
  ]
}
```

**🎯 権限詳細:**
- 📊 `User.Read.All` - ユーザー情報読み取り
- 🏢 `Group.Read.All` - グループ情報読み取り
- 📧 `Mail.Read` - メール統計読み取り
- 🎫 `Directory.Read.All` - ディレクトリ情報読み取り
- 📊 `Reports.Read.All` - 使用状況レポート読み取り
- ☁️ `Files.Read.All` - OneDrive情報読み取り

#### 🔑 証明書管理手順

##### 📜 証明書生成（PowerShell）
```powershell
# 自己署名証明書の作成
$cert = New-SelfSignedCertificate -Subject "CN=Microsoft365-IntegratedManagement" `
                                  -CertStoreLocation "Cert:\CurrentUser\My" `
                                  -KeyExportPolicy Exportable `
                                  -KeySpec Signature `
                                  -KeyLength 2048 `
                                  -KeyAlgorithm RSA `
                                  -HashAlgorithm SHA256

# 証明書の情報表示
$cert | Format-List Subject, Thumbprint, NotAfter

# 公開キーのエクスポート（Azure ADにアップロード用）
Export-Certificate -Cert $cert -FilePath "C:\temp\Microsoft365-IntegratedManagement.cer"
```

##### 🔄 証明書ローテーション
```powershell
# 証明書有効期限チェック（定期実行推奨）
function Test-CertificateExpiry {
    param([string]$Thumbprint)
    
    $cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$Thumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) {
        Write-Error "証明書が見つかりません: $Thumbprint"
        return
    }
    
    $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
    
    if ($daysUntilExpiry -lt 30) {
        Write-Warning "⚠️ 証明書の有効期限が近づいています: $daysUntilExpiry 日"
        return $false
    }
    
    Write-Host "✅ 証明書は有効です: あと $daysUntilExpiry 日"
    return $true
}

# 使用例
Test-CertificateExpiry -Thumbprint "YOUR_CERTIFICATE_THUMBPRINT"
```

### 🛡️ アクセス制御・権限管理

#### 👥 役割ベースアクセス制御
```powershell
# 設定ファイルでの権限管理例
{
  "UserRoles": {
    "SystemAdmin": {
      "Permissions": ["ALL"],
      "Users": ["admin@contoso.com"]
    },
    "ITManager": {
      "Permissions": ["READ_REPORTS", "GENERATE_REPORTS"],
      "Users": ["itmanager@contoso.com"]
    },
    "Operator": {
      "Permissions": ["READ_BASIC"],
      "Users": ["operator@contoso.com"]
    }
  }
}
```

#### 📝 監査ログ設定
```powershell
# ログ設定例（appsettings.json）
{
  "Logging": {
    "AuditLog": {
      "Enabled": true,
      "Level": "Information",
      "RetentionDays": 365,
      "Path": "Logs/Audit",
      "Format": "JSON"
    },
    "SecurityLog": {
      "Enabled": true,
      "Level": "Warning",
      "RetentionDays": 1095,
      "Path": "Logs/Security",
      "IncludeStackTrace": true
    }
  }
}
```

---

## 📊 システム監視・保守

### ⚡ パフォーマンス監視

#### 🖥️ システムリソース監視
```powershell
# リソース使用量確認スクリプト
function Get-SystemResourceUsage {
    $cpu = Get-Counter "\Processor(_Total)\% Processor Time" | 
           Select-Object -ExpandProperty CounterSamples | 
           Select-Object -ExpandProperty CookedValue
    
    $memory = Get-Counter "\Memory\Available MBytes" | 
              Select-Object -ExpandProperty CounterSamples | 
              Select-Object -ExpandProperty CookedValue
    
    $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" | 
            Select-Object @{Name="FreeSpaceGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}},
                         @{Name="TotalSpaceGB";Expression={[math]::Round($_.Size/1GB,2)}}
    
    [PSCustomObject]@{
        CPUUsage = [math]::Round($cpu, 2)
        AvailableMemoryMB = [math]::Round($memory, 2)
        DiskFreeSpaceGB = $disk.FreeSpaceGB
        DiskTotalSpaceGB = $disk.TotalSpaceGB
        Timestamp = Get-Date
    }
}

# 使用例（定期実行推奨）
Get-SystemResourceUsage | Format-Table -AutoSize
```

#### 📈 アプリケーション監視
```powershell
# Microsoft Graph API接続監視
function Test-GraphAPIConnection {
    try {
        $context = Get-MgContext
        if ($null -eq $context) {
            return @{
                Status = "Disconnected"
                Message = "Microsoft Graph未接続"
                Timestamp = Get-Date
            }
        }
        
        # 簡単なAPI呼び出しテスト
        $testUser = Get-MgUser -Top 1 -Property Id
        
        return @{
            Status = "Connected"
            Message = "Microsoft Graph接続正常"
            TenantId = $context.TenantId
            Account = $context.Account
            Timestamp = Get-Date
        }
    }
    catch {
        return @{
            Status = "Error"
            Message = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

# Exchange Online接続監視
function Test-ExchangeOnlineConnection {
    try {
        $session = Get-PSSession | Where-Object {$_.ConfigurationName -eq "Microsoft.Exchange"}
        if ($session) {
            $testMailbox = Get-Mailbox -ResultSize 1
            return @{
                Status = "Connected"
                Message = "Exchange Online接続正常"
                SessionState = $session.State
                Timestamp = Get-Date
            }
        }
        else {
            return @{
                Status = "Disconnected"
                Message = "Exchange Online未接続"
                Timestamp = Get-Date
            }
        }
    }
    catch {
        return @{
            Status = "Error"
            Message = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}
```

### 🗂️ ログ管理・ローテーション

#### 📁 ログファイル構造
```
Logs/
├── System/
│   ├── System_20250613.log        # システムログ（日次）
│   ├── Error_20250613.log         # エラーログ（日次）
│   └── Performance_20250613.csv   # パフォーマンスログ（日次）
├── Security/
│   ├── Authentication_20250613.log # 認証ログ（日次）
│   ├── Access_20250613.log        # アクセスログ（日次）
│   └── Audit_20250613.json        # 監査ログ（日次、JSON形式）
└── Application/
    ├── API_Calls_20250613.csv     # API呼び出しログ（日次）
    └── Reports_20250613.log       # レポート生成ログ（日次）
```

#### 🔄 自動ログローテーション
```powershell
# ログローテーションスクリプト
function Start-LogRotation {
    param(
        [string]$LogDirectory = "Logs",
        [int]$RetentionDays = 365
    )
    
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    
    Get-ChildItem -Path $LogDirectory -Recurse -File | 
    Where-Object {$_.LastWriteTime -lt $cutoffDate} | 
    ForEach-Object {
        Write-Host "削除: $($_.FullName) (最終更新: $($_.LastWriteTime))"
        Remove-Item $_.FullName -Force
    }
    
    # 圧縮（30日以上経過したログ）
    $compressDate = (Get-Date).AddDays(-30)
    Get-ChildItem -Path $LogDirectory -Recurse -File -Include "*.log", "*.csv" | 
    Where-Object {$_.LastWriteTime -lt $compressDate -and $_.Extension -ne ".zip"} | 
    ForEach-Object {
        $zipPath = $_.FullName.Replace($_.Extension, ".zip")
        Compress-Archive -Path $_.FullName -DestinationPath $zipPath
        Remove-Item $_.FullName -Force
        Write-Host "圧縮: $($_.FullName) → $zipPath"
    }
}

# タスクスケジューラーでの定期実行設定
# 毎日午前2時に実行
schtasks /create /tn "Microsoft365Tools-LogRotation" /tr "powershell.exe -File C:\Path\To\LogRotation.ps1" /sc daily /st 02:00 /ru SYSTEM
```

### 📊 レポート管理

#### 📅 レポート保存ポリシー
```powershell
# レポート保存期間設定
$ReportRetentionPolicy = @{
    Daily = @{
        RetentionDays = 30
        ArchiveAfterDays = 7
    }
    Weekly = @{
        RetentionDays = 365
        ArchiveAfterDays = 30
    }
    Monthly = @{
        RetentionDays = 1095  # 3年
        ArchiveAfterDays = 90
    }
    Yearly = @{
        RetentionDays = 2555  # 7年（法的要件）
        ArchiveAfterDays = 365
    }
}
```

#### 🧹 レポートクリーンアップ
```powershell
function Start-ReportCleanup {
    $reportTypes = @("Daily", "Weekly", "Monthly", "Yearly")
    
    foreach ($type in $reportTypes) {
        $reportPath = "Reports\$type"
        $policy = $ReportRetentionPolicy[$type]
        
        # 保存期間を超えたレポートの削除
        $deleteCutoff = (Get-Date).AddDays(-$policy.RetentionDays)
        Get-ChildItem -Path $reportPath -File | 
        Where-Object {$_.LastWriteTime -lt $deleteCutoff} | 
        Remove-Item -Force
        
        # アーカイブ対象のレポート圧縮
        $archiveCutoff = (Get-Date).AddDays(-$policy.ArchiveAfterDays)
        Get-ChildItem -Path $reportPath -File -Include "*.html", "*.csv" | 
        Where-Object {$_.LastWriteTime -lt $archiveCutoff -and $_.Extension -ne ".zip"} | 
        ForEach-Object {
            $zipPath = $_.FullName.Replace($_.Extension, ".zip")
            Compress-Archive -Path $_.FullName -DestinationPath $zipPath
            Remove-Item $_.FullName -Force
        }
    }
}
```

---

## 🚨 アラート・インシデント対応

### ⚠️ アラート設定

#### 📊 システムアラート閾値
```json
{
  "AlertThresholds": {
    "System": {
      "CPUUsage": 80,
      "MemoryUsage": 85,
      "DiskUsage": 90
    },
    "Application": {
      "APIFailureRate": 5,
      "ResponseTimeMs": 10000,
      "ConcurrentSessions": 10
    },
    "Business": {
      "MailboxCapacityWarning": 80,
      "OneDriveCapacityWarning": 85,
      "LicenseUsageWarning": 90
    }
  }
}
```

#### 📧 通知設定
```powershell
# SMTPを使用したアラート通知
function Send-AlertNotification {
    param(
        [string]$AlertType,
        [string]$Message,
        [string]$Severity = "Warning"
    )
    
    $smtpSettings = @{
        SmtpServer = "smtp.contoso.com"
        Port = 587
        UseSsl = $true
        Credential = Get-Credential # 事前に設定された認証情報
    }
    
    $mailParams = @{
        To = "it-alerts@contoso.com"
        From = "microsoft365tools@contoso.com"
        Subject = "[$Severity] Microsoft 365統合管理ツール - $AlertType"
        Body = @"
アラート発生時刻: $(Get-Date)
アラート種別: $AlertType
重要度: $Severity
詳細: $Message

システム情報:
- コンピューター名: $env:COMPUTERNAME
- ユーザー: $env:USERNAME
- PowerShell版: $($PSVersionTable.PSVersion)
"@
    }
    
    Send-MailMessage @mailParams @smtpSettings
}
```

### 🛠️ インシデント対応手順

#### 🔄 一般的なトラブルシューティング
```powershell
# 1. システム健全性チェック
function Test-SystemHealth {
    $results = @{}
    
    # PowerShell環境確認
    $results.PowerShellVersion = $PSVersionTable.PSVersion
    $results.ExecutionPolicy = Get-ExecutionPolicy
    
    # 必須モジュール確認
    $requiredModules = @("Microsoft.Graph", "ExchangeOnlineManagement")
    $results.Modules = @{}
    foreach ($module in $requiredModules) {
        $results.Modules[$module] = Get-Module -ListAvailable $module | Select-Object Version
    }
    
    # 接続確認
    $results.GraphConnection = Test-GraphAPIConnection
    $results.ExchangeConnection = Test-ExchangeOnlineConnection
    
    # ディスク容量確認
    $results.DiskSpace = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" | 
                        Select-Object @{N="FreeGB";E={[math]::Round($_.FreeSpace/1GB,2)}}
    
    return $results
}

# 2. 自動修復試行
function Start-AutoRepair {
    Write-Host "🔧 自動修復を開始します..."
    
    # モジュール再インポート
    $modules = @("Microsoft.Graph", "ExchangeOnlineManagement")
    foreach ($module in $modules) {
        try {
            Remove-Module $module -Force -ErrorAction SilentlyContinue
            Import-Module $module -Force
            Write-Host "✅ $module を再インポートしました"
        }
        catch {
            Write-Warning "❌ $module の再インポートに失敗: $($_.Exception.Message)"
        }
    }
    
    # 接続の再確立
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "✅ 既存接続を切断しました"
    }
    catch {
        Write-Warning "接続切断時にエラーが発生しましたが、続行します"
    }
}
```

---

## 📈 パフォーマンス最適化

### ⚡ システム最適化

#### 💾 メモリ使用量最適化
```powershell
# ガベージコレクションの強制実行
function Optimize-Memory {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    $memBefore = [System.GC]::GetTotalMemory($false) / 1MB
    $memAfter = [System.GC]::GetTotalMemory($true) / 1MB
    
    Write-Host "メモリ最適化完了:"
    Write-Host "  実行前: $([math]::Round($memBefore, 2)) MB"
    Write-Host "  実行後: $([math]::Round($memAfter, 2)) MB"
    Write-Host "  削減量: $([math]::Round($memBefore - $memAfter, 2)) MB"
}
```

#### 🔄 キャッシュ管理
```powershell
# キャッシュクリア
function Clear-ApplicationCache {
    if ($Global:APICache) {
        $cacheCount = $Global:APICache.Count
        $Global:APICache.Clear()
        Write-Host "✅ APIキャッシュをクリアしました ($cacheCount 項目)"
    }
    
    # 一時ファイルのクリーンアップ
    $tempPath = Join-Path $env:TEMP "Microsoft365Tools"
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Recurse -Force
        Write-Host "✅ 一時ファイルをクリアしました"
    }
}
```

### 📊 監視ダッシュボード作成

#### 🌐 HTML監視ダッシュボード
```powershell
function New-MonitoringDashboard {
    $systemHealth = Test-SystemHealth
    $resourceUsage = Get-SystemResourceUsage
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Microsoft 365統合管理ツール - 監視ダッシュボード</title>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="300"> <!-- 5分間隔で自動更新 -->
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .dashboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .card h3 { margin-top: 0; color: #333; }
        .status-ok { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-error { color: #dc3545; }
        .metric { display: flex; justify-content: space-between; margin: 10px 0; }
        .progress-bar { width: 100%; height: 20px; background-color: #e9ecef; border-radius: 4px; overflow: hidden; }
        .progress-fill { height: 100%; transition: width 0.3s ease; }
        .progress-ok { background-color: #28a745; }
        .progress-warning { background-color: #ffc107; }
        .progress-error { background-color: #dc3545; }
    </style>
</head>
<body>
    <h1>📊 Microsoft 365統合管理ツール - 監視ダッシュボード</h1>
    <p>最終更新: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</p>
    
    <div class="dashboard">
        <div class="card">
            <h3>🖥️ システムリソース</h3>
            <div class="metric">
                <span>CPU使用率:</span>
                <span class="$( if($resourceUsage.CPUUsage -lt 70) {'status-ok'} elseif($resourceUsage.CPUUsage -lt 85) {'status-warning'} else {'status-error'} )">
                    $($resourceUsage.CPUUsage)%
                </span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill $( if($resourceUsage.CPUUsage -lt 70) {'progress-ok'} elseif($resourceUsage.CPUUsage -lt 85) {'progress-warning'} else {'progress-error'} )" 
                     style="width: $($resourceUsage.CPUUsage)%"></div>
            </div>
            
            <div class="metric">
                <span>使用可能メモリ:</span>
                <span class="status-ok">$($resourceUsage.AvailableMemoryMB) MB</span>
            </div>
            
            <div class="metric">
                <span>ディスク空き容量:</span>
                <span class="status-ok">$($resourceUsage.DiskFreeSpaceGB) GB</span>
            </div>
        </div>
        
        <div class="card">
            <h3>🌐 API接続状況</h3>
            <div class="metric">
                <span>Microsoft Graph:</span>
                <span class="$( if($systemHealth.GraphConnection.Status -eq 'Connected') {'status-ok'} else {'status-error'} )">
                    $($systemHealth.GraphConnection.Status)
                </span>
            </div>
            <div class="metric">
                <span>Exchange Online:</span>
                <span class="$( if($systemHealth.ExchangeConnection.Status -eq 'Connected') {'status-ok'} else {'status-error'} )">
                    $($systemHealth.ExchangeConnection.Status)
                </span>
            </div>
        </div>
        
        <div class="card">
            <h3>📦 モジュール状況</h3>
            <div class="metric">
                <span>Microsoft.Graph:</span>
                <span class="status-ok">$(if($systemHealth.Modules['Microsoft.Graph']) {'インストール済み'} else {'未インストール'})</span>
            </div>
            <div class="metric">
                <span>ExchangeOnlineManagement:</span>
                <span class="status-ok">$(if($systemHealth.Modules['ExchangeOnlineManagement']) {'インストール済み'} else {'未インストール'})</span>
            </div>
        </div>
    </div>
</body>
</html>
"@
    
    $dashboardPath = "Reports\System\MonitoringDashboard_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $html | Out-File -FilePath $dashboardPath -Encoding UTF8
    
    Write-Host "📊 監視ダッシュボードを生成しました: $dashboardPath"
    return $dashboardPath
}
```

---

## 📚 運用手順書

### 🌅 日次運用チェックリスト

#### ✅ 毎日の確認事項
- [ ] 🖥️ **システムリソース確認**: CPU/メモリ/ディスク使用量
- [ ] 🌐 **API接続状況確認**: Graph API・Exchange Online接続
- [ ] 📝 **エラーログ確認**: 新しいエラーやワーニングの有無
- [ ] 📊 **レポート生成確認**: 日次レポートの正常生成
- [ ] 🔒 **セキュリティログ確認**: 不審なアクセスやログイン失敗

#### 🔧 日次メンテナンス
```powershell
# 日次メンテナンススクリプト
function Start-DailyMaintenance {
    Write-Host "🌅 日次メンテナンスを開始します..."
    
    # 1. システム健全性チェック
    $health = Test-SystemHealth
    Write-Host "✅ システム健全性チェック完了"
    
    # 2. リソース使用量確認
    $resources = Get-SystemResourceUsage
    Write-Host "✅ リソース使用量確認完了"
    
    # 3. ログローテーション（必要に応じて）
    Start-LogRotation -RetentionDays 365
    Write-Host "✅ ログローテーション完了"
    
    # 4. キャッシュクリア
    Clear-ApplicationCache
    Write-Host "✅ キャッシュクリア完了"
    
    # 5. 監視ダッシュボード生成
    $dashboardPath = New-MonitoringDashboard
    Write-Host "✅ 監視ダッシュボード生成完了: $dashboardPath"
    
    Write-Host "🎉 日次メンテナンス完了"
}
```

### 📅 週次運用チェックリスト

#### ✅ 毎週の確認事項
- [ ] 🔒 **証明書有効期限確認**: 30日以内に期限切れの証明書確認
- [ ] 📈 **週次レポート確認**: 傾向分析と異常値の確認
- [ ] 🛡️ **セキュリティ監査**: アクセスログの詳細分析
- [ ] 📦 **モジュール更新確認**: PowerShellモジュールの更新有無
- [ ] 💾 **バックアップ確認**: 設定ファイル・重要データのバックアップ

### 📆 月次運用チェックリスト

#### ✅ 毎月の確認事項
- [ ] 📊 **月次レポート分析**: 詳細な利用状況・トレンド分析
- [ ] 💰 **年間消費傾向確認**: 予算との照合・予測分析
- [ ] 🔄 **システム更新**: セキュリティパッチ・機能更新の適用
- [ ] 📋 **コンプライアンス監査**: ISO準拠状況の確認
- [ ] 🧹 **データクリーンアップ**: 不要なログ・レポートの削除

---

**🎯 適切な運用管理により、Microsoft 365統合管理ツールの安定稼働と最大効果を実現しましょう！**

---

*📅 最終更新: 2025年6月 | 🛠️ システム管理者向け運用マニュアル v1.0*