# 🚀 Microsoft製品運用管理ツール - 簡単展開ガイド

## 📋 **Windows環境での簡単起動**

### 🎯 **最も簡単な方法（推奨）**

1. **フォルダ全体をコピー**
2. **`START.bat` をダブルクリック** ← これだけ！

```
推奨場所: C:\Tools\MicrosoftProductManagementTools\
```

### 🖱️ **GUIメニュー起動**

```cmd
START.bat  ← ダブルクリック
```

または

```powershell
pwsh -File Start-ManagementTools.ps1
```

## 📋 **従来の3ステップ展開（詳細制御が必要な場合）**

### ✅ **ステップ1: フォルダ全体をコピー**

このフォルダ全体を新しいPCにコピーしてください：

```
推奨場所:
Windows: C:\Tools\MicrosoftProductManagementTools\
Linux: /opt/MicrosoftProductManagementTools/
```

### ✅ **ステップ2: PowerShellモジュールのインストール**

**Windows:**
```powershell
# 展開したフォルダに移動
cd C:\Tools\MicrosoftProductManagementTools

# モジュール自動インストール
pwsh -File install-modules.ps1
```

**Linux/WSL:**
```bash
# 展開したフォルダに移動
cd /opt/MicrosoftProductManagementTools

# モジュール自動インストール
pwsh -File install-modules.ps1
```

### ✅ **ステップ3: 認証テスト実行**

**Windows:**
```powershell
# メインランチャー（推奨）
pwsh -File Start-ManagementTools.ps1 -Action Test

# または直接実行
pwsh -File test-authentication-portable.ps1 -ShowDetails
```

**Linux/WSL:**
```bash
# ポータブル認証テスト
pwsh -File test-authentication-portable.ps1 -ShowDetails
```

## 🎯 **期待される結果**

**成功時の表示:**
```
✓ 設定ファイル読み込み成功
✓ 証明書ファイル存在
✓ Microsoft Graph 接続成功
✓ Exchange Online 接続成功
🎉 このシステムは別PCでも正常に動作します！
```

## 🔧 **追加セットアップ（オプション）**

### レポート生成テスト
```powershell
pwsh -File test-report-generation.ps1 -ReportType Daily
```

### 自動スケジュール設定
```bash
bash setup-scheduler.sh
```

### システム全体確認
```bash
bash config-check.sh --auto
```

## 📊 **含まれるファイル**

| ファイル/フォルダ | 説明 | 重要度 |
|------------------|------|--------|
| `Config/appsettings.json` | 設定ファイル | 🔴 必須 |
| `Certificates/MiraiConstEXO.pfx` | 認証証明書 | 🔴 必須 |
| `Scripts/` | PowerShellスクリプト群 | 🔴 必須 |
| `Templates/` | レポートテンプレート | 🟡 推奨 |
| `install-modules.ps1` | モジュールインストーラー | 🟡 推奨 |
| `test-authentication-portable.ps1` | 認証テスト | 🟡 推奨 |
| `DEPLOYMENT-GUIDE.md` | 詳細ガイド | 🟢 参考 |

## ⚠️ **重要な注意事項**

### セキュリティ
- **PFXファイル**には秘密鍵が含まれるため厳重に管理
- 不要になった古いコピーは削除
- 組織のセキュリティポリシーに従って運用

### 認証方式
このツールは**ハイブリッド認証**を採用：

1. **ファイルベース認証**（ポータブル）← 優先
2. **Thumbprint認証**（ストア依存）← フォールバック

### 環境要件
- Windows 10/11 または Windows Server 2019+
- PowerShell 5.1+ または PowerShell 7+
- インターネット接続（Microsoft 365アクセス用）

## 🆘 **トラブルシューティング**

### 問題: モジュールインストールエラー
```powershell
# 手動インストール
Install-Module Microsoft.Graph -Force -AllowClobber -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser
```

### 問題: 証明書認証エラー
```powershell
# 証明書ファイル確認
Test-Path "Certificates/MiraiConstEXO.pfx"

# 設定確認
Get-Content "Config/appsettings.json" | ConvertFrom-Json
```

### 問題: 権限エラー
- Azure AD アプリケーション「365 Pro Toolkit Application」の権限確認
- 管理者同意が付与されているか確認

## 📞 **サポート情報**

**ログファイル場所:** `Logs/`
**設定ファイル:** `Config/appsettings.json`
**詳細ガイド:** `DEPLOYMENT-GUIDE.md`

---

**🎉 このツールはITSM/ISO27001/27002準拠で、完全ポータブル設計です！**

最終更新: 2025年6月11日