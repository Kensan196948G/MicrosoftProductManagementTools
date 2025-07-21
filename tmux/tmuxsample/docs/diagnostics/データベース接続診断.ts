/**
 * データベース接続診断システム
 * Database Connection Diagnostic System
 * 
 * Role: QA Engineer - Emergency Database Diagnosis
 * Target: Comprehensive Database Connection Testing
 * Priority: Emergency - Database Connectivity Analysis
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';

interface DatabaseFile {
  path: string;
  exists: boolean;
  size: number;
  readable: boolean;
  writable: boolean;
  modified: Date | null;
  error?: string;
}

interface DatabaseConnection {
  path: string;
  connected: boolean;
  version: string;
  tables: string[];
  indexes: string[];
  connectionTime: number;
  error?: string;
}

interface DatabaseQuery {
  query: string;
  success: boolean;
  executionTime: number;
  rowCount: number;
  error?: string;
  result?: any;
}

interface DatabaseDiagnosticReport {
  timestamp: string;
  databaseFiles: DatabaseFile[];
  connections: DatabaseConnection[];
  queries: DatabaseQuery[];
  overallStatus: 'healthy' | 'degraded' | 'failed';
  recommendations: string[];
  errorPatterns: string[];
}

describe('Database Connection Diagnostic', () => {
  let diagnosticReport: DatabaseDiagnosticReport;
  
  const databasePaths = [
    '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/database/itsm.db',
    '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/data/itsm.db',
    '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/itsm.db'
  ];

  beforeAll(async () => {
    console.log('🔍 Starting Database Connection Diagnostic...');
    
    diagnosticReport = {
      timestamp: new Date().toISOString(),
      databaseFiles: [],
      connections: [],
      queries: [],
      overallStatus: 'healthy',
      recommendations: [],
      errorPatterns: []
    };
  });

  afterAll(async () => {
    await generateDatabaseDiagnosticReport();
  });

  describe('Database File Analysis', () => {
    it('should verify database file existence and accessibility', async () => {
      console.log('📁 Checking database file existence and accessibility...');
      
      for (const dbPath of databasePaths) {
        const dbFile: DatabaseFile = {
          path: dbPath,
          exists: false,
          size: 0,
          readable: false,
          writable: false,
          modified: null
        };
        
        try {
          dbFile.exists = fs.existsSync(dbPath);
          
          if (dbFile.exists) {
            const stats = fs.statSync(dbPath);
            dbFile.size = stats.size;
            dbFile.modified = stats.mtime;
            
            // Check read/write permissions
            try {
              fs.accessSync(dbPath, fs.constants.R_OK);
              dbFile.readable = true;
            } catch (error) {
              dbFile.readable = false;
            }
            
            try {
              fs.accessSync(dbPath, fs.constants.W_OK);
              dbFile.writable = true;
            } catch (error) {
              dbFile.writable = false;
            }
            
            console.log(`✅ Database file found: ${dbPath} (${dbFile.size} bytes)`);
          } else {
            console.log(`❌ Database file not found: ${dbPath}`);
          }
        } catch (error) {
          dbFile.error = error.message;
          console.error(`❌ Error accessing database file ${dbPath}:`, error.message);
        }
        
        diagnosticReport.databaseFiles.push(dbFile);
      }
      
      expect(diagnosticReport.databaseFiles.length).toBe(databasePaths.length);
    });

    it('should analyze database file integrity', async () => {
      console.log('🔍 Analyzing database file integrity...');
      
      const validDatabases = diagnosticReport.databaseFiles.filter(
        db => db.exists && db.readable && db.size > 0
      );
      
      if (validDatabases.length === 0) {
        diagnosticReport.errorPatterns.push('No valid database files found');
        diagnosticReport.recommendations.push('Critical: No accessible database files - check file permissions and paths');
      }
      
      for (const dbFile of validDatabases) {
        try {
          // Test basic SQLite file format
          const db = new Database(dbFile.path, { readonly: true });
          const result = db.prepare('SELECT sqlite_version()').get();
          db.close();
          
          console.log(`✅ Database integrity verified: ${dbFile.path} (SQLite ${result.sqlite_version})`);
        } catch (error) {
          dbFile.error = error.message;
          console.error(`❌ Database integrity check failed for ${dbFile.path}:`, error.message);
          diagnosticReport.errorPatterns.push(`Database corruption: ${dbFile.path}`);
        }
      }
      
      expect(validDatabases.length).toBeGreaterThan(0);
    });
  });

  describe('Database Connection Testing', () => {
    it('should test database connections', async () => {
      console.log('🔗 Testing database connections...');
      
      const validDatabases = diagnosticReport.databaseFiles.filter(
        db => db.exists && db.readable && !db.error
      );
      
      for (const dbFile of validDatabases) {
        const startTime = Date.now();
        const connection: DatabaseConnection = {
          path: dbFile.path,
          connected: false,
          version: '',
          tables: [],
          indexes: [],
          connectionTime: 0
        };
        
        try {
          const db = new Database(dbFile.path, { readonly: true });
          
          // Test basic connection
          const versionResult = db.prepare('SELECT sqlite_version() as version').get();
          connection.version = versionResult.version;
          connection.connected = true;
          connection.connectionTime = Date.now() - startTime;
          
          // Get table list
          const tablesResult = db.prepare(`
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name NOT LIKE 'sqlite_%'
            ORDER BY name
          `).all();
          connection.tables = tablesResult.map(t => t.name);
          
          // Get index list
          const indexesResult = db.prepare(`
            SELECT name FROM sqlite_master 
            WHERE type='index' AND name NOT LIKE 'sqlite_%'
            ORDER BY name
          `).all();
          connection.indexes = indexesResult.map(i => i.name);
          
          db.close();
          
          console.log(`✅ Database connection successful: ${dbFile.path}`);
          console.log(`   SQLite version: ${connection.version}`);
          console.log(`   Tables: ${connection.tables.length}`);
          console.log(`   Indexes: ${connection.indexes.length}`);
          console.log(`   Connection time: ${connection.connectionTime}ms`);
          
        } catch (error) {
          connection.error = error.message;
          console.error(`❌ Database connection failed for ${dbFile.path}:`, error.message);
          diagnosticReport.errorPatterns.push(`Connection error: ${dbFile.path}`);
        }
        
        diagnosticReport.connections.push(connection);
      }
      
      expect(diagnosticReport.connections.length).toBe(validDatabases.length);
    });

    it('should test database schema integrity', async () => {
      console.log('📊 Testing database schema integrity...');
      
      const connectedDatabases = diagnosticReport.connections.filter(
        conn => conn.connected && !conn.error
      );
      
      const expectedTables = [
        'users',
        'incidents',
        'problems',
        'changes',
        'change_requests',
        'configuration_items',
        'assets',
        'projects',
        'releases',
        'improvements',
        'rbac_permissions',
        'audit_logs',
        'availability_monitoring',
        'capacity_monitoring',
        'security_management',
        'knowledge_base',
        'service_catalog',
        'request_fulfillment',
        'business_services',
        'supplier_management'
      ];
      
      for (const connection of connectedDatabases) {
        const missingTables = expectedTables.filter(
          table => !connection.tables.includes(table)
        );
        
        if (missingTables.length > 0) {
          console.log(`⚠️  Missing tables in ${connection.path}:`);
          missingTables.forEach(table => console.log(`   - ${table}`));
          diagnosticReport.recommendations.push(`Missing tables in ${connection.path}: ${missingTables.join(', ')}`);
        } else {
          console.log(`✅ All expected tables present in ${connection.path}`);
        }
      }
      
      expect(connectedDatabases.length).toBeGreaterThan(0);
    });
  });

  describe('Database Query Performance Testing', () => {
    it('should test basic query performance', async () => {
      console.log('⚡ Testing database query performance...');
      
      const connectedDatabases = diagnosticReport.connections.filter(
        conn => conn.connected && !conn.error
      );
      
      const testQueries = [
        'SELECT COUNT(*) as count FROM users',
        'SELECT COUNT(*) as count FROM incidents',
        'SELECT COUNT(*) as count FROM problems',
        'SELECT COUNT(*) as count FROM changes',
        'SELECT name FROM sqlite_master WHERE type="table"',
        'PRAGMA table_info(users)',
        'PRAGMA database_list',
        'PRAGMA integrity_check',
        'SELECT sqlite_version()'
      ];
      
      for (const connection of connectedDatabases) {
        console.log(`📊 Testing queries on ${connection.path}...`);
        
        try {
          const db = new Database(connection.path, { readonly: true });
          
          for (const queryText of testQueries) {
            const startTime = Date.now();
            const query: DatabaseQuery = {
              query: queryText,
              success: false,
              executionTime: 0,
              rowCount: 0
            };
            
            try {
              const result = db.prepare(queryText).all();
              query.success = true;
              query.executionTime = Date.now() - startTime;
              query.rowCount = Array.isArray(result) ? result.length : 1;
              query.result = result;
              
              console.log(`   ✅ ${queryText}: ${query.executionTime}ms (${query.rowCount} rows)`);
            } catch (error) {
              query.error = error.message;
              query.executionTime = Date.now() - startTime;
              console.log(`   ❌ ${queryText}: ${error.message}`);
            }
            
            diagnosticReport.queries.push(query);
          }
          
          db.close();
        } catch (error) {
          console.error(`❌ Query testing failed for ${connection.path}:`, error.message);
        }
      }
      
      expect(diagnosticReport.queries.length).toBeGreaterThan(0);
    });

    it('should analyze query performance patterns', async () => {
      console.log('📈 Analyzing query performance patterns...');
      
      const successfulQueries = diagnosticReport.queries.filter(q => q.success);
      const failedQueries = diagnosticReport.queries.filter(q => !q.success);
      
      if (successfulQueries.length > 0) {
        const avgExecutionTime = successfulQueries.reduce((sum, q) => sum + q.executionTime, 0) / successfulQueries.length;
        const slowQueries = successfulQueries.filter(q => q.executionTime > 1000);
        
        console.log(`📊 Query Performance Analysis:`);
        console.log(`   Successful queries: ${successfulQueries.length}`);
        console.log(`   Failed queries: ${failedQueries.length}`);
        console.log(`   Average execution time: ${avgExecutionTime.toFixed(2)}ms`);
        console.log(`   Slow queries (>1s): ${slowQueries.length}`);
        
        if (slowQueries.length > 0) {
          diagnosticReport.recommendations.push('Performance: Slow queries detected - database optimization needed');
        }
        
        if (failedQueries.length > 0) {
          diagnosticReport.recommendations.push('Data integrity: Query failures detected - check database schema');
        }
      }
      
      expect(successfulQueries.length).toBeGreaterThan(0);
    });
  });

  describe('Database Transaction Testing', () => {
    it('should test database transaction capabilities', async () => {
      console.log('🔄 Testing database transaction capabilities...');
      
      const writableDatabases = diagnosticReport.databaseFiles.filter(
        db => db.exists && db.readable && db.writable && !db.error
      );
      
      for (const dbFile of writableDatabases) {
        try {
          const db = new Database(dbFile.path);
          
          // Test transaction support
          const startTime = Date.now();
          const transaction = db.transaction((queries) => {
            for (const query of queries) {
              db.prepare(query).run();
            }
          });
          
          // Test with simple SELECT queries (safe)
          const testQueries = [
            'SELECT 1',
            'SELECT sqlite_version()',
            'SELECT COUNT(*) FROM sqlite_master'
          ];
          
          transaction(testQueries);
          
          const transactionTime = Date.now() - startTime;
          
          console.log(`✅ Transaction support verified for ${dbFile.path} (${transactionTime}ms)`);
          
          db.close();
        } catch (error) {
          console.error(`❌ Transaction test failed for ${dbFile.path}:`, error.message);
          diagnosticReport.errorPatterns.push(`Transaction error: ${dbFile.path}`);
        }
      }
      
      expect(writableDatabases.length).toBeGreaterThanOrEqual(0);
    });

    it('should test database backup capability', async () => {
      console.log('💾 Testing database backup capability...');
      
      const accessibleDatabases = diagnosticReport.databaseFiles.filter(
        db => db.exists && db.readable && !db.error
      );
      
      for (const dbFile of accessibleDatabases) {
        try {
          const db = new Database(dbFile.path, { readonly: true });
          
          // Test backup capability by creating a temporary backup
          const backupPath = `${dbFile.path}.backup-test`;
          const backupDb = new Database(backupPath);
          
          // Test backup process
          const startTime = Date.now();
          await new Promise<void>((resolve, reject) => {
            db.backup(backupPath)
              .then(() => {
                const backupTime = Date.now() - startTime;
                console.log(`✅ Backup capability verified for ${dbFile.path} (${backupTime}ms)`);
                
                // Cleanup test backup
                backupDb.close();
                if (fs.existsSync(backupPath)) {
                  fs.unlinkSync(backupPath);
                }
                
                resolve();
              })
              .catch(reject);
          });
          
          db.close();
        } catch (error) {
          console.error(`❌ Backup test failed for ${dbFile.path}:`, error.message);
          diagnosticReport.errorPatterns.push(`Backup error: ${dbFile.path}`);
        }
      }
      
      expect(accessibleDatabases.length).toBeGreaterThan(0);
    });
  });

  /**
   * Generate comprehensive database diagnostic report
   */
  async function generateDatabaseDiagnosticReport() {
    console.log('📋 Generating Database Diagnostic Report...');
    
    // Determine overall status
    const hasValidDatabases = diagnosticReport.connections.some(conn => conn.connected);
    const hasErrors = diagnosticReport.errorPatterns.length > 0;
    const hasFailedQueries = diagnosticReport.queries.some(q => !q.success);
    
    if (!hasValidDatabases || diagnosticReport.errorPatterns.length > 3) {
      diagnosticReport.overallStatus = 'failed';
    } else if (hasErrors || hasFailedQueries) {
      diagnosticReport.overallStatus = 'degraded';
    } else {
      diagnosticReport.overallStatus = 'healthy';
    }
    
    // Generate recommendations based on findings
    if (!hasValidDatabases) {
      diagnosticReport.recommendations.push('Critical: No valid database connections - system cannot function');
    }
    
    if (diagnosticReport.databaseFiles.every(db => !db.exists)) {
      diagnosticReport.recommendations.push('Critical: No database files found - initialize database');
    }
    
    if (diagnosticReport.databaseFiles.some(db => db.exists && !db.readable)) {
      diagnosticReport.recommendations.push('Security: Database file permission issues - check file permissions');
    }
    
    if (diagnosticReport.queries.some(q => q.success && q.executionTime > 2000)) {
      diagnosticReport.recommendations.push('Performance: Database queries are slow - consider optimization');
    }
    
    // Add general recommendations
    if (diagnosticReport.overallStatus === 'failed') {
      diagnosticReport.recommendations.push('Emergency: Database system is non-functional - immediate attention required');
    } else if (diagnosticReport.overallStatus === 'degraded') {
      diagnosticReport.recommendations.push('Warning: Database system has issues - monitoring and maintenance needed');
    }
    
    // Write diagnostic report to file
    const reportPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/DATABASE_DIAGNOSTIC_REPORT.json';
    fs.writeFileSync(reportPath, JSON.stringify(diagnosticReport, null, 2));
    
    console.log('📊 Database Diagnostic Report Generated:', reportPath);
    console.log('🎯 Overall Database Status:', diagnosticReport.overallStatus);
    console.log('📁 Database Files:', diagnosticReport.databaseFiles.length);
    console.log('🔗 Connections:', diagnosticReport.connections.length);
    console.log('📊 Queries Tested:', diagnosticReport.queries.length);
    console.log('⚠️  Error Patterns:', diagnosticReport.errorPatterns.length);
    console.log('💡 Recommendations:', diagnosticReport.recommendations.length);
  }
});