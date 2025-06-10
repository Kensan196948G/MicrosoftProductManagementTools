# ================================================================================
# UserManagement.ps1
# Active Directory ユーザー管理スクリプト
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-ADLoginHistory {
    # 模擬データ生成（実際の環境では Get-WinEvent 等を使用）
    $mockData = @(
        @{ User = "user1@domain.com"; Time = (Get-Date).AddHours(-2); Result = "成功"; IPAddress = "192.168.1.100" }
        @{ User = "user2@domain.com"; Time = (Get-Date).AddHours(-1); Result = "失敗"; IPAddress = "192.168.1.101" }
        @{ User = "user3@domain.com"; Time = (Get-Date).AddMinutes(-30); Result = "成功"; IPAddress = "192.168.1.102" }
        @{ User = "admin@domain.com"; Time = (Get-Date).AddMinutes(-15); Result = "失敗"; IPAddress = "192.168.1.103" }
        @{ User = "test@domain.com"; Time = (Get-Date).AddMinutes(-5); Result = "成功"; IPAddress = "192.168.1.104" }
    )
    
    Write-Host "ADログイン履歴を取得中... (模擬データ)" -ForegroundColor Yellow
    return $mockData
}

function Get-ADInactiveUsers {
    param(
        [Parameter(Mandatory = $false)]
        [int]$InactiveDays = 90,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "AD非アクティブユーザー検出" -Operation {
        Write-Log "非アクティブユーザーの検出を開始します（$InactiveDays 日間）" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ActiveDirectory")
        
        $cutoffDate = (Get-Date).AddDays(-$InactiveDays)
        
        $inactiveUsers = Get-ADUser -Filter {
            Enabled -eq $true -and 
            LastLogonDate -lt $cutoffDate
        } -Properties LastLogonDate, EmailAddress, Department, Manager | 
        Select-Object Name, SamAccountName, LastLogonDate, EmailAddress, Department, 
                      @{Name="ManagerName"; Expression={(Get-ADUser $_.Manager -ErrorAction SilentlyContinue).Name}},
                      @{Name="InactiveDays"; Expression={((Get-Date) - $_.LastLogonDate).Days}}
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "ADInactiveUsers_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $inactiveUsers -FilePath $outputFile
        
        Write-AuditLog -Action "非アクティブユーザー検出" -Target "全ADユーザー" -Result "成功" -Details "$($inactiveUsers.Count)件の非アクティブユーザーを検出"
        
        return $inactiveUsers
    }
}

function Get-ADPasswordExpiryReport {
    param(
        [Parameter(Mandatory = $false)]
        [int]$WarningDays = 14,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "ADパスワード有効期限チェック" -Operation {
        Write-Log "パスワード有効期限チェックを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ActiveDirectory")
        
        $domain = Get-ADDomain
        $maxPasswordAge = $domain.MaxPasswordAge.Days
        
        if ($maxPasswordAge -eq 0) {
            Write-Log "パスワードの有効期限が設定されていません" -Level "Warning"
            return @()
        }
        
        $warningDate = (Get-Date).AddDays($WarningDays)
        
        $users = Get-ADUser -Filter {
            Enabled -eq $true -and 
            PasswordNeverExpires -eq $false
        } -Properties PasswordLastSet, EmailAddress, Department | 
        ForEach-Object {
            $expiryDate = $_.PasswordLastSet.AddDays($maxPasswordAge)
            
            if ($expiryDate -le $warningDate) {
                [PSCustomObject]@{
                    Name = $_.Name
                    SamAccountName = $_.SamAccountName
                    EmailAddress = $_.EmailAddress
                    Department = $_.Department
                    PasswordLastSet = $_.PasswordLastSet
                    ExpiryDate = $expiryDate
                    DaysUntilExpiry = ($expiryDate - (Get-Date)).Days
                    Status = if ($expiryDate -lt (Get-Date)) { "期限切れ" } else { "期限間近" }
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "ADPasswordExpiry_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $users -FilePath $outputFile
        
        Write-AuditLog -Action "パスワード有効期限チェック" -Target "全ADユーザー" -Result "成功" -Details "$($users.Count)件の対象ユーザーを検出"
        
        return $users
    }
}

function Get-ADUserAttributeChanges {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "ADユーザー属性変更履歴" -Operation {
        Write-Log "ユーザー属性変更履歴の取得を開始します（過去 $DaysBack 日間）" -Level "Info"
        
        $startDate = (Get-Date).AddDays(-$DaysBack)
        $results = @()
        
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4738, 4720, 4722, 4725, 4726
            StartTime = $startDate
        } -ErrorAction SilentlyContinue
        
        foreach ($event in $events) {
            $eventData = [xml]$event.ToXml()
            $targetUser = $eventData.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
            $subjectUser = $eventData.Event.EventData.Data | Where-Object { $_.Name -eq 'SubjectUserName' } | Select-Object -ExpandProperty '#text'
            
            $results += [PSCustomObject]@{
                DateTime = $event.TimeCreated
                EventID = $event.Id
                EventType = switch ($event.Id) {
                    4738 { "ユーザーアカウント変更" }
                    4720 { "ユーザーアカウント作成" }
                    4722 { "ユーザーアカウント有効化" }
                    4725 { "ユーザーアカウント無効化" }
                    4726 { "ユーザーアカウント削除" }
                }
                TargetUser = $targetUser
                ChangedBy = $subjectUser
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "ADUserChanges_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $results -FilePath $outputFile
        
        Write-AuditLog -Action "ユーザー属性変更履歴取得" -Target "全ADユーザー" -Result "成功" -Details "$($results.Count)件の変更を検出"
        
        return $results
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Active Directoryユーザー管理スクリプトを実行します" -Level "Info"
    
    try {
        Connect-ActiveDirectory
        
        Get-ADLoginHistory
        Get-ADInactiveUsers
        Get-ADPasswordExpiryReport
        Get-ADUserAttributeChanges
        
        Write-Log "Active Directoryユーザー管理スクリプトが正常に完了しました" -Level "Info"
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}