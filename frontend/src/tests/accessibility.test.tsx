// Microsoft 365 Management Tools - Accessibility Tests
// WCAG 2.1 AA準拠のアクセシビリティテスト

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';
import { FeatureButton } from '../components/shared/FeatureButton';
import { TabNavigation } from '../components/layout/TabNavigation';
import { MainDashboard } from '../components/dashboard/MainDashboard';
import { AccessibilityProvider } from '../components/accessibility/AccessibilityProvider';
import { FEATURE_TABS } from '../config/features';

// jest-axe のマッチャーを拡張
expect.extend(toHaveNoViolations);

// テスト用のラッパーコンポーネント
const TestWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AccessibilityProvider>
    {children}
  </AccessibilityProvider>
);

describe('Accessibility Tests', () => {
  const user = userEvent.setup();

  describe('FeatureButton Accessibility', () => {
    const mockFeature = {
      id: 'test-feature',
      text: '📊 テスト機能',
      icon: '📊',
      action: 'TestAction',
      description: 'テスト用の機能です',
      category: 'regular-reports' as const,
      position: { x: 0, y: 0 },
      status: 'active' as const
    };

    it('should pass axe accessibility tests', async () => {
      const { container } = render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} onClick={jest.fn()} />
        </TestWrapper>
      );

      const results = await axe(container);
      expect(results).toHaveNoViolations();
    });

    it('should have proper ARIA attributes', () => {
      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} onClick={jest.fn()} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      expect(button).toHaveAttribute('aria-label', '📊 テスト機能 - テスト用の機能です');
      expect(button).toHaveAttribute('role', 'button');
      expect(button).toHaveAttribute('tabIndex', '0');
    });

    it('should be keyboard accessible', async () => {
      const mockClick = jest.fn();
      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} onClick={mockClick} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      
      // Tab でフォーカス
      await user.tab();
      expect(button).toHaveFocus();

      // Enter キーで実行
      await user.keyboard('{Enter}');
      expect(mockClick).toHaveBeenCalledWith('TestAction');

      // Space キーで実行
      await user.keyboard(' ');
      expect(mockClick).toHaveBeenCalledWith('TestAction');
    });

    it('should have proper focus management', async () => {
      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} onClick={jest.fn()} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      
      // フォーカス時のアウトライン
      await user.tab();
      expect(button).toHaveFocus();
      expect(button).toHaveClass('focus:outline-none', 'focus:ring-2');
    });

    it('should handle disabled state properly', () => {
      const disabledFeature = { ...mockFeature, status: 'disabled' as const };
      
      render(
        <TestWrapper>
          <FeatureButton feature={disabledFeature} onClick={jest.fn()} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      expect(button).toBeDisabled();
      expect(button).toHaveAttribute('aria-disabled', 'true');
    });

    it('should handle loading state with proper ARIA', () => {
      const loadingFeature = { ...mockFeature, status: 'loading' as const };
      
      render(
        <TestWrapper>
          <FeatureButton feature={loadingFeature} onClick={jest.fn()} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      expect(button).toHaveAttribute('aria-busy', 'true');
    });
  });

  describe('TabNavigation Accessibility', () => {
    it('should pass axe accessibility tests', async () => {
      const { container } = render(
        <TestWrapper>
          <TabNavigation 
            activeTab="regular-reports" 
            onTabChange={jest.fn()} 
          />
        </TestWrapper>
      );

      const results = await axe(container);
      expect(results).toHaveNoViolations();
    });

    it('should have proper tab role and attributes', () => {
      render(
        <TestWrapper>
          <TabNavigation 
            activeTab="regular-reports" 
            onTabChange={jest.fn()} 
          />
        </TestWrapper>
      );

      const tablist = screen.getByRole('tablist');
      expect(tablist).toHaveAttribute('aria-label', 'Microsoft 365 管理機能');

      const tabs = screen.getAllByRole('tab');
      expect(tabs).toHaveLength(FEATURE_TABS.length);

      // アクティブタブのチェック
      const activeTab = tabs.find(tab => tab.getAttribute('aria-selected') === 'true');
      expect(activeTab).toBeInTheDocument();
      expect(activeTab).toHaveAttribute('tabIndex', '0');

      // 非アクティブタブのチェック
      const inactiveTabs = tabs.filter(tab => tab.getAttribute('aria-selected') === 'false');
      inactiveTabs.forEach(tab => {
        expect(tab).toHaveAttribute('tabIndex', '-1');
      });
    });

    it('should support keyboard navigation', async () => {
      const mockTabChange = jest.fn();
      
      render(
        <TestWrapper>
          <TabNavigation 
            activeTab="regular-reports" 
            onTabChange={mockTabChange} 
          />
        </TestWrapper>
      );

      const tabs = screen.getAllByRole('tab');
      
      // 最初のタブにフォーカス
      tabs[0].focus();
      
      // 右矢印キーで次のタブに移動
      await user.keyboard('{ArrowRight}');
      expect(mockTabChange).toHaveBeenCalledWith('analytics-reports');

      // 左矢印キーで前のタブに移動
      await user.keyboard('{ArrowLeft}');
      expect(mockTabChange).toHaveBeenCalledWith('regular-reports');
    });
  });

  describe('MainDashboard Accessibility', () => {
    it('should pass axe accessibility tests', async () => {
      const { container } = render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      const results = await axe(container);
      expect(results).toHaveNoViolations();
    });

    it('should have proper landmark roles', () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // ヘッダー
      const header = screen.getByRole('banner');
      expect(header).toBeInTheDocument();

      // メインコンテンツ
      const main = screen.getByRole('main');
      expect(main).toBeInTheDocument();

      // フッター
      const footer = screen.getByRole('contentinfo');
      expect(footer).toBeInTheDocument();
    });

    it('should have proper heading hierarchy', () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // h1 が存在する
      const h1 = screen.getByRole('heading', { level: 1 });
      expect(h1).toBeInTheDocument();
      expect(h1).toHaveTextContent('Microsoft 365統合管理ツール');

      // h2 が存在する（タブセクション）
      const h2Elements = screen.getAllByRole('heading', { level: 2 });
      expect(h2Elements.length).toBeGreaterThan(0);
    });

    it('should support keyboard shortcuts', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // Ctrl+R で定期レポートタブに移動
      await user.keyboard('{Control>}r{/Control}');
      
      await waitFor(() => {
        const activeTab = screen.getByRole('tab', { selected: true });
        expect(activeTab).toHaveTextContent('📊 定期レポート');
      });
    });
  });

  describe('Color Contrast', () => {
    it('should meet WCAG AA contrast requirements', async () => {
      const { container } = render(
        <TestWrapper>
          <FeatureButton 
            feature={{
              id: 'test',
              text: 'テスト',
              icon: '📊',
              action: 'Test',
              description: 'テスト',
              category: 'regular-reports',
              position: { x: 0, y: 0 },
              status: 'active'
            }}
            onClick={jest.fn()}
          />
        </TestWrapper>
      );

      const results = await axe(container, {
        rules: {
          'color-contrast': { enabled: true }
        }
      });
      
      expect(results).toHaveNoViolations();
    });
  });

  describe('Focus Management', () => {
    it('should trap focus in modal dialogs', async () => {
      // モーダルダイアログのフォーカストラップテスト
      // 実際のモーダルコンポーネントが実装されたらテスト
    });

    it('should restore focus after modal closes', async () => {
      // モーダル閉じた後のフォーカス復帰テスト
    });
  });

  describe('Screen Reader Support', () => {
    it('should announce status changes', async () => {
      // スクリーンリーダーへの告知テスト
      // 実際のコンポーネントでの状態変化時の告知
    });

    it('should have proper live regions', () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // aria-live 領域が存在する
      const liveRegion = document.querySelector('[aria-live]');
      expect(liveRegion).toBeInTheDocument();
    });
  });

  describe('Motion and Animation', () => {
    it('should respect prefers-reduced-motion', async () => {
      // モーション制御のテスト
      Object.defineProperty(window, 'matchMedia', {
        writable: true,
        value: jest.fn().mockImplementation(query => ({
          matches: query === '(prefers-reduced-motion: reduce)',
          media: query,
          onchange: null,
          addListener: jest.fn(),
          removeListener: jest.fn(),
          addEventListener: jest.fn(),
          removeEventListener: jest.fn(),
          dispatchEvent: jest.fn(),
        })),
      });

      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // reduce-motion クラスが適用されているか確認
      expect(document.documentElement).toHaveClass('reduce-motion');
    });
  });

  describe('High Contrast Mode', () => {
    it('should support high contrast mode', async () => {
      Object.defineProperty(window, 'matchMedia', {
        writable: true,
        value: jest.fn().mockImplementation(query => ({
          matches: query === '(prefers-contrast: high)',
          media: query,
          onchange: null,
          addListener: jest.fn(),
          removeListener: jest.fn(),
          addEventListener: jest.fn(),
          removeEventListener: jest.fn(),
          dispatchEvent: jest.fn(),
        })),
      });

      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // high-contrast クラスが適用されているか確認
      expect(document.documentElement).toHaveClass('high-contrast');
    });
  });

  describe('Form Accessibility', () => {
    it('should have proper form labels and descriptions', () => {
      // フォームのラベルと説明のテスト
      // 実際のフォームコンポーネントが実装されたらテスト
    });

    it('should show validation errors accessibly', () => {
      // バリデーションエラーのアクセシビリティテスト
    });
  });
});

// カスタムテストユーティリティ
export const testAccessibility = async (component: React.ReactElement) => {
  const { container } = render(
    <TestWrapper>
      {component}
    </TestWrapper>
  );

  const results = await axe(container);
  expect(results).toHaveNoViolations();
  
  return { container, results };
};

// パフォーマンステスト
export const testPerformance = async (component: React.ReactElement) => {
  const startTime = performance.now();
  
  render(
    <TestWrapper>
      {component}
    </TestWrapper>
  );
  
  const endTime = performance.now();
  const renderTime = endTime - startTime;
  
  // レンダリング時間が100ms以下であることを確認
  expect(renderTime).toBeLessThan(100);
  
  return renderTime;
};