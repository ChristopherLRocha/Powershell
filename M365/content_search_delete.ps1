
# Ensure the Exchange Online Management module is installed
#if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
#    Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
#}

# Import the module
#Import-Module ExchangeOnlineManagement

# Check if running in a GUI-capable environment
# $guiCapable = $Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows PowerShell ISE Host'

# Use appropriate connection method
#if ($guiCapable) {
    # Write-Host "Using standard authentication (GUI popup)..."
    Connect-IPPSSession
#} else {
#    Write-Host "Using device code authentication (no popup)..."
#    Connect-IPPSSession -UseDeviceAuthentication
#}

# Define the subject to search for
$subject = "RE: JLR cyberattack uninsured"

# Create a Compliance Search
$searchName = "JLR cyberattack uninsured test"
New-ComplianceSearch -Name $searchName -ExchangeLocation all -ContentMatchQuery "subject:`"$subject`""

# Start the Compliance Search
Start-ComplianceSearch -Identity $searchName

# Wait for the search to complete
do {
    $status = (Get-ComplianceSearch -Identity $searchName).Status
    Start-Sleep -Seconds 10
} while ($status -ne "Completed")

# Check results
New-ComplianceSearchAction -SearchName $searchName -Preview

Get-ComplianceSearchAction -SearchName $searchName



Get-ComplianceSearch -Identity $searchName | Format-List Name,Status,ItemsFound


# Purge the messages found by the search
New-ComplianceSearchAction -SearchName $searchName -Purge -PurgeType SoftDelete

# Verify the action
Get-ComplianceSearchAction -SearchName $searchName