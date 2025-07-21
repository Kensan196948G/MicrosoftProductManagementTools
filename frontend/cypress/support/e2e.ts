// Cypress E2E Support File for Microsoft 365 Management Tools
import './commands';
import 'cypress-axe';

// グローバル設定
beforeEach(() => {
  // アクセシビリティテストのセットアップ
  cy.injectAxe();
  
  // Microsoft 365認証モック（テスト環境用）
  cy.intercept('POST', '**/auth/login', {
    statusCode: 200,
    body: {
      access_token: 'mock-token',
      token_type: 'Bearer',
      expires_in: 3600,
      user: {
        id: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
      },
    },
  }).as('mockLogin');
  
  // Microsoft Graph API モック
  cy.intercept('GET', '**/graph/users**', {
    statusCode: 200,
    body: {
      value: [
        {
          id: 'user1',
          displayName: 'Test User 1',
          userPrincipalName: 'user1@example.com',
          mail: 'user1@example.com',
        },
        {
          id: 'user2', 
          displayName: 'Test User 2',
          userPrincipalName: 'user2@example.com',
          mail: 'user2@example.com',
        },
      ],
    },
  }).as('mockUsers');
});

// 26機能テスト用のカスタムエラーハンドリング
Cypress.on('uncaught:exception', (err, runnable) => {
  // Microsoft Graph API関連のエラーは無視（テスト環境）
  if (err.message.includes('graph.microsoft.com')) {
    return false;
  }
  
  // PowerShellブリッジ関連のエラーは無視（テスト環境）
  if (err.message.includes('PowerShell')) {
    return false;
  }
  
  return true;
});

// カスタムコマンドの型定義
declare global {
  namespace Cypress {
    interface Chainable {
      /**
       * Microsoft 365 テストユーザーでログイン
       */
      loginAsTestUser(): Chainable<Element>;
      
      /**
       * 26機能のうち指定した機能をテスト実行
       */
      executeFeature(featureAction: string): Chainable<Element>;
      
      /**
       * アクセシビリティチェック実行
       */
      checkAccessibility(): Chainable<Element>;
      
      /**
       * レスポンシブテスト実行
       */
      testResponsive(): Chainable<Element>;
    }
  }
}