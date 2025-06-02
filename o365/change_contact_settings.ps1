Get-Contact -Filter {Office -like '*China*'} | Export-Csv -Path C:\contactschina.csv

## Change company of users in csv

$csvPath = 'C:\contactsChina.csv'
$contacts = Import-Csv -Path $csvPath

foreach ($contact in $contacts) {
    $displayName = $contact.DisplayName
    $company = 'Coilcraft - China'  # Replace with the new company information

    # Update company information
    Set-Contact -Identity $displayName -Company $company
}
