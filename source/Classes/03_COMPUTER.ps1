class COMPUTER
{
    #region <Properties>
    [System.String]$Name
    [System.DateTime]$CheckTime
    [System.String]$Status
    [System.String]$SamAccountName
    [System.String]$CN
    [System.String]$Operatingsystem
    [System.String]$Description
    [System.String]$IPv4Address
    [System.String]$Created
    [System.String]$LastLogontimestamp
    [System.String]$CanonicalName
    [System.String]$MemberOF
    [System.String]$HotFixDescription
    [System.String]$HotfixID
    [System.String]$HotFixInstalledBy
    [System.String]$HotFixInstalledOn
    [System.String]$LastBootUptime
    [System.String]$RebootNeeded
    HIDDEN [System.Management.Automation.PSCredential]$Credential
    #endregion <Properties>

    #region <Constructor>
    COMPUTER()
    {
    }

    COMPUTER([string]$ComputerName)
    {
        $This.CheckTime = Get-Date
        $this.Name = $ComputerName
        $this.TestIfComputerIsOnline($ComputerName)
    }

    COMPUTER([string]$ComputerName, [System.Management.Automation.PSCredential]$Credential)
    {
        $This.Credential = $Credential
        $this.Name = $ComputerName
        $this.TestIfComputerIsOnline($ComputerName)
    }
    #endregion <Constructor>

    #region <Methods>
    [void] GetALlInformation ()
    {
        if ($this.Status -eq "Ping OK")
        {
            $This.CheckTime = Get-Date
            $this.TestIfComputerExistInAd()
            $this.GetComputerLastHotFix()
            $this.GetComputerLastBootUptime()
            $this.TestIfRebootNeeded()
        }
    }

    [void] TestIfComputerIsOnline([string]$ComputerName)
    {
        try
        {
            if (Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Stop)
            {
                $this.Status = "Ping OK"
            }
            else
            {
                $this.Status = "Ping KO"
            }
        }
        catch
        {
            $this.Status = "Host Unknown"
        }
    }

    [Boolean] TestIfComputerExistInAd ()
    {
        $Parameter = @{
            Properties  = 'Name', 'SamAccountName', 'CN', 'Operatingsystem', 'Description', 'IPv4Address', 'Created', 'LastLogontimestamp', 'CanonicalName', 'MemberOF'
            Filter      = { Name -eq $This.Name }
            ErrorAction = "SilentlyContinue"
        }

        if ($null -ne $this.Credential)
        {
            $Parameter.Add('Credential', $this.Credential)
        }

        $Computer = Get-ADComputer @Parameter
        if ($Computer)
        {
            try
            {
                $this.SamAccountName = $Computer.SamAccountName
                $this.CN = $Computer.CN
                $this.Operatingsystem = $Computer.Operatingsystem
                $this.Description = $Computer.Description
                $this.IPv4Address = $Computer.IPv4Address
                $this.Created = $Computer.Created
                $this.LastLogontimestamp = [DateTime]::FromFileTime($Computer.LastLogontimestamp)
                $this.CanonicalName = $Computer.CanonicalName
                if ($Computer.MemberOF.Count -gt 0)
                {
                    $this.MemberOF = ($Computer.MemberOf -like "*WSUS*").split("=")[1].split(",")[0]
                }
                else
                {
                    $This.MemberOF = "No WSUS Group"
                }
            }
            catch [System.Management.Automation.MethodException]
            {
                Write-Output ('[{0:O}] ErrorID: {1}' -f (get-date), $_.Exception.Message)
                Write-Output ('[{0:O}] Exception: {1}' -f (get-date), $_.FullyQualifiedErrorId)
                Write-Output ('[{0:O}] Category: {1}' -f (get-date), (($_.Exception.GetType() | Select-Object -ExpandProperty UnderlyingSystemType).FullName))
            }
            catch
            {
                Write-Output ('[{0:O}] ErrorID: {1}' -f (get-date), $_.Exception.Message)
                Write-Output ('[{0:O}] Exception: {1}' -f (get-date), $_.FullyQualifiedErrorId)
                Write-Output ('[{0:O}] Category: {1}' -f (get-date), (($_.Exception.GetType() | Select-Object -ExpandProperty UnderlyingSystemType).FullName))
            }
            return $true
        }
        else
        {
            $this.SamAccountName = "Unknown"
            $this.CN = "Unknown"
            $this.Operatingsystem = "Unknown"
            $this.Description = "Unknown"
            $this.IPv4Address = "Unknown"
            $this.Created = "Unknown"
            $this.LastLogontimestamp = "Unknown"
            $this.CanonicalName = "Unknown"
            $this.MemberOF = "Unknown"
            return $false
        }
    }

    [Void] GetComputerLastHotFix ()
    {
        try
        {
            $HotfixParameter = @{
                ComputerName = $this.CN
                ErrorAction  = "Stop"
            }
            if ($null -ne $this.Credential)
            {
                $HotfixParameter['Credential'] = $this.Credential
            }
            $hotfix = Get-HotFix @HotfixParameter  | Sort-Object -Descending -Property InstalledOn | Select-Object -First 1 | Select-Object Description, HotfixID, InstalledBy, InstalledOn
            $this.HotfixID = $hotfix.HotfixID
            $this.HotFixDescription = $hotfix.Description
            $this.HotFixInstalledBy = $hotfix.InstalledBy
            $this.HotFixInstalledOn = $hotfix.InstalledOn

        }
        catch [System.UnauthorizedAccessException]
        {
            $this.HotfixID = "UnauthorizedAccessException"
            $this.HotFixDescription = "UnauthorizedAccessException"
            $this.HotFixInstalledBy = "UnauthorizedAccessException"
            $this.HotFixInstalledOn = "UnauthorizedAccessException"
        }
        catch
        {
            $this.HotfixID = "Unknown"
            $this.HotFixDescription = "Unknown"
            $this.HotFixInstalledBy = "Unknown"
            $this.HotFixInstalledOn = "Unknown"
        }
    }

    [Void] GetComputerLastBootUptime ()
    {
        try
        {
            $Parameter = @{
                ComputerName = $this.CN
                ErrorAction  = "Stop"
            }
            if ($null -ne $this.Credential)
            {
                $Parameter['Credential'] = $this.Credential
            }
            $this.LastBootUptime = Invoke-Command @Parameter -ScriptBlock { (Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime) }
        }
        catch
        {
            Write-Output ('[{0:O}] ErrorID: {1}' -f (get-date), $_.Exception.Message)
            Write-Output ('[{0:O}] Exception: {1}' -f (get-date), $_.FullyQualifiedErrorId)
            Write-Output ('[{0:O}] Category: {1}' -f (get-date), (($_.Exception.GetType() | Select-Object -ExpandProperty UnderlyingSystemType).FullName))
            $this.LastBootUptime = "Unknown"
        }
    }

    [void] TestIfRebootNeeded ()
    {
        if ($this.Status -eq "Ping OK")
        {
            try
            {
                $CmdParameter = @{
                    ComputerName   = $this.CN
                    ErrorAction    = "Stop"
                    Authentication = "Kerberos"
                }
                if ($null -ne $this.Credential)
                {
                    $CmdParameter['Credential'] = $this.Credential
                }
                $this.RebootNeeded = Invoke-Command @CmdParameter -ScriptBlock {
                    if ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) -or (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) )
                    {
                        write-output "YES"
                    }
                    else
                    {
                        Write-output "NO"
                    }
                }
            }
            catch
            {
                $This.RebootNeeded = "Unknown"
            }
        }
    }

    [void] GetLocalAdministrators ()
    {
        if ($this.Status -eq "Ping OK")
        {
            $LocalAdminParameter = @{
                ComputerName = $this.CN
                ErrorAction  = "Stop"
            }
            if ($null -ne $this.Credential)
            {
                $LocalAdminParameter['Credential'] = $this.Credential
            }
            try
            {
                Invoke-Command @LocalAdminParameter -ScriptBlock {
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
                                ComputerName    = $this.Name
                                OSVersion       = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty  Caption
                                Member          = $_.Line
                                ObjectClass     = ""
                                PrincipalSource = ""
                            }
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
                    ComputerName    = $this.Name
                    OSVersion       = ""
                    Member          = ""
                    ObjectClass     = ""
                    PrincipalSource = ""
                }
            }
        }
    }
    #endregion <Methods>
}
