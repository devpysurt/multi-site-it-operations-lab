#Requires -Version 7.4
[CmdletBinding()]
param([switch]$IncludeWindows)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module Pester -RequiredVersion 5.7.1 -ErrorAction Stop
$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path $root 'tests'
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = Join-Path $root 'test-results/pester.xml'
if (-not $IncludeWindows) { $configuration.Filter.ExcludeTag = @('Windows') }
New-Item -ItemType Directory -Path (Join-Path $root 'test-results') -Force | Out-Null
$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0 -or $result.FailedBlocksCount -gt 0 -or $result.PassedCount -eq 0) { exit 1 }
exit 0
