

function Get-UserLockoutInformation
{
    <#
    .SYNOPSIS
    Get complete lockout information for a user account

    .DESCRIPTION
    Retrieves all lockout information for a user account including:
    - Lockout event details (timestamp, DC, source computer)
    - Lockout reason and failure codes

    .PARAMETER Identity
    User to check (by default all)

    .PARAMETER DC
    Domain controller on which you want to look up information (by default PDC Emulator)

    .PARAMETER Credential
    Administrator credential to connect to the DC

    .EXAMPLE
    Get-UserLockoutInformation -Credential (Get-Credential MyAdminAccount)
    Get complete lockout information for all locked users

    .EXAMPLE
    Get-UserLockoutInformation -Identity User1 -Credential (Get-Credential MyAdminAccount)
    Get complete lockout information for user User1

    .NOTES
    Combines Find-UserLockoutsInformation and Get-UserLockoutReason functionality
#>
    [CmdletBinding(
        DefaultParameterSetName = 'All'
    )]
    param (
        [Parameter(
            ValueFromPipeline = $true,
            ParameterSetName = 'ByUser'
        )]
        [System.String]$Identity,
        [System.String]$DC = (Get-ADDomain).PDCEmulator,
        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    Begin
    {
        Write-Verbose ('[{0:O}] Searching EventID : 4740 on Server : {1}' -f (get-date), $DC)
        $WinEventArguments = @{
            ComputerName    = $DC
            FilterHashtable = @{LogName = 'Security'; Id = 4740 }
        }

        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $WinEventArguments['Credential'] = $Credential
        }

        try {
            $LockedOutEvents = Get-WinEvent @WinEventArguments -ErrorAction Stop | Sort-Object -Property TimeCreated -Descending
        }
        catch {
            if ($Error[-1].Exception.Message -like "*elevated user rights*") {
                throw ('[{0:O}] You need an admin account. Please provide with the -Credential parameter' -f (get-date))
            }
        }

        if ($LockedOutEvents) {
            Write-Verbose ('[{0:O}] {1} event found' -f (get-date), $LockedOutEvents.Count)
        } else {
            throw ('[{0:O}] No event found' -f (get-date))
        }
    }

    Process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            ByUser
            {
                Write-Verbose ('[{0:O}] Searching information for user : {1}' -f (get-date), $Identity)
                $UserInfo = Get-ADUser -Identity $Identity
                Foreach ($Event in $LockedOutEvents)
                {
                    If ($Event | Where-Object { $_.Properties[2].value -match $UserInfo.SID.Value })
                    {
                        $LockoutSource = $Event.Properties[1].Value
                        $LockoutInfo = [PSCustomObject]@{
                            User               = $Event.Properties[0].Value
                            DomainController   = $Event.MachineName
                            EventId            = $Event.Id
                            LockoutTimeStamp   = $Event.TimeCreated
                            Message            = $Event.Message -split "`r" | Select-Object -First 1
                            LockoutSource      = $LockoutSource
                            LockedUserName     = $null
                            LogonType          = $null
                            LogonProcessName   = $null
                            ProcessName        = $null
                            FailureReason      = $null
                            FailureStatus      = $null
                            FailureSubStatus   = $null
                        }

                        # Get lockout reason from source computer
                        try {
                            Write-Verbose ('[{0:O}] Searching lockout reason on {1}' -f (get-date), $LockoutSource)
                            if (Test-Connection -ComputerName $LockoutSource -Quiet -Count 2)
                            {
                                $ReasonWinEventArguments = @{
                                    ComputerName    = $LockoutSource
                                    FilterHashtable = @{LogName = 'Security'; Id = 4625 }
                                }

                                if ($PSBoundParameters.ContainsKey('Credential'))
                                {
                                    $ReasonWinEventArguments['Credential'] = $Credential
                                }

                                $lockoutReasonEvents = Get-WinEvent @ReasonWinEventArguments -ErrorAction Stop

                                if ($lockoutReasonEvents) {
                                    # Get the reason event closest to the lockout timestamp
                                    $reasonEvent = $lockoutReasonEvents | Where-Object {
                                        $xml = [xml]$_.ToXml()
                                        $xml.Event.EventData.Data[5].'#text' -match $Identity
                                    } | Sort-Object -Property TimeCreated -Descending | Select-Object -First 1

                                    if ($reasonEvent) {
                                        $eventXML = [xml]$reasonEvent.ToXml()
                                        $LogonInfo = Import-PSFPowerShellDataFile -Path $PSScriptRoot/PSPowerAdminTasks.psd1

                                        $LockoutInfo.LockedUserName = $eventXML.Event.EventData.Data[5].'#text'
                                        $LockoutInfo.LogonType = $LogonInfo.PrivateData.LogonType."$($eventXML.Event.EventData.Data[10].'#text')"
                                        $LockoutInfo.LogonProcessName = $eventXML.Event.EventData.Data[11].'#text'
                                        $LockoutInfo.ProcessName = $eventXML.Event.EventData.Data[18].'#text'
                                        $LockoutInfo.FailureReason = $LogonInfo.PrivateData.FailureReason."$($eventXML.Event.EventData.Data[8].'#text')"
                                        $LockoutInfo.FailureStatus = $LogonInfo.PrivateData.FailureType."$($eventXML.Event.EventData.Data[7].'#text')"
                                        $LockoutInfo.FailureSubStatus = $LogonInfo.PrivateData.FailureType."$($eventXML.Event.EventData.Data[9].'#text')"
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Verbose ('[{0:O}] Could not retrieve lockout reason: {1}' -f (get-date), $_.Exception.Message)
                        }

                        $LockoutInfo
                    }
                }
            }
            All
            {
                Write-Verbose ('[{0:O}] Searching information for all user(s)' -f (get-date))
                Foreach ($Event in $LockedOutEvents)
                {
                    $LockoutSource = $Event.Properties[1].Value
                    $LockoutInfo = [PSCustomObject]@{
                        User               = $Event.Properties[0].Value
                        DomainController   = $Event.MachineName
                        EventId            = $Event.Id
                        LockoutTimeStamp   = $Event.TimeCreated
                        Message            = $Event.Message -split "`r" | Select-Object -First 1
                        LockoutSource      = $LockoutSource
                        LockedUserName     = $null
                        LogonType          = $null
                        LogonProcessName   = $null
                        ProcessName        = $null
                        FailureReason      = $null
                        FailureStatus      = $null
                        FailureSubStatus   = $null
                    }

                    # Get lockout reason from source computer
                    try {
                        Write-Verbose ('[{0:O}] Searching lockout reason on {1}' -f (get-date), $LockoutSource)
                        if (Test-Connection -ComputerName $LockoutSource -Quiet -Count 2)
                        {
                            $ReasonWinEventArguments = @{
                                ComputerName    = $LockoutSource
                                FilterHashtable = @{LogName = 'Security'; Id = 4625 }
                            }

                            if ($PSBoundParameters.ContainsKey('Credential'))
                            {
                                $ReasonWinEventArguments['Credential'] = $Credential
                            }

                            $lockoutReasonEvents = Get-WinEvent @ReasonWinEventArguments -ErrorAction Stop

                            if ($lockoutReasonEvents) {
                                $reasonEvent = $lockoutReasonEvents | Where-Object {
                                    $xml = [xml]$_.ToXml()
                                    $xml.Event.EventData.Data[5].'#text' -match $Event.Properties[0].Value
                                } | Sort-Object -Property TimeCreated -Descending | Select-Object -First 1

                                if ($reasonEvent) {
                                    $eventXML = [xml]$reasonEvent.ToXml()
                                    $LogonInfo = Import-PSFPowerShellDataFile -Path $PSScriptRoot/PSPowerAdminTasks.psd1

                                    $LockoutInfo.LockedUserName = $eventXML.Event.EventData.Data[5].'#text'
                                    $LockoutInfo.LogonType = $LogonInfo.PrivateData.LogonType."$($eventXML.Event.EventData.Data[10].'#text')"
                                    $LockoutInfo.LogonProcessName = $eventXML.Event.EventData.Data[11].'#text'
                                    $LockoutInfo.ProcessName = $eventXML.Event.EventData.Data[18].'#text'
                                    $LockoutInfo.FailureReason = $LogonInfo.PrivateData.FailureReason."$($eventXML.Event.EventData.Data[8].'#text')"
                                    $LockoutInfo.FailureStatus = $LogonInfo.PrivateData.FailureType."$($eventXML.Event.EventData.Data[7].'#text')"
                                    $LockoutInfo.FailureSubStatus = $LogonInfo.PrivateData.FailureType."$($eventXML.Event.EventData.Data[9].'#text')"
                                }
                            }
                        }
                    }
                    catch {
                        Write-Verbose ('[{0:O}] Could not retrieve lockout reason: {1}' -f (get-date), $_.Exception.Message)
                    }

                    $LockoutInfo
                }
            }
        }
    }
    End
    {
    }
}
