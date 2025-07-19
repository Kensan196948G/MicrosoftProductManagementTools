#!/bin/bash
set -e

# Microsoft 365 Management Tools - Production Docker Entrypoint
# Handles initialization, health checks, and graceful startup

echo "🚀 Starting Microsoft 365 Management Tools..."

# Environment validation
required_vars=(
    "MICROSOFT_TENANT_ID"
    "MICROSOFT_CLIENT_ID" 
    "MICROSOFT_CLIENT_SECRET"
    "SECRET_KEY"
    "JWT_SECRET_KEY"
    "DATABASE_URL"
    "REDIS_URL"
)

echo "🔧 Validating environment variables..."
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: Required environment variable $var is not set"
        exit 1
    fi
done
echo "✅ Environment validation completed"

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if python -c "
import psycopg2
import os
import sys
try:
    conn = psycopg2.connect(os.environ['DATABASE_URL'])
    conn.close()
    print('Database connection successful')
    sys.exit(0)
except Exception as e:
    print(f'Database connection failed: {e}')
    sys.exit(1)
" 2>/dev/null; then
        echo "✅ Database is ready"
        break
    fi
    
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts - Database not ready, waiting..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Database failed to become ready after $max_attempts attempts"
    exit 1
fi

# Wait for Redis to be ready
echo "⏳ Waiting for Redis connection..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if python -c "
import redis
import os
import sys
try:
    r = redis.from_url(os.environ['REDIS_URL'])
    r.ping()
    print('Redis connection successful')
    sys.exit(0)
except Exception as e:
    print(f'Redis connection failed: {e}')
    sys.exit(1)
" 2>/dev/null; then
        echo "✅ Redis is ready"
        break
    fi
    
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts - Redis not ready, waiting..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Redis failed to become ready after $max_attempts attempts"
    exit 1
fi

# Run database migrations if needed
if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
    echo "🔄 Running database migrations..."
    python -c "
import asyncio
from src.core.database import init_database

async def main():
    try:
        await init_database()
        print('Database initialization completed')
    except Exception as e:
        print(f'Database initialization failed: {e}')
        raise

asyncio.run(main())
"
    echo "✅ Database migrations completed"
fi

# Create necessary directories
echo "📁 Creating application directories..."
mkdir -p /app/logs /app/data /app/backups /app/Reports /app/TestOutput
echo "✅ Directories created"

# Validate application configuration
echo "🔧 Validating application configuration..."
python -c "
from src.core.config import get_settings
try:
    settings = get_settings()
    print('Configuration validation successful')
except Exception as e:
    print(f'Configuration validation failed: {e}')
    raise
"
echo "✅ Configuration validation completed"

# Set security headers and optimizations
export FORWARDED_ALLOW_IPS='*'
export PROXY_HEADERS_TIMEOUT=60
export GRACEFUL_TIMEOUT=120
export TIMEOUT=120
export KEEPALIVE=2
export MAX_REQUESTS=${MAX_REQUESTS:-1000}
export MAX_REQUESTS_JITTER=${MAX_REQUESTS_JITTER:-50}

# Performance tuning based on container resources
if [ -n "$CPU_LIMIT" ]; then
    export WORKERS=$(python -c "import math; print(max(1, min(int('$CPU_LIMIT'), 8)))")
else
    export WORKERS=${WORKERS:-4}
fi

echo "⚙️  Production settings:"
echo "   Workers: $WORKERS"
echo "   Max requests: $MAX_REQUESTS"
echo "   Max requests jitter: $MAX_REQUESTS_JITTER"
echo "   Timeout: $TIMEOUT"
echo "   Keepalive: $KEEPALIVE"

# Setup graceful shutdown handling
shutdown_handler() {
    echo "🛑 Received shutdown signal, gracefully stopping..."
    
    # Send SIGTERM to all child processes
    jobs -p | xargs -r kill -TERM
    
    # Wait for processes to terminate gracefully
    sleep 5
    
    # Force kill any remaining processes
    jobs -p | xargs -r kill -KILL
    
    echo "👋 Shutdown completed"
    exit 0
}

# Register shutdown handler
trap shutdown_handler SIGTERM SIGINT

# Final startup message
echo "🎉 Initialization completed successfully!"
echo "🚀 Starting Microsoft 365 Management Tools API server..."

# Execute the main command
exec "$@"