// Microsoft 365 Management Tools - Playwright アクセシビリティテスト

import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Microsoft 365 Management Tools - アクセシビリティテスト', () => {
  test.beforeEach(async ({ page }) => {
    // テスト用認証設定
    await page.addInitScript(() => {
      localStorage.setItem('auth_token', 'mock-jwt-token');
      localStorage.setItem('user_info', JSON.stringify({
        id: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
      }));
    });
    
    await page.goto('/');
  });

  test('WCAG 2.1 AA準拠チェック - メインダッシュボード', async ({ page }) => {
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('キーボードナビゲーション - 26機能すべてアクセス可能', async ({ page }) => {
    // Tabキーで26機能すべてにアクセス可能か確認
    let focusableElements = 0;
    
    // 最初の要素にフォーカス
    await page.keyboard.press('Tab');
    
    // 26機能ボタンまでTabで移動
    for (let i = 0; i < 50; i++) {
      const focused = await page.locator(':focus').getAttribute('data-cy');
      if (focused && focused.startsWith('feature-')) {
        focusableElements++;
        
        // Enterキーで機能実行可能か確認
        await page.keyboard.press('Enter');
        
        // モーダルが表示されることを確認
        await expect(page.locator('[data-cy=progress-modal]')).toBeVisible();
        
        // Escapeキーでモーダルを閉じる
        await page.keyboard.press('Escape');
        await expect(page.locator('[data-cy=progress-modal]')).toBeHidden();
      }
      
      await page.keyboard.press('Tab');
    }
    
    // 26機能すべてがキーボードでアクセス可能
    expect(focusableElements).toBeGreaterThanOrEqual(26);
  });

  test('スクリーンリーダー対応 - ARIA属性適切設定', async ({ page }) => {
    // メインランドマークの確認
    await expect(page.locator('main[role="main"]')).toBeVisible();
    
    // 26機能ボタンのARIA属性確認
    const featureButtons = page.locator('[data-cy^="feature-"]');
    const buttonCount = await featureButtons.count();
    
    for (let i = 0; i < buttonCount; i++) {
      const button = featureButtons.nth(i);
      
      // ボタンロールの確認
      await expect(button).toHaveAttribute('role', 'button');
      
      // アクセシブルな名前の確認
      const ariaLabel = await button.getAttribute('aria-label');
      const textContent = await button.textContent();
      
      expect(ariaLabel || textContent).toBeTruthy();
    }
  });

  test('色覚バリアフリー - コントラスト比4.5:1以上', async ({ page }) => {
    // 高コントラストモードでの表示確認
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.reload();
    
    // ダークモードでのアクセシビリティ確認
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('フォーカス表示 - すべてのインタラクティブ要素', async ({ page }) => {
    const interactiveElements = [
      '[data-cy^="feature-"]',
      '[data-cy^="tab-"]', 
      'button',
      'input',
      'select',
      'textarea',
      'a',
    ];

    for (const selector of interactiveElements) {
      const elements = page.locator(selector);
      const count = await elements.count();
      
      for (let i = 0; i < count; i++) {
        const element = elements.nth(i);
        
        // 要素が表示されている場合のみテスト
        if (await element.isVisible()) {
          await element.focus();
          
          // フォーカスリングの確認
          const focusStyles = await element.evaluate((el) => {
            const styles = window.getComputedStyle(el, ':focus');
            return {
              outline: styles.outline,
              outlineWidth: styles.outlineWidth,
              outlineColor: styles.outlineColor,
            };
          });
          
          // フォーカス表示があることを確認
          expect(
            focusStyles.outline !== 'none' || 
            focusStyles.outlineWidth !== '0px'
          ).toBeTruthy();
        }
      }
    }
  });

  test('動的コンテンツ - ライブリージョン適切設定', async ({ page }) => {
    // 機能実行時のライブリージョン確認
    await page.locator('[data-cy="feature-DailyReport"]').click();
    
    // 進捗メッセージがスクリーンリーダーに通知される
    const progressMessage = page.locator('[data-cy="progress-message"]');
    await expect(progressMessage).toHaveAttribute('aria-live', 'polite');
    
    // 完了通知がスクリーンリーダーに通知される
    const completionMessage = page.locator('[data-cy="completion-toast"]');
    if (await completionMessage.isVisible()) {
      await expect(completionMessage).toHaveAttribute('aria-live', 'assertive');
    }
  });

  test('フォームアクセシビリティ', async ({ page }) => {
    // 設定フォームなどがある場合の確認
    const forms = page.locator('form');
    const formCount = await forms.count();
    
    for (let i = 0; i < formCount; i++) {
      const form = forms.nth(i);
      
      // フォーム内の入力要素確認
      const inputs = form.locator('input, select, textarea');
      const inputCount = await inputs.count();
      
      for (let j = 0; j < inputCount; j++) {
        const input = inputs.nth(j);
        
        // ラベル関連付けの確認
        const ariaLabelledBy = await input.getAttribute('aria-labelledby');
        const ariaLabel = await input.getAttribute('aria-label');
        const id = await input.getAttribute('id');
        
        let hasLabel = false;
        if (id) {
          const label = form.locator(`label[for="${id}"]`);
          hasLabel = await label.count() > 0;
        }
        
        expect(ariaLabelledBy || ariaLabel || hasLabel).toBeTruthy();
      }
    }
  });

  test('エラーメッセージアクセシビリティ', async ({ page }) => {
    // エラー状態のテスト（認証失敗など）
    await page.addInitScript(() => {
      localStorage.removeItem('auth_token');
    });
    
    await page.reload();
    
    // エラーメッセージの確認
    const errorMessages = page.locator('[role="alert"], .error-message, [aria-live="assertive"]');
    const errorCount = await errorMessages.count();
    
    if (errorCount > 0) {
      for (let i = 0; i < errorCount; i++) {
        const error = errorMessages.nth(i);
        
        // エラーメッセージがスクリーンリーダーに通知される
        const role = await error.getAttribute('role');
        const ariaLive = await error.getAttribute('aria-live');
        
        expect(role === 'alert' || ariaLive === 'assertive').toBeTruthy();
      }
    }
  });
});