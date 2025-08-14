<#
.SYNOPSIS
Downloads PDF, Word, and Excel attachments from unread emails in a specific Outlook mailbox folder using Microsoft Graph API.

.DESCRIPTION
This script authenticates with Microsoft Graph API using client credentials (App Registration) and searches a specified user's mailbox folder 
(e.g., Inbox) for unread emails with attachments. It downloads PDF, DOCX, XLS, and XLSX files to a defined path on disk. 
If any attachments are successfully saved, the corresponding email is marked as read.

.PARAMETER tenantId
The Azure AD tenant ID used for authentication.

.PARAMETER clientId
The application (client) ID registered in Azure AD.

.PARAMETER clientSecret
The client secret associated with the app registration.

.PARAMETER userEmail
The email address (UPN or SID) of the mailbox to search.

.PARAMETER folderName
The name of the mailbox folder to check (e.g., "Inbox").

.PARAMETER downloadPath
The local or network path where attachments will be saved.

.NOTES
- Requires application permissions for Microsoft Graph Mail.Read and Mail.ReadWrite.
- Make sure the app registration has mailbox access granted via admin consent.
- Avoid duplicate file overwrites by appending a counter if a file already exists.

#>

# ==== CONFIG ====
$tenantId     = ''
$clientId     = ''
$clientSecret = ''
$userEmail    = ''
$folderName   = 'Inbox'
$downloadPath = ''

# ==== AUTH ====
$body = @{
    client_id     = $clientId
    scope         = 'https://graph.microsoft.com/.default'
    client_secret = $clientSecret
    grant_type    = 'client_credentials'
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
$accessToken = $tokenResponse.access_token
$headers = @{ Authorization = "Bearer $accessToken" }

# ==== GET FOLDER ID ====
$folderUrl = "https://graph.microsoft.com/v1.0/users/$userEmail/mailFolders"
$folders = Invoke-RestMethod -Uri $folderUrl -Headers $headers
$folderId = ($folders.value | Where-Object { $_.displayName -eq $folderName }).id

if (-not $folderId) {
    Write-Error "Folder '$folderName' not found."
    exit
}

# ==== GET UNREAD EMAILS WITH ATTACHMENTS ====
$messagesUrl = "https://graph.microsoft.com/v1.0/users/$userEmail/mailFolders/$folderId/messages?`$filter=isRead eq false and hasAttachments eq true&`$top=25"
$messages = Invoke-RestMethod -Uri $messagesUrl -Headers $headers

foreach ($message in $messages.value) {
    $messageId = $message.id
    $subject = $message.subject
    Write-Output "`n📧 Processing: $subject"
    
    $fileSaved = $false
    $attachmentCount = 0
    $savedCount = 0
    
    try {
        # ==== GET ATTACHMENTS WITH RETRY LOGIC ====
        $attachmentsUrl = "https://graph.microsoft.com/v1.0/users/$userEmail/messages/$messageId/attachments"
        $maxRetries = 3
        $retryCount = 0
        $attachments = $null
        
        do {
            try {
                $attachments = Invoke-RestMethod -Uri $attachmentsUrl -Headers $headers
                break
            } catch {
                $retryCount++
                Write-Output "Retry $retryCount/$maxRetries for getting attachments: $($_.Exception.Message)"
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Seconds (2 * $retryCount)  # Exponential backoff
                } else {
                    throw
                }
            }
        } while ($retryCount -lt $maxRetries)
        
        $attachmentCount = $attachments.value.Count
        Write-Output "📎 Found $attachmentCount attachment(s)"
        
        foreach ($att in $attachments.value) {
            Write-Output "  Processing attachment: $($att.name) (Type: $($att.'@odata.type'))"
            
            # Handle both file attachments and item attachments
            if ($att.'@odata.type' -eq "#microsoft.graph.fileAttachment") {
                $filename = $att.name.ToLower()
                
                if ($filename -like '*.pdf' -or $filename -like '*.docx' -or $filename -like '*.doc' -or 
                    $filename -like '*.xls' -or $filename -like '*.xlsx' -or $filename -like '*.xlsm') {
                    
                    # Prepare filename and avoid overwrite
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($att.name)
                    $ext = [System.IO.Path]::GetExtension($att.name)
                    $newFilename = "$baseName$ext"
                    $fullPath = Join-Path $downloadPath $newFilename
                    $counter = 1
                    
                    while (Test-Path $fullPath) {
                        $newFilename = "${baseName}_$counter$ext"
                        $fullPath = Join-Path $downloadPath $newFilename
                        $counter++
                    }
                    
                    try {
                        # Validate base64 content exists
                        if (-not $att.contentBytes) {
                            Write-Output "No content bytes for $($att.name)"
                            continue
                        }
                        
                        $bytes = [System.Convert]::FromBase64String($att.contentBytes)
                        
                        # Validate file size
                        if ($bytes.Length -eq 0) {
                            Write-Output "Empty file content for $($att.name)"
                            continue
                        }
                        
                        [IO.File]::WriteAllBytes($fullPath, $bytes)
                        $fileSaved = $true
                        $savedCount++
                        Write-Output "Saved: $newFilename (Size: $($bytes.Length) bytes)"
                        
                        # Add small delay between downloads to avoid rate limiting
                        Start-Sleep -Milliseconds 100
                        
                    } catch {
                        Write-Output "Failed to save $($att.name) - $($_.Exception.Message)"
                        Write-Output "   Error details: $($_.Exception.GetType().Name)"
                    }
                } else {
                    Write-Output "Skipped unsupported file: $($att.name)"
                }
            } elseif ($att.'@odata.type' -eq "#microsoft.graph.itemAttachment") {
                Write-Output "Item attachment found: $($att.name) - requires separate handling"
            } else {
                Write-Output "Unsupported attachment type: $($att.'@odata.type')"
            }
        }
        
    } catch {
        Write-Output "❌ Error processing attachments for message '$subject': $($_.Exception.Message)"
        continue
    }
    
    # ==== MARK EMAIL AS READ ONLY IF FILES WERE SAVED ====
    Write-Output "Summary: $savedCount/$attachmentCount attachments saved"
    
    if ($fileSaved) {
        try {
            $markReadUrl = "https://graph.microsoft.com/v1.0/users/$userEmail/messages/$messageId"
            $body = @{ isRead = $true } | ConvertTo-Json
            Invoke-RestMethod -Method Patch -Uri $markReadUrl -Headers $headers -Body $body -ContentType "application/json"
            Write-Output "Marked as read"
        } catch {
            Write-Output "Failed to mark email as read: $($_.Exception.Message)"
        }
    } else {
        Write-Output "No valid attachments saved. Email left unread."
    }
}