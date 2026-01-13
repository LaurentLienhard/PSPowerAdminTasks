
function Get-EffectiveADAccess
{
    <#
    .SYNOPSIS
    Get effective permissions for a user or group on an Active Directory object

    .DESCRIPTION
    Retrieves the effective permissions (Access Control List) for a specified user or group
    on an Active Directory object. This includes direct permissions and inherited permissions
    from parent containers.

    The function analyzes:
    - Direct ACE (Access Control Entry) assignments
    - Inherited permissions from organizational unit structure
    - Group membership implications
    - Special permissions (Create, Delete, Modify, etc.)

    .PARAMETER Identity
    The identity of the AD object to analyze (user, group, computer, OU, etc.)
    Can be specified as Distinguished Name, ObjectGUID, or sAMAccountName

    .PARAMETER Principal
    The user or group to check permissions for
    Can be specified as Distinguished Name, ObjectGUID, sAMAccountName, or UPN

    .PARAMETER Server
    Active Directory server to connect to (by default the current domain controller)

    .PARAMETER Credential
    Administrator credential to connect to Active Directory

    .EXAMPLE
    Get-EffectiveADAccess -Identity "CN=Users,DC=contoso,DC=com" -Principal "contoso\Domain Admins"
    Get effective permissions for Domain Admins group on the Users container

    .EXAMPLE
    Get-EffectiveADAccess -Identity "CN=john.doe,CN=Users,DC=contoso,DC=com" -Principal "john.doe"
    Get effective permissions for user john.doe on their own user object

    .EXAMPLE
    Get-ADUser -Identity john.doe | Get-EffectiveADAccess -Principal "Domain Users"
    Get effective permissions for Domain Users group on a specific user account

    .NOTES
    Requires:
    - Active Directory PowerShell module
    - Permissions to read AD objects and their security descriptors
    - Access to the object's SACL/DACL (requires administrative privileges for some objects)
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('DistinguishedName', 'DN')]
        [System.String]$Identity,

        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]$Principal,

        [Parameter()]
        [System.String]$Server,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Begin
    {
        Write-Verbose ('[{0:O}] Starting Get-EffectiveADAccess' -f (Get-Date))

        # Setup AD parameters
        $ADParams = @{
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('Server'))
        {
            $ADParams['Server'] = $Server
        }

        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $ADParams['Credential'] = $Credential
        }

        Write-Verbose ('[{0:O}] Connecting to Active Directory' -f (Get-Date))
    }

    Process
    {
        try
        {
            # Resolve the target AD object
            Write-Verbose ('[{0:O}] Resolving AD object: {1}' -f (Get-Date), $Identity)
            $ADObject = Get-ADObject -Identity $Identity @ADParams

            if (-not $ADObject)
            {
                throw "Could not find AD object: $Identity"
            }

            Write-Verbose ('[{0:O}] Found AD object: {1}' -f (Get-Date), $ADObject.DistinguishedName)

            # Resolve the principal
            Write-Verbose ('[{0:O}] Resolving principal: {1}' -f (Get-Date), $Principal)
            $PrincipalObject = $null

            try
            {
                $PrincipalObject = Get-ADUser -Identity $Principal @ADParams -ErrorAction SilentlyContinue
            }
            catch { Write-Verbose 'Command failed, continuing...' }

            if (-not $PrincipalObject)
            {
                try
                {
                    $PrincipalObject = Get-ADGroup -Identity $Principal @ADParams -ErrorAction SilentlyContinue
                }
                catch { Write-Verbose 'Command failed, continuing...' }
            }

            if (-not $PrincipalObject)
            {
                throw "Could not resolve principal: $Principal"
            }

            Write-Verbose ('[{0:O}] Resolved principal: {1}' -f (Get-Date), $PrincipalObject.DistinguishedName)

            # Get security descriptor
            Write-Verbose ('[{0:O}] Retrieving security descriptor' -f (Get-Date))
            $ACLPath = "AD:\$($ADObject.DistinguishedName)"
            $ACL = Get-ACL -Path $ACLPath
            $SecurityDescriptor = $ACL.Access

            if (-not $SecurityDescriptor)
            {
                Write-Warning ('[{0:O}] No security descriptor found for {1}' -f (Get-Date), $ADObject.DistinguishedName)
                return
            }

            # Process ACEs
            $EffectivePermissions = @()

            foreach ($ACE in $SecurityDescriptor)
            {
                # Check if this ACE applies to the principal or their groups
                $AppliesTo = $false

                if ($ACE.IdentityReference.Value -eq $PrincipalObject.SamAccountName -or
                    $ACE.IdentityReference.Value -eq $PrincipalObject.UserPrincipalName -or
                    $ACE.IdentityReference -like "*$($PrincipalObject.Name)*")
                {
                    $AppliesTo = $true
                }
                else
                {
                    # Check group membership if principal is a user
                    if ($PrincipalObject.ObjectClass -eq 'user')
                    {
                        try
                        {
                            $PrincipalGroups = Get-ADPrincipalGroupMembership -Identity $PrincipalObject.DistinguishedName @ADParams -ErrorAction SilentlyContinue
                            if ($PrincipalGroups -and ($PrincipalGroups.DistinguishedName -contains $ACE.IdentityReference.Value -or
                                $PrincipalGroups.SamAccountName -contains ($ACE.IdentityReference.Value -split '\\')[1]))
                            {
                                $AppliesTo = $true
                            }
                        }
                        catch
                        {
                            Write-Verbose ('[{0:O}] Could not retrieve group membership: {1}' -f (Get-Date), $_.Exception.Message)
                        }
                    }
                }

                if ($AppliesTo)
                {
                    $PermissionObject = [PSCustomObject]@{
                        ADObject            = $ADObject.DistinguishedName
                        Principal           = $PrincipalObject.Name
                        PrincipalType       = $PrincipalObject.ObjectClass
                        IdentityReference   = $ACE.IdentityReference.Value
                        AccessControlType   = $ACE.AccessControlType
                        ActiveDirectoryRights = $ACE.ActiveDirectoryRights
                        InheritanceFlags    = $ACE.InheritanceFlags
                        PropagationFlags    = $ACE.PropagationFlags
                        IsInherited         = $ACE.IsInherited
                        ObjectType          = $ACE.ObjectType
                        InheritedObjectType = $ACE.InheritedObjectType
                    }

                    $EffectivePermissions += $PermissionObject
                }
            }

            if ($EffectivePermissions.Count -eq 0)
            {
                Write-Verbose ('[{0:O}] No effective permissions found for {1} on {2}' -f (Get-Date), $Principal, $Identity)
            }
            else
            {
                Write-Verbose ('[{0:O}] Found {1} effective permission(s)' -f (Get-Date), $EffectivePermissions.Count)
                $EffectivePermissions
            }
        }
        catch
        {
            Write-Error ('[{0:O}] Error retrieving effective access: {1}' -f (Get-Date), $_.Exception.Message)
        }
    }

    End
    {
        Write-Verbose ('[{0:O}] Completed Get-EffectiveADAccess' -f (Get-Date))
    }
}

