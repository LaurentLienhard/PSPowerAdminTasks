function Set-RemoteDnsServer
{
    <#
    .SYNOPSIS
        Sets or replaces DNS server addresses on remote computers.

    .DESCRIPTION
        This function sets or replaces DNS server configuration on remote computers using the COMPUTER class.
        It supports two modes: set all DNS servers or replace a specific address.

    .PARAMETER ComputerName
        Specifies the target computer name or names.

    .PARAMETER ServerAddresses
        List of DNS server IP addresses to set (Parameter Set: All).

    .PARAMETER OldAddress
        DNS IP address to replace (Parameter Set: Replace).

    .PARAMETER NewAddress
        New DNS IP address (Parameter Set: Replace).

    .PARAMETER Credential
        Specifies the credentials to use for the connection.

    .EXAMPLE
        Set-RemoteDnsServer -ComputerName "SERVER01" -ServerAddresses "8.8.8.8","8.8.4.4"

    .EXAMPLE
        Set-RemoteDnsServer -ComputerName "SERVER01" -OldAddress "1.1.1.1" -NewAddress "8.8.8.8"

    .NOTES
        This function is part of the PSPowerAdminTasks module.
    #>
    [CmdletBinding(DefaultParameterSetName = "All")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [string[]]$ServerAddresses,

        [Parameter(Mandatory = $true, ParameterSetName = "Replace")]
        [string]$OldAddress,

        [Parameter(Mandatory = $true, ParameterSetName = "Replace")]
        [string]$NewAddress,

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

            $reportItem = $null

            try
            {
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $srvObject = [COMPUTER]::new($computer, $Credential)
                }
                else {
                    $srvObject = [COMPUTER]::new($computer)
                }

                if ($srvObject.Status -ne "Ping OK") {
                    $reportItem = [PSCustomObject]@{
                        ComputerName = $computer
                        Action       = "None"
                        Result       = "Unreachable"
                        NewDNS       = $null
                    }
                    $AllResults.Add($reportItem)
                    continue
                }

                switch ($PSCmdlet.ParameterSetName)
                {
                    "All" {
                        $srvObject.SetDnsServers($ServerAddresses)
                        $actionLog = "Set-All"
                    }

                    "Replace" {
                        $srvObject.ModifyDnsServer($OldAddress, $NewAddress)
                        $actionLog = "Replace ($OldAddress -> $NewAddress)"
                    }
                }

                $reportItem = [PSCustomObject]@{
                    ComputerName = $srvObject.Name
                    Action       = $actionLog
                    Result       = "Success"
                    NewDNS       = $srvObject.DnsServers
                }
            }
            catch
            {
                $reportItem = [PSCustomObject]@{
                    ComputerName = $computer
                    Action       = "Error"
                    Result       = $_.Exception.Message
                    NewDNS       = $null
                }
            }

            if ($reportItem) { $AllResults.Add($reportItem) }
        }
    }

    END
    {
        return $AllResults
    }
}
