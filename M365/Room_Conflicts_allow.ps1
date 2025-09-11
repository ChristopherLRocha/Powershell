<#
.SYNOPSIS
    Updates calendar processing settings for all room mailboxes in Exchange Online.

.DESCRIPTION
    This script connects to Exchange Online, retrieves all room mailboxes, 
    and applies updated conflict handling rules. 
    By default, if any instance of a recurring meeting conflicts, the whole series is rejected.
    This script changes the behavior so that:
        - Up to 20% of conflicting instances are allowed.
        - A maximum of 3 conflicts are tolerated.
        - Organizers’ names are added to the subject line of bookings.
        - Comments and subjects are preserved in responses to make declines clearer.

.NOTES
    Date:   2025-09-11
    Requirements:
        - Exchange Online PowerShell Module
        - Appropriate permissions (Organization Management or similar)
#>

# Connect to Exchange Online
Connect-ExchangeOnline

# Get all room mailboxes
$rooms = Get-Mailbox -RecipientTypeDetails RoomMailbox

# Loop through each room and set conflict policy
foreach ($room in $rooms) {
    Write-Host "Updating $($room.DisplayName)..."
    Set-CalendarProcessing -Identity $room.Identity `
        -ConflictPercentageAllowed 20 `
        -MaximumConflictInstances 3 `
        -AddOrganizerToSubject $true `
        -DeleteComments $
