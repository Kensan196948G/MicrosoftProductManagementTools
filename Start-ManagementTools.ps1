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
                                Write-Host "推定月額コスト: ¥$($result.TotalLicenseCost.ToString('N0'))" -ForegroundColor Blue
                                Write-Host "ユーザー単価平均: ¥$($result.AvgLicenseCostPerUser.ToString('N0'))/月" -ForegroundColor Blue
                                
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
                            Write-Status "配布グループ整合性チェック機能は実装中です" "Warning"
                        }
                        "6" {
                            Write-Status "会議室リソース利用状況監査機能は実装中です" "Warning"
                        }
                        "7" {
                            Write-Status "スパム・フィッシング傾向分析機能は実装中です" "Warning"
                        }
                        "8" {
                            Write-Status "Exchangeライセンス有効性チェック機能は実装中です" "Warning"
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
                            Write-Status "OneDrive使用容量分析機能は実装中です" "Warning"
                            Write-Host "実装予定機能:" -ForegroundColor Yellow
                            Write-Host "- OneDriveサイト容量監視" -ForegroundColor Gray
                            Write-Host "- 容量警告アラート" -ForegroundColor Gray
                            Write-Host "- 使用率レポート" -ForegroundColor Gray
                        }
                        "2" {
                            Write-Status "Teams構成確認機能は実装中です" "Warning"
                            Write-Host "実装予定機能:" -ForegroundColor Yellow
                            Write-Host "- チーム一覧とメンバー構成" -ForegroundColor Gray
                            Write-Host "- オーナー不在チーム検出" -ForegroundColor Gray
                            Write-Host "- 録画設定とポリシー確認" -ForegroundColor Gray
                        }
                        "3" {
                            Write-Status "OneDrive外部共有状況確認機能は実装中です" "Warning"
                            Write-Host "実装予定機能:" -ForegroundColor Yellow
                            Write-Host "- 外部共有ファイル/フォルダ検出" -ForegroundColor Gray
                            Write-Host "- 共有権限とアクセス状況" -ForegroundColor Gray
                            Write-Host "- セキュリティリスク評価" -ForegroundColor Gray
                        }
                        "4" {
                            Write-Status "ライセンス配布状況監視機能は実装中です" "Warning"
                            Write-Host "実装予定機能:" -ForegroundColor Yellow
                            Write-Host "- ライセンス種別と使用状況" -ForegroundColor Gray
                            Write-Host "- 未使用ライセンス検出" -ForegroundColor Gray
                            Write-Host "- コスト最適化提案" -ForegroundColor Gray
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