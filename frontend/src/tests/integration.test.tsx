// Microsoft 365 Management Tools - Integration Tests
// Frontend-Backend 統合テスト

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import { MainDashboard } from '../components/dashboard/MainDashboard';
import { AccessibilityProvider } from '../components/accessibility/AccessibilityProvider';
import { apiClient } from '../services/api';
import { useAuth, useFeatureExecution } from '../hooks/useApi';

// MSW サーバーセットアップ
const server = setupServer(
  // 認証エンドポイント
  rest.post('/api/auth/authenticate', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: {
          isAuthenticated: true,
          services: {
            graph: true,
            exchange: true,
            teams: true,
            oneDrive: true,
          },
          expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
          userInfo: {
            displayName: 'Test User',
            email: 'test@example.com',
            tenantId: 'test-tenant-id',
          },
        },
        timestamp: new Date().toISOString(),
      })
    );
  }),

  // 認証状態確認
  rest.get('/api/auth/status', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: {
          isAuthenticated: true,
          services: {
            graph: true,
            exchange: true,
            teams: true,
            oneDrive: true,
          },
          expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        },
        timestamp: new Date().toISOString(),
      })
    );
  }),

  // 機能実行エンドポイント
  rest.post('/api/features/execute', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: {
          executionId: 'test-execution-id',
          status: 'running',
          progress: 0,
          message: '実行を開始しました',
        },
        timestamp: new Date().toISOString(),
      })
    );
  }),

  // 実行状況確認
  rest.get('/api/features/execution/:executionId', (req, res, ctx) => {
    const { executionId } = req.params;
    
    return res(
      ctx.json({
        success: true,
        data: {
          executionId,
          status: 'completed',
          progress: 100,
          message: '実行が完了しました',
          outputPath: 'reports/test-report.html',
          outputUrl: '/api/reports/test-report.html',
          reportType: 'HTML',
          data: {
            recordCount: 150,
            generatedAt: new Date().toISOString(),
          },
        },
        timestamp: new Date().toISOString(),
      })
    );
  }),

  // システム状態
  rest.get('/api/system/status', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: {
          status: 'healthy',
          version: '1.0.0',
          uptime: 3600,
          services: {
            database: true,
            graph: true,
            exchange: true,
            teams: true,
            oneDrive: true,
          },
        },
        timestamp: new Date().toISOString(),
      })
    );
  }),

  // ヘルスチェック
  rest.get('/api/health', (req, res, ctx) => {
    return res(ctx.status(200), ctx.json({ status: 'ok' }));
  }),

  // レポート取得
  rest.get('/api/reports/:reportPath', (req, res, ctx) => {
    const { reportPath } = req.params;
    
    return res(
      ctx.set('Content-Type', 'text/html'),
      ctx.body(`<html><body><h1>Test Report: ${reportPath}</h1></body></html>`)
    );
  }),

  // エラーシミュレーション
  rest.post('/api/features/execute-error', (req, res, ctx) => {
    return res(
      ctx.status(500),
      ctx.json({
        success: false,
        error: 'Internal Server Error',
        message: '機能実行でエラーが発生しました',
        timestamp: new Date().toISOString(),
      })
    );
  }),

  // 認証エラー
  rest.get('/api/auth/status-error', (req, res, ctx) => {
    return res(
      ctx.status(401),
      ctx.json({
        success: false,
        error: 'Unauthorized',
        message: '認証が必要です',
        timestamp: new Date().toISOString(),
      })
    );
  })
);

// テストユーティリティ
const TestWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        staleTime: 0,
      },
      mutations: {
        retry: false,
      },
    },
  });

  return (
    <QueryClientProvider client={queryClient}>
      <AccessibilityProvider>
        {children}
      </AccessibilityProvider>
    </QueryClientProvider>
  );
};

// カスタムフック用のテストコンポーネント
const AuthTestComponent: React.FC = () => {
  const { authStatus, authenticate, isAuthenticating } = useAuth();

  return (
    <div>
      <div data-testid="auth-status">
        {authStatus?.isAuthenticated ? 'Authenticated' : 'Not Authenticated'}
      </div>
      <button
        data-testid="authenticate-button"
        onClick={() => authenticate({ interactive: true })}
        disabled={isAuthenticating}
      >
        {isAuthenticating ? 'Authenticating...' : 'Authenticate'}
      </button>
    </div>
  );
};

const FeatureExecutionTestComponent: React.FC = () => {
  const { executeFeature, isExecuting, executionStatus } = useFeatureExecution();

  return (
    <div>
      <div data-testid="execution-status">
        {executionStatus?.status || 'Not Started'}
      </div>
      <div data-testid="execution-progress">
        {executionStatus?.progress || 0}%
      </div>
      <button
        data-testid="execute-button"
        onClick={() => executeFeature({
          action: 'DailyReport',
          outputFormat: 'HTML',
        })}
        disabled={isExecuting}
      >
        {isExecuting ? 'Executing...' : 'Execute Feature'}
      </button>
    </div>
  );
};

describe('Integration Tests', () => {
  beforeAll(() => {
    server.listen();
  });

  afterEach(() => {
    server.resetHandlers();
  });

  afterAll(() => {
    server.close();
  });

  describe('Authentication Integration', () => {
    it('should authenticate successfully', async () => {
      render(
        <TestWrapper>
          <AuthTestComponent />
        </TestWrapper>
      );

      const authenticateButton = screen.getByTestId('authenticate-button');
      const authStatus = screen.getByTestId('auth-status');

      expect(authStatus).toHaveTextContent('Not Authenticated');

      fireEvent.click(authenticateButton);

      await waitFor(() => {
        expect(authStatus).toHaveTextContent('Authenticated');
      });
    });

    it('should handle authentication errors', async () => {
      server.use(
        rest.post('/api/auth/authenticate', (req, res, ctx) => {
          return res(
            ctx.status(401),
            ctx.json({
              success: false,
              error: 'Invalid credentials',
              message: '認証に失敗しました',
              timestamp: new Date().toISOString(),
            })
          );
        })
      );

      render(
        <TestWrapper>
          <AuthTestComponent />
        </TestWrapper>
      );

      const authenticateButton = screen.getByTestId('authenticate-button');
      fireEvent.click(authenticateButton);

      await waitFor(() => {
        expect(screen.getByTestId('auth-status')).toHaveTextContent('Not Authenticated');
      });
    });
  });

  describe('Feature Execution Integration', () => {
    it('should execute feature successfully', async () => {
      render(
        <TestWrapper>
          <FeatureExecutionTestComponent />
        </TestWrapper>
      );

      const executeButton = screen.getByTestId('execute-button');
      const executionStatus = screen.getByTestId('execution-status');
      const executionProgress = screen.getByTestId('execution-progress');

      expect(executionStatus).toHaveTextContent('Not Started');
      expect(executionProgress).toHaveTextContent('0%');

      fireEvent.click(executeButton);

      // 実行開始
      await waitFor(() => {
        expect(executionStatus).toHaveTextContent('running');
      });

      // 実行完了
      await waitFor(() => {
        expect(executionStatus).toHaveTextContent('completed');
        expect(executionProgress).toHaveTextContent('100%');
      });
    });

    it('should handle execution errors', async () => {
      server.use(
        rest.post('/api/features/execute', (req, res, ctx) => {
          return res(
            ctx.status(500),
            ctx.json({
              success: false,
              error: 'Execution failed',
              message: '実行に失敗しました',
              timestamp: new Date().toISOString(),
            })
          );
        })
      );

      render(
        <TestWrapper>
          <FeatureExecutionTestComponent />
        </TestWrapper>
      );

      const executeButton = screen.getByTestId('execute-button');
      fireEvent.click(executeButton);

      await waitFor(() => {
        expect(screen.getByTestId('execution-status')).toHaveTextContent('Not Started');
      });
    });
  });

  describe('Main Dashboard Integration', () => {
    it('should render dashboard and handle feature execution', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // ダッシュボードがレンダリングされる
      expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Microsoft 365統合管理ツール');

      // 機能ボタンが表示される
      const featureButtons = screen.getAllByRole('button');
      expect(featureButtons.length).toBeGreaterThan(0);

      // 機能実行
      const firstFeatureButton = featureButtons.find(button => 
        button.textContent?.includes('日次レポート')
      );
      
      if (firstFeatureButton) {
        fireEvent.click(firstFeatureButton);

        // 進捗モーダルが表示される
        await waitFor(() => {
          expect(screen.getByText('実行中...')).toBeInTheDocument();
        });
      }
    });
  });

  describe('API Client Integration', () => {
    it('should make authenticated requests', async () => {
      // 認証
      const authResponse = await apiClient.authenticate({
        interactive: true,
      });

      expect(authResponse.isAuthenticated).toBe(true);
      expect(authResponse.services.graph).toBe(true);
    });

    it('should execute features via API', async () => {
      const executionResponse = await apiClient.executeFeature({
        action: 'DailyReport',
        outputFormat: 'HTML',
      });

      expect(executionResponse.executionId).toBe('test-execution-id');
      expect(executionResponse.status).toBe('running');
    });

    it('should get execution status', async () => {
      const statusResponse = await apiClient.getExecutionStatus('test-execution-id');

      expect(statusResponse.status).toBe('completed');
      expect(statusResponse.progress).toBe(100);
    });

    it('should handle API errors', async () => {
      server.use(
        rest.get('/api/system/status', (req, res, ctx) => {
          return res(
            ctx.status(503),
            ctx.json({
              success: false,
              error: 'Service Unavailable',
              message: 'サービスが利用できません',
              timestamp: new Date().toISOString(),
            })
          );
        })
      );

      await expect(apiClient.getSystemStatus()).rejects.toThrow('サービスが利用できません');
    });
  });

  describe('Real-time Updates', () => {
    it('should update execution status in real-time', async () => {
      let executionStep = 0;

      server.use(
        rest.get('/api/features/execution/:executionId', (req, res, ctx) => {
          executionStep++;
          
          if (executionStep === 1) {
            return res(
              ctx.json({
                success: true,
                data: {
                  executionId: 'test-execution-id',
                  status: 'running',
                  progress: 25,
                  message: 'データを取得中...',
                },
                timestamp: new Date().toISOString(),
              })
            );
          } else if (executionStep === 2) {
            return res(
              ctx.json({
                success: true,
                data: {
                  executionId: 'test-execution-id',
                  status: 'running',
                  progress: 75,
                  message: 'レポートを生成中...',
                },
                timestamp: new Date().toISOString(),
              })
            );
          } else {
            return res(
              ctx.json({
                success: true,
                data: {
                  executionId: 'test-execution-id',
                  status: 'completed',
                  progress: 100,
                  message: '完了しました',
                  outputPath: 'reports/test-report.html',
                  outputUrl: '/api/reports/test-report.html',
                },
                timestamp: new Date().toISOString(),
              })
            );
          }
        })
      );

      render(
        <TestWrapper>
          <FeatureExecutionTestComponent />
        </TestWrapper>
      );

      const executeButton = screen.getByTestId('execute-button');
      fireEvent.click(executeButton);

      // 初期状態
      await waitFor(() => {
        expect(screen.getByTestId('execution-progress')).toHaveTextContent('25%');
      });

      // 進行状態
      await waitFor(() => {
        expect(screen.getByTestId('execution-progress')).toHaveTextContent('75%');
      });

      // 完了状態
      await waitFor(() => {
        expect(screen.getByTestId('execution-progress')).toHaveTextContent('100%');
        expect(screen.getByTestId('execution-status')).toHaveTextContent('completed');
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle network errors gracefully', async () => {
      server.use(
        rest.get('/api/auth/status', (req, res, ctx) => {
          return res.networkError('Network error');
        })
      );

      await expect(apiClient.checkAuthStatus()).rejects.toThrow();
    });

    it('should handle timeout errors', async () => {
      server.use(
        rest.get('/api/auth/status', (req, res, ctx) => {
          return res(ctx.delay(35000)); // 35秒遅延（タイムアウト）
        })
      );

      await expect(apiClient.checkAuthStatus()).rejects.toThrow();
    });
  });

  describe('Performance Integration', () => {
    it('should handle concurrent requests efficiently', async () => {
      const promises = Array.from({ length: 10 }, (_, i) =>
        apiClient.executeFeature({
          action: 'TestAction',
          parameters: { index: i },
        })
      );

      const results = await Promise.all(promises);
      expect(results).toHaveLength(10);
      results.forEach(result => {
        expect(result.executionId).toBeDefined();
      });
    });
  });
});

// カスタムマッチャー
expect.extend({
  toBeWithinRange(received: number, floor: number, ceiling: number) {
    const pass = received >= floor && received <= ceiling;
    
    if (pass) {
      return {
        message: () => `expected ${received} not to be within range ${floor} - ${ceiling}`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be within range ${floor} - ${ceiling}`,
        pass: false,
      };
    }
  },
});

declare global {
  namespace jest {
    interface Matchers<R> {
      toBeWithinRange(floor: number, ceiling: number): R;
    }
  }
}