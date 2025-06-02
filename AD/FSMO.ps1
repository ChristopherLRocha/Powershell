## Check FSMO Role Holders for the Current Domain
Get-ADDomain | Select-Object InfrastructureMaster, PDCEmulator, RIDMaster

## Check FSMO Role Holders for the Forest
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster

## Detailed FSMO Role Holders for Both Domain and Forest
Get-ADDomain | Format-List InfrastructureMaster, PDCEmulator, RIDMaster
Get-ADForest | Format-List SchemaMaster, DomainNamingMaster

## Move a FSMO Role
Move-ADDirectoryServerOperationMasterRole -Identity "TargetDC" -OperationMasterRole PDCEmulator

## Seize a FSMO Role

Move-ADDirectoryServerOperationMasterRole -Identity "TargetDC" -OperationMasterRole PDCEmulator -Force
