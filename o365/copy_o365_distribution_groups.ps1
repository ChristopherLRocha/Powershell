<#
.SYNOPSIS
Copies distribution group memberships from one Exchange Online user to another.

.DESCRIPTION
This script connects to Exchange Online and checks the group memberships of a specified source user. 
It optionally removes all existing distribution group memberships from the target user, then copies all 
distribution group memberships from the source user to the target user. The script confirms user existence 
and prompts for confirmation before making changes. It outputs the groups both users belong to before and 
after the transfer.

.PARAMETER sourceUser
The email address (PrimarySmtpAddress) of the user whose distribution group memberships will be copied.

.PARAMETER targetUser
The email address (PrimarySmtpAddress) of the user who will receive the group memberships.

.NOTES
- Requires Exchange Online PowerShell module.
- The script prompts the user to choose whether to remove existing group memberships from the target user.
- Includes validation and confirmation steps to prevent accidental changes.
#>

# Connect to Exchange Online
if (-not (Get-Module ExchangeOnlineManagement)) {
    Install-Module ExchangeOnlineManagement -Force -Scope CurrentUser
}
Import-Module ExchangeOnlineManagement

# Authenticate to Exchange Online
Connect-ExchangeOnline -ShowProgress $true

# Prompt for source user
$sourceUser = Read-Host "Enter the source user's email address"
while ([string]::IsNullOrWhiteSpace($sourceUser)) {
    $sourceUser = Read-Host "Source user email cannot be empty. Enter the source user's email address"
}

# Prompt for target user
$targetUser = Read-Host "Enter the target user's email address"
while ([string]::IsNullOrWhiteSpace($targetUser)) {
    $targetUser = Read-Host "Target user email cannot be empty. Enter the target user's email address"
}

# Check if source user exists
$sourceUserExists = Get-User -Identity $sourceUser -ErrorAction SilentlyContinue
if (-not $sourceUserExists) {
    Write-Host "Error: Source user '$sourceUser' not found." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false
    pause
    exit
}

# Check if target user exists
$targetUserExists = Get-User -Identity $targetUser -ErrorAction SilentlyContinue
if (-not $targetUserExists) {
    Write-Host "Error: Target user '$targetUser' not found." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false
    pause
    exit
}

# Get initial distribution list memberships for source and target users
Write-Host "Retrieving group memberships for source user..." -ForegroundColor Cyan
$sourceGroupsBefore = Get-DistributionGroup | Where-Object {
    (Get-DistributionGroupMember -Identity $_.Identity | Where-Object {$_.PrimarySmtpAddress -eq $sourceUser})
}

Write-Host "Retrieving group memberships for target user..." -ForegroundColor Yellow
$targetGroupsBefore = Get-DistributionGroup | Where-Object {
    (Get-DistributionGroupMember -Identity $_.Identity | Where-Object {$_.PrimarySmtpAddress -eq $targetUser})
}

Write-Host "The source user is a member of the following groups before transfer:" -ForegroundColor Cyan
$sourceGroupsBefore | ForEach-Object { Write-Host $_.PrimarySmtpAddress }

Write-Host "The target user is a member of the following groups before transfer:" -ForegroundColor Yellow
$targetGroupsBefore | ForEach-Object { Write-Host $_.PrimarySmtpAddress }

if ($sourceGroupsBefore.Count -eq 0) {
    Write-Host "No distribution list memberships found for $sourceUser" -ForegroundColor Yellow
    Disconnect-ExchangeOnline -Confirm:$false
    pause
    exit
}

# Ask if we want to remove all existing groups from the target user or just add
$mode = Read-Host "Would you like to (R)emove all existing groups from the target user before copying, or (A)dd to their existing groups? (R/A)"
while ($mode -ne 'R' -and $mode -ne 'A') {
    $mode = Read-Host "Invalid input. Please enter 'R' to remove existing groups or 'A' to add to existing groups."
}

if ($mode -eq 'R') {
    Write-Host "Removing all existing distribution group memberships from $targetUser..." -ForegroundColor Red
    foreach ($group in $targetGroupsBefore) {
        try {
            Remove-DistributionGroupMember -Identity $group.PrimarySmtpAddress -Member $targetUser -Confirm:$false -ErrorAction Stop
            Write-Host "Removed $targetUser from $($group.PrimarySmtpAddress)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to remove $targetUser from $($group.PrimarySmtpAddress): $_" -ForegroundColor Red
        }
    }
}

# Confirm before proceeding with the transfer
$confirm = Read-Host "Would you like to proceed with copying these memberships to $targetUser? (Y/N)"
if ($confirm -ne 'Y') {
    Write-Host "Operation canceled." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false
    pause
    exit
}

# Add target user to groups
foreach ($group in $sourceGroupsBefore) {
    try {
        Add-DistributionGroupMember -Identity $group.PrimarySmtpAddress -Member $targetUser -ErrorAction Stop
        Write-Host "Added $targetUser to $($group.PrimarySmtpAddress)" -ForegroundColor Green
    } catch {
        Write-Host "Failed to add $targetUser to $($group.PrimarySmtpAddress): $_" -ForegroundColor Red
    }
}

# Get final distribution list memberships for target user
Write-Host "Retrieving updated group memberships for target user..." -ForegroundColor Green
$targetGroupsAfter = Get-DistributionGroup | Where-Object {
    (Get-DistributionGroupMember -Identity $_.Identity | Where-Object {$_.PrimarySmtpAddress -eq $targetUser})
}

Write-Host "The target user is now a member of the following groups after transfer:" -ForegroundColor Green
$targetGroupsAfter | ForEach-Object { Write-Host $_.PrimarySmtpAddress }

# Disconnect session
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Done." -ForegroundColor Green

# Prevent window from closing immediately
pause
