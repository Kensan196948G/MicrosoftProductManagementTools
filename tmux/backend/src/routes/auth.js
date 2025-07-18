const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');

const logger = require('../utils/logger');
const { asyncHandler, AuthenticationError, ValidationError } = require('../middleware/errorHandler');
const { msalClient } = require('../config/microsoft365');

const router = express.Router();

// Rate limiting for authentication endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: {
    error: 'Too many authentication attempts, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Validation middleware
const loginValidation = [
  body('username').notEmpty().withMessage('Username is required'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters long'),
];

const tokenValidation = [
  body('token').notEmpty().withMessage('Token is required'),
];

// Login endpoint - for admin authentication
router.post('/login', authLimiter, loginValidation, asyncHandler(async (req, res) => {
  // Check validation results
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { username, password } = req.body;

  // TODO: Implement proper user authentication
  // For now, use environment variables for admin credentials
  const adminUsername = process.env.ADMIN_USERNAME || 'admin';
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';

  // Verify credentials
  if (username !== adminUsername || password !== adminPassword) {
    logger.audit('Failed login attempt', {
      username,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });
    throw new AuthenticationError('Invalid credentials');
  }

  // Generate JWT token
  const token = jwt.sign(
    { 
      username,
      role: 'admin',
      permissions: ['read', 'write', 'admin']
    },
    process.env.JWT_SECRET,
    { 
      expiresIn: process.env.JWT_EXPIRES_IN || '24h',
      issuer: 'ms365-management-api',
      audience: 'ms365-management-client'
    }
  );

  // Generate refresh token
  const refreshToken = jwt.sign(
    { username, type: 'refresh' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );

  logger.audit('Successful login', {
    username,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  res.json({
    message: 'Authentication successful',
    token,
    refreshToken,
    expiresIn: process.env.JWT_EXPIRES_IN || '24h',
    user: {
      username,
      role: 'admin',
      permissions: ['read', 'write', 'admin']
    }
  });
}));

// Microsoft 365 authentication endpoint
router.post('/microsoft365', asyncHandler(async (req, res) => {
  try {
    // Client credentials flow for Microsoft 365
    const clientCredentialRequest = {
      scopes: ['https://graph.microsoft.com/.default'],
      skipCache: false,
    };

    const response = await msalClient.acquireTokenSilent(clientCredentialRequest);
    
    if (!response) {
      const clientCredentialResponse = await msalClient.acquireTokenByClientCredential(clientCredentialRequest);
      
      logger.audit('Microsoft 365 authentication successful', {
        tenantId: process.env.MS_TENANT_ID,
        clientId: process.env.MS_CLIENT_ID,
        ip: req.ip
      });

      res.json({
        message: 'Microsoft 365 authentication successful',
        accessToken: clientCredentialResponse.accessToken,
        expiresOn: clientCredentialResponse.expiresOn,
        tokenType: clientCredentialResponse.tokenType,
        scopes: clientCredentialResponse.scopes
      });
    } else {
      logger.info('Using cached Microsoft 365 token');
      
      res.json({
        message: 'Microsoft 365 authentication successful (cached)',
        accessToken: response.accessToken,
        expiresOn: response.expiresOn,
        tokenType: response.tokenType,
        scopes: response.scopes
      });
    }
  } catch (error) {
    logger.error('Microsoft 365 authentication failed', {
      error: error.message,
      errorCode: error.errorCode,
      ip: req.ip
    });

    throw new AuthenticationError('Microsoft 365 authentication failed');
  }
}));

// Token refresh endpoint
router.post('/refresh', tokenValidation, asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { token } = req.body;

  try {
    // Verify refresh token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (decoded.type !== 'refresh') {
      throw new AuthenticationError('Invalid refresh token');
    }

    // Generate new access token
    const newToken = jwt.sign(
      { 
        username: decoded.username,
        role: 'admin',
        permissions: ['read', 'write', 'admin']
      },
      process.env.JWT_SECRET,
      { 
        expiresIn: process.env.JWT_EXPIRES_IN || '24h',
        issuer: 'ms365-management-api',
        audience: 'ms365-management-client'
      }
    );

    logger.audit('Token refresh successful', {
      username: decoded.username,
      ip: req.ip
    });

    res.json({
      message: 'Token refresh successful',
      token: newToken,
      expiresIn: process.env.JWT_EXPIRES_IN || '24h'
    });
  } catch (error) {
    logger.audit('Token refresh failed', {
      error: error.message,
      ip: req.ip
    });

    throw new AuthenticationError('Invalid refresh token');
  }
}));

// Logout endpoint
router.post('/logout', asyncHandler(async (req, res) => {
  // TODO: Implement token blacklisting for logout
  // For now, client should discard the token
  
  logger.audit('User logout', {
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  res.json({
    message: 'Logout successful'
  });
}));

// Token verification endpoint
router.get('/verify', asyncHandler(async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    throw new AuthenticationError('No token provided');
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    res.json({
      valid: true,
      user: {
        username: decoded.username,
        role: decoded.role,
        permissions: decoded.permissions
      },
      expiresAt: new Date(decoded.exp * 1000)
    });
  } catch (error) {
    throw new AuthenticationError('Invalid token');
  }
}));

// Get authentication status
router.get('/status', asyncHandler(async (req, res) => {
  res.json({
    authenticationMethods: ['local', 'microsoft365'],
    tokenType: 'JWT',
    securityFeatures: ['rate-limiting', 'audit-logging'],
    microsoft365: {
      configured: !!(process.env.MS_TENANT_ID && process.env.MS_CLIENT_ID && process.env.MS_CLIENT_SECRET),
      tenantId: process.env.MS_TENANT_ID,
      clientId: process.env.MS_CLIENT_ID
    }
  });
}));

module.exports = router;