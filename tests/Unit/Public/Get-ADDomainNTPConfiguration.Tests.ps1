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
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ADDomainNTPConfiguration' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should exist in the module' {
            Get-Command -Name Get-ADDomainNTPConfiguration -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Get-ADDomainNTPConfiguration -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {

        It 'Should have a mandatory ADServer parameter' {
            $param = (Get-Command -Name Get-ADDomainNTPConfiguration -Module $script:moduleName).Parameters['ADServer']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have a mandatory Credential parameter' {
            $param = (Get-Command -Name Get-ADDomainNTPConfiguration -Module $script:moduleName).Parameters['Credential']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }
    }

    Context 'Help Documentation' {

        It 'Should have help documentation' {
            $help = Get-Help -Name Get-ADDomainNTPConfiguration -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have a synopsis' {
            $help = Get-Help -Name Get-ADDomainNTPConfiguration -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one example' {
            $help = Get-Help -Name Get-ADDomainNTPConfiguration -ErrorAction SilentlyContinue
            $help.Examples | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - Success Path' {

        BeforeAll {
            $script:fakeCred = [System.Management.Automation.PSCredential]::new(
                'domain\admin',
                (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)
            )

            Mock -CommandName Get-ADDomainController -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{ HostName = 'DC01.domain.local' },
                    [PSCustomObject]@{ HostName = 'DC02.domain.local' }
                )
            }

            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        DCName     = 'DC01'
                        NTPSource  = 'time.windows.com'
                        ConfigType = 'NT5DS'
                        Service    = 'Running'
                        Accessible = $true
                    },
                    [PSCustomObject]@{
                        DCName     = 'DC02'
                        NTPSource  = 'DC01.domain.local'
                        ConfigType = 'NT5DS'
                        Service    = 'Running'
                        Accessible = $true
                    }
                )
            }
        }

        It 'Should call Get-ADDomainController with the provided server' {
            Get-ADDomainNTPConfiguration -ADServer 'DC01.domain.local' -Credential $script:fakeCred
            Should -Invoke -CommandName Get-ADDomainController -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should call Invoke-Command to retrieve NTP data' {
            Get-ADDomainNTPConfiguration -ADServer 'DC01.domain.local' -Credential $script:fakeCred
            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should return results' {
            $result = Get-ADDomainNTPConfiguration -ADServer 'DC01.domain.local' -Credential $script:fakeCred
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - Error Path' {

        BeforeAll {
            $script:fakeCred = [System.Management.Automation.PSCredential]::new(
                'domain\admin',
                (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)
            )

            Mock -CommandName Get-ADDomainController -ModuleName $script:moduleName -MockWith {
                return $null
            }
        }

        It 'Should write an error when no DCs are returned' {
            { Get-ADDomainNTPConfiguration -ADServer 'DC01.domain.local' -Credential $script:fakeCred -ErrorAction Stop } |
                Should -Throw
        }
    }
}
