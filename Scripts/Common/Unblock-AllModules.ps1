# ================================================================================
# モジュールファイルのブロック解除スクリプト
# PowerShell実行ポリシー問題解決用
# ================================================================================

param(
    [string]$ModulePath = (Join-Path $PSScriptRoot ".")
)

Write-Host "🔓 モジュールファイルのブロック解除を開始..." -ForegroundColor Cyan
Write-Host "📁 対象ディレクトリ: $ModulePath" -ForegroundColor Gray

# PowerShellモジュールファイルを取得
$moduleFiles = Get-ChildItem -Path $ModulePath -Filter "*.psm1" -File

if ($moduleFiles.Count -eq 0) {
    Write-Host "⚠️ .psm1ファイルが見つかりませんでした" -ForegroundColor Yellow
    exit 0
}

Write-Host "📊 発見されたモジュールファイル: $($moduleFiles.Count)個" -ForegroundColor Cyan

foreach ($file in $moduleFiles) {
    try {
        # ファイルがブロックされているかチェック
        $blocked = Get-Item $file.FullName | Get-ItemProperty -Name "Zone.Identifier" -ErrorAction SilentlyContinue
        
        if ($blocked) {
            Write-Host "🔒 ブロック検出: $($file.Name)" -ForegroundColor Yellow
            Unblock-File -Path $file.FullName
            Write-Host "✅ ブロック解除: $($file.Name)" -ForegroundColor Green
        } else {
            Write-Host "✅ ブロックなし: $($file.Name)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ エラー: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 実行ポリシーチェック
Write-Host "`n🔍 実行ポリシー確認:" -ForegroundColor Cyan
$policies = Get-ExecutionPolicy -List
foreach ($policy in $policies) {
    $color = if ($policy.ExecutionPolicy -eq "Bypass" -or $policy.ExecutionPolicy -eq "Unrestricted") { "Green" } else { "Yellow" }
    Write-Host "   $($policy.Scope): $($policy.ExecutionPolicy)" -ForegroundColor $color
}

Write-Host "`n✨ モジュールブロック解除処理完了" -ForegroundColor Green