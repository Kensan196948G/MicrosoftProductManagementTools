# CSV文字化け修正ツール
# 既存のUTF-8 CSVファイルをBOM付きUTF-8に変換

param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$FixAllReports = $false
)

function Convert-CsvToBomUtf8 {
    param(
        [string]$FilePath
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            Write-Host "❌ ファイルが見つかりません: $FilePath" -ForegroundColor Red
            return $false
        }
        
        Write-Host "🔧 修正中: $FilePath" -ForegroundColor Yellow
        
        # 現在の内容を読み取り
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        
        # バックアップ作成
        $backupPath = "$FilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $FilePath $backupPath
        Write-Host "  📄 バックアップ作成: $backupPath" -ForegroundColor Gray
        
        # BOM付きUTF-8で再書き込み
        $encoding = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($FilePath, $content, $encoding)
        
        Write-Host "  ✅ 修正完了: $FilePath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ❌ 修正エラー: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "📋 CSV文字化け修正ツール" -ForegroundColor Cyan
Write-Host ""

if ($FixAllReports) {
    Write-Host "🔍 Reports ディレクトリの全CSVファイルを検索中..." -ForegroundColor Yellow
    
    $csvFiles = Get-ChildItem -Path "Reports" -Recurse -Filter "*.csv" | Where-Object { $_.Name -notlike "*.backup.*" }
    
    Write-Host "📊 $($csvFiles.Count) 個のCSVファイルが見つかりました" -ForegroundColor Cyan
    Write-Host ""
    
    $fixedCount = 0
    foreach ($file in $csvFiles) {
        if (Convert-CsvToBomUtf8 -FilePath $file.FullName) {
            $fixedCount++
        }
    }
    
    Write-Host ""
    Write-Host "🎉 修正完了: $fixedCount / $($csvFiles.Count) ファイル" -ForegroundColor Green
    
} elseif ($CsvPath -ne "") {
    Write-Host "🔧 指定ファイルを修正します: $CsvPath" -ForegroundColor Yellow
    
    if (Convert-CsvToBomUtf8 -FilePath $CsvPath) {
        Write-Host ""
        Write-Host "🎉 修正が完了しました！" -ForegroundColor Green
        Write-Host "ExcelやLibreOfficeで正しく日本語が表示されるはずです。" -ForegroundColor Cyan
    }
    
} else {
    Write-Host "使用方法:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "# 特定のCSVファイルを修正:" -ForegroundColor Cyan
    Write-Host "pwsh -File fix-csv-encoding.ps1 -CsvPath 'Reports\Weekly\Spam_Phishing_Analysis_20250612_201022.csv'" -ForegroundColor Green
    Write-Host ""
    Write-Host "# Reports内の全CSVファイルを修正:" -ForegroundColor Cyan
    Write-Host "pwsh -File fix-csv-encoding.ps1 -FixAllReports" -ForegroundColor Green
    Write-Host ""
    
    # 最新のスパム分析CSVファイルを自動検出
    $latestSpamCsv = Get-ChildItem -Path "Reports" -Recurse -Filter "Spam_Phishing_Analysis_*.csv" | 
        Where-Object { $_.Name -notlike "*.backup.*" } | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1
    
    if ($latestSpamCsv) {
        Write-Host "💡 最新のスパム分析CSV: $($latestSpamCsv.FullName)" -ForegroundColor Yellow
        $fix = Read-Host "このファイルを修正しますか？ (y/N)"
        
        if ($fix -eq "y" -or $fix -eq "Y") {
            if (Convert-CsvToBomUtf8 -FilePath $latestSpamCsv.FullName) {
                Write-Host ""
                Write-Host "🎉 修正が完了しました！" -ForegroundColor Green
                Write-Host "Excelで開いて日本語表示を確認してください。" -ForegroundColor Cyan
            }
        }
    }
}

Write-Host ""
Write-Host "📝 注意事項:" -ForegroundColor Yellow
Write-Host "• 元のファイルは .backup.日時 の形式でバックアップされます" -ForegroundColor Gray
Write-Host "• BOM付きUTF-8は日本語版Excel/LibreOfficeで正しく表示されます" -ForegroundColor Gray
Write-Host "• 今後生成されるCSVファイルは自動的にBOM付きUTF-8で出力されます" -ForegroundColor Gray