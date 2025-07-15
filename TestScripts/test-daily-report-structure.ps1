# Test daily report data structure
Import-Module "$PSScriptRoot\..\Scripts\Common\DailyReportData.psm1" -Force

Write-Host "Testing Daily Report Data Structure..." -ForegroundColor Cyan

$data = Get-DailyReportRealData -UseSampleData

Write-Host ""
Write-Host "Data Structure Analysis:" -ForegroundColor Yellow
Write-Host "UserActivity Count: $($data.UserActivity.Count)"
Write-Host "MailboxCapacity Count: $($data.MailboxCapacity.Count)"
Write-Host "SecurityAlerts Count: $($data.SecurityAlerts.Count)"
Write-Host "MFAStatus Count: $($data.MFAStatus.Count)"

Write-Host ""
Write-Host "Summary Data:" -ForegroundColor Yellow
$data.Summary | Format-List

Write-Host ""
Write-Host "Sample UserActivity Record:" -ForegroundColor Yellow
if ($data.UserActivity.Count -gt 0) {
    $data.UserActivity[0] | Format-List
}