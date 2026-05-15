<#
.SYNOPSIS
    Archive user's home drive to a network archive location.

.DESCRIPTION
    Copies a user's home drive from a file server to a designated archive location,
    then removes the original directory after successful copy.

.AUTHOR
    Muhammad Yasir

.CREATED
    2026-05-15

.COPYRIGHT
    Copyright (c) 2026 Muhammad Yasir. All rights reserved.

.PARAMETER Username
    The username whose home drive should be archived.

.PARAMETER SourcePath
    UNC path to the source home drive location.
    Example: "\\file-server\home"

.PARAMETER DestinationPath
    UNC path or local path to archive destination.
    Example: "\\archive-server\archives\home-drives"

.PARAMETER Credentials
    Credentials for accessing archive location (if required).

.PARAMETER LogPath
    Path to the log file. Defaults to C:\Logs\archive.log

.EXAMPLE
    .\Copy-HomeDrive-to-Archive.ps1 -Username "jdoe" `
      -SourcePath "\\file-server\home" `
      -DestinationPath "\\archive-server\archives"

.NOTES
    Requires administrator privileges.
    Handles file ownership changes before deletion.
    Replace placeholder paths before use.
    Run PowerShell as Administrator.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "\\file-server\home",
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "\\archive-server\archives\home-drives",
    
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credentials,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\archive.log"
)

$ErrorActionPreference = "SilentlyContinue"
$errorCounter = 0

# Ensure log directory exists
$LogDir = Split-Path -Path $LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Get username if not provided
if (-not $Username) {
    Write-Host "Enter the username to archive:" -ForegroundColor Yellow
    $Username = Read-Host
}

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   HOME DRIVE ARCHIVE UTILITY           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Username: $Username" -ForegroundColor White
Write-Host "Source: $SourcePath" -ForegroundColor White
Write-Host "Destination: $DestinationPath" -ForegroundColor White
Write-Host ""

# Build full paths
$homeDrivePath = Join-Path $SourcePath $Username
$archiveDestination = Join-Path $DestinationPath $Username

Write-Host "Archiving home drive..." -ForegroundColor Cyan

# Check if source exists
if (Test-Path -Path $homeDrivePath) {
    Write-Host "✓ Home drive found: $homeDrivePath" -ForegroundColor Green
    
    try {
        Write-Host "  → Copying files to archive..." -ForegroundColor Cyan
        Copy-Item -Path $homeDrivePath -Recurse -Destination $archiveDestination -ErrorAction Stop -Force
        Write-Host "  ✓ Copy successful" -ForegroundColor Green
        
        # Remove original
        Write-Host "  → Taking ownership of original directory..." -ForegroundColor Cyan
        & takeown.exe /f $homeDrivePath /r /d Y | Out-Null
        
        Write-Host "  → Removing original directory..." -ForegroundColor Cyan
        Remove-Item -Path $homeDrivePath -Recurse -ErrorAction Stop -Force
        Write-Host "  ✓ Original directory removed" -ForegroundColor Green
        
        $message = "$(Get-Date) - SUCCESS - Home drive archived: $homeDrivePath → $archiveDestination"
        Add-Content -Path $LogPath -Value $message -Encoding UTF8
        
    } catch {
        Write-Host "  ✗ ERROR: Failed to archive home drive" -ForegroundColor Red
        Write-Host "  Details: $($Error[0])" -ForegroundColor Red
        
        $errorMessage = "$(Get-Date) - ERROR - Home Drive Archive Failed: $($Error[0])"
        Add-Content -Path $LogPath -Value $errorMessage -Encoding UTF8
        $errorCounter += 1
    }
} else {
    Write-Host "✗ Home drive not found at: $homeDrivePath" -ForegroundColor Yellow
    
    $message = "$(Get-Date) - WARNING - Home drive not found: $homeDrivePath"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
}

# Summary
Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Completion Status: $(if($errorCounter -eq 0) {'SUCCESS ✓'} else {'FAILED ✗'})" -ForegroundColor $(if($errorCounter -eq 0) {'Green'} else {'Red'})
Write-Host "Errors: $errorCounter" -ForegroundColor $(if($errorCounter -gt 0) {'Red'} else {'Green'})
Write-Host "Log: $LogPath" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

exit $errorCounter
