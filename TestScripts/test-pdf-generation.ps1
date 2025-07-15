# ================================================================================
# test-pdf-generation.ps1
# PuppeteerベースのPDF生成機能テストスクリプト
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$InstallPuppeteer = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestSampleHTML = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestReportGeneration = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestBatchConversion = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose = $false
)

# スクリプトルートパス
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent

# ログ出力関数
function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    $prefix = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        default { "ℹ" }
    }
    
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

# テストバナー表示
function Show-TestBanner {
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    PDF生成機能テストスクリプト                                    ║
║                  Puppeteer + Node.js による高品質PDF生成                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue
    Write-Host ""
}

# Puppeteer環境のセットアップ
function Test-PuppeteerEnvironment {
    Write-TestLog "Puppeteer環境をテストしています..." -Level Info
    
    try {
        # モジュールのインポート
        $pdfModulePath = Join-Path $Script:ToolRoot "Scripts\Common\PuppeteerPDF.psm1"
        if (-not (Test-Path $pdfModulePath)) {
            throw "PuppeteerPDFモジュールが見つかりません: $pdfModulePath"
        }
        
        Import-Module $pdfModulePath -Force
        Write-TestLog "PuppeteerPDFモジュールをインポートしました" -Level Success
        
        # Puppeteerセットアップ状態の確認
        $setupResult = Test-PuppeteerSetup
        if ($setupResult) {
            Write-TestLog "Puppeteer環境は正常にセットアップされています" -Level Success
        } else {
            Write-TestLog "Puppeteer環境のセットアップが必要です" -Level Warning
            
            if ($InstallPuppeteer) {
                Write-TestLog "Puppeteer環境を初期化します..." -Level Info
                $initResult = Initialize-PuppeteerEnvironment -Force
                if ($initResult) {
                    Write-TestLog "Puppeteer環境の初期化が完了しました" -Level Success
                } else {
                    throw "Puppeteer環境の初期化に失敗しました"
                }
            } else {
                Write-TestLog "Puppeteer環境の初期化をスキップします（-InstallPuppeteer フラグが指定されていません）" -Level Info
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-TestLog "Puppeteer環境のテストに失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# サンプルHTMLファイルの生成
function New-SampleHTMLFile {
    param([string]$OutputPath)
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF生成テスト - サンプルレポート</title>
    <style>
        body {
            font-family: 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', 'Noto Sans CJK JP', 'Yu Gothic', 'YuGothic', 'Meiryo', sans-serif;
            margin: 0;
            padding: 20px;
            background: #f8f9fa;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border-bottom: 2px solid #0078d4;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .title {
            color: #0078d4;
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .subtitle {
            color: #666;
            font-size: 16px;
        }
        .section {
            margin-bottom: 30px;
        }
        .section-title {
            color: #0078d4;
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            border-left: 4px solid #0078d4;
            padding-left: 10px;
        }
        .data-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .data-table th {
            background: #0078d4;
            color: white;
            padding: 12px;
            text-align: left;
            border: 1px solid #ddd;
        }
        .data-table td {
            padding: 10px;
            border: 1px solid #ddd;
        }
        .data-table tr:nth-child(even) {
            background: #f8f9fa;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
            font-size: 12px;
        }
        
        /* PDF印刷用設定 */
        @media print {
            * {
                -webkit-print-color-adjust: exact !important;
                print-color-adjust: exact !important;
            }
            
            body {
                background: white !important;
                margin: 0 !important;
                padding: 0 !important;
            }
            
            .container {
                box-shadow: none !important;
                max-width: none !important;
                padding: 20px !important;
            }
            
            .data-table {
                page-break-inside: avoid;
            }
            
            .section {
                page-break-inside: avoid;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="title">Microsoft 365 管理レポート</div>
            <div class="subtitle">PDF生成機能テスト - $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</div>
        </div>
        
        <div class="section">
            <div class="section-title">🔍 システム情報</div>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>項目</th>
                        <th>値</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>PowerShell バージョン</td>
                        <td>$($PSVersionTable.PSVersion)</td>
                    </tr>
                    <tr>
                        <td>PowerShell エディション</td>
                        <td>$($PSVersionTable.PSEdition)</td>
                    </tr>
                    <tr>
                        <td>OS</td>
                        <td>$($PSVersionTable.OS)</td>
                    </tr>
                    <tr>
                        <td>生成日時</td>
                        <td>$(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</td>
                    </tr>
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <div class="section-title">📊 サンプルデータ</div>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>ユーザー名</th>
                        <th>部署</th>
                        <th>ステータス</th>
                        <th>最終ログイン</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>田中太郎</td>
                        <td>営業部</td>
                        <td>アクティブ</td>
                        <td>2025-01-15 09:30:00</td>
                    </tr>
                    <tr>
                        <td>鈴木花子</td>
                        <td>開発部</td>
                        <td>アクティブ</td>
                        <td>2025-01-15 08:45:00</td>
                    </tr>
                    <tr>
                        <td>佐藤次郎</td>
                        <td>総務部</td>
                        <td>非アクティブ</td>
                        <td>2025-01-10 16:20:00</td>
                    </tr>
                    <tr>
                        <td>高橋美咲</td>
                        <td>マーケティング部</td>
                        <td>アクティブ</td>
                        <td>2025-01-15 10:15:00</td>
                    </tr>
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <div class="section-title">📈 統計情報</div>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>メトリック</th>
                        <th>値</th>
                        <th>前月比</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>アクティブユーザー数</td>
                        <td>187 名</td>
                        <td>+12 名</td>
                    </tr>
                    <tr>
                        <td>ストレージ使用量</td>
                        <td>2.3 TB</td>
                        <td>+0.2 TB</td>
                    </tr>
                    <tr>
                        <td>メール送信数</td>
                        <td>15,432 通</td>
                        <td>+1,234 通</td>
                    </tr>
                    <tr>
                        <td>Teams 会議時間</td>
                        <td>1,234 時間</td>
                        <td>+456 時間</td>
                    </tr>
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>Microsoft 365 統合管理ツール - PDF生成機能テスト</p>
            <p>© 2025 All Rights Reserved</p>
        </div>
    </div>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
    Write-TestLog "サンプルHTMLファイルを作成しました: $OutputPath" -Level Success
    return $OutputPath
}

# サンプルHTMLからPDF生成テスト
function Test-SampleHTMLToPDF {
    Write-TestLog "サンプルHTMLからPDF生成テストを開始します..." -Level Info
    
    try {
        # テスト用ディレクトリの作成
        $testDir = Join-Path $Script:ToolRoot "TestScripts\TestReports\PDF"
        if (-not (Test-Path $testDir)) {
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
        }
        
        # サンプルHTMLファイルの生成
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $htmlPath = Join-Path $testDir "sample_report_${timestamp}.html"
        New-SampleHTMLFile -OutputPath $htmlPath
        
        # PDF生成
        $pdfPath = Join-Path $testDir "sample_report_${timestamp}.pdf"
        
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
        
        $result = ConvertTo-PDFFromHTML -InputHtmlPath $htmlPath -OutputPdfPath $pdfPath -Options $pdfOptions
        
        if ($result.Success) {
            Write-TestLog "PDF生成成功!" -Level Success
            Write-TestLog "  入力ファイル: $htmlPath" -Level Info
            Write-TestLog "  出力ファイル: $pdfPath" -Level Info
            Write-TestLog "  ファイルサイズ: $($result.FileSize)" -Level Info
            Write-TestLog "  処理時間: $([math]::Round($result.ProcessingTime, 2))秒" -Level Info
            
            # PDFファイルを開く
            if (Test-Path $pdfPath) {
                Write-TestLog "PDFファイルを開いています..." -Level Info
                Start-Process $pdfPath
            }
            
            return $true
        } else {
            Write-TestLog "PDF生成に失敗しました" -Level Error
            return $false
        }
    }
    catch {
        Write-TestLog "サンプルHTMLからPDF生成テストに失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# 実際のレポート生成テスト
function Test-ReportGeneration {
    Write-TestLog "実際のレポート生成テストを開始します..." -Level Info
    
    try {
        # GUI レポート関数をインポート
        $guiModulePath = Join-Path $Script:ToolRoot "Scripts\Common\GuiReportFunctions.psm1"
        if (Test-Path $guiModulePath) {
            Import-Module $guiModulePath -Force
            Write-TestLog "GUI レポート関数をインポートしました" -Level Success
        } else {
            throw "GUI レポート関数が見つかりません: $guiModulePath"
        }
        
        # ダミーデータの生成
        $dummyData = @()
        $userNames = @("田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一")
        $departments = @("営業部", "開発部", "総務部", "人事部", "経理部")
        
        for ($i = 1; $i -le 20; $i++) {
            $dummyData += [PSCustomObject]@{
                ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                部署 = $departments[(Get-Random -Maximum $departments.Count)]
                ステータス = @("アクティブ", "非アクティブ", "一時停止")[(Get-Random -Maximum 3)]
                最終ログイン = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd HH:mm:ss")
                メール送信数 = Get-Random -Minimum 0 -Maximum 100
                ストレージ使用量 = Get-Random -Minimum 100 -Maximum 5000
            }
        }
        
        # レポート生成（PDF付き）
        $result = Export-GuiReport -Data $dummyData -ReportName "PDF生成テスト" -Action "TestPDF" -EnablePDF
        
        if ($result.Success) {
            Write-TestLog "レポート生成成功!" -Level Success
            Write-TestLog "  データ件数: $($result.DataCount)" -Level Info
            Write-TestLog "  CSVファイル: $($result.CsvPath)" -Level Info
            Write-TestLog "  HTMLファイル: $($result.HtmlPath)" -Level Info
            if ($result.PdfPath) {
                Write-TestLog "  PDFファイル: $($result.PdfPath)" -Level Info
            }
            
            return $true
        } else {
            Write-TestLog "レポート生成に失敗しました" -Level Error
            return $false
        }
    }
    catch {
        Write-TestLog "実際のレポート生成テストに失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# バッチ変換テスト
function Test-BatchConversion {
    Write-TestLog "バッチ変換テストを開始します..." -Level Info
    
    try {
        # 既存のHTMLファイルを検索
        $reportsDir = Join-Path $Script:ToolRoot "Reports"
        $htmlFiles = Get-ChildItem -Path $reportsDir -Filter "*.html" -Recurse | Select-Object -First 3
        
        if ($htmlFiles.Count -eq 0) {
            Write-TestLog "変換対象のHTMLファイルが見つかりません" -Level Warning
            return $false
        }
        
        Write-TestLog "$($htmlFiles.Count)個のHTMLファイルを見つけました" -Level Info
        
        # バッチ変換実行
        $results = ConvertAll-HTMLToPDF -InputDirectory $reportsDir -FilePattern "*.html"
        
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-TestLog "バッチ変換完了: 成功 $successCount 件、失敗 $failCount 件" -Level Info
        
        return $successCount -gt 0
    }
    catch {
        Write-TestLog "バッチ変換テストに失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# メイン実行
function Main {
    Show-TestBanner
    
    Write-TestLog "PDF生成機能テストを開始します..." -Level Info
    Write-TestLog "PowerShell バージョン: $($PSVersionTable.PSVersion)" -Level Info
    Write-TestLog "PowerShell エディション: $($PSVersionTable.PSEdition)" -Level Info
    
    $testResults = @()
    
    # 1. Puppeteer環境テスト
    $puppeteerResult = Test-PuppeteerEnvironment
    $testResults += @{
        Test = "Puppeteer環境テスト"
        Result = $puppeteerResult
    }
    
    if (-not $puppeteerResult) {
        Write-TestLog "Puppeteer環境テストに失敗しました。後続のテストをスキップします。" -Level Error
        Write-TestLog "解決方法: -InstallPuppeteer フラグを指定してPuppeteerをインストールしてください。" -Level Info
        return
    }
    
    # 2. サンプルHTMLからPDF生成テスト
    if ($TestSampleHTML) {
        $sampleResult = Test-SampleHTMLToPDF
        $testResults += @{
            Test = "サンプルHTMLからPDF生成テスト"
            Result = $sampleResult
        }
    }
    
    # 3. 実際のレポート生成テスト
    if ($TestReportGeneration) {
        $reportResult = Test-ReportGeneration
        $testResults += @{
            Test = "実際のレポート生成テスト"
            Result = $reportResult
        }
    }
    
    # 4. バッチ変換テスト
    if ($TestBatchConversion) {
        $batchResult = Test-BatchConversion
        $testResults += @{
            Test = "バッチ変換テスト"
            Result = $batchResult
        }
    }
    
    # テスト結果まとめ
    Write-TestLog "テスト結果まとめ:" -Level Info
    foreach ($test in $testResults) {
        $status = if ($test.Result) { "成功" } else { "失敗" }
        $level = if ($test.Result) { "Success" } else { "Error" }
        Write-TestLog "  $($test.Test): $status" -Level $level
    }
    
    $successCount = ($testResults | Where-Object { $_.Result }).Count
    $totalCount = $testResults.Count
    
    Write-TestLog "全体結果: $successCount/$totalCount テストが成功しました" -Level Info
    
    if ($successCount -eq $totalCount) {
        Write-TestLog "全てのテストが成功しました! PDF生成機能は正常に動作しています。" -Level Success
    } else {
        Write-TestLog "一部のテストが失敗しました。ログを確認してください。" -Level Warning
    }
}

# スクリプト実行
Main