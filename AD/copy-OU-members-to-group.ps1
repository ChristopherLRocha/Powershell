<#
.SYNOPSIS
    Adds all users from a specified Organizational Unit (OU) to a specified Active Directory group.

.DESCRIPTION
    This script retrieves all user accounts within a specified OU and adds them to a designated AD group.
    It is useful for bulk group membership updates based on OU membership.

.PARAMETER OU
    Distinguished Name (DN) of the target OU containing the users.

.PARAMETER Group
    The name (sAMAccountName or CN) of the Active Directory group to which the users will be added.

.NOTES
    - Requires the Active Directory PowerShell module.
    - Ensure you have appropriate permissions to read user objects and modify group memberships.
    - This script does not check if users are already members of the group before attempting to add them.
#>

# Define variables
$OU = "OU=YourOUName,DC=YourDomain,DC=com"
$Group = "YourGroupName"

# Get all members of the specified OU
$Members = Get-ADUser -Filter * -SearchBase $OU

# Add each user to the group
foreach ($Member in $Members) {
    Add-ADGroupMember -Identity $Group -Members $Member.SamAccountName
}
