<#
.SYNOPSIS
    Archive Windows user profiles from remote servers.

.DESCRIPTION
    Searches for Windows user profiles (V2 and V6) on remote profile servers,
    copies them to an archive location, and removes the originals.

.AUTHOR
    Muhammad Yasir

.CREATED
    2026-05-15

.COPYRIGHT
    Copyright (c) 2026 Muhammad Yasir. All rights reserved.

.PARAMETER Username
    The username whose profiles should be archived.

.PARAMETER ProfileServers
    Array of profile server names or UNC paths.
    Example: @("\\profile-server-01\profiles", "\\profile-server-02\profiles")

.PARAMETER DestinationPath
    UNC path or local path to archive destination.
    Example: "\\archive-server\archives\windows-profiles"

.PARAMETER ProfileVersions
    Array of profile versions to search for. Defaults to @("V2", "V6")

.PARAMETER Credentials
    Credentials for accessing archive location (if required).

.PARAMETER LogPath
    Path to the log file. Defaults to C:\Logs\archive.log

.EXAMPLE
    $servers = @("\\profile-server-01\profiles", "\\profile-server-02\profiles")
    .\Copy-WindowsProfiles-to-Archive.ps1 -Username "jdoe" `
      -ProfileServers $servers `
      -DestinationPath "\\archive-server\archives\windows-profiles"

.NOTES
    Requires administrator privileges.
    Searches for V2 and V6 profile versions by default.
    Handles file ownership changes before deletion.
    Replace placeholder paths before use.
    Run PowerShell as Administrator.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string[]]$ProfileServers = @(
        "\\profile-server-01\profiles",
        "\\profile-server-02\profiles",
        "\\profile-server-03\profiles"
    ),
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "\\archive-server\archives\windows-profiles",
    
    [Parameter(Mandatory=$false)]
    [string[]]$ProfileVersions = @("V2", "V6"),
    
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credentials,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\archive.log"
)

$ErrorActionPreference = "SilentlyContinue"
$errorCounter = 0
$profilesArchived = 0

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
Write-Host "║   WINDOWS PROFILES ARCHIVE UTILITY     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Username: $Username" -ForegroundColor White
Write-Host "Profile Versions: $($ProfileVersions -join ', ')" -ForegroundColor White
Write-Host "Destination: $DestinationPath" -ForegroundColor White
Write-Host ""

Write-Host "Scanning profile servers..." -ForegroundColor Cyan
Write-Host ""

# Process each profile server
foreach ($server in $ProfileServers) {
    Write-Host "Server: $server" -ForegroundColor Yellow
    
    if (-not (Test-Path -Path $server)) {
        Write-Host "  ✗ Server not accessible" -ForegroundColor Yellow
        
        $message = "$(Get-Date) - WARNING - Profile server not accessible: $server"
        Add-Content -Path $LogPath -Value $message -Encoding UTF8
        continue
    }
    
    # Search for each profile version
    foreach ($version in $ProfileVersions) {
        $profilePath = Join-Path $server "$Username.$version"
        
        if (Test-Path -Path $profilePath) {
            Write-Host "  ✓ Found profile: $Username.$version" -ForegroundColor Green
            
            try {
                $archiveFolder = Join-Path $DestinationPath "$server-$version"
                
                Write-Host "    → Copying to archive..." -ForegroundColor Cyan
                Copy-Item -Path $profilePath -Recurse -Destination $archiveFolder -ErrorAction Stop -Force
                Write-Host "    ✓ Copied successfully" -ForegroundColor Green
                
                Write-Host "    → Taking ownership..." -ForegroundColor Cyan
                & takeown.exe /f $profilePath /r /d Y | Out-Null
                
                Write-Host "    → Removing original..." -ForegroundColor Cyan
                Remove-Item -Path $profilePath -Recurse -ErrorAction Stop -Force
                Write-Host "    ✓ Original removed" -ForegroundColor Green
                
                $profilesArchived++
                
                $message = "$(Get-Date) - SUCCESS - Windows profile archived: $server\$Username.$version"
                Add-Content -Path $LogPath -Value $message -Encoding UTF8
                
            } catch {
                Write-Host "    ✗ ERROR: Failed to archive profile" -ForegroundColor Red
                Write-Host "    Details: $($Error[0])" -ForegroundColor Red
                
                $errorMessage = "$(Get-Date) - ERROR - Windows Profile Failed: $server\$Username.$version - $($Error[0])"
                Add-Content -Path $LogPath -Value $errorMessage -Encoding UTF8
                $errorCounter += 1
            }
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Profiles Archived: $profilesArchived" -ForegroundColor Green
Write-Host "Errors: $errorCounter" -ForegroundColor $(if($errorCounter -gt 0) {'Red'} else {'Green'})
Write-Host "Status: $(if($profilesArchived -gt 0) {'SUCCESS ✓'} else {'NO PROFILES FOUND'})" -ForegroundColor $(if($profilesArchived -gt 0) {'Green'} else {'Yellow'})
Write-Host "Log: $LogPath" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

exit $errorCounter
