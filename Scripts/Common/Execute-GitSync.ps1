# ================================================================================
# Execute-GitSync.ps1
# タスクスケジューラー用Git同期実行スクリプト
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryPath = "E:\MicrosoftProductManagementTools",
    
    [Parameter(Mandatory = $false)]
    [string]$Branch = "main",
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput = $false
)

# スクリプトルートパス
$Script:ToolRoot = "E:\MicrosoftProductManagementTools"

# ログファイルパス
$logPath = Join-Path $Script:ToolRoot "Logs\git-sync.log"

# ログディレクトリを作成
$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# ログ出力関数
function Write-SyncLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # ファイルとコンソールの両方に出力
    Add-Content -Path $logPath -Value $logEntry
    
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
}

# メイン実行
try {
    Write-SyncLog "Git自動同期を開始します..." -Level "Info"
    Write-SyncLog "リポジトリパス: $RepositoryPath" -Level "Info"
    Write-SyncLog "ブランチ: $Branch" -Level "Info"
    
    # 作業ディレクトリを変更
    Set-Location $RepositoryPath
    
    # GitSyncManagerモジュールをインポート
    $gitSyncModulePath = Join-Path $Script:ToolRoot "Scripts\Common\GitSyncManager.psm1"
    Import-Module $gitSyncModulePath -Force
    
    # セキュアGit同期を実行
    $syncResult = Invoke-SecureGitSync -RepositoryPath $RepositoryPath -Branch $Branch -VerboseOutput:$VerboseOutput
    
    if ($syncResult.Success) {
        Write-SyncLog "Git自動同期が完了しました" -Level "Success"
        Write-SyncLog "コミットメッセージ: $($syncResult.CommitMessage)" -Level "Info"
    } else {
        Write-SyncLog "Git自動同期に失敗しました: $($syncResult.Error)" -Level "Error"
        exit 1
    }
}
catch {
    Write-SyncLog "Git自動同期でエラーが発生しました: $($_.Exception.Message)" -Level "Error"
    exit 1
}
finally {
    Write-SyncLog "Git自動同期処理を終了します" -Level "Info"
}
