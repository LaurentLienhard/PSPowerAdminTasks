function Set-RemoteDnsDebugLog
{
    <#
    .SYNOPSIS
        Enables or disables Debug Logging (packet logging) on a remote DNS server.

    .DESCRIPTION
        This function configures the diagnostic options for a DNS server.
        It allows setting the log file path, maximum size, and enabling/disabling capture.
        By default, it enables capture for:
        - Protocols: UDP and TCP
        - Direction: Inbound and Outbound
        - Content: Queries, Transfers, Updates
        - Type: Requests and Responses

    .PARAMETER ComputerName
        The name or IP address of the target DNS server.

    .PARAMETER Credential
        PSCreadential object to authenticate against the remote server.
        If not specified, the current user credentials are used.

    .PARAMETER LogFilePath
        The ABSOLUTE path of the log file on the REMOTE server (e.g., C:\Logs\dns_debug.log).
        The folder must exist on the remote server.

    .PARAMETER MaxSize
        Maximum file size in bytes. Default: 500MB (500000000).

    .PARAMETER Disable
        If this switch is used, Debug Logging will be disabled on the target server.

    .EXAMPLE
        Set-RemoteDnsDebugLog -ComputerName "SRV-DNS01" -LogFilePath "C:\DnsLogs\debug.log"
        Enables logging on SRV-DNS01 and stores the file in C:\DnsLogs\ on that server.

    .EXAMPLE
        $cred = Get-Credential
        Set-RemoteDnsDebugLog -ComputerName "SRV-DNS01" -LogFilePath "C:\Logs\dns.log" -Credential $cred
        Enables logging using specific credentials.

    .EXAMPLE
        Set-RemoteDnsDebugLog -ComputerName "SRV-DNS01" -Disable
        Disables logging on SRV-DNS01.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
        [ValidateNotNullOrEmpty()]
        [string]$LogFilePath,

        [Parameter(ParameterSetName = "Enable")]
        [int64]$MaxSize = 500000000, # 500MB default

        [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
        [switch]$Disable
    )

    process
    {
        Write-Verbose "Connecting to DNS server: $ComputerName"

        # Check for RSAT DNS module
        if (-not (Get-Module -Name DnsServer -ListAvailable))
        {
            Write-Error "The 'DnsServer' PowerShell module (RSAT) is not installed on this machine."
            return
        }

        $Session = $null

        try
        {
            # Handle Credentials by creating a CIM Session if needed
            # Set-DnsServerDiagnostics does not have a -Credential parameter, it uses -CimSession
            $cmdletParams = @{}

            if ($Credential)
            {
                Write-Verbose "Creating CIM Session with provided credentials..."
                $SessionParams = @{
                    ComputerName = $ComputerName
                    Credential   = $Credential
                }
                $Session = New-CimSession @SessionParams -ErrorAction Stop
                $cmdletParams['CimSession'] = $Session
            }
            else
            {
                $cmdletParams['ComputerName'] = $ComputerName
            }

            if ($Disable)
            {
                # Disable Logging
                if ($PSCmdlet.ShouldProcess($ComputerName, "Disable DNS Debug Logging"))
                {
                    $cmdletParams['EnableLoggingToFile'] = $false

                    Set-DnsServerDiagnostics @cmdletParams -ErrorAction Stop
                    Write-Host "[-] Debug Logging successfully disabled on $ComputerName." -ForegroundColor Cyan
                }
            }
            else
            {
                # Enable Logging
                # Add Enable-specific parameters to the hashtable
                $cmdletParams['EnableLoggingToFile'] = $true
                $cmdletParams['LogFilePath'] = $LogFilePath
                $cmdletParams['MaxLogFileSize'] = $MaxSize

                # Enable logging for common diagnostic events
                $cmdletParams['EnableLoggingForLocalLookupEvent'] = $true
                $cmdletParams['EnableLoggingForRemoteServerEvent'] = $true
                $cmdletParams['EnableLoggingForRecursiveLookupEvent'] = $true
                $cmdletParams['EnableLoggingForZoneLoadingEvent'] = $true

                if ($PSCmdlet.ShouldProcess($ComputerName, "Enable Debug Logging to $LogFilePath"))
                {
                    Write-Verbose "Applying configuration..."
                    Set-DnsServerDiagnostics @cmdletParams -ErrorAction Stop

                    Write-Host "[+] Debug Logging enabled on $ComputerName" -ForegroundColor Green
                    Write-Host "    File path: $LogFilePath" -ForegroundColor Gray
                    Write-Host "    Max Size : $([math]::Round($MaxSize / 1MB, 2)) MB" -ForegroundColor Gray
                }
            }
        }
        catch
        {
            Write-Error "Error configuring DNS on $ComputerName : $($_.Exception.Message)"
        }
        finally
        {
            # Clean up CIM Session if created
            if ($Session)
            {
                Write-Verbose "Removing CIM Session..."
                Remove-CimSession -CimSession $Session -ErrorAction SilentlyContinue
            }
        }
    }
}