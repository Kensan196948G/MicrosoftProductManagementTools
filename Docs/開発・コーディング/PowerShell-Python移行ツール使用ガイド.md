# PowerShell-Python移行ツール使用ガイド

## 概要

このガイドでは、PowerShellコードをPythonに移行するための自動化ツールの使用方法を説明します。

## 移行ツールの構成

### 1. PowerShellブリッジ (`src/core/powershell_bridge.py`)
- 既存のPowerShellスクリプトをPythonから実行
- 型変換とデータマッピング
- 非同期実行サポート
- エラーハンドリングと再試行機能

### 2. 変換エンジン (`src/migration/ps_to_py_converter.py`)
- PowerShell構文をPython構文に自動変換
- 3つの変換レベル：FULL（完全変換）、BRIDGE（ブリッジ経由）、HYBRID（ハイブリッド）
- コマンドレット、制御構造、型システムの変換

### 3. 移行ヘルパー (`src/migration/migration_helper.py`)
- プロジェクト全体の分析と移行計画作成
- フェーズごとの段階的移行
- 進捗管理とレポート生成

## クイックスタート

### 1. 環境準備

```bash
# Python仮想環境の作成
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/macOS
source venv/bin/activate

# 依存関係のインストール
pip install -r requirements.txt
```

### 2. プロジェクト分析

```python
from pathlib import Path
from src.migration.migration_helper import MigrationHelper

# 移行ヘルパーの初期化
helper = MigrationHelper(Path.cwd())

# プロジェクト全体を分析
plan = helper.analyze_project()
print(f"移行対象ファイル数: {plan.total_files}")

# 移行計画の確認
for phase, files in plan.phases.items():
    print(f"\n{phase}: {len(files)}ファイル")
    for file in files[:3]:  # 最初の3ファイルを表示
        print(f"  - {file}")
```

### 3. 単一ファイルの移行

```python
# PowerShellファイルを指定
ps_file = Path("Scripts/Common/Common.psm1")

# 移行実行
success, message = helper.migrate_file(ps_file)
print(message)
```

### 4. フェーズごとの移行

```python
# フェーズ1（コア機能）を移行
results = helper.migrate_phase('phase1_core')

# 結果確認
for file, success in results.items():
    status = "✅" if success else "❌"
    print(f"{status} {file}")
```

## PowerShellブリッジの使用

### 基本的な使用方法

```python
from src.core.powershell_bridge import PowerShellBridge

# ブリッジの初期化
bridge = PowerShellBridge()

# PowerShellコマンドの実行
result = bridge.execute_command('Get-Date')
if result.success:
    print(f"現在時刻: {result.data}")

# PowerShellスクリプトの実行
result = bridge.execute_script(
    "Scripts/EXO/Get-MailboxStatistics.ps1",
    parameters={"Identity": "user@company.com"}
)
```

### 非同期実行

```python
import asyncio

async def run_async_commands():
    # 非同期でコマンド実行
    result = await bridge.execute_command_async('Get-MgUser -All')
    
    # バッチ実行
    commands = ['Get-Date', 'Get-Process', 'Get-Service']
    results = await bridge.execute_batch_async(commands)
    
    return results

# 実行
results = asyncio.run(run_async_commands())
```

### Microsoft 365 API統合

```python
# Graph API接続
result = bridge.connect_graph(
    tenant_id="your-tenant-id",
    client_id="your-client-id",
    certificate_thumbprint="cert-thumbprint"
)

# ユーザー情報取得
users = bridge.get_users(
    properties=["displayName", "mail", "department"],
    filter_query="accountEnabled eq true"
)

# ライセンス情報取得
licenses = bridge.get_licenses()
```

## 変換エンジンの使用

### 基本的な変換

```python
from src.migration.ps_to_py_converter import PowerShellToPythonConverter, ConversionLevel

# 変換エンジンの初期化
converter = PowerShellToPythonConverter(ConversionLevel.HYBRID)

# PowerShellコードの変換
ps_code = '''
function Get-UserInfo {
    param([string]$UserName)
    
    $user = Get-MgUser -Filter "displayName eq '$UserName'"
    if ($user) {
        Write-Host "User found: $($user.DisplayName)"
        return $user
    }
    return $null
}
'''

result = converter.convert_code(ps_code)
print(result.python_code)
```

### スクリプト分析

```python
# PowerShellスクリプトの複雑さを分析
analysis = converter.analyze_script(Path("Scripts/AD/Get-ADReport.ps1"))

print(f"行数: {analysis['lines']}")
print(f"関数数: {analysis['functions']}")
print(f"複雑度: {analysis['complexity']}")
print(f"ブリッジ必要: {analysis['bridge_required']}")
```

## 移行戦略

### フェーズ1: コア機能（依存関係なし）
- `Scripts/Common/*.psm1`
- 認証、ログ、エラーハンドリング
- 完全Python実装可能

### フェーズ2: API統合
- Microsoft Graph API呼び出し
- Exchange Online管理
- 一部PowerShellブリッジ使用

### フェーズ3: GUI機能
- Windows FormsからPyQt6への移行
- 大規模な書き換えが必要

### フェーズ4: その他のスクリプト
- バッチ処理、レポート生成
- 段階的に移行

## 互換性テスト

### テストの生成

```python
# 互換性テストを自動生成
test_code = helper.generate_compatibility_tests(
    ps_file=Path("Scripts/Common/Common.psm1"),
    py_file=Path("src/common/common.py")
)

# テストファイルとして保存
with open("Tests/compatibility/test_common_compat.py", "w") as f:
    f.write(test_code)
```

### テストの実行

```bash
# 単体テスト
pytest Tests/unit/test_powershell_bridge.py -v

# 互換性テスト
pytest Tests/compatibility/ -v

# 統合テスト（実際のPowerShell環境が必要）
pytest Tests/integration/ -v -m integration
```

## レポートとモニタリング

### 移行レポートの生成

```python
# 進捗レポート生成
report = helper.create_migration_report()

# ファイルに保存
with open("migration_report.md", "w") as f:
    f.write(report)
```

### ステータス確認

```python
# 現在の移行ステータス
for file, status in helper.migration_status.items():
    print(f"{file}: {status.status}")
    if status.bridge_dependencies:
        print(f"  ブリッジ依存: {', '.join(status.bridge_dependencies)}")
```

## トラブルシューティング

### よくある問題

1. **PowerShellが見つからない**
   ```python
   # PowerShellパスを明示的に指定
   bridge = PowerShellBridge()
   bridge.pwsh_exe = r"C:\Program Files\PowerShell\7\pwsh.exe"
   ```

2. **文字エンコーディングエラー**
   ```python
   # UTF-8 with BOMを使用
   result = bridge.execute_command(command, encoding='utf-8-sig')
   ```

3. **型変換エラー**
   ```python
   # カスタム型変換を追加
   converted_data = bridge._convert_ps_to_python(ps_data)
   ```

### デバッグモード

```python
# 詳細ログを有効化
import logging
logging.basicConfig(level=logging.DEBUG)

# 変換前後のコードを確認
result = converter.convert_code(ps_code)
print("=== 元のコード ===")
print(ps_code)
print("\n=== 変換後 ===")
print(result.python_code)
print("\n=== 警告 ===")
print(result.warnings)
```

## ベストプラクティス

### 1. 段階的移行
- 依存関係の少ないモジュールから開始
- 各フェーズ完了後にテスト実施
- ロールバック計画を準備

### 2. ブリッジの活用
- 複雑なPowerShell機能は当面ブリッジ経由で
- 段階的にネイティブPython実装へ移行
- パフォーマンスクリティカルな部分を優先

### 3. テストの重要性
- 変換前後の動作を必ず比較
- 自動テストを充実させる
- 実環境でのテストを実施

### 4. ドキュメント化
- 変換ルールをドキュメント化
- 移行の決定事項を記録
- 既知の問題と回避策を共有

## 次のステップ

1. **パイロット移行**
   - 小規模なモジュールで試験的に実施
   - 問題点の洗い出し

2. **ツールの改善**
   - 変換ルールの追加
   - エッジケースへの対応

3. **チーム教育**
   - Python開発のベストプラクティス
   - 移行ツールの使用方法

4. **本格移行**
   - フェーズごとの計画実行
   - 継続的な改善

---

作成日: 2025年1月18日  
バージョン: 1.0