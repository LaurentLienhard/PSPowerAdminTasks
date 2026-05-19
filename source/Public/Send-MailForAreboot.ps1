function Send-MailForAreboot
{
    <#
    .SYNOPSIS
        Sends an email notification for servers requiring a reboot or having pending updates.
    .DESCRIPTION
        Calculates the 3rd Wednesday of the month. If passed, moves to the next month.
        Specific maintenance window: Stop at 13:00, approx 1h duration.
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

    BEGIN
    {
        $result = @()
        $serversNeedingAttention = @()

        # --- Logique de calcul du 3ème Mercredi ---
        $GetThirdWednesday = {
            param($Year, $Month)
            $firstOfMonth = Get-Date -Year $Year -Month $Month -Day 1
            $daysUntilWednesday = (([int][DayOfWeek]::Wednesday - [int]$firstOfMonth.DayOfWeek + 7) % 7)
            return $firstOfMonth.AddDays($daysUntilWednesday + 14)
        }

        $today = Get-Date
        $targetWednesday = &$GetThirdWednesday -Year $today.Year -Month $today.Month

        # Bascule au mois suivant si la date du jour est après le mercredi cible
        if ($today.Date -gt $targetWednesday.Date) {
            $nextMonthDate = $today.AddMonths(1)
            $targetWednesday = &$GetThirdWednesday -Year $nextMonthDate.Year -Month $nextMonthDate.Month
        }
        $dateMaintenance = $targetWednesday.ToString("dd/MM/yyyy")
    }

    PROCESS
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
                    catch { $updateCount = "Error" }

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

    END
    {
        if ($serversNeedingAttention.Count -gt 0)
        {
            if ($French)
            {
                $Subject = "Action Requise : Maintenance AutoStore - $dateMaintenance"
                $Title    = "Rapport de Maintenance Serveurs"
                $Intro    = "Les serveurs suivants pr&eacute;sentent des mises &agrave; jour en attente ou n&eacute;cessitent un red&eacute;marrage :"
                $ThHost   = "Serveur"
                $ThUpd    = "Updates"
                $ThReb    = "Reboot Requis"
                # Mise à jour des horaires (13h + 1h de durée)
                $Action   = "La maintenance est pr&eacute;vue le <b>Mercredi $dateMaintenance</b>."
                $Action2  = "Merci d'arr&ecirc;ter la grille AutoStore &agrave; <b>13:00</b>. Le red&eacute;marrage est estim&eacute; aux alentours de <b>14:00</b>."
            }
            else
            {
                $Subject = "Action Required: AutoStore Maintenance - $dateMaintenance"
                $Title    = "Server Maintenance Report"
                $Intro    = "The following servers have pending updates or require a reboot:"
                $ThHost   = "Computer"
                $ThUpd    = "Updates"
                $ThReb    = "Reboot Needed"
                $Action   = "Maintenance is scheduled for <b>Wednesday $dateMaintenance</b>."
                $Action2  = "Please stop the AutoStore grid at <b>01:00 PM</b>. Restart is estimated around <b>02:00 PM</b>."
            }

            if ($PSCmdlet.ShouldProcess("Send email to $($Recipient -join ', ')"))
            {
                try
                {
                    $tableRows = foreach ($server in $serversNeedingAttention)
                    {
                        $rebootStyle = if ($server.RebootNeeded -eq 'YES') { "style='color: #c00; font-weight: bold;'" } else { "" }
                        $updateStyle = if ($server.PendingUpdates -is [int] -and $server.PendingUpdates -gt 0) { "style='color: #e67e22; font-weight: bold;'" } else { "" }

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
