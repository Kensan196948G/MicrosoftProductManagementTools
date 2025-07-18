const express = require('express');
const { body, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const cron = require('node-cron');

const logger = require('../utils/logger');
const { asyncHandler, ValidationError } = require('../middleware/errorHandler');
const microsoft365Service = require('../services/microsoft365Service');

const router = express.Router();

// Rate limiting for scheduler endpoints
const schedulerLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 15, // 15 requests per window per IP
  message: {
    error: 'Too many scheduler requests, please try again later.'
  }
});

router.use(schedulerLimiter);

// In-memory store for active scheduled tasks (in production, use Redis or database)
const activeSchedules = new Map();

// Get all scheduled tasks
router.get('/tasks', [
  query('status').optional().isIn(['active', 'paused', 'completed', 'failed', 'all']).withMessage('Invalid status'),
  query('type').optional().isIn(['report', 'backup', 'maintenance', 'monitoring', 'all']).withMessage('Invalid task type'),
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('skip').optional().isInt({ min: 0 }).withMessage('Skip must be a non-negative integer')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { status = 'all', type = 'all', limit = 50, skip = 0 } = req.query;

  try {
    const tasks = await microsoft365Service.getScheduledTasks({
      status,
      type,
      limit: parseInt(limit),
      skip: parseInt(skip)
    });

    logger.info('Retrieved scheduled tasks', {
      status,
      type,
      limit,
      skip,
      count: tasks.length,
      userId: req.user?.username
    });

    res.json({
      filters: {
        status,
        type
      },
      pagination: {
        limit: parseInt(limit),
        skip: parseInt(skip),
        count: tasks.length
      },
      data: tasks
    });
  } catch (error) {
    logger.error('Failed to retrieve scheduled tasks', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Create new scheduled task
router.post('/tasks', [
  body('name').notEmpty().withMessage('Task name is required'),
  body('type').isIn(['report', 'backup', 'maintenance', 'monitoring']).withMessage('Invalid task type'),
  body('schedule').notEmpty().withMessage('Schedule (cron expression) is required'),
  body('action').isObject().withMessage('Action configuration is required'),
  body('description').optional().isString(),
  body('enabled').optional().isBoolean(),
  body('notifications').optional().isObject(),
  body('retryConfig').optional().isObject()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { 
    name, 
    type, 
    schedule, 
    action, 
    description, 
    enabled = true, 
    notifications = {},
    retryConfig = { maxRetries: 3, retryDelay: 300000 } // 5 minutes
  } = req.body;

  try {
    // Validate cron expression
    if (!cron.validate(schedule)) {
      throw new ValidationError('Invalid cron expression');
    }

    const task = await microsoft365Service.createScheduledTask({
      name,
      type,
      schedule,
      action,
      description,
      enabled,
      notifications,
      retryConfig,
      createdBy: req.user?.username
    });

    // Start the scheduled task if enabled
    if (enabled) {
      const cronTask = cron.schedule(schedule, async () => {
        try {
          logger.info('Executing scheduled task', {
            taskId: task.id,
            taskName: name,
            type
          });

          await microsoft365Service.executeScheduledTask(task.id);
          
          logger.info('Scheduled task completed successfully', {
            taskId: task.id,
            taskName: name
          });
        } catch (error) {
          logger.error('Scheduled task execution failed', {
            taskId: task.id,
            taskName: name,
            error: error.message
          });
          
          // Handle retry logic
          await microsoft365Service.handleTaskFailure(task.id, error);
        }
      }, {
        scheduled: true,
        timezone: process.env.TIMEZONE || 'UTC'
      });

      activeSchedules.set(task.id, cronTask);
    }

    logger.audit('Created scheduled task', {
      taskId: task.id,
      taskName: name,
      type,
      schedule,
      enabled,
      userId: req.user?.username
    });

    res.status(201).json({
      message: 'Scheduled task created successfully',
      data: task
    });
  } catch (error) {
    logger.error('Failed to create scheduled task', {
      error: error.message,
      taskName: name,
      type,
      schedule,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Update scheduled task
router.put('/tasks/:taskId', [
  body('name').optional().notEmpty().withMessage('Task name cannot be empty'),
  body('schedule').optional().custom((value) => {
    if (value && !cron.validate(value)) {
      throw new Error('Invalid cron expression');
    }
    return true;
  }),
  body('action').optional().isObject(),
  body('description').optional().isString(),
  body('enabled').optional().isBoolean(),
  body('notifications').optional().isObject(),
  body('retryConfig').optional().isObject()
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { taskId } = req.params;
  const updates = req.body;

  try {
    const updatedTask = await microsoft365Service.updateScheduledTask(taskId, updates);

    // If schedule or enabled status changed, update the cron job
    if (updates.schedule || updates.hasOwnProperty('enabled')) {
      // Stop existing schedule
      if (activeSchedules.has(taskId)) {
        activeSchedules.get(taskId).stop();
        activeSchedules.delete(taskId);
      }

      // Start new schedule if enabled
      if (updatedTask.enabled) {
        const cronTask = cron.schedule(updatedTask.schedule, async () => {
          try {
            logger.info('Executing scheduled task', {
              taskId: updatedTask.id,
              taskName: updatedTask.name,
              type: updatedTask.type
            });

            await microsoft365Service.executeScheduledTask(updatedTask.id);
            
            logger.info('Scheduled task completed successfully', {
              taskId: updatedTask.id,
              taskName: updatedTask.name
            });
          } catch (error) {
            logger.error('Scheduled task execution failed', {
              taskId: updatedTask.id,
              taskName: updatedTask.name,
              error: error.message
            });
            
            await microsoft365Service.handleTaskFailure(updatedTask.id, error);
          }
        }, {
          scheduled: true,
          timezone: process.env.TIMEZONE || 'UTC'
        });

        activeSchedules.set(taskId, cronTask);
      }
    }

    logger.audit('Updated scheduled task', {
      taskId,
      updates,
      userId: req.user?.username
    });

    res.json({
      message: 'Scheduled task updated successfully',
      data: updatedTask
    });
  } catch (error) {
    logger.error('Failed to update scheduled task', {
      error: error.message,
      taskId,
      updates,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Delete scheduled task
router.delete('/tasks/:taskId', asyncHandler(async (req, res) => {
  const { taskId } = req.params;

  try {
    // Stop and remove from active schedules
    if (activeSchedules.has(taskId)) {
      activeSchedules.get(taskId).stop();
      activeSchedules.delete(taskId);
    }

    await microsoft365Service.deleteScheduledTask(taskId);

    logger.audit('Deleted scheduled task', {
      taskId,
      userId: req.user?.username
    });

    res.json({
      message: 'Scheduled task deleted successfully'
    });
  } catch (error) {
    logger.error('Failed to delete scheduled task', {
      error: error.message,
      taskId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Execute task immediately
router.post('/tasks/:taskId/execute', asyncHandler(async (req, res) => {
  const { taskId } = req.params;

  try {
    const result = await microsoft365Service.executeScheduledTask(taskId, true); // true = manual execution

    logger.audit('Manually executed scheduled task', {
      taskId,
      result: result ? 'success' : 'failed',
      userId: req.user?.username
    });

    res.json({
      message: 'Task executed successfully',
      executionId: result.executionId,
      startTime: result.startTime,
      endTime: result.endTime,
      status: result.status,
      data: result.data
    });
  } catch (error) {
    logger.error('Failed to execute scheduled task', {
      error: error.message,
      taskId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Pause/Resume task
router.patch('/tasks/:taskId/toggle', [
  body('action').isIn(['pause', 'resume']).withMessage('Action must be pause or resume')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { taskId } = req.params;
  const { action } = req.body;

  try {
    const task = await microsoft365Service.getScheduledTask(taskId);
    
    if (!task) {
      return res.status(404).json({
        error: 'Task not found'
      });
    }

    if (action === 'pause') {
      if (activeSchedules.has(taskId)) {
        activeSchedules.get(taskId).stop();
      }
      await microsoft365Service.updateScheduledTask(taskId, { enabled: false });
    } else if (action === 'resume') {
      const cronTask = cron.schedule(task.schedule, async () => {
        try {
          await microsoft365Service.executeScheduledTask(taskId);
        } catch (error) {
          logger.error('Scheduled task execution failed', {
            taskId,
            error: error.message
          });
          await microsoft365Service.handleTaskFailure(taskId, error);
        }
      }, {
        scheduled: true,
        timezone: process.env.TIMEZONE || 'UTC'
      });

      activeSchedules.set(taskId, cronTask);
      await microsoft365Service.updateScheduledTask(taskId, { enabled: true });
    }

    logger.audit(`${action}d scheduled task`, {
      taskId,
      action,
      userId: req.user?.username
    });

    res.json({
      message: `Task ${action}d successfully`,
      taskId,
      action,
      status: action === 'pause' ? 'paused' : 'active'
    });
  } catch (error) {
    logger.error(`Failed to ${action} scheduled task`, {
      error: error.message,
      taskId,
      action,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get task execution history
router.get('/tasks/:taskId/history', [
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('skip').optional().isInt({ min: 0 }).withMessage('Skip must be a non-negative integer'),
  query('status').optional().isIn(['success', 'failed', 'running', 'all']).withMessage('Invalid status')
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError('Validation failed', errors.array());
  }

  const { taskId } = req.params;
  const { limit = 20, skip = 0, status = 'all' } = req.query;

  try {
    const history = await microsoft365Service.getTaskExecutionHistory(taskId, {
      limit: parseInt(limit),
      skip: parseInt(skip),
      status
    });

    logger.info('Retrieved task execution history', {
      taskId,
      limit,
      skip,
      status,
      count: history.length,
      userId: req.user?.username
    });

    res.json({
      taskId,
      pagination: {
        limit: parseInt(limit),
        skip: parseInt(skip),
        count: history.length
      },
      filters: {
        status
      },
      data: history
    });
  } catch (error) {
    logger.error('Failed to retrieve task execution history', {
      error: error.message,
      taskId,
      userId: req.user?.username
    });
    throw error;
  }
}));

// Get scheduler statistics
router.get('/statistics', asyncHandler(async (req, res) => {
  try {
    const stats = await microsoft365Service.getSchedulerStatistics();

    logger.info('Retrieved scheduler statistics', {
      totalTasks: stats.totalTasks,
      activeTasks: stats.activeTasks,
      userId: req.user?.username
    });

    res.json({
      data: stats,
      activeSchedulesCount: activeSchedules.size
    });
  } catch (error) {
    logger.error('Failed to retrieve scheduler statistics', {
      error: error.message,
      userId: req.user?.username
    });
    throw error;
  }
}));

module.exports = router;