import express, { Request, Response } from 'express';
import { spawn } from 'child_process';
import WebSocket from 'ws';
import path from 'path';
import { authenticateToken } from '../middleware/auth';

const router = express.Router();

interface FeatureMapping {
  [category: string]: {
    [feature: string]: {
      script: string;
      params?: string[];
    }
  }
}

const featureMapping: FeatureMapping = {
  regular: {
    daily: { script: 'Scripts/Common/ScheduledReports.ps1', params: ['-ReportType', 'Daily'] },
    weekly: { script: 'Scripts/Common/ScheduledReports.ps1', params: ['-ReportType', 'Weekly'] },
    monthly: { script: 'Scripts/Common/ScheduledReports.ps1', params: ['-ReportType', 'Monthly'] },
    yearly: { script: 'Scripts/Common/ScheduledReports.ps1', params: ['-ReportType', 'Yearly'] },
    test: { script: 'TestScripts/test-all-features.ps1' }
  },
  analysis: {
    license: { script: 'Scripts/Analysis/Get-LicenseAnalysis.ps1' },
    usage: { script: 'Scripts/Analysis/Get-UsageAnalysis.ps1' },
    performance: { script: 'Scripts/Analysis/Get-PerformanceAnalysis.ps1' },
    security: { script: 'Scripts/Analysis/Get-SecurityAnalysis.ps1' },
    permission: { script: 'Scripts/Analysis/Get-PermissionAudit.ps1' }
  },
  entraid: {
    users: { script: 'Scripts/EntraID/Get-EntraIDUsers.ps1' },
    mfa: { script: 'Scripts/EntraID/Get-MFAStatus.ps1' },
    conditional: { script: 'Scripts/EntraID/Get-ConditionalAccessPolicies.ps1' },
    signin: { script: 'Scripts/EntraID/Get-SignInLogs.ps1' }
  },
  exchange: {
    mailbox: { script: 'Scripts/EXO/Get-MailboxManagement.ps1' },
    mailflow: { script: 'Scripts/EXO/Get-MailFlowAnalysis.ps1' },
    spam: { script: 'Scripts/EXO/Get-SpamProtectionAnalysis.ps1' },
    delivery: { script: 'Scripts/EXO/Get-MailDeliveryAnalysis.ps1' }
  },
  teams: {
    'teams-usage': { script: 'Scripts/EntraID/Get-TeamsUsage.ps1' },
    'teams-settings': { script: 'Scripts/EntraID/Get-TeamsSettings.ps1' },
    meeting: { script: 'Scripts/EntraID/Get-MeetingQuality.ps1' },
    apps: { script: 'Scripts/EntraID/Get-TeamsApps.ps1' }
  },
  onedrive: {
    storage: { script: 'Scripts/EntraID/Get-OneDriveStorage.ps1' },
    sharing: { script: 'Scripts/EntraID/Get-OneDriveSharing.ps1' },
    sync: { script: 'Scripts/EntraID/Get-OneDriveSyncErrors.ps1' },
    external: { script: 'Scripts/EntraID/Get-ExternalSharing.ps1' }
  }
};

// WebSocketクライアント管理
const wsClients = new Map<string, WebSocket>();

router.post('/:category/:feature/run', authenticateToken, async (req: Request, res: Response) => {
  const { category, feature } = req.params;
  const userId = (req as any).user.id;
  const sessionId = `${userId}-${Date.now()}`;

  const featureConfig = featureMapping[category]?.[feature];
  if (!featureConfig) {
    return res.status(404).json({ error: 'Feature not found' });
  }

  const scriptPath = path.join(process.cwd(), '..', featureConfig.script);
  const args = ['-File', scriptPath, ...(featureConfig.params || [])];

  // PowerShellプロセスを起動
  const ps = spawn('pwsh', args, {
    cwd: path.join(process.cwd(), '..'),
    env: { ...process.env }
  });

  // WebSocketでリアルタイムログを配信
  const ws = wsClients.get(userId);
  
  ps.stdout.on('data', (data) => {
    const message = data.toString();
    console.log(`[${sessionId}] stdout:`, message);
    
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'log',
        sessionId,
        level: 'info',
        message,
        timestamp: new Date().toISOString()
      }));
    }
  });

  ps.stderr.on('data', (data) => {
    const message = data.toString();
    console.error(`[${sessionId}] stderr:`, message);
    
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'log',
        sessionId,
        level: 'error',
        message,
        timestamp: new Date().toISOString()
      }));
    }
  });

  ps.on('close', (code) => {
    const status = code === 0 ? 'completed' : 'error';
    console.log(`[${sessionId}] Process exited with code ${code}`);
    
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'status',
        sessionId,
        status,
        code,
        timestamp: new Date().toISOString()
      }));
    }
  });

  res.json({
    sessionId,
    status: 'started',
    feature: `${category}/${feature}`,
    timestamp: new Date().toISOString()
  });
});

router.get('/:category/:feature/status', authenticateToken, async (req: Request, res: Response) => {
  const { category, feature } = req.params;
  
  // 実行状態を取得する処理
  // 実際の実装では、データベースやRedisから状態を取得
  
  res.json({
    feature: `${category}/${feature}`,
    status: 'ready',
    lastRun: '2025-01-17T10:30:00Z',
    lastResult: 'success'
  });
});

router.get('/:category/:feature/reports', authenticateToken, async (req: Request, res: Response) => {
  const { category, feature } = req.params;
  const { limit = 10, offset = 0 } = req.query;
  
  // レポート一覧を取得する処理
  // 実際の実装では、ファイルシステムやデータベースから取得
  
  res.json({
    reports: [
      {
        id: '20250117_103000',
        filename: `${feature}_20250117_103000.html`,
        format: 'html',
        size: 245678,
        createdAt: '2025-01-17T10:30:00Z'
      },
      {
        id: '20250117_103000',
        filename: `${feature}_20250117_103000.csv`,
        format: 'csv',
        size: 45678,
        createdAt: '2025-01-17T10:30:00Z'
      }
    ],
    total: 2,
    limit: Number(limit),
    offset: Number(offset)
  });
});

router.get('/:category/:feature/reports/:reportId/download', authenticateToken, async (req: Request, res: Response) => {
  const { category, feature, reportId } = req.params;
  const { format = 'html' } = req.query;
  
  // レポートファイルのパスを構築
  const reportPath = path.join(
    process.cwd(),
    '..',
    'Reports',
    category,
    `${feature}_${reportId}.${format}`
  );
  
  // ファイルを送信
  res.download(reportPath, (err) => {
    if (err) {
      console.error('Download error:', err);
      res.status(404).json({ error: 'Report not found' });
    }
  });
});

// WebSocket接続の設定
export function setupWebSocket(wss: WebSocket.Server) {
  wss.on('connection', (ws: WebSocket, req: any) => {
    const userId = req.user?.id;
    if (userId) {
      wsClients.set(userId, ws);
      
      ws.on('close', () => {
        wsClients.delete(userId);
      });
    }
  });
}

export default router;