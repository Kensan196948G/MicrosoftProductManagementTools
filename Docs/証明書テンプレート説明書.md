# 証明書設定ガイド

## 概要
このフォルダは証明書設定のテンプレートです。実際の証明書は`Certificates/`フォルダに配置してください。

## 必要なファイル構成

```
Certificates/
├── mycert.pfx              # Exchange Online認証用証明書
├── mycert.cer              # 公開鍵証明書
├── certificate-info.txt    # 証明書情報（拇印など）
└── certificate-update-procedure.md  # 更新手順
```

## 証明書設定手順

### 1. 証明書ファイルの配置
```powershell
# Certificatesフォルダを作成
mkdir Certificates

# 証明書ファイルをコピー
copy your-certificate.pfx Certificates/mycert.pfx
copy your-certificate.cer Certificates/mycert.cer
```

### 2. 証明書情報の記録
`Certificates/certificate-info.txt`に以下の情報を記録：
```
証明書拇印: 94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6
有効期限: 2026/6/4
証明書ID: b79ddad6-9a1f-4f9a-b4e8-e7fde8bb15fa
```

### 3. appsettings.json の更新
```json
{
  "ExchangeOnline": {
    "CertificateThumbprint": "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6",
    "CertificatePath": "Certificates/mycert.pfx"
  }
}
```

## セキュリティ注意事項

⚠️ **重要**: 実際の証明書ファイルは絶対にGitにコミットしないでください。

- `.gitignore`で`Certificates/`フォルダ全体が除外設定されています
- 証明書ファイルは各環境で個別に配置してください
- 本番環境では証明書ストアの使用を推奨します

## 環境別設定

### 開発環境
- ファイルベース証明書 (mycert.pfx)

### 本番環境  
- Windows証明書ストア (CertificateThumbprint)