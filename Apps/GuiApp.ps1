# ================================================================================
# Microsoft 365統合管理ツール - GUI拡張版
# GuiApp-Enhanced.ps1
# 豊富なメニューとダミーデータ対応のWindows Forms GUIアプリケーション
# ================================================================================

[CmdletBinding()]
param()

# STAモードチェック
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "警告: このスクリプトはSTAモードで実行する必要があります。" -ForegroundColor Yellow
    Write-Host "再起動します..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList "-sta", "-File", $MyInvocation.MyCommand.Path -NoNewWindow -Wait
    exit
}

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
    exit 1
}

# Windows Forms設定フラグ
$Script:FormsConfigured = $false

# Windows Forms初期設定関数
function Initialize-WindowsForms {
    if (-not $Script:FormsConfigured) {
        try {
            [System.Windows.Forms.Application]::EnableVisualStyles()
            [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
            $Script:FormsConfigured = $true
            Write-Host "Windows Forms設定完了" -ForegroundColor Green
        }
        catch {
            Write-Host "警告: Windows Forms設定に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# グローバル変数
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent

# 共通モジュールをインポート
$modulePath = Join-Path $Script:ToolRoot "Scripts\Common"
Import-Module "$modulePath\GuiReportFunctions.psm1" -Force -ErrorAction SilentlyContinue

# ダミーデータ生成機能（拡張版）
function New-DummyData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataType,
        
        [Parameter(Mandatory = $false)]
        [int]$RecordCount = 50
    )
    
    $dummyData = @()
    $userNames = @("田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一", "伊藤光子", "山田和也", "中村真理", "小林秀樹", "加藤明美")
    $departments = @("営業部", "開発部", "総務部", "人事部", "経理部", "マーケティング部", "システム部")
    
    switch ($DataType) {
        "Daily" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    日付 = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    ログイン失敗数 = Get-Random -Minimum 0 -Maximum 20
                    総ログイン数 = Get-Random -Minimum 100 -Maximum 500
                    新規ユーザー数 = Get-Random -Minimum 0 -Maximum 5
                    ストレージ使用率 = Get-Random -Minimum 50 -Maximum 95
                    メールボックス数 = Get-Random -Minimum 180 -Maximum 220
                    OneDrive使用率 = Get-Random -Minimum 60 -Maximum 90
                    Teamsアクティブユーザー = Get-Random -Minimum 150 -Maximum 200
                    ステータス = @("正常", "警告", "注意")[(Get-Random -Maximum 3)]
                }
            }
        }
        "Weekly" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    週 = "第${i}週"
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    MFA有効ユーザー = Get-Random -Minimum 150 -Maximum 200
                    MFA無効ユーザー = Get-Random -Minimum 10 -Maximum 30
                    外部共有件数 = Get-Random -Minimum 5 -Maximum 25
                    作成グループ数 = Get-Random -Minimum 0 -Maximum 8
                    削除グループ数 = Get-Random -Minimum 0 -Maximum 3
                    ライセンス変更数 = Get-Random -Minimum 0 -Maximum 15
                    セキュリティアラート = Get-Random -Minimum 0 -Maximum 5
                    コンプライアンススコア = Get-Random -Minimum 75 -Maximum 95
                }
            }
        }
        "Monthly" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    月 = (Get-Date).AddMonths(-$i).ToString("yyyy-MM")
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    アクティブユーザー数 = Get-Random -Minimum 180 -Maximum 220
                    ライセンス利用率 = Get-Random -Minimum 80 -Maximum 95
                    ストレージ増加率 = Get-Random -Minimum -5 -Maximum 15
                    Exchangeメールボックス = Get-Random -Minimum 190 -Maximum 210
                    Teams利用率 = Get-Random -Minimum 70 -Maximum 90
                    OneDrive普及率 = Get-Random -Minimum 85 -Maximum 95
                    セキュリティインシデント = Get-Random -Minimum 0 -Maximum 10
                    月額コスト = Get-Random -Minimum 8000 -Maximum 12000
                }
            }
        }
        "Yearly" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    年 = (Get-Date).AddYears(-$i).ToString("yyyy")
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    年間アクティブユーザー = Get-Random -Minimum 200 -Maximum 250
                    年間ライセンス消費 = Get-Random -Minimum 2000000 -Maximum 5000000
                    年間セキュリティインシデント = Get-Random -Minimum 5 -Maximum 50
                    年間ストレージ使用量 = Get-Random -Minimum 500 -Maximum 2000
                    コンプライアンス達成率 = Get-Random -Minimum 85 -Maximum 100
                    年間コスト削減額 = Get-Random -Minimum 100000 -Maximum 1000000
                }
            }
        }
        "License" {
            $licenseTypes = @("Microsoft 365 E3", "Microsoft 365 E5", "Office 365 E1", "Teams Essentials", "Exchange Online Plan 1", "Power BI Pro", "Project Plan 3")
            for ($i = 0; $i -lt $licenseTypes.Count; $i++) {
                $dummyData += [PSCustomObject]@{
                    ライセンス種別 = $licenseTypes[$i]
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    総ライセンス数 = Get-Random -Minimum 50 -Maximum 100
                    割当済ライセンス = Get-Random -Minimum 30 -Maximum 95
                    利用可能ライセンス = Get-Random -Minimum 5 -Maximum 20
                    利用率 = [math]::Round((Get-Random -Minimum 60 -Maximum 95), 1)
                    月額コスト = Get-Random -Minimum 500 -Maximum 3000
                    有効期限 = (Get-Date).AddMonths((Get-Random -Minimum 1 -Maximum 12)).ToString("yyyy-MM-dd")
                }
            }
        }
        "UsageAnalysis" {
            $services = @("Exchange Online", "SharePoint Online", "Teams", "OneDrive", "Power BI", "Power Apps", "Word Online", "Excel Online", "PowerPoint Online")
            for ($i = 0; $i -lt $services.Count; $i++) {
                $dummyData += [PSCustomObject]@{
                    サービス名 = $services[$i]
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    アクティブユーザー数 = Get-Random -Minimum 50 -Maximum 200
                    総ユーザー数 = Get-Random -Minimum 180 -Maximum 220
                    普及率 = [math]::Round((Get-Random -Minimum 60 -Maximum 95), 1)
                    日次アクティブユーザー = Get-Random -Minimum 40 -Maximum 180
                    週次アクティブユーザー = Get-Random -Minimum 120 -Maximum 200
                    月次アクティブユーザー = Get-Random -Minimum 150 -Maximum 210
                    傾向 = @("上昇", "安定", "下降")[(Get-Random -Maximum 3)]
                }
            }
        }
        "PerformanceMonitor" {
            $metrics = @("CPU使用率", "メモリ使用率", "ネットワーク遅延", "ディスクI/O", "レスポンス時間", "可用性")
            for ($i = 0; $i -lt $metrics.Count; $i++) {
                $dummyData += [PSCustomObject]@{
                    メトリクス名 = $metrics[$i]
                    測定時刻 = (Get-Date).AddHours(-$i).ToString("yyyy-MM-dd HH:mm:ss")
                    現在値 = Get-Random -Minimum 10 -Maximum 90
                    平均値 = Get-Random -Minimum 20 -Maximum 70
                    最大値 = Get-Random -Minimum 70 -Maximum 100
                    最小値 = Get-Random -Minimum 5 -Maximum 30
                    閾値 = Get-Random -Minimum 80 -Maximum 95
                    ステータス = @("正常", "警告", "危険")[(Get-Random -Maximum 3)]
                    アラート数 = Get-Random -Minimum 0 -Maximum 5
                }
            }
        }
        "SecurityAnalysis" {
            $securityItems = @("外部共有ファイル", "不審なログイン", "権限昇格", "データ漏洩リスク", "マルウェア検出", "フィッシング試行")
            for ($i = 0; $i -lt $securityItems.Count; $i++) {
                $dummyData += [PSCustomObject]@{
                    セキュリティ項目 = $securityItems[$i]
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    リスクレベル = @("低", "中", "高", "重大")[(Get-Random -Maximum 4)]
                    検出日時 = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30)).ToString("yyyy-MM-dd HH:mm:ss")
                    影響範囲 = Get-Random -Minimum 1 -Maximum 50
                    対処状況 = @("未対処", "調査中", "対処済み")[(Get-Random -Maximum 3)]
                    推奨アクション = @("監視継続", "即座に対応", "ポリシー変更", "ユーザー教育")[(Get-Random -Maximum 4)]
                }
            }
        }
        "PermissionAudit" {
            $permissions = @("グローバル管理者", "ユーザー管理者", "Exchange管理者", "SharePoint管理者", "Teams管理者", "セキュリティ管理者")
            for ($i = 0; $i -lt $permissions.Count; $i++) {
                $dummyData += [PSCustomObject]@{
                    権限名 = $permissions[$i]
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    割当日 = (Get-Date).AddDays(-(Get-Random -Minimum 30 -Maximum 365)).ToString("yyyy-MM-dd")
                    最終ログイン = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30)).ToString("yyyy-MM-dd HH:mm:ss")
                    使用頻度 = @("高", "中", "低", "未使用")[(Get-Random -Maximum 4)]
                    リスク評価 = @("低", "中", "高")[(Get-Random -Maximum 3)]
                    レビュー状況 = @("レビュー済み", "要レビュー", "承認待ち")[(Get-Random -Maximum 3)]
                }
            }
        }
        "EntraIDUsers" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    表示名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    役職 = @("部長", "課長", "主任", "一般", "新入社員")[(Get-Random -Maximum 5)]
                    メールアドレス = "user$i@company.com"
                    MFA有効 = @("有効", "無効")[(Get-Random -Maximum 2)]
                    ライセンス = @("Microsoft 365 E3", "Microsoft 365 E5", "Office 365 E1")[(Get-Random -Maximum 3)]
                    最終ログイン = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30)).ToString("yyyy-MM-dd HH:mm:ss")
                    アカウント状態 = @("有効", "無効", "一時停止")[(Get-Random -Maximum 3)]
                }
            }
        }
        "ExchangeMailbox" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    メールボックス名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    メールアドレス = "user$i@company.com"
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    メールボックスサイズ = [math]::Round((Get-Random -Minimum 1.5 -Maximum 15.0), 2)
                    使用量 = Get-Random -Minimum 50 -Maximum 95
                    送信メール数 = Get-Random -Minimum 10 -Maximum 200
                    受信メール数 = Get-Random -Minimum 50 -Maximum 500
                    スパム検出数 = Get-Random -Minimum 0 -Maximum 50
                    ルール数 = Get-Random -Minimum 0 -Maximum 20
                    転送設定 = @("なし", "内部転送", "外部転送")[(Get-Random -Maximum 3)]
                }
            }
        }
        "TeamsUsage" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    チーム数 = Get-Random -Minimum 1 -Maximum 10
                    チャンネル数 = Get-Random -Minimum 5 -Maximum 50
                    メッセージ数 = Get-Random -Minimum 100 -Maximum 2000
                    会議時間 = Get-Random -Minimum 10 -Maximum 500
                    通話時間 = Get-Random -Minimum 5 -Maximum 200
                    ファイル共有数 = Get-Random -Minimum 10 -Maximum 100
                    アプリ使用数 = Get-Random -Minimum 1 -Maximum 15
                    アクティビティ = @("高", "中", "低")[(Get-Random -Maximum 3)]
                }
            }
        }
        "OneDriveStorage" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    ストレージ容量 = "1TB"
                    使用容量 = [math]::Round((Get-Random -Minimum 0.1 -Maximum 0.9), 2)
                    使用率 = Get-Random -Minimum 10 -Maximum 90
                    ファイル数 = Get-Random -Minimum 100 -Maximum 5000
                    共有ファイル数 = Get-Random -Minimum 5 -Maximum 100
                    外部共有数 = Get-Random -Minimum 0 -Maximum 20
                    同期エラー数 = Get-Random -Minimum 0 -Maximum 5
                    最終アクセス = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30)).ToString("yyyy-MM-dd")
                }
            }
        }
        default {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $dummyData += [PSCustomObject]@{
                    "項目名" = "テスト項目 $i"
                    "ユーザー名" = $userNames[(Get-Random -Maximum $userNames.Count)]
                    "部署" = $departments[(Get-Random -Maximum $departments.Count)]
                    "値" = Get-Random -Minimum 1 -Maximum 100
                    "ステータス" = @("正常", "警告", "エラー")[(Get-Random -Maximum 3)]
                    "作成日時" = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
        }
    }
    
    return $dummyData
}

# レポート出力関数（拡張版 - PDF対応）
function Export-GuiReport {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportName,
        
        [Parameter(Mandatory = $false)]
        [string]$Action = "General",
        
        [Parameter(Mandatory = $false)]
        [switch]$EnablePDF = $true
    )
    
    try {
        # 出力先ディレクトリの決定
        $reportDir = switch ($Action) {
            "Daily" { "Reports\Daily" }
            "Weekly" { "Reports\Weekly" }
            "Monthly" { "Reports\Monthly" }
            "Yearly" { "Reports\Yearly" }
            "License" { "Analysis\License" }
            "UsageAnalysis" { "Analysis\Usage" }
            "PerformanceMonitor" { "Analysis\Performance" }
            "SecurityAnalysis" { "General" }
            "PermissionAudit" { "General" }
            "EntraIDUsers" { "Reports\EntraID\Users" }
            "ExchangeMailbox" { "Reports\Exchange\Mailbox" }
            "TeamsUsage" { "Reports\Teams\Usage" }
            "OneDriveStorage" { "Reports\OneDrive\Storage" }
            default { "General" }
        }
        
        $fullReportDir = Join-Path $Script:ToolRoot $reportDir
        if (-not (Test-Path $fullReportDir)) {
            New-Item -Path $fullReportDir -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # CSV出力
        $csvPath = Join-Path $fullReportDir "${ReportName}_${timestamp}.csv"
        $Data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
        
        # HTML出力
        $htmlPath = Join-Path $fullReportDir "${ReportName}_${timestamp}.html"
        $htmlContent = New-HTMLReport -Data $Data -ReportName $ReportName
        Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
        
        # PDF生成（オプション）
        $pdfPath = $null
        $pdfGenerated = $false
        
        if ($EnablePDF) {
            try {
                # PuppeteerPDFモジュールの動的インポート
                $pdfModulePath = Join-Path $Script:ToolRoot "Scripts\Common\PuppeteerPDF.psm1"
                if (Test-Path $pdfModulePath) {
                    Import-Module $pdfModulePath -Force -ErrorAction SilentlyContinue
                    
                    $pdfPath = Join-Path $fullReportDir "${ReportName}_${timestamp}.pdf"
                    
                    # PDF生成設定
                    $pdfOptions = @{
                        format = "A4"
                        margin = @{
                            top = "20mm"
                            right = "15mm"
                            bottom = "20mm"
                            left = "15mm"
                        }
                        printBackground = $true
                        preferCSSPageSize = $false
                        displayHeaderFooter = $true
                        timeout = 30000
                        waitForNetworkIdle = $true
                    }
                    
                    Write-Host "PDF生成を開始します..." -ForegroundColor Yellow
                    $pdfResult = ConvertTo-PDFFromHTML -InputHtmlPath $htmlPath -OutputPdfPath $pdfPath -Options $pdfOptions
                    
                    if ($pdfResult.Success) {
                        Write-Host "PDF生成が完了しました: $pdfPath" -ForegroundColor Green
                        $pdfGenerated = $true
                    } else {
                        Write-Host "PDF生成に失敗しました" -ForegroundColor Red
                        $pdfPath = $null
                    }
                } else {
                    Write-Host "PuppeteerPDFモジュールが見つかりません。HTMLのみ生成します。" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "PDF生成でエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
                $pdfPath = $null
            }
        }
        
        # ファイルを開く
        if (Test-Path $csvPath) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                Start-Process $csvPath
            } else {
                Start-Process -FilePath $csvPath -UseShellExecute
            }
        }
        if (Test-Path $htmlPath) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                Start-Process $htmlPath
            } else {
                Start-Process -FilePath $htmlPath -UseShellExecute
            }
        }
        if ($pdfPath -and (Test-Path $pdfPath)) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                Start-Process $pdfPath
            } else {
                Start-Process -FilePath $pdfPath -UseShellExecute
            }
        }
        
        # ポップアップ表示
        $message = "$ReportName を生成しました！`n`nデータ件数: $($Data.Count) 件`n`nCSVファイル: $csvPath`nHTMLファイル: $htmlPath"
        if ($pdfGenerated) {
            $message += "`nPDFファイル: $pdfPath"
        }
        $message += "`n`nファイルが自動的に開かれます。"
        
        [System.Windows.Forms.MessageBox]::Show($message, "レポート生成完了", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        return @{
            Success = $true
            CsvPath = $csvPath
            HtmlPath = $htmlPath
            PdfPath = $pdfPath
            PdfGenerated = $pdfGenerated
            DataCount = $Data.Count
        }
    }
    catch {
        $errorMessage = "レポート出力エラー: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "エラー", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return @{
            Success = $false
            Error = $errorMessage
        }
    }
}

# HTML生成関数（拡張版）
function New-HTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportName
    )
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportName - Microsoft 365統合管理ツール</title>
    <style>
        body { 
            font-family: 'Yu Gothic', 'Meiryo', 'MS Gothic', sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1600px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #0078d4; 
            text-align: center; 
            margin-bottom: 10px;
        }
        .meta-info {
            text-align: center;
            color: #666;
            margin-bottom: 20px;
            font-size: 14px;
        }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin-top: 20px;
            font-size: 12px;
        }
        th, td { 
            border: 1px solid #ddd; 
            padding: 8px; 
            text-align: left;
            word-wrap: break-word;
            max-width: 150px;
        }
        th { 
            background-color: #0078d4; 
            color: white;
            font-weight: bold;
            text-align: center;
            position: sticky;
            top: 0;
        }
        tr:nth-child(even) { 
            background-color: #f9f9f9; 
        }
        tr:hover { 
            background-color: #e3f2fd; 
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>$ReportName</h1>
        <div class="meta-info">
            生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss') | データ件数: $($Data.Count) 件
        </div>
        <table>
            <thead>
                <tr>
"@
    
    # ヘッダー行
    if ($Data.Count -gt 0) {
        $headers = $Data[0].PSObject.Properties.Name
        foreach ($header in $headers) {
            $htmlContent += "<th>$header</th>"
        }
    }
    
    $htmlContent += "</tr></thead><tbody>"
    
    # データ行
    foreach ($row in $Data) {
        $htmlContent += "<tr>"
        if ($Data.Count -gt 0) {
            $headers = $Data[0].PSObject.Properties.Name
            foreach ($header in $headers) {
                $cellValue = $row.$header
                if ($null -eq $cellValue) { $cellValue = "" }
                $htmlContent += "<td>$cellValue</td>"
            }
        }
        $htmlContent += "</tr>"
    }
    
    $htmlContent += @"
        </tbody>
    </table>
    <div class="footer">
        Microsoft 365統合管理ツール - 自動生成レポート
    </div>
    </div>
</body>
</html>
"@
    
    return $htmlContent
}


# メインフォーム作成関数（拡張版）
function New-MainForm {
    try {
        Write-Host "拡張版メインフォーム作成開始..." -ForegroundColor Green
        
        # フォーム作成
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Microsoft 365統合管理ツール - 拡張版"
        $form.Size = New-Object System.Drawing.Size(1200, 800)
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $form.ShowInTaskbar = $true
        
        # ウィンドウ操作を可能にする設定
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
        $form.MaximizeBox = $true
        $form.MinimizeBox = $true
        $form.ControlBox = $true
        $form.TopMost = $false
        $form.ShowIcon = $true
        $form.KeyPreview = $false
        $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
        $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96.0, 96.0)
        $form.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Auto
        
        # 移動可能にする設定
        $form.AllowDrop = $false
        $form.IsMdiContainer = $false
        
        # フォームの表示状態を確認
        Write-Host "フォーム設定確認:" -ForegroundColor Cyan
        Write-Host "  FormBorderStyle: $($form.FormBorderStyle)" -ForegroundColor Gray
        Write-Host "  MaximizeBox: $($form.MaximizeBox)" -ForegroundColor Gray
        Write-Host "  MinimizeBox: $($form.MinimizeBox)" -ForegroundColor Gray
        Write-Host "  ControlBox: $($form.ControlBox)" -ForegroundColor Gray
        Write-Host "  TopMost: $($form.TopMost)" -ForegroundColor Gray
        Write-Host "  SizeGripStyle: $($form.SizeGripStyle)" -ForegroundColor Gray
        
        # メインパネル
        $mainPanel = New-Object System.Windows.Forms.Panel
        $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
        $mainPanel.BackColor = [System.Drawing.Color]::WhiteSmoke
        $mainPanel.AutoScroll = $true
        $mainPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        $form.Controls.Add($mainPanel)
        
        # ヘッダーラベル
        $headerLabel = New-Object System.Windows.Forms.Label
        $headerLabel.Text = "Microsoft 365統合管理ツール"
        $headerLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 20, [System.Drawing.FontStyle]::Bold)
        $headerLabel.ForeColor = [System.Drawing.Color]::DarkBlue
        $headerLabel.Location = New-Object System.Drawing.Point(50, 10)
        $headerLabel.Size = New-Object System.Drawing.Size(800, 40)
        $headerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $mainPanel.Controls.Add($headerLabel)
        
        # 説明ラベル
        $descLabel = New-Object System.Windows.Forms.Label
        $descLabel.Text = "各ボタンをクリックしてレポートを生成します。CSVとHTMLファイルが自動で開かれます。"
        $descLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
        $descLabel.Location = New-Object System.Drawing.Point(50, 50)
        $descLabel.Size = New-Object System.Drawing.Size(800, 30)
        $descLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $mainPanel.Controls.Add($descLabel)
        
        # ボタン作成関数
        function New-ActionButton {
            param([string]$Text, [string]$Action, [System.Drawing.Point]$Location)
            
            $button = New-Object System.Windows.Forms.Button
            $button.Text = $Text
            $button.Tag = $Action
            $button.Font = New-Object System.Drawing.Font("Yu Gothic UI", 9, [System.Drawing.FontStyle]::Bold)
            $button.Size = New-Object System.Drawing.Size(170, 45)
            $button.Location = $Location
            $button.BackColor = [System.Drawing.Color]::LightBlue
            $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            # イベントハンドラーをスクリプトレベルで定義
            $button.Add_Click({
                param($sender, $e)
                
                # フォームが破棄されているかチェック
                if ($sender.IsDisposed -or $sender.FindForm().IsDisposed) {
                    Write-Host "フォームは既に破棄されています" -ForegroundColor Yellow
                    return
                }
                
                $buttonText = $sender.Text
                $actionValue = $sender.Tag
                Write-Host "ボタンクリック検出: $buttonText (アクション: $actionValue)" -ForegroundColor Cyan
                
                try {
                    # GuiReportFunctions.psm1の確実なインポート
                    $guiModulePath = Join-Path $Script:ToolRoot "Scripts\Common\GuiReportFunctions.psm1"
                    if (Test-Path $guiModulePath) {
                        Import-Module $guiModulePath -Force -ErrorAction SilentlyContinue
                        Write-Host "GuiReportFunctions.psm1 インポート完了" -ForegroundColor Green
                    }
                    
                    Write-Host "ボタンアクション実行: $buttonText ($actionValue)" -ForegroundColor Cyan
                    
                    switch ($actionValue) {
                        # 定期レポート
                        "Daily" {
                            Invoke-GuiReportGeneration -ReportType "Daily" -ReportName "日次レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "Daily" -RecordCount 30
                                Export-GuiReport -Data $data -ReportName "日次レポート（サンプル）" -Action "Daily"
                            }
                        }
                        "Weekly" {
                            Invoke-GuiReportGeneration -ReportType "Weekly" -ReportName "週次レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "Weekly" -RecordCount 12
                                Export-GuiReport -Data $data -ReportName "週次レポート（サンプル）" -Action "Weekly"
                            }
                        }
                        "Monthly" {
                            Invoke-GuiReportGeneration -ReportType "Monthly" -ReportName "月次レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "Monthly" -RecordCount 12
                                Export-GuiReport -Data $data -ReportName "月次レポート（サンプル）" -Action "Monthly"
                            }
                        }
                        "Yearly" {
                            Invoke-GuiReportGeneration -ReportType "Yearly" -ReportName "年次レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "Yearly" -RecordCount 5
                                Export-GuiReport -Data $data -ReportName "年次レポート（サンプル）" -Action "Yearly"
                            }
                        }
                        
                        # 分析レポート
                        "License" {
                            Invoke-GuiReportGeneration -ReportType "License" -ReportName "ライセンス分析レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "License" -RecordCount 10
                                Export-GuiReport -Data $data -ReportName "ライセンス分析レポート（サンプル）" -Action "License"
                            }
                        }
                        "UsageAnalysis" {
                            Invoke-GuiReportGeneration -ReportType "Usage" -ReportName "使用状況分析レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "UsageAnalysis" -RecordCount 15
                                Export-GuiReport -Data $data -ReportName "使用状況分析レポート（サンプル）" -Action "UsageAnalysis"
                            }
                        }
                        "PerformanceMonitor" {
                            Invoke-GuiReportGeneration -ReportType "Performance" -ReportName "パフォーマンス監視レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "PerformanceMonitor" -RecordCount 20
                                Export-GuiReport -Data $data -ReportName "パフォーマンス監視レポート（サンプル）" -Action "PerformanceMonitor"
                            }
                        }
                        "SecurityAnalysis" {
                            Invoke-GuiReportGeneration -ReportType "Security" -ReportName "セキュリティ分析レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "SecurityAnalysis" -RecordCount 25
                                Export-GuiReport -Data $data -ReportName "セキュリティ分析レポート（サンプル）" -Action "SecurityAnalysis"
                            }
                        }
                        "PermissionAudit" {
                            Invoke-GuiReportGeneration -ReportType "Permissions" -ReportName "権限監査レポート" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "PermissionAudit" -RecordCount 20
                                Export-GuiReport -Data $data -ReportName "権限監査レポート（サンプル）" -Action "PermissionAudit"
                            }
                        }
                        
                        # Entra ID管理
                        "EntraIDUsers" {
                            Invoke-GuiReportGeneration -ReportType "EntraIDUsers" -ReportName "Entra IDユーザー一覧" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "EntraIDUsers" -RecordCount 50
                                Export-GuiReport -Data $data -ReportName "Entra IDユーザー一覧（サンプル）" -Action "EntraIDUsers"
                            }
                        }
                        "EntraIDMFA" {
                            Invoke-GuiReportGeneration -ReportType "EntraIDMFA" -ReportName "Entra ID MFA状況" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "EntraIDUsers" -RecordCount 30
                                Export-GuiReport -Data $data -ReportName "Entra ID MFA状況（サンプル）" -Action "EntraIDUsers"
                            }
                        }
                        "ConditionalAccess" {
                            Invoke-GuiReportGeneration -ReportType "ConditionalAccess" -ReportName "条件付きアクセス設定" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "SecurityAnalysis" -RecordCount 15
                                Export-GuiReport -Data $data -ReportName "条件付きアクセス設定（サンプル）" -Action "SecurityAnalysis"
                            }
                        }
                        "SignInLogs" {
                            Invoke-GuiReportGeneration -ReportType "SignInLogs" -ReportName "サインインログ分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "SecurityAnalysis" -RecordCount 100
                                Export-GuiReport -Data $data -ReportName "サインインログ分析（サンプル）" -Action "SecurityAnalysis"
                            }
                        }
                        
                        # Exchange Online管理
                        "ExchangeMailbox" {
                            Invoke-GuiReportGeneration -ReportType "ExchangeMailbox" -ReportName "Exchangeメールボックス分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "ExchangeMailbox" -RecordCount 40
                                Export-GuiReport -Data $data -ReportName "Exchangeメールボックス分析（サンプル）" -Action "ExchangeMailbox"
                            }
                        }
                        "MailFlow" {
                            Invoke-GuiReportGeneration -ReportType "MailFlow" -ReportName "メールフロー分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "ExchangeMailbox" -RecordCount 30
                                Export-GuiReport -Data $data -ReportName "メールフロー分析（サンプル）" -Action "ExchangeMailbox"
                            }
                        }
                        "AntiSpam" {
                            Invoke-GuiReportGeneration -ReportType "AntiSpam" -ReportName "スパム対策分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "SecurityAnalysis" -RecordCount 25
                                Export-GuiReport -Data $data -ReportName "スパム対策分析（サンプル）" -Action "SecurityAnalysis"
                            }
                        }
                        "MailDelivery" {
                            Invoke-GuiReportGeneration -ReportType "MailDelivery" -ReportName "メール配信分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "ExchangeMailbox" -RecordCount 35
                                Export-GuiReport -Data $data -ReportName "メール配信分析（サンプル）" -Action "ExchangeMailbox"
                            }
                        }
                        
                        # Teams管理
                        "TeamsUsage" {
                            Invoke-GuiReportGeneration -ReportType "TeamsUsage" -ReportName "Teams使用状況" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "TeamsUsage" -RecordCount 40
                                Export-GuiReport -Data $data -ReportName "Teams使用状況分析" -Action "TeamsUsage"
                            }
                        }
                        "TeamsConfig" {
                            Invoke-GuiReportGeneration -ReportType "TeamsConfig" -ReportName "Teams設定分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "TeamsUsage" -RecordCount 20
                                Export-GuiReport -Data $data -ReportName "Teams設定分析" -Action "TeamsUsage"
                            }
                        }
                        "MeetingQuality" {
                            Invoke-GuiReportGeneration -ReportType "MeetingQuality" -ReportName "会議品質分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "PerformanceMonitor" -RecordCount 30
                                Export-GuiReport -Data $data -ReportName "会議品質分析" -Action "PerformanceMonitor"
                            }
                        }
                        "TeamsApps" {
                            Invoke-GuiReportGeneration -ReportType "TeamsApps" -ReportName "Teamsアプリ分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "UsageAnalysis" -RecordCount 15
                                Export-GuiReport -Data $data -ReportName "Teamsアプリ使用状況" -Action "UsageAnalysis"
                            }
                        }
                        
                        # OneDrive管理
                        "OneDriveStorage" {
                            Invoke-GuiReportGeneration -ReportType "OneDriveStorage" -ReportName "OneDriveストレージ分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "OneDriveStorage" -RecordCount 45
                                Export-GuiReport -Data $data -ReportName "OneDriveストレージ分析（サンプル）" -Action "OneDriveStorage"
                            }
                        }
                        "OneDriveSharing" {
                            Invoke-GuiReportGeneration -ReportType "OneDriveSharing" -ReportName "OneDrive共有分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "SecurityAnalysis" -RecordCount 25
                                Export-GuiReport -Data $data -ReportName "OneDrive共有分析（サンプル）" -Action "SecurityAnalysis"
                            }
                        }
                        "SyncErrors" {
                            Invoke-GuiReportGeneration -ReportType "SyncErrors" -ReportName "OneDrive同期エラー分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "OneDriveStorage" -RecordCount 20
                                Export-GuiReport -Data $data -ReportName "OneDrive同期エラー分析（サンプル）" -Action "OneDriveStorage"
                            }
                        }
                        "ExternalSharing" {
                            Invoke-GuiReportGeneration -ReportType "ExternalSharing" -ReportName "外部共有分析" -FallbackDataGenerator {
                                $data = New-DummyData -DataType "SecurityAnalysis" -RecordCount 30
                                Export-GuiReport -Data $data -ReportName "外部共有分析（サンプル）" -Action "SecurityAnalysis"
                            }
                        }
                        
                        # その他のアクション
                        "Test" {
                            $data = New-DummyData -DataType "default" -RecordCount 10
                            Export-GuiReport -Data $data -ReportName "テストレポート" -Action "General"
                        }
                        
                        default {
                            Write-Host "予期しないアクション: $actionValue" -ForegroundColor Red
                            [System.Windows.Forms.MessageBox]::Show(
                                "この機能は現在開発中です: $actionValue", 
                                "情報", 
                                [System.Windows.Forms.MessageBoxButtons]::OK, 
                                [System.Windows.Forms.MessageBoxIcon]::Information
                            )
                        }
                    }
                }
                catch {
                    if ($_.Exception -is [System.ObjectDisposedException]) {
                        Write-Host "オブジェクトは既に破棄されています" -ForegroundColor Yellow
                        return
                    }
                    
                    $errorMessage = "ボタンアクション実行エラー: $($_.Exception.Message)"
                    Write-Host $errorMessage -ForegroundColor Red
                    
                    # フォームがまだ有効な場合のみメッセージボックスを表示
                    try {
                        if (-not $sender.IsDisposed -and -not $sender.FindForm().IsDisposed) {
                            [System.Windows.Forms.MessageBox]::Show($errorMessage, "エラー", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                        }
                    }
                    catch {
                        Write-Host "メッセージボックス表示エラー: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            })
            
            return $button
        }
        
        # セクション作成関数
        function New-Section {
            param([string]$Title, [array]$Buttons, [int]$StartY)
            
            # セクションタイトル
            $sectionLabel = New-Object System.Windows.Forms.Label
            $sectionLabel.Text = $Title
            $sectionLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 12, [System.Drawing.FontStyle]::Bold)
            $sectionLabel.ForeColor = [System.Drawing.Color]::DarkGreen
            $sectionLabel.Location = New-Object System.Drawing.Point(50, $StartY)
            $sectionLabel.Size = New-Object System.Drawing.Size(300, 25)
            $mainPanel.Controls.Add($sectionLabel)
            
            # ボタン配置
            $currentY = $StartY + 30
            $currentX = 50
            $buttonsPerRow = 6
            $buttonCount = 0
            
            foreach ($buttonInfo in $Buttons) {
                $location = New-Object System.Drawing.Point($currentX, $currentY)
                $button = New-ActionButton -Text $buttonInfo.Text -Action $buttonInfo.Action -Location $location
                $mainPanel.Controls.Add($button)
                
                $buttonCount++
                $currentX += 180
                
                if ($buttonCount % $buttonsPerRow -eq 0) {
                    $currentX = 50
                    $currentY += 55
                }
            }
            
            return $currentY + 60
        }
        
        # ボタン定義（セクション別）
        $currentY = 90
        
        # 定期レポートセクション
        $periodicReports = @(
            @{ Text = "日次レポート"; Action = "Daily" },
            @{ Text = "週次レポート"; Action = "Weekly" },
            @{ Text = "月次レポート"; Action = "Monthly" },
            @{ Text = "年次レポート"; Action = "Yearly" },
            @{ Text = "テスト実行"; Action = "Test" }
        )
        $currentY = New-Section -Title "📊 定期レポート" -Buttons $periodicReports -StartY $currentY
        
        # 分析レポートセクション
        $analysisReports = @(
            @{ Text = "ライセンス分析"; Action = "License" },
            @{ Text = "使用状況分析"; Action = "UsageAnalysis" },
            @{ Text = "パフォーマンス監視"; Action = "PerformanceMonitor" },
            @{ Text = "セキュリティ分析"; Action = "SecurityAnalysis" },
            @{ Text = "権限監査"; Action = "PermissionAudit" }
        )
        $currentY = New-Section -Title "🔍 分析レポート" -Buttons $analysisReports -StartY $currentY
        
        # Entra ID管理セクション
        $entraIdManagement = @(
            @{ Text = "ユーザー一覧"; Action = "EntraIDUsers" },
            @{ Text = "MFA状況"; Action = "EntraIDMFA" },
            @{ Text = "条件付きアクセス"; Action = "ConditionalAccess" },
            @{ Text = "サインインログ"; Action = "SignInLogs" }
        )
        $currentY = New-Section -Title "👥 Entra ID管理" -Buttons $entraIdManagement -StartY $currentY
        
        # Exchange Online管理セクション
        $exchangeManagement = @(
            @{ Text = "メールボックス分析"; Action = "ExchangeMailbox" },
            @{ Text = "メールフロー分析"; Action = "MailFlow" },
            @{ Text = "スパム対策分析"; Action = "AntiSpam" },
            @{ Text = "メール配信分析"; Action = "MailDelivery" }
        )
        $currentY = New-Section -Title "📧 Exchange Online管理" -Buttons $exchangeManagement -StartY $currentY
        
        # Teams管理セクション
        $teamsManagement = @(
            @{ Text = "Teams使用状況"; Action = "TeamsUsage" },
            @{ Text = "Teams設定分析"; Action = "TeamsConfig" },
            @{ Text = "会議品質分析"; Action = "MeetingQuality" },
            @{ Text = "Teamsアプリ分析"; Action = "TeamsApps" }
        )
        $currentY = New-Section -Title "💬 Teams管理" -Buttons $teamsManagement -StartY $currentY
        
        # OneDrive管理セクション
        $oneDriveManagement = @(
            @{ Text = "ストレージ分析"; Action = "OneDriveStorage" },
            @{ Text = "共有分析"; Action = "OneDriveSharing" },
            @{ Text = "同期エラー分析"; Action = "SyncErrors" },
            @{ Text = "外部共有分析"; Action = "ExternalSharing" }
        )
        $currentY = New-Section -Title "💾 OneDrive管理" -Buttons $oneDriveManagement -StartY $currentY
        
        # 終了ボタン
        $exitButton = New-Object System.Windows.Forms.Button
        $exitButton.Text = "終了"
        $exitButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 12, [System.Drawing.FontStyle]::Bold)
        $exitButton.Size = New-Object System.Drawing.Size(120, 40)
        $exitButton.Location = New-Object System.Drawing.Point(500, $currentY)
        $exitButton.BackColor = [System.Drawing.Color]::LightCoral
        $exitButton.Add_Click({
            Write-Host "終了ボタンがクリックされました" -ForegroundColor Yellow
            $form.Close()
        })
        $mainPanel.Controls.Add($exitButton)
        
        # ステータスラベル
        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Text = "準備完了 - PowerShell $($PSVersionTable.PSVersion) - 拡張版GUI"
        $statusLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 9)
        $statusLabel.Location = New-Object System.Drawing.Point(50, ($currentY + 50))
        $statusLabel.Size = New-Object System.Drawing.Size(800, 20)
        $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $statusLabel.ForeColor = [System.Drawing.Color]::Gray
        $mainPanel.Controls.Add($statusLabel)
        
        # フォームサイズを明示的に再設定
        $form.Size = New-Object System.Drawing.Size(1200, 800)
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        
        Write-Host "拡張版メインフォーム作成完了" -ForegroundColor Green
        Write-Host "フォームサイズ: $($form.Width)x$($form.Height)" -ForegroundColor Cyan
        Write-Host "コントロール数: $($form.Controls.Count)" -ForegroundColor Cyan
        return $form
        
    }
    catch {
        $errorMessage = "フォーム作成エラー: $($_.Exception.Message)"
        Write-Host $errorMessage -ForegroundColor Red
        Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        return $null
    }
}

# アプリケーション初期化
function Initialize-Application {
    try {
        Initialize-WindowsForms
        Write-Host "拡張版アプリケーション初期化完了" -ForegroundColor Green
        return $true
    }
    catch {
        $errorMessage = "拡張版アプリケーション初期化エラー: $($_.Exception.Message)"
        Write-Host $errorMessage -ForegroundColor Red
        Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        return $false
    }
}

# メイン実行
function Main {
    try {
        # PowerShellバージョンチェック
        if ($PSVersionTable.PSVersion -lt [Version]"7.0.0") {
            Write-Host "エラー: このGUIアプリケーションはPowerShell 7.0以上が必要です。" -ForegroundColor Red
            Write-Host "現在のバージョン: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
            exit 1
        }
        
        # アプリケーション初期化
        if (-not (Initialize-Application)) {
            exit 1
        }
        
        
        # フォーム作成
        $form = New-MainForm
        if ($form) {
            Write-Host "拡張版フォーム作成成功、アプリケーション実行開始" -ForegroundColor Green
            
            # フォームのプロパティを再設定
            $form.TopMost = $false
            $form.ShowInTaskbar = $true
            $form.MinimumSize = New-Object System.Drawing.Size(800, 600)
            $form.AllowDrop = $false
            $form.IsMdiContainer = $false
            
            # フォームのLoadイベントを追加
            $form.Add_Load({
                Write-Host "フォームがロードされました" -ForegroundColor Green
                $sender = $args[0]
                Write-Host "フォーム名: $($sender.Text)" -ForegroundColor Cyan
                Write-Host "フォーム表示状態: $($sender.Visible)" -ForegroundColor Cyan
                Write-Host "フォーム移動可能: $($sender.FormBorderStyle)" -ForegroundColor Cyan
                Write-Host "フォーム最小化可能: $($sender.MinimizeBox)" -ForegroundColor Cyan
                Write-Host "フォーム最大化可能: $($sender.MaximizeBox)" -ForegroundColor Cyan
                Write-Host "フォーム制御ボックス: $($sender.ControlBox)" -ForegroundColor Cyan
                
                # Load時にウィンドウ操作設定を再度強制設定
                Write-Host "Load時にウィンドウ操作設定を強制設定..." -ForegroundColor Yellow
                $sender.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
                $sender.MaximizeBox = $true
                $sender.MinimizeBox = $true
                $sender.ControlBox = $true
                $sender.TopMost = $false
                $sender.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Auto
                
                # フォームの位置を明示的に設定
                $sender.Location = New-Object System.Drawing.Point(100, 100)
                $sender.BringToFront()
                
                # 設定後の確認
                Write-Host "Load時設定後の確認:" -ForegroundColor Cyan
                Write-Host "  FormBorderStyle: $($sender.FormBorderStyle)" -ForegroundColor Gray
                Write-Host "  MaximizeBox: $($sender.MaximizeBox)" -ForegroundColor Gray
                Write-Host "  MinimizeBox: $($sender.MinimizeBox)" -ForegroundColor Gray
                Write-Host "  ControlBox: $($sender.ControlBox)" -ForegroundColor Gray
                Write-Host "  TopMost: $($sender.TopMost)" -ForegroundColor Gray
                Write-Host "  SizeGripStyle: $($sender.SizeGripStyle)" -ForegroundColor Gray
            })
            
            # フォームの終了イベントハンドラーを追加
            $form.Add_FormClosing({
                param($sender, $e)
                Write-Host "フォームが閉じられようとしています..." -ForegroundColor Yellow
                Write-Host "終了理由: $($e.CloseReason)" -ForegroundColor Cyan
                
                # 全てのタイマーやバックグラウンドタスクを停止
                [System.Windows.Forms.Application]::DoEvents()
                
                # リソースのクリーンアップ
                $sender.Controls.Clear()
            })
            
            $form.Add_FormClosed({
                Write-Host "フォームが閉じられました" -ForegroundColor Green
                Write-Host "ランチャーメニューに戻ります..." -ForegroundColor Yellow
                
                # アプリケーションの終了処理（PowerShellプロセスは終了しない）
                [System.Windows.Forms.Application]::Exit()
            })
            
            try {
                Write-Host "アプリケーションループを開始します..." -ForegroundColor Yellow
                Write-Host "現在のスレッドのApartmentState: $([System.Threading.Thread]::CurrentThread.ApartmentState)" -ForegroundColor Cyan
                
                # フォームを明示的に前面に表示
                $form.Show()
                $form.Activate()
                $form.Focus()
                
                # 表示後にウィンドウ操作設定を再確認・強制設定
                Write-Host "表示後のフォーム設定を再確認・強制設定..." -ForegroundColor Yellow
                $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
                $form.MaximizeBox = $true
                $form.MinimizeBox = $true
                $form.ControlBox = $true
                $form.TopMost = $false
                $form.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Auto
                
                # 確認ログ
                Write-Host "再設定後の確認:" -ForegroundColor Cyan
                Write-Host "  FormBorderStyle: $($form.FormBorderStyle)" -ForegroundColor Gray
                Write-Host "  MaximizeBox: $($form.MaximizeBox)" -ForegroundColor Gray
                Write-Host "  MinimizeBox: $($form.MinimizeBox)" -ForegroundColor Gray
                Write-Host "  ControlBox: $($form.ControlBox)" -ForegroundColor Gray
                Write-Host "  TopMost: $($form.TopMost)" -ForegroundColor Gray
                Write-Host "  SizeGripStyle: $($form.SizeGripStyle)" -ForegroundColor Gray
                
                # フォームの再描画を強制
                $form.Refresh()
                [System.Windows.Forms.Application]::DoEvents()
                
                # アプリケーションのメインループを実行（フォームを渡す）
                [System.Windows.Forms.Application]::Run($form)
                Write-Host "アプリケーションループが終了しました" -ForegroundColor Yellow
            }
            catch {
                if ($_.Exception -is [System.ObjectDisposedException]) {
                    Write-Host "フォームは既に破棄されています（正常終了）" -ForegroundColor Yellow
                } else {
                    throw
                }
            }
        } else {
            Write-Host "エラー: 拡張版フォーム作成に失敗しました" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        $errorMessage = "拡張版アプリケーション起動エラー: $($_.Exception.Message)"
        Write-Host $errorMessage -ForegroundColor Red
        Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        
        [System.Windows.Forms.MessageBox]::Show(
            "$errorMessage`n`nスタックトレース:`n$($_.ScriptStackTrace)",
            "エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
}

# 実行開始
Write-Host "拡張版GUI起動..." -ForegroundColor Green
Main