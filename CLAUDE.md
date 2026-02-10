# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PSPowerAdminTasks is a PowerShell module containing system administration utilities. The project uses the Sampler framework for building, testing, and publishing PowerShell modules with a standardized CI/CD pipeline.

## Build System

This project uses the **Sampler** framework with **ModuleBuilder** and **InvokeBuild** for its build pipeline.

### Common Build Commands

```powershell
# Bootstrap: Install required build dependencies (always run first)
./build.ps1 -ResolveDependency -Tasks noop

# Build the module
./build.ps1 -Tasks build

# Run all tests
./build.ps1 -Tasks test

# Build and package
./build.ps1 -Tasks pack

# Full build and test (default workflow)
./build.ps1
```

### Testing

The project uses **Pester** for testing with a code coverage threshold of 80%.

```powershell
# Run all tests
./build.ps1 -Tasks test

# Run tests with specific tags
./build.ps1 -Tasks test -PesterTag 'Integration'

# Exclude specific tags
./build.ps1 -Tasks test -PesterExcludeTag 'helpQuality'

# Run a single test file directly (for rapid iteration during development)
Invoke-Pester -Path tests/Unit/Public/Get-RemoteSoftware.tests.ps1 -Output Detailed
```

Tests are organized in:
- `tests/Unit/` - Unit tests mirroring the source structure
  - `tests/Unit/Public/` - Tests for public functions
  - `tests/Unit/Private/` - Tests for private functions
  - `tests/Unit/Classes/` - Tests for classes
- `tests/QA/` - Quality assurance tests (e.g., module.tests.ps1)

## Module Architecture

### Source Structure

The module follows the Sampler pattern with code organized in `source/`:

- **`source/Public/`** - Exported functions (user-facing cmdlets)
- **`source/Private/`** - Internal helper functions (not exported)
- **`source/Classes/`** - PowerShell classes (numbered for load order: `1.class1.ps1`, `2.class2.ps1`, etc.)
- **`source/Enum/`** - Enumeration definitions
- **`source/Modules/`** - Nested modules
- **`source/en-US/`** - English help documentation
- **`source/Examples/`** - Usage examples
- **`source/WikiSource/`** - Wiki documentation source

### Module Building

The build process:
1. Reads source files from `source/`
2. Compiles them into a single module under `output/module/<ModuleName>/<Version>/`
3. Classes are loaded in numeric order by filename prefix
4. The root module file `source/PSPowerAdminTasks.psm1` is intentionally empty and rebuilt during build
5. Exports are defined in `source/PSPowerAdminTasks.psd1` manifest

### Code Style

#### General Rules
- **All code, functions, and documentation must be written in English**
- Comment-based help must be placed **immediately after the function name** (inside the function, before `[CmdletBinding()]`)
- **Every function (Public and Private) and every class must have a corresponding Pester test file**
- Tests must use mocks for external dependencies (no real API/AD/network calls)
- Each function/class must achieve **minimum 80% code coverage**
- **Prefer `Write-Verbose` over `Write-Host` or `Write-Output`** for informational messages

#### Function Structure
- Use **uppercase** for `BEGIN`, `PROCESS`, `END` blocks
- Use `[CmdletBinding()]` for all functions
- Use `[OutputType()]` attribute when returning specific types
- Support pipeline input with `ValueFromPipeline` and `ValueFromPipelineByPropertyName`
- Use `[Parameter()]` attribute with `Mandatory`, `HelpMessage`, `Position` as needed
- Use validation attributes: `[ValidateSet()]`, `[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`

#### Parameter Patterns
- Credential parameter pattern (optional credentials):
  ```powershell
  [Parameter()]
  [System.Management.Automation.PSCredential]$Credential
  ```
- Check for credential with `$PSBoundParameters.ContainsKey('Credential')`

#### Coding Conventions
- Use **splatting** for commands with multiple parameters:
  ```powershell
  $params = @{
      ComputerName = $Computer
      ErrorAction  = 'Stop'
  }
  Invoke-Command @params
  ```
- Use `[PSCustomObject]@{}` for structured output objects
- Use `[System.Collections.Generic.List[T]]::new()` instead of `ArrayList` for collections
- Use `try/catch` blocks with specific exception types when possible
- Use `[SuppressMessageAttribute()]` to bypass PSScriptAnalyzer rules only when justified

#### Code Formatting (VSCode PowerShell Extension)
**Brace Placement:**
- Opening braces on new line: `OpenBraceOnSameLine = false`
- New line after opening brace: `true`
- New line after closing brace: `true`
- Whitespace before opening brace: `true`

**Spacing & Operators:**
- Whitespace before opening parenthesis: `true`
- Whitespace around operators: `true`
- Whitespace after separator: `true`
- Align property value pairs: `true`

**Pipeline Formatting:**
- Pipeline indentation style: `IncreaseIndentationAfterEveryPipeline`
- Single-line blocks ignored: `false`

**File Formatting:**
- Trim trailing whitespace: `true`
- Trim final newlines: `true`
- Insert final newline: `true`
- PSScriptAnalyzer enabled: `true`

**Example formatted code:**
```powershell
function Get-Example
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $result = Get-Content -Path $Name |
        Where-Object { $_ -match 'pattern' } |
        Select-Object -Property Property1, Property2

    return $result
}
```

#### Class Structure
- Use `#region` comments to organize sections: `#region <Properties>`, `#region <Constructor>`, `#region <Methods>`
- Prefix class files with numbers for load order (e.g., `01_SITELINK.ps1`, `02_SITE.ps1`)
- Use `HIDDEN` keyword for internal properties (e.g., credentials)

#### Performance and Optimization
- **All functions must be optimized for PowerShell 7+ capabilities**
- **Parallel processing is required for operations processing multiple items** (10+ items):
  - Use `ForEach-Object -Parallel -ThrottleLimit <N>` for batch operations
  - Use appropriate ThrottleLimit values (default 32, range 1-256 based on resource constraints)
  - Provide ThrottleLimit as configurable parameter for users
- **Performance best practices**:
  - Avoid sequential loops when parallel alternatives exist
  - Use `[System.Collections.Generic.List[T]]` instead of `+=` for collections (100x faster)
  - Cache AD queries when possible instead of repeated lookups
  - Implement early filtering at AD level using LDAP filters, not post-processing
  - Use `-ErrorAction SilentlyContinue` appropriately to skip non-critical errors without stopping
  - Consider `-Timeout` parameters for network operations
- **Fallback for PowerShell 5.1**:
  - Functions should detect PowerShell version and use sequential processing as fallback
  - Display warning when running on PS 5.1 for large datasets
  - Example: `if ($PSVersionTable.PSVersion.Major -ge 7) { use parallel } else { use sequential }`
- **Example parallel pattern**:
  ```powershell
  $results = $items | ForEach-Object -ThrottleLimit 32 -Parallel {
      $item = $_
      $sharedVar = $using:sharedVar
      # Process item in parallel
      [PSCustomObject]@{ Result = $item }
  } | Where-Object { $null -ne $_ }
  ```

### Adding New Functions

1. Create function file in `source/Public/` (exported) or `source/Private/` (internal)
2. Use comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.PARAMETER`
3. Follow advanced function pattern with `[CmdletBinding()]`
4. Create corresponding test file in `tests/Unit/Public/` or `tests/Unit/Private/`
5. Public functions will be auto-exported during build

Example function structure:
```powershell
function Verb-Noun
{
    <#
        .SYNOPSIS
            Brief description of what the function does.

        .DESCRIPTION
            Detailed description of the function.

        .PARAMETER ParamName
            Description of the parameter.

        .PARAMETER Credential
            Credentials for remote access.

        .EXAMPLE
            Verb-Noun -ParamName "Value"

            Description of what this example does.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$ParamName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        Write-Verbose "Starting Verb-Noun"
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    PROCESS
    {
        foreach ($item in $ParamName)
        {
            $params = @{
                ComputerName = $item
                ErrorAction  = 'Stop'
            }

            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $params['Credential'] = $Credential
            }

            try
            {
                if ($PSCmdlet.ShouldProcess($item, "Perform action"))
                {
                    # Implementation
                    $result = [PSCustomObject]@{
                        Name   = $item
                        Status = 'Success'
                    }
                    $results.Add($result)
                }
            }
            catch
            {
                Write-Error "Error processing $item : $($_.Exception.Message)"
            }
        }
    }

    END
    {
        Write-Verbose "Completed Verb-Noun"
        return $results
    }
}
```

### Modifying Existing Functions

When modifying an existing function, **always update the comment-based help** to keep documentation in sync with implementation:

#### Required Documentation Updates
1. **New Parameters**: Add `.PARAMETER` blocks for any new parameters
   - Include clear descriptions of what the parameter does
   - Document default values
   - Explain the impact on function behavior

2. **Modified Parameters**: Update existing `.PARAMETER` descriptions if behavior changes
   - Note if parameter becomes mandatory/optional
   - Update examples if parameter usage changes

3. **Output Changes**: Update `.OUTPUTS` and `[OutputType()]` if return type or structure changes
   - Document new properties in returned objects
   - Explain how the change differs from previous behavior

4. **Examples**: Add/update `.EXAMPLE` blocks to demonstrate new functionality
   - Include examples showing new parameters in use
   - Show the expected output format
   - Add descriptive comments explaining what each example demonstrates

5. **Breaking Changes**: Add `.NOTES` section if function signature or behavior significantly changes
   - Highlight what changed and why
   - Provide migration guidance for callers

#### Example: Adding a Parameter and Updating Help
```powershell
# BEFORE: Simple function with basic help
function Get-ServerInfo
{
    <#
        .SYNOPSIS
            Gets server information from Active Directory.
        .PARAMETER ComputerName
            Name of the server to query.
        .EXAMPLE
            Get-ServerInfo -ComputerName 'Server01'
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )
}

# AFTER: Added Verbose parameter - HELP UPDATED!
function Get-ServerInfo
{
    <#
        .SYNOPSIS
            Gets server information from Active Directory with optional detailed output.
        .PARAMETER ComputerName
            Name of the server to query.
        .PARAMETER Verbose
            If specified, displays detailed processing information for each server scanned.
            Default is $false.
        .EXAMPLE
            Get-ServerInfo -ComputerName 'Server01'

            Gets basic server information from Active Directory.

        .EXAMPLE
            Get-ServerInfo -ComputerName 'Server01' -Verbose

            Gets server information and displays detailed processing messages showing
            which servers are being scanned and their status.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )
}
```

### Adding New Classes

1. Create class file in `source/Classes/`
2. Prefix filename with number to control load order (e.g., `03_MyClass.ps1`)
3. Lower numbers load first - important for class dependencies
4. Create corresponding test in `tests/Unit/Classes/`

Example class structure:
```powershell
class MYCLASS
{
    #region <Properties>
    [System.String]$Name
    [System.String]$Status
    HIDDEN [System.Management.Automation.PSCredential]$Credential
    #endregion <Properties>

    #region <Constructor>
    MYCLASS()
    {
    }

    MYCLASS([string]$Name)
    {
        $this.Name = $Name
    }

    MYCLASS([string]$Name, [System.Management.Automation.PSCredential]$Credential)
    {
        $this.Name = $Name
        $this.Credential = $Credential
    }
    #endregion <Constructor>

    #region <Methods>
    [void] DoSomething()
    {
        # Implementation
    }

    [Boolean] TestSomething()
    {
        return $true
    }

    static [MYCLASS] FromADObject([object]$ADObject)
    {
        $instance = [MYCLASS]::new($ADObject.Name)
        return $instance
    }
    #endregion <Methods>
}
```

## Version Management

The project uses **GitVersion** for semantic versioning:
- Version is calculated from git history
- Main branch: Tagged as `preview`
- Feature branches (`feature/` or `f/`): Minor version bump with branch name tag
- Hotfix branches (`hotfix/` or `fix/`): Patch version bump with `fix` tag
- Commit message keywords:
  - `breaking change`, `breaking`, `major` → Major version bump
  - `adds`, `feature`, `minor` → Minor version bump
  - `fix`, `patch` → Patch version bump
  - `+semver: none` or `+semver: skip` → No version bump

## CI/CD Pipeline

The Azure Pipelines configuration (`azure-pipelines.yml`) defines:

1. **Build Stage**: Packages module on Ubuntu
2. **Test Stage**: Runs tests on Linux, Windows (PS 7), Windows (PS 5.1), and macOS
3. **Deploy Stage**: Publishes to GitHub and PowerShell Gallery (only on main branch)

Tests produce NUnit XML results and code coverage artifacts.

## Configuration Files

- **`build.yaml`** - ModuleBuilder and Sampler configuration, defines build workflows and tasks
- **`RequiredModules.psd1`** - Build-time dependencies (Pester, PSScriptAnalyzer, etc.)
- **`GitVersion.yml`** - Semantic versioning rules
- **`azure-pipelines.yml`** - CI/CD pipeline definition
- **`source/PSPowerAdminTasks.psd1`** - Module manifest (version, author, exports)

## Development Workflow

1. Clone repository and navigate to root
2. Bootstrap dependencies: `./build.ps1 -ResolveDependency -Tasks noop`
3. Make changes in `source/` directory
4. Add/update tests in `tests/Unit/`
5. Build module: `./build.ps1 -Tasks build`
6. Run tests: `./build.ps1 -Tasks test`
7. Built module is in `output/module/PSPowerAdminTasks/<version>/`
8. To import and test locally: `Import-Module ./output/module/PSPowerAdminTasks/<version>/PSPowerAdminTasks.psd1 -Force`

## Testing Guidelines

- Test files use Pester v5 syntax (`BeforeAll`, `AfterAll`, `Describe`, `Context`, `It`)
- Mock external dependencies with `Mock -CommandName ... -ModuleName PSPowerAdminTasks`
- Test both named parameters and pipeline input
- Test `ShouldProcess` (`-WhatIf`) support where applicable
- Maintain 80% code coverage threshold

## Output Directory Structure

After building, the `output/` directory contains:
- `output/RequiredModules/` - Build dependencies
- `output/module/PSPowerAdminTasks/<version>/` - Built module
- `output/testResults/` - Test results and code coverage files
