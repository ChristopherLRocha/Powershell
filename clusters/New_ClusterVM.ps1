
# Variables

$ClusterName     = "cluster01"
$VMName          = "testvm01"
$TargetNode      = "node1"
$VMSwitch        = "10G LAN 1 Virtual Switch"
$CSVVolume       = "C:\ClusterStorage\Volume1"
$CSVPath         = "$CSVVolume\$VMName"
$VHDXPath        = "$CSVPath\$VMName.vhdx"
$MemoryStartup   = 8GB
$CPUCount        = 2
$VHDXSize        = 127GB
$PreferredOwners = @("node1", "node2", "node3")


# Create VM on remote cluster node
Invoke-Command -ComputerName $TargetNode -ScriptBlock {
    param (
        $VMName, $CSVPath, $VHDXPath, $MemoryStartup, $CPUCount, $VHDXSize, $VMSwitch
    )

    # Ensure target path exists
    if (-not (Test-Path -Path $CSVPath)) {
        New-Item -Path $CSVPath -ItemType Directory | Out-Null
    }

    # Create the VM
    New-VM -Name $VMName `
           -Generation 2 `
           -MemoryStartupBytes $MemoryStartup `
           -NewVHDPath $VHDXPath `
           -NewVHDSizeBytes $VHDXSize `
           -Path $CSVPath `
           -SwitchName $VMSwitch

    # Set the number of virtual processors
    Set-VMProcessor -VMName $VMName -Count $CPUCount

} -ArgumentList $VMName, $CSVPath, $VHDXPath, $MemoryStartup, $CPUCount, $VHDXSize, $VMSwitch

# Add VM to the cluster (make it highly available)
Add-ClusterVirtualMachineRole -Cluster $ClusterName -VirtualMachine $VMName

# Set preferred cluster owners (optional)
Get-ClusterGroup -Cluster $ClusterName -Name $VMName | Set-ClusterOwnerNode -Owners $PreferredOwners

# Output status
Write-Host "`nVM '$VMName' has been created and added to the cluster '$ClusterName'."
Write-Host "Preferred owners set to: $($PreferredOwners -join ', ')"
