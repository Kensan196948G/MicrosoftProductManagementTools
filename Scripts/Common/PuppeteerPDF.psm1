# ================================================================================
# PuppeteerPDF.psm1
# Puppeteer+Node.jsベースのPDF生成モジュール
# HTMLレポートから高品質なPDFを生成
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force

# Puppeteerセットアップ状態の確認
function Test-PuppeteerSetup {
    try {
        # Node.js とnpm の確認
        $nodeVersion = node --version 2>$null
        if (-not $nodeVersion) {
            Write-Log "Node.js が見つかりません。インストールが必要です。" -Level "Warning"
            return $false
        }
        
        # package.json の確認
        $packageJsonPath = Join-Path $PSScriptRoot "..\..\package.json"
        if (-not (Test-Path $packageJsonPath)) {
            Write-Log "package.json が見つかりません。Puppeteer環境を初期化します。" -Level "Info"
            return $false
        }
        
        # node_modules/puppeteer の確認
        $puppeteerPath = Join-Path $PSScriptRoot "..\..\node_modules\puppeteer"
        if (-not (Test-Path $puppeteerPath)) {
            Write-Log "Puppeteer がインストールされていません。インストールを実行します。" -Level "Info"
            return $false
        }
        
        Write-Log "Puppeteer環境は正常にセットアップされています。" -Level "Info"
        return $true
    }
    catch {
        Write-Log "Puppeteer環境の確認中にエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Puppeteerの初期設定
function Initialize-PuppeteerEnvironment {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force = $false
    )
    
    try {
        $rootPath = Join-Path $PSScriptRoot "..\..\"
        $packageJsonPath = Join-Path $rootPath "package.json"
        
        # package.json の作成または更新
        if (-not (Test-Path $packageJsonPath) -or $Force) {
            $packageJson = @{
                name = "microsoft-management-tools"
                version = "1.0.0"
                description = "Microsoft 365 管理ツール - PDF生成用Puppeteer環境"
                main = "index.js"
                scripts = @{
                    "generate-pdf" = "node scripts/generate-pdf.js"
                }
                dependencies = @{
                    puppeteer = "^21.11.0"
                }
                keywords = @("microsoft", "365", "pdf", "puppeteer")
                author = "Microsoft Management Tools"
                license = "MIT"
            }
            
            $packageJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $packageJsonPath -Encoding UTF8 -Force
            Write-Log "package.json を作成しました: $packageJsonPath" -Level "Info"
        }
        
        # Puppeteer PDF生成スクリプトの作成
        $scriptsDir = Join-Path $rootPath "scripts"
        if (-not (Test-Path $scriptsDir)) {
            New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null
        }
        
        $pdfScriptPath = Join-Path $scriptsDir "generate-pdf.js"
        $pdfScript = @"
const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// コマンドライン引数の解析
const args = process.argv.slice(2);
const inputFile = args[0];
const outputFile = args[1];
const options = JSON.parse(args[2] || '{}');

if (!inputFile || !outputFile) {
    console.error('使用方法: node generate-pdf.js <入力HTMLファイル> <出力PDFファイル> [オプション]');
    process.exit(1);
}

// デフォルト設定
const defaultOptions = {
    format: 'A4',
    margin: {
        top: '20mm',
        right: '15mm',
        bottom: '20mm',
        left: '15mm'
    },
    printBackground: true,
    preferCSSPageSize: false,
    displayHeaderFooter: true,
    headerTemplate: '<div style="font-size:10px; width:100%; text-align:center; color:#666;">{{REPORT_NAME}}</div>',
    footerTemplate: '<div style="font-size:10px; width:100%; text-align:center; color:#666;">ページ <span class="pageNumber"></span> / <span class="totalPages"></span> - 生成日時: {{GENERATED_DATE}}</div>',
    timeout: 30000,
    waitForNetworkIdle: true
};

// オプション統合
const pdfOptions = { ...defaultOptions, ...options };

async function generatePDF() {
    let browser;
    try {
        console.log('Puppeteer PDF生成を開始します...');
        console.log('入力ファイル:', inputFile);
        console.log('出力ファイル:', outputFile);
        
        // HTMLファイルの存在確認
        if (!fs.existsSync(inputFile)) {
            throw new Error('入力HTMLファイルが見つかりません: ' + inputFile);
        }
        
        // ブラウザ起動
        browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu',
                '--disable-extensions',
                '--disable-plugins',
                '--disable-images',
                '--disable-javascript',
                '--disable-web-security',
                '--allow-running-insecure-content'
            ]
        });
        
        const page = await browser.newPage();
        
        // 日本語フォント対応
        await page.evaluateOnNewDocument(() => {
            // 日本語フォントの設定
            const style = document.createElement('style');
            style.textContent = `
                * {
                    font-family: 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', 'Noto Sans CJK JP', 'Yu Gothic', 'YuGothic', 'Meiryo', sans-serif !important;
                }
            `;
            document.head.appendChild(style);
        });
        
        // HTMLファイルをロード
        const htmlContent = fs.readFileSync(inputFile, 'utf8');
        const fileUrl = 'file://' + path.resolve(inputFile);
        
        console.log('HTMLファイルをロードしています...');
        await page.goto(fileUrl, {
            waitUntil: pdfOptions.waitForNetworkIdle ? 'networkidle0' : 'load',
            timeout: pdfOptions.timeout
        });
        
        // ページサイズの自動調整
        await page.addStyleTag({
            content: `
                @page {
                    size: ${pdfOptions.format};
                    margin: ${pdfOptions.margin.top} ${pdfOptions.margin.right} ${pdfOptions.margin.bottom} ${pdfOptions.margin.left};
                }
                
                body {
                    -webkit-print-color-adjust: exact !important;
                    print-color-adjust: exact !important;
                }
                
                .container {
                    max-width: none !important;
                    width: 100% !important;
                }
                
                table {
                    width: 100% !important;
                    table-layout: fixed !important;
                }
                
                th, td {
                    word-wrap: break-word !important;
                    overflow-wrap: break-word !important;
                }
            `
        });
        
        // レポート名と日時のテンプレート置換
        const reportName = await page.evaluate(() => {
            const titleElement = document.querySelector('.title');
            return titleElement ? titleElement.textContent : 'レポート';
        });
        
        const generatedDate = await page.evaluate(() => {
            const timestampElement = document.querySelector('.timestamp');
            return timestampElement ? timestampElement.textContent : new Date().toLocaleString('ja-JP');
        });
        
        pdfOptions.headerTemplate = pdfOptions.headerTemplate.replace('{{REPORT_NAME}}', reportName);
        pdfOptions.footerTemplate = pdfOptions.footerTemplate.replace('{{GENERATED_DATE}}', generatedDate);
        
        // 出力ディレクトリの作成
        const outputDir = path.dirname(outputFile);
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }
        
        // PDF生成
        console.log('PDFを生成しています...');
        await page.pdf({
            path: outputFile,
            format: pdfOptions.format,
            margin: pdfOptions.margin,
            printBackground: pdfOptions.printBackground,
            preferCSSPageSize: pdfOptions.preferCSSPageSize,
            displayHeaderFooter: pdfOptions.displayHeaderFooter,
            headerTemplate: pdfOptions.headerTemplate,
            footerTemplate: pdfOptions.footerTemplate
        });
        
        console.log('PDF生成が完了しました:', outputFile);
        
        // ファイルサイズの確認
        const stats = fs.statSync(outputFile);
        const fileSizeInMB = (stats.size / (1024 * 1024)).toFixed(2);
        console.log('ファイルサイズ:', fileSizeInMB + ' MB');
        
        return {
            success: true,
            outputFile: outputFile,
            fileSize: fileSizeInMB + ' MB',
            reportName: reportName
        };
        
    } catch (error) {
        console.error('PDF生成エラー:', error.message);
        return {
            success: false,
            error: error.message
        };
    } finally {
        if (browser) {
            await browser.close();
        }
    }
}

// PDF生成実行
generatePDF().then(result => {
    if (result.success) {
        console.log('PDF生成成功:', JSON.stringify(result, null, 2));
        process.exit(0);
    } else {
        console.error('PDF生成失敗:', result.error);
        process.exit(1);
    }
}).catch(error => {
    console.error('予期しないエラー:', error);
    process.exit(1);
});
"@
        
        $pdfScript | Out-File -FilePath $pdfScriptPath -Encoding UTF8 -Force
        Write-Log "Puppeteer PDF生成スクリプトを作成しました: $pdfScriptPath" -Level "Info"
        
        # npm install の実行
        Write-Log "Puppeteer をインストールしています..." -Level "Info"
        $originalLocation = Get-Location
        try {
            Set-Location $rootPath
            $npmResult = npm install 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Puppeteer のインストールが完了しました。" -Level "Info"
                return $true
            } else {
                Write-Log "Puppeteer のインストールに失敗しました: $npmResult" -Level "Error"
                return $false
            }
        }
        finally {
            Set-Location $originalLocation
        }
    }
    catch {
        Write-Log "Puppeteer環境の初期化中にエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# HTMLファイルからPDFを生成
function ConvertTo-PDFFromHTML {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputHtmlPath,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPdfPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Options = @{}
    )
    
    try {
        # 入力ファイルの存在確認
        if (-not (Test-Path $InputHtmlPath)) {
            throw "入力HTMLファイルが見つかりません: $InputHtmlPath"
        }
        
        # Puppeteer環境の確認
        if (-not (Test-PuppeteerSetup)) {
            Write-Log "Puppeteer環境を初期化します..." -Level "Info"
            if (-not (Initialize-PuppeteerEnvironment)) {
                throw "Puppeteer環境の初期化に失敗しました。"
            }
        }
        
        # 出力ディレクトリの作成
        $outputDir = Split-Path $OutputPdfPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        # PDF生成スクリプトのパス
        $scriptPath = Join-Path $PSScriptRoot "..\..\scripts\generate-pdf.js"
        
        # オプションをJSON形式に変換
        $optionsJson = $Options | ConvertTo-Json -Compress
        
        # Node.js スクリプトの実行
        Write-Log "Puppeteer でPDF生成を開始します..." -Level "Info"
        $startTime = Get-Date
        
        $nodeArgs = @(
            $scriptPath,
            "`"$InputHtmlPath`"",
            "`"$OutputPdfPath`"",
            "`"$optionsJson`""
        )
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "node"
        $processInfo.Arguments = $nodeArgs -join " "
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.WorkingDirectory = Join-Path $PSScriptRoot "..\..\"
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($exitCode -eq 0) {
            Write-Log "PDF生成が完了しました: $OutputPdfPath (処理時間: $([math]::Round($duration, 2))秒)" -Level "Info"
            
            # 出力ログの表示
            if ($stdout) {
                Write-Log "Node.js 出力: $stdout" -Level "Debug"
            }
            
            # ファイルサイズの確認
            if (Test-Path $OutputPdfPath) {
                $fileSize = (Get-Item $OutputPdfPath).Length
                $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                Write-Log "生成されたPDFファイルサイズ: $fileSizeMB MB" -Level "Info"
            }
            
            return @{
                Success = $true
                OutputPath = $OutputPdfPath
                ProcessingTime = $duration
                FileSize = $fileSizeMB
            }
        }
        else {
            $errorMessage = "PDF生成に失敗しました (終了コード: $exitCode)"
            if ($stderr) {
                $errorMessage += "`nエラー詳細: $stderr"
            }
            if ($stdout) {
                $errorMessage += "`n出力: $stdout"
            }
            
            Write-Log $errorMessage -Level "Error"
            throw $errorMessage
        }
    }
    catch {
        Write-Log "PDF生成エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# HTMLレポートとPDFの同時生成
function New-HTMLReportWithPDF {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [array]$DataSections = @(),
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnablePDF = $true,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$PdfOptions = @{}
    )
    
    try {
        # 従来のHTMLレポート生成
        $htmlPath = New-HTMLReport -Title $Title -DataSections $DataSections -OutputPath $OutputPath
        
        if ($EnablePDF) {
            # PDFファイルパスの生成
            $pdfPath = $OutputPath -replace "\.html$", ".pdf"
            
            # PDF生成
            $pdfResult = ConvertTo-PDFFromHTML -InputHtmlPath $htmlPath -OutputPdfPath $pdfPath -Options $PdfOptions
            
            return @{
                HtmlPath = $htmlPath
                PdfPath = $pdfPath
                PdfResult = $pdfResult
            }
        }
        else {
            return @{
                HtmlPath = $htmlPath
                PdfPath = $null
                PdfResult = $null
            }
        }
    }
    catch {
        Write-Log "HTMLレポート+PDF生成エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# 拡張HTMLレポートでのPDF生成
function New-EnhancedHTMLReportWithPDF {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportName,
        
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$CustomSettings = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$EnablePDF = $true,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$PdfOptions = @{}
    )
    
    try {
        # 拡張HTMLレポート生成
        $htmlPath = New-EnhancedHTMLReport -ReportName $ReportName -Data $Data -OutputPath $OutputPath -Description $Description -CustomSettings $CustomSettings
        
        if ($EnablePDF) {
            # PDFファイルパスの生成
            $pdfPath = $OutputPath -replace "\.html$", ".pdf"
            
            # PDF生成
            $pdfResult = ConvertTo-PDFFromHTML -InputHtmlPath $htmlPath -OutputPdfPath $pdfPath -Options $PdfOptions
            
            return @{
                HtmlPath = $htmlPath
                PdfPath = $pdfPath
                PdfResult = $pdfResult
            }
        }
        else {
            return @{
                HtmlPath = $htmlPath
                PdfPath = $null
                PdfResult = $null
            }
        }
    }
    catch {
        Write-Log "拡張HTMLレポート+PDF生成エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# 既存のHTMLファイルからPDFを一括生成
function ConvertAll-HTMLToPDF {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDirectory,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = "",
        
        [Parameter(Mandatory = $false)]
        [string]$FilePattern = "*.html",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$PdfOptions = @{}
    )
    
    try {
        if (-not (Test-Path $InputDirectory)) {
            throw "入力ディレクトリが見つかりません: $InputDirectory"
        }
        
        # 出力ディレクトリの設定
        if (-not $OutputDirectory) {
            $OutputDirectory = $InputDirectory
        }
        
        # HTMLファイルの検索
        $htmlFiles = Get-ChildItem -Path $InputDirectory -Filter $FilePattern -Recurse
        
        if ($htmlFiles.Count -eq 0) {
            Write-Log "変換対象のHTMLファイルが見つかりません: $InputDirectory\$FilePattern" -Level "Warning"
            return @()
        }
        
        Write-Log "$($htmlFiles.Count)個のHTMLファイルをPDFに変換します..." -Level "Info"
        
        $results = @()
        $successCount = 0
        $errorCount = 0
        
        foreach ($htmlFile in $htmlFiles) {
            try {
                $relativePath = $htmlFile.FullName.Replace($InputDirectory, "").TrimStart("\")
                $pdfPath = Join-Path $OutputDirectory ($relativePath -replace "\.html$", ".pdf")
                
                Write-Log "変換中: $($htmlFile.Name)" -Level "Info"
                
                $result = ConvertTo-PDFFromHTML -InputHtmlPath $htmlFile.FullName -OutputPdfPath $pdfPath -Options $PdfOptions
                
                $results += @{
                    InputFile = $htmlFile.FullName
                    OutputFile = $pdfPath
                    Success = $result.Success
                    ProcessingTime = $result.ProcessingTime
                    FileSize = $result.FileSize
                }
                
                $successCount++
            }
            catch {
                Write-Log "変換エラー ($($htmlFile.Name)): $($_.Exception.Message)" -Level "Error"
                
                $results += @{
                    InputFile = $htmlFile.FullName
                    OutputFile = $pdfPath
                    Success = $false
                    Error = $_.Exception.Message
                }
                
                $errorCount++
            }
        }
        
        Write-Log "一括変換完了: 成功 $successCount 件、失敗 $errorCount 件" -Level "Info"
        
        return $results
    }
    catch {
        Write-Log "一括PDF変換エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

# エクスポート関数
Export-ModuleMember -Function Test-PuppeteerSetup, Initialize-PuppeteerEnvironment, ConvertTo-PDFFromHTML, New-HTMLReportWithPDF, New-EnhancedHTMLReportWithPDF, ConvertAll-HTMLToPDF