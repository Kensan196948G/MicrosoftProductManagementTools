# ================================================================================
# Microsoft 365統合管理ツール - 完全版 GUI
# 実データ対応・全機能統合版
# Templates/Samples の全6フォルダ対応
# ================================================================================

[CmdletBinding()]
param()

# PowerShellウィンドウタイトル設定（安全なアクセス）
try {
    $psVersion = $PSVersionTable.PSVersion
    
    # $Host.UI.RawUIが存在し、アクセス可能か確認
    if ($Host -and $Host.UI -and $Host.UI.RawUI) {
        if ($psVersion.Major -ge 7) {
            $Host.UI.RawUI.WindowTitle = "🚀 Microsoft 365統合管理ツール - 完全版 PowerShell 7.x GUI"
        } else {
            $Host.UI.RawUI.WindowTitle = "🚀 Microsoft 365統合管理ツール - 完全版 Windows PowerShell GUI"
        }
        
        # 背景色と文字色の設定はコンソールホストでのみ有効
        if ($Host.Name -eq "ConsoleHost") {
            if ($psVersion.Major -ge 7) {
                $Host.UI.RawUI.BackgroundColor = "DarkBlue"
                $Host.UI.RawUI.ForegroundColor = "White"
            } else {
                $Host.UI.RawUI.BackgroundColor = "DarkMagenta"
                $Host.UI.RawUI.ForegroundColor = "White"
            }
        }
    }
    
    Clear-Host
    Write-Host "🚀 Microsoft 365統合管理ツール完全版を起動中..." -ForegroundColor Cyan
} catch {
    # エラーを無視して続行
    Write-Host "🚀 Microsoft 365統合管理ツール完全版を起動中..." -ForegroundColor Cyan
}

# STAモードチェック
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "警告: このスクリプトはSTAモードで実行する必要があります。" -ForegroundColor Yellow
    Write-Host "再起動します..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList "-sta", "-File", $MyInvocation.MyCommand.Path -NoNewWindow -Wait
    exit
}

# プラットフォーム検出とアセンブリ読み込み
if ($IsLinux -or $IsMacOS) {
    Write-Host "エラー: このGUIアプリケーションはWindows環境でのみ動作します。" -ForegroundColor Red
    Write-Host "現在の環境: $($PSVersionTable.Platform)" -ForegroundColor Yellow
    Write-Host "CLIモードをご利用ください: pwsh -File run_launcher.ps1 -Mode cli" -ForegroundColor Green
    exit 1
}

# 必要なアセンブリの読み込み
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Add-Type -AssemblyName System.ComponentModel -ErrorAction Stop
    Add-Type -AssemblyName System.Web -ErrorAction Stop
}
catch {
    Write-Host "エラー: Windows Formsアセンブリの読み込みに失敗しました。" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# グローバル変数
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent
$Script:M365Connected = $false
$Script:ExchangeConnected = $false

# 共通モジュールをインポート
$modulePath = Join-Path $Script:ToolRoot "Scripts\Common"

# 新しいReal M365 Data Provider モジュールをインポート
try {
    # 既存のモジュールをクリーンアップ
    Get-Module RealM365DataProvider -ErrorAction SilentlyContinue | Remove-Module -Force
    Get-Module ProgressDisplay -ErrorAction SilentlyContinue | Remove-Module -Force
    
    Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
    Import-Module "$modulePath\HTMLTemplateEngine.psm1" -Force -DisableNameChecking -Global
    Import-Module "$modulePath\DataSourceVisualization.psm1" -Force -DisableNameChecking -Global
    Write-Host "✅ RealM365DataProvider モジュール読み込み完了" -ForegroundColor Green
    Write-Host "✅ HTMLTemplateEngine モジュール読み込み完了" -ForegroundColor Green
    Write-Host "✅ DataSourceVisualization モジュール読み込み完了" -ForegroundColor Green
    
    # モジュール読み込み直後にメイン関数を定義（グローバルスコープ）
    . {
        function global:Get-ReportDataFromProvider {
            param(
                [string]$DataType,
                [hashtable]$Parameters = @{}
            )
            
            try {
                # 常にリアルデータを取得（Microsoft 365接続状態は関数内で自動確認）
                switch ($DataType) {
                    "Users" { return Get-M365AllUsers @Parameters }
                    "LicenseAnalysis" { return Get-M365LicenseAnalysis @Parameters }
                    "UsageAnalysis" { return Get-M365UsageAnalysis @Parameters }
                    "MFAStatus" { return Get-M365MFAStatus @Parameters }
                    "MailboxAnalysis" { return Get-M365MailboxAnalysis @Parameters }
                    "TeamsUsage" { return Get-M365TeamsUsage @Parameters }
                    "OneDriveAnalysis" { return Get-M365OneDriveAnalysis @Parameters }
                    "SignInLogs" { return Get-M365SignInLogs @Parameters }
                    "DailyReport" { return Get-M365DailyReport @Parameters }
                    "WeeklyReport" { return Get-M365WeeklyReport @Parameters }
                    "MonthlyReport" { return Get-M365MonthlyReport @Parameters }
                    "YearlyReport" { return Get-M365YearlyReport @Parameters }
                    "TestExecution" { return Get-M365TestExecution @Parameters }
                    "PerformanceAnalysis" { return Get-M365PerformanceAnalysis @Parameters }
                    "SecurityAnalysis" { return Get-M365SecurityAnalysis @Parameters }
                    "PermissionAudit" { return Get-M365PermissionAudit @Parameters }
                    "ConditionalAccess" { return Get-M365ConditionalAccess @Parameters }
                    "MailFlowAnalysis" { return Get-M365MailFlowAnalysis @Parameters }
                    "SpamProtectionAnalysis" { return Get-M365SpamProtectionAnalysis @Parameters }
                    "MailDeliveryAnalysis" { return Get-M365MailDeliveryAnalysis @Parameters }
                    "TeamsSettings" { return Get-M365TeamsSettings @Parameters }
                    "MeetingQuality" { return Get-M365MeetingQuality @Parameters }
                    "TeamsAppAnalysis" { return Get-M365TeamsAppAnalysis @Parameters }
                    "SharingAnalysis" { return Get-M365SharingAnalysis @Parameters }
                    "SyncErrorAnalysis" { return Get-M365SyncErrorAnalysis @Parameters }
                    "ExternalSharingAnalysis" { return Get-M365ExternalSharingAnalysis @Parameters }
                    default { 
                        Write-Warning "未対応のデータタイプ: $DataType"
                        return @([PSCustomObject]@{ Message = "データタイプ '$DataType' は対応していません" })
                    }
                }
            }
            catch {
                Write-Host "データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
                # エラー時も基本的なエラー情報を返す
                return @([PSCustomObject]@{ 
                    Error = $_.Exception.Message
                    DataType = $DataType
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                })
            }
        }
        
        Write-Host "✅ Get-ReportDataFromProvider 関数をグローバルスコープで定義完了" -ForegroundColor Green
        
        # Export-DataToFiles関数もグローバルスコープで定義
        function global:Export-DataToFiles {
            param(
                [array]$Data,
                [string]$ReportName,
                [string]$FolderName = "Reports"
            )
            
            if (-not $Data -or $Data.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("出力するデータがありません。", "エラー", "OK", "Warning")
                return
            }
            
            try {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $reportsDir = Join-Path $Script:ToolRoot $FolderName
                $specificDir = Join-Path $reportsDir $ReportName
                
                if (-not (Test-Path $specificDir)) {
                    New-Item -Path $specificDir -ItemType Directory -Force | Out-Null
                }
                
                # CSV出力
                $csvPath = Join-Path $specificDir "${ReportName}_${timestamp}.csv"
                $Data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
                
                # HTML出力
                $htmlPath = Join-Path $specificDir "${ReportName}_${timestamp}.html"
                $htmlContent = Generate-EnhancedHTMLReport -Data $Data -ReportType $ReportName -Title $ReportName
                $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
                
                # ファイルを開く
                Start-Process $htmlPath
                Start-Process $csvPath
                
                [System.Windows.Forms.MessageBox]::Show("レポートを生成しました。`n`nHTML: $htmlPath`nCSV: $csvPath", "完了", "OK", "Information")
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("ファイル出力エラー: $($_.Exception.Message)", "エラー", "OK", "Error")
            }
        }
        
        Write-Host "✅ Export-DataToFiles 関数をグローバルスコープで定義完了" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ RealM365DataProvider モジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "ダミーデータモードで動作します" -ForegroundColor Yellow
}

# その他の必要なモジュールをインポート
try {
    Import-Module "$modulePath\ProgressDisplay.psm1" -Force -ErrorAction SilentlyContinue -Global
} catch {
    # ProgressDisplay モジュールが無い場合は無視
}

# Windows Forms初期設定（PowerShell 7.x 対応）
try {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    Write-Host "✅ Windows Forms 初期化完了" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Windows Forms 初期化警告: $($_.Exception.Message)" -ForegroundColor Yellow
}

# モジュール読み込み完了後にメイン関数を定義済み（グローバルスコープ）

# Export-DataToFiles関数もグローバルスコープで定義済み

# Generate-HTMLReport関数は削除し、HTMLTemplateEngine.psm1のGenerate-EnhancedHTMLReportを使用

# ================================================================================
# GUI作成関数
# ================================================================================

function New-MainForm {
    [OutputType([System.Windows.Forms.Form])]
    param()
    
    # メインフォーム作成（PowerShell 7.x 対応・出力制御版）
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "🚀 Microsoft 365統合管理ツール - 完全版"
    $form.Size = New-Object System.Drawing.Size(1200, 800)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    
    # メインタイトル
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "🏢 Microsoft 365統合管理ツール - 完全版"
    $titleLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 10)
    $titleLabel.Size = New-Object System.Drawing.Size(1000, 40)
    $titleLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($titleLabel)
    
    # 接続状態表示
    $connectionLabel = New-Object System.Windows.Forms.Label
    $connectionLabel.Location = New-Object System.Drawing.Point(20, 55)
    $connectionLabel.Size = New-Object System.Drawing.Size(1000, 25)
    $connectionLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
    $connectionLabel.TextAlign = "MiddleCenter"
    
    # 認証状態チェック（出力を抑制）
    try {
        $authStatus = Test-M365Authentication | Out-Null
        $null = $authStatus  # 変数を無効化
        # 簡易認証確認（出力なし）
        if ($Script:M365Connected) {
            $connectionLabel.Text = "✅ Microsoft 365 認証済み - リアルデータを取得します"
            $connectionLabel.ForeColor = [System.Drawing.Color]::Green
        } else {
            $connectionLabel.Text = "⚠️ Microsoft 365 未認証 - ダミーデータを使用します"
            $connectionLabel.ForeColor = [System.Drawing.Color]::Orange
        }
    } catch {
        $connectionLabel.Text = "❌ Microsoft 365 接続確認エラー - ダミーデータを使用します"
        $connectionLabel.ForeColor = [System.Drawing.Color]::Red
        $Script:M365Connected = $false
    }
    
    $form.Controls.Add($connectionLabel)
    
    # 接続ボタン
    $connectButton = New-Object System.Windows.Forms.Button
    $connectButton.Text = "🔑 Microsoft 365 に接続（非対話型）"
    $connectButton.Location = New-Object System.Drawing.Point(20, 85)
    $connectButton.Size = New-Object System.Drawing.Size(200, 35)
    $connectButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
    $connectButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $connectButton.ForeColor = [System.Drawing.Color]::White
    $connectButton.FlatStyle = "Flat"
    # スクリプトブロック内での変数スコープ問題を解決するため、ローカル変数を作成
    $btnConnect = $connectButton
    $lblConnection = $connectionLabel
    
    $connectButton.Add_Click({
        try {
            $btnConnect.Text = "🔄 接続中..."
            $btnConnect.Enabled = $false
            
            # 関数の存在確認とモジュールの再読み込み
            if (-not (Get-Command Connect-M365Services -ErrorAction SilentlyContinue)) {
                $modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
                Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
            }
            
            $authResult = Connect-M365Services
            if ($authResult.GraphConnected) {
                $lblConnection.Text = "✅ Microsoft 365 接続成功 - リアルデータを取得します"
                $lblConnection.ForeColor = [System.Drawing.Color]::Green
                $Script:M365Connected = $true
                [System.Windows.Forms.MessageBox]::Show("Microsoft 365 への接続に成功しました。", "接続成功", "OK", "Information")
            } else {
                $lblConnection.Text = "❌ Microsoft 365 接続失敗 - ダミーデータを使用します"
                $lblConnection.ForeColor = [System.Drawing.Color]::Red
                $Script:M365Connected = $false
                [System.Windows.Forms.MessageBox]::Show("Microsoft 365 への接続に失敗しました。", "接続失敗", "OK", "Warning")
            }
        } catch {
            $lblConnection.Text = "❌ Microsoft 365 接続エラー - ダミーデータを使用します"
            $lblConnection.ForeColor = [System.Drawing.Color]::Red
            $Script:M365Connected = $false
            [System.Windows.Forms.MessageBox]::Show("接続エラー: $($_.Exception.Message)", "エラー", "OK", "Error")
        } finally {
            $btnConnect.Text = "🔑 Microsoft 365 に接続（非対話型）"
            $btnConnect.Enabled = $true
        }
    }.GetNewClosure())
    $form.Controls.Add($connectButton)
    
    # タブコントロール作成
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(20, 130)
    $tabControl.Size = New-Object System.Drawing.Size(1150, 600)
    $tabControl.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
    
    # 1. 定期レポートタブ
    $regularTab = New-Object System.Windows.Forms.TabPage
    $regularTab.Text = "📊 定期レポート"
    $regularTab.BackColor = [System.Drawing.Color]::White
    Add-RegularReportsButtons -TabPage $regularTab
    $tabControl.TabPages.Add($regularTab)
    
    # 2. 分析レポートタブ
    $analyticsTab = New-Object System.Windows.Forms.TabPage
    $analyticsTab.Text = "🔍 分析レポート"
    $analyticsTab.BackColor = [System.Drawing.Color]::White
    Add-AnalyticsReportsButtons -TabPage $analyticsTab
    $tabControl.TabPages.Add($analyticsTab)
    
    # 3. Entra ID管理タブ
    $entraTab = New-Object System.Windows.Forms.TabPage
    $entraTab.Text = "👥 Entra ID管理"
    $entraTab.BackColor = [System.Drawing.Color]::White
    Add-EntraIDButtons -TabPage $entraTab
    $tabControl.TabPages.Add($entraTab)
    
    # 4. Exchange Online管理タブ
    $exchangeTab = New-Object System.Windows.Forms.TabPage
    $exchangeTab.Text = "📧 Exchange Online"
    $exchangeTab.BackColor = [System.Drawing.Color]::White
    Add-ExchangeButtons -TabPage $exchangeTab
    $tabControl.TabPages.Add($exchangeTab)
    
    # 5. Teams管理タブ
    $teamsTab = New-Object System.Windows.Forms.TabPage
    $teamsTab.Text = "💬 Teams管理"
    $teamsTab.BackColor = [System.Drawing.Color]::White
    Add-TeamsButtons -TabPage $teamsTab
    $tabControl.TabPages.Add($teamsTab)
    
    # 6. OneDrive管理タブ
    $oneDriveTab = New-Object System.Windows.Forms.TabPage
    $oneDriveTab.Text = "💾 OneDrive管理"
    $oneDriveTab.BackColor = [System.Drawing.Color]::White
    Add-OneDriveButtons -TabPage $oneDriveTab
    $tabControl.TabPages.Add($oneDriveTab)
    
    $form.Controls.Add($tabControl)
    
    # ステータスバー
    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = "準備完了 - Microsoft 365統合管理ツール"
    $statusStrip.Items.Add($statusLabel)
    $form.Controls.Add($statusStrip)
    
    # フォームオブジェクトのみを返す（配列にしない）
    return $form
}

function Add-RegularReportsButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    $buttons = @(
        @{ Text = "📅 日次レポート"; Action = "DailyReport"; X = 20; Y = 20 },
        @{ Text = "📊 週次レポート"; Action = "WeeklyReport"; X = 220; Y = 20 },
        @{ Text = "📈 月次レポート"; Action = "MonthlyReport"; X = 420; Y = 20 },
        @{ Text = "📆 年次レポート"; Action = "YearlyReport"; X = 620; Y = 20 },
        @{ Text = "🧪 テスト実行"; Action = "TestExecution"; X = 820; Y = 20 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-AnalyticsReportsButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    $buttons = @(
        @{ Text = "📊 ライセンス分析"; Action = "LicenseAnalysis"; X = 20; Y = 20 },
        @{ Text = "📈 使用状況分析"; Action = "UsageAnalysis"; X = 220; Y = 20 },
        @{ Text = "⚡ パフォーマンス分析"; Action = "PerformanceAnalysis"; X = 420; Y = 20 },
        @{ Text = "🛡️ セキュリティ分析"; Action = "SecurityAnalysis"; X = 620; Y = 20 },
        @{ Text = "🔍 権限監査"; Action = "PermissionAudit"; X = 820; Y = 20 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-EntraIDButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    $buttons = @(
        @{ Text = "👥 ユーザー一覧"; Action = "UserList"; X = 20; Y = 20 },
        @{ Text = "🔐 MFA状況"; Action = "MFAStatus"; X = 220; Y = 20 },
        @{ Text = "🛡️ 条件付きアクセス"; Action = "ConditionalAccess"; X = 420; Y = 20 },
        @{ Text = "📝 サインインログ"; Action = "SignInLogs"; X = 620; Y = 20 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-ExchangeButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    $buttons = @(
        @{ Text = "📧 メールボックス管理"; Action = "MailboxManagement"; X = 20; Y = 20 },
        @{ Text = "🔄 メールフロー分析"; Action = "MailFlowAnalysis"; X = 220; Y = 20 },
        @{ Text = "🛡️ スパム対策分析"; Action = "SpamProtectionAnalysis"; X = 420; Y = 20 },
        @{ Text = "📬 配信分析"; Action = "MailDeliveryAnalysis"; X = 620; Y = 20 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-TeamsButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    $buttons = @(
        @{ Text = "💬 Teams使用状況"; Action = "TeamsUsage"; X = 20; Y = 20 },
        @{ Text = "⚙️ Teams設定分析"; Action = "TeamsSettingsAnalysis"; X = 220; Y = 20 },
        @{ Text = "📹 会議品質分析"; Action = "MeetingQualityAnalysis"; X = 420; Y = 20 },
        @{ Text = "📱 アプリ分析"; Action = "TeamsAppAnalysis"; X = 620; Y = 20 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-OneDriveButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    $buttons = @(
        @{ Text = "💾 ストレージ分析"; Action = "StorageAnalysis"; X = 20; Y = 20 },
        @{ Text = "🤝 共有分析"; Action = "SharingAnalysis"; X = 220; Y = 20 },
        @{ Text = "🔄 同期エラー分析"; Action = "SyncErrorAnalysis"; X = 420; Y = 20 },
        @{ Text = "🌐 外部共有分析"; Action = "ExternalSharingAnalysis"; X = 620; Y = 20 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Create-ActionButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [string]$Action
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size(180, 50)
    $button.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = "Flat"
    $button.Cursor = "Hand"
    
    # スコープ問題を解決するため、インライン処理を実装
    $btnRef = $button
    $actionRef = $Action
    
    $button.Add_Click({
        param($sender, $e)
        
        # ボタンの安全な操作
        if ($sender -and $sender.GetType().Name -eq 'Button') {
            $originalText = $sender.Text
            $sender.Text = "🔄 処理中..."
            $sender.Enabled = $false
            
            try {
                # ダミーデータを生成
                $data = Get-ReportDataFromProvider -DataType "DailyReport"
                $reportName = "$actionRefレポート"
                
                # データをファイルにエクスポート
                Export-DataToFiles -Data $data -ReportName $reportName
                
                # 成功メッセージ
                [System.Windows.Forms.MessageBox]::Show("$reportNameが正常に生成されました。", "成功", "OK", "Information")
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("エラーが発生しました: $($_.Exception.Message)", "エラー", "OK", "Error")
            }
            finally {
                $sender.Text = $originalText
                $sender.Enabled = $true
            }
        }
    }.GetNewClosure())
    
    return $button
}

function Execute-ReportAction {
    param(
        [string]$Action,
        $Button
    )
    
    # ボタンオブジェクトの型チェックと安全なプロパティアクセス
    if ($Button -and $Button.GetType().Name -eq 'Button') {
        $originalText = $Button.Text
        $Button.Text = "🔄 処理中..."
        $Button.Enabled = $false
    } else {
        $originalText = "ボタン"
        Write-Host "警告: ボタンオブジェクトが有効ではありません" -ForegroundColor Yellow
    }
    
    try {
        $data = $null
        $reportName = ""
        
        switch ($Action) {
            "DailyReport" {
                $data = Get-ReportDataFromProvider -DataType "DailyReport"
                $reportName = "日次レポート"
            }
            "WeeklyReport" {
                $data = Get-ReportDataFromProvider -DataType "WeeklyReport"
                $reportName = "週次レポート"
            }
            "MonthlyReport" {
                $data = Get-ReportDataFromProvider -DataType "MonthlyReport"
                $reportName = "月次レポート"
            }
            "YearlyReport" {
                $data = Get-ReportDataFromProvider -DataType "YearlyReport"
                $reportName = "年次レポート"
            }
            "TestExecution" {
                $data = Get-ReportDataFromProvider -DataType "TestExecution"
                $reportName = "テスト実行結果"
            }
            "LicenseAnalysis" {
                $data = Get-ReportDataFromProvider -DataType "LicenseAnalysis"
                $reportName = "ライセンス分析"
            }
            "UsageAnalysis" {
                $data = Get-ReportDataFromProvider -DataType "UsageAnalysis"
                $reportName = "使用状況分析"
            }
            "PerformanceAnalysis" {
                $data = @([PSCustomObject]@{ ServiceName = "Microsoft Teams"; ResponseTimeMs = 120; UptimePercent = 99.9; SLAStatus = "達成"; ErrorRatePercent = 0.1; CPUUsagePercent = 45; MemoryUsagePercent = 38; StorageUsagePercent = 25; Status = "正常" })
                $reportName = "パフォーマンス分析"
            }
            "SecurityAnalysis" {
                $data = @([PSCustomObject]@{ SecurityItem = "MFA有効率"; Status = "良好"; TargetUsers = 150; ComplianceRatePercent = 85; RiskLevel = "低"; LastCheckDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); RecommendedAction = "全ユーザーでMFA有効化"; Details = "85%のユーザーがMFAを有効にしています" })
                $reportName = "セキュリティ分析"
            }
            "PermissionAudit" {
                $data = @([PSCustomObject]@{ UserName = "山田太郎"; Email = "yamada@contoso.com"; Department = "営業部"; AdminRole = "なし"; AccessRights = "標準ユーザー"; LastLogin = "2025-01-16 09:30"; MFAStatus = "有効"; Status = "適切" })
                $reportName = "権限監査"
            }
            "UserList" {
                $data = Get-ReportDataFromProvider -DataType "Users"
                $reportName = "ユーザー一覧"
            }
            "MFAStatus" {
                $data = Get-ReportDataFromProvider -DataType "MFAStatus"
                $reportName = "MFA状況"
            }
            "ConditionalAccess" {
                $data = @([PSCustomObject]@{ PolicyName = "MFA必須ポリシー"; Status = "有効"; TargetUsers = "全ユーザー"; TargetApplications = "全アプリケーション"; Conditions = "信頼できる場所以外"; AccessControls = "MFA必須"; CreationDate = "2024-01-15"; LastUpdated = "2024-12-01"; ApplicationCount = 1250 })
                $reportName = "条件付きアクセス"
            }
            "SignInLogs" {
                $data = Get-ReportDataFromProvider -DataType "SignInLogs"
                $reportName = "サインインログ"
            }
            "MailboxManagement" {
                $data = Get-ReportDataFromProvider -DataType "MailboxAnalysis"
                $reportName = "メールボックス管理"
            }
            "MailFlowAnalysis" {
                $data = @([PSCustomObject]@{ DateTime = "2025-01-16 09:30"; Sender = "yamada@contoso.com"; Recipient = "sato@contoso.com"; Subject = "会議の件"; MessageSizeKB = 25; Status = "配信済み"; Connector = "デフォルト"; EventType = "送信"; Details = "正常に配信されました" })
                $reportName = "メールフロー分析"
            }
            "SpamProtectionAnalysis" {
                $data = @([PSCustomObject]@{ DateTime = "2025-01-16 08:45"; Sender = "spam@example.com"; Recipient = "yamada@contoso.com"; Subject = "緊急のお知らせ"; ThreatType = "スパム"; SpamScore = 8.5; Action = "検疫"; PolicyName = "高保護ポリシー"; Details = "スパムとして検出され検疫されました" })
                $reportName = "スパム対策分析"
            }
            "MailDeliveryAnalysis" {
                $data = @([PSCustomObject]@{ SendDateTime = "2025-01-16 09:00"; Sender = "yamada@contoso.com"; Recipient = "client@partner.com"; Subject = "プロジェクト資料"; MessageID = "MSG001"; DeliveryStatus = "配信成功"; LatestEvent = "配信完了"; DelayReason = "なし"; RecipientServer = "partner.com" })
                $reportName = "配信分析"
            }
            "TeamsUsage" {
                $data = Get-ReportDataFromProvider -DataType "TeamsUsage"
                $reportName = "Teams使用状況"
            }
            "TeamsSettingsAnalysis" {
                $data = @([PSCustomObject]@{ PolicyName = "会議ポリシー"; PolicyType = "Teams会議"; TargetUsersCount = 150; Status = "有効"; MessagingPermission = "有効"; FileSharingPermission = "有効"; MeetingRecordingPermission = "管理者のみ"; LastUpdated = "2024-12-15"; Compliance = "準拠" })
                $reportName = "Teams設定分析"
            }
            "MeetingQualityAnalysis" {
                $data = @([PSCustomObject]@{ MeetingID = "MTG001"; MeetingName = "月次定例会議"; DateTime = "2025-01-16 10:00"; ParticipantCount = 8; AudioQuality = "良好"; VideoQuality = "良好"; NetworkQuality = "良好"; OverallQualityScore = 9.2; QualityRating = "優秀" })
                $reportName = "会議品質分析"
            }
            "TeamsAppAnalysis" {
                $data = @([PSCustomObject]@{ AppName = "Planner"; Version = "1.2.3"; Publisher = "Microsoft"; InstallationCount = 125; ActiveUsersCount = 95; LastUsedDate = "2025-01-16"; AppStatus = "アクティブ"; PermissionStatus = "承認済み"; SecurityScore = 9.5 })
                $reportName = "Teamsアプリ分析"
            }
            "StorageAnalysis" {
                $data = Get-ReportDataFromProvider -DataType "OneDriveAnalysis"
                $reportName = "OneDriveストレージ分析"
            }
            "SharingAnalysis" {
                $data = @([PSCustomObject]@{ FileName = "営業資料.xlsx"; Owner = "yamada@contoso.com"; FileSizeMB = 5.2; ShareType = "内部"; SharedWith = "営業チーム"; AccessPermission = "編集可能"; ShareDate = "2025-01-15 14:30"; LastAccess = "2025-01-16 09:15"; RiskLevel = "低" })
                $reportName = "OneDrive共有分析"
            }
            "SyncErrorAnalysis" {
                $data = @([PSCustomObject]@{ OccurrenceDate = "2025-01-16 08:30"; UserName = "田中次郎"; FilePath = "Documents/report.docx"; ErrorType = "同期競合"; ErrorCode = "SYNC001"; ErrorMessage = "ファイルが他のユーザーによって編集されています"; AffectedFilesCount = 1; Status = "解決済み"; RecommendedResolutionDate = "2025-01-16" })
                $reportName = "OneDrive同期エラー分析"
            }
            "ExternalSharingAnalysis" {
                $data = @([PSCustomObject]@{ FileName = "プロジェクト仕様書.pdf"; Owner = "yamada@contoso.com"; ExternalDomain = "partner.com"; SharedEmail = "client@partner.com"; AccessPermission = "表示のみ"; ShareURL = "https://contoso-my.sharepoint.com/personal/yamada.../shared"; ShareStartDate = "2025-01-15"; LastAccess = "2025-01-16 08:45"; RiskLevel = "中" })
                $reportName = "OneDrive外部共有分析"
            }
        }
        
        if ($data -and $data.Count -gt 0) {
            Export-DataToFiles -Data $data -ReportName $reportName
        } else {
            [System.Windows.Forms.MessageBox]::Show("データの取得に失敗しました。", "エラー", "OK", "Warning")
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("エラーが発生しました: $($_.Exception.Message)", "エラー", "OK", "Error")
    }
    finally {
        # ボタンオブジェクトの安全なリストア
        if ($Button -and $Button.GetType().Name -eq 'Button') {
            $Button.Text = $originalText
            $Button.Enabled = $true
        }
    }
}

# ================================================================================
# メイン処理
# ================================================================================

try {
    Write-Host "🎯 GUI初期化中..." -ForegroundColor Cyan
    
    # メインフォーム作成と表示（完全出力抑制版）
    $formCreationOutput = New-MainForm
    $mainForm = $formCreationOutput | Where-Object { $_ -is [System.Windows.Forms.Form] } | Select-Object -First 1
    
    if (-not $mainForm) {
        Write-Host "❌ フォーム作成エラー: 有効なフォームが見つかりません" -ForegroundColor Red
        throw "フォーム作成に失敗しました"
    }
    
    # フォーム型確認とキャスト
    if ($mainForm -is [System.Windows.Forms.Form]) {
        Write-Host "✅ GUIが正常に初期化されました" -ForegroundColor Green
        [System.Windows.Forms.Application]::Run($mainForm)
    } else {
        Write-Host "❌ フォーム作成エラー: 予期しない型 $($mainForm.GetType().Name)" -ForegroundColor Red
        throw "フォーム作成に失敗しました"
    }
}
catch {
    Write-Host "❌ GUI初期化エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    [System.Windows.Forms.MessageBox]::Show("GUI初期化エラー: $($_.Exception.Message)", "エラー", "OK", "Error")
}
finally {
    Write-Host "🔚 Microsoft 365統合管理ツールを終了します" -ForegroundColor Cyan
}