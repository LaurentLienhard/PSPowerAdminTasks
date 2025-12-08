Import-Module PSPowerAdminTasks,Send-MailKitMessage -Force

$gdriveParams = @{
    CertFile       = "D:\Script Powershell\Get Last Update\REST Version\fml-prod-system-auth-c9975d6d4b31.p12"
    CertPassword   = "notasecret"
    Project        = "fml-prod-system-auth"
    ServiceAccount = "system-auth-sa-gdrive-pwsh@fml-prod-system-auth.iam.gserviceaccount.com"
    GDriveFolderId = "1AU-8ddowjYXJ9LF3WNS7pShyreHw0cES"
    SupportsTeamDrives = $true
}

Get-LastUpdate -OnlySupported -UploadToGDriveParams $gdriveParams -SendByMail
