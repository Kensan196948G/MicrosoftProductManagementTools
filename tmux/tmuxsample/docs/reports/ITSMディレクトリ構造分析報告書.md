# ITSMディレクトリ構造調査報告書

## 調査概要
- 調査日時: 2025-07-11
- 調査対象: /media/kensan/LinuxHDD/ITSM-ITmanagementSystem/
- 調査者: dev4 (システム分析・アーキテクト)

## 1. ルートディレクトリ構造

### 主要ディレクトリ一覧
```
/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/
├── .claude/           # Claude設定ファイル
├── .github/           # GitHub関連設定
├── .pids/             # プロセスIDファイル
├── Archive/           # アーカイブファイル
├── Docs/              # 🔴 ドキュメント(大文字)
├── docs/              # 🔴 ドキュメント(小文字)
├── ai-integration/    # AI統合モジュール
├── analytics/         # 分析モジュール
├── automation/        # 自動化スクリプト
├── cypress/           # E2Eテストフレームワーク
├── database/          # データベース関連
├── deployment/        # デプロイ設定
├── docker/            # Docker設定
├── Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/  # 緊急バックアップ
├── frontend/          # フロントエンド
├── infrastructure/    # インフラ設定
├── itsm-backend/      # バックエンドAPI
├── kubernetes/        # Kubernetes設定
├── logs/              # ログファイル
├── monitoring/        # 監視システム
├── node_modules/      # NPMパッケージ
└── tmux/              # tmux統合ツール
```

### ディレクトリ統計
- 総ディレクトリ数: 187個
- 深度レベル: 最大4階層
- 主要機能領域: 16個

## 2. Docs vs docs 重複分析

### 構造比較
| 項目 | Docs/ | docs/ |
|------|-------|-------|
| ファイル数 | 52個 | 59個 |
| 構造 | 階層型(01-09番号付き) | フラット型 |
| 言語 | 主に日本語 | 英語・日本語混在 |
| 用途 | 正式ドキュメント | 作業用ドキュメント |

### Docs/ 構造 (階層型)
```
Docs/
├── 01-Project-Overview/    # プロジェクト概要
├── 02-Requirements/        # 要件定義
├── 03-Architecture/        # アーキテクチャ
├── 04-Development/         # 開発ガイド
├── 05-Testing/            # テスト関連
├── 06-Quality-Assurance/  # QA関連
├── 07-Security/           # セキュリティ
├── 08-Operations/         # 運用
└── 09-Integration-Guides/ # 統合ガイド
```

### docs/ 構造 (フラット型)
```
docs/
├── api/                   # API仕様
├── database/             # DB設計
├── dev-instructions/     # 開発指示
├── migration/            # マイグレーション
├── operations/           # 運用マニュアル
├── problem-management/   # 問題管理
├── reports/              # 報告書
└── tmux-integration/     # tmux統合
```

## 3. ファイル参照関係

### 重複ファイル名検出
- 総重複ファイル名: 78個
- 主要重複:
  - README.md (複数バージョン)
  - operations-manual.md
  - quality-assessment-report.md
  - manager.md, developer.md, ceo.md
  - operation-manual.md

### 相互参照関係
- Docs/→docs/: 限定的な参照
- docs/→Docs/: 参照関係なし
- tmux/→両方: 独立した参照

## 4. 不要ファイル特定

### 分類結果
| カテゴリ | 件数 | 削除対象 |
|----------|------|----------|
| node_modules/*.md | 594個 | ✅ 削除推奨 |
| *.log | 40個 | ✅ 削除推奨 |
| *backup* | 39個 | ⚠️ 選択的削除 |
| 重複README | 15個 | ⚠️ 統合検討 |
| 古いバックアップ | 5個 | ✅ 削除推奨 |

### 削除候補詳細
1. **node_modules/**: 594個のMarkdownファイル (パッケージドキュメント)
2. **ログファイル**: 40個の.logファイル
3. **バックアップファイル**: 39個のバックアップファイル
4. **重複README**: 複数バージョンのREADMEファイル

## 5. 整理提案

### 優先度A (緊急)
1. **Docs/docs統合**: 統一的なドキュメント構造へ
2. **node_modules清掃**: 594個の不要ファイル削除
3. **ログファイル管理**: 40個のログファイル整理

### 優先度B (重要)
1. **バックアップ整理**: 古いバックアップファイル削除
2. **重複ファイル統合**: README等の重複解消
3. **ディレクトリ命名統一**: 一貫性向上

### 優先度C (改善)
1. **アーカイブ整理**: Archive/ディレクトリ見直し
2. **tmux統合**: tmux/ディレクトリ最適化
3. **ドキュメント階層**: 統一的な階層構造

## 6. 技術的影響評価

### リスク評価
- **高リスク**: Docs/docs統合時の参照切れ
- **中リスク**: バックアップファイル削除
- **低リスク**: node_modules、ログファイル削除

### 推奨作業順序
1. バックアップ作成
2. 不要ファイル削除 (node_modules、logs)
3. 重複ファイル整理
4. Docs/docs統合検討
5. 最終検証

## 7. 結論

### 現状評価
- **構造**: 機能別に良好な分離
- **問題**: Docs/docs重複、大量の不要ファイル
- **改善効果**: 30%以上のファイル削減可能

### 次フェーズ推奨事項
1. 段階的な統合アプローチ
2. 自動化スクリプトによる継続的清掃
3. ドキュメント管理ルールの策定

---
**調査完了**: 2025-07-11
**担当者**: dev4 (システム分析・アーキテクト)