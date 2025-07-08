# Google Drive Sync Module for Microsoft Product Management Tools
# Provides secure certificate and configuration file synchronization

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Import required modules
if (-not (Get-Module -Name Microsoft.PowerShell.Security -ListAvailable)) {
    Write-Warning "Microsoft.PowerShell.Security module not found. Some encryption features may not work."
}

# Global variables
$script:GoogleDriveConfig = $null
$script:AccessToken = $null
$script:TokenExpiry = $null

function Initialize-GoogleDriveSync {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "Config/googledrive.json"
    )
    
    Write-Host "Initializing Google Drive Sync..." -ForegroundColor Green
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Google Drive configuration file not found: $ConfigPath"
    }
    
    $script:GoogleDriveConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    
    # Validate configuration
    if (-not $script:GoogleDriveConfig.GoogleDriveAPI.ClientId -or 
        $script:GoogleDriveConfig.GoogleDriveAPI.ClientId -eq "YOUR_GOOGLE_CLIENT_ID") {
        throw "Google Drive API credentials not configured. Please update $ConfigPath"
    }
    
    Write-Host "Google Drive Sync initialized successfully" -ForegroundColor Green
}

function Get-GoogleDriveAccessToken {
    [CmdletBinding()]
    param()
    
    # Check if token is still valid
    if ($script:AccessToken -and $script:TokenExpiry -and (Get-Date) -lt $script:TokenExpiry) {
        return $script:AccessToken
    }
    
    Write-Host "Refreshing Google Drive access token..." -ForegroundColor Yellow
    
    $tokenParams = @{
        Uri = $script:GoogleDriveConfig.GoogleDriveAPI.TokenUrl
        Method = "POST"
        Headers = @{
            "Content-Type" = "application/x-www-form-urlencoded"
        }
        Body = @{
            client_id = $script:GoogleDriveConfig.GoogleDriveAPI.ClientId
            client_secret = $script:GoogleDriveConfig.GoogleDriveAPI.ClientSecret
            refresh_token = $script:GoogleDriveConfig.GoogleDriveAPI.RefreshToken
            grant_type = "refresh_token"
        }
    }
    
    try {
        $response = Invoke-RestMethod @tokenParams
        $script:AccessToken = $response.access_token
        $script:TokenExpiry = (Get-Date).AddSeconds($response.expires_in - 60)
        
        Write-Host "Access token refreshed successfully" -ForegroundColor Green
        return $script:AccessToken
    }
    catch {
        Write-Error "Failed to refresh access token: $($_.Exception.Message)"
        throw
    }
}

function New-GoogleDriveFolder {
    [CmdletBinding()]
    param(
        [string]$FolderName,
        [string]$ParentFolderId = "root"
    )
    
    $accessToken = Get-GoogleDriveAccessToken
    
    $folderData = @{
        name = $FolderName
        mimeType = "application/vnd.google-apps.folder"
        parents = @($ParentFolderId)
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://www.googleapis.com/drive/v3/files" -Method POST -Headers $headers -Body $folderData
        Write-Host "Created folder: $FolderName (ID: $($response.id))" -ForegroundColor Green
        return $response.id
    }
    catch {
        Write-Error "Failed to create folder: $($_.Exception.Message)"
        throw
    }
}

function Get-GoogleDriveFolder {
    [CmdletBinding()]
    param(
        [string]$FolderName,
        [string]$ParentFolderId = "root"
    )
    
    $accessToken = Get-GoogleDriveAccessToken
    
    $query = "name='$FolderName' and mimeType='application/vnd.google-apps.folder' and '$ParentFolderId' in parents and trashed=false"
    $uri = "https://www.googleapis.com/drive/v3/files?q=$([System.Web.HttpUtility]::UrlEncode($query))"
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers
        if ($response.files.Count -gt 0) {
            return $response.files[0].id
        }
        return $null
    }
    catch {
        Write-Error "Failed to search for folder: $($_.Exception.Message)"
        throw
    }
}

function Set-GoogleDriveRemoteFolder {
    [CmdletBinding()]
    param()
    
    $folderName = $script:GoogleDriveConfig.SyncSettings.RemoteFolderName
    
    # Check if folder exists
    $folderId = Get-GoogleDriveFolder -FolderName $folderName
    
    if (-not $folderId) {
        Write-Host "Creating remote folder: $folderName" -ForegroundColor Yellow
        $folderId = New-GoogleDriveFolder -FolderName $folderName
    }
    
    # Update configuration with folder ID
    $script:GoogleDriveConfig.SyncSettings.RemoteFolderId = $folderId
    
    # Save updated configuration
    $configPath = "Config/googledrive.json"
    $script:GoogleDriveConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
    
    Write-Host "Remote folder configured: $folderName (ID: $folderId)" -ForegroundColor Green
    return $folderId
}

function Invoke-FileEncryption {
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [string]$Password
    )
    
    if (-not $script:GoogleDriveConfig.SyncSettings.EnableEncryption) {
        return $FilePath
    }
    
    $encryptedPath = "$FilePath.encrypted"
    
    try {
        $fileContent = Get-Content -Path $FilePath -Raw -Encoding Byte
        $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
        
        # Simple XOR encryption for demonstration
        $key = [System.Text.Encoding]::UTF8.GetBytes($Password)
        $encryptedContent = for ($i = 0; $i -lt $fileContent.Length; $i++) {
            $fileContent[$i] -bxor $key[$i % $key.Length]
        }
        
        [System.IO.File]::WriteAllBytes($encryptedPath, $encryptedContent)
        Write-Host "File encrypted: $encryptedPath" -ForegroundColor Green
        return $encryptedPath
    }
    catch {
        Write-Error "Failed to encrypt file: $($_.Exception.Message)"
        throw
    }
}

function Invoke-FileDecryption {
    [CmdletBinding()]
    param(
        [string]$EncryptedFilePath,
        [string]$OutputPath,
        [string]$Password
    )
    
    try {
        $encryptedContent = [System.IO.File]::ReadAllBytes($EncryptedFilePath)
        $key = [System.Text.Encoding]::UTF8.GetBytes($Password)
        
        $decryptedContent = for ($i = 0; $i -lt $encryptedContent.Length; $i++) {
            $encryptedContent[$i] -bxor $key[$i % $key.Length]
        }
        
        [System.IO.File]::WriteAllBytes($OutputPath, $decryptedContent)
        Write-Host "File decrypted: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to decrypt file: $($_.Exception.Message)"
        throw
    }
}

function Send-FileToGoogleDrive {
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [string]$RemoteFolderId,
        [string]$RemoteFileName = $null
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $accessToken = Get-GoogleDriveAccessToken
    
    if (-not $RemoteFileName) {
        $RemoteFileName = Split-Path $FilePath -Leaf
    }
    
    # Encrypt file if enabled
    $uploadFilePath = $FilePath
    if ($script:GoogleDriveConfig.SyncSettings.EnableEncryption) {
        $uploadFilePath = Invoke-FileEncryption -FilePath $FilePath -Password $script:GoogleDriveConfig.SyncSettings.EncryptionPassword
        $RemoteFileName += ".encrypted"
    }
    
    # Check file size
    $fileSize = (Get-Item $uploadFilePath).Length
    $maxSizeMB = $script:GoogleDriveConfig.Security.MaxFileSize
    if ($fileSize -gt ($maxSizeMB * 1MB)) {
        throw "File too large: $([math]::Round($fileSize / 1MB, 2))MB exceeds limit of ${maxSizeMB}MB"
    }
    
    # Create file metadata
    $fileMetadata = @{
        name = $RemoteFileName
        parents = @($RemoteFolderId)
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    
    try {
        # Use resumable upload for larger files
        $uri = "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"
        
        $boundary = "----boundary$(Get-Random)"
        $bodyLines = @(
            "--$boundary",
            "Content-Type: application/json; charset=UTF-8",
            "",
            $fileMetadata,
            "",
            "--$boundary",
            "Content-Type: application/octet-stream",
            "",
            [System.IO.File]::ReadAllText($uploadFilePath),
            "",
            "--$boundary--"
        )
        
        $body = $bodyLines -join "`r`n"
        $headers["Content-Type"] = "multipart/related; boundary=$boundary"
        
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body
        
        Write-Host "Uploaded: $FilePath -> $RemoteFileName (ID: $($response.id))" -ForegroundColor Green
        
        # Clean up encrypted file
        if ($uploadFilePath -ne $FilePath) {
            Remove-Item $uploadFilePath -Force
        }
        
        # Log the upload
        if ($script:GoogleDriveConfig.Security.EnableAuditLog) {
            $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - UPLOAD: $FilePath -> $RemoteFileName"
            Add-Content -Path $script:GoogleDriveConfig.Security.AuditLogPath -Value $logEntry
        }
        
        return $response.id
    }
    catch {
        Write-Error "Failed to upload file: $($_.Exception.Message)"
        throw
    }
}

function Sync-CertificatesToGoogleDrive {
    [CmdletBinding()]
    param(
        [string]$LocalPath = $null,
        [switch]$Force
    )
    
    if (-not $script:GoogleDriveConfig) {
        throw "Google Drive Sync not initialized. Run Initialize-GoogleDriveSync first."
    }
    
    if (-not $LocalPath) {
        $LocalPath = $script:GoogleDriveConfig.SyncSettings.LocalCertificatesPath
    }
    
    if (-not (Test-Path $LocalPath)) {
        throw "Local certificates path not found: $LocalPath"
    }
    
    Write-Host "Starting certificate synchronization..." -ForegroundColor Green
    
    # Ensure remote folder exists
    $remoteFolderId = $script:GoogleDriveConfig.SyncSettings.RemoteFolderId
    if (-not $remoteFolderId) {
        $remoteFolderId = Set-GoogleDriveRemoteFolder
    }
    
    # Get files to sync
    $allowedTypes = $script:GoogleDriveConfig.Security.AllowedFileTypes
    $excludePatterns = $script:GoogleDriveConfig.SyncSettings.ExcludePatterns
    
    $files = Get-ChildItem -Path $LocalPath -File | Where-Object {
        $file = $_
        $allowed = $allowedTypes | Where-Object { $file.Extension -eq $_ }
        $excluded = $excludePatterns | Where-Object { $file.Name -like $_ }
        return $allowed -and -not $excluded
    }
    
    $syncCount = 0
    foreach ($file in $files) {
        try {
            Write-Host "Syncing: $($file.Name)..." -ForegroundColor Yellow
            Send-FileToGoogleDrive -FilePath $file.FullName -RemoteFolderId $remoteFolderId
            $syncCount++
        }
        catch {
            Write-Warning "Failed to sync $($file.Name): $($_.Exception.Message)"
        }
    }
    
    Write-Host "Certificate synchronization completed: $syncCount files synced" -ForegroundColor Green
}

function Start-GoogleDriveFileWatcher {
    [CmdletBinding()]
    param()
    
    if (-not $script:GoogleDriveConfig.SyncSettings.SyncOnFileChange) {
        Write-Host "File change monitoring is disabled" -ForegroundColor Yellow
        return
    }
    
    $watchPath = $script:GoogleDriveConfig.SyncSettings.LocalCertificatesPath
    if (-not (Test-Path $watchPath)) {
        throw "Watch path not found: $watchPath"
    }
    
    Write-Host "Starting file system watcher on: $watchPath" -ForegroundColor Green
    
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $watchPath
    $watcher.Filter = "*.*"
    $watcher.IncludeSubdirectories = $false
    $watcher.EnableRaisingEvents = $true
    
    $action = {
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        
        if ($changeType -eq "Created" -or $changeType -eq "Changed") {
            Start-Sleep -Seconds 2  # Wait for file to be fully written
            
            try {
                $allowedTypes = $script:GoogleDriveConfig.Security.AllowedFileTypes
                $fileExtension = [System.IO.Path]::GetExtension($path)
                
                if ($allowedTypes -contains $fileExtension) {
                    Write-Host "Detected change: $path" -ForegroundColor Yellow
                    
                    $remoteFolderId = $script:GoogleDriveConfig.SyncSettings.RemoteFolderId
                    if (-not $remoteFolderId) {
                        $remoteFolderId = Set-GoogleDriveRemoteFolder
                    }
                    
                    Send-FileToGoogleDrive -FilePath $path -RemoteFolderId $remoteFolderId
                }
            }
            catch {
                Write-Warning "Auto-sync failed for $path: $($_.Exception.Message)"
            }
        }
    }
    
    Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
    
    Write-Host "File system watcher started. Press Ctrl+C to stop." -ForegroundColor Green
    
    try {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    finally {
        $watcher.Dispose()
        Write-Host "File system watcher stopped" -ForegroundColor Yellow
    }
}

function Test-GoogleDriveConnection {
    [CmdletBinding()]
    param()
    
    Write-Host "Testing Google Drive connection..." -ForegroundColor Yellow
    
    try {
        Initialize-GoogleDriveSync
        $accessToken = Get-GoogleDriveAccessToken
        
        # Test API access
        $headers = @{
            "Authorization" = "Bearer $accessToken"
        }
        
        $response = Invoke-RestMethod -Uri "https://www.googleapis.com/drive/v3/about?fields=user" -Headers $headers
        
        Write-Host "✓ Connected to Google Drive successfully" -ForegroundColor Green
        Write-Host "✓ User: $($response.user.displayName) ($($response.user.emailAddress))" -ForegroundColor Green
        
        # Test folder access
        $remoteFolderId = Set-GoogleDriveRemoteFolder
        Write-Host "✓ Remote folder configured: $($script:GoogleDriveConfig.SyncSettings.RemoteFolderName)" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Error "Google Drive connection test failed: $($_.Exception.Message)"
        return $false
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-GoogleDriveSync',
    'Sync-CertificatesToGoogleDrive',
    'Start-GoogleDriveFileWatcher',
    'Test-GoogleDriveConnection'
)