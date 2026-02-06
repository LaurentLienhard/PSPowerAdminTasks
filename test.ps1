
Import-Module -FullyQualifiedName .\output\module\PSPowerAdminTasks\0.0.1\PSPowerAdminTasks.psm1 -Force

 Get-adComputer -Filter 'OperatingSystem -like "*Server*" -and Enabled -eq $true' -Properties Name | Select-Object -ExpandProperty Name | Send-MailForAreboot -Recipient llienhard@cw.fmlogistic.com -Credential (Get-Secret AdmAccount) -Verbose


 Deploying module to remote servers...
Found module at: C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\output\module\PSPowerAdminTasks
No credentials provided. Will attempt deployment with current user context.
Tip: Use -Credential parameter or set DEPLOY_CREDENTIAL_PATH environment variable

Deploying to dsdpwinadm.fmlogistic.fr...
Failed to deploy to dsdpwinadm.fmlogistic.fr: Connecting to remote server dsdpwinadm.fmlogistic.fr failed with the following error message : Accès refusé. For more information, see the about_Remote_Troubleshooting Help topic.

Deploying to caw1pwinadm01.fmlogistic.fr...
Failed to deploy to caw1pwinadm01.fmlogistic.fr: Connecting to remote server caw1pwinadm01.fmlogistic.fr failed with the following error message : Accès refusé. For more information, see the about_Remote_Troubleshooting Help topic.
Deployment complete!
Done /deploy_remote/Deploy_Module 00:00:00.8344010
Done /deploy_remote 00:00:20.0834664
WARNING: C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\output\RequiredModules\InvokeBuild\5.14.22\Invoke-Build.ps1:797
Unexpected output: System.Collections.Hashtable.
WARNING: C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\output\RequiredModules\InvokeBuild\5.14.22\Invoke-Build.ps1:797
Unexpected output: System.Collections.Hashtable.
Build succeeded with warnings. 9 tasks, 0 errors, 2 warnings 00:00:21.4616967
