function Get-LastUpdate
{
    <#
        .SYNOPSIS
            Retrieves the last update information for computers.

        .DESCRIPTION
            Gets the last Windows update installation date and related information from remote computers.
            Optimized for PowerShell 7+ with parallel processing for multiple computers.

        .PARAMETER ComputerName
            Specifies the name of the computer(s) to check. Accepts pipeline input and multiple values.

        .PARAMETER OnlySupported
            Retrieve updates only for supported operating systems (Windows Server 2016, 2019, 2022).

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            Only applicable when processing 10+ computers on PowerShell 7+.

        .PARAMETER TimeoutSeconds
            Timeout in seconds for connection tests. Default is 2 seconds.

        .PARAMETER UploadToGDriveParams
            Parameters for uploading results to Google Drive.

        .PARAMETER SendByMail
            Send the results via email.

        .PARAMETER Credential
            Specifies credentials for remote connections.

        .EXAMPLE
            Get-LastUpdate -ComputerName Server01

        .EXAMPLE
            Get-LastUpdate -ComputerName Server01, Server02 -SendByMail

        .EXAMPLE
            Get-LastUpdate -OnlySupported -ThrottleLimit 64

        .NOTES
            Part of PSPowerAdminTasks module.
            For 10+ computers, PowerShell 7+ uses parallel processing automatically.
    #>
    [CmdletBinding(DefaultParameterSetName = "ByComputerName")]
    param(
        [Parameter(ParameterSetName = "ByComputerName", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName,

        [Parameter(ParameterSetName = "OnlySupported")]
        [switch]$OnlySupported,

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32,

        [Parameter()]
        [ValidateRange(1, 30)]
        [int]$TimeoutSeconds = 2,

        [Parameter()]
        [hashtable]$UploadToGDriveParams,

        [Parameter()]
        [switch]$SendByMail,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN
    {
        # Detect PowerShell version for parallel processing capability
        $useParallel = $PSVersionTable.PSVersion.Major -ge 7
        $results = [System.Collections.Generic.List[PSObject]]::new()

        Write-Verbose "Using parallel processing: $useParallel, ThrottleLimit: $ThrottleLimit"
    }

    PROCESS
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            "ByComputerName"
            {
                if ($useParallel -and $ComputerName.Count -ge 10)
                {
                    # PowerShell 7+ - Parallel processing
                    Write-Verbose "Processing $($ComputerName.Count) computers in parallel..."

                    $ComputerName | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                        $comp = $_
                        $Credential = $using:Credential
                        $TimeoutSeconds = $using:TimeoutSeconds

                        try
                        {
                            Write-Verbose ('[{0:O}] work on {1}' -f ((Get-Date), $comp))

                            # Quick connectivity test
                            if (-not (Test-Connection -ComputerName $comp -Count 1 -TimeoutSeconds $TimeoutSeconds -ErrorAction SilentlyContinue))
                            {
                                Write-Verbose "Skipping $comp - offline"
                                return
                            }

                            if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty)
                            {
                                $obj = [COMPUTER]::new($comp, $Credential)
                            }
                            else
                            {
                                $obj = [COMPUTER]::new($comp)
                            }

                            $obj.GetAllInformation()
                            $obj
                        }
                        catch
                        {
                            Write-Verbose "Error processing $comp : $($_.Exception.Message)"
                        }
                    } | Where-Object { $null -ne $_ } | ForEach-Object {
                        $results.Add($_)
                    }
                }
                else
                {
                    # Sequential processing for PS 5.1 or small counts
                    Write-Verbose "Processing $($ComputerName.Count) computers sequentially..."

                    foreach ($comp in $ComputerName)
                    {
                        try
                        {
                            Write-Verbose ('[{0:O}] work on {1}' -f ((Get-Date), $comp))

                            if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty)
                            {
                                $obj = [COMPUTER]::new($comp, $Credential)
                            }
                            else
                            {
                                $obj = [COMPUTER]::new($comp)
                            }

                            $obj.GetAllInformation()
                            $results.Add($obj)
                        }
                        catch
                        {
                            Write-Error "Error processing $comp : $($_.Exception.Message)"
                        }
                    }
                }
            }

            "OnlySupported"
            {
                try
                {
                    Write-Verbose "Querying Active Directory for supported operating systems..."

                    $adParams = @{ ErrorAction = 'Stop' }
                    if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty)
                    {
                        $adParams['Credential'] = $Credential
                    }

                    $ComputerList = Get-ADComputer -Filter { Enabled -eq $true } -Properties Name, DistinguishedName, OperatingSystem @adParams |
                        Where-Object {
                            (($_.OperatingSystem -like "*Windows*Server*2016*") -or
                             ($_.OperatingSystem -like "*Windows*Server*2019*") -or
                             ($_.OperatingSystem -like "*Windows*Server*2022*")) -and
                            -not ($_.DistinguishedName -like "*OU=Domain Controllers*")
                        } |
                        Select-Object -ExpandProperty Name

                    Write-Verbose "Found $($ComputerList.Count) supported computers"

                    if ($ComputerList)
                    {
                        # Recursive call with parallel processing
                        $getParams = @{
                            ComputerName   = $ComputerList
                            ThrottleLimit  = $ThrottleLimit
                            TimeoutSeconds = $TimeoutSeconds
                        }

                        if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty)
                        {
                            $getParams['Credential'] = $Credential
                        }

                        $results.AddRange((Get-LastUpdate @getParams))
                    }
                }
                catch
                {
                    Write-Error "Error querying Active Directory: $_"
                }
            }
        }
    }

    END
    {
        if ($results.Count -eq 0)
        {
            Write-Verbose "No results to export"
            return
        }

        $TodayDate = (Get-Date -f yyyyMMdd_HHmmss)
        $FileName = "$($env:temp)\LastUpdateStatus_$($TodayDate).csv"

        Write-Verbose "Exporting $($results.Count) results to $FileName"
        $results.ToArray() | Export-Csv -Path $FileName -NoTypeInformation -Delimiter "," -Encoding UTF8 -Force

        if ($UploadToGDriveParams)
        {
            # Ensure the SourceFile key is updated
            $UploadToGDriveParams["SourceFile"] = $FileName

            # Call the function using splatting
            Send-FileToGDrive @UploadToGDriveParams
        }

        if ($SendByMail)
        {
            # Send via email
            $SMTPServer = "smtp.fmlogistic.fr"
            $SMTPSender = [MimeKit.MailboxAddress]"dsdpwinadm@fmlogistic.fr"
            $SMTPRecipientList = [MimeKit.InternetAddressList]::new()
            $SMTPRecipientList.Add([MimeKit.InternetAddress]"llienhard@cw.fmlogistic.com")
            $SMTPRecipientList.Add([MimeKit.InternetAddress]"ddoreau@fmlogistic.com")
            $SMTPRecipientList.Add([MimeKit.InternetAddress]"alerts@rest-solution.com")
            $SMTPCCList = [MimeKit.InternetAddressList]::new()
            $SMTPCCList.Add([MimeKit.InternetAddress]"superadmin-dd@fmlogistic.com")
            $EmailSubject = "Get Last update $TodayDate"
            $EmailBody = "Powershell Script - Get last Update"
            $AttachmentList = [System.Collections.Generic.List[string]]::new()
            $AttachmentList.Add($FileName)

            Send-MailKitMessage -SMTPServer $SMTPServer -Port 25 -From $SMTPSender -RecipientList $SMTPRecipientList -CCList $SMTPCCList -Subject $EmailSubject -TextBody $EmailBody -AttachmentList $AttachmentList
        }

        if (-not $UploadToGDriveParams -and -not $SendByMail)
        {
            return $results.ToArray()
        }
    }
}
