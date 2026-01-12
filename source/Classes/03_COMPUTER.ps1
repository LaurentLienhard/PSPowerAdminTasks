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

    [System.String]$DnsServers

    HIDDEN [System.Management.Automation.PSCredential]$Credential
    #endregion <Properties>

    #region <Constructor>
    COMPUTER()
    {
    }

    COMPUTER([string]$ComputerName)
    {
        $this.CheckTime = Get-Date
        $this.Name = $ComputerName
        $this.TestIfComputerIsOnline($ComputerName)
    }

    COMPUTER([string]$ComputerName, [System.Management.Automation.PSCredential]$Credential)
    {
        # BUG FIX 1 : Initialisation de la date
        $this.CheckTime = Get-Date
        $this.Credential = $Credential
        $this.Name = $ComputerName
        $this.TestIfComputerIsOnline($ComputerName)
    }
    #endregion <Constructor>

    #region <Methods>
    [void] GetAllInformation ()
    {
        if ($this.Status -eq "Ping OK")
        {
            $this.CheckTime = Get-Date
            $this.TestIfComputerExistInAd()
            $this.GetComputerLastHotFix()
            $this.GetComputerLastBootUptime()
            $this.TestIfRebootNeeded()
            $this.GetDnsConfig()
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
                $this.Status = "Ping Failed"
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
            Filter      = { Name -eq $this.Name }
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
                    $this.MemberOF = "No WSUS Group"
                }
            }
            catch
            {
                #
            }
            return $true
        }
        else
        {
            return $false
        }
    }

    [Void] GetComputerLastHotFix ()
    {
        # BUG FIX 2 (Préventif) : Utiliser $this.Name au lieu de $this.CN
        # car si on n'a pas fait de requête AD, CN est vide.
        try
        {
            $HotfixParameter = @{
                ComputerName = $this.Name
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
        catch
        {
            $this.HotfixID = "Unknown"
            $this.HotFixDescription = "Unknown"
        }
    }

    [Void] GetComputerLastBootUptime ()
    {
        try
        {
            $Parameter = @{
                ComputerName = $this.Name # Fix: Name au lieu de CN
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
                    ComputerName   = $this.Name # Fix: Name au lieu de CN
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
                        Write-Output "YES"
                    }
                    else
                    {
                        Write-Output "NO"
                    }
                }
            }
            catch
            {
                $this.RebootNeeded = "Unknown"
            }
        }
    }

    # -------------------------------------------------------------------------
    # DNS MANAGEMENT METHODS (ENGLISH)
    # -------------------------------------------------------------------------

    # 1. Retrieve Current Configuration
    [void] GetDnsConfig ()
    {
        if ($this.Status -eq "Ping OK")
        {
            # BUG FIX 2 : Utiliser $this.Name ici aussi
            $CmdParameter = @{
                ComputerName = $this.Name
                ErrorAction  = "Stop"
            }
            if ($null -ne $this.Credential) { $CmdParameter['Credential'] = $this.Credential }

            try
            {
                # Retrieve unique IPs configured
                $result = Invoke-Command @CmdParameter -ScriptBlock {
                    $foundDns = @()
                    if (Get-Command -Name 'Get-NetAdapter' -ErrorAction SilentlyContinue) {
                        # Modern Method
                        $foundDns = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses -ne $null | Select-Object -ExpandProperty ServerAddresses
                    }
                    else {
                        # Legacy Method (WMI)
                        $foundDns = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'" | Select-Object -ExpandProperty DNSServerSearchOrder
                    }
                    return ($foundDns | Select-Object -Unique)
                }

                if ($result) {
                    $this.DnsServers = ($result -join ', ')
                } else {
                    $this.DnsServers = "None"
                }
            }
            catch {
                $this.DnsServers = "Error Retrieving DNS"
                # On capture l'erreur réelle pour le debug si besoin, mais on ne pollue pas la sortie standard
                # Write-Warning ("Debug Error on {0}: {1}" -f $this.Name, $_.Exception.Message)
            }
        }
    }

    # 2. Replace ALL DNS servers with a new list (Main Method)
    [void] SetDnsServers ([string[]]$NewDnsList)
    {
        if ($this.Status -eq "Ping OK")
        {
            Write-Verbose "Updating DNS servers on $($this.Name) with: $($NewDnsList -join ', ')..."

            $CmdParameter = @{
                ComputerName = $this.Name # Fix: Name au lieu de CN
                ErrorAction  = "Stop"
                ArgumentList = (,$NewDnsList)
            }
            if ($null -ne $this.Credential) { $CmdParameter['Credential'] = $this.Credential }

            try {
                Invoke-Command @CmdParameter -ScriptBlock {
                    param([string[]]$DnsToSet)

                    if (Get-Command -Name 'Get-NetAdapter' -ErrorAction SilentlyContinue) {
                        $interfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
                        foreach ($iface in $interfaces) {
                            Set-DnsClientServerAddress -InterfaceIndex $iface.ifIndex -ServerAddresses $DnsToSet -ErrorAction SilentlyContinue
                        }
                    }
                    else {
                        $adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'"
                        foreach ($adapter in $adapters) {
                            $adapter.SetDNSServerSearchOrder($DnsToSet) | Out-Null
                        }
                    }
                }
                $this.GetDnsConfig()
                Write-Verbose "DNS updated successfully."
            }
            catch {
                Write-Warning ('Error Setting DNS on {0}: {1}' -f $this.Name, $_.Exception.Message)
            }
        }
    }

    # Helper methods (Add/Remove/Modify) remain the same logical wrappers
    [void] AddDnsServer ([string]$NewDnsIP)
    {
        $this.GetDnsConfig()
        $currentList = @()
        if ($this.DnsServers -and $this.DnsServers -ne "None" -and $this.DnsServers -ne "Error Retrieving DNS") {
            $currentList = $this.DnsServers -split ', '
        }

        if ($currentList -notcontains $NewDnsIP) {
            $currentList += $NewDnsIP
            $this.SetDnsServers($currentList)
        }
    }

    [void] RemoveDnsServer ([string]$DnsIpToRemove)
    {
        $this.GetDnsConfig()
        $currentList = @()
        if ($this.DnsServers -and $this.DnsServers -ne "None") {
            $currentList = $this.DnsServers -split ', '
        }
        if ($currentList -contains $DnsIpToRemove) {
            $newList = $currentList | Where-Object { $_ -ne $DnsIpToRemove }
            $this.SetDnsServers($newList)
        }
    }

    [void] ModifyDnsServer ([string]$OldIp, [string]$NewIp)
    {
        $this.GetDnsConfig()
        $currentList = @()
        if ($this.DnsServers -and $this.DnsServers -ne "None") {
            $currentList = $this.DnsServers -split ', '
        }
        if ($currentList -contains $OldIp) {
            $newList = $currentList | ForEach-Object { if ($_ -eq $OldIp) { $NewIp } else { $_ } }
            $this.SetDnsServers($newList)
        }
    }
    #endregion <Methods>
}
