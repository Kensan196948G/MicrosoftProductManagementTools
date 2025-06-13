# ================================================================================
# MenuConfig.psm1
# 設定ベースのメニュー管理システム
# ================================================================================

# 設定ベースメニュー管理クラス
class MenuConfigManager {
    [string]$ConfigPath
    [PSCustomObject]$MenuConfig
    [datetime]$LastLoaded
    
    MenuConfigManager([string]$configPath) {
        $this.ConfigPath = $configPath
        $this.LastLoaded = [datetime]::MinValue
        $this.LoadConfig()
    }
    
    # 設定ファイルから設定を読み込み
    [void]LoadConfig() {
        try {
            if (Test-Path $this.ConfigPath) {
                $configContent = Get-Content $this.ConfigPath -Encoding UTF8 | ConvertFrom-Json
                
                # メニュー設定が存在する場合は読み込み、そうでなければデフォルト設定を作成
                if ($configContent.PSObject.Properties['MenuConfiguration']) {
                    $this.MenuConfig = $configContent.MenuConfiguration
                } else {
                    $this.MenuConfig = $this.CreateDefaultMenuConfig()
                    $this.SaveConfig()
                }
                
                $this.LastLoaded = Get-Date
                Write-Verbose "メニュー設定を読み込みました: $($this.ConfigPath)"
            } else {
                Write-Warning "設定ファイルが見つかりません: $($this.ConfigPath)"
                $this.MenuConfig = $this.CreateDefaultMenuConfig()
            }
        } catch {
            Write-Warning "設定ファイルの読み込みに失敗しました: $($_.Exception.Message)"
            $this.MenuConfig = $this.CreateDefaultMenuConfig()
        }
    }
    
    # デフォルトメニュー設定を作成
    [PSCustomObject]CreateDefaultMenuConfig() {
        return [PSCustomObject]@{
            MenuEngine = @{
                DefaultMenuType = "Auto"
                EnableAutoDetection = $true
                FallbackToCLI = $true
                ShowBreadcrumb = $true
                MenuWidth = 70
            }
            
            MenuCategories = @(
                @{
                    Id = "basic"
                    Name = "基本機能"
                    Description = "日常運用で使用する基本的な管理機能"
                    Icon = "🏢"
                    Order = 1
                    Enabled = $true
                },
                @{
                    Id = "reports"
                    Name = "レポート機能"
                    Description = "各種レポートの生成と出力"
                    Icon = "📊"
                    Order = 2
                    Enabled = $true
                },
                @{
                    Id = "advanced"
                    Name = "高度な管理機能"
                    Description = "管理者向けの高度な分析・管理機能"
                    Icon = "⚙️"
                    Order = 3
                    Enabled = $true
                },
                @{
                    Id = "system"
                    Name = "システム機能"
                    Description = "システム設定と保守機能"
                    Icon = "🛠️"
                    Order = 4
                    Enabled = $true
                }
            )
            
            MenuItems = @(
                # 基本機能
                @{
                    Id = "AD001"
                    CategoryId = "basic"
                    Name = "AD連携とユーザー同期状況確認"
                    Description = "Active DirectoryとEntra IDの同期状況を確認"
                    ScriptPath = "Scripts\AD\Test-ADSync.ps1"
                    Icon = "👥"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 1
                },
                @{
                    Id = "EXO001"
                    CategoryId = "basic"
                    Name = "Exchangeメールボックス容量監視"
                    Description = "Exchange Onlineメールボックスの容量使用状況を監視"
                    ScriptPath = "Scripts\EXO\Get-MailboxUsage.ps1"
                    Icon = "📧"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 2
                },
                @{
                    Id = "TM001"
                    CategoryId = "basic"
                    Name = "OneDrive容量・Teams利用状況確認"
                    Description = "OneDrive容量とTeams利用状況の確認"
                    ScriptPath = "Scripts\EntraID\Get-ODTeamsUsage.ps1"
                    Icon = "☁️"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 3
                },
                
                # レポート機能
                @{
                    Id = "RPT001"
                    CategoryId = "reports"
                    Name = "日次レポート生成"
                    Description = "日次運用レポートの生成と出力"
                    ScriptPath = "Scripts\Common\ScheduledReports.ps1"
                    Parameters = @{ReportType = "Daily"}
                    Icon = "📋"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 1
                },
                @{
                    Id = "RPT002"
                    CategoryId = "reports"
                    Name = "週次レポート生成"
                    Description = "週次運用レポートの生成と出力"
                    ScriptPath = "Scripts\Common\ScheduledReports.ps1"
                    Parameters = @{ReportType = "Weekly"}
                    Icon = "📅"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 2
                },
                @{
                    Id = "RPT003"
                    CategoryId = "reports"
                    Name = "月次レポート生成"
                    Description = "月次運用レポートの生成と出力"
                    ScriptPath = "Scripts\Common\ScheduledReports.ps1"
                    Parameters = @{ReportType = "Monthly"}
                    Icon = "📆"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 3
                },
                @{
                    Id = "RPT004"
                    CategoryId = "reports"
                    Name = "年次レポート生成"
                    Description = "年次運用レポートの生成と出力"
                    ScriptPath = "Scripts\Common\ScheduledReports.ps1"
                    Parameters = @{ReportType = "Yearly"}
                    Icon = "📈"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 4
                },
                
                # 高度な管理機能
                @{
                    Id = "SEC001"
                    CategoryId = "advanced"
                    Name = "セキュリティとコンプライアンス監査"
                    Description = "セキュリティ設定とコンプライアンス状況の監査"
                    ScriptPath = "Scripts\Common\SecurityAudit.ps1"
                    Icon = "🔒"
                    RequiresAdmin = $true
                    Enabled = $true
                    Order = 1
                },
                @{
                    Id = "BDG001"
                    CategoryId = "advanced"
                    Name = "年間消費傾向のアラート出力"
                    Description = "年間ライセンス消費トレンドと予算アラート分析"
                    Action = "YearlyConsumptionAlert"
                    Icon = "💰"
                    RequiresAdmin = $false
                    Enabled = $true
                    Order = 2
                },
                @{
                    Id = "USR001"
                    CategoryId = "advanced"
                    Name = "ユーザー・グループ管理"
                    Description = "ユーザーとグループの管理機能"
                    Action = "UserManagement"
                    Icon = "👤"
                    RequiresAdmin = $true
                    Enabled = $true
                    Order = 3
                },
                
                # システム機能
                @{
                    Id = "SYS001"
                    CategoryId = "system"
                    Name = "システム設定とメンテナンス"
                    Description = "システム設定の確認と保守作業"
                    Action = "SystemMaintenance"
                    Icon = "⚙️"
                    RequiresAdmin = $true
                    Enabled = $true
                    Order = 1
                },
                @{
                    Id = "EXO002"
                    CategoryId = "system"
                    Name = "Exchange Online詳細管理"
                    Description = "Exchange Onlineの詳細管理機能"
                    Action = "ExchangeManagement"
                    Icon = "📬"
                    RequiresAdmin = $true
                    Enabled = $true
                    Order = 2
                }
            )
            
            UISettings = @{
                Colors = @{
                    Header = "Blue"
                    Category = "Cyan"
                    Item = "White"
                    Accent = "Yellow"
                    Success = "Green"
                    Warning = "Yellow"
                    Error = "Red"
                    Input = "Gray"
                }
                Encoding = @{
                    ForceUTF8 = $true
                    UseSafeCharacters = $true
                    EnableUnicodeTest = $true
                }
                Layout = @{
                    MenuWidth = 70
                    ShowIcons = $true
                    ShowDescriptions = $true
                    ShowBreadcrumb = $true
                }
            }
            
            Version = "1.0.0"
            LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    # 設定をファイルに保存
    [void]SaveConfig() {
        try {
            # 既存の設定ファイルを読み込み
            $existingConfig = @{}
            if (Test-Path $this.ConfigPath) {
                $existingConfig = Get-Content $this.ConfigPath -Encoding UTF8 | ConvertFrom-Json
            }
            
            # メニュー設定を更新
            $existingConfig | Add-Member -MemberType NoteProperty -Name "MenuConfiguration" -Value $this.MenuConfig -Force
            
            # ファイルに保存
            $existingConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.ConfigPath -Encoding UTF8
            
            Write-Verbose "メニュー設定を保存しました: $($this.ConfigPath)"
        } catch {
            Write-Warning "設定ファイルの保存に失敗しました: $($_.Exception.Message)"
        }
    }
    
    # 設定の再読み込み
    [void]ReloadConfig() {
        $this.LoadConfig()
    }
}

# グローバル設定マネージャー
$Script:MenuConfigManager = $null

# メニュー設定マネージャーを初期化
function Initialize-MenuConfigManager {
    <#
    .SYNOPSIS
    メニュー設定マネージャーを初期化

    .PARAMETER ConfigPath
    設定ファイルのパス

    .EXAMPLE
    Initialize-MenuConfigManager -ConfigPath "Config\appsettings.json"
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "Config\appsettings.json"
    )
    
    try {
        # 相対パスを絶対パスに変換
        if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
            $ConfigPath = Join-Path $PSScriptRoot "..\..\$ConfigPath"
        }
        
        $Script:MenuConfigManager = [MenuConfigManager]::new($ConfigPath)
        Write-Verbose "メニュー設定マネージャーを初期化しました"
        
        return @{
            Success = $true
            ConfigPath = $ConfigPath
            Manager = $Script:MenuConfigManager
        }
    } catch {
        Write-Error "メニュー設定マネージャーの初期化に失敗しました: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# メニュー設定を取得
function Get-MenuConfiguration {
    <#
    .SYNOPSIS
    現在のメニュー設定を取得

    .OUTPUTS
    PSCustomObject - メニュー設定

    .EXAMPLE
    $config = Get-MenuConfiguration
    #>
    
    if ($null -eq $Script:MenuConfigManager) {
        Initialize-MenuConfigManager
    }
    
    return $Script:MenuConfigManager.MenuConfig
}

# カテゴリ一覧を取得
function Get-MenuCategories {
    <#
    .SYNOPSIS
    有効なメニューカテゴリ一覧を取得

    .PARAMETER IncludeDisabled
    無効なカテゴリも含めるか

    .OUTPUTS
    Array - カテゴリ配列

    .EXAMPLE
    $categories = Get-MenuCategories
    #>
    
    param(
        [switch]$IncludeDisabled
    )
    
    $config = Get-MenuConfiguration
    $categories = $config.MenuCategories
    
    if (-not $IncludeDisabled) {
        $categories = $categories | Where-Object { $_.Enabled -eq $true }
    }
    
    return $categories | Sort-Object Order
}

# カテゴリ別メニューアイテムを取得
function Get-MenuItemsByCategory {
    <#
    .SYNOPSIS
    指定カテゴリのメニューアイテム一覧を取得

    .PARAMETER CategoryId
    カテゴリID

    .PARAMETER IncludeDisabled
    無効なアイテムも含めるか

    .OUTPUTS
    Array - メニューアイテム配列

    .EXAMPLE
    $items = Get-MenuItemsByCategory -CategoryId "basic"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryId,
        
        [switch]$IncludeDisabled
    )
    
    $config = Get-MenuConfiguration
    $items = $config.MenuItems | Where-Object { $_.CategoryId -eq $CategoryId }
    
    if (-not $IncludeDisabled) {
        $items = $items | Where-Object { $_.Enabled -eq $true }
    }
    
    return $items | Sort-Object Order
}

# メニューアイテムをIDで取得
function Get-MenuItemById {
    <#
    .SYNOPSIS
    指定IDのメニューアイテムを取得

    .PARAMETER ItemId
    アイテムID

    .OUTPUTS
    PSCustomObject - メニューアイテム

    .EXAMPLE
    $item = Get-MenuItemById -ItemId "AD001"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemId
    )
    
    $config = Get-MenuConfiguration
    return $config.MenuItems | Where-Object { $_.Id -eq $ItemId } | Select-Object -First 1
}

# UI設定を取得
function Get-MenuUISettings {
    <#
    .SYNOPSIS
    メニューUI設定を取得

    .OUTPUTS
    PSCustomObject - UI設定

    .EXAMPLE
    $uiSettings = Get-MenuUISettings
    #>
    
    $config = Get-MenuConfiguration
    return $config.UISettings
}

# メニューアイテムを追加
function Add-MenuItemToConfig {
    <#
    .SYNOPSIS
    新しいメニューアイテムを設定に追加

    .PARAMETER Item
    追加するメニューアイテム

    .EXAMPLE
    $newItem = @{
        Id = "NEW001"
        CategoryId = "basic"
        Name = "新機能"
        Description = "新しい機能です"
        ScriptPath = "Scripts\New\NewFeature.ps1"
        Icon = "🆕"
        RequiresAdmin = $false
        Enabled = $true
        Order = 10
    }
    Add-MenuItemToConfig -Item $newItem
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Item
    )
    
    if ($null -eq $Script:MenuConfigManager) {
        Initialize-MenuConfigManager
    }
    
    try {
        # 既存アイテムとIDが重複していないかチェック
        $existingItem = Get-MenuItemById -ItemId $Item.Id
        if ($existingItem) {
            throw "ID '$($Item.Id)' は既に存在します"
        }
        
        # アイテムを追加
        $Script:MenuConfigManager.MenuConfig.MenuItems += $Item
        $Script:MenuConfigManager.MenuConfig.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        # 設定を保存
        $Script:MenuConfigManager.SaveConfig()
        
        Write-Verbose "メニューアイテム '$($Item.Id)' を追加しました"
        return $true
    } catch {
        Write-Error "メニューアイテムの追加に失敗しました: $($_.Exception.Message)"
        return $false
    }
}

# メニューアイテムを更新
function Update-MenuItemInConfig {
    <#
    .SYNOPSIS
    既存のメニューアイテムを更新

    .PARAMETER ItemId
    更新するアイテムのID

    .PARAMETER Updates
    更新する内容

    .EXAMPLE
    Update-MenuItemInConfig -ItemId "AD001" -Updates @{Enabled = $false}
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Updates
    )
    
    if ($null -eq $Script:MenuConfigManager) {
        Initialize-MenuConfigManager
    }
    
    try {
        # アイテムを検索
        $itemIndex = -1
        for ($i = 0; $i -lt $Script:MenuConfigManager.MenuConfig.MenuItems.Count; $i++) {
            if ($Script:MenuConfigManager.MenuConfig.MenuItems[$i].Id -eq $ItemId) {
                $itemIndex = $i
                break
            }
        }
        
        if ($itemIndex -eq -1) {
            throw "ID '$ItemId' のアイテムが見つかりません"
        }
        
        # アイテムを更新
        $item = $Script:MenuConfigManager.MenuConfig.MenuItems[$itemIndex]
        foreach ($key in $Updates.Keys) {
            $item.$key = $Updates[$key]
        }
        
        $Script:MenuConfigManager.MenuConfig.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        # 設定を保存
        $Script:MenuConfigManager.SaveConfig()
        
        Write-Verbose "メニューアイテム '$ItemId' を更新しました"
        return $true
    } catch {
        Write-Error "メニューアイテムの更新に失敗しました: $($_.Exception.Message)"
        return $false
    }
}

# メニュー設定の詳細情報を表示
function Show-MenuConfigurationInfo {
    <#
    .SYNOPSIS
    メニュー設定の詳細情報を表示

    .EXAMPLE
    Show-MenuConfigurationInfo
    #>
    
    $config = Get-MenuConfiguration
    
    Write-Host ""
    Write-Host "📋 メニュー設定情報" -ForegroundColor Cyan
    Write-Host "  バージョン: $($config.Version)" -ForegroundColor White
    Write-Host "  最終更新: $($config.LastModified)" -ForegroundColor White
    Write-Host "  設定ファイル: $($Script:MenuConfigManager.ConfigPath)" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "📂 カテゴリ情報" -ForegroundColor Cyan
    $categories = Get-MenuCategories -IncludeDisabled
    foreach ($category in $categories) {
        $status = if ($category.Enabled) { "✅" } else { "❌" }
        Write-Host "  $status $($category.Name) ($($category.Id))" -ForegroundColor White
        
        $items = Get-MenuItemsByCategory -CategoryId $category.Id -IncludeDisabled
        Write-Host "     アイテム数: $($items.Count)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "🎨 UI設定" -ForegroundColor Cyan
    $uiSettings = Get-MenuUISettings
    Write-Host "  メニュー幅: $($uiSettings.Layout.MenuWidth)" -ForegroundColor White
    Write-Host "  アイコン表示: $($uiSettings.Layout.ShowIcons)" -ForegroundColor White
    Write-Host "  説明表示: $($uiSettings.Layout.ShowDescriptions)" -ForegroundColor White
    Write-Host "  パンくず表示: $($uiSettings.Layout.ShowBreadcrumb)" -ForegroundColor White
}

# エクスポートする関数
Export-ModuleMember -Function @(
    'Initialize-MenuConfigManager',
    'Get-MenuConfiguration',
    'Get-MenuCategories',
    'Get-MenuItemsByCategory',
    'Get-MenuItemById',
    'Get-MenuUISettings',
    'Add-MenuItemToConfig',
    'Update-MenuItemInConfig',
    'Show-MenuConfigurationInfo'
)