# PowerShellBridge互換性テストスイート

このディレクトリには、PowerShellとPythonの相互運用性を検証するための包括的なテストスイートが含まれています。

## 📋 概要

PowerShellBridge互換性テストは、Python版の実装がPowerShell版と同じ結果を生成することを確認するためのテストです。CI/CD環境でも実行可能で、実際のPowerShellを使用せずにモック化されたテストを実行できます。

## 🗂️ ファイル構成

```
Tests/compatibility/
├── __init__.py                           # モジュール初期化
├── conftest.py                           # pytest設定とフィクスチャー
├── test_powershell_bridge.py            # PowerShellBridge基本機能テスト
├── test_data_format_compatibility.py    # データフォーマット互換性テスト
├── test_advanced_scenarios.py           # 高度なシナリオテスト
└── README.md                            # このファイル
```

## 🧪 テストファイル詳細

### 1. test_powershell_bridge.py
PowerShellBridgeクラスの基本機能をテストします。

**テストカテゴリ:**
- 初期化とPowerShell検出
- コマンド実行（同期・非同期）
- モジュールインポート
- 関数呼び出し
- エラーハンドリング
- 型変換
- Microsoft 365 API統合
- バッチ処理

**テスト数:** 32テストメソッド, 4テストクラス

### 2. test_data_format_compatibility.py
PowerShellとPythonの出力形式の互換性をテストします。

**テストカテゴリ:**
- CSV出力形式
- HTML出力形式
- JSON形式
- 日時形式
- サイズ表記
- 文字エンコーディング
- 特殊文字処理

**テスト数:** 18テストメソッド, 2テストクラス

### 3. test_advanced_scenarios.py
高度なシナリオと実際の使用例をテストします。

**テストカテゴリ:**
- 非同期処理
- パフォーマンス測定
- エッジケース
- 実際のワークフロー
- 大量データ処理
- 並行処理

**テスト数:** 19テストメソッド, 4テストクラス

### 4. conftest.py
pytest設定とテスト用フィクスチャーを提供します。

**含まれるフィクスチャー:**
- `mock_m365_users` - Microsoft 365ユーザーデータ
- `mock_m365_licenses` - ライセンス情報
- `mock_exchange_mailboxes` - Exchange Onlineメールボックス
- `mock_teams_usage` - Teams使用状況
- `mock_onedrive_storage` - OneDriveストレージ
- `mock_mfa_status` - MFA状況
- `mock_conditional_access_policies` - 条件付きアクセスポリシー
- `mock_signin_logs` - サインインログ
- `mock_powershell_error_scenarios` - エラーシナリオ
- `performance_test_data` - パフォーマンステスト用データ

## 🚀 実行方法

### 1. 基本実行
```bash
# 全テスト実行
python3 Tests/run_powershell_bridge_tests.py

# または pytest を直接使用
python3 -m pytest Tests/compatibility/ -v
```

### 2. オプション付き実行
```bash
# コードカバレッジ測定
python3 Tests/run_powershell_bridge_tests.py --coverage

# クイックテスト（時間のかかるテストを除外）
python3 Tests/run_powershell_bridge_tests.py --quick

# HTMLレポート生成
python3 Tests/run_powershell_bridge_tests.py --html-report

# XML JUnitレポート生成（CI/CD用）
python3 Tests/run_powershell_bridge_tests.py --xml-report

# 特定のテストパターンのみ実行
python3 Tests/run_powershell_bridge_tests.py -k "test_execute_command"
python3 Tests/run_powershell_bridge_tests.py -k "compatibility"
python3 Tests/run_powershell_bridge_tests.py -k "async"
```

### 3. 事前チェック
```bash
# テストセットアップ確認
python3 Tests/verify_test_setup.py

# 利用可能なテスト一覧表示
python3 Tests/run_powershell_bridge_tests.py --list

# 前提条件チェック
python3 Tests/run_powershell_bridge_tests.py --check
```

## 📊 テスト結果

### 現在の統計
- **総テスト数:** 69テストメソッド
- **テストクラス:** 10クラス
- **フィクスチャー:** 6個
- **総行数:** 約1,700行

### 出力ファイル
テスト実行後、以下のファイルが生成されます：

```
TestOutput/
├── powershell_bridge_tests.log          # テスト実行ログ
├── powershell_bridge_report_*.html      # HTMLレポート
├── powershell_bridge_junit_*.xml        # XML JUnitレポート
└── coverage_powershell_bridge/          # カバレッジレポート
    ├── index.html                       # カバレッジHTMLレポート
    └── coverage_powershell_bridge.json  # カバレッジJSONデータ
```

## 🔧 CI/CD統合

### GitHub Actions例
```yaml
name: PowerShellBridge互換性テスト

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install pytest pytest-cov pytest-html
    
    - name: Run PowerShellBridge tests
      run: |
        python Tests/run_powershell_bridge_tests.py --xml-report --coverage
    
    - name: Upload test results
      uses: actions/upload-artifact@v2
      if: always()
      with:
        name: test-results
        path: TestOutput/
```

## 🎯 テストの特徴

### 1. モック化されたテスト
- 実際のPowerShellやMicrosoft 365サービスを使用しない
- CI/CD環境での実行が可能
- 高速で安定したテスト実行

### 2. 包括的なカバレッジ
- PowerShellBridgeクラスの全機能をテスト
- 各種データ形式の互換性を検証
- エラーハンドリングとエッジケースを含む

### 3. 実際のデータ形式
- PowerShellの実際の出力形式を模倣
- Microsoft 365 APIの実際のレスポンス形式
- 日本語文字列とエンコーディングの処理

### 4. パフォーマンス測定
- 非同期処理の性能テスト
- 大量データ処理の検証
- 並行処理の正確性確認

## 🐛 トラブルシューティング

### よくある問題と解決策

1. **ModuleNotFoundError: No module named 'pytest'**
   ```bash
   pip install pytest pytest-cov pytest-html
   ```

2. **ImportError: cannot import name 'PowerShellBridge'**
   ```bash
   # プロジェクトルートから実行していることを確認
   python3 Tests/verify_test_setup.py
   ```

3. **テストが一部失敗する**
   ```bash
   # 詳細なエラー情報を確認
   python3 Tests/run_powershell_bridge_tests.py -v
   ```

4. **カバレッジレポートが生成されない**
   ```bash
   # pytest-covがインストールされていることを確認
   pip install pytest-cov
   ```

## 📈 今後の拡張予定

- [ ] 実際のPowerShellとの統合テスト
- [ ] より多くのMicrosoft 365サービスのテスト
- [ ] パフォーマンスベンチマークの追加
- [ ] 自動化されたレグレッションテスト
- [ ] クロスプラットフォーム対応テスト

## 🤝 貢献

テストの改善や新しいテストケースの追加は歓迎します。

1. テストファイルを追加する場合は、適切なドキュメントを含める
2. フィクスチャーは`conftest.py`に集約する
3. テストメソッド名は明確で分かりやすくする
4. 必要に応じてマーカーを使用する（`@pytest.mark.slow`など）

## 📞 サポート

質問や問題がある場合は、以下のファイルを確認してください：

- `Tests/verify_test_setup.py` - セットアップ確認
- `Tests/run_powershell_bridge_tests.py --help` - 使用方法
- `src/core/powershell_bridge.py` - PowerShellBridge実装

---

**作成者:** Dev1 - Test/QA Developer  
**更新日:** 2025-01-18  
**バージョン:** 2.0.0