<#
.SYNOPSIS
    Recursively scans all folders in a specified path to audit their sizes and access permissions.
    Filters out standard system-level ACL entries and exports custom or potentially risky permissions
    to a CSV file. Any access errors are logged separately.

.PARAMETER FolderPath
    Root folder to begin the recursive search.

.PARAMETER ExportPath
    Directory where output CSV and error log files will be saved.

.OUTPUTS
    - PrePermissionExport.csv: Contains folder size and non-standard ACL entries.
    - AccessDenied.txt: Contains error messages for folders that could not be accessed.

.NOTES
    Make sure to run this script with appropriate privileges to avoid excessive access errors.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [Parameter(Mandatory = $true)]
    [string]$ExportPath
)

# Create a results array
$results = @()

# Clear previous error buffer
$Error.Clear()

# Get all folders under the specified path
try {
    $Folders = Get-ChildItem -Path $FolderPath -Recurse -Directory -ErrorAction Stop
} catch {
    Write-Error "Failed to retrieve folders from $FolderPath: $_"
    exit 1
}

# Log any access errors during folder enumeration
foreach ($err in $Error) {
    $err.Exception.Message | Out-File -FilePath "$ExportPath\AccessDenied.txt" -Append
}
$Error.Clear() # Clear again before next phase

# Loop through each folder
foreach ($Folder in $Folders) {
    # Get folder size in MB
    $size = 0
    try {
        $size = ((Get-ChildItem -Path $Folder.FullName -Recurse -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum) / 1MB
    } catch {
        $_.Exception.Message | Out-File -FilePath "$ExportPath\AccessDenied.txt" -Append
        continue
    }

    # Get the folder's access control list (ACL)
    try {
        $Acls = Get-Acl -Path $Folder.FullName
    } catch {
        $_.Exception.Message | Out-File -FilePath "$ExportPath\AccessDenied.txt" -Append
        continue
    }

    # Filter and collect non-standard ACL entries
    foreach ($AclEntry in $Acls.Access) {
        if (
            $AclEntry.IdentityReference -notlike "BUILTIN\Administrators" -and
            $AclEntry.IdentityReference -notlike "CREATOR OWNER" -and
            $AclEntry.IdentityReference -notlike "NT AUTHORITY\SYSTEM" -and
            $AclEntry.IdentityReference -notlike "S-1-*" -and
            $AclEntry.FileSystemRights -notlike "-*" -and
            [int64]$AclEntry.FileSystemRights -ne 268435456
        ) {
            $properties = @{
                FolderName        = $Folder.Name
                FolderPath        = $Folder.FullName
                IdentityReference = $AclEntry.IdentityReference.ToString()
                SizeMB            = [math]::Round($size, 2)
                Permissions       = $AclEntry.FileSystemRights
                AccessControlType = $AclEntry.AccessControlType.ToString()
                IsInherited       = $AclEntry.IsInherited
            }

            $results += New-Object psobject -Property $properties
        }
    }
}

# Export results to CSV
if ($results.Count -gt 0) {
    $results | Select-Object FolderName, FolderPath, IdentityReference, SizeMB, Permissions, AccessControlType, IsInherited |
        Export-Csv -Path "$ExportPath\PrePermissionExport.csv" -Append -NoTypeInformation
    Write-Host "Export completed successfully." -ForegroundColor Green
} else {
    Write-Host "No non-standard ACL entries found." -ForegroundColor Yellow
}
