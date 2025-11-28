function Get-RemoteGPResult
{
    <#
    .SYNOPSIS
        Generates and retrieves a Group Policy results report from a remote computer.

    .DESCRIPTION
        This function executes 'gpresult /h' on a remote computer to generate
        a Group Policy results HTML report, then copies it to the local machine.
        Optionally, it can display the report immediately in the default browser.

    .PARAMETER ComputerName
        Name or IP address of the remote computer to query.

    .PARAMETER Credential
        Credentials to connect to the remote computer.
        If not specified, uses the current user's credentials.

    .PARAMETER OutputPath
        Local path where the HTML report will be saved.
        Can be a directory path or a full file path.
        - If a directory (existing or ending with / or \), a timestamped filename will be added.
        - If a file path with extension, it will be used as-is.
        Default: Current directory with filename "GPResult_<ComputerName>_<Timestamp>.html".

    .PARAMETER Scope
        Scope of the report: 'Computer', 'User', or 'Both'.
        Default: 'Both'.

    .PARAMETER Show
        If specified, opens the HTML report in the default browser after retrieval.

    .PARAMETER UserName
        For 'User' or 'Both' scope, specify the user account to query.
        If not specified, uses the current user on the remote computer.

    .PARAMETER ThrottleLimit
        Maximum number of computers to process in parallel (PowerShell 7+ only).
        Default: 5
        PowerShell 5.1 will process computers sequentially regardless of this setting.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01"

        Generates a GP results report for SERVER01 and saves it to the current directory.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01" -Show

        Generates a GP results report for SERVER01 and opens it immediately in the browser.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01" -Credential (Get-Credential) -OutputPath "C:\Reports\gpreport.html"

        Generates a report using specific credentials and saves it to a specific file path.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01" -OutputPath "C:\Reports\"

        Saves the report to C:\Reports\ with an auto-generated timestamped filename.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01" -Scope User -UserName "domain\jdoe"

        Generates a report for a specific user account on SERVER01.

    .EXAMPLE
        "SERVER01", "SERVER02" | Get-RemoteGPResult -Show

        Generates reports for multiple computers via pipeline and displays each one.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01", "SERVER02", "SERVER03" -ThrottleLimit 10

        Processes up to 10 computers in parallel (PowerShell 7+ only).
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Computer', 'User', 'Both')]
        [string]$Scope = 'Both',

        [Parameter(Mandatory = $false)]
        [switch]$Show,

        [Parameter(Mandatory = $false)]
        [string]$UserName,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = 5
    )

    begin
    {
        Write-Verbose "Starting Group Policy results retrieval"

        # Collect all computers from pipeline
        $allComputers = [System.Collections.Generic.List[string]]::new()
    }

    process
    {
        # Add computers to the list
        foreach ($computer in $ComputerName)
        {
            $allComputers.Add($computer)
        }
    }

    end
    {
        Write-Verbose "Processing $($allComputers.Count) computer(s)"

        # Check if PowerShell 7+ and multiple computers
        $useParallel = ($PSVersionTable.PSVersion.Major -ge 7) -and ($allComputers.Count -gt 1)

        if ($useParallel)
        {
            Write-Verbose "Using parallel processing with throttle limit of $ThrottleLimit"

            $allComputers | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                $computer = $_
                $cred = $using:Credential
                $outPath = $using:OutputPath
                $scopeValue = $using:Scope
                $showReport = $using:Show
                $user = $using:UserName

                try
                {
                    Write-Verbose "Processing $computer..."

                    # Test remote connectivity
                    if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet))
                    {
                        Write-Error "Unable to reach $computer. Please verify the computer is online and accessible."
                        return
                    }

                    # Generate timestamped filename if OutputPath not specified
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

                    if (-not $outPath)
                    {
                        # No path specified - use current directory with timestamped filename
                        $localReportPath = Join-Path -Path $PWD -ChildPath "GPResult_${computer}_${timestamp}.html"
                    }
                    else
                    {
                        # OutputPath specified - check if it's a directory or file
                        if (Test-Path -Path $outPath -PathType Container)
                        {
                            # It's a directory - add timestamped filename
                            $localReportPath = Join-Path -Path $outPath -ChildPath "GPResult_${computer}_${timestamp}.html"
                        }
                        elseif ($outPath -match '[\\/]$' -or -not [System.IO.Path]::HasExtension($outPath))
                        {
                            # Path ends with slash or has no extension - treat as directory
                            # Create directory if it doesn't exist
                            if (-not (Test-Path -Path $outPath))
                            {
                                New-Item -Path $outPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                            }
                            $localReportPath = Join-Path -Path $outPath -ChildPath "GPResult_${computer}_${timestamp}.html"
                        }
                        else
                        {
                            # Treat as full file path
                            $localReportPath = $outPath

                            # Ensure parent directory exists
                            $parentDir = Split-Path -Path $outPath -Parent
                            if ($parentDir -and -not (Test-Path -Path $parentDir))
                            {
                                New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                            }
                        }
                    }

                    # Create remote session parameters
                    $sessionParams = @{
                        ComputerName = $computer
                        ErrorAction  = 'Stop'
                    }

                    if ($cred)
                    {
                        $sessionParams.Add('Credential', $cred)
                    }

                    Write-Verbose "Creating remote session to $computer..."
                    $session = New-PSSession @sessionParams

                    try
                    {
                        # Generate report on remote computer
                        Write-Verbose "Generating Group Policy results report on $computer..."

                        $scriptBlock = {
                            param($ScopeParam, $UserNameParam)

                            $remoteTempPath = Join-Path -Path $env:TEMP -ChildPath "gpresult_temp_$(Get-Random).html"

                            # Build gpresult command
                            $gpresultArgs = @('/h', $remoteTempPath, '/f')

                            # Add scope parameter
                            switch ($ScopeParam)
                            {
                                'Computer' { $gpresultArgs += '/scope:computer' }
                                'User' { $gpresultArgs += '/scope:user' }
                                'Both' { }  # Default behavior
                            }

                            # Add user parameter if specified
                            if ($UserNameParam -and ($ScopeParam -eq 'User' -or $ScopeParam -eq 'Both'))
                            {
                                $gpresultArgs += '/user'
                                $gpresultArgs += $UserNameParam
                            }

                            # Execute gpresult
                            $process = Start-Process -FilePath 'gpresult.exe' `
                                -ArgumentList $gpresultArgs `
                                -Wait `
                                -NoNewWindow `
                                -PassThru

                            if ($process.ExitCode -ne 0)
                            {
                                throw "gpresult.exe failed with exit code $($process.ExitCode)"
                            }

                            if (-not (Test-Path -Path $remoteTempPath))
                            {
                                throw "Report file was not created at $remoteTempPath"
                            }

                            return $remoteTempPath
                        }

                        $remotePath = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $scopeValue, $user

                        if (-not $remotePath)
                        {
                            throw "Failed to generate report on remote computer"
                        }

                        Write-Verbose "Report generated successfully at $remotePath on remote computer"

                        # Copy report to local machine
                        Write-Verbose "Copying report from $computer to $localReportPath..."
                        Copy-Item -FromSession $session -Path $remotePath -Destination $localReportPath -ErrorAction Stop

                        # Verify that the file was successfully copied
                        if (-not (Test-Path -Path $localReportPath))
                        {
                            throw "Failed to copy report file from remote computer. The file does not exist at: $localReportPath"
                        }

                        $fileItem = Get-Item -Path $localReportPath -ErrorAction Stop
                        if ($fileItem.Length -eq 0)
                        {
                            throw "Report file was copied but appears to be empty (0 bytes)"
                        }

                        # Clean up remote file
                        Write-Verbose "Cleaning up remote temporary file..."
                        Invoke-Command -Session $session -ScriptBlock {
                            param($Path)
                            if (Test-Path -Path $Path)
                            {
                                Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
                            }
                        } -ArgumentList $remotePath

                        Write-Host "Report successfully saved to: $localReportPath" -ForegroundColor Green

                        # Open report if requested
                        if ($showReport)
                        {
                            Write-Verbose "Opening report in default browser..."
                            Invoke-Item -Path $localReportPath
                        }

                        # Return report information
                        [PSCustomObject]@{
                            ComputerName = $computer
                            ReportPath   = $localReportPath
                            Scope        = $scopeValue
                            UserName     = if ($user) { $user } else { 'Current User' }
                            Timestamp    = Get-Date
                            FileSize     = $fileItem.Length
                        }
                    }
                    finally
                    {
                        # Always clean up the session
                        if ($session)
                        {
                            Write-Verbose "Closing remote session..."
                            Remove-PSSession -Session @($session) -ErrorAction SilentlyContinue
                        }
                    }
                }
                catch [System.Management.Automation.Remoting.PSRemotingTransportException]
                {
                    Write-Error "Unable to connect to $computer via PowerShell Remoting. Verify that WinRM is enabled and firewall rules allow access."
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-Error "Access denied to $computer. Verify your credentials and permissions."
                }
                catch [System.Exception]
                {
                    Write-Error "Error processing $computer : $($_.Exception.Message)"
                }
            }
        }
        else
        {
            # Sequential processing for PowerShell 5.1 or single computer
            if ($allComputers.Count -eq 1)
            {
                Write-Verbose "Processing single computer sequentially"
            }
            else
            {
                Write-Verbose "Using sequential processing (PowerShell 5.1)"
            }

            foreach ($computer in $allComputers)
            {
                try
                {
                    Write-Verbose "Processing $computer..."

                    # Test remote connectivity
                    if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet))
                    {
                        Write-Error "Unable to reach $computer. Please verify the computer is online and accessible."
                        continue
                    }

                    # Generate timestamped filename if OutputPath not specified
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

                    if (-not $OutputPath)
                    {
                        # No path specified - use current directory with timestamped filename
                        $localReportPath = Join-Path -Path (Get-Location) -ChildPath "GPResult_${computer}_${timestamp}.html"
                    }
                    else
                    {
                        # OutputPath specified - check if it's a directory or file
                        if (Test-Path -Path $OutputPath -PathType Container)
                        {
                            # It's a directory - add timestamped filename
                            $localReportPath = Join-Path -Path $OutputPath -ChildPath "GPResult_${computer}_${timestamp}.html"
                        }
                        elseif ($OutputPath -match '[\\/]$' -or -not [System.IO.Path]::HasExtension($OutputPath))
                        {
                            # Path ends with slash or has no extension - treat as directory
                            # Create directory if it doesn't exist
                            if (-not (Test-Path -Path $OutputPath))
                            {
                                New-Item -Path $OutputPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                            }
                            $localReportPath = Join-Path -Path $OutputPath -ChildPath "GPResult_${computer}_${timestamp}.html"
                        }
                        else
                        {
                            # Treat as full file path
                            $localReportPath = $OutputPath

                            # Ensure parent directory exists
                            $parentDir = Split-Path -Path $OutputPath -Parent
                            if ($parentDir -and -not (Test-Path -Path $parentDir))
                            {
                                New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                            }
                        }
                    }

                    # Create remote session parameters
                    $sessionParams = @{
                        ComputerName = $computer
                        ErrorAction  = 'Stop'
                    }

                    if ($Credential)
                    {
                        $sessionParams.Add('Credential', $Credential)
                    }

                    Write-Verbose "Creating remote session to $computer..."
                    $session = New-PSSession @sessionParams

                    try
                    {
                        # Generate report on remote computer
                        Write-Verbose "Generating Group Policy results report on $computer..."

                        $scriptBlock = {
                            param($ScopeParam, $UserNameParam)

                            $remoteTempPath = Join-Path -Path $env:TEMP -ChildPath "gpresult_temp_$(Get-Random).html"

                            # Build gpresult command
                            $gpresultArgs = @('/h', $remoteTempPath, '/f')

                            # Add scope parameter
                            switch ($ScopeParam)
                            {
                                'Computer' { $gpresultArgs += '/scope:computer' }
                                'User' { $gpresultArgs += '/scope:user' }
                                'Both' { }  # Default behavior
                            }

                            # Add user parameter if specified
                            if ($UserNameParam -and ($ScopeParam -eq 'User' -or $ScopeParam -eq 'Both'))
                            {
                                $gpresultArgs += '/user'
                                $gpresultArgs += $UserNameParam
                            }

                            # Execute gpresult
                            $process = Start-Process -FilePath 'gpresult.exe' `
                                -ArgumentList $gpresultArgs `
                                -Wait `
                                -NoNewWindow `
                                -PassThru

                            if ($process.ExitCode -ne 0)
                            {
                                throw "gpresult.exe failed with exit code $($process.ExitCode)"
                            }

                            if (-not (Test-Path -Path $remoteTempPath))
                            {
                                throw "Report file was not created at $remoteTempPath"
                            }

                            return $remoteTempPath
                        }

                        $remotePath = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $Scope, $UserName

                        if (-not $remotePath)
                        {
                            throw "Failed to generate report on remote computer"
                        }

                        Write-Verbose "Report generated successfully at $remotePath on remote computer"

                        # Copy report to local machine
                        Write-Verbose "Copying report from $computer to $localReportPath..."
                        Copy-Item -FromSession $session -Path $remotePath -Destination $localReportPath -ErrorAction Stop

                        # Verify that the file was successfully copied
                        if (-not (Test-Path -Path $localReportPath))
                        {
                            throw "Failed to copy report file from remote computer. The file does not exist at: $localReportPath"
                        }

                        $fileItem = Get-Item -Path $localReportPath -ErrorAction Stop
                        if ($fileItem.Length -eq 0)
                        {
                            throw "Report file was copied but appears to be empty (0 bytes)"
                        }

                        # Clean up remote file
                        Write-Verbose "Cleaning up remote temporary file..."
                        Invoke-Command -Session $session -ScriptBlock {
                            param($Path)
                            if (Test-Path -Path $Path)
                            {
                                Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
                            }
                        } -ArgumentList $remotePath

                        Write-Host "Report successfully saved to: $localReportPath" -ForegroundColor Green

                        # Open report if requested
                        if ($Show)
                        {
                            Write-Verbose "Opening report in default browser..."
                            Invoke-Item -Path $localReportPath
                        }

                        # Return report information
                        [PSCustomObject]@{
                            ComputerName = $computer
                            ReportPath   = $localReportPath
                            Scope        = $Scope
                            UserName     = if ($UserName) { $UserName } else { 'Current User' }
                            Timestamp    = Get-Date
                            FileSize     = $fileItem.Length
                        }
                    }
                    finally
                    {
                        # Always clean up the session
                        if ($session)
                        {
                            Write-Verbose "Closing remote session..."
                            Remove-PSSession -Session @($session) -ErrorAction SilentlyContinue
                        }
                    }
                }
                catch [System.Management.Automation.Remoting.PSRemotingTransportException]
                {
                    Write-Error "Unable to connect to $computer via PowerShell Remoting. Verify that WinRM is enabled and firewall rules allow access."
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-Error "Access denied to $computer. Verify your credentials and permissions."
                }
                catch [System.Exception]
                {
                    Write-Error "Error processing $computer : $($_.Exception.Message)"
                }
            }
        }

        Write-Verbose "Group Policy results retrieval completed"
    }
}
