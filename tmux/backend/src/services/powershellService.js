const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs').promises;
const logger = require('../utils/logger');
const { ExternalServiceError } = require('../middleware/errorHandler');

class PowerShellService {
  constructor() {
    this.powershellPath = process.env.POWERSHELL_PATH || 'pwsh';
    this.scriptsPath = process.env.SCRIPTS_PATH || '../Scripts';
    this.timeout = 300000; // 5 minutes default timeout
  }

  // Execute PowerShell script
  async executeScript(scriptPath, args = [], options = {}) {
    const {
      timeout = this.timeout,
      cwd = process.cwd(),
      env = process.env
    } = options;

    const fullScriptPath = path.resolve(scriptPath);
    
    // Verify script exists
    try {
      await fs.access(fullScriptPath);
    } catch (error) {
      throw new ExternalServiceError(`PowerShell script not found: ${fullScriptPath}`, 'PowerShell');
    }

    const startTime = Date.now();
    
    return new Promise((resolve, reject) => {
      const powershellArgs = [
        '-ExecutionPolicy', 'Bypass',
        '-File', fullScriptPath,
        ...args
      ];

      logger.debug('Executing PowerShell script', {
        script: fullScriptPath,
        args: args,
        timeout
      });

      const child = spawn(this.powershellPath, powershellArgs, {
        cwd,
        env: { ...env, FORCE_COLOR: '0' },
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';
      let timedOut = false;

      // Set timeout
      const timeoutId = setTimeout(() => {
        timedOut = true;
        child.kill('SIGTERM');
      }, timeout);

      child.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('close', (code) => {
        clearTimeout(timeoutId);
        const duration = Date.now() - startTime;
        
        if (timedOut) {
          logger.error('PowerShell script timed out', {
            script: fullScriptPath,
            timeout,
            duration
          });
          reject(new ExternalServiceError('PowerShell script execution timed out', 'PowerShell'));
          return;
        }

        logger.debug('PowerShell script completed', {
          script: fullScriptPath,
          exitCode: code,
          duration,
          stdoutLength: stdout.length,
          stderrLength: stderr.length
        });

        if (code === 0) {
          resolve({
            success: true,
            stdout,
            stderr,
            exitCode: code,
            duration
          });
        } else {
          logger.error('PowerShell script failed', {
            script: fullScriptPath,
            exitCode: code,
            stderr,
            duration
          });
          reject(new ExternalServiceError(`PowerShell script failed with exit code ${code}: ${stderr}`, 'PowerShell'));
        }
      });

      child.on('error', (error) => {
        clearTimeout(timeoutId);
        logger.error('PowerShell script execution error', {
          script: fullScriptPath,
          error: error.message
        });
        reject(new ExternalServiceError(`PowerShell execution error: ${error.message}`, 'PowerShell'));
      });
    });
  }

  // Execute PowerShell command directly
  async executeCommand(command, options = {}) {
    const {
      timeout = this.timeout,
      cwd = process.cwd(),
      env = process.env
    } = options;

    const startTime = Date.now();
    
    return new Promise((resolve, reject) => {
      const powershellArgs = [
        '-ExecutionPolicy', 'Bypass',
        '-Command', command
      ];

      logger.debug('Executing PowerShell command', { command, timeout });

      const child = spawn(this.powershellPath, powershellArgs, {
        cwd,
        env: { ...env, FORCE_COLOR: '0' },
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';
      let timedOut = false;

      const timeoutId = setTimeout(() => {
        timedOut = true;
        child.kill('SIGTERM');
      }, timeout);

      child.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('close', (code) => {
        clearTimeout(timeoutId);
        const duration = Date.now() - startTime;
        
        if (timedOut) {
          logger.error('PowerShell command timed out', { command, timeout, duration });
          reject(new ExternalServiceError('PowerShell command execution timed out', 'PowerShell'));
          return;
        }

        logger.debug('PowerShell command completed', {
          command,
          exitCode: code,
          duration
        });

        if (code === 0) {
          resolve({
            success: true,
            stdout,
            stderr,
            exitCode: code,
            duration
          });
        } else {
          logger.error('PowerShell command failed', {
            command,
            exitCode: code,
            stderr,
            duration
          });
          reject(new ExternalServiceError(`PowerShell command failed with exit code ${code}: ${stderr}`, 'PowerShell'));
        }
      });

      child.on('error', (error) => {
        clearTimeout(timeoutId);
        logger.error('PowerShell command execution error', {
          command,
          error: error.message
        });
        reject(new ExternalServiceError(`PowerShell execution error: ${error.message}`, 'PowerShell'));
      });
    });
  }

  // Get all users using PowerShell module
  async getAllUsers() {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'RealM365DataProvider.psm1');
    const command = `Import-Module '${scriptPath}'; Get-M365AllUsers | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to get all users via PowerShell', { error: error.message });
      throw error;
    }
  }

  // Get license analysis using PowerShell module
  async getLicenseAnalysis() {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'RealM365DataProvider.psm1');
    const command = `Import-Module '${scriptPath}'; Get-M365LicenseAnalysis | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to get license analysis via PowerShell', { error: error.message });
      throw error;
    }
  }

  // Get usage analysis using PowerShell module
  async getUsageAnalysis() {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'RealM365DataProvider.psm1');
    const command = `Import-Module '${scriptPath}'; Get-M365UsageAnalysis | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to get usage analysis via PowerShell', { error: error.message });
      throw error;
    }
  }

  // Get MFA status using PowerShell module
  async getMfaStatus() {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'RealM365DataProvider.psm1');
    const command = `Import-Module '${scriptPath}'; Get-M365MFAStatus | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to get MFA status via PowerShell', { error: error.message });
      throw error;
    }
  }

  // Get Teams usage using PowerShell module
  async getTeamsUsage() {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'RealM365DataProvider.psm1');
    const command = `Import-Module '${scriptPath}'; Get-M365TeamsUsage | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to get Teams usage via PowerShell', { error: error.message });
      throw error;
    }
  }

  // Get OneDrive analysis using PowerShell module
  async getOneDriveAnalysis() {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'RealM365DataProvider.psm1');
    const command = `Import-Module '${scriptPath}'; Get-M365OneDriveAnalysis | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to get OneDrive analysis via PowerShell', { error: error.message });
      throw error;
    }
  }

  // Get sign-in logs using PowerShell module
  async getSignInLogs() {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'RealM365DataProvider.psm1');
    const command = `Import-Module '${scriptPath}'; Get-M365SignInLogs | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to get sign-in logs via PowerShell', { error: error.message });
      throw error;
    }
  }

  // Generate report using PowerShell module
  async generateReport(reportType, options = {}) {
    const scriptPath = path.join(this.scriptsPath, 'Common', 'ReportGenerator.psm1');
    const optionsJson = JSON.stringify(options);
    const command = `Import-Module '${scriptPath}'; New-Report -Type '${reportType}' -Options '${optionsJson}' | ConvertTo-Json -Depth 5`;
    
    try {
      const result = await this.executeCommand(command);
      return JSON.parse(result.stdout);
    } catch (error) {
      logger.error('Failed to generate report via PowerShell', { 
        reportType, 
        options, 
        error: error.message 
      });
      throw error;
    }
  }

  // Execute CLI app
  async executeCli(action, options = {}) {
    const scriptPath = path.join(this.scriptsPath, '..', 'Apps', 'CliApp_Enhanced.ps1');
    const args = [action];
    
    if (options.batch) args.push('-Batch');
    if (options.outputHtml) args.push('-OutputHTML');
    if (options.outputCsv) args.push('-OutputCSV');
    if (options.outputPath) args.push('-OutputPath', options.outputPath);
    if (options.maxResults) args.push('-MaxResults', options.maxResults);
    
    try {
      const result = await this.executeScript(scriptPath, args, { timeout: 600000 }); // 10 minutes for CLI
      return result;
    } catch (error) {
      logger.error('Failed to execute CLI app via PowerShell', { 
        action, 
        options, 
        error: error.message 
      });
      throw error;
    }
  }

  // Check PowerShell version and modules
  async checkEnvironment() {
    try {
      const versionResult = await this.executeCommand('$PSVersionTable.PSVersion.ToString()');
      const modulesResult = await this.executeCommand('Get-Module -ListAvailable | Where-Object { $_.Name -in @("ExchangeOnlineManagement", "Microsoft.Graph") } | Select-Object Name, Version | ConvertTo-Json');
      
      const version = versionResult.stdout.trim();
      const modules = JSON.parse(modulesResult.stdout || '[]');
      
      logger.info('PowerShell environment check completed', {
        version,
        modules
      });
      
      return {
        version,
        modules,
        healthy: true
      };
    } catch (error) {
      logger.error('PowerShell environment check failed', { error: error.message });
      return {
        healthy: false,
        error: error.message
      };
    }
  }

  // Health check
  async healthCheck() {
    try {
      await this.executeCommand('Write-Output "PowerShell Health Check"');
      return { status: 'healthy', timestamp: new Date().toISOString() };
    } catch (error) {
      logger.error('PowerShell health check failed', { error: error.message });
      return { status: 'unhealthy', error: error.message, timestamp: new Date().toISOString() };
    }
  }
}

module.exports = PowerShellService;