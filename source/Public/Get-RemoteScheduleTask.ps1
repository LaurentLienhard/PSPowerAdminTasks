function Get-RemoteScheduleTask {
    <#
    .SYNOPSIS
        Retrieves scheduled tasks from local or remote computers in parallel using PowerShell 7.

    .DESCRIPTION
        This function uses CIM cmdlets (Get-ScheduledTask) to query machines.
        It utilizes 'ForEach-Object -Parallel' to query multiple computers simultaneously,
        drastically reducing execution time when targeting many servers.

        It retrieves both the Task Definition (Name, Path, Author) and the Runtime Information
        (Last Run Time, Next Run Time, Last Result).

        The result is strictly typed to the custom class 'ScheduleTask'.

    .PARAMETER ComputerName
        The name of the target computer(s). Default is "localhost".
        Accepts a string array (e.g., "Server01", "Server02") or pipeline input.

    .PARAMETER Credential
        (Optional) A PSCredential object to use for authentication on remote machines.
        If not specified, the current user credentials are used.

    .PARAMETER ThrottleLimit
        (Optional) The number of computers to query simultaneously. Default is 5.
        Increase this value for high-performance networks, decrease it to reduce load.

    .EXAMPLE
        Get-RemoteScheduleTask -ComputerName "SRV01", "SRV02", "SRV03"

        Queries 3 servers in parallel.

    .EXAMPLE
        Get-Dclist | Select-Object -ExpandProperty Name | Get-RemoteScheduleTask -ThrottleLimit 20

        Queries all domain controllers (from a theoretical Get-Dclist function), running 20 threads at once.

    .EXAMPLE
        $Creds = Get-Secret AdmAccount
        Get-RemoteScheduleTask -ComputerName "SRV-APP" -Credential $Creds | Where-Object { $_.LastTaskResult -ne 0 }

        Checks a specific server for tasks that failed (LastResult != 0).

    .NOTES
        Version: 2.1 (PS7 Parallel + Serialization Fix)
        Requires: PowerShell 7.0 or later.
        Requires: Class [ScheduleTask] to be loaded in memory before execution.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName = "localhost",

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [int]$ThrottleLimit = 5
    )

    Process {
        # 1. Parallel Processing Phase
        # We send the list of computers into parallel threads
        $ComputerName | ForEach-Object -Parallel {
            $Computer = $_
            $Cred = $using:Credential

            # Verbose output must be explicit inside parallel blocks
            Write-Verbose "Processing $Computer..."

            $SessionParams = @{ ComputerName = $Computer }
            if ($Cred) { $SessionParams['Credential'] = $Cred }

            try {
                # Create a temporary, lightweight CIM session
                $CimSession = New-CimSession @SessionParams -ErrorAction Stop

                try {
                    # Get Task Definitions
                    $RawTasks = Get-ScheduledTask -CimSession $CimSession | Select-Object *

                    foreach ($Task in $RawTasks) {

                        # Get Runtime Info (LastRun, NextRun, Result) safely
                        $TaskInfo = $null
                        try {
                            $TaskInfo = Get-ScheduledTaskInfo -TaskName $Task.TaskName -TaskPath $Task.TaskPath -CimSession $CimSession -ErrorAction Stop
                        } catch {
                            # Ignore specific errors for single tasks (e.g. permission issues on one task)
                        }

                        # Return a Hashtable (Lightweight & Thread-Safe)
                        # We do NOT return the Class object here to avoid Deserialization issues between threads.
                        @{
                            ComputerName   = $Computer
                            TaskName       = $Task.TaskName
                            TaskPath       = $Task.TaskPath
                            State          = $Task.State
                            Author         = $Task.Author
                            RunAsUser      = $Task.Principal.UserId
                            LastRunTime    = $TaskInfo.LastRunTime
                            NextRunTime    = $TaskInfo.NextRunTime
                            LastTaskResult = $TaskInfo.LastTaskResult
                        }
                    }
                }
                catch {
                    Write-Error "Error retrieving data from $Computer : $_"
                }
                finally {
                    # Clean up the session to free up ports
                    if ($CimSession) {
                        Get-CimSession -Id $CimSession.Id | Remove-CimSession
                    }
                }
            }
            catch {
                Write-Error "Unable to connect to $Computer : $_"
            }

        } -ThrottleLimit $ThrottleLimit | ForEach-Object {
            # 2. Main Thread Re-hydration Phase
            # We receive the Hashtable from the parallel thread and manually build the Class Object.
            # This prevents the "Cannot convert value... to type ScheduleTask" error.

            $RawData = $_
            $TaskObj = [ScheduleTask]::new()

            # Manual property mapping
            if ($RawData.ComputerName) { $TaskObj.ComputerName = $RawData.ComputerName }
            if ($RawData.TaskName)     { $TaskObj.TaskName     = $RawData.TaskName }
            if ($RawData.TaskPath)     { $TaskObj.TaskPath     = $RawData.TaskPath }
            if ($RawData.State)        { $TaskObj.State        = $RawData.State.ToString() }
            if ($RawData.Author)       { $TaskObj.Author       = $RawData.Author }
            if ($RawData.RunAsUser)    { $TaskObj.RunAsUser    = $RawData.RunAsUser }

            # Safe Date Assignment
            if ($RawData.LastRunTime -is [DateTime]) { $TaskObj.LastRunTime = $RawData.LastRunTime }
            if ($RawData.NextRunTime -is [DateTime]) { $TaskObj.NextRunTime = $RawData.NextRunTime }

            # Safe String Assignment for Result
            if ($null -ne $RawData.LastTaskResult) { $TaskObj.LastTaskResult = $RawData.LastTaskResult.ToString() }

            # Output the final typed object
            $TaskObj
        }
    }
}
