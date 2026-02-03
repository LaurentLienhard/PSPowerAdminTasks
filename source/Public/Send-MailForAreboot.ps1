function Send-MailForAreboot
{
    <#
    .SYNOPSIS
        Send an email notification for servers requiring a reboot.

    .PARAMETER French
        If specified, the email content (subject and body) will be in French.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]]
        $ComputerName,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Recipient,

        [Parameter()]
        [System.String]
        $SMTPServer = 'smtp.fmlogistic.fr',

        [Parameter()]
        [System.Int32]
        $Port = 25,

        [Parameter()]
        [System.String]
        $From = 'dsdpwinadm@fmlogistic.fr',

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter()]
        [switch]$French
    )

    begin
    {
        $result = @()
        $serversNeedingReboot = @()
    }

    process
    {
        foreach ($computer in $ComputerName)
        {
            try
            {
                Write-Verbose "Checking reboot status for $computer..."

                if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                {
                    $computerObject = [COMPUTER]::new($computer, $Credential)
                }
                else
                {
                    $computerObject = [COMPUTER]::new($computer)
                }

                if ($computerObject.Status -eq 'Ping OK')
                {
                    $computerObject.GetAllInformation()

                    if ($computerObject.RebootNeeded -eq 'YES')
                    {
                        $rebootInfo = [PSCustomObject]@{
                            ComputerName    = $computerObject.Name
                            OperatingSystem = $computerObject.Operatingsystem
                            LastBootUptime  = $computerObject.LastBootUptime
                            LastHotfixID    = $computerObject.HotfixID
                            LastHotfixDate  = $computerObject.HotFixInstalledOn
                            RebootNeeded    = $computerObject.RebootNeeded
                            Status          = 'SUCCESS'
                        }
                        $serversNeedingReboot += $rebootInfo
                        $result += $rebootInfo
                    }
                    else
                    {
                        $result += [PSCustomObject]@{
                            ComputerName    = $computerObject.Name
                            OperatingSystem = $computerObject.Operatingsystem
                            RebootNeeded    = $computerObject.RebootNeeded
                            Status          = 'SUCCESS'
                        }
                    }
                }
                else
                {
                    Write-Warning "Computer $computer is not reachable"
                    $result += [PSCustomObject]@{
                        ComputerName = $computer
                        RebootNeeded = 'Unknown'
                        Status       = 'FAILED'
                        Message      = $computerObject.Status
                    }
                }
            }
            catch
            {
                Write-Error "Error for $computer : $_"
                $result += [PSCustomObject]@{
                    ComputerName = $computer
                    RebootNeeded = 'Unknown'
                    Status       = 'FAILED'
                    Message      = $_.Exception.Message
                }
            }
        }
    }

    end
    {
        if ($serversNeedingReboot.Count -gt 0)
        {
            if ($French)
            {
                $Subject = "Action Requise : $($serversNeedingReboot.Count) serveur(s) en attente de redémarrage"
                $Header = "Alerte de Notification de Redémarrage"
                $Intro = "Le(s) $($serversNeedingReboot.Count) serveur(s) suivant(s) nécessite(nt) une attention immédiate (redémarrage en attente) :"
                $ThHost = "Nom du Serveur"
                $ThOS = "Système d'Exploitation"
                $ThBoot = "Dernier Boot"
                $ThFix = "ID Dernier Hotfix"
                $ThDate = "Date du Hotfix"
                $Action = "Merci de planifier le redémarrage de ces serveurs dès que possible."
                $Footer = "Ceci est un message automatique."
            }
            else
            {
                $Subject = "Action Required: $($serversNeedingReboot.Count) server(s) require reboot"
                $Header = "Reboot Notification Alert"
                $Intro = "The following $($serversNeedingReboot.Count) server(s) require immediate attention and have a pending reboot:"
                $ThHost = "Computer Name"
                $ThOS = "Operating System"
                $ThBoot = "Last Boot Time"
                $ThFix = "Last Hotfix ID"
                $ThDate = "Last Hotfix Date"
                $Action = "Please plan to reboot these servers at the earliest convenient time."
                $Footer = "This is an automated message."
            }

            if ($PSCmdlet.ShouldProcess("Send email to $($Recipient -join ', ')"))
            {
                try
                {
                    $SMTPRecipientList = [MimeKit.InternetAddressList]::new()
                    foreach ($addr in $Recipient)
                    {
                        $SMTPRecipientList.Add([MimeKit.InternetAddress]$addr)
                    }

                    $htmlBody = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 12px; }
        th { background-color: #4472C4; color: white; text-align: left; }
        .warning { color: #c00; font-weight: bold; }
    </style>
</head>
<body>
    <h2>$Header</h2>
    <p><strong>$Intro</strong></p>
    <table>
        <tr>
            <th>$ThHost</th><th>$ThOS</th><th>$ThBoot</th><th>$ThFix</th><th>$ThDate</th>
        </tr>
"@
                    foreach ($server in $serversNeedingReboot)
                    {
                        $htmlBody += "<tr><td class='warning'>$($server.ComputerName)</td><td>$($server.OperatingSystem)</td><td>$($server.LastBootUptime)</td><td>$($server.LastHotfixID)</td><td>$($server.LastHotfixDate)</td></tr>"
                    }

                    $htmlBody += @"
    </table>
    <p><strong>$Action</strong></p>
    <p><small>$Footer</small></p>
</body>
</html>
"@
                    Send-MailKitMessage -SMTPServer $SMTPServer -Port $Port -From $From `
                        -RecipientList $SMTPRecipientList -Subject $Subject -HtmlBody $htmlBody
                }
                catch
                {
                    Write-Error "Failed to send email: $_"
                }
            }
        }
        return $result
    }
}
