$clustername = vmcluster

#enable S2D
Enable-ClusterStorageSpacesDirect -CimSession $clustername -PoolFriendlyName "S2DPool01"

#enable CSV cache in MB
$CSVCacheSize = 2048

Write-output "Setting the CSV cache..."
(Get-cluster $clustername).blockcachesize = $CSVCacheSize

Get-PhysicalDisk | Select-Object -Property Friendlyname, ClassName, CanPool, CannotPoolReason | Format-Table -AutoSize

Get-PhysicalDisk | Format-List

#Get health
Get-ClusterS2D

Get-StoragePool

Get-StorageSubSystem -FriendlyName *Cluster* | Get-StorageHealthReport

#Verify that all the physical and virtual drives are healthy by running the following commands:
Get-physicaldisk
Get-virtualdisks

#Check if there are backend repair jobs
Get-StorageJob

#Put storage in Maintenance mode
Get-StorageFaultDomain -type StorageScaleUnit | Where-Object {$_.Friendlyname -eq "<Servername>"} | enable-StorageMaintenanceMode