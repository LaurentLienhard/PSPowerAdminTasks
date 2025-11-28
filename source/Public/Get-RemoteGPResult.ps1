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
        Default: Current directory with filename "GPResult_<ComputerName>_<Timestamp>.html".

    .PARAMETER Scope
        Scope of the report: 'Computer', 'User', or 'Both'.
        Default: 'Both'.

    .PARAMETER Show
        If specified, opens the HTML report in the default browser after retrieval.

    .PARAMETER UserName
        For 'User' or 'Both' scope, specify the user account to query.
        If not specified, uses the current user on the remote computer.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01"

        Generates a GP results report for SERVER01 and saves it to the current directory.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01" -Show

        Generates a GP results report for SERVER01 and opens it immediately in the browser.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01" -Credential (Get-Credential) -OutputPath "C:\Reports\gpreport.html"

        Generates a report using specific credentials and saves it to a custom location.

    .EXAMPLE
        Get-RemoteGPResult -ComputerName "SERVER01" -Scope User -UserName "domain\jdoe"

        Generates a report for a specific user account on SERVER01.

    .EXAMPLE
        "SERVER01", "SERVER02" | Get-RemoteGPResult -Show

        Generates reports for multiple computers via pipeline and displays each one.
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
        [string]$UserName
    )

    begin
    {
        Write-Verbose "Starting Group Policy results retrieval"
    }

    process
    {
        foreach ($computer in $ComputerName)
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
                if (-not $OutputPath)
                {
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $localReportPath = Join-Path -Path (Get-Location) -ChildPath "GPResult_${computer}_${timestamp}.html"
                }
                else
                {
                    $localReportPath = $OutputPath
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
                        param($Scope, $UserName)

                        $remoteTempPath = Join-Path -Path $env:TEMP -ChildPath "gpresult_temp_$(Get-Random).html"

                        # Build gpresult command
                        $gpresultArgs = @('/h', $remoteTempPath, '/f')

                        # Add scope parameter
                        switch ($Scope)
                        {
                            'Computer' { $gpresultArgs += '/scope:computer' }
                            'User' { $gpresultArgs += '/scope:user' }
                            'Both' { }  # Default behavior
                        }

                        # Add user parameter if specified
                        if ($UserName -and ($Scope -eq 'User' -or $Scope -eq 'Both'))
                        {
                            $gpresultArgs += '/user'
                            $gpresultArgs += $UserName
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
                        FileSize     = (Get-Item -Path $localReportPath).Length
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

    end
    {
        Write-Verbose "Group Policy results retrieval completed"
    }
}
