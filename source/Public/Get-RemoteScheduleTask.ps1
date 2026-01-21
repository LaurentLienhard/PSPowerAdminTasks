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
        (Optional) The number of computers to query simultaneously. Default is 20.
        Increase this value for high-performance networks, decrease it to reduce load.

    .PARAMETER OperationTimeoutSec
        (Optional) Timeout in seconds for CIM operations. Default is 10 seconds.
        Prevents hanging on unresponsive servers.

    .PARAMETER SkipTaskInfo
        (Optional) Skip retrieving runtime task information (LastRunTime, NextRunTime, LastTaskResult).
        Use this flag for faster execution when you only need task definitions.

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
        Version: 2.2 (Optimized for Large Scale - 100s of servers)
        Requires: PowerShell 7.0 or later.
        Requires: Class [ScheduleTask] to be loaded in memory before execution.

        Performance Tips for Large Environments:
        - Use -SkipTaskInfo when you only need task definitions (3-5x faster)
        - Increase -ThrottleLimit to 30-50 for robust networks with high timeout thresholds
        - Use -OperationTimeoutSec 5 for fast-fail on unresponsive servers
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName = "localhost",

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [int]$ThrottleLimit = 20,

        [Parameter()]
        [int]$OperationTimeoutSec = 10,

        [Parameter()]
        [switch]$SkipTaskInfo
    )

    Process {
        # 1. Parallel Processing Phase
        # We send the list of computers into parallel threads
        $ComputerName | ForEach-Object -Parallel {
            $Computer = $_
            $Cred = $using:Credential
            $Skip = $using:SkipTaskInfo
            $Timeout = $using:OperationTimeoutSec

            # Verbose output must be explicit inside parallel blocks
            Write-Verbose "Processing $Computer..."

            $SessionParams = @{
                ComputerName = $Computer
                OperationTimeoutSec = $Timeout
            }
            if ($Cred) { $SessionParams['Credential'] = $Cred }

            try {
                # Create a temporary, lightweight CIM session
                $CimSession = New-CimSession @SessionParams -ErrorAction Stop

                try {
                    # Get Task Definitions - ONLY SELECT NEEDED PROPERTIES (critical optimization)
                    $RawTasks = Get-ScheduledTask -CimSession $CimSession -ErrorAction Stop |
                        Select-Object TaskName, TaskPath, State, Author, @{Name='RunAsUser'; Expression={$_.Principal.UserId}}

                    foreach ($Task in $RawTasks) {
                        # Build base hashtable without task info
                        $TaskData = @{
                            ComputerName   = $Computer
                            TaskName       = $Task.TaskName
                            TaskPath       = $Task.TaskPath
                            State          = $Task.State.ToString()
                            Author         = $Task.Author
                            RunAsUser      = $Task.RunAsUser
                            LastRunTime    = $null
                            NextRunTime    = $null
                            LastTaskResult = $null
                        }

                        # Optional: Get Runtime Info only if not skipped
                        if (-not $Skip) {
                            try {
                                $TaskInfo = Get-ScheduledTaskInfo -TaskName $Task.TaskName -TaskPath $Task.TaskPath -CimSession $CimSession -ErrorAction Stop
                                if ($TaskInfo) {
                                    $TaskData['LastRunTime']    = $TaskInfo.LastRunTime
                                    $TaskData['NextRunTime']    = $TaskInfo.NextRunTime
                                    $TaskData['LastTaskResult'] = $TaskInfo.LastTaskResult.ToString()
                                }
                            } catch {
                                # Silently ignore task info retrieval errors
                            }
                        }

                        # Return the hashtable
                        $TaskData
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

            # Direct assignment (no null checks needed for non-optional properties)
            $TaskObj.ComputerName   = $RawData.ComputerName
            $TaskObj.TaskName       = $RawData.TaskName
            $TaskObj.TaskPath       = $RawData.TaskPath
            $TaskObj.State          = $RawData.State
            $TaskObj.Author         = $RawData.Author
            $TaskObj.RunAsUser      = $RawData.RunAsUser
            $TaskObj.LastRunTime    = $RawData.LastRunTime
            $TaskObj.NextRunTime    = $RawData.NextRunTime
            $TaskObj.LastTaskResult = $RawData.LastTaskResult

            # Output the final typed object
            $TaskObj
        }
    }
}
