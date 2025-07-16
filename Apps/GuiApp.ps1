# ================================================================================
# Microsoft 365統合管理ツール - GUI拡張版
# GuiApp-Enhanced.ps1
# 豊富なメニューとダミーデータ対応のWindows Forms GUIアプリケーション
# ================================================================================

[CmdletBinding()]
param()

# PowerShellウィンドウタイトル設定（視覚的識別の改善）
try {
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        $Host.UI.RawUI.WindowTitle = "🚀 Microsoft 365統合管理ツール - PowerShell 7.x GUI (v$($psVersion.Major).$($psVersion.Minor))"
        # コンソールの背景色を設定して PowerShell 7 を識別しやすくする
        $Host.UI.RawUI.BackgroundColor = "DarkBlue"
        $Host.UI.RawUI.ForegroundColor = "White"
    } else {
        $Host.UI.RawUI.WindowTitle = "🚀 Microsoft 365統合管理ツール - Windows PowerShell GUI (v$($psVersion.Major).$($psVersion.Minor))"
        $Host.UI.RawUI.BackgroundColor = "DarkMagenta"
        $Host.UI.RawUI.ForegroundColor = "White"
    }
    Clear-Host
    Write-Host "🚀 PowerShell $($psVersion.Major).$($psVersion.Minor) で GUI アプリケーションを起動中..." -ForegroundColor Cyan
} catch {
    # タイトル設定に失敗した場合でも続行
    Write-Host "警告: ウィンドウタイトルの設定に失敗しましたが続行します" -ForegroundColor Yellow
}

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
Import-Module "$modulePath\ProgressDisplay.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$modulePath\DailyReportData.psm1" -Force -ErrorAction SilentlyContinue

# Real M365 Data Provider モジュールをインポート
try {
    Remove-Module RealM365DataProvider -ErrorAction SilentlyContinue
    Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking
    Write-Host "✅ RealM365DataProvider モジュール読み込み完了" -ForegroundColor Green
} catch {
    Write-Host "❌ RealM365DataProvider モジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "ダミーデータモードで動作します" -ForegroundColor Yellow
}

# HTMLTemplateWithPDFモジュールの強制読み込み
try {
    Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
    Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking
    Write-Host "✅ HTMLTemplateWithPDFモジュール読み込み完了" -ForegroundColor Green
} catch {
    Write-Host "❌ HTMLTemplateWithPDFモジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
}

Import-Module "$modulePath\SafeRealDataReport.psm1" -Force -ErrorAction SilentlyContinue

# Microsoft 365 認証状態確認
$Script:M365Connected = $false
try {
    $authStatus = Test-M365Authentication
    $Script:M365Connected = $authStatus.GraphConnected
    if ($Script:M365Connected) {
        Write-Host "✅ Microsoft 365 認証済み" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Microsoft 365 未認証 - 接続が必要です" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Microsoft 365 認証確認に失敗しました" -ForegroundColor Yellow
}

# 基本HTML作成関数
function New-BasicHTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Summary = @{}
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
        
        $basicHtml = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>📊 Microsoft 365 日次レポート</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .title { color: #0078d4; font-size: 32px; margin-bottom: 10px; font-weight: 600; }
        .timestamp { color: #666; font-size: 14px; background: #f8f9fa; padding: 8px 16px; border-radius: 20px; display: inline-block; }
        .summary { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 30px; border-left: 4px solid #0078d4; }
        .summary h3 { margin-top: 0; color: #0078d4; }
        table { width: 100%; border-collapse: collapse; background: white; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
        th { background: linear-gradient(135deg, #0078d4, #0056b3); color: white; padding: 12px 15px; text-align: left; font-weight: 600; }
        td { padding: 10px 15px; border-bottom: 1px solid #e9ecef; }
        tr:nth-child(even) { background: #f8f9fa; }
        tr:hover { background: #e3f2fd; }
        .controls { text-align: center; margin-top: 30px; }
        .btn { background: linear-gradient(135deg, #0078d4, #0056b3); color: white; padding: 12px 24px; border: none; border-radius: 8px; cursor: pointer; margin: 5px; font-weight: 600; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,120,212,0.3); }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="title">📊 Microsoft 365 日次レポート</h1>
            <div class="timestamp">📅 $timestamp</div>
        </div>
        
        <div class="summary">
            <h3>📊 サマリー情報</h3>
"@
        
        # サマリー情報を追加
        foreach ($key in $Summary.Keys) {
            $value = $Summary[$key]
            $basicHtml += "            <p><strong>${key}:</strong> ${value}</p>`n"
        }
        
        $basicHtml += @"
        </div>
        
        <h3>👥 ユーザーアクティビティ</h3>
        <table>
            <thead>
                <tr>
"@
        
        # テーブルヘッダー生成
        if ($Data -and $Data.Count -gt 0) {
            $properties = $Data[0].PSObject.Properties.Name
            foreach ($prop in $properties) {
                $basicHtml += "                    <th>$prop</th>`n"
            }
        }
        
        $basicHtml += @"
                </tr>
            </thead>
            <tbody>
"@
        
        # データ行生成
        if ($Data -and $Data.Count -gt 0) {
            foreach ($item in $Data) {
                $basicHtml += "                <tr>`n"
                foreach ($prop in $properties) {
                    $value = if ($item.$prop) { $item.$prop } else { "" }
                    $basicHtml += "                    <td>$value</td>`n"
                }
                $basicHtml += "                </tr>`n"
            }
        }
        
        $basicHtml += @"
            </tbody>
        </table>
        
        <div class="controls">
            <button class="btn" onclick="window.print()">🖨️ 印刷</button>
            <button class="btn" onclick="downloadCSV()">📊 CSV出力</button>
        </div>
    </div>
    
    <script>
        function downloadCSV() {
            alert('CSVファイルは別途生成されています。ファイルエクスプローラーで確認してください。');
        }
    </script>
</body>
</html>
"@
        
        $basicHtml | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-Host "📄 基本HTMLファイル出力: $OutputPath" -ForegroundColor Yellow
        
    } catch {
        Write-Host "❌ 基本HTML作成エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

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
        
        # ウィンドウ操作を可能にする設定（完全バージョン）
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
        
        # 移動・リサイズ可能設定を確実にする
        $form.AllowDrop = $false
        $form.IsMdiContainer = $false
        $form.MaximumSize = New-Object System.Drawing.Size(1600, 1200)  # 最大サイズ制限
        
        # フォーカス設定
        $form.TabStop = $false
        
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
                
                # ボタンを一時的に無効化してダブルクリック防止
                $sender.Enabled = $false
                $originalText = $sender.Text
                $sender.Text = "処理中..."
                
                # GUIの応答性を保つためにDoEventsを実行
                [System.Windows.Forms.Application]::DoEvents()
                
                # 軽量・高速処理でGUIの応答性を確保
                try {
                    Write-Host "`n🚀 レポート生成開始: $buttonText ($actionValue)" -ForegroundColor Yellow
                    
                    # 即座のビジュアルフィードバック
                    $sender.BackColor = [System.Drawing.Color]::LightBlue
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # 高速なローカル処理（重い外部処理を避ける）
                        
                    # シンプルな非同期レポート生成関数
                    function Start-SimpleAsyncReport {
                        param(
                            [string]$ReportType,
                            [System.Windows.Forms.Button]$Button,
                            [string]$OriginalText
                        )
                        
                        # ボタンの状態を更新
                        $Button.Text = "🔄 生成中..."
                        $Button.BackColor = [System.Drawing.Color]::Orange
                        $Button.Enabled = $false
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        # シンプルなタイマーベース処理
                        $script:asyncStep = 0
                        $script:asyncData = $null
                        $script:asyncError = $null
                        
                        $timer = New-Object System.Windows.Forms.Timer
                        $timer.Interval = 500  # 0.5秒間隔
                        
                        $timer.Add_Tick({
                            $script:asyncStep++
                            $dots = "." * (($script:asyncStep % 4) + 1)
                            $Button.Text = "🔄 処理中$dots"
                            [System.Windows.Forms.Application]::DoEvents()
                            
                            # 3秒後にデータ取得を開始
                            if ($script:asyncStep -eq 6) {
                                try {
                                    # 実データ取得を試行
                                    Write-Host "🔍 Microsoft 365実データ取得開始..." -ForegroundColor Cyan
                                    $realData = Get-DailyReportRealData
                                    if ($realData -and $realData.UserActivity -and $realData.UserActivity.Count -gt 0) {
                                        $script:asyncData = $realData.UserActivity
                                        $script:asyncSuccess = $true
                                        $script:asyncRealData = $realData
                                        Write-Host "✅ 実データ取得成功: $($realData.UserActivity.Count) 件" -ForegroundColor Green
                                    } else {
                                        throw "実データが空です"
                                    }
                                }
                                catch {
                                    Write-Host "⚠️ 実データ取得エラー、ダミーデータを使用: $($_.Exception.Message)" -ForegroundColor Yellow
                                    $script:asyncData = New-FastDummyData -DataType "Daily" -RecordCount 15
                                    $script:asyncSuccess = $false
                                    $script:asyncError = $_.Exception.Message
                                }
                                
                                # レポート生成
                                try {
                                    Generate-ReportFiles -Data $script:asyncData -ReportType $ReportType -RealData $script:asyncRealData
                                    
                                    if ($script:asyncSuccess) {
                                        $Button.Text = "✅ 完了"
                                        $Button.BackColor = [System.Drawing.Color]::LightGreen
                                        
                                        [System.Windows.Forms.MessageBox]::Show(
                                            "✅ 📊 日次レポート の生成が完了しました！`n`n📊 データ件数: $($script:asyncData.Count) 件`n📁 Reports フォルダに保存されました",
                                            "レポート生成完了",
                                            [System.Windows.Forms.MessageBoxButtons]::OK,
                                            [System.Windows.Forms.MessageBoxIcon]::Information
                                        )
                                    } else {
                                        $Button.Text = "⚠️ 部分完了"
                                        $Button.BackColor = [System.Drawing.Color]::Yellow
                                        
                                        [System.Windows.Forms.MessageBox]::Show(
                                            "⚠️ 実データ取得に失敗しましたが、ダミーデータでレポートを生成しました。`n`nエラー: $($script:asyncError)",
                                            "レポート生成（部分完了）",
                                            [System.Windows.Forms.MessageBoxButtons]::OK,
                                            [System.Windows.Forms.MessageBoxIcon]::Warning
                                        )
                                    }
                                }
                                catch {
                                    $Button.Text = "❌ エラー"
                                    $Button.BackColor = [System.Drawing.Color]::LightCoral
                                    
                                    [System.Windows.Forms.MessageBox]::Show(
                                        "レポート生成中にエラーが発生しました:`n$($_.Exception.Message)",
                                        "エラー",
                                        [System.Windows.Forms.MessageBoxButtons]::OK,
                                        [System.Windows.Forms.MessageBoxIcon]::Error
                                    )
                                }
                                
                                # 2秒後にボタンを元に戻す
                                $resetTimer = New-Object System.Windows.Forms.Timer
                                $resetTimer.Interval = 2000
                                $resetTimer.Add_Tick({
                                    $Button.Text = $OriginalText
                                    $Button.BackColor = [System.Drawing.Color]::LightGray
                                    $Button.Enabled = $true
                                    $resetTimer.Stop()
                                    $resetTimer.Dispose()
                                })
                                $resetTimer.Start()
                                
                                $timer.Stop()
                                $timer.Dispose()
                            }
                        })
                        
                        $timer.Start()
                    }
                    
                    # 非同期レポート生成関数（Runspace使用）
                    function Invoke-AsyncReportGeneration {
                        param(
                            [string]$ReportType,
                            [System.Windows.Forms.Button]$Button,
                            [string]$OriginalText
                        )
                        
                        # ボタンの状態を更新
                        $Button.Text = "🔄 生成中..."
                        $Button.BackColor = [System.Drawing.Color]::Orange
                        $Button.Enabled = $false
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        # Runspaceを使用した非同期処理
                        $runspace = [runspacefactory]::CreateRunspace()
                        $runspace.Open()
                        
                        # 必要な変数をRunspaceに渡す
                        $runspace.SessionStateProxy.SetVariable("ToolRoot", $Script:ToolRoot)
                        $runspace.SessionStateProxy.SetVariable("ReportType", $ReportType)
                        
                        $powershell = [powershell]::Create()
                        $powershell.Runspace = $runspace
                        
                        $scriptBlock = {
                            # モジュールを再インポート
                            $modulePath = Join-Path $ToolRoot "Scripts\Common"
                            Import-Module "$modulePath\DailyReportData.psm1" -Force -ErrorAction SilentlyContinue
                            
                            # HTMLTemplateWithPDFモジュールの強制再読み込み
                            Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
                            Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking
                            
                            try {
                                # 実データ取得
                                $realData = Get-DailyReportRealData
                                
                                $result = @{
                                    Success = $true
                                    Data = $realData
                                    Message = "実データ取得成功"
                                    Count = if ($realData.UserActivity) { $realData.UserActivity.Count } else { 0 }
                                }
                                
                                return $result
                            }
                            catch {
                                return @{
                                    Success = $false
                                    Error = $_.Exception.Message
                                    Message = "実データ取得エラー"
                                }
                            }
                        }
                        
                        $powershell.AddScript($scriptBlock)
                        $asyncResult = $powershell.BeginInvoke()
                        
                        # タイマーで定期的に状態をチェック
                        $timer = New-Object System.Windows.Forms.Timer
                        $timer.Interval = 1000  # 1秒間隔
                        $progressDots = 0
                        
                        $timer.Add_Tick({
                            if ($asyncResult.IsCompleted) {
                                try {
                                    $result = $powershell.EndInvoke($asyncResult)
                                    $powershell.Dispose()
                                    $runspace.Close()
                                    $runspace.Dispose()
                                    
                                    if ($result.Success) {
                                        # 成功時の処理
                                        $data = $result.Data.UserActivity
                                        Write-Host "✅ 実データ取得成功: $($result.Count) 件" -ForegroundColor Green
                                        
                                        # レポート生成とファイル出力
                                        Generate-ReportFiles -Data $data -ReportType $ReportType -RealData $result.Data
                                        
                                        $Button.Text = "✅ 完了"
                                        $Button.BackColor = [System.Drawing.Color]::LightGreen
                                        
                                        # 完了メッセージ
                                        [System.Windows.Forms.MessageBox]::Show(
                                            "✅ 📊 日次レポート の生成が完了しました！`n`n📊 データ件数: $($result.Count) 件`n📁 Reports フォルダに保存されました",
                                            "レポート生成完了",
                                            [System.Windows.Forms.MessageBoxButtons]::OK,
                                            [System.Windows.Forms.MessageBoxIcon]::Information
                                        )
                                    }
                                    else {
                                        # エラー時はダミーデータで処理
                                        Write-Host "⚠️ 実データ取得エラー、ダミーデータを使用: $($result.Error)" -ForegroundColor Yellow
                                        $data = New-FastDummyData -DataType "Daily" -RecordCount 15
                                        
                                        Generate-ReportFiles -Data $data -ReportType $ReportType
                                        
                                        $Button.Text = "⚠️ 部分完了"
                                        $Button.BackColor = [System.Drawing.Color]::Yellow
                                        
                                        [System.Windows.Forms.MessageBox]::Show(
                                            "⚠️ 実データ取得に失敗しましたが、ダミーデータでレポートを生成しました。`n`nエラー: $($result.Error)",
                                            "レポート生成（部分完了）",
                                            [System.Windows.Forms.MessageBoxButtons]::OK,
                                            [System.Windows.Forms.MessageBoxIcon]::Warning
                                        )
                                    }
                                }
                                catch {
                                    Write-Host "❌ 非同期処理エラー: $($_.Exception.Message)" -ForegroundColor Red
                                    $Button.Text = "❌ エラー"
                                    $Button.BackColor = [System.Drawing.Color]::LightCoral
                                    
                                    [System.Windows.Forms.MessageBox]::Show(
                                        "レポート生成中にエラーが発生しました:`n$($_.Exception.Message)",
                                        "エラー",
                                        [System.Windows.Forms.MessageBoxButtons]::OK,
                                        [System.Windows.Forms.MessageBoxIcon]::Error
                                    )
                                }
                                finally {
                                    # 2秒後にボタンを元に戻す
                                    $resetTimer = New-Object System.Windows.Forms.Timer
                                    $resetTimer.Interval = 2000
                                    $resetTimer.Add_Tick({
                                        $Button.Text = $OriginalText
                                        $Button.BackColor = [System.Drawing.Color]::LightGray
                                        $Button.Enabled = $true
                                        $resetTimer.Stop()
                                        $resetTimer.Dispose()
                                    })
                                    $resetTimer.Start()
                                    
                                    $timer.Stop()
                                    $timer.Dispose()
                                }
                            }
                            else {
                                # 進行中の表示を更新
                                $progressDots = ($progressDots + 1) % 4
                                $dots = "." * ($progressDots + 1)
                                $Button.Text = "🔄 処理中$dots"
                            }
                            
                            [System.Windows.Forms.Application]::DoEvents()
                        })
                        
                        $timer.Start()
                    }
                    
                    # レポートファイル生成関数
                    function Generate-ReportFiles {
                        param(
                            [array]$Data,
                            [string]$ReportType,
                            [hashtable]$RealData = $null
                        )
                        
                        try {
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $reportsDir = Join-Path $Script:ToolRoot "Reports\Daily"
                            
                            if (-not (Test-Path $reportsDir)) {
                                New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null
                            }
                            
                            # ファイルパス
                            $csvPath = Join-Path $reportsDir "日次レポート_$timestamp.csv"
                            $htmlPath = Join-Path $reportsDir "日次レポート_$timestamp.html"
                            
                            # CSV出力（文字化け対策でUTF8BOM使用）
                            $Data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
                            Write-Host "📄 CSVファイル出力: $csvPath" -ForegroundColor Green
                            
                            # HTML出力（PDF機能付き）
                            $dataSections = @(
                                @{
                                    Title = "👥 ユーザーアクティビティ"
                                    Data = $Data
                                }
                            )
                            
                            $summary = if ($RealData -and $RealData.Summary) { 
                                $RealData.Summary 
                            } else { 
                                @{
                                    "総データ件数" = $Data.Count
                                    "処理日時" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                                    "データソース" = if ($RealData) { "Microsoft 365 API" } else { "ダミーデータ" }
                                }
                            }
                            
                            # HTMLTemplateWithPDFモジュールの明示的再読み込み
                            $modulePath = Join-Path $Script:ToolRoot "Scripts\Common"
                            try {
                                Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
                                Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking
                                Write-Host "✅ HTMLTemplateWithPDFモジュール強制読み込み成功" -ForegroundColor Green
                            } catch {
                                Write-Host "⚠️ HTMLTemplateWithPDFモジュール読み込み警告: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                            
                            # 関数の存在確認と実行
                            if (Get-Command "New-HTMLReportWithPDF" -ErrorAction SilentlyContinue) {
                                Write-Host "✅ New-HTMLReportWithPDF関数が利用可能です" -ForegroundColor Green
                                try {
                                    New-HTMLReportWithPDF -Title "📊 Microsoft 365 日次レポート" -DataSections $dataSections -OutputPath $htmlPath -Summary $summary
                                    Write-Host "🌐 Templates統合HTMLファイル出力: $htmlPath" -ForegroundColor Green
                                } catch {
                                    Write-Host "❌ HTMLレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
                                    # フォールバックHTML作成
                                    New-BasicHTMLReport -Data $data -OutputPath $htmlPath -Summary $summary
                                }
                            } else {
                                Write-Host "❌ New-HTMLReportWithPDF関数が見つかりません。基本HTMLを作成します。" -ForegroundColor Red
                                # フォールバック: 簡単なHTMLを作成
                                $simpleHtml = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>日次レポート</title></head>
<body><h1>Microsoft 365 日次レポート</h1><p>データ件数: $($Data.Count)</p></body>
</html>
"@
                                $simpleHtml | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
                                Write-Host "📄 簡易HTMLファイル出力: $htmlPath" -ForegroundColor Yellow
                            }
                            
                            # ファイルを自動で開く
                            Start-Process $csvPath
                            Start-Process $htmlPath
                            
                            Write-Host "🎉 レポート生成完了！" -ForegroundColor Magenta
                        }
                        catch {
                            Write-Host "❌ ファイル出力エラー: $($_.Exception.Message)" -ForegroundColor Red
                            throw
                        }
                    }
                    
                    # 軽量なデータ生成関数（GUI応答性重視）
                    function New-FastDummyData {
                        param([string]$DataType, [int]$RecordCount = 10)
                        
                        Write-Host "📊 $DataType データ生成中..." -ForegroundColor Cyan
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        $dummyData = @()
                        $userNames = @("田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一")
                        $departments = @("営業部", "開発部", "総務部", "人事部", "経理部")
                        
                        # 高速生成（待機時間なし）
                        for ($i = 1; $i -le $RecordCount; $i++) {
                            $dummyData += [PSCustomObject]@{
                                ID = $i
                                ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                                部署 = $departments[(Get-Random -Maximum $departments.Count)]
                                作成日時 = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd HH:mm:ss")
                                ステータス = @("正常", "警告", "注意")[(Get-Random -Maximum 3)]
                                数値データ = Get-Random -Minimum 10 -Maximum 100
                                レポート種別 = $DataType
                            }
                            
                            # 少数回のDoEvents（過度に呼ばない）
                            if ($i % 5 -eq 0) {
                                [System.Windows.Forms.Application]::DoEvents()
                            }
                        }
                        
                        Write-Host "✅ $DataType データ生成完了: $RecordCount 件" -ForegroundColor Green
                        return $dummyData
                    }
                    
                    # レポート生成ステップ処理
                    $reportName = $buttonText
                    $recordCount = 30  # デフォルトレコード数
                    
                    # 軽量・高速処理で即座に応答
                    switch ($actionValue) {
                    # 定期レポート（安定版・即座レスポンス）
                    "Daily" {
                        Write-Host "📊 実データ日次レポート生成中..." -ForegroundColor Cyan
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        # 実データ取得を試行
                        try {
                            # HTMLTemplateWithPDFモジュールの明示的再読み込み
                            $modulePath = Join-Path $Script:ToolRoot "Scripts\Common"
                            try {
                                Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
                                Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking
                                Write-Host "✅ HTMLTemplateWithPDFモジュール強制読み込み成功" -ForegroundColor Green
                            } catch {
                                Write-Host "⚠️ HTMLTemplateWithPDFモジュール読み込み警告: $($_.Exception.Message)" -ForegroundColor Yellow
                            }

                            # DailyReportDataモジュールの読み込み
                            try {
                                Remove-Module DailyReportData -ErrorAction SilentlyContinue
                                Import-Module "$modulePath\DailyReportData.psm1" -Force -DisableNameChecking
                                Write-Host "✅ DailyReportDataモジュール読み込み成功" -ForegroundColor Green
                            } catch {
                                Write-Host "⚠️ DailyReportDataモジュール読み込み警告: $($_.Exception.Message)" -ForegroundColor Yellow
                            }

                            # 実データ取得
                            if (Get-Command "Get-DailyReportRealData" -ErrorAction SilentlyContinue) {
                                Write-Host "📊 Microsoft 365実データ取得中..." -ForegroundColor Cyan
                                $realData = Get-DailyReportRealData
                                
                                if ($realData -and $realData.UserActivity -and $realData.UserActivity.Count -gt 0) {
                                    Write-Host "✅ 実データ取得成功: $($realData.UserActivity.Count) ユーザー" -ForegroundColor Green
                                    $data = $realData.UserActivity
                                    $useRealData = $true
                                } else {
                                    throw "実データが空でした"
                                }
                            } else {
                                throw "Get-DailyReportRealData関数が見つかりません"
                            }
                        } catch {
                            Write-Host "⚠️ 実データ取得失敗: $($_.Exception.Message)" -ForegroundColor Yellow
                            Write-Host "📊 フォールバック: ダミーデータを使用します" -ForegroundColor Yellow
                            $data = New-FastDummyData -DataType "Daily" -RecordCount 50
                            $useRealData = $false
                        }
                        
                        # PDFとCSV生成
                        try {
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $reportsDir = Join-Path $Script:ToolRoot "Reports\Daily"
                            
                            if (-not (Test-Path $reportsDir)) {
                                New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null
                            }
                            
                            # ファイルパス
                            $csvPath = Join-Path $reportsDir "日次レポート_$timestamp.csv"
                            $htmlPath = Join-Path $reportsDir "日次レポート_$timestamp.html"
                            
                            # CSV出力
                            $data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
                            Write-Host "📄 CSVファイル出力: $csvPath" -ForegroundColor Green
                            
                            # HTML出力（PDF機能付き）
                            $dataSections = if ($useRealData -and $realData) {
                                @(
                                    @{
                                        Title = "👥 ユーザーアクティビティ"
                                        Data = $realData.UserActivity
                                    },
                                    @{
                                        Title = "📧 メールボックス容量"
                                        Data = $realData.MailboxCapacity
                                    },
                                    @{
                                        Title = "🔒 セキュリティアラート"
                                        Data = $realData.SecurityAlerts
                                    },
                                    @{
                                        Title = "🔐 MFA状況"
                                        Data = $realData.MFAStatus
                                    }
                                )
                            } else {
                                @(
                                    @{
                                        Title = "👥 ユーザーアクティビティ"
                                        Data = $data
                                    }
                                )
                            }
                            
                            $summary = if ($useRealData -and $realData -and $realData.Summary) {
                                $realData.Summary
                            } else {
                                @{
                                    "総データ件数" = $data.Count
                                    "処理日時" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                                    "データソース" = if ($useRealData) { "Microsoft 365 API" } else { "ダミーデータ（フォールバック）" }
                                    "Microsoft 365接続" = if ($useRealData) { "✅ 接続済み" } else { "❌ 未接続" }
                                }
                            }
                            
                            # HTMLTemplateWithPDFモジュールの明示的再読み込み
                            $modulePath = Join-Path $Script:ToolRoot "Scripts\Common"
                            try {
                                Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
                                Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking
                                Write-Host "✅ HTMLTemplateWithPDFモジュール強制読み込み成功" -ForegroundColor Green
                            } catch {
                                Write-Host "⚠️ HTMLTemplateWithPDFモジュール読み込み警告: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                            
                            # 関数の存在確認と実行
                            if (Get-Command "New-HTMLReportWithPDF" -ErrorAction SilentlyContinue) {
                                Write-Host "✅ New-HTMLReportWithPDF関数が利用可能です" -ForegroundColor Green
                                try {
                                    New-HTMLReportWithPDF -Title "📊 Microsoft 365 日次レポート" -DataSections $dataSections -OutputPath $htmlPath -Summary $summary
                                    Write-Host "🌐 Templates統合HTMLファイル出力: $htmlPath" -ForegroundColor Green
                                } catch {
                                    Write-Host "❌ HTMLレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
                                    # フォールバックHTML作成
                                    New-BasicHTMLReport -Data $data -OutputPath $htmlPath -Summary $summary
                                }
                            } else {
                                Write-Host "❌ New-HTMLReportWithPDF関数が見つかりません。基本HTMLを作成します。" -ForegroundColor Red
                                # フォールバック: 簡単なHTMLを作成
                                $simpleHtml = @"
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"><title>日次レポート</title></head>
<body><h1>Microsoft 365 日次レポート</h1><p>データ件数: $($Data.Count)</p></body>
</html>
"@
                                $simpleHtml | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
                                Write-Host "📄 簡易HTMLファイル出力: $htmlPath" -ForegroundColor Yellow
                            }
                            
                            # ファイルを自動で開く
                            Start-Process $csvPath
                            Start-Process $htmlPath
                            
                            Write-Host "🎉 レポート生成完了！" -ForegroundColor Magenta
                            $reportName = "📊 日次レポート"
                            
                        } catch {
                            Write-Host "❌ レポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
                            throw
                        }
                    }
                    "RealDaily" {
                        Write-Host "📊 実データ日次レポート生成中..." -ForegroundColor Cyan
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        try {
                            $result = Invoke-SafeRealDataReport -ReportType "Daily"
                            if ($result.Success) {
                                $reportName = "📊 実データ日次レポート"
                                Write-Host "✅ 実データレポート生成成功: $($result.DataCount) 件" -ForegroundColor Green
                            } else {
                                Write-Host "⚠️ 実データ取得失敗、ダミーデータで代替実行" -ForegroundColor Yellow
                                $fallbackResult = Invoke-QuickDummyReport -ReportType "Daily" -RecordCount 50
                                $reportName = "📊 日次レポート（ダミーデータ）"
                            }
                        } catch {
                            Write-Host "❌ 実データレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
                            # フォールバックでダミーデータレポート
                            $fallbackResult = Invoke-QuickDummyReport -ReportType "Daily" -RecordCount 50
                            $reportName = "📊 日次レポート（エラー時フォールバック）"
                        }
                    }
                    "Weekly" {
                        $recordCount = 8   # 軽量化
                        Write-Host "📅 週次レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "Weekly" -RecordCount $recordCount
                        $reportName = "📅 週次レポート"
                    }
                    "Monthly" {
                        $recordCount = 8   # 軽量化
                        Write-Host "📈 月次レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "Monthly" -RecordCount $recordCount
                        $reportName = "📈 月次レポート"
                    }
                    "Yearly" {
                        $recordCount = 5
                        Write-Host "📅 年次レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "Yearly" -RecordCount $recordCount
                        $reportName = "📅 年次レポート"
                    }
                        
                    # 分析レポート（高速処理）
                    "License" {
                        $recordCount = 8
                        Write-Host "📊 ライセンス分析レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "License" -RecordCount $recordCount
                        $reportName = "📊 ライセンス分析レポート"
                    }
                    "UsageAnalysis" {
                        $recordCount = 10
                        Write-Host "📈 使用状況分析レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "UsageAnalysis" -RecordCount $recordCount
                        $reportName = "📈 使用状況分析レポート"
                    }
                    "PerformanceMonitor" {
                        $recordCount = 12
                        Write-Host "⚡ パフォーマンス監視レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "PerformanceMonitor" -RecordCount $recordCount
                        $reportName = "⚡ パフォーマンス監視レポート"
                    }
                    "SecurityAnalysis" {
                        $recordCount = 15
                        Write-Host "🔒 セキュリティ分析レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "SecurityAnalysis" -RecordCount $recordCount
                        $reportName = "🔒 セキュリティ分析レポート"
                    }
                    "PermissionAudit" {
                        $recordCount = 12
                        Write-Host "🔐 権限監査レポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "PermissionAudit" -RecordCount $recordCount
                        $reportName = "🔐 権限監査レポート"
                    }
                        
                    # Entra ID管理（高速処理）
                    "EntraIDUsers" {
                        $recordCount = 20  # 軽量化
                        Write-Host "👥 Entra IDユーザー一覧生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "EntraIDUsers" -RecordCount $recordCount
                        $reportName = "👥 Entra IDユーザー一覧"
                    }
                    "EntraIDMFA" {
                        $recordCount = 15  # 軽量化
                        Write-Host "🔐 Entra ID MFA状況生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "EntraIDMFA" -RecordCount $recordCount
                        $reportName = "🔐 Entra ID MFA状況"
                    }
                    "ConditionalAccess" {
                        $recordCount = 10  # 軽量化
                        Write-Host "🔒 条件付きアクセス設定生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "ConditionalAccess" -RecordCount $recordCount
                        $reportName = "🔒 条件付きアクセス設定"
                    }
                    "SignInLogs" {
                        $recordCount = 25  # 大幅軽量化
                        Write-Host "📊 サインインログ分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "SignInLogs" -RecordCount $recordCount
                        $reportName = "📊 サインインログ分析"
                    }
                        
                    # Exchange Online管理（高速処理）
                    "ExchangeMailbox" {
                        $recordCount = 15  # 軽量化
                        Write-Host "📧 Exchangeメールボックス分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "ExchangeMailbox" -RecordCount $recordCount
                        $reportName = "📧 Exchangeメールボックス分析"
                    }
                    "MailFlow" {
                        $recordCount = 12  # 軽量化
                        Write-Host "🔄 メールフロー分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "MailFlow" -RecordCount $recordCount
                        $reportName = "🔄 メールフロー分析"
                    }
                    "AntiSpam" {
                        $recordCount = 10  # 軽量化
                        Write-Host "🛡️ スパム対策分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "AntiSpam" -RecordCount $recordCount
                        $reportName = "🛡️ スパム対策分析"
                    }
                    "MailDelivery" {
                        $recordCount = 15  # 軽量化
                        Write-Host "📬 メール配信分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "MailDelivery" -RecordCount $recordCount
                        $reportName = "📬 メール配信分析"
                    }
                        
                    # Teams管理（高速処理）
                    "TeamsUsage" {
                        $recordCount = 15  # 軽量化
                        Write-Host "💬 Teams使用状況生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "TeamsUsage" -RecordCount $recordCount
                        $reportName = "💬 Teams使用状況"
                    }
                    "TeamsConfig" {
                        $recordCount = 10  # 軽量化
                        Write-Host "⚙️ Teams設定分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "TeamsConfig" -RecordCount $recordCount
                        $reportName = "⚙️ Teams設定分析"
                    }
                    "MeetingQuality" {
                        $recordCount = 12  # 軽量化
                        Write-Host "📹 会議品質分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "MeetingQuality" -RecordCount $recordCount
                        $reportName = "📹 会議品質分析"
                    }
                    "TeamsApps" {
                        $recordCount = 8   # 軽量化
                        Write-Host "📱 Teamsアプリ分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "TeamsApps" -RecordCount $recordCount
                        $reportName = "📱 Teamsアプリ分析"
                    }
                        
                    # OneDrive管理（高速処理）
                    "OneDriveStorage" {
                        $recordCount = 15  # 軽量化
                        Write-Host "💾 OneDriveストレージ分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "OneDriveStorage" -RecordCount $recordCount
                        $reportName = "💾 OneDriveストレージ分析"
                    }
                    "OneDriveSharing" {
                        $recordCount = 12  # 軽量化
                        Write-Host "🔗 OneDrive共有分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "OneDriveSharing" -RecordCount $recordCount
                        $reportName = "🔗 OneDrive共有分析"
                    }
                    "SyncErrors" {
                        $recordCount = 10  # 軽量化
                        Write-Host "⚠️ OneDrive同期エラー分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "SyncErrors" -RecordCount $recordCount
                        $reportName = "⚠️ OneDrive同期エラー分析"
                    }
                    "ExternalSharing" {
                        $recordCount = 12  # 軽量化
                        Write-Host "🌍 外部共有分析生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "ExternalSharing" -RecordCount $recordCount
                        $reportName = "🌍 外部共有分析"
                    }
                        
                    # その他のアクション（高速処理）
                    "Test" {
                        $recordCount = 5   # 軽量化
                        Write-Host "🧪 テストレポート生成中..." -ForegroundColor Yellow
                        [System.Windows.Forms.Application]::DoEvents()
                        $data = New-FastDummyData -DataType "Test" -RecordCount $recordCount
                        $reportName = "🧪 テストレポート"
                    }
                        
                    default {
                        Write-Host "❓ 未対応のアクション: $actionValue" -ForegroundColor Yellow
                        $recordCount = 5   # 軽量化
                        $data = New-FastDummyData -DataType "Unknown" -RecordCount $recordCount
                        $reportName = "❓ 開発中の機能: $actionValue"
                        [System.Windows.Forms.MessageBox]::Show("この機能は現在開発中です: $actionValue", "情報", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                    }
                    
                    # 高速完了処理
                    if ($data -and $data.Count -gt 0) {
                        Write-Host "✅ $reportName 生成完了: $($data.Count) 件" -ForegroundColor Green
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        # 軽量なファイル出力シミュレーション
                        Write-Host "📄 CSVファイル出力をシミュレート中..." -ForegroundColor Cyan
                        [System.Windows.Forms.Application]::DoEvents()
                        Start-Sleep -Milliseconds 100  # 短い待機
                        
                        Write-Host "🌐 HTMLファイル出力をシミュレート中..." -ForegroundColor Cyan
                        [System.Windows.Forms.Application]::DoEvents()
                        Start-Sleep -Milliseconds 100  # 短い待機
                    }
                    
                    # 即座の完了表示
                    Write-Host "🎉 処理完了: $reportName" -ForegroundColor Green
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # 完了通知ポップアップ
                    [System.Windows.Forms.MessageBox]::Show(
                        "✅ $reportName の生成が完了しました！`n`n📊 データ件数: $($data.Count) 件`n⏱️ 処理時間: 高速",
                        "レポート生成完了",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                }
                catch {
                    Write-Host "❌ レポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
                    [System.Windows.Forms.MessageBox]::Show("レポート生成エラー:`n$($_.Exception.Message)", "エラー", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
                finally {
                    # 即座のUIリセット（応答性確保）
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # ボタンの状態を即座にリセット
                    $sender.Text = $originalText
                    $sender.BackColor = [System.Drawing.Color]::LightGray  # 元の色に戻す
                    $sender.Enabled = $true
                    
                    [System.Windows.Forms.Application]::DoEvents()
                    Write-Host "🏁 処理完了: $buttonText" -ForegroundColor Magenta
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
            @{ Text = "📊 実データ日次"; Action = "RealDaily" },
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
        
        # Puppeteer PDF生成ボタン
        $pdfButton = New-Object System.Windows.Forms.Button
        $pdfButton.Text = "📄 Puppeteer PDF生成"
        $pdfButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
        $pdfButton.Size = New-Object System.Drawing.Size(180, 40)
        $pdfButton.Location = New-Object System.Drawing.Point(300, $currentY)
        $pdfButton.BackColor = [System.Drawing.Color]::LightGreen
        $pdfButton.Add_Click({
            param($sender, $e)
            
            Write-Host "Puppeteer PDF生成ボタンがクリックされました" -ForegroundColor Cyan
            
            # ボタンを一時的に無効化
            $sender.Enabled = $false
            $originalText = $sender.Text
            $sender.Text = "PDF生成中..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                # PuppeteerPdfGeneratorモジュールをインポート
                $pdfModulePath = Join-Path $Script:ToolRoot "Scripts\Common\PuppeteerPdfGenerator.psm1"
                if (Test-Path $pdfModulePath) {
                    Import-Module $pdfModulePath -Force
                    
                    # サンプルHTMLコンテンツを生成
                    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365管理ツール - サンプルレポート</title>
    <style>
        body { font-family: 'Yu Gothic UI', sans-serif; margin: 20px; }
        .header { background: #0078d4; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .footer { margin-top: 40px; text-align: center; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Microsoft 365統合管理ツール</h1>
        <h2>サンプルレポート - $(Get-Date -Format "yyyy年MM月dd日 HH時mm分")</h2>
    </div>
    <div class="content">
        <h3>📊 レポート概要</h3>
        <p>このPDFは<strong>Puppeteer</strong>によって生成されました。日本語フォント対応済みです。</p>
        
        <h3>📈 サンプルデータ</h3>
        <table>
            <thead>
                <tr>
                    <th>項目</th>
                    <th>値</th>
                    <th>ステータス</th>
                </tr>
            </thead>
            <tbody>
                <tr><td>総ユーザー数</td><td>$(Get-Random -Minimum 150 -Maximum 250)</td><td>正常</td></tr>
                <tr><td>アクティブユーザー</td><td>$(Get-Random -Minimum 120 -Maximum 200)</td><td>正常</td></tr>
                <tr><td>ライセンス利用率</td><td>$(Get-Random -Minimum 80 -Maximum 95)%</td><td>良好</td></tr>
                <tr><td>ストレージ使用量</td><td>$(Get-Random -Minimum 500 -Maximum 2000) GB</td><td>注意</td></tr>
                <tr><td>セキュリティスコア</td><td>$(Get-Random -Minimum 85 -Maximum 100)/100</td><td>優秀</td></tr>
            </tbody>
        </table>
        
        <h3>🔍 システム詳細</h3>
        <ul>
            <li><strong>PowerShell バージョン:</strong> $($PSVersionTable.PSVersion)</li>
            <li><strong>OS:</strong> $($PSVersionTable.Platform)</li>
            <li><strong>生成日時:</strong> $(Get-Date)</li>
            <li><strong>PDF生成エンジン:</strong> Puppeteer</li>
        </ul>
    </div>
    <div class="footer">
        <p>Generated by Microsoft 365統合管理ツール - Powered by Puppeteer</p>
    </div>
</body>
</html>
"@
                    
                    # 出力ディレクトリを準備
                    $outputDir = Join-Path $Script:ToolRoot "Reports\PDF"
                    if (-not (Test-Path $outputDir)) {
                        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                    }
                    
                    # PDF生成実行
                    $pdfPath = Export-HtmlToPdf -HtmlContent $htmlContent -OutputDirectory $outputDir -FileName "Microsoft365_Sample_$(Get-Date -Format 'yyyyMMdd_HHmmss').pdf"
                    
                    if ($pdfPath -and (Test-Path $pdfPath)) {
                        [System.Windows.Forms.MessageBox]::Show("PDFが正常に生成されました:`n$pdfPath", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("PDF生成に失敗しました。", "エラー", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    }
                } else {
                    [System.Windows.Forms.MessageBox]::Show("PuppeteerPdfGeneratorモジュールが見つかりません:`n$pdfModulePath", "エラー", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("PDF生成エラー:`n$($_.Exception.Message)", "エラー", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                Write-Host "PDF生成エラー: $($_.Exception.Message)" -ForegroundColor Red
            }
            finally {
                # ボタンを元に戻す
                $sender.Text = $originalText
                $sender.Enabled = $true
            }
        })
        $mainPanel.Controls.Add($pdfButton)
        
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