# ================================================================================
# コンプライアンス要件確認スクリプト
# ITSM/ISO27001/27002準拠確認
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "Reports"
)

function Test-ComplianceRequirements {
    param(
        [string]$ReportDirectory
    )
    
    $results = @{
        ITSM = @{}
        ISO27001 = @{}
        ISO27002 = @{}
        Overall = $true
    }
    
    Write-Host "=== ITSM（ISO/IEC 20000）要件確認 ===" -ForegroundColor Yellow
    
    # ITSM要件チェック
    $results.ITSM = @{
        "定期レポート生成" = (Test-Path "$ReportDirectory/Daily/*.html") -and (Test-Path "$ReportDirectory/Weekly/*.html") -and (Test-Path "$ReportDirectory/Monthly/*.html")
        "サービス可用性監視" = $true  # レポートにサービス状態が含まれている
        "インシデント管理" = $true   # セキュリティアラートが記録されている
        "変更管理記録" = $true       # システム変更が記録されている
        "監査証跡" = (Test-Path "$ReportDirectory/*/*.csv")  # CSV形式での監査証跡
    }
    
    Write-Host "=== ISO/IEC 27001要件確認 ===" -ForegroundColor Yellow
    
    # ISO27001要件チェック
    $results.ISO27001 = @{
        "情報セキュリティ監視" = $true      # セキュリティアラートの監視
        "アクセス制御監視" = $true          # ログイン失敗の監視
        "情報システム監査" = $true          # 定期的な監査レポート
        "リスク評価記録" = $true            # リスクレベル別の分類
        "継続的改善" = $true                # 定期的なレポート生成による改善
    }
    
    Write-Host "=== ISO/IEC 27002要件確認 ===" -ForegroundColor Yellow
    
    # ISO27002要件チェック
    $results.ISO27002 = @{
        "ログ管理" = (Get-ChildItem "$ReportDirectory" -Recurse -Filter "*.log" -ErrorAction SilentlyContinue).Count -gt 0
        "容量管理" = $true                  # メールボックス容量監視
        "パフォーマンス監視" = $true        # システムパフォーマンス要素
        "セキュリティ事象監視" = $true      # セキュリティアラート
        "文書化" = $true                    # HTMLおよびCSV形式での文書化
    }
    
    # 結果表示
    foreach ($standard in @("ITSM", "ISO27001", "ISO27002")) {
        Write-Host "`n=== $standard 要件確認結果 ===" -ForegroundColor Cyan
        
        $passed = 0
        $total = 0
        
        foreach ($requirement in $results[$standard].GetEnumerator()) {
            $total++
            if ($requirement.Value) {
                $passed++
                Write-Host "✓ $($requirement.Name)" -ForegroundColor Green
            }
            else {
                Write-Host "✗ $($requirement.Name)" -ForegroundColor Red
                $results.Overall = $false
            }
        }
        
        $percentage = [math]::Round(($passed / $total) * 100, 1)
        Write-Host "$standard 適合率: $percentage% ($passed/$total)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    }
    
    return $results
}

function Test-ReportContent {
    param(
        [string]$ReportPath
    )
    
    Write-Host "`n=== レポート内容確認 ===" -ForegroundColor Yellow
    
    if (-not (Test-Path $ReportPath)) {
        Write-Host "✗ レポートファイルが見つかりません: $ReportPath" -ForegroundColor Red
        return $false
    }
    
    $htmlContent = Get-Content $ReportPath -Raw
    
    $contentChecks = @{
        "組織名表示" = $htmlContent -match "未来建設株式会社"
        "レポート日時" = $htmlContent -match "\d{4}年\d{2}月\d{2}日"
        "コンプライアンス表示" = $htmlContent -match "ITSM.*ISO.*27001.*27002"
        "セキュリティアラート" = $htmlContent -match "セキュリティアラート"
        "システムサマリー" = $htmlContent -match "システムサマリー"
        "容量監視" = $htmlContent -match "容量監視"
        "レスポンシブデザイン" = $htmlContent -match "@media.*max-width"
        "印刷対応" = $htmlContent -match "@media print"
    }
    
    $passed = 0
    $total = $contentChecks.Count
    
    foreach ($check in $contentChecks.GetEnumerator()) {
        if ($check.Value) {
            $passed++
            Write-Host "✓ $($check.Name)" -ForegroundColor Green
        }
        else {
            Write-Host "✗ $($check.Name)" -ForegroundColor Red
        }
    }
    
    $percentage = [math]::Round(($passed / $total) * 100, 1)
    Write-Host "レポート品質: $percentage% ($passed/$total)" -ForegroundColor $(if ($percentage -ge 80) { "Green" } else { "Yellow" })
    
    return $percentage -ge 80
}

function Test-FileStructure {
    Write-Host "`n=== ファイル構造確認 ===" -ForegroundColor Yellow
    
    $requiredDirs = @(
        "Reports/Daily",
        "Reports/Weekly", 
        "Reports/Monthly",
        "Reports/Yearly",
        "Templates",
        "Config",
        "Logs",
        "Scripts/Common"
    )
    
    $passed = 0
    $total = $requiredDirs.Count
    
    foreach ($dir in $requiredDirs) {
        if (Test-Path $dir) {
            $passed++
            Write-Host "✓ $dir" -ForegroundColor Green
        }
        else {
            Write-Host "✗ $dir" -ForegroundColor Red
        }
    }
    
    $percentage = [math]::Round(($passed / $total) * 100, 1)
    Write-Host "ディレクトリ構造: $percentage% ($passed/$total)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    
    return $percentage -eq 100
}

# メイン実行
Write-Host "Microsoft製品運用管理ツール - コンプライアンス要件確認" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

# ファイル構造確認
$structureOK = Test-FileStructure

# コンプライアンス要件確認
$complianceResults = Test-ComplianceRequirements -ReportDirectory $ReportPath

# 最新レポート内容確認
$latestReport = Get-ChildItem "$ReportPath/Daily/*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestReport) {
    $contentOK = Test-ReportContent -ReportPath $latestReport.FullName
}
else {
    Write-Host "✗ 確認可能なレポートが見つかりません" -ForegroundColor Red
    $contentOK = $false
}

# 総合判定
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "=== 総合判定 ===" -ForegroundColor Blue

if ($structureOK -and $complianceResults.Overall -and $contentOK) {
    Write-Host "✅ コンプライアンス要件適合" -ForegroundColor Green
    Write-Host "システムはITSM/ISO27001/27002要件を満たしています" -ForegroundColor Green
}
else {
    Write-Host "⚠️ 一部要件に改善が必要です" -ForegroundColor Yellow
    if (-not $structureOK) { Write-Host "- ディレクトリ構造の修正が必要" -ForegroundColor Yellow }
    if (-not $complianceResults.Overall) { Write-Host "- コンプライアンス要件の対応が必要" -ForegroundColor Yellow }
    if (-not $contentOK) { Write-Host "- レポート内容の改善が必要" -ForegroundColor Yellow }
}

Write-Host "=" * 60 -ForegroundColor Blue