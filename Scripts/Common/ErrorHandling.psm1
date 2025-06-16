# ================================================================================
# ErrorHandling.psm1
# エラーハンドリング・通知・再試行モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force

function Get-ErrorDetails {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    $errorType = "Unknown"
    $isNetworkError = $false
    
    # ネットワーク関連エラーの検出
    if ($ErrorRecord.Exception.Message -match "Connection reset by peer|The operation has timed out|A connection attempt failed|The remote name could not be resolved") {
        $errorType = "NetworkError"
        $isNetworkError = $true
    }
    elseif ($ErrorRecord.Exception.Message -match "401|Unauthorized|Authentication failed") {
        $errorType = "AuthenticationError"
    }
    elseif ($ErrorRecord.Exception.Message -match "403|Forbidden|Access denied") {
        $errorType = "AuthorizationError"
    }
    elseif ($ErrorRecord.Exception.Message -match "429|Too Many Requests|Rate limit") {
        $errorType = "RateLimitError"
    }
    
    return @{
        Message = $ErrorRecord.Exception.Message
        StackTrace = $ErrorRecord.ScriptStackTrace
        ScriptName = $ErrorRecord.InvocationInfo.ScriptName
        LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
        CommandName = $ErrorRecord.InvocationInfo.MyCommand.Name
        Timestamp = Get-Date
        Category = $ErrorRecord.CategoryInfo.Category
        FullyQualifiedErrorId = $ErrorRecord.FullyQualifiedErrorId
        ErrorType = $errorType
        IsNetworkError = $isNetworkError
    }
}

function Send-ErrorNotification {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ErrorDetails
    )
    
    $errorMessage = @"
Microsoft製品運用管理ツール - エラー通知

時刻: $($ErrorDetails.Timestamp)
スクリプト: $($ErrorDetails.ScriptName)
行番号: $($ErrorDetails.LineNumber)
コマンド: $($ErrorDetails.CommandName)
エラーメッセージ: $($ErrorDetails.Message)
カテゴリ: $($ErrorDetails.Category)

スタックトレース:
$($ErrorDetails.StackTrace)
"@

    # ログに記録
    Write-Log "エラー通知送信: $($ErrorDetails.Message)" -Level "Error"
    
    # コンソール出力
    Write-Host $errorMessage -ForegroundColor Red
    
    # 監査ログに記録
    Write-AuditLog -Action "エラー発生" -Target $ErrorDetails.ScriptName -Result "失敗" -Details $ErrorDetails.Message
}

function Invoke-RetryLogic {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$DelaySeconds = 5,
        
        [Parameter(Mandatory = $false)]
        [string]$Operation = "処理"
    )
    
    $attempt = 0
    $lastError = $null
    
    do {
        $attempt++
        
        try {
            Write-Log "$Operation を実行中 (試行回数: $attempt)" -Level "Info"
            $result = & $ScriptBlock
            Write-Log "$Operation が成功しました (試行回数: $attempt)" -Level "Info"
            return $result
        }
        catch {
            $lastError = $_
            $errorDetails = Get-ErrorDetails -ErrorRecord $_
            
            Write-Log "$Operation でエラーが発生しました (試行回数: $attempt): $($_.Exception.Message)" -Level "Warning"
            
            if ($attempt -lt $MaxRetries) {
                # ネットワークエラーの場合は待機時間を延長
                $waitTime = if ($errorDetails.IsNetworkError) {
                    $DelaySeconds * [Math]::Pow(2, $attempt - 1)  # 指数バックオフ
                } else {
                    $DelaySeconds
                }
                
                Write-Log "$waitTime 秒後に再試行します..." -Level "Info"
                Start-Sleep -Seconds $waitTime
            }
            else {
                Write-Log "$Operation の最大再試行回数 ($MaxRetries) に達しました" -Level "Error"
                Send-ErrorNotification -ErrorDetails $errorDetails
                throw $lastError
            }
        }
    } while ($attempt -le $MaxRetries)
}

function Test-Prerequisites {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Prerequisites
    )
    
    $allPassed = $true
    $results = @()
    
    foreach ($prereq in $Prerequisites) {
        $result = @{
            Name = $prereq.Name
            Type = $prereq.Type
            Passed = $false
            Message = ""
        }
        
        try {
            switch ($prereq.Type) {
                "File" {
                    if (Test-Path $prereq.Path) {
                        $result.Passed = $true
                        $result.Message = "ファイルが存在します: $($prereq.Path)"
                    }
                    else {
                        $result.Message = "ファイルが見つかりません: $($prereq.Path)"
                        $allPassed = $false
                    }
                }
                "Directory" {
                    if (Test-Path $prereq.Path -PathType Container) {
                        $result.Passed = $true
                        $result.Message = "ディレクトリが存在します: $($prereq.Path)"
                    }
                    else {
                        $result.Message = "ディレクトリが見つかりません: $($prereq.Path)"
                        $allPassed = $false
                    }
                }
                "Module" {
                    if (Get-Module -Name $prereq.Name -ListAvailable) {
                        $result.Passed = $true
                        $result.Message = "モジュールが利用可能です: $($prereq.Name)"
                    }
                    else {
                        $result.Message = "モジュールが見つかりません: $($prereq.Name)"
                        $allPassed = $false
                    }
                }
                "Command" {
                    if (Get-Command $prereq.Name -ErrorAction SilentlyContinue) {
                        $result.Passed = $true
                        $result.Message = "コマンドが利用可能です: $($prereq.Name)"
                    }
                    else {
                        $result.Message = "コマンドが見つかりません: $($prereq.Name)"
                        $allPassed = $false
                    }
                }
                "Service" {
                    $service = Get-Service -Name $prereq.Name -ErrorAction SilentlyContinue
                    if ($service -and $service.Status -eq "Running") {
                        $result.Passed = $true
                        $result.Message = "サービスが実行中です: $($prereq.Name)"
                    }
                    else {
                        $result.Message = "サービスが実行されていません: $($prereq.Name)"
                        $allPassed = $false
                    }
                }
                "Script" {
                    $scriptResult = & $prereq.ScriptBlock
                    if ($scriptResult) {
                        $result.Passed = $true
                        $result.Message = "カスタムチェックが成功しました: $($prereq.Name)"
                    }
                    else {
                        $result.Message = "カスタムチェックが失敗しました: $($prereq.Name)"
                        $allPassed = $false
                    }
                }
            }
        }
        catch {
            $result.Message = "チェック実行エラー: $($_.Exception.Message)"
            $allPassed = $false
        }
        
        $results += $result
        
        if ($result.Passed) {
            Write-Log "前提条件チェック成功: $($result.Message)" -Level "Info"
        }
        else {
            Write-Log "前提条件チェック失敗: $($result.Message)" -Level "Warning"
        }
    }
    
    return @{
        AllPassed = $allPassed
        Results = $results
    }
}

function Disconnect-AllServices {
    try {
        Write-Log "全サービス接続を切断中..." -Level "Info"
        
        # Exchange Online切断
        if (Get-Command Disconnect-ExchangeOnline -ErrorAction SilentlyContinue) {
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Exchange Online接続を切断しました" -Level "Info"
        }
        
        # Microsoft Graph切断
        if (Get-Command Disconnect-MgGraph -ErrorAction SilentlyContinue) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue
            Write-Log "Microsoft Graph接続を切断しました" -Level "Info"
        }
        
        # Azure AD切断
        if (Get-Command Disconnect-AzureAD -ErrorAction SilentlyContinue) {
            Disconnect-AzureAD -ErrorAction SilentlyContinue
            Write-Log "Azure AD接続を切断しました" -Level "Info"
        }
        
        Write-Log "全サービス接続切断完了" -Level "Info"
    }
    catch {
        Write-Log "サービス切断エラー: $($_.Exception.Message)" -Level "Warning"
    }
}

function Invoke-SafeOperation {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [string]$OperationName = "操作",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,
        
        [Parameter(Mandatory = $false)]
        [hashtable[]]$Prerequisites = @()
    )
    
    try {
        # 前提条件チェック
        if ($Prerequisites.Count -gt 0) {
            Write-Log "$OperationName の前提条件をチェック中..." -Level "Info"
            $prereqResult = Test-Prerequisites -Prerequisites $Prerequisites
            
            if (-not $prereqResult.AllPassed) {
                $failedChecks = $prereqResult.Results | Where-Object { -not $_.Passed }
                $errorMessage = "前提条件チェックが失敗しました: $($failedChecks.Message -join ', ')"
                throw $errorMessage
            }
        }
        
        # タイムアウト付き実行
        Write-Log "$OperationName を開始します（タイムアウト: ${TimeoutSeconds}秒）" -Level "Info"
        
        $job = Start-Job -ScriptBlock $ScriptBlock
        $result = Wait-Job -Job $job -Timeout $TimeoutSeconds
        
        if ($result) {
            $output = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            
            Write-Log "$OperationName が正常に完了しました" -Level "Info"
            return $output
        }
        else {
            Stop-Job -Job $job -Force
            Remove-Job -Job $job -Force
            throw "操作がタイムアウトしました（${TimeoutSeconds}秒）"
        }
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "$OperationName でエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# エクスポート関数
Export-ModuleMember -Function Get-ErrorDetails, Send-ErrorNotification, Invoke-RetryLogic, Test-Prerequisites, Disconnect-AllServices, Invoke-SafeOperation