function Get-RemoteDhcpScopes
{
    <#
        .SYNOPSIS
            Retrieves DHCP scopes, statistics, and options from remote servers.

        .DESCRIPTION
            Connects to the specified DHCP server(s) via WinRM to list IPv4 scopes.
            For each scope, it retrieves:
            - IP Configuration (Range, Subnet Mask)
            - Usage Statistics (Free/Used IPs)
            - Main Options (3=Router, 6=DNS, 15=Domain)
            Optimized for PowerShell 7+ with parallel processing for multiple servers.

        .PARAMETER ComputerName
            The target DHCP server name(s). Accepts pipeline input and multiple values.

        .PARAMETER Credential
            Credentials to use for the remote connection.

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            Only applicable when processing 10+ computers on PowerShell 7+.

        .EXAMPLE
            Get-RemoteDhcpScopes -ComputerName Server01

        .EXAMPLE
            Get-RemoteDhcpScopes -ComputerName Server01, Server02, Server03 -ThrottleLimit 32

        .EXAMPLE
            Get-RemoteDhcpScopes -ComputerName (Get-Content dhcp-servers.txt) -ThrottleLimit 64

        .NOTES
            This function is part of the PSPowerAdminTasks module.
            Requires DHCP role to be installed on target servers.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32
    )

    BEGIN
    {
        # Detect PowerShell version for parallel processing capability
        $useParallel = ($PSVersionTable.PSVersion.Major -ge 7) -and ($ComputerName.Count -ge 10)

        if (-not $useParallel -and ($PSVersionTable.PSVersion.Major -lt 7) -and ($ComputerName.Count -ge 10))
        {
            Write-Verbose "Running on PowerShell 5.1 with 10+ servers. Consider upgrading to PowerShell 7+ for parallel processing."
        }

        Write-Verbose "Processing $($ComputerName.Count) DHCP server(s). Parallel: $useParallel, ThrottleLimit: $ThrottleLimit"

        # Script block for remote execution
        $remoteScriptBlock = {
            try
            {
                $scopes = Get-DhcpServerv4Scope -ErrorAction Stop
            }
            catch
            {
                Write-Error "Unable to list scopes. Verify that the DHCP role is installed on $env:COMPUTERNAME."
                return
            }

            $results = foreach ($scope in $scopes)
            {
                $stats = Get-DhcpServerv4ScopeStatistics -ScopeId $scope.ScopeId
                $allOptions = Get-DhcpServerv4OptionValue -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue

                $optRouter = ($allOptions | Where-Object { $_.OptionId -eq 3 }).Value -join ', '
                $optDNS = ($allOptions | Where-Object { $_.OptionId -eq 6 }).Value -join ', '
                $optDomain = ($allOptions | Where-Object { $_.OptionId -eq 15 }).Value -join ', '
                $otherOptionsIDs = ($allOptions | Where-Object { $_.OptionId -notin 3, 6, 15 }).OptionId -join ', '

                [PSCustomObject]@{
                    ScopeID     = $scope.ScopeId.IPAddressToString
                    Name        = $scope.Name
                    State       = $scope.State
                    SubnetMask  = $scope.SubnetMask.IPAddressToString
                    StartRange  = $scope.StartRange.IPAddressToString
                    EndRange    = $scope.EndRange.IPAddressToString
                    Router      = if ($optRouter) { $optRouter } else { "N/A" }
                    DNS         = if ($optDNS) { $optDNS } else { "N/A" }
                    Domain      = if ($optDomain) { $optDomain } else { "N/A" }
                    OtherOptIDs = if ($otherOptionsIDs) { $otherOptionsIDs } else { "-" }
                    InUse       = $stats.InUse
                    Free        = $stats.Free
                    Percentage  = "{0:N0}%" -f $stats.PercentageInUse
                }
            }
            return $results
        }
    }

    PROCESS
    {
        if ($useParallel)
        {
            # PowerShell 7+ - Parallel processing
            Write-Verbose "Processing $($ComputerName.Count) servers in parallel..."

            $ComputerName | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                $computer = $_
                $cred = $using:Credential
                $scriptBlock = $using:remoteScriptBlock

                try
                {
                    Write-Verbose "Connecting to DHCP server $computer..."

                    $icParams = @{
                        ComputerName = $computer
                        ErrorAction  = 'Stop'
                        ScriptBlock  = $scriptBlock
                    }

                    if ($cred)
                    {
                        $icParams.Add('Credential', $cred)
                    }

                    $data = Invoke-Command @icParams

                    if ($data)
                    {
                        $data | Select-Object * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
                    }
                    else
                    {
                        Write-Verbose "No DHCP scopes found on $computer."
                    }
                }
                catch
                {
                    Write-Verbose "Connection error to $computer : $($_.Exception.Message)"
                }
            } | Where-Object { $null -ne $_ }
        }
        else
        {
            # Sequential processing for PS 5.1 or small counts
            Write-Verbose "Processing $($ComputerName.Count) server(s) sequentially..."

            foreach ($computer in $ComputerName)
            {
                try
                {
                    Write-Verbose "Connecting to DHCP server $computer..."

                    $icParams = @{
                        ComputerName = $computer
                        ErrorAction  = 'Stop'
                        ScriptBlock  = $remoteScriptBlock
                    }

                    if ($Credential)
                    {
                        $icParams.Add('Credential', $Credential)
                    }

                    $data = Invoke-Command @icParams

                    if ($data)
                    {
                        $data | Select-Object * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
                    }
                    else
                    {
                        Write-Warning "No DHCP scopes found on $computer."
                    }
                }
                catch
                {
                    Write-Error "Connection error to $computer : $($_.Exception.Message)"
                }
            }
        }
    }
}
