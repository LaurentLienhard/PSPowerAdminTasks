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

    # --- CORRECTION ICI : ON NE RESOUT PLUS L'IP LORS DU PING ---
    [void] TestIfComputerIsOnline([string]$ComputerName)
    {
        try
        {
            # On fait juste un Ping simple pour le statut.
            # On ne touche PAS à $this.IPv4Address ici pour éviter de récupérer l'IP NAT du VPN.
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

                # C'est ICI que la seule vraie IP (AD) sera définie
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
                # Silent catch
            }
            return $true
        }
        else
        {
            # Si pas dans l'AD, on le dit explicitement
            $this.IPv4Address = "Not in AD"
            return $false
        }
    }

    [Void] GetComputerLastHotFix ()
    {
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
                ComputerName = $this.Name
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
                    ComputerName   = $this.Name
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

[void] GetDnsConfig ()
    {
        if ($this.Status -eq "Ping OK")
        {
            $CmdParameter = @{
                ComputerName = $this.Name
                ErrorAction  = "Stop"
            }
            if ($null -ne $this.Credential) { $CmdParameter['Credential'] = $this.Credential }

            try
            {
                # On récupère un objet complexe (IP + DNS) depuis le serveur
                $remoteData = Invoke-Command @CmdParameter -ScriptBlock {
                    $resultData = @{ IP = $null; DNS = @() }

                    if (Get-Command -Name 'Get-NetAdapter' -ErrorAction SilentlyContinue) {
                        # MODERN (Windows 2012+)
                        # On cherche l'interface "Up" qui a une passerelle (souvent la principale)
                        $iface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
                        if ($iface) {
                            $dns = Get-DnsClientServerAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4
                            $ip  = Get-NetIPAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 | Select-Object -First 1

                            $resultData.DNS = $dns.ServerAddresses
                            $resultData.IP  = $ip.IPAddress
                        }
                    }
                    else {
                        # LEGACY (WMI)
                        $adapter = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'" | Select-Object -First 1
                        if ($adapter) {
                            $resultData.DNS = $adapter.DNSServerSearchOrder
                            $resultData.IP  = $adapter.IPAddress[0] # IPAddress est un tableau en WMI
                        }
                    }
                    return $resultData
                }

                # Traitement du résultat DNS
                if ($remoteData.DNS) {
                    $this.DnsServers = ($remoteData.DNS | Select-Object -Unique) -join ', '
                } else {
                    $this.DnsServers = "None"
                }

                # Traitement du résultat IP (C'est ici qu'on a la vraie IP LAN)
                if ($remoteData.IP) {
                    $this.IPv4Address = $remoteData.IP
                } else {
                    $this.IPv4Address = "Unknown IP"
                }
            }
            catch {
                $this.DnsServers = "Error Retrieving Info"
                $this.IPv4Address = "Connection Error"
            }
        }
    }

    [void] SetDnsServers ([string[]]$NewDnsList)
    {
        if ($this.Status -eq "Ping OK")
        {
            $CmdParameter = @{
                ComputerName = $this.Name
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
            }
            catch {
                Write-Warning ('Error Setting DNS on {0}: {1}' -f $this.Name, $_.Exception.Message)
            }
        }
    }

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
