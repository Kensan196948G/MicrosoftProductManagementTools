# Microsoft 365 統合管理ツール - Python版インストールガイド

## 🐍 概要

このドキュメントは、Microsoft 365 統合管理ツールのPython版（PyQt6 GUI + Microsoft Graph API）のインストールと使用方法を説明します。

## ✨ 特徴

### 🔄 PowerShell版との完全互換性
- **26機能**をPython版で完全再実装
- **同一UI/UX**: PowerShell版と同じレイアウトとユーザーエクスペリエンス
- **同じ設定ファイル**: `Config/appsettings.json`を共有
- **同じ出力形式**: CSV（UTF8-BOM）とHTML形式でレポート生成

### 🚀 Python版の追加メリット
- **クロスプラットフォーム対応**: Windows/Linux/macOS
- **モダンなUI**: PyQt6による美しいGUI
- **リアルタイムログ**: 3つのタブでログを分類表示
- **非同期処理**: レスポンシブなユーザーインターフェース
- **エラーハンドリング強化**: 詳細なエラー情報とフォールバック

## 📋 動作要件

### 最小要件
- **Python 3.9以上** (推奨: Python 3.11以上)
- **Windows 10/11, Ubuntu 20.04以上, macOS 11以上**
- **メモリ**: 4GB以上
- **ディスク**: 1GB以上の空き容量

### 推奨要件
- **Python 3.11以上**
- **メモリ**: 8GB以上
- **Microsoft Graph API アクセス権限**
- **Exchange Online PowerShell モジュール** (フル機能用)

## 🛠️ インストール手順

### ステップ 1: リポジトリの準備

```bash
# リポジトリのルートディレクトリに移動
cd /path/to/MicrosoftProductManagementTools

# Pythonパッケージ管理ディレクトリの確認
ls src/
```

### ステップ 2: Python仮想環境の作成（推奨）

```bash
# 仮想環境の作成
python3 -m venv venv

# 仮想環境の有効化
# Windows:
venv\\Scripts\\activate

# Linux/macOS:
source venv/bin/activate
```

### ステップ 3: 依存関係のインストール

```bash
# 全依存関係のインストール
pip install -r requirements.txt

# または基本依存関係のみ
pip install PyQt6 msal requests colorlog python-dotenv pyyaml
```

### ステップ 4: 設定ファイルの準備

```bash
# 設定ディレクトリが存在することを確認
ls Config/appsettings.json

# 存在しない場合はサンプルから作成
cp Config/appsettings.sample.json Config/appsettings.json
```

### ステップ 5: 動作テスト

```bash
# 軽量テスト（依存関係なし）
python3 test_lite.py

# フル機能テスト（依存関係必要）
python3 test_python_gui.py
```

## ⚙️ 設定

### Microsoft 365 認証設定

`Config/appsettings.json`を編集して認証情報を設定：

```json
{
  "Authentication": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "ClientSecret": "your-client-secret",
    "AuthMethod": "ClientSecret"
  }
}
```

### 認証方法の選択

1. **クライアントシークレット認証** (推奨)
   - `AuthMethod`: `"ClientSecret"`
   - `ClientSecret`を設定

2. **証明書認証**
   - `AuthMethod`: `"Certificate"`
   - `CertificatePath`または`CertificateThumbprint`を設定

3. **対話型認証** (開発用)
   - `AuthMethod`: `"Interactive"`

## 🚀 起動方法

### GUIモード（推奨）

```bash
# 直接起動
python3 src/main.py

# または統一ランチャー使用
python3 src/main.py gui
```

### CLIモード

```bash
# 対話型メニュー
python3 src/main.py cli

# 直接コマンド実行
python3 src/main.py cli --command daily_report --output both
```

### テストモード

```bash
# 軽量テスト（外部依存関係なし）
python3 test_lite.py

# 完全テスト
python3 test_python_gui.py
```

## 🎨 GUI機能詳細

### メインウィンドウ構成

```
┌─────────────────────────────────────────────────┐
│ 🚀 Microsoft 365 統合管理ツール - Python Edition │
├─────────────────────────────────────────────────┤
│ ┌─ 📊定期レポート ─┬─ 🔍分析レポート ─┬─ 👥Entra ID ─┐ │
│ │                 │                 │             │ │
│ │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────┐ │ │
│ │ │日次レポート │ │ │ライセンス分析│ │ │ユーザー │ │ │
│ │ └─────────────┘ │ └─────────────┘ │ │一覧     │ │ │
│ │                 │                 │ └─────────┘ │ │
│ └─────────────────┴─────────────────┴─────────────┘ │
├─────────────────────────────────────────────────┤
│ ┌─ 📋実行ログ ─┬─ ❌エラーログ ─┬─ 💻プロンプト ─┐   │
│ │              │               │               │   │
│ │              │               │               │   │
│ │              │               │               │   │
│ └──────────────┴───────────────┴───────────────┘   │
├─────────────────────────────────────────────────┤
│ 準備完了                            ████████████ │
└─────────────────────────────────────────────────┘
```

### 26機能の配置

#### 📊 定期レポート (6機能)
- 日次レポート
- 週次レポート  
- 月次レポート
- 年次レポート
- テスト実行
- 最新日次レポート表示

#### 🔍 分析レポート (5機能)
- ライセンス分析
- 使用状況分析
- パフォーマンス分析
- セキュリティ分析
- 権限監査

#### 👥 Entra ID管理 (4機能)
- ユーザー一覧
- MFA状況
- 条件付きアクセス
- サインインログ

#### 📧 Exchange Online管理 (4機能)
- メールボックス管理
- メールフロー分析
- スパム対策分析
- 配信分析

#### 💬 Teams管理 (4機能)
- Teams使用状況
- Teams設定分析
- 会議品質分析
- アプリ分析

#### 💾 OneDrive管理 (4機能)
- ストレージ分析
- 共有分析
- 同期エラー分析
- 外部共有分析

## 📊 レポート生成

### 出力形式

1. **CSV形式**
   - エンコーディング: UTF-8 BOM
   - Excel互換
   - 場所: `Reports/Python/[機能名]_[YYYYMMDD_HHMMSS].csv`

2. **HTML形式**
   - レスポンシブデザイン
   - 日本語フォント対応
   - 場所: `Reports/Python/[機能名]_[YYYYMMDD_HHMMSS].html`

### レポートサンプル

```csv
ID,レポートタイプ,実行日時,ステータス,詳細
1,ユーザー一覧,2025/01/18 10:30:15,正常,ユーザー一覧 - サンプルデータ 1
2,ユーザー一覧,2025/01/18 10:30:15,警告,ユーザー一覧 - サンプルデータ 2
```

## 🔧 トラブルシューティング

### よくある問題

#### 1. PyQt6のインストールエラー

```bash
# Windowsの場合
pip install --upgrade pip
pip install PyQt6

# Linuxの場合
sudo apt-get install python3-pyqt6
pip install PyQt6
```

#### 2. MSAL認証エラー

```bash
# 認証キャッシュのクリア
rm -rf ~/.cache/msal_*

# 設定ファイルの確認
cat Config/appsettings.json
```

#### 3. モジュール不足エラー

```bash
# 足りないモジュールの個別インストール
pip install colorlog python-dotenv requests msal

# または一括インストール
pip install -r requirements.txt
```

#### 4. GUI起動エラー

```bash
# 軽量テストで基本機能確認
python3 test_lite.py

# CLIモードで代替使用
python3 src/main.py cli
```

### ログの確認

```bash
# ログディレクトリの確認
ls Logs/

# 最新のログファイル確認
tail -f Logs/m365_tools_$(date +%Y%m%d).log
```

## 🔄 PowerShell版との互換性

### 共有要素
- **設定ファイル**: `Config/appsettings.json`
- **出力ディレクトリ**: `Reports/`
- **ログディレクトリ**: `Logs/`
- **テンプレート**: `Templates/`

### 独立要素
- **Python出力**: `Reports/Python/`
- **PowerShell出力**: `Reports/Daily/`, `Reports/Weekly/`等

## 📚 開発者向け情報

### アーキテクチャ

```
src/
├── main.py              # エントリーポイント
├── gui/                 # PyQt6 GUI
│   ├── main_window.py   # メインウィンドウ
│   └── components/      # UIコンポーネント
├── api/                 # Microsoft Graph API
│   └── graph/          # Graph API クライアント
├── cli/                # CLI アプリケーション
├── core/               # コア機能
│   ├── config.py       # 設定管理
│   └── logging_config.py # ログ設定
└── reports/            # レポート生成
    └── generators/     # CSV/HTML生成
```

### 拡張方法

1. **新機能の追加**
   - `src/gui/main_window.py`でボタン追加
   - `src/api/graph/services.py`でAPI機能追加

2. **新しいレポート形式**
   - `src/reports/generators/`に新ジェネレーター追加

## 📝 ライセンス

このソフトウェアは、MITライセンスの下で配布されています。

## 🙋‍♂️ サポート

- **GitHub Issues**: 問題報告・機能要望
- **ドキュメント**: `Docs/`ディレクトリ内の詳細ドキュメント
- **PowerShell版**: 既存の`run_launcher.ps1`も継続利用可能