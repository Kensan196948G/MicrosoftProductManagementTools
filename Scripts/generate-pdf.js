#!/usr/bin/env node

/**
 * Puppeteer PDF生成スクリプト
 * Microsoft 365統合管理ツール用
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function generatePDF() {
    let browser = null;
    let args = null;
    
    try {
        // コマンドライン引数の解析
        args = process.argv.slice(2);
        if (args.length < 2) {
            console.error('使用方法: node generate-pdf.js <HTMLファイルパス> <PDFファイルパス> [オプション]');
            process.exit(1);
        }
        
        const htmlPath = args[0];
        const pdfPath = args[1];
        
        // オプションをファイルまたは文字列から読み込み
        let options = {};
        if (args[2]) {
            try {
                // 第3引数がファイルパスかJSONかを判定
                if (fs.existsSync(args[2])) {
                    // ファイルから読み込み
                    const optionsContent = fs.readFileSync(args[2], 'utf8');
                    options = JSON.parse(optionsContent);
                    console.log(`  オプションファイルから読み込み: ${args[2]}`);
                } else {
                    // 直接JSONとして解析
                    options = JSON.parse(args[2]);
                    console.log(`  オプションを直接解析`);
                }
            } catch (error) {
                console.error(`オプション解析エラー: ${error.message}`);
                console.error(`引数: ${args[2]}`);
                process.exit(1);
            }
        }
        
        // HTMLファイルの存在確認
        if (!fs.existsSync(htmlPath)) {
            console.error(`エラー: HTMLファイルが見つかりません: ${htmlPath}`);
            process.exit(1);
        }
        
        console.log(`PDF生成開始:`);
        console.log(`  入力HTML: ${htmlPath}`);
        console.log(`  出力PDF: ${pdfPath}`);
        
        // PDFファイルの出力ディレクトリを作成
        const pdfDir = path.dirname(pdfPath);
        if (!fs.existsSync(pdfDir)) {
            fs.mkdirSync(pdfDir, { recursive: true });
            console.log(`  出力ディレクトリを作成: ${pdfDir}`);
        }
        
        // Puppeteer起動
        browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu'
            ]
        });
        
        console.log('  Puppeteerブラウザを起動しました');
        
        // 新しいページを作成
        const page = await browser.newPage();
        
        // 日本語フォント対応のためのViewport設定
        await page.setViewport({ 
            width: 1920, 
            height: 1080,
            deviceScaleFactor: 2
        });
        
        // HTMLファイルを読み込み
        const fileUrl = `file://${path.resolve(htmlPath)}`;
        console.log(`  HTMLファイルを読み込み中: ${fileUrl}`);
        
        await page.goto(fileUrl, { 
            waitUntil: ['networkidle0', 'domcontentloaded'],
            timeout: 30000
        });
        
        // フォントの読み込みを待機
        try {
            await page.evaluateHandle('document.fonts.ready');
        } catch (e) {
            console.log('  フォント待機をスキップ');
        }
        
        // 追加の待機時間（レンダリング完了）
        try {
            await page.waitForTimeout(2000);
        } catch (e) {
            // Puppeteer v21以降では waitForTimeout が削除されたため、代替手段を使用
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
        
        console.log('  HTMLページの読み込み完了');
        
        // PDFオプションの設定
        const defaultPdfOptions = {
            format: 'A4',
            margin: {
                top: '20mm',
                right: '15mm',
                bottom: '20mm',
                left: '15mm'
            },
            printBackground: true,
            displayHeaderFooter: true,
            headerTemplate: '<div></div>',
            footerTemplate: `
                <div style="font-size: 10px; width: 100%; text-align: center; color: #666;">
                    Microsoft 365統合管理ツール - 生成日時: ${new Date().toLocaleString('ja-JP')} - ページ <span class="pageNumber"></span> / <span class="totalPages"></span>
                </div>
            `,
            preferCSSPageSize: false
        };
        
        // カスタムオプションをマージ
        const pdfOptions = { ...defaultPdfOptions, ...options, path: pdfPath };
        
        console.log('  PDF生成中...');
        
        // PDF生成
        await page.pdf(pdfOptions);
        
        console.log(`  PDF生成完了: ${pdfPath}`);
        
        // ファイルサイズの確認
        const stats = fs.statSync(pdfPath);
        const fileSizeKB = Math.round(stats.size / 1024);
        console.log(`  ファイルサイズ: ${fileSizeKB} KB`);
        
        return {
            success: true,
            path: pdfPath,
            size: stats.size
        };
        
    } catch (error) {
        console.error('PDF生成エラー:', error.message);
        
        // デバッグ情報
        if (error.message.includes('Protocol error')) {
            console.error('ヒント: Puppeteerのバージョンを確認し、必要に応じて更新してください');
        } else if (error.message.includes('TimeoutError')) {
            console.error('ヒント: HTMLファイルの読み込みがタイムアウトしました。ファイルサイズやネットワーク接続を確認してください');
        }
        
        process.exit(1);
        
    } finally {
        // ブラウザを閉じる
        if (browser) {
            await browser.close();
            console.log('  Puppeteerブラウザを終了しました');
        }
        
        // 一時オプションファイルのクリーンアップ
        if (args[2] && fs.existsSync(args[2]) && args[2].includes('puppeteer_options_')) {
            try {
                fs.unlinkSync(args[2]);
                console.log('  一時オプションファイルを削除しました');
            } catch (e) {
                // エラーは無視（クリーンアップなので）
            }
        }
    }
}

// メイン実行
if (require.main === module) {
    generatePDF().catch(error => {
        console.error('予期しないエラー:', error);
        process.exit(1);
    });
}

module.exports = { generatePDF };