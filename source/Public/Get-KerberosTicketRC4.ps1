function Get-KerberosTicketRC4
{
    <#
        .SYNOPSIS
            Audits Windows Security event logs to identify Kerberos tickets encrypted with RC4.

        .DESCRIPTION
            This function queries the Security event logs on local and/or remote domain controllers
            to detect Kerberos Service Tickets (TGS) that were issued using RC4 encryption (Event ID 4769).
            It identifies which users and services requested RC4-encrypted tickets and when they occurred.
            RC4 is considered weak encryption and its detection is recommended for security auditing.
            Optimized for PowerShell 7+ with parallel processing for multiple computers.

        .PARAMETER ComputerName
            Specifies the computer(s) to audit (typically Domain Controllers).
            By default, queries the local machine.
            Accepts pipeline input for multiple computers.

        .PARAMETER Hours
            Number of hours back to audit from the current time.
            Default is 24 hours.

        .PARAMETER ShowAll
            Shows all Kerberos Service Ticket requests including non-RC4 ones.
            By default, only RC4 tickets are returned.

        .PARAMETER IncludeSuccess
            Includes successful Kerberos operations. By default, only failures related to RC4 are shown.

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            Only applicable when processing 10+ computers on PowerShell 7+.

        .EXAMPLE
            Get-KerberosTicketRC4
            Audits local machine logs for RC4 usage in the last 24 hours.

        .EXAMPLE
            Get-KerberosTicketRC4 -ComputerName DC1, DC2, DC3, DC4, DC5 -Hours 72 -ThrottleLimit 64
            Audits 5 DCs in parallel for RC4 usage in the last 3 days.

        .OUTPUTS
            PSCustomObject with the following properties:
            - TimeCreated: When the Kerberos ticket was requested
            - ClientName: User or account that requested the ticket
            - ServiceName: Service that was requested
            - EncryptionType: Encryption algorithm used (RC4, AES256, etc.)
            - TicketEncryptionType: Numeric encryption type value
            - ClientAddress: IP address of the requester
            - Status: Success or error status
            - EventID: Windows event ID
            - ComputerName: Computer where the event was logged
    #>
    [CmdletBinding(SupportsShouldProcess = $false)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateRange(1, 365)]
        [int]$Hours = 24,

        [Parameter()]
        [switch]$ShowAll,

        [Parameter()]
        [switch]$IncludeSuccess,

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32
    )

    BEGIN
    {
        # Calculate the start time for the event log query
        $startTime = (Get-Date).AddHours(-$Hours)

        # Detect PowerShell version for parallel processing capability
        $useParallel = ($PSVersionTable.PSVersion.Major -ge 7) -and ($ComputerName.Count -ge 10)

        if (-not $useParallel -and ($PSVersionTable.PSVersion.Major -lt 7) -and ($ComputerName.Count -ge 10))
        {
            Write-Verbose "Running on PowerShell 5.1 with 10+ computers. Consider upgrading to PowerShell 7+ for parallel processing."
        }

        Write-Verbose "Processing $($ComputerName.Count) computers. Parallel: $useParallel, ThrottleLimit: $ThrottleLimit"

        # XPath filter for Event ID 4769 (Kerberos Service Ticket was requested)
        # Ticket encryption type values: 1=DES, 3=RC4, 17=AES128, 18=AES256
        if ($ShowAll)
        {
            $xpathFilter = "*[System[EventID=4769 and TimeCreated[@SystemTime > '$($startTime.ToUniversalTime().ToString('o'))']]]"
        }
        else
        {
            $xpathFilter = "*[System[EventID=4769 and TimeCreated[@SystemTime > '$($startTime.ToUniversalTime().ToString('o'))']]]"
        }

        # Encryption type mapping
        $encryptionTypeMap = @{
            1  = 'DES-CBC-CRC'
            3  = 'RC4-HMAC'
            17 = 'AES128-CTS-HMAC-SHA1-96'
            18 = 'AES256-CTS-HMAC-SHA1-96'
            23 = 'RC4-HMAC'
        }
    }

    PROCESS
    {
        if ($useParallel)
        {
            # PowerShell 7+ - Parallel processing
            $ComputerName | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                $computer = $_
                $xpathFilter = $using:xpathFilter
                $ShowAll = $using:ShowAll
                $IncludeSuccess = $using:IncludeSuccess
                $Hours = $using:Hours
                $encryptionTypeMap = $using:encryptionTypeMap

                try
                {
                    Write-Verbose "Querying $computer for Kerberos RC4 usage..."

                    $events = Get-WinEvent -ComputerName $computer -FilterXPath $xpathFilter `
                        -LogName Security -ErrorAction Stop 2>$null | Sort-Object TimeCreated -Descending

                    foreach ($eventRecord in $events)
                    {
                        $eventXml = [xml]$eventRecord.ToXml()
                        $eventData = $eventXml.Event.EventData.Data

                        $ticketEncryptionType = $null
                        $clientName = $null
                        $serviceName = $null
                        $clientAddress = $null
                        $status = $null

                        foreach ($data in $eventData)
                        {
                            switch ($data.Name)
                            {
                                'TicketEncryptionType' { $ticketEncryptionType = [int]$data.'#text' }
                                'ClientName' { $clientName = $data.'#text' }
                                'ServiceName' { $serviceName = $data.'#text' }
                                'ClientAddress' { $clientAddress = $data.'#text' }
                                'Status' { $status = $data.'#text' }
                            }
                        }

                        $encryptionTypeName = $encryptionTypeMap[$ticketEncryptionType]
                        if (-not $encryptionTypeName)
                        {
                            $encryptionTypeName = "Unknown ($ticketEncryptionType)"
                        }

                        $isRC4 = ($ticketEncryptionType -eq 3 -or $ticketEncryptionType -eq 23)
                        $isSuccess = ($status -eq '0x0')

                        if (-not $ShowAll -and -not $isRC4)
                        {
                            continue
                        }

                        if (-not $IncludeSuccess -and $isSuccess)
                        {
                            continue
                        }

                        [PSCustomObject]@{
                            TimeCreated          = $eventRecord.TimeCreated
                            ClientName           = $clientName
                            ServiceName          = $serviceName
                            EncryptionType       = $encryptionTypeName
                            TicketEncryptionType = $ticketEncryptionType
                            ClientAddress        = $clientAddress
                            Status               = $status
                            EventID              = $eventRecord.Id
                            ComputerName         = $computer
                        }
                    }

                    if (-not $events)
                    {
                        Write-Verbose "No Kerberos events found on $computer in the last $Hours hours."
                    }
                }
                catch
                {
                    Write-Verbose "Error querying $computer : $_"
                }
            } | Where-Object { $null -ne $_ }
        }
        else
        {
            # Sequential processing for PS 5.1 or small counts
            Write-Verbose "Processing $($ComputerName.Count) computers sequentially..."

            foreach ($computer in $ComputerName)
            {
                try
                {
                    Write-Verbose "Querying $computer for Kerberos RC4 usage..."

                    $events = Get-WinEvent -ComputerName $computer -FilterXPath $xpathFilter `
                        -LogName Security -ErrorAction Stop 2>$null | Sort-Object TimeCreated -Descending

                    foreach ($eventRecord in $events)
                    {
                        $eventXml = [xml]$eventRecord.ToXml()
                        $eventData = $eventXml.Event.EventData.Data

                        $ticketEncryptionType = $null
                        $clientName = $null
                        $serviceName = $null
                        $clientAddress = $null
                        $status = $null

                        foreach ($data in $eventData)
                        {
                            switch ($data.Name)
                            {
                                'TicketEncryptionType' { $ticketEncryptionType = [int]$data.'#text' }
                                'ClientName' { $clientName = $data.'#text' }
                                'ServiceName' { $serviceName = $data.'#text' }
                                'ClientAddress' { $clientAddress = $data.'#text' }
                                'Status' { $status = $data.'#text' }
                            }
                        }

                        $encryptionTypeName = $encryptionTypeMap[$ticketEncryptionType]
                        if (-not $encryptionTypeName)
                        {
                            $encryptionTypeName = "Unknown ($ticketEncryptionType)"
                        }

                        $isRC4 = ($ticketEncryptionType -eq 3 -or $ticketEncryptionType -eq 23)
                        $isSuccess = ($status -eq '0x0')

                        if (-not $ShowAll -and -not $isRC4)
                        {
                            continue
                        }

                        if (-not $IncludeSuccess -and $isSuccess)
                        {
                            continue
                        }

                        [PSCustomObject]@{
                            TimeCreated          = $eventRecord.TimeCreated
                            ClientName           = $clientName
                            ServiceName          = $serviceName
                            EncryptionType       = $encryptionTypeName
                            TicketEncryptionType = $ticketEncryptionType
                            ClientAddress        = $clientAddress
                            Status               = $status
                            EventID              = $eventRecord.Id
                            ComputerName         = $computer
                        }
                    }

                    if (-not $events)
                    {
                        Write-Verbose "No Kerberos events found on $computer in the last $Hours hours."
                    }
                }
                catch
                {
                    Write-Error "Error querying $computer : $_"
                }
            }
        }
    }
}
