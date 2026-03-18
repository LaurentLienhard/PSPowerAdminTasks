function Get-LocalAdministratorsRemotly
{
    <#
        .SYNOPSIS
            Retrieves the members of the local Administrators group from one or more remote computers.

        .DESCRIPTION
            This function queries remote computers to retrieve all members of the local Administrators group.
            It supports credential-based authentication and optional logging of results. The function handles
            special cases where SIDs are present in the group membership and provides detailed object information
            including computer name, OS version, member name, object class, and principal source.

        .PARAMETER ComputerName
            The name(s) of the remote computer(s) to query. This parameter accepts an array of computer names
            and is mandatory. The function will connect to each computer to retrieve administrator group members.

        .PARAMETER Credential
            Optional credentials to use when connecting to the remote computer(s). If not specified, the
            current user's credentials will be used for the remote connection.

        .PARAMETER LogPath
            The path where the log file will be saved. Default is $env:Temp/Get-LocalAdministratorsRemotly.log.
            Only used if the log parameter is specified.

        .PARAMETER log
            If specified, logs the results to a CSV file at the path specified by LogPath parameter.
            Default is $false.

        .OUTPUTS
            PSCustomObject[] with the following properties:
            - ComputerName: The name of the remote computer
            - OSVersion: The operating system version of the remote computer
            - Member: The name of the local administrator
            - ObjectClass: The object class of the member (e.g., User, Group)
            - PrincipalSource: The source of the principal (e.g., Local, ActiveDirectory)

        .EXAMPLE
            Get-LocalAdministratorsRemotly -ComputerName 'SERVER01'

            Retrieves all local administrators from SERVER01 using the current user's credentials.

        .EXAMPLE
            Get-LocalAdministratorsRemotly -ComputerName 'SERVER01', 'SERVER02', 'SERVER03' -Credential $cred

            Retrieves local administrators from multiple servers using the specified credentials.

        .EXAMPLE
            Get-LocalAdministratorsRemotly -ComputerName 'SERVER01' -log

            Retrieves local administrators and logs the results to C:\rundeck\Get-LocalAdministratorsRemotly.csv.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String[]]$ComputerName,
        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,
        [Parameter()]
        [System.String]$LogPath = "$env:Temp/Get-LocalAdministratorsRemotly.log",
        [Parameter()]
        [switch]$log
    )

    begin
    {
        Write-Verbose "Starting Get-LocalAdministratorsRemotly"
    }

    process
    {
        $FinalResult = @()
        $Parameter = @{}
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $Parameter['Credential'] = $Credential
        }
        foreach ($Comp in $ComputerName)
        {
            try
            {
                $Parameter['ComputerName'] = $Comp
                if ($log)
                {
                    Write-Log -LogPath $LogPath -Message "Start Scanning $($Comp)" -Severity Information
                }
                $result = Invoke-Command @Parameter -ErrorAction Stop -ScriptBlock {
                    try
                    {
                        # Get the members of the Administrators group using net localgroup
                        $members = net localgroup Administrators
                        # Filter out lines that contain SIDs
                        $sids = $members | Select-String -Pattern "S-1-5-"

                        # Check if any SIDs were found
                        if ($sids)
                        {
                            [PSCustomObject]@{
                                ComputerName    = $comp
                                OSVersion       = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty  Caption
                                Member          = $_.Line
                                ObjectClass     = ""
                                PrincipalSource = ""
                            }
                            #Write-Output "SIDs found in the Administrators group:"
                            #$sids | ForEach-Object { Write-Output $_.Line }
                        }
                        else
                        {
                            $Members = Get-LocalGroupMember -Group Administrators -ErrorAction Stop
                            ForEach ($Member in $Members)
                            {
                                [PSCustomObject]@{
                                    ComputerName    = $env:COMPUTERNAME
                                    OSVersion       = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty  Caption
                                    Member          = $Member.Name
                                    ObjectClass     = $Member.ObjectClass
                                    PrincipalSource = $Member.PrincipalSource
                                }
                            }
                        }
                    }
                    catch
                    {
                        [PSCustomObject]@{
                            ComputerName    = $env:COMPUTERNAME
                            OSVersion       = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty  Caption
                            Member          = ""
                            ObjectClass     = ""
                            PrincipalSource = ""
                        }
                    }

                }
            }
            catch
            {
                Write-Output ('[{0:O}] ErrorID: {1}' -f (get-date), $_.Exception.Message)
                Write-Output ('[{0:O}] Exception: {1}' -f (get-date), $_.FullyQualifiedErrorId)
                Write-Output ('[{0:O}] Category: {1}' -f (get-date), (($_.Exception.GetType() | Select-Object -ExpandProperty UnderlyingSystemType).FullName))
                [PSCustomObject]@{
                    ComputerName    = $comp
                    OSVersion       = ""
                    Member          = ""
                    ObjectClass     = ""
                    PrincipalSource = ""
                }

            }
            if ($log)
            {
                if ($result.Member -ne "")
                {
                    foreach ($res in $result)
                    {
                        Write-Log -LogPath $LogPath -Message $res.Member -Severity Information
                    }
                } else {
                    Write-Log -LogPath $LogPath -Message "No members found on $($result.PSComputername) OS: $($result.OSVersion)" -Severity Error
                }
            }
            $FinalResult += $result
        }

    }

    end
    {
        return $FinalResult
    }
}
