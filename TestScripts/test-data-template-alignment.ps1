# データ構造とHTMLテンプレートの整合性検証テスト

Write-Host "🔍 データ構造とHTMLテンプレートの整合性検証テスト開始" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\HTMLTemplateEngine.psm1" -Force -DisableNameChecking -Global

# 既存の接続確認
$graphContext = Get-MgContext -ErrorAction SilentlyContinue
if (-not $graphContext) {
    Write-Host "🔐 Microsoft 365に接続中..." -ForegroundColor Yellow
    $connectionResult = Connect-M365Services
    if (-not $connectionResult.GraphConnected) {
        Write-Host "❌ 接続に失敗しました" -ForegroundColor Red
        exit 1
    }
}

# テストするデータタイプ
$testDataTypes = @(
    @{ Type = "Users"; TemplateName = "EntraIDManagement\user-list.html" },
    @{ Type = "LicenseAnalysis"; TemplateName = "Analyticreport\license-analysis.html" },
    @{ Type = "DailyReport"; TemplateName = "Regularreports\daily-report.html" }
)

foreach ($test in $testDataTypes) {
    Write-Host "`n" + "="*60 -ForegroundColor Yellow
    Write-Host "📊 $($test.Type) データとテンプレートの整合性検証" -ForegroundColor Yellow
    Write-Host "="*60 -ForegroundColor Yellow
    
    # 1. 実際のデータを取得
    Write-Host "🔄 実際のデータを取得中..." -ForegroundColor Cyan
    try {
        switch ($test.Type) {
            "Users" { 
                $data = Get-M365AllUsers -MaxResults 5
                Write-Host "✅ ユーザーデータ取得成功: $($data.Count) 件" -ForegroundColor Green
            }
            "LicenseAnalysis" { 
                $data = Get-M365LicenseAnalysis
                Write-Host "✅ ライセンスデータ取得成功: $($data.Count) 件" -ForegroundColor Green
            }
            "DailyReport" { 
                $data = Get-M365DailyReport
                Write-Host "✅ 日次レポートデータ取得成功: $($data.Count) 件" -ForegroundColor Green
            }
        }
        
        # 2. データ構造の詳細分析
        Write-Host "`n📋 データ構造の詳細分析:" -ForegroundColor Cyan
        if ($data.Count -gt 0) {
            $properties = $data[0].PSObject.Properties.Name
            Write-Host "   プロパティ数: $($properties.Count)" -ForegroundColor White
            Write-Host "   プロパティ一覧:" -ForegroundColor White
            foreach ($prop in $properties) {
                $value = $data[0].$prop
                Write-Host "     • $prop : $value" -ForegroundColor Gray
            }
        }
        
        # 3. HTMLテンプレートの分析
        Write-Host "`n📄 HTMLテンプレートの分析:" -ForegroundColor Cyan
        $templatePath = Join-Path $PSScriptRoot "..\Templates\Samples\$($test.TemplateName)"
        if (Test-Path $templatePath) {
            $templateContent = Get-Content $templatePath -Raw
            Write-Host "   ✅ テンプレートファイル確認: $($test.TemplateName)" -ForegroundColor Green
            
            # テンプレート内の変数を抽出
            $variables = [regex]::Matches($templateContent, '\{\{([^}]+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
            Write-Host "   📝 テンプレート内の変数:" -ForegroundColor White
            foreach ($var in $variables) {
                Write-Host "     • {{$var}}" -ForegroundColor Gray
            }
            
            # テーブルヘッダーの抽出
            $tableHeaders = [regex]::Matches($templateContent, '<th>([^<]+)</th>') | ForEach-Object { $_.Groups[1].Value }
            Write-Host "   📊 テーブルヘッダー:" -ForegroundColor White
            foreach ($header in $tableHeaders) {
                Write-Host "     • $header" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ❌ テンプレートファイルが見つかりません: $templatePath" -ForegroundColor Red
        }
        
        # 4. 現在のHTMLTemplateEngineによる処理をテスト
        Write-Host "`n🔧 現在のHTMLTemplateEngineによる処理テスト:" -ForegroundColor Cyan
        try {
            $htmlReport = Generate-EnhancedHTMLReport -Data $data -ReportType $test.Type -Title "$($test.Type)テストレポート"
            if ($htmlReport) {
                Write-Host "   ✅ HTMLレポート生成成功" -ForegroundColor Green
                Write-Host "   📏 レポート文字数: $($htmlReport.Length)" -ForegroundColor White
                
                # 生成されたHTMLに含まれる変数の確認
                $unreplacedVars = [regex]::Matches($htmlReport, '\{\{([^}]+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
                if ($unreplacedVars.Count -gt 0) {
                    Write-Host "   ⚠️ 置換されていない変数:" -ForegroundColor Yellow
                    foreach ($var in $unreplacedVars) {
                        Write-Host "     • {{$var}}" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "   ✅ すべての変数が正しく置換されました" -ForegroundColor Green
                }
            } else {
                Write-Host "   ❌ HTMLレポート生成失敗" -ForegroundColor Red
            }
        } catch {
            Write-Host "   ❌ HTMLレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # 5. 整合性評価
        Write-Host "`n📊 整合性評価:" -ForegroundColor Cyan
        $alignmentScore = 0
        $issues = @()
        
        # データプロパティとテンプレートヘッダーの整合性チェック
        if ($data.Count -gt 0 -and $tableHeaders.Count -gt 0) {
            $dataProps = $data[0].PSObject.Properties.Name
            $matchedHeaders = 0
            
            foreach ($header in $tableHeaders) {
                $matchFound = $false
                foreach ($prop in $dataProps) {
                    if ($prop -like "*$header*" -or $header -like "*$prop*") {
                        $matchFound = $true
                        break
                    }
                }
                if ($matchFound) { $matchedHeaders++ }
            }
            
            $headerMatchRate = [Math]::Round(($matchedHeaders / $tableHeaders.Count) * 100, 2)
            Write-Host "   📊 ヘッダー整合率: $headerMatchRate% ($matchedHeaders/$($tableHeaders.Count))" -ForegroundColor White
            
            if ($headerMatchRate -ge 80) {
                Write-Host "   ✅ ヘッダー整合性: 良好" -ForegroundColor Green
                $alignmentScore += 50
            } elseif ($headerMatchRate -ge 60) {
                Write-Host "   ⚠️ ヘッダー整合性: 要改善" -ForegroundColor Yellow
                $alignmentScore += 30
                $issues += "ヘッダー整合性が低い"
            } else {
                Write-Host "   ❌ ヘッダー整合性: 不良" -ForegroundColor Red
                $alignmentScore += 10
                $issues += "ヘッダー整合性が非常に低い"
            }
        }
        
        # 変数整合性チェック
        if ($unreplacedVars.Count -eq 0) {
            Write-Host "   ✅ 変数整合性: 完全" -ForegroundColor Green
            $alignmentScore += 50
        } else {
            Write-Host "   ⚠️ 変数整合性: 不完全 ($($unreplacedVars.Count)個未置換)" -ForegroundColor Yellow
            $alignmentScore += 20
            $issues += "$($unreplacedVars.Count)個の変数が未置換"
        }
        
        # 総合評価
        Write-Host "`n🎯 総合評価:" -ForegroundColor Cyan
        Write-Host "   スコア: $alignmentScore/100" -ForegroundColor White
        
        if ($alignmentScore -ge 80) {
            Write-Host "   判定: ✅ 良好" -ForegroundColor Green
        } elseif ($alignmentScore -ge 60) {
            Write-Host "   判定: ⚠️ 要改善" -ForegroundColor Yellow
        } else {
            Write-Host "   判定: ❌ 修正必要" -ForegroundColor Red
        }
        
        if ($issues.Count -gt 0) {
            Write-Host "   🔧 改善点:" -ForegroundColor Yellow
            foreach ($issue in $issues) {
                Write-Host "     • $issue" -ForegroundColor Yellow
            }
        }
        
    } catch {
        Write-Host "❌ テスト実行エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🏁 データ構造とHTMLテンプレートの整合性検証テスト完了" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan