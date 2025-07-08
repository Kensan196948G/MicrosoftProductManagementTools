# Google Drive Sync Test Script
# Tests Google Drive API integration and certificate synchronization

[CmdletBinding()]
param(
    [switch]$SkipConnection,
    [switch]$SkipUpload,
    [switch]$TestEncryption,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "=== Google Drive Sync Test Script ===" -ForegroundColor Cyan
Write-Host "Testing Google Drive API integration..." -ForegroundColor Green

# Import required modules
try {
    Import-Module "$PSScriptRoot/../Scripts/Common/GoogleDriveSync.psm1" -Force
    Write-Host "✓ GoogleDriveSync module imported successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import GoogleDriveSync module: $($_.Exception.Message)"
    exit 1
}

# Test variables
$TestResults = @{
    ConnectionTest = $false
    ConfigurationTest = $false
    EncryptionTest = $false
    UploadTest = $false
    OverallResult = $false
}

# Test 1: Configuration Test
Write-Host "`n--- Test 1: Configuration Validation ---" -ForegroundColor Yellow
try {
    $configPath = "$PSScriptRoot/../Config/googledrive.json"
    
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        
        # Check required fields
        if ($config.GoogleDriveAPI.ClientId -and 
            $config.GoogleDriveAPI.ClientId -ne "YOUR_GOOGLE_CLIENT_ID" -and
            $config.GoogleDriveAPI.ClientSecret -and 
            $config.GoogleDriveAPI.ClientSecret -ne "YOUR_GOOGLE_CLIENT_SECRET") {
            Write-Host "✓ Configuration file is properly configured" -ForegroundColor Green
            $TestResults.ConfigurationTest = $true
        }
        else {
            Write-Host "✗ Configuration file needs to be updated with actual API credentials" -ForegroundColor Red
            Write-Host "  Please update $configPath with your Google Drive API credentials" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "✗ Configuration file not found: $configPath" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Configuration test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Connection Test
if (-not $SkipConnection) {
    Write-Host "`n--- Test 2: Google Drive Connection ---" -ForegroundColor Yellow
    try {
        if ($TestResults.ConfigurationTest) {
            $TestResults.ConnectionTest = Test-GoogleDriveConnection
            
            if ($TestResults.ConnectionTest) {
                Write-Host "✓ Google Drive connection successful" -ForegroundColor Green
            }
            else {
                Write-Host "✗ Google Drive connection failed" -ForegroundColor Red
            }
        }
        else {
            Write-Host "⚠ Skipping connection test due to configuration issues" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Connection test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "`n--- Test 2: Google Drive Connection (Skipped) ---" -ForegroundColor Yellow
}

# Test 3: Encryption Test
if ($TestEncryption) {
    Write-Host "`n--- Test 3: Encryption Functionality ---" -ForegroundColor Yellow
    try {
        # Create a test file
        $testContent = "This is a test certificate file content for encryption testing."
        $testFile = "$env:TEMP/test-cert.txt"
        $testFile | Out-File -FilePath $testFile -Encoding UTF8
        
        # Test encryption
        $password = "TestPassword123!"
        $encryptedFile = Invoke-FileEncryption -FilePath $testFile -Password $password
        
        if (Test-Path $encryptedFile) {
            Write-Host "✓ File encryption successful" -ForegroundColor Green
            
            # Test decryption
            $decryptedFile = "$env:TEMP/test-cert-decrypted.txt"
            Invoke-FileDecryption -EncryptedFilePath $encryptedFile -OutputPath $decryptedFile -Password $password
            
            if (Test-Path $decryptedFile) {
                $originalContent = Get-Content $testFile -Raw
                $decryptedContent = Get-Content $decryptedFile -Raw
                
                if ($originalContent -eq $decryptedContent) {
                    Write-Host "✓ File decryption successful" -ForegroundColor Green
                    $TestResults.EncryptionTest = $true
                }
                else {
                    Write-Host "✗ Decrypted content doesn't match original" -ForegroundColor Red
                }
            }
            else {
                Write-Host "✗ File decryption failed" -ForegroundColor Red
            }
            
            # Clean up
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            Remove-Item $encryptedFile -Force -ErrorAction SilentlyContinue
            Remove-Item $decryptedFile -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "✗ File encryption failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Encryption test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "`n--- Test 3: Encryption Functionality (Skipped) ---" -ForegroundColor Yellow
}

# Test 4: Upload Test
if (-not $SkipUpload -and $TestResults.ConnectionTest) {
    Write-Host "`n--- Test 4: File Upload Test ---" -ForegroundColor Yellow
    try {
        # Create a test certificate file
        $testCertContent = @"
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKKKKKKKKKKKMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
aWRnaXRzIFB0eSBMdGQwHhcNMjMwNjE1MDAwMDAwWhcNMjQwNjE1MDAwMDAwWjBF
MQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50
ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
CgKCAQEAyXKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKj
-----END CERTIFICATE-----
"@
        
        $testCertFile = "$env:TEMP/test-upload-cert.cer"
        $testCertContent | Out-File -FilePath $testCertFile -Encoding UTF8
        
        # Initialize Google Drive Sync
        Initialize-GoogleDriveSync
        
        # Create temporary folder for testing
        $testFolder = New-GoogleDriveFolder -FolderName "TestFolder_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Host "Created test folder: $testFolder" -ForegroundColor Green
        
        # Upload test file
        $uploadResult = Send-FileToGoogleDrive -FilePath $testCertFile -RemoteFolderId $testFolder -RemoteFileName "test-cert.cer"
        
        if ($uploadResult) {
            Write-Host "✓ File upload successful (ID: $uploadResult)" -ForegroundColor Green
            $TestResults.UploadTest = $true
        }
        else {
            Write-Host "✗ File upload failed" -ForegroundColor Red
        }
        
        # Clean up
        Remove-Item $testCertFile -Force -ErrorAction SilentlyContinue
        
        # Note: In a real implementation, you might want to delete the test folder from Google Drive
        # but for safety, we'll leave it for manual cleanup
        Write-Host "Note: Test folder '$testFolder' was created in Google Drive and should be manually cleaned up" -ForegroundColor Yellow
    }
    catch {
        Write-Host "✗ Upload test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "`n--- Test 4: File Upload Test (Skipped) ---" -ForegroundColor Yellow
    if (-not $TestResults.ConnectionTest) {
        Write-Host "  Reason: Connection test failed" -ForegroundColor Yellow
    }
}

# Test 5: Local Certificate Discovery
Write-Host "`n--- Test 5: Local Certificate Discovery ---" -ForegroundColor Yellow
try {
    $certPath = "$PSScriptRoot/../Certificates"
    
    if (Test-Path $certPath) {
        $certFiles = Get-ChildItem -Path $certPath -File
        Write-Host "Found $($certFiles.Count) files in certificates directory:" -ForegroundColor Green
        
        foreach ($file in $certFiles) {
            $size = [math]::Round($file.Length / 1KB, 2)
            Write-Host "  - $($file.Name) ($size KB)" -ForegroundColor White
        }
        
        # Check for sensitive files
        $sensitiveFiles = $certFiles | Where-Object { $_.Extension -in @('.key', '.pfx', '.p12') }
        if ($sensitiveFiles) {
            Write-Host "⚠ Found $($sensitiveFiles.Count) sensitive files that should be handled carefully:" -ForegroundColor Yellow
            foreach ($file in $sensitiveFiles) {
                Write-Host "  - $($file.Name)" -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "✗ Certificates directory not found: $certPath" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Certificate discovery failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Overall Results
Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan

$passedTests = ($TestResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $TestResults.Keys.Count - 1  # Exclude OverallResult

Write-Host "Configuration Test: $(if ($TestResults.ConfigurationTest) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($TestResults.ConfigurationTest) { 'Green' } else { 'Red' })
Write-Host "Connection Test: $(if ($TestResults.ConnectionTest) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($TestResults.ConnectionTest) { 'Green' } else { 'Red' })
Write-Host "Encryption Test: $(if ($TestResults.EncryptionTest) { '✓ PASS' } else { '- SKIP' })" -ForegroundColor $(if ($TestResults.EncryptionTest) { 'Green' } else { 'Yellow' })
Write-Host "Upload Test: $(if ($TestResults.UploadTest) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($TestResults.UploadTest) { 'Green' } else { 'Red' })

$TestResults.OverallResult = ($TestResults.ConfigurationTest -and $TestResults.ConnectionTest)

if ($TestResults.OverallResult) {
    Write-Host "`n✓ Google Drive Sync is ready for use!" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Green
    Write-Host "  1. Run: Sync-CertificatesToGoogleDrive" -ForegroundColor White
    Write-Host "  2. Enable file watcher: Start-GoogleDriveFileWatcher" -ForegroundColor White
}
else {
    Write-Host "`n✗ Google Drive Sync needs additional configuration" -ForegroundColor Red
    Write-Host "Please check the failed tests above and refer to the setup guide:" -ForegroundColor Yellow
    Write-Host "  Docs/GoogleDriveSync-Setup.md" -ForegroundColor White
}

# Verbose output
if ($Verbose) {
    Write-Host "`n--- Verbose Information ---" -ForegroundColor Cyan
    Write-Host "Test Parameters:" -ForegroundColor White
    Write-Host "  SkipConnection: $SkipConnection" -ForegroundColor White
    Write-Host "  SkipUpload: $SkipUpload" -ForegroundColor White
    Write-Host "  TestEncryption: $TestEncryption" -ForegroundColor White
    Write-Host "  Verbose: $Verbose" -ForegroundColor White
    
    Write-Host "Environment:" -ForegroundColor White
    Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor White
    Write-Host "  Working Directory: $PWD" -ForegroundColor White
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan

# Exit with appropriate code
if ($TestResults.OverallResult) {
    exit 0
}
else {
    exit 1
}