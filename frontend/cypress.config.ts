import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    supportFile: 'cypress/support/e2e.ts',
    specPattern: 'cypress/e2e/**/*.cy.{js,jsx,ts,tsx}',
    viewportWidth: 1920,
    viewportHeight: 1080,
    video: true,
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000,
    env: {
      // Microsoft 365 Test Environment
      TEST_USER_EMAIL: 'test@example.com',
      TEST_USER_PASSWORD: 'TestPassword123!',
      API_BASE_URL: 'http://localhost:8000',
    },
    setupNodeEvents(on, config) {
      // アクセシビリティテスト統合
      on('task', {
        log(message) {
          console.log(message);
          return null;
        },
      });
      
      // スクリーンショット比較
      on('task', {
        generateReport(options) {
          // E2Eテストレポート生成
          return null;
        },
      });
    },
  },
  
  component: {
    devServer: {
      framework: 'react',
      bundler: 'vite',
    },
    supportFile: 'cypress/support/component.ts',
    specPattern: 'src/**/*.cy.{js,jsx,ts,tsx}',
  },
  
  // 26機能対応の拡張設定
  retries: {
    runMode: 2,
    openMode: 0,
  },
  
  watchForFileChanges: true,
});