// Database configuration placeholder
// This project currently uses PowerShell scripts for data storage
// Future implementation could include PostgreSQL or MongoDB

const config = {
  development: {
    // In-memory cache for development
    cache: {
      ttl: 3600, // 1 hour
      maxSize: 1000
    },
    // File-based storage paths
    storage: {
      reports: process.env.REPORT_OUTPUT_PATH || '../Reports',
      logs: process.env.LOG_DIR || './logs',
      temp: process.env.TEMP_DIR || './temp'
    }
  },
  
  production: {
    // Production database configuration
    database: {
      url: process.env.DATABASE_URL,
      ssl: process.env.NODE_ENV === 'production',
      pool: {
        min: 2,
        max: 10,
        acquireTimeoutMillis: 30000,
        idleTimeoutMillis: 30000
      }
    },
    cache: {
      ttl: 7200, // 2 hours
      maxSize: 5000
    },
    storage: {
      reports: process.env.REPORT_OUTPUT_PATH || '../Reports',
      logs: process.env.LOG_DIR || './logs',
      temp: process.env.TEMP_DIR || './temp'
    }
  }
};

module.exports = config[process.env.NODE_ENV || 'development'];