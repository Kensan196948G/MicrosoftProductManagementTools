import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import swaggerUi from 'swagger-ui-express';
import swaggerJsdoc from 'swagger-jsdoc';

// ルーターのインポート
import authRouter from './routes/auth.js';
import usersRouter from './routes/users.js';
import reportsRouter from './routes/reports.js';
import licensesRouter from './routes/licenses.js';
import exchangeRouter from './routes/exchange.js';
import teamsRouter from './routes/teams.js';
import onedriveRouter from './routes/onedrive.js';
import schedulerRouter from './routes/scheduler.js';

// ミドルウェアのインポート
import { errorHandler } from './middleware/errorHandler.js';
import { rateLimiter } from './middleware/rateLimiter.js';
import { requestLogger } from './middleware/requestLogger.js';

// ユーティリティのインポート
import logger from './utils/logger.js';
import { initializeDatabase } from './config/database.js';

// ESモジュール対応
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// 環境変数の読み込み
dotenv.config();

// Expressアプリケーションの初期化
const app = express();
const PORT = process.env.PORT || 3000;
const API_PREFIX = process.env.API_PREFIX || '/api/v1';

// Swagger設定
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Microsoft 365 Management Tools API',
      version: '1.0.0',
      description: 'エンタープライズ向けMicrosoft 365統合管理API',
      contact: {
        name: 'API Support',
        email: 'support@m365tools.local'
      }
    },
    servers: [
      {
        url: `http://localhost:${PORT}${API_PREFIX}`,
        description: 'Development server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    }
  },
  apis: ['./src/routes/*.js', './src/models/*.js']
};

const swaggerSpecs = swaggerJsdoc(swaggerOptions);

// 基本ミドルウェアの設定
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}));

app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3001',
  credentials: true
}));

app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

// カスタムミドルウェア
app.use(requestLogger);
app.use(rateLimiter);

// ヘルスチェックエンドポイント
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV
  });
});

// APIドキュメント
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

// APIルーター
app.use(`${API_PREFIX}/auth`, authRouter);
app.use(`${API_PREFIX}/users`, usersRouter);
app.use(`${API_PREFIX}/reports`, reportsRouter);
app.use(`${API_PREFIX}/licenses`, licensesRouter);
app.use(`${API_PREFIX}/exchange`, exchangeRouter);
app.use(`${API_PREFIX}/teams`, teamsRouter);
app.use(`${API_PREFIX}/onedrive`, onedriveRouter);
app.use(`${API_PREFIX}/scheduler`, schedulerRouter);

// 404ハンドラー
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested resource was not found',
    path: req.originalUrl
  });
});

// エラーハンドラー
app.use(errorHandler);

// データベース初期化とサーバー起動
async function startServer() {
  try {
    // データベース接続
    await initializeDatabase();
    logger.info('Database initialized successfully');

    // サーバー起動
    app.listen(PORT, () => {
      logger.info(`Server is running on port ${PORT}`);
      logger.info(`API documentation available at http://localhost:${PORT}/api-docs`);
      logger.info(`Environment: ${process.env.NODE_ENV}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// プロセス終了時のクリーンアップ
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  process.exit(0);
});

// 未処理の例外のハンドリング
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// サーバー起動
startServer();

export default app;