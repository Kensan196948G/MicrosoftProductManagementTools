const express = require('express');
const { body, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const archiver = require('archiver');
const fs = require('fs').promises;
const path = require('path');

const logger = require('../utils/logger');
const { asyncHandler, ValidationError } = require('../middleware/errorHandler');
const microsoft365Service = require('../services/microsoft365Service');

const router = express.Router();

// Rate limiting for reports endpoints
const reportsLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 10, // 10 requests per window per IP (reports are resource intensive)
  message: {
    error: 'Too many report requests, please try again later.'
  }
});

router.use(reportsLimiter);

// Generate daily report
router.post('/daily', [
  body('date').optional().isISO8601().withMessage('Invalid date format'),
  body('sections').optional().isArray().withMessage('Sections must be an array'),
  body('format').optional().isIn(['json', 'csv', 'pdf', 'html']).withMessage('Invalid format'),
  body('includeCharts').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { 
    date = new Date().toISOString().split('T')[0], 
    sections = ['users', 'licenses', 'security', 'usage'], 
    format = 'json',
    includeCharts = false 
  } = req.body;

  try {
    const report = await microsoft365Service.generateDailyReport({
      date,
      sections,
      format,
      includeCharts
    });

    logger.audit('Generated daily report', {
      date,
      sections,
      format,
      includeCharts,
      reportSize: JSON.stringify(report).length,
      userId: req.user?.username
    });

    // Set appropriate content type based on format
    switch (format) {
      case 'csv':
        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="daily-report-${date}.csv"`);
        break;
      case 'pdf':
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename="daily-report-${date}.pdf"`);
        break;
      case 'html':
        res.setHeader('Content-Type', 'text/html');
        break;
      default:
        res.setHeader('Content-Type', 'application/json');
    }

    res.json({
      reportType: 'daily',
      generatedAt: new Date().toISOString(),
      reportDate: date,
      sections,
      format,
      data: report
    });
  } catch (error) {
    logger.error('Failed to generate daily report', {
      error: error.message,
      date,
      sections,
      format,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Generate weekly report
router.post('/weekly', [
  body('weekStartDate').optional().isISO8601().withMessage('Invalid week start date format'),
  body('sections').optional().isArray().withMessage('Sections must be an array'),
  body('format').optional().isIn(['json', 'csv', 'pdf', 'html']).withMessage('Invalid format'),
  body('includeComparisons').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { 
    weekStartDate, 
    sections = ['usage', 'security', 'collaboration', 'storage'], 
    format = 'json',
    includeComparisons = true 
  } = req.body;

  try {
    const report = await microsoft365Service.generateWeeklyReport({
      weekStartDate,
      sections,
      format,
      includeComparisons
    });

    logger.audit('Generated weekly report', {
      weekStartDate,
      sections,
      format,
      includeComparisons,
      userId: req.user?.username
    });

    res.json({
      reportType: 'weekly',
      generatedAt: new Date().toISOString(),
      weekStartDate,
      sections,
      format,
      data: report
    });
  } catch (error) {
    logger.error('Failed to generate weekly report', {
      error: error.message,
      weekStartDate,
      sections,
      format,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Generate monthly report
router.post('/monthly', [
  body('month').optional().matches(/^\d{4}-\d{2}$/).withMessage('Month must be in YYYY-MM format'),
  body('sections').optional().isArray().withMessage('Sections must be an array'),
  body('format').optional().isIn(['json', 'csv', 'pdf', 'html']).withMessage('Invalid format'),
  body('includeTrends').optional().isBoolean(),
  body('includeExecutiveSummary').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { 
    month = new Date().toISOString().substring(0, 7), 
    sections = ['overview', 'usage', 'security', 'compliance', 'costs'], 
    format = 'json',
    includeTrends = true,
    includeExecutiveSummary = true 
  } = req.body;

  try {
    const report = await microsoft365Service.generateMonthlyReport({
      month,
      sections,
      format,
      includeTrends,
      includeExecutiveSummary
    });

    logger.audit('Generated monthly report', {
      month,
      sections,
      format,
      includeTrends,
      includeExecutiveSummary,
      userId: req.user?.username
    });

    res.json({
      reportType: 'monthly',
      generatedAt: new Date().toISOString(),
      month,
      sections,
      format,
      data: report
    });
  } catch (error) {
    logger.error('Failed to generate monthly report', {
      error: error.message,
      month,
      sections,
      format,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Generate custom report
router.post('/custom', [
  body('reportName').notEmpty().withMessage('Report name is required'),
  body('startDate').isISO8601().withMessage('Invalid start date format'),
  body('endDate').isISO8601().withMessage('Invalid end date format'),
  body('dataTypes').isArray().withMessage('Data types must be an array'),
  body('filters').optional().isObject(),
  body('format').optional().isIn(['json', 'csv', 'pdf', 'html']).withMessage('Invalid format'),
  body('groupBy').optional().isString(),
  body('aggregation').optional().isIn(['sum', 'avg', 'count', 'min', 'max']).withMessage('Invalid aggregation type')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { 
    reportName, 
    startDate, 
    endDate, 
    dataTypes, 
    filters = {}, 
    format = 'json',
    groupBy,
    aggregation 
  } = req.body;

  try {
    const report = await microsoft365Service.generateCustomReport({
      reportName,
      startDate,
      endDate,
      dataTypes,
      filters,
      format,
      groupBy,
      aggregation
    });

    logger.audit('Generated custom report', {
      reportName,
      startDate,
      endDate,
      dataTypes,
      filters,
      format,
      groupBy,
      aggregation,
      userId: req.user?.username
    });

    res.json({
      reportType: 'custom',
      reportName,
      generatedAt: new Date().toISOString(),
      period: {
        startDate,
        endDate
      },
      dataTypes,
      filters,
      format,
      data: report
    });
  } catch (error) {
    logger.error('Failed to generate custom report', {
      error: error.message,
      reportName,
      startDate,
      endDate,
      dataTypes,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get report templates
router.get('/templates', asyncHandler(async (req, res) => {
  try {
    const templates = await microsoft365Service.getReportTemplates();

    logger.info('Retrieved report templates', {
      count: templates.length,
      userId: req.user?.username
    });

    res.json({
      data: templates
    });
  } catch (error) {
    logger.error('Failed to retrieve report templates', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Save report template
router.post('/templates', [
  body('name').notEmpty().withMessage('Template name is required'),
  body('description').optional().isString(),
  body('configuration').isObject().withMessage('Configuration is required'),
  body('category').optional().isString(),
  body('tags').optional().isArray()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { name, description, configuration, category, tags = [] } = req.body;

  try {
    const template = await microsoft365Service.saveReportTemplate({
      name,
      description,
      configuration,
      category,
      tags,
      createdBy: req.user?.username
    });

    logger.audit('Saved report template', {
      templateName: name,
      templateId: template.id,
      category,
      userId: req.user?.username
    });

    res.status(201).json({
      message: 'Report template saved successfully',
      data: template
    });
  } catch (error) {
    logger.error('Failed to save report template', {
      error: error.message,
      templateName: name,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get report history
router.get('/history', [
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('skip').optional().isInt({ min: 0 }).withMessage('Skip must be a non-negative integer'),
  query('reportType').optional().isIn(['daily', 'weekly', 'monthly', 'custom']).withMessage('Invalid report type'),
  query('startDate').optional().isISO8601().withMessage('Invalid start date format'),
  query('endDate').optional().isISO8601().withMessage('Invalid end date format')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { limit = 50, skip = 0, reportType, startDate, endDate } = req.query;

  try {
    const history = await microsoft365Service.getReportHistory({
      limit: parseInt(limit),
      skip: parseInt(skip),
      reportType,
      startDate,
      endDate,
      userId: req.user?.username
    });

    logger.info('Retrieved report history', {
      limit,
      skip,
      reportType,
      startDate,
      endDate,
      count: history.length,
      userId: req.user?.username
    });

    res.json({
      pagination: {
        limit: parseInt(limit),
        skip: parseInt(skip),
        count: history.length
      },
      filters: {
        reportType,
        startDate,
        endDate
      },
      data: history
    });
  } catch (error) {
    logger.error('Failed to retrieve report history', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Download report archive
router.get('/download/:reportId', asyncHandler(async (req, res) => {
  const { reportId } = req.params;

  try {
    const reportData = await microsoft365Service.getReportById(reportId);
    
    if (!reportData) {
      return res.status(404).json({
        error: 'Report not found'
      });
    }

    // Create ZIP archive with report files
    const archive = archiver('zip', {
      zlib: { level: 9 }
    });

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="report-${reportId}.zip"`);

    archive.pipe(res);

    // Add report data as JSON
    archive.append(JSON.stringify(reportData, null, 2), { name: 'report.json' });

    // Add CSV version if available
    if (reportData.csvData) {
      archive.append(reportData.csvData, { name: 'report.csv' });
    }

    // Add HTML version if available
    if (reportData.htmlData) {
      archive.append(reportData.htmlData, { name: 'report.html' });
    }

    await archive.finalize();

    logger.audit('Downloaded report archive', {
      reportId,
      userId: req.user?.username
    });
  } catch (error) {
    logger.error('Failed to download report archive', {
      error: error.message,
      reportId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Schedule report generation
router.post('/schedule', [
  body('reportType').isIn(['daily', 'weekly', 'monthly']).withMessage('Invalid report type'),
  body('schedule').notEmpty().withMessage('Schedule is required'),
  body('recipients').isArray().withMessage('Recipients must be an array'),
  body('configuration').isObject().withMessage('Configuration is required'),
  body('enabled').optional().isBoolean()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { reportType, schedule, recipients, configuration, enabled = true } = req.body;

  try {
    const scheduledReport = await microsoft365Service.scheduleReport({
      reportType,
      schedule,
      recipients,
      configuration,
      enabled,
      createdBy: req.user?.username
    });

    logger.audit('Scheduled report generation', {
      reportType,
      schedule,
      recipients: recipients.length,
      scheduleId: scheduledReport.id,
      userId: req.user?.username
    });

    res.status(201).json({
      message: 'Report scheduled successfully',
      data: scheduledReport
    });
  } catch (error) {
    logger.error('Failed to schedule report', {
      error: error.message,
      reportType,
      schedule,
      userId: req.user?.username
    });
    throw error;
  }
}));

module.exports = router;