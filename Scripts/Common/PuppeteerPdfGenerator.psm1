# ================================================================================
# Puppeteer PDF生成モジュール
# Microsoft 365統合管理ツール用
# PowerShellからNode.js/Puppeteerを呼び出してPDF生成
# ================================================================================

# グローバル変数
$Script:ToolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Puppeteer PDF生成関数
function New-PuppeteerPdf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPdfPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Options = @{}
    )
    
    # 一時ファイル用変数
    $optionsFile = $null
    
    try {
        Write-Host "=== Puppeteer PDF生成開始 ===" -ForegroundColor Green
        Write-Host "入力HTMLファイル: $HtmlFilePath" -ForegroundColor Cyan
        Write-Host "出力PDFファイル: $OutputPdfPath" -ForegroundColor Cyan
        
        # Puppeteerスクリプトのパス
        $puppeteerScript = Join-Path $Script:ToolRoot "Scripts\generate-pdf.js"
        
        if (-not (Test-Path $puppeteerScript)) {
            throw "Puppeteerスクリプトが見つかりません: $puppeteerScript"
        }
        
        # HTMLファイルの存在確認
        if (-not (Test-Path $HtmlFilePath)) {
            throw "HTMLファイルが見つかりません: $HtmlFilePath"
        }
        
        # Node.jsの存在確認
        $nodeVersion = $null
        try {
            $nodeVersion = node --version 2>$null
            Write-Host "Node.js バージョン: $nodeVersion" -ForegroundColor Green
        }
        catch {
            throw "Node.jsがインストールされていません。Node.jsをインストールしてからお試しください。"
        }
        
        # Puppeteerの存在確認
        $puppeteerCheck = npm list puppeteer 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Puppeteerをインストール中..." -ForegroundColor Yellow
            npm install puppeteer
            if ($LASTEXITCODE -ne 0) {
                throw "Puppeteerのインストールに失敗しました"
            }
        }
        
        # PDFオプションを一時ファイルに保存（エスケープ問題回避）
        $optionsFile = "$env:TEMP\puppeteer_options_$(Get-Random).json"
        $optionsJson = if ($Options.Count -gt 0) { 
            $Options | ConvertTo-Json -Depth 10
        } else { 
            '{}' 
        }
        
        # オプションを一時ファイルに保存
        $optionsJson | Out-File -FilePath $optionsFile -Encoding UTF8 -Force
        
        # Puppeteerスクリプトを実行
        Write-Host "Puppeteerスクリプトを実行中..." -ForegroundColor Yellow
        
        # 引数（一時ファイルのパスを渡す）
        $arguments = @(
            $puppeteerScript,
            "`"$HtmlFilePath`"",
            "`"$OutputPdfPath`"",
            "`"$optionsFile`""
        )
        
        Write-Host "実行コマンド: node $($arguments -join ' ')" -ForegroundColor Cyan
        
        # Node.jsプロセスを実行
        $process = Start-Process -FilePath "node" -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\puppeteer_output.log" -RedirectStandardError "$env:TEMP\puppeteer_error.log"
        
        # 実行結果を確認
        if ($process.ExitCode -eq 0) {
            Write-Host "PDF生成が正常に完了しました" -ForegroundColor Green
            
            # 出力ログを表示
            if (Test-Path "$env:TEMP\puppeteer_output.log") {
                $output = Get-Content "$env:TEMP\puppeteer_output.log" -Raw
                if ($output.Trim()) {
                    Write-Host "Puppeteer出力:" -ForegroundColor Cyan
                    Write-Host $output -ForegroundColor Gray
                }
            }
            
            # PDFファイルの存在確認
            if (Test-Path $OutputPdfPath) {
                $fileInfo = Get-Item $OutputPdfPath
                Write-Host "PDFファイルが生成されました: $($fileInfo.FullName)" -ForegroundColor Green
                Write-Host "ファイルサイズ: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Green
                return $true
            } else {
                throw "PDFファイルが生成されませんでした"
            }
        } else {
            # エラーログを表示
            $errorOutput = ""
            if (Test-Path "$env:TEMP\puppeteer_error.log") {
                $errorOutput = Get-Content "$env:TEMP\puppeteer_error.log" -Raw
            }
            
            $standardOutput = ""
            if (Test-Path "$env:TEMP\puppeteer_output.log") {
                $standardOutput = Get-Content "$env:TEMP\puppeteer_output.log" -Raw
            }
            
            throw "Puppeteerスクリプトの実行に失敗しました (終了コード: $($process.ExitCode))`n標準出力: $standardOutput`nエラー出力: $errorOutput"
        }
        
    }
    catch {
        Write-Error "Puppeteer PDF生成エラー: $($_.Exception.Message)"
        return $false
    }
    finally {
        # 一時ファイルのクリーンアップ
        @("$env:TEMP\puppeteer_output.log", "$env:TEMP\puppeteer_error.log", $optionsFile) | ForEach-Object {
            if ($_ -and (Test-Path $_)) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# HTMLファイルからPDF生成（簡単な呼び出し用）
function Export-HtmlToPdf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlContent,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory,
        
        [Parameter(Mandatory = $false)]
        [string]$FileName = "report_$(Get-Date -Format 'yyyyMMdd_HHmmss').pdf"
    )
    
    try {
        # 一時HTMLファイルを作成
        $tempHtmlPath = Join-Path $env:TEMP "temp_$(Get-Date -Format 'yyyyMMddHHmmss').html"
        $outputPdfPath = Join-Path $OutputDirectory $FileName
        
        # 出力ディレクトリを作成
        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }
        
        # HTMLコンテンツを一時ファイルに保存
        $HtmlContent | Out-File -FilePath $tempHtmlPath -Encoding UTF8
        
        Write-Host "一時HTMLファイルを作成しました: $tempHtmlPath" -ForegroundColor Cyan
        
        # PuppeteerでPDF生成（シンプル版）
        $result = New-PuppeteerPdf -HtmlFilePath $tempHtmlPath -OutputPdfPath $outputPdfPath
        
        if ($result) {
            Write-Host "PDFエクスポートが完了しました: $outputPdfPath" -ForegroundColor Green
            
            # PDFファイルを開く
            if (Test-Path $outputPdfPath) {
                Start-Process $outputPdfPath
            }
            
            return $outputPdfPath
        } else {
            throw "PDFエクスポートに失敗しました"
        }
        
    }
    catch {
        Write-Error "HTMLからPDF変換エラー: $($_.Exception.Message)"
        return $null
    }
    finally {
        # 一時HTMLファイルのクリーンアップ
        if (Test-Path $tempHtmlPath) {
            Remove-Item $tempHtmlPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# WebページからPDF生成
function Export-WebPageToPdf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Options = @{}
    )
    
    try {
        Write-Host "WebページからPDF生成: $Url" -ForegroundColor Green
        
        # デフォルトオプション
        $defaultOptions = @{
            format = 'A4'
            margin = @{
                top = '20mm'
                right = '15mm'
                bottom = '20mm'
                left = '15mm'
            }
            printBackground = $true
            waitUntil = 'networkidle0'
            timeout = 30000
        }
        
        # オプションをマージ
        $mergedOptions = $defaultOptions
        foreach ($key in $Options.Keys) {
            $mergedOptions[$key] = $Options[$key]
        }
        
        # PuppeteerスクリプトでURL直接指定による生成
        $puppeteerScript = Join-Path $Script:ToolRoot "Scripts\generate-pdf.js"
        
        if (-not (Test-Path $puppeteerScript)) {
            throw "Puppeteerスクリプトが見つかりません: $puppeteerScript"
        }
        
        $optionsJson = $mergedOptions | ConvertTo-Json -Compress
        
        $arguments = @(
            $puppeteerScript,
            "`"$Url`"",
            "`"$OutputPath`"",
            "`"$optionsJson`""
        )
        
        # Node.jsプロセスを実行
        $process = Start-Process -FilePath "node" -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -and (Test-Path $OutputPath)) {
            Write-Host "WebページのPDF生成が完了しました: $OutputPath" -ForegroundColor Green
            return $true
        } else {
            throw "WebページのPDF生成に失敗しました"
        }
        
    }
    catch {
        Write-Error "WebページPDF生成エラー: $($_.Exception.Message)"
        return $false
    }
}

# モジュールのエクスポート
Export-ModuleMember -Function New-PuppeteerPdf, Export-HtmlToPdf, Export-WebPageToPdf