/**
 * 緊急システム障害診断 - 7コンポーネント包括的テストスイート
 * Emergency System Failure Diagnostic - Comprehensive 7-Component Test Suite
 * 
 * Role: QA Engineer (System Failure Diagnosis & Quality Assurance)
 * Priority: Maximum Emergency
 * Target: 7 Components 500 Error Comprehensive Testing & Diagnosis
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import axios from 'axios';
import { WebSocket } from 'ws';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

interface ComponentHealthStatus {
  component: string;
  status: 'healthy' | 'degraded' | 'failed';
  responseTime: number;
  errorDetails?: string;
  diagnosticData?: any;
}

interface DiagnosticReport {
  timestamp: string;
  overallStatus: 'healthy' | 'degraded' | 'critical';
  components: ComponentHealthStatus[];
  commonErrorPatterns: string[];
  recommendations: string[];
}

describe('Emergency System Failure Diagnostic Suite', () => {
  let diagnosticReport: DiagnosticReport;
  const baseUrl = 'http://localhost:3001';
  const frontendUrl = 'http://localhost:3000';
  
  beforeAll(async () => {
    console.log('🚨 EMERGENCY DIAGNOSTIC STARTING - 7 Components Analysis');
    diagnosticReport = {
      timestamp: new Date().toISOString(),
      overallStatus: 'healthy',
      components: [],
      commonErrorPatterns: [],
      recommendations: []
    };
  });

  afterAll(async () => {
    console.log('📋 EMERGENCY DIAGNOSTIC COMPLETE');
    await generateDiagnosticReport();
  });

  describe('Component 1: Frontend React Application', () => {
    let frontendStatus: ComponentHealthStatus;

    beforeAll(() => {
      frontendStatus = {
        component: 'Frontend React Application',
        status: 'healthy',
        responseTime: 0
      };
    });

    it('should verify frontend application availability', async () => {
      const startTime = Date.now();
      
      try {
        const response = await axios.get(frontendUrl, {
          timeout: 5000,
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
          }
        });
        
        frontendStatus.responseTime = Date.now() - startTime;
        
        expect(response.status).toBe(200);
        expect(response.data).toContain('<!DOCTYPE html>');
        
        frontendStatus.status = 'healthy';
        frontendStatus.diagnosticData = {
          contentType: response.headers['content-type'],
          contentLength: response.headers['content-length'],
          server: response.headers['server']
        };
        
        console.log('✅ Frontend: Available and responsive');
      } catch (error) {
        frontendStatus.status = 'failed';
        frontendStatus.errorDetails = error.message;
        frontendStatus.diagnosticData = {
          errorType: error.name,
          errorCode: error.code,
          errorMessage: error.message
        };
        
        console.error('❌ Frontend: Failed to respond', error.message);
        diagnosticReport.commonErrorPatterns.push('Frontend Connection Error');
      }
      
      diagnosticReport.components.push(frontendStatus);
    });

    it('should test frontend static assets loading', async () => {
      try {
        const assetsToCheck = [
          '/vite.svg',
          '/manifest.json'
        ];
        
        const assetResults = [];
        for (const asset of assetsToCheck) {
          try {
            const response = await axios.get(`${frontendUrl}${asset}`, { timeout: 3000 });
            assetResults.push({ asset, status: response.status, size: response.headers['content-length'] });
          } catch (error) {
            assetResults.push({ asset, status: 'failed', error: error.message });
          }
        }
        
        frontendStatus.diagnosticData = {
          ...frontendStatus.diagnosticData,
          staticAssets: assetResults
        };
        
        console.log('📦 Frontend Assets Check:', assetResults);
      } catch (error) {
        console.error('❌ Frontend Assets: Failed to check', error.message);
      }
    });

    it('should verify frontend build integrity', async () => {
      const frontendPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/frontend';
      const buildPath = path.join(frontendPath, 'dist');
      
      try {
        const buildExists = fs.existsSync(buildPath);
        const packageJsonExists = fs.existsSync(path.join(frontendPath, 'package.json'));
        
        frontendStatus.diagnosticData = {
          ...frontendStatus.diagnosticData,
          buildIntegrity: {
            buildExists,
            packageJsonExists,
            buildPath
          }
        };
        
        expect(packageJsonExists).toBe(true);
        console.log('🔧 Frontend Build Integrity: Verified');
      } catch (error) {
        console.error('❌ Frontend Build: Integrity check failed', error.message);
      }
    });
  });

  describe('Component 2: Backend API Server', () => {
    let backendStatus: ComponentHealthStatus;

    beforeAll(() => {
      backendStatus = {
        component: 'Backend API Server',
        status: 'healthy',
        responseTime: 0
      };
    });

    it('should verify backend API server availability', async () => {
      const startTime = Date.now();
      
      try {
        const response = await axios.get(`${baseUrl}/health`, {
          timeout: 5000,
          headers: {
            'Accept': 'application/json'
          }
        });
        
        backendStatus.responseTime = Date.now() - startTime;
        backendStatus.status = 'healthy';
        backendStatus.diagnosticData = {
          statusCode: response.status,
          headers: response.headers,
          data: response.data
        };
        
        expect(response.status).toBe(200);
        console.log('✅ Backend API: Available and responsive');
      } catch (error) {
        backendStatus.status = 'failed';
        backendStatus.errorDetails = error.message;
        backendStatus.diagnosticData = {
          errorType: error.name,
          errorCode: error.code,
          errorMessage: error.message,
          requestConfig: error.config
        };
        
        console.error('❌ Backend API: Failed to respond', error.message);
        diagnosticReport.commonErrorPatterns.push('Backend API Connection Error');
      }
      
      diagnosticReport.components.push(backendStatus);
    });

    it('should test critical API endpoints', async () => {
      const criticalEndpoints = [
        '/api/auth/status',
        '/api/users/profile',
        '/api/incidents',
        '/api/problems',
        '/api/changes',
        '/api/vendors',
        '/api/reports'
      ];
      
      const endpointResults = [];
      
      for (const endpoint of criticalEndpoints) {
        try {
          const response = await axios.get(`${baseUrl}${endpoint}`, {
            timeout: 3000,
            headers: {
              'Authorization': 'Bearer test-token',
              'Accept': 'application/json'
            }
          });
          
          endpointResults.push({
            endpoint,
            status: response.status,
            responseTime: Date.now() - Date.now()
          });
        } catch (error) {
          endpointResults.push({
            endpoint,
            status: 'failed',
            error: error.response?.status || error.message,
            details: error.response?.data || error.message
          });
          
          if (error.response?.status === 500) {
            diagnosticReport.commonErrorPatterns.push(`500 Error: ${endpoint}`);
          }
        }
      }
      
      backendStatus.diagnosticData = {
        ...backendStatus.diagnosticData,
        criticalEndpoints: endpointResults
      };
      
      console.log('🔍 Critical Endpoints Test:', endpointResults);
    });

    it('should verify backend server process', async () => {
      const backendPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend';
      
      try {
        const packageJsonExists = fs.existsSync(path.join(backendPath, 'package.json'));
        const appFileExists = fs.existsSync(path.join(backendPath, 'src/app.ts'));
        const nodeModulesExists = fs.existsSync(path.join(backendPath, 'node_modules'));
        
        backendStatus.diagnosticData = {
          ...backendStatus.diagnosticData,
          serverIntegrity: {
            packageJsonExists,
            appFileExists,
            nodeModulesExists,
            backendPath
          }
        };
        
        expect(packageJsonExists).toBe(true);
        expect(appFileExists).toBe(true);
        
        console.log('🔧 Backend Server Integrity: Verified');
      } catch (error) {
        console.error('❌ Backend Server: Integrity check failed', error.message);
      }
    });
  });

  describe('Component 3: Database System', () => {
    let databaseStatus: ComponentHealthStatus;

    beforeAll(() => {
      databaseStatus = {
        component: 'Database System',
        status: 'healthy',
        responseTime: 0
      };
    });

    it('should verify database connectivity', async () => {
      const startTime = Date.now();
      
      try {
        const response = await axios.get(`${baseUrl}/api/health/database`, {
          timeout: 5000
        });
        
        databaseStatus.responseTime = Date.now() - startTime;
        databaseStatus.status = 'healthy';
        databaseStatus.diagnosticData = {
          connectionStatus: response.data,
          responseTime: databaseStatus.responseTime
        };
        
        expect(response.status).toBe(200);
        console.log('✅ Database: Connection verified');
      } catch (error) {
        databaseStatus.status = 'failed';
        databaseStatus.errorDetails = error.message;
        databaseStatus.diagnosticData = {
          errorType: error.name,
          errorMessage: error.message
        };
        
        console.error('❌ Database: Connection failed', error.message);
        diagnosticReport.commonErrorPatterns.push('Database Connection Error');
      }
      
      diagnosticReport.components.push(databaseStatus);
    });

    it('should verify database file integrity', async () => {
      const dbPaths = [
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/data/itsm.db',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/database/itsm.db'
      ];
      
      const dbFileResults = [];
      
      for (const dbPath of dbPaths) {
        try {
          const exists = fs.existsSync(dbPath);
          const stats = exists ? fs.statSync(dbPath) : null;
          
          dbFileResults.push({
            path: dbPath,
            exists,
            size: stats?.size || 0,
            modified: stats?.mtime || null
          });
        } catch (error) {
          dbFileResults.push({
            path: dbPath,
            exists: false,
            error: error.message
          });
        }
      }
      
      databaseStatus.diagnosticData = {
        ...databaseStatus.diagnosticData,
        databaseFiles: dbFileResults
      };
      
      console.log('💾 Database Files Check:', dbFileResults);
    });

    it('should test database query performance', async () => {
      try {
        const queryTests = [
          { name: 'users', endpoint: '/api/users' },
          { name: 'incidents', endpoint: '/api/incidents' },
          { name: 'problems', endpoint: '/api/problems' }
        ];
        
        const queryResults = [];
        
        for (const test of queryTests) {
          const startTime = Date.now();
          try {
            const response = await axios.get(`${baseUrl}${test.endpoint}`, {
              timeout: 3000,
              headers: { 'Authorization': 'Bearer test-token' }
            });
            
            queryResults.push({
              query: test.name,
              responseTime: Date.now() - startTime,
              status: response.status,
              recordCount: Array.isArray(response.data?.data) ? response.data.data.length : 0
            });
          } catch (error) {
            queryResults.push({
              query: test.name,
              status: 'failed',
              error: error.response?.status || error.message
            });
          }
        }
        
        databaseStatus.diagnosticData = {
          ...databaseStatus.diagnosticData,
          queryPerformance: queryResults
        };
        
        console.log('⚡ Database Query Performance:', queryResults);
      } catch (error) {
        console.error('❌ Database Query: Performance test failed', error.message);
      }
    });
  });

  describe('Component 4: Authentication/Authorization', () => {
    let authStatus: ComponentHealthStatus;

    beforeAll(() => {
      authStatus = {
        component: 'Authentication/Authorization',
        status: 'healthy',
        responseTime: 0
      };
    });

    it('should verify authentication endpoints', async () => {
      const startTime = Date.now();
      
      try {
        const loginResponse = await axios.post(`${baseUrl}/api/auth/login`, {
          username: 'testuser',
          password: 'testpass'
        }, {
          timeout: 5000
        });
        
        authStatus.responseTime = Date.now() - startTime;
        authStatus.status = loginResponse.status === 200 ? 'healthy' : 'degraded';
        authStatus.diagnosticData = {
          loginStatus: loginResponse.status,
          hasToken: !!loginResponse.data?.token,
          authHeaders: loginResponse.headers
        };
        
        console.log('🔐 Authentication: Login endpoint verified');
      } catch (error) {
        authStatus.status = 'failed';
        authStatus.errorDetails = error.message;
        authStatus.diagnosticData = {
          errorType: error.name,
          errorMessage: error.message,
          statusCode: error.response?.status
        };
        
        console.error('❌ Authentication: Failed', error.message);
        diagnosticReport.commonErrorPatterns.push('Authentication Error');
      }
      
      diagnosticReport.components.push(authStatus);
    });

    it('should test JWT token validation', async () => {
      try {
        const tokenValidationResponse = await axios.get(`${baseUrl}/api/auth/validate`, {
          headers: {
            'Authorization': 'Bearer invalid-token'
          },
          timeout: 3000
        });
        
        authStatus.diagnosticData = {
          ...authStatus.diagnosticData,
          tokenValidation: {
            status: tokenValidationResponse.status,
            response: tokenValidationResponse.data
          }
        };
        
        console.log('🎫 JWT Token Validation: Tested');
      } catch (error) {
        authStatus.diagnosticData = {
          ...authStatus.diagnosticData,
          tokenValidation: {
            status: 'failed',
            error: error.response?.status || error.message
          }
        };
        
        console.log('🎫 JWT Token Validation: Expected failure for invalid token');
      }
    });

    it('should verify RBAC permissions', async () => {
      const rbacEndpoints = [
        '/api/rbac/roles',
        '/api/rbac/permissions',
        '/api/rbac/users'
      ];
      
      const rbacResults = [];
      
      for (const endpoint of rbacEndpoints) {
        try {
          const response = await axios.get(`${baseUrl}${endpoint}`, {
            timeout: 3000,
            headers: {
              'Authorization': 'Bearer test-admin-token'
            }
          });
          
          rbacResults.push({
            endpoint,
            status: response.status,
            accessible: response.status === 200
          });
        } catch (error) {
          rbacResults.push({
            endpoint,
            status: 'failed',
            error: error.response?.status || error.message
          });
        }
      }
      
      authStatus.diagnosticData = {
        ...authStatus.diagnosticData,
        rbacPermissions: rbacResults
      };
      
      console.log('👤 RBAC Permissions: Tested');
    });
  });

  describe('Component 5: WebSocket Realtime', () => {
    let websocketStatus: ComponentHealthStatus;

    beforeAll(() => {
      websocketStatus = {
        component: 'WebSocket Realtime',
        status: 'healthy',
        responseTime: 0
      };
    });

    it('should verify WebSocket connection', async () => {
      const startTime = Date.now();
      
      return new Promise((resolve) => {
        try {
          const ws = new WebSocket('ws://localhost:3001');
          
          ws.on('open', () => {
            websocketStatus.responseTime = Date.now() - startTime;
            websocketStatus.status = 'healthy';
            websocketStatus.diagnosticData = {
              connectionTime: websocketStatus.responseTime,
              readyState: ws.readyState
            };
            
            console.log('🔗 WebSocket: Connection established');
            ws.close();
            resolve(true);
          });
          
          ws.on('error', (error) => {
            websocketStatus.status = 'failed';
            websocketStatus.errorDetails = error.message;
            websocketStatus.diagnosticData = {
              errorType: error.name,
              errorMessage: error.message
            };
            
            console.error('❌ WebSocket: Connection failed', error.message);
            diagnosticReport.commonErrorPatterns.push('WebSocket Connection Error');
            resolve(false);
          });
          
          // Timeout after 5 seconds
          setTimeout(() => {
            if (ws.readyState === WebSocket.CONNECTING) {
              ws.close();
              websocketStatus.status = 'failed';
              websocketStatus.errorDetails = 'Connection timeout';
              console.error('❌ WebSocket: Connection timeout');
              resolve(false);
            }
          }, 5000);
        } catch (error) {
          websocketStatus.status = 'failed';
          websocketStatus.errorDetails = error.message;
          console.error('❌ WebSocket: Setup failed', error.message);
          resolve(false);
        }
      });
    });

    afterAll(() => {
      diagnosticReport.components.push(websocketStatus);
    });
  });

  describe('Component 6: External API Integration', () => {
    let externalApiStatus: ComponentHealthStatus;

    beforeAll(() => {
      externalApiStatus = {
        component: 'External API Integration',
        status: 'healthy',
        responseTime: 0
      };
    });

    it('should verify external API connectivity (192.168.3.135)', async () => {
      const startTime = Date.now();
      const externalUrl = 'http://192.168.3.135';
      
      try {
        const response = await axios.get(externalUrl, {
          timeout: 5000,
          headers: {
            'Accept': 'application/json'
          }
        });
        
        externalApiStatus.responseTime = Date.now() - startTime;
        externalApiStatus.status = 'healthy';
        externalApiStatus.diagnosticData = {
          statusCode: response.status,
          responseTime: externalApiStatus.responseTime,
          headers: response.headers
        };
        
        console.log('🌐 External API: Connection verified');
      } catch (error) {
        externalApiStatus.status = 'failed';
        externalApiStatus.errorDetails = error.message;
        externalApiStatus.diagnosticData = {
          errorType: error.name,
          errorCode: error.code,
          errorMessage: error.message
        };
        
        console.error('❌ External API: Connection failed', error.message);
        diagnosticReport.commonErrorPatterns.push('External API Connection Error');
      }
      
      diagnosticReport.components.push(externalApiStatus);
    });

    it('should test API integration patterns', async () => {
      try {
        const integrationResponse = await axios.get(`${baseUrl}/api/integration/status`, {
          timeout: 3000
        });
        
        externalApiStatus.diagnosticData = {
          ...externalApiStatus.diagnosticData,
          integrationStatus: integrationResponse.data
        };
        
        console.log('🔗 API Integration: Patterns tested');
      } catch (error) {
        externalApiStatus.diagnosticData = {
          ...externalApiStatus.diagnosticData,
          integrationStatus: {
            status: 'failed',
            error: error.message
          }
        };
        
        console.log('🔗 API Integration: Failed to test patterns');
      }
    });
  });

  describe('Component 7: Monitoring/Analytics', () => {
    let monitoringStatus: ComponentHealthStatus;

    beforeAll(() => {
      monitoringStatus = {
        component: 'Monitoring/Analytics',
        status: 'healthy',
        responseTime: 0
      };
    });

    it('should verify monitoring endpoints', async () => {
      const startTime = Date.now();
      
      try {
        const metricsResponse = await axios.get(`${baseUrl}/metrics`, {
          timeout: 5000
        });
        
        monitoringStatus.responseTime = Date.now() - startTime;
        monitoringStatus.status = 'healthy';
        monitoringStatus.diagnosticData = {
          statusCode: metricsResponse.status,
          metricsAvailable: metricsResponse.data.length > 0,
          contentType: metricsResponse.headers['content-type']
        };
        
        console.log('📊 Monitoring: Metrics endpoint verified');
      } catch (error) {
        monitoringStatus.status = 'failed';
        monitoringStatus.errorDetails = error.message;
        monitoringStatus.diagnosticData = {
          errorType: error.name,
          errorMessage: error.message
        };
        
        console.error('❌ Monitoring: Failed', error.message);
        diagnosticReport.commonErrorPatterns.push('Monitoring Error');
      }
      
      diagnosticReport.components.push(monitoringStatus);
    });

    it('should test analytics data collection', async () => {
      try {
        const analyticsResponse = await axios.get(`${baseUrl}/api/analytics/health`, {
          timeout: 3000
        });
        
        monitoringStatus.diagnosticData = {
          ...monitoringStatus.diagnosticData,
          analyticsStatus: analyticsResponse.data
        };
        
        console.log('📈 Analytics: Data collection verified');
      } catch (error) {
        monitoringStatus.diagnosticData = {
          ...monitoringStatus.diagnosticData,
          analyticsStatus: {
            status: 'failed',
            error: error.message
          }
        };
        
        console.log('📈 Analytics: Failed to verify data collection');
      }
    });
  });

  /**
   * Generate comprehensive diagnostic report
   */
  async function generateDiagnosticReport() {
    // Calculate overall system status
    const failedComponents = diagnosticReport.components.filter(c => c.status === 'failed');
    const degradedComponents = diagnosticReport.components.filter(c => c.status === 'degraded');
    
    if (failedComponents.length > 0) {
      diagnosticReport.overallStatus = 'critical';
    } else if (degradedComponents.length > 0) {
      diagnosticReport.overallStatus = 'degraded';
    } else {
      diagnosticReport.overallStatus = 'healthy';
    }
    
    // Generate recommendations
    diagnosticReport.recommendations = [];
    
    if (diagnosticReport.commonErrorPatterns.includes('Frontend Connection Error')) {
      diagnosticReport.recommendations.push('Check frontend server process and port 3000 availability');
    }
    
    if (diagnosticReport.commonErrorPatterns.includes('Backend API Connection Error')) {
      diagnosticReport.recommendations.push('Check backend server process and port 3001 availability');
    }
    
    if (diagnosticReport.commonErrorPatterns.includes('Database Connection Error')) {
      diagnosticReport.recommendations.push('Verify SQLite database file integrity and permissions');
    }
    
    if (diagnosticReport.commonErrorPatterns.includes('Authentication Error')) {
      diagnosticReport.recommendations.push('Check JWT configuration and authentication middleware');
    }
    
    if (diagnosticReport.commonErrorPatterns.includes('WebSocket Connection Error')) {
      diagnosticReport.recommendations.push('Verify WebSocket server configuration and Socket.IO setup');
    }
    
    if (diagnosticReport.commonErrorPatterns.includes('External API Connection Error')) {
      diagnosticReport.recommendations.push('Check network connectivity to 192.168.3.135 server');
    }
    
    if (diagnosticReport.commonErrorPatterns.includes('Monitoring Error')) {
      diagnosticReport.recommendations.push('Verify monitoring service configuration and Prometheus setup');
    }
    
    if (diagnosticReport.commonErrorPatterns.some(pattern => pattern.includes('500 Error'))) {
      diagnosticReport.recommendations.push('Critical: Multiple 500 errors detected - immediate investigation required');
    }
    
    // Write diagnostic report to file
    const reportPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/EMERGENCY_DIAGNOSTIC_REPORT.json';
    fs.writeFileSync(reportPath, JSON.stringify(diagnosticReport, null, 2));
    
    console.log('📋 Emergency Diagnostic Report Generated:', reportPath);
    console.log('🎯 Overall System Status:', diagnosticReport.overallStatus);
    console.log('📊 Components Status:', diagnosticReport.components.map(c => `${c.component}: ${c.status}`));
    console.log('⚠️  Common Error Patterns:', diagnosticReport.commonErrorPatterns);
    console.log('💡 Recommendations:', diagnosticReport.recommendations);
  }
});