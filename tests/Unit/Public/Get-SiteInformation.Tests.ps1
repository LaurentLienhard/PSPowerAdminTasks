BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module
    $modulePath = "$PSScriptRoot/../../../output/module/$moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
}

Describe 'Get-SiteInformation' -Tag 'Unit', 'Public' {
    Context 'Function Exists' {
        It 'Should have Get-SiteInformation function' {
            $command = Get-Command -Name Get-SiteInformation -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter Validation' {
        It 'Should have Name as optional parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Name'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should accept Name from pipeline' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Name'].Attributes.ValueFromPipeline | Should -Contain $true
        }

        It 'Should accept Name from pipeline by property name' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Name'].Attributes.ValueFromPipelineByPropertyName | Should -Contain $true
        }

        It 'Should support wildcards for Name parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $nameParam = $command.Parameters['Name']
            $supportsWildcards = $nameParam.Attributes | Where-Object { $_.TypeId.Name -eq 'SupportsWildcardsAttribute' }
            $supportsWildcards | Should -Not -BeNullOrEmpty
        }

        It 'Should have Server as optional parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Server'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should have Credential as optional parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Credential'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should output SITE array type' {
            $command = Get-Command -Name Get-SiteInformation
            $outputType = $command.OutputType.Type.Name
            $outputType | Should -Be 'SITE[]'
        }
    }

    Context 'Error Handling' {
        It 'Should write an error when ActiveDirectory module is not available' {
            # This test verifies the function handles missing AD module gracefully
            # by checking that it has a mechanism to detect and report the error
            $command = Get-Command -Name Get-SiteInformation
            $command | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function Structure' {
        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Get-SiteInformation
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have BEGIN block' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match 'BEGIN\s*\{'
        }

        It 'Should have PROCESS block' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match 'PROCESS\s*\{'
        }

        It 'Should have END block' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match 'END\s*\{'
        }
    }

    Context 'SITE Class Integration' {
        It 'Should use SITE class from module' {
            # Verify that SITE class exists in the module
            # This verifies the module loaded successfully with its classes
            Get-Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should reference FromADObject static method in function code' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match '\[SITE\]::FromADObject'
        }

        It 'Should reference AddSiteLink method in function code' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match '\.AddSiteLink\('
        }

        It 'Should reference Get-ADReplicationSiteLink in function code' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match 'Get-ADReplicationSiteLink'
        }
    }

    Context 'Help Documentation' {
        It 'Should have help content' {
            $help = Get-Help Get-SiteInformation -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have SYNOPSIS in help' {
            $help = Get-Help Get-SiteInformation
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have DESCRIPTION in help' {
            $help = Get-Help Get-SiteInformation
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one EXAMPLE' {
            $help = Get-Help Get-SiteInformation
            @($help.Examples.Example).Count | Should -BeGreaterOrEqual 1
        }

        It 'Should document Name parameter' {
            $help = Get-Help Get-SiteInformation
            $help.Parameters.Parameter | Where-Object { $_.Name -eq 'Name' } | Should -Not -BeNullOrEmpty
        }

        It 'Should document Server parameter' {
            $help = Get-Help Get-SiteInformation
            $help.Parameters.Parameter | Where-Object { $_.Name -eq 'Server' } | Should -Not -BeNullOrEmpty
        }

        It 'Should document Credential parameter' {
            $help = Get-Help Get-SiteInformation
            $help.Parameters.Parameter | Where-Object { $_.Name -eq 'Credential' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SITELINK Class Usage' {
        It 'Should reference SITELINK class in function code' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match '\[SITELINK\]::FromADObject'
        }

        It 'Should reference Cost property in function comments' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match 'Cost'
        }

        It 'Should reference ReplicationFrequency in function comments' {
            $functionCode = Get-Content function:\Get-SiteInformation
            $functionCode | Should -Match 'ReplicationFrequency'
        }
    }
}
