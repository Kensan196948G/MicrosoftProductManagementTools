# ================================================================================
# run_launcher_sta.ps1
# STAモードでランチャーを起動するラッパースクリプト
# ================================================================================

# 現在のApartmentStateを確認
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "🔄 STAモードでPowerShellを再起動します..." -ForegroundColor Cyan
    
    # PowerShell 7を探す
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        # すべての引数を渡してSTAモードで再起動
        $arguments = @("-sta", "-NoProfile", "-File", "$PSScriptRoot\run_launcher.ps1") + $args
        Start-Process pwsh -ArgumentList $arguments -NoNewWindow -Wait
    } else {
        # Windows PowerShellで実行
        $arguments = @("-sta", "-NoProfile", "-File", "$PSScriptRoot\run_launcher.ps1") + $args
        Start-Process powershell -ArgumentList $arguments -NoNewWindow -Wait
    }
    
    exit
}

# 既にSTAモードの場合は直接実行
& "$PSScriptRoot\run_launcher.ps1" @args