# Google Drive API 自動同期セットアップガイド

## 概要
このガイドでは、Microsoft Product Management Toolsの証明書ファイルをGoogle Driveに自動同期するためのセットアップ手順を説明します。

## 前提条件
- Google Oneアカウント（既存のアカウントを使用）
- PowerShell 5.1以降
- インターネット接続

## セットアップ手順

### 1. Google Drive API有効化

1. **Google Cloud Console**にアクセス
   - https://console.cloud.google.com/

2. **新しいプロジェクトを作成**
   - プロジェクト名: `MicrosoftProductManagementTools`
   - プロジェクトID: 自動生成またはカスタム

3. **Google Drive APIを有効化**
   - APIs & Services → Library
   - "Google Drive API"を検索
   - "Enable"をクリック

4. **OAuth 2.0認証情報を作成**
   - APIs & Services → Credentials
   - "Create Credentials" → "OAuth client ID"
   - Application type: "Desktop application"
   - Name: `MicrosoftProductManagementTools-Desktop`

5. **認証情報をダウンロード**
   - JSON形式でダウンロード
   - `client_secret.json`として保存

### 2. 初回認証設定

1. **設定ファイルの更新**
   ```powershell
   # Config/googledrive.json を編集
   {
     "GoogleDriveAPI": {
       "ClientId": "YOUR_CLIENT_ID_FROM_JSON",
       "ClientSecret": "YOUR_CLIENT_SECRET_FROM_JSON",
       "RefreshToken": "",  # 初回認証後に自動設定
       # ... その他の設定
     }
   }
   ```

2. **初回認証実行**
   ```powershell
   # PowerShellでモジュールをインポート
   Import-Module Scripts/Common/GoogleDriveSync.psm1
   
   # 初回認証（ブラウザが開きます）
   Initialize-GoogleDriveSync
   ```

3. **認証フロー**
   - ブラウザで Google アカウントにログイン
   - アプリケーションのアクセス許可を承認
   - 認証コードをコピー
   - PowerShellに認証コードを貼り付け

### 3. 基本的な使用方法

#### 手動同期
```powershell
# 証明書ファイルを手動で同期
Sync-CertificatesToGoogleDrive

# 特定のパスから同期
Sync-CertificatesToGoogleDrive -LocalPath "C:/path/to/certificates"
```

#### 自動監視開始
```powershell
# ファイル変更を監視して自動アップロード
Start-GoogleDriveFileWatcher
```

#### 接続テスト
```powershell
# Google Drive接続をテスト
Test-GoogleDriveConnection
```

### 4. 設定項目詳細

#### 同期設定
- **RemoteFolderName**: Google Drive上のフォルダ名
- **SyncInterval**: 定期同期間隔（秒）
- **EnableEncryption**: ファイル暗号化の有効/無効
- **AutoSyncEnabled**: 自動同期の有効/無効
- **SyncOnFileChange**: ファイル変更時の自動同期

#### セキュリティ設定
- **EnableAuditLog**: 操作ログの記録
- **MaxFileSize**: 最大ファイルサイズ（MB）
- **AllowedFileTypes**: 同期対象のファイル拡張子
- **EncryptionPassword**: 暗号化パスワード

### 5. 自動化スクリプトの作成

#### 日次同期スクリプト
```powershell
# Scripts/Common/DailyGoogleDriveSync.ps1
param()

Import-Module Scripts/Common/GoogleDriveSync.psm1

try {
    Initialize-GoogleDriveSync
    Sync-CertificatesToGoogleDrive
    Write-Host "Daily sync completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Daily sync failed: $($_.Exception.Message)"
    # 必要に応じて通知機能を実装
}
```

#### タスクスケジューラー登録
```powershell
# 管理者権限で実行
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File 'C:/path/to/DailyGoogleDriveSync.ps1'"
$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "GoogleDriveSync-Daily" -Action $action -Trigger $trigger -Settings $settings
```

### 6. トラブルシューティング

#### 一般的な問題

1. **認証エラー**
   - 認証情報が正しく設定されているか確認
   - リフレッシュトークンが有効か確認
   - Google Cloud Consoleでプロジェクトが有効か確認

2. **アップロードエラー**
   - ファイルサイズ制限を確認
   - ネットワーク接続を確認
   - Google Drive容量を確認

3. **権限エラー**
   - OAuth スコープが正しく設定されているか確認
   - Google Drive APIが有効になっているか確認

#### ログ確認
```powershell
# 同期ログを確認
Get-Content "Logs/googledrive-sync.log" -Tail 20
```

#### 設定リセット
```powershell
# 認証情報をリセット（再認証が必要）
$config = Get-Content "Config/googledrive.json" | ConvertFrom-Json
$config.GoogleDriveAPI.RefreshToken = ""
$config.GoogleDriveAPI.AccessToken = ""
$config | ConvertTo-Json -Depth 10 | Set-Content "Config/googledrive.json"
```

### 7. セキュリティ考慮事項

1. **認証情報の保護**
   - `googledrive.json`をgitignoreに追加
   - 適切なファイル権限を設定
   - 定期的なパスワード変更

2. **暗号化の使用**
   - 機密ファイルは暗号化してアップロード
   - 強力なパスワードを使用
   - パスワードの安全な管理

3. **アクセス制御**
   - 最小権限の原則
   - 定期的な権限レビュー
   - 不要なアクセスの削除

### 8. 運用の最適化

1. **定期メンテナンス**
   - 古いバックアップファイルの削除
   - ログファイルのローテーション
   - 設定の定期レビュー

2. **監視とアラート**
   - 同期失敗の通知
   - 容量使用量の監視
   - パフォーマンスの監視

3. **バックアップ戦略**
   - 複数の同期先の設定
   - 定期的な復元テスト
   - 災害復旧計画

## サポート

問題が発生した場合は、以下の情報を準備してサポートに連絡してください：

- エラーメッセージ
- 操作手順
- 設定ファイル（機密情報は除く）
- ログファイル