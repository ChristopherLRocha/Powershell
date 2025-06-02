<#
.SYNOPSIS
    Reports Active Directory users who do NOT have "Smart card is required for interactive logon" enforced.

.DESCRIPTION
    This script searches a specified base OU and all its nested OUs for AD users, and reports those who:
        - Do NOT have smart card logon enforcement enabled
        - Are NOT disabled
        - Are NOT in a list of specified ignored users (by SamAccountName)
        - Are NOT located in specified excluded OUs

    The report is formatted as an HTML table and sent in the body of an email via an unauthenticated SMTP server.

.NOTES
    Requirements:
        - RSAT tools / ActiveDirectory module
        - Permissions to query AD users
        - An SMTP relay that allows unauthenticated sending
#>


# ===================== Variables =====================

# Base OU to search (searches all sub-OUs unless excluded)
$BaseOU = "OU=Group Policy Configured,DC=domain,DC=com"

# List of SamAccountNames to ignore
$IgnoreUsers = @("user1","user2")

# List of OUs to exclude (Distinguished Names)
$ExcludeOUs = @(
    "OU=Shared Accounts,OU=Users & Groups,OU=Group Policy Configured,DC=domain,DC=com",
    "OU=Users & Groups,OU=Group Policy Configured,DC=domain,DC=com"
)

# Email settings
$SMTPServer = "your.smtp.com"
$From = "noreply@domain.com"
$To = "you@domain.com"
$Subject = "Users Without Smart Card Logon Enforced"

# =========================================================

# Smart card required flag
$SMARTCARD_REQUIRED_FLAG = 0x40000

# Import AD module
Import-Module ActiveDirectory

# Get users from the base OU and all sub-OUs
$allUsers = Get-ADUser -SearchBase $BaseOU -SearchScope Subtree -Filter * -Properties userAccountControl, Enabled, DistinguishedName

# Filter out users in excluded OUs
$users = $allUsers | Where-Object {
    $userDN = $_.DistinguishedName.ToLower()
    ($ExcludeOUs -notcontains ($ExcludeOUs | Where-Object { $userDN -like "*$($_.ToLower())*" })) -and
    $_.Enabled -eq $true -and
    ($IgnoreUsers -notcontains $_.SamAccountName)
}

# Filter users who do not have smart card enforced
$nonCompliantUsers = $users | Where-Object {
    ($_.userAccountControl -band $SMARTCARD_REQUIRED_FLAG) -eq 0
} | Select-Object Name, SamAccountName, DistinguishedName

# Create email body
if ($nonCompliantUsers.Count -eq 0) {
    $Body = "<p>All enabled users in '$BaseOU' (excluding specified OUs and users) have smart card logon enforcement enabled.</p>"
} else {
    $bodyLines = @()
    $bodyLines += "<h2>Users Without Smart Card Logon Enforced</h2>"
    $bodyLines += "<table border='1' cellpadding='4' cellspacing='0'>"
    $bodyLines += "<tr><th>Name</th><th>Username</th><th>Distinguished Name</th></tr>"

    foreach ($user in $nonCompliantUsers) {
        $bodyLines += "<tr><td>$($user.Name)</td><td>$($user.SamAccountName)</td><td>$($user.DistinguishedName)</td></tr>"
    }

    $bodyLines += "</table>"
    $Body = $bodyLines -join "`n"
}

# Send email
Send-MailMessage -From $From -To $To -Subject $Subject -BodyAsHtml -Body $Body -SmtpServer $SMTPServer

Write-Host "Report emailed to $To"
