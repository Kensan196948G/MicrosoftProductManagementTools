# 📁 セキュアGit同期システム利用ガイド

Microsoft 365統合管理ツールのセキュアGit同期システムの設定と使用方法について説明します。

## 🔧 概要

このシステムは以下の機能を提供します：

- **環境変数ベースの認証管理**（.envファイル）
- **機密情報の自動検出と除外**
- **30分間隔での自動同期**
- **Windowsタスクスケジューラー統合**
- **セキュアな認証情報管理**
- **包括的なログ記録**

## 📋 前提条件

- **Windows 10/11** またはWindows Server 2016以降
- **PowerShell 7.0以降**（推奨）
- **Git 2.20以降**
- **管理者権限**（初期設定時のみ）
- **GitHubアカウント**とリポジトリへのアクセス権

## 🚀 初期設定

### 1. 環境変数の設定

`.env`ファイルに以下の認証情報を設定してください：

```env
# Git認証情報
GIT_USERNAME=YOUR_GITHUB_USERNAME
GIT_PASSWORD=YOUR_GITHUB_PASSWORD
GIT_REPOSITORY_URL=https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
GIT_BRANCH=main
```

### 2. セキュリティ設定の確認

`.gitignore`ファイルに以下が含まれていることを確認してください：

```gitignore
# 機密情報・環境変数ファイル
.env
.env.local
.env.development
.env.production

# 証明書・秘密鍵ファイル
*.pfx
*.key
*.pem
Certificates/
```

### 3. 自動同期スケジューラーの設定

管理者権限でPowerShellを開き、以下のコマンドを実行してください：

```powershell
# 基本設定（30分間隔）
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1"

# カスタム間隔設定（例：15分間隔）
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1" -IntervalMinutes 15

# 特定のブランチを指定
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1" -Branch "development"
```

## 📊 システム構成

```
Microsoft365Tools/
├── .env                          # 環境変数ファイル（機密情報）
├── .gitignore                    # Git除外設定
├── Scripts/
│   ├── Common/
│   │   ├── EnvironmentManager.psm1     # 環境変数管理
│   │   ├── GitSyncManager.psm1         # Git同期管理
│   │   ├── Setup-GitSyncScheduler.ps1  # スケジューラー設定
│   │   ├── Execute-GitSync.ps1         # 実行スクリプト
│   │   └── Migrate-SecretsToEnv.ps1    # 機密情報移行
│   └── Launcher/                       # 移動されたランチャー
└── Logs/
    └── git-sync.log               # 同期ログ
```

## 🔄 使用方法

### 手動同期の実行

```powershell
# 基本同期
Import-Module "Scripts\Common\GitSyncManager.psm1"
Invoke-GitAutoSync

# セキュア同期（機密情報チェック付き）
Invoke-SecureGitSync -Verbose
```

### タスクスケジューラーの管理

```powershell
# タスク状態確認
Get-ScheduledTask -TaskName "Microsoft365Tools-GitAutoSync"

# 手動実行
Start-ScheduledTask -TaskName "Microsoft365Tools-GitAutoSync"

# タスク停止
Stop-ScheduledTask -TaskName "Microsoft365Tools-GitAutoSync"

# アンインストール
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1" -Uninstall
```

### ログの確認

```powershell
# 同期ログの表示
Get-Content "Logs\git-sync.log" -Tail 20

# リアルタイム監視
Get-Content "Logs\git-sync.log" -Wait
```

## 🔒 セキュリティ機能

### 1. 機密情報の自動検出

システムは以下のパターンで機密情報を検出します：

- `password = "..."`
- `secret = "..."`
- `key = "..."`
- `token = "..."`
- `api_key = "..."`

### 2. 除外対象ファイル

以下のファイルは自動的に除外されます：

- `.env`ファイル
- 証明書ファイル（.pfx, .key, .pem）
- ログファイル
- 一時ファイル

### 3. 認証情報の保護

- 環境変数による認証情報管理
- Git認証情報の暗号化保存
- プレースホルダー値の検証

## 📈 監視とメンテナンス

### 同期状態の確認

```powershell
# Git リポジトリ状態確認
Import-Module "Scripts\Common\GitSyncManager.psm1"
Get-GitRepositoryStatus -Verbose

# 環境変数設定確認
Import-Module "Scripts\Common\EnvironmentManager.psm1"
Test-EnvironmentConfiguration -Verbose
```

### トラブルシューティング

#### 1. 同期が失敗する場合

```powershell
# 認証情報の確認
Get-GitCredentials

# 手動同期でエラー詳細を確認
Invoke-SecureGitSync -Verbose
```

#### 2. タスクスケジューラーが動作しない場合

```powershell
# タスクの詳細確認
Get-ScheduledTaskInfo -TaskName "Microsoft365Tools-GitAutoSync"

# イベントログの確認
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=201}
```

#### 3. 環境変数が読み込まれない場合

```powershell
# .envファイルの確認
Test-Path ".env"

# 環境変数の手動読み込み
Initialize-Environment -Verbose
```

## 🛠️ 詳細設定

### カスタム同期間隔の設定

```powershell
# 15分間隔
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1" -IntervalMinutes 15

# 1時間間隔
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1" -IntervalMinutes 60
```

### 複数ブランチの管理

```powershell
# 開発ブランチ用タスク
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1" -TaskName "GitSync-Development" -Branch "development"

# 本番ブランチ用タスク
pwsh -File "Scripts\Common\Setup-GitSyncScheduler.ps1" -TaskName "GitSync-Production" -Branch "main"
```

### 除外ルールのカスタマイズ

`.gitignore`ファイルを編集して、プロジェクト固有の除外ルールを追加できます：

```gitignore
# プロジェクト固有の除外
MyCustomConfig/
*.backup
temp_*
```

## 📋 ベストプラクティス

### 1. 定期的な設定確認

```powershell
# 週次確認スクリプト
Test-EnvironmentConfiguration -Verbose
Get-GitRepositoryStatus -Verbose
```

### 2. ログの定期的な確認

```powershell
# 直近24時間のエラーログを確認
Select-String -Path "Logs\git-sync.log" -Pattern "ERROR" | Where-Object { $_.Line -match (Get-Date).AddDays(-1).ToString("yyyy-MM-dd") }
```

### 3. バックアップの実行

```powershell
# 設定ファイルのバックアップ
Copy-Item ".env" ".env.backup.$(Get-Date -Format 'yyyyMMdd')"
Copy-Item ".gitignore" ".gitignore.backup.$(Get-Date -Format 'yyyyMMdd')"
```

## 🔧 API リファレンス

### EnvironmentManager.psm1

```powershell
# 環境変数の初期化
Initialize-Environment -Verbose

# 認証情報の取得
Get-GitCredentials -ThrowOnMissing

# 設定状況の確認
Test-EnvironmentConfiguration -Verbose
```

### GitSyncManager.psm1

```powershell
# Git認証情報の設定
Set-GitCredentials -UseEnvironmentFile

# リポジトリ状態の確認
Get-GitRepositoryStatus -Verbose

# 自動同期の実行
Invoke-GitAutoSync -Verbose

# セキュア同期の実行
Invoke-SecureGitSync -Verbose
```

## 📞 サポート

問題が発生した場合は、以下の手順で対応してください：

1. **ログの確認**：`Logs\git-sync.log`を確認
2. **設定の確認**：環境変数とGit設定を確認
3. **手動テスト**：手動同期でエラーを特定
4. **システム再起動**：タスクスケジューラーサービスの再起動

## 📚 関連ドキュメント

- [Microsoft365統合管理ツール操作手順書](Microsoft365統合管理ツール操作手順書.md)
- [インストールガイド](インストールガイド.md)
- [トラブルシューティング](トラブルシューティング.md)
- [セキュリティガイド](セキュリティガイド.md)

---

**重要**: このシステムは機密情報を取り扱うため、セキュリティガイドラインを遵守し、定期的な設定確認を行ってください。