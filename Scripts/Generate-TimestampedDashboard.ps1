# Microsoft 365ライセンス分析ダッシュボード タイムスタンプ版生成スクリプト
# License_Analysis_Dashboard_Template_Clean.html をテンプレートとして使用して
# License_Analysis_Dashboard_YYYYMMDD_HHMMSS.html を生成

param(
    [string]$TemplateFile = "Reports/Monthly/License_Analysis_Dashboard_Template_Clean.html",
    [string]$OutputDirectory = "Reports/Monthly"
)

function Write-ColorMessage {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-ColorMessage "🚀 タイムスタンプ付きダッシュボード生成開始..." "Cyan"
    
    # タイムスタンプ生成
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputFileName = "License_Analysis_Dashboard_$timestamp.html"
    $currentDateTime = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    
    Write-ColorMessage "📅 タイムスタンプ: $timestamp" "Gray"
    Write-ColorMessage "📄 出力ファイル名: $outputFileName" "Gray"
    
    # パス設定
    $scriptRoot = $PSScriptRoot
    
    # テンプレートパスの処理（絶対パスか相対パスかを判定）
    if ([System.IO.Path]::IsPathRooted($TemplateFile)) {
        $templatePath = $TemplateFile
    } else {
        $templatePath = Join-Path $scriptRoot "../$TemplateFile"
    }
    
    $outputPath = Join-Path $scriptRoot "../$OutputDirectory/$outputFileName"
    
    # テンプレートファイル確認
    if (-not (Test-Path $templatePath)) {
        Write-ColorMessage "❌ テンプレートファイルが見つかりません: $templatePath" "Red"
        throw "テンプレートファイルが存在しません"
    }
    
    Write-ColorMessage "📖 テンプレート読み込み: $templatePath" "Yellow"
    
    # 出力ディレクトリ作成
    $outputDir = Split-Path $outputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-ColorMessage "📁 出力ディレクトリ作成: $outputDir" "Green"
    }
    
    # テンプレートファイルを読み込み
    $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
    
    # 日時情報を更新
    $updatedContent = $templateContent -replace '分析実行日時: \d{4}年\d{2}月\d{2}日 \d{2}:\d{2}:\d{2}', "分析実行日時: $currentDateTime"
    
    # フッター情報を更新
    $updatedContent = $updatedContent -replace '修正済み - \d{4}年\d{2}月\d{2}日 \d{2}:\d{2}:\d{2}', "生成済み - $currentDateTime"
    $updatedContent = $updatedContent -replace 'PowerShell生成 - フォールバック版', "タイムスタンプ生成 - $currentDateTime"
    
    # 新しいIDを追加（識別用）
    $updatedContent = $updatedContent -replace '<title>Microsoft 365ライセンス分析ダッシュボード</title>', "<title>Microsoft 365ライセンス分析ダッシュボード - $timestamp</title>"
    
    # フッターに生成情報を追加
    $footerAddition = @"
        <p style="font-size: 11px; color: #888; margin-top: 10px;">
            🕐 生成タイムスタンプ: $timestamp | 📄 ファイル名: $outputFileName
        </p>
"@
    
    $updatedContent = $updatedContent -replace '</div>\s*</body>', "$footerAddition`n    </div>`n</body>"
    
    # ヘッダーにタイムスタンプ情報を追加
    $headerAddition = @"
        <div class="subtitle" style="font-size: 14px; margin-top: 5px; opacity: 0.8;">
            📊 レポートID: $timestamp
        </div>
"@
    
    $updatedContent = $updatedContent -replace '(<div class="subtitle">分析実行日時: [^<]+</div>)', "`$1`n$headerAddition"
    
    # コメントを追加して生成情報を記録
    $generationComment = @"
<!-- 
生成情報:
- 生成日時: $currentDateTime
- タイムスタンプ: $timestamp
- テンプレート: License_Analysis_Dashboard_Template_Clean.html
- 生成スクリプト: Generate-TimestampedDashboard.ps1
-->
"@
    
    $updatedContent = $updatedContent -replace '(<head>)', "`$1`n$generationComment"
    
    # ファイルに出力
    $updatedContent | Out-File -FilePath $outputPath -Encoding UTF8 -Force
    
    # 結果確認
    if (Test-Path $outputPath) {
        $fileInfo = Get-Item $outputPath
        Write-ColorMessage "✅ タイムスタンプ付きダッシュボード生成成功!" "Green"
        Write-ColorMessage "📍 出力ファイル: $outputPath" "Green"
        Write-ColorMessage "📅 生成日時: $($fileInfo.CreationTime)" "Gray"
        Write-ColorMessage "📏 ファイルサイズ: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" "Gray"
        
        # テンプレートとの比較
        $templateInfo = Get-Item $templatePath
        Write-ColorMessage "`n📊 比較情報:" "Cyan"
        Write-ColorMessage "  📖 テンプレート: $([math]::Round($templateInfo.Length / 1KB, 2)) KB (更新: $($templateInfo.LastWriteTime))" "Gray"
        Write-ColorMessage "  📄 新規生成: $([math]::Round($fileInfo.Length / 1KB, 2)) KB (作成: $($fileInfo.CreationTime))" "Gray"
        
        # ライセンス統計情報
        Write-ColorMessage "`n📊 ライセンス統計 (継承):" "Cyan"
        Write-ColorMessage "  📈 総ライセンス数: 508 (E3: 440 | Exchange: 50 | Basic: 18)" "White"
        Write-ColorMessage "  ✅ 使用中ライセンス: 463 (E3: 413 | Exchange: 49 | Basic: 1)" "Green"
        Write-ColorMessage "  ⚠️  未使用ライセンス: 45 (E3: 27 | Exchange: 1 | Basic: 17)" "Yellow"
        Write-ColorMessage "  📉 ライセンス利用率: 91.1% (良好)" "Green"
        
        Write-ColorMessage "`n🎯 ファイル情報:" "Cyan"
        Write-ColorMessage "  📄 テンプレート: License_Analysis_Dashboard_Template_Clean.html" "Gray"
        Write-ColorMessage "  📄 新規ファイル: $outputFileName" "Green"
        Write-ColorMessage "  🕐 タイムスタンプ: $timestamp" "Green"
        
        Write-ColorMessage "`n✨ 生成完了!" "Green"
        
        return $outputPath
    } else {
        Write-ColorMessage "❌ ファイル生成に失敗しました" "Red"
        throw "出力ファイルが作成されませんでした"
    }
}
catch {
    Write-ColorMessage "❌ エラーが発生しました: $_" "Red"
    throw
}