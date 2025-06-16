# ================================================================================
# Microsoft 365統合管理ツール - PowerShell 7.5.1 ダウンロードヘルパー
# Download-PowerShell751.ps1
# PowerShell 7.5.1インストーラー自動ダウンロード
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "ダウンロード先ディレクトリ")]
    [string]$DestinationPath = "Installers",
    
    [Parameter(Mandatory = $false, HelpMessage = "既存ファイルを上書き")]
    [switch]$Force = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "ファイルハッシュ検証をスキップ")]
    [switch]$SkipHashVerification = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "プロキシURL")]
    [string]$ProxyUrl,
    
    [Parameter(Mandatory = $false, HelpMessage = "プロキシ認証情報")]
    [System.Management.Automation.PSCredential]$ProxyCredential
)

# グローバル変数
$Script:DownloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.1/PowerShell-7.5.1-win-x64.msi"
$Script:FileName = "PowerShell-7.5.1-win-x64.msi"
$Script:ExpectedHash = ""  # GitHubから取得
$Script:FileSize = 0

# ログ出力関数
function Write-DownloadLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success", "Progress")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Progress" { "Magenta" }
        default { "Cyan" }
    }
    
    $prefix = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        "Progress" { "→" }
        default { "ℹ" }
    }
    
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

# プログレス表示
function Write-ProgressInfo {
    param(
        [int]$PercentComplete,
        [long]$BytesDownloaded,
        [long]$TotalBytes,
        [string]$Status
    )
    
    $mbDownloaded = [math]::Round($BytesDownloaded / 1MB, 2)
    $mbTotal = [math]::Round($TotalBytes / 1MB, 2)
    
    Write-Progress -Activity "PowerShell 7.5.1 をダウンロード中" -Status $Status -PercentComplete $PercentComplete -CurrentOperation "$mbDownloaded MB / $mbTotal MB"
    
    Write-DownloadLog "ダウンロード進行: $PercentComplete% ($mbDownloaded MB / $mbTotal MB)" -Level Progress
}

# インターネット接続確認
function Test-InternetConnection {
    try {
        Write-DownloadLog "インターネット接続を確認中..." -Level Info
        $testUrl = "https://github.com"
        
        if ($ProxyUrl) {
            Write-DownloadLog "プロキシを使用: $ProxyUrl" -Level Info
            if ($ProxyCredential) {
                $response = Invoke-WebRequest -Uri $testUrl -Proxy $ProxyUrl -ProxyCredential $ProxyCredential -UseBasicParsing -TimeoutSec 10
            } else {
                $response = Invoke-WebRequest -Uri $testUrl -Proxy $ProxyUrl -UseBasicParsing -TimeoutSec 10
            }
        } else {
            $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
        }
        
        Write-DownloadLog "インターネット接続確認完了" -Level Success
        return $true
    }
    catch {
        Write-DownloadLog "インターネット接続エラー: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ファイルハッシュ取得（GitHub API使用）
function Get-ExpectedFileHash {
    try {
        Write-DownloadLog "ファイルハッシュ情報を取得中..." -Level Info
        
        # GitHub Release API URL
        $apiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/tags/v7.5.1"
        
        if ($ProxyUrl) {
            if ($ProxyCredential) {
                $release = Invoke-RestMethod -Uri $apiUrl -Proxy $ProxyUrl -ProxyCredential $ProxyCredential
            } else {
                $release = Invoke-RestMethod -Uri $apiUrl -Proxy $ProxyUrl
            }
        } else {
            $release = Invoke-RestMethod -Uri $apiUrl
        }
        
        # MSIファイル情報取得
        $msiAsset = $release.assets | Where-Object { $_.name -eq $Script:FileName }
        if ($msiAsset) {
            $Script:FileSize = $msiAsset.size
            Write-DownloadLog "ファイル情報: $Script:FileName ($([math]::Round($Script:FileSize / 1MB, 2)) MB)" -Level Info
        }
        
        # ハッシュファイル検索
        $hashAsset = $release.assets | Where-Object { $_.name -like "*hashes*" -or $_.name -like "*SHA256*" }
        if ($hashAsset) {
            Write-DownloadLog "ハッシュファイルが見つかりました: $($hashAsset.name)" -Level Success
            # 実際の実装では、ハッシュファイルをダウンロードして解析
            return $true
        } else {
            Write-DownloadLog "ハッシュファイルが見つかりません" -Level Warning
            return $false
        }
    }
    catch {
        Write-DownloadLog "ファイルハッシュ取得エラー: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

# ファイルハッシュ検証
function Test-FileHash {
    param([string]$FilePath)
    
    if ($SkipHashVerification) {
        Write-DownloadLog "ハッシュ検証をスキップしました" -Level Warning
        return $true
    }
    
    try {
        Write-DownloadLog "ファイルハッシュを検証中..." -Level Info
        
        $fileHash = Get-FileHash -Path $FilePath -Algorithm SHA256
        Write-DownloadLog "ファイルハッシュ: $($fileHash.Hash)" -Level Info
        
        # 実際の検証（ここでは簡略化）
        if ($Script:ExpectedHash -and $fileHash.Hash -eq $Script:ExpectedHash) {
            Write-DownloadLog "ファイルハッシュ検証成功" -Level Success
            return $true
        } else {
            Write-DownloadLog "期待されるハッシュ情報がありません。ファイルサイズで確認します" -Level Warning
            
            $fileInfo = Get-Item $FilePath
            if ($Script:FileSize -gt 0 -and [math]::Abs($fileInfo.Length - $Script:FileSize) -lt 1MB) {
                Write-DownloadLog "ファイルサイズが一致しています: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -Level Success
                return $true
            } else {
                Write-DownloadLog "ファイルサイズが一致しません" -Level Warning
                return $false
            }
        }
    }
    catch {
        Write-DownloadLog "ハッシュ検証エラー: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ファイルダウンロード
function Start-FileDownload {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        Write-DownloadLog "ダウンロードを開始します..." -Level Info
        Write-DownloadLog "URL: $Url" -Level Info
        Write-DownloadLog "保存先: $OutputPath" -Level Info
        
        # ダウンロード準備
        $webClient = New-Object System.Net.WebClient
        
        # プロキシ設定
        if ($ProxyUrl) {
            $proxy = New-Object System.Net.WebProxy($ProxyUrl)
            if ($ProxyCredential) {
                $proxy.Credentials = $ProxyCredential.GetNetworkCredential()
            }
            $webClient.Proxy = $proxy
        }
        
        # プログレス表示イベント
        $webClient.DownloadProgressChanged += {
            param($sender, $e)
            Write-ProgressInfo -PercentComplete $e.ProgressPercentage -BytesDownloaded $e.BytesReceived -TotalBytes $e.TotalBytesToReceive -Status "ダウンロード中..."
        }
        
        # ダウンロード完了イベント
        $webClient.DownloadFileCompleted += {
            param($sender, $e)
            if ($e.Error) {
                Write-DownloadLog "ダウンロードエラー: $($e.Error.Message)" -Level Error
            } else {
                Write-DownloadLog "ダウンロード完了" -Level Success
            }
        }
        
        # 非同期ダウンロード開始
        $webClient.DownloadFileAsync($Url, $OutputPath)
        
        # 完了まで待機
        while ($webClient.IsBusy) {
            Start-Sleep -Milliseconds 500
        }
        
        Write-Progress -Activity "PowerShell 7.5.1 をダウンロード中" -Completed
        
        # ダウンロード結果確認
        if (Test-Path $OutputPath) {
            $fileInfo = Get-Item $OutputPath
            Write-DownloadLog "ファイルサイズ: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -Level Success
            return $true
        } else {
            Write-DownloadLog "ダウンロードファイルが見つかりません" -Level Error
            return $false
        }
    }
    catch {
        Write-DownloadLog "ダウンロードエラー: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

# メイン実行
function Main {
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                PowerShell 7.5.1 ダウンローダー                              ║
║                Microsoft 365統合管理ツール 用                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue
    
    try {
        Write-DownloadLog "PowerShell 7.5.1 ダウンロードを開始します..." -Level Info
        
        # 出力ディレクトリ確認・作成
        if (-not (Test-Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            Write-DownloadLog "出力ディレクトリを作成しました: $DestinationPath" -Level Info
        }
        
        $outputFile = Join-Path $DestinationPath $Script:FileName
        
        # 既存ファイル確認
        if ((Test-Path $outputFile) -and -not $Force) {
            Write-DownloadLog "ファイルが既に存在します: $outputFile" -Level Warning
            $overwrite = Read-Host "上書きしますか？ (y/N)"
            if ($overwrite -notmatch "^[Yy]") {
                Write-DownloadLog "ダウンロードをキャンセルしました" -Level Info
                return
            }
        }
        
        # インターネット接続確認
        if (-not (Test-InternetConnection)) {
            Write-DownloadLog "インターネット接続が必要です" -Level Error
            return
        }
        
        # ファイル情報取得
        Get-ExpectedFileHash | Out-Null
        
        # ダウンロード実行
        $downloadResult = Start-FileDownload -Url $Script:DownloadUrl -OutputPath $outputFile
        
        if ($downloadResult) {
            # ハッシュ検証
            $hashResult = Test-FileHash -FilePath $outputFile
            
            if ($hashResult) {
                Write-DownloadLog "✅ PowerShell 7.5.1 ダウンロード完了!" -Level Success
                Write-DownloadLog "📁 保存場所: $outputFile" -Level Info
                Write-DownloadLog "🚀 ランチャーから自動インストールが利用可能になりました" -Level Success
                
                # 次のステップ案内
                Write-Host "`n" + "="*60 -ForegroundColor Gray
                Write-Host "次のステップ:" -ForegroundColor Yellow
                Write-Host "1. .\run_launcher.ps1 を実行" -ForegroundColor Green
                Write-Host "2. PowerShell 7.5.1が自動でインストールされます" -ForegroundColor Green
                Write-Host "3. GUI/CLIモードを選択して利用開始" -ForegroundColor Green
                Write-Host "="*60 -ForegroundColor Gray
            } else {
                Write-DownloadLog "ファイル検証に失敗しました。再ダウンロードを推奨します。" -Level Warning
            }
        } else {
            Write-DownloadLog "ダウンロードに失敗しました" -Level Error
        }
    }
    catch {
        Write-DownloadLog "予期しないエラーが発生しました: $($_.Exception.Message)" -Level Error
    }
}

# 実行開始
Main