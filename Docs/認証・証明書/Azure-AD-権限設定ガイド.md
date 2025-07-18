# 📋 Azure AD アプリケーション権限設定ガイド

## 🚨 現在の権限不足の状況

ログに表示されている通り、以下の Microsoft Graph API 権限が不足しています：

```
⚠️ 不足している権限があります: 
- User.Read.All
- Group.Read.All
- Directory.Read.All
- Files.Read.All
```

## ✅ 現在付与されている権限

```
✅ 取得された権限: 
- UserAuthenticationMethod.Read.All
- Directory.ReadWrite.All
- Sites.ReadWrite.All
- Files.ReadWrite.All
- AuditLog.Read.All
- Sites.FullControl.All
- Reports.Read.All
```

## 🔧 権限追加手順

### 1. Azure Portal にログイン

1. [Azure Portal](https://portal.azure.com) にアクセス
2. 管理者権限を持つアカウントでログイン

### 2. アプリケーション登録を開く

1. **Azure Active Directory** → **アプリの登録** を選択
2. アプリケーション **ClientId: 22e5d6e4-805f-4516-af09-ff09c7c224c4** を検索して選択

### 3. API のアクセス許可を設定

1. 左メニューから **API のアクセス許可** を選択
2. **+ アクセス許可の追加** をクリック
3. **Microsoft Graph** を選択
4. **アプリケーションの許可** を選択

### 4. 不足している権限を追加

以下の権限を検索して追加します：

#### User.Read.All
- **説明**: すべてのユーザーの完全なプロファイルを読み取る
- **必要な理由**: ユーザー一覧、ユーザー情報の取得

#### Group.Read.All
- **説明**: すべてのグループを読み取る
- **必要な理由**: グループメンバーシップ、グループ情報の取得

#### Directory.Read.All
- **説明**: ディレクトリ データを読み取る
- **必要な理由**: 組織の構造、ロール情報の取得

#### Files.Read.All
- **説明**: すべてのサイト コレクション内のファイルを読み取る
- **必要な理由**: OneDrive、SharePoint のファイル情報取得

### 5. 管理者の同意を付与

1. すべての権限を追加後、**[組織名] に管理者の同意を与えます** ボタンをクリック
2. 確認ダイアログで **はい** を選択

## 📊 推奨される完全な権限セット

Microsoft 365 統合管理ツールの全機能を利用するために、以下の権限セットを推奨します：

### Microsoft Graph API 権限（アプリケーション）

| 権限名 | 説明 | 用途 |
|--------|------|------|
| User.Read.All | すべてのユーザーの完全なプロファイルを読み取る | ユーザー管理 |
| Group.Read.All | すべてのグループを読み取る | グループ管理 |
| Directory.Read.All | ディレクトリ データを読み取る | 組織情報 |
| Directory.ReadWrite.All | ディレクトリ データの読み取りと書き込み | 管理操作 |
| AuditLog.Read.All | すべての監査ログ データを読み取る | 監査・ログ分析 |
| Reports.Read.All | すべての使用状況レポートを読み取る | レポート生成 |
| Files.Read.All | すべてのサイト コレクション内のファイルを読み取る | OneDrive/SharePoint |
| Files.ReadWrite.All | すべてのサイト コレクション内のファイルの読み取りと書き込み | ファイル管理 |
| Sites.Read.All | すべてのサイト コレクション内のアイテムを読み取る | SharePoint |
| Sites.ReadWrite.All | すべてのサイト コレクション内のアイテムの編集または削除 | SharePoint管理 |
| Mail.Read | アプリがすべてのメールボックス内のメールを読み取る | メール分析 |
| Mail.ReadWrite | アプリがメールの作成、読み取り、更新、削除を行う | メール管理 |
| UserAuthenticationMethod.Read.All | すべてのユーザーの認証方法を読み取る | MFA状況確認 |
| SecurityEvents.Read.All | 組織のセキュリティ イベントを読み取る | セキュリティ分析 |
| IdentityRiskEvent.Read.All | すべての ID リスク イベント情報を読み取る | リスク分析 |
| Policy.Read.All | 組織のポリシーを読み取る | ポリシー分析 |

### Exchange Online 権限（役割）

Exchange Online への接続には以下の役割が必要です（Azure AD アプリに割り当て）：

- View-Only Recipients
- View-Only Configuration
- View-Only Audit Logs
- Hygiene Management（スパム対策分析用）

## 🔍 権限確認方法

### PowerShell での確認

```powershell
# 現在の権限を確認
Connect-MgGraph -ClientId "22e5d6e4-805f-4516-af09-ff09c7c224c4" -TenantId "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea"
(Get-MgContext).Scopes
```

### ツール内での確認

```powershell
# 認証テストを実行
TestScripts\test-auth.ps1

# 出力で「取得された権限」と「不足している権限」を確認
```

## ⚠️ 注意事項

1. **権限の最小化**: 必要最小限の権限のみを付与してください
2. **定期的な見直し**: 使用していない権限は削除することを推奨
3. **監査ログ**: 権限変更は Azure AD の監査ログに記録されます
4. **承認プロセス**: 組織のセキュリティポリシーに従って承認を取得してください

## 🆘 トラブルシューティング

### 権限を追加しても反映されない場合

1. **キャッシュのクリア**: 
   ```powershell
   Disconnect-MgGraph
   Clear-MgGraphCache
   ```

2. **トークンの再取得**:
   ```powershell
   # ツールを再起動
   pwsh -File run_launcher.ps1
   ```

3. **同意の再付与**: Azure Portal で管理者の同意を再度付与

### エラーが続く場合

1. アプリケーション ID が正しいか確認
2. テナント ID が正しいか確認
3. シークレットまたは証明書の有効期限を確認

## 📅 更新日

最終更新日: 2025年1月15日