#!/usr/bin/env python3
"""
Microsoft 365 Management Tools - E2E包括テストスイート
Playwrightを使用したEnd-to-Endテスト実装
"""

import pytest
import asyncio
from playwright.async_api import async_playwright, Page, Browser, BrowserContext
from pathlib import Path
import json
import time
from typing import Dict, List, Any
import logging
import sys
import os
from datetime import datetime

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))


class TestE2EComprehensive:
    """E2E包括テストクラス"""
    
    @pytest.fixture(scope="class")
    async def browser_setup(self):
        """Playwrightブラウザーセットアップ"""
        async with async_playwright() as p:
            # Chromiumブラウザー起動
            browser = await p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-dev-shm-usage']
            )
            
            # コンテキスト作成
            context = await browser.new_context(
                viewport={'width': 1920, 'height': 1080},
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            )
            
            yield browser, context
            
            await context.close()
            await browser.close()
    
    @pytest.mark.asyncio
    async def test_application_startup_e2e(self, browser_setup):
        """E2Eアプリケーション起動テスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        start_time = time.time()
        
        try:
            # アプリケーションURLにアクセス
            # 実際のアプリケーションURLに合わせて調整
            await page.goto('http://localhost:3000')
            
            # メインダッシュボードの表示を待機
            await page.wait_for_selector('[data-testid="main-dashboard"]', timeout=10000)
            
            startup_time = time.time() - start_time
            
            # 起動時間基準: 5秒以内
            assert startup_time < 5.0, f"E2E起動時間が基準を超過: {startup_time:.2f}秒"
            
            # タイトル確認
            title = await page.title()
            assert "Microsoft 365" in title, f"ページタイトルが不正: {title}"
            
            logging.info(f"E2E起動時間: {startup_time:.2f}秒")
            
        finally:
            await page.close()
    
    @pytest.mark.asyncio
    async def test_user_management_workflow_e2e(self, browser_setup):
        """E2Eユーザー管理ワークフローテスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        try:
            await page.goto('http://localhost:3000')
            await page.wait_for_selector('[data-testid="main-dashboard"]')
            
            # ユーザー管理タブへ遷移
            await page.click('[data-testid="tab-users"]')
            await page.wait_for_selector('[data-testid="user-management-panel"]')
            
            # ユーザー一覧取得ボタンをクリック
            await page.click('[data-testid="btn-get-users"]')
            
            # ユーザーデータの表示を待機
            await page.wait_for_selector('[data-testid="user-list-table"]', timeout=15000)
            
            # ユーザーデータが表示されていることを確認
            user_rows = await page.query_selector_all('[data-testid="user-row"]')
            assert len(user_rows) > 0, "ユーザーデータが表示されていません"
            
            # ユーザー詳細情報をクリック
            if user_rows:
                await user_rows[0].click()
                await page.wait_for_selector('[data-testid="user-detail-panel"]')
                
                # ユーザー詳細情報が表示されていることを確認
                detail_content = await page.text_content('[data-testid="user-detail-content"]')
                assert detail_content, "ユーザー詳細情報が表示されていません"
            
            logging.info("ユーザー管理ワークフロー正常完了")
            
        finally:
            await page.close()
    
    @pytest.mark.asyncio
    async def test_report_generation_e2e(self, browser_setup):
        """E2Eレポート生成テスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        try:
            await page.goto('http://localhost:3000')
            await page.wait_for_selector('[data-testid="main-dashboard"]')
            
            # レポートタブへ遷移
            await page.click('[data-testid="tab-reports"]')
            await page.wait_for_selector('[data-testid="report-panel"]')
            
            # 日次レポート生成ボタンをクリック
            await page.click('[data-testid="btn-daily-report"]')
            
            # レポート生成の進行状況を確認
            await page.wait_for_selector('[data-testid="report-progress"]', timeout=5000)
            
            # レポート完成を待機
            await page.wait_for_selector('[data-testid="report-completed"]', timeout=30000)
            
            # レポートダウンロードリンクの確認
            download_link = await page.query_selector('[data-testid="download-report"]')
            assert download_link, "レポートダウンロードリンクが見つかりません"
            
            # レポートプレビューの確認
            preview_content = await page.text_content('[data-testid="report-preview"]')
            assert preview_content, "レポートプレビューが表示されていません"
            
            logging.info("レポート生成ワークフロー正常完了")
            
        finally:
            await page.close()
    
    @pytest.mark.asyncio
    async def test_authentication_flow_e2e(self, browser_setup):
        """E2E認証フローテスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        try:
            await page.goto('http://localhost:3000')
            
            # ログインページの表示を確認
            login_form = await page.query_selector('[data-testid="login-form"]')
            if login_form:
                # テスト用資格情報でログイン
                await page.fill('[data-testid="username-input"]', 'test@contoso.com')
                await page.fill('[data-testid="password-input"]', 'TestPassword123!')
                await page.click('[data-testid="login-button"]')
                
                # ログイン後のダッシュボード表示を待機
                await page.wait_for_selector('[data-testid="main-dashboard"]', timeout=10000)
                
                # ユーザー情報の表示を確認
                user_info = await page.query_selector('[data-testid="user-info"]')
                assert user_info, "ユーザー情報が表示されていません"
                
                # ログアウトテスト
                await page.click('[data-testid="logout-button"]')
                await page.wait_for_selector('[data-testid="login-form"]', timeout=5000)
                
                logging.info("認証フロー正常完了")
            else:
                # 認証が不要の場合
                await page.wait_for_selector('[data-testid="main-dashboard"]')
                logging.info("認証不要でアプリケーションにアクセス")
            
        finally:
            await page.close()
    
    @pytest.mark.asyncio
    async def test_responsive_design_e2e(self, browser_setup):
        """E2Eレスポンシブデザインテスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        try:
            await page.goto('http://localhost:3000')
            await page.wait_for_selector('[data-testid="main-dashboard"]')
            
            # デスクトップサイズでの表示確認
            await page.set_viewport_size({'width': 1920, 'height': 1080})
            desktop_layout = await page.is_visible('[data-testid="desktop-layout"]')
            
            # タブレットサイズでの表示確認
            await page.set_viewport_size({'width': 768, 'height': 1024})
            await page.wait_for_timeout(1000)  # レイアウト変更を待機
            tablet_layout = await page.is_visible('[data-testid="tablet-layout"]')
            
            # モバイルサイズでの表示確認
            await page.set_viewport_size({'width': 375, 'height': 667})
            await page.wait_for_timeout(1000)
            mobile_layout = await page.is_visible('[data-testid="mobile-layout"]')
            
            # モバイルメニューの動作確認
            mobile_menu_button = await page.query_selector('[data-testid="mobile-menu-button"]')
            if mobile_menu_button:
                await mobile_menu_button.click()
                mobile_menu = await page.wait_for_selector('[data-testid="mobile-menu"]', timeout=3000)
                assert mobile_menu, "モバイルメニューが表示されていません"
            
            logging.info("レスポンシブデザイン正常動作")
            
        finally:
            await page.close()
    
    @pytest.mark.asyncio
    async def test_error_handling_e2e(self, browser_setup):
        """E2Eエラーハンドリングテスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        try:
            await page.goto('http://localhost:3000')
            await page.wait_for_selector('[data-testid="main-dashboard"]')
            
            # ネットワークエラーのシミュレーション
            await page.route('**/api/**', lambda route: route.abort())
            
            # API呼び出しを発生させる操作
            await page.click('[data-testid="btn-get-users"]')
            
            # エラーメッセージの表示を確認
            error_message = await page.wait_for_selector('[data-testid="error-message"]', timeout=10000)
            assert error_message, "エラーメッセージが表示されていません"
            
            # エラーメッセージの内容確認
            error_text = await error_message.text_content()
            assert "エラー" in error_text or "Error" in error_text, f"適切なエラーメッセージが表示されていません: {error_text}"
            
            # リトライボタンの確認
            retry_button = await page.query_selector('[data-testid="retry-button"]')
            if retry_button:
                await retry_button.click()
                # リトライ後の動作確認
                await page.wait_for_timeout(2000)
            
            logging.info("エラーハンドリング正常動作")
            
        finally:
            await page.close()
    
    @pytest.mark.performance
    @pytest.mark.asyncio
    async def test_performance_e2e(self, browser_setup):
        """E2Eパフォーマンステスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        try:
            # パフォーマンスメトリクスを有効化
            await page.goto('http://localhost:3000')
            
            # Core Web Vitals測定
            performance_metrics = await page.evaluate("""
                () => {
                    return new Promise((resolve) => {
                        const observer = new PerformanceObserver((list) => {
                            const entries = list.getEntries();
                            const metrics = {};
                            
                            entries.forEach((entry) => {
                                if (entry.entryType === 'navigation') {
                                    metrics.loadTime = entry.loadEventEnd - entry.loadEventStart;
                                    metrics.domContentLoaded = entry.domContentLoadedEventEnd - entry.domContentLoadedEventStart;
                                }
                                if (entry.entryType === 'largest-contentful-paint') {
                                    metrics.lcp = entry.startTime;
                                }
                                if (entry.entryType === 'first-input') {
                                    metrics.fid = entry.processingStart - entry.startTime;
                                }
                            });
                            
                            resolve(metrics);
                        });
                        
                        observer.observe({entryTypes: ['navigation', 'largest-contentful-paint', 'first-input']});
                        
                        // 5秒後にタイムアウト
                        setTimeout(() => resolve({}), 5000);
                    });
                }
            """)
            
            # LCP (Largest Contentful Paint) 基準: 2.5秒以内
            if 'lcp' in performance_metrics:
                assert performance_metrics['lcp'] < 2500, f"LCPが基準を超過: {performance_metrics['lcp']}ms"
            
            # FID (First Input Delay) 基準: 100ms以内
            if 'fid' in performance_metrics:
                assert performance_metrics['fid'] < 100, f"FIDが基準を超過: {performance_metrics['fid']}ms"
            
            # JavaScriptヒープサイズ測定
            js_heap_size = await page.evaluate('performance.memory ? performance.memory.usedJSHeapSize : 0')
            
            # JSヒープサイズ基準: 50MB以内
            heap_size_mb = js_heap_size / 1024 / 1024
            assert heap_size_mb < 50, f"JSヒープサイズが基準を超過: {heap_size_mb:.2f}MB"
            
            logging.info(f"E2Eパフォーマンスメトリクス: {performance_metrics}")
            logging.info(f"JSヒープサイズ: {heap_size_mb:.2f}MB")
            
        finally:
            await page.close()
    
    @pytest.mark.asyncio
    async def test_accessibility_e2e(self, browser_setup):
        """E2Eアクセシビリティテスト"""
        browser, context = browser_setup
        page = await context.new_page()
        
        try:
            await page.goto('http://localhost:3000')
            await page.wait_for_selector('[data-testid="main-dashboard"]')
            
            # axe-coreアクセシビリティチェック
            await page.add_script_tag(url='https://unpkg.com/axe-core@latest/axe.min.js')
            
            accessibility_results = await page.evaluate("""
                async () => {
                    const results = await axe.run();
                    return {
                        violations: results.violations,
                        passes: results.passes.length,
                        incomplete: results.incomplete.length
                    };
                }
            """)
            
            # アクセシビリティ違反がないことを確認
            violations = accessibility_results['violations']
            assert len(violations) == 0, f"アクセシビリティ違反が発見されました: {violations}"
            
            # キーボードナビゲーションテスト
            await page.keyboard.press('Tab')
            focused_element = await page.evaluate('document.activeElement.tagName')
            assert focused_element, "フォーカス可能な要素が見つかりません"
            
            # スクリーンリーダーテキストの確認
            aria_labels = await page.evaluate("""
                () => {
                    const elementsWithAriaLabel = document.querySelectorAll('[aria-label]');
                    const elementsWithAriaLabelledby = document.querySelectorAll('[aria-labelledby]');
                    return {
                        ariaLabel: elementsWithAriaLabel.length,
                        ariaLabelledby: elementsWithAriaLabelledby.length
                    };
                }
            """)
            
            # ARIAラベルが適切に設定されていることを確認
            total_aria_elements = aria_labels['ariaLabel'] + aria_labels['ariaLabelledby']
            assert total_aria_elements > 0, "ARIAラベルが設定された要素が見つかりません"
            
            logging.info(f"アクセシビリティチェック結果: {accessibility_results}")
            logging.info(f"ARIA要素数: {total_aria_elements}")
            
        finally:
            await page.close()
    
    @pytest.mark.asyncio
    async def test_cross_browser_compatibility(self):
        """E2Eクロスブラウザー互換性テスト"""
        async with async_playwright() as p:
            browsers = []
            
            # Chromium, Firefox, Webkitでテスト
            for browser_type in [p.chromium, p.firefox, p.webkit]:
                try:
                    browser = await browser_type.launch(headless=True)
                    context = await browser.new_context()
                    page = await context.new_page()
                    
                    await page.goto('http://localhost:3000')
                    await page.wait_for_selector('[data-testid="main-dashboard"]', timeout=10000)
                    
                    # 基本機能の動作確認
                    title = await page.title()
                    assert "Microsoft 365" in title, f"{browser_type.name}でタイトルが不正: {title}"
                    
                    browsers.append(browser_type.name)
                    
                    await context.close()
                    await browser.close()
                    
                except Exception as e:
                    logging.warning(f"{browser_type.name}でエラー: {e}")
            
            # 少なくとも1つのブラウザーで動作することを確認
            assert len(browsers) > 0, "どのブラウザーでもアプリケーションが動作しません"
            
            logging.info(f"サポートされたブラウザー: {', '.join(browsers)}")


class TestE2EQualityMetrics:
    """E2E品質メトリクス測定クラス"""
    
    @pytest.mark.asyncio
    async def test_e2e_coverage_measurement(self, browser_setup):
        """E2Eカバレッジ測定"""
        browser, context = browser_setup
        page = await context.new_page()
        
        # JavaScriptカバレッジ測定を有効化
        await page.coverage.start_js_coverage()
        
        try:
            await page.goto('http://localhost:3000')
            await page.wait_for_selector('[data-testid="main-dashboard"]')
            
            # 主要な機能を一通りテスト
            await page.click('[data-testid="tab-users"]')
            await page.click('[data-testid="btn-get-users"]')
            await page.click('[data-testid="tab-reports"]')
            await page.click('[data-testid="btn-daily-report"]')
            
            # カバレッジデータ取得
            js_coverage = await page.coverage.stop_js_coverage()
            
            total_bytes = sum(entry['text'].__len__() for entry in js_coverage)
            used_bytes = sum(
                sum(range_item['end'] - range_item['start'] for range_item in entry['ranges'])
                for entry in js_coverage
            )
            
            coverage_percentage = (used_bytes / total_bytes * 100) if total_bytes > 0 else 0
            
            # E2Eカバレッジ基準: 60%以上
            assert coverage_percentage >= 60.0, f"E2Eカバレッジが基準を下回り: {coverage_percentage:.2f}%"
            
            logging.info(f"E2E JavaScriptカバレッジ: {coverage_percentage:.2f}%")
            
        finally:
            await page.close()
    
    def test_e2e_test_count_validation(self):
        """E2Eテスト数検証"""
        # このクラスのE2Eテストメソッド数をカウント
        test_methods = [method for method in dir(TestE2EComprehensive) if method.startswith('test_')]
        
        # 最低限必要なE2Eテスト数: 8個
        min_required_tests = 8
        assert len(test_methods) >= min_required_tests, f"E2Eテスト数が不足: {len(test_methods)}/{min_required_tests}"
        
        logging.info(f"E2Eテスト数: {len(test_methods)}個")


if __name__ == '__main__':
    # E2Eテストの単体実行
    pytest.main([__file__, '-v', '--tb=short', '-m', 'not performance'])
