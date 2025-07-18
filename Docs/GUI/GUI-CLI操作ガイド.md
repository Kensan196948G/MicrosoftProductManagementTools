# 📖 Microsoft 365統合管理ツール GUI/CLI操作ガイド

## 📋 概要

Microsoft 365統合管理ツールは、Windows環境でPowerShell 7.5.1に最適化されたGUI/CLI両対応の統合管理アプリケーションです。26の管理機能を搭載し、エンタープライズ環境での包括的なMicrosoft 365運用を支援します。

## 🚀 クイックスタート

### 1. 統一ランチャーから起動

```powershell
# PowerShell 7で実行（推奨）
pwsh -File run_launcher.ps1

# 表示されるメニュー:
# 1. GUI モード (推奨) - 26機能搭載のWindows Forms GUI
# 2. CLI モード - コマンドライン操作
# 3. 初期セットアップ（初回のみ）
# 4. 認証テスト
# 5. 終了
```

### 2. 直接起動

```powershell
# GUIアプリケーション直接起動
pwsh -File Apps/GuiApp.ps1

# CLIアプリケーション直接起動
pwsh -File Apps/CliApp.ps1

# CLIでの特定機能実行
pwsh -File Apps/CliApp.ps1 -Action daily -Batch
```

## 🖥️ GUI モード詳細（26機能）

### 📊 定期レポート（5機能）
1. **日次レポート生成**
   - ユーザーアクティビティ
   - メールボックス使用状況
   - セキュリティアラート

2. **週次レポート生成**
   - MFA設定状況
   - 外部共有レビュー
   - Teams利用統計

3. **月次レポート生成**
   - ライセンス使用分析
   - ストレージ容量傾向
   - コンプライアンス状況

4. **年次レポート生成**
   - 年間利用統計
   - コスト分析
   - 成長予測

5. **テスト実行**
   - 接続テスト
   - 権限確認
   - API動作確認

### 🔍 分析レポート（5機能）
6. **ライセンス分析**
   - 割り当て状況
   - 未使用ライセンス検出
   - 最適化提案

7. **使用状況分析**
   - サービス別利用率
   - ユーザー活動分析
   - トレンド解析

8. **パフォーマンス監視**
   - レスポンスタイム
   - エラー率監視
   - 容量予測

9. **セキュリティ分析**
   - 脅威検出
   - 異常ログイン
   - コンプライアンス違反

10. **権限監査**
    - 過剰権限検出
    - 役割レビュー
    - アクセス履歴

### 👥 Entra ID管理（4機能）
11. **ユーザー一覧**
    - 全ユーザー情報
    - 属性詳細
    - グループメンバーシップ

12. **MFA状況確認**
    - MFA設定率
    - 認証方法分析
    - 未設定ユーザー

13. **条件付きアクセス**
    - ポリシー一覧
    - 適用状況
    - 例外管理

14. **サインインログ分析**
    - ログイン履歴
    - 失敗分析
    - 地理的分布

### 📧 Exchange Online管理（4機能）
15. **メールボックス一覧**
    - 容量使用状況
    - アーカイブ状態
    - 制限値接近警告

16. **メールフロー分析**
    - 送受信統計
    - 配信遅延
    - ルーティング分析

17. **スパム対策状況**
    - フィルター効果
    - 誤検知率
    - ブロックリスト

18. **配信分析**
    - 配信成功率
    - バウンスメール
    - 配信経路追跡

### 💬 Teams管理（4機能）
19. **Teams使用状況**
    - チーム活動
    - チャネル利用
    - ファイル共有

20. **Teams設定確認**
    - ポリシー設定
    - ゲストアクセス
    - アプリ許可

21. **会議品質分析**
    - 通話品質
    - ネットワーク遅延
    - 参加者統計

22. **アプリ使用分析**
    - インストール済みアプリ
    - 利用頻度
    - カスタムアプリ

### 💾 OneDrive管理（4機能）
23. **ストレージ使用状況**
    - 個人容量
    - ファイルタイプ分析
    - 成長予測

24. **共有状況確認**
    - 共有リンク
    - 外部共有
    - アクセス権限

25. **同期エラー分析**
    - エラー原因
    - 影響ユーザー
    - 解決提案

26. **外部共有分析**
    - 外部ユーザー
    - 共有コンテンツ
    - リスク評価

### GUI特徴
- 🎨 セクション別色分けインターフェース
- 📊 リアルタイム進行状況表示
- 🔔 処理完了ポップアップ通知
- 📂 レポート自動表示機能
- 📜 実行ログのリアルタイム表示

## 💻 CLI モード詳細

### 対話型メニュー

```powershell
# メニュー起動
pwsh -File Apps/CliApp.ps1 -Action menu
```

### バッチモード実行

```powershell
# 定期レポート自動実行
pwsh -File Apps/CliApp.ps1 -Action daily -Batch
pwsh -File Apps/CliApp.ps1 -Action weekly -Batch
pwsh -File Apps/CliApp.ps1 -Action monthly -Batch
pwsh -File Apps/CliApp.ps1 -Action yearly -Batch

# 分析レポート実行
pwsh -File Apps/CliApp.ps1 -Action license-analysis -Batch
pwsh -File Apps/CliApp.ps1 -Action usage-analysis -Batch
pwsh -File Apps/CliApp.ps1 -Action performance -Batch
pwsh -File Apps/CliApp.ps1 -Action security -Batch
pwsh -File Apps/CliApp.ps1 -Action permissions -Batch

# サービス別管理
pwsh -File Apps/CliApp.ps1 -Action users-list -Batch
pwsh -File Apps/CliApp.ps1 -Action mailbox-list -Batch
pwsh -File Apps/CliApp.ps1 -Action teams-usage -Batch
pwsh -File Apps/CliApp.ps1 -Action storage-usage -Batch
```

### パイプライン処理

```powershell
# 複数レポートの連続実行
@("daily", "weekly", "license-analysis") | ForEach-Object {
    pwsh -File Apps/CliApp.ps1 -Action $_ -Batch
}

# 結果をファイルに保存
pwsh -File Apps/CliApp.ps1 -Action daily -Batch | Out-File -FilePath "daily_report_log.txt"
```

## ⚙️ 設定と認証

### 認証設定（Config/appsettings.local.json）

```json
{
  "EntraID": {
    "TenantId": "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea",
    "ClientId": "22e5d6e4-805f-4516-af09-ff09c7c224c4",
    "CertificateThumbprint": "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6",
    "ClientSecret": "ULG8Q~u2zTYsHLPQJak9yxh8obxZa4erSgGezaWZ"
  },
  "ExchangeOnline": {
    "Organization": "miraiconst.onmicrosoft.com",
    "AppId": "22e5d6e4-805f-4516-af09-ff09c7c224c4",
    "CertificateThumbprint": "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6",
    "CertificatePassword": "armageddon2002"
  }
}
```

### 証明書配置

```
Certificates/
├── MiraiConstEXO.pfx     # PowerShell認証用
├── MiraiConstEXO.cer     # Azure AD登録用
└── mycert.pfx            # 互換性用（同一証明書）
```

## 📊 レポート出力

### 出力形式
- **CSV形式**: データ分析・Excel取り込み用
- **HTML形式**: ビジュアルダッシュボード表示用

### ディレクトリ構造

```
Reports/
├── Daily/              # 日次レポート
├── Weekly/             # 週次レポート
├── Monthly/            # 月次レポート
├── Yearly/             # 年次レポート
├── Analysis/           # 分析レポート
│   ├── License/
│   ├── Usage/
│   ├── Performance/
│   └── Security/
├── EntraID/            # Entra ID関連
│   ├── Users/
│   ├── MFA/
│   ├── ConditionalAccess/
│   └── SignInLogs/
├── Exchange/           # Exchange関連
│   ├── Mailbox/
│   ├── MailFlow/
│   ├── AntiSpam/
│   └── Delivery/
├── Teams/              # Teams関連
│   ├── Usage/
│   ├── MeetingQuality/
│   └── Apps/
└── OneDrive/           # OneDrive関連
    ├── Storage/
    ├── Sharing/
    ├── SyncErrors/
    └── ExternalSharing/
```

## 🎯 使用シナリオ

### シナリオ1: 日常運用監視

```powershell
# 朝の定期チェック
pwsh -File run_launcher.ps1
# → GUI モードを選択
# → 日次レポート生成をクリック
# → 自動的にレポートが表示される
```

### シナリオ2: 月次レポート作成

```powershell
# 月末の総合レポート
pwsh -File Apps/CliApp.ps1 -Action monthly -Batch

# 詳細分析も実行
pwsh -File Apps/CliApp.ps1 -Action license-analysis -Batch
pwsh -File Apps/CliApp.ps1 -Action security -Batch
```

### シナリオ3: スケジュールタスク設定

```powershell
# タスクスケジューラー用コマンド
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-File `"D:\MicrosoftProductManagementTools\Apps\CliApp.ps1`" -Action daily -Batch"

$trigger = New-ScheduledTaskTrigger -Daily -At "06:00"

Register-ScheduledTask -TaskName "M365DailyReport" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

### シナリオ4: トラブルシューティング

```powershell
# 認証テスト
TestScripts\test-auth.ps1

# Exchange接続テスト
TestScripts\test-exchange-auth.ps1

# ログ確認
Get-Content Logs\gui_app.log -Tail 50
Get-Content Logs\cli_app.log -Tail 50
```

## 🔍 高度な機能

### カスタムレポート作成

```powershell
# カスタムパラメータでレポート生成
$params = @{
    StartDate = (Get-Date).AddDays(-30)
    EndDate = Get-Date
    IncludeInactive = $true
    DetailLevel = "Full"
}

# CLIでカスタム実行
pwsh -File Apps/CliApp.ps1 -Action custom -Parameters $params
```

### 並列処理

```powershell
# 複数レポートの並列生成
$jobs = @()
@("daily", "license-analysis", "security") | ForEach-Object {
    $jobs += Start-Job -ScriptBlock {
        param($action)
        pwsh -File "D:\MicrosoftProductManagementTools\Apps\CliApp.ps1" -Action $action -Batch
    } -ArgumentList $_
}

# 完了待機
$jobs | Wait-Job | Receive-Job
```

## 📞 サポート情報

### ログファイル

- `Logs/gui_app.log` - GUIアプリケーションログ
- `Logs/cli_app.log` - CLIアプリケーションログ
- `Logs/system.log` - システム全体ログ
- `Logs/audit.log` - 監査ログ

### デバッグモード

```powershell
# 詳細ログ出力を有効化
$env:DEBUG_MODE = "true"
pwsh -File Apps/GuiApp.ps1
```

---

**📅 最終更新日**: 2025年7月14日  
**🎯 対象バージョン**: v2.0  
**✅ 動作環境**: Windows 10/11, PowerShell 7.5.1  
**🏢 対象**: Microsoft 365 E3/E5環境