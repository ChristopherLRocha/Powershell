$clustername = vmcluster

#enable S2D
Enable-ClusterStorageSpacesDirect -CimSession $clustername -PoolFriendlyName "S2DPool01"

#enable CSV cache in MB
$CSVCacheSize = 2048

Write-output "Setting the CSV cache..."
(Get-cluster $clustername).blockcachesize = $CSVCacheSize

Get-PhysicalDisk | Select-Object -Property Friendlyname, ClassName, CanPool, CannotPoolReason | Format-Table -AutoSize

Get-PhysicalDisk | Format-List