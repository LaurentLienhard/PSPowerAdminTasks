function Get-LatencyMatrix
{
    <#
    .SYNOPSIS
        Generates a "Full Mesh" Latency Heatmap between a list of DCs.
    .DESCRIPTION
        Uses Invoke-Command to ping every server from every other server.
        Generates a color-coded HTML heatmap report.
        Optimized with ThrottleLimit for maximum parallelism.
    .PARAMETER DCList
        The list of hostnames or IP addresses of the Domain Controllers.
    .PARAMETER ReportPath
        The full path where the HTML report will be saved.
    .PARAMETER Credential
        (Optional) A PSCredential object to authenticate on remote servers via WinRM.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$DCList,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$ReportPath,

        [Parameter()]
        [PSCredential]$Credential
    )

    # --- Threshold Configuration (in ms) ---
    $Thresholds = @{
        Good   = 50   # Green below this
        Medium = 150  # Yellow below this (Red above)
    }

    # OPTIMIZATION: Set the parallelism limit to the exact number of servers.
    # If you have 50 DCs, it will launch 50 simultaneous WinRM threads.
    $Throttle = $DCList.Count

    Write-Verbose "1. Starting latency tests (Parallelism on $Throttle servers)..."

    # --- Prepare Parameters for Invoke-Command (Splatting) ---
    $ICParams = @{
        ComputerName  = $DCList
        ArgumentList  = (, $DCList)
        ErrorAction   = 'Stop'
        ThrottleLimit = $Throttle # <--- Optimization here
        ScriptBlock   = {
            param($Targets)
            $LocalResults = @()
            $Source = $env:COMPUTERNAME

            # NOTE: This loop runs ON the remote server.
            # Even if you use PS Core locally, remote servers often run Windows PS 5.1.
            # We keep a standard foreach loop for maximum compatibility.
            foreach ($Dest in $Targets)
            {
                # Case 1: Self
                if ($Source -eq $Dest)
                {
                    $LocalResults += [PSCustomObject]@{ Source = $Source; Dest = $Dest; Time = -1 }
                    continue
                }

                # Case 2: Ping target (Count 1 for speed)
                $Ping = Test-Connection -ComputerName $Dest -Count 1 -ErrorAction SilentlyContinue

                if ($Ping)
                {
                    $LocalResults += [PSCustomObject]@{ Source = $Source; Dest = $Dest; Time = $Ping.ResponseTime }
                }
                else
                {
                    $LocalResults += [PSCustomObject]@{ Source = $Source; Dest = $Dest; Time = $null }
                }
            }
            return $LocalResults
        }
    }

    # Add Credential only if provided
    if ($Credential)
    {
        $ICParams['Credential'] = $Credential
    }

    # --- Data Collection via WinRM ---
    try
    {
        $RawData = Invoke-Command @ICParams
    }
    catch
    {
        Write-Error "WinRM Connection Error."
        Write-Error "Check: 1. WinRM enabled on targets. 2. Your Credentials. 3. Your Admin rights."
        Write-Error $_.Exception.Message
        return
    }

    # --- HTML Generation ---
    Write-Verbose "2. Generating HTML report..."

    $HtmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
    body { font-family: Segoe UI, sans-serif; padding: 20px; }
    h2 { color: #333; }
    table { border-collapse: collapse; box-shadow: 0 0 20px rgba(0,0,0,0.15); }
    th, td { border: 1px solid #444; padding: 8px 12px; text-align: center; font-size: 14px; }
    th { background-color: #009879; color: white; font-weight: bold; }

    /* Color Codes */
    .self { background-color: #000; color: #000; } /* Black for self */
    .good { background-color: #98FB98; color: #006400; } /* Green */
    .warn { background-color: #FFE4B5; color: #8B4500; } /* Orange/Yellow */
    .bad  { background-color: #FF6B6B; color: white; font-weight: bold; } /* Red */
    .fail { background-color: #fff; color: red; font-weight: bold; font-size: 16px; } /* X Mark */
    .source-col { background-color: #ddd; font-weight: bold; text-align: left;}
</style>
</head>
<body>
<h2>Inter-DC Latency Heatmap ($Throttle DCs)</h2>
<table>
    <tr>
        <th>Source \ Dest</th>
"@

    # Column Headers
    foreach ($Server in $DCList)
    {
        $HtmlHeader += "<th>$Server</th>"
    }
    $HtmlHeader += "</tr>"

    $HtmlRows = ""

    # Grid Creation
    foreach ($Source in $DCList)
    {
        $HtmlRows += "<tr><td class='source-col'>$Source</td>"

        foreach ($Dest in $DCList)
        {
            # Find specific result in raw data
            $Match = $RawData | Where-Object { $_.PSComputerName -like "*$Source*" -and $_.Dest -eq $Dest } | Select-Object -First 1

            if (-not $Match)
            {
                $HtmlRows += "<td class='fail'>?</td>" # Missing Data
                continue
            }

            $Time = $Match.Time

            # Display Logic
            if ($Source -eq $Dest)
            {
                $HtmlRows += "<td class='self'>.</td>"
            }
            elseif ($null -eq $Time)
            {
                $HtmlRows += "<td class='fail'>X</td>"
            }
            else
            {
                if ($Time -le $Thresholds.Good)
                {
                    $Class = "good"
                }
                elseif ($Time -le $Thresholds.Medium)
                {
                    $Class = "warn"
                }
                else
                {
                    $Class = "bad"
                }

                $HtmlRows += "<td class='$Class'>$Time</td>"
            }
        }
        $HtmlRows += "</tr>"
    }

    $HtmlFooter = "</table><br><em>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm')</em></body></html>"

    # Save File
    $FinalHtml = $HtmlHeader + $HtmlRows + $HtmlFooter
    $FinalHtml | Out-File -FilePath $ReportPath -Encoding UTF8

    Write-Verbose "Done! Report available at: $ReportPath"

    # Auto-open file
    Invoke-Item $ReportPath
}
