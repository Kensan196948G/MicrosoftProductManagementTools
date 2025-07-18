const express = require('express');
const { body, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');

const logger = require('../utils/logger');
const { asyncHandler, ValidationError } = require('../middleware/errorHandler');
const microsoft365Service = require('../services/microsoft365Service');

const router = express.Router();

// Rate limiting for OneDrive endpoints
const onedriveLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 30, // 30 requests per window per IP
  message: {
    error: 'Too many OneDrive requests, please try again later.'
  }
});

router.use(onedriveLimiter);

// Get OneDrive usage statistics
router.get('/usage', [
  query('period').optional().isIn(['7', '30', '90', '180']).withMessage('Period must be 7, 30, 90, or 180 days'),
  query('userType').optional().isIn(['all', 'internal', 'external']).withMessage('Invalid user type')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { period = '30', userType = 'all' } = req.query;

  try {
    const usage = await microsoft365Service.getOneDriveUsageStatistics({
      period: parseInt(period),
      userType
    });

    logger.info('Retrieved OneDrive usage statistics', {
      period,
      userType,
      userId: req.user?.username
    });

    res.json({
      period: `${period} days`,
      userType,
      data: usage
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive usage statistics', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get OneDrive storage usage
router.get('/storage', [
  query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1 and 1000'),
  query('skip').optional().isInt({ min: 0 }).withMessage('Skip must be a non-negative integer'),
  query('sortBy').optional().isIn(['storageUsed', 'lastActivity', 'userName']).withMessage('Invalid sort field'),
  query('sortOrder').optional().isIn(['asc', 'desc']).withMessage('Sort order must be asc or desc')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { limit = 100, skip = 0, sortBy = 'storageUsed', sortOrder = 'desc' } = req.query;

  try {
    const storageData = await microsoft365Service.getOneDriveStorageUsage({
      limit: parseInt(limit),
      skip: parseInt(skip),
      sortBy,
      sortOrder
    });

    logger.info('Retrieved OneDrive storage usage', {
      limit,
      skip,
      sortBy,
      sortOrder,
      count: storageData.length,
      userId: req.user?.username
    });

    res.json({
      pagination: {
        limit: parseInt(limit),
        skip: parseInt(skip),
        count: storageData.length
      },
      sorting: {
        sortBy,
        sortOrder
      },
      data: storageData
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive storage usage', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get OneDrive sharing activity
router.get('/sharing', [
  query('period').optional().isIn(['7', '30', '90', '180']).withMessage('Period must be 7, 30, 90, or 180 days'),
  query('sharingType').optional().isIn(['all', 'internal', 'external', 'anonymous']).withMessage('Invalid sharing type'),
  query('fileType').optional().isIn(['all', 'documents', 'spreadsheets', 'presentations', 'images', 'videos', 'other']).withMessage('Invalid file type')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { period = '30', sharingType = 'all', fileType = 'all' } = req.query;

  try {
    const sharingActivity = await microsoft365Service.getOneDriveSharingActivity({
      period: parseInt(period),
      sharingType,
      fileType
    });

    logger.info('Retrieved OneDrive sharing activity', {
      period,
      sharingType,
      fileType,
      userId: req.user?.username
    });

    res.json({
      period: `${period} days`,
      filters: {
        sharingType,
        fileType
      },
      data: sharingActivity
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive sharing activity', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get OneDrive sync errors
router.get('/sync-errors', [
  query('period').optional().isIn(['7', '30', '90']).withMessage('Period must be 7, 30, or 90 days'),
  query('errorType').optional().isIn(['all', 'sync', 'upload', 'download', 'conflict']).withMessage('Invalid error type'),
  query('severity').optional().isIn(['all', 'low', 'medium', 'high']).withMessage('Invalid severity level')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { period = '7', errorType = 'all', severity = 'all' } = req.query;

  try {
    const syncErrors = await microsoft365Service.getOneDriveSyncErrors({
      period: parseInt(period),
      errorType,
      severity
    });

    logger.info('Retrieved OneDrive sync errors', {
      period,
      errorType,
      severity,
      count: syncErrors.length,
      userId: req.user?.username
    });

    res.json({
      period: `${period} days`,
      filters: {
        errorType,
        severity
      },
      data: syncErrors
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive sync errors', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get external sharing report
router.get('/external-sharing', [
  query('period').optional().isIn(['7', '30', '90', '180']).withMessage('Period must be 7, 30, 90, or 180 days'),
  query('includeAnonymous').optional().isBoolean(),
  query('domain').optional().isString(),
  query('riskLevel').optional().isIn(['all', 'low', 'medium', 'high']).withMessage('Invalid risk level')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { period = '30', includeAnonymous = true, domain, riskLevel = 'all' } = req.query;

  try {
    const externalSharing = await microsoft365Service.getOneDriveExternalSharing({
      period: parseInt(period),
      includeAnonymous: includeAnonymous === 'true',
      domain,
      riskLevel
    });

    logger.info('Retrieved OneDrive external sharing report', {
      period,
      includeAnonymous,
      domain,
      riskLevel,
      count: externalSharing.length,
      userId: req.user?.username
    });

    res.json({
      period: `${period} days`,
      filters: {
        includeAnonymous: includeAnonymous === 'true',
        domain,
        riskLevel
      },
      data: externalSharing
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive external sharing report', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get file activity details
router.get('/file-activity', [
  query('fileId').optional().isString(),
  query('userId').optional().isString(),
  query('startDate').optional().isISO8601().withMessage('Invalid start date format'),
  query('endDate').optional().isISO8601().withMessage('Invalid end date format'),
  query('activityType').optional().isIn(['all', 'viewed', 'edited', 'shared', 'downloaded', 'renamed', 'moved', 'deleted']).withMessage('Invalid activity type'),
  query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1 and 1000')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { fileId, userId, startDate, endDate, activityType = 'all', limit = 100 } = req.query;

  try {
    const fileActivity = await microsoft365Service.getOneDriveFileActivity({
      fileId,
      userId,
      startDate,
      endDate,
      activityType,
      limit: parseInt(limit)
    });

    logger.info('Retrieved OneDrive file activity', {
      fileId,
      userId,
      startDate,
      endDate,
      activityType,
      limit,
      count: fileActivity.length,
      userId: req.user?.username
    });

    res.json({
      filters: {
        fileId,
        userId,
        startDate,
        endDate,
        activityType,
        limit: parseInt(limit)
      },
      data: fileActivity
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive file activity', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get OneDrive quota and usage by user
router.get('/users/:userId/quota', asyncHandler(async (req, res) => {
  const { userId } = req.params;

  try {
    const quotaInfo = await microsoft365Service.getOneDriveUserQuota(userId);

    logger.info('Retrieved OneDrive user quota', {
      userId,
      quota: quotaInfo.quota,
      used: quotaInfo.used,
      remaining: quotaInfo.remaining,
      userId: req.user?.username
    });

    res.json({
      userId,
      data: quotaInfo
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive user quota', {
      error: error.message,
      userId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get OneDrive compliance policies
router.get('/compliance-policies', [
  query('policyType').optional().isIn(['all', 'retention', 'dlp', 'audit']).withMessage('Invalid policy type'),
  query('status').optional().isIn(['all', 'enabled', 'disabled']).withMessage('Invalid status')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { policyType = 'all', status = 'all' } = req.query;

  try {
    const policies = await microsoft365Service.getOneDriveCompliancePolicies({
      policyType,
      status
    });

    logger.info('Retrieved OneDrive compliance policies', {
      policyType,
      status,
      count: policies.length,
      userId: req.user?.username
    });

    res.json({
      filters: {
        policyType,
        status
      },
      data: policies
    });
  } catch (error) {
    logger.error('Failed to retrieve OneDrive compliance policies', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Update OneDrive sharing settings
router.put('/sharing-settings', [
  body('defaultSharingLinkType').optional().isIn(['view', 'edit', 'none']).withMessage('Invalid sharing link type'),
  body('externalSharingEnabled').optional().isBoolean(),
  body('anonymousSharingEnabled').optional().isBoolean(),
  body('requireSignInForAnonymousAccess').optional().isBoolean(),
  body('defaultLinkExpiration').optional().isInt({ min: 1, max: 365 }).withMessage('Expiration must be between 1 and 365 days')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const settings = req.body;

  try {
    const updatedSettings = await microsoft365Service.updateOneDriveSharingSettings(settings);

    logger.audit('Updated OneDrive sharing settings', {
      settings,
      userId: req.user?.username
    });

    res.json({
      message: 'OneDrive sharing settings updated successfully',
      data: updatedSettings
    });
  } catch (error) {
    logger.error('Failed to update OneDrive sharing settings', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

module.exports = router;