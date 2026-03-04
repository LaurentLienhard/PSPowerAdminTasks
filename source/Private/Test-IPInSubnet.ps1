function Test-IPInSubnet
{
    <#
        .SYNOPSIS
            Tests if an IP address belongs to a given subnet.

        .DESCRIPTION
            This function determines if a given IPv4 or IPv6 address belongs to a specified subnet
            provided in CIDR notation (e.g., 10.0.0.0/24).

        .PARAMETER IPAddress
            The IP address to test.

        .PARAMETER Subnet
            The subnet in CIDR notation (e.g., 10.0.0.0/24 or 2001:db8::/32).

        .EXAMPLE
            Test-IPInSubnet -IPAddress "10.0.0.5" -Subnet "10.0.0.0/24"

            Returns $true if 10.0.0.5 is in the 10.0.0.0/24 subnet.

        .NOTES
            This function is part of the PSPowerAdminTasks module.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $true)]
        [string]$Subnet
    )

    try
    {
        # Parse the IP address and subnet
        $ip = [System.Net.IPAddress]::Parse($IPAddress)
        $subnetParts = $Subnet -split '/'

        if ($subnetParts.Count -ne 2)
        {
            Write-Warning "Invalid subnet format: $Subnet. Expected CIDR notation (e.g., 10.0.0.0/24)"
            return $false
        }

        $subnetAddress = [System.Net.IPAddress]::Parse($subnetParts[0])
        $prefixLength = [int]$subnetParts[1]

        # Validate address type consistency
        if ($ip.AddressFamily -ne $subnetAddress.AddressFamily)
        {
            Write-Warning "IP address and subnet have different address families (IPv4 vs IPv6)"
            return $false
        }

        # Handle IPv4
        if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork)
        {
            if ($prefixLength -lt 0 -or $prefixLength -gt 32)
            {
                Write-Warning "Invalid IPv4 prefix length: $prefixLength (must be 0-32)"
                return $false
            }

            # Convert IP addresses to 32-bit integers
            $ipBytes = $ip.GetAddressBytes()
            $subnetBytes = $subnetAddress.GetAddressBytes()

            [Array]::Reverse($ipBytes)
            [Array]::Reverse($subnetBytes)

            $ipInt = [System.BitConverter]::ToUInt32($ipBytes, 0)
            $subnetInt = [System.BitConverter]::ToUInt32($subnetBytes, 0)

            # Create mask
            $mask = if ($prefixLength -eq 0) { 0 } else { [uint32]([uint32]::MaxValue -shl (32 - $prefixLength)) }

            # Check if IP is in subnet
            return ($ipInt -band $mask) -eq ($subnetInt -band $mask)
        }

        # Handle IPv6
        if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6)
        {
            if ($prefixLength -lt 0 -or $prefixLength -gt 128)
            {
                Write-Warning "Invalid IPv6 prefix length: $prefixLength (must be 0-128)"
                return $false
            }

            # Get address bytes
            $ipBytes = $ip.GetAddressBytes()
            $subnetBytes = $subnetAddress.GetAddressBytes()

            # Compare bytes up to prefix length
            $byteCount = [Math]::Floor($prefixLength / 8)
            $bitCount = $prefixLength % 8

            # Check complete bytes
            for ($i = 0; $i -lt $byteCount; $i++)
            {
                if ($ipBytes[$i] -ne $subnetBytes[$i])
                {
                    return $false
                }
            }

            # Check remaining bits
            if ($bitCount -gt 0)
            {
                $mask = [byte]([byte]255 -shl (8 - $bitCount))
                if (($ipBytes[$byteCount] -band $mask) -ne ($subnetBytes[$byteCount] -band $mask))
                {
                    return $false
                }
            }

            return $true
        }

        return $false
    }
    catch
    {
        Write-Warning "Error testing IP in subnet: $($_.Exception.Message)"
        return $false
    }
}
