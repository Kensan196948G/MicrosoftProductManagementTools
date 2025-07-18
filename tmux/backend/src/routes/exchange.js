const express = require('express');
const { body, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');

const logger = require('../utils/logger');
const { asyncHandler, ValidationError } = require('../middleware/errorHandler');
const microsoft365Service = require('../services/microsoft365Service');

const router = express.Router();

// Rate limiting for Exchange endpoints
const exchangeLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 20, // 20 requests per window per IP
  message: {
    error: 'Too many Exchange requests, please try again later.'
  }
});

router.use(exchangeLimiter);

// Get mailboxes
router.get('/mailboxes', [
  query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1 and 1000'),
  query('skip').optional().isInt({ min: 0 }).withMessage('Skip must be a non-negative integer'),
  query('filter').optional().isString()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { limit = 100, skip = 0, filter } = req.query;

  try {
    const mailboxes = await microsoft365Service.getExchangeMailboxes({
      limit: parseInt(limit),
      skip: parseInt(skip),
      filter
    });

    logger.info('Retrieved Exchange mailboxes', {
      count: mailboxes.length,
      limit,
      skip,
      userId: req.user?.username
    });

    res.json({
      data: mailboxes,
      pagination: {
        limit: parseInt(limit),
        skip: parseInt(skip),
        count: mailboxes.length
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve Exchange mailboxes', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get mailbox usage statistics
router.get('/mailboxes/:mailboxId/usage', [
  query('days').optional().isInt({ min: 1, max: 365 }).withMessage('Days must be between 1 and 365')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { mailboxId } = req.params;
  const { days = 30 } = req.query;

  try {
    const usage = await microsoft365Service.getMailboxUsage(mailboxId, parseInt(days));

    logger.info('Retrieved mailbox usage', {
      mailboxId,
      days,
      userId: req.user?.username
    });

    res.json({
      mailboxId,
      period: `${days} days`,
      data: usage
    });
  } catch (error) {
    logger.error('Failed to retrieve mailbox usage', {
      error: error.message,
      mailboxId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get mail flow statistics
router.get('/mail-flow', [
  query('startDate').optional().isISO8601().withMessage('Invalid start date format'),
  query('endDate').optional().isISO8601().withMessage('Invalid end date format'),
  query('granularity').optional().isIn(['daily', 'weekly', 'monthly']).withMessage('Invalid granularity')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { startDate, endDate, granularity = 'daily' } = req.query;

  try {
    const mailFlow = await microsoft365Service.getMailFlowStatistics({
      startDate,
      endDate,
      granularity
    });

    logger.info('Retrieved mail flow statistics', {
      startDate,
      endDate,
      granularity,
      userId: req.user?.username
    });

    res.json({
      period: {
        startDate,
        endDate,
        granularity
      },
      data: mailFlow
    });
  } catch (error) {
    logger.error('Failed to retrieve mail flow statistics', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get spam detection reports
router.get('/security/spam', [
  query('days').optional().isInt({ min: 1, max: 90 }).withMessage('Days must be between 1 and 90'),
  query('severity').optional().isIn(['low', 'medium', 'high', 'all']).withMessage('Invalid severity level')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { days = 7, severity = 'all' } = req.query;

  try {
    const spamReport = await microsoft365Service.getSpamDetectionReport({
      days: parseInt(days),
      severity
    });

    logger.info('Retrieved spam detection report', {
      days,
      severity,
      userId: req.user?.username
    });

    res.json({
      period: `${days} days`,
      severity,
      data: spamReport
    });
  } catch (error) {
    logger.error('Failed to retrieve spam detection report', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get message trace
router.get('/message-trace', [
  query('senderAddress').optional().isEmail().withMessage('Invalid sender email'),
  query('recipientAddress').optional().isEmail().withMessage('Invalid recipient email'),
  query('startDate').isISO8601().withMessage('Invalid start date format'),
  query('endDate').isISO8601().withMessage('Invalid end date format'),
  query('messageId').optional().isString(),
  query('status').optional().isIn(['None', 'GettingStatus', 'Failed', 'Pending', 'Delivered', 'Expanded', 'Quarantined', 'FilteredAsSpam'])
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { senderAddress, recipientAddress, startDate, endDate, messageId, status } = req.query;

  try {
    const messageTrace = await microsoft365Service.getMessageTrace({
      senderAddress,
      recipientAddress,
      startDate,
      endDate,
      messageId,
      status
    });

    logger.info('Retrieved message trace', {
      senderAddress,
      recipientAddress,
      startDate,
      endDate,
      messageId,
      status,
      resultCount: messageTrace.length,
      userId: req.user?.username
    });

    res.json({
      criteria: {
        senderAddress,
        recipientAddress,
        startDate,
        endDate,
        messageId,
        status
      },
      data: messageTrace
    });
  } catch (error) {
    logger.error('Failed to retrieve message trace', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get transport rules
router.get('/transport-rules', asyncHandler(async (req, res) => {
  try {
    const transportRules = await microsoft365Service.getTransportRules();

    logger.info('Retrieved transport rules', {
      count: transportRules.length,
      userId: req.user?.username
    });

    res.json({
      data: transportRules
    });
  } catch (error) {
    logger.error('Failed to retrieve transport rules', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Create transport rule
router.post('/transport-rules', [
  body('name').notEmpty().withMessage('Rule name is required'),
  body('description').optional().isString(),
  body('conditions').isArray().withMessage('Conditions must be an array'),
  body('actions').isArray().withMessage('Actions must be an array'),
  body('enabled').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { name, description, conditions, actions, enabled = true } = req.body;

  try {
    const newRule = await microsoft365Service.createTransportRule({
      name,
      description,
      conditions,
      actions,
      enabled
    });

    logger.audit('Created transport rule', {
      ruleName: name,
      ruleId: newRule.id,
      userId: req.user?.username
    });

    res.status(201).json({
      message: 'Transport rule created successfully',
      data: newRule
    });
  } catch (error) {
    logger.error('Failed to create transport rule', {
      error: error.message,
      ruleName: name,
      userId: req.user?.username
    });
    throw error;
  }
}));

module.exports = router;