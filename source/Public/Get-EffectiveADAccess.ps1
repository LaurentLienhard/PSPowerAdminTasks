function Get-EffectiveADAccess
{
<#
.SYNOPSIS
    Retrieves effective permissions (ACL) for a user or group on an Active Directory object.

.DESCRIPTION
    This function analyzes the Access Control List (ACL) of an AD object to determine if a specific user or group has permissions on it.

    Advanced Features:
    1. GUID Translation: Converts technical IDs (e.g., bf967a86...) into readable names (e.g., Computer, User).
    2. Group Recursivity: If querying a User, it calculates all their group memberships (including nested groups) to find indirect permissions.
    3. Smart Lookup (ANR): Accepts long names, email addresses, UPNs, or sAMAccountNames without crashing.
    4. "Via" Column: Clearly shows if a permission comes from a direct assignment or via a specific group.

.PARAMETER Identity
    The target AD object to check permissions on (e.g., an OU, a Computer).
    Accepts DistinguishedName, ObjectGUID, or Name.

.PARAMETER Principal
    The User or Group to check permissions for.
    Accepts sAMAccountName, Common Name (CN), UPN, or Email.

.PARAMETER Server
    Optional: Specific Active Directory server to connect to.

.PARAMETER Credential
    Optional: Credentials to use for the AD connection.

.EXAMPLE
    Get-EffectiveADAccess -Identity "OU=_Sleeping Computers,DC=dom,DC=com" -Principal "admin1"

    Checks what permissions user 'admin1' has on the specified OU (including permissions via groups).

.EXAMPLE
    Get-EffectiveADAccess -Identity "CN=PC-001,OU=Workstations,DC=dom,DC=com" -Principal "HelpDesk Group" | Format-Table -AutoSize

    Checks effective permissions for the HelpDesk group on a specific PC.

.NOTES
    Version: 1.6 (Final Robust - English)
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Identity,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Principal,

        [Parameter()][string]$Server,
        [Parameter()][pscredential]$Credential
    )

    Begin
    {
        # --- HELPER: GUID to Readable Name Mapping ---
        $GuidMap = @{
            'bf967a86-0de6-11d0-a285-00aa003049e2' = 'Computer'
            'bf967aba-0de6-11d0-a285-00aa003049e2' = 'User'
            'bf967a9c-0de6-11d0-a285-00aa003049e2' = 'Group'
            'bf967ab2-0de6-11d0-a285-00aa003049e2' = 'OrganizationalUnit'
            'bf967aa5-0de6-11d0-a285-00aa003049e2' = 'PrintQueue'
            'bf967aa8-0de6-11d0-a285-00aa003049e2' = 'Volume'
            '00000000-0000-0000-0000-000000000000' = 'Any Object/Self'
        }

        # Connection Setup
        $ConnParams = @{}
        if ($PSBoundParameters['Server']) { $ConnParams['Server'] = $Server }
        if ($PSBoundParameters['Credential']) { $ConnParams['Credential'] = $Credential }
    }

    Process
    {
        try
        {
            # 1. Resolve Target Object
            $ADObject = Get-ADObject -Identity $Identity @ConnParams -ErrorAction Stop

            # 2. Resolve Principal (Who?) - Smart Lookup
            Write-Verbose "Looking for Principal: $Principal"
            $PrincipalObj = $null

            # Attempt 1: Direct User
            try { $PrincipalObj = Get-ADUser -Identity $Principal @ConnParams -ErrorAction Stop } catch {}

            # Attempt 2: Direct Group
            if (-not $PrincipalObj) { try { $PrincipalObj = Get-ADGroup -Identity $Principal @ConnParams -ErrorAction Stop } catch {} }

            # Attempt 3: ANR Filter (Ambiguous Name Resolution) for long names/emails
            if (-not $PrincipalObj) {
                $PrincipalObj = Get-ADObject -Filter "anr -eq '$Principal'" @ConnParams -ErrorAction SilentlyContinue | Select-Object -First 1
                # Reload full object to get properties
                if ($PrincipalObj -and $PrincipalObj.ObjectClass -eq 'user') { $PrincipalObj = Get-ADUser -Identity $PrincipalObj.DistinguishedName @ConnParams }
                elseif ($PrincipalObj -and $PrincipalObj.ObjectClass -eq 'group') { $PrincipalObj = Get-ADGroup -Identity $PrincipalObj.DistinguishedName @ConnParams }
            }

            if (-not $PrincipalObj) { throw "Principal '$Principal' not found. Please check spelling." }

            # 3. Build Identity List (User + All Groups)
            $IdentitiesToCheck = @()
            if ($PrincipalObj.Sid) { $IdentitiesToCheck += $PrincipalObj.Sid.Value }
            if ($PrincipalObj.SamAccountName) { $IdentitiesToCheck += $PrincipalObj.SamAccountName }
            if ($PrincipalObj.Name) { $IdentitiesToCheck += $PrincipalObj.Name }

            if ($PrincipalObj.ObjectClass -eq 'user') {
                Write-Verbose "Calculating recursive group membership..."
                try {
                    # Tightly wrapped to prevent 'null-valued expression' on weird groups
                    $UserGroups = Get-ADAccountAuthorizationGroup -Identity $PrincipalObj.DistinguishedName @ConnParams -ErrorAction Stop

                    if ($UserGroups) {
                        foreach ($grp in $UserGroups) {
                            if ($grp.Sid) { $IdentitiesToCheck += $grp.Sid.Value }
                            if ($grp.SamAccountName) { $IdentitiesToCheck += $grp.SamAccountName }

                            # Add "DOMAIN\Group" format
                            if ($grp.DistinguishedName -and $grp.DistinguishedName -match ',DC=') {
                                try {
                                    $DomainPart = $grp.DistinguishedName.Split(',DC=')[1].ToUpper()
                                    $IdentitiesToCheck += "$DomainPart\$($grp.SamAccountName)"
                                } catch {}
                            }
                        }
                    }
                }
                catch {
                    Write-Verbose "Group calculation warning (non-critical): $_"
                }
            }

            # 4. Get and Scan ACL
            $ACL = Get-ACL -Path "AD:\$($ADObject.DistinguishedName)"
            if (-not $ACL.Access) { return }

            $Effective = @()

            foreach ($ACE in $ACL.Access)
            {
                $IsMatch = $false
                $AceIdentity = $ACE.IdentityReference.Value

                # Check if ACE is in our list
                if ($IdentitiesToCheck -contains $AceIdentity) { $IsMatch = $true }
                else {
                    # Fallback check for ShortName (Group vs DOMAIN\Group)
                    $AceShortName = $AceIdentity.Split('\')[-1]
                    if ($IdentitiesToCheck -contains $AceShortName) { $IsMatch = $true }
                }

                if ($IsMatch)
                {
                    # Translation Logic
                    $Type = $GuidMap[$ACE.ObjectType.ToString()]
                    if (-not $Type) { $Type = if($ACE.ObjectType -eq '00000000-0000-0000-0000-000000000000') {"All Objects"} else {$ACE.ObjectType} }

                    $Scope = "This object only"
                    if ($ACE.InheritanceFlags -ne 'None') { $Scope = "This object and descendants" }
                    if ($ACE.PropagationFlags -eq 'InheritOnly') { $Scope = "Descendants only" }

                    # Determine 'Via' (Did it come from a group?)
                    $Via = "Direct Assignment"
                    $AceShortName = $AceIdentity.Split('\')[-1]
                    if ($PrincipalObj.ObjectClass -eq 'user' -and $AceShortName -ne $PrincipalObj.SamAccountName) {
                        $Via = "Group: $AceShortName"
                    }

                    $Effective += [PSCustomObject]@{
                        'Principal'   = $PrincipalObj.Name
                        'Via'         = $Via
                        'Access'      = $ACE.AccessControlType
                        'Permissions' = $ACE.ActiveDirectoryRights
                        'AppliesTo'   = $Type
                        'Scope'       = $Scope
                    }
                }
            }

            if ($Effective) { $Effective } else { Write-Verbose "No effective permissions found." }
        }
        catch { Write-Error $_.Exception.Message }
    }
}
