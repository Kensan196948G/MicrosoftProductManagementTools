# ================================================================================
# プログレス表示テストスクリプト
# Microsoft 365統合管理ツール用
# ================================================================================

[CmdletBinding()]
param()

# スクリプトの場所とToolRootを設定
$Script:TestRoot = $PSScriptRoot
$Script:ToolRoot = Split-Path $Script:TestRoot -Parent

Write-Host "=== プログレス表示テスト開始 ===" -ForegroundColor Green
Write-Host "ToolRoot: $Script:ToolRoot" -ForegroundColor Cyan

try {
    # ProgressDisplayモジュールをインポート
    $modulePath = Join-Path $Script:ToolRoot "Scripts\Common\ProgressDisplay.psm1"
    Write-Host "モジュールパス: $modulePath" -ForegroundColor Cyan
    
    if (-not (Test-Path $modulePath)) {
        throw "ProgressDisplayモジュールが見つかりません: $modulePath"
    }
    
    Import-Module $modulePath -Force
    Write-Host "ProgressDisplayモジュールを読み込みました" -ForegroundColor Green
    
    Write-Host "`n🎬 実況ログ機能のテスト開始" -ForegroundColor Yellow
    
    # 実況ログのテスト
    Write-LiveLog "テスト開始: プログレス表示機能" -Level "Info" -Animate
    Start-Sleep -Seconds 1
    
    Write-LiveLog "初期化中..." -Level "Info"
    Start-Sleep -Seconds 1
    
    Write-LiveLog "認証確認中..." -Level "Verbose"
    Start-Sleep -Seconds 1
    
    Write-LiveLog "データ収集完了" -Level "Success"
    Start-Sleep -Seconds 1
    
    Write-LiveLog "警告: 一部のデータが見つかりません" -Level "Warning"
    Start-Sleep -Seconds 1
    
    Write-LiveLog "デバッグ情報: テストモードで実行中" -Level "Debug"
    Start-Sleep -Seconds 1
    
    # プログレスバーのテスト
    Write-Host "`n📊 プログレスバー機能のテスト" -ForegroundColor Yellow
    
    for ($i = 0; $i -le 100; $i += 10) {
        Show-ProgressBar -PercentComplete $i -Activity "テスト処理" -Status "データ処理中" -CurrentOperation "ステップ $i/100" -Id 1
        Start-Sleep -Milliseconds 300
    }
    
    Write-Progress -Id 1 -Completed
    Write-LiveLog "プログレスバーテスト完了" -Level "Success"
    
    # ステップ処理のテスト
    Write-Host "`n🔄 ステップ処理機能のテスト" -ForegroundColor Yellow
    
    $testSteps = @(
        @{
            Name = "🔧 環境初期化"
            Action = {
                Write-Host "    → 環境を初期化しています..." -ForegroundColor Gray
                Start-Sleep -Milliseconds 800
            }
        },
        @{
            Name = "📡 データ取得"
            Action = {
                Write-Host "    → データを取得しています..." -ForegroundColor Gray
                Start-Sleep -Milliseconds 1200
            }
        },
        @{
            Name = "⚙️ データ処理"
            Action = {
                Write-Host "    → データを処理しています..." -ForegroundColor Gray
                Start-Sleep -Milliseconds 1000
            }
        },
        @{
            Name = "💾 結果保存"
            Action = {
                Write-Host "    → 結果を保存しています..." -ForegroundColor Gray
                Start-Sleep -Milliseconds 600
            }
        }
    )
    
    Invoke-StepWithProgress -Steps $testSteps -Activity "テストワークフロー" -Id 2
    
    # ダミーデータ生成のテスト
    Write-Host "`n📊 ダミーデータ生成テスト" -ForegroundColor Yellow
    
    $dummyData = New-DummyDataWithProgress -DataType "TestData" -RecordCount 25 -ProgressId 3
    
    Write-Host "`n📋 生成されたダミーデータ (最初の5件):" -ForegroundColor Cyan
    $dummyData | Select-Object -First 5 | Format-Table -AutoSize
    
    # 新機能: 数値進捗表示付きデータ収集テスト
    Write-Host "`n🔢 数値進捗表示付きデータ収集テスト" -ForegroundColor Yellow
    Write-Host "「データ収集」ステップで数値による収集推移を表示します..." -ForegroundColor Cyan
    
    # 数値進捗表示機能をテスト
    Invoke-DataCollectionWithProgress -ReportType "Daily" -RecordCount 30
    
    Write-Host "`n📄 レポート生成完全テスト（数値進捗付き）" -ForegroundColor Yellow
    
    $reportData = Invoke-ReportGenerationWithProgress -ReportType "TestReport" -ReportName "🧪 数値進捗テストレポート" -RecordCount 20
    
    Write-Host "`n🎯 数値進捗表示機能の特徴:" -ForegroundColor Blue
    Write-Host "・収集中: X/Y 件 の形式で現在の収集状況を表示" -ForegroundColor White
    Write-Host "・ステップ別詳細進捗 (認証状態確認 → ユーザーデータ → メールボックス...)" -ForegroundColor White
    Write-Host "・リアルタイム数値更新" -ForegroundColor White
    Write-Host "・実データ取得の場合は即座に件数表示" -ForegroundColor White
    Write-Host "・ダミーデータの場合は段階的収集表示" -ForegroundColor White
    
    Write-Host "`n✅ 全テスト完了!" -ForegroundColor Green
    Write-Host "📊 生成されたデータ件数: $($reportData.Count)" -ForegroundColor Cyan
    
    # 最後にプログレスバーをクリア
    Clear-AllProgress
    
}
catch {
    Write-Host "`n❌ テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== プログレス表示テスト終了 ===" -ForegroundColor Magenta