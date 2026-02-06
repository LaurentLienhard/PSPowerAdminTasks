
Import-Module -FullyQualifiedName .\output\module\PSPowerAdminTasks\0.0.1\PSPowerAdminTasks.psm1 -Force

 Get-adComputer -Filter 'OperatingSystem -like "*Server*" -and Enabled -eq $true' -Properties Name | Select-Object -ExpandProperty Name | Send-MailForAreboot -Recipient llienhard@cw.fmlogistic.com -Credential (Get-Secret AdmAccount) -Verbose


 Deploying module to remote servers...
Found module at: C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\output\module\PSPowerAdminTasks
No servers configured in C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\.build\deploy-servers.ps1
ERROR: Server list is empty
At C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\.build\Deploy-Module.build.ps1:45 char:9
+         throw "Server list is empty"
+         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
At C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\.build\Deploy-Module.build.ps1:7 char:1
+ task Deploy_Module {
+ ~~~~~~~~~~~~~~~~~~~~
WARNING: C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\output\RequiredModules\InvokeBuild\5.14.22\Invoke-Build.ps1:797
Unexpected output: System.Collections.Hashtable System.Collections.Hashtable.
Build FAILED. 9 tasks, 1 errors, 1 warnings 00:00:21.4835906
Exception: C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\.build\Deploy-Module.build.ps1:45:9
Line |
  45 |          throw "Server list is empty"
     |          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Server list is empty
PS C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks>
