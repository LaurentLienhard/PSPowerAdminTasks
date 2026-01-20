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

    Begin
    {
        Write-Verbose ('[{0:O}] Starting Get-DirectoryTree' -f (Get-Date))

        # Helper pour l'affichage (taille humaine)
        function Get-HumanSize($Bytes) {
            $sizes = "o", "Ko", "Mo", "Go", "To"
            if (-not $Bytes -or $Bytes -eq 0) { return "0 o" }
            $i = [Math]::Floor([Math]::Log($Bytes, 1024))
            return "{0:N2} {1}" -f ($Bytes / [Math]::Pow(1024, $i)), $sizes[$i]
        }

        # Paramètres pour Invoke-Command
        $InvokeParams = @{ ErrorAction = 'Stop' }
        if ($PSBoundParameters.ContainsKey('ComputerName') -and -not [string]::IsNullOrEmpty($ComputerName)) {
            $InvokeParams['ComputerName'] = $ComputerName
        }
        if ($PSBoundParameters.ContainsKey('Credential') -and $Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            $InvokeParams['Credential'] = $Credential
        }

        # --- SCRIPTBLOCK PRINCIPAL (OPTIMISÉ) ---
        $TreeBuilderScript = {
            param (
                [String]$RootPath,
                [Int32]$MaxDepth,
                [String]$ItemTypeFilter,
                [Bool]$SkipSizeCalc
            )

            # Parcours itératif avec Queue pour éviter la récursion profonde
            $queue = [System.Collections.Generic.Queue[PSObject]]::new()
            $sizeCache = @{}

            # Ajouter le chemin racine
            $queue.Enqueue([PSCustomObject]@{
                Path  = $RootPath
                Depth = 1
            })

            while ($queue.Count -gt 0) {
                $current = $queue.Dequeue()

                # Vérification de la profondeur
                if ($MaxDepth -ne -1 -and $current.Depth -gt $MaxDepth) {
                    continue
                }

                try {
                    # Récupération UNE SEULE FOIS des items du dossier
                    $items = @(Get-ChildItem -Path $current.Path -Force -ErrorAction SilentlyContinue)

                    if ($items.Count -eq 0) { continue }

                    foreach ($item in $items) {
                        # Détection cross-platform du type (Directory vs File)
                        $isDirectory = ($item.Attributes -band [System.IO.FileAttributes]::Directory) -eq [System.IO.FileAttributes]::Directory

                        # Filtrage selon la demande utilisateur
                        if ($ItemTypeFilter -eq 'Directories' -and -not $isDirectory) {
                            continue
                        }
                        if ($ItemTypeFilter -eq 'Files' -and $isDirectory) {
                            continue
                        }

                        # Calcul de taille optimisé (avec cache)
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

                        # Création optimisée de l'objet (propriétés ordonnées)
                        [PSCustomObject]@{
                            Name          = $item.Name
                            FullName      = $item.FullName
                            Type          = if ($isDirectory) { 'Directory' } else { 'File' }
                            Size          = $itemSize
                            Depth         = $current.Depth
                            LastWriteTime = $item.LastWriteTime
                            Accessible    = $true
                        }

                        # Ajouter à la queue si c'est un dossier (parcours en largeur)
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

    Process
    {
        try
        {
            if ($PSCmdlet.ShouldProcess($Path, 'Get directory tree'))
            {
                # Vérification (si local)
                if (-not $InvokeParams.ContainsKey('ComputerName')) {
                    if (-not (Test-Path -Path $Path -ErrorAction SilentlyContinue)) {
                        Write-Error "Path not found: $Path"
                        return
                    }
                }

                # Exécution (Remote ou Local)
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

                # --- AFFICHAGE ---
                if ($results)
                {
                    if ($TreeView)
                    {
                        Write-Information "`nArborescence pour : $Path" -InformationAction Continue
                        if ($InvokeParams.ContainsKey('ComputerName')) {
                            Write-Information " (sur $($InvokeParams['ComputerName']))" -InformationAction Continue
                        }
                        Write-Information "----------------------------------------" -InformationAction Continue

                        # Affichage direct en parcourant les résultats (sans sort global)
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
                    Write-Warning "Aucun élément trouvé ou accès refusé."
                }
            }
        }
        catch
        {
            Write-Error "Fatal error: $_"
        }
    }
}
