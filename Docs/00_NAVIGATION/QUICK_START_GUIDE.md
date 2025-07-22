# Microsoft 365管理ツール - 5分でわかるクイックスタート

**所要時間**: 5分  
**対象**: 新規利用者・初心者

---

## 🎯 このツールでできること

Microsoft 365管理ツールは、**26の機能を搭載したエンタープライズ向け統合管理システム**です：

### 📊 主要機能
- **GUI版**: Windows Forms による直感的な操作 (26機能ボタン)
- **CLI版**: コマンドライン自動化対応 (30種類以上のコマンド)  
- **API版**: FastAPI による他システム連携

### 🎨 管理対象
- **Active Directory** - ユーザー・グループ管理
- **Entra ID** - 認証・MFA・条件付きアクセス
- **Exchange Online** - メールボックス・メールフロー
- **Microsoft Teams** - 利用状況・設定・会議品質
- **OneDrive** - ストレージ・共有・同期監視

---

## ⚡ 3分でスタート

### Step 1: システム確認 (30秒)
```bash
# PowerShell 7.5.1+ が必要
pwsh --version

# Python 3.11+ 推奨 (Python版の場合)
python --version
```

### Step 2: インストール (2分)
**Python版 (推奨)**:
```bash
git clone [repository]
cd MicrosoftProductManagementTools
pip install -r requirements.txt
```

**PowerShell版 (レガシー)**:
```bash
# 詳細: 04_バージョン別/PowerShell版/従来版ガイド.md
```

### Step 3: 起動・認証設定 (30秒)
```bash
# GUI版起動 (推奨)
pwsh -File run_launcher.ps1
# → 1. GUI モード選択

# または直接
python src/main.py --gui
```

---

## 🎮 基本操作

### GUI操作 (初心者推奨)
1. **起動**: `run_launcher.ps1` → GUI モード選択
2. **機能選択**: 26機能ボタンから目的の機能クリック
3. **レポート生成**: 自動的にCSV・HTML形式で出力
4. **結果確認**: 生成されたファイルが自動表示

### CLI操作 (上級者・自動化)
```bash
# 日次レポート実行
pwsh -File Apps/CliApp_Enhanced.ps1 daily -OutputHTML

# ユーザー一覧取得 (CSV形式、最大500件)
pwsh -File Apps/CliApp_Enhanced.ps1 users -Batch -OutputCSV -MaxResults 500

# 対話メニューモード
pwsh -File Apps/CliApp_Enhanced.ps1 menu
```

---

## 🔧 初期設定 (必須)

### 認証設定
Microsoft 365への接続に必要な認証情報を設定：

1. **Azure AD アプリケーション登録**
   - 詳細: [認証設定統合ガイド](../02_管理者向け/セットアップ・設定/認証設定統合ガイド.md)

2. **設定ファイル編集**
   ```json
   // Config/appsettings.json
   {
     "TenantId": "your-tenant-id",
     "ClientId": "your-client-id", 
     "ClientSecret": "your-client-secret"
   }
   ```

3. **接続テスト**
   ```bash
   TestScripts/test-auth.ps1
   ```

---

## 📊 よく使う機能 Top 5

| 順位 | 機能名 | 用途 | アクセス方法 |
|------|--------|------|--------------|
| 1 | 日次レポート | 毎日のログイン状況確認 | GUI: 定期レポート > 日次レポート |
| 2 | ユーザー一覧 | ユーザー管理・監査 | GUI: Entra ID管理 > ユーザー一覧 |
| 3 | MFA状況 | セキュリティ監査 | GUI: Entra ID管理 > MFA状況 |
| 4 | ライセンス分析 | コスト最適化 | GUI: 分析レポート > ライセンス分析 |  
| 5 | Teams使用状況 | 利用状況分析 | GUI: Teams管理 > 使用状況 |

---

## ❓ よくある質問

### Q: どのバージョンを使うべき？
**A**: Python版を推奨します。PowerShell版はレガシーサポートです。

### Q: 複数テナントに対応している？
**A**: はい。設定ファイルでテナント切り替えが可能です。

### Q: レポートはどこに保存される？
**A**: `Reports/`ディレクトリに機能別・日付別に自動保存されます。

### Q: エラーが発生した場合は？
**A**: [ユーザー向け問題解決](../01_ユーザー向け/トラブルシューティング/ユーザー向け問題解決.md) または [FAQ](FAQ_COMPREHENSIVE.md) を参照。

---

## 🎓 次のステップ

### 基本操作をマスターしたら:
1. **詳細操作**: [GUI操作ガイド](../01_ユーザー向け/基本操作/GUI操作ガイド.md)
2. **管理者設定**: [システム運用マニュアル](../02_管理者向け/運用・監視/システム運用マニュアル.md)
3. **自動化**: [CLI操作ガイド](../01_ユーザー向け/基本操作/CLI操作ガイド.md)

### システム管理者の方:
1. **企業展開**: [企業展開ガイド](../01_ユーザー向け/インストール/企業展開ガイド.md)
2. **運用監視**: [ログ監視](../02_管理者向け/運用・監視/ログ監視.md)
3. **セキュリティ**: [セキュリティベストプラクティス](../02_管理者向け/セキュリティ/セキュリティベストプラクティス.md)

### 開発者の方:
1. **システム理解**: [システム概要](../03_開発者向け/アーキテクチャ/システム概要.md)
2. **API活用**: [API仕様書](../03_開発者向け/アーキテクチャ/API仕様書.md)
3. **カスタマイズ**: [Python版開発ガイド](../03_開発者向け/実装・開発/Python版開発ガイド.md)

---

**🎉 準備完了！Microsoft 365の効率的な管理を始めましょう！**

困った時は [FAQ](FAQ_COMPREHENSIVE.md) または [マスターインデックス](MASTER_INDEX.md) で情報を検索してください。
