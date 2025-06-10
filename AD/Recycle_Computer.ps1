<#
.SYNOPSIS
    Multi-step cleanup script for Active Directory, DHCP, and DNS.

.DESCRIPTION
    This script allows you to select a location/domain controller and then perform one or more of the following cleanups:
    - Search and optionally delete computers from Active Directory (with protection for critical machines)
    - Search for DHCP reservations by IP address, and optionally delete the reservation and lease
    - Search and optionally delete DNS A records associated with a computer name

    The script guides the user through each step, allowing skipping sections, and provides a final summary of all actions taken.
    The entire process can be repeated multiple times until the user chooses to exit.

.NOTES
    Requires ActiveDirectory, DhcpServer, and DnsServer PowerShell modules.
    Run with appropriate permissions to manage AD, DHCP, and DNS.

.EXAMPLE
    Run the script, select location, choose cleanup sections, and follow prompts to delete or skip items.

#>

Import-Module ActiveDirectory
Import-Module DhcpServer
Import-Module DnsServer

do {
    Clear-Host
    Write-Host '----------PC Recycle Script----------'

    # Final Summary Log
    $Summary = @()
    $valid = $false

    # Step 0: Select Location (Domain Controller)
    do {
        $location = Read-Host -Prompt 'Which location (location1, location2, location3)? Type "exit" to cancel'

        switch ($location) {
            'location1'     { $ADServ = 'DC01'; $valid = $true }
            'location2'     { $ADServ = 'DC02'; $valid = $true }
            'location3'     { $ADServ = 'DC03'; $valid = $true }
            'exit' {
                Write-Host "Exiting script."
                exit
            }
            default {
                Write-Warning "Not a valid location. Please try again or type 'exit' to cancel."
                $valid = $false
            }
        }
    } until ($valid)

    # Ask user which cleanup sections to run
    Write-Host "`nSelect which cleanup sections to run. Type Y or N for each."

    $runAD = Read-Host "Run Active Directory computer cleanup? (Y/N)"
    $runDHCP = Read-Host "Run DHCP reservation cleanup? (Y/N)"
    $runDNS = Read-Host "Run DNS A record cleanup? (Y/N)"

    # --- Step 1: AD Computer Lookup & Deletion ---
    if ($runAD -match '^(Y|y)$') {
        # Define protected computers (exact names)
        $protectedComputers = @(
            'DC01',
            'DC02',
            'DC03',
            'DB01',
            'WS01',
            'FS01'  # Add all PCs you want to protect here
        )

        do {
            $pc_name = Read-Host "Enter the computer name"

            $pc = Get-ADComputer -Server $ADServ -Filter "Name -like '*$pc_name*'" -Properties * |
                  Select-Object Name, DistinguishedName, DNSHostName, OperatingSystem, LastLogonDate

            if ($pc) {
                Write-Host "`nComputer(s) found:`n" -ForegroundColor Green
                $pc | Format-Table Name, DNSHostName, OperatingSystem, LastLogonDate -AutoSize

                foreach ($computer in $pc) {
                    if ($protectedComputers -contains $computer.Name) {
                        Write-Warning "The computer '$($computer.Name)' is protected and cannot be deleted."
                        $Summary += "Attempted to delete protected computer '$($computer.Name)' - Skipped"
                        continue
                    }

                    $delete = Read-Host "`nDo you want to delete '$($computer.Name)' from Active Directory? (Y/N)"
                    if ($delete -match '^(Y|y)$') {
                        try {
                            Remove-ADComputer -Server $ADServ -Identity $computer.DistinguishedName -Confirm:$false
                            Write-Host "Computer '$($computer.Name)' deleted successfully." -ForegroundColor Yellow
                            $Summary += "AD computer '$($computer.Name)' deleted"
                        } catch {
                            Write-Host "Error deleting '$($computer.Name)': $_" -ForegroundColor Red
                            $Summary += "Failed to delete AD computer '$($computer.Name)': $_"
                        }
                    } else {
                        Write-Host "Skipped deletion of '$($computer.Name)'." -ForegroundColor Cyan
                        $Summary += "Skipped deletion of AD computer '$($computer.Name)'"
                    }
                }
            } else {
                Write-Host "`nNo computer found with the name '$pc_name'." -ForegroundColor Red
                $Summary += "No AD computer found with name '$pc_name'"
            }

            $retry = Read-Host "`nDo you want to search for another PC? (Y/N)"
        } while ($retry -match '^(Y|y)$')
    } else {
        Write-Host "`nSkipping Active Directory computer cleanup." -ForegroundColor Gray
    }

    # --- Step 2: DHCP Reservation and Lease Deletion ---
    if ($runDHCP -match '^(Y|y)$') {
        Write-Host "`n--- DHCP Reservation Cleanup ---" -ForegroundColor Cyan
        $ipAddress = Read-Host "Enter the IP address you want to check"

        try {
            $scopes = Get-DhcpServerv4Scope -ComputerName $ADServ
            $reservationFound = $false

            foreach ($scope in $scopes) {
                $reservation = Get-DhcpServerv4Reservation -ComputerName $ADServ -ScopeId $scope.ScopeId |
                               Where-Object { $_.IPAddress -eq $ipAddress }

                if ($reservation) {
                    $reservationFound = $true
                    Write-Host "`nReservation found in scope $($scope.ScopeId):" -ForegroundColor Green
                    $reservation | Format-List IPAddress, ClientId, Name, Description

                    $remove = Read-Host "`nDo you want to remove this reservation and its lease? (Y/N)"
                    if ($remove -match '^(Y|y)$') {
                        Remove-DhcpServerv4Reservation -ComputerName $ADServ -ScopeId $scope.ScopeId -ClientId $reservation.ClientId -Confirm:$false
                        Remove-DhcpServerv4Lease -ComputerName $ADServ -ScopeId $scope.ScopeId -IPAddress $ipAddress -Confirm:$false

                        Write-Host "Reservation and lease at IP $ipAddress deleted successfully." -ForegroundColor Yellow
                        $Summary += "DHCP reservation and lease for IP $ipAddress deleted"
                    } else {
                        Write-Host "Skipped deletion." -ForegroundColor Cyan
                        $Summary += "⏭Skipped DHCP reservation and lease for IP $ipAddress"
                    }
                    break
                }
            }

            if (-not $reservationFound) {
                Write-Host "`nNo reservation found for IP $ipAddress." -ForegroundColor Red
                $Summary += "No DHCP reservation found for IP $ipAddress"
            }
        } catch {
            Write-Host "Error while processing DHCP reservation: $_" -ForegroundColor Red
            $Summary += "Error during DHCP cleanup: $_"
        }
    } else {
        Write-Host "`nSkipping DHCP reservation cleanup." -ForegroundColor Gray
    }

    # --- Step 3: DNS A Record Cleanup ---
    if ($runDNS -match '^(Y|y)$') {
        Write-Host "`n--- DNS A Record Cleanup ---" -ForegroundColor Cyan

        try {
            $dnsZone = (Get-ADDomain).DNSRoot

            $dnsRecords = Get-DnsServerResourceRecord -ComputerName $ADServ -ZoneName $dnsZone -Name $pc_name |
                          Where-Object { $_.RecordType -eq "A" }

            if ($dnsRecords) {
                Write-Host "`nDNS A record(s) found for '$pc_name':" -ForegroundColor Green
                $dnsRecords | Format-Table HostName, RecordType, RecordData, TimeToLive -AutoSize

                $deleteDNS = Read-Host "`nDo you want to delete these DNS A record(s)? (Y/N)"
                if ($deleteDNS -match '^(Y|y)$') {
                    foreach ($record in $dnsRecords) {
                        Remove-DnsServerResourceRecord -ComputerName $ADServ -ZoneName $dnsZone `
                            -RRType "A" -Name $pc_name -RecordData $record.RecordData.IPv4Address -Confirm:$false

                        Write-Host "Deleted A record for $pc_name -> $($record.RecordData.IPv4Address)" -ForegroundColor Yellow
                        $Summary += "DNS A record for $pc_name -> $($record.RecordData.IPv4Address) deleted"
                    }
                } else {
                    Write-Host "Skipped DNS A record deletion." -ForegroundColor Cyan
                    $Summary += "Skipped DNS A record deletion for $pc_name"
                }
            } else {
                Write-Host "No DNS A records found for '$pc_name' in zone '$dnsZone'." -ForegroundColor Red
                $Summary += "No DNS A records found for $pc_name in $dnsZone"
            }
        } catch {
            Write-Host "Error during DNS record processing: $_" -ForegroundColor Red
            $Summary += "Error during DNS cleanup: $_"
        }
    } else {
        Write-Host "`nSkipping DNS A record cleanup." -ForegroundColor Gray
    }

    # --- Step 4: Final Summary Output ---
    Write-Host "`n--- Cleanup Summary ---" -ForegroundColor White
    $Summary | ForEach-Object { Write-Host $_ }
    
    $repeatAnswer = Read-Host "`nDo you want to run the cleanup again? (Y/N)"
    if ($repeatAnswer -match '^(Y|y)$') {
        $repeat = $true
    } else {
        $repeat = $false
        Write-Host "Exiting script. Goodbye!" -ForegroundColor Cyan
    }

} while ($repeat)
