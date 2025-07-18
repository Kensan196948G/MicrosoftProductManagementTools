# Python pytest移行アーキテクチャ設計書

## 📋 プロジェクト概要

**Microsoft 365管理ツール PowerShell → Python pytest完全移行**
- 移行対象: 70+ PowerShellテストスイート
- 新技術スタック: Python 3.12 + pytest + Playwright
- 品質要件: 100%機能互換性 + 新機能追加
- 期限: 2週間

## 🏗️ 移行アーキテクチャ設計

### 1. ディレクトリ構造設計

```
Tests/
├── pytest_migration_architecture.md    # 本設計書
├── conftest.py                         # pytest設定・共通フィクスチャ
├── pytest.ini                         # pytest設定ファイル
├── requirements.txt                    # Python依存関係
├── unit/                              # 単体テスト
│   ├── test_authentication.py
│   ├── test_graph_api.py
│   ├── test_exchange_online.py
│   ├── test_teams.py
│   ├── test_onedrive.py
│   └── test_logging.py
├── integration/                       # 統合テスト
│   ├── test_all_features.py          # test-all-features.ps1移行
│   ├── test_real_data_integration.py
│   └── test_cross_service.py
├── security/                         # セキュリティテスト
│   ├── test_vulnerability_scan.py    # security-vulnerability-test.ps1移行
│   ├── test_authentication_security.py
│   └── test_data_encryption.py
├── performance/                      # パフォーマンステスト
│   ├── test_memory_usage.py         # performance-memory-test.ps1移行
│   ├── test_load_testing.py
│   └── test_response_time.py
├── e2e/                             # E2Eテスト (Playwright)
│   ├── test_gui_automation.py        # GUI自動化テスト
│   ├── test_user_workflows.py
│   └── test_cross_browser.py
├── fixtures/                        # テストフィクスチャ
│   ├── auth_fixtures.py
│   ├── data_fixtures.py
│   └── mock_fixtures.py
├── utils/                           # テストユーティリティ
│   ├── test_helpers.py
│   ├── assertion_helpers.py
│   └── data_generators.py
└── reports/                         # テストレポート出力
    ├── html/
    ├── json/
    └── xml/
```

### 2. 技術スタック選択

#### 🧪 コアテスティングフレームワーク
- **pytest**: メインテストフレームワーク
- **pytest-asyncio**: 非同期テスト対応
- **pytest-mock**: モック・スタブ機能
- **pytest-cov**: コードカバレッジ測定
- **pytest-html**: HTMLレポート生成
- **pytest-xdist**: 並列テスト実行

#### 🎭 E2Eテスト・ブラウザ自動化
- **Playwright**: クロスブラウザ自動化
- **playwright-python**: Python統合
- **pytest-playwright**: pytest統合

#### 🔐 セキュリティテスト
- **bandit**: セキュリティ脆弱性スキャン
- **safety**: 依存関係脆弱性チェック
- **pytest-security**: セキュリティテスト拡張

#### 📊 パフォーマンステスト
- **pytest-benchmark**: パフォーマンス測定
- **memory-profiler**: メモリ使用量分析
- **locust**: 負荷テスト

#### 🔗 Microsoft 365 API統合
- **msal**: Microsoft認証
- **microsoft-graph**: Graph API
- **exchangelib**: Exchange Online
- **requests**: HTTP APIクライアント

### 3. PowerShell → Python移行マッピング

#### 認証システム移行
```python
# PowerShell: Connect-MgGraph
# Python: MSAL + Microsoft Graph

@pytest.fixture
async def graph_client():
    """Microsoft Graph認証済みクライアント"""
    app = msal.ConfidentialClientApplication(
        client_id=config.CLIENT_ID,
        client_credential=config.CLIENT_SECRET,
        authority=f"https://login.microsoftonline.com/{config.TENANT_ID}"
    )
    result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
    return GraphServiceClient(credentials=result['access_token'])
```

#### データ検証移行
```python
# PowerShell: Assert-条件
# Python: pytest assertions + custom helpers

def assert_user_has_license(user, license_type):
    """ユーザーライセンス検証"""
    assert user.assigned_licenses, f"User {user.display_name} has no licenses"
    license_ids = [lic.sku_id for lic in user.assigned_licenses]
    assert license_type in license_ids, f"License {license_type} not found"
```

#### レポート生成移行
```python
# PowerShell: Export-CSV, Out-File
# Python: pandas + jinja2 templates

@pytest.fixture
def report_generator():
    """テストレポート生成"""
    return TestReportGenerator(
        template_dir="templates",
        output_dir="reports",
        formats=["html", "json", "xml"]
    )
```

### 4. テストカテゴリ別移行戦略

#### A. 統合テスト移行 (test-all-features.ps1)
```python
# Tests/integration/test_all_features.py

@pytest.mark.integration
@pytest.mark.slow
class TestAllFeatures:
    """全機能統合テスト (PowerShell test-all-features.ps1移行)"""
    
    async def test_microsoft_graph_authentication(self, graph_client):
        """Microsoft Graph認証テスト"""
        context = await graph_client.get_context()
        assert context.auth_type == "ClientCredential"
        assert context.tenant_id == config.TENANT_ID
    
    async def test_user_management(self, graph_client):
        """ユーザー管理機能テスト"""
        users = await graph_client.users.get(top=5)
        assert len(users.value) > 0
        
        for user in users.value:
            assert user.display_name
            assert user.user_principal_name
    
    async def test_exchange_online_integration(self, exchange_client):
        """Exchange Online統合テスト"""
        mailboxes = await exchange_client.get_mailboxes(limit=3)
        assert len(mailboxes) > 0
        
        for mailbox in mailboxes:
            assert mailbox.primary_smtp_address
            assert mailbox.display_name
```

#### B. セキュリティテスト移行 (security-vulnerability-test.ps1)
```python
# Tests/security/test_vulnerability_scan.py

@pytest.mark.security
class TestSecurityVulnerabilities:
    """セキュリティ脆弱性テスト (PowerShell security-vulnerability-test.ps1移行)"""
    
    def test_credential_exposure_check(self, config_file):
        """認証情報露出チェック"""
        dangerous_patterns = [
            "YOUR-CERTIFICATE-THUMBPRINT-HERE",
            "YOUR-CLIENT-SECRET-HERE",
            "password=.*",
            "secret=.*"
        ]
        
        config_content = config_file.read_text()
        
        for pattern in dangerous_patterns:
            assert not re.search(pattern, config_content, re.IGNORECASE), \
                f"Dangerous pattern '{pattern}' found in config"
    
    def test_powershell_injection_patterns(self, source_files):
        """PowerShellインジェクション攻撃チェック"""
        dangerous_patterns = [
            r"Invoke-Expression",
            r"IEX\s*\(",
            r"cmd\s*/c",
            r"powershell\.exe"
        ]
        
        for source_file in source_files:
            content = source_file.read_text()
            for pattern in dangerous_patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                assert not matches, \
                    f"Dangerous pattern '{pattern}' found in {source_file.name}"
    
    def test_api_permissions_check(self, api_config):
        """API権限過剰チェック"""
        high_risk_scopes = [
            "https://graph.microsoft.com/Directory.ReadWrite.All",
            "https://graph.microsoft.com/User.ReadWrite.All",
            "https://graph.microsoft.com/Files.ReadWrite.All"
        ]
        
        configured_scopes = api_config.get("scopes", [])
        
        for scope in configured_scopes:
            if scope in high_risk_scopes:
                pytest.fail(f"High-risk scope '{scope}' should be avoided")
```

#### C. パフォーマンステスト移行 (performance-memory-test.ps1)
```python
# Tests/performance/test_memory_usage.py

@pytest.mark.performance
class TestMemoryUsage:
    """メモリ使用量テスト (PowerShell performance-memory-test.ps1移行)"""
    
    @pytest.mark.benchmark
    def test_module_import_performance(self, benchmark):
        """モジュールインポートパフォーマンス"""
        def import_modules():
            import src.core.authentication
            import src.core.logging_config
            import src.api.graph.client
            return "modules imported"
        
        result = benchmark(import_modules)
        assert result == "modules imported"
        
        # ベンチマーク結果の検証
        assert benchmark.stats.mean < 1.0  # 1秒以内
    
    @pytest.mark.memory
    def test_large_data_processing_memory(self, memory_tracker):
        """大量データ処理メモリテスト"""
        initial_memory = memory_tracker.get_usage()
        
        # 10,000件のテストデータ生成・処理
        test_data = [
            {
                "id": i,
                "name": f"User{i}",
                "email": f"user{i}@example.com",
                "department": f"Dept{i % 10}",
                "last_login": datetime.now() - timedelta(days=i % 30)
            }
            for i in range(10000)
        ]
        
        # データ処理
        processed_data = [
            user for user in test_data 
            if user["last_login"] > datetime.now() - timedelta(days=7)
        ]
        sorted_data = sorted(processed_data, key=lambda x: x["name"])
        
        final_memory = memory_tracker.get_usage()
        memory_increase = final_memory - initial_memory
        
        # メモリ使用量の検証
        assert memory_increase < 100 * 1024 * 1024  # 100MB未満
        assert len(sorted_data) > 0
    
    @pytest.mark.asyncio
    async def test_api_response_time(self, graph_client):
        """API応答時間テスト"""
        start_time = time.time()
        
        # API呼び出し
        users = await graph_client.users.get(top=100)
        
        end_time = time.time()
        response_time = end_time - start_time
        
        # 応答時間の検証
        assert response_time < 5.0  # 5秒以内
        assert len(users.value) > 0
```

#### D. E2Eテスト新規追加 (Playwright)
```python
# Tests/e2e/test_gui_automation.py

@pytest.mark.e2e
@pytest.mark.slow
class TestGUIAutomation:
    """GUI自動化テスト (Playwright使用)"""
    
    async def test_user_management_workflow(self, page):
        """ユーザー管理ワークフロー"""
        # アプリケーション起動
        await page.goto("http://localhost:8000")
        
        # ログイン
        await page.fill("#username", "admin@example.com")
        await page.fill("#password", "password")
        await page.click("#login-button")
        
        # ユーザー一覧表示
        await page.click("#users-menu")
        await page.wait_for_selector("#users-table")
        
        # ユーザー数の確認
        user_rows = await page.query_selector_all("#users-table tbody tr")
        assert len(user_rows) > 0
        
        # 新規ユーザー作成
        await page.click("#create-user-button")
        await page.fill("#user-name", "Test User")
        await page.fill("#user-email", "test@example.com")
        await page.click("#save-user-button")
        
        # 成功メッセージの確認
        success_message = await page.wait_for_selector(".success-message")
        assert await success_message.text_content() == "User created successfully"
    
    async def test_responsive_design(self, page):
        """レスポンシブデザインテスト"""
        await page.goto("http://localhost:8000")
        
        # デスクトップサイズ
        await page.set_viewport_size({"width": 1920, "height": 1080})
        desktop_menu = await page.query_selector("#desktop-menu")
        assert await desktop_menu.is_visible()
        
        # モバイルサイズ
        await page.set_viewport_size({"width": 375, "height": 667})
        mobile_menu = await page.query_selector("#mobile-menu")
        assert await mobile_menu.is_visible()
        
        # タブレットサイズ
        await page.set_viewport_size({"width": 768, "height": 1024})
        tablet_menu = await page.query_selector("#tablet-menu")
        assert await tablet_menu.is_visible()
```

### 5. 共通フィクスチャ設計

```python
# Tests/conftest.py

import pytest
import asyncio
from pathlib import Path
from playwright.async_api import async_playwright
from src.core.config import Config
from src.api.graph.client import GraphClient
from src.core.authentication import AuthenticationManager

# pytest設定
def pytest_configure(config):
    """pytest設定"""
    config.addinivalue_line("markers", "integration: 統合テストマーク")
    config.addinivalue_line("markers", "security: セキュリティテストマーク")
    config.addinivalue_line("markers", "performance: パフォーマンステストマーク")
    config.addinivalue_line("markers", "e2e: E2Eテストマーク")
    config.addinivalue_line("markers", "slow: 実行時間が長いテストマーク")

# セッションスコープフィクスチャ
@pytest.fixture(scope="session")
def event_loop():
    """セッションスコープイベントループ"""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
def config():
    """アプリケーション設定"""
    return Config.load_from_file("config/test_settings.json")

@pytest.fixture(scope="session")
async def auth_manager(config):
    """認証マネージャー"""
    return AuthenticationManager(config)

@pytest.fixture(scope="session")
async def graph_client(auth_manager):
    """Microsoft Graph認証済みクライアント"""
    client = GraphClient(auth_manager)
    await client.authenticate()
    yield client
    await client.close()

# テストスコープフィクスチャ
@pytest.fixture
async def playwright_browser():
    """Playwrightブラウザー"""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        yield browser
        await browser.close()

@pytest.fixture
async def page(playwright_browser):
    """Playwrightページ"""
    context = await playwright_browser.new_context()
    page = await context.new_page()
    yield page
    await context.close()

@pytest.fixture
def memory_tracker():
    """メモリ使用量トラッカー"""
    from utils.memory_tracker import MemoryTracker
    return MemoryTracker()

@pytest.fixture
def config_file():
    """設定ファイル"""
    return Path("config/appsettings.json")

@pytest.fixture
def source_files():
    """ソースファイル一覧"""
    return list(Path("src").rglob("*.py"))
```

### 6. CI/CD統合設計

```yaml
# .github/workflows/pytest.yml

name: Python pytest Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.9, 3.10, 3.11, 3.12]
        
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r Tests/requirements.txt
        
    - name: Install Playwright browsers
      run: |
        playwright install
        
    - name: Run pytest with coverage
      run: |
        pytest Tests/ \
          --cov=src \
          --cov-report=html \
          --cov-report=xml \
          --html=reports/pytest-report.html \
          --junitxml=reports/pytest-junit.xml \
          -v
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        
    - name: Archive test results
      uses: actions/upload-artifact@v3
      with:
        name: test-results-${{ matrix.python-version }}
        path: reports/
```

### 7. 品質保証メトリクス

#### テストカバレッジ要件
- **最小カバレッジ**: 85%
- **クリティカルモジュール**: 95%
- **新規コード**: 100%

#### パフォーマンス要件
- **単体テスト**: 平均実行時間 < 100ms
- **統合テスト**: 平均実行時間 < 5秒
- **E2Eテスト**: 平均実行時間 < 30秒
- **全テストスイート**: 総実行時間 < 15分

#### セキュリティ要件
- **脆弱性スキャン**: 0件のCritical/High
- **認証情報露出**: 0件
- **権限過剰**: 0件

### 8. 移行スケジュール

**Week 1:**
- Day 1-2: 基盤構築 (conftest.py, pytest.ini, requirements.txt)
- Day 3-4: 統合テスト移行 (test_all_features.py)
- Day 5-7: セキュリティテスト移行 (test_vulnerability_scan.py)

**Week 2:**
- Day 8-10: パフォーマンステスト移行 (test_memory_usage.py)
- Day 11-12: E2Eテスト新規作成 (test_gui_automation.py)
- Day 13-14: CI/CD統合・最終テスト・文書化

## 🚀 移行開始準備完了

次の段階では、この設計書に基づいて実際のPythonテストコードの実装を開始します。
