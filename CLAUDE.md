# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

ITSM（ISO/IEC 20000）、ISO/IEC 27001、ISO/IEC 27002標準に準拠したエンタープライズ向けMicrosoft 365管理ツール群です。Active Directory、Entra ID、Exchange Online、OneDrive、Microsoft Teamsの自動監視、レポート生成、コンプライアンス追跡機能を提供します。

## アーキテクチャ

コードベースはモジュラー型PowerShellアーキテクチャに従います：

- **Scripts/Common/**: 共通機能を提供するコアモジュール
  - `Common.psm1`: メイン初期化と設定読み込み
  - `Authentication.psm1`: 全Microsoftサービス統一認証
  - `Logging.psm1`: 監査証跡対応の集中ログ機能
  - `ErrorHandling.psm1`: 標準化されたエラーハンドリングと再試行ロジック
  - `ReportGenerator.psm1`: HTMLおよびCSVレポート生成
  - `ScheduledReports.ps1`: 日次/週次/月次/年次レポートのオーケストレーション

- **Scripts/AD/**: Active Directory管理スクリプト
- **Scripts/EXO/**: Exchange Online監視・分析
- **Scripts/EntraID/**: Entra ID、Teams、OneDrive管理

- **TestScripts/**: 開発・テスト用スクリプト群
  - `test-auth.ps1`: 基本認証テスト
  - `test-all-features.ps1`: 全機能統合テスト
  - `test-graph-features.ps1`: Microsoft Graph機能テスト
  - `test-onedrive-gui.ps1`: OneDrive GUI機能テスト

## 設定

全設定は`Config/appsettings.json`で一元管理されています。主要セクション：
- 認証資格情報と証明書
- レポート閾値とスケジューリング
- コンプライアンスとセキュリティ設定
- パフォーマンスと再試行設定

## 主要コマンド

### スクリプト実行
```powershell
# 管理ツールの初期化
Import-Module Scripts\Common\Common.psm1
$config = Initialize-ManagementTools

# 定期レポートの実行
Scripts\Common\ScheduledReports.ps1 -ReportType "Daily"    # 日次
Scripts\Common\ScheduledReports.ps1 -ReportType "Weekly"   # 週次
Scripts\Common\ScheduledReports.ps1 -ReportType "Monthly"  # 月次
Scripts\Common\ScheduledReports.ps1 -ReportType "Yearly"   # 年次
```

### 認証設定
認証は非対話型実行のために証明書ベースまたはクライアントシークレット方式を使用します。スクリプト実行前に`Config/appsettings.json`で資格情報を設定してください。

### テスト実行
```powershell
# 基本認証テスト
TestScripts\test-auth.ps1

# 全機能統合テスト
TestScripts\test-all-features.ps1

# Microsoft Graph機能テスト
TestScripts\test-graph-features.ps1
```

## レポート構造

生成されるレポートは`Reports/`ディレクトリに頻度別に保存されます：
- `Daily/`: ログイン失敗、容量監視、添付ファイル分析
- `Weekly/`: MFA状況、外部共有、グループレビュー
- `Monthly/`: 利用率、権限レビュー、スパム分析
- `Yearly/`: ライセンス消費、インシデント統計、コンプライアンスアーカイブ

全レポートはコンプライアンス要件のためにHTML（ダッシュボード）とCSV（監査証跡）の両形式で生成されます。

## エラーハンドリング

システムは以下を実装しています：
- 自動再試行ロジック（最大7回）
- `Logs/`ディレクトリへの包括的ログ記録
- 一時的障害の自己修復機能
- 1年間保持の監査証跡維持

## 開発時の注意事項

- 全スクリプトはPowerShell 5.1+またはPowerShell 7が必要
- 必須モジュール: ExchangeOnlineManagement、Microsoft.Graph
- 自動化のため実行ポリシーはRemoteSignedまたはBypassが必要
- スクリプトはタスクスケジューラーでの非対話型実行向けに設計