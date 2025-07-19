# Microsoft 365 Management Tools - Frontend Dockerfile
# PowerShell GUI互換 React アプリケーションのDocker設定

# マルチステージビルド: ビルドステージ
FROM node:18-alpine AS builder

# 作業ディレクトリの設定
WORKDIR /app

# package.jsonとpackage-lock.jsonをコピー
COPY package*.json ./

# 依存関係のインストール
RUN npm ci --only=production --silent

# ソースコードをコピー
COPY . .

# 環境変数設定
ENV NODE_ENV=production
ENV REACT_APP_API_URL=http://localhost:8000

# ビルドの実行
RUN npm run build

# プロダクションステージ
FROM nginx:alpine AS production

# 作業ディレクトリの設定
WORKDIR /usr/share/nginx/html

# ビルドされたファイルをコピー
COPY --from=builder /app/dist .

# Nginx設定をコピー
COPY nginx.conf /etc/nginx/nginx.conf

# ポート80を公開
EXPOSE 80

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:80 || exit 1

# Nginxの起動
CMD ["nginx", "-g", "daemon off;"]

# 開発用ステージ
FROM node:18-alpine AS development

# 作業ディレクトリの設定
WORKDIR /app

# package.jsonとpackage-lock.jsonをコピー
COPY package*.json ./

# 依存関係のインストール（開発用依存関係も含む）
RUN npm ci --silent

# ソースコードをコピー
COPY . .

# 環境変数設定
ENV NODE_ENV=development
ENV REACT_APP_API_URL=http://localhost:8000

# ポート3000を公開
EXPOSE 3000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000 || exit 1

# 開発サーバーの起動
CMD ["npm", "run", "dev"]