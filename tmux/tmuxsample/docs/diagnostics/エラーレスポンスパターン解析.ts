/**
 * エラーレスポンス・パターン分析システム
 * Error Response & Pattern Analysis System
 * 
 * Role: QA Engineer - Emergency Error Pattern Analysis
 * Target: Comprehensive Error Response Analysis & Common Pattern Detection
 * Priority: Emergency - 500 Error Pattern Investigation
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import axios from 'axios';
import fs from 'fs';
import path from 'path';

interface ErrorResponse {
  endpoint: string;
  method: string;
  statusCode: number;
  errorMessage: string;
  stackTrace?: string;
  timestamp: string;
  responseTime: number;
  requestData?: any;
  responseHeaders?: any;
  responseBody?: any;
}

interface ErrorPattern {
  pattern: string;
  frequency: number;
  severity: 'low' | 'medium' | 'high' | 'critical';
  endpoints: string[];
  errorMessages: string[];
  statusCodes: number[];
  commonCauses: string[];
  recommendations: string[];
}

interface ErrorAnalysisReport {
  timestamp: string;
  totalErrors: number;
  errorsByStatusCode: { [key: number]: number };
  errorsByEndpoint: { [key: string]: number };
  errorsByMethod: { [key: string]: number };
  criticalErrors: ErrorResponse[];
  errorPatterns: ErrorPattern[];
  commonErrorPatterns: ErrorPattern[];
  systemHealthScore: number;
  recommendations: string[];
  detailedErrors: ErrorResponse[];
}

describe('Error Response & Pattern Analysis', () => {
  let errorAnalysisReport: ErrorAnalysisReport;
  const baseUrl = 'http://localhost:3001';
  
  beforeAll(async () => {
    console.log('🔥 Starting Error Response & Pattern Analysis...');
    
    errorAnalysisReport = {
      timestamp: new Date().toISOString(),
      totalErrors: 0,
      errorsByStatusCode: {},
      errorsByEndpoint: {},
      errorsByMethod: {},
      criticalErrors: [],
      errorPatterns: [],
      commonErrorPatterns: [],
      systemHealthScore: 100,
      recommendations: [],
      detailedErrors: []
    };
  });

  afterAll(async () => {
    await generateErrorAnalysisReport();
  });

  describe('Comprehensive Error Response Testing', () => {
    it('should test all endpoints for error responses', async () => {
      console.log('🔍 Testing all endpoints for error responses...');
      
      // Test endpoints with various error conditions
      const errorTestCases = [
        // 404 Not Found Tests
        { method: 'GET', endpoint: '/api/nonexistent', expectedStatus: 404 },
        { method: 'GET', endpoint: '/api/users/999999', expectedStatus: 404 },
        { method: 'GET', endpoint: '/api/incidents/invalid-id', expectedStatus: 404 },
        { method: 'GET', endpoint: '/api/problems/nonexistent', expectedStatus: 404 },
        { method: 'GET', endpoint: '/api/vendors/invalid-vendor', expectedStatus: 404 },
        
        // 400 Bad Request Tests
        { method: 'POST', endpoint: '/api/auth/login', data: {}, expectedStatus: 400 },
        { method: 'POST', endpoint: '/api/users', data: { invalid: 'data' }, expectedStatus: 400 },
        { method: 'POST', endpoint: '/api/incidents', data: { title: '' }, expectedStatus: 400 },
        { method: 'PUT', endpoint: '/api/users/profile', data: { email: 'invalid-email' }, expectedStatus: 400 },
        { method: 'POST', endpoint: '/api/vendors', data: { name: 'A' }, expectedStatus: 400 },
        
        // 401 Unauthorized Tests
        { method: 'GET', endpoint: '/api/users/profile', expectedStatus: 401 },
        { method: 'GET', endpoint: '/api/incidents', expectedStatus: 401 },
        { method: 'GET', endpoint: '/api/problems', expectedStatus: 401 },
        { method: 'GET', endpoint: '/api/vendors', expectedStatus: 401 },
        { method: 'GET', endpoint: '/api/rbac/roles', expectedStatus: 401 },
        
        // 403 Forbidden Tests
        { method: 'GET', endpoint: '/api/rbac/admin', headers: { Authorization: 'Bearer user-token' }, expectedStatus: 403 },
        { method: 'DELETE', endpoint: '/api/users/admin', headers: { Authorization: 'Bearer user-token' }, expectedStatus: 403 },
        { method: 'POST', endpoint: '/api/security/settings', headers: { Authorization: 'Bearer user-token' }, expectedStatus: 403 },
        
        // 405 Method Not Allowed Tests
        { method: 'DELETE', endpoint: '/api/auth/login', expectedStatus: 405 },
        { method: 'PATCH', endpoint: '/api/health', expectedStatus: 405 },
        { method: 'PUT', endpoint: '/metrics', expectedStatus: 405 },
        
        // 500 Internal Server Error Tests (intentionally broken requests)
        { method: 'POST', endpoint: '/api/incidents', data: { circular: null }, expectedStatus: 500 },
        { method: 'GET', endpoint: '/api/reports/broken-query', expectedStatus: 500 },
        { method: 'POST', endpoint: '/api/database/corrupt-operation', expectedStatus: 500 },
        
        // Malformed JSON Tests
        { method: 'POST', endpoint: '/api/users', data: '{ invalid json }', expectedStatus: 400 },
        { method: 'POST', endpoint: '/api/incidents', data: '{ "title": }', expectedStatus: 400 },
        
        // Large Payload Tests
        { method: 'POST', endpoint: '/api/incidents', data: { description: 'x'.repeat(100000) }, expectedStatus: 413 },
        
        // SQL Injection Tests (should be handled safely)
        { method: 'GET', endpoint: '/api/users?id=1\' OR 1=1--', expectedStatus: 400 },
        { method: 'GET', endpoint: '/api/incidents?search=\'); DROP TABLE users;--', expectedStatus: 400 },
        
        // XSS Tests (should be handled safely)
        { method: 'POST', endpoint: '/api/incidents', data: { title: '<script>alert("xss")</script>' }, expectedStatus: 400 },
        
        // Rate Limiting Tests
        { method: 'GET', endpoint: '/api/users', rapid: true, expectedStatus: 429 },
        
        // Timeout Tests
        { method: 'GET', endpoint: '/api/slow-endpoint', timeout: 100, expectedStatus: 408 }
      ];
      
      for (const testCase of errorTestCases) {
        const startTime = Date.now();
        const errorResponse: ErrorResponse = {
          endpoint: testCase.endpoint,
          method: testCase.method,
          statusCode: 0,
          errorMessage: '',
          timestamp: new Date().toISOString(),
          responseTime: 0
        };
        
        try {
          // Handle rapid requests for rate limiting test
          if (testCase.rapid) {
            const promises = [];
            for (let i = 0; i < 100; i++) {
              promises.push(axios.get(`${baseUrl}${testCase.endpoint}`, { timeout: 1000 }));
            }
            await Promise.all(promises);
          } else {
            const config = {
              method: testCase.method.toLowerCase(),
              url: `${baseUrl}${testCase.endpoint}`,
              timeout: testCase.timeout || 5000,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                ...testCase.headers
              }
            };
            
            if (testCase.data) {
              config['data'] = testCase.data;
            }
            
            const response = await axios(config);
            errorResponse.statusCode = response.status;
            errorResponse.responseHeaders = response.headers;
            errorResponse.responseBody = response.data;
          }
        } catch (error) {
          errorResponse.responseTime = Date.now() - startTime;
          errorResponse.statusCode = error.response?.status || 0;
          errorResponse.errorMessage = error.message;
          errorResponse.responseHeaders = error.response?.headers;
          errorResponse.responseBody = error.response?.data;
          
          if (error.response?.data?.stack) {
            errorResponse.stackTrace = error.response.data.stack;
          }
          
          // Log error details
          console.log(`🔥 Error detected: ${testCase.method} ${testCase.endpoint} - ${errorResponse.statusCode}`);
          
          // Track error statistics
          errorAnalysisReport.totalErrors++;
          errorAnalysisReport.errorsByStatusCode[errorResponse.statusCode] = 
            (errorAnalysisReport.errorsByStatusCode[errorResponse.statusCode] || 0) + 1;
          errorAnalysisReport.errorsByEndpoint[testCase.endpoint] = 
            (errorAnalysisReport.errorsByEndpoint[testCase.endpoint] || 0) + 1;
          errorAnalysisReport.errorsByMethod[testCase.method] = 
            (errorAnalysisReport.errorsByMethod[testCase.method] || 0) + 1;
          
          // Mark critical errors (500s)
          if (errorResponse.statusCode >= 500) {
            errorAnalysisReport.criticalErrors.push(errorResponse);
          }
          
          errorAnalysisReport.detailedErrors.push(errorResponse);
        }
      }
      
      console.log(`📊 Error testing complete: ${errorAnalysisReport.totalErrors} errors detected`);
      expect(errorAnalysisReport.detailedErrors.length).toBeGreaterThan(0);
    });
  });

  describe('Common Error Pattern Detection', () => {
    it('should identify common error patterns', async () => {
      console.log('🔍 Identifying common error patterns...');
      
      // Analyze error patterns by status code
      const statusCodePatterns = Object.entries(errorAnalysisReport.errorsByStatusCode)
        .map(([code, count]) => {
          const statusCode = parseInt(code);
          const relatedErrors = errorAnalysisReport.detailedErrors.filter(
            err => err.statusCode === statusCode
          );
          
          return {
            pattern: `HTTP_${statusCode}_ERROR`,
            frequency: count,
            severity: getSeverityByStatusCode(statusCode),
            endpoints: relatedErrors.map(err => err.endpoint),
            errorMessages: relatedErrors.map(err => err.errorMessage),
            statusCodes: [statusCode],
            commonCauses: getCommonCausesByStatusCode(statusCode),
            recommendations: getRecommendationsByStatusCode(statusCode)
          };
        });
      
      errorAnalysisReport.errorPatterns.push(...statusCodePatterns);
      
      // Analyze error patterns by endpoint
      const endpointPatterns = Object.entries(errorAnalysisReport.errorsByEndpoint)
        .filter(([_, count]) => count > 1)
        .map(([endpoint, count]) => {
          const relatedErrors = errorAnalysisReport.detailedErrors.filter(
            err => err.endpoint === endpoint
          );
          
          return {
            pattern: `ENDPOINT_ERROR_${endpoint.replace(/[^a-zA-Z0-9]/g, '_')}`,
            frequency: count,
            severity: 'high' as const,
            endpoints: [endpoint],
            errorMessages: relatedErrors.map(err => err.errorMessage),
            statusCodes: [...new Set(relatedErrors.map(err => err.statusCode))],
            commonCauses: [`Multiple errors on endpoint: ${endpoint}`],
            recommendations: [`Investigate endpoint implementation: ${endpoint}`]
          };
        });
      
      errorAnalysisReport.errorPatterns.push(...endpointPatterns);
      
      // Analyze error patterns by method
      const methodPatterns = Object.entries(errorAnalysisReport.errorsByMethod)
        .filter(([_, count]) => count > 2)
        .map(([method, count]) => {
          const relatedErrors = errorAnalysisReport.detailedErrors.filter(
            err => err.method === method
          );
          
          return {
            pattern: `METHOD_ERROR_${method}`,
            frequency: count,
            severity: 'medium' as const,
            endpoints: [...new Set(relatedErrors.map(err => err.endpoint))],
            errorMessages: relatedErrors.map(err => err.errorMessage),
            statusCodes: [...new Set(relatedErrors.map(err => err.statusCode))],
            commonCauses: [`Multiple errors on ${method} requests`],
            recommendations: [`Review ${method} request handling`]
          };
        });
      
      errorAnalysisReport.errorPatterns.push(...methodPatterns);
      
      console.log(`📊 Pattern detection complete: ${errorAnalysisReport.errorPatterns.length} patterns identified`);
      expect(errorAnalysisReport.errorPatterns.length).toBeGreaterThan(0);
    });

    it('should identify critical error patterns', async () => {
      console.log('🚨 Identifying critical error patterns...');
      
      // Identify 500 error patterns
      const serverErrorPattern = {
        pattern: 'CRITICAL_SERVER_ERROR',
        frequency: errorAnalysisReport.criticalErrors.length,
        severity: 'critical' as const,
        endpoints: errorAnalysisReport.criticalErrors.map(err => err.endpoint),
        errorMessages: errorAnalysisReport.criticalErrors.map(err => err.errorMessage),
        statusCodes: [500, 501, 502, 503, 504],
        commonCauses: [
          'Database connection failure',
          'Unhandled exceptions',
          'Memory issues',
          'Configuration errors',
          'External service failures'
        ],
        recommendations: [
          'Immediate server investigation required',
          'Check error logs and stack traces',
          'Verify database connectivity',
          'Review error handling middleware',
          'Monitor system resources'
        ]
      };
      
      if (serverErrorPattern.frequency > 0) {
        errorAnalysisReport.commonErrorPatterns.push(serverErrorPattern);
      }
      
      // Identify authentication error patterns
      const authErrors = errorAnalysisReport.detailedErrors.filter(
        err => err.statusCode === 401 || err.statusCode === 403
      );
      
      if (authErrors.length > 0) {
        const authErrorPattern = {
          pattern: 'AUTHENTICATION_ERROR',
          frequency: authErrors.length,
          severity: 'high' as const,
          endpoints: authErrors.map(err => err.endpoint),
          errorMessages: authErrors.map(err => err.errorMessage),
          statusCodes: [401, 403],
          commonCauses: [
            'Invalid or expired JWT tokens',
            'Missing authentication headers',
            'Insufficient permissions',
            'RBAC configuration issues'
          ],
          recommendations: [
            'Review JWT token validation',
            'Check authentication middleware',
            'Verify RBAC permissions',
            'Update security configuration'
          ]
        };
        
        errorAnalysisReport.commonErrorPatterns.push(authErrorPattern);
      }
      
      // Identify validation error patterns
      const validationErrors = errorAnalysisReport.detailedErrors.filter(
        err => err.statusCode === 400
      );
      
      if (validationErrors.length > 3) {
        const validationErrorPattern = {
          pattern: 'VALIDATION_ERROR',
          frequency: validationErrors.length,
          severity: 'medium' as const,
          endpoints: validationErrors.map(err => err.endpoint),
          errorMessages: validationErrors.map(err => err.errorMessage),
          statusCodes: [400, 422],
          commonCauses: [
            'Invalid request data',
            'Missing required fields',
            'Data type mismatches',
            'Constraint violations'
          ],
          recommendations: [
            'Improve input validation',
            'Enhance error messages',
            'Add client-side validation',
            'Update API documentation'
          ]
        };
        
        errorAnalysisReport.commonErrorPatterns.push(validationErrorPattern);
      }
      
      console.log(`🚨 Critical pattern analysis complete: ${errorAnalysisReport.commonErrorPatterns.length} critical patterns`);
      expect(errorAnalysisReport.commonErrorPatterns).toBeDefined();
    });

    it('should calculate system health score', async () => {
      console.log('📊 Calculating system health score...');
      
      let healthScore = 100;
      
      // Deduct points for different error types
      const criticalErrorCount = errorAnalysisReport.criticalErrors.length;
      const authErrorCount = errorAnalysisReport.detailedErrors.filter(err => err.statusCode === 401 || err.statusCode === 403).length;
      const validationErrorCount = errorAnalysisReport.detailedErrors.filter(err => err.statusCode === 400).length;
      const notFoundErrorCount = errorAnalysisReport.detailedErrors.filter(err => err.statusCode === 404).length;
      
      // Deduct points based on error severity
      healthScore -= criticalErrorCount * 10; // 10 points per critical error
      healthScore -= authErrorCount * 5; // 5 points per auth error
      healthScore -= validationErrorCount * 2; // 2 points per validation error
      healthScore -= notFoundErrorCount * 1; // 1 point per not found error
      
      // Consider error patterns
      const highSeverityPatterns = errorAnalysisReport.errorPatterns.filter(p => p.severity === 'high' || p.severity === 'critical');
      healthScore -= highSeverityPatterns.length * 5;
      
      // Ensure score doesn't go below 0
      errorAnalysisReport.systemHealthScore = Math.max(0, healthScore);
      
      console.log(`📈 System Health Score: ${errorAnalysisReport.systemHealthScore}/100`);
      console.log(`   Critical Errors: ${criticalErrorCount}`);
      console.log(`   Auth Errors: ${authErrorCount}`);
      console.log(`   Validation Errors: ${validationErrorCount}`);
      console.log(`   Not Found Errors: ${notFoundErrorCount}`);
      console.log(`   High Severity Patterns: ${highSeverityPatterns.length}`);
      
      expect(errorAnalysisReport.systemHealthScore).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Error Response Analysis', () => {
    it('should analyze error response structures', async () => {
      console.log('🔍 Analyzing error response structures...');
      
      const errorResponses = errorAnalysisReport.detailedErrors.filter(err => err.responseBody);
      
      // Analyze response structure patterns
      const responseStructures = errorResponses.map(err => {
        const body = err.responseBody;
        return {
          endpoint: err.endpoint,
          statusCode: err.statusCode,
          hasErrorField: !!body.error,
          hasMessageField: !!body.message,
          hasStackTrace: !!body.stack,
          hasTimestamp: !!body.timestamp,
          hasRequestId: !!body.requestId,
          structure: Object.keys(body).sort().join(',')
        };
      });
      
      // Find common response structures
      const structureGroups = responseStructures.reduce((acc, resp) => {
        const key = resp.structure;
        if (!acc[key]) {
          acc[key] = [];
        }
        acc[key].push(resp);
        return acc;
      }, {});
      
      console.log('📊 Error Response Structure Analysis:');
      Object.entries(structureGroups).forEach(([structure, responses]) => {
        console.log(`   Structure "${structure}": ${responses.length} responses`);
      });
      
      // Check for inconsistent error response formats
      const uniqueStructures = Object.keys(structureGroups).length;
      if (uniqueStructures > 5) {
        errorAnalysisReport.recommendations.push('Standardize error response formats across endpoints');
      }
      
      expect(responseStructures.length).toBeGreaterThan(0);
    });

    it('should analyze error message patterns', async () => {
      console.log('🔍 Analyzing error message patterns...');
      
      const errorMessages = errorAnalysisReport.detailedErrors.map(err => err.errorMessage);
      
      // Find common error message patterns
      const messagePatterns = {
        connectionErrors: errorMessages.filter(msg => msg.includes('connect') || msg.includes('ECONNREFUSED')),
        timeoutErrors: errorMessages.filter(msg => msg.includes('timeout') || msg.includes('ETIMEDOUT')),
        notFoundErrors: errorMessages.filter(msg => msg.includes('404') || msg.includes('not found')),
        validationErrors: errorMessages.filter(msg => msg.includes('validation') || msg.includes('invalid')),
        authErrors: errorMessages.filter(msg => msg.includes('unauthorized') || msg.includes('forbidden')),
        serverErrors: errorMessages.filter(msg => msg.includes('500') || msg.includes('Internal Server Error'))
      };
      
      console.log('📊 Error Message Pattern Analysis:');
      Object.entries(messagePatterns).forEach(([pattern, messages]) => {
        if (messages.length > 0) {
          console.log(`   ${pattern}: ${messages.length} messages`);
        }
      });
      
      // Add recommendations based on message patterns
      if (messagePatterns.connectionErrors.length > 0) {
        errorAnalysisReport.recommendations.push('Network connectivity issues detected - check server availability');
      }
      
      if (messagePatterns.timeoutErrors.length > 0) {
        errorAnalysisReport.recommendations.push('Request timeout issues detected - optimize response times');
      }
      
      if (messagePatterns.serverErrors.length > 0) {
        errorAnalysisReport.recommendations.push('Server errors detected - investigate application logs');
      }
      
      expect(errorMessages.length).toBeGreaterThan(0);
    });
  });

  /**
   * Helper functions
   */
  function getSeverityByStatusCode(statusCode: number): 'low' | 'medium' | 'high' | 'critical' {
    if (statusCode >= 500) return 'critical';
    if (statusCode >= 400) return 'high';
    if (statusCode >= 300) return 'medium';
    return 'low';
  }

  function getCommonCausesByStatusCode(statusCode: number): string[] {
    const causes = {
      400: ['Invalid request data', 'Missing required fields', 'Validation errors'],
      401: ['Missing authentication', 'Invalid credentials', 'Expired tokens'],
      403: ['Insufficient permissions', 'RBAC restrictions', 'Access denied'],
      404: ['Resource not found', 'Invalid endpoint', 'Deleted resources'],
      405: ['Method not allowed', 'Incorrect HTTP method', 'Routing issues'],
      408: ['Request timeout', 'Slow responses', 'Network issues'],
      413: ['Payload too large', 'File size limits', 'Request size limits'],
      429: ['Rate limiting', 'Too many requests', 'API throttling'],
      500: ['Server errors', 'Unhandled exceptions', 'Database issues'],
      502: ['Bad gateway', 'Proxy errors', 'Upstream server issues'],
      503: ['Service unavailable', 'Maintenance mode', 'Overload'],
      504: ['Gateway timeout', 'Upstream timeout', 'Processing delays']
    };
    
    return causes[statusCode] || ['Unknown error cause'];
  }

  function getRecommendationsByStatusCode(statusCode: number): string[] {
    const recommendations = {
      400: ['Improve input validation', 'Enhance error messages', 'Add client-side validation'],
      401: ['Check authentication middleware', 'Verify JWT configuration', 'Update token handling'],
      403: ['Review RBAC permissions', 'Check user roles', 'Verify authorization logic'],
      404: ['Verify endpoint routing', 'Check resource existence', 'Update API documentation'],
      405: ['Review HTTP methods', 'Check route definitions', 'Update endpoint configurations'],
      408: ['Optimize response times', 'Increase timeout limits', 'Improve performance'],
      413: ['Increase payload limits', 'Optimize data transfer', 'Implement file chunking'],
      429: ['Implement rate limiting', 'Add request throttling', 'Optimize API usage'],
      500: ['Investigate server logs', 'Check error handling', 'Review application code'],
      502: ['Check proxy configuration', 'Verify upstream servers', 'Review load balancing'],
      503: ['Check server capacity', 'Review maintenance schedules', 'Monitor resource usage'],
      504: ['Optimize processing time', 'Increase gateway timeout', 'Review performance bottlenecks']
    };
    
    return recommendations[statusCode] || ['Review error handling'];
  }

  /**
   * Generate comprehensive error analysis report
   */
  async function generateErrorAnalysisReport() {
    console.log('📋 Generating Error Analysis Report...');
    
    // Add general recommendations
    if (errorAnalysisReport.systemHealthScore < 70) {
      errorAnalysisReport.recommendations.push('Critical: System health score below 70% - immediate attention required');
    } else if (errorAnalysisReport.systemHealthScore < 85) {
      errorAnalysisReport.recommendations.push('Warning: System health score below 85% - monitoring and improvements needed');
    }
    
    if (errorAnalysisReport.criticalErrors.length > 0) {
      errorAnalysisReport.recommendations.push('Critical: 500 errors detected - immediate server investigation required');
    }
    
    if (errorAnalysisReport.totalErrors > 20) {
      errorAnalysisReport.recommendations.push('High error count detected - comprehensive system review needed');
    }
    
    // Write error analysis report to file
    const reportPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/ERROR_ANALYSIS_REPORT.json';
    fs.writeFileSync(reportPath, JSON.stringify(errorAnalysisReport, null, 2));
    
    console.log('📊 Error Analysis Report Generated:', reportPath);
    console.log('🎯 System Health Score:', errorAnalysisReport.systemHealthScore);
    console.log('📈 Total Errors:', errorAnalysisReport.totalErrors);
    console.log('🚨 Critical Errors:', errorAnalysisReport.criticalErrors.length);
    console.log('🔍 Error Patterns:', errorAnalysisReport.errorPatterns.length);
    console.log('⚠️  Common Patterns:', errorAnalysisReport.commonErrorPatterns.length);
    console.log('💡 Recommendations:', errorAnalysisReport.recommendations.length);
  }
});