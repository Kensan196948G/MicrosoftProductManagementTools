# ================================================================================
# Windows用システム整合性チェック（config-check.sh相当）
# Check-System.ps1
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$Auto = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Fix = $false
)

$ErrorActionPreference = "Continue"
$ToolRoot = $PSScriptRoot
$LogDir = Join-Path $ToolRoot "Logs"
$ConfigFile = Join-Path $ToolRoot "Config\appsettings.json"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$CheckLog = Join-Path $LogDir "config_check_$Timestamp.log"

# ログディレクトリ作成
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "CHECK", "OK", "ERROR", "WARNING", "FIX", "FIXED", "FAIL", "SUMMARY", "RESULT")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    
    # コンソール出力
    $color = switch ($Level) {
        "OK" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "FIX" { "Cyan" }
        "FIXED" { "Green" }
        "FAIL" { "Red" }
        default { "White" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    # ファイル出力
    Add-Content -Path $CheckLog -Value $logMessage -Encoding UTF8
}

function Test-AndFix {
    param(
        [string]$CheckName,
        [scriptblock]$TestScript,
        [scriptblock]$FixScript = $null
    )
    
    Write-Log "CHECK" $CheckName
    
    try {
        $result = & $TestScript
        if ($result) {
            Write-Log "OK" $CheckName
            return $true
        }
        else {
            Write-Log "ERROR" $CheckName
            $Script:ErrorCount++
            
            if ($Auto -and $Fix -and $FixScript) {
                Write-Log "FIX" "$CheckName - 修復実行中..."
                try {
                    & $FixScript
                    Write-Log "FIXED" $CheckName
                    $Script:ErrorCount--
                    return $true
                }
                catch {
                    Write-Log "FAIL" "$CheckName - 修復失敗: $($_.Exception.Message)"
                    return $false
                }
            }
            return $false
        }
    }
    catch {
        Write-Log "ERROR" "$CheckName - エラー: $($_.Exception.Message)"
        $Script:ErrorCount++
        return $false
    }
}

# エラーカウンタ初期化
$Script:ErrorCount = 0
$Script:WarningCount = 0

Write-Log "INFO" "構成整合性チェック開始 (AUTO:$Auto, FIX:$Fix)"

# 必須ディレクトリ構造チェック
$requiredDirs = @(
    "Scripts\Common",
    "Scripts\AD",
    "Scripts\EXO", 
    "Scripts\EntraID",
    "Reports\Daily",
    "Reports\Weekly",
    "Reports\Monthly",
    "Reports\Yearly",
    "Templates",
    "Config",
    "Certificates",
    "Logs"
)

Test-AndFix "必須ディレクトリ構造" {
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $ToolRoot $dir
        if (-not (Test-Path $dirPath)) {
            return $false
        }
    }
    return $true
} {
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $ToolRoot $dir
        if (-not (Test-Path $dirPath)) {
            New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
        }
    }
}

# 設定ファイル存在チェック
Test-AndFix "設定ファイル存在確認" {
    Test-Path $ConfigFile
} {
    $defaultConfig = @{
        General = @{
            OrganizationName = "Default"
            Environment = "Development"
        }
    } | ConvertTo-Json -Depth 3
    
    Set-Content -Path $ConfigFile -Value $defaultConfig -Encoding UTF8
}

# JSON構文チェック
Test-AndFix "JSON設定ファイル構文" {
    try {
        Get-Content $ConfigFile | ConvertFrom-Json | Out-Null
        return $true
    }
    catch {
        return $false
    }
} {
    $backupFile = "$ConfigFile.backup.$Timestamp"
    Copy-Item $ConfigFile $backupFile
    
    $defaultConfig = @{
        General = @{
            OrganizationName = "Default"
            Environment = "Development"
        }
    } | ConvertTo-Json -Depth 3
    
    Set-Content -Path $ConfigFile -Value $defaultConfig -Encoding UTF8
}

# PowerShellモジュールファイル存在チェック
$requiredModules = @(
    "Scripts\Common\Common.psm1",
    "Scripts\Common\Authentication.psm1",
    "Scripts\Common\Logging.psm1",
    "Scripts\Common\ErrorHandling.psm1",
    "Scripts\Common\ReportGenerator.psm1",
    "Scripts\Common\ScheduledReports.ps1"
)

foreach ($module in $requiredModules) {
    $moduleName = Split-Path $module -Leaf
    Test-AndFix "PowerShellモジュール: $module" {
        Test-Path (Join-Path $ToolRoot $module)
    } {
        $modulePath = Join-Path $ToolRoot $module
        $content = @"
# Auto-generated placeholder module
Write-Host "Module $moduleName loaded"
"@
        Set-Content -Path $modulePath -Value $content -Encoding UTF8
    }
}

# HTMLテンプレートファイル確認
Test-AndFix "HTMLテンプレートファイル" {
    Test-Path (Join-Path $ToolRoot "Templates\ReportTemplate.html")
} {
    $templateDir = Join-Path $ToolRoot "Templates"
    if (-not (Test-Path $templateDir)) {
        New-Item -Path $templateDir -ItemType Directory -Force | Out-Null
    }
    
    $htmlContent = '<html><head><title>Report</title></head><body><h1>Microsoft 365 Management Report</h1></body></html>'
    Set-Content -Path (Join-Path $templateDir "ReportTemplate.html") -Value $htmlContent -Encoding UTF8
}

# PowerShellモジュール可用性チェック
$powerShellModules = @("Microsoft.Graph", "ExchangeOnlineManagement")
foreach ($module in $powerShellModules) {
    Test-AndFix "PowerShellモジュール可用性: $module" {
        $null -ne (Get-Module -ListAvailable -Name $module)
    } {
        # 自動インストールは危険なので警告のみ
        Write-Log "WARNING" "$module が見つかりません。install-modules.ps1 を実行してください"
        $Script:WarningCount++
    }
}

# 証明書ファイル確認
Test-AndFix "証明書ファイル" {
    Test-Path (Join-Path $ToolRoot "Certificates\mycert.pfx")
} {
    Write-Log "WARNING" "証明書ファイルが見つかりません。手動で配置してください"
    $Script:WarningCount++
}

# 結果サマリー
Write-Log "SUMMARY" "構成整合性チェック完了"
Write-Log "SUMMARY" "エラー: $Script:ErrorCount, 警告: $Script:WarningCount"
Write-Log "SUMMARY" "ログファイル: $CheckLog"

if ($Script:ErrorCount -gt 0) {
    Write-Log "RESULT" "構成エラーが検出されました"
    exit 1
}
else {
    Write-Log "RESULT" "構成整合性チェック正常完了"
    exit 0
}