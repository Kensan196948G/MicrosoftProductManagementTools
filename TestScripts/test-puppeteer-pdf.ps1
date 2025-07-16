# ================================================================================
# Puppeteer PDF生成テストスクリプト
# Microsoft 365統合管理ツール用
# ================================================================================

[CmdletBinding()]
param()

# スクリプトの場所とToolRootを設定
$Script:TestRoot = $PSScriptRoot
$Script:ToolRoot = Split-Path $Script:TestRoot -Parent

Write-Host "=== Puppeteer PDF生成テスト開始 ===" -ForegroundColor Green
Write-Host "ToolRoot: $Script:ToolRoot" -ForegroundColor Cyan
Write-Host "TestRoot: $Script:TestRoot" -ForegroundColor Cyan

try {
    # PuppeteerPdfGeneratorモジュールをインポート
    $modulePath = Join-Path $Script:ToolRoot "Scripts\Common\PuppeteerPdfGenerator.psm1"
    Write-Host "モジュールパス: $modulePath" -ForegroundColor Cyan
    
    if (-not (Test-Path $modulePath)) {
        throw "PuppeteerPdfGeneratorモジュールが見つかりません: $modulePath"
    }
    
    Import-Module $modulePath -Force
    Write-Host "PuppeteerPdfGeneratorモジュールを読み込みました" -ForegroundColor Green
    
    # テスト用HTMLコンテンツを作成
    $testHtml = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Puppeteer PDF生成テスト</title>
    <style>
        body {
            font-family: 'Noto Sans JP', 'Yu Gothic UI', sans-serif;
            margin: 20px;
            line-height: 1.6;
        }
        .header {
            background: linear-gradient(135deg, #0078d4, #005a9e);
            color: white;
            padding: 30px;
            text-align: center;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .content {
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
            background: white;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px 8px;
            text-align: left;
        }
        th {
            background-color: #0078d4;
            color: white;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .footer {
            margin-top: 40px;
            text-align: center;
            font-size: 12px;
            color: #666;
            border-top: 1px solid #ddd;
            padding-top: 20px;
        }
        .success { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .info { color: #17a2b8; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Microsoft 365統合管理ツール</h1>
        <h2>Puppeteer PDF生成テスト</h2>
        <p>生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH時mm分ss秒")</p>
    </div>
    
    <div class="content">
        <h3>📝 テスト概要</h3>
        <p>このPDFは<strong class="success">Puppeteer</strong>によって生成されました。</p>
        <p><strong>特徴:</strong></p>
        <ul>
            <li>✅ 日本語フォント完全対応</li>
            <li>✅ PowerShellからの呼び出し</li>
            <li>✅ Node.js統合</li>
            <li>✅ 高品質PDF出力</li>
            <li>✅ レスポンシブデザイン</li>
        </ul>
    </div>
    
    <div class="content">
        <h3>📊 システム情報</h3>
        <table>
            <thead>
                <tr>
                    <th>項目</th>
                    <th>値</th>
                    <th>ステータス</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>PowerShell バージョン</td>
                    <td>$($PSVersionTable.PSVersion)</td>
                    <td><span class="success">正常</span></td>
                </tr>
                <tr>
                    <td>OS プラットフォーム</td>
                    <td>$($PSVersionTable.Platform)</td>
                    <td><span class="success">対応</span></td>
                </tr>
                <tr>
                    <td>PDF生成エンジン</td>
                    <td>Puppeteer + Chromium</td>
                    <td><span class="success">動作中</span></td>
                </tr>
                <tr>
                    <td>生成日時</td>
                    <td>$(Get-Date)</td>
                    <td><span class="info">最新</span></td>
                </tr>
                <tr>
                    <td>文字エンコーディング</td>
                    <td>UTF-8</td>
                    <td><span class="success">対応</span></td>
                </tr>
                <tr>
                    <td>フォント描画</td>
                    <td>ネイティブ日本語対応</td>
                    <td><span class="success">最適化済み</span></td>
                </tr>
            </tbody>
        </table>
    </div>
    
    <div class="content">
        <h3>🔍 テストデータ</h3>
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>ユーザー名</th>
                    <th>部署</th>
                    <th>ライセンス</th>
                    <th>利用率</th>
                    <th>ステータス</th>
                </tr>
            </thead>
            <tbody>
"@

    # テーブルデータを動的に生成
    $userNames = @("田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一", "伊藤光子", "山田和也", "中村真理")
    $departments = @("営業部", "開発部", "総務部", "人事部", "経理部", "マーケティング部", "システム部", "企画部")
    $licenses = @("Microsoft 365 E3", "Microsoft 365 E5", "Office 365 E1", "Teams Essentials")
    $statuses = @('<span class="success">正常</span>', '<span class="warning">注意</span>', '<span class="info">確認中</span>')
    
    for ($i = 1; $i -le 10; $i++) {
        $userName = $userNames[(Get-Random -Maximum $userNames.Count)]
        $department = $departments[(Get-Random -Maximum $departments.Count)]
        $license = $licenses[(Get-Random -Maximum $licenses.Count)]
        $usage = Get-Random -Minimum 45 -Maximum 98
        $status = $statuses[(Get-Random -Maximum $statuses.Count)]
        
        $testHtml += @"
                <tr>
                    <td>$i</td>
                    <td>$userName</td>
                    <td>$department</td>
                    <td>$license</td>
                    <td>$usage%</td>
                    <td>$status</td>
                </tr>
"@
    }
    
    # HTMLを閉じる
    $testHtml += @"
            </tbody>
        </table>
    </div>
    
    <div class="content">
        <h3>📈 パフォーマンス指標</h3>
        <p><strong>この数秒でPuppeteerが以下を実行:</strong></p>
        <ul>
            <li>🌐 Chromiumブラウザの起動</li>
            <li>📄 HTMLコンテンツの解析</li>
            <li>🎨 CSSスタイルの適用</li>
            <li>🖼️ 日本語フォントの描画</li>
            <li>📑 PDF形式への変換</li>
            <li>💾 ファイル保存</li>
        </ul>
    </div>
    
    <div class="footer">
        <p><strong>Generated by Microsoft 365統合管理ツール</strong></p>
        <p>Powered by Puppeteer + PowerShell + Node.js</p>
        <p>日本語フォント対応 • 高品質PDF出力 • 自動化対応</p>
    </div>
</body>
</html>
"@
    
    Write-Host "テスト用HTMLコンテンツを生成しました" -ForegroundColor Green
    
    # 出力ディレクトリを準備
    $outputDir = Join-Path $Script:ToolRoot "TestScripts\TestReports"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Host "出力ディレクトリを作成しました: $outputDir" -ForegroundColor Green
    }
    
    # PDF生成実行
    Write-Host "Puppeteer PDF生成を開始します..." -ForegroundColor Yellow
    $pdfFileName = "PuppeteerTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').pdf"
    $pdfPath = Export-HtmlToPdf -HtmlContent $testHtml -OutputDirectory $outputDir -FileName $pdfFileName
    
    if ($pdfPath -and (Test-Path $pdfPath)) {
        $fileInfo = Get-Item $pdfPath
        Write-Host "✅ PDF生成テスト成功!" -ForegroundColor Green
        Write-Host "📁 ファイルパス: $($fileInfo.FullName)" -ForegroundColor Cyan
        Write-Host "📏 ファイルサイズ: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Cyan
        Write-Host "⏰ 生成日時: $($fileInfo.CreationTime)" -ForegroundColor Cyan
        
        # PDFファイルを開く
        Write-Host "PDFファイルを開いています..." -ForegroundColor Yellow
        Start-Process $pdfPath
        
        Write-Host "=== Puppeteer PDF生成テスト完了 ===" -ForegroundColor Green
    } else {
        Write-Host "❌ PDF生成テスト失敗" -ForegroundColor Red
        Write-Host "PDFファイルが生成されませんでした" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Puppeteer PDF生成テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== テスト終了 ===" -ForegroundColor Magenta