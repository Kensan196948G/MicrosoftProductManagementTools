# 📖 Microsoft 365統合管理ツール 操作手順書

## 🎯 概要

Microsoft 365統合管理ツールは、PowerShellベースの包括的な管理システムです。26機能を搭載したGUIアプリケーションとCLIアプリケーションの両方を提供し、エンタープライズ環境でのMicrosoft 365運用を効率化します。

---

## 🚀 基本的な起動手順

### 📋 手順1: PowerShellの起動

1. 🔍 **Windowsメニューから「PowerShell」を検索**
2. 🖱️ **「Windows PowerShell」または「PowerShell 7」を右クリック**
3. ⚡ **「管理者として実行」を選択**
4. 🛡️ **UACダイアログで「はい」をクリック**

### 📂 手順2: 作業ディレクトリへの移動

```powershell
cd "D:\MicrosoftProductManagementTools"
```

### 🎮 手順3: 統一ランチャーの起動

```powershell
pwsh -File run_launcher.ps1
```

起動後、以下のメニューが表示されます：

```
Microsoft 365 統合管理ツール ランチャー
=====================================
1. GUI モード (推奨) - 26機能搭載のWindows Forms GUI
2. CLI モード - コマンドライン操作
3. 初期セットアップ（初回のみ）
4. 認証テスト
5. 終了
```

---

## 🖥️ GUI モード操作（推奨）

### 📊 GUI アプリケーションの特徴

- **26機能**を6つのセクションに分類
- **直感的なボタン操作**
- **リアルタイムステータス表示**
- **自動ファイル表示機能**

### 🎨 セクション構成

#### 1. 📊 定期レポート（5機能）
- 日次レポート生成
- 週次レポート生成
- 月次レポート生成
- 年次レポート生成
- テスト実行

#### 2. 🔍 分析レポート（5機能）
- ライセンス分析
- 使用状況分析
- パフォーマンス監視
- セキュリティ分析
- 権限監査

#### 3. 👥 Entra ID管理（4機能）
- ユーザー一覧
- MFA状況確認
- 条件付きアクセス
- サインインログ分析

#### 4. 📧 Exchange Online管理（4機能）
- メールボックス一覧
- メールフロー分析
- スパム対策状況
- 配信分析

#### 5. 💬 Teams管理（4機能）
- Teams使用状況
- Teams設定確認
- 会議品質分析
- アプリ使用分析

#### 6. 💾 OneDrive管理（4機能）
- ストレージ使用状況
- 共有状況確認
- 同期エラー分析
- 外部共有分析

### 🖱️ 操作手順

1. **機能ボタンをクリック**
2. **処理実行中はステータスバーで進行状況を確認**
3. **完了後、レポートファイルが自動的に開く**
4. **ポップアップで処理完了を通知**

---

## 💻 CLI モード操作

### 📋 CLI メニューの特徴

- **コマンドライン環境での完全な機能アクセス**
- **バッチモード対応**
- **スクリプト自動化に最適**

### 🎯 CLI コマンド例

```powershell
# 対話型メニューモード
pwsh -File Apps/CliApp.ps1 -Action menu

# 日次レポート直接実行
pwsh -File Apps/CliApp.ps1 -Action daily

# バッチモードで週次レポート
pwsh -File Apps/CliApp.ps1 -Action weekly -Batch

# ライセンス分析実行
pwsh -File Apps/CliApp.ps1 -Action license-analysis
```

### 📝 利用可能なアクション

- `daily` - 日次レポート生成
- `weekly` - 週次レポート生成
- `monthly` - 月次レポート生成
- `yearly` - 年次レポート生成
- `test` - テスト実行
- `license-analysis` - ライセンス分析
- `usage-analysis` - 使用状況分析
- `performance` - パフォーマンス監視
- `security` - セキュリティ分析
- `permissions` - 権限監査
- `menu` - 対話型メニュー表示

---

## ⚙️ 初期セットアップ

### 📋 必要な設定

1. **認証情報の設定**
   - `Config/appsettings.local.json`を作成
   - テナントID、クライアントID、証明書情報を設定

2. **証明書の配置**
   - `Certificates/`フォルダに証明書ファイルを配置
   - PFXファイルとパスワードを設定

3. **モジュールのインストール**
   ```powershell
   Install-Module Microsoft.Graph -Force
   Install-Module ExchangeOnlineManagement -Force
   ```

### 🧪 認証テスト

ランチャーから「4. 認証テスト」を選択、または直接実行：

```powershell
TestScripts\test-auth.ps1
TestScripts\test-exchange-auth.ps1
```

---

## 📊 レポート出力

### 📁 出力ディレクトリ構造

```
Reports/
├── Daily/          # 日次レポート
├── Weekly/         # 週次レポート
├── Monthly/        # 月次レポート
├── Yearly/         # 年次レポート
├── Analysis/       # 分析レポート
│   ├── License/
│   ├── Usage/
│   ├── Performance/
│   └── Security/
├── EntraID/        # Entra ID関連
├── Exchange/       # Exchange関連
├── Teams/          # Teams関連
└── OneDrive/       # OneDrive関連
```

### 📄 出力形式

- **CSV形式**: データ分析・インポート用
- **HTML形式**: ビジュアルレポート・ダッシュボード表示

---

## 🛠️ トラブルシューティング

### ❌ よくある問題と解決方法

1. **PowerShellバージョンエラー**
   ```powershell
   # PowerShell 7のインストール確認
   $PSVersionTable.PSVersion
   ```

2. **モジュール読み込みエラー**
   ```powershell
   # 必要モジュールの再インストール
   Install-Module Microsoft.Graph -Force -AllowClobber
   Install-Module ExchangeOnlineManagement -Force -AllowClobber
   ```

3. **認証エラー**
   - `Config/appsettings.local.json`の設定確認
   - 証明書の有効期限確認
   - Azure ADアプリケーションの権限確認

### 📋 ログ確認

```powershell
# システムログ確認
Get-Content Logs\system.log -Tail 50

# GUIアプリログ確認
Get-Content Logs\gui_app.log -Tail 50

# CLIアプリログ確認
Get-Content Logs\cli_app.log -Tail 50
```

---

## 🔒 セキュリティ注意事項

1. **認証情報の保護**
   - `appsettings.local.json`は絶対に共有しない
   - 証明書ファイルは適切なアクセス権限で保護

2. **実行権限**
   - 管理者権限での実行を推奨
   - 最小権限の原則を適用

3. **監査ログ**
   - すべての操作は`Logs/audit.log`に記録
   - 定期的な監査を実施

---

## 📈 パフォーマンス最適化

1. **並列処理**
   - 複数のレポートを同時実行可能
   - リソース使用状況に注意

2. **キャッシュ活用**
   - 頻繁にアクセスするデータはキャッシュ
   - 設定で有効期限を調整可能

3. **スケジュール実行**
   - Windowsタスクスケジューラーでの自動実行
   - オフピーク時間での実行を推奨

---

**📅 最終更新日**: 2025年7月14日  
**🎯 対象バージョン**: v2.0  
**✅ 動作確認済み環境**: Windows 10/11, PowerShell 7.5.1