# PowerShell 7 移行ガイド

## 概要

Microsoft Product Management Toolsは、PowerShell 7シリーズでの実行を強く推奨します。このガイドでは、PowerShell 5からPowerShell 7への移行方法と、統一化された運用環境の構築方法を説明します。

## なぜPowerShell 7なのか？

### 🌟 PowerShell 7の利点

| 項目 | PowerShell 5.1 | PowerShell 7 | 改善内容 |
|------|----------------|---------------|----------|
| **パフォーマンス** | 標準 | **50-70%高速** | .NET Core/5+による最適化 |
| **エラーハンドリング** | 基本的 | **高度** | より詳細なエラー情報とスタックトレース |
| **Microsoft Graph** | 制限あり | **完全対応** | 最新APIとの完全互換性 |
| **セキュリティ** | Windows依存 | **最新基準** |継続的なセキュリティ更新 |
| **プラットフォーム** | Windows専用 | **クロスプラットフォーム** | Windows, Linux, macOS |
| **モジュール管理** | PowerShellGet v1 | **PowerShellGet v3** | 改良されたパッケージ管理 |

### 🔧 技術的な改善点

1. **メモリ効率**: ガベージコレクションの最適化
2. **JSON処理**: 大幅な性能向上
3. **並列処理**: ForEach-Object -Parallel の新機能
4. **REST API**: Invoke-RestMethod の改良
5. **文字列処理**: Unicode対応の強化

## 自動移行システム

### 🚀 PowerShell 7 Launcher

本ツールには自動移行システムが組み込まれています：

```powershell
# メインランチャーの実行
.\run_launcher.ps1

# PowerShell 5で実行すると自動的にPowerShell 7への切り替えを提案
# ⚠️  PowerShell 5 で実行中です
# 💡 PowerShell 7 での実行を強く推奨します
# 🚀 PowerShell 7 Launcher を使用しますか? [Y] はい (推奨)   [N] いいえ
```

### 🔄 自動検出・切り替え機能

1. **バージョン自動検出**: 実行時にPowerShellバージョンを自動判定
2. **PowerShell 7 検索**: システム内のPowerShell 7インストールを自動検索
3. **自動切り替え**: ユーザー承認後にPowerShell 7で再実行
4. **自動ダウンロード**: PowerShell 7未インストール時の自動取得

## インストール方法

### 🏠 方法1: 自動インストール（推奨）

```powershell
# PowerShell 7 Launcherを使用した自動インストール
.\Scripts\Common\PowerShell7-Launcher.ps1 -AutoInstall
```

**特徴:**
- ✅ ユーザーフォルダへのポータブルインストール
- ✅ 管理者権限不要
- ✅ 既存環境に影響なし
- ✅ 自動PATH設定

### 🔧 方法2: 手動インストール

#### Windows Package Manager (推奨)
```powershell
# winget を使用したインストール
winget install Microsoft.PowerShell
```

#### 公式インストーラー
1. [PowerShell公式ページ](https://github.com/PowerShell/PowerShell/releases/latest)にアクセス
2. `PowerShell-x.x.x-win-x64.msi`をダウンロード
3. インストーラーを実行（管理者権限推奨）

#### Chocolatey
```powershell
# Chocolatey を使用したインストール
choco install powershell-core
```

### 🐧 Linux/macOS

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y powershell

# CentOS/RHEL/Fedora
sudo dnf install -y powershell

# macOS (Homebrew)
brew install powershell
```

## 運用環境の統一化

### 📋 推奨構成

```
運用環境
├── PowerShell 7.4+ (メイン実行環境)
├── Microsoft.Graph モジュール
├── ExchangeOnlineManagement モジュール
└── 証明書ベース認証
```

### 🔧 環境確認コマンド

```powershell
# PowerShell バージョン確認
$PSVersionTable

# インストール済みPowerShell 7の確認
Get-Command pwsh -ErrorAction SilentlyContinue

# モジュール確認
Get-Module -ListAvailable Microsoft.Graph, ExchangeOnlineManagement
```

### ⚙️ 環境変数設定

```powershell
# PATH環境変数にPowerShell 7を追加（自動設定済み）
$env:PATH

# PowerShell 7をデフォルト端末に設定（Windows Terminal）
# settings.json の "defaultProfile" を PowerShell 7のGUIDに設定
```

## スクリプト実行方法

### 🚀 基本的な実行（自動切り替え）

```powershell
# メインランチャー（自動的にPowerShell 7チェック）
.\run_launcher.ps1

# 個別スクリプト（PowerShell 7 Launcher経由）
.\Scripts\Common\PowerShell7-Launcher.ps1 -TargetScript "Scripts\AD\UserManagement.ps1"
```

### 🎯 直接実行（PowerShell 7確定時）

```powershell
# PowerShell 7で直接実行
pwsh -ExecutionPolicy Bypass -File .\run_launcher.ps1

# 引数付きで実行
pwsh -ExecutionPolicy Bypass -File .\Scripts\Common\ScheduledReports.ps1 -ReportType "Daily"
```

### 📝 バッチファイル実行

```batch
@echo off
rem PowerShell 7で運用ツールを実行
pwsh.exe -ExecutionPolicy Bypass -File "%~dp0run_launcher.ps1"
pause
```

## 機能別対応状況

### ✅ 完全対応機能

- **Microsoft Graph API**: 完全互換
- **Exchange Online Management**: 最新機能対応
- **Active Directory**: 改良されたパフォーマンス
- **レポート生成**: JSON/CSV処理の高速化
- **認証システム**: セキュリティ強化

### ⚠️ 制限付き対応（PowerShell 5）

- **Microsoft Graph**: 一部API制限
- **Exchange Online**: レガシー機能のみ
- **パフォーマンス**: 50-70%低下
- **エラーハンドリング**: 基本的な情報のみ

### ❌ 非対応（PowerShell 4以下）

- システム要件を満たしていません
- PowerShell 5.1以上が必要

## トラブルシューティング

### 🔍 よくある問題と解決方法

#### 問題1: PowerShell 7が見つからない
```powershell
# 解決方法1: PATH環境変数の確認
$env:PATH -split ';' | Where-Object { $_ -like "*PowerShell*" }

# 解決方法2: 手動でPowerShell 7パスを指定
& "C:\Program Files\PowerShell\7\pwsh.exe" -File .\run_launcher.ps1
```

#### 問題2: モジュールが見つからない
```powershell
# PowerShell 7でモジュールパスを確認
$env:PSModulePath -split ';'

# モジュールの手動インストール
Install-Module Microsoft.Graph -Force -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Force -Scope CurrentUser
```

#### 問題3: 実行ポリシーエラー
```powershell
# 現在の実行ポリシー確認
Get-ExecutionPolicy -List

# 実行ポリシーの一時的変更
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# または起動時に指定
pwsh -ExecutionPolicy Bypass -File .\script.ps1
```

#### 問題4: 証明書認証エラー
```powershell
# 証明書ストアの確認
Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq "YOUR-THUMBPRINT" }

# PowerShell 7での証明書パス
$cert = Get-ChildItem Cert:\CurrentUser\My\YOUR-THUMBPRINT
```

### 🔧 診断コマンド

```powershell
# PowerShell環境診断
.\Scripts\Common\PowerShell7-Launcher.ps1 -TargetScript "Scripts\Common\DiagnosticTools.ps1"

# モジュール診断
Import-Module .\Scripts\Common\PowerShellVersionManager.psm1
Get-PowerShellVersionInfo
Test-PowerShell7Installation
```

## 移行チェックリスト

### 📋 移行前の準備

- [ ] 現在のPowerShellバージョンを確認
- [ ] 重要なスクリプトのバックアップ
- [ ] 必要なモジュールの一覧作成
- [ ] 認証情報の確認

### 🚀 移行実行

- [ ] PowerShell 7のインストール
- [ ] モジュールの再インストール
- [ ] 認証設定の確認
- [ ] テストスクリプトの実行

### ✅ 移行後の確認

- [ ] 全スクリプトの動作確認
- [ ] パフォーマンステスト
- [ ] エラーログの確認
- [ ] 定期実行タスクの更新

## 自動化スクリプト

### 🔧 環境セットアップ自動化

```powershell
# 完全自動セットアップ
.\Setup-Environment.ps1 -PowerShell7 -InstallModules -ConfigureCertificates

# PowerShell 7環境確認
.\Scripts\Common\PowerShell7-Launcher.ps1 -TargetScript "TestScripts\test-all-features.ps1"
```

### 📊 移行状況レポート

```powershell
# 移行状況の詳細レポート生成
Import-Module .\Scripts\Common\PowerShellVersionManager.psm1
$report = @{
    CurrentVersion = Get-PowerShellVersionInfo
    PS7Installations = Test-PowerShell7Installation
    LatestVersion = Get-LatestPowerShell7Version
    Modules = Get-Module -ListAvailable Microsoft.Graph, ExchangeOnlineManagement
}
$report | ConvertTo-Json -Depth 3 | Out-File "Reports\PowerShell7-Migration-Report.json"
```

## サポートとリソース

### 📚 参考資料

- [PowerShell 7公式ドキュメント](https://docs.microsoft.com/powershell/)
- [Microsoft Graph PowerShell](https://docs.microsoft.com/graph/powershell/get-started)
- [Exchange Online PowerShell V3](https://docs.microsoft.com/powershell/exchange/exchange-online-powershell-v2)

### 🆘 サポート

- **技術的な問題**: GitHubイシューまたはドキュメントを参照
- **移行支援**: Setup-Environment.ps1の実行
- **パフォーマンス問題**: 診断ツールの実行

---

## まとめ

PowerShell 7への移行により、Microsoft Product Management Toolsの性能、安定性、セキュリティが大幅に向上します。自動移行システムを活用して、スムーズな移行を実現してください。

**推奨アクション:**
1. `.\run_launcher.ps1` を実行
2. PowerShell 7への切り替えを選択
3. 自動インストールまたは手動インストールを実行
4. 移行完了後の動作確認

PowerShell 7シリーズでの統一運用により、より効率的で安全な Microsoft 365 管理環境を構築できます。