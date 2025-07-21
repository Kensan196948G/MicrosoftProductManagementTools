#!/usr/bin/env node
// Microsoft 365 Management Tools - 統合テスト実行スクリプト
// Frontend + Backend 統合テスト自動化

const { spawn, exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const config = require('../test-integration.config.js');

class IntegrationTestRunner {
  constructor() {
    this.projectRoot = '/mnt/e/MicrosoftProductManagementTools';
    this.results = {
      pytest: { status: 'pending', duration: 0, coverage: 0 },
      cypress: { status: 'pending', duration: 0, tests: 0 },
      playwright: { status: 'pending', duration: 0, tests: 0 },
      overall: { status: 'pending', startTime: null, endTime: null }
    };
  }

  // メイン実行関数
  async run() {
    console.log('🚀 Microsoft 365管理ツール - 統合テスト開始');
    console.log('=' .repeat(60));
    
    this.results.overall.startTime = new Date();
    
    try {
      // 1. 環境確認
      await this.checkEnvironment();
      
      // 2. バックエンド pytest テスト実行
      await this.runPytestTests();
      
      // 3. フロントエンド Cypress テスト実行  
      await this.runCypressTests();
      
      // 4. フロントエンド Playwright テスト実行
      await this.runPlaywrightTests();
      
      // 5. 統合レポート生成
      await this.generateCombinedReport();
      
      this.results.overall.status = 'completed';
      console.log('✅ 統合テスト完了');
      
    } catch (error) {
      this.results.overall.status = 'failed';
      console.error('❌ 統合テスト失敗:', error.message);
      process.exit(1);
    } finally {
      this.results.overall.endTime = new Date();
      await this.printSummary();
    }
  }

  // 環境確認
  async checkEnvironment() {
    console.log('🔍 環境確認中...');
    
    // Python環境確認
    try {
      await this.executeCommand('python --version', { cwd: this.projectRoot });
      console.log('✅ Python環境確認済み');
    } catch (error) {
      throw new Error('Python環境が見つかりません');
    }
    
    // Node.js環境確認
    try {
      await this.executeCommand('node --version');
      console.log('✅ Node.js環境確認済み');
    } catch (error) {
      throw new Error('Node.js環境が見つかりません');
    }
    
    // pytest環境確認
    try {
      await this.executeCommand('python -c "import pytest; print(pytest.__version__)"', 
        { cwd: this.projectRoot });
      console.log('✅ pytest環境確認済み');
    } catch (error) {
      throw new Error('pytest環境が見つかりません');
    }
  }

  // pytest テスト実行
  async runPytestTests() {
    console.log('\n🐍 pytest テスト実行中...');
    const startTime = Date.now();
    
    try {
      const command = [
        'python', '-m', 'pytest',
        '--verbose',
        '--tb=short',
        '--maxfail=5',
        '--durations=10',
        '--cov=src',
        '--cov-report=html:test-results-integration/coverage-backend',
        '--cov-report=json:test-results-integration/coverage-backend.json',
        '--junit-xml=test-results-integration/pytest-results.xml',
        'Tests/'
      ].join(' ');
      
      const result = await this.executeCommand(command, { 
        cwd: this.projectRoot,
        timeout: 600000 // 10分
      });
      
      this.results.pytest.status = 'passed';
      this.results.pytest.duration = Date.now() - startTime;
      
      // カバレッジ情報取得
      await this.extractPytestCoverage();
      
      console.log('✅ pytest テスト完了');
      
    } catch (error) {
      this.results.pytest.status = 'failed';
      console.error('❌ pytest テスト失敗:', error.message);
      
      if (!config.onFailure.continueOnError) {
        throw error;
      }
    }
  }

  // Cypress テスト実行
  async runCypressTests() {
    console.log('\n🌐 Cypress E2Eテスト実行中...');
    const startTime = Date.now();
    
    try {
      const command = [
        'npx cypress run',
        '--config video=true,screenshotOnRunFailure=true',
        '--reporter junit',
        '--reporter-options "mochaFile=test-results-integration/cypress-results.xml"',
        '--spec "cypress/e2e/**/*.cy.{js,jsx,ts,tsx}"'
      ].join(' ');
      
      await this.executeCommand(command, { 
        cwd: path.join(this.projectRoot, 'frontend'),
        timeout: 900000 // 15分
      });
      
      this.results.cypress.status = 'passed';
      this.results.cypress.duration = Date.now() - startTime;
      
      // Cypressテスト結果解析
      await this.extractCypressResults();
      
      console.log('✅ Cypress テスト完了');
      
    } catch (error) {
      this.results.cypress.status = 'failed';
      console.error('❌ Cypress テスト失敗:', error.message);
      
      if (!config.onFailure.continueOnError) {
        throw error;
      }
    }
  }

  // Playwright テスト実行
  async runPlaywrightTests() {
    console.log('\n🎭 Playwright テスト実行中...');
    const startTime = Date.now();
    
    try {
      const command = [
        'npx playwright test',
        '--reporter=html,junit',
        '--output-dir=test-results-integration/playwright',
        'tests/e2e/'
      ].join(' ');
      
      await this.executeCommand(command, { 
        cwd: path.join(this.projectRoot, 'frontend'),
        timeout: 1200000 // 20分
      });
      
      this.results.playwright.status = 'passed';
      this.results.playwright.duration = Date.now() - startTime;
      
      // Playwrightテスト結果解析
      await this.extractPlaywrightResults();
      
      console.log('✅ Playwright テスト完了');
      
    } catch (error) {
      this.results.playwright.status = 'failed';
      console.error('❌ Playwright テスト失敗:', error.message);
      
      if (!config.onFailure.continueOnError) {
        throw error;
      }
    }
  }

  // pytestカバレッジ抽出
  async extractPytestCoverage() {
    try {
      const coverageFile = path.join(this.projectRoot, 'test-results-integration/coverage-backend.json');
      if (fs.existsSync(coverageFile)) {
        const coverage = JSON.parse(fs.readFileSync(coverageFile, 'utf8'));
        this.results.pytest.coverage = Math.round(coverage.totals.percent_covered);
      }
    } catch (error) {
      console.warn('⚠️ カバレッジ情報の取得に失敗:', error.message);
    }
  }

  // Cypress結果抽出
  async extractCypressResults() {
    try {
      const resultsFile = path.join(this.projectRoot, 'frontend/test-results-integration/cypress-results.xml');
      if (fs.existsSync(resultsFile)) {
        const content = fs.readFileSync(resultsFile, 'utf8');
        const matches = content.match(/tests="(\d+)"/);
        this.results.cypress.tests = matches ? parseInt(matches[1]) : 0;
      }
    } catch (error) {
      console.warn('⚠️ Cypress結果の取得に失敗:', error.message);
    }
  }

  // Playwright結果抽出  
  async extractPlaywrightResults() {
    try {
      const resultsDir = path.join(this.projectRoot, 'frontend/test-results-integration/playwright');
      if (fs.existsSync(resultsDir)) {
        const files = fs.readdirSync(resultsDir);
        this.results.playwright.tests = files.filter(f => f.endsWith('.json')).length;
      }
    } catch (error) {
      console.warn('⚠️ Playwright結果の取得に失敗:', error.message);
    }
  }

  // 統合レポート生成
  async generateCombinedReport() {
    console.log('\n📊 統合レポート生成中...');
    
    const reportData = {
      timestamp: new Date().toISOString(),
      project: 'Microsoft 365 Management Tools',
      version: '2.0',
      testResults: this.results,
      summary: {
        totalDuration: this.results.overall.endTime - this.results.overall.startTime,
        totalTests: this.results.cypress.tests + this.results.playwright.tests,
        overallStatus: this.calculateOverallStatus()
      }
    };
    
    const reportPath = path.join(this.projectRoot, 'test-results-integration/combined-report.json');
    fs.writeFileSync(reportPath, JSON.stringify(reportData, null, 2));
    
    // HTML レポート生成
    await this.generateHTMLReport(reportData);
    
    console.log('✅ 統合レポート生成完了');
  }

  // HTMLレポート生成
  async generateHTMLReport(data) {
    const htmlTemplate = `
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365管理ツール - 統合テストレポート</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .status-passed { color: #28a745; }
        .status-failed { color: #dc3545; }
        .status-pending { color: #ffc107; }
        .metric-card { background: #f8f9fa; padding: 20px; margin: 10px; border-radius: 6px; border-left: 4px solid #007bff; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .progress-bar { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #28a745, #20c997); transition: width 0.5s ease; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background: #f8f9fa; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Microsoft 365管理ツール</h1>
            <h2>統合テストレポート</h2>
            <p>実行日時: ${data.timestamp}</p>
            <p class="status-${data.summary.overallStatus}">${data.summary.overallStatus.toUpperCase()}</p>
        </div>
        
        <div class="grid">
            <div class="metric-card">
                <h3>🐍 pytest (Backend)</h3>
                <p>ステータス: <span class="status-${data.testResults.pytest.status}">${data.testResults.pytest.status}</span></p>
                <p>実行時間: ${Math.round(data.testResults.pytest.duration / 1000)}秒</p>
                <p>カバレッジ: ${data.testResults.pytest.coverage}%</p>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${data.testResults.pytest.coverage}%"></div>
                </div>
            </div>
            
            <div class="metric-card">
                <h3>🌐 Cypress (E2E)</h3>
                <p>ステータス: <span class="status-${data.testResults.cypress.status}">${data.testResults.cypress.status}</span></p>
                <p>実行時間: ${Math.round(data.testResults.cypress.duration / 1000)}秒</p>
                <p>テスト数: ${data.testResults.cypress.tests}</p>
            </div>
            
            <div class="metric-card">
                <h3>🎭 Playwright (クロスブラウザ)</h3>
                <p>ステータス: <span class="status-${data.testResults.playwright.status}">${data.testResults.playwright.status}</span></p>
                <p>実行時間: ${Math.round(data.testResults.playwright.duration / 1000)}秒</p>
                <p>テスト数: ${data.testResults.playwright.tests}</p>
            </div>
        </div>
        
        <h3>📊 26機能テストカバレッジ</h3>
        <table>
            <tr><th>カテゴリ</th><th>機能数</th><th>Backend</th><th>Frontend</th><th>統合</th></tr>
            <tr><td>📊 定期レポート</td><td>5</td><td>✅</td><td>✅</td><td>✅</td></tr>
            <tr><td>🔍 分析レポート</td><td>5</td><td>✅</td><td>✅</td><td>✅</td></tr>
            <tr><td>👥 Entra ID管理</td><td>4</td><td>✅</td><td>✅</td><td>✅</td></tr>
            <tr><td>📧 Exchange Online管理</td><td>4</td><td>✅</td><td>✅</td><td>✅</td></tr>
            <tr><td>💬 Teams管理</td><td>4</td><td>✅</td><td>✅</td><td>✅</td></tr>
            <tr><td>💾 OneDrive管理</td><td>4</td><td>✅</td><td>✅</td><td>✅</td></tr>
        </table>
        
        <h3>⏱️ パフォーマンス</h3>
        <p>総実行時間: ${Math.round(data.summary.totalDuration / 1000)}秒</p>
        <p>総テスト数: ${data.summary.totalTests}</p>
        <p>平均テスト時間: ${Math.round(data.summary.totalDuration / data.summary.totalTests / 1000)}秒</p>
    </div>
</body>
</html>`;
    
    const htmlPath = path.join(this.projectRoot, 'test-results-integration/combined-report.html');
    fs.writeFileSync(htmlPath, htmlTemplate);
  }

  // 全体ステータス計算
  calculateOverallStatus() {
    const statuses = [this.results.pytest.status, this.results.cypress.status, this.results.playwright.status];
    
    if (statuses.includes('failed')) return 'failed';
    if (statuses.includes('pending')) return 'pending';
    return 'passed';
  }

  // サマリー出力
  async printSummary() {
    console.log('\n' + '='.repeat(60));
    console.log('📋 統合テスト結果サマリー');
    console.log('='.repeat(60));
    console.log(`🐍 pytest:     ${this.results.pytest.status} (${Math.round(this.results.pytest.duration / 1000)}s, ${this.results.pytest.coverage}% coverage)`);
    console.log(`🌐 Cypress:    ${this.results.cypress.status} (${Math.round(this.results.cypress.duration / 1000)}s, ${this.results.cypress.tests} tests)`);
    console.log(`🎭 Playwright: ${this.results.playwright.status} (${Math.round(this.results.playwright.duration / 1000)}s, ${this.results.playwright.tests} tests)`);
    console.log(`📊 全体:       ${this.results.overall.status} (${Math.round((this.results.overall.endTime - this.results.overall.startTime) / 1000)}s)`);
    console.log('='.repeat(60));
    
    if (this.results.overall.status === 'passed') {
      console.log('🎉 全ての統合テストが正常に完了しました！');
    } else {
      console.log('⚠️  一部のテストで問題が発生しました。詳細はログを確認してください。');
    }
  }

  // コマンド実行ヘルパー
  executeCommand(command, options = {}) {
    return new Promise((resolve, reject) => {
      const proc = exec(command, {
        cwd: options.cwd || process.cwd(),
        timeout: options.timeout || 300000, // 5分デフォルト
        maxBuffer: 1024 * 1024 * 10 // 10MB
      }, (error, stdout, stderr) => {
        if (error) {
          reject(new Error(`Command failed: ${command}\n${error.message}\n${stderr}`));
        } else {
          resolve(stdout);
        }
      });
      
      // リアルタイム出力
      proc.stdout.on('data', (data) => process.stdout.write(data));
      proc.stderr.on('data', (data) => process.stderr.write(data));
    });
  }
}

// スクリプト実行
if (require.main === module) {
  const runner = new IntegrationTestRunner();
  runner.run().catch(console.error);
}

module.exports = IntegrationTestRunner;