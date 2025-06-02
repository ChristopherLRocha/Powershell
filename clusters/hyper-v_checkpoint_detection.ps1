<#
.SYNOPSIS
    Hyper-V Checkpoint Monitor with Parallel Execution

.DESCRIPTION
    This script checks a list of Hyper-V servers for any virtual machines (VMs) that have active checkpoints (snapshots).
    It performs these checks in parallel to significantly reduce total execution time — making it suitable for environments
    with many Hyper-V hosts.

    The script compiles the results, logs them to a rotating log file (automatically removing logs older than 7 days),
    and sends an email summary via a specified SMTP server. The email subject line will dynamically reflect whether any
    checkpoints or errors were found.

.NOTES
    • Requires PowerShell 7 or later due to use of ForEach-Object -Parallel.
    • Script logs are stored in a specified directory with one file per day.
    • SMTP settings and server list are configurable via variables at the top of the script.
    • Ideal for scheduled automation in medium to large Hyper-V environments.

#>

# ------------------------
# User-defined Variables
# ------------------------

# List of Hyper-V servers to check
$HyperVServers = @("HyperV01", "HyperV02", "HyperV03")  # Replace with actual server names

# Email settings
$SMTPServer   = "smtp.yourdomain.com"
$SMTPPort     = 587
$EmailFrom    = "hyperv-monitor@yourdomain.com"
$EmailTo      = "you@yourdomain.com"

# Optional: SMTP credentials
$SMTPUser = "smtpuser@yourdomain.com"
$SMTPPass = "YourSecurePassword" | ConvertTo-SecureString -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential($SMTPUser, $SMTPPass)

# Logging
$LogDirectory = "C:\Scripts\HyperVCheckpointLogs"
if (!(Test-Path $LogDirectory)) { New-Item -Path $LogDirectory -ItemType Directory | Out-Null }

# Remove logs older than 7 days
Get-ChildItem -Path $LogDirectory -Filter "CheckpointReport_*.log" | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddDays(-7)
} | Remove-Item -Force

$TodayLog = Join-Path $LogDirectory ("CheckpointReport_{0:yyyy-MM-dd}.log" -f (Get-Date))

# ------------------------
# Parallel VM Scan
# ------------------------

$CheckpointResults = $HyperVServers | ForEach-Object -Parallel {
    param($Today)

    try {
        $VMs = Get-VM -ComputerName $_ | Where-Object { $_.CheckpointCount -gt 0 }
        if ($VMs) {
            $VMs | ForEach-Object {
                "[$_] VM: $($_.Name) - Checkpoints: $($_.CheckpointCount)"
            }
        }
    } catch {
        "[$_] ERROR: $($_.Exception.Message)"
    }

} -ArgumentList (Get-Date)  # PowerShell 7+ required

$CheckpointResults = $CheckpointResults | Where-Object { $_ }  # Remove nulls

# ------------------------
# Compose Email & Log
# ------------------------

if ($CheckpointResults.Count -gt 0) {
    $EmailSubject = "⚠️ Hyper-V Checkpoints or Errors Detected"
    $EmailBody = "The following VMs have checkpoints or errors occurred during scan:`n`n" + ($CheckpointResults -join "`n")
} else {
    $EmailSubject = "✅ Hyper-V Checkpoint Report: None Found"
    $EmailBody = "No Hyper-V checkpoints were found on any of the specified servers."
}

# Log results
Add-Content -Path $TodayLog -Value ("`n[{0}] Report Start`n" -f (Get-Date)))
$CheckpointResults | ForEach-Object { Add-Content -Path $TodayLog -Value $_ }
Add-Content -Path $TodayLog -Value ("`n[{0}] Report End`n" -f (Get-Date)))

# ------------------------
# Send Email
# ------------------------

Send-MailMessage -From $EmailFrom -To $EmailTo -Subject $EmailSubject -Body $EmailBody `
    -SmtpServer $SMTPServer -Port $SMTPPort -Credential $Creds -UseSsl
