# Try-Catch ブロックの不一致を修正
$content = Get-Content "Apps/GuiApp.ps1" -Raw

# Try と Catch の詳細な分析
$tryMatches = [regex]::Matches($content, "try\s*\{")
$catchMatches = [regex]::Matches($content, "catch\s*\{")
$finallyMatches = [regex]::Matches($content, "finally\s*\{")

Write-Host "=== Try-Catch 詳細分析 ===" -ForegroundColor Cyan
Write-Host "Try ブロック: $($tryMatches.Count)" -ForegroundColor Yellow
Write-Host "Catch ブロック: $($catchMatches.Count)" -ForegroundColor Yellow  
Write-Host "Finally ブロック: $($finallyMatches.Count)" -ForegroundColor Yellow

$difference = $tryMatches.Count - $catchMatches.Count - $finallyMatches.Count
Write-Host "不一致数: $difference" -ForegroundColor $(if ($difference -eq 0) { "Green" } else { "Red" })

if ($difference -gt 0) {
    Write-Host "`n不足している Catch ブロックを特定中..." -ForegroundColor Yellow
    
    # 各 Try の後に対応する Catch または Finally があるかチェック
    $lines = $content -split "`n"
    $unmatched = 0
    
    for ($i = 0; $i -lt $tryMatches.Count; $i++) {
        $tryPos = $tryMatches[$i].Index
        $tryLine = ($content.Substring(0, $tryPos) -split "`n").Count
        
        # この Try に対応する Catch または Finally を探す
        $foundMatch = $false
        
        foreach ($catch in $catchMatches) {
            if ($catch.Index -gt $tryPos) {
                $foundMatch = $true
                break
            }
        }
        
        if (-not $foundMatch) {
            foreach ($finally in $finallyMatches) {
                if ($finally.Index -gt $tryPos) {
                    $foundMatch = $true
                    break
                }
            }
        }
        
        if (-not $foundMatch) {
            Write-Host "未対応の Try ブロック: 行 $tryLine 付近" -ForegroundColor Red
            $unmatched++
        }
    }
    
    Write-Host "`n合計 $unmatched 個の未対応 Try ブロック" -ForegroundColor Red
}

Write-Host "`n=== 基本構文チェック ===" -ForegroundColor Cyan
try {
    $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
    Write-Host "✅ PowerShell 基本構文: OK" -ForegroundColor Green
}
catch {
    Write-Host "❌ PowerShell 基本構文エラー: $_" -ForegroundColor Red
}