# PowerShell script to shut down all VMs on a Hyper-V host
# Run this script as administrator on the Hyper-V host
# Used with our CyberPower UPS

# Import the Hyper-V module (if not already loaded)
Import-Module Hyper-V -ErrorAction Stop

# Get all running VMs on the Hyper-V host
$runningVMs = Get-VM | Where-Object { $_.State -eq 'Running' }

# Loop through each running VM and shut it down
foreach ($vm in $runningVMs) {
    Write-Output "Shutting down VM: $($vm.Name)"
    Stop-VM -Name $vm.Name -Force
}

# Wait for all VMs to stop before completing the script
$runningVMs | ForEach-Object {
    $vmName = $_.Name
    while ((Get-VM -Name $vmName).State -eq 'Running') {
        Start-Sleep -Seconds 5
    }
    Write-Output "VM $vmName has been shut down."
}

Write-Output "All VMs have been successfully shut down."