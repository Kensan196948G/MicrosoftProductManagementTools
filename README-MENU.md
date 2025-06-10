# 🎯 Microsoft製品運用管理ツール - メニューシステム利用ガイド

## 📊 **統合運用メニューの使用方法**

### 🚀 **メニュー起動**

```bash
./menu.sh
```

### ⚠️ **重要な注意事項**

**既存のメニューセッションが動作中の場合は新しいターミナルで実行してください**

### 🎮 **メニュー操作**

#### 【システム制御】
- **1**: システム開始 (`./start-all.sh`)
- **2**: システム停止 (`./stop-all.sh`)  
- **3**: 自動修復ループ開始 (`./auto-repair.sh --daemon`)
- **4**: システム再起動 (stop → start)

#### 【診断・テスト】
- **5**: 構成整合性チェック (`./config-check.sh --auto`)
- **6**: 包括的自動テスト (`./auto-test.sh --comprehensive`)
- **7**: クイックテスト (`./quick-test.sh`)
- **8**: PowerShell統合テスト (`./simple-test.ps1`)

#### 【レポート生成】✅
- **9**: 日次レポート生成 (`./generate-daily-report.sh`) ✅ **修復済み**
- **10**: 週次レポート生成 (`./generate-weekly-report.sh`) ✅ **修復済み**
- **11**: 月次レポート生成 (`./generate-monthly-report.sh`) ✅ **修復済み**
- **12**: 年次レポート生成 (`./generate-yearly-report.sh`) ✅ **修復済み**

#### 【ログ・監査】
- **13**: ログファイル一覧表示
- **14**: 最新ログ表示 (tail -f)
- **15**: システム情報表示
- **16**: プロセス状況確認

#### 【設定・管理】
- **17**: 設定ファイル編集 (`appsettings.json`)
- **18**: ディレクトリ構造表示
- **19**: システム要件確認
- **20**: 導入完了報告表示

#### 【終了】
- **0**: 終了

### 🔧 **直接コマンド実行（推奨）**

メニューで問題が発生した場合は、直接コマンド実行をお勧めします：

```bash
# 日次レポート生成
./generate-daily-report.sh

# 週次レポート生成
./generate-weekly-report.sh

# 月次レポート生成
./generate-monthly-report.sh

# 年次レポート生成
./generate-yearly-report.sh

# システム制御
./start-all.sh
./stop-all.sh
./auto-repair.sh --daemon &

# 診断・テスト
./config-check.sh --auto --force
./auto-test.sh --comprehensive --fix-errors --force
./quick-test.sh
pwsh -File simple-test.ps1
```

### 📊 **レポート生成結果例**

```
=== 日次レポート生成完了 ===
出力先: Reports/Daily/TestDailyReport_20250610_194249.html
ファイルサイズ: 2,978 bytes
レポートが正常に生成されました！
```

### 🎯 **トラブルシューティング**

1. **メニューが古いバージョンを実行している場合**
   ```bash
   # 新しいターミナルを開いて実行
   ./menu.sh
   ```

2. **レポート生成でエラーが発生する場合**
   ```bash
   # 直接実行
   ./generate-daily-report.sh
   ```

3. **システム状態確認**
   ```bash
   # プロセス確認
   ps aux | grep auto-repair
   
   # ログ確認
   ls -la Logs/
   ```

### ✅ **動作確認済み機能**

- ✅ レポート生成機能（日次/週次/月次/年次）
- ✅ システム制御機能
- ✅ 自動修復ループ
- ✅ 構成整合性チェック
- ✅ PowerShell 7.5.1対応

---

**© 2025 Microsoft製品運用管理ツール - 統合運用コンソール**