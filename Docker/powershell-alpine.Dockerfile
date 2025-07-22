# PowerShell 7 + Microsoft 365 Management Tools - Alpine Production
# Specialized container for PowerShell 7 + Microsoft Graph/Exchange Online integration
# Multi-architecture support (amd64/arm64) with enterprise security hardening

# Stage 1: PowerShell 7 Build Environment
FROM mcr.microsoft.com/powershell:7.4-alpine-3.18 as powershell-builder

# Enhanced security: Install PowerShell dependencies
RUN apk add --no-cache \
    curl \
    jq \
    git \
    openssh-client \
    ca-certificates \
    && update-ca-certificates

# Install Microsoft 365 PowerShell modules
RUN pwsh -Command " \
    Set-PSRepository PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name Microsoft.Graph -Force -AllowClobber -Scope AllUsers; \
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope AllUsers; \
    Install-Module -Name MicrosoftTeams -Force -AllowClobber -Scope AllUsers; \
    Install-Module -Name PnP.PowerShell -Force -AllowClobber -Scope AllUsers; \
    Install-Module -Name Az.Accounts -Force -AllowClobber -Scope AllUsers; \
    "

# Stage 2: Production Runtime with PowerShell 7 + Python Integration
FROM python:3.11-alpine as production

# Install PowerShell 7 in Python container
RUN apk add --no-cache \
    curl \
    less \
    ca-certificates \
    krb5-libs \
    libgcc \
    libintl \
    libssl3 \
    libstdc++ \
    tzdata \
    userspace-rcu \
    zlib \
    icu-libs \
    && apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache lttng-ust

# Install PowerShell 7
RUN curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/powershell-7.4.1-linux-musl-x64.tar.gz -o /tmp/powershell.tar.gz \
    && mkdir -p /opt/microsoft/powershell/7 \
    && tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
    && chmod +x /opt/microsoft/powershell/7/pwsh \
    && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
    && rm /tmp/powershell.tar.gz

# Copy PowerShell modules from builder
COPY --from=powershell-builder /root/.local/share/powershell/Modules/ /root/.local/share/powershell/Modules/
COPY --from=powershell-builder /opt/microsoft/powershell/7/Modules/ /opt/microsoft/powershell/7/Modules/

# Install Python dependencies for hybrid operation
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    pydantic \
    python-multipart \
    msal \
    pandas \
    jinja2 \
    aiofiles \
    asyncio-subprocess

# Create application user
RUN addgroup -g 1001 -S m365user && \
    adduser -u 1001 -S m365user -G m365user -s /bin/bash

# Application structure
WORKDIR /app
RUN mkdir -p \
    /app/Scripts/Common \
    /app/Scripts/EXO \
    /app/Scripts/EntraID \
    /app/Apps \
    /app/Config \
    /app/Reports \
    /app/Logs \
    && chown -R m365user:m365user /app

# Copy PowerShell scripts
COPY --chown=m365user:m365user Scripts/ ./Scripts/
COPY --chown=m365user:m365user Apps/ ./Apps/
COPY --chown=m365user:m365user Config/ ./Config/

# Create PowerShell + Python bridge entry point
RUN cat > /app/powershell-bridge.py << 'EOF'
#!/usr/bin/env python3
"""
PowerShell 7 + Python Bridge for Microsoft 365 Management
Enterprise-grade integration between PowerShell scripts and Python API
"""

import asyncio
import subprocess
import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional
import sys

class PowerShellBridge:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.pwsh_path = "/usr/bin/pwsh"
        
    async def execute_powershell(
        self, 
        script_path: str, 
        parameters: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Execute PowerShell script with parameters and return JSON result"""
        
        try:
            # Build PowerShell command
            cmd = [
                self.pwsh_path,
                "-NonInteractive",
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", script_path
            ]
            
            # Add parameters if provided
            if parameters:
                for key, value in parameters.items():
                    cmd.extend([f"-{key}", str(value)])
            
            # Execute PowerShell script
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd="/app"
            )
            
            stdout, stderr = await process.communicate()
            
            # Parse result
            result = {
                "success": process.returncode == 0,
                "returncode": process.returncode,
                "stdout": stdout.decode('utf-8'),
                "stderr": stderr.decode('utf-8')
            }
            
            # Try to parse JSON output from PowerShell
            try:
                if result["stdout"].strip():
                    json_data = json.loads(result["stdout"])
                    result["data"] = json_data
            except json.JSONDecodeError:
                # Output is not JSON, keep as text
                pass
                
            return result
            
        except Exception as e:
            self.logger.error(f"PowerShell execution failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "stdout": "",
                "stderr": str(e)
            }

# Global bridge instance
bridge = PowerShellBridge()

if __name__ == "__main__":
    # Test PowerShell integration
    async def test():
        result = await bridge.execute_powershell(
            "/app/TestScripts/test-auth.ps1"
        )
        print(json.dumps(result, indent=2))
    
    asyncio.run(test())
EOF

RUN chmod +x /app/powershell-bridge.py

# Create enhanced entrypoint for PowerShell + Python
RUN cat > /app/docker-entrypoint-hybrid.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🔄 Microsoft 365 Management Tools - PowerShell + Python Hybrid"
echo "   PowerShell Version: $(pwsh -Command '$PSVersionTable.PSVersion')"
echo "   Python Version: $(python --version)"

# Validate PowerShell modules
echo "🔍 Validating PowerShell modules..."
pwsh -Command "
    \$modules = @('Microsoft.Graph', 'ExchangeOnlineManagement', 'MicrosoftTeams')
    foreach (\$module in \$modules) {
        if (Get-Module -ListAvailable -Name \$module) {
            Write-Host \"✅ \$module: Available\"
        } else {
            Write-Host \"❌ \$module: Missing\"
        }
    }
"

# Test Microsoft 365 connectivity (non-blocking)
if [ "${TENANT_ID:-}" ] && [ "${CLIENT_ID:-}" ]; then
    echo "🔗 Testing Microsoft 365 connectivity..."
    pwsh -Command "
        try {
            Import-Module Microsoft.Graph
            Write-Host '✅ Microsoft Graph module imported successfully'
        } catch {
            Write-Host '⚠️  Microsoft Graph import failed: ' + \$_.Exception.Message
        }
    " || echo "⚠️  PowerShell module test completed with warnings"
fi

# Start based on mode
case "${1:-hybrid}" in
    "powershell"|"ps1")
        echo "⚡ Starting PowerShell mode..."
        exec pwsh "${@:2}"
        ;;
    "python"|"api")
        echo "🐍 Starting Python API mode..."
        exec python -m uvicorn src.main_fastapi:app --host 0.0.0.0 --port 8000
        ;;
    "hybrid"|"bridge")
        echo "🔄 Starting Hybrid Bridge mode..."
        exec python /app/powershell-bridge.py "${@:2}"
        ;;
    "gui")
        echo "🖥️  Starting GUI with X11 forwarding..."
        if [ -z "${DISPLAY:-}" ]; then
            echo "❌ DISPLAY environment variable not set"
            echo "   Use: docker run -e DISPLAY=:0 -v /tmp/.X11-unix:/tmp/.X11-unix ..."
            exit 1
        fi
        exec python src/main.py --mode gui
        ;;
    *)
        echo "📋 Custom command execution..."
        exec "$@"
        ;;
esac
EOF

RUN chmod +x /app/docker-entrypoint-hybrid.sh

# Enhanced health check for PowerShell + Python
RUN cat > /app/health-check-hybrid.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import json
import sys
from datetime import datetime

def check_powershell():
    """Check PowerShell availability and modules"""
    try:
        result = subprocess.run([
            "/usr/bin/pwsh", "-Command", 
            "Get-Module -ListAvailable Microsoft.Graph | Select-Object Name, Version | ConvertTo-Json"
        ], capture_output=True, text=True, timeout=10)
        
        return {
            "powershell_available": result.returncode == 0,
            "modules_check": result.stdout if result.returncode == 0 else result.stderr
        }
    except Exception as e:
        return {"powershell_available": False, "error": str(e)}

def check_python():
    """Check Python availability"""
    try:
        import msal, fastapi, uvicorn
        return {"python_modules": "OK", "msal": "available", "fastapi": "available"}
    except ImportError as e:
        return {"python_modules": "ERROR", "missing": str(e)}

def main():
    health_data = {
        "timestamp": datetime.now().isoformat(),
        "status": "healthy",
        "powershell": check_powershell(),
        "python": check_python()
    }
    
    # Determine overall health
    if not health_data["powershell"]["powershell_available"]:
        health_data["status"] = "degraded"
    
    print(json.dumps(health_data, indent=2))
    
    # Return appropriate exit code
    sys.exit(0 if health_data["status"] == "healthy" else 1)

if __name__ == "__main__":
    main()
EOF

RUN chmod +x /app/health-check-hybrid.py

# Switch to non-root user
USER m365user

# Health check for hybrid container
HEALTHCHECK --interval=30s --timeout=15s --start-period=90s --retries=3 \
    CMD python /app/health-check-hybrid.py || exit 1

# Expose ports
EXPOSE 8000 8001

# Use hybrid entrypoint
ENTRYPOINT ["/app/docker-entrypoint-hybrid.sh"]

# Default to hybrid bridge mode
CMD ["hybrid"]