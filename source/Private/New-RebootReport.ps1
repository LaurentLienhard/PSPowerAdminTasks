function New-RebootReport
{
    <#
    .SYNOPSIS
        Generates an HTML report from reboot events.

    .DESCRIPTION
        This function creates a color-coded HTML report from reboot events.
        Events are categorized by type: crash (red), user-initiated (orange), clean shutdown (green).

    .PARAMETER RebootEvents
        The reboot event objects to include in the report.

    .PARAMETER FilePath
        The path where the HTML report will be saved. Default is Desktop.

    .EXAMPLE
        Get-RemoteRebootLog -ComputerName "SERVER01" | New-RebootReport

    .NOTES
        This is an internal helper function.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$RebootEvents,

        [string]$FilePath = "$env:USERPROFILE\Desktop\Rapport_Reboot.html"
    )

    BEGIN
    {
        # Début du HTML et définition du CSS
        $htmlHead = @"
<html>
<head>
<meta charset="UTF-8">
<style>
    body { font-family: 'Segoe UI', sans-serif; background-color: #f4f4f4; padding: 20px; color: #333; }
    h2 { margin-bottom: 10px; }

    /* Styles du tableau */
    table { border-collapse: collapse; width: 100%; box-shadow: 0 2px 10px rgba(0,0,0,0.1); background-color: white; border-radius: 5px; overflow: hidden; }
    th { background-color: #0078D7; color: white; padding: 12px; text-align: left; }
    td { padding: 10px; border-bottom: 1px solid #eee; vertical-align: top; }
    tr:hover { background-color: #fafafa; }

    /* Couleurs des lignes */
    .crash { background-color: #ffe6e6; border-left: 6px solid #ff4d4d; }       /* Rouge */
    .user-init { background-color: #fff4e6; border-left: 6px solid #ffa500; }   /* Orange */
    .clean { background-color: #e6fffa; border-left: 6px solid #00cc99; }       /* Vert */
    .info { border-left: 6px solid #ccc; }

    /* Styles de la légende */
    .legend-container {
        display: flex;
        gap: 20px;
        margin-bottom: 20px;
        background: white;
        padding: 10px 15px;
        border-radius: 4px;
        width: fit-content;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    .legend-item { display: flex; align-items: center; font-size: 0.9em; font-weight: 500; }
    .dot { width: 12px; height: 12px; display: inline-block; margin-right: 8px; border-radius: 3px; }

    /* Couleurs des pastilles légende */
    .dot-red { background-color: #ff4d4d; }
    .dot-orange { background-color: #ffa500; }
    .dot-green { background-color: #00cc99; }
</style>
</head>
<body>
    <h2>Rapport de Redémarrage Serveurs</h2>

    <div class="legend-container">
        <div class="legend-item">
            <span class="dot dot-red"></span> Arrêt imprévu / Crash (6008)
        </div>
        <div class="legend-item">
            <span class="dot dot-orange"></span> Initié par utilisateur / App (1074/1076)
        </div>
        <div class="legend-item">
            <span class="dot dot-green"></span> Arrêt service propre (6006)
        </div>
    </div>

    <table>
        <tr>
            <th>Date</th>
            <th>Serveur</th>
            <th>Type</th>
            <th>ID</th>
            <th>Utilisateur</th>
            <th>Raison / Commentaire</th>
        </tr>
"@
    }

    PROCESS
    {
        foreach ($evt in $RebootEvents)
        {
            # Détermination de la classe CSS selon l'EventID
            $rowClass = ""
            switch ($evt.EventID)
            {
                6008 { $rowClass = "crash" }      # Crash
                1074 { $rowClass = "user-init" }  # Initié
                1076 { $rowClass = "user-init" }  # Initié (raison)
                6006 { $rowClass = "clean" }      # Service stop
                Default { $rowClass = "info" }
            }

            # Construction de la ligne du tableau
            $htmlHead += @"
        <tr class='$rowClass'>
            <td style="white-space:nowrap;">$($evt.TimeCreated)</td>
            <td><b>$($evt.Computer)</b></td>
            <td>$($evt.Type)</td>
            <td>$($evt.EventID)</td>
            <td>$($evt.User)</td>
            <td>
                <b>Raison:</b> $($evt.Reason)<br>
                <small style="color:#666;"><i>$($evt.Comment)</i></small>
            </td>
        </tr>
"@
        }
    }

    END
    {
        $htmlHead += @"
    </table>
    <p style="text-align:right; font-size:0.8em; color:#888;">Généré le $(Get-Date)</p>
</body>
</html>
"@
        $htmlHead | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Host "Rapport avec légende généré ici : $FilePath" -ForegroundColor Cyan

        # Ouvre automatiquement le rapport
        Invoke-Item $FilePath
    }
}
