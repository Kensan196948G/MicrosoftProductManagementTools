const express = require('express');
const { query } = require('express-validator');
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
const getLicensesValidation = [
  query('source').optional().isIn(['graph', 'powershell']).withMessage('Source must be graph or powershell')
];

// Get all licenses/subscriptions
router.get('/', readAccess, getLicensesValidation, asyncHandler(async (req, res) => {
  const { source = 'graph' } = req.query;
  
  try {
    let licenses;
    
    if (source === 'powershell') {
      licenses = await powershellService.getLicenseAnalysis();
    } else {
      licenses = await ms365Service.getSubscriptions();
    }
    
    logger.info('Licenses retrieved successfully', {
      count: licenses.value?.length || licenses.length,
      source,
      user: req.user.username
    });
    
    res.json({
      data: licenses.value || licenses,
      metadata: {
        source,
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve licenses', {
      error: error.message,
      source,
      user: req.user.username
    });
    throw error;
  }
}));

// Get license analysis
router.get('/analysis', readAccess, asyncHandler(async (req, res) => {
  const { source = 'powershell' } = req.query;
  
  try {
    let analysis;
    
    if (source === 'powershell') {
      analysis = await powershellService.getLicenseAnalysis();
    } else {
      // Use Graph API to get subscriptions and calculate analysis
      const subscriptions = await ms365Service.getSubscriptions();
      const users = await ms365Service.getUsers({ top: 999 });
      
      analysis = {
        subscriptions: subscriptions.value || [],
        totalUsers: users.value?.length || 0,
        licensedUsers: 0,
        unlicensedUsers: 0,
        costAnalysis: {},
        utilizationRate: 0
      };
      
      // Calculate license utilization
      const allUsers = users.value || [];
      analysis.licensedUsers = allUsers.filter(u => u.assignedLicenses?.length > 0).length;
      analysis.unlicensedUsers = analysis.totalUsers - analysis.licensedUsers;
      analysis.utilizationRate = (analysis.licensedUsers / analysis.totalUsers) * 100;
    }
    
    logger.info('License analysis retrieved successfully', {
      source,
      user: req.user.username
    });
    
    res.json({
      data: analysis,
      metadata: {
        source,
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve license analysis', {
      error: error.message,
      source,
      user: req.user.username
    });
    throw error;
  }
}));

// Get license usage statistics
router.get('/usage/statistics', readAccess, asyncHandler(async (req, res) => {
  try {
    const subscriptions = await ms365Service.getSubscriptions();
    const users = await ms365Service.getUsers({ top: 999 });
    
    const allSubscriptions = subscriptions.value || [];
    const allUsers = users.value || [];
    
    // Calculate usage statistics
    const stats = {
      totalLicenses: 0,
      assignedLicenses: 0,
      availableLicenses: 0,
      subscriptionBreakdown: [],
      userLicenseDistribution: {},
      utilizationByProduct: {}
    };
    
    // Process each subscription
    allSubscriptions.forEach(sub => {
      const prepaidUnits = sub.prepaidUnits?.enabled || 0;
      const consumedUnits = sub.consumedUnits || 0;
      
      stats.totalLicenses += prepaidUnits;
      stats.assignedLicenses += consumedUnits;
      stats.availableLicenses += (prepaidUnits - consumedUnits);
      
      stats.subscriptionBreakdown.push({
        skuId: sub.skuId,
        skuPartNumber: sub.skuPartNumber,
        prepaidUnits: prepaidUnits,
        consumedUnits: consumedUnits,
        availableUnits: prepaidUnits - consumedUnits,
        utilizationRate: prepaidUnits > 0 ? (consumedUnits / prepaidUnits) * 100 : 0
      });
      
      stats.utilizationByProduct[sub.skuPartNumber] = {
        total: prepaidUnits,
        used: consumedUnits,
        available: prepaidUnits - consumedUnits,
        percentage: prepaidUnits > 0 ? (consumedUnits / prepaidUnits) * 100 : 0
      };
    });
    
    // Calculate user license distribution
    allUsers.forEach(user => {
      const licenseCount = user.assignedLicenses?.length || 0;
      const key = `${licenseCount}_licenses`;
      stats.userLicenseDistribution[key] = (stats.userLicenseDistribution[key] || 0) + 1;
    });
    
    logger.info('License usage statistics retrieved successfully', {
      totalLicenses: stats.totalLicenses,
      assignedLicenses: stats.assignedLicenses,
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
    logger.error('Failed to retrieve license usage statistics', {
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

// Get license optimization recommendations
router.get('/optimization/recommendations', readAccess, asyncHandler(async (req, res) => {
  try {
    const subscriptions = await ms365Service.getSubscriptions();
    const users = await ms365Service.getUsers({ top: 999 });
    
    const allSubscriptions = subscriptions.value || [];
    const allUsers = users.value || [];
    
    const recommendations = [];
    
    // Analyze each subscription for optimization opportunities
    allSubscriptions.forEach(sub => {
      const prepaidUnits = sub.prepaidUnits?.enabled || 0;
      const consumedUnits = sub.consumedUnits || 0;
      const availableUnits = prepaidUnits - consumedUnits;
      const utilizationRate = prepaidUnits > 0 ? (consumedUnits / prepaidUnits) * 100 : 0;
      
      // Under-utilized licenses
      if (utilizationRate < 70 && availableUnits > 5) {
        recommendations.push({
          type: 'REDUCE_LICENSES',
          severity: 'medium',
          product: sub.skuPartNumber,
          currentCount: prepaidUnits,
          recommendedCount: Math.ceil(consumedUnits * 1.1), // 10% buffer
          potentialSavings: availableUnits,
          description: `Consider reducing ${sub.skuPartNumber} licenses. Current utilization: ${utilizationRate.toFixed(1)}%`
        });
      }
      
      // Over-utilized licenses (>95%)
      if (utilizationRate > 95) {
        recommendations.push({
          type: 'INCREASE_LICENSES',
          severity: 'high',
          product: sub.skuPartNumber,
          currentCount: prepaidUnits,
          recommendedCount: Math.ceil(prepaidUnits * 1.2), // 20% increase
          description: `Consider increasing ${sub.skuPartNumber} licenses. Current utilization: ${utilizationRate.toFixed(1)}%`
        });
      }
    });
    
    // Check for inactive users with licenses
    const inactiveUsersWithLicenses = allUsers.filter(u => 
      !u.accountEnabled && u.assignedLicenses?.length > 0
    );
    
    if (inactiveUsersWithLicenses.length > 0) {
      recommendations.push({
        type: 'REMOVE_INACTIVE_LICENSES',
        severity: 'high',
        affectedUsers: inactiveUsersWithLicenses.length,
        description: `${inactiveUsersWithLicenses.length} inactive users still have licenses assigned`
      });
    }
    
    // Check for users with multiple licenses
    const usersWithMultipleLicenses = allUsers.filter(u => 
      u.assignedLicenses?.length > 1
    );
    
    if (usersWithMultipleLicenses.length > 0) {
      recommendations.push({
        type: 'REVIEW_MULTIPLE_LICENSES',
        severity: 'low',
        affectedUsers: usersWithMultipleLicenses.length,
        description: `${usersWithMultipleLicenses.length} users have multiple licenses assigned. Review for optimization.`
      });
    }
    
    logger.info('License optimization recommendations generated', {
      recommendationsCount: recommendations.length,
      user: req.user.username
    });
    
    res.json({
      data: {
        recommendations,
        summary: {
          totalRecommendations: recommendations.length,
          highSeverity: recommendations.filter(r => r.severity === 'high').length,
          mediumSeverity: recommendations.filter(r => r.severity === 'medium').length,
          lowSeverity: recommendations.filter(r => r.severity === 'low').length
        }
      },
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id']
      }
    });
  } catch (error) {
    logger.error('Failed to generate license optimization recommendations', {
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

// Get license cost analysis
router.get('/cost/analysis', readAccess, asyncHandler(async (req, res) => {
  try {
    // This would require pricing information which isn't available in Graph API
    // For now, return a placeholder structure
    const subscriptions = await ms365Service.getSubscriptions();
    const allSubscriptions = subscriptions.value || [];
    
    const costAnalysis = {
      totalMonthlyCost: 0, // Would need pricing data
      totalAnnualCost: 0,
      costByProduct: {},
      costPerUser: 0,
      projectedCost: {
        monthly: 0,
        quarterly: 0,
        annual: 0
      },
      costTrends: [],
      warning: 'Cost analysis requires pricing information not available in Microsoft Graph API'
    };
    
    allSubscriptions.forEach(sub => {
      costAnalysis.costByProduct[sub.skuPartNumber] = {
        units: sub.consumedUnits || 0,
        unitCost: 0, // Would need pricing data
        totalCost: 0
      };
    });
    
    logger.info('License cost analysis retrieved (placeholder)', {
      subscriptions: allSubscriptions.length,
      user: req.user.username
    });
    
    res.json({
      data: costAnalysis,
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id'],
        note: 'Cost analysis requires external pricing data'
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve license cost analysis', {
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

// Get license assignment history (limited data available)
router.get('/assignments/history', readAccess, asyncHandler(async (req, res) => {
  try {
    // Microsoft Graph API doesn't provide detailed license assignment history
    // This would require audit logs or custom tracking
    const auditLogs = await ms365Service.getAuditLogs({
      filter: "category eq 'UserManagement'"
    });
    
    const licenseEvents = (auditLogs.value || []).filter(log => 
      log.activityDisplayName?.includes('license') || 
      log.activityDisplayName?.includes('License')
    );
    
    const history = licenseEvents.map(event => ({
      timestamp: event.activityDateTime,
      activity: event.activityDisplayName,
      user: event.targetResources?.[0]?.userPrincipalName,
      initiatedBy: event.initiatedBy?.user?.userPrincipalName,
      result: event.result,
      details: event.additionalDetails
    }));
    
    logger.info('License assignment history retrieved', {
      eventsCount: history.length,
      user: req.user.username
    });
    
    res.json({
      data: {
        events: history,
        summary: {
          totalEvents: history.length,
          dateRange: {
            from: history.length > 0 ? history[history.length - 1].timestamp : null,
            to: history.length > 0 ? history[0].timestamp : null
          }
        }
      },
      metadata: {
        source: 'graph',
        timestamp: new Date().toISOString(),
        requestId: req.headers['x-request-id'],
        note: 'Limited to audit log data from Microsoft Graph API'
      }
    });
  } catch (error) {
    logger.error('Failed to retrieve license assignment history', {
      error: error.message,
      user: req.user.username
    });
    throw error;
  }
}));

module.exports = router;