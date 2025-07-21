// Microsoft 365 Management Tools - 26機能 E2Eテストスイート
// PowerShell GUI 完全互換の動作確認 + Backend API統合テスト

describe('Microsoft 365 Management Tools - 26機能 E2Eテスト', () => {
  beforeEach(() => {
    // アプリケーション訪問
    cy.visit('/');
    
    // 初期読み込み完了待機
    cy.get('[data-testid="main-dashboard"]', { timeout: 10000 }).should('be.visible');
    
    // API Mock設定
    cy.setupApiMocks();
  });

  // 📊 定期レポート (5機能)
  describe('📊 定期レポート', () => {
    it('日次レポート実行', () => {
      cy.executeFeature('DailyReport');
      cy.get('[data-cy=report-output]').should('contain', '日次レポート');
    });

    it('週次レポート実行', () => {
      cy.executeFeature('WeeklyReport');
      cy.get('[data-cy=report-output]').should('contain', '週次レポート');
    });

    it('月次レポート実行', () => {
      cy.executeFeature('MonthlyReport');
      cy.get('[data-cy=report-output]').should('contain', '月次レポート');
    });

    it('年次レポート実行', () => {
      cy.executeFeature('YearlyReport');
      cy.get('[data-cy=report-output]').should('contain', '年次レポート');
    });

    it('テスト実行レポート', () => {
      cy.executeFeature('TestExecution');
      cy.get('[data-cy=report-output]').should('contain', 'テスト実行');
    });
  });

  // 🔍 分析レポート (5機能)
  describe('🔍 分析レポート', () => {
    it('ライセンス分析実行', () => {
      cy.executeFeature('LicenseAnalysis');
      cy.get('[data-cy=analysis-result]').should('contain', 'ライセンス');
    });

    it('使用状況分析実行', () => {
      cy.executeFeature('UsageAnalysis');
      cy.get('[data-cy=analysis-result]').should('contain', '使用状況');
    });

    it('パフォーマンス分析実行', () => {
      cy.executeFeature('PerformanceAnalysis');
      cy.get('[data-cy=analysis-result]').should('contain', 'パフォーマンス');
    });

    it('セキュリティ分析実行', () => {
      cy.executeFeature('SecurityAnalysis');
      cy.get('[data-cy=analysis-result]').should('contain', 'セキュリティ');
    });

    it('権限監査実行', () => {
      cy.executeFeature('PermissionAudit');
      cy.get('[data-cy=analysis-result]').should('contain', '権限監査');
    });
  });

  // 👥 Entra ID管理 (4機能)
  describe('👥 Entra ID管理', () => {
    it('ユーザー一覧取得', () => {
      cy.executeFeature('EntraUserList');
      cy.get('[data-cy=user-list]').should('be.visible');
      cy.get('[data-cy=user-item]').should('have.length.greaterThan', 0);
    });

    it('MFA状況確認', () => {
      cy.executeFeature('EntraMFAStatus');
      cy.get('[data-cy=mfa-status]').should('contain', 'MFA');
    });

    it('条件付きアクセス確認', () => {
      cy.executeFeature('EntraConditionalAccess');
      cy.get('[data-cy=conditional-access]').should('contain', '条件付きアクセス');
    });

    it('サインインログ確認', () => {
      cy.executeFeature('EntraSignInLogs');
      cy.get('[data-cy=signin-logs]').should('contain', 'サインイン');
    });
  });

  // 📧 Exchange Online管理 (4機能)
  describe('📧 Exchange Online管理', () => {
    it('メールボックス管理', () => {
      cy.executeFeature('ExchangeMailboxes');
      cy.get('[data-cy=mailbox-list]').should('be.visible');
    });

    it('メールフロー分析', () => {
      cy.executeFeature('ExchangeMailFlow');
      cy.get('[data-cy=mail-flow]').should('contain', 'メールフロー');
    });

    it('スパム対策分析', () => {
      cy.executeFeature('ExchangeSpamProtection');
      cy.get('[data-cy=spam-protection]').should('contain', 'スパム');
    });

    it('配信分析', () => {
      cy.executeFeature('ExchangeDeliveryAnalysis');
      cy.get('[data-cy=delivery-analysis]').should('contain', '配信');
    });
  });

  // 💬 Teams管理 (4機能)
  describe('💬 Teams管理', () => {
    it('Teams使用状況', () => {
      cy.executeFeature('TeamsUsage');
      cy.get('[data-cy=teams-usage]').should('contain', 'Teams');
    });

    it('Teams設定分析', () => {
      cy.executeFeature('TeamsSettings');
      cy.get('[data-cy=teams-settings]').should('contain', '設定');
    });

    it('会議品質分析', () => {
      cy.executeFeature('TeamsMeetingQuality');
      cy.get('[data-cy=meeting-quality]').should('contain', '会議品質');
    });

    it('Teamsアプリ分析', () => {
      cy.executeFeature('TeamsAppAnalysis');
      cy.get('[data-cy=teams-apps]').should('contain', 'アプリ');
    });
  });

  // 💾 OneDrive管理 (4機能)
  describe('💾 OneDrive管理', () => {
    it('ストレージ分析', () => {
      cy.executeFeature('OneDriveStorage');
      cy.get('[data-cy=storage-analysis]').should('contain', 'ストレージ');
    });

    it('共有分析', () => {
      cy.executeFeature('OneDriveSharing');
      cy.get('[data-cy=sharing-analysis]').should('contain', '共有');
    });

    it('同期エラー分析', () => {
      cy.executeFeature('OneDriveSyncErrors');
      cy.get('[data-cy=sync-errors]').should('contain', '同期エラー');
    });

    it('外部共有分析', () => {
      cy.executeFeature('OneDriveExternalSharing');
      cy.get('[data-cy=external-sharing]').should('contain', '外部共有');
    });
  });

  // 統合テスト
  describe('26機能統合テスト', () => {
    it('全機能ボタン表示確認', () => {
      cy.get('[data-cy^=feature-]').should('have.length', 26);
    });

    it('各カテゴリタブ切り替え確認', () => {
      const categories = [
        'regular-reports',
        'analysis-reports', 
        'entra-id-management',
        'exchange-management',
        'teams-management',
        'onedrive-management'
      ];

      categories.forEach((category) => {
        cy.get(`[data-cy=tab-${category}]`).click();
        cy.get(`[data-cy=category-${category}]`).should('be.visible');
      });
    });

    it('レスポンシブデザイン確認', () => {
      cy.testResponsive();
    });

    it('アクセシビリティ確認', () => {
      cy.checkAccessibility();
    });
  });
});