# PowerShell-Python互換性マッピングガイド

## 概要
このドキュメントは、Microsoft製品管理ツールのPowerShellコードをPythonに移行する際の互換性マッピングを提供します。

## 1. 基本構文マッピング

### 変数と型

| PowerShell | Python | 備考 |
|------------|--------|------|
| `$variable = "value"` | `variable = "value"` | $記号は不要 |
| `[string]$str = "text"` | `str: str = "text"` | 型アノテーション使用 |
| `[int]$num = 42` | `num: int = 42` | 型アノテーション使用 |
| `[array]$arr = @(1,2,3)` | `arr = [1, 2, 3]` | リスト使用 |
| `@{key="value"}` | `{"key": "value"}` | ハッシュテーブル→辞書 |
| `$null` | `None` | null値 |
| `$true/$false` | `True/False` | 大文字開始 |

### 条件分岐

| PowerShell | Python | 備考 |
|------------|--------|------|
| `if ($condition) { }` | `if condition:` | 括弧不要、コロン必須 |
| `elseif` | `elif` | スペルの違い |
| `switch ($var) { }` | `match var:` | Python 3.10以降 |
| `-eq, -ne, -gt, -lt` | `==, !=, >, <` | 演算子の違い |
| `-and, -or, -not` | `and, or, not` | 論理演算子 |

### ループ

| PowerShell | Python | 備考 |
|------------|--------|------|
| `foreach ($item in $list)` | `for item in list:` | foreach→for |
| `for ($i=0; $i -lt 10; $i++)` | `for i in range(10):` | range関数使用 |
| `while ($condition)` | `while condition:` | 基本的に同じ |
| `do { } while()` | なし | Pythonには存在しない |
| `break/continue` | `break/continue` | 同じ |

## 2. 関数とモジュール

### 関数定義

| PowerShell | Python | 備考 |
|------------|--------|------|
| `function Get-Data { }` | `def get_data():` | 命名規則の違い |
| `param([string]$name)` | `def func(name: str):` | パラメータ定義 |
| `[CmdletBinding()]` | `@dataclass` | データクラス使用 |
| `return $value` | `return value` | $記号不要 |
| `[OutputType([string])]` | `-> str:` | 戻り値の型アノテーション |

### モジュール

| PowerShell | Python | 備考 |
|------------|--------|------|
| `.psm1` ファイル | `.py` ファイル | モジュール拡張子 |
| `Import-Module` | `import` | モジュール読み込み |
| `Export-ModuleMember` | `__all__ = []` | エクスポート制御 |
| `$PSScriptRoot` | `__file__` | スクリプトパス |

## 3. エラーハンドリング

| PowerShell | Python | 備考 |
|------------|--------|------|
| `try { } catch { }` | `try: except:` | 基本構造 |
| `$_` or `$PSItem` | `e` (慣例) | 例外オブジェクト |
| `throw "message"` | `raise Exception("message")` | 例外発生 |
| `finally { }` | `finally:` | 最終処理 |
| `$Error[0]` | `sys.exc_info()` | 最新エラー情報 |

## 4. ファイル操作

| PowerShell | Python | 備考 |
|------------|--------|------|
| `Get-Content` | `open().read()` | ファイル読み込み |
| `Set-Content` | `open().write()` | ファイル書き込み |
| `Test-Path` | `os.path.exists()` | パス存在確認 |
| `New-Item -ItemType Directory` | `os.makedirs()` | ディレクトリ作成 |
| `Remove-Item` | `os.remove()` | ファイル削除 |
| `Get-ChildItem` | `os.listdir()` | ディレクトリ一覧 |

## 5. Microsoft 365 API マッピング

### 認証

| PowerShell | Python | 備考 |
|------------|--------|------|
| `Connect-MgGraph` | `PublicClientApplication()` | MSAL使用 |
| `Connect-ExchangeOnline` | カスタム実装必要 | REST API使用 |
| Certificate認証 | `load_pem_x509_certificate()` | cryptography使用 |

### Graph API

| PowerShell | Python | 備考 |
|------------|--------|------|
| `Get-MgUser` | `graph_client.users.get()` | SDK使用 |
| `Invoke-MgGraphRequest` | `requests.get()` | 直接API呼び出し |
| `-All` パラメータ | ページネーション処理 | 手動実装必要 |

### データ処理

| PowerShell | Python | 備考 |
|------------|--------|------|
| `Select-Object` | `[d['key'] for d in list]` | リスト内包表記 |
| `Where-Object` | `filter()` or 内包表記 | フィルタリング |
| `Sort-Object` | `sorted()` | ソート |
| `Group-Object` | `itertools.groupby()` | グループ化 |
| `Measure-Object` | `len()`, `sum()`, etc. | 集計関数 |

## 6. GUI マッピング

| PowerShell (WinForms) | Python (PyQt6) | 備考 |
|----------------------|----------------|------|
| `[System.Windows.Forms.Form]` | `QMainWindow` | メインウィンドウ |
| `Button` | `QPushButton` | ボタン |
| `TextBox` | `QLineEdit` | テキスト入力 |
| `Label` | `QLabel` | ラベル |
| `TabControl` | `QTabWidget` | タブコントロール |
| `DataGridView` | `QTableWidget` | テーブル |

## 7. 非同期処理

| PowerShell | Python | 備考 |
|------------|--------|------|
| `Start-Job` | `asyncio.create_task()` | 非同期タスク |
| `Receive-Job` | `await` | 結果取得 |
| `Wait-Job` | `asyncio.wait()` | 待機 |
| パイプライン `|` | ジェネレータ/async for | ストリーム処理 |

## 8. ログとデバッグ

| PowerShell | Python | 備考 |
|------------|--------|------|
| `Write-Host` | `print()` | コンソール出力 |
| `Write-Verbose` | `logging.debug()` | デバッグログ |
| `Write-Warning` | `logging.warning()` | 警告ログ |
| `Write-Error` | `logging.error()` | エラーログ |
| `Write-Output` | `return` or `yield` | 出力 |

## 9. 設定管理

| PowerShell | Python | 備考 |
|------------|--------|------|
| `appsettings.json` | `config.json` | 同じJSON形式 |
| `ConvertFrom-Json` | `json.loads()` | JSON解析 |
| `$env:VARIABLE` | `os.environ['VARIABLE']` | 環境変数 |
| `Get-Content | ConvertFrom-Json` | `json.load(open())` | ファイルからJSON読み込み |

## 10. テスト

| PowerShell | Python | 備考 |
|------------|--------|------|
| Pester | pytest | テストフレームワーク |
| `Describe` | `class TestClass:` | テストグループ |
| `It` | `def test_method():` | テストケース |
| `Should -Be` | `assert x == y` | アサーション |
| Mock | `@patch` | モック |

## 移行時の注意点

### 1. 命名規則
- PowerShell: `Verb-Noun` (PascalCase)
- Python: `snake_case`

### 2. 型システム
- PowerShell: 動的型付け（型キャスト可能）
- Python: 動的型付け（型アノテーション推奨）

### 3. パフォーマンス
- PowerShell: オブジェクトパイプライン
- Python: イテレータ/ジェネレータ使用

### 4. エンコーディング
- PowerShell: UTF-16デフォルト
- Python: UTF-8デフォルト

### 5. プラットフォーム依存
- PowerShell: Windows中心（Core版でクロスプラットフォーム）
- Python: 完全クロスプラットフォーム

## PowerShellブリッジ実装例

```python
import subprocess
import json
from typing import Any, Dict, List

class PowerShellBridge:
    """PowerShellコマンドをPythonから実行するブリッジクラス"""
    
    def __init__(self):
        self.pwsh_exe = "pwsh"  # PowerShell Core
        
    def execute_command(self, command: str) -> Dict[str, Any]:
        """PowerShellコマンドを実行し、結果を返す"""
        # JSON形式で結果を返すようにラップ
        wrapped_command = f"{command} | ConvertTo-Json -Depth 10"
        
        try:
            result = subprocess.run(
                [self.pwsh_exe, "-Command", wrapped_command],
                capture_output=True,
                text=True,
                check=True
            )
            
            # JSON解析
            if result.stdout:
                return json.loads(result.stdout)
            return {}
            
        except subprocess.CalledProcessError as e:
            raise Exception(f"PowerShell error: {e.stderr}")
    
    def import_module(self, module_path: str) -> None:
        """PowerShellモジュールをインポート"""
        command = f"Import-Module '{module_path}'"
        subprocess.run([self.pwsh_exe, "-Command", command], check=True)
    
    def call_function(self, function_name: str, **kwargs) -> Any:
        """PowerShell関数を呼び出す"""
        params = " ".join([f"-{k} '{v}'" for k, v in kwargs.items()])
        command = f"{function_name} {params}"
        return self.execute_command(command)
```

## 段階的移行戦略

### フェーズ1: 基盤整備
1. Python環境セットアップ
2. 共通ライブラリの移行
3. 設定管理システムの移行

### フェーズ2: コア機能移行
1. 認証モジュール
2. ログシステム
3. エラーハンドリング

### フェーズ3: API統合
1. Microsoft Graph SDK統合
2. データプロバイダー移行
3. レポート生成エンジン

### フェーズ4: UI移行
1. CLI機能の移行
2. GUI機能の段階的移行
3. テスト自動化

### フェーズ5: 完全移行
1. PowerShellブリッジの段階的削除
2. パフォーマンス最適化
3. ドキュメント更新

このマッピングガイドは、PowerShellからPythonへの移行作業の基準となります。実際の移行時には、各機能の特性に応じて最適な実装方法を選択してください。