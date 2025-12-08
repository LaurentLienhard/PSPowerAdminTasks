function Get-LastUpdate
{
    [CmdletBinding(DefaultParameterSetName = "ByComputerName")]
    param
    (
        [Parameter(ParameterSetName = "ByComputerName")]
        [System.String[]]$ComputerName,
        [Parameter(ParameterSetName = "OnlySupported")]
        [switch]$OnlySupported,
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

    begin
    {
        $result = @()
    }

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            "ByComputerName"
            {
                foreach ($comp in $ComputerName)
                {
                    Write-Verbose ('[{0:O}] work on {1}' -f ((get-date), $comp))
                    if ($PSBoundParameters.ContainsKey('Credential'))
                    {
                        $obj = [COMPUTER]::new($comp, $Credential)
                    }
                    else
                    {
                        $obj = [COMPUTER]::new($Comp)
                    }
                    $obj.GetALlInformation()
                    $result += $obj
                }
            }
            "OnlySupported"
            {
                $ComputerName = Get-ADComputer -Filter { Enabled -eq "true" } -Properties Name, DistinguishedName, OperatingSystem | Where-Object { (($_.OperatingSystem -like "*Windows*Server*2016*") -or ($_.OperatingSystem -like "*Windows*Server*2019*") -or ($_.OperatingSystem -like "*Windows*Server*2022*")) -and !($_.DistinguishedName -like "*OU=Domain Controllers*") } | Select-Object  -ExpandProperty Name
                if ($PSBoundParameters.ContainsKey('Credential'))
                {
                    $result = Get-LastUpdate -ComputerName $ComputerName -Credential $Credential
                }
                else
                {
                    $result = Get-LastUpdate -ComputerName $ComputerName
                }
            }
        }
    }

    end
    {
        $TodayDate = (Get-Date -f yyyyMMdd_HHmmss)
        $FileName = "$($env:temp)\LastUpdateStatus_$($TodayDate).csv"
        $result | Export-Csv -Path $FileName -NoTypeInformation -Delimiter "," -Encoding UTF8 -Force

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
            $AttachmentList = [System.Collections.Generic.List[string]]::new();
            $AttachmentList.Add($($FileName));

            Send-MailKitMessage -SMTPServer $SMTPServer -port 25 -From $SMTPSender -RecipientList $SMTPRecipientList -CCList $SMTPCCList -Subject $EmailSubject -TextBody $EmailBody -AttachmentList $AttachmentList
        }

        if (!($UploadToGDriveParams) -and !($SendByMail))
        {
            return $result
        }

    }
}
