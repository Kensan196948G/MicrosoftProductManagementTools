# Microsoft 365管理ツール - pytest テストスイート

Dev1 - Test/QA Developer による基盤構築

## 📋 概要

このディレクトリには、Microsoft 365管理ツールPython版の包括的なテストスイートが含まれています。PowerShell版との互換性を確保しながら、高品質なソフトウェア開発を支援します。

## 🏗️ テストアーキテクチャ

### テストカテゴリ構成

```
tests/
├── unit/                     # ユニットテスト
│   ├── test_gui_components.py    # GUIコンポーネント
│   └── __init__.py
├── integration/              # 統合テスト
│   ├── test_graph_api_integration.py  # Microsoft Graph API
│   └── __init__.py
├── compatibility/            # 互換性テスト
│   ├── test_powershell_output_compatibility.py  # PowerShell互換
│   └── __init__.py
├── security/                 # セキュリティテスト（将来実装）
├── performance/              # パフォーマンステスト（将来実装）
├── edge_cases/               # エッジケーステスト（将来実装）
├── coverage/                 # カバレッジ関連（将来実装）
├── conftest.py              # pytest共通設定・フィクスチャ
├── run_test_suite.py        # テストスイート実行ツール
└── README.md                # このファイル
```

## 🧪 実装済みテストスイート

### 1. ユニットテスト (`tests/unit/`)

#### GUI コンポーネントテスト (`test_gui_components.py`)
- **MockMainWindow**: 26機能ボタンを持つメインウィンドウのモック
- **MockLogViewer**: リアルタイムログビューアーのモック
- **テストクラス**:
  - `TestMainWindowGUI`: メインウィンドウの基本動作
  - `TestLogViewerGUI`: ログビューアーの機能
  - `TestGUIInteraction`: コンポーネント間相互作用
  - `TestGUIErrorHandling`: エラーハンドリング
  - `TestGUIStyleAndLayout`: スタイル・レイアウト
  - `TestGUIPerformance`: パフォーマンス

**主要機能テスト**:
- ウィンドウ初期化とレイアウト
- 26機能ボタンの動作確認
- プログレスバー・ログパネル機能
- ウィンドウリサイズ対応
- ボタン連打処理
- 大量ログパフォーマンス

### 2. 統合テスト (`tests/integration/`)

#### Microsoft Graph API統合テスト (`test_graph_api_integration.py`)
- **MockGraphClient**: Microsoft Graph APIクライアントの包括的モック
- **テストクラス**:
  - `TestGraphClientAuthentication`: 認証機能
  - `TestGraphClientUserOperations`: ユーザー操作
  - `TestGraphClientLicenseOperations`: ライセンス操作
  - `TestGraphClientUsageReports`: 使用状況レポート
  - `TestGraphClientGroupOperations`: グループ操作
  - `TestGraphClientPerformance`: パフォーマンス
  - `TestGraphClientErrorHandling`: エラーハンドリング
  - `TestGraphClientDataValidation`: データ検証

**モック機能**:
- 100ユーザー、2ライセンス、20グループのリアルなテストデータ
- トークンキャッシュ・有効期限管理
- フィルタリング・ページング・SELECT句対応
- API呼び出し履歴追跡
- 並行API呼び出し対応

### 3. 互換性テスト (`tests/compatibility/`)

#### PowerShell版出力互換性テスト (`test_powershell_output_compatibility.py`)
- **PowerShellOutputComparator**: PowerShell版との出力比較クラス
- **テストクラス**:
  - `TestBasicOutputCompatibility`: 基本的な出力互換性
  - `TestAdvancedOutputCompatibility`: 高度な互換性
  - `TestSpecialCharacterCompatibility`: 特殊文字・国際化
  - `TestEndToEndCompatibility`: エンドツーエンド

**比較機能**:
- CSV出力の詳細比較（構造・データ・エンコーディング）
- HTML構造比較（タグ・テーブル・スタイル）
- PowerShellスクリプト非同期実行
- UTF-8 BOM対応確認
- 大量データ処理性能比較

## ⚙️ pytest設定

### pytest.ini
包括的な設定を含む：
- **カスタムマーカー**: unit, integration, compatibility, gui, api, slow等
- **カバレッジ設定**: HTML・XML・JSON形式レポート
- **ログ設定**: CLI・ファイル両対応
- **タイムアウト設定**: 5分デフォルト
- **並列実行対応**: pytest-xdist準備済み

### conftest.py
豊富なフィクスチャを提供：
- **プロジェクト設定**: test_config, temp_dir, mock_config_file
- **Microsoft Graph API**: mock_graph_client, requests_mock_fixture
- **GUI テスト**: qapp, qtbot, mock_main_window
- **PowerShell互換性**: powershell_runner, compatibility_checker
- **テストデータ生成**: generate_mock_users, generate_mock_licenses

## 🚀 テスト実行方法

### 基本実行

```bash
# 全テスト実行
pytest tests/

# カテゴリ別実行
pytest tests/unit -m unit
pytest tests/integration -m integration  
pytest tests/compatibility -m compatibility

# GUIテスト実行
pytest tests/ -m gui

# 詳細出力
pytest tests/ -v --tb=short

# カバレッジ付き実行
pytest tests/ --cov=src --cov-report=html
```

### 高度なオプション

```bash
# PowerShell必須テストをスキップ
pytest tests/ -m "not requires_powershell"

# 認証必須テストをスキップ  
pytest tests/ -m "not requires_auth"

# 低速テストをスキップ
pytest tests/ -m "not slow"

# 並列実行
pytest tests/ -n auto

# 特定のテストファイル実行
pytest tests/unit/test_gui_components.py::TestMainWindowGUI::test_button_click_functionality
```

### 統合実行ツール

```bash
# 包括的テストスイート実行
python tests/run_test_suite.py --category all --verbose

# PowerShellスキップモード
python tests/run_test_suite.py --skip-powershell

# GUIスキップモード  
python tests/run_test_suite.py --skip-gui

# レポートのみ生成
python tests/run_test_suite.py --report-only
```

### Makefile コマンド

```bash
# 依存関係インストール
make install

# 基本テスト実行
make test

# カテゴリ別テスト
make test-unit
make test-integration
make test-compatibility
make test-gui

# 包括的テスト（レポート付き）
make test-all

# CI環境テスト
make test-ci

# コード品質チェック
make lint
make format
make security

# 開発環境セットアップ
make dev-setup
```

## 📊 レポート出力

### 自動生成レポート

テスト実行により以下のレポートが `TestScripts/TestReports/` に生成されます：

1. **包括的HTMLレポート**: `comprehensive-test-report_YYYYMMDD_HHMMSS.html`
   - 実行サマリー・成功率・詳細結果
   - インタラクティブな詳細表示
   - 環境情報・実行統計

2. **CSVサマリー**: `comprehensive-test-summary_YYYYMMDD_HHMMSS.csv`
   - カテゴリ別実行結果
   - PowerShell版互換レポート形式

3. **JSONデータ**: `comprehensive-test-data_YYYYMMDD_HHMMSS.json`
   - 機械可読な詳細データ
   - CI/CD パイプライン統合用

### カバレッジレポート

- **HTML**: `htmlcov/index.html` - ブラウザ表示用
- **XML**: `coverage.xml` - CI/CD統合用
- **JSON**: `coverage.json` - 解析用

## 🔧 CI/CD統合

### GitHub Actions ワークフロー (`.github/workflows/pytest-ci.yml`)

包括的なCI/CDパイプラインを提供：

#### ジョブ構成
1. **unit-tests**: Python 3.9-3.12 マトリックステスト
2. **integration-tests**: 統合テスト実行
3. **compatibility-tests**: PowerShellなし互換性テスト
4. **gui-tests**: GUIテスト（xvfb使用）
5. **windows-compatibility**: Windows環境テスト
6. **security-scan**: bandit・safety セキュリティスキャン
7. **code-quality**: black・flake8・mypy品質チェック
8. **comprehensive-report**: 包括レポート生成
9. **deploy-docs**: GitHub Pages公開

#### 主要機能
- **アーティファクト保存**: 全テスト結果・レポート保持
- **Codecov統合**: カバレッジ結果自動アップロード  
- **並列実行**: 効率的なパイプライン実行
- **クロスプラットフォーム**: Ubuntu・Windows対応
- **セキュリティ重視**: 機密情報スキップ・スキャン実行

## 🎯 テストマーカー

カスタムマーカーによる柔軟なテスト分類：

### 基本マーカー
- `unit`: ユニットテスト
- `integration`: 統合テスト
- `compatibility`: 互換性テスト
- `gui`: GUIテスト

### 実行環境マーカー
- `requires_auth`: Microsoft 365認証必須
- `requires_powershell`: PowerShell実行必須
- `slow`: 実行時間が長いテスト

### 機能マーカー
- `api`: Microsoft Graph API関連
- `security`: セキュリティ関連
- `performance`: パフォーマンス関連

### 使用例

```bash
# 認証が不要なテストのみ実行
pytest tests/ -m "not requires_auth"

# GUIと統合テストのみ実行
pytest tests/ -m "gui or integration"

# 高速テストのみ実行（CI用）
pytest tests/ -m "not slow and not requires_auth and not requires_powershell"
```

## 🛠️ 開発者向けガイド

### 新しいテストの追加

1. **適切なディレクトリに配置**:
   - ユニットテスト → `tests/unit/`
   - 統合テスト → `tests/integration/`
   - 互換性テスト → `tests/compatibility/`

2. **命名規則に従う**:
   - ファイル名: `test_*.py`
   - クラス名: `Test*`
   - 関数名: `test_*`

3. **適切なマーカーを付与**:
   ```python
   @pytest.mark.unit
   @pytest.mark.gui
   def test_new_feature(self):
       pass
   ```

4. **フィクスチャを活用**:
   ```python
   def test_with_fixtures(self, mock_graph_client, temp_dir):
       # テスト実装
       pass
   ```

### フィクスチャの拡張

`conftest.py` に新しいフィクスチャを追加：

```python
@pytest.fixture(scope="function")
def custom_fixture():
    # セットアップ
    yield "test_data"
    # クリーンアップ
```

### PowerShell互換性テストの追加

1. PowerShell実行用フィクスチャ活用:
   ```python
   @pytest.mark.compatibility
   @pytest.mark.requires_powershell
   async def test_new_compatibility(self, powershell_runner):
       result = await powershell_runner.run_script("new-test.ps1")
       assert result["success"]
   ```

2. 出力比較の実装:
   ```python
   def test_output_comparison(self, compatibility_checker):
       comparison = compatibility_checker.compare_csv_files(py_file, ps_file)
       assert comparison["success"]
   ```

## 📈 品質メトリクス目標

### テストカバレッジ
- **目標**: 80%以上
- **現在**: 構築中（基盤完成）
- **重点領域**: コアロジック・API統合・GUI機能

### テスト成功率
- **CI環境**: 95%以上
- **ローカル環境**: 90%以上（環境依存を考慮）

### パフォーマンス
- **テスト実行時間**: 15分以内（全カテゴリ）
- **ユニットテスト**: 5分以内
- **統合テスト**: 10分以内

## 🔍 トラブルシューティング

### よくある問題

#### GUI テストが失敗する
```bash
# Linux環境では仮想ディスプレイが必要
xvfb-run -a pytest tests/ -m gui
```

#### PowerShell互換性テストがスキップされる
```bash
# PowerShellが利用可能か確認
pwsh --version

# PowerShellテストを明示的に実行
pytest tests/compatibility -m requires_powershell --powershell
```

#### 依存関係エラー
```bash
# 依存関係を再インストール
make install
# または
pip install -r requirements.txt -e .
```

### ログレベル調整

```bash
# デバッグレベルでログ出力
pytest tests/ --log-cli-level=DEBUG

# 特定のモジュールのみ
pytest tests/ --log-cli-format="%(name)s: %(message)s"
```

## 🤝 貢献ガイドライン

### テスト品質基準

1. **明確なテスト名**: 何をテストするかが分かる名前
2. **独立性**: 他のテストに依存しない
3. **再現性**: 同じ条件で同じ結果
4. **高速実行**: 不要な待機時間を避ける
5. **適切なアサーション**: 期待値を明確に検証

### コードレビューチェックリスト

- [ ] 適切なマーカーが付与されている
- [ ] フィクスチャが適切に使用されている
- [ ] エラーハンドリングが適切
- [ ] ドキュメントが更新されている
- [ ] CI/CDパイプラインが通過する

## 📚 参考資料

- [pytest公式ドキュメント](https://docs.pytest.org/)
- [pytest-qt ドキュメント](https://pytest-qt.readthedocs.io/)
- [pytest-cov ドキュメント](https://pytest-cov.readthedocs.io/)
- [Microsoft Graph SDK for Python](https://github.com/microsoftgraph/msgraph-sdk-python)
- [PowerShell版テストスクリプト](../TestScripts/)

---

**Dev1 - Test/QA Developer** による基盤構築 - Microsoft 365管理ツール pytest テストスイート