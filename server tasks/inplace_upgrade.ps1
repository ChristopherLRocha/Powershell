<#
.SYNOPSIS
Automates an in-place upgrade from Windows Server 2016 to Windows Server 2022.

.DESCRIPTION
This script launches an unattended upgrade using setup.exe with silent mode, dynamic updates enabled,
and automatic reboot. It creates a log directory for upgrade logs and initiates the upgrade process 
with minimal user interaction.

.NOTES
- Requires the Windows Server 2022 ISO to be mounted or extracted.
- Tested for like-for-like upgrades (e.g., Standard → Standard).
- Ensure proper backups and application compatibility before running.

#>

# upgrade-ws2022.ps1

$setupPath = "D:\WS2022\setup.exe"  # Adjust this to your actual path
$logPath = "C:\UpgradeLogs"

# Create log directory if it doesn't exist
if (!(Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force
}

# Start unattended upgrade with automatic reboot
Start-Process -FilePath $setupPath -ArgumentList @(
    "/auto upgrade",
    "/quiet",
    "/dynamicupgrade enable",
    "/showoobe none",
    "/compat IgnoreWarning",
    "/copylogs $logPath"
) -Wait