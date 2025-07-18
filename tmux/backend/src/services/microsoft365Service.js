const axios = require('axios');
const { msalClient, graphConfig, serviceEndpoints } = require('../config/microsoft365');
const logger = require('../utils/logger');
const { ExternalServiceError } = require('../middleware/errorHandler');

class Microsoft365Service {
  constructor() {
    this.baseUrl = graphConfig.baseUrl;
    this.betaUrl = graphConfig.betaUrl;
    this.timeout = graphConfig.timeout;
    this.accessToken = null;
    this.tokenExpiresAt = null;
  }

  // Get access token for Microsoft Graph API
  async getAccessToken() {
    try {
      if (this.accessToken && this.tokenExpiresAt > Date.now()) {
        return this.accessToken;
      }

      const clientCredentialRequest = {
        scopes: ['https://graph.microsoft.com/.default'],
        skipCache: false,
      };

      const response = await msalClient.acquireTokenByClientCredential(clientCredentialRequest);
      
      this.accessToken = response.accessToken;
      this.tokenExpiresAt = response.expiresOn.getTime();
      
      logger.info('Microsoft 365 access token acquired');
      return this.accessToken;
    } catch (error) {
      logger.error('Failed to acquire Microsoft 365 access token', {
        error: error.message,
        errorCode: error.errorCode
      });
      throw new ExternalServiceError('Failed to authenticate with Microsoft 365', 'Microsoft Graph');
    }
  }

  // Make authenticated request to Microsoft Graph API
  async makeRequest(endpoint, options = {}) {
    const token = await this.getAccessToken();
    const url = endpoint.startsWith('http') ? endpoint : `${this.baseUrl}${endpoint}`;
    
    const config = {
      url,
      method: options.method || 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        ...options.headers
      },
      timeout: this.timeout,
      ...options
    };

    try {
      const startTime = Date.now();
      const response = await axios(config);
      const duration = Date.now() - startTime;
      
      logger.apiCall(config.method, endpoint, response.status, duration);
      
      return response.data;
    } catch (error) {
      const duration = Date.now() - Date.now();
      logger.apiCall(config.method, endpoint, error.response?.status || 'ERROR', duration, {
        error: error.message
      });
      
      if (error.response?.status === 429) {
        // Rate limit exceeded
        const retryAfter = error.response.headers['retry-after'] || 60;
        throw new ExternalServiceError(`Rate limit exceeded. Retry after ${retryAfter} seconds`, 'Microsoft Graph');
      }
      
      throw new ExternalServiceError(
        error.response?.data?.error?.message || 'Microsoft Graph API request failed',
        'Microsoft Graph'
      );
    }
  }

  // Get all users
  async getUsers(options = {}) {
    const { top = 100, skip = 0, filter = null, select = null } = options;
    
    let endpoint = `${serviceEndpoints.graph.users}?$top=${top}&$skip=${skip}`;
    
    if (filter) {
      endpoint += `&$filter=${encodeURIComponent(filter)}`;
    }
    
    if (select) {
      endpoint += `&$select=${encodeURIComponent(select)}`;
    }
    
    return await this.makeRequest(endpoint);
  }

  // Get user by ID
  async getUserById(userId) {
    const endpoint = `${serviceEndpoints.graph.users}/${userId}`;
    return await this.makeRequest(endpoint);
  }

  // Get user's manager
  async getUserManager(userId) {
    const endpoint = `${serviceEndpoints.graph.users}/${userId}/manager`;
    return await this.makeRequest(endpoint);
  }

  // Get user's direct reports
  async getUserDirectReports(userId) {
    const endpoint = `${serviceEndpoints.graph.users}/${userId}/directReports`;
    return await this.makeRequest(endpoint);
  }

  // Get organization information
  async getOrganization() {
    const endpoint = serviceEndpoints.graph.organization;
    return await this.makeRequest(endpoint);
  }

  // Get all groups
  async getGroups(options = {}) {
    const { top = 100, skip = 0, filter = null } = options;
    
    let endpoint = `${serviceEndpoints.graph.groups}?$top=${top}&$skip=${skip}`;
    
    if (filter) {
      endpoint += `&$filter=${encodeURIComponent(filter)}`;
    }
    
    return await this.makeRequest(endpoint);
  }

  // Get group members
  async getGroupMembers(groupId) {
    const endpoint = `${serviceEndpoints.graph.groups}/${groupId}/members`;
    return await this.makeRequest(endpoint);
  }

  // Get subscriptions (licenses)
  async getSubscriptions() {
    const endpoint = serviceEndpoints.graph.subscriptions;
    return await this.makeRequest(endpoint);
  }

  // Get directory roles
  async getDirectoryRoles() {
    const endpoint = serviceEndpoints.graph.directoryRoles;
    return await this.makeRequest(endpoint);
  }

  // Get audit logs
  async getAuditLogs(options = {}) {
    const { top = 100, filter = null } = options;
    
    let endpoint = `${serviceEndpoints.graph.auditLogs}/directoryAudits?$top=${top}`;
    
    if (filter) {
      endpoint += `&$filter=${encodeURIComponent(filter)}`;
    }
    
    return await this.makeRequest(endpoint);
  }

  // Get sign-in logs
  async getSignInLogs(options = {}) {
    const { top = 100, filter = null } = options;
    
    let endpoint = `${serviceEndpoints.graph.auditLogs}/signIns?$top=${top}`;
    
    if (filter) {
      endpoint += `&$filter=${encodeURIComponent(filter)}`;
    }
    
    return await this.makeRequest(endpoint);
  }

  // Get devices
  async getDevices(options = {}) {
    const { top = 100, skip = 0, filter = null } = options;
    
    let endpoint = `${serviceEndpoints.graph.devices}?$top=${top}&$skip=${skip}`;
    
    if (filter) {
      endpoint += `&$filter=${encodeURIComponent(filter)}`;
    }
    
    return await this.makeRequest(endpoint);
  }

  // Get applications
  async getApplications(options = {}) {
    const { top = 100, skip = 0, filter = null } = options;
    
    let endpoint = `${serviceEndpoints.graph.applications}?$top=${top}&$skip=${skip}`;
    
    if (filter) {
      endpoint += `&$filter=${encodeURIComponent(filter)}`;
    }
    
    return await this.makeRequest(endpoint);
  }

  // Get reports - Email activity
  async getEmailActivityReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.exchange.mailActivity}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get reports - Mailbox usage
  async getMailboxUsageReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.exchange.mailboxes}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get reports - Teams usage
  async getTeamsUsageReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.teams.usage}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get reports - Teams device usage
  async getTeamsDeviceUsageReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.teams.deviceUsage}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get reports - OneDrive usage
  async getOneDriveUsageReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.onedrive.usage}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get reports - OneDrive activity
  async getOneDriveActivityReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.onedrive.activity}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get reports - SharePoint usage
  async getSharePointUsageReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.sharepoint.usage}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get reports - SharePoint activity
  async getSharePointActivityReport(period = 'D7') {
    const endpoint = `${serviceEndpoints.services.sharepoint.activity}(period='${period}')`;
    return await this.makeRequest(endpoint);
  }

  // Get security alerts
  async getSecurityAlerts(options = {}) {
    const { top = 100, filter = null } = options;
    
    let endpoint = `${serviceEndpoints.graph.security}/alerts?$top=${top}`;
    
    if (filter) {
      endpoint += `&$filter=${encodeURIComponent(filter)}`;
    }
    
    return await this.makeRequest(endpoint);
  }

  // Get conditional access policies
  async getConditionalAccessPolicies() {
    const endpoint = '/identity/conditionalAccess/policies';
    return await this.makeRequest(endpoint);
  }

  // Get MFA authentication methods
  async getMfaAuthenticationMethods(userId) {
    const endpoint = `${serviceEndpoints.graph.users}/${userId}/authentication/methods`;
    return await this.makeRequest(endpoint);
  }

  // Batch requests for efficiency
  async batchRequest(requests) {
    const endpoint = '/$batch';
    const batchData = {
      requests: requests.map((req, index) => ({
        id: (index + 1).toString(),
        method: req.method || 'GET',
        url: req.url,
        headers: req.headers || {}
      }))
    };

    return await this.makeRequest(endpoint, {
      method: 'POST',
      data: batchData
    });
  }

  // Health check
  async healthCheck() {
    try {
      await this.makeRequest('/me');
      return { status: 'healthy', timestamp: new Date().toISOString() };
    } catch (error) {
      logger.error('Microsoft 365 health check failed', { error: error.message });
      return { status: 'unhealthy', error: error.message, timestamp: new Date().toISOString() };
    }
  }
}

module.exports = Microsoft365Service;