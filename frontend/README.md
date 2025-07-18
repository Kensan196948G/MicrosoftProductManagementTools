# Microsoft 365 Admin Tools - React Frontend

PowerShell Windows Forms GUIからReact + TypeScriptへの完全移行プロジェクト

## 🚀 技術スタック

- **React 18** - 最新のReactフレームワーク
- **TypeScript 5.0** - 型安全な開発
- **Material-UI v5** - エンタープライズ向けUIコンポーネント
- **Vite** - 高速ビルドツール
- **Zustand** - 軽量状態管理
- **React Router** - ルーティング

## 🏗️ アーキテクチャ

```
frontend/
├── src/
│   ├── components/          # 再利用可能なUIコンポーネント
│   │   ├── Layout/          # レイアウトコンポーネント
│   │   ├── Navigation/      # ナビゲーションコンポーネント
│   │   └── FunctionCard/    # 機能カードコンポーネント
│   ├── pages/               # ページコンポーネント
│   │   └── MainDashboard/   # メインダッシュボード
│   ├── types/               # TypeScript型定義
│   ├── theme/               # Material-UI テーマ設定
│   ├── config/              # 設定ファイル
│   ├── hooks/               # カスタムフック
│   ├── utils/               # ユーティリティ関数
│   └── api/                 # API通信関数
├── public/                  # 静的ファイル
└── dist/                    # ビルド出力
```

## 🎯 機能対応状況

### ✅ 完了した機能
- **基本アーキテクチャ** - React + TypeScript + Material-UI
- **レスポンシブデザイン** - モバイル・タブレット・デスクトップ対応
- **ダークモード** - ライト・ダークテーマ切り替え
- **26機能の完全定義** - 全機能をReactコンポーネントで実装
- **エンタープライズUI** - プロフェッショナルなデザインシステム

### 🔄 Phase 1: 定期レポート機能群 (優先実装)
- 📅 日次レポート
- 📊 週次レポート
- 📈 月次レポート
- 📆 年次レポート
- 🧪 テスト実行
- 📋 最新日次レポート表示

### 📋 Phase 2: 残り21機能
- 🔍 分析レポート (5機能)
- 👥 Entra ID管理 (4機能)
- 📧 Exchange Online (4機能)
- 💬 Teams管理 (4機能)
- 💾 OneDrive管理 (4機能)

## 💻 開発環境セットアップ

### 前提条件
- Node.js 18.x以上
- npm 9.x以上

### インストール
```bash
cd frontend
npm install
```

### 開発サーバー起動
```bash
npm run dev
```
http://localhost:3000 でアクセス可能

### ビルド
```bash
npm run build
```

### テスト実行
```bash
npm test                 # テスト実行
npm run test:ui          # UIテスト
npm run test:coverage    # カバレッジ測定
```

### 静的解析
```bash
npm run lint            # ESLint実行
npm run type-check      # TypeScript型チェック
```

## 🎨 UI/UXデザイン仕様

### カラーパレット
- **Primary**: #0078d4 (Microsoft Blue)
- **Secondary**: #6c757d (Gray)
- **Success**: #28a745 (Green)
- **Warning**: #ffc107 (Yellow)
- **Error**: #dc3545 (Red)
- **Info**: #17a2b8 (Cyan)

### フォント
- **Primary**: Segoe UI, Roboto, sans-serif
- **Headings**: 600 weight
- **Body**: 400 weight
- **Buttons**: 500 weight

### レスポンシブブレークポイント
- **xs**: 0px
- **sm**: 600px
- **md**: 900px
- **lg**: 1200px
- **xl**: 1536px

## 🔧 パフォーマンス最適化

### 実装済み最適化
- **コード分割** - 機能別バンドル分割
- **遅延読み込み** - 画像・コンポーネント遅延読み込み
- **キャッシュ戦略** - Service Worker実装
- **バンドル最適化** - Tree shaking・minification

### パフォーマンス目標
- **Lighthouse Performance**: 90点以上
- **First Contentful Paint**: 1.5秒以内
- **Largest Contentful Paint**: 2.5秒以内
- **Cumulative Layout Shift**: 0.1以下

## ♿ アクセシビリティ

### WCAG 2.1 AA準拠
- **キーボードナビゲーション** - 全機能キーボード操作対応
- **スクリーンリーダー** - ARIA属性完全対応
- **コントラスト比** - 4.5:1以上
- **フォーカス管理** - 明確なフォーカス表示

### 実装済み機能
- **高コントラストモード** - システム設定対応
- **カラーブラインド対応** - 色以外の情報提供
- **モーション制御** - reduce-motion対応

## 🔐 セキュリティ

### 実装済み対策
- **XSS対策** - 入力値サニタイズ
- **CSRF対策** - トークンベース認証
- **Content Security Policy** - 厳格なCSP設定
- **HTTPS強制** - 本番環境HTTPS必須

## 🧪 テスト戦略

### テスト種別
- **Unit Tests** - コンポーネント単体テスト
- **Integration Tests** - API統合テスト
- **E2E Tests** - エンドツーエンドテスト
- **Visual Regression Tests** - UI変更検出

### テストツール
- **Vitest** - 高速テストランナー
- **React Testing Library** - コンポーネントテスト
- **Playwright** - E2Eテスト
- **Chromatic** - ビジュアルテスト

## 📊 品質メトリクス

### 目標値
- **テストカバレッジ**: 85%以上
- **TypeScript strict mode**: 100%
- **ESLint準拠**: 100%
- **バンドルサイズ**: 1MB未満

## 🚀 デプロイメント

### ビルドプロセス
```bash
npm run build
npm run preview  # ビルド確認
```

### 本番環境
- **CDN**: CloudFront
- **ホスティング**: AWS S3
- **SSL**: AWS Certificate Manager

## 🔄 PowerShellからの移行状況

### 移行完了項目
- ✅ **GUI構造** - タブベースナビゲーション
- ✅ **機能カード** - 26機能の完全定義
- ✅ **レスポンシブ** - モバイル対応
- ✅ **テーマ** - ダークモード対応
- ✅ **通知** - リアルタイム通知システム

### 移行予定項目
- 🔄 **API統合** - バックエンドAPI連携
- 🔄 **認証** - MSAL認証実装
- 🔄 **データ表示** - グラフ・チャート表示
- 🔄 **エクスポート** - CSV・HTML出力

## 📝 開発ガイドライン

### コーディング規約
- **TypeScript strict mode** 必須
- **ESLint + Prettier** 準拠
- **Material-UI** コンポーネント優先使用
- **Semantic HTML** 構造化

### コミット規約
```
feat: 新機能追加
fix: バグ修正
docs: ドキュメント更新
style: スタイル修正
refactor: リファクタリング
test: テスト追加/修正
```

## 🤝 コントリビューション

1. 機能ブランチ作成
2. 実装・テスト追加
3. プルリクエスト作成
4. コードレビュー
5. マージ

## 📞 サポート

- **技術サポート**: dev-team@company.com
- **バグレポート**: GitHub Issues
- **機能要望**: GitHub Discussions

---

**開発チーム**: Microsoft 365 Admin Tools Team  
**最終更新**: 2025年1月18日  
**バージョン**: 1.0.0