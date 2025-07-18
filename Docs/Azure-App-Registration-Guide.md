# Azure ADアプリケーション登録手順

## 🎯 新しいアプリケーション作成手順

### Step 1: 基本設定
1. **Azure Portal** → **Azure Active Directory** → **アプリの登録** → **新しい登録**
2. **名前**: `Microsoft365ManagementTool-MiraiConst`
3. **サポートされているアカウントの種類**: `この組織ディレクトリのみのアカウント`
4. **リダイレクトURI**: 空白のまま
5. **登録** をクリック

### Step 2: 証明書アップロード
1. 作成されたアプリケーションを選択
2. **証明書とシークレット** → **証明書** → **証明書のアップロード**
3. CERファイル（`MiraiConstEXO.cer`）を選択してアップロード
4. **説明**: `Exchange Online PowerShell Authentication`

### Step 3: API権限設定

#### Microsoft Graph (Application permissions)
- `User.Read.All` - ユーザー情報読み取り
- `Group.Read.All` - グループ情報読み取り  
- `Directory.Read.All` - ディレクトリ読み取り
- `AuditLog.Read.All` - 監査ログ読み取り
- `Reports.Read.All` - レポート読み取り
- `Team.ReadBasic.All` - Teams基本情報読み取り
- `Sites.Read.All` - SharePointサイト読み取り
- `Files.Read.All` - OneDriveファイル読み取り

#### Office 365 Exchange Online (Application permissions)
- `Exchange.ManageAsApp` - Exchange管理

### Step 4: 管理者の同意
1. **API のアクセス許可** → **管理者の同意を与える**
2. 確認ダイアログで **はい** をクリック
3. 全ての権限が **付与済み** 状態になることを確認

### Step 5: アプリケーション情報記録
- **アプリケーション (クライアント) ID**: `[新しいID]`
- **ディレクトリ (テナント) ID**: `a7232f7a-a9e5-4f71-9372-dc8b1c6645ea`
- **証明書拇印**: `[新しい拇印]`

## ⚠️ 重要な注意事項

### Exchange Online接続設定
1. **Exchange管理センター** → **役割** → **管理者の役割**
2. 作成したアプリケーションを **Exchange管理者** ロールに追加

### 証明書の有効期限
- 作成した証明書の有効期限を記録
- 期限前の更新スケジュールを設定

## 🔧 トラブルシューティング

### よくあるエラー
1. **権限不足**: 管理者の同意が未実行
2. **証明書エラー**: 拇印の不一致
3. **接続タイムアウト**: ファイアウォール設定

### 確認コマンド
```powershell
# 証明書確認
Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.Subject -like "*MiraiConstEXO*"}

# 接続テスト
Connect-MgGraph -TenantId "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea" -ClientId "[新しいID]" -CertificateThumbprint "[新しい拇印]"
```