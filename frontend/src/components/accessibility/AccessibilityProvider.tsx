// Microsoft 365 Management Tools - Accessibility Provider
// WCAG 2.1 AA準拠のアクセシビリティ機能

import React, { createContext, useContext, useEffect, useState } from 'react';
import { AccessibilityConfig } from '../../types/features';
import { useAppStore } from '../../store/appStore';

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

  // システム設定の検出
  useEffect(() => {
    const detectSystemPreferences = () => {
      // 高コントラストモード検出
      const highContrast = window.matchMedia('(prefers-contrast: high)').matches;
      
      // モーション制御設定検出
      const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      
      setAccessibility({
        highContrast,
        reducedMotion
      });
    };

    detectSystemPreferences();

    // メディアクエリの変更監視
    const contrastQuery = window.matchMedia('(prefers-contrast: high)');
    const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

    const handleContrastChange = (e: MediaQueryListEvent) => {
      setAccessibility({ highContrast: e.matches });
    };

    const handleMotionChange = (e: MediaQueryListEvent) => {
      setAccessibility({ reducedMotion: e.matches });
    };

    contrastQuery.addEventListener('change', handleContrastChange);
    motionQuery.addEventListener('change', handleMotionChange);

    return () => {
      contrastQuery.removeEventListener('change', handleContrastChange);
      motionQuery.removeEventListener('change', handleMotionChange);
    };
  }, [setAccessibility]);

  // DOM の更新
  useEffect(() => {
    const root = document.documentElement;
    
    // 高コントラストモード
    if (accessibility.highContrast) {
      root.classList.add('high-contrast');
    } else {
      root.classList.remove('high-contrast');
    }
    
    // モーション制御
    if (accessibility.reducedMotion) {
      root.classList.add('reduce-motion');
    } else {
      root.classList.remove('reduce-motion');
    }
    
    // フォントサイズ
    root.style.fontSize = {
      small: '14px',
      medium: '16px',
      large: '18px',
      xl: '20px'
    }[accessibility.fontSize];
    
  }, [accessibility]);

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

  // スクリーンリーダーへの告知
  const announceToScreenReader = (message: string) => {
    if (announcer) {
      announcer.textContent = message;
      // 一定時間後にクリア
      setTimeout(() => {
        announcer.textContent = '';
      }, 1000);
    }
  };

  // 要素にフォーカス
  const focusElement = (elementId: string) => {
    const element = document.getElementById(elementId);
    if (element) {
      element.focus();
      announceToScreenReader(`フォーカスが${element.getAttribute('aria-label') || element.textContent}に移動しました`);
    }
  };

  // フォーカストラップ
  const trapFocus = (containerId: string) => {
    const container = document.getElementById(containerId);
    if (container) {
      setLastFocusedElement(document.activeElement);
      setFocusTrapped(containerId);
      
      // 最初のフォーカス可能要素にフォーカス
      const firstFocusable = container.querySelector<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );
      if (firstFocusable) {
        firstFocusable.focus();
      }
    }
  };

  // フォーカストラップの解除
  const releaseFocus = () => {
    setFocusTrapped(null);
    if (lastFocusedElement instanceof HTMLElement) {
      lastFocusedElement.focus();
    }
    setLastFocusedElement(null);
  };

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

  // 設定の更新
  const updateConfig = (config: Partial<AccessibilityConfig>) => {
    setAccessibility(config);
    
    // 設定変更の告知
    const changes = Object.keys(config).map(key => {
      const value = config[key as keyof AccessibilityConfig];
      return `${key}: ${value}`;
    }).join(', ');
    
    announceToScreenReader(`アクセシビリティ設定が更新されました: ${changes}`);
  };

  const contextValue: AccessibilityContextType = {
    config: accessibility,
    updateConfig,
    announceToScreenReader,
    focusElement,
    trapFocus,
    releaseFocus
  };

  return (
    <AccessibilityContext.Provider value={contextValue}>
      {children}
      
      {/* スキップリンク */}
      <div className="skip-links sr-only focus-within:not-sr-only">
        <a href="#main-content" className="skip-link">
          メインコンテンツにスキップ
        </a>
        <a href="#navigation" className="skip-link">
          ナビゲーションにスキップ
        </a>
      </div>
    </AccessibilityContext.Provider>
  );
};

// HOC: アクセシビリティ機能を追加
export const withAccessibility = <P extends object>(
  Component: React.ComponentType<P>
) => {
  const AccessibleComponent = (props: P) => {
    const { announceToScreenReader } = useAccessibility();

    // コンポーネントのマウント時に告知
    useEffect(() => {
      announceToScreenReader(`${Component.displayName || Component.name || 'コンポーネント'}が読み込まれました`);
    }, [announceToScreenReader]);

    return <Component {...props} />;
  };

  AccessibleComponent.displayName = `withAccessibility(${Component.displayName || Component.name})`;
  return AccessibleComponent;
};

export default AccessibilityProvider;