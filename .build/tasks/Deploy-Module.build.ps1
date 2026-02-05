<#
    Deploy-Module.build.ps1
    This task copies the built module to remote servers
#>

# Synopsis: Deploy built module to remote servers
task Deploy_Module {
    param(
        $BuildInfo,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Build -Color Cyan "Deploying module to remote servers..."

    # Get the built module path
    $modulePath = Join-Path $BuildInfo.OutputDirectory 'module' $BuildInfo.ProjectName

    if (-not (Test-Path $modulePath)) {
        Write-Build -Color Red "Module path not found: $modulePath"
        Write-Build -Color Yellow "Build the module first with: ./build.ps1 -Tasks build"
        throw "Module not found at $modulePath"
    }

    Write-Build -Color Green "Found module at: $modulePath"

    # Get credentials if not provided
    if (-not $Credential) {
        # Try to get from environment variable first
        if ($env:DEPLOY_CREDENTIAL_PATH -and (Test-Path $env:DEPLOY_CREDENTIAL_PATH)) {
            Write-Build -Color Yellow "Loading credential from: $env:DEPLOY_CREDENTIAL_PATH"
            $Credential = Import-Clixml -Path $env:DEPLOY_CREDENTIAL_PATH
        }
        else {
            Write-Build -Color Yellow "No credentials provided. Will attempt deployment with current user context."
            Write-Build -Color DarkGray "Tip: Use -Credential parameter or set DEPLOY_CREDENTIAL_PATH environment variable"
        }
    }

    # Configuration: List of remote servers to deploy to
    # You can modify this array to add/remove servers
    $servers = @(
        @{
            ComputerName = 'server1.contoso.com'
            DestinationPath = 'C:\Program Files\WindowsPowerShell\Modules\'
        }
        @{
            ComputerName = 'server2.contoso.com'
            DestinationPath = 'C:\Program Files\WindowsPowerShell\Modules\'
        }
        @{
            ComputerName = 'server3.contoso.com'
            DestinationPath = 'C:\Program Files\WindowsPowerShell\Modules\'
        }
    )

    # Deploy to each server
    foreach ($server in $servers) {
        Write-Build -Color Cyan "`nDeploying to $($server.ComputerName)..."

        try {
            # Create a session to the remote computer
            $sessionParams = @{
                ComputerName = $server.ComputerName
                ErrorAction  = 'Stop'
            }

            if ($Credential) {
                $sessionParams['Credential'] = $Credential
            }

            $session = New-PSSession @sessionParams
            Write-Build -Color Green "Connected to $($server.ComputerName)"

            # Copy the module to the remote server
            Copy-Item -Path "$modulePath/*" `
                      -Destination "$($server.DestinationPath)$($BuildInfo.ProjectName)" `
                      -ToSession $session `
                      -Recurse `
                      -Force

            Write-Build -Color Green "Successfully copied module to $($server.ComputerName)"

            # Optional: Verify the module is accessible
            $result = Invoke-Command -Session $session -ScriptBlock {
                Get-Module -Name $using:moduleName -ListAvailable
            } -ArgumentList $BuildInfo.ProjectName

            if ($result) {
                Write-Build -Color Green "Module verified on $($server.ComputerName): v$($result.Version)"
            }

            # Close the session
            Remove-PSSession $session
        }
        catch {
            Write-Build -Color Red "Failed to deploy to $($server.ComputerName): $($_.Exception.Message)"
        }
    }

    Write-Build -Color Green "Deployment complete!"
}

# Synopsis: Deploy module to a specific remote server
task Deploy_Module_Custom {
    param(
        $BuildInfo,
        [Parameter(Mandatory = $false)]
        [string]$ComputerName,
        [Parameter(Mandatory = $false)]
        [string]$DestinationPath = 'C:\Program Files\WindowsPowerShell\Modules\',
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    if (-not $ComputerName) {
        Write-Build -Color Red "ComputerName is required"
        Write-Build -Color Yellow "Usage: ./build.ps1 -Tasks Deploy_Module_Custom -ComputerName 'server.contoso.com'"
        throw "ComputerName parameter is mandatory"
    }

    $modulePath = Join-Path $BuildInfo.OutputDirectory 'module' $BuildInfo.ProjectName

    if (-not (Test-Path $modulePath)) {
        Write-Build -Color Red "Module path not found: $modulePath"
        throw "Module not found at $modulePath"
    }

    Write-Build -Color Cyan "Deploying to $ComputerName..."

    try {
        # Create session with optional credentials
        $sessionParams = @{
            ComputerName = $ComputerName
            ErrorAction  = 'Stop'
        }

        if ($Credential) {
            $sessionParams['Credential'] = $Credential
        }

        $session = New-PSSession @sessionParams
        Write-Build -Color Green "Connected to $ComputerName"

        Copy-Item -Path "$modulePath/*" `
                  -Destination "$DestinationPath$($BuildInfo.ProjectName)" `
                  -ToSession $session `
                  -Recurse `
                  -Force

        Write-Build -Color Green "Successfully deployed module to $ComputerName"

        # Verify deployment
        $result = Invoke-Command -Session $session -ScriptBlock {
            Get-Module -Name $using:moduleName -ListAvailable
        } -ArgumentList $BuildInfo.ProjectName

        if ($result) {
            Write-Build -Color Green "Module verified: v$($result.Version)"
        }

        Remove-PSSession $session
    }
    catch {
        Write-Build -Color Red "Deployment failed: $($_.Exception.Message)"
        throw $_
    }
}

# Synopsis: List configured deployment servers
task Deploy_List_Servers {
    Write-Build -Color Cyan "Configured deployment servers:"
    Write-Build -Color DarkGray "Edit '.build/tasks/Deploy-Module.build.ps1' to modify server list"
    Write-Build ""
    Write-Build -Color Yellow "Usage: ./build.ps1 -Tasks Deploy_Module"
}
