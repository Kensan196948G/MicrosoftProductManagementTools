# 認証モジュール (Authentication Module)

Microsoft 365サービスへの統一認証を提供するPythonモジュールです。

## 🎯 概要

このモジュールは、Microsoft Graph API、Exchange Online、およびその他のMicrosoft 365サービスへの認証を統一的に管理します。

### 主な機能
- **複数認証方式対応**: 証明書、クライアントシークレット、対話型、デバイスコード
- **トークンキャッシュ**: 認証トークンの自動キャッシュと管理
- **エラーハンドリング**: 包括的なエラーハンドリングと再試行ロジック
- **PowerShell統合**: 既存PowerShellスクリプトとの互換性
- **証明書管理**: PFX、PEM、証明書ストアからの証明書読み込み

## 📦 モジュール構成

```
src/core/auth/
├── __init__.py                 # モジュールエントリーポイント
├── authenticator.py            # 基底認証クラス
├── graph_auth.py              # Microsoft Graph認証
├── exchange_auth.py           # Exchange Online認証
├── certificate_manager.py     # 証明書管理
├── retry_handler.py           # 再試行ロジック
├── auth_exceptions.py         # 認証例外クラス
└── README.md                  # このファイル
```

## 🚀 使用方法

### 基本的な使用例

```python
from core.auth import GraphAuthenticator, AuthenticationMethod

# Graph認証インスタンスの作成
auth = GraphAuthenticator(
    tenant_id="your-tenant-id",
    client_id="your-client-id"
)

# 証明書による認証
result = auth.authenticate(
    AuthenticationMethod.CERTIFICATE,
    certificate_path="/path/to/certificate.pfx",
    certificate_password="password"
)

if result.success:
    print(f"認証成功: {result.access_token}")
else:
    print(f"認証失敗: {result.error}")
```

### Exchange Online認証

```python
from core.auth import ExchangeAuthenticator, AuthenticationMethod

# Exchange認証インスタンスの作成
exchange_auth = ExchangeAuthenticator(
    tenant_id="your-tenant-id",
    client_id="your-client-id",
    organization="your-org.onmicrosoft.com"
)

# 証明書による認証（PowerShell統合付き）
result = exchange_auth.authenticate(
    AuthenticationMethod.CERTIFICATE,
    certificate_path="/path/to/certificate.pfx"
)

if result.success:
    # Exchange PowerShellコマンドの実行
    mailboxes = exchange_auth.get_mailboxes(limit=10)
    print(f"メールボックス数: {len(mailboxes)}")
    
    # 後処理
    exchange_auth.disconnect()
```

### 証明書管理

```python
from core.auth import CertificateManager

cert_manager = CertificateManager()

# 証明書の読み込み
cert_data = cert_manager.load_certificate_from_file(
    Path("certificate.pfx"),
    password="password"
)

# 証明書情報の取得
cert_info = cert_manager.get_certificate_info(Path("certificate.pfx"))
print(f"証明書サムプリント: {cert_info['thumbprint']}")
print(f"有効期限: {cert_info['not_valid_after']}")
```

## 🔧 認証方式

### 1. 証明書認証 (Certificate Authentication)

```python
# PFXファイルからの証明書読み込み
result = auth.authenticate(
    AuthenticationMethod.CERTIFICATE,
    certificate_path="/path/to/cert.pfx",
    certificate_password="password"
)

# 証明書バイナリデータからの読み込み
with open("cert.pfx", "rb") as f:
    cert_data = f.read()

result = auth.authenticate(
    AuthenticationMethod.CERTIFICATE,
    certificate_data=cert_data,
    certificate_password="password"
)

# Windows証明書ストアからの読み込み（Windowsのみ）
result = auth.authenticate(
    AuthenticationMethod.CERTIFICATE,
    thumbprint="1234567890ABCDEF..."
)
```

### 2. クライアントシークレット認証

```python
result = auth.authenticate(
    AuthenticationMethod.CLIENT_SECRET,
    client_secret="your-client-secret"
)
```

### 3. 対話型認証

```python
result = auth.authenticate(
    AuthenticationMethod.INTERACTIVE
)
```

### 4. デバイスコード認証

```python
result = auth.authenticate(
    AuthenticationMethod.DEVICE_CODE
)
# コンソールに表示されるコードを使用してブラウザで認証
```

## 🔄 再試行とエラーハンドリング

### 再試行設定

```python
from core.auth.retry_handler import RetryConfig, RetryStrategy

# カスタム再試行設定
retry_config = RetryConfig(
    max_attempts=5,
    base_delay=2.0,
    max_delay=120.0,
    strategy=RetryStrategy.EXPONENTIAL_BACKOFF
)

# 再試行付きでの認証
from core.auth.retry_handler import retry_auth_operation

@retry_auth_operation(retry_config)
def authenticate_with_retry():
    return auth.authenticate(
        AuthenticationMethod.CERTIFICATE,
        certificate_path="cert.pfx"
    )

result = authenticate_with_retry()
```

### エラーハンドリング

```python
from core.auth.auth_exceptions import AuthenticationError, AuthErrorCode

try:
    result = auth.authenticate(
        AuthenticationMethod.CERTIFICATE,
        certificate_path="invalid.pfx"
    )
except AuthenticationError as e:
    if e.error_code == AuthErrorCode.CERTIFICATE_NOT_FOUND.value:
        print("証明書ファイルが見つかりません")
    elif e.error_code == AuthErrorCode.CERTIFICATE_EXPIRED.value:
        print("証明書の有効期限が切れています")
    else:
        print(f"認証エラー: {e.error_description}")
```

## 💾 トークンキャッシュ

### 自動キャッシュ

```python
# デフォルトでキャッシュが有効
auth = GraphAuthenticator(
    tenant_id="tenant-id",
    client_id="client-id",
    cache_tokens=True  # デフォルト値
)

# 初回認証（APIコール発生）
result1 = auth.authenticate(AuthenticationMethod.CERTIFICATE, ...)

# 2回目の認証（キャッシュから取得）
result2 = auth.authenticate(AuthenticationMethod.CERTIFICATE, ...)
```

### 手動キャッシュ管理

```python
from core.auth.authenticator import TokenCache

# カスタムキャッシュファイル
cache = TokenCache(cache_file=Path("custom_cache.json"))

# トークンの手動設定
cache.set_token("custom_key", auth_result)

# トークンの取得
cached_token = cache.get_token("custom_key")

# キャッシュのクリア
cache.clear_token("custom_key")
```

## 🧪 テスト

### 単体テスト実行

```bash
# 基本的なテスト
python -m pytest Tests/unit/test_auth.py -v

# 特定のテストクラスのみ
python -m pytest Tests/unit/test_auth.py::TestGraphAuthenticator -v
```

### 統合テスト実行

```bash
# 統合テストの実行（環境変数が必要）
export RUN_INTEGRATION_TESTS=1
python -m pytest Tests/integration/test_auth_integration.py -v -m integration
```

## 📋 設定例

### appsettings.json設定

```json
{
  "Authentication": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "AuthMethod": "Certificate",
    "CertificatePath": "Config/certificate.pfx",
    "CertificatePassword": "password",
    "CertificateThumbprint": "1234567890ABCDEF...",
    "ClientSecret": "your-client-secret"
  },
  "ExchangeOnline": {
    "Organization": "your-org.onmicrosoft.com",
    "UseModernAuth": true
  }
}
```

## 🔒 セキュリティ考慮事項

1. **証明書の保護**
   - 証明書ファイルは適切なアクセス許可で保護
   - パスワードは環境変数または安全な設定管理で保管

2. **トークンキャッシュ**
   - キャッシュファイルは適切なアクセス許可で保護
   - 本番環境では暗号化を検討

3. **ログ記録**
   - 認証情報はログに記録されない
   - エラーログからの情報漏洩を防止

## 🔧 依存関係

```bash
# 必須パッケージ
pip install msal cryptography requests

# Windows証明書ストア使用時（Windowsのみ）
pip install wincertstore

# PowerShell統合使用時
# PowerShell 7.0以上が必要
```

## 📚 関連ドキュメント

- [Microsoft Graph API認証](https://docs.microsoft.com/en-us/graph/auth/)
- [Exchange Online PowerShell](https://docs.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)
- [MSAL Python](https://github.com/AzureAD/microsoft-authentication-library-for-python)

## 🐛 トラブルシューティング

### よくある問題

1. **証明書が見つからない**
   ```
   FileNotFoundError: 証明書ファイルが見つかりません
   ```
   - 証明書パスを確認
   - 相対パスではなく絶対パスを使用

2. **証明書の有効期限切れ**
   ```
   AuthenticationError: 証明書は期限切れです
   ```
   - 証明書の有効期限を確認
   - 新しい証明書を取得

3. **PowerShellモジュールが見つからない**
   ```
   ModuleNotFoundError: ExchangeOnlineManagement module not found
   ```
   - PowerShellでモジュールをインストール:
     ```powershell
     Install-Module -Name ExchangeOnlineManagement
     ```

4. **ネットワーク接続エラー**
   ```
   ConnectionError: Connection failed
   ```
   - ネットワーク接続を確認
   - プロキシ設定を確認
   - ファイアウォール設定を確認

### ログ確認

```python
import logging

# ログレベルを設定
logging.basicConfig(level=logging.DEBUG)

# 認証モジュールのログを有効化
auth_logger = logging.getLogger("core.auth")
auth_logger.setLevel(logging.DEBUG)
```