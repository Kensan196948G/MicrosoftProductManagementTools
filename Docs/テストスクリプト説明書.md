# TestScripts フォルダ

このフォルダには、Microsoft 365統合管理ツールのテストに使用するPowerShellスクリプトが格納されています。

## ファイル一覧と説明

### 認証関連テストスクリプト
- **test-auth.ps1** - 基本認証テスト
- **test-auth-simple.ps1** - シンプルな認証テスト
- **test-auth-fix.ps1** - 認証修正テスト
- **test-auth-status.ps1** - 認証状態確認テスト
- **test-interactive-auth.ps1** - 対話型認証テスト
- **test-client-secret.ps1** - クライアントシークレット認証テスト
- **test-certificate.ps1** - 証明書認証テスト

### 接続関連テストスクリプト
- **test-connection-fix.ps1** - 接続修正テスト

### GUI関連テストスクリプト
- **test-gui-fix.ps1** - GUI修正テスト
- **test-fixed-gui.ps1** - 修正されたGUIテスト
- **test-onedrive-gui.ps1** - OneDrive GUI機能テスト

### 機能統合テストスクリプト
- **test-all-features.ps1** - 全機能統合テスト
- **test-graph-features.ps1** - Microsoft Graph機能テスト

## 使用方法

これらのスクリプトは、メインのツールディレクトリから実行してください：

```powershell
# 例: 基本認証テストを実行
.\TestScripts\test-auth.ps1

# 例: 全機能テストを実行  
.\TestScripts\test-all-features.ps1
```

## 注意事項

- これらのスクリプトは開発・デバッグ用途のため、本番環境での実行は推奨されません
- 実行前に適切なMicrosoft 365接続設定が必要です
- 各スクリプトのパス参照は、ルートディレクトリからの相対パスに更新されています

## 実行順序の推奨

1. `test-auth.ps1` - 基本認証確認
2. `test-graph-features.ps1` - Microsoft Graph機能確認
3. `test-all-features.ps1` - 統合テスト実行

## トラブルシューティング

テストで問題が発生した場合は、以下のログファイルを確認してください：
- `Logs/system.log` - システムログ
- `Logs/audit.log` - 監査ログ

詳細なトラブルシューティングについては、`Docs/トラブルシューティング.md` を参照してください。