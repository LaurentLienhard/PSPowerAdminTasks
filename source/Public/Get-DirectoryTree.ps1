function Get-DirectoryTree
{
    <#
    .SYNOPSIS
    Get a tree view of directory and file structure from a remote or local server.
    v4 Fix: Filters out directories during size calculation to prevent property errors.
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
        [Switch]$TreeView
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

        # --- SCRIPTBLOCK PRINCIPAL ---
        $TreeBuilderScript = {
            param (
                [String]$RootPath,
                [Int32]$MaxDepth,
                [String]$ItemTypeFilter
            )

            function Get-TreeItems
            {
                param (
                    [String]$CurrentPath,
                    [Int32]$CurrentDepth
                )

                if ($MaxDepth -ne -1 -and $CurrentDepth -gt $MaxDepth) { return }

                try
                {
                    # On récupère le contenu du dossier courant
                    $items = Get-ChildItem -Path $CurrentPath -Force -ErrorAction SilentlyContinue
                    if (-not $items) { return }

                    foreach ($item in $items)
                    {
                        # Filtrage selon la demande utilisateur
                        if ($ItemTypeFilter -eq 'Directories' -and -not $item.PSIsContainer) { continue }
                        if ($ItemTypeFilter -eq 'Files' -and $item.PSIsContainer) { continue }

                        # --- CALCUL DE LA TAILLE (CORRECTION ICI) ---
                        $itemSize = 0
                        try {
                            if ($item.PSIsContainer) {
                                # On ajoute "-File" pour ne mesurer que les fichiers et éviter l'erreur sur les dossiers
                                $stats = Get-ChildItem -Path $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
                                $itemSize = if ($stats.Sum) { $stats.Sum } else { 0 }
                            }
                            else {
                                $itemSize = $item.Length
                            }
                        } catch {
                            $itemSize = 0
                        }

                        # Création de l'objet
                        $resultObj = [PSCustomObject]@{
                            Name          = $item.Name
                            FullName      = $item.FullName
                            Type          = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
                            Size          = $itemSize
                            Depth         = $CurrentDepth
                            LastWriteTime = $item.LastWriteTime
                            Accessible    = $true
                        }

                        # Émission dans le pipeline
                        $resultObj

                        # Récursion
                        if ($item.PSIsContainer)
                        {
                            Get-TreeItems -CurrentPath $item.FullName -CurrentDepth ($CurrentDepth + 1)
                        }
                    }
                }
                catch
                {
                    # On ignore les erreurs d'accès pour ne pas casser l'arbre entier
                    Write-Warning "Access denied or error on '$CurrentPath': $_"
                }
            }

            # Lancement initial
            Get-TreeItems -CurrentPath $RootPath -CurrentDepth 1
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
                    $results = Invoke-Command @InvokeParams -ScriptBlock $TreeBuilderScript -ArgumentList $Path, $Depth, $ItemType
                }
                else
                {
                    Write-Verbose "Local execution"
                    $results = & $TreeBuilderScript -RootPath $Path -MaxDepth $Depth -ItemTypeFilter $ItemType
                }

                # --- AFFICHAGE ---
                if ($results)
                {
                    if ($TreeView)
                    {
                        Write-Host "`nArborescence pour : " -NoNewline
                        Write-Host "$Path" -ForegroundColor Cyan
                        if ($InvokeParams.ContainsKey('ComputerName')) {
                             Write-Host " (sur $($InvokeParams['ComputerName']))" -ForegroundColor Magenta
                        }
                        Write-Host "----------------------------------------" -ForegroundColor DarkGray

                        $results | Sort-Object FullName | ForEach-Object {
                            $Item = $_
                            $SizeStr = Get-HumanSize $Item.Size

                            if ($Item.Depth -eq 1) {
                                Write-Host "$($Item.Name) " -NoNewline -ForegroundColor Cyan
                                Write-Host "[$SizeStr]" -ForegroundColor Green
                            }
                            else {
                                $Indent = "    |" * ($Item.Depth - 2) + "----"
                                if ($Item.Type -eq 'Directory') {
                                    Write-Host "$Indent " -NoNewline -ForegroundColor DarkGray
                                    Write-Host "$($Item.Name) " -NoNewline -ForegroundColor Yellow
                                    Write-Host "[$SizeStr]" -ForegroundColor Green
                                }
                                else {
                                    Write-Host "$Indent " -NoNewline -ForegroundColor DarkGray
                                    Write-Host "$($Item.Name) " -NoNewline -ForegroundColor White
                                    Write-Host "($SizeStr)" -ForegroundColor Gray
                                }
                            }
                        }
                        Write-Host ""
                    }
                    else
                    {
                        $results | Sort-Object FullName
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
