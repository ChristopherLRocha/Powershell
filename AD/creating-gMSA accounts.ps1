<#
Step 1 - (on a non-DC)
Add-WindowsFeature RSAT-AD-Powershell

Step 2 - Create a Security group and add all the hostnames you will use the gMSA on.
These are the computers permitted to retrieve the password from AD
#>

$gMSA_Name = 'VeeamOne_gMSA'
$gMSA_FQDN = 'VeeamOne_gMSA.coilcraft.com'

# Getting all the hostnames from the group
$gMSA_HostNames = Get-ADGroupMember -Identity gMSA_VeeamOne_computers | Select-Object -ExpandProperty Name

# Add the Rootkey
Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)

# Get the principal for the computer account(s) in $gMSA_HostNames
$gMSA_HostsGroups = $gMSA_HostNames | ForEach-Object { Get-ADComputer -Identity $_ }

# Create the gMSA
New-ADServiceAccount -Name $gMSA_Name -DNSHostName $gMSA_FQDN -PrincipalsAllowedToRetrieveManagedPassword $gMSA_HostsGroups

# on target machine
Install-ADServiceAccount <gMSA_Name>

#You can now use the gMSA for a service, a group of IIS applications, or scheduled task. To do this, you must use the name of the account with $ at the end and leave the password blank.