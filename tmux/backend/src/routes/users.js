const express = require('express');
const { query, param } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');
const { readAccess } = require('../middleware/auth');
const Microsoft365Service = require('../services/microsoft365Service');
const PowerShellService = require('../services/powershellService');
const logger = require('../utils/logger');

const router = express.Router();

// Initialize services
const ms365Service = new Microsoft365Service();
const powershellService = new PowerShellService();

// Validation middleware
const getUsersValidation = [
  query('top').optional().isInt({ min: 1, max: 999 }).withMessage('Top must be between 1 and 999'),
  query('skip').optional().isInt({ min: 0 }).withMessage('Skip must be non-negative'),
  query('filter').optional().isString().withMessage('Filter must be a string'),
  query('select').optional().isString().withMessage('Select must be a string'),
  query('source').optional().isIn(['graph', 'powershell']).withMessage('Source must be graph or powershell')
];

const getUserValidation = [
  param('id').notEmpty().withMessage('User ID is required')
];

// Get all users
router.get('/', readAccess, getUsersValidation, asyncHandler(async (req, res) => {
  const { top = 100, skip = 0, filter, select, source = 'graph' } = req.query;
  
  try {
    let users;
    
    if (source === 'powershell') {
      // Use PowerShell module for data retrieval
      users = await powershellService.getAllUsers();
      
      // Apply pagination if needed
      if (skip > 0 || top < users.length) {
        users = users.slice(skip, skip + parseInt(top));
      }
    } else {
      // Use Microsoft Graph API
      users = await ms365Service.getUsers({
        top: parseInt(top),
        skip: parseInt(skip),
        filter,
        select
      });
    }
    
    logger.info('Users retrieved successfully', {
      count: users.value?.length || users.length,
      source,
      user: req.user.username
    });
    
    res.json({
      data: users.value || users,
      pagination: {
        top: parseInt(top),
        skip: parseInt(skip),
        total: users['@odata.count'] || users.length
      },
      metadata: {
        source,
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve users', {
      error: error.message,
      source,
      user: req.user.username
    });
    throw error;
  }
}));

// Get user by ID
router.get('/:id', readAccess, getUserValidation, asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  try {
    const user = await ms365Service.getUserById(id);
    
    logger.info('User retrieved successfully', {
      userId: id,
      user: req.user.username
    });
    
    res.json({
      data: user,
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve user', {
      userId: id,
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

// Get user's manager
router.get('/:id/manager', readAccess, getUserValidation, asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  try {
    const manager = await ms365Service.getUserManager(id);
    
    logger.info('User manager retrieved successfully', {
      userId: id,
      user: req.user.username
    });
    
    res.json({
      data: manager,
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve user manager', {
      userId: id,
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

// Get user's direct reports
router.get('/:id/directReports', readAccess, getUserValidation, asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  try {
    const directReports = await ms365Service.getUserDirectReports(id);
    
    logger.info('User direct reports retrieved successfully', {
      userId: id,
      count: directReports.value?.length || 0,
      user: req.user.username
    });
    
    res.json({
      data: directReports.value || directReports,
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve user direct reports', {
      userId: id,
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

// Get MFA status for all users
router.get('/mfa/status', readAccess, asyncHandler(async (req, res) => {
  const { source = 'powershell' } = req.query;
  
  try {
    let mfaStatus;
    
    if (source === 'powershell') {
      mfaStatus = await powershellService.getMfaStatus();
    } else {
      // For Graph API, we need to get authentication methods for each user
      const users = await ms365Service.getUsers();
      mfaStatus = [];
      
      for (const user of users.value || []) {
        try {
          const authMethods = await ms365Service.getMfaAuthenticationMethods(user.id);
          mfaStatus.push({
            userId: user.id,
            userPrincipalName: user.userPrincipalName,
            displayName: user.displayName,
            mfaEnabled: authMethods.value?.length > 0,
            authMethods: authMethods.value
          });
        } catch (error) {
          logger.warn('Failed to get MFA status for user', {
            userId: user.id,
            error: error.message
          });
        }
      }
    }
    
    logger.info('MFA status retrieved successfully', {
      count: mfaStatus.length,
      source,
      user: req.user.username
    });
    
    res.json({
      data: mfaStatus,
      metadata: {
        source,
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve MFA status', {
      error: error.message,
      source,
      user: req.user.username
    });
    throw error;
  }
}));

// Get user's MFA authentication methods
router.get('/:id/mfa/methods', readAccess, getUserValidation, asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  try {
    const authMethods = await ms365Service.getMfaAuthenticationMethods(id);
    
    logger.info('User MFA methods retrieved successfully', {
      userId: id,
      count: authMethods.value?.length || 0,
      user: req.user.username
    });
    
    res.json({
      data: authMethods.value || authMethods,
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve user MFA methods', {
      userId: id,
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

// Get sign-in logs
router.get('/signin/logs', readAccess, asyncHandler(async (req, res) => {
  const { top = 100, filter, source = 'powershell' } = req.query;
  
  try {
    let signInLogs;
    
    if (source === 'powershell') {
      signInLogs = await powershellService.getSignInLogs();
      
      // Apply pagination if needed
      if (top && signInLogs.length > top) {
        signInLogs = signInLogs.slice(0, parseInt(top));
      }
    } else {
      signInLogs = await ms365Service.getSignInLogs({
        top: parseInt(top),
        filter
      });
    }
    
    logger.info('Sign-in logs retrieved successfully', {
      count: signInLogs.value?.length || signInLogs.length,
      source,
      user: req.user.username
    });
    
    res.json({
      data: signInLogs.value || signInLogs,
      metadata: {
        source,
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve sign-in logs', {
      error: error.message,
      source,
      user: req.user.username
    });
    throw error;
  }
}));

// Get user statistics
router.get('/statistics/summary', readAccess, asyncHandler(async (req, res) => {
  try {
    const users = await ms365Service.getUsers({ top: 999 });
    const allUsers = users.value || users;
    
    // Calculate statistics
    const stats = {
      totalUsers: allUsers.length,
      activeUsers: allUsers.filter(u => u.accountEnabled).length,
      inactiveUsers: allUsers.filter(u => !u.accountEnabled).length,
      guestUsers: allUsers.filter(u => u.userType === 'Guest').length,
      memberUsers: allUsers.filter(u => u.userType === 'Member').length,
      usersWithMail: allUsers.filter(u => u.mail).length,
      usersWithManager: 0, // Will be calculated separately
      departmentDistribution: {},
      jobTitleDistribution: {}
    };
    
    // Calculate department and job title distributions
    allUsers.forEach(user => {
      if (user.department) {
        stats.departmentDistribution[user.department] = (stats.departmentDistribution[user.department] || 0) + 1;
      }
      if (user.jobTitle) {
        stats.jobTitleDistribution[user.jobTitle] = (stats.jobTitleDistribution[user.jobTitle] || 0) + 1;
      }
    });
    
    logger.info('User statistics retrieved successfully', {
      totalUsers: stats.totalUsers,
      user: req.user.username
    });
    
    res.json({
      data: stats,
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve user statistics', {
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

module.exports = router;