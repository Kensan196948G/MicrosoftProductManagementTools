# ================================================================================
# UserManagement.psm1
# UM系 - ユーザー管理機能モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ReportGenerator.psm1" -Force

# UM-03: MFA未設定者抽出
function Get-UsersWithoutMFA {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "MFA未設定者抽出を開始します" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            # 設定ファイル読み込み
            try {
                # Common.psm1が正しくインポートされているか確認
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                # Microsoft Graph接続試行
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # 全ユーザーの取得（ライセンス制限対応）
        Write-Log "ユーザー一覧を取得中..." -Level "Info"
        
        try {
            # Microsoft 365 E3対応：基本プロパティのみ取得
            $allUsers = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime
            Write-Log "Microsoft 365 E3環境での基本ユーザー情報取得" -Level "Info"
        }
        catch {
            Write-Log "ユーザー取得エラー: $($_.Exception.Message)" -Level "Error"
            # 最小限のプロパティで再試行
            $allUsers = Get-MgUser -All
            Write-Log "最小限プロパティでの取得完了" -Level "Warning"
        }
        
        Write-Log "取得完了: $($allUsers.Count)名のユーザー" -Level "Info"
        
        # MFA設定状況を確認
        $mfaResults = @()
        $progressCount = 0
        
        foreach ($user in $allUsers) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "MFA設定確認中" -Status "$progressCount/$($allUsers.Count)" -PercentComplete (($progressCount / $allUsers.Count) * 100)
            }
            
            try {
                # MFA認証方法の確認
                $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction SilentlyContinue
                
                # MFA有効な認証方法をチェック
                $mfaMethods = @()
                $hasMFA = $false
                
                if ($authMethods) {
                    foreach ($method in $authMethods) {
                        switch ($method.AdditionalProperties["@odata.type"]) {
                            "#microsoft.graph.phoneAuthenticationMethod" {
                                $mfaMethods += "電話"
                                $hasMFA = $true
                            }
                            "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                                $mfaMethods += "Authenticatorアプリ"
                                $hasMFA = $true
                            }
                            "#microsoft.graph.emailAuthenticationMethod" {
                                $mfaMethods += "メール"
                                # メールのみの場合は完全なMFAとは見なさない
                            }
                            "#microsoft.graph.fido2AuthenticationMethod" {
                                $mfaMethods += "FIDO2キー"
                                $hasMFA = $true
                            }
                            "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                                $mfaMethods += "Windows Hello"
                                $hasMFA = $true
                            }
                        }
                    }
                }
                
                # ライセンス確認（E3環境：個別取得方式）
                $hasLicense = $false
                $licenseInfo = "なし"
                
                try {
                    # E3でも個別ライセンス情報は取得可能
                    $userLicenses = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
                    if ($userLicenses -and $userLicenses.Count -gt 0) {
                        $hasLicense = $true
                        $licenseNames = @()
                        foreach ($license in $userLicenses) {
                            if ($license.SkuPartNumber) {
                                $licenseNames += $license.SkuPartNumber
                            }
                        }
                        $licenseInfo = if ($licenseNames.Count -gt 0) { $licenseNames -join ", " } else { "ライセンス詳細不明" }
                    }
                }
                catch {
                    # E3でライセンス個別取得も失敗した場合
                    $licenseInfo = "取得エラー"
                    Write-Log "ユーザー $($user.UserPrincipalName) のライセンス取得エラー: $($_.Exception.Message)" -Level "Debug"
                }
                
                # 最終サインイン確認（E3環境テスト）
                $lastSignIn = "不明"
                $includeSignInData = $true
                
                try {
                    # サインイン情報が取得できるかテスト
                    if ($user.SignInActivity -and $user.SignInActivity.LastSignInDateTime) {
                        $lastSignIn = $user.SignInActivity.LastSignInDateTime.ToString("yyyy/MM/dd HH:mm")
                    }
                    else {
                        $lastSignIn = "サインイン履歴なし"
                    }
                }
                catch {
                    # E3制限でサインイン情報が取得できない場合
                    $lastSignIn = "E3制限"
                    $includeSignInData = $false
                    Write-Log "サインイン情報はE3ライセンスでは制限されています" -Level "Warning"
                }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    HasMFA = $hasMFA
                    MFAMethods = if ($mfaMethods.Count -gt 0) { $mfaMethods -join ", " } else { "なし" }
                    HasLicense = $hasLicense
                    LicenseInfo = $licenseInfo
                    LastSignIn = $lastSignIn
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = if (-not $hasMFA -and $user.AccountEnabled -and $hasLicense) { "高" } 
                               elseif (-not $hasMFA -and $user.AccountEnabled) { "中" } 
                               else { "低" }
                    UserId = $user.Id
                }
                
                $mfaResults += $result
                
            }
            catch {
                Write-Log "ユーザー $($user.UserPrincipalName) のMFA確認エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    HasMFA = $false
                    MFAMethods = "確認エラー"
                    HasLicense = $user.AssignedLicenses.Count -gt 0
                    LicenseInfo = "確認エラー"
                    LastSignIn = "確認エラー"
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = "要確認"
                    UserId = $user.Id
                }
                
                $mfaResults += $result
            }
        }
        
        Write-Progress -Activity "MFA設定確認中" -Completed
        
        # 結果集計
        $totalUsers = $mfaResults.Count
        $mfaEnabledUsers = ($mfaResults | Where-Object { $_.HasMFA -eq $true }).Count
        $mfaDisabledUsers = $totalUsers - $mfaEnabledUsers
        $highRiskUsers = ($mfaResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        $enabledUsersWithoutMFA = ($mfaResults | Where-Object { $_.AccountEnabled -eq $true -and $_.HasMFA -eq $false }).Count
        
        # サインイン情報の取得可否を確認
        $signInDataAvailable = $mfaResults | Where-Object { $_.LastSignIn -ne "E3制限" } | Measure-Object | Select-Object -ExpandProperty Count
        $signInSupported = $signInDataAvailable -gt 0
        
        Write-Log "MFA設定確認完了" -Level "Info"
        Write-Log "総ユーザー数: $totalUsers" -Level "Info"
        Write-Log "MFA設定済み: $mfaEnabledUsers" -Level "Info"
        Write-Log "MFA未設定: $mfaDisabledUsers" -Level "Info"
        Write-Log "高リスクユーザー: $highRiskUsers" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== MFA未設定者一覧 ===" -ForegroundColor Yellow
            
            $mfaDisabledList = $mfaResults | Where-Object { $_.HasMFA -eq $false -and $_.AccountEnabled -eq $true } | Sort-Object RiskLevel -Descending
            
            foreach ($user in $mfaDisabledList) {
                $riskColor = switch ($user.RiskLevel) {
                    "高" { "Red" }
                    "中" { "Yellow" }
                    default { "Gray" }
                }
                
                Write-Host "[$($user.RiskLevel)] $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor $riskColor
                
                # サインイン情報がE3制限でない場合のみ表示
                if ($user.LastSignIn -ne "E3制限" -and $user.LastSignIn -ne "不明") {
                    Write-Host "  最終ログイン: $($user.LastSignIn)" -ForegroundColor Gray
                }
                elseif ($user.LastSignIn -eq "E3制限") {
                    Write-Host "  最終ログイン: E3ライセンスでは取得制限あり" -ForegroundColor Yellow
                }
                
                Write-Host "  ライセンス: $($user.LicenseInfo)" -ForegroundColor Gray
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\MFA_Analysis_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8、空データ対応）
            if ($mfaResults -and $mfaResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $mfaResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $mfaResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            else {
                # データが空の場合のヘッダーのみ出力
                $emptyContent = @('"DisplayName","UserPrincipalName","AccountEnabled","HasMFA","MFAMethods","HasLicense","LicenseInfo","LastSignIn","CreatedDate","RiskLevel","UserId"', '"データなし","","","","","","","","","",""')
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $emptyContent, $utf8WithBom)
                }
                else {
                    $emptyContent | Out-File -FilePath $OutputPath -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\MFA_Analysis_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-MFAReportHTML -MFAResults $mfaResults -Summary @{
                TotalUsers = $totalUsers
                MFAEnabledUsers = $mfaEnabledUsers
                MFADisabledUsers = $mfaDisabledUsers
                HighRiskUsers = $highRiskUsers
                EnabledUsersWithoutMFA = $enabledUsersWithoutMFA
                SignInSupported = $signInSupported
                LicenseEnvironment = "Microsoft 365 E3"
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalUsers = $totalUsers
            MFAEnabledUsers = $mfaEnabledUsers
            MFADisabledUsers = $mfaDisabledUsers
            HighRiskUsers = $highRiskUsers
            EnabledUsersWithoutMFA = $enabledUsersWithoutMFA
            SignInSupported = $signInSupported
            LicenseEnvironment = "Microsoft 365 E3"
            DetailedResults = $mfaResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "MFA未設定者抽出エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# UM-02: ログイン失敗アラート検出
function Get-FailedSignInAlerts {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Days = 7,
        
        [Parameter(Mandatory = $false)]
        [int]$ThresholdCount = 5
    )
    
    Write-Log "ログイン失敗アラート検出を開始します (過去${Days}日間)" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            # 設定ファイル読み込み
            try {
                # Common.psm1が正しくインポートされているか確認
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                # Microsoft Graph接続試行
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        $startDate = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        # サインインログ取得
        Write-Log "サインインログを取得中..." -Level "Info"
        
        try {
            $signInLogs = Get-MgAuditLogSignIn -Filter "createdDateTime ge $startDate and status/errorCode ne 0" -All
            
            Write-Log "取得完了: $($signInLogs.Count)件の失敗ログ" -Level "Info"
            
            # ユーザー別集計
            $failedSignInsByUser = $signInLogs | Group-Object UserPrincipalName | ForEach-Object {
                [PSCustomObject]@{
                    UserPrincipalName = $_.Name
                    FailureCount = $_.Count
                    LastFailure = ($_.Group | Sort-Object CreatedDateTime -Descending | Select-Object -First 1).CreatedDateTime
                    ErrorCodes = ($_.Group | Group-Object { $_.Status.ErrorCode } | ForEach-Object { "$($_.Name)($($_.Count))" }) -join ", "
                    IsAlert = $_.Count -ge $ThresholdCount
                }
            }
            
            $alerts = $failedSignInsByUser | Where-Object { $_.IsAlert -eq $true } | Sort-Object FailureCount -Descending
            
            Write-Log "アラート対象ユーザー: $($alerts.Count)名" -Level "Info"
            
            return @{
                Success = $true
                AlertUsers = $alerts
                TotalFailures = $signInLogs.Count
                Period = $Days
                Threshold = $ThresholdCount
            }
        }
        catch {
            # E3ライセンスではサインインログ取得に制限があります
            if ($_.Exception.Message -like "*Authentication_RequestFromNonPremiumTenantOrB2CTenant*" -or $_.Exception.Message -like "*Forbidden*") {
                Write-Log "E3ライセンス制限: サインインログ取得はプレミアムライセンスが必要です。この機能は使用できません" -Level "Warning"
                
                return @{
                    Success = $false
                    AlertUsers = @()
                    TotalFailures = 0
                    Period = $Days
                    Threshold = $ThresholdCount
                    ErrorMessage = "E3ライセンスではサインインログ取得機能は利用できません"
                }
            }
            else {
                Write-Log "サインインログ取得エラー: $($_.Exception.Message)" -Level "Error"
                throw $_
            }
        }
        
    }
    catch {
        Write-Log "ログイン失敗アラート検出エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# MFA HTMLレポート生成関数
function Generate-MFAReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$MFAResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 高リスクユーザーを抽出
    $highRiskUsers = $MFAResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
    $mediumRiskUsers = $MFAResults | Where-Object { $_.RiskLevel -eq "中" } | Sort-Object DisplayName
    $mfaEnabledUsers = $MFAResults | Where-Object { $_.HasMFA -eq $true } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MFA設定状況分析レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .risk-high { color: #d13438; font-weight: bold; }
        .risk-medium { color: #ff8c00; font-weight: bold; }
        .risk-low { color: #107c10; }
        .mfa-enabled { color: #107c10; }
        .mfa-disabled { color: #d13438; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        .alert-info {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(4, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 MFA設定状況分析レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - $($Summary.LicenseEnvironment)</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value">$($Summary.TotalUsers)</div>
            <div class="description">全アカウント</div>
        </div>
        <div class="summary-card">
            <h3>MFA設定済み</h3>
            <div class="value success">$($Summary.MFAEnabledUsers)</div>
            <div class="description">セキュア</div>
        </div>
        <div class="summary-card">
            <h3>MFA未設定</h3>
            <div class="value danger">$($Summary.MFADisabledUsers)</div>
            <div class="description">要対応</div>
        </div>
        <div class="summary-card">
            <h3>高リスクユーザー</h3>
            <div class="value danger">$($Summary.HighRiskUsers)</div>
            <div class="description">緊急対応必要</div>
        </div>
    </div>
"@

    # サインイン制限の注意表示
    if (-not $Summary.SignInSupported) {
        $htmlTemplate += @"
    <div class="alert-info">
        <strong>注意:</strong> サインイン履歴情報は$($Summary.LicenseEnvironment)の制限により取得できません。
    </div>
"@
    }

    # 高リスクユーザー一覧
    if ($highRiskUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 高リスクユーザー (緊急対応必要)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>アカウント状態</th>
                            <th>MFA設定</th>
                            <th>ライセンス</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $highRiskUsers) {
            $accountStatus = if ($user.AccountEnabled) { "有効" } else { "無効" }
            $mfaStatus = if ($user.HasMFA) { "設定済み" } else { "未設定" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$accountStatus</td>
                            <td class="mfa-disabled">$mfaStatus</td>
                            <td>$($user.LicenseInfo)</td>
                            <td>$($user.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 中リスクユーザー一覧
    if ($mediumRiskUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 中リスクユーザー</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>アカウント状態</th>
                            <th>MFA設定</th>
                            <th>ライセンス</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $mediumRiskUsers) {
            $accountStatus = if ($user.AccountEnabled) { "有効" } else { "無効" }
            $mfaStatus = if ($user.HasMFA) { "設定済み" } else { "未設定" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$accountStatus</td>
                            <td class="risk-medium">$mfaStatus</td>
                            <td>$($user.LicenseInfo)</td>
                            <td>$($user.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # MFA設定済みユーザー一覧
    if ($mfaEnabledUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>✅ MFA設定済みユーザー</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>MFA方法</th>
                            <th>ライセンス</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $mfaEnabledUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td class="mfa-enabled">$($user.MFAMethods)</td>
                            <td>$($user.LicenseInfo)</td>
                            <td>$($user.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# UM-04: パスワード有効期限チェック
function Get-PasswordExpiryUsers {
    param(
        [Parameter(Mandatory = $false)]
        [int]$WarningDays = 30,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "パスワード有効期限チェックを開始します (警告日数: ${WarningDays}日)" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # パスワードポリシー設定（E3制限対応）
        Write-Log "パスワードポリシー設定を確認中..." -Level "Info"
        
        # E3ライセンスではポリシー詳細取得に制限があるため、標準値を使用
        $passwordValidityPeriod = 90
        
        try {
            # ドメイン情報の取得を試行（E3でも基本的なドメイン情報は取得可能）
            $domains = Get-MgDomain -ErrorAction SilentlyContinue
            if ($domains) {
                $defaultDomain = $domains | Where-Object { $_.IsDefault -eq $true } | Select-Object -First 1
                Write-Log "ドメイン情報取得完了: $($defaultDomain.Id)" -Level "Info"
            }
            
            # 組織ポリシーの取得を試行（E3では制限される可能性が高い）
            try {
                $orgSettings = Get-MgPolicyAuthorizationPolicy -ErrorAction Stop
                Write-Log "組織ポリシー取得成功" -Level "Info"
                # ポリシーから詳細情報を取得できた場合の処理（E3では通常到達しない）
            }
            catch {
                # E3ライセンスでは予想される制限
                if ($_.Exception.Message -like "*Authorization_RequestDenied*" -or 
                    $_.Exception.Message -like "*Insufficient privileges*" -or
                    $_.Exception.Message -like "*Forbidden*") {
                    Write-Log "E3ライセンス制限: 組織ポリシー詳細は取得できません（予想される動作）" -Level "Info"
                }
                else {
                    Write-Log "組織ポリシー取得エラー: $($_.Exception.Message)" -Level "Debug"
                }
            }
        }
        catch {
            Write-Log "ドメイン情報取得エラー: $($_.Exception.Message)" -Level "Debug"
        }
        
        # E3環境では標準値を使用して処理を継続
        Write-Log "Microsoft標準値を適用: パスワード有効期限 $passwordValidityPeriod 日" -Level "Info"
        
        # 全ユーザーの取得
        Write-Log "ユーザー一覧を取得中..." -Level "Info"
        
        try {
            # パスワード関連情報を含めて取得
            $allUsers = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,PasswordPolicies,PasswordProfile,LastPasswordChangeDateTime
            Write-Log "ユーザー情報取得完了 (詳細プロパティ付き)" -Level "Info"
        }
        catch {
            Write-Log "詳細プロパティ取得エラー。基本プロパティで再試行..." -Level "Warning"
            $allUsers = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime
        }
        
        Write-Log "取得完了: $($allUsers.Count)名のユーザー" -Level "Info"
        
        # パスワード有効期限分析
        $passwordResults = @()
        $progressCount = 0
        $warningDate = (Get-Date).AddDays($WarningDays)
        
        foreach ($user in $allUsers) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "パスワード有効期限確認中" -Status "$progressCount/$($allUsers.Count)" -PercentComplete (($progressCount / $allUsers.Count) * 100)
            }
            
            try {
                # パスワード変更日時の確認
                $lastPasswordChange = $null
                $passwordNeverExpires = $false
                $passwordExpiryDate = $null
                $daysUntilExpiry = $null
                $status = "不明"
                
                # パスワードポリシーの確認
                if ($user.PasswordPolicies) {
                    $passwordNeverExpires = $user.PasswordPolicies -contains "DisablePasswordExpiration"
                }
                
                # 最終パスワード変更日時の取得
                if ($user.LastPasswordChangeDateTime) {
                    $lastPasswordChange = $user.LastPasswordChangeDateTime
                }
                elseif ($user.CreatedDateTime) {
                    # 最終変更日時が不明の場合は作成日時を使用
                    $lastPasswordChange = $user.CreatedDateTime
                }
                
                if ($lastPasswordChange -and -not $passwordNeverExpires) {
                    $passwordExpiryDate = $lastPasswordChange.AddDays($passwordValidityPeriod)
                    $daysUntilExpiry = [math]::Round(($passwordExpiryDate - (Get-Date)).TotalDays)
                    
                    $status = if ($daysUntilExpiry -le 0) { "期限切れ" }
                             elseif ($daysUntilExpiry -le 7) { "緊急" }
                             elseif ($daysUntilExpiry -le $WarningDays) { "警告" }
                             else { "正常" }
                }
                elseif ($passwordNeverExpires) {
                    $status = "無期限"
                    $daysUntilExpiry = 999999
                }
                
                # ライセンス確認
                $hasLicense = $false
                $licenseInfo = "なし"
                
                try {
                    $userLicenses = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
                    if ($userLicenses -and $userLicenses.Count -gt 0) {
                        $hasLicense = $true
                        $licenseNames = @()
                        foreach ($license in $userLicenses) {
                            if ($license.SkuPartNumber) {
                                $licenseNames += $license.SkuPartNumber
                            }
                        }
                        $licenseInfo = if ($licenseNames.Count -gt 0) { $licenseNames -join ", " } else { "ライセンス詳細不明" }
                    }
                }
                catch {
                    $licenseInfo = "取得エラー"
                }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    LastPasswordChange = if ($lastPasswordChange) { $lastPasswordChange.ToString("yyyy/MM/dd HH:mm") } else { "不明" }
                    PasswordExpiryDate = if ($passwordExpiryDate) { $passwordExpiryDate.ToString("yyyy/MM/dd") } else { "該当なし" }
                    DaysUntilExpiry = $daysUntilExpiry
                    Status = $status
                    PasswordNeverExpires = $passwordNeverExpires
                    HasLicense = $hasLicense
                    LicenseInfo = $licenseInfo
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    UserId = $user.Id
                }
                
                $passwordResults += $result
                
            }
            catch {
                Write-Log "ユーザー $($user.UserPrincipalName) のパスワード確認エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    LastPasswordChange = "確認エラー"
                    PasswordExpiryDate = "確認エラー"
                    DaysUntilExpiry = $null
                    Status = "確認エラー"
                    PasswordNeverExpires = $false
                    HasLicense = $false
                    LicenseInfo = "確認エラー"
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    UserId = $user.Id
                }
                
                $passwordResults += $result
            }
        }
        
        Write-Progress -Activity "パスワード有効期限確認中" -Completed
        
        # 結果集計
        $totalUsers = $passwordResults.Count
        $expiredUsers = ($passwordResults | Where-Object { $_.Status -eq "期限切れ" }).Count
        $urgentUsers = ($passwordResults | Where-Object { $_.Status -eq "緊急" }).Count
        $warningUsers = ($passwordResults | Where-Object { $_.Status -eq "警告" }).Count
        $neverExpiresUsers = ($passwordResults | Where-Object { $_.PasswordNeverExpires -eq $true }).Count
        $normalUsers = ($passwordResults | Where-Object { $_.Status -eq "正常" }).Count
        
        Write-Log "パスワード有効期限確認完了" -Level "Info"
        Write-Log "総ユーザー数: $totalUsers" -Level "Info"
        Write-Log "期限切れ: $expiredUsers" -Level "Info"
        Write-Log "緊急対応: $urgentUsers" -Level "Info"
        Write-Log "警告対象: $warningUsers" -Level "Info"
        Write-Log "無期限設定: $neverExpiresUsers" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== パスワード有効期限警告一覧 ===`n" -ForegroundColor Yellow
            
            # 期限切れユーザー
            $expiredList = $passwordResults | Where-Object { $_.Status -eq "期限切れ" -and $_.AccountEnabled -eq $true } | Sort-Object DaysUntilExpiry
            if ($expiredList.Count -gt 0) {
                Write-Host "【期限切れ】" -ForegroundColor Red
                foreach ($user in $expiredList) {
                    Write-Host "  ● $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Red
                    Write-Host "    有効期限: $($user.PasswordExpiryDate) (期限切れから$([math]::Abs($user.DaysUntilExpiry))日経過)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 緊急対応ユーザー
            $urgentList = $passwordResults | Where-Object { $_.Status -eq "緊急" -and $_.AccountEnabled -eq $true } | Sort-Object DaysUntilExpiry
            if ($urgentList.Count -gt 0) {
                Write-Host "【緊急対応（7日以内）】" -ForegroundColor Red
                foreach ($user in $urgentList) {
                    Write-Host "  ⚠ $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Red
                    Write-Host "    有効期限: $($user.PasswordExpiryDate) (残り$($user.DaysUntilExpiry)日)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 警告対象ユーザー
            $warningList = $passwordResults | Where-Object { $_.Status -eq "警告" -and $_.AccountEnabled -eq $true } | Sort-Object DaysUntilExpiry
            if ($warningList.Count -gt 0) {
                Write-Host "【警告対象（$WarningDays 日以内）】" -ForegroundColor Yellow
                foreach ($user in $warningList) {
                    Write-Host "  ⚠ $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Yellow
                    Write-Host "    有効期限: $($user.PasswordExpiryDate) (残り$($user.DaysUntilExpiry)日)" -ForegroundColor Gray
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\PasswordExpiry_Analysis_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($passwordResults -and $passwordResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $passwordResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $passwordResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\PasswordExpiry_Analysis_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-PasswordExpiryReportHTML -PasswordResults $passwordResults -Summary @{
                TotalUsers = $totalUsers
                ExpiredUsers = $expiredUsers
                UrgentUsers = $urgentUsers
                WarningUsers = $warningUsers
                NeverExpiresUsers = $neverExpiresUsers
                NormalUsers = $normalUsers
                WarningDays = $WarningDays
                PasswordValidityPeriod = $passwordValidityPeriod
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalUsers = $totalUsers
            ExpiredUsers = $expiredUsers
            UrgentUsers = $urgentUsers
            WarningUsers = $warningUsers
            NeverExpiresUsers = $neverExpiresUsers
            NormalUsers = $normalUsers
            WarningDays = $WarningDays
            PasswordValidityPeriod = $passwordValidityPeriod
            DetailedResults = $passwordResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "パスワード有効期限チェックエラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# UM-05: ライセンス未割当者確認
function Get-UnlicensedUsers {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false,
        
        [Parameter(Mandatory = $false)]
        [int]$HTMLLimitPerSection = 0  # 0は無制限、数値を指定すると制限
    )
    
    Write-Log "ライセンス未割当者確認を開始します" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # 全ユーザーの取得
        Write-Log "ユーザー一覧を取得中..." -Level "Info"
        
        try {
            $allUsers = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,UsageLocation
            Write-Log "ユーザー情報取得完了" -Level "Info"
        }
        catch {
            Write-Log "ユーザー取得エラー: $($_.Exception.Message)" -Level "Error"
            $allUsers = Get-MgUser -All
        }
        
        Write-Log "取得完了: $($allUsers.Count)名のユーザー" -Level "Info"
        
        # ライセンス分析
        $licenseResults = @()
        $progressCount = 0
        
        foreach ($user in $allUsers) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "ライセンス状況確認中" -Status "$progressCount/$($allUsers.Count)" -PercentComplete (($progressCount / $allUsers.Count) * 100)
            }
            
            try {
                # ライセンス詳細確認
                $hasLicense = $false
                $licenseInfo = "なし"
                $licenseCount = 0
                $licenseDetails = @()
                
                try {
                    $userLicenses = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
                    if ($userLicenses -and $userLicenses.Count -gt 0) {
                        $hasLicense = $true
                        $licenseCount = $userLicenses.Count
                        
                        foreach ($license in $userLicenses) {
                            if ($license.SkuPartNumber) {
                                $licenseDetails += $license.SkuPartNumber
                            }
                        }
                        $licenseInfo = if ($licenseDetails.Count -gt 0) { $licenseDetails -join ", " } else { "ライセンス詳細不明" }
                    }
                }
                catch {
                    $licenseInfo = "取得エラー"
                }
                
                # リスクレベル判定
                $riskLevel = if (-not $hasLicense -and $user.AccountEnabled) { "高" }
                            elseif (-not $hasLicense -and -not $user.AccountEnabled) { "中" }
                            else { "低" }
                
                # 使用地域確認
                $usageLocation = if ($user.UsageLocation) { $user.UsageLocation } else { "未設定" }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    HasLicense = $hasLicense
                    LicenseCount = $licenseCount
                    LicenseInfo = $licenseInfo
                    UsageLocation = $usageLocation
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = $riskLevel
                    UserId = $user.Id
                }
                
                $licenseResults += $result
                
            }
            catch {
                Write-Log "ユーザー $($user.UserPrincipalName) のライセンス確認エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    HasLicense = $false
                    LicenseCount = 0
                    LicenseInfo = "確認エラー"
                    UsageLocation = "確認エラー"
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = "要確認"
                    UserId = $user.Id
                }
                
                $licenseResults += $result
            }
        }
        
        Write-Progress -Activity "ライセンス状況確認中" -Completed
        
        # 結果集計
        $totalUsers = $licenseResults.Count
        $licensedUsers = ($licenseResults | Where-Object { $_.HasLicense -eq $true }).Count
        $unlicensedUsers = $totalUsers - $licensedUsers
        $unlicensedActiveUsers = ($licenseResults | Where-Object { $_.HasLicense -eq $false -and $_.AccountEnabled -eq $true }).Count
        $highRiskUsers = ($licenseResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        $noUsageLocationUsers = ($licenseResults | Where-Object { $_.UsageLocation -eq "未設定" }).Count
        
        Write-Log "ライセンス確認完了" -Level "Info"
        Write-Log "総ユーザー数: $totalUsers" -Level "Info"
        Write-Log "ライセンス済み: $licensedUsers" -Level "Info"
        Write-Log "ライセンス未割当: $unlicensedUsers" -Level "Info"
        Write-Log "未割当アクティブユーザー: $unlicensedActiveUsers" -Level "Info"
        Write-Log "高リスクユーザー: $highRiskUsers" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== ライセンス未割当者一覧 ===`n" -ForegroundColor Yellow
            
            # 高リスクユーザー（アクティブ且つライセンス未割当）
            $highRiskList = $licenseResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($highRiskList.Count -gt 0) {
                Write-Host "【高リスク（アクティブ・ライセンス未割当）】" -ForegroundColor Red
                foreach ($user in $highRiskList) {
                    Write-Host "  ● $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Red
                    Write-Host "    使用地域: $($user.UsageLocation) | 作成日: $($user.CreatedDate)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 使用地域未設定ユーザー
            $noLocationList = $licenseResults | Where-Object { $_.UsageLocation -eq "未設定" -and $_.AccountEnabled -eq $true } | Sort-Object DisplayName
            if ($noLocationList.Count -gt 0) {
                Write-Host "【使用地域未設定】" -ForegroundColor Yellow
                foreach ($user in $noLocationList) {
                    Write-Host "  ⚠ $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Yellow
                    Write-Host "    ライセンス: $($user.LicenseInfo)" -ForegroundColor Gray
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\License_Analysis_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($licenseResults -and $licenseResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $licenseResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $licenseResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\License_Analysis_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-LicenseReportHTML -LicenseResults $licenseResults -Summary @{
                TotalUsers = $totalUsers
                LicensedUsers = $licensedUsers
                UnlicensedUsers = $unlicensedUsers
                UnlicensedActiveUsers = $unlicensedActiveUsers
                HighRiskUsers = $highRiskUsers
                NoUsageLocationUsers = $noUsageLocationUsers
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalUsers = $totalUsers
            LicensedUsers = $licensedUsers
            UnlicensedUsers = $unlicensedUsers
            UnlicensedActiveUsers = $unlicensedActiveUsers
            HighRiskUsers = $highRiskUsers
            NoUsageLocationUsers = $noUsageLocationUsers
            DetailedResults = $licenseResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "ライセンス未割当者確認エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# パスワード有効期限 HTMLレポート生成関数
function Generate-PasswordExpiryReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$PasswordResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 各カテゴリ別にユーザーを抽出
    $expiredUsers = $PasswordResults | Where-Object { $_.Status -eq "期限切れ" } | Sort-Object DaysUntilExpiry
    $urgentUsers = $PasswordResults | Where-Object { $_.Status -eq "緊急" } | Sort-Object DaysUntilExpiry
    $warningUsers = $PasswordResults | Where-Object { $_.Status -eq "警告" } | Sort-Object DaysUntilExpiry
    $neverExpiresUsers = $PasswordResults | Where-Object { $_.PasswordNeverExpires -eq $true } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>パスワード有効期限分析レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #d13438 0%, #ff6b6b 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .value.urgent { color: #dc3545; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .status-expired { color: #d13438; font-weight: bold; }
        .status-urgent { color: #dc3545; font-weight: bold; }
        .status-warning { color: #ff8c00; font-weight: bold; }
        .status-normal { color: #107c10; }
        .status-never { color: #6c757d; font-style: italic; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        .alert-info {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(6, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 パスワード有効期限分析レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - Microsoft 365 E3環境</div>
        <div class="subtitle">分析基準: パスワード有効期限90日（Microsoft標準値）</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value">$($Summary.TotalUsers)</div>
            <div class="description">全アカウント</div>
        </div>
        <div class="summary-card">
            <h3>期限切れ</h3>
            <div class="value danger">$($Summary.ExpiredUsers)</div>
            <div class="description">即時対応</div>
        </div>
        <div class="summary-card">
            <h3>緊急対応</h3>
            <div class="value urgent">$($Summary.UrgentUsers)</div>
            <div class="description">7日以内</div>
        </div>
        <div class="summary-card">
            <h3>警告対象</h3>
            <div class="value warning">$($Summary.WarningUsers)</div>
            <div class="description">${($Summary.WarningDays)}日以内</div>
        </div>
        <div class="summary-card">
            <h3>正常</h3>
            <div class="value success">$($Summary.NormalUsers)</div>
            <div class="description">期限内</div>
        </div>
        <div class="summary-card">
            <h3>無期限設定</h3>
            <div class="value">$($Summary.NeverExpiresUsers)</div>
            <div class="description">期限なし</div>
        </div>
    </div>

    <div class="alert-info">
        <strong>注意:</strong> Microsoft 365 E3ライセンスでは組織ポリシーの詳細取得に制限があります。
        このレポートは標準的な90日パスワード有効期限を基準として分析しています。
    </div>
"@

    # 期限切れユーザー一覧
    if ($expiredUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 期限切れユーザー (即時対応必要)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>最終変更日</th>
                            <th>有効期限</th>
                            <th>経過日数</th>
                            <th>ライセンス</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $expiredUsers) {
            $expiredDays = [math]::Abs($user.DaysUntilExpiry)
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$($user.LastPasswordChange)</td>
                            <td>$($user.PasswordExpiryDate)</td>
                            <td class="status-expired">${expiredDays}日経過</td>
                            <td>$($user.LicenseInfo)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 緊急対応ユーザー一覧
    if ($urgentUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 緊急対応ユーザー (7日以内)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>最終変更日</th>
                            <th>有効期限</th>
                            <th>残り日数</th>
                            <th>ライセンス</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $urgentUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$($user.LastPasswordChange)</td>
                            <td>$($user.PasswordExpiryDate)</td>
                            <td class="status-urgent">残り$($user.DaysUntilExpiry)日</td>
                            <td>$($user.LicenseInfo)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 警告対象ユーザー一覧
    if ($warningUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 警告対象ユーザー ($($Summary.WarningDays)日以内)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>最終変更日</th>
                            <th>有効期限</th>
                            <th>残り日数</th>
                            <th>ライセンス</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $warningUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$($user.LastPasswordChange)</td>
                            <td>$($user.PasswordExpiryDate)</td>
                            <td class="status-warning">残り$($user.DaysUntilExpiry)日</td>
                            <td>$($user.LicenseInfo)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# ライセンス HTMLレポート生成関数
function Generate-LicenseReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$LicenseResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 各カテゴリ別にユーザーを抽出
    $highRiskUsers = $LicenseResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
    $unlicensedUsers = $LicenseResults | Where-Object { $_.HasLicense -eq $false } | Sort-Object DisplayName
    $noLocationUsers = $LicenseResults | Where-Object { $_.UsageLocation -eq "未設定" -and $_.AccountEnabled -eq $true } | Sort-Object DisplayName
    $licensedUsers = $LicenseResults | Where-Object { $_.HasLicense -eq $true } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ライセンス分析レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .risk-high { color: #d13438; font-weight: bold; }
        .risk-medium { color: #ff8c00; font-weight: bold; }
        .risk-low { color: #107c10; }
        .licensed { color: #107c10; }
        .unlicensed { color: #d13438; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        .show-more-btn { 
            background: #0078d4; 
            color: white; 
            border: none; 
            padding: 10px 20px; 
            border-radius: 4px; 
            cursor: pointer; 
            margin: 10px 0; 
            display: none;
        }
        .show-more-btn:hover { background: #106ebe; }
        .large-table { max-height: 600px; overflow-y: auto; }
        .large-table.collapsed { max-height: 400px; }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(6, 1fr); }
            .large-table { max-height: none; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📋 ライセンス分析レポート</h1>
        <div class="subtitle">みらい建設工業株式会社</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value">$($Summary.TotalUsers)</div>
            <div class="description">全アカウント</div>
        </div>
        <div class="summary-card">
            <h3>ライセンス済み</h3>
            <div class="value success">$($Summary.LicensedUsers)</div>
            <div class="description">正常</div>
        </div>
        <div class="summary-card">
            <h3>ライセンス未割当</h3>
            <div class="value danger">$($Summary.UnlicensedUsers)</div>
            <div class="description">要確認</div>
        </div>
        <div class="summary-card">
            <h3>アクティブ未割当</h3>
            <div class="value danger">$($Summary.UnlicensedActiveUsers)</div>
            <div class="description">緊急対応</div>
        </div>
        <div class="summary-card">
            <h3>高リスクユーザー</h3>
            <div class="value danger">$($Summary.HighRiskUsers)</div>
            <div class="description">即時対応</div>
        </div>
        <div class="summary-card">
            <h3>使用地域未設定</h3>
            <div class="value warning">$($Summary.NoUsageLocationUsers)</div>
            <div class="description">設定要</div>
        </div>
    </div>
"@

    # 高リスクユーザー一覧
    if ($highRiskUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 高リスクユーザー (アクティブ・ライセンス未割当)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>アカウント状態</th>
                            <th>ライセンス状況</th>
                            <th>使用地域</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $highRiskUsers) {
            $accountStatus = if ($user.AccountEnabled) { "有効" } else { "無効" }
            $licenseStatus = if ($user.HasLicense) { "割当済み" } else { "未割当" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$accountStatus</td>
                            <td class="unlicensed">$licenseStatus</td>
                            <td>$($user.UsageLocation)</td>
                            <td>$($user.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 使用地域未設定ユーザー一覧
    if ($noLocationUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 使用地域未設定ユーザー</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>ライセンス情報</th>
                            <th>ライセンス数</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $noLocationUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$($user.LicenseInfo)</td>
                            <td>$($user.LicenseCount)</td>
                            <td>$($user.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # ライセンス割当済みユーザー一覧（全件）
    if ($licensedUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>✅ ライセンス割当済みユーザー (全$($licensedUsers.Count)件)</h2>
        </div>
        <div class="section-content">
            <p><strong>注意:</strong> 件数が多い場合、テーブルはスクロール表示されます。すべてのデータはCSVレポートで確認できます。</p>
            <div class="table-container large-table">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>ライセンス情報</th>
                            <th>ライセンス数</th>
                            <th>使用地域</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $licensedUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td class="licensed">$($user.LicenseInfo)</td>
                            <td>$($user.LicenseCount)</td>
                            <td>$($user.UsageLocation)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# UM-06: ユーザー属性変更履歴確認（E3対応）
function Get-UserAttributeChanges {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Days = 30,
        
        [Parameter(Mandatory = $false)]
        [string]$UserId = "",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "ユーザー属性変更履歴確認を開始します (過去${Days}日間)" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        Write-Log "E3ライセンス環境：利用可能な方法で属性変更履歴を分析します" -Level "Info"
        
        # 対象ユーザーの決定
        $targetUsers = @()
        
        if ([string]::IsNullOrEmpty($UserId)) {
            # 全ユーザーを対象（効率化のため最近作成されたユーザーを重点的に）
            Write-Log "全ユーザーの属性変更履歴を確認します" -Level "Info"
            $allUsers = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,CompanyName,Department,JobTitle,OfficeLocation,UsageLocation
            
            # 最近作成されたユーザーを優先的に分析
            $recentUsers = $allUsers | Where-Object { $_.CreatedDateTime -gt (Get-Date).AddDays(-$Days) }
            $existingUsers = $allUsers | Where-Object { $_.CreatedDateTime -le (Get-Date).AddDays(-$Days) } | Sort-Object CreatedDateTime -Descending | Select-Object -First 100
            
            $targetUsers = $recentUsers + $existingUsers
        }
        else {
            # 指定されたユーザーのみ
            Write-Log "指定されたユーザーの属性変更履歴を確認します: $UserId" -Level "Info"
            $user = Get-MgUser -UserId $UserId -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,CompanyName,Department,JobTitle,OfficeLocation,UsageLocation
            $targetUsers = @($user)
        }
        
        Write-Log "対象ユーザー数: $($targetUsers.Count)" -Level "Info"
        
        # 属性変更履歴分析結果
        $changeResults = @()
        $progressCount = 0
        
        foreach ($user in $targetUsers) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "ユーザー属性変更確認中" -Status "$progressCount/$($targetUsers.Count) - $($user.DisplayName)" -PercentComplete (($progressCount / $targetUsers.Count) * 100)
            }
            
            try {
                # E3制限対応：利用可能な情報での変更検出アプローチ
                
                # 1. 最近の作成・変更日時による分析
                $recentlyCreated = $user.CreatedDateTime -gt (Get-Date).AddDays(-$Days)
                $suspiciousActivity = $false
                $changeIndicators = @()
                
                # 2. 属性の一貫性チェック（間接的な変更検出）
                $inconsistencies = @()
                
                # 会社名とドメインの一貫性
                if ($user.CompanyName -and $user.UserPrincipalName) {
                    $domain = ($user.UserPrincipalName -split "@")[1]
                    if ($user.CompanyName -notlike "*$domain*" -and $domain -notlike "*$($user.CompanyName)*") {
                        $inconsistencies += "会社名とメールドメインの不一致"
                    }
                }
                
                # 部署と役職の論理的一貫性
                if ($user.Department -and $user.JobTitle) {
                    $commonDeptTitles = @{
                        "IT" = @("エンジニア", "開発", "システム", "ネットワーク")
                        "営業" = @("営業", "Sales", "セールス")
                        "人事" = @("人事", "HR", "採用")
                        "経理" = @("経理", "会計", "財務")
                    }
                    
                    $deptFound = $false
                    foreach ($dept in $commonDeptTitles.Keys) {
                        if ($user.Department -like "*$dept*") {
                            $expectedTitles = $commonDeptTitles[$dept]
                            $titleMatch = $false
                            foreach ($title in $expectedTitles) {
                                if ($user.JobTitle -like "*$title*") {
                                    $titleMatch = $true
                                    break
                                }
                            }
                            if (-not $titleMatch) {
                                $inconsistencies += "部署と役職の不一致の可能性"
                            }
                            $deptFound = $true
                            break
                        }
                    }
                }
                
                # 使用地域の設定状況
                if (-not $user.UsageLocation) {
                    $inconsistencies += "使用地域未設定"
                }
                
                # 3. ライセンス変更の兆候
                $licenseChanges = @()
                try {
                    $currentLicenses = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
                    if ($currentLicenses) {
                        foreach ($license in $currentLicenses) {
                            # ライセンス付与日時が取得できる場合（制限あり）
                            if ($license.ServicePlans) {
                                $licenseChanges += "ライセンス: $($license.SkuPartNumber)"
                            }
                        }
                    }
                }
                catch {
                    Write-Log "ユーザー $($user.UserPrincipalName) のライセンス情報取得エラー" -Level "Debug"
                }
                
                # 4. グループメンバーシップ変更の可能性
                $groupMemberships = @()
                try {
                    $memberOf = Get-MgUserMemberOf -UserId $user.Id -ErrorAction SilentlyContinue | Select-Object -First 20
                    if ($memberOf) {
                        foreach ($group in $memberOf) {
                            $groupMemberships += $group.DisplayName
                        }
                    }
                }
                catch {
                    Write-Log "ユーザー $($user.UserPrincipalName) のグループメンバーシップ取得エラー" -Level "Debug"
                }
                
                # 5. 変更リスクレベルの判定
                $riskLevel = "低"
                $riskReasons = @()
                
                if ($recentlyCreated) {
                    $riskLevel = "中"
                    $riskReasons += "最近作成されたアカウント"
                }
                
                if ($inconsistencies.Count -gt 1) {
                    $riskLevel = "中"
                    $riskReasons += "複数の属性不一致"
                }
                
                if (-not $user.AccountEnabled) {
                    $riskLevel = "高"
                    $riskReasons += "無効化されたアカウント"
                }
                
                if ($groupMemberships.Count -gt 10) {
                    $riskLevel = "中"
                    $riskReasons += "多数のグループメンバーシップ"
                }
                
                # 6. 最終サインイン情報（取得可能な場合）
                $lastSignIn = "E3制限"
                try {
                    # サインイン情報の取得を試行（制限される可能性が高い）
                    if ($user.SignInActivity -and $user.SignInActivity.LastSignInDateTime) {
                        $lastSignIn = $user.SignInActivity.LastSignInDateTime.ToString("yyyy/MM/dd HH:mm")
                    }
                }
                catch {
                    # E3制限で取得できない場合
                }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd HH:mm")
                    RecentlyCreated = $recentlyCreated
                    Department = if ($user.Department) { $user.Department } else { "未設定" }
                    JobTitle = if ($user.JobTitle) { $user.JobTitle } else { "未設定" }
                    CompanyName = if ($user.CompanyName) { $user.CompanyName } else { "未設定" }
                    OfficeLocation = if ($user.OfficeLocation) { $user.OfficeLocation } else { "未設定" }
                    UsageLocation = if ($user.UsageLocation) { $user.UsageLocation } else { "未設定" }
                    LicenseInfo = if ($licenseChanges.Count -gt 0) { $licenseChanges -join ", " } else { "取得制限" }
                    GroupCount = $groupMemberships.Count
                    GroupMemberships = if ($groupMemberships.Count -gt 0) { ($groupMemberships | Select-Object -First 5) -join ", " } else { "なし" }
                    Inconsistencies = if ($inconsistencies.Count -gt 0) { $inconsistencies -join ", " } else { "なし" }
                    RiskLevel = $riskLevel
                    RiskReasons = if ($riskReasons.Count -gt 0) { $riskReasons -join ", " } else { "なし" }
                    LastSignIn = $lastSignIn
                    AnalysisMethod = "E3互換性分析"
                    UserId = $user.Id
                }
                
                $changeResults += $result
                
            }
            catch {
                Write-Log "ユーザー $($user.UserPrincipalName) の属性分析エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd HH:mm")
                    RecentlyCreated = $false
                    Department = "確認エラー"
                    JobTitle = "確認エラー"
                    CompanyName = "確認エラー"
                    OfficeLocation = "確認エラー"
                    UsageLocation = "確認エラー"
                    LicenseInfo = "確認エラー"
                    GroupCount = 0
                    GroupMemberships = "確認エラー"
                    Inconsistencies = "確認エラー"
                    RiskLevel = "要確認"
                    RiskReasons = "分析エラー"
                    LastSignIn = "確認エラー"
                    AnalysisMethod = "エラー"
                    UserId = $user.Id
                }
                
                $changeResults += $result
            }
        }
        
        Write-Progress -Activity "ユーザー属性変更確認中" -Completed
        
        # 結果集計
        $totalUsers = $changeResults.Count
        $recentlyCreatedUsers = ($changeResults | Where-Object { $_.RecentlyCreated -eq $true }).Count
        $highRiskUsers = ($changeResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        $mediumRiskUsers = ($changeResults | Where-Object { $_.RiskLevel -eq "中" }).Count
        $inconsistentUsers = ($changeResults | Where-Object { $_.Inconsistencies -ne "なし" }).Count
        $disabledUsers = ($changeResults | Where-Object { $_.AccountEnabled -eq $false }).Count
        
        Write-Log "ユーザー属性変更履歴確認完了（E3互換性分析）" -Level "Info"
        Write-Log "総ユーザー数: $totalUsers" -Level "Info"
        Write-Log "最近作成: $recentlyCreatedUsers" -Level "Info"
        Write-Log "高リスクユーザー: $highRiskUsers" -Level "Info"
        Write-Log "中リスクユーザー: $mediumRiskUsers" -Level "Info"
        Write-Log "属性不一致ユーザー: $inconsistentUsers" -Level "Info"
        Write-Log "無効ユーザー: $disabledUsers" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== ユーザー属性変更履歴分析結果 ===" -ForegroundColor Yellow
            Write-Host "※ E3ライセンス制限により、属性不一致検出と間接的分析を実行" -ForegroundColor Cyan
            
            # 高リスクユーザー
            $highRiskList = $changeResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($highRiskList.Count -gt 0) {
                Write-Host "`n【高リスクユーザー】" -ForegroundColor Red
                foreach ($user in $highRiskList) {
                    Write-Host "  ● $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Red
                    Write-Host "    リスク要因: $($user.RiskReasons)" -ForegroundColor Gray
                    Write-Host "    作成日: $($user.CreatedDate)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 最近作成されたユーザー
            $recentList = $changeResults | Where-Object { $_.RecentlyCreated -eq $true } | Sort-Object CreatedDate -Descending
            if ($recentList.Count -gt 0) {
                Write-Host "【最近作成されたユーザー（$Days日以内）】" -ForegroundColor Yellow
                foreach ($user in $recentList) {
                    Write-Host "  ⚠ $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Yellow
                    Write-Host "    作成日: $($user.CreatedDate) | 部署: $($user.Department)" -ForegroundColor Gray
                }
            }
            
            # 属性不一致ユーザー
            $inconsistentList = $changeResults | Where-Object { $_.Inconsistencies -ne "なし" } | Sort-Object DisplayName
            if ($inconsistentList.Count -gt 0) {
                Write-Host "`n【属性不一致検出】" -ForegroundColor Yellow
                foreach ($user in $inconsistentList) {
                    Write-Host "  ⚠ $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Yellow
                    Write-Host "    不一致: $($user.Inconsistencies)" -ForegroundColor Gray
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\UserAttribute_Changes_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($changeResults -and $changeResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $changeResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $changeResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\UserAttribute_Changes_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-UserAttributeChangesReportHTML -ChangeResults $changeResults -Summary @{
                TotalUsers = $totalUsers
                RecentlyCreatedUsers = $recentlyCreatedUsers
                HighRiskUsers = $highRiskUsers
                MediumRiskUsers = $mediumRiskUsers
                InconsistentUsers = $inconsistentUsers
                DisabledUsers = $disabledUsers
                AnalysisDays = $Days
                AnalysisMethod = "E3互換性分析（属性不一致検出）"
                LicenseEnvironment = "Microsoft 365 E3"
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalUsers = $totalUsers
            RecentlyCreatedUsers = $recentlyCreatedUsers
            HighRiskUsers = $highRiskUsers
            MediumRiskUsers = $mediumRiskUsers
            InconsistentUsers = $inconsistentUsers
            DisabledUsers = $disabledUsers
            AnalysisDays = $Days
            AnalysisMethod = "E3互換性分析"
            LicenseEnvironment = "Microsoft 365 E3"
            DetailedResults = $changeResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "ユーザー属性変更履歴確認エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# ユーザー属性変更 HTMLレポート生成関数
function Generate-UserAttributeChangesReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$ChangeResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 各カテゴリ別にユーザーを抽出
    $highRiskUsers = $ChangeResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
    $recentUsers = $ChangeResults | Where-Object { $_.RecentlyCreated -eq $true } | Sort-Object CreatedDate -Descending
    $inconsistentUsers = $ChangeResults | Where-Object { $_.Inconsistencies -ne "なし" } | Sort-Object DisplayName
    $disabledUsers = $ChangeResults | Where-Object { $_.AccountEnabled -eq $false } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ユーザー属性変更履歴分析レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .risk-high { color: #d13438; font-weight: bold; }
        .risk-medium { color: #ff8c00; font-weight: bold; }
        .risk-low { color: #107c10; }
        .user-recent { color: #ff8c00; font-weight: bold; }
        .user-disabled { color: #d13438; }
        .alert-info {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(6, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>👤 ユーザー属性変更履歴分析レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - $($Summary.LicenseEnvironment)</div>
        <div class="subtitle">分析方法: $($Summary.AnalysisMethod)</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="alert-info">
        <strong>E3ライセンス対応:</strong> このレポートは $($Summary.LicenseEnvironment) の制限に対応した間接的分析手法を使用しています。
        属性の不一致パターンと最近の変更から潜在的な変更を検出します。
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value">$($Summary.TotalUsers)</div>
            <div class="description">分析対象</div>
        </div>
        <div class="summary-card">
            <h3>最近作成</h3>
            <div class="value warning">$($Summary.RecentlyCreatedUsers)</div>
            <div class="description">${($Summary.AnalysisDays)}日以内</div>
        </div>
        <div class="summary-card">
            <h3>高リスクユーザー</h3>
            <div class="value danger">$($Summary.HighRiskUsers)</div>
            <div class="description">緊急確認</div>
        </div>
        <div class="summary-card">
            <h3>中リスクユーザー</h3>
            <div class="value warning">$($Summary.MediumRiskUsers)</div>
            <div class="description">要注意</div>
        </div>
        <div class="summary-card">
            <h3>属性不一致</h3>
            <div class="value warning">$($Summary.InconsistentUsers)</div>
            <div class="description">検証推奨</div>
        </div>
        <div class="summary-card">
            <h3>無効ユーザー</h3>
            <div class="value danger">$($Summary.DisabledUsers)</div>
            <div class="description">要確認</div>
        </div>
    </div>
"@

    # 高リスクユーザー一覧
    if ($highRiskUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 高リスクユーザー (緊急確認必要)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>アカウント状態</th>
                            <th>作成日</th>
                            <th>部署</th>
                            <th>リスク要因</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $highRiskUsers) {
            $accountStatus = if ($user.AccountEnabled) { "有効" } else { "無効" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td class="user-disabled">$accountStatus</td>
                            <td>$($user.CreatedDate)</td>
                            <td>$($user.Department)</td>
                            <td class="risk-high">$($user.RiskReasons)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 最近作成されたユーザー一覧
    if ($recentUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>📅 最近作成されたユーザー ($($Summary.AnalysisDays)日以内)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>作成日</th>
                            <th>部署</th>
                            <th>役職</th>
                            <th>会社名</th>
                            <th>使用地域</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $recentUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td class="user-recent">$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$($user.CreatedDate)</td>
                            <td>$($user.Department)</td>
                            <td>$($user.JobTitle)</td>
                            <td>$($user.CompanyName)</td>
                            <td>$($user.UsageLocation)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 属性不一致ユーザー一覧
    if ($inconsistentUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 属性不一致検出ユーザー</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>部署</th>
                            <th>役職</th>
                            <th>会社名</th>
                            <th>検出された不一致</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $inconsistentUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$($user.Department)</td>
                            <td>$($user.JobTitle)</td>
                            <td>$($user.CompanyName)</td>
                            <td class="risk-medium">$($user.Inconsistencies)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# UM-07: Microsoft 365ライセンス付与の有無確認（E3対応）
function Get-Microsoft365LicenseStatus {
    param(
        [Parameter(Mandatory = $false)]
        [string]$UserId = "",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeServicePlan = $false
    )
    
    Write-Log "Microsoft 365ライセンス付与確認を開始します" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # 組織のライセンス情報を取得
        Write-Log "組織のライセンス情報を取得中..." -Level "Info"
        
        $subscriptions = @()
        try {
            $orgSubscriptions = Get-MgSubscribedSku -All
            foreach ($sub in $orgSubscriptions) {
                $subscription = [PSCustomObject]@{
                    SkuId = $sub.SkuId
                    SkuPartNumber = $sub.SkuPartNumber
                    DisplayName = Get-LicenseDisplayName -SkuPartNumber $sub.SkuPartNumber
                    TotalLicenses = $sub.PrepaidUnits.Enabled
                    ConsumedLicenses = $sub.ConsumedUnits
                    AvailableLicenses = $sub.PrepaidUnits.Enabled - $sub.ConsumedUnits
                    UtilizationRate = if ($sub.PrepaidUnits.Enabled -gt 0) { 
                        [math]::Round(($sub.ConsumedUnits / $sub.PrepaidUnits.Enabled) * 100, 2) 
                    } else { 0 }
                    ServicePlans = $sub.ServicePlans.Count
                    AppliesTo = $sub.AppliesTo
                    CapabilityStatus = $sub.CapabilityStatus
                }
                $subscriptions += $subscription
            }
            Write-Log "組織ライセンス情報取得完了: $($subscriptions.Count)種類" -Level "Info"
        }
        catch {
            Write-Log "組織ライセンス情報取得エラー: $($_.Exception.Message)" -Level "Warning"
        }
        
        # 対象ユーザーの決定
        $targetUsers = @()
        
        if ([string]::IsNullOrEmpty($UserId)) {
            # 全ユーザーを対象
            Write-Log "全ユーザーのライセンス状況を確認します" -Level "Info"
            $targetUsers = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,UsageLocation,UserType
        }
        else {
            # 指定されたユーザーのみ
            Write-Log "指定されたユーザーのライセンス状況を確認します: $UserId" -Level "Info"
            $user = Get-MgUser -UserId $UserId -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,UsageLocation,UserType
            $targetUsers = @($user)
        }
        
        Write-Log "対象ユーザー数: $($targetUsers.Count)" -Level "Info"
        
        # ライセンス状況分析結果
        $licenseResults = @()
        $progressCount = 0
        
        foreach ($user in $targetUsers) {
            $progressCount++
            if ($progressCount % 20 -eq 0) {
                Write-Progress -Activity "ライセンス状況確認中" -Status "$progressCount/$($targetUsers.Count) - $($user.DisplayName)" -PercentComplete (($progressCount / $targetUsers.Count) * 100)
            }
            
            try {
                # ユーザーのライセンス詳細を取得
                $userLicenses = @()
                $totalLicenseValue = 0
                $microsoft365License = $false
                $exchangeOnline = $false
                $sharePointOnline = $false
                $teamsLicense = $false
                $officeApps = $false
                
                try {
                    $licenseDetails = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
                    
                    if ($licenseDetails) {
                        foreach ($license in $licenseDetails) {
                            $licenseDisplayName = Get-LicenseDisplayName -SkuPartNumber $license.SkuPartNumber
                            
                            # ライセンスタイプの分類
                            $licenseType = Get-LicenseCategory -SkuPartNumber $license.SkuPartNumber
                            $licenseValue = Get-LicenseValue -SkuPartNumber $license.SkuPartNumber
                            $totalLicenseValue += $licenseValue
                            
                            # Microsoft 365関連ライセンスの判定
                            if ($license.SkuPartNumber -like "*O365*" -or $license.SkuPartNumber -like "*M365*" -or 
                                $license.SkuPartNumber -eq "ENTERPRISEPACK" -or $license.SkuPartNumber -eq "ENTERPRISEPREMIUM") {
                                $microsoft365License = $true
                            }
                            
                            # サービス別ライセンスの確認
                            if ($license.ServicePlans) {
                                foreach ($servicePlan in $license.ServicePlans) {
                                    switch -Wildcard ($servicePlan.ServicePlanName) {
                                        "*EXCHANGE*" { $exchangeOnline = $true }
                                        "*SHAREPOINT*" { $sharePointOnline = $true }
                                        "*TEAMS*" { $teamsLicense = $true }
                                        "*OFFICESUBSCRIPTION*" { $officeApps = $true }
                                    }
                                }
                            }
                            
                            $userLicense = [PSCustomObject]@{
                                SkuPartNumber = $license.SkuPartNumber
                                DisplayName = $licenseDisplayName
                                LicenseType = $licenseType
                                EstimatedValue = $licenseValue
                                ServicePlanCount = $license.ServicePlans.Count
                                AssignedDateTime = if ($license.AssignedDateTime) { 
                                    $license.AssignedDateTime.ToString("yyyy/MM/dd HH:mm") 
                                } else { "不明" }
                            }
                            $userLicenses += $userLicense
                        }
                    }
                }
                catch {
                    Write-Log "ユーザー $($user.UserPrincipalName) のライセンス取得エラー: $($_.Exception.Message)" -Level "Debug"
                }
                
                # ライセンス状況の評価
                $licenseStatus = "ライセンス未割当"
                $riskLevel = "高"
                $recommendations = @()
                
                if ($userLicenses.Count -gt 0) {
                    if ($microsoft365License) {
                        $licenseStatus = "Microsoft 365ライセンス済み"
                        $riskLevel = "低"
                    }
                    elseif ($exchangeOnline -or $sharePointOnline -or $teamsLicense) {
                        $licenseStatus = "部分的ライセンス"
                        $riskLevel = "中"
                        $recommendations += "包括的なMicrosoft 365ライセンスを検討"
                    }
                    else {
                        $licenseStatus = "その他ライセンス"
                        $riskLevel = "中"
                    }
                }
                else {
                    if ($user.AccountEnabled) {
                        $recommendations += "Microsoft 365ライセンスの割り当てが必要"
                        $riskLevel = "高"
                    }
                    else {
                        $riskLevel = "低"
                        $recommendations += "無効ユーザーのためライセンス不要"
                    }
                }
                
                # 使用地域チェック
                if (-not $user.UsageLocation -and $userLicenses.Count -gt 0) {
                    $recommendations += "使用地域の設定が必要"
                    if ($riskLevel -eq "低") { $riskLevel = "中" }
                }
                
                # コスト効率チェック
                if ($totalLicenseValue -gt 2000 -and -not $microsoft365License) {
                    $recommendations += "ライセンス統合によるコスト最適化を検討"
                }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    UserType = $user.UserType
                    LicenseStatus = $licenseStatus
                    LicenseCount = $userLicenses.Count
                    Microsoft365License = $microsoft365License
                    ExchangeOnline = $exchangeOnline
                    SharePointOnline = $sharePointOnline
                    TeamsLicense = $teamsLicense
                    OfficeApps = $officeApps
                    TotalLicenseValue = $totalLicenseValue
                    UsageLocation = if ($user.UsageLocation) { $user.UsageLocation } else { "未設定" }
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = $riskLevel
                    Recommendations = if ($recommendations.Count -gt 0) { $recommendations -join "; " } else { "なし" }
                    LicenseDetails = if ($IncludeServicePlan) { 
                        ($userLicenses | ForEach-Object { "$($_.DisplayName) (¥$($_.EstimatedValue))" }) -join ", " 
                    } else { 
                        ($userLicenses | ForEach-Object { $_.DisplayName }) -join ", " 
                    }
                    UserId = $user.Id
                }
                
                $licenseResults += $result
                
            }
            catch {
                Write-Log "ユーザー $($user.UserPrincipalName) のライセンス分析エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled = $user.AccountEnabled
                    UserType = $user.UserType
                    LicenseStatus = "確認エラー"
                    LicenseCount = 0
                    Microsoft365License = $false
                    ExchangeOnline = $false
                    SharePointOnline = $false
                    TeamsLicense = $false
                    OfficeApps = $false
                    TotalLicenseValue = 0
                    UsageLocation = "確認エラー"
                    CreatedDate = $user.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = "要確認"
                    Recommendations = "ライセンス状況の手動確認が必要"
                    LicenseDetails = "確認エラー"
                    UserId = $user.Id
                }
                
                $licenseResults += $result
            }
        }
        
        Write-Progress -Activity "ライセンス状況確認中" -Completed
        
        # 結果集計
        $totalUsers = $licenseResults.Count
        $licensedUsers = ($licenseResults | Where-Object { $_.LicenseCount -gt 0 }).Count
        $unlicensedUsers = $totalUsers - $licensedUsers
        $microsoft365Users = ($licenseResults | Where-Object { $_.Microsoft365License -eq $true }).Count
        $partialLicenseUsers = ($licenseResults | Where-Object { $_.LicenseStatus -eq "部分的ライセンス" }).Count
        $highRiskUsers = ($licenseResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        $noUsageLocationUsers = ($licenseResults | Where-Object { $_.UsageLocation -eq "未設定" -and $_.LicenseCount -gt 0 }).Count
        
        # コスト分析
        $totalLicenseCost = ($licenseResults | Measure-Object -Property TotalLicenseValue -Sum).Sum
        $avgLicenseCostPerUser = if ($licensedUsers -gt 0) { 
            [math]::Round($totalLicenseCost / $licensedUsers, 0) 
        } else { 0 }
        
        Write-Log "Microsoft 365ライセンス分析完了" -Level "Info"
        Write-Log "総ユーザー数: $totalUsers" -Level "Info"
        Write-Log "ライセンス済み: $licensedUsers" -Level "Info"
        Write-Log "ライセンス未割当: $unlicensedUsers" -Level "Info"
        Write-Log "Microsoft 365ライセンス: $microsoft365Users" -Level "Info"
        Write-Log "部分的ライセンス: $partialLicenseUsers" -Level "Info"
        Write-Log "高リスクユーザー: $highRiskUsers" -Level "Info"
        Write-Log "推定総コスト: ¥$totalLicenseCost/月" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== Microsoft 365ライセンス分析結果 ===" -ForegroundColor Yellow
            
            # 組織ライセンス概要
            if ($subscriptions.Count -gt 0) {
                Write-Host "`n【組織ライセンス概要】" -ForegroundColor Cyan
                foreach ($sub in $subscriptions | Sort-Object ConsumedUnits -Descending) {
                    Write-Host "  📋 $($sub.DisplayName)" -ForegroundColor Cyan
                    Write-Host "    総数: $($sub.TotalLicenses) | 使用中: $($sub.ConsumedUnits) | 利用率: $($sub.UtilizationRate)%" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 高リスクユーザー（ライセンス未割当のアクティブユーザー）
            $highRiskList = $licenseResults | Where-Object { $_.RiskLevel -eq "高" -and $_.AccountEnabled -eq $true } | Sort-Object DisplayName
            if ($highRiskList.Count -gt 0) {
                Write-Host "【高リスクユーザー（アクティブ・ライセンス未割当）】" -ForegroundColor Red
                foreach ($user in $highRiskList) {
                    Write-Host "  ● $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Red
                    Write-Host "    推奨: $($user.Recommendations)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 部分的ライセンスユーザー
            $partialList = $licenseResults | Where-Object { $_.LicenseStatus -eq "部分的ライセンス" } | Sort-Object DisplayName
            if ($partialList.Count -gt 0) {
                Write-Host "【部分的ライセンスユーザー】" -ForegroundColor Yellow
                foreach ($user in $partialList) {
                    Write-Host "  ⚠ $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Yellow
                    Write-Host "    現在: $($user.LicenseDetails)" -ForegroundColor Gray
                    Write-Host "    推奨: $($user.Recommendations)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 使用地域未設定ユーザー
            if ($noUsageLocationUsers -gt 0) {
                $noLocationList = $licenseResults | Where-Object { $_.UsageLocation -eq "未設定" -and $_.LicenseCount -gt 0 } | Select-Object -First 10
                Write-Host "【使用地域未設定ユーザー（上位10件）】" -ForegroundColor Yellow
                foreach ($user in $noLocationList) {
                    Write-Host "  ⚠ $($user.DisplayName) - ライセンス: $($user.LicenseCount)個" -ForegroundColor Yellow
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\M365_License_Status_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($licenseResults -and $licenseResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $licenseResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $licenseResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\M365_License_Status_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-Microsoft365LicenseReportHTML -LicenseResults $licenseResults -Subscriptions $subscriptions -Summary @{
                TotalUsers = $totalUsers
                LicensedUsers = $licensedUsers
                UnlicensedUsers = $unlicensedUsers
                Microsoft365Users = $microsoft365Users
                PartialLicenseUsers = $partialLicenseUsers
                HighRiskUsers = $highRiskUsers
                NoUsageLocationUsers = $noUsageLocationUsers
                TotalLicenseCost = $totalLicenseCost
                AvgLicenseCostPerUser = $avgLicenseCostPerUser
                LicenseEnvironment = "Microsoft 365 E3"
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalUsers = $totalUsers
            LicensedUsers = $licensedUsers
            UnlicensedUsers = $unlicensedUsers
            Microsoft365Users = $microsoft365Users
            PartialLicenseUsers = $partialLicenseUsers
            HighRiskUsers = $highRiskUsers
            NoUsageLocationUsers = $noUsageLocationUsers
            TotalLicenseCost = $totalLicenseCost
            AvgLicenseCostPerUser = $avgLicenseCostPerUser
            LicenseEnvironment = "Microsoft 365 E3"
            DetailedResults = $licenseResults
            Subscriptions = $subscriptions
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "Microsoft 365ライセンス分析エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# ライセンス表示名を取得する関数
function Get-LicenseDisplayName {
    param([string]$SkuPartNumber)
    
    $licenseNames = @{
        "ENTERPRISEPACK" = "Microsoft 365 E3"
        "ENTERPRISEPREMIUM" = "Microsoft 365 E5"
        "MICROSOFT_BUSINESS_PREMIUM" = "Microsoft 365 Business Premium"
        "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "O365_BUSINESS_PREMIUM" = "Microsoft 365 Business Standard"
        "EXCHANGESTANDARD" = "Exchange Online Plan 1"
        "EXCHANGEENTERPRISE" = "Exchange Online Plan 2"
        "SHAREPOINTSTANDARD" = "SharePoint Online Plan 1"
        "SHAREPOINTENTERPRISE" = "SharePoint Online Plan 2"
        "MCOSTANDARD" = "Microsoft Teams"
        "OFFICESUBSCRIPTION" = "Microsoft 365 Apps for Enterprise"
        "POWER_BI_STANDARD" = "Power BI"
        "FLOW_FREE" = "Power Automate"
        "POWERAPPS_VIRAL" = "Power Apps"
        "PROJECTONLINE_PLAN_1" = "Project Online Plan 1"
        "VISIOONLINE_PLAN1" = "Visio Online Plan 1"
        "WIN10_PRO_ENT_SUB" = "Windows 10 Enterprise"
        "EMSPREMIUM" = "Enterprise Mobility + Security E5"
        "EMS" = "Enterprise Mobility + Security E3"
        "RIGHTSMANAGEMENT" = "Azure Rights Management"
        "AAD_PREMIUM" = "Azure Active Directory Premium P1"
        "AAD_PREMIUM_P2" = "Azure Active Directory Premium P2"
    }
    
    if ($licenseNames.ContainsKey($SkuPartNumber)) {
        return $licenseNames[$SkuPartNumber]
    }
    else {
        return $SkuPartNumber
    }
}

# ライセンスカテゴリを取得する関数
function Get-LicenseCategory {
    param([string]$SkuPartNumber)
    
    if ($SkuPartNumber -like "*ENTERPRISE*" -or $SkuPartNumber -like "*M365*") {
        return "Microsoft 365 Enterprise"
    }
    elseif ($SkuPartNumber -like "*BUSINESS*") {
        return "Microsoft 365 Business"
    }
    elseif ($SkuPartNumber -like "*EXCHANGE*") {
        return "Exchange Online"
    }
    elseif ($SkuPartNumber -like "*SHAREPOINT*") {
        return "SharePoint Online"
    }
    elseif ($SkuPartNumber -like "*TEAMS*" -or $SkuPartNumber -eq "MCOSTANDARD") {
        return "Microsoft Teams"
    }
    elseif ($SkuPartNumber -like "*OFFICE*") {
        return "Office Apps"
    }
    elseif ($SkuPartNumber -like "*POWER*") {
        return "Power Platform"
    }
    elseif ($SkuPartNumber -like "*EMS*" -or $SkuPartNumber -like "*AAD*") {
        return "Security & Identity"
    }
    else {
        return "その他"
    }
}

# ライセンス推定価格を取得する関数（円/月）
function Get-LicenseValue {
    param([string]$SkuPartNumber)
    
    $licenseValues = @{
        "ENTERPRISEPACK" = 2180      # Microsoft 365 E3
        "ENTERPRISEPREMIUM" = 4310   # Microsoft 365 E5
        "MICROSOFT_BUSINESS_PREMIUM" = 2390  # Business Premium
        "O365_BUSINESS_ESSENTIALS" = 540     # Business Basic
        "O365_BUSINESS_PREMIUM" = 1360       # Business Standard
        "EXCHANGESTANDARD" = 430             # Exchange Online Plan 1
        "EXCHANGEENTERPRISE" = 860           # Exchange Online Plan 2
        "SHAREPOINTSTANDARD" = 540           # SharePoint Online Plan 1
        "SHAREPOINTENTERPRISE" = 1080        # SharePoint Online Plan 2
        "MCOSTANDARD" = 430                  # Microsoft Teams
        "OFFICESUBSCRIPTION" = 1290          # Microsoft 365 Apps
        "POWER_BI_STANDARD" = 1080           # Power BI
        "EMSPREMIUM" = 1180                  # EMS E5
        "EMS" = 750                          # EMS E3
        "AAD_PREMIUM" = 650                  # Azure AD Premium P1
        "AAD_PREMIUM_P2" = 980               # Azure AD Premium P2
    }
    
    if ($licenseValues.ContainsKey($SkuPartNumber)) {
        return $licenseValues[$SkuPartNumber]
    }
    else {
        return 500  # 推定値
    }
}

# Microsoft 365ライセンス HTMLレポート生成関数
function Generate-Microsoft365LicenseReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$LicenseResults,
        
        [Parameter(Mandatory = $true)]
        [array]$Subscriptions,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 各カテゴリ別にユーザーを抽出
    $highRiskUsers = $LicenseResults | Where-Object { $_.RiskLevel -eq "高" -and $_.AccountEnabled -eq $true } | Sort-Object DisplayName
    $partialLicenseUsers = $LicenseResults | Where-Object { $_.LicenseStatus -eq "部分的ライセンス" } | Sort-Object DisplayName
    $microsoft365Users = $LicenseResults | Where-Object { $_.Microsoft365License -eq $true } | Sort-Object DisplayName
    $noUsageLocationUsers = $LicenseResults | Where-Object { $_.UsageLocation -eq "未設定" -and $_.LicenseCount -gt 0 } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365ライセンス分析レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .value.cost { color: #0078d4; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; max-height: 500px; overflow-y: auto; }
        .table-container.large-table { max-height: 600px; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
            position: sticky;
            top: 0;
        }
        .license-m365 { color: #107c10; font-weight: bold; }
        .license-partial { color: #ff8c00; font-weight: bold; }
        .license-none { color: #d13438; font-weight: bold; }
        .cost-high { color: #d13438; font-weight: bold; }
        .cost-medium { color: #ff8c00; }
        .cost-low { color: #107c10; }
        .subscription-card {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            padding: 15px;
            margin: 10px 0;
        }
        .subscription-card h4 { margin: 0 0 10px 0; color: #0078d4; }
        .progress-bar {
            width: 100%;
            height: 10px;
            background: #e9ecef;
            border-radius: 5px;
            overflow: hidden;
            margin: 5px 0;
        }
        .progress-fill {
            height: 100%;
            transition: width 0.3s ease;
        }
        .progress-low { background: #107c10; }
        .progress-medium { background: #ff8c00; }
        .progress-high { background: #d13438; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(4, 1fr); }
            .table-container { max-height: none; overflow: visible; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Microsoft 365ライセンス分析レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - $($Summary.LicenseEnvironment)</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value">$($Summary.TotalUsers)</div>
            <div class="description">全アカウント</div>
        </div>
        <div class="summary-card">
            <h3>ライセンス済み</h3>
            <div class="value success">$($Summary.LicensedUsers)</div>
            <div class="description">割り当て済み</div>
        </div>
        <div class="summary-card">
            <h3>ライセンス未割当</h3>
            <div class="value danger">$($Summary.UnlicensedUsers)</div>
            <div class="description">要対応</div>
        </div>
        <div class="summary-card">
            <h3>Microsoft 365</h3>
            <div class="value success">$($Summary.Microsoft365Users)</div>
            <div class="description">包括ライセンス</div>
        </div>
        <div class="summary-card">
            <h3>部分的ライセンス</h3>
            <div class="value warning">$($Summary.PartialLicenseUsers)</div>
            <div class="description">最適化余地</div>
        </div>
        <div class="summary-card">
            <h3>高リスクユーザー</h3>
            <div class="value danger">$($Summary.HighRiskUsers)</div>
            <div class="description">緊急対応</div>
        </div>
        <div class="summary-card">
            <h3>推定月額コスト</h3>
            <div class="value cost">¥$($Summary.TotalLicenseCost.ToString('N0'))</div>
            <div class="description">総ライセンス費用</div>
        </div>
        <div class="summary-card">
            <h3>ユーザー単価</h3>
            <div class="value cost">¥$($Summary.AvgLicenseCostPerUser.ToString('N0'))</div>
            <div class="description">平均/月</div>
        </div>
    </div>
"@

    # 組織ライセンス概要
    if ($Subscriptions.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>📋 組織ライセンス概要</h2>
        </div>
        <div class="section-content">
"@
        foreach ($sub in $Subscriptions | Sort-Object ConsumedUnits -Descending) {
            $progressClass = if ($sub.UtilizationRate -ge 90) { "progress-high" } 
                           elseif ($sub.UtilizationRate -ge 70) { "progress-medium" } 
                           else { "progress-low" }
            
            $htmlTemplate += @"
            <div class="subscription-card">
                <h4>$($sub.DisplayName)</h4>
                <p>総ライセンス数: $($sub.TotalLicenses) | 使用中: $($sub.ConsumedUnits) | 利用可能: $($sub.AvailableLicenses)</p>
                <div class="progress-bar">
                    <div class="progress-fill $progressClass" style="width: $($sub.UtilizationRate)%"></div>
                </div>
                <small>利用率: $($sub.UtilizationRate)%</small>
            </div>
"@
        }
        $htmlTemplate += @"
        </div>
    </div>
"@
    }

    # 高リスクユーザー（ライセンス未割当のアクティブユーザー）
    if ($highRiskUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 高リスクユーザー (アクティブ・ライセンス未割当)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>ユーザータイプ</th>
                            <th>使用地域</th>
                            <th>作成日</th>
                            <th>推奨事項</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $highRiskUsers) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td>$($user.UserType)</td>
                            <td>$($user.UsageLocation)</td>
                            <td>$($user.CreatedDate)</td>
                            <td class="license-none">$($user.Recommendations)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 部分的ライセンスユーザー
    if ($partialLicenseUsers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 部分的ライセンスユーザー</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>現在のライセンス</th>
                            <th>推定コスト/月</th>
                            <th>推奨事項</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $partialLicenseUsers) {
            $costClass = if ($user.TotalLicenseValue -gt 2000) { "cost-high" } 
                        elseif ($user.TotalLicenseValue -gt 1000) { "cost-medium" } 
                        else { "cost-low" }
            
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td class="license-partial">$($user.LicenseDetails)</td>
                            <td class="$costClass">¥$($user.TotalLicenseValue)</td>
                            <td>$($user.Recommendations)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # Microsoft 365ライセンスユーザー（全件表示）
    if ($microsoft365Users.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>✅ Microsoft 365ライセンスユーザー (全$($microsoft365Users.Count)件)</h2>
        </div>
        <div class="section-content">
            <p><strong>注意:</strong> 件数が多い場合、テーブルはスクロール表示されます。</p>
            <div class="table-container large-table">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>ライセンス詳細</th>
                            <th>Exchange</th>
                            <th>SharePoint</th>
                            <th>Teams</th>
                            <th>Office Apps</th>
                            <th>推定コスト/月</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($user in $microsoft365Users) {
            $exchangeIcon = if ($user.ExchangeOnline) { "✓" } else { "✗" }
            $sharepointIcon = if ($user.SharePointOnline) { "✓" } else { "✗" }
            $teamsIcon = if ($user.TeamsLicense) { "✓" } else { "✗" }
            $officeIcon = if ($user.OfficeApps) { "✓" } else { "✗" }
            
            $htmlTemplate += @"
                        <tr>
                            <td>$($user.DisplayName)</td>
                            <td>$($user.UserPrincipalName)</td>
                            <td class="license-m365">$($user.LicenseDetails)</td>
                            <td>$exchangeIcon</td>
                            <td>$sharepointIcon</td>
                            <td>$teamsIcon</td>
                            <td>$officeIcon</td>
                            <td>¥$($user.TotalLicenseValue)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# 公開関数のエクスポート
Export-ModuleMember -Function Get-UsersWithoutMFA, Get-FailedSignInAlerts, Get-PasswordExpiryUsers, Get-UnlicensedUsers, Get-UserAttributeChanges, Get-Microsoft365LicenseStatus