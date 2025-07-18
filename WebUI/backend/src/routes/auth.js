import express from 'express';
import { body, validationResult } from 'express-validator';
import { login, refresh, logout, validate } from '../controllers/authController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     LoginRequest:
 *       type: object
 *       required:
 *         - authMethod
 *       properties:
 *         authMethod:
 *           type: string
 *           enum: [certificate, client-secret, interactive]
 *           description: 認証方法
 *         tenantId:
 *           type: string
 *           description: テナントID
 *         clientId:
 *           type: string
 *           description: クライアントID
 *         clientSecret:
 *           type: string
 *           description: クライアントシークレット（client-secret認証時）
 *         certificatePath:
 *           type: string
 *           description: 証明書パス（certificate認証時）
 *         certificatePassword:
 *           type: string
 *           description: 証明書パスワード（certificate認証時）
 *     AuthResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         token:
 *           type: string
 *           description: JWTトークン
 *         refreshToken:
 *           type: string
 *           description: リフレッシュトークン
 *         expiresIn:
 *           type: number
 *           description: トークン有効期限（秒）
 *         user:
 *           type: object
 *           properties:
 *             id:
 *               type: string
 *             name:
 *               type: string
 *             email:
 *               type: string
 *             tenantId:
 *               type: string
 */

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: ログイン
 *     description: Microsoft 365認証を使用してAPIにログインします
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/LoginRequest'
 *           examples:
 *             certificate:
 *               summary: 証明書認証
 *               value:
 *                 authMethod: certificate
 *                 tenantId: "your-tenant-id"
 *                 clientId: "your-client-id"
 *                 certificatePath: "/path/to/certificate.pfx"
 *                 certificatePassword: "cert-password"
 *             clientSecret:
 *               summary: クライアントシークレット認証
 *               value:
 *                 authMethod: client-secret
 *                 tenantId: "your-tenant-id"
 *                 clientId: "your-client-id"
 *                 clientSecret: "your-client-secret"
 *     responses:
 *       200:
 *         description: ログイン成功
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: 無効なリクエスト
 *       401:
 *         description: 認証失敗
 *       500:
 *         description: サーバーエラー
 */
router.post('/login',
  [
    body('authMethod').isIn(['certificate', 'client-secret', 'interactive']),
    body('tenantId').optional().isString(),
    body('clientId').optional().isString(),
    body('clientSecret').optional().isString(),
    body('certificatePath').optional().isString(),
    body('certificatePassword').optional().isString()
  ],
  login
);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: トークンリフレッシュ
 *     description: リフレッシュトークンを使用してアクセストークンを更新します
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *                 description: リフレッシュトークン
 *     responses:
 *       200:
 *         description: トークンリフレッシュ成功
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: 無効なリクエスト
 *       401:
 *         description: 無効なリフレッシュトークン
 *       500:
 *         description: サーバーエラー
 */
router.post('/refresh',
  [
    body('refreshToken').isString().notEmpty()
  ],
  refresh
);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: ログアウト
 *     description: セッションを終了してトークンを無効化します
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: ログアウト成功
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       401:
 *         description: 認証が必要です
 *       500:
 *         description: サーバーエラー
 */
router.post('/logout',
  authenticate,
  logout
);

/**
 * @swagger
 * /auth/validate:
 *   get:
 *     summary: トークン検証
 *     description: 現在のトークンが有効かどうかを検証します
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: トークン有効
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 valid:
 *                   type: boolean
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     name:
 *                       type: string
 *                     email:
 *                       type: string
 *                     tenantId:
 *                       type: string
 *                 expiresAt:
 *                   type: string
 *                   format: date-time
 *       401:
 *         description: 無効なトークン
 *       500:
 *         description: サーバーエラー
 */
router.get('/validate',
  authenticate,
  validate
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