const express = require('express');
const { body, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');

const logger = require('../utils/logger');
const { asyncHandler, ValidationError } = require('../middleware/errorHandler');
const microsoft365Service = require('../services/microsoft365Service');

const router = express.Router();

// Rate limiting for Teams endpoints
const teamsLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 25, // 25 requests per window per IP
  message: {
    error: 'Too many Teams requests, please try again later.'
  }
});

router.use(teamsLimiter);

// Get Teams usage statistics
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
    const usage = await microsoft365Service.getTeamsUsageStatistics({
      period: parseInt(period),
      userType
    });

    logger.info('Retrieved Teams usage statistics', {
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
    logger.error('Failed to retrieve Teams usage statistics', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get Teams user activity
router.get('/user-activity', [
  query('period').optional().isIn(['7', '30', '90', '180']).withMessage('Period must be 7, 30, 90, or 180 days'),
  query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1 and 1000'),
  query('skip').optional().isInt({ min: 0 }).withMessage('Skip must be a non-negative integer')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { period = '30', limit = 100, skip = 0 } = req.query;

  try {
    const userActivity = await microsoft365Service.getTeamsUserActivity({
      period: parseInt(period),
      limit: parseInt(limit),
      skip: parseInt(skip)
    });

    logger.info('Retrieved Teams user activity', {
      period,
      limit,
      skip,
      count: userActivity.length,
      userId: req.user?.username
    });

    res.json({
      period: `${period} days`,
      pagination: {
        limit: parseInt(limit),
        skip: parseInt(skip),
        count: userActivity.length
      },
      data: userActivity
    });
  } catch (error) {
    logger.error('Failed to retrieve Teams user activity', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get Teams device usage
router.get('/device-usage', [
  query('period').optional().isIn(['7', '30', '90', '180']).withMessage('Period must be 7, 30, 90, or 180 days')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { period = '30' } = req.query;

  try {
    const deviceUsage = await microsoft365Service.getTeamsDeviceUsage({
      period: parseInt(period)
    });

    logger.info('Retrieved Teams device usage', {
      period,
      userId: req.user?.username
    });

    res.json({
      period: `${period} days`,
      data: deviceUsage
    });
  } catch (error) {
    logger.error('Failed to retrieve Teams device usage', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get Teams meetings
router.get('/meetings', [
  query('startDate').optional().isISO8601().withMessage('Invalid start date format'),
  query('endDate').optional().isISO8601().withMessage('Invalid end date format'),
  query('organizerId').optional().isString(),
  query('limit').optional().isInt({ min: 1, max: 500 }).withMessage('Limit must be between 1 and 500')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { startDate, endDate, organizerId, limit = 100 } = req.query;

  try {
    const meetings = await microsoft365Service.getTeamsMeetings({
      startDate,
      endDate,
      organizerId,
      limit: parseInt(limit)
    });

    logger.info('Retrieved Teams meetings', {
      startDate,
      endDate,
      organizerId,
      limit,
      count: meetings.length,
      userId: req.user?.username
    });

    res.json({
      criteria: {
        startDate,
        endDate,
        organizerId,
        limit: parseInt(limit)
      },
      data: meetings
    });
  } catch (error) {
    logger.error('Failed to retrieve Teams meetings', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get meeting quality data
router.get('/meetings/:meetingId/quality', asyncHandler(async (req, res) => {
  const { meetingId } = req.params;

  try {
    const qualityData = await microsoft365Service.getMeetingQuality(meetingId);

    logger.info('Retrieved meeting quality data', {
      meetingId,
      userId: req.user?.username
    });

    res.json({
      meetingId,
      data: qualityData
    });
  } catch (error) {
    logger.error('Failed to retrieve meeting quality data', {
      error: error.message,
      meetingId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get Teams apps usage
router.get('/apps-usage', [
  query('period').optional().isIn(['7', '30', '90', '180']).withMessage('Period must be 7, 30, 90, or 180 days'),
  query('appType').optional().isIn(['all', 'bots', 'tabs', 'connectors', 'messaging-extensions']).withMessage('Invalid app type')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { period = '30', appType = 'all' } = req.query;

  try {
    const appsUsage = await microsoft365Service.getTeamsAppsUsage({
      period: parseInt(period),
      appType
    });

    logger.info('Retrieved Teams apps usage', {
      period,
      appType,
      userId: req.user?.username
    });

    res.json({
      period: `${period} days`,
      appType,
      data: appsUsage
    });
  } catch (error) {
    logger.error('Failed to retrieve Teams apps usage', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get Teams configurations
router.get('/configurations', [
  query('teamId').optional().isString(),
  query('includeArchived').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { teamId, includeArchived = false } = req.query;

  try {
    const configurations = await microsoft365Service.getTeamsConfigurations({
      teamId,
      includeArchived: includeArchived === 'true'
    });

    logger.info('Retrieved Teams configurations', {
      teamId,
      includeArchived,
      count: configurations.length,
      userId: req.user?.username
    });

    res.json({
      filters: {
        teamId,
        includeArchived: includeArchived === 'true'
      },
      data: configurations
    });
  } catch (error) {
    logger.error('Failed to retrieve Teams configurations', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Update Teams configuration
router.put('/configurations/:teamId', [
  body('allowGuestAccess').optional().isBoolean(),
  body('allowMemberAddRemoveApps').optional().isBoolean(),
  body('allowMemberCreateUpdateChannels').optional().isBoolean(),
  body('allowMemberCreatePrivateChannels').optional().isBoolean(),
  body('allowOwnerDeleteMessages').optional().isBoolean(),
  body('allowUserEditMessages').optional().isBoolean(),
  body('allowUserDeleteMessages').optional().isBoolean(),
  body('allowTeamMentions').optional().isBoolean(),
  body('allowChannelMentions').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { teamId } = req.params;
  const updates = req.body;

  try {
    const updatedConfig = await microsoft365Service.updateTeamsConfiguration(teamId, updates);

    logger.audit('Updated Teams configuration', {
      teamId,
      updates,
      userId: req.user?.username
    });

    res.json({
      message: 'Teams configuration updated successfully',
      teamId,
      data: updatedConfig
    });
  } catch (error) {
    logger.error('Failed to update Teams configuration', {
      error: error.message,
      teamId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get Teams channels
router.get('/:teamId/channels', [
  query('includePrivate').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { teamId } = req.params;
  const { includePrivate = false } = req.query;

  try {
    const channels = await microsoft365Service.getTeamsChannels(teamId, {
      includePrivate: includePrivate === 'true'
    });

    logger.info('Retrieved Teams channels', {
      teamId,
      includePrivate,
      count: channels.length,
      userId: req.user?.username
    });

    res.json({
      teamId,
      includePrivate: includePrivate === 'true',
      data: channels
    });
  } catch (error) {
    logger.error('Failed to retrieve Teams channels', {
      error: error.message,
      teamId,
      userId: req.user?.username
    });
    throw error;
  }
}));

module.exports = router;