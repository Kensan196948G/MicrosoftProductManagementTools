# ================================================================================
# PowerShellモジュールインストールスクリプト
# 新しいPCでの初期セットアップ用
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false
)

Write-Host "Microsoft製品運用管理ツール - モジュールインストール" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

# 管理者権限チェック
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "⚠️ 管理者権限が推奨されますが、CurrentUserスコープでインストールを続行します" -ForegroundColor Yellow
}

# PowerShellバージョン確認
Write-Host "`n=== システム情報 ===" -ForegroundColor Yellow
Write-Host "PowerShellバージョン: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "OS: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Cyan
Write-Host "コンピューター名: $([System.Environment]::MachineName)" -ForegroundColor Cyan

# 実行ポリシー確認・設定
Write-Host "`n=== 実行ポリシー設定 ===" -ForegroundColor Yellow

$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
Write-Host "現在の実行ポリシー: $currentPolicy" -ForegroundColor Cyan

if ($currentPolicy -eq "Restricted") {
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "✓ 実行ポリシーをRemoteSignedに変更しました" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ 実行ポリシーの変更に失敗: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "手動で設定してください: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Yellow
    }
}
else {
    Write-Host "✓ 実行ポリシーは適切に設定されています" -ForegroundColor Green
}

# 必須モジュール定義
$requiredModules = @(
    @{
        Name = "Microsoft.Graph"
        MinVersion = "1.0.0"
        Description = "Microsoft Graph PowerShell SDK"
        InstallCommand = "Install-Module Microsoft.Graph -Force -AllowClobber -Scope CurrentUser"
    },
    @{
        Name = "ExchangeOnlineManagement"
        MinVersion = "3.0.0"
        Description = "Exchange Online Management"
        InstallCommand = "Install-Module ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser"
    }
)

# モジュールインストール
Write-Host "`n=== モジュールインストール ===" -ForegroundColor Yellow

foreach ($module in $requiredModules) {
    Write-Host "`n--- $($module.Name) ---" -ForegroundColor Cyan
    
    # 既存モジュール確認
    $installedModule = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
    
    if ($installedModule -and -not $Force) {
        Write-Host "✓ $($module.Name) は既にインストールされています" -ForegroundColor Green
        Write-Host "  バージョン: $($installedModule.Version)" -ForegroundColor Cyan
        Write-Host "  パス: $($installedModule.ModuleBase)" -ForegroundColor Cyan
        
        # バージョンチェック
        if ($installedModule.Version -ge [Version]$module.MinVersion) {
            Write-Host "✓ バージョン要件を満たしています" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ 最小バージョン要件 ($($module.MinVersion)) を満たしていません" -ForegroundColor Yellow
            Write-Host "アップデートを推奨します" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "📦 $($module.Name) をインストール中..." -ForegroundColor Yellow
        Write-Host "説明: $($module.Description)" -ForegroundColor Cyan
        
        try {
            # プログレス表示を一時的に無効化
            $ProgressPreference = 'SilentlyContinue'
            
            # インストール実行
            Invoke-Expression $module.InstallCommand
            
            # インストール確認
            $newModule = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
            if ($newModule) {
                Write-Host "✓ $($module.Name) インストール成功" -ForegroundColor Green
                Write-Host "  バージョン: $($newModule.Version)" -ForegroundColor Cyan
            }
            else {
                throw "インストール後にモジュールが見つかりません"
            }
            
            # プログレス表示を復元
            $ProgressPreference = 'Continue'
        }
        catch {
            Write-Host "✗ $($module.Name) インストール失敗: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "手動インストールコマンド: $($module.InstallCommand)" -ForegroundColor Yellow
        }
    }
}

# モジュールインポートテスト
Write-Host "`n=== モジュールインポートテスト ===" -ForegroundColor Yellow

foreach ($module in $requiredModules) {
    try {
        Import-Module $module.Name -Force -ErrorAction Stop
        Write-Host "✓ $($module.Name) インポート成功" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ $($module.Name) インポート失敗: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# インストール完了
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "=== インストール完了 ===" -ForegroundColor Blue

Write-Host "✅ PowerShellモジュールのセットアップが完了しました" -ForegroundColor Green
Write-Host "`n次のステップ:" -ForegroundColor Yellow
Write-Host "1. 認証テストを実行してください:" -ForegroundColor Cyan
Write-Host "   pwsh -File test-authentication-portable.ps1" -ForegroundColor White
Write-Host "`n2. レポート生成テストを実行してください:" -ForegroundColor Cyan
Write-Host "   pwsh -File test-report-generation.ps1" -ForegroundColor White

Write-Host "`n詳細な手順は DEPLOYMENT-GUIDE.md を参照してください" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue