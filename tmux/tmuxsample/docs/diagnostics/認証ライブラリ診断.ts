/**
 * 認証・認可機能 & 共通ライブラリ診断システム
 * Authentication/Authorization & Common Library Diagnostic System
 * 
 * Role: QA Engineer - Emergency Auth & Library Analysis
 * Target: Comprehensive Authentication, Authorization & Library Testing
 * Priority: Emergency - Security & Library Functionality Analysis
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import jwt from 'jsonwebtoken';

interface AuthTestResult {
  component: string;
  test: string;
  status: 'success' | 'failed' | 'error';
  responseTime: number;
  details?: any;
  error?: string;
}

interface LibraryTest {
  library: string;
  version?: string;
  status: 'available' | 'missing' | 'error';
  path?: string;
  functions?: string[];
  error?: string;
}

interface SecurityTest {
  test: string;
  passed: boolean;
  severity: 'low' | 'medium' | 'high' | 'critical';
  details: string;
  recommendation?: string;
}

interface AuthLibraryReport {
  timestamp: string;
  authenticationTests: AuthTestResult[];
  authorizationTests: AuthTestResult[];
  libraryTests: LibraryTest[];
  securityTests: SecurityTest[];
  overallAuthStatus: 'secure' | 'vulnerable' | 'critical';
  libraryStatus: 'complete' | 'missing' | 'error';
  recommendations: string[];
  criticalIssues: string[];
}

describe('Authentication/Authorization & Library Diagnostic', () => {
  let authLibraryReport: AuthLibraryReport;
  const baseUrl = 'http://localhost:3001';
  
  beforeAll(async () => {
    console.log('🔐 Starting Authentication/Authorization & Library Diagnostic...');
    
    authLibraryReport = {
      timestamp: new Date().toISOString(),
      authenticationTests: [],
      authorizationTests: [],
      libraryTests: [],
      securityTests: [],
      overallAuthStatus: 'secure',
      libraryStatus: 'complete',
      recommendations: [],
      criticalIssues: []
    };
  });

  afterAll(async () => {
    await generateAuthLibraryReport();
  });

  describe('Authentication System Testing', () => {
    it('should test JWT authentication functionality', async () => {
      console.log('🔑 Testing JWT authentication functionality...');
      
      // Test login endpoint
      const loginTest: AuthTestResult = {
        component: 'JWT Authentication',
        test: 'Login Endpoint',
        status: 'success',
        responseTime: 0
      };
      
      const startTime = Date.now();
      
      try {
        const loginResponse = await axios.post(`${baseUrl}/api/auth/login`, {
          username: 'test@example.com',
          password: 'testpassword'
        });
        
        loginTest.responseTime = Date.now() - startTime;
        loginTest.status = 'success';
        loginTest.details = {
          statusCode: loginResponse.status,
          hasToken: !!loginResponse.data?.token,
          tokenType: typeof loginResponse.data?.token,
          expiresIn: loginResponse.data?.expiresIn,
          userInfo: loginResponse.data?.user
        };
        
        console.log('✅ JWT Login: Success');
      } catch (error) {
        loginTest.responseTime = Date.now() - startTime;
        loginTest.status = 'error';
        loginTest.error = error.message;
        loginTest.details = {
          statusCode: error.response?.status,
          errorMessage: error.response?.data?.message
        };
        
        console.log('❌ JWT Login: Failed -', error.message);
      }
      
      authLibraryReport.authenticationTests.push(loginTest);
    });

    it('should test JWT token validation', async () => {
      console.log('🎫 Testing JWT token validation...');
      
      const validationTests = [
        { name: 'Valid Token', token: 'valid-jwt-token', expectedStatus: 200 },
        { name: 'Invalid Token', token: 'invalid-token', expectedStatus: 401 },
        { name: 'Expired Token', token: 'expired-jwt-token', expectedStatus: 401 },
        { name: 'Malformed Token', token: 'malformed.jwt.token', expectedStatus: 401 },
        { name: 'Empty Token', token: '', expectedStatus: 401 },
        { name: 'No Token', token: null, expectedStatus: 401 }
      ];
      
      for (const test of validationTests) {
        const validationTest: AuthTestResult = {
          component: 'JWT Validation',
          test: test.name,
          status: 'success',
          responseTime: 0
        };
        
        const startTime = Date.now();
        
        try {
          const headers = {};
          if (test.token) {
            headers['Authorization'] = `Bearer ${test.token}`;
          }
          
          const response = await axios.get(`${baseUrl}/api/auth/validate`, {
            headers,
            timeout: 3000
          });
          
          validationTest.responseTime = Date.now() - startTime;
          validationTest.status = response.status === test.expectedStatus ? 'success' : 'failed';
          validationTest.details = {
            statusCode: response.status,
            expectedStatus: test.expectedStatus,
            response: response.data
          };
          
          console.log(`✅ JWT Validation ${test.name}: ${response.status}`);
        } catch (error) {
          validationTest.responseTime = Date.now() - startTime;
          
          if (error.response?.status === test.expectedStatus) {
            validationTest.status = 'success';
            validationTest.details = {
              statusCode: error.response.status,
              expectedStatus: test.expectedStatus,
              message: 'Expected error response'
            };
            console.log(`✅ JWT Validation ${test.name}: Expected ${error.response.status}`);
          } else {
            validationTest.status = 'error';
            validationTest.error = error.message;
            console.log(`❌ JWT Validation ${test.name}: Unexpected error -`, error.message);
          }
        }
        
        authLibraryReport.authenticationTests.push(validationTest);
      }
    });

    it('should test password security', async () => {
      console.log('🔒 Testing password security...');
      
      const passwordTests = [
        { password: 'weak', strength: 'weak' },
        { password: 'password123', strength: 'weak' },
        { password: 'StrongP@ssw0rd!', strength: 'strong' },
        { password: 'VeryStrongP@ssw0rd123!', strength: 'strong' },
        { password: '', strength: 'invalid' },
        { password: '123', strength: 'weak' }
      ];
      
      for (const test of passwordTests) {
        const passwordTest: AuthTestResult = {
          component: 'Password Security',
          test: `Password Strength: ${test.strength}`,
          status: 'success',
          responseTime: 0
        };
        
        const startTime = Date.now();
        
        try {
          const response = await axios.post(`${baseUrl}/api/auth/validate-password`, {
            password: test.password
          });
          
          passwordTest.responseTime = Date.now() - startTime;
          passwordTest.details = {
            password: test.password.replace(/./g, '*'),
            expectedStrength: test.strength,
            actualStrength: response.data?.strength,
            requirements: response.data?.requirements,
            score: response.data?.score
          };
          
          console.log(`🔒 Password Test: ${test.strength} - ${response.data?.strength || 'N/A'}`);
        } catch (error) {
          passwordTest.responseTime = Date.now() - startTime;
          passwordTest.status = 'error';
          passwordTest.error = error.message;
          console.log(`❌ Password Test: ${test.strength} - Error:`, error.message);
        }
        
        authLibraryReport.authenticationTests.push(passwordTest);
      }
    });
  });

  describe('Authorization System Testing', () => {
    it('should test RBAC (Role-Based Access Control)', async () => {
      console.log('👤 Testing RBAC functionality...');
      
      const rbacTests = [
        { role: 'admin', endpoint: '/api/rbac/users', expectedStatus: 200 },
        { role: 'user', endpoint: '/api/rbac/users', expectedStatus: 403 },
        { role: 'admin', endpoint: '/api/rbac/roles', expectedStatus: 200 },
        { role: 'user', endpoint: '/api/rbac/roles', expectedStatus: 403 },
        { role: 'admin', endpoint: '/api/users', expectedStatus: 200 },
        { role: 'user', endpoint: '/api/users/profile', expectedStatus: 200 },
        { role: 'guest', endpoint: '/api/users', expectedStatus: 401 }
      ];
      
      for (const test of rbacTests) {
        const rbacTest: AuthTestResult = {
          component: 'RBAC Authorization',
          test: `${test.role} accessing ${test.endpoint}`,
          status: 'success',
          responseTime: 0
        };
        
        const startTime = Date.now();
        
        try {
          const headers = {};
          if (test.role !== 'guest') {
            headers['Authorization'] = `Bearer ${test.role}-token`;
          }
          
          const response = await axios.get(`${baseUrl}${test.endpoint}`, {
            headers,
            timeout: 3000
          });
          
          rbacTest.responseTime = Date.now() - startTime;
          rbacTest.status = response.status === test.expectedStatus ? 'success' : 'failed';
          rbacTest.details = {
            role: test.role,
            endpoint: test.endpoint,
            statusCode: response.status,
            expectedStatus: test.expectedStatus,
            allowed: response.status === 200
          };
          
          console.log(`✅ RBAC ${test.role} -> ${test.endpoint}: ${response.status}`);
        } catch (error) {
          rbacTest.responseTime = Date.now() - startTime;
          
          if (error.response?.status === test.expectedStatus) {
            rbacTest.status = 'success';
            rbacTest.details = {
              role: test.role,
              endpoint: test.endpoint,
              statusCode: error.response.status,
              expectedStatus: test.expectedStatus,
              message: 'Expected authorization failure'
            };
            console.log(`✅ RBAC ${test.role} -> ${test.endpoint}: Expected ${error.response.status}`);
          } else {
            rbacTest.status = 'error';
            rbacTest.error = error.message;
            console.log(`❌ RBAC ${test.role} -> ${test.endpoint}: Error -`, error.message);
          }
        }
        
        authLibraryReport.authorizationTests.push(rbacTest);
      }
    });

    it('should test permission-based access control', async () => {
      console.log('🛡️ Testing permission-based access control...');
      
      const permissionTests = [
        { permission: 'read:users', endpoint: '/api/users', method: 'GET', expectedStatus: 200 },
        { permission: 'write:users', endpoint: '/api/users', method: 'POST', expectedStatus: 201 },
        { permission: 'delete:users', endpoint: '/api/users/123', method: 'DELETE', expectedStatus: 200 },
        { permission: 'read:incidents', endpoint: '/api/incidents', method: 'GET', expectedStatus: 200 },
        { permission: 'write:incidents', endpoint: '/api/incidents', method: 'POST', expectedStatus: 201 },
        { permission: 'admin:system', endpoint: '/api/system/settings', method: 'GET', expectedStatus: 200 }
      ];
      
      for (const test of permissionTests) {
        const permissionTest: AuthTestResult = {
          component: 'Permission-based Access',
          test: `${test.permission} - ${test.method} ${test.endpoint}`,
          status: 'success',
          responseTime: 0
        };
        
        const startTime = Date.now();
        
        try {
          const config = {
            method: test.method.toLowerCase(),
            url: `${baseUrl}${test.endpoint}`,
            headers: {
              'Authorization': `Bearer permission-${test.permission}-token`,
              'Content-Type': 'application/json'
            },
            timeout: 3000
          };
          
          if (test.method === 'POST') {
            config['data'] = { test: 'data' };
          }
          
          const response = await axios(config);
          
          permissionTest.responseTime = Date.now() - startTime;
          permissionTest.status = 'success';
          permissionTest.details = {
            permission: test.permission,
            method: test.method,
            endpoint: test.endpoint,
            statusCode: response.status,
            allowed: response.status < 400
          };
          
          console.log(`✅ Permission ${test.permission}: ${response.status}`);
        } catch (error) {
          permissionTest.responseTime = Date.now() - startTime;
          permissionTest.status = 'error';
          permissionTest.error = error.message;
          permissionTest.details = {
            permission: test.permission,
            statusCode: error.response?.status,
            message: error.response?.data?.message
          };
          
          console.log(`❌ Permission ${test.permission}: Error -`, error.message);
        }
        
        authLibraryReport.authorizationTests.push(permissionTest);
      }
    });
  });

  describe('Common Library Testing', () => {
    it('should test essential Node.js libraries', async () => {
      console.log('📚 Testing essential Node.js libraries...');
      
      const essentialLibraries = [
        'express',
        'jsonwebtoken',
        'bcryptjs',
        'cors',
        'helmet',
        'axios',
        'better-sqlite3',
        'socket.io',
        'winston',
        'joi',
        'multer',
        'compression',
        'rate-limiter-flexible'
      ];
      
      for (const libName of essentialLibraries) {
        const libraryTest: LibraryTest = {
          library: libName,
          status: 'missing'
        };
        
        try {
          // Try to require the library
          const lib = require(libName);
          libraryTest.status = 'available';
          libraryTest.version = lib.version || 'unknown';
          
          // Test basic functionality if possible
          if (libName === 'express') {
            libraryTest.functions = ['Router', 'application', 'request', 'response'];
          } else if (libName === 'jsonwebtoken') {
            libraryTest.functions = ['sign', 'verify', 'decode'];
          } else if (libName === 'bcryptjs') {
            libraryTest.functions = ['hash', 'compare', 'genSalt'];
          } else if (libName === 'axios') {
            libraryTest.functions = ['get', 'post', 'put', 'delete'];
          }
          
          console.log(`✅ Library ${libName}: Available`);
        } catch (error) {
          libraryTest.status = 'error';
          libraryTest.error = error.message;
          console.log(`❌ Library ${libName}: Missing or Error -`, error.message);
        }
        
        authLibraryReport.libraryTests.push(libraryTest);
      }
    });

    it('should test custom utility libraries', async () => {
      console.log('🔧 Testing custom utility libraries...');
      
      const customLibraries = [
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/src/utils/jwt.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/src/utils/logger.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/src/utils/password.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/src/utils/security-utils.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/src/middleware/auth.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/src/middleware/rbac.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/itsm-backend/src/services/AuthController.ts'
      ];
      
      for (const libPath of customLibraries) {
        const libraryTest: LibraryTest = {
          library: path.basename(libPath),
          path: libPath,
          status: 'missing'
        };
        
        try {
          const exists = fs.existsSync(libPath);
          if (exists) {
            const content = fs.readFileSync(libPath, 'utf8');
            libraryTest.status = 'available';
            
            // Analyze content for functions/exports
            const functionMatches = content.match(/export\s+(function|const|class)\s+(\w+)/g);
            if (functionMatches) {
              libraryTest.functions = functionMatches.map(match => {
                const parts = match.split(/\s+/);
                return parts[parts.length - 1];
              });
            }
            
            console.log(`✅ Custom Library ${libraryTest.library}: Available`);
          } else {
            libraryTest.status = 'missing';
            console.log(`❌ Custom Library ${libraryTest.library}: Missing`);
          }
        } catch (error) {
          libraryTest.status = 'error';
          libraryTest.error = error.message;
          console.log(`❌ Custom Library ${libraryTest.library}: Error -`, error.message);
        }
        
        authLibraryReport.libraryTests.push(libraryTest);
      }
    });

    it('should test frontend authentication libraries', async () => {
      console.log('🌐 Testing frontend authentication libraries...');
      
      const frontendAuthFiles = [
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/frontend/src/services/api.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/frontend/src/lib/api.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/frontend/src/utils/errorHandler.ts',
        '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/frontend/src/components/common/ErrorNotification.tsx'
      ];
      
      for (const filePath of frontendAuthFiles) {
        const libraryTest: LibraryTest = {
          library: `Frontend: ${path.basename(filePath)}`,
          path: filePath,
          status: 'missing'
        };
        
        try {
          const exists = fs.existsSync(filePath);
          if (exists) {
            const content = fs.readFileSync(filePath, 'utf8');
            libraryTest.status = 'available';
            
            // Check for authentication-related functions
            const authPatterns = [
              'axios.interceptors',
              'Authorization',
              'Bearer',
              'token',
              'login',
              'logout',
              'authenticate',
              'errorHandler'
            ];
            
            const foundPatterns = authPatterns.filter(pattern => 
              content.includes(pattern)
            );
            
            libraryTest.functions = foundPatterns;
            
            console.log(`✅ Frontend Auth ${libraryTest.library}: Available (${foundPatterns.length} auth patterns)`);
          } else {
            libraryTest.status = 'missing';
            console.log(`❌ Frontend Auth ${libraryTest.library}: Missing`);
          }
        } catch (error) {
          libraryTest.status = 'error';
          libraryTest.error = error.message;
          console.log(`❌ Frontend Auth ${libraryTest.library}: Error -`, error.message);
        }
        
        authLibraryReport.libraryTests.push(libraryTest);
      }
    });
  });

  describe('Security Testing', () => {
    it('should test authentication security vulnerabilities', async () => {
      console.log('🔐 Testing authentication security vulnerabilities...');
      
      const securityTests: SecurityTest[] = [];
      
      // Test SQL injection in login
      try {
        await axios.post(`${baseUrl}/api/auth/login`, {
          username: "admin'; DROP TABLE users; --",
          password: "password"
        });
        
        securityTests.push({
          test: 'SQL Injection in Login',
          passed: true,
          severity: 'critical',
          details: 'SQL injection attempt was properly handled'
        });
      } catch (error) {
        if (error.response?.status === 400 || error.response?.status === 422) {
          securityTests.push({
            test: 'SQL Injection in Login',
            passed: true,
            severity: 'critical',
            details: 'SQL injection attempt was properly rejected'
          });
        } else {
          securityTests.push({
            test: 'SQL Injection in Login',
            passed: false,
            severity: 'critical',
            details: 'Unexpected response to SQL injection attempt',
            recommendation: 'Implement proper input validation and parameterized queries'
          });
        }
      }
      
      // Test JWT token manipulation
      try {
        const manipulatedToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFkbWluIiwiaWF0IjoxNTE2MjM5MDIyfQ.invalid';
        
        await axios.get(`${baseUrl}/api/users`, {
          headers: { Authorization: `Bearer ${manipulatedToken}` }
        });
        
        securityTests.push({
          test: 'JWT Token Manipulation',
          passed: false,
          severity: 'high',
          details: 'Manipulated JWT token was accepted',
          recommendation: 'Strengthen JWT signature verification'
        });
      } catch (error) {
        if (error.response?.status === 401) {
          securityTests.push({
            test: 'JWT Token Manipulation',
            passed: true,
            severity: 'high',
            details: 'Manipulated JWT token was properly rejected'
          });
        }
      }
      
      // Test password brute force protection
      const bruteForcePromises = [];
      for (let i = 0; i < 10; i++) {
        bruteForcePromises.push(
          axios.post(`${baseUrl}/api/auth/login`, {
            username: 'admin',
            password: `wrong-password-${i}`
          }).catch(() => {}) // Ignore errors
        );
      }
      
      try {
        await Promise.all(bruteForcePromises);
        
        // Try one more request
        await axios.post(`${baseUrl}/api/auth/login`, {
          username: 'admin',
          password: 'another-wrong-password'
        });
        
        securityTests.push({
          test: 'Brute Force Protection',
          passed: false,
          severity: 'high',
          details: 'No rate limiting detected for login attempts',
          recommendation: 'Implement rate limiting for authentication endpoints'
        });
      } catch (error) {
        if (error.response?.status === 429) {
          securityTests.push({
            test: 'Brute Force Protection',
            passed: true,
            severity: 'high',
            details: 'Rate limiting properly implemented'
          });
        } else {
          securityTests.push({
            test: 'Brute Force Protection',
            passed: false,
            severity: 'medium',
            details: 'Brute force protection status unclear'
          });
        }
      }
      
      authLibraryReport.securityTests = securityTests;
      
      console.log(`🔐 Security tests completed: ${securityTests.length} tests`);
    });

    it('should test authorization security', async () => {
      console.log('🛡️ Testing authorization security...');
      
      // Test privilege escalation
      try {
        await axios.post(`${baseUrl}/api/users`, {
          username: 'hacker',
          password: 'password',
          role: 'admin' // Try to set admin role
        }, {
          headers: { Authorization: 'Bearer user-token' }
        });
        
        authLibraryReport.securityTests.push({
          test: 'Privilege Escalation',
          passed: false,
          severity: 'critical',
          details: 'User was able to assign admin role to new user',
          recommendation: 'Implement proper role assignment validation'
        });
      } catch (error) {
        if (error.response?.status === 403 || error.response?.status === 422) {
          authLibraryReport.securityTests.push({
            test: 'Privilege Escalation',
            passed: true,
            severity: 'critical',
            details: 'Privilege escalation attempt was properly blocked'
          });
        }
      }
      
      // Test horizontal privilege escalation
      try {
        await axios.get(`${baseUrl}/api/users/other-user-profile`, {
          headers: { Authorization: 'Bearer user-token' }
        });
        
        authLibraryReport.securityTests.push({
          test: 'Horizontal Privilege Escalation',
          passed: false,
          severity: 'high',
          details: 'User was able to access other user\'s profile',
          recommendation: 'Implement proper user ownership validation'
        });
      } catch (error) {
        if (error.response?.status === 403 || error.response?.status === 404) {
          authLibraryReport.securityTests.push({
            test: 'Horizontal Privilege Escalation',
            passed: true,
            severity: 'high',
            details: 'Cross-user access was properly blocked'
          });
        }
      }
      
      console.log('🛡️ Authorization security testing completed');
    });
  });

  /**
   * Generate comprehensive authentication and library report
   */
  async function generateAuthLibraryReport() {
    console.log('📋 Generating Authentication & Library Report...');
    
    // Determine overall authentication status
    const criticalAuthFailures = authLibraryReport.authenticationTests.filter(t => t.status === 'error').length;
    const criticalAuthzFailures = authLibraryReport.authorizationTests.filter(t => t.status === 'error').length;
    const failedSecurityTests = authLibraryReport.securityTests.filter(t => !t.passed && t.severity === 'critical').length;
    
    if (criticalAuthFailures > 0 || criticalAuthzFailures > 0 || failedSecurityTests > 0) {
      authLibraryReport.overallAuthStatus = 'critical';
    } else if (authLibraryReport.securityTests.some(t => !t.passed && t.severity === 'high')) {
      authLibraryReport.overallAuthStatus = 'vulnerable';
    }
    
    // Determine library status
    const missingEssentialLibs = authLibraryReport.libraryTests.filter(
      t => t.status === 'missing' && ['express', 'jsonwebtoken', 'bcryptjs'].includes(t.library)
    ).length;
    
    if (missingEssentialLibs > 0) {
      authLibraryReport.libraryStatus = 'error';
    } else if (authLibraryReport.libraryTests.some(t => t.status === 'missing')) {
      authLibraryReport.libraryStatus = 'missing';
    }
    
    // Generate recommendations
    if (authLibraryReport.overallAuthStatus === 'critical') {
      authLibraryReport.recommendations.push('Critical: Authentication system has severe vulnerabilities - immediate security review required');
      authLibraryReport.criticalIssues.push('Authentication system vulnerabilities detected');
    }
    
    if (authLibraryReport.libraryStatus === 'error') {
      authLibraryReport.recommendations.push('Critical: Essential libraries missing - system cannot function properly');
      authLibraryReport.criticalIssues.push('Essential authentication libraries missing');
    }
    
    const failedAuthTests = authLibraryReport.authenticationTests.filter(t => t.status === 'error').length;
    if (failedAuthTests > 0) {
      authLibraryReport.recommendations.push('Authentication: Multiple authentication tests failed - review JWT and login functionality');
    }
    
    const failedAuthzTests = authLibraryReport.authorizationTests.filter(t => t.status === 'error').length;
    if (failedAuthzTests > 0) {
      authLibraryReport.recommendations.push('Authorization: RBAC system has issues - review role and permission management');
    }
    
    const missingCustomLibs = authLibraryReport.libraryTests.filter(t => t.status === 'missing' && t.path).length;
    if (missingCustomLibs > 0) {
      authLibraryReport.recommendations.push('Libraries: Custom authentication libraries missing - check file paths and implementations');
    }
    
    // Add security-specific recommendations
    authLibraryReport.securityTests.forEach(test => {
      if (!test.passed && test.recommendation) {
        authLibraryReport.recommendations.push(`Security: ${test.recommendation}`);
      }
    });
    
    // Write report to file
    const reportPath = '/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/AUTH_LIBRARY_DIAGNOSTIC_REPORT.json';
    fs.writeFileSync(reportPath, JSON.stringify(authLibraryReport, null, 2));
    
    console.log('📊 Authentication & Library Report Generated:', reportPath);
    console.log('🔐 Overall Auth Status:', authLibraryReport.overallAuthStatus);
    console.log('📚 Library Status:', authLibraryReport.libraryStatus);
    console.log('🧪 Auth Tests:', authLibraryReport.authenticationTests.length);
    console.log('🛡️  Authz Tests:', authLibraryReport.authorizationTests.length);
    console.log('📦 Library Tests:', authLibraryReport.libraryTests.length);
    console.log('🔒 Security Tests:', authLibraryReport.securityTests.length);
    console.log('⚠️  Critical Issues:', authLibraryReport.criticalIssues.length);
    console.log('💡 Recommendations:', authLibraryReport.recommendations.length);
  }
});