# ================================================================================
# Microsoft製品運用管理ツール - Windows用メインランチャー
# Start-ManagementTools.ps1
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Setup", "Test", "Report", "Schedule", "Check", "Menu")]
    [string]$Action = "Menu",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false
)

# グローバル変数
$Script:ToolRoot = $PSScriptRoot
$Script:LogDir = Join-Path $Script:ToolRoot "Logs"
$Script:ConfigFile = Join-Path $Script:ToolRoot "Config\appsettings.json"

# ログディレクトリ作成
if (-not (Test-Path $Script:LogDir)) {
    New-Item -Path $Script:LogDir -ItemType Directory -Force | Out-Null
}

function Write-Banner {
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════╗
║                Microsoft製品運用管理ツール                          ║
║             ITSM/ISO27001/27002準拠 統合管理システム                ║
╚══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    $prefix = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        default { "ℹ" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Host "`n=== 前提条件チェック ===" -ForegroundColor Yellow
    
    $results = @{
        PowerShell = $false
        Modules = $false
        Config = $false
        Certificates = $false
        Overall = $false
    }
    
    # PowerShellバージョン確認
    if ($PSVersionTable.PSVersion -ge [Version]"5.1") {
        Write-Status "PowerShell $($PSVersionTable.PSVersion)" "Success"
        $results.PowerShell = $true
    }
    else {
        Write-Status "PowerShell バージョンが古すぎます ($($PSVersionTable.PSVersion))" "Error"
    }
    
    # 必須モジュール確認
    $requiredModules = @("Microsoft.Graph", "ExchangeOnlineManagement")
    $moduleStatus = $true
    
    foreach ($module in $requiredModules) {
        $moduleInfo = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
        if ($moduleInfo) {
            Write-Status "$module v$($moduleInfo.Version)" "Success"
        }
        else {
            Write-Status "$module が見つかりません" "Warning"
            $moduleStatus = $false
        }
    }
    $results.Modules = $moduleStatus
    
    # 設定ファイル確認
    if (Test-Path $Script:ConfigFile) {
        try {
            $config = Get-Content $Script:ConfigFile | ConvertFrom-Json
            Write-Status "設定ファイル正常" "Success"
            $results.Config = $true
        }
        catch {
            Write-Status "設定ファイル構文エラー" "Error"
        }
    }
    else {
        Write-Status "設定ファイルが見つかりません" "Error"
    }
    
    # 証明書ファイル確認
    $certPath = Join-Path $Script:ToolRoot "Certificates\mycert.pfx"
    if (Test-Path $certPath) {
        Write-Status "証明書ファイル存在" "Success"
        $results.Certificates = $true
    }
    else {
        Write-Status "証明書ファイルが見つかりません" "Error"
    }
    
    $results.Overall = $results.PowerShell -and $results.Config -and $results.Certificates
    
    return $results
}

function Invoke-Setup {
    Write-Host "`n=== 初期セットアップ ===" -ForegroundColor Yellow
    
    # モジュールインストール
    Write-Status "PowerShellモジュールをインストール中..."
    try {
        & (Join-Path $Script:ToolRoot "install-modules.ps1") -Force:$Force
        Write-Status "モジュールインストール完了" "Success"
    }
    catch {
        Write-Status "モジュールインストール失敗: $($_.Exception.Message)" "Error"
        return $false
    }
    
    # システムチェック
    Write-Status "システム整合性をチェック中..."
    try {
        & (Join-Path $Script:ToolRoot "deployment-checklist.ps1")
        Write-Status "システムチェック完了" "Success"
    }
    catch {
        Write-Status "システムチェック失敗: $($_.Exception.Message)" "Error"
        return $false
    }
    
    return $true
}

function Invoke-AuthenticationTest {
    Write-Host "`n=== 認証テスト ===" -ForegroundColor Yellow
    
    try {
        & (Join-Path $Script:ToolRoot "test-authentication-portable.ps1") -ShowDetails
        Write-Status "認証テスト完了" "Success"
        return $true
    }
    catch {
        Write-Status "認証テスト失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Invoke-ReportGeneration {
    param(
        [ValidateSet("Daily", "Weekly", "Monthly", "Yearly")]
        [string]$ReportType = "Daily"
    )
    
    Write-Host "`n=== レポート生成 ($ReportType) ===" -ForegroundColor Yellow
    
    try {
        & (Join-Path $Script:ToolRoot "test-report-generation.ps1") -ReportType $ReportType
        Write-Status "$ReportType レポート生成完了" "Success"
        
        # 生成されたレポートファイルを表示
        $reportDir = Join-Path $Script:ToolRoot "Reports\$ReportType"
        $latestReport = Get-ChildItem $reportDir -Filter "*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($latestReport) {
            Write-Status "生成されたレポート: $($latestReport.FullName)" "Info"
            
            # オプション: レポートをブラウザで開く
            $openReport = Read-Host "レポートをブラウザで開きますか？ (y/N)"
            if ($openReport -eq "y" -or $openReport -eq "Y") {
                Start-Process $latestReport.FullName
            }
        }
        
        return $true
    }
    catch {
        Write-Status "レポート生成失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Invoke-SystemCheck {
    Write-Host "`n=== システム診断 ===" -ForegroundColor Yellow
    
    # 前提条件チェック
    $prereqs = Test-Prerequisites
    
    if ($prereqs.Overall) {
        Write-Status "✓ システム正常" "Success"
    }
    else {
        Write-Status "⚠ 一部に問題があります" "Warning"
    }
    
    # コンプライアンス確認
    try {
        & (Join-Path $Script:ToolRoot "compliance-check.ps1")
        Write-Status "コンプライアンス確認完了" "Success"
    }
    catch {
        Write-Status "コンプライアンス確認失敗: $($_.Exception.Message)" "Error"
    }
    
    return $prereqs.Overall
}

function Show-MainMenu {
    Write-Banner
    
    # システム状態表示
    $prereqs = Test-Prerequisites
    
    Write-Host "`n=== Microsoft 365 統合管理システム ===" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Gray
    Write-Host "【基本機能】" -ForegroundColor Cyan
    Write-Host "1. 初期セットアップ (Setup)"
    Write-Host "2. 認証テスト (Authentication Test)"
    Write-Host "3. レポート生成 (Report Generation)"
    Write-Host "4. システム診断 (System Check)"
    Write-Host "5. スケジュール設定 (Schedule Setup)"
    Write-Host ""
    Write-Host "【管理機能】" -ForegroundColor Green
    Write-Host "6. ユーザー管理 (UM系 - User Management)"
    Write-Host "7. グループ管理 (GM系 - Group Management)"
    Write-Host "8. Exchange Online (EX系 - Exchange)"
    Write-Host "9. OneDrive/Teams/ライセンス (OD/TM/LM系)"
    Write-Host ""
    Write-Host "【その他】" -ForegroundColor Yellow
    Write-Host "0. 終了 (Exit)"
    Write-Host "=" * 60 -ForegroundColor Gray
    
    do {
        $choice = Read-Host "`n選択してください (0-9)"
        
        switch ($choice) {
            "1" {
                if (Invoke-Setup) {
                    Write-Status "セットアップが完了しました" "Success"
                }
                break
            }
            "2" {
                if (Invoke-AuthenticationTest) {
                    Write-Status "認証テストが完了しました" "Success"
                }
                break
            }
            "3" {
                Write-Host "レポートタイプを選択:"
                Write-Host "1. 日次 (Daily)"
                Write-Host "2. 週次 (Weekly)"
                Write-Host "3. 月次 (Monthly)"
                Write-Host "4. 年次 (Yearly)"
                
                $reportChoice = Read-Host "選択 (1-4)"
                $reportType = switch ($reportChoice) {
                    "1" { "Daily" }
                    "2" { "Weekly" }
                    "3" { "Monthly" }
                    "4" { "Yearly" }
                    default { "Daily" }
                }
                
                if (Invoke-ReportGeneration -ReportType $reportType) {
                    Write-Status "レポート生成が完了しました" "Success"
                }
                break
            }
            "4" {
                if (Invoke-SystemCheck) {
                    Write-Status "システム診断が完了しました" "Success"
                }
                break
            }
            "5" {
                Write-Host "`n=== スケジュール設定 ===" -ForegroundColor Yellow
                Write-Host "1. タスクスケジューラー自動設定"
                Write-Host "2. 現在のタスク確認"
                Write-Host "3. タスク削除"
                Write-Host "4. 戻る"
                
                $scheduleChoice = Read-Host "選択 (1-4)"
                switch ($scheduleChoice) {
                    "1" {
                        Write-Status "Windowsタスクスケジューラーを設定中..." "Info"
                        try {
                            & (Join-Path $Script:ToolRoot "Setup-TaskScheduler.ps1")
                            Write-Status "タスクスケジューラー設定完了" "Success"
                        }
                        catch {
                            Write-Status "タスクスケジューラー設定失敗: $($_.Exception.Message)" "Error"
                        }
                    }
                    "2" {
                        Write-Status "現在のタスクを確認中..." "Info"
                        try {
                            & (Join-Path $Script:ToolRoot "Setup-TaskScheduler.ps1") -Show
                        }
                        catch {
                            Write-Status "タスク確認失敗: $($_.Exception.Message)" "Error"
                        }
                    }
                    "3" {
                        Write-Status "タスクを削除中..." "Info"
                        try {
                            & (Join-Path $Script:ToolRoot "Setup-TaskScheduler.ps1") -Remove
                            Write-Status "タスク削除完了" "Success"
                        }
                        catch {
                            Write-Status "タスク削除失敗: $($_.Exception.Message)" "Error"
                        }
                    }
                    "4" {
                        Write-Status "メインメニューに戻ります" "Info"
                    }
                    default {
                        Write-Status "無効な選択です" "Warning"
                    }
                }
                break
            }
            "6" {
                Write-Host "`n=== ユーザー管理 (UM系) ===" -ForegroundColor Green
                Write-Host "1. ログイン履歴抽出（無操作検出）"
                Write-Host "2. MFA未設定者抽出"
                Write-Host "3. パスワード有効期限チェック"
                Write-Host "4. ライセンス未割当者確認"
                Write-Host "5. ユーザー属性変更履歴確認"
                Write-Host "6. Microsoft 365ライセンス付与の有無確認"
                Write-Host "7. 戻る"
                
                $umChoice = Read-Host "選択 (1-7)"
                
                try {
                    # 必要なモジュールを事前インポート
                    Import-Module "$Script:ToolRoot\Scripts\Common\Common.psm1" -Force
                    Import-Module "$Script:ToolRoot\Scripts\Common\Authentication.psm1" -Force
                    Import-Module "$Script:ToolRoot\Scripts\EntraID\UserManagement.psm1" -Force
                    
                    switch ($umChoice) {
                        "1" {
                            Write-Status "ログイン履歴抽出機能は実装中です" "Warning"
                        }
                        "2" {
                            Write-Status "MFA未設定者抽出を実行中..." "Info"
                            $result = Get-UsersWithoutMFA -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "MFA分析完了 ($($result.LicenseEnvironment))" "Success"
                                Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
                                Write-Host "MFA設定済み: $($result.MFAEnabledUsers)" -ForegroundColor Green
                                Write-Host "MFA未設定: $($result.MFADisabledUsers)" -ForegroundColor Red
                                Write-Host "高リスクユーザー: $($result.HighRiskUsers)" -ForegroundColor Red
                                
                                if (-not $result.SignInSupported) {
                                    Write-Host "※ サインイン履歴: E3制限により取得不可" -ForegroundColor Yellow
                                }
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "3" {
                            Write-Status "パスワード有効期限チェックを実行中..." "Info"
                            Write-Host "※ E3環境のため、Microsoft標準値（90日）で分析を実行します" -ForegroundColor Cyan
                            Write-Host "※ 組織固有のポリシー詳細は取得制限があります" -ForegroundColor Yellow
                            $result = Get-PasswordExpiryUsers -WarningDays 30 -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "パスワード有効期限分析完了 (Microsoft標準90日ルール適用)" "Success"
                                Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
                                Write-Host "期限切れ: $($result.ExpiredUsers)" -ForegroundColor Red
                                Write-Host "緊急対応: $($result.UrgentUsers)" -ForegroundColor Red
                                Write-Host "警告対象: $($result.WarningUsers)" -ForegroundColor Yellow
                                Write-Host "正常: $($result.NormalUsers)" -ForegroundColor Green
                                Write-Host "無期限設定: $($result.NeverExpiresUsers)" -ForegroundColor Gray
                                Write-Host "※ 分析基準: パスワード有効期限90日（Microsoft標準値）" -ForegroundColor Cyan
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "4" {
                            Write-Status "ライセンス未割当者確認を実行中..." "Info"
                            $result = Get-UnlicensedUsers -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "ライセンス分析完了" "Success"
                                Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
                                Write-Host "ライセンス済み: $($result.LicensedUsers)" -ForegroundColor Green
                                Write-Host "ライセンス未割当: $($result.UnlicensedUsers)" -ForegroundColor Red
                                Write-Host "アクティブ未割当: $($result.UnlicensedActiveUsers)" -ForegroundColor Red
                                Write-Host "高リスクユーザー: $($result.HighRiskUsers)" -ForegroundColor Red
                                Write-Host "使用地域未設定: $($result.NoUsageLocationUsers)" -ForegroundColor Yellow
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "5" {
                            Write-Status "ユーザー属性変更履歴確認を実行中...（E3互換性分析）" "Info"
                            Write-Host "※ E3ライセンス制限に対応した間接的分析手法を使用します" -ForegroundColor Cyan
                            Write-Host "※ 属性不一致パターンと最近の変更から潜在的な変更を検出します" -ForegroundColor Yellow
                            $result = Get-UserAttributeChanges -Days 30 -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "ユーザー属性変更履歴分析完了 ($($result.AnalysisMethod))" "Success"
                                Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
                                Write-Host "最近作成: $($result.RecentlyCreatedUsers)" -ForegroundColor Yellow
                                Write-Host "高リスクユーザー: $($result.HighRiskUsers)" -ForegroundColor Red
                                Write-Host "中リスクユーザー: $($result.MediumRiskUsers)" -ForegroundColor Yellow
                                Write-Host "属性不一致: $($result.InconsistentUsers)" -ForegroundColor Yellow
                                Write-Host "無効ユーザー: $($result.DisabledUsers)" -ForegroundColor Red
                                Write-Host "※ 分析環境: $($result.LicenseEnvironment)" -ForegroundColor Cyan
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "6" {
                            Write-Status "Microsoft 365ライセンス付与確認を実行中..." "Info"
                            Write-Host "※ E3ライセンス環境でのライセンス分析を実行します" -ForegroundColor Cyan
                            Write-Host "※ 組織ライセンス概要とコスト分析を含みます" -ForegroundColor Yellow
                            $result = Get-Microsoft365LicenseStatus -ShowDetails -ExportCSV -ExportHTML -IncludeServicePlan
                            if ($result.Success) {
                                Write-Status "Microsoft 365ライセンス分析完了 ($($result.LicenseEnvironment))" "Success"
                                Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
                                Write-Host "ライセンス済み: $($result.LicensedUsers)" -ForegroundColor Green
                                Write-Host "ライセンス未割当: $($result.UnlicensedUsers)" -ForegroundColor Red
                                Write-Host "Microsoft 365ライセンス: $($result.Microsoft365Users)" -ForegroundColor Green
                                Write-Host "部分的ライセンス: $($result.PartialLicenseUsers)" -ForegroundColor Yellow
                                Write-Host "高リスクユーザー: $($result.HighRiskUsers)" -ForegroundColor Red
                                Write-Host "使用地域未設定: $($result.NoUsageLocationUsers)" -ForegroundColor Yellow
                                Write-Host "推定月額コスト: ¥$(if($result.TotalLicenseCost -ne $null) { $result.TotalLicenseCost.ToString('N0') } else { '0' })" -ForegroundColor Blue
                                Write-Host "ユーザー単価平均: ¥$(if($result.AvgLicenseCostPerUser -ne $null) { $result.AvgLicenseCostPerUser.ToString('N0') } else { '0' })/月" -ForegroundColor Blue
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "7" {
                            Write-Status "メインメニューに戻ります" "Info"
                        }
                        default {
                            Write-Status "無効な選択です" "Warning"
                        }
                    }
                }
                catch {
                    Write-Status "ユーザー管理機能エラー: $($_.Exception.Message)" "Error"
                }
                break
            }
            "7" {
                Write-Host "`n=== グループ管理 (GM系) ===" -ForegroundColor Green
                Write-Host "1. グループ一覧・構成抽出"
                Write-Host "2. メンバー棚卸レポート出力"
                Write-Host "3. 動的グループ設定確認"
                Write-Host "4. グループ属性およびロール確認"
                Write-Host "5. 戻る"
                
                $gmChoice = Read-Host "選択 (1-5)"
                
                try {
                    # 必要なモジュールを事前インポート
                    Import-Module "$Script:ToolRoot\Scripts\Common\Common.psm1" -Force
                    Import-Module "$Script:ToolRoot\Scripts\Common\Authentication.psm1" -Force
                    Import-Module "$Script:ToolRoot\Scripts\AD\GroupManagement.psm1" -Force
                    
                    switch ($gmChoice) {
                        "1" {
                            Write-Status "グループ一覧・構成抽出を実行中..." "Info"
                            $result = Get-GroupConfiguration -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "グループ構成分析完了" "Success"
                                Write-Host "総グループ数: $($result.TotalGroups)" -ForegroundColor Cyan
                                Write-Host "セキュリティグループ: $($result.SecurityGroups)" -ForegroundColor Green
                                Write-Host "配布グループ: $($result.DistributionGroups)" -ForegroundColor Blue
                                Write-Host "Microsoft 365グループ: $($result.M365Groups)" -ForegroundColor Blue
                                Write-Host "Teamsグループ: $($result.TeamsGroups)" -ForegroundColor Magenta
                                Write-Host "オーナー不在グループ: $($result.NoOwnerGroups)" -ForegroundColor Red
                                Write-Host "高リスクグループ: $($result.HighRiskGroups)" -ForegroundColor Red
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "2" {
                            Write-Status "メンバー棚卸レポート出力を実行中..." "Info"
                            $result = Get-GroupMemberAudit -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "メンバー棚卸完了" "Success"
                                Write-Host "対象グループ数: $($result.TargetGroupCount)" -ForegroundColor Cyan
                                Write-Host "総メンバー数: $($result.TotalMembers)" -ForegroundColor Cyan
                                Write-Host "オーナー数: $($result.OwnerMembers)" -ForegroundColor Green
                                Write-Host "無効ユーザー: $($result.DisabledMembers)" -ForegroundColor Red
                                Write-Host "ネストグループ: $($result.NestedGroups)" -ForegroundColor Yellow
                                Write-Host "高リスクメンバー: $($result.HighRiskMembers)" -ForegroundColor Red
                                Write-Host "空グループ: $($result.EmptyGroups)" -ForegroundColor Yellow
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "3" {
                            Write-Status "動的グループ設定確認を実行中...（E3対応分析）" "Info"
                            Write-Host "※ E3ライセンス制限に対応した推定分析手法を使用します" -ForegroundColor Cyan
                            Write-Host "※ 完全な動的グループ管理にはAzure AD Premium P1以上が必要です" -ForegroundColor Yellow
                            $result = Get-DynamicGroupConfiguration -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "動的グループ設定確認完了 ($($result.LicenseEnvironment))" "Success"
                                Write-Host "分析対象グループ数: $($result.TotalGroups)" -ForegroundColor Cyan
                                Write-Host "確実な動的グループ: $($result.TrueDynamicGroups)" -ForegroundColor Green
                                Write-Host "処理エラーグループ: $($result.ErrorGroups)" -ForegroundColor Red
                                Write-Host "一時停止グループ: $($result.PausedGroups)" -ForegroundColor Yellow
                                Write-Host "高リスクグループ: $($result.HighRiskGroups)" -ForegroundColor Red
                                Write-Host "大規模グループ: $($result.LargeGroups)" -ForegroundColor Yellow
                                
                                if ($result.TrueDynamicGroups -eq 0) {
                                    Write-Host "※ 分析環境: $($result.LicenseEnvironment)" -ForegroundColor Cyan
                                }
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "4" {
                            Write-Status "グループ属性およびロール確認を実行中..." "Info"
                            Write-Host "※ グループの詳細属性とロール情報を包括的に分析します" -ForegroundColor Cyan
                            Write-Host "※ ライセンス・セキュリティ・有効期限などを確認します" -ForegroundColor Yellow
                            $result = Get-GroupAttributesAndRoles -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "グループ属性・ロール確認完了" "Success"
                                Write-Host "総グループ数: $($result.TotalGroups)" -ForegroundColor Cyan
                                Write-Host "セキュリティグループ: $($result.SecurityGroups)" -ForegroundColor Green
                                Write-Host "メール対応グループ: $($result.MailEnabledGroups)" -ForegroundColor Blue
                                Write-Host "Teamsグループ: $($result.TeamsGroups)" -ForegroundColor Magenta
                                Write-Host "オーナー不在グループ: $($result.NoOwnerGroups)" -ForegroundColor Red
                                Write-Host "高リスクグループ: $($result.HighRiskGroups)" -ForegroundColor Red
                                Write-Host "ライセンスエラーグループ: $($result.LicenseErrorGroups)" -ForegroundColor Red
                                Write-Host "有効期限設定グループ: $($result.ExpiringGroups)" -ForegroundColor Yellow
                                Write-Host "管理者管理グループ: $($result.AdminManagedGroups)" -ForegroundColor Green
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "5" {
                            Write-Status "メインメニューに戻ります" "Info"
                        }
                        default {
                            Write-Status "無効な選択です" "Warning"
                        }
                    }
                }
                catch {
                    Write-Status "グループ管理機能エラー: $($_.Exception.Message)" "Error"
                }
                break
            }
            "8" {
                Write-Host "`n=== Exchange Online (EX系) ===" -ForegroundColor Green
                Write-Host "1. メールボックス容量・上限監視"
                Write-Host "2. 添付ファイル送信履歴分析"
                Write-Host "3. 自動転送・返信設定の確認"
                Write-Host "4. メール配送遅延・障害監視"
                Write-Host "5. 配布グループ整合性チェック"
                Write-Host "6. 会議室リソース利用状況監査"
                Write-Host "7. スパム・フィッシング傾向分析"
                Write-Host "8. Exchangeライセンス有効性チェック"
                Write-Host "9. 戻る"
                
                $exChoice = Read-Host "選択 (1-9)"
                
                try {
                    # 必要なモジュールを事前インポート
                    Import-Module "$Script:ToolRoot\Scripts\Common\Common.psm1" -Force
                    Import-Module "$Script:ToolRoot\Scripts\Common\Authentication.psm1" -Force
                    # 新しいGraph API統合モジュールを使用
                    Import-Module "$Script:ToolRoot\Scripts\EXO\ExchangeManagement-NEW.psm1" -Force
                    
                    switch ($exChoice) {
                        "1" {
                            Write-Status "メールボックス容量・上限監視を実行中..." "Info"
                            $result = Get-MailboxQuotaMonitoring -WarningThreshold 80 -ShowDetails -ExportCSV -ExportHTML
                            if ($result.Success) {
                                Write-Status "メールボックス容量監視完了" "Success"
                                Write-Host "総メールボックス数: $($result.TotalMailboxes)" -ForegroundColor Cyan
                                Write-Host "緊急対応: $($result.UrgentMailboxes)" -ForegroundColor Red
                                Write-Host "警告対象: $($result.WarningMailboxes)" -ForegroundColor Yellow
                                Write-Host "正常: $($result.NormalMailboxes)" -ForegroundColor Green
                                Write-Host "制限なし: $($result.UnlimitedMailboxes)" -ForegroundColor Gray
                                Write-Host "平均使用率: $($result.AverageUsage)%" -ForegroundColor Cyan
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "2" {
                            Write-Status "添付ファイル送信履歴分析を実行中..." "Info"
                            # 完全新バージョンのモジュールを使用
                            Remove-Module ExchangeManagement* -Force -ErrorAction SilentlyContinue
                            Import-Module "$Script:ToolRoot\Scripts\EXO\ExchangeManagement-NEW.psm1" -Force -Global
                            Write-Host "DEBUG: ExchangeManagement-NEW.psm1 (Graph API統合版) 読み込み完了" -ForegroundColor Green
                            $result = Get-AttachmentAnalysisNEW -Days 30 -SizeThresholdMB 10 -ShowDetails -ExportCSV -ExportHTML -AllUsers
                            if ($result.Success) {
                                Write-Status "添付ファイル分析完了" "Success"
                                Write-Host "分析メッセージ数: $($result.TotalMessages)" -ForegroundColor Cyan
                                Write-Host "添付ファイル付き: $($result.AttachmentMessages)" -ForegroundColor Blue
                                Write-Host "大容量添付: $($result.LargeAttachments)" -ForegroundColor Red
                                Write-Host "送信者数: $($result.UniqueSenders)" -ForegroundColor Green
                                Write-Host "※ E3制限により制限されたデータでの分析です" -ForegroundColor Yellow
                                
                                if ($result.OutputPath) {
                                    Write-Status "CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                }
                            }
                        }
                        "3" {
                            Write-Status "🔄 自動転送・返信設定確認を実行中..." "Info"
                            Write-Host "このレポートは以下を確認します:" -ForegroundColor Cyan
                            Write-Host "  • メールボックスの自動転送設定" -ForegroundColor Gray
                            Write-Host "  • 自動応答（不在通知）設定" -ForegroundColor Gray
                            Write-Host "  • インボックスルールによる転送" -ForegroundColor Gray
                            Write-Host "  • 外部ドメインへの転送（セキュリティリスク）" -ForegroundColor Gray
                            Write-Host ""
                            
                            $result = Get-ForwardingAndAutoReplySettings -ExportCSV -ExportHTML -ShowDetails
                            if ($result.Success) {
                                Write-Status "✅ 自動転送・返信設定確認完了" "Success"
                                Write-Host "総メールボックス数: $($result.TotalMailboxes)" -ForegroundColor Cyan
                                Write-Host "転送設定あり: $($result.ForwardingCount)" -ForegroundColor Yellow
                                Write-Host "自動応答設定あり: $($result.AutoReplyCount)" -ForegroundColor Blue
                                Write-Host "外部転送あり: $($result.ExternalForwardingCount)" -ForegroundColor Red
                                Write-Host "リスク検出: $($result.RiskCount)" -ForegroundColor Red
                                
                                Write-Host ""
                                Write-Host "🔒 セキュリティ監査のポイント:" -ForegroundColor Yellow
                                Write-Host "  • 外部転送設定は情報漏洩リスクがあります" -ForegroundColor Gray
                                Write-Host "  • 長期間設定された自動応答は要確認です" -ForegroundColor Gray
                                Write-Host "  • インボックスルールによる自動転送も監視対象です" -ForegroundColor Gray
                                Write-Host "  • 定期的な設定見直しを推奨します" -ForegroundColor Gray
                                
                                if ($result.OutputPath) {
                                    Write-Status "📄 CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "🌐 HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                    
                                    # オプション: HTMLレポートをブラウザで開く
                                    $openReport = Read-Host "HTMLレポートをブラウザで開きますか？ (y/N)"
                                    if ($openReport -eq "y" -or $openReport -eq "Y") {
                                        Start-Process $result.HTMLOutputPath
                                    }
                                }
                            }
                            else {
                                Write-Status "❌ エラーが発生しました: $($result.Error)" "Error"
                            }
                        }
                        "4" {
                            Write-Status "📧 メール配送遅延・障害監視を実行中..." "Info"
                            Write-Host "このレポートは以下を監視します:" -ForegroundColor Cyan
                            Write-Host "  • メッセージ配送状況（成功/失敗/遅延）" -ForegroundColor Gray
                            Write-Host "  • 配送遅延時間の分析" -ForegroundColor Gray
                            Write-Host "  • スパム・検疫メッセージの検出" -ForegroundColor Gray
                            Write-Host "  • 配送障害アラートの生成" -ForegroundColor Gray
                            Write-Host ""
                            
                            # 分析期間とパラメータの選択
                            Write-Host "分析期間を選択してください:" -ForegroundColor Yellow
                            Write-Host "1. 過去1時間（高速）"
                            Write-Host "2. 過去6時間（推奨）"
                            Write-Host "3. 過去24時間（詳細）"
                            Write-Host "4. カスタム設定"
                            Write-Host "5. 戻る"
                            
                            $periodChoice = Read-Host "選択 (1-5)"
                            $hours = 6  # デフォルト
                            $delayThreshold = 30  # デフォルト30分
                            $maxMessages = 1000  # デフォルト
                            
                            switch ($periodChoice) {
                                "1" { 
                                    $hours = 1
                                    $maxMessages = 500
                                    Write-Host "✅ 過去1時間の高速分析を実行します" -ForegroundColor Green
                                }
                                "2" { 
                                    $hours = 6
                                    $maxMessages = 1000
                                    Write-Host "✅ 過去6時間の推奨分析を実行します" -ForegroundColor Green
                                }
                                "3" { 
                                    $hours = 24
                                    $maxMessages = 2000
                                    Write-Host "✅ 過去24時間の詳細分析を実行します" -ForegroundColor Green
                                }
                                "4" {
                                    $hours = Read-Host "分析時間数を入力してください (1-48)"
                                    $delayThreshold = Read-Host "遅延閾値（分）を入力してください (15-120)"
                                    $maxMessages = Read-Host "最大メッセージ数を入力してください (100-5000)"
                                    Write-Host "✅ カスタム設定で分析を実行します: $hours時間, 遅延閾値$delayThreshold分, 最大$maxMessages件" -ForegroundColor Green
                                }
                                "5" {
                                    Write-Status "Exchange Onlineメニューに戻ります" "Info"
                                    break
                                }
                                default { 
                                    Write-Host "✅ デフォルト設定（過去6時間）で分析を実行します" -ForegroundColor Green
                                }
                            }
                            
                            # 戻るが選択された場合は処理をスキップ
                            if ($periodChoice -eq "5") {
                                break
                            }
                            
                            Write-Host ""
                            Write-Host "⏳ 分析開始中... しばらくお待ちください" -ForegroundColor Cyan
                            
                            $result = Get-MailDeliveryMonitoring -Hours $hours -DelayThresholdMinutes $delayThreshold -MaxMessages $maxMessages -ExportCSV -ExportHTML -ShowDetails
                            if ($result.Success) {
                                if ($result.TotalMessages -eq 0) {
                                    Write-Status "✅ メール配送遅延・障害監視完了（データなし）" "Success"
                                    Write-Host ""
                                    Write-Host "📋 分析結果:" -ForegroundColor Yellow
                                    Write-Host "指定期間内にメッセージトレースデータが見つかりませんでした。" -ForegroundColor Cyan
                                    Write-Host "これは以下の理由が考えられます:" -ForegroundColor Gray
                                    Write-Host "  • 分析期間中にメール送受信がなかった" -ForegroundColor Gray
                                    Write-Host "  • Exchange Onlineのデータ保持期間外" -ForegroundColor Gray
                                    Write-Host "  • ライセンス制限によるデータアクセス制限" -ForegroundColor Gray
                                    Write-Host ""
                                    Write-Host "💡 改善提案:" -ForegroundColor Yellow
                                    Write-Host "  • より長い期間（6時間～24時間）で再試行" -ForegroundColor Gray
                                    Write-Host "  • テストメールを送信後に再分析" -ForegroundColor Gray
                                    Write-Host "  • 組織のメール利用状況を確認" -ForegroundColor Gray
                                } else {
                                    Write-Status "✅ メール配送遅延・障害監視完了" "Success"
                                }
                                Write-Host ""
                                Write-Host "📊 配送状況サマリー:" -ForegroundColor Yellow
                                Write-Host "総メッセージ数: $($result.TotalMessages)" -ForegroundColor Cyan
                                Write-Host "配送完了: $($result.DeliveredMessages)" -ForegroundColor Green
                                Write-Host "配送失敗: $($result.FailedMessages)" -ForegroundColor Red
                                Write-Host "遅延検出: $($result.DelayedMessages)" -ForegroundColor Yellow
                                Write-Host "スパム検出: $($result.SpamMessages)" -ForegroundColor Magenta
                                Write-Host "配送中: $($result.ProcessingMessages)" -ForegroundColor Blue
                                Write-Host "送信者数: $($result.UniqueSenders)" -ForegroundColor Cyan
                                Write-Host "受信者数: $($result.UniqueRecipients)" -ForegroundColor Cyan
                                
                                if ($result.AverageDelay -gt 0) {
                                    Write-Host "平均遅延時間: $($result.AverageDelay)分" -ForegroundColor Yellow
                                }
                                
                                # 重大な問題のアラート表示
                                if ($result.CriticalIssues.Count -gt 0) {
                                    Write-Host ""
                                    Write-Host "🚨 重大な問題が検出されました:" -ForegroundColor Red
                                    foreach ($issue in $result.CriticalIssues) {
                                        Write-Host "  ⚠️  $issue" -ForegroundColor Red
                                    }
                                    Write-Host "緊急対応が必要です。詳細はレポートをご確認ください。" -ForegroundColor Red
                                }
                                
                                # 配送健全性の評価
                                if ($result.TotalMessages -gt 0) {
                                    $failureRate = ($result.FailedMessages / $result.TotalMessages) * 100
                                    $delayRate = ($result.DelayedMessages / $result.TotalMessages) * 100
                                    
                                    Write-Host ""
                                    Write-Host "📈 配送健全性評価:" -ForegroundColor Yellow
                                    
                                    if ($failureRate -le 1) {
                                        Write-Host "配送成功率: 優秀 ($($failureRate.ToString('N1'))% 失敗)" -ForegroundColor Green
                                    } elseif ($failureRate -le 3) {
                                        Write-Host "配送成功率: 良好 ($($failureRate.ToString('N1'))% 失敗)" -ForegroundColor Yellow
                                    } else {
                                        Write-Host "配送成功率: 要改善 ($($failureRate.ToString('N1'))% 失敗)" -ForegroundColor Red
                                    }
                                    
                                    if ($delayRate -le 5) {
                                        Write-Host "配送速度: 優秀 ($($delayRate.ToString('N1'))% 遅延)" -ForegroundColor Green
                                    } elseif ($delayRate -le 10) {
                                        Write-Host "配送速度: 良好 ($($delayRate.ToString('N1'))% 遅延)" -ForegroundColor Yellow
                                    } else {
                                        Write-Host "配送速度: 要改善 ($($delayRate.ToString('N1'))% 遅延)" -ForegroundColor Red
                                    }
                                }
                                
                                Write-Host ""
                                Write-Host "🔍 分析詳細:" -ForegroundColor Yellow
                                Write-Host "  • 分析期間: $hours時間"
                                Write-Host "  • 遅延閾値: $delayThreshold分"
                                Write-Host "  • 最大分析件数: $maxMessages件"
                                
                                if ($result.OutputPath) {
                                    Write-Status "📄 CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "🌐 HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                    
                                    # オプション: HTMLレポートをブラウザで開く
                                    $openReport = Read-Host "HTMLレポートをブラウザで開きますか？ (y/N)"
                                    if ($openReport -eq "y" -or $openReport -eq "Y") {
                                        Start-Process $result.HTMLOutputPath
                                    }
                                }
                                
                                Write-Host ""
                                Write-Host "💡 運用のヒント:" -ForegroundColor Yellow
                                Write-Host "  • 配送失敗率が5%を超える場合はExchange Onlineサービス状況を確認"
                                Write-Host "  • 遅延率が10%を超える場合はネットワークとメールフロー設定を確認"
                                Write-Host "  • スパム率が20%を超える場合は送信者のレピュテーションを確認"
                                Write-Host "  • 定期的な監視により障害の早期発見が可能です"
                            }
                            else {
                                Write-Status "❌ エラーが発生しました: $($result.Error)" "Error"
                                Write-Host ""
                                Write-Host "💡 トラブルシューティング:" -ForegroundColor Yellow
                                Write-Host "  • Exchange Onlineへの接続状況を確認してください"
                                Write-Host "  • 分析期間を短縮して再試行してください"
                                Write-Host "  • 管理者権限とライセンス設定を確認してください"
                            }
                        }
                        "5" {
                            Write-Status "🔍 配布グループ整合性チェックを実行中..." "Info"
                            Write-Host "このレポートは以下を確認します:" -ForegroundColor Cyan
                            Write-Host "  • 配布グループのメンバー整合性（存在しないユーザー検出）" -ForegroundColor Gray
                            Write-Host "  • オーナー設定の有効性確認" -ForegroundColor Gray
                            Write-Host "  • セキュリティ設定（外部送信許可・送信制限）" -ForegroundColor Gray
                            Write-Host "  • 無効化されたユーザーの検出" -ForegroundColor Gray
                            Write-Host "  • ネストグループの存在確認" -ForegroundColor Gray
                            Write-Host ""
                            
                            $result = Get-DistributionGroupIntegrityCheck -ExportCSV -ExportHTML -ShowDetails
                            if ($result.Success) {
                                Write-Status "✅ 配布グループ整合性チェック完了" "Success"
                                Write-Host "総配布グループ数: $($result.TotalGroups)" -ForegroundColor Cyan
                                Write-Host "問題のあるグループ: $($result.GroupsWithIssues)" -ForegroundColor Red
                                Write-Host "孤立メンバー: $($result.OrphanedMembers)" -ForegroundColor Red
                                Write-Host "オーナー不在グループ: $($result.NoOwnerGroups)" -ForegroundColor Yellow
                                Write-Host "外部送信許可グループ: $($result.ExternalSendersEnabled)" -ForegroundColor Yellow
                                Write-Host "送信制限グループ: $($result.RestrictedGroups)" -ForegroundColor Blue
                                
                                Write-Host ""
                                Write-Host "🛡️ セキュリティ評価:" -ForegroundColor Yellow
                                if ($result.GroupsWithIssues -eq 0) {
                                    Write-Host "優秀: 整合性の問題は検出されませんでした" -ForegroundColor Green
                                } elseif ($result.GroupsWithIssues -le 2) {
                                    Write-Host "良好: 軽微な問題のみです" -ForegroundColor Yellow
                                } else {
                                    Write-Host "要改善: 複数の問題が検出されました" -ForegroundColor Red
                                }
                                
                                if ($result.OrphanedMembers -gt 0) {
                                    Write-Host ""
                                    Write-Host "⚠️ 緊急対応推奨:" -ForegroundColor Red
                                    Write-Host "  • $($result.OrphanedMembers)件の孤立メンバーが検出されました" -ForegroundColor Red
                                    Write-Host "  • 存在しないユーザー/グループがメンバーに含まれています" -ForegroundColor Red
                                    Write-Host "  • セキュリティリスクとなる可能性があります" -ForegroundColor Red
                                }
                                
                                if ($result.NoOwnerGroups -gt 0) {
                                    Write-Host ""
                                    Write-Host "📋 管理改善推奨:" -ForegroundColor Yellow
                                    Write-Host "  • $($result.NoOwnerGroups)個のグループにオーナーが設定されていません" -ForegroundColor Yellow
                                    Write-Host "  • 適切な管理者を設定することを推奨します" -ForegroundColor Yellow
                                }
                                
                                if ($result.OutputPath) {
                                    Write-Status "📄 CSVレポート: $($result.OutputPath)" "Info"
                                }
                                if ($result.HTMLOutputPath) {
                                    Write-Status "🌐 HTMLレポート: $($result.HTMLOutputPath)" "Info"
                                    
                                    # オプション: HTMLレポートをブラウザで開く
                                    $openReport = Read-Host "HTMLレポートをブラウザで開きますか？ (y/N)"
                                    if ($openReport -eq "y" -or $openReport -eq "Y") {
                                        Start-Process $result.HTMLOutputPath
                                    }
                                }
                                
                                Write-Host ""
                                Write-Host "💡 改善提案:" -ForegroundColor Yellow
                                Write-Host "  • 高リスクグループは緊急見直しが必要です"
                                Write-Host "  • 孤立メンバーは削除または再設定してください"
                                Write-Host "  • オーナー不在グループには管理者を設定してください"
                                Write-Host "  • 外部送信許可設定は必要性を確認してください"
                                Write-Host "  • 定期的なチェックにより継続的な整合性を維持できます"
                            }
                            else {
                                Write-Status "❌ エラーが発生しました: $($result.Error)" "Error"
                                Write-Host ""
                                Write-Host "💡 トラブルシューティング:" -ForegroundColor Yellow
                                Write-Host "  • Exchange Onlineへの接続状況を確認してください"
                                Write-Host "  • 配布グループの管理権限を確認してください"
                                Write-Host "  • ネットワーク接続を確認してください"
                            }
                        }
                        "6" {
                            Write-Status "🏢 会議室リソース利用状況監査を実行中..." "Info"
                            Write-Host "このレポートは以下を分析します:" -ForegroundColor Cyan
                            Write-Host "  • 会議室の利用状況と稼働率分析" -ForegroundColor Gray
                            Write-Host "  • 予約パターンとピーク時間分析" -ForegroundColor Gray
                            Write-Host "  • 会議室の設定とポリシー確認" -ForegroundColor Gray
                            Write-Host "  • 利用効率改善の提案" -ForegroundColor Gray
                            Write-Host ""
                            
                            # 分析期間の選択
                            Write-Host "分析期間を選択してください:" -ForegroundColor Yellow
                            Write-Host "1. 過去7日間（推奨）"
                            Write-Host "2. 過去14日間（詳細）"
                            Write-Host "3. 過去30日間（月次）"
                            Write-Host "4. 戻る"
                            
                            $periodChoice = Read-Host "選択 (1-4)"
                            $days = 7  # デフォルト
                            
                            switch ($periodChoice) {
                                "1" { 
                                    $days = 7
                                    Write-Host "✅ 過去7日間の分析を実行します" -ForegroundColor Green
                                }
                                "2" { 
                                    $days = 14
                                    Write-Host "✅ 過去14日間の詳細分析を実行します" -ForegroundColor Green
                                }
                                "3" { 
                                    $days = 30
                                    Write-Host "✅ 過去30日間の月次分析を実行します" -ForegroundColor Green
                                }
                                "4" {
                                    Write-Status "Exchange Onlineメニューに戻ります" "Info"
                                    break
                                }
                                default { 
                                    Write-Host "✅ デフォルト設定（過去7日間）で分析を実行します" -ForegroundColor Green
                                }
                            }
                            
                            # 戻るが選択された場合は処理をスキップ
                            if ($periodChoice -eq "4") {
                                break
                            }
                            
                            Write-Host ""
                            Write-Host "⏳ 会議室リソース分析開始中... しばらくお待ちください" -ForegroundColor Cyan
                            
                            # SecurityAnalysis.ps1の関数を直接実行
                            try {
                                # 新しい独立した会議室監査スクリプトを使用
                                . "$Script:ToolRoot\Scripts\EXO\RoomResourceAudit.ps1"
                                
                                $result = Get-RoomResourceUtilizationAudit -DaysBack $days -ExportCSV -ExportHTML
                                if ($result -and $result.UtilizationData) {
                                    Write-Status "✅ 会議室リソース利用状況監査完了" "Success"
                                    
                                    $summary = $result.Summary
                                    Write-Host ""
                                    Write-Host "📊 会議室利用状況サマリー:" -ForegroundColor Yellow
                                    Write-Host "総会議室数: $($summary.TotalRooms)" -ForegroundColor Cyan
                                    Write-Host "平均利用率: $($summary.AverageUtilization)%" -ForegroundColor Cyan
                                    Write-Host "高負荷会議室: $($summary.HighUtilization)" -ForegroundColor Red
                                    Write-Host "標準稼働: $($summary.NormalUtilization)" -ForegroundColor Green
                                    Write-Host "低稼働: $($summary.LowUtilization)" -ForegroundColor Yellow
                                    Write-Host "未使用: $($summary.UnusedRooms)" -ForegroundColor Gray
                                    Write-Host "予想総予約数: $($summary.TotalEstimatedBookings)" -ForegroundColor Blue
                                    
                                    # 利用効率の評価
                                    Write-Host ""
                                    Write-Host "📈 利用効率評価:" -ForegroundColor Yellow
                                    if ($summary.AverageUtilization -gt 70) {
                                        Write-Host "優秀: 会議室が効率的に利用されています" -ForegroundColor Green
                                    } elseif ($summary.AverageUtilization -gt 40) {
                                        Write-Host "良好: 適度な利用率で運用されています" -ForegroundColor Green
                                    } elseif ($summary.AverageUtilization -gt 20) {
                                        Write-Host "改善余地あり: 利用促進を検討してください" -ForegroundColor Yellow
                                    } else {
                                        Write-Host "要改善: 利用率が低く、運用の見直しが必要です" -ForegroundColor Red
                                    }
                                    
                                    if ($summary.UnusedRooms -gt 0) {
                                        Write-Host ""
                                        Write-Host "⚠️ 改善提案:" -ForegroundColor Yellow
                                        Write-Host "  • $($summary.UnusedRooms)個の未使用会議室が検出されました" -ForegroundColor Yellow
                                        Write-Host "  • 設定の見直しや利用促進策を検討してください" -ForegroundColor Yellow
                                    }
                                    
                                    if ($summary.HighUtilization -gt 0) {
                                        Write-Host ""
                                        Write-Host "📋 運用提案:" -ForegroundColor Yellow
                                        Write-Host "  • $($summary.HighUtilization)個の高負荷会議室が検出されました" -ForegroundColor Yellow
                                        Write-Host "  • 追加会議室の検討や予約ルールの調整を推奨します" -ForegroundColor Yellow
                                    }
                                    
                                    if ($result.CSVPath) {
                                        Write-Status "📄 CSVレポート: $($result.CSVPath)" "Info"
                                    }
                                    if ($result.HTMLPath) {
                                        Write-Status "🌐 HTMLレポート: $($result.HTMLPath)" "Info"
                                        
                                        # オプション: HTMLレポートをブラウザで開く
                                        $openReport = Read-Host "HTMLレポートをブラウザで開きますか？ (y/N)"
                                        if ($openReport -eq "y" -or $openReport -eq "Y") {
                                            Start-Process $result.HTMLPath
                                        }
                                    }
                                    
                                    Write-Host ""
                                    Write-Host "💡 運用のヒント:" -ForegroundColor Yellow
                                    Write-Host "  • 利用率が90%を超える会議室は予約競合が発生しやすくなります"
                                    Write-Host "  • 利用率が10%未満の会議室は設定や配置の見直しを検討してください"
                                    Write-Host "  • ピーク時間帯の分析により効率的な会議室運用が可能です"
                                    Write-Host "  • 定期的な利用状況監査により最適な会議室環境を維持できます"
                                }
                                else {
                                    Write-Status "⚠️ 会議室データが取得できませんでした" "Warning"
                                    Write-Host ""
                                    Write-Host "考えられる原因:" -ForegroundColor Yellow
                                    Write-Host "  • 組織に会議室メールボックスが登録されていない" -ForegroundColor Gray
                                    Write-Host "  • Exchange Onlineへの接続に問題がある" -ForegroundColor Gray
                                    Write-Host "  • 会議室管理の権限が不足している" -ForegroundColor Gray
                                }
                            }
                            catch {
                                Write-Status "❌ エラーが発生しました: $($_.Exception.Message)" "Error"
                                Write-Host ""
                                Write-Host "💡 トラブルシューティング:" -ForegroundColor Yellow
                                Write-Host "  • Exchange Onlineへの接続状況を確認してください"
                                Write-Host "  • 会議室管理の権限を確認してください"
                                Write-Host "  • ネットワーク接続を確認してください"
                            }
                        }
                        "7" {
                            Write-Status "🛡️ スパム・フィッシング傾向分析を実行中..." "Info"
                            Write-Host "この分析では以下を実行します:" -ForegroundColor Cyan
                            Write-Host "  • 過去の脅威メッセージトレース分析" -ForegroundColor Gray
                            Write-Host "  • スパム・フィッシング・マルウェアの分類" -ForegroundColor Gray
                            Write-Host "  • 疑わしい送信者のリスク評価" -ForegroundColor Gray
                            Write-Host "  • 脅威傾向とパターンの可視化" -ForegroundColor Gray
                            Write-Host "  • セキュリティ推奨事項の生成" -ForegroundColor Gray
                            Write-Host ""
                            
                            # 分析期間の選択
                            Write-Host "分析期間を選択してください:" -ForegroundColor Yellow
                            Write-Host "1. 過去7日間（標準）"
                            Write-Host "2. 過去14日間（詳細） ※Exchange制限により10日間に調整されます"
                            Write-Host "3. 過去30日間（月次） ※Exchange制限により10日間に調整されます"
                            Write-Host "4. 戻る"
                            Write-Host ""
                            Write-Host "⚠️ 注意: Exchange Onlineのメッセージトレースは過去10日以内のデータのみ取得可能です" -ForegroundColor Yellow
                            
                            $periodChoice = Read-Host "選択 (1-4)"
                            $days = 7  # デフォルト
                            
                            switch ($periodChoice) {
                                "1" { 
                                    $days = 7
                                    Write-Host "✅ 過去7日間の脅威分析を実行します" -ForegroundColor Green
                                }
                                "2" { 
                                    $days = 14
                                    Write-Host "✅ 過去14日間の詳細脅威分析を実行します" -ForegroundColor Green
                                }
                                "3" { 
                                    $days = 30
                                    Write-Host "✅ 過去30日間の月次脅威分析を実行します" -ForegroundColor Green
                                }
                                "4" {
                                    Write-Status "Exchange Onlineメニューに戻ります" "Info"
                                    break
                                }
                                default { 
                                    Write-Host "✅ デフォルト設定（過去7日間）で分析を実行します" -ForegroundColor Green
                                }
                            }
                            
                            # 戻るが選択された場合は処理をスキップ
                            if ($periodChoice -eq "4") {
                                break
                            }
                            
                            Write-Host ""
                            Write-Host "🛡️ スパム・フィッシング傾向分析開始中... しばらくお待ちください" -ForegroundColor Cyan
                            Write-Host "⚠️  大量のメッセージトレースを分析するため時間がかかる場合があります" -ForegroundColor Yellow
                            
                            try {
                                # SpamPhishingAnalysis.ps1を読み込み
                                . "$Script:ToolRoot\Scripts\EXO\SpamPhishingAnalysis.ps1"
                                
                                $result = Get-SpamPhishingTrendAnalysis -DaysBack $days -ExportCSV -ExportHTML
                                if ($result -and $result.Summary) {
                                    Write-Status "✅ スパム・フィッシング傾向分析完了" "Success"
                                    
                                    $summary = $result.Summary
                                    Write-Host ""
                                    Write-Host "🛡️ セキュリティ脅威分析サマリー:" -ForegroundColor Yellow
                                    Write-Host "総脅威数: $($summary.TotalThreats)" -ForegroundColor Cyan
                                    Write-Host "スパムメール: $($summary.SpamCount)" -ForegroundColor Yellow
                                    Write-Host "フィッシング攻撃: $($summary.PhishingCount)" -ForegroundColor Red
                                    Write-Host "マルウェア検出: $($summary.MalwareCount)" -ForegroundColor Red
                                    Write-Host "疑わしい送信者: $($summary.UniqueSenders)" -ForegroundColor Magenta
                                    Write-Host "標的ユーザー: $($summary.TargetedUsers)" -ForegroundColor Blue
                                    Write-Host "脅威傾向: $($summary.SecurityTrend)" -ForegroundColor $(
                                        switch ($summary.SecurityTrend) {
                                            "増加傾向" { "Red" }
                                            "減少傾向" { "Green" }
                                            default { "Cyan" }
                                        }
                                    )
                                    
                                    # リスクレベル評価
                                    Write-Host ""
                                    switch ($summary.RiskLevel) {
                                        "高" {
                                            Write-Host "⚠️ 【高リスク警告】" -ForegroundColor Red
                                            Write-Host "大量の脅威が検出されています。緊急の対策が必要です。" -ForegroundColor Red
                                        }
                                        "中" {
                                            Write-Host "⚠️ 【注意】" -ForegroundColor Yellow
                                            Write-Host "通常より多くの脅威が検出されています。監視を強化してください。" -ForegroundColor Yellow
                                        }
                                        "低" {
                                            Write-Host "✅ 【良好】" -ForegroundColor Green
                                            Write-Host "脅威レベルは正常範囲内です。継続的な監視を維持してください。" -ForegroundColor Green
                                        }
                                    }
                                    
                                    # レポートファイル情報
                                    Write-Host ""
                                    Write-Host "📊 生成されたレポート:" -ForegroundColor Cyan
                                    if ($result.CSVPath) {
                                        Write-Host "  • CSVレポート: $($result.CSVPath)" -ForegroundColor Gray
                                    }
                                    if ($result.HTMLPath) {
                                        Write-Host "  • HTMLダッシュボード: $($result.HTMLPath)" -ForegroundColor Gray
                                        
                                        # HTMLレポートを開くかユーザーに確認
                                        Write-Host ""
                                        $openHtml = Read-Host "HTMLダッシュボードをブラウザで開きますか？ (y/N)"
                                        if ($openHtml -eq "y" -or $openHtml -eq "Y") {
                                            try {
                                                Start-Process $result.HTMLPath
                                                Write-Host "✅ ブラウザでHTMLダッシュボードを開きました" -ForegroundColor Green
                                            }
                                            catch {
                                                Write-Host "❌ ブラウザでの表示に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
                                            }
                                        }
                                    }
                                    
                                    # セキュリティ推奨事項
                                    if ($summary.PhishingCount -gt 0 -or $summary.MalwareCount -gt 0) {
                                        Write-Host ""
                                        Write-Host "💡 セキュリティ推奨事項:" -ForegroundColor Yellow
                                        if ($summary.PhishingCount -gt 0) {
                                            Write-Host "  • フィッシング対策: ユーザーセキュリティ研修を実施" -ForegroundColor Gray
                                        }
                                        if ($summary.MalwareCount -gt 0) {
                                            Write-Host "  • マルウェア対策: 添付ファイルスキャンを強化" -ForegroundColor Gray
                                        }
                                        if ($summary.HighRiskSenders -gt 0) {
                                            Write-Host "  • 送信者対策: 高リスク送信者をブロックリストに追加" -ForegroundColor Gray
                                        }
                                        Write-Host "  • 定期監視: このレポートを週次で確認し傾向を監視" -ForegroundColor Gray
                                    }
                                } else {
                                    Write-Status "⚠️ 脅威分析データが取得できませんでした" "Warning"
                                    Write-Host ""
                                    Write-Host "考えられる原因:" -ForegroundColor Yellow
                                    Write-Host "  • 分析期間内に脅威メッセージが存在しない" -ForegroundColor Gray
                                    Write-Host "  • Exchange Onlineメッセージトレースの権限不足" -ForegroundColor Gray
                                    Write-Host "  • ネットワーク接続の問題" -ForegroundColor Gray
                                }
                            }
                            catch {
                                Write-Status "❌ エラーが発生しました: $($_.Exception.Message)" "Error"
                                Write-Host ""
                                Write-Host "💡 トラブルシューティング:" -ForegroundColor Yellow
                                Write-Host "  • Exchange Onlineへの接続状況を確認してください" -ForegroundColor Gray
                                Write-Host "  • メッセージトレースの管理権限を確認してください" -ForegroundColor Gray
                                Write-Host "  • ネットワーク接続を確認してください" -ForegroundColor Gray
                                Write-Host "  • 分析期間を短くして再試行してください" -ForegroundColor Gray
                            }
                        }
                        "8" {
                            Write-Status "📋 Exchange Onlineライセンス有効性チェックを実行中..." "Info"
                            Write-Host "このレポートは以下を分析します:" -ForegroundColor Cyan
                            Write-Host "  • Exchange Onlineライセンス割り当て状況" -ForegroundColor Gray
                            Write-Host "  • メールボックス機能の有効性確認" -ForegroundColor Gray
                            Write-Host "  • ライセンス利用率とコスト分析" -ForegroundColor Gray
                            Write-Host "  • 未使用ライセンスの検出" -ForegroundColor Gray
                            Write-Host "  • リスク評価とコスト最適化提案" -ForegroundColor Gray
                            Write-Host ""
                            
                            try {
                                # ライセンス有効性チェックスクリプトを読み込み
                                . "$Script:ToolRoot\Scripts\EXO\ExchangeLicenseValidityCheck.ps1"
                                
                                $result = Get-ExchangeLicenseValidityCheck -ExportCSV -ExportHTML -ShowDetails
                                if ($result -and $result.Success) {
                                    Write-Status "✅ Exchange Onlineライセンス有効性チェック完了" "Success"
                                    
                                    Write-Host ""
                                    Write-Host "📊 ライセンス分析サマリー:" -ForegroundColor Yellow
                                    Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
                                    Write-Host "ライセンス付与: $($result.LicensedUsers)" -ForegroundColor Green
                                    Write-Host "ライセンス未割当: $($result.UnlicensedUsers)" -ForegroundColor Red
                                    Write-Host "メールボックス有効: $($result.Summary.MailboxEnabledUsers)" -ForegroundColor Blue
                                    Write-Host "高リスクユーザー: $($result.HighRiskUsers)" -ForegroundColor Red
                                    Write-Host "月額ライセンスコスト: ¥$(if($result.TotalMonthlyCost -ne $null) { $result.TotalMonthlyCost.ToString('N0') } else { '0' })" -ForegroundColor Blue
                                    Write-Host "ユーザー単価平均: ¥$(if($result.AverageCostPerUser -ne $null) { $result.AverageCostPerUser.ToString('N0') } else { '0' })/月" -ForegroundColor Blue
                                    Write-Host "ライセンス利用率: $($result.LicenseUtilizationRate)%" -ForegroundColor Cyan
                                    
                                    # ライセンス種別内訳
                                    Write-Host ""
                                    Write-Host "🏷️ ライセンス種別内訳:" -ForegroundColor Yellow
                                    Write-Host "Microsoft 365 E5: $($result.Summary.E5Licenses)ライセンス" -ForegroundColor Magenta
                                    Write-Host "Microsoft 365 E3: $($result.Summary.E3Licenses)ライセンス" -ForegroundColor Blue
                                    Write-Host "Exchange 基本: $($result.Summary.BasicLicenses)ライセンス" -ForegroundColor Green
                                    Write-Host "アーカイブ有効: $($result.Summary.ArchiveEnabledUsers)ユーザー" -ForegroundColor Gray
                                    Write-Host "リーガルホールド: $($result.Summary.LitigationHoldUsers)ユーザー" -ForegroundColor Gray
                                    
                                    # コスト最適化の提案
                                    if ($result.Summary.UnusedLicenses -gt 0) {
                                        Write-Host ""
                                        Write-Host "💡 コスト最適化提案:" -ForegroundColor Yellow
                                        $potentialSavings = $result.Summary.UnusedLicenses * $result.AverageCostPerUser
                                        Write-Host "  • 未使用ライセンス: $($result.Summary.UnusedLicenses)個" -ForegroundColor Red
                                        Write-Host "  • 削減可能コスト: ¥$(if($potentialSavings -ne $null) { $potentialSavings.ToString('N0') } else { '0' })/月" -ForegroundColor Red
                                        Write-Host "  • 最終サインインが不明なユーザーの見直しを推奨します" -ForegroundColor Yellow
                                    }
                                    
                                    # 高リスクユーザーの警告
                                    if ($result.HighRiskUsers -gt 0) {
                                        Write-Host ""
                                        Write-Host "⚠️ 緊急対応推奨:" -ForegroundColor Red
                                        Write-Host "  • $($result.HighRiskUsers)名の高リスクユーザーが検出されました" -ForegroundColor Red
                                        Write-Host "  • ライセンスとメールボックスの不整合があります" -ForegroundColor Red
                                        Write-Host "  • 詳細はレポートを確認して緊急対応してください" -ForegroundColor Red
                                    }
                                    
                                    # 利用率評価
                                    Write-Host ""
                                    Write-Host "📈 ライセンス利用効率評価:" -ForegroundColor Yellow
                                    if ($result.LicenseUtilizationRate -gt 90) {
                                        Write-Host "優秀: ライセンスが効率的に活用されています" -ForegroundColor Green
                                    } elseif ($result.LicenseUtilizationRate -gt 70) {
                                        Write-Host "良好: 適度な利用率で運用されています" -ForegroundColor Green
                                    } elseif ($result.LicenseUtilizationRate -gt 50) {
                                        Write-Host "改善余地あり: 未活用ライセンスの見直しを検討" -ForegroundColor Yellow
                                    } else {
                                        Write-Host "要改善: ライセンス利用率が低く、コスト最適化が必要" -ForegroundColor Red
                                    }
                                    
                                    if ($result.CSVPath) {
                                        Write-Status "📄 CSVレポート: $($result.CSVPath)" "Info"
                                    }
                                    if ($result.HTMLPath) {
                                        Write-Status "🌐 HTMLダッシュボード: $($result.HTMLPath)" "Info"
                                        
                                        # オプション: HTMLレポートをブラウザで開く
                                        $openReport = Read-Host "HTMLダッシュボードをブラウザで開きますか？ (y/N)"
                                        if ($openReport -eq "y" -or $openReport -eq "Y") {
                                            Start-Process $result.HTMLPath
                                        }
                                    }
                                    
                                    Write-Host ""
                                    Write-Host "💡 管理のヒント:" -ForegroundColor Yellow
                                    Write-Host "  • 月次でライセンス有効性をチェックしてコスト最適化" -ForegroundColor Gray
                                    Write-Host "  • 新規ユーザーには適切なライセンスプランを選択" -ForegroundColor Gray
                                    Write-Host "  • 退職者のライセンス回収を忘れずに実行" -ForegroundColor Gray
                                    Write-Host "  • 未使用ライセンスは定期的に見直してコスト削減" -ForegroundColor Gray
                                    Write-Host "  • 高額ライセンス（E5等）の利用状況を重点監視" -ForegroundColor Gray
                                } else {
                                    Write-Status "⚠️ ライセンス有効性データが取得できませんでした" "Warning"
                                    Write-Host ""
                                    Write-Host "考えられる原因:" -ForegroundColor Yellow
                                    Write-Host "  • Microsoft Graphへの接続に問題がある" -ForegroundColor Gray
                                    Write-Host "  • Exchange Onlineへの接続に問題がある" -ForegroundColor Gray
                                    Write-Host "  • ライセンス管理の権限が不足している" -ForegroundColor Gray
                                    
                                    if ($result -and $result.Error) {
                                        Write-Host "  • エラー詳細: $($result.Error)" -ForegroundColor Gray
                                    }
                                }
                            }
                            catch {
                                Write-Status "❌ エラーが発生しました: $($_.Exception.Message)" "Error"
                                Write-Host ""
                                Write-Host "🔍 詳細エラー情報:" -ForegroundColor Red
                                Write-Host "  • エラー種類: $($_.Exception.GetType().Name)" -ForegroundColor Gray
                                Write-Host "  • 発生場所: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
                                Write-Host "  • エラー行: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Gray
                                Write-Host ""
                                Write-Host "💡 トラブルシューティング:" -ForegroundColor Yellow
                                Write-Host "  • Microsoft GraphとExchange Onlineへの接続状況を確認してください" -ForegroundColor Gray
                                Write-Host "  • ライセンス管理の権限を確認してください" -ForegroundColor Gray
                                Write-Host "  • ネットワーク接続を確認してください" -ForegroundColor Gray
                            }
                        }
                        "9" {
                            Write-Status "メインメニューに戻ります" "Info"
                        }
                        default {
                            Write-Status "無効な選択です" "Warning"
                        }
                    }
                }
                catch {
                    Write-Status "Exchange Online機能エラー: $($_.Exception.Message)" "Error"
                }
                break
            }
            "9" {
                Write-Host "`n=== OneDrive/Teams/ライセンス (OD/TM/LM系) ===" -ForegroundColor Green
                Write-Host "1. OneDrive使用容量／残容量の分析"
                Write-Host "2. Teams構成確認（チーム一覧、録画設定、オーナー不在）"
                Write-Host "3. OneDrive外部共有状況確認"
                Write-Host "4. ライセンス配布状況・未使用ライセンス監視"
                Write-Host "5. 利用率／アクティブ率レポート"
                Write-Host "6. 年間消費傾向のアラート出力"
                Write-Host "7. 戻る"
                
                $odChoice = Read-Host "選択 (1-7)"
                
                try {
                    # 必要なモジュールを事前インポート
                    Import-Module "$Script:ToolRoot\Scripts\Common\Common.psm1" -Force
                    Import-Module "$Script:ToolRoot\Scripts\Common\Authentication.psm1" -Force
                    
                    switch ($odChoice) {
                        "1" {
                            Write-Status "📊 OneDrive使用容量分析を実行中..." "Info"
                            Write-Host "この分析は以下を監視します:" -ForegroundColor Cyan
                            Write-Host "  • ユーザー別OneDriveストレージ使用量" -ForegroundColor Gray
                            Write-Host "  • 容量警告・緊急アラートの検出" -ForegroundColor Gray
                            Write-Host "  • ストレージ効率と最適化提案" -ForegroundColor Gray
                            Write-Host "  • ライセンス使用率の分析" -ForegroundColor Gray
                            Write-Host ""
                            
                            # スクリプトファイル読み込み
                            $oneDriveScriptPath = Join-Path $Script:ToolRoot "Scripts\EntraID\OneDriveUsageAnalysis.ps1"
                            if (Test-Path $oneDriveScriptPath) {
                                . $oneDriveScriptPath
                                
                                Write-Host "⏳ OneDrive使用容量分析を開始中... しばらくお待ちください" -ForegroundColor Cyan
                                
                                $result = Get-OneDriveUsageAnalysis -ExportCSV -ExportHTML -ShowDetails
                                if ($result -and $result.Success) {
                                    Write-Status "✅ OneDrive使用容量分析完了" "Success"
                                    Write-Host ""
                                    Write-Host "📊 OneDrive使用状況サマリー:" -ForegroundColor Yellow
                                    Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
                                    Write-Host "OneDrive有効: $($result.OneDriveEnabledUsers)" -ForegroundColor Green
                                    Write-Host "容量警告: $($result.WarningUsers)" -ForegroundColor Yellow
                                    Write-Host "容量緊急: $($result.CriticalUsers)" -ForegroundColor Red
                                    Write-Host "使用済容量: $(if($result.TotalUsedStorageGB -ne $null) { $result.TotalUsedStorageGB.ToString('N1') } else { '0.0' }) GB" -ForegroundColor Blue
                                    Write-Host "平均使用率: $(if($result.AverageUsagePercent -ne $null) { $result.AverageUsagePercent.ToString('N1') } else { '0.0' })%" -ForegroundColor Cyan
                                    Write-Host "ストレージ効率: $(if($result.StorageEfficiency -ne $null) { $result.StorageEfficiency.ToString('N1') } else { '0.0' })%" -ForegroundColor Cyan
                                    
                                    if ($result.CSVPath) {
                                        Write-Status "📄 CSVレポート: $($result.CSVPath)" "Info"
                                    }
                                    if ($result.HTMLPath) {
                                        Write-Status "🌐 HTMLレポート: $($result.HTMLPath)" "Info"
                                        
                                        # オプション: HTMLレポートをブラウザで開く
                                        $openReport = Read-Host "HTMLレポートをブラウザで開きますか？ (y/N)"
                                        if ($openReport -eq "y" -or $openReport -eq "Y") {
                                            Start-Process $result.HTMLPath
                                        }
                                    }
                                }
                                else {
                                    Write-Status "❌ エラーが発生しました: $($result.Error)" "Error"
                                }
                            } else {
                                Write-Status "❌ OneDriveUsageAnalysis.ps1が見つかりません: $oneDriveScriptPath" "Error"
                            }
                        }
                        "2" {
                            Write-Status "📋 Microsoft Teams構成確認・分析を実行中..." "Info"
                            Write-Host "この分析は以下を監視します:" -ForegroundColor Cyan
                            Write-Host "  • チーム一覧とメンバー構成の詳細分析" -ForegroundColor Gray
                            Write-Host "  • オーナー不在チームの緊急検出" -ForegroundColor Gray
                            Write-Host "  • 録画設定とポリシーのコンプライアンス確認" -ForegroundColor Gray
                            Write-Host "  • Teamsガバナンススコアの算出" -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "⚠️ 注意: Microsoft TeamsのAPI制限により、サンプルデータを使用した分析を実行します" -ForegroundColor Yellow
                            Write-Host ""
                            
                            # スクリプトファイル読み込み
                            $teamsScriptPath = Join-Path $Script:ToolRoot "Scripts\EntraID\TeamsConfigurationAnalysis.ps1"
                            if (Test-Path $teamsScriptPath) {
                                . $teamsScriptPath
                                
                                Write-Host "⏳ Teams構成確認・分析を開始中... しばらくお待ちください" -ForegroundColor Cyan
                                
                                $result = Get-TeamsConfigurationAnalysis -ExportCSV -ExportHTML -ShowDetails -IncludeRecordingSettings -DetectOrphanedTeams
                                if ($result -and $result.Success) {
                                    Write-Status "✅ Microsoft Teams構成確認・分析完了" "Success"
                                    Write-Host ""
                                    Write-Host "📊 Teams構成サマリー:" -ForegroundColor Yellow
                                    Write-Host "総チーム数: $($result.TotalTeams)" -ForegroundColor Cyan
                                    Write-Host "アクティブチーム: $($result.ActiveTeams)" -ForegroundColor Green
                                    Write-Host "オーナー不在: $($result.OrphanedTeams)" -ForegroundColor $(if($result.OrphanedTeams -gt 0) { "Red" } else { "Green" })
                                    Write-Host "要対応チーム: $(if($result.CriticalTeams -ne $null -and $result.WarningTeams -ne $null) { $result.CriticalTeams + $result.WarningTeams } else { 0 })" -ForegroundColor Yellow
                                    Write-Host "ガバナンススコア: $(if($result.GovernanceScore -ne $null) { $result.GovernanceScore.ToString('N1') } else { '0.0' })%" -ForegroundColor Cyan
                                    
                                    # 重要な警告表示
                                    if ($result.OrphanedTeams -gt 0) {
                                        Write-Host ""
                                        Write-Host "🚨 緊急対応が必要:" -ForegroundColor Red
                                        Write-Host "   $($result.OrphanedTeams)個のチームにオーナーが存在しません" -ForegroundColor Red
                                        Write-Host "   業務継続に支障をきたす可能性があります" -ForegroundColor Red
                                    }
                                    
                                    if ($result.CSVPath) {
                                        Write-Status "📄 CSVレポート: $($result.CSVPath)" "Info"
                                    }
                                    if ($result.HTMLPath) {
                                        Write-Status "🌐 HTMLレポート: $($result.HTMLPath)" "Info"
                                        
                                        # オプション: HTMLレポートをブラウザで開く
                                        $openReport = Read-Host "HTMLレポートをブラウザで開きますか？ (y/N)"
                                        if ($openReport -eq "y" -or $openReport -eq "Y") {
                                            Start-Process $result.HTMLPath
                                        }
                                    }
                                }
                                else {
                                    Write-Status "❌ エラーが発生しました: $($result.Error)" "Error"
                                }
                            } else {
                                Write-Status "❌ TeamsConfigurationAnalysis.ps1が見つかりません: $teamsScriptPath" "Error"
                            }
                        }
                        "3" {
                            Write-Status "🔒 OneDrive外部共有状況確認を実行中..." "Info"
                            Write-Host "この分析は以下のセキュリティ監査を実行します:" -ForegroundColor Cyan
                            Write-Host "  • 外部共有ファイル/フォルダの検出" -ForegroundColor Gray
                            Write-Host "  • 匿名リンクと権限設定の確認" -ForegroundColor Gray
                            Write-Host "  • 機密ファイルの外部共有リスク評価" -ForegroundColor Gray
                            Write-Host "  • セキュリティ対策の推奨事項" -ForegroundColor Gray
                            Write-Host ""
                            
                            # スクリプトファイル読み込み
                            $externalSharingScriptPath = Join-Path $Script:ToolRoot "Scripts\EntraID\OneDriveExternalSharingAnalysis.ps1"
                            if (Test-Path $externalSharingScriptPath) {
                                . $externalSharingScriptPath
                                
                                Write-Host "⏳ OneDrive外部共有状況確認を開始中... しばらくお待ちください" -ForegroundColor Cyan
                                Write-Host "※ セキュリティ分析のため処理に時間がかかる場合があります" -ForegroundColor Yellow
                                
                                $result = Get-OneDriveExternalSharingAnalysis -IncludeFileDetails -ExportCSV -ExportHTML
                                if ($result -and $result.Success) {
                                    Write-Status "✅ OneDrive外部共有状況確認完了" "Success"
                                    Write-Host ""
                                    Write-Host "🔒 外部共有セキュリティサマリー:" -ForegroundColor Yellow
                                    Write-Host "分析対象ユーザー: $($result.Statistics.TotalUsers)" -ForegroundColor Cyan
                                    Write-Host "外部共有あり: $($result.Statistics.UsersWithExternalSharing)" -ForegroundColor $(if($result.Statistics.UsersWithExternalSharing -gt 0) { "Yellow" } else { "Green" })
                                    Write-Host "高リスクユーザー: $($result.Statistics.HighRiskUsers)" -ForegroundColor $(if($result.Statistics.HighRiskUsers -gt 0) { "Red" } else { "Green" })
                                    Write-Host "緊急対応必要: $($result.Statistics.CriticalRiskUsers)" -ForegroundColor $(if($result.Statistics.CriticalRiskUsers -gt 0) { "Red" } else { "Green" })
                                    Write-Host "外部共有総数: $($result.Statistics.TotalExternalShares)" -ForegroundColor $(if($result.Statistics.TotalExternalShares -gt 10) { "Yellow" } else { "Green" })
                                    Write-Host "匿名リンク: $($result.Statistics.TotalAnonymousLinks)" -ForegroundColor $(if($result.Statistics.TotalAnonymousLinks -gt 0) { "Red" } else { "Green" })
                                    
                                    # 重要な警告表示
                                    if ($result.Statistics.CriticalRiskUsers -gt 0) {
                                        Write-Host ""
                                        Write-Host "🚨 緊急対応が必要:" -ForegroundColor Red
                                        Write-Host "   $($result.Statistics.CriticalRiskUsers)名のユーザーで機密ファイルの危険な外部共有が検出されました" -ForegroundColor Red
                                        Write-Host "   セキュリティインシデントの可能性があります" -ForegroundColor Red
                                    }
                                    elseif ($result.Statistics.HighRiskUsers -gt 0) {
                                        Write-Host ""
                                        Write-Host "⚠️ 注意が必要:" -ForegroundColor Yellow
                                        Write-Host "   $($result.Statistics.HighRiskUsers)名のユーザーで高リスクな外部共有が検出されました" -ForegroundColor Yellow
                                        Write-Host "   セキュリティ確認と対策を実施してください" -ForegroundColor Yellow
                                    }
                                    elseif ($result.Statistics.TotalAnonymousLinks -gt 0) {
                                        Write-Host ""
                                        Write-Host "⚠️ 匿名リンク検出:" -ForegroundColor Yellow
                                        Write-Host "   $($result.Statistics.TotalAnonymousLinks)個の匿名アクセスリンクが検出されました" -ForegroundColor Yellow
                                        Write-Host "   セキュリティポリシーの確認を推奨します" -ForegroundColor Yellow
                                    }
                                    else {
                                        Write-Host ""
                                        Write-Host "✅ セキュリティ状況良好:" -ForegroundColor Green
                                        Write-Host "   危険な外部共有は検出されませんでした" -ForegroundColor Green
                                    }
                                    
                                    if ($result.CSVPath) {
                                        Write-Status "📄 CSVレポート: $($result.CSVPath)" "Info"
                                    }
                                    if ($result.HTMLPath) {
                                        Write-Status "🌐 HTMLセキュリティダッシュボード: $($result.HTMLPath)" "Info"
                                        
                                        # オプション: HTMLレポートをブラウザで開く
                                        $openReport = Read-Host "セキュリティダッシュボードをブラウザで開きますか？ (y/N)"
                                        if ($openReport -eq "y" -or $openReport -eq "Y") {
                                            Start-Process $result.HTMLPath
                                        }
                                    }
                                }
                                else {
                                    Write-Status "❌ エラーが発生しました: $($result.Error)" "Error"
                                }
                            } else {
                                Write-Status "❌ OneDriveExternalSharingAnalysis.ps1が見つかりません: $externalSharingScriptPath" "Error"
                            }
                        }
                        "4" {
                            Write-Status "💰 Microsoft 365ライセンス配布状況・未使用ライセンス監視を実行中..." "Info"
                            Write-Host "この分析は以下を監視します:" -ForegroundColor Cyan
                            Write-Host "  • ライセンス種別と使用状況の詳細分析" -ForegroundColor Gray
                            Write-Host "  • 未使用ライセンスの検出とコスト分析" -ForegroundColor Gray
                            Write-Host "  • ユーザー別ライセンス利用状況" -ForegroundColor Gray
                            Write-Host "  • コスト最適化提案と年間節約可能額" -ForegroundColor Gray
                            Write-Host "  • 長期未利用ユーザーの検出" -ForegroundColor Gray
                            Write-Host ""
                            
                            # スクリプトファイル読み込み
                            $licenseScriptPath = Join-Path $Script:ToolRoot "Scripts\EntraID\LicenseAnalysis.ps1"
                            if (Test-Path $licenseScriptPath) {
                                . $licenseScriptPath
                                
                                Write-Host "⏳ ライセンス分析を開始中... しばらくお待ちください" -ForegroundColor Cyan
                                
                                $result = Get-LicenseAnalysis -IncludeUserDetails -AnalyzeCosts -ExportCSV -ExportHTML
                                if ($result -and $result.Success) {
                                    Write-Status "✅ Microsoft 365ライセンス分析完了" "Success"
                                    Write-Host ""
                                    Write-Host "📊 ライセンス使用状況サマリー:" -ForegroundColor Yellow
                                    Write-Host "ライセンス種別数: $($result.Statistics.TotalLicenseTypes)" -ForegroundColor Cyan
                                    Write-Host "総ライセンス数: $($result.Statistics.TotalLicenses)" -ForegroundColor Cyan
                                    Write-Host "使用中ライセンス: $($result.Statistics.TotalConsumedLicenses)" -ForegroundColor Green
                                    Write-Host "未使用ライセンス: $($result.Statistics.TotalAvailableLicenses)" -ForegroundColor $(if($result.Statistics.TotalAvailableLicenses -gt 10) { "Yellow" } else { "Green" })
                                    Write-Host "平均利用率: $(if($result.Statistics.AverageUtilizationRate -ne $null) { $result.Statistics.AverageUtilizationRate.ToString('N1') } else { '0.0' })%" -ForegroundColor Cyan
                                    Write-Host ""
                                    Write-Host "💰 コスト分析:" -ForegroundColor Yellow
                                    Write-Host "月額総コスト: ¥$(if($result.Statistics.TotalMonthlyCost -ne $null) { $result.Statistics.TotalMonthlyCost.ToString('N0') } else { '0' })" -ForegroundColor Blue
                                    Write-Host "月額無駄コスト: ¥$(if($result.Statistics.TotalWastedCost -ne $null) { $result.Statistics.TotalWastedCost.ToString('N0') } else { '0' })" -ForegroundColor $(if($result.Statistics.TotalWastedCost -gt 10000) { "Red" } else { "Yellow" })
                                    Write-Host "年間節約可能額: ¥$(if($result.Statistics.TotalAnnualSavingsPotential -ne $null) { $result.Statistics.TotalAnnualSavingsPotential.ToString('N0') } else { '0' })" -ForegroundColor $(if($result.Statistics.TotalAnnualSavingsPotential -gt 100000) { "Green" } else { "Cyan" })
                                    Write-Host ""
                                    Write-Host "⚠️ 最適化機会:" -ForegroundColor Yellow
                                    Write-Host "低利用率ライセンス: $($result.Statistics.LowUtilizationLicenses)" -ForegroundColor $(if($result.Statistics.LowUtilizationLicenses -gt 0) { "Yellow" } else { "Green" })
                                    Write-Host "高リスクライセンス: $($result.Statistics.HighRiskLicenses)" -ForegroundColor $(if($result.Statistics.HighRiskLicenses -gt 0) { "Red" } else { "Green" })
                                    Write-Host "非アクティブユーザー: $($result.Statistics.InactiveUsers)" -ForegroundColor $(if($result.Statistics.InactiveUsers -gt 0) { "Red" } else { "Green" })
                                    
                                    # 重要な警告表示
                                    if ($result.Statistics.TotalAnnualSavingsPotential -gt 500000) {
                                        Write-Host ""
                                        Write-Host "🚨 高額な節約機会:" -ForegroundColor Red
                                        Write-Host "   年間$('{0:N0}' -f $result.Statistics.TotalAnnualSavingsPotential)円の節約が可能です" -ForegroundColor Red
                                        Write-Host "   ライセンス最適化の緊急実施を推奨します" -ForegroundColor Red
                                    }
                                    elseif ($result.Statistics.TotalAnnualSavingsPotential -gt 100000) {
                                        Write-Host ""
                                        Write-Host "💰 節約機会あり:" -ForegroundColor Yellow
                                        Write-Host "   年間$('{0:N0}' -f $result.Statistics.TotalAnnualSavingsPotential)円の節約が可能です" -ForegroundColor Yellow
                                        Write-Host "   ライセンス見直しを検討してください" -ForegroundColor Yellow
                                    }
                                    elseif ($result.Statistics.InactiveUsers -gt 5) {
                                        Write-Host ""
                                        Write-Host "⚠️ 非アクティブユーザー検出:" -ForegroundColor Yellow
                                        Write-Host "   $($result.Statistics.InactiveUsers)名の長期未利用ユーザーが検出されました" -ForegroundColor Yellow
                                        Write-Host "   ライセンス回収を検討してください" -ForegroundColor Yellow
                                    }
                                    else {
                                        Write-Host ""
                                        Write-Host "✅ ライセンス利用効率良好:" -ForegroundColor Green
                                        Write-Host "   ライセンス利用は最適化されています" -ForegroundColor Green
                                    }
                                    
                                    if ($result.CSVPath) {
                                        Write-Status "📄 CSVレポート: $($result.CSVPath)" "Info"
                                    }
                                    if ($result.HTMLPath) {
                                        Write-Status "🌐 HTMLダッシュボード: $($result.HTMLPath)" "Info"
                                        
                                        # オプション: HTMLレポートをブラウザで開く
                                        $openReport = Read-Host "ライセンス分析ダッシュボードをブラウザで開きますか？ (y/N)"
                                        if ($openReport -eq "y" -or $openReport -eq "Y") {
                                            Start-Process $result.HTMLPath
                                        }
                                    }
                                }
                                else {
                                    Write-Status "❌ エラーが発生しました: $($result.Error)" "Error"
                                }
                            } else {
                                Write-Status "❌ LicenseAnalysis.ps1が見つかりません: $licenseScriptPath" "Error"
                            }
                        }
                        "5" {
                            Write-Status "利用率・アクティブ率レポート機能は実装中です" "Warning"
                            Write-Host "実装予定機能:" -ForegroundColor Yellow
                            Write-Host "- ユーザーアクティビティ分析" -ForegroundColor Gray
                            Write-Host "- アプリケーション利用統計" -ForegroundColor Gray
                            Write-Host "- 非アクティブユーザー検出" -ForegroundColor Gray
                        }
                        "6" {
                            Write-Status "年間消費傾向アラート機能は実装中です" "Warning"
                            Write-Host "実装予定機能:" -ForegroundColor Yellow
                            Write-Host "- 年間ライセンス消費トレンド" -ForegroundColor Gray
                            Write-Host "- 容量使用量の予測" -ForegroundColor Gray
                            Write-Host "- 予算オーバー警告" -ForegroundColor Gray
                        }
                        "7" {
                            Write-Status "メインメニューに戻ります" "Info"
                        }
                        default {
                            Write-Status "無効な選択です" "Warning"
                        }
                    }
                }
                catch {
                    Write-Status "OneDrive/Teams/ライセンス機能エラー: $($_.Exception.Message)" "Error"
                }
                break
            }
            "0" {
                Write-Status "ツールを終了します" "Info"
                return
            }
            default {
                Write-Status "無効な選択です (0-9を選択してください)" "Warning"
                continue
            }
        }
        
        if ($choice -ne "0") {
            Write-Host "`n" + "=" * 40 -ForegroundColor Gray
            Write-Host "=== Microsoft 365 統合管理システム ===" -ForegroundColor Yellow
            Write-Host "=" * 60 -ForegroundColor Gray
            Write-Host "【基本機能】" -ForegroundColor Cyan
            Write-Host "1. 初期セットアップ (Setup)"
            Write-Host "2. 認証テスト (Authentication Test)"
            Write-Host "3. レポート生成 (Report Generation)"
            Write-Host "4. システム診断 (System Check)"
            Write-Host "5. スケジュール設定 (Schedule Setup)"
            Write-Host ""
            Write-Host "【管理機能】" -ForegroundColor Green
            Write-Host "6. ユーザー管理 (UM系 - User Management)"
            Write-Host "7. グループ管理 (GM系 - Group Management)"
            Write-Host "8. Exchange Online (EX系 - Exchange)"
            Write-Host "9. OneDrive/Teams/ライセンス (OD/TM/LM系)"
            Write-Host ""
            Write-Host "【その他】" -ForegroundColor Yellow
            Write-Host "0. 終了 (Exit)"
            Write-Host "=" * 60 -ForegroundColor Gray
            Write-Host "`nメニューに戻りますか？ (y/N)" -NoNewline
            $continue = Read-Host
            if ($continue -ne "y" -and $continue -ne "Y") {
                break
            }
        }
        
    } while ($choice -ne "0")
}

# メイン実行
try {
    # アクションに基づく実行
    switch ($Action) {
        "Setup" {
            Write-Banner
            Invoke-Setup
        }
        "Test" {
            Write-Banner
            Invoke-AuthenticationTest
        }
        "Report" {
            Write-Banner
            Invoke-ReportGeneration
        }
        "Schedule" {
            Write-Banner
            Write-Status "スケジュール設定は Windows タスクスケジューラーで行ってください" "Info"
        }
        "Check" {
            Write-Banner
            Invoke-SystemCheck
        }
        "Menu" {
            Show-MainMenu
        }
    }
}
catch {
    Write-Status "予期しないエラーが発生しました: $($_.Exception.Message)" "Error"
    Write-Host "詳細:" -ForegroundColor Yellow
    Write-Host $_.Exception.ToString() -ForegroundColor Gray
    exit 1
}

Write-Host "`n処理が完了しました。" -ForegroundColor Green