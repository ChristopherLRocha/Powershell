<#
.SYNOPSIS
    Automates the archiving and transfer of files from a local source folder to both a local archive and a remote iSeries server share.
    I made this script since we needed files to be copied from another job to a system that is separate from
    the windows domain.
    
.DESCRIPTION
    This script performs the following actions:
    1. Archives files from a source folder to a local archive directory.
    2. Maps a remote iSeries network share using provided credentials.
    3. Copies the same files to the remote share, ensuring name uniqueness if duplicates exist.
    4. Logs all actions to a log file with timestamps.
    5. Clears the source folder and disconnects the mapped network drive.
#>

# Define Paths
$SourceFolder = "C:\Path\to\Attachments"
$ArchiveFolder = "C:\Path\to\Archive"
$RemoteShare = "\\Path\to\Share"
$LogFile = "C:\Path\to\Logs\LogFile.txt"

# Credentials for remote share
$Username = "domain\username"
$Password = "Password123"

# Convert Password to Secure String
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)

# Function to Log Messages
function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -Append -FilePath $LogFile
}

# Function to get a unique filename by appending (1), (2), etc.
function Get-UniqueFileName {
    param (
        [string]$Directory,
        [string]$BaseFileName
    )
    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($BaseFileName)
    $Extension = [System.IO.Path]::GetExtension($BaseFileName)
    $FullPath = Join-Path $Directory $BaseFileName
    $counter = 1

    while (Test-Path $FullPath) {
        $NewFileName = "$FileName($counter)$Extension"
        $FullPath = Join-Path $Directory $NewFileName
        $counter++
    }

    return $FullPath
}

# Start Logging
Write-Log "Starting file copy job..."

# Step 1: Copy Files to Archive (Local Backup)
Write-Log "Archiving files locally to $ArchiveFolder..."
foreach ($file in Get-ChildItem -Path $SourceFolder) {
    $destinationFile = Join-Path -Path $ArchiveFolder -ChildPath $file.Name
    if (Test-Path $destinationFile) {
        $destinationFile = Join-Path -Path $ArchiveFolder -ChildPath (Append-Timestamp $file.Name)
    }
    Copy-Item -Path $file.FullName -Destination $destinationFile
}
Write-Log "Local archive completed successfully."

# Step 2: Remove any existing connections
Write-Log "Removing any existing connections to the server..."
$netUseCommand = "net use * /delete /y"
Invoke-Expression $netUseCommand

# Step 3: Map the iSeries Drive using net use
Write-Log "Mapping iSeries drive..."
$netUseCommand = "net use $RemoteShare /user:$Username $Password"
Invoke-Expression $netUseCommand

# Step 4: Copy Files to Remote iSeries Drive
$DestinationFolder = "\\cciusp\root\Eastern_Dragon"  # Update with correct path
Write-Log "Copying files to iSeries server..."
foreach ($file in Get-ChildItem -Path $SourceFolder) {
    $destinationFile = Join-Path -Path $DestinationFolder -ChildPath $file.Name
    if (Test-Path $destinationFile) {
        $destinationFile = Join-Path -Path $DestinationFolder -ChildPath (Append-Timestamp $file.Name)
    }
    Copy-Item -Path $file.FullName -Destination $destinationFile
}
Write-Log "Remote copy completed successfully."

# Step 5: Clear Source Folder
Write-Log "Clearing source folder..."
Remove-Item -Path "$SourceFolder\*" -Recurse -Force
Write-Log "Source folder cleared."

# Step 6: Remove Mapped Drive
Write-Log "Removing iSeries mapped drive..."
net use $RemoteShare /delete
Write-Log "File copy job completed."