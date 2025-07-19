# Microsoft Teams + Gmail 通知システム設定ガイド

## 📋 概要

Microsoft 365 Tools では、Slack の代替として **Microsoft Teams** と **Gmail** による包括的な通知システムを提供しています。このガイドでは、初期セットアップから動作確認まで、段階的に設定方法を説明します。

## 🎯 実現される機能

- ✅ **バックアップ成功/失敗通知**
- 🔄 **GitHub Actions ワークフロー通知**
- 📊 **日次サマリーレポート**
- 🚨 **緊急エスカレーション**
- 🛡️ **セキュリティアラート**
- 📱 **Microsoft Teams Adaptive Cards**
- 📧 **HTML形式Gmail通知**

---

## 🚀 セットアップ手順

### ステップ1: 依存パッケージのインストール

#### 1.1 自動インストールスクリプトの実行

```bash
# プロジェクトルートディレクトリで実行
cd /mnt/e/MicrosoftProductManagementTools

# セットアップスクリプトを実行（管理者権限が必要）
./setup_notification_dependencies.sh
```

#### 1.2 手動インストール（自動スクリプトが失敗した場合）

**Ubuntu/Debian系:**
```bash
sudo apt-get update
sudo apt-get install -y sendemail libnet-ssleay-perl libio-socket-ssl-perl
sudo apt-get install -y msmtp msmtp-mta curl jq bc
```

**CentOS/RHEL/Rocky Linux:**
```bash
sudo dnf install -y epel-release
sudo dnf install -y sendemail msmtp curl jq bc
```

**macOS (Homebrew):**
```bash
brew install msmtp curl jq
```

#### 1.3 インストール確認

```bash
# 依存パッケージの確認
./setup_notification_dependencies.sh verify
```

**期待される出力:**
- ✅ sendemail: インストール済み
- ✅ msmtp: インストール済み  
- ✅ curl: インストール済み
- ✅ jq: インストール済み
- ✅ python3: インストール済み

---

### ステップ2: Microsoft Teams の設定

#### 2.1 Teams チャンネルでの Webhook 作成

1. **通知を受信したい Microsoft Teams チャンネルを開く**
   - 例: "IT-監視" チャンネル

2. **チャンネル設定にアクセス**
   - チャンネル名の横の **「...」** をクリック
   - **「コネクタ」** を選択

3. **Incoming Webhook の設定**
   - 検索ボックスで **"Incoming Webhook"** を検索
   - **「構成」** ボタンをクリック

4. **Webhook の詳細設定**
   - **名前**: `Microsoft 365 Tools`
   - **説明**: `バックアップとシステム監視の通知`
   - **アイコン**: お好みで Microsoft のロゴなどをアップロード
   - **「作成」** をクリック

5. **Webhook URL の取得**
   - 生成された URL をコピー
   - 形式: `https://yourcompany.webhook.office.com/webhookb2/...`
   - ⚠️ **重要**: この URL は外部に漏らさないでください

#### 2.2 複数チャンネルでの設定（推奨）

**推奨チャンネル構成:**
- **一般通知用**: 日次レポート、成功通知
- **緊急通知用**: バックアップ失敗、セキュリティアラート
- **開発者用**: GitHub Actions 通知

各チャンネルで上記手順を繰り返し、用途別に Webhook を作成してください。

---

### ステップ3: Gmail の設定

#### 3.1 Google アカウントでの 2段階認証有効化

1. **Google アカウント設定にアクセス**
   - https://myaccount.google.com/ を開く
   - Google アカウントにログイン

2. **セキュリティ設定**
   - 左メニューから **「セキュリティ」** をクリック
   - **「Google へのログイン」** セクションを確認

3. **2段階認証プロセスの有効化**
   - **「2段階認証プロセス」** をクリック
   - 指示に従って設定（SMS、認証アプリなど）
   - ✅ **「オン」** になっていることを確認

#### 3.2 アプリパスワードの生成

1. **アプリパスワード設定にアクセス**
   - セキュリティページで **「アプリパスワード」** をクリック
   - ※ 2段階認証が有効でないと表示されません

2. **新しいアプリパスワードの作成**
   - **「アプリを選択」** → **「メール」** を選択
   - **「デバイスを選択」** → **「その他（カスタム名）」** を選択
   - カスタム名に **"Microsoft 365 Tools"** と入力
   - **「生成」** をクリック

3. **アプリパスワードの保存**
   - 表示された **16桁のパスワード** をコピー
   - 例: `abcd efgh ijkl mnop`
   - ⚠️ **重要**: このパスワードは再表示されません。安全に保管してください

#### 3.3 受信者メールアドレスの準備

通知を受信したいメールアドレスのリストを用意してください：
- 管理者: `admin@yourcompany.com`
- バックアップチーム: `backup-team@yourcompany.com`
- IT部門: `it-support@yourcompany.com`

---

### ステップ4: 設定ファイルの編集

#### 4.1 通知設定ファイルの編集

```bash
# 設定ファイルを開く
nano Config/notification_config.json
```

#### 4.2 Microsoft Teams 設定の更新

```json
{
  "microsoft_teams": {
    "enabled": true,
    "webhook": "https://yourcompany.webhook.office.com/webhookb2/12345678-1234-1234-1234-123456789012@12345678-1234-1234-1234-123456789012/IncomingWebhook/abcdefghijklmnopqrstuvwxyz/12345678-1234-1234-1234-123456789012",
    "notification_settings": {
      "backup_success": true,
      "backup_failure": true,
      "github_actions": true,
      "security_alerts": true,
      "system_health": true,
      "daily_summary": true
    }
  }
}
```

**設定項目の説明:**
- `enabled`: Teams 通知を有効にするか (`true`/`false`)
- `webhook`: ステップ2で取得した Webhook URL
- `notification_settings`: 各種通知の有効/無効設定

#### 4.3 Gmail 設定の更新

```json
{
  "gmail": {
    "enabled": true,
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587,
    "username": "your-email@gmail.com",
    "app_password": "abcd efgh ijkl mnop",
    "recipients": [
      "admin@yourcompany.com",
      "backup-team@yourcompany.com",
      "it-support@yourcompany.com"
    ],
    "notification_settings": {
      "backup_success": false,
      "backup_failure": true,
      "github_actions": false,
      "security_alerts": true,
      "system_health": true,
      "daily_summary": true
    }
  }
}
```

**設定項目の説明:**
- `enabled`: Gmail 通知を有効にするか (`true`/`false`)
- `username`: 送信元 Gmail アドレス
- `app_password`: ステップ3で生成したアプリパスワード（スペース含む）
- `recipients`: 通知受信者のメールアドレス配列
- `notification_settings`: 通知タイプ別の設定（Teams より細かく制御可能）

#### 4.4 高度な設定（オプション）

```json
{
  "notification_rules": {
    "escalation": {
      "backup_failure_consecutive": {
        "threshold": 2,
        "action": "send_to_all_channels"
      }
    },
    "rate_limiting": {
      "max_notifications_per_hour": 50
    },
    "quiet_hours": {
      "enabled": true,
      "start_time": "22:00",
      "end_time": "06:00",
      "timezone": "Asia/Tokyo"
    }
  }
}
```

---

### ステップ5: 動作テスト

#### 5.1 設定の検証

```bash
# 設定ファイルの構文チェック
./notification_system_enhanced.sh validate
```

**期待される出力:**
```
[2025-07-19 12:00:00] [SUCCESS] 通知設定検証完了
```

#### 5.2 テスト通知の送信

```bash
# テスト通知を送信
./notification_system_enhanced.sh test
```

**期待される結果:**
- **Microsoft Teams**: 設定したチャンネルにテストカードが表示される
- **Gmail**: 受信者にHTML形式のテストメールが届く

#### 5.3 個別機能のテスト

```bash
# バックアップ成功通知のテスト
./notification_system_enhanced.sh backup-success "/test/path" "10MB" "30" "100"

# バックアップ失敗通知のテスト  
./notification_system_enhanced.sh backup-failure "1" "Test failure message"

# 日次サマリーのテスト
./notification_system_enhanced.sh daily-summary "48" "97.9" "1.2GB" "healthy"
```

---

### ステップ6: 統合確認

#### 6.1 バックアップシステムとの統合確認

```bash
# 強化バックアップスクリプトの実行（通知付き）
./backup_script_enhanced.sh
```

**確認項目:**
- バックアップ実行後に Teams/Gmail 通知が送信される
- 通知にバックアップ詳細（サイズ、時間、ファイル数）が含まれる
- 失敗時に緊急通知が送信される

#### 6.2 GitHub Actions 連携確認

GitHub Actions ワークフローが実行されると、自動的に通知が送信されます：
- ワークフロー開始/完了通知
- テスト結果通知
- デプロイメント通知

---

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### Teams 通知が届かない

**確認項目:**
- [ ] Webhook URL が正しく設定されているか
- [ ] URL に余分なスペースや改行が含まれていないか
- [ ] Teams チャンネルでコネクタが有効になっているか

**解決方法:**
```bash
# curlによる直接テスト
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Test message"}' \
  "YOUR_WEBHOOK_URL"
```

#### Gmail 送信が失敗する

**確認項目:**
- [ ] 2段階認証が有効になっているか
- [ ] アプリパスワードが正しく設定されているか
- [ ] ネットワークが smtp.gmail.com:587 にアクセスできるか

**解決方法:**
```bash
# メール送信テスト
echo "Test" | sendemail -f "your-email@gmail.com" \
  -t "recipient@example.com" \
  -u "Test Subject" \
  -s "smtp.gmail.com:587" \
  -xu "your-email@gmail.com" \
  -xp "your-app-password"
```

#### パッケージインストールエラー

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install --fix-missing sendemail
```

**CentOS/RHEL:**
```bash
sudo dnf clean all
sudo dnf install epel-release
sudo dnf install sendemail
```

#### 設定ファイルの JSON エラー

```bash
# JSON構文チェック
python3 -m json.tool Config/notification_config.json
```

---

## 📊 通知内容の詳細

### Microsoft Teams 通知形式

Teams には **Adaptive Cards** 形式で通知が送信されます：

**通知に含まれる情報:**
- 📊 **レベル**: SUCCESS/WARNING/ERROR/CRITICAL
- 🖥️ **ホスト名**: システム識別用
- 🕐 **タイムスタンプ**: 発生時刻
- 🆔 **プロセスID**: デバッグ用
- 🔗 **ダッシュボードリンク**: GitHub Pages ダッシュボードへのリンク

**視覚的特徴:**
- カラーコード（緑：成功、赤：エラー、黄：警告）
- Microsoft アイコン
- クリック可能なアクションボタン

### Gmail 通知形式

Gmail には **HTML形式** でリッチなメールが送信されます：

**メール構成:**
- 📧 **件名**: 絵文字 + 通知タイトル
- 🎨 **HTML本文**: Microsoft スタイルのデザイン
- 📋 **詳細情報**: システム情報、実行時間など
- 🔗 **フッター**: プロジェクト情報とリンク

**重要度別の色分け:**
- 🟢 **成功**: 緑色のアラートボックス
- 🟡 **警告**: 黄色のアラートボックス  
- 🔴 **エラー**: 赤色のアラートボックス
- ⚫ **重大**: 太字の赤色アラート

---

## 🔒 セキュリティ考慮事項

### 認証情報の保護

- **アプリパスワード**: 通常のパスワードより権限が限定的
- **Webhook URL**: 外部に漏らさず、定期的にローテーション
- **設定ファイル**: 適切なファイル権限（640）を設定

### ログ監視

通知システムのログは以下に記録されます：
```
logs/notifications.log
```

定期的にログを確認し、異常な送信がないかチェックしてください。

### レート制限

過剰な通知を防ぐため、以下の制限が設定されています：
- **最大通知数**: 1時間あたり50件
- **静寂時間**: 22:00-06:00（設定可能）
- **緊急時オーバーライド**: 重大な問題は制限を無視

---

## 📈 運用のベストプラクティス

### チャンネル/受信者の使い分け

**Microsoft Teams:**
- **一般監視チャンネル**: 日次レポート、成功通知
- **緊急対応チャンネル**: 失敗、セキュリティアラート
- **開発者チャンネル**: GitHub Actions、テスト結果

**Gmail:**
- **管理者**: 全ての重要な通知
- **運用チーム**: バックアップ、システムヘルス
- **開発チーム**: GitHub Actions、デプロイメント

### 通知頻度の調整

```json
{
  "notification_settings": {
    "backup_success": false,  // 成功は Teams のみ
    "backup_failure": true,   // 失敗は Teams + Gmail
    "daily_summary": true     // サマリーは両方
  }
}
```

### 定期メンテナンス

**月次タスク:**
- Webhook URL の有効性確認
- アプリパスワードのローテーション
- 通知ログの分析
- 不要な受信者の削除

**年次タスク:**
- Teams コネクタの再設定
- Gmail アカウントのセキュリティ監査
- 通知内容の見直し

---

## 📞 サポート情報

### ログファイル場所

```
logs/notifications.log          # 通知システム全般
logs/backup_security.log       # セキュリティ関連
logs/backup_audit.log          # 監査証跡
```

### 設定ファイル場所

```
Config/notification_config.json    # 通知設定
Config/appsettings.json            # アプリケーション設定
```

### コマンドリファレンス

```bash
# 設定検証
./notification_system_enhanced.sh validate

# テスト通知
./notification_system_enhanced.sh test

# 依存関係確認
./setup_notification_dependencies.sh verify

# Gmail設定ガイド表示
./setup_notification_dependencies.sh gmail-guide

# Teams設定ガイド表示  
./setup_notification_dependencies.sh teams-guide
```

---

## ✅ セットアップ完了チェックリスト

### 必須項目

- [ ] 依存パッケージがインストールされている
- [ ] Microsoft Teams の Webhook が設定されている
- [ ] Gmail のアプリパスワードが生成されている
- [ ] `notification_config.json` が正しく編集されている
- [ ] テスト通知が正常に送信される
- [ ] バックアップシステムとの統合が確認できている

### 推奨項目

- [ ] 複数の Teams チャンネルを用途別に設定
- [ ] 複数の Gmail 受信者を設定
- [ ] 静寂時間を設定
- [ ] レート制限を適切に設定
- [ ] 定期メンテナンス計画を策定

### セキュリティ項目

- [ ] アプリパスワードが安全に保管されている
- [ ] Webhook URL が外部に漏れていない
- [ ] 設定ファイルの権限が適切に設定されている
- [ ] ログ監視体制が整っている

---

🎉 **セットアップ完了！**

これで Microsoft Teams と Gmail による包括的な通知システムが利用可能になりました。バックアップの成功/失敗、システムの状態変化、GitHub Actions の実行結果など、すべての重要なイベントがリアルタイムで通知されます。