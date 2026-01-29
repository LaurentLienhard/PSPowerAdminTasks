param()

BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'
    $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    else {
        $sourcePath = "$PSScriptRoot/../../../source/$script:moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }

    # Create a mock for Send-MailKitMessage if it doesn't exist
    if (-not (Get-Command -Name 'Send-MailKitMessage' -ErrorAction SilentlyContinue)) {
        function Send-MailKitMessage {
            param(
                [Parameter()]
                [string]$SMTPServer,
                [Parameter()]
                [int]$Port,
                [Parameter()]
                [object]$From,
                [Parameter()]
                [object]$RecipientList,
                [Parameter()]
                [object]$CCList,
                [Parameter()]
                [string]$Subject,
                [Parameter()]
                [string]$TextBody,
                [Parameter()]
                [string]$HtmlBody,
                [Parameter()]
                [object]$AttachmentList
            )
            # Stub function for testing
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Send-MailForAreboot' -Tag 'Unit' {

    Context 'Function Availability' {
        It 'Should be available as a public function' {
            Get-Command -Name 'Send-MailForAreboot' -Module $script:moduleName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Should have CommandType Function' {
            (Get-Command -Name 'Send-MailForAreboot' -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {
        It 'Should have ComputerName parameter' {
            (Get-Command -Name 'Send-MailForAreboot').Parameters.ContainsKey('ComputerName') | Should -BeTrue
        }

        It 'Should have Recipient parameter' {
            (Get-Command -Name 'Send-MailForAreboot').Parameters.ContainsKey('Recipient') | Should -BeTrue
        }

        It 'Should have SMTPServer parameter' {
            (Get-Command -Name 'Send-MailForAreboot').Parameters.ContainsKey('SMTPServer') | Should -BeTrue
        }

        It 'Should have Port parameter' {
            (Get-Command -Name 'Send-MailForAreboot').Parameters.ContainsKey('Port') | Should -BeTrue
        }

        It 'Should have From parameter' {
            (Get-Command -Name 'Send-MailForAreboot').Parameters.ContainsKey('From') | Should -BeTrue
        }

        It 'Should have Credential parameter' {
            (Get-Command -Name 'Send-MailForAreboot').Parameters.ContainsKey('Credential') | Should -BeTrue
        }
    }

    Context 'Parameter Sets' {
        It 'Should accept ComputerName as mandatory parameter' {
            $param = (Get-Command -Name 'Send-MailForAreboot').Parameters['ComputerName']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -First 1 | Select-Object -ExpandProperty Mandatory | Should -BeTrue
        }

        It 'Should accept Recipient as mandatory parameter' {
            $param = (Get-Command -Name 'Send-MailForAreboot').Parameters['Recipient']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -First 1 | Select-Object -ExpandProperty Mandatory | Should -BeTrue
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command -Name 'Send-MailForAreboot').Parameters['ComputerName']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -First 1 | Select-Object -ExpandProperty ValueFromPipeline | Should -BeTrue
        }
    }

    Context 'Help Documentation' {
        It 'Should have a SYNOPSIS' {
            (Get-Help -Name 'Send-MailForAreboot').Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have a DESCRIPTION' {
            (Get-Help -Name 'Send-MailForAreboot').Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one EXAMPLE' {
            (Get-Help -Name 'Send-MailForAreboot').Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have help for ComputerName parameter' {
            (Get-Help -Name 'Send-MailForAreboot').Parameters.Parameter |
                Where-Object { $_.Name -eq 'ComputerName' } | Should -Not -BeNullOrEmpty
        }

        It 'Should have help for Recipient parameter' {
            (Get-Help -Name 'Send-MailForAreboot').Parameters.Parameter |
                Where-Object { $_.Name -eq 'Recipient' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function Behavior' {
        It 'Should support ShouldProcess (WhatIf)' {
            $cmd = Get-Command -Name 'Send-MailForAreboot'
            $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] } |
                Select-Object -ExpandProperty SupportsShouldProcess | Should -BeTrue
        }

        BeforeEach {
            Mock -CommandName 'Write-Verbose'
            Mock -CommandName 'Write-Warning'
            Mock -CommandName 'Write-Error'
            Mock -CommandName 'Send-MailKitMessage'
        }

        It 'Should return result objects for checked computers' {
            $params = @{
                ComputerName = 'TestServer1'
                Recipient    = 'admin@test.com'
                ErrorAction  = 'SilentlyContinue'
            }

            $result = Send-MailForAreboot @params

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should handle multiple computer names from pipeline' {
            $computers = @('TestServer1', 'TestServer2', 'TestServer3')

            { $computers | Send-MailForAreboot -Recipient 'admin@test.com' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should accept multiple recipients' {
            $params = @{
                ComputerName = 'TestServer1'
                Recipient    = @('admin1@test.com', 'admin2@test.com')
                ErrorAction  = 'SilentlyContinue'
            }

            { Send-MailForAreboot @params } | Should -Not -Throw
        }

        It 'Should accept custom SMTP configuration' {
            $params = @{
                ComputerName = 'TestServer1'
                Recipient    = 'admin@test.com'
                SMTPServer   = 'smtp.custom.com'
                Port         = 587
                From         = 'alerts@custom.com'
                ErrorAction  = 'SilentlyContinue'
            }

            { Send-MailForAreboot @params } | Should -Not -Throw
        }

        It 'Should respect WhatIf parameter' {
            $params = @{
                ComputerName = 'TestServer1'
                Recipient    = 'admin@test.com'
                WhatIf       = $true
                ErrorAction  = 'SilentlyContinue'
            }

            { Send-MailForAreboot @params } | Should -Not -Throw
        }
    }
}
