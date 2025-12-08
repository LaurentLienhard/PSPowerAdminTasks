function Set-RemoteDnsServer
{
    <#
    .SYNOPSIS
        Configures DNS servers on one or more remote computers (compatible Server 2008+).
    .DESCRIPTION
        This function allows either completely replacing the DNS server list or replacing a specific DNS address with a new one on the active network adapters of target computers.
        It automatically detects which method to use (modern or WMI) based on the remote operating system.
    .PARAMETER ComputerName
        The name or list of names of computers to target.
    .PARAMETER ServerAddresses
        (ParameterSet 'All') One or more IP addresses of DNS servers to replace the existing configuration.
    .PARAMETER OldAddress
        (ParameterSet 'Replace') The IP address of the DNS server to replace.
    .PARAMETER NewAddress
        (ParameterSet 'Replace') The new IP address of the DNS server that will replace the old one.
    .PARAMETER Credential
        Specifies the credentials to use when connecting to remote computers.
    .EXAMPLE
        # Replace all DNS on PC01 (modern) and SRV2008 (legacy) with Google's servers.
        Set-RemoteDnsServer -ComputerName "PC01", "SRV2008" -ServerAddresses "8.8.8.8", "8.8.4.4"

    .EXAMPLE
        # On SRV2008, replace the old DNS 192.168.1.1 with the new 1.1.1.1.
        Set-RemoteDnsServer -ComputerName "SRV2008" -OldAddress "192.168.1.1" -NewAddress "1.1.1.1"
    #>
    [CmdletBinding(DefaultParameterSetName = "All")]
    param
    (
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

    # Process each provided computer
    foreach ($computer in $ComputerName)
    {
        Write-Verbose "Attempting to connect to $computer..."
        $Parameters = @{}
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $Parameters['Credential'] = $Credential
        }

        try
        {
            # The ScriptBlock now contains both logic paths (modern and legacy)
            $ScriptBlock = {
                # $using: allows using local variables in the remote session

                # Detect if modern cmdlets (NetAdapter) are available
                $modernCmdletsAvailable = Get-Command -Name 'Get-NetAdapter' -ErrorAction SilentlyContinue

                if ($modernCmdletsAvailable)
                {
                    Write-Verbose "[$($env:COMPUTERNAME)] Modern method (NetAdapter) detected."
                    # ===================================================
                    # MODERN LOGIC (Windows 8 / Server 2012 and later)
                    # ===================================================
                    $interfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
                    if (-not $interfaces)
                    {
                        Write-Warning "[$($env:COMPUTERNAME)] No active network adapters found."
                        return
                    }

                    switch ($using:PSCmdlet.ParameterSetName)
                    {
                        "All"
                        {
                            foreach ($interface in $interfaces)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] Setting DNS on interface '$($interface.Name)'..."
                                $interface | Set-DnsClientServerAddress -ServerAddresses $using:ServerAddresses -ErrorAction Stop
                            }
                        }
                        "Replace"
                        {
                            foreach ($interface in $interfaces)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] Processing interface '$($interface.Name)'..."
                                $currentDnsServers = (Get-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -AddressFamily IPv4).ServerAddresses

                                if ($currentDnsServers -contains $using:OldAddress)
                                {
                                    $newDnsServers = $currentDnsServers | ForEach-Object { if ($_ -eq $using:OldAddress) { $using:NewAddress } else { $_ } }
                                    Write-Verbose "[$($env:COMPUTERNAME)] Replacing '$($using:OldAddress)' with '$($using:NewAddress)'. New list: $($newDnsServers -join ', ')"
                                    $interface | Set-DnsClientServerAddress -ServerAddresses $newDnsServers -ErrorAction Stop
                                }
                                else
                                {
                                    Write-Warning "[$($env:COMPUTERNAME)] Address '$($using:OldAddress)' was not found on interface '$($interface.Name)'."
                                }
                            }
                        }
                    }
                }
                else
                {
                    Write-Verbose "[$($env:COMPUTERNAME)] WMI method (legacy) used."
                    # ===================================================
                    # LEGACY LOGIC (WMI for Windows 7 / Server 2008)
                    # ===================================================
                    # Filter on adapters that have active IP configuration
                    $adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'"
                    if (-not $adapters)
                    {
                        Write-Warning "[$($env:COMPUTERNAME)] No network adapters with enabled IP found via WMI."
                        return
                    }

                    switch ($using:PSCmdlet.ParameterSetName)
                    {
                        "All"
                        {
                            foreach ($adapter in $adapters)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] [WMI] Setting DNS on interface '$($adapter.Description)'..."
                                $result = $adapter.SetDNSServerSearchOrder($using:ServerAddresses)
                                if ($result.ReturnValue -ne 0) { Write-Warning "A WMI error occurred (Code: $($result.ReturnValue))" }
                            }
                        }
                        "Replace"
                        {
                            foreach ($adapter in $adapters)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] [WMI] Processing interface '$($adapter.Description)'..."
                                $currentDnsServers = $adapter.DNSServerSearchOrder

                                if ($currentDnsServers -contains $using:OldAddress)
                                {
                                    $newDnsServers = $currentDnsServers | ForEach-Object { if ($_ -eq $using:OldAddress) { $using:NewAddress } else { $_ } }
                                    Write-Verbose "[$($env:COMPUTERNAME)] [WMI] Replacing '$($using:OldAddress)' with '$($using:NewAddress)'. New list: $($newDnsServers -join ', ')"
                                    $result = $adapter.SetDNSServerSearchOrder($newDnsServers)
                                    if ($result.ReturnValue -ne 0) { Write-Warning "A WMI error occurred (Code: $($result.ReturnValue))" }
                                }
                                else
                                {
                                    Write-Warning "[$($env:COMPUTERNAME)] [WMI] Address '$($using:OldAddress)' was not found on interface '$($adapter.Description)'."
                                }
                            }
                        }
                    }
                }
            }

            Invoke-Command -ComputerName $computer @Parameters -ErrorAction Stop -ScriptBlock $ScriptBlock
            Write-Verbose "DNS operation completed successfully on $computer."
        }
        catch
        {
            Write-Warning "Failed to update DNS on $computer. Error: $($_.Exception.Message)"
        }
    }
}
