function Get-IPVersion
{
    <#
        .SYNOPSIS
            Determines if an IP address or subnet is IPv4 or IPv6.

        .DESCRIPTION
            This function parses an IP address or subnet in CIDR notation
            and returns whether it is IPv4 or IPv6.

        .PARAMETER IPAddressOrSubnet
            The IP address or subnet in CIDR notation to analyze.

        .EXAMPLE
            Get-IPVersion -IPAddressOrSubnet "10.0.0.0/8"
            # Returns "IPv4"

            Get-IPVersion -IPAddressOrSubnet "2001:db8::/32"
            # Returns "IPv6"

        .NOTES
            This function is part of the PSPowerAdminTasks module.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddressOrSubnet
    )

    try
    {
        # Extract IP address from CIDR notation if present
        $ipPart = $IPAddressOrSubnet -split '/' | Select-Object -First 1
        $ip = [System.Net.IPAddress]::Parse($ipPart)

        if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork)
        {
            return "IPv4"
        }
        elseif ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6)
        {
            return "IPv6"
        }
        else
        {
            return "Unknown"
        }
    }
    catch
    {
        return "Invalid"
    }
}
