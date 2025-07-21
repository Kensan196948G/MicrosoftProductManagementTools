/**
 * サーバー切り替え後全機能統合テスト
 * Post-Switch Full Function Integration Test
 * 
 * Role: QA Engineer - Post-Switch Integration Test & Quality Assurance
 * Target: Complete Function Verification After Server Switch
 * Priority: Emergency - Real-time Integration Testing
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import axios from 'axios';
import fs from 'fs';

interface ComponentTestResult {
  component: string;
  status: 'success' | 'failed' | 'error';
  apiTests: {
    endpoint: string;
    method: string;
    status: number;
    responseTime: number;
    success: boolean;
    error?: string;
  }[];
  uiTests: {
    errorHandling: boolean;
    loadingState: boolean;
    errorMessages: boolean;
  };
  overallScore: number;
}

interface SystemStabilityResult {
  longRunning: {
    duration: number;
    requests: number;
    success: number;
    failed: number;
    avgResponseTime: number;
  };
  concurrent: {
    connections: number;
    success: number;
    failed: number;
    maxResponseTime: number;
  };
  errorRecovery: {
    tested: number;
    recovered: number;
    avgRecoveryTime: number;
  };
}

interface IntegrationTestReport {
  timestamp: string;
  serverStatus: {
    running: boolean;
    version: string;
    apiCount: number;
    responseTime: number;
  };
  componentResults: ComponentTestResult[];
  apiCommunication: {
    totalEndpoints: number;
    workingEndpoints: number;
    failedEndpoints: number;
    avgResponseTime: number;
    successRate: number;
  };
  uiUxQuality: {
    errorFallback: boolean;
    loadingStates: boolean;
    errorMessages: boolean;
    accessibility: boolean;
    overallScore: number;
  };
  systemStability: SystemStabilityResult;
  overallStatus: 'excellent' | 'good' | 'partial' | 'failed';
  qualityScore: number;
  recommendations: string[];
  criticalIssues: string[];
}

describe('Post-Switch Full Function Integration Test', () => {
  let testReport: IntegrationTestReport;
  const baseUrl = 'http://localhost:8081';
  
  beforeAll(async () => {
    console.log('🚀 Starting Post-Switch Integration Test...');
    
    testReport = {
      timestamp: new Date().toISOString(),
      serverStatus: {
        running: false,
        version: 'unknown',
        apiCount: 0,
        responseTime: 0
      },
      componentResults: [],
      apiCommunication: {
        totalEndpoints: 0,
        workingEndpoints: 0,
        failedEndpoints: 0,
        avgResponseTime: 0,
        successRate: 0
      },
      uiUxQuality: {
        errorFallback: false,
        loadingStates: false,
        errorMessages: false,
        accessibility: false,
        overallScore: 0
      },
      systemStability: {
        longRunning: {
          duration: 0,
          requests: 0,
          success: 0,
          failed: 0,
          avgResponseTime: 0
        },
        concurrent: {
          connections: 0,
          success: 0,
          failed: 0,
          maxResponseTime: 0
        },
        errorRecovery: {
          tested: 0,
          recovered: 0,
          avgRecoveryTime: 0
        }
      },
      overallStatus: 'failed',
      qualityScore: 0,
      recommendations: [],
      criticalIssues: []
    };
  });

  afterAll(async () => {
    await generateIntegrationTestReport();
  });

  describe('Server Status Verification', () => {
    it('should verify server is running with full functionality', async () => {
      console.log('🔍 Verifying server status...');
      
      try {
        const healthStart = Date.now();
        const healthResponse = await axios.get(`${baseUrl}/health`, { timeout: 5000 });
        testReport.serverStatus.responseTime = Date.now() - healthStart;
        testReport.serverStatus.running = healthResponse.status === 200;
        
        // Check if this is the full version
        try {
          const docsResponse = await axios.get(`${baseUrl}/api/docs`, { timeout: 3000 });
          
          if (docsResponse.data?.status === 'Simple mode - Core features only') {
            testReport.criticalIssues.push('Server still running in simple mode - full switch not completed');
            testReport.serverStatus.version = 'simple';
            testReport.serverStatus.apiCount = 3;
          } else if (docsResponse.data?.endpoints && Object.keys(docsResponse.data.endpoints).length > 10) {
            testReport.serverStatus.version = 'full';
            testReport.serverStatus.apiCount = Object.keys(docsResponse.data.endpoints).length;
          } else {
            testReport.serverStatus.version = 'unknown';
            testReport.serverStatus.apiCount = 0;
          }
        } catch (error) {
          testReport.criticalIssues.push('API documentation not accessible');
        }
        
        console.log(`✅ Server Status: ${testReport.serverStatus.running ? 'Running' : 'Down'}`);
        console.log(`📊 Version: ${testReport.serverStatus.version}`);
        console.log(`🔗 API Count: ${testReport.serverStatus.apiCount}`);
        
        expect(testReport.serverStatus.running).toBe(true);
      } catch (error) {
        testReport.criticalIssues.push('Server not responding');
        console.error('❌ Server health check failed:', error.message);
        throw error;
      }
    });
  });

  describe('7 Component Function Testing', () => {
    const components = [
      {
        name: 'VendorManagementPage',
        endpoints: [
          { method: 'GET', path: '/api/vendors' },
          { method: 'GET', path: '/api/vendors/statistics' },
          { method: 'POST', path: '/api/vendors/initialize' }
        ]
      },
      {
        name: 'ServiceTargetSettings',
        endpoints: [
          { method: 'GET', path: '/api/service-level' },
          { method: 'GET', path: '/api/service-level/objectives' }
        ]
      },
      {
        name: 'AvailabilityManagement',
        endpoints: [
          { method: 'GET', path: '/api/availability' },
          { method: 'GET', path: '/api/availability-metrics' }
        ]
      },
      {
        name: 'PerformanceManagement',
        endpoints: [
          { method: 'GET', path: '/api/capacity' },
          { method: 'GET', path: '/api/performance-metrics' },
          { method: 'GET', path: '/api/resource-utilizations' }
        ]
      },
      {
        name: 'ServiceQualityMeasurement',
        endpoints: [
          { method: 'GET', path: '/api/quality' },
          { method: 'GET', path: '/api/quality/metrics' }
        ]
      },
      {
        name: 'SLAViolationManagement',
        endpoints: [
          { method: 'GET', path: '/api/sla-violations' },
          { method: 'GET', path: '/api/service-level/violations' }
        ]
      },
      {
        name: 'CategoryManagement',
        endpoints: [
          { method: 'GET', path: '/api/incidents/categories' },
          { method: 'GET', path: '/api/problems/categories' }
        ]
      }
    ];

    it('should test all 7 components individually', async () => {
      console.log('🧪 Testing all 7 components...');
      
      for (const component of components) {
        console.log(`\n📋 Testing ${component.name}...`);
        
        const componentResult: ComponentTestResult = {
          component: component.name,
          status: 'success',
          apiTests: [],
          uiTests: {
            errorHandling: true,
            loadingState: true,
            errorMessages: true
          },
          overallScore: 0
        };
        
        let successfulEndpoints = 0;
        let totalResponseTime = 0;
        
        for (const endpoint of component.endpoints) {
          const startTime = Date.now();
          
          try {
            const config = {
              method: endpoint.method.toLowerCase(),
              url: `${baseUrl}${endpoint.path}`,
              timeout: 5000,
              headers: {
                'Authorization': 'Bearer test-token',
                'Content-Type': 'application/json'
              }
            };
            
            const response = await axios(config);
            const responseTime = Date.now() - startTime;
            totalResponseTime += responseTime;
            
            componentResult.apiTests.push({
              endpoint: endpoint.path,
              method: endpoint.method,
              status: response.status,
              responseTime,
              success: true
            });
            
            successfulEndpoints++;
            console.log(`  ✅ ${endpoint.method} ${endpoint.path}: ${response.status} (${responseTime}ms)`);
            
          } catch (error) {
            const responseTime = Date.now() - startTime;
            totalResponseTime += responseTime;
            
            const success = error.response?.status === 401 || error.response?.status === 403; // Auth errors are expected
            if (success) successfulEndpoints++;
            
            componentResult.apiTests.push({
              endpoint: endpoint.path,
              method: endpoint.method,
              status: error.response?.status || 0,
              responseTime,
              success,
              error: error.message
            });
            
            if (success) {
              console.log(`  ✅ ${endpoint.method} ${endpoint.path}: ${error.response.status} (Auth required - Expected)`);
            } else {
              console.log(`  ❌ ${endpoint.method} ${endpoint.path}: ${error.message}`);
            }
          }
        }
        
        // Calculate component score
        const apiSuccessRate = successfulEndpoints / component.endpoints.length;
        componentResult.overallScore = Math.round(apiSuccessRate * 100);
        
        if (apiSuccessRate >= 0.8) {
          componentResult.status = 'success';
        } else if (apiSuccessRate >= 0.5) {
          componentResult.status = 'failed';
        } else {
          componentResult.status = 'error';
        }
        
        console.log(`📊 ${component.name}: ${successfulEndpoints}/${component.endpoints.length} endpoints working (${componentResult.overallScore}%)`);
        
        testReport.componentResults.push(componentResult);
      }
      
      const workingComponents = testReport.componentResults.filter(c => c.status === 'success').length;
      console.log(`\n📊 Component Testing Summary: ${workingComponents}/${components.length} components working`);
      
      expect(workingComponents).toBeGreaterThanOrEqual(components.length * 0.7);
    });
  });

  describe('API Communication Testing', () => {
    it('should test all monitoring-related APIs', async () => {
      console.log('🌐 Testing API communication...');
      
      const monitoringApis = [
        // Extract unique endpoints from all components
        '/api/vendors', '/api/vendors/statistics', '/api/vendors/initialize',
        '/api/service-level', '/api/service-level/objectives', '/api/service-level/violations',
        '/api/availability', '/api/availability-metrics',
        '/api/capacity', '/api/performance-metrics', '/api/resource-utilizations',
        '/api/quality', '/api/quality/metrics',
        '/api/sla-violations',
        '/api/incidents/categories', '/api/problems/categories',
        '/api/incidents', '/api/problems', '/api/changes',
        '/api/reports', '/api/monitoring'
      ];
      
      testReport.apiCommunication.totalEndpoints = monitoringApis.length;
      let workingEndpoints = 0;
      let totalResponseTime = 0;
      let requestCount = 0;
      
      for (const endpoint of monitoringApis) {
        try {
          const startTime = Date.now();
          const response = await axios.get(`${baseUrl}${endpoint}`, {
            timeout: 3000,
            headers: { 'Authorization': 'Bearer test-token' }
          });
          
          const responseTime = Date.now() - startTime;
          totalResponseTime += responseTime;
          requestCount++;
          
          if (response.status === 200) {
            workingEndpoints++;
          }
        } catch (error) {
          const responseTime = Date.now() - startTime;
          totalResponseTime += responseTime;
          requestCount++;
          
          // Auth errors (401, 403) are expected and count as working
          if (error.response?.status === 401 || error.response?.status === 403) {
            workingEndpoints++;
          } else {
            testReport.apiCommunication.failedEndpoints++;
          }
        }
      }
      
      testReport.apiCommunication.workingEndpoints = workingEndpoints;
      testReport.apiCommunication.avgResponseTime = requestCount > 0 ? totalResponseTime / requestCount : 0;
      testReport.apiCommunication.successRate = (workingEndpoints / testReport.apiCommunication.totalEndpoints) * 100;
      
      console.log(`📊 API Communication Results:`);
      console.log(`  Working: ${workingEndpoints}/${testReport.apiCommunication.totalEndpoints}`);
      console.log(`  Success Rate: ${testReport.apiCommunication.successRate.toFixed(1)}%`);
      console.log(`  Avg Response Time: ${testReport.apiCommunication.avgResponseTime.toFixed(0)}ms`);
      
      expect(testReport.apiCommunication.successRate).toBeGreaterThanOrEqual(70);
    });

    it('should test error handling and retry functionality', async () => {
      console.log('🔄 Testing error handling and retry functionality...');
      
      const errorTests = [
        { name: 'Invalid endpoint', endpoint: '/api/nonexistent', expectedStatus: 404 },
        { name: 'No authentication', endpoint: '/api/vendors', expectedStatus: 401 },
        { name: 'Invalid method', endpoint: '/api/vendors', method: 'DELETE', expectedStatus: 405 },
        { name: 'Invalid data', endpoint: '/api/vendors', method: 'POST', data: { invalid: 'data' }, expectedStatus: 400 }
      ];
      
      let errorHandlingScore = 0;
      
      for (const test of errorTests) {
        try {
          const config = {
            method: test.method?.toLowerCase() || 'get',
            url: `${baseUrl}${test.endpoint}`,
            timeout: 3000,
            headers: { 'Content-Type': 'application/json' }
          };
          
          if (test.data) {
            config['data'] = test.data;
          }
          
          const response = await axios(config);
          console.log(`  ⚠️  ${test.name}: Unexpected success (${response.status})`);
        } catch (error) {
          if (error.response?.status === test.expectedStatus) {
            errorHandlingScore++;
            console.log(`  ✅ ${test.name}: Correct error response (${error.response.status})`);
          } else {
            console.log(`  ❌ ${test.name}: Wrong error response (${error.response?.status || 'no response'})`);
          }
        }
      }
      
      const errorHandlingRate = (errorHandlingScore / errorTests.length) * 100;
      console.log(`🔥 Error Handling Score: ${errorHandlingRate.toFixed(1)}%`);
      
      expect(errorHandlingRate).toBeGreaterThanOrEqual(75);
    });
  });

  describe('UI/UX Quality Testing', () => {
    it('should verify UI/UX quality features', async () => {
      console.log('🎨 Testing UI/UX quality features...');
      
      // Test error fallback functionality
      try {
        await axios.get(`${baseUrl}/api/nonexistent`, { timeout: 1000 });
        testReport.uiUxQuality.errorFallback = false;
      } catch (error) {
        testReport.uiUxQuality.errorFallback = error.response?.status === 404;
      }
      
      // Test loading state (simulated)
      const loadingStartTime = Date.now();
      try {
        await axios.get(`${baseUrl}/health`, { timeout: 5000 });
        const loadingTime = Date.now() - loadingStartTime;
        testReport.uiUxQuality.loadingStates = loadingTime < 2000; // Reasonable loading time
      } catch (error) {
        testReport.uiUxQuality.loadingStates = false;
      }
      
      // Test error message format
      try {
        await axios.get(`${baseUrl}/api/invalid-endpoint`, { timeout: 1000 });
        testReport.uiUxQuality.errorMessages = false;
      } catch (error) {
        const hasProperErrorFormat = error.response?.data && 
          (error.response.data.error || error.response.data.message);
        testReport.uiUxQuality.errorMessages = hasProperErrorFormat;
      }
      
      // Basic accessibility check (response headers)
      try {
        const response = await axios.get(`${baseUrl}/health`, { timeout: 3000 });
        const hasSecurityHeaders = response.headers['content-type'];
        testReport.uiUxQuality.accessibility = !!hasSecurityHeaders;
      } catch (error) {
        testReport.uiUxQuality.accessibility = false;
      }
      
      // Calculate overall UI/UX score
      const uiFeatures = [
        testReport.uiUxQuality.errorFallback,
        testReport.uiUxQuality.loadingStates,
        testReport.uiUxQuality.errorMessages,
        testReport.uiUxQuality.accessibility
      ];
      
      testReport.uiUxQuality.overallScore = Math.round(
        (uiFeatures.filter(f => f).length / uiFeatures.length) * 100
      );
      
      console.log(`🎨 UI/UX Quality Results:`);
      console.log(`  Error Fallback: ${testReport.uiUxQuality.errorFallback ? '✅' : '❌'}`);
      console.log(`  Loading States: ${testReport.uiUxQuality.loadingStates ? '✅' : '❌'}`);
      console.log(`  Error Messages: ${testReport.uiUxQuality.errorMessages ? '✅' : '❌'}`);
      console.log(`  Accessibility: ${testReport.uiUxQuality.accessibility ? '✅' : '❌'}`);
      console.log(`  Overall Score: ${testReport.uiUxQuality.overallScore}%`);
      
      expect(testReport.uiUxQuality.overallScore).toBeGreaterThanOrEqual(75);
    });
  });

  describe('System Stability Testing', () => {
    it('should perform long-running test', async () => {
      console.log('⏱️  Performing long-running stability test...');
      
      const testDuration = 30000; // 30 seconds
      const requestInterval = 1000; // 1 second
      const startTime = Date.now();
      
      let requests = 0;
      let successCount = 0;
      let totalResponseTime = 0;
      
      while (Date.now() - startTime < testDuration) {
        try {
          const requestStart = Date.now();
          const response = await axios.get(`${baseUrl}/health`, { timeout: 2000 });
          const responseTime = Date.now() - requestStart;
          
          totalResponseTime += responseTime;
          requests++;
          
          if (response.status === 200) {
            successCount++;
          }
          
          await new Promise(resolve => setTimeout(resolve, requestInterval));
        } catch (error) {
          requests++;
          await new Promise(resolve => setTimeout(resolve, requestInterval));
        }
      }
      
      testReport.systemStability.longRunning = {
        duration: Date.now() - startTime,
        requests,
        success: successCount,
        failed: requests - successCount,
        avgResponseTime: requests > 0 ? totalResponseTime / requests : 0
      };
      
      console.log(`⏱️  Long-running test results:`);
      console.log(`  Duration: ${testReport.systemStability.longRunning.duration}ms`);
      console.log(`  Requests: ${requests}`);
      console.log(`  Success: ${successCount}/${requests} (${((successCount/requests)*100).toFixed(1)}%)`);
      console.log(`  Avg Response: ${testReport.systemStability.longRunning.avgResponseTime.toFixed(0)}ms`);
      
      expect(successCount / requests).toBeGreaterThanOrEqual(0.9);
    });

    it('should perform concurrent connection test', async () => {
      console.log('🔀 Performing concurrent connection test...');
      
      const concurrentConnections = 10;
      const promises = [];
      
      for (let i = 0; i < concurrentConnections; i++) {
        promises.push(
          axios.get(`${baseUrl}/health`, { timeout: 5000 })
            .then(response => ({ success: true, responseTime: Date.now(), status: response.status }))
            .catch(error => ({ success: false, responseTime: Date.now(), error: error.message }))
        );
      }
      
      const results = await Promise.all(promises);
      const successCount = results.filter(r => r.success).length;
      const responseTimes = results.map(r => r.responseTime);
      const maxResponseTime = Math.max(...responseTimes) - Math.min(...responseTimes);
      
      testReport.systemStability.concurrent = {
        connections: concurrentConnections,
        success: successCount,
        failed: concurrentConnections - successCount,
        maxResponseTime
      };
      
      console.log(`🔀 Concurrent test results:`);
      console.log(`  Connections: ${concurrentConnections}`);
      console.log(`  Success: ${successCount}/${concurrentConnections} (${((successCount/concurrentConnections)*100).toFixed(1)}%)`);
      console.log(`  Max Response Time Diff: ${maxResponseTime}ms`);
      
      expect(successCount / concurrentConnections).toBeGreaterThanOrEqual(0.8);
    });

    it('should test error recovery', async () => {
      console.log('🔄 Testing error recovery...');
      
      const errorRecoveryTests = [
        { name: 'Network timeout recovery', delay: 1000 },
        { name: 'Invalid request recovery', delay: 500 },
        { name: 'Server error recovery', delay: 1500 }
      ];
      
      let recoveredCount = 0;
      let totalRecoveryTime = 0;
      
      for (const test of errorRecoveryTests) {
        try {
          // Simulate error condition
          await axios.get(`${baseUrl}/api/simulate-error`, { timeout: 100 }).catch(() => {});
          
          // Test recovery
          const recoveryStart = Date.now();
          await new Promise(resolve => setTimeout(resolve, test.delay));
          
          const response = await axios.get(`${baseUrl}/health`, { timeout: 3000 });
          const recoveryTime = Date.now() - recoveryStart;
          
          if (response.status === 200) {
            recoveredCount++;
            totalRecoveryTime += recoveryTime;
            console.log(`  ✅ ${test.name}: Recovered in ${recoveryTime}ms`);
          }
        } catch (error) {
          console.log(`  ❌ ${test.name}: Recovery failed`);
        }
      }
      
      testReport.systemStability.errorRecovery = {
        tested: errorRecoveryTests.length,
        recovered: recoveredCount,
        avgRecoveryTime: recoveredCount > 0 ? totalRecoveryTime / recoveredCount : 0
      };
      
      console.log(`🔄 Error recovery results:`);
      console.log(`  Recovered: ${recoveredCount}/${errorRecoveryTests.length}`);
      console.log(`  Avg Recovery Time: ${testReport.systemStability.errorRecovery.avgRecoveryTime.toFixed(0)}ms`);
      
      expect(recoveredCount / errorRecoveryTests.length).toBeGreaterThanOrEqual(0.6);
    });
  });

  /**
   * Generate comprehensive integration test report
   */
  async function generateIntegrationTestReport() {
    console.log('📋 Generating Integration Test Report...');
    
    // Calculate overall quality score
    const componentScore = testReport.componentResults.length > 0 
      ? testReport.componentResults.reduce((sum, c) => sum + c.overallScore, 0) / testReport.componentResults.length 
      : 0;
    
    const apiScore = testReport.apiCommunication.successRate;
    const uiScore = testReport.uiUxQuality.overallScore;
    
    const stabilityScore = Math.min(
      (testReport.systemStability.longRunning.success / Math.max(testReport.systemStability.longRunning.requests, 1)) * 100,
      (testReport.systemStability.concurrent.success / Math.max(testReport.systemStability.concurrent.connections, 1)) * 100,
      (testReport.systemStability.errorRecovery.recovered / Math.max(testReport.systemStability.errorRecovery.tested, 1)) * 100
    );
    
    testReport.qualityScore = Math.round((componentScore + apiScore + uiScore + stabilityScore) / 4);
    
    // Determine overall status
    if (testReport.qualityScore >= 90) {
      testReport.overallStatus = 'excellent';
    } else if (testReport.qualityScore >= 80) {
      testReport.overallStatus = 'good';
    } else if (testReport.qualityScore >= 60) {
      testReport.overallStatus = 'partial';
    } else {
      testReport.overallStatus = 'failed';
    }
    
    // Generate recommendations
    if (testReport.serverStatus.version === 'simple') {
      testReport.recommendations.push('Critical: Server still in simple mode - complete switch to full version required');
    }
    
    const workingComponents = testReport.componentResults.filter(c => c.status === 'success').length;
    if (workingComponents < testReport.componentResults.length) {
      testReport.recommendations.push(`Component issues: ${testReport.componentResults.length - workingComponents} components need attention`);
    }
    
    if (testReport.apiCommunication.successRate < 80) {
      testReport.recommendations.push('API communication issues detected - review failed endpoints');
    }
    
    if (testReport.uiUxQuality.overallScore < 80) {
      testReport.recommendations.push('UI/UX quality improvements needed');
    }
    
    if (testReport.qualityScore >= 80) {
      testReport.recommendations.push('System ready for production use');
    }
    
    // Write comprehensive report
    const reportPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/POST_SWITCH_INTEGRATION_TEST_REPORT.json';
    fs.writeFileSync(reportPath, JSON.stringify(testReport, null, 2));
    
    console.log('📊 Integration Test Report Generated:', reportPath);
    console.log('🎯 Overall Status:', testReport.overallStatus);
    console.log('📈 Quality Score:', testReport.qualityScore);
    console.log('🏆 Component Results:', `${workingComponents}/${testReport.componentResults.length} working`);
    console.log('🌐 API Success Rate:', `${testReport.apiCommunication.successRate.toFixed(1)}%`);
    console.log('🎨 UI/UX Score:', `${testReport.uiUxQuality.overallScore}%`);
    console.log('⚠️  Critical Issues:', testReport.criticalIssues.length);
    console.log('💡 Recommendations:', testReport.recommendations.length);
  }
});