function Get-RemoteDnsServer
{
    <#
        .SYNOPSIS
            Retrieves DNS server configuration from remote computers.

        .DESCRIPTION
            This function retrieves DNS server configuration from remote computers using the COMPUTER class.
            It validates computer existence in Active Directory and returns DNS servers and IPv4 address information.
            Optimized for PowerShell 7+ with parallel processing support for multiple computers.

        .PARAMETER ComputerName
            Specifies the target computer name or names. Accepts pipeline input.

        .PARAMETER Credential
            Specifies the credentials to use for the connection.

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            Only applicable when processing 10+ computers on PowerShell 7+.

        .PARAMETER TimeoutSeconds
            Timeout in seconds for connection tests. Default is 2 seconds.

        .EXAMPLE
            Get-RemoteDnsServer -ComputerName Server01

        .EXAMPLE
            Get-RemoteDnsServer -ComputerName Server01, Server02 -Credential (Get-Credential)

        .EXAMPLE
            Get-RemoteDnsServer -ComputerName (Get-Content servers.txt) -ThrottleLimit 64

        .NOTES
            This function is part of the PSPowerAdminTasks module.
            For 10+ computers, PowerShell 7+ uses parallel processing automatically.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32,

        [Parameter()]
        [ValidateRange(1, 30)]
        [int]$TimeoutSeconds = 2
    )

    BEGIN
    {
        # Detect PowerShell version for parallel processing capability
        $useParallel = ($PSVersionTable.PSVersion.Major -ge 7) -and ($PSBoundParameters.ContainsKey('ComputerName')) -and ($ComputerName.Count -ge 10)

        if (-not $useParallel -and ($PSVersionTable.PSVersion.Major -lt 7) -and ($ComputerName.Count -ge 10))
        {
            Write-Verbose "Running on PowerShell 5.1 with 10+ computers. Consider upgrading to PowerShell 7+ for parallel processing."
        }

        Write-Verbose "Processing $($ComputerName.Count) computers. Parallel: $useParallel, ThrottleLimit: $ThrottleLimit"
    }

    PROCESS
    {
        if ($useParallel)
        {
            # PowerShell 7+ - Parallel processing
            $ComputerName | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                $computer = $_
                $Credential = $using:Credential
                $TimeoutSeconds = $using:TimeoutSeconds

                try
                {
                    Write-Verbose "Processing $computer via COMPUTER class (parallel)..."

                    # Quick connectivity test first
                    if (-not (Test-Connection -ComputerName $computer -Count 1 -TimeoutSeconds $TimeoutSeconds -ErrorAction SilentlyContinue))
                    {
                        Write-Verbose "Skipping $computer - offline"
                        return
                    }

                    if ($Credential)
                    {
                        $srvObject = [COMPUTER]::new($computer, $Credential)
                    }
                    else
                    {
                        $srvObject = [COMPUTER]::new($computer)
                    }

                    $srvObject.TestIfComputerExistInAd() | Out-Null
                    $srvObject.GetDnsConfig()

                    [PSCustomObject]@{
                        ComputerName = $srvObject.Name
                        IPv4Address  = $srvObject.IPv4Address
                        DNSServers   = $srvObject.DnsServers
                    }
                }
                catch
                {
                    Write-Verbose "Error processing $computer : $($_.Exception.Message)"
                }
            } | Where-Object { $null -ne $_ }
        }
        else
        {
            # Fallback - Sequential processing for PS 5.1 or small counts
            $results = [System.Collections.Generic.List[PSObject]]::new()

            foreach ($computer in $ComputerName)
            {
                try
                {
                    Write-Verbose "Processing $computer via COMPUTER class..."

                    if ($PSBoundParameters.ContainsKey('Credential'))
                    {
                        $srvObject = [COMPUTER]::new($computer, $Credential)
                    }
                    else
                    {
                        $srvObject = [COMPUTER]::new($computer)
                    }

                    $srvObject.TestIfComputerExistInAd() | Out-Null
                    $srvObject.GetDnsConfig()

                    $resultObj = [PSCustomObject]@{
                        ComputerName = $srvObject.Name
                        IPv4Address  = $srvObject.IPv4Address
                        DNSServers   = $srvObject.DnsServers
                    }

                    $results.Add($resultObj)
                }
                catch
                {
                    Write-Warning "Fatal error processing $computer : $($_.Exception.Message)"
                }
            }

            return $results
        }
    }

    END
    {
    }
}
