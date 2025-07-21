// Microsoft 365 Management Tools - 統合テスト設定
// Frontend (Cypress/Playwright) ↔ Backend (pytest) 連携設定

module.exports = {
  // テスト環境設定
  testEnvironments: {
    frontend: {
      url: 'http://localhost:3000',
      framework: 'react',
      testRunner: ['cypress', 'playwright'],
    },
    backend: {
      url: 'http://localhost:8000',
      framework: 'fastapi',
      testRunner: 'pytest',
    },
    pytest: {
      command: 'python -m pytest',
      workingDir: '/mnt/e/MicrosoftProductManagementTools',
      environment: 'pytest_env',
    }
  },

  // 26機能統合テスト設定
  testSuites: {
    // 📊 定期レポート (5機能)
    regularReports: {
      features: ['DailyReport', 'WeeklyReport', 'MonthlyReport', 'YearlyReport', 'TestExecution'],
      backend: 'Tests/integration/test_regular_reports.py',
      frontend: 'cypress/e2e/26-features-e2e.cy.ts',
      dataFiles: 'Tests/fixtures/test_data/regular_reports/'
    },

    // 🔍 分析レポート (5機能)
    analyticsReports: {
      features: ['LicenseAnalysis', 'UsageAnalysis', 'PerformanceAnalysis', 'SecurityAnalysis', 'PermissionAudit'],
      backend: 'Tests/integration/test_analytics_reports.py',
      frontend: 'cypress/e2e/26-features-e2e.cy.ts',
      dataFiles: 'Tests/fixtures/test_data/analytics_reports/'
    },

    // 👥 Entra ID管理 (4機能)
    entraIdManagement: {
      features: ['EntraUserList', 'EntraMFAStatus', 'EntraConditionalAccess', 'EntraSignInLogs'],
      backend: 'Tests/api/test_graph_api_integration.py',
      frontend: 'cypress/e2e/26-features-e2e.cy.ts',
      apiEndpoints: ['/api/graph/users', '/api/graph/mfa', '/api/graph/ca', '/api/graph/signin']
    },

    // 📧 Exchange Online管理 (4機能)
    exchangeManagement: {
      features: ['ExchangeMailboxes', 'ExchangeMailFlow', 'ExchangeSpamProtection', 'ExchangeDeliveryAnalysis'],
      backend: 'Tests/integration/test_exchange_integration.py',
      frontend: 'cypress/e2e/26-features-e2e.cy.ts',
      powershellBridge: 'Tests/compatibility/test_powershell_bridge.py'
    },

    // 💬 Teams管理 (4機能)
    teamsManagement: {
      features: ['TeamsUsage', 'TeamsSettings', 'TeamsMeetingQuality', 'TeamsAppAnalysis'],
      backend: 'Tests/integration/test_teams_integration.py',
      frontend: 'cypress/e2e/26-features-e2e.cy.ts',
      apiEndpoints: ['/api/teams/usage', '/api/teams/settings', '/api/teams/meetings', '/api/teams/apps']
    },

    // 💾 OneDrive管理 (4機能)
    oneDriveManagement: {
      features: ['OneDriveStorage', 'OneDriveSharing', 'OneDriveSyncErrors', 'OneDriveExternalSharing'],
      backend: 'Tests/integration/test_onedrive_integration.py',
      frontend: 'cypress/e2e/26-features-e2e.cy.ts',
      apiEndpoints: ['/api/onedrive/storage', '/api/onedrive/sharing', '/api/onedrive/sync', '/api/onedrive/external']
    }
  },

  // テストデータ共有設定
  sharedTestData: {
    mockUsers: 'Tests/fixtures/test_data/mock_users.json',
    mockLicenses: 'Tests/fixtures/test_data/mock_licenses.json',
    mockTeamsData: 'Tests/fixtures/test_data/mock_teams.json',
    mockExchangeData: 'Tests/fixtures/test_data/mock_exchange.json',
    authTokens: 'Tests/fixtures/test_data/auth_tokens.json'
  },

  // レポート統合設定
  reporting: {
    outputDir: './test-results-integration',
    formats: ['html', 'json', 'junit'],
    coverage: {
      frontend: './coverage/frontend',
      backend: './coverage/backend',
      combined: './coverage/combined'
    },
    screenshots: './test-results-integration/screenshots',
    videos: './test-results-integration/videos'
  },

  // 並列実行設定
  parallel: {
    frontendWorkers: 4,  // Cypress/Playwright並列数
    backendWorkers: 6,   // pytest並列数
    maxConcurrency: 10   // 全体最大並列数
  },

  // タイムアウト設定
  timeouts: {
    apiResponse: 30000,     // 30秒
    featureExecution: 120000, // 2分
    reportGeneration: 180000, // 3分
    fullTestSuite: 1800000   // 30分
  },

  // 統合テスト実行順序
  executionOrder: [
    'auth-setup',           // 認証設定
    'backend-health-check', // バックエンドヘルスチェック
    'frontend-startup',     // フロントエンド起動確認
    'api-connectivity',     // API接続確認
    'unit-tests',          // ユニットテスト
    'integration-tests',   // 統合テスト
    'e2e-tests',          // E2Eテスト
    'performance-tests',   // パフォーマンステスト
    'accessibility-tests', // アクセシビリティテスト
    'security-tests',      // セキュリティテスト
    'cleanup'             // テスト環境クリーンアップ
  ],

  // 失敗時設定
  onFailure: {
    captureScreenshot: true,
    captureVideo: true,
    saveLogs: true,
    retryCount: 2,
    continueOnError: false
  },

  // CI/CD統合
  cicd: {
    githubActions: {
      artifactUpload: true,
      summaryReport: true,
      slackNotification: false
    },
    reportPaths: {
      pytest: './test-results-integration/pytest-report.html',
      cypress: './test-results-integration/cypress-report.html',
      playwright: './test-results-integration/playwright-report.html',
      combined: './test-results-integration/combined-report.html'
    }
  }
};