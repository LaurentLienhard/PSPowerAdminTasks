function Disable-CompromisedUser
{
<#
    .SYNOPSIS
    Disable compromised user

    .DESCRIPTION
    In case of compromission from some users, you can rapidly disable this users.
    You can pass to parameter :
        - a nominative list of user
        - a file with a nominative list of users (one user by line)
        - an OU to disable all users
    Check example for more details (get-help Disable-CompromisedUser -Examples)
    A log file is create in your temp directory ($env:temp)

    .PARAMETER Identity
    One or more user(s) to disable

    .PARAMETER FileName
    File with a list of users to disable. txt with one name by line

    .PARAMETER OU
    One or more OU(s) in which we want to disable all users

    .PARAMETER Check
    Only check if the users passed in parameter, whatever the way (Identity, Filename or OU), are disable

    .PARAMETER Credential
    Specifies the user account credentials to use when performing this task

    .PARAMETER Log
    Log information in a file (in $env:Temp )

    .PARAMETER Console
    Show information in console (need Log parameter)

    .EXAMPLE
    Disable-CompromisedUser -Identity "User1"

    Disable the user account : User1

    .EXAMPLE
    Disable-CompromisedUser -Identity "User1" -Log

    Disable the user account : User1 and log information in file in $env:temp

    .EXAMPLE
    Disable-CompromisedUser -Identity "User1" -Log -Console

    Disable the user account : User1, log information in file in $env:temp and log to console the same information

    .EXAMPLE
    Disable-CompromisedUser -Identity "User1" -Check

    Check if user account User1 is disable

    .EXAMPLE
    Disable-CompromisedUser -Identity "User1","User2","User3"

    Disable users account : User1, User2 and User3

    .EXAMPLE
    Disable-CompromisedUser -Identity "User1","User2","User3" -Check

    Check if users account User1, User2 and User3 are disable

    .EXAMPLE
    Disable-CompromisedUser -FileName "c:\temp\CompromisedUser.txt"

    File template CompromisedUser.txt :
    User1
    User2
    User3

    Disable users account : User1, User2 and User3

    .EXAMPLE
    Disable-CompromisedUser -FileName "c:\temp\CompromisedUser.txt" -Check

    File template CompromisedUser.txt :
    User1
    User2
    User3

    Check if users account User1, User2 and User3 are disable

    .EXAMPLE
    Disable-CompromisedUser -OU "OU=OU1,DC=contoso,DC=com"

    Disable all users present in OU1

    .EXAMPLE
    Disable-CompromisedUser -OU "OU=OU1,DC=contoso,DC=com" -Check

    Check if all users present in OU1 are disable

    .EXAMPLE
    Disable-CompromisedUser -OU "OU=OU1,DC=contoso,DC=com","OU=OU2,DC=contoso,DC=com"

    Disable all users present in OU1 and OU2

    .EXAMPLE
    Disable-CompromisedUser -OU "OU=OU1,DC=contoso,DC=com","OU=OU2,DC=contoso,DC=com" -check

    Check if all users present in OU1 and OU2 are disable

    .NOTES
    General notes
#>
    [CmdletBinding(DefaultParameterSetName = "ByUser")]
    param (
        [Parameter(
            ParameterSetName = "ByUser",
            HelpMessage = 'One or more user(s) to disable'
        )]
        [System.String[]]$Identity,
        [Parameter(
            ParameterSetName = "ByFileName",
            HelpMessage = 'File with a list of users to disable. txt with one name by line'
        )]
        [System.String]$FileName,
        [Parameter(
            ParameterSetName = "ByOu",
            HelpMessage = 'One or more OU(s) in which we want to disable all users'
        )]
        [System.String[]]$OU,
        [Parameter(
            HelpMessage = 'Only check if the users passed in parameter, whatever the way (Identity, Filename or OU), are disable'
        )]
        [Switch]$Check,

        [Parameter(
            HelpMessage = "Specifies the user account credentials to use when performing this task."
        )]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(
            HelpMessage = 'Log information in a file'
        )]
        [switch]$log,

        [Parameter(
            HelpMessage = 'Show information in console'
        )]
        [switch]$Console
    )


    begin
    {
        if ($log)
        {
            $LogPath = $env:Temp + '\Disable-CompromisedUser.csv'
            Write-Log -LogPath $LogPath -Message 'Starting Disable-CompromisedUser' -Severity Information -Console:$Console
        }
        $Users = [System.Collections.ArrayList]@()

        switch ($PSCmdlet.ParameterSetName)
        {
            ByUser
            {
                if ($log) { write-log -LogPath $LogPath -Message "Retrieve AD User Account by user list" -Severity Information -Console:$Console}
                foreach ($User in $Identity)
                {
                    try
                    {
                        [void]$Users.Add((Get-ADUser -Identity $User -Properties SamAccountName,DisplayName,Enabled -ErrorAction Continue))
                        if ($log) { write-log -LogPath $LogPath -Message "User $($User) found" -Severity Information -Console:$Console}
                    }
                    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
                    {
                        if ($log) { write-log -LogPath $LogPath -Message "User $($User) not found" -Severity Error -Console:$Console}
                    }
                }
            }
            ByFileName
            {
                if ($log) { write-log -LogPath $LogPath -Message "Retrieve AD User Account by file list" -Severity Information -Console:$Console}
                foreach ($User in (Get-Content -Path $FileName))
                {
                    try
                    {
                        [void]$Users.Add((Get-ADUser -Identity $User -Properties SamAccountName,DisplayName,Enabled -ErrorAction Continue))
                        if ($log) { write-log -LogPath $LogPath -Message "User $($User) found" -Severity Information -Console:$Console}
                    }
                    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
                    {
                        if ($log) { write-log -LogPath $LogPath -Message "User $($User) not found" -Severity Error -Console:$Console}
                    }
                }
            }
            ByOu
            {
                if ($log) { write-log -LogPath $LogPath -Message "Retrieve AD User Account by OU list" -Severity Information -Console:$Console}
                foreach ($Organ in $OU)
                {
                    if ($log) { write-log -LogPath $LogPath -Message "Retrieve AD User Account in $($Organ)" -Severity Information -Console:$Console}
                    [void]$Users.AddRange((Get-ADUser -Filter * -SearchBase $Organ -Properties SamAccountName,DisplayName,Enabled))
                }
            }
        }
    }

    process
    {
        $Arguments = @{}
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $Arguments['Credential'] = $Credential
        }

        foreach ($user in $Users)
        {
            if ($Check)
            {
                if ($log) { write-log -LogPath $LogPath -Message "Check state for user $($user.SamAccountName)" -Severity Information -Console:$Console}
                if ($user.Enabled -eq $true)
                {
                    if ($log) { write-log -LogPath $LogPath -Message "user $($user.SamAccountName) is enabled" -Severity Information -Console:$Console}
                }
                else
                {
                    if ($log) { write-log -LogPath $LogPath -Message "user $($user.SamAccountName) is disabled" -Severity Information -Console:$Console}
                }
            }
            else
            {
                $Arguments['Identity'] = $user.SamAccountName
                Disable-ADAccount @Arguments -Confirm:$false
                if ($log) { write-log -LogPath $LogPath -Message "Disabling user $($user.SamAccountName)" -Severity Information -Console:$Console}
            }
        }
    }

    end
    {
        if ($log)
        {
            write-log -LogPath $LogPath -Message "Ending Disable-CompromisedUser" -Severity Information -Console:$Console
        }
    }
}
