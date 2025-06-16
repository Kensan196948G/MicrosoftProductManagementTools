# Microsoft 365ライセンス分析ダッシュボード統合生成スクリプト
# License_Analysis_Dashboard_20250613_150236.html をテンプレートとして
# タイムスタンプ付きの新しいダッシュボードを生成

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "出力するファイル名パターン")]
    [ValidateSet("Timestamp", "Fixed", "Custom")]
    [string]$FileNameType = "Timestamp",
    
    [Parameter(HelpMessage = "カスタムファイル名（FileNameType=Customの場合）")]
    [string]$CustomFileName,
    
    [Parameter(HelpMessage = "テンプレートファイルパス")]
    [string]$TemplateFile = "Reports/Monthly/License_Analysis_Dashboard_Template_Clean.html",
    
    [Parameter(HelpMessage = "出力ディレクトリ")]
    [string]$OutputDirectory = "Reports/Monthly",
    
    [Parameter(HelpMessage = "ファイル生成後にブラウザで開く")]
    [switch]$OpenInBrowser,
    
    [Parameter(HelpMessage = "詳細情報を表示")]
    [switch]$VerboseOutput
)

function Write-ColorMessage {
    param(
        [string]$Message, 
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Get-OutputFileName {
    param(
        [string]$Type,
        [string]$Custom
    )
    
    switch ($Type) {
        "Timestamp" {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            return "License_Analysis_Dashboard_$timestamp.html"
        }
        "Fixed" {
            return "License_Analysis_Dashboard_Template_Clean.html"
        }
        "Custom" {
            if ([string]::IsNullOrEmpty($Custom)) {
                throw "カスタムファイル名が指定されていません"
            }
            if (-not $Custom.EndsWith(".html")) {
                $Custom += ".html"
            }
            return $Custom
        }
        default {
            throw "無効なファイル名タイプ: $Type"
        }
    }
}

function Update-DashboardContent {
    param(
        [string]$Content,
        [string]$FileName,
        [string]$GenerationType
    )
    
    $currentDateTime = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # 日時情報を更新
    $updatedContent = $Content -replace '分析実行日時: \d{4}年\d{2}月\d{2}日 \d{2}:\d{2}:\d{2}', "分析実行日時: $currentDateTime"
    
    # タイトルを更新
    if ($GenerationType -eq "Timestamp") {
        $updatedContent = $updatedContent -replace '<title>Microsoft 365ライセンス分析ダッシュボード[^<]*</title>', "<title>Microsoft 365ライセンス分析ダッシュボード - $timestamp</title>"
    }
    
    # フッター情報を更新
    $updatedContent = $updatedContent -replace '修正済み - \d{4}年\d{2}月\d{2}日 \d{2}:\d{2}:\d{2}', "生成済み - $currentDateTime"
    $updatedContent = $updatedContent -replace 'PowerShell生成 - [^<]+', "$GenerationType生成 - $currentDateTime"
    
    # 生成情報をコメントとして追加
    $generationComment = @"
<!-- 
====================================
ダッシュボード生成情報
====================================
生成日時: $currentDateTime
生成タイプ: $GenerationType
ファイル名: $FileName
タイムスタンプ: $timestamp
テンプレート: License_Analysis_Dashboard_Template_Clean.html
生成スクリプト: New-LicenseDashboard.ps1
====================================
-->
"@
    
    $updatedContent = $updatedContent -replace '(<head>)', "`$1`n$generationComment"
    
    # ヘッダーに生成情報を追加
    if ($GenerationType -eq "Timestamp") {
        $headerAddition = @"
        <div class="subtitle" style="font-size: 14px; margin-top: 5px; opacity: 0.8;">
            📊 レポートID: $timestamp | 🕐 生成: $currentDateTime
        </div>
"@
        
        $updatedContent = $updatedContent -replace '(<div class="subtitle">分析実行日時: [^<]+</div>)', "`$1`n$headerAddition"
    }
    
    # フッターに詳細情報を追加
    $footerAddition = @"
        <div style="background: #f8f9fa; padding: 15px; border-radius: 4px; margin-top: 20px; font-size: 11px; color: #666;">
            <strong>📄 ファイル情報:</strong><br>
            🕐 生成タイムスタンプ: $timestamp<br>
            📁 ファイル名: $FileName<br>
            🔄 生成タイプ: $GenerationType<br>
            📖 テンプレート: License_Analysis_Dashboard_Template_Clean.html
        </div>
"@
    
    $updatedContent = $updatedContent -replace '(</div>\s*</body>)', "$footerAddition`n    `$1"
    
    return $updatedContent
}

try {
    Write-ColorMessage "🚀 Microsoft 365ライセンス分析ダッシュボード生成開始..." "Cyan"
    Write-ColorMessage "⚙️  生成タイプ: $FileNameType" "Gray"
    
    # ファイル名を決定
    $outputFileName = Get-OutputFileName -Type $FileNameType -Custom $CustomFileName
    Write-ColorMessage "📄 出力ファイル名: $outputFileName" "Green"
    
    # パス設定
    $scriptRoot = $PSScriptRoot
    
    # テンプレートパスの処理
    if ([System.IO.Path]::IsPathRooted($TemplateFile)) {
        $templatePath = $TemplateFile
    } else {
        $templatePath = Join-Path $scriptRoot $TemplateFile
    }
    
    $outputPath = Join-Path $scriptRoot "$OutputDirectory/$outputFileName"
    
    if ($VerboseOutput) {
        Write-ColorMessage "📍 テンプレートパス: $templatePath" "Gray"
        Write-ColorMessage "📍 出力パス: $outputPath" "Gray"
    }
    
    # テンプレートファイル確認
    if (-not (Test-Path $templatePath)) {
        Write-ColorMessage "❌ テンプレートファイルが見つかりません: $templatePath" "Red"
        Write-ColorMessage "💡 テンプレートファイルを生成しますか？ (Y/N): " "Yellow" -NoNewline
        $response = Read-Host
        if ($response -eq "Y" -or $response -eq "y") {
            Write-ColorMessage "🔄 テンプレートファイルを生成中..." "Yellow"
            & "$scriptRoot/Generate-LicenseDashboard-Final.ps1"
        } else {
            throw "テンプレートファイルが必要です"
        }
    }
    
    # 出力ディレクトリ作成
    $outputDir = Split-Path $outputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-ColorMessage "📁 出力ディレクトリ作成: $outputDir" "Green"
    }
    
    Write-ColorMessage "📖 テンプレート読み込み中..." "Yellow"
    
    # テンプレートファイルを読み込み
    $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
    
    # コンテンツを更新
    $updatedContent = Update-DashboardContent -Content $templateContent -FileName $outputFileName -GenerationType $FileNameType
    
    # ファイルに出力
    Write-ColorMessage "💾 ファイル生成中..." "Yellow"
    $updatedContent | Out-File -FilePath $outputPath -Encoding UTF8 -Force
    
    # 結果確認と統計表示
    if (Test-Path $outputPath) {
        $fileInfo = Get-Item $outputPath
        $templateInfo = Get-Item $templatePath
        
        Write-ColorMessage "`n✅ ダッシュボード生成成功!" "Green"
        Write-ColorMessage "📍 出力ファイル: $outputPath" "Green"
        
        if ($Verbose) {
            Write-ColorMessage "`n📊 ファイル詳細:" "Cyan"
            Write-ColorMessage "  📄 ファイル名: $outputFileName" "White"
            Write-ColorMessage "  📅 生成日時: $($fileInfo.CreationTime)" "Gray"
            Write-ColorMessage "  📏 ファイルサイズ: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" "Gray"
            Write-ColorMessage "  📖 テンプレートサイズ: $([math]::Round($templateInfo.Length / 1KB, 2)) KB" "Gray"
        }
        
        # ライセンス統計情報
        Write-ColorMessage "`n📊 ライセンス統計 (継承):" "Cyan"
        Write-ColorMessage "  📈 総ライセンス数: 508 (E3: 440 | Exchange: 50 | Basic: 18)" "White"
        Write-ColorMessage "  ✅ 使用中ライセンス: 463 (E3: 413 | Exchange: 49 | Basic: 1)" "Green"
        Write-ColorMessage "  ⚠️  未使用ライセンス: 45 (E3: 27 | Exchange: 1 | Basic: 17)" "Yellow"
        Write-ColorMessage "  📉 ライセンス利用率: 91.1% (良好)" "Green"
        
        # 生成情報
        Write-ColorMessage "`n🎯 生成情報:" "Cyan"
        Write-ColorMessage "  🔄 生成タイプ: $FileNameType" "White"
        Write-ColorMessage "  📄 出力ファイル: $outputFileName" "Green"
        Write-ColorMessage "  📖 テンプレート: License_Analysis_Dashboard_Template_Clean.html" "Gray"
        
        # ブラウザで開く
        if ($OpenInBrowser) {
            Write-ColorMessage "`n🌐 ブラウザで開いています..." "Cyan"
            try {
                Start-Process $outputPath
            } catch {
                Write-ColorMessage "⚠️ ブラウザで開けませんでした: $_" "Yellow"
            }
        }
        
        Write-ColorMessage "`n✨ 生成完了!" "Green"
        
        return @{
            FilePath = $outputPath
            FileName = $outputFileName
            GenerationType = $FileNameType
            FileSize = [math]::Round($fileInfo.Length / 1KB, 2)
            CreationTime = $fileInfo.CreationTime
        }
    } else {
        Write-ColorMessage "❌ ファイル生成に失敗しました" "Red"
        throw "出力ファイルが作成されませんでした"
    }
}
catch {
    Write-ColorMessage "❌ エラーが発生しました: $_" "Red"
    if ($VerboseOutput) {
        Write-ColorMessage "📍 スタックトレース: $($_.Exception.StackTrace)" "Red"
    }
    throw
}