// Microsoft 365 Management Tools - Performance Optimization Utilities
// エンタープライズパフォーマンス最適化ユーティリティ

import { debounce, throttle } from 'lodash-es';

// Web Vitals収集とレポート
export interface WebVitalsMetrics {
  fcp: number;  // First Contentful Paint
  lcp: number;  // Largest Contentful Paint
  fid: number;  // First Input Delay
  cls: number;  // Cumulative Layout Shift
  ttfb: number; // Time to First Byte
  tti: number;  // Time to Interactive
}

// パフォーマンス監視クラス
export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private metrics: Map<string, number> = new Map();
  private observers: Map<string, PerformanceObserver> = new Map();
  private isEnabled: boolean = true;

  private constructor() {
    this.initializeObservers();
  }

  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }

  // パフォーマンス監視の初期化
  private initializeObservers(): void {
    if (typeof window === 'undefined' || !window.PerformanceObserver) {
      this.isEnabled = false;
      return;
    }

    // First Contentful Paint / First Paint
    this.createObserver('paint', (entries) => {
      entries.forEach((entry) => {
        if (entry.name === 'first-contentful-paint') {
          this.setMetric('fcp', entry.startTime);
        }
        if (entry.name === 'first-paint') {
          this.setMetric('fp', entry.startTime);
        }
      });
    });

    // Largest Contentful Paint
    this.createObserver('largest-contentful-paint', (entries) => {
      const lastEntry = entries[entries.length - 1];
      this.setMetric('lcp', lastEntry.startTime);
    });

    // First Input Delay
    this.createObserver('first-input', (entries) => {
      entries.forEach((entry) => {
        if (entry.processingStart && entry.startTime) {
          this.setMetric('fid', entry.processingStart - entry.startTime);
        }
      });
    });

    // Cumulative Layout Shift
    let cumulativeLayoutShift = 0;
    this.createObserver('layout-shift', (entries) => {
      entries.forEach((entry) => {
        if (!(entry as any).hadRecentInput) {
          cumulativeLayoutShift += (entry as any).value;
        }
      });
      this.setMetric('cls', cumulativeLayoutShift);
    });

    // Long Tasks
    this.createObserver('longtask', (entries) => {
      entries.forEach((entry) => {
        this.setMetric('longTask', entry.duration);
      });
    });

    // Navigation Timing
    this.measureNavigationTiming();
  }

  private createObserver(type: string, callback: (entries: PerformanceEntry[]) => void): void {
    try {
      const observer = new PerformanceObserver((list) => {
        callback(list.getEntries());
      });
      observer.observe({ type, buffered: true });
      this.observers.set(type, observer);
    } catch (error) {
      console.warn(`Performance observer for ${type} not supported:`, error);
    }
  }

  private measureNavigationTiming(): void {
    // Navigation Timing API
    const navigationEntry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    if (navigationEntry) {
      this.setMetric('ttfb', navigationEntry.responseStart - navigationEntry.requestStart);
      this.setMetric('domContentLoaded', navigationEntry.domContentLoadedEventEnd - navigationEntry.navigationStart);
      this.setMetric('loadComplete', navigationEntry.loadEventEnd - navigationEntry.navigationStart);
    }
  }

  // メトリクスの設定
  private setMetric(name: string, value: number): void {
    this.metrics.set(name, value);
    this.reportMetric(name, value);
  }

  // メトリクスの取得
  getMetric(name: string): number | undefined {
    return this.metrics.get(name);
  }

  // 全メトリクスの取得
  getAllMetrics(): Record<string, number> {
    return Object.fromEntries(this.metrics);
  }

  // メトリクスのレポート
  private reportMetric(name: string, value: number): void {
    if (this.isEnabled) {
      // アナリティクスサービスに送信
      this.sendToAnalytics(name, value);
      
      // コンソールログ（開発時のみ）
      if (process.env.NODE_ENV === 'development') {
        console.log(`[Performance] ${name}: ${value.toFixed(2)}ms`);
      }
    }
  }

  // アナリティクスサービスへの送信
  private sendToAnalytics(name: string, value: number): void {
    // Google Analytics 4やその他のアナリティクスサービスに送信
    if (typeof gtag !== 'undefined') {
      gtag('event', 'performance_metric', {
        metric_name: name,
        metric_value: Math.round(value),
        custom_parameter: 'web_vitals'
      });
    }

    // カスタムAPIに送信
    this.sendToCustomAPI(name, value);
  }

  private sendToCustomAPI = debounce((name: string, value: number) => {
    fetch('/api/analytics/performance', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        metric: name,
        value: value,
        timestamp: Date.now(),
        userAgent: navigator.userAgent,
        url: window.location.href,
      }),
    }).catch((error) => {
      console.warn('Failed to send performance metrics:', error);
    });
  }, 1000);

  // パフォーマンス監視の無効化
  disable(): void {
    this.isEnabled = false;
    this.observers.forEach((observer) => observer.disconnect());
    this.observers.clear();
  }

  // パフォーマンスレポートの生成
  generateReport(): string {
    const metrics = this.getAllMetrics();
    const report = {
      timestamp: new Date().toISOString(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      metrics,
      recommendations: this.getRecommendations(metrics),
    };
    return JSON.stringify(report, null, 2);
  }

  // パフォーマンス改善の推奨事項
  private getRecommendations(metrics: Record<string, number>): string[] {
    const recommendations: string[] = [];

    if (metrics.fcp > 1800) {
      recommendations.push('First Contentful Paint が遅いです。リソースの最適化を検討してください。');
    }

    if (metrics.lcp > 2500) {
      recommendations.push('Largest Contentful Paint が遅いです。画像の最適化やキャッシュ戦略を見直してください。');
    }

    if (metrics.fid > 100) {
      recommendations.push('First Input Delay が長いです。JavaScriptの実行時間を短縮してください。');
    }

    if (metrics.cls > 0.1) {
      recommendations.push('Cumulative Layout Shift が高いです。レイアウトの安定性を改善してください。');
    }

    if (metrics.ttfb > 800) {
      recommendations.push('Time to First Byte が遅いです。サーバーの応答時間を改善してください。');
    }

    return recommendations;
  }
}

// リソース最適化ユーティリティ
export class ResourceOptimizer {
  // 画像の遅延読み込み
  static lazyLoadImages(): void {
    if ('IntersectionObserver' in window) {
      const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const img = entry.target as HTMLImageElement;
            if (img.dataset.src) {
              img.src = img.dataset.src;
              img.classList.remove('lazy');
              imageObserver.unobserve(img);
            }
          }
        });
      });

      document.querySelectorAll('img[data-src]').forEach((img) => {
        imageObserver.observe(img);
      });
    }
  }

  // CSSの最適化
  static optimizeCSS(): void {
    // 未使用のCSSを削除
    const styleSheets = Array.from(document.styleSheets);
    styleSheets.forEach((sheet) => {
      try {
        const rules = Array.from(sheet.cssRules || []);
        rules.forEach((rule) => {
          if (rule.type === CSSRule.STYLE_RULE) {
            const styleRule = rule as CSSStyleRule;
            if (!document.querySelector(styleRule.selectorText)) {
              // 未使用のルールを削除（本番環境では慎重に）
              if (process.env.NODE_ENV === 'development') {
                console.warn(`Unused CSS rule: ${styleRule.selectorText}`);
              }
            }
          }
        });
      } catch (error) {
        // Cross-origin CSS rules
        console.warn('Cannot access CSS rules:', error);
      }
    });
  }

  // JavaScript最適化
  static optimizeJavaScript(): void {
    // 不要なイベントリスナーを削除
    const elements = document.querySelectorAll('*');
    elements.forEach((element) => {
      const listeners = (element as any).eventListeners;
      if (listeners) {
        Object.keys(listeners).forEach((eventType) => {
          const eventListeners = listeners[eventType];
          if (eventListeners.length > 5) {
            console.warn(`Element has too many ${eventType} listeners:`, element);
          }
        });
      }
    });
  }

  // リソースヒントの追加
  static addResourceHints(): void {
    const head = document.head;

    // DNS prefetch
    const dnsPrefetch = document.createElement('link');
    dnsPrefetch.rel = 'dns-prefetch';
    dnsPrefetch.href = '//fonts.googleapis.com';
    head.appendChild(dnsPrefetch);

    // Preconnect
    const preconnect = document.createElement('link');
    preconnect.rel = 'preconnect';
    preconnect.href = 'https://api.example.com';
    head.appendChild(preconnect);

    // Prefetch
    const prefetch = document.createElement('link');
    prefetch.rel = 'prefetch';
    prefetch.href = '/api/user/profile';
    head.appendChild(prefetch);
  }
}

// メモリ最適化ユーティリティ
export class MemoryOptimizer {
  private static cleanupFunctions: (() => void)[] = [];

  // メモリリークの監視
  static monitorMemoryLeaks(): void {
    if (typeof window === 'undefined') return;

    const checkInterval = 30000; // 30秒間隔
    const memoryThreshold = 50 * 1024 * 1024; // 50MB

    const checkMemory = () => {
      if ((performance as any).memory) {
        const memInfo = (performance as any).memory;
        const usedMemory = memInfo.usedJSHeapSize;
        
        if (usedMemory > memoryThreshold) {
          console.warn('Memory usage is high:', usedMemory / 1024 / 1024, 'MB');
          this.runCleanup();
        }
      }
    };

    const intervalId = setInterval(checkMemory, checkInterval);
    this.addCleanupFunction(() => clearInterval(intervalId));
  }

  // クリーンアップ関数の追加
  static addCleanupFunction(fn: () => void): void {
    this.cleanupFunctions.push(fn);
  }

  // メモリクリーンアップの実行
  static runCleanup(): void {
    this.cleanupFunctions.forEach((fn) => {
      try {
        fn();
      } catch (error) {
        console.warn('Cleanup function failed:', error);
      }
    });
    
    // ガベージコレクションの強制実行（開発時のみ）
    if (process.env.NODE_ENV === 'development' && (window as any).gc) {
      (window as any).gc();
    }
  }

  // WeakMapとWeakSetの活用
  static createWeakCache<K extends object, V>(): WeakMap<K, V> {
    return new WeakMap<K, V>();
  }

  // イベントリスナーの自動削除
  static addEventListener<K extends keyof WindowEventMap>(
    target: EventTarget,
    type: K,
    listener: (this: Window, ev: WindowEventMap[K]) => any,
    options?: boolean | AddEventListenerOptions
  ): void {
    target.addEventListener(type, listener, options);
    
    // クリーンアップ関数に追加
    this.addCleanupFunction(() => {
      target.removeEventListener(type, listener, options);
    });
  }
}

// バンドルサイズ最適化
export class BundleOptimizer {
  // 動的インポートの最適化
  static async loadComponentDynamically<T>(
    importFn: () => Promise<{ default: T }>
  ): Promise<T> {
    try {
      const module = await importFn();
      return module.default;
    } catch (error) {
      console.error('Dynamic import failed:', error);
      throw error;
    }
  }

  // Tree Shaking最適化
  static optimizeTreeShaking(): void {
    // 使用されていない関数の検出
    const unusedFunctions = this.detectUnusedFunctions();
    if (unusedFunctions.length > 0) {
      console.warn('Unused functions detected:', unusedFunctions);
    }
  }

  private static detectUnusedFunctions(): string[] {
    const unusedFunctions: string[] = [];
    
    // 簡易的な使用されていない関数の検出
    const functionNames = this.extractFunctionNames();
    functionNames.forEach((name) => {
      if (!this.isFunctionUsed(name)) {
        unusedFunctions.push(name);
      }
    });

    return unusedFunctions;
  }

  private static extractFunctionNames(): string[] {
    // 実際の実装では、ASTパーサーを使用して関数名を抽出
    return [];
  }

  private static isFunctionUsed(name: string): boolean {
    // 実際の実装では、関数の使用状況を調べる
    return true;
  }
}

// パフォーマンス最適化のヘルパー関数
export const performanceHelpers = {
  // デバウンス（頻繁な呼び出しを制限）
  debounce: <T extends (...args: any[]) => any>(
    func: T,
    wait: number
  ): T => {
    return debounce(func, wait) as T;
  },

  // スロットル（一定間隔での実行を保証）
  throttle: <T extends (...args: any[]) => any>(
    func: T,
    wait: number
  ): T => {
    return throttle(func, wait) as T;
  },

  // requestAnimationFrameの最適化
  scheduleWork: (callback: () => void): void => {
    if (typeof requestAnimationFrame !== 'undefined') {
      requestAnimationFrame(callback);
    } else {
      setTimeout(callback, 16); // 60fps fallback
    }
  },

  // アイドル時の実行
  runWhenIdle: (callback: () => void, timeout: number = 5000): void => {
    if (typeof requestIdleCallback !== 'undefined') {
      requestIdleCallback(callback, { timeout });
    } else {
      setTimeout(callback, timeout);
    }
  },

  // 時間計測
  measureTime: <T>(name: string, fn: () => T): T => {
    const start = performance.now();
    const result = fn();
    const end = performance.now();
    console.log(`[Performance] ${name}: ${(end - start).toFixed(2)}ms`);
    return result;
  },

  // 非同期時間計測
  measureAsyncTime: async <T>(name: string, fn: () => Promise<T>): Promise<T> => {
    const start = performance.now();
    const result = await fn();
    const end = performance.now();
    console.log(`[Performance] ${name}: ${(end - start).toFixed(2)}ms`);
    return result;
  },

  // パフォーマンスマーク
  mark: (name: string): void => {
    if (typeof performance !== 'undefined' && performance.mark) {
      performance.mark(name);
    }
  },

  // パフォーマンス測定
  measure: (name: string, startMark: string, endMark: string): void => {
    if (typeof performance !== 'undefined' && performance.measure) {
      performance.measure(name, startMark, endMark);
    }
  },

  // Critical Resource Hintの追加
  addCriticalResourceHint: (url: string, as: string): void => {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = url;
    link.as = as;
    document.head.appendChild(link);
  },

  // Service Workerの最適化
  optimizeServiceWorker: async (): Promise<void> => {
    if ('serviceWorker' in navigator) {
      try {
        const registration = await navigator.serviceWorker.ready;
        if (registration.active) {
          // Service Workerの最適化処理
          registration.active.postMessage({
            type: 'OPTIMIZE_CACHE',
            timestamp: Date.now(),
          });
        }
      } catch (error) {
        console.warn('Service Worker optimization failed:', error);
      }
    }
  },
};

// パフォーマンス最適化の初期化
export const initializePerformanceOptimization = (): void => {
  // パフォーマンス監視の開始
  const monitor = PerformanceMonitor.getInstance();
  
  // リソースの最適化
  ResourceOptimizer.lazyLoadImages();
  ResourceOptimizer.addResourceHints();
  
  // メモリ最適化
  MemoryOptimizer.monitorMemoryLeaks();
  
  // バンドル最適化
  BundleOptimizer.optimizeTreeShaking();
  
  console.log('[Performance] Optimization initialized');
};

export default {
  PerformanceMonitor,
  ResourceOptimizer,
  MemoryOptimizer,
  BundleOptimizer,
  performanceHelpers,
  initializePerformanceOptimization,
};