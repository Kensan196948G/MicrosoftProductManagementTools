import express from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { 
  getUsers, 
  getUserById, 
  getUserLicenses, 
  getUserMFAStatus, 
  getUserSignInLogs,
  updateUserSettings,
  getUserUsageReport
} from '../controllers/userController.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     User:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           description: ユーザーID
 *         displayName:
 *           type: string
 *           description: 表示名
 *         userPrincipalName:
 *           type: string
 *           description: ユーザープリンシパル名
 *         mail:
 *           type: string
 *           description: メールアドレス
 *         jobTitle:
 *           type: string
 *           description: 職位
 *         department:
 *           type: string
 *           description: 部署
 *         accountEnabled:
 *           type: boolean
 *           description: アカウント有効状態
 *         createdDateTime:
 *           type: string
 *           format: date-time
 *           description: 作成日時
 *         lastSignInDateTime:
 *           type: string
 *           format: date-time
 *           description: 最終サインイン日時
 *         mfaEnabled:
 *           type: boolean
 *           description: MFA有効状態
 *         licenses:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/License'
 *     License:
 *       type: object
 *       properties:
 *         skuId:
 *           type: string
 *           description: SKU ID
 *         displayName:
 *           type: string
 *           description: ライセンス名
 *         assignedDateTime:
 *           type: string
 *           format: date-time
 *           description: 割り当て日時
 *         status:
 *           type: string
 *           enum: [active, suspended, deleted]
 *           description: ライセンス状態
 *     SignInLog:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         createdDateTime:
 *           type: string
 *           format: date-time
 *         userPrincipalName:
 *           type: string
 *         appDisplayName:
 *           type: string
 *         ipAddress:
 *           type: string
 *         location:
 *           type: object
 *           properties:
 *             city:
 *               type: string
 *             state:
 *               type: string
 *             country:
 *               type: string
 *         status:
 *           type: object
 *           properties:
 *             signInStatus:
 *               type: string
 *               enum: [success, failure, interrupted]
 *             errorCode:
 *               type: integer
 *             failureReason:
 *               type: string
 *         deviceDetail:
 *           type: object
 *           properties:
 *             deviceId:
 *               type: string
 *             displayName:
 *               type: string
 *             operatingSystem:
 *               type: string
 *             browser:
 *               type: string
 */

/**
 * @swagger
 * /users:
 *   get:
 *     summary: ユーザー一覧取得
 *     description: Microsoft 365のユーザー一覧を取得します
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: filter
 *         schema:
 *           type: string
 *         description: フィルター条件（OData形式）
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: 検索キーワード
 *       - in: query
 *         name: department
 *         schema:
 *           type: string
 *         description: 部署でフィルタ
 *       - in: query
 *         name: enabled
 *         schema:
 *           type: boolean
 *         description: 有効なアカウントのみ
 *       - in: query
 *         name: mfaEnabled
 *         schema:
 *           type: boolean
 *         description: MFA有効ユーザーのみ
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
 *         description: ユーザー一覧
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
 *                     $ref: '#/components/schemas/User'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     offset:
 *                       type: integer
 *                     hasMore:
 *                       type: boolean
 *       401:
 *         description: 認証が必要です
 *       500:
 *         description: サーバーエラー
 */
router.get('/',
  authenticate,
  [
    query('filter').optional().isString(),
    query('search').optional().isString(),
    query('department').optional().isString(),
    query('enabled').optional().isBoolean(),
    query('mfaEnabled').optional().isBoolean(),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('offset').optional().isInt({ min: 0 })
  ],
  getUsers
);

/**
 * @swagger
 * /users/{userId}:
 *   get:
 *     summary: ユーザー詳細取得
 *     description: 特定のユーザーの詳細情報を取得します
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ユーザーID
 *     responses:
 *       200:
 *         description: ユーザー詳細
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/User'
 *       404:
 *         description: ユーザーが見つかりません
 *       401:
 *         description: 認証が必要です
 */
router.get('/:userId',
  authenticate,
  [
    param('userId').isString().notEmpty()
  ],
  getUserById
);

/**
 * @swagger
 * /users/{userId}/licenses:
 *   get:
 *     summary: ユーザーライセンス取得
 *     description: 特定のユーザーに割り当てられているライセンスを取得します
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ユーザーID
 *     responses:
 *       200:
 *         description: ユーザーライセンス
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
 *                     $ref: '#/components/schemas/License'
 *       404:
 *         description: ユーザーが見つかりません
 *       401:
 *         description: 認証が必要です
 */
router.get('/:userId/licenses',
  authenticate,
  [
    param('userId').isString().notEmpty()
  ],
  getUserLicenses
);

/**
 * @swagger
 * /users/{userId}/mfa-status:
 *   get:
 *     summary: ユーザーMFA状態取得
 *     description: 特定のユーザーのMFA設定状態を取得します
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ユーザーID
 *     responses:
 *       200:
 *         description: MFA状態
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     enabled:
 *                       type: boolean
 *                     methods:
 *                       type: array
 *                       items:
 *                         type: string
 *                     defaultMethod:
 *                       type: string
 *                     lastUpdate:
 *                       type: string
 *                       format: date-time
 *       404:
 *         description: ユーザーが見つかりません
 *       401:
 *         description: 認証が必要です
 */
router.get('/:userId/mfa-status',
  authenticate,
  [
    param('userId').isString().notEmpty()
  ],
  getUserMFAStatus
);

/**
 * @swagger
 * /users/{userId}/signin-logs:
 *   get:
 *     summary: ユーザーサインインログ取得
 *     description: 特定のユーザーのサインイン履歴を取得します
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ユーザーID
 *       - in: query
 *         name: days
 *         schema:
 *           type: integer
 *           default: 30
 *         description: 取得期間（日数）
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [success, failure, interrupted]
 *         description: ステータスでフィルタ
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 100
 *         description: 取得件数
 *     responses:
 *       200:
 *         description: サインインログ
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
 *                     $ref: '#/components/schemas/SignInLog'
 *                 summary:
 *                   type: object
 *                   properties:
 *                     totalSignIns:
 *                       type: integer
 *                     successfulSignIns:
 *                       type: integer
 *                     failedSignIns:
 *                       type: integer
 *                     uniqueApplications:
 *                       type: integer
 *                     uniqueLocations:
 *                       type: integer
 *       404:
 *         description: ユーザーが見つかりません
 *       401:
 *         description: 認証が必要です
 */
router.get('/:userId/signin-logs',
  authenticate,
  [
    param('userId').isString().notEmpty(),
    query('days').optional().isInt({ min: 1, max: 365 }),
    query('status').optional().isIn(['success', 'failure', 'interrupted']),
    query('limit').optional().isInt({ min: 1, max: 1000 })
  ],
  getUserSignInLogs
);

/**
 * @swagger
 * /users/{userId}/usage-report:
 *   get:
 *     summary: ユーザー使用状況レポート取得
 *     description: 特定のユーザーのMicrosoft 365サービス使用状況レポートを取得します
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ユーザーID
 *       - in: query
 *         name: period
 *         schema:
 *           type: string
 *           enum: [D7, D30, D90, D180]
 *           default: D30
 *         description: レポート期間
 *       - in: query
 *         name: services
 *         schema:
 *           type: string
 *         description: サービス指定（カンマ区切り）
 *     responses:
 *       200:
 *         description: 使用状況レポート
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     user:
 *                       $ref: '#/components/schemas/User'
 *                     period:
 *                       type: string
 *                     services:
 *                       type: object
 *                       properties:
 *                         teams:
 *                           type: object
 *                         onedrive:
 *                           type: object
 *                         exchange:
 *                           type: object
 *                         sharepoint:
 *                           type: object
 *                         skypeForBusiness:
 *                           type: object
 *       404:
 *         description: ユーザーが見つかりません
 *       401:
 *         description: 認証が必要です
 */
router.get('/:userId/usage-report',
  authenticate,
  [
    param('userId').isString().notEmpty(),
    query('period').optional().isIn(['D7', 'D30', 'D90', 'D180']),
    query('services').optional().isString()
  ],
  getUserUsageReport
);

/**
 * @swagger
 * /users/{userId}/settings:
 *   patch:
 *     summary: ユーザー設定更新
 *     description: 特定のユーザーの設定を更新します
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ユーザーID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               displayName:
 *                 type: string
 *                 description: 表示名
 *               jobTitle:
 *                 type: string
 *                 description: 職位
 *               department:
 *                 type: string
 *                 description: 部署
 *               officeLocation:
 *                 type: string
 *                 description: オフィスの場所
 *               mobilePhone:
 *                 type: string
 *                 description: 携帯電話番号
 *               businessPhones:
 *                 type: array
 *                 items:
 *                   type: string
 *                 description: ビジネス電話番号
 *     responses:
 *       200:
 *         description: 更新成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 data:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: 無効なリクエスト
 *       404:
 *         description: ユーザーが見つかりません
 *       401:
 *         description: 認証が必要です
 */
router.patch('/:userId/settings',
  authenticate,
  [
    param('userId').isString().notEmpty(),
    body('displayName').optional().isString(),
    body('jobTitle').optional().isString(),
    body('department').optional().isString(),
    body('officeLocation').optional().isString(),
    body('mobilePhone').optional().isString(),
    body('businessPhones').optional().isArray()
  ],
  updateUserSettings
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