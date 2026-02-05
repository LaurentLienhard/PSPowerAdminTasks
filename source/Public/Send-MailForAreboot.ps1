function Send-MailForAreboot
{
    <#
    .SYNOPSIS
        Sends an email notification for servers requiring a reboot or having pending updates.

    .DESCRIPTION
        This function scans remote servers to retrieve the count of available software updates and checks the 'Pending Reboot' status.
        It generates a formatted HTML email with specific maintenance instructions for the AutoStore grid.

    .PARAMETER ComputerName
        List of computer names or server addresses to scan.

    .PARAMETER Recipient
        Email address(es) of the recipient(s).

    .PARAMETER SMTPServer
        The SMTP server used for sending (Default: smtp.fmlogistic.fr).

    .PARAMETER Port
        The SMTP port (Default: 25).

    .PARAMETER From
        The sender's email address (Default: dsdpwinadm@fmlogistic.fr).

    .PARAMETER Credential
        The credentials required to connect to the remote servers.

    .PARAMETER French
        If specified, the email content will be translated into French using proper HTML entities for encoding safety.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]]$ComputerName,

        [Parameter(Mandatory = $true)]
        [System.String[]]$Recipient,

        [Parameter()]$SMTPServer = 'smtp.fmlogistic.fr',
        [Parameter()]$Port = 25,
        [Parameter()]$From = 'dsdpwinadm@fmlogistic.fr',

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter()][switch]$French
    )

    begin
    {
        $result = @()
        $serversNeedingAttention = @()
    }

    process
    {
        foreach ($computer in $ComputerName)
        {
            try
            {
                Write-Verbose "Processing $computer..."
                $computerObject = if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                {
                    [COMPUTER]::new($computer, $Credential)
                }
                else
                {
                    [COMPUTER]::new($computer)
                }

                if ($computerObject.Status -eq 'Ping OK')
                {
                    $computerObject.GetAllInformation()

                    $updateCount = 0
                    try
                    {
                        $updateCount = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                            $searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
                            return $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0").Updates.Count
                        } -ErrorAction Stop
                    }
                    catch
                    {
                        $updateCount = "Error"
                    }

                    $serverData = [PSCustomObject]@{
                        ComputerName   = $computerObject.Name
                        PendingUpdates = $updateCount
                        RebootNeeded   = $computerObject.RebootNeeded
                        Status         = 'SUCCESS'
                    }

                    if (($computerObject.RebootNeeded -eq 'YES') -or ($updateCount -is [int] -and $updateCount -gt 0))
                    {
                        $serversNeedingAttention += $serverData
                    }
                    $result += $serverData
                }
                else
                {
                    $result += [PSCustomObject]@{ ComputerName = $computer; Status = 'FAILED'; Message = $computerObject.Status }
                }
            }
            catch
            {
                $result += [PSCustomObject]@{ ComputerName = $computer; Status = 'FAILED'; Message = $_.Exception.Message }
            }
        }
    }

    end
    {
        if ($serversNeedingAttention.Count -gt 0)
        {
            # Email Content Configuration
            if ($French)
            {
                $Subject = "Action Requise : Maintenance sur $($serversNeedingAttention.Count) serveur(s)"
                $Title = "Rapport de Maintenance Serveurs"
                $Intro = "Les serveurs suivants pr&eacute;sentent des mises &agrave; jour en attente ou n&eacute;cessitent un red&eacute;marrage :"
                $ThHost = "Serveur"
                $ThUpd = "Updates"
                $ThReb = "Reboot Requis"
                $Action = "Merci d'arr&ecirc;ter la grille autostore avant Dimanche 9H pour maintenance."
                $Action2 = "L'autostore pourra &ecirc;tre relanc&eacute; &agrave; partir de Dimanche &agrave; 12h."
            }
            else
            {
                $Subject = "Action Required: Maintenance on $($serversNeedingAttention.Count) server(s)"
                $Title = "Server Maintenance Report"
                $Intro = "The following servers have pending updates or require a reboot:"
                $ThHost = "Computer"
                $ThUpd = "Updates"
                $ThReb = "Reboot Needed"
                $Action = "Please stop the AutoStore grid before Sunday 9:00 AM for maintenance."
                $Action2 = "AutoStore can be restarted from Sunday at 12:00 PM."
            }

            if ($PSCmdlet.ShouldProcess("Send email to $($Recipient -join ', ')"))
            {
                try
                {
                    $tableRows = foreach ($server in $serversNeedingAttention)
                    {
                        $rebootStyle = if ($server.RebootNeeded -eq 'YES')
                        {
                            "style='color: #c00; font-weight: bold;'"
                        }
                        else
                        {
                            ""
                        }
                        $updateStyle = if ($server.PendingUpdates -is [int] -and $server.PendingUpdates -gt 0)
                        {
                            "style='color: #e67e22; font-weight: bold;'"
                        }
                        else
                        {
                            ""
                        }

                        "<tr>
                            <td>$($server.ComputerName)</td>
                            <td $updateStyle>$($server.PendingUpdates)</td>
                            <td $rebootStyle>$($server.RebootNeeded)</td>
                        </tr>"
                    }

                    $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; line-height: 1.6; }
        table { border-collapse: collapse; width: 500px; margin-top: 15px; margin-bottom: 25px; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #4472C4; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .instruction { font-size: 16px; font-weight: bold; color: #d35400; margin: 10px 0; }
    </style>
</head>
<body>
    <h2 style="color: #4472C4;">$Title</h2>
    <p>$Intro</p>
    <table>
        <thead>
            <tr><th>$ThHost</th><th>$ThUpd</th><th>$ThReb</th></tr>
        </thead>
        <tbody>
            $($tableRows -join '')
        </tbody>
    </table>
    <p class="instruction">$Action</p>
    <p class="instruction">$Action2</p>
</body>
</html>
"@
                    Send-MailKitMessage -SMTPServer $SMTPServer -Port $Port -From $From `
                        -RecipientList ($Recipient -join ',') -Subject $Subject -HtmlBody $htmlBody
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
