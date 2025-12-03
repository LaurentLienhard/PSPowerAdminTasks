function Write-Log {
    <#
    .SYNOPSIS
    Write log messages to file and optionally to console.

    .DESCRIPTION
    This function writes log messages to a CSV file for audit purposes.

    .PARAMETER LogPath
    Path to the log file

    .PARAMETER Message
    The message to log

    .PARAMETER Severity
    The severity level (Information, Warning, Error)

    .PARAMETER Console
    Whether to also write to console
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$LogPath,

        [Parameter(Mandatory = $true)]
        [String]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [String]$Severity = 'Information',

        [Parameter(Mandatory = $false)]
        [Switch]$Console
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "$timestamp,$Severity,$Message"

    Add-Content -Path $LogPath -Value $logMessage -ErrorAction SilentlyContinue

    if ($Console) {
        Write-Host $Message
    }
}
