function Start-RebootServerBygroup
{
    <#
    .SYNOPSIS
        Reboots servers in a WSUS group matching specific operating system versions.

    .DESCRIPTION
        This function retrieves all servers from a specified WSUS Active Directory group,
        filters them for Windows Server 2003, 2008, or 2012, and remotely reboots them.
        Optionally logs the reboot activity to a file.

    .PARAMETER WSUSGroupName
        The name of the WSUS Active Directory group containing servers to reboot.
        This parameter is dynamic and populated from AD groups matching the pattern "WSUS*".
        Mandatory parameter.

    .PARAMETER Log
        Switch parameter. When specified, logs reboot activities to a file at
        C:\rundeck\<WSUSGroupName>.log.

    .EXAMPLE
        Start-RebootServerBygroup -WSUSGroupName "WSUS-WebServers"

        Reboots all eligible servers in the WSUS-WebServers AD group without logging.

    .EXAMPLE
        Start-RebootServerBygroup -WSUSGroupName "WSUS-DatabaseServers" -Log

        Reboots all eligible servers in the WSUS-DatabaseServers AD group and logs
        the activity to C:\rundeck\WSUS-DatabaseServers.log.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$log
    )

    DynamicParam
    {
        # Set the dynamic parameters' name
        $ParameterName = 'WSUSGroupName'

        # Create the dictionary
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 1

        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        # Generate and set the ValidateSet
        $arrSet = Get-ADGroup -Filter { name -like "WSUS*" } | Select-Object -ExpandProperty Name
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)

        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin
    {
        $WSUSGroupName = $PSBoundParameters['WSUSGroupName']
        $LogPath = if ($log) { "C:\rundeck\$WSUSGroupName.log" } else { $null }
    }

    process
    {
        # Retrieve members and filter for servers with matching OS versions
        $ServersToReboot = Get-ADGroupMember -Identity $WSUSGroupName |
            ForEach-Object {
                Get-ADComputer -Identity $_.Name -Properties OperatingSystem
            } |
            Where-Object { $_.OperatingSystem -match '2003|2008|2012' } |
            Select-Object -ExpandProperty Name

        # Reboot each server with optional logging
        foreach ($server in $ServersToReboot)
        {
            if ($LogPath)
            {
                Write-Log -LogPath $LogPath -Message "Rebooting $server" -Severity Information
            }
            Restart-Computer -ComputerName $server -Confirm:$false -Force
        }
    }
}
