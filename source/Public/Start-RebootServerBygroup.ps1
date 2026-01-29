<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function Start-RebootServerBygroup
{
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
        if ($log)
        {
            $LogPath = "C:\rundeck\$($WSUSGroupName).log"
        }

    }

    process
    {
        $ServersToReboot = Get-ADGroupMember -Identity $WSUSGroupName | Select-Object -ExpandProperty name | foreach {
            Get-ADComputer -Identity $_ -Properties Name, OperatingSystem
        }
        $ServersToReboot = $ServersToReboot | Where-Object {$_.OperatingSystem -match "2008|2012|2003"} | Select-Object -ExpandProperty Name
        foreach ($server in $ServersToReboot) {
            if ($log)
                {
                    Write-Log -LogPath $LogPath -Message "Rebooting $($server)" -Severity Information
                }
            Restart-Computer -ComputerName $server -Confirm:$false -Force
        }


    }
    end
    {
    }
}
