# Microsoft 365管理ツール セキュリティポリシー

策定日: 2025年1月17日  
策定者: CTO  
バージョン: 1.0  
機密レベル: 社内限定

## 1. セキュリティ原則

### 1.1 基本原則
1. **最小権限の原則**: 各コンポーネントは必要最小限の権限のみを持つ
2. **多層防御**: 複数のセキュリティレイヤーを実装
3. **ゼロトラスト**: すべてのアクセスを検証
4. **監査証跡**: すべての操作を記録・保持

### 1.2 コンプライアンス要件
- **ITSM（ISO/IEC 20000）** 準拠
- **ISO/IEC 27001** 情報セキュリティマネジメント準拠
- **ISO/IEC 27002** セキュリティ管理策準拠
- **GDPR** データ保護規則準拠

## 2. 認証・認可

### 2.1 認証方式
#### 優先順位（高→低）
1. **証明書ベース認証**（推奨）
   - X.509証明書使用
   - 有効期限管理必須
   - 秘密鍵の安全な保管

2. **クライアントシークレット認証**
   - Azure Key Vaultでの管理推奨
   - 定期的なローテーション（90日）

3. **対話型認証**（禁止）
   - 自動化環境では使用不可
   - 開発・テスト環境のみ許可

### 2.2 アプリケーション権限
```json
{
  "必須権限": {
    "Microsoft Graph": [
      "User.Read.All",
      "Directory.Read.All",
      "Group.Read.All",
      "Reports.Read.All"
    ],
    "Exchange Online": [
      "Exchange.ManageAsApp",
      "full_access_as_app"
    ]
  },
  "オプション権限": {
    "Premium機能": [
      "AuditLog.Read.All",
      "SecurityEvents.Read.All"
    ]
  }
}
```

### 2.3 証明書管理ポリシー
1. **保管場所**
   - 本番: Certificates/ディレクトリ（暗号化必須）
   - 開発: ローカル証明書ストア

2. **アクセス制御**
   ```powershell
   # ファイルシステム権限設定
   icacls "Certificates\" /inheritance:r
   icacls "Certificates\" /grant:r "SYSTEM:(OI)(CI)F"
   icacls "Certificates\" /grant:r "$env:USERNAME:(OI)(CI)R"
   ```

3. **証明書ローテーション**
   - 有効期限90日前に更新開始
   - 自動更新スクリプトの実装
   - 更新履歴の記録

## 3. データ保護

### 3.1 機密データの分類
| レベル | 定義 | 例 | 保護要件 |
|-------|------|-----|---------|
| 極秘 | 漏洩時に重大な影響 | 認証情報、証明書 | 暗号化必須、アクセス記録 |
| 機密 | 限定的な影響 | ユーザー情報、ライセンス | 暗号化推奨、権限制御 |
| 社内限定 | 内部使用のみ | レポート、ログ | アクセス制御 |
| 公開 | 影響なし | ドキュメント | 制限なし |

### 3.2 暗号化要件
1. **保存時暗号化**
   - 証明書ファイル: AES-256
   - 設定ファイル: DPAPI（Windows）
   - バックアップ: BitLocker/FileVault

2. **通信時暗号化**
   - API通信: TLS 1.2以上
   - 内部通信: HTTPS必須
   - メール送信: STARTTLS

3. **暗号化実装例**
   ```powershell
   # SecureStringの使用
   $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force
   
   # DPAPI暗号化
   $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
       $bytes,
       $null,
       [System.Security.Cryptography.DataProtectionScope]::CurrentUser
   )
   ```

### 3.3 データ保持ポリシー
| データ種別 | 保持期間 | 削除方法 |
|-----------|---------|---------|
| 監査ログ | 7年 | 自動アーカイブ後削除 |
| レポート | 3年 | 手動確認後削除 |
| 一時ファイル | 7日 | 自動削除 |
| バックアップ | 1年 | 世代管理 |

## 4. アクセス制御

### 4.1 ロールベースアクセス制御（RBAC）
```powershell
# ロール定義
$roles = @{
    "Administrator" = @{
        Permissions = @("*")
        Description = "完全な管理権限"
    }
    "Operator" = @{
        Permissions = @("Read", "Execute", "Report")
        Description = "運用担当者"
    }
    "Auditor" = @{
        Permissions = @("Read", "Audit")
        Description = "監査担当者"
    }
    "Viewer" = @{
        Permissions = @("Read")
        Description = "閲覧のみ"
    }
}
```

### 4.2 実行権限制御
1. **スクリプト実行ポリシー**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
   ```

2. **管理者権限チェック**
   ```powershell
   function Test-Administrator {
       $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
       $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
       return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
   }
   ```

## 5. 脆弱性対策

### 5.1 入力検証
```powershell
# パラメータ検証の実装
function Validate-UserInput {
    param(
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]$Email,
        
        [Parameter(Mandatory=$true)]
        [ValidateRange(1,1000)]
        [int]$MaxResults
    )
}
```

### 5.2 インジェクション対策
1. **SQLインジェクション**: パラメータ化クエリ使用
2. **コマンドインジェクション**: 
   ```powershell
   # 悪い例
   Invoke-Expression "Get-User -Name $userName"
   
   # 良い例
   Get-User -Name $userName
   ```
3. **パスインジェクション**: 
   ```powershell
   # パス検証
   $safePath = [System.IO.Path]::GetFullPath($userPath)
   if (-not $safePath.StartsWith($allowedBasePath)) {
       throw "不正なパスです"
   }
   ```

### 5.3 セキュアコーディング
```powershell
# セキュリティヘッダーの実装（Webレポート用）
$htmlHeaders = @"
<meta http-equiv="Content-Security-Policy" content="default-src 'self'">
<meta http-equiv="X-Content-Type-Options" content="nosniff">
<meta http-equiv="X-Frame-Options" content="DENY">
<meta http-equiv="X-XSS-Protection" content="1; mode=block">
"@
```

## 6. 監査とログ

### 6.1 ログ記録要件
1. **必須記録項目**
   - タイムスタンプ（UTC）
   - ユーザー/サービス識別子
   - 操作内容
   - 結果（成功/失敗）
   - ソースIP（該当する場合）

2. **ログレベル**
   ```powershell
   enum LogLevel {
       Debug = 0
       Info = 1
       Warning = 2
       Error = 3
       Critical = 4
       Security = 5  # セキュリティイベント専用
   }
   ```

### 6.2 監査ログ保護
```powershell
# ログファイルの改ざん防止
function Write-AuditLog {
    param($Message)
    
    $logEntry = @{
        Timestamp = (Get-Date).ToUniversalTime()
        Message = $Message
        User = $env:USERNAME
        Hash = Get-FileHash -Algorithm SHA256
    }
    
    # 追記のみ許可
    Add-Content -Path $auditLogPath -Value (ConvertTo-Json $logEntry) -Encoding UTF8
}
```

### 6.3 セキュリティイベント監視
- 認証失敗（3回連続で警告）
- 権限昇格の試行
- 大量データのエクスポート
- 設定変更
- 証明書アクセス

## 7. インシデント対応

### 7.1 インシデント分類
| レベル | 定義 | 対応時間 | エスカレーション |
|-------|------|---------|----------------|
| 緊急 | サービス全体に影響 | 即時 | CTO直通 |
| 高 | 一部機能に影響 | 1時間以内 | 管理者 |
| 中 | 限定的影響 | 4時間以内 | 運用チーム |
| 低 | 影響なし | 翌営業日 | 記録のみ |

### 7.2 対応手順
```powershell
# インシデント検知時の自動対応
function Respond-SecurityIncident {
    param($IncidentType, $Severity)
    
    # 1. ログ記録
    Write-SecurityLog -Event $IncidentType -Severity $Severity
    
    # 2. 影響範囲の特定
    $impact = Assess-Impact -Type $IncidentType
    
    # 3. 初期対応
    switch ($Severity) {
        "Critical" { 
            # サービス停止
            Stop-Service -Name "M365ManagementTool"
            # 通知
            Send-Alert -To "security-team@company.com"
        }
        "High" {
            # 該当機能の無効化
            Disable-Feature -Name $impact.Feature
        }
    }
    
    # 4. 証跡保全
    Export-ForensicData -IncidentId $incident.Id
}
```

## 8. セキュリティテスト

### 8.1 定期的なセキュリティ評価
1. **月次**
   - 証明書有効期限チェック
   - アクセス権限レビュー
   - パッチ適用状況確認

2. **四半期**
   - ペネトレーションテスト
   - 脆弱性スキャン
   - セキュリティ設定監査

3. **年次**
   - 完全なセキュリティ監査
   - BCP訓練
   - ポリシー見直し

### 8.2 セキュリティテストスクリプト
```powershell
# TestScripts/security-test.ps1
function Test-SecurityCompliance {
    $results = @()
    
    # 証明書チェック
    $results += Test-CertificateExpiry
    
    # 権限チェック
    $results += Test-MinimumPrivileges
    
    # 暗号化チェック
    $results += Test-EncryptionStatus
    
    # 監査ログチェック
    $results += Test-AuditLogIntegrity
    
    return $results
}
```

## 9. セキュリティ更新手順

### 9.1 パッチ管理
1. **評価**: セキュリティアドバイザリーの確認
2. **テスト**: 開発環境での検証
3. **承認**: CTOによる適用承認
4. **適用**: 段階的ロールアウト
5. **検証**: 適用後の動作確認

### 9.2 緊急パッチ適用
```powershell
# 緊急パッチ適用プロセス
function Apply-EmergencyPatch {
    # バックアップ
    Backup-CurrentConfiguration
    
    # サービス停止
    Stop-AllServices
    
    # パッチ適用
    Install-SecurityUpdate
    
    # 検証
    Test-CoreFunctionality
    
    # サービス再開
    Start-AllServices
}
```

## 10. コンプライアンスチェックリスト

- [ ] すべての認証情報が暗号化されているか
- [ ] 証明書の有効期限が90日以上あるか
- [ ] アクセスログが適切に記録されているか
- [ ] 最小権限の原則が守られているか
- [ ] セキュリティパッチが最新か
- [ ] 監査ログの改ざん防止が実装されているか
- [ ] インシデント対応手順が文書化されているか
- [ ] データ保持ポリシーが遵守されているか
- [ ] セキュリティテストが定期的に実施されているか
- [ ] 従業員へのセキュリティ教育が実施されているか

## 改訂履歴

| バージョン | 日付 | 変更内容 | 承認者 |
|---------|------|---------|--------|
| 1.0 | 2025-01-17 | 初版作成 | CTO |

## 付録: セキュリティ連絡先

- セキュリティインシデント: security@company.com
- CTO直通: cto@company.com
- 24時間ホットライン: +81-3-XXXX-XXXX