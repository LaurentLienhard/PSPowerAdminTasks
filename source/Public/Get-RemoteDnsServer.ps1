function Get-RemoteDnsServer
{
    <#
    .SYNOPSIS
        Retrieves DNS server configuration from remote computers.

    .DESCRIPTION
        This function retrieves DNS server configuration from remote computers using the COMPUTER class.
        It validates computer existence in Active Directory and returns DNS servers and IPv4 address information.

    .PARAMETER ComputerName
        Specifies the target computer name or names.

    .PARAMETER Credential
        Specifies the credentials to use for the connection.

    .EXAMPLE
        Get-RemoteDnsServer -ComputerName Server01

    .EXAMPLE
        Get-RemoteDnsServer -ComputerName Server01, Server02 -Credential (Get-Credential)

    .NOTES
        This function is part of the PSPowerAdminTasks module.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        $AllResults = [System.Collections.Generic.List[PSObject]]::new()
    }

    PROCESS
    {
        foreach ($computer in $ComputerName)
        {
            Write-Verbose "Processing $computer via COMPUTER class..."
            try
            {
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $srvObject = [COMPUTER]::new($computer, $Credential)
                }
                else {
                    $srvObject = [COMPUTER]::new($computer)
                }

                $srvObject.TestIfComputerExistInAd() | Out-Null


                $srvObject.GetDnsConfig()

                $resultObj = [PSCustomObject]@{
                    ComputerName = $srvObject.Name
                    IPv4Address  = $srvObject.IPv4Address
                    DNSServers   = $srvObject.DnsServers
                }

                $AllResults.Add($resultObj)
            }
            catch
            {
                Write-Warning "Fatal error processing $computer : $($_.Exception.Message)"
            }
        }
    }

    END
    {
        return $AllResults
    }
}
