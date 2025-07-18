const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');
const { AuthenticationError, AuthorizationError } = require('./errorHandler');

// JWT token verification middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    logger.warn('Authentication attempt without token', {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      path: req.path
    });
    return next(new AuthenticationError('Access token required'));
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      logger.warn('Authentication failed - invalid token', {
        error: err.message,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        path: req.path
      });
      return next(new AuthenticationError('Invalid or expired token'));
    }

    // Add user info to request
    req.user = user;
    
    logger.debug('Authentication successful', {
      username: user.username,
      role: user.role,
      path: req.path
    });

    next();
  });
};

// Role-based authorization middleware
const authorizeRole = (requiredRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return next(new AuthenticationError('Authentication required'));
    }

    const userRole = req.user.role;
    const hasRequiredRole = Array.isArray(requiredRoles) 
      ? requiredRoles.includes(userRole)
      : requiredRoles === userRole;

    if (!hasRequiredRole) {
      logger.warn('Authorization failed - insufficient role', {
        username: req.user.username,
        userRole,
        requiredRoles,
        path: req.path,
        ip: req.ip
      });
      return next(new AuthorizationError('Insufficient permissions'));
    }

    next();
  };
};

// Permission-based authorization middleware
const authorizePermission = (requiredPermissions) => {
  return (req, res, next) => {
    if (!req.user) {
      return next(new AuthenticationError('Authentication required'));
    }

    const userPermissions = req.user.permissions || [];
    const hasRequiredPermission = Array.isArray(requiredPermissions)
      ? requiredPermissions.some(permission => userPermissions.includes(permission))
      : userPermissions.includes(requiredPermissions);

    if (!hasRequiredPermission) {
      logger.warn('Authorization failed - insufficient permissions', {
        username: req.user.username,
        userPermissions,
        requiredPermissions,
        path: req.path,
        ip: req.ip
      });
      return next(new AuthorizationError('Insufficient permissions'));
    }

    next();
  };
};

// Optional authentication middleware (for public endpoints that can benefit from user context)
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return next();
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (!err) {
      req.user = user;
    }
    next();
  });
};

// Admin-only middleware
const adminOnly = [
  authenticateToken,
  authorizeRole('admin')
];

// Read-only access middleware
const readAccess = [
  authenticateToken,
  authorizePermission(['read', 'write', 'admin'])
];

// Write access middleware
const writeAccess = [
  authenticateToken,
  authorizePermission(['write', 'admin'])
];

// API key authentication middleware (for service-to-service communication)
const authenticateApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey) {
    return next(new AuthenticationError('API key required'));
  }

  // TODO: Implement proper API key validation
  const validApiKey = process.env.API_KEY;
  
  if (apiKey !== validApiKey) {
    logger.warn('API key authentication failed', {
      providedKey: apiKey.substring(0, 8) + '...',
      ip: req.ip,
      path: req.path
    });
    return next(new AuthenticationError('Invalid API key'));
  }

  req.apiKeyAuth = true;
  next();
};

// Request logging middleware
const logRequest = (req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    logger.request(req, res, duration);
    
    // Log security-sensitive operations
    if (req.method !== 'GET' || req.path.includes('admin')) {
      logger.audit('API Request', {
        method: req.method,
        path: req.path,
        user: req.user?.username || 'anonymous',
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        status: res.statusCode,
        duration: `${duration}ms`
      });
    }
  });
  
  next();
};

// IP whitelist middleware
const ipWhitelist = (allowedIPs) => {
  return (req, res, next) => {
    const clientIP = req.ip;
    
    if (!allowedIPs.includes(clientIP)) {
      logger.warn('IP whitelist violation', {
        clientIP,
        allowedIPs,
        path: req.path
      });
      return next(new AuthorizationError('IP address not allowed'));
    }
    
    next();
  };
};

// Request validation middleware
const validateRequest = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.body);
    
    if (error) {
      logger.warn('Request validation failed', {
        error: error.details,
        path: req.path,
        user: req.user?.username
      });
      return next(new ValidationError('Request validation failed', error.details));
    }
    
    next();
  };
};

module.exports = {
  authenticateToken,
  authorizeRole,
  authorizePermission,
  optionalAuth,
  adminOnly,
  readAccess,
  writeAccess,
  authenticateApiKey,
  logRequest,
  ipWhitelist,
  validateRequest
};