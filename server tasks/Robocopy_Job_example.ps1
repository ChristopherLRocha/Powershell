# === CONFIGURATION ===
$source      = "\\path\to\source"
$destination = "\\path\to\destination"
$logPath     = "C:\logfile\name.txt"

# Email settings
$smtpServer = "smtp.company.com"
$from       = "robocopy_job@company.com"
$to         = "crocha@company.com"
$subject    = "Robocopy Completed - Initial Full Copy"
$body       = "The initial robocopy operation has completed. The log file is attached."

# === RUN ROBOCOPY ===
$robocopyArgs = @(
    "`"$source`"", "`"$destination`"",
    "/E",
    "/Z", "/COPY:DATS", "/B",
    "/R:3", "/W:5",
    "/TEE",
    "/LOG:$logPath",
    "/NFL", "/NDL"
)

Write-Host "Starting Robocopy..." -ForegroundColor Cyan
$robocopyResult = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru

# === EMAIL THE LOG ===
if (Test-Path $logPath) {
    try {
        Send-MailMessage -SmtpServer $smtpServer -From $from -To $to -Subject $subject -Body $body -Attachments $logPath
        Write-Host "Email sent successfully to $to." -ForegroundColor Green
    } catch {
        Write-Host "Failed to send email: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Robocopy log file not found. Skipping email." -ForegroundColor Yellow
}
