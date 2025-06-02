<#
.SYNOPSIS
    Commands used for setting up the network on nodes within a cluster.

.DESCRIPTION
    This PowerShell script automates the configuration of networking on cluster nodes by creating 
    virtual switches, setting up network teaming, disabling unnecessary protocols, and configuring 
    VLANs and backup networks for virtual machines (VMs). Additionally, it enables Cluster-Aware 
    Updating (CAU) for automated patching across clustered environments.

    The script performs the following tasks:
    - Creates a virtual teamed switch for 10G LAN networking using multiple physical NICs (LAN 1 and LAN 2).
    - Configures dynamic load balancing for the virtual switch.
    - Creates a virtual switch dedicated to VLAN networking for VM traffic.
    - Configures a backup virtual switch for redundant networking.
    - Disables RDMA and IPv6 on all network adapters to reduce unnecessary protocol overhead.
    - Sets up Cluster-Aware Updating (CAU) to automate patch management across the cluster.

.NOTES
    Requirements:
    - PowerShell run as Administrator.
    - PowerShell Hyper-V module installed on each node.
    - Appropriate permissions to configure networking and Cluster-Aware Updating.

#>


# Define network adapter names
$LANAdapters = @("LAN 1", "LAN 2")
$VLANAdapter = "VLAN"
$BackupAdapter = "Backup"

# Create virtual teamed switch
Write-Host "Creating 10G LAN Virtual Switch..." -ForegroundColor Green
New-VMSwitch -Name "10G LAN 1 Virtual Switch" -NetAdapterName $LANAdapters -EnableEmbeddedTeaming $true -AllowManagementOS $false -Verbose

# Set load balancing to dynamic
Write-Host "Setting load balancing to dynamic..." -ForegroundColor Green
Set-VMSwitchTeam -Name "10G LAN 1 Virtual Switch" -LoadBalancingAlgorithm HyperVPort -Verbose

# Check virtual switches
Write-Host "Checking virtual switches..." -ForegroundColor Green
Get-VMSwitchTeam

# Remove backup virtual switch if it exists
Write-Host "Removing Backup Virtual Switch..." -ForegroundColor Green
if (Get-VMSwitch "Backup Virtual Switch") {
    Remove-VMSwitch "Backup Virtual Switch" -Force
}

# Disable RDMA on all NICs
Write-Host "Disabling RDMA on all network adapters..." -ForegroundColor Green
disable-NetAdapterRdma -Name "*" -Verbose
Get-NetAdapterRdma

# Disable IPV6 on all network adapters
Write-Host "Disabling IPv6 on all network adapters..." -ForegroundColor Green
Get-NetAdapter | ForEach-Object { Disable-NetAdapterBinding -InterfaceAlias $_.Name -ComponentID ms_tcpip6 }

# Verify IPv6 is disabled
Write-Host "Verifying IPv6 is disabled..." -ForegroundColor Green
Get-NetAdapter | ForEach-Object { Get-NetAdapterBinding -InterfaceAlias $_.Name -ComponentID ms_tcpip6 }

# Create VLAN network for VMs
Write-Host "Creating VLAN Virtual Switch..." -ForegroundColor Green
New-VMSwitch -Name "VLAN Virtual Switch" -NetAdapterName $VLANAdapter -AllowManagementOS $false -Verbose

# Create Backup network for VMs
Write-Host "Creating Backup Virtual Switch..." -ForegroundColor Green
New-VMSwitch -Name "Backup Virtual Switch" -NetAdapterName $BackupAdapter -AllowManagementOS $true -Verbose

# Enable Cluster-Aware Updating
Write-Host "Enabling Cluster-Aware Updating..." -ForegroundColor Green
Add-CauClusterRole -EnableFirewallRules

Write-Host "Networking setup completed successfully!" -ForegroundColor Cyan