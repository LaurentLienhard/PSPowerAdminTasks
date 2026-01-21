function Get-KerberosTicketRC4 {
    <#
    .SYNOPSIS
        Audits Windows Security event logs to identify Kerberos tickets encrypted with RC4.

    .DESCRIPTION
        This function queries the Security event logs on local and/or remote domain controllers
        to detect Kerberos Service Tickets (TGS) that were issued using RC4 encryption (Event ID 4769).
        It identifies which users and services requested RC4-encrypted tickets and when they occurred.
        RC4 is considered weak encryption and its detection is recommended for security auditing.

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

    .EXAMPLE
        Get-KerberosTicketRC4
        Audits local machine logs for RC4 usage in the last 24 hours.

    .EXAMPLE
        Get-KerberosTicketRC4 -ComputerName DC1, DC2 -Hours 72
        Audits DC1 and DC2 for RC4 usage in the last 3 days.

    .EXAMPLE
        Get-KerberosTicketRC4 -ShowAll
        Shows all Kerberos tickets including those with strong encryption.

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
        [int]$Hours = 24,

        [Parameter()]
        [switch]$ShowAll,

        [Parameter()]
        [switch]$IncludeSuccess
    )

    begin {
        # Calculate the start time for the event log query
        $startTime = (Get-Date).AddHours(-$Hours)

        # XPath filter for Event ID 4769 (Kerberos Service Ticket was requested)
        # Ticket encryption type values:
        # 1 = DES
        # 3 = RC4
        # 17 = AES128
        # 18 = AES256
        if ($ShowAll) {
            $xpathFilter = "*[System[EventID=4769 and TimeCreated[@SystemTime > '$($startTime.ToUniversalTime().ToString('o'))']]]"
        } else {
            # Filter for RC4 specifically (TicketEncryptionType = 0x17 = 23 or 0x18 for RC4-HMAC)
            $xpathFilter = "*[System[EventID=4769 and TimeCreated[@SystemTime > '$($startTime.ToUniversalTime().ToString('o'))']]]"
        }
    }

    process {
        foreach ($computer in $ComputerName) {
            try {
                Write-Verbose "Querying $computer for Kerberos RC4 usage..."

                # Get Security event log entries
                $events = Get-WinEvent -ComputerName $computer -FilterXPath $xpathFilter `
                    -LogName Security -ErrorAction Stop 2>$null | Sort-Object TimeCreated -Descending

                foreach ($eventRecord in $events) {
                    # Parse the event XML to extract details
                    $eventXml = [xml]$eventRecord.ToXml()
                    $eventData = $eventXml.Event.EventData.Data

                    # Extract field values
                    $ticketEncryptionType = $null
                    $clientName = $null
                    $serviceName = $null
                    $clientAddress = $null
                    $status = $null

                    # Map the data fields
                    foreach ($data in $eventData) {
                        switch ($data.Name) {
                            'TicketEncryptionType' { $ticketEncryptionType = [int]$data.'#text' }
                            'ClientName' { $clientName = $data.'#text' }
                            'ServiceName' { $serviceName = $data.'#text' }
                            'ClientAddress' { $clientAddress = $data.'#text' }
                            'Status' { $status = $data.'#text' }
                        }
                    }

                    # Map encryption type to readable name
                    $encryptionTypeMap = @{
                        1  = 'DES-CBC-CRC'
                        3  = 'RC4-HMAC'
                        17 = 'AES128-CTS-HMAC-SHA1-96'
                        18 = 'AES256-CTS-HMAC-SHA1-96'
                        23 = 'RC4-HMAC'
                    }

                    $encryptionTypeName = $encryptionTypeMap[$ticketEncryptionType]
                    if (-not $encryptionTypeName) {
                        $encryptionTypeName = "Unknown ($ticketEncryptionType)"
                    }

                    # Filter results
                    $isRC4 = ($ticketEncryptionType -eq 3 -or $ticketEncryptionType -eq 23)
                    $isSuccess = ($status -eq '0x0')

                    # Skip if not RC4 and not showing all
                    if (-not $ShowAll -and -not $isRC4) {
                        continue
                    }

                    # Skip if not success and not including successes
                    if (-not $IncludeSuccess -and $isSuccess) {
                        continue
                    }

                    # Return the result
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

                if (-not $events) {
                    Write-Verbose "No Kerberos events found on $computer in the last $Hours hours."
                }
            } catch {
                Write-Error "Error querying $computer : $_"
            }
        }
    }
}
