function Send-MailForAreboot
{
    <#
    .SYNOPSIS
        Send an email notification for servers requiring a reboot.

    .DESCRIPTION
        This function connects to a list of servers, checks if a reboot is pending,
        and sends an email notification to the specified recipients if a reboot is required.

    .PARAMETER ComputerName
        The name(s) of the server(s) to check for pending reboot. Accepts an array of strings
        or pipeline input.

    .PARAMETER Recipient
        The email address(es) of the recipient(s) to notify. Accepts an array of email addresses.

    .PARAMETER SMTPServer
        The SMTP server address to use for sending emails. Default is 'smtp.fmlogistic.fr'.

    .PARAMETER Port
        The SMTP port to use. Default is 25.

    .PARAMETER From
        The sender email address. Default is 'dsdpwinadm@fmlogistic.fr'.

    .PARAMETER Credential
        PSCredential object for remote connection to servers. If not provided, uses current
        session credentials.

    .PARAMETER MaxParallel
        Maximum number of servers to process in parallel. Default is 5. Higher values increase
        parallelization but consume more resources. Requires PowerShell 7.0 or later.

    .EXAMPLE
        Send-MailForAreboot -ComputerName 'SERVER01', 'SERVER02' -Recipient 'admin@domain.com'

        Checks SERVER01 and SERVER02 for pending reboots and sends notification email if needed.

    .EXAMPLE
        'SERVER01', 'SERVER02' | Send-MailForAreboot -Recipient 'admin@domain.com', 'support@domain.com'

        Accepts computer names from pipeline and notifies multiple recipients.

    .EXAMPLE
        Send-MailForAreboot -ComputerName 'SERVER01' -Recipient 'admin@domain.com' `
            -SMTPServer 'smtp.custom.com' -Port 587 -From 'alerts@custom.com'

        Uses custom SMTP configuration.

    .EXAMPLE
        Send-MailForAreboot -ComputerName (Get-Content .\servers.txt) -Recipient 'admin@domain.com' -MaxParallel 10

        Processes 10 servers in parallel for faster execution.

    .NOTES
        The function uses the COMPUTER class to detect pending reboots and Send-MailKitMessage
        to send notifications. Email is only sent if at least one server requires a reboot.
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
        [ValidateRange(1, 50)]
        [System.Int32]
        $MaxParallel = 5
    )

    begin
    {
        $result = @()
        $serversNeedingReboot = @()
    }

    process
    {
        $ComputerName | ForEach-Object -Parallel {
            $computer = $_
            $Credential = $using:Credential

            try
            {
                Write-Verbose "Checking reboot status for $computer..."

                # Create COMPUTER object
                if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                {
                    $computerObject = [COMPUTER]::new($computer, $Credential)
                }
                else
                {
                    $computerObject = [COMPUTER]::new($computer)
                }

                # Test if computer is online
                if ($computerObject.Status -eq 'Ping OK')
                {
                    Write-Verbose "Computer $computer is online. Checking for pending reboot..."

                    # Get computer information including reboot status
                    $computerObject.GetAllInformation()

                    # Check if reboot is needed
                    if ($computerObject.RebootNeeded -eq 'YES')
                    {
                        Write-Verbose "Computer $computer requires a reboot."

                        [PSCustomObject]@{
                            ComputerName    = $computerObject.Name
                            OperatingSystem = $computerObject.Operatingsystem
                            LastBootUptime  = $computerObject.LastBootUptime
                            LastHotfixID    = $computerObject.HotfixID
                            LastHotfixDate  = $computerObject.HotFixInstalledOn
                            RebootNeeded    = $computerObject.RebootNeeded
                            Status          = 'SUCCESS'
                            NeedsReboot     = $true
                        }
                    }
                    else
                    {
                        Write-Verbose "Computer $computer does not require a reboot."

                        [PSCustomObject]@{
                            ComputerName    = $computerObject.Name
                            OperatingSystem = $computerObject.Operatingsystem
                            RebootNeeded    = $computerObject.RebootNeeded
                            Status          = 'SUCCESS'
                            NeedsReboot     = $false
                        }
                    }
                }
                else
                {
                    Write-Warning "Computer $computer is not reachable (Status: $($computerObject.Status))"

                    [PSCustomObject]@{
                        ComputerName = $computer
                        RebootNeeded = 'Unknown'
                        Status       = 'FAILED'
                        Message      = $computerObject.Status
                        NeedsReboot  = $false
                    }
                }
            }
            catch
            {
                Write-Error "Error checking reboot status for $computer : $_"

                [PSCustomObject]@{
                    ComputerName = $computer
                    RebootNeeded = 'Unknown'
                    Status       = 'FAILED'
                    Message      = $_.Exception.Message
                    NeedsReboot  = $false
                }
            }
        } -ThrottleLimit $MaxParallel | ForEach-Object {
            $result += $_
            if ($_.NeedsReboot)
            {
                $serversNeedingReboot += $_
            }
        }
    }

    end
    {
        if ($serversNeedingReboot.Count -gt 0)
        {
            Write-Verbose "Found $($serversNeedingReboot.Count) server(s) requiring reboot. Preparing to send email..."

            if ($PSCmdlet.ShouldProcess("Send reboot notification email to $($Recipient -join ', ')"))
            {
                try
                {
                    # Configure email recipients
                    $SMTPRecipientList = [MimeKit.InternetAddressList]::new()
                    foreach ($emailAddress in $Recipient)
                    {
                        $SMTPRecipientList.Add([MimeKit.InternetAddress]$emailAddress)
                    }

                    $SMTPSender = [MimeKit.MailboxAddress]$From

                    # Build email subject and body
                    $EmailSubject = "Action Required: $($serversNeedingReboot.Count) server(s) require reboot"

                    $htmlBody = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #4472C4; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .warning { color: #c00; font-weight: bold; }
        .summary { margin: 10px 0; }
    </style>
</head>
<body>
    <h2>Reboot Notification Alert</h2>

    <div class="summary">
        <p><strong>The following $($serversNeedingReboot.Count) server(s) require immediate attention and have a pending reboot:</strong></p>
    </div>

    <table>
        <tr>
            <th>Computer Name</th>
            <th>Operating System</th>
            <th>Last Boot Time</th>
            <th>Last Hotfix ID</th>
            <th>Last Hotfix Date</th>
        </tr>
"@

                    foreach ($server in $serversNeedingReboot)
                    {
                        $htmlBody += @"
        <tr>
            <td class="warning">$($server.ComputerName)</td>
            <td>$($server.OperatingSystem)</td>
            <td>$($server.LastBootUptime)</td>
            <td>$($server.LastHotfixID)</td>
            <td>$($server.LastHotfixDate)</td>
        </tr>
"@
                    }

                    $htmlBody += @"
    </table>

    <div class="summary">
        <p><strong>Action Required:</strong> Please plan to reboot these servers at the earliest convenient time to complete the pending updates.</p>
        <p><em>This is an automated message generated by PSPowerAdminTasks.</em></p>
    </div>

</body>
</html>
"@

                    # Send email
                    Send-MailKitMessage -SMTPServer $SMTPServer `
                        -Port $Port `
                        -From $SMTPSender `
                        -RecipientList $SMTPRecipientList `
                        -Subject $EmailSubject `
                        -HtmlBody $htmlBody

                    Write-Verbose "Email notification sent successfully to $($Recipient -join ', ')"
                }
                catch
                {
                    Write-Error "Error sending email notification: $_"
                }
            }
        }
        else
        {
            Write-Verbose "No servers require reboot. Email notification skipped."
        }

        return $result
    }
}



PS C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks> Get-adComputer -Filter 'OperatingSystem -like "*Server*" -and Enabled -eq $true' -Properties Name | Select-Object -ExpandProperty Name | Send-MailForAreboot -Recipient llienhard@cw.fmlogistic.com -Credential (Get-Secret AdmAccount) -Verbose -MaxParallel 20
Write-Error: Error checking reboot status for SGECITWI1 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for VMSDC04 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for ICADC03 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for DSDDC4 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for TDDDC02 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for PHGDC04 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for DUDDC02 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for LPODC03 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for CAW1PDC02 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for CAW1PDC01 : Unable to find type [COMPUTER].
Write-Error: Error checking reboot status for VMSDC03 : Unable to find type [COMPUTER].
