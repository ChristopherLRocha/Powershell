<#
.SYNOPSIS
    Retrieves Hyper-V virtual machines with checkpoints from multiple remote servers and emails a report.

.DESCRIPTION
    This script connects to a list of Hyper-V hosts remotely, queries all VMs to find those that have checkpoints (snapshots),
    and generates an HTML report listing each VM with checkpoint details. It then emails the report to a specified recipient.
    If no checkpoints are found on any VM, the script sends an email indicating no checkpoints were found.

.PARAMETER servers
    An array of server names or IPs to query for Hyper-V VMs.

.PARAMETER smtpServer
    The SMTP server used to send the email report.

.PARAMETER sender
    The email address used as the sender of the report.

.PARAMETER recipient
    The email address to receive the report.

.NOTES
    - Requires PowerShell remoting enabled on target Hyper-V hosts.
    - Uses Send-MailMessage cmdlet for emailing; ensure SMTP server permits relay.
#>

# === Set Variables ===
$servers = @("Server01", "Server02", "Server03")  # Replace with real server names
$smtpServer = "smtp.company.com"
$sender = "hyperv-checkpoint-report@company.com"
$recipient = "pc_admins@company.com"

# === Collect Checkpoint Data ===
$results = foreach ($server in $servers) {
    try {
        $vmsWithCheckpoints = Invoke-Command -ComputerName $server -ScriptBlock {
            Get-VM | ForEach-Object {
                $vm = $_
                $checkpoints = Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue
                if ($checkpoints) {
                    [PSCustomObject]@{
                        Server          = $env:COMPUTERNAME
                        VMName          = $vm.Name
                        CheckpointCount = $checkpoints.Count
                        SnapshotNames   = $checkpoints.Name -join ", "
                    }
                }
            }
        }
        # Ensure result is always an array (empty or with objects)
        @($vmsWithCheckpoints)
    } catch {
        Write-Warning "Failed to connect to ${server}: $($_.Exception.Message)"
        @()  # Return empty array on error to keep $results consistent
    }
}

# === Send Email Based on Checkpoint Results ===
if ($results -and (@($results).Count -gt 0)) {
    $htmlBody = $results |
        Sort-Object Server, VMName |
        ConvertTo-Html -Property Server, VMName, CheckpointCount, SnapshotNames `
        -Head "<style>table{border-collapse:collapse;}td,th{border:1px solid #ccc;padding:5px;}</style>" `
        -Title "Hyper-V Checkpoint Report" | Out-String

    Send-MailMessage -From $sender -To $recipient -Subject "Hyper-V Checkpoint Report (VMs with Checkpoints Only)" -Body $htmlBody -BodyAsHtml -SmtpServer $smtpServer
}
else {
    $noCheckpointBody = "<html><body><p>No checkpoints found on any VM in the checked servers.</p></body></html>"

    Send-MailMessage -From $sender -To $recipient -Subject "Hyper-V Checkpoint Report - No Checkpoints Found" -Body $noCheckpointBody -BodyAsHtml -SmtpServer $smtpServer
}
