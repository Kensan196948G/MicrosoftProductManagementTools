# Python移行タスク優先順位表

## プロジェクト概要
PowerShell版26機能をPython版へ段階的に移行するためのタスク管理と優先順位付け

作成日: 2025年1月18日
更新日: 2025年1月18日

## 実装状況サマリー

### 実装済み機能（リアルデータ取得可能）: 7/26 (27%)
- ✅ ユーザー一覧
- ✅ MFA状況
- ✅ ライセンス分析
- ✅ メールボックス管理（基本機能）
- ✅ Teams使用状況（一部）
- ✅ ストレージ分析
- ✅ 日次レポート（基本機能）

### モックデータ使用: 18/26 (69%)
### 未実装: 1/26 (4%)

## 優先順位マトリックス

### 🔴 P0: 緊急対応（1週間以内）

#### 1. テスト環境整備
- [ ] requirements.txt作成とpytestインストール
- [ ] CI/CD環境でのテスト自動実行設定
- [ ] 実装済み機能の単体テスト実行
- [ ] カバレッジレポート生成

#### 2. PowerShellブリッジ強化
- [ ] Exchange Online接続メソッド実装
- [ ] Exchange管理コマンドのラッパー追加
- [ ] セッション管理とエラーハンドリング強化

### 🟠 P1: 高優先度（2-3週間）

#### 3. 定期レポート機能の完成
- [ ] 週次レポート固有ロジック実装
- [ ] 月次レポート固有ロジック実装
- [ ] 年次レポート固有ロジック実装
- [ ] レポートスケジューラー実装

#### 4. セキュリティ・権限管理機能
- [ ] セキュリティ分析（サインインログ、リスクスコア）
- [ ] 権限監査（管理者権限、委任権限）
- [ ] 条件付きアクセスポリシー取得

### 🟡 P2: 中優先度（1ヶ月）

#### 5. Exchange Online完全統合
- [ ] メールフロー分析（PowerShellブリッジ経由）
- [ ] スパム対策分析
- [ ] 配信分析
- [ ] メッセージトレース機能

#### 6. 使用状況・パフォーマンス分析
- [ ] 使用状況分析（全サービス統合）
- [ ] パフォーマンス分析（応答時間、遅延）
- [ ] サービス正常性統合

### 🟢 P3: 低優先度（2ヶ月以降）

#### 7. Teams高度機能
- [ ] Teams設定分析
- [ ] 会議品質分析（通話品質API）
- [ ] アプリ分析

#### 8. OneDrive高度機能
- [ ] 共有分析（共有リンク詳細）
- [ ] 同期エラー分析
- [ ] 外部共有ポリシー分析

## タスク分解詳細

### P0-1: テスト環境整備（3日）

```python
# requirements.txt
pytest>=7.0.0
pytest-cov>=4.0.0
pytest-qt>=4.2.0
pytest-asyncio>=0.20.0
pytest-mock>=3.10.0
```

**実装タスク:**
1. requirements.txt作成
2. 仮想環境セットアップスクリプト作成
3. pytest.ini設定ファイル作成
4. GitHub Actions設定（.github/workflows/python-tests.yml）
5. 初回テスト実行と問題修正

### P0-2: PowerShellブリッジ強化（5日）

**実装タスク:**
1. ExchangeOnlineBridgeクラス作成
2. connect_exchange_online()メソッド実装
3. Exchange管理コマンドのラッパーメソッド追加:
   - get_mailbox_statistics()
   - get_message_trace()
   - get_mail_flow_statistics()
4. エラーハンドリングとリトライロジック強化
5. 統合テスト作成

### P1-3: 定期レポート完成（7日）

**実装タスク:**
1. ReportService拡張:
   - generate_weekly_report()実装
   - generate_monthly_report()実装
   - generate_yearly_report()実装
2. レポート集計ロジック:
   - 期間別データ集計
   - トレンド分析
   - 前期比較
3. スケジューラー実装:
   - APSchedulerまたはCelery統合
   - cron式サポート
4. テスト作成

### P1-4: セキュリティ・権限機能（7日）

**実装タスク:**
1. SecurityServiceクラス作成:
   - get_signin_logs()
   - get_risk_detections()
   - get_security_alerts()
2. PermissionServiceクラス作成:
   - get_role_assignments()
   - get_privileged_users()
   - audit_permissions()
3. ConditionalAccessServiceクラス作成
4. レポート生成とテスト

## 技術的依存関係

### 必須前提条件
1. Python 3.9+ インストール
2. Microsoft Graph API権限設定
3. Exchange Online管理者権限
4. テスト用Azure ADテナント

### API権限要件
```
# Microsoft Graph
- User.Read.All
- Reports.Read.All
- AuditLog.Read.All
- Directory.Read.All
- SecurityEvents.Read.All

# Exchange Online
- Exchange管理者ロール
- View-Only Recipients
- Message Tracking
```

## リスクと軽減策

### リスク1: API権限不足
**軽減策**: 段階的な権限申請とフォールバック実装

### リスク2: PowerShell依存
**軽減策**: PowerShellブリッジの早期完成と代替API調査

### リスク3: パフォーマンス劣化
**軽減策**: 非同期処理、バッチAPI、キャッシュ実装

## 成功指標

1. **機能カバレッジ**: 26機能中20機能以上の実装（77%）
2. **テストカバレッジ**: 80%以上
3. **パフォーマンス**: PowerShell版と同等以上
4. **互換性**: CSV/HTML出力の100%互換

## 次のアクション

1. **今週**: P0タスクの実行開始
2. **来週**: P1タスクの計画詳細化
3. **定例**: 週次進捗レビューと優先度調整