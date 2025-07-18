#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.3.0' }

<#
.SYNOPSIS
OneDrive機能の包括的Pesterテストスイート

.DESCRIPTION
OneDrive管理機能（ストレージ管理、共有設定、同期エラー、外部共有分析）の単体・統合テスト

.NOTES
Version: 2025.7.17.1
Author: Dev2 - Test/QA Developer
#>

BeforeAll {
    $script:TestRootPath = Split-Path -Parent $PSScriptRoot
    $script:ScriptsPath = Join-Path $TestRootPath "Scripts"
    $script:ConfigPath = Join-Path $TestRootPath "Config\appsettings.json"
    
    # モジュールのインポート
    $script:AuthModule = Join-Path $ScriptsPath "Common\Authentication.psm1"
    $script:DataModule = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
    
    if (Test-Path $AuthModule) {
        Import-Module $AuthModule -Force
    }
    
    if (Test-Path $DataModule) {
        Import-Module $DataModule -Force
    }
    
    # テスト用データ
    $script:TestOneDriveData = @{
        Sites = @(
            [PSCustomObject]@{
                SiteId = "site-1"
                SiteUrl = "https://contoso.sharepoint.com/personal/yamada_contoso_com"
                Owner = "yamada@contoso.com"
                OwnerDisplayName = "山田太郎"
                StorageUsageCurrent = 15360  # MB (15GB)
                StorageQuota = 102400  # MB (100GB)
                StorageUsagePercent = 15
                LastActivityDate = (Get-Date).AddHours(-3)
                FileCount = 2543
                ActiveFileCount = 156
                IsDeleted = $false
                StorageWarningLevel = 90
                StorageMaximumLevel = 100
            },
            [PSCustomObject]@{
                SiteId = "site-2"
                SiteUrl = "https://contoso.sharepoint.com/personal/sato_contoso_com"
                Owner = "sato@contoso.com"
                OwnerDisplayName = "佐藤花子"
                StorageUsageCurrent = 92160  # MB (90GB)
                StorageQuota = 102400  # MB (100GB)
                StorageUsagePercent = 90
                LastActivityDate = (Get-Date).AddDays(-2)
                FileCount = 8765
                ActiveFileCount = 432
                IsDeleted = $false
                StorageWarningLevel = 90
                StorageMaximumLevel = 100
            }
        )
        
        SharedFiles = @(
            [PSCustomObject]@{
                FileId = "file-1"
                FileName = "営業報告書_2025Q1.xlsx"
                FilePath = "/Documents/Reports/営業報告書_2025Q1.xlsx"
                Owner = "yamada@contoso.com"
                SharedWith = @("sato@contoso.com", "tanaka@contoso.com")
                SharedWithExternal = @()
                SharingType = "Internal"
                PermissionLevel = "Edit"
                SharedDate = (Get-Date).AddDays(-7)
                LastModified = (Get-Date).AddDays(-1)
                FileSize = 2048  # KB
                IsInherited = $false
                AnonymousLink = $null
            },
            [PSCustomObject]@{
                FileId = "file-2"
                FileName = "プロジェクト計画.docx"
                FilePath = "/Projects/プロジェクト計画.docx"
                Owner = "sato@contoso.com"
                SharedWith = @()
                SharedWithExternal = @("external.user@partner.com")
                SharingType = "External"
                PermissionLevel = "View"
                SharedDate = (Get-Date).AddDays(-14)
                LastModified = (Get-Date).AddDays(-3)
                FileSize = 512  # KB
                IsInherited = $false
                AnonymousLink = "https://contoso.sharepoint.com/:w:/g/personal/sato_contoso_com/EaBC123..."
            },
            [PSCustomObject]@{
                FileId = "file-3"
                FileName = "社内規定集.pdf"
                FilePath = "/Policies/社内規定集.pdf"
                Owner = "admin@contoso.com"
                SharedWith = @("AllUsers@contoso.com")
                SharedWithExternal = @()
                SharingType = "Organization"
                PermissionLevel = "View"
                SharedDate = (Get-Date).AddMonths(-3)
                LastModified = (Get-Date).AddMonths(-1)
                FileSize = 5120  # KB
                IsInherited = $true
                AnonymousLink = $null
            }
        )
        
        SyncErrors = @(
            [PSCustomObject]@{
                ErrorId = "error-1"
                UserPrincipalName = "yamada@contoso.com"
                DeviceName = "DESKTOP-ABC123"
                ErrorType = "FileLocked"
                ErrorMessage = "ファイルが他のアプリケーションで使用されています"
                FilePath = "/Documents/Working/予算計画.xlsx"
                ErrorDateTime = (Get-Date).AddHours(-2)
                ErrorCount = 3
                LastAttempt = (Get-Date).AddMinutes(-15)
                IsResolved = $false
                Severity = "Warning"
            },
            [PSCustomObject]@{
                ErrorId = "error-2"
                UserPrincipalName = "sato@contoso.com"
                DeviceName = "LAPTOP-XYZ789"
                ErrorType = "PathTooLong"
                ErrorMessage = "ファイルパスが長すぎます (260文字を超えています)"
                FilePath = "/Projects/2025/Q1/CustomerA/Documentation/TechnicalSpecifications/Version2/Draft/最終版_レビュー済み_承認待ち_更新版.docx"
                ErrorDateTime = (Get-Date).AddDays(-1)
                ErrorCount = 10
                LastAttempt = (Get-Date).AddHours(-1)
                IsResolved = $false
                Severity = "Error"
            },
            [PSCustomObject]@{
                ErrorId = "error-3"
                UserPrincipalName = "tanaka@contoso.com"
                DeviceName = "SURFACE-123"
                ErrorType = "QuotaExceeded"
                ErrorMessage = "ストレージ容量が不足しています"
                FilePath = "/Videos/TrainingMaterial.mp4"
                ErrorDateTime = (Get-Date).AddDays(-3)
                ErrorCount = 1
                LastAttempt = (Get-Date).AddDays(-3)
                IsResolved = $true
                Severity = "Critical"
            }
        )
        
        ExternalSharing = @(
            [PSCustomObject]@{
                ShareId = "share-1"
                ResourceType = "File"
                ResourceName = "契約書テンプレート.docx"
                ResourcePath = "/Templates/契約書テンプレート.docx"
                Owner = "legal@contoso.com"
                SharedWithDomain = "partner.com"
                SharedWithEmail = "contact@partner.com"
                PermissionType = "View"
                ShareDate = (Get-Date).AddDays(-30)
                ExpirationDate = (Get-Date).AddDays(30)
                AccessCount = 15
                LastAccessed = (Get-Date).AddDays(-2)
                IsActive = $true
                RiskLevel = "Medium"
            },
            [PSCustomObject]@{
                ShareId = "share-2"
                ResourceType = "Folder"
                ResourceName = "PublicDocuments"
                ResourcePath = "/Shared/PublicDocuments"
                Owner = "marketing@contoso.com"
                SharedWithDomain = "anyone"
                SharedWithEmail = $null
                PermissionType = "View"
                ShareDate = (Get-Date).AddMonths(-6)
                ExpirationDate = $null
                AccessCount = 234
                LastAccessed = (Get-Date).AddHours(-5)
                IsActive = $true
                RiskLevel = "High"
            }
        )
    }
}

Describe "OneDrive - ストレージ管理テスト" -Tags @("Unit", "OneDrive", "Storage") {
    Context "ストレージ使用状況の取得" {
        It "OneDriveサイト一覧が取得できること" {
            Mock Get-SPOSite {
                return $TestOneDriveData.Sites
            }
            
            $sites = Get-SPOSite -IncludePersonalSite $true
            $sites | Should -Not -BeNullOrEmpty
            $sites.Count | Should -Be 2
        }
        
        It "ストレージ使用率が計算できること" {
            $sites = $TestOneDriveData.Sites
            
            foreach ($site in $sites) {
                $calculatedPercent = [math]::Round(($site.StorageUsageCurrent / $site.StorageQuota) * 100, 2)
                $calculatedPercent | Should -Be $site.StorageUsagePercent
            }
        }
        
        It "ストレージ警告閾値を超えたサイトが識別できること" {
            $warningThreshold = 90
            $criticalSites = $TestOneDriveData.Sites | Where-Object {
                $_.StorageUsagePercent -ge $warningThreshold
            }
            
            $criticalSites.Count | Should -Be 1
            $criticalSites[0].Owner | Should -Be "sato@contoso.com"
            $criticalSites[0].StorageUsagePercent | Should -Be 90
        }
        
        It "アクティブファイル率が計算できること" {
            $sites = $TestOneDriveData.Sites
            
            foreach ($site in $sites) {
                if ($site.FileCount -gt 0) {
                    $activeFileRate = [math]::Round(($site.ActiveFileCount / $site.FileCount) * 100, 2)
                    $activeFileRate | Should -BeGreaterThan 0
                }
            }
        }
    }
    
    Context "ストレージ統計分析" {
        It "組織全体のストレージ使用状況が集計できること" {
            $totalStats = [PSCustomObject]@{
                TotalSites = $TestOneDriveData.Sites.Count
                TotalStorageQuotaMB = ($TestOneDriveData.Sites | Measure-Object -Property StorageQuota -Sum).Sum
                TotalStorageUsedMB = ($TestOneDriveData.Sites | Measure-Object -Property StorageUsageCurrent -Sum).Sum
                AverageUsagePercent = [math]::Round(
                    ($TestOneDriveData.Sites | Measure-Object -Property StorageUsagePercent -Average).Average, 2
                )
                TotalFiles = ($TestOneDriveData.Sites | Measure-Object -Property FileCount -Sum).Sum
                SitesNearCapacity = ($TestOneDriveData.Sites | Where-Object { $_.StorageUsagePercent -ge 80 }).Count
            }
            
            $totalStats.TotalSites | Should -Be 2
            $totalStats.TotalStorageQuotaMB | Should -Be 204800  # 200GB
            $totalStats.TotalStorageUsedMB | Should -Be 107520   # 105GB
            $totalStats.AverageUsagePercent | Should -Be 52.5
            $totalStats.TotalFiles | Should -Be 11308
            $totalStats.SitesNearCapacity | Should -Be 1
        }
        
        It "ストレージ使用トレンドが分析できること" {
            # 過去のデータをシミュレート
            $historicalData = @(
                [PSCustomObject]@{ Date = (Get-Date).AddMonths(-3); UsageGB = 85 },
                [PSCustomObject]@{ Date = (Get-Date).AddMonths(-2); UsageGB = 92 },
                [PSCustomObject]@{ Date = (Get-Date).AddMonths(-1); UsageGB = 98 },
                [PSCustomObject]@{ Date = (Get-Date); UsageGB = 105 }
            )
            
            # 月間成長率の計算
            $growthRates = for ($i = 1; $i -lt $historicalData.Count; $i++) {
                $previous = $historicalData[$i-1].UsageGB
                $current = $historicalData[$i].UsageGB
                [math]::Round((($current - $previous) / $previous) * 100, 2)
            }
            
            $averageGrowthRate = [math]::Round(($growthRates | Measure-Object -Average).Average, 2)
            $averageGrowthRate | Should -BeGreaterThan 5  # 5%以上の成長
        }
    }
    
    Context "ストレージ最適化提案" {
        It "非アクティブファイルの識別ができること" {
            $inactiveThresholdDays = 90
            $sites = $TestOneDriveData.Sites
            
            foreach ($site in $sites) {
                $inactiveFileCount = $site.FileCount - $site.ActiveFileCount
                $inactiveFilePercent = if ($site.FileCount -gt 0) {
                    [math]::Round(($inactiveFileCount / $site.FileCount) * 100, 2)
                } else { 0 }
                
                if ($inactiveFilePercent -gt 50) {
                    # 50%以上が非アクティブの場合、最適化候補
                    $site.Owner | Should -BeIn @("yamada@contoso.com", "sato@contoso.com")
                }
            }
        }
        
        It "大容量ファイルの検出ができること" {
            Mock Get-PnPListItem {
                return @(
                    [PSCustomObject]@{
                        FieldValues = @{
                            FileLeafRef = "大容量動画.mp4"
                            FileSizeDisplay = "2048000"  # 2GB in KB
                            Modified = (Get-Date).AddDays(-60)
                            Editor = @{ Email = "yamada@contoso.com" }
                        }
                    },
                    [PSCustomObject]@{
                        FieldValues = @{
                            FileLeafRef = "アーカイブデータ.zip"
                            FileSizeDisplay = "5120000"  # 5GB in KB
                            Modified = (Get-Date).AddDays(-180)
                            Editor = @{ Email = "sato@contoso.com" }
                        }
                    }
                )
            }
            
            $largeFiles = Get-PnPListItem -List "Documents" -PageSize 5000
            $largeFilesOver1GB = $largeFiles | Where-Object {
                [int]$_.FieldValues.FileSizeDisplay -gt 1048576  # 1GB in KB
            }
            
            $largeFilesOver1GB.Count | Should -Be 2
        }
    }
}

Describe "OneDrive - 共有設定管理テスト" -Tags @("Unit", "OneDrive", "Sharing") {
    Context "共有ファイル・フォルダの管理" {
        It "共有アイテム一覧が取得できること" {
            Mock Get-SharedItems {
                return $TestOneDriveData.SharedFiles
            }
            
            $sharedItems = Get-SharedItems
            $sharedItems | Should -Not -BeNullOrEmpty
            $sharedItems.Count | Should -Be 3
        }
        
        It "共有タイプ別の分類ができること" {
            $sharingStats = $TestOneDriveData.SharedFiles | Group-Object -Property SharingType
            
            $internalSharing = $sharingStats | Where-Object { $_.Name -eq "Internal" }
            $internalSharing.Count | Should -Be 1
            
            $externalSharing = $sharingStats | Where-Object { $_.Name -eq "External" }
            $externalSharing.Count | Should -Be 1
            
            $organizationSharing = $sharingStats | Where-Object { $_.Name -eq "Organization" }
            $organizationSharing.Count | Should -Be 1
        }
        
        It "外部共有ファイルが識別できること" {
            $externalSharedFiles = $TestOneDriveData.SharedFiles | Where-Object {
                $_.SharedWithExternal.Count -gt 0 -or $_.SharingType -eq "External"
            }
            
            $externalSharedFiles.Count | Should -Be 1
            $externalSharedFiles[0].FileName | Should -Be "プロジェクト計画.docx"
            $externalSharedFiles[0].SharedWithExternal | Should -Contain "external.user@partner.com"
        }
        
        It "匿名リンクの存在が検出できること" {
            $anonymousLinks = $TestOneDriveData.SharedFiles | Where-Object {
                $_.AnonymousLink -ne $null
            }
            
            $anonymousLinks.Count | Should -Be 1
            $anonymousLinks[0].FileName | Should -Be "プロジェクト計画.docx"
            $anonymousLinks[0].AnonymousLink | Should -Match "https://.*sharepoint.com/"
        }
    }
    
    Context "共有権限の分析" {
        It "権限レベル別の統計が取得できること" {
            $permissionStats = $TestOneDriveData.SharedFiles | Group-Object -Property PermissionLevel |
                Select-Object Name, Count, @{
                    Name = 'Percentage'
                    Expression = { [math]::Round(($_.Count / $TestOneDriveData.SharedFiles.Count) * 100, 2) }
                }
            
            $editPermissions = $permissionStats | Where-Object { $_.Name -eq "Edit" }
            $editPermissions.Count | Should -Be 1
            $editPermissions.Percentage | Should -Be 33.33
            
            $viewPermissions = $permissionStats | Where-Object { $_.Name -eq "View" }
            $viewPermissions.Count | Should -Be 2
            $viewPermissions.Percentage | Should -Be 66.67
        }
        
        It "過度に共有されているファイルが検出できること" {
            $oversharedThreshold = 5  # 5人以上と共有
            
            $oversharedFiles = $TestOneDriveData.SharedFiles | Where-Object {
                $totalShared = $_.SharedWith.Count + $_.SharedWithExternal.Count
                $totalShared -ge $oversharedThreshold -or $_.SharingType -eq "Organization"
            }
            
            $oversharedFiles.Count | Should -BeGreaterThan 0
            $oversharedFiles | Where-Object { $_.SharingType -eq "Organization" } | Should -Not -BeNullOrEmpty
        }
        
        It "継承された権限が識別できること" {
            $inheritedPermissions = $TestOneDriveData.SharedFiles | Where-Object {
                $_.IsInherited -eq $true
            }
            
            $inheritedPermissions.Count | Should -Be 1
            $inheritedPermissions[0].FileName | Should -Be "社内規定集.pdf"
        }
    }
}

Describe "OneDrive - 同期エラー分析テスト" -Tags @("Unit", "OneDrive", "SyncErrors") {
    Context "同期エラーの検出と分類" {
        It "同期エラー一覧が取得できること" {
            Mock Get-OneDriveSyncErrors {
                return $TestOneDriveData.SyncErrors
            }
            
            $syncErrors = Get-OneDriveSyncErrors
            $syncErrors | Should -Not -BeNullOrEmpty
            $syncErrors.Count | Should -Be 3
        }
        
        It "エラータイプ別の分類ができること" {
            $errorTypes = $TestOneDriveData.SyncErrors | Group-Object -Property ErrorType
            
            $errorTypes.Count | Should -Be 3
            $errorTypes.Name | Should -Contain "FileLocked"
            $errorTypes.Name | Should -Contain "PathTooLong"
            $errorTypes.Name | Should -Contain "QuotaExceeded"
        }
        
        It "重要度別のエラー統計が取得できること" {
            $severityStats = $TestOneDriveData.SyncErrors | Group-Object -Property Severity |
                Select-Object Name, Count, @{
                    Name = 'Percentage'
                    Expression = { [math]::Round(($_.Count / $TestOneDriveData.SyncErrors.Count) * 100, 2) }
                }
            
            $criticalErrors = $severityStats | Where-Object { $_.Name -eq "Critical" }
            $criticalErrors.Count | Should -Be 1
            
            $errorErrors = $severityStats | Where-Object { $_.Name -eq "Error" }
            $errorErrors.Count | Should -Be 1
            
            $warningErrors = $severityStats | Where-Object { $_.Name -eq "Warning" }
            $warningErrors.Count | Should -Be 1
        }
        
        It "未解決エラーが識別できること" {
            $unresolvedErrors = $TestOneDriveData.SyncErrors | Where-Object {
                $_.IsResolved -eq $false
            }
            
            $unresolvedErrors.Count | Should -Be 2
            $unresolvedErrors | Where-Object { $_.ErrorType -eq "PathTooLong" } | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "同期エラーの影響分析" {
        It "ユーザー別のエラー集計ができること" {
            $errorsByUser = $TestOneDriveData.SyncErrors | Group-Object -Property UserPrincipalName |
                Select-Object Name, @{
                    Name = 'TotalErrors'
                    Expression = { ($_.Group | Measure-Object -Property ErrorCount -Sum).Sum }
                }, @{
                    Name = 'UnresolvedCount'
                    Expression = { ($_.Group | Where-Object { -not $_.IsResolved }).Count }
                }
            
            $errorsByUser.Count | Should -Be 3
            
            $satoErrors = $errorsByUser | Where-Object { $_.Name -eq "sato@contoso.com" }
            $satoErrors.TotalErrors | Should -Be 10
            $satoErrors.UnresolvedCount | Should -Be 1
        }
        
        It "デバイス別のエラー分析ができること" {
            $errorsByDevice = $TestOneDriveData.SyncErrors | Group-Object -Property DeviceName
            
            $errorsByDevice.Count | Should -Be 3
            $errorsByDevice.Name | Should -Contain "DESKTOP-ABC123"
            $errorsByDevice.Name | Should -Contain "LAPTOP-XYZ789"
            $errorsByDevice.Name | Should -Contain "SURFACE-123"
        }
        
        It "エラーの発生頻度が分析できること" {
            $recentErrors = $TestOneDriveData.SyncErrors | Where-Object {
                $_.ErrorDateTime -ge (Get-Date).AddDays(-7)
            }
            
            $errorFrequency = $recentErrors | Group-Object -Property {
                $_.ErrorDateTime.Date
            } | Select-Object Name, Count
            
            $recentErrors.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "同期エラーの解決支援" {
        It "パス長エラーの詳細情報が取得できること" {
            $pathTooLongErrors = $TestOneDriveData.SyncErrors | Where-Object {
                $_.ErrorType -eq "PathTooLong"
            }
            
            foreach ($error in $pathTooLongErrors) {
                $error.FilePath.Length | Should -BeGreaterThan 100
                $error.ErrorMessage | Should -Match "260文字"
            }
        }
        
        It "ストレージ容量エラーの影響ユーザーが特定できること" {
            $quotaErrors = $TestOneDriveData.SyncErrors | Where-Object {
                $_.ErrorType -eq "QuotaExceeded"
            }
            
            foreach ($error in $quotaErrors) {
                # 該当ユーザーのストレージ使用率を確認
                $userSite = $TestOneDriveData.Sites | Where-Object {
                    $_.Owner -eq $error.UserPrincipalName
                }
                
                if ($userSite) {
                    $userSite.StorageUsagePercent | Should -BeGreaterOrEqual 90
                }
            }
        }
    }
}

Describe "OneDrive - 外部共有分析テスト" -Tags @("Unit", "OneDrive", "ExternalSharing") {
    Context "外部共有の検出と分類" {
        It "外部共有リソース一覧が取得できること" {
            Mock Get-ExternalSharingReport {
                return $TestOneDriveData.ExternalSharing
            }
            
            $externalShares = Get-ExternalSharingReport
            $externalShares | Should -Not -BeNullOrEmpty
            $externalShares.Count | Should -Be 2
        }
        
        It "共有先ドメイン別の分類ができること" {
            $sharesByDomain = $TestOneDriveData.ExternalSharing | Group-Object -Property SharedWithDomain
            
            $partnerShares = $sharesByDomain | Where-Object { $_.Name -eq "partner.com" }
            $partnerShares.Count | Should -Be 1
            
            $anyoneShares = $sharesByDomain | Where-Object { $_.Name -eq "anyone" }
            $anyoneShares.Count | Should -Be 1
        }
        
        It "リスクレベル別の統計が取得できること" {
            $riskStats = $TestOneDriveData.ExternalSharing | Group-Object -Property RiskLevel
            
            $highRiskShares = $riskStats | Where-Object { $_.Name -eq "High" }
            $highRiskShares.Count | Should -Be 1
            
            $mediumRiskShares = $riskStats | Where-Object { $_.Name -eq "Medium" }
            $mediumRiskShares.Count | Should -Be 1
        }
        
        It "有効期限切れ間近の共有が検出できること" {
            $expirationWarningDays = 30
            $expirationThreshold = (Get-Date).AddDays($expirationWarningDays)
            
            $expiringShares = $TestOneDriveData.ExternalSharing | Where-Object {
                $_.ExpirationDate -ne $null -and $_.ExpirationDate -le $expirationThreshold
            }
            
            $expiringShares.Count | Should -Be 1
            $expiringShares[0].ResourceName | Should -Be "契約書テンプレート.docx"
        }
    }
    
    Context "外部共有のアクセス分析" {
        It "アクセス頻度の高い共有が識別できること" {
            $highAccessThreshold = 50
            
            $highAccessShares = $TestOneDriveData.ExternalSharing | Where-Object {
                $_.AccessCount -ge $highAccessThreshold
            }
            
            $highAccessShares.Count | Should -Be 1
            $highAccessShares[0].ResourceName | Should -Be "PublicDocuments"
            $highAccessShares[0].AccessCount | Should -Be 234
        }
        
        It "最近アクセスされた共有が取得できること" {
            $recentAccessThreshold = (Get-Date).AddDays(-7)
            
            $recentlyAccessed = $TestOneDriveData.ExternalSharing | Where-Object {
                $_.LastAccessed -ge $recentAccessThreshold
            }
            
            $recentlyAccessed.Count | Should -Be 2
        }
        
        It "非アクティブな外部共有が検出できること" {
            $inactiveThresholdDays = 90
            $inactiveThreshold = (Get-Date).AddDays(-$inactiveThresholdDays)
            
            $inactiveShares = $TestOneDriveData.ExternalSharing | Where-Object {
                $_.LastAccessed -lt $inactiveThreshold -and $_.IsActive
            }
            
            # テストデータでは全て最近アクセスされているため0
            $inactiveShares.Count | Should -Be 0
        }
    }
    
    Context "外部共有のセキュリティ評価" {
        It "匿名共有（anyone）が検出できること" {
            $anonymousShares = $TestOneDriveData.ExternalSharing | Where-Object {
                $_.SharedWithDomain -eq "anyone"
            }
            
            $anonymousShares.Count | Should -Be 1
            $anonymousShares[0].RiskLevel | Should -Be "High"
            $anonymousShares[0].PermissionType | Should -Be "View"  # 最低限の権限であることを確認
        }
        
        It "編集権限を持つ外部共有が識別できること" {
            $editableExternalShares = $TestOneDriveData.ExternalSharing | Where-Object {
                $_.PermissionType -eq "Edit"
            }
            
            # テストデータでは外部共有は全てView権限
            $editableExternalShares.Count | Should -Be 0
        }
        
        It "期限なし外部共有が検出できること" {
            $noExpirationShares = $TestOneDriveData.ExternalSharing | Where-Object {
                $_.ExpirationDate -eq $null
            }
            
            $noExpirationShares.Count | Should -Be 1
            $noExpirationShares[0].ResourceName | Should -Be "PublicDocuments"
            $noExpirationShares[0].RiskLevel | Should -Be "High"
        }
    }
}

Describe "OneDrive - セキュリティとコンプライアンステスト" -Tags @("Security", "OneDrive", "Compliance") {
    Context "データ漏洩防止（DLP）" {
        It "機密データの外部共有が検出できること" {
            Mock Get-DLPComplianceRule {
                return @(
                    [PSCustomObject]@{
                        Name = "機密情報保護ルール"
                        ContentContainsSensitiveInformation = @(
                            @{ Name = "クレジットカード番号" },
                            @{ Name = "社会保障番号" },
                            @{ Name = "銀行口座番号" }
                        )
                    }
                )
            }
            
            # 機密情報を含む可能性のあるファイル名パターン
            $sensitivePatterns = @("契約", "機密", "個人情報", "クレジット", "口座")
            
            $potentiallySensitive = $TestOneDriveData.SharedFiles | Where-Object {
                $fileName = $_.FileName
                $isSensitive = $false
                foreach ($pattern in $sensitivePatterns) {
                    if ($fileName -match $pattern) {
                        $isSensitive = $true
                        break
                    }
                }
                $isSensitive -and ($_.SharedWithExternal.Count -gt 0 -or $_.SharingType -eq "External")
            }
            
            # "契約書テンプレート.docx" が該当しないことを確認（外部共有されていない）
            $potentiallySensitive.Count | Should -Be 0
        }
        
        It "DLPポリシー違反が記録されていること" {
            Mock Get-DLPComplianceCase {
                return @(
                    [PSCustomObject]@{
                        Name = "DLP-2025-001"
                        Status = "Active"
                        CreatedDateTime = (Get-Date).AddDays(-5)
                        Severity = "High"
                        ViolationType = "外部共有"
                        UserPrincipalName = "user@contoso.com"
                    }
                )
            }
            
            $dlpCases = Get-DLPComplianceCase
            $activeCases = $dlpCases | Where-Object { $_.Status -eq "Active" }
            
            $activeCases.Count | Should -BeGreaterThan 0
            $activeCases[0].Severity | Should -Be "High"
        }
    }
    
    Context "アクセス制御とガバナンス" {
        It "管理者による一括共有設定が適用されていること" {
            Mock Get-SPOTenant {
                return [PSCustomObject]@{
                    SharingCapability = "ExternalUserSharingOnly"
                    DefaultSharingPermission = "View"
                    RequireAcceptingAccountMatchInvitedAccount = $true
                    PreventExternalUsersFromResharing = $true
                    ShowEveryoneClaim = $false
                    ShowAllUsersClaim = $false
                    NotifyOwnersWhenItemsReshared = $true
                    DefaultLinkPermission = "View"
                    DisallowInfectedFileDownload = $true
                }
            }
            
            $tenantSettings = Get-SPOTenant
            
            # セキュリティベストプラクティスの確認
            $tenantSettings.SharingCapability | Should -Not -Be "ExternalUserAndGuestSharing"
            $tenantSettings.DefaultSharingPermission | Should -Be "View"
            $tenantSettings.PreventExternalUsersFromResharing | Should -Be $true
            $tenantSettings.ShowEveryoneClaim | Should -Be $false
            $tenantSettings.DisallowInfectedFileDownload | Should -Be $true
        }
        
        It "条件付きアクセスポリシーが適用されていること" {
            Mock Get-ConditionalAccessPolicy {
                return [PSCustomObject]@{
                    DisplayName = "OneDrive外部アクセス制限"
                    State = "enabled"
                    Conditions = @{
                        Applications = @{ IncludeApplications = @("00000003-0000-0ff1-ce00-000000000000") }  # SharePoint
                        Locations = @{ IncludeLocations = "All"; ExcludeLocations = "AllTrusted" }
                    }
                    GrantControls = @{
                        BuiltInControls = @("mfa", "compliantDevice")
                    }
                }
            }
            
            $policy = Get-ConditionalAccessPolicy
            
            $policy.State | Should -Be "enabled"
            $policy.GrantControls.BuiltInControls | Should -Contain "mfa"
            $policy.GrantControls.BuiltInControls | Should -Contain "compliantDevice"
        }
    }
    
    Context "ISO/IEC 27001準拠確認" {
        It "監査ログが有効化されていること" {
            Mock Get-SPOTenant {
                return [PSCustomObject]@{
                    EnableAuditLog = $true
                    AuditLogRetentionPeriod = 365
                }
            }
            
            $auditSettings = Get-SPOTenant
            
            $auditSettings.EnableAuditLog | Should -Be $true
            $auditSettings.AuditLogRetentionPeriod | Should -BeGreaterOrEqual 365
        }
        
        It "データ分類ラベルが適用可能であること" {
            Mock Get-Label {
                return @(
                    [PSCustomObject]@{ DisplayName = "公開"; Guid = [Guid]::NewGuid() },
                    [PSCustomObject]@{ DisplayName = "社内限定"; Guid = [Guid]::NewGuid() },
                    [PSCustomObject]@{ DisplayName = "機密"; Guid = [Guid]::NewGuid() },
                    [PSCustomObject]@{ DisplayName = "極秘"; Guid = [Guid]::NewGuid() }
                )
            }
            
            $labels = Get-Label
            $labels.Count | Should -BeGreaterOrEqual 3
            
            $requiredLabels = @("公開", "社内限定", "機密")
            foreach ($required in $requiredLabels) {
                $labels.DisplayName | Should -Contain $required
            }
        }
        
        It "定期的なアクセスレビューが設定されていること" {
            Mock Get-AccessReview {
                return [PSCustomObject]@{
                    DisplayName = "OneDrive外部共有四半期レビュー"
                    Status = "InProgress"
                    StartDateTime = (Get-Date).AddDays(-7)
                    EndDateTime = (Get-Date).AddDays(7)
                    ReviewerType = "Manager"
                    RecurrenceType = "quarterly"
                    Scope = @{
                        Query = "/external-sharing"
                        QueryType = "MicrosoftGraph"
                    }
                }
            }
            
            $accessReview = Get-AccessReview
            
            $accessReview.RecurrenceType | Should -Be "quarterly"
            $accessReview.Status | Should -BeIn @("NotStarted", "InProgress", "Completed")
        }
    }
}

Describe "OneDrive - パフォーマンステスト" -Tags @("Performance", "OneDrive") {
    Context "大規模データ処理性能" {
        It "10000サイトの処理が15秒以内に完了すること" {
            # 大量のOneDriveサイトを生成
            $largeSiteSet = @()
            for ($i = 1; $i -le 10000; $i++) {
                $largeSiteSet += [PSCustomObject]@{
                    SiteId = "site-$i"
                    Owner = "user$i@contoso.com"
                    StorageUsageCurrent = Get-Random -Minimum 1024 -Maximum 102400
                    StorageQuota = 102400
                    FileCount = Get-Random -Minimum 100 -Maximum 10000
                    LastActivityDate = (Get-Date).AddDays(-(Get-Random -Maximum 365))
                }
            }
            
            $measure = Measure-Command {
                # ストレージ使用率の計算
                $siteStats = $largeSiteSet | ForEach-Object {
                    [PSCustomObject]@{
                        SiteId = $_.SiteId
                        UsagePercent = [math]::Round(($_.StorageUsageCurrent / $_.StorageQuota) * 100, 2)
                        IsNearCapacity = (($_.StorageUsageCurrent / $_.StorageQuota) -ge 0.9)
                    }
                }
                
                # 統計情報の集計
                $summary = @{
                    TotalSites = $largeSiteSet.Count
                    SitesNearCapacity = ($siteStats | Where-Object { $_.IsNearCapacity }).Count
                    AverageUsage = ($siteStats | Measure-Object -Property UsagePercent -Average).Average
                    TotalStorage = ($largeSiteSet | Measure-Object -Property StorageUsageCurrent -Sum).Sum
                }
                
                # アクティブサイトの抽出
                $activeSites = $largeSiteSet | Where-Object {
                    $_.LastActivityDate -ge (Get-Date).AddDays(-30)
                }
            }
            
            $measure.TotalSeconds | Should -BeLessThan 15
        }
        
        It "100000共有アイテムの分析が20秒以内に完了すること" {
            # 大量の共有アイテムを生成
            $largeShareSet = @()
            $domains = @("contoso.com", "partner.com", "vendor.com", "customer.com", "anyone")
            
            for ($i = 1; $i -le 100000; $i++) {
                $largeShareSet += [PSCustomObject]@{
                    FileId = "file-$i"
                    Owner = "user$($i % 1000)@contoso.com"
                    SharedWithDomain = $domains[($i % 5)]
                    SharingType = if ($i % 5 -eq 4) { "External" } else { "Internal" }
                    AccessCount = Get-Random -Maximum 1000
                    LastAccessed = (Get-Date).AddDays(-(Get-Random -Maximum 180))
                }
            }
            
            $measure = Measure-Command {
                # 外部共有の分析
                $externalShares = $largeShareSet | Where-Object { $_.SharingType -eq "External" }
                
                # ドメイン別集計
                $sharesByDomain = $largeShareSet | Group-Object -Property SharedWithDomain
                
                # 高アクセス共有の特定
                $highAccessShares = $largeShareSet | Where-Object { $_.AccessCount -gt 500 }
                
                # リスク評価
                $riskAssessment = $largeShareSet | Where-Object {
                    $_.SharedWithDomain -eq "anyone" -or 
                    ($_.SharingType -eq "External" -and $_.AccessCount -gt 100)
                } | Select-Object -First 1000
            }
            
            $measure.TotalSeconds | Should -BeLessThan 20
        }
    }
    
    Context "メモリ効率性" {
        It "大規模ファイルリスト処理時のメモリ使用が適切であること" {
            [System.GC]::Collect()
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # 大量のファイル情報を処理
            $fileList = @()
            for ($i = 1; $i -le 50000; $i++) {
                $fileList += [PSCustomObject]@{
                    Id = [Guid]::NewGuid()
                    Name = "Document_$i.docx"
                    Path = "/Documents/Folder$($i % 100)/Document_$i.docx"
                    Size = Get-Random -Minimum 1024 -Maximum 10485760  # 1KB to 10MB
                    Modified = (Get-Date).AddDays(-(Get-Random -Maximum 365))
                    SharedWith = if ($i % 10 -eq 0) { 1..5 | ForEach-Object { "user$_@contoso.com" } } else { @() }
                }
            }
            
            # ファイル処理とフィルタリング
            $processedFiles = $fileList | Where-Object { $_.Size -gt 1048576 } | 
                Select-Object Name, @{
                    Name = 'SizeMB'
                    Expression = { [math]::Round($_.Size / 1MB, 2) }
                }, Modified
            
            [System.GC]::Collect()
            $finalMemory = [System.GC]::GetTotalMemory($false)
            
            $memoryIncreaseMB = ($finalMemory - $initialMemory) / 1MB
            $memoryIncreaseMB | Should -BeLessThan 500
        }
    }
}

AfterAll {
    Write-Host "`n✅ OneDrive機能テストスイート完了" -ForegroundColor Green
}