# ================================================================================
# PermissionFallback.psm1
# 権限不足時のフォールバック処理
# ================================================================================

# 利用可能な権限で動作するように調整
function Invoke-WithPermissionFallback {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$FallbackScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [string]$RequiredPermission,
        
        [Parameter(Mandatory = $false)]
        [string]$OperationName = "操作"
    )
    
    try {
        # 元の処理を実行
        $result = & $ScriptBlock
        return $result
    }
    catch {
        $errorMessage = $_.Exception.Message
        
        # 権限不足エラーのパターン
        $permissionErrors = @(
            "Insufficient privileges",
            "Authorization_RequestDenied",
            "Forbidden",
            "does not have the required permissions",
            "Access denied"
        )
        
        $isPermissionError = $false
        foreach ($pattern in $permissionErrors) {
            if ($errorMessage -match $pattern) {
                $isPermissionError = $true
                break
            }
        }
        
        if ($isPermissionError) {
            Write-Log "権限不足: $OperationName - $RequiredPermission" -Level "Warning"
            
            if ($FallbackScriptBlock) {
                Write-Log "フォールバック処理を実行します" -Level "Info"
                return & $FallbackScriptBlock
            }
            else {
                Write-Log "フォールバック処理が定義されていません。空の結果を返します。" -Level "Warning"
                return @()
            }
        }
        else {
            # 権限以外のエラーは再スロー
            throw
        }
    }
}

# 現在利用可能な権限を確認
function Get-AvailablePermissions {
    $availablePermissions = @{
        "Microsoft.Graph" = @()
        "ExchangeOnline" = @()
    }
    
    try {
        $context = Get-MgContext
        if ($context) {
            $availablePermissions["Microsoft.Graph"] = $context.Scopes -split ' ' | Where-Object { $_ }
        }
    }
    catch {
        Write-Log "Microsoft Graph権限の確認に失敗しました" -Level "Warning"
    }
    
    try {
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $exoConnection = Get-ConnectionInformation
            if ($exoConnection) {
                $availablePermissions["ExchangeOnline"] = @("Connected")
            }
        }
    }
    catch {
        Write-Log "Exchange Online権限の確認に失敗しました" -Level "Warning"
    }
    
    return $availablePermissions
}

# 権限に基づいて機能を調整
function Get-AdjustedUserData {
    param(
        [int]$MaxUsers = 50
    )
    
    $permissions = Get-AvailablePermissions
    $userData = @()
    
    # Directory.ReadWrite.All があれば User.Read.All の代替として使用
    if ($permissions["Microsoft.Graph"] -contains "Directory.ReadWrite.All") {
        try {
            Write-Log "Directory.ReadWrite.All を使用してユーザー情報を取得" -Level "Info"
            
            # 基本的なユーザー情報のみ取得
            $users = Get-MgUser -Top $MaxUsers -Property "Id,DisplayName,UserPrincipalName,AccountEnabled" -ErrorAction Stop
            
            foreach ($user in $users) {
                $userData += [PSCustomObject]@{
                    ユーザー名 = $user.DisplayName
                    メールアドレス = $user.UserPrincipalName
                    状態 = if ($user.AccountEnabled) { "有効" } else { "無効" }
                    部署 = "権限不足により取得不可"
                    最終ログイン = "権限不足により取得不可"
                }
            }
        }
        catch {
            Write-Log "ユーザー情報の取得に失敗: $($_.Exception.Message)" -Level "Warning"
        }
    }
    
    return $userData
}

# グループ情報の制限付き取得
function Get-AdjustedGroupData {
    param(
        [int]$MaxGroups = 25
    )
    
    $permissions = Get-AvailablePermissions
    $groupData = @()
    
    # Directory.ReadWrite.All でグループの基本情報を取得
    if ($permissions["Microsoft.Graph"] -contains "Directory.ReadWrite.All") {
        try {
            Write-Log "Directory.ReadWrite.All を使用してグループ情報を取得" -Level "Info"
            
            # 基本的なグループ情報のみ
            $groups = Invoke-WithPermissionFallback -ScriptBlock {
                Get-MgGroup -Top $MaxGroups -Property "Id,DisplayName,GroupTypes" -ErrorAction Stop
            } -FallbackScriptBlock {
                Write-Log "グループ情報を取得できません" -Level "Warning"
                return @()
            } -RequiredPermission "Group.Read.All" -OperationName "グループ一覧取得"
            
            foreach ($group in $groups) {
                $groupData += [PSCustomObject]@{
                    グループ名 = $group.DisplayName
                    種類 = if ($group.GroupTypes -contains "Unified") { "Microsoft 365" } else { "セキュリティ" }
                    メンバー数 = "権限不足により取得不可"
                }
            }
        }
        catch {
            Write-Log "グループ情報の取得に失敗: $($_.Exception.Message)" -Level "Warning"
        }
    }
    
    return $groupData
}

# OneDrive/SharePoint の制限付き情報取得
function Get-AdjustedStorageData {
    $permissions = Get-AvailablePermissions
    $storageData = @()
    
    # Sites.ReadWrite.All と Files.ReadWrite.All で代替
    if ($permissions["Microsoft.Graph"] -contains "Sites.ReadWrite.All" -or 
        $permissions["Microsoft.Graph"] -contains "Files.ReadWrite.All") {
        
        try {
            Write-Log "ReadWrite権限を使用してストレージ情報を取得" -Level "Info"
            
            # Reports.Read.All がある場合のみ使用状況レポートを取得
            if ($permissions["Microsoft.Graph"] -contains "Reports.Read.All") {
                $report = Get-MgReportOneDriveUsageAccountDetail -Period "D7" -ErrorAction Stop
                # レポート処理
            }
            else {
                Write-Log "Reports.Read.All がないため、使用状況レポートは取得できません" -Level "Warning"
                
                # ダミーデータを返す
                for ($i = 1; $i -le 10; $i++) {
                    $storageData += [PSCustomObject]@{
                        ユーザー = "ユーザー$i"
                        使用容量 = "取得不可"
                        ファイル数 = "取得不可"
                        状態 = "権限不足"
                    }
                }
            }
        }
        catch {
            Write-Log "ストレージ情報の取得に失敗: $($_.Exception.Message)" -Level "Warning"
        }
    }
    
    return $storageData
}

Export-ModuleMember -Function @(
    'Invoke-WithPermissionFallback',
    'Get-AvailablePermissions',
    'Get-AdjustedUserData',
    'Get-AdjustedGroupData',
    'Get-AdjustedStorageData'
)