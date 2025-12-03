function Get-RemoteUserLogons
{
    <#
    .SYNOPSIS
        Retrieves logon events (ID 4624) from remote servers.
    .DESCRIPTION
        Queries the Security log for successful logons.
        Allows filtering by human-readable logon types (e.g., RDP, Interactive).
    .PARAMETER ComputerName
        One or more server names.
    .PARAMETER Days
        Number of days of history (Default: 1).
    .PARAMETER LogonType
        Select specific logon types. Use TAB to autocomplete.
        - Interactive: Console/Keyboard access
        - RDP: Remote Desktop
        - Network: File shares/Printers
        - Service: Background services
        - Batch: Scheduled tasks
        - Unlock: Unlocking a workstation
    .PARAMETER Credential
        Credentials to connect to the servers.
    #>
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [int]$Days = 1,

        [Parameter(HelpMessage = "Choose a logon type. Press TAB for suggestions.")]
        [ValidateSet("Interactive", "Network", "Batch", "Service", "Unlock", "RDP", "Cached")]
        [string[]]$LogonType,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    # 1. MAPPING: Convert human names to Windows Event IDs
    $TypeMap = @{
        "Interactive" = 2
        "Network"     = 3
        "Batch"       = 4
        "Service"     = 5
        "Unlock"      = 7
        "RDP"         = 10
        "Cached"      = 11
    }

    # Convert the selected strings (e.g., "RDP") to numbers (e.g., 10)
    $SelectedTypeNumbers = @()
    if ($LogonType)
    {
        foreach ($Type in $LogonType)
        {
            if ($TypeMap.ContainsKey($Type))
            {
                $SelectedTypeNumbers += $TypeMap[$Type]
            }
        }
    }

    # 2. REMOTE SCRIPT
    $ScriptBlock = {
        param ([Parameter()]$DaysLookBack, [Parameter()]$TargetLogonTypes)

        $StartDate = (Get-Date).AddDays(-$DaysLookBack)

        # Dictionary for display purposes in the final result
        $LogonDescriptions = @{
            2  = "Interactive"
            3  = "Network"
            4  = "Batch"
            5  = "Service"
            7  = "Unlock"
            10 = "RDP"
            11 = "Cached"
        }

        try
        {
            $Events = Get-WinEvent -FilterHashtable @{
                LogName   = 'Security'
                ID        = 4624
                StartTime = $StartDate
            } -ErrorAction Stop
        }
        catch
        {
            Write-Warning "No events found or access denied on $env:COMPUTERNAME"
            return
        }

        $Results = @()

        foreach ($Event in $Events)
        {
            $Properties = $Event.Properties
            if ($null -eq $Properties -or $Properties.Count -lt 19)
            {
                continue
            }

            $TypeNum = [int]$Properties[8].Value

            # --- FILTERING LOGIC ---
            if ($TargetLogonTypes -and $TargetLogonTypes.Count -gt 0)
            {
                # If user asked for specific types (e.g. RDP), filter strictly
                if ($TargetLogonTypes -notcontains $TypeNum)
                {
                    continue
                }
            }
            else
            {
                # Default behavior: Hide Service(5) and Network(3) unless explicitly requested
                if ($TypeNum -eq 5 -or $TypeNum -eq 3)
                {
                    continue
                }
            }
            # -----------------------

            $User = $Properties[5].Value

            # Secure check (no regex) for machine accounts and SYSTEM
            if ([string]::IsNullOrWhiteSpace($User) -or $User -like '*$' -or $User -eq "SYSTEM" -or $User -eq "ANONYMOUS LOGON")
            {
                continue
            }

            $Results += [PSCustomObject]@{
                Time      = $Event.TimeCreated
                User      = $User
                Domain    = $Properties[6].Value
                LogonType = "$TypeNum - $(if($LogonDescriptions[$TypeNum]){$LogonDescriptions[$TypeNum]}else{'Other'})"
                SourceIP  = $Properties[18].Value
                Server    = $env:COMPUTERNAME
            }
        }
        return $Results
    }

    Write-Host "Querying servers..." -ForegroundColor Cyan

    $InvokeParams = @{
        ComputerName = $ComputerName
        ScriptBlock  = $ScriptBlock
        # Pass the calculated numbers (Int array) to the remote script
        ArgumentList = @($Days, $SelectedTypeNumbers)
    }
    if ($Credential)
    {
        $InvokeParams.Credential = $Credential
    }

    try
    {
        $Output = Invoke-Command @InvokeParams -ErrorAction Stop
        $Output | Select-Object Time, User, Domain, LogonType, SourceIP, Server | Sort-Object Time -Descending
    }
    catch
    {
        Write-Error "Error connecting to servers: $_"
    }
}
