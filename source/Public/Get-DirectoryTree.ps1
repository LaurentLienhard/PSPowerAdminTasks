function Get-DirectoryTree
{
    <#
    .SYNOPSIS
    Get a tree view of directory and file structure from a remote or local server.

    .DESCRIPTION
    Efficiently scans directory structure with support for depth limiting, item filtering,
    and remote execution. Uses optimized iterative traversal instead of recursion for better performance.

    .PARAMETER Path
    Root path to scan

    .PARAMETER ComputerName
    Remote computer to execute on

    .PARAMETER Depth
    Maximum depth to traverse (-1 for unlimited)

    .PARAMETER ItemType
    Filter: Both, Files, or Directories

    .PARAMETER Credential
    Credentials for remote execution

    .PARAMETER TreeView
    Display formatted tree output

    .PARAMETER SkipSize
    Skip size calculation for better performance on large trees
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Path,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [System.String]$ComputerName,

        [Parameter()]
        [ValidateRange(-1, 2147483647)]
        [System.Int32]$Depth = 3,

        [Parameter()]
        [ValidateSet('Both', 'Files', 'Directories')]
        [System.String]$ItemType = 'Both',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter()]
        [Switch]$TreeView,

        [Parameter()]
        [Switch]$SkipSize
    )

    BEGIN
    {
        Write-Verbose ('[{0:O}] Starting Get-DirectoryTree' -f (Get-Date))

        # Helper for display (human-readable size)
        function Get-HumanSize($Bytes) {
            $sizes = "B", "KB", "MB", "GB", "TB"
            if (-not $Bytes -or $Bytes -eq 0) { return "0 B" }
            $i = [Math]::Floor([Math]::Log($Bytes, 1024))
            return "{0:N2} {1}" -f ($Bytes / [Math]::Pow(1024, $i)), $sizes[$i]
        }

        # Parameters for Invoke-Command
        $InvokeParams = @{ ErrorAction = 'Stop' }
        if ($PSBoundParameters.ContainsKey('ComputerName') -and -not [string]::IsNullOrEmpty($ComputerName)) {
            $InvokeParams['ComputerName'] = $ComputerName
        }
        if ($PSBoundParameters.ContainsKey('Credential') -and $Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            $InvokeParams['Credential'] = $Credential
        }

        # --- MAIN SCRIPTBLOCK (OPTIMIZED) ---
        $TreeBuilderScript = {
            param (
                [String]$RootPath,
                [Int32]$MaxDepth,
                [String]$ItemTypeFilter,
                [Bool]$SkipSizeCalc
            )

            # Iterative traversal with Queue to avoid deep recursion
            $queue = [System.Collections.Generic.Queue[PSObject]]::new()
            $sizeCache = @{}

            # Add root path
            $queue.Enqueue([PSCustomObject]@{
                Path  = $RootPath
                Depth = 1
            })

            while ($queue.Count -gt 0) {
                $current = $queue.Dequeue()

                # Check depth limit
                if ($MaxDepth -ne -1 -and $current.Depth -gt $MaxDepth) {
                    continue
                }

                try {
                    # Retrieve items from folder ONLY ONCE
                    $items = @(Get-ChildItem -Path $current.Path -Force -ErrorAction SilentlyContinue)

                    if ($items.Count -eq 0) { continue }

                    foreach ($item in $items) {
                        # Cross-platform type detection (Directory vs File)
                        $isDirectory = ($item.Attributes -band [System.IO.FileAttributes]::Directory) -eq [System.IO.FileAttributes]::Directory

                        # Filter according to user request
                        if ($ItemTypeFilter -eq 'Directories' -and -not $isDirectory) {
                            continue
                        }
                        if ($ItemTypeFilter -eq 'Files' -and $isDirectory) {
                            continue
                        }

                        # Optimized size calculation (with cache)
                        $itemSize = 0
                        if (-not $SkipSizeCalc) {
                            if ($isDirectory) {
                                $cacheKey = $item.FullName
                                if (-not $sizeCache.ContainsKey($cacheKey)) {
                                    try {
                                        $stats = @(Get-ChildItem -Path $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue) |
                                                 Measure-Object -Property Length -Sum
                                        $sizeCache[$cacheKey] = if ($stats.Sum) { $stats.Sum } else { 0 }
                                    }
                                    catch {
                                        $sizeCache[$cacheKey] = 0
                                    }
                                }
                                $itemSize = $sizeCache[$cacheKey]
                            }
                            else {
                                $itemSize = $item.Length
                            }
                        }

                        # Optimized object creation (ordered properties)
                        [PSCustomObject]@{
                            Name          = $item.Name
                            FullName      = $item.FullName
                            Type          = if ($isDirectory) { 'Directory' } else { 'File' }
                            Size          = $itemSize
                            Depth         = $current.Depth
                            LastWriteTime = $item.LastWriteTime
                            Accessible    = $true
                        }

                        # Add to queue if it is a folder (breadth-first traversal)
                        if ($isDirectory) {
                            $queue.Enqueue([PSCustomObject]@{
                                Path  = $item.FullName
                                Depth = $current.Depth + 1
                            })
                        }
                    }
                }
                catch {
                    Write-Warning "Access denied or error on '$($current.Path)': $_"
                }
            }
        }
    }

    PROCESS
    {
        try
        {
            if ($PSCmdlet.ShouldProcess($Path, 'Get directory tree'))
            {
                # Validation (if local)
                if (-not $InvokeParams.ContainsKey('ComputerName')) {
                    if (-not (Test-Path -Path $Path -ErrorAction SilentlyContinue)) {
                        Write-Error "Path not found: $Path"
                        return
                    }
                }

                # Execution (Remote or Local)
                if ($InvokeParams.ContainsKey('ComputerName'))
                {
                    Write-Verbose "Remote execution on $ComputerName"
                    $results = Invoke-Command @InvokeParams -ScriptBlock $TreeBuilderScript -ArgumentList $Path, $Depth, $ItemType, $SkipSize
                }
                else
                {
                    Write-Verbose "Local execution"
                    $results = & $TreeBuilderScript -RootPath $Path -MaxDepth $Depth -ItemTypeFilter $ItemType -SkipSizeCalc $SkipSize
                }

                # --- DISPLAY ---
                if ($results)
                {
                    if ($TreeView)
                    {
                        Write-Information "`nDirectory tree for: $Path" -InformationAction Continue
                        if ($InvokeParams.ContainsKey('ComputerName')) {
                            Write-Information " (sur $($InvokeParams['ComputerName']))" -InformationAction Continue
                        }
                        Write-Information "----------------------------------------" -InformationAction Continue

                        # Direct display by iterating results (without global sort)
                        $resultList = @($results)
                        $resultList | Sort-Object Depth, FullName | ForEach-Object {
                            $Item = $_
                            $SizeStr = if (-not $SkipSize) { Get-HumanSize $Item.Size } else { "N/A" }

                            if ($Item.Depth -eq 1) {
                                Write-Information "$($Item.Name) [$SizeStr]" -InformationAction Continue
                            }
                            else {
                                $Indent = "    |" * ($Item.Depth - 2) + "----"
                                if ($Item.Type -eq 'Directory') {
                                    Write-Information "$Indent $($Item.Name) [$SizeStr]" -InformationAction Continue
                                }
                                else {
                                    Write-Information "$Indent $($Item.Name) ($SizeStr)" -InformationAction Continue
                                }
                            }
                        }
                        Write-Information "" -InformationAction Continue
                    }
                    else
                    {
                        $results | Sort-Object Depth, FullName
                    }
                }
                else
                {
                    Write-Warning "No items found or access denied."
                }
            }
        }
        catch
        {
            Write-Error "Fatal error: $_"
        }
    }
}
