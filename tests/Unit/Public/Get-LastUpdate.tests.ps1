BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module
    $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$script:moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-LastUpdate' -Tag 'Unit' {

    BeforeEach {
        Mock -CommandName Test-Connection -MockWith { $true }
        Mock -CommandName Get-ADComputer -MockWith {
            [PSCustomObject]@{
                Name = 'TEST01'
                SamAccountName = 'TEST01$'
                CN = 'TEST01'
                Operatingsystem = 'Windows Server 2019'
                Description = 'Test Computer'
                IPv4Address = '192.168.1.100'
                Created = (Get-Date)
                LastLogontimestamp = ([DateTime]::Now.ToFileTime())
                CanonicalName = 'domain.com/Computers/TEST01'
                MemberOf = @('CN=WSUS-Group,CN=Users,DC=domain,DC=com')
            }
        }
        Mock -CommandName Get-HotFix -MockWith {
            [PSCustomObject]@{
                HotfixID = 'KB1234567'
                Description = 'Security Update'
                InstalledBy = 'NT AUTHORITY\SYSTEM'
                InstalledOn = (Get-Date)
            }
        }
        Mock -CommandName Invoke-Command -MockWith { (Get-Date).AddDays(-5) }
        Mock -CommandName Export-Csv -MockWith {}
        Mock -CommandName Send-FileToGDrive -MockWith {}
        Mock -CommandName Send-MailKitMessage -MockWith {}
    }

    Context 'Parameter Validation' {

        It 'Should accept ComputerName parameter' {
            { Get-LastUpdate -ComputerName 'TEST01' } | Should -Not -Throw
        }

        It 'Should accept multiple ComputerNames' {
            { Get-LastUpdate -ComputerName 'TEST01', 'TEST02' } | Should -Not -Throw
        }

        It 'Should accept Credential parameter' {
            $cred = New-Object System.Management.Automation.PSCredential ('domain\user', (ConvertTo-SecureString 'password' -AsPlainText -Force))
            { Get-LastUpdate -ComputerName 'TEST01' -Credential $cred } | Should -Not -Throw
        }

        It 'Should accept UploadToGDriveParams hashtable' {
            $gdriveParams = @{ FolderId = 'abc123' }
            { Get-LastUpdate -ComputerName 'TEST01' -UploadToGDriveParams $gdriveParams } | Should -Not -Throw
        }

        It 'Should accept SendByMail switch' {
            { Get-LastUpdate -ComputerName 'TEST01' -SendByMail } | Should -Not -Throw
        }
    }

    Context 'CSV Export' {

        It 'Should export results to CSV file' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Export-Csv -Times 1
        }

        It 'Should use correct CSV parameters' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Export-Csv -ParameterFilter { $NoTypeInformation -eq $true -and $Delimiter -eq ',' } -Times 1
        }

        It 'Should create timestamped CSV file' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Export-Csv -ParameterFilter { $Path -match 'LastUpdateStatus_\d{8}_\d{6}\.csv' } -Times 1
        }
    }

    Context 'Google Drive Upload' {

        It 'Should call Send-FileToGDrive when UploadToGDriveParams provided' {
            $gdriveParams = @{ FolderId = 'abc123' }
            Get-LastUpdate -ComputerName 'TEST01' -UploadToGDriveParams $gdriveParams
            Assert-MockCalled -CommandName Send-FileToGDrive -Times 1
        }

        It 'Should not call Send-FileToGDrive when UploadToGDriveParams not provided' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Send-FileToGDrive -Times 0
        }

        It 'Should update SourceFile in UploadToGDriveParams' {
            $gdriveParams = @{ FolderId = 'abc123'; SourceFile = 'old.csv' }
            Get-LastUpdate -ComputerName 'TEST01' -UploadToGDriveParams $gdriveParams
            Assert-MockCalled -CommandName Send-FileToGDrive -ParameterFilter { $SourceFile -match 'LastUpdateStatus' } -Times 1
        }
    }

    Context 'Email Sending' {

        It 'Should call Send-MailKitMessage when SendByMail switch provided' {
            Get-LastUpdate -ComputerName 'TEST01' -SendByMail
            Assert-MockCalled -CommandName Send-MailKitMessage -Times 1
        }

        It 'Should not call Send-MailKitMessage when SendByMail switch not provided' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Send-MailKitMessage -Times 0
        }

        It 'Should use SMTP server from function' {
            Get-LastUpdate -ComputerName 'TEST01' -SendByMail
            Assert-MockCalled -CommandName Send-MailKitMessage -ParameterFilter { $SMTPServer -eq 'smtp.fmlogistic.fr' -and $port -eq 25 } -Times 1
        }

        It 'Should include CSV attachment in email' {
            Get-LastUpdate -ComputerName 'TEST01' -SendByMail
            Assert-MockCalled -CommandName Send-MailKitMessage -ParameterFilter { $null -ne $AttachmentList -and $AttachmentList.Count -gt 0 } -Times 1
        }
    }

    Context 'Return Value' {

        It 'Should return COMPUTER objects when no GDrive or Email params' {
            $result = Get-LastUpdate -ComputerName 'TEST01'
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 0
            $result.Name | Should -Be 'TEST01'
        }

        It 'Should not return objects when GDrive upload provided' {
            $gdriveParams = @{ FolderId = 'abc123' }
            $result = Get-LastUpdate -ComputerName 'TEST01' -UploadToGDriveParams $gdriveParams
            $result | Should -BeNullOrEmpty
        }

        It 'Should not return objects when SendByMail provided' {
            $result = Get-LastUpdate -ComputerName 'TEST01' -SendByMail
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'COMPUTER Class Integration' {

        It 'Should call Get-ADComputer for AD lookup' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Get-ADComputer -Times 1
        }

        It 'Should call Get-HotFix for hotfix information' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Get-HotFix -Times 1
        }

        It 'Should call Invoke-Command for boot uptime' {
            Get-LastUpdate -ComputerName 'TEST01'
            Assert-MockCalled -CommandName Invoke-Command -AtLeast 1
        }
    }
}
