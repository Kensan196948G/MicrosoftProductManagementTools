# PDF出力テストスクリプト
param(
    [string]$TestFile = "test-pdf-japanese.html"
)

Write-Host "PDF出力テストを開始します..." -ForegroundColor Green
Write-Host "テストファイル: $TestFile" -ForegroundColor Cyan

# テストファイルの存在確認
$testPath = Join-Path $PSScriptRoot $TestFile
if (-not (Test-Path $testPath)) {
    Write-Host "エラー: テストファイルが見つかりません: $testPath" -ForegroundColor Red
    exit 1
}

Write-Host "テストファイルパス: $testPath" -ForegroundColor Green

# ブラウザでテストファイルを開く
try {
    Write-Host "ブラウザでテストファイルを開いています..." -ForegroundColor Yellow
    Start-Process $testPath
    Write-Host "ブラウザが開きました。以下の手順でテストしてください:" -ForegroundColor Green
    Write-Host ""
    Write-Host "1. ブラウザでページが正しく表示されることを確認" -ForegroundColor White
    Write-Host "2. \"Download PDF\" ボタンをクリック" -ForegroundColor White
    Write-Host "3. PDFファイルが正しい名前でダウンロードされることを確認" -ForegroundColor White
    Write-Host "4. PDFファイルを開いて内容が正しく表示されることを確認" -ForegroundColor White
    Write-Host ""
    Write-Host "期待される結果:" -ForegroundColor Yellow
    Write-Host "- ファイル名: Microsoft_365_Report_YYYY_MM_DD_HH_MM_SS.pdf" -ForegroundColor Cyan
    Write-Host "- PDF内容: 日本語が適切に英語に変換されて表示される" -ForegroundColor Cyan
    Write-Host "- ヘッダー: Date, User_Name, Department, Failed_Logins, Total_Logins, Storage_Usage, Status" -ForegroundColor Cyan
    Write-Host "- データ: 田中太郎 → Taro Tanaka, 開発部 → Development, 正常 → Normal" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "テスト完了後、Enterキーを押してください..." -ForegroundColor Green
    Read-Host
}
catch {
    Write-Host "エラー: ブラウザでテストファイルを開けませんでした: $_" -ForegroundColor Red
    exit 1
}

Write-Host "PDF出力テストが完了しました。" -ForegroundColor Green
