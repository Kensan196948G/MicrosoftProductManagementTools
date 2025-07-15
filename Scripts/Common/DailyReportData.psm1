# ================================================================================
# DailyReportData.psm1
# 日次レポート用実データ取得モジュール
# Microsoft 365の実際のデータを取得し、フォールバック機能を提供
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\RealM365DataProvider.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\RealDataProvider.psm1" -Force -ErrorAction SilentlyContinue

# 日次レポート用統合データ取得（実データ優先）
function Get-DailyReportRealData {
    param(
        [switch]$ForceRealData = $false,
        [switch]$UseSampleData = $false
    )
    
    Write-Log "日次レポートデータ取得を開始します" -Level "Info"
    
    $reportData = @{
        UserActivity = @()
        MailboxCapacity = @()
        SecurityAlerts = @()
        MFAStatus = @()
        Summary = @{}
        DataSource = "Microsoft365API"  # デフォルトで実データを期待
        GeneratedAt = Get-Date
    }
    
    try {
        # 実データ取得を試行
        if (-not $UseSampleData) {
            Write-Log "Microsoft 365実データ取得を試行中..." -Level "Info"
            
            # 接続状態確認
            $isConnected = $false
            try {
                # まず認証を試行
                if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
                    Write-Log "Microsoft Graphに未接続のため、認証を実行します..." -Level "Info"
                    # 設定を読み込んで認証
                    try {
                        $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                        $configPath = Join-Path $toolRoot "Config\appsettings.json"
                        $localConfigPath = Join-Path $toolRoot "Config\appsettings.local.json"
                        
                        if (Test-Path $localConfigPath) {
                            $config = Get-Content $localConfigPath | ConvertFrom-Json
                        } elseif (Test-Path $configPath) {
                            $config = Get-Content $configPath | ConvertFrom-Json
                        }
                        
                        if ($config) {
                            $authResult = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph") -ErrorAction Stop
                            if (-not $authResult.Success) {
                                Write-Log "Microsoft Graph認証に失敗しました" -Level "Warning"
                            }
                        }
                    } catch {
                        Write-Log "認証設定の読み込みエラー: $($_.Exception.Message)" -Level "Warning"
                    }
                }
                
                # Microsoft Graph接続確認
                if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
                    if ($mgContext) {
                        Write-Log "Microsoft Graph接続確認: 成功" -Level "Debug"
                        $isConnected = $true
                    }
                }
                
                # Exchange Online接続確認
                if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
                    $exoConnection = Get-ConnectionInformation -ErrorAction SilentlyContinue
                    if (-not $exoConnection) {
                        Write-Log "Exchange Onlineに未接続のため、認証を実行します..." -Level "Info"
                        try {
                            $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                            $configPath = Join-Path $toolRoot "Config\appsettings.json"
                            $localConfigPath = Join-Path $toolRoot "Config\appsettings.local.json"
                            
                            if (Test-Path $localConfigPath) {
                                $config = Get-Content $localConfigPath | ConvertFrom-Json
                            } elseif (Test-Path $configPath) {
                                $config = Get-Content $configPath | ConvertFrom-Json
                            }
                            
                            if ($config) {
                                $authResult = Connect-ToMicrosoft365 -Config $config -Services @("ExchangeOnline") -ErrorAction Stop
                                if (-not $authResult.Success) {
                                    Write-Log "Exchange Online認証に失敗しました" -Level "Warning"
                                }
                            }
                        } catch {
                            Write-Log "Exchange Online接続エラー: $($_.Exception.Message)" -Level "Warning"
                        }
                    } else {
                        Write-Log "Exchange Online接続確認: 成功" -Level "Debug"
                    }
                }
            }
            catch {
                Write-Log "接続確認エラー: $($_.Exception.Message)" -Level "Warning"
            }
            
            if ($isConnected -or $ForceRealData) {
                try {
                    # ユーザーアクティビティデータ
                    Write-Log "ユーザーアクティビティデータを取得中..." -Level "Info"
                    $reportData.UserActivity = Get-UserActivityRealData
                    
                    # メールボックス容量データ
                    Write-Log "メールボックス容量データを取得中..." -Level "Info"
                    $reportData.MailboxCapacity = Get-MailboxCapacityRealData
                    
                    # セキュリティアラートデータ
                    Write-Log "セキュリティアラートデータを取得中..." -Level "Info"
                    $reportData.SecurityAlerts = Get-SecurityAlertsRealData
                    
                    # MFA状況データ
                    Write-Log "MFA状況データを取得中..." -Level "Info"
                    $reportData.MFAStatus = Get-MFAStatusRealData
                    
                    $reportData.DataSource = "Microsoft365API"
                    Write-Log "実データ取得成功" -Level "Info"
                }
                catch {
                    Write-Log "実データ取得中にエラーが発生しました: $($_.Exception.Message)" -Level "Warning"
                    if ($ForceRealData) {
                        throw
                    }
                    # フォールバックへ
                    $reportData.DataSource = "SampleData"
                }
            }
            else {
                Write-Log "Microsoft 365への接続が無効です。サンプルデータを使用します。" -Level "Warning"
                $reportData.DataSource = "SampleData"
            }
        }
        
        # サンプルデータ使用（フォールバック）
        if ($reportData.DataSource -eq "SampleData" -or $UseSampleData) {
            Write-Log "サンプルデータを生成中..." -Level "Info"
            
            # ユーザーアクティビティ（サンプル）
            $reportData.UserActivity = Get-UserActivitySampleData
            
            # メールボックス容量（サンプル）
            $reportData.MailboxCapacity = Get-MailboxCapacitySampleData
            
            # セキュリティアラート（サンプル）
            $reportData.SecurityAlerts = Get-SecurityAlertsSampleData
            
            # MFA状況（サンプル）
            $reportData.MFAStatus = Get-MFAStatusSampleData
        }
        
        # サマリー情報生成（日本語項目名）
        $reportData.Summary = @{
            総ユーザー数 = $reportData.UserActivity.Count
            アクティブユーザー数 = ($reportData.UserActivity | Where-Object { $_.Status -eq "アクティブ" }).Count
            非アクティブユーザー数 = ($reportData.UserActivity | Where-Object { $_.Status -eq "非アクティブ" }).Count
            監視対象メールボックス数 = $reportData.MailboxCapacity.Count
            メールボックス警告数 = ($reportData.MailboxCapacity | Where-Object { $_.Status -in @("警告", "危険") }).Count
            セキュリティアラート総数 = $reportData.SecurityAlerts.Count
            高リスクアラート数 = ($reportData.SecurityAlerts | Where-Object { $_.Severity -eq "高" }).Count
            MFA設定済みユーザー数 = ($reportData.MFAStatus | Where-Object { $_.HasMFA -eq $true }).Count
            MFA未設定ユーザー数 = ($reportData.MFAStatus | Where-Object { $_.HasMFA -eq $false }).Count
            データソース = $reportData.DataSource
            レポート生成日時 = $reportData.GeneratedAt.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Write-Log "日次レポートデータ取得完了 (ソース: $($reportData.DataSource))" -Level "Info"
        return $reportData
    }
    catch {
        Write-Log "日次レポートデータ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# ユーザーアクティビティ実データ取得
function Get-UserActivityRealData {
    try {
        Write-Log "ユーザー基本情報を取得中（E3ライセンス対応版）..." -Level "Debug"
        
        # E3ライセンスで取得可能な基本情報のみ取得（全ユーザー取得）
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled,LastPasswordChangeDateTime,CreatedDateTime
        
        $activities = @()
        $today = Get-Date
        
        foreach ($user in $users) {
            if ($user.AccountEnabled) {
                # E3ライセンスではSignInActivityは利用不可のため、代替指標を使用
                $lastPasswordChange = $null
                $daysSinceActivity = 999
                $activityIndicator = "不明"
                
                # パスワード変更日時を活動の指標として使用
                if ($user.LastPasswordChangeDateTime) {
                    $lastPasswordChange = [DateTime]::Parse($user.LastPasswordChangeDateTime)
                    $daysSinceActivity = ($today - $lastPasswordChange).Days
                    $activityIndicator = "パスワード変更"
                }
                
                # アカウント作成日も考慮
                $accountAge = 999
                if ($user.CreatedDateTime) {
                    $createdDate = [DateTime]::Parse($user.CreatedDateTime)
                    $accountAge = ($today - $createdDate).Days
                }
                
                # 新規アカウント（30日以内）の場合はアクティブとみなす
                if ($accountAge -le 30) {
                    $daysSinceActivity = 0
                    $activityIndicator = "新規アカウント"
                }
                
                $activities += [PSCustomObject]@{
                    ユーザー名 = $user.DisplayName
                    メールアドレス = $user.UserPrincipalName
                    アカウント作成日 = if ($user.CreatedDateTime) { [DateTime]::Parse($user.CreatedDateTime).ToString("yyyy-MM-dd") } else { "不明" }
                    最終パスワード変更 = if ($lastPasswordChange) { $lastPasswordChange.ToString("yyyy-MM-dd") } else { "未変更" }
                    パスワード未変更日数 = $daysSinceActivity
                    アクティビティ状態 = if ($daysSinceActivity -eq 0) { "✓ アクティブ（推定）" }
                            elseif ($daysSinceActivity -le 90) { "○ 通常" }
                            elseif ($daysSinceActivity -le 180) { "△ 要確認" }
                            else { "✗ 長期未更新" }
                    セキュリティリスク = if ($daysSinceActivity -gt 365) { "⚠️ 高リスク" }
                            elseif ($daysSinceActivity -gt 180) { "⚡ 中リスク" }
                            else { "✓ 低リスク" }
                    推奨アクション = if ($daysSinceActivity -gt 365) { "パスワード変更を強く推奨" }
                            elseif ($daysSinceActivity -gt 180) { "パスワード変更を推奨" }
                            elseif ($daysSinceActivity -gt 90) { "状況を確認" }
                            else { "対応不要" }
                }
            }
        }
        
        Write-Log "E3ライセンスでのユーザーアクティビティ取得完了（${activities.Count}件）" -Level "Info"
        return $activities | Sort-Object パスワード未変更日数 -Descending
    }
    catch {
        Write-Log "ユーザーアクティビティ実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# メールボックス容量実データ取得
function Get-MailboxCapacityRealData {
    try {
        $mailboxes = @()
        
        # Exchange Online接続確認
        if (Test-ExchangeOnlineConnection) {
            $mbxList = Get-Mailbox -ResultSize Unlimited
            
            foreach ($mbx in $mbxList) {
                $stats = Get-MailboxStatistics -Identity $mbx.Identity
                
                # サイズ計算
                $totalSizeGB = 0
                if ($stats.TotalItemSize) {
                    $sizeString = $stats.TotalItemSize.ToString()
                    if ($sizeString -match '(\d+(?:\.\d+)?)\s*(GB|MB|KB|B)') {
                        $size = [double]$matches[1]
                        $unit = $matches[2]
                        
                        switch ($unit) {
                            'GB' { $totalSizeGB = $size }
                            'MB' { $totalSizeGB = $size / 1024 }
                            'KB' { $totalSizeGB = $size / 1024 / 1024 }
                            'B'  { $totalSizeGB = $size / 1024 / 1024 / 1024 }
                        }
                    }
                }
                
                # クォータ取得
                $quotaGB = 100  # デフォルト
                if ($mbx.ProhibitSendQuota -and $mbx.ProhibitSendQuota -ne "Unlimited") {
                    $quotaString = $mbx.ProhibitSendQuota.ToString()
                    if ($quotaString -match '(\d+(?:\.\d+)?)\s*(GB|MB)') {
                        $quota = [double]$matches[1]
                        $unit = $matches[2]
                        $quotaGB = if ($unit -eq 'GB') { $quota } else { $quota / 1024 }
                    }
                }
                
                $usagePercent = if ($quotaGB -gt 0) { 
                    [Math]::Round(($totalSizeGB / $quotaGB) * 100, 2) 
                } else { 0 }
                
                $mailboxes += [PSCustomObject]@{
                    メールボックス = $mbx.DisplayName
                    メールアドレス = $mbx.PrimarySmtpAddress
                    使用容量GB = [Math]::Round($totalSizeGB, 2)
                    制限容量GB = $quotaGB
                    使用率 = $usagePercent
                    アイテム数 = $stats.ItemCount
                    Status = if ($usagePercent -ge 90) { "危険" }
                            elseif ($usagePercent -ge 80) { "警告" }
                            else { "正常" }
                    最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                }
            }
        }
        else {
            throw "Exchange Online未接続"
        }
        
        return $mailboxes | Sort-Object 使用率 -Descending
    }
    catch {
        Write-Log "メールボックス容量実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# セキュリティアラート実データ取得
function Get-SecurityAlertsRealData {
    try {
        $alerts = @()
        $today = Get-Date
        
        Write-Log "E3ライセンスでのセキュリティアラート取得を開始（代替方法使用）" -Level "Debug"
        
        # E3ライセンスでは監査ログやリスクユーザーAPIが使用できないため
        # 代わりに以下の情報を収集:
        
        # 1. 無効化されたユーザーの確認
        try {
            $disabledUsers = Get-MgUser -Filter "accountEnabled eq false" -Top 20 -Property DisplayName,UserPrincipalName,LastPasswordChangeDateTime
            
            foreach ($user in $disabledUsers) {
                $alerts += [PSCustomObject]@{
                    アラートID = "DISABLED-$($alerts.Count + 1)"
                    種類 = "無効化ユーザー"
                    Severity = "中"
                    ユーザー = $user.UserPrincipalName
                    詳細 = "アカウントが無効化されています"
                    IPアドレス = "N/A"
                    場所 = "N/A"
                    検出時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                    Status = "要確認"
                }
            }
        }
        catch {
            Write-Log "無効化ユーザー確認エラー: $($_.Exception.Message)" -Level "Warning"
        }
        
        # 2. 長期間パスワード未変更ユーザーの検出
        try {
            $users = Get-MgUser -Filter "accountEnabled eq true" -Top 100 -Property DisplayName,UserPrincipalName,LastPasswordChangeDateTime
            
            foreach ($user in $users) {
                if ($user.LastPasswordChangeDateTime) {
                    $lastChange = [DateTime]::Parse($user.LastPasswordChangeDateTime)
                    $daysSinceChange = ($today - $lastChange).Days
                    
                    if ($daysSinceChange -gt 365) {
                        $alerts += [PSCustomObject]@{
                            アラートID = "PWDAGE-$($alerts.Count + 1)"
                            種類 = "パスワード期限"
                            Severity = if ($daysSinceChange -gt 730) { "高" } else { "中" }
                            ユーザー = $user.UserPrincipalName
                            詳細 = "パスワード未変更: $daysSinceChange 日"
                            IPアドレス = "N/A"
                            場所 = "N/A"
                            検出時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                            Status = "未対応"
                        }
                    }
                }
            }
        }
        catch {
            Write-Log "パスワード期限確認エラー: $($_.Exception.Message)" -Level "Warning"
        }
        
        # 3. 管理者権限を持つユーザーの確認
        try {
            # Global Administratorロールを持つユーザーを確認
            $adminRole = Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'" -ErrorAction Stop
            if ($adminRole) {
                # 全メンバーを取得
                $adminMembers = Get-MgDirectoryRoleMember -DirectoryRoleId $adminRole.Id -All -ErrorAction Stop
                
                # メンバー数をカウント
                $memberCount = @($adminMembers).Count
                
                if ($memberCount -gt 5) {
                    $alerts += [PSCustomObject]@{
                        アラートID = "ADMIN-001"
                        種類 = "管理者数"
                        Severity = "中"
                        ユーザー = "システム"
                        詳細 = "グローバル管理者が多数存在: $memberCount 名"
                        IPアドレス = "N/A"
                        場所 = "N/A"
                        検出時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                        Status = "要確認"
                    }
                }
                
                # 管理者の詳細情報も個別アラートとして追加（最初の5名まで）
                $adminCount = 0
                foreach ($member in $adminMembers) {
                    $adminCount++
                    if ($adminCount -le 5) {
                        try {
                            # メンバーのUPN取得
                            $adminUser = Get-MgUser -UserId $member.Id -Property UserPrincipalName,DisplayName -ErrorAction Stop
                            $alerts += [PSCustomObject]@{
                                アラートID = "ADMIN-USER-$adminCount"
                                種類 = "管理者アカウント"
                                Severity = "低"
                                ユーザー = $adminUser.UserPrincipalName
                                詳細 = "グローバル管理者: $($adminUser.DisplayName)"
                                IPアドレス = "N/A"
                                場所 = "N/A"
                                検出時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                                Status = "情報"
                            }
                        }
                        catch {
                            Write-Log "管理者情報取得エラー: $($_.Exception.Message)" -Level "Debug"
                        }
                    }
                }
            }
        }
        catch {
            Write-Log "管理者権限確認エラー: $($_.Exception.Message)" -Level "Warning"
            
            # エラーが特定のページサイズ問題の場合、別の方法を試す
            if ($_.Exception.Message -match "page size") {
                try {
                    Write-Log "代替方法で管理者確認を実行" -Level "Debug"
                    $adminRole = Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'" -ErrorAction Stop
                    if ($adminRole) {
                        # ConsistencyLevel headerを使用しない単純な取得
                        $adminMembers = Get-MgDirectoryRoleMember -DirectoryRoleId $adminRole.Id -ErrorAction Stop
                        $memberCount = @($adminMembers).Count
                        
                        $alerts += [PSCustomObject]@{
                            アラートID = "ADMIN-COUNT"
                            種類 = "管理者数確認"
                            Severity = if ($memberCount -gt 5) { "中" } else { "低" }
                            ユーザー = "システム"
                            詳細 = "グローバル管理者数: $memberCount 名"
                            IPアドレス = "N/A"
                            場所 = "N/A"
                            検出時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                            Status = "情報"
                        }
                    }
                }
                catch {
                    Write-Log "代替方法での管理者確認も失敗: $($_.Exception.Message)" -Level "Warning"
                }
            }
        }
        
        Write-Log "E3ライセンスでのセキュリティアラート取得完了（$($alerts.Count)件）" -Level "Info"
        return $alerts | Sort-Object 検出時刻 -Descending
    }
    catch {
        Write-Log "セキュリティアラート実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# MFA状況実データ取得
function Get-MFAStatusRealData {
    try {
        $mfaStatus = @()
        
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType
        
        foreach ($user in $users) {
            if ($user.AccountEnabled -and $user.UserType -eq "Member") {
                try {
                    $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id
                    
                    $hasMFA = $false
                    $mfaMethods = @()
                    
                    foreach ($method in $authMethods) {
                        $methodType = $method.AdditionalProperties.'@odata.type'
                        switch ($methodType) {
                            '#microsoft.graph.phoneAuthenticationMethod' {
                                $hasMFA = $true
                                $mfaMethods += "電話"
                            }
                            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
                                $hasMFA = $true
                                $mfaMethods += "Authenticator"
                            }
                            '#microsoft.graph.fido2AuthenticationMethod' {
                                $hasMFA = $true
                                $mfaMethods += "FIDO2"
                            }
                        }
                    }
                    
                    $mfaStatus += [PSCustomObject]@{
                        ユーザー名 = $user.DisplayName
                        メールアドレス = $user.UserPrincipalName
                        HasMFA = $hasMFA
                        MFA状況 = if ($hasMFA) { "設定済み" } else { "未設定" }
                        認証方法 = if ($mfaMethods.Count -gt 0) { $mfaMethods -join ", " } else { "なし" }
                        リスク = if (-not $hasMFA) { "高" } else { "低" }
                        最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                    }
                }
                catch {
                    Write-Log "ユーザー $($user.UserPrincipalName) のMFA情報取得エラー" -Level "Warning"
                }
            }
        }
        
        return $mfaStatus | Sort-Object HasMFA, ユーザー名
    }
    catch {
        Write-Log "MFA状況実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# サンプルデータ生成関数群
function Get-UserActivitySampleData {
    $activities = @()
    $today = Get-Date
    
    for ($i = 1; $i -le 50; $i++) {
        $daysSince = Get-Random -Minimum 0 -Maximum 500
        $accountCreated = (Get-Date).AddDays(-(Get-Random -Minimum 30 -Maximum 1000))
        $lastPasswordChange = (Get-Date).AddDays(-$daysSince)
        
        $activities += [PSCustomObject]@{
            ユーザー名 = "テストユーザー$i"
            メールアドレス = "user$i@miraiconst.onmicrosoft.com"
            アカウント作成日 = $accountCreated.ToString("yyyy-MM-dd")
            最終パスワード変更 = $lastPasswordChange.ToString("yyyy-MM-dd")
            パスワード未変更日数 = $daysSince
            アクティビティ状態 = if ($daysSince -eq 0) { "✓ アクティブ（推定）" }
                    elseif ($daysSince -le 90) { "○ 通常" }
                    elseif ($daysSince -le 180) { "△ 要確認" }
                    else { "✗ 長期未更新" }
            セキュリティリスク = if ($daysSince -gt 365) { "⚠️ 高リスク" }
                    elseif ($daysSince -gt 180) { "⚡ 中リスク" }
                    else { "✓ 低リスク" }
            推奨アクション = if ($daysSince -gt 365) { "パスワード変更を強く推奨" }
                    elseif ($daysSince -gt 180) { "パスワード変更を推奨" }
                    elseif ($daysSince -gt 90) { "状況を確認" }
                    else { "対応不要" }
        }
    }
    
    return $activities | Sort-Object パスワード未変更日数 -Descending
}

function Get-MailboxCapacitySampleData {
    $mailboxes = @()
    for ($i = 1; $i -le 30; $i++) {
        $usedGB = Get-Random -Minimum 5 -Maximum 95
        $quotaGB = 100
        $usagePercent = [Math]::Round(($usedGB / $quotaGB) * 100, 2)
        
        $mailboxes += [PSCustomObject]@{
            メールボックス = "ユーザー$i"
            メールアドレス = "user$i@miraiconst.onmicrosoft.com"
            使用容量GB = $usedGB
            制限容量GB = $quotaGB
            使用率 = $usagePercent
            アイテム数 = Get-Random -Minimum 1000 -Maximum 50000
            Status = if ($usagePercent -ge 90) { "危険" }
                    elseif ($usagePercent -ge 80) { "警告" }
                    else { "正常" }
            最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        }
    }
    
    return $mailboxes | Sort-Object 使用率 -Descending
}

function Get-SecurityAlertsSampleData {
    $alertTypes = @("サインイン失敗", "異常アクセス", "権限昇格試行", "不審なダウンロード", "パスワード攻撃")
    $severities = @("高", "中", "低")
    $locations = @("東京, 日本", "大阪, 日本", "不明", "海外", "VPN経由")
    
    $alerts = @()
    for ($i = 1; $i -le 15; $i++) {
        $alerts += [PSCustomObject]@{
            アラートID = "ALERT-$(Get-Random -Minimum 1000 -Maximum 9999)"
            種類 = $alertTypes | Get-Random
            Severity = $severities | Get-Random
            ユーザー = "user$(Get-Random -Minimum 1 -Maximum 50)@miraiconst.onmicrosoft.com"
            詳細 = "セキュリティイベントが検出されました"
            IPアドレス = "192.168.$(Get-Random -Minimum 1 -Maximum 255).$(Get-Random -Minimum 1 -Maximum 255)"
            場所 = $locations | Get-Random
            検出時刻 = (Get-Date).AddHours(-(Get-Random -Minimum 0 -Maximum 24)).ToString("yyyy-MM-dd HH:mm")
            Status = @("未対応", "調査中", "対応済") | Get-Random
        }
    }
    
    return $alerts | Sort-Object 検出時刻 -Descending
}

function Get-MFAStatusSampleData {
    $mfaStatus = @()
    for ($i = 1; $i -le 100; $i++) {
        $hasMFA = (Get-Random -Minimum 0 -Maximum 100) -gt 30  # 70%がMFA設定済み
        $methods = @("Authenticator", "電話", "SMS", "FIDO2")
        
        $mfaStatus += [PSCustomObject]@{
            ユーザー名 = "ユーザー$i"
            メールアドレス = "user$i@miraiconst.onmicrosoft.com"
            HasMFA = $hasMFA
            MFA状況 = if ($hasMFA) { "設定済み" } else { "未設定" }
            認証方法 = if ($hasMFA) { 
                $methods | Get-Random -Count (Get-Random -Minimum 1 -Maximum 3) | Join-String -Separator ", "
            } else { "なし" }
            リスク = if (-not $hasMFA) { "高" } else { "低" }
            最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        }
    }
    
    return $mfaStatus | Sort-Object HasMFA, ユーザー名
}

# エクスポート
Export-ModuleMember -Function @(
    'Get-DailyReportRealData',
    'Get-UserActivityRealData',
    'Get-MailboxCapacityRealData', 
    'Get-SecurityAlertsRealData',
    'Get-MFAStatusRealData'
)