#!/bin/bash
set -e

# Microsoft 365 Management Tools - Production Docker Entrypoint
# Enterprise-grade initialization script with health checks

echo "🚀 Microsoft 365 Management Tools v2.0 起動中..."
echo "Environment: ${ENVIRONMENT:-production}"
echo "Log Level: ${LOG_LEVEL:-info}"

# Environment validation
validate_environment() {
    echo "📋 環境変数検証中..."
    
    required_vars=(
        "MICROSOFT_TENANT_ID"
        "MICROSOFT_CLIENT_ID"
        "DATABASE_URL"
        "REDIS_URL"
        "SECRET_KEY"
    )
    
    missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "❌ 必須環境変数が設定されていません:"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi
    
    echo "✅ 環境変数検証完了"
}

# Database connection check
check_database() {
    echo "🔍 データベース接続確認中..."
    
    python3 -c "
import os
import sys
import asyncio
import asyncpg
from urllib.parse import urlparse

async def check_db():
    try:
        db_url = os.environ.get('DATABASE_URL')
        if not db_url:
            print('❌ DATABASE_URL not set')
            sys.exit(1)
            
        # Parse connection string
        parsed = urlparse(db_url)
        conn = await asyncpg.connect(
            host=parsed.hostname,
            port=parsed.port or 5432,
            user=parsed.username,
            password=parsed.password,
            database=parsed.path[1:] if parsed.path else 'postgres'
        )
        
        # Simple health check
        result = await conn.fetchval('SELECT 1')
        await conn.close()
        
        if result == 1:
            print('✅ データベース接続成功')
        else:
            print('❌ データベース接続異常')
            sys.exit(1)
            
    except Exception as e:
        print(f'❌ データベース接続エラー: {e}')
        sys.exit(1)

asyncio.run(check_db())
" || echo "⚠️ データベース接続チェックをスキップ"
}

# Redis connection check
check_redis() {
    echo "🔍 Redis接続確認中..."
    
    python3 -c "
import os
import sys
import redis
from urllib.parse import urlparse

try:
    redis_url = os.environ.get('REDIS_URL')
    if not redis_url:
        print('❌ REDIS_URL not set')
        sys.exit(1)
        
    r = redis.from_url(redis_url)
    r.ping()
    print('✅ Redis接続成功')
    
except Exception as e:
    print(f'❌ Redis接続エラー: {e}')
    sys.exit(1)
" || echo "⚠️ Redis接続チェックをスキップ"
}

# Microsoft Graph API authentication check
check_graph_api() {
    echo "🔍 Microsoft Graph API認証確認中..."
    
    python3 -c "
import os
import sys
from msal import ConfidentialClientApplication

try:
    tenant_id = os.environ.get('MICROSOFT_TENANT_ID')
    client_id = os.environ.get('MICROSOFT_CLIENT_ID')
    client_secret = os.environ.get('MICROSOFT_CLIENT_SECRET')
    
    if not all([tenant_id, client_id, client_secret]):
        print('❌ Microsoft認証情報が不完全')
        sys.exit(1)
    
    authority = f'https://login.microsoftonline.com/{tenant_id}'
    app = ConfidentialClientApplication(
        client_id=client_id,
        client_credential=client_secret,
        authority=authority
    )
    
    # Test token acquisition
    result = app.acquire_token_for_client(scopes=['https://graph.microsoft.com/.default'])
    
    if 'access_token' in result:
        print('✅ Microsoft Graph API認証成功')
    else:
        print(f'❌ Microsoft Graph API認証失敗: {result.get(\"error_description\", \"Unknown error\")}')
        sys.exit(1)
        
except Exception as e:
    print(f'❌ Microsoft Graph API認証エラー: {e}')
    sys.exit(1)
" || echo "⚠️ Microsoft Graph API認証チェックをスキップ"
}

# Application directories setup
setup_directories() {
    echo "📁 アプリケーションディレクトリ設定中..."
    
    directories=(
        "/app/logs"
        "/app/Reports"
        "/app/Reports/Daily"
        "/app/Reports/Weekly"
        "/app/Reports/Monthly"
        "/app/Reports/Yearly"
        "/app/Reports/Analysis"
        "/app/Reports/EntraID"
        "/app/Reports/Exchange"
        "/app/Reports/Teams"
        "/app/Reports/OneDrive"
        "/app/backups"
        "/app/temp"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    echo "✅ ディレクトリ設定完了"
}

# Health check endpoint setup
setup_health_checks() {
    echo "🏥 ヘルスチェック設定中..."
    
    # Create health check script
    cat > /app/health_check.py << 'EOF'
#!/usr/bin/env python3
"""
Health check script for Microsoft 365 Management Tools
"""
import os
import sys
import json
import asyncio
from datetime import datetime

async def check_all():
    health_status = {
        "timestamp": datetime.utcnow().isoformat(),
        "status": "healthy",
        "checks": {},
        "version": "2.0",
        "environment": os.environ.get("ENVIRONMENT", "production")
    }
    
    # Basic application check
    try:
        import src.main
        health_status["checks"]["application"] = "healthy"
    except Exception as e:
        health_status["checks"]["application"] = f"unhealthy: {str(e)}"
        health_status["status"] = "unhealthy"
    
    # Database check (optional)
    try:
        db_url = os.environ.get('DATABASE_URL')
        if db_url:
            import asyncpg
            conn = await asyncpg.connect(db_url)
            await conn.fetchval('SELECT 1')
            await conn.close()
            health_status["checks"]["database"] = "healthy"
        else:
            health_status["checks"]["database"] = "skipped"
    except Exception as e:
        health_status["checks"]["database"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    # Redis check (optional)
    try:
        redis_url = os.environ.get('REDIS_URL')
        if redis_url:
            import redis
            r = redis.from_url(redis_url)
            r.ping()
            health_status["checks"]["redis"] = "healthy"
        else:
            health_status["checks"]["redis"] = "skipped"
    except Exception as e:
        health_status["checks"]["redis"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    # Microsoft Graph API check (optional)
    try:
        tenant_id = os.environ.get('MICROSOFT_TENANT_ID')
        client_id = os.environ.get('MICROSOFT_CLIENT_ID')
        client_secret = os.environ.get('MICROSOFT_CLIENT_SECRET')
        
        if all([tenant_id, client_id, client_secret]):
            from msal import ConfidentialClientApplication
            
            authority = f'https://login.microsoftonline.com/{tenant_id}'
            app = ConfidentialClientApplication(
                client_id=client_id,
                client_credential=client_secret,
                authority=authority
            )
            
            result = app.acquire_token_for_client(scopes=['https://graph.microsoft.com/.default'])
            
            if 'access_token' in result:
                health_status["checks"]["microsoft_graph"] = "healthy"
            else:
                health_status["checks"]["microsoft_graph"] = f"unhealthy: {result.get('error_description', 'Unknown error')}"
                health_status["status"] = "degraded"
        else:
            health_status["checks"]["microsoft_graph"] = "skipped"
    except Exception as e:
        health_status["checks"]["microsoft_graph"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    return health_status

if __name__ == "__main__":
    result = asyncio.run(check_all())
    print(json.dumps(result, indent=2))
    
    if result["status"] == "unhealthy":
        sys.exit(1)
EOF
    
    chmod +x /app/health_check.py
    echo "✅ ヘルスチェック設定完了"
}

# Signal handlers for graceful shutdown
graceful_shutdown() {
    echo "🛑 Graceful shutdown開始..."
    
    # Kill background processes
    pkill -TERM -P $$ 2>/dev/null || true
    
    # Wait for processes to exit
    sleep 5
    
    echo "✅ Graceful shutdown完了"
    exit 0
}

trap graceful_shutdown SIGTERM SIGINT

# Main execution
main() {
    echo "🔧 本番環境初期化開始..."
    
    # Run all checks and setups
    setup_directories
    setup_health_checks
    
    # Optional infrastructure checks (skip if not configured)
    check_database || true
    check_redis || true
    check_graph_api || true
    
    echo "✅ 初期化完了。アプリケーション起動中..."
    
    # Start the application based on mode
    case "${APP_MODE:-api}" in
        "api")
            echo "🚀 FastAPI サーバー起動中 (ポート: ${PORT:-8000})"
            exec python3 -m uvicorn src.main_fastapi:app \
                --host 0.0.0.0 \
                --port "${PORT:-8000}" \
                --workers "${WORKERS:-4}" \
                --access-log \
                --log-level "${LOG_LEVEL:-info}"
            ;;
        "worker")
            echo "🔨 バックグラウンドワーカー起動中"
            exec python3 -m src.worker
            ;;
        "scheduler")
            echo "⏰ スケジューラー起動中"
            exec python3 -m src.scheduler
            ;;
        "gui")
            echo "🖥️ GUI アプリケーション起動中"
            exec python3 -m src.main
            ;;
        *)
            echo "❌ 不明なAPP_MODE: ${APP_MODE}"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"