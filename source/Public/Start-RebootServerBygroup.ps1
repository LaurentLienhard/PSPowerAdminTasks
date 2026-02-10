function Start-RebootServerByGroup {
    <#
    .SYNOPSIS
        Reboots servers in a WSUS group matching specific operating system versions.
    .DESCRIPTION
        This function retrieves all servers from a specified WSUS Active Directory group,
        filters them for Windows Server 2003, 2008, or 2012, and remotely reboots them.
        Includes full support for -WhatIf and -Confirm.
    .PARAMETER Log
        Switch parameter. When specified, logs reboot activities to C:\rundeck\<WSUSGroupName>.log.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter()]
        [switch]$Log
    )

    DynamicParam {
        $ParameterName = 'WSUSGroupName'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 1
        $AttributeCollection.Add($ParameterAttribute)

        # Dynamic population of groups starting with "WSUS"
        $arrSet = Get-ADGroup -Filter { name -like "WSUS*" } | Select-Object -ExpandProperty Name
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)

        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    BEGIN
    {
        $WSUSGroupName = $PSBoundParameters['WSUSGroupName']
        $OSRegex = '2003|2008|2012'

        if ($Log) {
            $LogDir = "C:\rundeck"
            if (-not (Test-Path $LogDir)) {
                New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
            }
            $LogPath = Join-Path $LogDir "$WSUSGroupName.log"
        }
    }

    PROCESS
    {
        Write-Verbose "Fetching members for group: $WSUSGroupName"

        # Filter for computer objects to avoid errors with nested users/groups
        $GroupMembers = Get-ADGroupMember -Identity $WSUSGroupName |
                        Where-Object { $_.objectClass -eq "computer" }

        foreach ($Member in $GroupMembers) {
            $Computer = Get-ADComputer -Identity $Member.distinguishedName -Properties OperatingSystem

            # Check if OS matches the target versions
            if ($Computer.OperatingSystem -match $OSRegex) {

                # ShouldProcess automatically handles -WhatIf and -Confirm
                $StatusMessage = "Rebooting server (OS: $($Computer.OperatingSystem))"
                if ($PSCmdlet.ShouldProcess($Computer.Name, $StatusMessage)) {

                    if ($Log) {
                        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        "$TimeStamp - Initiating reboot for $($Computer.Name) ($($Computer.OperatingSystem))" | Out-File -FilePath $LogPath -Append
                    }

                    try {
                        Restart-Computer -ComputerName $Computer.Name -Force -ErrorAction Stop
                        Write-Host "Successfully sent reboot command to $($Computer.Name)" -ForegroundColor Cyan
                    }
                    catch {
                        $ErrorMsg = "Failed to reboot $($Computer.Name): $($_.Exception.Message)"
                        Write-Warning $ErrorMsg
                        if ($Log) {
                            "$(Get-Date -Format 'HH:mm:ss') - ERROR: $ErrorMsg" | Out-File -FilePath $LogPath -Append
                        }
                    }
                }
            }
            else {
                Write-Verbose "Skipping $($Computer.Name): OS ($($Computer.OperatingSystem)) does not match target list."
            }
        }
    }
}
