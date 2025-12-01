Set-RemoteDnsDebugLog: C:\Users\llienhard\Documents\01-DEV\Github\PSPowerAdminTasks\source\Public\Set-RemoteDnsDebugLog.ps1:152:2
Line |
 152 |   Set-RemoteDnsDebugLog -ComputerName ecrdc01 -Credential (Get-Secret  …
     |   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Error configuring DNS on ecrdc01 : Parameter cannot be processed because the parameter name 'EnableLogging' is ambiguous. Possible matches include:
     | -EnableLoggingForRemoteServerEvent -EnableLoggingForPluginDllEvent -EnableLoggingForZoneLoadingEvent -EnableLoggingForLocalLookupEvent -EnableLoggingToFile
     | -EnableLoggingForZoneDataWriteEvent -EnableLoggingForTombstoneEvent -EnableLoggingForRecursiveLookupEvent -EnableLoggingForServerStartStopEvent.
