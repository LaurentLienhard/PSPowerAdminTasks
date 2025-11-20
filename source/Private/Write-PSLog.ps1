function Write-PSLog {
    <#
    .SYNOPSIS
        Writes log messages to file, screen, or Windows Event Log.

    .DESCRIPTION
        The Write-PSLog function provides a flexible logging mechanism that can write to:
        - Log files with automatic rotation
        - Console output with color-coded severity levels
        - Windows Event Log (Windows only)

        It supports different severity levels (Info, Warning, Error) and can write to
        multiple targets simultaneously.

    .PARAMETER Message
        The message to log.

    .PARAMETER Level
        The severity level of the log message. Valid values: Info, Warning, Error.
        Default: Info

    .PARAMETER LogFile
        Path to the log file. If specified, messages will be written to this file.
        The directory will be created if it doesn't exist.

    .PARAMETER ToScreen
        If specified, messages will be written to the console.

    .PARAMETER ToEventLog
        If specified, messages will be written to the Windows Event Log (Windows only).
        Requires the event source to be registered.

    .PARAMETER EventSource
        The event source name for Event Log entries. Only used when ToEventLog is specified.
        Default: PSPowerAdminTasks

    .PARAMETER EventLogName
        The event log name for Event Log entries. Only used when ToEventLog is specified.
        Default: Application

    .PARAMETER NoTimestamp
        If specified, suppresses the timestamp in log file entries.

    .EXAMPLE
        Write-PSLog -Message "Operation completed successfully" -ToScreen

        Writes an informational message to the console.

    .EXAMPLE
        Write-PSLog -Message "Connection failed" -Level Error -LogFile "C:\Logs\app.log" -ToScreen

        Writes an error message to both a log file and the console.

    .EXAMPLE
        Write-PSLog -Message "Service started" -Level Info -ToEventLog -EventSource "MyApp"

        Writes an informational message to the Windows Event Log.

    .EXAMPLE
        Write-PSLog -Message "Disk space low" -Level Warning -LogFile "C:\Logs\app.log" -ToScreen -ToEventLog

        Writes a warning message to log file, console, and Windows Event Log.

    .NOTES
        - Event Log functionality is only available on Windows platforms
        - Event sources must be registered before use (requires administrator privileges)
        - Log files are created with UTF8 encoding
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [String]$Level = 'Info',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$LogFile,

        [Parameter()]
        [Switch]$ToScreen,

        [Parameter()]
        [Switch]$ToEventLog,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$EventSource = 'PSPowerAdminTasks',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$EventLogName = 'Application',

        [Parameter()]
        [Switch]$NoTimestamp
    )

    begin {
        # Prepare timestamp
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        # Map severity levels to Event Log entry types
        $eventLogTypeMap = @{
            'Info'    = 'Information'
            'Warning' = 'Warning'
            'Error'   = 'Error'
        }

        # Map severity levels to Event Log entry IDs
        $eventLogIdMap = @{
            'Info'    = 1000
            'Warning' = 2000
            'Error'   = 3000
        }
    }

    process {
        # Write to log file
        if ($PSBoundParameters.ContainsKey('LogFile')) {
            try {
                # Ensure directory exists
                $logDirectory = Split-Path -Path $LogFile -Parent
                if ($logDirectory -and -not (Test-Path -Path $logDirectory)) {
                    New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-Verbose "Created log directory: $logDirectory"
                }

                # Format log entry
                if ($NoTimestamp) {
                    $logEntry = "[$Level] $Message"
                }
                else {
                    $logEntry = "$timestamp [$Level] $Message"
                }

                # Write to file
                Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
                Write-Verbose "Wrote to log file: $LogFile"
            }
            catch {
                Write-Warning "Failed to write to log file '$LogFile': $_"
            }
        }

        # Write to screen
        if ($ToScreen) {
            $screenMessage = if ($NoTimestamp) {
                "[$Level] $Message"
            }
            else {
                "$timestamp [$Level] $Message"
            }

            switch ($Level) {
                'Info' {
                    Write-Host $screenMessage -ForegroundColor Cyan
                }
                'Warning' {
                    Write-Host $screenMessage -ForegroundColor Yellow
                }
                'Error' {
                    Write-Host $screenMessage -ForegroundColor Red
                }
            }
        }

        # Write to Event Log (Windows only)
        if ($ToEventLog) {
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                try {
                    # Check if event source exists
                    $sourceExists = [System.Diagnostics.EventLog]::SourceExists($EventSource)

                    if (-not $sourceExists) {
                        Write-Warning "Event source '$EventSource' does not exist. Creating it requires administrator privileges."
                        Write-Warning "Run the following command as administrator to create the source:"
                        Write-Warning "New-EventLog -LogName '$EventLogName' -Source '$EventSource'"
                        return
                    }

                    # Write event
                    $eventType = $eventLogTypeMap[$Level]
                    $eventId = $eventLogIdMap[$Level]

                    Write-EventLog -LogName $EventLogName `
                        -Source $EventSource `
                        -EntryType $eventType `
                        -EventId $eventId `
                        -Message $Message `
                        -ErrorAction Stop

                    Write-Verbose "Wrote to Event Log: $EventLogName (Source: $EventSource, Type: $eventType)"
                }
                catch {
                    Write-Warning "Failed to write to Event Log: $_"
                }
            }
            else {
                Write-Warning "Event Log is only available on Windows platforms."
            }
        }

        # If no output target specified, write to Verbose stream
        if (-not $ToScreen -and -not $PSBoundParameters.ContainsKey('LogFile') -and -not $ToEventLog) {
            Write-Verbose "No output target specified. Message: $Message"
        }
    }
}
