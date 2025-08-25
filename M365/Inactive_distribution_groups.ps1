# Find-InactiveDLs90Days.ps1
# Find distribution groups with no activity in the last 90 days using historical search

param(
    [string]$NotificationEmail
)

Connect-ExchangeOnline

$StartDate = (Get-Date).AddDays(-90)
$EndDate = Get-Date
$CSVFile = "c:\temp\InactiveDLs90Days.csv"

Write-Host "=== 90-Day Distribution List Activity Analysis ===" -ForegroundColor Cyan
Write-Host "Analysis period: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))"
Write-Host ""

# Get all distribution groups
Write-Host "Getting all distribution groups..." -ForegroundColor Yellow
try {
    [array]$DLs = Get-DistributionGroup -ResultSize Unlimited
    if ($DLs.Count -eq 0) {
        Write-Host "No distribution groups found in the tenant" -ForegroundColor Red
        exit
    }
    Write-Host "Found $($DLs.Count) distribution groups" -ForegroundColor Green
} catch {
    Write-Host "Failed to retrieve distribution groups: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Check for existing completed historical searches
Write-Host "Checking for existing historical searches..." -ForegroundColor Yellow
try {
    $ExistingSearches = Get-HistoricalSearch | Where-Object {
        $_.Status -eq "Done" -and 
        $_.ReportType -eq "MessageTrace" -and
        (Get-Date $_.StartDate) -le $StartDate -and
        (Get-Date $_.EndDate) -ge $EndDate
    } | Sort-Object SubmitDate -Descending
} catch {
    Write-Host "Failed to check existing historical searches: $($_.Exception.Message)" -ForegroundColor Red
    $ExistingSearches = @()
}

if ($ExistingSearches) {
    Write-Host "Found $($ExistingSearches.Count) suitable completed historical searches" -ForegroundColor Green
    $LatestSearch = $ExistingSearches | Select-Object -First 1
    Write-Host "Using search: $($LatestSearch.ReportTitle) (JobId: $($LatestSearch.JobId))" -ForegroundColor Green
    Write-Host "Search covers: $($LatestSearch.StartDate) to $($LatestSearch.EndDate)"
    
    # Get the historical data
    Write-Host "Retrieving historical message trace data..." -ForegroundColor Yellow
    try {
        $HistoricalData = Get-HistoricalSearch -JobId $LatestSearch.JobId
        if (-not $HistoricalData -or $HistoricalData.Count -eq 0) {
            Write-Host "No data returned from historical search. The search may be empty." -ForegroundColor Yellow
            $HistoricalData = @()
        } else {
            Write-Host "Retrieved $($HistoricalData.Count) message trace records" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to retrieve historical search data: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "No suitable historical searches found. Starting new search..." -ForegroundColor Yellow
    
    # Get notification email
    if ([string]::IsNullOrWhiteSpace($NotificationEmail)) {
        $NotificationEmail = Read-Host "Enter your email address for notification when search completes"
    }
    
    if ([string]::IsNullOrWhiteSpace($NotificationEmail)) {
        Write-Host "Email address is required for historical search" -ForegroundColor Red
        exit
    }
    
    # Start historical search
    try {
        $SearchTitle = "DL_Activity_Analysis_$(Get-Date -Format 'yyyyMMdd_HHmm')"
        $HistoricalSearch = Start-HistoricalSearch -ReportTitle $SearchTitle `
            -StartDate $StartDate `
            -EndDate $EndDate `
            -ReportType MessageTrace `
            -NotifyAddress $NotificationEmail
        
        Write-Host "Historical search started successfully!" -ForegroundColor Green
        Write-Host "Job ID: $($HistoricalSearch.JobId)"
        Write-Host "Title: $SearchTitle"
        Write-Host ""
        Write-Host "This search may take several hours to complete." -ForegroundColor Yellow
        Write-Host "You will receive an email notification when it's ready." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To check status manually, run:" -ForegroundColor Cyan
        Write-Host "Get-HistoricalSearch -JobId '$($HistoricalSearch.JobId)'" -ForegroundColor White
        Write-Host ""
        Write-Host "Once complete, re-run this script and it will automatically use the completed search." -ForegroundColor Cyan
        
        # Show command to rerun
        Write-Host "Re-run command:" -ForegroundColor Cyan
        Write-Host ".\Find-InactiveDLs90Days.ps1" -ForegroundColor White
        
        exit
    } catch {
        Write-Host "Failed to start historical search: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
}

# Create hash table of DL SMTP addresses for quick lookup
Write-Host "Creating distribution list lookup table..." -ForegroundColor Yellow
$DLLookup = @{}
ForEach ($DL in $DLs) {
    $PrimaryAddress = [string]$DL.PrimarySMTPAddress
    if (-not [string]::IsNullOrWhiteSpace($PrimaryAddress)) {
        $DLLookup[$PrimaryAddress.ToLower()] = @{
            DisplayName = [string]$DL.DisplayName
            Alias = [string]$DL.Alias
        }
    }
}

Write-Host "Created lookup table for $($DLLookup.Count) distribution lists"

# Find messages sent to distribution lists
Write-Host "Analyzing message trace data for DL activity..." -ForegroundColor Yellow
$DLActivity = @{}
$ProcessedCount = 0
$DLMessageCount = 0

if ($HistoricalData.Count -gt 0) {
    # Get the first record to inspect property names
    $SampleRecord = $HistoricalData[0]
    Write-Host "Sample record properties:" -ForegroundColor Gray
    $SampleRecord.PSObject.Properties.Name | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    ForEach ($Message in $HistoricalData) {
        $ProcessedCount++
        if ($ProcessedCount % 10000 -eq 0) {
            Write-Host "Processed $ProcessedCount of $($HistoricalData.Count) messages... (Found $DLMessageCount DL messages)" -ForegroundColor Gray
        }
        
        # Handle different possible property names
        $RecipientAddress = $null
        if ($Message.PSObject.Properties['recipient_address']) {
            $RecipientAddress = $Message.recipient_address
        } elseif ($Message.PSObject.Properties['RecipientAddress']) {
            $RecipientAddress = $Message.RecipientAddress
        } elseif ($Message.PSObject.Properties['Recipient']) {
            $RecipientAddress = $Message.Recipient
        }
        
        if ([string]::IsNullOrWhiteSpace($RecipientAddress)) {
            continue
        }
        
        # Check if recipient is a distribution list (case-insensitive)
        $RecipientLower = $RecipientAddress.ToLower()
        if ($DLLookup.ContainsKey($RecipientLower)) {
            $DLMessageCount++
            
            # Handle different timestamp property names
            $MessageDate = $null
            if ($Message.PSObject.Properties['timestamp']) {
                $MessageDate = Get-Date $Message.timestamp
            } elseif ($Message.PSObject.Properties['Timestamp']) {
                $MessageDate = Get-Date $Message.Timestamp
            } elseif ($Message.PSObject.Properties['Received']) {
                $MessageDate = Get-Date $Message.Received
            } elseif ($Message.PSObject.Properties['DateTime']) {
                $MessageDate = Get-Date $Message.DateTime
            }
            
            if ($MessageDate) {
                # Handle different sender property names
                $SenderAddress = ""
                if ($Message.PSObject.Properties['sender_address']) {
                    $SenderAddress = $Message.sender_address
                } elseif ($Message.PSObject.Properties['SenderAddress']) {
                    $SenderAddress = $Message.SenderAddress
                } elseif ($Message.PSObject.Properties['Sender']) {
                    $SenderAddress = $Message.Sender
                }
                
                # Handle different subject property names
                $Subject = ""
                if ($Message.PSObject.Properties['subject']) {
                    $Subject = $Message.subject
                } elseif ($Message.PSObject.Properties['Subject']) {
                    $Subject = $Message.Subject
                }
                
                # Track the most recent message for this DL
                if (-not $DLActivity.ContainsKey($RecipientLower) -or $MessageDate -gt $DLActivity[$RecipientLower].LastMessage) {
                    $DLActivity[$RecipientLower] = @{
                        LastMessage = $MessageDate
                        LastSender = $SenderAddress
                        LastSubject = $Subject
                        MessageCount = if ($DLActivity.ContainsKey($RecipientLower)) { $DLActivity[$RecipientLower].MessageCount + 1 } else { 1 }
                    }
                } else {
                    $DLActivity[$RecipientLower].MessageCount++
                }
            }
        }
    }
}

Write-Host "Completed analysis - found $DLMessageCount messages to distribution lists" -ForegroundColor Green

# Generate the report
Write-Host "Generating final report..." -ForegroundColor Yellow
$Report = [System.Collections.Generic.List[Object]]::new()
$ActiveCount = 0
$InactiveCount = 0
$ProcessedDLs = 0

ForEach ($DL in $DLs) {
    $ProcessedDLs++
    if ($ProcessedDLs % 50 -eq 0) {
        Write-Host "Processed $ProcessedDLs of $($DLs.Count) distribution lists..." -ForegroundColor Gray
    }
    
    $DLAddress = [string]$DL.PrimarySMTPAddress
    $DLAddressLower = $DLAddress.ToLower()
    
    if ($DLActivity.ContainsKey($DLAddressLower)) {
        # DL has activity
        $Activity = $DLActivity[$DLAddressLower]
        $DaysAgo = (Get-Date) - $Activity.LastMessage
        
        $ReportLine = [PSCustomObject]@{
            DLName = $DL.DisplayName
            DLAddress = $DLAddress
            Status = "Active"
            LastMessageDate = $Activity.LastMessage.ToString('yyyy-MM-dd HH:mm:ss')
            DaysAgo = [math]::Round($DaysAgo.TotalDays, 1)
            MessageCount90Days = $Activity.MessageCount
            LastSender = $Activity.LastSender
            LastSubject = if ($Activity.LastSubject.Length -gt 100) { $Activity.LastSubject.Substring(0,100) + "..." } else { $Activity.LastSubject }
        }
        $ActiveCount++
    } else {
        # DL has no activity in 90 days
        $ReportLine = [PSCustomObject]@{
            DLName = $DL.DisplayName
            DLAddress = $DLAddress
            Status = "Inactive (90+ days)"
            LastMessageDate = "No messages in 90 days"
            DaysAgo = "90+"
            MessageCount90Days = 0
            LastSender = "N/A"
            LastSubject = "N/A"
        }
        $InactiveCount++
    }
    
    $Report.Add($ReportLine)
}

# Sort and export results
$Report = $Report | Sort-Object Status, DaysAgo
$Report | Export-CSV -NoTypeInformation $CSVFile -Encoding UTF8

# Display summary
Write-Host ""
Write-Host "=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
Write-Host ("Total distribution lists analyzed: {0}" -f $DLs.Count) -ForegroundColor White
Write-Host ("Active in last 90 days:           {0} ({1:P1})" -f $ActiveCount, ($ActiveCount/$DLs.Count)) -ForegroundColor Green
Write-Host ("Inactive for 90+ days:            {0} ({1:P1})" -f $InactiveCount, ($InactiveCount/$DLs.Count)) -ForegroundColor Red
Write-Host ""
Write-Host ("Report saved to: {0}" -f $CSVFile) -ForegroundColor Cyan
Write-Host ""

# Show inactive distribution lists
if ($InactiveCount -gt 0) {
    Write-Host "=== INACTIVE DISTRIBUTION LISTS (90+ days) ===" -ForegroundColor Red
    $InactiveDLs = $Report | Where-Object { $_.Status -eq "Inactive (90+ days)" }
    
    $InactiveDLs | Select-Object -First 20 | Format-Table DLName, DLAddress -AutoSize
    if ($InactiveDLs.Count -gt 20) {
        Write-Host "... and $($InactiveDLs.Count - 20) more inactive distribution lists" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Consider reviewing these distribution lists for potential removal or archiving." -ForegroundColor Yellow
}

Write-Host "Analysis parameters used:" -ForegroundColor Cyan
Write-Host "  Historical search period: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))"

Write-Host ""
Write-Host "Opening detailed report in GridView..." -ForegroundColor Yellow
$Report | Out-GridView -Title "Distribution List Activity Report (90 Days)"