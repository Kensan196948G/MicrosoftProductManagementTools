import { Sequelize } from 'sequelize';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs/promises';
import logger from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// データベース設定
const DB_TYPE = process.env.DB_TYPE || 'sqlite';
const DB_PATH = process.env.DB_PATH || join(__dirname, '../../data/m365management.db');
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_NAME = process.env.DB_NAME || 'm365management';
const DB_USER = process.env.DB_USER || 'postgres';
const DB_PASSWORD = process.env.DB_PASSWORD || '';

let sequelize;

// データベース接続の初期化
export const initializeDatabase = async () => {
  try {
    if (DB_TYPE === 'sqlite') {
      // SQLiteの場合、データディレクトリを作成
      const dataDir = dirname(DB_PATH);
      try {
        await fs.mkdir(dataDir, { recursive: true });
      } catch (error) {
        // ディレクトリが既に存在する場合は無視
      }

      sequelize = new Sequelize({
        dialect: 'sqlite',
        storage: DB_PATH,
        logging: (msg) => logger.debug(msg),
        pool: {
          max: 5,
          min: 0,
          acquire: 30000,
          idle: 10000
        },
        define: {
          freezeTableName: true,
          timestamps: true,
          underscored: true
        }
      });

      logger.info(`SQLite database initialized at: ${DB_PATH}`);
    } else if (DB_TYPE === 'postgres') {
      sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
        host: DB_HOST,
        port: DB_PORT,
        dialect: 'postgres',
        logging: (msg) => logger.debug(msg),
        pool: {
          max: 20,
          min: 0,
          acquire: 30000,
          idle: 10000
        },
        define: {
          freezeTableName: true,
          timestamps: true,
          underscored: true
        }
      });

      logger.info(`PostgreSQL database initialized at: ${DB_HOST}:${DB_PORT}/${DB_NAME}`);
    } else {
      throw new Error(`Unsupported database type: ${DB_TYPE}`);
    }

    // 接続テスト
    await sequelize.authenticate();
    logger.info('Database connection has been established successfully.');

    // テーブル作成
    await createTables();

    return sequelize;
  } catch (error) {
    logger.error('Unable to connect to the database:', error);
    throw error;
  }
};

// テーブル作成
const createTables = async () => {
  try {
    // ユーザーテーブル
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR(255) UNIQUE NOT NULL,
        display_name VARCHAR(255),
        user_principal_name VARCHAR(255) UNIQUE,
        mail VARCHAR(255),
        job_title VARCHAR(255),
        department VARCHAR(255),
        office_location VARCHAR(255),
        mobile_phone VARCHAR(50),
        business_phones TEXT,
        account_enabled BOOLEAN DEFAULT true,
        created_date_time DATETIME,
        last_sign_in_date_time DATETIME,
        mfa_enabled BOOLEAN DEFAULT false,
        tenant_id VARCHAR(255),
        sync_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // ライセンステーブル
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS licenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku_id VARCHAR(255) NOT NULL,
        sku_part_number VARCHAR(255),
        display_name VARCHAR(255),
        consumed_units INTEGER DEFAULT 0,
        enabled_units INTEGER DEFAULT 0,
        suspended_units INTEGER DEFAULT 0,
        warning_units INTEGER DEFAULT 0,
        tenant_id VARCHAR(255),
        sync_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // ユーザーライセンス関連テーブル
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS user_licenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR(255) NOT NULL,
        sku_id VARCHAR(255) NOT NULL,
        assigned_date_time DATETIME,
        status VARCHAR(50) DEFAULT 'active',
        tenant_id VARCHAR(255),
        sync_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      )
    `);

    // レポートテーブル
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id VARCHAR(255) UNIQUE NOT NULL,
        type VARCHAR(100) NOT NULL,
        format VARCHAR(20) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        progress INTEGER DEFAULT 0,
        file_path VARCHAR(500),
        file_size INTEGER,
        parameters TEXT,
        error_message TEXT,
        tenant_id VARCHAR(255),
        requested_by VARCHAR(255),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        started_at DATETIME,
        completed_at DATETIME
      )
    `);

    // サインインログテーブル
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS signin_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_id VARCHAR(255) UNIQUE NOT NULL,
        user_id VARCHAR(255),
        user_principal_name VARCHAR(255),
        created_date_time DATETIME,
        app_display_name VARCHAR(255),
        app_id VARCHAR(255),
        ip_address VARCHAR(45),
        location_city VARCHAR(255),
        location_state VARCHAR(255),
        location_country VARCHAR(255),
        sign_in_status VARCHAR(50),
        error_code INTEGER,
        failure_reason TEXT,
        device_id VARCHAR(255),
        device_display_name VARCHAR(255),
        device_os VARCHAR(255),
        device_browser VARCHAR(255),
        conditional_access_status VARCHAR(50),
        tenant_id VARCHAR(255),
        sync_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 使用状況統計テーブル
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS usage_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR(255),
        service_name VARCHAR(100),
        period VARCHAR(10),
        report_date DATE,
        last_activity_date DATE,
        usage_data TEXT,
        tenant_id VARCHAR(255),
        sync_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 認証セッションテーブル
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS auth_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id VARCHAR(255) UNIQUE NOT NULL,
        user_id VARCHAR(255),
        token_hash VARCHAR(255),
        refresh_token_hash VARCHAR(255),
        expires_at DATETIME,
        tenant_id VARCHAR(255),
        ip_address VARCHAR(45),
        user_agent TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_accessed_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // インデックス作成
    await createIndexes();

    logger.info('Database tables created successfully');
  } catch (error) {
    logger.error('Error creating database tables:', error);
    throw error;
  }
};

// インデックス作成
const createIndexes = async () => {
  try {
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_users_upn ON users(user_principal_name)',
      'CREATE INDEX IF NOT EXISTS idx_users_department ON users(department)',
      'CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id)',
      'CREATE INDEX IF NOT EXISTS idx_licenses_sku_id ON licenses(sku_id)',
      'CREATE INDEX IF NOT EXISTS idx_licenses_tenant_id ON licenses(tenant_id)',
      'CREATE INDEX IF NOT EXISTS idx_user_licenses_user_id ON user_licenses(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_user_licenses_sku_id ON user_licenses(sku_id)',
      'CREATE INDEX IF NOT EXISTS idx_reports_type ON reports(type)',
      'CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status)',
      'CREATE INDEX IF NOT EXISTS idx_reports_tenant_id ON reports(tenant_id)',
      'CREATE INDEX IF NOT EXISTS idx_signin_logs_user_id ON signin_logs(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_signin_logs_created_date ON signin_logs(created_date_time)',
      'CREATE INDEX IF NOT EXISTS idx_signin_logs_tenant_id ON signin_logs(tenant_id)',
      'CREATE INDEX IF NOT EXISTS idx_usage_stats_user_id ON usage_stats(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_usage_stats_service ON usage_stats(service_name)',
      'CREATE INDEX IF NOT EXISTS idx_usage_stats_period ON usage_stats(period)',
      'CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id ON auth_sessions(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_auth_sessions_expires_at ON auth_sessions(expires_at)'
    ];

    for (const indexQuery of indexes) {
      await sequelize.query(indexQuery);
    }

    logger.info('Database indexes created successfully');
  } catch (error) {
    logger.error('Error creating database indexes:', error);
    throw error;
  }
};

// データベース接続取得
export const getDatabase = () => {
  if (!sequelize) {
    throw new Error('Database not initialized. Call initializeDatabase() first.');
  }
  return sequelize;
};

// データベース接続終了
export const closeDatabase = async () => {
  if (sequelize) {
    await sequelize.close();
    logger.info('Database connection closed');
  }
};

// ヘルスチェック
export const checkDatabaseHealth = async () => {
  try {
    if (!sequelize) {
      return { healthy: false, error: 'Database not initialized' };
    }

    await sequelize.authenticate();
    return { healthy: true };
  } catch (error) {
    return { healthy: false, error: error.message };
  }
};

export default {
  initializeDatabase,
  getDatabase,
  closeDatabase,
  checkDatabaseHealth
};