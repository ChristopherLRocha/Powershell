<#
.SYNOPSIS
    Automates the installation and configuration of the Zabbix agent on a Windows machine.

.DESCRIPTION
    This script performs the following steps:
    - Defines the source path of the latest Zabbix agent release and the target installation directory.
    - Retrieves the server's hostname.
    - Creates the Zabbix installation directory if it doesn't already exist.
    - Copies the agent files from the network share to the local machine.
    - Replaces the placeholder hostname in the agent configuration file with the actual hostname.
    - Installs the Zabbix agent service using the updated configuration.
    - Starts the Zabbix agent service.

.NOTES
    - Requires administrator privileges.
    - Assumes the Zabbix agent files are structured correctly in the source path.
    - Configuration file must contain the placeholder text "Windows host" for hostname substitution.
#>

#-----------Variables-----------------------

$latest_release_file_path = "\\path\to\latest\files"
$zabbix_directory = "C:\Program Files\Zabbix"
$Zabbix_Host = "DNS entry or IP address of your zabbix host"

#-------------------------------------------

# Gets the server host name
$serverHostname = $env:COMPUTERNAME

# Create Zabbix DIR if it doesn't exist
if (-not (Test-Path $zabbix_directory)) {
    New-Item -Path $zabbix_directory -ItemType Directory -Force
}

# Copy files from server to Zabbix DIR
Copy-Item -Path "$latest_release_file_path\*" -Destination $zabbix_directory -Recurse -Force

# Replace hostname in the config file
$configPath = Join-Path $zabbix_directory "conf\zabbix_agentd.conf"
(Get-Content -Path $configPath) | ForEach-Object { $_ -Replace 'Windows host', $serverHostname } | Set-Content -Path $configPath

# Replace hostname and IP address in the config file
$configPath = Join-Path $zabbix_directory "conf\zabbix_agentd.conf"
(Get-Content -Path $configPath) | ForEach-Object {
    $_ -replace 'Windows host', $serverHostname -replace '127\.0\.0\.1', $Zabbix_Host
} | Set-Content -Path $configPath

# Install the agent
& "$zabbix_directory\bin\zabbix_agentd.exe" --config "$configPath" --install

# Start the agent
& "$zabbix_directory\bin\zabbix_agentd.exe" --start --config "$configPath"
