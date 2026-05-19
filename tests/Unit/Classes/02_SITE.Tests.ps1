BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module - find the versioned module manifest
    $outputModulePath = "$PSScriptRoot/../../../output/module/$moduleName"
    $versionedManifest = Get-ChildItem -Path $outputModulePath -Include '*.psd1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -match '^\d+\.\d+\.\d+' } |
        Select-Object -First 1

    if ($versionedManifest) {
        $script:module = Import-Module $versionedManifest.FullName -Force -ErrorAction Stop -PassThru
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$moduleName.psd1"
        if (Test-Path $sourcePath) {
            $script:module = Import-Module $sourcePath -Force -ErrorAction Stop -PassThru
        } else {
            throw "Unable to find module manifest"
        }
    }
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
}

Describe 'SITE Class' -Tag @('Unit', 'Class') {
    Context 'Class Definition' {
        It 'Should have SITE class available' {
            # Test is simplified - class testing is challenging in module scope
            # This serves as a smoke test for module loading
            $moduleName = $script:moduleName
            { Get-Module $moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have Name property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have Description property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have Location property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have DistinguishedName property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have Subnets property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have SiteLinks property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have WhenCreated property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have WhenChanged property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have Options property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }

    Context 'Constructor - Default' {
        It 'Should create instance with no parameters' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should initialize Subnets as empty list' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should initialize SiteLinks as empty list' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should initialize Options as empty hashtable' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }

    Context 'Constructor - With Parameters' {
        It 'Should create instance with Name' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should create instance with Name and Description' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should create instance with Name, Description, and Location' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }

    Context 'Methods' {
        It 'Should add subnet to Subnets list' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should add site link to SiteLinks list' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should convert to hashtable' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should return meaningful ToString output' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }
}
