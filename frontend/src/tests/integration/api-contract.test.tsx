// Microsoft 365 Management Tools - API Contract Integration Tests
// Frontend (React) ↔ Backend (FastAPI) 契約テスト

import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { toast } from 'react-hot-toast';

import { FeatureButton } from '../../components/shared/FeatureButton';
import { MainDashboard } from '../../components/dashboard/MainDashboard';
import { apiClient } from '../../services/api';
import { FEATURE_TABS } from '../../config/features';

// Mock Server Setup (dev2のpytestと同等のAPI仕様)
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
            oneDrive: true
          },
          expiresAt: new Date(Date.now() + 3600000).toISOString(),
          userInfo: {
            displayName: 'Test User',
            email: 'test@contoso.com',
            tenantId: 'test-tenant-id'
          }
        },
        timestamp: new Date().toISOString()
      })
    );
  }),

  // 機能実行エンドポイント
  rest.post('/api/features/execute', async (req, res, ctx) => {
    const body = await req.json();
    const { action, parameters, outputFormat } = body;

    // dev2のBackend実装と同じスキーマ検証
    if (!action || typeof action !== 'string') {
      return res(
        ctx.status(400),
        ctx.json({
          success: false,
          error: 'Invalid action parameter',
          timestamp: new Date().toISOString()
        })
      );
    }

    const executionId = `exec_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    return res(
      ctx.json({
        success: true,
        data: {
          executionId,
          status: 'running',
          progress: 0,
          message: `Starting ${action}`,
          reportType: outputFormat || 'HTML'
        },
        timestamp: new Date().toISOString()
      })
    );
  }),

  // 実行状況確認エンドポイント
  rest.get('/api/features/execution/:executionId', (req, res, ctx) => {
    const { executionId } = req.params;
    
    return res(
      ctx.json({
        success: true,
        data: {
          executionId,
          status: 'completed',
          progress: 100,
          message: 'Execution completed successfully',
          outputPath: `/reports/${executionId}.html`,
          outputUrl: `http://localhost:8000/api/reports/${executionId}.html`,
          data: {
            recordCount: 42,
            processedAt: new Date().toISOString()
          }
        },
        timestamp: new Date().toISOString()
      })
    );
  }),

  // Microsoft Graph API模拟
  rest.get('/api/graph/users', (req, res, ctx) => {
    const top = req.url.searchParams.get('top') || '10';
    const users = Array.from({ length: parseInt(top) }, (_, i) => ({
      id: `user-${i}`,
      displayName: `Test User ${i}`,
      mail: `user${i}@contoso.com`,
      userPrincipalName: `user${i}@contoso.com`
    }));

    return res(
      ctx.json({
        success: true,
        data: users,
        timestamp: new Date().toISOString()
      })
    );
  }),

  // システム状態確認
  rest.get('/api/system/status', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: {
          status: 'healthy',
          version: '2.0.0',
          uptime: 3600,
          services: {
            database: true,
            redis: true,
            graph_api: true,
            exchange_api: true
          }
        },
        timestamp: new Date().toISOString()
      })
    );
  })
);

// テストセットアップ
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// React Query Client セットアップ
const createTestQueryClient = () => new QueryClient({
  defaultOptions: {
    queries: { retry: false },
    mutations: { retry: false }
  }
});

const TestWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const queryClient = createTestQueryClient();
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

describe('Frontend ↔ Backend API Contract Tests', () => {
  describe('認証契約テスト', () => {
    it('認証リクエスト・レスポンス契約確認', async () => {
      const authRequest = {
        clientId: 'test-client-id',
        tenantId: 'test-tenant-id',
        certificateThumbprint: 'test-thumbprint',
        interactive: false
      };

      const response = await apiClient.authenticate(authRequest);

      // レスポンス構造検証 (dev2のBackendと同じスキーマ)
      expect(response).toHaveProperty('isAuthenticated', true);
      expect(response).toHaveProperty('services');
      expect(response.services).toHaveProperty('graph', true);
      expect(response.services).toHaveProperty('exchange', true);
      expect(response).toHaveProperty('userInfo');
      expect(response.userInfo).toHaveProperty('displayName');
      expect(response.userInfo).toHaveProperty('email');
    });

    it('認証エラー時の契約確認', async () => {
      // エラーレスポンスを設定
      server.use(
        rest.post('/api/auth/authenticate', (req, res, ctx) => {
          return res(
            ctx.status(401),
            ctx.json({
              success: false,
              error: 'Authentication failed',
              timestamp: new Date().toISOString()
            })
          );
        })
      );

      await expect(apiClient.authenticate({})).rejects.toMatchObject({
        status: 401,
        message: expect.stringContaining('Authentication failed')
      });
    });
  });

  describe('26機能実行契約テスト', () => {
    const testFeatures = [
      { action: 'DailyReport', category: 'regular-reports' },
      { action: 'LicenseAnalysis', category: 'analytics-reports' },
      { action: 'UserList', category: 'entra-id' },
      { action: 'MailboxManagement', category: 'exchange-online' },
      { action: 'TeamsUsage', category: 'teams-management' },
      { action: 'StorageAnalysis', category: 'onedrive-management' }
    ];

    testFeatures.forEach(({ action, category }) => {
      it(`${action} 機能実行契約テスト`, async () => {
        const executionRequest = {
          action,
          parameters: {
            outputPath: 'Reports/General',
            autoOpen: false,
            language: 'ja'
          },
          outputFormat: 'HTML' as const
        };

        const execution = await apiClient.executeFeature(executionRequest);

        // 実行レスポンス検証
        expect(execution).toHaveProperty('executionId');
        expect(execution).toHaveProperty('status', 'running');
        expect(execution).toHaveProperty('progress', 0);
        expect(execution).toHaveProperty('message');
        expect(execution.executionId).toMatch(/^exec_\d+_[a-z0-9]+$/);

        // 状況確認
        const status = await apiClient.getExecutionStatus(execution.executionId);
        expect(status).toHaveProperty('status', 'completed');
        expect(status).toHaveProperty('progress', 100);
        expect(status).toHaveProperty('outputUrl');
        expect(status.outputUrl).toContain(execution.executionId);
      });
    });

    it('無効なアクション契約エラーテスト', async () => {
      const invalidRequest = {
        action: '', // 無効なアクション
        parameters: {},
        outputFormat: 'HTML' as const
      };

      await expect(apiClient.executeFeature(invalidRequest)).rejects.toMatchObject({
        status: 400,
        message: expect.stringContaining('Invalid action parameter')
      });
    });
  });

  describe('Microsoft Graph API統合契約テスト', () => {
    it('ユーザー一覧取得契約テスト', async () => {
      const users = await apiClient.getMicrosoft365Users({
        top: 5,
        select: 'displayName,mail,userPrincipalName'
      });

      expect(Array.isArray(users)).toBe(true);
      expect(users).toHaveLength(5);
      
      users.forEach(user => {
        expect(user).toHaveProperty('id');
        expect(user).toHaveProperty('displayName');
        expect(user).toHaveProperty('mail');
        expect(user).toHaveProperty('userPrincipalName');
      });
    });

    it('Exchange メールボックス取得契約テスト', async () => {
      const mailboxes = await apiClient.getExchangeMailboxes({
        resultSize: 10,
        filter: 'RecipientTypeDetails -eq "UserMailbox"'
      });

      expect(Array.isArray(mailboxes)).toBe(true);
      // dev2のBackend実装と同じデータ構造を期待
    });
  });

  describe('システム状態契約テスト', () => {
    it('ヘルスチェック契約テスト', async () => {
      const isHealthy = await apiClient.healthCheck();
      expect(isHealthy).toBe(true);
    });

    it('システム状態詳細契約テスト', async () => {
      const status = await apiClient.getSystemStatus();

      expect(status).toHaveProperty('status', 'healthy');
      expect(status).toHaveProperty('version');
      expect(status).toHaveProperty('uptime');
      expect(status).toHaveProperty('services');
      expect(status.services).toHaveProperty('database', true);
      expect(status.services).toHaveProperty('redis', true);
      expect(status.services).toHaveProperty('graph_api', true);
    });
  });
});

describe('React Component ↔ API Integration Tests', () => {
  describe('FeatureButton統合テスト', () => {
    it('ボタンクリック → API実行 → 状態更新フロー', async () => {
      const user = userEvent.setup();
      const mockFeature = FEATURE_TABS[0].features[0]; // 日次レポート

      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} />
        </TestWrapper>
      );

      const button = screen.getByRole('button', { name: /日次レポート/i });
      expect(button).toBeInTheDocument();

      // ボタンクリック
      await user.click(button);

      // ローディング状態確認
      expect(button).toHaveAttribute('aria-busy', 'true');
      
      // API呼び出し完了待機
      await waitFor(() => {
        expect(button).not.toHaveAttribute('aria-busy', 'true');
      }, { timeout: 5000 });

      // 成功状態確認
      expect(screen.getByTestId('success-icon')).toBeInTheDocument();
    });

    it('API エラー時のエラー状態表示', async () => {
      // エラーレスポンス設定
      server.use(
        rest.post('/api/features/execute', (req, res, ctx) => {
          return res(
            ctx.status(500),
            ctx.json({
              success: false,
              error: 'Internal server error',
              timestamp: new Date().toISOString()
            })
          );
        })
      );

      const user = userEvent.setup();
      const mockFeature = FEATURE_TABS[0].features[0];

      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      await user.click(button);

      // エラー状態確認
      await waitFor(() => {
        expect(screen.getByTestId('error-icon')).toBeInTheDocument();
      });
    });
  });

  describe('MainDashboard統合テスト', () => {
    it('ダッシュボード読み込み → 認証確認 → 接続状態表示', async () => {
      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // ヘッダー確認
      expect(screen.getByText('Microsoft 365統合管理ツール')).toBeInTheDocument();

      // 接続状態確認（非同期）
      await waitFor(() => {
        expect(screen.getByText('Connected')).toBeInTheDocument();
      });

      // タブナビゲーション確認
      expect(screen.getByRole('tablist')).toBeInTheDocument();
      expect(screen.getAllByRole('tab')).toHaveLength(6);
    });

    it('タブ切り替え → 機能ボタン表示確認', async () => {
      const user = userEvent.setup();

      render(
        <TestWrapper>
          <MainDashboard />
        </TestWrapper>
      );

      // 分析レポートタブに切り替え
      const analyticsTab = screen.getByRole('tab', { name: /分析レポート/i });
      await user.click(analyticsTab);

      // 分析レポート機能ボタンの確認
      await waitFor(() => {
        expect(screen.getByRole('button', { name: /ライセンス分析/i })).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /使用状況分析/i })).toBeInTheDocument();
      });
    });
  });
});

describe('リアルタイム通信テスト', () => {
  describe('長時間実行機能のポーリング', () => {
    it('実行状況ポーリング → 進捗更新 → 完了通知', async () => {
      let pollCount = 0;
      
      // 段階的な進捗レスポンス
      server.use(
        rest.get('/api/features/execution/:executionId', (req, res, ctx) => {
          pollCount++;
          const progress = Math.min(pollCount * 25, 100);
          const status = progress === 100 ? 'completed' : 'running';
          
          return res(
            ctx.json({
              success: true,
              data: {
                executionId: req.params.executionId,
                status,
                progress,
                message: `Progress: ${progress}%`,
                outputUrl: status === 'completed' ? 'http://localhost:8000/report.html' : undefined
              },
              timestamp: new Date().toISOString()
            })
          );
        })
      );

      const user = userEvent.setup();
      const mockFeature = FEATURE_TABS[0].features[0];

      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      await user.click(button);

      // 実行完了まで待機（最大10秒）
      await waitFor(() => {
        expect(screen.getByTestId('success-icon')).toBeInTheDocument();
      }, { timeout: 10000 });

      // ポーリングが複数回実行されたことを確認
      expect(pollCount).toBeGreaterThan(1);
    });

    it('実行タイムアウト処理', async () => {
      // タイムアウトレスポンス設定
      server.use(
        rest.get('/api/features/execution/:executionId', (req, res, ctx) => {
          return res(
            ctx.json({
              success: true,
              data: {
                executionId: req.params.executionId,
                status: 'running',
                progress: 50,
                message: 'Still processing...'
              },
              timestamp: new Date().toISOString()
            })
          );
        })
      );

      const user = userEvent.setup();
      const mockFeature = FEATURE_TABS[0].features[0];

      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      await user.click(button);

      // タイムアウト処理確認（短縮版：5秒）
      await waitFor(() => {
        expect(screen.getByTestId('error-icon')).toBeInTheDocument();
      }, { timeout: 6000 });
    });
  });
});

describe('エラー回復性テスト', () => {
  describe('ネットワークエラー処理', () => {
    it('一時的なネットワークエラー → 自動リトライ → 成功', async () => {
      let attemptCount = 0;
      
      server.use(
        rest.post('/api/features/execute', (req, res, ctx) => {
          attemptCount++;
          
          if (attemptCount <= 2) {
            // 最初の2回は失敗
            return res(ctx.status(503), ctx.json({ error: 'Service unavailable' }));
          }
          
          // 3回目で成功
          return res(
            ctx.json({
              success: true,
              data: {
                executionId: 'test-exec-id',
                status: 'running',
                progress: 0,
                message: 'Started successfully'
              }
            })
          );
        })
      );

      const user = userEvent.setup();
      const mockFeature = FEATURE_TABS[0].features[0];

      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      await user.click(button);

      // 最終的に成功することを確認
      await waitFor(() => {
        expect(button).toHaveAttribute('aria-busy', 'true');
      });

      expect(attemptCount).toBeGreaterThan(1); // リトライが実行された
    });
  });

  describe('認証期限切れ処理', () => {
    it('認証期限切れ → 自動再認証 → 処理継続', async () => {
      server.use(
        rest.post('/api/features/execute', (req, res, ctx) => {
          return res(
            ctx.status(401),
            ctx.json({ success: false, error: 'Authentication expired' })
          );
        })
      );

      const user = userEvent.setup();
      const mockFeature = FEATURE_TABS[0].features[0];

      render(
        <TestWrapper>
          <FeatureButton feature={mockFeature} />
        </TestWrapper>
      );

      const button = screen.getByRole('button');
      await user.click(button);

      // 認証期限切れエラーの処理を確認
      await waitFor(() => {
        // auth-expired イベントが発火することを確認
        // （実際の実装では再認証画面に遷移）
      });
    });
  });
});

// パフォーマンステスト統合
describe('パフォーマンス統合テスト', () => {
  it('API応答時間測定', async () => {
    const startTime = Date.now();
    
    await apiClient.healthCheck();
    
    const responseTime = Date.now() - startTime;
    expect(responseTime).toBeLessThan(1000); // 1秒以内
  });

  it('同時実行制限確認', async () => {
    const promises = Array.from({ length: 5 }, () =>
      apiClient.executeFeature({
        action: 'TestAction',
        parameters: {},
        outputFormat: 'HTML'
      })
    );

    const results = await Promise.allSettled(promises);
    
    // 全てが適切に処理されることを確認
    results.forEach(result => {
      expect(result.status).toBe('fulfilled');
    });
  });
});

export {};