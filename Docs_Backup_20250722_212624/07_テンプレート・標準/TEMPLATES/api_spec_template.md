# [API名] - API仕様書

**品質レベル**: ⭐⭐⭐⭐⭐ エンタープライズ級  
**対象者**: 開発者向け  
**最終更新**: [YYYY-MM-DD]  
**更新者**: [役職/担当者名]  
**レビュー状況**: [未レビュー/レビュー中/承認済み]  

---

## 📋 API概要

**API名**: [API名称]  
**バージョン**: [v1.0]  
**ベースURL**: `https://api.example.com/v1`  
**認証方式**: [OAuth 2.0 / JWT / API Key]  
**データ形式**: JSON  
**文字エンコーディング**: UTF-8  

### 目的
[APIの目的と用途を2-3行で記述]

---

## 🔐 認証

### 認証方式
```http
Authorization: Bearer {access_token}
```

### アクセストークン取得
```http
POST /auth/token
Content-Type: application/json

{
  "client_id": "your_client_id",
  "client_secret": "your_client_secret",
  "grant_type": "client_credentials"
}
```

**レスポンス**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

---

## 📚 APIエンドポイント

### [エンドポイントグループ1]

#### GET /[endpoint]
[エンドポイントの説明]

**リクエスト**:
```http
GET /[endpoint]?param1=value1&param2=value2
Authorization: Bearer {access_token}
```

**パラメータ**:
| パラメータ | 型 | 必須 | 説明 | 例 |
|-----------|---|------|------|-----|
| `param1` | string | ✅ | [説明] | `example` |
| `param2` | integer | ❌ | [説明] | `10` |

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "id": "12345",
    "name": "Example",
    "created_at": "2025-07-22T10:00:00Z"
  },
  "pagination": {
    "total": 100,
    "page": 1,
    "per_page": 10
  }
}
```

**HTTPステータスコード**:
- `200 OK`: 成功
- `400 Bad Request`: リクエストエラー
- `401 Unauthorized`: 認証エラー
- `404 Not Found`: リソースが存在しない
- `500 Internal Server Error`: サーバーエラー

---

#### POST /[endpoint]
[エンドポイントの説明]

**リクエスト**:
```http
POST /[endpoint]
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "name": "New Item",
  "description": "Description of new item",
  "active": true
}
```

**リクエストボディ**:
| フィールド | 型 | 必須 | 説明 | 制約 |
|-----------|---|------|------|------|
| `name` | string | ✅ | 名前 | 最大100文字 |
| `description` | string | ❌ | 説明 | 最大500文字 |
| `active` | boolean | ❌ | 有効フラグ | デフォルト: true |

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "id": "67890",
    "name": "New Item",
    "description": "Description of new item",
    "active": true,
    "created_at": "2025-07-22T10:30:00Z"
  }
}
```

---

### [エンドポイントグループ2]

[他のエンドポイントも同様に記述]

---

## 🔧 データモデル

### [モデル名1]
```json
{
  "id": "string",
  "name": "string",
  "email": "string",
  "active": "boolean",
  "created_at": "string (ISO 8601)",
  "updated_at": "string (ISO 8601)"
}
```

**フィールド詳細**:
| フィールド | 型 | 必須 | 説明 | 制約 |
|-----------|---|------|------|------|
| `id` | string | ✅ | 一意識別子 | UUID v4 |
| `name` | string | ✅ | 名前 | 1-100文字 |
| `email` | string | ✅ | メールアドレス | RFC 5322準拠 |
| `active` | boolean | ✅ | 有効フラグ | - |
| `created_at` | string | ✅ | 作成日時 | ISO 8601形式 |
| `updated_at` | string | ✅ | 更新日時 | ISO 8601形式 |

---

## ⚠️ エラーレスポンス

### エラー形式
```json
{
  "status": "error",
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": {
      "field": "Additional error details"
    }
  },
  "timestamp": "2025-07-22T10:00:00Z"
}
```

### エラーコード一覧
| コード | HTTPステータス | メッセージ | 説明 |
|--------|---------------|------------|------|
| `INVALID_REQUEST` | 400 | Invalid request format | リクエスト形式が不正 |
| `UNAUTHORIZED` | 401 | Authentication required | 認証が必要 |
| `FORBIDDEN` | 403 | Access denied | アクセス権限なし |
| `NOT_FOUND` | 404 | Resource not found | リソースが存在しない |
| `RATE_LIMIT_EXCEEDED` | 429 | Rate limit exceeded | レート制限を超過 |
| `INTERNAL_ERROR` | 500 | Internal server error | サーバー内部エラー |

---

## 🚀 使用例

### JavaScript (Fetch API)
```javascript
// GETリクエスト例
async function fetchData() {
  const response = await fetch('https://api.example.com/v1/items', {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    }
  });
  
  const data = await response.json();
  return data;
}

// POSTリクエスト例
async function createItem(itemData) {
  const response = await fetch('https://api.example.com/v1/items', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(itemData)
  });
  
  return await response.json();
}
```

### Python (requests)
```python
import requests

# GETリクエスト例
def fetch_data(access_token):
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    response = requests.get('https://api.example.com/v1/items', headers=headers)
    return response.json()

# POSTリクエスト例
def create_item(access_token, item_data):
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    response = requests.post('https://api.example.com/v1/items', 
                           json=item_data, headers=headers)
    return response.json()
```

### PowerShell
```powershell
# GETリクエスト例
function Get-ApiData {
    param($AccessToken)
    
    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
    }
    
    $response = Invoke-RestMethod -Uri 'https://api.example.com/v1/items' -Headers $headers -Method Get
    return $response
}

# POSTリクエスト例
function New-ApiItem {
    param($AccessToken, $ItemData)
    
    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
    }
    
    $body = $ItemData | ConvertTo-Json
    $response = Invoke-RestMethod -Uri 'https://api.example.com/v1/items' -Headers $headers -Method Post -Body $body
    return $response
}
```

---

## 📊 レート制限

### 制限値
- **基本プラン**: 100 requests/hour
- **プロプラン**: 1,000 requests/hour
- **エンタープライズプラン**: 10,000 requests/hour

### ヘッダー情報
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1627849200
```

### レート制限エラー
```json
{
  "status": "error",
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Please try again later.",
    "details": {
      "limit": 1000,
      "remaining": 0,
      "reset_at": "2025-07-22T11:00:00Z"
    }
  }
}
```

---

## 🔄 バージョニング

### バージョン戦略
- **URLパス**: `/v1/`, `/v2/` etc.
- **後方互換性**: 最低2バージョン保持
- **廃止予告**: 6ヶ月前に通知

### バージョン履歴
| バージョン | リリース日 | 主要変更 | 廃止予定 |
|-----------|-----------|----------|----------|
| v1.0 | 2025-01-01 | 初版リリース | - |
| v1.1 | 2025-06-01 | [変更内容] | - |

---

## 🧪 テスト・デバッグ

### Postmanコレクション
[Postmanコレクションのリンクまたはファイル]

### cURLコマンド集
```bash
# 認証
curl -X POST https://api.example.com/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"client_id":"your_id","client_secret":"your_secret","grant_type":"client_credentials"}'

# データ取得
curl -X GET https://api.example.com/v1/items \
  -H "Authorization: Bearer {access_token}"

# データ作成
curl -X POST https://api.example.com/v1/items \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{"name":"New Item","active":true}'
```

---

## 📞 サポート

### 技術サポート
- **Eメール**: api-support@company.com
- **ドキュメント**: [リンク]
- **Status Page**: [リンク]

### 変更通知
- **更新通知**: [購読リンク]
- **メンテナンス情報**: [購読リンク]

---

## 📝 文書情報

**作成日**: [YYYY-MM-DD]  
**作成者**: [役職/担当者名]  
**最終更新**: [YYYY-MM-DD]  
**更新者**: [役職/担当者名]  
**品質レベル**: ⭐⭐⭐⭐⭐ エンタープライズ級  
**レビュー**: [承認者名] - [承認日]  
**次回レビュー予定**: [YYYY-MM-DD]  

### 変更履歴
| 日付 | バージョン | 変更内容 | 変更者 |
|------|------------|----------|--------|
| YYYY-MM-DD | v1.0 | 初版作成 | [担当者] |

---

**Documentation Architecture Engineer**  
**Microsoft 365管理ツール - API仕様書テンプレート**  
**品質基準**: ⭐⭐⭐⭐⭐ エンタープライズ級