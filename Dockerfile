FROM python:3.11-slim

WORKDIR /app

# システムパッケージインストール
RUN apt-get update && apt-get install -y \
    curl \
    git \
    tmux \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Python依存関係インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコピー
COPY src/ ./src/
COPY Config/ ./Config/
COPY scripts/ ./scripts/
COPY tests/ ./tests/

# ディレクトリ作成
RUN mkdir -p /app/reports/progress /app/logs

# スクリプトを実行可能にする
RUN chmod +x scripts/automation/devops_monitor.sh

# cron設定
RUN echo "0 */4 * * * cd /app && ./scripts/automation/devops_monitor.sh >> logs/devops_monitor.log 2>&1" > /etc/cron.d/devops-monitor
RUN chmod 0644 /etc/cron.d/devops-monitor

# エントリーポイント
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["python", "-m", "src.main"]