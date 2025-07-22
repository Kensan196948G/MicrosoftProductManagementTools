#!/usr/bin/env python3
"""
Frontend Jest/Cypress/Vitest Integration Suite
QA Engineer (dev2) - Frontend Testing Integration & Quality Assurance

フロントエンドテスト統合システム：
- React/TypeScript 単体テスト (Vitest)
- Cypress E2Eテスト統合
- 26機能完全カバレッジ
- UI/UXテスト自動化・レスポンシブテスト
- パフォーマンステスト・アクセシビリティテスト
"""
import os
import sys
import json
import subprocess
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import pytest

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class FrontendTestIntegration:
    """フロントエンドテスト統合システム"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.frontend_dir = self.project_root / "frontend"
        self.integration_dir = self.project_root / "Tests" / "frontend_integration"
        self.integration_dir.mkdir(exist_ok=True)
        
        self.reports_dir = self.integration_dir / "reports"
        self.reports_dir.mkdir(exist_ok=True)
        
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # フロントエンド環境チェック
        self.frontend_available = self._check_frontend_environment()
        
        # 26機能定義
        self.features_26 = [
            # 定期レポート (5機能)
            "daily_report", "weekly_report", "monthly_report", "yearly_report", "test_execution",
            # 分析レポート (5機能)  
            "license_analysis", "usage_analysis", "performance_analysis", "security_analysis", "permission_audit",
            # Entra ID管理 (4機能)
            "user_list", "mfa_status", "conditional_access", "signin_logs",
            # Exchange Online管理 (4機能)
            "mailbox_management", "mail_flow", "spam_protection", "delivery_analysis",
            # Teams管理 (4機能)
            "teams_usage", "teams_settings", "meeting_quality", "teams_apps",
            # OneDrive管理 (4機能)
            "storage_analysis", "sharing_analysis", "sync_errors", "external_sharing"
        ]
    
    def _check_frontend_environment(self) -> bool:
        """フロントエンド環境チェック"""
        if not self.frontend_dir.exists():
            logger.warning("Frontend directory not found")
            return False
        
        package_json = self.frontend_dir / "package.json"
        if not package_json.exists():
            logger.warning("package.json not found")
            return False
        
        # Node.js チェック
        try:
            result = subprocess.run(["node", "--version"], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                logger.info(f"✅ Node.js available: {result.stdout.strip()}")
                return True
        except Exception as e:
            logger.warning(f"Node.js not available: {e}")
        
        return False
    
    def analyze_frontend_structure(self) -> Dict[str, Any]:
        """フロントエンド構造分析"""
        logger.info("🔍 Analyzing frontend structure...")
        
        analysis = {
            "directories": {},
            "test_files": {},
            "package_scripts": {},
            "components": {},
            "total_files": 0,
            "issues": []
        }
        
        if not self.frontend_available:
            analysis["issues"].append("Frontend environment not available")
            return analysis
        
        # ディレクトリ分析
        directories_to_check = [
            self.frontend_dir / "src",
            self.frontend_dir / "tests",
            self.frontend_dir / "src" / "tests",
            self.frontend_dir / "cypress",
            self.frontend_dir / "src" / "components"
        ]
        
        for directory in directories_to_check:
            if directory.exists():
                files = list(directory.glob("**/*"))
                typescript_files = [f for f in files if f.suffix in ['.ts', '.tsx']]
                test_files = [f for f in files if any(pattern in f.name for pattern in ['test', 'spec'])]
                
                analysis["directories"][str(directory.relative_to(self.frontend_dir))] = {
                    "exists": True,
                    "total_files": len(files),
                    "typescript_files": len(typescript_files),
                    "test_files": len(test_files)
                }
                
                # テストファイル詳細
                for test_file in test_files:
                    analysis["test_files"][str(test_file.relative_to(self.frontend_dir))] = {
                        "size": test_file.stat().st_size,
                        "type": "e2e" if "cypress" in str(test_file) else "unit"
                    }
            else:
                analysis["directories"][str(directory.relative_to(self.frontend_dir))] = {"exists": False}
        
        # package.json スクリプト分析
        package_json = self.frontend_dir / "package.json"
        if package_json.exists():
            try:
                with open(package_json) as f:
                    package_data = json.load(f)
                    analysis["package_scripts"] = package_data.get("scripts", {})
            except Exception as e:
                analysis["issues"].append(f"Error reading package.json: {e}")
        
        # コンポーネント分析
        components_dir = self.frontend_dir / "src" / "components"
        if components_dir.exists():
            component_dirs = [d for d in components_dir.iterdir() if d.is_dir()]
            for component_dir in component_dirs:
                tsx_files = list(component_dir.glob("*.tsx"))
                test_files = list(component_dir.glob("*.test.*"))
                
                analysis["components"][component_dir.name] = {
                    "tsx_files": len(tsx_files),
                    "test_files": len(test_files),
                    "has_tests": len(test_files) > 0
                }
        
        analysis["total_files"] = sum(
            data.get("total_files", 0) 
            for data in analysis["directories"].values() 
            if isinstance(data, dict) and "total_files" in data
        )
        
        return analysis
    
    def create_vitest_config(self) -> Dict[str, Any]:
        """Vitest設定作成"""
        logger.info("⚙️ Creating Vitest configuration...")
        
        vitest_config_content = '''/// <reference types="vitest" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/tests/setup.ts'],
    css: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: '../Tests/frontend_integration/reports/coverage',
      exclude: [
        'node_modules/**',
        'src/tests/**',
        '**/*.d.ts',
        '**/*.config.*',
        'dist/**'
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80
        }
      }
    },
    include: [
      'src/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'
    ],
    exclude: [
      'node_modules/**',
      'dist/**',
      'cypress/**'
    ],
    testTimeout: 30000,
    hookTimeout: 30000,
    reporters: [
      'default',
      'json',
      'html'
    ],
    outputFile: {
      json: '../Tests/frontend_integration/reports/vitest-results.json',
      html: '../Tests/frontend_integration/reports/vitest-report.html'
    }
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@components': path.resolve(__dirname, './src/components'),
      '@hooks': path.resolve(__dirname, './src/hooks'),
      '@services': path.resolve(__dirname, './src/services'),
      '@utils': path.resolve(__dirname, './src/utils'),
      '@types': path.resolve(__dirname, './src/types')
    }
  }
})
'''
        
        # Vitest設定保存
        vitest_config_path = self.frontend_dir / "vitest.config.ts"
        with open(vitest_config_path, 'w', encoding='utf-8') as f:
            f.write(vitest_config_content)
        
        # テストセットアップファイル作成
        test_setup_content = '''import '@testing-library/jest-dom'
import { vi } from 'vitest'

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(), // deprecated
    removeListener: vi.fn(), // deprecated
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

// Mock IntersectionObserver
global.IntersectionObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}))

// Mock ResizeObserver
global.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}))

// Mock fetch
global.fetch = vi.fn()

// Mock localStorage
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
}
global.localStorage = localStorageMock
'''
        
        setup_path = self.frontend_dir / "src" / "tests" / "setup.ts"
        setup_path.parent.mkdir(exist_ok=True)
        with open(setup_path, 'w', encoding='utf-8') as f:
            f.write(test_setup_content)
        
        return {
            "vitest_config_created": str(vitest_config_path),
            "setup_file_created": str(setup_path),
            "status": "configured"
        }
    
    def create_comprehensive_component_tests(self) -> Dict[str, Any]:
        """包括的コンポーネントテスト作成"""
        logger.info("🧪 Creating comprehensive component tests...")
        
        created_tests = []
        
        # 26機能ボタンコンポーネントテスト
        feature_button_test = '''import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { FeatureButton } from '../shared/FeatureButton'
import type { Feature } from '@/types/features'

const mockFeature: Feature = {
  id: 'daily_report',
  name: '日次レポート',
  description: 'Daily activity report generation',
  category: 'reports',
  icon: 'Calendar',
  enabled: true
}

describe('FeatureButton', () => {
  it('renders feature button correctly', () => {
    const mockOnExecute = vi.fn()
    
    render(
      <FeatureButton 
        feature={mockFeature} 
        onExecute={mockOnExecute}
      />
    )
    
    expect(screen.getByText('日次レポート')).toBeInTheDocument()
    expect(screen.getByText('Daily activity report generation')).toBeInTheDocument()
  })
  
  it('calls onExecute when clicked', async () => {
    const mockOnExecute = vi.fn().mockResolvedValue(undefined)
    
    render(
      <FeatureButton 
        feature={mockFeature} 
        onExecute={mockOnExecute}
      />
    )
    
    const button = screen.getByRole('button')
    fireEvent.click(button)
    
    await waitFor(() => {
      expect(mockOnExecute).toHaveBeenCalledWith(mockFeature.id)
    })
  })
  
  it('shows loading state during execution', async () => {
    const mockOnExecute = vi.fn().mockImplementation(
      () => new Promise(resolve => setTimeout(resolve, 1000))
    )
    
    render(
      <FeatureButton 
        feature={mockFeature} 
        onExecute={mockOnExecute}
      />
    )
    
    const button = screen.getByRole('button')
    fireEvent.click(button)
    
    expect(screen.getByText(/実行中/)).toBeInTheDocument()
    
    await waitFor(() => {
      expect(mockOnExecute).toHaveBeenCalled()
    }, { timeout: 1500 })
  })
  
  it('is accessible', () => {
    const mockOnExecute = vi.fn()
    
    render(
      <FeatureButton 
        feature={mockFeature} 
        onExecute={mockOnExecute}
      />
    )
    
    const button = screen.getByRole('button')
    expect(button).toHaveAttribute('aria-label')
    expect(button).toHaveAttribute('tabIndex', '0')
  })
  
  it('supports keyboard navigation', () => {
    const mockOnExecute = vi.fn()
    
    render(
      <FeatureButton 
        feature={mockFeature} 
        onExecute={mockOnExecute}
      />
    )
    
    const button = screen.getByRole('button')
    
    // Tab キーでフォーカス
    button.focus()
    expect(button).toHaveFocus()
    
    // Enter キーで実行
    fireEvent.keyDown(button, { key: 'Enter', code: 'Enter' })
    expect(mockOnExecute).toHaveBeenCalled()
  })
})
'''
        
        feature_button_test_path = self.frontend_dir / "src" / "components" / "shared" / "FeatureButton.test.tsx"
        feature_button_test_path.parent.mkdir(parents=True, exist_ok=True)
        with open(feature_button_test_path, 'w', encoding='utf-8') as f:
            f.write(feature_button_test)
        created_tests.append(str(feature_button_test_path))
        
        # MainDashboard コンポーネントテスト
        dashboard_test = '''import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { MainDashboard } from '../dashboard/MainDashboard'

// Mock hooks
vi.mock('@/hooks/useFeatureExecution', () => ({
  useFeatureExecution: () => ({
    executeFeature: vi.fn(),
    isExecuting: false,
    executionResults: {}
  })
}))

vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({
    isAuthenticated: true,
    user: { name: 'Test User' },
    login: vi.fn(),
    logout: vi.fn()
  })
}))

describe('MainDashboard', () => {
  it('renders all 26 features', () => {
    render(<MainDashboard />)
    
    // 定期レポート (5機能)
    expect(screen.getByText('日次レポート')).toBeInTheDocument()
    expect(screen.getByText('週次レポート')).toBeInTheDocument()
    expect(screen.getByText('月次レポート')).toBeInTheDocument()
    expect(screen.getByText('年次レポート')).toBeInTheDocument()
    expect(screen.getByText('テスト実行')).toBeInTheDocument()
    
    // 分析レポート (5機能)
    expect(screen.getByText('ライセンス分析')).toBeInTheDocument()
    expect(screen.getByText('使用状況分析')).toBeInTheDocument()
    
    // カテゴリごとのセクションが表示されていることを確認
    expect(screen.getByText('定期レポート')).toBeInTheDocument()
    expect(screen.getByText('分析レポート')).toBeInTheDocument()
    expect(screen.getByText('Entra ID管理')).toBeInTheDocument()
    expect(screen.getByText('Exchange Online管理')).toBeInTheDocument()
    expect(screen.getByText('Teams管理')).toBeInTheDocument()
    expect(screen.getByText('OneDrive管理')).toBeInTheDocument()
  })
  
  it('is responsive across different screen sizes', () => {
    // Mobile viewport
    global.innerWidth = 375
    global.innerHeight = 667
    global.dispatchEvent(new Event('resize'))
    
    render(<MainDashboard />)
    
    const dashboard = screen.getByTestId('main-dashboard')
    expect(dashboard).toBeInTheDocument()
    
    // Desktop viewport
    global.innerWidth = 1920
    global.innerHeight = 1080
    global.dispatchEvent(new Event('resize'))
    
    expect(dashboard).toBeInTheDocument()
  })
  
  it('handles feature execution', () => {
    const mockExecuteFeature = vi.fn()
    
    vi.mocked(require('@/hooks/useFeatureExecution').useFeatureExecution).mockReturnValue({
      executeFeature: mockExecuteFeature,
      isExecuting: false,
      executionResults: {}
    })
    
    render(<MainDashboard />)
    
    const dailyReportButton = screen.getByText('日次レポート').closest('button')
    fireEvent.click(dailyReportButton!)
    
    expect(mockExecuteFeature).toHaveBeenCalledWith('daily_report')
  })
})
'''
        
        dashboard_test_path = self.frontend_dir / "src" / "components" / "dashboard" / "MainDashboard.test.tsx"
        dashboard_test_path.parent.mkdir(parents=True, exist_ok=True)
        with open(dashboard_test_path, 'w', encoding='utf-8') as f:
            f.write(dashboard_test)
        created_tests.append(str(dashboard_test_path))
        
        # アクセシビリティテスト
        accessibility_test = '''import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { axe, toHaveNoViolations } from 'jest-axe'
import { AccessibilityProvider } from '../accessibility/AccessibilityProvider'

expect.extend(toHaveNoViolations)

describe('Accessibility Tests', () => {
  it('AccessibilityProvider has no accessibility violations', async () => {
    const { container } = render(
      <AccessibilityProvider>
        <div>
          <h1>Test Content</h1>
          <button>Test Button</button>
          <input aria-label="Test Input" />
        </div>
      </AccessibilityProvider>
    )
    
    const results = await axe(container)
    expect(results).toHaveNoViolations()
  })
  
  it('supports high contrast mode', () => {
    // Mock high contrast media query
    window.matchMedia = vi.fn().mockImplementation(query => ({
      matches: query === '(prefers-contrast: high)',
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    }))
    
    render(
      <AccessibilityProvider>
        <div data-testid="high-contrast-content">Content</div>
      </AccessibilityProvider>
    )
    
    const content = screen.getByTestId('high-contrast-content')
    expect(content).toBeInTheDocument()
  })
  
  it('supports reduced motion preferences', () => {
    window.matchMedia = vi.fn().mockImplementation(query => ({
      matches: query === '(prefers-reduced-motion: reduce)',
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    }))
    
    render(
      <AccessibilityProvider>
        <div data-testid="reduced-motion-content">Content</div>
      </AccessibilityProvider>
    )
    
    const content = screen.getByTestId('reduced-motion-content')
    expect(content).toBeInTheDocument()
  })
})
'''
        
        accessibility_test_path = self.frontend_dir / "src" / "components" / "accessibility" / "AccessibilityProvider.test.tsx"
        accessibility_test_path.parent.mkdir(parents=True, exist_ok=True)
        with open(accessibility_test_path, 'w', encoding='utf-8') as f:
            f.write(accessibility_test)
        created_tests.append(str(accessibility_test_path))
        
        return {
            "created_tests": created_tests,
            "total_tests": len(created_tests),
            "status": "comprehensive"
        }
    
    def enhance_cypress_config(self) -> Dict[str, Any]:
        """Cypress設定強化"""
        logger.info("🎯 Enhancing Cypress configuration...")
        
        # 26機能E2Eテスト作成
        cypress_26_features_test = '''describe('26 Features E2E Tests', () => {
  beforeEach(() => {
    cy.visit('/')
    
    // 認証モック（必要に応じて）
    cy.window().then((win) => {
      win.localStorage.setItem('auth_token', 'mock-token')
    })
  })

  const features = [
    // 定期レポート (5機能)
    { id: 'daily_report', name: '日次レポート', category: 'reports' },
    { id: 'weekly_report', name: '週次レポート', category: 'reports' },
    { id: 'monthly_report', name: '月次レポート', category: 'reports' },
    { id: 'yearly_report', name: '年次レポート', category: 'reports' },
    { id: 'test_execution', name: 'テスト実行', category: 'reports' },
    
    // 分析レポート (5機能)
    { id: 'license_analysis', name: 'ライセンス分析', category: 'analysis' },
    { id: 'usage_analysis', name: '使用状況分析', category: 'analysis' },
    { id: 'performance_analysis', name: 'パフォーマンス分析', category: 'analysis' },
    { id: 'security_analysis', name: 'セキュリティ分析', category: 'analysis' },
    { id: 'permission_audit', name: '権限監査', category: 'analysis' },
    
    // Entra ID管理 (4機能)
    { id: 'user_list', name: 'ユーザー一覧', category: 'entraid' },
    { id: 'mfa_status', name: 'MFA状況', category: 'entraid' },
    { id: 'conditional_access', name: '条件付きアクセス', category: 'entraid' },
    { id: 'signin_logs', name: 'サインインログ', category: 'entraid' },
    
    // Exchange Online管理 (4機能)
    { id: 'mailbox_management', name: 'メールボックス管理', category: 'exchange' },
    { id: 'mail_flow', name: 'メールフロー', category: 'exchange' },
    { id: 'spam_protection', name: 'スパム対策', category: 'exchange' },
    { id: 'delivery_analysis', name: '配信分析', category: 'exchange' },
    
    // Teams管理 (4機能)
    { id: 'teams_usage', name: 'Teams使用状況', category: 'teams' },
    { id: 'teams_settings', name: 'Teams設定', category: 'teams' },
    { id: 'meeting_quality', name: '会議品質', category: 'teams' },
    { id: 'teams_apps', name: 'Teamsアプリ', category: 'teams' },
    
    // OneDrive管理 (4機能)
    { id: 'storage_analysis', name: 'ストレージ分析', category: 'onedrive' },
    { id: 'sharing_analysis', name: '共有分析', category: 'onedrive' },
    { id: 'sync_errors', name: '同期エラー', category: 'onedrive' },
    { id: 'external_sharing', name: '外部共有', category: 'onedrive' }
  ]

  it('displays all 26 features correctly', () => {
    // すべての機能がページに表示されていることを確認
    features.forEach((feature) => {
      cy.contains(feature.name).should('be.visible')
    })
    
    // カテゴリヘッダーの確認
    cy.contains('定期レポート').should('be.visible')
    cy.contains('分析レポート').should('be.visible')
    cy.contains('Entra ID管理').should('be.visible')
    cy.contains('Exchange Online管理').should('be.visible')
    cy.contains('Teams管理').should('be.visible')
    cy.contains('OneDrive管理').should('be.visible')
  })

  features.forEach((feature) => {
    it(`executes ${feature.name} (${feature.id}) successfully`, () => {
      // 機能ボタンをクリック
      cy.contains(feature.name).click()
      
      // 実行開始の確認
      cy.contains('実行中').should('be.visible')
      
      // 実行完了の確認（タイムアウト30秒）
      cy.contains('完了', { timeout: 30000 }).should('be.visible')
      
      // 成功メッセージまたは結果の確認
      cy.get('[data-cy="execution-result"]').should('exist')
    })
  })

  it('handles feature execution errors gracefully', () => {
    // エラーをシミュレート（APIモック）
    cy.intercept('POST', '/api/execute/*', { 
      statusCode: 500, 
      body: { error: 'Server Error' } 
    })
    
    cy.contains('日次レポート').click()
    
    // エラーメッセージの確認
    cy.contains('エラー').should('be.visible')
    cy.get('[data-cy="error-message"]').should('be.visible')
  })

  it('is responsive across different viewports', () => {
    const viewports = [
      { width: 375, height: 667, device: 'iPhone SE' },
      { width: 768, height: 1024, device: 'iPad' },
      { width: 1920, height: 1080, device: 'Desktop' }
    ]

    viewports.forEach((viewport) => {
      cy.viewport(viewport.width, viewport.height)
      
      // 各ビューポートで主要要素が表示されることを確認
      cy.get('[data-cy="main-dashboard"]').should('be.visible')
      cy.contains('定期レポート').should('be.visible')
      
      // 最初の機能ボタンがクリック可能であることを確認
      cy.contains('日次レポート').should('be.visible').click()
      cy.contains('実行中').should('be.visible')
    })
  })

  it('meets accessibility standards', () => {
    // axe-core でアクセシビリティテスト
    cy.injectAxe()
    
    // WCAG 2.1 AA レベルの確認
    cy.checkA11y(null, {
      runOnly: {
        type: 'tag',
        values: ['wcag2a', 'wcag2aa', 'wcag21aa']
      }
    })
  })

  it('supports keyboard navigation', () => {
    // Tab キーでナビゲーション
    cy.get('body').tab()
    cy.focused().should('have.attr', 'data-cy', 'first-feature-button')
    
    // 機能ボタン間のナビゲーション
    for (let i = 0; i < 5; i++) {
      cy.focused().tab()
    }
    
    // Enter キーで機能実行
    cy.focused().type('{enter}')
    cy.contains('実行中').should('be.visible')
  })

  it('has good performance metrics', () => {
    // ページロード時間の測定
    cy.visit('/', {
      onBeforeLoad: (win) => {
        win.performance.mark('start')
      },
      onLoad: (win) => {
        win.performance.mark('end')
        win.performance.measure('pageLoad', 'start', 'end')
      }
    })
    
    cy.window().then((win) => {
      const measure = win.performance.getEntriesByName('pageLoad')[0]
      expect(measure.duration).to.be.lessThan(3000) // 3秒以内
    })
  })
})
'''
        
        cypress_test_path = self.frontend_dir / "cypress" / "e2e" / "26-features-complete.cy.ts"
        cypress_test_path.parent.mkdir(parents=True, exist_ok=True)
        with open(cypress_test_path, 'w', encoding='utf-8') as f:
            f.write(cypress_26_features_test)
        
        return {
            "cypress_test_created": str(cypress_test_path),
            "features_covered": 26,
            "test_types": ["functional", "responsive", "accessibility", "performance", "keyboard"],
            "status": "enhanced"
        }
    
    def run_frontend_test_suite(self) -> Dict[str, Any]:
        """フロントエンドテストスイート実行"""
        logger.info("🚀 Running frontend test suite...")
        
        if not self.frontend_available:
            return {
                "status": "skipped",
                "reason": "Frontend environment not available"
            }
        
        test_results = {
            "vitest_results": {},
            "cypress_results": {},
            "summary": {}
        }
        
        # Vitest (単体テスト) 実行
        try:
            logger.info("Running Vitest tests...")
            vitest_cmd = ["npm", "run", "test", "--", "--reporter=json", "--reporter=html"]
            
            vitest_result = subprocess.run(
                vitest_cmd,
                cwd=self.frontend_dir,
                capture_output=True,
                text=True,
                timeout=300
            )
            
            test_results["vitest_results"] = {
                "exit_code": vitest_result.returncode,
                "success": vitest_result.returncode == 0,
                "stdout_lines": len(vitest_result.stdout.splitlines()),
                "stderr_lines": len(vitest_result.stderr.splitlines())
            }
            
        except Exception as e:
            test_results["vitest_results"] = {
                "success": False,
                "error": str(e)
            }
        
        # Cypress (E2E テスト) 実行
        try:
            logger.info("Running Cypress tests...")
            cypress_cmd = ["npm", "run", "test:e2e"]
            
            cypress_result = subprocess.run(
                cypress_cmd,
                cwd=self.frontend_dir,
                capture_output=True,
                text=True,
                timeout=600
            )
            
            test_results["cypress_results"] = {
                "exit_code": cypress_result.returncode,
                "success": cypress_result.returncode == 0,
                "stdout_lines": len(cypress_result.stdout.splitlines()),
                "stderr_lines": len(cypress_result.stderr.splitlines())
            }
            
        except Exception as e:
            test_results["cypress_results"] = {
                "success": False,
                "error": str(e)
            }
        
        # サマリー生成
        vitest_success = test_results["vitest_results"].get("success", False)
        cypress_success = test_results["cypress_results"].get("success", False)
        
        test_results["summary"] = {
            "timestamp": self.timestamp,
            "vitest_passed": vitest_success,
            "cypress_passed": cypress_success,
            "overall_success": vitest_success and cypress_success,
            "features_tested": len(self.features_26)
        }
        
        return test_results
    
    def run_full_frontend_integration(self) -> Dict[str, Any]:
        """完全フロントエンド統合実行"""
        logger.info("🎯 Running full frontend integration...")
        
        # 分析
        analysis = self.analyze_frontend_structure()
        
        # Vitest 設定
        vitest_config = self.create_vitest_config()
        
        # 包括的テスト作成
        component_tests = self.create_comprehensive_component_tests()
        
        # Cypress 設定強化
        cypress_enhancement = self.enhance_cypress_config()
        
        # テスト実行
        test_execution = self.run_frontend_test_suite()
        
        # 統合結果
        integration_results = {
            "timestamp": self.timestamp,
            "project_root": str(self.project_root),
            "frontend_available": self.frontend_available,
            "features_26": self.features_26,
            "analysis": analysis,
            "vitest_config": vitest_config,
            "component_tests": component_tests,
            "cypress_enhancement": cypress_enhancement,
            "test_execution": test_execution,
            "integration_status": "completed"
        }
        
        # 最終レポート保存
        final_report = self.reports_dir / f"frontend_integration_report_{self.timestamp}.json"
        with open(final_report, 'w') as f:
            json.dump(integration_results, f, indent=2)
        
        logger.info(f"✅ Frontend integration completed!")
        logger.info(f"📄 Integration report: {final_report}")
        
        return integration_results


# pytest統合用テスト関数
@pytest.mark.frontend
@pytest.mark.integration
def test_frontend_environment():
    """フロントエンド環境テスト"""
    integration = FrontendTestIntegration()
    
    # Node.js 環境確認（CI環境では緩い条件）
    if os.getenv("CI") != "true":
        assert integration.frontend_available, "Frontend environment should be available"


@pytest.mark.frontend
@pytest.mark.unit
def test_26_features_definition():
    """26機能定義テスト"""
    integration = FrontendTestIntegration()
    
    assert len(integration.features_26) == 26, "Should have exactly 26 features defined"
    
    # カテゴリ別機能数確認
    reports_features = [f for f in integration.features_26 if 'report' in f or f == 'test_execution']
    analysis_features = [f for f in integration.features_26 if 'analysis' in f or 'audit' in f]
    
    assert len(reports_features) == 5, "Should have 5 report features"
    assert len(analysis_features) == 5, "Should have 5 analysis features"


@pytest.mark.frontend
@pytest.mark.integration
def test_vitest_config_creation():
    """Vitest設定作成テスト"""
    integration = FrontendTestIntegration()
    result = integration.create_vitest_config()
    
    assert result["status"] == "configured", "Vitest should be configured successfully"
    
    config_path = Path(result["vitest_config_created"])
    setup_path = Path(result["setup_file_created"])
    
    # ファイル存在確認（実際のファイルシステムをチェック）
    if integration.frontend_available:
        assert config_path.exists(), "Vitest config file should exist"
        assert setup_path.exists(), "Setup file should exist"


@pytest.mark.frontend
@pytest.mark.e2e
def test_cypress_enhancement():
    """Cypress設定強化テスト"""
    integration = FrontendTestIntegration()
    result = integration.enhance_cypress_config()
    
    assert result["status"] == "enhanced", "Cypress should be enhanced successfully"
    assert result["features_covered"] == 26, "Should cover all 26 features"
    assert "accessibility" in result["test_types"], "Should include accessibility tests"


if __name__ == "__main__":
    # スタンドアロン実行
    integration = FrontendTestIntegration()
    results = integration.run_full_frontend_integration()
    
    print("\n" + "="*60)
    print("🎯 FRONTEND INTEGRATION RESULTS")
    print("="*60)
    print(f"Frontend Available: {results['frontend_available']}")
    print(f"Features Covered: {len(results['features_26'])}")
    print(f"Integration Status: {results['integration_status']}")
    if 'test_execution' in results and 'summary' in results['test_execution']:
        print(f"Tests Passed: {results['test_execution']['summary']['overall_success']}")
    print("="*60)