function Get-LocalAdministratorsRemotly
{
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
        [switch]$log
    )

    begin
    {
        if ($log)
        {
            $LogPath = 'C:\rundeck\Get-LocalAdministratorsRemotly.csv'
        }

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
