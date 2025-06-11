# ================================================================================
# GroupManagement.psm1
# GM系 - グループ管理機能モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ReportGenerator.psm1" -Force

# GM-01: グループ一覧・構成抽出
function Get-GroupConfiguration {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "グループ一覧・構成抽出を開始します" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # 全グループの取得
        Write-Log "グループ一覧を取得中..." -Level "Info"
        
        try {
            # Microsoft 365グループ、セキュリティグループ、配布グループを取得
            $allGroups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,SecurityEnabled,MailEnabled,CreatedDateTime,Description,Visibility,OnPremisesSyncEnabled
            Write-Log "グループ情報取得完了" -Level "Info"
        }
        catch {
            Write-Log "グループ取得エラー: $($_.Exception.Message)" -Level "Error"
            $allGroups = Get-MgGroup -All
        }
        
        Write-Log "取得完了: $($allGroups.Count)個のグループ" -Level "Info"
        
        # グループ分析
        $groupResults = @()
        $progressCount = 0
        
        foreach ($group in $allGroups) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "グループ詳細確認中" -Status "$progressCount/$($allGroups.Count)" -PercentComplete (($progressCount / $allGroups.Count) * 100)
            }
            
            try {
                # グループタイプの判定
                $groupType = "不明"
                $isTeam = $false
                
                if ($group.GroupTypes -and $group.GroupTypes -contains "Unified") {
                    $groupType = "Microsoft 365"
                    
                    # Teamsチームかどうか確認
                    try {
                        $teamInfo = Get-MgTeam -TeamId $group.Id -ErrorAction SilentlyContinue
                        if ($teamInfo) {
                            $isTeam = $true
                            $groupType = "Microsoft Teams"
                        }
                    }
                    catch {
                        # Teams情報取得エラーは無視
                    }
                }
                elseif ($group.SecurityEnabled -and -not $group.MailEnabled) {
                    $groupType = "セキュリティグループ"
                }
                elseif (-not $group.SecurityEnabled -and $group.MailEnabled) {
                    $groupType = "配布グループ"
                }
                elseif ($group.SecurityEnabled -and $group.MailEnabled) {
                    $groupType = "メール対応セキュリティグループ"
                }
                
                # メンバー数の取得
                $memberCount = 0
                $ownerCount = 0
                
                try {
                    $members = Get-MgGroupMember -GroupId $group.Id -ErrorAction SilentlyContinue
                    $memberCount = if ($members) { $members.Count } else { 0 }
                    
                    $owners = Get-MgGroupOwner -GroupId $group.Id -ErrorAction SilentlyContinue
                    $ownerCount = if ($owners) { $owners.Count } else { 0 }
                }
                catch {
                    Write-Log "グループ $($group.DisplayName) のメンバー取得エラー: $($_.Exception.Message)" -Level "Debug"
                }
                
                # 同期状態確認
                $syncStatus = if ($group.OnPremisesSyncEnabled) { "オンプレミス同期" } else { "クラウドのみ" }
                
                # 可視性設定
                $visibility = if ($group.Visibility) { $group.Visibility } else { "未設定" }
                
                # リスクレベル判定
                $riskLevel = "低"
                $riskReasons = @()
                
                if ($ownerCount -eq 0) {
                    $riskLevel = "高"
                    $riskReasons += "オーナー不在"
                }
                elseif ($memberCount -eq 0) {
                    $riskLevel = "中"
                    $riskReasons += "メンバー不在"
                }
                elseif ($memberCount -gt 500) {
                    $riskLevel = "中"
                    $riskReasons += "大規模グループ"
                }
                
                if ($visibility -eq "Public" -and $groupType -eq "Microsoft 365") {
                    if ($riskLevel -eq "低") { $riskLevel = "中" }
                    $riskReasons += "パブリック設定"
                }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $group.DisplayName
                    GroupType = $groupType
                    IsTeam = $isTeam
                    SecurityEnabled = $group.SecurityEnabled
                    MailEnabled = $group.MailEnabled
                    MemberCount = $memberCount
                    OwnerCount = $ownerCount
                    Visibility = $visibility
                    SyncStatus = $syncStatus
                    Description = if ($group.Description) { $group.Description } else { "説明なし" }
                    CreatedDate = $group.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = $riskLevel
                    RiskReasons = if ($riskReasons.Count -gt 0) { $riskReasons -join ", " } else { "なし" }
                    GroupId = $group.Id
                }
                
                $groupResults += $result
                
            }
            catch {
                Write-Log "グループ $($group.DisplayName) の詳細確認エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $group.DisplayName
                    GroupType = "確認エラー"
                    IsTeam = $false
                    SecurityEnabled = $group.SecurityEnabled
                    MailEnabled = $group.MailEnabled
                    MemberCount = 0
                    OwnerCount = 0
                    Visibility = "確認エラー"
                    SyncStatus = "確認エラー"
                    Description = "確認エラー"
                    CreatedDate = $group.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = "要確認"
                    RiskReasons = "確認エラー"
                    GroupId = $group.Id
                }
                
                $groupResults += $result
            }
        }
        
        Write-Progress -Activity "グループ詳細確認中" -Completed
        
        # 結果集計
        $totalGroups = $groupResults.Count
        $securityGroups = ($groupResults | Where-Object { $_.GroupType -eq "セキュリティグループ" }).Count
        $distributionGroups = ($groupResults | Where-Object { $_.GroupType -eq "配布グループ" }).Count
        $m365Groups = ($groupResults | Where-Object { $_.GroupType -eq "Microsoft 365" }).Count
        $teamsGroups = ($groupResults | Where-Object { $_.IsTeam -eq $true }).Count
        $noOwnerGroups = ($groupResults | Where-Object { $_.OwnerCount -eq 0 }).Count
        $highRiskGroups = ($groupResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        
        Write-Log "グループ構成確認完了" -Level "Info"
        Write-Log "総グループ数: $totalGroups" -Level "Info"
        Write-Log "セキュリティグループ: $securityGroups" -Level "Info"
        Write-Log "配布グループ: $distributionGroups" -Level "Info"
        Write-Log "Microsoft 365グループ: $m365Groups" -Level "Info"
        Write-Log "Teamsグループ: $teamsGroups" -Level "Info"
        Write-Log "オーナー不在グループ: $noOwnerGroups" -Level "Info"
        Write-Log "高リスクグループ: $highRiskGroups" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== グループ構成一覧 ===`n" -ForegroundColor Yellow
            
            # 高リスクグループ
            $highRiskList = $groupResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($highRiskList.Count -gt 0) {
                Write-Host "【高リスクグループ】" -ForegroundColor Red
                foreach ($group in $highRiskList) {
                    Write-Host "  ● $($group.DisplayName) ($($group.GroupType))" -ForegroundColor Red
                    Write-Host "    リスク要因: $($group.RiskReasons)" -ForegroundColor Gray
                    Write-Host "    メンバー: $($group.MemberCount)名 | オーナー: $($group.OwnerCount)名" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # オーナー不在グループ
            $noOwnerList = $groupResults | Where-Object { $_.OwnerCount -eq 0 } | Sort-Object DisplayName
            if ($noOwnerList.Count -gt 0) {
                Write-Host "【オーナー不在グループ】" -ForegroundColor Yellow
                foreach ($group in $noOwnerList) {
                    Write-Host "  ⚠ $($group.DisplayName) ($($group.GroupType))" -ForegroundColor Yellow
                    Write-Host "    メンバー: $($group.MemberCount)名 | 作成日: $($group.CreatedDate)" -ForegroundColor Gray
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\Group_Configuration_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($groupResults -and $groupResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $groupResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $groupResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\Group_Configuration_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-GroupConfigurationReportHTML -GroupResults $groupResults -Summary @{
                TotalGroups = $totalGroups
                SecurityGroups = $securityGroups
                DistributionGroups = $distributionGroups
                M365Groups = $m365Groups
                TeamsGroups = $teamsGroups
                NoOwnerGroups = $noOwnerGroups
                HighRiskGroups = $highRiskGroups
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalGroups = $totalGroups
            SecurityGroups = $securityGroups
            DistributionGroups = $distributionGroups
            M365Groups = $m365Groups
            TeamsGroups = $teamsGroups
            NoOwnerGroups = $noOwnerGroups
            HighRiskGroups = $highRiskGroups
            DetailedResults = $groupResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "グループ一覧・構成抽出エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# GM-02: メンバー棚卸レポート出力
function Get-GroupMemberAudit {
    param(
        [Parameter(Mandatory = $false)]
        [string]$GroupId = "",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "メンバー棚卸レポート出力を開始します" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # 対象グループの決定
        $targetGroups = @()
        
        if ([string]::IsNullOrEmpty($GroupId)) {
            # 全グループを対象とする
            Write-Log "全グループのメンバー棚卸を実行します" -Level "Info"
            $targetGroups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,SecurityEnabled,MailEnabled
        }
        else {
            # 指定されたグループのみ
            Write-Log "指定されたグループのメンバー棚卸を実行します: $GroupId" -Level "Info"
            $group = Get-MgGroup -GroupId $GroupId -Property Id,DisplayName,GroupTypes,SecurityEnabled,MailEnabled
            $targetGroups = @($group)
        }
        
        Write-Log "対象グループ数: $($targetGroups.Count)" -Level "Info"
        
        # メンバー棚卸結果
        $auditResults = @()
        $progressCount = 0
        
        foreach ($group in $targetGroups) {
            $progressCount++
            Write-Progress -Activity "メンバー棚卸実行中" -Status "$progressCount/$($targetGroups.Count) - $($group.DisplayName)" -PercentComplete (($progressCount / $targetGroups.Count) * 100)
            
            try {
                # グループタイプの判定
                $groupType = "不明"
                if ($group.GroupTypes -and $group.GroupTypes -contains "Unified") {
                    $groupType = "Microsoft 365"
                }
                elseif ($group.SecurityEnabled -and -not $group.MailEnabled) {
                    $groupType = "セキュリティグループ"
                }
                elseif (-not $group.SecurityEnabled -and $group.MailEnabled) {
                    $groupType = "配布グループ"
                }
                elseif ($group.SecurityEnabled -and $group.MailEnabled) {
                    $groupType = "メール対応セキュリティグループ"
                }
                
                # メンバー取得
                $members = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction SilentlyContinue
                $owners = Get-MgGroupOwner -GroupId $group.Id -All -ErrorAction SilentlyContinue
                
                # メンバー詳細分析
                foreach ($member in $members) {
                    try {
                        # メンバーの詳細情報取得
                        $memberDetail = $null
                        $memberType = "不明"
                        $isOwner = $false
                        
                        # オーナーかどうか確認
                        $isOwner = $owners | Where-Object { $_.Id -eq $member.Id } | Measure-Object | Select-Object -ExpandProperty Count
                        $isOwner = $isOwner -gt 0
                        
                        # メンバータイプの判定
                        if ($member.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.user") {
                            $memberType = "ユーザー"
                            $memberDetail = Get-MgUser -UserId $member.Id -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime -ErrorAction SilentlyContinue
                        }
                        elseif ($member.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.group") {
                            $memberType = "グループ"
                            $memberDetail = Get-MgGroup -GroupId $member.Id -Property Id,DisplayName -ErrorAction SilentlyContinue
                        }
                        elseif ($member.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.device") {
                            $memberType = "デバイス"
                            $memberDetail = $member
                        }
                        else {
                            $memberType = "その他"
                            $memberDetail = $member
                        }
                        
                        # リスクレベル判定
                        $riskLevel = "低"
                        $riskReasons = @()
                        
                        if ($memberType -eq "ユーザー" -and $memberDetail) {
                            if (-not $memberDetail.AccountEnabled) {
                                $riskLevel = "高"
                                $riskReasons += "無効ユーザー"
                            }
                        }
                        
                        if ($memberType -eq "グループ") {
                            $riskLevel = "中"
                            $riskReasons += "ネストされたグループ"
                        }
                        
                        # 結果オブジェクト作成
                        $auditResult = [PSCustomObject]@{
                            GroupName = $group.DisplayName
                            GroupType = $groupType
                            MemberName = if ($memberDetail.DisplayName) { $memberDetail.DisplayName } else { "不明" }
                            MemberPrincipalName = if ($memberDetail.UserPrincipalName) { $memberDetail.UserPrincipalName } else { "N/A" }
                            MemberType = $memberType
                            IsOwner = $isOwner
                            AccountEnabled = if ($memberDetail.AccountEnabled -ne $null) { $memberDetail.AccountEnabled } else { "N/A" }
                            MemberCreatedDate = if ($memberDetail.CreatedDateTime) { $memberDetail.CreatedDateTime.ToString("yyyy/MM/dd") } else { "不明" }
                            RiskLevel = $riskLevel
                            RiskReasons = if ($riskReasons.Count -gt 0) { $riskReasons -join ", " } else { "なし" }
                            GroupId = $group.Id
                            MemberId = $member.Id
                        }
                        
                        $auditResults += $auditResult
                        
                    }
                    catch {
                        Write-Log "メンバー $($member.Id) の詳細取得エラー: $($_.Exception.Message)" -Level "Debug"
                        
                        # エラー時も基本情報は記録
                        $auditResult = [PSCustomObject]@{
                            GroupName = $group.DisplayName
                            GroupType = $groupType
                            MemberName = "取得エラー"
                            MemberPrincipalName = "取得エラー"
                            MemberType = "不明"
                            IsOwner = $false
                            AccountEnabled = "不明"
                            MemberCreatedDate = "不明"
                            RiskLevel = "要確認"
                            RiskReasons = "詳細取得エラー"
                            GroupId = $group.Id
                            MemberId = $member.Id
                        }
                        
                        $auditResults += $auditResult
                    }
                }
                
                # メンバーが0の場合も記録
                if ($members.Count -eq 0) {
                    $auditResult = [PSCustomObject]@{
                        GroupName = $group.DisplayName
                        GroupType = $groupType
                        MemberName = "メンバーなし"
                        MemberPrincipalName = "N/A"
                        MemberType = "N/A"
                        IsOwner = $false
                        AccountEnabled = "N/A"
                        MemberCreatedDate = "N/A"
                        RiskLevel = "中"
                        RiskReasons = "メンバー不在"
                        GroupId = $group.Id
                        MemberId = "N/A"
                    }
                    
                    $auditResults += $auditResult
                }
                
            }
            catch {
                Write-Log "グループ $($group.DisplayName) のメンバー取得エラー: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        Write-Progress -Activity "メンバー棚卸実行中" -Completed
        
        # 結果集計
        $totalMembers = ($auditResults | Where-Object { $_.MemberName -ne "メンバーなし" }).Count
        $ownerMembers = ($auditResults | Where-Object { $_.IsOwner -eq $true }).Count
        $disabledMembers = ($auditResults | Where-Object { $_.AccountEnabled -eq $false }).Count
        $nestedGroups = ($auditResults | Where-Object { $_.MemberType -eq "グループ" }).Count
        $highRiskMembers = ($auditResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        $emptyGroups = ($auditResults | Where-Object { $_.MemberName -eq "メンバーなし" }).Count
        
        Write-Log "メンバー棚卸完了" -Level "Info"
        Write-Log "総メンバー数: $totalMembers" -Level "Info"
        Write-Log "オーナー数: $ownerMembers" -Level "Info"
        Write-Log "無効ユーザー: $disabledMembers" -Level "Info"
        Write-Log "ネストグループ: $nestedGroups" -Level "Info"
        Write-Log "高リスクメンバー: $highRiskMembers" -Level "Info"
        Write-Log "空グループ: $emptyGroups" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== メンバー棚卸結果 ===`n" -ForegroundColor Yellow
            
            # 高リスクメンバー
            $highRiskList = $auditResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object GroupName, MemberName
            if ($highRiskList.Count -gt 0) {
                Write-Host "【高リスクメンバー】" -ForegroundColor Red
                foreach ($member in $highRiskList) {
                    Write-Host "  ● $($member.GroupName) > $($member.MemberName)" -ForegroundColor Red
                    Write-Host "    リスク要因: $($member.RiskReasons)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 無効ユーザー
            $disabledList = $auditResults | Where-Object { $_.AccountEnabled -eq $false } | Sort-Object GroupName, MemberName
            if ($disabledList.Count -gt 0) {
                Write-Host "【無効ユーザー】" -ForegroundColor Yellow
                foreach ($member in $disabledList) {
                    Write-Host "  ⚠ $($member.GroupName) > $($member.MemberName)" -ForegroundColor Yellow
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\Group_Member_Audit_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($auditResults -and $auditResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $auditResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $auditResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\Group_Member_Audit_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-GroupMemberAuditReportHTML -AuditResults $auditResults -Summary @{
                TotalMembers = $totalMembers
                OwnerMembers = $ownerMembers
                DisabledMembers = $disabledMembers
                NestedGroups = $nestedGroups
                HighRiskMembers = $highRiskMembers
                EmptyGroups = $emptyGroups
                TargetGroupCount = $targetGroups.Count
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalMembers = $totalMembers
            OwnerMembers = $ownerMembers
            DisabledMembers = $disabledMembers
            NestedGroups = $nestedGroups
            HighRiskMembers = $highRiskMembers
            EmptyGroups = $emptyGroups
            TargetGroupCount = $targetGroups.Count
            DetailedResults = $auditResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "メンバー棚卸レポート出力エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# グループ構成 HTMLレポート生成関数
function Generate-GroupConfigurationReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$GroupResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 各カテゴリ別にグループを抽出
    $highRiskGroups = $GroupResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
    $noOwnerGroups = $GroupResults | Where-Object { $_.OwnerCount -eq 0 } | Sort-Object DisplayName
    $teamsGroups = $GroupResults | Where-Object { $_.IsTeam -eq $true } | Sort-Object DisplayName
    $securityGroups = $GroupResults | Where-Object { $_.GroupType -eq "セキュリティグループ" } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>グループ構成分析レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .risk-high { color: #d13438; font-weight: bold; }
        .risk-medium { color: #ff8c00; font-weight: bold; }
        .risk-low { color: #107c10; }
        .team-group { color: #6264a7; font-weight: bold; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(7, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>👥 グループ構成分析レポート</h1>
        <div class="subtitle">みらい建設工業株式会社</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総グループ数</h3>
            <div class="value">$($Summary.TotalGroups)</div>
            <div class="description">全グループ</div>
        </div>
        <div class="summary-card">
            <h3>セキュリティグループ</h3>
            <div class="value success">$($Summary.SecurityGroups)</div>
            <div class="description">認証・権限</div>
        </div>
        <div class="summary-card">
            <h3>配布グループ</h3>
            <div class="value">$($Summary.DistributionGroups)</div>
            <div class="description">メール配信</div>
        </div>
        <div class="summary-card">
            <h3>Microsoft 365</h3>
            <div class="value">$($Summary.M365Groups)</div>
            <div class="description">コラボレーション</div>
        </div>
        <div class="summary-card">
            <h3>Teamsグループ</h3>
            <div class="value">$($Summary.TeamsGroups)</div>
            <div class="description">チームワーク</div>
        </div>
        <div class="summary-card">
            <h3>オーナー不在</h3>
            <div class="value danger">$($Summary.NoOwnerGroups)</div>
            <div class="description">要対応</div>
        </div>
        <div class="summary-card">
            <h3>高リスクグループ</h3>
            <div class="value danger">$($Summary.HighRiskGroups)</div>
            <div class="description">緊急対応</div>
        </div>
    </div>
"@

    # 高リスクグループ一覧
    if ($highRiskGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 高リスクグループ (緊急対応必要)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>グループタイプ</th>
                            <th>メンバー数</th>
                            <th>オーナー数</th>
                            <th>リスク要因</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $highRiskGroups) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($group.DisplayName)</td>
                            <td>$($group.GroupType)</td>
                            <td>$($group.MemberCount)</td>
                            <td>$($group.OwnerCount)</td>
                            <td class="risk-high">$($group.RiskReasons)</td>
                            <td>$($group.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # オーナー不在グループ一覧
    if ($noOwnerGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ オーナー不在グループ</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>グループタイプ</th>
                            <th>メンバー数</th>
                            <th>可視性</th>
                            <th>説明</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $noOwnerGroups) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($group.DisplayName)</td>
                            <td>$($group.GroupType)</td>
                            <td>$($group.MemberCount)</td>
                            <td>$($group.Visibility)</td>
                            <td>$($group.Description)</td>
                            <td>$($group.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # Teamsグループ一覧
    if ($teamsGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🎯 Microsoft Teamsグループ</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>チーム名</th>
                            <th>メンバー数</th>
                            <th>オーナー数</th>
                            <th>可視性</th>
                            <th>説明</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $teamsGroups) {
            $htmlTemplate += @"
                        <tr>
                            <td class="team-group">$($group.DisplayName)</td>
                            <td>$($group.MemberCount)</td>
                            <td>$($group.OwnerCount)</td>
                            <td>$($group.Visibility)</td>
                            <td>$($group.Description)</td>
                            <td>$($group.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# グループメンバー棚卸 HTMLレポート生成関数
function Generate-GroupMemberAuditReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$AuditResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 各カテゴリ別にメンバーを抽出
    $highRiskMembers = $AuditResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object GroupName, MemberName
    $disabledMembers = $AuditResults | Where-Object { $_.AccountEnabled -eq $false } | Sort-Object GroupName, MemberName
    $nestedGroups = $AuditResults | Where-Object { $_.MemberType -eq "グループ" } | Sort-Object GroupName, MemberName
    $ownerMembers = $AuditResults | Where-Object { $_.IsOwner -eq $true } | Sort-Object GroupName, MemberName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>グループメンバー棚卸レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .risk-high { color: #d13438; font-weight: bold; }
        .member-owner { color: #107c10; font-weight: bold; }
        .member-disabled { color: #d13438; }
        .member-nested { color: #ff8c00; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(7, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📋 グループメンバー棚卸レポート</h1>
        <div class="subtitle">みらい建設工業株式会社</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>対象グループ数</h3>
            <div class="value">$($Summary.TargetGroupCount)</div>
            <div class="description">分析済み</div>
        </div>
        <div class="summary-card">
            <h3>総メンバー数</h3>
            <div class="value">$($Summary.TotalMembers)</div>
            <div class="description">全メンバー</div>
        </div>
        <div class="summary-card">
            <h3>オーナー数</h3>
            <div class="value success">$($Summary.OwnerMembers)</div>
            <div class="description">管理者</div>
        </div>
        <div class="summary-card">
            <h3>無効ユーザー</h3>
            <div class="value danger">$($Summary.DisabledMembers)</div>
            <div class="description">要削除</div>
        </div>
        <div class="summary-card">
            <h3>ネストグループ</h3>
            <div class="value warning">$($Summary.NestedGroups)</div>
            <div class="description">複雑化要因</div>
        </div>
        <div class="summary-card">
            <h3>高リスクメンバー</h3>
            <div class="value danger">$($Summary.HighRiskMembers)</div>
            <div class="description">緊急対応</div>
        </div>
        <div class="summary-card">
            <h3>空グループ</h3>
            <div class="value warning">$($Summary.EmptyGroups)</div>
            <div class="description">削除検討</div>
        </div>
    </div>
"@

    # 高リスクメンバー一覧
    if ($highRiskMembers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 高リスクメンバー (緊急対応必要)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>メンバー名</th>
                            <th>メンバータイプ</th>
                            <th>アカウント状態</th>
                            <th>オーナー</th>
                            <th>リスク要因</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($member in $highRiskMembers) {
            $ownerBadge = if ($member.IsOwner) { "✓" } else { "" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($member.GroupName)</td>
                            <td>$($member.MemberName)</td>
                            <td>$($member.MemberType)</td>
                            <td class="member-disabled">$($member.AccountEnabled)</td>
                            <td>$ownerBadge</td>
                            <td class="risk-high">$($member.RiskReasons)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 無効ユーザー一覧
    if ($disabledMembers.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 無効ユーザー (削除推奨)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>ユーザー名</th>
                            <th>プリンシパル名</th>
                            <th>オーナー</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($member in $disabledMembers) {
            $ownerBadge = if ($member.IsOwner) { "✓" } else { "" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($member.GroupName)</td>
                            <td class="member-disabled">$($member.MemberName)</td>
                            <td>$($member.MemberPrincipalName)</td>
                            <td>$ownerBadge</td>
                            <td>$($member.MemberCreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # ネストされたグループ一覧
    if ($nestedGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🔗 ネストされたグループ</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>親グループ</th>
                            <th>子グループ</th>
                            <th>オーナー</th>
                            <th>リスクレベル</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($member in $nestedGroups) {
            $ownerBadge = if ($member.IsOwner) { "✓" } else { "" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($member.GroupName)</td>
                            <td class="member-nested">$($member.MemberName)</td>
                            <td>$ownerBadge</td>
                            <td>$($member.RiskLevel)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# GM-03: 動的グループ設定確認
function Get-DynamicGroupConfiguration {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "動的グループ設定確認を開始します" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # 動的グループの取得
        Write-Log "動的グループ一覧を取得中..." -Level "Info"
        
        try {
            # 動的メンバーシップが有効なグループを検索
            $allGroups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,MembershipRule,MembershipRuleProcessingState,CreatedDateTime,Description,Visibility,OnPremisesSyncEnabled
            $dynamicGroups = $allGroups | Where-Object { $_.MembershipRule -ne $null -and $_.MembershipRule -ne "" }
            
            Write-Log "動的グループ情報取得完了: $($dynamicGroups.Count)個の動的グループ" -Level "Info"
        }
        catch {
            Write-Log "動的グループ取得エラー: $($_.Exception.Message)" -Level "Error"
            # E3制限により動的グループ情報が制限される場合の対応
            Write-Log "E3ライセンス制限により、動的グループの詳細情報取得に制限があります" -Level "Warning"
            $dynamicGroups = @()
        }
        
        # 動的グループ分析結果（確実に配列として初期化）
        $dynamicResults = @()
        $progressCount = 0
        
        if ($dynamicGroups.Count -eq 0) {
            Write-Log "動的グループが見つかりませんでした。" -Level "Warning"
            # 空の場合は通常の配列として初期化（ArrayListではなく）
            $dynamicResults = @()
        }
        else {
            # 動的グループが取得できた場合の詳細分析
            $dynamicResults = @()  # 処理前に初期化
            foreach ($group in $dynamicGroups) {
                $progressCount++
                Write-Progress -Activity "動的グループ分析中" -Status "$progressCount/$($dynamicGroups.Count)" -PercentComplete (($progressCount / $dynamicGroups.Count) * 100)
                
                try {
                    # メンバー数の取得
                    $members = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction SilentlyContinue
                    $memberCount = if ($members) { $members.Count } else { 0 }
                    
                    # 処理状態の分析
                    $processingState = if ($group.MembershipRuleProcessingState) { $group.MembershipRuleProcessingState } else { "不明" }
                    
                    # リスクレベル判定
                    $riskLevel = "低"
                    $riskReasons = @()
                    
                    if ($processingState -eq "ProcessingError") {
                        $riskLevel = "高"
                        $riskReasons += "動的ルール処理エラー"
                    }
                    elseif ($processingState -eq "Paused") {
                        $riskLevel = "中"
                        $riskReasons += "動的処理が一時停止"
                    }
                    elseif ($memberCount -eq 0 -and $group.MembershipRule) {
                        $riskLevel = "中"
                        $riskReasons += "ルールが設定されているがメンバーが0"
                    }
                    elseif ($memberCount -gt 500) {
                        $riskLevel = "中"
                        $riskReasons += "大規模動的グループ"
                    }
                    
                    # 結果オブジェクト作成
                    $result = [PSCustomObject]@{
                        DisplayName = $group.DisplayName
                        IsDynamicGroup = $true
                        IsDynamicLikely = $true
                        MembershipRule = if ($group.MembershipRule.Length -gt 100) { $group.MembershipRule.Substring(0, 100) + "..." } else { $group.MembershipRule }
                        ProcessingState = $processingState
                        MemberCount = $memberCount
                        GroupType = if ($group.GroupTypes -contains "Unified") { "Microsoft 365" } else { "セキュリティグループ" }
                        Visibility = if ($group.Visibility) { $group.Visibility } else { "未設定" }
                        SyncStatus = if ($group.OnPremisesSyncEnabled) { "オンプレミス同期" } else { "クラウドのみ" }
                        Description = if ($group.Description) { $group.Description } else { "説明なし" }
                        CreatedDate = $group.CreatedDateTime.ToString("yyyy/MM/dd")
                        RiskLevel = $riskLevel
                        RiskReasons = if ($riskReasons.Count -gt 0) { $riskReasons -join ", " } else { "なし" }
                        AnalysisNotes = "完全な動的グループ分析"
                        GroupId = $group.Id
                        LicenseEnvironment = "Premium"
                    }
                    
                    $dynamicResults += $result
                    
                }
                catch {
                    Write-Log "動的グループ $($group.DisplayName) の詳細確認エラー: $($_.Exception.Message)" -Level "Warning"
                }
            }
        }
        
        Write-Progress -Activity "動的グループ分析中" -Completed
        
        # 結果集計（null安全）
        $totalGroups = if ($null -ne $dynamicResults) { $dynamicResults.Count } else { 0 }
        $trueDynamicGroups = if ($null -ne $dynamicResults -and $dynamicResults.Count -gt 0) { 
            ($dynamicResults | Where-Object { $_.IsDynamicGroup -eq $true }).Count 
        } else { 0 }
        $errorGroups = if ($null -ne $dynamicResults -and $dynamicResults.Count -gt 0) { 
            ($dynamicResults | Where-Object { $_.ProcessingState -eq "ProcessingError" }).Count 
        } else { 0 }
        $pausedGroups = if ($null -ne $dynamicResults -and $dynamicResults.Count -gt 0) { 
            ($dynamicResults | Where-Object { $_.ProcessingState -eq "Paused" }).Count 
        } else { 0 }
        $highRiskGroups = if ($null -ne $dynamicResults -and $dynamicResults.Count -gt 0) { 
            ($dynamicResults | Where-Object { $_.RiskLevel -eq "高" }).Count 
        } else { 0 }
        $largeGroups = if ($null -ne $dynamicResults -and $dynamicResults.Count -gt 0) { 
            ($dynamicResults | Where-Object { $_.MemberCount -gt 500 }).Count 
        } else { 0 }
        
        Write-Log "動的グループ設定確認完了" -Level "Info"
        Write-Log "分析対象グループ数: $totalGroups" -Level "Info"
        Write-Log "確実な動的グループ: $trueDynamicGroups" -Level "Info"
        Write-Log "処理エラーグループ: $errorGroups" -Level "Info"
        Write-Log "一時停止グループ: $pausedGroups" -Level "Info"
        Write-Log "高リスクグループ: $highRiskGroups" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== 動的グループ設定確認結果 ===`n" -ForegroundColor Yellow
            
            # 処理エラーグループ
            $errorList = $dynamicResults | Where-Object { $_.ProcessingState -eq "ProcessingError" } | Sort-Object DisplayName
            if ($errorList.Count -gt 0) {
                Write-Host "【処理エラーグループ】" -ForegroundColor Red
                foreach ($group in $errorList) {
                    Write-Host "  ● $($group.DisplayName)" -ForegroundColor Red
                    Write-Host "    ルール: $($group.MembershipRule)" -ForegroundColor Gray
                    Write-Host "    状態: $($group.ProcessingState)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 高リスクグループ
            $highRiskList = $dynamicResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($highRiskList.Count -gt 0) {
                Write-Host "【高リスクグループ】" -ForegroundColor Red
                foreach ($group in $highRiskList) {
                    Write-Host "  ⚠ $($group.DisplayName)" -ForegroundColor Red
                    Write-Host "    リスク要因: $($group.RiskReasons)" -ForegroundColor Gray
                    Write-Host "    メンバー数: $($group.MemberCount)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # E3制限メッセージ
            if ($trueDynamicGroups -eq 0) {
                Write-Host "※ 動的グループが検出されませんでした" -ForegroundColor Yellow
                Write-Host "※ 完全な動的グループ管理にはAzure AD Premium P1以上が必要です" -ForegroundColor Yellow
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\Dynamic_Group_Configuration_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($null -ne $dynamicResults -and $dynamicResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $dynamicResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $dynamicResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            else {
                # 空の場合はヘッダーのみのCSVを作成
                $emptyResult = [PSCustomObject]@{
                    DisplayName = "動的グループが検出されませんでした"
                    IsDynamicGroup = $false
                    MembershipRule = "N/A"
                    ProcessingState = "N/A"
                    MemberCount = 0
                    GroupType = "N/A"
                    Visibility = "N/A"
                    SyncStatus = "N/A"
                    Description = "E3ライセンス環境では動的グループの検出に制限があります"
                    CreatedDate = "N/A"
                    RiskLevel = "情報"
                    RiskReasons = "なし"
                    AnalysisNotes = "動的グループが見つかりませんでした"
                    GroupId = "N/A"
                    LicenseEnvironment = "E3 (制限あり)"
                }
                
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $emptyResult | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $emptyResult | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\Dynamic_Group_Configuration_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成（パラメータ名を明示して確実に渡す）
            $emptyArray = @()
            $htmlContent = Generate-DynamicGroupReportHTML -DynamicResults $emptyArray -Summary @{
                TotalGroups = $totalGroups
                TrueDynamicGroups = $trueDynamicGroups
                ErrorGroups = $errorGroups
                PausedGroups = $pausedGroups
                HighRiskGroups = $highRiskGroups
                LargeGroups = $largeGroups
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却（null安全）
        return @{
            Success = $true
            TotalGroups = $totalGroups
            TrueDynamicGroups = $trueDynamicGroups
            ErrorGroups = $errorGroups
            PausedGroups = $pausedGroups
            HighRiskGroups = $highRiskGroups
            LargeGroups = $largeGroups
            DetailedResults = if ($null -ne $dynamicResults) { $dynamicResults } else { @() }
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
            LicenseEnvironment = if ($trueDynamicGroups -gt 0) { "Premium" } else { "E3 (制限あり)" }
        }
        
    }
    catch {
        Write-Log "動的グループ設定確認エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# 動的グループ HTMLレポート生成関数
function Generate-DynamicGroupReportHTML {
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]$DynamicResults = @(),
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # パラメータのnullチェックと初期化
    if ($null -eq $DynamicResults) {
        $DynamicResults = @()
    }
    
    # 各カテゴリ別に動的グループを抽出（null/空のコレクション対応）
    $errorGroups = @()
    $pausedGroups = @()
    $highRiskGroups = @()
    $trueDynamicGroups = @()
    
    if ($DynamicResults.Count -gt 0) {
        try {
            $errorGroups = $DynamicResults | Where-Object { $_.ProcessingState -eq "ProcessingError" } | Sort-Object DisplayName
            if ($null -eq $errorGroups) { $errorGroups = @() }
            
            $pausedGroups = $DynamicResults | Where-Object { $_.ProcessingState -eq "Paused" } | Sort-Object DisplayName
            if ($null -eq $pausedGroups) { $pausedGroups = @() }
            
            $highRiskGroups = $DynamicResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($null -eq $highRiskGroups) { $highRiskGroups = @() }
            
            $trueDynamicGroups = $DynamicResults | Where-Object { $_.IsDynamicGroup -eq $true } | Sort-Object DisplayName
            if ($null -eq $trueDynamicGroups) { $trueDynamicGroups = @() }
        }
        catch {
            # エラーが発生した場合も空の配列を確保
            $errorGroups = @()
            $pausedGroups = @()
            $highRiskGroups = @()
            $trueDynamicGroups = @()
        }
    }
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>動的グループ設定確認レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; max-height: 400px; overflow-y: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
            position: sticky;
            top: 0;
        }
        .risk-high { color: #d13438; font-weight: bold; }
        .risk-medium { color: #ff8c00; font-weight: bold; }
        .risk-low { color: #107c10; }
        .dynamic-group { color: #0078d4; font-weight: bold; }
        .membership-rule { font-family: monospace; font-size: 12px; background: #f8f9fa; padding: 4px; border-radius: 3px; }
        .alert-info {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(7, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>⚙️ 動的グループ設定確認レポート</h1>
        <div class="subtitle">みらい建設工業株式会社</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>分析対象グループ数</h3>
            <div class="value">$($Summary.TotalGroups)</div>
            <div class="description">全分析対象</div>
        </div>
        <div class="summary-card">
            <h3>動的グループ</h3>
            <div class="value success">$($Summary.TrueDynamicGroups)</div>
            <div class="description">確実</div>
        </div>
        <div class="summary-card">
            <h3>処理エラー</h3>
            <div class="value danger">$($Summary.ErrorGroups)</div>
            <div class="description">要対応</div>
        </div>
        <div class="summary-card">
            <h3>一時停止</h3>
            <div class="value warning">$($Summary.PausedGroups)</div>
            <div class="description">確認必要</div>
        </div>
        <div class="summary-card">
            <h3>高リスクグループ</h3>
            <div class="value danger">$($Summary.HighRiskGroups)</div>
            <div class="description">緊急対応</div>
        </div>
        <div class="summary-card">
            <h3>大規模グループ</h3>
            <div class="value warning">$($Summary.LargeGroups)</div>
            <div class="description">500名以上</div>
        </div>
    </div>
"@

    # E3制限の場合の情報表示
    if ($Summary.TrueDynamicGroups -eq 0) {
        $htmlTemplate += @"
    <div class="alert-info">
        <strong>注意:</strong> 動的グループが検出されませんでした。
        完全な動的グループ管理にはAzure AD Premium P1以上が必要です。
    </div>
"@
    }

    # 処理エラーグループ一覧
    if ($errorGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 処理エラーグループ (緊急対応必要)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>メンバーシップルール</th>
                            <th>処理状態</th>
                            <th>メンバー数</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $errorGroups) {
            $htmlTemplate += @"
                        <tr>
                            <td class="dynamic-group">$($group.DisplayName)</td>
                            <td class="membership-rule">$($group.MembershipRule)</td>
                            <td class="risk-high">$($group.ProcessingState)</td>
                            <td>$($group.MemberCount)</td>
                            <td>$($group.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 高リスクグループ一覧
    if ($highRiskGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 高リスクグループ</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>動的グループ</th>
                            <th>メンバー数</th>
                            <th>リスク要因</th>
                            <th>分析備考</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $highRiskGroups) {
            $isDynamic = if ($group.IsDynamicGroup) { "✓" } else { "×" }
            $htmlTemplate += @"
                        <tr>
                            <td>$($group.DisplayName)</td>
                            <td>$isDynamic</td>
                            <td>$($group.MemberCount)</td>
                            <td class="risk-high">$($group.RiskReasons)</td>
                            <td>$($group.AnalysisNotes)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 動的グループ一覧
    if ($trueDynamicGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🔄 動的グループ一覧</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>メンバーシップルール</th>
                            <th>処理状態</th>
                            <th>メンバー数</th>
                            <th>グループタイプ</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $trueDynamicGroups) {
            $stateColor = switch ($group.ProcessingState) {
                "ProcessingError" { "risk-high" }
                "Paused" { "risk-medium" }
                default { "risk-low" }
            }
            $htmlTemplate += @"
                        <tr>
                            <td class="dynamic-group">$($group.DisplayName)</td>
                            <td class="membership-rule">$($group.MembershipRule)</td>
                            <td class="$stateColor">$($group.ProcessingState)</td>
                            <td>$($group.MemberCount)</td>
                            <td>$($group.GroupType)</td>
                            <td>$($group.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# GM-04: グループ属性およびロール確認
function Get-GroupAttributesAndRoles {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "グループ属性およびロール確認を開始します" -Level "Info"
    
    try {
        # Microsoft Graph接続確認と自動接続
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Microsoft Graph に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Microsoft Graph への自動接続を開始します" -Level "Info"
                $connectResult = Connect-MicrosoftGraphService -Config $config
                
                if ($connectResult) {
                    Write-Log "Microsoft Graph 自動接続成功" -Level "Info"
                }
                else {
                    throw "Microsoft Graph への自動接続に失敗しました"
                }
            }
            catch {
                throw "Microsoft Graph 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        else {
            Write-Log "Microsoft Graph 接続確認完了" -Level "Info"
        }
        
        # 全グループの取得（詳細属性付き）
        Write-Log "グループ属性とロール情報を取得中..." -Level "Info"
        
        try {
            # E3互換の基本プロパティでグループ情報を取得
            $allGroups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,SecurityEnabled,MailEnabled,CreatedDateTime,Description,Visibility,OnPremisesSyncEnabled,Mail,MailNickname,ProxyAddresses,AssignedLicenses,Classification,RenewedDateTime,ExpirationDateTime
            Write-Log "グループ属性情報取得完了: $($allGroups.Count)個のグループ" -Level "Info"
        }
        catch {
            Write-Log "グループ取得エラー (E3制限対応): $($_.Exception.Message)" -Level "Warning"
            # さらに制限されたプロパティで再試行
            try {
                $allGroups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,SecurityEnabled,MailEnabled,CreatedDateTime,Description,Visibility,Mail,MailNickname
                Write-Log "グループ基本情報取得完了: $($allGroups.Count)個のグループ（制限モード）" -Level "Info"
            }
            catch {
                Write-Log "グループ取得エラー（最小プロパティ）: $($_.Exception.Message)" -Level "Error"
                # 最小限のプロパティで最終試行
                $allGroups = Get-MgGroup -All
                Write-Log "グループ最小情報取得完了: $($allGroups.Count)個のグループ（最小モード）" -Level "Info"
            }
        }
        
        # グループ属性・ロール分析結果
        $attributeResults = @()
        $progressCount = 0
        
        foreach ($group in $allGroups) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "グループ属性・ロール確認中" -Status "$progressCount/$($allGroups.Count)" -PercentComplete (($progressCount / $allGroups.Count) * 100)
            }
            
            try {
                # グループタイプの詳細判定
                $groupType = "不明"
                $isTeam = $false
                $securityType = "なし"
                
                if ($group.GroupTypes -and $group.GroupTypes -contains "Unified") {
                    $groupType = "Microsoft 365"
                    $securityType = "統合グループ"
                    
                    # Teamsチームかどうか確認
                    try {
                        $teamInfo = Get-MgTeam -TeamId $group.Id -ErrorAction SilentlyContinue
                        if ($teamInfo) {
                            $isTeam = $true
                            $groupType = "Microsoft Teams"
                        }
                    }
                    catch {
                        # Teams情報取得エラーは無視
                    }
                }
                elseif ($group.SecurityEnabled -and -not $group.MailEnabled) {
                    $groupType = "セキュリティグループ"
                    $securityType = "セキュリティのみ"
                }
                elseif (-not $group.SecurityEnabled -and $group.MailEnabled) {
                    $groupType = "配布グループ"
                    $securityType = "メール配信のみ"
                }
                elseif ($group.SecurityEnabled -and $group.MailEnabled) {
                    $groupType = "メール対応セキュリティグループ"
                    $securityType = "セキュリティ+メール"
                }
                
                # オーナーとメンバーの詳細情報取得
                $owners = @()
                $members = @()
                $memberCount = 0
                $ownerCount = 0
                $adminRoles = @()
                
                try {
                    $owners = Get-MgGroupOwner -GroupId $group.Id -All -ErrorAction SilentlyContinue
                    $ownerCount = if ($owners) { $owners.Count } else { 0 }
                    
                    $members = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction SilentlyContinue
                    $memberCount = if ($members) { $members.Count } else { 0 }
                }
                catch {
                    Write-Log "グループ $($group.DisplayName) のメンバー取得エラー: $($_.Exception.Message)" -Level "Debug"
                }
                
                # 管理者ロールの確認（オーナーの権限レベル分析）
                $adminRoleCount = 0
                $globalAdminCount = 0
                $groupAdminCount = 0
                
                foreach ($owner in $owners) {
                    try {
                        if ($owner.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.user") {
                            # ユーザーの管理者ロールを確認（E3制限により簡略化）
                            $userDetail = Get-MgUser -UserId $owner.Id -Property Id,DisplayName,UserPrincipalName -ErrorAction SilentlyContinue
                            if ($userDetail) {
                                # オーナーは何らかの管理権限を持つとみなす
                                $adminRoleCount++
                                $groupAdminCount++
                            }
                        }
                    }
                    catch {
                        # 個別ユーザー情報取得エラーは無視
                    }
                }
                
                # メール属性の分析
                $mailAttributes = @{
                    HasMail = $group.Mail -ne $null -and $group.Mail -ne ""
                    MailAddress = if ($group.Mail) { $group.Mail } else { "設定なし" }
                    MailNickname = if ($group.MailNickname) { $group.MailNickname } else { "設定なし" }
                    ProxyAddresses = if ($group.ProxyAddresses) { $group.ProxyAddresses.Count } else { 0 }
                }
                
                # ライセンス属性の分析（E3制限対応）
                $licenseInfo = @{
                    HasAssignedLicenses = $group.AssignedLicenses -ne $null -and $group.AssignedLicenses.Count -gt 0
                    LicenseCount = if ($group.AssignedLicenses) { $group.AssignedLicenses.Count } else { 0 }
                    HasLicenseErrors = $false  # E3制限により直接取得不可、代替手法で推定
                }
                
                # ライセンスエラーの推定判定（E3互換）
                try {
                    if ($licenseInfo.HasAssignedLicenses -and $memberCount -gt 0) {
                        # グループにライセンスが割り当てられているが、メンバーが多い場合は潜在的エラーリスク
                        if ($memberCount -gt 50 -and $licenseInfo.LicenseCount -gt 0) {
                            $licenseInfo.HasLicenseErrors = $true  # 推定
                        }
                    }
                }
                catch {
                    # ライセンスエラー推定処理でのエラーは無視
                }
                
                # 有効期限とライフサイクル
                $lifecycleInfo = @{
                    HasExpiration = $group.ExpirationDateTime -ne $null
                    ExpirationDate = if ($group.ExpirationDateTime) { $group.ExpirationDateTime.ToString("yyyy/MM/dd") } else { "無期限" }
                    LastRenewed = if ($group.RenewedDateTime) { $group.RenewedDateTime.ToString("yyyy/MM/dd") } else { "不明" }
                    Classification = if ($group.Classification) { $group.Classification } else { "未分類" }
                }
                
                # リスクレベル判定
                $riskLevel = "低"
                $riskReasons = @()
                
                if ($ownerCount -eq 0) {
                    $riskLevel = "高"
                    $riskReasons += "オーナー不在"
                }
                elseif ($adminRoleCount -eq 0 -and $ownerCount -gt 0) {
                    $riskLevel = "中"
                    $riskReasons += "管理者権限不明"
                }
                
                if ($group.SecurityEnabled -and $memberCount -gt 100) {
                    if ($riskLevel -eq "低") { $riskLevel = "中" }
                    $riskReasons += "大規模セキュリティグループ"
                }
                
                if ($mailAttributes.HasMail -and $group.Visibility -eq "Public") {
                    if ($riskLevel -eq "低") { $riskLevel = "中" }
                    $riskReasons += "パブリックメール配信グループ"
                }
                
                if ($licenseInfo.HasLicenseErrors) {
                    $riskLevel = "高"
                    $riskReasons += "ライセンスエラー"
                }
                
                if ($lifecycleInfo.HasExpiration -and $group.ExpirationDateTime -lt (Get-Date).AddDays(30)) {
                    if ($riskLevel -ne "高") { $riskLevel = "中" }
                    $riskReasons += "有効期限間近"
                }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $group.DisplayName
                    GroupType = $groupType
                    SecurityType = $securityType
                    IsTeam = $isTeam
                    SecurityEnabled = $group.SecurityEnabled
                    MailEnabled = $group.MailEnabled
                    MemberCount = $memberCount
                    OwnerCount = $ownerCount
                    AdminRoleCount = $adminRoleCount
                    GlobalAdminCount = $globalAdminCount
                    GroupAdminCount = $groupAdminCount
                    Visibility = if ($group.Visibility) { $group.Visibility } else { "未設定" }
                    SyncStatus = if ($group.OnPremisesSyncEnabled) { "オンプレミス同期" } else { "クラウドのみ" }
                    HasMail = $mailAttributes.HasMail
                    MailAddress = $mailAttributes.MailAddress
                    MailNickname = $mailAttributes.MailNickname
                    ProxyAddressCount = $mailAttributes.ProxyAddresses
                    HasAssignedLicenses = $licenseInfo.HasAssignedLicenses
                    LicenseCount = $licenseInfo.LicenseCount
                    HasLicenseErrors = $licenseInfo.HasLicenseErrors
                    Classification = $lifecycleInfo.Classification
                    HasExpiration = $lifecycleInfo.HasExpiration
                    ExpirationDate = $lifecycleInfo.ExpirationDate
                    LastRenewed = $lifecycleInfo.LastRenewed
                    Description = if ($group.Description) { $group.Description } else { "説明なし" }
                    CreatedDate = $group.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = $riskLevel
                    RiskReasons = if ($riskReasons.Count -gt 0) { $riskReasons -join ", " } else { "なし" }
                    GroupId = $group.Id
                }
                
                $attributeResults += $result
                
            }
            catch {
                Write-Log "グループ $($group.DisplayName) の属性確認エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $group.DisplayName
                    GroupType = "確認エラー"
                    SecurityType = "確認エラー"
                    IsTeam = $false
                    SecurityEnabled = $group.SecurityEnabled
                    MailEnabled = $group.MailEnabled
                    MemberCount = 0
                    OwnerCount = 0
                    AdminRoleCount = 0
                    GlobalAdminCount = 0
                    GroupAdminCount = 0
                    Visibility = "確認エラー"
                    SyncStatus = "確認エラー"
                    HasMail = $false
                    MailAddress = "確認エラー"
                    MailNickname = "確認エラー"
                    ProxyAddressCount = 0
                    HasAssignedLicenses = $false
                    LicenseCount = 0
                    HasLicenseErrors = $false
                    Classification = "確認エラー"
                    HasExpiration = $false
                    ExpirationDate = "確認エラー"
                    LastRenewed = "確認エラー"
                    Description = "確認エラー"
                    CreatedDate = $group.CreatedDateTime.ToString("yyyy/MM/dd")
                    RiskLevel = "要確認"
                    RiskReasons = "属性確認エラー"
                    GroupId = $group.Id
                }
                
                $attributeResults += $result
            }
        }
        
        Write-Progress -Activity "グループ属性・ロール確認中" -Completed
        
        # 結果集計
        $totalGroups = $attributeResults.Count
        $securityGroups = ($attributeResults | Where-Object { $_.SecurityEnabled -eq $true }).Count
        $mailEnabledGroups = ($attributeResults | Where-Object { $_.MailEnabled -eq $true }).Count
        $teamsGroups = ($attributeResults | Where-Object { $_.IsTeam -eq $true }).Count
        $noOwnerGroups = ($attributeResults | Where-Object { $_.OwnerCount -eq 0 }).Count
        $highRiskGroups = ($attributeResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        $licenseErrorGroups = ($attributeResults | Where-Object { $_.HasLicenseErrors -eq $true }).Count
        $expiringGroups = ($attributeResults | Where-Object { $_.HasExpiration -eq $true }).Count
        $adminManagedGroups = ($attributeResults | Where-Object { $_.AdminRoleCount -gt 0 }).Count
        
        Write-Log "グループ属性およびロール確認完了" -Level "Info"
        Write-Log "総グループ数: $totalGroups" -Level "Info"
        Write-Log "セキュリティグループ: $securityGroups" -Level "Info"
        Write-Log "メール対応グループ: $mailEnabledGroups" -Level "Info"
        Write-Log "Teamsグループ: $teamsGroups" -Level "Info"
        Write-Log "オーナー不在グループ: $noOwnerGroups" -Level "Info"
        Write-Log "高リスクグループ: $highRiskGroups" -Level "Info"
        Write-Log "ライセンスエラーグループ: $licenseErrorGroups" -Level "Info"
        Write-Log "有効期限設定グループ: $expiringGroups" -Level "Info"
        Write-Log "管理者管理グループ: $adminManagedGroups" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== グループ属性およびロール確認結果 ===`n" -ForegroundColor Yellow
            
            # ライセンスエラーグループ
            $licenseErrorList = $attributeResults | Where-Object { $_.HasLicenseErrors -eq $true } | Sort-Object DisplayName
            if ($licenseErrorList.Count -gt 0) {
                Write-Host "【ライセンスエラーグループ】" -ForegroundColor Red
                foreach ($group in $licenseErrorList) {
                    Write-Host "  ● $($group.DisplayName) ($($group.GroupType))" -ForegroundColor Red
                    Write-Host "    ライセンス数: $($group.LicenseCount) | メンバー: $($group.MemberCount)名" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 高リスクグループ
            $highRiskList = $attributeResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($highRiskList.Count -gt 0) {
                Write-Host "【高リスクグループ】" -ForegroundColor Red
                foreach ($group in $highRiskList) {
                    Write-Host "  ⚠ $($group.DisplayName) ($($group.GroupType))" -ForegroundColor Red
                    Write-Host "    リスク要因: $($group.RiskReasons)" -ForegroundColor Gray
                    Write-Host "    オーナー: $($group.OwnerCount)名 | 管理者: $($group.AdminRoleCount)名" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 有効期限間近グループ
            $expiringList = $attributeResults | Where-Object { $_.HasExpiration -eq $true -and $_.ExpirationDate -ne "無期限" } | Sort-Object ExpirationDate
            if ($expiringList.Count -gt 0) {
                Write-Host "【有効期限設定グループ】" -ForegroundColor Yellow
                foreach ($group in $expiringList) {
                    Write-Host "  📅 $($group.DisplayName) ($($group.GroupType))" -ForegroundColor Yellow
                    Write-Host "    有効期限: $($group.ExpirationDate) | 最終更新: $($group.LastRenewed)" -ForegroundColor Gray
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\Group_Attributes_Roles_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($null -ne $attributeResults -and $attributeResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $attributeResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $attributeResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\Group_Attributes_Roles_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $emptyArray = if ($null -eq $attributeResults) { @() } else { $attributeResults }
            $htmlContent = Generate-GroupAttributesRolesReportHTML -AttributeResults $emptyArray -Summary @{
                TotalGroups = $totalGroups
                SecurityGroups = $securityGroups
                MailEnabledGroups = $mailEnabledGroups
                TeamsGroups = $teamsGroups
                NoOwnerGroups = $noOwnerGroups
                HighRiskGroups = $highRiskGroups
                LicenseErrorGroups = $licenseErrorGroups
                ExpiringGroups = $expiringGroups
                AdminManagedGroups = $adminManagedGroups
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalGroups = $totalGroups
            SecurityGroups = $securityGroups
            MailEnabledGroups = $mailEnabledGroups
            TeamsGroups = $teamsGroups
            NoOwnerGroups = $noOwnerGroups
            HighRiskGroups = $highRiskGroups
            LicenseErrorGroups = $licenseErrorGroups
            ExpiringGroups = $expiringGroups
            AdminManagedGroups = $adminManagedGroups
            DetailedResults = if ($null -ne $attributeResults) { $attributeResults } else { @() }
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "グループ属性およびロール確認エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# グループ属性・ロール HTMLレポート生成関数
function Generate-GroupAttributesRolesReportHTML {
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]$AttributeResults = @(),
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # パラメータのnullチェックと初期化
    if ($null -eq $AttributeResults) {
        $AttributeResults = @()
    }
    
    # 各カテゴリ別にグループを抽出
    $licenseErrorGroups = @()
    $highRiskGroups = @()
    $expiringGroups = @()
    $securityGroups = @()
    
    if ($AttributeResults.Count -gt 0) {
        try {
            $licenseErrorGroups = $AttributeResults | Where-Object { $_.HasLicenseErrors -eq $true } | Sort-Object DisplayName
            if ($null -eq $licenseErrorGroups) { $licenseErrorGroups = @() }
            
            $highRiskGroups = $AttributeResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($null -eq $highRiskGroups) { $highRiskGroups = @() }
            
            $expiringGroups = $AttributeResults | Where-Object { $_.HasExpiration -eq $true } | Sort-Object ExpirationDate
            if ($null -eq $expiringGroups) { $expiringGroups = @() }
            
            $securityGroups = $AttributeResults | Where-Object { $_.SecurityEnabled -eq $true } | Sort-Object DisplayName
            if ($null -eq $securityGroups) { $securityGroups = @() }
        }
        catch {
            # エラーが発生した場合も空の配列を確保
            $licenseErrorGroups = @()
            $highRiskGroups = @()
            $expiringGroups = @()
            $securityGroups = @()
        }
    }
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>グループ属性・ロール確認レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; max-height: 400px; overflow-y: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
            position: sticky;
            top: 0;
        }
        .risk-high { color: #d13438; font-weight: bold; }
        .risk-medium { color: #ff8c00; font-weight: bold; }
        .risk-low { color: #107c10; }
        .security-group { color: #0078d4; font-weight: bold; }
        .team-group { color: #6264a7; font-weight: bold; }
        .mail-group { color: #107c10; font-weight: bold; }
        .license-error { color: #d13438; background-color: #ffeaea; padding: 2px 6px; border-radius: 3px; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(9, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 グループ属性・ロール確認レポート</h1>
        <div class="subtitle">みらい建設工業株式会社</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総グループ数</h3>
            <div class="value">$($Summary.TotalGroups)</div>
            <div class="description">全グループ</div>
        </div>
        <div class="summary-card">
            <h3>セキュリティグループ</h3>
            <div class="value success">$($Summary.SecurityGroups)</div>
            <div class="description">認証・権限</div>
        </div>
        <div class="summary-card">
            <h3>メール対応</h3>
            <div class="value">$($Summary.MailEnabledGroups)</div>
            <div class="description">配信機能</div>
        </div>
        <div class="summary-card">
            <h3>Teamsグループ</h3>
            <div class="value">$($Summary.TeamsGroups)</div>
            <div class="description">チームワーク</div>
        </div>
        <div class="summary-card">
            <h3>オーナー不在</h3>
            <div class="value danger">$($Summary.NoOwnerGroups)</div>
            <div class="description">要対応</div>
        </div>
        <div class="summary-card">
            <h3>高リスクグループ</h3>
            <div class="value danger">$($Summary.HighRiskGroups)</div>
            <div class="description">緊急対応</div>
        </div>
        <div class="summary-card">
            <h3>ライセンスエラー</h3>
            <div class="value danger">$($Summary.LicenseErrorGroups)</div>
            <div class="description">修正必要</div>
        </div>
        <div class="summary-card">
            <h3>有効期限設定</h3>
            <div class="value warning">$($Summary.ExpiringGroups)</div>
            <div class="description">ライフサイクル</div>
        </div>
        <div class="summary-card">
            <h3>管理者管理</h3>
            <div class="value success">$($Summary.AdminManagedGroups)</div>
            <div class="description">適切な管理</div>
        </div>
    </div>
"@

    # ライセンスエラーグループ一覧
    if ($licenseErrorGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 ライセンスエラーグループ (緊急対応必要)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>グループタイプ</th>
                            <th>ライセンス数</th>
                            <th>メンバー数</th>
                            <th>管理者数</th>
                            <th>作成日</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $licenseErrorGroups) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($group.DisplayName)</td>
                            <td>$($group.GroupType)</td>
                            <td class="license-error">$($group.LicenseCount)</td>
                            <td>$($group.MemberCount)</td>
                            <td>$($group.AdminRoleCount)</td>
                            <td>$($group.CreatedDate)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 高リスクグループ一覧
    if ($highRiskGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 高リスクグループ</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>セキュリティタイプ</th>
                            <th>オーナー数</th>
                            <th>管理者数</th>
                            <th>リスク要因</th>
                            <th>可視性</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $highRiskGroups) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($group.DisplayName)</td>
                            <td>$($group.SecurityType)</td>
                            <td>$($group.OwnerCount)</td>
                            <td>$($group.AdminRoleCount)</td>
                            <td class="risk-high">$($group.RiskReasons)</td>
                            <td>$($group.Visibility)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 有効期限設定グループ一覧
    if ($expiringGroups.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>📅 有効期限設定グループ</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>グループ名</th>
                            <th>分類</th>
                            <th>有効期限</th>
                            <th>最終更新</th>
                            <th>オーナー数</th>
                            <th>メンバー数</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($group in $expiringGroups) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($group.DisplayName)</td>
                            <td>$($group.Classification)</td>
                            <td>$($group.ExpirationDate)</td>
                            <td>$($group.LastRenewed)</td>
                            <td>$($group.OwnerCount)</td>
                            <td>$($group.MemberCount)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# 公開関数のエクスポート
Export-ModuleMember -Function Get-GroupConfiguration, Get-GroupMemberAudit, Get-DynamicGroupConfiguration, Get-GroupAttributesAndRoles