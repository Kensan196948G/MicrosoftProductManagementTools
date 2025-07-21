// Microsoft 365 Management Tools - Lighthouse パフォーマンステスト
// 90点以上を目標とした総合品質検証

describe('Lighthouse Performance Tests', () => {
  beforeEach(() => {
    cy.visit('/');
    
    // アプリケーション完全読み込み待機
    cy.get('[data-testid="main-dashboard"]').should('be.visible');
    cy.wait(2000); // 安定化待機
  });

  it('メインページのLighthouse性能テスト（90点以上目標）', () => {
    // Lighthouse設定
    const lighthouseConfig = {
      performance: 90,
      accessibility: 95,
      'best-practices': 90,
      seo: 85,
      pwa: 80
    };

    // Lighthouse実行
    cy.lighthouse(lighthouseConfig);
    
    // Core Web Vitals確認
    cy.window().then((win) => {
      // LCP (Largest Contentful Paint) < 2.5s
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.entryType === 'largest-contentful-paint') {
            expect(entry.startTime).to.be.lessThan(2500);
          }
        }
      }).observe({ entryTypes: ['largest-contentful-paint'] });

      // FID (First Input Delay) < 100ms
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.entryType === 'first-input') {
            expect((entry as any).processingStart - entry.startTime).to.be.lessThan(100);
          }
        }
      }).observe({ entryTypes: ['first-input'] });

      // CLS (Cumulative Layout Shift) < 0.1
      new PerformanceObserver((list) => {
        let clsValue = 0;
        for (const entry of list.getEntries()) {
          if (!(entry as any).hadRecentInput) {
            clsValue += (entry as any).value;
          }
        }
        expect(clsValue).to.be.lessThan(0.1);
      }).observe({ entryTypes: ['layout-shift'] });
    });
  });

  it('各タブページのパフォーマンス確認', () => {
    const tabs = [
      { id: 'regular-reports', name: '📊 定期レポート' },
      { id: 'analytics-reports', name: '🔍 分析レポート' },
      { id: 'entra-id', name: '👥 Entra ID管理' },
      { id: 'exchange-online', name: '📧 Exchange Online' },
      { id: 'teams-management', name: '💬 Teams管理' },
      { id: 'onedrive-management', name: '💾 OneDrive管理' }
    ];

    tabs.forEach((tab) => {
      cy.log(`Testing performance for ${tab.name}`);
      
      // タブ切り替え
      cy.contains('[role="tab"]', tab.name).click();
      
      // タブ切り替え時間測定
      const startTime = Date.now();
      cy.get('[role="tabpanel"]').should('be.visible').then(() => {
        const switchTime = Date.now() - startTime;
        expect(switchTime).to.be.lessThan(300); // 300ms以内
      });

      // バンドルサイズ確認
      cy.window().then((win) => {
        const navigationEntries = win.performance.getEntriesByType('navigation');
        if (navigationEntries.length > 0) {
          const entry = navigationEntries[0] as PerformanceNavigationTiming;
          const transferSize = entry.transferSize || 0;
          expect(transferSize).to.be.lessThan(1024 * 1024); // 1MB以下
        }
      });
    });
  });

  it('機能実行時のパフォーマンス確認', () => {
    cy.contains('[role="tab"]', '📊 定期レポート').click();
    
    // 機能実行時間測定
    const featureButton = '[data-testid*="feature-button"]';
    
    cy.get(featureButton).first().then(($button) => {
      const featureName = $button.text();
      const startTime = Date.now();
      
      cy.wrap($button).click();
      
      // 実行開始の確認
      cy.get($button).should('have.attr', 'aria-busy', 'true');
      
      // 実行完了待機（最大30秒）
      cy.get($button, { timeout: 30000 }).should('not.have.attr', 'aria-busy', 'true');
      
      cy.then(() => {
        const executionTime = Date.now() - startTime;
        cy.log(`${featureName} execution time: ${executionTime}ms`);
        expect(executionTime).to.be.lessThan(30000); // 30秒以内
      });
    });
  });

  it('メモリ使用量テスト', () => {
    // 初期メモリ使用量記録
    let initialMemory: number;
    
    cy.window().then((win) => {
      const memory = (win.performance as any).memory;
      if (memory) {
        initialMemory = memory.usedJSHeapSize;
      }
    });

    // 全タブを順次操作
    const tabs = ['📊 定期レポート', '🔍 分析レポート', '👥 Entra ID管理', '📧 Exchange Online', '💬 Teams管理', '💾 OneDrive管理'];
    
    tabs.forEach((tabName) => {
      cy.contains('[role="tab"]', tabName).click();
      cy.wait(500);
      
      // 各タブで機能実行
      cy.get('[data-testid*="feature-button"]').first().click();
      cy.wait(1000);
    });

    // 最終メモリ使用量確認
    cy.window().then((win) => {
      const memory = (win.performance as any).memory;
      if (memory && initialMemory) {
        const memoryIncrease = memory.usedJSHeapSize - initialMemory;
        const memoryIncreaseMB = memoryIncrease / (1024 * 1024);
        
        cy.log(`Memory increase: ${memoryIncreaseMB.toFixed(2)}MB`);
        expect(memoryIncreaseMB).to.be.lessThan(20); // 20MB以下の増加
      }
    });
  });

  it('ネットワークリクエスト最適化確認', () => {
    let requestCount = 0;
    let totalTransferSize = 0;

    // ネットワーク監視開始
    cy.intercept('**/*', (req) => {
      requestCount++;
      req.continue((res) => {
        if (res.headers['content-length']) {
          totalTransferSize += parseInt(res.headers['content-length'] as string);
        }
      });
    }).as('allRequests');

    // アプリケーション操作
    cy.reload();
    cy.get('[data-testid="main-dashboard"]').should('be.visible');

    // 全タブ巡回
    const tabs = ['📊 定期レポート', '🔍 分析レポート', '👥 Entra ID管理'];
    tabs.forEach((tabName) => {
      cy.contains('[role="tab"]', tabName).click();
      cy.wait(1000);
    });

    cy.then(() => {
      cy.log(`Total requests: ${requestCount}`);
      cy.log(`Total transfer size: ${(totalTransferSize / 1024).toFixed(2)}KB`);
      
      // リクエスト数制限
      expect(requestCount).to.be.lessThan(50); // 50リクエスト以下
      
      // 転送サイズ制限
      expect(totalTransferSize).to.be.lessThan(2 * 1024 * 1024); // 2MB以下
    });
  });

  it('画像最適化確認', () => {
    cy.get('img').each(($img) => {
      // 遅延読み込み確認
      cy.wrap($img).should('have.attr', 'loading', 'lazy')
        .or('have.attr', 'loading', 'eager'); // eager も許可
      
      // アスペクト比設定確認
      cy.wrap($img).should('have.css', 'aspect-ratio')
        .or('have.attr', 'width')
        .or('have.attr', 'height');
    });
  });

  it('CSS・JavaScript最適化確認', () => {
    cy.window().then((win) => {
      const doc = win.document;
      
      // CSS最適化確認
      const styleSheets = Array.from(doc.styleSheets);
      const inlineStyles = doc.querySelectorAll('style');
      
      cy.log(`External stylesheets: ${styleSheets.length}`);
      cy.log(`Inline styles: ${inlineStyles.length}`);
      
      // インラインスタイル数制限
      expect(inlineStyles.length).to.be.lessThan(10);
      
      // JavaScript最適化確認
      const scripts = doc.querySelectorAll('script');
      const inlineScripts = Array.from(scripts).filter(script => !script.src);
      
      cy.log(`Total scripts: ${scripts.length}`);
      cy.log(`Inline scripts: ${inlineScripts.length}`);
      
      // インラインスクリプト数制限
      expect(inlineScripts.length).to.be.lessThan(5);
    });
  });

  it('フォント読み込み最適化確認', () => {
    cy.window().then((win) => {
      const doc = win.document;
      
      // フォント preload 確認
      const fontPreloads = doc.querySelectorAll('link[rel="preload"][as="font"]');
      cy.log(`Font preloads: ${fontPreloads.length}`);
      
      // Web フォント確認
      const fontFaces = Array.from(doc.fonts);
      cy.log(`Web fonts: ${fontFaces.length}`);
      
      // フォント読み込み完了確認
      return doc.fonts.ready.then(() => {
        cy.log('All fonts loaded');
        expect(fontFaces.every(font => font.status === 'loaded')).to.be.true;
      });
    });
  });

  it('Service Worker確認', () => {
    cy.window().then((win) => {
      if ('serviceWorker' in win.navigator) {
        return win.navigator.serviceWorker.getRegistrations().then((registrations) => {
          cy.log(`Service Workers: ${registrations.length}`);
          
          registrations.forEach((registration) => {
            expect(registration.active).to.not.be.null;
            cy.log(`SW scope: ${registration.scope}`);
          });
        });
      } else {
        cy.log('Service Worker not supported');
      }
    });
  });

  it('キャッシュ戦略確認', () => {
    // キャッシュヘッダー確認
    cy.intercept('GET', '**/*.{js,css,png,jpg,jpeg,gif,svg,woff,woff2}', (req) => {
      req.continue((res) => {
        // 静的リソースのキャッシュヘッダー確認
        expect(res.headers).to.have.property('cache-control');
        
        const cacheControl = res.headers['cache-control'] as string;
        if (cacheControl) {
          // 長期キャッシュまたは適切なキャッシュ設定
          expect(cacheControl).to.match(/(max-age=\d+|public|immutable)/);
        }
      });
    });

    // ページリロード
    cy.reload();
    cy.get('[data-testid="main-dashboard"]').should('be.visible');
  });

  it('Bundle Analyzer確認', () => {
    // バンドルサイズ分析
    cy.task('checkBundleSize').then((result: any) => {
      cy.log(`Main bundle size: ${result.mainSize}KB`);
      cy.log(`Vendor bundle size: ${result.vendorSize}KB`);
      cy.log(`Total bundle size: ${result.totalSize}KB`);
      
      // バンドルサイズ制限
      expect(result.mainSize).to.be.lessThan(500); // 500KB以下
      expect(result.vendorSize).to.be.lessThan(800); // 800KB以下
      expect(result.totalSize).to.be.lessThan(1200); // 1.2MB以下
    });
  });

  it('Tree Shaking確認', () => {
    // 未使用コードの確認
    cy.window().then((win) => {
      const scripts = Array.from(win.document.querySelectorAll('script[src]'));
      
      scripts.forEach((script) => {
        const src = script.getAttribute('src');
        if (src && src.includes('chunk')) {
          cy.log(`Chunk: ${src}`);
          
          // チャンクサイズ確認
          cy.request(src).then((response) => {
            const sizeKB = response.body.length / 1024;
            cy.log(`${src}: ${sizeKB.toFixed(2)}KB`);
            expect(sizeKB).to.be.lessThan(300); // 各チャンク300KB以下
          });
        }
      });
    });
  });
});

// パフォーマンステスト用のカスタムコマンド
declare global {
  namespace Cypress {
    interface Chainable {
      checkBundleSize(): Chainable<any>;
    }
  }
}

// Cypress タスク設定
export {};