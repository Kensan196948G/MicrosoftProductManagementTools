# Python版インストールガイド - Microsoft 365管理ツール

**対象**: Python版（現行システム・推奨）  
**所要時間**: 15分  
**最終更新**: 2025-07-22

---

## 📋 システム要件

### 必須環境
- **Python**: 3.11以上（推奨）/ 3.9以上（最小）
- **OS**: Windows 10/11, Linux, macOS対応
- **メモリ**: 4GB以上（8GB推奨）
- **ストレージ**: 2GB以上の空き容量

### 必要権限
- **Microsoft 365**: テナント管理者権限またはApplication Administrator
- **Azure AD**: アプリケーション登録権限
- **PowerShell**: 実行ポリシー RemoteSigned以上

---

## 🚀 インストール手順

### Step 1: Pythonセットアップ（2分）
```bash
# Python バージョン確認
python --version  # 3.11+推奨

# 仮想環境作成（推奨）
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate    # Windows
```

### Step 2: リポジトリクローン（1分）
```bash
git clone https://github.com/your-org/MicrosoftProductManagementTools.git
cd MicrosoftProductManagementTools
```

### Step 3: 依存関係インストール（5分）
```bash
# 必須パッケージインストール
pip install -r requirements.txt

# PyQt6インストール（GUI使用の場合）
pip install PyQt6

# 開発用パッケージ（開発者のみ）
pip install -r requirements-dev.txt
```

### Step 4: 設定ファイル準備（3分）
```bash
# 設定ファイルコピー
cp Config/appsettings.example.json Config/appsettings.json

# 設定編集（認証情報設定）
nano Config/appsettings.json  # または任意のエディタ
```

### Step 5: 認証設定（2分）
詳細手順: [認証設定統合ガイド](../02_管理者向け/セットアップ・設定/認証設定統合ガイド.md)

```json
{
  "Authentication": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "ClientSecret": "your-client-secret"
  }
}
```

### Step 6: 動作確認（2分）
```bash
# 認証テスト
python TestScripts/test-auth.py

# GUI版起動テスト
python src/main.py --gui

# CLI版テスト
python src/main.py --cli --help
```

---

## ✅ インストール確認

### 成功の確認項目
1. ✅ **Python起動**: `python src/main.py --version` で版数表示
2. ✅ **GUI表示**: GUIウィンドウが正常表示
3. ✅ **認証成功**: Microsoft 365への接続成功
4. ✅ **機能動作**: サンプルレポート生成成功

### トラブルシューティング
- **ModuleNotFoundError**: `pip install -r requirements.txt` 再実行
- **認証エラー**: [認証設定ガイド](../02_管理者向け/セットアップ・設定/認証設定統合ガイド.md)確認
- **GUI エラー**: PyQt6インストール確認、ディスプレイ設定確認

---

## 🎯 次のステップ

### 基本操作習得
1. [5分クイックスタート](../../00_NAVIGATION/QUICK_START_GUIDE.md) 
2. [GUI操作ガイド](../基本操作/GUI操作ガイド.md)
3. [CLI操作ガイド](../基本操作/CLI操作ガイド.md)

### システム管理者向け
1. [企業展開ガイド](企業展開ガイド.md) - 大規模展開
2. [システム運用マニュアル](../../02_管理者向け/運用・監視/システム運用マニュアル.md)

### 開発者向け
1. [システム概要](../../03_開発者向け/アーキテクチャ/システム概要.md)
2. [Python版開発ガイド](../../03_開発者向け/実装・開発/Python版開発ガイド.md)

---

## 📞 サポート

**問題が解決しない場合**:
1. [FAQ](../../00_NAVIGATION/FAQ_COMPREHENSIVE.md)の確認
2. [問題解決ガイド](../トラブルシューティング/ユーザー向け問題解決.md)の参照
3. GitHub Issues での報告

**🎉 インストール完了！Microsoft 365の効率管理を始めましょう！**
