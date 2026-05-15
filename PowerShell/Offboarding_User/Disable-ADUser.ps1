<#
.SYNOPSIS
    Disable an Active Directory user account for employee exit process.

.DESCRIPTION
    Performs user deactivation in Active Directory including:
    - Generating and setting a new secure random password
    - Disabling logon hours to prevent authentication
    - Hiding the user from the Global Address List
    - Disabling the user account
    - Moving the user to a designated "former employees" organizational unit

.AUTHOR
    Muhammad Yasir

.CREATED
    2026-05-15

.COPYRIGHT
    Copyright (c) 2026 Muhammad Yasir. All rights reserved.

.PARAMETER Username
    The Active Directory username to deactivate.

.PARAMETER TargetOU
    Distinguished name of the organizational unit where the user should be moved.
    Example: "OU=FormerEmployees,DC=contoso,DC=com"

.PARAMETER LogPath
    Path to the log file. Defaults to C:\Logs\ad-deactivation.log

.EXAMPLE
    .\Disable-ADUser.ps1 -Username "jdoe" `
      -TargetOU "OU=FormerEmployees,DC=contoso,DC=com"

.NOTES
    Requires Active Directory module and administrator privileges.
    Replace placeholder OU path with your domain structure.
    Run PowerShell as Administrator.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetOU = "OU=FormerEmployees,DC=contoso,DC=com",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\ad-deactivation.log"
)

$ErrorActionPreference = "SilentlyContinue"
$errorCounter = 0

# Ensure log directory exists
$LogDir = Split-Path -Path $LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Helper functions
function ScrambleString([string]$inputString) {     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    return -join $scrambledStringArray
}

function Get-RandomCharacters($length, $characters) { 
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length } 
    $private:ofs = "" 
    return [String]$characters[$random]
}

# Get username if not provided
if (-not $Username) {
    Write-Host "Enter the Active Directory username:" -ForegroundColor Yellow
    $Username = Read-Host
}

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   ACTIVE DIRECTORY USER DEACTIVATION   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Username: $Username" -ForegroundColor White
Write-Host "Target OU: $TargetOU" -ForegroundColor White
Write-Host ""

# Import Active Directory module
Write-Host "Importing Active Directory module..." -ForegroundColor Cyan
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Host "✗ ERROR: Could not import Active Directory module" -ForegroundColor Red
    Write-Host "  Details: $($Error[0])" -ForegroundColor Red
    
    $message = "$(Get-Date) - ERROR - AD Module Import Failed: $($Error[0])"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
    exit 1
}

Write-Host "✓ Module loaded" -ForegroundColor Green

# Verify user exists
Write-Host ""
Write-Host "Verifying user exists..." -ForegroundColor Cyan
try {
    $ADUser = Get-ADUser -Identity $Username -ErrorAction Stop
    Write-Host "✓ User found: $($ADUser.Name)" -ForegroundColor Green
} catch {
    Write-Host "✗ ERROR: User not found in Active Directory" -ForegroundColor Red
    Write-Host "  Username: $Username" -ForegroundColor Red
    
    $message = "$(Get-Date) - ERROR - User not found: $Username - $($Error[0])"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
    exit 1
}

# Generate new password
Write-Host ""
Write-Host "Generating secure random password..." -ForegroundColor Cyan
$Password = Get-RandomCharacters -length 4 -characters 'abcdefghikmnoprstuvwxyz'
$Password += Get-RandomCharacters -length 4 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$Password += Get-RandomCharacters -length 3 -characters '1234567890'
$Password += Get-RandomCharacters -length 3 -characters '-.,_:;#+*&%/()'
$Password = ScrambleString -inputString $Password
Write-Host "✓ Password generated (14 characters)" -ForegroundColor Green

# Reset password
Write-Host ""
Write-Host "Resetting user password..." -ForegroundColor Cyan
try {
    Set-ADAccountPassword -Identity $Username -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force) -ErrorAction Stop
    Write-Host "✓ Password reset successfully" -ForegroundColor Green
    
    $message = "$(Get-Date) - SUCCESS - Password reset for user: $Username"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
    
} catch {
    Write-Host "✗ ERROR: Failed to reset password" -ForegroundColor Red
    Write-Host "  Details: $($Error[0])" -ForegroundColor Red
    
    $errorMessage = "$(Get-Date) - ERROR - Password Reset Failed: $($Error[0])"
    Add-Content -Path $LogPath -Value $errorMessage -Encoding UTF8
    $errorCounter += 1
}

# Disable logon hours
Write-Host ""
Write-Host "Disabling logon hours..." -ForegroundColor Cyan
try {
    [byte[]]$noLogonHours = @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    Get-ADUser -Identity $Username | Set-ADUser -Replace @{logonhours = $noLogonHours} -ErrorAction Stop
    Write-Host "✓ Logon hours disabled" -ForegroundColor Green
    
    $message = "$(Get-Date) - SUCCESS - Logon hours disabled for user: $Username"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
    
} catch {
    Write-Host "✗ ERROR: Failed to disable logon hours" -ForegroundColor Red
    Write-Host "  Details: $($Error[0])" -ForegroundColor Red
    
    $errorMessage = "$(Get-Date) - ERROR - Logon Hours Failed: $($Error[0])"
    Add-Content -Path $LogPath -Value $errorMessage -Encoding UTF8
    $errorCounter += 1
}

# Hide from Global Address List
Write-Host ""
Write-Host "Hiding user from Global Address List..." -ForegroundColor Cyan
try {
    Set-ADUser $Username -Replace @{msExchHideFromAddressLists=$true} -ErrorAction Stop
    Write-Host "✓ Hidden from Global Address List" -ForegroundColor Green
    
    $message = "$(Get-Date) - SUCCESS - Hidden from GAL: $Username"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
    
} catch {
    Write-Host "⚠ WARNING: Could not hide from address list (Exchange not configured)" -ForegroundColor Yellow
    
    $message = "$(Get-Date) - WARNING - GAL Hide Failed: $($Error[0])"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
}

# Disable user account
Write-Host ""
Write-Host "Disabling user account..." -ForegroundColor Cyan
try {
    Disable-ADAccount -Identity $Username -ErrorAction Stop
    Write-Host "✓ Account disabled" -ForegroundColor Green
    
    $message = "$(Get-Date) - SUCCESS - Account disabled for user: $Username"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
    
} catch {
    Write-Host "✗ ERROR: Failed to disable account" -ForegroundColor Red
    Write-Host "  Details: $($Error[0])" -ForegroundColor Red
    
    $errorMessage = "$(Get-Date) - ERROR - Account Disable Failed: $($Error[0])"
    Add-Content -Path $LogPath -Value $errorMessage -Encoding UTF8
    $errorCounter += 1
}

# Move to target OU
Write-Host ""
Write-Host "Moving user to target organizational unit..." -ForegroundColor Cyan
try {
    $userGuid = (Get-ADUser -Identity $Username).ObjectGUID
    Move-ADObject -Identity $userGuid -TargetPath $TargetOU -ErrorAction Stop
    Write-Host "✓ User moved to: $TargetOU" -ForegroundColor Green
    
    $message = "$(Get-Date) - SUCCESS - User moved to OU: $TargetOU"
    Add-Content -Path $LogPath -Value $message -Encoding UTF8
    
} catch {
    Write-Host "✗ ERROR: Failed to move user to organizational unit" -ForegroundColor Red
    Write-Host "  Target OU: $TargetOU" -ForegroundColor Red
    Write-Host "  Details: $($Error[0])" -ForegroundColor Red
    
    $errorMessage = "$(Get-Date) - ERROR - Move to OU Failed: $TargetOU - $($Error[0])"
    Add-Content -Path $LogPath -Value $errorMessage -Encoding UTF8
    $errorCounter += 1
}

# Summary
Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Completion Status: $(if($errorCounter -eq 0) {'SUCCESS ✓'} else {'PARTIAL ⚠'})" -ForegroundColor $(if($errorCounter -eq 0) {'Green'} else {'Yellow'})
Write-Host "Errors: $errorCounter" -ForegroundColor $(if($errorCounter -gt 0) {'Red'} else {'Green'})
Write-Host "Log: $LogPath" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

exit $errorCounter
