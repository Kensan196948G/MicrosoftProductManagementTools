# ================================================================================
# Setup-GitSyncScheduler.ps1
# Windowsタスクスケジューラーを使用したGit自動同期の設定
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$IntervalMinutes = 30,
    
    [Parameter(Mandatory = $false)]
    [string]$TaskName = "Microsoft365Tools-GitAutoSync",
    
    [Parameter(Mandatory = $false)]
    [string]$RepositoryPath = $null,
    
    [Parameter(Mandatory = $false)]
    [string]$Branch = "main",
    
    [Parameter(Mandatory = $false)]
    [switch]$Uninstall = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput = $false
)

# RepositoryPathの動的設定
if ([string]::IsNullOrEmpty($RepositoryPath)) {
    $RepositoryPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Write-Host "📂 RepositoryPathを動的に設定: $RepositoryPath" -ForegroundColor Cyan
}

# 管理者権限チェック
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ログ出力関数
function Write-SchedulerLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
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
    
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

# 既存のタスクを削除
function Remove-ExistingTask {
    param([string]$TaskName)
    
    try {
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        
        if ($existingTask) {
            Write-SchedulerLog "既存のタスクを削除しています: $TaskName" -Level "Warning"
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-SchedulerLog "既存のタスクを削除しました" -Level "Success"
        }
    }
    catch {
        Write-SchedulerLog "既存のタスクの削除に失敗しました: $($_.Exception.Message)" -Level "Error"
    }
}

# Git同期実行スクリプトを作成
function New-GitSyncScript {
    param(
        [string]$RepositoryPath,
        [string]$Branch
    )
    
    $scriptPath = Join-Path $RepositoryPath "Scripts\Common\Execute-GitSync.ps1"
    
    $scriptContent = @"
# ================================================================================
# Execute-GitSync.ps1
# タスクスケジューラー用Git同期実行スクリプト
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = `$false)]
    [string]`$RepositoryPath = "$RepositoryPath",
    
    [Parameter(Mandatory = `$false)]
    [string]`$Branch = "$Branch",
    
    [Parameter(Mandatory = `$false)]
    [switch]`$VerboseOutput = `$false
)

# スクリプトルートパス
`$Script:ToolRoot = "$RepositoryPath"

# ログファイルパス
`$logPath = Join-Path `$Script:ToolRoot "Logs\git-sync.log"

# ログディレクトリを作成
`$logDir = Split-Path `$logPath -Parent
if (-not (Test-Path `$logDir)) {
    New-Item -Path `$logDir -ItemType Directory -Force | Out-Null
}

# ログ出力関数
function Write-SyncLog {
    param(
        [string]`$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]`$Level = "Info"
    )
    
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logEntry = "[`$timestamp] [`$Level] `$Message"
    
    # ファイルとコンソールの両方に出力
    Add-Content -Path `$logPath -Value `$logEntry
    
    `$color = switch (`$Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    Write-Host `$logEntry -ForegroundColor `$color
}

# メイン実行
try {
    Write-SyncLog "Git自動同期を開始します..." -Level "Info"
    Write-SyncLog "リポジトリパス: `$RepositoryPath" -Level "Info"
    Write-SyncLog "ブランチ: `$Branch" -Level "Info"
    
    # 作業ディレクトリを変更
    Set-Location `$RepositoryPath
    
    # GitSyncManagerモジュールをインポート
    `$gitSyncModulePath = Join-Path `$Script:ToolRoot "Scripts\Common\GitSyncManager.psm1"
    Import-Module `$gitSyncModulePath -Force
    
    # セキュアGit同期を実行
    `$syncResult = Invoke-SecureGitSync -RepositoryPath `$RepositoryPath -Branch `$Branch -Verbose:`$VerboseOutput
    
    if (`$syncResult.Success) {
        Write-SyncLog "Git自動同期が完了しました" -Level "Success"
        Write-SyncLog "コミットメッセージ: `$(`$syncResult.CommitMessage)" -Level "Info"
    } else {
        Write-SyncLog "Git自動同期に失敗しました: `$(`$syncResult.Error)" -Level "Error"
        exit 1
    }
}
catch {
    Write-SyncLog "Git自動同期でエラーが発生しました: `$(`$_.Exception.Message)" -Level "Error"
    exit 1
}
finally {
    Write-SyncLog "Git自動同期処理を終了します" -Level "Info"
}
"@
    
    try {
        $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
        Write-SchedulerLog "Git同期実行スクリプトを作成しました: $scriptPath" -Level "Success"
        return $scriptPath
    }
    catch {
        Write-SchedulerLog "Git同期実行スクリプトの作成に失敗しました: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# タスクスケジューラーに登録
function Register-GitSyncTask {
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [int]$IntervalMinutes
    )
    
    try {
        Write-SchedulerLog "タスクスケジューラーにタスクを登録しています..." -Level "Info"
        
        # タスクアクション（PowerShellスクリプトの実行）
        $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
        
        # タスクトリガー（指定間隔での実行）
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
        
        # タスク設定
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
        
        # タスクプリンシパル（システムアカウントで実行）
        $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        # タスクを登録
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Microsoft 365管理ツール - Git自動同期"
        
        Write-SchedulerLog "タスクスケジューラーにタスクを登録しました: $TaskName" -Level "Success"
        Write-SchedulerLog "実行間隔: $IntervalMinutes 分" -Level "Info"
        
        return $true
    }
    catch {
        Write-SchedulerLog "タスクスケジューラーへの登録に失敗しました: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# タスクの状態確認
function Get-TaskStatus {
    param([string]$TaskName)
    
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        
        Write-SchedulerLog "タスク状態:" -Level "Info"
        Write-SchedulerLog "  名前: $($task.TaskName)" -Level "Info"
        Write-SchedulerLog "  状態: $($task.State)" -Level "Info"
        Write-SchedulerLog "  最終実行: $($taskInfo.LastRunTime)" -Level "Info"
        Write-SchedulerLog "  次回実行: $($taskInfo.NextRunTime)" -Level "Info"
        Write-SchedulerLog "  最終結果: $($taskInfo.LastTaskResult)" -Level "Info"
        
        return @{
            TaskName = $task.TaskName
            State = $task.State
            LastRunTime = $taskInfo.LastRunTime
            NextRunTime = $taskInfo.NextRunTime
            LastTaskResult = $taskInfo.LastTaskResult
        }
    }
    catch {
        Write-SchedulerLog "タスク状態の取得に失敗しました: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

# メイン実行
function Main {
    Write-SchedulerLog "Git自動同期スケジューラーのセットアップを開始します..." -Level "Info"
    
    # 管理者権限チェック
    if (-not (Test-Administrator)) {
        Write-SchedulerLog "このスクリプトは管理者権限で実行する必要があります" -Level "Error"
        Write-SchedulerLog "PowerShellを管理者として実行してください" -Level "Error"
        exit 1
    }
    
    # アンインストールモード
    if ($Uninstall) {
        Write-SchedulerLog "Git自動同期タスクをアンインストールします..." -Level "Warning"
        Remove-ExistingTask -TaskName $TaskName
        Write-SchedulerLog "アンインストールが完了しました" -Level "Success"
        return
    }
    
    # リポジトリパスの確認
    if (-not (Test-Path $RepositoryPath)) {
        Write-SchedulerLog "リポジトリパスが見つかりません: $RepositoryPath" -Level "Error"
        exit 1
    }
    
    # .gitディレクトリの確認
    $gitDir = Join-Path $RepositoryPath ".git"
    if (-not (Test-Path $gitDir)) {
        Write-SchedulerLog "指定されたパスはGitリポジトリではありません: $RepositoryPath" -Level "Error"
        exit 1
    }
    
    # 既存のタスクを削除
    Remove-ExistingTask -TaskName $TaskName
    
    # 既存のGit同期実行スクリプトを使用（最新版）
    $scriptPath = Join-Path $RepositoryPath "Scripts\Common\Execute-GitSync.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-SchedulerLog "Git同期実行スクリプトが見つかりません: $scriptPath" -Level "Error"
        exit 1
    }
    
    # タスクスケジューラーに登録
    Register-GitSyncTask -TaskName $TaskName -ScriptPath $scriptPath -IntervalMinutes $IntervalMinutes
    
    # タスクの状態確認
    Start-Sleep -Seconds 2
    $taskStatus = Get-TaskStatus -TaskName $TaskName
    
    if ($taskStatus) {
        Write-SchedulerLog "Git自動同期スケジューラーのセットアップが完了しました" -Level "Success"
        Write-SchedulerLog "タスク名: $TaskName" -Level "Info"
        Write-SchedulerLog "実行間隔: $IntervalMinutes 分" -Level "Info"
        Write-SchedulerLog "次回実行: $($taskStatus.NextRunTime)" -Level "Info"
        
        # 手動でタスクを開始
        try {
            Start-ScheduledTask -TaskName $TaskName
            Write-SchedulerLog "タスクを手動で開始しました" -Level "Success"
        }
        catch {
            Write-SchedulerLog "タスクの手動開始に失敗しました: $($_.Exception.Message)" -Level "Warning"
        }
    } else {
        Write-SchedulerLog "タスクの状態確認に失敗しました" -Level "Error"
        exit 1
    }
    
    # 使用方法の表示
    Write-SchedulerLog "使用方法:" -Level "Info"
    Write-SchedulerLog "  タスク状態確認: Get-ScheduledTask -TaskName '$TaskName'" -Level "Info"
    Write-SchedulerLog "  手動実行: Start-ScheduledTask -TaskName '$TaskName'" -Level "Info"
    Write-SchedulerLog "  タスク停止: Stop-ScheduledTask -TaskName '$TaskName'" -Level "Info"
    Write-SchedulerLog "  アンインストール: powershell -File `"$($MyInvocation.MyCommand.Path)`" -Uninstall" -Level "Info"
}

# スクリプト実行
Main