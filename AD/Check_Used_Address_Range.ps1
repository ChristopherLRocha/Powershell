<#
.SYNOPSIS
    Checks for assigned IPs in a specific DHCP scope used for computer deployments.

.DESCRIPTION
    This script automatically discovers the nearest Active Directory domain controller and queries its DHCP server 
    for leases in the 172.16.0.0 scope that match the ".127." IP pattern. This IP range is designated for computers 
    currently undergoing deployment. If any such addresses are found, the script emails a report to the PC department 
    listing the active leases. If no matching IPs are found, a simple notification is sent.

    The script is used internally to track deployment activity and reclaim unused IPs if necessary.

.NOTES
    Purpose: Monitor and report on IP usage within the deployment address range.
    Dependencies: ActiveDirectory module, DHCP tools, SMTP access

#>


#------------Variables-----------------

$domain_controller = (Get-ADDomainController -Discover -NextClosestSite).HostName

#--------------------------------------

Invoke-Command -ComputerName $domain_controller -ScriptBlock {

    param($dc)

    $ipresult = Get-DhcpServerv4Lease -ComputerName $dc -ScopeId 172.16.0.0 |
        Where-Object { $_.IPAddress -like '*.127.*' } |
        Format-Table IPAddress, HostName, AddressState, LeaseExpiryTime -AutoSize |
        Out-String

    if (-not $ipresult.Trim()) {
        Send-MailMessage -SmtpServer smtp.company.com `
            -To admin@company.com `
            -From no_reply@company.com `
            -Subject '.127 IP Address Report' `
            -Body 'There are no .127 addresses in use'
    }
    else {
        $body = @"
This is a list of the .127 addresses in use. Please let the admin know if the address(es) are no longer needed.

$ipresult
"@
        Send-MailMessage -SmtpServer smtp.company.com `
            -To pc_department@company.com `
            -From no_reply@company.com `
            -Subject '.127 IP Address Report' `
            -Body $body
    }

} -ArgumentList $domain_controller
