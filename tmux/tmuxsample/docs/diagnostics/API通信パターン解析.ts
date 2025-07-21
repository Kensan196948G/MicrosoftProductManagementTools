/**
 * API通信パターン分析システム
 * API Communication Pattern Analyzer
 * 
 * Role: QA Engineer - Emergency System Diagnosis
 * Target: Comprehensive API Communication Pattern Analysis
 * Priority: Emergency - 500 Error Pattern Detection
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import axios, { AxiosResponse } from 'axios';
import fs from 'fs';
import path from 'path';

interface ApiEndpoint {
  method: string;
  path: string;
  expectedStatus: number;
  requiresAuth: boolean;
  category: string;
}

interface ApiTestResult {
  endpoint: ApiEndpoint;
  status: 'success' | 'failed' | 'timeout' | 'error';
  responseTime: number;
  statusCode?: number;
  errorDetails?: any;
  responseData?: any;
  headers?: any;
}

interface CommunicationPattern {
  pattern: string;
  frequency: number;
  errorRate: number;
  avgResponseTime: number;
  endpoints: string[];
  errorTypes: string[];
}

interface ApiAnalysisReport {
  timestamp: string;
  totalEndpoints: number;
  successRate: number;
  failureRate: number;
  averageResponseTime: number;
  criticalErrors: ApiTestResult[];
  communicationPatterns: CommunicationPattern[];
  recommendations: string[];
  detailedResults: ApiTestResult[];
}

describe('API Communication Pattern Analysis', () => {
  let analysisReport: ApiAnalysisReport;
  const baseUrl = 'http://localhost:3001';
  
  // 包括的なAPIエンドポイント一覧
  const apiEndpoints: ApiEndpoint[] = [
    // Authentication & Authorization
    { method: 'POST', path: '/api/auth/login', expectedStatus: 200, requiresAuth: false, category: 'auth' },
    { method: 'POST', path: '/api/auth/logout', expectedStatus: 200, requiresAuth: true, category: 'auth' },
    { method: 'GET', path: '/api/auth/profile', expectedStatus: 200, requiresAuth: true, category: 'auth' },
    { method: 'GET', path: '/api/auth/validate', expectedStatus: 200, requiresAuth: true, category: 'auth' },
    
    // User Management
    { method: 'GET', path: '/api/users', expectedStatus: 200, requiresAuth: true, category: 'users' },
    { method: 'POST', path: '/api/users', expectedStatus: 201, requiresAuth: true, category: 'users' },
    { method: 'GET', path: '/api/users/profile', expectedStatus: 200, requiresAuth: true, category: 'users' },
    { method: 'PUT', path: '/api/users/profile', expectedStatus: 200, requiresAuth: true, category: 'users' },
    
    // Incident Management
    { method: 'GET', path: '/api/incidents', expectedStatus: 200, requiresAuth: true, category: 'incidents' },
    { method: 'POST', path: '/api/incidents', expectedStatus: 201, requiresAuth: true, category: 'incidents' },
    { method: 'GET', path: '/api/incidents/statistics', expectedStatus: 200, requiresAuth: true, category: 'incidents' },
    { method: 'GET', path: '/api/incidents/search', expectedStatus: 200, requiresAuth: true, category: 'incidents' },
    
    // Problem Management
    { method: 'GET', path: '/api/problems', expectedStatus: 200, requiresAuth: true, category: 'problems' },
    { method: 'POST', path: '/api/problems', expectedStatus: 201, requiresAuth: true, category: 'problems' },
    { method: 'GET', path: '/api/problems/statistics', expectedStatus: 200, requiresAuth: true, category: 'problems' },
    { method: 'GET', path: '/api/problems/search', expectedStatus: 200, requiresAuth: true, category: 'problems' },
    
    // Change Management
    { method: 'GET', path: '/api/changes', expectedStatus: 200, requiresAuth: true, category: 'changes' },
    { method: 'POST', path: '/api/changes', expectedStatus: 201, requiresAuth: true, category: 'changes' },
    { method: 'GET', path: '/api/changes/statistics', expectedStatus: 200, requiresAuth: true, category: 'changes' },
    { method: 'GET', path: '/api/change-requests', expectedStatus: 200, requiresAuth: true, category: 'changes' },
    
    // Vendor Management
    { method: 'GET', path: '/api/vendors', expectedStatus: 200, requiresAuth: true, category: 'vendors' },
    { method: 'POST', path: '/api/vendors', expectedStatus: 201, requiresAuth: true, category: 'vendors' },
    { method: 'GET', path: '/api/vendors/statistics', expectedStatus: 200, requiresAuth: true, category: 'vendors' },
    { method: 'POST', path: '/api/vendors/initialize', expectedStatus: 200, requiresAuth: true, category: 'vendors' },
    
    // CMDB & Configuration
    { method: 'GET', path: '/api/cmdb/items', expectedStatus: 200, requiresAuth: true, category: 'cmdb' },
    { method: 'POST', path: '/api/cmdb/items', expectedStatus: 201, requiresAuth: true, category: 'cmdb' },
    { method: 'GET', path: '/api/configuration-items', expectedStatus: 200, requiresAuth: true, category: 'cmdb' },
    { method: 'GET', path: '/api/configuration-baselines', expectedStatus: 200, requiresAuth: true, category: 'cmdb' },
    
    // Asset Management
    { method: 'GET', path: '/api/assets', expectedStatus: 200, requiresAuth: true, category: 'assets' },
    { method: 'POST', path: '/api/assets', expectedStatus: 201, requiresAuth: true, category: 'assets' },
    { method: 'GET', path: '/api/assets/search', expectedStatus: 200, requiresAuth: true, category: 'assets' },
    
    // Reporting & Analytics
    { method: 'GET', path: '/api/reports', expectedStatus: 200, requiresAuth: true, category: 'reports' },
    { method: 'GET', path: '/api/reports/dashboard', expectedStatus: 200, requiresAuth: true, category: 'reports' },
    { method: 'GET', path: '/api/reports/analytics', expectedStatus: 200, requiresAuth: true, category: 'reports' },
    { method: 'GET', path: '/api/reporting/kpi', expectedStatus: 200, requiresAuth: true, category: 'reports' },
    
    // RBAC & Security
    { method: 'GET', path: '/api/rbac/roles', expectedStatus: 200, requiresAuth: true, category: 'rbac' },
    { method: 'GET', path: '/api/rbac/permissions', expectedStatus: 200, requiresAuth: true, category: 'rbac' },
    { method: 'GET', path: '/api/rbac/users', expectedStatus: 200, requiresAuth: true, category: 'rbac' },
    { method: 'GET', path: '/api/security/audit', expectedStatus: 200, requiresAuth: true, category: 'security' },
    
    // Monitoring & Health
    { method: 'GET', path: '/api/health', expectedStatus: 200, requiresAuth: false, category: 'health' },
    { method: 'GET', path: '/api/health/database', expectedStatus: 200, requiresAuth: false, category: 'health' },
    { method: 'GET', path: '/metrics', expectedStatus: 200, requiresAuth: false, category: 'monitoring' },
    { method: 'GET', path: '/api/monitoring/status', expectedStatus: 200, requiresAuth: true, category: 'monitoring' },
    
    // Business Services
    { method: 'GET', path: '/api/business-services', expectedStatus: 200, requiresAuth: true, category: 'business' },
    { method: 'GET', path: '/api/service-catalog', expectedStatus: 200, requiresAuth: true, category: 'business' },
    { method: 'GET', path: '/api/request-fulfillment', expectedStatus: 200, requiresAuth: true, category: 'business' },
    
    // Capacity & Performance
    { method: 'GET', path: '/api/capacity', expectedStatus: 200, requiresAuth: true, category: 'capacity' },
    { method: 'GET', path: '/api/performance-metrics', expectedStatus: 200, requiresAuth: true, category: 'capacity' },
    { method: 'GET', path: '/api/availability', expectedStatus: 200, requiresAuth: true, category: 'capacity' },
    
    // Knowledge Base
    { method: 'GET', path: '/api/knowledge', expectedStatus: 200, requiresAuth: true, category: 'knowledge' },
    { method: 'POST', path: '/api/knowledge', expectedStatus: 201, requiresAuth: true, category: 'knowledge' },
    { method: 'GET', path: '/api/knowledge/search', expectedStatus: 200, requiresAuth: true, category: 'knowledge' }
  ];

  beforeAll(async () => {
    console.log('🔍 Starting API Communication Pattern Analysis...');
    console.log(`📊 Total endpoints to analyze: ${apiEndpoints.length}`);
    
    analysisReport = {
      timestamp: new Date().toISOString(),
      totalEndpoints: apiEndpoints.length,
      successRate: 0,
      failureRate: 0,
      averageResponseTime: 0,
      criticalErrors: [],
      communicationPatterns: [],
      recommendations: [],
      detailedResults: []
    };
  });

  afterAll(async () => {
    await generateApiAnalysisReport();
  });

  describe('API Endpoint Communication Analysis', () => {
    it('should test all API endpoints for communication patterns', async () => {
      console.log('🚀 Testing all API endpoints...');
      
      const testResults: ApiTestResult[] = [];
      let totalResponseTime = 0;
      let successCount = 0;
      let failureCount = 0;
      
      for (const endpoint of apiEndpoints) {
        const startTime = Date.now();
        const testResult: ApiTestResult = {
          endpoint,
          status: 'success',
          responseTime: 0
        };
        
        try {
          const config = {
            method: endpoint.method.toLowerCase(),
            url: `${baseUrl}${endpoint.path}`,
            timeout: 5000,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            }
          };
          
          // Add authentication if required
          if (endpoint.requiresAuth) {
            config.headers['Authorization'] = 'Bearer test-token';
          }
          
          // Add test data for POST requests
          if (endpoint.method === 'POST') {
            config['data'] = getTestDataForEndpoint(endpoint.path);
          }
          
          const response: AxiosResponse = await axios(config);
          
          testResult.responseTime = Date.now() - startTime;
          testResult.statusCode = response.status;
          testResult.headers = response.headers;
          testResult.responseData = response.data;
          
          if (response.status === endpoint.expectedStatus) {
            testResult.status = 'success';
            successCount++;
          } else {
            testResult.status = 'failed';
            testResult.errorDetails = `Expected ${endpoint.expectedStatus}, got ${response.status}`;
            failureCount++;
          }
          
          totalResponseTime += testResult.responseTime;
          
          console.log(`✅ ${endpoint.method} ${endpoint.path}: ${response.status} (${testResult.responseTime}ms)`);
          
        } catch (error) {
          testResult.responseTime = Date.now() - startTime;
          testResult.status = 'error';
          testResult.statusCode = error.response?.status || 0;
          testResult.errorDetails = {
            message: error.message,
            code: error.code,
            response: error.response?.data || null
          };
          
          failureCount++;
          totalResponseTime += testResult.responseTime;
          
          console.error(`❌ ${endpoint.method} ${endpoint.path}: ${error.message}`);
          
          // Track critical errors (500 errors)
          if (error.response?.status === 500) {
            analysisReport.criticalErrors.push(testResult);
          }
        }
        
        testResults.push(testResult);
      }
      
      // Calculate success/failure rates
      analysisReport.successRate = (successCount / apiEndpoints.length) * 100;
      analysisReport.failureRate = (failureCount / apiEndpoints.length) * 100;
      analysisReport.averageResponseTime = totalResponseTime / apiEndpoints.length;
      analysisReport.detailedResults = testResults;
      
      console.log(`📊 Analysis Complete: ${successCount} success, ${failureCount} failures`);
      console.log(`📈 Success Rate: ${analysisReport.successRate.toFixed(2)}%`);
      console.log(`📉 Failure Rate: ${analysisReport.failureRate.toFixed(2)}%`);
      console.log(`⏱️  Average Response Time: ${analysisReport.averageResponseTime.toFixed(2)}ms`);
      
      expect(testResults.length).toBe(apiEndpoints.length);
    });
  });

  describe('Communication Pattern Detection', () => {
    it('should analyze communication patterns by category', async () => {
      console.log('🔍 Analyzing communication patterns by category...');
      
      const categories = [...new Set(apiEndpoints.map(ep => ep.category))];
      const patterns: CommunicationPattern[] = [];
      
      for (const category of categories) {
        const categoryEndpoints = apiEndpoints.filter(ep => ep.category === category);
        const categoryResults = analysisReport.detailedResults.filter(
          result => result.endpoint.category === category
        );
        
        const successfulResults = categoryResults.filter(r => r.status === 'success');
        const failedResults = categoryResults.filter(r => r.status === 'error' || r.status === 'failed');
        
        const pattern: CommunicationPattern = {
          pattern: `${category}_communication`,
          frequency: categoryEndpoints.length,
          errorRate: (failedResults.length / categoryResults.length) * 100,
          avgResponseTime: categoryResults.reduce((sum, r) => sum + r.responseTime, 0) / categoryResults.length,
          endpoints: categoryEndpoints.map(ep => `${ep.method} ${ep.path}`),
          errorTypes: failedResults.map(r => r.errorDetails?.message || 'Unknown error')
        };
        
        patterns.push(pattern);
        
        console.log(`📊 ${category}: ${successfulResults.length}/${categoryResults.length} success (${pattern.errorRate.toFixed(2)}% error rate)`);
      }
      
      analysisReport.communicationPatterns = patterns;
      
      expect(patterns.length).toBe(categories.length);
    });

    it('should identify high-error communication patterns', async () => {
      console.log('🚨 Identifying high-error communication patterns...');
      
      const highErrorPatterns = analysisReport.communicationPatterns.filter(
        pattern => pattern.errorRate > 50
      );
      
      for (const pattern of highErrorPatterns) {
        console.log(`⚠️  High Error Pattern: ${pattern.pattern} (${pattern.errorRate.toFixed(2)}% error rate)`);
        console.log(`   Endpoints: ${pattern.endpoints.join(', ')}`);
        console.log(`   Error Types: ${pattern.errorTypes.join(', ')}`);
      }
      
      if (highErrorPatterns.length > 0) {
        analysisReport.recommendations.push('Critical: High error rate patterns detected - immediate investigation required');
      }
      
      expect(highErrorPatterns).toBeDefined();
    });

    it('should analyze response time patterns', async () => {
      console.log('⏱️  Analyzing response time patterns...');
      
      const slowEndpoints = analysisReport.detailedResults.filter(
        result => result.responseTime > 2000
      );
      
      const fastEndpoints = analysisReport.detailedResults.filter(
        result => result.responseTime < 100
      );
      
      console.log(`🐌 Slow endpoints (>2s): ${slowEndpoints.length}`);
      console.log(`⚡ Fast endpoints (<100ms): ${fastEndpoints.length}`);
      
      if (slowEndpoints.length > 0) {
        analysisReport.recommendations.push('Performance: Slow response times detected - optimization needed');
        slowEndpoints.forEach(endpoint => {
          console.log(`   Slow: ${endpoint.endpoint.method} ${endpoint.endpoint.path} (${endpoint.responseTime}ms)`);
        });
      }
      
      expect(slowEndpoints).toBeDefined();
      expect(fastEndpoints).toBeDefined();
    });
  });

  describe('Error Response Analysis', () => {
    it('should analyze 500 error patterns', async () => {
      console.log('🔥 Analyzing 500 error patterns...');
      
      const fiveHundredErrors = analysisReport.detailedResults.filter(
        result => result.statusCode === 500
      );
      
      if (fiveHundredErrors.length > 0) {
        console.log(`💥 500 Errors detected: ${fiveHundredErrors.length}`);
        
        fiveHundredErrors.forEach(error => {
          console.log(`   500 Error: ${error.endpoint.method} ${error.endpoint.path}`);
          console.log(`   Details: ${JSON.stringify(error.errorDetails, null, 2)}`);
        });
        
        analysisReport.recommendations.push('Critical: 500 Internal Server Errors detected - immediate server investigation required');
      }
      
      expect(fiveHundredErrors).toBeDefined();
    });

    it('should analyze authentication error patterns', async () => {
      console.log('🔐 Analyzing authentication error patterns...');
      
      const authErrors = analysisReport.detailedResults.filter(
        result => result.statusCode === 401 || result.statusCode === 403
      );
      
      if (authErrors.length > 0) {
        console.log(`🚫 Auth Errors detected: ${authErrors.length}`);
        
        authErrors.forEach(error => {
          console.log(`   Auth Error: ${error.endpoint.method} ${error.endpoint.path} (${error.statusCode})`);
        });
        
        analysisReport.recommendations.push('Security: Authentication/Authorization errors detected - check JWT and RBAC configuration');
      }
      
      expect(authErrors).toBeDefined();
    });
  });

  /**
   * Generate test data for POST endpoints
   */
  function getTestDataForEndpoint(path: string): any {
    const testData = {
      '/api/auth/login': {
        username: 'test@example.com',
        password: 'testpassword'
      },
      '/api/users': {
        username: 'testuser',
        email: 'test@example.com',
        password: 'testpassword',
        role: 'user'
      },
      '/api/incidents': {
        title: 'Test Incident',
        description: 'Test incident description',
        priority: 'medium',
        category: 'software',
        status: 'open'
      },
      '/api/problems': {
        title: 'Test Problem',
        description: 'Test problem description',
        priority: 'medium',
        category: 'software',
        status: 'open'
      },
      '/api/changes': {
        title: 'Test Change',
        description: 'Test change description',
        priority: 'medium',
        category: 'software',
        status: 'pending'
      },
      '/api/vendors': {
        name: 'Test Vendor',
        company_type: 'corporation',
        contact_person: 'John Doe',
        email: 'john@testvendor.com',
        phone: '+1234567890',
        address: '123 Test St',
        city: 'Test City',
        country: 'Test Country',
        services_provided: ['IT Support'],
        contract_type: 'recurring'
      },
      '/api/assets': {
        name: 'Test Asset',
        type: 'hardware',
        category: 'server',
        model: 'Test Model',
        serial_number: 'TEST123',
        status: 'active'
      },
      '/api/knowledge': {
        title: 'Test Knowledge Article',
        content: 'Test knowledge content',
        category: 'general',
        tags: ['test', 'knowledge'],
        status: 'published'
      }
    };
    
    return testData[path] || {};
  }

  /**
   * Generate comprehensive API analysis report
   */
  async function generateApiAnalysisReport() {
    console.log('📋 Generating API Communication Analysis Report...');
    
    // Add general recommendations based on analysis
    if (analysisReport.failureRate > 30) {
      analysisReport.recommendations.push('High failure rate detected - comprehensive system review needed');
    }
    
    if (analysisReport.averageResponseTime > 1000) {
      analysisReport.recommendations.push('High average response time - performance optimization required');
    }
    
    if (analysisReport.criticalErrors.length > 0) {
      analysisReport.recommendations.push('Critical errors detected - immediate attention required');
    }
    
    // Write analysis report to file
    const reportPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/API_COMMUNICATION_ANALYSIS_REPORT.json';
    fs.writeFileSync(reportPath, JSON.stringify(analysisReport, null, 2));
    
    console.log('📊 API Communication Analysis Report Generated:', reportPath);
    console.log('📈 Final Statistics:');
    console.log(`   Total Endpoints: ${analysisReport.totalEndpoints}`);
    console.log(`   Success Rate: ${analysisReport.successRate.toFixed(2)}%`);
    console.log(`   Failure Rate: ${analysisReport.failureRate.toFixed(2)}%`);
    console.log(`   Average Response Time: ${analysisReport.averageResponseTime.toFixed(2)}ms`);
    console.log(`   Critical Errors: ${analysisReport.criticalErrors.length}`);
    console.log(`   Communication Patterns: ${analysisReport.communicationPatterns.length}`);
    console.log(`   Recommendations: ${analysisReport.recommendations.length}`);
  }
});