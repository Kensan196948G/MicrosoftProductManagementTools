#!/bin/bash
source "/mnt/e/MicrosoftProductManagementTools/log-management-config.sh"
if create_rate_limit 'daily-report' 3600; then
    cd "/mnt/e/MicrosoftProductManagementTools"
    pwsh -ExecutionPolicy Bypass -File '/mnt/e/MicrosoftProductManagementTools/Scripts/Common/ScheduledReports.ps1' -ReportType Daily >> "/mnt/e/MicrosoftProductManagementTools/Logs/scheduled_daily-report_$(date '+%Y%m%d_%H%M%S').log" 2>&1
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Rate limited: daily-report" >> "/mnt/e/MicrosoftProductManagementTools/Logs/rate_limit.log"
fi
