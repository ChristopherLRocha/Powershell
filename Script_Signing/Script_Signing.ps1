<#
.SYNOPSIS
Automatically converts and signs PowerShell scripts in a specified directory using a local code signing certificate.

.DESCRIPTION
This script performs the following operations:
1. Logs script start time and actions to a timestamped log file.
2. Sets the working directory to a predefined script folder.
3. Recursively searches for all `.ps1`, `.psd1`, and `.psm1` files.
4. Converts each script file to UTF-8 encoding to ensure compatibility.
5. Locates a local code signing certificate from the current user store.
6. Signs all applicable script files with the certificate, appending the results to the log.
7. Sends an email with the log file attached for audit and review purposes.

.NOTES
- Ensure that a valid code signing certificate is available in the CurrentUser\My certificate store.
- Update the SMTP server and email addresses in the `$mailParams` section accordingly.
- Requires appropriate permissions to modify files and access the certificate store.
-If you're in an Active Directory domain and your company uses AD Certificate Services:
    Open certmgr.msc or certreq on the domain-joined machine.
    Request a new certificate for Code Signing from your internal CA.
    The certificate will automatically be trusted on all domain-joined machines.
#>


# Logging
$logpath = '\\Path\to\folder' 
$Outputfile = '{0}\{1:yyyy.MM.dd-hh.mm.ss}_Signed_Scripts.txt' -f $logpath, $(Get-Date) 
$starttime = Get-Date
write-output "**** Script Start $starttime ****" | Out-File $Outputfile -append

# Set Working Directory 
$scriptdir = "\\Path\to\scripts"
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
  Body = 'Attached is the log file showing the scripts that were signed.'
  Attachments = $Outputfile 
}                 
Send-MailMessage @mailParams



<#
@"
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣬⡛⣿⣿⣿⣯⢻
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⢻⣿⣿⢟⣻⣿⣿⣿⣿⣿⣿⣮⡻⣿⣿⣧
⣿⣿⣿⣿⣿⢻⣿⣿⣿⣿⣿⣿⣆⠻⡫⣢⠿⣿⣿⣿⣿⣿⣿⣿⣷⣜⢻⣿
⣿⣿⡏⣿⣿⣨⣝⠿⣿⣿⣿⣿⣿⢕⠸⣛⣩⣥⣄⣩⢝⣛⡿⠿⣿⣿⣆⢝
⣿⣿⢡⣸⣿⣏⣿⣿⣶⣯⣙⠫⢺⣿⣷⡈⣿⣿⣿⣿⡿⠿⢿⣟⣒⣋⣙⠊
⣿⡏⡿⣛⣍⢿⣮⣿⣿⣿⣿⣿⣿⣿⣶⣶⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⢱⣾⣿⣿⣿⣝⡮⡻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠛⣋⣻⣿⣿⣿
⢿⢸⣿⣿⣿⣿⣿⣿⣷⣽⣿⣿⣿⣿⣿⣿⣿⡕⣡⣴⣶⣿⣿⣿⡟⣿⣿⣿
⣦⡸⣿⣿⣿⣿⣿⣿⡛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿
⢛⠷⡹⣿⠋⣉⣠⣤⣶⣶⣿⣿⣿⣿⣿⣿⡿⠿⢿⣿⣿⣿⣿⣿⣷⢹⣿⣿
⣷⡝⣿⡞⣿⣿⣿⣿⣿⣿⣿⣿⡟⠋⠁⣠⣤⣤⣦⣽⣿⣿⣿⡿⠋⠘⣿⣿
⣿⣿⡹⣿⡼⣿⣿⣿⣿⣿⣿⣿⣧⡰⣿⣿⣿⣿⣿⣹⡿⠟⠉⡀⠄⠄⢿⣿
⣿⣿⣿⣽⣿⣼⣛⠿⠿⣿⣿⣿⣿⣿⣯⣿⠿⢟⣻⡽⢚⣤⡞⠄⠄⠄⢸⣿
"@#>