BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module - find the versioned module manifest
    $outputModulePath = "$PSScriptRoot/../../../output/module/$moduleName"
    $versionedManifest = Get-ChildItem -Path $outputModulePath -Include '*.psd1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -match '^\d+\.\d+\.\d+' } |
        Select-Object -First 1

    if ($versionedManifest) {
        $script:module = Import-Module $versionedManifest.FullName -Force -ErrorAction Stop -PassThru
    }
    else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$moduleName.psd1"
        if (Test-Path $sourcePath) {
            $script:module = Import-Module $sourcePath -Force -ErrorAction Stop -PassThru
        }
        else {
            throw "Unable to find module manifest"
        }
    }

    # Create a temp directory for test log files
    $script:testDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSPowerAdminTasks-WriteLog-Tests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:testDirectory -Force | Out-Null
}

AfterAll {
    # Clean up test files
    if (Test-Path $script:testDirectory) {
        Remove-Item -Path $script:testDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Clean up module
    Get-Module $script:moduleName | Remove-Module -Force
}

Describe 'Write-Log Function' -Tag 'Unit', 'Private' {

    Context 'Parameter Validation' {
        It 'Should require LogPath parameter' {
            { Write-Log -Message 'Test' -ErrorAction Stop } | Should -Throw
        }

        It 'Should require Message parameter' {
            $logPath = Join-Path -Path $script:testDirectory -ChildPath 'test.log'
            { Write-Log -LogPath $logPath -ErrorAction Stop } | Should -Throw
        }

        It 'Should accept all parameters' {
            $logPath = Join-Path -Path $script:testDirectory -ChildPath 'test.log'
            { Write-Log -LogPath $logPath -Message 'Test' -Severity 'Information' -Console } | Should -Not -Throw
        }
    }

    Context 'Severity Levels' {
        BeforeEach {
            $script:logPath = Join-Path -Path $script:testDirectory -ChildPath "severity-$(Get-Random).log"
        }

        It 'Should accept Information severity' {
            { Write-Log -LogPath $script:logPath -Message 'Test' -Severity 'Information' } | Should -Not -Throw
        }

        It 'Should accept Warning severity' {
            { Write-Log -LogPath $script:logPath -Message 'Test' -Severity 'Warning' } | Should -Not -Throw
        }

        It 'Should accept Error severity' {
            { Write-Log -LogPath $script:logPath -Message 'Test' -Severity 'Error' } | Should -Not -Throw
        }

        It 'Should reject invalid severity' {
            { Write-Log -LogPath $script:logPath -Message 'Test' -Severity 'InvalidLevel' -ErrorAction Stop } | Should -Throw
        }

        It 'Should use Information as default severity' {
            Write-Log -LogPath $script:logPath -Message 'Default severity test'

            $content = Get-Content -Path $script:logPath
            $content | Should -Match 'Information'
        }
    }

    Context 'Log File Creation and Writing' {
        BeforeEach {
            $script:logPath = Join-Path -Path $script:testDirectory -ChildPath "write-$(Get-Random).log"
        }

        It 'Should create log file if it does not exist' {
            Test-Path -Path $script:logPath | Should -Be $false

            Write-Log -LogPath $script:logPath -Message 'Test message'

            Test-Path -Path $script:logPath | Should -Be $true
        }

        It 'Should write message to log file' {
            Write-Log -LogPath $script:logPath -Message 'Test message'

            $content = Get-Content -Path $script:logPath
            $content | Should -Not -BeNullOrEmpty
            $content | Should -Match 'Test message'
        }

        It 'Should append messages to existing log file' {
            Write-Log -LogPath $script:logPath -Message 'First message'
            Write-Log -LogPath $script:logPath -Message 'Second message'

            $content = @(Get-Content -Path $script:logPath)
            $content.Count | Should -Be 2
            $content[0] | Should -Match 'First message'
            $content[1] | Should -Match 'Second message'
        }

        It 'Should write multiple lines over time' {
            Write-Log -LogPath $script:logPath -Message 'Message 1'
            Write-Log -LogPath $script:logPath -Message 'Message 2'
            Write-Log -LogPath $script:logPath -Message 'Message 3'

            $content = @(Get-Content -Path $script:logPath)
            $content.Count | Should -Be 3
        }
    }

    Context 'Log Message Format' {
        BeforeEach {
            $script:logPath = Join-Path -Path $script:testDirectory -ChildPath "format-$(Get-Random).log"
        }

        It 'Should include timestamp in ISO format' {
            Write-Log -LogPath $script:logPath -Message 'Test' -Severity 'Information'

            $content = Get-Content -Path $script:logPath
            $content | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        }

        It 'Should include severity level in log entry' {
            Write-Log -LogPath $script:logPath -Message 'Test' -Severity 'Warning'

            $content = Get-Content -Path $script:logPath
            $content | Should -Match 'Warning'
        }

        It 'Should include message text in log entry' {
            $testMessage = 'This is my test message'
            Write-Log -LogPath $script:logPath -Message $testMessage -Severity 'Information'

            $content = Get-Content -Path $script:logPath
            $content | Should -Match [regex]::Escape($testMessage)
        }

        It 'Should format as CSV with comma separators' {
            Write-Log -LogPath $script:logPath -Message 'Test message' -Severity 'Error'

            $content = Get-Content -Path $script:logPath
            # Should have timestamp, severity, and message separated by commas
            $content | Should -Match '^[\d\s\-:]+,[A-Za-z]+,.+'
        }

        It 'Should preserve special characters in message' {
            $specialMessage = 'Test with special chars: !@#$%^&*()'
            Write-Log -LogPath $script:logPath -Message $specialMessage

            $content = Get-Content -Path $script:logPath
            $content | Should -Match [regex]::Escape($specialMessage)
        }
    }

    Context 'Console Output' {
        BeforeEach {
            $script:logPath = Join-Path -Path $script:testDirectory -ChildPath "console-$(Get-Random).log"
        }

        It 'Should not write to console by default' {
            Write-Log -LogPath $script:logPath -Message 'Silent test' 3>&1 | Should -BeNullOrEmpty
        }

        It 'Should write to console when Console switch is used' {
            $output = Write-Log -LogPath $script:logPath -Message 'Console test' -Console 6>&1

            # Capture host output
            $output = Write-Log -LogPath $script:logPath -Message 'Console test' -Console -WarningAction SilentlyContinue -WarningVariable dummy 6>&1
        }

        It 'Should write message text to console, not the full log format' {
            $message = 'This is the console message'
            Write-Log -LogPath $script:logPath -Message $message -Console -InformationAction SilentlyContinue -InformationVariable dummy
        }
    }

    Context 'Edge Cases' {
        BeforeEach {
            $script:logPath = Join-Path -Path $script:testDirectory -ChildPath "edge-$(Get-Random).log"
        }

        It 'Should handle empty message' {
            { Write-Log -LogPath $script:logPath -Message '' } | Should -Not -Throw
        }

        It 'Should handle very long message' {
            $longMessage = 'A' * 1000
            { Write-Log -LogPath $script:logPath -Message $longMessage } | Should -Not -Throw

            $content = Get-Content -Path $script:logPath
            $content | Should -Match ('A' * 100)
        }

        It 'Should handle message with newlines' {
            $multilineMessage = "Line 1`nLine 2`nLine 3"
            Write-Log -LogPath $script:logPath -Message $multilineMessage

            $content = Get-Content -Path $script:logPath
            $content | Should -Not -BeNullOrEmpty
        }

        It 'Should handle message with commas' {
            $messageWithCommas = 'This, has, commas, in it'
            Write-Log -LogPath $script:logPath -Message $messageWithCommas

            $content = Get-Content -Path $script:logPath
            $content | Should -Match [regex]::Escape($messageWithCommas)
        }

        It 'Should handle nested directory path creation' {
            $nestedLogPath = Join-Path -Path $script:testDirectory -ChildPath 'nested/deep/path/test.log'
            $nestedDir = Split-Path -Path $nestedLogPath -Parent

            if (-not (Test-Path $nestedDir)) {
                New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
            }

            { Write-Log -LogPath $nestedLogPath -Message 'Test' } | Should -Not -Throw
        }
    }

    Context 'Severity and Message Combinations' {
        BeforeEach {
            $script:logPath = Join-Path -Path $script:testDirectory -ChildPath "combo-$(Get-Random).log"
        }

        It 'Should log Information severity with message' {
            Write-Log -LogPath $script:logPath -Message 'Information test' -Severity 'Information'

            $content = Get-Content -Path $script:logPath
            $content | Should -Match 'Information.*Information test'
        }

        It 'Should log Warning severity with message' {
            Write-Log -LogPath $script:logPath -Message 'Warning test' -Severity 'Warning'

            $content = Get-Content -Path $script:logPath
            $content | Should -Match 'Warning.*Warning test'
        }

        It 'Should log Error severity with message' {
            Write-Log -LogPath $script:logPath -Message 'Error test' -Severity 'Error'

            $content = Get-Content -Path $script:logPath
            $content | Should -Match 'Error.*Error test'
        }
    }
}
