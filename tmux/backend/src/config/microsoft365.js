const { ConfidentialClientApplication } = require('@azure/msal-node');
const logger = require('../utils/logger');

// Microsoft 365 configuration
const msalConfig = {
  auth: {
    clientId: process.env.MS_CLIENT_ID,
    clientSecret: process.env.MS_CLIENT_SECRET,
    authority: `https://login.microsoftonline.com/${process.env.MS_TENANT_ID}`,
  },
  system: {
    loggerOptions: {
      loggerCallback(loglevel, message, containsPii) {
        if (!containsPii) {
          logger.debug(`MSAL: ${message}`);
        }
      },
      piiLoggingEnabled: false,
      logLevel: 'Info',
    },
  },
};

// Create MSAL client instance
const msalClient = new ConfidentialClientApplication(msalConfig);

// Microsoft Graph API configuration
const graphConfig = {
  baseUrl: 'https://graph.microsoft.com/v1.0',
  betaUrl: 'https://graph.microsoft.com/beta',
  scopes: [
    'https://graph.microsoft.com/.default'
  ],
  timeout: 30000,
  retryAttempts: 3,
  retryDelay: 1000
};

// Exchange Online configuration
const exchangeConfig = {
  certificatePath: process.env.EXO_CERTIFICATE_PATH,
  certificatePassword: process.env.EXO_CERTIFICATE_PASSWORD,
  organization: process.env.MS_ORGANIZATION || `${process.env.MS_TENANT_ID}.onmicrosoft.com`,
  appId: process.env.MS_CLIENT_ID,
  timeout: 60000
};

// Microsoft 365 service endpoints
const serviceEndpoints = {
  // Microsoft Graph API endpoints
  graph: {
    users: '/users',
    groups: '/groups',
    applications: '/applications',
    organization: '/organization',
    subscriptions: '/subscriptions',
    directoryRoles: '/directoryRoles',
    auditLogs: '/auditLogs',
    security: '/security',
    reports: '/reports',
    devices: '/devices',
    identityGovernance: '/identityGovernance'
  },
  
  // Specific Microsoft 365 service endpoints
  services: {
    // Exchange Online
    exchange: {
      mailboxes: '/reports/getMailboxUsageDetail',
      mailActivity: '/reports/getEmailActivityUserDetail',
      mailAppUsage: '/reports/getEmailAppUsageUserDetail'
    },
    
    // Microsoft Teams
    teams: {
      usage: '/reports/getTeamsUserActivityUserDetail',
      deviceUsage: '/reports/getTeamsDeviceUsageUserDetail',
      meetings: '/reports/getTeamsUserActivityUserDetail'
    },
    
    // OneDrive
    onedrive: {
      usage: '/reports/getOneDriveUsageAccountDetail',
      activity: '/reports/getOneDriveActivityUserDetail',
      storage: '/reports/getOneDriveUsageStorage'
    },
    
    // SharePoint
    sharepoint: {
      usage: '/reports/getSharePointSiteUsageDetail',
      activity: '/reports/getSharePointActivityUserDetail',
      storage: '/reports/getSharePointSiteUsageStorage'
    }
  }
};

// Rate limiting configuration for Microsoft APIs
const rateLimits = {
  graph: {
    requestsPerSecond: 10,
    burstLimit: 100,
    backoffMultiplier: 2,
    maxBackoffTime: 30000
  },
  exchange: {
    requestsPerSecond: 5,
    burstLimit: 50,
    backoffMultiplier: 2,
    maxBackoffTime: 60000
  }
};

// Data retention policies
const dataRetention = {
  reports: {
    daily: 90,    // 90 days
    weekly: 365,  // 1 year
    monthly: 1095, // 3 years
    yearly: 2555   // 7 years
  },
  logs: {
    application: 30,  // 30 days
    audit: 365,      // 1 year
    security: 2555   // 7 years
  },
  cache: {
    userInfo: 300,      // 5 minutes
    groupInfo: 600,     // 10 minutes
    reports: 3600,      // 1 hour
    licenses: 1800      // 30 minutes
  }
};

// Validation schemas for Microsoft 365 data
const validationSchemas = {
  user: {
    requiredFields: ['id', 'displayName', 'userPrincipalName', 'mail'],
    optionalFields: ['department', 'jobTitle', 'officeLocation', 'mobilePhone']
  },
  group: {
    requiredFields: ['id', 'displayName', 'groupTypes'],
    optionalFields: ['description', 'visibility', 'membershipRule']
  },
  license: {
    requiredFields: ['skuId', 'skuPartNumber', 'consumedUnits', 'prepaidUnits'],
    optionalFields: ['capabilityStatus', 'appliesTo']
  }
};

module.exports = {
  msalClient,
  msalConfig,
  graphConfig,
  exchangeConfig,
  serviceEndpoints,
  rateLimits,
  dataRetention,
  validationSchemas,
  
  // Helper functions
  getGraphUrl: (endpoint) => `${graphConfig.baseUrl}${endpoint}`,
  getBetaUrl: (endpoint) => `${graphConfig.betaUrl}${endpoint}`,
  
  // Configuration validation
  validateConfig: () => {
    const requiredEnvVars = [
      'MS_TENANT_ID',
      'MS_CLIENT_ID',
      'MS_CLIENT_SECRET'
    ];
    
    const missing = requiredEnvVars.filter(envVar => !process.env[envVar]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
    
    logger.info('Microsoft 365 configuration validated successfully');
    return true;
  }
};