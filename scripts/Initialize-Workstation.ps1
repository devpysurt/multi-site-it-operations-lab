#Requires -Version 7.4
<#
.SYNOPSIS
Create a workstation workspace, optionally installing missing WinGet packages.
.EXAMPLE
./scripts/Initialize-Workstation.ps1 -WhatIf -InstallPackages
.EXAMPLE
./scripts/Initialize-Workstation.ps1 -InstallPackages -AcceptPackageAgreements
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '../config/workstation.example.json'),
    [string]$WorkspaceRoot = (Join-Path $PSScriptRoot '../workstation'),
    [string]$LogDirectory = (Join-Path $PSScriptRoot '../logs'),
    [switch]$InstallPackages,
    [switch]$AcceptPackageAgreements
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot '../src/ITOpsLab/ITOpsLab.psd1') -Force
    $arguments = @{
        ConfigPath = $ConfigPath; WorkspaceRoot = $WorkspaceRoot; LogDirectory = $LogDirectory
        InstallPackages = $InstallPackages; AcceptPackageAgreements = $AcceptPackageAgreements
        WhatIf = [bool]$WhatIfPreference
    }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $arguments.Confirm = $PSBoundParameters.Confirm }
    $result = Initialize-LabWorkstation @arguments
    $result
    if (-not $result.Succeeded) { exit 1 }
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
