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

The project uses **Pester** for testing with a code coverage threshold of 85%.

```powershell
# Run all tests
./build.ps1 -Tasks test

# Run tests with specific tags
./build.ps1 -Tasks test -PesterTag 'Integration'

# Exclude specific tags
./build.ps1 -Tasks test -PesterExcludeTag 'helpQuality'
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

### Adding New Functions

1. Create function file in `source/Public/` (exported) or `source/Private/` (internal)
2. Use comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.PARAMETER`
3. Follow advanced function pattern with `[CmdletBinding()]`
4. Create corresponding test file in `tests/Unit/Public/` or `tests/Unit/Private/`
5. Public functions will be auto-exported during build

Example function structure:
```powershell
function Verb-Noun {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ParamName
    )

    process {
        if ($PSCmdlet.ShouldProcess($target)) {
            # Implementation
        }
    }
}
```

### Adding New Classes

1. Create class file in `source/Classes/`
2. Prefix filename with number to control load order (e.g., `3.MyClass.ps1`)
3. Lower numbers load first - important for class dependencies
4. Create corresponding test in `tests/Unit/Classes/`

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

## Testing Guidelines

- Test files use Pester v5 syntax (`BeforeAll`, `AfterAll`, `Describe`, `Context`, `It`)
- Mock external dependencies with `Mock -CommandName ... -ModuleName PSPowerAdminTasks`
- Test both named parameters and pipeline input
- Test `ShouldProcess` (`-WhatIf`) support where applicable
- Maintain 85% code coverage threshold

## Output Directory Structure

After building, the `output/` directory contains:
- `output/RequiredModules/` - Build dependencies
- `output/module/PSPowerAdminTasks/<version>/` - Built module
- `output/testResults/` - Test results and code coverage files
