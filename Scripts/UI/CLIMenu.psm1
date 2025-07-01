# ================================================================================
# CLIMenu.psm1
# PowerShell 5.1系対応 改良CLIメニューシステム
# ================================================================================

# 必要モジュールのインポート
Import-Module "$PSScriptRoot\..\Common\VersionDetection.psm1" -Force
Import-Module "$PSScriptRoot\EncodingManager.psm1" -Force

# メニュー設定構造体
class MenuConfig {
    [string]$Title
    [string]$Subtitle
    [System.Collections.ArrayList]$Categories
    [hashtable]$Colors
    [int]$Width
    [bool]$ShowBreadcrumb
    
    MenuConfig() {
        $this.Categories = [System.Collections.ArrayList]::new()
        $this.Colors = @{
            Header = "Blue"
            Category = "Cyan" 
            Item = "White"
            Accent = "Yellow"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Input = "Gray"
        }
        $this.Width = 70
        $this.ShowBreadcrumb = $true
    }
}

class MenuCategory {
    [string]$Name
    [string]$Description
    [System.Collections.ArrayList]$Items
    [ConsoleColor]$Color
    
    MenuCategory([string]$name, [string]$description) {
        $this.Name = $name
        $this.Description = $description
        $this.Items = [System.Collections.ArrayList]::new()
        $this.Color = "Cyan"
    }
}

class MenuItem {
    [string]$Id
    [string]$Name
    [string]$Description
    [string]$ScriptPath
    [hashtable]$Parameters
    [bool]$RequiresAdmin
    [string]$Category
    [scriptblock]$Action
    
    MenuItem([string]$id, [string]$name, [string]$description) {
        $this.Id = $id
        $this.Name = $name
        $this.Description = $description
        $this.Parameters = @{}
        $this.RequiresAdmin = $false
    }
}

# グローバルメニュー設定
$Script:CurrentMenuConfig = $null
$Script:NavigationStack = [System.Collections.ArrayList]::new()

# メニュー設定を初期化する関数
function Initialize-CLIMenuConfig {
    <#
    .SYNOPSIS
    CLIメニューの設定を初期化

    .DESCRIPTION
    Microsoft 365管理ツール用のCLIメニュー構成を作成

    .EXAMPLE
    Initialize-CLIMenuConfig
    #>
    
    $config = [MenuConfig]::new()
    $config.Title = "Microsoft 365 統合管理システム"
    $config.Subtitle = "ITSM/ISO27001/27002準拠 エンタープライズ管理ツール"
    
    # 基本機能カテゴリ
    $basicCategory = [MenuCategory]::new("基本機能", "日常運用で使用する基本的な管理機能")
    
    $item1 = [MenuItem]::new("1", "AD連携とユーザー同期状況確認", "Active DirectoryとEntra IDの同期状況を確認")
    $item1.ScriptPath = "Scripts\AD\Test-ADSync.ps1"
    $item1.Category = "AD"
    $basicCategory.Items.Add($item1)
    
    $item2 = [MenuItem]::new("2", "Exchangeメールボックス容量監視", "Exchange Onlineメールボックスの容量使用状況を監視")
    $item2.ScriptPath = "Scripts\EXO\Get-MailboxUsage.ps1"
    $item2.Category = "EXO"
    $basicCategory.Items.Add($item2)
    
    $item3 = [MenuItem]::new("3", "OneDrive容量・Teams利用状況確認", "OneDrive容量とTeams利用状況の確認")
    $item3.ScriptPath = "Scripts\EntraID\Get-ODTeamsUsage.ps1"
    $item3.Category = "Teams"
    $basicCategory.Items.Add($item3)
    
    # レポート機能カテゴリ
    $reportCategory = [MenuCategory]::new("レポート機能", "各種レポートの生成と出力")
    
    $item4 = [MenuItem]::new("4", "日次/週次/月次レポート生成", "定期レポートの生成と出力")
    $item4.Category = "Reports"
    $item4.Action = { Show-ReportMenu }
    $reportCategory.Items.Add($item4)
    
    # 高度な管理機能カテゴリ
    $advancedCategory = [MenuCategory]::new("高度な管理機能", "管理者向けの高度な管理機能")
    
    $item5 = [MenuItem]::new("5", "セキュリティとコンプライアンス監査", "セキュリティ設定とコンプライアンス状況の監査")
    $item5.ScriptPath = "Scripts\Common\SecurityAudit.ps1"
    $item5.RequiresAdmin = $true
    $item5.Category = "Security"
    $advancedCategory.Items.Add($item5)
    
    $item6 = [MenuItem]::new("6", "年間消費傾向のアラート出力", "年間ライセンス消費トレンドと予算アラート分析")
    $item6.Category = "Analysis"
    $item6.Action = { Show-YearlyConsumptionMenu }
    $advancedCategory.Items.Add($item6)
    
    $item7 = [MenuItem]::new("7", "ユーザー・グループ管理", "ユーザーとグループの管理機能")
    $item7.Category = "UserManagement"
    $item7.Action = { Show-UserManagementMenu }
    $advancedCategory.Items.Add($item7)
    
    # システム機能カテゴリ
    $systemCategory = [MenuCategory]::new("システム機能", "システム設定と保守機能")
    
    $item8 = [MenuItem]::new("8", "システム設定とメンテナンス", "システム設定の確認と保守作業")
    $item8.Category = "System"
    $item8.Action = { Show-SystemMenu }
    $systemCategory.Items.Add($item8)
    
    $item9 = [MenuItem]::new("9", "Exchange Online詳細管理", "Exchange Onlineの詳細管理機能")
    $item9.Category = "EXO"
    $item9.Action = { Show-ExchangeMenu }
    $systemCategory.Items.Add($item9)
    
    # カテゴリを設定に追加
    $config.Categories.Add($basicCategory)
    $config.Categories.Add($reportCategory)
    $config.Categories.Add($advancedCategory)
    $config.Categories.Add($systemCategory)
    
    $Script:CurrentMenuConfig = $config
}

# メインメニューを表示する関数
function Show-CLIMainMenu {
    <#
    .SYNOPSIS
    改良されたCLIメインメニューを表示

    .DESCRIPTION
    PowerShell 5.1系に最適化された文字化け対策済みCLIメニューを表示

    .EXAMPLE
    Show-CLIMainMenu
    #>
    
    if ($null -eq $Script:CurrentMenuConfig) {
        Initialize-CLIMenuConfig | Out-Null
    }
    
    $continueMenu = $true
    do {
        Clear-Host
        
        # エンコーディング初期化
        Initialize-EncodingSupport
        
        # ヘッダー表示
        Show-MenuHeader
        
        # ナビゲーション表示
        if ($Script:CurrentMenuConfig.ShowBreadcrumb -and $Script:NavigationStack.Count -gt 0) {
            Show-Breadcrumb
        }
        
        # メニューカテゴリ表示
        Show-MenuCategories
        
        # フッター表示
        Show-MenuFooter
        
        # ユーザー入力受付
        $selection = Read-MenuInput
        
        # 選択処理
        $continueMenu = Process-MenuSelection -Selection $selection
        
    } while ($continueMenu)
}

# メニューヘッダーを表示する関数
function Show-MenuHeader {
    $config = $Script:CurrentMenuConfig
    
    Write-SafeBox -Title $config.Title -Width $config.Width -Color $config.Colors.Header
    Write-Host ""
    Write-SafeString -Text "    $($config.Subtitle)" -ForegroundColor $config.Colors.Header
    Write-Host ""
    
    # PowerShell環境情報
    $versionInfo = Get-PowerShellVersionInfo
    $envText = "PowerShell $($versionInfo.Version) ($($versionInfo.Edition)) - $($versionInfo.CompatibilityLevel)"
    Write-SafeString -Text "    環境: $envText" -ForegroundColor Gray
    Write-Host ""
    
    Write-SafeString -Text ("=" * $config.Width) -ForegroundColor $config.Colors.Accent
}

# ブレッドクラム表示関数
function Show-Breadcrumb {
    $breadcrumb = "ホーム"
    if ($Script:NavigationStack.Count -gt 0) {
        $breadcrumb += " > " + ($Script:NavigationStack -join " > ")
    }
    Write-SafeString -Text "    📍 ナビゲーション: $breadcrumb" -ForegroundColor Gray
    Write-Host ""
}

# メニューカテゴリ表示関数
function Show-MenuCategories {
    $config = $Script:CurrentMenuConfig
    
    foreach ($category in $config.Categories) {
        Write-Host ""
        Write-SafeString -Text "【$($category.Name)】 - $($category.Description)" -ForegroundColor $config.Colors.Category
        Write-SafeString -Text ("-" * ($config.Width - 10)) -ForegroundColor $config.Colors.Category
        
        foreach ($item in $category.Items) {
            $prefix = "   $($item.Id)."
            $adminMark = if ($item.RequiresAdmin) { " [管理者権限必要]" } else { "" }
            $itemText = "$prefix $($item.Name)$adminMark"
            
            Write-SafeString -Text $itemText -ForegroundColor $config.Colors.Item
            
            if ($item.Description) {
                Write-SafeString -Text "       └ $($item.Description)" -ForegroundColor Gray
            }
        }
    }
}

# メニューフッター表示関数
function Show-MenuFooter {
    $config = $Script:CurrentMenuConfig
    
    Write-Host ""
    Write-SafeString -Text ("=" * $config.Width) -ForegroundColor $config.Colors.Accent
    Write-Host ""
    Write-SafeString -Text "   H: ヘルプ表示 | R: 最新情報に更新 | Q: 終了" -ForegroundColor $config.Colors.Input
    Write-Host ""
}

# ユーザー入力受付関数
function Read-MenuInput {
    Write-SafeString -Text "選択してください (1-9, H, R, Q): " -ForegroundColor $Script:CurrentMenuConfig.Colors.Input -NoNewline
    $input = Read-Host
    return $input.Trim()
}

# メニュー選択処理関数
function Process-MenuSelection {
    param([string]$Selection)
    
    $config = $Script:CurrentMenuConfig
    
    switch ($Selection.ToUpper()) {
        "H" { 
            Show-Help
            Read-Host "`n続行するには Enter キーを押してください"
            return $true
        }
        "R" { 
            Write-SafeString -Text "✓ メニューを更新しました" -ForegroundColor $config.Colors.Success
            Start-Sleep -Seconds 1
            return $true
        }
        "Q" { 
            Write-SafeString -Text "Microsoft 365 管理ツールを終了します..." -ForegroundColor $config.Colors.Warning
            return $false
        }
        default {
            # 数値選択の処理
            if ($Selection -match "^\d+$") {
                $selectedItem = Find-MenuItemById -Id $Selection
                if ($selectedItem) {
                    Execute-MenuItem -Item $selectedItem
                } else {
                    Write-SafeString -Text "✗ 無効な選択です: $Selection" -ForegroundColor $config.Colors.Error
                    Start-Sleep -Seconds 2
                }
            } else {
                Write-SafeString -Text "✗ 無効な入力です: $Selection" -ForegroundColor $config.Colors.Error
                Start-Sleep -Seconds 2
            }
            return $true
        }
    }
}

# メニューアイテム検索関数
function Find-MenuItemById {
    param([string]$Id)
    
    foreach ($category in $Script:CurrentMenuConfig.Categories) {
        foreach ($item in $category.Items) {
            if ($item.Id -eq $Id) {
                return $item
            }
        }
    }
    return $null
}

# メニューアイテム実行関数
function Execute-MenuItem {
    param([MenuItem]$Item)
    
    $config = $Script:CurrentMenuConfig
    
    Write-SafeString -Text "実行中: $($Item.Name)" -ForegroundColor $config.Colors.Success
    Write-Host ""
    
    try {
        if ($Item.Action) {
            # ScriptBlock実行
            & $Item.Action
        } elseif ($Item.ScriptPath) {
            # スクリプトファイル実行
            $projectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
            $scriptFullPath = Join-Path -Path $projectRoot -ChildPath $Item.ScriptPath
            if (Test-Path $scriptFullPath) {
                & $scriptFullPath
            } else {
                Write-SafeString -Text "✗ スクリプトファイルが見つかりません: $scriptFullPath" -ForegroundColor $config.Colors.Error
            }
        } else {
            Write-SafeString -Text "⚠ このメニューアイテムはまだ実装されていません" -ForegroundColor $config.Colors.Warning
        }
    } catch {
        Write-SafeString -Text "✗ 実行エラー: $($_.Exception.Message)" -ForegroundColor $config.Colors.Error
    }
    
    Write-Host ""
    Read-Host "続行するには Enter キーを押してください"
}

# ヘルプ表示関数
function Show-Help {
    Clear-Host
    Write-SafeBox -Title "Microsoft 365 管理ツール - ヘルプ" -Width 70 -Color Blue
    
    Write-Host @"

📖 使用方法:
   • 各機能は番号で選択できます (1-9)
   • H: このヘルプを表示
   • R: メニューを最新情報に更新
   • Q: ツールを終了

🔧 基本機能:
   1-3: 日常運用で使用する基本的な監視・確認機能
   
📊 レポート機能:
   4: 各種定期レポートの生成と出力
   
⚙️ 高度な管理機能:
   5-7: 管理者向けの高度な分析・管理機能
   
🛠️ システム機能:
   8-9: システム設定と詳細管理機能

⚠️ 注意事項:
   • [管理者権限必要] と表示される機能は、管理者として実行してください
   • 一部機能はMicrosoft 365の適切な権限が必要です
   • レポート出力先: Reports フォルダ

📞 サポート:
   技術的な問題がある場合は、システム管理者にお問い合わせください

"@ -ForegroundColor White
}

# サブメニュー: レポート機能
function Show-ReportMenu {
    $Script:NavigationStack.Add("レポート機能")
    
    do {
        Clear-Host
        Write-SafeBox -Title "レポート生成メニュー" -Width 70 -Color Green
        Show-Breadcrumb
        
        Write-Host @"

【定期レポート】
   1. 日次レポート生成
   2. 週次レポート生成  
   3. 月次レポート生成
   4. 年次レポート生成

【特別レポート】
   5. セキュリティ監査レポート
   6. 容量使用状況レポート
   7. ライセンス使用状況レポート

   B: 戻る | Q: メインメニューに戻る

"@ -ForegroundColor White
        
        $selection = Read-Host "選択してください"
        
        switch ($selection.ToUpper()) {
            "1" { 
                Execute-ScriptWithParams -ScriptPath "Scripts\Common\ScheduledReports.ps1" -Parameters @{ReportType="Daily"}
                Read-Host "続行するには Enter キーを押してください"
            }
            "2" { 
                Execute-ScriptWithParams -ScriptPath "Scripts\Common\ScheduledReports.ps1" -Parameters @{ReportType="Weekly"}
                Read-Host "続行するには Enter キーを押してください"
            }
            "3" { 
                Execute-ScriptWithParams -ScriptPath "Scripts\Common\ScheduledReports.ps1" -Parameters @{ReportType="Monthly"}
                Read-Host "続行するには Enter キーを押してください"
            }
            "4" { 
                Execute-ScriptWithParams -ScriptPath "Scripts\Common\ScheduledReports.ps1" -Parameters @{ReportType="Yearly"}
                Read-Host "続行するには Enter キーを押してください"
            }
            "B" { 
                $Script:NavigationStack.RemoveAt($Script:NavigationStack.Count - 1)
                return 
            }
            "Q" { 
                $Script:NavigationStack.Clear()
                return 
            }
            default {
                Write-SafeString -Text "✗ 無効な選択です" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($true)
}

# サブメニュー: 年間消費傾向
function Show-YearlyConsumptionMenu {
    $Script:NavigationStack.Add("年間消費傾向アラート")
    
    Clear-Host
    Write-SafeBox -Title "年間消費傾向アラート設定" -Width 70 -Color Red
    Show-Breadcrumb
    
    Write-Host ""
    Write-SafeString -Text "年間消費傾向アラートシステムの設定を行います" -ForegroundColor Yellow
    Write-Host ""
    
    # 予算上限入力
    $budgetLimit = Read-Host "年間予算上限を入力してください (例: 5000000)"
    if (-not $budgetLimit -or $budgetLimit -notmatch "^\d+$") {
        $budgetLimit = 5000000
        Write-SafeString -Text "デフォルト値を使用: ¥5,000,000" -ForegroundColor Yellow
    }
    
    # アラート閾値入力
    $alertThreshold = Read-Host "アラート閾値(%)を入力してください (例: 80)"
    if (-not $alertThreshold -or $alertThreshold -notmatch "^\d+$") {
        $alertThreshold = 80
        Write-SafeString -Text "デフォルト値を使用: 80%" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-SafeString -Text "年間消費傾向アラート分析を実行中..." -ForegroundColor Green
    
    try {
        $yearlyAlertScriptPath = Join-Path $PSScriptRoot "..\..\Scripts\EntraID\YearlyConsumptionAlert.ps1"
        
        if (Test-Path $yearlyAlertScriptPath) {
            . $yearlyAlertScriptPath
            $result = Get-YearlyConsumptionAlert -BudgetLimit ([long]$budgetLimit) -AlertThreshold ([int]$alertThreshold) -ExportHTML -ExportCSV
            
            if ($result.Success) {
                Write-SafeString -Text "✓ 年間消費傾向アラート分析が完了しました" -ForegroundColor Green
                Write-Host ""
                Write-SafeString -Text "結果サマリー:" -ForegroundColor Cyan
                Write-SafeString -Text "  現在ライセンス数: $($result.TotalLicenses)" -ForegroundColor White
                Write-SafeString -Text "  年間予測消費: $($result.PredictedYearlyConsumption)" -ForegroundColor White
                Write-SafeString -Text "  予算使用率: $($result.BudgetUtilization)%" -ForegroundColor White
                Write-SafeString -Text "  緊急アラート: $($result.CriticalAlerts)件" -ForegroundColor Red
                Write-SafeString -Text "  警告アラート: $($result.WarningAlerts)件" -ForegroundColor Yellow
                
                if ($result.HTMLPath) {
                    Write-SafeString -Text "  HTMLダッシュボード: $($result.HTMLPath)" -ForegroundColor Green
                }
            } else {
                Write-SafeString -Text "✗ 分析中にエラーが発生しました: $($result.Error)" -ForegroundColor Red
            }
        } else {
            Write-SafeString -Text "✗ 年間消費傾向アラートスクリプトが見つかりません" -ForegroundColor Red
        }
    } catch {
        Write-SafeString -Text "✗ 実行エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "続行するには Enter キーを押してください"
    $Script:NavigationStack.RemoveAt($Script:NavigationStack.Count - 1)
}

# スクリプト実行補助関数
function Execute-ScriptWithParams {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )
    
    # プロジェクトルートディレクトリを取得
    $projectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $fullPath = Join-Path -Path $projectRoot -ChildPath $ScriptPath
    
    if (Test-Path $fullPath) {
        try {
            Write-SafeString -Text "実行中: $ScriptPath" -ForegroundColor Green
            if ($Parameters.Count -gt 0) {
                & $fullPath @Parameters
            } else {
                & $fullPath
            }
        } catch {
            Write-SafeString -Text "✗ スクリプト実行エラー: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-SafeString -Text "✗ スクリプトファイルが見つかりません: $fullPath" -ForegroundColor Red
    }
}

# エクスポートする関数
Export-ModuleMember -Function @(
    'Initialize-CLIMenuConfig',
    'Show-CLIMainMenu',
    'Show-ReportMenu',
    'Show-YearlyConsumptionMenu'
)