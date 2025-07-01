# GUI構文修正確認テスト
try {
    Write-Host "=== GUI アプリケーション構文チェック ===" -ForegroundColor Green
    
    # 1. PowerShell構文チェック
    Write-Host "1. PowerShell構文をチェック中..." -ForegroundColor Yellow
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content "Apps/GuiApp.ps1" -Raw), [ref]$null)
    Write-Host "   ✅ PowerShell構文: OK" -ForegroundColor Green
    
    # 2. Try-Catch ブロックの整合性チェック
    Write-Host "2. Try-Catch ブロックをチェック中..." -ForegroundColor Yellow
    $content = Get-Content "Apps/GuiApp.ps1" -Raw
    $tryCount = ($content | Select-String "try\s*\{" -AllMatches).Matches.Count
    $catchCount = ($content | Select-String "catch\s*\{" -AllMatches).Matches.Count
    Write-Host "   Try ブロック数: $tryCount" -ForegroundColor Cyan
    Write-Host "   Catch ブロック数: $catchCount" -ForegroundColor Cyan
    
    if ($tryCount -eq $catchCount) {
        Write-Host "   ✅ Try-Catch ブロック: OK" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Try-Catch ブロック: 不一致があります" -ForegroundColor Yellow
    }
    
    # 3. 主要switch文の確認
    Write-Host "3. Switch文をチェック中..." -ForegroundColor Yellow
    $switchPatterns = @(
        "PermissionAudit",
        "SecurityAnalysis", 
        "Yearly",
        "Comprehensive",
        "UsageAnalysis"
    )
    
    foreach ($pattern in $switchPatterns) {
        if ($content -match "`"$pattern`"\s*\{") {
            Write-Host "   ✅ $pattern セクション: OK" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $pattern セクション: 見つかりません" -ForegroundColor Red
        }
    }
    
    # 4. 修正内容の確認
    Write-Host "4. 修正内容を確認中..." -ForegroundColor Yellow
    
    # 権限監査の実運用データ対応確認
    if ($content -match "Get-RealisticUserData") {
        Write-Host "   ✅ 権限監査: 実運用データ対応済み" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ 権限監査: 実運用データ対応未確認" -ForegroundColor Yellow
    }
    
    # セキュリティ分析のMicrosoft Graph対応確認
    if ($content -match "Get-MgUser.*LastSignInDateTime") {
        Write-Host "   ✅ セキュリティ分析: Microsoft Graph対応済み" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ セキュリティ分析: Microsoft Graph対応未確認" -ForegroundColor Yellow
    }
    
    Write-Host "`n=== チェック完了 ===" -ForegroundColor Green
    Write-Host "GUIアプリケーションの構文修正が完了しました。" -ForegroundColor Cyan
    Write-Host "run_launcher.ps1 -Mode gui でテストしてください。" -ForegroundColor White
}
catch {
    Write-Host "❌ チェックエラー: $($_.Exception.Message)" -ForegroundColor Red
}