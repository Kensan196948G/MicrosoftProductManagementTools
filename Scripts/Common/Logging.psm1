# ================================================================================
# Logging.psm1
# ログ記録・監査証跡モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

$LogDirectory = Join-Path $PSScriptRoot "..\..\Logs"
$AuditLogPath = Join-Path $LogDirectory "audit.log"
$SystemLogPath = Join-Path $LogDirectory "system.log"
$ErrorLogPath = Join-Path $LogDirectory "error.log"

# ログディレクトリ作成
if (-not (Test-Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Debug", "Success")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = $SystemLogPath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # コンソール出力（色付き）
    switch ($Level) {
        "Info" { Write-Host $logEntry -ForegroundColor Green }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error" { Write-Host $logEntry -ForegroundColor Red }
        "Debug" { Write-Host $logEntry -ForegroundColor Cyan }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # ファイル出力
    try {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -Force
    }
    catch {
        Write-Host "ログファイル書き込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("成功", "失敗", "警告")]
        [string]$Result,
        
        [Parameter(Mandatory = $false)]
        [string]$Details = "",
        
        [Parameter(Mandatory = $false)]
        [string]$User = $env:USERNAME
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $auditEntry = @{
        Timestamp = $timestamp
        User = $User
        Action = $Action
        Target = $Target
        Result = $Result
        Details = $Details
        SourceIP = try { (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } | Select-Object -First 1).IPAddress } catch { "不明" }
    }
    
    $auditJson = $auditEntry | ConvertTo-Json -Compress
    
    try {
        Add-Content -Path $AuditLogPath -Value $auditJson -Encoding UTF8 -Force
        Write-Log "監査ログ記録: $Action -> $Result" -Level "Info"
    }
    catch {
        Write-Log "監査ログ書き込みエラー: $($_.Exception.Message)" -Level "Error"
    }
}

function Get-LogFiles {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 30
    )
    
    $cutoffDate = (Get-Date).AddDays(-$DaysBack)
    
    try {
        return Get-ChildItem -Path $LogDirectory -Filter "*.log" | Where-Object { $_.LastWriteTime -ge $cutoffDate }
    }
    catch {
        Write-Log "ログファイル取得エラー: $($_.Exception.Message)" -Level "Error"
        return @()
    }
}

function Export-LogsToArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 365
    )
    
    try {
        $archiveDir = Split-Path $ArchivePath -Parent
        if (-not (Test-Path $archiveDir)) {
            New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null
        }
        
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $oldLogFiles = Get-ChildItem -Path $LogDirectory -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldLogFiles.Count -gt 0) {
            Compress-Archive -Path $oldLogFiles.FullName -DestinationPath $ArchivePath -CompressionLevel Optimal -Force
            
            # アーカイブ後に古いファイルを削除
            $oldLogFiles | Remove-Item -Force
            
            Write-AuditLog -Action "ログアーカイブ" -Target $ArchivePath -Result "成功" -Details "$($oldLogFiles.Count)個のログファイルをアーカイブしました"
        }
        else {
            Write-Log "アーカイブ対象のログファイルはありません" -Level "Info"
        }
    }
    catch {
        Write-Log "ログアーカイブエラー: $($_.Exception.Message)" -Level "Error"
        Write-AuditLog -Action "ログアーカイブ" -Target $ArchivePath -Result "失敗" -Details $_.Exception.Message
    }
}

function Clear-OldLogs {
    param(
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 90
    )
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $oldLogs = Get-ChildItem -Path $LogDirectory -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        $removedCount = 0
        foreach ($log in $oldLogs) {
            Remove-Item -Path $log.FullName -Force
            $removedCount++
        }
        
        if ($removedCount -gt 0) {
            Write-Log "$removedCount個の古いログファイルを削除しました" -Level "Info"
            Write-AuditLog -Action "ログクリーンアップ" -Target "ログディレクトリ" -Result "成功" -Details "$removedCount個のファイルを削除"
        }
    }
    catch {
        Write-Log "ログクリーンアップエラー: $($_.Exception.Message)" -Level "Error"
    }
}

# 初期化時にロガーを開始
Write-Log "ログシステムを初期化しました" -Level "Info"

# エクスポート関数
Export-ModuleMember -Function Write-Log, Write-AuditLog, Get-LogFiles, Export-LogsToArchive, Clear-OldLogs