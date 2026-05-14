<#
.SYNOPSIS
    Rename a local Windows device and join it to an Active Directory domain.

.DESCRIPTION
    Local workstation provisioning script for renaming a Windows device,
    joining it to an Active Directory domain, and placing it in a target OU.

.AUTHOR
    Muhammad Yasir

.CREATED
    2026-05-15

.COPYRIGHT
    Copyright (c) 2026 Muhammad Yasir. All rights reserved.

.NOTES
    Run PowerShell as Administrator.
    Replace all placeholder values before use.
#>

# =========================
# Configuration
# =========================

$SitePrefix     = "SITE"
$DeviceType     = "NB"
$AssetNumber    = "001"

$DomainName     = "example.local"
$OUPath         = "OU=Computers,DC=example,DC=local"

$DomainUsername = "EXAMPLE\domainjoinuser"

# =========================
# Generate computer name
# Example: SITE-W10NB001
# =========================

$NewComputerName = "$SitePrefix-W10$DeviceType$AssetNumber"

# =========================
# Get domain password securely
# =========================

$SecurePassword = Read-Host "Enter domain join password" -AsSecureString

$DomainCredential = New-Object System.Management.Automation.PSCredential `
    ($DomainUsername, $SecurePassword)

# =========================
# Show confirmation
# =========================

Write-Host "Current computer name: $env:COMPUTERNAME"
Write-Host "New computer name:     $NewComputerName"
Write-Host "Domain:                $DomainName"
Write-Host "Target OU:             $OUPath"

$Confirm = Read-Host "Do you want to continue? (Y/N)"

if ($Confirm -ne "Y") {
    Write-Host "Operation cancelled."
    exit
}

# =========================
# Rename and join domain
# =========================

Add-Computer `
    -DomainName $DomainName `
    -NewName $NewComputerName `
    -Credential $DomainCredential `
    -OUPath $OUPath `
    -Restart