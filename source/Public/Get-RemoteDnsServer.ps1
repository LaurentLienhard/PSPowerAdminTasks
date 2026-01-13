<#
.SYNOPSIS
Provides get remotednsserver functionality.

.DESCRIPTION
This function is used for administrative tasks. See Examples for usage.

.PARAMETER ComputerName
Specifies the target computer.

.EXAMPLE
Get-RemoteDnsServer -ComputerName Server01

.NOTES
This function is part of the PSPowerAdminTasks module.
#>
function Get-RemoteDnsServer
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    Begin
    {
        $AllResults = [System.Collections.Generic.List[PSObject]]::new()
    }

    Process
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

    End
    {
        return $AllResults
    }
}
