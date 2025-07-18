# pytest テストガイド - Microsoft 365管理ツール

## 概要

このガイドは、Microsoft 365管理ツールのPython移行プロジェクトにおけるpytestを使用したテスト作成のベストプラクティスを提供します。

## テスト構造

```
Tests/
├── __init__.py
├── conftest.py              # プロジェクト全体のフィクスチャと設定
├── unit/                    # ユニットテスト
│   ├── test_config.py
│   ├── test_graph_client.py
│   └── test_powershell_bridge.py
├── integration/             # 統合テスト
│   ├── test_graph_api_integration.py
│   └── test_graph_api_compatibility.py
├── compatibility/           # PowerShell互換性テスト
│   ├── test_feature_compatibility.py
│   └── test_powershell_output_compatibility.py
├── performance/             # パフォーマンステスト
├── security/                # セキュリティテスト
├── edge_cases/              # エッジケーステスト
└── e2e/                     # エンドツーエンドテスト
```

## テスト実行コマンド

### 基本的な実行
```bash
# 全テスト実行
pytest

# 特定のディレクトリのみ実行
pytest Tests/unit/

# 特定のファイルのみ実行
pytest Tests/unit/test_config.py

# 特定のテストのみ実行
pytest Tests/unit/test_config.py::TestConfig::test_load_existing_config
```

### マーカーを使用した実行
```bash
# ユニットテストのみ実行
pytest -m unit

# 統合テストのみ実行
pytest -m integration

# PowerShell互換性テストのみ実行
pytest -m compatibility

# 低速テストを除外
pytest -m "not slow"

# 認証が必要なテストを除外
pytest -m "not requires_auth"

# モックデータテストのみ実行
pytest -m mock_data
```

### カバレッジ付き実行
```bash
# カバレッジレポート生成
pytest --cov=src --cov-report=html

# 特定モジュールのカバレッジ
pytest --cov=src.core --cov-report=term-missing

# カバレッジ閾値設定
pytest --cov=src --cov-fail-under=80
```

### 並列実行
```bash
# 自動並列実行
pytest -n auto

# 4プロセスで並列実行
pytest -n 4

# CPUコア数に基づく並列実行
pytest -n logical
```

### デバッグモード
```bash
# 詳細出力
pytest -vv

# 失敗時にPDBデバッガー起動
pytest --pdb

# 最初の失敗で停止
pytest -x

# 標準出力を表示
pytest -s
```

## テスト作成のベストプラクティス

### 1. テストクラスと関数の命名規則

```python
# ✅ 良い例
class TestConfig:
    def test_load_existing_config(self):
        pass
    
    def test_save_creates_directory(self):
        pass

# ❌ 悪い例
class ConfigTests:  # "Test" プレフィックスがない
    def check_load(self):  # "test_" プレフィックスがない
        pass
```

### 2. フィクスチャの活用

```python
import pytest
from pathlib import Path

@pytest.fixture
def temp_config_file(tmp_path):
    """一時的な設定ファイルを作成"""
    config_path = tmp_path / "config.json"
    config_path.write_text('{"test": "data"}')
    return config_path

def test_config_loading(temp_config_file):
    """フィクスチャを使用したテスト"""
    config = Config(temp_config_file)
    assert config.load() == {"test": "data"}
```

### 3. パラメータ化テスト

```python
@pytest.mark.parametrize("input_value,expected", [
    ("user@example.com", True),
    ("invalid-email", False),
    ("", False),
    (None, False),
])
def test_email_validation(input_value, expected):
    """複数の入力値でテスト"""
    assert validate_email(input_value) == expected
```

### 4. PowerShell互換性テスト

```python
@pytest.mark.compatibility
@pytest.mark.requires_powershell
class TestPowerShellCompatibility:
    def test_output_format_matches_powershell(self, powershell_bridge):
        """PowerShell出力との互換性確認"""
        # Python実装の結果
        python_result = get_users()
        
        # PowerShell実行結果
        ps_result = powershell_bridge.execute_script(
            "Scripts/EntraID/Get-EntraIDUsers.ps1"
        )
        
        # 出力形式の比較
        assert_output_compatible(python_result, ps_result)
```

### 5. モックの使用

```python
from unittest.mock import Mock, patch

def test_graph_api_call():
    """Microsoft Graph APIのモック"""
    with patch('src.api.graph.client.GraphClient') as mock_client:
        mock_instance = mock_client.return_value
        mock_instance.get_users.return_value = {
            "value": [{"id": "123", "displayName": "Test User"}]
        }
        
        # テスト実行
        result = list_users()
        assert len(result) == 1
        assert result[0]["displayName"] == "Test User"
```

### 6. 非同期テスト

```python
@pytest.mark.asyncio
async def test_async_api_call():
    """非同期APIのテスト"""
    client = AsyncGraphClient()
    users = await client.get_users_async()
    assert len(users) > 0
```

### 7. エラーハンドリングテスト

```python
def test_invalid_config_raises_error():
    """例外発生のテスト"""
    with pytest.raises(ValueError, match="Invalid configuration"):
        Config({"invalid": "config"})
```

### 8. 一時ファイル・ディレクトリの使用

```python
def test_report_generation(tmp_path):
    """一時ディレクトリを使用したファイル出力テスト"""
    output_dir = tmp_path / "reports"
    output_dir.mkdir()
    
    generator = ReportGenerator(output_dir)
    report_path = generator.create_report({"data": "test"})
    
    assert report_path.exists()
    assert report_path.suffix == ".html"
```

## マーカーの使用ガイド

### 定義済みマーカー

```python
@pytest.mark.unit  # 単体テスト
@pytest.mark.integration  # 統合テスト
@pytest.mark.compatibility  # PowerShell互換性テスト
@pytest.mark.gui  # GUIテスト
@pytest.mark.api  # APIテスト
@pytest.mark.auth  # 認証テスト
@pytest.mark.slow  # 実行時間が長いテスト
@pytest.mark.requires_auth  # 実際の認証が必要
@pytest.mark.requires_powershell  # PowerShell環境が必要
@pytest.mark.e2e  # エンドツーエンドテスト
@pytest.mark.security  # セキュリティテスト
@pytest.mark.performance  # パフォーマンステスト
@pytest.mark.real_data  # 実データ使用
@pytest.mark.mock_data  # モックデータ使用
```

### カスタムマーカーの追加

```python
# pytest.iniに追加
markers =
    critical: クリティカルなテスト（CI必須）
    experimental: 実験的機能のテスト
```

## CI/CDでの実行

### GitHub Actions設定例

```yaml
- name: Run tests
  run: |
    # ユニットテストとカバレッジ
    pytest -m "unit" --cov=src --cov-report=xml
    
    # 統合テスト（認証不要）
    pytest -m "integration and not requires_auth"
    
    # PowerShell互換性テスト
    pytest -m "compatibility" --ci
```

## トラブルシューティング

### よくある問題と解決策

1. **インポートエラー**
   ```bash
   # プロジェクトルートからの実行
   python -m pytest Tests/
   ```

2. **PowerShellテストの失敗**
   ```bash
   # PowerShellバージョン確認
   pwsh --version
   
   # 実行ポリシー確認
   pwsh -Command "Get-ExecutionPolicy"
   ```

3. **カバレッジが低い**
   ```bash
   # 未テスト部分の確認
   pytest --cov=src --cov-report=term-missing
   ```

4. **テストが遅い**
   ```bash
   # 並列実行
   pytest -n auto
   
   # 低速テストをスキップ
   pytest -m "not slow"
   ```

## テスト作成チェックリスト

- [ ] テスト関数名は`test_`で開始
- [ ] 適切なマーカーを付与
- [ ] フィクスチャを活用
- [ ] エラーケースをテスト
- [ ] PowerShell互換性を確認（該当する場合）
- [ ] モックを適切に使用
- [ ] アサーションメッセージを追加
- [ ] ドキュメント文字列を記載

## 関連リソース

- [pytest公式ドキュメント](https://docs.pytest.org/)
- [pytest-cov](https://pytest-cov.readthedocs.io/)
- [pytest-mock](https://github.com/pytest-dev/pytest-mock)
- [pytest-asyncio](https://github.com/pytest-dev/pytest-asyncio)