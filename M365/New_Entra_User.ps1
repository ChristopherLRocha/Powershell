#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.DirectoryManagement

<#
.SYNOPSIS
    Creates new users in Entra ID (Azure AD) with specified attributes and license assignments.

.DESCRIPTION
    This script creates new users in Entra ID with the following features:
    - Prompts for user details (first name, last name, location)
    - Creates email in format: flast@company.com
    - Assigns users to license-based security groups
    - Generates random passwords from word list with year digit and exclamation

#>

# Configuration - Update these paths for your environment
$WordListPath = "\\fileserver\share\wordlist.txt"
$Domain = "company.com"

# Function to connect to Microsoft Graph
function Connect-ToGraph {
    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        exit 1
    }
}

# Function to load word list
function Get-WordList {
    param([string]$Path)
    
    try {
        if (-not (Test-Path $Path)) {
            throw "Word list file not found at: $Path"
        }
        
        $words = Get-Content $Path | Where-Object { $_.Trim() -ne "" }
        if ($words.Count -eq 0) {
            throw "Word list file is empty"
        }
        
        Write-Host "Loaded $($words.Count) words from word list" -ForegroundColor Green
        return $words
    }
    catch {
        Write-Error "Failed to load word list: $($_.Exception.Message)"
        exit 1
    }
}

# Function to generate random password
function New-RandomPassword {
    param([array]$WordList)
    
    # Get 3 random words
    $randomWords = $WordList | Get-Random -Count 3
    
    # Get current year's last digit
    $yearDigit = (Get-Date).Year % 10
    
    # Combine words with proper capitalization
    $password = ""
    foreach ($word in $randomWords) {
        $password += (Get-Culture).TextInfo.ToTitleCase($word.ToLower())
    }
    
    # Add year digit and exclamation
    $password += $yearDigit.ToString() + "!"
    
    return $password
}

# Function to get license choice
function Get-LicenseChoice {
    do {
        Write-Host "`nAvailable License Options:" -ForegroundColor Cyan
        Write-Host "1. E1" -ForegroundColor White
        Write-Host "2. E3" -ForegroundColor White
        Write-Host "3. F3" -ForegroundColor White
        
        $choice = Read-Host "Select license (1-3)"
        
        switch ($choice) {
            "1" { return "E1" }
            "2" { return "E3" }
            "3" { return "F3" }
            default { 
                Write-Host "Invalid choice. Please select 1, 2, or 3." -ForegroundColor Red
            }
        }
    } while ($true)
}

# Function to create user
function New-EntraUser {
    param(
        [string]$FirstName,
        [string]$LastName,
        [string]$Location,
        [string]$License,
        [string]$Password,
        [string]$Domain
    )
    
    try {
        # Create username and email
        $username = ($FirstName.Substring(0,1) + $LastName).ToLower()
        $email = "$username@$Domain"
        $displayName = "$FirstName $LastName"
        
        Write-Host "`nCreating user with the following details:" -ForegroundColor Cyan
        Write-Host "Name: $displayName" -ForegroundColor White
        Write-Host "Username: $username" -ForegroundColor White
        Write-Host "Email: $email" -ForegroundColor White
        Write-Host "Location: $Location" -ForegroundColor White
        Write-Host "License: $License" -ForegroundColor White
        Write-Host "Password: $Password" -ForegroundColor White
        
        # Create user object
        $userParams = @{
            DisplayName = $displayName
            GivenName = $FirstName
            Surname = $LastName
            UserPrincipalName = $email
            MailNickname = $username
            CompanyName = $Location
            PasswordProfile = @{
                ForceChangePasswordNextSignIn = $true
                Password = $Password
            }
            AccountEnabled = $true
            UsageLocation = "US"  # Adjust as needed for your region
        }
        
        # Create the user
        $newUser = New-MgUser @userParams
        Write-Host "User created successfully with ID: $($newUser.Id)" -ForegroundColor Green
        
        return $newUser
    }
    catch {
        Write-Error "Failed to create user: $($_.Exception.Message)"
        return $null
    }
}

# Function to add user to BYOD group
function Add-UserToBYODGroup {
    param([string]$UserId)
    
    try {
        $groupName = "Intune_enrollment_BYOD"
        Write-Host "Adding user to mandatory BYOD group: $groupName" -ForegroundColor Yellow
        
        # Find the group
        $group = Get-MgGroup -Filter "displayName eq '$groupName'"
        
        if (-not $group) {
            Write-Warning "BYOD group '$groupName' not found. Please create it first."
            return $false
        }
        
        # Add user to group
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $UserId
        Write-Host "User added to BYOD group '$groupName' successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to add user to BYOD group: $($_.Exception.Message)"
        return $false
    }
}

# Function to add user to security group
function Add-UserToLicenseGroup {
    param(
        [string]$UserId,
        [string]$License
    )
    
    try {
        $groupName = "standard_$($License)_Users"
        Write-Host "Looking for security group: $groupName" -ForegroundColor Yellow
        
        # Find the group
        $group = Get-MgGroup -Filter "displayName eq '$groupName'"
        
        if (-not $group) {
            Write-Warning "Security group '$groupName' not found. Please create it first."
            return $false
        }
        
        # Add user to group
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $UserId
        Write-Host "User added to group '$groupName' successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to add user to group: $($_.Exception.Message)"
        return $false
    }
}

# Main script execution
try {
    Write-Host "=== Entra ID User Creation Script ===" -ForegroundColor Cyan
    Write-Host "This script will create a new user in Entra ID" -ForegroundColor White
    
    # Connect to Microsoft Graph
    Connect-ToGraph
    
    # Load word list
    $wordList = Get-WordList -Path $WordListPath
    
    # Gather user information
    Write-Host "`n--- User Information ---" -ForegroundColor Cyan
    $firstName = Read-Host "Enter first name"
    $lastName = Read-Host "Enter last name"
    $location = Read-Host "Enter user location/company"
    
    # Get license choice
    $license = Get-LicenseChoice
    
    # Generate password
    $password = New-RandomPassword -WordList $wordList
    
    # Create the user
    $newUser = New-EntraUser -FirstName $firstName -LastName $lastName -Location $location -License $license -Password $password -Domain $Domain
    
    if ($newUser) {
        # Add user to license group
        $licenseGroupSuccess = Add-UserToLicenseGroup -UserId $newUser.Id -License $license
        
        # Add user to mandatory BYOD group
        $byodGroupSuccess = Add-UserToBYODGroup -UserId $newUser.Id
        
        Write-Host "`n=== User Creation Summary ===" -ForegroundColor Green
        Write-Host "User: $($newUser.DisplayName)" -ForegroundColor White
        Write-Host "Email: $($newUser.UserPrincipalName)" -ForegroundColor White
        Write-Host "Password: $password" -ForegroundColor White
        Write-Host "License Group: $(if($licenseGroupSuccess){'Added'}else{'Failed'})" -ForegroundColor White
        Write-Host "BYOD Group: $(if($byodGroupSuccess){'Added'}else{'Failed'})" -ForegroundColor White
        
        Write-Host "`nUser creation completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Error "User creation failed. Please check the errors above."
    }
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
}
finally {
    # Disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph | Out-Null
        Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Yellow
    }
    catch {
        # Ignore disconnection errors
    }
}