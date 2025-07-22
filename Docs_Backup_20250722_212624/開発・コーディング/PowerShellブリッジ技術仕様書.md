# PowerShellブリッジ技術仕様書

## 概要

Python版Microsoft 365統合管理ツールから既存PowerShellスクリプトを実行するためのブリッジ機能の技術仕様書です。

## アーキテクチャ

### コンポーネント構成

```
Pythonアプリケーション
    │
    ├── PowerShellBridgeクラス
    │       │
    │       ├── 実行エンジン
    │       ├── パラメータシリアライザ
    │       └── 結果パーサ
    │
    └── PowerShellプロセス
            │
            ├── 既存PowerShellスクリプト
            └── Exchange/Microsoft Graphモジュール
```

## 実装仕様

### PowerShellBridgeクラス

```python
class PowerShellBridge:
    """PowerShellスクリプト実行ブリッジ"""
    
    def __init__(self, powershell_path: str = None):
        """
        初期化
        
        Args:
            powershell_path: PowerShell実行ファイルパス
                           Noneの場合は自動検出
        """
        self.powershell_path = powershell_path or self._detect_powershell()
        self.encoding = 'utf-8-sig'  # UTF-8 with BOM
        self.timeout = 300  # 5分
        
    async def execute_script(
        self,
        script_path: str,
        parameters: Dict[str, Any] = None,
        output_format: str = 'json'
    ) -> Union[Dict, str]:
        """
        PowerShellスクリプトを実行
        
        Args:
            script_path: 実行する.ps1ファイルパス
            parameters: スクリプトパラメータ
            output_format: 'json' | 'text' | 'csv'
            
        Returns:
            実行結果
        """
        
    async def execute_command(
        self,
        command: str,
        parameters: Dict[str, Any] = None
    ) -> str:
        """
        PowerShellコマンドを直接実行
        """
```

### 主要機能

#### 1. PowerShell自動検出

```python
def _detect_powershell(self) -> str:
    """
    利用可能なPowerShellを検出
    
    優先順位:
    1. pwsh (PowerShell 7+)
    2. powershell (Windows PowerShell 5.1)
    """
    for ps in ['pwsh', 'powershell']:
        if shutil.which(ps):
            return ps
    raise PowerShellNotFoundError(
        "PowerShellが見つかりません"
    )
```

#### 2. パラメータシリアライゼーション

```python
def _serialize_parameters(
    self,
    parameters: Dict[str, Any]
) -> List[str]:
    """
    PythonオブジェクトをPowerShellパラメータに変換
    """
    args = []
    for key, value in parameters.items():
        if isinstance(value, bool):
            # スイッチパラメータ
            if value:
                args.append(f'-{key}')
        elif isinstance(value, (list, dict)):
            # JSON形式で渡す
            json_value = json.dumps(value)
            args.extend([f'-{key}', json_value])
        else:
            # 文字列/数値
            args.extend([f'-{key}', str(value)])
    return args
```

#### 3. 非同期実行

```python
async def _execute_async(
    self,
    command: List[str]
) -> Tuple[str, str]:
    """
    PowerShellを非同期実行
    """
    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        encoding=self.encoding
    )
    
    try:
        stdout, stderr = await asyncio.wait_for(
            process.communicate(),
            timeout=self.timeout
        )
    except asyncio.TimeoutError:
        process.kill()
        raise PowerShellTimeoutError(
            f"実行タイムアウト: {self.timeout}秒"
        )
    
    return stdout, stderr
```

#### 4. 結果パーシング

```python
def _parse_output(
    self,
    output: str,
    output_format: str
) -> Union[Dict, List, str]:
    """
    PowerShell出力を解析
    """
    if output_format == 'json':
        try:
            return json.loads(output)
        except json.JSONDecodeError:
            # JSON以外の出力をオブジェクトに変換
            return self._parse_object_output(output)
    
    elif output_format == 'csv':
        return list(csv.DictReader(io.StringIO(output)))
    
    else:  # text
        return output.strip()
```

## 使用例

### 基本的な使用方法

```python
# ブリッジの初期化
bridge = PowerShellBridge()

# Exchangeメールボックス統計取得
result = await bridge.execute_script(
    "Scripts/EXO/Get-MailboxStatistics.ps1",
    parameters={
        "Identity": "user@company.com",
        "IncludeArchive": True
    },
    output_format='json'
)

# 結果の使用
print(f"メールボックスサイズ: {result['TotalItemSize']}")
```

### Exchange Online管理

```python
class ExchangeService:
    def __init__(self, bridge: PowerShellBridge):
        self.bridge = bridge
        
    async def get_mailbox_statistics(self, email: str) -> Dict:
        """メールボックス統計取得"""
        return await self.bridge.execute_script(
            "Scripts/EXO/Get-MailboxStatistics.ps1",
            parameters={"Identity": email}
        )
    
    async def get_mail_flow_statistics(self) -> List[Dict]:
        """メールフロー統計取得"""
        return await self.bridge.execute_script(
            "Scripts/EXO/Get-MailFlowStatistics.ps1",
            output_format='csv'
        )
```

### エラーハンドリング

```python
try:
    result = await bridge.execute_script(
        "Scripts/EXO/ComplexReport.ps1",
        parameters={"Days": 30}
    )
except PowerShellTimeoutError:
    logger.error("レポート生成がタイムアウトしました")
    # フォールバック処理
except PowerShellExecutionError as e:
    logger.error(f"PowerShellエラー: {e.stderr}")
    # エラー内容に応じた処理
```

## セキュリティ考慮事項

### 1. コマンドインジェクション対策

```python
def _validate_script_path(self, script_path: str) -> None:
    """スクリプトパスの検証"""
    # 絶対パスに変換
    abs_path = os.path.abspath(script_path)
    
    # 許可されたディレクトリ内か確認
    allowed_dirs = [
        os.path.abspath("Scripts"),
        os.path.abspath("TestScripts")
    ]
    
    if not any(abs_path.startswith(d) for d in allowed_dirs):
        raise SecurityError(
            "許可されていないスクリプトパス"
        )
```

### 2. 実行ポリシー

```python
# PowerShell実行ポリシー設定
EXECUTION_POLICY_ARGS = [
    "-ExecutionPolicy", "RemoteSigned",
    "-NonInteractive",
    "-NoProfile"
]
```

### 3. センシティブデータのマスキング

```python
def _sanitize_output(self, output: str) -> str:
    """センシティブ情報をマスク"""
    # メールアドレス
    output = re.sub(
        r'[\w\.-]+@[\w\.-]+\.\w+',
        lambda m: m.group(0)[:3] + '***@***',
        output
    )
    # その他のセンシティブデータ
    return output
```

## パフォーマンス最適化

### 1. コネクションプーリング

```python
class PowerShellPool:
    """PowerShellプロセスプール"""
    
    def __init__(self, size: int = 3):
        self.pool = asyncio.Queue(maxsize=size)
        self._initialize_pool()
        
    async def execute(self, command: str) -> str:
        process = await self.pool.get()
        try:
            return await self._run_command(process, command)
        finally:
            await self.pool.put(process)
```

### 2. キャッシュ機構

```python
from functools import lru_cache
import hashlib

class CachedBridge(PowerShellBridge):
    @lru_cache(maxsize=100)
    async def execute_cached(
        self,
        script_hash: str,
        ttl: int = 300
    ) -> Any:
        """キャッシュ付き実行"""
        # TTLチェックロジック
        return await self.execute_script(...)
```

### 3. バッチ処理

```python
async def execute_batch(
    self,
    scripts: List[Tuple[str, Dict]]
) -> List[Any]:
    """複数スクリプトの並列実行"""
    tasks = [
        self.execute_script(path, params)
        for path, params in scripts
    ]
    return await asyncio.gather(*tasks)
```

## 移行戦略

### フェーズ1: ブリッジ経由実行

1. **既存PowerShellスクリプトをそのまま使用**
   - 変更リスク最小化
   - 動作互換性保証

2. **Python側でラップ**
   ```python
   class ExchangeServiceBridge:
       async def get_mailbox_stats(self):
           # PowerShell経由で実行
           return await self.bridge.execute_script(
               "Scripts/EXO/Get-MailboxStats.ps1"
           )
   ```

### フェーズ2: ハイブリッド実装

1. **一部機能をPythonネイティブ実装**
   ```python
   class ExchangeServiceHybrid:
       async def get_mailbox_stats(self):
           if self.use_native:
               # Pythonネイティブ実装
               return await self.graph_client.get_mailbox()
           else:
               # PowerShellブリッジ
               return await self.bridge.execute_script(...)
   ```

### フェーズ3: 完全Python化

1. **すべての機能をPythonで再実装**
2. **PowerShellブリッジの廃止**
3. **レガシーコードの削除**

## テスト戦略

### 単体テスト

```python
@pytest.mark.asyncio
async def test_execute_script():
    bridge = PowerShellBridge()
    result = await bridge.execute_script(
        "TestScripts/test-simple.ps1",
        parameters={"Name": "Test"}
    )
    assert result["Status"] == "Success"
```

### 統合テスト

```python
@pytest.mark.integration
async def test_exchange_integration():
    # 実際Exchange接続テスト
    service = ExchangeService(PowerShellBridge())
    stats = await service.get_mailbox_statistics(
        "test@company.com"
    )
    assert "TotalItemSize" in stats
```

### パフォーマンステスト

```python
@pytest.mark.benchmark
async def test_performance():
    bridge = PowerShellBridge()
    start = time.time()
    
    # 100回実行
    for _ in range(100):
        await bridge.execute_command("Get-Date")
    
    elapsed = time.time() - start
    assert elapsed < 30  # 30秒以内
```

## トラブルシューティング

### 一般的な問題

1. **PowerShellが見つからない**
   - 解決: PATH確認、手動パス指定

2. **文字エンコーディングエラー**
   - 解決: UTF-8 BOM使用、chcp 65001

3. **実行ポリシーエラー**
   - 解決: RemoteSignedポリシー使用

### デバッグモード

```python
# 詳細ログ有効化
bridge = PowerShellBridge(debug=True)

# 実行コマンドの表示
bridge.show_commands = True

# 出力の保存
bridge.save_output = True
```

## 今後の拡張

1. **PowerShell Core対応強化**
   - Linux/macOSでの動作改善

2. **ストリーミング出力**
   - 大量データのリアルタイム処理

3. **リモート実行**
   - SSH/WinRM経由での実行

---

作成日: 2025年1月18日  
バージョン: 1.0  
作成者: Claude Code
