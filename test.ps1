
Import-Module -FullyQualifiedName .\output\module\PSPowerAdminTasks\0.0.1\PSPowerAdminTasks.psm1 -Force

 Get-adComputer -Filter 'OperatingSystem -like "*Server*" -and Enabled -eq $true' -Properties Name | Select-Object -ExpandProperty Name | Send-MailForAreboot -Recipient llienhard@cw.fmlogistic.com -Credential (Get-Secret AdmAccount) -Verbose
