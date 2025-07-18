# Exchange Online 証明書認証 トラブルシューティングガイド

**作成日**: 2025年07月17日  
**対象**: Exchange Online PowerShell認証エラー  
**エラー**: `A parameter cannot be found that matches parameter name 'CertificateThumbprint'`

---

## 🔍 現状分析

### ✅ 修正済み項目
- **証明書拇印**: `94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6` （正しい値に更新済み）
- **証明書ファイル**: `MiraiConstEXO.cer` （存在確認済み）
- **証明書パスワード**: `armageddon2002` （環境変数設定済み）

### ❌ 問題点
- **Exchange Online PowerShell**: `CertificateThumbprint` パラメータが認識されない
- **原因**: Exchange Online PowerShell V3以降での認証方式変更の可能性

---

## 🔧 対応方法

### 方法1: PFXファイルを使用した認証
証明書拇印の代わりに、PFXファイルを直接指定する方法：

```powershell
# 現在のファイルから PFX ファイルを生成
openssl pkcs12 -export -out MiraiConstEXO.pfx -inkey MiraiConstEXO.key -in MiraiConstEXO.crt -password pass:armageddon2002
```

### 方法2: Certificate Pathパラメータ使用
`CertificateThumbprint` の代わりに `CertificatePath` を使用：

```json
"ExchangeOnline": {
  "Organization": "miraiconst.onmicrosoft.com",
  "AppId": "22e5d6e4-805f-4516-af09-ff09c7c224c4",
  "CertificatePath": "Certificates\\MiraiConstEXO.pfx",
  "CertificatePassword": "armageddon2002"
}
```

### 方法3: Exchange Online V2 モジュール使用
古いバージョンのExchange Online PowerShellモジュールを使用：

```powershell
Install-Module -Name ExchangeOnlineManagement -RequiredVersion 2.0.5 -Force
```

---

## 📋 証明書情報詳細

| 項目 | 値 |
|------|-----|
| **拇印（SHA1）** | `94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6` |
| **有効期限** | 2026年6月4日 |
| **証明書ID** | `b79ddad6-9a1f-4f9a-b4e8-e7fde8bb15fa` |
| **組織** | miraiconst.onmicrosoft.com |
| **アプリケーションID** | `22e5d6e4-805f-4516-af09-ff09c7c224c4` |

---

## 🎯 推奨対応手順

### ステップ1: PFXファイル作成
```bash
# Linuxの場合
cd /mnt/d/MicrosoftProductManagementTools/Certificates
openssl pkcs12 -export -out MiraiConstEXO.pfx \
  -inkey MiraiConstEXO.key \
  -in MiraiConstEXO.crt \
  -password pass:armageddon2002
```

### ステップ2: 設定ファイル更新
`appsettings.json` の Exchange Online セクションを更新：
```json
"CertificatePath": "Certificates\\MiraiConstEXO.pfx"
```

### ステップ3: 接続テスト
```powershell
pwsh -Command "Import-Module './Scripts/Common/RealM365DataProvider.psm1'; Connect-M365Services"
```

---

## 📝 参考情報

### Exchange Online PowerShell 認証方式変更履歴
- **V1**: Basic認証（廃止済み）
- **V2**: Modern認証 + CertificateThumbprint
- **V3**: Modern認証 + CertificateObject/CertificatePath

### 代替認証方法
1. **アプリパスワード**: 古い方式（推奨されない）
2. **マネージドID**: Azure環境向け
3. **証明書ベース認証**: 現在使用中（要修正）

---

## ⚠️ 注意事項

1. **証明書有効期限**: 2026年6月4日まで有効
2. **セキュリティ**: PFXファイルのパスワード保護は必須
3. **バックアップ**: 証明書ファイルの定期バックアップを推奨

---

**最終更新**: 2025年07月17日  
**次回レビュー**: 2025年08月17日