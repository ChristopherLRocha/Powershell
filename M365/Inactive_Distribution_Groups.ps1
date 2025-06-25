<#
.SYNOPSIS
    Tracks distribution group activity over time using Get-MessageTrace (10-day max),
    logs activity to a CSV, and reports groups with no activity in 90+ days.

.NOTES
    - Run this script daily/weekly
    - Keeps a cumulative activity log in CSV
#>

# CONFIGURATION
$LogPath = "C:\path\to\log.csv"
$InactiveDays = 90
$CutoffDate = (Get-Date).AddDays(-$InactiveDays)
$CheckWindowStart = (Get-Date).AddDays(-10)  # Max lookback for Get-MessageTrace

# Email config
$smtpServer = "smtp.company.com"
$smtpFrom = "noreply@company.com"
$smtpTo = "pc_admins@company.com"
$smtpSubject = "Inactive Distribution Groups (Past $InactiveDays Days)"

# Connect to Exchange Online
$AppId = "your_app_ID"
$CertificateThumbprint = "your_certificate_thumbprint"
$Organization = "tenant.onmicrosoft.com"

try {
    Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
    Write-Host "Connected to Exchange Online using certificate-based app auth." -ForegroundColor Green
} catch {
    Write-Error "Exchange Online connection failed: $_"
    exit 1
}



# Load previous activity log
if (Test-Path $LogPath) {
    $activityLog = Import-Csv $LogPath
} else {
    $activityLog = @()
}

# Get distribution groups
$groups = Get-DistributionGroup -ResultSize Unlimited
Write-Host "Retrieved $($groups.Count) distribution groups from Exchange." -ForegroundColor Cyan

# Track newly active groups
$seenToday = @()
foreach ($group in $groups) {
    Write-Host "Checking $($group.DisplayName)..."
    $traces = Get-MessageTrace -StartDate $CheckWindowStart -EndDate (Get-Date) -RecipientAddress $group.PrimarySmtpAddress -PageSize 1

    if ($traces.Count -gt 0) {
        $seenToday += [PSCustomObject]@{
            GroupName    = $group.DisplayName
            EmailAddress = $group.PrimarySmtpAddress
            LastSeen     = (Get-Date).ToString("yyyy-MM-dd")
        }
    }
}
Write-Host "$($seenToday.Count) group(s) were active in the last 10 days." -ForegroundColor Green

# Get list of current group email addresses (canonical casing)
$currentGroupEmails = $groups.PrimarySmtpAddress | ForEach-Object { $_.ToLower() }

# Get lowercase list of existing logged emails - FIXED with null check
$existingLoggedEmails = @()
if ($activityLog.Count -gt 0) {
    $existingLoggedEmails = $activityLog | ForEach-Object { $_.EmailAddress.ToLower() }
}

# Groups not seen today AND not already in the CSV
$placeholderGroups = $groups | Where-Object {
    ($seenToday.EmailAddress -notcontains $_.PrimarySmtpAddress) -and
    ($existingLoggedEmails -notcontains $_.PrimarySmtpAddress.ToLower())
} | ForEach-Object {
    [PSCustomObject]@{
        GroupName    = $_.DisplayName
        EmailAddress = $_.PrimarySmtpAddress
        LastSeen     = (Get-Date).ToString("yyyy-MM-dd")  # placeholder
    }
}

Write-Host "Added $($placeholderGroups.Count) placeholder group entries (no trace history yet)." -ForegroundColor Yellow

# Final merge: update log with today's seen groups + placeholders
$updatedLog = (@($activityLog | Where-Object {
    $_.EmailAddress.ToLower() -in $currentGroupEmails -and
    ($seenToday.EmailAddress -notcontains $_.EmailAddress)
}) + $seenToday + $placeholderGroups)

# Save updated log
$updatedLog | Sort-Object EmailAddress, LastSeen | Export-Csv -Path $LogPath -NoTypeInformation
Write-Host "Activity log updated and saved to $LogPath" -ForegroundColor Cyan

# Identify inactive groups (not seen in past N days)
$inactiveGroups = $groups | Where-Object {
    $email = $_.PrimarySmtpAddress.ToLower()
    $lastSeen = ($updatedLog | Where-Object { $_.EmailAddress -eq $email } | Sort-Object LastSeen -Descending | Select-Object -First 1).LastSeen
    if ($lastSeen) {
        [datetime]$lastSeenDate = [datetime]::Parse($lastSeen)
        return $lastSeenDate -lt $CutoffDate
    } else {
        return $true
    }
} | ForEach-Object {
    [PSCustomObject]@{
        GroupName    = $_.DisplayName
        EmailAddress = $_.PrimarySmtpAddress
        LastSeen     = ($updatedLog | Where-Object { $_.EmailAddress -eq $_.PrimarySmtpAddress } | Sort-Object LastSeen -Descending | Select-Object -First 1).LastSeen
    }
}

Write-Host "$($inactiveGroups.Count) group(s) flagged as inactive (no activity in $InactiveDays+ days)." -ForegroundColor Magenta

Disconnect-ExchangeOnline -Confirm:$false

# Prepare email body
if ($inactiveGroups.Count -gt 0) {
    $htmlBody = $inactiveGroups | ConvertTo-Html -Property GroupName, EmailAddress, LastSeen `
        -Title "Inactive Distribution Groups" `
        -PreContent "<h2>Inactive Distribution Groups (No activity in past $InactiveDays days)</h2>" `
        -PostContent "<br><i>Generated on $(Get-Date)</i>" | Out-String
} else {
    $htmlBody = @"
        <html>
        <body>
            <h2>Inactive Distribution Groups (No activity in past $InactiveDays days)</h2>
            <p><b>Good news!</b> No inactive distribution groups were found during this reporting period.</p>
            <br><i>Generated on $(Get-Date)</i>
        </body>
        </html>
"@
}

Send-MailMessage -From $smtpFrom -To $smtpTo -Subject $smtpSubject -Body $htmlBody `
    -BodyAsHtml:$true -SmtpServer $smtpServer

Write-Host "Email report sent." -ForegroundColor Green
