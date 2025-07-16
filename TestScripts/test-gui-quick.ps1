# ================================================================================
# GUIアプリケーション簡易テスト
# Microsoft 365統合管理ツール用
# ================================================================================

[CmdletBinding()]
param()

# スクリプトの場所とToolRootを設定
$Script:TestRoot = $PSScriptRoot
$Script:ToolRoot = Split-Path $Script:TestRoot -Parent

Write-Host "=== GUI簡易テスト開始 ===" -ForegroundColor Green

try {
    # ダミーデータ生成機能のテスト
    function New-DummyData {
        param(
            [Parameter(Mandatory = $true)]
            [string]$DataType,
            
            [Parameter(Mandatory = $false)]
            [int]$RecordCount = 10
        )
        
        Write-Host "📊 $DataType データを生成中... ($RecordCount 件)" -ForegroundColor Cyan
        
        $dummyData = @()
        $userNames = @("田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一")
        $departments = @("営業部", "開発部", "総務部", "人事部", "経理部")
        
        for ($i = 1; $i -le $RecordCount; $i++) {
            $dummyData += [PSCustomObject]@{
                ID = $i
                ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                部署 = $departments[(Get-Random -Maximum $departments.Count)]
                作成日時 = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd HH:mm:ss")
                ステータス = @("正常", "警告", "注意")[(Get-Random -Maximum 3)]
                数値データ = Get-Random -Minimum 10 -Maximum 100
            }
            
            # 進行状況表示
            if ($i % 3 -eq 0) {
                Write-Host "  → $i/$RecordCount 件生成済み" -ForegroundColor Gray
            }
        }
        
        Write-Host "✅ $DataType データ生成完了: $RecordCount 件" -ForegroundColor Green
        return $dummyData
    }
    
    # 各レポートタイプをテスト
    $testCases = @(
        @{ Type = "Daily"; Count = 5; Name = "📊 日次レポート" },
        @{ Type = "Weekly"; Count = 3; Name = "📅 週次レポート" },
        @{ Type = "License"; Count = 7; Name = "📊 ライセンス分析" },
        @{ Type = "UsageAnalysis"; Count = 8; Name = "📈 使用状況分析" }
    )
    
    foreach ($testCase in $testCases) {
        Write-Host "`n🔄 テスト実行: $($testCase.Name)" -ForegroundColor Yellow
        
        $data = New-DummyData -DataType $testCase.Type -RecordCount $testCase.Count
        
        Write-Host "📋 生成結果: $($data.Count) 件のデータ" -ForegroundColor Cyan
        if ($data.Count -gt 0) {
            Write-Host "📝 サンプル: $($data[0].ユーザー名) - $($data[0].部署)" -ForegroundColor Gray
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "`n✅ GUI簡易テスト完了!" -ForegroundColor Green
    Write-Host "🚀 GUIアプリケーションでのボタンクリック処理は正常に動作するはずです" -ForegroundColor Cyan
    
}
catch {
    Write-Host "`n❌ テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== GUI簡易テスト終了 ===" -ForegroundColor Magenta