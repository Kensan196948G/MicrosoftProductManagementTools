# 💻 Microsoft 365統合管理ツール 開発者向けガイド

## 📋 開発環境概要

### 🎯 開発方針・設計思想
Microsoft 365統合管理ツールは、**モジュラー設計**・**保守性**・**拡張性**を重視したPowerShellベースの統合管理システムです。

#### 🏗️ 設計原則
- 🧩 **モジュラー設計**: 機能ごとの独立性確保
- 🔄 **後方互換性**: PowerShell 5.1-7.x対応
- 🛡️ **エラーハンドリング**: 堅牢な例外処理
- 🔐 **セキュリティファースト**: セキュアコーディング実践
- 📊 **監査対応**: 包括的なログ記録

#### 🎨 アーキテクチャパターン
```
📦 レイヤードアーキテクチャ（4層構成）
├── 🎨 プレゼンテーション層（UI）
├── 🧠 ビジネスロジック層
├── 🌐 データアクセス層
└── 🖥️ インフラストラクチャ層
```

---

## 🛠️ 開発環境セットアップ

### 📋 必要ツール・環境
```powershell
# 必須開発環境
✅ PowerShell 5.1+ または PowerShell 7+
✅ Visual Studio Code + PowerShell Extension
✅ Git for Windows
✅ Microsoft Graph PowerShell SDK
✅ Exchange Online Management Module

# 推奨追加ツール
📦 PSScriptAnalyzer（コード解析）
📦 Pester（テストフレームワーク）
📦 platyPS（ドキュメント生成）
📦 PSReadLine（コマンドライン拡張）
```

### ⚡ 開発環境構築手順
```powershell
# 1. PowerShell実行ポリシー設定
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. 必須モジュールインストール
$requiredModules = @(
    "Microsoft.Graph",
    "ExchangeOnlineManagement", 
    "Microsoft.PowerShell.ConsoleGuiTools",
    "PSScriptAnalyzer",
    "Pester",
    "platyPS"
)

foreach ($module in $requiredModules) {
    Install-Module $module -Force -Scope CurrentUser
    Write-Host "✅ $module インストール完了"
}

# 3. 開発用設定ファイル作成
Copy-Item "Config\appsettings.json" "Config\appsettings.development.json"
```

### 📁 プロジェクト構造理解
```
MicrosoftProductManagementTools/
├── 📄 Start-ManagementTools.ps1        # 🚀 メインエントリーポイント
├── 📁 Scripts/
│   ├── 📁 UI/                          # 🎨 ユーザーインターフェース層
│   │   ├── MenuEngine.psm1             # 🤖 メニューエンジン基盤
│   │   ├── CLIMenu.psm1                # 🔧 CLI メニューシステム
│   │   ├── ConsoleGUIMenu.psm1         # 🎯 ConsoleGUI メニューシステム
│   │   └── EncodingManager.psm1        # 🔤 文字エンコーディング管理
│   ├── 📁 Common/                      # 🛠️ 共通機能層
│   │   ├── VersionDetection.psm1       # 🔍 PowerShell環境検出
│   │   ├── MenuConfig.psm1             # 📋 設定ベースメニュー管理
│   │   ├── Logging.psm1                # 📝 ログ管理システム
│   │   ├── ErrorHandling.psm1          # ⚠️ エラーハンドリング
│   │   └── Authentication.psm1         # 🔐 認証統合管理
│   └── 📁 [AD|EXO|EntraID]/            # 💼 機能別実装層
└── 📁 Tests/                           # 🧪 テストコード
    ├── Unit/                           # ユニットテスト
    ├── Integration/                    # 統合テスト
    └── E2E/                           # エンドツーエンドテスト
```

---

## 🔧 コーディング規約・ベストプラクティス

### 📝 PowerShell コーディング標準

#### 🎯 命名規則
```powershell
# ✅ 推奨命名パターン
# 関数: 動詞-名詞パターン（Pascal Case）
function Get-UserLicenseInfo { }
function Set-MailboxQuota { }
function Test-GraphConnection { }

# 変数: camelCase
$userPrincipalName = "user@contoso.com"
$mailboxStatistics = @()

# 定数: UPPER_SNAKE_CASE
$GRAPH_API_VERSION = "v1.0"
$MAX_RETRY_COUNT = 5

# ファイル名: PascalCase.psm1
# MenuEngine.psm1, VersionDetection.psm1
```

#### 📋 関数設計パターン
```powershell
# ✅ 標準関数テンプレート
function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParameter,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$OptionalParameter = 10,
        
        [switch]$EnableVerboseOutput
    )
    
    begin {
        Write-Log "関数開始: $($MyInvocation.MyCommand.Name)" "Info"
        
        # 前提条件チェック
        if (-not (Test-Prerequisites)) {
            throw "前提条件が満たされていません"
        }
    }
    
    process {
        try {
            # メイン処理
            $result = Invoke-MainLogic -Parameter $RequiredParameter
            
            # 結果検証
            if ($null -eq $result) {
                Write-Warning "処理結果が空です"
                return $null
            }
            
            return $result
        }
        catch {
            Write-Log "エラー発生: $($_.Exception.Message)" "Error"
            Handle-Error -ErrorRecord $_ -Context $MyInvocation.MyCommand.Name
            throw
        }
    }
    
    end {
        Write-Log "関数終了: $($MyInvocation.MyCommand.Name)" "Info"
    }
}
```

#### 🛡️ エラーハンドリングパターン
```powershell
# ✅ 推奨エラーハンドリング
function Invoke-SafeAPICall {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )
    
    $attempt = 0
    do {
        try {
            $attempt++
            return & $ScriptBlock
        }
        catch {
            $errorMessage = $_.Exception.Message
            
            # リトライ可能なエラーかチェック
            if ($errorMessage -match "429|throttle|rate limit" -and $attempt -lt $MaxRetries) {
                $delay = $DelaySeconds * [Math]::Pow(2, $attempt - 1)
                Write-Warning "API制限検出。${delay}秒後にリトライします... (試行 $attempt/$MaxRetries)"
                Start-Sleep -Seconds $delay
                continue
            }
            
            # エラーログ記録
            Write-Log "API呼び出し失敗: $errorMessage (試行 $attempt)" "Error"
            
            # カスタムエラーオブジェクトを作成
            $errorDetails = [PSCustomObject]@{
                Message = $errorMessage
                AttemptCount = $attempt
                Timestamp = Get-Date
                ScriptBlock = $ScriptBlock.ToString()
            }
            
            throw [System.InvalidOperationException]::new(
                "API呼び出しが失敗しました: $errorMessage", 
                $_.Exception
            )
        }
    } while ($attempt -lt $MaxRetries)
}
```

### 🧪 テスト駆動開発

#### 📋 Pesterテスト作成
```powershell
# Tests/Unit/VersionDetection.Tests.ps1
Describe "VersionDetection Module Tests" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\..\Scripts\Common\VersionDetection.psm1" -Force
    }
    
    Context "Get-PowerShellVersionInfo" {
        It "Should return version information object" {
            # Arrange & Act
            $result = Get-PowerShellVersionInfo
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Version | Should -Not -BeNullOrEmpty
            $result.Edition | Should -BeIn @("Desktop", "Core")
            $result.SupportedMenuType | Should -BeIn @("CLI", "ConsoleGUI", "WPF")
        }
        
        It "Should detect PowerShell 7 correctly" {
            # Arrange
            Mock Get-Variable -ParameterFilter { $Name -eq "PSVersionTable" } -MockWith {
                @{ Value = @{ PSVersion = [Version]"7.2.0"; PSEdition = "Core" } }
            }
            
            # Act
            $result = Get-PowerShellVersionInfo
            
            # Assert
            $result.IsCore | Should -Be $true
            $result.SupportedMenuType | Should -Be "ConsoleGUI"
        }
    }
    
    Context "Test-PowerShellCompatibility" {
        It "Should validate minimum version requirement" {
            # Act & Assert
            { Test-PowerShellCompatibility -MinimumVersion "5.1" } | Should -Not -Throw
        }
        
        It "Should throw on unsupported version" {
            # Arrange
            Mock Get-Variable -MockWith {
                @{ Value = @{ PSVersion = [Version]"4.0" } }
            }
            
            # Act & Assert
            { Test-PowerShellCompatibility -MinimumVersion "5.1" } | Should -Throw
        }
    }
}
```

#### 🔄 継続的インテグレーション
```powershell
# Scripts/CI/RunTests.ps1
param(
    [string]$TestPath = "Tests",
    [string]$OutputFormat = "NUnitXml",
    [string]$OutputFile = "TestResults.xml"
)

# Pesterモジュール確認・インストール
if (-not (Get-Module -ListAvailable Pester)) {
    Install-Module Pester -Force -SkipPublisherCheck
}

# テスト実行設定
$config = [PesterConfiguration]::Default
$config.Run.Path = $TestPath
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = $OutputFormat
$config.TestResult.OutputPath = $OutputFile
$config.Output.Verbosity = "Detailed"

# テスト実行
$result = Invoke-Pester -Configuration $config

# 結果判定
if ($result.FailedCount -gt 0) {
    Write-Error "テストが失敗しました: $($result.FailedCount) 件"
    exit 1
}

Write-Host "✅ 全テストが成功しました: $($result.PassedCount) 件"
```

---

## 🔌 新機能開発ガイド

### 📦 新しいモジュール作成

#### 🛠️ モジュール作成テンプレート
```powershell
# Scripts/Template/NewModule.psm1
#Requires -Version 5.1

<#
.SYNOPSIS
    [モジュールの簡潔な説明]

.DESCRIPTION
    [モジュールの詳細な説明]

.NOTES
    Author: [開発者名]
    Created: [作成日]
    Version: 1.0.0
    Dependencies: [依存モジュール]
#>

# モジュール変数（プライベート）
$script:ModuleConfig = @{
    Version = "1.0.0"
    Name = "NewModule"
    Author = "Developer Name"
}

#region Public Functions

<#
.SYNOPSIS
    [関数の簡潔な説明]

.DESCRIPTION
    [関数の詳細な説明]

.PARAMETER ParameterName
    [パラメータの説明]

.EXAMPLE
    PS> FunctionName -ParameterName "Value"
    [使用例の説明]

.NOTES
    [追加の注意事項]
#>
function Public-Function {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )
    
    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] 開始"
    }
    
    process {
        try {
            # メイン処理
            $result = Invoke-PrivateFunction -InputData $ParameterName
            return $result
        }
        catch {
            Write-Error "[$($MyInvocation.MyCommand.Name)] エラー: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] 終了"
    }
}

#endregion

#region Private Functions

function Invoke-PrivateFunction {
    [CmdletBinding()]
    param(
        [string]$InputData
    )
    
    # プライベート関数の実装
    return "Processed: $InputData"
}

#endregion

#region Module Initialization

# モジュール初期化処理
Write-Verbose "[$($script:ModuleConfig.Name)] モジュール読み込み完了 (v$($script:ModuleConfig.Version))"

#endregion

# エクスポート（明示的に公開する関数のみ）
Export-ModuleMember -Function @(
    'Public-Function'
)
```

### 🎨 新しいUIタイプ追加

#### 🖼️ WPFメニュー実装例
```powershell
# Scripts/UI/WPFMenu.psm1
Add-Type -AssemblyName PresentationFramework

function Show-WPFMenu {
    [CmdletBinding()]
    param(
        [hashtable]$MenuConfig
    )
    
    # XAML定義
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Microsoft 365統合管理ツール" Height="600" Width="800"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- ヘッダー -->
        <StackPanel Grid.Row="0" Background="#0078d4" Margin="0,0,0,10">
            <TextBlock Text="Microsoft 365統合管理ツール" 
                       FontSize="20" FontWeight="Bold" 
                       Foreground="White" Margin="20,10"/>
        </StackPanel>
        
        <!-- メニューエリア -->
        <ScrollViewer Grid.Row="1" Margin="20">
            <StackPanel Name="MenuPanel">
                <!-- 動的にメニューアイテムを追加 -->
            </StackPanel>
        </ScrollViewer>
        
        <!-- ステータスバー -->
        <StatusBar Grid.Row="2">
            <StatusBarItem>
                <TextBlock Name="StatusText" Text="準備完了"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
'@
    
    # XAML読み込み
    $reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    # コントロール取得
    $menuPanel = $window.FindName("MenuPanel")
    $statusText = $window.FindName("StatusText")
    
    # メニューアイテム動的生成
    foreach ($category in $MenuConfig.Categories) {
        $expander = New-Object System.Windows.Controls.Expander
        $expander.Header = $category.Name
        $expander.IsExpanded = $true
        
        $stackPanel = New-Object System.Windows.Controls.StackPanel
        
        foreach ($task in $category.Tasks) {
            $button = New-Object System.Windows.Controls.Button
            $button.Content = $task.DisplayName
            $button.Margin = "5"
            $button.Padding = "10,5"
            $button.Tag = $task
            
            # クリックイベント
            $button.Add_Click({
                param($sender, $e)
                $selectedTask = $sender.Tag
                $statusText.Text = "実行中: $($selectedTask.DisplayName)"
                
                # タスク実行（非同期）
                $job = Start-Job -ScriptBlock {
                    param($Task)
                    & $Task.ScriptPath @Task.Parameters
                } -ArgumentList $selectedTask
                
                # 完了監視
                Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
                    if ($Event.Sender.State -eq "Completed") {
                        $statusText.Text = "完了: $($selectedTask.DisplayName)"
                        Unregister-Event $Event.SourceIdentifier
                    }
                }
            })
            
            $stackPanel.Children.Add($button)
        }
        
        $expander.Content = $stackPanel
        $menuPanel.Children.Add($expander)
    }
    
    # ウィンドウ表示
    $window.ShowDialog()
}
```

### 🔌 外部システム連携

#### 🌐 REST API連携テンプレート
```powershell
# Scripts/Integration/RestAPIClient.psm1
class RestAPIClient {
    [string]$BaseUrl
    [hashtable]$DefaultHeaders
    [int]$TimeoutSeconds
    
    RestAPIClient([string]$baseUrl) {
        $this.BaseUrl = $baseUrl.TrimEnd('/')
        $this.DefaultHeaders = @{
            'Content-Type' = 'application/json'
            'User-Agent' = 'Microsoft365-IntegratedManagement/1.0'
        }
        $this.TimeoutSeconds = 30
    }
    
    [object] InvokeRequest([string]$method, [string]$endpoint, [object]$body) {
        $uri = "$($this.BaseUrl)/$($endpoint.TrimStart('/'))"
        
        $requestParams = @{
            Uri = $uri
            Method = $method
            Headers = $this.DefaultHeaders
            TimeoutSec = $this.TimeoutSeconds
        }
        
        if ($body -and $method -in @('POST', 'PUT', 'PATCH')) {
            $requestParams.Body = $body | ConvertTo-Json -Depth 10
        }
        
        try {
            $response = Invoke-RestMethod @requestParams
            return $response
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode
                $statusDescription = $_.Exception.Response.StatusDescription
                $errorMessage = "HTTP $statusCode $statusDescription : $errorMessage"
            }
            
            throw [System.Exception]::new("API呼び出しエラー: $errorMessage", $_.Exception)
        }
    }
    
    [object] Get([string]$endpoint) {
        return $this.InvokeRequest('GET', $endpoint, $null)
    }
    
    [object] Post([string]$endpoint, [object]$body) {
        return $this.InvokeRequest('POST', $endpoint, $body)
    }
    
    [object] Put([string]$endpoint, [object]$body) {
        return $this.InvokeRequest('PUT', $endpoint, $body)
    }
    
    [object] Delete([string]$endpoint) {
        return $this.InvokeRequest('DELETE', $endpoint, $null)
    }
}

# 使用例
function Connect-CustomAPI {
    param(
        [string]$ApiBaseUrl,
        [string]$ApiKey
    )
    
    $client = [RestAPIClient]::new($ApiBaseUrl)
    $client.DefaultHeaders.Add('Authorization', "Bearer $ApiKey")
    
    return $client
}
```

---

## 📊 デバッグ・トラブルシューティング

### 🔍 デバッグ手法

#### 📝 高度なログ機能
```powershell
# Scripts/Common/AdvancedLogging.psm1
enum LogLevel {
    Trace = 0
    Debug = 1
    Info = 2
    Warning = 3
    Error = 4
    Critical = 5
}

class Logger {
    [string]$LogPath
    [LogLevel]$MinLevel
    [bool]$IncludeStackTrace
    
    Logger([string]$logPath, [LogLevel]$minLevel = [LogLevel]::Info) {
        $this.LogPath = $logPath
        $this.MinLevel = $minLevel
        $this.IncludeStackTrace = $false
        
        # ログディレクトリ作成
        $logDir = Split-Path $logPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force
        }
    }
    
    [void] WriteLog([LogLevel]$level, [string]$message, [hashtable]$properties = @{}) {
        if ($level -lt $this.MinLevel) {
            return
        }
        
        $logEntry = [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Level = $level.ToString()
            Message = $message
            Properties = $properties
            ProcessId = $PID
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        if ($this.IncludeStackTrace -and $level -ge [LogLevel]::Error) {
            $logEntry | Add-Member -NotePropertyName StackTrace -NotePropertyValue (Get-PSCallStack | Out-String)
        }
        
        # JSON形式でログ出力
        $jsonLog = $logEntry | ConvertTo-Json -Compress
        Add-Content -Path $this.LogPath -Value $jsonLog -Encoding UTF8
        
        # コンソール出力（色分け）
        $color = switch ($level) {
            ([LogLevel]::Trace) { 'Gray' }
            ([LogLevel]::Debug) { 'Cyan' }
            ([LogLevel]::Info) { 'White' }
            ([LogLevel]::Warning) { 'Yellow' }
            ([LogLevel]::Error) { 'Red' }
            ([LogLevel]::Critical) { 'Magenta' }
        }
        
        Write-Host "[$($logEntry.Timestamp)] [$($level.ToString().ToUpper())] $message" -ForegroundColor $color
    }
    
    [void] Trace([string]$message, [hashtable]$properties = @{}) {
        $this.WriteLog([LogLevel]::Trace, $message, $properties)
    }
    
    [void] Debug([string]$message, [hashtable]$properties = @{}) {
        $this.WriteLog([LogLevel]::Debug, $message, $properties)
    }
    
    [void] Info([string]$message, [hashtable]$properties = @{}) {
        $this.WriteLog([LogLevel]::Info, $message, $properties)
    }
    
    [void] Warning([string]$message, [hashtable]$properties = @{}) {
        $this.WriteLog([LogLevel]::Warning, $message, $properties)
    }
    
    [void] Error([string]$message, [hashtable]$properties = @{}) {
        $this.WriteLog([LogLevel]::Error, $message, $properties)
    }
    
    [void] Critical([string]$message, [hashtable]$properties = @{}) {
        $this.WriteLog([LogLevel]::Critical, $message, $properties)
    }
}

# グローバルロガー
$script:Logger = [Logger]::new("Logs\Development\Debug_$(Get-Date -Format 'yyyyMMdd').json", [LogLevel]::Debug)

function Get-Logger {
    return $script:Logger
}
```

#### 🧪 パフォーマンス測定
```powershell
# Scripts/Common/PerformanceProfiler.psm1
class PerformanceProfiler {
    [hashtable]$Timers = @{}
    [array]$Results = @()
    
    [void] StartTimer([string]$name) {
        $this.Timers[$name] = [System.Diagnostics.Stopwatch]::StartNew()
    }
    
    [void] StopTimer([string]$name) {
        if ($this.Timers.ContainsKey($name)) {
            $timer = $this.Timers[$name]
            $timer.Stop()
            
            $result = [PSCustomObject]@{
                Name = $name
                ElapsedMilliseconds = $timer.ElapsedMilliseconds
                ElapsedTicks = $timer.ElapsedTicks
                Timestamp = Get-Date
            }
            
            $this.Results += $result
            $this.Timers.Remove($name)
            
            Write-Verbose "⏱️ Performance: $name = $($timer.ElapsedMilliseconds)ms"
        }
    }
    
    [object] GetResults() {
        return $this.Results | Sort-Object ElapsedMilliseconds -Descending
    }
    
    [void] ExportResults([string]$path) {
        $this.Results | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    }
}

# パフォーマンス測定デコレータ
function Measure-Performance {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )
    
    $profiler = [PerformanceProfiler]::new()
    $profiler.StartTimer($Name)
    
    try {
        $result = & $ScriptBlock
        return $result
    }
    finally {
        $profiler.StopTimer($Name)
        $profiler.GetResults() | Format-Table -AutoSize
    }
}
```

---

## 🚀 デプロイメント・配布

### 📦 モジュール配布準備

#### 📋 マニフェスト作成
```powershell
# Microsoft365IntegratedManagement.psd1
@{
    RootModule = 'Microsoft365IntegratedManagement.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'IT Department'
    CompanyName = 'Contoso Corporation'
    Copyright = '(c) 2025 Contoso Corporation. All rights reserved.'
    Description = 'Microsoft 365統合管理ツール - エンタープライズ向け包括的管理システム'
    
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    
    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph'; ModuleVersion = '1.0.0' },
        @{ ModuleName = 'ExchangeOnlineManagement'; ModuleVersion = '2.0.0' }
    )
    
    FunctionsToExport = @(
        'Start-ManagementTools',
        'Get-SystemInfo',
        'Test-SystemHealth'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Microsoft365', 'Management', 'Enterprise', 'ITSM', 'Compliance')
            LicenseUri = 'https://github.com/company/microsoft365-tools/blob/main/LICENSE'
            ProjectUri = 'https://github.com/company/microsoft365-tools'
            ReleaseNotes = 'Initial release with PowerShell version detection and adaptive UI'
        }
    }
}
```

#### 🔧 インストールスクリプト
```powershell
# Scripts/Install/Install-Microsoft365Tools.ps1
[CmdletBinding()]
param(
    [string]$InstallPath = "$env:ProgramFiles\Microsoft365IntegratedManagement",
    [switch]$ForCurrentUser,
    [switch]$Force
)

Write-Host "🚀 Microsoft 365統合管理ツール インストーラー" -ForegroundColor Cyan

# 管理者権限チェック
if (-not $ForCurrentUser) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Error "システム全体へのインストールには管理者権限が必要です。-ForCurrentUser を使用するか、管理者として実行してください。"
        exit 1
    }
}

# インストールパス決定
if ($ForCurrentUser) {
    $InstallPath = "$env:USERPROFILE\Documents\PowerShell\Modules\Microsoft365IntegratedManagement"
}

# 既存インストールチェック
if (Test-Path $InstallPath -and -not $Force) {
    $response = Read-Host "既存のインストールが見つかりました。上書きしますか? (Y/N)"
    if ($response -ne 'Y') {
        Write-Host "インストールがキャンセルされました。"
        exit 0
    }
}

try {
    # インストールディレクトリ作成
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    # ファイルコピー
    $sourceFiles = @(
        "Start-ManagementTools.ps1",
        "Scripts\*",
        "Config\*",
        "Microsoft365IntegratedManagement.psd1"
    )

    foreach ($source in $sourceFiles) {
        $sourcePath = Join-Path $PSScriptRoot "..\..\$source"
        $targetPath = Join-Path $InstallPath (Split-Path $source -Leaf)
        
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $targetPath -Recurse -Force
            Write-Host "✅ コピー完了: $source"
        }
    }

    # 必要モジュールインストール
    $requiredModules = @(
        "Microsoft.Graph",
        "ExchangeOnlineManagement",
        "Microsoft.PowerShell.ConsoleGuiTools"
    )

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable $module)) {
            Write-Host "📦 インストール中: $module"
            Install-Module $module -Force -Scope $(if($ForCurrentUser){'CurrentUser'}else{'AllUsers'})
        }
    }

    # スタートメニューショートカット作成（システムインストールのみ）
    if (-not $ForCurrentUser) {
        $shortcutPath = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Microsoft 365統合管理ツール.lnk"
        $WScriptShell = New-Object -ComObject WScript.Shell
        $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-File `"$InstallPath\Start-ManagementTools.ps1`""
        $shortcut.WorkingDirectory = $InstallPath
        $shortcut.Description = "Microsoft 365統合管理ツール"
        $shortcut.Save()
    }

    Write-Host "🎉 インストール完了!" -ForegroundColor Green
    Write-Host "インストール場所: $InstallPath"
    Write-Host "使用方法: . '$InstallPath\Start-ManagementTools.ps1'"

}
catch {
    Write-Error "インストール中にエラーが発生しました: $($_.Exception.Message)"
    exit 1
}
```

---

## 📚 リファレンス・参考資料

### 🔗 Microsoft Graph API リファレンス
- 📊 [Microsoft Graph REST API v1.0](https://docs.microsoft.com/en-us/graph/api/overview)
- 🎫 [Microsoft Graph PowerShell SDK](https://docs.microsoft.com/en-us/powershell/microsoftgraph/)
- 📧 [Exchange Online PowerShell](https://docs.microsoft.com/en-us/powershell/exchange/)

### 🛠️ PowerShell開発リソース
- 📝 [PowerShell Style Guide](https://github.com/PoshCode/PowerShellPracticeAndStyle)
- 🧪 [Pester Testing Framework](https://pester.dev/)
- 📊 [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)

### 📋 設計パターン・アーキテクチャ
- 🏗️ [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- 📦 [PowerShell Module Design](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/writing-a-windows-powershell-module)

---

**💻 効率的な開発とメンテナンスで、高品質なMicrosoft 365管理ツールを構築しましょう！**

---

*📅 最終更新: 2025年6月 | 💻 開発者向けガイド v1.0*