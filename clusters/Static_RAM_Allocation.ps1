# Define the name of the remote cluster
$ClusterName = "clustername"

# Get all VM resources from the cluster
$VMResources = Get-ClusterResource -Cluster $ClusterName | Where-Object { $_.ResourceType -eq "Virtual Machine" }

# Array to hold VM memory info
$StaticVMInfo = @()

foreach ($VMResource in $VMResources) {
    # Get the actual VM name from the resource's private properties
    $VMConfigName = (Get-ClusterParameter -InputObject $VMResource | Where-Object { $_.Name -eq "VmId" }).Value

    if ($VMConfigName) {
        # Use the VM ID to get the VM object
        $VM = Get-VM -ComputerName $ClusterName | Where-Object { $_.Id.Guid -eq $VMConfigName }

        if ($VM -and -not $VM.DynamicMemoryEnabled) {
            $StaticVMInfo += [PSCustomObject]@{
                VMName         = $VM.Name
                StaticMemoryMB = $VM.MemoryStartup / 1MB
            }
        }
    }
}

# Display the results in a table
$StaticVMInfo | Format-Table -AutoSize

# Calculate and display total static memory in GB
$TotalMemoryGB = ($StaticVMInfo | Measure-Object -Property StaticMemoryMB -Sum).Sum / 1024
Write-Host "`nTotal Static Memory Allocated: $([math]::Round($TotalMemoryGB, 2)) GB"
