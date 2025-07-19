# Microsoft 365 Management Tools - GUI Testing Framework

完全な PyQt6 GUI テストスイート for Microsoft 365 管理ツール

## 🧪 テストフレームワーク概要

### 技術スタック
- **pytest**: メインテストフレームワーク
- **pytest-qt**: PyQt6 GUI テスト専用プラグイン
- **PyQt6**: GUI フレームワーク
- **pytest-asyncio**: 非同期テスト対応
- **pytest-mock**: モック機能強化
- **psutil**: パフォーマンス監視

### テストカバレッジ
- ✅ **GUI コンポーネント**: すべての PyQt6 ウィジェット
- ✅ **ボタン管理**: Enhanced Button Manager の 26 機能
- ✅ **リアルタイムダッシュボード**: WebSocket 統合
- ✅ **パフォーマンス**: メモリ・CPU 使用量監視
- ✅ **統合テスト**: エンドツーエンドワークフロー
- ✅ **アクセシビリティ**: キーボードナビゲーション

## 📁 ディレクトリ構造

```
src/tests/
├── conftest.py              # 共通フィクスチャとテスト設定
├── pytest.ini              # pytest 設定ファイル
├── requirements.txt         # テスト依存関係
├── run_tests.py            # 高度なテストランナー
├── README.md               # このファイル
│
├── gui/                    # GUI テストスイート
│   ├── test_main_window.py           # メインウィンドウテスト
│   ├── test_enhanced_button_manager.py  # ボタン管理テスト
│   └── test_realtime_dashboard.py    # ダッシュボードテスト
│
├── integration/            # 統合テスト（将来追加）
├── unit/                  # ユニットテスト（将来追加）
└── reports/               # テストレポート出力
```

## 🚀 クイックスタート

### 1. 依存関係インストール

```bash
# テスト依存関係インストール
pip install -r src/tests/requirements.txt

# またはプロジェクトルートから
pip install -r src/tests/requirements.txt
```

### 2. 基本テスト実行

```bash
# プロジェクトルートディレクトリから実行

# 全テスト実行
python src/tests/run_tests.py

# GUI テストのみ実行
python src/tests/run_tests.py --gui

# 煙テスト（クイック検証）
python src/tests/run_tests.py --smoke

# パフォーマンステスト
python src/tests/run_tests.py --performance
```

### 3. ヘッドレス実行（CI/CD 用）

```bash
# ヘッドレスモードで実行（Xvfb 必要）
python src/tests/run_tests.py --headless --gui

# Ubuntu/Debian で Xvfb インストール
sudo apt-get install xvfb
```

## 📊 テストカテゴリ

### GUI テスト (`gui/`)

#### メインウィンドウテスト (`test_main_window.py`)
- ✅ ウィンドウ初期化と基本レイアウト
- ✅ ボタンマネージャー統合
- ✅ キーボードショートカット
- ✅ リアルタイムダッシュボード統合
- ✅ ログビューアー機能
- ✅ WebSocket 接続処理
- ✅ レスポンシブレイアウト
- ✅ エラーハンドリングワークフロー

```python
# 実行例
pytest src/tests/gui/test_main_window.py -v
python src/tests/run_tests.py gui/test_main_window.py
```

#### Enhanced Button Manager テスト (`test_enhanced_button_manager.py`)
- ✅ ボタン設定とコンフィグレーション
- ✅ 状態管理（IDLE/LOADING/SUCCESS/ERROR）
- ✅ アニメーション効果
- ✅ レスポンシブレイアウト
- ✅ カテゴリ別ボタンフィルタリング
- ✅ 一括操作（有効化/無効化）
- ✅ パフォーマンステスト

```python
# 実行例
pytest src/tests/gui/test_enhanced_button_manager.py::TestButtonState -v
```

#### Real-time Dashboard テスト (`test_realtime_dashboard.py`)
- ✅ ダッシュボードウィジェット初期化
- ✅ メトリクス更新とビジュアライゼーション
- ✅ プログレス追跡
- ✅ ログエントリー処理
- ✅ WebSocket メッセージハンドリング
- ✅ チャート統合
- ✅ 大量データ処理

```python
# 実行例
pytest src/tests/gui/test_realtime_dashboard.py::TestWebSocketIntegration -v
```

## 🎯 テストマーカー

pytest マーカーでテストをフィルタリング:

```bash
# 高速テストのみ
pytest -m "not slow"

# GUI テストのみ
pytest -m gui

# パフォーマンステスト
pytest -m performance

# 統合テスト
pytest -m integration

# 特定のマーカーを除外
pytest -m "not stress"
```

### 利用可能マーカー
- `gui`: GUI テスト
- `slow`: 実行時間の長いテスト
- `fast`: 高速テスト
- `performance`: パフォーマンステスト
- `stress`: ストレステスト
- `integration`: 統合テスト
- `unit`: ユニットテスト
- `smoke`: 煙テスト
- `websocket`: WebSocket 関連テスト
- `mock`: 大量のモックを使用するテスト

## 📈 詳細なテスト実行オプション

### 基本実行

```bash
# 標準実行
python src/tests/run_tests.py

# 詳細出力
python src/tests/run_tests.py --verbose

# 静音出力
python src/tests/run_tests.py --quiet
```

### 並列実行

```bash
# 並列実行（pytest-xdist 必要）
python src/tests/run_tests.py --parallel

# CPU コア数を指定
pytest -n 4 src/tests/
```

### カバレッジレポート

```bash
# カバレッジ付き実行
python src/tests/run_tests.py

# カバレッジレポートのみ生成
python src/tests/run_tests.py --coverage-only

# カバレッジなしで実行
python src/tests/run_tests.py --no-coverage
```

### 特定テスト実行

```bash
# 特定ファイル
python src/tests/run_tests.py gui/test_main_window.py

# 特定テスト関数
python src/tests/run_tests.py gui/test_main_window.py::test_window_initialization

# 特定テストクラス
pytest src/tests/gui/test_enhanced_button_manager.py::TestButtonConfig
```

## 🔧 設定とカスタマイズ

### pytest.ini 設定

```ini
[tool:pytest]
testpaths = src/tests
addopts = 
    --strict-markers
    --verbose
    --cov=src/gui
    --cov-report=html
    --timeout=300
```

### 環境変数

```bash
# デバッグモード
export PYTEST_DEBUG=1

# GUI テスト用ディスプレイ設定
export DISPLAY=:0

# ヘッドレスモード
export QT_QPA_PLATFORM=offscreen
```

## 🎨 Visual Testing（将来実装）

```python
# スクリーンショット比較テスト（計画中）
def test_visual_regression(qtbot, main_window):
    """Visual regression testing"""
    # ウィジェットのスクリーンショット撮影
    screenshot = main_window.grab()
    
    # ベースライン画像と比較
    # assert_images_equal(screenshot, "baseline/main_window.png")
```

## 🚨 CI/CD 統合

### GitHub Actions 例

```yaml
name: GUI Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'
    
    - name: Install system dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y xvfb
    
    - name: Install dependencies
      run: |
        pip install -r src/tests/requirements.txt
    
    - name: Run tests
      run: |
        python src/tests/run_tests.py --headless --gui
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

## 🐛 デバッグとトラブルシューティング

### 一般的な問題

#### 1. PyQt6 インポートエラー
```bash
# 解決方法
pip install PyQt6 PyQt6-Charts PyQt6-WebEngine
```

#### 2. Display エラー（ヘッドレス環境）
```bash
# Xvfb インストール
sudo apt-get install xvfb

# または offscreen プラットフォーム使用
export QT_QPA_PLATFORM=offscreen
```

#### 3. テストタイムアウト
```bash
# タイムアウト延長
python src/tests/run_tests.py --timeout 600
```

### デバッグ用実行

```bash
# デバッグ出力付き
pytest -s -vv src/tests/gui/

# 失敗時に pdb 起動
pytest --pdb src/tests/gui/

# 最初の失敗で停止
pytest -x src/tests/gui/
```

## 📋 ベストプラクティス

### 1. テスト作成
- 各テストは独立して実行可能にする
- `qtbot.addWidget()` でウィジェットを適切に管理
- モックを活用して外部依存を排除
- アサーションメッセージを明確にする

### 2. パフォーマンス
- `qtbot.wait()` で UI 更新を待機
- 大量データテストには `@pytest.mark.slow` を使用
- メモリリークを監視

### 3. 保守性
- フィクスチャを活用して重複を避ける
- テストデータは `conftest.py` で管理
- わかりやすいテスト名を付ける

## 🔮 将来の拡張計画

### Phase 4 計画
- ✅ **Visual Regression Testing**: スクリーンショット比較
- ✅ **API Integration Tests**: 実際の Microsoft Graph API テスト
- ✅ **E2E Testing**: Selenium WebDriver 統合
- ✅ **Load Testing**: 大量データでのパフォーマンステスト
- ✅ **Accessibility Testing**: WCAG 準拠チェック

### 追加予定テスト
- 多言語対応テスト
- テーマ切り替えテスト
- プラグインシステムテスト
- セキュリティテスト

## 📞 サポート

### 問題報告
- GitHub Issues でバグ報告
- テストの失敗は詳細なログと共に報告
- 環境情報（OS、Python、PyQt6 バージョン）を含める

### 貢献
- 新しいテストケースの追加歓迎
- テストフレームワークの改善提案
- ドキュメントの更新

---

**開発者**: Frontend Developer (dev0)  
**バージョン**: 3.1.0  
**最終更新**: 2025-07-19