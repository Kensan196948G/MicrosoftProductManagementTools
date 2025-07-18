#Requires -Version 5.1

<#
.SYNOPSIS
Microsoft 365管理ツール - 包括的テストカバレッジ分析

.DESCRIPTION
Dev2 - Test/QA Developerによる包括的テストカバレッジ分析スクリプト。
現在のテストカバレッジを測定し、80%以上のカバレッジ達成に向けた改善提案を提供します。

.NOTES
Version: 2025.7.18.1
Author: Dev2 - Test/QA Developer
Framework: Pester 5.3.0+, PowerShell 5.1+
Security: ISO/IEC 27001準拠のセキュリティ要件
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = "E:\MicrosoftProductManagementTools",
    [string]$OutputPath = "TestReports",
    [switch]$GenerateReport = $true,
    [switch]$DetailedAnalysis = $true
)

# 実行開始
$AnalysisStartTime = Get-Date
$SessionId = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "🔍 Microsoft 365管理ツール - テストカバレッジ分析開始" -ForegroundColor Cyan
Write-Host "分析セッション ID: $SessionId" -ForegroundColor Yellow
Write-Host "プロジェクトルート: $ProjectRoot" -ForegroundColor Gray
Write-Host ""

# 出力ディレクトリ作成
$OutputDir = Join-Path $PSScriptRoot $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# カバレッジ分析結果
$CoverageResults = @{
    ProjectStructure = @()
    TestFiles = @()
    SourceFiles = @()
    Coverage = @()
    UncoveredFiles = @()
    Recommendations = @()
    SecurityGaps = @()
    PerformanceGaps = @()
    ComplianceGaps = @()
}

# ヘルパー関数: ログ出力
function Write-AnalysisLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Success" { "Green" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

Write-AnalysisLog "プロジェクト構造解析を開始します" -Level "Info"

# 1. プロジェクト構造の解析
$ProjectDirectories = @(
    "Apps",
    "Scripts/Common",
    "Scripts/AD", 
    "Scripts/EXO",
    "Scripts/EntraID",
    "Tests",
    "TestScripts"
)

foreach ($dir in $ProjectDirectories) {
    $fullPath = Join-Path $ProjectRoot $dir
    if (Test-Path $fullPath) {
        $files = Get-ChildItem -Path $fullPath -Filter "*.ps1" -Recurse
        $modules = Get-ChildItem -Path $fullPath -Filter "*.psm1" -Recurse
        
        $CoverageResults.ProjectStructure += [PSCustomObject]@{
            Directory = $dir
            Path = $fullPath
            ScriptFiles = $files.Count
            ModuleFiles = $modules.Count
            TotalFiles = $files.Count + $modules.Count
            LastModified = if ($files -or $modules) { 
                ($files + $modules | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime 
            } else { 
                $null 
            }
        }
        
        Write-AnalysisLog "解析完了: $dir (スクリプト: $($files.Count), モジュール: $($modules.Count))" -Level "Success"
    } else {
        Write-AnalysisLog "ディレクトリが見つかりません: $dir" -Level "Warning"
    }
}

# 2. テストファイルの詳細解析
Write-AnalysisLog "テストファイルの詳細解析を開始します" -Level "Info"

$TestDirectories = @(
    (Join-Path $ProjectRoot "Tests"),
    (Join-Path $ProjectRoot "TestScripts")
)

foreach ($testDir in $TestDirectories) {
    if (Test-Path $testDir) {
        $testFiles = Get-ChildItem -Path $testDir -Filter "*.ps1" -Recurse
        
        foreach ($testFile in $testFiles) {
            $content = Get-Content $testFile.FullName -Raw -ErrorAction SilentlyContinue
            $lineCount = ($content -split "`n").Count
            
            # Pester関数の検出
            $describeCalls = ($content | Select-String "Describe\s+" -AllMatches).Matches.Count
            $contextCalls = ($content | Select-String "Context\s+" -AllMatches).Matches.Count
            $itCalls = ($content | Select-String "It\s+" -AllMatches).Matches.Count
            
            # テストタグの検出
            $tags = @()
            if ($content -match '-Tags\s+@\("([^"]+)"\)') {
                $tags = $Matches[1] -split '",\s*"' | ForEach-Object { $_.Trim('"') }
            }
            
            $CoverageResults.TestFiles += [PSCustomObject]@{
                FileName = $testFile.Name
                FullPath = $testFile.FullName
                RelativePath = $testFile.FullName.Replace($ProjectRoot, "").TrimStart('\')
                LineCount = $lineCount
                DescribeBlocks = $describeCalls
                ContextBlocks = $contextCalls
                TestCases = $itCalls
                Tags = $tags -join ", "
                LastModified = $testFile.LastWriteTime
                IsPesterTest = $content -match "Describe|Context|It"
            }
        }
    }
}

# 3. ソースファイルの解析
Write-AnalysisLog "ソースファイルの解析を開始します" -Level "Info"

$SourceDirectories = @(
    (Join-Path $ProjectRoot "Apps"),
    (Join-Path $ProjectRoot "Scripts")
)

foreach ($sourceDir in $SourceDirectories) {
    if (Test-Path $sourceDir) {
        $sourceFiles = Get-ChildItem -Path $sourceDir -Include "*.ps1", "*.psm1" -Recurse | 
                      Where-Object { $_.Directory.Name -notmatch "Test" }
        
        foreach ($sourceFile in $sourceFiles) {
            $content = Get-Content $sourceFile.FullName -Raw -ErrorAction SilentlyContinue
            $lineCount = ($content -split "`n").Count
            
            # 関数の検出
            $functions = ($content | Select-String "function\s+[\w-]+\s*\{" -AllMatches).Matches.Count
            
            # コメント率の計算
            $commentLines = ($content | Select-String "^\s*#" -AllMatches).Matches.Count
            $commentRatio = if ($lineCount -gt 0) { [math]::Round(($commentLines / $lineCount) * 100, 2) } else { 0 }
            
            # セキュリティパターンの検出
            $hasSecurityPatterns = $content -match "(password|secret|token|key|credential)" -and 
                                 $content -notmatch "# TODO|# FIXME|placeholder"
            
            $CoverageResults.SourceFiles += [PSCustomObject]@{
                FileName = $sourceFile.Name
                FullPath = $sourceFile.FullName
                RelativePath = $sourceFile.FullName.Replace($ProjectRoot, "").TrimStart('\')
                LineCount = $lineCount
                FunctionCount = $functions
                CommentRatio = $commentRatio
                HasSecurityPatterns = $hasSecurityPatterns
                LastModified = $sourceFile.LastWriteTime
                FileType = $sourceFile.Extension
            }
        }
    }
}

# 4. テストカバレッジの計算
Write-AnalysisLog "テストカバレッジの計算を開始します" -Level "Info"

$totalSourceFiles = $CoverageResults.SourceFiles.Count
$totalTestFiles = ($CoverageResults.TestFiles | Where-Object { $_.IsPesterTest }).Count

# カバレッジマッピング
foreach ($sourceFile in $CoverageResults.SourceFiles) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile.FileName)
    $matchingTests = $CoverageResults.TestFiles | Where-Object { 
        $_.FileName -match $baseName -or 
        $_.FullPath -match ($sourceFile.RelativePath -replace "\\", "\\").Replace(".ps1", "").Replace(".psm1", "") 
    }
    
    $isCovered = $matchingTests.Count -gt 0
    $testCount = $matchingTests.Count
    $testCases = ($matchingTests | Measure-Object TestCases -Sum).Sum
    
    if (-not $isCovered) {
        $CoverageResults.UncoveredFiles += $sourceFile
    }
    
    $CoverageResults.Coverage += [PSCustomObject]@{
        SourceFile = $sourceFile.FileName
        SourcePath = $sourceFile.RelativePath
        IsCovered = $isCovered
        TestFileCount = $testCount
        TestCaseCount = $testCases
        MatchingTests = ($matchingTests.FileName -join "; ")
        CoverageType = if ($isCovered) { 
            if ($testCases -ge 5) { "High" } 
            elseif ($testCases -ge 2) { "Medium" } 
            else { "Low" } 
        } else { "None" }
    }
}

# カバレッジ統計の計算
$coveredFiles = ($CoverageResults.Coverage | Where-Object { $_.IsCovered }).Count
$coveragePercentage = if ($totalSourceFiles -gt 0) { 
    [math]::Round(($coveredFiles / $totalSourceFiles) * 100, 2) 
} else { 0 }

# 5. 改善提案の生成
Write-AnalysisLog "改善提案を生成しています" -Level "Info"

# 一般的な推奨事項
if ($coveragePercentage -lt 80) {
    $CoverageResults.Recommendations += "テストカバレッジが80%未満です ($coveragePercentage%)。追加のテストケースが必要です。"
}

if ($CoverageResults.UncoveredFiles.Count -gt 0) {
    $CoverageResults.Recommendations += "$($CoverageResults.UncoveredFiles.Count) 個のファイルにテストがありません。"
    $CoverageResults.Recommendations += "未カバーファイル: $($CoverageResults.UncoveredFiles[0..4].FileName -join ', ')$(if ($CoverageResults.UncoveredFiles.Count -gt 5) { ', ...' })"
}

# セキュリティギャップの特定
$securityFiles = $CoverageResults.SourceFiles | Where-Object { $_.HasSecurityPatterns }
foreach ($secFile in $securityFiles) {
    $hasSecurityTest = $CoverageResults.TestFiles | Where-Object { 
        $_.FileName -match "Security|Auth" -and $_.FullPath -match $secFile.FileName.Replace(".ps1", "").Replace(".psm1", "")
    }
    
    if (-not $hasSecurityTest) {
        $CoverageResults.SecurityGaps += "セキュリティパターンを含むファイル '$($secFile.FileName)' にセキュリティテストがありません。"
    }
}

# パフォーマンスギャップの特定
$largeFiles = $CoverageResults.SourceFiles | Where-Object { $_.LineCount -gt 500 }
foreach ($largeFile in $largeFiles) {
    $hasPerformanceTest = $CoverageResults.TestFiles | Where-Object { 
        $_.FileName -match "Performance|Load|Memory" -and $_.FullPath -match $largeFile.FileName.Replace(".ps1", "").Replace(".psm1", "")
    }
    
    if (-not $hasPerformanceTest) {
        $CoverageResults.PerformanceGaps += "大型ファイル '$($largeFile.FileName)' ($($largeFile.LineCount) 行) にパフォーマンステストがありません。"
    }
}

# ISO/IEC 27001コンプライアンスギャップ
$compliancePatterns = @("audit", "log", "security", "compliance", "authentication")
foreach ($pattern in $compliancePatterns) {
    $complianceFiles = $CoverageResults.SourceFiles | Where-Object { $_.FileName -match $pattern }
    foreach ($compFile in $complianceFiles) {
        $hasComplianceTest = $CoverageResults.TestFiles | Where-Object { 
            $_.Tags -match "ISO27001|Compliance|Audit" -and $_.FullPath -match $compFile.FileName.Replace(".ps1", "").Replace(".psm1", "")
        }
        
        if (-not $hasComplianceTest) {
            $CoverageResults.ComplianceGaps += "コンプライアンス関連ファイル '$($compFile.FileName)' にISO/IEC 27001準拠テストがありません。"
        }
    }
}

# 6. 結果の表示
$AnalysisEndTime = Get-Date
$TotalDuration = ($AnalysisEndTime - $AnalysisStartTime).TotalSeconds

Write-Host ""
Write-Host "=== テストカバレッジ分析結果 ===" -ForegroundColor Cyan
Write-Host "分析時間: $([math]::Round($TotalDuration, 2)) 秒" -ForegroundColor White
Write-Host ""

Write-Host "📊 統計情報:" -ForegroundColor Yellow
Write-Host "  ソースファイル数: $totalSourceFiles" -ForegroundColor White
Write-Host "  テストファイル数: $totalTestFiles" -ForegroundColor White
Write-Host "  カバレッジ率: $coveragePercentage%" -ForegroundColor $(if ($coveragePercentage -ge 80) { "Green" } else { "Red" })
Write-Host "  カバー済みファイル: $coveredFiles" -ForegroundColor Green
Write-Host "  未カバーファイル: $($CoverageResults.UncoveredFiles.Count)" -ForegroundColor Red
Write-Host ""

Write-Host "🎯 品質ギャップ:" -ForegroundColor Yellow
Write-Host "  セキュリティギャップ: $($CoverageResults.SecurityGaps.Count)" -ForegroundColor $(if ($CoverageResults.SecurityGaps.Count -eq 0) { "Green" } else { "Red" })
Write-Host "  パフォーマンスギャップ: $($CoverageResults.PerformanceGaps.Count)" -ForegroundColor $(if ($CoverageResults.PerformanceGaps.Count -eq 0) { "Green" } else { "Red" })
Write-Host "  コンプライアンスギャップ: $($CoverageResults.ComplianceGaps.Count)" -ForegroundColor $(if ($CoverageResults.ComplianceGaps.Count -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($CoverageResults.Recommendations.Count -gt 0) {
    Write-Host "📋 改善提案:" -ForegroundColor Yellow
    foreach ($recommendation in $CoverageResults.Recommendations) {
        Write-Host "  • $recommendation" -ForegroundColor White
    }
    Write-Host ""
}

# 7. レポート生成
if ($GenerateReport) {
    Write-AnalysisLog "詳細レポートを生成しています" -Level "Info"
    
    # CSV レポート
    $csvPath = Join-Path $OutputDir "test-coverage-analysis_$SessionId.csv"
    $CoverageResults.Coverage | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    
    # HTML レポート
    $htmlPath = Join-Path $OutputDir "test-coverage-analysis_$SessionId.html"
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>テストカバレッジ分析レポート - $SessionId</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1, h2, h3 { color: #2c3e50; }
        .metric { display: inline-block; margin: 10px; padding: 15px; border-radius: 5px; text-align: center; min-width: 120px; }
        .metric-high { background-color: #2ecc71; color: white; }
        .metric-medium { background-color: #f39c12; color: white; }
        .metric-low { background-color: #e74c3c; color: white; }
        .metric-info { background-color: #3498db; color: white; }
        .coverage-excellent { color: #2ecc71; font-weight: bold; }
        .coverage-good { color: #f39c12; font-weight: bold; }
        .coverage-poor { color: #e74c3c; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #34495e; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .recommendation { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .security-gap { background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 10px; margin: 5px 0; border-radius: 5px; }
        .performance-gap { background-color: #d1ecf1; border: 1px solid #bee5eb; padding: 10px; margin: 5px 0; border-radius: 5px; }
        .compliance-gap { background-color: #d4edda; border: 1px solid #c3e6cb; padding: 10px; margin: 5px 0; border-radius: 5px; }
        .progress-bar { width: 100%; background-color: #e0e0e0; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 20px; background-color: #4caf50; text-align: center; line-height: 20px; color: white; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 テストカバレッジ分析レポート</h1>
        <p><strong>分析セッション:</strong> $SessionId</p>
        <p><strong>実行時間:</strong> $([math]::Round($TotalDuration, 2)) 秒</p>
        <p><strong>分析日時:</strong> $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
        
        <h2>📊 カバレッジ概要</h2>
        <div>
            <div class="metric metric-info">
                <div style="font-size: 24px;">$totalSourceFiles</div>
                <div>ソースファイル</div>
            </div>
            <div class="metric metric-info">
                <div style="font-size: 24px;">$totalTestFiles</div>
                <div>テストファイル</div>
            </div>
            <div class="metric $(if ($coveragePercentage -ge 80) { 'metric-high' } elseif ($coveragePercentage -ge 60) { 'metric-medium' } else { 'metric-low' })">
                <div style="font-size: 24px;">$coveragePercentage%</div>
                <div>カバレッジ率</div>
            </div>
            <div class="metric metric-high">
                <div style="font-size: 24px;">$coveredFiles</div>
                <div>カバー済み</div>
            </div>
            <div class="metric metric-low">
                <div style="font-size: 24px;">$($CoverageResults.UncoveredFiles.Count)</div>
                <div>未カバー</div>
            </div>
        </div>
        
        <h3>カバレッジ進捗</h3>
        <div class="progress-bar">
            <div class="progress-fill" style="width: $coveragePercentage%;">$coveragePercentage%</div>
        </div>
        
        <h2>🎯 品質ギャップ分析</h2>
        <div>
            <div class="metric $(if ($CoverageResults.SecurityGaps.Count -eq 0) { 'metric-high' } else { 'metric-low' })">
                <div style="font-size: 24px;">$($CoverageResults.SecurityGaps.Count)</div>
                <div>セキュリティギャップ</div>
            </div>
            <div class="metric $(if ($CoverageResults.PerformanceGaps.Count -eq 0) { 'metric-high' } else { 'metric-low' })">
                <div style="font-size: 24px;">$($CoverageResults.PerformanceGaps.Count)</div>
                <div>パフォーマンスギャップ</div>
            </div>
            <div class="metric $(if ($CoverageResults.ComplianceGaps.Count -eq 0) { 'metric-high' } else { 'metric-low' })">
                <div style="font-size: 24px;">$($CoverageResults.ComplianceGaps.Count)</div>
                <div>コンプライアンスギャップ</div>
            </div>
        </div>
        
        <h2>📋 改善提案</h2>
"@
    
    if ($CoverageResults.Recommendations.Count -gt 0) {
        foreach ($recommendation in $CoverageResults.Recommendations) {
            $htmlContent += "<div class='recommendation'>💡 $recommendation</div>`n"
        }
    } else {
        $htmlContent += "<div class='recommendation'>✅ 改善提案はありません。現在のテスト状況は良好です。</div>`n"
    }
    
    # セキュリティギャップ
    if ($CoverageResults.SecurityGaps.Count -gt 0) {
        $htmlContent += "<h3>🔒 セキュリティギャップ</h3>`n"
        foreach ($gap in $CoverageResults.SecurityGaps) {
            $htmlContent += "<div class='security-gap'>🚨 $gap</div>`n"
        }
    }
    
    # パフォーマンスギャップ
    if ($CoverageResults.PerformanceGaps.Count -gt 0) {
        $htmlContent += "<h3>⚡ パフォーマンスギャップ</h3>`n"
        foreach ($gap in $CoverageResults.PerformanceGaps) {
            $htmlContent += "<div class='performance-gap'>📊 $gap</div>`n"
        }
    }
    
    # コンプライアンスギャップ
    if ($CoverageResults.ComplianceGaps.Count -gt 0) {
        $htmlContent += "<h3>📜 ISO/IEC 27001 コンプライアンスギャップ</h3>`n"
        foreach ($gap in $CoverageResults.ComplianceGaps) {
            $htmlContent += "<div class='compliance-gap'>⚖️ $gap</div>`n"
        }
    }
    
    # 詳細テーブル
    $htmlContent += @"
        <h2>📁 ファイル別カバレッジ詳細</h2>
        <table>
            <tr>
                <th>ソースファイル</th>
                <th>カバレッジ</th>
                <th>テストファイル数</th>
                <th>テストケース数</th>
                <th>カバレッジタイプ</th>
                <th>対応テスト</th>
            </tr>
"@
    
    foreach ($coverage in $CoverageResults.Coverage) {
        $coverageClass = switch ($coverage.CoverageType) {
            "High" { "coverage-excellent" }
            "Medium" { "coverage-good" }
            "Low" { "coverage-good" }
            "None" { "coverage-poor" }
        }
        
        $coveredIcon = if ($coverage.IsCovered) { "✅" } else { "❌" }
        
        $htmlContent += @"
            <tr>
                <td>$($coverage.SourceFile)</td>
                <td class="$coverageClass">$coveredIcon $(if ($coverage.IsCovered) { "カバー済み" } else { "未カバー" })</td>
                <td>$($coverage.TestFileCount)</td>
                <td>$($coverage.TestCaseCount)</td>
                <td class="$coverageClass">$($coverage.CoverageType)</td>
                <td>$($coverage.MatchingTests)</td>
            </tr>
"@
    }
    
    $htmlContent += @"
        </table>
        
        <h2>📈 プロジェクト構造概要</h2>
        <table>
            <tr>
                <th>ディレクトリ</th>
                <th>スクリプトファイル</th>
                <th>モジュールファイル</th>
                <th>合計ファイル</th>
                <th>最終更新</th>
            </tr>
"@
    
    foreach ($structure in $CoverageResults.ProjectStructure) {
        $lastModified = if ($structure.LastModified) { 
            $structure.LastModified.ToString("yyyy/MM/dd HH:mm") 
        } else { 
            "N/A" 
        }
        
        $htmlContent += @"
            <tr>
                <td>$($structure.Directory)</td>
                <td>$($structure.ScriptFiles)</td>
                <td>$($structure.ModuleFiles)</td>
                <td>$($structure.TotalFiles)</td>
                <td>$lastModified</td>
            </tr>
"@
    }
    
    $htmlContent += @"
        </table>
        
        <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #7f8c8d;">
            <p>Generated by Dev2 - Test/QA Developer | Microsoft 365管理ツール テストカバレッジ分析</p>
            <p>Report ID: $SessionId | Generated: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
        </footer>
    </div>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
    
    Write-AnalysisLog "レポートを生成しました:" -Level "Success"
    Write-AnalysisLog "  CSV: $csvPath" -Level "Info"
    Write-AnalysisLog "  HTML: $htmlPath" -Level "Info"
}

# 終了ステータス
Write-Host ""
if ($coveragePercentage -ge 80) {
    Write-Host "🟢 テストカバレッジは目標を達成しています ($coveragePercentage%)" -ForegroundColor Green
    $exitCode = 0
} else {
    Write-Host "🔴 テストカバレッジが目標未達です ($coveragePercentage% < 80%)" -ForegroundColor Red
    $exitCode = 1
}

Write-Host "分析完了: $([math]::Round($TotalDuration, 2)) 秒" -ForegroundColor Gray

# カバレッジ結果をJSONで出力（CI/CD統合用）
$jsonPath = Join-Path $OutputDir "coverage-results_$SessionId.json"
$CoverageResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8

exit $exitCode