# ================================================================================
# GroupManagement.ps1
# Active Directory グループ管理スクリプト
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-ADGroupInventory {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "ADグループ棚卸" -Operation {
        Write-Log "ADグループの棚卸を開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ActiveDirectory")
        
        $groups = Get-ADGroup -Filter * -Properties Members, ManagedBy, Description, GroupCategory, GroupScope, WhenCreated, WhenChanged
        
        $groupReport = foreach ($group in $groups) {
            $memberCount = if ($group.Members) { $group.Members.Count } else { 0 }
            $manager = if ($group.ManagedBy) { 
                try { (Get-ADUser $group.ManagedBy -ErrorAction SilentlyContinue).Name } 
                catch { $group.ManagedBy }
            } else { "未設定" }
            
            [PSCustomObject]@{
                GroupName = $group.Name
                DistinguishedName = $group.DistinguishedName
                Description = $group.Description
                GroupCategory = $group.GroupCategory
                GroupScope = $group.GroupScope
                MemberCount = $memberCount
                ManagedBy = $manager
                WhenCreated = $group.WhenCreated
                WhenChanged = $group.WhenChanged
                DaysSinceCreated = if ($group.WhenCreated) { ((Get-Date) - $group.WhenCreated).Days } else { "不明" }
                DaysSinceChanged = if ($group.WhenChanged) { ((Get-Date) - $group.WhenChanged).Days } else { "不明" }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "ADGroupInventory_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $groupReport -FilePath $outputFile
        
        Write-AuditLog -Action "ADグループ棚卸" -Target "全ADグループ" -Result "成功" -Details "$($groupReport.Count)件のグループを棚卸"
        
        return $groupReport
    }
}

function Get-ADGroupMembershipReport {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$GroupNames = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "ADグループメンバーシップレポート" -Operation {
        Write-Log "ADグループメンバーシップレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ActiveDirectory")
        
        if ($GroupNames.Count -eq 0) {
            $groups = Get-ADGroup -Filter * -Properties Members
        } else {
            $groups = $GroupNames | ForEach-Object { Get-ADGroup $_ -Properties Members -ErrorAction SilentlyContinue }
        }
        
        $membershipReport = foreach ($group in $groups) {
            if ($group.Members) {
                foreach ($memberDN in $group.Members) {
                    try {
                        $member = Get-ADObject $memberDN -Properties objectClass, Name, SamAccountName
                        
                        [PSCustomObject]@{
                            GroupName = $group.Name
                            GroupDN = $group.DistinguishedName
                            MemberName = $member.Name
                            MemberSamAccountName = if ($member.SamAccountName) { $member.SamAccountName } else { "N/A" }
                            MemberType = $member.objectClass
                            MemberDN = $member.DistinguishedName
                        }
                    }
                    catch {
                        Write-Log "メンバー情報の取得に失敗: $memberDN" -Level "Warning"
                        
                        [PSCustomObject]@{
                            GroupName = $group.Name
                            GroupDN = $group.DistinguishedName
                            MemberName = "取得エラー"
                            MemberSamAccountName = "N/A"
                            MemberType = "不明"
                            MemberDN = $memberDN
                        }
                    }
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "ADGroupMembership_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $membershipReport -FilePath $outputFile
        
        Write-AuditLog -Action "グループメンバーシップレポート" -Target "指定グループ" -Result "成功" -Details "$($membershipReport.Count)件のメンバーシップを報告"
        
        return $membershipReport
    }
}

function Get-ADEmptyGroups {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "AD空グループ検出" -Operation {
        Write-Log "空のADグループを検出します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ActiveDirectory")
        
        $emptyGroups = Get-ADGroup -Filter * -Properties Members, WhenCreated, WhenChanged | 
        Where-Object { 
            -not $_.Members -or $_.Members.Count -eq 0 
        } | 
        Select-Object Name, DistinguishedName, 
                      @{Name="DaysSinceCreated"; Expression={((Get-Date) - $_.WhenCreated).Days}},
                      @{Name="DaysSinceChanged"; Expression={((Get-Date) - $_.WhenChanged).Days}},
                      WhenCreated, WhenChanged
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "ADEmptyGroups_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $emptyGroups -FilePath $outputFile
        
        Write-AuditLog -Action "空グループ検出" -Target "全ADグループ" -Result "成功" -Details "$($emptyGroups.Count)件の空グループを検出"
        
        return $emptyGroups
    }
}

function Get-ADNestedGroupReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "ADネストグループレポート" -Operation {
        Write-Log "ネストしたADグループを分析します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ActiveDirectory")
        
        $nestedGroups = @()
        $allGroups = Get-ADGroup -Filter * -Properties Members
        
        foreach ($group in $allGroups) {
            if ($group.Members) {
                foreach ($memberDN in $group.Members) {
                    try {
                        $member = Get-ADObject $memberDN -Properties objectClass
                        
                        if ($member.objectClass -eq "group") {
                            $nestedGroups += [PSCustomObject]@{
                                ParentGroup = $group.Name
                                ParentGroupDN = $group.DistinguishedName
                                NestedGroup = $member.Name
                                NestedGroupDN = $member.DistinguishedName
                                NestingLevel = 1
                            }
                        }
                    }
                    catch {
                        Write-Log "ネストグループ分析エラー: $memberDN" -Level "Warning"
                    }
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "ADNestedGroups_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $nestedGroups -FilePath $outputFile
        
        Write-AuditLog -Action "ネストグループレポート" -Target "全ADグループ" -Result "成功" -Details "$($nestedGroups.Count)件のネスト関係を検出"
        
        return $nestedGroups
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Active Directoryグループ管理スクリプトを実行します" -Level "Info"
    
    try {
        Connect-ActiveDirectory
        
        Get-ADGroupInventory
        Get-ADGroupMembershipReport
        Get-ADEmptyGroups
        Get-ADNestedGroupReport
        
        Write-Log "Active Directoryグループ管理スクリプトが正常に完了しました" -Level "Info"
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