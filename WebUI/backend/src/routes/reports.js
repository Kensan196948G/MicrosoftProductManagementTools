import express from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { generateReport, getReportHistory, getReportStatus } from '../controllers/reportController.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Report:
 *       type: object
 *       required:
 *         - type
 *         - format
 *       properties:
 *         type:
 *           type: string
 *           enum: [daily, weekly, monthly, yearly, license-analysis, usage-analysis, performance-analysis, security-analysis]
 *           description: レポートタイプ
 *         format:
 *           type: string
 *           enum: [html, csv, pdf]
 *           description: 出力形式
 *         parameters:
 *           type: object
 *           description: レポート固有のパラメータ
 *         schedule:
 *           type: object
 *           properties:
 *             enabled:
 *               type: boolean
 *             cron:
 *               type: string
 *               description: Cron式
 *     ReportStatus:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         status:
 *           type: string
 *           enum: [pending, running, completed, failed]
 *         progress:
 *           type: number
 *           minimum: 0
 *           maximum: 100
 *         createdAt:
 *           type: string
 *           format: date-time
 *         completedAt:
 *           type: string
 *           format: date-time
 *         filePath:
 *           type: string
 *         error:
 *           type: string
 */

/**
 * @swagger
 * /reports/generate:
 *   post:
 *     summary: レポート生成
 *     description: 指定されたタイプのレポートを生成します
 *     tags: [Reports]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Report'
 *           examples:
 *             dailyReport:
 *               summary: 日次レポート例
 *               value:
 *                 type: daily
 *                 format: html
 *                 parameters:
 *                   includeDetails: true
 *             licenseAnalysis:
 *               summary: ライセンス分析例
 *               value:
 *                 type: license-analysis
 *                 format: csv
 *                 parameters:
 *                   dateRange: 30
 *     responses:
 *       202:
 *         description: レポート生成を開始しました
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 reportId:
 *                   type: string
 *                 statusUrl:
 *                   type: string
 *       400:
 *         description: 無効なリクエスト
 *       401:
 *         description: 認証が必要です
 *       500:
 *         description: サーバーエラー
 */
router.post('/generate',
  authenticate,
  [
    body('type').isIn(['daily', 'weekly', 'monthly', 'yearly', 'license-analysis', 'usage-analysis', 'performance-analysis', 'security-analysis']),
    body('format').isIn(['html', 'csv', 'pdf']),
    body('parameters').optional().isObject(),
    body('schedule').optional().isObject()
  ],
  generateReport
);

/**
 * @swagger
 * /reports/history:
 *   get:
 *     summary: レポート履歴取得
 *     description: 生成されたレポートの履歴を取得します
 *     tags: [Reports]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *         description: レポートタイプでフィルタ
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, running, completed, failed]
 *         description: ステータスでフィルタ
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: 取得件数
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *         description: オフセット
 *     responses:
 *       200:
 *         description: レポート履歴
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/ReportStatus'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     offset:
 *                       type: integer
 *       401:
 *         description: 認証が必要です
 */
router.get('/history',
  authenticate,
  [
    query('type').optional().isIn(['daily', 'weekly', 'monthly', 'yearly', 'license-analysis', 'usage-analysis', 'performance-analysis', 'security-analysis']),
    query('status').optional().isIn(['pending', 'running', 'completed', 'failed']),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('offset').optional().isInt({ min: 0 })
  ],
  getReportHistory
);

/**
 * @swagger
 * /reports/status/{reportId}:
 *   get:
 *     summary: レポートステータス取得
 *     description: 特定のレポートの進行状況を取得します
 *     tags: [Reports]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: reportId
 *         required: true
 *         schema:
 *           type: string
 *         description: レポートID
 *     responses:
 *       200:
 *         description: レポートステータス
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/ReportStatus'
 *       404:
 *         description: レポートが見つかりません
 *       401:
 *         description: 認証が必要です
 */
router.get('/status/:reportId',
  authenticate,
  [
    param('reportId').isUUID()
  ],
  getReportStatus
);

// バリデーションエラーハンドラー
router.use((req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }
  next();
});

export default router;