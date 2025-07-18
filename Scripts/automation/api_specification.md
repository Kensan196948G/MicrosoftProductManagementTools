# ペイン間連携API仕様書

## 概要

Python移行プロジェクトにおける5ペイン間の連携を実現するAPI仕様書です。各ペインが独立して動作しながら、統合的な進捗管理を実現します。

**設計者**: アーキテクト  
**作成日**: 2025年1月18日  
**バージョン**: 1.0.0

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                    統合ダッシュボード                             │
│                (progress_dashboard.py)                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
    ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐
    │   共有       │   │   レポート   │   │   エスカレ   │
    │ コンテキスト │   │ ストレージ   │   │ ーション    │
    └─────────────┘   └─────────────┘   └─────────────┘
          │               │               │
    ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐
    │  Pane 0   │   │  Pane 1   │   │  Pane 2   │
    │アーキテクト│   │バックエンド│   │フロントエンド│
    └───────────┘   └───────────┘   └───────────┘
          │               │               │
    ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐
    │  Pane 3   │   │  Pane 4   │   │   外部連携  │
    │ テスター   │   │  DevOps   │   │  システム   │
    └───────────┘   └───────────┘   └───────────┘
```

## API エンドポイント仕様

### 1. 進捗収集API (Progress Collection API)

#### 1.1 個別ペイン進捗報告

**エンドポイント**: `POST /api/progress/report`

**リクエスト形式**:
```json
{
  "pane_id": "string",
  "developer_role": "string",
  "timestamp": "ISO8601",
  "metrics": {
    "progress_percentage": "number",
    "coverage_percentage": "number",
    "quality_score": "number",
    "component_counts": {
      "completed": "number",
      "in_progress": "number",
      "pending": "number",
      "total": "number"
    },
    "performance_metrics": {
      "response_time": "number",
      "memory_usage": "number",
      "error_rate": "number"
    }
  },
  "status": "string",
  "alerts": ["string"],
  "next_collection_time": "ISO8601"
}
```

**レスポンス形式**:
```json
{
  "status": "success|error",
  "message": "string",
  "escalation_needed": "boolean",
  "next_actions": ["string"]
}
```

#### 1.2 統合進捗取得

**エンドポイント**: `GET /api/progress/integrated`

**レスポンス形式**:
```json
{
  "timestamp": "ISO8601",
  "overall_metrics": {
    "total_progress": "number",
    "total_coverage": "number",
    "health_status": "string",
    "active_panes": "number"
  },
  "pane_details": {
    "pane_0": { "metrics": "object" },
    "pane_1": { "metrics": "object" },
    "pane_2": { "metrics": "object" },
    "pane_3": { "metrics": "object" },
    "pane_4": { "metrics": "object" }
  },
  "alerts": ["string"],
  "escalations": ["object"]
}
```

### 2. エスカレーションAPI (Escalation API)

#### 2.1 エスカレーション通知

**エンドポイント**: `POST /api/escalation/notify`

**リクエスト形式**:
```json
{
  "escalation_level": "critical|warning|notice",
  "source_pane": "string",
  "reason": "string",
  "metrics": "object",
  "timestamp": "ISO8601",
  "auto_actions_taken": ["string"],
  "manual_action_required": "boolean"
}
```

#### 2.2 エスカレーション履歴取得

**エンドポイント**: `GET /api/escalation/history`

**パラメータ**:
- `start_date`: ISO8601 (optional)
- `end_date`: ISO8601 (optional)
- `level`: critical|warning|notice (optional)

### 3. 共有コンテキストAPI (Shared Context API)

#### 3.1 コンテキスト更新

**エンドポイント**: `POST /api/context/update`

**リクエスト形式**:
```json
{
  "pane_id": "string",
  "message_type": "progress|alert|completion|question",
  "content": "string",
  "timestamp": "ISO8601",
  "priority": "high|medium|low",
  "requires_response": "boolean",
  "target_panes": ["string"]
}
```

#### 3.2 コンテキスト取得

**エンドポイント**: `GET /api/context/latest`

**パラメータ**:
- `pane_id`: string (optional)
- `limit`: number (optional, default: 50)

### 4. 品質ゲートAPI (Quality Gate API)

#### 4.1 品質ゲート状態取得

**エンドポイント**: `GET /api/quality/gates`

**レスポンス形式**:
```json
{
  "overall_status": "pass|fail|warning",
  "gates": {
    "test_coverage": {
      "status": "pass|fail|warning",
      "current_value": "number",
      "threshold": "number",
      "trend": "improving|stable|declining"
    },
    "build_success": {
      "status": "pass|fail|warning",
      "current_value": "number",
      "threshold": "number",
      "consecutive_failures": "number"
    },
    "api_performance": {
      "status": "pass|fail|warning",
      "current_value": "number",
      "threshold": "number",
      "trend": "improving|stable|declining"
    }
  }
}
```

## データ形式仕様

### 1. ペイン識別子

```typescript
type PaneId = "pane_0" | "pane_1" | "pane_2" | "pane_3" | "pane_4";
type DeveloperRole = "architect" | "backend" | "frontend" | "tester" | "devops";
```

### 2. 進捗メトリクス

```typescript
interface ProgressMetrics {
  progress_percentage: number;    // 0-100
  coverage_percentage: number;    // 0-100
  quality_score: number;          // 0-100
  component_counts: {
    completed: number;
    in_progress: number;
    pending: number;
    total: number;
  };
  performance_metrics: {
    response_time: number;        // seconds
    memory_usage: number;         // percentage
    error_rate: number;          // percentage
  };
}
```

### 3. ステータス定義

```typescript
type Status = "operational" | "warning" | "critical" | "offline" | "unknown";
type EscalationLevel = "critical" | "warning" | "notice";
type HealthStatus = "excellent" | "good" | "warning" | "caution" | "critical";
```

## ファイルシステム連携仕様

### 1. レポートファイル命名規則

```
Reports/progress/
├── {pane_id}_status.json           # 最新ステータス
├── {pane_id}_history_YYYYMMDD.json # 日次履歴
├── integrated_YYYYMMDD_HHMMSS.json # 統合レポート
└── escalation_YYYYMMDD.log         # エスカレーションログ
```

### 2. 共有コンテキストファイル

```
tmux_shared_context.md
├── ヘッダー情報
├── 各ペインの進捗報告
├── エスカレーション履歴
├── 決定事項・課題
└── フッター情報
```

## 同期・非同期処理仕様

### 1. 同期処理 (Synchronous)

- **品質ゲートチェック**: 即座に結果を返す必要があるため
- **緊急エスカレーション**: 即座に通知が必要なため
- **統合ダッシュボード表示**: リアルタイム表示のため

### 2. 非同期処理 (Asynchronous)

- **進捗レポート生成**: 重い処理のため
- **メール・外部通知**: 外部システム連携のため
- **履歴データ集計**: 大量データ処理のため

## エラーハンドリング仕様

### 1. API エラーコード

```typescript
enum ApiErrorCode {
  VALIDATION_ERROR = 400,
  AUTHENTICATION_ERROR = 401,
  AUTHORIZATION_ERROR = 403,
  NOT_FOUND = 404,
  ESCALATION_REQUIRED = 409,
  INTERNAL_SERVER_ERROR = 500,
  SERVICE_UNAVAILABLE = 503
}
```

### 2. エラーレスポンス形式

```json
{
  "error": {
    "code": "number",
    "message": "string",
    "details": "object",
    "timestamp": "ISO8601",
    "trace_id": "string"
  }
}
```

### 3. 再試行ロジック

```typescript
interface RetryPolicy {
  max_attempts: number;        // 最大再試行回数
  backoff_strategy: "linear" | "exponential" | "fixed";
  initial_delay: number;       // 初期遅延(秒)
  max_delay: number;          // 最大遅延(秒)
  jitter: boolean;            // ランダム遅延追加
}
```

## セキュリティ仕様

### 1. 認証・認可

- **内部API**: ファイルシステムベースの認証
- **外部連携**: OAuth 2.0 / API Key認証
- **データ暗号化**: AES-256暗号化

### 2. アクセス制御

```typescript
interface AccessControl {
  pane_id: PaneId;
  allowed_operations: ("read" | "write" | "execute")[];
  resource_patterns: string[];
  rate_limit: {
    requests_per_minute: number;
    burst_capacity: number;
  };
}
```

## 監視・ログ仕様

### 1. ログレベル

```typescript
enum LogLevel {
  DEBUG = "debug",
  INFO = "info",
  WARN = "warn",
  ERROR = "error",
  FATAL = "fatal"
}
```

### 2. ログ形式

```json
{
  "timestamp": "ISO8601",
  "level": "LogLevel",
  "pane_id": "string",
  "component": "string",
  "message": "string",
  "metadata": "object",
  "trace_id": "string"
}
```

## 実装ガイドライン

### 1. 各ペインの実装責任

#### Pane 0 (アーキテクト)
- 統合ダッシュボードの実装
- API仕様の維持・更新
- エスカレーション管理

#### Pane 1 (バックエンド開発者)
- 進捗収集APIの実装
- データ処理・集計ロジック
- 外部システム連携

#### Pane 2 (フロントエンド開発者)
- GUI進捗表示コンポーネント
- リアルタイム更新機能
- ユーザーインターフェース

#### Pane 3 (テスター)
- 品質ゲート自動チェック
- テストカバレッジ収集
- 品質メトリクス監視

#### Pane 4 (DevOps)
- CI/CD連携
- 監視・アラート設定
- インフラ管理

### 2. 共通実装ルール

- **エラーハンドリング**: 全てのAPI呼び出しで適切な例外処理
- **ログ出力**: 全ての重要な操作でログ記録
- **設定管理**: 外部設定ファイルで動作パラメータを管理
- **テスト**: 単体テスト・統合テスト実装必須

### 3. 開発・デプロイメント

- **開発環境**: 各ペインのローカル開発環境
- **統合環境**: tmux環境での5ペイン統合テスト
- **本番環境**: 実際のプロジェクト環境での運用

## 付録

### A. 設定ファイル例

```yaml
# api_config.yml
api:
  host: "localhost"
  port: 8080
  timeout: 30
  
progress_collection:
  interval_hours: 4
  retention_days: 30
  
escalation:
  immediate_threshold: 85
  warning_threshold: 90
  
notifications:
  email:
    enabled: true
    smtp_server: "smtp.office365.com"
  teams:
    enabled: true
    webhook_url: "${TEAMS_WEBHOOK_URL}"
```

### B. 実装チェックリスト

- [ ] 各ペインのAPI実装完了
- [ ] 統合ダッシュボード実装完了
- [ ] エスカレーション機能実装完了
- [ ] 品質ゲート実装完了
- [ ] ログ・監視機能実装完了
- [ ] 設定ファイル整備完了
- [ ] テスト実装完了
- [ ] ドキュメント整備完了

---

**次回更新予定**: 2025年1月19日（実装フィードバック反映）