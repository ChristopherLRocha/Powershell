##Log into https://compliance.microsoft.com/

##Under Solutions on the left-hand navigation menu, go to Content Search

##Create a new search, specify to search in All Exchange mailboxes (or specific users), enter your search criteria (address the bad email was sent from, keywords in the subject of the bad email, date range, etc.)

##Save & Run the search (give it an appropriate name such as "bad email purge"), preview results to make sure it returns the emails you want to purge

##Fire up Windows Powershell (see here if you haven’t installed the Exchange Online component before: https://docs.microsoft.com/en-us/powershell/exchange/office-365-scc/connect-to-scc-powershell/mfa-connect-to-scc-powershell?view=exchange-ps )

##Run the command and sign in as an account with global/exchange online admin rights:

Connect-IPPSSession

##Run the command: 

New-ComplianceSearchAction -SearchName "(search name from step 4)" -Purge -PurgeType HardDelete

##The emails are removed from the specified mailboxes permanently

##check the status of the purge
 Get-ComplianceSearchAction -identity “(search name)_purge”