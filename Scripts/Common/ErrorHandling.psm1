# ================================================================================
# ErrorHandling.psm1
# Microsoft製品運用管理ツール - エラーハンドリング共通モジュール
# ITSM/ISO27001/27002準拠 - 最大7回の自律修復ループ
# ================================================================================

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 7,
        
        [Parameter(Mandatory = $false)]
        [int]$DelaySeconds = 5,
        
        [Parameter(Mandatory = $false)]
        [string]$OperationName = "Operation"
    )
    
    $attempt = 1
    
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log "実行開始: $OperationName (試行 $attempt/$MaxRetries)" -Level "Info"
            
            $result = & $ScriptBlock
            
            Write-Log "実行成功: $OperationName (試行 $attempt/$MaxRetries)" -Level "Info"
            return $result
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Log "実行エラー: $OperationName (試行 $attempt/$MaxRetries) - $errorMessage" -Level "Warning"
            
            if ($attempt -eq $MaxRetries) {
                Write-Log "最大試行回数に達しました: $OperationName" -Level "Error"
                throw $_
            }
            
            Write-Log "リトライまで $DelaySeconds 秒待機します" -Level "Info"
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

function Test-Prerequisites {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RequiredModules,
        
        [Parameter(Mandatory = $false)]
        [string[]]$RequiredCommands = @()
    )
    
    $issues = @()
    
    foreach ($module in $RequiredModules) {
        try {
            Import-Module $module -ErrorAction Stop -Force
            Write-Log "モジュール確認OK: $module" -Level "Debug"
        }
        catch {
            $issues += "必要なモジュールが見つかりません: $module"
            Write-Log "モジュール確認NG: $module" -Level "Error"
        }
    }
    
    foreach ($command in $RequiredCommands) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            $issues += "必要なコマンドが見つかりません: $command"
            Write-Log "コマンド確認NG: $command" -Level "Error"
        }
        else {
            Write-Log "コマンド確認OK: $command" -Level "Debug"
        }
    }
    
    if ($issues.Count -gt 0) {
        $issueList = $issues -join "`n"
        throw "前提条件チェックに失敗しました:`n$issueList"
    }
    
    Write-Log "前提条件チェック完了" -Level "Info"
    return $true
}

function Invoke-SafeOperation {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$CleanupOperation = {},
        
        [Parameter(Mandatory = $false)]
        [string]$OperationName = "SafeOperation",
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 7
    )
    
    try {
        return Invoke-WithRetry -ScriptBlock $Operation -MaxRetries $MaxRetries -OperationName $OperationName
    }
    catch {
        Write-Log "安全実行でエラーが発生しました: $OperationName - $($_.Exception.Message)" -Level "Error"
        
        try {
            Write-Log "クリーンアップ操作を実行します: $OperationName" -Level "Info"
            & $CleanupOperation
        }
        catch {
            Write-Log "クリーンアップ操作でエラーが発生しました: $($_.Exception.Message)" -Level "Warning"
        }
        
        throw $_
    }
}

function Get-ErrorDetails {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    $details = @{
        Message = $ErrorRecord.Exception.Message
        FullyQualifiedErrorId = $ErrorRecord.FullyQualifiedErrorId
        ScriptStackTrace = $ErrorRecord.ScriptStackTrace
        PositionMessage = $ErrorRecord.InvocationInfo.PositionMessage
        CategoryInfo = $ErrorRecord.CategoryInfo.ToString()
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    return $details
}

function Send-ErrorNotification {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorDetails,
        
        [Parameter(Mandatory = $false)]
        [string]$NotificationMethod = "Log"
    )
    
    $errorSummary = @"
エラー詳細:
時刻: $($ErrorDetails.Timestamp)
メッセージ: $($ErrorDetails.Message)
エラーID: $($ErrorDetails.FullyQualifiedErrorId)
カテゴリ: $($ErrorDetails.CategoryInfo)
位置: $($ErrorDetails.PositionMessage)
スタックトレース: $($ErrorDetails.ScriptStackTrace)
"@
    
    switch ($NotificationMethod) {
        "Log" {
            Write-Log $errorSummary -Level "Error"
        }
        "Email" {
            Write-Log "メール通知機能は未実装です" -Level "Warning"
        }
        "EventLog" {
            try {
                Write-EventLog -LogName Application -Source "Microsoft管理ツール" -EventId 1001 -EntryType Error -Message $errorSummary
            }
            catch {
                Write-Log "イベントログへの書き込みに失敗しました" -Level "Warning"
            }
        }
    }
}

Export-ModuleMember -Function Invoke-WithRetry, Test-Prerequisites, Invoke-SafeOperation, Get-ErrorDetails, Send-ErrorNotification