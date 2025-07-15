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

# ログファイルパス（YYYYMMDDHHMM形式でローテーション）
$timestamp = Get-Date -Format "yyyyMMddHHmm"
$logPath = Join-Path $Script:ToolRoot "Logs\git-sync_$timestamp.log"
$masterLogPath = Join-Path $Script:ToolRoot "Logs\git-sync.log"

# ログディレクトリを作成
$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# 古いログファイルのクリーンアップ（30日以上経過したファイルを削除）
try {
    $cutoffDate = (Get-Date).AddDays(-30)
    Get-ChildItem -Path $logDir -Filter "git-sync_*.log" | Where-Object { 
        $_.LastWriteTime -lt $cutoffDate 
    } | Remove-Item -Force -ErrorAction SilentlyContinue
} catch {
    # クリーンアップエラーは無視
}

# ログ出力関数（タイムスタンプ付きローテーション対応）
function Write-SyncLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$logTimestamp] [$Level] $Message"
    
    # タイムスタンプ付きログファイルに出力
    Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    
    # マスターログファイルにも出力（後方互換性）
    Add-Content -Path $masterLogPath -Value $logEntry -Encoding UTF8
    
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
    # セッション開始ログ
    Write-SyncLog "=================================================" -Level "Info"
    Write-SyncLog "Git自動同期セッション開始 [$timestamp]" -Level "Info"
    Write-SyncLog "=================================================" -Level "Info"
    Write-SyncLog "リポジトリパス: $RepositoryPath" -Level "Info"
    Write-SyncLog "ブランチ: $Branch" -Level "Info"
    Write-SyncLog "ログファイル: git-sync_$timestamp.log" -Level "Info"
    
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
    $endTimestamp = Get-Date -Format "yyyyMMddHHmm"
    Write-SyncLog "=================================================" -Level "Info"
    Write-SyncLog "Git自動同期セッション終了 [$endTimestamp]" -Level "Info"
    Write-SyncLog "=================================================" -Level "Info"
}
