// Microsoft 365 Management Tools - Accessibility Provider
// WCAG 2.1 AA準拠のアクセシビリティ機能
// パフォーマンス最適化版

import React, { createContext, useContext, useEffect, useState, useCallback, useMemo } from 'react';
import { AccessibilityConfig } from '../../types/features';
import { useAppStore } from '../../store/appStore';
import '../../../styles/accessibility.css';

interface AccessibilityContextType {
  config: AccessibilityConfig;
  updateConfig: (config: Partial<AccessibilityConfig>) => void;
  announceToScreenReader: (message: string) => void;
  focusElement: (elementId: string) => void;
  trapFocus: (containerId: string) => void;
  releaseFocus: () => void;
}

const AccessibilityContext = createContext<AccessibilityContextType | undefined>(undefined);

export const useAccessibility = () => {
  const context = useContext(AccessibilityContext);
  if (!context) {
    throw new Error('useAccessibility must be used within AccessibilityProvider');
  }
  return context;
};

interface AccessibilityProviderProps {
  children: React.ReactNode;
}

export const AccessibilityProvider: React.FC<AccessibilityProviderProps> = ({ children }) => {
  const { accessibility, setAccessibility } = useAppStore();
  const [lastFocusedElement, setLastFocusedElement] = useState<Element | null>(null);
  const [focusTrapped, setFocusTrapped] = useState<string | null>(null);

  // スクリーンリーダー告知用の要素
  const [announcer, setAnnouncer] = useState<HTMLElement | null>(null);

  // システム設定の検出（最適化版）
  const detectSystemPreferences = useCallback(() => {
    const updates: Partial<AccessibilityConfig> = {};
    
    // 高コントラストモード検出
    if (window.matchMedia('(prefers-contrast: high)').matches) {
      updates.highContrast = true;
    }
    
    // モーション制御設定検出
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      updates.reducedMotion = true;
    }
    
    // ダークモード検出
    if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
      updates.darkMode = true;
    }
    
    // フォーカス表示設定
    if (window.matchMedia('(any-pointer: coarse)').matches) {
      updates.enhancedFocus = true; // タッチデバイス
    }
    
    if (Object.keys(updates).length > 0) {
      setAccessibility(updates);
    }
  }, [setAccessibility]);

  useEffect(() => {
    detectSystemPreferences();

    // メディアクエリの変更監視（パフォーマンス最適化）
    const queries = [
      { query: '(prefers-contrast: high)', handler: (e: MediaQueryListEvent) => setAccessibility({ highContrast: e.matches }) },
      { query: '(prefers-reduced-motion: reduce)', handler: (e: MediaQueryListEvent) => setAccessibility({ reducedMotion: e.matches }) },
      { query: '(prefers-color-scheme: dark)', handler: (e: MediaQueryListEvent) => setAccessibility({ darkMode: e.matches }) },
      { query: '(any-pointer: coarse)', handler: (e: MediaQueryListEvent) => setAccessibility({ enhancedFocus: e.matches }) },
    ];

    const mediaQueries = queries.map(({ query, handler }) => {
      const mq = window.matchMedia(query);
      mq.addEventListener('change', handler);
      return { mq, handler };
    });

    return () => {
      mediaQueries.forEach(({ mq, handler }) => {
        mq.removeEventListener('change', handler);
      });
    };
  }, [detectSystemPreferences, setAccessibility]);

  // DOM の更新（パフォーマンス最適化版）
  const applyAccessibilityStyles = useCallback(() => {
    const root = document.documentElement;
    
    // CSSクラス管理（バッチ処理）
    const classesToAdd: string[] = [];
    const classesToRemove: string[] = [];
    
    // 高コントラストモード
    if (accessibility.highContrast) {
      classesToAdd.push('high-contrast');
    } else {
      classesToRemove.push('high-contrast');
    }
    
    // モーション制御
    if (accessibility.reducedMotion) {
      classesToAdd.push('reduce-motion');
    } else {
      classesToRemove.push('reduce-motion');
    }
    
    // ダークモード
    if (accessibility.darkMode) {
      classesToAdd.push('dark-mode');
    } else {
      classesToRemove.push('dark-mode');
    }
    
    // キーボードナビゲーション
    if (accessibility.keyboardNavigation) {
      classesToAdd.push('keyboard-navigation');
    } else {
      classesToRemove.push('keyboard-navigation');
    }
    
    // バッチ更新
    root.classList.add(...classesToAdd);
    root.classList.remove(...classesToRemove);
    
    // CSS変数更新
    const fontSizeMap = {
      small: '14px',
      medium: '16px',
      large: '18px',
      xl: '20px'
    };
    
    root.style.setProperty('--accessibility-font-size', fontSizeMap[accessibility.fontSize]);
    root.style.setProperty('--accessibility-contrast', accessibility.highContrast ? 'high' : 'normal');
    root.style.setProperty('--accessibility-motion', accessibility.reducedMotion ? 'reduce' : 'normal');
    
  }, [accessibility]);

  useEffect(() => {
    applyAccessibilityStyles();
  }, [applyAccessibilityStyles]);

  // スクリーンリーダー告知用要素の作成
  useEffect(() => {
    const element = document.createElement('div');
    element.id = 'accessibility-announcer';
    element.setAttribute('aria-live', 'polite');
    element.setAttribute('aria-atomic', 'true');
    element.className = 'sr-only';
    document.body.appendChild(element);
    setAnnouncer(element);

    return () => {
      if (element.parentNode) {
        element.parentNode.removeChild(element);
      }
    };
  }, []);

  // キーボードナビゲーション
  useEffect(() => {
    if (!accessibility.keyboardNavigation) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      // Escキーでフォーカストラップを解除
      if (event.key === 'Escape' && focusTrapped) {
        releaseFocus();
      }

      // Tab キーでフォーカストラップ
      if (event.key === 'Tab' && focusTrapped) {
        trapFocusWithinContainer(focusTrapped, event);
      }

      // ランドマーク間のナビゲーション
      if (event.key === 'F6') {
        event.preventDefault();
        navigateToNextLandmark(event.shiftKey);
      }

      // スキップリンク
      if (event.key === 'F7') {
        event.preventDefault();
        showSkipLinks();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [accessibility.keyboardNavigation, focusTrapped]);

  // スクリーンリーダーへの告知（最適化版）
  const announceToScreenReader = useCallback((message: string, priority: 'polite' | 'assertive' = 'polite') => {
    if (!announcer || !accessibility.screenReaderMode) return;
    
    // 重複アナウンスの防止
    if (announcer.textContent === message) return;
    
    // 優先度設定
    announcer.setAttribute('aria-live', priority);
    announcer.textContent = message;
    
    // アナウンス後にクリア（メモリリーク防止）
    const timeoutId = setTimeout(() => {
      if (announcer.textContent === message) {
        announcer.textContent = '';
      }
    }, priority === 'assertive' ? 2000 : 1000);
    
    return () => clearTimeout(timeoutId);
  }, [announcer, accessibility.screenReaderMode]);

  // 要素にフォーカス（最適化版）
  const focusElement = useCallback((elementId: string) => {
    const element = document.getElementById(elementId);
    if (element) {
      // スムーズスクロールとフォーカス
      element.scrollIntoView({ behavior: accessibility.reducedMotion ? 'auto' : 'smooth', block: 'center' });
      
      // フォーカス可能要素でない場合はtabindexを設定
      if (!element.matches('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')) {
        element.setAttribute('tabindex', '-1');
      }
      
      element.focus();
      
      const label = element.getAttribute('aria-label') || 
                   element.getAttribute('aria-labelledby') && 
                   document.getElementById(element.getAttribute('aria-labelledby')!)?.textContent ||
                   element.textContent?.trim() ||
                   '要素';
      
      announceToScreenReader(`フォーカスが${label}に移動しました`);
    }
  }, [accessibility.reducedMotion, announceToScreenReader]);

  // フォーカストラップ（最適化版）
  const trapFocus = useCallback((containerId: string) => {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    setLastFocusedElement(document.activeElement);
    setFocusTrapped(containerId);
    
    // フォーカス可能要素の検出（最適化）
    const focusableSelector = [
      'button:not([disabled])',
      '[href]:not([disabled])',
      'input:not([disabled]):not([type="hidden"])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"]):not([disabled])',
      '[contenteditable="true"]'
    ].join(', ');
    
    const focusableElements = container.querySelectorAll<HTMLElement>(focusableSelector);
    
    if (focusableElements.length > 0) {
      const firstFocusable = focusableElements[0];
      firstFocusable.focus();
      
      announceToScreenReader(`フォーカスが${container.getAttribute('aria-label') || 'ダイアログ'}内に制限されました`);
    }
  }, [announceToScreenReader]);

  // フォーカストラップの解除（最適化版）
  const releaseFocus = useCallback(() => {
    setFocusTrapped(null);
    
    if (lastFocusedElement instanceof HTMLElement) {
      // 元の要素がまだ存在しているか確認
      if (document.contains(lastFocusedElement)) {
        lastFocusedElement.focus();
        announceToScreenReader('フォーカス制限が解除されました');
      } else {
        // 元の要素がない場合はメインコンテンツにフォーカス
        const mainContent = document.getElementById('main-content');
        if (mainContent) {
          mainContent.focus();
        }
      }
    }
    
    setLastFocusedElement(null);
  }, [lastFocusedElement, announceToScreenReader]);

  // フォーカストラップ内でのタブナビゲーション
  const trapFocusWithinContainer = (containerId: string, event: KeyboardEvent) => {
    const container = document.getElementById(containerId);
    if (!container) return;

    const focusableElements = container.querySelectorAll<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );

    if (focusableElements.length === 0) return;

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    if (event.shiftKey) {
      // Shift+Tab
      if (document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      }
    } else {
      // Tab
      if (document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    }
  };

  // ランドマーク間のナビゲーション
  const navigateToNextLandmark = (reverse: boolean = false) => {
    const landmarks = document.querySelectorAll<HTMLElement>(
      '[role="main"], [role="navigation"], [role="banner"], [role="contentinfo"], [role="complementary"], [role="region"]'
    );

    if (landmarks.length === 0) return;

    const currentIndex = Array.from(landmarks).findIndex(
      landmark => landmark.contains(document.activeElement)
    );

    let nextIndex;
    if (reverse) {
      nextIndex = currentIndex <= 0 ? landmarks.length - 1 : currentIndex - 1;
    } else {
      nextIndex = currentIndex >= landmarks.length - 1 ? 0 : currentIndex + 1;
    }

    const nextLandmark = landmarks[nextIndex];
    if (nextLandmark) {
      nextLandmark.focus();
      announceToScreenReader(`${nextLandmark.getAttribute('aria-label') || 'ランドマーク'}に移動しました`);
    }
  };

  // スキップリンクの表示
  const showSkipLinks = () => {
    const skipLinks = document.querySelectorAll<HTMLElement>('.skip-link');
    skipLinks.forEach(link => {
      link.style.display = 'block';
      link.style.position = 'absolute';
      link.style.top = '10px';
      link.style.left = '10px';
      link.style.zIndex = '9999';
      link.style.padding = '8px 16px';
      link.style.backgroundColor = '#000';
      link.style.color = '#fff';
      link.style.textDecoration = 'none';
      link.style.borderRadius = '4px';
    });

    if (skipLinks.length > 0) {
      (skipLinks[0] as HTMLElement).focus();
    }
  };

  // 設定の更新（最適化版）
  const updateConfig = useCallback((config: Partial<AccessibilityConfig>) => {
    setAccessibility(config);
    
    // ローカルストレージに保存
    try {
      const currentSettings = JSON.parse(localStorage.getItem('accessibility-settings') || '{}');
      const updatedSettings = { ...currentSettings, ...config };
      localStorage.setItem('accessibility-settings', JSON.stringify(updatedSettings));
    } catch (error) {
      console.error('Failed to save accessibility settings:', error);
    }
    
    // 設定変更の告知（最適化）
    const changes = Object.entries(config)
      .map(([key, value]) => {
        const labels: Record<string, string> = {
          highContrast: '高コントラスト',
          reducedMotion: 'モーション減少',
          fontSize: 'フォントサイズ',
          keyboardNavigation: 'キーボードナビゲーション',
          screenReaderMode: 'スクリーンリーダーモード'
        };
        return `${labels[key] || key}: ${value}`;
      })
      .join(', ');
    
    announceToScreenReader(`アクセシビリティ設定が更新されました: ${changes}`);
  }, [setAccessibility, announceToScreenReader]);
  
  // 設定の初期読み込み
  useEffect(() => {
    try {
      const savedSettings = localStorage.getItem('accessibility-settings');
      if (savedSettings) {
        const parsedSettings = JSON.parse(savedSettings);
        setAccessibility(parsedSettings);
      }
    } catch (error) {
      console.error('Failed to load accessibility settings:', error);
    }
  }, [setAccessibility]);

  // Context値のメモ化（パフォーマンス最適化）
  const contextValue: AccessibilityContextType = useMemo(() => ({
    config: accessibility,
    updateConfig,
    announceToScreenReader,
    focusElement,
    trapFocus,
    releaseFocus
  }), [accessibility, updateConfig, announceToScreenReader, focusElement, trapFocus, releaseFocus]);

  return (
    <AccessibilityContext.Provider value={contextValue}>
      {children}
      
      {/* スキップリンク（最適化版） */}
      {accessibility.keyboardNavigation && (
        <nav className="skip-links sr-only focus-within:not-sr-only" aria-label="スキップリンク">
          <a href="#main-content" className="skip-link focus-visible-enhanced">
            メインコンテンツにスキップ
          </a>
          <a href="#navigation" className="skip-link focus-visible-enhanced">
            ナビゲーションにスキップ
          </a>
          <a href="#feature-grid" className="skip-link focus-visible-enhanced">
            機能一覧にスキップ
          </a>
        </nav>
      )}
      
      {/* ライブリージョン（強化版） */}
      <div 
        aria-live="polite" 
        aria-atomic="true" 
        className="sr-only" 
        id="polite-announcements"
        role="status"
      />
      <div 
        aria-live="assertive" 
        aria-atomic="true" 
        className="sr-only" 
        id="assertive-announcements"
        role="alert"
      />
    </AccessibilityContext.Provider>
  );
};

// HOC: アクセシビリティ機能を追加（最適化版）
export const withAccessibility = <P extends object>(
  Component: React.ComponentType<P>,
  options: { 
    announceOnMount?: boolean;
    enableFocusManagement?: boolean;
    customAnnouncement?: string;
  } = {}
) => {
  const { 
    announceOnMount = false, 
    enableFocusManagement = false,
    customAnnouncement 
  } = options;
  
  const AccessibleComponent = React.memo((props: P) => {
    const { announceToScreenReader, config } = useAccessibility();

    // コンポーネントのマウント時に告知（オプション）
    useEffect(() => {
      if (announceOnMount && config.screenReaderMode) {
        const message = customAnnouncement || 
          `${Component.displayName || Component.name || 'コンポーネント'}が読み込まれました`;
        announceToScreenReader(message);
      }
    }, [announceToScreenReader, config.screenReaderMode]);

    // フォーカス管理（オプション）
    useEffect(() => {
      if (enableFocusManagement && config.keyboardNavigation) {
        // フォーカス可能要素の自動検出と管理
      }
    }, [config.keyboardNavigation]);

    return (
      <div 
        className="accessible-component"
        data-accessibility-enabled={config.keyboardNavigation}
        data-high-contrast={config.highContrast}
        data-reduced-motion={config.reducedMotion}
      >
        <Component {...props} />
      </div>
    );
  });

  AccessibleComponent.displayName = `withAccessibility(${Component.displayName || Component.name})`;
  return AccessibleComponent;
};

// アクセシビリティチェッカー（開発用）
export const AccessibilityDevTools: React.FC = () => {
  const [issues, setIssues] = useState<Array<{ type: string; message: string; element?: string }>>([]);
  const { config } = useAccessibility();

  useEffect(() => {
    if (process.env.NODE_ENV !== 'development') return;

    const checkAccessibility = () => {
      const foundIssues: Array<{ type: string; message: string; element?: string }> = [];

      // 基本的なアクセシビリティチェック
      document.querySelectorAll('img').forEach((img, index) => {
        if (!img.alt && !img.getAttribute('aria-label')) {
          foundIssues.push({ 
            type: 'missing-alt', 
            message: `画像 ${index + 1}: alt属性またはaria-labelが必要`,
            element: img.outerHTML.substring(0, 100)
          });
        }
      });

      document.querySelectorAll('button').forEach((button, index) => {
        if (!button.textContent?.trim() && !button.getAttribute('aria-label')) {
          foundIssues.push({ 
            type: 'missing-label', 
            message: `ボタン ${index + 1}: テキストまたはaria-labelが必要`,
            element: button.outerHTML.substring(0, 100)
          });
        }
      });

      setIssues(foundIssues);
    };

    const timeoutId = setTimeout(checkAccessibility, 1000);
    return () => clearTimeout(timeoutId);
  }, []);

  if (process.env.NODE_ENV !== 'development' || issues.length === 0) {
    return null;
  }

  return (
    <div className="accessibility-dev-tools" style={{ 
      position: 'fixed', 
      bottom: 10, 
      right: 10, 
      background: '#fee', 
      padding: 15, 
      border: '2px solid #f00',
      borderRadius: 8,
      maxWidth: 400,
      maxHeight: 300,
      overflow: 'auto',
      zIndex: 9999,
      fontSize: '12px',
      fontFamily: 'monospace'
    }}>
      <h4 style={{ margin: '0 0 10px 0', color: '#d00' }}>
        アクセシビリティの問題 ({issues.length})
      </h4>
      {issues.map((issue, index) => (
        <div key={index} style={{ margin: '5px 0', padding: '5px', background: '#fff', border: '1px solid #ccc', borderRadius: '3px' }}>
          <strong>{issue.type}:</strong> {issue.message}
          {issue.element && (
            <div style={{ fontSize: '10px', color: '#666', marginTop: '2px' }}>
              {issue.element}...
            </div>
          )}
        </div>
      ))}
      <div style={{ marginTop: '10px', fontSize: '10px', color: '#666' }}>
        現在の設定: {JSON.stringify(config, null, 2).substring(0, 100)}...
      </div>
    </div>
  );
};

export default AccessibilityProvider;