<#
    00-LoadTasks.ps1
    Workaround for macOS PowerShell Get-ChildItem issue with .build directory
    This file explicitly loads all task files
#>

# Get the directory where this script is located
$buildTasksDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Explicitly load task files
$taskFiles = @(
    'Deploy-Module.build.ps1',
    'Credential-Helper.build.ps1'
)

foreach ($taskFile in $taskFiles) {
    $filePath = Join-Path $buildTasksDir $taskFile
    if (Test-Path $filePath) {
        "Importing task file: $taskFile" | Write-Verbose
        . $filePath
    }
}
