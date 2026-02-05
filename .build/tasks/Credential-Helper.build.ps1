<#
    Credential-Helper.build.ps1
    Helper tasks for managing credentials for deployment
#>

# Synopsis: Save credentials to encrypted file for deployment
task Save_Deploy_Credentials {
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Build -Color Cyan "Saving deployment credentials..."

    # Prompt for credentials if not provided
    if (-not $Credential) {
        $Credential = Get-Credential -Message "Enter credentials for remote deployment"
    }

    # Create config directory if it doesn't exist
    $configDir = Join-Path (Get-Location) '.build/config'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        Write-Build -Color Green "Created config directory: $configDir"
    }

    # Save credentials to encrypted file
    $credFile = Join-Path $configDir 'deploy-credentials.xml'
    $Credential | Export-Clixml -Path $credFile -Force

    Write-Build -Color Green "Credentials saved to: $credFile"
    Write-Build -Color Yellow "Set environment variable to use:"
    Write-Build -Color DarkGray "`$env:DEPLOY_CREDENTIAL_PATH = '$credFile'"
}

# Synopsis: Load saved deployment credentials
task Load_Deploy_Credentials {
    $credFile = Join-Path (Get-Location) '.build/config/deploy-credentials.xml'

    if (-not (Test-Path $credFile)) {
        Write-Build -Color Red "Credentials file not found: $credFile"
        Write-Build -Color Yellow "Run: ./build.ps1 -Tasks Save_Deploy_Credentials"
        throw "Credentials not configured"
    }

    Write-Build -Color Cyan "Loading credentials from: $credFile"
    $credential = Import-Clixml -Path $credFile

    # Set environment variable
    $env:DEPLOY_CREDENTIAL_PATH = $credFile

    Write-Build -Color Green "Credentials loaded successfully"
    Write-Build -Color DarkGray "Environment variable DEPLOY_CREDENTIAL_PATH set"
}

# Synopsis: Clear saved deployment credentials
task Clear_Deploy_Credentials {
    $credFile = Join-Path (Get-Location) '.build/config/deploy-credentials.xml'

    if (Test-Path $credFile) {
        Remove-Item -Path $credFile -Force
        Write-Build -Color Green "Credentials file deleted: $credFile"
    }
    else {
        Write-Build -Color Yellow "No credentials file found"
    }

    # Clear environment variable
    Remove-Item -Path 'env:DEPLOY_CREDENTIAL_PATH' -ErrorAction SilentlyContinue
    Write-Build -Color Green "Environment variable cleared"
}

# Synopsis: Show credential management help
task Credential_Help {
    Write-Build -Color Cyan "Credential Management for Deployment"
    Write-Build ""
    Write-Build -Color Yellow "Option 1: Save credentials securely (recommended)"
    Write-Build -Color DarkGray @"
    ./build.ps1 -Tasks Save_Deploy_Credentials
    This creates an encrypted XML file with your credentials.

    Then deploy with:
    ./build.ps1 -Tasks deploy
    ./build.ps1 -Tasks Deploy_Module_Custom -ComputerName 'server.com'
"@

    Write-Build ""
    Write-Build -Color Yellow "Option 2: Pass credentials directly (interactive)"
    Write-Build -Color DarkGray @"
    `$cred = Get-Credential
    ./build.ps1 -Tasks deploy -Credential `$cred
"@

    Write-Build ""
    Write-Build -Color Yellow "Option 3: Use environment variable"
    Write-Build -Color DarkGray @"
    `$env:DEPLOY_CREDENTIAL_PATH = 'C:\path\to\credentials.xml'
    ./build.ps1 -Tasks deploy
"@

    Write-Build ""
    Write-Build -Color Yellow "Option 4: Use current user context (no credentials needed)"
    Write-Build -Color DarkGray @"
    ./build.ps1 -Tasks deploy
    Requires current user to have admin access to remote servers
"@
}
