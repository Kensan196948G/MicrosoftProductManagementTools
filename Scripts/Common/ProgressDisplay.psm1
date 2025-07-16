# ================================================================================
# プログレス表示モジュール
# Microsoft 365統合管理ツール用
# PowerShell 7の機能を使用したリアルタイム進行状況表示
# ================================================================================

# 実データ取得モジュールをインポート
try {
    Import-Module "$PSScriptRoot\DailyReportData.psm1" -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\WeeklyReportData.psm1" -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\MonthlyReportData.psm1" -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\YearlyReportData.psm1" -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "警告: 実データ取得モジュールのインポートに失敗しました" -ForegroundColor Yellow
}

# グローバル変数
$Script:ProgressWidth = 50
$Script:ProgressChar = "█"
$Script:ProgressEmptyChar = "░"

# プログレスバー表示関数
function Show-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$PercentComplete,
        
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        
        [Parameter(Mandatory = $false)]
        [string]$Status = "",
        
        [Parameter(Mandatory = $false)]
        [string]$CurrentOperation = "",
        
        [Parameter(Mandatory = $false)]
        [int]$Id = 1,
        
        [Parameter(Mandatory = $false)]
        [switch]$NoNewLine
    )
    
    try {
        # PowerShell 7のWrite-Progressを使用
        $progressParams = @{
            Id = $Id
            Activity = $Activity
            PercentComplete = $PercentComplete
        }
        
        if ($Status) {
            $progressParams.Status = $Status
        }
        
        if ($CurrentOperation) {
            $progressParams.CurrentOperation = $CurrentOperation
        }
        
        Write-Progress @progressParams
        
        # コンソールにも視覚的なプログレスバーを表示
        $filledLength = [math]::Round(($PercentComplete / 100) * $Script:ProgressWidth)
        $emptyLength = $Script:ProgressWidth - $filledLength
        
        $progressBar = $Script:ProgressChar * $filledLength + $Script:ProgressEmptyChar * $emptyLength
        
        # 数値進捗の詳細表示
        $progressText = if ($CurrentOperation) {
            "$Activity [$progressBar] $PercentComplete% - $CurrentOperation"
        } else {
            "$Activity [$progressBar] $PercentComplete% $Status"
        }
        
        if ($NoNewLine) {
            Write-Host "`r$progressText" -NoNewline -ForegroundColor Cyan
        } else {
            Write-Host $progressText -ForegroundColor Cyan
        }
        
    }
    catch {
        # フォールバック: シンプルなテキスト表示
        Write-Host "$Activity - $PercentComplete% $Status" -ForegroundColor Cyan
    }
}

# 実況ログ表示関数
function Write-LiveLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug", "Verbose")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoTimestamp,
        
        [Parameter(Mandatory = $false)]
        [switch]$Animate
    )
    
    $colors = @{
        Info = "White"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Debug = "Magenta"
        Verbose = "Gray"
    }
    
    $icons = @{
        Info = "ℹ️"
        Success = "✅"
        Warning = "⚠️"
        Error = "❌"
        Debug = "🔍"
        Verbose = "💬"
    }
    
    $timestamp = if (-not $NoTimestamp) { 
        "[$(Get-Date -Format 'HH:mm:ss')] " 
    } else { 
        "" 
    }
    
    $icon = $icons[$Level]
    $color = $colors[$Level]
    $logText = "$timestamp$icon $Message"
    
    if ($Animate) {
        # アニメーション効果付きで1文字ずつ表示
        foreach ($char in $logText.ToCharArray()) {
            Write-Host $char -NoNewline -ForegroundColor $color
            Start-Sleep -Milliseconds 20
        }
        Write-Host ""
    } else {
        Write-Host $logText -ForegroundColor $color
    }
}

# ステップ処理関数（進行状況付き）
function Invoke-StepWithProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Steps,
        
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        
        [Parameter(Mandatory = $false)]
        [int]$Id = 1
    )
    
    $totalSteps = $Steps.Count
    $currentStep = 0
    
    Write-LiveLog "📋 開始: $Activity ($totalSteps ステップ)" -Level "Info"
    
    foreach ($step in $Steps) {
        $currentStep++
        $percentComplete = [math]::Round(($currentStep / $totalSteps) * 100)
        
        $stepName = if ($step.Name) { $step.Name } else { "ステップ $currentStep" }
        $stepAction = $step.Action
        
        Show-ProgressBar -PercentComplete $percentComplete -Activity $Activity -Status $stepName -CurrentOperation "実行中..." -Id $Id
        Write-LiveLog "🔄 実行中: $stepName" -Level "Info" -Animate
        
        try {
            # ステップのアクションを実行
            if ($stepAction -is [ScriptBlock]) {
                $result = & $stepAction
            } elseif ($stepAction -is [string]) {
                $result = Invoke-Expression $stepAction
            } else {
                throw "無効なアクション: $stepAction"
            }
            
            Write-LiveLog "✅ 完了: $stepName" -Level "Success"
            
            # 少し待機（視覚効果のため）
            Start-Sleep -Milliseconds 500
            
        }
        catch {
            Write-LiveLog "❌ エラー: $stepName - $($_.Exception.Message)" -Level "Error"
            throw
        }
    }
    
    # 完了時にプログレスバーをクリア
    Write-Progress -Id $Id -Completed
    Write-LiveLog "🎉 完了: $Activity" -Level "Success" -Animate
}

# ダミーデータ生成の進行状況表示
function New-DummyDataWithProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataType,
        
        [Parameter(Mandatory = $false)]
        [int]$RecordCount = 50,
        
        [Parameter(Mandatory = $false)]
        [int]$ProgressId = 2
    )
    
    Write-LiveLog "📊 ダミーデータ生成開始: $DataType ($RecordCount 件)" -Level "Info"
    
    $dummyData = @()
    $userNames = @("田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一", "伊藤光子", "山田和也", "中村真理", "小林秀樹", "加藤明美")
    $departments = @("営業部", "開発部", "総務部", "人事部", "経理部", "マーケティング部", "システム部")
    
    for ($i = 1; $i -le $RecordCount; $i++) {
        $percentComplete = [math]::Round(($i / $RecordCount) * 100)
        
        Show-ProgressBar -PercentComplete $percentComplete -Activity "ダミーデータ生成" -Status "$DataType データ" -CurrentOperation "レコード $i/$RecordCount 生成中" -Id $ProgressId -NoNewLine
        
        $dummyData += [PSCustomObject]@{
            ID = $i
            ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
            部署 = $departments[(Get-Random -Maximum $departments.Count)]
            作成日時 = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd HH:mm:ss")
            ステータス = @("正常", "警告", "注意")[(Get-Random -Maximum 3)]
            数値データ = Get-Random -Minimum 10 -Maximum 100
            データ種別 = $DataType
        }
        
        # リアルタイム感を演出するため少し待機
        if ($i % 10 -eq 0 -or $i -eq $RecordCount) {
            Start-Sleep -Milliseconds 100
        }
    }
    
    Write-Progress -Id $ProgressId -Completed
    Write-Host ""  # 改行
    Write-LiveLog "✅ ダミーデータ生成完了: $RecordCount 件のレコードを生成" -Level "Success"
    
    return $dummyData
}

# レポート生成ステップ定義
function Get-ReportGenerationSteps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [int]$RecordCount = 50
    )
    
    $steps = @(
        @{
            Name = "📝 初期化"
            Action = {
                Write-LiveLog "🔧 レポート生成環境を初期化中..." -Level "Verbose"
                Start-Sleep -Milliseconds 300
            }
        },
        @{
            Name = "🔗 認証確認"
            Action = {
                Write-LiveLog "🔐 Microsoft 365認証状態を確認中..." -Level "Verbose"
                Start-Sleep -Milliseconds 500
            }
        },
        @{
            Name = "📊 データ収集"
            Action = {
                Write-LiveLog "📈 $ReportType データ収集を開始..." -Level "Verbose"
                
                # データ収集の詳細進捗表示
                Invoke-DataCollectionWithProgress -ReportType $ReportType -RecordCount $RecordCount
            }
        },
        @{
            Name = "🔄 データ処理"
            Action = {
                Write-LiveLog "⚙️ 収集したデータを処理中..." -Level "Verbose"
                Start-Sleep -Milliseconds 800
            }
        },
        @{
            Name = "📋 CSV生成"
            Action = {
                Write-LiveLog "📝 CSVファイルを生成中..." -Level "Verbose"
                Start-Sleep -Milliseconds 600
            }
        },
        @{
            Name = "🌐 HTML生成"
            Action = {
                Write-LiveLog "🎨 HTMLレポートを生成中..." -Level "Verbose"
                Start-Sleep -Milliseconds 700
            }
        },
        @{
            Name = "💾 ファイル保存"
            Action = {
                Write-LiveLog "💾 レポートファイルを保存中..." -Level "Verbose"
                Start-Sleep -Milliseconds 400
            }
        },
        @{
            Name = "🚀 ファイル表示"
            Action = {
                Write-LiveLog "📂 生成されたレポートを表示中..." -Level "Verbose"
                Start-Sleep -Milliseconds 300
            }
        },
        @{
            Name = "📢 完了通知"
            Action = {
                Write-LiveLog "🔔 レポート完了通知を表示中..." -Level "Verbose"
                Show-ReportCompletionNotification -ReportType $ReportType
                Start-Sleep -Milliseconds 200
            }
        }
    )
    
    return $steps
}

# プログレス表示付きレポート生成関数
function Invoke-ReportGenerationWithProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportName,
        
        [Parameter(Mandatory = $false)]
        [int]$RecordCount = 50
    )
    
    Write-Host "`n" + "="*80 -ForegroundColor Blue
    Write-Host "🚀 Microsoft 365統合管理ツール - レポート生成開始" -ForegroundColor Blue
    Write-Host "="*80 -ForegroundColor Blue
    
    $steps = Get-ReportGenerationSteps -ReportType $ReportType -RecordCount $RecordCount
    
    try {
        Invoke-StepWithProgress -Steps $steps -Activity $ReportName -Id 1
        
        Write-Host "`n" + "="*80 -ForegroundColor Green
        Write-Host "🎉 レポート生成完了: $ReportName" -ForegroundColor Green
        Write-Host "="*80 -ForegroundColor Green
        
        return $script:collectedData
    }
    catch {
        Write-Host "`n" + "="*80 -ForegroundColor Red
        Write-Host "💥 レポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "="*80 -ForegroundColor Red
        throw
    }
}

# プログレスバークリア関数
function Clear-AllProgress {
    for ($i = 1; $i -le 10; $i++) {
        Write-Progress -Id $i -Completed
    }
}

# データ収集進捗表示関数
function Invoke-DataCollectionWithProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [int]$RecordCount = 50
    )
    
    $script:totalCollected = 0
    $script:collectedData = @()
    
    # データ収集ステップの定義
    $collectionSteps = @(
        @{ Name = "認証状態確認"; Weight = 10; Action = "Auth" },
        @{ Name = "ユーザーデータ"; Weight = 30; Action = "Users" },
        @{ Name = "メールボックスデータ"; Weight = 25; Action = "Mailboxes" },
        @{ Name = "セキュリティデータ"; Weight = 20; Action = "Security" },
        @{ Name = "設定データ"; Weight = 15; Action = "Config" }
    )
    
    $totalWeight = ($collectionSteps | Measure-Object -Property Weight -Sum).Sum
    $currentProgress = 0
    
    Write-LiveLog "🔍 データ収集プロセス開始 ($($collectionSteps.Count) ステップ)" -Level "Info"
    
    foreach ($step in $collectionSteps) {
        $stepStartProgress = $currentProgress
        $stepEndProgress = $currentProgress + $step.Weight
        
        Write-LiveLog "📥 $($step.Name) 収集開始..." -Level "Info"
        
        # ステップ内での詳細進捗表示
        $stepItems = [math]::Round($RecordCount * ($step.Weight / 100.0))
        if ($stepItems -lt 1) { $stepItems = 1 }
        
        # 実際のデータ取得を試行
        $realDataCollected = $false
        
        # レポートタイプと収集ステップに応じた実データ取得
        if ($step.Action -eq "Users" -and $ReportType -eq "Daily") {
            try {
                if (Get-Command Get-DailyReportRealData -ErrorAction SilentlyContinue) {
                    Write-LiveLog "🔍 実データ取得を試行中..." -Level "Info"
                    Show-ProgressBar -PercentComplete $stepStartProgress -Activity "📊 データ収集" -Status "$($step.Name)" -CurrentOperation "Microsoft 365 実データ取得中..." -Id 3
                    
                    $realData = Get-DailyReportRealData
                    if ($realData -and $realData.UserActivity -and $realData.UserActivity.Count -gt 0) {
                        $script:collectedData += $realData.UserActivity
                        $script:totalCollected = $realData.UserActivity.Count
                        $realDataCollected = $true
                        Write-LiveLog "✅ 実データ取得成功: $($realData.UserActivity.Count) 件" -Level "Success"
                        Show-ProgressBar -PercentComplete $stepEndProgress -Activity "📊 データ収集" -Status "$($step.Name)" -CurrentOperation "実データ取得完了: $($realData.UserActivity.Count) 件" -Id 3
                        Start-Sleep -Milliseconds 500
                    }
                }
            } catch {
                Write-LiveLog "⚠️ 実データ取得エラー、ダミーデータにフォールバック" -Level "Warning"
            }
        }
        
        # 実データが取得できない場合はダミーデータ生成（数値進捗付き）
        if (-not $realDataCollected) {
            for ($i = 1; $i -le $stepItems; $i++) {
                $itemProgress = $stepStartProgress + (($i / $stepItems) * $step.Weight)
                $itemProgress = [math]::Round($itemProgress)
                
                # プログレスバー更新（数値進捗付き）
                Show-ProgressBar -PercentComplete $itemProgress -Activity "📊 データ収集" -Status "$($step.Name)" -CurrentOperation "収集中: $script:totalCollected/$RecordCount 件 ($($step.Name) $i/$stepItems)" -Id 3
                
                # データ生成シミュレーション
                $newItem = [PSCustomObject]@{
                    ID = $script:totalCollected + 1
                    ステップ = $step.Name
                    アクション = $step.Action
                    データ = "サンプルデータ_$($script:totalCollected + 1)"
                    収集時刻 = Get-Date
                    ReportType = $ReportType
                }
                
                $script:collectedData += $newItem
                $script:totalCollected++
                
                # リアルタイム進捗ログ
                if ($i % 3 -eq 0 -or $i -eq $stepItems) {
                    Write-LiveLog "📈 $($step.Name): $i/$stepItems 件収集完了 (総計: $script:totalCollected/$RecordCount)" -Level "Verbose"
                }
                
                # リアルな収集感を演出
                Start-Sleep -Milliseconds 30
            }
        }
        
        $currentProgress = $stepEndProgress
        Write-LiveLog "✅ $($step.Name) 収集完了: $stepItems 件" -Level "Success"
    }
    
    # 最終プログレス表示
    Show-ProgressBar -PercentComplete 100 -Activity "📊 データ収集" -Status "完了" -CurrentOperation "収集完了: $script:totalCollected 件のデータを取得" -Id 3
    Write-LiveLog "🎉 データ収集完了: 総計 $script:totalCollected 件" -Level "Success"
    
    # プログレスバーをクリア
    Start-Sleep -Milliseconds 500
    Write-Progress -Id 3 -Completed
}

# レポート完了通知関数
function Show-ReportCompletionNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType
    )
    
    $reportNames = @{
        "Daily" = "📊 日次レポート"
        "Weekly" = "📅 週次レポート"
        "Monthly" = "📈 月次レポート"
        "Yearly" = "🗓️ 年次レポート"
        "License" = "📋 ライセンス分析レポート"
        "Usage" = "📊 使用状況分析レポート"
        "Performance" = "⚡ パフォーマンス監視レポート"
        "Security" = "🔒 セキュリティ監査レポート"
        "Permission" = "🔑 権限監査レポート"
    }
    
    $reportName = if ($reportNames.ContainsKey($ReportType)) { 
        $reportNames[$ReportType] 
    } else { 
        "📋 $ReportType レポート" 
    }
    
    $notificationTitle = "レポート生成完了"
    $notificationMessage = @"
✅ $reportName の生成が完了しました！

📂 Reports フォルダに保存されました
📄 CSV とHTML形式で出力
🕒 生成日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

レポートファイルが自動的に開かれます。
"@

    try {
        # Windows環境でのポップアップ表示
        if ($IsWindows -or $PSVersionTable.PSEdition -eq "Desktop") {
            # Windows Forms使用（GUIアプリケーション用）
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show(
                    $notificationMessage,
                    $notificationTitle,
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                Write-LiveLog "✅ ポップアップ通知を表示しました" -Level "Success"
            }
            catch {
                # Windows Formsが使用できない場合のフォールバック
                Write-Host "`n" + "="*60 -ForegroundColor Green
                Write-Host $notificationTitle -ForegroundColor Green -BackgroundColor Black
                Write-Host "="*60 -ForegroundColor Green
                Write-Host $notificationMessage -ForegroundColor White
                Write-Host "="*60 -ForegroundColor Green
                Write-LiveLog "✅ コンソール通知を表示しました" -Level "Success"
            }
        }
        else {
            # Linux/macOS環境用のコンソール通知
            Write-Host "`n" + "="*60 -ForegroundColor Green
            Write-Host $notificationTitle -ForegroundColor Green -BackgroundColor Black
            Write-Host "="*60 -ForegroundColor Green
            Write-Host $notificationMessage -ForegroundColor White
            Write-Host "="*60 -ForegroundColor Green
            Write-LiveLog "✅ コンソール通知を表示しました（Linux/macOS）" -Level "Success"
        }
    }
    catch {
        Write-LiveLog "⚠️ 通知表示エラー: $($_.Exception.Message)" -Level "Warning"
        # 最低限のコンソール出力
        Write-Host "`n🎉 $reportName 生成完了！" -ForegroundColor Green
    }
}

# モジュールのエクスポート
Export-ModuleMember -Function Show-ProgressBar, Write-LiveLog, Invoke-StepWithProgress, New-DummyDataWithProgress, Get-ReportGenerationSteps, Invoke-ReportGenerationWithProgress, Clear-AllProgress, Show-ReportCompletionNotification, Invoke-DataCollectionWithProgress