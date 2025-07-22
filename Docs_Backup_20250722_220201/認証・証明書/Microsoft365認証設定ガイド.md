# Microsoft 365 認証設定ガイド

## Azure ADアプリケーション登録手順

### 1. Azure ポータルでのアプリケーション登録

1. **Azure ポータル**にアクセス: https://portal.azure.com
2. **Azure Active Directory** → **アプリの登録** → **新規登録**
3. アプリケーション情報を入力：
   - **名前**: `Microsoft365-Management-Tool`
   - **サポートされているアカウントの種類**: `この組織ディレクトリのみのアカウント`
   - **リダイレクト URI**: 空白のまま

### 2. API アクセス許可の設定

**Microsoft Graph** に以下の **アプリケーション許可** を追加：

#### 必須権限:
- `User.Read.All` - すべてのユーザープロファイルの読み取り
- `Directory.Read.All` - ディレクトリデータの読み取り
- `Group.Read.All` - すべてのグループの読み取り
- `AuditLog.Read.All` - 監査ログの読み取り
- `Reports.Read.All` - すべての利用状況レポートの読み取り

#### Exchange Online権限（オプション）:
- `Exchange.ManageAsApp` - Exchange Online管理

⚠️ **重要**: 管理者の同意が必要です

### 3. クライアントシークレットの作成

1. **証明書とシークレット** → **新しいクライアントシークレット**
2. **説明**: `PowerShell-Tool-Secret`
3. **有効期限**: 24ヶ月
4. **シークレット値**をコピー（一度しか表示されません）

### 4. テナント情報の取得

- **テナントID**: Azure AD概要ページから取得
- **アプリケーション（クライアント）ID**: アプリ登録概要ページから取得

## 設定ファイルの更新

### Config/appsettings.local.json を作成:

```json
{
  "EntraID": {
    "TenantId": "あなたのテナントID",
    "ClientId": "あなたのクライアントID", 
    "ClientSecret": "あなたのクライアントシークレット"
  }
}
```

⚠️ **セキュリティ**: `appsettings.local.json` は .gitignore に含まれており、リポジトリにコミットされません

## 接続テスト

以下のコマンドで認証をテスト:

```powershell
# Microsoft Graphモジュールのインストール（必要に応じて）
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# 認証テスト
TestScripts\test-auth.ps1
```

## セキュリティのベストプラクティス

1. **最小権限の原則**: 必要最小限の権限のみ付与
2. **定期的なシークレット更新**: 24ヶ月毎にクライアントシークレットを更新
3. **証明書認証への移行**: 可能であれば証明書ベース認証を使用
4. **監査ログ**: すべてのAPI呼び出しを監査

## トラブルシューティング

### よくあるエラー:

1. **権限不足エラー**:
   - 管理者同意が未実行
   - 必要な権限が未付与

2. **認証エラー**:
   - テナントID、クライアントID、シークレットの不一致
   - シークレットの有効期限切れ

3. **タイムアウトエラー**:
   - ネットワーク接続の問題
   - Microsoft Graph API の一時的な問題

### デバッグモード:

```powershell
# デバッグ情報を有効化
$DebugPreference = "Continue"
TestScripts\test-auth.ps1
```

## サポート

- [Microsoft Graph API ドキュメント](https://docs.microsoft.com/graph/)
- [Azure AD アプリ登録ガイド](https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app)