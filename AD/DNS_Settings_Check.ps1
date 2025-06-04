<#
.SYNOPSIS
    Scans a specified IP address range to collect DNS server settings from accessible Windows computers.

.DESCRIPTION
    This script loops through an IP range and attempts to connect to each IP using WMI.
    If successful, it retrieves the DNS server settings from enabled network adapters.
    The results are exported to a specified CSV file for reporting or auditing purposes.

.REQUIREMENTS
    - Administrative rights on remote machines.
    - Remote WMI access enabled (or WinRM if modified).
    - Target computers must be online and allow remote queries.
    
.PARAMETERS
    $startIP      - Starting IP address of the scan range.
    $endIP        - Ending IP address of the scan range.
    $outputFile   - Full path where the CSV report will be saved.

.OUTPUT
    A CSV file containing each computer's IP and its DNS server configuration.
#>


# Define the IP range
$startIP = [System.Net.IPAddress]::Parse("192.168.64.2")
$endIP = [System.Net.IPAddress]::Parse("192.168.64.254")

# Output file
$outputFile = "c:\DNS_Server_Settings.csv"

# Convert IP to Int for iteration
function ConvertTo-Int {
    param ($ip)
    $bytes = $ip.GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function ConvertTo-IP {
    param ($int)
    $bytes = [BitConverter]::GetBytes($int)
    [Array]::Reverse($bytes)
    return [System.Net.IPAddress]::new($bytes)
}

# Prepare the output list
$dnsResults = @()

# Loop through the IPs
$startInt = ConvertTo-Int $startIP
$endInt = ConvertTo-Int $endIP

for ($i = $startInt; $i -le $endInt; $i++) {
    $currentIP = ConvertTo-IP $i

    Write-Host "Checking $currentIP..." -ForegroundColor Cyan

    try {
        $dnsInfo = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $currentIP.IPAddressToString -Filter "IPEnabled = True" -ErrorAction Stop
        foreach ($adapter in $dnsInfo) {
            $dnsServers = ($adapter.DNSServerSearchOrder -join ", ")
            $dnsResults += [PSCustomObject]@{
                ComputerName = $currentIP.IPAddressToString
                DNS_Servers  = $dnsServers
            }
        }
    } catch {
        Write-Warning "Could not retrieve DNS info from $currentIP"
    }
}

# Export to CSV
$dnsResults | Export-Csv -Path $outputFile -NoTypeInformation
Write-Host "Done. Results saved to $outputFile" -ForegroundColor Green
