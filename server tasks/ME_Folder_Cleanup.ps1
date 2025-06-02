<#
.SYNOPSIS
    Automates the cleanup of Mail Enable log files older than 3 months.

.DESCRIPTION
    This PowerShell script is designed to delete Mail Enable log files that are older than 3 months 
    from specified directories. After the cleanup process, the script sends an email notification 
    indicating whether the operation was successful or encountered errors. 

    The script performs the following tasks:
    - Iterates through defined log directories.
    - Identifies and deletes files older than 3 months based on the LastWriteTime property.
    - Logs the results of the cleanup (successful deletions and errors).
    - Sends an email notification to administrators with details of the cleanup operation.

.NOTES
    Requirements:
    - PowerShell with access to the specified Mail Enable log directories.
    - SMTP server configured for sending email notifications.
#>

# Define parameters
$folders = @(
    "C:\Program Files (x86)\Mail Enable\Logging\IMAP",
    "C:\Program Files (x86)\Mail Enable\Logging\POP",
    "C:\Program Files (x86)\Mail Enable\Logging\SMTP"
    "C:\Program Files (x86)\Mail Enable\Logging\LS"
    "C:\Program Files (x86)\Mail Enable\Logging\MTA"
    "C:\Program Files (x86)\Mail Enable\Logging\SF"
)
$cutoffDate = (Get-Date).AddMonths(-3)
$smtpServer = "smtp.company.com"
$fromEmail = "no-reply@company.com"
$toEmail = "pc_admins@company.com"
$subjectSuccess = "Mail Enable Log Cleanup Successful"
$subjectFailure = "Mail Enable Log Cleanup Failed"

# Initialize variables
$log = @()
$success = $true

foreach ($folderPath in $folders) {
    try {
        # Get files older than the cutoff date
        $filesToDelete = Get-ChildItem -Path $folderPath -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }

        if ($filesToDelete) {
            foreach ($file in $filesToDelete) {
                # Attempt to delete each file
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $log += "Deleted: $($file.FullName)"
            }
        } else {
            $log += "No files older than 3 months found in $folderPath."
        }
    } catch {
        $success = $false
        # Capture error message
        $log += "Failed to clean $folderPath - Error: $($_.Exception.Message)"
    }
}

# Construct email body
$body = if ($success) {
    "Log cleanup completed successfully.`n`n" + ($log -join "`n")
} else {
    "Log cleanup encountered errors:`n`n" + ($log -join "`n")
}

# Set email subject
$subject = if ($success) { $subjectSuccess } else { $subjectFailure }

# Send email notification
Send-MailMessage -From $fromEmail -To $toEmail -Subject $subject -Body $body -SmtpServer $smtpServer

