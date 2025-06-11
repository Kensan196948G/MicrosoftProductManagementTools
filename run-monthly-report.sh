#!/bin/bash
source "/mnt/e/MicrosoftProductManagementTools/log-management-config.sh"
if create_rate_limit 'monthly-report' 3600; then
    cd "/mnt/e/MicrosoftProductManagementTools"
    pwsh -ExecutionPolicy Bypass -File '/mnt/e/MicrosoftProductManagementTools/Scripts/Common/ScheduledReports.ps1' -ReportType Monthly >> "/mnt/e/MicrosoftProductManagementTools/Logs/scheduled_monthly-report_$(date '+%Y%m%d_%H%M%S').log" 2>&1
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Rate limited: monthly-report" >> "/mnt/e/MicrosoftProductManagementTools/Logs/rate_limit.log"
fi
