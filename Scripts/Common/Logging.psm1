# ================================================================================
# Logging.psm1
# Microsoft製品運用管理ツール - ログ共通モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

$global:LogPath = ""
$global:AuditLogPath = ""

function Initialize-Logging {
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogDirectory = "Logs"
    )
    
    $DateString = Get-Date -Format "yyyyMMdd"
    $LogDir = Join-Path $LogDirectory $DateString
    
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    $global:LogPath = Join-Path $LogDir "execution_$DateString.log"
    $global:AuditLogPath = Join-Path $LogDir "audit_$DateString.log"
    
    Write-Log "ログシステムを初期化しました" -Level "Info"
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [switch]$IsAudit
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    if ($IsAudit -and $global:AuditLogPath) {
        Add-Content -Path $global:AuditLogPath -Value $LogEntry -Encoding UTF8
    }
    elseif ($global:LogPath) {
        Add-Content -Path $global:LogPath -Value $LogEntry -Encoding UTF8
    }
    
    switch ($Level) {
        "Error" { Write-Host $LogEntry -ForegroundColor Red }
        "Warning" { Write-Host $LogEntry -ForegroundColor Yellow }
        "Debug" { if ($VerbosePreference -eq "Continue") { Write-Host $LogEntry -ForegroundColor Gray } }
        default { Write-Host $LogEntry -ForegroundColor White }
    }
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter(Mandatory = $false)]
        [string]$Result = "Success",
        
        [Parameter(Mandatory = $false)]
        [string]$Details = ""
    )
    
    $AuditMessage = "Action: $Action | Target: $Target | Result: $Result"
    if ($Details) {
        $AuditMessage += " | Details: $Details"
    }
    
    Write-Log -Message $AuditMessage -Level "Info" -IsAudit
}

function Get-LogFiles {
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogDirectory = "Logs",
        
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 30
    )
    
    $StartDate = (Get-Date).AddDays(-$DaysBack)
    
    Get-ChildItem -Path $LogDirectory -Recurse -Filter "*.log" | 
    Where-Object { $_.LastWriteTime -gt $StartDate } |
    Sort-Object LastWriteTime -Descending
}

function Export-LogsToArchive {
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogDirectory = "Logs",
        
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 365
    )
    
    try {
        $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $LogFiles = Get-ChildItem -Path $LogDirectory -Recurse -Filter "*.log" | 
                   Where-Object { $_.LastWriteTime -lt $CutoffDate }
        
        if ($LogFiles.Count -gt 0) {
            Compress-Archive -Path $LogFiles.FullName -DestinationPath $ArchivePath -Force
            Write-Log "ログファイルをアーカイブしました: $ArchivePath" -Level "Info"
            
            $LogFiles | Remove-Item -Force
            Write-Log "古いログファイルを削除しました" -Level "Info"
        }
        
        return $true
    }
    catch {
        Write-Log "ログアーカイブエラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

Export-ModuleMember -Function Initialize-Logging, Write-Log, Write-AuditLog, Get-LogFiles, Export-LogsToArchive