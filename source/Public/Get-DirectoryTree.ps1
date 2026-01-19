function Get-DirectoryTree
{
    <#
    .SYNOPSIS
    Get a tree view of directory and file structure from a remote or local server

    .DESCRIPTION
    Retrieves a hierarchical tree view of directories and/or files with support for:
    - Remote servers (Windows 2008 through 2025)
    - Configurable search depth
    - Selective retrieval of files, folders, or both
    - Size reporting with error handling (returns 0 for inaccessible items)
    - Detailed tree structure with indentation and formatting

    .PARAMETER Path
    The root path to start the tree view from. Can be a local path or UNC path.

    .PARAMETER ComputerName
    Computer name for remote access. If not specified, local path is used.

    .PARAMETER Depth
    Maximum depth to search. Default is 3 levels. Use -1 for unlimited depth.

    .PARAMETER ItemType
    Type of items to include: 'Both' (default), 'Files', or 'Directories'

    .PARAMETER Credential
    Credential for remote access if required.

    .EXAMPLE
    Get-DirectoryTree -Path "C:\Windows\System32" -Depth 2 -ItemType Directories
    Shows directory structure 2 levels deep

    .EXAMPLE
    Get-DirectoryTree -Path "\\server\share" -ComputerName "server01" -Depth 3 -ItemType Both
    Shows files and folders 3 levels deep on a remote share

    .EXAMPLE
    Get-DirectoryTree -Path "C:\Data" -Depth 5 | Select-Object FullName, Size, Depth
    Shows complete tree with sizes at each level

    .NOTES
    - Items with no access return Size = 0
    - Works with Windows 2008 through 2025
    - Remote access via WinRM required for remote paths
    - Handles permission errors gracefully
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]$Path,

        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [System.String]$ComputerName,

        [Parameter()]
        [ValidateRange(-1, 2147483647)]
        [System.Int32]$Depth = 3,

        [Parameter()]
        [ValidateSet('Both', 'Files', 'Directories')]
        [System.String]$ItemType = 'Both',

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Begin
    {
        Write-Verbose ('[{0:O}] Starting Get-DirectoryTree' -f (Get-Date))
        Write-Verbose ('[{0:O}] Path: {1}, Depth: {2}, ItemType: {3}' -f (Get-Date), $Path, $Depth, $ItemType)

        # Setup session parameters for remote access
        $InvokeParams = @{
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('ComputerName') -and -not [string]::IsNullOrEmpty($ComputerName))
        {
            $InvokeParams['ComputerName'] = $ComputerName
        }

        if ($PSBoundParameters.ContainsKey('Credential') -and $Credential -ne [System.Management.Automation.PSCredential]::Empty)
        {
            $InvokeParams['Credential'] = $Credential
        }

        # Create the tree builder scriptblock
        $TreeBuilderScript = {
            param (
                [String]$RootPath,
                [Int32]$MaxDepth,
                [String]$ItemTypeFilter
            )

            $resultList = @()

            function Invoke-TreeBuilder
            {
                param (
                    [String]$CurrentPath,
                    [Int32]$CurrentDepth,
                    [Int32]$MaxDepth,
                    [String]$ItemTypeFilter
                )

                # Check if we've reached max depth
                if ($MaxDepth -ne -1 -and $CurrentDepth -gt $MaxDepth)
                {
                    return
                }

                try
                {
                    $items = Get-ChildItem -Path $CurrentPath -Force -ErrorAction SilentlyContinue

                    if ($items)
                    {
                        foreach ($item in $items)
                        {
                            # Filter by item type
                            if ($ItemTypeFilter -eq 'Directories' -and -not $item.PSIsContainer)
                            {
                                continue
                            }
                            elseif ($ItemTypeFilter -eq 'Files' -and $item.PSIsContainer)
                            {
                                continue
                            }

                            # Get size safely
                            $itemSize = 0
                            try
                            {
                                if ($item.PSIsContainer)
                                {
                                    # For directories, calculate total size
                                    $itemSize = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                                    if ($null -eq $itemSize)
                                    {
                                        $itemSize = 0
                                    }
                                }
                                else
                                {
                                    $itemSize = $item.Length
                                }
                            }
                            catch
                            {
                                $itemSize = 0
                            }

                            # Create result object
                            $resultObj = [PSCustomObject]@{
                                Name          = $item.Name
                                FullName      = $item.FullName
                                Type          = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
                                Size          = $itemSize
                                Depth         = $CurrentDepth
                                LastWriteTime = $item.LastWriteTime
                                Accessible    = $true
                            }

                            $script:resultList += $resultObj

                            # Recurse into directories
                            if ($item.PSIsContainer -and ($MaxDepth -eq -1 -or $CurrentDepth -lt $MaxDepth))
                            {
                                Invoke-TreeBuilder -CurrentPath $item.FullName -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth -ItemTypeFilter $ItemTypeFilter
                            }
                        }
                    }
                }
                catch
                {
                    Write-Error "Error accessing path '$CurrentPath': $_"
                }
            }

            # Invoke the builder
            Invoke-TreeBuilder -CurrentPath $RootPath -CurrentDepth 1 -MaxDepth $MaxDepth -ItemTypeFilter $ItemTypeFilter

            # Return results
            return $resultList
        }
    }

    Process
    {
        try
        {
            Write-Verbose ('[{0:O}] Processing path: {1}' -f (Get-Date), $Path)

            if ($PSCmdlet.ShouldProcess($Path, 'Get directory tree'))
            {
                # Check if path exists before processing
                if (-not (Test-Path -Path $Path -ErrorAction SilentlyContinue))
                {
                    Write-Error "Path not found: $Path"
                    return
                }

                # Execute tree building (remotely or locally)
                if ($InvokeParams.ContainsKey('ComputerName'))
                {
                    Write-Verbose ('[{0:O}] Invoking tree builder on remote computer: {1}' -f (Get-Date), $ComputerName)
                    $results = Invoke-Command @InvokeParams -ScriptBlock $TreeBuilderScript -ArgumentList $Path, $Depth, $ItemType
                }
                else
                {
                    Write-Verbose ('[{0:O}] Invoking tree builder locally' -f (Get-Date))
                    $results = & $TreeBuilderScript -RootPath $Path -MaxDepth $Depth -ItemTypeFilter $ItemType
                }

                # Output results sorted by path
                if ($results -and $results.Count -gt 0)
                {
                    Write-Verbose ('[{0:O}] Found {1} item(s)' -f (Get-Date), $results.Count)
                    $results | Sort-Object -Property FullName
                }
                else
                {
                    Write-Verbose ('[{0:O}] No items found or path is empty' -f (Get-Date))
                }
            }
        }
        catch
        {
            Write-Error ('[{0:O}] Error in Get-DirectoryTree: {1}' -f (Get-Date), $_.Exception.Message)
        }
    }

    End
    {
        Write-Verbose ('[{0:O}] Completed Get-DirectoryTree' -f (Get-Date))
    }
}
