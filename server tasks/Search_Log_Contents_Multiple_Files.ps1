<#
.SYNOPSIS
Searches MailEnable SMTP log files for a specific email address.

.DESCRIPTION
This script scans all `.log` files in the MailEnable SMTP log directory for a specified email address or keyword. 
If the search term is found in any file, the script outputs the name of the file where it was detected.

.PARAMETER $logDirectory
The path to the MailEnable SMTP log files.

.PARAMETER $searchWord
The email address or string to search for within the log files.

.NOTES
Modify the $searchWord variable to search for a different string or email address.

#>

# Define the directory containing the log files
$logDirectory = "C:\Program Files (x86)\Mail Enable\Logging\SMTP"

# Define the word to search for
$searchWord = "example@company.com"

# Get all log files in the directory
$logFiles = Get-ChildItem -Path $logDirectory -Filter *.log

# Loop through each log file and search for the word
foreach ($logFile in $logFiles) {
    $content = Get-Content -Path $logFile.FullName
    if ($content -match $searchWord) {
        Write-Output "The word '$searchWord' was found in file: $($logFile.Name)"
    }
}