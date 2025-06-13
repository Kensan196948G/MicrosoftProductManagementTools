# ================================================================================
# ConsoleGUIMenu.psm1
# PowerShell 7系対応 ConsoleGUIメニューシステム
# ================================================================================

# 必要モジュールのインポート
Import-Module "$PSScriptRoot\..\Common\VersionDetection.psm1" -Force

# Microsoft.PowerShell.ConsoleGuiToolsの可用性チェック
$Script:ConsoleGuiToolsAvailable = $false
$Script:ConsoleGuiModule = $null

# モジュール初期化
function Initialize-ConsoleGUISupport {
    <#
    .SYNOPSIS
    ConsoleGUIサポートを初期化

    .DESCRIPTION
    Microsoft.PowerShell.ConsoleGuiToolsモジュールの可用性をチェックし、必要に応じてインストールを提案

    .EXAMPLE
    Initialize-ConsoleGUISupport
    #>
    
    try {
        # モジュールの存在確認
        $Script:ConsoleGuiModule = Get-Module -ListAvailable -Name "Microsoft.PowerShell.ConsoleGuiTools" | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($Script:ConsoleGuiModule) {
            Import-Module "Microsoft.PowerShell.ConsoleGuiTools" -Force -Scope Global
            $Script:ConsoleGuiToolsAvailable = $true
            Write-Verbose "ConsoleGuiTools モジュールを読み込みました (v$($Script:ConsoleGuiModule.Version))"
        } else {
            $Script:ConsoleGuiToolsAvailable = $false
            Write-Warning "Microsoft.PowerShell.ConsoleGuiTools モジュールが見つかりません"
        }
    } catch {
        $Script:ConsoleGuiToolsAvailable = $false
        Write-Warning "ConsoleGuiTools モジュールの読み込みに失敗しました: $($_.Exception.Message)"
    }
    
    return $Script:ConsoleGuiToolsAvailable
}

# ConsoleGUIメニューデータ構造
class ConsoleMenuItem {
    [string]$Id
    [string]$Category
    [string]$Task
    [string]$Description
    [string]$ScriptPath
    [hashtable]$Parameters
    [bool]$RequiresAdmin
    [scriptblock]$Action
    
    ConsoleMenuItem([string]$id, [string]$category, [string]$task) {
        $this.Id = $id
        $this.Category = $category  
        $this.Task = $task
        $this.Parameters = @{}
        $this.RequiresAdmin = $false
    }
}

# メニューデータ作成関数
function New-ConsoleGUIMenuData {
    <#
    .SYNOPSIS
    ConsoleGUIメニュー用のデータ構造を作成

    .DESCRIPTION
    Microsoft 365管理ツール用のConsoleGUIメニューデータを生成

    .OUTPUTS
    Array - メニューアイテムの配列

    .EXAMPLE
    $menuItems = New-ConsoleGUIMenuData
    #>
    
    $menuItems = @()
    
    # Active Directory 管理
    $menuItems += [PSCustomObject]@{
        ID = "AD001"
        Category = "🏢 Active Directory"
        Task = "AD連携とユーザー同期状況確認"
        Description = "Active DirectoryとEntra IDの同期状況確認"
        ScriptPath = "Scripts\AD\Test-ADSync.ps1"
        RequiresAdmin = $false
        Priority = "High"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "AD002"
        Category = "🏢 Active Directory"
        Task = "ADユーザーとグループ管理"
        Description = "Active Directoryのユーザーとグループ管理"
        ScriptPath = "Scripts\AD\Manage-ADUsers.ps1"
        RequiresAdmin = $true
        Priority = "Medium"
    }
    
    # Exchange Online 管理
    $menuItems += [PSCustomObject]@{
        ID = "EXO001"
        Category = "📧 Exchange Online"
        Task = "メールボックス容量監視"
        Description = "Exchange Onlineメールボックスの容量使用状況監視"
        ScriptPath = "Scripts\EXO\Get-MailboxUsage.ps1"
        RequiresAdmin = $false
        Priority = "High"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "EXO002"
        Category = "📧 Exchange Online"
        Task = "添付ファイル分析"
        Description = "大容量添付ファイルの分析と容量圧迫要因調査"
        ScriptPath = "Scripts\EXO\Analyze-Attachments.ps1"
        RequiresAdmin = $false
        Priority = "Medium"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "EXO003"
        Category = "📧 Exchange Online"
        Task = "スパムフィルター分析"
        Description = "スパムフィルターの効果測定と最適化提案"
        ScriptPath = "Scripts\EXO\Analyze-SpamFilter.ps1"
        RequiresAdmin = $false
        Priority = "Medium"
    }
    
    # Teams & OneDrive 管理
    $menuItems += [PSCustomObject]@{
        ID = "TM001"
        Category = "👥 Teams & OneDrive"
        Task = "OneDrive容量・Teams利用状況確認"
        Description = "OneDrive容量使用量とTeams利用状況の包括的分析"
        ScriptPath = "Scripts\EntraID\Get-ODTeamsUsage.ps1"
        RequiresAdmin = $false
        Priority = "High"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "TM002"
        Category = "👥 Teams & OneDrive"
        Task = "Teams会議使用状況分析"
        Description = "Teams会議の使用状況と生産性指標分析"
        ScriptPath = "Scripts\EntraID\Analyze-TeamsUsage.ps1"
        RequiresAdmin = $false
        Priority = "Medium"
    }
    
    # レポート機能
    $menuItems += [PSCustomObject]@{
        ID = "RPT001"
        Category = "📊 レポート機能"
        Task = "日次レポート生成"
        Description = "日次運用レポートの生成と出力"
        ScriptPath = "Scripts\Common\ScheduledReports.ps1"
        Parameters = @{ReportType = "Daily"}
        RequiresAdmin = $false
        Priority = "High"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "RPT002"
        Category = "📊 レポート機能"
        Task = "週次レポート生成"
        Description = "週次運用レポートの生成と出力"
        ScriptPath = "Scripts\Common\ScheduledReports.ps1"
        Parameters = @{ReportType = "Weekly"}
        RequiresAdmin = $false
        Priority = "Medium"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "RPT003"
        Category = "📊 レポート機能"
        Task = "月次レポート生成"
        Description = "月次運用レポートの生成と出力"
        ScriptPath = "Scripts\Common\ScheduledReports.ps1"
        Parameters = @{ReportType = "Monthly"}
        RequiresAdmin = $false
        Priority = "Medium"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "RPT004"
        Category = "📊 レポート機能"
        Task = "年次レポート生成"
        Description = "年次運用レポートの生成と出力"
        ScriptPath = "Scripts\Common\ScheduledReports.ps1"
        Parameters = @{ReportType = "Yearly"}
        RequiresAdmin = $false
        Priority = "Low"
    }
    
    # セキュリティ・コンプライアンス
    $menuItems += [PSCustomObject]@{
        ID = "SEC001"
        Category = "🔒 セキュリティ・コンプライアンス"
        Task = "セキュリティ監査"
        Description = "セキュリティ設定とコンプライアンス状況の包括的監査"
        ScriptPath = "Scripts\Common\SecurityAudit.ps1"
        RequiresAdmin = $true
        Priority = "High"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "SEC002"
        Category = "🔒 セキュリティ・コンプライアンス"
        Task = "MFA利用状況分析"
        Description = "多要素認証の利用状況分析と推奨事項"
        ScriptPath = "Scripts\EntraID\Analyze-MFA.ps1"
        RequiresAdmin = $false
        Priority = "High"
    }
    
    # 年間消費傾向・予算管理
    $menuItems += [PSCustomObject]@{
        ID = "BDG001"
        Category = "💰 年間消費傾向・予算管理"
        Task = "年間消費傾向アラート"
        Description = "年間ライセンス消費トレンドと予算アラート分析"
        Action = "YearlyConsumptionAlert"
        RequiresAdmin = $false
        Priority = "High"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "BDG002"
        Category = "💰 年間消費傾向・予算管理"
        Task = "ライセンス使用状況詳細分析"
        Description = "Microsoft 365ライセンスの詳細使用状況分析"
        ScriptPath = "Scripts\EntraID\Analyze-LicenseUsage.ps1"
        RequiresAdmin = $false
        Priority = "Medium"
    }
    
    # システム管理
    $menuItems += [PSCustomObject]@{
        ID = "SYS001"
        Category = "⚙️ システム管理"
        Task = "システム設定確認"
        Description = "システム設定の確認と健全性チェック"
        ScriptPath = "Scripts\Common\Test-SystemHealth.ps1"
        RequiresAdmin = $true
        Priority = "Medium"
    }
    
    $menuItems += [PSCustomObject]@{
        ID = "SYS002"
        Category = "⚙️ システム管理"
        Task = "ログ管理とクリーンアップ"
        Description = "ログファイルの管理とディスクスペースクリーンアップ"
        ScriptPath = "Scripts\Common\Manage-Logs.ps1"
        RequiresAdmin = $true
        Priority = "Low"
    }
    
    return $menuItems
}

# メインConsoleGUIメニュー表示関数
function Show-ConsoleGUIMainMenu {
    <#
    .SYNOPSIS
    ConsoleGUIメインメニューを表示

    .DESCRIPTION
    PowerShell 7系のConsoleGuiToolsを使用してインタラクティブなメニューを表示

    .EXAMPLE
    Show-ConsoleGUIMainMenu
    #>
    
    # ConsoleGUIサポート初期化
    if (-not (Initialize-ConsoleGUISupport)) {
        Write-Warning "ConsoleGUI機能が利用できません。CLIメニューに切り替えます。"
        return $false
    }
    
    do {
        try {
            Clear-Host
            Write-Host "🚀 Microsoft 365 統合管理システム (ConsoleGUI Mode)" -ForegroundColor Blue
            Write-Host "ITSM/ISO27001/27002準拠 エンタープライズ管理ツール" -ForegroundColor Cyan
            Write-Host ""
            
            # 環境情報表示
            $versionInfo = Get-PowerShellVersionInfo
            Write-Host "環境: PowerShell $($versionInfo.Version) ($($versionInfo.Edition)) - ConsoleGUI対応" -ForegroundColor Gray
            Write-Host ""
            
            # メニューデータ取得
            $menuItems = New-ConsoleGUIMenuData
            
            # カテゴリ選択
            $categories = $menuItems | Select-Object -Property Category -Unique | Sort-Object Category
            $selectedCategory = $categories | Out-ConsoleGridView -Title "📋 カテゴリを選択してください" -OutputMode Single
            
            if (-not $selectedCategory) {
                Write-Host "操作がキャンセルされました。メニューを終了します。" -ForegroundColor Yellow
                break
            }
            
            # 選択カテゴリのタスク一覧表示
            $categoryTasks = $menuItems | Where-Object { $_.Category -eq $selectedCategory.Category } | Sort-Object Priority, Task
            
            if ($categoryTasks.Count -eq 0) {
                Write-Host "選択されたカテゴリにタスクがありません。" -ForegroundColor Yellow
                Read-Host "続行するには Enter キーを押してください"
                continue
            }
            
            # タスク選択
            $selectedTask = $categoryTasks | Out-ConsoleGridView -Title "📋 実行するタスクを選択してください - $($selectedCategory.Category)" -OutputMode Single
            
            if (-not $selectedTask) {
                Write-Host "タスクが選択されませんでした。" -ForegroundColor Yellow
                continue
            }
            
            # タスク実行確認
            Write-Host ""
            Write-Host "選択されたタスク:" -ForegroundColor Cyan
            Write-Host "  ID: $($selectedTask.ID)" -ForegroundColor White
            Write-Host "  タスク: $($selectedTask.Task)" -ForegroundColor White
            Write-Host "  説明: $($selectedTask.Description)" -ForegroundColor Gray
            
            if ($selectedTask.RequiresAdmin) {
                Write-Host "  ⚠️ このタスクは管理者権限が必要です" -ForegroundColor Yellow
            }
            
            Write-Host ""
            $confirm = Read-Host "このタスクを実行しますか？ (Y/N)"
            
            if ($confirm -match "^[Yy]") {
                Execute-ConsoleGUITask -Task $selectedTask
            } else {
                Write-Host "タスクの実行をキャンセルしました。" -ForegroundColor Yellow
            }
            
            Write-Host ""
            $continueChoice = Read-Host "メニューを続行しますか？ (Y/N)"
            
        } catch {
            Write-Error "ConsoleGUIメニューでエラーが発生しました: $($_.Exception.Message)"
            Write-Host "CLIメニューに切り替えます..." -ForegroundColor Yellow
            return $false
        }
        
    } while ($continueChoice -match "^[Yy]")
    
    Write-Host "Microsoft 365 管理ツールを終了します。" -ForegroundColor Green
    return $true
}

# ConsoleGUIタスク実行関数
function Execute-ConsoleGUITask {
    <#
    .SYNOPSIS
    ConsoleGUIで選択されたタスクを実行

    .PARAMETER Task
    実行するタスクオブジェクト

    .EXAMPLE
    Execute-ConsoleGUITask -Task $selectedTask
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Task
    )
    
    Write-Host ""
    Write-Host "🔄 実行中: $($Task.Task)" -ForegroundColor Green
    Write-Host ""
    
    try {
        # 特殊アクション処理
        if ($Task.Action -eq "YearlyConsumptionAlert") {
            Invoke-YearlyConsumptionAlert
            return
        }
        
        # スクリプトパス実行
        if ($Task.ScriptPath) {
            $scriptFullPath = Join-Path $PSScriptRoot "..\..\$($Task.ScriptPath)"
            
            if (Test-Path $scriptFullPath) {
                if ($Task.Parameters -and $Task.Parameters.Count -gt 0) {
                    & $scriptFullPath @($Task.Parameters)
                } else {
                    & $scriptFullPath
                }
                Write-Host ""
                Write-Host "✅ タスクが正常に完了しました" -ForegroundColor Green
            } else {
                Write-Host "❌ スクリプトファイルが見つかりません: $scriptFullPath" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠️ このタスクはまだ実装されていません" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ タスク実行エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "続行するには Enter キーを押してください"
}

# 年間消費傾向アラート専用実行関数
function Invoke-YearlyConsumptionAlert {
    <#
    .SYNOPSIS
    年間消費傾向アラート機能の実行

    .DESCRIPTION
    ConsoleGUI環境での年間消費傾向アラート機能の実行とパラメータ入力

    .EXAMPLE
    Invoke-YearlyConsumptionAlert
    #>
    
    Write-Host "💰 年間消費傾向アラートシステム設定" -ForegroundColor Yellow
    Write-Host ""
    
    # パラメータ設定オプション提示
    $paramOptions = @(
        [PSCustomObject]@{
            Option = "デフォルト設定"
            BudgetLimit = 5000000
            AlertThreshold = 80
            Description = "予算上限: ¥5,000,000 / アラート閾値: 80%"
        },
        [PSCustomObject]@{
            Option = "カスタム設定"
            BudgetLimit = 0
            AlertThreshold = 0
            Description = "手動でパラメータを設定"
        }
    )
    
    try {
        $selectedOption = $paramOptions | Out-ConsoleGridView -Title "💰 設定オプションを選択してください" -OutputMode Single
        
        if (-not $selectedOption) {
            Write-Host "設定がキャンセルされました。" -ForegroundColor Yellow
            return
        }
        
        $budgetLimit = $selectedOption.BudgetLimit
        $alertThreshold = $selectedOption.AlertThreshold
        
        # カスタム設定の場合は手動入力
        if ($selectedOption.Option -eq "カスタム設定") {
            Write-Host ""
            $budgetInput = Read-Host "年間予算上限を入力してください (例: 5000000)"
            if ($budgetInput -match "^\d+$") {
                $budgetLimit = [long]$budgetInput
            } else {
                Write-Host "無効な入力です。デフォルト値（¥5,000,000）を使用します。" -ForegroundColor Yellow
                $budgetLimit = 5000000
            }
            
            $thresholdInput = Read-Host "アラート閾値(%)を入力してください (例: 80)"
            if ($thresholdInput -match "^\d+$") {
                $alertThreshold = [int]$thresholdInput
            } else {
                Write-Host "無効な入力です。デフォルト値（80%）を使用します。" -ForegroundColor Yellow
                $alertThreshold = 80
            }
        }
        
        Write-Host ""
        Write-Host "設定確認:" -ForegroundColor Cyan
        Write-Host "  年間予算上限: ¥$($budgetLimit.ToString('N0'))" -ForegroundColor White
        Write-Host "  アラート閾値: $alertThreshold%" -ForegroundColor White
        Write-Host ""
        
        # 年間消費傾向アラート実行
        $yearlyAlertScriptPath = Join-Path $PSScriptRoot "..\..\Scripts\EntraID\YearlyConsumptionAlert.ps1"
        
        if (Test-Path $yearlyAlertScriptPath) {
            Write-Host "🔄 年間消費傾向アラート分析を実行中..." -ForegroundColor Green
            
            . $yearlyAlertScriptPath
            $result = Get-YearlyConsumptionAlert -BudgetLimit $budgetLimit -AlertThreshold $alertThreshold -ExportHTML -ExportCSV
            
            if ($result.Success) {
                Write-Host ""
                Write-Host "✅ 年間消費傾向アラート分析が完了しました!" -ForegroundColor Green
                Write-Host ""
                Write-Host "📊 結果サマリー:" -ForegroundColor Cyan
                Write-Host "  現在ライセンス数: $($result.TotalLicenses)" -ForegroundColor White
                Write-Host "  年間予測消費: $($result.PredictedYearlyConsumption)" -ForegroundColor White
                Write-Host "  予算使用率: $($result.BudgetUtilization)%" -ForegroundColor $(if($result.BudgetUtilization -gt 100) {"Red"} elseif($result.BudgetUtilization -gt 90) {"Yellow"} else {"Green"})
                Write-Host "  🚨 緊急アラート: $($result.CriticalAlerts)件" -ForegroundColor Red
                Write-Host "  ⚠️ 警告アラート: $($result.WarningAlerts)件" -ForegroundColor Yellow
                
                if ($result.HTMLPath) {
                    Write-Host ""
                    Write-Host "📄 生成されたレポート:" -ForegroundColor Cyan
                    Write-Host "  HTMLダッシュボード: $($result.HTMLPath)" -ForegroundColor Green
                    
                    # レポートを開くかの確認
                    $openReport = Read-Host "HTMLレポートを開きますか？ (Y/N)"
                    if ($openReport -match "^[Yy]") {
                        try {
                            Start-Process $result.HTMLPath
                        } catch {
                            Write-Host "レポートを開けませんでした: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                }
            } else {
                Write-Host "❌ 分析中にエラーが発生しました: $($result.Error)" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ 年間消費傾向アラートスクリプトが見つかりません" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ 年間消費傾向アラート実行エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ConsoleGUI機能のテスト関数
function Test-ConsoleGUIFeatures {
    <#
    .SYNOPSIS
    ConsoleGUI機能のテスト

    .DESCRIPTION
    ConsoleGUI機能が正常に動作するかテスト

    .OUTPUTS
    Boolean - テスト結果

    .EXAMPLE
    Test-ConsoleGUIFeatures
    #>
    
    try {
        # ConsoleGuiToolsの初期化テスト
        if (-not (Initialize-ConsoleGUISupport)) {
            return $false
        }
        
        # 簡単なテストデータでOut-ConsoleGridViewをテスト
        $testData = @(
            [PSCustomObject]@{Name = "Test1"; Value = "Value1"}
            [PSCustomObject]@{Name = "Test2"; Value = "Value2"}
        )
        
        # Out-ConsoleGridViewが動作するかテスト（実際には表示しない）
        $testResult = $testData | Out-ConsoleGridView -Title "テスト" -OutputMode None
        
        return $true
        
    } catch {
        Write-Verbose "ConsoleGUI機能テストに失敗: $($_.Exception.Message)"
        return $false
    }
}

# モジュール初期化
if (-not (Initialize-ConsoleGUISupport)) {
    Write-Warning "ConsoleGUI機能が初期化できませんでした。Install-Module Microsoft.PowerShell.ConsoleGuiTools を実行してください。"
}

# エクスポートする関数
Export-ModuleMember -Function @(
    'Initialize-ConsoleGUISupport',
    'Show-ConsoleGUIMainMenu',
    'Test-ConsoleGUIFeatures',
    'New-ConsoleGUIMenuData'
)