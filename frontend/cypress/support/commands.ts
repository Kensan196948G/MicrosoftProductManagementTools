// Microsoft 365 Management Tools - Cypress Custom Commands

/**
 * Microsoft 365 テストユーザーでログイン
 */
Cypress.Commands.add('loginAsTestUser', () => {
  cy.visit('/');
  
  // 認証フローをモック
  cy.window().then((window) => {
    window.localStorage.setItem('auth_token', 'mock-jwt-token');
    window.localStorage.setItem('user_info', JSON.stringify({
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
    }));
  });
  
  cy.reload();
  cy.get('[data-cy=dashboard]').should('be.visible');
});

/**
 * 26機能のうち指定した機能をテスト実行
 */
Cypress.Commands.add('executeFeature', (featureAction: string) => {
  // 機能ボタンを探してクリック
  cy.get(`[data-cy=feature-${featureAction}]`).should('be.visible').click();
  
  // 進捗モーダルの表示確認
  cy.get('[data-cy=progress-modal]').should('be.visible');
  cy.get('[data-cy=progress-message]').should('contain', 'Microsoft 365 に接続中');
  
  // 実行完了まで待機（最大30秒）
  cy.get('[data-cy=progress-complete]', { timeout: 30000 }).should('be.visible');
  
  // 結果表示の確認
  cy.get('[data-cy=execution-result]').should('be.visible');
});

/**
 * アクセシビリティチェック実行
 */
Cypress.Commands.add('checkAccessibility', () => {
  // WCAG 2.1 AA レベルのチェック
  cy.checkA11y(null, {
    runOnly: {
      type: 'tag',
      values: ['wcag2a', 'wcag2aa', 'wcag21aa'],
    },
  });
  
  // キーボードナビゲーションテスト
  cy.get('body').tab();
  cy.focused().should('be.visible');
  
  // Enterキーでアクション実行可能性確認
  cy.focused().then(($el) => {
    if ($el.is('button') || $el.is('[role="button"]')) {
      cy.focused().type('{enter}');
    }
  });
});

/**
 * レスポンシブテスト実行
 */
Cypress.Commands.add('testResponsive', () => {
  const viewports = [
    { width: 320, height: 568, device: 'iPhone SE' },
    { width: 375, height: 667, device: 'iPhone 8' },
    { width: 768, height: 1024, device: 'iPad' },
    { width: 1366, height: 768, device: 'Laptop' },
    { width: 1920, height: 1080, device: 'Desktop' },
  ];

  viewports.forEach((viewport) => {
    cy.viewport(viewport.width, viewport.height);
    cy.log(`Testing responsive design on ${viewport.device} (${viewport.width}x${viewport.height})`);
    
    // メインコンテンツの表示確認
    cy.get('[data-cy=dashboard]').should('be.visible');
    cy.get('[data-cy=feature-grid]').should('be.visible');
    
    // 26機能ボタンの表示確認
    cy.get('[data-cy^=feature-]').should('have.length.greaterThan', 20);
    
    // ナビゲーションの確認
    if (viewport.width < 768) {
      // モバイル: ハンバーガーメニュー
      cy.get('[data-cy=mobile-menu-button]').should('be.visible');
    } else {
      // デスクトップ: 通常のナビゲーション
      cy.get('[data-cy=desktop-nav]').should('be.visible');
    }
  });
});