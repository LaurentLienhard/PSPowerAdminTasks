<#
    Deploy-Module.build.ps1
    This task copies the built module to remote servers
#>

# Synopsis: Deploy built module to remote servers
task Deploy_Module {
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Build -Color Cyan "Deploying module to remote servers..."

    # Get configuration values
    $sourceManifest = Get-Item -Path "$BuildRoot/source/*.psd1" | Select-Object -First 1
    $ProjectName = $sourceManifest.BaseName
    $OutputDirectory = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $BuildRoot $OutputDirectory }
    $BuiltModuleSubdirectory = 'module'

    # Get the built module path
    $buildModuleOutput = Join-Path $OutputDirectory $BuiltModuleSubdirectory
    $modulePath = Join-Path $buildModuleOutput $ProjectName

    if (-not (Test-Path $modulePath)) {
        Write-Build -Color Red "Module path not found: $modulePath"
        Write-Build -Color Yellow "Build the module first with: ./build.ps1 -Tasks build"
        throw "Module not found at $modulePath"
    }

    Write-Build -Color Green "Found module at: $modulePath"

    # Load server configuration from external file
    $serversConfigFile = Join-Path $BuildRoot '.build/deploy-servers.ps1'
    if (-not (Test-Path $serversConfigFile)) {
        Write-Build -Color Red "Server configuration file not found: $serversConfigFile"
        Write-Build -Color Yellow "Please copy '.build/deploy-servers.ps1.example' to '.build/deploy-servers.ps1' and update with your servers."
        throw "Server configuration file is missing"
    }

    $servers = @(. $serversConfigFile 2>$null)

    if (-not $servers -or $servers.Count -eq 0 -or $servers[0] -isnot [hashtable]) {
        Write-Build -Color Red "No servers configured in $serversConfigFile"
        throw "Server list is empty"
    }

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
                      -Destination "$($server.DestinationPath)$ProjectName" `
                      -ToSession $session `
                      -Recurse `
                      -Force

            Write-Build -Color Green "Successfully copied module to $($server.ComputerName)"

            # Optional: Verify the module is accessible
            $result = Invoke-Command -Session $session -ScriptBlock {
                Get-Module -Name $using:moduleName -ListAvailable
            } -ArgumentList $ProjectName

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

    # Get configuration values
    $sourceManifest = Get-Item -Path "$BuildRoot/source/*.psd1" | Select-Object -First 1
    $ProjectName = $sourceManifest.BaseName
    $OutputDirectory = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $BuildRoot $OutputDirectory }
    $BuiltModuleSubdirectory = 'module'

    # Get the built module path
    $buildModuleOutput = Join-Path $OutputDirectory $BuiltModuleSubdirectory
    $modulePath = Join-Path $buildModuleOutput $ProjectName

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
                  -Destination "$DestinationPath$ProjectName" `
                  -ToSession $session `
                  -Recurse `
                  -Force

        Write-Build -Color Green "Successfully deployed module to $ComputerName"

        # Verify deployment
        $result = Invoke-Command -Session $session -ScriptBlock {
            Get-Module -Name $using:moduleName -ListAvailable
        } -ArgumentList $ProjectName

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

# Synopsis: Deploy built module to local machine
task Deploy_Local {
    Write-Build -Color Cyan "Deploying module locally..."

    # Get configuration values
    $sourceManifest = Get-Item -Path "$BuildRoot/source/*.psd1" | Select-Object -First 1
    $ProjectName = $sourceManifest.BaseName
    $OutputDirectory = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $BuildRoot $OutputDirectory }
    $BuiltModuleSubdirectory = 'module'

    # Get the built module path
    $buildModuleOutput = Join-Path $OutputDirectory $BuiltModuleSubdirectory
    $modulePath = Join-Path $buildModuleOutput $ProjectName

    if (-not (Test-Path $modulePath)) {
        Write-Build -Color Red "Module path not found: $modulePath"
        Write-Build -Color Yellow "Build the module first with: ./build.ps1 -Tasks build"
        throw "Module not found at $modulePath"
    }

    Write-Build -Color Green "Found module at: $modulePath"

    # Determine destination based on platform
    if ($PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.OS -like 'Windows*') {
        $systemPath = "C:\Program Files\PowerShell\Modules\$ProjectName"
        # User module path
        $userPath = "$HOME\Documents\PowerShell\Modules\$ProjectName"

        # Check if running as administrator
        $isAdmin = $false
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            $isAdmin = $false
        }

        if ($isAdmin) {
            $destination = $systemPath
            Write-Build -Color Green "Running as Administrator - deploying to system path"
            Write-Build -Color DarkGray "Destination: $destination"
        }
        else {
            Write-Build -Color Yellow "Not running as Administrator - deploying to user path (PowerShell 7)"
            Write-Build -Color DarkGray "System path requires admin: $systemPath"
            Write-Build -Color DarkGray "User path: $userPath"
            $destination = $userPath
        }
    }
    else {
        # On macOS/Linux, use .local/share
        $destination = "$HOME/.local/share/powershell/Modules/$ProjectName"
        Write-Build -Color DarkGray "Platform: $($PSVersionTable.OS) - using user module path"
        Write-Build -Color DarkGray "Destination: $destination"
    }

    try {
        # Create destination directory if it doesn't exist
        if (-not (Test-Path $destination)) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Write-Build -Color Green "Created directory: $destination"
        }

        # Copy module files
        Write-Build -Color Cyan "Copying module files..."
        Copy-Item -Path "$modulePath/*" -Destination $destination -Recurse -Force

        Write-Build -Color Green "Successfully copied module to: $destination"

        # Verify deployment
        $module = Get-Module -Name $ProjectName -ListAvailable | Where-Object { $_.Path -like "$destination*" }
        if ($module) {
            Write-Build -Color Green "Module verified: v$($module.Version)"
            Write-Build -Color Green "You can now use: Import-Module $ProjectName"
        }
        else {
            Write-Build -Color Yellow "Warning: Module could not be verified"
        }
    }
    catch {
        Write-Build -Color Red "Deployment failed: $($_.Exception.Message)"

        # Provide helpful error message for permission issues on Windows
        if (($PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.OS -like 'Windows*') -and
            ($_ -like "*denied*" -or $_.Exception.Message -like "*Access*")) {
            Write-Build -Color Yellow ""
            Write-Build -Color Yellow "⚠️  Permission Denied - You need administrator privileges"
            Write-Build -Color Yellow ""
            Write-Build -Color DarkGray "Options:"
            Write-Build -Color DarkGray "1. Run PowerShell as Administrator and try again:"
            Write-Build -Color DarkGray "   ./build.ps1 -Tasks deploy"
            Write-Build -Color DarkGray ""
            Write-Build -Color DarkGray "2. Or deploy to user directory instead:"
            if (-not [string]::IsNullOrEmpty($userPath)) {
                Write-Build -Color DarkGray "   $userPath"
            }
            Write-Build -Color DarkGray ""
            Write-Build -Color DarkGray "   Manual install: Copy-Item -Path '$modulePath/*' -Destination '$userPath' -Recurse -Force"
        }

        throw $_
    }
}

# Synopsis: List configured deployment servers
task Deploy_List_Servers {
    Write-Build -Color Cyan "Configured deployment servers:"
    Write-Build -Color DarkGray "Edit '.build/deploy-servers.ps1' to modify server list"
    Write-Build -Color DarkGray "See '.build/deploy-servers.ps1.example' for template"
    Write-Build -Color White ""

    $serversConfigFile = Join-Path $BuildRoot '.build/deploy-servers.ps1'
    if (Test-Path $serversConfigFile) {
        try {
            $rawOutput = & {
                . $serversConfigFile 6>$null 4>$null 3>$null 2>$null
            }

            # Handle the output - it could be a single hashtable or array
            if ($rawOutput -is [object[]]) {
                $servers = @($rawOutput | Where-Object { $_ -is [hashtable] })
            } elseif ($rawOutput -is [hashtable]) {
                $servers = @($rawOutput)
            } else {
                $servers = @()
            }

            if ($servers.Count -gt 0) {
                Write-Build -Color White ""
                foreach ($server in $servers) {
                    if ($server.ContainsKey('ComputerName')) {
                        Write-Build -Color Green "  • $($server.ComputerName) → $($server.DestinationPath)"
                    }
                }
            }
        } catch {
            Write-Build -Color Yellow "Error reading server configuration: $_"
        }
    }
    else {
        Write-Build -Color Yellow "No server configuration found. Create '.build/deploy-servers.ps1' from '.build/deploy-servers.ps1.example'"
    }

    Write-Build -Color White ""
    Write-Build -Color Yellow "Usage: ./build.ps1 -Tasks Deploy_Module"
}
