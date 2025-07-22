# PowerShell 7.5.1 インストーラー配置手順

このディレクトリには、Microsoft 365統合管理ツールのGUI/CLI両対応ランチャーで使用するPowerShell 7.5.1インストーラーを配置します。

## 必要なファイル

以下のファイルをこのディレクトリに配置してください：

### PowerShell 7.5.1 (Windows x64)
- **ファイル名**: `PowerShell-7.5.1-win-x64.msi`
- **ダウンロードURL**: https://github.com/PowerShell/PowerShell/releases/download/v7.5.1/PowerShell-7.5.1-win-x64.msi
- **ファイルサイズ**: 約 140MB
- **SHA256ハッシュ**: (GitHubリリースページで確認してください)

## ダウンロード手順

### 方法1: ブラウザから直接ダウンロード
1. 上記のダウンロードURLをブラウザで開く
2. ファイルをこの`Installers`フォルダに保存
3. ファイル名が`PowerShell-7.5.1-win-x64.msi`であることを確認

### 方法2: PowerShellスクリプトでダウンロード
```powershell
# PowerShell 5.1 または 7.x で実行
$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.1/PowerShell-7.5.1-win-x64.msi"
$destinationPath = ".\PowerShell-7.5.1-win-x64.msi"

Write-Host "PowerShell 7.5.1 をダウンロード中..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath -UseBasicParsing

if (Test-Path $destinationPath) {
    Write-Host "✅ ダウンロード完了: $destinationPath" -ForegroundColor Green
    $fileInfo = Get-Item $destinationPath
    Write-Host "📏 ファイルサイズ: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host "❌ ダウンロードに失敗しました" -ForegroundColor Red
}
```

### 方法3: コマンドライン（curl）
```batch
curl -L -o PowerShell-7.5.1-win-x64.msi https://github.com/PowerShell/PowerShell/releases/download/v7.5.1/PowerShell-7.5.1-win-x64.msi
```

## ファイル確認

配置後、以下のコマンドでファイルの存在を確認できます：

```powershell
Get-ChildItem -Path "Installers" -Filter "*.msi" | Format-Table Name, Length, LastWriteTime
```

## セキュリティ確認

### ファイルハッシュの確認
```powershell
$filePath = ".\Installers\PowerShell-7.5.1-win-x64.msi"
if (Test-Path $filePath) {
    $hash = Get-FileHash -Path $filePath -Algorithm SHA256
    Write-Host "SHA256: $($hash.Hash)" -ForegroundColor Green
} else {
    Write-Host "ファイルが見つかりません: $filePath" -ForegroundColor Red
}
```

### デジタル署名の確認
```powershell
$filePath = ".\Installers\PowerShell-7.5.1-win-x64.msi"
$signature = Get-AuthenticodeSignature -FilePath $filePath
Write-Host "署名ステータス: $($signature.Status)" -ForegroundColor $(if($signature.Status -eq 'Valid'){'Green'}else{'Red'})
Write-Host "署名者: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
```

## 自動ダウンロードスクリプト

便利なダウンロードスクリプトを提供しています：

```powershell
.\Download-PowerShell751.ps1
```

このスクリプトは：
- PowerShell 7.5.1の最新版を自動検出
- ファイルハッシュの検証
- 既存ファイルのスキップ機能
- プログレス表示

## トラブルシューティング

### ダウンロードが失敗する場合
1. インターネット接続を確認
2. プロキシ設定を確認
3. Windows Defender/アンチウイルスの設定を確認
4. 手動でブラウザからダウンロードを試行

### 権限エラーの場合
1. 管理者権限でPowerShellを実行
2. フォルダの書き込み権限を確認
3. ファイルが使用中でないことを確認

## 注意事項

- インストーラーは約140MBのサイズです
- ダウンロードには安定したインターネット接続が必要です
- 企業環境ではプロキシ設定が必要な場合があります
- ファイルのデジタル署名を必ず確認してください

## 関連リンク

- [PowerShell リリースページ](https://github.com/PowerShell/PowerShell/releases)
- [PowerShell ドキュメント](https://docs.microsoft.com/powershell/)
- [インストールガイド](https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)