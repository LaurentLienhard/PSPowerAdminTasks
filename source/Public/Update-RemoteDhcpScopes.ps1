function Update-RemoteDhcpScopes
{
    <#
    .SYNOPSIS
        Remotely updates DHCP Scope options for one or multiple scopes.

    .DESCRIPTION
        This function connects via WinRM. It allows overwriting the DNS list or
        replacing a specific IP within the existing list.

    .PARAMETER ScopeId
        One or more IPv4 addresses of the DHCP scopes.

    .PARAMETER DnsServers
        The new complete list of DNS server IPs (Overwrites existing).

    .PARAMETER ReplaceDns
        The specific DNS IP you want to find and replace.

    .PARAMETER WithDns
        The new DNS IP to put in place of the one found in -ReplaceDns.

    .PARAMETER ComputerName
        The hostname or FQDN of the remote DHCP server.

    .PARAMETER Credential
        The credentials required to access the remote server.

    .EXAMPLE
        Update-RemoteDhcpScopes -ScopeId "10.104.0.0" -ReplaceDns "10.152.3.15" -WithDns "10.100.152.4" -ComputerName "dsddhcp02" -Credential $creds -Verbose
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ScopeId,

        [Parameter(ParameterSetName = "Overwrite")]
        [string[]]$DnsServers,

        [Parameter(ParameterSetName = "Replace", Mandatory = $true)]
        [string]$ReplaceDns,

        [Parameter(ParameterSetName = "Replace", Mandatory = $true)]
        [string]$WithDns,

        [Parameter(Mandatory = $false)]
        [string]$DomainName,

        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    process
    {
        $Session = $null
        try
        {
            # 1. Establish Session
            if ($PSCmdlet.ShouldProcess($ComputerName, "Connect to DHCP Server"))
            {
                Write-Verbose "Connecting to $ComputerName via WinRM..."
                $SessionOption = New-CimSessionOption -Protocol WsMan
                $Session = New-CimSession -ComputerName $ComputerName -Credential $Credential -SessionOption $SessionOption
            }

            foreach ($CurrentScope in $ScopeId)
            {
                $FinalDnsList = $null
                $Target = "Scope $CurrentScope on $ComputerName"

                # MODE: REPLACE
                if ($PSCmdlet.ParameterSetName -eq "Replace")
                {
                    if ($null -ne $Session)
                    {
                        Write-Verbose "[$CurrentScope] Fetching current DNS servers (Option 6)..."
                        $OptionData = Get-DhcpServerv4OptionValue -CimSession $Session -ScopeId $CurrentScope -OptionId 6 -ErrorAction SilentlyContinue

                        # Extract IPs from the Value property
                        $CurrentIPs = @($OptionData.Value)
                        Write-Verbose "[$CurrentScope] Found current DNS: $($CurrentIPs -join ', ')"

                        if ($CurrentIPs -contains $ReplaceDns)
                        {
                            $FinalDnsList = foreach ($ip in $CurrentIPs)
                            {
                                if ($ip -eq $ReplaceDns)
                                {
                                    $WithDns
                                }
                                else
                                {
                                    $ip
                                }
                            }
                            $Msg = "Replace $ReplaceDns with $WithDns (New list: $($FinalDnsList -join ', '))"
                        }
                        else
                        {
                            Write-Warning "[$CurrentScope] IP $ReplaceDns not found in: $($CurrentIPs -join ', ')"
                            continue
                        }
                    }
                    else
                    {
                        $Msg = "Replace $ReplaceDns with $WithDns (Simulation)"
                    }
                }
                # MODE: OVERWRITE
                else
                {
                    $FinalDnsList = $DnsServers
                    $Msg = "Overwrite with $($DnsServers -join ', ')"
                }

                # 2. Perform the Update
                if ($PSCmdlet.ShouldProcess($Target, $Msg))
                {
                    if ($null -ne $FinalDnsList -and $null -ne $Session)
                    {
                        Set-DhcpServerv4OptionValue -CimSession $Session -ScopeId $CurrentScope -OptionId 6 -Value $FinalDnsList
                        Write-Verbose "[$CurrentScope] Successfully updated DNS servers."
                    }
                }

                # 3. Handle Domain Name (Option 15)
                if ($DomainName -and $PSCmdlet.ShouldProcess($Target, "Set Domain Name to $DomainName"))
                {
                    if ($null -ne $Session)
                    {
                        Set-DhcpServerv4OptionValue -CimSession $Session -ScopeId $CurrentScope -OptionId 15 -Value $DomainName
                        Write-Verbose "[$CurrentScope] Domain Name updated."
                    }
                }
            }
        }
        catch
        {
            Write-Error "Failed to process $($ComputerName). Details: $($_.Exception.Message)"
        }
        finally
        {
            if ($null -ne $Session)
            {
                Write-Verbose "Closing session."
                $Session | Remove-CimSession
            }
        }
    }
}
