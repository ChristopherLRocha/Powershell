Get-Contact -Filter {Office -like '*Chicago*'} | Export-Csv -Path C:\contacts_chicago.csv

## Change company of users in csv

$csvPath = 'C:\contacts_chicago.csv'
$contacts = Import-Csv -Path $csvPath

foreach ($contact in $contacts) {
    $displayName = $contact.DisplayName
    $company = 'company - Chicago'  # Replace with the new company information

    # Update company information
    Set-Contact -Identity $displayName -Company $company
}
