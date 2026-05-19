function Send-MailAfterReboot
{
    <#
    .SYNOPSIS
        Sends an email report listing Windows Updates installed on the current day after a reboot.

    .DESCRIPTION
        This function queries one or more remote servers (or the local machine) to retrieve a list of Windows Updates successfully installed on the current day.
        If any updates are found, it generates and sends an HTML-formatted email report to the specified recipients.

        The function supports French or English output via the -French switch and allows for credential passing for remote queries.

    .PARAMETER ComputerName
        Specifies the name of the computer(s) to query. Accepts pipeline input. Defaults to the local computer name ($env:ComputerName).

    .PARAMETER Recipient
        Specifies the email address(es) of the recipient(s) for the report. Mandatory.

    .PARAMETER SMTPServer
        Specifies the SMTP server to use for sending the email. Defaults to 'smtp.fmlogistic.fr'.

    .PARAMETER Port
        Specifies the port for the SMTP server. Defaults to 25.

    .PARAMETER From
        Specifies the sender's email address. Defaults to 'dsdpwinadm@fmlogistic.fr'.

    .PARAMETER Credential
        Specifies the credentials to use for connecting to remote computers.

    .PARAMETER French
        If specified, the email report will be generated in French.

    .EXAMPLE
        PS C:\> Send-MailAfterReboot -ComputerName 'SRV01' -Recipient 'admin@example.com'
        Queries 'SRV01' for today's updates and sends an English report to 'admin@example.com'.

    .EXAMPLE
        PS C:\> 'SRV01', 'SRV02' | Send-MailAfterReboot -Recipient 'admin@example.com' -French
        Queries 'SRV01' and 'SRV02' for today's updates and sends a French report to 'admin@example.com'.

    .EXAMPLE
        PS C:\> $cred = Get-Credential
        PS C:\> Send-MailAfterReboot -ComputerName 'SRV01' -Recipient 'admin@example.com' -Credential $cred
        Queries 'SRV01' using the provided credentials.

    .INPUTS
        System.String[]

    .OUTPUTS
        None.

    .NOTES
        This function requires the external 'Send-MailKitMessage' command to be available in the session to send the email.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [System.String[]]$ComputerName = $env:ComputerName,

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
        $allInstalledUpdates = @()
        $todayStr = (Get-Date).ToString("dd/MM/yyyy")
    }

    PROCESS
    {
        $updateScriptBlock = {
            $Today = (Get-Date).Date
            $UpdateSession = New-Object -ComObject Microsoft.Update.Session
            $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
            $TotalHistory = $UpdateSearcher.GetTotalHistoryCount()

            if ($TotalHistory -gt 0)
            {
                # Extraction et filtrage : Opération 1 (Installation) et ResultCode 2 (Succès)
                $UpdateSearcher.QueryHistory(0, $TotalHistory) | Where-Object {
                    $_.Date -ge $Today -and $_.Operation -eq 1 -and $_.ResultCode -eq 2
                } | Select-Object @{N = 'ComputerName'; E = { $env:COMPUTERNAME } }, Date, Title
            }
        }

        foreach ($computer in $ComputerName)
        {
            try
            {
                Write-Verbose "Checking installed updates on $computer..."

                $isLocal = ($computer -eq $env:COMPUTERNAME -or $computer -eq 'localhost' -or $computer -eq '127.0.0.1' -or $computer -eq '.')

                if ($isLocal)
                {
                    $installedToday = & $updateScriptBlock
                }
                else
                {
                    $invokeParams = @{
                        ComputerName = $computer
                        ErrorAction  = 'Stop'
                    }
                    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                    {
                        $invokeParams.Credential = $Credential
                    }

                    # Bloc de code exécuté sur le serveur distant
                    $installedToday = Invoke-Command @invokeParams -ScriptBlock $updateScriptBlock
                }

                if ($installedToday)
                {
                    $allInstalledUpdates += $installedToday
                }
                else
                {
                    Write-Verbose "No updates installed today on $computer."
                }
            }
            catch
            {
                Write-Error "Failed to query $computer : $_"
            }
        }
    }

    END
    {
        # On n'envoie le mail que si au moins une mise à jour a été installée sur l'un des serveurs
        if ($allInstalledUpdates.Count -gt 0)
        {
            if ($French)
            {
                $Subject = "Rapport de Maintenance : Mises à jour installées - $todayStr"
                $Title = "Mises à jour installées avec succès"
                $Intro = "Le redémarrage a été effectué. Voici la liste des mises à jour installées aujourd'hui ($todayStr) :"
                $ThHost = "Serveur"
                $ThDate = "Heure d'installation"
                $ThTitle = "Nom de la mise à jour"
            }
            else
            {
                $Subject = "Maintenance Report: Updates Installed - $todayStr"
                $Title = "Successfully Installed Updates"
                $Intro = "The reboot has completed. Here is the list of updates installed today ($todayStr):"
                $ThHost = "Computer"
                $ThDate = "Installation Time"
                $ThTitle = "Update Title"
            }

            if ($PSCmdlet.ShouldProcess("Send installation report email to $($Recipient -join ', ')"))
            {
                try
                {
                    $tableRows = foreach ($update in $allInstalledUpdates)
                    {
                        "<tr>
                            <td>$($update.ComputerName)</td>
                            <td>$($update.Date.ToString('HH:mm:ss'))</td>
                            <td class='update-title'>$($update.Title)</td>
                        </tr>"
                    }

                    $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; line-height: 1.6; }
        table { border-collapse: collapse; width: 700px; margin-top: 15px; margin-bottom: 25px; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #4472C4; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .update-title { font-size: 13px; font-family: Consolas, monospace; }
        .success-msg { color: #2e7d32; font-weight: bold; font-size: 16px; }
    </style>
</head>
<body>
    <h2 style="color: #4472C4;">$Title</h2>
    <p>$Intro</p>
    <table>
        <thead>
            <tr><th>$ThHost</th><th>$ThDate</th><th>$ThTitle</th></tr>
        </thead>
        <tbody>
            $($tableRows -join '')
        </tbody>
    </table>
    <p class="success-msg">$(if ($French) { "La grille AutoStore peut être relancée si nécessaire." } else { "The AutoStore grid can be restarted if required." })</p>
</body>
</html>
"@

                    # Utilisation de votre fonction habituelle Send-MailKitMessage
                    Send-MailKitMessage -SMTPServer $SMTPServer -Port $Port -From $From `
                        -RecipientList ($Recipient -join ',') -Subject $Subject -HtmlBody $htmlBody
                }
                catch
                {
                    Write-Error "Failed to send email: $_"
                }
            }
        }
        else
        {
            Write-Verbose "No updates were installed on any targeted servers today. No email sent."
        }
    }
}
