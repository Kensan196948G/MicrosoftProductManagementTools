# Azure アプリ登録 証明書更新手順書

## 前提
- 事前にCSP証明書（.cerファイル）を作成済み
- Azureポータルへアクセス可能な管理者権限を保有
- 証明書ファイル: `Certificates/MiraiConstEXO.cer`

---

## 【1】Azureポータルへサインイン

1. Webブラウザで下記URLへアクセス
   ```
   https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Overview
   ```

2. 管理者アカウントでログイン

---

## 【2】アプリ登録画面へ移動

3. 左メニューから「Microsoft Entra ID」をクリック
4. 「アプリの登録」をクリック
5. 「365 Pro Toolkit Application」をクリック

---

## 【3】証明書のアップロード

6. 左メニューから「証明書とシークレット」をクリック
7. 「証明書」タブをクリックし、「証明書のアップロード」ボタンをクリック
8. 作成済みの .cer ファイル（`Certificates/MiraiConstEXO.cer`）を選択して「追加」

---

## 【4】アップロード完了・確認・テスト

9. アップロード後、証明書一覧に新しいThumbprint（拇印）が表示されることを確認
   - Thumbprintの値を記録する（PowerShellで取得した値と一致すること）

10. 証明書の有効期限やSubject名も確認・記録

11. **重要**: 新しい証明書での接続テストを実施
    - `Config/appsettings.json` の Thumbprint 値を新しい値に更新
    - PowerShellスクリプトで接続テストを実行
    - 正常に動作することを確認

---

## 【5】古い証明書の削除

12. 接続テスト完了後、古い証明書を削除
    - 古い証明書（拇印: `94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6`、有効期限: 2026/6/4）の行を探す
    - 古い証明書の右端にある「削除」アイコン（ゴミ箱マーク）をクリック
    - 削除確認ダイアログで「はい」または「削除」をクリックして確定
    - 古い証明書が一覧から消えることを確認

---

## 【6】アプリケーション権限の確認（必要に応じて）

13. 「APIのアクセス許可」から、Exchange Online用の必要な権限が設定されているか確認

### 必要な権限（Office 365 Exchange Online）:
- `Exchange.ManageAsApp`
- `Mail.ReadWrite`
- `Mail.Send`
- `MailboxSettings.ReadWrite`

### Microsoft Graph権限（補助的）:
- `User.Read.All`
- `Group.Read.All`

14. 未追加の権限がある場合:
    - 「アクセス許可の追加」をクリック
    - 「Office 365 Exchange Online」または「Microsoft Graph」から権限を選択
    - 「アプリケーションのアクセス許可」を選択
    - 権限を追加後、「管理者の同意の付与」を必ず実施

---

## 【7】設定ファイルの更新

15. `Config/appsettings.json` の以下の値を更新:
    ```json
    {
      "EntraID": {
        "CertificateThumbprint": "3C5C3A9C4F97CD1C95DFDB389AB1F371AAB87975"
      },
      "ExchangeOnline": {
        "CertificateThumbprint": "3C5C3A9C4F97CD1C95DFDB389AB1F371AAB87975"
      }
    }
    ```
    
    **更新完了**: 2025年6月11日
    - 旧Thumbprint: `94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6`
    - 新Thumbprint: `3C5C3A9C4F97CD1C95DFDB389AB1F371AAB87975`

---

## 【8】最終確認・テスト

16. 全スクリプトでの動作確認:
    - 日次レポート生成テスト
    - Exchange Online 接続テスト
    - Microsoft Graph 接続テスト

17. ログファイルでエラーがないことを確認

---

## 【9】手順完了

証明書更新作業完了。次回更新予定日をカレンダーに登録することを推奨。

## 注意事項

- **セキュリティ**: 古い証明書は新しい証明書での動作確認完了後に削除する
- **バックアップ**: 設定変更前に `Config/appsettings.json` のバックアップを作成する
- **ログ監視**: 更新後数日間はログを注意深く監視する
- **証明書有効期限**: 定期的な更新スケジュールを設定する