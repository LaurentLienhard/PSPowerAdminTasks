function Get-RemoteDhcpScopes
{
    <#
    .SYNOPSIS
        Retrieves DHCP scopes, statistics, and options (Router, DNS, etc.) from a remote server.
    .DESCRIPTION
        Connects to the specified server via WinRM to list IPv4 scopes.
        For each scope, it retrieves:
        - IP Configuration (Range, Subnet Mask)
        - Usage Statistics (Free/Used IPs)
        - Main Options (3=Router, 6=DNS, 15=Domain)
    .PARAMETER ComputerName
        The target DHCP server name.
    .PARAMETER Credential
        Credentials to use for the remote connection.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential
    )

    process
    {
        Write-Verbose "Connecting to DHCP server $ComputerName..."

        $icParams = @{
            ComputerName = $ComputerName
            ErrorAction  = 'Stop'
            ScriptBlock  = {
                # This block runs ON the remote server

                # 1. Retrieve all scopes
                try
                {
                    $scopes = Get-DhcpServerv4Scope -ErrorAction Stop
                }
                catch
                {
                    Write-Error "Unable to list scopes. Verify that the DHCP role is installed on $env:COMPUTERNAME."
                    return
                }

                $results = foreach ($scope in $scopes)
                {
                    # 2. Retrieve statistics (Free/Used IPs)
                    $stats = Get-DhcpServerv4ScopeStatistics -ScopeId $scope.ScopeId

                    # 3. Retrieve OPTIONS for this specific scope
                    # Using SilentlyContinue because some scopes might have no options configured
                    $allOptions = Get-DhcpServerv4OptionValue -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue

                    # --- Extracting Standard Options ---

                    # Option 003: Router (Gateway)
                    # Using -join ', ' in case multiple values exist
                    $optRouter = ($allOptions | Where-Object { $_.OptionId -eq 3 }).Value -join ', '

                    # Option 006: DNS Servers
                    $optDNS = ($allOptions | Where-Object { $_.OptionId -eq 6 }).Value -join ', '

                    # Option 015: DNS Domain Name
                    $optDomain = ($allOptions | Where-Object { $_.OptionId -eq 15 }).Value -join ', '

                    # List IDs of other options present (e.g., 44 WINS, 66/67 PXE) for info
                    $otherOptionsIDs = ($allOptions | Where-Object { $_.OptionId -notin 3, 6, 15 }).OptionId -join ', '

                    # 4. Constructing the Output Object
                    [PSCustomObject]@{
                        ScopeID     = $scope.ScopeId.IPAddressToString
                        Name        = $scope.Name
                        State       = $scope.State

                        # IP Configuration
                        SubnetMask  = $scope.SubnetMask.IPAddressToString
                        StartRange  = $scope.StartRange.IPAddressToString
                        EndRange    = $scope.EndRange.IPAddressToString

                        # DHCP Options
                        Router      = if ($optRouter)
                        {
                            $optRouter
                        }
                        else
                        {
                            "N/A"
                        }
                        DNS         = if ($optDNS)
                        {
                            $optDNS
                        }
                        else
                        {
                            "N/A"
                        }
                        Domain      = if ($optDomain)
                        {
                            $optDomain
                        }
                        else
                        {
                            "N/A"
                        }
                        OtherOptIDs = if ($otherOptionsIDs)
                        {
                            $otherOptionsIDs
                        }
                        else
                        {
                            "-"
                        }

                        # Statistics
                        InUse       = $stats.InUse
                        Free        = $stats.Free
                        Percentage  = "{0:N0}%" -f $stats.PercentageInUse
                    }
                }
                return $results
            }
        }

        # Add credentials if provided
        if ($Credential)
        {
            $icParams.Add('Credential', $Credential)
        }

        try
        {
            # Execute the command
            $data = Invoke-Command @icParams

            # Clean output (remove WinRM technical properties)
            if ($data)
            {
                $data | Select-Object * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
            }
            else
            {
                Write-Warning "No data returned by $ComputerName."
            }
        }
        catch
        {
            Write-Error "Connection error to $ComputerName : $($_.Exception.Message)"
        }
    }
}
