import { Client } from '@microsoft/microsoft-graph-client';
import { ConfidentialClientApplication } from '@azure/msal-node';
import { readFileSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import logger from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Microsoft 365設定
const config = {
  tenantId: process.env.MICROSOFT_TENANT_ID,
  clientId: process.env.MICROSOFT_CLIENT_ID,
  clientSecret: process.env.MICROSOFT_CLIENT_SECRET,
  certificatePath: process.env.MICROSOFT_CERTIFICATE_PATH,
  certificatePassword: process.env.MICROSOFT_CERTIFICATE_PASSWORD,
  authority: `https://login.microsoftonline.com/${process.env.MICROSOFT_TENANT_ID}`,
  scopes: [
    'https://graph.microsoft.com/.default'
  ]
};

// Graph APIクライアント設定
let graphClient;
let msalClient;

// Microsoft Graph Client初期化
export const initializeMicrosoftGraphClient = async (authMethod = 'client-secret', credentials = {}) => {
  try {
    let clientConfig = {
      auth: {
        clientId: credentials.clientId || config.clientId,
        authority: credentials.authority || config.authority,
        tenantId: credentials.tenantId || config.tenantId
      }
    };

    if (authMethod === 'certificate') {
      // 証明書認証
      const certificatePath = credentials.certificatePath || config.certificatePath;
      const certificatePassword = credentials.certificatePassword || config.certificatePassword;
      
      if (!certificatePath) {
        throw new Error('Certificate path is required for certificate authentication');
      }

      try {
        // 証明書の読み込み
        const certificateBuffer = readFileSync(certificatePath);
        
        clientConfig.auth.clientCertificate = {
          thumbprint: '', // 実際の実装では証明書から取得
          privateKey: certificateBuffer,
          passphrase: certificatePassword
        };
      } catch (error) {
        logger.error('Failed to load certificate:', error);
        throw new Error('Certificate loading failed');
      }
    } else if (authMethod === 'client-secret') {
      // クライアントシークレット認証
      const clientSecret = credentials.clientSecret || config.clientSecret;
      
      if (!clientSecret) {
        throw new Error('Client secret is required for client-secret authentication');
      }

      clientConfig.auth.clientSecret = clientSecret;
    } else {
      throw new Error(`Unsupported authentication method: ${authMethod}`);
    }

    // MSAL クライアント初期化
    msalClient = new ConfidentialClientApplication(clientConfig);

    // トークン取得
    const clientCredentialRequest = {
      scopes: config.scopes,
      tenantId: credentials.tenantId || config.tenantId
    };

    const response = await msalClient.acquireTokenSilent(clientCredentialRequest);
    
    if (!response) {
      const tokenResponse = await msalClient.acquireTokenByClientCredential(clientCredentialRequest);
      
      if (!tokenResponse) {
        throw new Error('Failed to acquire access token');
      }
    }

    // Graph Client初期化
    graphClient = Client.init({
      authProvider: async (done) => {
        try {
          const tokenResponse = await msalClient.acquireTokenByClientCredential(clientCredentialRequest);
          done(null, tokenResponse.accessToken);
        } catch (error) {
          logger.error('Graph auth provider error:', error);
          done(error, null);
        }
      }
    });

    logger.info(`Microsoft Graph Client initialized with ${authMethod} authentication`);
    return graphClient;
  } catch (error) {
    logger.error('Failed to initialize Microsoft Graph Client:', error);
    throw error;
  }
};

// Graph APIクライアント取得
export const getGraphClient = () => {
  if (!graphClient) {
    throw new Error('Microsoft Graph Client not initialized. Call initializeMicrosoftGraphClient() first.');
  }
  return graphClient;
};

// ユーザー取得
export const getUsers = async (options = {}) => {
  try {
    const client = getGraphClient();
    let query = client.users;

    // フィルタリング
    if (options.filter) {
      query = query.filter(options.filter);
    }

    // 検索
    if (options.search) {
      query = query.search(`"displayName:${options.search}" OR "userPrincipalName:${options.search}"`);
    }

    // 選択フィールド
    const select = options.select || [
      'id',
      'displayName',
      'userPrincipalName',
      'mail',
      'jobTitle',
      'department',
      'officeLocation',
      'mobilePhone',
      'businessPhones',
      'accountEnabled',
      'createdDateTime',
      'signInActivity'
    ];

    query = query.select(select);

    // 並び順
    if (options.orderBy) {
      query = query.orderby(options.orderBy);
    }

    // 件数制限
    if (options.top) {
      query = query.top(options.top);
    }

    const users = await query.get();
    return users;
  } catch (error) {
    logger.error('Failed to get users:', error);
    throw error;
  }
};

// 特定ユーザー取得
export const getUserById = async (userId) => {
  try {
    const client = getGraphClient();
    const user = await client
      .users(userId)
      .select([
        'id',
        'displayName',
        'userPrincipalName',
        'mail',
        'jobTitle',
        'department',
        'officeLocation',
        'mobilePhone',
        'businessPhones',
        'accountEnabled',
        'createdDateTime',
        'signInActivity'
      ])
      .get();
    return user;
  } catch (error) {
    logger.error(`Failed to get user ${userId}:`, error);
    throw error;
  }
};

// ユーザーライセンス取得
export const getUserLicenses = async (userId) => {
  try {
    const client = getGraphClient();
    const licenses = await client
      .users(userId)
      .licenseDetails
      .get();
    return licenses;
  } catch (error) {
    logger.error(`Failed to get licenses for user ${userId}:`, error);
    throw error;
  }
};

// ライセンス情報取得
export const getSubscribedSkus = async () => {
  try {
    const client = getGraphClient();
    const skus = await client
      .subscribedSkus
      .get();
    return skus;
  } catch (error) {
    logger.error('Failed to get subscribed SKUs:', error);
    throw error;
  }
};

// サインインログ取得
export const getSignInLogs = async (options = {}) => {
  try {
    const client = getGraphClient();
    let query = client.auditLogs.signIns;

    // フィルタリング
    if (options.filter) {
      query = query.filter(options.filter);
    }

    // 日付範囲
    if (options.startDate || options.endDate) {
      let dateFilter = '';
      if (options.startDate) {
        dateFilter += `createdDateTime ge ${options.startDate}`;
      }
      if (options.endDate) {
        if (dateFilter) dateFilter += ' and ';
        dateFilter += `createdDateTime le ${options.endDate}`;
      }
      query = query.filter(dateFilter);
    }

    // 選択フィールド
    const select = options.select || [
      'id',
      'createdDateTime',
      'userPrincipalName',
      'userId',
      'appDisplayName',
      'appId',
      'ipAddress',
      'location',
      'status',
      'deviceDetail',
      'conditionalAccessStatus'
    ];

    query = query.select(select);

    // 並び順
    query = query.orderby('createdDateTime desc');

    // 件数制限
    if (options.top) {
      query = query.top(options.top);
    }

    const signInLogs = await query.get();
    return signInLogs;
  } catch (error) {
    logger.error('Failed to get sign-in logs:', error);
    throw error;
  }
};

// 使用状況レポート取得
export const getUsageReports = async (reportType, period = 'D30') => {
  try {
    const client = getGraphClient();
    let report;

    switch (reportType) {
      case 'office365-activations':
        report = await client
          .reports
          .office365Activations()
          .get();
        break;
      case 'office365-active-users':
        report = await client
          .reports
          .office365ActiveUsers(period)
          .get();
        break;
      case 'office365-services-user-counts':
        report = await client
          .reports
          .office365ServicesUserCounts(period)
          .get();
        break;
      case 'teams-user-activity':
        report = await client
          .reports
          .teamsUserActivity(period)
          .get();
        break;
      case 'onedrive-usage':
        report = await client
          .reports
          .oneDriveUsage(period)
          .get();
        break;
      case 'exchange-activity':
        report = await client
          .reports
          .emailActivity(period)
          .get();
        break;
      default:
        throw new Error(`Unsupported report type: ${reportType}`);
    }

    return report;
  } catch (error) {
    logger.error(`Failed to get usage report ${reportType}:`, error);
    throw error;
  }
};

// 接続テスト
export const testConnection = async () => {
  try {
    const client = getGraphClient();
    const me = await client.organization.get();
    logger.info('Microsoft Graph connection test successful');
    return { success: true, organization: me };
  } catch (error) {
    logger.error('Microsoft Graph connection test failed:', error);
    return { success: false, error: error.message };
  }
};

// MFA状態取得
export const getUserMFAStatus = async (userId) => {
  try {
    const client = getGraphClient();
    const authMethods = await client
      .users(userId)
      .authentication
      .methods
      .get();
    
    const mfaStatus = {
      enabled: authMethods.length > 0,
      methods: authMethods.map(method => method['@odata.type']),
      methodCount: authMethods.length,
      lastUpdate: new Date().toISOString()
    };
    
    return mfaStatus;
  } catch (error) {
    logger.error(`Failed to get MFA status for user ${userId}:`, error);
    throw error;
  }
};

// 設定エクスポート
export const exportConfiguration = () => {
  return {
    tenantId: config.tenantId,
    clientId: config.clientId,
    scopes: config.scopes,
    hasCertificate: !!config.certificatePath,
    hasClientSecret: !!config.clientSecret
  };
};

export default {
  initializeMicrosoftGraphClient,
  getGraphClient,
  getUsers,
  getUserById,
  getUserLicenses,
  getSubscribedSkus,
  getSignInLogs,
  getUsageReports,
  getUserMFAStatus,
  testConnection,
  exportConfiguration
};