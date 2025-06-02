<#
.SYNOPSIS
    Copies Active Directory group memberships from one user to another.

.DESCRIPTION
    This script prompts for a source user, target user, and domain controller.
    It first removes the target user from all current AD groups, then copies all group memberships from the source user to the target user.
    Useful for replicating group memberships when replacing or updating user accounts.

.PARAMETER sourceUser
    The sAMAccountName (or username) of the source user whose group memberships will be copied.

.PARAMETER targetUser
    The sAMAccountName (or username) of the target user to receive the copied group memberships.

.PARAMETER domainController
    The domain controller to query and perform group modifications against.

.NOTES
    - Requires Active Directory PowerShell module.
    - User running the script must have permissions to modify group memberships.
    - The script removes all existing group memberships of the target user before adding new ones.
    - No error handling included for groups that may not allow membership changes.
#>

# Clear the screen
Clear-Host

# Prompt the user for the source user, target user, and domain controller
$sourceUser = Read-Host "Enter the source user flast"
$targetUser = Read-Host "Enter the target user flast"
$domainController = Read-Host "Enter the domain controller"

# Remove all groups from the target user
$targetGroups = Get-ADUser $targetUser -Server $domainController | Get-ADPrincipalGroupMembership -Server $domainController
foreach ($group in $targetGroups) {
    Remove-ADGroupMember -Identity $group -Members $targetUser -Server $domainController -Confirm:$false
}

# Copy groups from the source user to the target user
$sourceGroups = Get-ADUser $sourceUser -Server $domainController | Get-ADPrincipalGroupMembership -Server $domainController
foreach ($group in $sourceGroups) {
    Add-ADGroupMember -Identity $group -Members $targetUser -Server $domainController
}

Write-Host "Group membership successfully copied from $sourceUser to $targetUser"
