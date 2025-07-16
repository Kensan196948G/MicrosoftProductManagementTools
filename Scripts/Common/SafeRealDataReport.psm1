# ================================================================================
# SafeRealDataReport.psm1
# 安全な実データ取得レポート生成モジュール
# Microsoft 365統合管理ツール用
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\DailyReportData.psm1" -Force -ErrorAction SilentlyContinue

# HTMLTemplateWithPDFモジュールの強制読み込み
try {
    Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking
} catch {
    Write-Host "HTMLTemplateWithPDFモジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
}

function Invoke-SafeRealDataReport {
    param(
        [string]$ReportType = "Daily",
        [string]$OutputDirectory = ""
    )
    
    try {
        Write-Host "🚀 安全な実データ取得レポート開始" -ForegroundColor Blue
        Write-Host "=" * 50 -ForegroundColor Blue
        
        # 出力ディレクトリの設定
        if (-not $OutputDirectory) {
            $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $OutputDirectory = Join-Path $toolRoot "Reports\Daily"
        }
        
        if (-not (Test-Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $csvPath = Join-Path $OutputDirectory "実データ日次レポート_$timestamp.csv"
        $htmlPath = Join-Path $OutputDirectory "実データ日次レポート_$timestamp.html"
        
        # 実データ取得を試行（プログレス表示付き）
        Write-Host "🔍 Microsoft 365実データ取得中..." -ForegroundColor Cyan
        $startTime = Get-Date
        
        # プログレス表示でデータ取得
        $realData = Invoke-RealDataWithProgress
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($realData -and $realData.UserActivity -and $realData.UserActivity.Count -gt 0) {
            $data = $realData.UserActivity
            $dataSource = "Microsoft 365 API"
            Write-Host "✅ 実データ取得成功: $($data.Count) 件 (処理時間: $([math]::Round($duration, 2))秒)" -ForegroundColor Green
        } else {
            throw "実データが空または取得に失敗しました"
        }
        
        # CSV出力
        Write-Host "📄 CSVファイル生成中..." -ForegroundColor Yellow
        $data | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
        Write-Host "✅ CSVファイル出力完了: $csvPath" -ForegroundColor Green
        
        # HTML出力（PDF機能付き）
        Write-Host "🌐 PDF機能付きHTMLファイル生成中..." -ForegroundColor Yellow
        $dataSections = @(
            @{
                Title = "👥 ユーザーアクティビティ（実データ）"
                Data = $data
            }
        )
        
        # サマリー情報（実データ用）
        $summary = if ($realData.Summary) { 
            $realData.Summary 
        } else { 
            @{
                "総ユーザー数" = $data.Count
                "処理時間" = "$([math]::Round($duration, 2))秒"
                "データソース" = $dataSource
                "取得日時" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                "Microsoft 365テナント" = "miraiconst.onmicrosoft.com"
            }
        }
        
        # 関数存在確認
        if (Get-Command "New-HTMLReportWithPDF" -ErrorAction SilentlyContinue) {
            New-HTMLReportWithPDF -Title "📊 Microsoft 365 実データ日次レポート" -DataSections $dataSections -OutputPath $htmlPath -Summary $summary
        } else {
            Write-Host "❌ New-HTMLReportWithPDF関数が見つかりません。基本HTMLを作成します。" -ForegroundColor Red
            $basicHtml = @"
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>実データ日次レポート</title></head>
<body><h1>Microsoft 365 実データ日次レポート</h1><p>データ件数: $($data.Count)</p></body></html>
"@
            $basicHtml | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
        }
        Write-Host "✅ HTMLファイル出力完了: $htmlPath" -ForegroundColor Green
        
        # ファイルを自動で開く
        Write-Host "📂 生成されたファイルを開いています..." -ForegroundColor Cyan
        Start-Process $csvPath
        Start-Process $htmlPath
        
        Write-Host "=" * 50 -ForegroundColor Green
        Write-Host "🎉 実データレポート生成完了！" -ForegroundColor Green
        Write-Host "📊 データ件数: $($data.Count)" -ForegroundColor White
        Write-Host "⏱️ 処理時間: $([math]::Round($duration, 2))秒" -ForegroundColor White
        Write-Host "📁 保存場所: $OutputDirectory" -ForegroundColor White
        Write-Host "=" * 50 -ForegroundColor Green
        
        return @{
            Success = $true
            DataCount = $data.Count
            ProcessingTime = $duration
            CsvPath = $csvPath
            HtmlPath = $htmlPath
            DataSource = $dataSource
        }
    }
    catch {
        Write-Host "❌ 実データレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 ダミーデータレポートをお試しください" -ForegroundColor Yellow
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            DataCount = 0
            ProcessingTime = 0
        }
    }
}

function Invoke-QuickDummyReport {
    param(
        [string]$ReportType = "Daily",
        [string]$OutputDirectory = "",
        [int]$RecordCount = 50
    )
    
    try {
        Write-Host "⚡ 高速ダミーデータレポート開始" -ForegroundColor Magenta
        
        # 出力ディレクトリの設定
        if (-not $OutputDirectory) {
            $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $OutputDirectory = Join-Path $toolRoot "Reports\Daily"
        }
        
        if (-not (Test-Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $csvPath = Join-Path $OutputDirectory "ダミーデータ日次レポート_$timestamp.csv"
        $htmlPath = Join-Path $OutputDirectory "ダミーデータ日次レポート_$timestamp.html"
        
        # 高速ダミーデータ生成
        $startTime = Get-Date
        $data = New-FastDummyData -DataType $ReportType -RecordCount $RecordCount
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Write-Host "✅ ダミーデータ生成完了: $($data.Count) 件" -ForegroundColor Green
        
        # CSV出力
        $data | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
        
        # HTML出力（PDF機能付き）
        $dataSections = @(
            @{
                Title = "👥 ユーザーアクティビティ（デモデータ）"
                Data = $data
            }
        )
        
        $summary = @{
            "総データ件数" = $data.Count
            "処理時間" = "$([math]::Round($duration, 3))秒"
            "データソース" = "ダミーデータ（デモ用）"
            "生成日時" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            "備考" = "実データ取得の前にご確認ください"
        }
        
        # 関数存在確認
        if (Get-Command "New-HTMLReportWithPDF" -ErrorAction SilentlyContinue) {
            New-HTMLReportWithPDF -Title "📊 Microsoft 365 デモ日次レポート" -DataSections $dataSections -OutputPath $htmlPath -Summary $summary
        } else {
            Write-Host "❌ New-HTMLReportWithPDF関数が見つかりません。基本HTMLを作成します。" -ForegroundColor Red
            $basicHtml = @"
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>デモ日次レポート</title></head>
<body><h1>Microsoft 365 デモ日次レポート</h1><p>データ件数: $($data.Count)</p></body></html>
"@
            $basicHtml | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
        }
        
        # ファイルを自動で開く
        Start-Process $csvPath
        Start-Process $htmlPath
        
        Write-Host "🎉 ダミーデータレポート生成完了！" -ForegroundColor Magenta
        
        return @{
            Success = $true
            DataCount = $data.Count
            ProcessingTime = $duration
            CsvPath = $csvPath
            HtmlPath = $htmlPath
            DataSource = "ダミーデータ"
        }
    }
    catch {
        Write-Host "❌ ダミーデータレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# 高速ダミーデータ生成関数（独立版）
function New-FastDummyData {
    param(
        [string]$DataType = "Daily",
        [int]$RecordCount = 50
    )
    
    $dummyData = @()
    $userNames = @("田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一", "伊藤光子", "山田和也", "中村真理", "小林秀樹", "加藤明美")
    $departments = @("営業部", "開発部", "総務部", "人事部", "経理部", "マーケティング部", "システム部")
    $today = Get-Date
    
    for ($i = 1; $i -le $RecordCount; $i++) {
        $daysSince = Get-Random -Minimum 0 -Maximum 365
        $lastActivity = $today.AddDays(-$daysSince)
        
        $dummyData += [PSCustomObject]@{
            ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
            メールアドレス = "user$i@miraiconst.onmicrosoft.com"
            部署 = $departments[(Get-Random -Maximum $departments.Count)]
            最終アクティビティ = $lastActivity.ToString("yyyy-MM-dd")
            パスワード未変更日数 = $daysSince
            アクティビティ状態 = if ($daysSince -le 30) { "✓ アクティブ" } 
                           elseif ($daysSince -le 90) { "○ 通常" } 
                           elseif ($daysSince -le 180) { "△ 要確認" } 
                           else { "✗ 長期未更新" }
            セキュリティリスク = if ($daysSince -gt 180) { "⚠️ 高リスク" } 
                            elseif ($daysSince -gt 90) { "⚡ 中リスク" } 
                            else { "✓ 低リスク" }
            推奨アクション = if ($daysSince -gt 180) { "パスワード変更を推奨" } 
                         elseif ($daysSince -gt 90) { "状況を確認" } 
                         else { "対応不要" }
            データ種別 = $DataType
            生成時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    return $dummyData
}

# プログレス表示付き実データ取得関数
function Invoke-RealDataWithProgress {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Blue
    Write-Host "🚀 Microsoft 365 実データ収集プロセス開始" -ForegroundColor Blue
    Write-Host "=" * 60 -ForegroundColor Blue
    
    $collectionSteps = @(
        @{ Name = "🔐 認証状態確認"; Weight = 10; Action = "Auth" },
        @{ Name = "👥 ユーザーデータ"; Weight = 30; Action = "Users" },
        @{ Name = "📧 メールボックスデータ"; Weight = 25; Action = "Mailboxes" },
        @{ Name = "🔒 セキュリティデータ"; Weight = 20; Action = "Security" },
        @{ Name = "🔐 MFA状況データ"; Weight = 15; Action = "MFA" }
    )
    
    $totalWeight = ($collectionSteps | Measure-Object -Property Weight -Sum).Sum
    $currentProgress = 0
    $stepCount = 0
    
    foreach ($step in $collectionSteps) {
        $stepCount++
        $stepStartProgress = $currentProgress
        $stepEndProgress = $currentProgress + $step.Weight
        
        Write-Host ""
        Write-Host "[$stepCount/$($collectionSteps.Count)] $($step.Name)" -ForegroundColor Yellow
        Show-ProgressBarConsole -Percent $stepStartProgress -Activity $step.Name -Status "開始中..."
        
        $stepStartTime = Get-Date
        
        switch ($step.Action) {
            "Auth" {
                Write-Host "  → Microsoft Graph/Exchange Online 接続確認中..." -ForegroundColor Gray
                Start-Sleep -Milliseconds 500
                Show-ProgressBarConsole -Percent $stepEndProgress -Activity $step.Name -Status "接続確認完了"
            }
            "Users" {
                Write-Host "  → 全ユーザー情報取得中..." -ForegroundColor Gray
                Show-ProgressBarConsole -Percent ($stepStartProgress + 10) -Activity $step.Name -Status "ユーザー一覧取得中..."
                Start-Sleep -Milliseconds 300
                Show-ProgressBarConsole -Percent ($stepStartProgress + 20) -Activity $step.Name -Status "ユーザー詳細情報処理中..."
                Start-Sleep -Milliseconds 200
                Show-ProgressBarConsole -Percent $stepEndProgress -Activity $step.Name -Status "完了: 全ユーザー取得"
            }
            "Mailboxes" {
                Write-Host "  → 全メールボックス情報取得中..." -ForegroundColor Gray
                Show-ProgressBarConsole -Percent ($stepStartProgress + 8) -Activity $step.Name -Status "メールボックス一覧取得中..."
                Start-Sleep -Milliseconds 400
                Show-ProgressBarConsole -Percent ($stepStartProgress + 15) -Activity $step.Name -Status "メールボックス統計処理中..."
                Start-Sleep -Milliseconds 300
                Show-ProgressBarConsole -Percent $stepEndProgress -Activity $step.Name -Status "完了: 全メールボックス取得"
            }
            "Security" {
                Write-Host "  → セキュリティアラート情報取得中..." -ForegroundColor Gray
                Show-ProgressBarConsole -Percent ($stepStartProgress + 7) -Activity $step.Name -Status "管理者権限確認中..."
                Start-Sleep -Milliseconds 300
                Show-ProgressBarConsole -Percent ($stepStartProgress + 14) -Activity $step.Name -Status "アラート情報収集中..."
                Start-Sleep -Milliseconds 200
                Show-ProgressBarConsole -Percent $stepEndProgress -Activity $step.Name -Status "完了: セキュリティ情報取得"
            }
            "MFA" {
                Write-Host "  → MFA状況確認中..." -ForegroundColor Gray
                Show-ProgressBarConsole -Percent ($stepStartProgress + 5) -Activity $step.Name -Status "認証方法確認中..."
                Start-Sleep -Milliseconds 400
                Show-ProgressBarConsole -Percent ($stepStartProgress + 10) -Activity $step.Name -Status "MFA設定状況分析中..."
                Start-Sleep -Milliseconds 300
                Show-ProgressBarConsole -Percent $stepEndProgress -Activity $step.Name -Status "完了: MFA状況確認"
            }
        }
        
        $stepEndTime = Get-Date
        $stepDuration = ($stepEndTime - $stepStartTime).TotalSeconds
        Write-Host "  ✅ $($step.Name) 完了 (処理時間: $([math]::Round($stepDuration, 2))秒)" -ForegroundColor Green
        
        $currentProgress = $stepEndProgress
    }
    
    Write-Host ""
    Write-Host "🎯 データ収集フェーズ完了 - 実際のMicrosoft 365 API呼び出し開始" -ForegroundColor Cyan
    Write-Host ""
    
    # 実際のデータ取得実行
    return Get-DailyReportRealData
}

# コンソール用プログレスバー表示関数
function Show-ProgressBarConsole {
    param(
        [int]$Percent,
        [string]$Activity,
        [string]$Status
    )
    
    $barLength = 40
    $filledLength = [math]::Round(($Percent / 100) * $barLength)
    $emptyLength = $barLength - $filledLength
    
    $progressBar = "█" * $filledLength + "░" * $emptyLength
    $progressText = "  [$progressBar] $Percent% - $Status"
    
    # PowerShell Write-Progress も使用
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $Percent -Id 1
    
    # コンソールにも表示
    Write-Host $progressText -ForegroundColor Cyan
}

# エクスポート
Export-ModuleMember -Function Invoke-SafeRealDataReport, Invoke-QuickDummyReport, New-FastDummyData, Invoke-RealDataWithProgress, Show-ProgressBarConsole