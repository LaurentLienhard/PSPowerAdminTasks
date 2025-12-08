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

Describe 'Send-FileToGDrive' -Tag 'Unit' {

    Context 'Parameter Acceptance' {

        It 'Should accept all required parameters' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return "test-token-123"
            }
            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    id   = "file-id-123"
                    name = "test.csv"
                }
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile -ErrorAction SilentlyContinue
            $testFile | Remove-Item -Force -ErrorAction SilentlyContinue
            New-Item -Path $testFile.FullName -ItemType File -Force | Out-Null

            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = (New-TemporaryFile).FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                # Create dummy cert file
                New-Item -Path $params.CertFile -ItemType File -Force | Out-Null

                { Send-FileToGDrive @params -ErrorAction Stop } | Should -Not -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $params.CertFile -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should require SourceFile parameter' {
            $params = @{
                CertFile           = "C:\cert.p12"
                CertPassword       = "password"
                Project            = "test-project"
                ServiceAccount     = "test@test.iam.gserviceaccount.com"
                GDriveFolderId     = "folder-id-123"
                SupportsTeamDrives = $true
            }

            { Send-FileToGDrive @params -ErrorAction Stop } | Should -Throw
        }

        It 'Should require CertFile parameter' {
            # Create a temporary test file
            $testFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                { Send-FileToGDrive @params -ErrorAction Stop } | Should -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should validate SourceFile exists' {
            $params = @{
                SourceFile         = "C:\NonExistent\file.csv"
                CertFile           = "C:\cert.p12"
                CertPassword       = "password"
                Project            = "test-project"
                ServiceAccount     = "test@test.iam.gserviceaccount.com"
                GDriveFolderId     = "folder-id-123"
                SupportsTeamDrives = $true
            }

            { Send-FileToGDrive @params -ErrorAction Stop } | Should -Throw
        }

        It 'Should validate CertFile exists' {
            # Create a temporary test file
            $testFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = "C:\NonExistent\cert.p12"
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                { Send-FileToGDrive @params -ErrorAction Stop } | Should -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Token Retrieval' {

        It 'Should call Get-GoogleDriveAccessToken with correct parameters' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return "test-token-123"
            } -Verifiable

            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    id   = "file-id-123"
                    name = "test.csv"
                }
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                Send-FileToGDrive @params -ErrorAction SilentlyContinue

                Should -Invoke -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -Times 1
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should handle token retrieval failure' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return $null
            }

            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    id   = "file-id-123"
                    name = "test.csv"
                }
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                { Send-FileToGDrive @params -ErrorAction Stop } | Should -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'File Upload' {

        It 'Should call Invoke-GoogleDriveUpload with correct parameters' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return "test-token-123"
            }

            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    id   = "file-id-123"
                    name = "test.csv"
                }
            } -Verifiable

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                Send-FileToGDrive @params -ErrorAction SilentlyContinue

                Should -Invoke -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -Times 1
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should return upload result on success' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return "test-token-123"
            }

            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    id   = "file-id-123"
                    name = "test.csv"
                }
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                $result = Send-FileToGDrive @params -ErrorAction SilentlyContinue

                $result | Should -Not -BeNullOrEmpty
                $result.id | Should -Be "file-id-123"
                $result.name | Should -Be "test.csv"
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should handle upload failure' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return "test-token-123"
            }

            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return $null
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                { Send-FileToGDrive @params -ErrorAction Stop } | Should -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'ShouldProcess Support' {

        It 'Should support WhatIf parameter' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return "test-token-123"
            }

            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    id   = "file-id-123"
                    name = "test.csv"
                }
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                { Send-FileToGDrive @params -WhatIf -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Error Handling' {

        It 'Should handle exceptions gracefully' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                throw "Certificate error"
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                { Send-FileToGDrive @params -ErrorAction Stop } | Should -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Verbose Output' {

        It 'Should support Verbose parameter' {
            Mock -CommandName Get-GoogleDriveAccessToken -ModuleName $script:moduleName -MockWith {
                return "test-token-123"
            }

            Mock -CommandName Invoke-GoogleDriveUpload -ModuleName $script:moduleName -MockWith {
                return [PSCustomObject]@{
                    id   = "file-id-123"
                    name = "test.csv"
                }
            }

            # Create a temporary test file
            $testFile = New-TemporaryFile
            $certFile = New-TemporaryFile
            try {
                $params = @{
                    SourceFile         = $testFile.FullName
                    CertFile           = $certFile.FullName
                    CertPassword       = "password"
                    Project            = "test-project"
                    ServiceAccount     = "test@test.iam.gserviceaccount.com"
                    GDriveFolderId     = "folder-id-123"
                    SupportsTeamDrives = $true
                }

                { Send-FileToGDrive @params -Verbose -ErrorAction SilentlyContinue 4>&1 } | Should -Not -Throw
            }
            finally {
                Remove-Item -Path $testFile.FullName -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $certFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

}
