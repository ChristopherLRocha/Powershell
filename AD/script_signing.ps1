<#
.SYNOPSIS
    Automatically converts script files to UTF-8 encoding and signs them using a local code signing certificate.

.DESCRIPTION
    This script performs the following actions:
    - Logs execution start and end times.
    - Sets the working directory to a specified scripts folder.
    - Recursively finds all PowerShell-related script files (*.ps1, *.psd1, *.psm1).
    - Converts each file to UTF-8 encoding to ensure compatibility with signing.
    - Searches for a local code-signing certificate.
    - Signs all identified scripts with the certificate.
    - Logs the signing results to a timestamped log file.
    - Emails the log file to a specified recipient for auditing purposes.

.NOTES
    Useful for environments where script signing is required for compliance or security policy.
#>


# LOGGING
$logpath = '\\path\to\log\folder\' 
$Outputfile = '{0}\{1:yyyy.MM.dd-hh.mm.ss}_Signed_Scripts.txt' -f $logpath, $(Get-Date) 
$starttime = Get-Date
write-output "**** Script Start $starttime ****" | Out-File $Outputfile -append
# Set Working Directory 
$scriptdir = "\\path\to\script\folder"
cd $scriptdir
# Search for all Scripts, get their contents and save them using UTF8 
$scripts = Get-ChildItem -Recurse | Where-Object { ($_.Extension -ieq '.PS1') -or ($_.Extension -ieq '.PSD1') -or ($_.Extension -ieq '.PSM1') }
$list = @()
foreach ($script in $scripts)
{
  $list += $script.fullname
}
foreach($File in $list){
  $TempFile = "$($File).UTF8"
  get-content $File | out-file $TempFile -Encoding UTF8
  remove-item $File
  rename-item $TempFile $File
}
# Search the local machine for an installed code sign certificate
$cert = Get-ChildItem cert:\CurrentUser\my -codesigning
# Search for all Scripts
$Files = Get-ChildItem $scriptdir -Include *.ps1, *.psd1, *.psm1 -Recurse
# For each file found get its file path and sign the script 
Foreach($file in $Files) {
  $a = $file.fullname
  Set-AuthenticodeSignature -filepath $a -Certificate $cert -IncludeChain ALL -force | Out-File $Outputfile -append
}
$finishtime = Get-Date
write-output "**** Script Finished $finishtime ****" | Out-File $Outputfile -append
 
 
# Send Email Log
$mailParams = @{
  SmtpServer = 'smtp.company.com'
  To = 'admin@company.com'
  From = 'ScriptSigning@company.com'
  Subject = 'Auto Script Signing'
  Body = 'Attached is the log file showing the scripts that were signed'
  Attachments = $Outputfile 
}                 
Send-MailMessage @mailParams