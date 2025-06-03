<#
.SYNOPSIS
    Uninstalls the Zabbix agent from a Windows machine.

.DESCRIPTION
    This script stops the running Zabbix agent service, uninstalls it,
    and removes all related files from "C:\Program Files\Zabbix".

.NOTES
    - Requires administrator privileges.
    - Assumes the agent was installed in the default directory.
    - Uses zabbix_agentd.exe for both stopping and uninstalling the service.
#>

#----------Variables-----------

$zabbix_directory = "C:\Program Files\Zabbix"
$configPath = "$zabbix_directory\conf\zabbix_agentd.conf"
$agentExe = "$zabbix_directory\bin\zabbix_agentd.exe"

#------------------------------

# Stop the Zabbix Agent service
if (Test-Path $agentExe) {
    & $agentExe --stop --config $configPath
    Write-Host "zabbix_agentd has been stopped."
} else {
    Write-Host "Agent executable not found. Skipping stop step."
}

# Uninstall the Zabbix Agent service
if (Test-Path $agentExe) {
    & $agentExe --uninstall --config $configPath
    Write-Host "zabbix_agentd has been uninstalled."
} else {
    Write-Host "Agent executable not found. Skipping uninstall step."
}

Start-Sleep -Seconds 1

# Clean up Zabbix directory
if (Test-Path $zabbix_directory) {
    Remove-Item $zabbix_directory -Recurse -Force
    Write-Host "Zabbix files removed from $zabbix_directory"
} else {
    Write-Host "Zabbix directory not found. Nothing to remove."
}
