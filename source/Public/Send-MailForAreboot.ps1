function Send-MailForAreboot
{
    <#
    .SYNOPSIS
        Send an email notification for servers requiring a reboot or having pending updates.

    .DESCRIPTION
        This function checks remote servers for pending reboots and available software updates.
        It sends a localized HTML email if action is required.
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
            # Localization avec entites HTML pour eviter les erreurs d'encodage
            if ($French)
            {
                $Subject = "Action Requise : Maintenance sur $($serversNeedingAttention.Count) serveur(s)"
                $Title = "Rapport de Maintenance Serveurs"
                $Intro = "Les serveurs suivants pr&eacute;sentent des mises &agrave; jour en attente ou n&eacute;cessitent un red&eacute;marrage :"
                $ThHost = "Serveur"
                $ThUpd = "Updates"
                $ThReb = "Reboot Requis"
                $Action = "Action : Merci de planifier une intervention pour ces machines."
            }
            else
            {
                $Subject = "Action Required: Maintenance on $($serversNeedingAttention.Count) server(s)"
                $Title = "Server Maintenance Report"
                $Intro = "The following servers have pending updates or require a reboot:"
                $ThHost = "Computer"
                $ThUpd = "Updates"
                $ThReb = "Reboot Needed"
                $Action = "Action: Please plan a maintenance window for these machines."
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
<html lang="fr">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; line-height: 1.6; }
        table { border-collapse: collapse; width: 500px; margin-top: 15px; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #4472C4; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
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
    <p><strong>$Action</strong></p>
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
