# ================================================================================
# M365ErrorHandler.psm1
# Microsoft 365 統合エラーハンドリングモジュール
# Dev1 - Backend Developer による実装
# ================================================================================

# エラー分類と処理戦略
$Script:ErrorCategories = @{
    Authentication = @{
        Pattern = "authentication|authorization|forbidden|unauthorized|401|403|AADSTS"
        Action = "Reauthenticate"
        Retry = $false
        LogLevel = "ERROR"
    }
    RateLimit = @{
        Pattern = "429|throttle|rate limit|TooManyRequests|RequestThrottled"
        Action = "ExponentialBackoff"
        Retry = $true
        LogLevel = "WARNING"
    }
    ServiceUnavailable = @{
        Pattern = "Service unavailable|503|500|InternalServerError|ServiceNotAvailable"
        Action = "LinearBackoff"
        Retry = $true
        LogLevel = "WARNING"
    }
    Timeout = @{
        Pattern = "timeout|timed out|request timeout|OperationTimeout"
        Action = "ExtendedDelay"
        Retry = $true
        LogLevel = "WARNING"
    }
    NotFound = @{
        Pattern = "not found|404|ResourceNotFound|ItemNotFound"
        Action = "Skip"
        Retry = $false
        LogLevel = "INFO"
    }
    Permission = @{
        Pattern = "permission|access denied|insufficient|privilege"
        Action = "CheckPermissions"
        Retry = $false
        LogLevel = "ERROR"
    }
    NetworkError = @{
        Pattern = "network|connection|dns|socket"
        Action = "NetworkRetry"
        Retry = $true
        LogLevel = "WARNING"
    }
}

# エラー詳細情報の取得
function Get-M365ErrorDetails {
    <#
    .SYNOPSIS
    Microsoft 365 API エラーの詳細情報を取得
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    $errorDetails = @{
        Message = $ErrorRecord.Exception.Message
        Type = $ErrorRecord.Exception.GetType().FullName
        Category = "Unknown"
        Action = "None"
        Retry = $false
        StackTrace = $ErrorRecord.ScriptStackTrace
        Timestamp = Get-Date
        InnerException = $null
        ApiError = $null
    }
    
    # 内部例外の確認
    if ($ErrorRecord.Exception.InnerException) {
        $errorDetails.InnerException = $ErrorRecord.Exception.InnerException.Message
    }
    
    # API固有のエラー情報を抽出
    if ($ErrorRecord.Exception.Response) {
        try {
            $responseStream = $ErrorRecord.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($responseStream)
            $responseBody = $reader.ReadToEnd()
            $errorDetails.ApiError = $responseBody | ConvertFrom-Json
        }
        catch {
            # レスポンス本文の解析に失敗した場合は無視
        }
    }
    
    # エラーカテゴリの判定
    foreach ($category in $Script:ErrorCategories.GetEnumerator()) {
        if ($errorDetails.Message -match $category.Value.Pattern) {
            $errorDetails.Category = $category.Key
            $errorDetails.Action = $category.Value.Action
            $errorDetails.Retry = $category.Value.Retry
            break
        }
    }
    
    return $errorDetails
}

# 高度なリトライ戦略
function Invoke-M365RetryStrategy {
    <#
    .SYNOPSIS
    エラータイプに応じた適切なリトライ戦略を実行
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [string]$Operation = "M365 API Call",
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$BaseDelaySeconds = 2,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{}
    )
    
    $attempt = 0
    $lastError = $null
    
    do {
        try {
            $attempt++
            Write-Verbose "$Operation - 試行 $attempt/$MaxRetries"
            
            # コンテキストを含めて実行
            if ($Context.Count -gt 0) {
                $result = & $ScriptBlock @Context
            }
            else {
                $result = & $ScriptBlock
            }
            
            return @{
                Success = $true
                Result = $result
                Attempts = $attempt
                Error = $null
            }
        }
        catch {
            $lastError = $_
            $errorDetails = Get-M365ErrorDetails -ErrorRecord $_
            
            # ログ出力
            $logMessage = "$Operation エラー (試行 $attempt): $($errorDetails.Message)"
            if (Get-Command Write-ModuleLog -ErrorAction SilentlyContinue) {
                Write-ModuleLog $logMessage $errorDetails.Category
            }
            else {
                Write-Warning $logMessage
            }
            
            # リトライ不可能なエラーの場合は即座に失敗
            if (-not $errorDetails.Retry -or $attempt -ge $MaxRetries) {
                break
            }
            
            # エラータイプに応じた遅延戦略
            $delay = switch ($errorDetails.Action) {
                "ExponentialBackoff" {
                    # 指数バックオフ (2, 4, 8, 16秒...)
                    $BaseDelaySeconds * [Math]::Pow(2, $attempt - 1)
                }
                "LinearBackoff" {
                    # 線形バックオフ (2, 4, 6, 8秒...)
                    $BaseDelaySeconds * $attempt
                }
                "ExtendedDelay" {
                    # 拡張遅延（タイムアウトの場合）
                    $BaseDelaySeconds * 3 * $attempt
                }
                "NetworkRetry" {
                    # ネットワークエラーの場合の短い遅延
                    [Math]::Min($BaseDelaySeconds * $attempt, 10)
                }
                default {
                    $BaseDelaySeconds
                }
            }
            
            # API制限の場合、Retry-Afterヘッダーを確認
            if ($errorDetails.Category -eq "RateLimit" -and $_.Exception.Response.Headers) {
                $retryAfter = $_.Exception.Response.Headers["Retry-After"]
                if ($retryAfter) {
                    $delay = [int]$retryAfter
                }
            }
            
            Write-Verbose "$delay 秒後にリトライします..."
            Start-Sleep -Seconds $delay
        }
    } while ($attempt -lt $MaxRetries)
    
    # 最終的に失敗した場合
    return @{
        Success = $false
        Result = $null
        Attempts = $attempt
        Error = $lastError
        ErrorDetails = Get-M365ErrorDetails -ErrorRecord $lastError
    }
}

# エラー通知機能
function Send-M365ErrorNotification {
    <#
    .SYNOPSIS
    重要なエラーの通知を送信
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorDetails,
        
        [Parameter(Mandatory = $false)]
        [string]$Operation = "M365 Operation",
        
        [Parameter(Mandatory = $false)]
        [string[]]$NotificationChannels = @("Log", "Console")
    )
    
    $notification = @{
        Title = "Microsoft 365 API エラー"
        Operation = $Operation
        Category = $ErrorDetails.Category
        Message = $ErrorDetails.Message
        Timestamp = $ErrorDetails.Timestamp
        Action = $ErrorDetails.Action
        Severity = switch ($ErrorDetails.Category) {
            "Authentication" { "Critical" }
            "Permission" { "High" }
            "RateLimit" { "Medium" }
            "ServiceUnavailable" { "Medium" }
            default { "Low" }
        }
    }
    
    foreach ($channel in $NotificationChannels) {
        switch ($channel) {
            "Log" {
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log "$($notification.Title): $($notification.Message)" -Level "Error"
                }
            }
            "Console" {
                $color = switch ($notification.Severity) {
                    "Critical" { "Red" }
                    "High" { "DarkRed" }
                    "Medium" { "Yellow" }
                    default { "White" }
                }
                Write-Host "`n[$($notification.Severity)] $($notification.Title)" -ForegroundColor $color
                Write-Host "操作: $($notification.Operation)" -ForegroundColor $color
                Write-Host "エラー: $($notification.Message)" -ForegroundColor $color
                Write-Host "推奨アクション: $($notification.Action)`n" -ForegroundColor $color
            }
            "Email" {
                # メール通知の実装（必要に応じて）
            }
            "Teams" {
                # Teams通知の実装（必要に応じて）
            }
        }
    }
}

# バルクエラーハンドリング
function Handle-M365BulkErrors {
    <#
    .SYNOPSIS
    バルク操作でのエラーを集約して処理
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Errors,
        
        [Parameter(Mandatory = $false)]
        [string]$Operation = "Bulk Operation",
        
        [Parameter(Mandatory = $false)]
        [switch]$SummarizeOnly
    )
    
    if ($Errors.Count -eq 0) {
        return $null
    }
    
    # エラーをカテゴリ別に集計
    $errorSummary = @{}
    $criticalErrors = @()
    
    foreach ($error in $Errors) {
        $details = if ($error -is [hashtable]) { 
            $error 
        } else { 
            Get-M365ErrorDetails -ErrorRecord $error 
        }
        
        if (-not $errorSummary.ContainsKey($details.Category)) {
            $errorSummary[$details.Category] = @()
        }
        $errorSummary[$details.Category] += $details
        
        if ($details.Category -in @("Authentication", "Permission")) {
            $criticalErrors += $details
        }
    }
    
    # サマリーレポートの生成
    $report = @{
        Operation = $Operation
        TotalErrors = $Errors.Count
        Categories = @{}
        CriticalErrors = $criticalErrors
        Timestamp = Get-Date
        Recommendations = @()
    }
    
    foreach ($category in $errorSummary.Keys) {
        $report.Categories[$category] = @{
            Count = $errorSummary[$category].Count
            Samples = $errorSummary[$category] | Select-Object -First 3
        }
    }
    
    # 推奨事項の生成
    if ($errorSummary.ContainsKey("Authentication")) {
        $report.Recommendations += "認証情報を確認し、再認証を実行してください"
    }
    if ($errorSummary.ContainsKey("RateLimit")) {
        $report.Recommendations += "API呼び出し頻度を調整するか、バッチサイズを縮小してください"
    }
    if ($errorSummary.ContainsKey("Permission")) {
        $report.Recommendations += "必要なAPI権限が付与されているか確認してください"
    }
    
    # 詳細出力
    if (-not $SummarizeOnly) {
        Write-Host "`n========== エラーサマリー ==========" -ForegroundColor Yellow
        Write-Host "操作: $($report.Operation)" -ForegroundColor Yellow
        Write-Host "総エラー数: $($report.TotalErrors)" -ForegroundColor Yellow
        Write-Host "タイムスタンプ: $($report.Timestamp)" -ForegroundColor Yellow
        
        foreach ($category in $report.Categories.Keys) {
            Write-Host "`n[$category] $($report.Categories[$category].Count) 件" -ForegroundColor Cyan
            foreach ($sample in $report.Categories[$category].Samples) {
                Write-Host "  - $($sample.Message)" -ForegroundColor Gray
            }
        }
        
        if ($report.Recommendations.Count -gt 0) {
            Write-Host "`n推奨事項:" -ForegroundColor Green
            foreach ($rec in $report.Recommendations) {
                Write-Host "  • $rec" -ForegroundColor Green
            }
        }
        Write-Host "====================================`n" -ForegroundColor Yellow
    }
    
    return $report
}

# エクスポート
Export-ModuleMember -Function Get-M365ErrorDetails, Invoke-M365RetryStrategy, Send-M365ErrorNotification, Handle-M365BulkErrors