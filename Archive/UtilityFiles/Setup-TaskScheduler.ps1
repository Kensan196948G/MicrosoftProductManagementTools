# ================================================================================
# Setup-TaskScheduler.ps1
# Windows タスクスケジューラー自動設定
# Microsoft 365 管理ツール用
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$Remove = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Show = $false
)

$ErrorActionPreference = "Continue"

# 管理者権限チェック
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

# 設定読み込み
try {
    Import-Module "$PSScriptRoot\Scripts\Common\Common.psm1" -Force
    $config = Initialize-ManagementTools
}
catch {
    Write-Status "設定ファイル読み込みエラー: $($_.Exception.Message)" "Error"
    exit 1
}

# タスク定義
$tasks = @(
    @{
        Name = "Microsoft365-DailyReport"
        Description = "Microsoft 365 日次レポート生成"
        ScriptPath = Join-Path $PSScriptRoot "test-report-generation.ps1"
        Arguments = "-ReportType Daily"
        Schedule = @{
            Type = "Daily"
            Time = $config.Scheduling.DailyReportTime
        }
    },
    @{
        Name = "Microsoft365-WeeklyReport"
        Description = "Microsoft 365 週次レポート生成"
        ScriptPath = Join-Path $PSScriptRoot "test-report-generation.ps1"
        Arguments = "-ReportType Weekly"
        Schedule = @{
            Type = "Weekly"
            DayOfWeek = $config.Scheduling.WeeklyReportDay
            Time = $config.Scheduling.WeeklyReportTime
        }
    },
    @{
        Name = "Microsoft365-MonthlyReport"
        Description = "Microsoft 365 月次レポート生成"
        ScriptPath = Join-Path $PSScriptRoot "test-report-generation.ps1"
        Arguments = "-ReportType Monthly"
        Schedule = @{
            Type = "Monthly"
            Day = $config.Scheduling.MonthlyReportDay
            Time = $config.Scheduling.MonthlyReportTime
        }
    }
)

Write-Host @"
╔══════════════════════════════════════════════════════════════════════╗
║           Microsoft 365 管理ツール - タスクスケジューラー設定        ║
╚══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue

# 管理者権限確認
if (-not (Test-AdminRights)) {
    Write-Status "このスクリプトは管理者権限で実行する必要があります" "Error"
    Write-Status "PowerShellを管理者として実行し直してください" "Warning"
    exit 1
}

Write-Status "管理者権限で実行中" "Success"

if ($Show) {
    # 既存タスク表示
    Write-Host "`n=== 現在の Microsoft 365 タスク一覧 ===" -ForegroundColor Yellow
    
    foreach ($task in $tasks) {
        try {
            $existingTask = Get-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue
            if ($existingTask) {
                $taskInfo = Get-ScheduledTaskInfo -TaskName $task.Name
                Write-Status "タスク名: $($task.Name)" "Success"
                Write-Host "  説明: $($existingTask.Description)" -ForegroundColor Gray
                Write-Host "  状態: $($existingTask.State)" -ForegroundColor Gray
                Write-Host "  最終実行: $($taskInfo.LastRunTime)" -ForegroundColor Gray
                Write-Host "  次回実行: $($taskInfo.NextRunTime)" -ForegroundColor Gray
            }
            else {
                Write-Status "タスク名: $($task.Name) (未設定)" "Warning"
            }
        }
        catch {
            Write-Status "タスク確認エラー: $($task.Name)" "Error"
        }
    }
    exit 0
}

if ($Remove) {
    # タスク削除
    Write-Host "`n=== Microsoft 365 タスク削除 ===" -ForegroundColor Yellow
    
    foreach ($task in $tasks) {
        try {
            $existingTask = Get-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue
            if ($existingTask) {
                Unregister-ScheduledTask -TaskName $task.Name -Confirm:$false
                Write-Status "タスク削除完了: $($task.Name)" "Success"
            }
            else {
                Write-Status "タスクが存在しません: $($task.Name)" "Warning"
            }
        }
        catch {
            Write-Status "タスク削除エラー: $($task.Name) - $($_.Exception.Message)" "Error"
        }
    }
    exit 0
}

# タスク作成
Write-Host "`n=== Microsoft 365 タスクスケジューラー設定 ===" -ForegroundColor Yellow

foreach ($task in $tasks) {
    Write-Host "`n--- $($task.Name) ---" -ForegroundColor Cyan
    
    try {
        # 既存タスク確認
        $existingTask = Get-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Status "既存タスクを削除中..." "Warning"
            Unregister-ScheduledTask -TaskName $task.Name -Confirm:$false
        }
        
        # アクション定義
        $action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-ExecutionPolicy Bypass -File `"$($task.ScriptPath)`" $($task.Arguments)" -WorkingDirectory $PSScriptRoot
        
        # トリガー定義
        switch ($task.Schedule.Type) {
            "Daily" {
                $trigger = New-ScheduledTaskTrigger -Daily -At $task.Schedule.Time
                Write-Status "日次スケジュール: $($task.Schedule.Time)" "Info"
            }
            "Weekly" {
                $dayOfWeek = switch ($task.Schedule.DayOfWeek) {
                    "Monday" { "Monday" }
                    "Tuesday" { "Tuesday" }
                    "Wednesday" { "Wednesday" }
                    "Thursday" { "Thursday" }
                    "Friday" { "Friday" }
                    "Saturday" { "Saturday" }
                    "Sunday" { "Sunday" }
                    default { "Monday" }
                }
                $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dayOfWeek -At $task.Schedule.Time
                Write-Status "週次スケジュール: $dayOfWeek $($task.Schedule.Time)" "Info"
            }
            "Monthly" {
                # 月次トリガー：毎月1日に実行（簡易版）
                $trigger = New-ScheduledTaskTrigger -Daily -At $task.Schedule.Time
                # 実際は手動で月次スケジュールに変更する必要があります
                Write-Status "月次スケジュール: 毎月$($task.Schedule.Day)日 $($task.Schedule.Time) (要手動調整)" "Warning"
                Write-Status "タスクスケジューラーで手動で月次に変更してください" "Info"
            }
        }
        
        # 設定定義
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        # プリンシパル定義（最高権限で実行）
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        # タスク登録
        Register-ScheduledTask -TaskName $task.Name -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $task.Description
        
        Write-Status "タスク作成完了: $($task.Name)" "Success"
        
    }
    catch {
        Write-Status "タスク作成エラー: $($task.Name) - $($_.Exception.Message)" "Error"
    }
}

Write-Host "`n=== 設定完了 ===" -ForegroundColor Green
Write-Status "Windows タスクスケジューラーに Microsoft 365 管理タスクを登録しました" "Success"
Write-Status "タスクスケジューラー (taskschd.msc) で確認できます" "Info"

Write-Host "`n=== 使用方法 ===" -ForegroundColor Yellow
Write-Host "タスク確認: .\Setup-TaskScheduler.ps1 -Show"
Write-Host "タスク削除: .\Setup-TaskScheduler.ps1 -Remove"
Write-Host "手動実行: Start-ScheduledTask -TaskName 'Microsoft365-DailyReport'"