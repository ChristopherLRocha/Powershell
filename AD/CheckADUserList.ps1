<#
.SYNOPSIS
    Monitors Active Directory user account changes between runs.

.DESCRIPTION
    This script captures a snapshot of current Active Directory user accounts and compares it to the previous snapshot.
    If any differences are detected (such as added or removed accounts), it generates a difference report and emails it to PC admins.
    It handles cleanup and file rotation automatically to maintain accurate comparisons across runs.

.NOTES
    Requirements: ActiveDirectory module, SMTP access

#>

#-----------------variables--------------

$CurrentFile = ".\current_users.txt"
$PreviousFile = ".\previous_users.txt"
$DifferenceFile = ".\different_users.txt"

#----------------------------------------

# if there was a difference file the last time delete it
if (Test-Path -Path $DifferenceFile -PathType Leaf) {Remove-Item -Path $DifferenceFile} 

# if the previous file exists delete it
# if the current file exists rename it to previous file
if (Test-Path -Path $CurrentFile -PathType Leaf) {
  if (Test-Path -Path $PreviousFile -PathType Leaf) {
    Remove-Item -Path $PreviousFile
  } 
  Rename-Item -Path $CurrentFile -NewName $PreviousFile
}

# get list of current users from active directory
Get-ADUser -Filter * | Sort-Object -Property SamAccountName | Format-Table SamAccountName -HideTableHeaders > $CurrentFile
#compare current user list with previous user list and create difference list
Compare-Object (Get-Content $CurrentFile) (Get-Content $PreviousFile) | Format-Table InputObject -HideTableHeaders > $DifferenceFile

# if there are differences then email them to pc admins
if (Test-Path -Path $DifferenceFile -PathType Leaf) {
  $mailParams = @{
    SmtpServer = 'smtp.company.com'
    To = 'pc_admins@company.com'
    From = 'noreply@company.com'
    Subject = "Active Directory user accounts changed since last checked."
    Body = "Please see attached for the list of Active Directory user accounts that have changed since last checked."
    Attachments = $DifferenceFile
  }                 
  Send-MailMessage @mailParams
}