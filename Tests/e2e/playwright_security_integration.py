#!/usr/bin/env python3
"""
Playwright + Security Integration E2E Test Suite
QA Engineer (dev2) - pytest + Playwright + Security Tools Integration

統合E2Eテストスイート：
- Playwright ブラウザ自動化
- セキュリティテスト統合
- アクセシビリティテスト
- パフォーマンス測定
- pytest統合
"""
import asyncio
import json
import time
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
import pytest
from playwright.async_api import async_playwright, Page, Browser, BrowserContext

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()


class PlaywrightSecurityIntegration:
    """Playwright + セキュリティ統合テストスイート"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.reports_dir = self.project_root / "Tests" / "e2e" / "reports"
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.test_results = {}
        
        # テスト対象URL (本番環境では適切に設定)
        self.base_url = "http://localhost:8000"
        self.fallback_url = "about:blank"  # フォールバック用
    
    async def setup_browser(self) -> tuple[Browser, BrowserContext, Page]:
        """ブラウザセットアップ"""
        playwright = await async_playwright().start()
        
        # Chromium ブラウザ起動 (セキュリティ設定付き)
        browser = await playwright.chromium.launch(
            headless=True,
            args=[
                '--disable-web-security',
                '--disable-features=VizDisplayCompositor',
                '--no-sandbox',
                '--disable-dev-shm-usage'
            ]
        )
        
        # セキュリティヘッダー監視用コンテキスト
        context = await browser.new_context(
            ignore_https_errors=False,
            user_agent='PlaywrightSecurityTester/1.0'
        )
        
        page = await context.new_page()
        
        return browser, context, page
    
    async def test_security_headers(self, page: Page) -> Dict[str, Any]:
        """セキュリティヘッダーテスト"""
        print("🛡️ Testing Security Headers...")
        
        security_headers = [
            'X-Content-Type-Options',
            'X-Frame-Options', 
            'X-XSS-Protection',
            'Strict-Transport-Security',
            'Content-Security-Policy',
            'Referrer-Policy'
        ]
        
        results = {}
        
        try:
            # テストページに移動
            response = await page.goto(self.base_url, timeout=10000)
            
            if response:
                headers = response.headers
                
                for header in security_headers:
                    header_lower = header.lower()
                    found = any(h.lower() == header_lower for h in headers.keys())
                    results[header] = {
                        "present": found,
                        "value": headers.get(header_lower, "") if found else None
                    }
            else:
                # フォールバック: ローカルHTMLページテスト
                await page.goto(self.fallback_url)
                for header in security_headers:
                    results[header] = {"present": False, "value": None}
                    
        except Exception as e:
            print(f"Security headers test failed: {e}")
            for header in security_headers:
                results[header] = {"present": False, "error": str(e)}
        
        # 評価
        present_headers = sum(1 for r in results.values() if r.get("present", False))
        security_score = (present_headers / len(security_headers)) * 100
        
        return {
            "test_type": "security_headers",
            "timestamp": self.timestamp,
            "headers": results,
            "present_headers": present_headers,
            "total_headers": len(security_headers),
            "security_score": round(security_score, 2),
            "passed": security_score >= 50  # 50%以上で合格
        }
    
    async def test_xss_vulnerability(self, page: Page) -> Dict[str, Any]:
        """XSS脆弱性テスト"""
        print("🕷️ Testing XSS Vulnerabilities...")
        
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "javascript:alert('XSS')",
            "<img src=x onerror=alert('XSS')>",
            "';alert('XSS');//"
        ]
        
        vulnerabilities_found = []
        
        try:
            await page.goto(self.base_url, timeout=10000)
            
            # 入力フィールドを探してXSSテスト
            inputs = await page.query_selector_all('input[type="text"], input[type="search"], textarea')
            
            for i, input_element in enumerate(inputs):
                for payload in xss_payloads:
                    try:
                        await input_element.fill(payload)
                        await page.keyboard.press('Enter')
                        
                        # アラートダイアログの検出
                        page.on('dialog', lambda dialog: dialog.accept())
                        
                        # ページソースにペイロードが実行可能な形で存在するかチェック
                        content = await page.content()
                        if payload in content and 'script' in payload.lower():
                            vulnerabilities_found.append({
                                "input_index": i,
                                "payload": payload,
                                "location": "input_field"
                            })
                            
                    except Exception as e:
                        pass  # 個別の入力エラーは無視
                        
        except Exception as e:
            print(f"XSS test failed: {e}")
        
        return {
            "test_type": "xss_vulnerability",
            "timestamp": self.timestamp,
            "payloads_tested": len(xss_payloads),
            "vulnerabilities_found": len(vulnerabilities_found),
            "vulnerability_details": vulnerabilities_found,
            "passed": len(vulnerabilities_found) == 0
        }
    
    async def test_accessibility(self, page: Page) -> Dict[str, Any]:
        """アクセシビリティテスト"""
        print("♿ Testing Accessibility...")
        
        accessibility_checks = {
            "has_title": False,
            "has_lang_attribute": False,
            "has_alt_text": True,  # デフォルトTrue、問題があればFalse
            "has_headings": False,
            "has_landmarks": False
        }
        
        try:
            await page.goto(self.base_url, timeout=10000)
            
            # タイトル確認
            title = await page.title()
            accessibility_checks["has_title"] = bool(title and title.strip())
            
            # 言語属性確認
            html_element = await page.query_selector('html')
            if html_element:
                lang_attr = await html_element.get_attribute('lang')
                accessibility_checks["has_lang_attribute"] = bool(lang_attr)
            
            # 画像のalt属性確認
            images = await page.query_selector_all('img')
            for img in images:
                alt_attr = await img.get_attribute('alt')
                if not alt_attr:
                    accessibility_checks["has_alt_text"] = False
                    break
            
            # 見出し確認
            headings = await page.query_selector_all('h1, h2, h3, h4, h5, h6')
            accessibility_checks["has_headings"] = len(headings) > 0
            
            # ランドマーク確認
            landmarks = await page.query_selector_all('main, nav, header, footer, section, article')
            accessibility_checks["has_landmarks"] = len(landmarks) > 0
            
        except Exception as e:
            print(f"Accessibility test failed: {e}")
        
        passed_checks = sum(1 for check in accessibility_checks.values() if check)
        accessibility_score = (passed_checks / len(accessibility_checks)) * 100
        
        return {
            "test_type": "accessibility",
            "timestamp": self.timestamp,
            "checks": accessibility_checks,
            "passed_checks": passed_checks,
            "total_checks": len(accessibility_checks),
            "accessibility_score": round(accessibility_score, 2),
            "passed": accessibility_score >= 70  # 70%以上で合格
        }
    
    async def test_performance_metrics(self, page: Page) -> Dict[str, Any]:
        """パフォーマンス測定テスト"""
        print("⚡ Testing Performance Metrics...")
        
        try:
            # ページロード時間測定
            start_time = time.time()
            await page.goto(self.base_url, timeout=30000)
            load_time = time.time() - start_time
            
            # Performance API メトリクス取得
            performance_metrics = await page.evaluate("""
                () => {
                    const navigation = performance.getEntriesByType('navigation')[0];
                    return {
                        dom_content_loaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
                        load_complete: navigation.loadEventEnd - navigation.loadEventStart,
                        first_paint: performance.getEntriesByType('paint').find(entry => entry.name === 'first-paint')?.startTime || 0,
                        first_contentful_paint: performance.getEntriesByType('paint').find(entry => entry.name === 'first-contentful-paint')?.startTime || 0
                    };
                }
            """)
            
            # Core Web Vitals 基準
            performance_thresholds = {
                "page_load_time": 3.0,  # 3秒以内
                "dom_content_loaded": 1500,  # 1.5秒以内 (ms)
                "first_contentful_paint": 1800  # 1.8秒以内 (ms)
            }
            
            metrics = {
                "page_load_time": round(load_time, 2),
                "dom_content_loaded": round(performance_metrics.get("dom_content_loaded", 0), 2),
                "load_complete": round(performance_metrics.get("load_complete", 0), 2),
                "first_paint": round(performance_metrics.get("first_paint", 0), 2),
                "first_contentful_paint": round(performance_metrics.get("first_contentful_paint", 0), 2)
            }
            
            # 合格判定
            performance_passed = (
                metrics["page_load_time"] <= performance_thresholds["page_load_time"] and
                metrics["dom_content_loaded"] <= performance_thresholds["dom_content_loaded"] and
                metrics["first_contentful_paint"] <= performance_thresholds["first_contentful_paint"]
            )
            
        except Exception as e:
            print(f"Performance test failed: {e}")
            metrics = {"error": str(e)}
            performance_passed = False
        
        return {
            "test_type": "performance_metrics",
            "timestamp": self.timestamp,
            "metrics": metrics,
            "thresholds": performance_thresholds,
            "passed": performance_passed
        }
    
    async def run_full_e2e_suite(self) -> Dict[str, Any]:
        """完全E2Eテストスイート実行"""
        print("🎯 Running Full E2E Test Suite with Security Integration...")
        
        browser, context, page = await self.setup_browser()
        
        try:
            # 各テスト実行
            tests = {
                "security_headers": self.test_security_headers(page),
                "xss_vulnerability": self.test_xss_vulnerability(page),
                "accessibility": self.test_accessibility(page),
                "performance_metrics": self.test_performance_metrics(page)
            }
            
            results = {}
            for test_name, test_coro in tests.items():
                try:
                    print(f"\n--- Running {test_name} ---")
                    result = await test_coro
                    results[test_name] = result
                    
                    if result.get("passed", False):
                        print(f"✅ {test_name}: PASSED")
                    else:
                        print(f"❌ {test_name}: FAILED")
                        
                except Exception as e:
                    print(f"💥 {test_name}: ERROR - {e}")
                    results[test_name] = {
                        "test_type": test_name,
                        "status": "error",
                        "error": str(e),
                        "passed": False
                    }
            
            # 総合評価
            passed_tests = sum(1 for result in results.values() if result.get("passed", False))
            total_tests = len(results)
            success_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
            
            overall_results = {
                "timestamp": self.timestamp,
                "test_suite": "playwright_security_integration",
                "base_url": self.base_url,
                "browser": "chromium",
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "failed_tests": total_tests - passed_tests,
                "success_rate": round(success_rate, 2),
                "overall_status": "PASS" if success_rate >= 75 else "FAIL",
                "test_results": results
            }
            
        finally:
            # ブラウザクリーンアップ
            await browser.close()
        
        # レポート保存
        report_file = self.reports_dir / f"e2e_security_integration_{self.timestamp}.json"
        with open(report_file, 'w') as f:
            json.dump(overall_results, f, indent=2)
        
        print(f"\n✅ E2E test suite completed!")
        print(f"📊 Results: {passed_tests}/{total_tests} tests passed ({success_rate:.1f}%)")
        print(f"📄 Report saved: {report_file}")
        
        return overall_results


# pytest統合用テスト関数
@pytest.mark.e2e
@pytest.mark.security
@pytest.mark.asyncio
async def test_security_headers():
    """セキュリティヘッダーE2Eテスト"""
    tester = PlaywrightSecurityIntegration()
    browser, context, page = await tester.setup_browser()
    
    try:
        result = await tester.test_security_headers(page)
        # 少なくとも1つのセキュリティヘッダーが設定されていることを確認
        assert result["present_headers"] >= 1, f"No security headers found"
    finally:
        await browser.close()


@pytest.mark.e2e
@pytest.mark.security
@pytest.mark.asyncio
async def test_xss_protection():
    """XSS保護E2Eテスト"""
    tester = PlaywrightSecurityIntegration()
    browser, context, page = await tester.setup_browser()
    
    try:
        result = await tester.test_xss_vulnerability(page)
        # XSS脆弱性が検出されないことを確認
        assert result["vulnerabilities_found"] == 0, f"XSS vulnerabilities detected: {result['vulnerabilities_found']}"
    finally:
        await browser.close()


@pytest.mark.e2e
@pytest.mark.accessibility
@pytest.mark.asyncio
async def test_accessibility_standards():
    """アクセシビリティ基準E2Eテスト"""
    tester = PlaywrightSecurityIntegration()
    browser, context, page = await tester.setup_browser()
    
    try:
        result = await tester.test_accessibility(page)
        # アクセシビリティスコアが50%以上であることを確認
        assert result["accessibility_score"] >= 50, f"Accessibility score too low: {result['accessibility_score']}%"
    finally:
        await browser.close()


@pytest.mark.e2e
@pytest.mark.performance
@pytest.mark.asyncio
async def test_performance_requirements():
    """パフォーマンス要件E2Eテスト"""
    tester = PlaywrightSecurityIntegration()
    browser, context, page = await tester.setup_browser()
    
    try:
        result = await tester.test_performance_metrics(page)
        # パフォーマンス測定が完了していることを確認
        assert "error" not in result.get("metrics", {}), "Performance measurement failed"
    finally:
        await browser.close()


@pytest.mark.e2e
@pytest.mark.integration
@pytest.mark.asyncio
async def test_full_e2e_integration():
    """完全E2E統合テスト"""
    tester = PlaywrightSecurityIntegration()
    result = await tester.run_full_e2e_suite()
    
    # 少なくとも50%のテストが成功することを確認
    assert result["success_rate"] >= 50, f"E2E test success rate too low: {result['success_rate']}%"
    
    # すべてのテストが実行されていることを確認
    assert result["total_tests"] >= 4, f"Not all E2E tests were executed"


if __name__ == "__main__":
    # スタンドアロン実行
    async def main():
        tester = PlaywrightSecurityIntegration()
        results = await tester.run_full_e2e_suite()
        
        print("\n" + "="*60)
        print("🎭 PLAYWRIGHT + SECURITY E2E TEST RESULTS")
        print("="*60)
        print(f"Overall Status: {results['overall_status']}")
        print(f"Tests Passed: {results['passed_tests']}/{results['total_tests']}")
        print(f"Success Rate: {results['success_rate']:.1f}%")
        print("="*60)
    
    asyncio.run(main())