// Microsoft 365 Management Tools - Final Integration Test Suite
// 最終統合テストと品質確認

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter } from 'react-router-dom';
import { vi, describe, it, expect, beforeEach, afterEach } from 'vitest';
import { server } from './mocks/server';
import { rest } from 'msw';

// テスト対象コンポーネント
import { MainDashboard } from '../components/dashboard/MainDashboard';
import { MonitoringDashboard } from '../components/monitoring/MonitoringDashboard';
import { HealthMonitor } from '../components/monitoring/HealthMonitor';
import { PerformanceMonitor } from '../components/monitoring/PerformanceMonitor';
import { AlertManager } from '../components/monitoring/AlertManager';
import { LogViewer } from '../components/monitoring/LogViewer';
import { AccessibilityProvider } from '../components/accessibility/AccessibilityProvider';
import { useAppStore } from '../store/appStore';
import { initializePerformanceOptimization } from '../utils/performance';
import { initializeSecurity } from '../utils/security';

// テストヘルパー
const createTestQueryClient = () => {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        staleTime: 0,
        refetchOnWindowFocus: false,
      },
    },
  });
};

const TestWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const queryClient = createTestQueryClient();
  
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AccessibilityProvider>
          {children}
        </AccessibilityProvider>
      </BrowserRouter>
    </QueryClientProvider>
  );
};

// モックデータ
const mockSystemHealth = {
  overall: {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    responseTime: 150,
    message: 'System is running normally'
  },
  frontend: {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    responseTime: 100,
  },
  backend: {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    responseTime: 200,
  },
  database: {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    responseTime: 50,
  },
  api: {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    responseTime: 120,
  },
  authentication: {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    responseTime: 80,
  },
  microsoft365: {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    responseTime: 300,
  },
};

const mockPerformanceData = {
  current: {
    cpu: 45.2,
    memory: 67.8,
    network: 23.1,
    disk: 78.5,
    responseTime: 150,
    throughput: 85.3,
  },
  history: [
    { timestamp: new Date().toISOString(), value: 45.2, unit: '%', category: 'cpu' },
    { timestamp: new Date().toISOString(), value: 67.8, unit: '%', category: 'memory' },
  ],
  alerts: [],
};

const mockAlerts = [
  {
    id: 'alert-1',
    title: 'High CPU Usage',
    message: 'CPU usage is above 80%',
    severity: 'warning',
    source: 'system',
    timestamp: new Date().toISOString(),
    acknowledged: false,
    resolved: false,
  },
  {
    id: 'alert-2',
    title: 'Database Connection Error',
    message: 'Unable to connect to database',
    severity: 'critical',
    source: 'database',
    timestamp: new Date().toISOString(),
    acknowledged: false,
    resolved: false,
  },
];

const mockLogs = [
  {
    id: 'log-1',
    timestamp: new Date().toISOString(),
    level: 'info',
    message: 'User logged in successfully',
    source: 'authentication',
    userId: 'user-123',
  },
  {
    id: 'log-2',
    timestamp: new Date().toISOString(),
    level: 'error',
    message: 'Failed to connect to external API',
    source: 'api',
    stack: 'Error: Connection timeout\n  at fetch...',
  },
];

// テストスイート
describe('Final Integration Tests', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = createTestQueryClient();
    
    // MSWハンドラーの設定
    server.use(
      rest.get('/api/health/system', (req, res, ctx) => {
        return res(ctx.json(mockSystemHealth));
      }),
      rest.get('/api/monitoring/performance', (req, res, ctx) => {
        return res(ctx.json(mockPerformanceData));
      }),
      rest.get('/api/monitoring/web-vitals', (req, res, ctx) => {
        return res(ctx.json({
          fcp: 1200,
          lcp: 2100,
          fid: 50,
          cls: 0.05,
          ttfb: 400,
          tti: 3000,
        }));
      }),
      rest.get('/api/alerts', (req, res, ctx) => {
        return res(ctx.json(mockAlerts));
      }),
      rest.get('/api/logs', (req, res, ctx) => {
        return res(ctx.json(mockLogs));
      }),
      rest.get('/api/monitoring/overview', (req, res, ctx) => {
        return res(ctx.json({
          systemStatus: 'healthy',
          uptime: 86400,
          totalAlerts: 2,
          criticalAlerts: 1,
          errorRate: 0.5,
          avgResponseTime: 150,
          activeUsers: 45,
          lastUpdate: new Date().toISOString(),
        }));
      }),
      rest.get('/api/monitoring/quick-stats', (req, res, ctx) => {
        return res(ctx.json({
          cpu: 45.2,
          memory: 67.8,
          disk: 78.5,
          network: 23.1,
          throughput: 85.3,
          errors: 2,
        }));
      })
    );
  });

  afterEach(() => {
    queryClient.clear();
  });

  describe('Main Dashboard Integration', () => {
    it('should render main dashboard with all components', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // タイトルの確認
      expect(screen.getByText('Microsoft 365 Management Tools')).toBeInTheDocument();
      
      // タブナビゲーションの確認
      expect(screen.getByRole('button', { name: /📊 定期レポート/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /🔍 分析レポート/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /👥 Entra ID/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /📧 Exchange Online/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /💬 Teams/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /💾 OneDrive/i })).toBeInTheDocument();
    });

    it('should handle tab navigation correctly', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // 初期状態では定期レポートタブが選択されている
      expect(screen.getByText('定期レポート')).toBeInTheDocument();
      
      // Entra IDタブをクリック
      fireEvent.click(screen.getByRole('button', { name: /👥 Entra ID/i }));
      
      await waitFor(() => {
        expect(screen.getByText('Entra ID管理')).toBeInTheDocument();
      });
    });

    it('should execute feature functions correctly', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // 機能ボタンをクリック
      const dailyReportButton = screen.getByRole('button', { name: /日次レポート/i });
      fireEvent.click(dailyReportButton);

      await waitFor(() => {
        expect(screen.getByText(/実行中/i)).toBeInTheDocument();
      });
    });
  });

  describe('Monitoring Dashboard Integration', () => {
    it('should render monitoring dashboard with all components', async () => {
      render(
        <TestWrapper>
          <MonitoringDashboard />
        </TestWrapper>
      );

      // タイトルの確認
      expect(screen.getByText('Microsoft 365 Management Tools - 監視ダッシュボード')).toBeInTheDocument();
      
      // ナビゲーションタブの確認
      expect(screen.getByRole('button', { name: /📊 概要/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /❤️ ヘルス/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /⚡ パフォーマンス/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /🚨 アラート/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /📋 ログ/i })).toBeInTheDocument();
    });

    it('should display system overview correctly', async () => {
      render(
        <TestWrapper>
          <MonitoringDashboard />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('クイック統計')).toBeInTheDocument();
        expect(screen.getByText('システム概要')).toBeInTheDocument();
      });
    });

    it('should handle monitoring tab navigation', async () => {
      render(
        <TestWrapper>
          <MonitoringDashboard />
        </TestWrapper>
      );

      // ヘルスタブをクリック
      fireEvent.click(screen.getByRole('button', { name: /❤️ ヘルス/i }));
      
      await waitFor(() => {
        expect(screen.getByText('システム監視ダッシュボード')).toBeInTheDocument();
      });
    });
  });

  describe('Health Monitor Integration', () => {
    it('should render health monitor with system status', async () => {
      render(
        <TestWrapper>
          <HealthMonitor />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('システム監視ダッシュボード')).toBeInTheDocument();
        expect(screen.getByText('コンポーネント状態')).toBeInTheDocument();
      });
    });

    it('should display component health status', async () => {
      render(
        <TestWrapper>
          <HealthMonitor />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('フロントエンド')).toBeInTheDocument();
        expect(screen.getByText('バックエンド')).toBeInTheDocument();
        expect(screen.getByText('データベース')).toBeInTheDocument();
        expect(screen.getByText('API')).toBeInTheDocument();
        expect(screen.getByText('認証')).toBeInTheDocument();
        expect(screen.getByText('Microsoft 365')).toBeInTheDocument();
      });
    });
  });

  describe('Performance Monitor Integration', () => {
    it('should render performance monitor with metrics', async () => {
      render(
        <TestWrapper>
          <PerformanceMonitor />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('パフォーマンスモニター')).toBeInTheDocument();
        expect(screen.getByText('現在のパフォーマンス')).toBeInTheDocument();
        expect(screen.getByText('Core Web Vitals')).toBeInTheDocument();
      });
    });

    it('should display performance metrics correctly', async () => {
      render(
        <TestWrapper>
          <PerformanceMonitor />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('CPU使用率')).toBeInTheDocument();
        expect(screen.getByText('メモリ使用率')).toBeInTheDocument();
        expect(screen.getByText('応答時間')).toBeInTheDocument();
        expect(screen.getByText('ネットワーク使用率')).toBeInTheDocument();
        expect(screen.getByText('ディスク使用率')).toBeInTheDocument();
        expect(screen.getByText('スループット')).toBeInTheDocument();
      });
    });
  });

  describe('Alert Manager Integration', () => {
    it('should render alert manager with alerts', async () => {
      render(
        <TestWrapper>
          <AlertManager />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('アラートマネージャー')).toBeInTheDocument();
      });
    });

    it('should display alert list correctly', async () => {
      render(
        <TestWrapper>
          <AlertManager />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('High CPU Usage')).toBeInTheDocument();
        expect(screen.getByText('Database Connection Error')).toBeInTheDocument();
      });
    });

    it('should handle alert acknowledgment', async () => {
      render(
        <TestWrapper>
          <AlertManager />
        </TestWrapper>
      );

      await waitFor(() => {
        const acknowledgeButton = screen.getByRole('button', { name: /確認/i });
        fireEvent.click(acknowledgeButton);
      });
    });
  });

  describe('Log Viewer Integration', () => {
    it('should render log viewer with logs', async () => {
      render(
        <TestWrapper>
          <LogViewer />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('ログビューア')).toBeInTheDocument();
      });
    });

    it('should display log entries correctly', async () => {
      render(
        <TestWrapper>
          <LogViewer />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('User logged in successfully')).toBeInTheDocument();
        expect(screen.getByText('Failed to connect to external API')).toBeInTheDocument();
      });
    });

    it('should handle log filtering', async () => {
      render(
        <TestWrapper>
          <LogViewer />
        </TestWrapper>
      );

      // フィルターボタンをクリック
      fireEvent.click(screen.getByRole('button', { name: /フィルター/i }));
      
      await waitFor(() => {
        expect(screen.getByText('ログレベル')).toBeInTheDocument();
      });
    });
  });

  describe('Accessibility Integration', () => {
    it('should support keyboard navigation', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // Tab キーでナビゲーション
      const firstTab = screen.getByRole('button', { name: /📊 定期レポート/i });
      firstTab.focus();
      
      expect(document.activeElement).toBe(firstTab);
      
      // Arrow キーでタブ移動
      fireEvent.keyDown(firstTab, { key: 'ArrowRight', code: 'ArrowRight' });
      
      await waitFor(() => {
        expect(document.activeElement).toBe(screen.getByRole('button', { name: /🔍 分析レポート/i }));
      });
    });

    it('should have proper ARIA labels', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      const dailyReportButton = screen.getByRole('button', { name: /日次レポート/i });
      expect(dailyReportButton).toHaveAttribute('aria-label');
    });

    it('should support screen reader announcements', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // ライブリージョンの存在確認
      expect(screen.getByRole('status')).toBeInTheDocument();
    });
  });

  describe('Performance Optimization Integration', () => {
    it('should initialize performance monitoring correctly', () => {
      const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
      
      initializePerformanceOptimization();
      
      expect(consoleSpy).toHaveBeenCalledWith('[Performance] Optimization initialized');
      
      consoleSpy.mockRestore();
    });

    it('should handle performance metrics collection', async () => {
      // パフォーマンスメトリクスの収集をテスト
      const { PerformanceMonitor } = await import('../utils/performance');
      
      const monitor = PerformanceMonitor.getInstance();
      const metrics = monitor.getAllMetrics();
      
      expect(typeof metrics).toBe('object');
    });
  });

  describe('Security Integration', () => {
    it('should initialize security measures correctly', () => {
      const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
      
      initializeSecurity();
      
      expect(consoleSpy).toHaveBeenCalledWith('[Security] Security measures initialized');
      
      consoleSpy.mockRestore();
    });

    it('should validate input correctly', async () => {
      const { InputValidator } = await import('../utils/security');
      
      expect(InputValidator.validateEmail('test@example.com')).toBe(true);
      expect(InputValidator.validateEmail('invalid-email')).toBe(false);
    });
  });

  describe('Error Handling Integration', () => {
    it('should handle API errors gracefully', async () => {
      server.use(
        rest.get('/api/health/system', (req, res, ctx) => {
          return res(ctx.status(500), ctx.json({ error: 'Internal Server Error' }));
        })
      );

      render(
        <TestWrapper>
          <HealthMonitor />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/ヘルスモニター接続エラー/i)).toBeInTheDocument();
      });
    });

    it('should display error boundaries correctly', async () => {
      const ThrowingComponent = () => {
        throw new Error('Test error');
      };

      render(
        <TestWrapper>
          <ThrowingComponent />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/エラーが発生しました/i)).toBeInTheDocument();
      });
    });
  });

  describe('Data Integrity Tests', () => {
    it('should maintain data consistency across components', async () => {
      const { result } = renderHook(() => useAppStore(), {
        wrapper: TestWrapper,
      });

      // 初期状態の確認
      expect(result.current.user).toBeNull();
      expect(result.current.isAuthenticated).toBe(false);

      // 認証状態の更新
      act(() => {
        result.current.login({
          id: 'user-123',
          name: 'Test User',
          email: 'test@example.com',
          role: 'admin',
        });
      });

      expect(result.current.user).toBeDefined();
      expect(result.current.isAuthenticated).toBe(true);
    });

    it('should handle concurrent data updates correctly', async () => {
      render(
        <TestWrapper>
          <HealthMonitor />
        </TestWrapper>
      );

      // 複数の更新を同時実行
      const updatePromises = Array.from({ length: 5 }, () => 
        waitFor(() => screen.getByText('システム監視ダッシュボード'))
      );

      await Promise.all(updatePromises);
      
      // データの整合性を確認
      expect(screen.getByText('システム監視ダッシュボード')).toBeInTheDocument();
    });
  });

  describe('Complete User Journey Tests', () => {
    it('should complete full monitoring workflow', async () => {
      render(
        <TestWrapper>
          <MonitoringDashboard />
        </TestWrapper>
      );

      // 1. 概要ページの確認
      await waitFor(() => {
        expect(screen.getByText('システム概要')).toBeInTheDocument();
      });

      // 2. ヘルスモニターへの移動
      fireEvent.click(screen.getByRole('button', { name: /❤️ ヘルス/i }));
      
      await waitFor(() => {
        expect(screen.getByText('コンポーネント状態')).toBeInTheDocument();
      });

      // 3. パフォーマンスモニターへの移動
      fireEvent.click(screen.getByRole('button', { name: /⚡ パフォーマンス/i }));
      
      await waitFor(() => {
        expect(screen.getByText('現在のパフォーマンス')).toBeInTheDocument();
      });

      // 4. アラートマネージャーへの移動
      fireEvent.click(screen.getByRole('button', { name: /🚨 アラート/i }));
      
      await waitFor(() => {
        expect(screen.getByText('アラートマネージャー')).toBeInTheDocument();
      });

      // 5. ログビューアへの移動
      fireEvent.click(screen.getByRole('button', { name: /📋 ログ/i }));
      
      await waitFor(() => {
        expect(screen.getByText('ログビューア')).toBeInTheDocument();
      });
    });

    it('should handle complete feature execution workflow', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // 1. 機能の選択
      const dailyReportButton = screen.getByRole('button', { name: /日次レポート/i });
      
      // 2. 機能の実行
      fireEvent.click(dailyReportButton);
      
      // 3. 実行状態の確認
      await waitFor(() => {
        expect(screen.getByText(/実行中/i)).toBeInTheDocument();
      });

      // 4. 完了通知の確認
      await waitFor(() => {
        expect(screen.getByText(/完了/i)).toBeInTheDocument();
      }, { timeout: 5000 });
    });
  });

  describe('Load Testing Simulation', () => {
    it('should handle high frequency updates', async () => {
      render(
        <TestWrapper>
          <HealthMonitor />
        </TestWrapper>
      );

      // 高頻度での更新をシミュレート
      for (let i = 0; i < 10; i++) {
        fireEvent.click(screen.getByRole('button', { name: /更新/i }));
        await new Promise(resolve => setTimeout(resolve, 100));
      }

      // システムが安定していることを確認
      await waitFor(() => {
        expect(screen.getByText('システム監視ダッシュボード')).toBeInTheDocument();
      });
    });
  });
});

// パフォーマンステスト
describe('Performance Tests', () => {
  it('should render components within performance budget', async () => {
    const startTime = performance.now();
    
    render(
      <TestWrapper>
        <MainDashboard />
      </TestWrapper>
    );

    await waitFor(() => {
      expect(screen.getByText('Microsoft 365 Management Tools')).toBeInTheDocument();
    });

    const endTime = performance.now();
    const renderTime = endTime - startTime;
    
    // 100ms以内でレンダリング完了することを確認
    expect(renderTime).toBeLessThan(100);
  });

  it('should handle large datasets efficiently', async () => {
    const largeMockLogs = Array.from({ length: 1000 }, (_, index) => ({
      id: `log-${index}`,
      timestamp: new Date().toISOString(),
      level: 'info',
      message: `Log entry ${index}`,
      source: 'test',
    }));

    server.use(
      rest.get('/api/logs', (req, res, ctx) => {
        return res(ctx.json(largeMockLogs));
      })
    );

    const startTime = performance.now();
    
    render(
      <TestWrapper>
        <LogViewer />
      </TestWrapper>
    );

    await waitFor(() => {
      expect(screen.getByText('ログビューア')).toBeInTheDocument();
    });

    const endTime = performance.now();
    const renderTime = endTime - startTime;
    
    // 大量データでも500ms以内でレンダリング完了
    expect(renderTime).toBeLessThan(500);
  });
});

// 品質保証テスト
describe('Quality Assurance Tests', () => {
  it('should pass accessibility standards', async () => {
    const { container } = render(
      <TestWrapper>
        <MainDashboard />
      </TestWrapper>
    );

    await waitFor(() => {
      expect(screen.getByText('Microsoft 365 Management Tools')).toBeInTheDocument();
    });

    // アクセシビリティチェック
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('should maintain consistent styling', async () => {
    render(
      <TestWrapper>
        <MainDashboard />
      </TestWrapper>
    );

    // 一貫したスタイリングの確認
    const buttons = screen.getAllByRole('button');
    buttons.forEach(button => {
      expect(button).toHaveClass('transition-colors');
    });
  });

  it('should handle edge cases gracefully', async () => {
    // 空のレスポンス
    server.use(
      rest.get('/api/health/system', (req, res, ctx) => {
        return res(ctx.json({}));
      })
    );

    render(
      <TestWrapper>
        <HealthMonitor />
      </TestWrapper>
    );

    await waitFor(() => {
      expect(screen.getByText('システム監視ダッシュボード')).toBeInTheDocument();
    });
  });
});

// セキュリティテスト
describe('Security Tests', () => {
  it('should prevent XSS attacks', async () => {
    const maliciousScript = '<script>alert("XSS")</script>';
    
    server.use(
      rest.get('/api/logs', (req, res, ctx) => {
        return res(ctx.json([{
          id: 'log-xss',
          timestamp: new Date().toISOString(),
          level: 'error',
          message: maliciousScript,
          source: 'test',
        }]));
      })
    );

    render(
      <TestWrapper>
        <LogViewer />
      </TestWrapper>
    );

    await waitFor(() => {
      expect(screen.getByText('ログビューア')).toBeInTheDocument();
    });

    // スクリプトが実行されていないことを確認
    expect(document.querySelectorAll('script').length).toBe(0);
  });

  it('should validate input sanitization', async () => {
    const { InputValidator } = await import('../utils/security');
    
    const maliciousInput = '<script>alert("XSS")</script>';
    expect(InputValidator.validatePattern(maliciousInput, /^[a-zA-Z0-9\s]+$/)).toBe(false);
  });
});

export default {};