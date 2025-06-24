# ================================================================================
# SafeDataProvider.psm1
# Microsoft 365データ取得のフォールバック機能
# 認証失敗時の安全なデータ提供
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force

# 権限監査用の安全なサンプルデータ生成
function Get-SafePermissionAuditData {
    param(
        [int]$UserCount = 25,
        [int]$GroupCount = 10
    )
    
    try {
        Write-Log "安全な権限監査データを生成中..." -Level "Info"
        
        $auditData = @()
        
        # 実際の組織に近いユーザーデータ
        $departments = @("総務部", "営業部", "技術部", "経理部", "人事部", "マーケティング部", "IT部")
        $jobTitles = @("部長", "課長", "係長", "主任", "一般職", "アシスタント", "スペシャリスト")
        $riskLevels = @("低", "中", "高")
        
        for ($i = 1; $i -le $UserCount; $i++) {
            $department = $departments | Get-Random
            $jobTitle = $jobTitles | Get-Random
            $groupCount = Get-Random -Minimum 1 -Maximum 15
            $licenseCount = Get-Random -Minimum 1 -Maximum 5
            
            # リスク評価ロジック
            $riskLevel = "低"
            $action = "定期確認"
            
            if ($groupCount -gt 10) {
                $riskLevel = "高"
                $action = "権限見直し要"
            } elseif ($groupCount -gt 5) {
                $riskLevel = "中"
                $action = "権限確認"
            }
            
            $auditData += [PSCustomObject]@{
                種別 = "ユーザー"
                名前 = "ユーザー${i}（${department}）"
                プリンシパル = "user${i}@miraiconst.onmicrosoft.com"
                部署 = $department
                役職 = $jobTitle
                グループ数 = $groupCount
                ライセンス数 = $licenseCount
                リスクレベル = $riskLevel
                最終確認 = (Get-Date).ToString("yyyy-MM-dd")
                推奨アクション = $action
                備考 = "フォールバックデータ（認証テスト後に実データに更新）"
            }
        }
        
        # グループデータ
        $groupTypes = @("セキュリティ", "Microsoft 365", "配布", "Teams")
        for ($i = 1; $i -le $GroupCount; $i++) {
            $memberCount = Get-Random -Minimum 5 -Maximum 50
            $groupType = $groupTypes | Get-Random
            
            $riskLevel = "低"
            $action = "定期確認"
            
            if ($memberCount -gt 30) {
                $riskLevel = "高"
                $action = "メンバー見直し要"
            } elseif ($memberCount -gt 15) {
                $riskLevel = "中"
                $action = "メンバー確認"
            }
            
            $auditData += [PSCustomObject]@{
                種別 = "グループ"
                名前 = "グループ${i}（${groupType}）"
                プリンシパル = $groupType
                部署 = "-"
                役職 = "-"
                グループ数 = "-"
                ライセンス数 = "-"
                メンバー数 = $memberCount
                リスクレベル = $riskLevel
                最終確認 = (Get-Date).ToString("yyyy-MM-dd")
                推奨アクション = $action
                備考 = "フォールバックデータ（認証後に実データに更新）"
            }
        }
        
        Write-Log "安全な権限監査データ生成完了: $($auditData.Count)件" -Level "Info"
        return $auditData
    }
    catch {
        Write-Log "安全データ生成エラー: $($_.Exception.Message)" -Level "Error"
        
        # 最低限のデータ
        return @(
            [PSCustomObject]@{
                種別 = "システム"
                名前 = "データ取得エラー"
                プリンシパル = "認証が必要"
                部署 = "システム"
                役職 = "-"
                グループ数 = 0
                ライセンス数 = 0
                リスクレベル = "確認要"
                最終確認 = (Get-Date).ToString("yyyy-MM-dd")
                推奨アクション = "Microsoft Graph接続確認"
                備考 = "認証後に実データが表示されます"
            }
        )
    }
}

# セキュリティ分析用の安全なサンプルデータ生成
function Get-SafeSecurityAnalysisData {
    param(
        [int]$AlertCount = 20
    )
    
    try {
        Write-Log "安全なセキュリティ分析データを生成中..." -Level "Info"
        
        $securityData = @()
        $categories = @("サインイン分析", "アカウント状況", "ライセンス監査", "アクセス監視", "リスク評価")
        $riskLevels = @("低", "中", "高")
        $statuses = @("正常", "注意", "警告")
        $locations = @("東京, 日本", "大阪, 日本", "名古屋, 日本", "福岡, 日本")
        
        for ($i = 1; $i -le $AlertCount; $i++) {
            $category = $categories | Get-Random
            $riskLevel = $riskLevels | Get-Random
            $status = $statuses | Get-Random
            $location = $locations | Get-Random
            
            # リスクスコア計算
            $riskScore = switch ($riskLevel) {
                "高" { Get-Random -Minimum 8 -Maximum 10 }
                "中" { Get-Random -Minimum 4 -Maximum 7 }
                "低" { Get-Random -Minimum 1 -Maximum 3 }
            }
            
            $securityData += [PSCustomObject]@{
                ユーザー名 = "ユーザー${i}（${category}）"
                プリンシパル = "user${i}@miraiconst.onmicrosoft.com"
                カテゴリ = $category
                アカウント状態 = if ($status -eq "正常") { "有効" } else { "要確認" }
                最終サインイン = (Get-Date).AddDays(-1 * (Get-Random -Minimum 1 -Maximum 30)).ToString("yyyy/MM/dd")
                サインインリスク = $riskLevel
                場所 = $location
                リスク要因 = if ($riskLevel -eq "高") { "複数要因検出" } elseif ($riskLevel -eq "中") { "注意要因あり" } else { "なし" }
                リスクスコア = $riskScore
                総合リスク = $riskLevel
                推奨対応 = switch ($riskLevel) {
                    "高" { "即座に確認要" }
                    "中" { "詳細確認要" }
                    "低" { "定期監視" }
                }
                確認日 = (Get-Date).ToString("yyyy/MM/dd")
                備考 = "フォールバックデータ（認証後に実データに更新）"
            }
        }
        
        Write-Log "安全なセキュリティ分析データ生成完了: $($securityData.Count)件" -Level "Info"
        return $securityData
    }
    catch {
        Write-Log "セキュリティデータ生成エラー: $($_.Exception.Message)" -Level "Error"
        
        # 最低限のデータ
        return @(
            [PSCustomObject]@{
                ユーザー名 = "データ取得エラー"
                プリンシパル = "認証が必要"
                カテゴリ = "システム"
                アカウント状態 = "確認要"
                最終サインイン = (Get-Date).ToString("yyyy/MM/dd")
                サインインリスク = "確認要"
                場所 = "不明"
                リスク要因 = "Microsoft Graph接続が必要"
                リスクスコア = 0
                総合リスク = "確認要"
                推奨対応 = "認証設定確認"
                確認日 = (Get-Date).ToString("yyyy/MM/dd")
                備考 = "認証後に実データが表示されます"
            }
        )
    }
}

# 認証テスト用の安全なサンプルデータ生成
function Get-SafeAuthenticationTestData {
    try {
        Write-Log "安全な認証テストデータを生成中..." -Level "Info"
        
        $authData = @()
        $users = @("admin@miraiconst.onmicrosoft.com", "user1@miraiconst.onmicrosoft.com", "manager@miraiconst.onmicrosoft.com")
        $apps = @("Microsoft 365", "Azure Portal", "Teams", "SharePoint", "Exchange")
        $statuses = @("Success", "Success", "Success", "Failure")
        $locations = @("東京, 日本", "大阪, 日本", "名古屋, 日本")
        
        for ($i = 1; $i -le 15; $i++) {
            $user = $users | Get-Random
            $app = $apps | Get-Random
            $status = $statuses | Get-Random
            $location = $locations | Get-Random
            $timeOffset = Get-Random -Minimum 1 -Maximum 1440
            
            $authData += [PSCustomObject]@{
                "ログイン日時" = (Get-Date).AddMinutes(-$timeOffset).ToString("yyyy/MM/dd HH:mm:ss")
                "ユーザー" = $user
                "アプリケーション" = $app
                "認証状態" = $status
                "IPアドレス" = "192.168.1.$(Get-Random -Minimum 10 -Maximum 254)"
                "クライアント" = if ($status -eq "Success") { "Browser" } else { "Mobile Apps" }
                "場所" = $location
                "リスク詳細" = if ($status -eq "Failure") { "要確認" } else { "正常" }
                "デバイス OS" = @("Windows 11", "iOS", "Android") | Get-Random
                "ブラウザ" = @("Edge", "Chrome", "Safari") | Get-Random
                "備考" = "フォールバックデータ（認証後に実ログに更新）"
            }
        }
        
        Write-Log "安全な認証テストデータ生成完了: $($authData.Count)件" -Level "Info"
        return $authData
    }
    catch {
        Write-Log "認証テストデータ生成エラー: $($_.Exception.Message)" -Level "Error"
        
        # 最低限のデータ
        return @(
            [PSCustomObject]@{
                "ログイン日時" = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
                "ユーザー" = "データ取得エラー"
                "アプリケーション" = "システム"
                "認証状態" = "Error"
                "IPアドレス" = "0.0.0.0"
                "クライアント" = "Unknown"
                "場所" = "不明"
                "リスク詳細" = "認証設定確認が必要"
                "デバイス OS" = "Unknown"
                "ブラウザ" = "Unknown"
                "備考" = "認証後に実データが表示されます"
            }
        )
    }
}

Export-ModuleMember -Function Get-SafePermissionAuditData, Get-SafeSecurityAnalysisData, Get-SafeAuthenticationTestData