class ScheduleTask
{
    [string]$ComputerName
    [string]$TaskName
    [string]$TaskPath
    [string]$State
    [string]$Author
    [string]$RunAsUser
    [Nullable[DateTime]]$LastRunTime
    [Nullable[DateTime]]$NextRunTime
    [string]$LastTaskResult

    # Empty constructor
    ScheduleTask() {}
}
