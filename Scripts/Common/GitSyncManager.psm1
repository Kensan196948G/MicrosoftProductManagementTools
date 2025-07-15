# ================================================================================
# GitSyncManager.psm1
# セキュアな自動Git同期システム
# ================================================================================

Import-Module "$PSScriptRoot\EnvironmentManager.psm1" -Force
Import-Module "$PSScriptRoot\Logging.psm1" -Force

# Git認証情報の設定
function Set-GitCredentials {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$UseEnvironmentFile = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [string]$Password,
        
        [Parameter(Mandatory = $false)]
        [string]$RepositoryUrl,
        
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    try {
        # 環境変数から認証情報を取得
        if ($UseEnvironmentFile) {
            Initialize-Environment -VerboseOutput:$VerboseOutput
            $gitCreds = Get-GitCredentials -ThrowOnMissing
            
            $Username = $gitCreds.Username
            $Password = $gitCreds.Password
            $RepositoryUrl = $gitCreds.RepositoryUrl
        }
        
        if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
            throw "Git認証情報が設定されていません"
        }
        
        # Git認証情報を設定
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
        
        # Git設定を更新
        git config --global user.name $Username
        git config --global user.email "$Username@github.com"
        git config --global credential.helper store
        
        # 認証情報をGitに保存
        $gitCredentialPath = "$env:USERPROFILE\.git-credentials"
        $credentialLine = "https://$Username`:$Password@github.com"
        
        # 既存の認証情報があれば削除
        if (Test-Path $gitCredentialPath) {
            $existingContent = Get-Content $gitCredentialPath | Where-Object { $_ -notmatch "github.com" }
            $existingContent | Out-File $gitCredentialPath -Encoding UTF8
        }
        
        # 新しい認証情報を追加
        Add-Content -Path $gitCredentialPath -Value $credentialLine
        
        Write-Log "Git認証情報を設定しました: $Username" -Level "Info"
        
        return @{
            Success = $true
            Username = $Username
            RepositoryUrl = $RepositoryUrl
        }
    }
    catch {
        Write-Log "Git認証情報の設定に失敗しました: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# Gitリポジトリの状態確認
function Get-GitRepositoryStatus {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath = ".",
        
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    try {
        $originalLocation = Get-Location
        Set-Location $RepositoryPath
        
        # Git リポジトリかどうか確認
        $isGitRepo = Test-Path ".git"
        if (-not $isGitRepo) {
            throw "指定されたパスはGitリポジトリではありません: $RepositoryPath"
        }
        
        # 現在のブランチを取得
        $currentBranch = git rev-parse --abbrev-ref HEAD
        
        # リモートの状態を確認
        git fetch --quiet 2>$null
        
        # 変更されたファイルの数を取得
        $stagedFiles = (git diff --cached --name-only).Count
        $modifiedFiles = (git diff --name-only).Count
        $untrackedFiles = (git ls-files --others --exclude-standard).Count
        
        # コミット数の差を確認
        $ahead = 0
        $behind = 0
        
        try {
            $status = git status --porcelain=v1 --branch
            $branchLine = $status | Select-Object -First 1
            
            if ($branchLine -match '\[ahead (\d+)\]') {
                $ahead = [int]$matches[1]
            }
            
            if ($branchLine -match '\[behind (\d+)\]') {
                $behind = [int]$matches[1]
            }
        }
        catch {
            Write-Log "Git状態の詳細取得に失敗しました: $($_.Exception.Message)" -Level "Warning"
        }
        
        # 最後のコミット情報
        $lastCommitHash = git rev-parse HEAD
        $lastCommitDate = git log -1 --format="%ci"
        $lastCommitMessage = git log -1 --format="%s"
        
        $status = @{
            IsGitRepository = $isGitRepo
            CurrentBranch = $currentBranch
            StagedFiles = $stagedFiles
            ModifiedFiles = $modifiedFiles
            UntrackedFiles = $untrackedFiles
            AheadCount = $ahead
            BehindCount = $behind
            LastCommitHash = $lastCommitHash
            LastCommitDate = $lastCommitDate
            LastCommitMessage = $lastCommitMessage
            HasChanges = ($stagedFiles + $modifiedFiles + $untrackedFiles) -gt 0
            NeedsPush = $ahead -gt 0
            NeedsPull = $behind -gt 0
        }
        
        if ($VerboseOutput) {
            Write-Log "Git リポジトリ状態:" -Level "Info"
            Write-Log "  ブランチ: $currentBranch" -Level "Info"
            Write-Log "  ステージされたファイル: $stagedFiles" -Level "Info"
            Write-Log "  変更されたファイル: $modifiedFiles" -Level "Info"
            Write-Log "  未追跡ファイル: $untrackedFiles" -Level "Info"
            Write-Log "  プッシュ待ちコミット: $ahead" -Level "Info"
            Write-Log "  プル待ちコミット: $behind" -Level "Info"
        }
        
        return $status
    }
    catch {
        Write-Log "Gitリポジトリ状態の取得に失敗しました: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
    finally {
        Set-Location $originalLocation
    }
}

# 自動同期実行
function Invoke-GitAutoSync {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath = ".",
        
        [Parameter(Mandatory = $false)]
        [string]$CommitMessage = "自動同期: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        
        [Parameter(Mandatory = $false)]
        [string]$Branch = "main",
        
        [Parameter(Mandatory = $false)]
        [switch]$ForcePush = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    try {
        $originalLocation = Get-Location
        Set-Location $RepositoryPath
        
        Write-Log "自動Git同期を開始します..." -Level "Info"
        
        # Git認証情報の設定
        Set-GitCredentials -UseEnvironmentFile -VerboseOutput:$VerboseOutput
        
        # 現在のリポジトリ状態を確認
        $repoStatus = Get-GitRepositoryStatus -RepositoryPath $RepositoryPath -VerboseOutput:$VerboseOutput
        
        # リモートから最新の変更を取得
        Write-Log "リモートから最新の変更を取得しています..." -Level "Info"
        git fetch origin $Branch
        
        # マージの必要性を確認
        if ($repoStatus.BehindCount -gt 0) {
            Write-Log "リモートに新しいコミットがあります。プルを実行します..." -Level "Info"
            
            # ローカルに変更がある場合はスタッシュ
            if ($repoStatus.HasChanges) {
                Write-Log "ローカルの変更を一時保存しています..." -Level "Info"
                git stash push -m "自動同期前の一時保存 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            }
            
            # プルを実行
            $pullResult = git pull origin $Branch 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "プルに失敗しました: $pullResult"
            }
            
            # スタッシュした変更を復元
            if ($repoStatus.HasChanges) {
                Write-Log "一時保存した変更を復元しています..." -Level "Info"
                git stash pop
            }
        }
        
        # 未追跡ファイルを追加（.gitignoreに含まれないもの）
        if ($repoStatus.UntrackedFiles -gt 0) {
            Write-Log "未追跡ファイルを追加しています..." -Level "Info"
            git add .
        }
        
        # 変更されたファイルを再度確認
        $updatedStatus = Get-GitRepositoryStatus -RepositoryPath $RepositoryPath
        
        if ($updatedStatus.HasChanges) {
            Write-Log "変更をコミットしています..." -Level "Info"
            git commit -m $CommitMessage
            
            if ($LASTEXITCODE -ne 0) {
                throw "コミットに失敗しました"
            }
        }
        
        # プッシュの実行
        $pushStatus = Get-GitRepositoryStatus -RepositoryPath $RepositoryPath
        
        if ($pushStatus.AheadCount -gt 0 -or $ForcePush) {
            Write-Log "リモートにプッシュしています..." -Level "Info"
            
            $pushArgs = @("push", "origin", $Branch)
            if ($ForcePush) {
                $pushArgs += "--force"
            }
            
            $pushResult = & git $pushArgs 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "プッシュに失敗しました: $pushResult"
            }
            
            Write-Log "プッシュが完了しました" -Level "Success"
        } else {
            Write-Log "プッシュする変更がありません" -Level "Info"
        }
        
        # 最終状態を取得
        $finalStatus = Get-GitRepositoryStatus -RepositoryPath $RepositoryPath -VerboseOutput:$VerboseOutput
        
        Write-Log "自動Git同期が完了しました" -Level "Success"
        
        return @{
            Success = $true
            CommitMessage = $CommitMessage
            Branch = $Branch
            FinalStatus = $finalStatus
        }
    }
    catch {
        Write-Log "自動Git同期に失敗しました: $($_.Exception.Message)" -Level "Error"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Branch = $Branch
        }
    }
    finally {
        Set-Location $originalLocation
    }
}

# 安全な同期実行（機密情報チェック付き）
function Invoke-SecureGitSync {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath = ".",
        
        [Parameter(Mandatory = $false)]
        [string]$CommitMessage = "セキュア同期: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        
        [Parameter(Mandatory = $false)]
        [string]$Branch = "main",
        
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    try {
        Write-Log "セキュアGit同期を開始します..." -Level "Info"
        
        # 機密情報の確認
        $secretPatterns = @(
            'password\s*=\s*"[^"]*"',
            'secret\s*=\s*"[^"]*"',
            'key\s*=\s*"[^"]*"',
            'token\s*=\s*"[^"]*"',
            'api_key\s*=\s*"[^"]*"'
        )
        
        $originalLocation = Get-Location
        Set-Location $RepositoryPath
        
        # ステージされたファイルで機密情報をチェック
        $stagedFiles = git diff --cached --name-only
        $secretsFound = $false
        
        foreach ($file in $stagedFiles) {
            if (-not (Test-Path $file)) {
                continue
            }
            
            $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
            if (-not $content) {
                continue
            }
            
            foreach ($pattern in $secretPatterns) {
                if ($content -match $pattern) {
                    # プレースホルダーや明らかにダミーの値は除外
                    $match = $matches[0]
                    if ($match -notmatch "YOUR-.*-HERE|placeholder|dummy|example|test|ELzion1969|Kensan196948G") {
                        Write-Log "機密情報の可能性があるファイル: $file" -Level "Warning"
                        $secretsFound = $true
                    }
                }
            }
        }
        
        # .envファイルがコミット対象に含まれていないかチェック
        if ($stagedFiles -contains ".env") {
            Write-Log ".envファイルがコミット対象に含まれています。除外します..." -Level "Warning"
            git reset HEAD .env
            $secretsFound = $true
        }
        
        # 機密情報が見つかった場合の処理
        if ($secretsFound) {
            Write-Log "機密情報が検出されました。手動で確認してください。" -Level "Warning"
            
            # 対話モードでない場合は同期を中断
            if (-not $VerboseOutput) {
                throw "機密情報検出のため同期を中断しました"
            }
        }
        
        # 通常の同期実行
        $syncResult = Invoke-GitAutoSync -RepositoryPath $RepositoryPath -CommitMessage $CommitMessage -Branch $Branch -VerboseOutput:$VerboseOutput
        
        if ($syncResult.Success) {
            Write-Log "セキュアGit同期が完了しました" -Level "Success"
        } else {
            Write-Log "セキュアGit同期に失敗しました: $($syncResult.Error)" -Level "Error"
        }
        
        return $syncResult
    }
    catch {
        Write-Log "セキュアGit同期でエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Branch = $Branch
        }
    }
    finally {
        Set-Location $originalLocation
    }
}

# 同期スケジューラー
function Start-GitSyncScheduler {
    param(
        [Parameter(Mandatory = $false)]
        [int]$IntervalMinutes = 30,
        
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath = ".",
        
        [Parameter(Mandatory = $false)]
        [string]$Branch = "main",
        
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    try {
        Write-Log "Git同期スケジューラーを開始します（間隔: $IntervalMinutes 分）..." -Level "Info"
        
        $syncCount = 0
        $errorCount = 0
        
        while ($true) {
            try {
                $syncCount++
                Write-Log "同期実行 #$syncCount を開始します..." -Level "Info"
                
                $syncResult = Invoke-SecureGitSync -RepositoryPath $RepositoryPath -Branch $Branch -VerboseOutput:$VerboseOutput
                
                if ($syncResult.Success) {
                    Write-Log "同期 #$syncCount が完了しました" -Level "Success"
                } else {
                    $errorCount++
                    Write-Log "同期 #$syncCount に失敗しました: $($syncResult.Error)" -Level "Error"
                }
                
                # 統計情報のログ
                Write-Log "同期統計: 実行回数 $syncCount, 失敗回数 $errorCount" -Level "Info"
                
                # 次の同期まで待機
                Write-Log "次の同期まで $IntervalMinutes 分待機します..." -Level "Info"
                Start-Sleep -Seconds ($IntervalMinutes * 60)
            }
            catch {
                $errorCount++
                Write-Log "同期スケジューラーでエラーが発生しました: $($_.Exception.Message)" -Level "Error"
                
                # エラー時は短い間隔で再試行
                Start-Sleep -Seconds 300  # 5分待機
            }
        }
    }
    catch {
        Write-Log "Git同期スケジューラーの開始に失敗しました: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# エクスポート関数
Export-ModuleMember -Function Set-GitCredentials, Get-GitRepositoryStatus, Invoke-GitAutoSync, Invoke-SecureGitSync, Start-GitSyncScheduler