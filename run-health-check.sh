#!/bin/bash
source "/mnt/e/MicrosoftProductManagementTools/log-management-config.sh"
if create_rate_limit 'health-check' 3600; then
    cd "/mnt/e/MicrosoftProductManagementTools"
    bash '/mnt/e/MicrosoftProductManagementTools/config-check.sh' --auto >> "/mnt/e/MicrosoftProductManagementTools/Logs/scheduled_health-check_$(date '+%Y%m%d_%H%M%S').log" 2>&1
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Rate limited: health-check" >> "/mnt/e/MicrosoftProductManagementTools/Logs/rate_limit.log"
fi
