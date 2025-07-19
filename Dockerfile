# Microsoft 365 Management Tools - Phase 2 Enterprise Production Dockerfile
# Python 3.11 Alpine Linux with Azure optimizations
FROM python:3.11-alpine

# Metadata
LABEL maintainer="Microsoft 365 Management Tools Team"
LABEL version="2.0"
LABEL description="Enterprise Microsoft 365 Management Tools - Phase 2 Production"

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONPATH=/app/src \
    AZURE_KEYVAULT_URL="" \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET="" \
    AZURE_CLIENT_CERTIFICATE_PATH="" \
    AZURE_CLIENT_CERTIFICATE_PASSWORD="" \
    LOG_LEVEL=INFO \
    ENABLE_CACHE=true \
    ENABLE_BATCHING=true \
    MAX_WORKERS=4 \
    REQUEST_TIMEOUT=30 \
    HEALTH_CHECK_INTERVAL=30

# Install system dependencies
RUN apk add --no-cache \
    gcc \
    g++ \
    libc-dev \
    linux-headers \
    musl-dev \
    libffi-dev \
    openssl-dev \
    postgresql-dev \
    jpeg-dev \
    zlib-dev \
    curl \
    git \
    tmux \
    dcron \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
COPY src/requirements.txt ./src/

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r src/requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p \
    /app/logs \
    /app/Reports \
    /app/Config \
    /app/data \
    /app/temp \
    /app/reports/progress \
    && chown -R appuser:appgroup /app

# Set permissions
RUN chmod +x /app/docker-entrypoint.sh
RUN chmod +x /app/src/main.py
RUN chmod +x /app/Scripts/automation/devops_monitor.sh

# Create health check script
RUN echo '#!/usr/bin/env python3\n\
import sys\n\
sys.path.insert(0, "/app/src")\n\
import requests\n\
import os\n\
\n\
def health_check():\n\
    try:\n\
        # Check if main application is responsive\n\
        response = requests.get("http://localhost:8000/health", timeout=5)\n\
        if response.status_code == 200:\n\
            return 0\n\
        else:\n\
            return 1\n\
    except Exception as e:\n\
        print(f"Health check failed: {e}")\n\
        return 1\n\
\n\
if __name__ == "__main__":\n\
    exit(health_check())\n\
' > /app/health_check.py && chmod +x /app/health_check.py

# Cron configuration for DevOps monitoring
RUN echo "0 */4 * * * cd /app && ./Scripts/automation/devops_monitor.sh >> logs/devops_monitor.log 2>&1" > /etc/cron.d/devops-monitor && \
    chmod 0644 /etc/cron.d/devops-monitor

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python /app/health_check.py || exit 1

# Set entrypoint
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# Default command
CMD ["python", "-m", "src.main"]