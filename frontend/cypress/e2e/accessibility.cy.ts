// Microsoft 365 Management Tools - Cypress E2E Accessibility Tests
// WCAG 2.1 AA準拠のE2Eアクセシビリティテスト

describe('Accessibility E2E Tests', () => {
  beforeEach(() => {
    // アクセシビリティテストの初期化
    cy.visit('/');
    cy.injectAxe();
  });

  describe('Full Page Accessibility', () => {
    it('should pass axe accessibility tests on load', () => {
      cy.checkA11y();
    });

    it('should pass axe accessibility tests on all tab changes', () => {
      const tabs = [
        'regular-reports',
        'analytics-reports',
        'entra-id',
        'exchange-online',
        'teams-management',
        'onedrive-management'
      ];

      tabs.forEach(tabId => {
        cy.get(`[data-cy=tab-${tabId}]`).click();
        cy.checkA11y();
      });
    });

    it('should maintain focus order', () => {
      // Tab順序の確認
      cy.get('body').tab();
      cy.focused().should('have.attr', 'data-cy', 'skip-link-main');
      
      cy.focused().tab();
      cy.focused().should('have.attr', 'data-cy', 'skip-link-nav');
      
      cy.focused().tab();
      cy.focused().should('contain', '📊 定期レポート');
    });
  });

  describe('Keyboard Navigation', () => {
    it('should support tab navigation through all interactive elements', () => {
      let tabCount = 0;
      
      // すべてのインタラクティブ要素をタブで巡回
      cy.get('body').then(() => {
        cy.get('body').tab();
        cy.focused().then(($el) => {
          if ($el.length > 0) {
            tabCount++;
            // 最大50回タブして無限ループを防ぐ
            if (tabCount < 50) {
              cy.get('body').tab();
            }
          }
        });
      });

      // 少なくとも10個のインタラクティブ要素があることを確認
      expect(tabCount).to.be.greaterThan(10);
    });

    it('should support arrow key navigation in tabs', () => {
      // 最初のタブにフォーカス
      cy.get('[role="tab"]').first().focus();
      
      // 右矢印キーで次のタブに移動
      cy.focused().type('{rightArrow}');
      cy.focused().should('contain', '🔍 分析レポート');
      
      // 左矢印キーで前のタブに戻る
      cy.focused().type('{leftArrow}');
      cy.focused().should('contain', '📊 定期レポート');
    });

    it('should support Enter and Space key activation', () => {
      // 機能ボタンをキーボードで実行
      cy.get('[data-cy=feature-button]').first().focus();
      
      // Enter キーで実行
      cy.focused().type('{enter}');
      cy.get('[data-cy=progress-modal]').should('be.visible');
      
      // モーダルを閉じる
      cy.get('[data-cy=close-modal]').click();
      
      // Space キーで実行
      cy.get('[data-cy=feature-button]').first().focus();
      cy.focused().type(' ');
      cy.get('[data-cy=progress-modal]').should('be.visible');
    });

    it('should trap focus in modal dialogs', () => {
      // モーダルを開く
      cy.get('[data-cy=feature-button]').first().click();
      cy.get('[data-cy=progress-modal]').should('be.visible');
      
      // モーダル内でフォーカストラップを確認
      cy.get('[data-cy=progress-modal]').within(() => {
        cy.get('[data-cy=modal-close]').focus();
        cy.focused().tab();
        
        // 最後の要素から最初の要素にループ
        cy.get('[data-cy=modal-close]').should('be.focused');
      });
    });

    it('should restore focus after modal closes', () => {
      // 機能ボタンにフォーカス
      cy.get('[data-cy=feature-button]').first().focus();
      const buttonText = cy.focused().text();
      
      // モーダルを開く
      cy.focused().click();
      cy.get('[data-cy=progress-modal]').should('be.visible');
      
      // モーダルを閉じる
      cy.get('[data-cy=close-modal]').click();
      
      // 元のボタンにフォーカスが戻る
      cy.focused().should('contain', buttonText);
    });
  });

  describe('Screen Reader Support', () => {
    it('should have proper ARIA labels and descriptions', () => {
      // すべてのボタンにaria-labelがある
      cy.get('[role="button"]').each(($button) => {
        cy.wrap($button).should('have.attr', 'aria-label');
      });
      
      // すべてのタブにaria-controlsがある
      cy.get('[role="tab"]').each(($tab) => {
        cy.wrap($tab).should('have.attr', 'aria-controls');
      });
    });

    it('should announce status changes', () => {
      // 機能実行時の状態変化をテスト
      cy.get('[data-cy=feature-button]').first().click();
      
      // aria-live領域で状態変化が告知される
      cy.get('[aria-live]').should('contain', '実行中');
    });

    it('should have proper heading hierarchy', () => {
      // h1が1つだけ存在
      cy.get('h1').should('have.length', 1);
      cy.get('h1').should('contain', 'Microsoft 365統合管理ツール');
      
      // h2以下が適切な階層
      cy.get('h2').should('exist');
      cy.get('h3').should('exist');
    });

    it('should have landmark roles', () => {
      // 主要なランドマークが存在
      cy.get('[role="banner"]').should('exist'); // ヘッダー
      cy.get('[role="navigation"]').should('exist'); // ナビゲーション
      cy.get('[role="main"]').should('exist'); // メインコンテンツ
      cy.get('[role="contentinfo"]').should('exist'); // フッター
    });
  });

  describe('Visual Accessibility', () => {
    it('should meet color contrast requirements', () => {
      // 色のコントラスト比をチェック
      cy.checkA11y(null, {
        rules: {
          'color-contrast': { enabled: true }
        }
      });
    });

    it('should be usable at 200% zoom', () => {
      // 200%ズームでの使用性テスト
      cy.get('body').invoke('css', 'zoom', '2');
      
      // 主要要素が見える
      cy.get('[data-cy=main-title]').should('be.visible');
      cy.get('[data-cy=tab-navigation]').should('be.visible');
      cy.get('[data-cy=feature-grid]').should('be.visible');
      
      // 要素が重なっていない
      cy.get('[data-cy=feature-button]').should('be.visible');
    });

    it('should work with high contrast mode', () => {
      // 高コントラストモードをシミュレート
      cy.get('html').invoke('addClass', 'high-contrast');
      
      // 要素が見える
      cy.get('[data-cy=feature-button]').should('be.visible');
      cy.get('[data-cy=tab-navigation]').should('be.visible');
      
      // アクセシビリティチェック
      cy.checkA11y();
    });
  });

  describe('Motion and Animation', () => {
    it('should respect reduced motion preference', () => {
      // モーション制御設定をシミュレート
      cy.get('html').invoke('addClass', 'reduce-motion');
      
      // アニメーションが無効化される
      cy.get('[data-cy=feature-button]').click();
      cy.get('[data-cy=progress-modal]').should('be.visible');
      
      // アニメーション時間が短縮される
      cy.get('[data-cy=progress-modal]').should('have.css', 'animation-duration', '0.01ms');
    });
  });

  describe('Form Accessibility', () => {
    it('should have proper form labels', () => {
      // フォーム要素のラベルテスト（実装されたら追加）
    });

    it('should show validation errors accessibly', () => {
      // バリデーションエラーのアクセシビリティテスト
    });
  });

  describe('Mobile Accessibility', () => {
    it('should be accessible on mobile devices', () => {
      cy.viewport('iphone-x');
      
      // モバイルビューでのアクセシビリティチェック
      cy.checkA11y();
      
      // タッチターゲットが適切なサイズ
      cy.get('[data-cy=feature-button]').should('have.css', 'min-height', '44px');
      cy.get('[data-cy=feature-button]').should('have.css', 'min-width', '44px');
    });

    it('should support touch navigation', () => {
      cy.viewport('iphone-x');
      
      // タッチでのナビゲーション
      cy.get('[data-cy=tab-analytics]').click();
      cy.get('[data-cy=analytics-content]').should('be.visible');
      
      // フィーチャーボタンのタッチ
      cy.get('[data-cy=feature-button]').first().click();
      cy.get('[data-cy=progress-modal]').should('be.visible');
    });
  });

  describe('Performance and Accessibility', () => {
    it('should load quickly and remain accessible', () => {
      // ページロード時間の測定
      cy.window().then((win) => {
        const loadTime = win.performance.timing.loadEventEnd - win.performance.timing.navigationStart;
        expect(loadTime).to.be.lessThan(3000); // 3秒以内
      });
      
      // ロード後のアクセシビリティチェック
      cy.checkA11y();
    });

    it('should maintain accessibility during interactions', () => {
      // インタラクション中のアクセシビリティ
      cy.get('[data-cy=feature-button]').first().click();
      
      // 進捗中でもアクセシビリティが維持される
      cy.checkA11y();
      
      // 完了後もアクセシビリティが維持される
      cy.wait(3000);
      cy.checkA11y();
    });
  });

  describe('Browser Compatibility', () => {
    it('should work with assistive technologies', () => {
      // 支援技術との互換性テスト
      // 実際のスクリーンリーダーテストは別途実施
    });
  });
});