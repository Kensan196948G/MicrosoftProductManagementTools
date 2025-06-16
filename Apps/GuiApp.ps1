# ================================================================================
# Microsoft 365統合管理ツール - GUI アプリケーション
# GuiApp.ps1
# System.Windows.Forms ベースのGUIインターフェース
# PowerShell 7.5.1専用
# ================================================================================

[CmdletBinding()]
param(
)

# プラットフォーム検出とアセンブリ読み込み
if ($IsLinux -or $IsMacOS) {
    Write-Host "エラー: このGUIアプリケーションはWindows環境でのみ動作します。" -ForegroundColor Red
    Write-Host "現在の環境: $($PSVersionTable.Platform)" -ForegroundColor Yellow
    Write-Host "CLIモードをご利用ください: pwsh -File run_launcher.ps1 -Mode cli" -ForegroundColor Green
    exit 1
}

# 必要なアセンブリの読み込み（Windows環境のみ）
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Add-Type -AssemblyName System.ComponentModel -ErrorAction Stop
    Add-Type -AssemblyName System.Web -ErrorAction Stop
}
catch {
    Write-Host "エラー: Windows Formsアセンブリの読み込みに失敗しました。" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "このアプリケーションはWindows .NET Framework環境が必要です。" -ForegroundColor Yellow
    exit 1
}

# Windows Forms設定フラグ
$Script:FormsConfigured = $false

# Windows Forms初期設定関数
function Initialize-WindowsForms {
    if (-not $Script:FormsConfigured) {
        try {
            # Visual Styles のみ有効化（SetCompatibleTextRenderingDefaultは回避）
            [System.Windows.Forms.Application]::EnableVisualStyles()
            $Script:FormsConfigured = $true
            Write-Host "Windows Forms設定完了" -ForegroundColor Green
        }
        catch {
            Write-Host "警告: Windows Forms設定に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "一部表示が正しくない可能性がありますが、続行します。" -ForegroundColor Yellow
        }
    }
}

# グローバル変数
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent
$Script:Form = $null
$Script:StatusLabel = $null
$Script:LogTextBox = $null
$Script:ProgressBar = $null

# GUI要素への参照を保持するためのグローバル変数
$Global:GuiLogTextBox = $null
$Global:GuiStatusLabel = $null

# モジュール読み込みはMain関数内で遅延実行
$Script:ModuleLoadError = $null
$Script:ModulesLoaded = $false

# 遅延モジュール読み込み関数
function Import-RequiredModules {
    if (-not $Script:ModulesLoaded) {
        try {
            Import-Module "$Script:ToolRoot\Scripts\Common\Common.psm1" -Force -ErrorAction Stop
            Import-Module "$Script:ToolRoot\Scripts\Common\Logging.psm1" -Force -ErrorAction Stop
            Import-Module "$Script:ToolRoot\Scripts\Common\Authentication.psm1" -Force -ErrorAction Stop
            $Script:ModulesLoaded = $true
            Write-Host "必要なモジュールを読み込みました" -ForegroundColor Green
        }
        catch {
            $Script:ModuleLoadError = $_.Exception.Message
            Write-Host "警告: 必要なモジュールの読み込みに失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# レポートフォルダ構造管理とファイル出力関数
function Initialize-ReportFolders {
    param([string]$BaseReportsPath)
    
    $folderStructure = @(
        "Authentication",
        "Reports\Daily",
        "Reports\Weekly", 
        "Reports\Monthly",
        "Reports\Yearly",
        "Analysis\License",
        "Analysis\Usage",
        "Analysis\Performance",
        "Tools\Config",
        "Tools\Logs",
        "Exchange\Mailbox",
        "Exchange\MailFlow",
        "Exchange\AntiSpam",
        "Exchange\Delivery",
        "Teams\Usage",
        "Teams\MeetingQuality",
        "Teams\ExternalAccess",
        "Teams\Apps",
        "OneDrive\Storage",
        "OneDrive\Sharing",
        "OneDrive\SyncErrors",
        "OneDrive\ExternalSharing",
        "EntraID\Users",
        "EntraID\SignInLogs",
        "EntraID\ConditionalAccess",
        "EntraID\MFA",
        "EntraID\AppRegistrations"
    )
    
    foreach ($folder in $folderStructure) {
        $fullPath = Join-Path $BaseReportsPath $folder
        if (-not (Test-Path $fullPath)) {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            Write-Host "フォルダ作成: $fullPath" -ForegroundColor Green
        }
    }
}

function Export-ReportData {
    param(
        [string]$Category,
        [string]$ReportName,
        [object]$Data,
        [string]$BaseReportsPath
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileName = "${ReportName}_${timestamp}"
    
    # カテゴリに応じたサブフォルダ決定
    $subFolder = switch ($Category) {
        "Auth" { "Authentication" }
        "Daily" { "Reports\Daily" }
        "Weekly" { "Reports\Weekly" }
        "Monthly" { "Reports\Monthly" }
        "Yearly" { "Reports\Yearly" }
        "License" { "Analysis\License" }
        "UsageAnalysis" { "Analysis\Usage" }
        "PerformanceMonitor" { "Analysis\Performance" }
        "ConfigManagement" { "Tools\Config" }
        "LogViewer" { "Tools\Logs" }
        "ExchangeMailboxMonitor" { "Exchange\Mailbox" }
        "ExchangeMailFlow" { "Exchange\MailFlow" }
        "ExchangeAntiSpam" { "Exchange\AntiSpam" }
        "ExchangeDeliveryReport" { "Exchange\Delivery" }
        "TeamsUsage" { "Teams\Usage" }
        "TeamsMeetingQuality" { "Teams\MeetingQuality" }
        "TeamsExternalAccess" { "Teams\ExternalAccess" }
        "TeamsAppsUsage" { "Teams\Apps" }
        "OneDriveStorage" { "OneDrive\Storage" }
        "OneDriveSharing" { "OneDrive\Sharing" }
        "OneDriveSyncErrors" { "OneDrive\SyncErrors" }
        "OneDriveExternalSharing" { "OneDrive\ExternalSharing" }
        "EntraIdUserMonitor" { "EntraID\Users" }
        "EntraIdSignInLogs" { "EntraID\SignInLogs" }
        "EntraIdConditionalAccess" { "EntraID\ConditionalAccess" }
        "EntraIdMFA" { "EntraID\MFA" }
        "EntraIdAppRegistrations" { "EntraID\AppRegistrations" }
        default { "General" }
    }
    
    $targetFolder = Join-Path $BaseReportsPath $subFolder
    if (-not (Test-Path $targetFolder)) {
        New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
    }
    
    # CSV形式で出力
    $csvPath = Join-Path $targetFolder "${fileName}.csv"
    # HTML形式で出力  
    $htmlPath = Join-Path $targetFolder "${fileName}.html"
    
    try {
        # CSV出力
        if ($Data -is [System.Collections.IEnumerable] -and $Data -isnot [string]) {
            $Data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        } else {
            $Data | Out-String | Set-Content -Path $csvPath -Encoding UTF8
        }
        
        # HTML出力
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportName レポート</title>
    <style>
        body { font-family: 'Yu Gothic', 'Meiryo', sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 15px; border-radius: 5px; }
        .content { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .timestamp { color: #666; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f4f4f4; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 3px; white-space: pre-wrap; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$ReportName レポート</h1>
        <div class="timestamp">生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</div>
    </div>
    <div class="content">
        <h2>レポートデータ</h2>
        <pre>$($Data | Out-String)</pre>
    </div>
</body>
</html>
"@
        Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
        
        return @{
            CSVPath = $csvPath
            HTMLPath = $htmlPath
            Success = $true
        }
    }
    catch {
        Write-Host "ファイル出力エラー: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# レポートデータ出力実行関数
function Export-ReportData {
    param(
        [string]$Category,
        [string]$ReportName,
        [object]$Data,
        [string]$BaseReportsPath
    )
    
    try {
        # パラメーター検証とデバッグ出力
        Write-Host "Export-ReportData: Category='$Category', ReportName='$ReportName', BaseReportsPath='$BaseReportsPath'" -ForegroundColor Cyan
        
        if ([string]::IsNullOrEmpty($BaseReportsPath)) {
            throw "BaseReportsPathが指定されていません"
        }
        
        if (-not (Test-Path $BaseReportsPath)) {
            Write-Host "BaseReportsPathが存在しないため作成します: $BaseReportsPath" -ForegroundColor Yellow
            New-Item -Path $BaseReportsPath -ItemType Directory -Force | Out-Null
        }
        # カテゴリに応じたフォルダ決定
        $categoryFolder = switch ($Category) {
            "Auth" { "Authentication" }
            "Daily" { "Daily" }
            "Weekly" { "Weekly" }
            "Monthly" { "Monthly" }
            "Yearly" { "Yearly" }
            "License" { "Analysis\License" }
            "Usage" { "Analysis\Usage" }
            "Performance" { "Analysis\Performance" }
            "Config" { "Tools\Config" }
            "Logs" { "Tools\Logs" }
            "ExchangeMailbox" { "Exchange\Mailbox" }
            "ExchangeMailFlow" { "Exchange\MailFlow" }
            "ExchangeAntiSpam" { "Exchange\AntiSpam" }
            "ExchangeDelivery" { "Exchange\Delivery" }
            "Teams" { "Teams\Usage" }
            "TeamsMeeting" { "Teams\MeetingQuality" }
            "TeamsExternal" { "Teams\ExternalAccess" }
            "TeamsApps" { "Teams\Apps" }
            "OneDriveStorage" { "OneDrive\Storage" }
            "OneDriveSharing" { "OneDrive\Sharing" }
            "OneDriveSync" { "OneDrive\SyncErrors" }
            "OneDriveExternal" { "OneDrive\ExternalSharing" }
            "EntraUsers" { "EntraID\Users" }
            "EntraSignIn" { "EntraID\SignInLogs" }
            "EntraConditional" { "EntraID\ConditionalAccess" }
            "EntraMFA" { "EntraID\MFA" }
            "EntraApps" { "EntraID\AppRegistrations" }
            default { "Reports\General" }
        }
        
        # フォルダパス作成
        Write-Host "CategoryFolder: '$categoryFolder'" -ForegroundColor Cyan
        $outputFolder = Join-Path $BaseReportsPath $categoryFolder
        Write-Host "OutputFolder: '$outputFolder'" -ForegroundColor Cyan
        
        if (-not (Test-Path $outputFolder)) {
            Write-Host "出力フォルダが存在しないため作成します: $outputFolder" -ForegroundColor Yellow
            New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
        }
        
        # ファイル名生成
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $safeReportName = $ReportName -replace '[^\w\-_\.]', '_'
        $fileName = "${safeReportName}_${timestamp}"
        Write-Host "FileName: '$fileName'" -ForegroundColor Cyan
        
        # CSV出力
        $csvPath = Join-Path $outputFolder "$fileName.csv"
        Write-Host "CSVPath: '$csvPath'" -ForegroundColor Cyan
        
        if ([string]::IsNullOrEmpty($csvPath)) {
            throw "CSVパスの生成に失敗しました。outputFolder='$outputFolder', fileName='$fileName'"
        }
        
        if ($Data -is [Array] -and $Data.Count -gt 0) {
            Write-Host "データ配列をCSVに出力中... (${Data.Count}件)" -ForegroundColor Green
            $Data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        } else {
            Write-Host "データを文字列としてCSVに出力中..." -ForegroundColor Green
            $Data | Out-String | Set-Content -Path $csvPath -Encoding UTF8
        }
        
        # HTML出力
        $htmlPath = Join-Path $outputFolder "$fileName.html"
        Write-Host "HTMLPath: '$htmlPath'" -ForegroundColor Cyan
        
        if ([string]::IsNullOrEmpty($htmlPath)) {
            throw "HTMLパスの生成に失敗しました。outputFolder='$outputFolder', fileName='$fileName'"
        }
        
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportName - Microsoft 365統合管理ツール</title>
    <style>
        body { font-family: 'Yu Gothic', 'Meiryo', sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #0078d4; color: white; padding: 20px; border-radius: 5px; text-align: center; }
        .content { background-color: white; padding: 20px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { margin: 0; font-size: 24px; }
        h2 { color: #0078d4; border-bottom: 2px solid #0078d4; padding-bottom: 5px; }
        .timestamp { color: #666; font-size: 0.9em; margin-top: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f4f4f4; }
        pre { background-color: #f8f9fa; padding: 15px; border-radius: 3px; white-space: pre-wrap; overflow-x: auto; }
        .data-section { margin: 15px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$ReportName</h1>
        <div class="timestamp">生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</div>
    </div>
    <div class="content">
        <h2>レポートデータ</h2>
        <div class="data-section">
"@

        # データの種類に応じてHTML出力を調整
        if ($Data -is [Array] -and $Data.Count -gt 0 -and $Data[0] -is [PSCustomObject]) {
            # PSCustomObject配列の場合はテーブル形式で出力
            $htmlContent += "<table>`n<thead><tr>"
            
            # ヘッダー行作成
            $firstItem = $Data[0]
            $properties = $firstItem.PSObject.Properties.Name
            foreach ($prop in $properties) {
                $htmlContent += "<th>$prop</th>"
            }
            $htmlContent += "</tr></thead>`n<tbody>"
            
            # データ行作成
            foreach ($item in $Data) {
                $htmlContent += "<tr>"
                foreach ($prop in $properties) {
                    $value = $item.$prop
                    if ($null -eq $value) { $value = "" }
                    $encodedValue = try {
                        [System.Web.HttpUtility]::HtmlEncode($value.ToString())
                    } catch {
                        # フォールバック: 手動エスケープ
                        $value.ToString() -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&#39;'
                    }
                    $htmlContent += "<td>$encodedValue</td>"
                }
                $htmlContent += "</tr>`n"
            }
            $htmlContent += "</tbody></table>"
        } else {
            # その他の場合はプレーンテキストとして出力
            $textData = $Data | Out-String
            $encodedTextData = try {
                [System.Web.HttpUtility]::HtmlEncode($textData)
            } catch {
                # フォールバック: 手動エスケープ
                $textData -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&#39;'
            }
            $htmlContent += "<pre>$encodedTextData</pre>"
        }

        $htmlContent += @"
        </div>
    </div>
    <div style="text-align: center; color: #666; font-size: 0.8em; margin-top: 30px;">
        Generated by Microsoft 365統合管理ツール
    </div>
</body>
</html>
"@
        Write-Host "HTMLファイルを出力中..." -ForegroundColor Green
        Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
        
        Write-Host "レポート出力完了: CSV='$csvPath', HTML='$htmlPath'" -ForegroundColor Green
        
        return @{
            CSVPath = $csvPath
            HTMLPath = $htmlPath
            Success = $true
        }
    }
    catch {
        Write-Host "ファイル出力エラー: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# GUI ログ出力関数
function Write-SafeGuiLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $formattedMessage = "[$timestamp] [$Level] $Message"
    
    if ($Script:LogTextBox) {
        $Script:LogTextBox.Invoke([Action[string]]{
            param($msg)
            $Script:LogTextBox.AppendText("$msg`r`n")
            $Script:LogTextBox.ScrollToCaret()
        }, $formattedMessage)
    }
    
    # 通常のログにも出力
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Message $Message -Level $Level
    }
}

# 重複削除（既に上で定義済み）

# ステータス更新関数
function Update-Status {
    param([string]$Message)
    
    if ($Script:StatusLabel) {
        $Script:StatusLabel.Invoke([Action[string]]{
            param($msg)
            $Script:StatusLabel.Text = $msg
        }, $Message)
    }
}

# プログレスバー更新関数
function Update-Progress {
    param(
        [int]$Value,
        [string]$Status = ""
    )
    
    if ($Script:ProgressBar) {
        $Script:ProgressBar.Invoke([Action[int]]{
            param($val)
            $Script:ProgressBar.Value = [Math]::Min([Math]::Max($val, 0), 100)
        }, $Value)
    }
    
    if ($Status) {
        Update-Status $Status
    }
}

# 認証実行
function Invoke-Authentication {
    try {
        Update-Status "認証を実行中..."
        Update-Progress 10 "設定ファイルを読み込み中..."
        
        # 設定ファイル読み込み
        $configPath = Join-Path $Script:ToolRoot "Config\appsettings.json"
        if (-not (Test-Path $configPath)) {
            throw "設定ファイルが見つかりません: $configPath"
        }
        $config = Get-Content $configPath | ConvertFrom-Json
        
        Update-Progress 30 "Microsoft Graph に接続中..."
        Write-SafeGuiLog "Microsoft Graph認証を開始します" -Level Info
        
        # 利用可能な認証関数を確認
        if (Get-Command Connect-ToMicrosoft365 -ErrorAction SilentlyContinue) {
            $authResult = Connect-ToMicrosoft365 -Config $config
        } elseif (Get-Command Connect-ToMicrosoftGraph -ErrorAction SilentlyContinue) {
            $authResult = Connect-ToMicrosoftGraph -Config $config
        } else {
            throw "認証機能が利用できません。必要なモジュールが読み込まれていません。"
        }
        if ($authResult) {
            Update-Progress 100 "認証完了"
            Write-SafeGuiLog "Microsoft Graph認証が成功しました" -Level Success
            [System.Windows.Forms.MessageBox]::Show(
                "Microsoft 365への認証が成功しました！",
                "認証成功",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            throw "認証に失敗しました"
        }
    }
    catch {
        Update-Progress 0 "認証エラー"
        Write-SafeGuiLog "認証エラー: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "認証に失敗しました:`n$($_.Exception.Message)",
            "認証エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# レポート生成実行
function Invoke-ReportGeneration {
    param([string]$ReportType)
    
    try {
        Update-Status "レポートを生成中..."
        Write-SafeGuiLog "$ReportType レポートの生成を開始します" -Level Info
        
        Update-Progress 20 "レポートスクリプトを準備中..."
        # スクリプトファイルのパス確認
        $reportScript = "$Script:ToolRoot\Scripts\Common\ScheduledReports.ps1"
        if (-not (Test-Path $reportScript)) {
            throw "レポートスクリプトが見つかりません: $reportScript"
        }
        
        Update-Progress 50 "レポートを生成中..."
        
        # レポート生成の実行
        switch ($ReportType) {
            "Daily" {
                & $reportScript -ReportType "Daily"
            }
            "Weekly" {
                & $reportScript -ReportType "Weekly"
            }
            "Monthly" {
                & $reportScript -ReportType "Monthly"
            }
            "Yearly" {
                & $reportScript -ReportType "Yearly"
            }
            default {
                throw "不明なレポートタイプ: $ReportType"
            }
        }
        
        Update-Progress 100 "レポート生成完了"
        Write-SafeGuiLog "$ReportType レポートの生成が完了しました" -Level Success
        
        [System.Windows.Forms.MessageBox]::Show(
            "$ReportType レポートの生成が完了しました！`nレポートはReportsフォルダに保存されています。",
            "レポート生成完了",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        Update-Progress 0 "レポート生成エラー"
        Write-SafeGuiLog "レポート生成エラー: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "レポート生成に失敗しました:`n$($_.Exception.Message)",
            "レポート生成エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# ライセンス分析実行
function Invoke-LicenseAnalysis {
    try {
        Update-Status "ライセンス分析を実行中..."
        Write-SafeGuiLog "ライセンス分析を開始します" -Level Info
        
        Update-Progress 30 "ライセンス情報を取得中..."
        # ライセンスダッシュボードスクリプトのパス確認
        $licenseScript = "$Script:ToolRoot\Archive\UtilityFiles\New-LicenseDashboard.ps1"
        if (-not (Test-Path $licenseScript)) {
            # 代替パスを試行
            $licenseScript = "$Script:ToolRoot\Scripts\EntraID\LicenseAnalysis.ps1"
        }
        if (-not (Test-Path $licenseScript)) {
            throw "ライセンス分析スクリプトが見つかりません"
        }
        & $licenseScript
        
        Update-Progress 100 "ライセンス分析完了"
        Write-SafeGuiLog "ライセンス分析が完了しました" -Level Success
        
        [System.Windows.Forms.MessageBox]::Show(
            "ライセンス分析が完了しました！`nダッシュボードファイルが生成されています。",
            "ライセンス分析完了",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        Update-Progress 0 "ライセンス分析エラー"
        Write-SafeGuiLog "ライセンス分析エラー: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "ライセンス分析に失敗しました:`n$($_.Exception.Message)",
            "ライセンス分析エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# レポートフォルダを開く
function Open-ReportsFolder {
    try {
        $reportsPath = Join-Path $Script:ToolRoot "Reports"
        if (Test-Path $reportsPath) {
            Start-Process explorer.exe -ArgumentList $reportsPath
            Write-SafeGuiLog "レポートフォルダを開きました: $reportsPath" -Level Info
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "レポートフォルダが見つかりません: $reportsPath",
                "フォルダエラー",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    }
    catch {
        Write-SafeGuiLog "レポートフォルダを開く際にエラーが発生しました: $($_.Exception.Message)" -Level Error
    }
}

# メインフォーム作成
function New-MainForm {
    try {
        Write-Host "New-MainForm: 関数開始" -ForegroundColor Magenta
        $form = New-Object System.Windows.Forms.Form
        Write-Host "New-MainForm: Formオブジェクト作成完了" -ForegroundColor Magenta
    $form.Text = "Microsoft 365統合管理ツール - GUI版"
    $form.Size = New-Object System.Drawing.Size(1200, 900)  # より大きなサイズに変更
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable  # リサイズ可能に変更
    $form.MaximizeBox = $true  # 最大化ボタンを有効
    $form.MinimumSize = New-Object System.Drawing.Size(1000, 700)  # 最小サイズを設定
    $form.Icon = [System.Drawing.SystemIcons]::Application
    
    # メインパネル
    $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainPanel.RowCount = 4
    $mainPanel.ColumnCount = 1
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 400)))  # ボタンエリアを大きく
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    
    # ヘッダーパネル
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.BackColor = [System.Drawing.Color]::Navy
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    
    $headerLabel = New-Object System.Windows.Forms.Label
    $headerLabel.Text = "Microsoft 365統合管理ツール"
    $headerLabel.Font = New-Object System.Drawing.Font("MS Gothic", 16, [System.Drawing.FontStyle]::Bold)
    $headerLabel.ForeColor = [System.Drawing.Color]::White
    $headerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $headerLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $headerPanel.Controls.Add($headerLabel)
    
    # アコーディオン式ボタンパネル
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttonPanel.AutoScroll = $true
    $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    
    # アコーディオンセクション作成関数
    function New-AccordionSection {
        param(
            [string]$Title,
            [hashtable[]]$Buttons,
            [int]$YPosition
        )
        
        # セクションパネル
        $sectionPanel = New-Object System.Windows.Forms.Panel
        $sectionPanel.Location = New-Object System.Drawing.Point(0, $YPosition)
        $sectionPanel.Width = $buttonPanel.ClientSize.Width - 20
        $sectionPanel.Height = 35  # 初期高さ（折りたたみ状態）
        $sectionPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        
        # タイトルバー
        $titleBar = New-Object System.Windows.Forms.Panel
        $titleBar.Height = 35
        $titleBar.Dock = [System.Windows.Forms.DockStyle]::Top
        $titleBar.BackColor = [System.Drawing.Color]::DarkBlue
        $titleBar.Cursor = [System.Windows.Forms.Cursors]::Hand
        
        # タイトルラベル
        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = "▶ $Title"
        $titleLabel.ForeColor = [System.Drawing.Color]::White
        $titleLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
        $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $titleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
        $titleLabel.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $titleLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
        
        # ボタンコンテナ
        $buttonContainer = New-Object System.Windows.Forms.FlowLayoutPanel
        $buttonContainer.Location = New-Object System.Drawing.Point(0, 35)  # タイトルバーの下に配置
        $buttonContainer.Size = New-Object System.Drawing.Size(($sectionPanel.Width), 100)  # 明示的なサイズ指定
        $buttonContainer.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        $buttonContainer.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
        $buttonContainer.WrapContents = $true
        $buttonContainer.Padding = New-Object System.Windows.Forms.Padding(15, 10, 15, 15)
        $buttonContainer.AutoSize = $false
        $buttonContainer.AutoScroll = $false
        $buttonContainer.Visible = $false
        
        # 展開/折りたたみの状態を直接パネルに保存
        $sectionPanel | Add-Member -NotePropertyName "IsExpanded" -NotePropertyValue $false
        $sectionPanel | Add-Member -NotePropertyName "OriginalTitle" -NotePropertyValue $Title
        $sectionPanel | Add-Member -NotePropertyName "TitleLabel" -NotePropertyValue $titleLabel
        $sectionPanel | Add-Member -NotePropertyName "ButtonContainer" -NotePropertyValue $buttonContainer
        
        # 展開/折りたたみ処理（直接参照版）
        $toggleAction = {
            param($sender, $e)
            
            try {
                # senderから正しいパネルを特定
                $panel = $null
                $current = $sender
                
                # 最大3レベルまで親を検索
                for ($i = 0; $i -lt 3; $i++) {
                    if ($current -and $current.PSObject.Properties["IsExpanded"]) {
                        $panel = $current
                        break
                    }
                    $current = $current.Parent
                }
                
                if (-not $panel) {
                    Write-Host "展開対象パネルが見つかりません" -ForegroundColor Yellow
                    return
                }
                
                # 直接保存された参照を使用
                $label = $panel.TitleLabel
                $container = $panel.ButtonContainer
                
                if (-not $label -or -not $container) {
                    Write-Host "ラベルまたはコンテナが見つかりません" -ForegroundColor Yellow
                    return
                }
                
                if ($panel.IsExpanded) {
                    $label.Text = "▶ $($panel.OriginalTitle)"
                    $container.Visible = $false
                    $panel.Height = 35
                    $panel.IsExpanded = $false
                    Write-Host "$($panel.OriginalTitle) セクションを折りたたみました" -ForegroundColor Cyan
                } else {
                    $label.Text = "▼ $($panel.OriginalTitle)"
                    $container.Visible = $true
                    
                    # ボタン数に応じて動的高さ計算（保守的）
                    $buttonCount = $container.Controls.Count
                    $containerWidth = if ($container.Width -gt 0) { $container.Width } else { 600 }  # より大きなデフォルト幅
                    $buttonsPerRow = [Math]::Floor(($containerWidth - 60) / 170)  # ボタン幅170px (150 + マージン20)
                    if ($buttonsPerRow -lt 1) { $buttonsPerRow = 1 }
                    if ($buttonsPerRow -gt 3) { $buttonsPerRow = 3 }  # 最大3個/行に制限
                    $rows = [Math]::Ceiling($buttonCount / $buttonsPerRow)
                    
                    # より保守的な高さ計算
                    $buttonRowHeight = 55  # ボタン高さ40 + マージン15
                    $titleHeight = 35
                    $topPadding = 20
                    $bottomPadding = 25
                    $dynamicHeight = $titleHeight + $topPadding + ($rows * $buttonRowHeight) + $bottomPadding
                    
                    # 最小高さ保証
                    if ($dynamicHeight -lt 120) { $dynamicHeight = 120 }
                    
                    # ボタンコンテナのサイズも調整
                    $containerHeight = $dynamicHeight - 35  # タイトルバーの高さを除く
                    $container.Size = New-Object System.Drawing.Size($container.Width, $containerHeight)
                    
                    $panel.Height = $dynamicHeight
                    $panel.IsExpanded = $true
                    Write-Host "$($panel.OriginalTitle) セクションを展開しました" -ForegroundColor Cyan
                    Write-Host "  - 高さ: $dynamicHeight px (タイトル:$titleHeight + パディング:$($topPadding+$bottomPadding) + ボタン:$($rows)行×$buttonRowHeight)" -ForegroundColor Gray
                    Write-Host "  - ボタン数: $buttonCount 個 ($buttonsPerRow 個/行)" -ForegroundColor Gray
                }
                
                # 他のセクションの位置を再配置
                $yPosition = 10
                foreach ($control in $panel.Parent.Controls) {
                    if ($control -is [System.Windows.Forms.Panel] -and $control.PSObject.Properties["IsExpanded"]) {
                        $control.Location = New-Object System.Drawing.Point(10, $yPosition)
                        $yPosition += $control.Height + 10
                    }
                }
                
                # 親パネルの再描画
                if ($panel.Parent) {
                    $panel.Parent.Refresh()
                }
            }
            catch {
                Write-Host "展開処理エラー: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "エラー詳細: $($_.Exception.StackTrace)" -ForegroundColor Yellow
            }
        }
        
        # クリックイベント設定
        $titleBar.Add_Click($toggleAction)
        $titleLabel.Add_Click($toggleAction)
        
        # ボタンを追加
        Write-Host "New-AccordionSection: $Title にボタンを追加中 (${Buttons.Count}個)" -ForegroundColor Gray
        foreach ($buttonInfo in $Buttons) {
            $button = New-ActionButton -Text $buttonInfo.Text -Action $buttonInfo.Action
            $button.Size = New-Object System.Drawing.Size(150, 40)  # サイズを少し大きく
            $button.Margin = New-Object System.Windows.Forms.Padding(5, 3, 5, 3)  # 上下マージンを調整
            $buttonContainer.Controls.Add($button)
            Write-Host "  - ボタン追加: $($buttonInfo.Text)" -ForegroundColor DarkGray
        }
        Write-Host "New-AccordionSection: $Title コンテナ完了 (${buttonContainer.Controls.Count}個のボタン)" -ForegroundColor Gray
        
        # コンテナに追加
        $titleBar.Controls.Add($titleLabel)
        $sectionPanel.Controls.Add($titleBar)
        $sectionPanel.Controls.Add($buttonContainer)
        
        return $sectionPanel
    }
    
    # ボタン作成関数
    function New-ActionButton {
        param([string]$Text, [string]$Action)
        
        $button = New-Object System.Windows.Forms.Button
        $button.Text = $Text
        $button.Size = New-Object System.Drawing.Size(120, 40)
        $button.Anchor = [System.Windows.Forms.AnchorStyles]::None
        $button.UseVisualStyleBackColor = $true
        $button.Font = New-Object System.Drawing.Font("MS Gothic", 9)
        
        # 変数を明示的にキャプチャ
        $buttonText = $Text
        $buttonAction = $Action
        
        $button.Add_Click({
            try {
                [System.Windows.Forms.Application]::DoEvents()
                
                # デバッグ: ボタンクリック確認
                Write-Host "ボタンクリック検出: $buttonText ($buttonAction)" -ForegroundColor Magenta
                
                # 安全なログ出力（グローバル参照を使用）
                $message = "$buttonText ボタンがクリックされました"
                Write-Host "ログ出力テスト - Script:LogTextBox: $($Script:LogTextBox -ne $null), Global:GuiLogTextBox: $($Global:GuiLogTextBox -ne $null)" -ForegroundColor Cyan
                
                $logTextBox = if ($Global:GuiLogTextBox) { $Global:GuiLogTextBox } else { $Script:LogTextBox }
                if ($logTextBox) {
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    try {
                        $logTextBox.Invoke([Action[string]]{
                            param($msg)
                            $logTextBox.AppendText("[$timestamp] [Info] $msg`r`n")
                            $logTextBox.ScrollToCaret()
                        }, $message)
                        Write-Host "ログ出力成功: $message" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ログ出力エラー: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "LogTextBoxが利用できません" -ForegroundColor Red
                }
                
                Write-Host "処理開始: $buttonAction" -ForegroundColor Magenta
                Write-Host "switch文実行前: アクション='$buttonAction'" -ForegroundColor Cyan
                
                # グローバル参照を使用してログ出力
                function Write-GuiLog {
                    param([string]$Message, [string]$Level = "Info")
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    $formattedMessage = "[$timestamp] [$Level] $Message"
                    
                    $targetLogTextBox = if ($Global:GuiLogTextBox) { $Global:GuiLogTextBox } else { $Script:LogTextBox }
                    if ($targetLogTextBox) {
                        try {
                            $targetLogTextBox.Invoke([Action[string]]{
                                param($msg)
                                $targetLogTextBox.AppendText("$msg`r`n")
                                $targetLogTextBox.ScrollToCaret()
                            }, $formattedMessage)
                            Write-Host "GUI ログ成功: $formattedMessage" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "GUI ログエラー: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "GUI ログ失敗: LogTextBoxなし" -ForegroundColor Red
                    }
                }
                
                switch ($buttonAction) {
                    "Auth" { 
                        Write-Host "認証テスト処理開始" -ForegroundColor Yellow
                        
                        Write-GuiLog "認証テストを開始します" "Info"
                        
                        # サンプル認証データの生成
                        $authData = @(
                            [PSCustomObject]@{
                                ユーザー名 = "user001@company.com"
                                認証方法 = "MFA (SMS)"
                                認証結果 = "成功"
                                認証時刻 = (Get-Date).AddMinutes(-30).ToString("yyyy-MM-dd HH:mm:ss")
                                IPアドレス = "192.168.1.100"
                                場所 = "東京, 日本"
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user002@company.com"
                                認証方法 = "MFA (App)"
                                認証結果 = "成功"
                                認証時刻 = (Get-Date).AddMinutes(-15).ToString("yyyy-MM-dd HH:mm:ss")
                                IPアドレス = "192.168.1.101"
                                場所 = "大阪, 日本"
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user003@company.com"
                                認証方法 = "パスワードのみ"
                                認証結果 = "失敗"
                                認証時刻 = (Get-Date).AddMinutes(-5).ToString("yyyy-MM-dd HH:mm:ss")
                                IPアドレス = "203.0.113.10"
                                場所 = "不明"
                            }
                        )
                        
                        # 簡素化されたレポート出力
                        try {
                            $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path $PSScriptRoot -Parent }
                            if (-not $toolRoot) { $toolRoot = Split-Path $PSCommandPath -Parent }
                            if (-not $toolRoot) { $toolRoot = Get-Location }
                            
                            $outputFolder = Join-Path $toolRoot "Reports\Authentication"
                            if (-not (Test-Path $outputFolder)) {
                                New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
                            }
                            
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $csvPath = Join-Path $outputFolder "認証テスト結果_${timestamp}.csv"
                            $htmlPath = Join-Path $outputFolder "認証テスト結果_${timestamp}.html"
                            
                            # CSV出力
                            $authData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                            
                            # 簡単なHTML出力
                            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>認証テスト結果</title></head>
<body>
<h1>認証テスト結果</h1>
<p>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
<table border="1">
<tr><th>ユーザー名</th><th>認証方法</th><th>認証結果</th><th>認証時刻</th><th>IPアドレス</th><th>場所</th></tr>
"@
                            foreach ($item in $authData) {
                                $htmlContent += "<tr><td>$($item.ユーザー名)</td><td>$($item.認証方法)</td><td>$($item.認証結果)</td><td>$($item.認証時刻)</td><td>$($item.IPアドレス)</td><td>$($item.場所)</td></tr>"
                            }
                            $htmlContent += "</table></body></html>"
                            
                            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
                            
                            $exportResult = @{
                                CSVPath = $csvPath
                                HTMLPath = $htmlPath
                                Success = $true
                            }
                        }
                        catch {
                            $exportResult = @{
                                Success = $false
                                Error = $_.Exception.Message
                            }
                        }
                        
                        if ($exportResult.Success) {
                            Write-GuiLog "認証テストレポートを出力しました" "Success"
                            Write-GuiLog "CSV: $($exportResult.CSVPath)" "Info"
                            Write-GuiLog "HTML: $($exportResult.HTMLPath)" "Info"
                            
                            [System.Windows.Forms.MessageBox]::Show("認証テストが完了しました。`n`nレポートファイル:`n・CSV: $(Split-Path $exportResult.CSVPath -Leaf)`n・HTML: $(Split-Path $exportResult.HTMLPath -Leaf)", "認証テスト完了", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        } else {
                            Write-GuiLog "レポート出力エラー: $($exportResult.Error)" "Error"
                            [System.Windows.Forms.MessageBox]::Show("認証テストは完了しましたが、レポート出力でエラーが発生しました。", "警告", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                        }
                        
                        Write-Host "認証テスト処理完了" -ForegroundColor Yellow
                    }
                    "Daily" { 
                        Write-GuiLog "日次レポートを生成します..." "Info"
                        
                        # サンプル日次レポートデータ
                        $dailyData = @(
                            [PSCustomObject]@{
                                項目 = "ログイン失敗数"
                                値 = "12件"
                                前日比 = "+3件"
                                状態 = "注意"
                            },
                            [PSCustomObject]@{
                                項目 = "新規ユーザー"
                                値 = "5名"
                                前日比 = "+2名"
                                状態 = "正常"
                            },
                            [PSCustomObject]@{
                                項目 = "容量使用率"
                                値 = "73.2%"
                                前日比 = "+1.1%"
                                状態 = "正常"
                            },
                            [PSCustomObject]@{
                                項目 = "メール送信数"
                                値 = "1,234件"
                                前日比 = "-56件"
                                状態 = "正常"
                            }
                        )
                        
                        # 簡素化された日次レポート出力
                        try {
                            $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path $PSScriptRoot -Parent }
                            if (-not $toolRoot) { $toolRoot = Split-Path $PSCommandPath -Parent }
                            if (-not $toolRoot) { $toolRoot = Get-Location }
                            
                            $outputFolder = Join-Path $toolRoot "Reports\Daily"
                            if (-not (Test-Path $outputFolder)) {
                                New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
                            }
                            
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $csvPath = Join-Path $outputFolder "日次レポート_${timestamp}.csv"
                            $htmlPath = Join-Path $outputFolder "日次レポート_${timestamp}.html"
                            
                            $dailyData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                            
                            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>日次レポート</title></head>
<body>
<h1>日次レポート</h1>
<p>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
<table border="1">
<tr><th>項目</th><th>値</th><th>前日比</th><th>状態</th></tr>
"@
                            foreach ($item in $dailyData) {
                                $htmlContent += "<tr><td>$($item.項目)</td><td>$($item.値)</td><td>$($item.前日比)</td><td>$($item.状態)</td></tr>"
                            }
                            $htmlContent += "</table></body></html>"
                            
                            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
                            
                            $exportResult = @{ CSVPath = $csvPath; HTMLPath = $htmlPath; Success = $true }
                        }
                        catch {
                            $exportResult = @{ Success = $false; Error = $_.Exception.Message }
                        }
                        
                        if ($exportResult.Success) {
                            Write-GuiLog "日次レポートを出力しました" "Success"
                            [System.Windows.Forms.MessageBox]::Show("日次レポートが完了しました。`n`nレポートファイル:`n・CSV: $(Split-Path $exportResult.CSVPath -Leaf)`n・HTML: $(Split-Path $exportResult.HTMLPath -Leaf)", "日次レポート完了", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        } else {
                            Write-GuiLog "日次レポート出力エラー: $($exportResult.Error)" "Error"
                        }
                    }
                    "Weekly" { 
                        Write-GuiLog "週次レポートを生成します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("週次レポート機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "週次レポート機能は開発中です" "Warning"
                    }
                    "Monthly" { 
                        Write-GuiLog "月次レポートを生成します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("月次レポート機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "月次レポート機能は開発中です" "Warning"
                    }
                    "License" { 
                        Write-GuiLog "ライセンス分析を開始します..." "Info"
                        
                        # サンプルライセンスデータ
                        $licenseData = @(
                            [PSCustomObject]@{
                                ライセンス種類 = "Microsoft 365 E3"
                                購入数 = "1000"
                                使用数 = "847"
                                利用率 = "84.7%"
                                残り = "153"
                                状態 = "正常"
                            },
                            [PSCustomObject]@{
                                ライセンス種類 = "Microsoft 365 E5"
                                購入数 = "200"
                                使用数 = "195"
                                利用率 = "97.5%"
                                残り = "5"
                                状態 = "注意"
                            },
                            [PSCustomObject]@{
                                ライセンス種類 = "Teams Phone"
                                購入数 = "150"
                                使用数 = "89"
                                利用率 = "59.3%"
                                残り = "61"
                                状態 = "正常"
                            },
                            [PSCustomObject]@{
                                ライセンス種類 = "Power BI Pro"
                                購入数 = "100"
                                使用数 = "78"
                                利用率 = "78.0%"
                                残り = "22"
                                状態 = "正常"
                            }
                        )
                        
                        # 簡素化されたライセンス分析出力
                        try {
                            $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path $PSScriptRoot -Parent }
                            if (-not $toolRoot) { $toolRoot = Split-Path $PSCommandPath -Parent }
                            if (-not $toolRoot) { $toolRoot = Get-Location }
                            
                            $outputFolder = Join-Path $toolRoot "Reports\Analysis\License"
                            if (-not (Test-Path $outputFolder)) {
                                New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
                            }
                            
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $csvPath = Join-Path $outputFolder "ライセンス分析_${timestamp}.csv"
                            $htmlPath = Join-Path $outputFolder "ライセンス分析_${timestamp}.html"
                            
                            $licenseData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                            
                            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>ライセンス分析</title></head>
<body>
<h1>ライセンス分析</h1>
<p>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
<table border="1">
<tr><th>ライセンス種類</th><th>購入数</th><th>使用数</th><th>利用率</th><th>残り</th><th>状態</th></tr>
"@
                            foreach ($item in $licenseData) {
                                $htmlContent += "<tr><td>$($item.ライセンス種類)</td><td>$($item.購入数)</td><td>$($item.使用数)</td><td>$($item.利用率)</td><td>$($item.残り)</td><td>$($item.状態)</td></tr>"
                            }
                            $htmlContent += "</table></body></html>"
                            
                            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
                            
                            $exportResult = @{ CSVPath = $csvPath; HTMLPath = $htmlPath; Success = $true }
                        }
                        catch {
                            $exportResult = @{ Success = $false; Error = $_.Exception.Message }
                        }
                        
                        if ($exportResult.Success) {
                            Write-GuiLog "ライセンス分析レポートを出力しました" "Success"
                            [System.Windows.Forms.MessageBox]::Show("ライセンス分析が完了しました。`n`nレポートファイル:`n・CSV: $(Split-Path $exportResult.CSVPath -Leaf)`n・HTML: $(Split-Path $exportResult.HTMLPath -Leaf)", "ライセンス分析完了", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        } else {
                            Write-GuiLog "ライセンス分析出力エラー: $($exportResult.Error)" "Error"
                        }
                    }
                    "OpenReports" { 
                        Write-Host "レポートフォルダを開く処理開始" -ForegroundColor Yellow
                        Write-GuiLog "レポートフォルダを開いています..." "Info"
                        
                        # ツールルートパス取得
                        $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path $PSScriptRoot -Parent }
                        if (-not $toolRoot) { $toolRoot = Split-Path $PSCommandPath -Parent }
                        if (-not $toolRoot) { $toolRoot = Get-Location }
                        
                        $reportsPath = Join-Path $toolRoot "Reports"
                        Write-Host "レポートパス: $reportsPath" -ForegroundColor Cyan
                        
                        if (Test-Path $reportsPath) {
                            Start-Process "explorer.exe" -ArgumentList $reportsPath
                            Write-GuiLog "レポートフォルダを開きました: $reportsPath" "Success"
                        } else {
                            Write-GuiLog "レポートフォルダが見つかりません: $reportsPath" "Warning"
                            [System.Windows.Forms.MessageBox]::Show("レポートフォルダが見つかりません:`n$reportsPath", "警告", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                        }
                        
                        Write-Host "レポートフォルダを開く処理完了" -ForegroundColor Yellow
                    }
                    "PermissionAudit" {
                        Write-GuiLog "権限監査を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("権限監査機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "権限監査機能は開発中です" "Warning"
                    }
                    "SecurityAnalysis" {
                        Write-GuiLog "セキュリティ分析を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("セキュリティ分析機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "セキュリティ分析機能は開発中です" "Warning"
                    }
                    "Yearly" {
                        Write-GuiLog "年次レポートを生成します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("年次レポート機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "年次レポート機能は開発中です" "Warning"
                    }
                    "UsageAnalysis" {
                        Write-GuiLog "使用状況分析を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("使用状況分析機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "使用状況分析機能は開発中です" "Warning"
                    }
                    "PerformanceMonitor" {
                        Write-GuiLog "パフォーマンス監視を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("パフォーマンス監視機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "パフォーマンス監視機能は開発中です" "Warning"
                    }
                    "ConfigManagement" {
                        Write-GuiLog "設定管理を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("設定管理機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "設定管理機能は開発中です" "Warning"
                    }
                    "LogViewer" {
                        Write-GuiLog "ログビューアを開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("ログビューア機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "ログビューア機能は開発中です" "Warning"
                    }
                    "ExchangeMailboxMonitor" {
                        Write-GuiLog "Exchange メールボックス監視を開始します..." "Info"
                        
                        # サンプルメールボックスデータ
                        $mailboxData = @(
                            [PSCustomObject]@{
                                ユーザー名 = "user001@company.com"
                                メールボックスサイズ = "4.2 GB"
                                使用率 = "84.0%"
                                最終ログイン = (Get-Date).AddHours(-2).ToString("yyyy-MM-dd HH:mm")
                                状態 = "正常"
                                警告 = ""
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user002@company.com"
                                メールボックスサイズ = "4.8 GB"
                                使用率 = "96.0%"
                                最終ログイン = (Get-Date).AddHours(-1).ToString("yyyy-MM-dd HH:mm")
                                状態 = "警告"
                                警告 = "容量不足"
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user003@company.com"
                                メールボックスサイズ = "2.1 GB"
                                使用率 = "42.0%"
                                最終ログイン = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd HH:mm")
                                状態 = "注意"
                                警告 = "長期未ログイン"
                            }
                        )
                        
                        # 簡素化されたExchangeメールボックス監視出力
                        try {
                            $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path $PSScriptRoot -Parent }
                            if (-not $toolRoot) { $toolRoot = Split-Path $PSCommandPath -Parent }
                            if (-not $toolRoot) { $toolRoot = Get-Location }
                            
                            $outputFolder = Join-Path $toolRoot "Reports\Exchange\Mailbox"
                            if (-not (Test-Path $outputFolder)) {
                                New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
                            }
                            
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $csvPath = Join-Path $outputFolder "Exchangeメールボックス監視_${timestamp}.csv"
                            $htmlPath = Join-Path $outputFolder "Exchangeメールボックス監視_${timestamp}.html"
                            
                            $mailboxData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                            
                            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>Exchangeメールボックス監視</title></head>
<body>
<h1>Exchangeメールボックス監視</h1>
<p>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
<table border="1">
<tr><th>ユーザー名</th><th>メールボックスサイズ</th><th>使用率</th><th>最終ログイン</th><th>状態</th><th>警告</th></tr>
"@
                            foreach ($item in $mailboxData) {
                                $htmlContent += "<tr><td>$($item.ユーザー名)</td><td>$($item.メールボックスサイズ)</td><td>$($item.使用率)</td><td>$($item.最終ログイン)</td><td>$($item.状態)</td><td>$($item.警告)</td></tr>"
                            }
                            $htmlContent += "</table></body></html>"
                            
                            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
                            
                            $exportResult = @{ CSVPath = $csvPath; HTMLPath = $htmlPath; Success = $true }
                        }
                        catch {
                            $exportResult = @{ Success = $false; Error = $_.Exception.Message }
                        }
                        
                        if ($exportResult.Success) {
                            Write-GuiLog "Exchangeメールボックス監視レポートを出力しました" "Success"
                            [System.Windows.Forms.MessageBox]::Show("Exchangeメールボックス監視が完了しました。`n`nレポートファイル:`n・CSV: $(Split-Path $exportResult.CSVPath -Leaf)`n・HTML: $(Split-Path $exportResult.HTMLPath -Leaf)", "メールボックス監視完了", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        } else {
                            Write-GuiLog "Exchangeメールボックス監視出力エラー: $($exportResult.Error)" "Error"
                        }
                    }
                    "ExchangeMailFlow" {
                        Write-GuiLog "Exchange メールフロー分析を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("Exchange メールフロー分析機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Exchange メールフロー分析機能は開発中です" "Warning"
                    }
                    "ExchangeAntiSpam" {
                        Write-GuiLog "Exchange スパム対策分析を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("Exchange スパム対策分析機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Exchange スパム対策分析機能は開発中です" "Warning"
                    }
                    "ExchangeDeliveryReport" {
                        Write-GuiLog "Exchange 配信レポートを開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("Exchange 配信レポート機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Exchange 配信レポート機能は開発中です" "Warning"
                    }
                    "TeamsUsage" {
                        Write-GuiLog "Teams 利用状況分析を開始します..." "Info"
                        Write-GuiLog "※ Teams機能は管理者確認待ちのため、ダミーデータを表示します" "Warning"
                        
                        $dummyData = @"
Teams 利用状況分析 (ダミーデータ)
=============================================

総ユーザー数: 1,234名
アクティブユーザー数 (過去30日): 987名
チーム数: 145個
チャネル数: 678個

月間メッセージ数: 45,678件
月間通話時間: 2,345時間
月間会議数: 892回

※ このデータは管理者の確認が取れるまでダミー表示です
"@
                        [System.Windows.Forms.MessageBox]::Show($dummyData, "Teams 利用状況分析 (ダミーデータ)", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Teams利用状況分析（ダミーデータ）を表示しました" "Info"
                    }
                    "TeamsMeetingQuality" {
                        Write-GuiLog "Teams 会議品質分析を開始します..." "Info"
                        Write-GuiLog "※ Teams機能は管理者確認待ちのため、ダミーデータを表示します" "Warning"
                        
                        $dummyData = @"
Teams 会議品質分析 (ダミーデータ)
=============================================

会議品質スコア: 4.2/5.0
音声品質: 良好 (98.5%)
ビデオ品質: 良好 (96.2%)
画面共有品質: 良好 (99.1%)

接続問題発生率: 1.8%
平均遅延: 45ms
パケット損失率: 0.02%

※ このデータは管理者の確認が取れるまでダミー表示です
"@
                        [System.Windows.Forms.MessageBox]::Show($dummyData, "Teams 会議品質分析 (ダミーデータ)", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Teams会議品質分析（ダミーデータ）を表示しました" "Info"
                    }
                    "TeamsExternalAccess" {
                        Write-GuiLog "Teams 外部アクセス監視を開始します..." "Info"
                        Write-GuiLog "※ Teams機能は管理者確認待ちのため、ダミーデータを表示します" "Warning"
                        
                        $dummyData = @"
Teams 外部アクセス監視 (ダミーデータ)
=============================================

ゲストユーザー数: 56名
外部組織との通信: 23社
外部共有チーム数: 12個

今月の外部アクセス数: 234回
外部会議参加数: 78回
外部ファイル共有数: 145件

※ このデータは管理者の確認が取れるまでダミー表示です
"@
                        [System.Windows.Forms.MessageBox]::Show($dummyData, "Teams 外部アクセス監視 (ダミーデータ)", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Teams外部アクセス監視（ダミーデータ）を表示しました" "Info"
                    }
                    "TeamsAppsUsage" {
                        Write-GuiLog "Teams アプリ利用状況分析を開始します..." "Info"
                        Write-GuiLog "※ Teams機能は管理者確認待ちのため、ダミーデータを表示します" "Warning"
                        
                        $dummyData = @"
Teams アプリ利用状況 (ダミーデータ)
=============================================

インストール済みアプリ数: 28個
アクティブアプリ数: 19個

よく使用されるアプリ:
1. Planner (利用率: 78%)
2. OneNote (利用率: 65%)
3. Forms (利用率: 52%)
4. SharePoint (利用率: 45%)
5. Power BI (利用率: 23%)

※ このデータは管理者の確認が取れるまでダミー表示です
"@
                        [System.Windows.Forms.MessageBox]::Show($dummyData, "Teams アプリ利用状況 (ダミーデータ)", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Teamsアプリ利用状況（ダミーデータ）を表示しました" "Info"
                    }
                    "OneDriveStorage" {
                        Write-GuiLog "OneDrive ストレージ利用状況分析を開始します..." "Info"
                        
                        # サンプルOneDriveデータ
                        $oneDriveData = @(
                            [PSCustomObject]@{
                                ユーザー名 = "user001@company.com"
                                使用容量 = "892 MB"
                                利用率 = "8.9%"
                                ファイル数 = "1,234"
                                最終同期 = (Get-Date).AddMinutes(-15).ToString("yyyy-MM-dd HH:mm")
                                状態 = "正常"
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user002@company.com"
                                使用容量 = "9.2 GB"
                                利用率 = "92.0%"
                                ファイル数 = "4,567"
                                最終同期 = (Get-Date).AddMinutes(-30).ToString("yyyy-MM-dd HH:mm")
                                状態 = "警告"
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user003@company.com"
                                使用容量 = "3.4 GB"
                                利用率 = "34.0%"
                                ファイル数 = "890"
                                最終同期 = (Get-Date).AddHours(-2).ToString("yyyy-MM-dd HH:mm")
                                状態 = "正常"
                            }
                        )
                        
                        # 簡素化されたOneDriveストレージ分析出力
                        try {
                            $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path $PSScriptRoot -Parent }
                            if (-not $toolRoot) { $toolRoot = Split-Path $PSCommandPath -Parent }
                            if (-not $toolRoot) { $toolRoot = Get-Location }
                            
                            $outputFolder = Join-Path $toolRoot "Reports\OneDrive\Storage"
                            if (-not (Test-Path $outputFolder)) {
                                New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
                            }
                            
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $csvPath = Join-Path $outputFolder "OneDriveストレージ利用状況_${timestamp}.csv"
                            $htmlPath = Join-Path $outputFolder "OneDriveストレージ利用状況_${timestamp}.html"
                            
                            $oneDriveData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                            
                            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>OneDriveストレージ利用状況</title></head>
<body>
<h1>OneDriveストレージ利用状況</h1>
<p>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
<table border="1">
<tr><th>ユーザー名</th><th>使用容量</th><th>利用率</th><th>ファイル数</th><th>最終同期</th><th>状態</th></tr>
"@
                            foreach ($item in $oneDriveData) {
                                $htmlContent += "<tr><td>$($item.ユーザー名)</td><td>$($item.使用容量)</td><td>$($item.利用率)</td><td>$($item.ファイル数)</td><td>$($item.最終同期)</td><td>$($item.状態)</td></tr>"
                            }
                            $htmlContent += "</table></body></html>"
                            
                            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
                            
                            $exportResult = @{ CSVPath = $csvPath; HTMLPath = $htmlPath; Success = $true }
                        }
                        catch {
                            $exportResult = @{ Success = $false; Error = $_.Exception.Message }
                        }
                        
                        if ($exportResult.Success) {
                            Write-GuiLog "OneDriveストレージ分析レポートを出力しました" "Success"
                            [System.Windows.Forms.MessageBox]::Show("OneDriveストレージ分析が完了しました。`n`nレポートファイル:`n・CSV: $(Split-Path $exportResult.CSVPath -Leaf)`n・HTML: $(Split-Path $exportResult.HTMLPath -Leaf)", "OneDrive分析完了", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        } else {
                            Write-GuiLog "OneDriveストレージ分析出力エラー: $($exportResult.Error)" "Error"
                        }
                    }
                    "OneDriveSharing" {
                        Write-GuiLog "OneDrive 共有ファイル監視を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("OneDrive 共有ファイル監視機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "OneDrive 共有ファイル監視機能は開発中です" "Warning"
                    }
                    "OneDriveSyncErrors" {
                        Write-GuiLog "OneDrive 同期エラー分析を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("OneDrive 同期エラー分析機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "OneDrive 同期エラー分析機能は開発中です" "Warning"
                    }
                    "OneDriveExternalSharing" {
                        Write-GuiLog "OneDrive 外部共有レポートを開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("OneDrive 外部共有レポート機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "OneDrive 外部共有レポート機能は開発中です" "Warning"
                    }
                    "EntraIdUserMonitor" {
                        Write-GuiLog "Entra ID ユーザー監視を開始します..." "Info"
                        
                        # サンプルEntra IDユーザーデータ
                        $entraUserData = @(
                            [PSCustomObject]@{
                                ユーザー名 = "user001@company.com"
                                表示名 = "田中 太郎"
                                部署 = "営業部"
                                MFA状態 = "有効"
                                最終ログイン = (Get-Date).AddHours(-1).ToString("yyyy-MM-dd HH:mm")
                                アカウント状態 = "有効"
                                リスク = "低"
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user002@company.com"
                                表示名 = "佐藤 花子"
                                部署 = "人事部"
                                MFA状態 = "無効"
                                最終ログイン = (Get-Date).AddDays(-3).ToString("yyyy-MM-dd HH:mm")
                                アカウント状態 = "有効"
                                リスク = "中"
                            },
                            [PSCustomObject]@{
                                ユーザー名 = "user003@company.com"
                                表示名 = "山田 次郎"
                                部署 = "IT部"
                                MFA状態 = "有効"
                                最終ログイン = (Get-Date).AddMinutes(-30).ToString("yyyy-MM-dd HH:mm")
                                アカウント状態 = "有効"
                                リスク = "低"
                            }
                        )
                        
                        # 簡素化されたEntra IDユーザー監視出力
                        try {
                            $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path $PSScriptRoot -Parent }
                            if (-not $toolRoot) { $toolRoot = Split-Path $PSCommandPath -Parent }
                            if (-not $toolRoot) { $toolRoot = Get-Location }
                            
                            $outputFolder = Join-Path $toolRoot "Reports\EntraID\Users"
                            if (-not (Test-Path $outputFolder)) {
                                New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
                            }
                            
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $csvPath = Join-Path $outputFolder "EntraIDユーザー監視_${timestamp}.csv"
                            $htmlPath = Join-Path $outputFolder "EntraIDユーザー監視_${timestamp}.html"
                            
                            $entraUserData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                            
                            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>EntraIDユーザー監視</title></head>
<body>
<h1>EntraIDユーザー監視</h1>
<p>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
<table border="1">
<tr><th>ユーザー名</th><th>表示名</th><th>部署</th><th>MFA状態</th><th>最終ログイン</th><th>アカウント状態</th><th>リスク</th></tr>
"@
                            foreach ($item in $entraUserData) {
                                $htmlContent += "<tr><td>$($item.ユーザー名)</td><td>$($item.表示名)</td><td>$($item.部署)</td><td>$($item.MFA状態)</td><td>$($item.最終ログイン)</td><td>$($item.アカウント状態)</td><td>$($item.リスク)</td></tr>"
                            }
                            $htmlContent += "</table></body></html>"
                            
                            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
                            
                            $exportResult = @{ CSVPath = $csvPath; HTMLPath = $htmlPath; Success = $true }
                        }
                        catch {
                            $exportResult = @{ Success = $false; Error = $_.Exception.Message }
                        }
                        
                        if ($exportResult.Success) {
                            Write-GuiLog "Entra IDユーザー監視レポートを出力しました" "Success"
                            [System.Windows.Forms.MessageBox]::Show("Entra IDユーザー監視が完了しました。`n`nレポートファイル:`n・CSV: $(Split-Path $exportResult.CSVPath -Leaf)`n・HTML: $(Split-Path $exportResult.HTMLPath -Leaf)", "ユーザー監視完了", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        } else {
                            Write-GuiLog "Entra IDユーザー監視出力エラー: $($exportResult.Error)" "Error"
                        }
                    }
                    "EntraIdSignInLogs" {
                        Write-GuiLog "Entra ID サインインログ分析を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("Entra ID サインインログ分析機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Entra ID サインインログ分析機能は開発中です" "Warning"
                    }
                    "EntraIdConditionalAccess" {
                        Write-GuiLog "Entra ID 条件付きアクセス分析を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("Entra ID 条件付きアクセス分析機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Entra ID 条件付きアクセス分析機能は開発中です" "Warning"
                    }
                    "EntraIdMFA" {
                        Write-GuiLog "Entra ID MFA状況確認を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("Entra ID MFA状況確認機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Entra ID MFA状況確認機能は開発中です" "Warning"
                    }
                    "EntraIdAppRegistrations" {
                        Write-GuiLog "Entra ID アプリ登録監視を開始します..." "Info"
                        [System.Windows.Forms.MessageBox]::Show("Entra ID アプリ登録監視機能は開発中です", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        Write-GuiLog "Entra ID アプリ登録監視機能は開発中です" "Warning"
                    }
                    default { 
                        Write-Host "不明なアクション: '$buttonAction'" -ForegroundColor Red
                        $errorMsg = "不明なアクション: '$buttonAction'"
                        if ($Script:LogTextBox) {
                            $timestamp = Get-Date -Format "HH:mm:ss"
                            $Script:LogTextBox.Invoke([Action[string]]{
                                param($msg)
                                $Script:LogTextBox.AppendText("[$timestamp] [Warning] $msg`r`n")
                                $Script:LogTextBox.ScrollToCaret()
                            }, $errorMsg)
                        }
                    }
                }
                
                Write-Host "switch文実行完了: $buttonAction" -ForegroundColor Cyan
            }
            catch {
                # 詳細なエラー情報
                $errorDetails = @{
                    Message = $_.Exception.Message
                    Type = $_.Exception.GetType().FullName
                    StackTrace = $_.ScriptStackTrace
                    ButtonAction = $buttonAction
                    ButtonText = $buttonText
                }
                
                $errorMessage = "ボタン処理エラー ($buttonText): $($errorDetails.Message)"
                $detailedError = @"
エラー詳細:
- ボタン: $($errorDetails.ButtonText) ($($errorDetails.ButtonAction))
- エラータイプ: $($errorDetails.Type)
- メッセージ: $($errorDetails.Message)
- スタックトレース: $($errorDetails.StackTrace)
"@
                
                # エラーログ出力（詳細情報付き）
                if ($Script:LogTextBox) {
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    $Script:LogTextBox.Invoke([Action[string]]{
                        param($msg)
                        $Script:LogTextBox.AppendText("[$timestamp] [Error] $msg`r`n")
                        $Script:LogTextBox.ScrollToCaret()
                    }, $errorMessage)
                    
                    # 詳細ログも追加
                    $Script:LogTextBox.Invoke([Action[string]]{
                        param($msg)
                        $Script:LogTextBox.AppendText("$msg`r`n")
                        $Script:LogTextBox.ScrollToCaret()
                    }, $detailedError)
                }
                
                # コンソールにも出力
                Write-Host $errorMessage -ForegroundColor Red
                Write-Host $detailedError -ForegroundColor Yellow
                
                [System.Windows.Forms.MessageBox]::Show(
                    "エラーが発生しました:`n$($_.Exception.Message)`n`n詳細は実行ログを確認してください。",
                    "エラー",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }.GetNewClosure())
        
        return $button
    }
    
    # アコーディオンセクション作成
    $currentY = 10
    
    # 認証・セキュリティセクション
    $authSection = New-AccordionSection -Title "認証・セキュリティ" -Buttons @(
        @{ Text = "認証テスト"; Action = "Auth" },
        @{ Text = "権限監査"; Action = "PermissionAudit" },
        @{ Text = "セキュリティ分析"; Action = "SecurityAnalysis" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($authSection)
    $currentY += $authSection.Height + 5
    
    # レポート管理セクション
    $reportSection = New-AccordionSection -Title "レポート管理" -Buttons @(
        @{ Text = "日次レポート"; Action = "Daily" },
        @{ Text = "週次レポート"; Action = "Weekly" },
        @{ Text = "月次レポート"; Action = "Monthly" },
        @{ Text = "年次レポート"; Action = "Yearly" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($reportSection)
    $currentY += $reportSection.Height + 5
    
    # 分析・監視セクション
    $analysisSection = New-AccordionSection -Title "分析・監視" -Buttons @(
        @{ Text = "ライセンス分析"; Action = "License" },
        @{ Text = "使用状況分析"; Action = "UsageAnalysis" },
        @{ Text = "パフォーマンス監視"; Action = "PerformanceMonitor" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($analysisSection)
    $currentY += $analysisSection.Height + 5
    
    # ツール・ユーティリティセクション
    $toolsSection = New-AccordionSection -Title "ツール・ユーティリティ" -Buttons @(
        @{ Text = "レポートを開く"; Action = "OpenReports" },
        @{ Text = "設定管理"; Action = "ConfigManagement" },
        @{ Text = "ログビューア"; Action = "LogViewer" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($toolsSection)
    $currentY += $toolsSection.Height + 5
    
    # Exchange Online管理セクション
    $exchangeSection = New-AccordionSection -Title "Exchange Online" -Buttons @(
        @{ Text = "メールボックス監視"; Action = "ExchangeMailboxMonitor" },
        @{ Text = "メールフロー分析"; Action = "ExchangeMailFlow" },
        @{ Text = "スパム対策"; Action = "ExchangeAntiSpam" },
        @{ Text = "配信レポート"; Action = "ExchangeDeliveryReport" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($exchangeSection)
    $currentY += $exchangeSection.Height + 5
    
    # Microsoft Teams管理セクション
    $teamsSection = New-AccordionSection -Title "Microsoft Teams" -Buttons @(
        @{ Text = "チーム利用状況"; Action = "TeamsUsage" },
        @{ Text = "会議品質分析"; Action = "TeamsMeetingQuality" },
        @{ Text = "外部アクセス監視"; Action = "TeamsExternalAccess" },
        @{ Text = "アプリ利用状況"; Action = "TeamsAppsUsage" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($teamsSection)
    $currentY += $teamsSection.Height + 5
    
    # OneDrive管理セクション
    $oneDriveSection = New-AccordionSection -Title "OneDrive" -Buttons @(
        @{ Text = "ストレージ利用状況"; Action = "OneDriveStorage" },
        @{ Text = "共有ファイル監視"; Action = "OneDriveSharing" },
        @{ Text = "同期エラー分析"; Action = "OneDriveSyncErrors" },
        @{ Text = "外部共有レポート"; Action = "OneDriveExternalSharing" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($oneDriveSection)
    $currentY += $oneDriveSection.Height + 5
    
    # Entra ID管理セクション
    $entraIdSection = New-AccordionSection -Title "Entra ID (Azure AD)" -Buttons @(
        @{ Text = "ユーザー監視"; Action = "EntraIdUserMonitor" },
        @{ Text = "サインインログ分析"; Action = "EntraIdSignInLogs" },
        @{ Text = "条件付きアクセス"; Action = "EntraIdConditionalAccess" },
        @{ Text = "MFA状況確認"; Action = "EntraIdMFA" },
        @{ Text = "アプリ登録監視"; Action = "EntraIdAppRegistrations" }
    ) -YPosition $currentY
    $buttonPanel.Controls.Add($entraIdSection)
    $currentY += $entraIdSection.Height + 5
    
    
    # ログ表示エリア
    Write-Host "New-MainForm: ログ表示エリア作成開始" -ForegroundColor Cyan
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $logPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    
    $logLabel = New-Object System.Windows.Forms.Label
    $logLabel.Text = "実行ログ:"
    $logLabel.Dock = [System.Windows.Forms.DockStyle]::Top
    $logLabel.Height = 20
    $logLabel.Font = New-Object System.Drawing.Font("MS Gothic", 9, [System.Drawing.FontStyle]::Bold)
    
    Write-Host "New-MainForm: LogTextBox作成開始" -ForegroundColor Cyan
    $Script:LogTextBox = New-Object System.Windows.Forms.TextBox
    $Global:GuiLogTextBox = $Script:LogTextBox  # グローバル参照も設定
    Write-Host "New-MainForm: LogTextBox作成完了" -ForegroundColor Green
    $Script:LogTextBox.Multiline = $true
    $Script:LogTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $Script:LogTextBox.ReadOnly = $true
    $Script:LogTextBox.BackColor = [System.Drawing.Color]::Black
    $Script:LogTextBox.ForeColor = [System.Drawing.Color]::White
    $Script:LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $Script:LogTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    Write-Host "New-MainForm: LogTextBoxプロパティ設定完了" -ForegroundColor Green
    
    $logPanel.Controls.Add($logLabel)
    $logPanel.Controls.Add($Script:LogTextBox)
    Write-Host "New-MainForm: ログ表示エリア完了" -ForegroundColor Cyan
    
    # ステータスバー
    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $statusPanel.BackColor = [System.Drawing.Color]::LightGray
    
    $Script:StatusLabel = New-Object System.Windows.Forms.Label
    $Global:GuiStatusLabel = $Script:StatusLabel  # グローバル参照も設定
    $Script:StatusLabel.Text = "準備完了"
    $Script:StatusLabel.Dock = [System.Windows.Forms.DockStyle]::Left
    $Script:StatusLabel.Width = 300
    $Script:StatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $Script:StatusLabel.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    
    $Script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $Script:ProgressBar.Dock = [System.Windows.Forms.DockStyle]::Right
    $Script:ProgressBar.Width = 200
    $Script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $Script:ProgressBar.Margin = New-Object System.Windows.Forms.Padding(0, 5, 10, 5)
    
    $statusPanel.Controls.Add($Script:StatusLabel)
    $statusPanel.Controls.Add($Script:ProgressBar)
    
    # パネルをフォームに追加
    $mainPanel.Controls.Add($headerPanel, 0, 0)
    $mainPanel.Controls.Add($buttonPanel, 0, 1)
    $mainPanel.Controls.Add($logPanel, 0, 2)
    $mainPanel.Controls.Add($statusPanel, 0, 3)
    
        $form.Controls.Add($mainPanel)
        
        # LogTextBox最終確認
        Write-Host "New-MainForm完了: LogTextBox = $($Script:LogTextBox -ne $null)" -ForegroundColor Green
        
        return $form
    }
    catch {
        Write-Error "New-MainForm関数でエラーが発生しました: $($_.Exception.Message)"
        throw
    }
}

# アプリケーション初期化
function Initialize-GuiApp {
    try {
        # LogTextBox確認
        Write-Host "Initialize-GuiApp: LogTextBox確認開始" -ForegroundColor Magenta
        if ($Script:LogTextBox) {
            Write-Host "Initialize-GuiApp: LogTextBox存在確認 - OK" -ForegroundColor Green
        } else {
            Write-Host "Initialize-GuiApp: LogTextBox存在確認 - NG (null)" -ForegroundColor Red
        }
        
        Write-SafeGuiLog "Microsoft 365統合管理ツール GUI版を起動しています..." -Level Info
        Write-SafeGuiLog "PowerShell バージョン: $($PSVersionTable.PSVersion)" -Level Info
        Write-SafeGuiLog "実行ポリシー: $(Get-ExecutionPolicy)" -Level Info
        
        # 設定ファイル確認
        $configPath = Join-Path $Script:ToolRoot "Config\appsettings.json"
        if (Test-Path $configPath) {
            Write-SafeGuiLog "設定ファイルが見つかりました: $configPath" -Level Success
        } else {
            Write-SafeGuiLog "設定ファイルが見つかりません: $configPath" -Level Warning
        }
        
        # レポートフォルダ構造の初期化
        $reportsPath = Join-Path $Script:ToolRoot "Reports"
        Write-SafeGuiLog "レポートフォルダ構造を初期化しています..." -Level Info
        Initialize-ReportFolders -BaseReportsPath $reportsPath
        Write-SafeGuiLog "レポートフォルダ構造の初期化が完了しました" -Level Success
        
        Write-SafeGuiLog "GUI初期化完了。操作ボタンをクリックして機能をご利用ください。" -Level Success
        Update-Status "準備完了 - ボタンをクリックして開始してください"
    }
    catch {
        Write-SafeGuiLog "GUI初期化中にエラーが発生しました: $($_.Exception.Message)" -Level Error
        Update-Status "初期化エラー"
    }
}

# メイン実行
function Main {
    try {
        # Windows Forms初期設定を最初に実行
        Initialize-WindowsForms
        
        # 必要なモジュールを読み込み
        Import-RequiredModules
        
        # モジュール読み込みエラーチェック
        if ($Script:ModuleLoadError) {
            [System.Windows.Forms.MessageBox]::Show(
                "必要なモジュールの読み込みに失敗しました:`n$Script:ModuleLoadError",
                "警告",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
        
        # メインフォーム作成
        Write-Host "Main: フォーム作成開始" -ForegroundColor Magenta
        try {
            $formResult = New-MainForm
            Write-Host "Main: New-MainForm関数呼び出し完了" -ForegroundColor Magenta
            
            # 配列の場合は最後の要素を取得
            if ($formResult -is [System.Array]) {
                $Script:Form = $formResult[-1]
                Write-Host "配列から最後の要素を取得: $($Script:Form.GetType().FullName)" -ForegroundColor Yellow
            } else {
                $Script:Form = $formResult
                Write-Host "直接フォームを取得: $($Script:Form.GetType().FullName)" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "フォーム作成中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
        
        # フォーム作成結果の検証
        if ($Script:Form -isnot [System.Windows.Forms.Form]) {
            throw "フォーム作成に失敗しました。戻り値の型: $($Script:Form.GetType().FullName)"
        }
        
        # フォーム表示イベント
        $Script:Form.Add_Shown({
            Initialize-GuiApp
        })
        
        # フォーム終了イベント
        $Script:Form.Add_FormClosing({
            param($formSender, $e)
            Write-SafeGuiLog "Microsoft 365統合管理ツール GUI版を終了します" -Level Info
        })
        
        # アプリケーション実行
        [System.Windows.Forms.Application]::Run($Script:Form)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "アプリケーション起動エラー:`n$($_.Exception.Message)",
            "エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
}

# 実行開始
if ($PSVersionTable.PSVersion -lt [Version]"7.0.0") {
    Write-Host "エラー: このGUIアプリケーションはPowerShell 7.0以上が必要です。" -ForegroundColor Red
    Write-Host "現在のバージョン: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "PowerShell 7以上をインストールしてから再実行してください。" -ForegroundColor Green
    exit 1
}

Main