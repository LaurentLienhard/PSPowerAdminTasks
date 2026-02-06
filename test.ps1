
Import-Module -FullyQualifiedName .\output\module\PSPowerAdminTasks\0.0.1\PSPowerAdminTasks.psm1 -Force

 Get-adComputer -Filter 'OperatingSystem -like "*Server*" -and Enabled -eq $true' -Properties Name | Select-Object -ExpandProperty Name | Send-MailForAreboot -Recipient llienhard@cw.fmlogistic.com -Credential (Get-Secret AdmAccount) -Verbose


 PS C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks> .\build.ps1 -Tasks deploy_remote -credential (Get-Secret AdmAccount)
build.ps1: A parameter cannot be found that matches parameter name 'credential'.
